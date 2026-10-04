#!/usr/bin/env bash
# Bateria de testes da stack: funcional, segurança e rede. Roda em uma instância isolada, que o
# próprio script cria e remove: nomes, portas, sub-rede, dados e segredos separados da instalação
# desta pasta, que não é tocada. A instância de teste só sobe em IP privado, inclusive nos casos que
# ligam REDE_PERMITIR_IP_PUBLICO. As funções ficam em tests/comum.sh e os casos, em tests/etapas/.
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
Uso: ./tests/testar.sh [--manter] [--resultados <pasta>]
     ./tests/testar.sh --limpar

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

# shellcheck source=tests/comum.sh
source tests/comum.sh

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
    echo "Instância de teste mantida no ar ($FTP, $PAINEL, $NGINX). Remover: ./tests/testar.sh --limpar"
  else
    derrubar; apagar_pasta
  fi
}
trap final EXIT

OUTROS_ANTES="$(outros)"
preparar "$ENVA" "" "$FTP_PORTA" "$PAINEL_PORTA" "$PASSIVA" "$SUBREDE"
USUARIO="$(env_file="$ENVA" env_valor FTP_USER transfer)"
echo "Bateria de testes na instância isolada $NOME ($IP:$FTP_PORTA e $B). Resultados em $destino."

# As etapas rodam na ordem do nome do arquivo e dividem o mesmo estado: cada uma parte do que a
# anterior deixou (instância no ar, usuários criados, sessão do painel).
for etapa in tests/etapas/[0-9][0-9]-*.sh; do
  # shellcheck source=/dev/null
  source "$etapa"
done
encerrar
