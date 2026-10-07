#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -Eeuo pipefail
root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$root_dir"
action="${1:-}"
user="${2:-}"
pasta="${3:-}"
case "$action" in
  list|del|add|passwd|pasta|limites|tls-dispensar|tls-exigir|tls-lista) ;;
  *)
    echo "Uso: $0 add|passwd|pasta|del|list|tls-dispensar|tls-exigir|tls-lista [usuario] [pasta]" >&2
    echo "     $0 limites <usuario> [sessoes=N] [download=KB] [envio=KB] [horario=HHMM-HHMM] [baixar=N]" >&2
    exit 2 ;;
esac
# Instalação a operar: a do .env desta pasta ou a do arquivo apontado por ENV_FILE.
env_file="${ENV_FILE:-.env}"
[[ -f "$env_file" ]] || { echo "ERRO: $env_file não existe: rode ./deploy.sh antes." >&2; exit 1; }
compose() { docker compose --env-file "$env_file" "$@"; }
case "$action" in
  list|del|tls-dispensar|tls-exigir|tls-lista)
    compose exec -T ftp allsafe-ftp-user "$action" "$user"
    ;;
  pasta)
    # Troca a pasta do usuário; os arquivos da pasta anterior continuam nela.
    [[ -n "$user" && -n "$pasta" ]] || { echo "Uso: $0 pasta <usuario> <pasta>" >&2; exit 2; }
    compose exec -T ftp allsafe-ftp-user pasta "$user" "$pasta"
    ;;
  limites)
    # Sem pares, mostra os limites do usuário; com pares, grava os que vieram (valor vazio tira o limite).
    [[ -n "$user" ]] || { echo "Uso: $0 limites <usuario> [chave=valor ...]" >&2; exit 2; }
    compose exec -T ftp allsafe-ftp-user limites "$user" "${@:3}"
    ;;
  add|passwd)
    read -r -s -p "Senha para $user: " password
    echo
    # A pasta só vale no add: sem ela, a pasta do usuário leva o nome dele.
    printf '%s\n' "$password" | compose exec -T ftp allsafe-ftp-user "$action" "$user" ${pasta:+"$pasta"}
    unset password
    ;;
esac

