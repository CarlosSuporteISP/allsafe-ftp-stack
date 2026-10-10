# SPDX-License-Identifier: Apache-2.0
"""Aba Servidor: os containers da stack, cada um com o que usa e o que foi alocado a ele, e os recursos do servidor
em que ela roda, com o histórico dos últimos minutos."""
import shutil
import time

import recursos
from config import ARQ_CERT, CFG, PASTA_DADOS
from estado import bloqueios, certificado, ftp_no_ar, pastas_distintas, uso_da_pasta, usuarios
from graficos import linha, numero, tira
from icones import icone
from pagina import ESTADOS, cabeca, como, e, pagina, tamanho, validade
from sessao import sessoes_por_admin

ATUALIZA = 10                           # segundos entre duas atualizações automáticas da tela
USO_ATENCAO, USO_RUIM = 80, 95          # % do processador em uso, na média do último minuto
LIVRE_ATENCAO, LIVRE_RUIM = 15, 5       # % de memória disponível e de disco livre
PARTE_ATENCAO, PARTE_RUIM = 80, 95      # % do que foi alocado ao container: a barra muda de cor
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


def nucleos(valor, unidade=True):
    """Núcleos de processador: até duas casas, sem zero sobrando."""
    texto = f'{valor:.2f}'.rstrip('0').rstrip('.').replace('.', ',')
    return f'{texto} {"núcleos" if valor >= 2 else "núcleo"}' if unidade else texto


def vezes(quantas):
    return 'nunca' if not quantas else '1\u00a0vez' if quantas == 1 else f'{numero(quantas)}\u00a0vezes'


def por_folga(livre):
    """Estado de um recurso pela folga que sobra, em %."""
    return 'ruim' if livre < LIVRE_RUIM else 'atencao' if livre < LIVRE_ATENCAO else 'bom'


def saude(estado, texto=''):
    """Selo do estado, ao lado do título: o desenho e a palavra, que é quem diz o estado."""
    desenho, rotulo = ESTADOS[estado]
    return f'<span class="saude {estado}">{icone(desenho)}{texto or rotulo}</span>'


def pares(itens):
    """Linhas de nome e valor, separadas por um fio: os números que o desenho não escreve."""
    linhas = ''.join(f'<div><dt>{nome}</dt><dd>{valor}</dd></div>' for nome, valor in itens if valor)
    return f'<dl class="pares">{linhas}</dl>' if linhas else ''


def medida(nome, parte, texto):
    """Uma medida contra o teto dela, numa linha: o nome, o uso e o teto por escrito, a parte em uso e a barra fina."""
    if parte is None:
        return (f'<div class="medida"><p><span>{nome}</span><span class="suave">{texto}</span><strong>—</strong></p>'
                f'{tira((), 100)}</div>')
    tom = 'ruim' if parte >= PARTE_RUIM else 'atencao' if parte >= PARTE_ATENCAO else 'info'
    return (f'<div class="medida"><p><span>{nome}</span><span class="suave">{texto}</span><strong>{parte:.0f}%</strong></p>'
            f'{tira(((tom, parte),), 100)}</div>')


def cartao(desenho, titulo, estado, medida_, nota, miolo, dados):
    """Cartão de um recurso do servidor: o estado, a medida de agora, o desenho e os números que ele não escreve."""
    return (f'<section class="cartao recurso"><h3>{icone(desenho)}{titulo}{estado}</h3>'
            f'<p class="numero">{medida_}</p><p class="suave">{nota}</p>{miolo}{pares(dados)}</section>')


def escala(usos):
    """Topo do desenho de uma medida em %: pouco acima do pico do período, para a linha ter forma mesmo com uso baixo."""
    return min(max(max(usos, default=0) * 1.25, 5), 100)


def periodo(series, teto, resumo):
    """O desenho do histórico e, embaixo, de quanto tempo ele é e o que ele mostra."""
    quantas = len(series[0][1])
    if quantas < 2:
        return '<p class="eixo">O histórico aparece alguns segundos depois de o painel iniciar.</p>'
    return f'{linha(series, teto)}<p class="eixo">últimos {duracao((quantas - 1) * recursos.INTERVALO)} · {resumo}</p>'


