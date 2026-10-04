#!/usr/bin/env bash
# Bateria de testes da stack: funcional, segurança e rede. Roda em uma instância isolada, que o
# próprio script cria e remove: nomes, portas, sub-rede, dados e segredos separados da instalação
# desta pasta, que não é tocada. SÓ PARA REDE PRIVADA: a instância de teste só sobe em IP privado.
# Nenhuma senha, token, cookie ou hash é impresso nem gravado nos resultados.
set -uo pipefail
trap '' PIPE
trap 'exit 130' INT TERM
root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir" || exit 1
# shellcheck source=scripts/rede-privada.sh
source scripts/rede-privada.sh
# shellcheck source=scripts/ambiente.sh
source scripts/ambiente.sh

usage() {
  cat <<'USO'
Uso: ./scripts/testar.sh [--manter] [--resultados <pasta>]
     ./scripts/testar.sh --limpar

  (sem opção)           sobe a instância de teste, roda a bateria, grava os resultados e remove tudo
  --manter              deixa a instância de teste no ar ao final (remova depois com --limpar)
  --resultados <pasta>  onde gravar os três arquivos de resultado (padrão: doc/planos, se existir; senão TEMP_DIR/resultados)
  --limpar              só remove a instância de teste e a pasta dela

Ajustes por variável de ambiente (padrão entre parênteses):
  TESTE_IP (127.0.0.2) · TESTE_FTP_PORT (2121) · TESTE_PAINEL_PORT (8444)
  TESTE_PASSIVA_INICIO (32000) · TESTE_SUBNET (172.29.2.0/29) · TESTE_SUBNET_B (172.29.3.0/29)
  TEMP_DIR (o do .env; sem ele, o do .env.example)

Saída: 0 = todos os casos passaram · 1 = algum caso falhou · 2 = uso ou requisito · 3 = segredo no resultado
USO
}
die() { echo "ERRO: $*" >&2; exit 2; }

manter=false; limpar=false; destino=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --manter) manter=true; shift ;;
    --limpar) limpar=true; shift ;;
    --resultados) destino="${2:?Informe a pasta}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção inválida: $1" >&2; usage >&2; exit 2 ;;
  esac
done

for programa in docker curl openssl ss sha256sum tar; do
  command -v "$programa" >/dev/null 2>&1 || die "$programa não encontrado no host."
done
docker compose version >/dev/null 2>&1 || die "plugin Docker Compose não encontrado."
docker info >/dev/null 2>&1 || die "sem acesso ao Docker: o serviço está parado ou este usuário não está no grupo docker."
curl -V | grep -q -w ftps || die "o curl deste host não tem suporte a FTPS."

IP="${TESTE_IP:-127.0.0.2}"
FTP_PORTA="${TESTE_FTP_PORT:-2121}"
PAINEL_PORTA="${TESTE_PAINEL_PORT:-8444}"
PASSIVA="${TESTE_PASSIVA_INICIO:-32000}"
SUBREDE="${TESTE_SUBNET:-172.29.2.0/29}"
SUBREDE_B="${TESTE_SUBNET_B:-172.29.3.0/29}"
ip_privado "$IP" || die "TESTE_IP=$IP não é IP privado. A instância de teste também é só para rede interna."

temp="${TEMP_DIR:-}"
[[ -z "$temp" && -f .env ]] && temp="$(env_file=.env env_valor TEMP_DIR)"
[[ -z "$temp" ]] && temp="$(env_file=.env.example env_valor TEMP_DIR)"
[[ "$temp" == /* ]] || die "TEMP_DIR tem de ser um caminho absoluto (veja o .env.example)."

NOME=allsafe-ftp-teste
T="$temp/testar"; W="$T/trabalho"; S="$T/segredos"
ENVA="$T/env"; ENVB="$T/env-b"
FTP="$NOME"; PAINEL="$NOME-painel"; NGINX="$NOME-nginx"
IMG_FTP="$NOME:local"; IMG_PAINEL="$NOME-painel:local"; IMG_NGINX="$NOME-nginx:local"
B="https://$IP:$PAINEL_PORTA"; F="ftp://$IP:$FTP_PORTA"
CARIMBO="$(date +%Y%m%d-%H%M%S)"; QUANDO="$(date '+%Y-%m-%d %H:%M:%S')"

if [[ -f .env ]]; then
  nome_local="$(env_file=.env env_valor STACK_NAME allsafe-ftp-stack)"
  [[ "$nome_local" != "$NOME" && "$nome_local" != "$NOME-b" ]] \
    || die "o .env desta pasta usa STACK_NAME=$nome_local, reservado para a instância de teste."
fi

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

if [[ -e "$T" && ! -f "$T/.allsafe-ftp-teste" ]]; then
  die "$T já existe e não foi criada por este script; nada foi tocado."
fi
if [[ "$limpar" == true ]]; then
  derrubar; apagar_pasta
  echo "Instância de teste removida: containers, rede, imagens e a pasta $T."
  exit 0
fi
if [[ -e "$T" ]]; then
  echo "Sobra de uma execução anterior em $T: removendo antes de começar."
  derrubar; apagar_pasta
fi

if [[ -z "$destino" ]]; then
  if [[ -d doc/planos ]]; then destino="$root_dir/doc/planos"; else destino="$temp/resultados"; fi
fi
[[ "$destino" == /* ]] || destino="$PWD/$destino"

umask 077
mkdir -p "$W" "$S" || die "não foi possível criar $T."
: > "$T/.allsafe-ftp-teste"; : > "$W/proibidos"
umask 022
finalizado=false
final() {
  [[ "$finalizado" == true ]] && return 0
  finalizado=true
  if [[ "$manter" == true ]]; then
    echo "Instância de teste mantida no ar ($FTP, $PAINEL, $NGINX). Remover: ./scripts/testar.sh --limpar"
  else
    derrubar; apagar_pasta
  fi
}
trap final EXIT

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
mu() { # <add|passwd|del|list> [usuário] [arquivo da senha]: manage-user.sh na instância de teste
  if [[ -n "${3:-}" ]]; then
    { cat "$3"; echo; } | ENV_FILE="$ENVA" ./manage-user.sh "$1" "$2" > "$W/mu.log" 2>&1
  else
    ENV_FILE="$ENVA" ./manage-user.sh "$1" "${2:-}" < /dev/null > "$W/mu.log" 2>&1
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
    *) tempo=10 ;;
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
entrar() { # <pote de cookies> <arquivo da senha> [cabeçalhos a mais...] → código HTTP
  local pote="$1" senha="$2" formulario; shift 2
  formulario="$(c -c "$pote" "$B/entrar" | sed -n 's/.*name="token" value="\([^"]*\)".*/\1/p')"
  c -o "$W/entrada.corpo" -D "$W/entrada.cab" -w '%{http_code}' -b "$pote" -c "$pote" -H "Origin: $B" "$@" \
    --data-urlencode "token=$formulario" --data-urlencode "senha@$senha" "$B/entrar"
}
J="$W/sessao.jar"
csrf() { c -b "$J" "$B/usuarios/novo" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1; }
envio() { # <caminho> <campos...> → "código destino"
  local caminho="$1"; shift
  c -o /dev/null -w '%{http_code} %{redirect_url}' -b "$J" -H "Origin: $B" "$@" "$B$caminho" | sed "s|$B||"
}
aba() { c -o "$W/corpo" -w '%{http_code} %{redirect_url}' "$@" | sed "s|$B||"; }
tls_painel() { openssl s_client -connect "$IP:$PAINEL_PORTA" -"$1" -cipher 'DEFAULT@SECLEVEL=0' < /dev/null 2>&1 | grep -a -o -m1 'New, TLSv1[.0-9]*' || echo recusado; }
auditoria() { docker exec "$PAINEL" cat /painel/auditoria.log > "$W/auditoria" 2>/dev/null; }
eventos() { grep -c " evento=$1" "$W/auditoria" 2>/dev/null || true; }
recusa_deploy() { # <CHAVE=valor> → "código · mensagem · estado da instância"
  cp "$ENVA" "$W/env-recusa"; gravar_env "$W/env-recusa" "${1%%=*}" "${1#*=}"
  local antes codigo; antes="$(ids)"
  ENV_FILE="$W/env-recusa" ./deploy.sh --check-only < /dev/null > "$W/recusa.log" 2>&1; codigo=$?
  echo "saída $codigo · $(grep -E -m1 '^(ERRO|FALHA)' "$W/recusa.log") · instância $([[ "$antes" == "$(ids)" ]] && echo intacta || echo ALTERADA)"
}
recusa_container() { # <ftp|painel|nginx> <CHAVE=valor> → "código · mensagem"
  local codigo; local -a opcoes=()
  case "$1" in
    ftp) opcoes=(-v "$S/ftp_password.txt:/run/secrets/ftp_password:ro" "$IMG_FTP") ;;
    painel) opcoes=(-v "$S/painel_password_hash.txt:/run/secrets/painel_password_hash:ro" "$IMG_PAINEL") ;;
    nginx) opcoes=(--user 10001:10001 --tmpfs /run/nginx:uid=10001,gid=10001 "$IMG_NGINX") ;;
  esac
  timeout 60 docker run --rm --name "$NOME-recusa" --network none --read-only -e "$2" "${opcoes[@]}" > "$W/recusa.log" 2>&1; codigo=$?
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
    echo "| Comando | \`./scripts/testar.sh\` |"
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
  [testes]="$(seq -s ' ' 1 19)"
  [seguranca]="$(seq -s ' ' 1 38)"
  [rede]="$(seq -s ' ' 1 12)"
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
    "Validação estática e em execução, instalação em um comando, login, envio e download por FTPS, ciclo de usuário pelo terminal e pelo painel, reinício, healthcheck do FTP, backup e restauração, abas do painel, atividade e saída"
  gravar seguranca seguranca "🔐 Resultado — bateria de segurança" "Testes de segurança" \
    "Recusas do FTP (sem TLS, anônimo, fuga da pasta, outro usuário, \`SITE CHMOD\`), modos de TLS, containers endurecidos, segredos fora da imagem, do Git, do \`.env\` e das variáveis, recusa de IP e rede públicos, e o painel (sessão, CSRF, origem, cabeçalhos, TLS, limite de tentativas, auditoria)"
  gravar rede rede "🌐 Resultado — bateria de rede" "Testes de rede" \
    "Endereços e portas publicados, faixa passiva, endereço anunciado, limite de sessões por IP, sub-rede Docker, troca de perfil, duas instâncias no mesmo host e painel só em HTTPS"
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
OUTROS_ANTES="$(outros)"

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
  gravar_env "$1" FTP_PUBLIC_IP "$IP"
  gravar_env "$1" FTP_PORT "$3"
  gravar_env "$1" PAINEL_BIND_IP "$IP"
  gravar_env "$1" PAINEL_PORT "$4"
  gravar_env "$1" FTP_PASSIVE_PORT_START "$5"
  gravar_env "$1" FTP_PASSIVE_PORT_END "$(( $5 + 19 ))"
  gravar_env "$1" FTP_SUBNET "$6"
}
preparar "$ENVA" "" "$FTP_PORTA" "$PAINEL_PORTA" "$PASSIVA" "$SUBREDE"
USUARIO="$(env_file="$ENVA" env_valor FTP_USER transfer)"
echo "Bateria de testes na instância isolada $NOME ($IP:$FTP_PORTA e $B). Resultados em $destino."

