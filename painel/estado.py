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

from config import ARQ_SEM_TLS, ARQ_USUARIOS, CFG, CMD_USUARIO, NIVEL, NOME, PASTA, PASTA_BLOQUEIOS, PASTA_DADOS
from idioma import N, t

TRAVA_CACHE = threading.Lock()
CACHE = {}
# Memória por conferência de senha (m=, em KiB), no começo do campo da senha do cadastro do FTP.
CUSTO = re.compile(r'\$argon2id\$v=\d+\$m=(\d+),t=\d+,p=\d+\$')
# Endereço de origem no nome do arquivo de um bloqueio: o mesmo formato que o vigia e o porteiro do ftp aceitam.
ORIGEM = re.compile(r'[0-9a-fA-F.:]{2,45}')
DIAS_DO_GRAFICO = 14        # dias do gráfico de arquivos recebidos, na Visão geral
BLOQUEIOS_LIDOS = 5000      # arquivos de bloqueio lidos por tela; o vigia guarda no máximo 4096


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


UID_DO_PERFIL = {'10002': 'envio', '10003': 'leitura', '10004': 'soenvio'}   # os demais são do perfil completo (ftpdata, 10000)
UID_SOENVIO = '10004'


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


def pasta_da_linha(campos):
    """Pasta do usuário pela linha dele no cadastro. No perfil só envio a pasta da sessão do FTP (campo 6) é a área
    de entrada, de onde o servidor move o que chega, e a pasta do usuário está na descrição (campo 5)."""
    if campos[2] == UID_SOENVIO:
        return campos[4] if PASTA.fullmatch(campos[4]) else None
    return pasta_do_cadastro(campos[5])


def usuarios():
    """Nome ➜ pasta de cada usuário, em ordem de nome. O hash da senha, que está no mesmo arquivo, nunca sai daqui."""
    cadastro = {}
    try:
        with open(ARQ_USUARIOS, encoding='utf-8', errors='replace') as arq:
            for linha in arq:
                campos = linha.rstrip('\n').split(':')
                if len(campos) > 5 and NOME.fullmatch(campos[0]):
                    cadastro[campos[0]] = pasta_da_linha(campos)
    except OSError:
        pass
    return dict(sorted(cadastro.items()))


def perfis():
    """Nome ➜ perfil de cada usuário: completo, envio, soenvio ou leitura. O perfil é a identidade de sistema gravada no
    cadastro (campo 3), a mesma que o allsafe-ftp-user grava: quem aplica o limite é o sistema de arquivos."""
    cadastro = {}
    try:
        with open(ARQ_USUARIOS, encoding='utf-8', errors='replace') as arq:
            for linha in arq:
                campos = linha.rstrip('\n').split(':')
                if len(campos) > 5 and NOME.fullmatch(campos[0]):
                    cadastro[campos[0]] = UID_DO_PERFIL.get(campos[2], 'completo')
    except OSError:
        pass
    return cadastro


