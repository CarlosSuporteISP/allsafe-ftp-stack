# SPDX-License-Identifier: Apache-2.0
"""Envio de arquivo pelo rclone, para o que o S3 não cobre: servidores de arquivos (SFTP, WebDAV, FTP com TLS), nuvens
de arquivos, armazenamento de objetos que não fala S3 e serviços de transferência para empresas.

O painel só envia. Do rclone saem dois subcomandos, e nenhum outro: `rcat`, que grava no remoto o que recebe pela
entrada padrão, e `obscure`, que cifra a senha para o arquivo de configuração. Copiar de volta, listar, mover,
sincronizar e apagar não estão em SUBCOMANDOS, e por isso não saem do painel por nenhum caminho: tela, rotina ou
terminal. O binário é o da imagem, com versão e soma fixas na construção; nada é baixado nem atualizado em execução.

A configuração do remoto é um segredo do destino, no formato do próprio rclone, e é montada aqui a partir de uma lista
fechada: os tipos de CAMPOS, os campos de cada um e a forma de cada valor. O que o rclone tem de perigoso para quem
escreve a configuração (comando a executar, arquivo a ler, proxy, certificado sem conferência, remoto que embrulha
outro, pasta local, endereço sem TLS) não está na lista e não entra. O arquivo é conferido de novo a cada leitura,
pela mesma lista: o que não é exatamente o que o painel gravaria é recusado.

O rclone nunca mexe no segredo: trabalha em uma cópia, em /tmp/rclone, apagada depois de cada execução. Da cópia o
painel só aproveita o que o rclone tem motivo para mudar: o token renovado das nuvens e, no teste do SFTP, a chave do
servidor. O SFTP só envia para servidor de chave conhecida: sem ela gravada, o envio é recusado antes de sair, e é o
teste pedido pelo administrador que a fixa. Chave que muda depois disso é recusada pelo rclone.

Um rclone por vez, com memória e processadores limitados pelo ambiente. A saída de erro dele serve só para escolher o
motivo, em uma palavra: o texto pode trazer endereço, usuário e caminho do remoto e não vai para tela nem registro.
"""
import base64
import contextlib
import fcntl
import hashlib
import ipaddress
import json
import os
import re
import socket
import subprocess
import threading
import time

import saida
from config import PASTA_DESTINOS

BINARIO = '/usr/local/bin/rclone'
SUBCOMANDOS = ('rcat', 'obscure')    # tudo o que o painel pede ao rclone
PASTA_TRABALHO = '/tmp/rclone'       # a cópia da configuração e o que o rclone guarda enquanto roda
ARQ_TRAVA = os.path.join(PASTA_DESTINOS, '.rclone')
SECAO = 'destino'                    # o nome do remoto dentro do arquivo: sempre o mesmo
SEGREDO_MAX = 16384                  # bytes do arquivo de configuração de um remoto
ERRO_MAX = 65536                     # bytes guardados da saída de erro, para escolher o motivo
ALVO_MAX = 1024                      # bytes do caminho de um arquivo no remoto
PEM_MAX = 8000                       # caracteres de uma chave privada
JSON_MAX = 6000                      # caracteres de um token ou de uma credencial de conta de serviço
URIS_DO_TOKEN = ('https://oauth2.googleapis.com/token', 'https://accounts.google.com/o/oauth2/token')
ARQ_TESTE = 'allsafe-ftp-stack-teste.txt'
TESTE_TOTAL = 20                     # segundos do teste inteiro: depois disso o rclone é encerrado
TENTATIVAS = 3                       # vezes que o rclone repete uma operação de rede dentro de um envio
AMBIENTE = {'PATH': '/usr/local/bin:/usr/bin:/bin', 'HOME': PASTA_TRABALHO, 'TMPDIR': PASTA_TRABALHO,
            'XDG_CACHE_HOME': PASTA_TRABALHO + '/cache', 'XDG_CONFIG_HOME': PASTA_TRABALHO + '/config',
            'GOMAXPROCS': '2', 'GOMEMLIMIT': '64MiB'}

NOME_DE_REDE = r'[A-Za-z0-9](?:[A-Za-z0-9.-]{0,251}[A-Za-z0-9])?'
HOST = re.compile(NOME_DE_REDE + r'|[0-9A-Fa-f:]{3,39}')
NOME = re.compile(NOME_DE_REDE)
# O servidor e a pasta de partida, sem `..`.
NOME_E_PASTA = re.compile(NOME_DE_REDE + r'(?:/[A-Za-z0-9][A-Za-z0-9._-]{0,63}){0,8}')
USUARIO = re.compile(r'[A-Za-z0-9_][A-Za-z0-9._@+-]{0,127}')
URL = re.compile(r'https://(' + NOME_DE_REDE + r')(?::([0-9]{1,5}))?'
                 r'((?:/(?:[A-Za-z0-9._~@+-]|%[0-9A-Fa-f]{2}){1,128}){0,12}/?)')
# O endereço com assinatura: o mesmo começo de URL, e a assinatura depois da interrogação.
URL_SAS = re.compile(r'https://(' + NOME_DE_REDE + r')(?::([0-9]{1,5}))?(?:/[A-Za-z0-9._~-]{1,128}){0,4}/?'
                     r'\?[A-Za-z0-9%&=._~:+/-]{8,2048}')