# ------------------------------------------------------------------ containers da stack

SERVICOS = {'ftp': ('servidor', 'Servidor FTP'), 'painel': ('painel', 'Painel'), 'nginx': ('escudo', 'Frente web')}


def container(nome, leitura, amostras, servidor_, no_ar, dados):
    """Cartão de um container: se está no ar, o que usa de processador, memória e processos contra o que foi
    alocado a ele, o processador nos últimos minutos e os avisos do limite."""
    desenho, titulo = SERVICOS[nome]
    nucleos_host, memoria_host = servidor_
    if not no_ar:
        selo = saude('ruim', 'Fora do ar')
    elif not leitura:
        selo = saude('bom', 'No ar')
    else:
        cheia = 100 * leitura['memoria'] / leitura['memoria_max'] if leitura['memoria_max'] else 0
        selo = (saude('ruim', 'Memória no limite') if cheia >= PARTE_RUIM else
                saude('atencao', 'Atenção') if cheia >= PARTE_ATENCAO or leitura['faltou'] else saude('bom', 'No ar'))
    if not leitura:
        return (f'<section class="cartao recurso"><h3>{icone(desenho)}{titulo}{selo}</h3>'
                f'<p class="suave"><code>{nome}</code> · sem leitura: ela aparece alguns segundos depois de o container iniciar</p>'
                f'{medida("Processador", None, "")}{medida("Memória", None, "")}{medida("Processos", None, "")}'
                f'{pares(dados)}</section>')
    # Sem limite, o teto é o do servidor inteiro.
    teto_nucleos = leitura['nucleos'] or nucleos_host
    teto_memoria = leitura['memoria_max'] or memoria_host
    sem_limite = ' do servidor (sem limite)'
    if leitura['cpu'] is None:
        processador_ = medida('Processador', None, f'de {nucleos(teto_nucleos)}{"" if leitura["nucleos"] else sem_limite} · lendo')
    else:
        processador_ = medida('Processador', 100 * leitura['cpu'] / teto_nucleos if teto_nucleos else None,
                              f'{nucleos(leitura["cpu"], False)} de {nucleos(teto_nucleos)}{"" if leitura["nucleos"] else sem_limite}')
    memoria_ = medida('Memória', 100 * leitura['memoria'] / teto_memoria if teto_memoria else None,
                      f'{e(tamanho(leitura["memoria"]))} de {e(tamanho(teto_memoria))}{"" if leitura["memoria_max"] else sem_limite}')
    if leitura['processos_max']:
        processos_ = medida('Processos', 100 * leitura['processos'] / leitura['processos_max'],
                            f'{numero(leitura["processos"])} de {numero(leitura["processos_max"])}')
    else:
        processos_ = medida('Processos', None, f'{numero(leitura["processos"])}, sem limite')
    usos = [100 * amostra[4][nome][0] / teto_nucleos for amostra in amostras
            if nome in amostra[4] and amostra[4][nome][0] is not None] if teto_nucleos else []
    historico = periodo((('info', usos),), escala(usos), f'processador, pico de {max(usos):.0f}%' if usos else '')
    return (f'<section class="cartao recurso"><h3>{icone(desenho)}{titulo}{selo}</h3>'
            f'<p class="suave"><code>{nome}</code> · no ar há {duracao(max(time.time() - leitura["inicio"], 0))}</p>'
            f'{processador_}{memoria_}{processos_}{historico}'
            + pares((('Limite de processador atingido', vezes(leitura['contido'])),
                     ('Encerrado por falta de memória', vezes(leitura['faltou']))) + tuple(dados)) + '</section>')


def somas(leituras):
    """O que os containers com leitura usam e o que foi alocado a eles: (núcleos em uso, núcleos alocados, memória em
    uso, memória alocada, quantos). Alocado é None quando algum deles está sem limite; uso do processador é None
    enquanto nenhum tem duas leituras."""
    lidas = [leitura for _, leitura in leituras if leitura]
    em_uso = [leitura['cpu'] for leitura in lidas if leitura['cpu'] is not None]
    return (sum(em_uso) if em_uso else None,
            sum(leitura['nucleos'] for leitura in lidas) if lidas and all(leitura['nucleos'] for leitura in lidas) else None,
            sum(leitura['memoria'] for leitura in lidas),
            sum(leitura['memoria_max'] for leitura in lidas) if lidas and all(leitura['memoria_max'] for leitura in lidas) else None,
            len(lidas))


