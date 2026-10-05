# SPDX-License-Identifier: Apache-2.0
"""Tela Meus arquivos: o usuário do FTP navega pela pasta dele e baixa os próprios arquivos.

A raiz é a pasta do cadastro, guardada na sessão. O caminho pedido é sempre relativo a ela e passa pelas
mesmas conferências da aba Arquivos: parte por parte, sem `..` e sem seguir link simbólico. Daqui não se
cria, não se envia, não se renomeia e não se apaga nada."""
import os

from aba_arquivos import (Recusado, abrir, aviso_de_corte, conteudo, endereco, entregar, linhas_da_lista, parametro,
                          partes, recusa, visivel)
from pagina import e, pagina


def inicio(pedido, sessao, consulta, formulario, token):
    pedido.redirecionar('/meus-arquivos')


def trilha(lista):
    """Caminho da pasta aberta, a partir da pasta do usuário, com um link em cada nível."""
    if not lista:
        return '<strong>Início</strong>'
    niveis = ['<a href="/meus-arquivos">Início</a>']
    for indice, parte in enumerate(lista):
        if indice == len(lista) - 1:
            niveis.append(f'<strong>{e(visivel(parte))}</strong>')
        else:
            niveis.append(f'<a href="{e(endereco("/meus-arquivos", "pasta", "/".join(lista[:indice + 1])))}">{e(visivel(parte))}</a>')
    return ' / '.join(niveis)


def lista_arquivos(pedido, sessao, consulta, formulario, token):
    caminho = parametro(pedido, 'pasta')
    pastas, arquivos, cortado = [], [], False
    try:
        lista = partes(caminho)
        descritor = abrir(partes(sessao['pasta']) + lista, pasta=True)
    except Recusado as erro:
        # A pasta do usuário nasce no primeiro login por FTP: enquanto não existe, a tela mostra a lista vazia.
        if caminho or erro.codigo != 404:
            return recusa(pedido, sessao, erro, caminho)
        lista = []
    else:
        try:
            pastas, arquivos, cortado = conteudo(descritor)
        except OSError:
            pass
        finally:
            os.close(descritor)
    pedido.enviar(200, pagina('Meus arquivos', f'''<h1>📁 Meus arquivos</h1>
<p class="trilha">{trilha(lista)}</p>
{aviso_de_corte(cortado)}<section class="cartao"><div class="rolagem"><table>
<thead><tr><th>Nome</th><th>Tamanho</th><th>Modificado</th><th>Ações</th></tr></thead>
<tbody>{linhas_da_lista('/meus-arquivos', caminho, pastas, arquivos)}</tbody></table></div>
<p class="suave">Arquivos da pasta do usuário <strong>{e(sessao['usuario'])}</strong> no FTP. Aqui você navega e baixa:
enviar, renomear e apagar continuam sendo feitos por FTP. Todo download fica registrado.</p></section>''', sessao, '/meus-arquivos'))


def baixar(pedido, sessao, consulta, formulario, token):
    caminho = parametro(pedido, 'arquivo')
    try:
        lista = partes(caminho)
        if not lista:
            raise Recusado(404)
        descritor = abrir(partes(sessao['pasta']) + lista, pasta=False)
    except Recusado as erro:
        return recusa(pedido, sessao, erro, caminho)
    return entregar(pedido, sessao, descritor, lista[-1], f'{sessao["pasta"]}/{caminho}')