# ================================================================== A · sem nada no ar
ruins=""; total=0
for item in 127.0.0.1=s 127.255.255.254=s 10.0.0.1=s 10.255.255.255=s 172.16.0.1=s 172.31.255.254=s 192.168.0.1=s 192.168.255.255=s \
            0.0.0.0=n 8.8.8.8=n 200.1.2.3=n 11.0.0.1=n 172.15.255.255=n 172.32.0.1=n 192.167.1.1=n 192.169.1.1=n 100.64.0.1=n 169.254.1.1=n \
            10.0.0.256=n 10.0.0=n 10.0.0.1.1=n 010.0.0.1=n ::1=n fd00::1=n localhost=n =n 10.0.0.1/8=n; do
  total=$((total + 1)); ip_privado "${item%=*}" && obtido=s || obtido=n
  [[ "$obtido" == "${item##*=}" ]] || ruins+=" ${item%=*}"
done
redes=0
for item in 127.0.0.0/8=s 10.0.0.0/8=s 172.16.0.0/12=s 192.168.0.0/16=s 192.168.10.0/24=s 10.1.2.3/32=s \
            0.0.0.0/0=n 10.0.0.0/7=n 172.16.0.0/11=n 192.168.0.0/15=n 8.8.8.0/24=n 100.64.0.0/10=n 10.0.0.0/33=n 10.0.0.0=n 10.0.0.0/=n; do
  redes=$((redes + 1)); cidr_privado "${item%=*}" && obtido=s || obtido=n
  [[ "$obtido" == "${item##*=}" ]] || ruins+=" ${item%=*}"
done
[[ -z "$ruins" ]]; caso $? seguranca 21 "Função ip_privado" "$total endereços e $redes redes conferidos (privados, públicos, CGNAT, link-local, IPv6 e malformados): ${ruins:+divergência em$ruins}${ruins:-nenhuma divergência}"

./scripts/validate.sh > "$W/validate.log" 2>&1; r=$?
perfis="$(find profiles -maxdepth 1 -name '*.env' | wc -l)"
[[ "$r" == 0 && "$(grep -c '^compose OK' "$W/validate.log")" == "$perfis" ]] && grep -q '^Validacao FTP concluida\.$' "$W/validate.log"
caso $? testes 1 "Validação estática" "validate.sh: saída $r · compose OK em $(grep -c '^compose OK' "$W/validate.log") de $perfis perfis · $(tail -1 "$W/validate.log")"

# ================================================================== B · instalação
inicio=$(date +%s); dep; r=$?; duracao=$(( $(date +%s) - inicio ))
if [[ "$r" != 0 ]]; then
  caso 1 testes 10 "Instalação em um comando" "deploy.sh: saída $r · $(grep -E '^(ERRO|FALHA)' "$W/deploy.log" | head -2)"
  echo "A instância de teste não subiu; a bateria para aqui. Últimas linhas do deploy.sh:" >&2
  tail -5 "$W/deploy.log" | limpo >&2
  encerrar
