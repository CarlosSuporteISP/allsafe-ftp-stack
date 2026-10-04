"""Tela de entrada, entrada e saída do painel."""
import administradores
from auditoria import auditar
from config import NOME
from pagina import aviso_rede, e, pagina
from senha import senha_confere
from sessao import (bloqueado, buscar_sessao, criar_sessao, encerrar_sessao, registrar_falha, token_formulario,
                    token_formulario_valido)


def tela_entrada(pedido, codigo=200, erro=''):
    aviso = f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''
    pedido.enviar(codigo, pagina('Entrar', f'''<section class="cartao entrada">
<h1>🗄️ AllSafe FTP</h1>
<p class="suave">Painel de administração da stack.</p>
{aviso}
<form method="post" action="/entrar">
<input type="hidden" name="token" value="{e(token_formulario())}">
<label for="usuario">Usuário</label>
<input id="usuario" name="usuario" required autofocus autocomplete="username" maxlength="32" autocapitalize="none" spellcheck="false">
<label for="senha">Senha</label>
<input id="senha" name="senha" type="password" required autocomplete="current-password" maxlength="256">
<button type="submit">Entrar</button>
</form>
{aviso_rede()}
</section>'''))


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
    if not (0 < len(senha) <= 256 and senha_confere(senha, guardado)):
        registrar_falha(pedido.ip)
        auditar(pedido.ip, 'entrada_falha')
        return tela_entrada(pedido, 401, 'Não foi possível entrar.')
    auditar(pedido.ip, 'entrada_ok', f'admin={nome}')
    cookie = f'__Host-sessao={criar_sessao(pedido.ip, nome)}; Path=/; Secure; HttpOnly; SameSite=Strict'
    return pedido.redirecionar('/', (('Set-Cookie', cookie),))


def sair(pedido, sessao, consulta, formulario, token):
    encerrar_sessao(token)
    auditar(pedido.ip, 'saida', f'admin={sessao["admin"]}')
    vazio = '__Host-sessao=; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=0'
    pedido.redirecionar('/entrar', (('Set-Cookie', vazio),))
