#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Funções de rede, usadas pelo deploy.sh e pelos entrypoints (carregue com `source`).
# Por padrão a stack só publica em IPv4 privado: 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12 e 192.168.0.0/16.
# CGNAT (100.64.0.0/10) e qualquer IP público só passam com REDE_PERMITIR_IP_PUBLICO=sim, por escolha
# de quem instala. 0.0.0.0 fica de fora sempre: o endereço é escolhido, nunca "todos".
# IPv6 segue a mesma regra, e só é publicado com REDE_IPV6=sim: privado é ::1 e a faixa local única (fc00::/7);
# o global (2000::/3) só passa com a mesma opção. Ficam de fora sempre '::', enlace local (fe80::/10), multicast,
# IPv4 escrito em IPv6, zona (%) e colchetes.
# Publicar só o painel, por proxy ou túnel, é a outra opção de quem instala: PAINEL_PROXY_CONFIAVEL.

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

# ipv6_valido <endereço>: verdadeiro para um IPv6 bem formado, sem máscara, sem zona e sem IPv4 escrito dentro.
# O endereço por extenso fica em IPV6_HEX: 32 dígitos hexadecimais minúsculos.
ipv6_valido() {
  local texto="${1:-}" grupos='([0-9A-Fa-f]{1,4}(:[0-9A-Fa-f]{1,4})*)?' grupo hex='' faltam=0
  local -a antes=() depois=()
  if [[ "$texto" == *::* ]]; then
    [[ "${texto%%::*}" =~ ^${grupos}$ && "${texto#*::}" =~ ^${grupos}$ ]] || return 1
    IFS=':' read -r -a antes <<< "${texto%%::*}"
    IFS=':' read -r -a depois <<< "${texto#*::}"
    faltam=$(( 8 - ${#antes[@]} - ${#depois[@]} ))
    (( faltam >= 1 )) || return 1
  else
    [[ "$texto" =~ ^${grupos}$ ]] || return 1
    IFS=':' read -r -a antes <<< "$texto"
    (( ${#antes[@]} == 8 )) || return 1
  fi
  for grupo in "${antes[@]}"; do printf -v grupo '%04x' "0x$grupo"; hex+="$grupo"; done
  for (( ; faltam > 0; faltam-- )); do hex+=0000; done
  for grupo in "${depois[@]}"; do printf -v grupo '%04x' "0x$grupo"; hex+="$grupo"; done
  IPV6_HEX=$hex
}

# ip6_privado <endereço>: verdadeiro só para ::1 e para a faixa local única (fc00::/7).
ip6_privado() {
  ipv6_valido "${1:-}" || return 1
  [[ "$IPV6_HEX" == 00000000000000000000000000000001 || "$IPV6_HEX" == f[cd]* ]]
}

# ip6_utilizavel <endereço>: IPv6 que um servidor pode ter: os privados e os globais (2000::/3). Ficam de fora '::',
# enlace local, multicast e IPv4 escrito em IPv6.
ip6_utilizavel() {
  ipv6_valido "${1:-}" || return 1
  [[ "$IPV6_HEX" == 00000000000000000000000000000001 || "$IPV6_HEX" == f[cd]* || "$IPV6_HEX" == [23]* ]]
}

# cidr6_privado <endereço/prefixo>: verdadeiro só para ::1/128 e para uma rede inteira dentro da faixa local única.
cidr6_privado() {
  local ip="${1%/*}" prefixo="${1#*/}"
  [[ "${1:-}" == */* && "$prefixo" =~ ^(0|[1-9][0-9]{0,2})$ ]] || return 1
  ip6_privado "$ip" || return 1
  if [[ "$IPV6_HEX" == f[cd]* ]]; then
    (( prefixo >= 7 && prefixo <= 128 ))
  else
    (( prefixo == 128 ))
  fi
}

# cidr6_utilizavel <endereço/prefixo>: rede IPv6 privada, ou global com prefixo de 16 a 128. "Todo mundo" não entra.
cidr6_utilizavel() {
  local ip="${1%/*}" prefixo="${1#*/}"
  cidr6_privado "${1:-}" && return 0
  [[ "${1:-}" == */* && "$prefixo" =~ ^(0|[1-9][0-9]{0,2})$ ]] || return 1
  ipv6_valido "$ip" && [[ "$IPV6_HEX" == [23]* ]] || return 1
  (( prefixo >= 16 && prefixo <= 128 ))
}

# ip6_na_rede <endereço> <endereço/prefixo>: verdadeiro quando o endereço IPv6 está dentro da rede.
ip6_na_rede() {
  local ip rede prefixo="${2#*/}" inteiros resto
  ipv6_valido "${1:-}" || return 1
  ip=$IPV6_HEX
  [[ "${2:-}" == */* && "$prefixo" =~ ^(0|[1-9][0-9]{0,2})$ ]] && (( prefixo <= 128 )) && ipv6_valido "${2%/*}" || return 1
  rede=$IPV6_HEX
  inteiros=$(( prefixo / 4 )) resto=$(( prefixo % 4 ))
  [[ "${ip:0:inteiros}" == "${rede:0:inteiros}" ]] || return 1
  (( resto == 0 )) && return 0
  (( (0x${ip:inteiros:1} >> (4 - resto)) == (0x${rede:inteiros:1} >> (4 - resto)) ))
}

# rede_ipv6: verdadeiro quando quem instalou ligou o IPv6 na stack.
rede_ipv6() {
  case "${REDE_IPV6:-nao}" in
    sim) return 0 ;;
    nao) return 1 ;;
    *) echo "FALHA: REDE_IPV6 deve ser 'nao' ou 'sim'; está '${REDE_IPV6}'." >&2; exit 1 ;;
  esac
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

# exigir_ip6 <nome da variável> <valor>: o mesmo, para um endereço IPv6 (sem colchetes).
exigir_ip6() {
  ip6_privado "$2" && return 0
  if ip_publico_permitido; then
    ip6_utilizavel "$2" && return 0
    echo "FALHA: $1=$2 não é um endereço IPv6 de servidor ('::', enlace local, multicast e IPv4 escrito em IPv6" >&2
    echo "       são recusados; o endereço vai sem colchetes e sem zona)." >&2
    return 1
  fi
  echo "FALHA: $1=$2 não é IPv6 privado. Por padrão esta stack é só para rede interna:" >&2
  echo "       use ::1 ou a faixa local única (fc00::/7), sem colchetes ('::' é sempre recusado)." >&2
  echo "       IPv6 público só com REDE_PERMITIR_IP_PUBLICO=sim, e com firewall: leia o alerta no .env.example." >&2
  return 1
}

# exigir_subrede_ipv6 <nome da variável> <rede>: a rede dos containers em IPv6 é sempre local única, /64.
exigir_subrede_ipv6() {
  if [[ "$2" == */64 ]] && ipv6_valido "${2%/*}" && [[ "$IPV6_HEX" == f[cd]* && "${IPV6_HEX:16}" == 0000000000000000 ]]; then
    return 0
  fi
  echo "FALHA: $1=$2 não serve. A rede dos containers em IPv6 é uma faixa local única (dentro de fc00::/7)," >&2
  echo "       com prefixo /64 e sem bits de máquina, como fd29:1::/64." >&2
  return 1
}

# exigir_rede <nome da variável> <rede>: o mesmo, para uma rede em notação CIDR, IPv4 ou IPv6.
exigir_rede() {
  if [[ "$2" == *:* ]]; then
    cidr6_privado "$2" && return 0
    if ip_publico_permitido; then
      cidr6_utilizavel "$2" && return 0
      echo "FALHA: $1: '$2' não é uma rede IPv6 aceita (prefixo de /16 a /128; 'todo mundo' é recusado)." >&2
      return 1
    fi
    echo "FALHA: $1: '$2' não é rede IPv6 privada (::1/128 ou dentro de fc00::/7). Por padrão esta stack é só" >&2
    echo "       para rede interna. Rede pública só com REDE_PERMITIR_IP_PUBLICO=sim, e com firewall." >&2
    return 1
  fi
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

# ip_na_rede <ip> <ip/prefixo>: verdadeiro quando o endereço está dentro da rede, as duas da mesma família.
ip_na_rede() {
  local ip rede prefixo="${2#*/}" mascara
  if [[ "${1:-}" == *:* ]]; then ip6_na_rede "$@"; return; fi
  ipv4_valido "${1:-}" || return 1
  ip=$(( (IPV4_A << 24) | (IPV4_B << 16) | (IPV4_C << 8) | IPV4_D ))
  [[ "${2:-}" == */* && "$prefixo" =~ ^[0-9]{1,2}$ ]] && (( 10#$prefixo <= 32 )) && ipv4_valido "${2%/*}" || return 1
  rede=$(( (IPV4_A << 24) | (IPV4_B << 16) | (IPV4_C << 8) | IPV4_D ))
  mascara=$(( (0xFFFFFFFF << (32 - 10#$prefixo)) & 0xFFFFFFFF ))
  (( (ip & mascara) == (rede & mascara) ))
}

# exigir_proxies <lista> <redes permitidas>: confere PAINEL_PROXY_CONFIAVEL, os endereços de onde o nginx aceita
# o endereço do cliente em X-Forwarded-For. Vazio = nenhum. Só endereço, um a um e no máximo oito: rede inteira
# não entra, porque qualquer máquina dela poderia se passar por outro cliente. Cada um tem de estar em uma das
# redes de PAINEL_REDES_PERMITIDAS: fora delas o nginx recusaria o próprio proxy.
exigir_proxies() {
  local item rede dentro; local -a itens redes
  [[ -n "${1// /}" ]] || return 0
  IFS=',' read -r -a itens <<< "$1"
  IFS=',' read -r -a redes <<< "${2:-}"
  if (( ${#itens[@]} > 8 )); then
    echo "FALHA: PAINEL_PROXY_CONFIAVEL aceita até 8 endereços; tem ${#itens[@]}." >&2
    return 1
  fi
  for item in "${itens[@]}"; do
    item="${item// /}"
    if ipv6_valido "$item"; then
      exigir_ip6 PAINEL_PROXY_CONFIAVEL "$item" || return 1
    elif ipv4_valido "$item"; then
      exigir_ip PAINEL_PROXY_CONFIAVEL "$item" || return 1
    else
      echo "FALHA: PAINEL_PROXY_CONFIAVEL: '$item' não é um endereço IPv4 nem IPv6. Informe o endereço do proxy ou" >&2
      echo "       do túnel, um a um, sem máscara e sem colchetes: rede inteira não é aceita." >&2
      return 1
    fi
    dentro=nao
    for rede in "${redes[@]}"; do
      ip_na_rede "$item" "${rede// /}" && dentro=sim
    done
    if [[ "$dentro" == nao ]]; then
      echo "FALHA: PAINEL_PROXY_CONFIAVEL: $item está fora de PAINEL_REDES_PERMITIDAS: o nginx recusaria o proxy." >&2
      return 1
    fi
  done
}

# aviso_ip_publico: alerta fixo, mostrado sempre que a opção está ligada.
aviso_ip_publico() {
  ip_publico_permitido || return 0
  echo "ALERTA: REDE_PERMITIR_IP_PUBLICO=sim: a stack aceita endereço público, por opção de quem instalou. FTP e"
  echo "        painel na internet são alvo de varredura e de tentativa de senha o tempo todo. Use com firewall no"
  echo "        servidor liberando apenas os endereços dos equipamentos e de quem administra, com TLS obrigatório"
  echo "        e senhas geradas. A escolha e o risco são de quem ligou a opção."
}

# aviso_proxy: alerta fixo, mostrado sempre que o painel está publicado por proxy ou túnel.
aviso_proxy() {
  [[ -n "${PAINEL_PROXY_CONFIAVEL// /}" ]] || return 0
  echo "ALERTA: PAINEL_PROXY_CONFIAVEL=${PAINEL_PROXY_CONFIAVEL// /}: o painel está publicado por proxy ou túnel, por opção de"
  echo "        quem instalou. O endereço de quem acessa passa a ser o que esse proxy informa em X-Forwarded-For, e"
  echo "        quem pode chegar à tela de entrada é decidido lá: restrinja o acesso no proxy ou no túnel. O FTP não"
  echo "        passa por ele e continua só nos endereços desta stack."
}
