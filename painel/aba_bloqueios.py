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
from pagina import cabeca, como, e, pagina, quando, vazio

MOSTRADOS = 500     # linhas da lista; acima disso, a busca
ONDE = {'ftp': 'no FTP', 'painel': 'no painel'}
MENSAGENS = {'liberado': 'Endereço liberado: ele volta a entrar no FTP e no painel.',
             'prazo': 'Prazo do bloqueio alterado.',
             'ausente': 'Este endereço não está mais bloqueado.'}


def falta(expira):
    dias = math.ceil((expira - time.time()) / 86400)
    return 'menos de 1 dia' if dias <= 1 else f'{dias} dias'


def regra():
    """A regra em vigor, em uma frase, para o começo da tela."""
    if not CFG['endereco_erros']:
        return ('O bloqueio automático está desligado (<code>BLOQUEIO_ENDERECO_ERROS=0</code>): '
                'aqui ficam só os endereços bloqueados pelo terminal.')
    erros, horas, dias = CFG['endereco_erros'], CFG['endereco_janela'] // 3600, CFG['endereco_dias']
    return (f'O endereço que passa de {erros} erro{"" if erros == 1 else "s"} de usuário e senha em {horas} hora{"" if horas == 1 else "s"}, '
            f'no FTP ou no painel, fica {dias} dia{"" if dias == 1 else "s"} sem entrar nos dois.')


def cartao_usuarios():
    """Bloqueios curtos do FTP, de um usuário para um endereço; vazio quando não há nenhum."""
    linhas = []
    for nome, dele in sorted(bloqueios().items()):
        destino = urllib.parse.quote(nome)
        for origem, expira, desde, erradas in dele:
            linhas.append(f'<tr><td><strong>{e(nome)}</strong></td>'
                          f'<td class="origem" data-rotulo="Origem"><code>{e(origem)}</code></td>'
                          f'<td data-rotulo="Senhas erradas">{erradas}</td><td data-rotulo="Bloqueado em">{e(quando(desde))}</td>'
                          f'<td data-rotulo="Até">{e(quando(expira))}</td><td class="acoes">'
                          f'<a class="botao" href="/usuarios/editar?usuario={destino}#bloqueios">{icone("lapis")}Abrir o usuário</a></td></tr>')
    if not linhas:
        return ''
    return f'''<section class="cartao lista"><h2>{icone('usuarios')}Usuários bloqueados no FTP</h2>
<p class="suave">Bloqueio curto, de um usuário para um endereço: os outros usuários seguem entrando por ele.
Vence sozinho e é desfeito em Editar, na aba Usuários.</p>
<div class="rolagem"><table class="blocos barrados">
<thead><tr><th>Usuário</th><th>Origem</th><th>Senhas erradas</th><th>Bloqueado em</th><th>Até</th><th>Ações</th></tr></thead>
<tbody>{''.join(linhas[:MOSTRADOS])}</tbody></table></div></section>'''


def lista(pedido, sessao, consulta, formulario, token):
    aviso = MENSAGENS.get(consulta.get('m', ''), '')
    todos = enderecos.lista()
    busca = ''.join(letra for letra in consulta.get('q', '') if letra in '0123456789.')[:15]
    achados = [bloqueio for bloqueio in todos if busca in bloqueio[0]] if busca else todos
    linhas = []
    for ip, expira, desde, erros, quem in achados[:MOSTRADOS]:
        destino = urllib.parse.quote(ip)
        motivo = f'{erros} erros {ONDE[quem]}' if erros and quem in ONDE else enderecos.QUEM[quem]
        linhas.append(f'<tr><td class="origem"><strong><code>{e(ip)}</code></strong></td>'
                      f'<td data-rotulo="Bloqueado por">{motivo}</td><td data-rotulo="Desde">{e(quando(desde))}</td>'
                      f'<td data-rotulo="Até"><span class="prazo"><span>{e(quando(expira))}</span> <span class="suave">({falta(expira)})</span></span></td>'
                      f'<td class="acoes"><a class="botao" href="/bloqueios/endereco?ip={destino}">{icone("relogio")}Mudar prazo</a> '
                      f'<a class="botao" href="/bloqueios/endereco?ip={destino}#liberar">{icone("cadeado-aberto")}Desbloquear</a></td></tr>')
    if busca:
        nada = vazio(5, 'lupa', 'Nenhum endereço bloqueado com esse trecho', 'Confira os números ou veja a lista inteira.')
    elif CFG['endereco_erros']:
        nada = vazio(5, 'escudo', 'Nenhum endereço bloqueado agora',
                     'Quem passar do limite de erros de usuário e senha, no FTP ou no painel, aparece aqui.')
    else:
        nada = vazio(5, 'escudo', 'Nenhum endereço bloqueado agora', 'Nada é bloqueado sozinho nesta instalação: só pelo terminal do servidor.')
    corpo = ''.join(linhas) or nada
    procurar = ''
    if busca or len(todos) > 10:
        procurar = f'''<form class="busca" method="get" action="/bloqueios" role="search">
<label for="q">Procurar endereço</label>
<input id="q" name="q" inputmode="decimal" maxlength="15" autocomplete="off" value="{e(busca)}" placeholder="203.0.113">
<button type="submit">{icone('lupa')}Procurar</button>{' <a class="botao" href="/bloqueios">Ver todos</a>' if busca else ''}
</form>'''
    cortado = (f'<p class="suave">Mostrando os {MOSTRADOS} mais recentes de {len(achados)}: use a busca para chegar aos outros.</p>'
               if len(achados) > MOSTRADOS else '')
    total = ('nenhum endereço bloqueado' if not todos else '1 endereço bloqueado' if len(todos) == 1
             else f'{len(todos)} endereços bloqueados')
    pedido.enviar(200, pagina('Bloqueios', f'''{cabeca('Bloqueios', f'{regra()} Agora: {total}.')}
{f'<p class="ok" role="status">{e(aviso)}</p>' if aviso else ''}
<section class="cartao lista">{procurar}<div class="rolagem"><table class="blocos barrados">
<thead><tr><th>Endereço</th><th>Bloqueado por</th><th>Desde</th><th>Até</th><th>Ações</th></tr></thead>
<tbody>{corpo}</tbody></table></div>{cortado}
{como('Como funciona o bloqueio por endereço', '''<p class="suave">O endereço bloqueado é recusado com qualquer conta, mesmo com a
senha certa, no FTP (com e sem TLS, em modo ativo ou passivo) e no painel. Desbloquear vale no próximo pedido; mudar o prazo
serve para bloquear por mais tempo ou para encurtar.</p>
<p class="suave">Nunca são bloqueados sozinhos o próprio servidor, a rede interna da stack e os proxies de
<code>PAINEL_PROXY_CONFIAVEL</code>. Administrador que ficou com o próprio endereço bloqueado libera pelo servidor:
<code>./manage-user.sh endereco-liberar &lt;endereço&gt;</code>.</p>''')}</section>
{cartao_usuarios()}''', sessao, '/bloqueios'))


