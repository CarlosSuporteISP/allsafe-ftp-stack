#!/usr/bin/env bash
set -Eeuo pipefail
root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"
for script in deploy.sh manage-user.sh scripts/*.sh; do bash -n "$script"; done
# O host não precisa de Python; se tiver, confere a sintaxe do painel sem gravar nada.
if command -v python3 >/dev/null 2>&1; then
  python3 -c 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1])' painel/servidor.py
  echo "painel/servidor.py OK"
fi
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
