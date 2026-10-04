#!/usr/bin/env bash
# Troca a senha do painel. Grava só o hash scrypt em SECRETS_DIR/painel-admin-inicial-senha-hash.txt;
# a senha em texto não é guardada. O hash é calculado dentro da imagem do painel, sem rede,
# para o host não precisar de Python.
set -Eeuo pipefail
root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"
# shellcheck source=scripts/ambiente.sh
source scripts/ambiente.sh

env_file="${ENV_FILE:-.env}"
gerar=false
inicial=false
usage() {
  cat <<'USO'
Uso: scripts/painel-senha.sh [--gerar]
  sem opção   pergunta a senha nova duas vezes (mínimo de 12 caracteres)
  --gerar     cria uma senha forte e mostra uma única vez
A senha também pode vir pela entrada padrão: scripts/painel-senha.sh < arquivo
USO
}
die() { echo "ERRO: $*" >&2; exit 1; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --gerar) gerar=true; shift ;;
    --inicial) inicial=true; shift ;;  # uso do deploy.sh: não reinicia e mantém a senha inicial em texto
    -h|--help) usage; exit 0 ;;
    *) echo "Opção inválida: $1" >&2; usage >&2; exit 64 ;;
  esac
done
[[ -f "$env_file" ]] || die "$env_file não existe: rode ./deploy.sh primeiro"

secrets_dir="$(env_valor SECRETS_DIR ./.secrets)"
imagem="$(env_valor PAINEL_IMAGE allsafe-ftp-painel:local)"
hash_file="$secrets_dir/painel-admin-inicial-senha-hash.txt"
docker image inspect "$imagem" >/dev/null 2>&1 || die "imagem $imagem não encontrada: rode ./deploy.sh primeiro"

if [[ "$gerar" == true ]]; then
  command -v openssl >/dev/null 2>&1 || die "openssl não encontrado no host (necessário para gerar a senha)"
  senha="$(openssl rand -base64 36)"
elif [[ -t 0 ]]; then
  read -r -s -p "Senha nova do painel: " senha; echo
  read -r -s -p "Repita a senha: " repetida; echo
  [[ "$senha" == "$repetida" ]] || die "as duas senhas não são iguais"
  unset repetida
else
  IFS= read -r senha || [[ -n "$senha" ]] || die "nenhuma senha na entrada padrão"
fi
[[ ${#senha} -ge 12 ]] || die "a senha do painel deve ter pelo menos 12 caracteres"

hash="$(printf '%s\n' "$senha" | docker run --rm -i --network none --read-only --cap-drop ALL \
  --entrypoint python3 "$imagem" /opt/painel/servidor.py --hash)"
[[ "$hash" == 'scrypt$'* ]] || die "a imagem $imagem não devolveu um hash"

umask 077
mkdir -p "$secrets_dir"
chmod 0700 "$secrets_dir"
# Gravado no mesmo arquivo (sem trocar o inode): o container enxerga o conteúdo novo ao reiniciar.
printf '%s\n' "$hash" > "$hash_file"
chmod 0600 "$hash_file"
unset hash

if [[ "$gerar" == true ]]; then
  echo "Senha nova do painel (mostrada só agora; guarde no seu cofre de senhas):"
  printf '%s\n' "$senha"
fi
unset senha

if [[ "$inicial" == false ]]; then
  # A senha inicial em texto deixou de valer: o arquivo é removido para não confundir.
  rm -f "$secrets_dir/painel-admin-inicial-senha.txt"
  if [[ -n "$(docker compose --env-file "$env_file" ps -q painel 2>/dev/null)" ]]; then
    docker compose --env-file "$env_file" restart painel >/dev/null
    echo "Hash gravado em $hash_file; painel reiniciado e sessões abertas encerradas."
  else
    echo "Hash gravado em $hash_file; vale na próxima subida do painel."
  fi
fi
