# SPDX-License-Identifier: Apache-2.0
"""Aba Atividade: os últimos registros da auditoria."""
from auditoria import ler_auditoria
from pagina import e, pagina

EVENTOS = {
    'painel_iniciado': '🚀 Painel iniciado',
    'entrada_ok': '✅ Entrada',
    'entrada_falha': '❌ Entrada recusada',
    'entrada_bloqueada': '⛔ Entrada bloqueada pelo limite de tentativas',
    'saida': '🚪 Saída',
    'sessao_encerrada': '🚪 Sessão de usuário do FTP encerrada',
    'usuario_criado': '👤 Usuário criado',
    'senha_trocada': '🔑 Senha trocada',
    'pasta_trocada': '📁 Pasta do usuário trocada',
    'limites_alterados': '⏱️ Limites do usuário alterados',
    'bloqueio_removido': '🔓 Bloqueio do usuário no FTP removido',
    'usuario_removido': '🗑️ Usuário removido',
    'tls_dispensado': '🔓 Usuário dispensado do TLS',
    'tls_exigido': '🔒 Usuário volta a exigir TLS',
    'falha_comando': '⚠️ Alteração não concluída',
    'arquivo_baixado': '⬇️ Arquivo baixado',
    'pasta_criada': '📁 Pasta criada',
    'item_renomeado': '✏️ Arquivo ou pasta renomeado',
    'item_apagado': '🗑️ Arquivo ou pasta apagado',
    'arquivo_interrompido': '⚠️ Download interrompido',
    'admin_inicial_criado': '🛡️ Administrador inicial criado',
    'admin_criado': '🛡️ Administrador criado',
    'admin_senha_trocada': '🔑 Senha de administrador trocada',
    'admin_renomeado': '✏️ Administrador renomeado',
    'admin_removido': '🗑️ Administrador removido',
    'admin_definido_no_host': '🛠️ Administrador definido pelo host',
    'admin_senha_atual_recusada': '❌ Senha atual recusada',
    'recusa_csrf': '⛔ Envio sem token válido',
    'recusa_origem': '⛔ Envio de outra origem',
    'recusa_host': '⛔ Endereço não aceito',
    'recusa_rede': '⛔ Cliente fora das redes permitidas',
    'recusa_caminho': '⛔ Caminho de arquivo recusado',
    'recusa_papel': '⛔ Tela de administração pedida por usuário do FTP',
}


def atividade(pedido, sessao, consulta, formulario, token):
    linhas = []
    for texto in ler_auditoria():
        campos = texto.split(' ')
        if len(campos) < 3:
            continue
        momento = campos[0][:19].replace('T', ' ')
        ip = campos[1].partition('=')[2]
        evento = campos[2].partition('=')[2]
        linhas.append(f'<tr><td>{e(momento)}</td><td><code>{e(ip)}</code></td><td>{e(EVENTOS.get(evento, evento))}</td>'
                      f'<td>{e(" ".join(campos[3:]))}</td></tr>')
    corpo = ''.join(linhas) or '<tr><td colspan="4" class="suave">Nada registrado ainda.</td></tr>'
    pedido.enviar(200, pagina('Atividade', f'''<h1 class="titulo-aba">Atividade</h1>
<section class="cartao"><div class="rolagem"><table>
<thead><tr><th>Quando</th><th>De onde</th><th>O que aconteceu</th><th>Detalhe</th></tr></thead>
<tbody>{corpo}</tbody></table></div>
<p class="suave">Últimos 300 registros do painel, do mais novo para o mais antigo. Senha e token nunca são gravados.
As transferências dos equipamentos ficam no log do serviço FTP.</p></section>''', sessao, '/atividade'))
