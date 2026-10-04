"""Aba Usuários: lista, criação, troca de senha e remoção dos usuários do FTP."""
import secrets
import urllib.parse

from auditoria import auditar
from config import CFG, NOME, SENHA_MAX, SENHA_MIN
from estado import executar_usuario, uso_da_pasta, usuarios
from pagina import e, pagina, quando, tamanho

MENSAGENS = {
    'criado': '✅ Usuário criado.',
    'senha': '✅ Senha trocada.',
    'removido': '✅ Usuário removido. Os arquivos continuam na pasta.',
}


def lista_usuarios(pedido, sessao, consulta, formulario, token):
    aviso = MENSAGENS.get(consulta.get('m', ''), '')
    linhas = []
    for nome in usuarios():
        uso = uso_da_pasta(nome)
        destino = urllib.parse.quote(nome)
        mais = ' ou mais' if uso['parcial'] else ''
        if nome == CFG['ftp_usuario']:
            acoes = '<span class="suave">usuário inicial: a senha vem de <code>.secrets/ftp-usuario-inicial-senha.txt</code></span>'
            marca = ' <span class="etiqueta">inicial</span>'
        else:
            acoes = (f'<a class="botao" href="/usuarios/senha?usuario={destino}">🔑 Trocar senha</a> '
                     f'<a class="botao perigo" href="/usuarios/remover?usuario={destino}">🗑️ Remover</a>')
            marca = ''
        linhas.append(f'<tr><td><strong>{e(nome)}</strong>{marca}</td>'
                      f'<td><a href="/arquivos?pasta={destino}" title="Abrir na aba Arquivos"><code>{e(CFG["pasta_host"])}/{e(nome)}</code></a></td>'
                      f'<td>{e(tamanho(uso["bytes"]))}{mais}</td><td>{uso["arquivos"]}{mais}</td>'
                      f'<td>{e(quando(uso["ultimo"]))}</td><td class="acoes">{acoes}</td></tr>')
    corpo = ''.join(linhas) or '<tr><td colspan="6" class="suave">Nenhum usuário ainda.</td></tr>'
    pedido.enviar(200, pagina('Usuários', f'''<h1>👥 Usuários</h1>
{f'<p class="ok" role="status">{e(aviso)}</p>' if aviso else ''}
<p><a class="botao principal" href="/usuarios/novo">➕ Novo usuário</a></p>
<section class="cartao"><div class="rolagem"><table>
<thead><tr><th>Usuário</th><th>Pasta no host</th><th>Uso</th><th>Arquivos</th><th>Último envio</th><th>Ações</th></tr></thead>
<tbody>{corpo}</tbody></table></div>
<p class="suave">Cada usuário fica preso na própria pasta. A alteração vale no próximo login, sem reiniciar o FTP.</p></section>''',
                            sessao, '/usuarios'))


def campos_de_senha():
    return f'''<label for="senha">Senha <span class="suave">(deixe em branco para o painel gerar uma senha forte)</span></label>
<input id="senha" name="senha" type="password" autocomplete="new-password" minlength="{SENHA_MIN}" maxlength="{SENHA_MAX}">
<label for="confirmacao">Repita a senha</label>
<input id="confirmacao" name="confirmacao" type="password" autocomplete="new-password" maxlength="{SENHA_MAX}">
<p class="suave">Mínimo de {SENHA_MIN} caracteres. A senha gerada aparece uma única vez, na tela seguinte.</p>'''


def senha_do_formulario(formulario):
    """Devolve (senha, gerada, erro)."""
    senha, repetida = formulario.get('senha', ''), formulario.get('confirmacao', '')
    if not senha and not repetida:
        return secrets.token_urlsafe(24), True, ''
    if senha != repetida:
        return '', False, 'As duas senhas não são iguais.'
    if not SENHA_MIN <= len(senha) <= SENHA_MAX:
        return '', False, f'A senha deve ter de {SENHA_MIN} a {SENHA_MAX} caracteres.'
    if any(ord(letra) < 32 or ord(letra) == 127 for letra in senha):
        return '', False, 'A senha não pode ter caractere de controle.'
    return senha, False, ''


