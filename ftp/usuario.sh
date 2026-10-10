#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -Eeuo pipefail

usage() {
  echo "Uso: $0 add|passwd|pasta|del|list|tls-dispensar|tls-exigir|tls-lista [usuario] [pasta] [perfil]" >&2
  echo "     $0 perfil <usuario> [completo|envio|soenvio|leitura]" >&2
  echo "     $0 limites <usuario> [sessoes=N] [download=KB] [envio=KB] [horario=HHMM-HHMM] [baixar=N] [tentativas=N] [minutos=N]" >&2
  echo "     $0 bloqueios [usuario]" >&2
  echo "     $0 desbloquear <usuario> [origem]" >&2
  exit 2
}
action="${1:-}"
user="${2:-}"
pasta="${3:-$user}"
passwd_file=/auth/pureftpd.passwd
# Perfil do usuário: o que ele pode fazer na pasta. O Pure-FTPd não tem permissão por conta: o perfil é a
# identidade de sistema gravada no cadastro (campos 3 e 4), e quem aplica o limite é o sistema de arquivos.
#   completo  ftpdata:ftpdata        envia, baixa, renomeia e apaga;
#   envio     ftpenvio:ftpdata       envia e baixa; o vigia do FTP passa cada arquivo recebido para o ftpdata,
#                                    e daí em diante este perfil não o sobrescreve, não o renomeia e não o apaga;
#   soenvio   ftpsoenvio:ftpsoenvio  só envia: a sessão fica presa em /data/.entrada/<usuario>, fora da pasta
#                                    do usuário, e o vigia do FTP move cada arquivo recebido para a pasta, como
#                                    ftpdata. Este perfil não lista nem baixa o que está lá. No cadastro, a pasta
#                                    da sessão (campo 6) é a área de entrada e a do usuário vai na descrição (campo 5);
#   leitura   ftpleitura:ftpleitura  lista e baixa.
declare -A dono_do_perfil=([completo]=ftpdata [envio]=ftpenvio [soenvio]=ftpsoenvio [leitura]=ftpleitura)
declare -A grupo_do_perfil=([completo]=ftpdata [envio]=ftpdata [soenvio]=ftpsoenvio [leitura]=ftpleitura)
uid_envio=10002 uid_leitura=10003 uid_soenvio=10004
pasta_entrada=/data/.entrada
# Quem entra sem TLS com o TLS por usuário valendo: um nome por linha. Quem lê é o porteiro do FTP, a cada
# entrada, e a partida do serviço ftp, que só aceita sessão sem TLS enquanto houver nome aqui.
lista_tls=/auth/sem-tls.lista
# Limites por usuário que não são do cadastro do Pure-FTPd: uma linha por usuário, `nome chave=valor ...`.
# `baixar` é lido e aplicado pelo painel; `tentativas` e `minutos`, pelo vigia do FTP.
lista_limites=/auth/limites.lista
# Bloqueios por tentativa: um arquivo por usuário e endereço, `<usuario>@<origem>`, com `<vale até> <desde>
# <senhas erradas>`. Quem grava é o vigia do FTP e quem aplica é o porteiro; apagar o arquivo desbloqueia.
pasta_bloqueios=/auth/bloqueios
regra_origem='^[0-9a-fA-F.:]{2,45}$'
# Pasta do usuário, dentro de /data: até 4 níveis. Nenhum nível começa com ponto, então "." e ".." não passam.
regra_pasta='^[A-Za-z0-9_][A-Za-z0-9._-]{0,63}(/[A-Za-z0-9_][A-Za-z0-9._-]{0,63}){0,3}$'
# Custo do hash da senha: o mesmo do entrypoint do serviço ftp (`pure-pw -C`, logins ao mesmo tempo).
logins="${FTP_MAX_CLIENTS:-50}"
# Senha do usuário inicial trocada por aqui: a partida do serviço ftp mantém esta senha enquanto o arquivo do
# segredo não mudar. O arquivo guarda só o nome do usuário.
inicial="${FTP_USER:-transfer}"
marca_inicial=/auth/senha-inicial.trocada
# Usuário inicial já criado uma vez: com esta marca, a partida do serviço ftp não o recria depois de removido.
marca_criado=/auth/usuario-inicial.criado
gravar_marca() { # <arquivo>: grava o nome do usuário inicial, só para o root
  rm -f "$1.novo"
  ( umask 077; printf '%s\n' "$inicial" > "$1.novo" )
  mv -f "$1.novo" "$1"
}
[[ $# -le 2 || "$action" == add || "$action" == pasta || "$action" == perfil || "$action" == limites || "$action" == desbloquear ]] || usage
perfil_invalido() { echo "Perfil invalido: use completo, envio, soenvio ou leitura" >&2; exit 1; }
pasta_invalida() {
  echo "Pasta invalida: ate 4 niveis separados por /; letras, numeros, _ - e ponto; nenhum nivel comeca com ponto" >&2
  exit 1
}

# O serviço ftp e o painel alteram os mesmos arquivos: uma alteração por vez.
travar() {
  exec 9>/auth/.lock
  flock -w 30 9 || { echo "Outra alteracao de usuario em andamento; tente de novo" >&2; exit 1; }
}

# Pasta gravada no cadastro para o usuário (campo 6, na forma /data/<pasta>/./). No perfil só envio o campo 6 é
# a área de entrada, e a pasta do usuário é a da descrição (campo 5).
pasta_de() {
  local nome uid descricao casa _
  while IFS=: read -r nome _ uid _ descricao casa _; do
    [[ "$nome" == "$1" ]] || continue
    if [[ "$uid" == "$uid_soenvio" ]]; then
      [[ "$descricao" =~ $regra_pasta ]] || return 1
      casa="/data/$descricao"
    fi
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
}

# Perfil gravado no cadastro para o usuário.
perfil_de() {
  local nome uid _
  while IFS=: read -r nome _ uid _; do
    [[ "$nome" == "$1" ]] || continue
    case "$uid" in
      "$uid_envio") echo envio ;;
      "$uid_soenvio") echo soenvio ;;
      "$uid_leitura") echo leitura ;;
      *) echo completo ;;
    esac
    return 0
  done < "$passwd_file"
  return 1
}

