#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -Eeuo pipefail
root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"
for script in deploy.sh manage-user.sh scripts/*.sh ftp/*.sh painel/*.sh nginx/*.sh tests/*.sh tests/etapas/*.sh; do bash -n "$script"; done
# O vigia do FTP é Perl, que a imagem já traz; o host não precisa dele. Se tiver, confere a sintaxe.
if command -v perl >/dev/null 2>&1; then for script in ftp/*.pl; do perl -c "$script" 2>/dev/null || { perl -c "$script"; exit 1; }; done; fi
# O host não precisa de Python; se tiver, confere os módulos do painel sem importar nem gravar nada:
# a sintaxe de cada um e que todo nome usado está definido ou importado nele (import esquecido).
if command -v python3 >/dev/null 2>&1; then
  python3 - painel/*.py <<'PY'
import builtins, dis, sys
falha = 0
for arquivo in sys.argv[1:]:
    codigo = compile(open(arquivo, encoding='utf-8').read(), arquivo, 'exec')
    pilha, definidos, usados = [codigo], set(dir(builtins)) | {'__file__', '__name__'}, set()
    while pilha:
        atual = pilha.pop()
        pilha += [c for c in atual.co_consts if hasattr(c, 'co_code')]
        for i in dis.get_instructions(atual):
            if i.opname == 'STORE_NAME':
                definidos.add(i.argval)
            elif i.opname in ('LOAD_GLOBAL', 'LOAD_NAME'):
                usados.add(i.argval)
    for nome in sorted(usados - definidos):
        print(f'ERRO: {arquivo} usa "{nome}", que não está definido nem importado', file=sys.stderr)
        falha = 1
sys.exit(falha)
PY
  echo "painel OK: $(find painel -maxdepth 1 -name '*.py' | wc -l) módulos Python"
  # Idioma das telas: cada texto que o painel passa por t(), tn() ou N() tem tradução no catálogo do inglês e no do
  # espanhol, com os mesmos nomes entre chaves, as mesmas marcas do HTML e as mesmas aspas; nenhuma tradução sobra; e
  # cada mensagem de erro do allsafe-ftp-user que o painel mostra tem a sua, nos dois.
  python3 - <<'PY'
import ast
import collections
import pathlib
import re
import sys

MARCADOR = re.compile(r'\{([a-z_]+)\}')
MARCA = re.compile(r'</?[a-z]+[^>]*>')
ENTIDADE = re.compile(r'&[a-z]+;')
MENSAGEM = re.compile(r'echo "([^"]+)" >&2')
falhas = []


def texto(no):
    return no.value if isinstance(no, ast.Constant) and isinstance(no.value, str) else None


# Todo texto de t(), tn() e N() do painel, com o lugar da primeira chamada e os nomes dos valores de cada chamada.
do_codigo = {}
for arquivo in sorted(pathlib.Path('painel').glob('*.py')):
    for no in ast.walk(ast.parse(arquivo.read_text(encoding='utf-8'))):
        if not isinstance(no, ast.Call):
            continue
        nome = no.func.id if isinstance(no.func, ast.Name) else no.func.attr if isinstance(no.func, ast.Attribute) else ''
        if nome not in ('t', 'tn', 'N'):
            continue
        onde = f'{arquivo}:{no.lineno}'
        alvos = [texto(alvo) for alvo in (no.args[1:3] if nome == 'tn' else no.args[:1])]
        if nome != 't' and None in alvos:
            falhas.append(f'{onde}: {nome}() recebe o texto escrito na chamada, para ele entrar no catálogo')
        aberto = any(valor.arg is None for valor in no.keywords)
        if nome == 'tn' and any(valor.arg == 'n' for valor in no.keywords):
            falhas.append(f'{onde}: tn() já entrega a quantidade em {{n}}: o valor n não é passado')
        dados = {valor.arg for valor in no.keywords if valor.arg} | ({'n'} if nome == 'tn' else set())
        for chave in filter(None, alvos):
            do_codigo.setdefault(chave, onde)
            pedidos = set(MARCADOR.findall(chave))
            if nome != 'N' and not aberto and not pedidos <= dados:
                falhas.append(f'{onde}: faltam valores para {sorted(pedidos - dados)} em {chave[:60]!r}')
        if nome != 'N' and not aberto and all(alvos):
            sobram = dados - {'n'} - {marcador for chave in alvos for marcador in MARCADOR.findall(chave)}
            if sobram:
                falhas.append(f'{onde}: valores sem lugar no texto: {sorted(sobram)}')

# Mensagens de erro do allsafe-ftp-user, como saem do ftp/usuario.sh.
mensagens = []
for linha in pathlib.Path('ftp/usuario.sh').read_text(encoding='utf-8').splitlines():
    for mensagem in MENSAGEM.findall(linha):
        if not re.match(r'Uso:|\s+\$0 |AVISO:', mensagem):
            mensagens.append(re.sub(r'\$\{?[A-Za-z_0-9]+\}?', '7', mensagem))

# Cada catálogo é lido como texto: nada é importado nem gravado.
for arquivo, dicionario in (('idioma_en.py', 'EN'), ('idioma_es.py', 'ES')):
    catalogo, regras = {}, []
    for no in ast.parse(pathlib.Path('painel', arquivo).read_text(encoding='utf-8')).body:
        if isinstance(no, ast.Assign) and no.targets[0].id == dicionario:
            pares = [(texto(chave), texto(valor)) for chave, valor in zip(no.value.keys, no.value.values)]
            repetidas = [chave for chave, vezes in collections.Counter(chave for chave, _ in pares).items() if vezes > 1]
            if repetidas:
                falhas.append(f'{arquivo}: chave repetida: {repetidas[0][:60]!r}')
            catalogo = dict(pares)
        elif isinstance(no, ast.Assign) and no.targets[0].id == 'COMANDO':
            regras = [(re.compile(texto(par.elts[0])), texto(par.elts[1]))
                      for par in no.value.args[0].generators[0].iter.elts]

    for chave, onde in do_codigo.items():
        if chave not in catalogo:
            falhas.append(f'{onde}: texto sem tradução em painel/{arquivo}: {chave[:60]!r}')
    for chave, traducao in catalogo.items():
        if chave not in do_codigo:
            falhas.append(f'{arquivo}: tradução de texto que o painel não usa mais: {chave[:60]!r}')
            continue
        if not traducao or set(MARCADOR.findall(chave)) != set(MARCADOR.findall(traducao)):
            falhas.append(f'{arquivo}: nomes entre chaves diferentes na tradução de {chave[:60]!r}')
        for nome, regra in (('marcas do HTML', MARCA), ('entidades do HTML', ENTIDADE)):
            if collections.Counter(regra.findall(chave)) != collections.Counter(regra.findall(traducao or '')):
                falhas.append(f'{arquivo}: {nome} diferentes na tradução de {chave[:60]!r}')
        if chave.count('"') != (traducao or '').count('"'):
            falhas.append(f'{arquivo}: aspas diferentes na tradução de {chave[:60]!r}')
        if '{' in MARCADOR.sub('', traducao or '') or '}' in MARCADOR.sub('', traducao or ''):
            falhas.append(f'{arquivo}: chave solta, fora de um nome, na tradução de {chave[:60]!r}')

    # Cada mensagem de erro tem a sua regra, e nenhuma regra sobra.
    for mensagem in sorted(set(mensagens)):
        if not any(regra.fullmatch(mensagem) for regra, _ in regras):
            falhas.append(f'ftp/usuario.sh: mensagem de erro sem tradução em COMANDO ({arquivo}): {mensagem[:70]!r}')
    for regra, modelo in regras:
        if not any(regra.fullmatch(mensagem) for mensagem in mensagens):
            falhas.append(f'{arquivo}: regra de COMANDO que não casa com mensagem do ftp/usuario.sh: {regra.pattern[:70]!r}')
        elif not modelo or set(re.findall(r'\\(\d)', modelo)) != {str(n) for n in range(1, regra.groups + 1)}:
            falhas.append(f'{arquivo}: trechos variáveis diferentes na tradução da regra {regra.pattern[:70]!r}')

for falha in falhas:
    print(f'ERRO: {falha}', file=sys.stderr)
if falhas:
    sys.exit(1)
print(f'idioma OK: {len(do_codigo)} textos do painel com tradução em inglês e em espanhol, '
      f'{len(set(mensagens))} mensagens do comando de usuários')
PY
fi
# Toda variável do .env.example tem comentário na linha de cima e está explicada no guia de configuração, nos três idiomas.
awk -v guias='doc/pt-BR/configuracao.md doc/en/configuration.md doc/es/configuracion.md' '
  BEGIN { n = split(guias, guia, " "); for (i = 1; i <= n; i++) while ((getline linha < guia[i]) > 0) texto[i] = texto[i] linha "\n" }
  /^[A-Z_]+=/ {
    nome = $0; sub(/=.*/, "", nome); total++
    if (anterior !~ /^# /) { print "ERRO: " nome " sem comentário na linha de cima, no .env.example" > "/dev/stderr"; falha = 1 }
    for (i = 1; i <= n; i++) if (index(texto[i], "`" nome "`") == 0) { print "ERRO: " nome " não está em " guia[i] > "/dev/stderr"; falha = 1 }
  }
  { anterior = $0 }
  END { if (falha) exit 1; print ".env.example OK: " total " variáveis, todas comentadas e no guia de configuração, nos três idiomas" }
