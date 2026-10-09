# SPDX-License-Identifier: Apache-2.0
"""Recursos do servidor e de cada container da stack, com o histórico dos últimos minutos.

O painel lê só o que o container dele já enxerga: o /proc mostra o processador e a memória do servidor inteiro, e o
cgroup, o uso e os limites do próprio container. Os outros dois containers leem o cgroup deles e publicam uma linha
de números: o ftp em /auth (junto com a rede dele) e o nginx na pasta de estado dele. Não há soquete do Docker nem
pasta do servidor montada para isso. O histórico fica na memória do processo e recomeça quando o painel reinicia.
"""
import collections
import functools
import os
import re
import stat
import threading
import time

from config import ARQ_RECURSOS_FTP, ARQ_RECURSOS_NGINX, ARQ_REDE

INTERVALO = 5               # segundos entre duas amostras
AMOSTRAS = 120              # amostras guardadas: 10 minutos
REDE_VALE = 12              # segundos em que a última leitura da rede ainda é a velocidade de agora
RECURSOS_VALE = 90          # segundos em que vale o que outro container publicou: parado, ele publica uma vez por minuto
NUCLEO = re.compile(r'cpu\d+ ')
NUMERO = re.compile(r'[0-9]{1,20}')
CGROUP = '/sys/fs/cgroup'
# Os containers da stack, pelo nome do serviço no compose.yaml; None é o do próprio painel, lido direto do cgroup.
PUBLICADOS = (('ftp', ARQ_RECURSOS_FTP), ('painel', None), ('nginx', ARQ_RECURSOS_NGINX))

HISTORICO = collections.deque(maxlen=AMOSTRAS)
TRAVA = threading.Lock()
INICIO = time.time()
PROPRIO = {}                # última leitura do container do painel, com o uso do processador já calculado


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