def senhas_de_custo_antigo():
    """Usuários com a senha gravada com mais memória por conferência do que o porte atual prevê: cada tentativa
    de entrada com o nome deles ocupa mais o processador do FTP. A referência é a conta do pure-pw para o
    FTP_MAX_CLIENTS em vigor: 65536 KiB divididos pelos logins ao mesmo tempo, com piso de 8 KiB.
    Do campo da senha só sai o número da memória; o hash nunca sai daqui."""
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
    atual = max(8, 65536 // int(CFG['ftp_clientes']))
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


def bloqueios():
    """Bloqueios por tentativa em vigor no FTP: usuário ➜ lista de (origem, vale até, desde, senhas erradas),
    do mais recente para o mais antigo. Cada arquivo é `<usuário>@<origem>`, com os três números na primeira
    linha; quem grava é o vigia do serviço ftp e quem tira é o allsafe-ftp-user."""
    achados = {}
    agora = time.time()
    try:
        itens = sorted(os.listdir(PASTA_BLOQUEIOS))[:BLOQUEIOS_LIDOS]
    except OSError:
        return achados
    for item in itens:
        nome, arroba, origem = item.partition('@')
        if not (arroba and NOME.fullmatch(nome) and ORIGEM.fullmatch(origem)):
            continue
        caminho = os.path.join(PASTA_BLOQUEIOS, item)
        try:
            if os.path.islink(caminho):
                continue
            with open(caminho, encoding='ascii', errors='replace') as arq:
                campos = arq.readline(64).split()
        except OSError:
            continue
        if len(campos) < 3 or not all(campo.isascii() and campo.isdigit() and len(campo) <= 12 for campo in campos[:3]):
            continue
        expira, desde, erradas = (int(campo) for campo in campos[:3])
        if expira > agora:
            achados.setdefault(nome, []).append((origem, expira, desde, erradas))
    for lista in achados.values():
        lista.sort(key=lambda bloqueio: -bloqueio[2])
    return achados


def vizinhos(cadastro, nome):
    """Outros usuários que alcançam a pasta deste: quem tem a mesma, uma acima ou uma abaixo dela."""
    pasta = cadastro.get(nome)
    if not pasta:
        return []
    return [outro for outro, dele in cadastro.items()
            if outro != nome and dele and (dele == pasta or dele.startswith(pasta + '/') or pasta.startswith(dele + '/'))]


def pastas_acima(pasta):
    """Pastas que contêm esta: de 'a/b/c', 'a' e 'a/b'."""
    return [pasta[:corte] for corte, letra in enumerate(pasta) if letra == '/' and corte]


def vizinhos_de_todos(cadastro):
    """O mesmo que vizinhos(), para o cadastro inteiro em uma passada: usuário ➜ quem alcança a pasta dele.
    É o que a lista de usuários usa: chamar vizinhos() em cada linha compara todos com todos."""
    donos = {}
    for nome, pasta in cadastro.items():
        if pasta:
            donos.setdefault(pasta, []).append(nome)
    achados = {nome: [] for nome in cadastro}
    for pasta, nomes in donos.items():
        de_cima = [outro for acima in pastas_acima(pasta) for outro in donos.get(acima, ())]
        for nome in nomes:
            achados[nome] += [outro for outro in nomes if outro != nome] + de_cima
        for outro in de_cima:
            achados[outro] += nomes
    ordem = {nome: posicao for posicao, nome in enumerate(cadastro)}
    return {nome: sorted(outros, key=ordem.__getitem__) for nome, outros in achados.items()}


def pastas_distintas(cadastro):
    """Pastas dos usuários sem repetição e sem a que fica dentro de outra, para a soma não contar duas vezes."""
    unicas = {pasta for pasta in cadastro.values() if pasta}
    return sorted(pasta for pasta in unicas if not any(acima in unicas for acima in pastas_acima(pasta)))


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
            return t('Não foi possível conferir a pasta.')
        if stat.S_ISLNK(modo):
            return t('A pasta passa por um link simbólico, que não é aceito.')
        if not stat.S_ISDIR(modo):
            return t('Já existe um arquivo com este nome no caminho da pasta.')
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


def uso_da_pasta(pasta, validade=60):
    """Tamanho, quantidade e data do arquivo mais novo de /data/<pasta>, com limite de tempo e de itens.
    `dias` conta os arquivos pela data de cada um: hoje, ontem e assim até DIAS_DO_GRAFICO - 1 dias atrás.
    A medida vale por `validade` segundos; a tela que confirma um apagamento pede a de agora (0)."""
    def medir():
        total = arquivos = 0
        ultimo = 0.0
        parcial = False
        dias = [0] * DIAS_DO_GRAFICO
        fim_de_hoje = time.mktime(time.localtime()[:3] + (0, 0, 0, 0, 0, -1)) + 86400
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
                                atras = int((fim_de_hoje - dados.st_mtime) // 86400)
                                if 0 <= atras < DIAS_DO_GRAFICO:
                                    dias[atras] += 1
                        except OSError:
                            continue
                        if arquivos >= 50000 or time.monotonic() > prazo:
                            parcial = True
                            pilha.clear()
                            break
            except OSError:
                continue
        return {'bytes': total, 'arquivos': arquivos, 'ultimo': ultimo, 'parcial': parcial, 'dias': dias}
    return com_cache(('uso', pasta), validade, medir)


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


def executar_usuario(acao, nome, senha=None, pasta=None, pares=()):
    """Chama o allsafe-ftp-user, o mesmo do serviço ftp. A senha vai pela entrada padrão.
    O FTP_MAX_CLIENTS vai junto: é dele que sai o custo do hash da senha, o mesmo do serviço ftp.
    O FTP_USER também: a troca da senha do usuário inicial deixa a marca que a partida do ftp respeita.
    `pares` são os limites do usuário, um `chave=valor` por argumento."""
    try:
        resultado = subprocess.run(
            [CMD_USUARIO, acao, nome] + ([pasta] if pasta else []) + list(pares), input=None if senha is None else senha + '\n',
            capture_output=True, text=True, timeout=30,
            env={'PATH': '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin', 'LC_ALL': 'C',
                 'FTP_MAX_CLIENTS': CFG['ftp_clientes'], 'FTP_USER': CFG['ftp_usuario']})
    except (OSError, subprocess.SubprocessError):
        return False, N('O comando de usuários não respondeu.')
    limpar_cache()
    if resultado.returncode != 0:
        ultima = (resultado.stderr.strip().splitlines() or [N('erro sem mensagem')])[-1]
        return False, ultima[:200]
    return True, ''
