# SPDX-License-Identifier: Apache-2.0
"""Aba Visão geral: situação do FTP, o servidor e os containers em quatro medidas, o que chegou nos últimos dias,
quem parou de enviar e os dados do equipamento."""
import datetime
import shutil
import time
import urllib.parse

import idioma
from aba_atividade import recentes
from aba_servidor import resumo
from config import ARQ_CERT_FTP, CFG, PASTA_DADOS
from estado import DIAS_DO_GRAFICO, certificado, dias_restantes, ftp_no_ar, pastas_distintas, sem_tls, uso_da_pasta, usuarios
from graficos import barras, colunas, faixa, numero
from icones import icone
from idioma import t, tn
from pagina import alerta_tls, cabeca, e, marca, pagina, quando, tamanho, validade


PASTAS_NO_GRAFICO = 6       # pastas do gráfico de espaço e usuários da lista de quem parou de enviar
SEM_ENVIO = 7 * 86400       # depois disso o usuário entra na lista de quem está sem enviar


def dia_curto(data):
    """Dia e mês de uma data, na ordem do idioma do pedido."""
    return idioma.dia_e_mes(f'{data.year}', f'{data.month:02d}', f'{data.day:02d}')[1]


def dia_da_coluna(data):
    """Rótulo de uma coluna do gráfico: só o dia fica escrito; o mês vai para o leitor de tela."""
    if idioma.atual() == 'en':
        return f'<span class="so-leitor">{data.month:02d}-</span>{data.day:02d}'
    return f'{data.day:02d}<span class="so-leitor">/{data.month:02d}</span>'


def recebidos(usos):
    """Cartão dos arquivos por dia: soma, de todas as pastas, os arquivos que têm a data de cada um dos últimos dias."""
    por_dia = [sum(uso['dias'][atras] for uso in usos) for atras in reversed(range(DIAS_DO_GRAFICO))]
    hoje = datetime.date.today()
    datas = [hoje - datetime.timedelta(days=atras) for atras in reversed(range(DIAS_DO_GRAFICO))]
    rotulos = [dia_da_coluna(data) for data in datas[:-1]] + [t('hoje')]
    parcial = (' ' + t('A contagem está incompleta: há pasta grande demais para ser lida inteira.')
               if any(uso['parcial'] for uso in usos) else '')
    return f"""<section class="cartao"><h2>{icone('envio')}{t('Arquivos recebidos por dia')}</h2>
<p class="suave">{t('<strong class="numero">{quantos}</strong> com data de {desde} até hoje, em todas as pastas',
                    quantos=numero(sum(por_dia)), desde=dia_curto(datas[0]))}</p>
{colunas(por_dia, rotulos, t('arquivos'))}
<p class="suave">{t('Conta o que está nas pastas agora, pela data de cada arquivo: o que foi apagado ou substituído não entra.')}{parcial}</p>
</section>"""


