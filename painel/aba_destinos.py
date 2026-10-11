# SPDX-License-Identifier: Apache-2.0
"""Aba Destinos: o administrador liga a pasta dos dados a um armazenamento S3 e a um bot do Telegram.

A tela grava a configuração e os segredos de cada destino, pede um teste e pede uma passada fora de hora; quem envia
é destinos.py. Só o administrador chega aqui, e gravar ou remover pede de novo a senha dele (confirmacao.py).

Nenhum segredo volta para a tela: a chave de acesso, a chave secreta, o token do bot e a identificação da conversa
são campos só de escrita, e o que a tela diz deles é se estão gravados. Campo de segredo em branco mantém o gravado.
Da resposta do serviço de fora a tela mostra só o motivo, em uma frase do próprio painel.

Com PAINEL_DESTINOS=nao a aba não existe: sai do menu e toda rota dela responde como caminho desconhecido.
"""
import functools
import re

import aba_arquivos
import destinos
import idioma
from auditoria import auditar, limpo
from config import CFG
from confirmacao import campo_senha_atual, confirmacao_recusada
from icones import icone
from idioma import N, t, tn
from pagina import cabeca, e, pagina, quando, tamanho

ABA = '/destinos'
TITULOS = {'s3': N('Armazenamento S3'), 'telegram': N('Bot do Telegram')}
DESENHOS = {'s3': 'nuvem', 'telegram': 'aviao'}
MENSAGENS = {'gravado': N('Destino gravado. Vale a partir da próxima passada.'),
             'removido': N('Destino removido: a configuração e os segredos dele foram apagados.'),
             'teste': N('Teste concluído: o destino recebeu.'),
             'pedido': N('Passada pedida: o painel começa em instantes. Atualize a tela para acompanhar.')}
# O botão de cada destino na linha de um arquivo da aba Arquivos: o nome curto e a dica.
NA_LINHA = {'telegram': ('Telegram', N('Enviar este arquivo pelo bot do Telegram')),
            's3': ('S3', N('Enviar este arquivo para o armazenamento S3'))}
# Motivo de uma falha, como destinos.py e saida.py registram ➜ a frase que a tela mostra.
MOTIVOS = {
    'dns': N('o nome do endereço não foi encontrado'),
    'endereco': N('o endereço não é aceito pelo painel, ou o serviço mandou o pedido para outro endereço'),
    'conexao': N('não foi possível conectar ao serviço'),
    'tls': N('o certificado do serviço não foi aceito'),
    'tempo': N('o serviço não respondeu a tempo'),
    'resposta': N('a resposta do serviço não foi entendida'),
    'recusado': N('o serviço recusou a credencial ou a permissão'),
    'nao_encontrado': N('o bucket ou a conversa não existe para esta credencial'),
    'limite': N('o arquivo é maior do que o serviço aceita'),
    'arquivo': N('um arquivo não pôde ser lido'),
    'pasta': N('a pasta escolhida não existe mais dentro dos dados'),
    'segredo': N('faltam os segredos do destino: grave-os de novo'),
    'espera': N('o S3 espera o bot do Telegram entregar o que falta antes de apagar mais arquivos'),
    'ocupado': N('outro teste está em andamento: tente de novo em instantes'),
    'vazio': N('o arquivo está vazio, e o bot não envia arquivo vazio'),
    'nome': N('o nome do arquivo não cabe no destino'),
    'mudou': N('o arquivo mudou durante o envio: repita quando ele terminar de chegar'),
    'enviando': N('outro envio pedido pela tela está em andamento: tente de novo em instantes'),
    'desligado': N('o destino está desligado ou sem os segredos'),
}
# Campo que destinos.defeito() aponta ➜ o erro que o formulário mostra.
ERROS = {
    'situacao': N('Formulário incompleto: abra a tela de novo.'),
    'endpoint': N('Endereço inválido: use https://nome ou https://nome:porta, em minúsculas e sem caminho.'),
    'regiao': N('Região inválida: letras minúsculas, números e hífen, até 32 caracteres.'),
    'bucket': N('Bucket inválido: de 3 a 63 caracteres, com letras minúsculas, números, ponto e hífen.'),
    'prefixo': N('Prefixo inválido: até 8 níveis separados por barra, com letras, números, _, - e ponto.'),
    'estilo': N('Escolha a forma do endereço do bucket.'),
    'modo': N('Escolha o que acontece com o arquivo depois do envio.'),
    'pasta': N('Pasta inválida: até 4 níveis separados por barra, com letras, números, _, - e ponto.'),
    'intervalo': N('Intervalo inválido: de 5 a 1440 minutos.'),
    'idioma': N('Idioma não aceito.'),
}


