# SPDX-License-Identifier: Apache-2.0
"""Tela de entrada, entrada e saída do painel."""
import aba_fator
import administradores
import conta_ftp
import enderecos
import fator
import idioma
from auditoria import auditar
from cena import cena
from config import CFG, FALHAS_MAX, NOME, VALIDADE_CADASTRO, VALIDADE_ETAPA
from icones import icone
from idioma import t
from pagina import e, pagina, prazo_da_sessao, troca_de_idioma
from senha import senha_confere
from sessao import (bloqueado, buscar_etapa, buscar_sessao, criar_etapa, criar_sessao, encerrar_etapa, encerrar_sessao,
                    encerrar_sessoes_de, encerrar_sessoes_do_usuario, quem, registrar_falha, token_formulario,
                    token_formulario_valido)

COOKIE_VAZIO = '__Host-sessao=; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=0'
# A espera do segundo fator tem o cookie dela, que não abre tela nenhuma além da que pede o código ou cadastra o fator.
COOKIE_ETAPA = '__Host-etapa'
ETAPA_VAZIA = f'{COOKIE_ETAPA}=; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=0'


def cookie(token):
    return f'__Host-sessao={token}; Path=/; Secure; HttpOnly; SameSite=Strict'


def cookie_da_etapa(token, prazo=VALIDADE_ETAPA):
    return f'{COOKIE_ETAPA}={token}; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age={prazo}'


def moldura(pedido, codigo, titulo, acesso, extras=()):
    """A tela de quem ainda não entrou: a marca de um lado e, do outro, o que `acesso` pede."""
    pedido.enviar(codigo, pagina(titulo, f'''<div class="entrada">
<section class="entrada-marca" aria-label="AllSafe FTP">
<p class="entrada-nome"><img src="/marca/logo-320.png" alt="ALL-SAFE" width="56" height="56">AllSafe FTP</p>
<div class="entrada-texto">
<p class="entrada-chamada">{t('Backups e arquivos, guardados em um lugar só.')}</p>
<ul class="entrada-pontos">
<li>{icone('equipamento')}{t('Equipamentos de rede, câmeras, sistemas e arquivos de pessoas e empresas')}</li>
<li>{icone('pasta')}{t('Cada conta presa na própria pasta')}</li>
<li>{icone('cadeado')}{t('Painel só por HTTPS, atrás do nginx')}</li>
<li>{icone('relogio')}{t('Sessão encerrada depois de {prazo} sem uso', prazo=prazo_da_sessao())}</li>
</ul>
</div>
{cena()}
</section>
<section class="entrada-acesso">
{acesso}
</section>
</div>''', porta=True), extras=extras)


def tela_entrada(pedido, codigo=200, erro='', extras=()):
    aviso = f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''
    quem_entra = (t('Administradores entram com a conta do painel. Usuários do FTP entram com o nome e a senha do FTP '
                    'e veem só os arquivos da própria pasta.') if CFG['acesso_usuarios'] else t('Painel de administração da stack.'))
    ficha = token_formulario()
    moldura(pedido, codigo, t('Entrar'), f'''<h1>{t('Entrar no painel')}</h1>
<p class="suave">{quem_entra}</p>
{aviso}
<form method="post" action="/entrar">
<input type="hidden" name="token" value="{e(ficha)}">
<label for="usuario">{t('Usuário')}</label>
<input id="usuario" name="usuario" required autofocus autocomplete="username" maxlength="32" autocapitalize="none" spellcheck="false">
<label for="senha">{t('Senha')}</label>
<input id="senha" name="senha" type="password" required autocomplete="current-password" maxlength="256">
<button type="submit">{t('Entrar')}</button>
</form>
<p class="nota">{t('Uso restrito a quem foi autorizado. As tentativas de entrada ficam registradas.')}</p>
{troca_de_idioma('token', ficha)}''', extras)


def sem_aparelho(etapa):
    """O que dizer a quem está sem o aparelho, na tela que pede o código."""
    saida = (t('Sem o aparelho: outro administrador desliga o segundo fator da sua conta, na aba Usuários, ou quem tem '
               'acesso ao servidor desliga pelo terminal.') if etapa['admin'] else
             t('Sem o aparelho: peça ao administrador para desligar o segundo fator da sua conta.'))
    return saida + (' ' + t('Na entrada seguinte, o painel pede o cadastro de um aplicativo de novo.')
                    if CFG['fator_obrigatorio'] else '')


