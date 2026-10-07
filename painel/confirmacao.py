# SPDX-License-Identifier: Apache-2.0
"""Confirmação pela senha atual de quem está na sessão.

Pedida em toda alteração de administrador e em tudo o que apaga arquivo ou pasta: um navegador esquecido
aberto não basta para criar um administrador nem para apagar um backup."""
import administradores
from auditoria import auditar, limpo
from pagina import e
from senha import senha_confere
from sessao import bloqueado, registrar_falha


def campo_senha_atual(sessao, obrigatoria=True, para='para confirmar'):
    return f'''<label for="senha_atual">Sua senha atual <span class="suave">(a de {e(sessao['admin'])}, {para})</span></label>
<input id="senha_atual" name="senha_atual" type="password"{' required' if obrigatoria else ''} autocomplete="current-password" maxlength="256">'''


def confirmacao_recusada(pedido, sessao, formulario):
    """Confere a senha atual de quem está na sessão. Devolve (código, erro); (0, '') quando confere."""
    if bloqueado(pedido.ip):
        auditar(pedido.ip, 'entrada_bloqueada')
        return 429, 'Muitas tentativas. Aguarde alguns minutos e tente de novo.'
    senha = formulario.get('senha_atual', '')
    if not (0 < len(senha) <= 256 and senha_confere(senha, administradores.ler().get(sessao['admin']))):
        registrar_falha(pedido.ip)
        auditar(pedido.ip, 'admin_senha_atual_recusada', f'admin={sessao["admin"]} caminho={limpo(pedido.caminho)}')
        return 403, 'A sua senha atual não confere. Nada foi alterado.'
    return 0, ''
