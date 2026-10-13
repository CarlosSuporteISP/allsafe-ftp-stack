# SPDX-License-Identifier: Apache-2.0
"""Aba Arquivos: navegar pelas pastas dos usuários do FTP, baixar e enviar arquivo pelo navegador, criar pasta,
trocar o nome e apagar.

Arquivo enviado nunca substitui outro. Apagar pede a caixa de confirmação e a senha de quem está na sessão. Toda alteração
é feita em relação à pasta de cima já aberta, sem seguir link simbólico. As mesmas funções servem à tela Meus
arquivos, do usuário do FTP, e às outras pastas que o administrador liberou a ele: a Vista diz de onde cada um vê
os arquivos, e a tabela de rotas do perfil, ou da permissão dele na pasta liberada (rotas.py), diz quais destas
ações existem para ele."""
import ctypes
import errno
import itertools
import os
import pwd
import re
import stat
import threading
import time
import urllib.parse

import chegadas
import envio
import pastas
from auditoria import auditar, limpo
from config import (APAGAR_MAX, APAGAR_NIVEIS, APAGAR_PRAZO, CFG, DONO_DADOS, DOWNLOADS_MAX, ENVIOS_MAX, LISTA_MAX, NIVEL, PASTA,
                    PASTA_DADOS)
from confirmacao import campo_senha_atual, confirmacao_recusada
from estado import limpar_cache, uso_da_pasta, usuarios
from icones import icone
from idioma import N, t
from limites import downloads_e_taxa, envio_pelo_painel
from pagina import cabeca, como, e, pagina, quando, tamanho, vazio
from sessao import quem

VAGAS = threading.BoundedSemaphore(DOWNLOADS_MAX)
TRAVA_CURSO = threading.Lock()
EM_CURSO = {}  # usuário do FTP → downloads dele em andamento
ENVIOS = threading.BoundedSemaphore(ENVIOS_MAX)
ENVIANDO = set()  # usuários do FTP com um envio pelo painel em andamento: cada um envia um arquivo por vez
# Nenhuma parte do caminho é seguida se for link simbólico; O_NONBLOCK não deixa um FIFO prender o pedido.
ABRIR = os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK
RECUSAS = {
    400: N('Caminho não aceito.'),
    403: N('Link simbólico não é seguido pelo painel.'),
    404: N('Pasta ou arquivo não encontrado.'),
}
MENSAGENS = {'criada': N('Pasta criada.'), 'renomeado': N('Nome trocado.'), 'apagado': N('Apagado.'),
             'enviado': N('Arquivo enviado.'),
             'enviado_com_data': N('Arquivo enviado. Já havia um com este nome: o novo foi guardado com a data e a hora no nome.')}
TRAVA_APAGAR = threading.Lock()  # um apagamento por vez: os outros pedidos do painel seguem atendidos
PARADAS = {
    'limite': N('A pasta tem mais do que o painel apaga de uma vez ({maximo} itens ou {prazo} segundos por pedido). '
                'Repita para continuar.'),
    'erro': N('Um item não pôde ser apagado, ou a pasta recebeu arquivo durante a limpeza. Confira a pasta e repita.'),
    'ocupado': N('O painel já está apagando outra pasta. Espere terminar e repita.'),
}
REGRA_DO_ITEM = N('Letras, números, <code>_</code>, <code>-</code> e ponto; não começa com ponto; até 64 caracteres.')
# Tipo do item ➜ a frase de cada tela, inteira: o artigo e a ordem das palavras mudam de um idioma para o outro.
RENOMEAR = {
    'pasta': N('Trocar o nome da pasta <strong>{nome}</strong>, em {onde}.'),
    'arquivo': N('Trocar o nome do arquivo <strong>{nome}</strong>, em {onde}.'),
    'link': N('Trocar o nome do link simbólico <strong>{nome}</strong>, em {onde}.'),
    'especial': N('Trocar o nome do arquivo especial <strong>{nome}</strong>, em {onde}.'),
}
APAGAR = {
    'pasta': N('Apagar a pasta <strong>{nome}</strong> e <strong>tudo o que há dentro dela</strong>: {arquivos} arquivo(s), '
               '{tamanho}, em {onde}?'),
    'arquivo': N('Apagar o arquivo <strong>{nome}</strong>, de {tamanho}, modificado em {quando}, em {onde}?'),
    'link': N('Apagar o link simbólico <strong>{nome}</strong>; o destino dele não é tocado, em {onde}?'),
    'especial': N('Apagar o arquivo especial <strong>{nome}</strong>; o destino dele não é tocado, em {onde}?'),
}
DE_USUARIO = {
    'renomeada': N('A pasta <strong>{nome}</strong> não é renomeada por aqui: é a pasta, ou tem dentro dela a pasta, de {de_quem}.'),
    'apagada': N('A pasta <strong>{nome}</strong> não é apagada por aqui: é a pasta, ou tem dentro dela a pasta, de {de_quem}.'),
}
LIBERADA = {
    'renomeada': N('A pasta <strong>{nome}</strong> não é renomeada por aqui: ela, ou uma pasta dentro dela, está liberada a '
                   '{de_quem} em Outras pastas.'),
    'apagada': N('A pasta <strong>{nome}</strong> não é apagada por aqui: ela, ou uma pasta dentro dela, está liberada a '
                 '{de_quem} em Outras pastas.'),
}
# renameat2 da libc: é o kernel que recusa o nome que já existe, sem intervalo entre conferir e trocar.
LIBC = ctypes.CDLL(None, use_errno=True)
LIBC.renameat2.argtypes = (ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint)
RENAME_NOREPLACE = 1


AREA_DE_ENTRADA = '.entrada'   # área do perfil só envio, na raiz dos dados: é do servidor, o painel não entra nela


class Recusado(Exception):
    """Caminho que tenta sair da pasta dos dados, passa por link simbólico ou não existe."""

    def __init__(self, codigo):
        super().__init__(codigo)
        self.codigo = codigo


class Interrompido(Exception):
    """Apagamento que parou no limite de itens ou de tempo de um pedido."""


def visivel(nome):
    """Nome de arquivo pronto para a tela: byte fora do UTF-8 vira o sinal de substituição."""
    return nome.encode('utf-8', 'surrogateescape').decode('utf-8', 'replace')


def endereco(rota, campo, caminho):
    return f'{rota}?{campo}=' + urllib.parse.quote(caminho, safe='/', errors='surrogateescape')


def parametro(pedido, nome):
    """Valor da consulta com os bytes do nome preservados: arquivo com nome fora do UTF-8 também abre."""
    try:
        campos = urllib.parse.parse_qs(urllib.parse.urlsplit(pedido.path).query, max_num_fields=5, errors='surrogateescape')
    except ValueError:
        return ''
    return campos.get(nome, [''])[0]


