# SPDX-License-Identifier: Apache-2.0
"""Aba Visão geral: situação do FTP e os dados para configurar o equipamento."""
import shutil

from aba_atividade import recentes
from config import ARQ_CERT_FTP, CFG, PASTA_DADOS
from estado import certificado, ftp_no_ar, pastas_distintas, sem_tls, uso_da_pasta, usuarios
from icones import icone
from pagina import alerta_tls, cabeca, e, marca, pagina, quando, tamanho, validade


def visao_geral(pedido, sessao, consulta, formulario, token):
    nomes = usuarios()
    usos = [uso_da_pasta(pasta) for pasta in pastas_distintas(nomes)]
    total = sum(u['bytes'] for u in usos)
    ultimo = max((u['ultimo'] for u in usos), default=0)
    no_ar = ftp_no_ar()
    estado_cert, texto_cert = validade(certificado(ARQ_CERT_FTP))
    try:
        livre = tamanho(shutil.disk_usage(PASTA_DADOS).free) + ' livres no disco'
    except OSError:
        livre = ''
    tls = {'0': 'Sem TLS: texto puro', '1': 'TLS opcional: aceita texto puro',
           '2': 'TLS obrigatório no login', '3': 'TLS obrigatório no login e nos dados'}
    protocolo = {'0': 'FTP sem TLS (texto puro), modo passivo',
                 '1': 'FTPS explícito (FTP com TLS) ou, só para equipamento sem TLS, FTP em texto puro; modo passivo',
                 '3': 'FTPS explícito (FTP com TLS), também no canal de dados; modo passivo'}
    # Uma superfície só: o estado do FTP é a pergunta da tela e ocupa a célula maior; as quatro medidas ficam ao lado.
    pedido.enviar(200, pagina('Visão geral', f'''{cabeca('Visão geral', 'Como o servidor está agora e o que colocar no equipamento para ele enviar o backup.')}
{alerta_tls()}
<section class="situacao" aria-label="Situação do servidor">
<div class="estado {'bom' if no_ar else 'ruim'}"><h2>{icone('servidor')}Servidor FTP</h2>
<p class="numero">{'No ar' if no_ar else 'Fora do ar'}</p>
<p class="suave">{e(tls.get(CFG['ftp_tls'], 'modo TLS ' + CFG['ftp_tls']))}{', com exceção por usuário' if CFG['tls_excecoes'] and sem_tls() else ''}</p>
<p class="atalho"><a href="/seguranca">conferir a segurança</a></p></div>
<div><h2>{icone('usuarios')}Usuários</h2><p class="numero">{len(nomes)}</p><p class="suave">contas cadastradas no FTP</p>
<p class="atalho"><a href="/usuarios">ver os usuários</a></p></div>
<div><h2>{icone('disco')}Espaço usado</h2><p class="numero">{e(tamanho(total))}</p><p class="suave">{e(livre)}</p>
<p class="atalho"><a href="/arquivos">ver as pastas</a></p></div>
<div><h2>{icone('envio')}Último envio</h2><p class="numero menor">{e(quando(ultimo))}</p><p class="suave">arquivo mais novo nas pastas</p>
<p class="atalho"><a href="/arquivos">ver os arquivos</a></p></div>
<div><h2>{icone('certificado')}Certificado do FTP</h2><p class="numero menor">{marca(estado_cert)}{e(texto_cert)}</p>
<p class="atalho"><a href="/seguranca">conferir a impressão digital</a></p></div>
</section>
<div class="dupla">
<section class="cartao"><h2>{icone('equipamento')}Dados para configurar o equipamento</h2>
<dl class="dados">
<div><dt>Servidor</dt><dd><code>{e(CFG['ftp_anunciado'])}</code></dd></div>
<div><dt>Porta de controle</dt><dd><code>{e(CFG['ftp_porta'])}</code>/tcp</dd></div>
<div><dt>Portas passivas</dt><dd><code>{e(CFG['ftp_passiva'])}</code>/tcp</dd></div>
<div class="larga"><dt>Protocolo</dt><dd>{e(protocolo.get(CFG['ftp_tls'], 'FTPS explícito (FTP com TLS), modo passivo'))}</dd></div>
<div class="larga"><dt>Usuário e senha</dt><dd>um usuário por equipamento ou por grupo, criado em <a href="/usuarios">Usuários</a></dd></div>
</dl></section>
<section class="cartao"><h2>{icone('atividade')}Atividade recente</h2>
<ul class="recentes">{recentes()}</ul>
<p class="atalho"><a href="/atividade">ver toda a atividade</a></p></section>
</div>''', sessao, '/'))
