"""Atendimento HTTP atrás do nginx: o soquete Unix, as conferências de todo pedido e o roteamento."""
import hmac
import http.server
import ipaddress
import os
import re
import socketserver
import sys
import threading
import urllib.parse

import conta_ftp
import entrada
from auditoria import auditar, limpo
from config import BLOCO_ARQUIVO, CFG, CONEXOES_MAX, CORPO_MAX, GID_NGINX, TEMPO_CONEXAO, privado
from pagina import e, pagina
from rotas import ROTAS, ROTAS_USUARIO
from sessao import buscar_sessao, encerrar_sessao

CABECALHOS = (
    ('Content-Security-Policy', "default-src 'none'; style-src 'self'; img-src 'self'; form-action 'self'; "
                                "frame-ancestors 'none'; base-uri 'none'"),
    ('X-Frame-Options', 'DENY'),
    ('X-Content-Type-Options', 'nosniff'),
    ('Referrer-Policy', 'same-origin'),
    ('Strict-Transport-Security', 'max-age=31536000'),
    ('Cross-Origin-Opener-Policy', 'same-origin'),
    ('Cross-Origin-Resource-Policy', 'same-origin'),
    ('Permissions-Policy', 'camera=(), geolocation=(), microphone=()'),
    ('Cache-Control', 'no-store'),
)


