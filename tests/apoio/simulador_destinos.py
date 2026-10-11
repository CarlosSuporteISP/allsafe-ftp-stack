#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Serviços de exemplo para a etapa dos destinos da bateria: um armazenamento S3 e uma API de bot do Telegram.

Roda dentro da rede da instância de teste, só com a biblioteca padrão, e atende HTTPS com o certificado que a etapa
gera. Não guarda o conteúdo de nada: de cada pedido fica uma linha em <pasta>/chamadas.jsonl, com o serviço, a
operação, o código da resposta e, do que foi recebido, o tamanho e o SHA-256. É por essas linhas que a etapa confere
o que o painel enviou, e que ele não pediu nenhuma operação além das de gravar e de enviar.

O S3 de exemplo refaz a assinatura versão 4 de cada pedido, com uma implementação que não é a do painel, e recusa o
corpo que não bate com a soma assinada. A API de bot confere o token e a conversa e mede o arquivo contra o limite.

<pasta>/config.json diz o que vale: {"s3_id", "s3_segredo", "regiao", "buckets", "bot_token", "conversa",
"telegram_max", "recusar"} e, quando o bot alcança mais de uma conversa, "conversas", com as outras. Objeto ou documento com o texto de "recusar" no nome recebe 400, e só ele. <pasta>/falhar,
quando existe, força a resposta de um serviço: uma linha "<s3|telegram> <código> [vezes [pular]]". Sem "vezes", vale
até o arquivo sair; com "pular", os primeiros pedidos passam e a falha começa depois deles.