PORTADOR = re.compile(r'[A-Za-z0-9._~+/=-]{8,4096}')
CHAVE = re.compile(r'[\x21-\x7e]{1,256}')            # senha ou chave que o serviço guarda em texto, sem espaço
CLIENTE = re.compile(r'[A-Za-z0-9][A-Za-z0-9._-]{0,127}')
SEGREDO_DO_CLIENTE = re.compile(r'[A-Za-z0-9._~-]{1,128}')
IDENTIFICACAO = re.compile(r'[A-Za-z0-9][A-Za-z0-9!_-]{0,127}')
INQUILINO = re.compile(r'[A-Za-z0-9](?:[A-Za-z0-9.-]{0,62}[A-Za-z0-9])?')
SENHA = re.compile(r'[^\x00-\x1f\x7f]{1,256}')
CIFRADA = re.compile(r'[A-Za-z0-9_-]{22,1024}')      # o que o `obscure` devolve
ALGORITMO = re.compile(r'(?:ssh|ecdsa|sk|rsa)-[a-z0-9@.-]{2,60}')
CORPO_DA_CHAVE = re.compile(r'[A-Za-z0-9+/]{32,2048}={0,2}')
CHAVES_MAX = 8                       # chaves de servidor de um remoto SFTP
PEM = re.compile(r'-----BEGIN ((?:[A-Z0-9]{1,12} ){0,2})PRIVATE KEY-----\n'
                 r'(?:(?:[A-Za-z-]{1,32}: [A-Za-z0-9 ,-]{1,128}\n){1,4}\n)?'
                 r'(?:[A-Za-z0-9+/]{1,76}={0,2}\n){1,128}'
                 r'-----END \1PRIVATE KEY-----')
# A pasta dentro do remoto. No SFTP pode começar pela barra (caminho inteiro no servidor); sem ela, parte da pasta
# em que o usuário entra.
PARTE = r'[A-Za-z0-9_](?:[A-Za-z0-9._ -]{0,62}[A-Za-z0-9._-])?'
CAMINHO = re.compile(r'/?' + PARTE + r'(?:/' + PARTE + r'){0,15}')
ROTULO = re.compile(PARTE)           # nome que o serviço deixa ter espaço: biblioteca, projeto, domínio
CAMINHO_MAX = 255
VALOR = re.compile(r'[\x21-\x7e](?:[\x20-\x7e]*[\x21-\x7e])?')   # qualquer valor gravado: uma linha de ASCII visível
DESTINO = re.compile(r'[a-z0-9-]{1,32}')

