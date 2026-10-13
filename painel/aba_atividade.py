# SPDX-License-Identifier: Apache-2.0
"""Aba Log: os últimos registros da auditoria."""
import re

from auditoria import fim_da_auditoria, ler_auditoria
from icones import icone
from idioma import N, dia_e_mes, t
from pagina import cabeca, como, e, pagina, tamanho, vazio

EVENTOS = {
    'painel_iniciado': ('inicio', N('Painel iniciado')),
    'entrada_ok': ('ok', N('Entrada')),
    'entrada_senha_ok': ('chave', N('Senha aceita, à espera do segundo fator')),
    'entrada_codigo_recusado': ('erro', N('Código do segundo fator recusado')),
    'entrada_fator_sem_segredo': ('alerta', N('Entrada recusada: segundo fator ligado sem o segredo no servidor')),
    'entrada_falha': ('erro', N('Entrada recusada')),
    'entrada_bloqueada': ('bloqueio', N('Entrada bloqueada pelo limite de tentativas')),
    'saida': ('sair', N('Saída')),
    'sessao_encerrada': ('sair', N('Sessão de usuário do FTP encerrada')),
    'usuario_criado': ('usuario', N('Usuário criado')),
    'senha_trocada': ('chave', N('Senha trocada')),
    'pasta_trocada': ('pasta', N('Pasta do usuário trocada')),
    'perfil_trocado': ('usuario', N('Perfil do usuário trocado')),
    'limites_alterados': ('relogio', N('Limites do usuário alterados')),
    'retencao_alterada': ('relogio', N('Limpeza automática do usuário alterada')),
    'retencao_aplicada': ('lixeira', N('Limpeza automática: arquivos antigos apagados')),
    'retencao_falhou': ('alerta', N('Limpeza automática não concluída')),
    'destino_gravado': ('nuvem', N('Destino de envio gravado')),
    'destino_removido': ('lixeira', N('Destino de envio removido')),
    'destino_teste': ('nuvem', N('Teste de destino de envio')),
    'destino_pedido': ('tocar', N('Envio para o destino pedido fora de hora')),
    'destino_arquivo': ('envio', N('Arquivo enviado para o destino a pedido')),
    'destino_enviado': ('envio', N('Arquivos enviados para o destino')),
    'destino_falhou': ('alerta', N('Envio para o destino não concluído')),
    'destino_pulado': ('alerta', N('Arquivo recusado pelo destino deixado para trás')),
    'copia_gravada': ('nuvem', N('Cópia do sistema para o S3 gravada')),
    'copia_pedida': ('tocar', N('Cópia do sistema pedida pela tela')),
    'copia_enviada': ('envio', N('Cópia do sistema enviada para o S3')),
    'copia_falhou': ('alerta', N('Cópia do sistema não concluída')),
    'copia_sem_destino': ('lixeira', N('Cópia do sistema ficou sem destino')),
    'bloqueio_removido': ('cadeado-aberto', N('Bloqueio do usuário no FTP removido')),
    'endereco_bloqueado': ('bloqueio', N('Endereço bloqueado por erros de usuário e senha')),
    'endereco_bloqueado_manual': ('bloqueio', N('Endereço ou prefixo bloqueado pelo administrador')),
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
    'arquivo_enviado': ('envio', N('Arquivo enviado pelo painel')),
    'envio_interrompido': ('alerta', N('Envio interrompido')),
    'recusa_envio': ('bloqueio', N('Envio pelo painel sem a permissão')),
    'admin_inicial_criado': ('escudo', N('Administrador inicial criado')),
    'admin_criado': ('escudo', N('Administrador criado')),
    'admin_senha_trocada': ('chave', N('Senha de administrador trocada')),
    'admin_renomeado': ('lapis', N('Administrador renomeado')),
    'admin_removido': ('lixeira', N('Administrador removido')),
    'admin_fator_ligado': ('escudo', N('Segundo fator ligado')),
    'admin_fator_desligado': ('escudo', N('Segundo fator desligado')),
    'admin_fator_desligado_no_host': ('escudo', N('Segundo fator desligado pelo terminal')),
    'fator_cadastrado_na_entrada': ('escudo', N('Segundo fator cadastrado na entrada')),
    'usuario_fator_desligado': ('escudo', N('Segundo fator de usuário do FTP desligado')),
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
    'recusa_pasta': ('bloqueio', N('Pasta não liberada pedida por usuário do FTP')),
}


# Ícone que pede atenção ganha a cor do estado; os outros ficam na cor do texto.
TONS = {'erro': 'ruim', 'bloqueio': 'ruim', 'alerta': 'atencao'}
# Nome de cada chave do detalhe, como ele aparece na tela. Chave fora daqui aparece como foi gravada.
ROTULOS = {'admin': N('administrador'), 'usuario': N('usuário'), 'versao': N('versão'), 'acao': N('ação'),
           'conferencia': N('conferência'), 'credencial': N('senha'), 'alvo': N('conta'), 'novo': N('conta nova'),
           'anterior': N('pasta anterior'), 'host': N('endereço pedido'), 'bytes': N('tamanho'), 'endereco': N('endereço'),
           'ultimos': N('arquivos mantidos'), 'dias': N('dias'), 'pasta': N('pasta'), 'arquivos': N('arquivos'),
           'pastas': N('pastas'), 'erros': N('erros'), 'destino': N('destino'), 'motivo': N('motivo'),
           'apagados': N('apagados do servidor'), 'grandes': N('acima do limite do bot'), 'ignorados': N('ignorados'),
           'modo': N('depois do envio'), 'intervalo': N('minutos entre as passadas'), 'resultado': N('resultado'),
           'arquivo': N('arquivo'), 'situacao': N('situação'), 'segredos': N('segredos')}
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
    pedido.enviar(200, pagina(t('Log'), f'''{cabeca('Log', resumo)}
<section class="cartao lista"><div class="rolagem"><table class="blocos registros">
<thead><tr><th>{t('Quando')}</th><th>{t('De onde')}</th><th>{t('O que aconteceu')}</th><th>{t('Detalhe')}</th></tr></thead>
<tbody>{corpo}</tbody></table></div>
{como(t('O que fica registrado'), '<p class="suave">'
      + t('Senha e token nunca são gravados. As transferências dos equipamentos ficam no log do serviço FTP.') + '</p>')}</section>''',
                              sessao, '/atividade'))