Uso: simulador_destinos.py <pasta> <certificado.pem> <chave.pem> [porta]
"""
import hashlib
import hmac
import http.server
import json
import os
import re
import ssl
import sys
import tempfile
import threading
import urllib.parse

PASTA = sys.argv[1]
TRAVA = threading.Lock()
ENVIOS = {}     # identificador do envio em partes ➜ {'bucket', 'chave', 'partes': {número: arquivo com os bytes}}
FALHAS = {}     # texto da linha de <pasta>/falhar ➜ [pedidos que ainda passam, vezes que ainda falha]
BOT = re.compile(r'/bot([^/]+)/([A-Za-z]+)')


def config():
    with open(os.path.join(PASTA, 'config.json'), encoding='utf-8') as arquivo:
        return json.load(arquivo)


def conversas(conf):
    """As conversas que o bot alcança: a de "conversa" e, quando há, as de "conversas". A linha de cada envio leva em
    `qual` a posição da conversa que recebeu, para a etapa conferir o destino sem levar a conversa à evidência."""
    return [conf['conversa']] + list(conf.get('conversas', ()))


def anotar(**campos):
    with TRAVA, open(os.path.join(PASTA, 'chamadas.jsonl'), 'a', encoding='utf-8') as arquivo:
        arquivo.write(json.dumps(campos, ensure_ascii=False, sort_keys=True) + '\n')


def forcada(servico):
    """O código que <pasta>/falhar manda responder a este serviço, ou 0."""
    try:
        with open(os.path.join(PASTA, 'falhar'), encoding='utf-8') as arquivo:
            linha = arquivo.readline().strip()
    except OSError:
        return 0
    campos = linha.split()
    if len(campos) < 2 or campos[0] != servico or not campos[1].isdigit():
        return 0
    if len(campos) > 2 and campos[2].isdigit():
        with TRAVA:
            conta = FALHAS.setdefault(linha, [int(campos[3]) if len(campos) > 3 and campos[3].isdigit() else 0, int(campos[2])])
            if conta[0] > 0:
                conta[0] -= 1
                return 0
            if conta[1] <= 0:
                return 0
            conta[1] -= 1
    return int(campos[1])


def codificar(texto):
    return urllib.parse.quote(texto, safe='-_.~')


def assinatura_esperada(metodo, caminho, consulta, cabecalhos, assinados, soma, momento, regiao, segredo):
    pedido = '\n'.join((
        metodo, caminho,
        '&'.join(f'{codificar(nome)}={codificar(valor)}' for nome, valor in sorted(consulta)),
        ''.join(f'{nome}:{" ".join(cabecalhos.get(nome, "").split())}\n' for nome in assinados),
        ';'.join(assinados), soma))
    escopo = f'{momento[:8]}/{regiao}/s3/aws4_request'
    texto = '\n'.join(('AWS4-HMAC-SHA256', momento, escopo, hashlib.sha256(pedido.encode()).hexdigest()))
    chave = ('AWS4' + segredo).encode()
    for parte in (momento[:8], regiao, 's3', 'aws4_request'):
        chave = hmac.new(chave, parte.encode(), hashlib.sha256).digest()
    return hmac.new(chave, texto.encode(), hashlib.sha256).hexdigest(), escopo


class Pedido(http.server.BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'

    def log_message(self, *argumentos):
        pass

    def responder(self, codigo, corpo=b'', tipo='application/xml', extras=()):
        self.send_response(codigo)
        self.send_header('Content-Type', tipo)
        self.send_header('Content-Length', str(len(corpo)))
        for nome, valor in extras:
            self.send_header(nome, valor)
        self.end_headers()
        if self.command != 'HEAD':
            self.wfile.write(corpo)

    def corpo(self, destino=None):
        """Lê o corpo inteiro: devolve (tamanho, SHA-256, MD5). Com `destino`, os bytes vão também para ele."""
        falta = int(self.headers.get('Content-Length') or 0)
        soma, marca, tamanho = hashlib.sha256(), hashlib.md5(), falta
        while falta:
            pedaco = self.rfile.read(min(falta, 1 << 18))
            if not pedaco:
                break
            falta -= len(pedaco)
            soma.update(pedaco)
            marca.update(pedaco)
            if destino is not None:
                destino.write(pedaco)
        return tamanho - falta, soma.hexdigest(), marca.hexdigest()

    def atender(self):
        caminho, _, consulta = self.path.partition('?')
        if caminho == '/saude':
            self.corpo()
            return self.responder(200, b'ok', 'text/plain')
        bot = BOT.fullmatch(caminho)
        if bot:
            return self.telegram(bot.group(1), bot.group(2))
        return self.s3(caminho, urllib.parse.parse_qsl(consulta, keep_blank_values=True))

    do_GET = do_HEAD = do_PUT = do_POST = do_DELETE = atender

    # ------------------------------------------------------------ S3

    def erro_s3(self, codigo, nome, **campos):
        anotar(servico='s3', metodo=self.command, codigo=codigo, erro=nome, **campos)
        self.responder(codigo, f'<?xml version="1.0"?><Error><Code>{nome}</Code></Error>'.encode())

    def s3(self, caminho, consulta):
        conf = config()
        nomes = dict(consulta)
        host = self.headers.get('Host', '').split(':')[0]
        if host.split('.')[0] in conf['buckets'] and '.' in host:
            bucket, chave, estilo = host.split('.')[0], urllib.parse.unquote(caminho[1:]), 'host'
        else:
            (bucket, _, chave), estilo = urllib.parse.unquote(caminho[1:]).partition('/'), 'caminho'
        campos = {'bucket': bucket, 'chave': chave, 'estilo': estilo, 'consulta': sorted(nomes)}
        parte = self.command == 'PUT' and set(nomes) == {'partNumber', 'uploadId'} and nomes['partNumber'].isdigit()
        guardado = tempfile.TemporaryFile() if parte else None
        try:
            return self.s3_conferido(conf, caminho, consulta, nomes, campos, guardado)
        finally:
            if guardado is not None and not any(guardado in envio['partes'].values() for envio in list(ENVIOS.values())):
                guardado.close()

    def s3_conferido(self, conf, caminho, consulta, nomes, campos, guardado):
        bucket, chave = campos['bucket'], campos['chave']
        tamanho, soma, marca = self.corpo(guardado)
        # A assinatura: a mesma conta que o serviço de verdade faz, com o que chegou.
        casa = re.fullmatch(r'AWS4-HMAC-SHA256 Credential=([^/]+)/([^,]+),\s*SignedHeaders=([^,]+),\s*Signature=([0-9a-f]{64})',
                            self.headers.get('Authorization', ''))
        if not casa:
            return self.erro_s3(403, 'AccessDenied', **campos)
        if casa.group(1) != conf['s3_id']:
            return self.erro_s3(403, 'InvalidAccessKeyId', **campos)
        cabecalhos = {nome.lower(): valor for nome, valor in self.headers.items()}
        assinados = casa.group(3).split(';')
        esperada, escopo = assinatura_esperada(self.command, caminho, consulta, cabecalhos, assinados,
                                               cabecalhos.get('x-amz-content-sha256', ''), cabecalhos.get('x-amz-date', ''),
                                               conf['regiao'], conf['s3_segredo'])
        if not ({'host', 'x-amz-content-sha256', 'x-amz-date'} <= set(assinados) and casa.group(2) == escopo
                and hmac.compare_digest(casa.group(4), esperada)):
            return self.erro_s3(403, 'SignatureDoesNotMatch', **campos)
        if cabecalhos['x-amz-content-sha256'] != soma:
            return self.erro_s3(400, 'XAmzContentSHA256Mismatch', **campos)
        codigo = forcada('s3')
        if codigo:
            extras = (('Location', 'https://outro.simulador.test/'),) if codigo in (301, 302, 307, 308) else ()
            anotar(servico='s3', metodo=self.command, codigo=codigo, erro='Forcado', **campos)
            return self.responder(codigo, b'<?xml version="1.0"?><Error><Code>Forcado</Code></Error>', extras=extras)
        if bucket not in conf['buckets']:
            return self.erro_s3(404, 'NoSuchBucket', **campos)
        if conf.get('recusar') and conf['recusar'] in chave:
            return self.erro_s3(400, 'InvalidRequest', **campos)
        if self.command == 'PUT' and not consulta:
            anotar(servico='s3', op='gravar', codigo=200, bytes=tamanho, sha256=soma, **campos)
            return self.responder(200, extras=(('ETag', f'"{marca}"'),))
        if self.command == 'POST' and consulta == [('uploads', '')]:
            envio = hashlib.sha256(os.urandom(16)).hexdigest()[:32]
            with TRAVA:
                ENVIOS[envio] = {'bucket': bucket, 'chave': chave, 'partes': {}}
            anotar(servico='s3', op='abrir_partes', codigo=200, **campos)
            return self.responder(200, f'<?xml version="1.0"?><InitiateMultipartUploadResult><Bucket>{bucket}</Bucket>'
                                       f'<UploadId>{envio}</UploadId></InitiateMultipartUploadResult>'.encode())
        if 'uploadId' in nomes:
            envio = ENVIOS.get(nomes['uploadId'])
            if envio is None or (envio['bucket'], envio['chave']) != (bucket, chave):
                return self.erro_s3(404, 'NoSuchUpload', **campos)
            if guardado is not None:
                with TRAVA:
                    envio['partes'][int(nomes['partNumber'])] = guardado
                anotar(servico='s3', op='parte', codigo=200, numero=int(nomes['partNumber']), bytes=tamanho, **campos)
                return self.responder(200, extras=(('ETag', f'"{marca}"'),))
            if self.command == 'DELETE' and set(nomes) == {'uploadId'}:
                with TRAVA:
                    ENVIOS.pop(nomes['uploadId'], None)
                for copia in envio['partes'].values():
                    copia.close()
                anotar(servico='s3', op='abandonar', codigo=204, **campos)
                return self.responder(204)
            if self.command == 'POST' and set(nomes) == {'uploadId'}:
                return self.concluir(nomes['uploadId'], envio, campos)
        # Ler, listar e apagar não são do painel: a linha fica, e a etapa falha se ela aparecer.
        return self.erro_s3(405, 'MethodNotAllowed', op='outra', **campos)

    def concluir(self, identificador, envio, campos):
        """O fim de um envio em partes: a lista pedida precisa ser a das partes recebidas, na ordem."""
        with TRAVA:
            ENVIOS.pop(identificador, None)
        # A lista veio no corpo, que já foi lido para a soma: aqui só vale o que foi recebido, em ordem.
        soma, tamanho = hashlib.sha256(), 0
        for numero in sorted(envio['partes']):
            copia = envio['partes'][numero]
            copia.seek(0)
            while True:
                pedaco = copia.read(1 << 20)
                if not pedaco:
                    break
                soma.update(pedaco)
                tamanho += len(pedaco)
            copia.close()
        if sorted(envio['partes']) != list(range(1, len(envio['partes']) + 1)) or not envio['partes']:
            return self.erro_s3(400, 'InvalidPartOrder', **campos)
        anotar(servico='s3', op='gravar', codigo=200, bytes=tamanho, sha256=soma.hexdigest(), partes=len(envio['partes']), **campos)
        return self.responder(200, b'<?xml version="1.0"?><CompleteMultipartUploadResult><ETag>"fim"</ETag>'
                                   b'</CompleteMultipartUploadResult>')

    # ------------------------------------------------------------ API de bot

    def resposta_do_bot(self, codigo, descricao='', **campos):
        anotar(servico='telegram', codigo=codigo, **campos)
        corpo = {'ok': codigo == 200}
        if codigo != 200:
            corpo.update({'error_code': codigo, 'description': descricao})
        if codigo == 429:
            corpo['parameters'] = {'retry_after': 1}
        self.responder(codigo, json.dumps(corpo).encode(), 'application/json')

    def telegram(self, token, operacao):
        conf = config()
        inteiro = bytearray()

        class Juntar:
            write = staticmethod(inteiro.extend)
        tamanho, _, _ = self.corpo(Juntar)
        campos = {'op': operacao, 'metodo': self.command}
        if token != conf['bot_token']:
            return self.resposta_do_bot(401, 'Unauthorized', **campos)
        codigo = forcada('telegram')
        if codigo:
            return self.resposta_do_bot(codigo, 'Forcado', **campos)
        tipo = self.headers.get('Content-Type', '')
        if operacao == 'sendMessage' and tipo.startswith('application/x-www-form-urlencoded'):
            dados = dict(urllib.parse.parse_qsl(inteiro.decode('utf-8')))
            if dados.get('chat_id') not in conversas(conf):
                return self.resposta_do_bot(400, 'Bad Request: chat not found', **campos)
            return self.resposta_do_bot(200, conversa=dados['chat_id'], qual=conversas(conf).index(dados['chat_id']),
                                        texto=dados.get('text', ''), **campos)
        marca = re.search(r'boundary=([0-9a-f]{32})$', tipo)
        if operacao == 'sendDocument' and marca:
            partes = {}
            for pedaco in bytes(inteiro).split(b'--' + marca.group(1).encode())[1:-1]:
                cabeca, _, valor = pedaco.partition(b'\r\n\r\n')
                nome = re.search(rb'name="([^"]+)"', cabeca)
                arquivo = re.search(rb'filename="([^"]*)"', cabeca)
                if nome:
                    partes[nome.group(1).decode()] = (valor[:-2], arquivo.group(1).decode('utf-8') if arquivo else None)
            if not {'chat_id', 'document'} <= set(partes) or set(partes) - {'chat_id', 'caption', 'document'}:
                return self.resposta_do_bot(400, 'Bad Request: wrong form', campos_do_formulario=sorted(partes), **campos)
            conversa = partes['chat_id'][0].decode()
            if conversa not in conversas(conf):
                return self.resposta_do_bot(400, 'Bad Request: chat not found', **campos)
            documento, nome = partes['document']
            if conf.get('recusar') and conf['recusar'] in (nome or ''):
                return self.resposta_do_bot(400, 'Bad Request: wrong file', arquivo=nome, **campos)
            if len(documento) > conf['telegram_max']:
                return self.resposta_do_bot(413, 'Request Entity Too Large', bytes=len(documento), **campos)
            return self.resposta_do_bot(200, conversa=conversa, qual=conversas(conf).index(conversa), arquivo=nome,
                                        bytes=len(documento),
                                        sha256=hashlib.sha256(documento).hexdigest(),
                                        legenda=partes.get('caption', (b'', None))[0].decode('utf-8'), **campos)
        # Qualquer outra operação (ler mensagens, registrar endereço de retorno): a linha fica, e a etapa falha.
        return self.resposta_do_bot(200, outra=True, bytes=tamanho, **campos)


def principal():
    contexto = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    contexto.minimum_version = ssl.TLSVersion.TLSv1_2
    contexto.load_cert_chain(sys.argv[2], sys.argv[3])
    servidor = http.server.ThreadingHTTPServer(('', int(sys.argv[4]) if len(sys.argv) > 4 else 8443), Pedido)
    servidor.socket = contexto.wrap_socket(servidor.socket, server_side=True)
    print('simulador dos destinos pronto', flush=True)
    servidor.serve_forever()


if __name__ == '__main__':
    principal()
