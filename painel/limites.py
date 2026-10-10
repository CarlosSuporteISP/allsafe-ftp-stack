# SPDX-License-Identifier: Apache-2.0
"""Limites próprios de cada usuário do FTP.

Sessões, taxas e horário ficam no cadastro do Pure-FTPd, que é quem os aplica. Em /auth/limites.lista ficam
o de downloads ao mesmo tempo pelo painel, que o painel aplica, e os do bloqueio por tentativa no FTP
(senhas erradas até o bloqueio e minutos de bloqueio), que o vigia do serviço ftp aplica. Todos são gravados
pelo allsafe-ftp-user, o mesmo comando do terminal. Sem limite próprio, vale o da stack."""
import re

from config import ARQ_LIMITES, ARQ_USUARIOS, CFG, DOWNLOADS_MAX, DOWNLOADS_POR_USUARIO, NOME
from idioma import N, t

# chave ➜ (posição no cadastro, unidade em que o cadastro guarda, maior valor aceito). O teto de `sessoes`
# é o FTP_MAX_CLIENTS em vigor e o de `baixar`, o DOWNLOADS_MAX: os dois são resolvidos em teto().
NUMEROS = {
    'sessoes': (10, 1, 0),
    'download': (7, 1024, 10_000_000),
    'envio': (6, 1024, 10_000_000),
}
POSICAO_HORARIO = 17
# chave ➜ (menor, maior valor aceito) dos limites que ficam em /auth/limites.lista. Em `tentativas`, 0 quer
# dizer que o usuário nunca é bloqueado por senha errada.
DA_LISTA = {'baixar': (1, DOWNLOADS_MAX), 'tentativas': (0, 100), 'minutos': (1, 1440)}
CHAVES = ('sessoes', 'download', 'envio', 'horario', 'baixar', 'tentativas', 'minutos')
ROTULOS = {'sessoes': N('sessões no FTP'), 'download': N('download em KB/s'), 'envio': N('envio em KB/s'),
           'horario': N('horário'), 'baixar': N('downloads pelo painel'), 'tentativas': N('senhas erradas até o bloqueio'),
           'minutos': N('minutos de bloqueio')}
# O pure-pw grava o horário sem os zeros da esquerda: 0800-1800 fica 800-1800 e 0000-0600, 0-600.
HORARIO = re.compile(r'(\d{1,4})-(\d{1,4})')
HHMM = re.compile(r'(?:[01]\d|2[0-3])[0-5]\d')
HORA = re.compile(r'(?:[01]\d|2[0-3]):[0-5]\d')
PAR = re.compile(r'(baixar|tentativas|minutos)=(0|[1-9]\d{0,5})')


def teto(chave):
    if chave == 'sessoes':
        return int(CFG['ftp_clientes'])
    return DA_LISTA[chave][1] if chave in DA_LISTA else NUMEROS[chave][2]


def piso(chave):
    return DA_LISTA[chave][0] if chave in DA_LISTA else 1


def todos():
    """Usuário ➜ limites dele. Em cada um, chave ➜ inteiro, ou '' quando vale o da stack; `horario` é
    'HHMM-HHMM' ou ''. Do cadastro só saem os campos dos limites; o hash da senha nunca sai daqui."""
    limites = {}
    try:
        with open(ARQ_USUARIOS, encoding='utf-8', errors='replace') as arq:
            for linha in arq:
                campos = linha.rstrip('\n').split(':')
                if len(campos) <= 5 or not NOME.fullmatch(campos[0]):
                    continue
                dele = dict.fromkeys(CHAVES, '')
                for chave, (posicao, unidade, _) in NUMEROS.items():
                    bruto = campos[posicao] if len(campos) > posicao else ''
                    if bruto.isascii() and bruto.isdigit() and int(bruto) >= unidade:
                        dele[chave] = int(bruto) // unidade
                achado = HORARIO.fullmatch(campos[POSICAO_HORARIO] if len(campos) > POSICAO_HORARIO else '')
                if achado:
                    inicio, fim = (f'{int(parte):04d}' for parte in achado.groups())
                    if HHMM.fullmatch(inicio) and HHMM.fullmatch(fim):
                        dele['horario'] = f'{inicio}-{fim}'
                limites[campos[0]] = dele
    except OSError:
        pass
    try:
        with open(ARQ_LIMITES, encoding='utf-8', errors='replace') as arq:
            for linha in arq:
                nome, _, resto = linha.rstrip('\n').partition(' ')
                if nome in limites:
                    for par in resto.split():
                        achado = PAR.fullmatch(par)
                        if achado and piso(achado.group(1)) <= int(achado.group(2)) <= teto(achado.group(1)):
                            limites[nome][achado.group(1)] = int(achado.group(2))
    except OSError:
        pass
    return limites


def ler(nome):
    return todos().get(nome) or dict.fromkeys(CHAVES, '')


def downloads_e_taxa(nome):
    """O que vale para os downloads do usuário pelo painel: quantos ao mesmo tempo e a taxa em KB/s (0 = sem teto)."""
    dele = ler(nome)
    return dele['baixar'] or DOWNLOADS_POR_USUARIO, dele['download'] or 0


def resumo(dele):
    """Os limites próprios em uma frase, para a lista de usuários; '' quando não há nenhum."""
    partes = []
    for chave in CHAVES:
        if dele[chave] != '':
            if chave == 'horario':
                valor = t('{inicio} às {fim}', inicio=f'{dele[chave][:2]}:{dele[chave][2:4]}', fim=f'{dele[chave][5:7]}:{dele[chave][7:]}')
            elif chave == 'tentativas' and dele[chave] == 0:
                valor = t('nunca bloqueia')
            else:
                valor = dele[chave]
            partes.append(f'{t(ROTULOS[chave])}: {valor}')
    return ' · '.join(partes)


def do_formulario(formulario):
    """Confere os limites enviados pela tela. Devolve (valores, erro); os valores vêm na forma de ler()."""
    valores = dict.fromkeys(CHAVES, '')
    for chave in ('sessoes', 'download', 'envio', 'baixar', 'tentativas', 'minutos'):
        texto = formulario.get(chave, '').strip()
        if not texto:
            continue
        minimo, maximo = piso(chave), teto(chave)
        if not (texto.isascii() and texto.isdigit() and len(texto) <= 9 and minimo <= int(texto) <= maximo):
            return None, t('Limite inválido em "{limite}": deixe vazio ou use um número inteiro de {minimo} a {maximo}.',
                           limite=t(ROTULOS[chave]), minimo=minimo, maximo=maximo)
        valores[chave] = int(texto)
    inicio, fim = formulario.get('inicio', '').strip(), formulario.get('fim', '').strip()
    if inicio or fim:
        if not (HORA.fullmatch(inicio) and HORA.fullmatch(fim)):
            return None, t('Horário inválido: preencha o início e o fim, no formato HH:MM, ou deixe os dois vazios.')
        if inicio == fim:
            return None, t('Horário inválido: o início e o fim não podem ser iguais.')
        valores['horario'] = f'{inicio[:2]}{inicio[3:]}-{fim[:2]}{fim[3:]}'
    return valores, ''


def pares(valores):
    """Os limites na forma que o allsafe-ftp-user recebe: um `chave=valor` por limite; valor vazio tira o limite."""
    return [f'{chave}={valores[chave]}' for chave in CHAVES]