def ler_linha(caminho, quantos):
    """Os números da primeira linha de um arquivo de estado que outro container grava; None se ela não é exatamente
    `quantos` números. Quem grava não é de confiança: o painel não segue link simbólico, não espera por arquivo que
    não seja comum (um FIFO prenderia a leitura), lê só o começo e não aceita nada além de dígitos."""
    try:
        descritor = os.open(caminho, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    except OSError:
        return None
    try:
        if not stat.S_ISREG(os.fstat(descritor).st_mode):
            return None
        texto = os.read(descritor, 400).decode('ascii', errors='replace')
    except OSError:
        return None
    finally:
        os.close(descritor)
    campos = texto.split('\n', 1)[0].split()
    if len(campos) != quantos or not all(NUMERO.fullmatch(campo) for campo in campos):
        return None
    return [int(campo) for campo in campos]


def ler_rede():
    """Última leitura da rede que o vigia do serviço ftp publicou; None se não há leitura ou se ela não é a esperada.

    O arquivo é uma linha de sete números: instante, segundos do intervalo, bytes recebidos e enviados desde que o
    container do ftp subiu, bytes recebidos e enviados no intervalo, e erros e descartes. Nada além de dígitos é aceito.
    """
    campos = ler_linha(ARQ_REDE, 7)
    if not campos:
        return None
    quando, intervalo, recebido, enviado, recebeu, enviou, erros = campos
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


def do_cgroup(nome, chave=None):
    """Um número do cgroup do container do painel: o do arquivo ou, com `chave`, o da linha que começa por ela.
    None quando não há número ali, que é o caso de "max" (sem limite)."""
    try:
        with open(f'{CGROUP}/{nome}', encoding='ascii', errors='replace') as arq:
            texto = arq.read(8192)
    except OSError:
        return None
    for linha in texto.splitlines():
        campos = linha.split()
        if chave is None:
            return int(campos[0]) if campos and NUMERO.fullmatch(campos[0]) else None
        if len(campos) == 2 and campos[0] == chave:
            return int(campos[1]) if NUMERO.fullmatch(campos[1]) else None
    return None


def limite_de_nucleos():
    """Núcleos que o container do painel pode usar (cota dividida pelo período); None sem limite."""
    try:
        with open(f'{CGROUP}/cpu.max', encoding='ascii', errors='replace') as arq:
            campos = arq.read(64).split()
    except OSError:
        return None
    if len(campos) == 2 and all(NUMERO.fullmatch(campo) for campo in campos) and int(campos[0]) and int(campos[1]):
        return int(campos[0]) / int(campos[1])
    return None


def ler_proprio(antes=None):
    """Recursos do container do painel, lidos do cgroup dele. `antes` é (instante, microssegundos de processador) da
    leitura anterior: com ele, sai o uso do processador no intervalo, em núcleos. Devolve a leitura e o par de agora."""
    instante, gasto = time.monotonic(), do_cgroup('cpu.stat', 'usage_usec')
    em_uso, inativa = do_cgroup('memory.current'), do_cgroup('memory.stat', 'inactive_file') or 0
    if gasto is None or em_uso is None:
        return None, None
    nucleos = None
    if antes and instante > antes[0] and gasto >= antes[1]:
        nucleos = (gasto - antes[1]) / 1e6 / (instante - antes[0])
    return {'inicio': INICIO, 'cpu': nucleos, 'nucleos': limite_de_nucleos(),
            # Como o `docker stats`: o cache de arquivo que o sistema solta quando precisa não conta como uso.
            'memoria': max(em_uso - inativa, 0), 'memoria_max': do_cgroup('memory.max'),
            'processos': do_cgroup('pids.current') or 0, 'processos_max': do_cgroup('pids.max'),
            'contido': do_cgroup('cpu.stat', 'nr_throttled') or 0,
            'faltou': do_cgroup('memory.events', 'oom_kill') or 0}, (instante, gasto)


def ler_publicado(caminho, agora=None):
    """Recursos que outro container da stack publicou, no mesmo formato de `ler_proprio`; None sem leitura que valha.

    A linha tem doze números: instante, instante em que o container iniciou, milissegundos do intervalo,
    microssegundos de processador gastos nele, cota e período do limite de processador, memória em uso e limite,
    processos e limite, vezes em que o limite de processador segurou o container e vezes em que faltou memória.
    Limite 0 quer dizer sem limite.
    """
    agora = time.time() if agora is None else agora
    campos = ler_linha(caminho, 12)
    if not campos:
        return None
    quando, inicio, intervalo, gasto, cota, periodo, memoria, memoria_max, processos, processos_max, contido, faltou = campos
    if not -RECURSOS_VALE <= agora - quando <= RECURSOS_VALE:
        return None
    return {'inicio': inicio, 'cpu': gasto / 1000 / intervalo if intervalo else None,
            'nucleos': cota / periodo if cota and periodo else None,
            'memoria': memoria, 'memoria_max': memoria_max or None,
            'processos': processos, 'processos_max': processos_max or None, 'contido': contido, 'faltou': faltou}


def containers():
    """Os containers da stack, na ordem da tela: (serviço, leitura), com None onde não há leitura."""
    with TRAVA:
        proprio = dict(PROPRIO) or None
    return [(nome, ler_publicado(caminho) if caminho else proprio) for nome, caminho in PUBLICADOS]


def amostrar():
    """Laço do histórico: a cada intervalo, o uso do processador no período, a memória em uso, a velocidade da rede e
    o processador e a memória de cada container. Leitura que falha vira None naquela amostra; o laço não para por isso."""
    antes = ler_processador()
    proprio, par = ler_proprio()
    with TRAVA:
        PROPRIO.update(proprio or {})
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
        proprio, par = ler_proprio(par)
        with TRAVA:
            PROPRIO.clear()
            PROPRIO.update(proprio or {})
        por_container = {nome: (leitura['cpu'], leitura['memoria']) if leitura else (None, None)
                         for nome, leitura in containers()}
        with TRAVA:
            HISTORICO.append((uso, usada, recebendo, enviando, por_container))


def iniciar():
    """Começa a guardar o histórico. Só o servidor do painel chama: os outros modos (--saude, --hash) não amostram."""
    threading.Thread(target=amostrar, name='recursos', daemon=True).start()


def historico():
    """As amostras guardadas, da mais antiga para a mais nova: (processador %, memória %, recebendo, enviando e,
    por container, o processador em núcleos e a memória em bytes)."""
    with TRAVA:
        return list(HISTORICO)
