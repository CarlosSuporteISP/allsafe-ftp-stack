"""Aba Arquivos: navegar pelas pastas dos usuários do FTP, baixar um arquivo pelo navegador e criar pasta.

O painel não envia, não renomeia e não apaga: a única gravação que ele faz nos dados é criar pasta vazia.
A abertura dos caminhos, a lista e a entrega do arquivo servem também à tela Meus arquivos, do usuário do FTP."""
import os
import pwd
import re
import stat
import threading
import urllib.parse

from auditoria import auditar, limpo
from config import CFG, DONO_DADOS, DOWNLOADS_MAX, DOWNLOADS_POR_USUARIO, LISTA_MAX, NIVEL, PASTA, PASTA_DADOS
from estado import usuarios
from pagina import e, pagina, quando, tamanho
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
MENSAGENS = {'criada': '✅ Pasta criada.'}


class Recusado(Exception):
    """Caminho que tenta sair da pasta dos dados, passa por link simbólico ou não existe."""

    def __init__(self, codigo):
        super().__init__(codigo)
        self.codigo = codigo


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


def tela_de(sessao):
    """Rota e nome da tela de arquivos de quem está na sessão: a do administrador ou a do usuário do FTP."""
    return ('/meus-arquivos', 'Meus arquivos') if sessao['usuario'] else ('/arquivos', 'Arquivos')


def recusa(pedido, sessao, erro, caminho):
    rota, tela = tela_de(sessao)
    if erro.codigo != 404:
        auditar(pedido.ip, 'recusa_caminho', f'{quem(sessao)} caminho={limpo(caminho, 120)}')
    pedido.enviar(erro.codigo, pagina(tela, f'<section class="cartao"><h1>⛔ Pedido recusado</h1><p>{e(RECUSAS[erro.codigo])}</p>'
                                      f'<p><a href="{rota}">Voltar para {tela}</a></p></section>', sessao, rota))


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


def trilha(lista):
    """Caminho da pasta aberta, com um link em cada nível."""
    if not lista:
        return f'<code>{e(CFG["pasta_host"])}</code>'
    niveis = [f'<a href="/arquivos"><code>{e(CFG["pasta_host"])}</code></a>']
    for indice, parte in enumerate(lista):
        if indice == len(lista) - 1:
            niveis.append(f'<strong>{e(visivel(parte))}</strong>')
        else:
            niveis.append(f'<a href="{e(endereco("/arquivos", "pasta", "/".join(lista[:indice + 1])))}">{e(visivel(parte))}</a>')
    return ' / '.join(niveis)


def linhas_da_lista(rota, caminho, pastas, arquivos):
    """Linhas da tabela de uma pasta aberta; `rota` é a tela que mostra a lista e `caminho`, a pasta como ela a vê."""
    base = caminho + '/' if caminho else ''
    linhas = []
    for nome, dados in pastas:
        linhas.append(f'<tr><td>📁 <a href="{e(endereco(rota, "pasta", base + nome))}"><strong>{e(visivel(nome))}</strong></a></td>'
                      f'<td class="suave">pasta</td><td>{e(quando(dados.st_mtime))}</td><td></td></tr>')
    for nome, dados in arquivos:
        if stat.S_ISREG(dados.st_mode):
            linhas.append(f'<tr><td>📄 {e(visivel(nome))}</td><td>{e(tamanho(dados.st_size))}</td><td>{e(quando(dados.st_mtime))}</td>'
                          f'<td class="acoes"><a class="botao" href="{e(endereco(rota + "/baixar", "arquivo", base + nome))}" download>'
                          '⬇️ Baixar</a></td></tr>')
        else:
            tipo = 'link simbólico' if stat.S_ISLNK(dados.st_mode) else 'arquivo especial'
            linhas.append(f'<tr><td>🔗 {e(visivel(nome))} <span class="etiqueta">{tipo}</span></td><td class="suave">—</td>'
                          f'<td>{e(quando(dados.st_mtime))}</td><td class="acoes"><span class="suave">o painel não abre</span></td></tr>')
    return ''.join(linhas) or '<tr><td colspan="4" class="suave">Pasta vazia.</td></tr>'