# Os tipos de remoto e os campos de cada um, na ordem em que são gravados: (nome, forma, regra, marcas). Formas:
# texto (expressão), porta, escolha (lista), senha (cifrada pelo `obscure`), pem (chave privada, em uma linha), json
# ('token' ou 'conta') e chaves (as do servidor SFTP). Marcas: `o` obrigatório; `l` faz parte do lugar para onde o
# destino envia; `r` nomeia um servidor, conferido antes de cada conexão (conferir_rede); `s` é segredo em texto, que
# a tela mostra como senha. Nenhum valor volta para a tela.
APLICATIVO = (('client_id', 'texto', CLIENTE, ''), ('client_secret', 'texto', SEGREDO_DO_CLIENTE, 's'))
COM_TOKEN = APLICATIVO + (('token', 'json', 'token', 'o'),)
CAMPOS = {
    'sftp': (
        ('host', 'texto', HOST, 'olr'),
        ('port', 'porta', None, 'l'),
        ('user', 'texto', USUARIO, 'ol'),
        ('pass', 'senha', None, ''),
        ('key_pem', 'pem', None, ''),
        ('key_file_pass', 'senha', None, ''),
        ('host_keys', 'chaves', None, ''),
    ),
    'webdav': (
        ('url', 'texto', URL, 'olr'),
        ('vendor', 'escolha', ('other', 'nextcloud', 'owncloud', 'infinitescale', 'sharepoint', 'sharepoint-ntlm',
                               'fastmail', 'rclone'), ''),
        ('user', 'texto', USUARIO, 'l'),
        ('pass', 'senha', None, ''),
        ('bearer_token', 'texto', PORTADOR, 's'),
    ),
    'ftp': (
        ('host', 'texto', HOST, 'olr'),
        ('port', 'porta', None, 'l'),
        ('user', 'texto', USUARIO, 'ol'),
        ('pass', 'senha', None, 'o'),
        ('explicit_tls', 'escolha', ('true', 'false'), 'o'),
    ),
    'seafile': (
        ('url', 'texto', URL, 'olr'),
        ('user', 'texto', USUARIO, 'ol'),
        ('pass', 'senha', None, ''),
        ('auth_token', 'texto', PORTADOR, 's'),
        ('library', 'texto', ROTULO, 'ol'),
        ('library_key', 'senha', None, ''),
    ),
    'drive': APLICATIVO + (
        ('scope', 'escolha', ('drive', 'drive.file'), ''),
        ('token', 'json', 'token', ''),
        ('service_account_credentials', 'json', 'conta', ''),
        ('root_folder_id', 'texto', IDENTIFICACAO, 'l'),
        ('team_drive', 'texto', IDENTIFICACAO, 'l'),
    ),
    'onedrive': COM_TOKEN + (
        ('drive_id', 'texto', IDENTIFICACAO, 'ol'),
        ('drive_type', 'escolha', ('personal', 'business', 'documentLibrary'), 'o'),
        ('region', 'escolha', ('global', 'us', 'de', 'cn'), ''),
        ('tenant', 'texto', INQUILINO, ''),
    ),
    'dropbox': COM_TOKEN,
    'pcloud': COM_TOKEN + (
        ('hostname', 'escolha', ('api.pcloud.com', 'eapi.pcloud.com'), 'l'),
    ),
    'box': COM_TOKEN + (
        ('box_sub_type', 'escolha', ('user', 'enterprise'), ''),
    ),
    'mega': (
        ('user', 'texto', USUARIO, 'ol'),
        ('pass', 'senha', None, 'o'),
    ),
    'protondrive': (
        ('username', 'texto', USUARIO, 'ol'),
        ('password', 'senha', None, 'o'),
        ('mailbox_password', 'senha', None, ''),
    ),
    'koofr': (
        ('provider', 'escolha', ('koofr', 'digistorage', 'other'), 'ol'),
        ('endpoint', 'texto', URL, 'lr'),
        ('user', 'texto', USUARIO, 'ol'),
        ('password', 'senha', None, 'o'),
    ),
    'yandex': COM_TOKEN,
    'mailru': (
        ('user', 'texto', USUARIO, 'ol'),
        ('pass', 'senha', None, 'o'),
    ),
    'hidrive': COM_TOKEN,
    'huaweidrive': COM_TOKEN,
    'zoho': COM_TOKEN + (
        ('region', 'escolha', ('com', 'eu', 'in', 'jp', 'com.cn', 'com.au'), 'ol'),
    ),
    'putio': COM_TOKEN,
    'premiumizeme': (
        ('api_key', 'texto', PORTADOR, 'os'),
    ),
    'opendrive': (
        ('username', 'texto', USUARIO, 'ol'),
        ('password', 'senha', None, 'o'),
    ),
    'filen': (
        ('email', 'texto', USUARIO, 'ol'),
        ('password', 'senha', None, 'o'),
        ('api_key', 'senha', None, 'o'),
    ),
    'fichier': (
        ('api_key', 'texto', PORTADOR, 'os'),
    ),
    'filelu': (
        ('key', 'texto', PORTADOR, 'os'),
    ),
    'gofile': (
        ('access_token', 'texto', PORTADOR, 'os'),
    ),
    'pixeldrain': (
        ('api_key', 'texto', PORTADOR, 'os'),
        ('root_folder_id', 'texto', IDENTIFICACAO, 'l'),
    ),
    'drime': (
        ('access_token', 'texto', PORTADOR, 'os'),
    ),
    'linkbox': (
        ('token', 'texto', PORTADOR, 'os'),
        ('email', 'texto', USUARIO, 'ol'),
        ('password', 'senha', None, 'o'),
    ),
    'ulozto': (
        ('app_token', 'texto', PORTADOR, 'os'),
        ('username', 'texto', USUARIO, 'ol'),
        ('password', 'senha', None, 'o'),
    ),
    'shade': (
        ('drive_id', 'texto', IDENTIFICACAO, 'ol'),
        ('api_key', 'texto', PORTADOR, 'os'),
    ),
    'azureblob': (
        ('account', 'texto', CLIENTE, 'l'),
        ('key', 'texto', PORTADOR, 's'),
        ('sas_url', 'texto', URL_SAS, 'lrs'),
    ),
    'azurefiles': (
        ('account', 'texto', CLIENTE, 'l'),
        ('share_name', 'texto', CLIENTE, 'ol'),
        ('key', 'texto', PORTADOR, 's'),
        ('sas_url', 'texto', URL_SAS, 'lrs'),
    ),
    'b2': (
        ('account', 'texto', CLIENTE, 'ol'),
        ('key', 'texto', PORTADOR, 'os'),
    ),
    'gcs': APLICATIVO + (
        ('token', 'json', 'token', ''),
        ('service_account_credentials', 'json', 'conta', ''),
        ('bucket_policy_only', 'escolha', ('true', 'false'), ''),
    ),
    'swift': (
        ('auth', 'texto', URL, 'olr'),
        ('auth_version', 'escolha', ('1', '2', '3'), ''),
        ('user', 'texto', USUARIO, 'ol'),
        ('key', 'texto', CHAVE, 'os'),
        ('domain', 'texto', ROTULO, ''),
        ('tenant', 'texto', ROTULO, 'l'),
        ('tenant_domain', 'texto', ROTULO, ''),
        ('region', 'texto', ROTULO, 'l'),
    ),
    'qingstor': (
        ('access_key_id', 'texto', CLIENTE, 'ol'),
        ('secret_access_key', 'texto', PORTADOR, 'os'),
        ('zone', 'texto', CLIENTE, 'l'),
        ('endpoint', 'texto', URL, 'lr'),
    ),
    'storj': (
        ('access_grant', 'texto', PORTADOR, 'os'),
    ),
    'netstorage': (
        ('host', 'texto', NOME_E_PASTA, 'olr'),
        ('account', 'texto', USUARIO, 'ol'),
        ('secret', 'senha', None, 'o'),
    ),
    'filescom': (
        ('site', 'texto', NOME, 'olr'),
        ('api_key', 'texto', PORTADOR, 's'),
        ('username', 'texto', USUARIO, 'l'),
        ('password', 'senha', None, ''),
    ),
    'quatrix': (
        ('host', 'texto', NOME, 'olr'),
        ('api_key', 'texto', PORTADOR, 'os'),
    ),
    'sharefile': COM_TOKEN + (
        ('endpoint', 'texto', URL, 'olr'),
        ('root_folder_id', 'escolha', ('favorites', 'allshared', 'connectors', 'top'), 'l'),
    ),
    'filefabric': (
        ('url', 'texto', URL, 'olr'),
        ('permanent_token', 'texto', PORTADOR, 'os'),
        ('root_folder_id', 'texto', IDENTIFICACAO, 'l'),
    ),
}
# Os tipos que abrem de duas formas: os campos de uma e os da outra. Vale uma só, e inteira.
FORMAS = {
    'seafile': (('pass',), ('auth_token',)),
    'azureblob': (('account', 'key'), ('sas_url',)),
    'azurefiles': (('account', 'key'), ('sas_url',)),
    'gcs': (('token',), ('service_account_credentials',)),
    'filescom': (('api_key',), ('username', 'password')),
}
# Os tipos em que a primeira pasta do caminho é o bucket (ou o contêiner): a pasta no remoto é obrigatória, para o
# nome de uma pasta dos dados nunca virar nome de bucket.
BALDES = ('azureblob', 'b2', 'gcs', 'swift', 'qingstor', 'storj')
# O que o painel escreve por conta própria em cada tipo. No SFTP o rclone não abre terminal no servidor nem pede a
# ele a soma do arquivo. Onde o envio é em pedaços, o tamanho e o número de pedaços ao mesmo tempo cabem na memória do
# painel. No Azure Blob e no Google Cloud Storage o rclone não confere nem cria o contêiner ou o bucket: só grava.
# No Mega, o padrão do rclone é transferir por HTTP sem TLS: o painel fixa o HTTPS.
EM_PEDACOS = (('chunk_size', '16Mi'), ('upload_concurrency', '1'))
FIXOS = {
    'sftp': (('shell_type', 'none'), ('disable_hashcheck', 'true')),
    'dropbox': (('chunk_size', '8Mi'),),
    'mega': (('use_https', 'true'),),
    'mailru': (('speedup_enable', 'false'),),
    'hidrive': EM_PEDACOS,
    'filelu': EM_PEDACOS[:1],
    'shade': EM_PEDACOS,
    'azureblob': (('upload_concurrency', '2'), ('no_check_container', 'true')),
    'azurefiles': (('upload_concurrency', '2'),),
    'b2': EM_PEDACOS,
    'gcs': (('no_check_bucket', 'true'),),
    'sharefile': EM_PEDACOS[:1],
}
# O texto de erro do rclone ➜ o motivo, em uma palavra. A primeira regra que casa vale.
MOTIVOS = (
    ('chave_trocada', re.compile(r'host key|host_keys|knownhosts|known_hosts')),
    ('frase', re.compile(r'passphrase|private key|decryption password')),
    ('mudou', re.compile(r'corrupted on transfer|sizes differ')),
    ('tls', re.compile(r'x509|tls:|certificate')),
    ('recusado', re.compile(r'unable to authenticate|\b401\b|\b403\b|\b530\b|permission denied|invalid_grant'
                            r'|unauthorized|forbidden|access denied')),
    ('dns', re.compile(r'no such host|server misbehaving|lookup ')),
    ('tempo', re.compile(r'i/o timeout|deadline exceeded|timed out')),
    ('conexao', re.compile(r'connection refused|no route to host|network is unreachable|connection reset|broken pipe')),
    ('cheio', re.compile(r'quota|insufficient storage|\b507\b|no space left')),
)


