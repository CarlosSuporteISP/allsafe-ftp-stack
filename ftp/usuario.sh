#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -Eeuo pipefail

usage() {
  echo "Uso: $0 add|passwd|pasta|del|list|tls-dispensar|tls-exigir|tls-lista [usuario] [pasta]" >&2
  echo "     $0 limites <usuario> [sessoes=N] [download=KB] [envio=KB] [horario=HHMM-HHMM] [baixar=N]" >&2
  exit 2
}
action="${1:-}"
user="${2:-}"
pasta="${3:-$user}"
passwd_file=/auth/pureftpd.passwd
# Quem entra sem TLS quando FTP_TLS_EXCECOES=sim: um nome por linha. Quem lê é o porteiro do FTP.
lista_tls=/auth/sem-tls.lista
# Limites por usuário que não são do cadastro do Pure-FTPd: uma linha por usuário, `nome chave=valor ...`.
# Quem lê e aplica é o painel.
lista_limites=/auth/limites.lista
# Pasta do usuário, dentro de /data: até 4 níveis. Nenhum nível começa com ponto, então "." e ".." não passam.
regra_pasta='^[A-Za-z0-9_][A-Za-z0-9._-]{0,63}(/[A-Za-z0-9_][A-Za-z0-9._-]{0,63}){0,3}$'
# Custo do hash da senha: o mesmo do entrypoint do serviço ftp (`pure-pw -C`, logins ao mesmo tempo).
logins="${FTP_MAX_CLIENTS:-50}"
# Senha do usuário inicial trocada por aqui: a partida do serviço ftp mantém esta senha enquanto o arquivo do
# segredo não mudar. O arquivo guarda só o nome do usuário.
inicial="${FTP_USER:-transfer}"
marca_inicial=/auth/senha-inicial.trocada
[[ $# -le 2 || "$action" == add || "$action" == pasta || "$action" == limites ]] || usage
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

# Grava um limite do painel para o usuário; valor vazio tira o limite e chave vazia tira o usuário da lista.
# Vai para um arquivo ao lado e troca de nome, para o painel nunca ler a lista pela metade.
gravar_limite() {
  local chave="$1" valor="${2:-}" nome resto par dele=""
  local novo="$lista_limites.novo"
  local -a pares=() antes=()
  : > "$novo"
  chmod 0600 "$novo"
  if [[ -f "$lista_limites" ]]; then
    while read -r nome resto; do
      [[ "$nome" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || continue
      if [[ "$nome" == "$user" ]]; then
        dele="$resto"
      elif pasta_de "$nome" > /dev/null; then  # conta que saiu do cadastro sai da lista
        printf '%s %s\n' "$nome" "$resto" >> "$novo"
      fi
    done < "$lista_limites"
  fi
  if [[ -n "$chave" ]]; then
    read -r -a antes <<< "$dele"
    for par in "${antes[@]}"; do
      if [[ "$par" =~ ^[a-z]{1,16}=[0-9]{1,6}$ && "${par%%=*}" != "$chave" ]]; then pares+=("$par"); fi
    done
    [[ -z "$valor" ]] || pares+=("$chave=$valor")
    (( ${#pares[@]} == 0 )) || printf '%s %s\n' "$user" "${pares[*]}" >> "$novo"
  fi
  mv -f "$novo" "$lista_limites"
}

# Limites do usuário, uma chave por linha; valor vazio quer dizer sem limite próprio: vale o da stack.
# O cadastro guarda as taxas em bytes por segundo e o horário sem os zeros da esquerda (0800-1800 vira 800-1800).
mostrar_limites() {
  local nome envio download sessoes horario resto par baixar="" _
  local -a pares=()
  while IFS=: read -r nome _ _ _ _ _ envio download _ _ sessoes _ _ _ _ _ _ horario _; do
    [[ "$nome" == "$user" ]] || continue
    if [[ -f "$lista_limites" ]]; then
      while read -r nome resto; do
        [[ "$nome" == "$user" ]] || continue
        read -r -a pares <<< "$resto"
        for par in "${pares[@]}"; do
          if [[ "$par" =~ ^baixar=[0-9]{1,6}$ ]]; then baixar="${par#baixar=}"; fi
        done
      done < "$lista_limites"
    fi
    [[ "$envio" =~ ^[1-9][0-9]*$ ]] && envio=$(( envio / 1024 )) || envio=""
    [[ "$download" =~ ^[1-9][0-9]*$ ]] && download=$(( download / 1024 )) || download=""
    [[ "$sessoes" =~ ^[1-9][0-9]*$ ]] || sessoes=""
    if [[ "$horario" =~ ^([0-9]{1,4})-([0-9]{1,4})$ ]]; then
      printf -v horario '%04d-%04d' "$(( 10#${BASH_REMATCH[1]} ))" "$(( 10#${BASH_REMATCH[2]} ))"
    else
      horario=""
    fi
    printf 'sessoes=%s\ndownload=%s\nenvio=%s\nhorario=%s\nbaixar=%s\n' "$sessoes" "$download" "$envio" "$horario" "$baixar"
    return 0
  done < "$passwd_file"
  return 1
}

# Número de um limite: vazio (tira o limite) ou inteiro de 1 até o teto.
numero() {
  [[ -z "$2" ]] && return 0
  if [[ ! "$2" =~ ^[1-9][0-9]{0,8}$ ]] || (( $2 > $3 )); then
    echo "Limite invalido: $1 aceita vazio ou um inteiro de 1 a $3" >&2; exit 1
  fi
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
    # Um usuário novo com o mesmo nome não herda a dispensa do TLS nem os limites.
    [[ ! -f "$lista_tls" ]] || gravar_lista_tls exigir
    [[ ! -f "$lista_limites" ]] || gravar_limite ""
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
  limites)
    # Sem pares, mostra os limites do usuário. Com pares, grava só os que vieram; valor vazio tira o limite.
    # sessoes, download, envio e horario ficam no cadastro do Pure-FTPd, que é quem os aplica;
    # baixar (downloads ao mesmo tempo pelo painel) fica na lista que o painel lê.
    [[ "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || usage
    shift 2
    declare -a opcoes=()
    baixar="" tem_baixar=nao
    for par in "$@"; do
      [[ "$par" == *=* ]] || usage
      chave="${par%%=*}" valor="${par#*=}"
      case "$chave" in
        sessoes)  numero sessoes "$valor" 99999; opcoes+=(-y "$valor") ;;
        download) numero download "$valor" 10000000; opcoes+=(-t "$valor") ;;
        envio)    numero envio "$valor" 10000000; opcoes+=(-T "$valor") ;;
        horario)
          if [[ -n "$valor" ]] && { [[ ! "$valor" =~ ^([01][0-9]|2[0-3])[0-5][0-9]-([01][0-9]|2[0-3])[0-5][0-9]$ ]] || [[ "${valor%-*}" == "${valor#*-}" ]]; }; then
            echo "Limite invalido: horario aceita vazio ou HHMM-HHMM, com inicio diferente do fim" >&2; exit 1
          fi
          opcoes+=(-z "$valor") ;;
        baixar)   numero baixar "$valor" 8; baixar="$valor" tem_baixar=sim ;;
        *) usage ;;
      esac
    done
    [[ -f "$passwd_file" ]] && pasta_de "$user" > /dev/null || { echo "Usuario nao existe: $user" >&2; exit 1; }
    if [[ $# -eq 0 ]]; then
      mostrar_limites
      exit 0
    fi
    travar
    pasta_de "$user" > /dev/null || { echo "Usuario nao existe: $user" >&2; exit 1; }
    if (( ${#opcoes[@]} > 0 )); then
      pure-pw usermod "$user" -f "$passwd_file" "${opcoes[@]}"
      pure-pw mkdb /auth/pureftpd.pdb -f "$passwd_file"
      chmod 0600 "$passwd_file" /auth/pureftpd.pdb
    fi
    [[ "$tem_baixar" == nao ]] || gravar_limite baixar "$baixar"
    echo "Limites do usuario $user gravados: valem na proxima entrada no FTP."
    ;;
  tls-lista)
    [[ ! -f "$lista_tls" ]] || grep -E '^[a-z_][a-z0-9_-]{0,31}$' "$lista_tls" || true
    ;;
  *) usage ;;
esac
