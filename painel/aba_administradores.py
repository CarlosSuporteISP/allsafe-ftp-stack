# SPDX-License-Identifier: Apache-2.0
"""Administradores: quem entra no painel. Criação, troca de senha, troca de nome e remoção; a lista é a da aba Usuários,
onde o administrador aparece com o perfil dele.

Toda alteração pede de novo a senha de quem está na sessão (confirmacao.py): um navegador esquecido aberto
não basta para criar um administrador nem para trocar a senha de outro."""
import urllib.parse

import aba_usuarios
import administradores
import idioma
from aba_usuarios import campos_de_senha, senha_do_formulario
from auditoria import auditar
from config import ADMINS_MAX, NOME
from confirmacao import campo_senha_atual, confirmacao_recusada
from idioma import N, t
from pagina import e, pagina
from senha import gerar_hash
from sessao import encerrar_sessoes_de, renomear_sessoes

ABA = '/administradores'
LISTA = '/usuarios'         # os administradores aparecem na lista de usuários, com o perfil Administrador
SUMIU = N('A sua conta de administrador não existe mais. Saia e entre de novo.')


def lista(pedido, sessao, consulta, formulario, token):
    """O endereço antigo da lista de administradores leva à lista de usuários."""
    return pedido.redirecionar(LISTA)


def gravar(funcao):
    """Aplica a alteração no arquivo. Devolve (código, erro); (0, '') quando gravou."""
    try:
        erro = administradores.alterar(funcao)
    except OSError as motivo:
        return 500, t('Não foi possível gravar o arquivo de administradores:') + ' ' + (motivo.strerror or t('erro de disco'))
    return (409, erro) if erro else (0, '')


def alvo_existente(pedido, sessao, nome):
    """Confere o nome recebido; responde com o erro e devolve False se o administrador não existe."""
    if NOME.fullmatch(nome) and nome in administradores.ler():
        return True
    titulo = t('Administrador não encontrado')
    pedido.enviar(404, pagina(titulo, f'<section class="cartao"><h1>{titulo}</h1>'
                              f'<p><a href="{LISTA}">{t("Voltar para a lista")}</a></p></section>', sessao, LISTA))
    return False


def tela_senha_gerada(pedido, sessao, nome, senha, titulo):
    pedido.enviar(200, pagina(titulo, f'''<h1>{e(titulo)}</h1>
<section class="cartao"><p>{t('Administrador <strong>{nome}</strong>. Senha gerada pelo painel:', nome=e(nome))}</p>
<p class="segredo"><code>{e(senha)}</code></p>
<p class="aviso">{t('Copie agora para o seu cofre de senhas ou entregue a quem vai usar. Ela <strong>não será mostrada de '
                    'novo</strong>: o painel guarda só o hash.')}</p>
<p><a class="botao principal" href="{LISTA}">{t('Já copiei: voltar para a lista')}</a></p></section>''', sessao, LISTA))


def tela_novo(pedido, sessao, consulta=None, formulario=None, token=None, erro='', codigo=200, nome=''):
    """O formulário é o de Novo usuário, com o perfil Administrador marcado."""
    if not erro:
        return pedido.redirecionar(LISTA + '/novo?perfil=administrador')
    return aba_usuarios.tela_novo(pedido, sessao, erro=erro, codigo=codigo, nome=nome, perfil='administrador')


def criar(pedido, sessao, consulta, formulario, token):
    nome = formulario.get('usuario', '').strip()
    if not NOME.fullmatch(nome):
        return tela_novo(pedido, sessao, erro=t('Nome inválido. Veja a regra abaixo do campo.'), codigo=400)
    if nome in administradores.ler():
        return tela_novo(pedido, sessao, erro=t('Já existe um administrador com este nome.'), codigo=409, nome=nome)
    senha, gerada, erro = senha_do_formulario(formulario)
    if erro:
        return tela_novo(pedido, sessao, erro=erro, codigo=400, nome=nome)
    codigo, erro = confirmacao_recusada(pedido, sessao, formulario)
    if erro:
        return tela_novo(pedido, sessao, erro=erro, codigo=codigo, nome=nome)
    guardado = gerar_hash(senha)

    def aplicar(admins):
        if sessao['admin'] not in admins:
            return t(SUMIU)
        if nome in admins:
            return t('Já existe um administrador com este nome.')
        if len(admins) >= ADMINS_MAX:
            return t('Limite de {maximo} administradores atingido: remova um antes de criar outro.', maximo=ADMINS_MAX)
        admins[nome] = guardado
        return ''
    codigo, erro = gravar(aplicar)
    if erro:
        return tela_novo(pedido, sessao, erro=erro, codigo=codigo, nome=nome)
    auditar(pedido.ip, 'admin_criado', f'admin={sessao["admin"]} novo={nome} credencial={"gerada" if gerada else "informada"}')
    if gerada:
        return tela_senha_gerada(pedido, sessao, nome, senha, t('Administrador criado'))
    return pedido.redirecionar(LISTA + '?m=admin_criado')