def tela_endereco(pedido, sessao, consulta, formulario, token, erro='', codigo=200):
    ip = consulta.get('ip', '')
    dado = enderecos.ler(ip)
    if dado is None:
        return pedido.redirecionar('/bloqueios?m=ausente')
    expira, desde, erros, quem = dado
    oculto = f'<input type="hidden" name="csrf" value="{e(sessao["csrf"])}">\n<input type="hidden" name="ip" value="{e(ip)}">'
    pedido.enviar(codigo, pagina(f'Bloqueio de {ip}', f'''<h1>Bloqueio de <code>{e(ip)}</code></h1>
<section class="cartao estreito"><h2>Prazo</h2>{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<p>Bloqueado por <strong>{enderecos.QUEM[quem]}</strong>{f', com {erros} erros de usuário e senha' if erros else ''}, em {e(quando(desde))}.
Vale até <strong>{e(quando(expira))}</strong> ({falta(expira)}).</p>
<form method="post" action="/bloqueios/prazo" autocomplete="off">
{oculto}
<label for="dias">Manter bloqueado por <span class="suave">(dias, contados de agora; de 1 a 3650)</span></label>
<input id="dias" name="dias" type="number" min="1" max="3650" step="1" required value="{CFG['endereco_dias']}">
<p class="suave">O prazo novo substitui o atual: serve para bloquear por mais tempo ou para encurtar o bloqueio.</p>
<button type="submit">Gravar prazo</button> <a class="botao" href="/bloqueios">Cancelar</a>
</form></section>
<section class="cartao estreito" id="liberar"><h2>Desbloquear</h2>
<p>O endereço volta a entrar no FTP e no painel no próximo pedido, e a contagem dos erros dele recomeça.</p>
<p class="suave">Antes de desbloquear, corrija a senha no equipamento: se ele continuar errando, o bloqueio volta.</p>
<form method="post" action="/bloqueios/liberar" autocomplete="off">
{oculto}
<button type="submit">Desbloquear</button>
</form></section>''', sessao, '/bloqueios'))


def mudar_prazo(pedido, sessao, consulta, formulario, token):
    ip, dias = formulario.get('ip', ''), formulario.get('dias', '')
    if enderecos.ler(ip) is None:
        return pedido.redirecionar('/bloqueios?m=ausente')
    if not (dias.isascii() and dias.isdigit() and len(dias) <= 4 and 1 <= int(dias) <= 3650):
        return tela_endereco(pedido, sessao, {'ip': ip}, {}, token, erro='Prazo inválido: de 1 a 3650 dias.', codigo=400)
    feito, mensagem = executar_usuario('endereco-bloquear', ip, pares=(str(int(dias)),))
    if not feito:
        auditar(pedido.ip, 'falha_comando', f'admin={sessao["admin"]} acao=prazo_do_endereco endereco={ip}')
        return tela_endereco(pedido, sessao, {'ip': ip}, {}, token, erro='Não foi possível gravar: ' + mensagem, codigo=500)
    auditar(pedido.ip, 'endereco_prazo', f'admin={sessao["admin"]} endereco={ip} dias={int(dias)}')
    return pedido.redirecionar('/bloqueios?m=prazo')


def liberar(pedido, sessao, consulta, formulario, token):
    ip = formulario.get('ip', '')
    if enderecos.ler(ip) is None:
        return pedido.redirecionar('/bloqueios?m=ausente')
    feito, mensagem = executar_usuario('endereco-liberar', ip)
    if not feito:
        auditar(pedido.ip, 'falha_comando', f'admin={sessao["admin"]} acao=liberar_endereco endereco={ip}')
        return tela_endereco(pedido, sessao, {'ip': ip}, {}, token, erro='Não foi possível desbloquear: ' + mensagem, codigo=500)
    enderecos.esquecer(ip)
    auditar(pedido.ip, 'endereco_desbloqueado', f'admin={sessao["admin"]} endereco={ip}')
    return pedido.redirecionar('/bloqueios?m=liberado')