' .env.example
# Caminho que só existe em um computador não é publicado: nenhum arquivo do repositório cita pasta pessoal.
# Vale para o que o Git acompanha e para o que ainda não foi adicionado; o .env local fica fora, pelo .gitignore.
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  if pessoais="$(git grep -n -I --untracked -E '/(home|Users)/[A-Za-z0-9._-]+/' -- . 2>/dev/null)"; then
    echo "ERRO: pasta pessoal em arquivo do repositório; use o padrão do .env.example ou leia o valor do .env:" >&2
    printf '%s\n' "$pessoais" | cut -c1-160 | head -n 20 >&2
    exit 1
  fi
  echo "caminhos OK: nenhum arquivo do repositório cita pasta pessoal"
else
  echo "caminhos: conferência pulada (a pasta não é um repositório Git)"
fi
# Marca: todo arquivo que a imagem do nginx copia e o nginx.conf.modelo serve existe e é PNG ou ICO de verdade.
for arquivo in favicon.ico icone-32.png icone-192.png apple-touch-icon.png simbolo-64.png logo-320.png; do
  assinatura="$(head -c 4 "web/marca/$arquivo" 2>/dev/null | od -An -tx1 | tr -d ' \n')"
  case "$arquivo:$assinatura" in
    *.png:89504e47 | *.ico:00000100) ;;
    *) echo "ERRO: web/marca/$arquivo falta ou não é uma imagem válida. Rode scripts/gerar-marca.sh." >&2; exit 1 ;;
  esac
