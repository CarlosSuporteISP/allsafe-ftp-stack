#!/usr/bin/env bash
# Restaura uma cópia feita pelo scripts/backup.sh: para a stack, guarda antes uma cópia do estado
# atual, troca o conteúdo de dados/, auth/, certs/ e painel/ em DATA_DIR pelo da cópia e sobe de novo.
# O .env e os segredos de SECRETS_DIR não estão na cópia: continuam os desta pasta.
set -Eeuo pipefail
root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"
# shellcheck source=scripts/ambiente.sh
source scripts/ambiente.sh

env_file="${ENV_FILE:-.env}"
sim=false
copia=""
usage() {
  cat <<'USO'
Uso: scripts/restaurar.sh <cópia> [--sim]
     scripts/restaurar.sh --listar
  <cópia>    arquivo .tar.gz feito pelo scripts/backup.sh: o caminho ou só o nome, procurado em BACKUP_DIR
  --sim      não pede confirmação (uso em automação)
  --listar   mostra as cópias que existem em BACKUP_DIR
O conteúdo atual de dados/, auth/, certs/ e painel/ é substituído pelo da cópia. Antes, o estado
atual é guardado em BACKUP_DIR, em um arquivo com "antes-da-restauracao" no nome.
USO
}
die() { echo "ERRO: $*" >&2; exit 1; }
uso_invalido() { echo "$*" >&2; usage >&2; exit 64; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --sim) sim=true; shift ;;
    --listar) ENV_FILE="$env_file" exec scripts/backup.sh --listar ;;
    -h|--help) usage; exit 0 ;;
    -*) uso_invalido "Opção inválida: $1" ;;
    *) [[ -z "$copia" ]] || uso_invalido "Informe uma cópia só."
       copia="$1"; shift ;;
  esac
done
[[ -n "$copia" ]] || uso_invalido "Informe a cópia a restaurar (veja as que existem com --listar)."
[[ -f "$env_file" ]] || die "$env_file não existe: rode ./deploy.sh primeiro"

data_dir="$(env_valor DATA_DIR)"
backup_dir="$(env_valor BACKUP_DIR)"
secrets_dir="$(env_valor SECRETS_DIR ./.secrets)"
imagem="$(env_valor FTP_IMAGE allsafe-ftp:local)"
[[ "$data_dir" == /* ]] || die "DATA_DIR tem de ser um caminho absoluto em $env_file (veja o .env.example)"
data_dir="${data_dir%/}"; backup_dir="${backup_dir%/}"
[[ "$data_dir" =~ ^/[^/]+/[^/]+ ]] || die "DATA_DIR=$data_dir é raso demais para restaurar por aqui."
[[ -d "$data_dir" ]] || die "$data_dir não existe: rode ./deploy.sh primeiro, depois restaure."
for programa in docker tar sha256sum; do
  command -v "$programa" >/dev/null 2>&1 || die "$programa não encontrado no host."
done
docker image inspect "$imagem" >/dev/null 2>&1 || die "imagem $imagem não encontrada: rode ./deploy.sh primeiro"

arquivo="$copia"
[[ "$copia" == */* || -f "$copia" ]] || arquivo="$backup_dir/$copia"
[[ -f "$arquivo" && -r "$arquivo" ]] || die "cópia não encontrada: $arquivo (veja as que existem com --listar)"
arquivo="$(cd -- "$(dirname -- "$arquivo")" && pwd)/$(basename -- "$arquivo")"

# A cópia é conferida antes de qualquer alteração: soma, formato e o que há dentro.
if [[ -f "$arquivo.sha256" ]]; then
  ( cd "$(dirname -- "$arquivo")" && sha256sum --status -c "$(basename -- "$arquivo").sha256" ) \
    || die "a soma sha256 de $arquivo não confere: a cópia está corrompida ou foi alterada. Nada foi tocado."
  soma_texto="soma sha256 conferida"
else
  soma_texto="sem arquivo .sha256 ao lado: soma não conferida"
