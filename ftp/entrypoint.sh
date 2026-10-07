#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
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
FTP_BLOQUEIO_TENTATIVAS="${FTP_BLOQUEIO_TENTATIVAS:-5}"
FTP_BLOQUEIO_MINUTOS="${FTP_BLOQUEIO_MINUTOS:-15}"
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
[[ "$FTP_BLOQUEIO_TENTATIVAS" =~ ^(0|[1-9][0-9]{0,2})$ ]] && (( FTP_BLOQUEIO_TENTATIVAS <= 100 )) || die "FTP_BLOQUEIO_TENTATIVAS deve ficar entre 0 e 100 (0 desliga o bloqueio por tentativa)"
[[ "$FTP_BLOQUEIO_MINUTOS" =~ ^[1-9][0-9]{0,3}$ ]] && (( FTP_BLOQUEIO_MINUTOS <= 1440 )) || die "FTP_BLOQUEIO_MINUTOS deve ficar entre 1 e 1440"
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
# Mesma trava do allsafe-ftp-user: o painel pode estar alterando usuários agora.
exec 9>/auth/.lock
flock -w 30 9 || die "arquivo de usuarios em uso por outra alteracao"
touch /auth/pureftpd.passwd
chmod 0600 /auth/pureftpd.passwd

# Usuário inicial: criado uma vez, na primeira subida. A marca em /auth guarda o nome de quem já foi criado;
# removido depois pelo painel ou pelo manage-user.sh, ele não volta nas subidas seguintes. Trocar o FTP_USER
# no .env cria o usuário do nome novo, também uma vez.
# Senha do usuário inicial: a do segredo vale quando o usuário é criado e sempre que o arquivo do segredo
# muda. Trocada pelo painel ou pelo manage-user.sh (o allsafe-ftp-user deixa a marca), a senha nova fica até
# o segredo mudar. Para saber se mudou, a partida guarda a impressão do segredo aplicado por último:
# sha512-crypt com sal, só o root lê; a senha em si não é gravada.
impressao=/auth/senha-inicial.aplicada
marca_inicial=/auth/senha-inicial.trocada
marca_criado=/auth/usuario-inicial.criado
inicial_ja_criado() {
  local nome=""
  [[ -f "$marca_criado" && ! -L "$marca_criado" ]] || return 1
  IFS= read -r nome < "$marca_criado" || true
  [[ "$nome" == "$FTP_USER" ]]
}
marcar_criado() {
  rm -f "$marca_criado.novo"
  ( umask 077; printf '%s\n' "$FTP_USER" > "$marca_criado.novo" )
  mv -f "$marca_criado.novo" "$marca_criado"
}
casa_inicial() {
  local nome casa _
  while IFS=: read -r nome _ _ _ _ casa _; do
    [[ "$nome" == "$FTP_USER" ]] && { printf '%s\n' "$casa"; return 0; }
  done < /auth/pureftpd.passwd
  return 1
}
segredo_ja_aplicado() {
  local guardada=""
  [[ -f "$impressao" && ! -L "$impressao" ]] || return 1
  IFS= read -r guardada < "$impressao" || true
  [[ "$guardada" =~ ^\$6\$([A-Za-z0-9./]{1,16})\$[A-Za-z0-9./]{86}$ ]] || return 1
  [[ "$(printf '%s\n' "$password" | openssl passwd -6 -salt "${BASH_REMATCH[1]}" -stdin)" == "$guardada" ]]
}
trocada_por_fora() {
  local nome=""
  [[ -f "$marca_inicial" && ! -L "$marca_inicial" ]] || return 1
  IFS= read -r nome < "$marca_inicial" || true
  [[ "$nome" == "$FTP_USER" ]]
}
registrar_segredo() {
  rm -f "$impressao.novo" "$marca_inicial"
  ( umask 077; printf '%s\n' "$password" | openssl passwd -6 -salt "$(openssl rand -hex 8)" -stdin > "$impressao.novo" )
  mv -f "$impressao.novo" "$impressao"
}
# Custo do hash da senha (argon2id): o pure-pw divide a memória da conta pelo número de logins ao mesmo
# tempo (-C). Sem a opção ele supõe 8, e cada conferência de senha ocupa o processador por cerca de 3 s:
# poucas senhas erradas ao mesmo tempo seguravam o login de todos por quase um minuto.
# O `passwd` mantém a pasta do usuário, que pode ter sido trocada pelo painel; o `usermod` não regrava senha.
if casa="$(casa_inicial)"; then
  # A pasta de fábrica é refeita se sumiu; a escolhida pelo painel já foi criada por ele.
  [[ "$casa" != "/data/$FTP_USER/./" ]] || install -d -o ftpdata -g ftpdata -m 0750 "/data/$FTP_USER"
  if trocada_por_fora && segredo_ja_aplicado; then
    echo "Usuário inicial '$FTP_USER': mantida a senha trocada pelo painel; o arquivo do segredo não mudou desde então."
  else
    printf '%s\n%s\n' "$password" "$password" | pure-pw passwd "$FTP_USER" -f /auth/pureftpd.passwd -C "$FTP_MAX_CLIENTS" >/dev/null
    registrar_segredo
  fi
  # Instalação anterior à marca: o usuário que já existe passa a contar como criado.
  inicial_ja_criado || marcar_criado