done
echo "marca OK: 6 arquivos em web/marca/"
# Licença: o LICENSE é o texto oficial da Apache-2.0, o NOTICE traz a autoria, o MARCA.md e os pares dele em espanhol
# (MARCA.es.md) e em inglês (TRADEMARK.md) existem e todo arquivo de código diz a licença dele em uma das duas
# primeiras linhas.
[[ "$(sha256sum LICENSE 2>/dev/null | cut -c1-64)" == cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30 ]] \
  || { echo "ERRO: LICENSE falta ou não é o texto oficial da Apache-2.0." >&2; exit 1; }
{ grep -q -F 'Desenvolvido pela allsafe.inf.br' NOTICE && grep -q -F 'https://github.com/allsafe-inf' NOTICE; } 2>/dev/null \
  || { echo "ERRO: NOTICE falta ou está sem a linha de autoria e o endereço do GitHub." >&2; exit 1; }
[[ -s MARCA.md ]] || { echo "ERRO: MARCA.md falta." >&2; exit 1; }
[[ -s MARCA.es.md ]] || { echo "ERRO: MARCA.es.md falta." >&2; exit 1; }
[[ -s TRADEMARK.md ]] || { echo "ERRO: TRADEMARK.md falta." >&2; exit 1; }
# Política de segurança: o SECURITY.md, em inglês, o SECURITY.pt-BR.md e o SECURITY.es.md existem, apontam para a
# variável do contato e não trazem endereço fixo.
for arquivo in SECURITY.md SECURITY.pt-BR.md SECURITY.es.md; do
  { grep -q -F 'SEGURANCA_CONTATO_EMAIL' "$arquivo" && ! grep -q -E '[A-Za-z0-9._+-]+@[A-Za-z0-9-]+\.[A-Za-z]' "$arquivo"; } 2>/dev/null \
    || { echo "ERRO: $arquivo falta, não cita SEGURANCA_CONTATO_EMAIL ou traz um endereço de e-mail fixo." >&2; exit 1; }
