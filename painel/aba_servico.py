# SPDX-License-Identifier: Apache-2.0
"""Aba Serviço: o que o serviço guarda e o que ele manda para fora. Os usuários, os arquivos e o tamanho de cada pasta;
e, por destino gravado, o que já foi enviado, o que não foi e o que está na fila, com os nomes dos arquivos.

A tela só lê: o cadastro, as pastas dos dados e o andamento que cada destino grava. Não chama destino nenhum, não tem
formulário e não mostra nada do acesso: nem endereço, nem chave, nem conversa, nem o registro de erro do rclone."""
import shutil
import time
import urllib.parse

import aba_destinos
import copia
import destinos
from aba_usuarios import NOME_DO_PERFIL, PERFIS_FTP
from config import CFG, PASTA_DADOS
from estado import pastas_distintas, perfis, uso_da_pasta, usuarios
from graficos import numero
from icones import icone
from idioma import t, tn
from pagina import cabeca, como, e, pagina, quando, tamanho, vazio


PRAZO_DO_RESUMO = 1     # segundos da medida das filas na Visão geral; a pasta que não coube fica sem medida


def celula(desenho, titulo, medida, nota, endereco='', atalho=''):
    """Uma medida da faixa: o número, o que ele conta e, quando há, o link de quem o detalha."""
    link = f'<p class="atalho"><a href="{endereco}">{atalho}</a></p>' if endereco else ''
    return f'<div><h2>{icone(desenho)}{titulo}</h2><p class="numero">{medida}</p><p class="suave">{nota}</p>{link}</div>'


def arquivos_de(quantos):
    return tn(quantos, '{quantos} arquivo', '{quantos} arquivos', quantos=numero(quantos))


def ao_menos(quantos, parcial):
    """A quantidade de uma conta que pode ter parado antes do fim."""
    return t('pelo menos {quantos}', quantos=numero(quantos)) if parcial else numero(quantos)


def guardado(nomes, pastas, usos):
    """Faixa do que o serviço guarda: os usuários por perfil, os arquivos, o espaço e as pastas."""
    papeis = perfis()
    por_perfil = [(sum(1 for nome in nomes if papeis.get(nome, 'completo') == chave), chave) for chave in PERFIS_FTP]
    perfis_ = ' · '.join(f'{quantos} {t(NOME_DO_PERFIL[chave])}' for quantos, chave in por_perfil if quantos)
    mais = ' ' + t('ou mais') if any(uso['parcial'] for uso in usos) else ''
    try:
        livre = t('{espaco} livres no disco', espaco=tamanho(shutil.disk_usage(PASTA_DADOS).free))
    except OSError:
        livre = ''
    maior = max(zip(usos, pastas), key=lambda par: par[0]['bytes'], default=None)
    nota = (t('a maior tem {tamanho}', tamanho=e(tamanho(maior[0]['bytes']))) if maior else t('nenhuma pasta de usuário ainda'))
    return f"""<div class="situacao">
{celula('usuarios', t('Usuários'), len(nomes), perfis_ or t('nenhuma conta cadastrada'), '/usuarios', t('ver os usuários'))}
{celula('envio', t('Arquivos'), numero(sum(uso['arquivos'] for uso in usos)) + mais, t('nas pastas dos usuários'),
        '/arquivos', t('ver os arquivos'))}
{celula('disco', t('Espaço usado'), e(tamanho(sum(uso['bytes'] for uso in usos))) + mais, e(livre), '/arquivos', t('ver as pastas'))}
{celula('pasta', t('Pastas'), len(pastas), nota, '#t-pastas', t('ver o tamanho de cada uma'))}
</div>"""


def ler_destinos(prazo=destinos.FILAS_PRAZO):
    """O que os destinos gravados fizeram e o que falta: destino ➜ situação, destino ➜ fila, e as somas da faixa.
    Na soma da fila entram só os destinos ligados: o desligado não envia o que chegou."""
    vistos = {destino: destinos.situacao(destino) for destino in destinos.todos()}
    filas = destinos.filas(vistos, prazo)
    soma = {'gravados': len(vistos), 'ligados': 0, 'arquivos': 0, 'bytes': 0, 'recusados': 0,
            'fila': 0, 'fila_bytes': 0, 'parcial': False, 'sem_medida': 0}
    for destino, visto in vistos.items():
        soma['arquivos'] += aba_destinos.inteiro(visto['total'], 'arquivos')
        soma['bytes'] += aba_destinos.inteiro(visto['total'], 'bytes')
        soma['recusados'] += aba_destinos.inteiro(visto['total'], 'recusados')
        if not (visto['conf']['ligado'] and visto['segredos']):
            continue
        soma['ligados'] += 1
        fila = filas[destino]
        if fila is None:
            soma['sem_medida'] += 1
            continue
        soma['fila'] += fila['arquivos']
        soma['fila_bytes'] += fila['bytes']
        soma['parcial'] = soma['parcial'] or fila['parcial']
    return vistos, filas, soma


