# SPDX-License-Identifier: Apache-2.0
"""Sessão do painel, limite de tentativas de entrada e token do formulário de entrada."""
import hashlib
import hmac
import secrets
import threading
import time

from config import (CFG, FALHAS_MAX, JANELA_FALHAS, SESSAO_ABSOLUTA, SESSOES_MAX, SESSOES_POR_USUARIO,
                    VALIDADE_FORMULARIO)

CHAVE_PROCESSO = secrets.token_bytes(32)  # assina o formulário de entrada; some ao reiniciar
TRAVA = threading.Lock()
# sha256 do token → {'criada', 'uso', 'csrf', 'ip', 'admin', 'usuario', 'marca', 'pasta'}. A sessão é de um
# administrador ('admin' com o nome, 'usuario' None) ou de um usuário do FTP ('usuario' com o nome, 'admin'
# None, mais a marca e a pasta do cadastro dele na hora da entrada).
SESSOES = {}
FALHAS = {}    # ip → [instantes das falhas]


def resumo_token(token):
    return hashlib.sha256(token.encode()).hexdigest()


def criar_sessao(ip, admin=None, usuario=None, marca=None, pasta=None):
    token = secrets.token_urlsafe(32)
    agora = time.time()
    with TRAVA:
        for chave in [c for c, s in SESSOES.items() if sessao_vencida(s, agora)]:
            del SESSOES[chave]
        if usuario:
            dele = sorted((c for c, s in SESSOES.items() if s['usuario'] == usuario), key=lambda c: SESSOES[c]['uso'])
            for chave in dele[:max(0, len(dele) - SESSOES_POR_USUARIO + 1)]:
                del SESSOES[chave]
        while len(SESSOES) >= SESSOES_MAX:
            # Sai a menos usada, e primeiro a de usuário do FTP: entrada de usuário não derruba administrador.
            candidatas = [c for c, s in SESSOES.items() if s['usuario']] or list(SESSOES)
            del SESSOES[min(candidatas, key=lambda c: SESSOES[c]['uso'])]
        SESSOES[resumo_token(token)] = {'criada': agora, 'uso': agora, 'csrf': secrets.token_urlsafe(32), 'ip': ip,
                                         'admin': admin, 'usuario': usuario, 'marca': marca, 'pasta': pasta}
    return token


def quem(sessao):
    """Dono da sessão, como vai para a auditoria: admin=<nome> ou usuario=<nome>."""
    return f'usuario={sessao["usuario"]}' if sessao['usuario'] else f'admin={sessao["admin"]}'


def sessao_vencida(sessao, agora):
    return agora - sessao['uso'] > CFG['inatividade'] or agora - sessao['criada'] > SESSAO_ABSOLUTA


def buscar_sessao(token, ip):
    agora = time.time()
    with TRAVA:
        chave = resumo_token(token)
        sessao = SESSOES.get(chave)
        if sessao is None:
            return None
        if sessao_vencida(sessao, agora) or sessao['ip'] != ip:
            del SESSOES[chave]
            return None
        sessao['uso'] = agora
        return sessao


def encerrar_sessao(token):
    with TRAVA:
        SESSOES.pop(resumo_token(token), None)


def encerrar_sessoes_de(admin, menos=None):
    """Encerra as sessões de um administrador; `menos` é a sessão que continua (a de quem fez a alteração)."""
    with TRAVA:
        for chave in [c for c, s in SESSOES.items() if s['admin'] and s['admin'] == admin and s is not menos]:
            del SESSOES[chave]


def sessoes_por_admin():
    """Quantas sessões válidas cada administrador tem agora: {nome: quantidade}."""
    agora, conta = time.time(), {}
    with TRAVA:
        for sessao in SESSOES.values():
            if sessao['admin'] and not sessao_vencida(sessao, agora):
                conta[sessao['admin']] = conta.get(sessao['admin'], 0) + 1
    return conta


def renomear_sessoes(antigo, novo):
    with TRAVA:
        for sessao in SESSOES.values():
            if sessao['admin'] and sessao['admin'] == antigo:
                sessao['admin'] = novo


def bloqueado(ip):
    agora = time.time()
    with TRAVA:
        recentes = [t for t in FALHAS.get(ip, ()) if agora - t < JANELA_FALHAS]
        if recentes:
            FALHAS[ip] = recentes
        else:
            FALHAS.pop(ip, None)
        return len(recentes) >= FALHAS_MAX


def registrar_falha(ip):
    with TRAVA:
        if len(FALHAS) > 5000:
            FALHAS.clear()
        FALHAS.setdefault(ip, []).append(time.time())


def token_formulario():
    instante = str(int(time.time()))
    return instante + '.' + hmac.new(CHAVE_PROCESSO, instante.encode(), 'sha256').hexdigest()


def token_formulario_valido(token):
    instante, _, assinatura = str(token).partition('.')
    if not instante.isdigit():
        return False
    esperado = hmac.new(CHAVE_PROCESSO, instante.encode(), 'sha256').hexdigest()
    return hmac.compare_digest(assinatura, esperado) and 0 <= time.time() - int(instante) <= VALIDADE_FORMULARIO