class Invalido(Exception):
    """O que o administrador preencheu não serve. `campo` é o nome do campo, `acesso` quando falta a senha, a chave
    ou o token com que o remoto é aberto, ou `demais` quando vieram duas formas de acesso onde cabe uma."""

    def __init__(self, campo):
        super().__init__(campo)
        self.campo = campo


# ------------------------------------------------------------ a forma de cada valor

def pem_em_linha(texto):
    """A chave privada colada ➜ uma linha, com `\\n` no lugar de cada quebra, como o rclone lê."""
    linhas = [linha.strip() for linha in texto.replace('\r', '').strip().split('\n')]
    limpo = '\n'.join(linhas)
    if len(limpo) > PEM_MAX or not PEM.fullmatch(limpo):
        raise ValueError
    return limpo.replace('\n', '\\n')


def json_em_linha(texto, especie):
    """O token de uma nuvem, ou a credencial de uma conta de serviço ➜ o mesmo objeto, em uma linha de ASCII."""
    if len(texto) > JSON_MAX:
        raise ValueError
    dados = json.loads(texto)
    if not isinstance(dados, dict) or not 1 <= len(dados) <= 16:
        raise ValueError
    for nome, valor in dados.items():
        if not re.fullmatch(r'[A-Za-z_]{1,40}', nome) or type(valor) not in (str, int, float):
            raise ValueError
    if especie == 'token':
        exigidos = ('access_token',)
    else:
        exigidos = ('private_key', 'client_email')
        # O endereço em que a conta de serviço troca a chave por um token é o do serviço, e não outro.
        if dados.get('type') != 'service_account' or dados.get('token_uri', URIS_DO_TOKEN[0]) not in URIS_DO_TOKEN:
            raise ValueError
    if not all(isinstance(dados.get(nome), str) and dados[nome] for nome in exigidos):
        raise ValueError
    return json.dumps(dados, ensure_ascii=True, separators=(',', ':'))


