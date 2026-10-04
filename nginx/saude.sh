#!/usr/bin/env bash
# Healthcheck do nginx: pede /saude ao painel passando pelo nginx (TLS e soquete Unix), de dentro
# do container. Não confere a cadeia do certificado: serve também para certificado da CA interna.
set -Eeuo pipefail
resposta="$(printf 'GET /saude HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n' \
  | timeout 6 openssl s_client -quiet -connect 127.0.0.1:8443 -servername localhost 2>/dev/null)" || true
[[ "$resposta" == "HTTP/1.1 200"* && "$resposta" == *$'\n'ok ]]
