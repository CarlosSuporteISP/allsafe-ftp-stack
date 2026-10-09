# SPDX-License-Identifier: Apache-2.0
"""Recursos da máquina em que a stack roda: processador, memória e a rede do FTP, com o histórico dos últimos minutos.

O painel lê só o que o container dele já enxerga: o /proc mostra o processador e a memória do servidor inteiro, e a
rede do serviço ftp chega pelo arquivo que o vigia dele publica em /auth. Não há soquete do Docker nem pasta do
servidor montada para isso. O histórico fica na memória do processo e recomeça quando o painel reinicia.
"""
import collections
import functools
import os
import re
import threading
import time

from config import ARQ_REDE

INTERVALO = 5               # segundos entre duas amostras
AMOSTRAS = 120              # amostras guardadas: 10 minutos
REDE_VALE = 12              # segundos em que a última leitura da rede ainda é a velocidade de agora
NUCLEO = re.compile(r'cpu\d+ ')

HISTORICO = collections.deque(maxlen=AMOSTRAS)
TRAVA = threading.Lock()
INICIO = time.time()


def ler_processador():
    """(tempo ocupado, tempo total, núcleos) do servidor desde que ligou, em tiques; None se não der para ler."""
    try:
        with open('/proc/stat', encoding='ascii', errors='replace') as arq:
            linhas = arq.read(65536).splitlines()
    except OSError:
        return None
    campos = linhas[0].split() if linhas else []
    if len(campos) < 6 or campos[0] != 'cpu' or not all(campo.isdigit() for campo in campos[1:9]):
        return None
    # usuário, nice, sistema, parado, espera de disco, interrupções (duas) e tempo tomado por outra máquina virtual.
    tempos = [int(campo) for campo in campos[1:9]]
    parado = tempos[3] + tempos[4]
    return sum(tempos) - parado, sum(tempos), sum(1 for linha in linhas if NUCLEO.match(linha)) or 1


def ler_memoria():
    """Memória do servidor, em bytes: total, disponível, cache e swap; None se não der para ler."""
    valores = {}
    try:
        with open('/proc/meminfo', encoding='ascii', errors='replace') as arq:
            for linha in arq.read(16384).splitlines():
                nome, _, resto = linha.partition(':')
                campos = resto.split()
                if campos and campos[0].isdigit():
                    valores[nome] = int(campos[0]) * 1024
    except OSError:
        return None
    if not valores.get('MemTotal') or 'MemAvailable' not in valores:
        return None
    return {'total': valores['MemTotal'], 'disponivel': min(valores['MemAvailable'], valores['MemTotal']),
            'cache': valores.get('Cached', 0) + valores.get('Buffers', 0),
            'swap_total': valores.get('SwapTotal', 0), 'swap_livre': valores.get('SwapFree', 0)}


def ler_rede():
    """Última leitura da rede que o vigia do serviço ftp publicou; None se não há leitura ou se ela não é a esperada.

    O arquivo é uma linha de sete números: instante, segundos do intervalo, bytes recebidos e enviados desde que o
    container do ftp subiu, bytes recebidos e enviados no intervalo, e erros e descartes. Nada além de dígitos é aceito.
    """
    try:
        descritor = os.open(ARQ_REDE, os.O_RDONLY | os.O_NOFOLLOW)
        with os.fdopen(descritor, encoding='ascii', errors='replace') as arq:
            campos = arq.readline(200).split()
    except OSError:
        return None
    if len(campos) != 7 or not all(campo.isascii() and campo.isdigit() and len(campo) <= 20 for campo in campos):
        return None
    quando, intervalo, recebido, enviado, recebeu, enviou, erros = (int(campo) for campo in campos)
    return {'quando': quando, 'intervalo': intervalo, 'recebido': recebido, 'enviado': enviado,
            'recebeu': recebeu, 'enviou': enviou, 'erros': erros}


def velocidade(rede, agora=None):
    """(recebendo, enviando) em bytes por segundo. Leitura antiga quer dizer que a rede parou: o vigia só publica
    quando os contadores mudam."""
    agora = time.time() if agora is None else agora
    if not rede or rede['intervalo'] <= 0 or agora - rede['quando'] > REDE_VALE:
        return 0.0, 0.0
    return rede['recebeu'] / rede['intervalo'], rede['enviou'] / rede['intervalo']


def carga():
    """Carga média do servidor em 1, 5 e 15 minutos; None se não der para ler."""
    try:
        with open('/proc/loadavg', encoding='ascii', errors='replace') as arq:
            return tuple(float(campo) for campo in arq.read(128).split()[:3])
    except (OSError, ValueError):
        return None


def ligado_ha():
    """Segundos desde que o servidor ligou; None se não der para ler."""
    try:
        with open('/proc/uptime', encoding='ascii', errors='replace') as arq:
            return float(arq.read(64).split()[0])
    except (OSError, ValueError, IndexError):
        return None


@functools.lru_cache(maxsize=1)
def modelo():
    """Nome do processador, como o sistema informa; vazio quando ele não informa (acontece fora do x86)."""
    try:
        with open('/proc/cpuinfo', encoding='utf-8', errors='replace') as arq:
            for linha in arq.read(16384).splitlines():
                nome, _, valor = linha.partition(':')
                if nome.strip() in ('model name', 'Model', 'Hardware') and valor.strip():
                    return ' '.join(valor.split())[:80]
    except OSError:
        pass
    return ''


def memoria_do_painel():
    """(memória em uso, limite) do container do painel, em bytes; o limite é None quando o container não tem um."""
    def ler(nome):
        try:
            with open(f'/sys/fs/cgroup/{nome}', encoding='ascii', errors='replace') as arq:
                texto = arq.read(32).strip()
        except OSError:
            return None
        return int(texto) if texto.isdigit() else None
    return ler('memory.current'), ler('memory.max')


def amostrar():
    """Laço do histórico: a cada intervalo, o uso do processador no período, a memória em uso e a velocidade da rede.
    Leitura que falha vira None naquela amostra; o laço não para por isso."""
    antes = ler_processador()
    while True:
        time.sleep(INTERVALO)
        agora = ler_processador()
        uso = None
        if antes and agora and agora[1] > antes[1]:
            uso = 100 * (agora[0] - antes[0]) / (agora[1] - antes[1])
        antes = agora
        memoria = ler_memoria()
        usada = 100 * (memoria['total'] - memoria['disponivel']) / memoria['total'] if memoria else None
        recebendo, enviando = velocidade(ler_rede())
        with TRAVA:
            HISTORICO.append((uso, usada, recebendo, enviando))


def iniciar():
    """Começa a guardar o histórico. Só o servidor do painel chama: os outros modos (--saude, --hash) não amostram."""
    threading.Thread(target=amostrar, name='recursos', daemon=True).start()


def historico():
    """As amostras guardadas, da mais antiga para a mais nova: (processador %, memória %, recebendo, enviando)."""
    with TRAVA:
        return list(HISTORICO)
