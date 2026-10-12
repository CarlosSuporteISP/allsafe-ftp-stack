# SPDX-License-Identifier: Apache-2.0
"""Segundo fator: ligar e desligar o código do aplicativo autenticador (fator.py).

Cada administrador liga o dele: o painel mostra o código QR e a chave uma vez, e só grava depois de receber um
código certo, que prova que o aplicativo leu. Desligar, qualquer administrador desliga o de qualquer conta,
de administrador ou de usuário do FTP: é a saída de quem perdeu o aparelho. As duas ações pedem a senha de quem
está na sessão (confirmacao.py).

Com PAINEL_SEGUNDO_FATOR_OBRIGATORIO=sim, quem não tem o fator cadastra na entrada (entrada.py), e desligar o de
uma conta é mandá-la cadastrar de novo na entrada seguinte. O usuário do FTP só tem fator por esse caminho."""
import re
import time

import fator
import qr
from aba_administradores import ABA, LISTA, alvo_existente
from aba_usuarios import usuario_alteravel
from auditoria import auditar
from config import CFG
from confirmacao import campo_senha_atual, confirmacao_recusada
from idioma import t
from pagina import e, pagina
from sessao import encerrar_sessoes_de

VALIDADE_DA_CHAVE = 10 * 60    # segundos em que a chave mostrada espera o primeiro código
LUGAR = re.compile(r'[a-z0-9.-]{1,60}')


def chave_nova(sessao, trocar=False):
    """A chave que está esperando o primeiro código, guardada só na memória da sessão: a tela aberta de novo, ou
    devolvida com erro, mostra a mesma, e o aplicativo que já leu continua valendo."""
    guardada = sessao.get('fator_novo')
    if trocar or not guardada or time.time() - guardada[1] > VALIDADE_DA_CHAVE:
        guardada = sessao['fator_novo'] = (fator.novo_segredo(), time.time())
    return guardada[0]


def passos_da_chave(pedido, nome, segredo):
    """Os dois primeiros passos de quem cadastra o aplicativo: o código QR e a chave escrita. Servem à tela de ligar
    e ao cadastro feito na entrada (entrada.py)."""
    lugar = pedido.headers.get('Host', '').lower().rsplit(':', 1)[0]
    endereco = fator.endereco(nome, segredo, lugar if LUGAR.fullmatch(lugar) else '')
    desenho = qr.svg(qr.matriz(endereco.encode()), t('Código QR do segundo fator'))
    em_grupos = ' '.join(segredo[i:i + 4] for i in range(0, len(segredo), 4))
    return f'''<li>{t('Abra o aplicativo autenticador no celular e leia o código abaixo.')}
{desenho}</li>
<li>{t('Sem câmera: escolha digitar a chave no aplicativo, do tipo baseado em tempo, e copie esta.')}
<p class="segredo"><code>{e(em_grupos)}</code></p></li>'''


def tela_ligar(pedido, sessao, erro='', codigo=200):
    pedido.enviar(codigo, pagina(t('Segundo fator'), f'''<h1>{t('Ligar o segundo fator')}</h1>
<section class="cartao estreito">{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<p>{t('Depois de ligado, o painel pede, além da sua senha, o código de seis dígitos de um aplicativo autenticador. '
      'Vale só para a entrada neste painel: o FTP não muda.')}</p>
<ol class="roteiro">
{passos_da_chave(pedido, sessao['admin'], chave_nova(sessao))}
<li>{t('Digite o código que o aplicativo mostrar e confirme com a sua senha.')}</li>
</ol>
<p class="aviso">{t('Esta chave <strong>não será mostrada de novo</strong>. Quem a tiver gera os seus códigos: não a guarde '
                    'em foto nem em mensagem.')}</p>
<form method="post" action="{ABA}/fator/ligar" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<label for="codigo">{t('Código do aplicativo')}</label>
<input id="codigo" name="codigo" required inputmode="numeric" autocomplete="one-time-code" pattern="[0-9 ]{{6,7}}" maxlength="7" spellcheck="false">
{campo_senha_atual(sessao)}
<button type="submit">{t('Ligar o segundo fator')}</button> <a class="botao" href="{LISTA}">{t('Cancelar')}</a>
</form></section>''', sessao, LISTA))


def tela_desligar(pedido, sessao, nome, erro='', codigo=200, do_ftp=False):
    """`do_ftp` diz que `nome` é de usuário do FTP: muda para onde o formulário vai e o que acontece depois."""
    proprio = not do_ftp and nome == sessao['admin']
    cuidado = ''
    if CFG['fator_obrigatorio']:
        efeito = (t('Na sua próxima entrada, o painel pede o cadastro de um aplicativo de novo, com uma chave nova.') if proprio
                  else t('Na próxima entrada, a conta <strong>{nome}</strong> cadastra um aplicativo de novo, com uma chave '
                         'nova. É o caminho de quem perdeu ou trocou o aparelho.', nome=e(nome)))
        if not proprio:
            cuidado = '<p class="aviso">' + t('Aparelho perdido ou roubado: troque também a senha da conta. Até o cadastro '
                                              'novo, quem souber a senha cadastra o aplicativo.') + '</p>'
    elif do_ftp:
        efeito = t('A conta <strong>{nome}</strong> volta a entrar no painel só com usuário e senha.', nome=e(nome))
    else:
        efeito = (t('A sua conta volta a entrar só com usuário e senha.') if proprio else
                  t('A conta <strong>{nome}</strong> volta a entrar só com usuário e senha. É o caminho de quem perdeu o '
                    'aparelho: depois de entrar, ele liga de novo, com uma chave nova.', nome=e(nome)))
    destino, campo = ('/usuarios/fator/desligar', 'usuario') if do_ftp else (ABA + '/fator/desligar', 'admin')
    pedido.enviar(codigo, pagina(t('Segundo fator'), f'''<h1>{t('Desligar o segundo fator')}</h1>
<section class="cartao estreito">{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<p>{efeito}</p>
<p class="suave">{t('A chave guardada é apagada: os códigos do aplicativo deixam de valer.')}</p>
{cuidado}
<form method="post" action="{destino}" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<input type="hidden" name="{campo}" value="{e(nome)}">
{campo_senha_atual(sessao)}
<button class="perigo" type="submit">{t('Sim, desligar o segundo fator')}</button> <a class="botao" href="{LISTA}">{t('Cancelar')}</a>
</form></section>''', sessao, LISTA))


