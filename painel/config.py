"""Configuração do painel: caminhos, limites e o que vem do ambiente do container."""
import ipaddress
import os
import re
import sys

# Soquete Unix na pasta que o painel divide com o nginx; o grupo é o do nginx (alvo `nginx` do Dockerfile).
ARQ_SOQUETE = '/nginx/painel.sock'
GID_NGINX = 10001
RAIZ = os.path.dirname(os.path.abspath(__file__))
ARQ_HASH = '/run/secrets/painel_admin_inicial_senha_hash'
ARQ_ADMINS = '/painel/administradores'
ARQ_CERT = '/painel/tls/painel-cert.pem'
ARQ_AUDITORIA = '/painel/auditoria.log'
ARQ_USUARIOS = '/auth/pureftpd.passwd'
ARQ_CERT_FTP = '/auth/ftp-cert.pem'
CMD_USUARIO = '/usr/local/sbin/allsafe-ftp-user'
PASTA_DADOS = '/data'

# Mesma regra de nome do allsafe-ftp-user; aqui ela só antecipa a mensagem de erro. Vale também para administrador.
NOME = re.compile(r'[a-z_][a-z0-9_-]{0,31}')
PRIVADAS = [ipaddress.ip_network(r) for r in ('127.0.0.0/8', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')]

CORPO_MAX = 8192            # bytes de um envio de formulário
TEMPO_CONEXAO = 15          # segundos por conexão
CONEXOES_MAX = 32
DOWNLOADS_MAX = 8           # arquivos entregues ao mesmo tempo; o resto das conexões fica para as telas
BLOCO_ARQUIVO = 64 * 1024   # bytes lidos e enviados por vez em um download
LISTA_MAX = 2000            # itens mostrados por pasta na aba Arquivos
FALHAS_MAX = 5              # falhas de entrada por IP...
JANELA_FALHAS = 15 * 60     # ...nesta janela, em segundos
SESSAO_ABSOLUTA = 8 * 3600
SESSOES_MAX = 50
ADMINS_MAX = 20
VALIDADE_FORMULARIO = 15 * 60
AUDITORIA_MAX = 1024 * 1024
SENHA_MIN, SENHA_MAX = 12, 128

SCRYPT_LOG_N, SCRYPT_R, SCRYPT_P = 15, 8, 1
SCRYPT_MAXMEM = 128 * 1024 * 1024


def falha(texto):
    print(f'FALHA: {texto}', file=sys.stderr, flush=True)
    sys.exit(1)


def privado(ip):
    return ip.version == 4 and any(ip in rede for rede in PRIVADAS)


def endereco_privado(texto):
    try:
        return privado(ipaddress.ip_address(texto))
    except ValueError:
        return False


def configuracao():
    amb = os.environ.get
    if amb('REDE_PERMITIR_IP_PUBLICO', 'nao') not in ('nao', 'sim'):
        falha("REDE_PERMITIR_IP_PUBLICO deve ser 'nao' ou 'sim'")
    publico = amb('REDE_PERMITIR_IP_PUBLICO', 'nao') == 'sim'
    redes = []
    for texto in amb('PAINEL_REDES_PERMITIDAS', '127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16').split(','):
        try:
            rede = ipaddress.ip_network(texto.strip())
        except ValueError:
            falha(f'PAINEL_REDES_PERMITIDAS: "{texto.strip()}" não é uma rede válida')
        if rede.version != 4:
            falha(f'PAINEL_REDES_PERMITIDAS: {rede} não é uma rede IPv4')
        if not any(rede.subnet_of(p) for p in PRIVADAS):
            if not publico:
                falha(f'PAINEL_REDES_PERMITIDAS: {rede} não é rede privada. Rede pública só com REDE_PERMITIR_IP_PUBLICO=sim.')
            if rede.prefixlen < 8 or not 1 <= int(rede.network_address) >> 24 <= 223:
                falha(f'PAINEL_REDES_PERMITIDAS: {rede} não é uma rede aceita (prefixo de /8 a /32; "todo mundo" é recusado)')
        redes.append(rede)
    admin = amb('PAINEL_ADMIN_USER', 'admin')
    if not NOME.fullmatch(admin):
        falha('PAINEL_ADMIN_USER inválido: letras minúsculas, números, _ e -; começa com letra ou _; até 32 caracteres')
    minutos = amb('PAINEL_SESSAO_MINUTOS', '15')
    if not (minutos.isdigit() and 1 <= int(minutos) <= 120):
        falha('PAINEL_SESSAO_MINUTOS deve ficar entre 1 e 120')
    try:
        with open(os.path.join(RAIZ, 'VERSION'), encoding='utf-8') as arq:
            versao = arq.read().strip()
    except OSError:
        versao = '?'
    return {
        'ip_publico': publico,
        'redes': redes,
        'admin_inicial': admin,
        'inatividade': int(minutos) * 60,
        'cert_cn': amb('PAINEL_CERT_CN', '').strip().lower(),
        'painel_bind': amb('PAINEL_BIND_IP', '127.0.0.1'),
        'painel_porta': amb('PAINEL_PORT', '8443'),
        'ftp_host': amb('PAINEL_FTP_HOST', 'ftp'),
        'ftp_usuario': amb('FTP_USER', 'transfer'),
        'ftp_bind': amb('FTP_BIND_IP', '127.0.0.1'),
        'ftp_porta': amb('FTP_PORT', '21'),
        'ftp_anunciado': amb('FTP_PASSIVE_IP', '127.0.0.1'),
        'ftp_tls': amb('FTP_TLS_MODE', '2'),
        'ftp_passiva': f"{amb('FTP_PASSIVE_PORT_START', '30000')}–{amb('FTP_PASSIVE_PORT_END', '30049')}",
        'pasta_host': amb('PAINEL_PASTA_DADOS', 'DATA_DIR/dados').rstrip('/'),
        'versao': versao,
    }


# Preenchido uma vez, na subida do servidor; os outros módulos só leem.
CFG = {}
