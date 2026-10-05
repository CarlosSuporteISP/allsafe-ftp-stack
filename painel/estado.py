# SPDX-License-Identifier: Apache-2.0
"""Leitura do estado da stack (usuários, pastas, FTP, certificados) e o comando que altera usuários."""
import datetime
import os
import re
import socket
import stat
import subprocess
import threading
import time

from config import ARQ_SEM_TLS, ARQ_USUARIOS, CFG, CMD_USUARIO, NIVEL, NOME, PASTA_DADOS

TRAVA_CACHE = threading.Lock()
CACHE = {}
# Memória por conferência de senha (m=, em KiB), no começo do campo da senha do cadastro do FTP.
CUSTO = re.compile(r'\$argon2id\$v=\d+\$m=(\d+),t=\d+,p=\d+\$')


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


def pasta_do_cadastro(casa):
    """Pasta do usuário como está no cadastro (/data/<pasta>/./), relativa à pasta dos dados.
    Devolve None se o cadastro aponta para a própria pasta dos dados ou para fora dela."""
    casa = casa.removesuffix('/./').rstrip('/')
    if not casa.startswith(PASTA_DADOS + '/'):
        return None
    pasta = casa[len(PASTA_DADOS) + 1:]
    if any(parte in ('', '.', '..') for parte in pasta.split('/')):
        return None
    return pasta


def usuarios():
    """Nome ➜ pasta de cada usuário, em ordem de nome. O hash da senha, que está no mesmo arquivo, nunca sai daqui."""
    cadastro = {}
    try:
        with open(ARQ_USUARIOS, encoding='utf-8', errors='replace') as arq:
            for linha in arq:
                campos = linha.rstrip('\n').split(':')
                if len(campos) > 5 and NOME.fullmatch(campos[0]):
                    cadastro[campos[0]] = pasta_do_cadastro(campos[5])
    except OSError:
        pass
    return dict(sorted(cadastro.items()))


def senhas_de_custo_antigo():
    """Usuários com a senha gravada com mais memória por conferência do que o porte atual prevê: cada tentativa
    de entrada com o nome deles ocupa mais o processador do FTP. A referência é o usuário inicial, que o serviço
    ftp regrava a cada subida. Do campo da senha só sai o número da memória; o hash nunca sai daqui.
    Devolve None quando o usuário inicial não está no cadastro."""
    memoria = {}
    try:
        with open(ARQ_USUARIOS, encoding='utf-8', errors='replace') as arq:
            for linha in arq:
                campos = linha.rstrip('\n').split(':')
                if len(campos) > 5 and NOME.fullmatch(campos[0]):
                    custo = CUSTO.match(campos[1])
                    memoria[campos[0]] = int(custo.group(1)) if custo else None
    except OSError:
        pass
    atual = memoria.get(CFG['ftp_usuario'])
    if not atual:
        return None
    return sorted(nome for nome, dele in memoria.items() if dele is None or dele > atual)


def sem_tls(cadastro=None):
    """Usuários que o administrador dispensou do TLS, em ordem de nome. Só conta quem está no cadastro."""
    cadastro = usuarios() if cadastro is None else cadastro
    marcados = set()
    try:
        with open(ARQ_SEM_TLS, encoding='utf-8', errors='replace') as arq:
            for linha in arq:
                nome = linha.rstrip('\n')
                if NOME.fullmatch(nome) and nome in cadastro:
                    marcados.add(nome)
    except OSError:
        pass
    return sorted(marcados)


def vizinhos(cadastro, nome):
    """Outros usuários que alcançam a pasta deste: quem tem a mesma, uma acima ou uma abaixo dela."""
    pasta = cadastro.get(nome)
    if not pasta:
        return []
    return [outro for outro, dele in cadastro.items()
            if outro != nome and dele and (dele == pasta or dele.startswith(pasta + '/') or pasta.startswith(dele + '/'))]


def pastas_distintas(cadastro):
    """Pastas dos usuários sem repetição e sem a que fica dentro de outra, para a soma não contar duas vezes."""
    unicas = sorted({pasta for pasta in cadastro.values() if pasta})
    return [pasta for pasta in unicas if not any(pasta.startswith(outra + '/') for outra in unicas)]


def impedimento_da_pasta(pasta):
    """Confere, nível por nível, se a pasta pode ser a de um usuário. Devolve '' ou o motivo da recusa.
    Quem decide é o allsafe-ftp-user, com a mesma conferência; esta antecipa a resposta na tela."""
    atual = PASTA_DADOS
    for nivel in pasta.split('/'):
        atual = os.path.join(atual, nivel)
        try:
            modo = os.lstat(atual).st_mode
        except FileNotFoundError:
            return ''
        except OSError:
            return 'Não foi possível conferir a pasta.'
        if stat.S_ISLNK(modo):
            return 'A pasta passa por um link simbólico, que não é aceito.'
        if not stat.S_ISDIR(modo):
            return 'Já existe um arquivo com este nome no caminho da pasta.'
    return ''


def pastas_do_primeiro_nivel(limite=200):
    """Pastas que já existem logo abaixo da pasta dos dados, para sugerir no formulário de usuário novo."""
    nomes = []
    try:
        with os.scandir(PASTA_DADOS) as itens:
            for item in itens:
                if NIVEL.fullmatch(item.name) and item.is_dir(follow_symlinks=False):
                    nomes.append(item.name)
                    if len(nomes) >= limite:
                        break
    except OSError:
        pass
    return sorted(nomes)


def uso_da_pasta(pasta):
    """Tamanho, quantidade e data do arquivo mais novo de /data/<pasta>, com limite de tempo e de itens."""
    def medir():
        total = arquivos = 0
        ultimo = 0.0
        parcial = False
        prazo = time.monotonic() + 2
        pilha = [os.path.join(PASTA_DADOS, pasta)] if pasta else []
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
    return com_cache(('uso', pasta), 60, medir)


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


def executar_usuario(acao, nome, senha=None, pasta=None):
    """Chama o allsafe-ftp-user, o mesmo do serviço ftp. A senha vai pela entrada padrão.
    O FTP_MAX_CLIENTS vai junto: é dele que sai o custo do hash da senha, o mesmo do serviço ftp."""
    try:
        resultado = subprocess.run(
            [CMD_USUARIO, acao, nome] + ([pasta] if pasta else []), input=None if senha is None else senha + '\n',
            capture_output=True, text=True, timeout=30,
            env={'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin', 'LC_ALL': 'C',
                 'FTP_MAX_CLIENTS': CFG['ftp_clientes']})
    except (OSError, subprocess.SubprocessError):
        return False, 'O comando de usuários não respondeu.'
    limpar_cache()
    if resultado.returncode != 0:
        ultima = (resultado.stderr.strip().splitlines() or ['erro sem mensagem'])[-1]
        return False, ultima[:200]
    return True, ''