def tela_codigo(pedido, etapa, codigo=200, erro=''):
    aviso = f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''
    moldura(pedido, codigo, t('Código de verificação'), f'''<h1>{t('Código de verificação')}</h1>
<p class="suave">{t('A senha conferiu. Digite o código de seis dígitos que o aplicativo autenticador mostra para esta conta.')}</p>
{aviso}
<form method="post" action="/entrar/codigo" autocomplete="off">
<input type="hidden" name="token" value="{e(token_formulario())}">
<label for="codigo">{t('Código')}</label>
<input id="codigo" name="codigo" required autofocus inputmode="numeric" autocomplete="one-time-code" pattern="[0-9 ]{{6,7}}" maxlength="7" spellcheck="false">
<button type="submit">{t('Confirmar')}</button>
</form>
<p class="nota">{sem_aparelho(etapa)}</p>
<p class="suave"><a href="/entrar">{t('Voltar para usuário e senha')}</a></p>''')


def tela_cadastro(pedido, etapa, codigo=200, erro=''):
    """Cadastro do segundo fator na entrada: a chave fica só na espera e só é gravada com o primeiro código certo."""
    aviso = f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''
    moldura(pedido, codigo, t('Segundo fator'), f'''<h1>{t('Cadastre o segundo fator')}</h1>
<p class="suave">{t('A senha conferiu. Este painel exige, além da senha, o código de seis dígitos de um aplicativo '
                    'autenticador. Cadastre o seu agora para entrar; vale só para este painel, o FTP não muda.')}</p>
{aviso}
<ol class="roteiro">
{aba_fator.passos_da_chave(pedido, etapa['admin'] or etapa['usuario'], etapa['segredo'])}
<li>{t('Digite o código que o aplicativo mostrar.')}</li>
</ol>
<form method="post" action="/entrar/cadastro" autocomplete="off">
<input type="hidden" name="token" value="{e(token_formulario())}">
<label for="codigo">{t('Código do aplicativo')}</label>
<input id="codigo" name="codigo" required inputmode="numeric" autocomplete="one-time-code" pattern="[0-9 ]{{6,7}}" maxlength="7" spellcheck="false">
<button type="submit">{t('Cadastrar e entrar')}</button>
</form>
<p class="aviso">{t('Esta chave <strong>não será mostrada de novo</strong>. Quem a tiver gera os seus códigos: não a guarde '
                    'em foto nem em mensagem.')}</p>
<p class="suave"><a href="/entrar">{t('Voltar para usuário e senha')}</a></p>''')


def espera_do_fator(pedido, lingua, admin=None, usuario=None, conta=None):
    """A senha conferiu. Abre a espera do segundo fator e responde com o caminho dela quando a conta tem o fator
    (falta o código) ou é obrigada a ter (falta o cadastro); devolve False quando a conta entra só com a senha."""
    if fator.ligado(admin or fator.do_usuario(usuario)):
        destino, segredo, prazo = '/entrar/codigo', '', VALIDADE_ETAPA
    elif CFG['fator_obrigatorio']:
        destino, segredo, prazo = '/entrar/cadastro', fator.novo_segredo(), VALIDADE_CADASTRO
    else:
        return False
    # A senha é só metade: nada de sessão, e a contagem de erros do endereço não recomeça ainda.
    auditar(pedido.ip, 'entrada_senha_ok', f'admin={admin}' if admin else f'usuario={usuario}')
    token = criar_etapa(pedido.ip, admin, lingua, usuario=usuario, conta=conta, segredo=segredo)
    pedido.redirecionar(destino, (('Set-Cookie', cookie_da_etapa(token, prazo)), ('Set-Cookie', idioma.cookie(lingua))))
    return True


