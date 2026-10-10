# SPDX-License-Identifier: Apache-2.0
"""Aba Atividade: os últimos registros da auditoria."""
import re

from auditoria import fim_da_auditoria, ler_auditoria
from icones import icone
from idioma import N, dia_e_mes, t
from pagina import cabeca, como, e, pagina, tamanho, vazio

EVENTOS = {
    'painel_iniciado': ('inicio', N('Painel iniciado')),
    'entrada_ok': ('ok', N('Entrada')),
    'entrada_falha': ('erro', N('Entrada recusada')),
    'entrada_bloqueada': ('bloqueio', N('Entrada bloqueada pelo limite de tentativas')),
    'saida': ('sair', N('Saída')),
    'sessao_encerrada': ('sair', N('Sessão de usuário do FTP encerrada')),
    'usuario_criado': ('usuario', N('Usuário criado')),
    'senha_trocada': ('chave', N('Senha trocada')),
    'pasta_trocada': ('pasta', N('Pasta do usuário trocada')),
    'perfil_trocado': ('usuario', N('Perfil do usuário trocado')),
    'limites_alterados': ('relogio', N('Limites do usuário alterados')),
    'bloqueio_removido': ('cadeado-aberto', N('Bloqueio do usuário no FTP removido')),
    'endereco_bloqueado': ('bloqueio', N('Endereço bloqueado por erros de usuário e senha')),
    'endereco_prazo': ('relogio', N('Prazo do bloqueio de endereço alterado')),
    'endereco_desbloqueado': ('cadeado-aberto', N('Endereço desbloqueado')),
    'usuario_removido': ('lixeira', N('Usuário removido')),
    'tls_dispensado': ('cadeado-aberto', N('Usuário dispensado do TLS')),
    'tls_exigido': ('cadeado', N('Usuário volta a exigir TLS')),
    'falha_comando': ('alerta', N('Alteração não concluída')),
    'arquivo_baixado': ('baixar', N('Arquivo baixado')),
    'pasta_criada': ('pasta', N('Pasta criada')),
    'item_renomeado': ('lapis', N('Arquivo ou pasta renomeado')),
    'item_apagado': ('lixeira', N('Arquivo ou pasta apagado')),
    'arquivo_interrompido': ('alerta', N('Download interrompido')),
    'admin_inicial_criado': ('escudo', N('Administrador inicial criado')),
    'admin_criado': ('escudo', N('Administrador criado')),
    'admin_senha_trocada': ('chave', N('Senha de administrador trocada')),
    'admin_renomeado': ('lapis', N('Administrador renomeado')),
    'admin_removido': ('lixeira', N('Administrador removido')),
    'admin_definido_no_host': ('terminal', N('Administrador definido pelo host')),
    'admin_senha_atual_recusada': ('erro', N('Senha atual recusada')),
    'usuario_senha_atual_recusada': ('erro', N('Senha do FTP recusada na confirmação')),
    'recusa_csrf': ('bloqueio', N('Envio sem token válido')),
    'recusa_origem': ('bloqueio', N('Envio de outra origem')),
    'recusa_host': ('bloqueio', N('Endereço não aceito')),
    'recusa_rede': ('bloqueio', N('Cliente fora das redes permitidas')),
    'recusa_endereco': ('bloqueio', N('Pedido de endereço bloqueado')),
    'recusa_caminho': ('bloqueio', N('Caminho de arquivo recusado')),
    'recusa_papel': ('bloqueio', N('Tela fora do papel ou do perfil pedida por usuário do FTP')),
}


# Ícone que pede atenção ganha a cor do estado; os outros ficam na cor do texto.
TONS = {'erro': 'ruim', 'bloqueio': 'ruim', 'alerta': 'atencao'}
# Nome de cada chave do detalhe, como ele aparece na tela. Chave fora daqui aparece como foi gravada.
ROTULOS = {'admin': N('administrador'), 'usuario': N('usuário'), 'versao': N('versão'), 'acao': N('ação'),
           'conferencia': N('conferência'), 'credencial': N('senha'), 'alvo': N('conta'), 'novo': N('conta nova'),
           'anterior': N('pasta anterior'), 'host': N('endereço pedido'), 'bytes': N('tamanho'), 'endereco': N('endereço')}
