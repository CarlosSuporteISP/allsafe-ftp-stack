#!/usr/bin/env bash
set -Eeuo pipefail

usage() { echo "Uso: $0 add|passwd|del|list [usuario] [pasta]" >&2; exit 2; }
action="${1:-}"
user="${2:-}"
pasta="${3:-$user}"
passwd_file=/auth/pureftpd.passwd
# Pasta do usuário, dentro de /data: até 4 níveis. Nenhum nível começa com ponto, então "." e ".." não passam.
regra_pasta='^[A-Za-z0-9_][A-Za-z0-9._-]{0,63}(/[A-Za-z0-9_][A-Za-z0-9._-]{0,63}){0,3}$'
[[ $# -le 2 || "$action" == add ]] || usage

# O serviço ftp e o painel alteram os mesmos arquivos: uma alteração por vez.
travar() {
  exec 9>/auth/.lock
  flock -w 30 9 || { echo "Outra alteracao de usuario em andamento; tente de novo" >&2; exit 1; }
}

# Pasta gravada no cadastro para o usuário (campo 6, na forma /data/<pasta>/./).
pasta_de() {
  local nome casa _
  while IFS=: read -r nome _ _ _ _ casa _; do
    [[ "$nome" == "$1" ]] || continue
    casa="${casa%/./}"
    printf '%s\n' "${casa%/}"
    return 0
  done < "$passwd_file"
  return 1
}

# Cria a pasta nível por nível. O que já existe tem de ser pasta de verdade: link simbólico e arquivo
# no caminho são recusados, para a pasta do usuário nunca cair fora de /data.
preparar_pasta() {
  local nivel atual=/data
  local -a niveis
  IFS=/ read -r -a niveis <<< "$1"
  for nivel in "${niveis[@]}"; do
    atual+="/$nivel"
    if [[ -L "$atual" ]]; then
      echo "Pasta recusada: $atual e link simbolico" >&2; exit 1
    elif [[ -d "$atual" ]]; then
      continue
    elif [[ -e "$atual" ]]; then
      echo "Pasta recusada: $atual existe e nao e pasta" >&2; exit 1
    fi
    install -d -o ftpdata -g ftpdata -m 0750 "$atual"
  done
  chown ftpdata:ftpdata "$atual"
  chmod 0750 "$atual"
}

# Quem mais alcança a pasta: usuário com a mesma, com uma acima ou com uma abaixo dela.
avisar_divisao() {
  local nome casa _
  while IFS=: read -r nome _ _ _ _ casa _; do
    casa="${casa%/./}"; casa="${casa%/}"
    [[ "$nome" != "$user" && "$casa" == /data/* ]] || continue
    casa="${casa#/data/}"
    if [[ "$casa" == "$pasta" || "$casa" == "$pasta"/* || "$pasta" == "$casa"/* ]]; then
      echo "Aviso: /data/$pasta e dividida com o usuario $nome (/data/$casa): um alcanca os arquivos do outro."
    fi
  done < "$passwd_file"
}

case "$action" in
  list)
    # O `pure-pw list` não aceita `-f` logo depois da ação: o arquivo vai pela variável.
    PURE_PASSWDFILE="$passwd_file" pure-pw list
    ;;
  add|passwd)
    [[ "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || usage
    if [[ "$action" == add && ! "$pasta" =~ $regra_pasta ]]; then
      echo "Pasta invalida: ate 4 niveis separados por /; letras, numeros, _ - e ponto; nenhum nivel comeca com ponto" >&2
      exit 1
    fi
    IFS= read -r password
    [[ ${#password} -ge 12 ]] || { echo "Senha deve ter pelo menos 12 caracteres" >&2; exit 1; }
    travar
    if [[ "$action" == add ]]; then
      if [[ -f "$passwd_file" ]] && pasta_de "$user" > /dev/null; then
        echo "Usuario ja existe: $user" >&2; exit 1
      fi
      preparar_pasta "$pasta"
      printf '%s\n%s\n' "$password" "$password" | pure-pw useradd "$user" \
        -f "$passwd_file" -u ftpdata -g ftpdata -d "/data/$pasta"
      avisar_divisao
    else
      printf '%s\n%s\n' "$password" "$password" | pure-pw passwd "$user" -f "$passwd_file"
    fi
    pure-pw mkdb /auth/pureftpd.pdb -f "$passwd_file"
    chmod 0600 "$passwd_file" /auth/pureftpd.pdb
    ;;
  del)
    [[ "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || usage
    travar
    casa="$(pasta_de "$user" || true)"
    pure-pw userdel "$user" -f "$passwd_file"
    pure-pw mkdb /auth/pureftpd.pdb -f "$passwd_file"
    chmod 0600 "$passwd_file" /auth/pureftpd.pdb
    echo "Usuario removido; os dados em ${casa:-/data/$user} foram preservados."
    ;;
  *) usage ;;
esac