def alocado(leituras, servidor_):
    """Uma linha com a soma do que foi alocado aos containers e do que eles usam agora, ao lado do que o servidor tem."""
    cpu, cota, em_uso, teto, quantos = somas(leituras)
    if not quantos:
        return ''
    nucleos_host, memoria_host = servidor_
    partes = []
    if cota and teto:
        partes.append(f'Alocado aos {quantos} containers: <strong>{nucleos(cota)}</strong> e '
                      f'<strong>{e(tamanho(teto))}</strong> de memória')
    partes.append((f'em uso agora: <strong>{nucleos(cpu)}</strong> e ' if cpu is not None else 'em uso agora: ')
                  + f'<strong>{e(tamanho(em_uso))}</strong>')
    if nucleos_host and memoria_host:
        partes.append(f'o servidor tem {nucleos(nucleos_host)} e {e(tamanho(memoria_host))}')
    return f'<p class="suave resumo">{" · ".join(partes)}.</p>'


def containers(amostras, servidor_):
    leituras = recursos.containers()
    estado_cert, texto_cert = validade(certificado(ARQ_CERT))
    presos = sum(len(lista) for lista in bloqueios().values())
    regra = (f'<a href="/usuarios">{numero(presos)} em vigor</a>' if presos else
             'nenhum' if CFG['bloqueio_tentativas'] else 'desligado na stack')
    extras = {'ftp': ((('Bloqueios de entrada', regra),), ftp_no_ar()),
              'painel': ((('<a href="/atividade">Sessões de administrador</a>', numero(sum(sessoes_por_admin().values()))),), True),
              # Este pedido chegou pelo nginx: se ele não estivesse no ar, a tela não abriria.
              'nginx': ((('<a href="/seguranca">Certificado</a>', f'<span class="{estado_cert}">{e(texto_cert.split(" (")[0])}</span>'),), True)}
    cartoes = ''
    for nome, leitura in leituras:
        dados, no_ar = extras[nome]
        cartoes += container(nome, leitura, amostras, servidor_, no_ar, dados)
    return (f'<section aria-labelledby="t-containers"><h2 class="secao" id="t-containers">Containers da stack</h2>'
            f'{alocado(leituras, servidor_)}<div class="recursos tres">{cartoes}</div></section>')


# ------------------------------------------------------------------ servidor (host)

def processador(amostras, lido):
    usos = [amostra[0] for amostra in amostras if amostra[0] is not None]
    if not lido:
        return cartao('processador', 'Processador', saude('neutro', 'sem leitura'), '—',
                      'O painel não conseguiu ler o uso do processador neste servidor.', '', ())
    media = sum(usos[-MINUTO:]) / len(usos[-MINUTO:]) if usos else None
    estado = 'neutro' if media is None else 'ruim' if media >= USO_RUIM else 'atencao' if media >= USO_ATENCAO else 'bom'
    cargas = recursos.carga()
    ligado = recursos.ligado_ha()
    if usos:
        medida_ = f'{usos[-1]:.0f}%'
        nota = f'{nucleos(usos[-1] * lido[2] / 100, False)} de {nucleos(lido[2])} em uso'
        miolo = tira((('info', usos[-1]),), 100) + periodo((('info', usos),), escala(usos), f'pico de {max(usos):.0f}%')
    else:
        medida_, nota, miolo = '—', f'{nucleos(lido[2])} · a primeira leitura sai em alguns segundos', ''
    return cartao('processador', 'Processador', saude(estado, '' if usos else 'lendo'), medida_, nota, miolo, (
        ('Média de 1 min', f'{media:.0f}%' if usos else ''),
        ('Carga média', ' · '.join(f'{valor:.2f}'.replace('.', ',') for valor in cargas) if cargas else ''),
        ('Ligado há', duracao(ligado) if ligado else ''),
        ('Modelo', e(recursos.modelo()))))