def entrar(pedido, metodo, formulario):
    if metodo == 'GET':
        token = pedido.token_do_cookie()
        if token and buscar_sessao(token, pedido.ip):
            return pedido.redirecionar('/')
        return tela_entrada(pedido)
    if bloqueado(pedido.ip):
        auditar(pedido.ip, 'entrada_bloqueada')
        return tela_entrada(pedido, 429, t('Muitas tentativas. Aguarde alguns minutos e tente de novo.'))
    if not token_formulario_valido(formulario.get('token', '')):
        return tela_entrada(pedido, 400, t('A página expirou. Tente de novo.'))
    nome, senha = formulario.get('usuario', '').strip().lower(), formulario.get('senha', '')
    # Nome que não existe passa pela mesma conta da senha e recebe a mesma resposta: a tela não diz qual dos dois errou.
    # O nome digitado não vai para a auditoria: é comum a senha cair nesse campo por engano.
    guardado = administradores.ler().get(nome) if NOME.fullmatch(nome) else None
    senha_serve = 0 < len(senha) <= 256
    if senha_serve and senha_confere(senha, guardado):
        lingua = idioma.escolha('admin', nome) or idioma.atual()
        if espera_do_fator(pedido, lingua, admin=nome):
            return None
        auditar(pedido.ip, 'entrada_ok', f'admin={nome}')
        enderecos.esquecer(pedido.ip)    # entrou com usuário e senha certos: a contagem do endereço recomeça
        return pedido.redirecionar('/', (('Set-Cookie', cookie(criar_sessao(pedido.ip, admin=nome, idioma=lingua))),
                                         ('Set-Cookie', idioma.cookie(lingua))))
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
        # Senha que o FTP não chegou a conferir não é erro de usuário e senha: não conta para o bloqueio do endereço.
        if not motivo:
            enderecos.erro_de_entrada(pedido.ip)
        return tela_entrada(pedido, 401, t('Não foi possível entrar.'))
    lingua = idioma.escolha('usuario', nome) or idioma.atual()
    if espera_do_fator(pedido, lingua, usuario=nome, conta=conta):
        return None
    auditar(pedido.ip, 'entrada_ok', f'usuario={nome}')
    enderecos.esquecer(pedido.ip)
    token = criar_sessao(pedido.ip, usuario=nome, marca=conta['marca'], pasta=conta['pasta'], perfil=conta['perfil'],
                         idioma=lingua)
    return pedido.redirecionar('/meus-arquivos', (('Set-Cookie', cookie(token)), ('Set-Cookie', idioma.cookie(lingua))))


def espera_aberta(pedido, de_cadastro):
    """A espera deste navegador, se ainda vale para o caminho pedido: (token, espera, conta do fator). Sem a senha
    conferida há pouco, neste endereço, ou com a conta mudada desde então, não há o que perguntar: a espera é
    encerrada, a resposta manda de volta ao começo e a espera devolvida é None."""
    token = pedido.token_do_cookie(COOKIE_ETAPA)
    etapa = buscar_etapa(token, pedido.ip) if token else None
    conta = ''
    if etapa is not None:
        conta = etapa['admin'] or fator.do_usuario(etapa['usuario'])
        # Cada caminho só serve à espera que foi aberta para ele: a do cadastro não confere código de conta que já
        # tem fator, e a do código não cadastra. Conta que ganhou o fator por outra entrada volta a pedir a senha.
        vale = (etapa['admin'] in administradores.ler() if etapa['admin'] else not conta_ftp.motivo_do_fim(etapa))
        if not vale or bool(etapa['segredo']) != de_cadastro or fator.ligado(conta) == de_cadastro:
            etapa = None
    if etapa is None:
        if token:
            encerrar_etapa(token)
        pedido.redirecionar('/entrar', (('Set-Cookie', ETAPA_VAZIA),))
    return token, etapa, conta


def abrir_sessao(pedido, etapa):
    """A conta passou pela senha e pelo segundo fator: abre a sessão dela e manda para a primeira tela."""
    auditar(pedido.ip, 'entrada_ok', quem(etapa))
    enderecos.esquecer(pedido.ip)    # só agora, com a senha e o código certos, a contagem do endereço recomeça
    if etapa['admin']:
        destino, sessao = '/', criar_sessao(pedido.ip, admin=etapa['admin'], idioma=etapa['idioma'])
    else:
        destino, sessao = '/meus-arquivos', criar_sessao(pedido.ip, usuario=etapa['usuario'], marca=etapa['marca'],
                                                         pasta=etapa['pasta'], perfil=etapa['perfil'], idioma=etapa['idioma'])
    return pedido.redirecionar(destino, (('Set-Cookie', cookie(sessao)), ('Set-Cookie', ETAPA_VAZIA)))


def sem_segredo(pedido, etapa):
    """O fator está ligado e o segredo não está no servidor (cópia restaurada sem os segredos, arquivo apagado):
    a conta não entra, em vez de entrar só com a senha ou de cadastrar outro."""
    auditar(pedido.ip, 'entrada_fator_sem_segredo', quem(etapa))
    return tela_codigo(pedido, etapa, 503, t('O segundo fator desta conta está ligado, mas o segredo dele não está no servidor. '
                                             'Um administrador ou quem tem acesso ao servidor precisa desligá-lo.'))