def chaves_em_linha(texto):
    """As chaves públicas do servidor SFTP ➜ `algoritmo chave`, separadas por vírgula. Aceita o que vem de um
    arquivo de servidores conhecidos: uma por linha, com o nome do servidor na frente e um comentário no fim."""
    pares = []
    for linha in re.split(r'[,\n]', texto):
        palavras = linha.split()
        if not palavras:
            continue
        inicio = next((posicao for posicao, palavra in enumerate(palavras) if ALGORITMO.fullmatch(palavra)), None)
        if inicio is None or inicio > 1 or inicio + 1 >= len(palavras) or not CORPO_DA_CHAVE.fullmatch(palavras[inicio + 1]):
            raise ValueError
        base64.b64decode(palavras[inicio + 1], validate=True)
        pares.append(f'{palavras[inicio]} {palavras[inicio + 1]}')
    if not 1 <= len(pares) <= CHAVES_MAX:
        raise ValueError
    return ','.join(pares)


def pem_cifrada(valor):
    """Se a chave privada, já em uma linha, só abre com frase."""
    linhas = valor.split('\\n')
    if 'ENCRYPTED' in linhas[0] or any(linha.startswith('Proc-Type: 4,ENCRYPTED') for linha in linhas[1:5]):
        return True
    if 'OPENSSH' not in linhas[0]:
        return False
    try:
        corpo = base64.b64decode(''.join(linhas[1:-1]), validate=True)
    except ValueError:
        return True
    # Formato do OpenSSH: a marca, e em seguida o nome da cifra, que é `none` na chave sem frase.
    marca = b'openssh-key-v1\x00'
    tamanho = int.from_bytes(corpo[len(marca):len(marca) + 4], 'big')
    return not corpo.startswith(marca) or corpo[len(marca) + 4:len(marca) + 4 + tamanho] != b'none'


def guardado(forma, regra, valor):
    """O valor como fica no arquivo, se tem a forma do campo. Levanta ValueError quando não tem."""
    if forma == 'texto':
        certo = regra.fullmatch(valor)
    elif forma == 'porta':
        certo = valor.isdigit() and str(int(valor)) == valor and 1 <= int(valor) <= 65535
    elif forma == 'escolha':
        certo = valor in regra
    elif forma == 'senha':
        certo = CIFRADA.fullmatch(valor)
    elif forma == 'pem':
        certo = pem_em_linha(valor.replace('\\n', '\n')) == valor
    elif forma == 'json':
        certo = json_em_linha(valor, regra) == valor
    else:
        certo = chaves_em_linha(valor) == valor
    # O leitor de configuração do rclone tira aspas do começo, troca %(nome)s por outro valor e emenda a linha que
    # termina em barra invertida: nada disso passa.
    if not certo or not VALOR.fullmatch(valor) or valor[0] in '"`' or '%(' in valor or valor.endswith('\\'):
        raise ValueError
    return valor


def falta(tipo, campos):
    """O nome do campo que falta ou não combina com os outros, ou '' quando o remoto está inteiro."""
    for nome, _, regra, marcas in CAMPOS[tipo]:
        if 'o' in marcas and nome not in campos:
            return nome
        if nome not in campos:
            continue
        if regra in (URL, URL_SAS) and not 1 <= int(regra.fullmatch(campos[nome]).group(2) or 443) <= 65535:
            return nome
        if regra is HOST and ':' in campos[nome]:
            try:
                ipaddress.IPv6Address(campos[nome])
            except ValueError:
                return nome
    if tipo in FORMAS:
        vindos = [[nome for nome in forma if nome in campos] for forma in FORMAS[tipo]]
        if all(vindos):
            return 'demais'
        if not any(vindos):
            return 'acesso'
        forma = FORMAS[tipo][0 if vindos[0] else 1]
        return next((nome for nome in forma if nome not in campos), '')
    if tipo == 'sftp':
        if ('key_file_pass' in campos) != ('key_pem' in campos and pem_cifrada(campos['key_pem'])):
            return 'key_file_pass'
        return '' if 'pass' in campos or 'key_pem' in campos else 'acesso'
    if tipo == 'webdav':
        if ('user' in campos) != ('pass' in campos):
            return 'pass' if 'user' in campos else 'user'
        return '' if 'pass' in campos or 'bearer_token' in campos else 'acesso'
    if tipo == 'drive':
        return '' if 'token' in campos or 'service_account_credentials' in campos else 'acesso'
    if tipo == 'koofr' and ('endpoint' in campos) != (campos['provider'] == 'other'):
        return 'endpoint'
    return ''


