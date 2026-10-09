# SPDX-License-Identifier: Apache-2.0
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
ARQ_SEM_TLS = '/auth/sem-tls.lista'   # quem entra sem TLS com o TLS por usuário valendo; quem grava é o allsafe-ftp-user
ARQ_LIMITES = '/auth/limites.lista'   # limites por usuário que o painel aplica; quem grava é o allsafe-ftp-user
PASTA_BLOQUEIOS = '/auth/bloqueios'   # bloqueios por tentativa no FTP, um arquivo por usuário e endereço; quem grava é o vigia do ftp
CMD_USUARIO = '/usr/local/sbin/allsafe-ftp-user'
PASTA_DADOS = '/data'

# Mesma regra de nome do allsafe-ftp-user; aqui ela só antecipa a mensagem de erro. Vale também para administrador.
NOME = re.compile(r'[a-z_][a-z0-9_-]{0,31}')
# Pasta de um usuário, dentro da pasta dos dados: até 4 níveis. Nenhum nível começa com ponto, então `.` e `..`
# não passam. É a mesma regra do allsafe-ftp-user, que é quem decide; aqui ela antecipa a mensagem de erro.
NIVEL = re.compile(r'[A-Za-z0-9_][A-Za-z0-9._-]{0,63}')
PASTA = re.compile(r'[A-Za-z0-9_][A-Za-z0-9._-]{0,63}(?:/[A-Za-z0-9_][A-Za-z0-9._-]{0,63}){0,3}')
# Contato de segurança (SEGURANCA_CONTATO_EMAIL): um endereço de e-mail só, que cabe em um `mailto:` sem codificação.
EMAIL = re.compile(r'[A-Za-z0-9._+-]{1,64}@(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,24}')
DONO_DADOS = 'ftpdata'      # usuário do sistema dono das pastas e dos arquivos do FTP
PRIVADAS = [ipaddress.ip_network(r) for r in ('127.0.0.0/8', '10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16')]

