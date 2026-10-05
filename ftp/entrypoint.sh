#!/usr/bin/env bash
set -Eeuo pipefail

die() { echo "FALHA: $*" >&2; exit 1; }
# shellcheck source=scripts/rede-privada.sh
source /usr/local/lib/allsafe/rede-privada.sh

# A senha vem só do segredo montado pelo Compose; variável de ambiente com senha é recusada.
secret_file=/run/secrets/ftp_usuario_inicial_senha
[[ -z "${FTP_PASSWORD:-}" ]] || die "FTP_PASSWORD não é aceita: a senha fica em .secrets/ftp-usuario-inicial-senha.txt"
[[ -r "$secret_file" ]] || die "segredo $secret_file ausente: rode ./deploy.sh, que cria .secrets/ftp-usuario-inicial-senha.txt"

FTP_USER="${FTP_USER:-transfer}"
FTP_BIND_IP="${FTP_BIND_IP:-127.0.0.1}"
FTP_PASSIVE_IP="${FTP_PASSIVE_IP:-127.0.0.1}"
FTP_PASSIVE_PORT_START="${FTP_PASSIVE_PORT_START:-30000}"
FTP_PASSIVE_PORT_END="${FTP_PASSIVE_PORT_END:-30049}"
FTP_TLS_MODE="${FTP_TLS_MODE:-2}"
FTP_TLS_EXCECOES="${FTP_TLS_EXCECOES:-nao}"
FTP_MAX_CLIENTS="${FTP_MAX_CLIENTS:-50}"
FTP_MAX_CLIENTS_PER_IP="${FTP_MAX_CLIENTS_PER_IP:-8}"
password="$(tr -d '\r\n' < "$secret_file")"

conferir_opcao_ip_publico
exigir_ip FTP_BIND_IP "$FTP_BIND_IP" || exit 1
exigir_ip FTP_PASSIVE_IP "$FTP_PASSIVE_IP" || exit 1