# ------------------------------------------------------------ o arquivo de configuração de um remoto

def do_formulario(tipo, valores):
    """O que o administrador preencheu ➜ os campos como ficam gravados, com as senhas já cifradas. Campo em branco
    fica de fora. Levanta Invalido com o nome do campo que não serve."""
    campos = {}
    for nome, forma, regra, _ in CAMPOS[tipo]:
        bruto = (valores.get(nome) or '').replace('\r\n', '\n').strip()
        if not bruto:
            continue
        try:
            if forma == 'senha':
                if not SENHA.fullmatch(bruto):
                    raise ValueError
                bruto = cifrar(bruto)
            elif forma == 'pem':
                bruto = pem_em_linha(bruto)
            elif forma == 'json':
                bruto = json_em_linha(bruto, regra)
            elif forma == 'chaves':
                bruto = chaves_em_linha(bruto)
            campos[nome] = guardado(forma, regra, bruto)
        except ValueError:
            raise Invalido(nome) from None
    faltou = falta(tipo, campos)
    if faltou:
        raise Invalido(faltou)
    if len(montar(tipo, campos)) > SEGREDO_MAX:
        raise Invalido('acesso')
    return campos


def fixos_de(tipo, campos):
    """O que o painel fixa no remoto. O FTP sai sempre com TLS: o explícito é a escolha do administrador, e quem não
    o escolheu leva o implícito."""
    if tipo == 'ftp':
        return () if campos.get('explicit_tls') == 'true' else (('tls', 'true'),)
    return FIXOS.get(tipo, ())


def montar(tipo, campos):
    """O arquivo de configuração do remoto: o tipo, os campos na ordem da lista e o que o painel fixa."""
    linhas = [f'[{SECAO}]', f'type = {tipo}']
    linhas += [f'{nome} = {campos[nome]}' for nome, _, _, _ in CAMPOS[tipo] if nome in campos]
    linhas += [f'{nome} = {valor}' for nome, valor in fixos_de(tipo, campos)]
    return '\n'.join(linhas) + '\n'


def analisar(texto):
    """O arquivo gravado ➜ (tipo, campos). Só serve o que o painel gravaria, linha por linha: tipo e campos da lista,
    cada valor na forma dele e nada além. O resto levanta saida.Falha('segredo')."""
    try:
        linhas = texto.strip('\n').split('\n')
        pares = [linha.split(' = ', 1) for linha in linhas[1:]]
        if linhas[0] != f'[{SECAO}]' or pares[0][0] != 'type' or pares[0][1] not in CAMPOS:
            raise ValueError
        tipo, campos, fixos = pares[0][1], {}, []
        formas = {nome: (forma, regra) for nome, forma, regra, _ in CAMPOS[tipo]}
        for nome, valor in pares[1:]:
            if nome in formas and nome not in campos:
                campos[nome] = guardado(*formas[nome], valor)
            else:
                fixos.append((nome, valor))
        if (tuple(fixos) != fixos_de(tipo, campos) or falta(tipo, campos)
                or montar(tipo, campos) != texto.strip('\n') + '\n'):
            raise ValueError
    except (ValueError, IndexError, KeyError, AttributeError):
        raise saida.Falha('segredo') from None
    return tipo, campos


def lugar(tipo, campos, caminho):
    """Para onde o remoto envia, sem os segredos: é o que diz se dois destinos gravam no mesmo lugar e se um destino
    regravado continua de onde estava. Do endereço com assinatura entra só o que vem antes dela."""
    return ([tipo] + [campos.get(nome, '').split('?')[0] for nome, _, _, marcas in CAMPOS[tipo] if 'l' in marcas]
            + [caminho])


def impressoes(campos):
    """A impressão digital de cada chave fixada do servidor SFTP, como o cliente SSH mostra: (algoritmo, SHA256:…)."""
    lista = []
    for par in campos.get('host_keys', '').split(','):
        algoritmo, _, corpo = par.partition(' ')
        if corpo:
            resumo = base64.b64encode(hashlib.sha256(base64.b64decode(corpo)).digest()).decode('ascii').rstrip('=')
            lista.append((algoritmo, 'SHA256:' + resumo))
    return lista


def alvo_de(caminho, relativo):
    """A pasta do remoto + o caminho do arquivo dentro da pasta dos dados. None quando não serve de caminho no
    remoto: passa de ALVO_MAX bytes ou tem caractere de controle."""
    alvo = f'{caminho.rstrip("/")}/{relativo}' if caminho else relativo
    try:
        cabe = len(alvo.encode('utf-8')) <= ALVO_MAX
    except UnicodeEncodeError:
        return None
    return alvo if cabe and relativo and not re.search(r'[\x00-\x1f\x7f]', alvo) else None


# ------------------------------------------------------------ a rede

