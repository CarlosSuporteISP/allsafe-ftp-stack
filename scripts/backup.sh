#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Cópia de segurança da stack: dados/, auth/, certs/ e painel/ de DATA_DIR viram um arquivo cifrado
# BACKUP_DIR/<STACK_NAME>-AAAAMMDD-HHMMSS.tar.gz.age (modo 0600), com a soma sha256 ao lado.
# A leitura e a cifra são feitas por um container sem rede, porque parte dos arquivos é do root.
# A cifra (age) usa a chave pública de SECRETS_DIR; só a chave privada abre a cópia.
# O .env e os segredos de SECRETS_DIR NÃO entram na cópia: guarde-os à parte (doc/backup.md).
set -Eeuo pipefail
root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"
# shellcheck source=scripts/ambiente.sh
source scripts/ambiente.sh

env_file="${ENV_FILE:-.env}"
listar=false
rotulo=""
usage() {
  cat <<'USO'
Uso: scripts/backup.sh [--rotulo <texto>]
     scripts/backup.sh --listar
  sem opção          grava uma cópia de dados/, auth/, certs/ e painel/ em BACKUP_DIR
  --rotulo <texto>   acrescenta o texto ao nome do arquivo (letras minúsculas, números e hífen)
  --listar           mostra as cópias que existem em BACKUP_DIR
A stack pode ficar no ar durante a cópia. O .env e os segredos não entram no arquivo.
A cópia sai cifrada com a chave pública de SECRETS_DIR; só a chave privada abre.
USO
}
die() { echo "ERRO: $*" >&2; exit 1; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --listar) listar=true; shift ;;
    --rotulo) [[ $# -ge 2 ]] || { echo "Informe o texto do rótulo." >&2; usage >&2; exit 64; }
              rotulo="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção inválida: $1" >&2; usage >&2; exit 64 ;;
  esac
done
[[ -z "$rotulo" || "$rotulo" =~ ^[a-z0-9][a-z0-9-]{0,39}$ ]] \
  || { echo "Rótulo inválido: use letras minúsculas, números e hífen (até 40)." >&2; exit 64; }
[[ -f "$env_file" ]] || die "$env_file não existe: rode ./deploy.sh primeiro"

data_dir="$(env_valor DATA_DIR)"
backup_dir="$(env_valor BACKUP_DIR)"
secrets_dir="$(env_valor SECRETS_DIR ./.secrets)"
nome="$(env_valor STACK_NAME allsafe-ftp-stack)"
imagem="$(env_valor FTP_IMAGE allsafe-ftp:local)"
[[ "$data_dir" == /* ]] || die "DATA_DIR tem de ser um caminho absoluto em $env_file (veja o .env.example)"
[[ "$backup_dir" == /* ]] || die "BACKUP_DIR tem de ser um caminho absoluto em $env_file (veja o .env.example)"
data_dir="${data_dir%/}"; backup_dir="${backup_dir%/}"
case "$backup_dir/" in
  "$data_dir"/*) die "BACKUP_DIR=$backup_dir fica dentro de DATA_DIR: a cópia tem de ir para outra pasta." ;;
esac

if [[ "$listar" == true ]]; then
  shopt -s nullglob
  copias=("$backup_dir/$nome"-*.tar.gz.age "$backup_dir/$nome"-*.tar.gz)
  if [[ ${#copias[@]} -eq 0 ]]; then
    echo "Nenhuma cópia em $backup_dir."
    exit 0
  fi
  echo "Cópias em $backup_dir:"
  for copia in "${copias[@]}"; do
    sem_cifra=""
    [[ "$copia" == *.age ]] || sem_cifra="  (sem cifra: feita antes da 0.25.0)"
    printf '  %6s  %s%s\n' "$(du -h -- "$copia" | cut -f1)" "$(basename -- "$copia")" "$sem_cifra"
  done
  exit 0
fi

for programa in docker sha256sum; do
  command -v "$programa" >/dev/null 2>&1 || die "$programa não encontrado no host."
done
docker image inspect "$imagem" >/dev/null 2>&1 || die "imagem $imagem não encontrada: rode ./deploy.sh primeiro"
# A chave pública não é segredo: com ela só se cifra. Vai ao container como argumento.
chave_publica="$secrets_dir/backup-chave-publica.txt"
[[ -s "$chave_publica" ]] || die "$chave_publica não existe: rode ./deploy.sh, que gera a chave da cópia de segurança."
destinatario=""
IFS= read -r destinatario < "$chave_publica" || true
[[ "$destinatario" =~ ^age1[0-9a-z]{58}$ ]] \
  || die "$chave_publica não tem uma chave pública age válida: rode ./deploy.sh, que a refaz a partir da chave privada."
pastas=()
for pasta in dados certs painel; do
  [[ -d "$data_dir/$pasta" ]] && pastas+=("$pasta")
done
[[ -d "$data_dir/auth" ]] || die "$data_dir/auth não existe: não há instalação para copiar. Rode ./deploy.sh primeiro."

( umask 077; mkdir -p -- "$backup_dir" ) || die "não foi possível criar $backup_dir"
arquivo="$backup_dir/$nome-$(date +%Y%m%d-%H%M%S)${rotulo:+-$rotulo}.tar.gz.age"
[[ ! -e "$arquivo" ]] || die "$arquivo já existe: aguarde um segundo e rode de novo."
parcial="$arquivo.parcial"
trap 'rm -f -- "$parcial"' EXIT
umask 077

# auth/ é copiada com a trava dos usuários (a mesma do painel e do manage-user.sh), solta em seguida:
# a lista de usuários entra inteira, e o resto da cópia não segura quem altera usuário.
# O container só lê: sem rede, raiz somente leitura, DATA_DIR montada somente leitura.
# O tar sai direto para o age: nada sem cifra chega ao disco. Saída 4 é falha da cifra.
codigo=0
docker run --rm --network none --read-only --cap-drop ALL --cap-add DAC_READ_SEARCH \
  --security-opt no-new-privileges:true --tmpfs /tmp:rw,noexec,nosuid,nodev,size=64m,mode=0700 \
  -v "$data_dir":/origem:ro --entrypoint bash "$imagem" -c '
    set -e
    if [[ -e /origem/auth/.lock ]]; then
      exec 9< /origem/auth/.lock
      flock -s -w 30 9 || { echo "arquivo de usuarios em uso por outra alteracao" >&2; exit 3; }
    fi
    cp -a /origem/auth /tmp/auth
    exec 9<&-
    destinatario="$1"; shift
    set +e
    tar --numeric-owner -czf - -C /tmp auth -C /origem "$@" | age -r "$destinatario"
    estado=("${PIPESTATUS[@]}")
    [[ "${estado[1]}" -eq 0 ]] || exit 4
    exit "${estado[0]}"' copia "$destinatario" "${pastas[@]}" > "$parcial" || codigo=$?
case "$codigo" in
  0) ;;
  1) echo "AVISO: algum arquivo mudou enquanto era lido (envio em andamento). A cópia foi gravada;" >&2
     echo "       para uma cópia exata, repita fora do horário dos backups dos equipamentos." >&2 ;;
  4) die "a cifra da cópia falhou; nada foi gravado em $backup_dir. Confira $chave_publica (o ./deploy.sh a refaz)." ;;
  *) die "a cópia falhou (código $codigo); nada foi gravado em $backup_dir." ;;
esac
[[ "$(head -c 21 -- "$parcial" | tr -d '\0')" == 'age-encryption.org/v1' ]] \
  || die "o arquivo gerado não é uma cópia cifrada; nada foi gravado em $backup_dir."
mv -- "$parcial" "$arquivo"
( cd "$backup_dir" && sha256sum -- "$(basename -- "$arquivo")" > "$(basename -- "$arquivo").sha256" )

echo "Cópia gravada: $arquivo ($(du -h -- "$arquivo" | cut -f1), cifrada)"
echo "Fora da cópia: $env_file e os segredos de $secrets_dir. Guarde-os à parte (doc/backup.md)."
echo "Só a chave privada abre a cópia (backup-chave-privada.txt, de $secrets_dir): guarde-a também fora deste servidor."
echo "Restaurar: ./scripts/restaurar.sh $(basename -- "$arquivo")"