def ultimos_envios(nomes):
    """Cartão de quem está enviando: os usuários divididos pela data do arquivo mais novo da pasta de cada um."""
    if not nomes:
        return (f'<section class="cartao"><h2>{icone("relogio")}{t("Último envio por usuário")}</h2><p class="suave">'
                + t('Nenhum usuário cadastrado. O primeiro é criado em <a href="/usuarios">Usuários</a>.') + '</p></section>')
    agora = time.time()
    grupos = {'dia': [], 'semana': [], 'antigo': [], 'nenhum': []}
    for nome, pasta in nomes.items():
        ultimo = uso_da_pasta(pasta)['ultimo']
        idade = agora - ultimo
        grupos['nenhum' if not ultimo else 'dia' if idade < 86400 else 'semana' if idade < SEM_ENVIO else 'antigo'].append((ultimo, nome))
    parados = sorted(grupos['antigo']) + sorted(grupos['nenhum'], key=lambda par: par[1])
    if parados:
        linhas = ''.join(f'<li><strong>{e(nome)}</strong><span class="suave">{e(quando(ultimo)) if ultimo else t("nenhum arquivo na pasta")}</span></li>'
                         for ultimo, nome in parados[:PASTAS_NO_GRAFICO])
        resto = len(parados) - PASTAS_NO_GRAFICO
        lista = (f'<h3>{t("Sem enviar há mais de 7 dias")}</h3><ul class="recentes">{linhas}</ul>'
                 + (f'<p class="suave">{t("e mais {resto}, na aba Usuários.", resto=resto)}</p>' if resto > 0 else ''))
    else:
        lista = f'<p class="suave">{t("Nenhum usuário está há mais de 7 dias sem enviar.")}</p>'
    return f"""<section class="cartao"><h2>{icone('relogio')}{t('Último envio por usuário')}</h2>
{faixa((('bom', len(grupos['dia']), t('nas últimas 24 horas')), ('info', len(grupos['semana']), t('entre 1 e 7 dias')),
        ('atencao', len(grupos['antigo']), t('há mais de 7 dias')), ('neutro', len(grupos['nenhum']), t('sem arquivo na pasta'))))}
{lista}
<p class="atalho"><a href="/usuarios">{t('ver os usuários')}</a></p></section>"""


def espaco(pastas, usos):
    """Cartão do espaço: as pastas que mais ocupam, cada uma com o tamanho e a quantidade de arquivos."""
    maiores = sorted(zip(pastas, usos), key=lambda par: par[1]['bytes'], reverse=True)[:PASTAS_NO_GRAFICO]
    if maiores:
        miolo = barras([(f'<a href="/arquivos?pasta={urllib.parse.quote(pasta, safe="/")}"><code>{e(pasta)}</code></a>', uso['bytes'],
                         f'{e(tamanho(uso["bytes"]))} · '
                         + tn(uso['arquivos'], '{quantos} arquivo', '{quantos} arquivos', quantos=numero(uso['arquivos'])))
                        for pasta, uso in maiores])
        resto = len(pastas) - len(maiores)
        miolo += ('<p class="suave">' + t('As {maiores} maiores de {todas} pastas.', maiores=len(maiores), todas=len(pastas)) + '</p>'
                  if resto > 0 else '')
    else:
        miolo = f'<p class="suave">{t("Nenhuma pasta de usuário ainda.")}</p>'
    return f"""<section class="cartao"><h2>{icone('disco')}{t('Espaço por pasta')}</h2>
{miolo}
<p class="atalho"><a href="/arquivos">{t('ver as pastas')}</a></p></section>"""


