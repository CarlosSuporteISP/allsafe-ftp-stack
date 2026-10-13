#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -Eeuo pipefail
root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$root_dir"
action="${1:-}"
user="${2:-}"
pasta="${3:-}"
case "$action" in
  list|del|add|passwd|pasta|perfil|limites|retencao|outras|bloqueios|desbloquear|tls-dispensar|tls-exigir|tls-lista) ;;
  enderecos|endereco-bloquear|endereco-liberar) ;;
  *)
    echo "Uso: $0 add|passwd|pasta|del|list|tls-dispensar|tls-exigir|tls-lista [usuario] [pasta] [perfil]" >&2
    echo "     $0 perfil <usuario> [completo|envio|soenvio|leitura]" >&2
    echo "     $0 limites <usuario> [sessoes=N] [download=KB] [envio=KB] [horario=HHMM-HHMM] [baixar=N] [tentativas=N] [minutos=N] [enviar=1]" >&2
    echo "     $0 retencao <usuario> [ultimos=N] [dias=N]" >&2
    echo "     $0 outras <usuario> [<pasta> leitura|envio|completo|nenhuma]" >&2
    echo "     $0 bloqueios [usuario]" >&2
    echo "     $0 desbloquear <usuario> [origem]" >&2
    echo "     $0 enderecos" >&2
    echo "     $0 endereco-bloquear <endereco ou prefixo> [dias]" >&2
    echo "     $0 endereco-liberar <endereco ou prefixo>" >&2
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
  perfil)
    # Sem o perfil, mostra o do usuário; com ele, troca: completo (envia, baixa e apaga), envio (envia e baixa),
    # soenvio (só envia: não lista nem baixa) ou leitura (só lista e baixa). Vale na próxima entrada no FTP.
    [[ -n "$user" ]] || { echo "Uso: $0 perfil <usuario> [completo|envio|soenvio|leitura]" >&2; exit 2; }
    compose exec -T ftp allsafe-ftp-user perfil "$user" ${pasta:+"$pasta"}
    ;;
  limites)
    # Sem pares, mostra os limites do usuário; com pares, grava os que vieram (valor vazio tira o limite).
    # enviar=1 dá ao usuário a permissão de enviar arquivo pelo painel web; enviar= tira.
    [[ -n "$user" ]] || { echo "Uso: $0 limites <usuario> [chave=valor ...]" >&2; exit 2; }
    compose exec -T ftp allsafe-ftp-user limites "$user" "${@:3}"
    ;;
  retencao)
    # Limpeza automática da pasta do usuário: ultimos=N mantém só os N arquivos mais recentes de cada pasta, e dias=N
    # apaga o arquivo que está há mais de N dias no servidor. Sem pares, mostra a regra; valor vazio desliga aquela parte.
    [[ -n "$user" ]] || { echo "Uso: $0 retencao <usuario> [ultimos=N] [dias=N]" >&2; exit 2; }
    compose exec -T ftp allsafe-ftp-user retencao "$user" "${@:3}"
    ;;
  outras)
    # Outras pastas do usuário, além da do cadastro, com a permissão de cada uma: valem só no painel web. Sem a pasta,
    # mostra as que ele tem; com a pasta e a permissão, concede ou troca; a permissão "nenhuma" retira.
    [[ -n "$user" && ( $# -eq 2 || $# -eq 4 ) ]] || { echo "Uso: $0 outras <usuario> [<pasta> leitura|envio|completo|nenhuma]" >&2; exit 2; }
    compose exec -T ftp allsafe-ftp-user outras "$user" "${@:3}"
    ;;
  bloqueios)
    # Bloqueios por tentativa em vigor, de todos ou de um usuário.
    compose exec -T ftp allsafe-ftp-user bloqueios ${user:+"$user"}
    ;;
  desbloquear)
    # Tira o bloqueio por tentativa do usuário: de todas as origens ou só da que vier.
    [[ -n "$user" ]] || { echo "Uso: $0 desbloquear <usuario> [origem]" >&2; exit 2; }
    compose exec -T ftp allsafe-ftp-user desbloquear "$user" ${pasta:+"$pasta"}
    ;;
  enderecos)
    # Endereços bloqueados agora, no FTP e no painel.
    compose exec -T ftp allsafe-ftp-user enderecos
    ;;
  endereco-bloquear)
    # Bloqueia um endereço ou um prefixo (IPv4 ou IPv6) no FTP e no painel, ou muda o prazo de um que já está bloqueado.
    # Sem os dias, o prazo da stack. O bloqueio automático nunca alcança prefixo: prefixo só entra por aqui ou pelo painel.
    [[ -n "$user" && $# -le 3 ]] || { echo "Uso: $0 endereco-bloquear <endereco ou prefixo> [dias]" >&2; exit 2; }
    compose exec -T ftp allsafe-ftp-user endereco-bloquear "$user" ${pasta:+"$pasta"}
    ;;
  endereco-liberar)
    # Libera um endereço ou um prefixo bloqueado. É a saída para o administrador que ficou com o próprio endereço bloqueado.
    [[ -n "$user" && $# -le 2 ]] || { echo "Uso: $0 endereco-liberar <endereco ou prefixo>" >&2; exit 2; }
    compose exec -T ftp allsafe-ftp-user endereco-liberar "$user"
    ;;
  add|passwd)
    read -r -s -p "Senha para $user: " password
    echo
    # A pasta e o perfil só valem no add: sem a pasta, a do usuário leva o nome dele; sem o perfil, é completo.
    perfil="${4:-}"
    [[ -z "$perfil" || "$action" == add ]] || { echo "Uso: $0 passwd <usuario>" >&2; exit 2; }
    printf '%s\n' "$password" | compose exec -T ftp allsafe-ftp-user "$action" "$user" ${pasta:+"$pasta"} ${perfil:+"$perfil"}
    unset password
    ;;
esac

