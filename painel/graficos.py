# SPDX-License-Identifier: Apache-2.0
"""Gráficos do painel: SVG montado no servidor, sem script e sem estilo dentro do HTML.

A política de conteúdo do painel não aceita `style=""`: a medida de cada barra vai em atributo de geometria do SVG
(x, y, width, height) e a cor vem da classe, no estilo.css. Número e nome são sempre texto da página, ao lado do
desenho: o gráfico mostra a proporção, e quem usa leitor de tela recebe os mesmos valores.
"""

DESENHO = 'preserveAspectRatio="none" aria-hidden="true" focusable="false"'


def numero(valor):
    """Inteiro com o ponto de milhar."""
    return f'{valor:,}'.replace(',', '.')


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
    total = sum(quantidade for _, quantidade, _ in partes)
    barras_, inicio = '', 0.0
    for tom, quantidade, _ in partes:
        if quantidade:
            largura = 100 * quantidade / total
            # O vão entre duas partes é o fundo da barra aparecendo.
            barras_ += f'<rect class="{tom}" x="{inicio:.2f}" y="0" width="{max(largura - 0.5, 0.5):.2f}" height="4"/>'
            inicio += largura
    legenda = ''.join(f'<li><span class="chave {tom}"></span><strong>{numero(quantidade)}</strong> {texto}</li>'
                      for tom, quantidade, texto in partes)
    return f'<svg class="faixa" viewBox="0 0 100 4" {DESENHO}>{barras_}</svg><ul class="chaves">{legenda}</ul>'


def barras(itens):
    """Barras deitadas, uma por linha: (nome, valor, valor por escrito). A maior ocupa a largura toda."""
    maior = max((valor for _, valor, _ in itens), default=0)
    linhas = ''
    for nome, valor, texto in itens:
        largura = max(100 * valor / maior, 1) if valor else 0
        linhas += (f'<li><span class="nome">{nome}</span><svg viewBox="0 0 100 4" {DESENHO}>'
                   f'<rect x="0" y="0" width="{largura:.2f}" height="4"/></svg><span class="valor">{texto}</span></li>')
    return f'<ul class="barras">{linhas}</ul>'