def tela(pedido, sessao, consulta, formulario=None, token=None):
    nome = consulta.get('admin', '')
    if not alvo_existente(pedido, sessao, nome):
        return None
    if fator.ligado(nome):
        return tela_desligar(pedido, sessao, nome)
    if nome == sessao['admin']:
        return tela_ligar(pedido, sessao)
    titulo = t('Segundo fator')
    return pedido.enviar(409, pagina(titulo, f'''<section class="cartao"><h1>{titulo}</h1>
<p>{t('O segundo fator de <strong>{nome}</strong> está desligado. Só o próprio administrador liga o dele, porque a chave '
      'fica no aparelho de quem entra.', nome=e(nome))}</p>
<p><a href="{LISTA}">{t('Voltar para a lista')}</a></p></section>''', sessao, LISTA))


def ligar(pedido, sessao, consulta, formulario, token):
    nome = sessao['admin']
    if not alvo_existente(pedido, sessao, nome):
        return None
    if fator.ligado(nome):
        return pedido.redirecionar(LISTA)
    guardada = sessao.get('fator_novo')
    if not guardada or time.time() - guardada[1] > VALIDADE_DA_CHAVE:
        chave_nova(sessao, trocar=True)
        return tela_ligar(pedido, sessao, t('A chave mostrada venceu. Leia a nova no aplicativo e tente de novo.'), 400)
    contador = fator.contador_do(guardada[0], formulario.get('codigo', ''))
    if contador is None:
        return tela_ligar(pedido, sessao, t('O código não confere com a chave desta tela. Confira a hora do celular, '
                                            'espere o próximo código e tente de novo.'), 400)
    codigo, erro = confirmacao_recusada(pedido, sessao, formulario)
    if erro:
        return tela_ligar(pedido, sessao, erro, codigo)
    try:
        fator.ligar(nome, guardada[0], contador)
    except OSError as motivo:
        return pedido.recusar(500, t('Não foi possível gravar o segundo fator:') + ' ' + (motivo.strerror or t('erro de disco')))
    sessao.pop('fator_novo', None)
    encerrar_sessoes_de(nome, menos=sessao)
    auditar(pedido.ip, 'admin_fator_ligado', f'admin={nome}')
    return pedido.redirecionar(LISTA + '?m=fator_ligado')


def desligar(pedido, sessao, consulta, formulario, token):
    nome = formulario.get('admin', '')
    if not alvo_existente(pedido, sessao, nome):
        return None
    if not fator.ligado(nome):
        return pedido.redirecionar(LISTA)
    codigo, erro = confirmacao_recusada(pedido, sessao, formulario)
    if erro:
        return tela_desligar(pedido, sessao, nome, erro, codigo)
    try:
        fator.desligar(nome)
    except OSError as motivo:
        return pedido.recusar(500, t('Não foi possível gravar o segundo fator:') + ' ' + (motivo.strerror or t('erro de disco')))
    auditar(pedido.ip, 'admin_fator_desligado', f'admin={sessao["admin"]} alvo={nome}')
    return pedido.redirecionar(LISTA + desligado())


def desligado():
    """A mensagem da lista depois de um desligamento: o que vem a seguir depende de o fator ser obrigatório."""
    return '?m=fator_zerado' if CFG['fator_obrigatorio'] else '?m=fator_desligado'


def tela_do_usuario(pedido, sessao, consulta, formulario=None, token=None):
    """O segundo fator de um usuário do FTP: o administrador só desliga, e nunca vê a chave."""
    nome = consulta.get('usuario', '')
    if not usuario_alteravel(pedido, sessao, nome):
        return None
    if not fator.ligado(fator.do_usuario(nome)):
        return pedido.redirecionar(LISTA)
    return tela_desligar(pedido, sessao, nome, do_ftp=True)


def desligar_do_usuario(pedido, sessao, consulta, formulario, token):
    nome = formulario.get('usuario', '')
    if not usuario_alteravel(pedido, sessao, nome):
        return None
    if not fator.ligado(fator.do_usuario(nome)):
        return pedido.redirecionar(LISTA)
    codigo, erro = confirmacao_recusada(pedido, sessao, formulario)
    if erro:
        return tela_desligar(pedido, sessao, nome, erro, codigo, do_ftp=True)
    try:
        fator.desligar(fator.do_usuario(nome))
    except OSError as motivo:
        return pedido.recusar(500, t('Não foi possível gravar o segundo fator:') + ' ' + (motivo.strerror or t('erro de disco')))
    auditar(pedido.ip, 'usuario_fator_desligado', f'admin={sessao["admin"]} usuario={nome}')
    return pedido.redirecionar(LISTA + desligado())
