#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa AA: painel publicado por proxy ou túnel (PAINEL_PROXY_CONFIAVEL). Sem a opção, o endereço que o cliente
# escreve em cabeçalho é ignorado; com ela, só a conexão vinda do proxy aceito informa o endereço do cliente, e é
# esse endereço que conta as senhas erradas, prende a sessão e vai para a auditoria. No fim, a opção volta a vazio.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel zera a contagem de falhas de entrada e encerra as sessões.
dc restart painel > /dev/null 2>&1; painel_de_pe
nova_senha "$W/errada27.senha"
P27="$W/p27.jar"; S27="$W/s27.jar"
# [opções do curl...] → código HTTP de uma entrada com a senha errada
errar27() {
  local formulario
  formulario="$(c -c "$P27" "$@" "$B/entrar" | sed -n 's/.*name="token" value="\([^"]*\)".*/\1/p')"
  c -o /dev/null -w '%{http_code}' -b "$P27" -H "Origin: $B" "$@" --data-urlencode "token=$formulario" \
    --data-urlencode "usuario=$ADMIN" --data-urlencode "senha@$W/errada27.senha" "$B/entrar"
}
de27() { auditoria; grep -o 'ip=[^ ]* evento=entrada_[a-z]*' "$W/auditoria" | tail -1 | sed -e 's/^ip=//' -e 's/ evento=.*//'; }  # endereço da última entrada na auditoria
aceitos27() { docker exec "$NGINX" grep -c -E '^[[:space:]]+[0-9.]+ 1;$' /run/nginx/nginx.conf 2>/dev/null; }                 # endereços de proxy na configuração do nginx
forjado27() { auditoria; grep -c -E 'ip=(198\.51\.100|203\.0\.113)\.' "$W/auditoria" 2>/dev/null || true; }                      # linhas da auditoria com endereço de documentação

# ------------------------------------------------------------------ sem a opção: o cabeçalho do cliente não vale
opcao_0="$(env_file="$ENVA" env_valor PAINEL_PROXY_CONFIAVEL)"; aceitos_0="$(aceitos27)"; forjado_0="$(forjado27)"
r_limpo="$(errar27)"; origem27="$(de27)"
r_forjado="$(errar27 -H 'X-Forwarded-For: 198.51.100.7' -H 'X-Cliente-IP: 198.51.100.8' -H 'X-Real-IP: 198.51.100.9' -H 'Forwarded: for=198.51.100.10')"
de_forjado="$(de27)"; forjado_1="$(forjado27)"
nota_0="$(c "$B/entrar" | grep -c 'De fábrica, uso só em rede privada, atrás de firewall')"
ip_privado "$origem27" && [[ -z "$opcao_0" && "$aceitos_0" == 0 && "$r_limpo" == 401 && "$r_forjado" == 401 && "$de_forjado" == "$origem27" \
  && "$forjado_0" == "$forjado_1" && "$nota_0" == 1 ]]
caso $? seguranca 93 "Endereço escrito pelo cliente em cabeçalho é ignorado" "PAINEL_PROXY_CONFIAVEL vazio, endereços de proxy na configuração do nginx: $aceitos_0 · entrada com senha errada, sem cabeçalho a mais: $r_limpo, na auditoria com o endereço $origem27 · a mesma entrada com X-Forwarded-For, X-Cliente-IP, X-Real-IP e Forwarded apontando para 198.51.100.x: $r_forjado, na auditoria com o endereço $de_forjado · linhas da auditoria com o endereço forjado: $forjado_0 → $forjado_1 · tela de entrada com a nota do uso em rede privada: $nota_0"

# ------------------------------------------------------------------ o que a opção recusa, antes de mexer em qualquer coisa
PRIV27="127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
rec_rede="$(recusa_deploy REDE_PERMITIR_IP_PUBLICO=nao "PAINEL_REDES_PERMITIDAS=$PRIV27" PAINEL_PROXY_CONFIAVEL=10.0.0.0/24)"
rec_publico="$(recusa_deploy REDE_PERMITIR_IP_PUBLICO=nao "PAINEL_REDES_PERMITIDAS=$PRIV27" PAINEL_PROXY_CONFIAVEL=203.0.113.9)"
rec_todos="$(recusa_deploy REDE_PERMITIR_IP_PUBLICO=nao "PAINEL_REDES_PERMITIDAS=$PRIV27" PAINEL_PROXY_CONFIAVEL=0.0.0.0)"
rec_nove="$(recusa_deploy REDE_PERMITIR_IP_PUBLICO=nao "PAINEL_REDES_PERMITIDAS=$PRIV27" PAINEL_PROXY_CONFIAVEL=10.0.0.1,10.0.0.2,10.0.0.3,10.0.0.4,10.0.0.5,10.0.0.6,10.0.0.7,10.0.0.8,10.0.0.9)"
rec_fora="$(recusa_deploy REDE_PERMITIR_IP_PUBLICO=nao PAINEL_REDES_PERMITIDAS=127.0.0.0/8,172.16.0.0/12 PAINEL_PROXY_CONFIAVEL=10.9.9.9)"
rec_nginx="$(recusa_container nginx PAINEL_PROXY_CONFIAVEL=10.0.0.0/24)"
rec_painel="$(recusa_container painel PAINEL_PROXY_CONFIAVEL=203.0.113.9)"

# ------------------------------------------------------------------ com a opção: quem informa o endereço é o proxy aceito
gravar_env "$ENVA" PAINEL_PROXY_CONFIAVEL "$origem27"
dep; r=$?
saude_p="$(saude "$FTP" "$PAINEL" "$NGINX")"; aceitos_1="$(aceitos27)"
alerta_deploy="$(grep -c '^ALERTA: PAINEL_PROXY_CONFIAVEL=' "$W/deploy.log")"
ev=""; alertas=0
for n in "$PAINEL" "$NGINX"; do
  a="$(docker logs "$n" 2>&1 | grep -c 'ALERTA: PAINEL_PROXY_CONFIAVEL=')"
  [[ "$a" -ge 1 ]] && alertas=$((alertas + 1)); ev+="$n: $a; "
done
r_e="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; de_admin="$(de27)"
seg="$(aba -b "$J" "$B/seguranca")"
no_topo="$(grep -c 'Painel publicado por proxy ou túnel' "$W/corpo")"; na_linha="$(grep -c 'Painel por proxy ou túnel</th><td><strong>Em uso</strong>' "$W/corpo")"
rodape="$(grep -c 'painel publicado por proxy ou túnel' "$W/corpo")"
r_1="$(errar27 -H 'X-Forwarded-For: 198.51.100.7')"; de_1="$(de27)"
r_2="$(errar27 -H 'X-Forwarded-For: 203.0.113.99, 198.51.100.8')"; de_2="$(de27)"
r_3="$(errar27 -H 'X-Forwarded-For: 198.51.100.9' -H 'X-Cliente-IP: 203.0.113.77' -H 'X-Real-IP: 203.0.113.78')"; de_3="$(de27)"
r_4="$(errar27 -H 'X-Forwarded-For: nao-e-endereco')"; de_4="$(de27)"
r_5="$(errar27 -H 'X-Cliente-IP: 198.51.100.11')"; de_5="$(de27)"
[[ "$r" == 0 && "$saude_p" == "healthy healthy healthy " && "$aceitos_1" == 1 && "$alerta_deploy" == 1 && "$alertas" == 2 && "$r_e" == 303 \
  && "$de_admin" == "$origem27" && "$seg" == "200 " && "$no_topo" -ge 1 && "$na_linha" == 1 && "$rodape" == 1 \
  && "$r_1" == 401 && "$de_1" == 198.51.100.7 && "$r_2" == 401 && "$de_2" == 198.51.100.8 && "$r_3" == 401 && "$de_3" == 198.51.100.9 \
  && "$r_4" == 401 && "$de_4" == "$origem27" && "$r_5" == 401 && "$de_5" == "$origem27" ]]
caso $? seguranca 94 "Painel por proxy: só o proxy aceito informa o endereço do cliente" "deploy.sh com PAINEL_PROXY_CONFIAVEL=$origem27: saída $r, saúde $saude_p· endereços de proxy na configuração do nginx: $aceitos_1 · alerta na saída do deploy.sh: $alerta_deploy · no registro dos containers: $ev· entrada do administrador sem X-Forwarded-For: $r_e, na auditoria com $de_admin · aba Segurança ($seg): aviso no topo $no_topo, linha 'Em uso' $na_linha, rodapé $rodape · senha errada com X-Forwarded-For 198.51.100.7: $r_1, auditoria $de_1 · com '203.0.113.99, 198.51.100.8' (o primeiro é o que o cliente escreveu): $r_2, auditoria $de_2 · com X-Forwarded-For 198.51.100.9 mais X-Cliente-IP e X-Real-IP forjados: $r_3, auditoria $de_3 · com valor que não é endereço: $r_4, auditoria $de_4 · só com X-Cliente-IP forjado: $r_5, auditoria $de_5"

# ------------------------------------------------------------------ senha errada e sessão pelo endereço que o proxy informou
ev=""
for n in 1 2 3 4 5; do ev+="$(errar27 -H 'X-Forwarded-For: 198.51.100.20') "; done
sexta="$(errar27 -H 'X-Forwarded-For: 198.51.100.20')"
certa_bloqueado="$(entrar "$S27" "$W/painel.senha" -H 'X-Forwarded-For: 198.51.100.20')"
certa_outro="$(entrar "$S27" "$W/painel.senha" -H 'X-Forwarded-For: 198.51.100.21')"; proibir "$(biscoito_de "$S27")"; de_outro="$(de27)"
s_mesmo="$(aba -b "$S27" -H 'X-Forwarded-For: 198.51.100.21' "$B/usuarios")"
s_troca="$(aba -b "$S27" -H 'X-Forwarded-For: 198.51.100.22' "$B/usuarios")"
s_volta="$(aba -b "$S27" -H 'X-Forwarded-For: 198.51.100.21' "$B/usuarios")"
s_admin="$(aba -b "$J" "$B/usuarios")"
[[ "$ev" == "401 401 401 401 401 " && "$sexta" == 429 && "$certa_bloqueado" == 429 && "$certa_outro" == 303 && "$de_outro" == 198.51.100.21 \
  && "$s_mesmo" == "200 " && "$s_troca" == "303 /entrar" && "$s_volta" == "303 /entrar" && "$s_admin" == "200 " ]]
caso $? seguranca 95 "Painel por proxy: senha errada e sessão contam pelo endereço do cliente" "cinco senhas erradas vindas de 198.51.100.20 pelo proxy: $ev· a sexta: $sexta · a senha certa do mesmo endereço: $certa_bloqueado · a senha certa de 198.51.100.21, pelo mesmo proxy: $certa_outro, na auditoria com $de_outro · a sessão aberta, usada de 198.51.100.21: $s_mesmo· usada de 198.51.100.22: $s_troca · de volta a 198.51.100.21, já encerrada: $s_volta · a sessão do administrador que entrou sem X-Forwarded-For continua: $s_admin"

# ------------------------------------------------------------------ aviso na tela: quem instala pode ocultar
rec_aviso="$(recusa_deploy PAINEL_AVISO_EXPOSICAO=talvez)"
gravar_env "$ENVA" PAINEL_AVISO_EXPOSICAO nao
dep; r_oc=$?
saude_oc="$(saude "$FTP" "$PAINEL" "$NGINX")"; alerta_oc="$(grep -c '^ALERTA: PAINEL_PROXY_CONFIAVEL=' "$W/deploy.log")"
entrada_oc="$(c "$B/entrar" | grep -c -i -E 'publicado por proxy ou túnel|PAINEL_PROXY_CONFIAVEL')"
r_oc_e="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"
seg_oc="$(aba -b "$J" "$B/seguranca")"
topo_oc="$(grep -c -i 'painel publicado por proxy ou túnel' "$W/corpo")"
linha_oc="$(grep -c 'Painel por proxy ou túnel</th><td><strong>Em uso</strong>' "$W/corpo")"; dito_oc="$(grep -c 'PAINEL_AVISO_EXPOSICAO=nao' "$W/corpo")"
recusou "$rec_aviso" "PAINEL_AVISO_EXPOSICAO deve ser 'sim' ou 'nao'" \
  && [[ "$r_oc" == 0 && "$saude_oc" == "healthy healthy healthy " && "$alerta_oc" == 1 && "$entrada_oc" == 0 && "$r_oc_e" == 303 \
  && "$seg_oc" == "200 " && "$topo_oc" == 0 && "$linha_oc" == 1 && "$dito_oc" == 1 ]]
caso $? seguranca 96 "Aviso de exposição oculto por opção: a tela não diz, a aba Segurança e o deploy dizem" "deploy.sh com PAINEL_AVISO_EXPOSICAO=talvez: $rec_aviso · com PAINEL_AVISO_EXPOSICAO=nao e o proxy aceito: saída $r_oc, saúde $saude_oc· alerta na saída do deploy.sh: $alerta_oc · linhas da tela de entrada que falam do proxy: $entrada_oc · entrada do administrador: $r_oc_e · aba Segurança ($seg_oc): aviso no topo e no rodapé $topo_oc, linha 'Em uso' $linha_oc, linha que diz que o aviso está oculto $dito_oc"

# ------------------------------------------------------------------ de volta ao padrão
gravar_env "$ENVA" PAINEL_AVISO_EXPOSICAO sim
gravar_env "$ENVA" PAINEL_PROXY_CONFIAVEL ""
dep; r_fim=$?
saude_fim="$(saude "$FTP" "$PAINEL" "$NGINX")"; aceitos_fim="$(aceitos27)"
r_volta="$(errar27 -H 'X-Forwarded-For: 198.51.100.30')"; de_volta="$(de27)"
recusou "$rec_rede" 'não é um endereço IPv4' && recusou "$rec_publico" 'não é IP privado' && recusou "$rec_todos" 'não é IP privado' \
  && recusou "$rec_nove" 'aceita até 8 endereços' && recusou "$rec_fora" 'está fora de PAINEL_REDES_PERMITIDAS' \
  && recusou "$rec_nginx" 'não é um endereço IPv4' && recusou "$rec_painel" 'não é IP privado' \
  && [[ "$r_fim" == 0 && "$saude_fim" == "healthy healthy healthy " && "$aceitos_fim" == 0 && "$r_volta" == 401 && "$de_volta" == "$origem27" ]]
caso $? rede 14 "Proxy do painel: endereço escolhido, um a um, e dentro das redes permitidas" "deploy.sh com PAINEL_PROXY_CONFIAVEL=10.0.0.0/24 (rede inteira): $rec_rede · com 203.0.113.9, sem a opção de IP público: $rec_publico · com 0.0.0.0: $rec_todos · com nove endereços: $rec_nove · com 10.9.9.9 fora de PAINEL_REDES_PERMITIDAS: $rec_fora · container do nginx com rede inteira: $rec_nginx · container do painel com endereço público: $rec_painel · opção de volta a vazio, deploy.sh: saída $r_fim, saúde $saude_fim· endereços de proxy na configuração do nginx: $aceitos_fim · senha errada com X-Forwarded-For 198.51.100.30: $r_volta, na auditoria com $de_volta"
