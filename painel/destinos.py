# SPDX-License-Identifier: Apache-2.0
"""Destinos de fora: o painel envia sozinho os arquivos de uma pasta para um armazenamento S3 e para um bot do Telegram.

Cada destino tem uma ligação só, gravada pelo administrador na aba Destinos: a configuração fica em
/painel/destinos/<destino>.conf e os segredos, um por arquivo, em /segredos (SECRETS_DIR/destinos, no host). Uma linha
de execução do próprio painel confere a cada minuto e faz a passada do destino que está na hora; a mesma passada sai
pelo terminal (servidor.py --destinos enviar <destino>).

A passada percorre a pasta pelo descritor dela, sem seguir link simbólico, como a aba Arquivos. Só sai arquivo comum:
ficam de fora o link, tudo o que tem o nome começado por ponto, o que está em outro sistema de arquivos e o nome que
não é UTF-8. O arquivo é enviado depois de ficar ASSENTAR segundos sem mudar, para o que ainda está chegando não sair
pela metade. A ordem é a da chegada no servidor (a data de mudança do arquivo, que o cliente FTP não escolhe), e o
andamento é uma marca só: o último arquivo entregue. Uma falha do destino encerra a passada, e a seguinte recomeça do
mesmo arquivo; nada é pulado nem enviado duas vezes.

O bot do Telegram não espera o arquivo assentar quando sabe que ele chegou inteiro: o servidor FTP anuncia cada envio
concluído e o envio pelo painel anuncia o dele (chegadas.py). O anúncio faz a passada do bot na hora e dispensa a
espera daquele arquivo; a fila continua em ordem, e para no primeiro arquivo que ainda pode estar chegando. O S3
segue pela espera, porque no modo `mover` ele apaga o que enviou.

O administrador também envia um arquivo só, pela aba Arquivos (enviar_arquivo): esse envio não mexe na marca das
passadas e nunca apaga o arquivo.

No S3, o modo `copiar` deixa o arquivo no servidor e o `mover` apaga o arquivo depois que o destino confirma a
gravação, e só se ele não mudou desde o envio. O Telegram só envia o que chegar depois de ligado. Com os dois na
mesma pasta, o Telegram passa primeiro e o `mover` só apaga o que o bot já entregou.
"""
import contextlib
import fcntl
import heapq
import itertools
import json
import os
import re
import secrets
import threading
import time

import chegadas
import idioma
import s3
import saida
import telegram
from aba_arquivos import ABRIR, Recusado, abrir, partes
from auditoria import auditar, limpo
from config import APAGAR_NIVEIS, CFG, ENDERECO_HTTPS, PASTA, PASTA_DESTINOS, PASTA_SEGREDOS
from estado import limpar_cache
from idioma import t
from pagina import quando, tamanho as com_unidade

NOMES = ('telegram', 's3')    # a ordem da passada: o bot entrega antes de o S3 poder apagar
SEGREDOS = {'s3': ('s3-chave-de-acesso.txt', 's3-chave-secreta.txt'),
            'telegram': ('telegram-token.txt', 'telegram-conversa.txt')}
FORMATO = {'s3': (r'[\x21-\x7e]{3,128}', r'[\x21-\x7e]{8,256}'),
           'telegram': (telegram.TOKEN.pattern, telegram.CONVERSA.pattern)}
ARQ_TRAVA = os.path.join(PASTA_DESTINOS, '.trava')
ASSENTAR = 120               # segundos sem mudar para o arquivo entrar na passada
LOTE = 20000                 # arquivos escolhidos por vez, dos mais antigos para os mais novos
INTERVALO = (5, 1440)        # minutos entre as passadas de um destino
PAUSA_TELEGRAM = 3           # segundos entre um envio e o seguinte: a API limita as mensagens por minuto de um grupo
ADIADOS_MAX = 20000          # arquivos já gravados no S3 à espera do bot para serem apagados
SEGREDO_MAX = 512            # bytes lidos de um arquivo de segredo
PRAZO_TESTE = 8              # segundos por operação de rede do teste pedido pela tela...
TESTE_MAX = 25               # ...e o teto do teste inteiro: abaixo do tempo que o nginx espera pelo painel
GRAVAR_A_CADA = 10           # segundos entre uma gravação do andamento e a seguinte, dentro de uma passada
TROPECOS = 3                 # passadas em que o destino recusa o mesmo arquivo até ele ficar para trás
COLHER = 2                   # segundos entre uma colheita dos anúncios de chegada e a seguinte
CALMA = 3                    # segundos entre o anúncio e o envio: o cliente FTP que acerta a data do arquivo logo
                             # depois de enviar já acertou, e o arquivo não sai duas vezes
