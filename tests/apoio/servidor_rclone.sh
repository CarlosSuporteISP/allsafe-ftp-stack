#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Servidor de arquivos de teste do destino rclone: WebDAV com TLS e SFTP, pelo `rclone serve` do binário da imagem
# do painel. Só a bateria usa (tests/etapas/36-destino-rclone.sh), em container próprio na rede da instância de
# teste; o painel nunca chama `serve`.
# Pastas montadas: /rem (certificado, senha e chaves públicas aceitas, só leitura), /srv e /srv-b (o que chega),
# /cache e /cache-b (a chave de cada servidor SFTP, que o rclone cria na primeira subida) e /saida (registro).
set -eu
export HOME=/tmp/h RCLONE_CONFIG=/tmp/h/vazio.conf
mkdir -p /tmp/h
: > "$RCLONE_CONFIG"
# O usuário e a senha vão pelo ambiente: não aparecem na linha de comando.
RCLONE_USER=teste RCLONE_PASS="$(cat /rem/senha.txt)"
export RCLONE_USER RCLONE_PASS
# WebDAV (porta 8443) e SFTP por senha (porta 2022) gravam em /srv.
rclone serve webdav /srv --addr :8443 --cert /rem/servidor.pem --key /rem/servidor.key --cache-dir /cache 2> /saida/webdav.log &
rclone serve sftp /srv --addr :2022 --cache-dir /cache 2> /saida/sftp.log &
# SFTP que também aceita chave pública (porta 2023), com outra chave de servidor, grava em /srv-b.
rclone serve sftp /srv-b --addr :2023 --cache-dir /cache-b --authorized-keys /rem/autorizadas 2> /saida/sftp-chave.log &
wait
