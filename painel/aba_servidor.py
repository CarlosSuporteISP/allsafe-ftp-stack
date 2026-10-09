# SPDX-License-Identifier: Apache-2.0
"""Aba Servidor: os serviços da stack e os recursos da máquina em que ela roda, com o histórico dos últimos minutos."""
import shutil
import time

import recursos
from config import ARQ_CERT, CFG, PASTA_DADOS
from estado import bloqueios, certificado, ftp_no_ar, pastas_distintas, uso_da_pasta, usuarios
from graficos import linha, numero, tira
from icones import icone
from pagina import ESTADOS, cabeca, e, marca, pagina, tamanho, validade

ATUALIZA = 10                           # segundos entre duas atualizações automáticas da tela
USO_ATENCAO, USO_RUIM = 80, 95          # % do processador em uso, na média do último minuto
LIVRE_ATENCAO, LIVRE_RUIM = 15, 5       # % de memória disponível e de disco livre
MINUTO = 60 // recursos.INTERVALO       # amostras de um minuto
TETO_REDE = 1250                        # bytes por segundo do topo do desenho da rede quando quase nada passa (10 kbit/s)


def decimal(valor):
    return f'{valor:.1f}'.replace('.', ',')


def velocidade(bytes_por_segundo):
    """Velocidade em bits por segundo, como se mede um enlace; o espaço antes da unidade é o não separável."""
    valor = bytes_por_segundo * 8
    for unidade in ('bit/s', 'kbit/s', 'Mbit/s', 'Gbit/s'):
        if valor < 1000 or unidade == 'Gbit/s':
            return f'{valor:.0f} {unidade}' if unidade == 'bit/s' else f'{decimal(valor)} {unidade}'
        valor /= 1000
    return ''


def duracao(segundos):
    segundos = int(segundos)
    dias, horas, minutos = segundos // 86400, segundos % 86400 // 3600, segundos % 3600 // 60
    if dias:
        return f'{dias} d {horas} h'
    if horas:
        return f'{horas} h {minutos} min'
    return f'{minutos} min' if minutos else f'{segundos} s'


def por_folga(livre):
    """Estado de um recurso pela folga que sobra, em %."""
    return 'ruim' if livre < LIVRE_RUIM else 'atencao' if livre < LIVRE_ATENCAO else 'bom'


def saude(estado, texto=''):
    """Estado do recurso, ao lado do título: o desenho e a palavra, que é quem diz o estado."""
    desenho, rotulo = ESTADOS[estado]
    return f'<span class="saude {estado}">{icone(desenho)}{texto or rotulo}</span>'


def cartao(desenho, titulo, estado, medida, nota, miolo, dados, atalho=''):
    """Cartão de um recurso: o estado, a medida de agora, o desenho e os números que o desenho não escreve."""
    itens = ''.join(f'<div><dt>{nome}</dt><dd>{valor}</dd></div>' for nome, valor in dados if valor)
    return (f'<section class="cartao recurso"><h2>{icone(desenho)}{titulo}{estado}</h2>'
            f'<p class="numero">{medida}</p><p class="suave">{nota}</p>{miolo}'
            + (f'<dl class="dados">{itens}</dl>' if itens else '') + atalho + '</section>')


def periodo(series, teto, escala, resumo):
    """O desenho do histórico com a linha do tempo embaixo: o começo, a escala e o agora."""
    if len(series[0][1]) < 2:
        return '<p class="suave">O histórico começa a aparecer alguns segundos depois de o painel iniciar.</p>'
    return (f'{linha(series, teto, recursos.AMOSTRAS)}<p class="eixo"><span>há '
            f'{duracao(recursos.AMOSTRAS * recursos.INTERVALO)}</span><span>{escala}</span><span>agora</span></p>'
            f'<p class="suave">{resumo}</p>')


def processador(amostras):
    lido, usos = recursos.ler_processador(), [amostra[0] for amostra in amostras if amostra[0] is not None]
    if not lido:
        return cartao('processador', 'Processador', saude('neutro', 'sem leitura'), '—',
                      'O painel não conseguiu ler o uso do processador neste servidor.', '', ())
    media = sum(usos[-MINUTO:]) / len(usos[-MINUTO:]) if usos else None
    estado = 'neutro' if media is None else 'ruim' if media >= USO_RUIM else 'atencao' if media >= USO_ATENCAO else 'bom'
    cargas = recursos.carga()
    ligado = recursos.ligado_ha()
    if usos:
        medida = f'{usos[-1]:.0f}%'
        nota = f'em uso agora · média do último minuto: {media:.0f}%'
        barra = tira((('info', usos[-1]),), 100)
        resumo = f'No período: média de {sum(usos) / len(usos):.0f}% e pico de {max(usos):.0f}%.'
    else:
        medida, nota, barra, resumo = '—', 'a primeira leitura sai em alguns segundos', '', ''
    return cartao('processador', 'Processador', saude(estado, '' if usos else 'lendo'), medida, nota,
                  barra + periodo((('info', usos),), 100, 'de 0 a 100%', resumo), (
                      ('Núcleos', numero(lido[2])),
                      ('Carga em 1, 5 e 15 min', ' · '.join(f'{valor:.2f}'.replace('.', ',') for valor in cargas) if cargas else ''),
                      ('Carga por núcleo', f'{cargas[0] / lido[2]:.2f}'.replace('.', ',') if cargas else ''),
                      ('Servidor ligado há', duracao(ligado) if ligado else ''),
                      ('Modelo', e(recursos.modelo()))))