def ligada(funcao):
    """Com PAINEL_DESTINOS=nao, a rota responde como caminho desconhecido."""
    @functools.wraps(funcao)
    def rota(pedido, sessao, consulta, formulario=None, token=None, **mais):
        if not CFG['destinos']:
            return pedido.enviar(404, pagina(t('Não encontrado'), f'<section class="cartao"><h1>{t("Página não encontrada")}</h1>'
                                             f'<p><a href="/">{t("Voltar ao painel")}</a></p></section>', sessao))
        return funcao(pedido, sessao, consulta, formulario, token, **mais)
    return rota


def explicar(motivo):
    if motivo in MOTIVOS:
        return t(MOTIVOS[motivo])
    if re.fullmatch(r'http_[0-9]{3}', motivo):
        return t('o serviço respondeu com o código {codigo}', codigo=motivo[5:])
    return t('falha não identificada')


def inteiro(dados, chave):
    valor = dados.get(chave, 0)
    return valor if type(valor) is int and valor >= 0 else 0


def pasta_enviada(conf):
    return f'<code>{e(conf["pasta"])}</code>' if conf['pasta'] else t('toda a pasta dos dados')


def a_cada(conf):
    return tn(conf['intervalo'], 'a cada {n} minuto', 'a cada {n} minutos')


# ------------------------------------------------------------ a tela dos dois destinos

def etiqueta(visto):
    conf = visto['conf']
    if not conf:
        return f'<span class="etiqueta">{t("não configurado")}</span>'
    if not visto['segredos']:
        return f'<span class="etiqueta atencao">{t("faltam os segredos")}</span>'
    return f'<span class="etiqueta">{t("ligado") if conf["ligado"] else t("desligado")}</span>'


def numeros(conta):
    """O que uma passada fez, em uma linha: só o que não é zero, depois dos arquivos enviados."""
    itens = [tn(inteiro(conta, 'arquivos'), '{n} arquivo enviado', '{n} arquivos enviados')]
    if inteiro(conta, 'bytes'):
        itens.append(e(tamanho(inteiro(conta, 'bytes'))))
    if inteiro(conta, 'apagados'):
        itens.append(tn(inteiro(conta, 'apagados'), '{n} apagado do servidor', '{n} apagados do servidor'))
    if inteiro(conta, 'grandes'):
        itens.append(tn(inteiro(conta, 'grandes'), '{n} acima do limite do bot (foi só o aviso)',
                        '{n} acima do limite do bot (foi só o aviso)'))
    if inteiro(conta, 'ignorados'):
        itens.append(tn(inteiro(conta, 'ignorados'), '{n} ignorado', '{n} ignorados'))
    if inteiro(conta, 'erros'):
        itens.append(tn(inteiro(conta, 'erros'), '{n} recusado pelo destino', '{n} recusados pelo destino'))
    return ' · '.join(itens)


def passadas(visto):
    """As linhas da última passada, do total e da passada em andamento."""
    ultima, linhas = visto['ultima'], ''
    if inteiro(ultima, 'quando'):
        linhas += f'<div class="larga"><dt>{t("Última passada")}</dt><dd>{e(quando(ultima["quando"]))} · {numeros(ultima)}</dd></div>'
    else:
        linhas += f'<div class="larga"><dt>{t("Última passada")}</dt><dd>{t("nenhuma ainda")}</dd></div>'
    if inteiro(visto['total'], 'arquivos'):
        linhas += (f'<div><dt>{t("Enviado desde que foi ligado")}</dt><dd>'
                   f'{tn(inteiro(visto["total"], "arquivos"), "{n} arquivo", "{n} arquivos")} · '
                   f'{e(tamanho(inteiro(visto["total"], "bytes")))}</dd></div>')
    if visto['adiados']:
        linhas += (f'<div class="larga"><dt>{t("À espera do bot")}</dt><dd>'
                   + tn(visto['adiados'], '{n} arquivo já gravado no S3 sai do servidor quando o bot do Telegram o entregar',
                        '{n} arquivos já gravados no S3 saem do servidor quando o bot do Telegram os entregar') + '</dd></div>')
    if inteiro(ultima, 'esperando'):
        linhas += (f'<div class="larga"><dt>{t("Ainda chegando")}</dt><dd>'
                   + tn(inteiro(ultima, 'esperando'),
                        '{n} arquivo mudou há menos de dois minutos e ainda pode estar chegando: vai em uma próxima passada',
                        '{n} arquivos mudaram há menos de dois minutos e ainda podem estar chegando: vão em uma próxima passada')
                   + '</dd></div>')
    if visto['andamento']:
        linhas += f'<div class="larga"><dt>{t("Agora")}</dt><dd>{t("passada em andamento")}: {numeros(visto["andamento"])}</dd></div>'
    return linhas


