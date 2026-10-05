#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa F: reinício dos serviços e healthcheck do FTP.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

mu add equip09 "$W/u6.senha"; r_e="$(ftp_curl tls equip09 "$W/u6.senha" -T "$W/envio.bin" "$F/reinicio.cfg")"
dc restart ftp > "$W/restart.log" 2>&1; r=$?; esperar "$FTP"
r_l="$(ftp_curl tls equip09 "$W/u6.senha" -o "$W/reinicio.bin" "$F/reinicio.cfg")"; r_i="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" "$F/")"
dc restart painel >> "$W/restart.log" 2>&1; esperar "$PAINEL"; esperar "$NGINX"
de_volta="$(entrar "$J" "$W/painel.senha")"; proibir "$(awk '$6 == "__Host-sessao" {print $7}' "$J")"
[[ "$r" == 0 && "$r_e" == 0 && "$r_l" == 0 && "$r_i" == 0 && " $(usuarios_ftp)" == *" equip09 "* && "$de_volta" == 303 ]] && cmp -s "$W/envio.bin" "$W/reinicio.bin"
caso $? testes 8 "Reinício" "docker compose restart ftp: saída $r, saúde $(saude "$FTP")· usuário criado antes: login e download $r_l, arquivo $(cmp -s "$W/envio.bin" "$W/reinicio.bin" && echo idêntico || echo DIFERENTE) · usuário inicial: $r_i · painel reiniciado em seguida: saúde $(saude "$PAINEL" "$NGINX")· entrada $de_volta"
achado seguranca "O limite de tentativas do painel fica na memória do processo" "Depois das 6 tentativas o endereço fica bloqueado por 15 minutos; reiniciar o painel zera a contagem (entrada com a senha certa: $de_volta). Quem reinicia o container já tem acesso ao host"

# Healthcheck do FTP: mede a porta de controle. Com o servidor suspenso, o processo existe e a saúde falha.
h_cfg="$(docker inspect -f '{{json .Config.Healthcheck.Test}}' "$FTP" 2>/dev/null)"
docker exec "$FTP" /usr/local/sbin/allsafe-ftp-saude > /dev/null 2>&1; h_antes=$?
docker exec "$FTP" sh -c 'kill -STOP $(pidof pure-ftpd)' > /dev/null 2>&1
docker exec "$FTP" /usr/local/sbin/allsafe-ftp-saude > /dev/null 2>&1; h_parado=$?
docker exec "$FTP" pidof pure-ftpd > /dev/null 2>&1; h_processo=$?
docker exec "$FTP" sh -c 'kill -CONT $(pidof pure-ftpd)' > /dev/null 2>&1
docker exec "$FTP" /usr/local/sbin/allsafe-ftp-saude > /dev/null 2>&1; h_depois=$?
r="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" "$F/")"
[[ "$h_cfg" == *allsafe-ftp-saude* && "$h_antes" == 0 && "$h_parado" != 0 && "$h_processo" == 0 && "$h_depois" == 0 && "$r" == 0 ]]
caso $? testes 19 "Healthcheck do FTP" "teste configurado: $h_cfg · servidor atendendo: saída $h_antes · servidor suspenso (kill -STOP), processo presente (pidof: $h_processo): saída $h_parado · retomado: saída $h_depois, login $r"