def memoria(amostras, lida):
    usos = [amostra[1] for amostra in amostras if amostra[1] is not None]
    if not lida:
        return cartao('memoria', 'Memória', saude('neutro', 'sem leitura'), '—',
                      'O painel não conseguiu ler a memória deste servidor.', '', ())
    usada = lida['total'] - lida['disponivel']
    parte = 100 * usada / lida['total']
    swap = (f'{e(tamanho(lida["swap_total"] - lida["swap_livre"]))} de {e(tamanho(lida["swap_total"]))}'
            if lida['swap_total'] else 'o servidor não tem')
    return cartao('memoria', 'Memória', saude(por_folga(100 - parte)), f'{parte:.0f}%',
                  f'{e(tamanho(usada))} de {e(tamanho(lida["total"]))} em uso',
                  tira((('info', parte),), 100)
                  + periodo((('info', usos),), escala(usos), f'pico de {max(usos):.0f}%' if usos else ''), (
                      ('Disponível', e(tamanho(lida['disponivel']))),
                      ('Em cache', e(tamanho(lida['cache']))),
                      ('Swap', swap)))


def disco():
    try:
        uso = shutil.disk_usage(PASTA_DADOS)
    except OSError:
        return cartao('disco', 'Disco', saude('neutro', 'sem leitura'), '—',
                      'O painel não conseguiu ler o disco da pasta dos dados.', '', ())
    # Como o df: o que o sistema de arquivos reserva para si não entra na conta do que dá para usar.
    total = uso.used + uso.free
    parte = 100 * uso.used / total if total else 0
    usos = [uso_da_pasta(pasta) for pasta in pastas_distintas(usuarios())]
    do_ftp = min(sum(item['bytes'] for item in usos), uso.used)
    incompleta = ' (soma incompleta: há pasta grande demais para ser lida inteira)' if any(item['parcial'] for item in usos) else ''
    return cartao('disco', 'Disco', saude(por_folga(100 - parte)), f'{parte:.0f}%',
                  f'{e(tamanho(uso.used))} de {e(tamanho(total))} em uso',
                  tira((('info', do_ftp), ('neutro', uso.used - do_ftp)), total), (
                      ('<span class="chave info"></span><a href="/arquivos">Pastas do FTP</a>', e(tamanho(do_ftp)) + incompleta),
                      ('<span class="chave neutro"></span>Outros dados', e(tamanho(uso.used - do_ftp))),
                      ('Livre', e(tamanho(uso.free)))))


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
    fluxo = '<span><span class="seta {}" aria-hidden="true">{}</span>{}</span>'
    return cartao('rede', 'Rede do FTP', saude('bom', 'lendo'),
                  f'<span class="fluxo">{fluxo.format("info", "↓", e(velocidade(recebendo)))}'
                  f'{fluxo.format("bom", "↑", e(velocidade(enviando)))}</span>',
                  'recebendo e enviando agora',
                  periodo((('info', recebe), ('bom', envia)), teto, f'topo em {e(velocidade(teto))}'), (
                      ('Pico recebendo', e(velocidade(pico_recebe))),
                      ('Pico enviando', e(velocidade(pico_envia))),
                      ('Total recebido', e(tamanho(lida['recebido']))),
                      ('Total enviado', e(tamanho(lida['enviado']))),
                      ('Erros e descartes', numero(lida['erros'])),
                      ('Sem tráfego há', duracao(parada) if parada > recursos.REDE_VALE else '')))