fi
for arquivo in "$S"/*.txt; do proibir "$(head -1 "$arquivo")"; done
tr -d '\r\n' < "$S/ftp_password.txt" > "$W/inicial.senha"
tr -d '\r\n' < "$S/painel_password.txt" > "$W/painel.senha"
printf 'senha-errada-de-teste' > "$W/errada.senha"; printf 'teste@exemplo.com.br' > "$W/anonimo.senha"
for n in 1 2 3 4 5 6; do nova_senha "$W/u$n.senha"; done
ev10="1ª execução: saída 0 em $duracao s, sem terminal · criados: $(grep -c -E '^(Criado|Gerada)' "$W/deploy.log") (o .env e duas senhas) · saúde: $(saude "$FTP" "$PAINEL" "$NGINX")· senhas na saída: $(segredos_em "$W/deploy.log")"
ok10=1; [[ "$(saude "$FTP" "$PAINEL" "$NGINX")" == "healthy healthy healthy " && "$(segredos_em "$W/deploy.log")" == 0 ]] || ok10=0

modos="$(stat -c '%a' "$S" "$S"/*.txt | tr '\n' ' ')"
[[ "$modos" == "700 600 600 600 " ]]; caso $? seguranca 14 "Permissão dos segredos" "pasta e arquivos (ftp_password, painel_password, painel_password_hash): $modos"

ENV_FILE="$ENVA" ./scripts/validate.sh --runtime > "$W/runtime.log" 2>&1; r=$?
[[ "$r" == 0 && "$(grep -c 'running, healthy' "$W/runtime.log")" == 3 ]] && grep -q "presente no PureDB" "$W/runtime.log"
caso $? testes 2 "Validação em execução" "validate.sh --runtime: saída $r · $(grep -E '^(servico|usuario)' "$W/runtime.log" | tr '\n' ';')"

escuta="$(ss -Hltn | awk '{print $4}')"
controle="$(docker port "$FTP" 2121/tcp 2>/dev/null | tr '\n' ' ')"
[[ "$controle" == "$IP:$FTP_PORTA " ]] && grep -q -x -F "$IP:$FTP_PORTA" <<< "$escuta" && ! grep -q -x -E "(0\.0\.0\.0|\*|\[::\]):$FTP_PORTA" <<< "$escuta"
caso $? rede 1 "Bind da porta de controle" "docker port 2121/tcp: $controle· ss: $(grep -c -x -F "$IP:$FTP_PORTA" <<< "$escuta") escuta em $IP:$FTP_PORTA, $(grep -c -x -E "(0\.0\.0\.0|\*|\[::\]):$FTP_PORTA" <<< "$escuta") em todas as interfaces"

publicadas=0; no_host=0
for ((porta = PASSIVA; porta < PASSIVA + 20; porta++)); do
  [[ "$(docker port "$FTP" "$porta/tcp" 2>/dev/null)" == "$IP:$porta" ]] && publicadas=$((publicadas + 1))
  grep -q -x -F "$IP:$porta" <<< "$escuta" && no_host=$((no_host + 1))
done
[[ "$publicadas" == 20 && "$no_host" == 20 ]]
caso $? rede 2 "Faixa passiva publicada" "faixa $PASSIVA-$((PASSIVA + 19)): $publicadas de 20 publicadas 1:1 em $IP · $no_host em escuta no host"

subrede="$(docker network inspect -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' "$NOME-network" 2>/dev/null)"
[[ "$subrede" == "$SUBREDE" ]]; caso $? rede 6 "Sub-rede Docker" "rede $NOME-network: $subrede · FTP_SUBNET: $SUBREDE"

painel_pub="$(docker port "$NGINX" 2>/dev/null | tr '\n' ' ')"
[[ "$painel_pub" == "8443/tcp -> $IP:$PAINEL_PORTA " ]] && grep -q -x -F "$IP:$PAINEL_PORTA" <<< "$escuta" && ! grep -q -x -E "(0\.0\.0\.0|\*|\[::\]):$PAINEL_PORTA" <<< "$escuta"
caso $? rede 9 "Bind do painel" "nginx publica: $painel_pub· ss: $(grep -c -x -F "$IP:$PAINEL_PORTA" <<< "$escuta") escuta em $IP:$PAINEL_PORTA, $(grep -c -x -E "(0\.0\.0\.0|\*|\[::\]):$PAINEL_PORTA" <<< "$escuta") em todas as interfaces"

p_ftp="$(docker port "$FTP" | wc -l)"; p_painel="$(docker port "$PAINEL" | wc -l)"; p_nginx="$(docker port "$NGINX" | wc -l)"
p_fora="$(docker port "$FTP"; docker port "$PAINEL"; docker port "$NGINX")"; p_fora="$(grep -c -v -F -- "-> $IP:" <<< "$p_fora")"
[[ "$p_ftp" == 21 && "$p_painel" == 0 && "$p_nginx" == 1 && ( "$p_fora" == 0 || -z "$p_fora" ) ]]
caso $? rede 11 "Nenhuma porta além das previstas" "ftp: $p_ftp (controle + 20 passivas) · painel: $p_painel · nginx: $p_nginx · publicadas fora de $IP: ${p_fora:-0}"

ev=""; ok=0
for n in "$FTP" "$PAINEL" "$NGINX"; do
  d="$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}} {{.HostConfig.CapDrop}} {{.HostConfig.SecurityOpt}} privilegiado={{.HostConfig.Privileged}}' "$n" 2>/dev/null)"
  [[ "$d" == "true [ALL] [no-new-privileges:true] privilegiado=false" ]] || ok=1
  ev+="$n: $d; "
done
usuario_nginx="$(docker inspect -f '{{.Config.User}}' "$NGINX" 2>/dev/null)"; [[ "$usuario_nginx" == 10001:10001 ]] || ok=1
caso $ok seguranca 8 "Container endurecido" "$ev nginx roda como $usuario_nginx (sem root)"

soquetes="$(docker inspect -f '{{range .Mounts}}{{println .Source}}{{end}}' "$FTP" "$PAINEL" "$NGINX" 2>/dev/null | grep -c 'docker\.sock')"
[[ "$soquetes" == 0 ]]; caso $? seguranca 35 "Sem socket do Docker" "montagens com docker.sock nos três containers: $soquetes"

docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$FTP" "$PAINEL" "$NGINX" > "$W/variaveis" 2>/dev/null
n_nome="$(grep -c -i -E '^[^=]*(password|passwd|secret|token|hash|_key)[^=]*=' "$W/variaveis")"; n_valor="$(segredos_em "$W/variaveis")"
[[ "$n_nome" == 0 && "$n_valor" == 0 ]]
caso $? seguranca 12 "Nenhuma senha em variável de ambiente" "$(grep -c . "$W/variaveis") variáveis nos três containers · com nome de senha, token, hash ou chave: $n_nome · com o valor de um segredo: $n_valor"

s_ftp="$(docker exec "$FTP" ls /run/secrets 2>/dev/null | tr '\n' ' ')"; s_painel="$(docker exec "$PAINEL" ls /run/secrets 2>/dev/null | tr '\n' ' ')"
s_nginx="$(docker exec "$NGINX" ls /run/secrets 2>/dev/null | tr '\n' ' ')"
[[ "$s_ftp" == "ftp_password " && "$s_painel" == "painel_password_hash " && -z "$s_nginx" ]]
caso $? seguranca 13 "Cada serviço vê só o próprio segredo" "ftp: ${s_ftp:-nenhum }· painel: ${s_painel:-nenhum }· nginx: ${s_nginx:-nenhum}"

ev=""; ok=0
for imagem in "$IMG_FTP" "$IMG_PAINEL" "$IMG_NGINX"; do
  h="$(docker history --no-trunc "$imagem" 2>/dev/null | grep -c -a -F -f "$W/proibidos")"
  v="$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$imagem" 2>/dev/null | grep -c -i -E 'password|passwd|secret|token|hash|_key')"
  docker create --name "$NOME-export" "$imagem" > /dev/null 2>&1
  a="$(docker export "$NOME-export" 2>/dev/null | grep -c -a -F -f "$W/proibidos")"
  docker rm -f "$NOME-export" > /dev/null 2>&1
  [[ "$h" == 0 && "$v" == 0 && "$a" == 0 ]] || ok=1
  ev+="$imagem: histórico $h, variáveis $v, arquivos $a; "
done
caso $ok seguranca 9 "Segredo fora da imagem" "ocorrências das senhas e do hash desta instalação · $ev"

# ================================================================== C · FTP
head -c 65536 /dev/urandom > "$W/envio.bin"; soma="$(sha256sum < "$W/envio.bin" | cut -c1-64)"
r="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" "$F/")"
[[ "$r" == 0 ]]; caso $? testes 3 "Login por FTPS" "usuário inicial, curl --ssl-reqd: saída $r · $(resposta 230)"

r="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" --disable-epsv -T "$W/envio.bin" "$F/backup.cfg")"; pasv="$(resposta 227)"
gravado="$(docker exec "$FTP" stat -c '%s bytes, dono %U, modo %a' "/data/$USUARIO/backup.cfg" 2>/dev/null)"
[[ "$r" == 0 && "$gravado" == "65536 bytes"* ]]; caso $? testes 4 "Envio de arquivo" "curl -T: saída $r · em DATA_DIR/dados/$USUARIO: ${gravado:-arquivo ausente}"
anunciado=""; porta_dados=0
if [[ "$pasv" =~ \(([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+)\) ]]; then
  anunciado="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}.${BASH_REMATCH[4]}"; porta_dados=$(( BASH_REMATCH[5] * 256 + BASH_REMATCH[6] ))
fi
[[ "$anunciado" == "$IP" && "$porta_dados" -ge "$PASSIVA" && "$porta_dados" -lt $((PASSIVA + 20)) ]]
caso $? rede 4 "Endereço anunciado" "resposta do PASV: ${pasv:-ausente} · endereço $anunciado (FTP_PUBLIC_IP=$IP) · porta $porta_dados, dentro da faixa $PASSIVA-$((PASSIVA + 19))"
r2="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" --disable-epsv "$F/")"
[[ "$r" == 0 && "$r2" == 0 ]] && grep -q 'backup\.cfg' "$W/curl.out"
caso $? rede 3 "Transferência em modo passivo" "envio com PASV: saída $r · listagem com PASV: saída $r2, arquivo enviado $(grep -q 'backup\.cfg' "$W/curl.out" && echo presente || echo AUSENTE) na listagem"

r="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" -o "$W/volta.bin" "$F/backup.cfg")"; volta="$(sha256sum < "$W/volta.bin" 2>/dev/null | cut -c1-64)"
[[ "$r" == 0 && "$volta" == "$soma" ]]; caso $? testes 5 "Download e comparação" "curl -o: saída $r · sha256 $([[ "$volta" == "$soma" ]] && echo idêntico || echo DIFERENTE) (${soma:0:16}…)"

# Segunda execução do deploy.sh: nada é recriado, senha e dado ficam como estavam.
a_ids="$(ids)"; a_somas="$(somas)"; dep; r=$?
rv="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" -o "$W/volta2.bin" "$F/backup.cfg")"
[[ "$ok10" == 1 && "$r" == 0 && "$a_somas" == "$(somas)" && "$a_ids" == "$(ids)" && "$rv" == 0 ]] && cmp -s "$W/envio.bin" "$W/volta2.bin" && [[ "$(grep -c -E '^(Criado|Gerada)' "$W/deploy.log")" == 0 ]]
caso $? testes 10 "Instalação em um comando" "$ev10 · 2ª execução: saída $r, criados: $(grep -c -E '^(Criado|Gerada)' "$W/deploy.log"), segredos $([[ "$a_somas" == "$(somas)" ]] && echo iguais || echo MUDARAM), containers $([[ "$a_ids" == "$(ids)" ]] && echo 'os mesmos' || echo RECRIADOS), arquivo enviado $(cmp -s "$W/envio.bin" "$W/volta2.bin" && echo idêntico || echo DIFERENTE)"

mu add equip01 "$W/u1.senha"; r_add=$?; mu add equip02 "$W/u2.senha"
mu list; listado="$(grep -c -E '^equip0[12][[:space:]]' "$W/mu.log")"
r_a="$(ftp_curl tls equip01 "$W/u1.senha" -T "$W/envio.bin" "$F/a.cfg")"

r_pwd="$(ftp_curl tls equip01 "$W/u1.senha" -Q "CWD .." -Q "CWD ../../.." -Q PWD "$F/")"; pwd_ftp="$(resposta 257)"
r_etc="$(ftp_curl tls equip01 "$W/u1.senha" -o "$W/passwd" "$F//etc/passwd")"; resp_etc="$(resposta 5)"
r_sobe="$(ftp_curl tls equip01 "$W/u1.senha" --path-as-is -o "$W/passwd" "$F/../../etc/passwd")"
[[ "$r_pwd" == 0 && "$pwd_ftp" == *'"/"'* && "$r_etc" != 0 && "$r_sobe" != 0 && ! -s "$W/passwd" ]]
caso $? seguranca 3 "Fuga do chroot" "depois de CWD .. e CWD ../../..: $pwd_ftp · /etc/passwd: curl saída $r_etc ($resp_etc) · ../../etc/passwd: curl saída $r_sobe · arquivo do sistema recebido: $([[ -s "$W/passwd" ]] && echo SIM || echo não)"

r_l="$(ftp_curl tls equip02 "$W/u2.senha" "$F/")"; ve="$(grep -c 'a\.cfg' "$W/curl.out")"
r_c1="$(ftp_curl tls equip02 "$W/u2.senha" -Q "CWD /data/equip01" "$F/")"; resp_c1="$(resposta 5)"
r_c2="$(ftp_curl tls equip02 "$W/u2.senha" -Q "CWD ../equip01" "$F/")"
r_c3="$(ftp_curl tls equip02 "$W/u2.senha" --path-as-is -o "$W/alheio" "$F/../equip01/a.cfg")"
[[ "$r_a" == 0 && "$r_l" == 0 && "$ve" == 0 && "$r_c1" != 0 && "$r_c2" != 0 && "$r_c3" != 0 && ! -s "$W/alheio" ]]
caso $? seguranca 4 "Isolamento entre usuários" "equip02 lista a própria pasta: saída $r_l, arquivos do equip01 à vista: $ve · CWD /data/equip01: curl saída $r_c1 ($resp_c1) · CWD ../equip01: saída $r_c2 · baixar ../equip01/a.cfg: saída $r_c3, arquivo recebido: $([[ -s "$W/alheio" ]] && echo SIM || echo não)"

modo_antes="$(docker exec "$FTP" stat -c %a /data/equip01/a.cfg 2>/dev/null)"
r="$(ftp_curl tls equip01 "$W/u1.senha" -Q "SITE CHMOD 777 a.cfg" "$F/")"; resp="$(resposta 5)"
modo_depois="$(docker exec "$FTP" stat -c %a /data/equip01/a.cfg 2>/dev/null)"
[[ "$r" != 0 && -n "$modo_antes" && "$modo_antes" == "$modo_depois" ]]
caso $? seguranca 6 "SITE CHMOD" "SITE CHMOD 777: curl saída $r ($resp) · modo do arquivo antes $modo_antes, depois $modo_depois"

r_1="$(ftp_curl tls equip01 "$W/u1.senha" "$F/")"; mu passwd equip01 "$W/u3.senha"; r_pw=$?
r_velha="$(ftp_curl tls equip01 "$W/u1.senha" "$F/")"; r_nova="$(ftp_curl tls equip01 "$W/u3.senha" "$F/")"
mu del equip01; r_del=$?; r_fim="$(ftp_curl tls equip01 "$W/u3.senha" "$F/")"
docker exec "$FTP" test -f /data/equip01/a.cfg; pasta=$?
mu del equip02
[[ "$r_add" == 0 && "$listado" == 2 && "$r_1" == 0 && "$r_pw" == 0 && "$r_velha" == 67 && "$r_nova" == 0 && "$r_del" == 0 && "$r_fim" == 67 && "$pasta" == 0 ]]
caso $? testes 6 "Ciclo de usuário pelo terminal" "add: saída $r_add, na lista: $listado de 2, login $r_1 · passwd: saída $r_pw, senha antiga $r_velha, nova $r_nova · del: saída $r_del, login $r_fim · pasta e arquivo depois do del: $([[ "$pasta" == 0 ]] && echo preservados || echo AUSENTES) (curl: 0 = entrou, 67 = login recusado)"

printf 'curta\n' | ENV_FILE="$ENVA" ./manage-user.sh add equip03 > "$W/curta.log" 2>&1; r=$?
[[ "$r" != 0 && " $(usuarios_ftp)" != *" equip03 "* ]] && grep -q 'Senha deve ter pelo menos 12 caracteres' "$W/curta.log"
caso $? testes 7 "Senha curta" "manage-user.sh add com 5 caracteres: saída $r · $(grep -o 'Senha deve ter[^"]*' "$W/curta.log" | head -1) · usuário criado: $([[ " $(usuarios_ftp)" == *" equip03 "* ]] && echo SIM || echo não)"

resp="$(ftp_cru "USER $USUARIO")"; r="$(ftp_curl puro "$USUARIO" "$W/inicial.senha" "$F/")"
[[ "$r" != 0 && -n "$resp" && ! "$resp" =~ ^(230|331) ]]
caso $? seguranca 1 "Login sem TLS" "USER em texto puro: $resp · curl sem --ssl-reqd: saída $r"

r="$(ftp_curl tls anonymous "$W/anonimo.senha" "$F/")"; resp="$(resposta '[45]')"
[[ "$r" == 67 ]]; caso $? seguranca 2 "Login anônimo" "usuário anonymous por FTPS: curl saída $r ($resp)"

r="$(ftp_curl tls "$USUARIO" "$W/errada.senha" "$F/")"; resp="$(resposta 530)"
[[ "$r" == 67 && "$resp" == 530* ]]; caso $? seguranca 5 "Senha errada" "curl saída $r · $resp"

# Modo 2: só --ftp-ssl-control mede "TLS no login, dados sem proteção" (junto com --ssl-reqd, o curl protege tudo).
m2_claro="$(ftp_curl controle "$USUARIO" "$W/inicial.senha" -o "$W/claro.bin" "$F/backup.cfg")"; m2_resp="$(resposta '(150|226|4|5)')"
m2_tls="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" -o "$W/claro.bin" "$F/backup.cfg")"

limite="$(env_file="$ENVA" env_valor FTP_MAX_CLIENTS_PER_IP 8)"; abertas=(); aceitas=0; sleep 2
for ((i = 1; i <= limite; i++)); do
  { exec {fd}<>"/dev/tcp/$IP/$FTP_PORTA"; } 2>/dev/null || continue
  abertas+=("$fd"); [[ "$(ftp_ler "$fd")" == 220* ]] && aceitas=$((aceitas + 1))
done
excedente="$(ftp_cru)"
for fd in "${abertas[@]}"; do exec {fd}>&-; done
[[ "$aceitas" == "$limite" && "$excedente" == 421* ]]
caso $? rede 5 "Limite de sessões por IP" "FTP_MAX_CLIENTS_PER_IP=$limite: $aceitas sessões aceitas (220) · a seguinte: $excedente"

# ================================================================== D · painel
codigo="$(c -o "$W/corpo" -w '%{http_code}' "$B/saude")"
[[ "$codigo" == 200 && "$(tr -d '\n' < "$W/corpo")" == ok ]]; caso $? testes 11 "Saúde do painel" "GET /saude: $codigo, corpo: $(tr -d '\n' < "$W/corpo")"

ev=""; ok=0
for caminho in / /usuarios /seguranca /atividade; do
  r="$(aba "$B$caminho")"; [[ "$r" == "303 /entrar" && "$(grep -c -E '<table|name="csrf"' "$W/corpo")" == 0 ]] || ok=1
  ev+="GET $caminho: $r; "
done
caso $ok seguranca 22 "Aba sem sessão" "$ev nenhum dado da aba no corpo"

c -D "$W/cabecalhos" -o /dev/null "$B/entrar"; faltam=""
for cabecalho in 'content-security-policy:' 'x-frame-options:' 'x-content-type-options: nosniff' 'strict-transport-security:' 'cache-control: no-store'; do
  grep -q -i "^$cabecalho" "$W/cabecalhos" || faltam+=" $cabecalho"
done
[[ -z "$faltam" ]]; caso $? seguranca 29 "Cabeçalhos de segurança" "$(grep -i -E '^(x-frame-options|x-content-type-options|strict-transport-security|cache-control):' "$W/cabecalhos" | tr -d '\r' | tr '\n' ';') CSP: $(grep -c -i '^content-security-policy:' "$W/cabecalhos") · faltando:${faltam:- nenhum}"

http="$(curl -s --max-time 6 -o "$W/puro" -w '%{http_code}' "http://$IP:$PAINEL_PORTA/entrar")"; form_http="$(grep -c 'name="senha"' "$W/puro" 2>/dev/null)"
https="$(c -o "$W/corpo" -w '%{http_code}' "$B/entrar")"; form_https="$(grep -c 'name="senha"' "$W/corpo")"
[[ "$http" != 200 && "${form_http:-0}" == 0 ]]; caso $? seguranca 30 "Sem HTTP" "HTTP puro na porta do painel: código $http, formulário de entrada no corpo: ${form_http:-0}"
[[ "$https" == 200 && "$form_https" == 1 && "$http" != 200 && "${form_http:-0}" == 0 ]]
caso $? rede 10 "Painel só em HTTPS" "https://: $https, com a tela de entrada · http://: $http, sem a tela de entrada"

t11="$(tls_painel tls1_1)"; t12="$(tls_painel tls1_2)"; t13="$(tls_painel tls1_3)"
[[ "$t11" == recusado && "$t12" == "New, TLSv1.2" && "$t13" == "New, TLSv1.3" ]]
caso $? seguranca 31 "TLS antigo" "TLS 1.0: $(tls_painel tls1) · TLS 1.1: $t11 · TLS 1.2: $t12 · TLS 1.3: $t13"

codigo="$(entrar "$J" "$W/painel.senha")"; destino_entrada="$(grep -i '^location:' "$W/entrada.cab" | tr -d '\r' | cut -d' ' -f2)"
biscoito="$(grep -i '^set-cookie:' "$W/entrada.cab" | tr -d '\r')"
proibir "$(awk '$6 == "__Host-sessao" {print $7}' "$J")"
K="$(csrf)"; proibir "$K"
geral="$(aba -b "$J" "$B/")"
[[ "$codigo" == 303 && "$destino_entrada" == / && "$geral" == "200 " ]] && grep -q '<h1>.*Visão geral</h1>' "$W/corpo"
caso $? testes 12 "Entrada" "POST /entrar com a senha certa: $codigo → $destino_entrada · GET / com a sessão: $geral· $(grep -o '<h1>[^<]*</h1>' "$W/corpo" | head -1 | sed 's/<[^>]*>//g')"
ok=0; for atributo in '__Host-sessao=' 'Path=/' 'Secure' 'HttpOnly' 'SameSite=Strict'; do [[ "$biscoito" == *"$atributo"* ]] || ok=1; done
caso $ok seguranca 28 "Atributos do cookie" "$(sed -E 's/(__Host-sessao=)[^;]+/\1<REDACTED>/' <<< "$biscoito")"

no_ar="$(grep -c 'No ar' "$W/corpo")"; contagem="$(sed -n 's/.*Usuários<\/h2><p class="numero">\([0-9]*\)<.*/\1/p' "$W/corpo" | head -1)"
certificado="$(sed -n 's/.*Certificado do FTP<\/h2><p class="numero menor">\([^<]*\)<.*/\1/p' "$W/corpo" | head -1)"
reais="$(usuarios_ftp | wc -w)"
[[ "$no_ar" -ge 1 && -n "$contagem" && "$contagem" == "$reais" && -n "$certificado" ]]
caso $? testes 13 "Visão geral" "servidor FTP: $([[ "$no_ar" -ge 1 ]] && echo 'No ar' || echo 'FORA DO AR') · usuários na aba: ${contagem:-?}, no PureDB: $reais · certificado do FTP: ${certificado:-ausente}"
saudacao="$(docker exec "$PAINEL" python3 -c 'import socket; s = socket.create_connection(("ftp", 2121), 5); print(s.recv(200).decode(errors="replace").splitlines()[0][:60])' 2>&1 | head -1)"
[[ "$no_ar" -ge 1 && "$saudacao" == 220* && "$(docker port "$PAINEL" | wc -l)" == 0 ]]
caso $? rede 12 "Painel alcança o FTP pela rede interna" "visão geral: $([[ "$no_ar" -ge 1 ]] && echo 'No ar' || echo 'FORA DO AR') · de dentro do painel, ftp:2121 responde: $saudacao · portas publicadas pelo painel: $(docker port "$PAINEL" | wc -l)"

