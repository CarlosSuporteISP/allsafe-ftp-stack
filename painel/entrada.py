# SPDX-License-Identifier: Apache-2.0
"""Tela de entrada, entrada e saída do painel."""
import administradores
import conta_ftp
from auditoria import auditar
from config import CFG, NOME
from icones import icone
from pagina import aviso_rede, e, pagina
from senha import senha_confere
from sessao import (bloqueado, buscar_sessao, criar_sessao, encerrar_sessao, quem, registrar_falha, token_formulario,
                    token_formulario_valido)

COOKIE_VAZIO = '__Host-sessao=; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=0'


def cookie(token):
    return f'__Host-sessao={token}; Path=/; Secure; HttpOnly; SameSite=Strict'


# Desenho do lado da marca: cada equipamento chega pelo FTPS e cai na própria pasta. É enfeite (o texto ao lado diz o mesmo),
# feito aqui mesmo, no traço da logo, sem pedido de rede.
def _caminho():
    linhas = (28, 76, 124, 172)
    entra = ('M96 28H146l42 42h12', 'M96 76H174l14 14h12', 'M96 124H174l14-14h12', 'M96 172H146l42-42h12')
    sai = ('M248 70h12l42-42H352', 'M248 90h12l14-14H352', 'M248 110h12l14 14H352', 'M248 130h12l42 42H352')
    pontas = ''.join(f'M12 {y}a4 4 0 1 1-8 0 4 4 0 0 1 8 0z' for y in linhas)
    pastas = ''.join(f'M360 {y - 5}a2 2 0 0 1 2-2h3.5l2 2.5h6.5a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2h-12a2 2 0 0 1-2-2z' for y in linhas)
    nomes = ''.join(f'<text x="22" y="{y + 5}">{nome}</text>' for y, nome in zip(linhas, ('roteador', 'switch', 'OLT', 'rádio')))
    destinos = ''.join(f'<text class="pasta" x="386" y="{y + 5}">{nome}</text>' for y, nome in zip(linhas, ('roteador', 'switch', 'olt', 'radio')))
    return ('<svg class="caminho" viewBox="0 0 464 200" aria-hidden="true">'
            f'<path class="fio" d="{"".join(entra + sai)}{pontas}"/><path class="destino" d="{pastas}"/>'
            '<rect class="portao" x="200" y="52" width="48" height="96" rx="12"/>'
            '<path class="tranca" d="M217 92h14a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1h-14a1 1 0 0 1-1-1v-8a1 1 0 0 1 1-1zM219 92v-4a5 5 0 0 1 10 0v4"/>'
            f'<text class="sigla" x="224" y="128">FTPS</text>{nomes}{destinos}</svg>')


CAMINHO = _caminho()


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
{CAMINHO}
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
{aviso_rede()}
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
    token = criar_sessao(pedido.ip, usuario=nome, marca=conta['marca'], pasta=conta['pasta'])
    return pedido.redirecionar('/meus-arquivos', (('Set-Cookie', cookie(token)),))


def sair(pedido, sessao, consulta, formulario, token):
    encerrar_sessao(token)
    auditar(pedido.ip, 'saida', quem(sessao))
    pedido.redirecionar('/entrar', (('Set-Cookie', COOKIE_VAZIO),))