def tela_senha_gerada(pedido, sessao, nome, senha, titulo):
    pedido.enviar(200, pagina(titulo, f'''<h1>{e(titulo)}</h1>
<section class="cartao"><p>Usuário <strong>{e(nome)}</strong>. Senha gerada pelo painel:</p>
<p class="segredo"><code>{e(senha)}</code></p>
<p class="aviso">⚠️ Copie agora para o equipamento ou para o seu cofre de senhas. Ela <strong>não será mostrada de novo</strong>
e não fica guardada em lugar nenhum além do hash do FTP.</p>
<p><a class="botao principal" href="/usuarios">Já copiei: voltar para a lista</a></p></section>''', sessao, '/usuarios'))


def tela_novo(pedido, sessao, consulta=None, formulario=None, token=None, erro='', codigo=200, nome=''):
    pedido.enviar(codigo, pagina('Novo usuário', f'''<h1>➕ Novo usuário</h1>
<section class="cartao estreito">{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<form method="post" action="/usuarios/novo" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<label for="usuario">Nome do usuário</label>
<input id="usuario" name="usuario" required maxlength="32" pattern="[a-z_][a-z0-9_\\-]*" value="{e(nome)}" autocapitalize="none" spellcheck="false">
<p class="suave">Letras minúsculas, números, <code>_</code> e <code>-</code>; começa com letra ou <code>_</code>; até 32 caracteres.</p>
{campos_de_senha()}
<button type="submit">Criar usuário</button> <a class="botao" href="/usuarios">Cancelar</a>
</form></section>''', sessao, '/usuarios'))


def criar_usuario(pedido, sessao, consulta, formulario, token):
    nome = formulario.get('usuario', '').strip()
    if not NOME.fullmatch(nome):
        return tela_novo(pedido, sessao, erro='Nome inválido. Veja a regra abaixo do campo.', codigo=400)
    if nome in usuarios():
        return tela_novo(pedido, sessao, erro='Já existe um usuário com este nome.', codigo=409, nome=nome)
    senha, gerada, erro = senha_do_formulario(formulario)
    if erro:
        return tela_novo(pedido, sessao, erro=erro, codigo=400, nome=nome)
    feito, mensagem = executar_usuario('add', nome, senha)
    if not feito:
        auditar(pedido.ip, 'falha_comando', f'admin={sessao["admin"]} acao=criar usuario={nome}')
        return tela_novo(pedido, sessao, erro='Não foi possível criar: ' + mensagem, codigo=500, nome=nome)
    auditar(pedido.ip, 'usuario_criado', f'admin={sessao["admin"]} usuario={nome} credencial={"gerada" if gerada else "informada"}')
    if gerada:
        return tela_senha_gerada(pedido, sessao, nome, senha, '✅ Usuário criado')
    return pedido.redirecionar('/usuarios?m=criado')


def usuario_alteravel(pedido, sessao, nome):
    """Confere o nome recebido; responde com o erro e devolve False se não der para alterar."""
    if not NOME.fullmatch(nome) or nome not in usuarios():
        pedido.enviar(404, pagina('Usuário não encontrado', '<section class="cartao"><h1>🔎 Usuário não encontrado</h1>'
                                '<p><a href="/usuarios">Voltar para a lista</a></p></section>', sessao, '/usuarios'))
        return False
    if nome == CFG['ftp_usuario']:
        pedido.enviar(409, pagina('Usuário inicial', '<section class="cartao"><h1>🔑 Usuário inicial</h1>'
                                '<p>A senha deste usuário vem do arquivo <code>.secrets/ftp-usuario-inicial-senha.txt</code> e é '
                                'reaplicada a cada subida do FTP. Troque por lá: o guia de segredos mostra como.</p>'
                                '<p><a href="/usuarios">Voltar para a lista</a></p></section>', sessao, '/usuarios'))
        return False
    return True