antes="$(usuarios_ftp)"
r="$(envio /usuarios/novo --data-urlencode 'usuario=invasor' --data-urlencode "senha@$W/u4.senha" --data-urlencode "confirmacao@$W/u4.senha")"
[[ "$r" == "403 " && "$antes" == "$(usuarios_ftp)" ]]; caso $? seguranca 25 "Envio sem token CSRF" "POST /usuarios/novo com sessão e sem o token: $r· usuários $([[ "$antes" == "$(usuarios_ftp)" ]] && echo inalterados || echo ALTERADOS)"
r="$(c -o /dev/null -w '%{http_code}' -b "$J" -H 'Origin: https://site-de-fora.example' --data-urlencode 'usuario=invasor' --data-urlencode "csrf=$K" --data-urlencode "senha@$W/u4.senha" --data-urlencode "confirmacao@$W/u4.senha" "$B/usuarios/novo")"
[[ "$r" == 403 && "$antes" == "$(usuarios_ftp)" ]]; caso $? seguranca 26 "Envio com Origin de fora" "POST com o token certo e Origin https://site-de-fora.example: $r · usuários $([[ "$antes" == "$(usuarios_ftp)" ]] && echo inalterados || echo ALTERADOS)"
# O navegador manda "Origin: null" quando o envio parte de outro endereço ou de página sem referência. A política
# same-origin faz o envio do próprio painel levar a origem real; com no-referrer, até ele chegaria como "null".
politica="$(grep -i '^referrer-policy:' "$W/cabecalhos" | tr -d '\r' | cut -d ' ' -f 2-)"
r="$(c -o /dev/null -w '%{http_code}' -b "$J" -H 'Origin: null' --data-urlencode 'usuario=invasor' --data-urlencode "csrf=$K" --data-urlencode "senha@$W/u4.senha" --data-urlencode "confirmacao@$W/u4.senha" "$B/usuarios/novo")"
[[ "$politica" == same-origin && "$r" == 403 && "$antes" == "$(usuarios_ftp)" ]]; caso $? seguranca 38 "Envio com Origin null" "Referrer-Policy da resposta: ${politica:-ausente} · POST com o token certo e Origin null: $r · usuários $([[ "$antes" == "$(usuarios_ftp)" ]] && echo inalterados || echo ALTERADOS)"
r="$(c -o /dev/null -w '%{http_code}' -b "$J" -H 'Host: painel.exemplo.com.br' "$B/")"
[[ "$r" == 400 ]]; caso $? seguranca 27 "Cabeçalho Host inesperado" "GET / com Host: painel.exemplo.com.br: $r"

