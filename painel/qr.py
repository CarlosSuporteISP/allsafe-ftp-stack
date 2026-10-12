# SPDX-License-Identifier: Apache-2.0
"""Código QR desenhado pelo próprio painel, em SVG, sem biblioteca de fora e sem JavaScript.

Serve para um uso só: mostrar ao aplicativo autenticador o endereço `otpauth://` do segundo fator. Por isso é a
parte da norma (ISO/IEC 18004) de que esse endereço precisa: modo de bytes, correção de erro M, versões 1 a 10
(até 213 bytes). Texto maior que isso é recusado com ValueError."""

# Versão ➜ (codewords de correção por bloco, quantidade de blocos, total de codewords), na correção M.
VERSOES = {1: (10, 1, 26), 2: (16, 1, 44), 3: (26, 1, 70), 4: (18, 2, 100), 5: (24, 2, 134),
           6: (16, 4, 172), 7: (18, 4, 196), 8: (22, 4, 242), 9: (22, 5, 292), 10: (26, 5, 346)}
ALINHAMENTO = {1: (), 2: (6, 18), 3: (6, 22), 4: (6, 26), 5: (6, 30), 6: (6, 34), 7: (6, 22, 38), 8: (6, 24, 42),
               9: (6, 26, 46), 10: (6, 28, 50)}
