#!/usr/bin/env bash
set -Eeuo pipefail

die() { echo "FALHA: $*" >&2; exit 1; }
# shellcheck source=scripts/rede-privada.sh
source /usr/local/lib/allsafe/rede-privada.sh

# A senha vem só do segredo montado pelo Compose; variável de ambiente com senha é recusada.
secret_file=/run/secrets/ftp_password
[[ -z "${FTP_PASSWORD:-}" ]] || die "FTP_PASSWORD não é mais aceita: grave a senha em .secrets/ftp_password.txt"
[[ -r "$secret_file" ]] || die "segredo $secret_file ausente: rode ./deploy.sh, que cria .secrets/ftp_password.txt"

FTP_USER="${FTP_USER:-transfer}"
FTP_BIND_IP="${FTP_BIND_IP:-127.0.0.1}"
FTP_PUBLIC_IP="${FTP_PUBLIC_IP:-127.0.0.1}"
FTP_PASSIVE_PORT_START="${FTP_PASSIVE_PORT_START:-30000}"
FTP_PASSIVE_PORT_END="${FTP_PASSIVE_PORT_END:-30049}"
FTP_TLS_MODE="${FTP_TLS_MODE:-2}"
FTP_MAX_CLIENTS="${FTP_MAX_CLIENTS:-50}"
FTP_MAX_CLIENTS_PER_IP="${FTP_MAX_CLIENTS_PER_IP:-8}"
password="$(tr -d '\r\n' < "$secret_file")"

exigir_ip_privado FTP_BIND_IP "$FTP_BIND_IP" || exit 1
exigir_ip_privado FTP_PUBLIC_IP "$FTP_PUBLIC_IP" || exit 1

[[ "$FTP_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "FTP_USER invalido"
[[ ${#password} -ge 12 ]] || die "a senha FTP deve ter pelo menos 12 caracteres"
[[ "$FTP_PASSIVE_PORT_START" =~ ^[0-9]+$ && "$FTP_PASSIVE_PORT_END" =~ ^[0-9]+$ ]] || die "faixa passiva invalida"
(( FTP_PASSIVE_PORT_START >= 1024 && FTP_PASSIVE_PORT_END <= 65535 && FTP_PASSIVE_PORT_START <= FTP_PASSIVE_PORT_END )) || die "faixa passiva fora dos limites"
[[ "$FTP_TLS_MODE" =~ ^[0123]$ ]] || die "FTP_TLS_MODE deve ser 0, 1, 2 ou 3"

# As pastas vêm do host por bind mount: o dono e o modo são normalizados a cada subida.
chown root:root /data /auth /etc/ssl/private
chmod 0755 /data
chmod 0750 /auth
chmod 0700 /etc/ssl/private
install -d -o ftpdata -g ftpdata -m 0750 "/data/$FTP_USER"
# Mesma trava do allsafe-ftp-user: o painel pode estar alterando usuários agora.
exec 9>/auth/.lock
flock -w 30 9 || die "arquivo de usuarios em uso por outra alteracao"
touch /auth/pureftpd.passwd
chmod 0600 /auth/pureftpd.passwd

if grep -q "^${FTP_USER}:" /auth/pureftpd.passwd; then
  printf '%s\n%s\n' "$password" "$password" | pure-pw usermod "$FTP_USER" -f /auth/pureftpd.passwd >/dev/null
else
  printf '%s\n%s\n' "$password" "$password" | pure-pw useradd "$FTP_USER" \
    -f /auth/pureftpd.passwd -u ftpdata -g ftpdata -d "/data/$FTP_USER" >/dev/null
fi
pure-pw mkdb /auth/pureftpd.pdb -f /auth/pureftpd.passwd
chmod 0600 /auth/pureftpd.passwd /auth/pureftpd.pdb
exec 9>&-  # solta a trava: o descritor não pode ir para o pure-ftpd

certificate=/etc/ssl/private/pure-ftpd.pem
if [[ ! -s "$certificate" ]]; then
  umask 077
  if [[ "${FTP_CERT_CN:-localhost}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    certificate_san="IP:${FTP_CERT_CN:-127.0.0.1}"
  else
    certificate_san="DNS:${FTP_CERT_CN:-localhost}"
  fi
  openssl req -x509 -nodes -newkey rsa:3072 -sha256 -days 825 \
    -keyout "$certificate" -out "$certificate" \
    -subj "/C=BR/O=AllSafe/CN=${FTP_CERT_CN:-localhost}" \
    -addext "subjectAltName=${certificate_san}" >/dev/null 2>&1
fi
chmod 0600 "$certificate"
# Parte pública do certificado, para o painel mostrar validade e impressão digital sem ver a chave.
openssl x509 -in "$certificate" -out /auth/ftp-cert.pem
chmod 0644 /auth/ftp-cert.pem

unset password
# 0 e 1 existem para equipamento antigo sem suporte a TLS: o aviso fica no registro a cada subida.
case "$FTP_TLS_MODE" in
  0) echo "AVISO: FTP_TLS_MODE=0, FTP sem TLS: senhas e arquivos trafegam em texto puro. Só para equipamento sem suporte a TLS, em rede interna isolada." >&2 ;;
  1) echo "AVISO: FTP_TLS_MODE=1, TLS opcional: quem entra sem TLS manda senha e arquivos em texto puro. Só para equipamento sem suporte a TLS, em rede interna isolada." >&2 ;;
esac
echo "FTP pronto em 2121/tcp; TLS=${FTP_TLS_MODE}; passivo=${FTP_PASSIVE_PORT_START}-${FTP_PASSIVE_PORT_END}"
exec /usr/sbin/pure-ftpd \
  -A -E -H -j -R \
  -c "$FTP_MAX_CLIENTS" -C "$FTP_MAX_CLIENTS_PER_IP" \
  -I 15 -L 10000:8 -u 10000 -U 133:022 \
  -l "puredb:/auth/pureftpd.pdb" \
  -p "${FTP_PASSIVE_PORT_START}:${FTP_PASSIVE_PORT_END}" \
  -P "$FTP_PUBLIC_IP" -S "0.0.0.0,2121" -Y "$FTP_TLS_MODE" \
  -O clf:/dev/stdout