def nota_da_fila(soma):
    if soma['sem_medida']:
        return tn(soma['sem_medida'], '{n} destino ficou sem medida agora', '{n} destinos ficaram sem medida agora')
    return e(tamanho(soma['fila_bytes'])) + ' · ' + t('nos destinos ligados')


def enviado(soma):
    """Faixa dos destinos: quantos estão ligados, o que já saiu, o que espera e o que ficou de fora."""
    return f"""<div class="situacao">
{celula('nuvem', t('Destinos'), t('{ligados} de {gravados}', ligados=soma['ligados'], gravados=soma['gravados']),
        t('ligados, com os segredos no lugar'), '/destinos', t('ver os destinos'))}
{celula('envio', t('Enviados'), numero(soma['arquivos']), e(tamanho(soma['bytes'])) + ' · ' + t('somados os destinos'))}
{celula('relogio', t('Na fila'), ao_menos(soma['fila'], soma['parcial']), nota_da_fila(soma))}
{celula('alerta', t('Não enviados'), numero(soma['recusados']), t('recusados pelo destino ou fora do que ele aceita'))}
</div>"""


def lista(titulo, nota, itens):
    """Uma lista de arquivos de um destino, recolhida: cada item é (caminho, tamanho, instante, motivo ou '')."""
    if not itens:
        return ''
    linhas = ''.join(f'<li><code>{e(caminho)}</code><span class="suave">{e(tamanho(octetos))} · {e(quando(instante))}'
                     f'{" · " + e(aba_destinos.explicar(motivo)) if motivo else ""}</span></li>'
                     for caminho, octetos, instante, motivo in itens)
    return como(titulo, (f'<p class="suave">{nota}</p>' if nota else '') + f'<ul class="recentes">{linhas}</ul>')