done
echo "política de segurança OK: SECURITY.md aponta para SEGURANCA_CONTATO_EMAIL, sem endereço fixo"
com_licenca=0; sem_licenca=0
for arquivo in Dockerfile compose.yaml compose.ipv6.yaml deploy.sh manage-user.sh scripts/*.sh ftp/*.sh ftp/*.pl painel/*.sh painel/*.py nginx/*.sh nginx/*.conf \
  nginx/*.modelo web/*.css tests/*.sh tests/etapas/*.sh; do
  if head -n 2 "$arquivo" | grep -q -F 'SPDX-License-Identifier: Apache-2.0'; then
    com_licenca=$((com_licenca + 1))
  else
    echo "ERRO: $arquivo sem a linha SPDX-License-Identifier: Apache-2.0 no começo." >&2; sem_licenca=1
  fi
done
[[ "$sem_licenca" == 0 ]] || exit 1
echo "licença OK: LICENSE (Apache-2.0), NOTICE, MARCA.md e a linha SPDX em $com_licenca arquivos de código"
# Cada perfil tem o dobro de portas passivas que de sessões: o Pure-FTPd aceita no máximo metade das portas em sessões.
for profile in .env.example profiles/*.env; do
  awk -F= -v arquivo="$profile" '
    $1 == "FTP_MAX_CLIENTS" { c = $2 } $1 == "FTP_PASSIVE_PORT_START" { i = $2 } $1 == "FTP_PASSIVE_PORT_END" { f = $2 }
    END {
      if ((f - i + 1) < 2 * c) { print "ERRO: " arquivo ": FTP_MAX_CLIENTS=" c " pede " 2 * c " portas passivas e a faixa tem " f - i + 1 > "/dev/stderr"; exit 1 }
      print "sessões OK em " arquivo ": " c " sessões, " f - i + 1 " portas passivas"
    }' "$profile"
done
for profile in profiles/*.env; do
  docker compose --env-file .env.example --env-file "$profile" config --quiet
  COMPOSE_FILE=compose.yaml:compose.ipv6.yaml docker compose --env-file .env.example --env-file "$profile" config --quiet
  echo "compose OK com $(basename "$profile")"
done
if [[ "${1:-}" == "--runtime" ]]; then
  # Confere a instalação no ar: a do .env desta pasta ou a do arquivo apontado por ENV_FILE.
  # shellcheck source=scripts/ambiente.sh
  source scripts/ambiente.sh
  env_file="${ENV_FILE:-.env}"
  [[ -f "$env_file" ]] || { echo "ERRO: $env_file não existe: não há instalação para conferir. Rode ./deploy.sh antes." >&2; exit 1; }
  compose() { docker compose --env-file "$env_file" "$@"; }
  for servico in ftp painel nginx; do
    container_id="$(compose ps -q "$servico")"
    [[ -n "$container_id" ]] || { echo "ERRO: o serviço $servico não está no ar." >&2; exit 1; }
    estado="$(docker inspect --format '{{.State.Status}}/{{if .State.Health}}{{.State.Health.Status}}{{end}}' "$container_id")"
    [[ "$estado" == running/healthy ]] || { echo "ERRO: o serviço $servico está em '$estado'; o esperado é running/healthy." >&2; exit 1; }
    echo "servico $servico: running, healthy"
  done
  usuario="$(env_valor FTP_USER transfer)"
  # O usuário inicial é criado uma vez; removido pelo administrador, fica a marca de que já existiu.
  if compose exec -T ftp pure-pw show "$usuario" -f /auth/pureftpd.passwd >/dev/null 2>&1; then
    echo "usuario inicial '$usuario' presente no PureDB"
  elif compose exec -T ftp grep -qxF -- "$usuario" /auth/usuario-inicial.criado 2>/dev/null; then
    echo "usuario inicial '$usuario' removido pelo administrador (o serviço ftp não o recria)"
  else
    echo "ERRO: o usuário inicial '$usuario' não está no PureDB nem consta como removido." >&2; exit 1
  fi
fi
echo "Validacao FTP concluida."