CONFERIR = 60                # segundos entre uma conferência do que está na hora e a seguinte
AVULSO_MAX = 20              # segundos que a tela espera pelo envio de um arquivo pedido por ela; depois ele segue sozinho

ACORDAR = threading.Event()
PEDIDOS = set()              # destinos com passada pedida pelo botão Enviar agora
TRAVA_PEDIDOS = threading.Lock()
TRAVA_TESTE = threading.Lock()
TRAVA_AVULSO = threading.Lock()   # um envio de arquivo pedido pela tela por vez
ANDAMENTO = {}               # destino ➜ o que a passada em curso já fez, para a tela


def arquivo(destino, tipo):
    return os.path.join(PASTA_DESTINOS, f'{destino}.{tipo}')


# ------------------------------------------------------------ segredos

def ler_segredo(nome):
    """O conteúdo de um arquivo de segredo, ou '' quando não existe, está vazio ou não é um arquivo comum."""
    try:
        descritor = os.open(os.path.join(PASTA_SEGREDOS, nome), os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK)
    except OSError:
        return ''
    try:
        return os.read(descritor, SEGREDO_MAX + 1).decode('ascii', 'replace').strip()
    except OSError:
        return ''
    finally:
        os.close(descritor)


def segredos_de(destino):
    """Os dois segredos do destino, ou None quando falta algum ou algum não tem o formato dele."""
    valores = tuple(ler_segredo(nome) for nome in SEGREDOS[destino])
    return valores if all(re.fullmatch(regra, valor) for regra, valor in zip(FORMATO[destino], valores)) else None


def gravar_texto(caminho, texto, dono=None):
    """Grava em arquivo ao lado e troca de uma vez, com modo 0600. `dono` é (uid, gid) para o arquivo do host."""
    provisorio = caminho + '.novo'
    descritor = os.open(provisorio, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600)
    with os.fdopen(descritor, 'w', encoding='utf-8') as arq:
        arq.write(texto)
        arq.flush()
        os.fchmod(arq.fileno(), 0o600)
        if dono:
            os.fchown(arq.fileno(), *dono)
        os.fsync(arq.fileno())
    os.replace(provisorio, caminho)


def gravar_segredo(nome, valor):
    # A pasta é do host: o arquivo fica com o dono dela, para quem instalou poder guardar e apagar os segredos.
    pasta = os.stat(PASTA_SEGREDOS)
    gravar_texto(os.path.join(PASTA_SEGREDOS, nome), valor + '\n', (pasta.st_uid, pasta.st_gid))


def apagar(caminho):
    with contextlib.suppress(FileNotFoundError):
        os.unlink(caminho)


# ------------------------------------------------------------ configuração

def pasta_existe(pasta):
    try:
        os.close(abrir(partes(pasta), True))
    except Recusado:
        return False
    return True


def defeito(destino, conf):
    """O nome do primeiro campo que não serve, ou '' quando a configuração está inteira."""
    try:
        if conf['ligado'] not in (True, False):
            return 'situacao'
        if conf['pasta'] and not PASTA.fullmatch(conf['pasta']):
            return 'pasta'
        if type(conf['intervalo']) is not int or not INTERVALO[0] <= conf['intervalo'] <= INTERVALO[1]:
            return 'intervalo'
        if destino == 'telegram':
            return '' if conf['idioma'] in idioma.IDIOMAS else 'idioma'
        if not ENDERECO_HTTPS.fullmatch(conf['endpoint']):
            return 'endpoint'
        saida.analisar(conf['endpoint'])
        if not s3.REGIAO.fullmatch(conf['regiao']):
            return 'regiao'
        if not s3.BUCKET.fullmatch(conf['bucket']) or '..' in conf['bucket']:
            return 'bucket'
        if conf['prefixo'] and not (len(conf['prefixo']) <= 255 and s3.PREFIXO.fullmatch(conf['prefixo'])):
            return 'prefixo'
        if conf['estilo'] not in ('caminho', 'host'):
            return 'estilo'
        return '' if conf['modo'] in ('copiar', 'mover') else 'modo'
    except saida.Falha:
        return 'endpoint'
    except (KeyError, TypeError, re.error):
        return 'situacao'