def resumo():
    """Faixa da Visão geral: o servidor e os containers da stack em quatro medidas, cada uma com o uso contra o que
    há ou o que foi alocado. O detalhe fica nesta aba."""
    amostras = recursos.historico()
    lido, lida = recursos.ler_processador(), recursos.ler_memoria()
    cpu, cota, em_uso, teto, quantos = somas(recursos.containers())
    uso = next((amostra[0] for amostra in reversed(amostras) if amostra[0] is not None), None)
    medidas = ''
    if lido and uso is not None:
        medidas += medida('Processador do servidor', uso, f'{nucleos(uso * lido[2] / 100, False)} de {nucleos(lido[2])}')
    else:
        medidas += medida('Processador do servidor', None, 'lendo' if lido else 'sem leitura')
    if lida:
        usada = lida['total'] - lida['disponivel']
        medidas += medida('Memória do servidor', 100 * usada / lida['total'], f'{e(tamanho(usada))} de {e(tamanho(lida["total"]))}')
    else:
        medidas += medida('Memória do servidor', None, 'sem leitura')
    if cpu is not None and cota:
        medidas += medida('Processador dos containers', 100 * cpu / cota, f'{nucleos(cpu, False)} de {nucleos(cota)}')
    else:
        medidas += medida('Processador dos containers', None, 'lendo' if quantos else 'sem leitura')
    if quantos and teto:
        medidas += medida('Memória dos containers', 100 * em_uso / teto, f'{e(tamanho(em_uso))} de {e(tamanho(teto))}')
    else:
        medidas += medida('Memória dos containers', None, e(tamanho(em_uso)) if quantos else 'sem leitura')
    return (f'<section class="cartao recurso"><div class="topo"><h2>{icone("pulso")}Servidor e containers</h2>'
            f'<p class="atalho"><a href="/servidor">ver o servidor</a></p></div><div class="medidas">{medidas}</div></section>')


def servidor(pedido, sessao, consulta, formulario, token):
    sozinha = consulta.get('auto') == '1'
    amostras = recursos.historico()
    lido, lida = recursos.ler_processador(), recursos.ler_memoria()
    servidor_ = (lido[2] if lido else 0, lida['total'] if lida else 0)
    acao = (f'<a class="botao" href="/servidor">{icone("pausa")}Parar a atualização</a>' if sozinha else
            f'<a class="botao" href="/servidor?auto=1">{icone("tocar")}Atualizar sozinha</a>')
    # A atualização automática parte do navegador, não de quem usa: o pedido dela não renova a sessão (atendimento.py).
    ritmo = (f'A tela se atualiza a cada {ATUALIZA} s. A atualização automática não conta como uso do painel: a sessão '
             f'encerra depois de {CFG["inatividade"] // 60} min sem ação sua.' if sozinha else
             'Para acompanhar sem recarregar a página, ligue <strong>Atualizar sozinha</strong>.')
    pedido.enviar(200, pagina('Servidor', f"""{cabeca('Servidor', 'Os containers desta stack e o servidor em que ela roda.', acao, quieta=sozinha)}
<div class="lado">
{containers(amostras, servidor_)}
<section aria-labelledby="t-servidor"><h2 class="secao" id="t-servidor">Recursos do servidor</h2>
<p class="suave resumo">A máquina inteira, e não só o que a stack usa dela.</p>
<div class="recursos quatro">
{processador(amostras, lido)}
{memoria(amostras, lida)}
{disco()}
{rede(amostras)}
</div></section>
</div>
<p class="suave rodape-aba">Lido às {time.strftime('%H:%M:%S')}. {ritmo}</p>
{como('Como estas medidas são lidas', f'''<p class="suave">Cada container lê o próprio uso e os limites que recebeu no <code>compose.yaml</code> (<code>*_CPU_LIMIT</code>, <code>*_MEMORY_LIMIT</code> e <code>*_PIDS_LIMIT</code> no <code>.env</code>), sem swap; a memória em uso não conta o cache de arquivo que o sistema solta quando precisa. O histórico guarda os últimos {duracao(recursos.AMOSTRAS * recursos.INTERVALO)}, com uma leitura a cada {recursos.INTERVALO} s, e recomeça quando o painel reinicia; cada desenho vai de zero até pouco acima do pico do período. Na rede, a linha cheia é o que chega e a tracejada, o que sai, e os totais contam desde que o serviço do FTP iniciou; o disco é o da pasta dos dados.</p>''')}""",
                              sessao, '/servidor'),
                  extras=(('Refresh', f'{ATUALIZA}; url=/servidor?auto=1'),) if sozinha else ())
