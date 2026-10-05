#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Funções de rede, usadas pelo deploy.sh e pelos entrypoints (carregue com `source`).
# Por padrão a stack só publica em IPv4 privado: 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12 e 192.168.0.0/16.
# CGNAT (100.64.0.0/10) e qualquer IP público só passam com REDE_PERMITIR_IP_PUBLICO=sim, por escolha
# de quem instala. IPv6 e 0.0.0.0 ficam de fora sempre: o endereço é escolhido, nunca "todos".

# ipv4_valido <ip>: verdadeiro para um IPv4 bem formado; os octetos ficam em IPV4_A a IPV4_D.
ipv4_valido() {
  local octeto='(0|[1-9][0-9]{0,2})'
  [[ "${1:-}" =~ ^${octeto}\.${octeto}\.${octeto}\.${octeto}$ ]] || return 1
  IPV4_A=${BASH_REMATCH[1]} IPV4_B=${BASH_REMATCH[2]} IPV4_C=${BASH_REMATCH[3]} IPV4_D=${BASH_REMATCH[4]}
  (( IPV4_A <= 255 && IPV4_B <= 255 && IPV4_C <= 255 && IPV4_D <= 255 ))
}

# ip_privado <ip>: verdadeiro só para um IPv4 bem formado dentro das faixas privadas.
ip_privado() {
  ipv4_valido "${1:-}" || return 1
  (( IPV4_A == 127 || IPV4_A == 10 || (IPV4_A == 172 && IPV4_B >= 16 && IPV4_B <= 31) || (IPV4_A == 192 && IPV4_B == 168) ))
}

# ip_utilizavel <ip>: IPv4 que um servidor pode ter. Ficam de fora 0.0.0.0/8, multicast e reservados.
ip_utilizavel() {
  ipv4_valido "${1:-}" || return 1
  (( IPV4_A >= 1 && IPV4_A <= 223 ))
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

# cidr_utilizavel <ip/prefixo>: rede IPv4 com prefixo de 8 a 32. "Todo mundo" (/0 a /7) não entra.
cidr_utilizavel() {
  local ip="${1%/*}" prefixo="${1#*/}"
  [[ "${1:-}" == */* && "$prefixo" =~ ^[0-9]{1,2}$ ]] || return 1
  ip_utilizavel "$ip" || return 1
  (( 10#$prefixo >= 8 && 10#$prefixo <= 32 ))
}

# ip_publico_permitido: verdadeiro quando quem instalou escolheu aceitar IP público.
ip_publico_permitido() {
  case "${REDE_PERMITIR_IP_PUBLICO:-nao}" in
    sim) return 0 ;;
    nao) return 1 ;;
    *) echo "FALHA: REDE_PERMITIR_IP_PUBLICO deve ser 'nao' ou 'sim'; está '${REDE_PERMITIR_IP_PUBLICO}'." >&2; exit 1 ;;
  esac
}

# conferir_opcao_ip_publico: para logo no começo se REDE_PERMITIR_IP_PUBLICO não for 'nao' nem 'sim'.
conferir_opcao_ip_publico() { ip_publico_permitido || true; }

# exigir_ip <nome da variável> <valor>: para com mensagem clara se o endereço não for aceito.
exigir_ip() {
  ip_privado "$2" && return 0
  if ip_publico_permitido; then
    ip_utilizavel "$2" && return 0
    echo "FALHA: $1=$2 não é um endereço IPv4 de servidor (0.0.0.0, multicast e reservados são recusados)." >&2
    return 1
  fi
  echo "FALHA: $1=$2 não é IP privado. Por padrão esta stack é só para rede interna:" >&2
  echo "       use 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12 ou 192.168.0.0/16 (0.0.0.0 é sempre recusado)." >&2
  echo "       IP público só com REDE_PERMITIR_IP_PUBLICO=sim, e com firewall: leia o alerta no .env.example." >&2
  return 1
}

# exigir_rede <nome da variável> <rede>: o mesmo, para uma rede em notação CIDR.
exigir_rede() {
  cidr_privado "$2" && return 0
  if ip_publico_permitido; then
    cidr_utilizavel "$2" && return 0
    echo "FALHA: $1: '$2' não é uma rede IPv4 aceita (prefixo de /8 a /32; 'todo mundo' é recusado)." >&2
    return 1
  fi
  echo "FALHA: $1: '$2' não é rede privada. Por padrão esta stack é só para rede interna." >&2
  echo "       Rede pública só com REDE_PERMITIR_IP_PUBLICO=sim, e com firewall: leia o alerta no .env.example." >&2
  return 1
}

# aviso_ip_publico: alerta fixo, mostrado sempre que a opção está ligada.
aviso_ip_publico() {
  ip_publico_permitido || return 0
  echo "ALERTA: REDE_PERMITIR_IP_PUBLICO=sim: a stack aceita endereço público. FTP e painel na internet são alvo"
  echo "        de varredura e de tentativa de senha o tempo todo. Só use com firewall no servidor liberando apenas"
  echo "        os endereços dos equipamentos e de quem administra, com TLS obrigatório e senhas geradas."
  echo "        Sem firewall, o risco é de quem ligou a opção."
}
