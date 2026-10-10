# SPDX-License-Identifier: Apache-2.0
"""Tela de entrada, entrada e saída do painel."""
import administradores
import conta_ftp
from auditoria import auditar
from cena import cena
from config import CFG, NOME
from icones import icone
from pagina import e, pagina
from senha import senha_confere
from sessao import (bloqueado, buscar_sessao, criar_sessao, encerrar_sessao, quem, registrar_falha, token_formulario,
                    token_formulario_valido)

COOKIE_VAZIO = '__Host-sessao=; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=0'


def cookie(token):
    return f'__Host-sessao={token}; Path=/; Secure; HttpOnly; SameSite=Strict'


def tela_entrada(pedido, codigo=200, erro=''):
    aviso = f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''
    quem_entra = ('Administradores entram com a conta do painel. Usuários do FTP entram com o nome e a senha do FTP '
                  'e veem só os arquivos da própria pasta.') if CFG['acesso_usuarios'] else 'Painel de administração da stack.'
    pedido.enviar(codigo, pagina('Entrar', f'''<div class="entrada">
<section class="entrada-marca" aria-label="AllSafe FTP">
<p class="entrada-nome"><img src="/marca/logo-320.png" alt="ALL-SAFE" width="56" height="56">AllSafe FTP</p>
<div class="entrada-texto">
<p class="entrada-chamada">O backup dos equipamentos da rede, guardado em um lugar só.</p>
<ul class="entrada-pontos">
<li>{icone('pasta')}Cada equipamento preso na própria pasta</li>
<li>{icone('cadeado')}Painel só por HTTPS, atrás do nginx</li>
<li>{icone('relogio')}Sessão encerrada depois de {CFG['inatividade'] // 60} minutos sem uso</li>
</ul>
</div>
{cena()}
</section>
<section class="entrada-acesso">
<h1>Entrar no painel</h1>
<p class="suave">{quem_entra}</p>
{aviso}
<form method="post" action="/entrar">
<input type="hidden" name="token" value="{e(token_formulario())}">
<label for="usuario">Usuário</label>
<input id="usuario" name="usuario" required autofocus autocomplete="username" maxlength="32" autocapitalize="none" spellcheck="false">
<label for="senha">Senha</label>
<input id="senha" name="senha" type="password" required autocomplete="current-password" maxlength="256">
<button type="submit">Entrar</button>
</form>
<p class="nota">Uso restrito a quem foi autorizado. As tentativas de entrada ficam registradas.</p>
</section>
</div>''', porta=True))


def entrar(pedido, metodo, formulario):
    if metodo == 'GET':
        token = pedido.token_do_cookie()
        if token and buscar_sessao(token, pedido.ip):
            return pedido.redirecionar('/')
        return tela_entrada(pedido)
    if bloqueado(pedido.ip):
        auditar(pedido.ip, 'entrada_bloqueada')
        return tela_entrada(pedido, 429, 'Muitas tentativas. Aguarde alguns minutos e tente de novo.')
    if not token_formulario_valido(formulario.get('token', '')):
        return tela_entrada(pedido, 400, 'A página expirou. Tente de novo.')
    nome, senha = formulario.get('usuario', '').strip().lower(), formulario.get('senha', '')
    # Nome que não existe passa pela mesma conta da senha e recebe a mesma resposta: a tela não diz qual dos dois errou.
    # O nome digitado não vai para a auditoria: é comum a senha cair nesse campo por engano.
    guardado = administradores.ler().get(nome) if NOME.fullmatch(nome) else None
    senha_serve = 0 < len(senha) <= 256
    if senha_serve and senha_confere(senha, guardado):
        auditar(pedido.ip, 'entrada_ok', f'admin={nome}')
        return pedido.redirecionar('/', (('Set-Cookie', cookie(criar_sessao(pedido.ip, admin=nome))),))
    conta, motivo = None, ''
    if CFG['acesso_usuarios'] and senha_serve:
        # Não é administrador com esta senha: pode ser usuário do FTP. Nome que também é de administrador vale só
        # como administrador, mas a conferência no FTP é feita do mesmo jeito: o tempo da resposta não diz quais
        # nomes são de administrador, de usuário do FTP ou de ninguém.
        conta, motivo = conta_ftp.conferir(nome, senha)
        if guardado is not None:
            conta = None
    if conta is None:
        registrar_falha(pedido.ip)
        auditar(pedido.ip, 'entrada_falha', f'conferencia={motivo}' if motivo else '')
        return tela_entrada(pedido, 401, 'Não foi possível entrar.')
    auditar(pedido.ip, 'entrada_ok', f'usuario={nome}')
    token = criar_sessao(pedido.ip, usuario=nome, marca=conta['marca'], pasta=conta['pasta'], perfil=conta['perfil'])
    return pedido.redirecionar('/meus-arquivos', (('Set-Cookie', cookie(token)),))


def sair(pedido, sessao, consulta, formulario, token):
    encerrar_sessao(token)
    auditar(pedido.ip, 'saida', quem(sessao))
    pedido.redirecionar('/entrar', (('Set-Cookie', COOKIE_VAZIO),))