ev=""; ok=0; pastas_antes="$(docker exec "$FTP" sh -c 'ls -A /data | wc -l')"
for nome in '../x' 'equip 01' 'equip;01' 'Equip01' '-equip'; do
  r="$(envio /usuarios/novo --data-urlencode "usuario=$nome" --data-urlencode "csrf=$K" --data-urlencode "senha@$W/u4.senha" --data-urlencode "confirmacao@$W/u4.senha")"
  [[ "$r" == "400 " ]] || ok=1; ev+="'$nome': $r; "
done
pastas_depois="$(docker exec "$FTP" sh -c 'ls -A /data | wc -l')"
[[ "$antes" == "$(usuarios_ftp)" && "$pastas_antes" == "$pastas_depois" ]] || ok=1
caso $ok seguranca 32 "Nome de usuário malicioso" "$ev usuários $([[ "$antes" == "$(usuarios_ftp)" ]] && echo inalterados || echo ALTERADOS) · pastas em /data: $pastas_depois (eram $pastas_antes)"
printf 'curta123' > "$W/curta.senha"
r="$(envio /usuarios/novo --data-urlencode 'usuario=equip05' --data-urlencode "csrf=$K" --data-urlencode "senha@$W/curta.senha" --data-urlencode "confirmacao@$W/curta.senha")"
[[ "$r" == "400 " && "$antes" == "$(usuarios_ftp)" ]]; caso $? seguranca 33 "Senha fraca no painel" "novo usuário com senha de 8 caracteres: $r· usuário criado: $([[ "$antes" == "$(usuarios_ftp)" ]] && echo não || echo SIM)"
r="$(head -c 20000 /dev/zero | tr '\0' a | c -o /dev/null -w '%{http_code}' -b "$J" -H "Origin: $B" --data-binary @- "$B/usuarios/novo")"
[[ "$r" == 413 ]]; caso $? seguranca 34 "Corpo grande demais" "POST de 20000 bytes (limite de 16 k no nginx): $r"

