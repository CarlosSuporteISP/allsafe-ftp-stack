# SPDX-License-Identifier: Apache-2.0
"""Aba Bloqueios: os endereços que erraram usuário e senha demais e não entram mais no FTP nem no painel.

O administrador acompanha a lista, libera um endereço e muda o prazo de um que já está bloqueado. Quem bloqueia é o
vigia do FTP e o próprio painel (enderecos.py); no terminal, o manage-user.sh. A tela mostra também os bloqueios
curtos do FTP, de um usuário para um endereço, que são desfeitos em Editar, na aba Usuários."""
import math
import time
import urllib.parse

import enderecos
from auditoria import auditar
from config import CFG
from estado import bloqueios, executar_usuario
from icones import icone
from idioma import N, do_comando, t, tn
from pagina import cabeca, como, e, pagina, quando, vazio

MOSTRADOS = 500     # linhas da lista; acima disso, a busca
MOTIVO = {'ftp': N('{erros} erros no FTP'), 'painel': N('{erros} erros no painel')}
MENSAGENS = {'liberado': N('Endereço liberado: ele volta a entrar no FTP e no painel.'),
             'prazo': N('Prazo do bloqueio alterado.'),
             'ausente': N('Este endereço não está mais bloqueado.')}


def falta(expira):
    dias = math.ceil((expira - time.time()) / 86400)
    return t('menos de 1 dia') if dias <= 1 else t('{dias} dias', dias=dias)


