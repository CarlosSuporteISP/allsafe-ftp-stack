# SPDX-License-Identifier: Apache-2.0
"""Corpo de um envio de arquivo pelo navegador (multipart/form-data, RFC 7578), lido em fluxo: o arquivo vai do
soquete para o disco em blocos e nunca fica inteiro na memória.

O formulário do painel manda os campos de texto primeiro e o arquivo por último, e só essa forma é aceita. Com o
arquivo no fim, o tamanho dele sai do Content-Length: não se procura a marca de separação no meio do conteúdo, e
um arquivo que traga a marca dentro dele chega inteiro. Qualquer outra forma é recusada como envio malformado."""
import os
import re
import select
import time

from config import BLOCO_ARQUIVO

# A marca de separação só com os caracteres da RFC 2046, com ou sem aspas.
LIMITE = re.compile(r'multipart/form-data\s*;\s*boundary=("?)([0-9A-Za-z\'()+_,\-./:=?]{1,70})\1', re.IGNORECASE)
# Como os navegadores escrevem cada parte: aspas no nome do arquivo chegam como %22 e quebra de linha, como %0A.
PARTE = re.compile(rb'form-data; name="([a-z]{1,16})"(?:; filename="([^"\r\n]{0,1024})")?')
CAMPOS_MAX = 8         # campos de texto antes do arquivo
CABECALHO_MAX = 2048   # bytes do cabeçalho de uma parte
VALOR_MAX = 4608       # bytes de um campo de texto: cabe o caminho de uma pasta


class Malformado(Exception):
    """Corpo fora da forma que o formulário do painel manda."""


class Cortado(Exception):
    """Quem enviava fechou a conexão, ou parou de mandar, antes do fim do arquivo."""


def limite_de(tipo):
    """A marca de separação que o Content-Type declara, ou None se o pedido não é multipart/form-data."""
    achado = LIMITE.fullmatch(tipo.strip())
    return achado.group(2) if achado else None


class Corpo:
    def __init__(self, fluxo, total, limite, conexao=None):
        self.fluxo, self.resta = fluxo, total
        self.vigia = None   # avisa quando quem enviava fecha a conexão; usado por esperar()
        if conexao is not None:
            self.vigia = select.poll()
            self.vigia.register(conexao, select.POLLRDHUP)
        self.marca = b'--' + limite.encode('ascii')
        self.fecho = b'\r\n' + self.marca + b'--\r\n'
        self.arquivo = ''   # nome que o navegador deu ao arquivo; preenchido por campos()

    def linha(self, maximo):
        """Uma linha do corpo de até `maximo` bytes, sem o fim de linha."""
        dados = self.fluxo.readline(min(maximo + 2, self.resta))
        self.resta -= len(dados)
        if not dados.endswith(b'\r\n'):
            raise Malformado
        return dados[:-2]

    def campos(self):
        """Lê os campos de texto e para no primeiro byte do conteúdo do arquivo. Devolve campo ➜ valor."""
        campos = {}
        if self.linha(len(self.marca)) != self.marca:
            raise Malformado
        while True:
            parte, lidos = None, 0
            while True:
                linha = self.linha(CABECALHO_MAX)
                lidos += len(linha)
                if lidos > CABECALHO_MAX:
                    raise Malformado
                if not linha:
                    break
                nome, _, valor = linha.partition(b':')
                if nome.strip().lower() == b'content-disposition':
                    if parte is not None:
                        raise Malformado
                    parte = PARTE.fullmatch(valor.strip())
                    if parte is None:
                        raise Malformado
            if parte is None:
                raise Malformado
            campo = parte.group(1).decode('ascii')
            if parte.group(2) is not None:
                if campo != 'arquivo':
                    raise Malformado
                self.arquivo = parte.group(2).decode('utf-8', 'replace')
                return campos
            if campo in campos or len(campos) >= CAMPOS_MAX:
                raise Malformado
            try:
                campos[campo] = self.linha(VALOR_MAX).decode('utf-8')
            except UnicodeDecodeError:
                raise Malformado from None
            if self.linha(len(self.marca)) != self.marca:
                raise Malformado

    def tamanho(self):
        """Bytes do arquivo: o que falta do corpo menos o fecho. Negativo quando o corpo acaba antes do fecho."""
        return self.resta - len(self.fecho)

    def ler(self, quantos):
        try:
            bloco = self.fluxo.read1(quantos)
        except OSError:
            raise Cortado from None
        if not bloco:
            raise Cortado
        self.resta -= len(bloco)
        return bloco

    def esperar(self, segundos):
        """Espera o ritmo da taxa. Se quem enviava fechar a conexão nesse meio-tempo, o envio acaba já (Cortado):
        sem isso o painel ainda leria, na taxa do usuário, o que ficou parado no soquete, com a vaga ocupada."""
        if segundos <= 0:
            return
        if self.vigia is None:
            time.sleep(segundos)
        elif self.vigia.poll(segundos * 1000):
            raise Cortado

    def gravar(self, descritor, taxa=0):
        """Copia o conteúdo do arquivo para o descritor e confere o fecho do corpo. Devolve os bytes gravados.
        `taxa`, em KB por segundo, segura o recebimento no ritmo do limite do usuário; 0 = sem teto. Erro do disco
        sai como OSError; conexão que caiu no meio, como Cortado."""
        total = falta = self.tamanho()
        if falta < 0:
            raise Malformado
        por_vez = min(BLOCO_ARQUIVO, taxa * 1024) if taxa else BLOCO_ARQUIVO
        inicio = time.monotonic()
        while falta:
            bloco = memoryview(self.ler(min(por_vez, falta)))
            falta -= len(bloco)
            while bloco:
                bloco = bloco[os.write(descritor, bloco):]
            if taxa and falta:
                self.esperar((total - falta) / (taxa * 1024) - (time.monotonic() - inicio))
        fecho = b''
        while len(fecho) < len(self.fecho):
            fecho += self.ler(len(self.fecho) - len(fecho))
        if fecho != self.fecho:
            raise Malformado
        return total

    def escoar(self, prazo, maximo):
        """Lê e joga fora o que falta do corpo, até `maximo` bytes e `prazo` segundos: é o tempo de o nginx receber
        a resposta que já saiu, antes de a conexão fechar com o navegador ainda enviando."""
        fim = time.monotonic() + prazo
        try:
            while self.resta > 0 and maximo > 0 and time.monotonic() < fim:
                bloco = self.fluxo.read1(min(BLOCO_ARQUIVO, self.resta))
                if not bloco:
                    break
                self.resta -= len(bloco)
                maximo -= len(bloco)
        except OSError:
            pass