iniciado="$(docker inspect -f '{{.State.StartedAt}}' "$FTP")"
r="$(envio /usuarios/novo --data-urlencode 'usuario=equip04' --data-urlencode "csrf=$K" --data-urlencode "senha@$W/u4.senha" --data-urlencode "confirmacao@$W/u4.senha")"
r_login="$(ftp_curl tls equip04 "$W/u4.senha" "$F/")"; r_envio="$(ftp_curl tls equip04 "$W/u4.senha" -T "$W/envio.bin" "$F/painel.cfg")"
mesmo="$([[ "$iniciado" == "$(docker inspect -f '{{.State.StartedAt}}' "$FTP")" ]] && echo não || echo SIM)"
[[ "$r" == "303 /usuarios?m=criado" && "$r_login" == 0 && "$r_envio" == 0 && "$mesmo" == não ]]
caso $? testes 14 "Novo usuário pelo painel" "POST /usuarios/novo: $r · FTPS com o usuário novo: login $r_login, envio $r_envio · FTP reiniciado: $mesmo"
r="$(envio /usuarios/senha --data-urlencode 'usuario=equip04' --data-urlencode "csrf=$K" --data-urlencode "senha@$W/u5.senha" --data-urlencode "confirmacao@$W/u5.senha")"
r_velha="$(ftp_curl tls equip04 "$W/u4.senha" "$F/")"; r_nova="$(ftp_curl tls equip04 "$W/u5.senha" "$F/")"
[[ "$r" == "303 /usuarios?m=senha" && "$r_velha" == 67 && "$r_nova" == 0 ]]
caso $? testes 15 "Troca de senha pelo painel" "POST /usuarios/senha: $r · FTPS com a senha antiga: $r_velha (67 = recusado) · com a nova: $r_nova"
r="$(envio /usuarios/remover --data-urlencode 'usuario=equip04' --data-urlencode "csrf=$K" --data-urlencode 'confirmar=sim')"
r_login="$(ftp_curl tls equip04 "$W/u5.senha" "$F/")"; docker exec "$FTP" test -f /data/equip04/painel.cfg; pasta=$?
[[ "$r" == "303 /usuarios?m=removido" && "$r_login" == 67 && "$pasta" == 0 ]]
caso $? testes 16 "Remoção pelo painel" "POST /usuarios/remover: $r · FTPS depois: $r_login (67 = recusado) · arquivo na pasta: $([[ "$pasta" == 0 ]] && echo preservado || echo AUSENTE)"

r="$(aba -b "$J" "$B/atividade")"; ev=""; ok=0
for texto in 'Entrada' 'Usuário criado' 'Senha trocada' 'Usuário removido'; do
  n="$(grep -o "$texto" "$W/corpo" | wc -l)"; [[ "$n" -ge 1 ]] || ok=1; ev+="$texto: $n; "
done
# o token CSRF da própria sessão faz parte dos formulários da página: o que não pode aparecer é senha nem cookie
grep -v -x -F -e "$K" "$W/proibidos" > "$W/proibidos-pagina"
na_pagina="$(grep -c -a -F -f "$W/proibidos-pagina" "$W/corpo" || true)"
[[ "$r" == "200 " && "$na_pagina" == 0 ]] || ok=1
caso $ok testes 17 "Atividade" "GET /atividade: $r· $ev senhas ou cookie de sessão na página: $na_pagina"

r="$(envio /sair --data-urlencode "csrf=$K")"; depois="$(aba -b "$J" "$B/")"
[[ "$r" == "303 /entrar" && "$depois" == "303 /entrar" ]]
caso $? testes 18 "Saída" "POST /sair: $r · abrir a visão geral em seguida: $depois"
antes="$(usuarios_ftp)"
r2="$(envio /usuarios/novo --data-urlencode 'usuario=equip06' --data-urlencode "csrf=$K" --data-urlencode "senha@$W/u4.senha" --data-urlencode "confirmacao@$W/u4.senha")"
[[ "$depois" == "303 /entrar" && "$r2" == "303 /entrar" && "$antes" == "$(usuarios_ftp)" ]]
caso $? seguranca 37 "Sessão encerrada" "cookie antigo em GET /: $depois · em POST /usuarios/novo, com o token antigo: $r2 · usuário criado: $([[ "$antes" == "$(usuarios_ftp)" ]] && echo não || echo SIM)"

auditoria; f_antes="$(eventos entrada_falha)"
r="$(entrar "$W/errado.jar" "$W/errada.senha")"; aviso="$(sed -n 's/.*role="alert">\([^<]*\)<.*/\1/p' "$W/entrada.corpo" | head -1)"
auditoria; f_depois="$(eventos entrada_falha)"
[[ "$r" == 401 && "$f_depois" == $((f_antes + 1)) && "$aviso" != *enha* ]]
caso $? seguranca 23 "Senha errada" "POST /entrar com senha errada: $r · aviso na tela: $aviso · entrada_falha na auditoria: $f_antes → $f_depois"
ev=""; for _ in 2 3 4 5; do ev+="$(entrar "$W/errado.jar" "$W/errada.senha") "; done
sexta="$(entrar "$W/errado.jar" "$W/errada.senha")"; certa="$(entrar "$W/errado.jar" "$W/painel.senha")"
auditoria
[[ "$ev" == "401 401 401 401 " && "$sexta" == 429 && "$certa" == 429 && "$(eventos entrada_bloqueada)" -ge 2 ]]
caso $? seguranca 24 "Limite de tentativas" "2ª a 5ª senha errada: $ev· 6ª: $sexta · senha certa em seguida: $certa · entrada_bloqueada na auditoria: $(eventos entrada_bloqueada)"

docker logs "$FTP" > "$W/log-ftp" 2>&1; docker logs "$PAINEL" > "$W/log-painel" 2>&1; docker logs "$NGINX" > "$W/log-nginx" 2>&1
n_aud="$(segredos_em "$W/auditoria")"; n_logs=$(( $(segredos_em "$W/log-ftp") + $(segredos_em "$W/log-painel") + $(segredos_em "$W/log-nginx") ))
[[ -s "$W/auditoria" && "$n_aud" == 0 && "$n_logs" == 0 ]]
caso $? seguranca 36 "Auditoria sem segredo" "auditoria.log: $(grep -c . "$W/auditoria") linhas, $(grep -c . "$W/proibidos") valores procurados (senhas, hash, cookie e token), $n_aud ocorrências · logs dos três containers: $n_logs ocorrências"

# ================================================================== E · recusas
d="$(recusa_deploy FTP_PASSWORD=valor-de-exemplo-sem-uso)"; migracao="$(grep -c 'Migração' "$W/recusa.log")"
k="$(recusa_container ftp FTP_PASSWORD=valor-de-exemplo-sem-uso)"
recusou "$d" 'ainda traz FTP_PASSWORD' && [[ "$migracao" -ge 1 && "$k" != "saída 0 "* && "$k" == *'não é mais aceita'* ]]
caso $? seguranca 15 ".env antigo com senha" "deploy.sh: $d, explica a migração: $([[ "$migracao" -ge 1 ]] && echo sim || echo NÃO) · container: $k"
ev=""
par() { # <nº> <nome> <serviço do container> <CHAVE=valor> <texto esperado>
  local d k; d="$(recusa_deploy "$4")"; k="$(recusa_container "$3" "$4")"
  recusou "$d" "$5" && [[ "$k" != "saída 0 "* && "$k" == *"$5"* ]]
  caso $? seguranca "$1" "$2" "$4 · deploy.sh: $d · container do $3: $k$ev"
}
par 16 "Bind do FTP em todas as interfaces" ftp FTP_BIND_IP=0.0.0.0 'não é IP privado'
par 17 "Bind do FTP em IP público" ftp FTP_BIND_IP=8.8.8.8 'não é IP privado'
par 18 "IP anunciado público" ftp FTP_PUBLIC_IP=8.8.8.8 'não é IP privado'
par 19 "Bind do painel fora de IP privado" painel PAINEL_BIND_IP=0.0.0.0 'não é IP privado'
ev=" · container do nginx: $(recusa_container nginx PAINEL_REDES_PERMITIDAS=0.0.0.0/0)"
[[ "$ev" == *'saída 1 '*'não é rede privada'* ]] || ev+=" (NÃO RECUSOU)"
par 20 "Rede permitida pública no painel" painel PAINEL_REDES_PERMITIDAS=0.0.0.0/0 'não é rede privada'
[[ "$ev" != *'NÃO RECUSOU'* ]] || { falhas=$((falhas + 1)); sed -i -e '/^20\t/s/\t✅\t/\t❌\t/' "$W/casos-seguranca.tsv"; }
ev=""

