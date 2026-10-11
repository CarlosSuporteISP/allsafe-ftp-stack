# SPDX-License-Identifier: Apache-2.0
"""Conexão HTTPS de saída do painel, para os destinos de fora (S3 e bot do Telegram).

É a única porta por onde o painel fala com alguém fora da stack, e só existe com PAINEL_DESTINOS=sim. Só HTTPS, com
TLS 1.2 ou mais novo e o certificado conferido contra as autoridades da imagem e, se o administrador gravou uma, contra
a de /painel/destinos/ca.pem (S3 da rede interna com autoridade própria). O nome é resolvido uma vez, cada endereço é
conferido e a conexão vai para o endereço que foi conferido: não há segunda consulta de nome entre conferir e conectar.
Nunca sai para o próprio container, para endereço de enlace (onde ficam os metadados das nuvens), de grupo ou
reservado. Redirecionamento não é seguido e a resposta tem teto: o que vem de fora nunca vai inteiro para a memória.

Quem chama recebe uma Falha com o motivo em uma palavra; texto que vem de fora não entra em mensagem nem em registro.
"""
import http.client
import ipaddress
import os
import socket
import ssl

from config import ENDERECO_HTTPS, PASTA_DESTINOS

ARQ_CA = os.path.join(PASTA_DESTINOS, 'ca.pem')
PRAZO = 30                  # segundos por operação de rede de um envio
RESPOSTA_MAX = 256 * 1024   # bytes lidos de uma resposta
BLOCO = 256 * 1024          # bytes de arquivo lidos e enviados por vez
ENDERECOS_MAX = 3           # endereços de um mesmo nome tentados por conexão
# Metadados das nuvens em IPv6: fora da faixa de enlace, então são recusados pelo nome da rede.
RECUSADAS = (ipaddress.ip_network('fd00:ec2::/32'),)


class Falha(Exception):
    """Envio que não deu certo. `motivo` é uma palavra: dns, endereco, conexao, tls, tempo, resposta, recusado,
    nao_encontrado, limite, arquivo ou http_<código>."""

    def __init__(self, motivo):
        super().__init__(motivo)
        self.motivo = motivo


def analisar(endereco):
    """`https://nome[:porta]` ➜ (nome, porta). Qualquer outra coisa é recusada."""
    casa = ENDERECO_HTTPS.fullmatch(endereco or '')
    if not casa:
        raise Falha('endereco')
    porta = int(casa.group(2) or 443)
    if not 1 <= porta <= 65535:
        raise Falha('endereco')
    return casa.group(1), porta


def aceito(texto):
    """O endereço para onde a conexão iria pode receber um pedido do painel?"""
    try:
        ip = ipaddress.ip_address(texto.split('%')[0])
    except ValueError:
        return False
    if ip.version == 6 and ip.ipv4_mapped is not None:
        ip = ip.ipv4_mapped
    if ip.is_loopback or ip.is_link_local or ip.is_multicast or ip.is_unspecified or ip.is_reserved:
        return False
    return not any(ip.version == rede.version and ip in rede for rede in RECUSADAS)


def contexto():
    ctx = ssl.create_default_context()
    ctx.minimum_version = ssl.TLSVersion.TLSv1_2
    if os.path.isfile(ARQ_CA):
        try:
            ctx.load_verify_locations(ARQ_CA)
        except (OSError, ssl.SSLError):
            raise Falha('tls') from None
    return ctx


def motivo_de(erro):
    """A exceção de uma tentativa ➜ o motivo, em uma palavra."""
    if isinstance(erro, Falha):
        return erro.motivo
    if isinstance(erro, ssl.SSLError):
        return 'tls'
    if isinstance(erro, TimeoutError):
        return 'tempo'
    if isinstance(erro, socket.gaierror):
        return 'dns'
    if isinstance(erro, http.client.HTTPException):
        return 'resposta'
    return 'conexao'


class Ligacao(http.client.HTTPSConnection):
    """Conexão com um serviço de fora. Reabre sozinha no pedido seguinte quando o outro lado fecha."""

    def __init__(self, endereco, prazo=PRAZO):
        nome, porta = analisar(endereco)
        self.seguro = contexto()
        self.pedidos = 0   # pedidos respondidos nesta conexão: no primeiro, falha de conexão não é repetida
        super().__init__(nome, porta, timeout=prazo, context=self.seguro)

    def connect(self):
        try:
            achados = socket.getaddrinfo(self.host, self.port, type=socket.SOCK_STREAM)
        except socket.gaierror:
            raise Falha('dns') from None
        # IPv4 primeiro: o container do painel só tem IPv6 quando a rede da stack tem.
        destinos = sorted({(familia != socket.AF_INET, alvo[0]) for familia, _, _, _, alvo in achados if aceito(alvo[0])})
        if not destinos:
            raise Falha('endereco')
        erro = None
        for _, ip in destinos[:ENDERECOS_MAX]:
            try:
                solto = socket.create_connection((ip, self.port), self.timeout)
                break
            except OSError as motivo:
                erro = motivo
        else:
            raise Falha(motivo_de(erro))
        try:
            self.sock = self.seguro.wrap_socket(solto, server_hostname=self.host)
        except BaseException:
            solto.close()
            raise
        self.pedidos = 0


def pedir(ligacao, metodo, caminho, cabecalhos, corpo=None, teto=RESPOSTA_MAX):
    """Faz um pedido e devolve (código, cabeçalhos, corpo). `corpo` é bytes ou uma função sem argumento que devolve os
    blocos a enviar: sendo função, o envio pode ser refeito do começo. Conexão que já tinha servido a um pedido e caiu
    neste é reaberta uma vez; resposta maior que o teto vem cortada e fecha a conexão."""
    for tentativa in (1, 2):
        reusada = ligacao.sock is not None and ligacao.pedidos > 0
        try:
            ligacao.request(metodo, caminho, body=corpo() if callable(corpo) else corpo, headers=cabecalhos)
            resposta = ligacao.getresponse()
            dados = resposta.read(teto + 1)
            if len(dados) > teto or resposta.will_close:
                ligacao.close()
            else:
                ligacao.pedidos += 1
            return resposta.status, resposta.headers, dados[:teto]
        except Falha:
            ligacao.close()
            raise
        except (OSError, http.client.HTTPException) as erro:
            ligacao.close()
            caiu = isinstance(erro, (ConnectionError, http.client.RemoteDisconnected, http.client.BadStatusLine))
            if tentativa == 1 and reusada and caiu:
                continue
            raise Falha(motivo_de(erro)) from None
    raise Falha('conexao')


def blocos(descritor, inicio, quanto):
    """Os bytes de um arquivo aberto, de `inicio` em diante, em blocos. Arquivo que encolheu no meio é falha."""
    feito = 0
    while feito < quanto:
        pedaco = os.pread(descritor, min(BLOCO, quanto - feito), inicio + feito)
        if not pedaco:
            raise Falha('arquivo')
        feito += len(pedaco)
        yield pedaco
