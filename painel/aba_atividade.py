# SPDX-License-Identifier: Apache-2.0
"""Aba Atividade: os últimos registros da auditoria."""
import re

from auditoria import fim_da_auditoria, ler_auditoria
from icones import icone
from pagina import cabeca, e, pagina, tamanho

EVENTOS = {
    'painel_iniciado': ('inicio', 'Painel iniciado'),
    'entrada_ok': ('ok', 'Entrada'),
    'entrada_falha': ('erro', 'Entrada recusada'),
    'entrada_bloqueada': ('bloqueio', 'Entrada bloqueada pelo limite de tentativas'),
    'saida': ('sair', 'Saída'),
    'sessao_encerrada': ('sair', 'Sessão de usuário do FTP encerrada'),
    'usuario_criado': ('usuario', 'Usuário criado'),
    'senha_trocada': ('chave', 'Senha trocada'),
    'pasta_trocada': ('pasta', 'Pasta do usuário trocada'),
    'perfil_trocado': ('usuario', 'Perfil do usuário trocado'),
    'limites_alterados': ('relogio', 'Limites do usuário alterados'),
    'bloqueio_removido': ('cadeado-aberto', 'Bloqueio do usuário no FTP removido'),
    'usuario_removido': ('lixeira', 'Usuário removido'),
    'tls_dispensado': ('cadeado-aberto', 'Usuário dispensado do TLS'),
    'tls_exigido': ('cadeado', 'Usuário volta a exigir TLS'),
    'falha_comando': ('alerta', 'Alteração não concluída'),
    'arquivo_baixado': ('baixar', 'Arquivo baixado'),
    'pasta_criada': ('pasta', 'Pasta criada'),
    'item_renomeado': ('lapis', 'Arquivo ou pasta renomeado'),
    'item_apagado': ('lixeira', 'Arquivo ou pasta apagado'),
    'arquivo_interrompido': ('alerta', 'Download interrompido'),
    'admin_inicial_criado': ('escudo', 'Administrador inicial criado'),
    'admin_criado': ('escudo', 'Administrador criado'),
    'admin_senha_trocada': ('chave', 'Senha de administrador trocada'),
    'admin_renomeado': ('lapis', 'Administrador renomeado'),
    'admin_removido': ('lixeira', 'Administrador removido'),
    'admin_definido_no_host': ('terminal', 'Administrador definido pelo host'),
    'admin_senha_atual_recusada': ('erro', 'Senha atual recusada'),
    'usuario_senha_atual_recusada': ('erro', 'Senha do FTP recusada na confirmação'),
    'recusa_csrf': ('bloqueio', 'Envio sem token válido'),
    'recusa_origem': ('bloqueio', 'Envio de outra origem'),
    'recusa_host': ('bloqueio', 'Endereço não aceito'),
    'recusa_rede': ('bloqueio', 'Cliente fora das redes permitidas'),
    'recusa_caminho': ('bloqueio', 'Caminho de arquivo recusado'),
    'recusa_papel': ('bloqueio', 'Tela fora do papel ou do perfil pedida por usuário do FTP'),
}


# Ícone que pede atenção ganha a cor do estado; os outros ficam na cor do texto.
TONS = {'erro': 'ruim', 'bloqueio': 'ruim', 'alerta': 'atencao'}
# Nome de cada chave do detalhe, como ele aparece na tela. Chave fora daqui aparece como foi gravada.
ROTULOS = {'admin': 'administrador', 'usuario': 'usuário', 'versao': 'versão', 'acao': 'ação', 'conferencia': 'conferência',
           'credencial': 'senha', 'alvo': 'conta', 'novo': 'conta nova', 'anterior': 'pasta anterior', 'host': 'endereço pedido',
           'bytes': 'tamanho'}
MOMENTO = re.compile(r'(\d{4})-(\d\d)-(\d\d)T(\d\d:\d\d)(:\d\d)')


def acontecido(evento):
    if evento not in EVENTOS:
        return e(evento)
    desenho, texto = EVENTOS[evento]
    return f'<span class="item">{icone(desenho, classe=TONS.get(desenho, ""))}{e(texto)}</span>'


def origem(ip):
    """De onde veio: o endereço inteiro, IPv4 ou IPv6, sem quebra; o que o próprio painel registra não tem endereço."""
    return '<span class="suave">no servidor</span>' if ip == '-' else f'<code>{e(ip)}</code>'


def detalhe(campos):
    pares = []
    for campo in campos:
        chave, igual, valor = campo.partition('=')
        if not igual:
            pares.append(e(campo))
            continue
        if chave == 'bytes' and valor.isdigit():
            valor = tamanho(int(valor))
        pares.append(f'<span class="par"><span>{e(ROTULOS.get(chave, chave))}</span> {e(valor)}</span>')
    return ' '.join(pares)


def registro(texto):
    """Uma linha da auditoria ➜ (dia, hora, endereço, evento, campos do detalhe), ou None se ela não tem o formato."""
    campos = texto.split(' ')
    data = MOMENTO.match(campos[0])
    if len(campos) < 3 or not data:
        return None
    ano, mes, dia, hora, segundos = data.groups()
    return f'{dia}/{mes}/{ano}', hora + segundos, campos[1].partition('=')[2], campos[2].partition('=')[2], campos[3:]


def recentes():
    """Os últimos registros, em lista curta, para a Visão geral."""
    itens = []
    for dia, hora, ip, evento, _ in filter(None, map(registro, fim_da_auditoria())):
        itens.append(f'<li>{acontecido(evento)}<span class="suave">{dia[:5]}\u00a0{hora[:5]} · {origem(ip)}</span></li>')
    return ''.join(itens) or '<li class="suave">Nada registrado ainda.</li>'


def atividade(pedido, sessao, consulta, formulario, token):
    linhas = []
    for dia, hora, ip, evento, campos in filter(None, map(registro, ler_auditoria())):
        linhas.append(f'<tr><td class="quando">{dia}\u00a0{hora}</td><td class="origem">{origem(ip)}</td>'
                      f'<td>{acontecido(evento)}</td><td class="detalhe">{detalhe(campos)}</td></tr>')
    corpo = ''.join(linhas) or '<tr><td colspan="4" class="suave">Nada registrado ainda.</td></tr>'
    pedido.enviar(200, pagina('Atividade', f'''{cabeca('Atividade', 'Quem entrou e o que foi feito no painel: os últimos 300 registros, do mais novo para o mais antigo.')}
<section class="cartao lista"><div class="rolagem"><table>
<thead><tr><th>Quando</th><th>De onde</th><th>O que aconteceu</th><th>Detalhe</th></tr></thead>
<tbody>{corpo}</tbody></table></div>
<p class="suave">Senha e token nunca são gravados.
As transferências dos equipamentos ficam no log do serviço FTP.</p></section>''', sessao, '/atividade'))