chaves='^[A-Za-z0-9_]*(PASSWORD|PASSWD|SECRET|TOKEN|HASH|API_KEY|PRIVATE_KEY)[A-Za-z0-9_]*=.+'
caminhos='^[A-Za-z0-9_]*_(DIR|FILE|PATH)='   # caminho de onde o segredo mora não é segredo
n_env="$(grep -i -E "$chaves" "$ENVA" | grep -c -v -E "$caminhos")"; n_exemplo="$(grep -i -E "$chaves" .env.example | grep -c -v -E "$caminhos")"; n_valor="$(segredos_em "$ENVA")"
[[ "$n_env" == 0 && "$n_exemplo" == 0 && "$n_valor" == 0 ]]
caso $? seguranca 11 "Nenhuma senha no .env" "chaves de senha, token, hash ou chave preenchidas · .env da instância: $n_env · .env.example: $n_exemplo · valores dos segredos no .env: $n_valor"

if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  no_indice="$(git ls-files -- .env .secrets | grep -c -v -x -e '.secrets/.gitkeep' -e '.secrets/README.md')"
  no_historico="$(git log --all --diff-filter=A --name-only --format= -- .env .secrets 2>/dev/null | grep -v -x -e '.secrets/.gitkeep' -e '.secrets/README.md' -e '' | sort -u | wc -l)"
  ignorados=0
  for arquivo in .env .secrets/ftp_password.txt .secrets/painel_password.txt .secrets/painel_password_hash.txt; do
    git check-ignore -q "$arquivo" || ignorados=1
  done
  no_git="$(git grep -c -I -F -f "$W/proibidos" 2>/dev/null | wc -l)"
  [[ "$no_indice" == 0 && "$no_historico" == 0 && "$ignorados" == 0 && "$no_git" == 0 ]]
  caso $? seguranca 10 "Segredo fora do Git" "git ls-files com .env ou arquivo de .secrets além do .gitkeep e do README.md: $no_indice · no histórico (git log --all): $no_historico · .env e os três segredos ignorados pelo .gitignore: $([[ "$ignorados" == 0 ]] && echo sim || echo NÃO) · arquivos versionados com um segredo desta bateria: $no_git"
else
  fora seguranca 10 "Segredo fora do Git" "a pasta não é um repositório Git"
fi

# ================================================================== F · reinício
mu add equip09 "$W/u6.senha"; r_e="$(ftp_curl tls equip09 "$W/u6.senha" -T "$W/envio.bin" "$F/reinicio.cfg")"
dc restart ftp > "$W/restart.log" 2>&1; r=$?; esperar "$FTP"
r_l="$(ftp_curl tls equip09 "$W/u6.senha" -o "$W/reinicio.bin" "$F/reinicio.cfg")"; r_i="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" "$F/")"
dc restart painel >> "$W/restart.log" 2>&1; esperar "$PAINEL"; esperar "$NGINX"
de_volta="$(entrar "$J" "$W/painel.senha")"; proibir "$(awk '$6 == "__Host-sessao" {print $7}' "$J")"
[[ "$r" == 0 && "$r_e" == 0 && "$r_l" == 0 && "$r_i" == 0 && " $(usuarios_ftp)" == *" equip09 "* && "$de_volta" == 303 ]] && cmp -s "$W/envio.bin" "$W/reinicio.bin"
caso $? testes 8 "Reinício" "docker compose restart ftp: saída $r, saúde $(saude "$FTP")· usuário criado antes: login e download $r_l, arquivo $(cmp -s "$W/envio.bin" "$W/reinicio.bin" && echo idêntico || echo DIFERENTE) · usuário inicial: $r_i · painel reiniciado em seguida: saúde $(saude "$PAINEL" "$NGINX")· entrada $de_volta"
achado seguranca "O limite de tentativas do painel fica na memória do processo" "Depois das 6 tentativas o endereço fica bloqueado por 15 minutos; reiniciar o painel zera a contagem (entrada com a senha certa: $de_volta). Quem reinicia o container já tem acesso ao host"

# Healthcheck do FTP: mede a porta de controle. Com o servidor suspenso, o processo existe e a saúde falha.
h_cfg="$(docker inspect -f '{{json .Config.Healthcheck.Test}}' "$FTP" 2>/dev/null)"
docker exec "$FTP" /usr/local/sbin/allsafe-ftp-saude > /dev/null 2>&1; h_antes=$?
docker exec "$FTP" sh -c 'kill -STOP $(pidof pure-ftpd)' > /dev/null 2>&1
docker exec "$FTP" /usr/local/sbin/allsafe-ftp-saude > /dev/null 2>&1; h_parado=$?
docker exec "$FTP" pidof pure-ftpd > /dev/null 2>&1; h_processo=$?
docker exec "$FTP" sh -c 'kill -CONT $(pidof pure-ftpd)' > /dev/null 2>&1
docker exec "$FTP" /usr/local/sbin/allsafe-ftp-saude > /dev/null 2>&1; h_depois=$?
r="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" "$F/")"
[[ "$h_cfg" == *allsafe-ftp-saude* && "$h_antes" == 0 && "$h_parado" != 0 && "$h_processo" == 0 && "$h_depois" == 0 && "$r" == 0 ]]
caso $? testes 19 "Healthcheck do FTP" "teste configurado: $h_cfg · servidor atendendo: saída $h_antes · servidor suspenso (kill -STOP), processo presente (pidof: $h_processo): saída $h_parado · retomado: saída $h_depois, login $r"

# ================================================================== G · TLS obrigatório também nos dados
gravar_env "$ENVA" FTP_TLS_MODE 3; dep; r=$?
m3_claro="$(ftp_curl controle "$USUARIO" "$W/inicial.senha" -o "$W/claro3.bin" "$F/backup.cfg")"; m3_resp="$(resposta '(150|226|4|5)')"
m3_tls="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" -o "$W/claro3.bin" "$F/backup.cfg")"
gravar_env "$ENVA" FTP_TLS_MODE 2
[[ "$r" == 0 && "$m2_tls" == 0 && "$m3_tls" == 0 && "$m3_claro" != 0 ]]
caso $? seguranca 7 "Dados sem criptografia no modo 2" "login com TLS e dados sem proteção (curl --ftp-ssl-control) · modo 2: curl saída $m2_claro ($m2_resp) · modo 3: curl saída $m3_claro ($m3_resp) · TLS no login e nos dados: modo 2 saída $m2_tls, modo 3 saída $m3_tls"
if [[ "$m2_claro" == 0 ]]; then
  achado seguranca "No modo 2 (padrão), o servidor aceita os dados sem criptografia de um cliente que protege só o login" "A senha nunca passa em texto puro, mas o arquivo pode passar se o equipamento não pedir a proteção dos dados. O modo 3 recusa (curl saída $m3_claro); a troca do padrão depende de teste com os equipamentos reais"
fi

# ================================================================== H · perfil e segunda instância
perfil() { sed -n "s/^$1=//p" profiles/medium.env | tail -n 1; }
em_bytes() { case "${1: -1}" in G) echo $(( ${1%G} * 1073741824 )) ;; M) echo $(( ${1%M} * 1048576 )) ;; *) echo "$1" ;; esac; }
limites() { docker inspect -f '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}} {{.HostConfig.PidsLimit}}' "$FTP" 2>/dev/null; }
esperado="$(em_bytes "$(perfil FTP_MEMORY_LIMIT)") $(awk -v c="$(perfil FTP_CPU_LIMIT)" 'BEGIN { printf "%d", c * 1000000000 }') $(perfil FTP_PIDS_LIMIT)"
faixa=$(( $(perfil FTP_PASSIVE_PORT_END) - $(perfil FTP_PASSIVE_PORT_START) + 1 ))
dep --size medium; r=$?
l1="$(limites)"; p1=$(( $(docker port "$FTP" | wc -l) - 1 )); c1="$(docker exec "$FTP" printenv FTP_MAX_CLIENTS 2>/dev/null)"; i1="$(ids)"
dc up -d > "$W/up.log" 2>&1; r_up=$?
l2="$(limites)"; p2=$(( $(docker port "$FTP" | wc -l) - 1 )); i2="$(ids)"
r_l="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" -o "$W/medium.bin" "$F/backup.cfg")"
[[ "$r" == 0 && "$l1" == "$esperado" && "$p1" == "$faixa" && "$c1" == "$(perfil FTP_MAX_CLIENTS)" && "$r_up" == 0 && "$l2" == "$esperado" && "$p2" == "$faixa" && "$i1" == "$i2" && "$r_l" == 0 ]] \
  && cmp -s "$W/envio.bin" "$W/medium.bin" && [[ "$(env_file="$ENVA" env_valor FTP_PROFILE)" == medium ]]
