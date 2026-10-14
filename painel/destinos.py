# SPDX-License-Identifier: Apache-2.0
"""Destinos de fora: o painel envia sozinho os arquivos de uma pasta para armazenamentos S3, para remotos do rclone e
para bots do Telegram.

O administrador grava na aba Destinos quantos destinos quiser de cada tipo, até POR_TIPO: cada um leva uma pasta a um
lugar. O primeiro de cada tipo se chama `s3`, `rclone` ou `telegram` e os seguintes, `s3-2`, `telegram-2` e assim por diante. A
configuração fica em /painel/destinos/<destino>.conf e os segredos, um por arquivo, em /segredos (SECRETS_DIR/destinos,
no host), com o nome do destino na frente. Dois destinos podem usar o mesmo acesso: o destino novo criado a partir de
outro recebe uma cópia dos segredos dele, feita aqui no servidor. Uma linha de execução do próprio painel confere a
cada minuto e faz a passada do destino que está na hora; a mesma passada sai pelo terminal (servidor.py --destinos
enviar <destino>).

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

Para a aba Serviço, o andamento guarda também os últimos HISTORICO arquivos enviados e os últimos que ficaram de fora,
com o motivo, e a tela mede a fila: o que está na pasta depois da marca de cada destino (filas).

No S3, o modo `copiar` deixa o arquivo no servidor e o `mover` apaga o arquivo depois que o destino confirma a
gravação, e só se ele não mudou desde o envio. O Telegram só envia o que chegar depois de ligado. Com mais de um
destino na mesma pasta, os bots e os S3 em `copiar` passam primeiro, e o `mover` só apaga o arquivo depois que todos
os outros destinos operantes que o cobrem passaram por ele.

O remoto do rclone (rclone.py) só recebe: envia o que já estava na pasta e o que chegar, como o S3 em `copiar`, não tem
o modo `mover` e o arquivo continua no servidor. O segredo dele é um só, o arquivo de configuração do remoto.
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
import rclone
import s3
import saida
import telegram
from aba_arquivos import ABRIR, Recusado, abrir, partes
from auditoria import auditar, limpo
from config import APAGAR_NIVEIS, CFG, ENDERECO_HTTPS, PASTA, PASTA_DESTINOS, PASTA_SEGREDOS
from estado import com_cache, limpar_cache
from idioma import t
from pagina import quando, tamanho as com_unidade

TIPOS = ('telegram', 'rclone', 's3')   # a ordem da passada: os outros entregam antes de um S3 poder apagar
POR_TIPO = 20                 # destinos de cada tipo
IDENTIFICADOR = re.compile(r'(telegram|rclone|s3)(-([2-9]|1[0-9]|20))?')
NOME = re.compile(r'[^\x00-\x1f\x7f-\x9f]{0,40}')   # o nome que o administrador dá ao destino, para a tela
SEGREDOS = {'s3': ('chave-de-acesso', 'chave-secreta'), 'telegram': ('token', 'conversa'), 'rclone': ('remoto',)}
FORMATO = {'s3': (r'[\x21-\x7e]{3,128}', r'[\x21-\x7e]{8,256}'),
           'telegram': (telegram.TOKEN.pattern, telegram.CONVERSA.pattern)}
ARQ_TRAVA = os.path.join(PASTA_DESTINOS, '.trava')
ASSENTAR = 120               # segundos sem mudar para o arquivo entrar na passada
LOTE = 20000                 # arquivos escolhidos por vez, dos mais antigos para os mais novos
INTERVALO = (5, 1440)        # minutos entre as passadas de um destino
PAUSA_TELEGRAM = 3           # segundos entre um envio e o seguinte: a API limita as mensagens por minuto de um grupo
ADIADOS_MAX = 20000          # arquivos já gravados no S3 à espera dos outros destinos para serem apagados
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
HISTORICO = 30               # últimos arquivos enviados, e últimos não enviados, que cada destino guarda para a aba Serviço
FILA_NA_TELA = 30            # arquivos da fila que a aba Serviço lista por destino: os mais antigos, que saem primeiro
FILA_PRAZO = 2               # segundos da medida da fila de uma pasta...
FILA_MAX = 50000             # ...e arquivos lidos nela; acima disso a conta sai como parcial
FILAS_PRAZO = 6              # segundos da medida de todas as filas em uma tela; a pasta que não coube fica sem medida
FILA_VALE = 20               # segundos que a medida da fila de uma pasta vale

ACORDAR = threading.Event()
PEDIDOS = set()              # destinos com passada pedida pelo botão Enviar agora
TRAVA_PEDIDOS = threading.Lock()
TRAVA_TESTE = threading.Lock()
TRAVA_AVULSO = threading.Lock()   # um envio de arquivo pedido pela tela por vez
ANDAMENTO = {}               # destino ➜ o que a passada em curso já fez, para a tela


def arquivo(destino, parte):
    return os.path.join(PASTA_DESTINOS, f'{destino}.{parte}')


# ------------------------------------------------------------ os destinos e os nomes deles

def tipo(destino):
    """'s3', 'rclone' ou 'telegram': o primeiro destino do tipo tem o nome dele, e os seguintes, <tipo>-2 a <tipo>-20."""
    return destino.partition('-')[0]


def valido(destino):
    return isinstance(destino, str) and bool(IDENTIFICADOR.fullmatch(destino))


def do_tipo(qual):
    """Todos os nomes que um destino do tipo pode ter, em ordem."""
    return [qual] + [f'{qual}-{numero}' for numero in range(2, POR_TIPO + 1)]


def todos(qual=None):
    """Os destinos gravados, de um tipo ou de todos: os bots, os remotos do rclone e os S3, cada tipo na ordem dos nomes."""
    return [destino for cada in ((qual,) if qual else TIPOS) for destino in do_tipo(cada) if ler(destino)]


def livre(qual):
    """O nome que o próximo destino do tipo recebe: o primeiro sem configuração. None quando o tipo está cheio."""
    return next((destino for destino in do_tipo(qual) if not ler(destino)), None)


def nomes_dos_segredos(destino):
    return tuple(f'{destino}-{sufixo}.txt' for sufixo in SEGREDOS[tipo(destino)])


def cruzam(uma, outra):
    """As duas pastas são a mesma, ou uma está dentro da outra? A pasta vazia é a dos dados inteira."""
    return not uma or not outra or uma == outra or uma.startswith(outra + '/') or outra.startswith(uma + '/')


# ------------------------------------------------------------ segredos

def ler_segredo(nome, limite=SEGREDO_MAX):
    """O conteúdo de um arquivo de segredo, ou '' quando não existe, está vazio ou não é um arquivo comum."""
    try:
        descritor = os.open(os.path.join(PASTA_SEGREDOS, nome), os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK)
    except OSError:
        return ''
    try:
        return os.read(descritor, limite + 1).decode('ascii', 'replace').strip()
    except OSError:
        return ''
    finally:
        os.close(descritor)


def guardados_de(destino):
    """O que está nos arquivos de segredo do destino, sem conferir o formato."""
    limite = rclone.SEGREDO_MAX if tipo(destino) == 'rclone' else SEGREDO_MAX
    return tuple(ler_segredo(nome, limite) for nome in nomes_dos_segredos(destino))


def remoto_de(texto):
    """(tipo, campos) do arquivo de remoto do rclone, ou None quando ele não é o que o painel gravaria."""
    try:
        return rclone.analisar(texto)
    except saida.Falha:
        return None


def segredos_de(destino):
    """Os segredos do destino, ou None quando falta algum ou algum não tem o formato dele: dois no S3 e no bot; no
    rclone, o arquivo do remoto."""
    valores = guardados_de(destino)
    if tipo(destino) == 'rclone':
        return valores if remoto_de(valores[0]) else None
    return valores if all(re.fullmatch(regra, valor) for regra, valor in zip(FORMATO[tipo(destino)], valores)) else None


def chaves_do_servidor(destino):
    """As impressões digitais das chaves que o remoto SFTP tem fixadas, que é o que a tela mostra do remoto. None
    quando o destino não é um remoto SFTP com o segredo no lugar."""
    remoto = remoto_de(guardados_de(destino)[0]) if tipo(destino) == 'rclone' else None
    return rclone.impressoes(remoto[1]) if remoto and remoto[0] == 'sftp' else None


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
        if not (isinstance(conf.get('nome', ''), str) and NOME.fullmatch(conf.get('nome', ''))):
            return 'nome'
        if conf['pasta'] and not PASTA.fullmatch(conf['pasta']):
            return 'pasta'
        if type(conf['intervalo']) is not int or not INTERVALO[0] <= conf['intervalo'] <= INTERVALO[1]:
            return 'intervalo'
        if tipo(destino) == 'telegram':
            return '' if conf['idioma'] in idioma.IDIOMAS else 'idioma'
        if tipo(destino) == 'rclone':
            if conf['remoto'] not in rclone.CAMPOS:
                return 'remoto'
            caminho = conf['caminho']
            if not caminho:
                return 'balde' if conf['remoto'] in rclone.BALDES else ''
            return '' if len(caminho) <= rclone.CAMINHO_MAX and rclone.CAMINHO.fullmatch(caminho) else 'caminho'
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
    conf.setdefault('nome', '')   # a configuração gravada antes de haver vários destinos não tem o nome
    return conf


def operante(destino, conf=None):
    """O destino está ligado e com os segredos no lugar?"""
    conf = conf or ler(destino)
    return bool(conf and conf['ligado'] and segredos_de(destino))


def segredos_finais(destino, novos_segredos, origem=None):
    """Os segredos com que o destino fica depois de gravado: o que veio; onde veio vazio, o do destino de origem (em
    destino novo, criado com o acesso de outro) ou o que já está gravado nele."""
    guardados = (segredos_de(origem) if origem else None) or guardados_de(destino)
    return tuple(valor or guardado for valor, guardado in zip(novos_segredos, guardados))


def repetido(destino, conf, novos_segredos, origem=None):
    """O outro destino que já leva a mesma pasta, ou uma que a contém ou está dentro dela, ao mesmo lugar: no S3, o
    mesmo endereço, bucket e prefixo; no bot, o mesmo token e a mesma conversa; no rclone, o mesmo tipo de remoto,
    servidor, usuário e caminho. '' quando não há. Os segredos são comparados aqui, no servidor."""
    qual = tipo(destino)
    meus = segredos_finais(destino, novos_segredos, origem) if qual != 's3' else None
    remoto = remoto_de(meus[0]) if qual == 'rclone' else None
    onde = rclone.lugar(*remoto, conf['caminho']) if remoto else None
    for outro in todos(qual):
        dele = ler(outro)
        if outro == destino or not dele or not cruzam(dele['pasta'], conf['pasta']):
            continue
        if qual == 's3' and all(dele[chave] == conf[chave] for chave in ('endpoint', 'bucket', 'prefixo')):
            return outro
        if qual == 'telegram' and all(meus) and segredos_de(outro) == meus:
            return outro
        remoto = remoto_de(guardados_de(outro)[0]) if onde else None
        if remoto and rclone.lugar(*remoto, dele['caminho']) == onde:
            return outro
    return ''


def gravar(destino, novo, novos_segredos, origem=None):
    """Grava a configuração e os segredos que vieram. O segredo vazio mantém o gravado; em destino novo criado com o
    acesso de outro (`origem`), o vazio é copiado do destino de origem, aqui no servidor. O andamento continua quando
    o lugar é o mesmo; destino ou pasta diferente recomeça. O Telegram recomeça também quando volta a ficar operante:
    o que chegou enquanto ele estava parado não é enviado. No rclone, `novos_segredos` traz o arquivo do remoto."""
    antes = ler(destino)
    seguia = operante(destino, antes)
    qual = tipo(destino)
    bot = qual == 'telegram'
    fixos = {'telegram': ('pasta',), 'rclone': ('remoto', 'caminho', 'pasta'),
             's3': ('endpoint', 'bucket', 'prefixo', 'estilo', 'pasta')}[qual]
    mesmo = bool(antes) and all(antes[chave] == novo[chave] for chave in fixos)
    if bot:
        mesmo = mesmo and seguia
    if mesmo and qual == 'rclone':
        # O servidor e o usuário do remoto estão no segredo: o andamento continua só se o remoto regravado é o mesmo.
        velho, vindo = remoto_de(guardados_de(destino)[0]), remoto_de(segredos_finais(destino, novos_segredos, origem)[0])
        mesmo = bool(velho and vindo) and rclone.lugar(*velho, '') == rclone.lugar(*vindo, '')
    novo = dict(novo)
    novo['serie'] = antes['serie'] if mesmo else secrets.token_hex(8)
    novo['desde'] = antes['desde'] if mesmo else (time.time_ns() if bot else 0)
    copiados = (segredos_de(origem) if origem else None) or ('',) * len(SEGREDOS[qual])
    for nome, valor, copiado in zip(nomes_dos_segredos(destino), novos_segredos, copiados):
        if valor or copiado:
            gravar_segredo(nome, valor or copiado)
    gravar_texto(arquivo(destino, 'conf'), json.dumps(novo, ensure_ascii=False, sort_keys=True) + '\n')


def remover(destino):
    """Apaga a configuração, o andamento e os segredos do destino. Nada é apagado no destino de fora."""
    for parte in ('conf', 'estado'):
        apagar(arquivo(destino, parte))
    for nome in nomes_dos_segredos(destino):
        apagar(os.path.join(PASTA_SEGREDOS, nome))


# ------------------------------------------------------------ andamento

def historico_de(lido):
    """As listas da aba Serviço, do andamento lido: os últimos enviados, [quando, caminho, tamanho], e os últimos
    não enviados, com o motivo no fim. O andamento gravado antes delas, ou com elas fora do formato, vale do mesmo
    jeito: as listas começam vazias e a marca não muda."""
    listas, guardado = {'enviados': [], 'recusados': []}, lido.get('historico')
    if not isinstance(guardado, dict):
        return listas
    for chave, campos in (('enviados', 3), ('recusados', 4)):
        linhas = guardado.get(chave)
        if isinstance(linhas, list) and all(
                isinstance(linha, list) and len(linha) == campos and type(linha[0]) is int and isinstance(linha[1], str)
                and type(linha[2]) is int and all(isinstance(resto, str) for resto in linha[3:]) for linha in linhas):
            listas[chave] = linhas[-HISTORICO:]
    return listas


def ler_estado(destino, conf):
    """O andamento do destino nesta configuração. Andamento de outro lugar (série diferente) não vale."""
    novo = {'serie': conf['serie'], 'marca': [conf['desde'], ''], 'adiados': {}, 'ultima': {}, 'tropeco': ['', 0],
            'total': {'arquivos': 0, 'bytes': 0, 'recusados': 0}, 'historico': {'enviados': [], 'recusados': []}}
    try:
        with open(arquivo(destino, 'estado'), encoding='utf-8') as arq:
            lido = json.load(arq)
        marca = lido['marca']
        if (lido['serie'] == conf['serie'] and type(marca[0]) is int and isinstance(marca[1], str) and len(marca) == 2
                and isinstance(lido['adiados'], dict) and isinstance(lido['ultima'], dict)
                and isinstance(lido['tropeco'][0], str) and type(lido['tropeco'][1]) is int and len(lido['tropeco']) == 2
                and all(type(lido['total'][chave]) is int for chave in ('arquivos', 'bytes'))):
            estado = {chave: lido[chave] for chave in novo if chave != 'historico'}
            # O que a aba Serviço acrescentou é conferido à parte: o andamento de uma versão anterior continua valendo.
            estado['historico'] = historico_de(lido)
            if type(estado['total'].get('recusados')) is not int:
                estado['total']['recusados'] = 0
            return estado
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
            'total': estado.get('total', {}), 'adiados': len(estado.get('adiados', ())), 'andamento': ANDAMENTO.get(destino),
            'chaves': chaves_do_servidor(destino), 'historico': estado.get('historico', {'enviados': [], 'recusados': []}),
            'marca': tuple(estado['marca']) if estado else None}


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


def medir_fila(pasta, marcas):
    """O que a pasta tem depois de cada marca: marca ➜ (arquivos, bytes, os FILA_NA_TELA mais antigos, cada um
    [chegada, caminho, tamanho]), e se a conta parou antes do fim, pelo prazo ou pelo teto. None: a pasta não existe."""
    try:
        raiz = abrir(partes(pasta), True)
    except Recusado:
        return None
    contas = {marca: [0, 0, []] for marca in marcas}
    lidos, parcial, prazo = 0, False, time.monotonic() + FILA_PRAZO
    try:
        with contextlib.closing(caminhar(raiz, pasta + '/' if pasta else '', {'ignorados': 0})) as itens:
            for item in itens:
                lidos += 1
                for marca, conta in contas.items():
                    if marca < item[:2]:
                        conta[0] += 1
                        conta[1] += item[2]
                        conta[2].append(item[:3])
                        if len(conta[2]) > 8 * FILA_NA_TELA:
                            conta[2] = heapq.nsmallest(FILA_NA_TELA, conta[2])
                if lidos >= FILA_MAX or (lidos % 256 == 0 and time.monotonic() > prazo):
                    parcial = True
                    break
    except OSError:
        parcial = True
    finally:
        os.close(raiz)
    return {'parcial': parcial,
            'marcas': {marca: (conta[0], conta[1], heapq.nsmallest(FILA_NA_TELA, conta[2])) for marca, conta in contas.items()}}


def filas(vistos, prazo=FILAS_PRAZO):
    """A fila de cada destino configurado: destino ➜ {'arquivos', 'bytes', 'primeiros', 'parcial'}. `vistos` é
    destino ➜ situacao(destino). Uma leitura por pasta serve a todos os destinos dela, e vale por FILA_VALE segundos
    enquanto as marcas forem as mesmas. None: a pasta não existe mais, ou o tempo da tela acabou antes dela."""
    por_pasta = {}
    for destino, visto in vistos.items():
        if visto['conf']:
            por_pasta.setdefault(visto['conf']['pasta'], set()).add(visto['marca'])
    fim, medidas = time.monotonic() + prazo, {}
    for pasta, marcas in sorted(por_pasta.items()):
        marcas = tuple(sorted(marcas))

        def medir(pasta=pasta, marcas=marcas):
            return marcas, medir_fila(pasta, marcas)
        if time.monotonic() > fim:
            continue
        guardado = com_cache(('fila', pasta), FILA_VALE, medir)
        if guardado[0] != marcas:
            guardado = com_cache(('fila', pasta), 0, medir)   # uma passada andou: a medida anterior não serve
        medidas[pasta] = guardado[1]
    resposta = {}
    for destino, visto in vistos.items():
        medida = medidas.get(visto['conf']['pasta']) if visto['conf'] else None
        if medida:
            arquivos, octetos, primeiros = medida['marcas'][visto['marca']]
            resposta[destino] = {'arquivos': arquivos, 'bytes': octetos, 'primeiros': primeiros, 'parcial': medida['parcial']}
        else:
            resposta[destino] = None
    return resposta


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

def falta(outros, caminho, chegada, tamanho):
    """Algum outro destino ainda vai enviar este arquivo? `outros` vem de outros_agora(). O bot não envia arquivo vazio."""
    return any((tamanho or qual != 'telegram') and (not pasta or caminho.startswith(pasta + '/')) and marca < (chegada, caminho)
               for qual, pasta, marca in outros)


def outros_agora(destino):
    """(tipo, pasta, marca) de cada outro destino operante, de qualquer tipo: é por eles que o `mover` espera antes de apagar."""
    lista = []
    for outro in todos():
        conf = ler(outro)
        if outro != destino and operante(outro, conf):
            lista.append((tipo(outro), conf['pasta'], tuple(ler_estado(outro, conf)['marca'])))
    return lista


def entregar_s3(conf, canal, estado, item, resumo, outros):
    chegada, caminho, tamanho, inode = item
    chave = s3.chave_do_objeto(conf['prefixo'], caminho)
    if chave is None or tamanho > s3.OBJETO_MAX:
        resumo['ignorados'] += 1
        return
    adiar = conf['modo'] == 'mover' and falta(outros, caminho, chegada, tamanho)
    if adiar and len(estado['adiados']) >= ADIADOS_MAX:
        raise saida.Falha('espera')   # outro destino está parado e a fila do que espera por ele encheu: nada mais sai até ele voltar
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


def entregar_rclone(conf, canal, estado, item, resumo, outros):
    chegada, caminho, tamanho, _ = item
    alvo = rclone.alvo_de(conf['caminho'], caminho)
    if alvo is None:
        resumo['ignorados'] += 1
        return
    descritor = abrir_igual(item)
    if descritor is None:
        return
    try:
        try:
            canal.enviar(alvo, descritor, tamanho)
        except saida.Falha:
            if mudou(descritor, item):
                return   # mudou no meio do envio: a versão nova entra em uma passada seguinte e grava por cima
            raise
        if mudou(descritor, item):
            return
    finally:
        os.close(descritor)
    resumo['arquivos'] += 1
    resumo['bytes'] += tamanho


def apagar_adiados(estado, resumo, outros):
    """Arquivos que o S3 já tinha confirmado e que esperavam outro destino: apaga os que todos já entregaram; o que
    mudou ou já saiu do servidor sai da lista."""
    for caminho, (inode, tamanho, chegada) in list(estado['adiados'].items()):
        if falta(outros, caminho, chegada, tamanho):
            continue
        if apagar_local(caminho, inode, tamanho, chegada):
            resumo['apagados'] += 1
        del estado['adiados'][caminho]


def texto_do_arquivo(caminho, tamanho, chegada):
    return f'{caminho}\n{com_unidade(tamanho)} · {quando(chegada // 10**9)}'


def entregar_telegram(conf, canal, estado, item, resumo, outros):
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


def desfecho(qual, tamanho, antes, resumo):
    """O que a entrega fez com o arquivo, pela conta da passada antes e depois dele: '' é enviado; um motivo, o que
    o deixou de fora (MOTIVOS em aba_destinos.py); None, o arquivo que mudou ou saiu do servidor no meio do envio, e
    que por isso não entra em lista nenhuma: a versão nova dele vai em outra passada."""
    if resumo['arquivos'] > antes[0]:
        return ''
    if resumo['grandes'] > antes[1]:
        return 'limite'
    if resumo['ignorados'] > antes[2]:
        if qual == 'telegram':
            return 'vazio'
        return 'limite' if qual == 's3' and tamanho > s3.OBJETO_MAX else 'nome'
    return None


def anotar(estado, item, motivo):
    """Guarda o arquivo para a aba Serviço: sem motivo, entre os últimos enviados; com motivo, entre os últimos não
    enviados, que também entram na soma do destino."""
    linha = [int(time.time()), item[1], item[2]]
    lista = estado['historico']['recusados' if motivo else 'enviados']
    lista.append(linha + [motivo] if motivo else linha)
    del lista[:-HISTORICO]
    if motivo:
        estado['total']['recusados'] += 1


def canal_de(destino, conf, prazo=saida.PRAZO):
    valores = segredos_de(destino)
    if not valores:
        raise saida.Falha('segredo')
    if tipo(destino) == 's3':
        return s3.Destino(conf, *valores, prazo=prazo)
    if tipo(destino) == 'rclone':
        if remoto_de(valores[0])[0] != conf['remoto']:
            raise saida.Falha('segredo')
        nome = nomes_dos_segredos(destino)[0]
        return rclone.Remoto(destino, valores[0], conf['caminho'], prazo, lambda texto: gravar_segredo(nome, texto.rstrip('\n')))
    return telegram.Bot(CFG['telegram_api'], *valores, prazo=prazo)


def passada(destino, conf, recentes=False, anunciados=None):
    """Envia o que chegou desde a última marca. Devolve o resumo; `motivo` vazio é passada completa. Com `recentes`,
    entram também os arquivos que ainda não assentaram (pedido pelo terminal); `anunciados` são os que chegaram
    inteiros e não precisam esperar. `esperando` conta os que ficaram para a passada seguinte."""
    estado = ler_estado(destino, conf)
    resumo = {'quando': int(time.time()), 'arquivos': 0, 'bytes': 0, 'apagados': 0, 'grandes': 0, 'ignorados': 0, 'erros': 0,
              'esperando': 0, 'motivo': ''}
    corte = time.time_ns() - (0 if recentes else ASSENTAR * 10**9)
    qual = tipo(destino)
    entregar = {'s3': entregar_s3, 'rclone': entregar_rclone, 'telegram': entregar_telegram}[qual]
    outros = outros_agora(destino) if qual == 's3' else ()
    canal, gravado = None, time.monotonic()
    ANDAMENTO[destino] = resumo
    if qual == 'telegram':
        idioma.usar(conf['idioma'])
    try:
        canal = canal_de(destino, conf)
        if qual == 's3':
            apagar_adiados(estado, resumo, outros)
        while True:
            conta = {'ignorados': 0}
            itens, esperando = escolher(conf, tuple(estado['marca']), corte, conta, anunciados)
            for item in itens:
                antes = (resumo['arquivos'], resumo['grandes'], resumo['ignorados'])
                try:
                    entregar(conf, canal, estado, item, resumo, outros)
                except saida.Falha as falha:
                    if not desistir(estado, item[1], falha.motivo):
                        raise
                    resumo['erros'] += 1
                    auditar('-', 'destino_pulado', f'destino={destino} arquivo={limpo(item[1], 200)} motivo={falha.motivo}')
                    anotar(estado, item, falha.motivo)
                else:
                    motivo = desfecho(qual, item[2], antes, resumo)
                    if motivo is not None:
                        anotar(estado, item, motivo)
                estado['marca'] = [item[0], item[1]]
                if qual == 'telegram' or time.monotonic() - gravado > GRAVAR_A_CADA:
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
    confs = {destino: ler(destino) for destino in todos()}
    operantes = [destino for destino, conf in confs.items() if conf and operante(destino, conf)]
    vez = {destino for destino in operantes
           if (destino in pedidos if pedidos is not None else na_hora(destino, confs[destino]))}
    # Antes de um S3 apagar o que gravou, os outros destinos da mesma pasta entregam o que falta: a passada deles vem junto.
    for destino in [destino for destino in vez if confs[destino].get('modo') == 'mover']:
        vez.update(outro for outro in operantes if cruzam(confs[outro]['pasta'], confs[destino]['pasta']))
    if not vez:
        return {}
    # Os bots, os remotos do rclone, os S3 que copiam e, por último, os que guardam: quem apaga encontra os outros já passados.
    ordem = sorted(vez, key=lambda destino: (TIPOS.index(tipo(destino)), confs[destino].get('modo') == 'mover',
                                             operantes.index(destino)))
    with uma_por_vez() as vaga:
        if not vaga:
            return None
        return {destino: passada(destino, confs[destino], recentes, chegadas.validos() if tipo(destino) == 'telegram' else None)
                for destino in ordem}


def pedir(destino):
    """Passada pedida pela tela: a linha de execução acorda e faz, sem esperar o intervalo."""
    with TRAVA_PEDIDOS:
        PEDIDOS.add(destino)
    ACORDAR.set()


def rodar():
    """Colhe os anúncios de chegada a cada COLHER segundos e faz as passadas: a pedida pela tela, a dos bots quando
    chega arquivo (`urgente`) ou quando o que estava à espera já assentou (`rever`), e a de quem está na hora."""
    conferido, urgente, rever, depois = time.monotonic(), 0.0, 0.0, False

    def volta(feitas):
        """A passada de um bot deixou arquivo à espera: a seguinte é quando ele assentar, e não só no intervalo."""
        espera = any(tipo(destino) == 'telegram' and conta.get('esperando') for destino, conta in (feitas or {}).items())
        return time.monotonic() + ASSENTAR + CALMA if espera else 0.0
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
            dos_bots = 0 < urgente <= agora or 0 < rever <= agora
            if dos_bots:
                pedidos.update(todos('telegram'))
            if pedidos or dos_bots:
                feitas = executar(pedidos)
                if feitas is None:
                    with TRAVA_PEDIDOS:
                        PEDIDOS.update(pedidos)   # o terminal está fazendo uma passada: o pedido fica para a volta seguinte
                    urgente, rever = 0.0, 0.0
                elif dos_bots or any(tipo(destino) == 'telegram' for destino in pedidos):
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
    """Grava um objeto de teste no S3, um arquivo de teste no remoto do rclone ou envia uma mensagem de teste pelo
    bot. Devolve '' quando deu certo, o motivo da falha ou 'ocupado' quando outro teste está em curso."""
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
            if tipo(destino) == 's3':
                chave = s3.chave_do_objeto(conf['prefixo'], 'allsafe-ftp-stack-teste.txt')
                canal.pedir('PUT', chave, corpo=f'Teste de gravação da allsafe-ftp-stack, em {time.strftime("%Y-%m-%d %H:%M:%S")}.\n'.encode())
            elif tipo(destino) == 'rclone':
                canal.testar()
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
    conf, chave, motivo, qual = ler(destino), None, '', tipo(destino)
    if not conf or not segredos_de(destino):
        motivo = 'segredo'
    elif qual == 'telegram':
        motivo = 'vazio' if not item[2] else 'limite' if item[2] > CFG['telegram_max'] else ''
    elif qual == 'rclone':
        chave = rclone.alvo_de(conf['caminho'], caminho)
        motivo = '' if chave is not None else 'nome'
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
            if qual == 'telegram':
                idioma.usar(conf['idioma'])
            canal = canal_de(destino, conf)
            if qual != 'telegram':
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
