# SPDX-License-Identifier: Apache-2.0
"""Aba Usuários: todas as contas em uma lista, cada uma com o seu perfil. Os administradores entram no painel; os
usuários do FTP têm o perfil Completo, Envio, Só envio ou Leitura. Aqui ficam a lista, a criação, a edição (perfil, pasta, TLS,
limites e bloqueios), a troca de senha e a remoção dos usuários do FTP; as alterações de administrador ficam em
aba_administradores.py.

A remoção pode levar junto a pasta do usuário, quando nenhum outro a alcança; apagar pede a senha atual
do administrador."""
import secrets
import urllib.parse

import administradores
import limites
from aba_arquivos import Recusado, apagar_caminho, endereco, resposta_parcial
from auditoria import auditar, limpo
from config import ADMINS_MAX, CFG, DOWNLOADS_POR_USUARIO, NOME, PASTA, SENHA_MAX, SENHA_MIN
from confirmacao import campo_senha_atual, confirmacao_recusada
from estado import (bloqueios, executar_usuario, impedimento_da_pasta, pastas_do_primeiro_nivel, perfis, sem_tls, uso_da_pasta,
                    usuarios, vizinhos, vizinhos_de_todos)
from icones import icone
from pagina import cabeca, como, e, pagina, quando, tamanho
from sessao import sessoes_por_admin

# Perfil ➜ nome na tela e o que a conta pode fazer. O administrador é do painel; os outros quatro são do FTP.
PERFIS = (
    ('administrador', 'Administrador', 'entra no painel e administra tudo; não é conta do FTP'),
    ('completo', 'Completo', 'envia, baixa, renomeia e apaga'),
    ('envio', 'Envio', 'envia e baixa; não apaga nem altera o que já enviou'),
    ('soenvio', 'Só envio', 'só envia; não lista nem baixa nada, nem o que ela mesma enviou'),
    ('leitura', 'Leitura', 'só lista e baixa'),
)
PERFIS_FTP = tuple(chave for chave, _, _ in PERFIS[1:])
NOME_DO_PERFIL = {chave: rotulo for chave, rotulo, _ in PERFIS}

MENSAGENS = {
    'criado': 'Usuário criado.',
    'criado_sem_tls': 'Usuário criado e dispensado do TLS: a senha e os arquivos dele passam em texto puro.',
    'criado_tls_falhou': 'Usuário criado, mas a dispensa do TLS não foi gravada: ele só entra com TLS. Tente de novo em Editar.',
    'senha': 'Senha trocada.',
    'pasta': 'Pasta trocada. Os arquivos da pasta anterior continuam nela.',
    'perfil': 'Perfil trocado. Vale na próxima entrada do usuário no FTP.',
    'limites': 'Limites gravados. Valem na próxima entrada do usuário no FTP.',
    'desbloqueado': 'Bloqueio removido. O usuário volta a poder entrar no FTP.',
    'removido': 'Usuário removido. Os arquivos continuam na pasta.',
    'removido_com_pasta': 'Usuário removido e pasta apagada.',
    'tls_dispensado': 'Usuário dispensado do TLS: a senha e os arquivos dele passam em texto puro.',
    'tls_exigido': 'O usuário volta a ser obrigado a usar TLS.',
    'admin_criado': 'Administrador criado.',
    'admin_senha': 'Senha trocada. As outras sessões desse administrador foram encerradas.',
    'admin_nome': 'Nome trocado. As outras sessões desse administrador foram encerradas.',
    'admin_removido': 'Administrador removido. As sessões dele foram encerradas.',
}

ALERTA_SEM_TLS = ('A senha e os arquivos deste usuário passam a trafegar em texto puro e podem ser lidos por quem estiver '
                  'na mesma rede. Use só para equipamento antigo sem suporte a TLS, em rede interna isolada, com o firewall '
                  'liberando só esse equipamento. Os outros usuários continuam obrigados a usar TLS.')


