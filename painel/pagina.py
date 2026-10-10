# SPDX-License-Identifier: Apache-2.0
"""Moldura das telas e os textos que mais de uma aba usa."""
import html
import re
import time

import idioma
from cena import miniatura
from config import CFG
from estado import dias_restantes, sem_tls
from icones import desenhos, icone
from idioma import N, t

ABAS = (('/', 'painel', N('Visão geral')), ('/usuarios', 'usuarios', N('Usuários')), ('/arquivos', 'pasta', N('Arquivos')),
        ('/servidor', 'pulso', N('Servidor')), ('/seguranca', 'cadeado', N('Segurança')),
        ('/bloqueios', 'bloqueio', N('Bloqueios')), ('/atividade', 'atividade', N('Atividade')))
ABAS_USUARIO = (('/meus-arquivos', 'pasta', N('Meus arquivos')),)
ABAS_SOENVIO = (('/meus-arquivos', 'envio', N('Envio de arquivos')),)   # perfil só envio: sem lista de arquivos
# Menu lateral do administrador: o dia a dia em cima, o que cuida do próprio painel embaixo.
GRUPOS = ((N('Operação'), ABAS[:3]), (N('Sistema'), ABAS[3:]))
# Título da aba, em português ➜ ícone dela no menu: é o mesmo que abre a faixa de cabeçalho da tela.
DESENHO_DA_ABA = {rotulo: desenho for _, desenho, rotulo in ABAS + ABAS_USUARIO + ABAS_SOENVIO}
# Estado de um item conferido ➜ (ícone, o que o leitor de tela diz). A cor acompanha, mas nunca é o único sinal.
ESTADOS = {'bom': ('ok', N('em ordem')), 'atencao': ('alerta', N('atenção')), 'ruim': ('erro', N('problema')),
           'neutro': ('neutro', N('não se aplica')), 'manual': ('muro', N('conferir no servidor'))}
# Autoria: aparece no rodapé de todas as telas e fica também em quem troca a logo e o ícone (web/marca/).
AUTORIA = ('<a href="https://allsafe.inf.br" target="_blank" rel="noopener noreferrer">allsafe.inf.br</a> · '
           '<a href="https://github.com/allsafe-inf" target="_blank" rel="noopener noreferrer">github.com/allsafe-inf</a>')


def e(texto):
    return html.escape(str(texto), quote=True)


def tamanho(valor):
    """Tamanho com a unidade; o espaço entre os dois é o não separável, para o número não ficar numa linha e a unidade na outra."""
    for unidade in ('B', 'KiB', 'MiB', 'GiB', 'TiB'):
        if valor < 1024 or unidade == 'TiB':
            return f'{valor:.0f} {unidade}' if unidade == 'B' else idioma.decimal(f'{valor:.1f}') + f' {unidade}'
        valor /= 1024
    return ''


def marca(estado):
    """Ícone de um estado de ESTADOS, com a cor dele e o nome para o leitor de tela."""
    desenho, rotulo = ESTADOS[estado]
    return icone(desenho, t(rotulo), estado)


def quando(instante):
    return time.strftime(idioma.formato_da_data() + ' %H:%M', time.localtime(instante)) if instante else '—'


def data_inteira(texto):
    """O texto, já escapado, com a data ano-mês-dia numa marca que não parte: o navegador dobraria a linha no hífen."""
    return re.sub(r'\d{4}-\d{2}-\d{2}', r'<span class="data">\g<0></span>', texto)


def alerta_tls():
    """Aviso das telas enquanto o FTP aceita sessão sem criptografia: FTP_TLS_MODE 0 ou 1, ou usuário dispensado do TLS."""
    resto = t('Use só para equipamento antigo sem suporte a TLS, em rede interna isolada, e volte para '
              '<code>FTP_TLS_MODE=2</code> assim que puder.') + '</p>'
    if CFG['ftp_tls'] == '0':
        return ('<p class="aviso" role="alert">'
                + t('O FTP está <strong>sem TLS</strong> (<code>FTP_TLS_MODE=0</code>): '
                    'senhas e arquivos trafegam em texto puro e podem ser lidos por quem estiver na mesma rede.') + ' ' + resto)
    if CFG['ftp_tls'] == '1':
        return ('<p class="aviso" role="alert">'
                + t('O TLS do FTP está <strong>opcional</strong> (<code>FTP_TLS_MODE=1</code>): '
                    'quem entra sem TLS manda senha e arquivos em texto puro.') + ' ' + resto)
    marcados = sem_tls() if CFG['tls_excecoes'] else []
    if marcados:
        return ('<p class="aviso" role="alert">'
                + t('<strong>{quantos} usuário(s) entram no FTP sem TLS</strong> ({nomes}): a senha e os arquivos deles '
                    'trafegam em texto puro e podem ser lidos por quem estiver na mesma rede. Use só para equipamento antigo '
                    'sem suporte a TLS, em rede interna isolada, e volte a exigir o TLS em <a href="/usuarios">Usuários</a> '
                    'assim que puder.', quantos=len(marcados), nomes=e(', '.join(marcados))) + '</p>')
    return ''


