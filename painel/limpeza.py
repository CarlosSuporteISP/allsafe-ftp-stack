# SPDX-License-Identifier: Apache-2.0
"""Limpeza automática: aplica a regra de cada usuário (retencao.py) na pasta dele, de tempos em tempos.

Roda numa linha de execução do próprio painel, a cada PAINEL_RETENCAO_MINUTOS, e também pelo terminal
(servidor.py --retencao, com --simular para só contar). A pasta do usuário é aberta sem seguir link simbólico e
percorrida pelo descritor dela, como na aba Arquivos: o que foi conferido é o que é apagado.

Só sai arquivo comum. Ficam como estão o link simbólico, tudo o que tem o nome começado por ponto (arquivo ou
pasta), a área de entrada e o que está em outro sistema de arquivos montado dentro da pasta. `ultimos` conta os
arquivos de cada pasta, pela data de modificação; `dias` olha a data mais nova entre a de modificação e a de
mudança no servidor, para o arquivo que chegou hoje com data antiga não sair no mesmo dia. Subpasta que a limpeza
esvaziou sai junto; a pasta do usuário nunca sai."""
import heapq
import os
import threading
import time

import retencao
from aba_arquivos import ABRIR, Recusado, abrir, partes
from auditoria import auditar, limpo
from config import APAGAR_NIVEIS, CFG
from estado import limpar_cache, usuarios

LOTE = 1000         # arquivos apagados de cada vez; entre um lote e outro a limpeza dá uma pausa
PAUSA = 0.05        # segundos da pausa: o disco e os pedidos do painel seguem atendidos
SUBPASTAS = 10000   # subpastas percorridas em cada pasta, por passada
ESPERA = 120        # segundos entre a partida do painel e a primeira passada


def soltar(descritor, saem, conta, simular):
    """Apaga os arquivos do lote, pelo descritor da pasta deles, e soma o que saiu."""
    for nome, tamanho in saem:
        if not simular:
            try:
                os.unlink(nome, dir_fd=descritor)
            except FileNotFoundError:
                continue  # saiu pelo FTP no meio da limpeza
            except OSError:
                conta['erros'] += 1
                continue
        conta['arquivos'] += 1
        conta['bytes'] += tamanho
    saem.clear()
    if not simular:
        time.sleep(PAUSA)


def limpar_pasta(descritor, regra, antes_de, conta, simular, nivel=0):
    """Aplica a regra nesta pasta e nas de dentro. Devolve se alguma coisa saiu daqui: é quando vale tentar
    apagar a própria pasta, que só sai se tiver ficado vazia."""
    ultimos = regra['ultimos']
    recentes, saem, pastas = [], [], []
    antes = conta['arquivos']
    with os.scandir(descritor) as itens:
        for item in itens:
            if item.name.startswith('.'):
                continue
            try:
                if item.is_dir(follow_symlinks=False):
                    if len(pastas) < SUBPASTAS:
                        pastas.append(item.name)
                    continue
                if not item.is_file(follow_symlinks=False):
                    continue
                dados = item.stat(follow_symlinks=False)
            except OSError:
                continue
            if antes_de and max(dados.st_mtime, dados.st_ctime) < antes_de:
                saem.append((item.name, dados.st_size))
            elif ultimos:
                # O monte guarda os `ultimos` mais novos vistos até aqui; o que ele devolve é mais antigo que todos eles.
                novo = (dados.st_mtime_ns, item.name, dados.st_size)
                if len(recentes) < ultimos:
                    heapq.heappush(recentes, novo)
                else:
                    _, nome, tamanho = heapq.heappushpop(recentes, novo)
                    saem.append((nome, tamanho))
            if len(saem) >= LOTE:
                soltar(descritor, saem, conta, simular)
    soltar(descritor, saem, conta, simular)
    saiu = conta['arquivos'] > antes
    if nivel + 1 >= APAGAR_NIVEIS:
        return saiu
    aparelho = os.fstat(descritor).st_dev
    for nome in pastas:
        try:
            dentro = os.open(nome, ABRIR | os.O_DIRECTORY, dir_fd=descritor)
        except OSError:
            continue  # saiu pelo FTP, ou deu lugar a um link simbólico
        try:
            esvaziar = (os.fstat(dentro).st_dev == aparelho
                        and limpar_pasta(dentro, regra, antes_de, conta, simular, nivel + 1))
        finally:
            os.close(dentro)
        if esvaziar and not simular:
            try:
                os.rmdir(nome, dir_fd=descritor)
            except OSError:
                continue  # ainda tem arquivo dentro
            conta['pastas'] += 1
            saiu = True
    return saiu


def passada(simular=False):
    """Aplica a regra de cada usuário que tem uma. Devolve [(usuário, pasta, regra, o que saiu)]; o que saiu é
    None quando a pasta não pôde ser aberta. Com `simular`, nada é apagado: só é contado o que sairia."""
    cadastro = usuarios()
    feitas, vistas = [], set()
    for nome, regra in sorted(retencao.regras().items()):
        pasta = cadastro.get(nome)
        marca = (pasta, regra['ultimos'], regra['dias'])
        if not pasta or marca in vistas:
            continue  # sem pasta dentro dos dados, ou a mesma pasta com a mesma regra por outro usuário
        vistas.add(marca)
        conta = {'arquivos': 0, 'pastas': 0, 'bytes': 0, 'erros': 0}
        try:
            descritor = abrir(partes(pasta), True)
        except Recusado:
            feitas.append((nome, pasta, regra, None))
            continue
        try:
            limpar_pasta(descritor, regra, time.time() - regra['dias'] * 86400 if regra['dias'] else 0, conta, simular)
        except OSError:
            conta['erros'] += 1
        finally:
            os.close(descritor)
        feitas.append((nome, pasta, regra, conta))
        if not simular and (conta['arquivos'] or conta['pastas'] or conta['erros']):
            limpar_cache()
            auditar('-', 'retencao_aplicada',
                    f'usuario={nome} pasta={limpo(pasta, 200)} arquivos={conta["arquivos"]} pastas={conta["pastas"]} '
                    f'bytes={conta["bytes"]} erros={conta["erros"]} ultimos={regra["ultimos"] or "-"} '
                    f'dias={regra["dias"] or "-"}')
    return feitas


def rodar():
    time.sleep(ESPERA)
    while True:
        try:
            passada()
        except Exception as motivo:  # uma passada que falha não acaba com as seguintes
            auditar('-', 'retencao_falhou', f'motivo={type(motivo).__name__}')
        time.sleep(CFG['retencao_minutos'] * 60)


def iniciar():
    """Começa as passadas. Só o servidor do painel chama; com PAINEL_RETENCAO_MINUTOS=0, nenhuma regra é aplicada."""
    if CFG['retencao_minutos']:
        threading.Thread(target=rodar, name='limpeza', daemon=True).start()
