#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -Eeuo pipefail
root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"
for script in deploy.sh manage-user.sh scripts/*.sh ftp/*.sh painel/*.sh nginx/*.sh tests/*.sh tests/etapas/*.sh; do bash -n "$script"; done
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
fi
# Toda variável do .env.example tem comentário na linha de cima e está explicada no guia de configuração.
awk -v guia=doc/configuracao.md '
  BEGIN { while ((getline linha < guia) > 0) texto = texto linha "\n" }
  /^[A-Z_]+=/ {
    nome = $0; sub(/=.*/, "", nome); total++
    if (anterior !~ /^# /) { print "ERRO: " nome " sem comentário na linha de cima, no .env.example" > "/dev/stderr"; falha = 1 }
    if (index(texto, "`" nome "`") == 0) { print "ERRO: " nome " não está em " guia > "/dev/stderr"; falha = 1 }
  }
  { anterior = $0 }
  END { if (falha) exit 1; print ".env.example OK: " total " variáveis, todas comentadas e no guia de configuração" }
' .env.example
# Marca: todo arquivo que a imagem do nginx copia e o nginx.conf.modelo serve existe e é PNG ou ICO de verdade.
for arquivo in favicon.ico icone-32.png icone-192.png apple-touch-icon.png simbolo-64.png logo-320.png; do
  assinatura="$(head -c 4 "web/marca/$arquivo" 2>/dev/null | od -An -tx1 | tr -d ' \n')"
  case "$arquivo:$assinatura" in
    *.png:89504e47 | *.ico:00000100) ;;
    *) echo "ERRO: web/marca/$arquivo falta ou não é uma imagem válida. Rode scripts/gerar-marca.sh." >&2; exit 1 ;;
  esac
done
echo "marca OK: 6 arquivos em web/marca/"
# Licença: o LICENSE é o texto oficial da Apache-2.0, o NOTICE traz a autoria, o MARCA.md existe e todo
# arquivo de código diz a licença dele em uma das duas primeiras linhas.
[[ "$(sha256sum LICENSE 2>/dev/null | cut -c1-64)" == cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30 ]] \
  || { echo "ERRO: LICENSE falta ou não é o texto oficial da Apache-2.0." >&2; exit 1; }
{ grep -q -F 'Desenvolvido pela allsafe.inf.br' NOTICE && grep -q -F 'https://github.com/allsafe-inf' NOTICE; } 2>/dev/null \
  || { echo "ERRO: NOTICE falta ou está sem a linha de autoria e o endereço do GitHub." >&2; exit 1; }
[[ -s MARCA.md ]] || { echo "ERRO: MARCA.md falta." >&2; exit 1; }
com_licenca=0; sem_licenca=0
for arquivo in Dockerfile compose.yaml deploy.sh manage-user.sh scripts/*.sh ftp/*.sh painel/*.sh painel/*.py nginx/*.sh nginx/*.conf \
  nginx/*.modelo web/*.css tests/*.sh tests/etapas/*.sh; do
  if head -n 2 "$arquivo" | grep -q -F 'SPDX-License-Identifier: Apache-2.0'; then
    com_licenca=$((com_licenca + 1))
  else
    echo "ERRO: $arquivo sem a linha SPDX-License-Identifier: Apache-2.0 no começo." >&2; sem_licenca=1
  fi
done
[[ "$sem_licenca" == 0 ]] || exit 1
echo "licença OK: LICENSE (Apache-2.0), NOTICE, MARCA.md e a linha SPDX em $com_licenca arquivos de código"
for profile in profiles/*.env; do
  docker compose --env-file .env.example --env-file "$profile" config --quiet
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
  compose exec -T ftp pure-pw show "$usuario" -f /auth/pureftpd.passwd >/dev/null \
    || { echo "ERRO: o usuário inicial '$usuario' não está no PureDB." >&2; exit 1; }
  echo "usuario inicial '$usuario' presente no PureDB"
fi
echo "Validacao FTP concluida."