def nomes_de_rede(tipo, campos):
    """Os servidores que o administrador escolheu: os campos de marca `r`. O que não tem um desses fala com o endereço
    do próprio serviço, que a configuração não muda."""
    nomes = []
    for nome, _, regra, marcas in CAMPOS[tipo]:
        if 'r' not in marcas or nome not in campos:
            continue
        if regra in (URL, URL_SAS):
            nomes.append(regra.fullmatch(campos[nome]).group(1))
        elif tipo == 'filescom' and '.' not in campos[nome]:
            nomes.append(campos[nome] + '.files.com')
        else:
            nomes.append(campos[nome].split('/')[0])
    return nomes


def conferir_rede(tipo, campos):
    """Os servidores do remoto podem receber uma conexão do painel? Vale a mesma regra do S3 (saida.aceito), e para
    todos os endereços de cada nome: quem escolhe entre eles é o rclone. Entre esta conferência e a conexão o nome
    pode mudar de endereço; quem segura o que vier daí é o certificado, onde há TLS, e a chave fixada do servidor,
    no SFTP. O que o serviço indicar depois de aberto (outro servidor para o envio) não passa por aqui."""
    for nome in nomes_de_rede(tipo, campos):
        try:
            achados = socket.getaddrinfo(nome, None, type=socket.SOCK_STREAM)
        except (socket.gaierror, UnicodeError):
            raise saida.Falha('dns') from None
        if not achados or not all(saida.aceito(achado[4][0]) for achado in achados):
            raise saida.Falha('endereco')


# ------------------------------------------------------------ o rclone

def linha_de(subcomando, gerais=(), finais=()):
    """A linha de comando de uma execução. O subcomando fora de SUBCOMANDOS é recusado antes de qualquer processo."""
    if subcomando not in SUBCOMANDOS:
        raise saida.Falha('proibido')
    return [BINARIO, *gerais, subcomando, *finais]


def preparar():
    os.makedirs(PASTA_TRABALHO, mode=0o700, exist_ok=True)


def cifrar(senha):
    """A senha como o rclone a guarda na configuração. Ela entra pela entrada padrão, nunca pela linha de comando."""
    preparar()
    try:
        feito = subprocess.run(linha_de('obscure', finais=('-',)), input=senha.encode('utf-8'), stdout=subprocess.PIPE,
                               stderr=subprocess.DEVNULL, env=AMBIENTE, cwd=PASTA_TRABALHO, timeout=10, check=True)
    except (OSError, subprocess.SubprocessError):
        raise saida.Falha('rclone') from None
    cifrada = feito.stdout.decode('ascii', 'replace').strip()
    if not CIFRADA.fullmatch(cifrada):
        raise saida.Falha('rclone')
    return cifrada


@contextlib.contextmanager
def vez(esperar):
    """Um rclone por vez, entre as passadas, o envio de um arquivo, o teste e o terminal. O envio espera a vez; o
    teste, que tem a tela esperando, levanta saida.Falha('em_uso')."""
    descritor = os.open(ARQ_TRAVA, os.O_RDWR | os.O_CREAT | os.O_CLOEXEC, 0o600)
    try:
        try:
            fcntl.flock(descritor, fcntl.LOCK_EX | (0 if esperar else fcntl.LOCK_NB))
        except OSError:
            raise saida.Falha('em_uso') from None
        yield
    finally:
        os.close(descritor)


def motivo_de(erro, ocultar=()):
    """A saída de erro do rclone ➜ o motivo. O que é do remoto (servidor, usuário, caminho) sai do texto antes da
    escolha, para um nome de arquivo ou de servidor não passar por motivo."""
    mensagens = []
    for linha in erro.decode('utf-8', 'replace').splitlines():
        try:
            dado = json.loads(linha)
            mensagens.append(str(dado.get('msg', '')) if isinstance(dado, dict) else '')
        except ValueError:
            mensagens.append(linha)
    texto = ' '.join(mensagens).lower()
    for parte in sorted({parte.lower() for parte in ocultar if len(parte) > 2}, key=len, reverse=True):
        texto = texto.replace(parte, ' ')
    return next((motivo for motivo, regra in MOTIVOS if regra.search(texto)), 'rclone')


def executar(linha, entrada, limite=None):
    """Roda o rclone até o fim e devolve (código de saída, começo da saída de erro, se passou do limite). `entrada`
    é o descritor de um arquivo aberto ou os bytes a entregar pela entrada padrão."""
    preparar()
    avulso = isinstance(entrada, bytes)
    try:
        processo = subprocess.Popen(linha, stdin=subprocess.PIPE if avulso else entrada, stdout=subprocess.DEVNULL,
                                    stderr=subprocess.PIPE, env=AMBIENTE, cwd=PASTA_TRABALHO, close_fds=True)
    except OSError:
        raise saida.Falha('rclone') from None
    estourou = threading.Event()

    def encerrar():
        estourou.set()
        processo.kill()
    relogio = threading.Timer(limite, encerrar) if limite else None
    if relogio:
        relogio.start()
    erro = b''
    try:
        if avulso:
            with contextlib.suppress(OSError):
                processo.stdin.write(entrada)
            with contextlib.suppress(OSError):
                processo.stdin.close()
        while True:
            pedaco = processo.stderr.read(65536)
            if not pedaco:
                break
            erro += pedaco[:ERRO_MAX - len(erro)]
        codigo = processo.wait()
    finally:
        if relogio:
            relogio.cancel()
        if processo.poll() is None:
            processo.kill()
            processo.wait()
        processo.stderr.close()
    return codigo, erro, estourou.is_set()


