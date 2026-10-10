# SPDX-License-Identifier: Apache-2.0
"""Cena do lado da marca na tela de entrada: cada equipamento manda o backup pelo FTPS e ele cai na própria pasta.
As telas de dentro levam a mesma cena, pequena, na faixa de cabeçalho (miniatura).

É enfeite (o texto ao lado diz o mesmo) e fica fora do leitor de tela. Tudo é HTML e CSS do próprio painel: a
profundidade vem de `transform` em três dimensões, o movimento só mexe em `transform` e `opacity`, e não há script,
imagem nem pedido de rede. A caixa de marcar antes da cena é o botão de pausar: quem a marca para o movimento, e o
navegador com movimento reduzido já recebe a cena parada (web/estilo.css).
"""
from icones import icone

FAIXAS = ('l1', 'l2', 'l3', 'l4')
EQUIPAMENTOS = ('roteador', 'switch', 'OLT', 'rádio')
PASTAS = ('roteador', 'switch', 'olt', 'radio')
# Os trilhos, na medida do palco (22 por 15): do equipamento ao muro e do muro à pasta, uma linha por faixa.
TRILHOS = ''.join(f'M3 {y}H9.9M12.1 {y}H19' for y in ('2.25', '5.75', '9.25', '12.75'))


def miniatura(quieta=False):
    """A cena na faixa de cabeçalho das telas de dentro: sem os nomes e sem girar. Os pacotes atravessam uma vez,
    na chegada à tela, e param; por isso não há botão de pausar. `quieta` é a tela que se recarrega sozinha: nela
    nada se mexe."""
    blocos = ''.join(f'<i class="bloco eq {f}"></i><i class="bloco gaveta {f}">{icone("pasta")}</i><i class="pacote {f}"></i>'
                     for f in FAIXAS)
    return (f'<div class="cena mini{" quieta" if quieta else ""}" aria-hidden="true"><div class="palco"><i class="chao"></i>'
            f'<svg class="trilhos" viewBox="0 0 22 15"><path d="{TRILHOS}"/></svg>{blocos}<i class="bloco muro"></i></div></div>')


def cena():
    blocos = ''.join(f'<i class="bloco eq {f}"></i><i class="bloco gaveta {f}">{icone("pasta")}</i>'
                     f'<i class="pacote {f}"></i><i class="pacote outro {f}"></i>' for f in FAIXAS)
    nomes = ''.join(f'<span class="placa de {f}">{nome}</span>' for f, nome in zip(FAIXAS, EQUIPAMENTOS))
    destinos = ''.join(f'<span class="placa para {f}">/{nome}</span>' for f, nome in zip(FAIXAS, PASTAS))
    return ('<div class="vitrine"><input class="pausa" id="pausa" type="checkbox">'
            f'<label class="pausa-rotulo" for="pausa"><span class="roda">{icone("pausa")}Pausar movimento</span>'
            f'<span class="parada">{icone("tocar")}Retomar movimento</span></label>'
            '<div class="cena" aria-hidden="true"><div class="palco"><i class="chao"></i>'
            f'<svg class="trilhos" viewBox="0 0 22 15"><path d="{TRILHOS}"/></svg>'
            f'{blocos}<i class="bloco muro"></i>{nomes}{destinos}'
            f'<span class="placa selo">{icone("cadeado")}FTPS</span></div></div></div>')
