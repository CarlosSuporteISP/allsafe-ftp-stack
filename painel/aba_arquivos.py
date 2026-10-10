# SPDX-License-Identifier: Apache-2.0
"""Aba Arquivos: navegar pelas pastas dos usuários do FTP, baixar um arquivo pelo navegador, criar pasta,
trocar o nome e apagar.

O painel não envia arquivo. Apagar pede a caixa de confirmação e a senha de quem está na sessão. Toda alteração
é feita em relação à pasta de cima já aberta, sem seguir link simbólico. As mesmas funções servem à tela Meus
arquivos, do usuário do FTP: a Vista diz de onde cada um vê os arquivos, e a tabela de rotas do perfil (rotas.py)
diz quais destas ações existem para ele."""
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

from auditoria import auditar, limpo
from config import APAGAR_MAX, APAGAR_NIVEIS, APAGAR_PRAZO, CFG, DONO_DADOS, DOWNLOADS_MAX, LISTA_MAX, NIVEL, PASTA, PASTA_DADOS
from confirmacao import campo_senha_atual, confirmacao_recusada
from estado import limpar_cache, uso_da_pasta, usuarios
from icones import icone
from limites import downloads_e_taxa
from pagina import cabeca, e, pagina, quando, tamanho
from sessao import quem

VAGAS = threading.BoundedSemaphore(DOWNLOADS_MAX)
TRAVA_CURSO = threading.Lock()
EM_CURSO = {}  # usuário do FTP → downloads dele em andamento
# Nenhuma parte do caminho é seguida se for link simbólico; O_NONBLOCK não deixa um FIFO prender o pedido.
ABRIR = os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK
RECUSAS = {
    400: 'Caminho não aceito.',
    403: 'Link simbólico não é seguido pelo painel.',
    404: 'Pasta ou arquivo não encontrado.',
}
MENSAGENS = {'criada': 'Pasta criada.', 'renomeado': 'Nome trocado.', 'apagado': 'Apagado.'}
TRAVA_APAGAR = threading.Lock()  # um apagamento por vez: os outros pedidos do painel seguem atendidos
PARADAS = {
    'limite': f'A pasta tem mais do que o painel apaga de uma vez ({APAGAR_MAX} itens ou {APAGAR_PRAZO} segundos por pedido). '
              'Repita para continuar.',
    'erro': 'Um item não pôde ser apagado, ou a pasta recebeu arquivo durante a limpeza. Confira a pasta e repita.',
    'ocupado': 'O painel já está apagando outra pasta. Espere terminar e repita.',
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
    do FTP, da pasta do cadastro dele, pela tela Meus arquivos. O caminho que vem do navegador é sempre relativo
    à raiz da vista, e é a raiz que o prende ali."""

    def __init__(self, sessao):
        self.usuario = sessao['usuario']
        self.rota, self.tela = ('/meus-arquivos', 'Meus arquivos') if self.usuario else ('/arquivos', 'Arquivos')
        self.raiz = partes(sessao['pasta']) if self.usuario else []
        self.inicio = 'Início' if self.usuario else CFG['pasta_host']

    def real(self, caminho):
        """O mesmo caminho a partir da pasta dos dados: é o que vai para a auditoria e para a conta do cadastro."""
        return '/'.join(self.raiz + ([caminho] if caminho else []))


def recusa(pedido, sessao, erro, caminho):
    v = Vista(sessao)
    if erro.codigo != 404:
        auditar(pedido.ip, 'recusa_caminho', f'{quem(sessao)} caminho={limpo(caminho, 120)}')
    pedido.enviar(erro.codigo, pagina(v.tela, f'<section class="cartao"><h1>Pedido recusado</h1><p>{e(RECUSAS[erro.codigo])}</p>'
                                      f'<p><a href="{v.rota}">Voltar para {v.tela}</a></p></section>', sessao, v.rota))


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
    return (f' <a class="botao" href="{e(endereco(rota + "/renomear", "item", item))}">Renomear</a>'
            f' <a class="botao perigo" href="{e(endereco(rota + "/apagar", "item", item))}">Apagar</a>')


def linhas_da_lista(rota, caminho, pastas, arquivos, gerir=False):
    """Linhas da tabela de uma pasta aberta; `rota` é a tela que mostra a lista e `caminho`, a pasta como ela a vê.
    Com `gerir`, cada linha ganha os botões de renomear e de apagar."""
    base = caminho + '/' if caminho else ''
    linhas = []
    for nome, dados in pastas:
        gestao = botoes_de_gestao(rota, base + nome) if gerir else ''
        linhas.append(f'<tr><td><a class="item" href="{e(endereco(rota, "pasta", base + nome))}">{icone("pasta")}<strong>{e(visivel(nome))}</strong></a></td>'
                      f'<td class="suave">pasta</td><td>{e(quando(dados.st_mtime))}</td><td class="acoes">{gestao}</td></tr>')
    for nome, dados in arquivos:
        gestao = botoes_de_gestao(rota, base + nome) if gerir else ''
        if stat.S_ISREG(dados.st_mode):
            linhas.append(f'<tr><td><span class="item">{icone("arquivo")}{e(visivel(nome))}</span></td><td>{e(tamanho(dados.st_size))}</td><td>{e(quando(dados.st_mtime))}</td>'
                          f'<td class="acoes"><a class="botao" href="{e(endereco(rota + "/baixar", "arquivo", base + nome))}" download>'
                          f'Baixar</a>{gestao}</td></tr>')
        else:
            tipo = 'link simbólico' if stat.S_ISLNK(dados.st_mode) else 'arquivo especial'
            linhas.append(f'<tr><td><span class="item">{icone("atalho")}{e(visivel(nome))}</span> <span class="etiqueta">{tipo}</span></td><td class="suave">—</td>'
                          f'<td>{e(quando(dados.st_mtime))}</td><td class="acoes"><span class="suave">o painel não abre</span>'
                          f'{gestao}</td></tr>')
    return ''.join(linhas) or '<tr><td colspan="4" class="suave">Pasta vazia.</td></tr>'


def aviso_de_corte(cortado):
    return (f'<p class="aviso">Esta pasta tem mais de {LISTA_MAX} itens: a lista mostra só os primeiros {LISTA_MAX}. '
            'Para ver todos, entre por FTP.</p>') if cortado else ''


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
    corpo, aviso = linhas_da_lista('/arquivos', caminho, pastas, arquivos, gerir=True), aviso_de_corte(cortado)
    feito = MENSAGENS.get(consulta.get('m', ''), '')
    donos = [nome for nome, dele in usuarios().items() if dele == caminho] if caminho else []
    de_quem = f'<p class="suave">Pasta do usuário do FTP: <strong>{e(", ".join(donos))}</strong>.</p>' if donos else ''
    novo_usuario = (f' <a class="botao" href="{e(endereco("/usuarios/novo", "pasta", caminho))}">Novo usuário nesta pasta</a>'
                    if PASTA.fullmatch(caminho) else '')
    pedido.enviar(200, pagina('Arquivos', f'''{cabeca('Arquivos', 'O que os equipamentos já enviaram, pasta por pasta.')}
{f'<p class="ok" role="status">{e(feito)}</p>' if feito else ''}
<p class="trilha">{trilha(Vista(sessao), lista)}{novo_usuario}</p>
{de_quem}{aviso}<section class="cartao lista"><div class="rolagem"><table>
<thead><tr><th>Nome</th><th>Tamanho</th><th>Modificado</th><th>Ações</th></tr></thead>
<tbody>{corpo}</tbody></table></div>
<p class="suave">O painel navega, baixa, cria pasta, troca o nome e apaga; enviar arquivo continua sendo feito por FTP.
Apagar pede a sua senha atual e não tem lixeira. Todo download e toda alteração ficam registrados na aba Atividade.</p></section>
{formulario_nova_pasta(sessao, caminho)}''', sessao, '/arquivos'))


def formulario_nova_pasta(sessao, caminho):
    """Formulário que cria uma pasta dentro da que está aberta. Não aparece se o caminho tem byte fora do UTF-8,
    que o formulário não consegue devolver."""
    try:
        caminho.encode('utf-8')
    except UnicodeEncodeError:
        return ''
    v = Vista(sessao)
    nasce = ('A pasta nasce vazia, dentro da sua pasta no FTP.' if v.usuario else
             'A pasta nasce vazia; para um equipamento gravar nela, crie um usuário com esta pasta.')
    return f'''<section class="cartao estreito"><h2>Nova pasta</h2>
<form method="post" action="{v.rota}/pasta" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<input type="hidden" name="pasta" value="{e(caminho)}">
<label for="nome">Nome da pasta, criada dentro de <code>{e(v.inicio)}{'/' + e(caminho) if caminho else ''}</code></label>
<input id="nome" name="nome" required maxlength="64" pattern="[A-Za-z0-9_][A-Za-z0-9._\\-]*" autocapitalize="none" spellcheck="false">
<p class="suave">Letras, números, <code>_</code>, <code>-</code> e ponto; não começa com ponto; até 64 caracteres.
{nasce}</p>
<button type="submit">Criar pasta</button>
</form></section>'''


def resposta_pasta(pedido, sessao, codigo, titulo, texto, caminho):
    v = Vista(sessao)
    pedido.enviar(codigo, pagina(v.tela, f'<section class="cartao"><h1>{titulo}</h1><p>{e(texto)}</p>'
                                 f'<p><a href="{e(endereco(v.rota, "pasta", caminho))}">Voltar para a pasta</a></p></section>',
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
            return resposta_pasta(pedido, sessao, 400, 'Nome não aceito', 'Use letras, números, _, - e ponto; o nome não começa '
                                  'com ponto e tem até 64 caracteres.', caminho)
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
        return resposta_pasta(pedido, sessao, 409, 'Nome já usado', 'Já existe uma pasta ou um arquivo com este nome.', caminho)
    except (OSError, KeyError):
        auditar(pedido.ip, 'falha_comando', f'{quem(sessao)} acao=criar_pasta pasta={limpo(v.real(novo), 200)}')
        return resposta_pasta(pedido, sessao, 500, 'Pasta não criada', 'Não foi possível criar a pasta.', caminho)
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
    """(palavra da auditoria, nome na tela) do tipo do item."""
    if stat.S_ISDIR(dados.st_mode):
        return 'pasta', 'a pasta'
    if stat.S_ISREG(dados.st_mode):
        return 'arquivo', 'o arquivo'
    if stat.S_ISLNK(dados.st_mode):
        return 'link', 'o link simbólico'
    return 'especial', 'o arquivo especial'


def usuarios_presos(caminho):
    """Usuários do FTP com a pasta do cadastro neste caminho (a partir da pasta dos dados) ou dentro dele: trocar
    o nome da pasta ou apagá-la por aqui os deixaria sem ter onde entrar."""
    return [nome for nome, dele in usuarios().items() if dele and (dele == caminho or dele.startswith(caminho + '/'))]


def pasta_de_usuario(pedido, sessao, lista, presos, feita):
    v = Vista(sessao)
    if v.usuario:  # quem são os outros usuários é assunto do administrador: a tela dele não diz os nomes
        de_quem = 'outro usuário do FTP'
        saida = 'Peça ao administrador do painel.'
    else:
        de_quem = f'<strong>{e(", ".join(presos))}</strong>'
        saida = ('Para dar outra pasta a um usuário, use <strong>Usuários ➜ Editar</strong>. Para apagar a pasta junto com '
                 'o usuário, use <strong>Usuários ➜ Remover</strong>.')
    pedido.enviar(409, pagina(v.tela, f'''<section class="cartao"><h1>Pasta de usuário do FTP</h1>
<p>A pasta <strong>{e(visivel(lista[-1]))}</strong> não é {feita} por aqui: é a pasta, ou tem dentro dela a pasta, de
{de_quem}.</p>
<p>{saida} O que está dentro dela pode ser renomeado e apagado item por item.</p>
<p><a href="{e(endereco(v.rota, "pasta", "/".join(lista[:-1])))}">Voltar para a pasta</a></p></section>''', sessao, v.rota))


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
    return pedido.enviar(codigo, pagina('Renomear', f'''<h1>Renomear</h1>
<section class="cartao estreito">{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<p>Trocar o nome d{tipo_de(dados)[1]} <strong>{e(visivel(lista[-1]))}</strong>, em {onde_fica(v, lista)}.</p>
<form method="post" action="{v.rota}/renomear" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
{campo_do_item(caminho)}
<label for="nome">Nome novo</label>
<input id="nome" name="nome" required maxlength="64" pattern="[A-Za-z0-9_][A-Za-z0-9._\\-]*" value="{e(novo)}" autocapitalize="none" spellcheck="false">
<p class="suave">Letras, números, <code>_</code>, <code>-</code> e ponto; não começa com ponto; até 64 caracteres.
O item continua na mesma pasta: o painel não move de uma pasta para outra. O equipamento que grava com o nome antigo
cria outro arquivo no envio seguinte.</p>
<button type="submit">Trocar nome</button> <a class="botao" href="{e(volta)}">Cancelar</a>
</form></section>''', sessao, v.rota))


def renomear(pedido, sessao, consulta, formulario, token):
    """Troca o nome de um arquivo ou de uma pasta, dentro da mesma pasta. O nome novo segue a regra do nome de
    pasta; a pasta de um usuário do FTP, ou a que tem uma dentro, não é renomeada por aqui."""
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
            return tela_renomear(pedido, sessao, consulta, erro='Nome não aceito. Veja a regra abaixo do campo.', codigo=400,
                                 caminho=caminho)
        presos = usuarios_presos(v.real(caminho)) if stat.S_ISDIR(dados.st_mode) else []
        if presos:
            return pasta_de_usuario(pedido, sessao, lista, presos, 'renomeada')
        if novo == lista[-1]:
            return tela_renomear(pedido, sessao, consulta, erro='O item já tem este nome.', codigo=409, caminho=caminho, novo=novo)
        try:
            trocar_nome(acima, lista[-1], novo)
        except FileExistsError:
            return tela_renomear(pedido, sessao, consulta, erro='Já existe uma pasta ou um arquivo com este nome.', codigo=409,
                                 caminho=caminho, novo=novo)
        except OSError:
            auditar(pedido.ip, 'falha_comando', f'{quem(sessao)} acao=renomear caminho={limpo(v.real(caminho), 200)}')
            return tela_renomear(pedido, sessao, consulta, erro='Não foi possível trocar o nome.', codigo=500, caminho=caminho,
                                 novo=novo)
    finally:
        os.close(acima)
    limpar_cache()
    auditar(pedido.ip, 'item_renomeado', f'{quem(sessao)} tipo={tipo_de(dados)[0]} de={limpo(v.real(caminho), 200)} '
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
    nome = e(visivel(lista[-1]))
    if stat.S_ISDIR(dados.st_mode):
        presos = usuarios_presos(v.real(caminho))
        if presos:
            return pasta_de_usuario(pedido, sessao, lista, presos, 'apagada')
        uso = uso_da_pasta(v.real(caminho), validade=0)
        mais = ' ou mais' if uso['parcial'] else ''
        alvo = (f'a pasta <strong>{nome}</strong> e <strong>tudo o que há dentro dela</strong>: {uso["arquivos"]}{mais} arquivo(s), '
                f'{e(tamanho(uso["bytes"]))}{mais}')
    elif stat.S_ISREG(dados.st_mode):
        alvo = f'o arquivo <strong>{nome}</strong>, de {e(tamanho(dados.st_size))}, modificado em {e(quando(dados.st_mtime))}'
    else:
        alvo = f'{tipo_de(dados)[1]} <strong>{nome}</strong>; o destino dele não é tocado'
    volta = endereco(v.rota, 'pasta', '/'.join(lista[:-1]))
    return pedido.enviar(codigo, pagina('Apagar', f'''<h1>Apagar</h1>
<section class="cartao estreito">{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<p>Apagar {alvo}, em {onde_fica(v, lista)}?</p>
<p class="aviso">O painel <strong>não tem lixeira</strong>: o que for apagado só volta de uma cópia de segurança.</p>
<form method="post" action="{v.rota}/apagar" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
{campo_do_item(caminho)}
<label class="marcar"><input type="checkbox" name="confirmar" value="sim" required> Conferi o nome e quero apagar</label>
{campo_senha_atual(sessao, para='para apagar')}
<button class="perigo" type="submit">Apagar de vez</button> <a class="botao" href="{e(volta)}">Cancelar</a>
</form></section>''', sessao, v.rota))


def apagar(pedido, sessao, consulta, formulario, token):
    """Apaga um arquivo, ou uma pasta com tudo o que há nela. Pede a caixa de confirmação e a senha de quem está
    na sessão; a pasta de um usuário do FTP, ou a que tem uma dentro, só sai junto com o usuário."""
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
            return tela_apagar(pedido, sessao, consulta, erro='Marque a caixa de confirmação. Nada foi apagado.', codigo=400,
                               caminho=caminho)
        codigo, erro = confirmacao_recusada(pedido, sessao, formulario)
        if codigo:
            return tela_apagar(pedido, sessao, consulta, erro=erro.replace('alterado', 'apagado'), codigo=codigo, caminho=caminho)
        itens, parada = apagar_item(acima, lista[-1], pasta)
    finally:
        os.close(acima)
    registro = f'{quem(sessao)} tipo={tipo_de(dados)[0]} caminho={limpo(v.real(caminho), 200)}'
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
    titulo = 'Apagado em parte' if itens else 'Nada foi apagado'
    feito = f'<p><strong>{itens}</strong> item(ns) apagado(s); o restante continua no lugar.</p>' if itens else ''
    return pedido.enviar(codigo, pagina('Apagar', f'<section class="cartao"><h1>{titulo}</h1>{feito}<p>{e(PARADAS[parada])}</p>'
                                        f'<p><a class="botao" href="{e(repetir)}">Repetir</a> <a class="botao" href="{e(volta)}">Voltar</a></p>'
                                        '</section>', sessao, aba),
                         extras=(('Retry-After', '30'),) if parada == 'ocupado' else ())


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
            limite = f'O limite deste usuário é de {dele} arquivo(s) por vez.'
        elif not VAGAS.acquire(blocking=False):
            limite = f'O painel entrega até {DOWNLOADS_MAX} arquivos por vez.'
        elif usuario:
            EM_CURSO[usuario] = EM_CURSO.get(usuario, 0) + 1
    if limite:
        os.close(descritor)
        return pedido.enviar(503, pagina(v.tela, '<section class="cartao"><h1>Muitos downloads ao mesmo tempo</h1>'
                                         f'<p>{limite} Espere um deles terminar e repita.</p>'
                                         f'<p><a href="{v.rota}">Voltar para {v.tela}</a></p></section>', sessao, v.rota),
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