MASCARAS = (lambda x, y: (x + y) % 2 == 0, lambda x, y: y % 2 == 0, lambda x, y: x % 3 == 0,
            lambda x, y: (x + y) % 3 == 0, lambda x, y: (x // 3 + y // 2) % 2 == 0,
            lambda x, y: x * y % 2 + x * y % 3 == 0, lambda x, y: (x * y % 2 + x * y % 3) % 2 == 0,
            lambda x, y: ((x + y) % 2 + x * y % 3) % 2 == 0)
MARGEM = 4    # módulos claros em volta, o mínimo que a norma pede


def vezes(a, b):
    """Produto no corpo de 256 elementos da correção de erro (polinômio 0x11D)."""
    produto = 0
    for bit in range(7, -1, -1):
        produto = (produto << 1) ^ ((produto >> 7) * 0x11D)
        produto ^= ((b >> bit) & 1) * a
    return produto


def divisor(grau):
    """Polinômio gerador da correção de erro, sem o termo de maior grau."""
    coeficientes, raiz = [0] * (grau - 1) + [1], 1
    for _ in range(grau):
        for i in range(grau):
            coeficientes[i] = vezes(coeficientes[i], raiz)
            if i + 1 < grau:
                coeficientes[i] ^= coeficientes[i + 1]
        raiz = vezes(raiz, 2)
    return coeficientes


def resto(dados, gerador):
    sobra = [0] * len(gerador)
    for byte in dados:
        fator = byte ^ sobra.pop(0)
        sobra.append(0)
        for i, coeficiente in enumerate(gerador):
            sobra[i] ^= vezes(coeficiente, fator)
    return sobra


def codewords(texto):
    """(versão, codewords já com a correção de erro e intercalados) da menor versão em que o texto cabe."""
    for versao, (correcao, blocos, total) in VERSOES.items():
        capacidade = total - correcao * blocos
        contagem = 8 if versao < 10 else 16
        if 4 + contagem + 8 * len(texto) <= 8 * capacidade:
            break
    else:
        raise ValueError('texto longo demais para o código QR')
    bits = [0, 1, 0, 0] + [(len(texto) >> i) & 1 for i in range(contagem - 1, -1, -1)]
    for byte in texto:
        bits += [(byte >> i) & 1 for i in range(7, -1, -1)]
    bits += [0] * min(4, 8 * capacidade - len(bits))
    bits += [0] * (-len(bits) % 8)
    dados = [int(''.join(map(str, bits[i:i + 8])), 2) for i in range(0, len(bits), 8)]
    dados += [(0xEC, 0x11)[i % 2] for i in range(capacidade - len(dados))]
    # Os blocos curtos vêm primeiro; os longos têm um codeword de dados a mais.
    curtos, tamanho = blocos - capacidade % blocos, capacidade // blocos
    gerador, partes, inicio = divisor(correcao), [], 0
    for bloco in range(blocos):
        fim = inicio + tamanho + (bloco >= curtos)
        partes.append((dados[inicio:fim], resto(dados[inicio:fim], gerador)))
        inicio = fim
    saida = [parte[0][i] for i in range(tamanho + 1) for parte in partes if i < len(parte[0])]
    saida += [parte[1][i] for i in range(correcao) for parte in partes]
    return versao, saida


def matriz(texto):
    """O código QR do texto (bytes): lista de linhas, cada módulo True quando é escuro."""
    versao, dados = codewords(bytes(texto))
    lado = 17 + 4 * versao
    modulos = [[False] * lado for _ in range(lado)]
    fixos = [[False] * lado for _ in range(lado)]

    def fixar(x, y, escuro):
        modulos[y][x], fixos[y][x] = bool(escuro), True

    for i in range(lado):
        fixar(6, i, i % 2 == 0)
        fixar(i, 6, i % 2 == 0)
    for cx, cy in ((3, 3), (lado - 4, 3), (3, lado - 4)):
        for dy in range(-4, 5):
            for dx in range(-4, 5):
                if 0 <= cx + dx < lado and 0 <= cy + dy < lado:
                    fixar(cx + dx, cy + dy, max(abs(dx), abs(dy)) not in (2, 4))
    centros = ALINHAMENTO[versao]
    for cx in centros:
        for cy in centros:
            if (cx, cy) in ((6, 6), (6, centros[-1]), (centros[-1], 6)):
                continue    # ali ficam os três quadrados de canto
            for dy in range(-2, 3):
                for dx in range(-2, 3):
                    fixar(cx + dx, cy + dy, max(abs(dx), abs(dy)) != 1)

    def formato(mascara):
        # Correção M é 00 nos dois primeiros bits: o dado é só o número da máscara.
        sobra = mascara
        for _ in range(10):
            sobra = (sobra << 1) ^ ((sobra >> 9) * 0x537)
        bits = (mascara << 10 | sobra) ^ 0x5412
        for i in range(6):
            fixar(8, i, bits >> i & 1)
        fixar(8, 7, bits >> 6 & 1)
        fixar(8, 8, bits >> 7 & 1)
        fixar(7, 8, bits >> 8 & 1)
        for i in range(9, 15):
            fixar(14 - i, 8, bits >> i & 1)
        for i in range(8):
            fixar(lado - 1 - i, 8, bits >> i & 1)
        for i in range(8, 15):
            fixar(8, lado - 15 + i, bits >> i & 1)
        fixar(8, lado - 8, True)

    formato(0)    # reserva o lugar; o valor certo entra depois de escolhida a máscara
    if versao >= 7:
        sobra = versao
        for _ in range(12):
            sobra = (sobra << 1) ^ ((sobra >> 11) * 0x1F25)
        bits = versao << 12 | sobra
        for i in range(18):
            fixar(lado - 11 + i % 3, i // 3, bits >> i & 1)
            fixar(i // 3, lado - 11 + i % 3, bits >> i & 1)

    # Os dados sobem e descem em colunas de dois módulos, da direita para a esquerda, pulando a coluna 6.
    posicao = 0
    for direita in range(lado - 1, 0, -2):
        if direita <= 6:
            direita -= 1
        for passo in range(lado):
            for lado_da_coluna in range(2):
                x = direita - lado_da_coluna
                y = lado - 1 - passo if (direita + 1) & 2 == 0 else passo
                if not fixos[y][x] and posicao < 8 * len(dados):
                    modulos[y][x] = bool(dados[posicao >> 3] >> (7 - (posicao & 7)) & 1)
                    posicao += 1

    def mascarar(mascara):
        regra = MASCARAS[mascara]
        for y in range(lado):
            for x in range(lado):
                if not fixos[y][x] and regra(x, y):
                    modulos[y][x] = not modulos[y][x]

    melhor, menor = 0, None
    for mascara in range(8):
        mascarar(mascara)
        formato(mascara)
        pena = penalidade(modulos)
        if menor is None or pena < menor:
            melhor, menor = mascara, pena
        mascarar(mascara)    # aplicar de novo desfaz
    mascarar(melhor)
    formato(melhor)
    return modulos


def penalidade(modulos):
    """Quanto a máscara atrapalha a leitura, pelas quatro regras da norma; a menor ganha."""
    lado, pena = len(modulos), 0
    colunas = [list(coluna) for coluna in zip(*modulos)]
    padrao = [True, False, True, True, True, False, True, False, False, False, False]
    for linhas in (modulos, colunas):
        for linha in linhas:
            seguidos = 1
            for i in range(1, lado):
                seguidos = seguidos + 1 if linha[i] == linha[i - 1] else 1
                if seguidos == 5:
                    pena += 3
                elif seguidos > 5:
                    pena += 1
            for i in range(lado - 10):
                if linha[i:i + 11] in (padrao, padrao[::-1]):
                    pena += 40
    for y in range(lado - 1):
        for x in range(lado - 1):
            if modulos[y][x] == modulos[y][x + 1] == modulos[y + 1][x] == modulos[y + 1][x + 1]:
                pena += 3
    escuros = sum(map(sum, modulos))
    return pena + 10 * (abs(20 * escuros - 10 * lado * lado) // (lado * lado))


def svg(modulos, rotulo):
    """O código em SVG, preto sobre branco nos dois temas: é o contraste que a câmera lê. `rotulo` já vem escapado."""
    lado = len(modulos) + 2 * MARGEM
    tracos = ''.join(f'M{x + MARGEM} {y + MARGEM}h1v1h-1z' for y, linha in enumerate(modulos)
                     for x, escuro in enumerate(linha) if escuro)
    return (f'<svg class="qr" role="img" aria-label="{rotulo}" viewBox="0 0 {lado} {lado}" shape-rendering="crispEdges">'
            f'<rect width="{lado}" height="{lado}" fill="#fff"/><path fill="#000" d="{tracos}"/></svg>')
