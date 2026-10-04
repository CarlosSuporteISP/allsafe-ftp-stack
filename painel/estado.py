"""Leitura do estado da stack (usuários, pastas, FTP, certificados) e o comando que altera usuários."""
import datetime
import os
import socket
import subprocess
import threading
import time

from config import ARQ_USUARIOS, CFG, CMD_USUARIO, NOME, PASTA_DADOS

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