[[ "$FTP_USER" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || die "FTP_USER invalido"
[[ ${#password} -ge 12 ]] || die "a senha FTP deve ter pelo menos 12 caracteres"
[[ "$FTP_PASSIVE_PORT_START" =~ ^[0-9]+$ && "$FTP_PASSIVE_PORT_END" =~ ^[0-9]+$ ]] || die "faixa passiva invalida"
(( FTP_PASSIVE_PORT_START >= 1024 && FTP_PASSIVE_PORT_END <= 65535 && FTP_PASSIVE_PORT_START <= FTP_PASSIVE_PORT_END )) || die "faixa passiva fora dos limites"
[[ "$FTP_TLS_MODE" =~ ^[0123]$ ]] || die "FTP_TLS_MODE deve ser 0, 1, 2 ou 3"
[[ "$FTP_MAX_CLIENTS" =~ ^[1-9][0-9]{0,4}$ ]] || die "FTP_MAX_CLIENTS deve ser um inteiro maior que zero"
[[ "$FTP_MAX_CLIENTS_PER_IP" =~ ^[1-9][0-9]{0,4}$ ]] || die "FTP_MAX_CLIENTS_PER_IP deve ser um inteiro maior que zero"
# Com IP público aceito, senha em texto puro não passa: o TLS tem de ser obrigatório.
if ip_publico_permitido && (( FTP_TLS_MODE < 2 )); then
  die "REDE_PERMITIR_IP_PUBLICO=sim exige FTP_TLS_MODE=2 ou 3; está $FTP_TLS_MODE (FTP sem TLS na internet entrega a senha a quem escuta)"
fi
# Exceção de TLS por usuário: só sobre o modo 2 (em 0 e 1 todos já entram sem TLS; o 3 exige TLS também nos dados)
# e nunca com IP público aceito.
[[ "$FTP_TLS_EXCECOES" == nao || "$FTP_TLS_EXCECOES" == sim ]] || die "FTP_TLS_EXCECOES deve ser 'nao' ou 'sim'"
if [[ "$FTP_TLS_EXCECOES" == sim ]]; then
  [[ "$FTP_TLS_MODE" == 2 ]] || die "FTP_TLS_EXCECOES=sim exige FTP_TLS_MODE=2; está $FTP_TLS_MODE"
  if ip_publico_permitido; then
    die "FTP_TLS_EXCECOES=sim não combina com REDE_PERMITIR_IP_PUBLICO=sim (FTP sem TLS na internet entrega a senha a quem escuta)"
  fi
fi

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

# Custo do hash da senha (argon2id): o pure-pw divide a memória da conta pelo número de logins ao mesmo
# tempo (-C). Sem a opção ele supõe 8, e cada conferência de senha ocupa o processador por cerca de 3 s:
# poucas senhas erradas ao mesmo tempo seguravam o login de todos por quase um minuto.
# A senha do segredo é reaplicada a cada subida pelo `passwd`: o `usermod` não regrava senha.
if grep -q "^${FTP_USER}:" /auth/pureftpd.passwd; then
  printf '%s\n%s\n' "$password" "$password" | pure-pw passwd "$FTP_USER" -f /auth/pureftpd.passwd -C "$FTP_MAX_CLIENTS" >/dev/null
else
  printf '%s\n%s\n' "$password" "$password" | pure-pw useradd "$FTP_USER" \
    -f /auth/pureftpd.passwd -u ftpdata -g ftpdata -d "/data/$FTP_USER" -C "$FTP_MAX_CLIENTS" >/dev/null
fi
pure-pw mkdb /auth/pureftpd.pdb -f /auth/pureftpd.passwd
chmod 0600 /auth/pureftpd.passwd /auth/pureftpd.pdb
# Lista de quem entra sem TLS (allsafe-ftp-user tls-dispensar): só o root lê, também depois de uma restauração.
if [[ -f /auth/sem-tls.lista && ! -L /auth/sem-tls.lista ]]; then
  chown root:root /auth/sem-tls.lista
  chmod 0600 /auth/sem-tls.lista
fi
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
aviso_ip_publico >&2
opcoes=(
  -A -E -H -j -R
  -c "$FTP_MAX_CLIENTS" -C "$FTP_MAX_CLIENTS_PER_IP"
  -I 15 -L 10000:8 -u 10000 -U 133:022
  -p "${FTP_PASSIVE_PORT_START}:${FTP_PASSIVE_PORT_END}"
  -P "$FTP_PASSIVE_IP" -S "0.0.0.0,2121"
  -O clf:/dev/stdout
)
if [[ "$FTP_TLS_EXCECOES" != sim ]]; then
  echo "FTP pronto em 2121/tcp; TLS=${FTP_TLS_MODE}; passivo=${FTP_PASSIVE_PORT_START}-${FTP_PASSIVE_PORT_END}"
  exec /usr/sbin/pure-ftpd "${opcoes[@]}" -l "puredb:/auth/pureftpd.pdb" -Y "$FTP_TLS_MODE"
fi

# TLS por usuário. O pure-ftpd aceita sessão com e sem TLS (-Y 1) e pergunta primeiro ao pure-authd, que
# chama o porteiro: sem TLS só segue quem está em /auth/sem-tls.lista. Quem segue tem a senha conferida
# no PureDB, como sempre. Sem o pure-authd o pure-ftpd cairia direto no PureDB e aceitaria todos sem TLS:
# por isso os dois processos são vigiados aqui e, se um deles sair, o container encerra (e o Docker o
# sobe de novo, com os dois).
soquete=/run/pure-authd.sock
rm -f "$soquete"
marcados="$(grep -c -E '^[a-z_][a-z0-9_-]{0,31}$' /auth/sem-tls.lista 2>/dev/null || true)"
echo "AVISO: FTP_TLS_EXCECOES=sim: ${marcados:-0} usuário(s) marcado(s) no painel entram sem TLS, com senha e arquivos em texto puro. Os demais continuam obrigados a usar TLS, mas um equipamento mal configurado manda a senha em texto puro antes de ser recusado. Só para equipamento sem suporte a TLS, em rede interna isolada." >&2
/usr/sbin/pure-authd -s "$soquete" -r /usr/local/sbin/allsafe-ftp-porteiro-tls &
porteiro=$!
for _ in $(seq 1 100); do
  [[ -S "$soquete" ]] && break
  kill -0 "$porteiro" 2>/dev/null || break
  sleep 0.1
done
[[ -S "$soquete" ]] && kill -0 "$porteiro" 2>/dev/null || die "o pure-authd não abriu o soquete $soquete: o FTP não sobe sem o porteiro do TLS"
/usr/sbin/pure-ftpd "${opcoes[@]}" -l "extauth:$soquete" -l "puredb:/auth/pureftpd.pdb" -Y 1 &
servidor=$!
parar() { kill -TERM "$servidor" "$porteiro" 2>/dev/null || true; }
trap 'parar; wait; exit 0' TERM INT
echo "FTP pronto em 2121/tcp; TLS=${FTP_TLS_MODE} com exceção por usuário; passivo=${FTP_PASSIVE_PORT_START}-${FTP_PASSIVE_PORT_END}"
wait -n "$servidor" "$porteiro" || true
kill -0 "$porteiro" 2>/dev/null && quem=pure-ftpd || quem=pure-authd
parar
echo "FALHA: o $quem saiu: o container encerra para ninguém entrar sem a conferência do TLS por usuário" >&2
exit 1
