#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa A: sem nada no ar. Funções de rede e validação estática.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

ruins=""; total=0
for item in 127.0.0.1=s 127.255.255.254=s 10.0.0.1=s 10.255.255.255=s 172.16.0.1=s 172.31.255.254=s 192.168.0.1=s 192.168.255.255=s \
            0.0.0.0=n 8.8.8.8=n 200.1.2.3=n 11.0.0.1=n 172.15.255.255=n 172.32.0.1=n 192.167.1.1=n 192.169.1.1=n 100.64.0.1=n 169.254.1.1=n \
            10.0.0.256=n 10.0.0=n 10.0.0.1.1=n 010.0.0.1=n ::1=n fd00::1=n localhost=n =n 10.0.0.1/8=n; do
  total=$((total + 1)); ip_privado "${item%=*}" && obtido=s || obtido=n
  [[ "$obtido" == "${item##*=}" ]] || ruins+=" ${item%=*}"
done
redes=0
for item in 127.0.0.0/8=s 10.0.0.0/8=s 172.16.0.0/12=s 192.168.0.0/16=s 192.168.10.0/24=s 10.1.2.3/32=s \
            0.0.0.0/0=n 10.0.0.0/7=n 172.16.0.0/11=n 192.168.0.0/15=n 8.8.8.0/24=n 100.64.0.0/10=n 10.0.0.0/33=n 10.0.0.0=n 10.0.0.0/=n; do
  redes=$((redes + 1)); cidr_privado "${item%=*}" && obtido=s || obtido=n
  [[ "$obtido" == "${item##*=}" ]] || ruins+=" ${item%=*}"
done
[[ -z "$ruins" ]]; caso $? seguranca 21 "Função ip_privado" "$total endereços e $redes redes conferidos (privados, públicos, CGNAT, link-local, IPv6 e malformados): ${ruins:+divergência em$ruins}${ruins:-nenhuma divergência}"

# Com REDE_PERMITIR_IP_PUBLICO=sim valem ip_utilizavel e cidr_utilizavel: qualquer IPv4 de servidor,
# menos "todos os endereços", multicast e reservados; rede só de /8 a /32.
ruins=""; total=0
for item in 8.8.8.8=s 203.0.113.10=s 100.64.0.1=s 223.255.255.254=s 10.0.0.1=s 127.0.0.1=s \
            0.0.0.0=n 0.1.2.3=n 224.0.0.1=n 240.0.0.1=n 255.255.255.255=n 256.1.1.1=n 8.8.8=n 08.8.8.8=n ::1=n localhost=n =n 8.8.8.8/32=n; do
  total=$((total + 1)); ip_utilizavel "${item%=*}" && obtido=s || obtido=n
  [[ "$obtido" == "${item##*=}" ]] || ruins+=" ${item%=*}"
done
redes=0
for item in 203.0.113.0/24=s 8.0.0.0/8=s 100.64.0.0/10=s 198.51.100.7/32=s 192.168.0.0/16=s \
            0.0.0.0/0=n 8.0.0.0/7=n 128.0.0.0/1=n 0.0.0.0/8=n 224.0.0.0/8=n 8.8.8.0/33=n 8.8.8.0=n 8.8.8.0/=n; do
  redes=$((redes + 1)); cidr_utilizavel "${item%=*}" && obtido=s || obtido=n
  [[ "$obtido" == "${item##*=}" ]] || ruins+=" ${item%=*}"
done
# exigir_ip e exigir_rede: a opção muda o que passa. Cada chamada em subshell, porque valor inválido encerra.
exigencias=0
for item in 'nao exigir_ip 10.0.0.1 0' 'nao exigir_ip 8.8.8.8 1' 'sim exigir_ip 8.8.8.8 0' 'sim exigir_ip 0.0.0.0 1' 'sim exigir_ip 224.0.0.1 1' \
            'nao exigir_rede 192.168.0.0/16 0' 'nao exigir_rede 8.8.8.0/24 1' 'sim exigir_rede 8.8.8.0/24 0' 'sim exigir_rede 0.0.0.0/0 1' \
            'talvez exigir_ip 8.8.8.8 1' 'SIM exigir_rede 8.8.8.0/24 1'; do
  read -r opcao funcao valor esperado <<< "$item"
  exigencias=$((exigencias + 1))
  ( REDE_PERMITIR_IP_PUBLICO="$opcao"; "$funcao" TESTE "$valor" ) > /dev/null 2>&1; obtido=$?
  [[ "$obtido" == "$esperado" ]] || ruins+=" $opcao:$funcao:$valor"
done
[[ -z "$ruins" ]]; caso $? seguranca 40 "Funções da opção de IP público" "ip_utilizavel: $total endereços · cidr_utilizavel: $redes redes · exigir_ip e exigir_rede com a opção em nao, sim e valor inválido: $exigencias chamadas · ${ruins:+divergência em$ruins}${ruins:-nenhuma divergência}"

./scripts/validate.sh > "$W/validate.log" 2>&1; r=$?
perfis="$(find profiles -maxdepth 1 -name '*.env' | wc -l)"
[[ "$r" == 0 && "$(grep -c '^compose OK' "$W/validate.log")" == "$perfis" ]] && grep -q '^Validacao FTP concluida\.$' "$W/validate.log"
caso $? testes 1 "Validação estática" "validate.sh: saída $r · compose OK em $(grep -c '^compose OK' "$W/validate.log") de $perfis perfis · $(tail -1 "$W/validate.log")"
