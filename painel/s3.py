# SPDX-License-Identifier: Apache-2.0
"""Envio de arquivo para um armazenamento S3, só com a biblioteca padrão.

O painel só grava: PutObject para arquivo de até 32 MiB e envio em partes acima disso (criar, enviar cada parte,
concluir; abandonar quando falha). A cópia do sistema (copia.py) usa o mesmo envio em partes, com cada parte tirada de um fluxo. Nada é lido, listado nem apagado no destino: a chave só precisa das permissões
s3:PutObject e s3:AbortMultipartUpload, e Destino.pedir recusa, antes de sair, o pedido que não está em FORMAS. Cada pedido é assinado com a assinatura versão 4 (AWS4-HMAC-SHA256), com o
SHA-256 do corpo dentro da assinatura: o arquivo é lido duas vezes, uma para a soma e outra para o envio, e o destino
recusa o que chegar diferente do que foi assinado. Serve para qualquer serviço que fale o protocolo do S3, com o
endereço por caminho (https://servico/bucket/chave) ou por nome (https://bucket.servico/chave).
"""
import hashlib
import hmac
import re
import time
import urllib.parse

import saida

SIMPLES_MAX = 32 * 1024 * 1024       # até aqui, um pedido só
PARTE_MIN = 16 * 1024 * 1024         # tamanho de cada parte, enquanto couber em PARTES_MAX
PARTES_MAX = 9000                    # o protocolo aceita 10000 partes
OBJETO_MAX = 5 * 1024 ** 4           # maior objeto que o protocolo aceita
CHAVE_MAX = 1024                     # bytes da chave de um objeto
VAZIO = hashlib.sha256(b'').hexdigest()
BUCKET = re.compile(r'[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]')
REGIAO = re.compile(r'[a-z0-9][a-z0-9-]{0,31}')
PREFIXO = re.compile(r'[A-Za-z0-9_][A-Za-z0-9._-]{0,63}(?:/[A-Za-z0-9_][A-Za-z0-9._-]{0,63}){0,7}')
ENVIO = re.compile(rb'<UploadId>([^<]{1,1024})</UploadId>')
# Tudo o que o painel pode pedir a um bucket: o método e os nomes da consulta, em ordem. O DELETE da lista desfaz um
# envio em partes que não foi concluído, que não é objeto. Apagar ou ler objeto, apagar vários, mexer no bucket e nas
# regras dele não estão aqui, e por isso não saem do painel por nenhum caminho: tela, rotina, terminal ou cópia.
FORMAS = {
    'PUT': ((), ('partNumber', 'uploadId')),
    'POST': (('uploads',), ('uploadId',)),
    'DELETE': (('uploadId',),),
}


def codificar(texto):
    return urllib.parse.quote(texto, safe='-_.~')


def assinar(metodo, caminho, consulta, cabecalhos, soma, regiao, chave_id, chave_secreta, agora=None):
    """Devolve os cabeçalhos do pedido com a data, a soma do corpo e a autorização. `caminho` já vem codificado,
    `consulta` é uma lista de pares e `cabecalhos` traz pelo menos o Host; todos os que vierem entram na assinatura."""
    momento = time.strftime('%Y%m%dT%H%M%SZ', time.gmtime(agora))
    todos = {nome.lower(): ' '.join(str(valor).split()) for nome, valor in cabecalhos.items()}
    todos['x-amz-content-sha256'] = soma
    todos['x-amz-date'] = momento
    assinados = ';'.join(sorted(todos))
    pedido = '\n'.join((
        metodo, caminho,
        '&'.join(f'{codificar(nome)}={codificar(valor)}' for nome, valor in sorted(consulta)),
        ''.join(f'{nome}:{todos[nome]}\n' for nome in sorted(todos)),
        assinados, soma))
    escopo = f'{momento[:8]}/{regiao}/s3/aws4_request'
    a_assinar = '\n'.join(('AWS4-HMAC-SHA256', momento, escopo, hashlib.sha256(pedido.encode()).hexdigest()))
    chave = ('AWS4' + chave_secreta).encode()
    for parte in (momento[:8], regiao, 's3', 'aws4_request'):
        chave = hmac.new(chave, parte.encode(), hashlib.sha256).digest()
    assinatura = hmac.new(chave, a_assinar.encode(), hashlib.sha256).hexdigest()
    todos['authorization'] = f'AWS4-HMAC-SHA256 Credential={chave_id}/{escopo},SignedHeaders={assinados},Signature={assinatura}'
    return todos


def chave_do_objeto(prefixo, relativo):
    """Prefixo do destino + caminho do arquivo dentro da pasta dos dados. None quando não cabe em uma chave."""
    chave = f'{prefixo}/{relativo}' if prefixo else relativo
    try:
        return chave if len(chave.encode('utf-8')) <= CHAVE_MAX else None
    except UnicodeEncodeError:
        return None