def ler(destino):
    """A configuração gravada do destino, ou None quando ele não tem uma (ou o arquivo não serve)."""
    try:
        with open(arquivo(destino, 'conf'), encoding='utf-8') as arq:
            conf = json.loads(arq.read(65536))
    except (OSError, ValueError):
        return None
    if not isinstance(conf, dict) or defeito(destino, conf):
        return None
    if not (isinstance(conf.get('serie'), str) and type(conf.get('desde')) is int):
        return None
    return conf


def operante(destino, conf=None):
    """O destino está ligado e com os segredos no lugar?"""
    conf = conf or ler(destino)
    return bool(conf and conf['ligado'] and segredos_de(destino))


def gravar(destino, novo, novos_segredos):
    """Grava a configuração e os segredos que vieram (o vazio mantém o gravado). O andamento continua quando o lugar
    é o mesmo; destino ou pasta diferente recomeça. O Telegram recomeça também quando volta a ficar operante: o que
    chegou enquanto ele estava parado não é enviado."""
    antes = ler(destino)
    seguia = operante(destino, antes)
    fixos = ('pasta',) if destino == 'telegram' else ('endpoint', 'bucket', 'prefixo', 'estilo', 'pasta')
    mesmo = bool(antes) and all(antes[chave] == novo[chave] for chave in fixos)
    if destino == 'telegram':
        mesmo = mesmo and seguia
    novo = dict(novo)
    novo['serie'] = antes['serie'] if mesmo else secrets.token_hex(8)
    novo['desde'] = antes['desde'] if mesmo else (time.time_ns() if destino == 'telegram' else 0)
    for nome, valor in zip(SEGREDOS[destino], novos_segredos):
        if valor:
            gravar_segredo(nome, valor)
    gravar_texto(arquivo(destino, 'conf'), json.dumps(novo, ensure_ascii=False, sort_keys=True) + '\n')


def remover(destino):
    """Apaga a configuração, o andamento e os segredos do destino."""
    for tipo in ('conf', 'estado'):
        apagar(arquivo(destino, tipo))
    for nome in SEGREDOS[destino]:
        apagar(os.path.join(PASTA_SEGREDOS, nome))


# ------------------------------------------------------------ andamento

def ler_estado(destino, conf):
    """O andamento do destino nesta configuração. Andamento de outro lugar (série diferente) não vale."""
    novo = {'serie': conf['serie'], 'marca': [conf['desde'], ''], 'adiados': {}, 'ultima': {}, 'tropeco': ['', 0],
            'total': {'arquivos': 0, 'bytes': 0}}
    try:
        with open(arquivo(destino, 'estado'), encoding='utf-8') as arq:
            lido = json.load(arq)
        marca = lido['marca']
        if (lido['serie'] == conf['serie'] and type(marca[0]) is int and isinstance(marca[1], str) and len(marca) == 2
                and isinstance(lido['adiados'], dict) and isinstance(lido['ultima'], dict)
                and isinstance(lido['tropeco'][0], str) and type(lido['tropeco'][1]) is int and len(lido['tropeco']) == 2
                and all(type(lido['total'][chave]) is int for chave in ('arquivos', 'bytes'))):
            return {chave: lido[chave] for chave in novo}
    except (OSError, ValueError, KeyError, TypeError, IndexError):
        pass
    return novo


def gravar_estado(destino, estado):
    gravar_texto(arquivo(destino, 'estado'), json.dumps(estado, ensure_ascii=False) + '\n')


