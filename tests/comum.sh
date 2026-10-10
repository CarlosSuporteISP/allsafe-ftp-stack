#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Funções da bateria de testes: remoção da instância de teste, registro dos casos, auxiliares de FTP
# e do painel e gravação dos resultados. Carregado pelo tests/testar.sh (com `source`), que define
# antes os nomes, as portas e as pastas da instância de teste.

# ------------------------------------------------------------------ remoção da instância de teste
derrubar() {
  local arquivo nome
  for arquivo in "$ENVB" "$ENVA"; do
    [[ -f "$arquivo" ]] && ENV_FILE="$arquivo" ./deploy.sh --remover --apagar-dados --sim < /dev/null > /dev/null 2>&1
  done
  for nome in "$NOME-b" "$NOME"; do
    docker ps -aq --filter "label=com.docker.compose.project=$nome" | xargs -r docker rm -f > /dev/null 2>&1
    docker network rm "$nome-network" > /dev/null 2>&1
  done
  docker rm -f "$NOME-recusa" "$NOME-export" > /dev/null 2>&1
  # Sobra de dados (arquivos do root e do ftpdata): quem apaga é um container sem rede.
  if [[ -d "$T/dados" || -d "$T/dados-b" ]] && docker image inspect "$IMG_FTP" > /dev/null 2>&1; then
    docker run --rm --network none --read-only -v "$T":/alvo --entrypoint sh "$IMG_FTP" \
      -c 'rm -rf /alvo/dados /alvo/dados-b' > /dev/null 2>&1
  fi
  docker image rm "$IMG_FTP" "$IMG_PAINEL" "$IMG_NGINX" > /dev/null 2>&1
  return 0
}
apagar_pasta() {
  [[ -f "$T/.allsafe-ftp-teste" ]] || return 0
  rm -rf -- "${T:?}" 2>/dev/null
  [[ ! -e "$T" ]] || echo "AVISO: não foi possível apagar $T por inteiro; apague à mão." >&2
}

