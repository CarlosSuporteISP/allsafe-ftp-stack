#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Painel web da allsafe-ftp-stack. Por padrão, só para rede privada, atrás de firewall.

O navegador fala HTTPS com o nginx, que é a única porta publicada; o painel não escuta na rede:
atende só o soquete Unix que o nginx abre e recebe dele o endereço real do cliente. Cada administrador
entra com usuário e senha, conferida contra hash scrypt; sessão em cookie __Host-, token CSRF em todo
envio e nenhuma dependência fora da biblioteca padrão do Python.
Não usa JavaScript nem o socket do Docker: os usuários do FTP são alterados pelo mesmo
allsafe-ftp-user do serviço ftp, na pasta /auth que os dois containers compartilham.

Modos: sem argumento, sobe o servidor; --hash lê uma senha da entrada padrão e imprime o hash;
--administrador <nome> lê um hash da entrada padrão e cria o administrador ou troca a senha dele;
--saude confere /saude pelo soquete e sai com 0 ou 1 (o healthcheck do container roda o saude.py direto, sem subir o painel);
--retencao aplica agora a limpeza automática de cada usuário que tem uma, e com --simular só conta o que sairia;
--destinos mostra a situação de cada destino (S3, remoto do rclone e bot do Telegram), e --destinos enviar <destino> faz agora a passada dele
(com --sem-espera, sem aguardar os dois minutos de um arquivo sem mudar);
--copia mostra a situação da cópia do sistema para o S3, e --copia enviar faz a cópia agora e só volta quando ela termina;
--segundo-fator mostra quais administradores estão com o segundo fator ligado, e --segundo-fator desligar <nome> desliga o de um
(a saída de quem perdeu o aparelho e não tem outro administrador a quem pedir).
"""
import os
import sys

import administradores
import copia
import destinos
import fator
import limpeza
import recursos
import saude
from atendimento import Painel, Servidor
from auditoria import auditar, limpo
from config import ARQ_ADMINS, ARQ_HASH, ARQ_SOQUETE, CFG, NOME, SENHA_MIN, configuracao, falha
from senha import analisar_hash, gerar_hash, ler_hash_inicial


def modo_hash():
    senha = sys.stdin.readline().rstrip('\r\n')
    if not SENHA_MIN <= len(senha) <= 256:
        falha(f'a senha do painel deve ter pelo menos {SENHA_MIN} caracteres')
    print(gerar_hash(senha))


def modo_administrador(nome):
    """Recuperação pelo host (scripts/painel-senha.sh): o hash vem pela entrada padrão, nunca a senha."""
    guardado = sys.stdin.readline().strip()
    if not NOME.fullmatch(nome):
        falha('nome de administrador inválido: letras minúsculas, números, _ e -; começa com letra ou _; até 32 caracteres')
    if not analisar_hash(guardado):
        falha('a entrada padrão não trouxe um hash scrypt válido')
    try:
        feito, erro = administradores.definir(nome, guardado)
    except OSError as motivo:
        falha(f'não foi possível gravar {ARQ_ADMINS}: {motivo.strerror}')
    if erro:
        falha(erro)
    auditar('-', 'admin_definido_no_host', f'admin={nome} resultado={feito}')
    print(f'administrador {nome}: {feito}')


def modo_segundo_fator(argumentos):
    """Situação do segundo fator de cada administrador, ou o desligamento do de um, pedido pelo terminal."""
    if not argumentos:
        for nome in administradores.ler():
            if not fator.ligado(nome):
                print(f'{nome}: desligado')
            elif fator.segredo_de(nome):
                print(f'{nome}: ligado')
            else:
                print(f'{nome}: ligado, sem o segredo no servidor (a conta não entra até ser desligado)')
        return
    if len(argumentos) != 2 or argumentos[0] != 'desligar':
        falha('uso: --segundo-fator [desligar <administrador>]')
    nome = argumentos[1]
    if not NOME.fullmatch(nome) or nome not in administradores.ler():
        falha('administrador não encontrado')
    try:
        estava = fator.desligar(nome)
    except OSError as motivo:
        falha(f'não foi possível gravar o segundo fator: {motivo.strerror}')
    if estava:
        auditar('-', 'admin_fator_desligado_no_host', f'alvo={nome}')
    print(f'{nome}: segundo fator desligado' if estava else f'{nome}: o segundo fator já estava desligado')


def modo_retencao(simular):
    """A passada da limpeza automática, pedida pelo terminal. Diz o que saiu de cada pasta, sem o nome dos arquivos."""
    feitas = limpeza.passada(simular)
    for nome, pasta, regra, conta in feitas:
        dela = ' '.join(f'{chave}={valor}' for chave, valor in regra.items() if valor)
        if conta is None:
            print(f'{nome} /data/{pasta} ({dela}): a pasta não pôde ser aberta')
        else:
            print(f'{nome} /data/{pasta} ({dela}): {conta["arquivos"]} arquivo(s), {conta["bytes"]} bytes, '
                  f'{conta["pastas"]} pasta(s) vazia(s), {conta["erros"]} erro(s)')
    if not feitas:
        print('Nenhum usuário com limpeza automática.')
    elif simular:
        print('Simulação: nada foi apagado. Pasta que ficaria vazia não entra na conta.')


def linha_da_passada(conta):
    return (f'{conta.get("arquivos", 0)} arquivo(s), {conta.get("bytes", 0)} bytes, {conta.get("apagados", 0)} apagado(s) '
            f'do servidor, {conta.get("grandes", 0)} acima do limite do bot, {conta.get("ignorados", 0)} ignorado(s), '
            f'{conta.get("erros", 0)} recusado(s); ' + (f'parou: {conta["motivo"]}' if conta.get('motivo') else 'chegou ao fim'))


def modo_destinos(argumentos):
    """Os destinos de fora, pelo terminal: a situação de cada um ou uma passada agora. Nenhum segredo é mostrado."""
    CFG.update(configuracao())
    if not CFG['destinos']:
        falha('os destinos estão desligados nesta instalação (PAINEL_DESTINOS=nao)')
    if not argumentos:
        for tipo in destinos.TIPOS:
            gravados = destinos.todos(tipo)
            if not gravados:
                print(f'{tipo}: não configurado')
            for destino in gravados:
                visto = destinos.situacao(destino)
                estado = ('ligado' if visto['conf']['ligado'] else 'desligado') + ('' if visto['segredos'] else ', faltam os segredos')
                ultima = visto['ultima']
                print(f'{destino}: {estado}; pasta /data/{visto["conf"]["pasta"]}; a cada {visto["conf"]["intervalo"]} min; '
                      + (f'última passada: {linha_da_passada(ultima)}' if ultima.get('quando') else 'nenhuma passada ainda')
                      + (f'; nome: {visto["conf"]["nome"]}' if visto['conf']['nome'] else ''))
        return
    if len(argumentos) < 2 or argumentos[0] != 'enviar' or not destinos.valido(argumentos[1]) \
            or set(argumentos[2:]) - {'--sem-espera'}:
        falha('uso: --destinos [enviar <destino> [--sem-espera]]; o destino é o nome que a lista mostra: s3, rclone, telegram, s3-2, rclone-2 ...')
    feitas = destinos.executar({argumentos[1]}, '--sem-espera' in argumentos)
    if feitas is None:
        falha('outra passada está em andamento: tente de novo em instantes')
    if not feitas:
        falha(f'{argumentos[1]}: não configurado, desligado ou sem os segredos')
    for destino, conta in feitas.items():
        print(f'{destino}: {linha_da_passada(conta)}')
    sys.exit(1 if any(conta.get('motivo') for conta in feitas.values()) else 0)


def linha_da_copia(resumo):
    if resumo.get('motivo') == 'soma':
        return f'falhou: o objeto {resumo.get("lugar", "")} foi gravado, mas o arquivo .sha256 dele não; faça outra cópia'
    if resumo.get('motivo'):
        return f'falhou: {resumo["motivo"]}; nenhum objeto ficou no destino'
    return (f'{resumo["lugar"]}; {resumo["bytes"]} bytes em {resumo["partes"]} parte(s); {resumo["arquivos"]} arquivo(s), '
            f'{resumo["mudaram"]} mudaram durante a leitura, {resumo["fora"]} de fora (soquete, fila ou dispositivo); '
            f'sha256 {resumo["sha256"]}')


def modo_copia(argumentos):
    """A cópia do sistema para o S3, pelo terminal: a situação dela ou uma cópia agora. Nenhum segredo é mostrado."""
    CFG.update(configuracao())
    if not CFG['destinos']:
        falha('os destinos estão desligados nesta instalação (PAINEL_DESTINOS=nao)')
    if not argumentos:
        visto = copia.situacao()
        conf = visto['conf']
        if not conf:
            print('cópia do sistema: não configurada')
        else:
            pasta = f'{visto["destino"]["bucket"]}/{conf["prefixo"]}'.rstrip('/') if visto['destino'] else 'destino removido'
            rotina = f'a cada {conf["dias"]} dia(s), às {conf["hora"]}' if conf['dias'] else 'só pelo botão ou pelo terminal'
            print(f'cópia do sistema: {conf["destino"]} ({pasta}); {rotina}'
                  + ('' if visto['segredos'] else '; faltam os segredos do destino'))
        if not visto['chave']:
            print('falta a chave pública da cópia: rode ./deploy.sh')
        if visto['andamento']:
            print(f'em andamento: {visto["andamento"].get("bytes", 0)} bytes em {visto["andamento"].get("partes", 0)} parte(s)')
        elif visto['interrompida']:
            print('a cópia anterior foi interrompida pelo reinício do painel')
        print(f'última cópia: {linha_da_copia(visto["ultima"])}' if visto['ultima'].get('quando') else 'nenhuma cópia ainda')
        return
    if argumentos != ['enviar']:
        falha('uso: --copia [enviar]')
    resumo = copia.enviar(os.environ.get('PAINEL_COPIA_ORIGEM', 'terminal'))
    if resumo['motivo'] == 'copiando':
        falha('outra cópia está em andamento: tente de novo quando ela terminar')
    print(f'cópia do sistema: {linha_da_copia(resumo)}')
    sys.exit(1 if resumo['motivo'] else 0)


def principal():
    if '--hash' in sys.argv[1:]:
        return modo_hash()
    if '--copia' in sys.argv[1:]:
        return modo_copia(sys.argv[sys.argv.index('--copia') + 1:])
    if '--destinos' in sys.argv[1:]:
        return modo_destinos(sys.argv[sys.argv.index('--destinos') + 1:])
    if '--segundo-fator' in sys.argv[1:]:
        return modo_segundo_fator(sys.argv[sys.argv.index('--segundo-fator') + 1:])
    if '--retencao' in sys.argv[1:]:
        return modo_retencao('--simular' in sys.argv[1:])
    if '--saude' in sys.argv[1:]:
        return saude.conferir()
    if '--administrador' in sys.argv[1:]:
        posicao = sys.argv.index('--administrador')
        return modo_administrador(sys.argv[posicao + 1] if len(sys.argv) > posicao + 1 else '')
    CFG.update(configuracao())
    # O segredo da instalação só vale para criar o primeiro administrador; depois, quem manda é o arquivo.
    if not administradores.ler():
        inicial = ler_hash_inicial()
        if inicial is None:
            falha(f'{ARQ_HASH} ausente ou inválido: rode ./deploy.sh ou scripts/painel-senha.sh')
        try:
            criado = administradores.iniciar(CFG['admin_inicial'], inicial)
        except OSError as motivo:
            falha(f'não foi possível gravar {ARQ_ADMINS}: {motivo.strerror}')
        if criado:
            auditar('-', 'admin_inicial_criado', f'admin={CFG["admin_inicial"]}')
    servidor = Servidor(ARQ_SOQUETE, Painel)
    recursos.iniciar()
    limpeza.iniciar()
    destinos.iniciar()
    copia.iniciar()
    auditar('-', 'painel_iniciado', f'versao={limpo(CFG["versao"])}')
    print(f'Painel pronto no soquete {ARQ_SOQUETE}, atrás do nginx; sessão de {CFG["inatividade"] // 60} min; '
          f'redes permitidas: {", ".join(str(r) for r in CFG["redes"])}', flush=True)
    servidor.serve_forever()


if __name__ == '__main__':
    principal()
