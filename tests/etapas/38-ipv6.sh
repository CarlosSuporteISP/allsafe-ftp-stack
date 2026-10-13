#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa AL: IPv6. Desligado por padrão, REDE_IPV6=sim publica o FTP e o painel também em IPv6 e dá uma sub-rede
# IPv6 à rede dos containers. A etapa prova as recusas do deploy.sh e dos containers, a subida, o FTP com TLS e o
# painel por IPv6 com o endereço de quem chega, o Host em IPv6, o bloqueio de um endereço IPv6 de fora, o cliente
# IPv6 fora das redes permitidas recusado pelo nginx, o proxy e o nome do certificado em IPv6, e a volta a 'nao'.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.
#
# Só entram endereços de teste: o do próprio host (TESTE_IP6, ::1), faixas locais únicas (TESTE_SUBNET6 e
# TESTE_SUBNET6_B) e a faixa de documentação 2001:db8::/32, esta só em recusa e em conferência, sem conexão.
# Pela porta publicada, o cliente deste host chega com o gateway IPv6 da rede da stack, que nunca é bloqueado
# sozinho. O endereço de fora vem de uma rede a mais, ligada aos containers depois de eles subirem (como na etapa
# do bloqueio por endereço): o gateway dela é o host falando direto com o endereço do container nessa rede.

NOMES38=(
  "IPv6 desligado por padrão, e endereço e rede fora da regra recusados"
  "Subida com REDE_IPV6=sim: rede, portas e escuta em IPv4 e IPv6"
  "Volta a REDE_IPV6=nao: rede, portas e certificado como antes, dados e bloqueio mantidos"
  "FTP por IPv6 com TLS: envio e volta do arquivo com a mesma soma"
  "Painel por IPv6: entrada, endereço de quem chega na auditoria e na aba Log"
  "Host em IPv6: só endereço literal privado, entre colchetes e sem zona"
  "Bloqueio de endereço IPv6 de fora no FTP, e o endereço de saída poupado"
  "Cliente IPv6 fora das redes permitidas recusado pelo nginx"
  "Proxy aceito e nome do certificado em IPv6"
)
if [[ ! -e /proc/net/if_inet6 || "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2> /dev/null)" != 0 ]]; then
  M38="IPv6 desligado no kernel deste host"
  fora rede 15 "${NOMES38[0]}" "$M38"; fora rede 16 "${NOMES38[1]}" "$M38"; fora rede 17 "${NOMES38[2]}" "$M38"
  fora testes 107 "${NOMES38[3]}" "$M38"; fora testes 108 "${NOMES38[4]}" "$M38"
  fora seguranca 152 "${NOMES38[5]}" "$M38"; fora seguranca 153 "${NOMES38[6]}" "$M38"
  fora seguranca 154 "${NOMES38[7]}" "$M38"; fora seguranca 155 "${NOMES38[8]}" "$M38"
  return 0
fi

REDES4_38="127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
redes_0="$(env_file="$ENVA" env_valor PAINEL_REDES_PERMITIDAS "$REDES4_38")"; opcao_0="$(env_file="$ENVA" env_valor REDE_PERMITIR_IP_PUBLICO nao)"
proxy_0="$(env_file="$ENVA" env_valor PAINEL_PROXY_CONFIAVEL)"; cn_0="$(env_file="$ENVA" env_valor PAINEL_CERT_CN)"
sub6_0="$(env_file="$ENVA" env_valor FTP_SUBNET_IPV6 fd29:1::/64)"
X38="$NOME-network-38"; J38="$W/j38.jar"; P38="$W/p38.jar"; F38=0
CN38="${SUBREDE6%/*}5"; XF38="${SUBREDE6%/*}77"   # nome do certificado e cliente informado pelo proxy, dentro da rede de teste
igual38() { [[ "$1" == "$2" ]] || F38=1; }
na38() { docker inspect -f "{{(index .NetworkSettings.Networks \"$2\").$3}}" "$1" 2> /dev/null; }  # <container> <rede> <campo>
# <base> <usuário> <arquivo da senha> → "0 226" (entrou e listou) ou "67 530" (recusado)
tenta38() { local base="$1" r; shift; r="$(ftp_curl tls "$1" "$2" -l "$base/")"; echo "$r $(resposta '(226|421|530) ' | cut -c1-3)"; }
erra38() { tenta38 "$1" "$2" "$W/errada38.senha"; }                                          # <base> <usuário>: senha errada
preso38() { docker exec "$FTP" test -f "/auth/enderecos/$1"; }
pasta38() { docker exec "$FTP" ls -A /auth/enderecos 2> /dev/null | sort | tr '\n' ' '; }      # endereços com arquivo de bloqueio
quem38() { docker exec "$FTP" cut -d' ' -f3,4 "/auth/enderecos/$1" 2> /dev/null | tr -d '\n'; }  # <endereço> → "<erros> <quem>"
vigia38() { docker logs "$FTP" 2>&1 | grep -c -F -- "$1"; }
portas38() { docker port "$1" 2> /dev/null | grep -c -F -- "-> $2:"; }                         # <container> <endereço>: portas publicadas nele
rede38() { docker network inspect -f '{{.EnableIPv6}} {{range .IPAM.Config}}{{.Subnet}} {{end}}' "$NOME-network" 2> /dev/null; }
escuta38() { docker exec "$NGINX" grep -c -F 'listen [::]:8443 ssl default_server;' /run/nginx/nginx.conf 2> /dev/null; }
tcp6_38() { docker exec "$FTP" grep -c -v '^ *sl ' /proc/net/tcp6 2> /dev/null; }               # soquetes TCP em IPv6 no container do FTP
# <endereço:porta> <IP> → 1 quando o certificado que o painel apresenta vale para esse IP
cert38() { openssl s_client -connect "$1" < /dev/null 2> /dev/null | openssl x509 -noout -checkip "$2" 2> /dev/null | grep -c 'does match certificate'; }
host38() { c -o /dev/null -w '%{http_code}' -H "Host: $1" "$B6/entrar"; }                      # <Host> → código HTTP da tela de entrada
destino38() { grep -i '^location:' "$W/entrada.cab" | tr -d '\r' | cut -d' ' -f2; }
ultima38() { auditoria; grep -o 'ip=[^ ]* evento=entrada_[a-z]*' "$W/auditoria" | tail -1; }  # endereço e resultado da última entrada
tem38() { grep -c -F -- "$1" "$W/corpo"; }