def situacao(destino):
    """O que a tela mostra do destino: a configuração, se os segredos estão no lugar, a última passada e a em curso."""
    conf = ler(destino)
    estado = ler_estado(destino, conf) if conf else {}
    return {'conf': conf, 'segredos': segredos_de(destino) is not None, 'ultima': estado.get('ultima', {}),
            'total': estado.get('total', {}), 'adiados': len(estado.get('adiados', ())), 'andamento': ANDAMENTO.get(destino)}


# ------------------------------------------------------------ a pasta

def caminhar(descritor, base, conta, nivel=0):
    """Cada arquivo comum da pasta e das de dentro: (chegada, caminho dentro dos dados, tamanho, inode)."""
    pastas = []
    with os.scandir(descritor) as itens:
        for item in itens:
            if item.name.startswith('.'):
                continue
            try:
                item.name.encode('utf-8')
            except UnicodeEncodeError:
                conta['ignorados'] += 1
                continue
            try:
                if item.is_dir(follow_symlinks=False):
                    pastas.append(item.name)
                    continue
                if not item.is_file(follow_symlinks=False):
                    continue
                dados = item.stat(follow_symlinks=False)
            except OSError:
                continue
            yield dados.st_ctime_ns, base + item.name, dados.st_size, dados.st_ino
    if nivel + 1 >= APAGAR_NIVEIS:
        return
    aparelho = os.fstat(descritor).st_dev
    for nome in pastas:
        try:
            dentro = os.open(nome, ABRIR | os.O_DIRECTORY, dir_fd=descritor)
        except OSError:
            continue  # saiu pelo FTP, ou deu lugar a um link simbólico
        try:
            if os.fstat(dentro).st_dev == aparelho:
                yield from caminhar(dentro, f'{base}{nome}/', conta, nivel + 1)
        finally:
            os.close(dentro)


def escolher(conf, marca, corte, conta, anunciados=None):
    """Os arquivos da pasta que chegaram depois da marca, dos mais antigos para os mais novos, até o primeiro que
    ainda pode estar chegando: o que mudou depois do corte e não tem anúncio de chegada que o cubra. Parar nele é o
    que deixa a marca ser uma só. Devolve (os que saem agora, quantos ficaram à espera)."""
    try:
        raiz = abrir(partes(conf['pasta']), True)
    except Recusado:
        raise saida.Falha('pasta') from None
    try:
        base = conf['pasta'] + '/' if conf['pasta'] else ''
        novos = heapq.nsmallest(LOTE, (item for item in caminhar(raiz, base, conta) if marca < item[:2]))
    finally:
        os.close(raiz)
    agora, calma = time.time_ns(), CALMA * 10**9

    def inteiro(item):
        """Assentou, ou foi anunciado há mais que a calma e não mudou depois dela."""
        anuncio = (anunciados or {}).get(item[1])
        return item[0] <= corte or (anuncio is not None and anuncio + calma <= agora and item[0] <= anuncio + calma)
    prontos = list(itertools.takewhile(inteiro, novos))
    return prontos, len(novos) - len(prontos)


def abrir_igual(item):
    """Abre o arquivo escolhido, se ele ainda é o mesmo. None quando saiu, mudou ou deu lugar a outra coisa."""
    chegada, caminho, tamanho, inode = item
    try:
        descritor = abrir(partes(caminho), False)
    except Recusado:
        return None
    dados = os.fstat(descritor)
    if (dados.st_ino, dados.st_size, dados.st_ctime_ns) != (inode, tamanho, chegada):
        os.close(descritor)
        return None
    return descritor


def mudou(descritor, item):
    dados = os.fstat(descritor)
    return (dados.st_size, dados.st_ctime_ns) != (item[2], item[0])


def apagar_local(caminho, inode, tamanho, chegada):
    """Apaga o arquivo que o S3 confirmou, se ele ainda é o mesmo que foi enviado. Devolve se apagou."""
    lista = partes(caminho)
    try:
        pasta = abrir(lista[:-1], True)
    except Recusado:
        return False
    try:
        dados = os.stat(lista[-1], dir_fd=pasta, follow_symlinks=False)
        if (dados.st_ino, dados.st_size, dados.st_ctime_ns) != (inode, tamanho, chegada):
            return False
        os.unlink(lista[-1], dir_fd=pasta)
        return True
    except OSError:
        return False
    finally:
        os.close(pasta)