def tela_trocar_senha(pedido, sessao, consulta, formulario=None, token=None, erro='', codigo=200):
    nome = consulta.get('usuario', '')
    if not usuario_alteravel(pedido, sessao, nome):
        return
    pedido.enviar(codigo, pagina('Trocar senha', f'''<h1>🔑 Trocar senha</h1>
<section class="cartao estreito">{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<p>Usuário <strong>{e(nome)}</strong>. A senha antiga deixa de valer no próximo login.</p>
<form method="post" action="/usuarios/senha" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<input type="hidden" name="usuario" value="{e(nome)}">
{campos_de_senha()}
<button type="submit">Trocar senha</button> <a class="botao" href="/usuarios">Cancelar</a>
</form></section>''', sessao, '/usuarios'))


def trocar_senha(pedido, sessao, consulta, formulario, token):
    nome = formulario.get('usuario', '')
    if not usuario_alteravel(pedido, sessao, nome):
        return None
    senha, gerada, erro = senha_do_formulario(formulario)
    if erro:
        return tela_trocar_senha(pedido, sessao, {'usuario': nome}, erro=erro, codigo=400)
    feito, mensagem = executar_usuario('passwd', nome, senha)
    if not feito:
        auditar(pedido.ip, 'falha_comando', f'admin={sessao["admin"]} acao=trocar_senha usuario={nome}')
        return tela_trocar_senha(pedido, sessao, {'usuario': nome}, erro='Não foi possível trocar: ' + mensagem, codigo=500)
    auditar(pedido.ip, 'senha_trocada', f'admin={sessao["admin"]} usuario={nome} credencial={"gerada" if gerada else "informada"}')
    if gerada:
        return tela_senha_gerada(pedido, sessao, nome, senha, '✅ Senha trocada')
    return pedido.redirecionar('/usuarios?m=senha')


def tela_remover(pedido, sessao, consulta, formulario=None, token=None):
    nome = consulta.get('usuario', '')
    if not usuario_alteravel(pedido, sessao, nome):
        return
    uso = uso_da_pasta(nome)
    pedido.enviar(200, pagina('Remover usuário', f'''<h1>🗑️ Remover usuário</h1>
<section class="cartao estreito">
<p>Remover <strong>{e(nome)}</strong>? O login deixa de funcionar na hora.</p>
<p class="aviso">📁 Os arquivos <strong>não são apagados</strong>: {uso['arquivos']} arquivo(s), {e(tamanho(uso['bytes']))},
continuam em <code>{e(CFG['pasta_host'])}/{e(nome)}</code>.</p>
<form method="post" action="/usuarios/remover">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<input type="hidden" name="usuario" value="{e(nome)}">
<input type="hidden" name="confirmar" value="sim">
<button class="perigo" type="submit">Sim, remover o usuário</button> <a class="botao" href="/usuarios">Cancelar</a>
</form></section>''', sessao, '/usuarios'))


def remover_usuario(pedido, sessao, consulta, formulario, token):
    nome = formulario.get('usuario', '')
    if not usuario_alteravel(pedido, sessao, nome):
        return None
    if formulario.get('confirmar') != 'sim':
        return pedido.redirecionar('/usuarios/remover?usuario=' + urllib.parse.quote(nome))
    feito, mensagem = executar_usuario('del', nome)
    if not feito:
        auditar(pedido.ip, 'falha_comando', f'admin={sessao["admin"]} acao=remover usuario={nome}')
        return pedido.recusar(500, 'Não foi possível remover: ' + mensagem)
    auditar(pedido.ip, 'usuario_removido', f'admin={sessao["admin"]} usuario={nome}')
    return pedido.redirecionar('/usuarios?m=removido')
