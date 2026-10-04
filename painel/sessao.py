"""Sessão do painel, limite de tentativas de entrada e token do formulário de entrada."""
import hashlib
import hmac
import secrets
import threading
import time

from config import CFG, FALHAS_MAX, JANELA_FALHAS, SESSAO_ABSOLUTA, SESSOES_MAX, VALIDADE_FORMULARIO

CHAVE_PROCESSO = secrets.token_bytes(32)  # assina o formulário de entrada; some ao reiniciar
TRAVA = threading.Lock()
SESSOES = {}   # sha256 do token → {'criada', 'uso', 'csrf', 'ip'}
FALHAS = {}    # ip → [instantes das falhas]


def resumo_token(token):
    return hashlib.sha256(token.encode()).hexdigest()


def criar_sessao(ip):
    token = secrets.token_urlsafe(32)
    agora = time.time()
    with TRAVA:
        for chave in [c for c, s in SESSOES.items() if sessao_vencida(s, agora)]:
            del SESSOES[chave]
        while len(SESSOES) >= SESSOES_MAX:
            del SESSOES[min(SESSOES, key=lambda c: SESSOES[c]['uso'])]
        SESSOES[resumo_token(token)] = {'criada': agora, 'uso': agora, 'csrf': secrets.token_urlsafe(32), 'ip': ip}
    return token


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
