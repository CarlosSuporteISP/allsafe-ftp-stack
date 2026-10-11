# SPDX-License-Identifier: Apache-2.0
"""Chegadas: os arquivos que acabaram de chegar inteiros, para o bot do Telegram enviar sem esperar.

O painel não tem como saber sozinho que um envio por FTP terminou: o arquivo aparece na pasta enquanto ainda chega.
Quem sabe é o servidor FTP, e o vigia dele grava um anúncio em /auth/chegadas para cada envio concluído: um arquivo
com o caminho dentro dos dados. A linha de execução dos destinos colhe os anúncios com colher(); o envio pelo painel
anuncia direto, com chegou().

O anúncio não escolhe o que é enviado: só dispensa a espera de um arquivo que a passada encontraria de qualquer
jeito, dentro da pasta do destino. Um anúncio falso, perdido ou repetido não envia nada a mais."""
import contextlib
import os
import re
import stat
import threading
import time

from config import PASTA_CHEGADAS

NOME = re.compile(r'[0-9]{1,12}-[0-9]{1,12}')   # o nome que o vigia dá ao anúncio; o de passagem começa por ponto
CAMINHO_MAX = 4096           # bytes do caminho anunciado
VALE = 240 * 10**9           # ns: depois disso o arquivo já assentou, e o anúncio não diz mais nada
ANUNCIADOS_MAX = 20000       # anúncios guardados na memória
ANUNCIADOS = {}              # caminho dentro dos dados ➜ instante do anúncio, em ns
NOVAS = threading.Event()    # chegou anúncio desde a última vez que a linha de execução dos destinos olhou
TRAVA = threading.Lock()


def chegou(caminho, instante=None):
    """Anuncia um arquivo que está inteiro no lugar dele. Sem `instante`, chegou agora (envio pelo painel)."""
    with TRAVA:
        ANUNCIADOS.pop(caminho, None)   # volta para o fim: o primeiro é sempre o mais antigo
        ANUNCIADOS[caminho] = instante or time.time_ns()
        while len(ANUNCIADOS) > ANUNCIADOS_MAX:
            del ANUNCIADOS[next(iter(ANUNCIADOS))]
    NOVAS.set()


def colher():
    """Lê e apaga os anúncios do vigia do FTP. O instante do anúncio é a data do arquivo dele, do mesmo relógio que
    data os arquivos dos dados."""
    try:
        pasta = os.open(PASTA_CHEGADAS, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
    except OSError:
        return
    try:
        with os.scandir(pasta) as itens:
            nomes = [item.name for item in itens if NOME.fullmatch(item.name)]
        agora = time.time_ns()
        for nome in nomes:
            try:
                descritor = os.open(nome, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK, dir_fd=pasta)
            except OSError:
                continue
            try:
                dados = os.fstat(descritor)
                lido = os.read(descritor, CAMINHO_MAX + 1) if stat.S_ISREG(dados.st_mode) else b''
            except OSError:
                dados, lido = None, b''
            finally:
                os.close(descritor)
            with contextlib.suppress(OSError):
                os.unlink(nome, dir_fd=pasta)
            if dados is None:
                continue
            try:
                caminho = lido.decode('utf-8')
            except UnicodeDecodeError:
                continue   # a passada também não envia nome que não é UTF-8
            if caminho and len(lido) <= CAMINHO_MAX and '\x00' not in caminho and agora - dados.st_mtime_ns < VALE:
                chegou(caminho, dados.st_mtime_ns)
    finally:
        os.close(pasta)


def validos():
    """Os anúncios que ainda valem: {caminho: instante}."""
    limite = time.time_ns() - VALE
    with TRAVA:
        for caminho in [caminho for caminho, instante in ANUNCIADOS.items() if instante < limite]:
            del ANUNCIADOS[caminho]
        return dict(ANUNCIADOS)