fi
lista="$(tar -tzf "$arquivo" 2>/dev/null)" || die "$arquivo não é um arquivo .tar.gz legível. Nada foi tocado."
if grep -q -v -E '^(dados|auth|certs|painel)(/|$)' <<< "$lista" || grep -q -E '(^|/)\.\.(/|$)' <<< "$lista"; then
  die "$arquivo tem itens fora de dados/, auth/, certs/ e painel/: não é uma cópia desta stack. Nada foi tocado."
fi
grep -q -x -F 'auth/pureftpd.passwd' <<< "$lista" \
  || die "$arquivo não tem a lista de usuários (auth/pureftpd.passwd): não é uma cópia desta stack. Nada foi tocado."

echo "Cópia: $arquivo ($(du -h -- "$arquivo" | cut -f1), $(wc -l <<< "$lista") itens, $soma_texto)"
if [[ "$sim" == false ]]; then
  [[ -t 0 ]] || die "restauração sem terminal exige --sim."
  echo "O conteúdo atual de dados/, auth/, certs/ e painel/ em $data_dir será substituído pelo da cópia."
  echo "A stack para durante a restauração; o estado atual é guardado antes em $backup_dir."
  read -r -p "Digite 'restaurar' para confirmar: " resposta
  [[ "$resposta" == restaurar ]] || die "confirmação não recebida; nada foi alterado."
fi

compose() { docker compose --env-file "$env_file" "$@"; }
no_ar="$(compose ps -q 2>/dev/null || true)"
subir() {
  [[ -n "$no_ar" ]] || return 0
  compose up -d --wait --wait-timeout 300 \
    || die "os containers não ficaram healthy depois da restauração. Veja: docker compose logs --tail 50 ftp painel nginx"
}
if [[ -n "$no_ar" ]]; then
  echo "Parando a stack..."
  compose stop
fi

# Estado atual guardado antes de qualquer troca. Sem instalação anterior (auth/ ausente), não há o que guardar.
anterior=""
if [[ -d "$data_dir/auth" ]]; then
  if ! saida="$(ENV_FILE="$env_file" scripts/backup.sh --rotulo antes-da-restauracao)"; then
    echo "ERRO: não foi possível guardar o estado atual; nada foi alterado." >&2
    subir
    exit 1
  fi
  anterior="$(sed -n 's/^Cópia gravada: \(.*\.tar\.gz\) (.*/\1/p' <<< "$saida")"
  echo "Estado atual guardado em: $anterior"
fi

# Quem apaga e grava é um container sem rede, só com DATA_DIR: os arquivos são do root e do ftpdata,
# e voltam com o dono e o modo que tinham na cópia.
docker run --rm -i --network none --read-only --cap-drop ALL \
  --cap-add CHOWN --cap-add DAC_OVERRIDE --cap-add FOWNER --security-opt no-new-privileges:true \
  -v "$data_dir":/alvo --entrypoint bash "$imagem" -c '
    set -e
    for pasta in dados auth certs painel; do
      if [[ -d "/alvo/$pasta" ]]; then find "/alvo/$pasta" -mindepth 1 -delete; fi
    done
    tar -C /alvo --numeric-owner -xzpf -
    mkdir -p /alvo/dados /alvo/auth /alvo/certs /alvo/painel' < "$arquivo" \
  || die "a restauração falhou no meio: $data_dir pode estar incompleta. Restaure de novo${anterior:+ (o estado anterior está em $anterior)}; a stack continua parada."

if [[ -n "$no_ar" ]]; then
  echo "Subindo a stack..."
  subir
  compose ps
  echo "Restaurado e no ar (healthy)."
else
  echo "Restaurado. A stack estava parada e continua parada: suba com ./deploy.sh"
fi
echo "Usuários, arquivos, certificados e auditoria voltaram ao estado da cópia."
echo "As senhas do usuário inicial e do painel continuam as de $secrets_dir, que não fazem parte da cópia."
[[ -z "$anterior" ]] || echo "Desfazer: ./scripts/restaurar.sh $(basename -- "$anterior")"