def dados_do_s3(conf):
    modo = (t('Guardar no S3: o arquivo sai do servidor depois de gravado no destino') if conf['modo'] == 'mover'
            else t('Copiar: o arquivo continua no servidor'))
    lugar = f'<code>{e(conf["bucket"])}</code>' + (f' / <code>{e(conf["prefixo"])}</code>' if conf['prefixo'] else '')
    return (f'<div><dt>{t("Endereço")}</dt><dd><code>{e(conf["endpoint"])}</code></dd></div>'
            f'<div><dt>{t("Bucket e prefixo")}</dt><dd>{lugar}</dd></div>'
            f'<div><dt>{t("Região")}</dt><dd><code>{e(conf["regiao"])}</code></dd></div>'
            f'<div><dt>{t("Pasta enviada")}</dt><dd>{pasta_enviada(conf)}</dd></div>'
            f'<div><dt>{t("Passadas")}</dt><dd>{a_cada(conf)}</dd></div>'
            f'<div class="larga"><dt>{t("Depois do envio")}</dt><dd>{modo}</dd></div>')


def dados_do_telegram(conf):
    return (f'<div><dt>{t("Pasta enviada")}</dt><dd>{pasta_enviada(conf)}</dd></div>'
            f'<div><dt>{t("Passadas")}</dt><dd>{a_cada(conf)}</dd></div>'
            f'<div><dt>{t("Maior arquivo que o bot envia")}</dt><dd>{e(tamanho(CFG["telegram_max"]))}</dd></div>'
            f'<div><dt>{t("Idioma das mensagens")}</dt><dd>{e(idioma.NOMES[conf["idioma"]][1])}</dd></div>')


def cartao(sessao, destino):
    visto = destinos.situacao(destino)
    conf = visto['conf']
    titulo = f'<h2>{icone(DESENHOS[destino])}{t(TITULOS[destino])} {etiqueta(visto)}</h2>'
    if not conf:
        oque = (t('Envia os arquivos de uma pasta para um bucket de qualquer serviço que fale o protocolo do S3, na nuvem ou '
                  'na rede interna. Pode só copiar, ou guardar lá e liberar o disco do servidor.') if destino == 's3' else
                t('Envia cada arquivo que chega em uma pasta para uma pessoa, um grupo ou um canal, por um bot do Telegram. '
                  'O bot só envia: o painel não lê mensagem nem aceita comando pela conversa.'))
        return (f'<section class="cartao">{titulo}<p>{oque}</p>'
                f'<p><a class="botao principal" href="{ABA}/{destino}">{icone("mais")}{t("Configurar")}</a></p></section>')
    falha = ''
    if not visto['segredos']:
        falha = ('<p class="aviso">' + t('A configuração está gravada, mas faltam os segredos deste destino (eles não entram na '
                                         'cópia de segurança). Abra <strong>Alterar</strong> e grave-os de novo; até lá, nada é '
                                         'enviado.') + '</p>')
    elif visto['ultima'].get('motivo'):
        falha = ('<p class="aviso">' + t('A última passada parou antes do fim: {motivo}. A seguinte recomeça do mesmo arquivo.',
                                         motivo=e(explicar(str(visto['ultima']['motivo'])))) + '</p>')
    guardados = (t('gravados; não aparecem na tela') if visto['segredos'] else t('faltando'))
    segredos = (f'<div><dt>{t("Chave de acesso e chave secreta") if destino == "s3" else t("Token do bot e conversa")}</dt>'
                f'<dd>{guardados}</dd></div>')
    dados = (dados_do_s3 if destino == 's3' else dados_do_telegram)(conf)
    return f'''<section class="cartao">{titulo}{falha}
<dl class="dados">{dados}{segredos}{passadas(visto)}</dl>
<form method="post" action="{ABA}/testar" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<input type="hidden" name="destino" value="{destino}">
<button type="submit">{t('Testar')}</button> <button type="submit" formaction="{ABA}/agora">{icone('envio')}{t('Enviar agora')}</button>
<a class="botao" href="{ABA}/{destino}">{icone('lapis')}{t('Alterar')}</a>
<a class="botao perigo" href="{ABA}/remover?destino={destino}">{icone('lixeira')}{t('Remover')}</a>
</form></section>'''


