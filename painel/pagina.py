# SPDX-License-Identifier: Apache-2.0
"""Moldura das telas e os textos que mais de uma aba usa."""
import html
import time

from config import CFG
from estado import dias_restantes, sem_tls

ABAS = (('/', '📊 Visão geral'), ('/usuarios', '👥 Usuários'), ('/arquivos', '📁 Arquivos'),
        ('/administradores', '🛡️ Administradores'), ('/seguranca', '🔐 Segurança'), ('/atividade', '📜 Atividade'))
ABAS_USUARIO = (('/meus-arquivos', '📁 Meus arquivos'),)
# Autoria: aparece no rodapé de todas as telas e fica também em quem troca a logo e o ícone (web/marca/).
AUTORIA = ('Desenvolvido pela <a href="https://allsafe.inf.br" target="_blank" rel="noopener noreferrer">allsafe.inf.br</a> · '
           '<a href="https://github.com/allsafe-inf" target="_blank" rel="noopener noreferrer">github.com/allsafe-inf</a>')


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
    """Aviso das telas enquanto o FTP aceita sessão sem criptografia: FTP_TLS_MODE 0 ou 1, ou usuário dispensado do TLS."""
    resto = ('Use só para equipamento antigo sem suporte a TLS, em rede interna isolada, e volte para '
             '<code>FTP_TLS_MODE=2</code> assim que puder.</p>')
    if CFG['ftp_tls'] == '0':
        return ('<p class="aviso" role="alert">⚠️ O FTP está <strong>sem TLS</strong> (<code>FTP_TLS_MODE=0</code>): '
                'senhas e arquivos trafegam em texto puro e podem ser lidos por quem estiver na mesma rede. ' + resto)
    if CFG['ftp_tls'] == '1':
        return ('<p class="aviso" role="alert">⚠️ O TLS do FTP está <strong>opcional</strong> (<code>FTP_TLS_MODE=1</code>): '
                'quem entra sem TLS manda senha e arquivos em texto puro. ' + resto)
    marcados = sem_tls() if CFG['tls_excecoes'] else []
    if marcados:
        return ('<p class="aviso" role="alert">⚠️ <strong>' + str(len(marcados)) + ' usuário(s) entram no FTP sem TLS</strong> ('
                + e(', '.join(marcados)) + '): a senha e os arquivos deles trafegam em texto puro e podem ser lidos por quem '
                'estiver na mesma rede. Use só para equipamento antigo sem suporte a TLS, em rede interna isolada, e volte a '
                'exigir o TLS em <a href="/usuarios">Usuários</a> assim que puder.</p>')
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
        abas, nome, papel = ((ABAS_USUARIO, sessao['usuario'], 'Usuário do FTP desta sessão') if sessao['usuario']
                             else (ABAS, sessao['admin'], 'Administrador desta sessão'))
        links = ''.join(f'<a href="{caminho}"' + (' class="ativa" aria-current="page"' if caminho == ativa else '') + f'>{rotulo}</a>'
                        for caminho, rotulo in abas)
        menu = (f'<nav aria-label="Abas do painel">{links}<form method="post" action="/sair">'
                f'<input type="hidden" name="csrf" value="{e(sessao["csrf"])}"><span class="quem" title="{papel}">'
                f'{e(nome)}</span><button type="submit">🚪 Sair</button></form></nav>')
    return f'''<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow">
<title>{e(titulo)} · AllSafe FTP</title>
<link rel="icon" href="/favicon.ico" sizes="16x16 32x32 48x48">
<link rel="icon" href="/marca/icone-32.png" type="image/png" sizes="32x32">
<link rel="icon" href="/marca/icone-192.png" type="image/png" sizes="192x192">
<link rel="apple-touch-icon" href="/marca/apple-touch-icon.png">
<link rel="stylesheet" href="/estilo.css">
</head>
<body>
<header><span class="marca-topo"><img src="/marca/simbolo-64.png" alt="" width="28" height="28">AllSafe FTP</span>{menu}</header>
<main>
{miolo}
</main>
<footer>
<p>allsafe-ftp-stack v{e(CFG.get('versao', '?'))} · {'⚠️ endereço público aceito: confira o firewall' if CFG.get('ip_publico') else '🧱 só para rede privada, atrás de firewall'}</p>
<p class="autoria">{AUTORIA}</p>
</footer>
</body>
</html>
'''
