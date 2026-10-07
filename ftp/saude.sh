#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Healthcheck do FTP: abre a porta de controle e espera a saudação do servidor. Processo vivo que
# não atende deixa de contar como saudável. 220 = pronto; 421 = no limite de conexões, mas atendendo.
# O FTP só está saudável com o soquete do pure-authd (o porteiro) e o do vigia abertos.
[[ -S /run/pure-authd.sock && -S /dev/log ]] || exit 1
{ exec 3<> /dev/tcp/127.0.0.1/2121; } 2>/dev/null || exit 1
IFS= read -r -t 4 saudacao <&3 || exit 1
printf 'QUIT\r\n' >&3 2>/dev/null || true
[[ "$saudacao" == 220* || "$saudacao" == 421* ]]