CORPO_MAX = 8192            # bytes de um envio de formulário
TEMPO_CONEXAO = 15          # segundos por conexão
CONEXOES_MAX = 32
DOWNLOADS_MAX = 8           # arquivos entregues ao mesmo tempo; o resto das conexões fica para as telas
BLOCO_ARQUIVO = 64 * 1024   # bytes lidos e enviados por vez em um download
LISTA_MAX = 2000            # itens mostrados por pasta na aba Arquivos
APAGAR_MAX = 50000          # itens apagados por pedido na aba Arquivos; pasta maior é apagada em mais de um pedido
APAGAR_PRAZO = 20           # segundos por pedido de apagar: abaixo do tempo que o nginx espera pelo painel
APAGAR_NIVEIS = 64          # pastas uma dentro da outra que o painel desce para apagar
FALHAS_MAX = 5              # falhas de entrada por IP...
JANELA_FALHAS = 15 * 60     # ...nesta janela, em segundos
SESSAO_ABSOLUTA = 8 * 3600
SESSOES_MAX = 50
SESSOES_POR_USUARIO = 3     # sessões de um mesmo usuário do FTP; a mais antiga sai quando entra a quarta
DOWNLOADS_POR_USUARIO = 2   # arquivos que um usuário do FTP baixa ao mesmo tempo, quando ele não tem limite próprio
CONFERENCIAS_FTP = 2        # senhas conferidas no servidor FTP ao mesmo tempo (ele limita as conexões por IP)
ESPERA_FTP = 5              # segundos de espera pela vez de conferir
TEMPO_FTP = 15              # segundos por etapa da conferência: o servidor FTP leva de 3 a 6 s a mais para recusar uma senha
ADMINS_MAX = 20
VALIDADE_FORMULARIO = 15 * 60
VALIDADE_CONTATO = 90       # dias de validade (Expires) do security.txt, contados do pedido
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
    # Painel publicado por proxy ou túnel: os endereços de onde o nginx aceita o endereço do cliente.
    proxies = []
    for texto in filter(None, (t.strip() for t in amb('PAINEL_PROXY_CONFIAVEL', '').split(','))):
        try:
            proxy = ipaddress.ip_address(texto)
        except ValueError:
            falha(f'PAINEL_PROXY_CONFIAVEL: "{texto}" não é um endereço IPv4 (um a um, sem máscara)')
        if proxy.version != 4 or not (privado(proxy) or (publico and 1 <= int(proxy) >> 24 <= 223)):
            falha(f'PAINEL_PROXY_CONFIAVEL: {proxy} não é IP privado. Endereço público só com REDE_PERMITIR_IP_PUBLICO=sim.')
        if not any(proxy in rede for rede in redes):
            falha(f'PAINEL_PROXY_CONFIAVEL: {proxy} está fora de PAINEL_REDES_PERMITIDAS: o nginx recusaria o proxy antes do painel')
        proxies.append(proxy)
    if len(proxies) > 8:
        falha('PAINEL_PROXY_CONFIAVEL aceita até 8 endereços')
    admin = amb('PAINEL_ADMIN_USER', 'admin')
    if not NOME.fullmatch(admin):
        falha('PAINEL_ADMIN_USER inválido: letras minúsculas, números, _ e -; começa com letra ou _; até 32 caracteres')
    if amb('PAINEL_ACESSO_USUARIOS_FTP', 'sim') not in ('nao', 'sim'):
        falha("PAINEL_ACESSO_USUARIOS_FTP deve ser 'sim' ou 'nao'")
    if amb('FTP_TLS_EXCECOES', 'sim') not in ('nao', 'sim'):
        falha("FTP_TLS_EXCECOES deve ser 'nao' ou 'sim'")
    if amb('PAINEL_AVISO_EXPOSICAO', 'sim') not in ('nao', 'sim'):
        falha("PAINEL_AVISO_EXPOSICAO deve ser 'sim' ou 'nao'")
    # O TLS por usuário só vale sobre o modo 2 e sem IP público aceito; fora disso a opção fica sem efeito,
    # como no serviço ftp, e o painel diz o motivo no lugar dos botões.
    if amb('FTP_TLS_EXCECOES', 'sim') == 'nao':
        sem_excecao = 'a opção está desligada (<code>FTP_TLS_EXCECOES=nao</code>)'
    elif amb('FTP_TLS_MODE', '2') != '2':
        sem_excecao = 'ela só vale com <code>FTP_TLS_MODE=2</code>, e o FTP está em outro modo'
    elif publico:
        sem_excecao = 'ela não vale com <code>REDE_PERMITIR_IP_PUBLICO=sim</code>: FTP sem TLS na internet entrega a senha a quem escuta'
    else:
        sem_excecao = ''
    contato = amb('SEGURANCA_CONTATO_EMAIL', '')
    if contato and not (len(contato) <= 254 and EMAIL.fullmatch(contato)):
        falha('SEGURANCA_CONTATO_EMAIL inválido: um endereço de e-mail só, como seguranca@exemplo.com.br, ou vazio')
    clientes = amb('FTP_MAX_CLIENTS', '50')
    if not re.fullmatch(r'[1-9][0-9]{0,4}', clientes):
        falha('FTP_MAX_CLIENTS deve ser um inteiro maior que zero')
    tentativas = amb('FTP_BLOQUEIO_TENTATIVAS', '5')
    if not (re.fullmatch(r'0|[1-9][0-9]{0,2}', tentativas) and int(tentativas) <= 100):
        falha('FTP_BLOQUEIO_TENTATIVAS deve ficar entre 0 e 100 (0 desliga o bloqueio por tentativa)')
    bloqueio = amb('FTP_BLOQUEIO_MINUTOS', '15')
    if not (re.fullmatch(r'[1-9][0-9]{0,3}', bloqueio) and int(bloqueio) <= 1440):
        falha('FTP_BLOQUEIO_MINUTOS deve ficar entre 1 e 1440')
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
        'proxies': proxies,
        'aviso_exposicao': amb('PAINEL_AVISO_EXPOSICAO', 'sim') == 'sim',
        'admin_inicial': admin,
        'acesso_usuarios': amb('PAINEL_ACESSO_USUARIOS_FTP', 'sim') == 'sim',
        'inatividade': int(minutos) * 60,
        'cert_cn': amb('PAINEL_CERT_CN', '').strip().lower(),
        'contato_seguranca': contato,
        'painel_bind': amb('PAINEL_BIND_IP', '127.0.0.1'),
        'painel_porta': amb('PAINEL_PORT', '8443'),
        'ftp_host': amb('PAINEL_FTP_HOST', 'ftp'),
        'ftp_usuario': amb('FTP_USER', 'transfer'),
        'ftp_bind': amb('FTP_BIND_IP', '127.0.0.1'),
        'ftp_porta': amb('FTP_PORT', '21'),
        'ftp_anunciado': amb('FTP_PASSIVE_IP', '127.0.0.1'),
        'ftp_tls': amb('FTP_TLS_MODE', '2'),
        'ftp_clientes': clientes,
        'tls_excecoes': not sem_excecao,
        'tls_sem_excecao': sem_excecao,
        'bloqueio_tentativas': int(tentativas),
        'bloqueio_minutos': int(bloqueio),
        'ftp_passiva': f"{amb('FTP_PASSIVE_PORT_START', '30000')}–{amb('FTP_PASSIVE_PORT_END', '30049')}",
        'pasta_host': amb('PAINEL_PASTA_DADOS', 'DATA_DIR/dados').rstrip('/'),
        'versao': versao,
    }


# Preenchido uma vez, na subida do servidor; os outros módulos só leem.
CFG = {}
