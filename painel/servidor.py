#!/usr/bin/env python3
"""Painel web da allsafe-ftp-stack. Por padrão, só para rede privada, atrás de firewall.

O navegador fala HTTPS com o nginx, que é a única porta publicada; o painel não escuta na rede:
atende só o soquete Unix que o nginx abre e recebe dele o endereço real do cliente. Cada administrador
entra com usuário e senha, conferida contra hash scrypt; sessão em cookie __Host-, token CSRF em todo
envio e nenhuma dependência fora da biblioteca padrão do Python.
Não usa JavaScript nem o socket do Docker: os usuários do FTP são alterados pelo mesmo
allsafe-ftp-user do serviço ftp, na pasta /auth que os dois containers compartilham.

Modos: sem argumento, sobe o servidor; --hash lê uma senha da entrada padrão e imprime o hash;
--administrador <nome> lê um hash da entrada padrão e cria o administrador ou troca a senha dele;
--saude confere /saude pelo soquete e sai com 0 ou 1 (healthcheck do container).
"""
import socket
import sys

import administradores
from atendimento import Painel, Servidor
from auditoria import auditar, limpo
from config import ARQ_ADMINS, ARQ_HASH, ARQ_SOQUETE, CFG, NOME, SENHA_MIN, configuracao, falha
from senha import analisar_hash, gerar_hash, ler_hash_inicial


def modo_hash():
    senha = sys.stdin.readline().rstrip('\r\n')
    if not SENHA_MIN <= len(senha) <= 256:
        falha(f'a senha do painel deve ter pelo menos {SENHA_MIN} caracteres')
    print(gerar_hash(senha))


def modo_administrador(nome):
    """Recuperação pelo host (scripts/painel-senha.sh): o hash vem pela entrada padrão, nunca a senha."""
    guardado = sys.stdin.readline().strip()
    if not NOME.fullmatch(nome):
        falha('nome de administrador inválido: letras minúsculas, números, _ e -; começa com letra ou _; até 32 caracteres')
    if not analisar_hash(guardado):
        falha('a entrada padrão não trouxe um hash scrypt válido')
    try:
        feito, erro = administradores.definir(nome, guardado)
    except OSError as motivo:
        falha(f'não foi possível gravar {ARQ_ADMINS}: {motivo.strerror}')
    if erro:
        falha(erro)
    auditar('-', 'admin_definido_no_host', f'admin={nome} resultado={feito}')
    print(f'administrador {nome}: {feito}')


def modo_saude():
    """Pede /saude pelo soquete, como o nginx faria a partir do próprio host."""
    pedido = b'GET /saude HTTP/1.1\r\nHost: localhost\r\nX-Real-IP: 127.0.0.1\r\nConnection: close\r\n\r\n'
    resposta = b''
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as conexao:
            conexao.settimeout(4)
            conexao.connect(ARQ_SOQUETE)
            conexao.sendall(pedido)
            while len(resposta) < 8192:
                parte = conexao.recv(4096)
                if not parte:
                    break
                resposta += parte
    except OSError:
        sys.exit(1)
    cabecalho, _, corpo = resposta.partition(b'\r\n\r\n')
    sys.exit(0 if cabecalho.startswith(b'HTTP/1.1 200 ') and corpo.strip() == b'ok' else 1)


def principal():
    if '--hash' in sys.argv[1:]:
        return modo_hash()
    if '--saude' in sys.argv[1:]:
        return modo_saude()
    if '--administrador' in sys.argv[1:]:
        posicao = sys.argv.index('--administrador')
        return modo_administrador(sys.argv[posicao + 1] if len(sys.argv) > posicao + 1 else '')
    CFG.update(configuracao())
    # O segredo da instalação só vale para criar o primeiro administrador; depois, quem manda é o arquivo.
    if not administradores.ler():
        inicial = ler_hash_inicial()
        if inicial is None:
            falha(f'{ARQ_HASH} ausente ou inválido: rode ./deploy.sh ou scripts/painel-senha.sh')
        try:
            criado = administradores.iniciar(CFG['admin_inicial'], inicial)
        except OSError as motivo:
            falha(f'não foi possível gravar {ARQ_ADMINS}: {motivo.strerror}')
        if criado:
            auditar('-', 'admin_inicial_criado', f'admin={CFG["admin_inicial"]}')
    servidor = Servidor(ARQ_SOQUETE, Painel)
    auditar('-', 'painel_iniciado', f'versao={limpo(CFG["versao"])}')
    print(f'Painel pronto no soquete {ARQ_SOQUETE}, atrás do nginx; sessão de {CFG["inatividade"] // 60} min; '
          f'redes permitidas: {", ".join(str(r) for r in CFG["redes"])}', flush=True)
    servidor.serve_forever()


if __name__ == '__main__':
    principal()
