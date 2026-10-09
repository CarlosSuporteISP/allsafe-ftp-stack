# SPDX-License-Identifier: Apache-2.0
"""Moldura das telas e os textos que mais de uma aba usa."""
import html
import time

from config import CFG
from estado import dias_restantes, sem_tls
from icones import desenhos, icone

ABAS = (('/', 'painel', 'Visão geral'), ('/usuarios', 'usuarios', 'Usuários'), ('/arquivos', 'pasta', 'Arquivos'),
        ('/administradores', 'escudo', 'Administradores'), ('/seguranca', 'cadeado', 'Segurança'),
        ('/atividade', 'atividade', 'Atividade'))
ABAS_USUARIO = (('/meus-arquivos', 'pasta', 'Meus arquivos'),)
# Estado de um item conferido ➜ (ícone, o que o leitor de tela diz). A cor acompanha, mas nunca é o único sinal.
ESTADOS = {'bom': ('ok', 'em ordem'), 'atencao': ('alerta', 'atenção'), 'ruim': ('erro', 'problema'),
           'neutro': ('neutro', 'não se aplica'), 'manual': ('muro', 'conferir no servidor')}
# Autoria: aparece no rodapé de todas as telas e fica também em quem troca a logo e o ícone (web/marca/).
AUTORIA = ('Desenvolvido pela <a href="https://allsafe.inf.br" target="_blank" rel="noopener noreferrer">allsafe.inf.br</a> · '
           '<a href="https://github.com/allsafe-inf" target="_blank" rel="noopener noreferrer">github.com/allsafe-inf</a>')


def e(texto):
    return html.escape(str(texto), quote=True)


def tamanho(valor):
    """Tamanho com a unidade; o espaço entre os dois é o não separável, para o número não ficar numa linha e a unidade na outra."""
    for unidade in ('B', 'KiB', 'MiB', 'GiB', 'TiB'):
        if valor < 1024 or unidade == 'TiB':
            return f'{valor:.0f}\u00a0{unidade}' if unidade == 'B' else f'{valor:.1f}\u00a0{unidade}'.replace('.', ',')
        valor /= 1024
    return ''


def marca(estado):
    """Ícone de um estado de ESTADOS, com a cor dele e o nome para o leitor de tela."""
    desenho, rotulo = ESTADOS[estado]
    return icone(desenho, rotulo, estado)


def quando(instante):
    return time.strftime('%d/%m/%Y\u00a0%H:%M', time.localtime(instante)) if instante else '—'


def alerta_tls():
    """Aviso das telas enquanto o FTP aceita sessão sem criptografia: FTP_TLS_MODE 0 ou 1, ou usuário dispensado do TLS."""
    resto = ('Use só para equipamento antigo sem suporte a TLS, em rede interna isolada, e volte para '
             '<code>FTP_TLS_MODE=2</code> assim que puder.</p>')
    if CFG['ftp_tls'] == '0':
        return ('<p class="aviso" role="alert">O FTP está <strong>sem TLS</strong> (<code>FTP_TLS_MODE=0</code>): '
                'senhas e arquivos trafegam em texto puro e podem ser lidos por quem estiver na mesma rede. ' + resto)
    if CFG['ftp_tls'] == '1':
        return ('<p class="aviso" role="alert">O TLS do FTP está <strong>opcional</strong> (<code>FTP_TLS_MODE=1</code>): '
                'quem entra sem TLS manda senha e arquivos em texto puro. ' + resto)
    marcados = sem_tls() if CFG['tls_excecoes'] else []
    if marcados:
        return ('<p class="aviso" role="alert"><strong>' + str(len(marcados)) + ' usuário(s) entram no FTP sem TLS</strong> ('
                + e(', '.join(marcados)) + '): a senha e os arquivos deles trafegam em texto puro e podem ser lidos por quem '
                'estiver na mesma rede. Use só para equipamento antigo sem suporte a TLS, em rede interna isolada, e volte a '
                'exigir o TLS em <a href="/usuarios">Usuários</a> assim que puder.</p>')
    return ''


def validade(info):
    dias = dias_restantes(info)
    if dias is None:
        return 'atencao', 'não foi possível ler o certificado'
    data = info['vence'].astimezone().strftime('%d/%m/%Y')
    if dias < 0:
        return 'ruim', f'vencido em {data}'
    return ('atencao' if dias < 30 else 'bom'), f'válido até {data} ({dias} dias)'