# ------------------------------------------------------------------ desligado por padrão e recusas
# Com 'nao', nada de IPv6 existe na instância. As recusas vêm do deploy.sh --check-only, que não muda nada.
# Portas que o FTP publica em IPv4 antes da etapa (controle e faixa passiva do perfil em uso): as mesmas têm de aparecer em IPv6.
pf_ini="$(portas38 "$FTP" "$IP")"
arq_0="$(grep -c '^COMPOSE_FILE=' "$ENVA")"; rede_0="$(rede38)"; pf_0="$(portas38 "$FTP" "[$IP6]")"; pn_0="$(portas38 "$NGINX" "[$IP6]")"
esc_0="$(escuta38)"; tcp_0="$(tcp6_38)"; cert_0="$(cert38 "$IP:$PAINEL_PORTA" ::1)"
c -o /dev/null "$F6/" 2> /dev/null; r_f0=$?; h_0="$(c -o /dev/null -w '%{http_code}' -H "Host: [::1]:$PAINEL_PORTA" "$B/entrar")"
LIGA38=(REDE_IPV6=sim "FTP_SUBNET_IPV6=$SUBREDE6" "PAINEL_REDES_PERMITIDAS=$REDES4_38,$SUBREDE6" REDE_PERMITIR_IP_PUBLICO=nao)
ABRE38=("${LIGA38[@]:0:3}" REDE_PERMITIR_IP_PUBLICO=sim)
r_v0="$(recusa_deploy REDE_IPV6=talvez)"
r_v1="$(recusa_deploy "${LIGA38[@]}" FTP_BIND_IPV6=::)"
r_v2="$(recusa_deploy "${LIGA38[@]}" PAINEL_BIND_IPV6=2001:db8::1)"
r_v3="$(recusa_deploy "${LIGA38[@]}" 'FTP_BIND_IPV6=[::1]')"
r_v4="$(recusa_deploy "${ABRE38[@]}" FTP_BIND_IPV6=::)"
r_v5="$(recusa_deploy "${ABRE38[@]}" FTP_BIND_IPV6=fe80::1)"
r_v6="$(recusa_deploy "${ABRE38[@]}" PAINEL_BIND_IPV6=::ffff:10.0.0.1)"
r_v7="$(recusa_deploy "${LIGA38[@]}" FTP_SUBNET_IPV6=2001:db8:1::/64)"
r_v8="$(recusa_deploy "${LIGA38[@]}" "PAINEL_REDES_PERMITIDAS=$REDES4_38")"
r_v9="$(recusa_deploy "${LIGA38[@]}" "PAINEL_REDES_PERMITIDAS=$REDES4_38,::/0")"
r_v10="$(recusa_deploy "${LIGA38[@]}" "PAINEL_PROXY_CONFIAVEL=${SUBREDE6_B%/*}1")"
a_v1="$(aceite_deploy "${LIGA38[@]}")"; a_v2="$(aceite_deploy "${ABRE38[@]}" PAINEL_BIND_IPV6=2001:db8::1)"
k_f="$(recusa_container ftp REDE_IPV6=talvez)"; k_p="$(recusa_container painel REDE_IPV6=talvez)"; k_n="$(recusa_container nginx REDE_IPV6=talvez)"
k_f2="$(recusa_container ftp REDE_IPV6=sim FTP_BIND_IPV6=::)"
MSG_V="REDE_IPV6 deve ser 'nao' ou 'sim'"; MSG_P='não é IPv6 privado'; MSG_S='não é um endereço IPv6 de servidor'
F38=0
igual38 "$arq_0 $rede_0" "0 false $SUBREDE "; igual38 "$pf_0 $pn_0 $esc_0 $tcp_0 $cert_0" '0 0 0 0 0'; igual38 "$r_f0 $h_0" '7 400'
recusou "$r_v0" "$MSG_V" || F38=1; recusou "$r_v1" "$MSG_P" || F38=1; recusou "$r_v2" "$MSG_P" || F38=1; recusou "$r_v3" "$MSG_P" || F38=1
recusou "$r_v4" "$MSG_S" || F38=1; recusou "$r_v5" "$MSG_S" || F38=1; recusou "$r_v6" "$MSG_S" || F38=1
recusou "$r_v7" 'A rede dos containers em IPv6 é uma faixa local única' || F38=1
recusou "$r_v8" 'PAINEL_REDES_PERMITIDAS não tem nenhuma rede IPv6' || F38=1; recusou "$r_v9" 'não é rede IPv6 privada' || F38=1
recusou "$r_v10" 'está fora de PAINEL_REDES_PERMITIDAS' || F38=1
[[ "$a_v1" == "saída 0 · OK: "*"IPv6 ligado"*" · alerta de IP público: 0 · instância intacta" ]] || F38=1
[[ "$a_v2" == "saída 0 · OK: "*"IPv6 ligado"*" · alerta de IP público: 1 · instância intacta" ]] || F38=1
recusou "$k_f" "$MSG_V" || F38=1; recusou "$k_p" "$MSG_V" || F38=1; recusou "$k_n" "$MSG_V" || F38=1; recusou "$k_f2" "$MSG_P" || F38=1
caso "$F38" rede 15 "${NOMES38[0]}" \
  "com REDE_IPV6=nao: linha COMPOSE_FILE no arquivo de ambiente, IPv6 na rede e sub-redes: $arq_0 $rede_0; portas publicadas em [$IP6] pelo FTP e pelo nginx: $pf_0 e $pn_0; escuta em IPv6 no nginx: $esc_0; soquetes IPv6 no container do FTP: $tcp_0; certificado do painel vale para ::1: $cert_0; curl em $F6: saída $r_f0; tela de entrada com Host [::1]:$PAINEL_PORTA: $h_0 · deploy.sh com REDE_IPV6=talvez: $r_v0 · com REDE_IPV6=sim e FTP_BIND_IPV6=::: $r_v1 · PAINEL_BIND_IPV6=2001:db8::1: $r_v2 · FTP_BIND_IPV6=[::1]: $r_v3 · com REDE_PERMITIR_IP_PUBLICO=sim e FTP_BIND_IPV6=::: $r_v4 · FTP_BIND_IPV6=fe80::1: $r_v5 · PAINEL_BIND_IPV6=::ffff:10.0.0.1: $r_v6 · FTP_SUBNET_IPV6=2001:db8:1::/64: $r_v7 · PAINEL_REDES_PERMITIDAS sem rede IPv6: $r_v8 · com ::/0 na lista: $r_v9 · PAINEL_PROXY_CONFIAVEL=${SUBREDE6_B%/*}1, fora das redes: $r_v10 · aceito, com $SUBREDE6 na lista: $a_v1 · aceito, com a opção de IP público e PAINEL_BIND_IPV6=2001:db8::1: $a_v2 · container do FTP com REDE_IPV6=talvez: $k_f · do painel: $k_p · do nginx: $k_n · do FTP com REDE_IPV6=sim e FTP_BIND_IPV6=::: $k_f2"

# ------------------------------------------------------------------ subida com IPv6
gravar_env "$ENVA" REDE_IPV6 sim; gravar_env "$ENVA" FTP_SUBNET_IPV6 "$SUBREDE6"
gravar_env "$ENVA" PAINEL_REDES_PERMITIDAS "$REDES4_38,$SUBREDE6"; gravar_env "$ENVA" REDE_PERMITIR_IP_PUBLICO nao
gravar_env "$ENVA" PAINEL_PROXY_CONFIAVEL ""; gravar_env "$ENVA" PAINEL_CERT_CN ""
dep; r_s=$?; painel_de_pe
refez_s="$(grep -c -F "REDE_IPV6 mudou: refazendo a rede $NOME-network" "$W/deploy.log")"
dito_s="$(grep -c -F -e "e em IPv6: [$IP6]:$FTP_PORTA, mesma faixa passiva" -e "e em IPv6: $B6" "$W/deploy.log")"
saude_s="$(saude "$FTP" "$PAINEL" "$NGINX")"; arq_s="$(env_file="$ENVA" env_valor COMPOSE_FILE)"; rede_s="$(rede38)"
pf_s="$(portas38 "$FTP" "$IP") $(portas38 "$FTP" "[$IP6]")"; pn_s="$(portas38 "$NGINX" "$IP") $(portas38 "$NGINX" "[$IP6]")"
esc_s="$(escuta38)"; tcp_s="$(tcp6_38)"; cert_s="$(cert38 "[$IP6]:$PAINEL_PORTA" ::1) $(cert38 "$IP:$PAINEL_PORTA" "$IP")"
GS6="$(na38 "$FTP" "$NOME-network" IPv6Gateway)"; GS4="$(na38 "$FTP" "$NOME-network" Gateway)"
F38=0
igual38 "$r_s $refez_s $dito_s" '0 1 2'; igual38 "$saude_s" 'healthy healthy healthy '; igual38 "$arq_s" 'compose.yaml:compose.ipv6.yaml'
igual38 "$rede_s" "true $SUBREDE $SUBREDE6 "; igual38 "$pf_s" "$pf_ini $pf_ini"; [[ "$pf_ini" -ge 2 ]] || F38=1; igual38 "$pn_s" '1 1'; igual38 "$esc_s" 1; [[ "$tcp_s" -ge 1 ]] || F38=1
igual38 "$cert_s" '1 1'; igual38 "$GS6" "${SUBREDE6%/*}1"
caso "$F38" rede 16 "${NOMES38[1]}" \
  "REDE_IPV6=sim, FTP_SUBNET_IPV6=$SUBREDE6 e a rede $SUBREDE6 em PAINEL_REDES_PERMITIDAS; deploy.sh: saída $r_s, aviso de que refez a rede: $refez_s, endereços em IPv6 na mensagem final: $dito_s; saúde: $saude_s; COMPOSE_FILE gravado: $arq_s; IPv6 na rede e sub-redes: $rede_s; portas publicadas pelo FTP em $IP e em [$IP6] (antes da etapa, em $IP: $pf_ini): $pf_s; pelo nginx: $pn_s; escuta em IPv6 no nginx: $esc_s; soquetes IPv6 no container do FTP: $tcp_s; certificado do painel vale para ::1 e para $IP: $cert_s; gateway IPv6 e IPv4 da rede: $GS6 e $GS4"

# ------------------------------------------------------------------ FTP por IPv6
nova_senha "$W/v38.senha"; nova_senha "$W/w38.senha"; nova_senha "$W/errada38.senha"
mu add v38 "$W/v38.senha" ipv6-38/a; r_u1=$?; mu add w38 "$W/w38.senha" ipv6-38/b; r_u2=$?
head -c 300000 /dev/urandom > "$W/v38.bin"; soma_38="$(sha256sum < "$W/v38.bin" | cut -c1-16)"
r_e6="$(ftp_curl tls v38 "$W/v38.senha" -T "$W/v38.bin" "$F6/v38.bin")"
epsv_6="$(grep -a -c '^< 229 ' "$W/curl.err")"; tls_6="$(grep -a -c 'SSL connection using' "$W/curl.err")"
r_b6="$(ftp_curl tls v38 "$W/v38.senha" -o "$W/v38.volta6" "$F6/v38.bin")"; soma_6="$(sha256sum < "$W/v38.volta6" | cut -c1-16)"
r_b4="$(ftp_curl tls v38 "$W/v38.senha" -o "$W/v38.volta4" "$F/v38.bin")"; soma_4="$(sha256sum < "$W/v38.volta4" | cut -c1-16)"
# Sem TLS: 421 logo depois do nome quando nenhum usuário está dispensado de TLS (o curl sai com 28), 530 depois da senha quando algum está.
puro_6="$(ESPERA_PURO=25 ftp_curl puro v38 "$W/v38.senha" -l "$F6/") $(resposta '(230|421|530) ' | cut -c1-3)"
sleep 2
de_6="$(vigia38 "vigia: entrada: usuario=v38 origem=$GS6")"; de_4="$(vigia38 "vigia: entrada: usuario=v38 origem=$GS4")"
F38=0
igual38 "$r_u1 $r_u2" '0 0'; igual38 "$r_e6 $r_b6 $r_b4" '0 0 0'; [[ "$epsv_6" -ge 1 && "$tls_6" -ge 1 ]] || F38=1
igual38 "$soma_6 $soma_4" "$soma_38 $soma_38"; [[ "$puro_6" == '28 421' || "$puro_6" == '67 530' ]] || F38=1; [[ "$de_6" -ge 2 && "$de_4" -ge 1 ]] || F38=1
caso "$F38" testes 107 "${NOMES38[3]}" \
  "usuários v38 e w38 criados: $r_u1 e $r_u2; envio de 300000 bytes por $F6, com TLS: saída $r_e6, respostas 229 (modo passivo estendido): $epsv_6, conexões com TLS: $tls_6; volta por $F6: saída $r_b6, soma $soma_6; volta por $F: saída $r_b4, soma $soma_4; soma do arquivo enviado: $soma_38; entrada sem TLS por $F6 (curl e resposta do servidor; 421 ou 530 é recusa): $puro_6; entradas de v38 que o vigia registrou com origem $GS6: $de_6, com origem $GS4: $de_4"

# ------------------------------------------------------------------ painel por IPv6
t_e6="$(B="$B6" aba "$B6/entrar")"
e_6="$(B="$B6" entrar "$J38" "$W/painel.senha")"; d_6="$(destino38)"; proibir "$(biscoito_de "$J38")"; a_6="$(ultima38)"
t_log="$(B="$B6" aba -b "$J38" "$B6/atividade")"; q_log="$(tem38 "$GS6")"
t_seg="$(B="$B6" aba -b "$J38" "$B6/seguranca")"
q_seg="$(tem38 'Endereço do FTP em IPv6') $(tem38 "[$IP6]:$FTP_PORTA") $(tem38 'Endereço do painel em IPv6') $(tem38 "[$IP6]:$PAINEL_PORTA")"
e_4="$(entrar "$J" "$W/painel.senha")"; d_4="$(destino38)"; proibir "$(biscoito_de "$J")"; a_4="$(ultima38)"; K="$(csrf)"; proibir "$K"
F38=0
igual38 "$t_e6" '200 '; igual38 "$e_6 $d_6" '303 /'; igual38 "$a_6" "ip=$GS6 evento=entrada_ok"; igual38 "${t_log%% *}" 200; [[ "$q_log" -ge 1 ]] || F38=1
igual38 "${t_seg%% *}" 200; [[ "$q_seg" =~ ^1\ [1-9][0-9]*\ 1\ [1-9][0-9]*$ ]] || F38=1; igual38 "$e_4 $d_4" '303 /'; igual38 "$a_4" "ip=$GS4 evento=entrada_ok"
caso "$F38" testes 108 "${NOMES38[4]}" \
  "tela de entrada por $B6: $t_e6; entrada de $ADMIN: $e_6 $d_6, na auditoria: $a_6; aba Log: ${t_log%% *}, linhas com $GS6: $q_log; aba Segurança: ${t_seg%% *}, linhas com \"Endereço do FTP em IPv6\", com [$IP6]:$FTP_PORTA, com \"Endereço do painel em IPv6\" e com [$IP6]:$PAINEL_PORTA: $q_seg; entrada por $B: $e_4 $d_4, na auditoria: $a_4"

# ------------------------------------------------------------------ Host em IPv6
h_s1="$(host38 "[$IP6]:$PAINEL_PORTA")"; h_s2="$(host38 "[$IP6]")"; h_s3="$(host38 "[${SUBREDE6%/*}2]:$PAINEL_PORTA")"
h_n1="$(host38 "[2001:db8::1]:$PAINEL_PORTA")"; h_n2="$(host38 "[::1%eth0]:$PAINEL_PORTA")"; h_n3="$(host38 '[::1]x')"
h_n4="$(host38 "[::ffff:127.0.0.1]:$PAINEL_PORTA")"; h_n5="$(host38 '[::1')"; h_n6="$(host38 "::1:$PAINEL_PORTA")"
[[ "$h_s1 $h_s2 $h_s3" == '200 200 200' && "$h_n1 $h_n2 $h_n3 $h_n4 $h_n5 $h_n6" == '400 400 400 400 400 400' ]]
caso $? seguranca 152 "${NOMES38[5]}" \
  "tela de entrada por $B6, com REDE_IPV6=sim e sem a opção de IP público · Host [$IP6]:$PAINEL_PORTA: $h_s1 · [$IP6], sem porta: $h_s2 · [${SUBREDE6%/*}2]:$PAINEL_PORTA, faixa local única: $h_s3 · [2001:db8::1]:$PAINEL_PORTA, endereço público: $h_n1 · [::1%eth0]:$PAINEL_PORTA, com zona: $h_n2 · [::1]x: $h_n3 · [::ffff:127.0.0.1]:$PAINEL_PORTA, IPv4 escrito em IPv6: $h_n4 · [::1, sem fechar: $h_n5 · ::1:$PAINEL_PORTA, sem colchetes: $h_n6 · com REDE_IPV6=nao o Host [::1]:$PAINEL_PORTA deu $h_0 (caso 15 de rede)"

# ------------------------------------------------------------------ bloqueio de endereço IPv6 de fora
docker network create --ipv6 --subnet "${TESTE_SUBNET_C:-172.29.3.8/29}" --subnet "$SUBREDE6_B" "$X38" > /dev/null 2>&1; r_x=$?
docker network connect "$X38" "$FTP" > /dev/null 2>&1; r_x1=$?; docker network connect "$X38" "$NGINX" > /dev/null 2>&1; r_x2=$?
FX="ftp://[$(na38 "$FTP" "$X38" GlobalIPv6Address)]:2121"; GX="$(na38 "$FTP" "$X38" IPv6Gateway)"
NX6="$(na38 "$NGINX" "$X38" GlobalIPv6Address)"; NX4="$(na38 "$NGINX" "$X38" IPAddress)"
certa_x="$(tenta38 "$FX" v38 "$W/v38.senha")"; sleep 1
# Dois erros de um usuário que existe e três de nomes que não existem: cinco do mesmo endereço, sem chegar ao
# bloqueio do usuário (cinco senhas erradas dele).
ev=""; for n in 1 2; do ev+="$(erra38 "$FX" v38); "; done; for n in 1 2 3; do ev+="$(erra38 "$FX" "fantasma38x$n"); "; done
sleep 2
cinco_x="$(preso38 "$GX" && echo gravado || echo nenhum)"
sexto_x="$(erra38 "$FX" fantasma38x4)"
for n in $(seq 1 50); do preso38 "$GX" && break; sleep 0.2; done
quem_x="$(quem38 "$GX")"; preso_v="$(tenta38 "$FX" v38 "$W/v38.senha")"; preso_w="$(tenta38 "$FX" w38 "$W/w38.senha")"
porta_w="$(tenta38 "$F6" w38 "$W/w38.senha")"
# Pela porta publicada, sete erros seguidos: o vigia registra os sete com o endereço de saída IPv6 da stack e não o bloqueia.
interno_0="$(vigia38 "origem=$GS6 (não está no cadastro)")"
ev_s=""; for n in 1 2 3 4 5 6 7; do ev_s+="$(erra38 "$F6" "fantasma38s$n"); "; done
sleep 2
interno_1="$(vigia38 "origem=$GS6 (não está no cadastro)")"; pasta_x="$(pasta38)"; saida_w="$(tenta38 "$F6" w38 "$W/w38.senha")"
t_blo="$(B="$B6" aba -b "$J38" "$B6/bloqueios")"; q_blo="$(tem38 "$GX")"
F38=0
igual38 "$r_x $r_x1 $r_x2" '0 0 0'; igual38 "$GX" "${SUBREDE6_B%/*}1"; igual38 "$certa_x" '0 226'; igual38 "$ev" '67 530; 67 530; 67 530; 67 530; 67 530; '
igual38 "$cinco_x" nenhum; igual38 "$sexto_x" '67 530'; igual38 "$quem_x" '6 ftp'; igual38 "$preso_v $preso_w" '67 530 67 530'; igual38 "$porta_w" '0 226'
igual38 "$ev_s" '67 530; 67 530; 67 530; 67 530; 67 530; 67 530; 67 530; '; igual38 "$((interno_1 - interno_0))" 7; igual38 "$pasta_x" "$GX "
igual38 "$saida_w" '0 226'; igual38 "${t_blo%% *}" 200; [[ "$q_blo" -ge 1 ]] || F38=1
caso "$F38" seguranca 153 "${NOMES38[6]}" \
  "rede $X38 ($SUBREDE6_B) criada e ligada ao FTP e ao nginx: $r_x $r_x1 $r_x2; por ela o host chega ao FTP como $GX · senha certa de v38: $certa_x · duas senhas erradas de v38 e três de nomes que não existem: ${ev}bloqueio depois do quinto erro: $cinco_x · sexto erro: $sexto_x, arquivo do bloqueio (erros e origem): $quem_x · depois, v38 e w38 com a senha certa: $preso_v e $preso_w · w38 pela porta publicada, $F6: $porta_w · sete erros seguidos por $F6: ${ev_s}erros que o vigia registrou com origem $GS6: $((interno_1 - interno_0)); endereços bloqueados: $pasta_x; w38 em seguida: $saida_w · aba Bloqueios: ${t_blo%% *}, linhas com $GX: $q_blo"

# ------------------------------------------------------------------ cliente IPv6 fora das redes permitidas
proibido_0="$(docker logs "$NGINX" 2>&1 | grep -c -F "access forbidden by rule, client: $GX")"; 
n_6="$(c -o /dev/null -w '%{http_code}' "https://[$NX6]:8443/entrar")"; n_6s="$(c -o /dev/null -w '%{http_code}' "https://[$NX6]:8443/saude")"
n_4="$(c -o /dev/null -w '%{http_code}' "https://$NX4:8443/entrar")"; n_p="$(c -o /dev/null -w '%{http_code}' "$B6/entrar")"
sleep 1
proibido_1="$(docker logs "$NGINX" 2>&1 | grep -c -F "access forbidden by rule, client: $GX")"; auditoria; aud_1="$(grep -c -F "ip=$GX " "$W/auditoria")"
[[ "$n_6 $n_6s" == '403 403' && "$n_4 $n_p" == '200 200' && $((proibido_1 - proibido_0)) -ge 2 && "$aud_1" == 0 && -n "$NX6" ]]
caso $? seguranca 154 "${NOMES38[7]}" \
  "PAINEL_REDES_PERMITIDAS=$REDES4_38,$SUBREDE6; o host fala direto com o nginx na rede $X38, de onde chega como $GX, fora da lista · tela de entrada por https://[$NX6]:8443: $n_6, /saude: $n_6s; recusas a $GX no registro do nginx: $((proibido_1 - proibido_0)); linhas da auditoria do painel com esse endereço: $aud_1 · pelo IPv4 da mesma rede, $NX4, dentro de 172.16.0.0/12: $n_4 · por $B6, de onde o host chega como $GS6, dentro da lista: $n_p"
docker network disconnect -f "$X38" "$NGINX" > /dev/null 2>&1; docker network disconnect -f "$X38" "$FTP" > /dev/null 2>&1
docker network rm "$X38" > /dev/null 2>&1

# ------------------------------------------------------------------ proxy e nome do certificado em IPv6
gravar_env "$ENVA" PAINEL_PROXY_CONFIAVEL "$GS6"; gravar_env "$ENVA" PAINEL_CERT_CN "$CN38"
dep; r_p=$?; painel_de_pe
alerta_p="$(grep -c -F "ALERTA: PAINEL_PROXY_CONFIAVEL=$GS6:" "$W/deploy.log")"; saude_p="$(saude "$FTP" "$PAINEL" "$NGINX")"
aceito_p="$(docker logs --since "$(docker inspect -f '{{.State.StartedAt}}' "$NGINX")" "$NGINX" 2>&1 | grep -c -F "proxy ou túnel aceito: $GS6")"
cert_p="$(cert38 "[$IP6]:$PAINEL_PORTA" "$CN38") $(cert38 "[$IP6]:$PAINEL_PORTA" ::1) $(cert38 "[$IP6]:$PAINEL_PORTA" "${SUBREDE6%/*}6")"
h_p="$(host38 "[$CN38]:$PAINEL_PORTA")"
rm -f "$P38"; e_p="$(B="$B6" entrar "$P38" "$W/painel.senha" -H "X-Forwarded-For: $XF38")"; d_p="$(destino38)"; proibir "$(biscoito_de "$P38")"; a_p="$(ultima38)"
e_p4="$(entrar "$P38" "$W/painel.senha" -H "X-Forwarded-For: $XF38")"; proibir "$(biscoito_de "$P38")"; a_p4="$(ultima38)"
[[ "$r_p" == 0 && "$alerta_p" == 1 && "$saude_p" == 'healthy healthy healthy ' && "$aceito_p" -ge 1 && "$cert_p" == '1 1 0' && "$h_p" == 200 \
  && "$e_p $d_p" == '303 /' && "$a_p" == "ip=$XF38 evento=entrada_ok" && "$e_p4" == 303 && "$a_p4" == "ip=$GS4 evento=entrada_ok" ]]
caso $? seguranca 155 "${NOMES38[8]}" \
  "PAINEL_PROXY_CONFIAVEL=$GS6 e PAINEL_CERT_CN=$CN38; deploy.sh: saída $r_p, alerta do proxy: $alerta_p; saúde: $saude_p; proxy aceito na partida do nginx: $aceito_p; certificado do painel vale para $CN38, para ::1 e para ${SUBREDE6%/*}6 (que não foi pedido): $cert_p; tela de entrada com Host [$CN38]:$PAINEL_PORTA: $h_p · entrada de $ADMIN por $B6, que chega pelo proxy aceito, com X-Forwarded-For: $XF38: $e_p $d_p, na auditoria: $a_p · a mesma entrada por $B, que não chega pelo proxy aceito: $e_p4, na auditoria: $a_p4"

# ------------------------------------------------------------------ de volta a 'nao'
gravar_env "$ENVA" REDE_IPV6 nao; gravar_env "$ENVA" FTP_SUBNET_IPV6 "$sub6_0"; gravar_env "$ENVA" PAINEL_REDES_PERMITIDAS "$redes_0"
gravar_env "$ENVA" REDE_PERMITIR_IP_PUBLICO "$opcao_0"; gravar_env "$ENVA" PAINEL_PROXY_CONFIAVEL "$proxy_0"; gravar_env "$ENVA" PAINEL_CERT_CN "$cn_0"
dep; r_n=$?; painel_de_pe
refez_n="$(grep -c -F "REDE_IPV6 mudou: refazendo a rede $NOME-network" "$W/deploy.log")"; dito_n="$(grep -c -F 'e em IPv6:' "$W/deploy.log")"
saude_n="$(saude "$FTP" "$PAINEL" "$NGINX")"; arq_n="$(env_file="$ENVA" env_valor COMPOSE_FILE)"; rede_n="$(rede38)"
pf_n="$(portas38 "$FTP" "$IP") $(portas38 "$FTP" "[$IP6]")"; pn_n="$(portas38 "$NGINX" "$IP") $(portas38 "$NGINX" "[$IP6]")"
esc_n="$(escuta38)"; tcp_n="$(tcp6_38)"; cert_n="$(cert38 "$IP:$PAINEL_PORTA" ::1) $(cert38 "$IP:$PAINEL_PORTA" "$IP")"
c -o /dev/null "$F6/" 2> /dev/null; r_f6=$?; c -o /dev/null "$B6/entrar" 2> /dev/null; r_p6=$?
r_v4="$(ftp_curl tls v38 "$W/v38.senha" -o "$W/v38.volta" "$F/v38.bin")"; soma_n="$(sha256sum < "$W/v38.volta" | cut -c1-16)"
e_n="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; a_n="$(ultima38)"; K="$(csrf)"; proibir "$K"
t_segn="$(aba -b "$J" "$B/seguranca")"; q_segn="$(tem38 'em IPv6')"; pasta_n="$(pasta38)"; t_blon="$(aba -b "$J" "$B/bloqueios")"; q_blon="$(tem38 "$GX")"
mu endereco-liberar "$GX"; r_lib=$?; pasta_fim="$(pasta38)"
mu del v38; mu del w38
docker exec "$FTP" rm -rf /data/ipv6-38 > /dev/null 2>&1
rm -f "$J38" "$P38" "$W"/v38.* "$W/w38.senha" "$W/errada38.senha"
redes_fim="$(docker network ls -q --filter "name=$X38" | wc -l)"; usuarios_fim="$(usuarios_ftp | tr ' ' '\n' | grep -c -E '^[vw]38$')"
F38=0
igual38 "$r_n $refez_n $dito_n" '0 1 0'; igual38 "$saude_n" 'healthy healthy healthy '; igual38 "$arq_n" compose.yaml; igual38 "$rede_n" "false $SUBREDE "
igual38 "$pf_n" "$pf_ini 0"; igual38 "$pn_n" '1 0'; igual38 "$esc_n $tcp_n" '0 0'; igual38 "$cert_n" '0 1'; igual38 "$r_f6 $r_p6" '7 7'
igual38 "$r_v4 $soma_n" "0 $soma_38"; igual38 "$e_n" 303; igual38 "$a_n" "ip=$GS4 evento=entrada_ok"; igual38 "${t_segn%% *} $q_segn" '200 0'
igual38 "$pasta_n" "$GX "; igual38 "${t_blon%% *}" 200; [[ "$q_blon" -ge 1 ]] || F38=1; igual38 "$r_lib" 0; igual38 "$pasta_fim" ''; igual38 "$redes_fim $usuarios_fim" '0 0'
caso "$F38" rede 17 "${NOMES38[2]}" \
  "REDE_IPV6=nao e as outras opções como estavam; deploy.sh: saída $r_n, aviso de que refez a rede: $refez_n, endereços em IPv6 na mensagem final: $dito_n; saúde: $saude_n; COMPOSE_FILE: $arq_n; IPv6 na rede e sub-redes: $rede_n; portas publicadas pelo FTP em $IP e em [$IP6] (antes da etapa, em $IP: $pf_ini): $pf_n; pelo nginx: $pn_n; escuta em IPv6 no nginx e soquetes IPv6 no container do FTP: $esc_n $tcp_n; certificado do painel vale para ::1 e para $IP: $cert_n; curl em $F6 e em $B6: saídas $r_f6 e $r_p6 · arquivo enviado antes, de volta por $F: saída $r_v4, soma $soma_n (a enviada: $soma_38); entrada de $ADMIN por $B: $e_n, na auditoria: $a_n; aba Segurança: ${t_segn%% *}, linhas com \"em IPv6\": $q_segn · bloqueio de $GX depois da volta: $pasta_n, aba Bloqueios: ${t_blon%% *}, linhas com ele: $q_blon; liberado pelo terminal: $r_lib, endereços bloqueados depois: \"$pasta_fim\" · redes e usuários da etapa que sobraram: $redes_fim e $usuarios_fim"
painel_de_pe
