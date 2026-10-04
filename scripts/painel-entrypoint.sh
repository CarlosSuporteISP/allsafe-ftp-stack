#!/usr/bin/env bash
# Entrada do container do painel. SÓ PARA REDE PRIVADA: recusa endereço e rede que não sejam internos.
set -Eeuo pipefail

die() { echo "FALHA: $*" >&2; exit 1; }
# shellcheck source=scripts/rede-privada.sh
source /usr/local/lib/allsafe/rede-privada.sh

# A senha do painel chega só como hash, pelo segredo montado pelo Compose.
secret_file=/run/secrets/painel_password_hash
for variavel in PAINEL_PASSWORD PAINEL_PASSWORD_HASH; do
  [[ -z "${!variavel:-}" ]] || die "$variavel não é aceita: a senha do painel fica em .secrets/, nunca em variável"
done
[[ -r "$secret_file" ]] || die "segredo $secret_file ausente: rode ./deploy.sh, que cria .secrets/painel_password_hash.txt"

PAINEL_BIND_IP="${PAINEL_BIND_IP:-127.0.0.1}"
PAINEL_REDES_PERMITIDAS="${PAINEL_REDES_PERMITIDAS:-127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16}"
PAINEL_CERT_CN="${PAINEL_CERT_CN:-}"

exigir_ip_privado PAINEL_BIND_IP "$PAINEL_BIND_IP" || exit 1
IFS=',' read -r -a redes <<< "$PAINEL_REDES_PERMITIDAS"
[[ ${#redes[@]} -gt 0 ]] || die "PAINEL_REDES_PERMITIDAS está vazia"
for rede in "${redes[@]}"; do
  rede="${rede// /}"
  cidr_privado "$rede" || die "PAINEL_REDES_PERMITIDAS: '$rede' não é rede privada. Esta stack é só para rede interna."
done
[[ -z "$PAINEL_CERT_CN" || "$PAINEL_CERT_CN" =~ ^[a-z0-9]([a-z0-9.-]{0,251}[a-z0-9])?$ ]] \
  || die "PAINEL_CERT_CN inválido: use um nome interno em minúsculas ou um IP privado"
cn_ip=false
if [[ "$PAINEL_CERT_CN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  cn_ip=true
  exigir_ip_privado PAINEL_CERT_CN "$PAINEL_CERT_CN" || exit 1
fi

[[ -d /auth && -d /data ]] || die "pastas /auth e /data ausentes: o painel usa as mesmas do serviço ftp"

# /painel vem do host por bind mount: dono e modo são normalizados a cada subida.
chown root:root /painel
chmod 0700 /painel
install -d -o root -g root -m 0700 /painel/tls
touch /painel/auditoria.log
chmod 0600 /painel/auditoria.log

# Certificado autoassinado, válido para os endereços pelos quais o painel é aberto.
# O arquivo painel-san.txt marca que o certificado foi gerado aqui: enquanto ele existir, o
# certificado é refeito quando os endereços mudam ou quando faltam menos de 30 dias para vencer.
# Certificado próprio (da CA interna): grave painel-cert.pem e painel-key.pem e apague o painel-san.txt.
certificado=/painel/tls/painel-cert.pem
chave=/painel/tls/painel-key.pem
marca=/painel/tls/painel-san.txt
san="DNS:localhost,IP:127.0.0.1"
[[ "$PAINEL_BIND_IP" == 127.0.0.1 ]] || san+=",IP:${PAINEL_BIND_IP}"
if [[ "$cn_ip" == true ]]; then
  [[ "$PAINEL_CERT_CN" == "$PAINEL_BIND_IP" || "$PAINEL_CERT_CN" == 127.0.0.1 ]] || san+=",IP:${PAINEL_CERT_CN}"
elif [[ -n "$PAINEL_CERT_CN" && "$PAINEL_CERT_CN" != localhost ]]; then
  san+=",DNS:${PAINEL_CERT_CN}"
fi

gerar=false
if [[ ! -s "$certificado" || ! -s "$chave" ]]; then
  gerar=true
elif [[ -f "$marca" ]]; then
  [[ "$(cat "$marca")" == "$san" ]] || gerar=true
  openssl x509 -in "$certificado" -noout -checkend $((30 * 86400)) >/dev/null 2>&1 || gerar=true
fi
if [[ "$gerar" == true ]]; then
  umask 077
  openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -sha256 -days 825 \
    -keyout "$chave" -out "$certificado" \
    -subj "/C=BR/O=AllSafe/CN=${PAINEL_CERT_CN:-allsafe-ftp-painel}" \
    -addext "subjectAltName=${san}" >/dev/null 2>&1 || die "não foi possível gerar o certificado do painel"
  printf '%s\n' "$san" > "$marca"
  echo "Certificado do painel gerado para: ${san}"
fi
chmod 0600 "$chave"
chmod 0644 "$certificado"

exec python3 /opt/painel/servidor.py
