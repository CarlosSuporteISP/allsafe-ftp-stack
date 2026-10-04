"""Rotas do painel depois da entrada: método e caminho ➜ função que responde.

São duas tabelas, uma por papel: ROTAS é a do administrador e ROTAS_USUARIO, a do usuário do FTP, que só
navega e baixa na pasta dele. O que não está na tabela do papel não existe para ele.
Toda função recebe (pedido, sessao, consulta, formulario, token); `pedido` é o tratador de atendimento.py."""
import aba_administradores
import aba_arquivos
import aba_atividade
import aba_meus_arquivos
import aba_seguranca
import aba_usuarios
import aba_visao_geral
import entrada

ROTAS = {
    ('GET', '/'): aba_visao_geral.visao_geral,
    ('GET', '/usuarios'): aba_usuarios.lista_usuarios,
    ('GET', '/usuarios/novo'): aba_usuarios.tela_novo,
    ('POST', '/usuarios/novo'): aba_usuarios.criar_usuario,
    ('GET', '/usuarios/senha'): aba_usuarios.tela_trocar_senha,
    ('POST', '/usuarios/senha'): aba_usuarios.trocar_senha,
    ('GET', '/usuarios/remover'): aba_usuarios.tela_remover,
    ('POST', '/usuarios/remover'): aba_usuarios.remover_usuario,
    ('GET', '/arquivos'): aba_arquivos.lista_arquivos,
    ('GET', '/arquivos/baixar'): aba_arquivos.baixar,
    ('POST', '/arquivos/pasta'): aba_arquivos.criar_pasta,
    ('GET', '/administradores'): aba_administradores.lista,
    ('GET', '/administradores/novo'): aba_administradores.tela_novo,
    ('POST', '/administradores/novo'): aba_administradores.criar,
    ('GET', '/administradores/senha'): aba_administradores.tela_trocar_senha,
    ('POST', '/administradores/senha'): aba_administradores.trocar_senha,
    ('GET', '/administradores/nome'): aba_administradores.tela_trocar_nome,
    ('POST', '/administradores/nome'): aba_administradores.trocar_nome,
    ('GET', '/administradores/remover'): aba_administradores.tela_remover,
    ('POST', '/administradores/remover'): aba_administradores.remover,
    ('GET', '/seguranca'): aba_seguranca.seguranca,
    ('GET', '/atividade'): aba_atividade.atividade,
    ('POST', '/sair'): entrada.sair,
}

ROTAS_USUARIO = {
    ('GET', '/'): aba_meus_arquivos.inicio,
    ('GET', '/meus-arquivos'): aba_meus_arquivos.lista_arquivos,
    ('GET', '/meus-arquivos/baixar'): aba_meus_arquivos.baixar,
    ('POST', '/sair'): entrada.sair,
}
