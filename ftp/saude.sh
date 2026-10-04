#!/usr/bin/env bash
# Healthcheck do FTP: abre a porta de controle e espera a saudação do servidor. Processo vivo que
# não atende deixa de contar como saudável. 220 = pronto; 421 = no limite de conexões, mas atendendo.
{ exec 3<> /dev/tcp/127.0.0.1/2121; } 2>/dev/null || exit 1
IFS= read -r -t 4 saudacao <&3 || exit 1
printf 'QUIT\r\n' >&3 2>/dev/null || true
[[ "$saudacao" == 220* || "$saudacao" == 421* ]]