MOMENTO = re.compile(r'(\d{4})-(\d\d)-(\d\d)T(\d\d:\d\d)(:\d\d)')


def acontecido(evento):
    if evento not in EVENTOS:
        return e(evento)
    desenho, texto = EVENTOS[evento]
    return f'<span class="item">{icone(desenho, classe=TONS.get(desenho, ""))}{e(t(texto))}</span>'


def origem(ip):
    """De onde veio: o endereço inteiro, IPv4 ou IPv6, sem quebra; o que o próprio painel registra não tem endereço."""
    return f'<span class="suave">{t("no servidor")}</span>' if ip == '-' else f'<code>{e(ip)}</code>'


def detalhe(campos):
    pares = []
    for campo in campos:
        chave, igual, valor = campo.partition('=')
        if not igual:
            pares.append(e(campo))
            continue
        if chave == 'bytes' and valor.isdigit():
            valor = tamanho(int(valor))
        pares.append(f'<span class="par"><span>{e(t(ROTULOS[chave]) if chave in ROTULOS else chave)}</span> {e(valor)}</span>')
    return ' '.join(pares)


def registro(texto):
    """Uma linha da auditoria ➜ (dia, hora, endereço, evento, campos do detalhe), ou None se ela não tem o formato.
    O dia vem em duas formas, no idioma do pedido: a inteira e a curta, só com dia e mês."""
    campos = texto.split(' ')
    data = MOMENTO.match(campos[0])
    if len(campos) < 3 or not data:
        return None
    ano, mes, dia, hora, segundos = data.groups()
    return dia_e_mes(ano, mes, dia), hora + segundos, campos[1].partition('=')[2], campos[2].partition('=')[2], campos[3:]


def recentes():
    """Os últimos registros, em lista curta, para a Visão geral."""
    itens = []
    for (_, dia), hora, ip, evento, _ in filter(None, map(registro, fim_da_auditoria())):
        itens.append(f'<li>{acontecido(evento)}<span class="suave">{dia}\u00a0{hora[:5]} · {origem(ip)}</span></li>')
    return ''.join(itens) or f'<li class="suave">{t("Nada registrado ainda.")}</li>'


def atividade(pedido, sessao, consulta, formulario, token):
    linhas = []
    for (dia, _), hora, ip, evento, campos in filter(None, map(registro, ler_auditoria())):
        linhas.append(f'<tr><td class="quando">{dia}\u00a0{hora}</td><td class="origem" data-rotulo="{t("De onde")}">{origem(ip)}</td>'
                      f'<td class="fato">{acontecido(evento)}</td><td class="detalhe">{detalhe(campos)}</td></tr>')
    corpo = ''.join(linhas) or vazio(4, 'atividade', t('Nada registrado ainda'),
                                     t('Cada entrada no painel e cada alteração feita por ele passa a aparecer aqui.'))
    resumo = t('Quem entrou e o que foi feito no painel: os últimos 300 registros, do mais novo para o mais antigo.')
    pedido.enviar(200, pagina(t('Atividade'), f'''{cabeca('Atividade', resumo)}
<section class="cartao lista"><div class="rolagem"><table class="blocos registros">
<thead><tr><th>{t('Quando')}</th><th>{t('De onde')}</th><th>{t('O que aconteceu')}</th><th>{t('Detalhe')}</th></tr></thead>
<tbody>{corpo}</tbody></table></div>
{como(t('O que fica registrado'), '<p class="suave">'
      + t('Senha e token nunca são gravados. As transferências dos equipamentos ficam no log do serviço FTP.') + '</p>')}</section>''',
                              sessao, '/atividade'))
