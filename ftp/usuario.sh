#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -Eeuo pipefail

usage() { echo "Uso: $0 add|passwd|pasta|del|list|tls-dispensar|tls-exigir|tls-lista [usuario] [pasta]" >&2; exit 2; }
action="${1:-}"
user="${2:-}"
pasta="${3:-$user}"
passwd_file=/auth/pureftpd.passwd
# Quem entra sem TLS quando FTP_TLS_EXCECOES=sim: um nome por linha. Quem lê é o porteiro do FTP.
lista_tls=/auth/sem-tls.lista
# Pasta do usuário, dentro de /data: até 4 níveis. Nenhum nível começa com ponto, então "." e ".." não passam.
regra_pasta='^[A-Za-z0-9_][A-Za-z0-9._-]{0,63}(/[A-Za-z0-9_][A-Za-z0-9._-]{0,63}){0,3}$'
# Custo do hash da senha: o mesmo do entrypoint do serviço ftp (`pure-pw -C`, logins ao mesmo tempo).
logins="${FTP_MAX_CLIENTS:-50}"
# Senha do usuário inicial trocada por aqui: a partida do serviço ftp mantém esta senha enquanto o arquivo do
# segredo não mudar. O arquivo guarda só o nome do usuário.
inicial="${FTP_USER:-transfer}"
marca_inicial=/auth/senha-inicial.trocada
[[ $# -le 2 || "$action" == add || "$action" == pasta ]] || usage
pasta_invalida() {
  echo "Pasta invalida: ate 4 niveis separados por /; letras, numeros, _ - e ponto; nenhum nivel comeca com ponto" >&2
  exit 1
}

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

# Grava a lista de quem entra sem TLS, com ou sem o usuário. Vai para um arquivo ao lado e troca de nome,
# para o porteiro nunca ler a lista pela metade.
gravar_lista_tls() {
  local modo="$1" nome
  local novo="$lista_tls.novo"
  : > "$novo"
  chmod 0600 "$novo"
  if [[ -f "$lista_tls" ]]; then
    while IFS= read -r nome; do
      [[ "$nome" =~ ^[a-z_][a-z0-9_-]{0,31}$ && "$nome" != "$user" ]] || continue
      pasta_de "$nome" > /dev/null || continue  # conta que saiu do cadastro sai da lista
      printf '%s\n' "$nome" >> "$novo"
    done < "$lista_tls"
  fi
  [[ "$modo" != dispensar ]] || printf '%s\n' "$user" >> "$novo"
  sort -u -o "$novo" "$novo"
  mv -f "$novo" "$lista_tls"
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
    [[ "$action" != add || "$pasta" =~ $regra_pasta ]] || pasta_invalida
    [[ "$logins" =~ ^[1-9][0-9]{0,4}$ ]] || { echo "FTP_MAX_CLIENTS deve ser um inteiro maior que zero" >&2; exit 1; }
    IFS= read -r password
    [[ ${#password} -ge 12 ]] || { echo "Senha deve ter pelo menos 12 caracteres" >&2; exit 1; }
    travar
    if [[ "$action" == add ]]; then
      if [[ -f "$passwd_file" ]] && pasta_de "$user" > /dev/null; then
        echo "Usuario ja existe: $user" >&2; exit 1
      fi
      preparar_pasta "$pasta"
      printf '%s\n%s\n' "$password" "$password" | pure-pw useradd "$user" \
        -f "$passwd_file" -u ftpdata -g ftpdata -d "/data/$pasta" -C "$logins"
      avisar_divisao
    else
      printf '%s\n%s\n' "$password" "$password" | pure-pw passwd "$user" -f "$passwd_file" -C "$logins"
      if [[ "$user" == "$inicial" ]]; then
        printf '%s\n' "$user" > "$marca_inicial.novo"
        chmod 0600 "$marca_inicial.novo"
        mv -f "$marca_inicial.novo" "$marca_inicial"
      fi
    fi
    pure-pw mkdb /auth/pureftpd.pdb -f "$passwd_file"
    chmod 0600 "$passwd_file" /auth/pureftpd.pdb
    ;;
  pasta)
    # Troca a pasta do usuário. Os arquivos da pasta anterior não são movidos nem apagados.
    [[ "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ && $# -eq 3 ]] || usage
    [[ "$pasta" =~ $regra_pasta ]] || pasta_invalida
    travar
    if ! { [[ -f "$passwd_file" ]] && anterior="$(pasta_de "$user")"; }; then
      echo "Usuario nao existe: $user" >&2; exit 1
    fi
    preparar_pasta "$pasta"
    pure-pw usermod "$user" -f "$passwd_file" -d "/data/$pasta"
    pure-pw mkdb /auth/pureftpd.pdb -f "$passwd_file"
    chmod 0600 "$passwd_file" /auth/pureftpd.pdb
    avisar_divisao
    echo "Pasta do usuario $user: /data/$pasta. Os arquivos de ${anterior:-/data/$user} continuam la."
    ;;
  del)
    [[ "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || usage
    travar
    casa="$(pasta_de "$user" || true)"
    pure-pw userdel "$user" -f "$passwd_file"
    pure-pw mkdb /auth/pureftpd.pdb -f "$passwd_file"
    chmod 0600 "$passwd_file" /auth/pureftpd.pdb
    # Um usuário novo com o mesmo nome não herda a dispensa do TLS.
    [[ ! -f "$lista_tls" ]] || gravar_lista_tls exigir
    echo "Usuario removido; os dados em ${casa:-/data/$user} foram preservados."
    ;;
  tls-dispensar|tls-exigir)
    [[ "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || usage
    travar
    if ! { [[ -f "$passwd_file" ]] && pasta_de "$user" > /dev/null; }; then
      echo "Usuario nao existe: $user" >&2; exit 1
    fi
    gravar_lista_tls "${action#tls-}"
    if [[ "$action" == tls-dispensar ]]; then
      echo "Usuario $user dispensado do TLS: vale na proxima entrada, com FTP_TLS_EXCECOES=sim."
    else
      echo "Usuario $user volta a ser obrigado a usar TLS: vale na proxima entrada."
    fi
    ;;
  tls-lista)
    [[ ! -f "$lista_tls" ]] || grep -E '^[a-z_][a-z0-9_-]{0,31}$' "$lista_tls" || true
    ;;
  *) usage ;;
esac
