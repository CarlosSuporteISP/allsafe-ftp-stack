# SPDX-License-Identifier: Apache-2.0
"""Gráficos do painel: SVG montado no servidor, sem script e sem estilo dentro do HTML.

A política de conteúdo do painel não aceita `style=""`: a medida de cada barra vai em atributo de geometria do SVG
(x, y, width, height) e a cor vem da classe, no estilo.css. Número e nome são sempre texto da página, ao lado do
desenho: o gráfico mostra a proporção, e quem usa leitor de tela recebe os mesmos valores.
"""

import itertools

from idioma import milhar

DESENHO = 'preserveAspectRatio="none" aria-hidden="true" focusable="false"'
AREAS = itertools.count(1)      # cada área leva um nome só dela: a página pode ter vários desenhos de linha


def numero(valor):
    """Inteiro com o separador de milhar do idioma do pedido."""
    return milhar(valor)


def colunas(valores, rotulos, unidade):
    """Colunas de um período, da mais antiga para a mais nova; a última é a de hoje.

    `rotulos` é o texto de baixo de cada coluna e `unidade`, o que o leitor de tela diz depois do número.
    A coluna mais alta leva a classe `pico`: em tela estreita só o valor dela e o de hoje ficam escritos.
    """
    maior = max(valores, default=0)
    itens = ''
    for posicao, (valor, rotulo) in enumerate(zip(valores, rotulos)):
        # Coluna com valor nunca some: a menor ainda tem 2% da altura.
        altura = max(round(100 * valor / maior, 1), 2) if valor else 0
        classes = ' '.join(filter(None, ('hoje' if posicao == len(valores) - 1 else '',
                                         'pico' if valor and valor == maior else '', '' if valor else 'vazio')))
        itens += (f'<li{f" class={chr(34)}{classes}{chr(34)}" if classes else ""}><span class="valor">{numero(valor)}'
                  f'<span class="so-leitor"> {unidade}, </span></span><svg viewBox="0 0 10 100" {DESENHO}>'
                  f'<rect x="0" y="{100 - altura:g}" width="10" height="{altura:g}"/></svg><span class="dia">{rotulo}</span></li>')
    return f'<ol class="colunas">{itens}</ol>'


def faixa(partes):
    """Uma barra dividida em partes e a legenda dela. `partes`: (tom, quantidade, texto), na ordem em que aparecem.

    O tom é a classe de cor (bom, info, atencao, ruim, neutro). Parte com zero não é desenhada, mas fica na legenda.
    """
    legenda = ''.join(f'<li><span class="chave {tom}"></span><strong>{numero(quantidade)}</strong> {texto}</li>'
                      for tom, quantidade, texto in partes)
    return f'{tira([(tom, quantidade) for tom, quantidade, _ in partes])}<ul class="chaves">{legenda}</ul>'


def tira(partes, total=None):
    """Só a barra dividida em partes: (tom, quantidade). Sem `total`, as partes enchem a barra; com ele, o que falta
    para o total fica vazio, que é o caso da medida de uso (processador, memória, disco)."""
    total = total or sum(quantidade for _, quantidade in partes)
    barras_, inicio = '', 0.0
    for tom, quantidade in partes:
        if quantidade > 0 and total:
            largura = min(100 * quantidade / total, 100 - inicio)
            # O vão entre duas partes é o fundo da barra aparecendo.
            barras_ += f'<rect class="{tom}" x="{inicio:.2f}" y="0" width="{max(largura - 0.5, 0.5):.2f}" height="4"/>'
            inicio += largura
    return f'<svg class="faixa" viewBox="0 0 100 4" {DESENHO}>{barras_}</svg>'


def linha(series, teto):
    """Linhas de um período, da amostra mais antiga, na esquerda, à mais nova, na direita: o que há ocupa a largura
    toda, e quem chama escreve de quanto tempo é. `series`: (tom, valores); `teto` é o valor do topo do desenho.
    A primeira série leva a área embaixo da linha, na cor do tom e mais clara perto da base; a segunda sai tracejada.
    """
    desenho = ''
    for posicao, (tom, valores) in enumerate(series):
        if len(valores) < 2:
            continue
        passo = 100 / (len(valores) - 1)
        # A linha do zero fica um pouco acima da base, para o traço não ser cortado pela borda do desenho.
        pontos = ' '.join(f'{passo * vez:.2f},{38 - 36 * min(max(valor, 0), teto) / teto:.2f}'
                          for vez, valor in enumerate(valores))
        desenho += f'<g class="{tom}">'
        if posicao == 0:
            # O degradê fica dentro do grupo do tom, que é de onde vem a cor dele.
            area = f'area-{next(AREAS)}'
            desenho += (f'<linearGradient id="{area}" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="0" y2="40">'
                        '<stop offset="0" stop-opacity="0.4"/><stop offset="1" stop-opacity="0.03"/></linearGradient>'
                        f'<polygon fill="url(#{area})" points="0,40 {pontos} 100,40"/>')
        desenho += f'<polyline points="{pontos}"/></g>'
    return f'<svg class="linha" viewBox="0 0 100 40" {DESENHO}>{desenho}</svg>'


def barras(itens):
    """Barras deitadas, uma por linha: (nome, valor, valor por escrito). A maior ocupa a largura toda."""
    maior = max((valor for _, valor, _ in itens), default=0)
    linhas = ''
    for nome, valor, texto in itens:
        largura = max(100 * valor / maior, 1) if valor else 0
        linhas += (f'<li><span class="nome">{nome}</span><svg viewBox="0 0 100 4" {DESENHO}>'
                   f'<rect x="0" y="0" width="{largura:.2f}" height="4"/></svg><span class="valor">{texto}</span></li>')
    return f'<ul class="barras">{linhas}</ul>'
