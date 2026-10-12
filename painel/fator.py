# SPDX-License-Identifier: Apache-2.0
"""Segundo fator da entrada do painel: código de aplicativo autenticador (TOTP, RFC 6238).

Só na web: depois de usuário e senha, o painel pede o código de seis dígitos que o aplicativo mostra. O FTP não
muda, porque o protocolo não tem onde pedir o código. Com PAINEL_SEGUNDO_FATOR_OBRIGATORIO=sim, toda conta que
entra no painel tem o dela, administrador e usuário do FTP, e quem ainda não cadastrou cadastra na entrada
(entrada.py); com nao, cada administrador liga o dele, se quiser. Quem perde o aparelho pede a um administrador
para desligar, ou usa `servidor.py --segundo-fator`.

A conta do fator é o nome do administrador ou, para o usuário do FTP, `ftp.` mais o nome dele: o ponto não cabe
em nome nenhum, e por isso as duas nunca se confundem, nem quando um administrador e um usuário do FTP têm o
mesmo nome.

Duas coisas guardadas, em lugares diferentes. Quem está com o fator ligado fica em /painel/segundo-fator, uma
conta por linha, junto dos dados do painel e dentro da cópia de segurança. O segredo de cada uma fica em
/segundo-fator/<conta>.txt, que vem de SECRETS_DIR/segundo-fator e não entra na cópia. Restaurada a cópia sem os
segredos, a conta continua pedindo o código e não entra até o fator ser desligado: a falta do segredo fecha, não abre.

O código é o padrão que os aplicativos leem: SHA-1, seis dígitos, passo de 30 segundos. Vale o do passo atual e
o dos dois vizinhos, para relógio um pouco fora, e cada código vale uma vez só."""
import base64
import contextlib
import hashlib
import hmac
import os
import re
import secrets
import struct
import threading
import time
import urllib.parse

from config import ARQ_FATOR, FATOR_ERROS_MAX, JANELA_FALHAS, NOME, PASTA_FATOR

EMISSOR = 'AllSafe FTP'
PASSO, DIGITOS, FOLGA = 30, 6, 1
ENDERECO_MAX = 213                  # o que cabe no código QR do painel (qr.py)
SEGREDO = re.compile(r'[A-Z2-7]{32}')    # 160 bits em base32
CODIGO = re.compile(r'[0-9]{6}')
DO_FTP = 'ftp.'                          # começo da conta do fator de um usuário do FTP
CONTA = re.compile(r'(ftp\.)?' + NOME.pattern)
TRAVA = threading.Lock()
USADOS = {}    # conta → contador do último código aceito: o mesmo código não entra duas vezes
ERROS = {}     # conta → [instantes dos códigos recusados]


def novo_segredo():
    return base64.b32encode(secrets.token_bytes(20)).decode()


def codigo_de(segredo, contador):
    resumo = hmac.new(base64.b32decode(segredo), struct.pack('>Q', contador), hashlib.sha1).digest()
    inicio = resumo[-1] & 15
    valor = struct.unpack('>I', resumo[inicio:inicio + 4])[0] & 0x7FFFFFFF
    return f'{valor % 10 ** DIGITOS:0{DIGITOS}d}'


