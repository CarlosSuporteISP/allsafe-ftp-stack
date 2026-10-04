#!/usr/bin/env bash
# Funções de rede privada, usadas pelo deploy.sh e pelos entrypoints (carregue com `source`).
# A stack só publica em IPv4 privado: 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12 e 192.168.0.0/16.
# CGNAT (100.64.0.0/10), IPv6, 0.0.0.0 e qualquer IP público ficam de fora de propósito.

# ip_privado <ip>: verdadeiro só para um IPv4 bem formado dentro das faixas privadas.
ip_privado() {
  local octeto='(0|[1-9][0-9]{0,2})' a b c d
  [[ "${1:-}" =~ ^${octeto}\.${octeto}\.${octeto}\.${octeto}$ ]] || return 1
  a=${BASH_REMATCH[1]} b=${BASH_REMATCH[2]} c=${BASH_REMATCH[3]} d=${BASH_REMATCH[4]}
  (( a <= 255 && b <= 255 && c <= 255 && d <= 255 )) || return 1
  (( a == 127 || a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168) ))
}

# cidr_privado <ip/prefixo>: verdadeiro só para uma rede inteira dentro de uma faixa privada.
cidr_privado() {
  local ip="${1%/*}" prefixo="${1#*/}" minimo
  [[ "${1:-}" == */* && "$prefixo" =~ ^[0-9]{1,2}$ ]] || return 1
  ip_privado "$ip" || return 1
  case "${ip%%.*}" in
    127|10) minimo=8 ;;
    172) minimo=12 ;;
    *) minimo=16 ;;
  esac
  (( 10#$prefixo >= minimo && 10#$prefixo <= 32 ))
}

# exigir_ip_privado <nome da variável> <valor>: para com mensagem clara se o valor não for privado.
exigir_ip_privado() {
  ip_privado "$2" && return 0
  echo "FALHA: $1=$2 não é IP privado. Esta stack é só para rede interna:" >&2
  echo "       use 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12 ou 192.168.0.0/16 (0.0.0.0 e IP público são recusados)." >&2
  return 1
}
