"""Administradores do painel: nome e hash scrypt da senha de cada um, em /painel/administradores.

Uma linha por administrador, `nome:hash`. O arquivo nasce na primeira subida, com o nome de
PAINEL_ADMIN_USER e o hash do segredo da instalação; depois disso quem manda é ele, alterado pela
aba Administradores ou por scripts/painel-senha.sh. A senha em texto nunca é gravada."""
import os
import threading

from config import ADMINS_MAX, ARQ_ADMINS, NOME
from senha import analisar_hash

TRAVA_ADMINS = threading.Lock()


def ler():
    """Devolve {nome: hash}, na ordem do arquivo. Linha que não serve é ignorada."""
    admins = {}
    try:
        with open(ARQ_ADMINS, encoding='ascii') as arq:
            for linha in arq.read().splitlines():
                nome, _, guardado = linha.partition(':')
                if NOME.fullmatch(nome) and analisar_hash(guardado) and len(admins) < ADMINS_MAX:
                    admins.setdefault(nome, guardado)
    except (OSError, ValueError):
        pass
    return admins


def gravar(admins):
    """Grava em arquivo ao lado e troca de uma vez: uma queda no meio não deixa o painel sem administrador."""
    provisorio = ARQ_ADMINS + '.novo'
    descritor = os.open(provisorio, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(descritor, 'w', encoding='ascii') as arq:
        arq.write(''.join(f'{nome}:{guardado}\n' for nome, guardado in admins.items()))
        arq.flush()
        os.fsync(arq.fileno())
    os.chmod(provisorio, 0o600)
    os.replace(provisorio, ARQ_ADMINS)


def alterar(funcao):
    """Lê, aplica `funcao(admins)` e grava, um por vez. `funcao` devolve o texto do erro ou '' para gravar."""
    with TRAVA_ADMINS:
        admins = ler()
        erro = funcao(admins)
        if not erro:
            gravar(admins)
        return erro


def iniciar(nome, guardado):
    """Primeira subida: sem nenhum administrador, cria o inicial. Devolve True se criou."""
    with TRAVA_ADMINS:
        if ler():
            return False
        gravar({nome: guardado})
        return True


def definir(nome, guardado):
    """Cria o administrador ou troca a senha dele (uso de scripts/painel-senha.sh). Devolve 'criado' ou 'alterado'."""
    feito = []

    def aplicar(admins):
        if nome not in admins and len(admins) >= ADMINS_MAX:
            return f'limite de {ADMINS_MAX} administradores atingido'
        feito.append('alterado' if nome in admins else 'criado')
        admins[nome] = guardado
        return ''
    erro = alterar(aplicar)
    return (feito[0], '') if not erro else ('', erro)