# ------------------------------------------------------------------ registro dos casos
falhas=0
limpo() { sed -e "s|$T|<TEMP_DIR>/testar|g" -e "s|$root_dir|<projeto>|g"; }
linha() { printf '%s' "$1" | tr '\n\t\r' '   ' | sed -e 's/|/\//g' -e 's/  */ /g' | limpo; }
caso() { # <código: 0 = passou> <tipo> <nº> <nome> <evidência>
  local marca='✅'
  [[ "$1" == 0 ]] || { marca='❌'; falhas=$((falhas + 1)); }
  printf '%s\t%s\t%s\t%s\n' "$3" "$marca" "$4" "$(linha "$5")" >> "$W/casos-$2.tsv"
  printf '%s %-9s %2s · %s\n' "$marca" "$2" "$3" "$4"
}
fora() { # <tipo> <nº> <nome> <motivo>: caso que não se aplica a esta execução
  printf '%s\t%s\t%s\t%s\n' "$2" '⏳' "$3" "$(linha "$4")" >> "$W/casos-$1.tsv"
  printf '⏳ %-9s %2s · %s (%s)\n' "$1" "$2" "$3" "$4"
}
achado() { printf '%s\t%s\n' "$(linha "$2")" "$(linha "$3")" >> "$W/achados-$1.tsv"; }
proibir() { # <valor>: segredo que não pode aparecer em resultado, log nem auditoria
  local valor; valor="$(printf '%s' "$1" | tr -d '\r\n')"
  [[ ${#valor} -ge 12 ]] && printf '%s\n' "$valor" >> "$W/proibidos"
  return 0
}
# Lista ainda vazia (bateria parou antes de existir segredo): o grep não imprime contagem, então a resposta é 0.
segredos_em() { [[ -s "$W/proibidos" ]] || { echo 0; return 0; }; grep -c -a -F -f "$W/proibidos" "$1" 2>/dev/null || true; }

# ------------------------------------------------------------------ auxiliares
dc() { docker compose --env-file "$ENVA" "$@"; }
dep() { ENV_FILE="$ENVA" ./deploy.sh "$@" < /dev/null > "$W/deploy.log" 2>&1; }
gravar_env() { ( env_file="$1"; env_gravar "$2" "$3" ); }
esperar() { # <container>: até 120 s pelo healthy
  local _
  for _ in $(seq 1 60); do
    [[ "$(docker inspect -f '{{.State.Health.Status}}' "$1" 2>/dev/null)" == healthy ]] && return 0
    sleep 2
  done
  return 1
}
saude() { local n; for n in "$@"; do printf '%s ' "$(docker inspect -f '{{.State.Health.Status}}' "$n" 2>/dev/null || echo ausente)"; done; }
ids() { docker inspect -f '{{.Id}}' "$FTP" "$PAINEL" "$NGINX" 2>/dev/null | cut -c1-12 | tr '\n' ' '; }
somas() { sha256sum "$S"/*.txt 2>/dev/null | awk '{print $1}' | sha256sum | cut -c1-16; }
outros() { docker ps -a --no-trunc --format '{{.ID}} {{.Names}}' | grep -v -E " $NOME(-|\$)" | awk '{print $1}' | sort; }
usuarios_ftp() { docker exec "$FTP" cut -d: -f1 /auth/pureftpd.passwd 2>/dev/null | sort | tr '\n' ' '; }
mu() { # <add|passwd|pasta|limites|bloqueios|desbloquear|del|list|tls-dispensar|tls-exigir|tls-lista> [usuário] [arquivo da senha] [pasta, limites ou origem...]: manage-user.sh na instância de teste
  if [[ -n "${3:-}" ]]; then
    { cat "$3"; echo; } | ENV_FILE="$ENVA" ./manage-user.sh "$1" "$2" "${@:4}" > "$W/mu.log" 2>&1
  else
    ENV_FILE="$ENVA" ./manage-user.sh "$1" "${2:-}" "${@:4}" < /dev/null > "$W/mu.log" 2>&1
  fi
}
nova_senha() { openssl rand -base64 24 | tr -d '\n' > "$1"; proibir "$(cat "$1")"; }
# ftp_curl <tls|controle|puro> <usuário> <arquivo da senha> <argumentos do curl...> → código de saída do curl
#   tls = TLS no login e nos dados · controle = TLS só no login · puro = sem TLS
ftp_curl() {
  local modo="$1" usuario="$2" arquivo="$3" codigo tempo=25; shift 3
  local -a opcoes=()
  case "$modo" in
    tls) opcoes=(--ssl-reqd -k) ;;
    controle) opcoes=(--ftp-ssl-control -k) ;;
    *) tempo="${ESPERA_PURO:-10}" ;;  # recusa de senha sem TLS passa pelo argon2id e pela espera do servidor
  esac
  ( umask 077; printf 'user = "%s:%s"\n' "$usuario" "$(tr -d '\r\n' < "$arquivo")" > "$W/curl.cfg" )
  curl -sS -v --max-time "$tempo" -K "$W/curl.cfg" "${opcoes[@]}" "$@" > "$W/curl.out" 2> "$W/curl.err"; codigo=$?
  rm -f "$W/curl.cfg"
  echo "$codigo"
}
resposta() { grep -a -E "^< $1" "$W/curl.err" | tail -1 | tr -d '\r' | cut -c3-; }  # <prefixo do código>: última resposta do servidor
ftp_ler() { # <descritor>: última linha de uma resposta do servidor FTP
  local l
  while IFS= read -r -t 8 -u "$1" l; do
    l="${l%$'\r'}"
    [[ "$l" =~ ^[0-9]{3}\  ]] && { printf '%s\n' "$l"; return 0; }
  done
  return 1
}
ftp_cru() { # [comando...]: conversa sem TLS; devolve a saudação (sem comando) ou a resposta de cada comando
  local fd comando saudacao
  { exec {fd}<>"/dev/tcp/$IP/$FTP_PORTA"; } 2>/dev/null || { echo "sem conexão"; return 1; }
  saudacao="$(ftp_ler "$fd")"
  [[ $# -eq 0 ]] && printf '%s\n' "$saudacao"
  for comando in "$@"; do
    printf '%s\r\n' "$comando" >&"$fd"
    ftp_ler "$fd" || echo "(sem resposta)"
  done
  exec {fd}>&-
}
c() { sleep 0.05; curl -sk --max-time 20 "$@"; }
# Administrador da entrada: $COMO (sem ele, o inicial, $ADMIN). Sessão dos envios: $POTE (sem ele, a principal, $J).
entrar() { # <pote de cookies> <arquivo da senha> [opções do curl a mais...] → código HTTP
  local pote="$1" senha="$2" formulario; shift 2
  formulario="$(c -c "$pote" "$B/entrar" | sed -n 's/.*name="token" value="\([^"]*\)".*/\1/p')"
  c -o "$W/entrada.corpo" -D "$W/entrada.cab" -w '%{http_code}' -b "$pote" -c "$pote" -H "Origin: $B" "$@" \
    --data-urlencode "token=$formulario" --data-urlencode "usuario=${COMO:-$ADMIN}" --data-urlencode "senha@$senha" "$B/entrar"
}
J="$W/sessao.jar"
csrf() { c -b "${POTE:-$J}" "$B/usuarios/novo" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1; }
envio() { # <caminho> <campos...> → "código destino"
  local caminho="$1"; shift
  c -o /dev/null -w '%{http_code} %{redirect_url}' -b "${POTE:-$J}" -H "Origin: $B" "$@" "$B$caminho" | sed "s|$B||"
}
biscoito_de() { awk '$6 == "__Host-sessao" {print $7}' "$1"; }  # <pote>: valor do cookie de sessão
admins() { docker exec "$PAINEL" cut -d: -f1 /painel/administradores 2>/dev/null | tr '\n' ' '; }
painel_de_pe() { # até 60 s pelo painel respondendo pelo nginx
  local _
  for _ in $(seq 1 120); do
    [[ "$(curl -sk --max-time 5 -o /dev/null -w '%{http_code}' "$B/saude")" == 200 ]] && return 0
    sleep 0.5
  done
  return 1
}
aba() { c -o "$W/corpo" -w '%{http_code} %{redirect_url}' "$@" | sed "s|$B||"; }
tls_painel() { openssl s_client -connect "$IP:$PAINEL_PORTA" -"$1" -cipher 'DEFAULT@SECLEVEL=0' < /dev/null 2>&1 | grep -a -o -m1 'New, TLSv1[.0-9]*' || echo recusado; }
auditoria() { docker exec "$PAINEL" cat /painel/auditoria.log > "$W/auditoria" 2>/dev/null; }
eventos() { grep -c " evento=$1" "$W/auditoria" 2>/dev/null || true; }
conferir_deploy() { # <CHAVE=valor>...: deploy.sh --check-only com as chaves trocadas; a saída fica em recusa.log
  local par
  cp "$ENVA" "$W/env-recusa"
  for par in "$@"; do gravar_env "$W/env-recusa" "${par%%=*}" "${par#*=}"; done
  ENV_FILE="$W/env-recusa" ./deploy.sh --check-only < /dev/null > "$W/recusa.log" 2>&1
}
recusa_deploy() { # <CHAVE=valor>... → "código · mensagem · estado da instância"
  local antes codigo; antes="$(ids)"
  conferir_deploy "$@"; codigo=$?
  echo "saída $codigo · $(grep -E -m1 '^(ERRO|FALHA)' "$W/recusa.log") · instância $([[ "$antes" == "$(ids)" ]] && echo intacta || echo ALTERADA)"
}
aceite_deploy() { # <CHAVE=valor>... → "código · linha de aprovação · alertas de IP público · estado da instância"
  local antes codigo; antes="$(ids)"
  conferir_deploy "$@"; codigo=$?
  echo "saída $codigo · $(grep -m1 '^OK:' "$W/recusa.log") · alerta de IP público: $(grep -c '^ALERTA: REDE_PERMITIR_IP_PUBLICO=sim' "$W/recusa.log") · instância $([[ "$antes" == "$(ids)" ]] && echo intacta || echo ALTERADA)"
}
recusa_container() { # <ftp|painel|nginx> <CHAVE=valor>... → "código · mensagem"
  local codigo servico="$1" par; local -a opcoes=() variaveis=()
  shift
  for par in "$@"; do variaveis+=(-e "$par"); done
  case "$servico" in
    ftp) opcoes=(-v "$S/ftp-usuario-inicial-senha.txt:/run/secrets/ftp_usuario_inicial_senha:ro" "$IMG_FTP") ;;
    painel) opcoes=(-v "$S/painel-admin-inicial-senha-hash.txt:/run/secrets/painel_admin_inicial_senha_hash:ro" "$IMG_PAINEL") ;;
    nginx) opcoes=(--user 10001:10001 --tmpfs /run/nginx:uid=10001,gid=10001 "$IMG_NGINX") ;;
  esac
  timeout 60 docker run --rm --name "$NOME-recusa" --network none --read-only "${variaveis[@]}" "${opcoes[@]}" > "$W/recusa.log" 2>&1; codigo=$?
  docker rm -f "$NOME-recusa" > /dev/null 2>&1
  echo "saída $codigo · $(grep -E -m1 '^(ERRO|FALHA)' "$W/recusa.log")"
}
recusou() { [[ "$1" == "saída 1 · "* && "$1" == *"$2"* && "$1" != *ALTERADA* ]]; }

