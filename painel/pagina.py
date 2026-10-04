"""Moldura das telas e os textos que mais de uma aba usa."""
import html
import time

from config import CFG
from estado import dias_restantes

ABAS = (('/', '📊 Visão geral'), ('/usuarios', '👥 Usuários'), ('/seguranca', '🔐 Segurança'), ('/atividade', '📜 Atividade'))
ICONE = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><rect width="16" height="16" rx="3" fill="#0d1117"/>'
         '<path d="M3 5h10v2H3zm0 4h10v2H3z" fill="#58a6ff"/></svg>')


def e(texto):
    return html.escape(str(texto), quote=True)


def tamanho(valor):
    for unidade in ('B', 'KiB', 'MiB', 'GiB', 'TiB'):
        if valor < 1024 or unidade == 'TiB':
            return f'{valor:.0f} {unidade}' if unidade == 'B' else f'{valor:.1f} {unidade}'.replace('.', ',')
        valor /= 1024
    return ''


def quando(instante):
    return time.strftime('%d/%m/%Y %H:%M', time.localtime(instante)) if instante else '—'


def alerta_tls():
    """Aviso das telas enquanto o FTP aceita sessão sem criptografia (FTP_TLS_MODE 0 ou 1)."""
    resto = ('Use só para equipamento antigo sem suporte a TLS, em rede interna isolada, e volte para '
             '<code>FTP_TLS_MODE=2</code> assim que puder.</p>')
    if CFG['ftp_tls'] == '0':
        return ('<p class="aviso" role="alert">⚠️ O FTP está <strong>sem TLS</strong> (<code>FTP_TLS_MODE=0</code>): '
                'senhas e arquivos trafegam em texto puro e podem ser lidos por quem estiver na mesma rede. ' + resto)
    if CFG['ftp_tls'] == '1':
        return ('<p class="aviso" role="alert">⚠️ O TLS do FTP está <strong>opcional</strong> (<code>FTP_TLS_MODE=1</code>): '
                'quem entra sem TLS manda senha e arquivos em texto puro. ' + resto)
    return ''


def validade(info):
    dias = dias_restantes(info)
    if dias is None:
        return '⚠️', 'não foi possível ler o certificado'
    data = info['vence'].astimezone().strftime('%d/%m/%Y')
    if dias < 0:
        return '❌', f'vencido em {data}'
    return ('⚠️' if dias < 30 else '✅'), f'válido até {data} ({dias} dias)'


def aviso_rede():
    if CFG.get('ip_publico'):
        return ('<p class="aviso">⚠️ Endereço público aceito (<code>REDE_PERMITIR_IP_PUBLICO=sim</code>). FTP e painel na internet '
                'são alvo de varredura e de tentativa de senha o tempo todo: mantenha o firewall do servidor liberando só os '
                'endereços dos equipamentos e de quem administra.</p>')
    return '<p class="aviso">🧱 Uso só em rede privada, atrás de firewall. FTP e painel recusam, por código, escutar em IP público.</p>'


def pagina(titulo, miolo, sessao=None, ativa=''):
    menu = ''
    if sessao:
        links = ''.join(f'<a href="{caminho}"' + (' class="ativa" aria-current="page"' if caminho == ativa else '') + f'>{rotulo}</a>'
                        for caminho, rotulo in ABAS)
        menu = (f'<nav aria-label="Abas do painel">{links}<form method="post" action="/sair">'
                f'<input type="hidden" name="csrf" value="{e(sessao["csrf"])}"><button type="submit">🚪 Sair</button></form></nav>')
    return f'''<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>{e(titulo)} · AllSafe FTP</title>
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="stylesheet" href="/estilo.css">
</head>
<body>
<header><span class="marca-topo">🗄️ AllSafe FTP</span>{menu}</header>
<main>
{miolo}
</main>
<footer>allsafe-ftp-stack v{e(CFG.get('versao', '?'))} · {'⚠️ endereço público aceito: confira o firewall' if CFG.get('ip_publico') else '🧱 só para rede privada, atrás de firewall'}</footer>
</body>
</html>
'''
