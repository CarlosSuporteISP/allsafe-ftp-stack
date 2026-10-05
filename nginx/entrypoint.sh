#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Entrada do container do nginx, a frente web do painel. Por padrão, só para rede privada.
# Roda sem root: gera a configuração em /run/nginx a partir do modelo e das redes permitidas.
set -Eeuo pipefail

die() { echo "FALHA: $*" >&2; exit 1; }
# shellcheck source=scripts/rede-privada.sh
source /usr/local/lib/allsafe/rede-privada.sh

modelo=/etc/allsafe-nginx/nginx.conf.modelo
configuracao=/run/nginx/nginx.conf
soquete=/nginx/painel.sock
certificado=/nginx/tls/painel-cert.pem
chave=/nginx/tls/painel-key.pem

[[ "$(id -u)" != 0 ]] || die "o nginx desta stack não roda como root: confira 'user' no compose.yaml"

conferir_opcao_ip_publico
PAINEL_REDES_PERMITIDAS="${PAINEL_REDES_PERMITIDAS:-127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16}"
IFS=',' read -r -a redes <<< "$PAINEL_REDES_PERMITIDAS"
[[ ${#redes[@]} -gt 0 ]] || die "PAINEL_REDES_PERMITIDAS está vazia"
regras=$'        allow 127.0.0.1;\n'
for rede in "${redes[@]}"; do
  rede="${rede// /}"
  exigir_rede PAINEL_REDES_PERMITIDAS "$rede" || exit 1
  regras+="        allow ${rede};"$'\n'
done

# O painel sobe antes: cria o soquete e entrega a cópia do certificado. Espera curta, para o caso de
# os dois containers serem iniciados juntos pelo Docker (reinício do host).
for _ in $(seq 1 30); do
  [[ -S "$soquete" && -r "$certificado" && -r "$chave" ]] && break
  sleep 1
done
[[ -S "$soquete" ]] || die "soquete do painel ausente em $soquete: o serviço painel está no ar?"
[[ -r "$certificado" && -r "$chave" ]] || die "certificado do painel ausente ou ilegível em /nginx/tls"

while IFS= read -r linha; do
  if [[ "$linha" == "@REDES@" ]]; then
    printf '%s' "$regras"
  else
    printf '%s\n' "$linha"
  fi
done < "$modelo" > "$configuracao"

nginx -e stderr -q -t -c "$configuracao" || die "configuração do nginx recusada"
aviso_ip_publico >&2
echo "nginx pronto em 8443/tcp (HTTPS), à frente do painel; redes permitidas: ${PAINEL_REDES_PERMITIDAS}"
exec nginx -e stderr -c "$configuracao"