def memoria(amostras):
    lida, usos = recursos.ler_memoria(), [amostra[1] for amostra in amostras if amostra[1] is not None]
    if not lida:
        return cartao('memoria', 'Memória', saude('neutro', 'sem leitura'), '—',
                      'O painel não conseguiu ler a memória deste servidor.', '', ())
    usada = lida['total'] - lida['disponivel']
    parte = 100 * usada / lida['total']
    swap = (f'{e(tamanho(lida["swap_total"] - lida["swap_livre"]))} de {e(tamanho(lida["swap_total"]))} em uso'
            if lida['swap_total'] else 'o servidor não tem swap')
    resumo = f'No período: média de {sum(usos) / len(usos):.0f}% e pico de {max(usos):.0f}%.' if usos else ''
    return cartao('memoria', 'Memória', saude(por_folga(100 - parte)), f'{parte:.0f}%',
                  f'em uso: {e(tamanho(usada))} de {e(tamanho(lida["total"]))}',
                  tira((('info', parte),), 100) + periodo((('info', usos),), 100, 'de 0 a 100%', resumo), (
                      ('Disponível', e(tamanho(lida['disponivel']))),
                      ('Em cache', e(tamanho(lida['cache']))),
                      ('Swap', swap)))


def disco():
    try:
        uso = shutil.disk_usage(PASTA_DADOS)
    except OSError:
        return cartao('disco', 'Disco dos backups', saude('neutro', 'sem leitura'), '—',
                      'O painel não conseguiu ler o disco da pasta dos dados.', '', ())
    # Como o df: o que o sistema de arquivos reserva para si não entra na conta do que dá para usar.
    total = uso.used + uso.free
    parte = 100 * uso.used / total if total else 0
    usos = [uso_da_pasta(pasta) for pasta in pastas_distintas(usuarios())]
    do_ftp = min(sum(item['bytes'] for item in usos), uso.used)
    incompleta = ' A soma das pastas do FTP está incompleta: há pasta grande demais para ser lida inteira.' if any(
        item['parcial'] for item in usos) else ''
    return cartao('disco', 'Disco dos backups', saude(por_folga(100 - parte)), f'{parte:.0f}%',
                  f'em uso: {e(tamanho(uso.used))} de {e(tamanho(total))}',
                  tira((('info', do_ftp), ('neutro', uso.used - do_ftp)), total)
                  + f'<ul class="chaves"><li><span class="chave info"></span><strong>{e(tamanho(do_ftp))}</strong> nas pastas do FTP</li>'
                  f'<li><span class="chave neutro"></span><strong>{e(tamanho(uso.used - do_ftp))}</strong> de outros dados do mesmo disco</li>'
                  f'<li><strong>{e(tamanho(uso.free))}</strong> livres</li></ul>'
                  f'<p class="suave">É o disco em que fica a pasta dos dados do FTP, que pode ser dividido com o resto do servidor.{incompleta}</p>',
                  (), '<p class="atalho"><a href="/arquivos">ver as pastas</a></p>')