# ------------------------------------------------------------ a passada

def falta_o_bot(bot, caminho, chegada, tamanho):
    """O bot do Telegram ainda vai enviar este arquivo? `bot` é (pasta, marca) do Telegram operante, ou None."""
    if not bot or not tamanho:
        return False
    pasta, marca = bot
    return (not pasta or caminho.startswith(pasta + '/')) and marca < (chegada, caminho)


def bot_agora():
    conf = ler('telegram')
    return (conf['pasta'], tuple(ler_estado('telegram', conf)['marca'])) if operante('telegram', conf) else None


def entregar_s3(conf, canal, estado, item, resumo, bot):
    chegada, caminho, tamanho, inode = item
    chave = s3.chave_do_objeto(conf['prefixo'], caminho)
    if chave is None or tamanho > s3.OBJETO_MAX:
        resumo['ignorados'] += 1
        return
    adiar = conf['modo'] == 'mover' and falta_o_bot(bot, caminho, chegada, tamanho)
    if adiar and len(estado['adiados']) >= ADIADOS_MAX:
        raise saida.Falha('espera')   # o bot está parado e a fila do que espera por ele encheu: nada mais sai até ele voltar
    descritor = abrir_igual(item)
    if descritor is None:
        return
    try:
        try:
            canal.enviar(chave, descritor, tamanho)
        except saida.Falha:
            if mudou(descritor, item):
                return   # mudou no meio do envio: a versão nova entra em uma passada seguinte
            raise
        if mudou(descritor, item):
            return
    finally:
        os.close(descritor)
    resumo['arquivos'] += 1
    resumo['bytes'] += tamanho
    if conf['modo'] != 'mover':
        return
    if adiar:
        estado['adiados'][caminho] = [inode, tamanho, chegada]
    elif apagar_local(caminho, inode, tamanho, chegada):
        resumo['apagados'] += 1


def apagar_adiados(estado, resumo, bot):
    """Arquivos que o S3 já tinha confirmado e que esperavam o bot: apaga os que ele entregou; o que mudou sai da lista."""
    for caminho, (inode, tamanho, chegada) in list(estado['adiados'].items()):
        if falta_o_bot(bot, caminho, chegada, tamanho):
            continue
        if apagar_local(caminho, inode, tamanho, chegada):
            resumo['apagados'] += 1
        del estado['adiados'][caminho]


def texto_do_arquivo(caminho, tamanho, chegada):
    return f'{caminho}\n{com_unidade(tamanho)} · {quando(chegada // 10**9)}'


def entregar_telegram(conf, canal, estado, item, resumo, bot):
    chegada, caminho, tamanho, _ = item
    if not tamanho:
        resumo['ignorados'] += 1   # a API de bot não aceita arquivo vazio
        return

    def avisar():
        canal.avisar(t('Arquivo maior que o limite de envio do bot ({limite}): não foi enviado por aqui.',
                       limite=com_unidade(CFG['telegram_max'])) + '\n' + texto_do_arquivo(caminho, tamanho, chegada))
        resumo['grandes'] += 1
    try:
        if tamanho > CFG['telegram_max']:
            return avisar()
        descritor = abrir_igual(item)
        if descritor is None:
            return None
        try:
            canal.enviar(descritor, tamanho, caminho.rsplit('/', 1)[-1], texto_do_arquivo(caminho, tamanho, chegada))
        except saida.Falha as falha:
            if falha.motivo == 'limite':
                return avisar()   # a API recusou pelo tamanho: o limite dela é menor que PAINEL_TELEGRAM_MAX_MB
            if mudou(descritor, item):
                return None
            raise
        finally:
            os.close(descritor)
        resumo['arquivos'] += 1
        resumo['bytes'] += tamanho
    finally:
        time.sleep(PAUSA_TELEGRAM)
    return None


