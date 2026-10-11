# SPDX-License-Identifier: Apache-2.0
"""Envio de arquivo e de aviso por um bot do Telegram, só com a biblioteca padrão.

O bot só envia. O painel chama duas operações da API de bot, sendDocument e sendMessage, e nenhuma outra: não lê
mensagem, não registra endereço de retorno e não aceita comando vindo da conversa. O arquivo sai do disco em blocos,
dentro de um formulário montado aqui, sem passar inteiro pela memória. O token vai no caminho do pedido, como a API
exige, e por isso o caminho nunca entra em mensagem de erro nem em registro: quem chama recebe só o motivo.
"""
import json
import re
import secrets
import time
import urllib.parse

import saida

TOKEN = re.compile(r'[0-9]{6,12}:[A-Za-z0-9_-]{30,64}')
CONVERSA = re.compile(r'-?[0-9]{1,20}|@[A-Za-z][A-Za-z0-9_]{4,31}')
LEGENDA_MAX = 1024     # caracteres da legenda de um arquivo
TEXTO_MAX = 4096       # caracteres de uma mensagem
OPERACOES = ('sendDocument', 'sendMessage')   # as duas da API de bot que o painel chama; nenhuma lê nem apaga
ESPERA_MAX = 30        # segundos que o painel aceita esperar quando a API pede para ir mais devagar


def nome_no_formulario(nome):
    """Nome do arquivo como vai no cabeçalho da parte: sem aspas, barras nem caractere de controle."""
    return re.sub(r'[\x00-\x1f\x7f"\\/]', '_', nome)[:200] or 'arquivo'


class Bot:
    """Um bot e a conversa que recebe, com a conexão aberta entre um envio e o seguinte."""

    def __init__(self, api, token, conversa, prazo=saida.PRAZO):
        if not (TOKEN.fullmatch(token) and CONVERSA.fullmatch(conversa)):
            raise saida.Falha('recusado')
        self.ligacao = saida.Ligacao(api, prazo)
        self.base, self.conversa = f'/bot{token}/', conversa

    def fechar(self):
        self.ligacao.close()

    def chamar(self, operacao, tipo, corpo, tamanho):
        if operacao not in OPERACOES:
            raise saida.Falha('proibido')
        for tentativa in (1, 2):
            codigo, _, dados = saida.pedir(self.ligacao, 'POST', self.base + operacao,
                                           {'Content-Type': tipo, 'Content-Length': str(tamanho)}, corpo)
            try:
                resposta = json.loads(dados)
            except ValueError:
                resposta = None
            if not isinstance(resposta, dict):
                resposta = {}
            if codigo == 200 and resposta.get('ok') is True:
                return
            if codigo == 429 and tentativa == 1:
                dados_da_espera = resposta.get('parameters')
                espera = dados_da_espera.get('retry_after') if isinstance(dados_da_espera, dict) else None
                if isinstance(espera, int) and 0 < espera <= ESPERA_MAX:
                    time.sleep(espera)
                    continue
            if codigo in (401, 403, 404):
                raise saida.Falha('recusado')        # token que não vale, ou bot fora da conversa
            if codigo == 400 and 'chat not found' in str(resposta.get('description', '')).lower():
                raise saida.Falha('nao_encontrado')  # a conversa não existe para este bot
            if codigo == 413:
                raise saida.Falha('limite')
            raise saida.Falha(f'http_{codigo}' if codigo != 200 else 'resposta')

    def avisar(self, texto):
        """Mensagem de texto puro para a conversa."""
        corpo = urllib.parse.urlencode({'chat_id': self.conversa, 'text': texto[:TEXTO_MAX]}).encode()
        self.chamar('sendMessage', 'application/x-www-form-urlencoded', corpo, len(corpo))

    def enviar(self, descritor, tamanho, nome, legenda):
        """Envia o arquivo aberto em `descritor` como documento, com a legenda em texto puro."""
        marca = secrets.token_hex(16)

        def campo(rotulo, valor):
            return f'--{marca}\r\nContent-Disposition: form-data; name="{rotulo}"\r\n\r\n{valor}\r\n'
        antes = (campo('chat_id', self.conversa) + campo('caption', legenda[:LEGENDA_MAX])
                 + f'--{marca}\r\nContent-Disposition: form-data; name="document"; filename="{nome_no_formulario(nome)}"\r\n'
                   'Content-Type: application/octet-stream\r\n\r\n').encode('utf-8')
        depois = f'\r\n--{marca}--\r\n'.encode()

        def corpo():
            yield antes
            yield from saida.blocos(descritor, 0, tamanho)
            yield depois
        self.chamar('sendDocument', f'multipart/form-data; boundary={marca}', corpo, len(antes) + tamanho + len(depois))