def criar_conta(pedido, sessao, consulta, formulario, token):
    """Recebe o formulário de Novo usuário: o perfil Administrador cria a conta do painel; os outros, a do FTP."""
    if formulario.get('perfil') == 'administrador':
        return criar(pedido, sessao, consulta, formulario, token)
    return aba_usuarios.criar_usuario(pedido, sessao, consulta, formulario, token)


def tela_trocar_senha(pedido, sessao, consulta, formulario=None, token=None, erro='', codigo=200):
    nome = consulta.get('admin', '')
    if not alvo_existente(pedido, sessao, nome):
        return
    efeito = (t('A sua senha antiga deixa de valer na hora e as outras sessões desse administrador são encerradas.')
              if nome == sessao['admin'] else
              t('A senha de <strong>{nome}</strong> antiga deixa de valer na hora e as outras sessões desse administrador '
                'são encerradas.', nome=e(nome)))
    pedido.enviar(codigo, pagina(t('Trocar senha'), f'''<h1>{t('Trocar senha de administrador')}</h1>
<section class="cartao estreito">{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<p>{efeito}</p>
<form method="post" action="{ABA}/senha" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<input type="hidden" name="admin" value="{e(nome)}">
{campos_de_senha()}
{campo_senha_atual(sessao)}
<button type="submit">{t('Trocar senha')}</button> <a class="botao" href="{LISTA}">{t('Cancelar')}</a>
</form></section>''', sessao, LISTA))


def trocar_senha(pedido, sessao, consulta, formulario, token):
    nome = formulario.get('admin', '')
    if not alvo_existente(pedido, sessao, nome):
        return None
    senha, gerada, erro = senha_do_formulario(formulario)
    if erro:
        return tela_trocar_senha(pedido, sessao, {'admin': nome}, erro=erro, codigo=400)
    codigo, erro = confirmacao_recusada(pedido, sessao, formulario)
    if erro:
        return tela_trocar_senha(pedido, sessao, {'admin': nome}, erro=erro, codigo=codigo)
    guardado = gerar_hash(senha)

    def aplicar(admins):
        if sessao['admin'] not in admins:
            return t(SUMIU)
        if nome not in admins:
            return t('Este administrador não existe mais.')
        admins[nome] = guardado
        return ''
    codigo, erro = gravar(aplicar)
    if erro:
        return pedido.recusar(codigo, erro)
    encerrar_sessoes_de(nome, menos=sessao)
    auditar(pedido.ip, 'admin_senha_trocada', f'admin={sessao["admin"]} alvo={nome} credencial={"gerada" if gerada else "informada"}')
    if gerada:
        return tela_senha_gerada(pedido, sessao, nome, senha, t('Senha trocada'))
    return pedido.redirecionar(LISTA + '?m=admin_senha')


def tela_trocar_nome(pedido, sessao, consulta, formulario=None, token=None, erro='', codigo=200, novo=''):
    nome = consulta.get('admin', '')
    if not alvo_existente(pedido, sessao, nome):
        return
    pedido.enviar(codigo, pagina(t('Trocar nome'), f'''<h1>{t('Trocar nome de administrador')}</h1>
<section class="cartao estreito">{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<p>{t('Administrador <strong>{nome}</strong>. A senha continua a mesma; o nome antigo deixa de entrar na hora.', nome=e(nome))}</p>
<form method="post" action="{ABA}/nome" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<input type="hidden" name="admin" value="{e(nome)}">
<label for="nome">{t('Nome novo')}</label>
<input id="nome" name="nome" required maxlength="32" pattern="[a-z_][a-z0-9_\\-]*" value="{e(novo)}" autocapitalize="none" spellcheck="false">
<p class="suave">{t('Letras minúsculas, números, <code>_</code> e <code>-</code>; começa com letra ou <code>_</code>; até 32 caracteres.')}</p>
{campo_senha_atual(sessao)}
<button type="submit">{t('Trocar nome')}</button> <a class="botao" href="{LISTA}">{t('Cancelar')}</a>
</form></section>''', sessao, LISTA))