@ligada
def lista(pedido, sessao, consulta, formulario, token):
    aviso, erro = '', ''
    if consulta.get('m') == 'falha' and consulta.get('d') in destinos.NOMES:
        erro = t('{destino}: não deu certo. Motivo: {motivo}.', destino=t(TITULOS[consulta['d']]),
                 motivo=explicar(consulta.get('f', '')))
    elif consulta.get('m') in MENSAGENS:
        aviso = t(MENSAGENS[consulta['m']])
    resumo = t('Cópia automática dos arquivos para fora do servidor: um armazenamento S3 e um bot do Telegram.')
    pedido.enviar(200, pagina(t('Destinos'), f'''{cabeca('Destinos', resumo)}
{f'<p class="ok" role="status">{e(aviso)}</p>' if aviso else ''}{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<div class="fichas">
{cartao(sessao, 's3')}
{cartao(sessao, 'telegram')}
<section class="cartao medio"><h2>{icone('escudo')}{t('Como o painel envia')}</h2>
<p class="suave">{t('O painel só sai do servidor para os destinos gravados aqui, sempre por HTTPS com o certificado '
                    'conferido. Sai arquivo comum: link simbólico e nome começado por ponto ficam de fora. O bot do '
                    'Telegram envia em instantes o arquivo que chega inteiro por FTP ou pelo painel; nos outros casos, e sempre '
                    'no S3, o arquivo só entra na passada depois de dois minutos sem mudar, para o que ainda está chegando não '
                    'sair pela metade. A ordem é a da chegada ao servidor; uma falha do destino encerra a passada e a seguinte recomeça do mesmo '
                    'arquivo. Pasta que troca de nome não reenvia os arquivos de dentro.')}</p>
<p class="suave">{t('Os segredos ficam no servidor, na pasta <code>destinos</code> dos segredos da instalação, um por arquivo, e '
                    'não entram na cópia de segurança: depois de restaurar uma cópia, grave-os de novo.')}</p></section>
</div>''',
                              sessao, ABA))


# ------------------------------------------------------------ formulários

def texto(nome, rotulo, nota, valor, mais=''):
    return (f'<label for="{nome}">{rotulo} <span class="suave">({nota})</span></label>\n'
            f'<input id="{nome}" name="{nome}" value="{e(valor)}" autocomplete="off" autocapitalize="none" spellcheck="false"{mais}>')


def segredo(nome, rotulo, gravado, tipo='password'):
    """Campo só de escrita: nunca traz o que está gravado, nem o que foi digitado em um envio recusado."""
    nota = t('em branco mantém o gravado') if gravado else t('obrigatório')
    return (f'<label for="{nome}">{rotulo} <span class="suave">({nota})</span></label>\n'
            f'<input id="{nome}" name="{nome}" type="{tipo}" maxlength="256" autocomplete="off" autocapitalize="none" '
            f'spellcheck="false"{"" if gravado else " required"}>')


def escolha(nome, legenda, opcoes, marcado):
    itens = ''.join(f'<label class="marcar"><input type="radio" name="{nome}" value="{chave}"{" checked" if chave == marcado else ""}> '
                    f'<span><strong>{rotulo}</strong>{": " + nota if nota else ""}</span></label>' for chave, rotulo, nota in opcoes)
    return f'<fieldset class="perfis"><legend>{legenda}</legend>{itens}</fieldset>'


