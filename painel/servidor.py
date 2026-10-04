#!/usr/bin/env python3
"""Painel web da allsafe-ftp-stack. SÓ PARA REDE PRIVADA, atrás de firewall.

HTTPS obrigatório, uma senha de administrador conferida contra hash scrypt, sessão em cookie
__Host-, token CSRF em todo envio e nenhuma dependência fora da biblioteca padrão do Python.
Não usa JavaScript nem o socket do Docker: os usuários do FTP são alterados pelo mesmo
allsafe-ftp-user do serviço ftp, na pasta /auth que os dois containers compartilham.

Modos: sem argumento, sobe o servidor; --hash lê uma senha da entrada padrão e imprime o hash;
--saude confere /saude e sai com 0 ou 1 (healthcheck do container).
"""
import base64
import datetime
import hashlib
import hmac
import html
import http.server
import ipaddress
import os
import re
import secrets
import shutil
import socket
import ssl
import subprocess
import sys
import threading
import time
import urllib.parse
import urllib.request

PORTA = 8443
RAIZ = os.path.dirname(os.path.abspath(__file__))
ARQ_HASH = '/run/secrets/painel_password_hash'
ARQ_CERT = '/painel/tls/painel-cert.pem'
ARQ_CHAVE = '/painel/tls/painel-key.pem'
ARQ_AUDITORIA = '/painel/auditoria.log'
ARQ_USUARIOS = '/auth/pureftpd.passwd'
ARQ_CERT_FTP = '/auth/ftp-cert.pem'
CMD_USUARIO = '/usr/local/sbin/allsafe-ftp-user'
PASTA_DADOS = '/data'