caso $? rede 7 "Troca de perfil" "deploy.sh --size medium: saída $r, saúde $(saude "$FTP" "$PAINEL" "$NGINX")· memória, CPU e processos do FTP: $l1 (perfil: $esperado) · portas passivas: $p1 de $faixa · FTP_MAX_CLIENTS: $c1 · docker compose up -d em seguida: saída $r_up, mesmos containers: $([[ "$i1" == "$i2" ]] && echo sim || echo NÃO), limites $l2, passivas $p2 · arquivo enviado antes: $(cmp -s "$W/envio.bin" "$W/medium.bin" && echo idêntico || echo DIFERENTE)"

preparar "$ENVB" -b "$((FTP_PORTA + 1))" "$((PAINEL_PORTA + 1))" "$((PASSIVA + 100))" "$SUBREDE_B"
a_ids="$(ids)"
ENV_FILE="$ENVB" ./deploy.sh < /dev/null > "$W/deploy-b.log" 2>&1; r=$?
for arquivo in "$T/segredos-b"/*.txt; do [[ -f "$arquivo" ]] && proibir "$(head -1 "$arquivo")"; done
tr -d '\r\n' < "$T/segredos-b/ftp_password.txt" > "$W/inicial-b.senha" 2>/dev/null
saude_b="$(saude "$NOME-b" "$NOME-b-painel" "$NOME-b-nginx")"; saude_a="$(saude "$FTP" "$PAINEL" "$NGINX")"
FB="ftp://$IP:$((FTP_PORTA + 1))"
r_b="$(ftp_curl tls "$USUARIO" "$W/inicial-b.senha" "$FB/")"; r_cruzado="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" "$FB/")"
r_a="$(ftp_curl tls equip09 "$W/u6.senha" "$F/")"; r_ab="$(ftp_curl tls equip09 "$W/u6.senha" "$FB/")"
painel_b="$(c -o /dev/null -w '%{http_code}' "https://$IP:$((PAINEL_PORTA + 1))/saude")"
sub_b="$(docker network inspect -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' "$NOME-b-network" 2>/dev/null)"
ENV_FILE="$ENVB" ./deploy.sh --remover --apagar-dados --sim < /dev/null >> "$W/deploy-b.log" 2>&1; r_rm=$?
[[ "$r" == 0 && "$saude_b" == "healthy healthy healthy " && "$saude_a" == "healthy healthy healthy " && "$r_b" == 0 && "$r_cruzado" == 67 && "$r_a" == 0 && "$r_ab" == 67 \
  && "$painel_b" == 200 && "$sub_b" == "$SUBREDE_B" && "$r_rm" == 0 && "$a_ids" == "$(ids)" && "$(saude "$FTP" "$PAINEL" "$NGINX")" == "healthy healthy healthy " ]]
caso $? rede 8 "Duas instâncias no mesmo host" "segunda instância ($NOME-b, portas $((FTP_PORTA + 1)) e $((PAINEL_PORTA + 1)), sub-rede $sub_b): deploy.sh saída $r, saúde $saude_b· primeira: saúde $saude_a· login na segunda com a senha dela: $r_b, com a senha da primeira: $r_cruzado · usuário criado na primeira: login nela $r_a, na segunda $r_ab · painel da segunda: $painel_b · remoção da segunda: saída $r_rm, primeira com os mesmos containers: $([[ "$a_ids" == "$(ids)" ]] && echo sim || echo NÃO) (67 = login recusado)"

# ================================================================== I · backup e restauração
copias="$T/copias"
r_e="$(ftp_curl tls equip09 "$W/u6.senha" -T "$W/envio.bin" "$F/copia.cfg")"
ENV_FILE="$ENVA" ./scripts/backup.sh < /dev/null > "$W/backup.log" 2>&1; r_bk=$?
copia="$(sed -n 's/^Cópia gravada: \(.*\.tar\.gz\) (.*/\1/p' "$W/backup.log")"
modos="$(stat -c '%a' "$copias" "$copia" "$copia.sha256" 2>/dev/null | tr '\n' ' ')"
tar -tzf "$copia" > "$W/copia.lista" 2>/dev/null
de_fora="$(grep -c -v -E '^(dados|auth|certs|painel)(/|$)' "$W/copia.lista" || true)"
senhas="$(tar -xzOf "$copia" 2>/dev/null | grep -c -a -F -f "$W/proibidos" || true)"
# Depois da cópia: o arquivo é apagado, o usuário é removido e entra um usuário que a cópia não tem.
r_dele="$(ftp_curl tls equip09 "$W/u6.senha" -Q "DELE copia.cfg" "$F/")"
mu del equip09; r_del=$?
nova_senha "$W/u9.senha"; mu add equip10 "$W/u9.senha"
r_sem="$(ftp_curl tls equip09 "$W/u6.senha" "$F/")"; r_novo="$(ftp_curl tls equip10 "$W/u9.senha" "$F/")"
# Cópia adulterada: recusada pela soma antes de qualquer alteração.
{ cat "$copia"; printf 'x'; } > "$copias/adulterada.tar.gz" 2>/dev/null
sed "s|$(basename "$copia")|adulterada.tar.gz|" "$copia.sha256" > "$copias/adulterada.tar.gz.sha256" 2>/dev/null
a_ids="$(ids)"
ENV_FILE="$ENVA" ./scripts/restaurar.sh adulterada.tar.gz --sim < /dev/null > "$W/restaurar-ruim.log" 2>&1; r_ruim=$?
intacta="$([[ "$a_ids" == "$(ids)" && "$(saude "$FTP" "$PAINEL" "$NGINX")" == "healthy healthy healthy " && " $(usuarios_ftp)" == *" equip10 "* ]] && echo 'instância intacta' || echo 'instância ALTERADA')"
ENV_FILE="$ENVA" ./scripts/restaurar.sh "$(basename "$copia")" --sim < /dev/null > "$W/restaurar.log" 2>&1; r_rs=$?
saude_rs="$(saude "$FTP" "$PAINEL" "$NGINX")"
r_l="$(ftp_curl tls equip09 "$W/u6.senha" -o "$W/copia.bin" "$F/copia.cfg")"; volta="$(sha256sum < "$W/copia.bin" 2>/dev/null | cut -c1-64)"
r_10="$(ftp_curl tls equip10 "$W/u9.senha" "$F/")"; r_i="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" "$F/")"
de_volta="$(entrar "$J" "$W/painel.senha")"; proibir "$(awk '$6 == "__Host-sessao" {print $7}' "$J")"
anteriores="$(find "$copias" -maxdepth 1 -name '*-antes-da-restauracao.tar.gz' 2>/dev/null | wc -l)"
[[ "$r_e" == 0 && "$r_bk" == 0 && -s "$copia" && "$modos" == "700 600 600 " && "$de_fora" == 0 && "$senhas" == 0 \
  && "$r_dele" == 0 && "$r_del" == 0 && "$r_sem" == 67 && "$r_novo" == 0 && "$r_ruim" == 1 && "$intacta" == 'instância intacta' \
  && "$r_rs" == 0 && "$saude_rs" == "healthy healthy healthy " && "$r_l" == 0 && "$volta" == "$soma" && "$r_10" == 67 && "$r_i" == 0 \
  && "$de_volta" == 303 && "$anteriores" == 1 ]]
caso $? testes 9 "Backup e restauração" "backup.sh: saída $r_bk, $(basename "${copia:-ausente}"), $(grep -c . "$W/copia.lista") itens, modos da pasta, da cópia e da soma: $modos· itens fora de dados, auth, certs e painel: $de_fora · senhas em texto na cópia: $senhas · depois da cópia: arquivo apagado ($r_dele), usuário removido ($r_del, login $r_sem), usuário novo (login $r_novo) · cópia adulterada: saída $r_ruim, $(grep -o 'a soma sha256[^:]*não confere' "$W/restaurar-ruim.log" | sed 's| de .* não| não|' | head -1), $intacta · restaurar.sh: saída $r_rs, saúde $saude_rs· usuário da cópia: login e download $r_l, sha256 $([[ "$volta" == "$soma" ]] && echo idêntico || echo DIFERENTE) · usuário criado depois da cópia: $r_10 (67 = recusado) · usuário inicial: $r_i · painel: $de_volta · estado anterior guardado: $anteriores cópia"
encerrar