def comuns(dele):
    """Os campos que os dois destinos têm: a situação, a pasta e o intervalo."""
    return f'''<label class="marcar"><input type="checkbox" name="ligado" value="sim"{' checked' if dele['ligado'] else ''}> <span>{t('Ligado: o painel envia sozinho, no intervalo abaixo')}</span></label>
{texto('pasta', t('Pasta enviada'), t('dentro dos dados, com as pastas de dentro dela; em branco é a pasta dos dados inteira'),
       dele['pasta'], ' maxlength="259"')}
<label for="intervalo">{t('Intervalo entre as passadas')} <span class="suave">({t('minutos, de 5 a 1440')})</span></label>
<input id="intervalo" name="intervalo" type="number" min="5" max="1440" step="1" inputmode="numeric" required value="{e(str(dele['intervalo'] or ''))}">'''


def moldura(sessao, destino, erro, codigo, miolo, pedido):
    titulo = t(TITULOS[destino])
    pedido.enviar(codigo, pagina(titulo, f'''<h1>{titulo}</h1>
<section class="cartao estreito">{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<form method="post" action="{ABA}/{destino}" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
{miolo}
{campo_senha_atual(sessao, para=t('para gravar o destino'))}
<button type="submit">{t('Gravar')}</button> <a class="botao" href="{ABA}">{t('Cancelar')}</a>
</form></section>''', sessao, ABA))


def gravados(destino):
    """Cada segredo do destino já está gravado? Na ordem de destinos.SEGREDOS."""
    return [bool(destinos.ler_segredo(nome)) for nome in destinos.SEGREDOS[destino]]


@ligada
def tela_s3(pedido, sessao, consulta, formulario=None, token=None, erro='', codigo=200, dele=None):
    dele = dele or destinos.ler('s3') or {'ligado': True, 'endpoint': '', 'regiao': 'us-east-1', 'bucket': '', 'prefixo': '',
                                         'estilo': 'caminho', 'pasta': '', 'modo': 'copiar', 'intervalo': 60}
    tem_id, tem_secreta = gravados('s3')
    moldura(sessao, 's3', erro, codigo, f'''<p>{t('Serve qualquer serviço que fale o protocolo do S3. A chave só precisa poder gravar no bucket '
      '(<code>s3:PutObject</code> e <code>s3:AbortMultipartUpload</code>): o painel não lê, não lista e não apaga nada no destino.')}</p>
{texto('endpoint', t('Endereço do serviço'), t('só HTTPS, sem o bucket: <code>https://nome</code> ou <code>https://nome:porta</code>'),
       dele['endpoint'], ' required maxlength="270" inputmode="url" placeholder="https://"')}
{texto('regiao', t('Região'), t('a que o serviço informa; onde não há, <code>us-east-1</code>'), dele['regiao'], ' required maxlength="32"')}
{texto('bucket', t('Bucket'), t('já criado no serviço'), dele['bucket'], ' required maxlength="63"')}
{texto('prefixo', t('Prefixo'), t('pasta dentro do bucket; em branco grava na raiz dele'), dele['prefixo'], ' maxlength="255"')}
{escolha('estilo', t('Endereço do bucket'), (
    ('caminho', t('No caminho'), t('<code>https://nome/bucket/arquivo</code>, o que a maioria dos serviços próprios usa')),
    ('host', t('No nome'), t('<code>https://bucket.nome/arquivo</code>, o que as nuvens grandes pedem'))), dele['estilo'])}
{segredo('chave_id', t('Chave de acesso'), tem_id, 'text')}
{segredo('chave_secreta', t('Chave secreta'), tem_secreta)}
{comuns(dele)}
{escolha('modo', t('Depois do envio'), (
    ('copiar', t('Copiar'), t('o arquivo continua no servidor; o S3 é a segunda cópia')),
    ('mover', t('Guardar no S3'), t('o arquivo sai do servidor depois que o destino confirma a gravação'))), dele['modo'])}
<p class="aviso">{t('Em <strong>Guardar no S3</strong>, o destino passa a ter a única cópia: o painel não tem lixeira e não '
                    'baixa de volta. A primeira passada envia tudo o que já está na pasta; com Guardar no S3, tudo isso sai '
                    'do servidor. Trocar de Copiar para Guardar vale para o que for enviado dali em diante.')}</p>
<p class="suave">{t('O nome do objeto é o prefixo mais o caminho do arquivo dentro dos dados. Trocar o endereço, o bucket, o '
                    'prefixo ou a pasta recomeça do zero: tudo o que está na pasta é enviado de novo.')}</p>''', pedido)
    return None


