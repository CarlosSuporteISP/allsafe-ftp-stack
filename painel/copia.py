# SPDX-License-Identifier: Apache-2.0
"""Cópia do sistema inteiro para um armazenamento S3, feita pelo próprio painel.

O administrador escolhe na aba Destinos um S3 já gravado, a pasta do bucket e a rotina (de quantos em quantos dias e a
que horas); o botão da tela, a rotina e o terminal (servidor.py --copia enviar) fazem a mesma coisa. Quem copia é um
processo à parte, com a prioridade mais baixa, para o painel continuar atendendo: o processo do painel só o dispara.

A cópia tem o formato da que o scripts/backup.sh grava, e o scripts/restaurar.sh a abre sem mudança: um tar.gz com as
pastas auth, dados, certs e painel, cifrado com a chave pública da cópia (age). O tar sai direto para o age e do age
para o destino: nada sem cifra chega ao disco, e da cópia cifrada só uma parte por vez fica em um arquivo sem nome de
/painel/destinos, até o destino confirmar a gravação dela. O objeto só passa a existir no destino depois de a cópia
inteira ter saído sem erro: uma falha em qualquer ponto (leitura, cifra, rede) desfaz o envio em partes. Depois do
objeto vai o <nome>.sha256, com a soma do que foi enviado.

Nada é apagado no destino: as cópias se acumulam lá, e quem cuida do prazo delas é a regra do bucket. O .env e os
segredos da instalação não entram na cópia, como no backup.sh.
"""
import contextlib
import errno
import fcntl
import gzip
import hashlib
import json
import os
import re
import resource
import stat
import subprocess
import sys
import tarfile
import tempfile
import threading
import time

import destinos
import s3
import saida
from auditoria import auditar, limpo
from config import CFG, PASTA_DADOS, PASTA_DESTINOS

ARQ_CONF = os.path.join(PASTA_DESTINOS, 'copia.conf')
ARQ_ESTADO = os.path.join(PASTA_DESTINOS, 'copia.estado')
ARQ_TRAVA = os.path.join(PASTA_DESTINOS, '.trava-copia')
ARQ_CHAVE = '/run/secrets/backup_chave_publica'   # com ela só se cifra: a chave que abre a cópia não chega ao painel
ARQ_TRAVA_CADASTRO = '/auth/.lock'                # a trava de quem altera usuário (allsafe-ftp-user e backup.sh)
# O nome de cada pasta dentro da cópia e de onde ela vem, na ordem do backup.sh.
PASTAS = (('auth', '/auth'), ('dados', PASTA_DADOS), ('certs', '/certs'), ('painel', '/painel'))
# O andamento e a trava são da cópia que está sendo feita, e não do sistema: restaurados, diriam que ela foi interrompida.
SO_DELA = ('painel/destinos/copia.estado', 'painel/destinos/.trava-copia')
CHAVE = re.compile(r'age1[0-9a-z]{58}')
HORA = re.compile(r'([01][0-9]|2[0-3]):([0-5][0-9])')
DIAS_MAX = 30                # o maior espaço entre uma cópia da rotina e a seguinte; 0 é só pelo botão
ESPERA_CADASTRO = 30         # segundos à espera de quem está alterando usuário
MARGEM = 64 * 1024 * 1024    # espaço que tem de sobrar no disco além da parte que está sendo montada
CONFERIR = 60                # segundos entre uma conferência da rotina e a seguinte
ABRIR = os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC | os.O_NONBLOCK
ORIGENS = ('tela', 'rotina', 'terminal')


# ------------------------------------------------------------ configuração e andamento

def defeito(conf):
    """O nome do primeiro campo que não serve, ou '' quando a configuração está inteira."""
    try:
        if not (destinos.valido(conf['destino']) and destinos.tipo(conf['destino']) == 's3'):
            return 'destino'
        if conf['prefixo'] and not (len(conf['prefixo']) <= 255 and s3.PREFIXO.fullmatch(conf['prefixo'])):
            return 'prefixo'
        if type(conf['dias']) is not int or not 0 <= conf['dias'] <= DIAS_MAX:
            return 'dias'
        return '' if HORA.fullmatch(conf['hora']) else 'hora'
    except (KeyError, TypeError):
        return 'destino'


