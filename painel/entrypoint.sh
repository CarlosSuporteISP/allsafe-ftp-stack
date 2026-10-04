#!/usr/bin/env bash
# Entrada do container do painel. Por padrão, só para rede privada: recusa endereço e rede que não
# sejam internos, a não ser que quem instalou tenha ligado REDE_PERMITIR_IP_PUBLICO.
set -Eeuo pipefail

die() { echo "FALHA: $*" >&2; exit 1; }
# shellcheck source=scripts/rede-privada.sh
source /usr/local/lib/allsafe/rede-privada.sh

# A senha do primeiro administrador chega só como hash, pelo segredo montado pelo Compose.
secret_file=/run/secrets/painel_admin_inicial_senha_hash
for variavel in PAINEL_PASSWORD PAINEL_PASSWORD_HASH; do
  [[ -z "${!variavel:-}" ]] || die "$variavel não é aceita: a senha do painel fica em .secrets/, nunca em variável"
done
[[ -r "$secret_file" ]] || die "segredo $secret_file ausente: rode ./deploy.sh, que cria .secrets/painel-admin-inicial-senha-hash.txt"

PAINEL_BIND_IP="${PAINEL_BIND_IP:-127.0.0.1}"
PAINEL_REDES_PERMITIDAS="${PAINEL_REDES_PERMITIDAS:-127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16}"
PAINEL_CERT_CN="${PAINEL_CERT_CN:-}"
PAINEL_ADMIN_USER="${PAINEL_ADMIN_USER:-admin}"

conferir_opcao_ip_publico
exigir_ip PAINEL_BIND_IP "$PAINEL_BIND_IP" || exit 1
IFS=',' read -r -a redes <<< "$PAINEL_REDES_PERMITIDAS"
[[ ${#redes[@]} -gt 0 ]] || die "PAINEL_REDES_PERMITIDAS está vazia"
for rede in "${redes[@]}"; do
  rede="${rede// /}"
  exigir_rede PAINEL_REDES_PERMITIDAS "$rede" || exit 1
done
[[ -z "$PAINEL_CERT_CN" || "$PAINEL_CERT_CN" =~ ^[a-z0-9]([a-z0-9.-]{0,251}[a-z0-9])?$ ]] \
  || die "PAINEL_CERT_CN inválido: use um nome em minúsculas ou um endereço IPv4"
[[ "$PAINEL_ADMIN_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] \
  || die "PAINEL_ADMIN_USER inválido: letras minúsculas, números, _ e -; começa com letra ou _; até 32 caracteres"
[[ "${PAINEL_ACESSO_USUARIOS_FTP:-sim}" == sim || "${PAINEL_ACESSO_USUARIOS_FTP:-sim}" == nao ]] \
  || die "PAINEL_ACESSO_USUARIOS_FTP deve ser 'sim' ou 'nao'"
cn_ip=false
if [[ "$PAINEL_CERT_CN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  cn_ip=true
  exigir_ip PAINEL_CERT_CN "$PAINEL_CERT_CN" || exit 1
fi

[[ -d /auth && -d /data ]] || die "pastas /auth e /data ausentes: o painel usa as mesmas do serviço ftp"
[[ -d /nginx ]] || die "pasta /nginx ausente: é por ela que o nginx alcança o painel (rode ./deploy.sh)"

# /painel vem do host por bind mount: dono e modo são normalizados a cada subida.
chown root:root /painel
chmod 0700 /painel
install -d -o root -g root -m 0700 /painel/tls
touch /painel/auditoria.log
chmod 0600 /painel/auditoria.log
# Administradores do painel (nome e hash da senha): só o root lê, também depois de uma restauração.
if [[ -e /painel/administradores ]]; then
  chown root:root /painel/administradores
  chmod 0600 /painel/administradores
fi

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

# /nginx é a pasta que o painel divide com o nginx (uid e gid 10001, sem root): nela ficam o soquete
# Unix do painel e a cópia do certificado. Só o root e o grupo do nginx entram; o nginx monta a pasta
# somente para leitura. A cópia é refeita a cada subida, para acompanhar o certificado em /painel/tls.
gid_nginx=10001
chown root:"$gid_nginx" /nginx
chmod 0750 /nginx
install -d -o root -g "$gid_nginx" -m 0750 /nginx/tls
install -o root -g "$gid_nginx" -m 0644 "$certificado" /nginx/tls/painel-cert.pem
install -o root -g "$gid_nginx" -m 0640 "$chave" /nginx/tls/painel-key.pem
rm -f /nginx/painel.sock

aviso_ip_publico >&2

exec python3 /opt/painel/servidor.py