@ligada
def tela_telegram(pedido, sessao, consulta, formulario=None, token=None, erro='', codigo=200, dele=None):
    dele = dele or destinos.ler('telegram') or {'ligado': True, 'pasta': '', 'intervalo': 5, 'idioma': idioma.atual()}
    tem_token, tem_conversa = gravados('telegram')
    linguas = tuple((codigo_da, e(nome), '') for codigo_da, (_, nome, _) in idioma.NOMES.items())
    moldura(sessao, 'telegram', erro, codigo, f'''<p>{t('O bot <strong>só envia</strong>: o painel usa o envio de arquivo e o envio de mensagem, e nada mais. Não lê a '
      'conversa, não registra endereço de retorno e não aceita comando.')}</p>
{segredo('token', t('Token do bot'), tem_token)}
{segredo('conversa', t('Conversa que recebe'), tem_conversa, 'text')}
<p class="suave">{t('A conversa é o número da pessoa ou do grupo (o de grupo começa com <code>-</code>) ou o <code>@nome</code> '
                    'de um canal. O bot precisa estar no grupo ou no canal, e a pessoa precisa ter iniciado a conversa com ele.')}</p>
{comuns(dele)}
{escolha('idioma', t('Idioma das mensagens'), linguas, dele['idioma'] if dele['idioma'] in idioma.IDIOMAS else idioma.PADRAO)}
<p class="suave">{t('Vai um arquivo por mensagem, com o caminho, o tamanho e a data. O maior arquivo que o bot envia tem '
                    '{limite}: acima disso vai só um aviso com o nome e o tamanho. Só é enviado o que chegar depois de o '
                    'destino ser ligado; desligar e ligar de novo, ou trocar a pasta, recomeça dali.',
                    limite=e(tamanho(CFG['telegram_max'])))}</p>
<p class="suave">{t('O arquivo que chega inteiro por FTP ou pelo painel sai em instantes, sem esperar o intervalo. O intervalo '
                    'confere o que ficou para trás: o arquivo que trocou de nome e o que chegou por outro caminho.')}</p>''', pedido)
    return None


def do_formulario(destino, formulario):
    """O formulário ➜ (configuração, segredos novos, erro). O segredo em branco mantém o gravado."""
    intervalo = formulario.get('intervalo', '').strip()
    conf = {'ligado': formulario.get('ligado') == 'sim', 'pasta': formulario.get('pasta', '').strip().strip('/'),
            'intervalo': int(intervalo) if re.fullmatch(r'[0-9]{1,4}', intervalo) else 0}
    if destino == 's3':
        conf.update({'endpoint': formulario.get('endpoint', '').strip().lower().rstrip('/'),
                     'regiao': formulario.get('regiao', '').strip().lower(), 'bucket': formulario.get('bucket', '').strip(),
                     'prefixo': formulario.get('prefixo', '').strip().strip('/'), 'estilo': formulario.get('estilo', ''),
                     'modo': formulario.get('modo', '')})
        novos = (formulario.get('chave_id', '').strip(), formulario.get('chave_secreta', '').strip())
        mal = (t('Chave de acesso inválida: de 3 a 128 caracteres, sem espaço.'),
               t('Chave secreta inválida: de 8 a 256 caracteres, sem espaço.'))
    else:
        conf['idioma'] = formulario.get('idioma', '')
        novos = (formulario.get('token', '').strip(), formulario.get('conversa', '').strip())
        mal = (t('Token inválido: é o texto inteiro que o criador de bots entrega, com os números, os dois-pontos e o resto.'),
               t('Conversa inválida: o número da pessoa ou do grupo, ou o @nome do canal.'))
    campo = destinos.defeito(destino, conf)
    if campo:
        return conf, novos, t(ERROS[campo])
    if conf['pasta'] and not destinos.pasta_existe(conf['pasta']):
        return conf, novos, t('A pasta não existe dentro dos dados. Crie em Arquivos ou confira o nome.')
    for valor, regra, erro, tem in zip(novos, destinos.FORMATO[destino], mal, gravados(destino)):
        if valor and not re.fullmatch(regra, valor):
            return conf, novos, erro
        if not valor and not tem:
            return conf, novos, t('Preencha os dois segredos do destino: nenhum deles está gravado ainda.')
    return conf, novos, ''