def ler():
    """A configuração gravada da cópia, ou None quando não há (ou o arquivo não serve)."""
    try:
        with open(ARQ_CONF, encoding='utf-8') as arq:
            conf = json.loads(arq.read(4096))
    except (OSError, ValueError):
        return None
    return conf if isinstance(conf, dict) and not defeito(conf) and type(conf.get('desde')) is int else None


def gravar(conf):
    """Grava a configuração. A rotina vale da gravação em diante: a hora que já passou hoje não dispara cópia."""
    destinos.gravar_texto(ARQ_CONF, json.dumps({**conf, 'desde': int(time.time())}, sort_keys=True) + '\n')


def esquecer(destino):
    """O destino foi removido: se era o da cópia, ela fica sem configuração e a rotina para. Diz se era."""
    conf = ler()
    if not conf or conf['destino'] != destino:
        return False
    destinos.apagar(ARQ_CONF)
    return True


def ler_estado():
    novo = {'tentativa': 0, 'feita': 0, 'ultima': {}, 'andamento': {}}
    try:
        with open(ARQ_ESTADO, encoding='utf-8') as arq:
            lido = json.loads(arq.read(65536))
        if (type(lido['tentativa']) is int and type(lido['feita']) is int and isinstance(lido['ultima'], dict)
                and isinstance(lido['andamento'], dict)):
            return {chave: lido[chave] for chave in novo}
    except (OSError, ValueError, KeyError, TypeError):
        pass
    return novo


def gravar_estado(estado):
    destinos.gravar_texto(ARQ_ESTADO, json.dumps(estado, ensure_ascii=False) + '\n')


def chave_publica():
    """A chave pública da cópia, ou '' quando o arquivo não existe ou não traz uma chave do age."""
    try:
        with open(ARQ_CHAVE, encoding='ascii') as arq:
            linha = arq.readline(256).strip()
    except (OSError, ValueError):
        return ''
    return linha if CHAVE.fullmatch(linha) else ''