class Servidor(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    """HTTP em soquete Unix: quem fecha o TLS e fala com a rede é o nginx."""
    daemon_threads = True
    request_queue_size = CONEXOES_MAX

    def __init__(self, caminho, tratador):
        try:
            os.unlink(caminho)
        except FileNotFoundError:
            pass
        # O soquete nasce fechado e só então é aberto para o grupo do nginx: ninguém mais conecta.
        antiga = os.umask(0o177)
        try:
            super().__init__(caminho, tratador)
        finally:
            os.umask(antiga)
        os.chown(caminho, 0, GID_NGINX)
        os.chmod(caminho, 0o660)
        self.vagas = threading.BoundedSemaphore(CONEXOES_MAX)

    def process_request(self, request, client_address):
        if not self.vagas.acquire(blocking=False):
            self.shutdown_request(request)
            return
        try:
            super().process_request(request, client_address)
        except Exception:
            self.vagas.release()
            raise

    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self.vagas.release()

    def handle_error(self, request, client_address):
        erro = sys.exc_info()[1]
        if not isinstance(erro, OSError):
            print(f'erro ao atender um pedido: {type(erro).__name__}', file=sys.stderr, flush=True)


class Painel(http.server.BaseHTTPRequestHandler):
    server_version = 'painel'
    sys_version = ''
    protocol_version = 'HTTP/1.1'
    timeout = TEMPO_CONEXAO
    error_content_type = 'text/plain; charset=utf-8'
    error_message_format = '%(code)d %(message)s\n'

    def version_string(self):
        return 'painel'

    def log_message(self, formato, *valores):
        pass

    def end_headers(self):
        for nome, valor in CABECALHOS:
            self.send_header(nome, valor)
        self.send_header('Connection', 'close')
        super().end_headers()

    def do_GET(self):
        self.tratar('GET')

    def do_POST(self):
        self.tratar('POST')

    # ------------------------------------------------------------ respostas

    def enviar(self, codigo, corpo, tipo='text/html; charset=utf-8', extras=()):
        dados = corpo.encode() if isinstance(corpo, str) else corpo
        self.send_response(codigo)
        self.send_header('Content-Type', tipo)
        self.send_header('Content-Length', str(len(dados)))
        for nome, valor in extras:
            self.send_header(nome, valor)
        self.end_headers()
        self.wfile.write(dados)
        if self.caminho != '/saude':
            print(f'{self.ip} {self.command} {limpo(self.caminho)} {codigo}', flush=True)

    def enviar_arquivo(self, arquivo, total, extras=()):
        """Entrega um arquivo já aberto, em blocos, sem carregá-lo na memória. Devolve quantos bytes saíram."""
        self.send_response(200)
        self.send_header('Content-Type', 'application/octet-stream')
        self.send_header('Content-Length', str(total))
        self.send_header('Accept-Ranges', 'none')
        for nome, valor in extras:
            self.send_header(nome, valor)
        self.end_headers()
        enviados = 0
        try:
            while enviados < total:
                bloco = arquivo.read(min(BLOCO_ARQUIVO, total - enviados))
                if not bloco:
                    break
                self.wfile.write(bloco)
                enviados += len(bloco)
        except OSError:  # quem baixava fechou a conexão, ou o arquivo deixou de ser lido
            pass
        print(f'{self.ip} {self.command} {limpo(self.caminho)} 200 {enviados}/{total} bytes', flush=True)
        return enviados

    def redirecionar(self, destino, extras=()):
        self.enviar(303, '', extras=(('Location', destino),) + tuple(extras))

    def recusar(self, codigo, texto):
        self.enviar(codigo, pagina('Pedido recusado', f'<section class="cartao"><h1>⛔ Pedido recusado</h1><p>{e(texto)}</p>'
                                   '<p><a href="/">Voltar ao painel</a></p></section>'))

    # ------------------------------------------------------------ conferências antes de qualquer tela

    def rede_permitida(self):
        try:
            ip = ipaddress.ip_address(self.ip)
        except ValueError:
            return False
        return ip.is_loopback or any(ip in rede for rede in CFG['redes'])

    def host_valido(self):
        host = self.headers.get('Host', '').lower()
        nome, separador, porta = host.partition(':')
        if separador and not porta.isdigit():
            return False
        if nome and nome in ('localhost', CFG['cert_cn']):
            return True
        try:
            ip = ipaddress.ip_address(nome)
        except ValueError:
            return False
        # Endereço IP no lugar do nome não serve a ataque de troca de DNS: com IP público aceito, vale qualquer IPv4.
        return ip.version == 4 and (CFG['ip_publico'] or privado(ip))

    def origem_valida(self):
        esperado = 'https://' + self.headers.get('Host', '')
        origem = self.headers.get('Origin')
        if origem is not None:
            return origem == esperado
        referencia = self.headers.get('Referer', '')
        return referencia.startswith(esperado + '/')

    def token_do_cookie(self):
        for parte in self.headers.get('Cookie', '').split(';'):
            nome, _, valor = parte.strip().partition('=')
            if nome == '__Host-sessao' and re.fullmatch(r'[A-Za-z0-9_-]{20,100}', valor):
                return valor
        return None

    def ler_formulario(self):
        """Devolve o formulário como dicionário, ou None depois de já ter respondido com o erro."""
        comprimento = self.headers.get('Content-Length', '')
        if not comprimento.isdigit():
            self.recusar(411, 'Envio sem tamanho declarado.')
            return None
        if int(comprimento) > CORPO_MAX:
            self.recusar(413, 'Envio grande demais.')
            return None
        if self.headers.get('Content-Type', '').split(';')[0].strip().lower() != 'application/x-www-form-urlencoded':
            self.recusar(415, 'Formato de envio não aceito.')
            return None
        try:
            campos = urllib.parse.parse_qs(self.rfile.read(int(comprimento)).decode('utf-8'),
                                           keep_blank_values=True, max_num_fields=12, strict_parsing=False)
        except (ValueError, UnicodeDecodeError):
            self.recusar(400, 'Envio malformado.')
            return None
        return {nome: valores[0] for nome, valores in campos.items()}

    # ------------------------------------------------------------ roteamento

    def tratar(self, metodo):
        url = urllib.parse.urlsplit(self.path)
        self.caminho = url.path
        try:
            consulta = {n: v[0] for n, v in urllib.parse.parse_qs(url.query, max_num_fields=5).items()}
        except ValueError:
            consulta = {}

        # O endereço do cliente é o que o nginx viu: ele sempre sobrescreve X-Real-IP. Pedido sem o
        # cabeçalho, com mais de um ou com valor que não é IP não veio pelo nginx e é recusado.
        enderecos = self.headers.get_all('X-Real-IP') or []
        self.ip = enderecos[0].strip() if len(enderecos) == 1 else ''
        try:
            ipaddress.ip_address(self.ip)
        except ValueError:
            self.ip = '-'
            return self.enviar(400, 'pedido sem o endereço do cliente\n', 'text/plain; charset=utf-8')

        if not self.rede_permitida():
            auditar(self.ip, 'recusa_rede')
            return self.enviar(403, 'cliente fora das redes permitidas\n', 'text/plain; charset=utf-8')
        if not self.host_valido():
            auditar(self.ip, 'recusa_host', f'host={limpo(self.headers.get("Host", ""))}')
            return self.enviar(400, 'endereço não aceito\n', 'text/plain; charset=utf-8')

        if metodo == 'GET' and self.caminho == '/saude':
            return self.enviar(200, 'ok\n', 'text/plain; charset=utf-8')

        formulario = {}
        if metodo == 'POST':
            formulario = self.ler_formulario()
            if formulario is None:
                return None
            if not self.origem_valida():
                auditar(self.ip, 'recusa_origem', f'caminho={limpo(self.caminho)}')
                return self.recusar(403, 'O envio não partiu deste painel.')

        if self.caminho == '/entrar':
            return entrada.entrar(self, metodo, formulario)

        token = self.token_do_cookie()
        sessao = buscar_sessao(token, self.ip) if token else None
        if sessao is None:
            return self.redirecionar('/entrar')
        if sessao['usuario']:
            motivo = conta_ftp.motivo_do_fim(sessao)
            if motivo:
                encerrar_sessao(token)
                auditar(self.ip, 'sessao_encerrada', f'usuario={sessao["usuario"]} motivo={motivo}')
                return self.redirecionar('/entrar', (('Set-Cookie', entrada.COOKIE_VAZIO),))
        if metodo == 'POST' and not hmac.compare_digest(formulario.get('csrf', ''), sessao['csrf']):
            auditar(self.ip, 'recusa_csrf', f'caminho={limpo(self.caminho)}')
            return self.recusar(403, 'Formulário sem token válido. Abra a página de novo e repita.')

        # Cada papel tem a tabela dele: para o usuário do FTP, as telas de administração não existem.
        rota = (ROTAS_USUARIO if sessao['usuario'] else ROTAS).get((metodo, self.caminho))
        if rota is None:
            if sessao['usuario'] and (metodo, self.caminho) in ROTAS:
                auditar(self.ip, 'recusa_papel', f'usuario={sessao["usuario"]} caminho={limpo(self.caminho)}')
            return self.enviar(404, pagina('Não encontrado', '<section class="cartao"><h1>🔎 Página não encontrada</h1>'
                                           '<p><a href="/">Voltar ao painel</a></p></section>', sessao))
        return rota(self, sessao, consulta, formulario, token)