def gravar(pedido, sessao, formulario, destino, tela):
    conf, novos, erro = do_formulario(destino, formulario)
    codigo = 400 if erro else 0
    if not erro:
        codigo, erro = confirmacao_recusada(pedido, sessao, formulario)
    if not erro:
        try:
            destinos.gravar(destino, conf, novos)
        except OSError as motivo:
            codigo, erro = 500, t('Não foi possível gravar o destino:') + ' ' + (motivo.strerror or t('erro de disco'))
            auditar(pedido.ip, 'falha_comando', f'admin={sessao["admin"]} acao=gravar_destino destino={destino}')
    if erro:
        return tela(pedido, sessao, {}, erro=erro, codigo=codigo, dele=conf)
    auditar(pedido.ip, 'destino_gravado',
            f'admin={sessao["admin"]} destino={destino} situacao={"ligado" if conf["ligado"] else "desligado"} '
            f'pasta={limpo(conf["pasta"], 200) or "-"} intervalo={conf["intervalo"]}'
            + (f' modo={conf["modo"]}' if destino == 's3' else '')
            + (f' segredos={"trocados" if any(novos) else "mantidos"}'))
    return pedido.redirecionar(ABA + '?m=gravado')


@ligada
def gravar_s3(pedido, sessao, consulta, formulario, token):
    return gravar(pedido, sessao, formulario, 's3', tela_s3)


@ligada
def gravar_telegram(pedido, sessao, consulta, formulario, token):
    return gravar(pedido, sessao, formulario, 'telegram', tela_telegram)


# ------------------------------------------------------------ teste, passada pedida e remoção

def destino_do(pedido, sessao, dados):
    """O destino pedido, ou None depois de responder que ele não existe."""
    destino = dados.get('destino', '')
    if destino in destinos.NOMES:
        return destino
    pedido.enviar(404, pagina(t('Não encontrado'), f'<section class="cartao"><h1>{t("Página não encontrada")}</h1>'
                              f'<p><a href="{ABA}">{t("Voltar para os destinos")}</a></p></section>', sessao, ABA))
    return None


@ligada
def testar(pedido, sessao, consulta, formulario, token):
    """Grava um objeto pequeno no S3 ou envia uma mensagem pelo bot, com o que está gravado."""
    destino = destino_do(pedido, sessao, formulario)
    if not destino:
        return None
    motivo = destinos.testar(destino)
    auditar(pedido.ip, 'destino_teste', f'admin={sessao["admin"]} destino={destino} resultado={motivo or "ok"}')
    return pedido.redirecionar(f'{ABA}?m=falha&d={destino}&f={motivo}' if motivo else ABA + '?m=teste')


@ligada
def agora(pedido, sessao, consulta, formulario, token):
    """Passada fora de hora: quem faz é a linha de execução dos destinos, e a tela não espera por ela."""
    destino = destino_do(pedido, sessao, formulario)
    if not destino:
        return None
    if not destinos.operante(destino):
        return pedido.redirecionar(f'{ABA}?m=falha&d={destino}&f=desligado')
    destinos.pedir(destino)
    auditar(pedido.ip, 'destino_pedido', f'admin={sessao["admin"]} destino={destino}')
    return pedido.redirecionar(ABA + '?m=pedido')


# ------------------------------------------------------------ um arquivo só, pela aba Arquivos

def botoes_do_arquivo(sessao):
    """Para a aba Arquivos: os formulários de envio de um arquivo só, um por destino com configuração e segredos
    gravados, e a função que dá os botões da linha de um arquivo. Os formulários ficam fora da tabela e os botões
    apontam para eles, para o token não se repetir em cada linha. Sem destino pronto, não há botão."""
    prontos = [destino for destino in destinos.NOMES
               if destinos.ler(destino) and destinos.segredos_de(destino)] if CFG['destinos'] else []
    if not prontos:
        return '', None
    formularios = ''.join(f'<form id="para-{destino}" method="post" action="{ABA}/arquivo" autocomplete="off" hidden>'
                          f'<input type="hidden" name="csrf" value="{e(sessao["csrf"])}">'
                          f'<input type="hidden" name="destino" value="{destino}"></form>' for destino in prontos)
    moldes = [(destino, icone(DESENHOS[destino]), NA_LINHA[destino][0], e(t(NA_LINHA[destino][1]))) for destino in prontos]

    def botoes(caminho):
        try:
            caminho.encode('utf-8')
        except UnicodeEncodeError:
            return ''   # o formulário não devolve nome com byte fora do UTF-8, e a passada também não o envia
        valor = e(caminho)
        return ''.join(f' <button class="botao" type="submit" form="para-{destino}" name="arquivo" value="{valor}" title="{dica}">'
                       f'{desenho}{rotulo}</button>' for destino, desenho, rotulo, dica in moldes)
    return formularios, botoes