def aviso_rede():
    """Como esta instalação está publicada. Expor à internet é opção de quem instala, e a tela diz quando está ligada."""
    avisos = ''
    if CFG.get('ip_publico'):
        avisos += ('<p class="aviso">Endereço público aceito (<code>REDE_PERMITIR_IP_PUBLICO=sim</code>), por opção de quem '
                   'instalou. FTP e painel na internet são alvo de varredura e de tentativa de senha o tempo todo: mantenha o '
                   'firewall do servidor liberando só os endereços dos equipamentos e de quem administra.</p>')
    if CFG.get('proxies'):
        avisos += ('<p class="aviso">Painel publicado por proxy ou túnel (<code>PAINEL_PROXY_CONFIAVEL</code>), por opção de '
                   'quem instalou. Quem chega a esta tela é decidido lá: restrinja o acesso no proxy ou no túnel. O FTP não '
                   'passa por ele.</p>')
    return avisos or ('<p class="nota">De fábrica, uso só em rede privada, atrás de firewall. Publicar o painel ou o FTP na '
                      'internet é opção de quem instala, e fica avisado aqui quando está ligada.</p>')


def cabeca(titulo, resumo, acao=''):
    """Começo de toda aba do menu: o título, uma linha que diz o que a tela mostra e, à direita, a ação principal dela."""
    return (f'<div class="cabeca"><div><h1 class="titulo-aba">{titulo}</h1><p class="suave">{resumo}</p></div>{acao}</div>')


def pagina(titulo, miolo, sessao=None, ativa='', porta=False):
    """Moldura de toda tela. `porta` é a tela de entrada: sem o topo, com a marca dentro dela."""
    topo = ''
    if not porta:
        menu = ''
        if sessao:
            abas, nome, papel = ((ABAS_USUARIO, sessao['usuario'], 'Usuário do FTP desta sessão') if sessao['usuario']
                                 else (ABAS, sessao['admin'], 'Administrador desta sessão'))
            links = ''.join(f'<a href="{caminho}"' + (' class="ativa" aria-current="page"' if caminho == ativa else '')
                            + f'>{icone(desenho)}{rotulo}</a>' for caminho, desenho, rotulo in abas)
            menu = (f'<nav aria-label="Abas do painel">{links}</nav><form class="sair" method="post" action="/sair">'
                    f'<input type="hidden" name="csrf" value="{e(sessao["csrf"])}"><span class="quem" title="{papel}">'
                    f'{e(nome)}</span><button type="submit">{icone("sair")}Sair</button></form>')
        topo = ('<header><span class="marca-topo"><img src="/marca/simbolo-64.png" alt="" width="28" height="28">AllSafe FTP</span>'
                f'{menu}</header>\n')
    rede = ' · '.join(filter(None, ('endereço público aceito: confira o firewall' if CFG.get('ip_publico') else '',
                                    'painel publicado por proxy ou túnel' if CFG.get('proxies') else ''))) \
        or 'só para rede privada, atrás de firewall'
    corpo = f"""<a class="pular" href="#conteudo">Pular para o conteúdo</a>
{topo}<main id="conteudo">
{miolo}
</main>
<footer>
<p>allsafe-ftp-stack v{e(CFG.get('versao', '?'))} · {rede}</p>
<p class="autoria">{AUTORIA}</p>
</footer>
"""
    return f"""<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<meta name="color-scheme" content="dark light">
<meta name="theme-color" content="#151c26" media="(prefers-color-scheme: dark)">
<meta name="theme-color" content="#fcfdff" media="(prefers-color-scheme: light)">
<title>{e(titulo)} · AllSafe FTP</title>
<link rel="icon" href="/favicon.ico" sizes="16x16 32x32 48x48">
<link rel="icon" href="/marca/icone-32.png" type="image/png" sizes="32x32">
<link rel="icon" href="/marca/icone-192.png" type="image/png" sizes="192x192">
<link rel="apple-touch-icon" href="/marca/apple-touch-icon.png">
<link rel="stylesheet" href="/estilo.css">
</head>
<body{' class="porta"' if porta else ''}>
{corpo}{desenhos(corpo)}
</body>
</html>
"""
