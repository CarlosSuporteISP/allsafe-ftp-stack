# SPDX-License-Identifier: Apache-2.0
"""Rotas do painel depois da entrada: método e caminho ➜ função que responde.

Cada papel tem a tabela dele: ROTAS é a do administrador e ROTAS_USUARIO traz a do usuário do FTP, uma por
perfil, todas presas à pasta dele: Leitura navega e baixa, Envio também cria pasta, Completo também troca o nome
e apaga. Só envio não tem lista nem download: vê só como enviar. Enviar arquivo pelo painel existe para o
administrador e para os perfis que enviam por FTP (Só envio, Envio e Completo); no usuário do FTP, só com a permissão
dele, que a própria rota confere. O que não está na tabela do papel ou do perfil não existe para ele.
As outras pastas que o administrador liberou a um usuário (/pastas/<identificador>) usam as mesmas tabelas: a
permissão dele naquela pasta escolhe a tabela do perfil de mesmo nome, e o caminho é lido como o de /meus-arquivos
(atendimento.py).
Toda função recebe (pedido, sessao, consulta, formulario, token); `pedido` é o tratador de atendimento.py."""
import aba_administradores
import aba_arquivos
import aba_atividade
import aba_bloqueios
import aba_destinos
import aba_fator
import aba_meus_arquivos
import aba_seguranca
import aba_servidor
import aba_usuarios
import aba_visao_geral
import entrada

ROTAS = {
    ('GET', '/'): aba_visao_geral.visao_geral,
    ('GET', '/usuarios'): aba_usuarios.lista_usuarios,
    ('GET', '/usuarios/novo'): aba_usuarios.tela_novo,
    ('POST', '/usuarios/novo'): aba_administradores.criar_conta,
    ('GET', '/usuarios/editar'): aba_usuarios.tela_editar,
    ('POST', '/usuarios/perfil'): aba_usuarios.trocar_perfil,
    ('POST', '/usuarios/pasta'): aba_usuarios.trocar_pasta,
    ('POST', '/usuarios/limites'): aba_usuarios.gravar_limites,
    ('POST', '/usuarios/limpeza'): aba_usuarios.gravar_limpeza,
    ('POST', '/usuarios/desbloquear'): aba_usuarios.desbloquear,
    ('GET', '/usuarios/senha'): aba_usuarios.tela_trocar_senha,
    ('POST', '/usuarios/senha'): aba_usuarios.trocar_senha,
    ('GET', '/usuarios/remover'): aba_usuarios.tela_remover,
    ('POST', '/usuarios/remover'): aba_usuarios.remover_usuario,
    ('GET', '/usuarios/tls'): aba_usuarios.tela_tls,
    ('POST', '/usuarios/tls'): aba_usuarios.alterar_tls,
    ('GET', '/arquivos'): aba_arquivos.lista_arquivos,
    ('GET', '/arquivos/baixar'): aba_arquivos.baixar,
    ('POST', '/arquivos/pasta'): aba_arquivos.criar_pasta,
    ('POST', '/arquivos/enviar'): aba_arquivos.enviar,
    ('GET', '/arquivos/renomear'): aba_arquivos.tela_renomear,
    ('POST', '/arquivos/renomear'): aba_arquivos.renomear,
    ('GET', '/arquivos/apagar'): aba_arquivos.tela_apagar,
    ('POST', '/arquivos/apagar'): aba_arquivos.apagar,
    ('GET', '/destinos'): aba_destinos.lista,
    ('GET', '/destinos/s3'): aba_destinos.tela_s3,
    ('POST', '/destinos/s3'): aba_destinos.gravar_s3,
    ('GET', '/destinos/telegram'): aba_destinos.tela_telegram,
    ('POST', '/destinos/telegram'): aba_destinos.gravar_telegram,
    ('GET', '/destinos/rclone'): aba_destinos.tela_rclone,
    ('POST', '/destinos/rclone'): aba_destinos.gravar_rclone,
    ('POST', '/destinos/testar'): aba_destinos.testar,
    ('POST', '/destinos/agora'): aba_destinos.agora,
    ('GET', '/destinos/arquivo'): aba_destinos.tela_escolher,
    ('POST', '/destinos/arquivo'): aba_destinos.arquivo,
    ('GET', '/destinos/remover'): aba_destinos.tela_remover,
    ('POST', '/destinos/remover'): aba_destinos.remover,
    ('GET', '/destinos/copia'): aba_destinos.tela_copia,
    ('POST', '/destinos/copia'): aba_destinos.gravar_copia,
    ('POST', '/destinos/copia/agora'): aba_destinos.copia_agora,
    ('GET', '/administradores'): aba_administradores.lista,
    ('GET', '/administradores/novo'): aba_administradores.tela_novo,
    ('GET', '/administradores/senha'): aba_administradores.tela_trocar_senha,
    ('POST', '/administradores/senha'): aba_administradores.trocar_senha,
    ('GET', '/administradores/nome'): aba_administradores.tela_trocar_nome,
    ('POST', '/administradores/nome'): aba_administradores.trocar_nome,
    ('GET', '/administradores/remover'): aba_administradores.tela_remover,
    ('POST', '/administradores/remover'): aba_administradores.remover,
    ('GET', '/administradores/fator'): aba_fator.tela,
    ('POST', '/administradores/fator/ligar'): aba_fator.ligar,
    ('POST', '/administradores/fator/desligar'): aba_fator.desligar,
    ('GET', '/usuarios/fator'): aba_fator.tela_do_usuario,
    ('POST', '/usuarios/fator/desligar'): aba_fator.desligar_do_usuario,
    ('GET', '/seguranca'): aba_seguranca.seguranca,
    ('GET', '/servidor'): aba_servidor.servidor,
    ('GET', '/bloqueios'): aba_bloqueios.lista,
    ('GET', '/bloqueios/novo'): aba_bloqueios.tela_novo,
    ('POST', '/bloqueios/novo'): aba_bloqueios.bloquear,
    ('GET', '/bloqueios/endereco'): aba_bloqueios.tela_endereco,
    ('POST', '/bloqueios/prazo'): aba_bloqueios.mudar_prazo,
    ('POST', '/bloqueios/liberar'): aba_bloqueios.liberar,
    ('GET', '/atividade'): aba_atividade.atividade,
    ('POST', '/sair'): entrada.sair,
}

