"""Senha do painel: hash scrypt, conferido em tempo constante."""
import base64
import hashlib
import hmac
import secrets
import threading

from config import ARQ_HASH, SCRYPT_LOG_N, SCRYPT_MAXMEM, SCRYPT_P, SCRYPT_R


def b64(dados):
    return base64.b64encode(dados).decode()


def gerar_hash(senha):
    sal = secrets.token_bytes(16)
    resumo = hashlib.scrypt(senha.encode(), salt=sal, n=2 ** SCRYPT_LOG_N, r=SCRYPT_R, p=SCRYPT_P,
                            maxmem=SCRYPT_MAXMEM, dklen=32)
    return f'scrypt${SCRYPT_LOG_N}${SCRYPT_R}${SCRYPT_P}${b64(sal)}${b64(resumo)}'


def ler_hash():
    """Devolve (log_n, r, p, sal, resumo) do segredo, ou None se o arquivo não serve."""
    try:
        with open(ARQ_HASH, encoding='ascii') as arq:
            campos = arq.read().strip().split('$')
        if len(campos) != 6 or campos[0] != 'scrypt':
            return None
        log_n, r, p = int(campos[1]), int(campos[2]), int(campos[3])
        sal, resumo = base64.b64decode(campos[4], validate=True), base64.b64decode(campos[5], validate=True)
        if not (14 <= log_n <= 17 and r == 8 and 1 <= p <= 2 and len(sal) >= 16 and len(resumo) == 32):
            return None
        return log_n, r, p, sal, resumo
    except (OSError, ValueError):
        return None


TRAVA_SCRYPT = threading.Lock()  # um cálculo por vez: cada um usa 32 MiB


def senha_confere(senha):
    guardado = ler_hash()
    if guardado is None:
        return False
    log_n, r, p, sal, resumo = guardado
    with TRAVA_SCRYPT:
        calculado = hashlib.scrypt(senha.encode(), salt=sal, n=2 ** log_n, r=r, p=p,
                                   maxmem=SCRYPT_MAXMEM, dklen=len(resumo))
    return hmac.compare_digest(calculado, resumo)
