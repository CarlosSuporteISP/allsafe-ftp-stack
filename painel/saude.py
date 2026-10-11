# SPDX-License-Identifier: Apache-2.0
"""Verificação de saúde do container do painel: pede /saude pelo soquete Unix e sai com 0 ou 1.

Fica em um arquivo à parte, que só usa o soquete e não importa nada do painel: o Docker o roda a cada 20 s, e
subir o painel inteiro para fazer um pedido gastava de uma vez mais processador do que a cota do container dá em
um período, o que somava no contador de limite atingido da aba Servidor sem carga nenhuma.
"""
import socket
import sys

# Soquete Unix na pasta que o painel divide com o nginx; o config.py lê o caminho daqui.
ARQ_SOQUETE = '/nginx/painel.sock'


def conferir():
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


if __name__ == '__main__':
    conferir()