def regra():
    """A regra em vigor, em uma frase, para o começo da tela."""
    if not CFG['endereco_erros']:
        return t('O bloqueio automático está desligado (<code>BLOQUEIO_ENDERECO_ERROS=0</code>): '
                 'aqui ficam só os endereços bloqueados pelo terminal.')
    return t('O endereço que passa de {erros} de usuário e senha em {horas}, no FTP ou no painel, fica {dias} sem entrar nos dois.',
             erros=tn(CFG['endereco_erros'], '{n} erro', '{n} erros'),
             horas=tn(CFG['endereco_janela'] // 3600, '{n} hora', '{n} horas'),
             dias=tn(CFG['endereco_dias'], '{n} dia', '{n} dias'))


def cartao_usuarios():
    """Bloqueios curtos do FTP, de um usuário para um endereço; vazio quando não há nenhum."""
    linhas = []
    for nome, dele in sorted(bloqueios().items()):
        destino = urllib.parse.quote(nome)
        for origem, expira, desde, erradas in dele:
            linhas.append(f'<tr><td><strong>{e(nome)}</strong></td>'
                          f'<td class="origem" data-rotulo="{t("Origem")}"><code>{e(origem)}</code></td>'
                          f'<td data-rotulo="{t("Senhas erradas")}">{erradas}</td>'
                          f'<td class="quando" data-rotulo="{t("Bloqueado em")}">{e(quando(desde))}</td>'
                          f'<td class="quando" data-rotulo="{t("Até")}">{e(quando(expira))}</td><td class="acoes">'
                          f'<a class="botao" href="/usuarios/editar?usuario={destino}#bloqueios">{icone("lapis")}{t("Abrir o usuário")}</a></td></tr>')
    if not linhas:
        return ''
    return f'''<section class="cartao lista"><h2>{icone('usuarios')}{t('Usuários bloqueados no FTP')}</h2>
<p class="suave">{t('Bloqueio curto, de um usuário para um endereço: os outros usuários seguem entrando por ele. '
                    'Vence sozinho e é desfeito em Editar, na aba Usuários.')}</p>
<div class="rolagem"><table class="blocos barrados">
<thead><tr><th>{t('Usuário')}</th><th>{t('Origem')}</th><th>{t('Senhas erradas')}</th><th>{t('Bloqueado em')}</th><th>{t('Até')}</th><th>{t('Ações')}</th></tr></thead>
<tbody>{''.join(linhas[:MOSTRADOS])}</tbody></table></div></section>'''


def lista(pedido, sessao, consulta, formulario, token):
    aviso = t(MENSAGENS.get(consulta.get('m', ''), ''))
    todos = enderecos.lista()
    busca = ''.join(letra for letra in consulta.get('q', '') if letra in '0123456789.')[:15]
    achados = [bloqueio for bloqueio in todos if busca in bloqueio[0]] if busca else todos
    linhas = []
    for ip, expira, desde, erros, quem in achados[:MOSTRADOS]:
        destino = urllib.parse.quote(ip)
        motivo = t(MOTIVO[quem], erros=erros) if erros and quem in MOTIVO else t(enderecos.QUEM[quem])
        linhas.append(f'<tr><td class="origem"><strong><code>{e(ip)}</code></strong></td>'
                      f'<td data-rotulo="{t("Bloqueado por")}">{motivo}</td><td class="quando" data-rotulo="{t("Desde")}">{e(quando(desde))}</td>'
                      f'<td data-rotulo="{t("Até")}"><span class="prazo"><span>{e(quando(expira))}</span> <span class="suave">({falta(expira)})</span></span></td>'
                      f'<td class="acoes"><a class="botao" href="/bloqueios/endereco?ip={destino}">{icone("relogio")}{t("Mudar prazo")}</a> '
                      f'<a class="botao" href="/bloqueios/endereco?ip={destino}#liberar">{icone("cadeado-aberto")}{t("Desbloquear")}</a></td></tr>')
    if busca:
        nada = vazio(5, 'lupa', t('Nenhum endereço bloqueado com esse trecho'), t('Confira os números ou veja a lista inteira.'))
    elif CFG['endereco_erros']:
        nada = vazio(5, 'escudo', t('Nenhum endereço bloqueado agora'),
                     t('Quem passar do limite de erros de usuário e senha, no FTP ou no painel, aparece aqui.'))
    else:
        nada = vazio(5, 'escudo', t('Nenhum endereço bloqueado agora'),
                     t('Nada é bloqueado sozinho nesta instalação: só pelo terminal do servidor.'))
    corpo = ''.join(linhas) or nada
    procurar = ''
    if busca or len(todos) > 10:
        procurar = f'''<form class="busca" method="get" action="/bloqueios" role="search">
<label for="q">{t('Procurar endereço')}</label>
<input id="q" name="q" inputmode="decimal" maxlength="15" autocomplete="off" value="{e(busca)}" placeholder="203.0.113">
<button type="submit">{icone('lupa')}{t('Procurar')}</button>{f' <a class="botao" href="/bloqueios">{t("Ver todos")}</a>' if busca else ''}
</form>'''
    cortado = ('<p class="suave">' + t('Mostrando os {mostrados} mais recentes de {achados}: use a busca para chegar aos outros.',
                                       mostrados=MOSTRADOS, achados=len(achados)) + '</p>'
               if len(achados) > MOSTRADOS else '')
    total = t('nenhum endereço bloqueado') if not todos else tn(len(todos), '1 endereço bloqueado', '{n} endereços bloqueados')
    pedido.enviar(200, pagina(t('Bloqueios'), f'''{cabeca('Bloqueios', t('{regra} Agora: {total}.', regra=regra(), total=total))}
{f'<p class="ok" role="status">{e(aviso)}</p>' if aviso else ''}
<section class="cartao lista">{procurar}<div class="rolagem"><table class="blocos barrados">
<thead><tr><th>{t('Endereço')}</th><th>{t('Bloqueado por')}</th><th>{t('Desde')}</th><th>{t('Até')}</th><th>{t('Ações')}</th></tr></thead>
<tbody>{corpo}</tbody></table></div>{cortado}
{como(t('Como funciona o bloqueio por endereço'), '<p class="suave">'
      + t('O endereço bloqueado é recusado com qualquer conta, mesmo com a senha certa, no FTP (com e sem TLS, em modo ativo '
          'ou passivo) e no painel. Desbloquear vale no próximo pedido; mudar o prazo serve para bloquear por mais tempo ou '
          'para encurtar.') + '</p>\n<p class="suave">'
      + t('Nunca são bloqueados sozinhos o próprio servidor, a rede interna da stack e os proxies de '
          '<code>PAINEL_PROXY_CONFIAVEL</code>. Administrador que ficou com o próprio endereço bloqueado libera pelo servidor: '
          '<code>./manage-user.sh endereco-liberar &lt;endereço&gt;</code>.') + '</p>')}</section>
{cartao_usuarios()}''', sessao, '/bloqueios'))


def tela_endereco(pedido, sessao, consulta, formulario, token, erro='', codigo=200):
    ip = consulta.get('ip', '')
    dado = enderecos.ler(ip)
    if dado is None:
        return pedido.redirecionar('/bloqueios?m=ausente')
    expira, desde, erros, quem = dado
    oculto = f'<input type="hidden" name="csrf" value="{e(sessao["csrf"])}">\n<input type="hidden" name="ip" value="{e(ip)}">'
    autor = (t('Bloqueado por <strong>{quem}</strong>, com {erros} erros de usuário e senha, em {desde}.',
               quem=t(enderecos.QUEM[quem]), erros=erros, desde=e(quando(desde))) if erros
             else t('Bloqueado por <strong>{quem}</strong>, em {desde}.', quem=t(enderecos.QUEM[quem]), desde=e(quando(desde))))
    pedido.enviar(codigo, pagina(t('Bloqueio de {ip}', ip=ip), f'''<h1>{t('Bloqueio de <code>{ip}</code>', ip=e(ip))}</h1>
<section class="cartao estreito"><h2>{t('Prazo')}</h2>{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<p>{autor}
{t('Vale até <strong>{ate}</strong> ({falta}).', ate=e(quando(expira)), falta=falta(expira))}</p>
<form method="post" action="/bloqueios/prazo" autocomplete="off">
{oculto}
<label for="dias">{t('Manter bloqueado por <span class="suave">(dias, contados de agora; de 1 a 3650)</span>')}</label>
<input id="dias" name="dias" type="number" min="1" max="3650" step="1" required value="{CFG['endereco_dias']}">
<p class="suave">{t('O prazo novo substitui o atual: serve para bloquear por mais tempo ou para encurtar o bloqueio.')}</p>
<button type="submit">{t('Gravar prazo')}</button> <a class="botao" href="/bloqueios">{t('Cancelar')}</a>
</form></section>
<section class="cartao estreito" id="liberar"><h2>{t('Desbloquear')}</h2>
<p>{t('O endereço volta a entrar no FTP e no painel no próximo pedido, e a contagem dos erros dele recomeça.')}</p>
<p class="suave">{t('Antes de desbloquear, corrija a senha no equipamento: se ele continuar errando, o bloqueio volta.')}</p>
<form method="post" action="/bloqueios/liberar" autocomplete="off">
{oculto}
<button type="submit">{t('Desbloquear')}</button>
</form></section>''', sessao, '/bloqueios'))


def mudar_prazo(pedido, sessao, consulta, formulario, token):
    ip, dias = formulario.get('ip', ''), formulario.get('dias', '')
    if enderecos.ler(ip) is None:
        return pedido.redirecionar('/bloqueios?m=ausente')
    if not (dias.isascii() and dias.isdigit() and len(dias) <= 4 and 1 <= int(dias) <= 3650):
        return tela_endereco(pedido, sessao, {'ip': ip}, {}, token, erro=t('Prazo inválido: de 1 a 3650 dias.'), codigo=400)
    feito, mensagem = executar_usuario('endereco-bloquear', ip, pares=(str(int(dias)),))
    if not feito:
        auditar(pedido.ip, 'falha_comando', f'admin={sessao["admin"]} acao=prazo_do_endereco endereco={ip}')
        return tela_endereco(pedido, sessao, {'ip': ip}, {}, token, erro=t('Não foi possível gravar:') + ' ' + do_comando(mensagem), codigo=500)
    auditar(pedido.ip, 'endereco_prazo', f'admin={sessao["admin"]} endereco={ip} dias={int(dias)}')
    return pedido.redirecionar('/bloqueios?m=prazo')


def liberar(pedido, sessao, consulta, formulario, token):
    ip = formulario.get('ip', '')
    if enderecos.ler(ip) is None:
        return pedido.redirecionar('/bloqueios?m=ausente')
    feito, mensagem = executar_usuario('endereco-liberar', ip)
    if not feito:
        auditar(pedido.ip, 'falha_comando', f'admin={sessao["admin"]} acao=liberar_endereco endereco={ip}')
        return tela_endereco(pedido, sessao, {'ip': ip}, {}, token, erro=t('Não foi possível desbloquear:') + ' ' + do_comando(mensagem), codigo=500)
    enderecos.esquecer(ip)
    auditar(pedido.ip, 'endereco_desbloqueado', f'admin={sessao["admin"]} endereco={ip}')
    return pedido.redirecionar('/bloqueios?m=liberado')