def validade(info):
    dias = dias_restantes(info)
    if dias is None:
        return 'atencao', t('não foi possível ler o certificado')
    data = info['vence'].astimezone().strftime(idioma.formato_da_data())
    if dias < 0:
        return 'ruim', t('vencido em {data}', data=data)
    return ('atencao' if dias < 30 else 'bom'), t('válido até {data} ({dias} dias)', data=data, dias=dias)


def aviso_oculto():
    """A instalação está publicada e quem instalou pediu que a tela não avise (PAINEL_AVISO_EXPOSICAO=nao)."""
    return not CFG.get('aviso_exposicao', True) and bool(CFG.get('ip_publico') or CFG.get('proxies'))


def publicado():
    """A instalação aceita endereço público ou está atrás de proxy, e o aviso disso não foi ocultado."""
    return bool(CFG.get('ip_publico') or CFG.get('proxies')) and not aviso_oculto()


def aviso_rede():
    """Como esta instalação está publicada, para o administrador: começo da aba Segurança.

    Expor à internet é opção de quem instala. A tela de entrada não diz nada disso: quem ainda não entrou não fica
    sabendo como o painel está publicado. Com PAINEL_AVISO_EXPOSICAO=nao o aviso some também daqui, do menu e do
    rodapé: o estado continua nas linhas da aba Segurança e na saída do deploy.sh.
    """
    if aviso_oculto():
        return ''
    avisos = ''
    if CFG.get('ip_publico'):
        avisos += ('<p class="aviso">'
                   + t('Endereço público aceito (<code>REDE_PERMITIR_IP_PUBLICO=sim</code>), por opção de quem '
                       'instalou. FTP e painel na internet são alvo de varredura e de tentativa de senha o tempo todo: mantenha o '
                       'firewall do servidor liberando só os endereços dos equipamentos e de quem administra.') + '</p>')
    if CFG.get('proxies'):
        avisos += ('<p class="aviso">'
                   + t('Painel publicado por proxy ou túnel (<code>PAINEL_PROXY_CONFIAVEL</code>), por opção de '
                       'quem instalou. Quem chega à tela de entrada é decidido lá: restrinja o acesso no proxy ou no túnel. O FTP '
                       'não passa por ele.') + '</p>')
    return avisos


def cabeca(titulo, resumo, acao='', quieta=False):
    """Começo de toda aba do menu, em faixa com as cores da tela de entrada: o ícone da aba, o título, uma linha que
    diz o que a tela mostra, a cena da entrada em miniatura e, à direita, a ação principal da tela. `titulo` é o nome
    da aba em português, como está em ABAS: sai aqui no idioma do pedido."""
    return (f'<div class="cabeca"><span class="selo-aba">{icone(DESENHO_DA_ABA.get(titulo, "painel"))}</span>'
            f'<div><h1 class="titulo-aba">{t(titulo)}</h1><p class="suave">{resumo}</p></div>{miniatura(quieta)}{acao}</div>')


def vazio(colunas, desenho, titulo, texto):
    """Linha de uma tabela sem nada para mostrar: o que falta e quando passa a aparecer."""
    return (f'<tr class="vazio"><td colspan="{colunas}"><div>{icone(desenho)}<strong>{titulo}</strong>'
            f'<span class="suave">{texto}</span></div></td></tr>')


def como(titulo, miolo):
    """Explicação longa de uma tela, recolhida: abre com um clique, sem script."""
    return f'<details class="como"><summary>{titulo}</summary>{miolo}</details>'


def troca_de_idioma(campo, valor):
    """Os botões de idioma: um formulário pequeno, enviado por POST, que volta para a tela de onde saiu. `campo` é o
    token que vai junto: o `csrf` da sessão ou, na tela de entrada, o `token` do formulário dela."""
    botoes = ''.join(f'<button type="submit" name="idioma" value="{codigo}" lang="{da_lingua}" title="{nome}" '
                     f'aria-pressed="{"true" if codigo == idioma.atual() else "false"}">{sigla}'
                     f'<span class="so-leitor"> {nome}</span></button>'
                     for codigo, (sigla, nome, da_lingua) in idioma.NOMES.items())
    return (f'<form class="idioma" method="post" action="/idioma"><input type="hidden" name="{campo}" value="{e(valor)}">'
            f'<div role="group" aria-label="{t("Idioma das telas")}">{botoes}</div></form>')


