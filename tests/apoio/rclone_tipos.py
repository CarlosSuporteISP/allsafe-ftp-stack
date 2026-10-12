#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Conferências da lista de tipos do destino rclone, para a etapa do rclone da bateria.

Roda na imagem do painel, em container sem rede, com o código do painel em /opt/painel e o rclone da imagem. Cada
modo imprime uma linha só, que começa por "certo:" ou por "ERRADO:"; a etapa compara a linha inteira com a esperada.

  consistencia  a lista do painel contra o que o próprio rclone declara (`rclone config providers`): os tipos existem,
                cada opção gravada existe no tipo dela, é cifrado o que o rclone cifra e só isso, as escolhas são as
                que o rclone lista, nenhuma opção de comando, arquivo local, proxy e afins está na lista, e todo tipo
                do rclone está na lista ou entre os deixados de fora. O rclone ignora, sem erro, opção que não
                conhece: sem esta conferência um nome errado passaria calado.
  adulterados   arquivos de remoto que o painel não gravaria: todos recusados, com o motivo `segredo`.
  rede          servidor escolhido pelo administrador em endereço interno: recusado antes de qualquer conexão. Só
                endereço IP, para nenhuma consulta de nome sair.
  motivo        a saída de erro do rclone com a chave na URL: dela só sai o motivo, em uma palavra. A chave de teste
                vem pela entrada padrão.