def visao_geral(pedido, sessao, consulta, formulario, token):
    nomes = usuarios()
    pastas = pastas_distintas(nomes)
    usos = [uso_da_pasta(pasta) for pasta in pastas]
    total = sum(u['bytes'] for u in usos)
    ultimo = max((u['ultimo'] for u in usos), default=0)
    no_ar = ftp_no_ar()
    # A data é a medida da célula; o que ela quer dizer desce para a linha de baixo, como nas outras.
    info = certificado(ARQ_CERT_FTP)
    estado_cert, dias = validade(info)[0], dias_restantes(info)
    if dias is None:
        data_cert, nota_cert = t('não lido'), t('não foi possível ler o certificado')
    else:
        data_cert = info['vence'].astimezone().strftime(idioma.formato_da_data())
        nota_cert = t('vencido há {dias} dias', dias=-dias) if dias < 0 else t('válido, faltam {dias} dias', dias=dias)
    try:
        livre = t('{espaco} livres no disco', espaco=tamanho(shutil.disk_usage(PASTA_DADOS).free))
    except OSError:
        livre = ''
    tls = {'0': t('Sem TLS: texto puro'), '1': t('TLS opcional: aceita texto puro'),
           '2': t('TLS obrigatório no login'), '3': t('TLS obrigatório no login e nos dados')}
    protocolo = {'0': t('FTP sem TLS (texto puro), modo passivo'),
                 '1': t('FTPS explícito (FTP com TLS) ou, só para equipamento sem TLS, FTP em texto puro; modo passivo'),
                 '3': t('FTPS explícito (FTP com TLS), também no canal de dados; modo passivo')}
    resumo_da_tela = t('Como o servidor está agora e o que colocar no equipamento para ele enviar o backup.')
    # Uma superfície só: o estado do FTP é a pergunta da tela e ocupa a célula maior; as quatro medidas ficam ao lado.
    pedido.enviar(200, pagina(t('Visão geral'), f"""{cabeca('Visão geral', resumo_da_tela)}
{alerta_tls()}
<section class="situacao" aria-label="{t('Situação do servidor')}">
<div class="estado {'bom' if no_ar else 'ruim'}"><h2>{icone('servidor')}{t('Servidor FTP')}</h2>
<p class="numero">{t('No ar') if no_ar else t('Fora do ar')}</p>
<p class="suave">{e(tls.get(CFG['ftp_tls']) or t('modo TLS {modo}', modo=CFG['ftp_tls']))}{', ' + t('com exceção por usuário') if CFG['tls_excecoes'] and sem_tls() else ''}</p>
<p class="atalho"><a href="/seguranca">{t('conferir a segurança')}</a></p></div>
<div><h2>{icone('usuarios')}{t('Usuários')}</h2><p class="numero">{len(nomes)}</p><p class="suave">{t('contas cadastradas no FTP')}</p>
<p class="atalho"><a href="/usuarios">{t('ver os usuários')}</a></p></div>
<div><h2>{icone('disco')}{t('Espaço usado')}</h2><p class="numero">{e(tamanho(total))}</p><p class="suave">{e(livre)}</p>
<p class="atalho"><a href="/arquivos">{t('ver as pastas')}</a></p></div>
<div><h2>{icone('envio')}{t('Último envio')}</h2><p class="numero menor">{e(quando(ultimo))}</p><p class="suave">{t('arquivo mais novo nas pastas')}</p>
<p class="atalho"><a href="/arquivos">{t('ver os arquivos')}</a></p></div>
<div><h2>{icone('certificado')}{t('Certificado do FTP')}</h2><p class="numero menor">{marca(estado_cert)}{e(data_cert)}</p>
<p class="suave">{e(nota_cert)}</p>
<p class="atalho"><a href="/seguranca">{t('conferir a impressão digital')}</a></p></div>
</section>
{resumo()}
<div class="dupla">
{recebidos(usos)}
{ultimos_envios(nomes)}
</div>
<div class="dupla">
{espaco(pastas, usos)}
<section class="cartao"><h2>{icone('atividade')}{t('Atividade recente')}</h2>
<ul class="recentes">{recentes()}</ul>
<p class="atalho"><a href="/atividade">{t('ver toda a atividade')}</a></p></section>
</div>
<section class="cartao"><h2>{icone('equipamento')}{t('Dados para configurar o equipamento')}</h2>
<dl class="dados">
<div><dt>{t('Servidor')}</dt><dd><code>{e(CFG['ftp_anunciado'])}</code></dd></div>
<div><dt>{t('Porta de controle')}</dt><dd><code>{e(CFG['ftp_porta'])}</code>/tcp</dd></div>
<div><dt>{t('Portas passivas')}</dt><dd><code>{e(CFG['ftp_passiva'])}</code>/tcp</dd></div>
<div><dt>{t('Protocolo')}</dt><dd>{e(protocolo.get(CFG['ftp_tls']) or t('FTPS explícito (FTP com TLS), modo passivo'))}</dd></div>
<div><dt>{t('Usuário e senha')}</dt><dd>{t('um usuário por equipamento ou por grupo, criado em <a href="/usuarios">Usuários</a>')}</dd></div>
</dl></section>""", sessao, '/'))