def menu_lateral(sessao, ativa):
    """Menu, o idioma, quem está na sessão e a saída. Em tela larga fica na lateral; na estreita, vira a faixa de cima."""
    admin = not sessao['usuario']
    grupos = GRUPOS if admin else (('', ABAS_SOENVIO if sessao['perfil'] == 'soenvio' else ABAS_USUARIO),)
    links = ''
    for grupo, abas in grupos:
        links += f'<span class="grupo">{t(grupo)}</span>' if grupo else ''
        for caminho, desenho, rotulo in abas:
            # Instalação publicada: o administrador vê a marca na aba que explica, em qualquer tela em que estiver.
            # É um desenho, e não uma etiqueta escrita: cabe no menu estreito e na faixa de cima sem cortar.
            sinal = (f'<span class="sinal" title="{t("Esta instalação está publicada fora da rede privada: veja como nesta aba")}">'
                     f'{icone("alerta")}<span class="so-leitor"> {t("(instalação publicada)")}</span></span>'
                     ) if caminho == '/seguranca' and publicado() else ''
            links += (f'<a href="{caminho}"' + (' class="ativa" aria-current="page"' if caminho == ativa else '')
                      + f'>{icone(desenho)}{t(rotulo)}{sinal}</a>')
    nome, papel = (sessao['admin'], t('Administrador')) if admin else (sessao['usuario'], t('Usuário do FTP'))
    return (f'<nav aria-label="{t("Abas do painel")}">{links}</nav>{troca_de_idioma("csrf", sessao["csrf"])}'
            '<form class="sair" method="post" action="/sair">'
            f'<input type="hidden" name="csrf" value="{e(sessao["csrf"])}">'
            f'<span class="avatar">{icone("escudo" if admin else "usuario")}</span><span class="quem">{e(nome)}<span>{papel}</span>'
            f'</span><button type="submit">{icone("sair")}{t("Sair")}</button></form>')


def pagina(titulo, miolo, sessao=None, ativa='', porta=False):
    """Moldura de toda tela. `porta` é a tela de entrada: sem o menu, com a marca dentro dela. `titulo` já vem no
    idioma do pedido.

    Com sessão, o corpo leva `com-menu`: é o que deixa o menu na lateral em tela larga. Tela de recusa sem sessão
    fica só com a marca em cima.
    """
    topo = ''
    if not porta:
        topo = ('<header><span class="marca-topo"><img src="/marca/simbolo-64.png" alt="" width="28" height="28">AllSafe FTP</span>'
                f'{menu_lateral(sessao, ativa) if sessao else ""}</header>\n')
    # Como a instalação está publicada só vai ao rodapé do administrador: quem não entrou e o usuário do FTP não leem.
    rede = ''
    if not (CFG.get('ip_publico') or CFG.get('proxies')):
        rede = ' · ' + t('só para rede privada, atrás de firewall')
    elif sessao and not sessao['usuario'] and not aviso_oculto():
        rede = ' · ' + ' · '.join(filter(None, (t('endereço público aceito: confira o firewall') if CFG.get('ip_publico') else '',
                                                 t('painel publicado por proxy ou túnel') if CFG.get('proxies') else '')))
    corpo = f"""<a class="pular" href="#conteudo">{t('Pular para o conteúdo')}</a>
{topo}<main id="conteudo">
{miolo}
</main>
<footer>
<p>allsafe-ftp-stack v{e(CFG.get('versao', '?'))}{rede}</p>
<p class="autoria">{t('Desenvolvido pela')} {AUTORIA}</p>
</footer>
"""
    return f"""<!doctype html>
<html lang="{idioma.da_pagina()}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<meta name="color-scheme" content="dark light">
<meta name="theme-color" content="#0e2648">
<title>{e(titulo)} · AllSafe FTP</title>
<link rel="icon" href="/favicon.ico" sizes="16x16 32x32 48x48">
<link rel="icon" href="/marca/icone-32.png" type="image/png" sizes="32x32">
<link rel="icon" href="/marca/icone-192.png" type="image/png" sizes="192x192">
<link rel="apple-touch-icon" href="/marca/apple-touch-icon.png">
<link rel="stylesheet" href="/estilo.css{'?v=' + CFG['estilo'] if CFG.get('estilo') else ''}">
</head>
<body{' class="porta"' if porta else ' class="com-menu"' if sessao else ''}>
{corpo}{desenhos(corpo)}
</body>
</html>
"""