@contextlib.contextmanager
def uma_por_vez(esperar=0):
    """Só uma cópia por vez, entre o botão, a rotina e o terminal. Entrega se conseguiu a vez."""
    descritor = os.open(ARQ_TRAVA, os.O_RDWR | os.O_CREAT | os.O_CLOEXEC, 0o600)
    try:
        limite = time.monotonic() + esperar
        while True:
            try:
                fcntl.flock(descritor, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except OSError:
                if time.monotonic() >= limite:
                    yield False
                    return
                time.sleep(0.2)
        yield True
    finally:
        os.close(descritor)


def em_curso():
    """Há uma cópia sendo feita agora? Quem responde é a trava, que o processo da cópia segura do começo ao fim."""
    try:
        descritor = os.open(ARQ_TRAVA, os.O_RDWR | os.O_CREAT | os.O_CLOEXEC, 0o600)
    except OSError:
        return False
    try:
        fcntl.flock(descritor, fcntl.LOCK_SH | fcntl.LOCK_NB)
    except OSError:
        return True
    finally:
        os.close(descritor)
    return False


def situacao():
    """O que a tela e o terminal mostram: a configuração, o destino dela, a última cópia e a que está em curso."""
    conf, estado, andando = ler(), ler_estado(), em_curso()
    dele = destinos.ler(conf['destino']) if conf else None
    return {'conf': conf, 'destino': dele, 'segredos': bool(conf and destinos.segredos_de(conf['destino'])),
            'chave': bool(chave_publica()), 'ultima': estado['ultima'], 'andamento': estado['andamento'] if andando else {},
            # O andamento que ficou gravado sem cópia em curso é de uma cópia que o reinício do painel interrompeu.
            'interrompida': bool(estado['andamento']) and not andando}


def impedimento():
    """Por que a cópia não pode sair agora, em uma palavra; '' quando pode."""
    conf = ler()
    if not conf or not destinos.ler(conf['destino']):
        return 'sem_destino'
    if not destinos.segredos_de(conf['destino']):
        return 'segredo'
    return '' if chave_publica() else 'chave'


# ------------------------------------------------------------ o pacote

def ficha(nome, visto, tipo, alvo=''):
    """A entrada do tar, com o dono em número: é o que o --numeric-owner do backup.sh grava."""
    entrada = tarfile.TarInfo(nome)
    entrada.type, entrada.linkname = tipo, alvo
    entrada.mode = stat.S_IMODE(visto.st_mode)
    entrada.uid, entrada.gid = visto.st_uid, visto.st_gid
    entrada.mtime = int(visto.st_mtime)
    entrada.size = visto.st_size if tipo == tarfile.REGTYPE else 0
    return entrada


class Inteiro:
    """Entrega exatamente o tamanho que a ficha anunciou. O arquivo que encolheu enquanto era lido é completado com
    zeros, como faz o tar: a cópia continua bem formada, e o arquivo entra na conta dos que mudaram."""

    def __init__(self, descritor, falta):
        self.descritor, self.falta, self.curto = descritor, falta, False

    def read(self, quanto):
        quanto = min(quanto, self.falta)
        if quanto <= 0:
            return b''
        bloco = b'' if self.curto else os.read(self.descritor, quanto)
        if not bloco:
            self.curto, bloco = True, bytes(quanto)
        self.falta -= len(bloco)
        return bloco


def arquivo_comum(tar, pasta, nome, caminho, resumo):
    try:
        descritor = os.open(nome, ABRIR, dir_fd=pasta)
    except OSError as erro:
        if erro.errno in (errno.ENOENT, errno.ELOOP, errno.ENXIO):
            return   # saiu, ou foi trocado por outra coisa, entre a listagem e a abertura
        raise
    try:
        visto = os.fstat(descritor)
        if not stat.S_ISREG(visto.st_mode):
            resumo['fora'] += 1
            return
        origem = Inteiro(descritor, visto.st_size)
        tar.addfile(ficha(caminho, visto, tarfile.REGTYPE), origem)
        resumo['arquivos'] += 1
        resumo['mudaram'] += origem.curto
    finally:
        os.close(descritor)


def conteudo(tar, descritor, caminho, resumo):
    """Empacota os arquivos e os links de uma pasta e devolve o nome das pastas de dentro dela."""
    pastas = []
    with os.scandir(descritor) as itens:
        for item in itens:
            try:
                visto = item.stat(follow_symlinks=False)
            except FileNotFoundError:
                continue
            dentro = f'{caminho}/{item.name}'
            if dentro in SO_DELA:
                continue
            if stat.S_ISDIR(visto.st_mode):
                pastas.append(item.name)
            elif stat.S_ISREG(visto.st_mode):
                arquivo_comum(tar, descritor, item.name, dentro, resumo)
            elif stat.S_ISLNK(visto.st_mode):
                with contextlib.suppress(FileNotFoundError):
                    tar.addfile(ficha(dentro, visto, tarfile.SYMTYPE, os.readlink(item.name, dir_fd=descritor)))
            else:
                resumo['fora'] += 1   # soquete, fila e dispositivo não entram, como no tar
    return pastas


def empacotar_pasta(tar, raiz, nome, resumo):
    """Uma pasta inteira, pelo descritor de cada nível: o link simbólico entra como link e nunca é seguido. Não há
    chamada dentro de chamada: a profundidade da árvore é a dos descritores abertos, e não a da pilha do Python."""
    pilha = [(os.open(raiz, ABRIR | os.O_DIRECTORY), nome, None)]
    try:
        while pilha:
            descritor, caminho, falta = pilha[-1]
            if falta is None:
                tar.addfile(ficha(caminho, os.fstat(descritor), tarfile.DIRTYPE))
                falta = conteudo(tar, descritor, caminho, resumo)
                pilha[-1] = (descritor, caminho, falta)
            if not falta:
                os.close(descritor)
                pilha.pop()
                continue
            filha = falta.pop()
            try:
                pilha.append((os.open(filha, ABRIR | os.O_DIRECTORY, dir_fd=descritor), f'{caminho}/{filha}', None))
            except OSError as erro:
                if erro.errno not in (errno.ENOENT, errno.ELOOP, errno.ENOTDIR):
                    raise
    finally:
        for descritor, _, _ in pilha:
            os.close(descritor)


@contextlib.contextmanager
def cadastro_parado():
    """A trava dos usuários, em modo de leitura: a lista entra inteira na cópia, e quem altera usuário espera só o
    tempo de a pasta auth ser lida."""
    try:
        descritor = os.open(ARQ_TRAVA_CADASTRO, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
    except FileNotFoundError:
        yield
        return
    try:
        limite = time.monotonic() + ESPERA_CADASTRO
        while True:
            try:
                fcntl.flock(descritor, fcntl.LOCK_SH | fcntl.LOCK_NB)
                break
            except OSError:
                if time.monotonic() >= limite:
                    raise saida.Falha('cadastro') from None
                time.sleep(0.2)
        yield
    finally:
        os.close(descritor)


def empacotar(cano, resumo, erros):
    """A linha de execução que escreve o tar.gz na entrada do age. O que der errado fica em `erros`, em uma palavra:
    quem envia só conclui o objeto com a lista vazia."""
    try:
        with gzip.GzipFile(fileobj=cano, mode='wb', compresslevel=1, mtime=0) as comprimido, \
                tarfile.open(fileobj=comprimido, mode='w|', format=tarfile.GNU_FORMAT, encoding='utf-8',
                             errors='surrogateescape', bufsize=saida.BLOCO) as tar:
            tar.copybufsize = saida.BLOCO
            try:
                for nome, raiz in PASTAS:
                    if nome == 'auth':
                        with cadastro_parado():
                            empacotar_pasta(tar, raiz, nome, resumo)
                    elif os.path.isdir(raiz):
                        empacotar_pasta(tar, raiz, nome, resumo)
            except BaseException as erro:
                erros.append(erro.motivo if isinstance(erro, saida.Falha) else
                             'cifra' if isinstance(erro, BrokenPipeError) else
                             'profundo' if isinstance(erro, OSError) and erro.errno == errno.EMFILE else
                             'arquivo' if isinstance(erro, OSError) else 'interno')
                raise
    except BaseException:   # o motivo já está em `erros`; o que sobra é o fechamento de um cano que quebrou
        if not erros:
            erros.append('cifra')
    finally:
        with contextlib.suppress(OSError):
            cano.close()


# ------------------------------------------------------------ o envio

def tamanho_da_parte():
    """O tamanho de cada parte: o que os discos das pastas têm em uso é o teto do que a cópia pode ter, e ele tem de
    caber no número de partes que o protocolo aceita."""
    discos, usado = set(), 0
    for _, raiz in PASTAS:
        try:
            disco = os.stat(raiz).st_dev
            if disco not in discos:
                discos.add(disco)
                espaco = os.statvfs(raiz)
                usado += (espaco.f_blocks - espaco.f_bfree) * espaco.f_frsize
        except OSError:
            continue
    parte = max(s3.PARTE_MIN, min(usado, s3.OBJETO_MAX) // s3.PARTES_MAX + 1)
    livre = os.statvfs(PASTA_DESTINOS)
    if livre.f_bavail * livre.f_frsize < parte + MARGEM:
        raise saida.Falha('espaco')
    return parte


def transmitir(canal, chave, destinatario, resumo, ao_andar):
    """tar ➜ gzip ➜ age ➜ partes ➜ destino. Devolve a soma SHA-256 do que foi enviado."""
    parte, soma, erros = tamanho_da_parte(), hashlib.sha256(), []
    # O age herda a prioridade baixa deste processo; duas linhas de execução bastam para ele.
    try:
        age = subprocess.Popen(['age', '-r', destinatario], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.DEVNULL, env={'PATH': '/usr/bin:/bin', 'GOMAXPROCS': '2'})
    except OSError:
        raise saida.Falha('cifra') from None
    empacotador = threading.Thread(target=empacotar, args=(age.stdin, resumo, erros), name='empacotar', daemon=True)
    empacotador.start()
    try:
        with tempfile.TemporaryFile(dir=PASTA_DESTINOS) as guardada:
            def trechos():
                fim = False
                while not fim:
                    guardada.seek(0)
                    guardada.truncate()
                    quanto = 0
                    while quanto < parte:
                        bloco = age.stdout.read(min(saida.BLOCO, parte - quanto))
                        if not bloco:
                            fim = True
                            break
                        guardada.write(bloco)
                        soma.update(bloco)
                        quanto += len(bloco)
                    guardada.flush()
                    if fim:
                        # Antes da última parte: o pacote saiu inteiro e a cifra terminou bem? Senão o envio é desfeito.
                        empacotador.join()
                        if erros or age.wait() != 0:
                            raise saida.Falha(erros[0] if erros else 'cifra')
                        if not quanto:
                            if not resumo['partes']:
                                raise saida.Falha('cifra')
                            return   # a cópia terminou junto com a parte anterior
                    yield guardada.fileno(), 0, quanto
                    resumo['bytes'] += quanto
                    resumo['partes'] += 1
                    ao_andar()
            canal.em_partes(chave, trechos())
    finally:
        if age.poll() is None:
            age.kill()
        age.stdout.close()
        empacotador.join()
        age.wait()
    return soma.hexdigest()


def fazer(origem):
    inicio = int(time.time())
    resumo = {'quando': inicio, 'fim': 0, 'origem': origem, 'motivo': '', 'objeto': '', 'lugar': '', 'bytes': 0, 'partes': 0,
              'arquivos': 0, 'mudaram': 0, 'fora': 0, 'sha256': ''}
    estado = ler_estado()
    if origem == 'rotina':
        estado['tentativa'] = inicio

    def ao_andar():
        estado['andamento'] = {chave: resumo[chave] for chave in ('quando', 'bytes', 'partes', 'arquivos')}
        gravar_estado(estado)

    try:
        ao_andar()
        conf = ler()
        dele = destinos.ler(conf['destino']) if conf else None
        if not dele:
            raise saida.Falha('sem_destino')
        destinatario = chave_publica()
        if not destinatario:
            raise saida.Falha('chave')
        nome = f'{CFG["stack"]}-{time.strftime("%Y%m%d-%H%M%S", time.localtime(inicio))}.tar.gz.age'
        chave = s3.chave_do_objeto(conf['prefixo'], nome)
        if not chave:
            raise saida.Falha('limite')
        resumo['lugar'] = f'{conf["destino"]}:{dele["bucket"]}/{chave}'
        canal = destinos.canal_de(conf['destino'], dele)
        try:
            resumo['sha256'] = transmitir(canal, chave, destinatario, resumo, ao_andar)
            resumo['objeto'] = nome
            try:
                canal.pedir('PUT', chave + '.sha256', corpo=f'{resumo["sha256"]}  {nome}\n'.encode('ascii'))
            except saida.Falha:
                # O objeto está inteiro no destino, mas sem o arquivo da soma quem restaura não tem como conferi-lo: não conta como feita.
                raise saida.Falha('soma') from None
        finally:
            canal.fechar()
    except saida.Falha as falha:
        resumo['motivo'] = falha.motivo
    except OSError as erro:
        resumo['motivo'] = 'espaco' if erro.errno == errno.ENOSPC else 'disco'
    except Exception as erro:   # o que não foi previsto também fica registrado como falha, e não some com o processo
        resumo['motivo'] = 'interno'
        print(f'cópia do sistema: {type(erro).__name__}', file=sys.stderr, flush=True)
    resumo['fim'] = int(time.time())
    estado['ultima'], estado['andamento'] = resumo, {}
    if not resumo['motivo']:
        estado['feita'] = resumo['fim']
    with contextlib.suppress(OSError):   # sem disco para o andamento, o registro de atividade ainda diz o que houve
        gravar_estado(estado)
    if resumo['motivo']:
        auditar('-', 'copia_falhou', f'origem={origem} motivo={limpo(resumo["motivo"], 40)} partes={resumo["partes"]}')
    else:
        auditar('-', 'copia_enviada', f'origem={origem} destino={conf["destino"]} objeto={limpo(chave, 300)} '
                f'bytes={resumo["bytes"]} partes={resumo["partes"]} arquivos={resumo["arquivos"]} '
                f'mudaram={resumo["mudaram"]} fora={resumo["fora"]}')
    return resumo


def enviar(origem='terminal'):
    """Faz a cópia agora, neste processo. Devolve o resumo: `motivo` vazio é cópia gravada no destino, e `copiando` é
    outra cópia em andamento (que não é mexida)."""
    with contextlib.suppress(OSError, ValueError):
        os.nice(19)
    with contextlib.suppress(OSError, ValueError):
        # Um descritor por nível de pasta aberto: a árvore funda não pode parar no limite de arquivos abertos.
        teto = resource.getrlimit(resource.RLIMIT_NOFILE)[1]
        resource.setrlimit(resource.RLIMIT_NOFILE, (min(teto, 65536), teto))
    with uma_por_vez(esperar=2) as vez:
        if not vez:
            return {'motivo': 'copiando'}
        return fazer(origem if origem in ORIGENS else 'terminal')


# ------------------------------------------------------------ o disparo e a rotina

def disparar(origem):
    """Começa a cópia em um processo à parte e volta na hora. Devolve o motivo de não ter começado, ou ''."""
    motivo = impedimento() or ('copiando' if em_curso() else '')
    if motivo:
        return motivo
    try:
        filho = subprocess.Popen([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'servidor.py'),
                                  '--copia', 'enviar'], stdin=subprocess.DEVNULL,
                                 env={**os.environ, 'PAINEL_COPIA_ORIGEM': origem})   # a saída é a do painel: o registro do container
    except OSError:
        return 'interno'
    threading.Thread(target=filho.wait, name='copia-espera', daemon=True).start()
    return ''


def marco(hora, agora):
    """O instante mais recente em que o relógio do servidor marcou `hora` (HH:MM)."""
    horas, minutos = (int(parte) for parte in HORA.fullmatch(hora).groups())
    hoje = time.localtime(agora)
    for dia in (hoje.tm_mday, hoje.tm_mday - 1):
        instante = int(time.mktime((hoje.tm_year, hoje.tm_mon, dia, horas, minutos, 0, 0, 0, -1)))
        if instante <= agora:
            return instante
    return 0


def na_hora(conf, estado, agora):
    """A rotina deve copiar agora? Uma tentativa por dia, na hora marcada, quando a última cópia que deu certo (por
    qualquer caminho) já tem o número de dias da rotina. A cópia que falha é tentada de novo no dia seguinte."""
    if not conf['dias']:
        return False
    ultimo = marco(conf['hora'], agora)
    return ultimo >= conf['desde'] and estado['tentativa'] < ultimo and estado['feita'] < ultimo - (conf['dias'] - 1) * 86400


def rodar():
    disparado = 0
    while True:
        time.sleep(CONFERIR)
        try:
            conf, agora = ler(), int(time.time())
            if not conf or not na_hora(conf, ler_estado(), agora) or marco(conf['hora'], agora) == disparado:
                continue
            motivo = disparar('rotina')
            if motivo == 'copiando':
                continue   # o botão ou o terminal está copiando: a rotina confere de novo quando ele terminar
            disparado = marco(conf['hora'], agora)
            if motivo:
                auditar('-', 'copia_falhou', f'origem=rotina motivo={motivo} partes=0')
        except Exception as erro:   # uma conferência que falha não acaba com as seguintes
            auditar('-', 'copia_falhou', f'origem=rotina motivo={type(erro).__name__} partes=0')


def iniciar():
    """Começa a rotina da cópia. Só o servidor do painel chama, e só com os destinos ligados."""
    if CFG['destinos']:
        threading.Thread(target=rodar, name='copia', daemon=True).start()