class Destino:
    """Um bucket, com a conexão aberta entre um arquivo e o seguinte. `conf` é a configuração gravada (destinos.py)."""

    def __init__(self, conf, chave_id, chave_secreta, prazo=saida.PRAZO):
        nome, porta = saida.analisar(conf['endpoint'])
        if conf['estilo'] == 'host':
            nome, self.raiz = f'{conf["bucket"]}.{nome}', ''
        else:
            self.raiz = '/' + conf['bucket']
        self.host = nome if porta == 443 else f'{nome}:{porta}'
        self.ligacao = saida.Ligacao(f'https://{self.host}', prazo)
        self.regiao, self.chave_id, self.chave_secreta = conf['regiao'], chave_id, chave_secreta

    def fechar(self):
        self.ligacao.close()

    def pedir(self, metodo, chave, consulta=(), corpo=b'', soma=None, tamanho=None, extras=None):
        consulta = list(consulta)
        if (tuple(sorted(nome for nome, _ in consulta)) not in FORMAS.get(metodo, ()) or not chave.strip('/')
                or any(nome == 'uploadId' and not valor for nome, valor in consulta)):
            raise saida.Falha('proibido')
        caminho = self.raiz + '/' + '/'.join(codificar(parte) for parte in chave.split('/'))
        cabecalhos = assinar(metodo, caminho, consulta, {'Host': self.host, **(extras or {})},
                             soma or hashlib.sha256(corpo).hexdigest(), self.regiao, self.chave_id, self.chave_secreta)
        cabecalhos['content-length'] = str(len(corpo) if tamanho is None else tamanho)
        if consulta:
            caminho += '?' + '&'.join(f'{codificar(nome)}={codificar(valor)}' for nome, valor in sorted(consulta))
        codigo, recebidos, dados = saida.pedir(self.ligacao, metodo, caminho, cabecalhos, corpo)
        if codigo in (301, 302, 307, 308):
            raise saida.Falha('endereco')   # bucket de outra região ou endereço trocado: o painel não segue
        if codigo in (401, 403):
            raise saida.Falha('recusado')
        if codigo == 404:
            raise saida.Falha('nao_encontrado')
        if not 200 <= codigo < 300:
            raise saida.Falha(f'http_{codigo}')
        return recebidos, dados

    def trecho(self, descritor, inicio, quanto):
        """Soma de um trecho do arquivo e a função que o entrega em blocos, para o envio."""
        soma = hashlib.sha256()
        for pedaco in saida.blocos(descritor, inicio, quanto):
            soma.update(pedaco)
        return soma.hexdigest(), lambda: saida.blocos(descritor, inicio, quanto)

    def enviar(self, chave, descritor, tamanho):
        """Grava o arquivo aberto em `descritor` na chave. Levanta saida.Falha quando não grava."""
        if tamanho > OBJETO_MAX:
            raise saida.Falha('limite')
        if tamanho <= SIMPLES_MAX:
            soma, corpo = self.trecho(descritor, 0, tamanho) if tamanho else (VAZIO, b'')
            self.pedir('PUT', chave, corpo=corpo, soma=soma, tamanho=tamanho)
            return
        parte = max(PARTE_MIN, -(-tamanho // PARTES_MAX))
        self.em_partes(chave, ((descritor, inicio, min(parte, tamanho - inicio)) for inicio in range(0, tamanho, parte)))

    def em_partes(self, chave, trechos):
        """Envio em partes: `trechos` entrega (descritor, início, quanto) de cada parte, e a seguinte só é pedida
        depois de a anterior estar gravada. Qualquer falha, também a de quem entrega os trechos, desfaz o envio:
        o objeto só existe depois de concluído. Devolve o número de partes."""
        _, dados = self.pedir('POST', chave, [('uploads', '')])
        casa = ENVIO.search(dados)
        if not casa:
            raise saida.Falha('resposta')
        envio = casa.group(1).decode('ascii', 'replace')
        try:
            marcas = []
            for numero, (descritor, inicio, quanto) in enumerate(trechos, 1):
                if numero > 10000:
                    raise saida.Falha('limite')
                soma, corpo = self.trecho(descritor, inicio, quanto)
                recebidos, _ = self.pedir('PUT', chave, [('partNumber', str(numero)), ('uploadId', envio)],
                                          corpo=corpo, soma=soma, tamanho=quanto)
                marca = recebidos.get('ETag', '')
                if not re.fullmatch(r'"?[A-Za-z0-9+/=_-]{1,128}"?', marca):
                    raise saida.Falha('resposta')
                marcas.append((numero, marca.strip('"')))
            lista = ('<CompleteMultipartUpload>'
                     + ''.join(f'<Part><PartNumber>{numero}</PartNumber><ETag>"{marca}"</ETag></Part>' for numero, marca in marcas)
                     + '</CompleteMultipartUpload>').encode()
            _, dados = self.pedir('POST', chave, [('uploadId', envio)], corpo=lista)
            # O protocolo pode responder 200 e trazer o erro no corpo: só vale quando vem o resultado.
            if b'<Error>' in dados or b'CompleteMultipartUploadResult' not in dados:
                raise saida.Falha('resposta')
            return len(marcas)
        except BaseException:
            try:
                self.pedir('DELETE', chave, [('uploadId', envio)])
            except saida.Falha:
                pass   # o que sobrou do envio em partes fica para a regra de expiração do bucket
            raise