def ficha(destino, visto, fila):
    """Cartão de um destino: a situação, a fila, o que não foi e as três listas de arquivos."""
    conf, historico = visto['conf'], visto['historico']
    falha = ''
    if visto['ultima'].get('motivo'):
        falha = ('<p class="aviso">' + t('A última passada parou antes do fim: {motivo}. A seguinte recomeça do mesmo arquivo.',
                                         motivo=e(aba_destinos.explicar(str(visto['ultima']['motivo'])))) + '</p>')
    if fila is None:
        na_fila, proximos = t('sem medida agora'), ''
    else:
        parado = '' if conf['ligado'] and visto['segredos'] else ' · ' + t('parada: o destino não está enviando')
        na_fila = (tn(fila['arquivos'], '{quantos} arquivo', '{quantos} arquivos', quantos=ao_menos(fila['arquivos'], fila['parcial']))
                   + f' · {e(tamanho(fila["bytes"]))}{parado}')
        resto = (t('Os {mostrados} que chegaram primeiro, de {todos}: são os que saem primeiro.', mostrados=len(fila['primeiros']),
                   todos=ao_menos(fila['arquivos'], fila['parcial'])) if fila['arquivos'] > len(fila['primeiros']) else '')
        proximos = lista(t('Próximos da fila'), resto,
                         [(caminho, octetos, chegada // 10**9, '') for chegada, caminho, octetos in fila['primeiros']])
    recusados = aba_destinos.inteiro(visto['total'], 'recusados')
    enviados = lista(t('Últimos enviados'), '', [(caminho, octetos, instante, '')
                                                 for instante, caminho, octetos in reversed(historico['enviados'])])
    ficaram = lista(t('Últimos não enviados'), '', [(caminho, octetos, instante, motivo)
                                                    for instante, caminho, octetos, motivo in reversed(historico['recusados'])])
    return f"""<section class="cartao"><h2>{icone(aba_destinos.DESENHOS[destinos.tipo(destino)])}{e(aba_destinos.rotulo(destino, conf))} {aba_destinos.etiqueta(visto)}</h2>{falha}
<dl class="dados"><div><dt>{t('Pasta enviada')}</dt><dd>{aba_destinos.pasta_enviada(conf)}</dd></div>
<div><dt>{t('Na fila')}</dt><dd>{na_fila}</dd></div>
<div><dt>{t('Não enviados')}</dt><dd>{arquivos_de(recusados)}</dd></div>
{aba_destinos.passadas(visto)}</dl>
{proximos}{enviados}{ficaram}</section>"""


def ficha_da_copia():
    """Cartão da cópia do sistema, quando ela está configurada: a última e a que está em curso."""
    visto = copia.situacao()
    conf, dele, ultima, andamento = visto['conf'], visto['destino'], visto['ultima'], visto['andamento']
    if not (conf and dele):
        return ''
    inteiro = aba_destinos.inteiro
    marca = (f'<span class="etiqueta">{t("em andamento")}</span>' if andamento else
             f'<span class="etiqueta atencao">{t("faltam os segredos")}</span>' if not visto['segredos'] else
             f'<span class="etiqueta">{t("rotina ligada") if conf["dias"] else t("só pelo botão")}</span>')
    falha = ''
    if visto['interrompida']:
        falha = '<p class="aviso">' + t('A cópia anterior foi interrompida pelo reinício do painel: faça outra.') + '</p>'
    elif ultima.get('motivo'):
        falha = ('<p class="aviso">' + t('A última cópia, de {quando}, não foi concluída: {motivo}.',
                                         quando=e(quando(inteiro(ultima, 'quando'))),
                                         motivo=e(aba_destinos.explicar(str(ultima['motivo'])))) + '</p>')
    if inteiro(ultima, 'quando') and not ultima.get('motivo'):
        feita = (f'{e(quando(inteiro(ultima, "fim")))} · {e(tamanho(inteiro(ultima, "bytes")))} · '
                 + tn(inteiro(ultima, 'arquivos'), '{n} arquivo', '{n} arquivos'))
    else:
        feita = t('nenhuma ainda')
    agora = ''
    if andamento:
        agora = (f'<div class="larga"><dt>{t("Agora")}</dt><dd>{t("cópia em andamento")}: {e(tamanho(inteiro(andamento, "bytes")))} · '
                 + tn(inteiro(andamento, 'partes'), '{n} parte enviada', '{n} partes enviadas') + '</dd></div>')
    return f"""<section class="cartao"><h2>{icone('servidor')}{t('Cópia do sistema')} {marca}</h2>{falha}
<dl class="dados"><div><dt>{t('Destino')}</dt><dd>{e(aba_destinos.rotulo(conf['destino'], dele))}</dd></div>
<div class="larga"><dt>{t('Última cópia')}</dt><dd>{feita}</dd></div>{agora}</dl></section>"""


def dos_destinos():
    """A parte dos destinos: a faixa das somas e um cartão por destino gravado, mais o da cópia do sistema."""
    vistos, filas, soma = ler_destinos()
    if vistos:
        fichas = '\n'.join(ficha(destino, visto, filas[destino]) for destino, visto in vistos.items())
        miolo = f'{enviado(soma)}\n<div class="fichas">\n{fichas}\n{ficha_da_copia()}</div>'
    else:
        miolo = (f'<section class="cartao"><h2>{icone("nuvem")}{t("Nenhum destino gravado")}</h2><p class="suave">'
                 + t('O envio para fora do servidor começa em <a href="/destinos">Destinos</a>, com um armazenamento S3, um '
                     'remoto do rclone ou um bot do Telegram.') + '</p></section>')
    return f"""<section aria-labelledby="t-envio"><h2 class="secao" id="t-envio">{t('Envio aos destinos')}</h2>
<p class="suave resumo">{t('O que saiu, o que espera e o que ficou de fora, em cada destino gravado.')}</p>
{miolo}</section>"""


def das_pastas(nomes, pastas, usos):
    """A tabela das pastas dos usuários, da maior para a menor."""
    linhas = ''
    for pasta, uso in sorted(zip(pastas, usos), key=lambda par: par[1]['bytes'], reverse=True):
        contas = sum(1 for dela in nomes.values() if dela == pasta or dela.startswith(pasta + '/'))
        mais = ' ' + t('ou mais') if uso['parcial'] else ''
        linhas += (f'<tr><td class="pasta" data-rotulo="{t("Pasta")}"><a href="/arquivos?pasta={urllib.parse.quote(pasta, safe="/")}">'
                   f'<code>{e(pasta)}</code></a></td>'
                   f'<td data-rotulo="{t("Usuários")}">{contas}</td>'
                   f'<td data-rotulo="{t("Arquivos")}">{numero(uso["arquivos"])}{mais}</td>'
                   f'<td data-rotulo="{t("Uso")}">{e(tamanho(uso["bytes"]))}{mais}</td>'
                   f'<td class="quando" data-rotulo="{t("Último envio")}">{e(quando(uso["ultimo"]))}</td></tr>')
    nenhuma = vazio(5, 'pasta', t('Nenhuma pasta de usuário ainda.'), t('Ela aparece aqui quando o primeiro usuário for criado.'))
    return f"""<section aria-labelledby="t-pastas"><h2 class="secao" id="t-pastas">{t('Tamanho das pastas')}</h2>
<p class="suave resumo">{t('A pasta de cada usuário, da maior para a menor. A que fica dentro de outra entra na conta da de fora.')}</p>
<section class="cartao lista"><div class="rolagem"><table class="blocos">
<thead><tr><th>{t('Pasta')}</th><th>{t('Usuários')}</th><th>{t('Arquivos')}</th><th>{t('Uso')}</th><th>{t('Último envio')}</th></tr></thead>
<tbody>{linhas or nenhuma}</tbody></table></div></section></section>"""


def resumo():
    """Faixa da Visão geral: os destinos em quatro medidas. O detalhe fica nesta aba. Vazia quando o envio a destinos
    está desligado na instalação ou não há destino gravado."""
    if not CFG['destinos']:
        return ''
    vistos, _, soma = ler_destinos(PRAZO_DO_RESUMO)
    if not vistos:
        return ''
    medidas = ''.join(f'<div class="medida"><p><span>{nome}</span><span class="suave">{valor}</span></p></div>' for nome, valor in (
        (t('Destinos ligados'), t('{ligados} de {gravados}', ligados=soma['ligados'], gravados=soma['gravados'])),
        (t('Enviados'), f'{arquivos_de(soma["arquivos"])} · {e(tamanho(soma["bytes"]))}'),
        (t('Na fila'), t('sem medida agora') if soma['sem_medida'] else
         tn(soma['fila'], '{quantos} arquivo', '{quantos} arquivos', quantos=ao_menos(soma['fila'], soma['parcial']))),
        (t('Não enviados'), arquivos_de(soma['recusados']))))
    return (f'<section class="cartao recurso"><div class="topo"><h2>{icone("medidor")}{t("Envio aos destinos")}</h2>'
            f'<p class="atalho"><a href="/servico">{t("ver o serviço")}</a></p></div><div class="medidas">{medidas}</div></section>')


def servico(pedido, sessao, consulta, formulario, token):
    nomes = usuarios()
    pastas = pastas_distintas(nomes)
    usos = [uso_da_pasta(pasta) for pasta in pastas]
    incompleta = ('<p class="suave resumo">' + t('A contagem está incompleta: há pasta grande demais para ser lida inteira.') + '</p>'
                  if any(uso['parcial'] for uso in usos) else '')
    leitura = t('Os arquivos e o espaço são contados nas pastas dos usuários e valem por um minuto. <strong>Na fila</strong> é o '
                'que está na pasta do destino e chegou depois do último arquivo que ele tratou: o que ainda está chegando conta '
                'também, e a fila do destino desligado fica parada até ele ser ligado. A medida de cada pasta vale por {segundos} s; em pasta '
                'grande demais ela para antes do fim e a tela escreve <strong>pelo menos</strong>. <strong>Não enviados</strong> '
                'são os arquivos que o destino recusou depois de {tropecos} passadas e os que ficaram fora do que ele aceita: acima do '
                'limite, vazios ou com nome que o destino não guarda. A fila segue sem eles. As listas guardam os últimos '
                '{guardados} de cada destino, e os números contam desde que o destino foi ligado. O arquivo enviado um a um, pelos '
                'botões de destino da aba Arquivos, não entra nelas. Esta tela só lê: nada é enviado, repetido nem apagado '
                'por ela.', segundos=destinos.FILA_VALE, tropecos=destinos.TROPECOS, guardados=destinos.HISTORICO)
    pedido.enviar(200, pagina(t('Serviço'), f"""{cabeca('Serviço', t('O que o serviço guarda e o que ele manda para os destinos.'))}
<section aria-labelledby="t-guardado"><h2 class="secao" id="t-guardado">{t('O que o serviço guarda')}</h2>
<p class="suave resumo">{t('As contas do FTP e o que está nas pastas delas agora.')}</p>
{guardado(nomes, pastas, usos)}{incompleta}</section>
{dos_destinos() if CFG['destinos'] else ''}
{das_pastas(nomes, pastas, usos)}
<p class="suave rodape-aba">{t('Lido às {hora}.', hora=time.strftime('%H:%M:%S'))}</p>
{como(t('Como estas medidas são lidas'), f'<p class="suave">{leitura}</p>')}""", sessao, '/servico'))
