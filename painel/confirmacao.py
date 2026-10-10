# SPDX-License-Identifier: Apache-2.0
"""Confirmação pela senha atual de quem está na sessão.

Pedida em toda alteração de administrador e em tudo o que apaga arquivo ou pasta: um navegador esquecido
aberto não basta para criar um administrador nem para apagar um backup. A do administrador é conferida no
cadastro do painel; a do usuário do FTP, pelo servidor FTP, como na entrada."""
import hmac

import administradores
import conta_ftp
import enderecos
from auditoria import auditar, limpo
from pagina import e
from senha import senha_confere
from sessao import bloqueado, quem, registrar_falha


def campo_senha_atual(sessao, obrigatoria=True, para='para confirmar'):
    rotulo, dono = ('Sua senha do FTP', sessao['usuario']) if sessao['usuario'] else ('Sua senha atual', sessao['admin'])
    return f'''<label for="senha_atual">{rotulo} <span class="suave">(a de {e(dono)}, {para})</span></label>
<input id="senha_atual" name="senha_atual" type="password"{' required' if obrigatoria else ''} autocomplete="current-password" maxlength="256">'''


def confirmacao_recusada(pedido, sessao, formulario):
    """Confere a senha atual de quem está na sessão. Devolve (código, erro); (0, '') quando confere."""
    if bloqueado(pedido.ip):
        auditar(pedido.ip, 'entrada_bloqueada')
        return 429, 'Muitas tentativas. Aguarde alguns minutos e tente de novo.'
    senha = formulario.get('senha_atual', '')
    serve = 0 < len(senha) <= 256
    if sessao['usuario']:
        # A senha aceita tem de ser a da linha do cadastro com que a sessão foi aberta: é a marca que diz isso.
        conta, motivo = conta_ftp.conferir(sessao['usuario'], senha) if serve else (None, '')
        if motivo:
            auditar(pedido.ip, 'falha_comando', f'{quem(sessao)} acao=confirmar_senha motivo={motivo}')
            return 503, 'Não foi possível conferir a sua senha agora. Nada foi alterado. Tente de novo em instantes.'
        confere = conta is not None and hmac.compare_digest(conta['marca'], sessao['marca'])
        evento = 'usuario_senha_atual_recusada'
    else:
        confere = serve and senha_confere(senha, administradores.ler().get(sessao['admin']))
        evento = 'admin_senha_atual_recusada'
    if not confere:
        registrar_falha(pedido.ip)
        auditar(pedido.ip, evento, f'{quem(sessao)} caminho={limpo(pedido.caminho)}')
        enderecos.erro_de_entrada(pedido.ip)
        return 403, 'A sua senha atual não confere. Nada foi alterado.'
    return 0, ''
