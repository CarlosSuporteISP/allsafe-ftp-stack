# SPDX-License-Identifier: Apache-2.0
"""Auditoria do painel: uma linha por evento, no arquivo e na saída do container."""
import os
import re
import sys
import threading
import time

from config import ARQ_AUDITORIA, AUDITORIA_MAX

TRAVA_AUDITORIA = threading.Lock()
ULTIMA_RECUSA = {}


def limpo(texto, tamanho=80):
    """Texto vindo do cliente, reduzido a caracteres que não quebram a linha da auditoria."""
    return re.sub(r'[^A-Za-z0-9_.:/\[\]-]', '?', str(texto))[:tamanho]


def auditar(ip, evento, detalhe=''):
    """Uma linha por evento. Nunca recebe senha, token nem cookie."""
    linha = f'{time.strftime("%Y-%m-%dT%H:%M:%S%z")} ip={ip} evento={evento}' + (f' {detalhe}' if detalhe else '')
    with TRAVA_AUDITORIA:
        if evento.startswith('recusa_'):  # recusa repetida do mesmo IP: uma linha por minuto
            agora = time.monotonic()
            if agora - ULTIMA_RECUSA.get((ip, evento), -60) < 60:
                return
            if len(ULTIMA_RECUSA) > 1000:
                ULTIMA_RECUSA.clear()
            ULTIMA_RECUSA[(ip, evento)] = agora
        try:
            if os.path.exists(ARQ_AUDITORIA) and os.path.getsize(ARQ_AUDITORIA) > AUDITORIA_MAX:
                os.replace(ARQ_AUDITORIA, ARQ_AUDITORIA + '.1')
            descritor = os.open(ARQ_AUDITORIA, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
            with os.fdopen(descritor, 'a', encoding='utf-8') as arq:
                arq.write(linha + '\n')
        except OSError as erro:
            print(f'auditoria indisponível: {erro}', file=sys.stderr, flush=True)
    print(linha, flush=True)


def fim_da_auditoria(limite=6, janela=8192):
    """Os últimos registros, lendo só o fim do arquivo atual: é o que a Visão geral mostra a cada abertura."""
    try:
        with open(ARQ_AUDITORIA, 'rb') as arq:
            inicio = max(0, arq.seek(0, os.SEEK_END) - janela)
            arq.seek(inicio)
            linhas = arq.read().decode('utf-8', 'replace').splitlines()
    except OSError:
        return []
    # Leitura que começou no meio do arquivo: a primeira linha pode estar cortada.
    return (linhas[1:] if inicio else linhas)[-limite:][::-1]


def ler_auditoria(limite=300):
    linhas = []
    for caminho in (ARQ_AUDITORIA + '.1', ARQ_AUDITORIA):
        try:
            with open(caminho, encoding='utf-8', errors='replace') as arq:
                linhas.extend(arq.read().splitlines())
        except OSError:
            continue
    return linhas[-limite:][::-1]