# ------------------------------------------------------------------ resultados
gravar() { # <tipo> <sufixo do arquivo> <título> <rótulo do índice> <o que foi testado>
  local tipo="$1" arquivo="$destino/$1/resultados/$CARIMBO-bateria-$2.md" total ruins pulados resultado n faltou=0
  [[ -f "$W/casos-$tipo.tsv" ]] || : > "$W/casos-$tipo.tsv"
  for n in ${ESPERADOS[$tipo]}; do
    grep -q -P "^$n\t" "$W/casos-$tipo.tsv" && continue
    printf '%s\t❌\tCaso %s\tnão executado: a bateria parou antes\n' "$n" "$n" >> "$W/casos-$tipo.tsv"; faltou=$((faltou + 1))
  done
  falhas=$((falhas + faltou))
  total="$(grep -c . "$W/casos-$tipo.tsv")"; ruins="$(grep -c -P '\t❌\t' "$W/casos-$tipo.tsv")"; pulados="$(grep -c -P '\t⏳\t' "$W/casos-$tipo.tsv")"
  if [[ "$ruins" == 0 ]]; then resultado="✅ Aprovado: $((total - pulados)) casos, nenhum desvio"; else resultado="❌ Reprovado: $ruins de $((total - pulados)) casos com desvio"; fi
  [[ "$pulados" == 0 ]] || resultado+=" · $pulados fora desta execução"
  mkdir -p "$destino/$tipo/resultados" || return 1
  {
    echo "# $3"; echo
    [[ -f "$destino/$tipo/README.md" ]] && { echo "↩ [$4](../README.md)"; echo; }
    echo "| Campo | Valor |"; echo "|---|---|"
    echo "| Data | $QUANDO |"
    echo "| O que foi testado | $5 |"
    echo "| Comando | \`./tests/testar.sh\` |"
    echo "| Versão | $VERSAO |"
    echo "| Ambiente | $AMBIENTE |"
    echo "| Instância | Instância de teste isolada \`$NOME\`, criada e removida pela própria bateria: FTP em \`$IP:$FTP_PORTA\`, painel em \`$B\` pelo nginx, sub-rede \`$SUBREDE\`, dados e segredos em \`TEMP_DIR/testar\` |"
    echo "| Limpeza | $LIMPEZA |"
    echo "| Resultado | $resultado |"
    echo
    echo "Nenhuma senha, hash, token ou cookie aparece neste arquivo: os valores usados foram conferidos contra o texto antes da gravação (0 ocorrências)."
    echo; echo "## 📋 Casos"; echo
    echo "| Nº | Caso | Resultado | Evidência |"; echo "|---|---|---|---|"
    sort -t "$(printf '\t')" -k1,1n "$W/casos-$tipo.tsv" | awk -F '\t' '{ printf "| %s | %s | %s | %s |\n", $1, $3, $2, $4 }'
    if [[ -s "$W/achados-$tipo.tsv" ]]; then
      echo; echo "## 🔎 Achados"; echo
      echo "| Achado | Conclusão |"; echo "|---|---|"
      awk -F '\t' '{ printf "| %s | %s |\n", $1, $2 }' "$W/achados-$tipo.tsv"
    fi
  } > "$arquivo"
  ARQUIVOS+=("$arquivo")
  printf '%-9s %s → %s\n' "$tipo" "$resultado" "$arquivo"
}
declare -A ESPERADOS=(
  [testes]="$(seq -s ' ' 1 58)"
  [seguranca]="$(seq -s ' ' 1 103)"
  [rede]="$(seq -s ' ' 1 14)"
)
ARQUIVOS=()
LIMPEZA="instância mantida no ar (--manter)"
VERSAO="\`$(cat VERSION 2>/dev/null || echo '?')\`"
if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  VERSAO+=" · branch \`$(git rev-parse --abbrev-ref HEAD)\` · commit \`$(git rev-parse --short HEAD)\`"
fi
AMBIENTE="$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-Linux}") · Docker Engine $(docker version -f '{{.Server.Version}}') · Docker Compose $(docker compose version --short) · curl $(curl -V | awk 'NR==1 {print $2}') · $(docker info --format '{{.NCPU}}') CPUs"
encerrar() { # grava os três arquivos, confere que nenhum segredo entrou e sai
  local arquivo vazou=0
  if [[ "$manter" == false ]]; then
    derrubar
    LIMPEZA="containers da bateria: $(docker ps -aq --filter "label=com.docker.compose.project=$NOME" --filter "label=com.docker.compose.project=$NOME-b" | wc -l) · redes: $(docker network ls -q --filter "name=$NOME" | wc -l) · imagens: $(docker images -q "$NOME*" | wc -l) · dados de teste: $([[ -e "$T/dados" || -e "$T/dados-b" ]] && echo 'AINDA EXISTEM' || echo removidos)"
  fi
  LIMPEZA+=" · outros containers do host: $(printf '%s\n' "$OUTROS_ANTES" | grep -c .), $([[ "$OUTROS_ANTES" == "$(outros)" ]] && echo 'os mesmos antes e depois' || echo 'a lista MUDOU durante a bateria')"
  echo
  gravar testes funcional "🧪 Resultado — bateria funcional" "Testes funcionais" \
    "Validação estática e em execução, instalação em um comando, login, envio e download por FTPS, ciclo de usuário pelo terminal e pelo painel, reinício, healthcheck do FTP, backup e restauração, abas do painel, atividade e saída, arquivos estáticos pelo nginx, conversão dos nomes antigos, administradores pelo painel, recuperação do acesso pelo host, a aba Arquivos (navegação e download pelo navegador, com nome acentuado e arquivo grande) e a entrada do usuário do FTP no painel (tela Meus arquivos, download, sessão que acompanha o cadastro, a chave \`PAINEL_ACESSO_USUARIOS_FTP\` e os quatro modos de TLS), o TLS por usuário (dispensa e volta pelo painel e pelo terminal) , a marca (logo e ícone entregues pelo nginx e a autoria no rodapé de todas as telas), o \`robots.txt\` e o \`security.txt\` com o contato de segurança, a execução só em Docker, sem systemd, a senha do usuário inicial reaplicada do segredo a cada subida, a licença e a autoria no projeto e dentro das três imagens, o método HEAD do painel (o código e os cabeçalhos do GET, sem o corpo) e a edição de usuário (pasta trocada pelo painel e pelo terminal, senha e pasta do usuário inicial pelo painel, até o segredo mudar) e renomear e apagar pelo painel (arquivo e pasta na aba Arquivos e o usuário removido junto com a pasta) e os limites por usuário (sessões, taxas e horário gravados pelo painel e pelo terminal e aplicados pelo FTP, e os downloads pelo painel no limite do usuário) e o bloqueio por tentativa no FTP (limite do usuário pelo painel e pelo terminal, bloqueio só do usuário e só para o endereço que errou, desbloqueio, vencimento e o padrão da stack)"
  gravar seguranca seguranca "🔐 Resultado — bateria de segurança" "Testes de segurança" \
    "Recusas do FTP (sem TLS, anônimo, fuga da pasta, outro usuário, \`SITE CHMOD\`), modos de TLS, containers endurecidos, segredos fora da imagem, do Git, do \`.env\` e das variáveis, recusa de IP e rede públicos, a opção \`REDE_PERMITIR_IP_PUBLICO\` (o que passa, o que continua recusado e o alerta), o painel (sessão, CSRF, origem, cabeçalhos, TLS, limite de tentativas, auditoria) e os administradores (entrada sem revelar nomes, senha atual em toda alteração, sessões encerradas, arquivo só com hash, própria conta, nome inválido) e a aba Arquivos (sem sessão, fuga da pasta, link simbólico, entrega só como anexo e limite de downloads ao mesmo tempo) e o usuário do FTP no painel (administração fora do alcance, preso à própria pasta, entrada que não revela contas nem aceita nome de administrador, FTP parado, certificado trocado, limite de sessões e de downloads por usuário), o TLS por usuário (sem TLS só entra quem foi dispensado, \`pure-authd\` morto encerra o FTP, combinações recusadas) , a pasta da marca (só os seis arquivos, só para leitura) os endereços abertos sem senha do \`robots.txt\` e do \`security.txt\` e a segurança ampliada: nada abre sem senha (todas as rotas do painel e os comandos do FTP), senha aleatória não entra, a stack aguenta rajada de senhas, de pedidos e de conexões, conexão parada e pedido malformado, o cadastro das senhas fica fora do alcance da web, do FTP, dos outros containers e do host, e o custo da senha do FTP acompanha o porte, e a troca de pasta do usuário (não sai da pasta dos dados nem age sem sessão, sem token ou com a sessão do próprio usuário do FTP) e o apagar e renomear do painel (não saem da pasta dos dados, não seguem link simbólico, não agem sem sessão, sem token e sem a senha atual, e a pasta grande sai em mais de um pedido) e os limites por usuário (valor fora da regra, sem sessão, sem token e com a sessão do próprio usuário do FTP) e o bloqueio por tentativa no FTP (prazo que não estica, nome fora do cadastro, link e arquivo postos à mão, senhas fora dos registros, queda do vigia e as recusas do desbloqueio e das duas variáveis)"
  gravar rede rede "🌐 Resultado — bateria de rede" "Testes de rede" \
    "Endereços e portas publicados, faixa passiva, endereço anunciado, limite de sessões por IP, sub-rede Docker, troca de perfil, duas instâncias no mesmo host, painel só em HTTPS e rede pública liberada no nginx só com a opção ligada"
  for arquivo in "${ARQUIVOS[@]}"; do
    [[ "$(segredos_em "$arquivo")" == 0 ]] || { vazou=1; rm -f "$arquivo"; }
  done
  if [[ "$vazou" == 1 ]]; then
    echo "ERRO: um valor secreto apareceu em um resultado; os arquivos com o valor foram apagados." >&2
    exit 3
  fi
  if [[ "$falhas" == 0 ]]; then echo "Bateria aprovada: nenhum desvio."; exit 0; fi
  echo "Bateria reprovada: $falhas caso(s) com desvio." >&2
  exit 1
}

