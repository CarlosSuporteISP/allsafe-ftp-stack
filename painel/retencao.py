# SPDX-License-Identifier: Apache-2.0
"""Limpeza automática: a regra de cada usuário do FTP.

O administrador liga a regra por usuário, e ela vale para a pasta dele e para as de dentro: `ultimos` mantém só os
arquivos mais recentes de cada pasta, e `dias` apaga o arquivo que está há mais dias que isso no servidor. Com as
duas, sai o arquivo que passar de qualquer uma. Sem regra, que é o padrão, nada é apagado.

A regra fica em /auth/limites.lista, gravada pelo allsafe-ftp-user (ação retencao), o mesmo comando do terminal.
Quem a aplica é o módulo limpeza."""
import re

from config import ARQ_LIMITES, NOME
from idioma import t, tn

# chave ➜ maior valor aceito; o menor é 1. Valor fora disso na lista não vale: a regra fica desligada.
TETOS = {'ultimos': 100000, 'dias': 3650}
PAR = re.compile(r'(ultimos|dias)=([1-9]\d{0,5})')


def regras():
    """Usuário ➜ {'ultimos': N, 'dias': N} de quem tem limpeza automática; 0 quer dizer que essa parte não vale."""
    achadas = {}
    try:
        with open(ARQ_LIMITES, encoding='utf-8', errors='replace') as arq:
            for linha in arq:
                nome, _, resto = linha.rstrip('\n').partition(' ')
                if not NOME.fullmatch(nome):
                    continue
                dele = {'ultimos': 0, 'dias': 0}
                for par in resto.split():
                    achado = PAR.fullmatch(par)
                    if achado and int(achado.group(2)) <= TETOS[achado.group(1)]:
                        dele[achado.group(1)] = int(achado.group(2))
                if dele['ultimos'] or dele['dias']:
                    achadas[nome] = dele
    except OSError:
        pass
    return achadas


def ler(nome):
    return regras().get(nome) or {'ultimos': 0, 'dias': 0}


def que_alcancam(cadastro, pasta):
    """As regras que valem para esta pasta: a de cada usuário que tem como pasta ela mesma ou uma acima dela."""
    return [regra for nome, regra in regras().items()
            if cadastro.get(nome) and (pasta == cadastro[nome] or pasta.startswith(cadastro[nome] + '/'))]


def resumo(dele):
    """A regra em uma frase; '' quando a limpeza automática está desligada."""
    partes = []
    if dele['ultimos']:
        partes.append(tn(dele['ultimos'], 'mantém só o arquivo mais recente de cada pasta',
                         'mantém só os {n} arquivos mais recentes de cada pasta'))
    if dele['dias']:
        partes.append(tn(dele['dias'], 'apaga o arquivo com mais de {n} dia', 'apaga o arquivo com mais de {n} dias'))
    return ' · '.join(partes)


def do_formulario(formulario):
    """Confere a regra enviada pela tela. Devolve (valores, erro); os valores vêm na forma de ler()."""
    valores = {'ultimos': 0, 'dias': 0}
    rotulos = {'ultimos': t('arquivos mantidos'), 'dias': t('dias')}
    for chave, maximo in TETOS.items():
        texto = formulario.get(chave, '').strip()
        if not texto:
            continue
        if not (texto.isascii() and texto.isdigit() and len(texto) <= 9 and 1 <= int(texto) <= maximo):
            return None, t('Valor inválido em "{campo}": deixe vazio ou use um número inteiro de 1 a {maximo}.',
                           campo=rotulos[chave], maximo=maximo)
        valores[chave] = int(texto)
    return valores, ''


def pares(valores):
    """Os argumentos do allsafe-ftp-user retencao: as duas chaves vão sempre, e a vazia desliga aquela parte."""
    return [f'{chave}={valores[chave] or ""}' for chave in TETOS]