def desistir(estado, caminho, motivo):
    """O destino recusou este arquivo, e não o acesso: resposta 4xx que não é de permissão, de limite nem de pressa.
    Na passada de número TROPECOS em que o mesmo arquivo é recusado, ele fica para trás, para os seguintes saírem."""
    if not re.fullmatch(r'http_4[0-9]{2}', motivo) or motivo in ('http_408', 'http_429'):
        return False
    anterior, vezes = estado['tropeco']
    estado['tropeco'] = [caminho, vezes + 1 if anterior == caminho else 1]
    return estado['tropeco'][1] >= TROPECOS


def canal_de(destino, conf, prazo=saida.PRAZO):
    valores = segredos_de(destino)
    if not valores:
        raise saida.Falha('segredo')
    if destino == 's3':
        return s3.Destino(conf, *valores, prazo=prazo)
    return telegram.Bot(CFG['telegram_api'], *valores, prazo=prazo)


def passada(destino, conf, recentes=False, anunciados=None):
    """Envia o que chegou desde a última marca. Devolve o resumo; `motivo` vazio é passada completa. Com `recentes`,
    entram também os arquivos que ainda não assentaram (pedido pelo terminal); `anunciados` são os que chegaram
    inteiros e não precisam esperar. `esperando` conta os que ficaram para a passada seguinte."""
    estado = ler_estado(destino, conf)
    resumo = {'quando': int(time.time()), 'arquivos': 0, 'bytes': 0, 'apagados': 0, 'grandes': 0, 'ignorados': 0, 'erros': 0,
              'esperando': 0, 'motivo': ''}
    corte = time.time_ns() - (0 if recentes else ASSENTAR * 10**9)
    entregar = entregar_s3 if destino == 's3' else entregar_telegram
    bot = bot_agora() if destino == 's3' else None
    canal, gravado = None, time.monotonic()
    ANDAMENTO[destino] = resumo
    if destino == 'telegram':
        idioma.usar(conf['idioma'])
    try:
        canal = canal_de(destino, conf)
        if destino == 's3':
            apagar_adiados(estado, resumo, bot)
        while True:
            conta = {'ignorados': 0}
            itens, esperando = escolher(conf, tuple(estado['marca']), corte, conta, anunciados)
            for item in itens:
                try:
                    entregar(conf, canal, estado, item, resumo, bot)
                except saida.Falha as falha:
                    if not desistir(estado, item[1], falha.motivo):
                        raise
                    resumo['erros'] += 1
                    auditar('-', 'destino_pulado', f'destino={destino} arquivo={limpo(item[1], 200)} motivo={falha.motivo}')
                estado['marca'] = [item[0], item[1]]
                if destino == 'telegram' or time.monotonic() - gravado > GRAVAR_A_CADA:
                    gravar_estado(destino, estado)
                    gravado = time.monotonic()
            if len(itens) < LOTE:
                resumo['ignorados'] += conta['ignorados']
                resumo['esperando'] = esperando
                break
    except saida.Falha as falha:
        resumo['motivo'] = falha.motivo
    except OSError:
        resumo['motivo'] = 'arquivo'
    finally:
        if canal:
            canal.fechar()
        ANDAMENTO.pop(destino, None)
        anterior = estado['ultima'].get('motivo', '')
        estado['ultima'] = resumo
        estado['total']['arquivos'] += resumo['arquivos']
        estado['total']['bytes'] += resumo['bytes']
        with contextlib.suppress(OSError):
            gravar_estado(destino, estado)
    if resumo['apagados']:
        limpar_cache()
    numeros = (f'arquivos={resumo["arquivos"]} bytes={resumo["bytes"]} apagados={resumo["apagados"]} '
               f'grandes={resumo["grandes"]} ignorados={resumo["ignorados"]} erros={resumo["erros"]}')
    if resumo['arquivos'] or resumo['apagados'] or resumo['grandes'] or resumo['erros']:
        auditar('-', 'destino_enviado', f'destino={destino} {numeros}')
    # A falha que se repete a cada passada é registrada uma vez, quando começa.
    if resumo['motivo'] and resumo['motivo'] != anterior:
        auditar('-', 'destino_falhou', f'destino={destino} motivo={resumo["motivo"]}')
    return resumo