Uso: rclone_tipos.py <consistencia|adulterados|rede|motivo>
"""
import json
import re
import secrets
import subprocess
import sys

sys.path.insert(0, '/opt/painel')
import rclone  # noqa: E402
import saida  # noqa: E402

# Os tipos do rclone que não são destino do painel. Tipo novo numa atualização do rclone não está aqui nem na lista
# do painel, e a conferência falha até alguém decidir onde ele fica.
FORA = ('alias', 'union', 'combine', 'crypt', 'chunker', 'compress', 'hasher', 'cache', 'archive', 'local', 'memory',
        'http', 'doi', 'tardigrade', 's3', 'smb', 'hdfs', 'sia', 'gphotos', 'internetarchive', 'cloudinary',
        'imagekit', 'pikpak', 'internxt', 'iclouddrive', 'jottacloud', 'sugarsync', 'oos')
# Opção que roda comando, lê arquivo do servidor do painel, desvia a conexão ou desliga a conferência do certificado.
PROIBIDAS = re.compile(r'(?:^|_)(?:command|cmd)(?:$|_)|proxy|socks|_file$|_path$|^env_auth$|^auth_url$|^token_url$'
                       r'|^no_check_certificate$|^remote$|^upstreams$|^connection_string$|2fa|^ssh$')
INTERNOS = ('127.0.0.1', '0.0.0.0', '169.254.169.254', '::1', 'fe80::1', 'fd00:ec2::254')
DE_FORA = '203.0.113.5'


def fim(erros, texto):
    print(('ERRADO: ' + texto + ' | ' + '; '.join(erros[:8])) if erros else 'certo: ' + texto)
    return 1 if erros else 0


def consistencia():
    rclone.preparar()
    feito = subprocess.run([rclone.BINARIO, 'config', 'providers'], stdout=subprocess.PIPE,
                           stderr=subprocess.DEVNULL, env=rclone.AMBIENTE, cwd=rclone.PASTA_TRABALHO, timeout=60,
                           check=True)
    do_rclone = {tipo['Prefix']: {opcao['Name']: opcao for opcao in tipo['Options']}
                 for tipo in json.loads(feito.stdout)}
    erros = [f'tipo que o rclone não tem: {tipo}' for tipo in rclone.CAMPOS if tipo not in do_rclone]
    opcoes = conhecidas = campos = iguais = senhas = escolhas = dentro = sem_lista = no_rclone = na_lista = 0
    for tipo in rclone.CAMPOS:
        dele = do_rclone.get(tipo, {})
        fixos = [nome for nome, _ in rclone.FIXOS.get(tipo, ())] + (['tls'] if tipo == 'ftp' else [])
        nomes = [campo[0] for campo in rclone.CAMPOS[tipo]] + fixos
        no_rclone += sum(1 for nome in dele if PROIBIDAS.search(nome))
        for nome in nomes:
            opcoes += 1
            conhecidas += nome in dele
            if nome not in dele:
                erros.append(f'opção que o rclone não tem: {tipo}.{nome}')
            if PROIBIDAS.search(nome):
                na_lista += 1
                erros.append(f'opção proibida na lista: {tipo}.{nome}')
        for nome, forma, regra, _ in rclone.CAMPOS[tipo]:
            if nome not in dele:
                continue
            campos += 1
            senhas += forma == 'senha'
            if (forma == 'senha') == bool(dele[nome].get('IsPassword')):
                iguais += 1
            else:
                erros.append(f'cifrado de um lado só: {tipo}.{nome}')
            if forma != 'escolha':
                continue
            escolhas += 1
            if dele[nome].get('Type') == 'bool':
                aceitas = {'true', 'false'}
            else:
                aceitas = {str(exemplo['Value']) for exemplo in dele[nome].get('Examples') or ()}
            if not aceitas:
                sem_lista += 1
            elif set(regra) <= aceitas:
                dentro += 1
            else:
                erros.append(f'escolha que o rclone não lista: {tipo}.{nome}')
    lista, fora = set(rclone.CAMPOS), set(FORA)
    if lista & fora or lista | fora != set(do_rclone):
        erros.append('tipos sem lugar: ' + ' '.join(sorted((set(do_rclone) ^ (lista | fora)) | (lista & fora))))
    return fim(erros, f'tipos da lista no rclone: {len(lista & set(do_rclone))} de {len(lista)}; '
                      f'opções da lista que o rclone conhece: {conhecidas} de {opcoes}; '
                      f'campos cifrados só onde o rclone cifra: {iguais} de {campos}, {senhas} senhas; '
                      f'escolhas dentro do que o rclone lista: {dentro} de {escolhas - sem_lista}, '
                      f'{sem_lista} sem lista no rclone; '
                      f'opções de comando, arquivo local, proxy e afins nesses tipos: {no_rclone} no rclone, '
                      f'{na_lista} na lista; '
                      f'tipos do rclone: {len(do_rclone)} = {len(lista)} da lista + {len(fora)} de fora')


def sem(texto, *nomes):
    return ''.join(linha + '\n' for linha in texto.splitlines() if linha.split(' = ')[0] not in nomes)


def adulterados():
    senha = secrets.token_urlsafe(18)
    token = json.dumps({'access_token': secrets.token_hex(20), 'token_type': 'Bearer',
                        'expiry': '2030-01-01T00:00:00Z'})
    ftp = {'host': 'arquivos.example', 'user': 'u', 'pass': senha}

    def gravado(tipo, valores):
        return rclone.montar(tipo, rclone.do_formulario(tipo, valores))

    implicito = gravado('ftp', dict(ftp, explicit_tls='false'))
    explicito = gravado('ftp', dict(ftp, explicit_tls='true'))
    dropbox = gravado('dropbox', {'token': token})
    hidrive = gravado('hidrive', {'token': token})
    mega = gravado('mega', {'user': 'u@example.com', 'pass': senha})
    b2 = gravado('b2', {'account': '000aaaa', 'key': secrets.token_hex(20)})
    controles = (('FTP implícito', implicito), ('FTP explícito', explicito), ('Dropbox', dropbox),
                 ('HiDrive', hidrive), ('Mega', mega), ('Backblaze B2', b2))
    casos = [
        ('FTP implícito sem a linha do TLS', sem(implicito, 'tls')),
        ('FTP com o TLS desligado', implicito.replace('tls = true', 'tls = false')),
        ('FTP sem TLS nenhum', sem(implicito, 'tls', 'explicit_tls')),
        ('FTP com os dois TLS', explicito + 'tls = true\n'),
        ('FTP sem conferir o certificado', implicito + 'no_check_certificate = true\n'),
        ('FTP por proxy', implicito + 'socks_proxy = 127.0.0.1:1\n'),
        ('FTP com a senha em texto', re.sub(r'(?m)^pass = .*$', 'pass = abc', implicito)),
        ('seção com outro nome', implicito.replace(f'[{rclone.SECAO}]', '[outro]')),
        ('segunda seção', implicito + '[outro]\ntype = local\n'),
        ('Mega com código de uso único', mega + '2fa = 123456\n'),
        ('Mega sem o HTTPS que o painel fixa', sem(mega, 'use_https')),
        ('Mega com o HTTPS desligado', mega.replace('use_https = true', 'use_https = false')),
        ('Dropbox com outro pedaço', dropbox.replace('chunk_size = 8Mi', 'chunk_size = 1Ki')),
        ('HiDrive sem o que o painel fixa', sem(hidrive, 'chunk_size', 'upload_concurrency')),
        ('Backblaze B2 com mais pedaços ao mesmo tempo', b2.replace('upload_concurrency = 1',
                                                                    'upload_concurrency = 64')),
    ]
    casos += [(f'tipo trocado por {tipo}', implicito.replace('type = ftp', f'type = {tipo}'))
              for tipo in ('http', 'local', 'alias', 'crypt', 's3', 'smb', 'sftp')]
    erros, aceitos, recusados = [], 0, 0
    for nome, texto in controles:
        try:
            rclone.analisar(texto)
            aceitos += 1
        except saida.Falha:
            erros.append(f'controle recusado: {nome}')
    for nome, texto in casos:
        try:
            rclone.analisar(texto)
            erros.append(f'aceito: {nome}')
        except saida.Falha as falha:
            if str(falha) == 'segredo':
                recusados += 1
            else:
                erros.append(f'outro motivo: {nome}')
    return fim(erros, f'arquivos que o painel grava, aceitos (controle): {aceitos} de {len(controles)}; '
                      f'adulterados recusados com o motivo segredo: {recusados} de {len(casos)}')


def no_formato(regra, endereco):
    if regra is rclone.URL:
        return f'https://{endereco}/'
    if regra is rclone.URL_SAS:
        return f'https://{endereco}/?sv=2022-11-02&sig=xxxxxxxx'
    if regra is rclone.NOME_E_PASTA:
        return f'{endereco}/1/pasta'
    return endereco


def rede():
    erros, tipos, campos, recusados, tentados, formato, aceitos = [], set(), 0, 0, 0, 0, 0
    for tipo in rclone.CAMPOS:
        for nome, _, regra, marcas in rclone.CAMPOS[tipo]:
            if 'r' not in marcas:
                continue
            tipos.add(tipo)
            campos += 1
            try:
                rclone.conferir_rede(tipo, {nome: no_formato(regra, DE_FORA)})
                aceitos += 1
            except saida.Falha:
                erros.append(f'controle recusado: {tipo}.{nome}')
            for endereco in INTERNOS:
                valor = no_formato(regra, endereco)
                if not regra.fullmatch(valor):
                    formato += 1        # o campo nem aceita o endereço escrito assim: a tela recusa antes
                    continue
                tentados += 1
                try:
                    rclone.conferir_rede(tipo, {nome: valor})
                    erros.append(f'aceito: {tipo}.{nome} {endereco}')
                except saida.Falha as falha:
                    if str(falha) == 'endereco':
                        recusados += 1
                    else:
                        erros.append(f'outro motivo: {tipo}.{nome} {endereco}')
    return fim(erros, f'tipos com servidor escolhido pelo administrador: {len(tipos)}, em {campos} campos; '
                      f'endereço interno recusado com o motivo endereco: {recusados} de {tentados}; '
                      f'endereço interno que o campo nem aceita: {formato}; '
                      f'endereço de fora aceito (controle): {aceitos} de {campos}')


def motivo():
    chave = sys.stdin.read().strip()
    erros = [] if len(chave) >= 12 else ['chave de teste curta']
    possiveis = {nome for nome, _ in rclone.MOTIVOS} | {'rclone'}
    exemplos = (
        f'ERROR : x.txt: Post "https://api.example/pasta?apikey={chave}": dial tcp: lookup api.example: no such host',
        f'ERROR : x.txt: Get "https://api.example/upload?key={chave}&pwd={chave}": dial tcp: i/o timeout',
        json.dumps({'level': 'error', 'msg': f'Post "https://api.example/?token={chave}": 403 Forbidden'}),
        chave,
    )
    achados = [rclone.motivo_de(exemplo.encode('utf-8')) for exemplo in exemplos]
    erros += [f'motivo fora da lista no exemplo {n}' for n, achado in enumerate(achados, 1) if achado not in possiveis]
    erros += [f'chave no motivo do exemplo {n}' for n, achado in enumerate(achados, 1) if chave and chave in achado]
    return fim(erros, f'erros do rclone com a chave na URL: {len(exemplos)}; motivos: {" ".join(achados)}; '
                      f'a chave em nenhum deles')


MODOS = {'consistencia': consistencia, 'adulterados': adulterados, 'rede': rede, 'motivo': motivo}

if __name__ == '__main__':
    if len(sys.argv) != 2 or sys.argv[1] not in MODOS:
        sys.exit(__doc__.strip().splitlines()[-1])
    sys.exit(MODOS[sys.argv[1]]())