def aviso_de_corte(cortado):
    return (f'<p class="aviso">⚠️ Esta pasta tem mais de {LISTA_MAX} itens: a lista mostra só os primeiros {LISTA_MAX}. '
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
    corpo, aviso = linhas_da_lista('/arquivos', caminho, pastas, arquivos), aviso_de_corte(cortado)
    feito = MENSAGENS.get(consulta.get('m', ''), '')
    donos = [nome for nome, dele in usuarios().items() if dele == caminho] if caminho else []
    de_quem = f'<p class="suave">Pasta do usuário do FTP: <strong>{e(", ".join(donos))}</strong>.</p>' if donos else ''
    novo_usuario = (f' <a class="botao" href="{e(endereco("/usuarios/novo", "pasta", caminho))}">👤 Novo usuário nesta pasta</a>'
                    if PASTA.fullmatch(caminho) else '')
    pedido.enviar(200, pagina('Arquivos', f'''<h1>📁 Arquivos</h1>
{f'<p class="ok" role="status">{e(feito)}</p>' if feito else ''}
<p class="trilha">{trilha(lista)}{novo_usuario}</p>
{de_quem}{aviso}<section class="cartao"><div class="rolagem"><table>
<thead><tr><th>Nome</th><th>Tamanho</th><th>Modificado</th><th>Ações</th></tr></thead>
<tbody>{corpo}</tbody></table></div>
<p class="suave">O painel navega, baixa e cria pasta: enviar, renomear e apagar continuam sendo feitos por FTP.
Todo download e toda pasta criada ficam registrados na aba Atividade.</p></section>
{formulario_nova_pasta(sessao, caminho)}''', sessao, '/arquivos'))


def formulario_nova_pasta(sessao, caminho):
    """Formulário que cria uma pasta dentro da que está aberta. Não aparece se o caminho tem byte fora do UTF-8,
    que o formulário não consegue devolver."""
    try:
        caminho.encode('utf-8')
    except UnicodeEncodeError:
        return ''
    return f'''<section class="cartao estreito"><h2>➕ Nova pasta</h2>
<form method="post" action="/arquivos/pasta" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<input type="hidden" name="pasta" value="{e(caminho)}">
<label for="nome">Nome da pasta, criada dentro de <code>{e(CFG['pasta_host'])}{'/' + e(caminho) if caminho else ''}</code></label>
<input id="nome" name="nome" required maxlength="64" pattern="[A-Za-z0-9_][A-Za-z0-9._\\-]*" autocapitalize="none" spellcheck="false">
<p class="suave">Letras, números, <code>_</code>, <code>-</code> e ponto; não começa com ponto; até 64 caracteres.
A pasta nasce vazia; para um equipamento gravar nela, crie um usuário com esta pasta.</p>
<button type="submit">Criar pasta</button>
</form></section>'''


def resposta_pasta(pedido, sessao, codigo, titulo, texto, caminho):
    pedido.enviar(codigo, pagina('Arquivos', f'<section class="cartao"><h1>{titulo}</h1><p>{e(texto)}</p>'
                                 f'<p><a href="{e(endereco("/arquivos", "pasta", caminho))}">Voltar para a pasta</a></p></section>',
                                 sessao, '/arquivos'))


def criar_pasta(pedido, sessao, consulta, formulario, token):
    """Cria uma pasta vazia dentro de uma pasta que já existe, com o dono e o modo das pastas do FTP.
    A pasta de cima é aberta parte por parte, sem seguir link simbólico, e a nova nasce em relação a ela."""
    caminho, nome = formulario.get('pasta', ''), formulario.get('nome', '').strip()
    novo = f'{caminho}/{nome}' if caminho else nome
    try:
        lista = partes(caminho)
        if not NIVEL.fullmatch(nome):
            auditar(pedido.ip, 'recusa_caminho', f'{quem(sessao)} caminho={limpo(novo, 120)}')
            return resposta_pasta(pedido, sessao, 400, '⛔ Nome não aceito', 'Use letras, números, _, - e ponto; o nome não começa '
                                  'com ponto e tem até 64 caracteres.', caminho)
        descritor = abrir(lista, pasta=True)
    except Recusado as erro:
        return recusa(pedido, sessao, erro, novo)
    try:
        dono = pwd.getpwnam(DONO_DADOS)
        os.mkdir(nome, 0o750, dir_fd=descritor)
        feita = os.open(nome, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=descritor)
        try:
            os.fchmod(feita, 0o750)
            os.fchown(feita, dono.pw_uid, dono.pw_gid)
        finally:
            os.close(feita)
    except FileExistsError:
        return resposta_pasta(pedido, sessao, 409, '📁 Nome já usado', 'Já existe uma pasta ou um arquivo com este nome.', caminho)
    except (OSError, KeyError):
        auditar(pedido.ip, 'falha_comando', f'{quem(sessao)} acao=criar_pasta pasta={limpo(novo, 200)}')
        return resposta_pasta(pedido, sessao, 500, '⚠️ Pasta não criada', 'Não foi possível criar a pasta.', caminho)
    finally:
        os.close(descritor)
    auditar(pedido.ip, 'pasta_criada', f'{quem(sessao)} pasta={limpo(novo, 200)}')
    return pedido.redirecionar(endereco('/arquivos', 'pasta', caminho) + '&m=criada')


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
    auditoria, relativo à pasta dos dados. Vale o teto geral de downloads e, para usuário do FTP, o teto dele."""
    rota, tela = tela_de(sessao)
    usuario, limite = sessao['usuario'], ''
    with TRAVA_CURSO:
        if usuario and EM_CURSO.get(usuario, 0) >= DOWNLOADS_POR_USUARIO:
            limite = f'Cada usuário baixa até {DOWNLOADS_POR_USUARIO} arquivos por vez.'
        elif not VAGAS.acquire(blocking=False):
            limite = f'O painel entrega até {DOWNLOADS_MAX} arquivos por vez.'
        elif usuario:
            EM_CURSO[usuario] = EM_CURSO.get(usuario, 0) + 1
    if limite:
        os.close(descritor)
        return pedido.enviar(503, pagina(tela, '<section class="cartao"><h1>⏳ Muitos downloads ao mesmo tempo</h1>'
                                         f'<p>{limite} Espere um deles terminar e repita.</p>'
                                         f'<p><a href="{rota}">Voltar para {tela}</a></p></section>', sessao, rota),
                             extras=(('Retry-After', '30'),))
    try:
        with os.fdopen(descritor, 'rb', buffering=0) as arquivo:
            total = os.fstat(arquivo.fileno()).st_size
            enviados = pedido.enviar_arquivo(arquivo, total, extras=(('Content-Disposition', anexo(nome)),))
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
