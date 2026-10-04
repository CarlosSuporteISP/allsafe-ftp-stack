"""Aba Arquivos: navegar pelas pastas dos usuários do FTP e baixar um arquivo pelo navegador. Só leitura."""
import os
import re
import stat
import threading
import urllib.parse

from auditoria import auditar, limpo
from config import CFG, DOWNLOADS_MAX, LISTA_MAX, PASTA_DADOS
from pagina import e, pagina, quando, tamanho

VAGAS = threading.BoundedSemaphore(DOWNLOADS_MAX)
# Nenhuma parte do caminho é seguida se for link simbólico; O_NONBLOCK não deixa um FIFO prender o pedido.
ABRIR = os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK
RECUSAS = {
    400: 'Caminho não aceito.',
    403: 'Link simbólico não é seguido pelo painel.',
    404: 'Pasta ou arquivo não encontrado.',
}


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


def recusa(pedido, sessao, erro, caminho):
    if erro.codigo != 404:
        auditar(pedido.ip, 'recusa_caminho', f'admin={sessao["admin"]} caminho={limpo(caminho, 120)}')
    pedido.enviar(erro.codigo, pagina('Arquivos', f'<section class="cartao"><h1>⛔ Pedido recusado</h1><p>{e(RECUSAS[erro.codigo])}</p>'
                                      '<p><a href="/arquivos">Voltar para Arquivos</a></p></section>', sessao, '/arquivos'))


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
    base = caminho + '/' if caminho else ''
    linhas = []
    for nome, dados in pastas:
        linhas.append(f'<tr><td>📁 <a href="{e(endereco("/arquivos", "pasta", base + nome))}"><strong>{e(visivel(nome))}</strong></a></td>'
                      f'<td class="suave">pasta</td><td>{e(quando(dados.st_mtime))}</td><td></td></tr>')
    for nome, dados in arquivos:
        if stat.S_ISREG(dados.st_mode):
            linhas.append(f'<tr><td>📄 {e(visivel(nome))}</td><td>{e(tamanho(dados.st_size))}</td><td>{e(quando(dados.st_mtime))}</td>'
                          f'<td class="acoes"><a class="botao" href="{e(endereco("/arquivos/baixar", "arquivo", base + nome))}" download>'
                          '⬇️ Baixar</a></td></tr>')
        else:
            tipo = 'link simbólico' if stat.S_ISLNK(dados.st_mode) else 'arquivo especial'
            linhas.append(f'<tr><td>🔗 {e(visivel(nome))} <span class="etiqueta">{tipo}</span></td><td class="suave">—</td>'
                          f'<td>{e(quando(dados.st_mtime))}</td><td class="acoes"><span class="suave">o painel não abre</span></td></tr>')
    corpo = ''.join(linhas) or '<tr><td colspan="4" class="suave">Pasta vazia.</td></tr>'
    aviso = (f'<p class="aviso">⚠️ Esta pasta tem mais de {LISTA_MAX} itens: a lista mostra só os primeiros {LISTA_MAX}. '
             'Para ver todos, entre por FTP.</p>') if cortado else ''
    pedido.enviar(200, pagina('Arquivos', f'''<h1>📁 Arquivos</h1>
<p class="trilha">{trilha(lista)}</p>
{aviso}<section class="cartao"><div class="rolagem"><table>
<thead><tr><th>Nome</th><th>Tamanho</th><th>Modificado</th><th>Ações</th></tr></thead>
<tbody>{corpo}</tbody></table></div>
<p class="suave">Cada pasta do primeiro nível é a de um usuário do FTP. O painel só lê: enviar, renomear e apagar
continuam sendo feitos por FTP. Todo download fica registrado na aba Atividade.</p></section>''', sessao, '/arquivos'))


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
    if not VAGAS.acquire(blocking=False):
        os.close(descritor)
        return pedido.enviar(503, pagina('Arquivos', '<section class="cartao"><h1>⏳ Muitos downloads ao mesmo tempo</h1>'
                                         f'<p>O painel entrega até {DOWNLOADS_MAX} arquivos por vez. Espere um deles terminar e repita.</p>'
                                         '<p><a href="/arquivos">Voltar para Arquivos</a></p></section>', sessao, '/arquivos'),
                             extras=(('Retry-After', '30'),))
    try:
        with os.fdopen(descritor, 'rb', buffering=0) as arquivo:
            total = os.fstat(arquivo.fileno()).st_size
            enviados = pedido.enviar_arquivo(arquivo, total, extras=(('Content-Disposition', anexo(lista[-1])),))
    finally:
        VAGAS.release()
    evento = 'arquivo_baixado' if enviados == total else 'arquivo_interrompido'
    auditar(pedido.ip, evento, f'admin={sessao["admin"]} arquivo={limpo(caminho, 200)} bytes={enviados}')
    return None