# ------------------------------------------------------------------ instância de teste
preparar() { # <arquivo> <sufixo> <porta FTP> <porta do painel> <início da faixa passiva> <sub-rede>
  ( umask 077; cp .env.example "$1" )
  gravar_env "$1" STACK_NAME "$NOME$2"
  gravar_env "$1" FTP_IMAGE "$IMG_FTP"
  gravar_env "$1" PAINEL_IMAGE "$IMG_PAINEL"
  gravar_env "$1" NGINX_IMAGE "$IMG_NGINX"
  gravar_env "$1" FTP_CONTAINER_NAME "$NOME$2"
  gravar_env "$1" PAINEL_CONTAINER_NAME "$NOME$2-painel"
  gravar_env "$1" NGINX_CONTAINER_NAME "$NOME$2-nginx"
  gravar_env "$1" FTP_NETWORK_NAME "$NOME$2-network"
  gravar_env "$1" DATA_DIR "$T/dados$2"
  gravar_env "$1" SECRETS_DIR "$T/segredos$2"
  gravar_env "$1" BACKUP_DIR "$T/copias$2"
  gravar_env "$1" FTP_BIND_IP "$IP"
  gravar_env "$1" FTP_PASSIVE_IP "$IP"
  gravar_env "$1" FTP_PORT "$3"
  gravar_env "$1" PAINEL_BIND_IP "$IP"
  gravar_env "$1" PAINEL_PORT "$4"
  gravar_env "$1" FTP_PASSIVE_PORT_START "$5"
  gravar_env "$1" FTP_PASSIVE_PORT_END "$(( $5 + 19 ))"
  gravar_env "$1" FTP_SUBNET "$6"
  gravar_env "$1" PAINEL_ADMIN_USER "$ADMIN"
}