class Remoto:
    """O remoto de um destino. `texto` é o segredo gravado; `caminho`, a pasta dentro do remoto; `guardar(texto)`
    regrava o segredo quando o rclone renova o token ou o teste fixa a chave do servidor."""

    def __init__(self, destino, texto, caminho='', prazo=saida.PRAZO, guardar=None):
        if not DESTINO.fullmatch(destino) or (caminho and not (len(caminho) <= CAMINHO_MAX and CAMINHO.fullmatch(caminho))):
            raise saida.Falha('segredo')
        self.destino, self.caminho, self.prazo, self.guardar = destino, caminho, int(prazo), guardar
        self.tipo, self.campos = analisar(texto)

    def fechar(self):
        """Nada fica aberto entre um arquivo e o seguinte: cada envio é um processo."""

    def sem_chave(self):
        return self.tipo == 'sftp' and 'host_keys' not in self.campos

    def enviar(self, alvo, descritor, tamanho):
        """Grava no remoto, em `alvo`, o arquivo aberto em `descritor`. Levanta saida.Falha quando não grava."""
        if self.sem_chave():
            raise saida.Falha('sem_chave')
        os.lseek(descritor, 0, os.SEEK_SET)
        self.gravar(alvo, descritor, tamanho, True)

    def testar(self):
        """Grava um arquivo de teste na pasta do remoto. No SFTP ainda sem chave de servidor, é este teste, pedido
        pelo administrador, que guarda a chave que o servidor apresentou."""
        texto = f'Teste de gravação da allsafe-ftp-stack, em {time.strftime("%Y-%m-%d %H:%M:%S")}.\n'.encode()
        self.gravar(alvo_de(self.caminho, ARQ_TESTE), texto, len(texto), False, TESTE_TOTAL)

    def gravar(self, alvo, entrada, tamanho, esperar, limite=None):
        if not alvo or alvo_de('', alvo) is None:
            raise saida.Falha('nome')
        conferir_rede(self.tipo, self.campos)
        fixar = self.sem_chave()
        gerais = ['--use-json-log', '--log-level', 'ERROR', '--ask-password=false', '--retries', '1',
                  '--low-level-retries', str(1 if limite else TENTATIVAS), '--contimeout', f'{self.prazo}s',
                  '--timeout', f'{self.prazo}s', '--transfers', '1', '--checkers', '1']
        if os.path.isfile(saida.ARQ_CA):
            gerais += ['--ca-cert', saida.ARQ_CA]
        if fixar:
            gerais.append('--sftp-pin-host-key')
        copia = os.path.join(PASTA_TRABALHO, self.destino + '.conf')
        with vez(esperar):
            preparar()
            try:
                descritor = os.open(copia, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600)
                with os.fdopen(descritor, 'w', encoding='ascii') as arq:
                    arq.write(montar(self.tipo, self.campos))
                codigo, erro, estourou = executar(
                    linha_de('rcat', ['--config', copia] + gerais, ['--size', str(tamanho), f'{SECAO}:{alvo}']), entrada, limite)
                self.recolher(copia, fixar and codigo == 0)
            except OSError:
                raise saida.Falha('rclone') from None
            finally:
                with contextlib.suppress(OSError):
                    os.unlink(copia)
        if estourou:
            raise saida.Falha('tempo')
        if codigo:
            textos = [self.campos[nome] for nome, forma, _, _ in CAMPOS[self.tipo]
                      if forma == 'texto' and nome in self.campos]
            raise saida.Falha(motivo_de(erro, [alvo, alvo.rsplit('/', 1)[-1], self.caminho] + textos))
        if fixar and self.sem_chave():
            raise saida.Falha('sem_chave')

    def recolher(self, copia, fixou):
        """Lê da cópia o que o rclone mudou e o painel guarda: o token renovado e, quando o teste fixou, a chave do
        servidor. Cada valor passa pela forma do campo; o que o rclone escreveu além disso fica na cópia, que é apagada."""
        with open(copia, encoding='utf-8', errors='replace') as arq:
            lidos = dict(linha.split(' = ', 1) for linha in arq.read(ERRO_MAX).split('\n') if ' = ' in linha)
        novos = dict(self.campos)
        for nome, forma, regra, _ in CAMPOS[self.tipo]:
            if not ((forma == 'json' and regra == 'token') or (forma == 'chaves' and fixou)) or nome not in lidos:
                continue
            try:
                valor = json_em_linha(lidos[nome], regra) if forma == 'json' else chaves_em_linha(lidos[nome])
                novos[nome] = guardado(forma, regra, valor)
            except ValueError:
                continue
        if novos == self.campos:
            return
        self.campos = novos
        if self.guardar:
            try:
                self.guardar(montar(self.tipo, novos))
            except OSError:
                if fixou:
                    raise saida.Falha('segredo') from None
