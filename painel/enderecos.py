# SPDX-License-Identifier: Apache-2.0
"""Bloqueio por endereço: quem erra usuário e senha demais não entra mais, nem no FTP nem no painel.

Cada endereço bloqueado, IPv4 ou IPv6, é um arquivo em /auth/enderecos, com o nome dele e uma linha: `<vale até>
<desde> <erros> <quem bloqueou>`. Gravam o vigia do serviço ftp (erros no FTP), este módulo (erros na entrada e na
confirmação por senha do painel, pelo allsafe-ftp-user) e o administrador, na aba Bloqueios ou no terminal. O
porteiro do FTP e o atendimento do painel aplicam: com o arquivo valendo, o endereço é recusado com qualquer conta.

Prefixo (uma rede inteira) é um arquivo em /auth/prefixos, `<rede>_<tamanho>`, com a mesma linha. Só o
administrador bloqueia prefixo: o bloqueio automático é sempre de um endereço.

O nome do arquivo é o endereço numa escrita só, a mesma do FTP (ftp/endereco.pl): IPv4 sem zero à esquerda, IPv6
minúsculo e comprimido, e o IPv4 escrito dentro de IPv6 (::ffff:a.b.c.d) como IPv4. Do próprio servidor, e nunca
bloqueado, é o que está em 127.0.0.0/8, em 0.0.0.0/8 e em ::/16.

Nunca são bloqueados sozinhos: o próprio servidor, a rede interna da stack, o endereço de saída do container (por
ele chegam os clientes do próprio host) e os proxies de PAINEL_PROXY_CONFIAVEL, atrás dos quais estão todos os
visitantes. Para esses continua valendo só o limite curto de tentativas da entrada."""
import ipaddress
import os
import re
import sys
import threading
import time

from auditoria import auditar
from config import CFG, PASTA_ENDERECOS, PASTA_PREFIXOS
from estado import com_cache, executar_usuario
from idioma import N

# O que pode ser um endereço: sem zona (%eth0) nem nada além de números, letras de hexadecimal, ponto e dois-pontos.
ENDERECO = re.compile(r'[0-9A-Fa-f.:]{2,45}')
TAMANHO = re.compile(r'[1-9][0-9]{0,2}')
QUEM = {'ftp': N('FTP'), 'painel': N('Painel'), 'manual': N('Administrador')}
ENDERECOS_LIDOS = 10000     # arquivos lidos por tela; é o teto de endereços bloqueados
PREFIXOS_LIDOS = 1000       # o teto de prefixos bloqueados
PREFIXOS_VALEM = 5          # segundos: a lista de prefixos é relida quando a pasta muda e, no máximo, a cada tanto
CONTAGENS_MAX = 5000        # endereços com erro guardados na memória
TRAVA = threading.Lock()
ERROS = {}                  # endereço ➜ instantes dos erros de usuário e senha ainda dentro da janela
PREFIXOS = {'marca': None, 'lido': 0.0, 'redes': ()}


def endereco_de(texto):
    """Texto ➜ endereço (ipaddress), com o IPv4 escrito dentro de IPv6 já como IPv4. None se não é endereço."""
    if not isinstance(texto, str) or not ENDERECO.fullmatch(texto):
        return None
    try:
        endereco = ipaddress.ip_address(texto)
    except ValueError:
        return None
    return endereco.ipv4_mapped or endereco if endereco.version == 6 else endereco


def do_servidor(endereco):
    """Endereço do próprio servidor, que nunca vira bloqueio: 127.0.0.0/8, 0.0.0.0/8 e ::/16."""
    return int(endereco) >> 24 in (0, 127) if endereco.version == 4 else int(endereco) >> 112 == 0