def volta_do_arquivo(consulta):
    """(aviso, erro) que a aba Arquivos mostra na volta do envio de um arquivo só."""
    feito, destino = consulta.get('m', ''), consulta.get('d', '')
    if destino not in destinos.NOMES:
        return '', ''
    if feito == 'destino_ok':
        return t('{destino}: arquivo enviado.', destino=t(TITULOS[destino])), ''
    if feito == 'destino_andando':
        return t('{destino}: o envio continua em segundo plano. O resultado aparece na aba Log.', destino=t(TITULOS[destino])), ''
    if feito == 'destino_falha':
        return '', t('{destino}: não deu certo. Motivo: {motivo}.', destino=t(TITULOS[destino]),
                     motivo=explicar(consulta.get('f', '')))
    return '', ''


@ligada
def arquivo(pedido, sessao, consulta, formulario, token):
    """Envia um arquivo ao destino, com o que está gravado, e volta para a pasta dele. O arquivo não é apagado e o
    andamento das passadas não muda."""
    destino = destino_do(pedido, sessao, formulario)
    if not destino:
        return None
    caminho, ip, admin = formulario.get('arquivo', ''), pedido.ip, sessao['admin']

    def ao_terminar(resultado, enviados):
        auditar(ip, 'destino_arquivo', f'admin={admin} destino={destino} arquivo={limpo(caminho, 200)} bytes={enviados} '
                                       f'resultado={resultado or "ok"}')
    try:
        motivo = destinos.enviar_arquivo(destino, caminho, ao_terminar)
    except aba_arquivos.Recusado as erro:
        return aba_arquivos.recusa(pedido, sessao, erro, caminho)
    volta = aba_arquivos.endereco('/arquivos', 'pasta', caminho.rpartition('/')[0])
    if motivo in ('', 'andando'):
        return pedido.redirecionar(f'{volta}&m=destino_{motivo or "ok"}&d={destino}')
    return pedido.redirecionar(f'{volta}&m=destino_falha&d={destino}&f={motivo}')


@ligada
def tela_remover(pedido, sessao, consulta, formulario=None, token=None, erro='', codigo=200):
    destino = destino_do(pedido, sessao, consulta)
    if not destino:
        return None
    titulo = t('Remover destino')
    pedido.enviar(codigo, pagina(titulo, f'''<h1>{titulo}</h1>
<section class="cartao estreito">{f'<p class="erro" role="alert">{e(erro)}</p>' if erro else ''}
<p>{t('Remover <strong>{destino}</strong>? O painel apaga a configuração, o andamento e os segredos deste destino e para de '
      'enviar para ele. O que já foi enviado continua lá, e nenhum arquivo do servidor é apagado.', destino=t(TITULOS[destino]))}</p>
<form method="post" action="{ABA}/remover" autocomplete="off">
<input type="hidden" name="csrf" value="{e(sessao['csrf'])}">
<input type="hidden" name="destino" value="{destino}">
{campo_senha_atual(sessao, para=t('para remover o destino'))}
<button class="perigo" type="submit">{t('Sim, remover o destino')}</button> <a class="botao" href="{ABA}">{t('Cancelar')}</a>
</form></section>''', sessao, ABA))
    return None


@ligada
def remover(pedido, sessao, consulta, formulario, token):
    destino = destino_do(pedido, sessao, formulario)
    if not destino:
        return None
    codigo, erro = confirmacao_recusada(pedido, sessao, formulario)
    if not erro:
        try:
            destinos.remover(destino)
        except OSError as motivo:
            codigo, erro = 500, t('Não foi possível remover o destino:') + ' ' + (motivo.strerror or t('erro de disco'))
            auditar(pedido.ip, 'falha_comando', f'admin={sessao["admin"]} acao=remover_destino destino={destino}')
    if erro:
        return tela_remover(pedido, sessao, {'destino': destino}, erro=erro, codigo=codigo)
    auditar(pedido.ip, 'destino_removido', f'admin={sessao["admin"]} destino={destino}')
    return pedido.redirecionar(ABA + '?m=removido')
