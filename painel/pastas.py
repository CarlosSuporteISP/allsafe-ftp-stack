# SPDX-License-Identifier: Apache-2.0
"""Outras pastas de cada usuário do FTP no painel web.

Além da pasta do cadastro, que continua só dele, o administrador libera a um usuário outras pastas, cada uma com a
permissão que escolher: leitura, envio ou completo. A lista fica em /auth/pastas.lista, gravada pelo
allsafe-ftp-user, o mesmo comando do terminal, e é lida a cada pedido: conceder, trocar a permissão e retirar valem
no pedido seguinte, com a sessão aberta. Vale só no painel: no FTP a conta continua presa à pasta do cadastro."""
import hashlib
import re

from config import ARQ_PASTAS, PASTA
from estado import perfis, usuarios

PERMISSOES = ('leitura', 'envio', 'completo')
PASTAS_MAX = 20   # o mesmo teto do allsafe-ftp-user
PAR = re.compile(r'([^=\s]+)=(leitura|envio|completo)')


def todas():
    """Usuário ➜ {pasta: permissão} das outras pastas dele. Só entra o que o allsafe-ftp-user gravaria: usuário que
    existe e não é do perfil só envio, pasta no formato das pastas de usuário e diferente da do cadastro dele."""
    cadastro, perfil = usuarios(), perfis()
    concedidas = {}
    try:
        with open(ARQ_PASTAS, encoding='utf-8', errors='replace') as arq:
            for linha in arq:
                nome, _, resto = linha.rstrip('\n').partition(' ')
                if nome not in cadastro or perfil.get(nome) == 'soenvio':
                    continue
                dele = {}
                for par in resto.split():
                    achado = PAR.fullmatch(par)
                    if (achado and PASTA.fullmatch(achado.group(1)) and achado.group(1) != cadastro[nome]
                            and len(dele) < PASTAS_MAX):
                        dele[achado.group(1)] = achado.group(2)
                if dele:
                    concedidas[nome] = dele
    except OSError:
        pass
    return concedidas


def do_usuario(nome):
    return todas().get(nome, {})


def identificador(pasta):
    """Nome da pasta no endereço da tela (/pastas/<identificador>). Não é segredo nem autorização: quem autoriza é
    a lista, conferida a cada pedido pelo usuário da sessão."""
    return hashlib.sha256(pasta.encode()).hexdigest()[:16]


def da_area(nome, area):
    """(pasta, permissão) da outra pasta do usuário que tem este identificador; None se ele não tem nenhuma assim."""
    for pasta, permissao in do_usuario(nome).items():
        if identificador(pasta) == area:
            return pasta, permissao
    return None


def com_acesso(caminho):
    """(usuário, pasta liberada, permissão) de quem alcança este caminho por outra pasta: a liberada é ele, fica acima
    dele ou dentro dele."""
    return [(nome, pasta, permissao) for nome, dele in todas().items() for pasta, permissao in dele.items()
            if pasta == caminho or pasta.startswith(caminho + '/') or caminho.startswith(pasta + '/')]


def presos(caminho):
    """Usuários com outra pasta neste caminho ou dentro dele: trocar o nome da pasta ou apagá-la deixaria a
    liberação apontando para o que não existe."""
    return sorted(nome for nome, dele in todas().items()
                  if any(pasta == caminho or pasta.startswith(caminho + '/') for pasta in dele))