# Dono e modo de cada pasta de usuário, pelo perfil de quem a alcança: quem tem a mesma pasta ou uma acima.
#   só completo  0750  o dono faz tudo e ninguém mais entra;
#   com envio    +g+w e o bit de permanência: o envio cria, e só o dono do arquivo o troca, renomeia ou apaga;
#   com leitura  +o+rx: a leitura fica fora do grupo e entra pelo "outros". O /data é 0700 do root, então
#                esse "outros" só existe para quem o Pure-FTPd já prendeu dentro da pasta.
# As pastas de dentro acompanham a do usuário quando o modo muda. Os argumentos são pastas que saíram do
# cadastro nesta alteração (a de quem foi removido, a anterior de quem trocou): voltam ao que o resto pede.
ajustar_pastas() {
  local nome uid descricao casa outra par modo atual _
  local -a pares=() casas=("$@")
  while IFS=: read -r nome _ uid _ descricao casa _; do
    if [[ "$uid" == "$uid_soenvio" ]]; then
      # Só envio não alcança a pasta: ela entra na conta, mas este perfil não muda o modo dela.
      [[ ! "$descricao" =~ $regra_pasta ]] || casas+=("/data/$descricao")
      continue
    fi
    casa="${casa%/./}"; casa="${casa%/}"
    [[ "$casa" == /data/* ]] || continue
    pares+=("$uid:$casa")
    casas+=("$casa")
  done < "$passwd_file"
  (( ${#casas[@]} > 0 )) || return 0
  # Em ordem, a pasta de cima vem antes da de dentro: a de dentro fica com o modo dela por último.
  while IFS= read -r casa; do
    [[ "$casa" == /data/* && -d "$casa" && ! -L "$casa" ]] || continue
    modo=0750
    for par in "${pares[@]}"; do
      uid="${par%%:*}" outra="${par#*:}"
      [[ "$casa" == "$outra" || "$casa" == "$outra"/* ]] || continue
      [[ "$uid" != "$uid_envio" ]] || modo=$(( modo | 01020 ))
      [[ "$uid" != "$uid_leitura" ]] || modo=$(( modo | 0005 ))
    done
    printf -v modo '%o' "$modo"
    atual="$(stat -c '%U:%G %a' "$casa")"
    [[ "$atual" != "ftpdata:ftpdata $modo" ]] || continue
    chown ftpdata:ftpdata "$casa"
    if [[ "${atual#* }" == "$modo" ]]; then continue; fi
    find "$casa" -xdev -type d -exec chmod "$modo" {} +
  done < <(printf '%s\n' "${casas[@]}" | sort -u)
}

# Regrava o banco que o Pure-FTPd consulta, a partir do cadastro.
gravar_banco() {
  pure-pw mkdb /auth/pureftpd.pdb -f "$passwd_file"
  chmod 0600 "$passwd_file" /auth/pureftpd.pdb
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
  local nome envio download sessoes horario resto par baixar="" tentativas="" minutos="" _
  local -a pares=()
  while IFS=: read -r nome _ _ _ _ _ envio download _ _ sessoes _ _ _ _ _ _ horario _; do
    [[ "$nome" == "$user" ]] || continue
    if [[ -f "$lista_limites" ]]; then
      while read -r nome resto; do
        [[ "$nome" == "$user" ]] || continue
        read -r -a pares <<< "$resto"
        for par in "${pares[@]}"; do
          case "$par" in
            baixar=*)     [[ ! "${par#*=}" =~ ^[0-9]{1,6}$ ]] || baixar="${par#*=}" ;;
            tentativas=*) [[ ! "${par#*=}" =~ ^[0-9]{1,6}$ ]] || tentativas="${par#*=}" ;;
            minutos=*)    [[ ! "${par#*=}" =~ ^[0-9]{1,6}$ ]] || minutos="${par#*=}" ;;
          esac
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
    printf 'sessoes=%s\ndownload=%s\nenvio=%s\nhorario=%s\nbaixar=%s\ntentativas=%s\nminutos=%s\n' \
      "$sessoes" "$download" "$envio" "$horario" "$baixar" "$tentativas" "$minutos"
    return 0
  done < "$passwd_file"
  return 1
}

# Número de um limite: vazio (tira o limite) ou inteiro do piso (1, se não vier) até o teto.
numero() { # <nome> <valor> <teto> [piso]
  local piso="${4:-1}"
  [[ -z "$2" ]] && return 0
  if [[ ! "$2" =~ ^(0|[1-9][0-9]{0,8})$ ]] || (( $2 < piso || $2 > $3 )); then
    echo "Limite invalido: $1 aceita vazio ou um inteiro de $piso a $3" >&2; exit 1
  fi
}

# Tira os bloqueios por tentativa do usuário: todos, ou só o de uma origem. Diz quantos saíram.
tirar_bloqueios() { # [origem]
  local arquivo quantos=0
  for arquivo in "$pasta_bloqueios/$user"@${1:-*}; do
    [[ -f "$arquivo" && ! -L "$arquivo" ]] || continue
    rm -f -- "$arquivo"
    quantos=$(( quantos + 1 ))
  done
  printf '%s\n' "$quantos"
}

# Quem mais alcança a pasta: usuário com a mesma, com uma acima ou com uma abaixo dela.
avisar_divisao() {
  local nome uid descricao casa _
  while IFS=: read -r nome _ uid _ descricao casa _; do
    [[ "$uid" != "$uid_soenvio" ]] || casa="/data/$descricao"
    casa="${casa%/./}"; casa="${casa%/}"
    [[ "$nome" != "$user" && "$casa" == /data/* ]] || continue
    casa="${casa#/data/}"
    if [[ "$casa" == "$pasta" || "$casa" == "$pasta"/* || "$pasta" == "$casa"/* ]]; then
      echo "Aviso: /data/$pasta e dividida com o usuario $nome (/data/$casa): um alcanca os arquivos do outro."
    fi
  done < "$passwd_file"
}

# Área de entrada do perfil só envio: /data/.entrada é do root e só ele entra; a de cada usuário é do ftpsoenvio.
preparar_entrada() { # <usuario>
  local area="$pasta_entrada/$1"
  [[ ! -L "$pasta_entrada" && ! -L "$area" ]] || { echo "Area de entrada recusada: $area passa por link simbolico" >&2; exit 1; }
  [[ ! -e "$area" || -d "$area" ]] || { echo "Area de entrada recusada: $area existe e nao e pasta" >&2; exit 1; }
  install -d -o root -g root -m 0700 "$pasta_entrada"
  install -d -o ftpsoenvio -g ftpsoenvio -m 0700 "$area"
}

# Entrega à pasta do usuário o que ficou na área de entrada dele (envio que o vigia não chegou a mover).
entregar_entrada() { # <usuario> <pasta do usuario, sem o /data/>
  [[ -d "$pasta_entrada/$1" && ! -L "$pasta_entrada" && ! -L "$pasta_entrada/$1" ]] || return 0
  perl /usr/local/lib/allsafe/entrada.pl "$1" "$2"
}

# O usuário deixou de ser só envio, ou saiu do cadastro: o que ficou na área vai para a pasta dele e a área sai.
# O que não pôde ser entregue continua na área, com o aviso.
retirar_entrada() { # <usuario> <pasta do usuario, sem o /data/>
  local area="$pasta_entrada/$1"
  [[ -d "$area" && ! -L "$pasta_entrada" && ! -L "$area" ]] || return 0
  entregar_entrada "$1" "$2" || true
  find "$area" -xdev -depth -type d -empty -delete
  [[ ! -e "$area" ]] || echo "Aviso: ficou em $area o que nao pode ser entregue em /data/$2."
}

case "$action" in
  list)
    # O `pure-pw list` não aceita `-f` logo depois da ação: o arquivo vai pela variável.
    PURE_PASSWDFILE="$passwd_file" pure-pw list
    ;;
  add|passwd)
    [[ "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || usage
    [[ "$action" != add || "$pasta" =~ $regra_pasta ]] || pasta_invalida
    perfil="${4:-completo}"
    [[ $# -le 4 && ( "$action" == add || $# -le 2 ) ]] || usage
    [[ -n "${dono_do_perfil[$perfil]:-}" ]] || perfil_invalido
    [[ "$logins" =~ ^[1-9][0-9]{0,4}$ ]] || { echo "FTP_MAX_CLIENTS deve ser um inteiro maior que zero" >&2; exit 1; }
    IFS= read -r password
    [[ ${#password} -ge 12 ]] || { echo "Senha deve ter pelo menos 12 caracteres" >&2; exit 1; }
    travar
    if [[ "$action" == add ]]; then
      if [[ -f "$passwd_file" ]] && pasta_de "$user" > /dev/null; then
        echo "Usuario ja existe: $user" >&2; exit 1
      fi
      preparar_pasta "$pasta"
      if [[ "$perfil" == soenvio ]]; then
        preparar_entrada "$user"
        printf '%s\n%s\n' "$password" "$password" | pure-pw useradd "$user" \
          -f "$passwd_file" -u ftpsoenvio -g ftpsoenvio -d "$pasta_entrada/$user" -c "$pasta" -C "$logins"
      else
        printf '%s\n%s\n' "$password" "$password" | pure-pw useradd "$user" \
          -f "$passwd_file" -u "${dono_do_perfil[$perfil]}" -g "${grupo_do_perfil[$perfil]}" -d "/data/$pasta" -C "$logins"
      fi
      ajustar_pastas
      avisar_divisao
      # Usuário inicial criado de novo depois de removido: fica com a senha informada aqui, como na troca de senha.
      [[ "$user" != "$inicial" ]] || { gravar_marca "$marca_inicial"; gravar_marca "$marca_criado"; }
    else
      printf '%s\n%s\n' "$password" "$password" | pure-pw passwd "$user" -f "$passwd_file" -C "$logins"
      # Senha nova: quem estava bloqueado por errar a anterior volta a poder entrar.
      tirar_bloqueios > /dev/null
      [[ "$user" != "$inicial" ]] || gravar_marca "$marca_inicial"
    fi
    gravar_banco
    ;;
  perfil)
    # Sem o perfil, mostra o do usuário. Com ele, troca: o que já está na pasta continua lá, e o modo das
    # pastas acompanha. A sessão de FTP já aberta segue com o perfil anterior até sair.
    [[ "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ && $# -le 3 ]] || usage
    perfil="${3:-}"
    [[ -z "$perfil" || -n "${dono_do_perfil[$perfil]:-}" ]] || perfil_invalido
    if [[ -z "$perfil" ]]; then
      { [[ -f "$passwd_file" ]] && perfil_de "$user"; } || { echo "Usuario nao existe: $user" >&2; exit 1; }
      exit 0
    fi
    travar
    if ! { [[ -f "$passwd_file" ]] && casa="$(pasta_de "$user")"; }; then
      echo "Usuario nao existe: $user" >&2; exit 1
    fi
    casa="${casa#/data/}"
    anterior="$(perfil_de "$user")"
    # Entrar no só envio ou sair dele troca também a pasta da sessão: a área de entrada ou a pasta do usuário.
    if [[ "$perfil" == soenvio ]]; then
      preparar_pasta "$casa"
      preparar_entrada "$user"
      pure-pw usermod "$user" -f "$passwd_file" -u ftpsoenvio -g ftpsoenvio -d "$pasta_entrada/$user" -c "$casa"
    elif [[ "$anterior" == soenvio ]]; then
      pure-pw usermod "$user" -f "$passwd_file" -u "${dono_do_perfil[$perfil]}" -g "${grupo_do_perfil[$perfil]}" -d "/data/$casa" -c ""
    else
      pure-pw usermod "$user" -f "$passwd_file" -u "${dono_do_perfil[$perfil]}" -g "${grupo_do_perfil[$perfil]}"
    fi
    gravar_banco
    ajustar_pastas
    [[ "$anterior" != soenvio || "$perfil" == soenvio ]] || retirar_entrada "$user" "$casa"
    echo "Perfil do usuario $user: $perfil. Vale na proxima entrada no FTP."
    ;;
  ajustar)
    # Uso da partida do serviço ftp, antes de o servidor aceitar sessão: refaz o modo das pastas pelos perfis
    # e entrega ao ftpdata o que um envio deixou sem entrega (container parado entre o envio e a entrega).
    # Com sessão aberta não serve: um envio em andamento perderia o arquivo que ainda está gravando.
    [[ $# -eq 1 ]] || usage
    travar
    [[ -f "$passwd_file" ]] || exit 0
    ajustar_pastas
    while IFS=: read -r nome _ uid _ descricao casa _; do
      # Só envio: a área de entrada volta a ser do perfil e o que ficou nela vai para a pasta do usuário.
      if [[ "$uid" == "$uid_soenvio" && "$nome" =~ ^[a-z_][a-z0-9_-]{0,31}$ && "$descricao" =~ $regra_pasta ]]; then
        preparar_entrada "$nome"
        entregar_entrada "$nome" "$descricao" || echo "AVISO: ficou arquivo sem entrega em $pasta_entrada/$nome" >&2
        # As pastas que o cliente criou na área já existem na pasta do usuário: vazias, saem daqui.
        find "$pasta_entrada/$nome" -mindepth 1 -xdev -depth -type d -empty -delete
        continue
      fi
      casa="${casa%/./}"; casa="${casa%/}"
      [[ "$uid" == "$uid_envio" && "$casa" == /data/* && -d "$casa" && ! -L "$casa" ]] || continue
      find "$casa" -xdev -type d -user ftpenvio -exec chmod --reference="$casa" {} + -exec chown ftpdata:ftpdata {} +
      find "$casa" -xdev -type f -links 1 -user ftpenvio -exec chown ftpdata:ftpdata {} +
    done < "$passwd_file"
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
    if [[ "$(perfil_de "$user")" == soenvio ]]; then
      pure-pw usermod "$user" -f "$passwd_file" -c "$pasta"   # a pasta da sessão continua sendo a área de entrada
    else
      pure-pw usermod "$user" -f "$passwd_file" -d "/data/$pasta"
    fi
    gravar_banco
    ajustar_pastas "$anterior"
    avisar_divisao
    echo "Pasta do usuario $user: /data/$pasta. Os arquivos de ${anterior:-/data/$user} continuam la."
    ;;
  del)
    [[ "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || usage
    travar
    casa="$(pasta_de "$user" || true)"
    anterior="$(perfil_de "$user" || true)"
    pure-pw userdel "$user" -f "$passwd_file"
    # Usuário inicial removido: a marca de criado impede a partida do serviço ftp de trazê-lo de volta.
    if [[ "$user" == "$inicial" ]]; then
      gravar_marca "$marca_criado"
      rm -f "$marca_inicial"
    fi
    gravar_banco
    [[ -z "$casa" ]] || ajustar_pastas "$casa"
    [[ "$anterior" != soenvio || -z "$casa" ]] || retirar_entrada "$user" "${casa#/data/}"
    # Um usuário novo com o mesmo nome não herda a dispensa do TLS, os limites nem os bloqueios.
    [[ ! -f "$lista_tls" ]] || gravar_lista_tls exigir
    [[ ! -f "$lista_limites" ]] || gravar_limite ""
    tirar_bloqueios > /dev/null
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
      echo "Usuario $user dispensado do TLS: vale em instantes, com FTP_TLS_EXCECOES=sim, FTP_TLS_MODE=2 e sem IP publico aceito."
    else
      echo "Usuario $user volta a ser obrigado a usar TLS: vale na proxima entrada dele."
    fi
    ;;
  limites)
    # Sem pares, mostra os limites do usuário. Com pares, grava só os que vieram; valor vazio tira o limite.
    # sessoes, download, envio e horario ficam no cadastro do Pure-FTPd, que é quem os aplica;
    # baixar (downloads ao mesmo tempo pelo painel) fica na lista que o painel lê; tentativas (senhas erradas
    # do mesmo endereço até o bloqueio; 0 = este usuário nunca é bloqueado) e minutos (quanto o bloqueio
    # dura), na mesma lista, que o vigia do FTP também lê.
    [[ "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || usage
    shift 2
    declare -a opcoes=()
    declare -A da_lista=()
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
        baixar)   numero baixar "$valor" 8; da_lista[baixar]="$valor" ;;
        tentativas) numero tentativas "$valor" 100 0; da_lista[tentativas]="$valor" ;;
        minutos)  numero minutos "$valor" 1440; da_lista[minutos]="$valor" ;;
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
    regra_antes="$(mostrar_limites | grep -E '^(tentativas|minutos)=' || true)"
    if (( ${#opcoes[@]} > 0 )); then
      pure-pw usermod "$user" -f "$passwd_file" "${opcoes[@]}"
      gravar_banco
    fi
    for chave in baixar tentativas minutos; do
      [[ -z "${da_lista[$chave]+tem}" ]] || gravar_limite "$chave" "${da_lista[$chave]}"
    done
    # Regra do bloqueio mudou: os bloqueios feitos com a anterior saem. Gravar o mesmo valor não desbloqueia ninguém.
    regra_depois="$(mostrar_limites | grep -E '^(tentativas|minutos)=' || true)"
    [[ "$regra_antes" == "$regra_depois" ]] || tirar_bloqueios > /dev/null
    echo "Limites do usuario $user gravados: valem na proxima entrada no FTP."
    ;;
  bloqueios)
    # Bloqueios por tentativa em vigor, de todos ou de um usuário: quem, de onde, até quando e com quantas senhas erradas.
    [[ -z "$user" || "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || usage
    achou=nao
    for arquivo in "$pasta_bloqueios"/*@*; do
      [[ -f "$arquivo" && ! -L "$arquivo" ]] || continue
      item="${arquivo##*/}"
      nome="${item%%@*}" origem="${item#*@}"
      [[ "$nome" =~ ^[a-z_][a-z0-9_-]{0,31}$ && "$origem" =~ $regra_origem ]] || continue
      [[ -z "$user" || "$nome" == "$user" ]] || continue
      expira="" desde="" erradas=""
      read -r expira desde erradas _ < "$arquivo" || true
      [[ "$expira" =~ ^[0-9]{1,12}$ && "$desde" =~ ^[0-9]{1,12}$ && "$erradas" =~ ^[0-9]{1,6}$ ]] || continue
      (( 10#$expira > EPOCHSECONDS )) || continue
      printf 'usuario=%s origem=%s senhas_erradas=%s desde=%(%F %T)T ate=%(%F %T)T\n' "$nome" "$origem" "$erradas" "$(( 10#$desde ))" "$(( 10#$expira ))"
      achou=sim
    done
    [[ "$achou" == sim ]] || echo "Nenhum bloqueio em vigor."
    ;;
  desbloquear)
    # Tira o bloqueio por tentativa do usuário: de todas as origens ou só de uma. Vale na próxima entrada.
    [[ "$user" =~ ^[a-z_][a-z0-9_-]{0,31}$ && $# -le 3 ]] || usage
    origem="${3:-}"
    [[ -z "$origem" || "$origem" =~ $regra_origem ]] || { echo "Origem invalida: use o endereco IP que aparece em bloqueios" >&2; exit 1; }
    quantos="$(tirar_bloqueios "$origem")"
    if (( quantos > 0 )); then
      echo "Usuario $user desbloqueado ($quantos endereco(s)): vale na proxima entrada no FTP."
    else
      echo "Usuario $user nao tem bloqueio${origem:+ para $origem}."
    fi
    ;;
  tls-lista)
    [[ ! -f "$lista_tls" ]] || grep -E '^[a-z_][a-z0-9_-]{0,31}$' "$lista_tls" || true
    ;;
  *) usage ;;
esac