def trocar_nome(pedido, sessao, consulta, formulario, token):
    nome, novo = formulario.get('admin', ''), formulario.get('nome', '').strip()
    if not alvo_existente(pedido, sessao, nome):
        return None
    if not NOME.fullmatch(novo):
        return tela_trocar_nome(pedido, sessao, {'admin': nome}, erro=t('Nome inválido. Veja a regra abaixo do campo.'), codigo=400)
    if novo == nome:
        return tela_trocar_nome(pedido, sessao, {'admin': nome}, erro=t('O nome novo é igual ao atual.'), codigo=400, novo=novo)
    if novo in administradores.ler():
        return tela_trocar_nome(pedido, sessao, {'admin': nome}, erro=t('Já existe um administrador com este nome.'),
                                codigo=409, novo=novo)
    codigo, erro = confirmacao_recusada(pedido, sessao, formulario)
    if erro:
        return tela_trocar_nome(pedido, sessao, {'admin': nome}, erro=erro, codigo=codigo, novo=novo)

    def aplicar(admins):
        if sessao['admin'] not in admins:
            return t(SUMIU)
        if nome not in admins:
            return t('Este administrador não existe mais.')
        if novo in admins:
            return t('Já existe um administrador com este nome.')
        trocados = {(novo if atual == nome else atual): guardado for atual, guardado in admins.items()}
        admins.clear()
        admins.update(trocados)
        return ''
    codigo, erro = gravar(aplicar)
    if erro:
        return pedido.recusar(codigo, erro)
    quem = sessao['admin']
    encerrar_sessoes_de(nome, menos=sessao)
    renomear_sessoes(nome, novo)
    idioma.renomear('admin', nome, novo)
    auditar(pedido.ip, 'admin_renomeado', f'admin={quem} de={nome} para={novo}')
    return pedido.redirecionar(LISTA + '?m=admin_nome')


def propria_conta(pedido, sessao, nome):
    """Ninguém remove a própria conta: responde com o motivo e devolve True quando é o caso."""
    if nome != sessao['admin']:
        return False
    motivo = t('Ninguém remove a própria conta, para o painel nunca ficar sem administrador. '
               'Peça a outro administrador para removê-la.')
    pedido.enviar(409, pagina(t('Remover administrador'), f'<section class="cartao"><h1>{t("Esta é a sua conta")}</h1>'
                              f'<p>{motivo}</p>'
                              f'<p><a href="{LISTA}">{t("Voltar para a lista")}</a></p></section>', sessao, LISTA))
    return True


def tela_remover(pedido, sessao, consulta, formulario=None, token=None, erro='', codigo=200):
    nome = consulta.get('admin', '')
    if not alvo_existente(pedido, sessao, nome) or propria_conta(pedido, sessao, nome):
        return
    pedido.enviar(codigo, pagina(t('Remover administrador'), f'''<h1>{t('Remover administrador')}</h1>
<section class="cartao estreito">{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<p>{t('Remover <strong>{nome}</strong>? Ele deixa de entrar no painel na hora e as sessões abertas dele são encerradas. '
      'Os usuários do FTP e os arquivos não mudam.', nome=e(nome))}</p>
<form method="post" action="{ABA}/remover" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<input type="hidden" name="admin" value="{e(nome)}">
{campo_senha_atual(sessao)}
<button class="perigo" type="submit">{t('Sim, remover o administrador')}</button> <a class="botao" href="{LISTA}">{t('Cancelar')}</a>
</form></section>''', sessao, LISTA))


def remover(pedido, sessao, consulta, formulario, token):
    nome = formulario.get('admin', '')
    if not alvo_existente(pedido, sessao, nome) or propria_conta(pedido, sessao, nome):
        return None
    codigo, erro = confirmacao_recusada(pedido, sessao, formulario)
    if erro:
        return tela_remover(pedido, sessao, {'admin': nome}, erro=erro, codigo=codigo)

    def aplicar(admins):
        if sessao['admin'] not in admins:
            return t(SUMIU)
        if nome not in admins:
            return t('Este administrador não existe mais.')
        del admins[nome]
        return ''
    codigo, erro = gravar(aplicar)
    if erro:
        return pedido.recusar(codigo, erro)
    encerrar_sessoes_de(nome)
    idioma.esquecer('admin', nome)
    auditar(pedido.ip, 'admin_removido', f'admin={sessao["admin"]} alvo={nome}')
    return pedido.redirecionar(LISTA + '?m=admin_removido')
