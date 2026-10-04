#!/usr/bin/env bash
# Instala, reaplica, atualiza ou remove a stack em um comando, sem perguntas.
# SÓ PARA REDE PRIVADA: recusa bind e IP anunciado fora de IP privado.
set -Eeuo pipefail
root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$root_dir"
# shellcheck source=scripts/rede-privada.sh
source scripts/rede-privada.sh
# shellcheck source=scripts/ambiente.sh
source scripts/ambiente.sh

env_file="${ENV_FILE:-.env}"
size=""
check_only=false
atualizar=false
remover=false
apagar_dados=false
sim=false
usage() {
  cat <<'USO'
Uso: ./deploy.sh [--size small|medium|large] [--atualizar] [--check-only]
     ./deploy.sh --remover [--apagar-dados [--sim]]

  (sem opção)       instala ou reaplica: cria o .env, as pastas e as senhas que faltarem,
                    sobe os containers e espera ficarem healthy
  --size <perfil>   grava no .env os limites de profiles/<perfil>.env
                    (sem a opção, o .env fica como está)
  --atualizar       reconstrói as imagens sem cache, com os pacotes atuais do Debian
  --check-only      só valida a configuração; não cria nem sobe nada
  --remover         derruba os containers e a rede; dados, segredos e .env ficam
  --apagar-dados    com --remover: apaga também as pastas de DATA_DIR (pede confirmação)
  --sim             com --apagar-dados: dispensa a confirmação
USO
}
die() { echo "ERRO: $*" >&2; exit 1; }
uso_invalido() { echo "$*" >&2; usage >&2; exit 64; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --size) size="${2:?Informe o perfil}"; shift 2 ;;
    --check-only) check_only=true; shift ;;
    --atualizar) atualizar=true; shift ;;
    --remover) remover=true; shift ;;
    --apagar-dados) apagar_dados=true; shift ;;
    --sim) sim=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) uso_invalido "Opção inválida: $1" ;;
  esac
done
if [[ "$remover" == true ]]; then
  [[ -z "$size" && "$check_only" == false && "$atualizar" == false ]] || uso_invalido "Opção inválida: --remover só combina com --apagar-dados e --sim"
else
  [[ "$apagar_dados" == false && "$sim" == false ]] || uso_invalido "Opção inválida: --apagar-dados e --sim só valem com --remover"
fi
[[ "$sim" == false || "$apagar_dados" == true ]] || uso_invalido "Opção inválida: --sim só vale com --apagar-dados"

profile_file="profiles/${size:-small}.env"
[[ -f "$profile_file" ]] || { echo "ERRO: perfil inexistente: $size" >&2; usage >&2; exit 64; }

# Requisitos: conferidos antes de qualquer alteração.
command -v docker >/dev/null 2>&1 || die "Docker não encontrado. Instale o Docker Engine com o plugin Compose e rode de novo."
docker compose version >/dev/null 2>&1 || die "plugin Docker Compose não encontrado (docker compose version falhou)."
docker info >/dev/null 2>&1 || die "sem acesso ao Docker: o serviço está parado ou este usuário não está no grupo docker."

if [[ ! -f "$env_file" ]]; then
  if [[ "$check_only" == true ]]; then
    env_file=.env.example
    echo "Sem .env: validando com o .env.example."
  elif [[ "$remover" == true ]]; then
    die "$env_file não existe: não há instalação desta pasta para remover."
  else
    ( umask 077; cp .env.example "$env_file" )
    chmod 0600 "$env_file"
    echo "Criado $env_file a partir do .env.example: tudo em 127.0.0.1, só este servidor acessa."
  fi
fi

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

compose() { docker compose --env-file "$env_file" "$@"; }