def contador_do(segredo, texto, agora=None):
    """O contador (o passo de 30 segundos) a que o código pertence, ou None quando ele não é o de agora nem o de um
    vizinho. Espaço no meio do código é aceito: é como o aplicativo mostra."""
    texto = re.sub(r'\s', '', str(texto))
    if not CODIGO.fullmatch(texto) or not SEGREDO.fullmatch(segredo):
        return None
    atual, achado = int((agora or time.time()) // PASSO), None
    for contador in range(atual - FOLGA, atual + FOLGA + 1):
        if hmac.compare_digest(codigo_de(segredo, contador), texto):
            achado = contador
    return achado


def endereco(nome, segredo, lugar=''):
    """O endereço `otpauth://` que o aplicativo lê. `lugar` é o nome do servidor, para quem tem mais de uma
    instalação no mesmo aplicativo; fica de fora quando o endereço passaria do que o código QR do painel leva."""
    def montar(conta):
        return (f'otpauth://totp/{urllib.parse.quote(f"{EMISSOR}:{conta}")}?secret={segredo}'
                f'&issuer={urllib.parse.quote(EMISSOR)}')
    completo = montar(f'{nome}@{lugar}') if lugar else ''
    return completo if completo and len(completo) <= ENDERECO_MAX else montar(nome)


# ------------------------------------------------------------ o que fica guardado

def caminho(nome):
    return os.path.join(PASTA_FATOR, nome + '.txt')


def do_usuario(nome):
    """A conta do fator de um usuário do FTP."""
    return DO_FTP + nome


def ligados():
    """As contas que estão com o segundo fator ligado. Linha fora da regra de conta é ignorada."""
    try:
        with open(ARQ_FATOR, encoding='ascii', errors='replace') as arq:
            return {linha for linha in arq.read().splitlines() if CONTA.fullmatch(linha)}
    except OSError:
        return set()


def ligado(nome):
    return nome in ligados()


def segredo_de(nome):
    """O segredo guardado da conta, ou '' quando falta, não é um arquivo comum ou não tem o formato."""
    try:
        descritor = os.open(caminho(nome), os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK)
    except OSError:
        return ''
    try:
        texto = os.read(descritor, 64).decode('ascii', 'replace').strip()
    except OSError:
        return ''
    finally:
        os.close(descritor)
    return texto if SEGREDO.fullmatch(texto) else ''


def gravar_texto(caminho_do_arquivo, texto, dono=None):
    """Grava em arquivo ao lado e troca de uma vez, com modo 0600. `dono` é (uid, gid) para o arquivo do host."""
    provisorio = caminho_do_arquivo + '.novo'
    descritor = os.open(provisorio, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600)
    with os.fdopen(descritor, 'w', encoding='ascii') as arq:
        arq.write(texto)
        arq.flush()
        os.fchmod(arq.fileno(), 0o600)
        if dono:
            os.fchown(arq.fileno(), *dono)
        os.fsync(arq.fileno())
    os.replace(provisorio, caminho_do_arquivo)


def apagar(caminho_do_arquivo):
    with contextlib.suppress(FileNotFoundError):
        os.unlink(caminho_do_arquivo)


def gravar_lista(nomes):
    gravar_texto(ARQ_FATOR, ''.join(f'{nome}\n' for nome in sorted(nomes)))


def ligar(nome, segredo, contador, so_novo=False):
    """Grava o segredo e põe a conta na lista. `contador` é o do código que provou a leitura: ele não entra de novo.
    `so_novo` é o cadastro feito na entrada, por quem só provou a senha: conta que já tem fator não é regravada, e
    a resposta é False."""
    with TRAVA:
        if so_novo and nome in ligados():
            return False
        # A pasta é do host: o arquivo fica com o dono dela, para quem instalou poder guardar e apagar os segredos.
        pasta = os.stat(PASTA_FATOR)
        gravar_texto(caminho(nome), segredo + '\n', (pasta.st_uid, pasta.st_gid))
        gravar_lista(ligados() | {nome})
        USADOS[nome] = contador
        ERROS.pop(nome, None)
        return True


def desligar(nome):
    """Tira a conta da lista e apaga o segredo. Devolve se o fator estava ligado."""
    with TRAVA:
        nomes = ligados()
        if nome in nomes:
            gravar_lista(nomes - {nome})
        apagar(caminho(nome))
        USADOS.pop(nome, None)
        ERROS.pop(nome, None)
        return nome in nomes


def esquecer_usuario(nome):
    """O usuário do FTP foi criado ou removido pelo painel: o fator que houver com o nome dele sai. Falha de disco
    não desfaz a alteração do usuário: a sobra fecha (a conta pede um código que ninguém tem) e sai com o
    desligamento, pela aba Usuários ou pelo terminal."""
    with contextlib.suppress(OSError):
        desligar(do_usuario(nome))


def renomear(antigo, novo):
    """O administrador trocou de nome: o fator e o segredo vão junto."""
    with TRAVA:
        nomes = ligados()
        apagar(caminho(novo))
        if antigo in nomes:
            with contextlib.suppress(FileNotFoundError):
                os.replace(caminho(antigo), caminho(novo))
            gravar_lista(nomes - {antigo} | {novo})
        else:
            apagar(caminho(antigo))
            if novo in nomes:
                gravar_lista(nomes - {novo})
        for guardado in (USADOS, ERROS):
            if antigo in guardado:
                guardado[novo] = guardado.pop(antigo)


# ------------------------------------------------------------ conferência na entrada

def conferir(nome, texto):
    """Confere o código digitado na entrada. Devolve '' quando ele vale, ou o motivo da recusa: 'pausa' (códigos
    recusados demais nesta conta, de qualquer endereço), 'segredo' (o fator está ligado e o segredo não está no
    servidor) ou 'codigo' (não confere, ou já foi usado)."""
    agora = time.time()
    with TRAVA:
        recentes = [instante for instante in ERROS.get(nome, ()) if agora - instante < JANELA_FALHAS]
        if recentes:
            ERROS[nome] = recentes
        else:
            ERROS.pop(nome, None)
        if len(recentes) >= FATOR_ERROS_MAX:
            return 'pausa'
        segredo = segredo_de(nome)
        if not segredo:
            return 'segredo'
        contador = contador_do(segredo, texto, agora)
        if contador is None or contador <= USADOS.get(nome, 0):
            ERROS.setdefault(nome, []).append(agora)
            return 'codigo'
        USADOS[nome] = contador
        ERROS.pop(nome, None)
        return ''