def prefixo_de(texto):
    """'rede/tamanho' ➜ rede (ipaddress), já sem os bits depois do tamanho. None se não é prefixo aceito: IPv4 de
    /8 a /31 e IPv6 de /16 a /127."""
    rede, barra, tamanho = texto.partition('/') if isinstance(texto, str) else ('', '', '')
    endereco = endereco_de(rede)
    if not barra or endereco is None or not TAMANHO.fullmatch(tamanho):
        return None
    minimo, maximo = (8, 31) if endereco.version == 4 else (16, 127)
    if not minimo <= int(tamanho) <= maximo:
        return None
    return ipaddress.ip_network(f'{endereco}/{tamanho}', strict=False)


def alvo(texto):
    """O que o administrador quer bloquear ➜ ('endereco' ou 'prefixo', escrita única, rede que ele cobre).
    ('invalido', '', None) se o texto não é nenhum dos dois; ('servidor', '', None) se é do próprio servidor."""
    endereco, rede = endereco_de(texto), prefixo_de(texto)
    if endereco is None and rede is None:
        return 'invalido', '', None
    if do_servidor(endereco if rede is None else rede.network_address):
        return 'servidor', '', None
    if rede is None:
        return 'endereco', str(endereco), ipaddress.ip_network(endereco)
    return 'prefixo', str(rede), rede


def redes_do_container():
    """Redes ligadas direto a este container, lidas de /proc/net/route; None quando não dá para ler."""
    redes = []
    try:
        with open('/proc/net/route', encoding='ascii') as arq:
            for linha in arq.readlines()[1:]:
                campos = linha.split()
                # Rota sem gateway (campo 3 zerado) é rede ligada direto; a rota padrão tem máscara zero e fica de fora.
                if len(campos) < 8 or int(campos[2], 16) or not int(campos[7], 16):
                    continue
                destino, mascara = (int.from_bytes(int(campos[n], 16).to_bytes(4, sys.byteorder), 'big') for n in (1, 7))
                redes.append(ipaddress.ip_network((destino, bin(mascara).count('1'))))
    except (OSError, ValueError):
        return None
    return redes


def poupado(ip):
    """Endereço que o painel nunca bloqueia sozinho."""
    endereco = endereco_de(ip)
    if endereco is None or do_servidor(endereco) or endereco in CFG['proxies']:
        return True
    if endereco.version == 6:
        return False    # as redes ligadas a este container são IPv4: endereço IPv6 só chega informado por proxy
    redes = com_cache('redes_do_container', 60, redes_do_container)
    return redes is None or any(endereco in rede for rede in redes)


def protegido(rede, ip):
    """Por que o administrador não bloqueia esta rede pelo painel: ela pega o endereço dele ('proprio') ou a rede
    interna da stack, o endereço de saída do container ou um proxy confiável ('stack'). '' quando pode."""
    dele = endereco_de(ip)
    if dele is not None and dele.version == rede.version and dele in rede:
        return 'proprio'
    if any(proxy.version == rede.version and proxy in rede for proxy in CFG['proxies']):
        return 'stack'
    redes = com_cache('redes_do_container', 60, redes_do_container)
    if rede.version == 4 and (redes is None or any(rede.overlaps(outra) for outra in redes)):
        return 'stack'
    return ''


