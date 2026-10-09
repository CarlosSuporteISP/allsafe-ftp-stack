#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Recupera o acesso ao painel pelo host: define a senha de um administrador e cria o administrador se
# ele não existir. No dia a dia, nome e senha são trocados na aba Usuários do painel.
# A senha em texto não é guardada: o hash scrypt é calculado dentro da imagem do painel, sem rede
# (o host não precisa de Python), e gravado em DATA_DIR/painel/administradores pelo próprio painel.
set -Eeuo pipefail
root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"
# shellcheck source=scripts/ambiente.sh
source scripts/ambiente.sh

env_file="${ENV_FILE:-.env}"
gerar=false
inicial=false
usuario=""
usage() {
  cat <<'USO'
Uso: scripts/painel-senha.sh [--usuario NOME] [--gerar]
  sem opção        pergunta a senha nova duas vezes (mínimo de 12 caracteres)
  --usuario NOME   administrador a alterar ou criar; sem a opção, o de PAINEL_ADMIN_USER
  --gerar          cria uma senha forte e mostra uma única vez
A senha também pode vir pela entrada padrão: scripts/painel-senha.sh < arquivo
As sessões abertas no painel são encerradas.
USO
}
die() { echo "ERRO: $*" >&2; exit 1; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --gerar) gerar=true; shift ;;
    --usuario) [[ $# -ge 2 ]] || die "--usuario pede o nome do administrador"; usuario="$2"; shift 2 ;;
    --inicial) inicial=true; shift ;;  # uso do deploy.sh: grava só o hash da senha inicial, antes da primeira subida
    -h|--help) usage; exit 0 ;;
    *) echo "Opção inválida: $1" >&2; usage >&2; exit 64 ;;
  esac
done
[[ -f "$env_file" ]] || die "$env_file não existe: rode ./deploy.sh primeiro"

secrets_dir="$(env_valor SECRETS_DIR ./.secrets)"
data_dir="$(env_valor DATA_DIR)"
imagem="$(env_valor PAINEL_IMAGE allsafe-ftp-painel:local)"
admin_inicial="$(env_valor PAINEL_ADMIN_USER admin)"
nome="${usuario:-$admin_inicial}"
hash_file="$secrets_dir/painel-admin-inicial-senha-hash.txt"
[[ "$nome" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] \
  || die "nome de administrador inválido: letras minúsculas, números, _ e -; começa com letra ou _; até 32 caracteres"
[[ "$inicial" == false || -z "$usuario" ]] || die "--inicial não combina com --usuario"
docker image inspect "$imagem" >/dev/null 2>&1 || die "imagem $imagem não encontrada: rode ./deploy.sh primeiro"
if [[ "$inicial" == false ]]; then
  [[ -s "$hash_file" && -d "$data_dir/painel" ]] || die "instalação incompleta: rode ./deploy.sh primeiro"
fi

if [[ "$gerar" == true ]]; then
  command -v openssl >/dev/null 2>&1 || die "openssl não encontrado no host (necessário para gerar a senha)"
  senha="$(openssl rand -base64 36)"
elif [[ -t 0 ]]; then
  read -r -s -p "Senha nova do administrador $nome: " senha; echo
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

# Hash da senha inicial: só o do primeiro administrador. O painel o usa enquanto não existe nenhum.
gravar_hash_inicial() {
  umask 077
  mkdir -p "$secrets_dir"
  chmod 0700 "$secrets_dir"
  # Gravado no mesmo arquivo (sem trocar o inode): o container enxerga o conteúdo novo ao reiniciar.
  printf '%s\n' "$hash" > "$hash_file"
  chmod 0600 "$hash_file"
}

if [[ "$inicial" == true ]]; then
  gravar_hash_inicial
  unset hash senha
  exit 0
fi

# O arquivo de administradores é do painel: quem grava é ele, no container que está no ar ou, com o
# painel parado, em um container de uso único, sem rede e sem os outros serviços.
no_ar=false
[[ -z "$(docker compose --env-file "$env_file" ps -q --status running painel 2>/dev/null)" ]] || no_ar=true
if [[ "$no_ar" == true ]]; then
  resultado="$(printf '%s\n' "$hash" | docker compose --env-file "$env_file" exec -T painel \
    python3 /opt/painel/servidor.py --administrador "$nome" | tail -n 1)" || die "o painel não gravou o administrador $nome"
else
  resultado="$(printf '%s\n' "$hash" | docker compose --env-file "$env_file" run --rm --no-deps -T \
    --entrypoint python3 painel /opt/painel/servidor.py --administrador "$nome" | tail -n 1)" \
    || die "o painel não gravou o administrador $nome"
fi
[[ "$resultado" == "administrador $nome: "* ]] || die "o painel não confirmou a gravação do administrador $nome"

if [[ "$nome" == "$admin_inicial" ]]; then
  gravar_hash_inicial
  # A senha inicial em texto deixou de valer: o arquivo é removido para não confundir.
  rm -f "$secrets_dir/painel-admin-inicial-senha.txt"
fi
unset hash

if [[ "$gerar" == true ]]; then
  echo "Senha nova do administrador $nome (mostrada só agora; guarde no seu cofre de senhas):"
  printf '%s\n' "$senha"
fi
unset senha

case "$resultado" in
  *criado) feito="criado" ;;
  *) feito="com a senha trocada" ;;
esac
if [[ "$no_ar" == true ]]; then
  docker compose --env-file "$env_file" restart painel >/dev/null
  echo "Administrador $nome $feito; painel reiniciado e sessões abertas encerradas."
else
  echo "Administrador $nome $feito; vale na próxima subida do painel."
fi
