# SPDX-License-Identifier: Apache-2.0
"""Aba Atividade: os últimos registros da auditoria."""
from auditoria import ler_auditoria
from icones import icone
from pagina import cabeca, e, pagina

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
    'recusa_csrf': ('bloqueio', 'Envio sem token válido'),
    'recusa_origem': ('bloqueio', 'Envio de outra origem'),
    'recusa_host': ('bloqueio', 'Endereço não aceito'),
    'recusa_rede': ('bloqueio', 'Cliente fora das redes permitidas'),
    'recusa_caminho': ('bloqueio', 'Caminho de arquivo recusado'),
    'recusa_papel': ('bloqueio', 'Tela de administração pedida por usuário do FTP'),
}


def acontecido(evento):
    if evento not in EVENTOS:
        return e(evento)
    desenho, texto = EVENTOS[evento]
    return f'<span class="item">{icone(desenho)}{e(texto)}</span>'


def atividade(pedido, sessao, consulta, formulario, token):
    linhas = []
    for texto in ler_auditoria():
        campos = texto.split(' ')
        if len(campos) < 3:
            continue
        momento = campos[0][:19].replace('T', '\u00a0')
        ip = campos[1].partition('=')[2]
        evento = campos[2].partition('=')[2]
        linhas.append(f'<tr><td>{e(momento)}</td><td><code>{e(ip)}</code></td><td>{acontecido(evento)}</td>'
                      f'<td>{e(" ".join(campos[3:]))}</td></tr>')
    corpo = ''.join(linhas) or '<tr><td colspan="4" class="suave">Nada registrado ainda.</td></tr>'
    pedido.enviar(200, pagina('Atividade', f'''{cabeca('Atividade', 'Quem entrou e o que foi feito no painel: os últimos 300 registros, do mais novo para o mais antigo.')}
<section class="cartao"><div class="rolagem"><table>
<thead><tr><th>Quando</th><th>De onde</th><th>O que aconteceu</th><th>Detalhe</th></tr></thead>
<tbody>{corpo}</tbody></table></div>
<p class="suave">Senha e token nunca são gravados.
As transferências dos equipamentos ficam no log do serviço FTP.</p></section>''', sessao, '/atividade'))
