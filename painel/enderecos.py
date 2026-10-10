# SPDX-License-Identifier: Apache-2.0
"""Bloqueio por endereço: quem erra usuário e senha demais não entra mais, nem no FTP nem no painel.

Cada endereço bloqueado é um arquivo em /auth/enderecos, com o nome dele e uma linha: `<vale até> <desde> <erros>
<quem bloqueou>`. Gravam o vigia do serviço ftp (erros no FTP), este módulo (erros na entrada e na confirmação por
senha do painel, pelo allsafe-ftp-user) e o administrador, no terminal. O porteiro do FTP e o atendimento do painel
aplicam: com o arquivo valendo, o endereço é recusado com qualquer conta.

Nunca são bloqueados daqui: o próprio servidor, a rede interna da stack, o endereço de saída do container (por ele
chegam os clientes do próprio host) e os proxies de PAINEL_PROXY_CONFIAVEL, atrás dos quais estão todos os
visitantes. Para esses continua valendo só o limite curto de tentativas da entrada."""
import ipaddress
import os
import re
import sys
import threading
import time

from auditoria import auditar
from config import CFG, PASTA_ENDERECOS
from estado import com_cache, executar_usuario
from idioma import N

# IPv4 escrito de um jeito só: é o nome do arquivo do bloqueio. A mesma regra do vigia, do porteiro e do allsafe-ftp-user.
IPV4 = re.compile(r'(?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])')
QUEM = {'ftp': N('FTP'), 'painel': N('Painel'), 'manual': N('Administrador')}
ENDERECOS_LIDOS = 10000     # arquivos lidos por tela; é o teto de endereços bloqueados
CONTAGENS_MAX = 5000        # endereços com erro guardados na memória
TRAVA = threading.Lock()
ERROS = {}                  # endereço ➜ instantes dos erros de usuário e senha ainda dentro da janela


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
    if not IPV4.fullmatch(ip):
        return True
    endereco = ipaddress.ip_address(ip)
    if endereco.is_loopback or endereco in CFG['proxies']:
        return True
    redes = com_cache('redes_do_container', 60, redes_do_container)
    return redes is None or any(endereco in rede for rede in redes)


def ler(ip):
    """Bloqueio em vigor do endereço: (vale até, desde, erros, quem bloqueou), ou None."""
    if not IPV4.fullmatch(ip) or ip.startswith('127.'):
        return None
    try:
        descritor = os.open(os.path.join(PASTA_ENDERECOS, ip), os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
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


def bloqueado(ip):
    return ler(ip) is not None


def erro_de_entrada(ip):
    """Conta um erro de usuário e senha do endereço. Quando ele passa do limite dentro da janela, o endereço é
    bloqueado no FTP e no painel. Entrada certa não zera a contagem: quem tem uma conta não ganha tentativas."""
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
    """Endereço liberado: a contagem dele recomeça."""
    with TRAVA:
        ERROS.pop(ip, None)


def ler_todos():
    achados = []
    try:
        itens = os.listdir(PASTA_ENDERECOS)[:ENDERECOS_LIDOS]
    except OSError:
        return achados
    for item in itens:
        dado = ler(item)
        if dado:
            achados.append((item,) + dado)
    achados.sort(key=lambda bloqueio: -bloqueio[2])
    return achados


def lista():
    """Endereços bloqueados agora, do mais recente para o mais antigo: (endereço, vale até, desde, erros, quem)."""
    return com_cache('enderecos', 5, ler_todos)
