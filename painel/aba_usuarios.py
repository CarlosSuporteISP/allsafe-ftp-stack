# SPDX-License-Identifier: Apache-2.0
"""Aba Usuários: lista, criação, troca de senha e remoção dos usuários do FTP."""
import secrets
import urllib.parse

from auditoria import auditar, limpo
from config import CFG, NOME, PASTA, SENHA_MAX, SENHA_MIN
from estado import executar_usuario, impedimento_da_pasta, pastas_do_primeiro_nivel, sem_tls, uso_da_pasta, usuarios, vizinhos
from pagina import e, pagina, quando, tamanho

MENSAGENS = {
    'criado': '✅ Usuário criado.',
    'senha': '✅ Senha trocada.',
    'removido': '✅ Usuário removido. Os arquivos continuam na pasta.',
    'tls_dispensado': '⚠️ Usuário dispensado do TLS: a senha e os arquivos dele passam em texto puro.',
    'tls_exigido': '✅ O usuário volta a ser obrigado a usar TLS.',
}


def lista_usuarios(pedido, sessao, consulta, formulario, token):
    aviso = MENSAGENS.get(consulta.get('m', ''), '')
    linhas = []
    cadastro = usuarios()
    excecoes = CFG['tls_excecoes']
    marcados = sem_tls(cadastro) if excecoes else []
    for nome, pasta in cadastro.items():
        uso = uso_da_pasta(pasta)
        destino = urllib.parse.quote(nome)
        if pasta:
            celula = (f'<a href="/arquivos?pasta={urllib.parse.quote(pasta, safe="/")}" title="Abrir na aba Arquivos">'
                      f'<code>{e(CFG["pasta_host"])}/{e(pasta)}</code></a>')
            outros = vizinhos(cadastro, nome)
            if outros:
                celula += f' <span class="etiqueta" title="Também alcançada por: {e(", ".join(outros))}">dividida</span>'
        else:
            celula = '<span class="suave">fora da pasta dos dados</span>'
        mais = ' ou mais' if uso['parcial'] else ''
        if nome == CFG['ftp_usuario']:
            acoes = '<span class="suave">usuário inicial: a senha vem de <code>.secrets/ftp-usuario-inicial-senha.txt</code></span>'
            marca = ' <span class="etiqueta">inicial</span>'
        else:
            acoes = (f'<a class="botao" href="/usuarios/senha?usuario={destino}">🔑 Trocar senha</a> '
                     f'<a class="botao perigo" href="/usuarios/remover?usuario={destino}">🗑️ Remover</a>')
            marca = ''
        coluna_tls = ''
        if excecoes:
            if nome in marcados:
                coluna_tls = '<td><span class="etiqueta">⚠️ sem TLS</span></td>'
                acoes = f'<a class="botao" href="/usuarios/tls?usuario={destino}">🔒 Exigir TLS</a> ' + acoes
            else:
                coluna_tls = '<td>obrigatório</td>'
                acoes = f'<a class="botao" href="/usuarios/tls?usuario={destino}">🔓 Dispensar TLS</a> ' + acoes
        linhas.append(f'<tr><td><strong>{e(nome)}</strong>{marca}</td>'
                      f'<td>{celula}</td>'
                      f'<td>{e(tamanho(uso["bytes"]))}{mais}</td><td>{uso["arquivos"]}{mais}</td>'
                      f'<td>{e(quando(uso["ultimo"]))}</td>{coluna_tls}<td class="acoes">{acoes}</td></tr>')
    corpo = ''.join(linhas) or f'<tr><td colspan="{7 if excecoes else 6}" class="suave">Nenhum usuário ainda.</td></tr>'
    nota_tls = (' <span class="etiqueta">⚠️ sem TLS</span> marca quem o administrador dispensou do TLS '
                '(<code>FTP_TLS_EXCECOES=sim</code>): a senha e os arquivos desse usuário trafegam em texto puro.') if excecoes else ''
    pedido.enviar(200, pagina('Usuários', f'''<h1>👥 Usuários</h1>
{f'<p class="ok" role="status">{e(aviso)}</p>' if aviso else ''}
<p><a class="botao principal" href="/usuarios/novo">➕ Novo usuário</a></p>
<section class="cartao"><div class="rolagem"><table>
<thead><tr><th>Usuário</th><th>Pasta no host</th><th>Uso</th><th>Arquivos</th><th>Último envio</th>{'<th>TLS</th>' if excecoes else ''}<th>Ações</th></tr></thead>
<tbody>{corpo}</tbody></table></div>
<p class="suave">Cada usuário fica preso na pasta dele. Pasta marcada como <span class="etiqueta">dividida</span> é alcançada por
mais de um usuário: um lê, grava e apaga os arquivos do outro. A alteração vale no próximo login, sem reiniciar o FTP.{nota_tls}</p></section>''',
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


def tela_novo(pedido, sessao, consulta=None, formulario=None, token=None, erro='', codigo=200, nome='', pasta=''):
    if not pasta and consulta and PASTA.fullmatch(consulta.get('pasta', '')):
        pasta = consulta['pasta']  # vindo da aba Arquivos: novo usuário nesta pasta
    sugestoes = ''.join(f'<option value="{e(item)}">' for item in pastas_do_primeiro_nivel())
    pedido.enviar(codigo, pagina('Novo usuário', f'''<h1>➕ Novo usuário</h1>
<section class="cartao estreito">{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<form method="post" action="/usuarios/novo" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<label for="usuario">Nome do usuário</label>
<input id="usuario" name="usuario" required maxlength="32" pattern="[a-z_][a-z0-9_\\-]*" value="{e(nome)}" autocapitalize="none" spellcheck="false">
<p class="suave">Letras minúsculas, números, <code>_</code> e <code>-</code>; começa com letra ou <code>_</code>; até 32 caracteres.</p>
<label for="pasta">Pasta <span class="suave">(deixe em branco para usar o nome do usuário)</span></label>
<input id="pasta" name="pasta" maxlength="259" list="pastas" value="{e(pasta)}" autocapitalize="none" spellcheck="false"
 pattern="[A-Za-z0-9_][A-Za-z0-9._\\-]{{0,63}}(/[A-Za-z0-9_][A-Za-z0-9._\\-]{{0,63}}){{0,3}}">
<datalist id="pastas">{sugestoes}</datalist>
<p class="suave">Fica dentro de <code>{e(CFG['pasta_host'])}</code> e é criada se não existir. Até 4 níveis separados por <code>/</code>;
letras, números, <code>_</code>, <code>-</code> e ponto; nenhum nível começa com ponto.</p>
<p class="aviso">⚠️ Usuários com a mesma pasta, ou com uma dentro da outra, leem, gravam e apagam os arquivos um do outro.
Para um equipamento não alcançar o backup de outro, dê a cada um a própria pasta.</p>
{campos_de_senha()}
<button type="submit">Criar usuário</button> <a class="botao" href="/usuarios">Cancelar</a>
</form></section>''', sessao, '/usuarios'))


def criar_usuario(pedido, sessao, consulta, formulario, token):
    nome = formulario.get('usuario', '').strip()
    if not NOME.fullmatch(nome):
        return tela_novo(pedido, sessao, erro='Nome inválido. Veja a regra abaixo do campo.', codigo=400)
    informada = formulario.get('pasta', '').strip()
    pasta = informada or nome
    if nome in usuarios():
        return tela_novo(pedido, sessao, erro='Já existe um usuário com este nome.', codigo=409, nome=nome, pasta=informada)
    impedimento = impedimento_da_pasta(pasta) if PASTA.fullmatch(pasta) else 'Pasta inválida. Veja a regra abaixo do campo.'
    if impedimento:
        auditar(pedido.ip, 'recusa_caminho', f'admin={sessao["admin"]} caminho={limpo(pasta, 120)}')
        return tela_novo(pedido, sessao, erro=impedimento, codigo=400, nome=nome)
    senha, gerada, erro = senha_do_formulario(formulario)
    if erro:
        return tela_novo(pedido, sessao, erro=erro, codigo=400, nome=nome, pasta=informada)
    feito, mensagem = executar_usuario('add', nome, senha, pasta)
    if not feito:
        auditar(pedido.ip, 'falha_comando', f'admin={sessao["admin"]} acao=criar usuario={nome}')
        return tela_novo(pedido, sessao, erro='Não foi possível criar: ' + mensagem, codigo=500, nome=nome, pasta=informada)
    auditar(pedido.ip, 'usuario_criado',
            f'admin={sessao["admin"]} usuario={nome} credencial={"gerada" if gerada else "informada"} pasta={pasta}')
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
    cadastro = usuarios()
    pasta = cadastro.get(nome)
    uso = uso_da_pasta(pasta)
    onde = f"<code>{e(CFG['pasta_host'])}/{e(pasta)}</code>" if pasta else 'na pasta dele'
    outros = vizinhos(cadastro, nome)
    dividida = f'<p class="suave">Esta pasta também é alcançada por: <strong>{e(", ".join(outros))}</strong>.</p>' if outros else ''
    pedido.enviar(200, pagina('Remover usuário', f'''<h1>🗑️ Remover usuário</h1>
<section class="cartao estreito">
<p>Remover <strong>{e(nome)}</strong>? O login deixa de funcionar na hora.</p>
<p class="aviso">📁 Os arquivos <strong>não são apagados</strong>: {uso['arquivos']} arquivo(s), {e(tamanho(uso['bytes']))},
continuam em {onde}.</p>{dividida}
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


def usuario_do_tls(pedido, sessao, nome):
    """Confere o pedido de dispensa do TLS; responde com o erro e devolve False se não der para seguir.
    Vale também para o usuário inicial: o que não se troca pelo painel é a senha dele, não a exigência do TLS."""
    if not CFG['tls_excecoes']:
        pedido.enviar(404, pagina('TLS por usuário desligado', '<section class="cartao"><h1>🔒 TLS por usuário desligado</h1>'
                                '<p>Todos os usuários seguem o <code>FTP_TLS_MODE</code>. Para dispensar um equipamento sem suporte '
                                'a TLS, quem administra o servidor liga <code>FTP_TLS_EXCECOES=sim</code> no <code>.env</code> '
                                'e roda <code>./deploy.sh</code>.</p>'
                                '<p><a href="/usuarios">Voltar para a lista</a></p></section>', sessao, '/usuarios'))
        return False
    if not NOME.fullmatch(nome) or nome not in usuarios():
        pedido.enviar(404, pagina('Usuário não encontrado', '<section class="cartao"><h1>🔎 Usuário não encontrado</h1>'
                                '<p><a href="/usuarios">Voltar para a lista</a></p></section>', sessao, '/usuarios'))
        return False
    return True


def tela_tls(pedido, sessao, consulta, formulario=None, token=None):
    nome = consulta.get('usuario', '')
    if not usuario_do_tls(pedido, sessao, nome):
        return
    if nome in sem_tls():
        titulo, marca, acao, botao, classe = 'Exigir TLS', '🔒', 'exigir', 'Sim, voltar a exigir o TLS', ''
        texto = (f'<p>O usuário <strong>{e(nome)}</strong> entra hoje <strong>sem TLS</strong>. Ao voltar a exigir, o equipamento '
                 'dele só entra com TLS (FTPS explícito): confira antes se ele já foi configurado para isso.</p>'
                 '<p class="suave">A senha dele já trafegou em texto puro: troque-a depois de exigir o TLS.</p>')
    else:
        titulo, marca, acao, botao, classe = 'Dispensar TLS', '🔓', 'dispensar', 'Sim, deixar este usuário entrar sem TLS', ' class="perigo"'
        texto = (f'<p>Deixar <strong>{e(nome)}</strong> entrar no FTP <strong>sem TLS</strong>?</p>'
                 '<p class="aviso">⚠️ A senha e os arquivos deste usuário passam a trafegar em texto puro e podem ser lidos por quem '
                 'estiver na mesma rede. Use só para equipamento antigo sem suporte a TLS, em rede interna isolada, com o '
                 'firewall liberando só esse equipamento. Os outros usuários continuam obrigados a usar TLS.</p>'
                 '<p class="suave">Com TLS este usuário continua entrando normalmente. Dê a ele uma pasta só dele e uma senha '
                 'que não seja usada em mais nenhum lugar.</p>')
    pedido.enviar(200, pagina(titulo, f'''<h1>{marca} {titulo}</h1>
<section class="cartao estreito">{texto}
<form method="post" action="/usuarios/tls">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<input type="hidden" name="usuario" value="{e(nome)}">
<input type="hidden" name="acao" value="{acao}">
<button{classe} type="submit">{botao}</button> <a class="botao" href="/usuarios">Cancelar</a>
</form></section>''', sessao, '/usuarios'))


def alterar_tls(pedido, sessao, consulta, formulario, token):
    nome = formulario.get('usuario', '')
    if not usuario_do_tls(pedido, sessao, nome):
        return None
    acao = formulario.get('acao', '')
    if acao not in ('dispensar', 'exigir'):
        return pedido.redirecionar('/usuarios/tls?usuario=' + urllib.parse.quote(nome))
    feito, mensagem = executar_usuario('tls-' + acao, nome)
    if not feito:
        auditar(pedido.ip, 'falha_comando', f'admin={sessao["admin"]} acao=tls_{acao} usuario={nome}')
        return pedido.recusar(500, 'Não foi possível alterar: ' + mensagem)
    evento = 'tls_dispensado' if acao == 'dispensar' else 'tls_exigido'
    auditar(pedido.ip, evento, f'admin={sessao["admin"]} usuario={nome}')
    return pedido.redirecionar('/usuarios?m=' + evento)