@contextlib.contextmanager
def uma_por_vez():
    """Só uma passada por vez, entre a linha de execução do painel e o terminal. Entrega se conseguiu a vez."""
    descritor = os.open(ARQ_TRAVA, os.O_RDWR | os.O_CREAT | os.O_CLOEXEC, 0o600)
    try:
        try:
            fcntl.flock(descritor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            yield False
            return
        yield True
    finally:
        os.close(descritor)


def na_hora(destino, conf):
    ultima = ler_estado(destino, conf)['ultima'].get('quando', 0)
    return not isinstance(ultima, int) or time.time() - ultima >= conf['intervalo'] * 60


def executar(pedidos=None, recentes=False):
    """Faz as passadas dos destinos operantes: os pedidos, quando vêm, ou os que estão na hora. Devolve
    {destino: resumo}, ou None quando outra passada está em curso."""
    confs = {destino: ler(destino) for destino in NOMES}
    vez = {destino for destino in NOMES if operante(destino, confs[destino])
           and (destino in pedidos if pedidos is not None else na_hora(destino, confs[destino]))}
    # Antes de o S3 apagar o que gravou, o bot entrega o que falta: a passada dele vem junto.
    if 's3' in vez and confs['s3']['modo'] == 'mover' and operante('telegram', confs['telegram']):
        vez.add('telegram')
    if not vez:
        return {}
    with uma_por_vez() as livre:
        if not livre:
            return None
        return {destino: passada(destino, confs[destino], recentes, chegadas.validos() if destino == 'telegram' else None)
                for destino in NOMES if destino in vez}


def pedir(destino):
    """Passada pedida pela tela: a linha de execução acorda e faz, sem esperar o intervalo."""
    with TRAVA_PEDIDOS:
        PEDIDOS.add(destino)
    ACORDAR.set()


def rodar():
    """Colhe os anúncios de chegada a cada COLHER segundos e faz as passadas: a pedida pela tela, a do bot quando
    chega arquivo (`urgente`) ou quando o que estava à espera já assentou (`rever`), e a de quem está na hora."""
    conferido, urgente, rever, depois = time.monotonic(), 0.0, 0.0, False

    def volta(feitas):
        """A passada do bot deixou arquivo à espera: a seguinte é quando ele assentar, e não só no intervalo."""
        return time.monotonic() + ASSENTAR + CALMA if (feitas or {}).get('telegram', {}).get('esperando') else 0.0
    while True:
        agora = time.monotonic()
        ACORDAR.wait(min([COLHER] + [max(prazo - agora, 0.1) for prazo in (urgente, rever) if prazo]))
        ACORDAR.clear()
        with TRAVA_PEDIDOS:
            pedidos = set(PEDIDOS)
            PEDIDOS.clear()
        try:
            chegadas.colher()
            agora = time.monotonic()
            if chegadas.NOVAS.is_set():
                chegadas.NOVAS.clear()
                if urgente:
                    depois = True   # chegou mais um com a passada do bot já marcada: ele ganha a dele em seguida
                else:
                    urgente = agora + CALMA
            if 0 < urgente <= agora or 0 < rever <= agora:
                pedidos.add('telegram')
            if pedidos:
                feitas = executar(pedidos)
                if feitas is None:
                    with TRAVA_PEDIDOS:
                        PEDIDOS.update(pedidos)   # o terminal está fazendo uma passada: o pedido fica para a volta seguinte
                    urgente, rever = 0.0, 0.0
                elif 'telegram' in pedidos:
                    urgente, depois, rever = (time.monotonic() + CALMA if depois else 0.0), False, volta(feitas)
            if agora - conferido >= CONFERIR:
                conferido = agora
                rever = volta(executar()) or rever
        except Exception as motivo:  # uma passada que falha não acaba com as seguintes
            urgente, rever, depois = 0.0, 0.0, False
            auditar('-', 'destino_falhou', f'destino=- motivo={type(motivo).__name__}')


def iniciar():
    """Começa as passadas. Só o servidor do painel chama; com PAINEL_DESTINOS=nao, nada sai do servidor."""
    if CFG['destinos']:
        threading.Thread(target=rodar, name='destinos', daemon=True).start()


# ------------------------------------------------------------ teste pedido pela tela ou pelo terminal

def testar(destino):
    """Grava um objeto de teste no S3 ou envia uma mensagem de teste pelo bot. Devolve '' quando deu certo, o motivo
    da falha ou 'ocupado' quando outro teste está em curso."""
    conf = ler(destino)
    if not conf or not segredos_de(destino):
        return 'segredo'
    if not TRAVA_TESTE.acquire(blocking=False):
        return 'ocupado'
    resultado, lingua = [], idioma.atual()

    def tentar():
        idioma.usar(lingua)
        canal = None
        try:
            canal = canal_de(destino, conf, PRAZO_TESTE)
            if destino == 's3':
                chave = s3.chave_do_objeto(conf['prefixo'], 'allsafe-ftp-stack-teste.txt')
                canal.pedir('PUT', chave, corpo=f'Teste de gravação da allsafe-ftp-stack, em {time.strftime("%Y-%m-%d %H:%M:%S")}.\n'.encode())
            else:
                canal.avisar(t('Teste do painel da allsafe-ftp-stack: o bot consegue enviar para esta conversa.'))
            resultado.append('')
        except saida.Falha as falha:
            resultado.append(falha.motivo)
        except Exception:  # o que o teste não previu não derruba o pedido da tela
            resultado.append('conexao')
        finally:
            if canal:
                canal.fechar()
            TRAVA_TESTE.release()
    linha = threading.Thread(target=tentar, name='destinos-teste', daemon=True)
    linha.start()
    linha.join(TESTE_MAX)
    return resultado[0] if resultado else 'tempo'


# ------------------------------------------------------------ um arquivo só, pedido pela aba Arquivos

def enviar_arquivo(destino, caminho, ao_terminar):
    """Envia um arquivo ao destino, com o que está gravado; funciona com o destino desligado, como o teste. Não mexe
    no andamento das passadas e nunca apaga o arquivo, nem no modo `mover`. Devolve '' quando o destino recebeu, o
    motivo da recusa ou da falha, ou 'andando' quando o envio passou de AVULSO_MAX segundos e segue sozinho.
    `ao_terminar(resultado, bytes)` é chamada uma vez, quando o envio acaba. Levanta Recusado quando o caminho não é
    de um arquivo comum dentro dos dados."""
    descritor = abrir(partes(caminho), False)
    dados = os.fstat(descritor)
    item = (dados.st_ctime_ns, caminho, dados.st_size, dados.st_ino)
    conf, chave, motivo = ler(destino), None, ''
    if not conf or not segredos_de(destino):
        motivo = 'segredo'
    elif destino == 'telegram':
        motivo = 'vazio' if not item[2] else 'limite' if item[2] > CFG['telegram_max'] else ''
    else:
        chave = s3.chave_do_objeto(conf['prefixo'], caminho)
        motivo = 'nome' if chave is None else 'limite' if item[2] > s3.OBJETO_MAX else ''
    if not motivo and not TRAVA_AVULSO.acquire(blocking=False):
        motivo = 'enviando'
    if motivo:
        os.close(descritor)
        ao_terminar(motivo, item[2])
        return motivo
    resultado = []

    def tentar():
        canal = None
        try:
            if destino == 'telegram':
                idioma.usar(conf['idioma'])
            canal = canal_de(destino, conf)
            if destino == 's3':
                canal.enviar(chave, descritor, item[2])
            else:
                canal.enviar(descritor, item[2], caminho.rsplit('/', 1)[-1], texto_do_arquivo(caminho, item[2], item[0]))
            resultado.append('mudou' if mudou(descritor, item) else '')
        except saida.Falha as falha:
            resultado.append(falha.motivo)
        except OSError:
            resultado.append('arquivo')
        except Exception:  # o que o envio não previu não derruba o pedido da tela
            resultado.append('conexao')
        finally:
            if canal:
                canal.fechar()
            os.close(descritor)
            TRAVA_AVULSO.release()
            ao_terminar(resultado[0], item[2])
    linha = threading.Thread(target=tentar, name='destinos-arquivo', daemon=True)
    linha.start()
    linha.join(AVULSO_MAX)
    return resultado[0] if resultado else 'andando'