# Mesma regra de nome do allsafe-ftp-user; aqui ela só antecipa a mensagem de erro.
NOME = re.compile(r'[a-z_][a-z0-9_-]{0,31}')
PRIVADAS = [ipaddress.ip_network(r) for r in ('127.0.0.0/8', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')]

CORPO_MAX = 8192            # bytes de um envio de formulário
TEMPO_CONEXAO = 15          # segundos por conexão
CONEXOES_MAX = 32
FALHAS_MAX = 5              # falhas de entrada por IP...
JANELA_FALHAS = 15 * 60     # ...nesta janela, em segundos
SESSAO_ABSOLUTA = 8 * 3600
SESSOES_MAX = 50
VALIDADE_FORMULARIO = 15 * 60
AUDITORIA_MAX = 1024 * 1024
SENHA_MIN, SENHA_MAX = 12, 128

SCRYPT_LOG_N, SCRYPT_R, SCRYPT_P = 15, 8, 1
SCRYPT_MAXMEM = 128 * 1024 * 1024

CABECALHOS = (
    ('Content-Security-Policy', "default-src 'none'; style-src 'self'; img-src 'self'; form-action 'self'; "
                                "frame-ancestors 'none'; base-uri 'none'"),
    ('X-Frame-Options', 'DENY'),
    ('X-Content-Type-Options', 'nosniff'),
    ('Referrer-Policy', 'no-referrer'),
    ('Strict-Transport-Security', 'max-age=31536000'),
    ('Cross-Origin-Opener-Policy', 'same-origin'),
    ('Cross-Origin-Resource-Policy', 'same-origin'),
    ('Permissions-Policy', 'camera=(), geolocation=(), microphone=()'),
    ('Cache-Control', 'no-store'),
)

EVENTOS = {
    'painel_iniciado': '🚀 Painel iniciado',
    'entrada_ok': '✅ Entrada',
    'entrada_falha': '❌ Senha recusada',
    'entrada_bloqueada': '⛔ Entrada bloqueada pelo limite de tentativas',
    'saida': '🚪 Saída',
    'usuario_criado': '👤 Usuário criado',
    'senha_trocada': '🔑 Senha trocada',
    'usuario_removido': '🗑️ Usuário removido',
    'falha_comando': '⚠️ Alteração não concluída',
    'recusa_csrf': '⛔ Envio sem token válido',
    'recusa_origem': '⛔ Envio de outra origem',
    'recusa_host': '⛔ Endereço não aceito',
    'recusa_rede': '⛔ Cliente fora das redes permitidas',
}
MENSAGENS = {
    'criado': '✅ Usuário criado.',
    'senha': '✅ Senha trocada.',
    'removido': '✅ Usuário removido. Os arquivos continuam na pasta.',
}


def falha(texto):
    print(f'FALHA: {texto}', file=sys.stderr, flush=True)
    sys.exit(1)


# ---------------------------------------------------------------- senha do painel (scrypt)

def b64(dados):
    return base64.b64encode(dados).decode()


def gerar_hash(senha):
    sal = secrets.token_bytes(16)
    resumo = hashlib.scrypt(senha.encode(), salt=sal, n=2 ** SCRYPT_LOG_N, r=SCRYPT_R, p=SCRYPT_P,
                            maxmem=SCRYPT_MAXMEM, dklen=32)
    return f'scrypt${SCRYPT_LOG_N}${SCRYPT_R}${SCRYPT_P}${b64(sal)}${b64(resumo)}'


def ler_hash():
    """Devolve (log_n, r, p, sal, resumo) do segredo, ou None se o arquivo não serve."""
    try:
        with open(ARQ_HASH, encoding='ascii') as arq:
            campos = arq.read().strip().split('$')
        if len(campos) != 6 or campos[0] != 'scrypt':
            return None
        log_n, r, p = int(campos[1]), int(campos[2]), int(campos[3])
        sal, resumo = base64.b64decode(campos[4], validate=True), base64.b64decode(campos[5], validate=True)
        if not (14 <= log_n <= 17 and r == 8 and 1 <= p <= 2 and len(sal) >= 16 and len(resumo) == 32):
            return None
        return log_n, r, p, sal, resumo
    except (OSError, ValueError):
        return None


TRAVA_SCRYPT = threading.Lock()  # um cálculo por vez: cada um usa 32 MiB


def senha_confere(senha):
    guardado = ler_hash()
    if guardado is None:
        return False
    log_n, r, p, sal, resumo = guardado
    with TRAVA_SCRYPT:
        calculado = hashlib.scrypt(senha.encode(), salt=sal, n=2 ** log_n, r=r, p=p,
                                   maxmem=SCRYPT_MAXMEM, dklen=len(resumo))
    return hmac.compare_digest(calculado, resumo)


# ---------------------------------------------------------------- configuração

def configuracao():
    amb = os.environ.get
    redes = []
    for texto in amb('PAINEL_REDES_PERMITIDAS', '127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16').split(','):
        try:
            rede = ipaddress.ip_network(texto.strip())
        except ValueError:
            falha(f'PAINEL_REDES_PERMITIDAS: "{texto.strip()}" não é uma rede válida')
        if rede.version != 4 or not any(rede.subnet_of(p) for p in PRIVADAS):
            falha(f'PAINEL_REDES_PERMITIDAS: {rede} não é rede privada. Esta stack é só para rede interna.')
        redes.append(rede)
    minutos = amb('PAINEL_SESSAO_MINUTOS', '15')
    if not (minutos.isdigit() and 1 <= int(minutos) <= 120):
        falha('PAINEL_SESSAO_MINUTOS deve ficar entre 1 e 120')
    try:
        with open(os.path.join(RAIZ, 'VERSION'), encoding='utf-8') as arq:
            versao = arq.read().strip()
    except OSError:
        versao = '?'
    return {
        'redes': redes,
        'inatividade': int(minutos) * 60,
        'cert_cn': amb('PAINEL_CERT_CN', '').strip().lower(),
        'painel_bind': amb('PAINEL_BIND_IP', '127.0.0.1'),
        'painel_porta': amb('PAINEL_PORT', '8443'),
        'ftp_host': amb('PAINEL_FTP_HOST', 'ftp'),
        'ftp_usuario': amb('FTP_USER', 'transfer'),
        'ftp_bind': amb('FTP_BIND_IP', '127.0.0.1'),
        'ftp_porta': amb('FTP_PORT', '21'),
        'ftp_anunciado': amb('FTP_PUBLIC_IP', '127.0.0.1'),
        'ftp_tls': amb('FTP_TLS_MODE', '2'),
        'ftp_passiva': f"{amb('FTP_PASSIVE_PORT_START', '30000')}–{amb('FTP_PASSIVE_PORT_END', '30049')}",
        'pasta_host': amb('PAINEL_PASTA_DADOS', 'DATA_DIR/dados').rstrip('/'),
        'versao': versao,
    }


CFG = {}
CHAVE_PROCESSO = secrets.token_bytes(32)  # assina o formulário de entrada; some ao reiniciar

# ---------------------------------------------------------------- auditoria

TRAVA_AUDITORIA = threading.Lock()
ULTIMA_RECUSA = {}


def limpo(texto, tamanho=80):
    """Texto vindo do cliente, reduzido a caracteres que não quebram a linha da auditoria."""
    return re.sub(r'[^A-Za-z0-9_.:/\[\]-]', '?', str(texto))[:tamanho]


def auditar(ip, evento, detalhe=''):
    """Uma linha por evento. Nunca recebe senha, token nem cookie."""
    linha = f'{time.strftime("%Y-%m-%dT%H:%M:%S%z")} ip={ip} evento={evento}' + (f' {detalhe}' if detalhe else '')
    with TRAVA_AUDITORIA:
        if evento.startswith('recusa_'):  # recusa repetida do mesmo IP: uma linha por minuto
            agora = time.monotonic()
            if agora - ULTIMA_RECUSA.get((ip, evento), -60) < 60:
                return
            if len(ULTIMA_RECUSA) > 1000:
                ULTIMA_RECUSA.clear()
            ULTIMA_RECUSA[(ip, evento)] = agora
        try:
            if os.path.exists(ARQ_AUDITORIA) and os.path.getsize(ARQ_AUDITORIA) > AUDITORIA_MAX:
                os.replace(ARQ_AUDITORIA, ARQ_AUDITORIA + '.1')
            descritor = os.open(ARQ_AUDITORIA, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
            with os.fdopen(descritor, 'a', encoding='utf-8') as arq:
                arq.write(linha + '\n')
        except OSError as erro:
            print(f'auditoria indisponível: {erro}', file=sys.stderr, flush=True)
    print(linha, flush=True)


def ler_auditoria(limite=300):
    linhas = []
    for caminho in (ARQ_AUDITORIA + '.1', ARQ_AUDITORIA):
        try:
            with open(caminho, encoding='utf-8', errors='replace') as arq:
                linhas.extend(arq.read().splitlines())
        except OSError:
            continue
    return linhas[-limite:][::-1]


# ---------------------------------------------------------------- sessão, tentativas e formulário de entrada

TRAVA = threading.Lock()
SESSOES = {}   # sha256 do token → {'criada', 'uso', 'csrf', 'ip'}
FALHAS = {}    # ip → [instantes das falhas]


def resumo_token(token):
    return hashlib.sha256(token.encode()).hexdigest()


def criar_sessao(ip):
    token = secrets.token_urlsafe(32)
    agora = time.time()
    with TRAVA:
        for chave in [c for c, s in SESSOES.items() if sessao_vencida(s, agora)]:
            del SESSOES[chave]
        while len(SESSOES) >= SESSOES_MAX:
            del SESSOES[min(SESSOES, key=lambda c: SESSOES[c]['uso'])]
        SESSOES[resumo_token(token)] = {'criada': agora, 'uso': agora, 'csrf': secrets.token_urlsafe(32), 'ip': ip}
    return token


def sessao_vencida(sessao, agora):
    return agora - sessao['uso'] > CFG['inatividade'] or agora - sessao['criada'] > SESSAO_ABSOLUTA


def buscar_sessao(token, ip):
    agora = time.time()
    with TRAVA:
        chave = resumo_token(token)
        sessao = SESSOES.get(chave)
        if sessao is None:
            return None
        if sessao_vencida(sessao, agora) or sessao['ip'] != ip:
            del SESSOES[chave]
            return None
        sessao['uso'] = agora
        return sessao


def encerrar_sessao(token):
    with TRAVA:
        SESSOES.pop(resumo_token(token), None)


def bloqueado(ip):
    agora = time.time()
    with TRAVA:
        recentes = [t for t in FALHAS.get(ip, ()) if agora - t < JANELA_FALHAS]
        if recentes:
            FALHAS[ip] = recentes
        else:
            FALHAS.pop(ip, None)
        return len(recentes) >= FALHAS_MAX


def registrar_falha(ip):
    with TRAVA:
        if len(FALHAS) > 5000:
            FALHAS.clear()
        FALHAS.setdefault(ip, []).append(time.time())


def token_formulario():
    instante = str(int(time.time()))
    return instante + '.' + hmac.new(CHAVE_PROCESSO, instante.encode(), 'sha256').hexdigest()


def token_formulario_valido(token):
    instante, _, assinatura = str(token).partition('.')
    if not instante.isdigit():
        return False
    esperado = hmac.new(CHAVE_PROCESSO, instante.encode(), 'sha256').hexdigest()
    return hmac.compare_digest(assinatura, esperado) and 0 <= time.time() - int(instante) <= VALIDADE_FORMULARIO


# ---------------------------------------------------------------- leitura do estado da stack

TRAVA_CACHE = threading.Lock()
CACHE = {}


def com_cache(chave, validade, funcao):
    agora = time.monotonic()
    with TRAVA_CACHE:
        guardado = CACHE.get(chave)
        if guardado and agora - guardado[0] < validade:
            return guardado[1]
    valor = funcao()
    with TRAVA_CACHE:
        CACHE[chave] = (agora, valor)
    return valor


def limpar_cache():
    with TRAVA_CACHE:
        CACHE.clear()


def usuarios():
    """Nome e pasta de cada usuário. O hash da senha, que está no mesmo arquivo, nunca sai daqui."""
    lista = []
    try:
        with open(ARQ_USUARIOS, encoding='utf-8', errors='replace') as arq:
            for linha in arq:
                campos = linha.rstrip('\n').split(':')
                if len(campos) > 5 and NOME.fullmatch(campos[0]):
                    lista.append(campos[0])
    except OSError:
        pass
    return sorted(lista)


def uso_da_pasta(nome):
    """Tamanho, quantidade e data do arquivo mais novo de /data/<nome>, com limite de tempo e de itens."""
    def medir():
        total = arquivos = 0
        ultimo = 0.0
        parcial = False
        prazo = time.monotonic() + 2
        pilha = [os.path.join(PASTA_DADOS, nome)]
        while pilha:
            try:
                with os.scandir(pilha.pop()) as itens:
                    for item in itens:
                        try:
                            if item.is_dir(follow_symlinks=False):
                                pilha.append(item.path)
                            elif item.is_file(follow_symlinks=False):
                                dados = item.stat(follow_symlinks=False)
                                total += dados.st_size
                                arquivos += 1
                                ultimo = max(ultimo, dados.st_mtime)
                        except OSError:
                            continue
                        if arquivos >= 50000 or time.monotonic() > prazo:
                            parcial = True
                            pilha.clear()
                            break
            except OSError:
                continue
        return {'bytes': total, 'arquivos': arquivos, 'ultimo': ultimo, 'parcial': parcial}
    return com_cache(('uso', nome), 60, medir)


def ftp_no_ar():
    def conferir():
        try:
            with socket.create_connection((CFG['ftp_host'], 2121), timeout=3) as conexao:
                conexao.settimeout(3)
                saudacao = conexao.recv(256)
                conexao.sendall(b'QUIT\r\n')
            return saudacao.startswith(b'220')
        except OSError:
            return False
    return com_cache('ftp', 5, conferir)


def certificado(caminho):
    """Validade, impressão digital e nome de um certificado, pela parte pública dele."""
    def ler():
        try:
            saida = subprocess.run(
                ['openssl', 'x509', '-in', caminho, '-noout', '-enddate', '-fingerprint', '-sha256', '-subject'],
                capture_output=True, text=True, timeout=5, check=True).stdout
        except (OSError, subprocess.SubprocessError):
            return None
        info = {'digital': '', 'nome': '', 'vence': None}
        for linha in saida.splitlines():
            chave, _, valor = linha.partition('=')
            if chave == 'notAfter':
                try:
                    vence = datetime.datetime.strptime(valor.strip(), '%b %d %H:%M:%S %Y %Z')
                    info['vence'] = vence.replace(tzinfo=datetime.timezone.utc)
                except ValueError:
                    pass
            elif chave.lower().startswith('sha256'):
                info['digital'] = valor.strip()
            elif chave == 'subject':
                info['nome'] = valor.strip()
        return info
    return com_cache(('cert', caminho), 60, ler)


def dias_restantes(info):
    if not info or not info['vence']:
        return None
    return (info['vence'] - datetime.datetime.now(datetime.timezone.utc)).days


def executar_usuario(acao, nome, senha=None):
    """Chama o allsafe-ftp-user, o mesmo do serviço ftp. A senha vai pela entrada padrão."""
    try:
        resultado = subprocess.run(
            [CMD_USUARIO, acao, nome], input=None if senha is None else senha + '\n',
            capture_output=True, text=True, timeout=30,
            env={'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin', 'LC_ALL': 'C'})
    except (OSError, subprocess.SubprocessError):
        return False, 'O comando de usuários não respondeu.'
    limpar_cache()
    if resultado.returncode != 0:
        ultima = (resultado.stderr.strip().splitlines() or ['erro sem mensagem'])[-1]
        return False, ultima[:200]
    return True, ''


# ---------------------------------------------------------------- textos

def e(texto):
    return html.escape(str(texto), quote=True)


def tamanho(valor):
    for unidade in ('B', 'KiB', 'MiB', 'GiB', 'TiB'):
        if valor < 1024 or unidade == 'TiB':
            return f'{valor:.0f} {unidade}' if unidade == 'B' else f'{valor:.1f} {unidade}'.replace('.', ',')
        valor /= 1024
    return ''


def quando(instante):
    return time.strftime('%d/%m/%Y %H:%M', time.localtime(instante)) if instante else '—'


def validade(info):
    dias = dias_restantes(info)
    if dias is None:
        return '⚠️', 'não foi possível ler o certificado'
    data = info['vence'].astimezone().strftime('%d/%m/%Y')
    if dias < 0:
        return '❌', f'vencido em {data}'
    return ('⚠️' if dias < 30 else '✅'), f'válido até {data} ({dias} dias)'


# ---------------------------------------------------------------- servidor HTTPS

class Servidor(http.server.ThreadingHTTPServer):
    daemon_threads = True
    request_queue_size = CONEXOES_MAX
    allow_reuse_address = True

    def __init__(self, endereco, tratador, contexto):
        super().__init__(endereco, tratador)
        self.contexto = contexto
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
        # O aperto de mão TLS acontece aqui, na thread da conexão, com tempo limite:
        # um cliente lento ou que fala HTTP puro não segura o laço que aceita conexões.
        try:
            try:
                request.settimeout(TEMPO_CONEXAO)
                request = self.contexto.wrap_socket(request, server_side=True)
            except (OSError, ssl.SSLError):
                self.shutdown_request(request)
                return
            super().process_request_thread(request, client_address)
        finally:
            self.vagas.release()

    def handle_error(self, request, client_address):
        erro = sys.exc_info()[1]
        if not isinstance(erro, (OSError, ssl.SSLError)):
            print(f'erro ao atender {client_address[0]}: {type(erro).__name__}', file=sys.stderr, flush=True)


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
        return ip.version == 4 and any(ip in rede for rede in PRIVADAS)

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
        self.ip = self.client_address[0]
        url = urllib.parse.urlsplit(self.path)
        self.caminho = url.path
        try:
            consulta = {n: v[0] for n, v in urllib.parse.parse_qs(url.query, max_num_fields=5).items()}
        except ValueError:
            consulta = {}

        if not self.rede_permitida():
            auditar(self.ip, 'recusa_rede')
            return self.enviar(403, 'cliente fora das redes permitidas\n', 'text/plain; charset=utf-8')
        if not self.host_valido():
            auditar(self.ip, 'recusa_host', f'host={limpo(self.headers.get("Host", ""))}')
            return self.enviar(400, 'endereço não aceito\n', 'text/plain; charset=utf-8')

        if metodo == 'GET' and self.caminho == '/saude':
            return self.enviar(200, 'ok\n', 'text/plain; charset=utf-8')
        if metodo == 'GET' and self.caminho == '/estilo.css':
            return self.enviar(200, ESTILO, 'text/css; charset=utf-8')
        if metodo == 'GET' and self.caminho == '/favicon.svg':
            return self.enviar(200, ICONE, 'image/svg+xml')

        formulario = {}
        if metodo == 'POST':
            formulario = self.ler_formulario()
            if formulario is None:
                return None
            if not self.origem_valida():
                auditar(self.ip, 'recusa_origem', f'caminho={limpo(self.caminho)}')
                return self.recusar(403, 'O envio não partiu deste painel.')

        if self.caminho == '/entrar':
            return self.entrar(metodo, formulario)

        token = self.token_do_cookie()
        sessao = buscar_sessao(token, self.ip) if token else None
        if sessao is None:
            return self.redirecionar('/entrar')
        if metodo == 'POST' and not hmac.compare_digest(formulario.get('csrf', ''), sessao['csrf']):
            auditar(self.ip, 'recusa_csrf', f'caminho={limpo(self.caminho)}')
            return self.recusar(403, 'Formulário sem token válido. Abra a página de novo e repita.')

        rota = ROTAS.get((metodo, self.caminho))
        if rota is None:
            return self.enviar(404, pagina('Não encontrado', '<section class="cartao"><h1>🔎 Página não encontrada</h1>'
                                           '<p><a href="/">Voltar ao painel</a></p></section>', sessao))
        return rota(self, sessao, consulta, formulario, token)

    # ------------------------------------------------------------ entrada e saída

    def tela_entrada(self, codigo=200, erro=''):
        aviso = f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''
        self.enviar(codigo, pagina('Entrar', f'''<section class="cartao entrada">
<h1>🗄️ AllSafe FTP</h1>
<p class="suave">Painel de administração da stack.</p>
{aviso}
<form method="post" action="/entrar" autocomplete="off">
<input type="hidden" name="token" value="{e(token_formulario())}">
<label for="senha">Senha do painel</label>
<input id="senha" name="senha" type="password" required autofocus autocomplete="current-password" maxlength="256">
<button type="submit">Entrar</button>
</form>
<p class="aviso">🧱 Uso só em rede privada, atrás de firewall. Nunca publique este painel na internet.</p>
</section>'''))

    def entrar(self, metodo, formulario):
        if metodo == 'GET':
            token = self.token_do_cookie()
            if token and buscar_sessao(token, self.ip):
                return self.redirecionar('/')
            return self.tela_entrada()
        if bloqueado(self.ip):
            auditar(self.ip, 'entrada_bloqueada')
            return self.tela_entrada(429, 'Muitas tentativas. Aguarde alguns minutos e tente de novo.')
        if not token_formulario_valido(formulario.get('token', '')):
            return self.tela_entrada(400, 'A página expirou. Tente de novo.')
        senha = formulario.get('senha', '')
        if not (0 < len(senha) <= 256 and senha_confere(senha)):
            registrar_falha(self.ip)
            auditar(self.ip, 'entrada_falha')
            return self.tela_entrada(401, 'Não foi possível entrar.')
        auditar(self.ip, 'entrada_ok')
        cookie = f'__Host-sessao={criar_sessao(self.ip)}; Path=/; Secure; HttpOnly; SameSite=Strict'
        return self.redirecionar('/', (('Set-Cookie', cookie),))

    def sair(self, sessao, consulta, formulario, token):
        encerrar_sessao(token)
        auditar(self.ip, 'saida')
        vazio = '__Host-sessao=; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=0'
        self.redirecionar('/entrar', (('Set-Cookie', vazio),))

    # ------------------------------------------------------------ abas

    def visao_geral(self, sessao, consulta, formulario, token):
        nomes = usuarios()
        usos = [uso_da_pasta(nome) for nome in nomes]
        total = sum(u['bytes'] for u in usos)
        ultimo = max((u['ultimo'] for u in usos), default=0)
        no_ar = ftp_no_ar()
        marca, texto_cert = validade(certificado(ARQ_CERT_FTP))
        try:
            livre = tamanho(shutil.disk_usage(PASTA_DADOS).free) + ' livres no disco'
        except OSError:
            livre = ''
        tls = {'1': 'TLS opcional', '2': 'TLS obrigatório no login', '3': 'TLS obrigatório no login e nos dados'}
        self.enviar(200, pagina('Visão geral', f'''<h1>📊 Visão geral</h1>
<div class="grade">
<section class="cartao"><h2>⚙️ Servidor FTP</h2><p class="numero {'bom' if no_ar else 'ruim'}">{'🟢 No ar' if no_ar else '🔴 Fora do ar'}</p>
<p class="suave">{e(tls.get(CFG['ftp_tls'], 'modo TLS ' + CFG['ftp_tls']))}</p></section>
<section class="cartao"><h2>👥 Usuários</h2><p class="numero">{len(nomes)}</p><p class="suave"><a href="/usuarios">ver a lista</a></p></section>
<section class="cartao"><h2>💽 Espaço usado</h2><p class="numero">{e(tamanho(total))}</p><p class="suave">{e(livre)}</p></section>
<section class="cartao"><h2>📥 Último envio</h2><p class="numero menor">{e(quando(ultimo))}</p><p class="suave">arquivo mais novo nas pastas</p></section>
<section class="cartao"><h2>🔐 Certificado do FTP</h2><p class="numero menor">{marca} {e(texto_cert)}</p><p class="suave"><a href="/seguranca">conferir a impressão digital</a></p></section>
</div>
<section class="cartao"><h2>📡 Dados para configurar o equipamento</h2>
<table><tbody>
<tr><th scope="row">Servidor</th><td><code>{e(CFG['ftp_anunciado'])}</code></td></tr>
<tr><th scope="row">Porta de controle</th><td><code>{e(CFG['ftp_porta'])}</code>/tcp</td></tr>
<tr><th scope="row">Portas passivas</th><td><code>{e(CFG['ftp_passiva'])}</code>/tcp</td></tr>
<tr><th scope="row">Protocolo</th><td>FTPS explícito (FTP com TLS), modo passivo</td></tr>
<tr><th scope="row">Usuário e senha</th><td>um usuário por equipamento ou por grupo, criado em <a href="/usuarios">👥 Usuários</a></td></tr>
</tbody></table></section>''', sessao, '/'))

    def lista_usuarios(self, sessao, consulta, formulario, token):
        aviso = MENSAGENS.get(consulta.get('m', ''), '')
        linhas = []
        for nome in usuarios():
            uso = uso_da_pasta(nome)
            mais = ' ou mais' if uso['parcial'] else ''
            if nome == CFG['ftp_usuario']:
                acoes = '<span class="suave">usuário inicial: a senha vem de <code>.secrets/ftp_password.txt</code></span>'
                marca = ' <span class="etiqueta">inicial</span>'
            else:
                destino = urllib.parse.quote(nome)
                acoes = (f'<a class="botao" href="/usuarios/senha?usuario={destino}">🔑 Trocar senha</a> '
                         f'<a class="botao perigo" href="/usuarios/remover?usuario={destino}">🗑️ Remover</a>')
                marca = ''
            linhas.append(f'<tr><td><strong>{e(nome)}</strong>{marca}</td><td><code>{e(CFG["pasta_host"])}/{e(nome)}</code></td>'
                          f'<td>{e(tamanho(uso["bytes"]))}{mais}</td><td>{uso["arquivos"]}{mais}</td>'
                          f'<td>{e(quando(uso["ultimo"]))}</td><td class="acoes">{acoes}</td></tr>')
        corpo = ''.join(linhas) or '<tr><td colspan="6" class="suave">Nenhum usuário ainda.</td></tr>'
        self.enviar(200, pagina('Usuários', f'''<h1>👥 Usuários</h1>
{f'<p class="ok" role="status">{e(aviso)}</p>' if aviso else ''}
<p><a class="botao principal" href="/usuarios/novo">➕ Novo usuário</a></p>
<section class="cartao"><div class="rolagem"><table>
<thead><tr><th>Usuário</th><th>Pasta no host</th><th>Uso</th><th>Arquivos</th><th>Último envio</th><th>Ações</th></tr></thead>
<tbody>{corpo}</tbody></table></div>
<p class="suave">Cada usuário fica preso na própria pasta. A alteração vale no próximo login, sem reiniciar o FTP.</p></section>''',
                                sessao, '/usuarios'))

    def campos_de_senha(self):
        return f'''<label for="senha">Senha <span class="suave">(deixe em branco para o painel gerar uma senha forte)</span></label>
<input id="senha" name="senha" type="password" autocomplete="new-password" minlength="{SENHA_MIN}" maxlength="{SENHA_MAX}">
<label for="confirmacao">Repita a senha</label>
<input id="confirmacao" name="confirmacao" type="password" autocomplete="new-password" maxlength="{SENHA_MAX}">
<p class="suave">Mínimo de {SENHA_MIN} caracteres. A senha gerada aparece uma única vez, na tela seguinte.</p>'''

    def senha_do_formulario(self, formulario):
        """Devolve (senha, gerada, erro)."""
        senha, repetida = formulario.get('senha', ''), formulario.get('confirmacao', '')
        if not senha and not repetida:
            return secrets.token_urlsafe(24), True, ''
        if senha != repetida:
            return '', False, 'As duas senhas não são iguais.'
        if not SENHA_MIN <= len(senha) <= SENHA_MAX:
            return '', False, f'A senha deve ter de {SENHA_MIN} a {SENHA_MAX} caracteres.'
        if any(ord(letra) < 32 or ord(letra) == 127 for letra in senha):
            return '', False, 'A senha não pode ter caractere de controle.'
        return senha, False, ''

    def tela_senha_gerada(self, sessao, nome, senha, titulo):
        self.enviar(200, pagina(titulo, f'''<h1>{e(titulo)}</h1>
<section class="cartao"><p>Usuário <strong>{e(nome)}</strong>. Senha gerada pelo painel:</p>
<p class="segredo"><code>{e(senha)}</code></p>
<p class="aviso">⚠️ Copie agora para o equipamento ou para o seu cofre de senhas. Ela <strong>não será mostrada de novo</strong>
e não fica guardada em lugar nenhum além do hash do FTP.</p>
<p><a class="botao principal" href="/usuarios">Já copiei: voltar para a lista</a></p></section>''', sessao, '/usuarios'))

    def tela_novo(self, sessao, consulta=None, formulario=None, token=None, erro='', codigo=200, nome=''):
        self.enviar(codigo, pagina('Novo usuário', f'''<h1>➕ Novo usuário</h1>
<section class="cartao estreito">{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<form method="post" action="/usuarios/novo" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<label for="usuario">Nome do usuário</label>
<input id="usuario" name="usuario" required maxlength="32" pattern="[a-z_][a-z0-9_\\-]*" value="{e(nome)}" autocapitalize="none" spellcheck="false">
<p class="suave">Letras minúsculas, números, <code>_</code> e <code>-</code>; começa com letra ou <code>_</code>; até 32 caracteres.</p>
{self.campos_de_senha()}
<button type="submit">Criar usuário</button> <a class="botao" href="/usuarios">Cancelar</a>
</form></section>''', sessao, '/usuarios'))

    def criar_usuario(self, sessao, consulta, formulario, token):
        nome = formulario.get('usuario', '').strip()
        if not NOME.fullmatch(nome):
            return self.tela_novo(sessao, erro='Nome inválido. Veja a regra abaixo do campo.', codigo=400)
        if nome in usuarios():
            return self.tela_novo(sessao, erro='Já existe um usuário com este nome.', codigo=409, nome=nome)
        senha, gerada, erro = self.senha_do_formulario(formulario)
        if erro:
            return self.tela_novo(sessao, erro=erro, codigo=400, nome=nome)
        feito, mensagem = executar_usuario('add', nome, senha)
        if not feito:
            auditar(self.ip, 'falha_comando', f'acao=criar usuario={nome}')
            return self.tela_novo(sessao, erro='Não foi possível criar: ' + mensagem, codigo=500, nome=nome)
        auditar(self.ip, 'usuario_criado', f'usuario={nome} credencial={"gerada" if gerada else "informada"}')
        if gerada:
            return self.tela_senha_gerada(sessao, nome, senha, '✅ Usuário criado')
        return self.redirecionar('/usuarios?m=criado')

    def usuario_alteravel(self, sessao, nome):
        """Confere o nome recebido; responde com o erro e devolve False se não der para alterar."""
        if not NOME.fullmatch(nome) or nome not in usuarios():
            self.enviar(404, pagina('Usuário não encontrado', '<section class="cartao"><h1>🔎 Usuário não encontrado</h1>'
                                    '<p><a href="/usuarios">Voltar para a lista</a></p></section>', sessao, '/usuarios'))
            return False
        if nome == CFG['ftp_usuario']:
            self.enviar(409, pagina('Usuário inicial', '<section class="cartao"><h1>🔑 Usuário inicial</h1>'
                                    '<p>A senha deste usuário vem do arquivo <code>.secrets/ftp_password.txt</code> e é '
                                    'reaplicada a cada subida do FTP. Troque por lá: o guia de segredos mostra como.</p>'
                                    '<p><a href="/usuarios">Voltar para a lista</a></p></section>', sessao, '/usuarios'))
            return False
        return True

    def tela_trocar_senha(self, sessao, consulta, formulario=None, token=None, erro='', codigo=200):
        nome = consulta.get('usuario', '')
        if not self.usuario_alteravel(sessao, nome):
            return
        self.enviar(codigo, pagina('Trocar senha', f'''<h1>🔑 Trocar senha</h1>
<section class="cartao estreito">{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<p>Usuário <strong>{e(nome)}</strong>. A senha antiga deixa de valer no próximo login.</p>
<form method="post" action="/usuarios/senha" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<input type="hidden" name="usuario" value="{e(nome)}">
{self.campos_de_senha()}
<button type="submit">Trocar senha</button> <a class="botao" href="/usuarios">Cancelar</a>
</form></section>''', sessao, '/usuarios'))

    def trocar_senha(self, sessao, consulta, formulario, token):
        nome = formulario.get('usuario', '')
        if not self.usuario_alteravel(sessao, nome):
            return None
        senha, gerada, erro = self.senha_do_formulario(formulario)
        if erro:
            return self.tela_trocar_senha(sessao, {'usuario': nome}, erro=erro, codigo=400)
        feito, mensagem = executar_usuario('passwd', nome, senha)
        if not feito:
            auditar(self.ip, 'falha_comando', f'acao=trocar_senha usuario={nome}')
            return self.tela_trocar_senha(sessao, {'usuario': nome}, erro='Não foi possível trocar: ' + mensagem, codigo=500)
        auditar(self.ip, 'senha_trocada', f'usuario={nome} credencial={"gerada" if gerada else "informada"}')
        if gerada:
            return self.tela_senha_gerada(sessao, nome, senha, '✅ Senha trocada')
        return self.redirecionar('/usuarios?m=senha')

    def tela_remover(self, sessao, consulta, formulario=None, token=None):
        nome = consulta.get('usuario', '')
        if not self.usuario_alteravel(sessao, nome):
            return
        uso = uso_da_pasta(nome)
        self.enviar(200, pagina('Remover usuário', f'''<h1>🗑️ Remover usuário</h1>
<section class="cartao estreito">
<p>Remover <strong>{e(nome)}</strong>? O login deixa de funcionar na hora.</p>
<p class="aviso">📁 Os arquivos <strong>não são apagados</strong>: {uso['arquivos']} arquivo(s), {e(tamanho(uso['bytes']))},
continuam em <code>{e(CFG['pasta_host'])}/{e(nome)}</code>.</p>
<form method="post" action="/usuarios/remover">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<input type="hidden" name="usuario" value="{e(nome)}">
<input type="hidden" name="confirmar" value="sim">
<button class="perigo" type="submit">Sim, remover o usuário</button> <a class="botao" href="/usuarios">Cancelar</a>
</form></section>''', sessao, '/usuarios'))

    def remover_usuario(self, sessao, consulta, formulario, token):
        nome = formulario.get('usuario', '')
        if not self.usuario_alteravel(sessao, nome):
            return None
        if formulario.get('confirmar') != 'sim':
            return self.redirecionar('/usuarios/remover?usuario=' + urllib.parse.quote(nome))
        feito, mensagem = executar_usuario('del', nome)
        if not feito:
            auditar(self.ip, 'falha_comando', f'acao=remover usuario={nome}')
            return self.recusar(500, 'Não foi possível remover: ' + mensagem)
        auditar(self.ip, 'usuario_removido', f'usuario={nome}')
        return self.redirecionar('/usuarios?m=removido')

    def seguranca(self, sessao, consulta, formulario, token):
        tls = {'1': ('⚠️', 'opcional: aceita login sem criptografia. Use só com equipamento legado.'),
               '2': ('✅', 'obrigatório no login; os dados seguem o que o cliente pedir.'),
               '3': ('✅', 'obrigatório no login e nos dados.')}
        marca_tls, texto_tls = tls.get(CFG['ftp_tls'], ('⚠️', 'modo desconhecido'))
        cert_ftp, cert_painel = certificado(ARQ_CERT_FTP), certificado(ARQ_CERT)
        marca_ftp, validade_ftp = validade(cert_ftp)
        marca_painel, validade_painel = validade(cert_painel)
        somente_leitura = not os.access('/', os.W_OK)
        sem_docker = not os.path.exists('/var/run/docker.sock') and not os.path.exists('/run/docker.sock')
        redes = ', '.join(str(rede) for rede in CFG['redes'])

        def local(ip):
            return 'só o próprio host alcança' if ip.startswith('127.') else 'alcançável pela rede interna deste endereço'

        def linha(marca, item, situacao):
            return f'<tr><td class="marca">{marca}</td><th scope="row">{item}</th><td>{situacao}</td></tr>'
        itens = [
            linha('✅', 'Endereço do FTP', f'<code>{e(CFG["ftp_bind"])}:{e(CFG["ftp_porta"])}</code> — IP privado, {local(CFG["ftp_bind"])}.'),
            linha('✅', 'IP anunciado no modo passivo', f'<code>{e(CFG["ftp_anunciado"])}</code> — IP privado.'),
            linha(marca_tls, 'TLS do FTP', f'Modo <code>{e(CFG["ftp_tls"])}</code>: {texto_tls}'),
            linha(marca_ftp, 'Certificado do FTP', f'{e(validade_ftp)}<br><span class="suave">SHA-256</span> '
                  f'<code class="digital">{e(cert_ftp["digital"] if cert_ftp else "—")}</code>'),
            linha('✅', 'Endereço do painel', f'<code>{e(CFG["painel_bind"])}:{e(CFG["painel_porta"])}</code> — só HTTPS, '
                  f'{local(CFG["painel_bind"])}.'),
            linha(marca_painel, 'Certificado do painel', f'{e(validade_painel)}<br><span class="suave">SHA-256</span> '
                  f'<code class="digital">{e(cert_painel["digital"] if cert_painel else "—")}</code>'),
            linha('✅', 'Quem pode abrir o painel', f'Clientes de <code>{e(redes)}</code>; os demais são recusados antes de qualquer tela.'),
            linha('✅', 'Sessão', f'Encerra com {CFG["inatividade"] // 60} minutos sem uso e, de qualquer forma, em 8 horas. '
                  f'{FALHAS_MAX} senhas erradas bloqueiam o endereço por 15 minutos.'),
            linha('✅' if somente_leitura else '⚠️', 'Container do painel',
                  ('Raiz somente leitura' if somente_leitura else 'Raiz gravável: confira o <code>read_only</code>')
                  + (' e sem acesso ao Docker do host.' if sem_docker else '. <strong>Há um socket do Docker montado: remova.</strong>')),
            linha('🧱', 'Firewall do host', 'O painel não enxerga o firewall. Confira você: as portas do FTP e do painel devem '
                  'estar liberadas só para as redes internas que precisam, na cadeia <code>DOCKER-USER</code>, e nenhuma delas '
                  'pode ser redirecionada da internet.'),
        ]
        self.enviar(200, pagina('Segurança', f'''<h1>🔐 Segurança</h1>
<p class="aviso">🧱 Esta stack é só para rede privada, atrás de firewall. FTP e painel recusam, por código, escutar em IP público.</p>
<section class="cartao"><div class="rolagem"><table class="conferencia"><tbody>{''.join(itens)}</tbody></table></div></section>
<p class="suave">Confira a impressão digital com a que o navegador e o cliente FTP mostram antes de aceitar o certificado.</p>''',
                                sessao, '/seguranca'))

    def atividade(self, sessao, consulta, formulario, token):
        linhas = []
        for texto in ler_auditoria():
            campos = texto.split(' ')
            if len(campos) < 3:
                continue
            momento = campos[0][:19].replace('T', ' ')
            ip = campos[1].partition('=')[2]
            evento = campos[2].partition('=')[2]
            linhas.append(f'<tr><td>{e(momento)}</td><td><code>{e(ip)}</code></td><td>{e(EVENTOS.get(evento, evento))}</td>'
                          f'<td>{e(" ".join(campos[3:]))}</td></tr>')
        corpo = ''.join(linhas) or '<tr><td colspan="4" class="suave">Nada registrado ainda.</td></tr>'
        self.enviar(200, pagina('Atividade', f'''<h1>📜 Atividade</h1>
<section class="cartao"><div class="rolagem"><table>
<thead><tr><th>Quando</th><th>De onde</th><th>O que aconteceu</th><th>Detalhe</th></tr></thead>
<tbody>{corpo}</tbody></table></div>
<p class="suave">Últimos 300 registros do painel, do mais novo para o mais antigo. Senha e token nunca são gravados.
As transferências dos equipamentos ficam no log do serviço FTP.</p></section>''', sessao, '/atividade'))


ROTAS = {
    ('GET', '/'): Painel.visao_geral,
    ('GET', '/usuarios'): Painel.lista_usuarios,
    ('GET', '/usuarios/novo'): Painel.tela_novo,
    ('POST', '/usuarios/novo'): Painel.criar_usuario,
    ('GET', '/usuarios/senha'): Painel.tela_trocar_senha,
    ('POST', '/usuarios/senha'): Painel.trocar_senha,
    ('GET', '/usuarios/remover'): Painel.tela_remover,
    ('POST', '/usuarios/remover'): Painel.remover_usuario,
    ('GET', '/seguranca'): Painel.seguranca,
    ('GET', '/atividade'): Painel.atividade,
    ('POST', '/sair'): Painel.sair,
}

ABAS = (('/', '📊 Visão geral'), ('/usuarios', '👥 Usuários'), ('/seguranca', '🔐 Segurança'), ('/atividade', '📜 Atividade'))
ICONE = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><rect width="16" height="16" rx="3" fill="#0d1117"/>'
         '<path d="M3 5h10v2H3zm0 4h10v2H3z" fill="#58a6ff"/></svg>')
ESTILO = ''


def pagina(titulo, miolo, sessao=None, ativa=''):
    menu = ''
    if sessao:
        links = ''.join(f'<a href="{caminho}"' + (' class="ativa" aria-current="page"' if caminho == ativa else '') + f'>{rotulo}</a>'
                        for caminho, rotulo in ABAS)
        menu = (f'<nav aria-label="Abas do painel">{links}<form method="post" action="/sair">'
                f'<input type="hidden" name="csrf" value="{e(sessao["csrf"])}"><button type="submit">🚪 Sair</button></form></nav>')
    return f'''<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>{e(titulo)} · AllSafe FTP</title>
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="stylesheet" href="/estilo.css">
</head>
<body>
<header><span class="marca-topo">🗄️ AllSafe FTP</span>{menu}</header>
<main>
{miolo}
</main>
<footer>allsafe-ftp-stack v{e(CFG.get('versao', '?'))} · 🧱 só para rede privada, atrás de firewall</footer>
</body>
</html>
'''


# ---------------------------------------------------------------- modos de execução

def modo_hash():
    senha = sys.stdin.readline().rstrip('\r\n')
    if not SENHA_MIN <= len(senha) <= 256:
        falha(f'a senha do painel deve ter pelo menos {SENHA_MIN} caracteres')
    print(gerar_hash(senha))


def modo_saude():
    contexto = ssl.create_default_context(cafile=ARQ_CERT)
    try:
        with urllib.request.urlopen(f'https://localhost:{PORTA}/saude', context=contexto, timeout=4) as resposta:
            sys.exit(0 if resposta.status == 200 and resposta.read().strip() == b'ok' else 1)
    except (OSError, ValueError):
        sys.exit(1)


def principal():
    global ESTILO
    if '--hash' in sys.argv[1:]:
        return modo_hash()
    if '--saude' in sys.argv[1:]:
        return modo_saude()
    CFG.update(configuracao())
    if ler_hash() is None:
        falha(f'{ARQ_HASH} ausente ou inválido: rode ./deploy.sh ou scripts/painel-senha.sh')
    with open(os.path.join(RAIZ, 'estilo.css'), encoding='utf-8') as arq:
        ESTILO = arq.read()
    contexto = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    contexto.minimum_version = ssl.TLSVersion.TLSv1_2
    contexto.load_cert_chain(ARQ_CERT, ARQ_CHAVE)
    servidor = Servidor(('0.0.0.0', PORTA), Painel, contexto)
    auditar('-', 'painel_iniciado', f'versao={limpo(CFG["versao"])}')
    print(f'Painel pronto em {PORTA}/tcp (HTTPS); sessão de {CFG["inatividade"] // 60} min; '
          f'redes permitidas: {", ".join(str(r) for r in CFG["redes"])}', flush=True)
    servidor.serve_forever()


if __name__ == '__main__':
    principal()