if [[ "$remover" == true ]]; then
  if [[ "$apagar_dados" == true ]]; then
    [[ "$data_dir" =~ ^/[^/]+/[^/]+ ]] || die "DATA_DIR=$data_dir é raso demais para apagar por aqui; apague à mão."
    if [[ "$sim" == false ]]; then
      [[ -t 0 ]] || die "--apagar-dados sem terminal exige --sim."
      echo "Serão apagados os backups recebidos, os usuários, os certificados e a auditoria em $data_dir."
      read -r -p "Digite 'apagar' para confirmar: " resposta
      [[ "$resposta" == apagar ]] || die "confirmação não recebida; nada foi removido."
    fi
  fi
  compose down --remove-orphans
  if [[ "$apagar_dados" == true ]]; then
    pastas=()
    for pasta in dados auth certs painel; do
      [[ -d "$data_dir/$pasta" ]] && pastas+=("$pasta")
    done
    imagem="$(env_valor FTP_IMAGE allsafe-ftp:local)"
    if [[ ${#pastas[@]} -eq 0 ]]; then
      echo "Nenhuma pasta da stack em $data_dir."
    elif docker image inspect "$imagem" >/dev/null 2>&1; then
      # Os arquivos são do root e do ftpdata: quem apaga é um container sem rede, só com esta pasta.
      docker run --rm --network none --read-only -v "$data_dir":/alvo --entrypoint find "$imagem" \
        "${pastas[@]/#//alvo/}" -delete
    else
      for pasta in "${pastas[@]}"; do
        rm -rf -- "${data_dir:?}/$pasta" || die "sem permissão para apagar $data_dir/$pasta; apague como root."
      done
    fi
    rmdir "$data_dir" 2>/dev/null || true
    echo "Removidos os containers, a rede e as pastas de dados em $data_dir."
  else
    echo "Removidos os containers e a rede. Os dados continuam em $data_dir."
  fi
  echo "Preservados: $env_file, os segredos em $secrets_dir e as imagens. Para subir de novo: ./deploy.sh"
  exit 0
fi

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

if [[ "$check_only" == true ]]; then
  if [[ -n "$size" ]]; then
    docker compose --env-file "$env_file" --env-file "$profile_file" config --quiet
  else
    compose config --quiet
  fi
  echo "OK: perfil '${size:-$(env_valor FTP_PROFILE small)}', rede privada e compose validados; nada foi alterado."
  exit 0
fi

# Perfil: as chaves de profiles/<perfil>.env vão para o .env, para o `docker compose up -d` direto
# manter os mesmos limites. Sem --size, o .env fica como está.
if [[ -n "$size" ]]; then
  while IFS= read -r linha; do
    [[ "$linha" =~ ^([A-Z_][A-Z0-9_]*)=(.*)$ ]] || continue
    env_gravar "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  done < "$profile_file"
  env_gravar FTP_PROFILE "$size"
fi

# Portas: nenhuma pode estar em uso por outro programa. As que os containers desta stack já publicam não contam.
if command -v ss >/dev/null 2>&1; then
  declare -A escuta=() propria=()
  while IFS= read -r alvo; do
    [[ -n "$alvo" ]] && escuta["${alvo/#\*:/0.0.0.0:}"]=1
  done < <(ss -Hltn 2>/dev/null | awk '{print $4}')
  for servico in ftp painel; do
    id="$(compose ps -q "$servico" 2>/dev/null || true)"
    [[ -n "$id" ]] || continue
    while IFS= read -r alvo; do
      [[ -n "$alvo" ]] && propria["$alvo"]=1
    done < <(docker port "$id" 2>/dev/null | sed -n 's/.*-> //p')
  done
  ocupadas=()
  porta_em_uso() { # <ip> <porta>
    [[ -z "${propria[$1:$2]:-}" ]] && [[ -n "${escuta[$1:$2]:-}${escuta[0.0.0.0:$2]:-}" ]]
  }
  ftp_ip="$(env_valor FTP_BIND_IP 127.0.0.1)"
  painel_ip="$(env_valor PAINEL_BIND_IP 127.0.0.1)"
  porta_em_uso "$ftp_ip" "$(env_valor FTP_PORT 21)" && ocupadas+=("$ftp_ip:$(env_valor FTP_PORT 21)")
  porta_em_uso "$painel_ip" "$(env_valor PAINEL_PORT 8443)" && ocupadas+=("$painel_ip:$(env_valor PAINEL_PORT 8443)")
  for ((porta = $(env_valor FTP_PASSIVE_PORT_START 30000); porta <= $(env_valor FTP_PASSIVE_PORT_END 30049); porta++)); do
    porta_em_uso "$ftp_ip" "$porta" && ocupadas+=("$ftp_ip:$porta")
  done
  if [[ ${#ocupadas[@]} -gt 0 ]]; then
    die "porta já em uso por outro programa: ${ocupadas[*]:0:8}. Veja quem usa com 'ss -ltnp' e troque FTP_PORT, PAINEL_PORT ou a faixa passiva em $env_file."
  fi
fi

# Pastas dos dados (bind mount). O container ajusta dono e modo de cada uma ao subir.
mkdir -p "$data_dir/dados" "$data_dir/auth" "$data_dir/certs" "$data_dir/painel" \
  || die "não foi possível criar as pastas em $data_dir; ajuste DATA_DIR em $env_file."

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
if [[ "$atualizar" == true ]]; then
  # A base é fixada por digest no Dockerfile; sem cache, os pacotes do Debian são baixados de novo.
  compose build --no-cache
else
  compose build
fi

# Senha do painel: gerada forte na primeira execução. O container recebe só o hash scrypt;
# a senha em texto fica em painel_password.txt, só no host, até ser trocada por scripts/painel-senha.sh.
painel_hash="$secrets_dir/painel_password_hash.txt"
painel_senha="$secrets_dir/painel_password.txt"
if [[ ! -s "$painel_hash" ]]; then
  if [[ ! -s "$painel_senha" ]]; then
    command -v openssl >/dev/null 2>&1 || die "openssl não encontrado no host (necessário para gerar a senha)"
    openssl rand -base64 36 > "$painel_senha"
    echo "Gerada uma senha forte para o painel em $painel_senha (0600)."
  fi
  chmod 0600 "$painel_senha"
  ENV_FILE="$env_file" scripts/painel-senha.sh --inicial < "$painel_senha"
fi
chmod 0600 "$painel_hash"

# Sobe e espera os dois containers ficarem healthy; só então informa onde acessar.
if ! compose up -d --wait --wait-timeout 180; then
  compose ps || true
  die "os containers não ficaram healthy. Veja o motivo com: docker compose logs --tail 50 ftp painel"
fi
compose ps

ftp_ip="$(env_valor FTP_BIND_IP 127.0.0.1)"
echo
echo "Pronto: FTP e painel no ar (healthy), perfil '$(env_valor FTP_PROFILE small)'."
echo "FTP:    $ftp_ip:$(env_valor FTP_PORT 21) com TLS explícito, modo passivo $(env_valor FTP_PASSIVE_PORT_START 30000)-$(env_valor FTP_PASSIVE_PORT_END 30049)"
echo "        usuário '$(env_valor FTP_USER transfer)', senha no arquivo $secret_file"
echo "Painel: https://$(env_valor PAINEL_BIND_IP 127.0.0.1):$(env_valor PAINEL_PORT 8443)  (certificado autoassinado; só rede privada, atrás de firewall)"
if [[ -s "$painel_senha" ]]; then
  echo "        senha inicial no arquivo $painel_senha; troque com ./scripts/painel-senha.sh"
else
  echo "        senha: a que foi definida com ./scripts/painel-senha.sh"
fi
echo "Remover: ./deploy.sh --remover  (os dados ficam em $data_dir)"