def ler_arquivo(caminho):
    """Bloqueio em vigor gravado no arquivo: (vale até, desde, erros, quem bloqueou), ou None."""
    try:
        descritor = os.open(caminho, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        try:
            campos = os.read(descritor, 64).decode('ascii', 'replace').split('\n')[0].split()
        finally:
            os.close(descritor)
    except OSError:
        return None
    if len(campos) < 3 or not all(campo.isascii() and campo.isdigit() and len(campo) <= 12 for campo in campos[:3]):
        return None
    expira, desde, erros = (int(campo) for campo in campos[:3])
    if expira <= time.time():
        return None
    return expira, desde, erros, campos[3] if len(campos) > 3 and campos[3] in QUEM else 'manual'


def ler(texto):
    """Bloqueio em vigor do endereço ou do prefixo, dito na escrita única: (vale até, desde, erros, quem), ou None."""
    tipo, escrita, _ = alvo(texto)
    if escrita != texto:
        return None
    if tipo == 'prefixo':
        return ler_arquivo(os.path.join(PASTA_PREFIXOS, escrita.replace('/', '_')))
    return ler_arquivo(os.path.join(PASTA_ENDERECOS, escrita))


def ler_pasta(pasta, teto, texto_de):
    achados = []
    try:
        itens = os.listdir(pasta)[:teto]
    except OSError:
        return achados
    for item in itens:
        dado = ler(texto_de(item))
        if dado:
            achados.append((texto_de(item),) + dado)
    return achados


def prefixos():
    """Prefixos bloqueados: ((rede, vale até), ...). A pasta é relida quando muda e, no máximo, a cada
    PREFIXOS_VALEM segundos: a data da pasta não distingue duas mudanças no mesmo instante."""
    try:
        marca = os.stat(PASTA_PREFIXOS).st_mtime_ns
    except OSError:
        return ()
    agora = time.monotonic()
    with TRAVA:
        if PREFIXOS['marca'] == marca and agora - PREFIXOS['lido'] < PREFIXOS_VALEM:
            return PREFIXOS['redes']
    redes = tuple((prefixo_de(texto), expira)
                  for texto, expira, *_ in ler_pasta(PASTA_PREFIXOS, PREFIXOS_LIDOS, lambda item: item.replace('_', '/')))
    with TRAVA:
        PREFIXOS.update(marca=marca, lido=agora, redes=redes)
    return redes


def bloqueado(ip):
    """O endereço não entra: está bloqueado ele mesmo, ou um prefixo bloqueado o cobre."""
    endereco = endereco_de(ip)
    if endereco is None or do_servidor(endereco):
        return False
    if ler_arquivo(os.path.join(PASTA_ENDERECOS, str(endereco))) is not None:
        return True
    agora = time.time()
    return any(expira > agora and rede.version == endereco.version and endereco in rede for rede, expira in prefixos())


def erro_de_entrada(ip):
    """Conta um erro de usuário e senha do endereço. Quando ele passa do limite dentro da janela, o endereço é
    bloqueado no FTP e no painel. Entrada certa zera a contagem (esquecer); o limite curto de tentativas da
    entrada continua contando, e é ele que segura quem tem uma conta e tenta a senha de outra."""
    limite = CFG['endereco_erros']
    if not limite or poupado(ip):
        return
    agora = time.time()
    with TRAVA:
        if ip not in ERROS and len(ERROS) >= CONTAGENS_MAX:
            ERROS.clear()
        dentro = [instante for instante in ERROS.get(ip, ()) if agora - instante < CFG['endereco_janela']] + [agora]
        if len(dentro) <= limite:
            ERROS[ip] = dentro
            return
        ERROS.pop(ip, None)
    feito, _ = executar_usuario('endereco-bloquear', ip, pares=(str(CFG['endereco_dias']), 'painel', str(len(dentro))))
    if feito:
        auditar(ip, 'endereco_bloqueado', f'erros={len(dentro)} dias={CFG["endereco_dias"]}')
    else:
        auditar(ip, 'falha_comando', 'acao=bloquear_endereco')


def esquecer(ip):
    """Endereço liberado, ou que entrou com usuário e senha certos: a contagem dele recomeça."""
    with TRAVA:
        ERROS.pop(ip, None)


def ler_todos():
    achados = (ler_pasta(PASTA_ENDERECOS, ENDERECOS_LIDOS, str)
               + ler_pasta(PASTA_PREFIXOS, PREFIXOS_LIDOS, lambda item: item.replace('_', '/')))
    achados.sort(key=lambda bloqueio: -bloqueio[2])
    return achados


def lista():
    """Endereços e prefixos bloqueados agora, do mais recente para o mais antigo: (endereço ou prefixo, vale até,
    desde, erros, quem)."""
    return com_cache('enderecos', 5, ler_todos)