elif inicial_ja_criado; then
  # A impressão acompanha o segredo: recriado depois com o mesmo nome, ele fica com a senha informada no painel.
  registrar_segredo
  echo "Usuário inicial '$FTP_USER': removido pelo administrador; não é recriado. Para tê-lo de novo, crie um usuário com este nome no painel."
else
  install -d -o ftpdata -g ftpdata -m 0750 "/data/$FTP_USER"
  printf '%s\n%s\n' "$password" "$password" | pure-pw useradd "$FTP_USER" \
    -f /auth/pureftpd.passwd -u ftpdata -g ftpdata -d "/data/$FTP_USER" -C "$FTP_MAX_CLIENTS" >/dev/null
  registrar_segredo
  marcar_criado
fi
pure-pw mkdb /auth/pureftpd.pdb -f /auth/pureftpd.passwd
chmod 0600 /auth/pureftpd.passwd /auth/pureftpd.pdb
# Lista de quem entra sem TLS (allsafe-ftp-user tls-dispensar): só o root lê, também depois de uma restauração.
if [[ -f /auth/sem-tls.lista && ! -L /auth/sem-tls.lista ]]; then
  chown root:root /auth/sem-tls.lista
  chmod 0600 /auth/sem-tls.lista
fi
# Bloqueios por tentativa (um arquivo por usuário e endereço): o vigia grava, o porteiro lê, o painel mostra.
# Só o root entra na pasta. O que ainda vale atravessa o reinício.
[[ ! -L /auth/bloqueios ]] || die "/auth/bloqueios é link simbólico: remova-o"
install -d -o root -g root -m 0700 /auth/bloqueios
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
)
# Toda entrada passa pelo porteiro. O pure-ftpd pergunta primeiro ao pure-authd, que chama o porteiro: ele
# recusa quem está bloqueado por senhas erradas e, com o TLS por usuário, quem chega sem TLS sem estar em
# /auth/sem-tls.lista (aí o pure-ftpd aceita sessão com e sem TLS, -Y 1). Quem segue tem a senha conferida
# no PureDB, como sempre. O vigia escuta o que o pure-ftpd registra, conta as senhas erradas e grava os
# bloqueios. Sem o pure-authd o pure-ftpd cairia direto no PureDB, sem bloqueio e sem a conferência do TLS,
# e sem o vigia ninguém mais seria bloqueado: por isso os três processos são vigiados aqui e, se um deles
# sair, o container encerra (e o Docker o sobe de novo, com os três).
soquete=/run/pure-authd.sock
modo_tls="$FTP_TLS_MODE"
descricao_tls="TLS=${FTP_TLS_MODE}"
rm -rf "$soquete" /dev/log /run/allsafe
install -d -o root -g root -m 0700 /run/allsafe /run/allsafe/recusa
if [[ "$FTP_TLS_EXCECOES" == sim ]]; then
  modo_tls=1
  descricao_tls+=" com exceção por usuário"
  : > /run/allsafe/tls-por-usuario
  marcados="$(grep -c -E '^[a-z_][a-z0-9_-]{0,31}$' /auth/sem-tls.lista 2>/dev/null || true)"
  echo "AVISO: FTP_TLS_EXCECOES=sim: ${marcados:-0} usuário(s) marcado(s) no painel entram sem TLS, com senha e arquivos em texto puro. Os demais continuam obrigados a usar TLS, mas um equipamento mal configurado manda a senha em texto puro antes de ser recusado. Só para equipamento sem suporte a TLS, em rede interna isolada." >&2
fi
# Espera até 10 s por um soquete aberto pelo processo que acabou de subir.
esperar_soquete() { # <soquete> <pid>
  local _
  for _ in $(seq 1 100); do
    [[ -S "$1" ]] && break
    kill -0 "$2" 2>/dev/null || break
    sleep 0.1
  done
  [[ -S "$1" ]] && kill -0 "$2" 2>/dev/null
}
/usr/local/sbin/allsafe-ftp-vigia &
vigia=$!
esperar_soquete /dev/log "$vigia" || die "o vigia não abriu o soquete /dev/log: o FTP não sobe sem a contagem das senhas erradas"
/usr/sbin/pure-authd -s "$soquete" -r /usr/local/sbin/allsafe-ftp-porteiro &
porteiro=$!
esperar_soquete "$soquete" "$porteiro" || die "o pure-authd não abriu o soquete $soquete: o FTP não sobe sem o porteiro"
/usr/sbin/pure-ftpd "${opcoes[@]}" -l "extauth:$soquete" -l "puredb:/auth/pureftpd.pdb" -Y "$modo_tls" &
servidor=$!
parar() { kill -TERM "$servidor" "$porteiro" "$vigia" 2>/dev/null || true; }
trap 'parar; wait; exit 0' TERM INT
echo "FTP pronto em 2121/tcp; ${descricao_tls}; passivo=${FTP_PASSIVE_PORT_START}-${FTP_PASSIVE_PORT_END}"
wait -n "$servidor" "$porteiro" "$vigia" || true
if ! kill -0 "$porteiro" 2>/dev/null; then quem=pure-authd; elif ! kill -0 "$vigia" 2>/dev/null; then quem=vigia; else quem=pure-ftpd; fi
parar
echo "FALHA: o $quem saiu: o container encerra para ninguém entrar sem a conferência do porteiro" >&2
exit 1
