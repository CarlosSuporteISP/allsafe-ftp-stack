"""Conta de usuário do FTP no painel: o cadastro dele e a conferência da senha.

Quem confere a senha é o próprio servidor FTP, pela rede interna da stack: o painel não lê o hash do
cadastro nem refaz a conta dele. A conversa vai em TLS, com o certificado do servidor conferido contra a
parte pública que o serviço ftp deixa em /auth; só com FTP_TLS_MODE=0, em que o servidor não tem TLS, ela
vai em texto puro, e ainda assim não sai da rede interna da stack."""
import ftplib
import hashlib
import hmac
import ssl
import threading

import administradores
from config import ARQ_CERT_FTP, ARQ_USUARIOS, CFG, CONFERENCIAS_FTP, ESPERA_FTP, NOME, TEMPO_FTP
from estado import pasta_do_cadastro

VEZ = threading.BoundedSemaphore(CONFERENCIAS_FTP)


def cadastro(nome):
    """Marca e pasta do usuário no cadastro do FTP, ou None se ele não existe ou a pasta não serve.
    A marca é o resumo da linha inteira: muda quando a senha, a pasta ou qualquer outro campo muda."""
    try:
        with open(ARQ_USUARIOS, encoding='utf-8', errors='replace') as arq:
            for linha in arq:
                campos = linha.rstrip('\n').split(':')
                if len(campos) > 5 and campos[0] == nome:
                    pasta = pasta_do_cadastro(campos[5])
                    return (hashlib.sha256(linha.rstrip('\n').encode()).digest(), pasta) if pasta else None
    except OSError:
        pass
    return None


def certificado_esperado():
    with open(ARQ_CERT_FTP, encoding='ascii') as arq:
        return ssl.PEM_cert_to_DER_cert(arq.read().strip())


def senha_aceita(nome, senha):
    """Entra no servidor FTP com o nome e a senha e sai em seguida. True = o servidor aceitou; False = recusou;
    None = não foi possível conferir (servidor fora do ar, lotado, sem resposta ou com outro certificado)."""
    if not VEZ.acquire(timeout=ESPERA_FTP):
        return None
    conexao = None
    try:
        if CFG['ftp_tls'] == '0':
            conexao = ftplib.FTP(timeout=TEMPO_FTP)
            conexao.connect(CFG['ftp_host'], 2121)
        else:
            esperado = certificado_esperado()
            contexto = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
            contexto.minimum_version = ssl.TLSVersion.TLSv1_2
            # O certificado é autoassinado e não tem o nome interno do serviço: em vez da cadeia e do nome, o que
            # se confere é o certificado inteiro, byte a byte, contra o que o serviço ftp gravou em /auth.
            contexto.check_hostname = False
            contexto.verify_mode = ssl.CERT_NONE
            conexao = ftplib.FTP_TLS(timeout=TEMPO_FTP, context=contexto)
            conexao.connect(CFG['ftp_host'], 2121)
            conexao.auth()
            recebido = conexao.sock.getpeercert(binary_form=True)
            if not recebido or not hmac.compare_digest(recebido, esperado):
                return None
        try:
            conexao.login(nome, senha)
        except ftplib.error_perm as recusa:
            return False if str(recusa).startswith('530') else None
        return True
    except (ftplib.Error, OSError, EOFError, ValueError):  # ValueError: quebra de linha na senha ou certificado ilegível
        return None
    finally:
        if conexao is not None:
            try:
                if conexao.sock is not None:  # sem conexão aberta não há de quem se despedir
                    conexao.quit()
            except (ftplib.Error, OSError, EOFError, ValueError):
                pass
            conexao.close()
        VEZ.release()


def conferir(nome, senha):
    """Confere nome e senha de um usuário do FTP. Devolve (conta, motivo): a conta é {'marca', 'pasta'} quando
    a entrada vale e None quando não vale; o motivo só vem preenchido quando a conferência não pôde ser feita.
    O servidor é consultado para todo nome válido, exista ou não: a resposta e o tempo não dizem qual existe."""
    if not NOME.fullmatch(nome):
        return None, ''
    antes = cadastro(nome)
    aceita = senha_aceita(nome, senha)
    if aceita is None:
        return None, 'ftp_indisponivel'
    # O cadastro lido antes e depois da conferência tem de ser o mesmo: a senha aceita é a desta linha.
    if not aceita or antes is None or cadastro(nome) != antes:
        return None, ''
    return {'marca': antes[0], 'pasta': antes[1]}, ''


def motivo_do_fim(sessao):
    """A sessão de um usuário do FTP só vale enquanto o acesso está ligado, o usuário existe com a mesma linha
    no cadastro (mesma senha, mesma pasta) e nenhum administrador tem o nome dele. Devolve '' enquanto vale
    ou o motivo do encerramento. É conferido a cada pedido: alteração feita no painel ou pelo terminal vale na hora."""
    if not CFG['acesso_usuarios']:
        return 'acesso_desligado'
    if sessao['usuario'] in administradores.ler():
        return 'nome_de_administrador'
    return '' if cadastro(sessao['usuario']) == (sessao['marca'], sessao['pasta']) else 'cadastro_alterado'