def lista_usuarios(pedido, sessao, consulta, formulario, token):
    aviso = MENSAGENS.get(consulta.get('m', ''), '')
    linhas = []
    cadastro = usuarios()
    excecoes = CFG['tls_excecoes']
    marcados = sem_tls(cadastro) if excecoes else []
    proprios = limites.todos()
    presos = bloqueios()
    divididas = vizinhos_de_todos(cadastro)
    papeis = perfis()
    abertas = sessoes_por_admin()
    colunas = 7 if excecoes else 6
    for nome in administradores.ler():
        destino = urllib.parse.quote(nome)
        proprio = nome == sessao['admin']
        acoes = (f'<a class="botao" href="/administradores/senha?admin={destino}">{icone("chave")}Trocar senha</a> '
                 f'<a class="botao" href="/administradores/nome?admin={destino}">{icone("lapis")}Trocar nome</a>')
        if not proprio:
            acoes += f' <a class="botao perigo" href="/administradores/remover?admin={destino}">{icone("lixeira")}Remover</a>'
        quantas = abertas.get(nome, 0)
        marca = ' <span class="etiqueta">você</span>' if proprio else ''
        linhas.append(f'<tr><td><strong>{e(nome)}</strong>{marca}<span class="perfil">{NOME_DO_PERFIL["administrador"]}</span></td>'
                      f'<td class="suave" colspan="{colunas - 2}">Painel inteiro; '
                      f'{quantas} {"sessão aberta" if quantas == 1 else "sessões abertas"}</td>'
                      f'<td class="acoes">{acoes}</td></tr>')
    for nome, pasta in cadastro.items():
        uso = uso_da_pasta(pasta)
        destino = urllib.parse.quote(nome)
        if pasta:
            celula = (f'<a href="/arquivos?pasta={urllib.parse.quote(pasta, safe="/")}" title="Abrir na aba Arquivos">'
                      f'<code>{e(pasta)}</code></a>')
            outros = divididas[nome]
            if outros:
                celula += f' <span class="etiqueta" title="Também alcançada por: {e(", ".join(outros))}">dividida</span>'
        else:
            celula = '<span class="suave">fora da pasta dos dados</span>'
        mais = ' ou mais' if uso['parcial'] else ''
        # A ordem dos botões põe um curto ao lado de um longo: as duas linhas da coluna ficam com largura parecida.
        acoes = f'<a class="botao" href="/usuarios/editar?usuario={destino}">{icone("lapis")}Editar</a>'
        senha = f' <a class="botao" href="/usuarios/senha?usuario={destino}">{icone("chave")}Trocar senha</a>'
        marca = (' <span class="etiqueta" title="Criado pela instalação, uma vez; removido, não volta sozinho">inicial</span>'
                 if nome == CFG['ftp_usuario'] else '')
        remover = f' <a class="botao perigo" href="/usuarios/remover?usuario={destino}">{icone("lixeira")}Remover</a>'
        dele = limites.resumo(proprios[nome]) if nome in proprios else ''
        if dele:
            marca += f' <span class="etiqueta" title="Limites próprios: {e(dele)}">limites</span>'
        if nome in presos:
            origens = ', '.join(origem for origem, *_ in presos[nome][:5]) + (' e outros' if len(presos[nome]) > 5 else '')
            marca += f' <span class="etiqueta ruim" title="Senhas erradas demais no FTP, vindas de: {e(origens)}">bloqueado</span>'
        coluna_tls = ''
        if excecoes:
            if nome in marcados:
                coluna_tls = '<td data-rotulo="TLS"><span class="etiqueta atencao">sem TLS</span></td>'
                acoes += f' <a class="botao" href="/usuarios/tls?usuario={destino}">{icone("cadeado")}Exigir TLS</a>'
            else:
                coluna_tls = '<td data-rotulo="TLS">obrigatório</td>'
                acoes += f' <a class="botao" href="/usuarios/tls?usuario={destino}">{icone("cadeado-aberto")}Dispensar TLS</a>'
        acoes += senha + remover
        linhas.append(f'<tr><td><strong>{e(nome)}</strong>{marca}'
                      f'<span class="perfil">{NOME_DO_PERFIL[papeis.get(nome, "completo")]}</span></td>'
                      f'<td class="pasta" data-rotulo="Pasta">{celula}</td>'
                      f'<td data-rotulo="Uso">{e(tamanho(uso["bytes"]))}{mais}</td><td data-rotulo="Arquivos">{uso["arquivos"]}{mais}</td>'
                      f'<td data-rotulo="Último envio">{e(quando(uso["ultimo"]))}</td>{coluna_tls}<td class="acoes">{acoes}</td></tr>')
    corpo = ''.join(linhas) or f'<tr><td colspan="{colunas}" class="suave">Nenhum usuário ainda.</td></tr>'
    nota_tls = ('<li><span class="etiqueta atencao">sem TLS</span> Dispensado do TLS pelo administrador, em Editar ou ao criar: '
                'a senha e os arquivos desse usuário trafegam em texto puro.</li>') if excecoes else ''
    pedido.enviar(200, pagina('Usuários', f'''{cabeca('Usuários', 'As contas do painel e do FTP, cada uma com o seu perfil.',
        f'<a class="botao principal" href="/usuarios/novo">{icone("mais")}Novo usuário</a>')}
{f'<p class="ok" role="status">{e(aviso)}</p>' if aviso else ''}
<section class="cartao lista"><div class="rolagem"><table class="blocos contas">
<thead><tr><th>Usuário e perfil</th><th>Pasta</th><th>Uso</th><th>Arquivos</th><th>Último envio</th>{'<th>TLS</th>' if excecoes else ''}<th>Ações</th></tr></thead>
<tbody>{corpo}</tbody></table></div>
{como('Como funcionam os perfis e as etiquetas', f'''<ul class="legenda">
<li><strong>Administrador</strong> entra neste painel e administra tudo; não é conta do FTP. Alterar administrador pede a sua senha
atual, e ninguém remove a própria conta. Até {ADMINS_MAX} administradores.</li>
<li><strong>Completo</strong> envia, baixa, renomeia e apaga. <strong>Envio</strong> envia e baixa, sem apagar nem alterar o que já
enviou. <strong>Só envio</strong> só envia: não lista nem baixa nada. <strong>Leitura</strong> só lista e baixa. O perfil vale no FTP e na entrada do usuário pelo painel.</li>
<li>Cada usuário do FTP fica preso na pasta dele, dentro de <code>{e(CFG['pasta_host'])}</code> no servidor. Toda alteração vale no
próximo login, sem reiniciar o FTP.</li>
<li><span class="etiqueta">dividida</span> Pasta alcançada por mais de um usuário: cada um mexe nos arquivos do outro até onde o
perfil dele deixa.</li>
<li><span class="etiqueta">limites</span> Limite próprio, ajustado em Editar.</li>
<li><span class="etiqueta ruim">bloqueado</span> Recusado pelo FTP por senhas erradas demais vindas de um endereço: o bloqueio sai
sozinho no fim do prazo, ou em Editar.</li>
{nota_tls}</ul>''')}</section>''',
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


def tela_senha_gerada(pedido, sessao, nome, senha, titulo, nota=''):
    pedido.enviar(200, pagina(titulo, f'''<h1>{e(titulo)}</h1>
<section class="cartao"><p>Usuário <strong>{e(nome)}</strong>. Senha gerada pelo painel:</p>
<p class="segredo"><code>{e(senha)}</code></p>
{f'<p class="aviso" role="alert">{e(nota)}</p>' if nota else ''}
<p class="aviso">Copie agora para o equipamento ou para o seu cofre de senhas. Ela <strong>não será mostrada de novo</strong>
e não fica guardada em lugar nenhum além do hash do FTP.</p>
<p><a class="botao principal" href="/usuarios">Já copiei: voltar para a lista</a></p></section>''', sessao, '/usuarios'))


def campo_da_pasta(rotulo, pasta, obrigatoria=False):
    """Campo da pasta do usuário, com as pastas que já existem como sugestão; o mesmo em criar e em editar."""
    sugestoes = ''.join(f'<option value="{e(item)}">' for item in pastas_do_primeiro_nivel())
    return f'''<label for="pasta">{rotulo}</label>
<input id="pasta" name="pasta" maxlength="259" list="pastas" value="{e(pasta)}" autocapitalize="none" spellcheck="false"{' required' if obrigatoria else ''}
 pattern="[A-Za-z0-9_][A-Za-z0-9._\\-]{{0,63}}(/[A-Za-z0-9_][A-Za-z0-9._\\-]{{0,63}}){{0,3}}">
<datalist id="pastas">{sugestoes}</datalist>
<p class="suave">Fica dentro de <code>{e(CFG['pasta_host'])}</code> e é criada se não existir. Até 4 níveis separados por <code>/</code>;
letras, números, <code>_</code>, <code>-</code> e ponto; nenhum nível começa com ponto.</p>
<p class="aviso">Usuários com a mesma pasta, ou com uma dentro da outra, alcançam os arquivos um do outro, cada um até onde o
perfil dele deixa. Para um equipamento não alcançar o backup de outro, dê a cada um a própria pasta.</p>'''


def campo_do_tls(marcado=False):
    """Caixa que dispensa o usuário novo do TLS; vazio quando o TLS por usuário não vale nesta instalação."""
    if not CFG['tls_excecoes']:
        return ''
    return f'''<label class="marcar"><input type="checkbox" name="sem_tls" value="sim"{' checked' if marcado else ''}> <span>Equipamento sem suporte a TLS: deixar este usuário entrar <strong>sem TLS</strong></span></label>
<p class="aviso">{ALERTA_SEM_TLS} Sem marcar a caixa, o usuário só entra com TLS (FTPS explícito).</p>'''


def campo_do_perfil(marcado, com_administrador=True, legenda='Perfil'):
    """Seletor do perfil, uma opção por linha com o que ela permite. Em Editar o administrador fica de fora: a conta
    dele é outra, guardada em outro arquivo."""
    opcoes = ''.join(
        f'<label class="marcar"><input type="radio" id="perfil-{chave}" name="perfil" value="{chave}"{" checked" if chave == marcado else ""}> '
        f'<span><strong>{rotulo}</strong>: {e(nota)}.</span></label>'
        for chave, rotulo, nota in PERFIS if com_administrador or chave != 'administrador')
    return f'<fieldset class="perfis"><legend>{legenda}</legend>{opcoes}</fieldset>'


def tela_novo(pedido, sessao, consulta=None, formulario=None, token=None, erro='', codigo=200, nome='', pasta='', sem_tls_marcado=False,
              perfil=''):
    if not pasta and consulta and PASTA.fullmatch(consulta.get('pasta', '')):
        pasta = consulta['pasta']  # vindo da aba Arquivos: novo usuário nesta pasta
    perfil = perfil or (consulta or {}).get('perfil', '')
    if perfil not in NOME_DO_PERFIL:
        perfil = 'completo'
    pedido.enviar(codigo, pagina('Novo usuário', f'''<h1>Novo usuário</h1>
<section class="cartao estreito">{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<form method="post" action="/usuarios/novo" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
{campo_do_perfil(perfil)}
<label for="usuario">Nome do usuário</label>
<input id="usuario" name="usuario" required maxlength="32" pattern="[a-z_][a-z0-9_\\-]*" value="{e(nome)}" autocapitalize="none" spellcheck="false">
<p class="suave">Letras minúsculas, números, <code>_</code> e <code>-</code>; começa com letra ou <code>_</code>; até 32 caracteres.</p>
<div class="so-ftp">{campo_da_pasta('Pasta <span class="suave">(deixe em branco para usar o nome do usuário)</span>', pasta)}</div>
{campos_de_senha()}
<div class="so-ftp">{campo_do_tls(sem_tls_marcado)}</div>
<div class="so-admin">{campo_senha_atual(sessao, obrigatoria=False, para='pedida para criar administrador')}</div>
<button type="submit">Criar usuário</button> <a class="botao" href="/usuarios">Cancelar</a>
</form></section>''', sessao, '/usuarios'))


def criar_usuario(pedido, sessao, consulta, formulario, token):
    nome = formulario.get('usuario', '').strip()
    # A caixa só existe com o TLS por usuário valendo: fora disso o campo é ignorado, e não recusado.
    dispensar = CFG['tls_excecoes'] and formulario.get('sem_tls') == 'sim'
    perfil = formulario.get('perfil', 'completo')
    if perfil not in PERFIS_FTP:
        return tela_novo(pedido, sessao, erro='Perfil inválido.', codigo=400, sem_tls_marcado=dispensar)
    if not NOME.fullmatch(nome):
        return tela_novo(pedido, sessao, erro='Nome inválido. Veja a regra abaixo do campo.', codigo=400, sem_tls_marcado=dispensar,
                         perfil=perfil)
    informada = formulario.get('pasta', '').strip()
    pasta = informada or nome
    if nome in usuarios():
        return tela_novo(pedido, sessao, erro='Já existe um usuário com este nome.', codigo=409, nome=nome, pasta=informada,
                         sem_tls_marcado=dispensar, perfil=perfil)
    impedimento = impedimento_da_pasta(pasta) if PASTA.fullmatch(pasta) else 'Pasta inválida. Veja a regra abaixo do campo.'
    if impedimento:
        auditar(pedido.ip, 'recusa_caminho', f'admin={sessao["admin"]} caminho={limpo(pasta, 120)}')
        return tela_novo(pedido, sessao, erro=impedimento, codigo=400, nome=nome, sem_tls_marcado=dispensar, perfil=perfil)
    senha, gerada, erro = senha_do_formulario(formulario)
    if erro:
        return tela_novo(pedido, sessao, erro=erro, codigo=400, nome=nome, pasta=informada, sem_tls_marcado=dispensar, perfil=perfil)
    feito, mensagem = executar_usuario('add', nome, senha, pasta, pares=(perfil,))
    if not feito:
        auditar(pedido.ip, 'falha_comando', f'admin={sessao["admin"]} acao=criar usuario={nome}')
        return tela_novo(pedido, sessao, erro='Não foi possível criar: ' + mensagem, codigo=500, nome=nome, pasta=informada,
                         sem_tls_marcado=dispensar, perfil=perfil)
    auditar(pedido.ip, 'usuario_criado',
            f'admin={sessao["admin"]} usuario={nome} credencial={"gerada" if gerada else "informada"} pasta={pasta} perfil={perfil}')
    resultado = 'criado'
    if dispensar:
        # O usuário já existe: se a dispensa falhar, ele fica obrigado a usar TLS, que é o lado seguro.
        feito, _ = executar_usuario('tls-dispensar', nome)
        if feito:
            auditar(pedido.ip, 'tls_dispensado', f'admin={sessao["admin"]} usuario={nome}')
            resultado = 'criado_sem_tls'
        else:
            auditar(pedido.ip, 'falha_comando', f'admin={sessao["admin"]} acao=tls_dispensar usuario={nome}')
            resultado = 'criado_tls_falhou'
    if gerada:
        return tela_senha_gerada(pedido, sessao, nome, senha, 'Usuário criado',
                                 MENSAGENS[resultado] if resultado != 'criado' else '')
    return pedido.redirecionar('/usuarios?m=' + resultado)


def usuario_alteravel(pedido, sessao, nome):
    """Confere o nome recebido; responde com o erro e devolve False se não der para alterar.
    O usuário inicial é alterado e removido como os outros."""
    if not NOME.fullmatch(nome) or nome not in usuarios():
        pedido.enviar(404, pagina('Usuário não encontrado', '<section class="cartao"><h1>Usuário não encontrado</h1>'
                                '<p><a href="/usuarios">Voltar para a lista</a></p></section>', sessao, '/usuarios'))
        return False
    return True


def cartao_limites(sessao, nome, dele, erro=''):
    """Formulário dos limites do usuário. `dele` traz o que mostrar em cada campo: os limites gravados ou,
    depois de uma recusa, o que foi digitado."""
    def numero(chave, rotulo, nota):
        return (f'<label for="{chave}">{rotulo} <span class="suave">({nota})</span></label>\n'
                f'<input id="{chave}" name="{chave}" type="number" min="{limites.piso(chave)}" max="{limites.teto(chave)}" step="1" '
                f'inputmode="numeric" value="{e(str(dele.get(chave, "")))}">')
    padrao = (f'vazio: {CFG["bloqueio_tentativas"]}, o padrão da stack' if CFG['bloqueio_tentativas']
              else 'vazio: o padrão da stack, que está desligado')
    return f'''<section class="cartao estreito" id="limites"><h2>Limites</h2>{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<p>Campo vazio quer dizer <strong>sem limite próprio</strong>: vale o da stack.</p>
<form method="post" action="/usuarios/limites" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<input type="hidden" name="usuario" value="{e(nome)}">
{numero('sessoes', 'Sessões ao mesmo tempo no FTP', 'conexões abertas com este usuário')}
{numero('download', 'Taxa de download, em KB por segundo', 'no FTP e nos downloads dele pelo painel')}
{numero('envio', 'Taxa de envio, em KB por segundo', 'no FTP; cada arquivo enviado leva pelo menos 256 ÷ taxa segundos')}
<label for="inicio">Horário em que o FTP aceita a entrada: das</label>
<input id="inicio" name="inicio" type="time" value="{e(str(dele.get('inicio', '')))}">
<label for="fim">até as</label>
<input id="fim" name="fim" type="time" value="{e(str(dele.get('fim', '')))}">
{numero('baixar', 'Downloads ao mesmo tempo pelo painel', f'vazio: {DOWNLOADS_POR_USUARIO}')}
{numero('tentativas', 'Senhas erradas no FTP até o bloqueio', f'{padrao}; 0: este usuário nunca é bloqueado')}
{numero('minutos', 'Minutos de bloqueio', f'vazio: {CFG["bloqueio_minutos"]}, o padrão da stack; é também o tempo em que as senhas erradas se somam')}
<p class="suave">Os limites valem na próxima entrada do usuário no FTP. Quando um limite do FTP muda, a sessão dele no
painel é encerrada. Quem confere a senha do painel é o FTP: fora do horário, ou com todas as sessões dele ocupadas, o
usuário também não entra no painel.</p>
<p class="suave">O bloqueio vale só para este usuário e só para o endereço que errou a senha: os outros endereços e a entrada
dele pelo painel continuam valendo. Entrada certa zera a contagem. Entrada fora do horário conta como senha errada.
Equipamentos que chegam ao FTP pelo mesmo endereço são bloqueados juntos. Mudar um destes dois campos tira os
bloqueios do usuário.</p>
<button type="submit">Gravar limites</button> <a class="botao" href="/usuarios">Cancelar</a>
</form></section>'''


def cartao_bloqueios(sessao, nome, erro=''):
    """Bloqueios por tentativa do usuário no FTP, com o botão que os tira; vazio quando não há nenhum."""
    dele = bloqueios().get(nome, [])
    if not dele and not erro:
        return ''
    linhas = ''.join(f'<tr><td class="origem"><code>{e(origem)}</code></td><td>{erradas}</td><td>{e(quando(desde))}</td><td>{e(quando(expira))}</td></tr>'
                     for origem, expira, desde, erradas in dele)
    return f'''<section class="cartao medio" id="bloqueios"><h2>Bloqueios</h2>{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<p>O FTP está recusando este usuário quando ele chega dos endereços abaixo, por senhas erradas demais. Com a senha certa
ele também é recusado, até o fim do prazo.</p>
<div class="rolagem"><table>
<thead><tr><th>Origem</th><th>Senhas erradas</th><th>Bloqueado em</th><th>Até</th></tr></thead>
<tbody>{linhas or '<tr><td colspan="4" class="suave">Nenhum bloqueio em vigor.</td></tr>'}</tbody></table></div>
<form method="post" action="/usuarios/desbloquear" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<input type="hidden" name="usuario" value="{e(nome)}">
<p class="suave">Antes de desbloquear, corrija a senha no equipamento: se ele continuar errando, o bloqueio volta.</p>
<button type="submit">Desbloquear</button>
</form></section>'''


def cartao_perfil(sessao, nome, atual, erro=''):
    """Formulário do perfil do usuário do FTP."""
    return f'''<section class="cartao estreito" id="perfil"><h2>Perfil</h2>{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<form method="post" action="/usuarios/perfil" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<input type="hidden" name="usuario" value="{e(nome)}">
{campo_do_perfil(atual, com_administrador=False, legenda='O que este usuário pode fazer')}
<p class="suave">O perfil vale no FTP e na entrada do usuário pelo painel. A troca vale no próximo login no FTP e encerra a sessão
dele no painel; sessão de FTP que já está aberta segue com o perfil anterior até sair.</p>
<p class="suave">No perfil Envio, o arquivo passa a ser do servidor assim que termina de chegar: daí em diante o usuário não o
apaga, não o renomeia e não grava por cima. Equipamento que envia sempre com o mesmo nome de arquivo precisa do perfil Completo.</p>
<p class="suave">No perfil Só envio, a conta entra em uma área de entrada vazia e cada arquivo que chega é movido para a pasta do
usuário: ela não lista nem baixa o que está lá. Nome repetido não substitui o anterior: o novo é guardado com a data e a hora no
nome. Equipamento que envia com um nome provisório e renomeia no fim, ou que confere o envio listando a pasta, precisa de outro perfil.</p>
<button type="submit">Gravar perfil</button> <a class="botao" href="/usuarios">Cancelar</a>
</form></section>'''


def cartao_tls(nome):
    """Como o usuário entra no FTP e o caminho para mudar; com o TLS por usuário sem efeito, o motivo."""
    destino = urllib.parse.quote(nome)
    if not CFG['tls_excecoes']:
        return f'''<section class="cartao estreito" id="tls"><h2>TLS</h2>
<p>Este usuário segue o <code>FTP_TLS_MODE</code>, como todos os outros.</p>
<p class="suave">Dispensar um usuário do TLS não está disponível nesta instalação: {CFG['tls_sem_excecao']}. Quem muda isso é
quem administra o servidor, no <code>.env</code>, com <code>./deploy.sh</code> em seguida.</p></section>'''
    if nome in sem_tls():
        return f'''<section class="cartao estreito" id="tls"><h2>TLS</h2>
<p class="aviso" role="alert">Este usuário entra <strong>sem TLS</strong>: a senha e os arquivos dele trafegam em texto puro e podem
ser lidos por quem estiver na mesma rede. Com TLS ele continua entrando normalmente.</p>
<p><a class="botao" href="/usuarios/tls?usuario={destino}">Exigir TLS</a></p>
<p class="suave">Volte a exigir assim que o equipamento tiver suporte a TLS, e troque a senha em seguida.</p></section>'''
    return f'''<section class="cartao estreito" id="tls"><h2>TLS</h2>
<p>Este usuário só entra com <strong>TLS</strong> (FTPS explícito).</p>
<p><a class="botao" href="/usuarios/tls?usuario={destino}">Dispensar TLS</a></p>
<p class="suave">Para equipamento antigo sem suporte a TLS, em rede interna isolada. A tela seguinte pede a confirmação.</p></section>'''


def tela_editar(pedido, sessao, consulta, formulario=None, token=None, erro='', codigo=200, pasta='', erro_limites='', digitado=None,
                erro_bloqueio='', erro_perfil=''):
    nome = consulta.get('usuario', '')
    if not usuario_alteravel(pedido, sessao, nome):
        return
    cadastro = usuarios()
    atual = cadastro.get(nome)
    uso = uso_da_pasta(atual)
    destino = urllib.parse.quote(nome)
    onde = f"<code>{e(CFG['pasta_host'])}/{e(atual)}</code>" if atual else '<span class="suave">fora da pasta dos dados</span>'
    outros = vizinhos(cadastro, nome)
    dividida = f' Também alcançada por: <strong>{e(", ".join(outros))}</strong>.' if outros else ''
    mais = ' ou mais' if uso['parcial'] else ''
    inicial = ' <span class="etiqueta">inicial</span>' if nome == CFG['ftp_usuario'] else ''
    if digitado is None:
        digitado = limites.ler(nome)
        horario = digitado['horario']
        digitado['inicio'] = f'{horario[:2]}:{horario[2:4]}' if horario else ''
        digitado['fim'] = f'{horario[5:7]}:{horario[7:]}' if horario else ''
    pedido.enviar(codigo, pagina('Editar usuário', f'''<h1>Editar usuário</h1>
<div class="fichas">
<section class="cartao estreito">
<p>Usuário <strong>{e(nome)}</strong>{inicial}. O nome não muda: é com ele que o equipamento entra no FTP.</p>
<p><a class="botao" href="/usuarios/senha?usuario={destino}">Trocar senha</a> <a class="botao" href="/usuarios">Voltar para a lista</a></p>
</section>
{cartao_bloqueios(sessao, nome, erro_bloqueio)}
{cartao_perfil(sessao, nome, perfis().get(nome, 'completo'), erro_perfil)}
<section class="cartao estreito"><h2>Pasta</h2>{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<p>Pasta atual: {onde}, com {uso['arquivos']}{mais} arquivo(s), {e(tamanho(uso['bytes']))}{mais}.{dividida}</p>
<form method="post" action="/usuarios/pasta" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<input type="hidden" name="usuario" value="{e(nome)}">
{campo_da_pasta('Pasta nova', pasta, obrigatoria=True)}
<p class="suave">Os arquivos da pasta atual <strong>não são movidos nem apagados</strong>: continuam onde estão, e o usuário deixa de
alcançá-los. A troca vale no próximo login no FTP e encerra a sessão dele no painel.</p>
<button type="submit">Trocar pasta</button> <a class="botao" href="/usuarios">Cancelar</a>
</form></section>
{cartao_tls(nome)}
{cartao_limites(sessao, nome, digitado, erro_limites)}
</div>''', sessao, '/usuarios'))


def gravar_limites(pedido, sessao, consulta, formulario, token):
    nome = formulario.get('usuario', '')
    if not usuario_alteravel(pedido, sessao, nome):
        return None
    valores, erro = limites.do_formulario(formulario)
    if erro:
        return tela_editar(pedido, sessao, {'usuario': nome}, erro_limites=erro, codigo=400, digitado=formulario)
    feito, mensagem = executar_usuario('limites', nome, pares=limites.pares(valores))
    if not feito:
        auditar(pedido.ip, 'falha_comando', f'admin={sessao["admin"]} acao=gravar_limites usuario={nome}')
        return tela_editar(pedido, sessao, {'usuario': nome}, erro_limites='Não foi possível gravar: ' + mensagem,
                           codigo=500, digitado=formulario)
    gravados = ' '.join(f'{chave}={valores[chave] if valores[chave] != "" else "-"}' for chave in limites.CHAVES)
    auditar(pedido.ip, 'limites_alterados', f'admin={sessao["admin"]} usuario={nome} {gravados}')
    return pedido.redirecionar('/usuarios?m=limites')


def desbloquear(pedido, sessao, consulta, formulario, token):
    nome = formulario.get('usuario', '')
    if not usuario_alteravel(pedido, sessao, nome):
        return None
    origens = len(bloqueios().get(nome, []))
    feito, mensagem = executar_usuario('desbloquear', nome)
    if not feito:
        auditar(pedido.ip, 'falha_comando', f'admin={sessao["admin"]} acao=desbloquear usuario={nome}')
        return tela_editar(pedido, sessao, {'usuario': nome}, erro_bloqueio='Não foi possível desbloquear: ' + mensagem, codigo=500)
    auditar(pedido.ip, 'bloqueio_removido', f'admin={sessao["admin"]} usuario={nome} origens={origens}')
    return pedido.redirecionar('/usuarios?m=desbloqueado')


def trocar_perfil(pedido, sessao, consulta, formulario, token):
    nome = formulario.get('usuario', '')
    if not usuario_alteravel(pedido, sessao, nome):
        return None
    perfil = formulario.get('perfil', '')
    anterior = perfis().get(nome, 'completo')
    if perfil not in PERFIS_FTP:
        return tela_editar(pedido, sessao, {'usuario': nome}, erro_perfil='Perfil inválido.', codigo=400)
    if perfil == anterior:
        return tela_editar(pedido, sessao, {'usuario': nome}, erro_perfil='Este já é o perfil do usuário.', codigo=409)
    feito, mensagem = executar_usuario('perfil', nome, pares=(perfil,))
    if not feito:
        auditar(pedido.ip, 'falha_comando', f'admin={sessao["admin"]} acao=trocar_perfil usuario={nome}')
        return tela_editar(pedido, sessao, {'usuario': nome}, erro_perfil='Não foi possível trocar: ' + mensagem, codigo=500)
    auditar(pedido.ip, 'perfil_trocado', f'admin={sessao["admin"]} usuario={nome} perfil={perfil} anterior={anterior}')
    return pedido.redirecionar('/usuarios?m=perfil')


def trocar_pasta(pedido, sessao, consulta, formulario, token):
    nome = formulario.get('usuario', '')
    if not usuario_alteravel(pedido, sessao, nome):
        return None
    pasta = formulario.get('pasta', '').strip()
    anterior = usuarios().get(nome)
    if not PASTA.fullmatch(pasta):
        impedimento = 'Pasta inválida. Veja a regra abaixo do campo.'
    elif pasta == anterior:
        return tela_editar(pedido, sessao, {'usuario': nome}, erro='Esta já é a pasta do usuário.', codigo=409, pasta=pasta)
    else:
        impedimento = impedimento_da_pasta(pasta)
    if impedimento:
        auditar(pedido.ip, 'recusa_caminho', f'admin={sessao["admin"]} caminho={limpo(pasta, 120)}')
        return tela_editar(pedido, sessao, {'usuario': nome}, erro=impedimento, codigo=400)
    feito, mensagem = executar_usuario('pasta', nome, pasta=pasta)
    if not feito:
        auditar(pedido.ip, 'falha_comando', f'admin={sessao["admin"]} acao=trocar_pasta usuario={nome}')
        return tela_editar(pedido, sessao, {'usuario': nome}, erro='Não foi possível trocar: ' + mensagem, codigo=500, pasta=pasta)
    auditar(pedido.ip, 'pasta_trocada', f'admin={sessao["admin"]} usuario={nome} pasta={pasta} anterior={anterior or "fora"}')
    return pedido.redirecionar('/usuarios?m=pasta')


def tela_trocar_senha(pedido, sessao, consulta, formulario=None, token=None, erro='', codigo=200):
    nome = consulta.get('usuario', '')
    if not usuario_alteravel(pedido, sessao, nome):
        return
    do_segredo = ('\n<p class="suave">Este é o usuário inicial. A senha trocada aqui vale até o arquivo '
                  '<code>.secrets/ftp-usuario-inicial-senha.txt</code> ser alterado: aí, na subida seguinte do serviço '
                  '<code>ftp</code>, volta a valer a do arquivo.</p>') if nome == CFG['ftp_usuario'] else ''
    pedido.enviar(codigo, pagina('Trocar senha', f'''<h1>Trocar senha</h1>
<section class="cartao estreito">{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<p>Usuário <strong>{e(nome)}</strong>. A senha antiga deixa de valer no próximo login.</p>{do_segredo}
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
        return tela_senha_gerada(pedido, sessao, nome, senha, 'Senha trocada')
    return pedido.redirecionar('/usuarios?m=senha')


def tela_remover(pedido, sessao, consulta, formulario=None, token=None, erro='', codigo=200):
    nome = consulta.get('usuario', '')
    if not usuario_alteravel(pedido, sessao, nome):
        return
    cadastro = usuarios()
    pasta = cadastro.get(nome)
    uso = uso_da_pasta(pasta, validade=0)
    mais = ' ou mais' if uso['parcial'] else ''
    onde = f"<code>{e(CFG['pasta_host'])}/{e(pasta)}</code>" if pasta else 'na pasta dele'
    outros = vizinhos(cadastro, nome)
    if outros:
        opcao = (f'<p class="suave">Esta pasta também é alcançada por: <strong>{e(", ".join(outros))}</strong>. Por isso ela não é '
                 'apagada junto com o usuário: os arquivos continuam nela.</p>')
    elif pasta:
        opcao = f'''<label class="marcar"><input type="checkbox" name="apagar_pasta" value="sim"> Apagar também a pasta e tudo o que há nela</label>
<p class="aviso">O painel <strong>não tem lixeira</strong>: a pasta apagada só volta de uma cópia de segurança.
Sem marcar a caixa, os arquivos continuam em {onde}.</p>
{campo_senha_atual(sessao, obrigatoria=False, para='só para apagar a pasta')}'''
    else:
        opcao = ''
    do_inicial = ('\n<p class="suave">Este é o usuário inicial, criado pela instalação. Removido, ele não volta nas próximas '
                  'subidas do serviço <code>ftp</code>; para tê-lo de novo, crie um usuário com o mesmo nome.</p>'
                  ) if nome == CFG['ftp_usuario'] else ''
    pedido.enviar(codigo, pagina('Remover usuário', f'''<h1>Remover usuário</h1>
<section class="cartao estreito">{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<p>Remover <strong>{e(nome)}</strong>? O login deixa de funcionar na hora.</p>{do_inicial}
<p>A pasta dele tem {uso['arquivos']}{mais} arquivo(s), {e(tamanho(uso['bytes']))}{mais}, em {onde}.</p>
<form method="post" action="/usuarios/remover" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<input type="hidden" name="usuario" value="{e(nome)}">
<input type="hidden" name="confirmar" value="sim">
{opcao}
<button class="perigo" type="submit">Sim, remover o usuário</button> <a class="botao" href="/usuarios">Cancelar</a>
</form></section>''', sessao, '/usuarios'))


def remover_usuario(pedido, sessao, consulta, formulario, token):
    """Remove o usuário do cadastro. Com a caixa marcada, apaga também a pasta dele, depois de conferir a senha
    atual do administrador e que nenhum outro usuário alcança a mesma pasta, uma de dentro ou uma de fora."""
    nome = formulario.get('usuario', '')
    if not usuario_alteravel(pedido, sessao, nome):
        return None
    if formulario.get('confirmar') != 'sim':
        return pedido.redirecionar('/usuarios/remover?usuario=' + urllib.parse.quote(nome))
    com_pasta = formulario.get('apagar_pasta') == 'sim'
    pasta = ''
    if com_pasta:
        cadastro = usuarios()
        pasta = cadastro.get(nome)
        if not pasta or vizinhos(cadastro, nome):
            return tela_remover(pedido, sessao, {'usuario': nome}, erro='A pasta deste usuário não pode ser apagada junto: outro '
                                'usuário a alcança, ou ela fica fora da pasta dos dados. Nada foi alterado.', codigo=409)
        codigo, erro = confirmacao_recusada(pedido, sessao, formulario)
        if codigo:
            return tela_remover(pedido, sessao, {'usuario': nome}, erro=erro, codigo=codigo)
    feito, mensagem = executar_usuario('del', nome)
    if not feito:
        auditar(pedido.ip, 'falha_comando', f'admin={sessao["admin"]} acao=remover usuario={nome}')
        return pedido.recusar(500, 'Não foi possível remover: ' + mensagem)
    auditar(pedido.ip, 'usuario_removido', f'admin={sessao["admin"]} usuario={nome}' + (f' pasta={pasta}' if com_pasta else ''))
    if not com_pasta:
        return pedido.redirecionar('/usuarios?m=removido')
    # O usuário já saiu do cadastro: ninguém mais grava na pasta enquanto ela é apagada.
    try:
        itens, parada = apagar_caminho(pasta)
    except Recusado as motivo:
        if motivo.codigo == 404:  # a pasta nunca chegou a existir
            return pedido.redirecionar('/usuarios?m=removido_com_pasta')
        itens, parada = 0, 'erro'
    registro = f'admin={sessao["admin"]} tipo=pasta caminho={pasta}'
    if not parada:
        auditar(pedido.ip, 'item_apagado', f'{registro} itens={itens} usuario={nome}')
        return pedido.redirecionar('/usuarios?m=removido_com_pasta')
    if itens:
        auditar(pedido.ip, 'item_apagado', f'{registro} itens={itens} completo=nao usuario={nome}')
    else:
        auditar(pedido.ip, 'falha_comando', f'admin={sessao["admin"]} acao=apagar caminho={pasta}')
    # O usuário não existe mais: o que sobrou da pasta termina de ser apagado pela aba Arquivos.
    return resposta_parcial(pedido, sessao, itens, parada, endereco('/arquivos/apagar', 'item', pasta),
                            endereco('/arquivos', 'pasta', pasta), '/usuarios')


def usuario_do_tls(pedido, sessao, nome):
    """Confere o pedido de dispensa do TLS; responde com o erro e devolve False se não der para seguir.
    Vale também para o usuário inicial."""
    if not CFG['tls_excecoes']:
        pedido.enviar(404, pagina('TLS por usuário sem efeito', '<section class="cartao"><h1>TLS por usuário sem efeito</h1>'
                                '<p>Todos os usuários seguem o <code>FTP_TLS_MODE</code>. Dispensar um usuário do TLS não está '
                                f'disponível nesta instalação: {CFG["tls_sem_excecao"]}. Quem muda isso é quem administra o '
                                'servidor, no <code>.env</code>, com <code>./deploy.sh</code> em seguida.</p>'
                                '<p><a href="/usuarios">Voltar para a lista</a></p></section>', sessao, '/usuarios'))
        return False
    if not NOME.fullmatch(nome) or nome not in usuarios():
        pedido.enviar(404, pagina('Usuário não encontrado', '<section class="cartao"><h1>Usuário não encontrado</h1>'
                                '<p><a href="/usuarios">Voltar para a lista</a></p></section>', sessao, '/usuarios'))
        return False
    return True


def tela_tls(pedido, sessao, consulta, formulario=None, token=None):
    nome = consulta.get('usuario', '')
    if not usuario_do_tls(pedido, sessao, nome):
        return
    if nome in sem_tls():
        titulo, acao, botao, classe = 'Exigir TLS', 'exigir', 'Sim, voltar a exigir o TLS', ''
        texto = (f'<p>O usuário <strong>{e(nome)}</strong> entra hoje <strong>sem TLS</strong>. Ao voltar a exigir, o equipamento '
                 'dele só entra com TLS (FTPS explícito): confira antes se ele já foi configurado para isso.</p>'
                 '<p class="suave">A senha dele já trafegou em texto puro: troque-a depois de exigir o TLS.</p>')
    else:
        titulo, acao, botao, classe = 'Dispensar TLS', 'dispensar', 'Sim, deixar este usuário entrar sem TLS', ' class="perigo"'
        texto = (f'<p>Deixar <strong>{e(nome)}</strong> entrar no FTP <strong>sem TLS</strong>?</p>'
                 f'<p class="aviso">{ALERTA_SEM_TLS}</p>'
                 '<p class="suave">Com TLS este usuário continua entrando normalmente. Dê a ele uma pasta só dele e uma senha '
                 'que não seja usada em mais nenhum lugar. A dispensa vale em instantes; as sessões em andamento no FTP '
                 'não são interrompidas.</p>')
    pedido.enviar(200, pagina(titulo, f'''<h1>{titulo}</h1>
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