def codigo(pedido, metodo, formulario):
    """Segunda metade da entrada de quem tem segundo fator: o código do aplicativo autenticador."""
    token, etapa, conta = espera_aberta(pedido, de_cadastro=False)
    if etapa is None:
        return None
    idioma.usar(etapa['idioma'])
    if not fator.segredo_de(conta):
        return sem_segredo(pedido, etapa)
    if metodo == 'GET':
        return tela_codigo(pedido, etapa)
    if bloqueado(pedido.ip):
        auditar(pedido.ip, 'entrada_bloqueada')
        return tela_codigo(pedido, etapa, 429, t('Muitas tentativas. Aguarde alguns minutos e tente de novo.'))
    if not token_formulario_valido(formulario.get('token', '')):
        return tela_codigo(pedido, etapa, 400, t('A página expirou. Tente de novo.'))
    motivo = fator.conferir(conta, formulario.get('codigo', ''))
    if motivo == 'segredo':
        return sem_segredo(pedido, etapa)
    if motivo == 'pausa':
        auditar(pedido.ip, 'entrada_bloqueada', quem(etapa))
        return tela_codigo(pedido, etapa, 429, t('Muitas tentativas. Aguarde alguns minutos e tente de novo.'))
    if motivo:
        etapa['erros'] = etapa.get('erros', 0) + 1
        registrar_falha(pedido.ip)
        auditar(pedido.ip, 'entrada_codigo_recusado', quem(etapa))
        enderecos.erro_de_entrada(pedido.ip)
        if etapa['erros'] >= FALHAS_MAX:
            encerrar_etapa(token)
            return tela_entrada(pedido, 401, t('Não foi possível entrar.'), (('Set-Cookie', ETAPA_VAZIA),))
        return tela_codigo(pedido, etapa, 401, t('O código não confere. Espere o aplicativo mostrar o próximo e tente de novo.'))
    encerrar_etapa(token)
    return abrir_sessao(pedido, etapa)


def cadastro(pedido, metodo, formulario):
    """Segunda metade da entrada de quem é obrigado a ter segundo fator e ainda não tem: o cadastro do aplicativo.
    Código errado aqui não é erro de entrada: a chave está na tela de quem digita, e nada foi gravado ainda."""
    token, etapa, conta = espera_aberta(pedido, de_cadastro=True)
    if etapa is None:
        return None
    idioma.usar(etapa['idioma'])
    if metodo == 'GET':
        return tela_cadastro(pedido, etapa)
    if bloqueado(pedido.ip):
        auditar(pedido.ip, 'entrada_bloqueada')
        return tela_cadastro(pedido, etapa, 429, t('Muitas tentativas. Aguarde alguns minutos e tente de novo.'))
    if not token_formulario_valido(formulario.get('token', '')):
        return tela_cadastro(pedido, etapa, 400, t('A página expirou. Tente de novo.'))
    contador = fator.contador_do(etapa['segredo'], formulario.get('codigo', ''))
    if contador is None:
        return tela_cadastro(pedido, etapa, 400, t('O código não confere com a chave desta tela. Confira a hora do celular, '
                                                   'espere o próximo código e tente de novo.'))
    try:
        gravou = fator.ligar(conta, etapa['segredo'], contador, so_novo=True)
    except OSError as motivo:
        return tela_cadastro(pedido, etapa, 500, t('Não foi possível gravar o segundo fator:') + ' '
                             + (motivo.strerror or t('erro de disco')))
    if not gravou:
        # Outra entrada da mesma conta cadastrou primeiro: vale o cadastro dela, e esta volta a pedir a senha.
        encerrar_etapa(token)
        return pedido.redirecionar('/entrar', (('Set-Cookie', ETAPA_VAZIA),))
    auditar(pedido.ip, 'fator_cadastrado_na_entrada', quem(etapa))
    # As outras sessões e esperas da conta caem: daqui em diante ela só entra com o código.
    if etapa['admin']:
        encerrar_sessoes_de(etapa['admin'])
    else:
        encerrar_sessoes_do_usuario(etapa['usuario'])
    return abrir_sessao(pedido, etapa)


def idioma_da_entrada(pedido, formulario):
    """Troca de idioma de quem ainda não entrou: só o navegador guarda a escolha, e a tela de entrada volta nela.
    Vale com o token do formulário de entrada; sem ele, ou com idioma que não existe, nada muda."""
    novo = formulario.get('idioma', '')
    if novo in idioma.IDIOMAS and token_formulario_valido(formulario.get('token', '')):
        return pedido.redirecionar('/entrar', (('Set-Cookie', idioma.cookie(novo)),))
    return pedido.redirecionar('/entrar')


def sair(pedido, sessao, consulta, formulario, token):
    encerrar_sessao(token)
    auditar(pedido.ip, 'saida', quem(sessao))
    pedido.redirecionar('/entrar', (('Set-Cookie', COOKIE_VAZIO),))
