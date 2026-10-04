#!/usr/bin/env bash
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