def partes(caminho):
    """Caminho relativo à pasta dos dados, parte por parte. Recusa o que tenta sair dela."""
    if len(caminho) > 4096 or '\x00' in caminho:
        raise Recusado(400)
    lista = caminho.split('/') if caminho else []
    for parte in lista:
        if parte in ('', '.', '..') or len(os.fsencode(parte)) > 255:
            raise Recusado(400)
    return lista


def abrir(lista, pasta):
    """Abre a partir da pasta dos dados, uma parte por vez e sempre em relação à anterior, sem seguir
    link simbólico em nenhuma: o que foi conferido é o que fica aberto. Devolve o descritor."""
    if lista and lista[0] == AREA_DE_ENTRADA:
        raise Recusado(404)
    atual = os.open(PASTA_DADOS, os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
    try:
        for indice, parte in enumerate(lista):
            final = indice == len(lista) - 1 and not pasta
            try:
                proximo = os.open(parte, ABRIR if final else ABRIR | os.O_DIRECTORY, dir_fd=atual)
            except OSError:
                try:
                    link = stat.S_ISLNK(os.lstat(parte, dir_fd=atual).st_mode)
                except OSError:
                    link = False
                raise Recusado(403 if link else 404) from None
            os.close(atual)
            atual = proximo
        if not pasta and not stat.S_ISREG(os.fstat(atual).st_mode):
            raise Recusado(404)
    except BaseException:
        os.close(atual)
        raise
    return atual


class Vista:
    """De onde quem está na sessão vê os arquivos: o administrador, da pasta dos dados, pela aba Arquivos; o usuário
    do FTP, da pasta do cadastro dele, pela tela Meus arquivos, ou de outra pasta que o administrador liberou a
    ele, pela tela dela (a sessão chega com essa pasta e com `area`, postas pelo roteamento a cada pedido). O
    caminho que vem do navegador é sempre relativo à raiz da vista, e é a raiz que o prende ali."""

    def __init__(self, sessao):
        self.usuario = sessao['usuario']
        self.area = sessao.get('area', '')
        if self.area:
            self.rota, self.tela, self.inicio = f'/pastas/{self.area}', N('Pasta liberada'), sessao['pasta']
        elif self.usuario:
            self.rota, self.tela, self.inicio = '/meus-arquivos', N('Meus arquivos'), t('Início')
        else:
            self.rota, self.tela, self.inicio = '/arquivos', N('Arquivos'), CFG['pasta_host']
        self.raiz = partes(sessao['pasta']) if self.usuario else []

    def real(self, caminho):
        """O mesmo caminho a partir da pasta dos dados: é o que vai para a auditoria e para a conta do cadastro."""
        return '/'.join(self.raiz + ([caminho] if caminho else []))


def recusa(pedido, sessao, erro, caminho):
    v = Vista(sessao)
    if erro.codigo != 404:
        auditar(pedido.ip, 'recusa_caminho', f'{quem(sessao)} caminho={limpo(caminho, 120)}')
    pedido.enviar(erro.codigo, pagina(t(v.tela), f'<section class="cartao"><h1>{t("Pedido recusado")}</h1>'
                                      f'<p>{e(t(RECUSAS[erro.codigo]))}</p>'
                                      f'<p><a href="{v.rota}">{t("Voltar para {tela}", tela=t(v.tela))}</a></p></section>',
                                      sessao, v.rota))


def conteudo(descritor):
    """Pastas e arquivos de uma pasta já aberta, em ordem de nome, até o limite de itens."""
    pastas, arquivos, cortado = [], [], False
    with os.scandir(descritor) as itens:
        for item in itens:
            if len(pastas) + len(arquivos) >= LISTA_MAX:
                cortado = True
                break
            try:
                dados = item.stat(follow_symlinks=False)
            except OSError:
                continue
            (pastas if stat.S_ISDIR(dados.st_mode) else arquivos).append((item.name, dados))
    return sorted(pastas), sorted(arquivos), cortado


def trilha(v, lista):
    """Caminho da pasta aberta, a partir da raiz da vista, com um link em cada nível."""
    inicio = e(v.inicio) if v.usuario else f'<code>{e(v.inicio)}</code>'
    if not lista:
        return f'<strong>{inicio}</strong>' if v.usuario else inicio
    niveis = [f'<a href="{v.rota}">{inicio}</a>']
    for indice, parte in enumerate(lista):
        if indice == len(lista) - 1:
            niveis.append(f'<strong>{e(visivel(parte))}</strong>')
        else:
            niveis.append(f'<a href="{e(endereco(v.rota, "pasta", "/".join(lista[:indice + 1])))}">{e(visivel(parte))}</a>')
    return ' / '.join(niveis)


def botoes_de_gestao(rota, item):
    """Renomear e Apagar de um item da lista: aparecem para o administrador e para o usuário de perfil completo."""
    return (f' <a class="botao" href="{e(endereco(rota + "/renomear", "item", item))}">{icone("lapis")}{t("Renomear")}</a>'
            f' <a class="botao perigo" href="{e(endereco(rota + "/apagar", "item", item))}">{icone("lixeira")}{t("Apagar")}</a>')


def linhas_da_lista(rota, caminho, pastas, arquivos, gerir=False, mais=None):
    """Linhas da tabela de uma pasta aberta; `rota` é a tela que mostra a lista e `caminho`, a pasta como ela a vê.
    Com `gerir`, cada linha ganha os botões de renomear e de apagar; `mais(caminho)` dá outros botões ao arquivo comum."""
    base = caminho + '/' if caminho else ''
    linhas = []
    do_tamanho, do_modificado = t('Tamanho'), t('Modificado')
    for nome, dados in pastas:
        gestao = botoes_de_gestao(rota, base + nome) if gerir else ''
        destino = e(endereco(rota, "pasta", base + nome))
        linhas.append(f'<tr><td><a class="item" href="{destino}">{icone("pasta")}<strong>{e(visivel(nome))}</strong></a></td>'
                      f'<td class="suave" data-rotulo="{do_tamanho}">{t("pasta")}</td>'
                      f'<td class="quando" data-rotulo="{do_modificado}">{e(quando(dados.st_mtime))}</td>'
                      f'<td class="acoes"><a class="botao" href="{destino}">{icone("pasta")}{t("Abrir")}</a>{gestao}</td></tr>')
    for nome, dados in arquivos:
        gestao = botoes_de_gestao(rota, base + nome) if gerir else ''
        if stat.S_ISREG(dados.st_mode):
            linhas.append(f'<tr><td><span class="item">{icone("arquivo")}{e(visivel(nome))}</span></td><td data-rotulo="{do_tamanho}">{e(tamanho(dados.st_size))}</td>'
                          f'<td class="quando" data-rotulo="{do_modificado}">{e(quando(dados.st_mtime))}</td>'
                          f'<td class="acoes"><a class="botao" href="{e(endereco(rota + "/baixar", "arquivo", base + nome))}" download>'
                          f'{icone("baixar")}{t("Baixar")}</a>{mais(base + nome) if mais else ""}{gestao}</td></tr>')
        else:
            tipo = t('link simbólico') if stat.S_ISLNK(dados.st_mode) else t('arquivo especial')
            linhas.append(f'<tr><td><span class="item">{icone("atalho")}{e(visivel(nome))}</span> <span class="etiqueta">{tipo}</span></td><td class="suave" data-rotulo="{do_tamanho}">—</td>'
                          f'<td class="quando" data-rotulo="{do_modificado}">{e(quando(dados.st_mtime))}</td><td class="acoes"><span class="suave sem-acao">{t("não abre aqui")}</span>'
                          f'{gestao}</td></tr>')
    # Na pasta liberada (/pastas/<identificador>) a conta não entra por FTP: o texto da lista vazia não fala dele.
    return ''.join(linhas) or vazio(4, 'pasta', t('Pasta vazia'), t('O que for gravado nela aparece aqui.') if rota.startswith('/pastas/')
                                    else t('O que for enviado para ela por FTP aparece aqui.'))


def aviso_de_corte(cortado):
    return ('<p class="aviso">'
            + t('Esta pasta tem mais de {maximo} itens: a lista mostra só os primeiros {maximo}. Para ver todos, entre por FTP.',
                maximo=LISTA_MAX) + '</p>') if cortado else ''


def liberada_a(caminho):
    """Linha da aba Arquivos com os usuários que abrem esta pasta no painel por liberação: a liberada é ela ou uma
    acima dela. Vazia quando não há nenhum."""
    contas = sorted({nome for nome, pasta, _ in pastas.com_acesso(caminho) if pasta == caminho or caminho.startswith(pasta + '/')})
    return ('<p class="suave">' + t('Pasta liberada no painel a: <strong>{contas}</strong>.', contas=e(', '.join(contas))) + '</p>'
            ) if contas else ''


def lista_arquivos(pedido, sessao, consulta, formulario, token):
    caminho = parametro(pedido, 'pasta')
    try:
        lista = partes(caminho)
        descritor = abrir(lista, pasta=True)
    except Recusado as erro:
        return recusa(pedido, sessao, erro, caminho)
    try:
        pastas, arquivos, cortado = conteudo(descritor)
    except OSError:
        pastas, arquivos, cortado = [], [], False
    finally:
        os.close(descritor)
    if not lista:
        pastas = [item for item in pastas if item[0] != AREA_DE_ENTRADA]
    import aba_destinos   # aqui, e não no alto do arquivo: destinos.py usa as funções deste módulo
    para_destinos, botoes = aba_destinos.botoes_do_arquivo(sessao)
    corpo, aviso = linhas_da_lista('/arquivos', caminho, pastas, arquivos, gerir=True, mais=botoes), aviso_de_corte(cortado)
    feito = MENSAGENS.get(consulta.get('m', ''), '')
    do_destino, falha = aba_destinos.volta_do_arquivo(consulta)
    donos = [nome for nome, dele in usuarios().items() if dele == caminho] if caminho else []
    de_quem = ('<p class="suave">' + t('Pasta do usuário do FTP: <strong>{donos}</strong>.', donos=e(', '.join(donos))) + '</p>'
               ) if donos else ''
    de_quem += liberada_a(caminho) if caminho else ''
    novo_usuario = (f' <a class="botao" href="{e(endereco("/usuarios/novo", "pasta", caminho))}">{t("Novo usuário nesta pasta")}</a>'
                    if PASTA.fullmatch(caminho) else '')
    ajuda = ('<p class="suave">'
             + t('O painel navega, baixa, envia arquivo, cria pasta, troca o nome e apaga; arquivo enviado não substitui outro. '
                 'Trocar o nome e apagar pedem a sua senha atual, e apagar não tem lixeira. Todo download e toda alteração ficam registrados na aba '
                 'Log.') + '</p>')
    pedido.enviar(200, pagina(t('Arquivos'), f'''{cabeca('Arquivos', t('O que os equipamentos já enviaram, pasta por pasta.'))}
{f'<p class="ok" role="status">{e(t(feito) if feito else do_destino)}</p>' if feito or do_destino else ''}
{f'<p class="erro" role="alert">{e(falha)}</p>' if falha else ''}
<p class="trilha">{trilha(Vista(sessao), lista)}{novo_usuario}</p>
{para_destinos}{de_quem}{aviso}<section class="cartao lista"><div class="rolagem"><table class="blocos itens">
<thead><tr><th>{t('Nome')}</th><th>{t('Tamanho')}</th><th>{t('Modificado')}</th><th>{t('Ações')}</th></tr></thead>
<tbody>{corpo}</tbody></table></div>
{como(t('O que dá para fazer nesta aba'), ajuda)}</section>
{formulario_envio(sessao, caminho)}
{formulario_nova_pasta(sessao, caminho)}''', sessao, '/arquivos'))


def formulario_nova_pasta(sessao, caminho):
    """Formulário que cria uma pasta dentro da que está aberta. Não aparece se o caminho tem byte fora do UTF-8,
    que o formulário não consegue devolver."""
    try:
        caminho.encode('utf-8')
    except UnicodeEncodeError:
        return ''
    v = Vista(sessao)
    nasce = (t('A pasta nasce vazia, dentro desta pasta liberada.') if v.area else
             t('A pasta nasce vazia, dentro da sua pasta no FTP.') if v.usuario else
             t('A pasta nasce vazia; para um equipamento gravar nela, crie um usuário com esta pasta.'))
    dentro = f'{e(v.inicio)}{"/" + e(caminho) if caminho else ""}'
    return f'''<section class="cartao estreito"><h2>{t('Nova pasta')}</h2>
<form method="post" action="{v.rota}/pasta" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<input type="hidden" name="pasta" value="{e(caminho)}">
<label for="nome">{t('Nome da pasta, criada dentro de <code>{onde}</code>', onde=dentro)}</label>
<input id="nome" name="nome" required maxlength="64" pattern="[A-Za-z0-9_][A-Za-z0-9._\\-]*" autocapitalize="none" spellcheck="false">
<p class="suave">{t(REGRA_DO_ITEM)}
{nasce}</p>
<button type="submit">{t('Criar pasta')}</button>
</form></section>'''


def resposta_pasta(pedido, sessao, codigo, titulo, texto, caminho):
    """`titulo` e `texto` chegam no idioma da tela."""
    v = Vista(sessao)
    pedido.enviar(codigo, pagina(t(v.tela), f'<section class="cartao"><h1>{titulo}</h1><p>{e(texto)}</p>'
                                 f'<p><a href="{e(endereco(v.rota, "pasta", caminho))}">{t("Voltar para a pasta")}</a></p></section>',
                                 sessao, v.rota))


def criar_pasta(pedido, sessao, consulta, formulario, token):
    """Cria uma pasta vazia dentro de uma pasta que já existe, com o dono e o modo das pastas do FTP.
    A pasta de cima é aberta parte por parte, sem seguir link simbólico, e a nova nasce em relação a ela."""
    v = Vista(sessao)
    caminho, nome = formulario.get('pasta', ''), formulario.get('nome', '').strip()
    novo = f'{caminho}/{nome}' if caminho else nome
    try:
        lista = v.raiz + partes(caminho)
        if not NIVEL.fullmatch(nome):
            auditar(pedido.ip, 'recusa_caminho', f'{quem(sessao)} caminho={limpo(novo, 120)}')
            return resposta_pasta(pedido, sessao, 400, t('Nome não aceito'),
                                  t('Use letras, números, _, - e ponto; o nome não começa com ponto e tem até 64 caracteres.'),
                                  caminho)
        descritor = abrir(lista, pasta=True)
    except Recusado as erro:
        return recusa(pedido, sessao, erro, novo)
    try:
        dono = pwd.getpwnam(DONO_DADOS)
        # Dentro de outra pasta, a nova acompanha o modo dela: é ele que diz o que cada perfil de usuário do FTP
        # alcança ali (grupo que grava e bit de permanência para o envio, "outros" para a leitura).
        modo = (os.fstat(descritor).st_mode & 0o1775) | 0o750 if lista else 0o750
        os.mkdir(nome, 0o750, dir_fd=descritor)
        feita = os.open(nome, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=descritor)
        try:
            os.fchmod(feita, modo)
            os.fchown(feita, dono.pw_uid, dono.pw_gid)
        finally:
            os.close(feita)
    except FileExistsError:
        return resposta_pasta(pedido, sessao, 409, t('Nome já usado'), t('Já existe uma pasta ou um arquivo com este nome.'),
                              caminho)
    except (OSError, KeyError):
        auditar(pedido.ip, 'falha_comando', f'{quem(sessao)} acao=criar_pasta pasta={limpo(v.real(novo), 200)}')
        return resposta_pasta(pedido, sessao, 500, t('Pasta não criada'), t('Não foi possível criar a pasta.'), caminho)
    finally:
        os.close(descritor)
    auditar(pedido.ip, 'pasta_criada', f'{quem(sessao)} pasta={limpo(v.real(novo), 200)}')
    return pedido.redirecionar(endereco(v.rota, 'pasta', caminho) + '&m=criada')


def campo_do_item(caminho):
    """Campo escondido com o caminho do item. Vai codificado: nome com byte fora do UTF-8 também volta inteiro."""
    return f'<input type="hidden" name="item" value="{e(urllib.parse.quote(caminho, safe="/", errors="surrogateescape"))}">'


def item_do_formulario(formulario):
    return urllib.parse.unquote(formulario.get('item', ''), errors='surrogateescape')


def situar(caminho, raiz=()):
    """Abre a pasta de cima do item e confere que ele existe, sem segui-lo se for link simbólico. O caminho é
    relativo à `raiz`: a pasta dos dados ou, na vista de um usuário do FTP, a pasta dele.
    Devolve (partes do caminho, descritor da pasta de cima, dados do item); quem chama fecha o descritor."""
    lista = partes(caminho)
    if not lista:
        raise Recusado(400)
    if not raiz and lista[0] == AREA_DE_ENTRADA:
        raise Recusado(404)
    acima = abrir([*raiz, *lista[:-1]], pasta=True)
    try:
        dados = os.lstat(lista[-1], dir_fd=acima)
    except OSError:
        os.close(acima)
        raise Recusado(404) from None
    return lista, acima, dados


def tipo_de(dados):
    """Tipo do item: a palavra que vai para a auditoria e que escolhe a frase da tela."""
    if stat.S_ISDIR(dados.st_mode):
        return 'pasta'
    if stat.S_ISREG(dados.st_mode):
        return 'arquivo'
    if stat.S_ISLNK(dados.st_mode):
        return 'link'
    return 'especial'


def usuarios_presos(caminho):
    """Usuários do FTP presos a este caminho (a partir da pasta dos dados) ou ao que há dentro dele: (os que têm ali
    a pasta do cadastro, os que têm ali outra pasta liberada); vazio se não há nenhum. Trocar o nome da pasta ou
    apagá-la por aqui deixaria os primeiros sem ter onde entrar e os outros com a liberação apontando para nada."""
    donos = [nome for nome, dele in usuarios().items() if dele and (dele == caminho or dele.startswith(caminho + '/'))]
    com_liberada = pastas.presos(caminho)
    return (donos, com_liberada) if donos or com_liberada else ()


def pasta_de_usuario(pedido, sessao, lista, presos, feita):
    v = Vista(sessao)
    donos, com_liberada = presos
    frase, titulo = (DE_USUARIO, t('Pasta de usuário do FTP')) if donos else (LIBERADA, t('Pasta liberada a usuário do FTP'))
    if v.usuario:  # quem são os outros usuários é assunto do administrador: a tela dele não diz os nomes
        de_quem = t('outro usuário do FTP') if donos else t('uma conta do FTP')
        saida = t('Peça ao administrador do painel.')
    elif donos:
        de_quem = f'<strong>{e(", ".join(donos))}</strong>'
        saida = t('Para dar outra pasta a um usuário, use <strong>Usuários ➜ Editar</strong>. Para apagar a pasta junto com '
                  'o usuário, use <strong>Usuários ➜ Remover</strong>.')
    else:
        de_quem = f'<strong>{e(", ".join(com_liberada))}</strong>'
        saida = t('Para retirar a pasta de um usuário, use <strong>Usuários ➜ Editar ➜ Outras pastas</strong>.')
    pedido.enviar(409, pagina(t(v.tela), f'''<section class="cartao"><h1>{titulo}</h1>
<p>{t(frase[feita], nome=e(visivel(lista[-1])), de_quem=de_quem)}</p>
<p>{saida} {t('O que está dentro dela pode ser renomeado e apagado item por item.')}</p>
<p><a href="{e(endereco(v.rota, "pasta", "/".join(lista[:-1])))}">{t('Voltar para a pasta')}</a></p></section>''', sessao, v.rota))


def onde_fica(v, lista):
    """Pasta de cima do item, como quem está na sessão a vê: o administrador, no host; o usuário do FTP, na pasta dele."""
    return f'<code>{e(v.inicio)}{"".join("/" + e(visivel(parte)) for parte in lista[:-1])}</code>'


def trocar_nome(descritor, antigo, novo):
    """Troca o nome dentro da mesma pasta, sem nunca passar por cima de outro item. Levanta FileExistsError
    se o nome novo já existe. Em sistema de arquivos sem RENAME_NOREPLACE (EINVAL), confere e troca em dois passos."""
    if LIBC.renameat2(descritor, os.fsencode(antigo), descritor, os.fsencode(novo), RENAME_NOREPLACE) == 0:
        return
    codigo = ctypes.get_errno()
    if codigo != errno.EINVAL:
        raise OSError(codigo, os.strerror(codigo))
    try:
        os.lstat(novo, dir_fd=descritor)
    except FileNotFoundError:
        os.rename(antigo, novo, src_dir_fd=descritor, dst_dir_fd=descritor)
    else:
        raise FileExistsError(errno.EEXIST, os.strerror(errno.EEXIST))


def tela_renomear(pedido, sessao, consulta, formulario=None, token=None, erro='', codigo=200, caminho=None, novo=''):
    v = Vista(sessao)
    caminho = parametro(pedido, 'item') if caminho is None else caminho
    try:
        lista, acima, dados = situar(caminho, v.raiz)
    except Recusado as motivo:
        return recusa(pedido, sessao, motivo, caminho)
    os.close(acima)
    presos = usuarios_presos(v.real(caminho)) if stat.S_ISDIR(dados.st_mode) else []
    if presos:
        return pasta_de_usuario(pedido, sessao, lista, presos, 'renomeada')
    volta = endereco(v.rota, 'pasta', '/'.join(lista[:-1]))
    return pedido.enviar(codigo, pagina(t('Renomear'), f'''<h1>{t('Renomear')}</h1>
<section class="cartao estreito">{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<p>{t(RENOMEAR[tipo_de(dados)], nome=e(visivel(lista[-1])), onde=onde_fica(v, lista))}</p>
<form method="post" action="{v.rota}/renomear" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
{campo_do_item(caminho)}
<label for="nome">{t('Nome novo')}</label>
<input id="nome" name="nome" required maxlength="64" pattern="[A-Za-z0-9_][A-Za-z0-9._\\-]*" value="{e(novo)}" autocapitalize="none" spellcheck="false">
<p class="suave">{t(REGRA_DO_ITEM)}
{t('O item continua na mesma pasta: o painel não move de uma pasta para outra. O equipamento que grava com o nome antigo '
   'cria outro arquivo no envio seguinte.')}</p>
{campo_senha_atual(sessao)}
<button type="submit">{t('Trocar nome')}</button> <a class="botao" href="{e(volta)}">{t('Cancelar')}</a>
</form></section>''', sessao, v.rota))


def renomear(pedido, sessao, consulta, formulario, token):
    """Troca o nome de um arquivo ou de uma pasta, dentro da mesma pasta. Pede a senha de quem está na sessão. O
    nome novo segue a regra do nome de pasta; a pasta de um usuário do FTP, a liberada a um deles, ou a que tem uma
    dessas dentro, não é renomeada por aqui."""
    v = Vista(sessao)
    caminho, novo = item_do_formulario(formulario), formulario.get('nome', '').strip()
    try:
        lista, acima, dados = situar(caminho, v.raiz)
    except Recusado as motivo:
        return recusa(pedido, sessao, motivo, caminho)
    de_cima = '/'.join(lista[:-1])
    destino = f'{de_cima}/{novo}' if de_cima else novo
    try:
        if not NIVEL.fullmatch(novo):
            auditar(pedido.ip, 'recusa_caminho', f'{quem(sessao)} caminho={limpo(destino, 120)}')
            return tela_renomear(pedido, sessao, consulta, erro=t('Nome não aceito. Veja a regra abaixo do campo.'), codigo=400,
                                 caminho=caminho)
        presos = usuarios_presos(v.real(caminho)) if stat.S_ISDIR(dados.st_mode) else []
        if presos:
            return pasta_de_usuario(pedido, sessao, lista, presos, 'renomeada')
        if novo == lista[-1]:
            return tela_renomear(pedido, sessao, consulta, erro=t('O item já tem este nome.'), codigo=409, caminho=caminho, novo=novo)
        codigo, erro = confirmacao_recusada(pedido, sessao, formulario)
        if codigo:
            return tela_renomear(pedido, sessao, consulta, erro=erro, codigo=codigo, caminho=caminho, novo=novo)
        try:
            trocar_nome(acima, lista[-1], novo)
        except FileExistsError:
            return tela_renomear(pedido, sessao, consulta, erro=t('Já existe uma pasta ou um arquivo com este nome.'), codigo=409,
                                 caminho=caminho, novo=novo)
        except OSError:
            auditar(pedido.ip, 'falha_comando', f'{quem(sessao)} acao=renomear caminho={limpo(v.real(caminho), 200)}')
            return tela_renomear(pedido, sessao, consulta, erro=t('Não foi possível trocar o nome.'), codigo=500, caminho=caminho,
                                 novo=novo)
    finally:
        os.close(acima)
    limpar_cache()
    auditar(pedido.ip, 'item_renomeado', f'{quem(sessao)} tipo={tipo_de(dados)} de={limpo(v.real(caminho), 200)} '
                                         f'para={limpo(v.real(destino), 200)}')
    return pedido.redirecionar(endereco(v.rota, 'pasta', de_cima) + '&m=renomeado')


def apagar_entrada(acima, nome, pasta, estado, nivel=0):
    """Apaga um item em relação à pasta de cima já aberta. A pasta é aberta sem seguir link simbólico e esvaziada
    de dentro para fora, sempre pelo descritor dela: link simbólico é apagado, o destino dele nunca é tocado.
    A lista é lida em lotes, para a pasta com muitos arquivos não ocupar a memória do painel."""
    if pasta:
        if nivel >= APAGAR_NIVEIS:
            raise OSError(errno.ELOOP, 'pastas demais uma dentro da outra')
        dentro = os.open(nome, ABRIR | os.O_DIRECTORY, dir_fd=acima)
        try:
            while True:
                with os.scandir(dentro) as itens:
                    lote = [(item.name, item.is_dir(follow_symlinks=False)) for item in itertools.islice(itens, 1000)]
                if not lote:
                    break
                for filho, e_pasta in lote:
                    if estado['itens'] >= APAGAR_MAX or time.monotonic() > estado['prazo']:
                        raise Interrompido()
                    try:
                        apagar_entrada(dentro, filho, e_pasta, estado, nivel + 1)
                    except FileNotFoundError:
                        pass  # saiu por FTP no meio da limpeza
        finally:
            os.close(dentro)
        os.rmdir(nome, dir_fd=acima)
    else:
        os.unlink(nome, dir_fd=acima)
    estado['itens'] += 1


def apagar_item(acima, nome, pasta):
    """Apaga o item e devolve (itens apagados, motivo da parada). O motivo é '' quando tudo foi apagado;
    senão é uma das chaves de PARADAS, e o que já foi apagado continua apagado."""
    if not TRAVA_APAGAR.acquire(blocking=False):
        return 0, 'ocupado'
    estado = {'itens': 0, 'prazo': time.monotonic() + APAGAR_PRAZO}
    try:
        apagar_entrada(acima, nome, pasta, estado)
    except Interrompido:
        return estado['itens'], 'limite'
    except OSError:
        return estado['itens'], 'erro'
    finally:
        TRAVA_APAGAR.release()
        limpar_cache()
    return estado['itens'], ''


def apagar_caminho(caminho):
    """Apaga a pasta ou o arquivo deste caminho, relativo à pasta dos dados. Devolve o mesmo que apagar_item;
    levanta Recusado se o caminho não é aceito, passa por link simbólico ou não existe."""
    lista, acima, dados = situar(caminho)
    try:
        return apagar_item(acima, lista[-1], stat.S_ISDIR(dados.st_mode))
    finally:
        os.close(acima)


def tela_apagar(pedido, sessao, consulta, formulario=None, token=None, erro='', codigo=200, caminho=None):
    v = Vista(sessao)
    caminho = parametro(pedido, 'item') if caminho is None else caminho
    try:
        lista, acima, dados = situar(caminho, v.raiz)
    except Recusado as motivo:
        return recusa(pedido, sessao, motivo, caminho)
    os.close(acima)
    nome, onde, tipo = e(visivel(lista[-1])), onde_fica(v, lista), tipo_de(dados)
    if tipo == 'pasta':
        presos = usuarios_presos(v.real(caminho))
        if presos:
            return pasta_de_usuario(pedido, sessao, lista, presos, 'apagada')
        uso = uso_da_pasta(v.real(caminho), validade=0)
        mais = ' ' + t('ou mais') if uso['parcial'] else ''
        pergunta = t(APAGAR[tipo], nome=nome, onde=onde, arquivos=f'{uso["arquivos"]}{mais}',
                     tamanho=e(tamanho(uso['bytes'])) + mais)
    elif tipo == 'arquivo':
        pergunta = t(APAGAR[tipo], nome=nome, onde=onde, tamanho=e(tamanho(dados.st_size)), quando=e(quando(dados.st_mtime)))
    else:
        pergunta = t(APAGAR[tipo], nome=nome, onde=onde)
    volta = endereco(v.rota, 'pasta', '/'.join(lista[:-1]))
    return pedido.enviar(codigo, pagina(t('Apagar'), f'''<h1>{t('Apagar')}</h1>
<section class="cartao estreito">{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<p>{pergunta}</p>
<p class="aviso">{t('O painel <strong>não tem lixeira</strong>: o que for apagado só volta de uma cópia de segurança.')}</p>
<form method="post" action="{v.rota}/apagar" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
{campo_do_item(caminho)}
<label class="marcar"><input type="checkbox" name="confirmar" value="sim" required> {t('Conferi o nome e quero apagar')}</label>
{campo_senha_atual(sessao, para=t('para apagar'))}
<button class="perigo" type="submit">{t('Apagar de vez')}</button> <a class="botao" href="{e(volta)}">{t('Cancelar')}</a>
</form></section>''', sessao, v.rota))


def apagar(pedido, sessao, consulta, formulario, token):
    """Apaga um arquivo, ou uma pasta com tudo o que há nela. Pede a caixa de confirmação e a senha de quem está
    na sessão; a pasta de um usuário do FTP, ou a que tem uma dentro, só sai junto com o usuário, e a liberada a um
    deles, depois de retirada."""
    v = Vista(sessao)
    caminho = item_do_formulario(formulario)
    try:
        lista, acima, dados = situar(caminho, v.raiz)
    except Recusado as motivo:
        return recusa(pedido, sessao, motivo, caminho)
    try:
        pasta = stat.S_ISDIR(dados.st_mode)
        presos = usuarios_presos(v.real(caminho)) if pasta else []
        if presos:
            return pasta_de_usuario(pedido, sessao, lista, presos, 'apagada')
        if formulario.get('confirmar') != 'sim':
            return tela_apagar(pedido, sessao, consulta, erro=t('Marque a caixa de confirmação. Nada foi apagado.'), codigo=400,
                               caminho=caminho)
        codigo, erro = confirmacao_recusada(pedido, sessao, formulario, apagando=True)
        if codigo:
            return tela_apagar(pedido, sessao, consulta, erro=erro, codigo=codigo, caminho=caminho)
        itens, parada = apagar_item(acima, lista[-1], pasta)
    finally:
        os.close(acima)
    registro = f'{quem(sessao)} tipo={tipo_de(dados)} caminho={limpo(v.real(caminho), 200)}'
    de_cima = '/'.join(lista[:-1])
    if not parada:
        auditar(pedido.ip, 'item_apagado', f'{registro} itens={itens}')
        return pedido.redirecionar(endereco(v.rota, 'pasta', de_cima) + '&m=apagado')
    if itens:
        auditar(pedido.ip, 'item_apagado', f'{registro} itens={itens} completo=nao')
    elif parada != 'ocupado':
        auditar(pedido.ip, 'falha_comando', f'{quem(sessao)} acao=apagar caminho={limpo(v.real(caminho), 200)}')
    return resposta_parcial(pedido, sessao, itens, parada, endereco(v.rota + '/apagar', 'item', caminho),
                            endereco(v.rota, 'pasta', de_cima), v.rota)


def resposta_parcial(pedido, sessao, itens, parada, repetir, volta, aba):
    """Apagamento que não chegou ao fim: diz quanto saiu, por que parou e onde repetir."""
    codigo = 503 if parada == 'ocupado' else 200 if itens else 500
    titulo = t('Apagado em parte') if itens else t('Nada foi apagado')
    feito = ('<p>' + t('<strong>{itens}</strong> item(ns) apagado(s); o restante continua no lugar.', itens=itens) + '</p>'
             ) if itens else ''
    motivo = t(PARADAS[parada], maximo=APAGAR_MAX, prazo=APAGAR_PRAZO)
    return pedido.enviar(codigo, pagina(t('Apagar'), f'<section class="cartao"><h1>{titulo}</h1>{feito}<p>{e(motivo)}</p>'
                                        f'<p><a class="botao" href="{e(repetir)}">{t("Repetir")}</a> '
                                        f'<a class="botao" href="{e(volta)}">{t("Voltar")}</a></p>'
                                        '</section>', sessao, aba),
                         extras=(('Retry-After', '30'),) if parada == 'ocupado' else ())


def formulario_envio(sessao, caminho=''):
    """Formulário que envia um arquivo para a pasta que está aberta. O arquivo é o último campo: o painel lê os de
    texto, e confere a sessão, antes de receber o conteúdo (envio.py). Não aparece se o caminho tem byte fora do
    UTF-8, que o formulário não consegue devolver."""
    try:
        caminho.encode('utf-8')
    except UnicodeEncodeError:
        return ''
    v = Vista(sessao)
    if v.usuario and sessao['perfil'] == 'soenvio':
        onde = t('Arquivo, guardado na pasta do usuário no servidor')
        repetido = t('Nome que já existe não substitui o anterior: o novo é guardado com a data e a hora no nome.')
    else:
        onde = t('Arquivo, gravado em <code>{onde}</code>', onde=f'{e(v.inicio)}{"/" + e(caminho) if caminho else ""}')
        repetido = t('Nome que já existe na pasta não é substituído: o envio é recusado.')
    return f'''<section class="cartao estreito"><h2>{t('Enviar arquivo')}</h2>
<form method="post" action="{v.rota}/enviar" enctype="multipart/form-data" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<input type="hidden" name="pasta" value="{e(caminho)}">
<label for="gravar-como">{t('Gravar com o nome <span class="suave">(deixe em branco para manter o nome do arquivo)</span>')}</label>
<input id="gravar-como" name="nome" maxlength="64" pattern="[A-Za-z0-9_][A-Za-z0-9._\\-]*" autocapitalize="none" spellcheck="false">
<label for="arquivo">{onde}</label>
<input id="arquivo" name="arquivo" type="file" required>
<p class="suave">{t(REGRA_DO_ITEM)}
{t('Até {maximo} por arquivo.', maximo=e(tamanho(CFG['envio_max'])))} {repetido}</p>
<button type="submit">{t('Enviar arquivo')}</button>
</form></section>'''


def nomes_com_data(nome):
    """Perfil só envio: os nomes a tentar quando o arquivo já existe, pela regra da área de entrada do FTP
    (ftp/entrada.pl): data e hora antes da extensão e, se ainda assim repetir, um número."""
    achado = re.fullmatch(r'(.+?)((?:\.tar)?\.[A-Za-z0-9]{1,10})', nome)
    base, extensao = achado.groups() if achado else (nome, '')
    marca = time.strftime('-%Y%m%d-%H%M%S')
    return [f'{base}{marca}{f"-{vez}" if vez > 1 else ""}{extensao}' for vez in range(1, 100)]


def enviar(pedido, sessao, consulta, formulario, token):
    """Recebe um arquivo do navegador e o grava na pasta aberta, com o dono e o modo dos arquivos do FTP. O arquivo
    é escrito sem nome (O_TMPFILE) na própria pasta de destino e só ganha nome depois de chegar inteiro, por link():
    envio que cai no meio não deixa resto, e nome que já existe nunca é substituído. O administrador sempre envia;
    o usuário do FTP, só com a permissão dele, lida a cada envio, na taxa de envio dele e um arquivo por vez."""
    v, corpo, usuario = Vista(sessao), pedido.corpo, sessao['usuario']
    so_envia = bool(usuario) and sessao['perfil'] == 'soenvio'
    caminho = '' if so_envia else formulario.get('pasta', '')
    permitido, taxa = envio_pelo_painel(usuario) if usuario else (True, 0)
    if not permitido:
        auditar(pedido.ip, 'recusa_envio', f'{quem(sessao)} perfil={sessao["perfil"]}')
        return resposta_pasta(pedido, sessao, 403, t('Envio não permitido'),
                              t('Esta conta não tem a permissão de enviar arquivo pelo painel. Quem dá a permissão é um '
                                'administrador.'), caminho)
    nome = formulario.get('nome', '').strip() or re.split(r'[/\\]', corpo.arquivo)[-1].strip()
    destino = f'{caminho}/{nome}' if caminho else nome
    bytes_do_arquivo = corpo.tamanho()
    if bytes_do_arquivo < 0:
        return pedido.recusar(400, t('Envio malformado.'))
    try:
        lista = v.raiz + partes(caminho)
        if not corpo.arquivo:
            return resposta_pasta(pedido, sessao, 400, t('Nenhum arquivo escolhido'), t('Escolha o arquivo e envie de novo.'), caminho)
        if not NIVEL.fullmatch(nome):
            auditar(pedido.ip, 'recusa_caminho', f'{quem(sessao)} caminho={limpo(destino, 120)}')
            return resposta_pasta(pedido, sessao, 400, t('Nome não aceito'),
                                  t('O nome do arquivo usa letras, números, _, - e ponto, não começa com ponto e tem até 64 '
                                    'caracteres. Troque o nome do arquivo ou preencha o campo "Gravar com o nome".'), caminho)
        if bytes_do_arquivo > CFG['envio_max']:
            return resposta_pasta(pedido, sessao, 413, t('Arquivo grande demais'),
                                  t('Arquivo grande demais: o painel recebe até {maximo} por arquivo.', maximo=tamanho(CFG['envio_max'])),
                                  caminho)
        descritor = abrir(lista, pasta=True)
    except Recusado as erro:
        return recusa(pedido, sessao, erro, destino)
    limite = ''
    with TRAVA_CURSO:
        if usuario in ENVIANDO:
            limite = t('Esta conta envia um arquivo por vez.')
        elif not ENVIOS.acquire(blocking=False):
            limite = t('O painel recebe até {maximo} arquivos por vez.', maximo=ENVIOS_MAX)
        elif usuario:
            ENVIANDO.add(usuario)
    if limite:
        os.close(descritor)
        return pedido.enviar(503, pagina(t(v.tela), f'<section class="cartao"><h1>{t("Muitos envios ao mesmo tempo")}</h1>'
                                         f'<p>{limite} {t("Espere terminar e repita.")}</p>'
                                         f'<p><a href="{e(endereco(v.rota, "pasta", caminho))}">{t("Voltar para a pasta")}</a></p></section>',
                                         sessao, v.rota),
                             extras=(('Retry-After', '30'),))
    final = ''
    try:
        disco = os.fstatvfs(descritor)
        if bytes_do_arquivo > disco.f_bavail * disco.f_frsize:
            raise OSError(errno.ENOSPC, 'sem espaço')
        dono = pwd.getpwnam(DONO_DADOS)
        sem_nome = os.open('.', os.O_TMPFILE | os.O_WRONLY | os.O_CLOEXEC, 0o600, dir_fd=descritor)
        try:
            corpo.gravar(sem_nome, taxa)
            os.fchown(sem_nome, dono.pw_uid, dono.pw_gid)
            os.fchmod(sem_nome, 0o644)
            os.fsync(sem_nome)
            for tentativa in [nome] + (nomes_com_data(nome) if so_envia else []):
                try:
                    os.link(f'/proc/self/fd/{sem_nome}', tentativa, dst_dir_fd=descritor)
                except FileExistsError:
                    continue
                final = tentativa
                break
        finally:
            os.close(sem_nome)
    except envio.Cortado:
        auditar(pedido.ip, 'envio_interrompido', f'{quem(sessao)} arquivo={limpo(v.real(destino), 200)} bytes={bytes_do_arquivo}')
        try:
            return pedido.recusar(400, t('O envio parou antes do fim: nada foi gravado.'))
        except OSError:
            return None
    except envio.Malformado:
        return pedido.recusar(400, t('Envio malformado.'))
    except (OSError, KeyError) as erro:
        if getattr(erro, 'errno', None) in (errno.ENOSPC, errno.EDQUOT):
            auditar(pedido.ip, 'falha_comando', f'{quem(sessao)} acao=enviar motivo=sem_espaco arquivo={limpo(v.real(destino), 200)}')
            return resposta_pasta(pedido, sessao, 507, t('Sem espaço'), t('O servidor não tem espaço livre para este arquivo.'), caminho)
        auditar(pedido.ip, 'falha_comando', f'{quem(sessao)} acao=enviar arquivo={limpo(v.real(destino), 200)}')
        return resposta_pasta(pedido, sessao, 500, t('Arquivo não gravado'), t('Não foi possível gravar o arquivo.'), caminho)
    finally:
        os.close(descritor)
        ENVIOS.release()
        if usuario:
            with TRAVA_CURSO:
                ENVIANDO.discard(usuario)
    if not final:
        return resposta_pasta(pedido, sessao, 409, t('Nome já usado'), t('Já existe uma pasta ou um arquivo com este nome.'), caminho)
    limpar_cache()
    gravado = f'{caminho}/{final}' if caminho else final
    chegadas.chegou(v.real(gravado))   # o arquivo está inteiro no lugar: o bot do Telegram não precisa esperar por ele
    auditar(pedido.ip, 'arquivo_enviado', f'{quem(sessao)} arquivo={limpo(v.real(gravado), 200)} bytes={bytes_do_arquivo}')
    return pedido.redirecionar(endereco(v.rota, 'pasta', caminho) + ('&m=enviado' if final == nome else '&m=enviado_com_data'))


def anexo(nome):
    """Content-Disposition de anexo (RFC 6266): o navegador salva o arquivo, nunca abre. O nome vai duas
    vezes: reduzido a ASCII, para cliente antigo, e inteiro, em UTF-8 (RFC 8187)."""
    inteiro = visivel(nome)
    simples = re.sub(r'[^A-Za-z0-9._-]', '_', inteiro)[:150]
    return f'attachment; filename="{simples}"; filename*=UTF-8\'\'{urllib.parse.quote(inteiro, safe="")}'


def baixar(pedido, sessao, consulta, formulario, token):
    caminho = parametro(pedido, 'arquivo')
    try:
        lista = partes(caminho)
        if not lista:
            raise Recusado(404)
        descritor = abrir(lista, pasta=False)
    except Recusado as erro:
        return recusa(pedido, sessao, erro, caminho)
    return entregar(pedido, sessao, descritor, lista[-1], caminho)


def entregar(pedido, sessao, descritor, nome, registro):
    """Entrega como anexo um arquivo já aberto e registra o download. `registro` é o caminho que vai para a
    auditoria, relativo à pasta dos dados. Vale o teto geral de downloads e, para usuário do FTP, o teto e a
    taxa dele: os limites próprios, se ele tiver, ou os da stack."""
    if pedido.command == 'HEAD':  # só os cabeçalhos: nada é baixado, não ocupa vaga nem entra na auditoria
        with os.fdopen(descritor, 'rb', buffering=0) as arquivo:
            pedido.enviar_arquivo(arquivo, os.fstat(arquivo.fileno()).st_size, extras=(('Content-Disposition', anexo(nome)),))
        return None
    v = Vista(sessao)
    usuario, limite = sessao['usuario'], ''
    dele, taxa = downloads_e_taxa(usuario) if usuario else (0, 0)
    with TRAVA_CURSO:
        if usuario and EM_CURSO.get(usuario, 0) >= dele:
            limite = t('O limite deste usuário é de {quantos} arquivo(s) por vez.', quantos=dele)
        elif not VAGAS.acquire(blocking=False):
            limite = t('O painel entrega até {maximo} arquivos por vez.', maximo=DOWNLOADS_MAX)
        elif usuario:
            EM_CURSO[usuario] = EM_CURSO.get(usuario, 0) + 1
    if limite:
        os.close(descritor)
        return pedido.enviar(503, pagina(t(v.tela), f'<section class="cartao"><h1>{t("Muitos downloads ao mesmo tempo")}</h1>'
                                         f'<p>{limite} {t("Espere um deles terminar e repita.")}</p>'
                                         f'<p><a href="{v.rota}">{t("Voltar para {tela}", tela=t(v.tela))}</a></p></section>',
                                         sessao, v.rota),
                             extras=(('Retry-After', '30'),))
    try:
        with os.fdopen(descritor, 'rb', buffering=0) as arquivo:
            total = os.fstat(arquivo.fileno()).st_size
            enviados = pedido.enviar_arquivo(arquivo, total, extras=(('Content-Disposition', anexo(nome)),), taxa=taxa)
    finally:
        VAGAS.release()
        if usuario:
            with TRAVA_CURSO:
                EM_CURSO[usuario] -= 1
                if EM_CURSO[usuario] <= 0:
                    del EM_CURSO[usuario]
    evento = 'arquivo_baixado' if enviados == total else 'arquivo_interrompido'
    auditar(pedido.ip, evento, f'{quem(sessao)} arquivo={limpo(registro, 200)} bytes={enviados}')
    return None
