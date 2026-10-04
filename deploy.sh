#!/usr/bin/env bash
# Instala ou atualiza a stack. SÓ PARA REDE PRIVADA: recusa bind e IP anunciado fora de IP privado.
set -Eeuo pipefail
root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$root_dir"
# shellcheck source=scripts/rede-privada.sh
source scripts/rede-privada.sh
# shellcheck source=scripts/ambiente.sh
source scripts/ambiente.sh

env_file="${ENV_FILE:-.env}"
size=small
check_only=false
usage() { echo "Uso: $0 [--size small|medium|large] [--check-only]"; }
die() { echo "ERRO: $*" >&2; exit 1; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --size) size="${2:?Informe o perfil}"; shift 2 ;;
    --check-only) check_only=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção inválida: $1" >&2; usage >&2; exit 64 ;;
  esac
done

profile_file="profiles/${size}.env"
[[ -f "$profile_file" ]] || { echo "ERRO: perfil inexistente: $size" >&2; usage >&2; exit 64; }
[[ -f "$env_file" ]] || { cp .env.example "$env_file"; chmod 0600 "$env_file"; echo "Edite $env_file e execute novamente."; exit 1; }

# O .env guarda só variável ajustável: senha ali é recusada.
for chave in FTP_PASSWORD FTP_PASSWORD_FILE; do
  if [[ -n "$(env_valor "$chave")" ]]; then
    echo "ERRO: $env_file ainda traz $chave. Senha não fica mais no .env." >&2
    echo "      Migração: grave a senha em .secrets/ftp_password.txt (modo 0600), apague as linhas" >&2
    echo "      FTP_PASSWORD e FTP_PASSWORD_FILE do .env e rode ./deploy.sh de novo. Guia: doc/segredos.md" >&2
    exit 1
  fi
done
for chave in PAINEL_PASSWORD PAINEL_PASSWORD_HASH; do
  [[ -z "$(env_valor "$chave")" ]] || die "$env_file traz $chave. A senha do painel fica só em .secrets/ (guia: doc/segredos.md)"
done

data_dir="$(env_valor DATA_DIR)"
secrets_dir="$(env_valor SECRETS_DIR ./.secrets)"
[[ "$data_dir" == /* ]] || die "DATA_DIR tem de ser um caminho absoluto em $env_file (veja o .env.example)"

exigir_ip_privado FTP_BIND_IP "$(env_valor FTP_BIND_IP 127.0.0.1)" || exit 1
exigir_ip_privado FTP_PUBLIC_IP "$(env_valor FTP_PUBLIC_IP 127.0.0.1)" || exit 1
exigir_ip_privado PAINEL_BIND_IP "$(env_valor PAINEL_BIND_IP 127.0.0.1)" || exit 1
IFS=',' read -r -a redes_painel <<< "$(env_valor PAINEL_REDES_PERMITIDAS 127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16)"
for rede in "${redes_painel[@]}"; do
  cidr_privado "${rede// /}" || die "PAINEL_REDES_PERMITIDAS: '${rede// /}' não é rede privada. Esta stack é só para rede interna."
done
painel_cn="$(env_valor PAINEL_CERT_CN)"
if [[ "$painel_cn" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  exigir_ip_privado PAINEL_CERT_CN "$painel_cn" || exit 1
fi

compose() { docker compose --env-file "$env_file" --env-file "$profile_file" "$@"; }

if [[ "$check_only" == true ]]; then
  compose config --quiet
  echo "OK: perfil '$size', rede privada e compose validados; nada foi alterado."
  exit 0
fi

# Pastas dos dados (bind mount). O container ajusta dono e modo de cada uma ao subir.
mkdir -p "$data_dir/dados" "$data_dir/auth" "$data_dir/certs" "$data_dir/painel"

# Senha do usuário inicial: gerada forte na primeira execução; nunca regravada se já existe.
# Para usar uma senha específica, grave-a no arquivo antes de rodar.
umask 077
mkdir -p "$secrets_dir"
chmod 0700 "$secrets_dir"
secret_file="$secrets_dir/ftp_password.txt"
if [[ ! -s "$secret_file" ]]; then
  command -v openssl >/dev/null 2>&1 || die "openssl não encontrado no host (necessário para gerar a senha)"
  openssl rand -base64 36 > "$secret_file"
  echo "Gerada uma senha forte em $secret_file (0600). Guarde-a para o cliente FTP."
fi
chmod 0600 "$secret_file"

compose config --quiet
compose build

# Senha do painel: gerada forte na primeira execução. O container recebe só o hash scrypt;
# a senha em texto fica em painel_password.txt, só no host, até ser trocada por scripts/painel-senha.sh.
painel_hash="$secrets_dir/painel_password_hash.txt"
if [[ ! -s "$painel_hash" ]]; then
  painel_senha="$secrets_dir/painel_password.txt"
  if [[ ! -s "$painel_senha" ]]; then
    command -v openssl >/dev/null 2>&1 || die "openssl não encontrado no host (necessário para gerar a senha)"
    openssl rand -base64 36 > "$painel_senha"
    echo "Gerada uma senha forte para o painel em $painel_senha (0600)."
  fi
  chmod 0600 "$painel_senha"
  ENV_FILE="$env_file" scripts/painel-senha.sh --inicial < "$painel_senha"
fi
chmod 0600 "$painel_hash"

compose up -d
compose ps
echo "Painel: https://$(env_valor PAINEL_BIND_IP 127.0.0.1):$(env_valor PAINEL_PORT 8443)  (certificado autoassinado; só rede privada, atrás de firewall)"
