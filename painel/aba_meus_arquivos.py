# SPDX-License-Identifier: Apache-2.0
"""Tela Meus arquivos: o usuário do FTP navega pela pasta dele, baixa os próprios arquivos e, conforme o perfil,
cria pasta, troca o nome e apaga.

A raiz é a pasta do cadastro, guardada na sessão. O caminho pedido é sempre relativo a ela e passa pelas
mesmas conferências da aba Arquivos: parte por parte, sem `..` e sem seguir link simbólico. O perfil, também
guardado na sessão, diz o que a tela oferece; quem recusa o resto é a tabela de rotas do perfil (rotas.py), e as
ações são as mesmas funções da aba Arquivos, presas à pasta do usuário. Daqui não se envia arquivo."""
import os

from aba_arquivos import (MENSAGENS, Recusado, Vista, abrir, aviso_de_corte, conteudo, entregar, formulario_nova_pasta,
                          linhas_da_lista, parametro, partes, recusa, trilha)
from pagina import cabeca, e, pagina

# perfil ➜ (linha de cima da tela, o que a tela diz que esta conta faz)
PODE = {
    'leitura': ('Os arquivos da sua pasta no FTP, para navegar e baixar.',
                'Aqui você navega e baixa. O perfil desta conta é de leitura: ela não cria, não envia, não renomeia e não '
                'apaga nada, nem aqui nem por FTP. Todo download fica registrado.'),
    'envio': ('Os arquivos da sua pasta no FTP, para navegar, baixar e criar pasta.',
              'Aqui você navega, baixa e cria pasta; enviar arquivo continua sendo feito por FTP. O perfil desta conta é de '
              'envio: o que já foi enviado não é renomeado nem apagado por ela. Todo download e toda pasta criada ficam '
              'registrados.'),
    'completo': ('Os arquivos da sua pasta no FTP, para navegar, baixar e organizar.',
                 'Aqui você navega, baixa, cria pasta, troca o nome e apaga; enviar arquivo continua sendo feito por FTP. '
                 'Apagar pede a sua senha do FTP e não tem lixeira. Todo download e toda alteração ficam registrados.'),
}


def inicio(pedido, sessao, consulta, formulario, token):
    pedido.redirecionar('/meus-arquivos')


def lista_arquivos(pedido, sessao, consulta, formulario, token):
    v, perfil = Vista(sessao), sessao['perfil']
    caminho = parametro(pedido, 'pasta')
    pastas, arquivos, cortado, existe = [], [], False, True
    try:
        lista = partes(caminho)
        descritor = abrir(v.raiz + lista, pasta=True)
    except Recusado as erro:
        # A pasta do usuário nasce no primeiro login por FTP: enquanto não existe, a tela mostra a lista vazia.
        if caminho or erro.codigo != 404:
            return recusa(pedido, sessao, erro, caminho)
        lista, existe = [], False
    else:
        try:
            pastas, arquivos, cortado = conteudo(descritor)
        except OSError:
            pass
        finally:
            os.close(descritor)
    resumo, texto = PODE[perfil]
    feito = MENSAGENS.get(consulta.get('m', ''), '')
    nova_pasta = formulario_nova_pasta(sessao, caminho) if existe and perfil != 'leitura' else ''
    pedido.enviar(200, pagina('Meus arquivos', f'''{cabeca('Meus arquivos', resumo)}
{f'<p class="ok" role="status">{e(feito)}</p>' if feito else ''}
<p class="trilha">{trilha(v, lista)}</p>
{aviso_de_corte(cortado)}<section class="cartao lista"><div class="rolagem"><table>
<thead><tr><th>Nome</th><th>Tamanho</th><th>Modificado</th><th>Ações</th></tr></thead>
<tbody>{linhas_da_lista(v.rota, caminho, pastas, arquivos, gerir=perfil == 'completo')}</tbody></table></div>
<p class="suave">Arquivos da pasta do usuário <strong>{e(sessao['usuario'])}</strong> no FTP. {texto}</p></section>
{nova_pasta}''', sessao, v.rota))


def baixar(pedido, sessao, consulta, formulario, token):
    v = Vista(sessao)
    caminho = parametro(pedido, 'arquivo')
    try:
        lista = partes(caminho)
        if not lista:
            raise Recusado(404)
        descritor = abrir(v.raiz + lista, pasta=False)
    except Recusado as erro:
        return recusa(pedido, sessao, erro, caminho)
    return entregar(pedido, sessao, descritor, lista[-1], v.real(caminho))
