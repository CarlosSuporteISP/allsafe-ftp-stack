#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa J: a opção REDE_PERMITIR_IP_PUBLICO ligada na instância de teste, em execução.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# Os endereços de escuta continuam os da instância de teste (IP privado): o que muda é a opção e uma
# rede de documentação (RFC 5737) liberada no painel. Antes, a mesma rede sem a opção tem de ser recusada.
REDES_TESTE="127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,203.0.113.0/24"
sem="$(recusa_deploy "PAINEL_REDES_PERMITIDAS=$REDES_TESTE")"
permitidas() { docker exec "$NGINX" grep -c -E '^[[:space:]]*allow ' /run/nginx/nginx.conf 2>/dev/null; }
liberada() { docker exec "$NGINX" grep -c -x -E '[[:space:]]*allow 203\.0\.113\.0/24;' /run/nginx/nginx.conf 2>/dev/null; }
antes_l="$(liberada)"; antes_p="$(permitidas)"
gravar_env "$ENVA" REDE_PERMITIR_IP_PUBLICO sim
gravar_env "$ENVA" PAINEL_REDES_PERMITIDAS "$REDES_TESTE"
dep; r=$?
saude_j="$(saude "$FTP" "$PAINEL" "$NGINX")"
alerta_deploy="$(grep -c '^ALERTA: REDE_PERMITIR_IP_PUBLICO=sim' "$W/deploy.log")"
ev=""; alertas=0
for n in "$FTP" "$PAINEL" "$NGINX"; do
  a="$(docker logs "$n" 2>&1 | grep -c 'ALERTA: REDE_PERMITIR_IP_PUBLICO=sim')"
  [[ "$a" -ge 1 ]] && alertas=$((alertas + 1)); ev+="$n: $a; "
done
r_e="$(entrar "$J" "$W/painel.senha")"; proibir "$(awk '$6 == "__Host-sessao" {print $7}' "$J")"
seg="$(aba -b "$J" "$B/seguranca")"
no_painel="$(grep -c 'Endereço público aceito' "$W/corpo")"; linha_publico="$(grep -c 'Endereço público</' "$W/corpo")"; rede_na_aba="$(grep -c -F '203.0.113.0/24' "$W/corpo")"
rodape="$(grep -c 'endereço público aceito: confira o firewall' "$W/corpo")"; marcador="$(grep -c -F '<span class="so-leitor"> (instalação publicada)</span>' "$W/corpo")"
# A tela de entrada é de quem ainda não entrou: não diz como a instalação está publicada.
na_entrada="$(c "$B/entrar" | grep -c -i -E 'endereço público|publicado por proxy ou túnel|PAINEL_PROXY_CONFIAVEL|REDE_PERMITIR_IP_PUBLICO')"
r_l="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" "$F/")"
[[ "$r" == 0 && "$saude_j" == "healthy healthy healthy " && "$alerta_deploy" == 1 && "$alertas" == 3 && "$r_e" == 303 && "$seg" == "200 " \
  && "$no_painel" -ge 1 && "$linha_publico" -ge 1 && "$rede_na_aba" -ge 1 && "$rodape" == 1 && "$marcador" == 1 && "$na_entrada" == 0 && "$r_l" == 0 ]]
caso $? seguranca 45 "Alerta de IP público em execução" "deploy.sh com REDE_PERMITIR_IP_PUBLICO=sim: saída $r, saúde $saude_j· alerta na saída do deploy.sh: $alerta_deploy · no registro dos containers: $ev· painel, aba Segurança ($seg): aviso no topo $no_painel, linha 'Endereço público' $linha_publico, rede pública listada $rede_na_aba, rodapé com o alerta $rodape, sinal de instalação publicada no menu $marcador · linhas da tela de entrada que falam da exposição: $na_entrada · FTPS depois da troca: login $r_l"

depois_l="$(liberada)"; depois_p="$(permitidas)"
de_dentro="$(c -o /dev/null -w '%{http_code}' "$B/saude")"
recusou "$sem" 'não é rede privada' && [[ "$antes_l" == 0 && "$depois_l" == 1 && "$depois_p" == $((antes_p + 1)) && "$de_dentro" == 200 ]] \
  && docker exec "$NGINX" grep -q -x -E '[[:space:]]*deny all;' /run/nginx/nginx.conf
caso $? rede 13 "Rede pública no painel só com a opção" "PAINEL_REDES_PERMITIDAS com 203.0.113.0/24 · sem a opção, deploy.sh: $sem · com a opção, regras allow no nginx: $antes_p → $depois_p, a da rede pública: $antes_l → $depois_l, 'deny all' no fim: $(docker exec "$NGINX" grep -c -x -E '[[:space:]]*deny all;' /run/nginx/nginx.conf 2>/dev/null) · painel a partir de $IP: $de_dentro"
