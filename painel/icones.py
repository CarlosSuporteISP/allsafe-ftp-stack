# SPDX-License-Identifier: Apache-2.0
"""Ícones do painel: desenhos de linha próprios, em grade de 24, que saem dentro do HTML.

Nenhum arquivo de imagem, fonte ou script é pedido: cada tela leva, uma vez, o desenho dos ícones que ela usa
(um <symbol> por ícone), e cada uso é só uma referência a ele. A cor é a do texto em volta (currentColor) e o
traço vem do estilo.css; a política de conteúdo do painel não muda.
"""
import re

TRACOS = {
    'painel': 'M4 4h7v9H4zM13 4h7v5h-7zM13 11h7v9h-7zM4 15h7v5H4z',
    'usuarios': 'M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM2.5 20c0-3.3 2.9-6 6.5-6s6.5 2.7 6.5 6M16 4.3a3.5 3.5 0 0 1 0 6.4M18 14.3c2 .8 3.5 2.9 3.5 5.7',
    'usuario': 'M12 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zM5 20c0-3.3 3.1-6 7-6s7 2.7 7 6',
    'pasta': 'M3 7a2 2 0 0 1 2-2h4l2 2.5h8a2 2 0 0 1 2 2V17a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z',
    'arquivo': 'M7 3h7l5 5v11a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2zM14 3v5h5',
    'atalho': 'M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1',
    'escudo': 'M12 3l7 3v5c0 4.5-3 8.3-7 10-4-1.7-7-5.5-7-10V6zM9 11.5l2.2 2.2 3.8-4',
    'cadeado': 'M6 11h12a1 1 0 0 1 1 1v7a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-7a1 1 0 0 1 1-1zM8 11V8a4 4 0 0 1 8 0v3',
    'cadeado-aberto': 'M6 11h12a1 1 0 0 1 1 1v7a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1v-7a1 1 0 0 1 1-1zM8 11V8a4 4 0 0 1 7.6-1.7',
    'atividade': 'M8 6h12M8 12h12M8 18h12M4 6h.01M4 12h.01M4 18h.01',
    'sair': 'M10 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h4M15 8l4 4-4 4M19 12H9',
    'servidor': 'M4 5h16v6H4zM4 13h16v6H4zM7.5 8h.01M7.5 16h.01',
    'disco': 'M4 6c0-1.7 3.6-3 8-3s8 1.3 8 3-3.6 3-8 3-8-1.3-8-3zM4 6v12c0 1.7 3.6 3 8 3s8-1.3 8-3V6M4 12c0 1.7 3.6 3 8 3s8-1.3 8-3',
    'envio': 'M12 15V4M8 8l4-4 4 4M4 15v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3',
    'baixar': 'M12 4v11M8 11l4 4 4-4M4 15v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3',
    'certificado': 'M12 14a5 5 0 1 0 0-10 5 5 0 0 0 0 10zM9 13.5V21l3-2 3 2v-7.5',
    'equipamento': 'M3 14h18v5H3zM7 16.5h.01M11 16.5h.01M17 14V9.5M13.6 6.4a4.8 4.8 0 0 1 6.8 0',
    'mais': 'M12 5v14M5 12h14',
    'ok': 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM8.5 12.5l2.5 2.5 4.5-5',
    'alerta': 'M12 4l9 16H3zM12 10v4M12 17h.01',
    'erro': 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM9 9l6 6M15 9l-6 6',
    'bloqueio': 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM5.6 5.6l12.8 12.8',
    'neutro': 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM8 12h8',
    'muro': 'M3 5h18v14H3zM3 9.7h18M3 14.3h18M9 5v4.7M15 9.7v4.6M9 14.3V19',
    'lupa': 'M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM20 20l-4-4',
    'chave': 'M8 19a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM10.8 12.2L20 3M16.5 6.5l3 3M14 9l2 2',
    'lapis': 'M4 20l1-4L16 5l3 3L8 19zM13.5 7.5l3 3',
    'lixeira': 'M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13M10 11v5M14 11v5',
    'inicio': 'M12 3v9M6.3 6.3a8 8 0 1 0 11.4 0',
    'terminal': 'M4 5h16v14H4zM7.5 9.5l3 2.5-3 2.5M13 15h3.5',
    'relogio': 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 7v5l3 2',
}
USO = re.compile(r'<use href="#i-([a-z-]+)"/>')


def icone(nome, rotulo='', classe=''):
    """Referência ao ícone. Sem rótulo ele é enfeite do texto ao lado; com rótulo, é ele que diz o estado ao leitor de tela."""
    if nome not in TRACOS:
        raise KeyError(nome)
    acesso = f'role="img" aria-label="{rotulo}"' if rotulo else 'aria-hidden="true"'
    return f'<svg class="i{" " + classe if classe else ""}" {acesso}><use href="#i-{nome}"/></svg>'


def desenhos(pagina):
    """Os <symbol> dos ícones que a página usa, em um <svg> que não ocupa lugar."""
    usados = sorted(set(USO.findall(pagina)) & TRACOS.keys())
    if not usados:
        return ''
    return ('<svg class="desenhos" aria-hidden="true">'
            + ''.join(f'<symbol id="i-{nome}" viewBox="0 0 24 24"><path d="{TRACOS[nome]}"/></symbol>' for nome in usados) + '</svg>')