ROTAS_SOENVIO = {
    ('GET', '/'): aba_meus_arquivos.inicio,
    ('GET', '/meus-arquivos'): aba_meus_arquivos.so_envio,
    ('POST', '/meus-arquivos/enviar'): aba_arquivos.enviar,
    ('POST', '/sair'): entrada.sair,
}
ROTAS_LEITURA = {
    ('GET', '/'): aba_meus_arquivos.inicio,
    ('GET', '/meus-arquivos'): aba_meus_arquivos.lista_arquivos,
    ('GET', '/meus-arquivos/baixar'): aba_meus_arquivos.baixar,
    ('POST', '/sair'): entrada.sair,
}
ROTAS_ENVIO = {
    **ROTAS_LEITURA,
    ('POST', '/meus-arquivos/pasta'): aba_arquivos.criar_pasta,
    ('POST', '/meus-arquivos/enviar'): aba_arquivos.enviar,
}
ROTAS_COMPLETO = {
    **ROTAS_ENVIO,
    ('GET', '/meus-arquivos/renomear'): aba_arquivos.tela_renomear,
    ('POST', '/meus-arquivos/renomear'): aba_arquivos.renomear,
    ('GET', '/meus-arquivos/apagar'): aba_arquivos.tela_apagar,
    ('POST', '/meus-arquivos/apagar'): aba_arquivos.apagar,
}
ROTAS_USUARIO = {'soenvio': ROTAS_SOENVIO, 'leitura': ROTAS_LEITURA, 'envio': ROTAS_ENVIO, 'completo': ROTAS_COMPLETO}
# Rotas que recebem arquivo: o corpo delas é lido em fluxo (envio.py), e são as únicas em que o nginx aceita corpo grande.
# A de uma pasta liberada (/pastas/<identificador>/enviar) entra pela de /meus-arquivos.
ROTAS_DE_ENVIO = ('/arquivos/enviar', '/meus-arquivos/enviar')
# Rotas de formulário longo: o acesso do remoto do rclone leva chave privada e token, que não cabem no limite comum
# (CORPO_REMOTO_MAX no lugar de CORPO_MAX). O nginx abre a mesma folga só nelas.
ROTAS_LONGAS = ('/destinos/rclone',)
