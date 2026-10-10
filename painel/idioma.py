# SPDX-License-Identifier: Apache-2.0
"""Idioma das telas: português, que é o padrão, ou inglês. Cada conta escolhe o seu.

O texto em português é a chave: `t('Entrar')` devolve o próprio texto ou, com o pedido em inglês, a tradução do
catálogo (idioma_en.py). Texto sem tradução sai em português. O idioma vale para o pedido em atendimento: cada
pedido tem a sua linha de execução, e é nela que ele fica guardado.

A escolha de cada conta fica em /painel/idiomas, uma linha por conta (`admin:<nome>:<idioma>` ou
`usuario:<nome>:<idioma>`). Antes da entrada não há conta: a tela de entrada segue o cookie do navegador.

Só as telas mudam de idioma. O registro da auditoria, as mensagens do terminal e as do FTP continuam como são.
"""
import os
import re
import threading

from idioma_en import COMANDO, EN

IDIOMAS = ('pt', 'en')
PADRAO = 'pt'
# Idioma ➜ (o que o botão mostra, o nome por extenso, na própria língua, e o valor de `lang` do nome).
NOMES = {'pt': ('PT', 'Português', 'pt-BR'), 'en': ('EN', 'English', 'en')}
ARQ_IDIOMAS = '/painel/idiomas'
LINHA = re.compile(r'(admin|usuario):([a-z_][a-z0-9_-]{0,31}):(pt|en)')
COOKIE = re.compile(r'__Host-idioma=(pt|en)')
TRAVA = threading.Lock()
DO_PEDIDO = threading.local()


def usar(idioma):
    """Define o idioma do pedido em atendimento; valor desconhecido é o padrão."""
    DO_PEDIDO.idioma = idioma if idioma in IDIOMAS else PADRAO


def atual():
    return getattr(DO_PEDIDO, 'idioma', PADRAO)


def t(texto, /, **valores):
    """O texto no idioma do pedido. Os valores entram pelos nomes entre chaves e já vêm prontos para o HTML."""
    if atual() == 'en':
        texto = EN.get(texto, texto)
    return texto.format(**valores) if valores else texto


def tn(quantos, um, varios, /, **valores):
    """Como t(), para texto que muda com a quantidade: `um` quando é 1, `varios` nos demais; a quantidade é `{n}`."""
    return t(um if quantos == 1 else varios, n=quantos, **valores)


def N(texto):
    """Marca o texto de uma constante de módulo: ele entra no catálogo e é traduzido com t() na hora de montar a tela."""
    return texto


def do_comando(mensagem):
    """Mensagem de erro que veio do allsafe-ftp-user, que fala português: em inglês, a que o catálogo conhece sai
    traduzida. As duas que o próprio painel escreve no lugar dele estão no catálogo comum."""
    if atual() == 'en':
        if mensagem in EN:
            return EN[mensagem]
        for regra, ingles in COMANDO:
            achado = regra.fullmatch(mensagem)
            if achado:
                return achado.expand(ingles)
    return mensagem


def formato_da_data():
    return '%Y-%m-%d' if atual() == 'en' else '%d/%m/%Y'


def dia_e_mes(ano, mes, dia):
    """A data por extenso e a curta, só com dia e mês, de três textos já com os zeros."""
    return (f'{ano}-{mes}-{dia}', f'{mes}-{dia}') if atual() == 'en' else (f'{dia}/{mes}/{ano}', f'{dia}/{mes}')


def decimal(texto):
    """Número já escrito com ponto decimal, com o separador do idioma."""
    return texto if atual() == 'en' else texto.replace('.', ',')


def milhar(valor):
    """Inteiro com o separador de milhar do idioma."""
    return f'{valor:,}' if atual() == 'en' else f'{valor:,}'.replace(',', '.')


def da_pagina():
    """Valor de `lang` da página."""
    return NOMES[atual()][2]


# ------------------------------------------------------------ cookie da tela de entrada

def do_cookie(cabecalho):
    """Idioma pedido pelo navegador que ainda não entrou, ou None."""
    for parte in cabecalho.split(';'):
        achado = COOKIE.fullmatch(parte.strip())
        if achado:
            return achado.group(1)
    return None


def cookie(idioma):
    return f'__Host-idioma={idioma}; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=31536000'


# ------------------------------------------------------------ escolha de cada conta

def escolhas():
    """(tipo, nome) ➜ idioma, das contas que já escolheram. Linha fora do formato é ignorada."""
    achadas = {}
    try:
        with open(ARQ_IDIOMAS, encoding='ascii', errors='replace') as arq:
            for linha in arq:
                achado = LINHA.fullmatch(linha.rstrip('\n'))
                if achado:
                    achadas[achado.group(1), achado.group(2)] = achado.group(3)
    except OSError:
        pass
    return achadas


def escolha(tipo, nome):
    """Idioma que a conta escolheu, ou None se ela nunca escolheu."""
    return escolhas().get((tipo, nome))


def alterar(funcao):
    """Lê, aplica `funcao(escolhas)` e grava em arquivo ao lado, trocado de uma vez. Devolve se gravou."""
    with TRAVA:
        achadas = escolhas()
        funcao(achadas)
        provisorio = ARQ_IDIOMAS + '.novo'
        try:
            descritor = os.open(provisorio, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            with os.fdopen(descritor, 'w', encoding='ascii') as arq:
                arq.write(''.join(f'{tipo}:{nome}:{idioma}\n' for (tipo, nome), idioma in sorted(achadas.items())))
                arq.flush()
                os.fsync(arq.fileno())
            os.chmod(provisorio, 0o600)
            os.replace(provisorio, ARQ_IDIOMAS)
        except OSError:
            return False
    return True


def escolher(tipo, nome, idioma, contas):
    """Grava a escolha da conta. `contas` são os pares (tipo, nome) que existem agora: a escolha de quem saiu do
    cadastro some junto, e uma conta nova com o mesmo nome não herda o idioma da antiga."""
    def aplicar(achadas):
        for par in [par for par in achadas if par not in contas]:
            del achadas[par]
        achadas[tipo, nome] = idioma
    return idioma in IDIOMAS and alterar(aplicar)


def esquecer(tipo, nome):
    """Conta removida: a escolha dela sai do arquivo. Sem escolha gravada, nada é escrito."""
    if (tipo, nome) in escolhas():
        alterar(lambda achadas: achadas.pop((tipo, nome), None))


def renomear(tipo, antigo, novo):
    """Conta que trocou de nome leva a escolha junto."""
    def aplicar(achadas):
        idioma = achadas.pop((tipo, antigo), None)
        if idioma:
            achadas[tipo, novo] = idioma
    if (tipo, antigo) in escolhas():
        alterar(aplicar)