def rede(amostras):
    lida = recursos.ler_rede()
    if not lida:
        return cartao('rede', 'Rede do FTP', saude('neutro', 'sem leitura'), '—',
                      'O serviço do FTP ainda não publicou a leitura da rede dele. Ela aparece alguns segundos depois de ele iniciar.',
                      '', ())
    recebendo, enviando = recursos.velocidade(lida)
    recebe, envia = [amostra[2] for amostra in amostras], [amostra[3] for amostra in amostras]
    # A leitura de agora entra no pico: ela pode ser mais nova que a última amostra do histórico.
    pico_recebe, pico_envia = max(recebe + [recebendo]), max(envia + [enviando])
    teto = max(pico_recebe, pico_envia, TETO_REDE)
    parada = time.time() - lida['quando']
    resumo = (f'Linha cheia: recebendo, com pico de {e(velocidade(pico_recebe))}. Linha tracejada: enviando, com pico de '
              f'{e(velocidade(pico_envia))}.') if recebe else ''
    return cartao('rede', 'Rede do FTP', saude('bom', 'lendo'), e(velocidade(recebendo)),
                  f'recebendo agora · enviando {e(velocidade(enviando))}',
                  periodo((('info', recebe), ('neutro', envia)), teto, f'topo do desenho: {e(velocidade(teto))}', resumo), (
                      ('Recebido desde que o FTP iniciou', e(tamanho(lida['recebido']))),
                      ('Enviado', e(tamanho(lida['enviado']))),
                      ('Erros e descartes', numero(lida['erros'])),
                      ('Sem tráfego há', duracao(parada) if parada > recursos.REDE_VALE else '')))


def servicos():
    """Os serviços da stack, cada um com o que o painel consegue conferir dele."""
    no_ar = ftp_no_ar()
    estado_cert, texto_cert = validade(certificado(ARQ_CERT))
    em_uso, limite = recursos.memoria_do_painel()
    memoria_painel = ''
    if em_uso is not None:
        memoria_painel = f' · {e(tamanho(em_uso))}' + (f' de {e(tamanho(limite))}' if limite else '') + ' de memória'
    presos = sum(len(lista) for lista in bloqueios().values())
    regra = ('por senha errada no FTP, por usuário e endereço' if CFG['bloqueio_tentativas'] else
             'desligado na stack (<code>FTP_BLOQUEIO_TENTATIVAS=0</code>): vale o limite de cada usuário')
    return f'''<section class="situacao" aria-label="Serviços da stack">
<div><h2>{icone('servidor')}Servidor FTP</h2><p class="numero menor">{marca('bom' if no_ar else 'ruim')}{'No ar' if no_ar else 'Fora do ar'}</p>
<p class="suave">{'aceita conexão na porta de controle' if no_ar else 'não respondeu na porta de controle'}</p>
<p class="atalho"><a href="/">ver a visão geral</a></p></div>
<div><h2>{icone('painel')}Painel</h2><p class="numero menor">{marca('bom')}No ar</p>
<p class="suave">há {duracao(time.time() - recursos.INICIO)}{memoria_painel}</p>
<p class="atalho"><a href="/atividade">ver a atividade</a></p></div>
<div><h2>{icone('escudo')}Frente web (nginx)</h2><p class="numero menor">{marca(estado_cert)}No ar</p>
<p class="suave">este pedido chegou por ela · certificado {e(texto_cert)}</p>
<p class="atalho"><a href="/seguranca">conferir a segurança</a></p></div>
<div><h2>{icone('bloqueio')}Bloqueios de entrada</h2><p class="numero menor">{marca('atencao' if presos else 'bom')}{f'{numero(presos)} em vigor' if presos else 'Nenhum'}</p>
<p class="suave">{regra}</p>
<p class="atalho"><a href="/usuarios">ver os usuários</a></p></div>
</section>'''


def servidor(pedido, sessao, consulta, formulario, token):
    sozinha = consulta.get('auto') == '1'
    amostras = recursos.historico()
    acao = (f'<a class="botao" href="/servidor">{icone("pausa")}Parar a atualização</a>' if sozinha else
            f'<a class="botao" href="/servidor?auto=1">{icone("tocar")}Atualizar sozinha</a>')
    # A atualização automática parte do navegador, não de quem usa: o pedido dela não renova a sessão (atendimento.py).
    ritmo = (f'A tela se atualiza a cada {ATUALIZA} s. A atualização automática não conta como uso do painel: a sessão '
             f'encerra depois de {CFG["inatividade"] // 60} min sem ação sua.' if sozinha else
             'Para acompanhar sem recarregar a página, ligue <strong>Atualizar sozinha</strong>.')
    pedido.enviar(200, pagina('Servidor', f'''{cabeca('Servidor', 'Os serviços da stack e os recursos da máquina em que ela roda.', acao)}
{servicos()}
<div class="recursos">
{processador(amostras)}
{memoria(amostras)}
{disco()}
{rede(amostras)}
</div>
<p class="suave">Lido às {time.strftime('%H:%M:%S')}. {ritmo} Processador, memória e disco são os do servidor inteiro, e não só os da stack. O histórico guarda os últimos {duracao(recursos.AMOSTRAS * recursos.INTERVALO)}, com uma leitura a cada {recursos.INTERVALO} s, e recomeça quando o painel reinicia.</p>''',
                              sessao, '/servidor'),
                  extras=(('Refresh', f'{ATUALIZA}; url=/servidor?auto=1'),) if sozinha else ())
