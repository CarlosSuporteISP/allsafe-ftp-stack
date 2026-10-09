#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Instala, reaplica, atualiza ou remove a stack em um comando, sem perguntas.
# Por padrão, só para rede privada: recusa bind e IP anunciado fora de IP privado. IP público só
# passa com REDE_PERMITIR_IP_PUBLICO=sim no .env, por escolha de quem instala.
set -Eeuo pipefail
root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$root_dir"
# shellcheck source=scripts/rede-privada.sh
source scripts/rede-privada.sh
# shellcheck source=scripts/ambiente.sh
source scripts/ambiente.sh

env_file="${ENV_FILE:-.env}"
size=""
check_only=false
atualizar=false
remover=false
apagar_dados=false
sim=false
usage() {
  cat <<'USO'
Uso: ./deploy.sh [--size small|medium|large|xlarge|extended] [--atualizar] [--check-only]
     ./deploy.sh --remover [--apagar-dados [--sim]]

  (sem opção)       instala ou reaplica: cria o .env, as pastas e as senhas que faltarem,
                    sobe os containers e espera ficarem healthy
  --size <perfil>   grava no .env os limites de profiles/<perfil>.env
                    (sem a opção, o .env fica como está); o perfil não pode
                    pedir mais CPU nem mais memória do que o servidor tem
  --atualizar       reconstrói as imagens sem cache, com os pacotes atuais do Debian
  --check-only      só valida a configuração; não cria nem sobe nada
  --remover         derruba os containers e a rede; dados, segredos e .env ficam
  --apagar-dados    com --remover: apaga também as pastas de DATA_DIR (pede confirmação)
  --sim             com --apagar-dados: dispensa a confirmação
USO
}
die() { echo "ERRO: $*" >&2; exit 1; }
uso_invalido() { echo "$*" >&2; usage >&2; exit 64; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --size) size="${2:?Informe o perfil}"; shift 2 ;;
    --check-only) check_only=true; shift ;;
    --atualizar) atualizar=true; shift ;;
    --remover) remover=true; shift ;;
    --apagar-dados) apagar_dados=true; shift ;;
    --sim) sim=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) uso_invalido "Opção inválida: $1" ;;
  esac
done
if [[ "$remover" == true ]]; then
  [[ -z "$size" && "$check_only" == false && "$atualizar" == false ]] || uso_invalido "Opção inválida: --remover só combina com --apagar-dados e --sim"
else
  [[ "$apagar_dados" == false && "$sim" == false ]] || uso_invalido "Opção inválida: --apagar-dados e --sim só valem com --remover"
fi
[[ "$sim" == false || "$apagar_dados" == true ]] || uso_invalido "Opção inválida: --sim só vale com --apagar-dados"

profile_file="profiles/${size:-small}.env"
[[ -f "$profile_file" ]] || { echo "ERRO: perfil inexistente: $size" >&2; usage >&2; exit 64; }

# Requisitos: conferidos antes de qualquer alteração.
command -v docker >/dev/null 2>&1 || die "Docker não encontrado. Instale o Docker Engine com o plugin Compose e rode de novo."
docker compose version >/dev/null 2>&1 || die "plugin Docker Compose não encontrado (docker compose version falhou)."
docker info >/dev/null 2>&1 || die "sem acesso ao Docker: o serviço está parado ou este usuário não está no grupo docker."

# Recursos: o perfil não pode pedir mais CPU nem mais memória do que o servidor do Docker tem.
# O Docker recusa CPU a mais só na hora de subir; aqui a recusa vem antes de qualquer alteração,
# inclusive antes de criar o .env.
if [[ "$remover" == false ]]; then
  do_perfil() { # <chave> <padrão>: valor do perfil pedido com --size ou, sem ele, do .env que já existe
    local valor=""
    if [[ -n "$size" ]]; then
      valor="$(sed -n "s/^$1=//p" "$profile_file" | tail -n 1)"
    elif [[ -f "$env_file" ]]; then
      valor="$(env_valor "$1")"
    fi
    printf '%s' "${valor:-$2}"
  }
  perfil_nome="${size:-$(do_perfil FTP_PROFILE small)}"
  read -r host_cpus host_memoria < <(docker info --format '{{.NCPU}} {{.MemTotal}}' 2>/dev/null) || true
  cpu_pedida="$(do_perfil FTP_CPU_LIMIT 1.0)"
  memoria_pedida="$(do_perfil FTP_MEMORY_LIMIT 256M)"
  if [[ "${host_cpus:-}" =~ ^[0-9]+$ && "$cpu_pedida" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    awk -v pedida="$cpu_pedida" -v tem="$host_cpus" 'BEGIN { exit !(pedida <= tem) }' \
      || die "o perfil '$perfil_nome' pede $cpu_pedida CPUs (FTP_CPU_LIMIT) e este servidor tem $host_cpus. Use um perfil menor com --size ou ajuste FTP_CPU_LIMIT em $env_file."
  fi
  if [[ "${host_memoria:-}" =~ ^[0-9]+$ && "${memoria_pedida,,}" =~ ^([0-9]+)([kmg]?)b?$ ]]; then
    case "${BASH_REMATCH[2]}" in
      g) memoria_bytes=$(( BASH_REMATCH[1] * 1024 * 1024 * 1024 )) ;;
      m) memoria_bytes=$(( BASH_REMATCH[1] * 1024 * 1024 )) ;;
      k) memoria_bytes=$(( BASH_REMATCH[1] * 1024 )) ;;
      *) memoria_bytes=${BASH_REMATCH[1]} ;;
    esac
    (( memoria_bytes <= host_memoria )) \
      || die "o perfil '$perfil_nome' pede $memoria_pedida de memória (FTP_MEMORY_LIMIT) e este servidor tem $(( host_memoria / 1024 / 1024 )) MiB. Use um perfil menor com --size ou ajuste FTP_MEMORY_LIMIT em $env_file."
  fi
fi

if [[ ! -f "$env_file" ]]; then
  if [[ "$check_only" == true ]]; then
    env_file=.env.example
    echo "Sem .env: validando com o .env.example."
  elif [[ "$remover" == true ]]; then
    die "$env_file não existe: não há instalação desta pasta para remover."
  else
    ( umask 077; cp .env.example "$env_file" )
    chmod 0600 "$env_file"
    echo "Criado $env_file a partir do .env.example: tudo em 127.0.0.1, só este servidor acessa."
  fi
fi

# O .env guarda só variável ajustável: senha ali é recusada.
for chave in FTP_PASSWORD FTP_PASSWORD_FILE; do
  if [[ -n "$(env_valor "$chave")" ]]; then
    echo "ERRO: $env_file ainda traz $chave. Senha não fica mais no .env." >&2
    echo "      Migração: grave a senha em .secrets/ftp-usuario-inicial-senha.txt (modo 0600), apague as linhas" >&2
    echo "      FTP_PASSWORD e FTP_PASSWORD_FILE do .env e rode ./deploy.sh de novo. Guia: doc/segredos.md" >&2
    exit 1
  fi
done
for chave in PAINEL_PASSWORD PAINEL_PASSWORD_HASH; do
  [[ -z "$(env_valor "$chave")" ]] || die "$env_file traz $chave. A senha do painel fica só em .secrets/ (guia: doc/segredos.md)"
done

data_dir="$(env_valor DATA_DIR)"
secrets_dir="$(env_valor SECRETS_DIR ./.secrets)"
[[ "$data_dir" == /* ]] || die "DATA_DIR tem de ser um caminho absoluto em $env_file (veja o .env.example)"

# Nomes antigos, de instalação feita até a 0.9.0: a variável FTP_PUBLIC_IP e os três arquivos de
# segredo. São convertidos aqui, sem perguntas: o .env é copiado antes para BACKUP_DIR e os arquivos
# de segredo só mudam de nome (o conteúdo não é lido nem copiado). Com --check-only nada é alterado.
segredos_renomeados=(
  "ftp_password.txt:ftp-usuario-inicial-senha.txt"
  "painel_password.txt:painel-admin-inicial-senha.txt"
  "painel_password_hash.txt:painel-admin-inicial-senha-hash.txt"
)
env_antigo=false
grep -q '^[[:space:]]*FTP_PUBLIC_IP=' "$env_file" && env_antigo=true
segredos_antigos=()
for par in "${segredos_renomeados[@]}"; do
  [[ -e "$secrets_dir/${par%%:*}" ]] && segredos_antigos+=("$par")
done
if [[ "$env_antigo" == true || ${#segredos_antigos[@]} -gt 0 ]]; then
  if [[ "$check_only" == true ]]; then
    echo "AVISO: esta instalação usa nomes antigos (FTP_PUBLIC_IP no .env ou arquivos *_password*.txt em $secrets_dir)."
    echo "       O ./deploy.sh sem --check-only converte sozinho; aqui nada é alterado."
    # A validação segue com o valor que a conversão gravaria.
    [[ "$env_antigo" == false || -n "$(env_valor FTP_PASSIVE_IP)" ]] || export FTP_PASSIVE_IP="$(env_valor FTP_PUBLIC_IP 127.0.0.1)"
  else
    if [[ "$env_antigo" == true ]]; then
      backup_dir="$(env_valor BACKUP_DIR)"
      [[ "$backup_dir" == /* ]] || die "BACKUP_DIR tem de ser um caminho absoluto em $env_file: é para lá que vai a cópia do .env antes da conversão dos nomes."
      copia_env="${backup_dir%/}/$(date +%Y%m%d-%H%M%S)-antes-da-migracao-de-nomes"
      ( umask 077; mkdir -p "$copia_env" && cp -p -- "$env_file" "$copia_env/env" ) \
        || die "não foi possível copiar $env_file para $copia_env; nada foi convertido."
      anunciado="$(env_valor FTP_PASSIVE_IP "$(env_valor FTP_PUBLIC_IP 127.0.0.1)")"
      # Gravado no mesmo arquivo, que mantém dono e modo: a linha antiga dá lugar à nova, no mesmo ponto.
      novo_env="$(VALOR="$anunciado" awk '
        /^[[:space:]]*FTP_PASSIVE_IP=/ { next }
        /^[[:space:]]*FTP_PUBLIC_IP=/ { if (!feito) { print "FTP_PASSIVE_IP=" ENVIRON["VALOR"]; feito = 1 }; next }
        { print }' "$env_file")"
      printf '%s\n' "$novo_env" > "$env_file"
      unset novo_env
      echo "Convertido: FTP_PUBLIC_IP virou FTP_PASSIVE_IP em $env_file (cópia do anterior em $copia_env/env)."
    fi
    for par in "${segredos_antigos[@]}"; do
      antigo="$secrets_dir/${par%%:*}"; novo="$secrets_dir/${par##*:}"
      if [[ -e "$novo" ]]; then
        echo "AVISO: $antigo e $novo existem: vale o novo. Confira e apague o antigo."
      else
        mv -- "$antigo" "$novo" || die "não foi possível renomear $antigo"
        echo "Convertido: $antigo virou $novo."
      fi
    done
  fi
fi

compose() { docker compose --env-file "$env_file" "$@"; }

if [[ "$remover" == true ]]; then
  if [[ "$apagar_dados" == true ]]; then
    [[ "$data_dir" =~ ^/[^/]+/[^/]+ ]] || die "DATA_DIR=$data_dir é raso demais para apagar por aqui; apague à mão."
    if [[ "$sim" == false ]]; then
      [[ -t 0 ]] || die "--apagar-dados sem terminal exige --sim."
      echo "Serão apagados os backups recebidos, os usuários, os certificados e a auditoria em $data_dir."
      read -r -p "Digite 'apagar' para confirmar: " resposta
      [[ "$resposta" == apagar ]] || die "confirmação não recebida; nada foi removido."
    fi
  fi
  compose down --remove-orphans
  if [[ "$apagar_dados" == true ]]; then
    pastas=()
    for pasta in dados auth certs painel nginx; do
      [[ -d "$data_dir/$pasta" ]] && pastas+=("$pasta")
    done
    imagem="$(env_valor FTP_IMAGE allsafe-ftp:local)"
    if [[ ${#pastas[@]} -eq 0 ]]; then
      echo "Nenhuma pasta da stack em $data_dir."
    elif docker image inspect "$imagem" >/dev/null 2>&1; then
      # Os arquivos são do root e do ftpdata: quem apaga é um container sem rede, só com esta pasta.
      docker run --rm --network none --read-only -v "$data_dir":/alvo --entrypoint find "$imagem" \
        "${pastas[@]/#//alvo/}" -delete
    else
      for pasta in "${pastas[@]}"; do
        rm -rf -- "${data_dir:?}/$pasta" || die "sem permissão para apagar $data_dir/$pasta; apague como root."
      done
    fi
    rmdir "$data_dir" 2>/dev/null || true
    echo "Removidos os containers, a rede e as pastas de dados em $data_dir."
  else
    echo "Removidos os containers e a rede. Os dados continuam em $data_dir."
  fi
  echo "Preservados: $env_file, os segredos em $secrets_dir e as imagens. Para subir de novo: ./deploy.sh"
  exit 0
fi

# Rede: privada por padrão. As funções de scripts/rede-privada.sh leem esta escolha.
REDE_PERMITIR_IP_PUBLICO="$(env_valor REDE_PERMITIR_IP_PUBLICO nao)"
conferir_opcao_ip_publico
exigir_ip FTP_BIND_IP "$(env_valor FTP_BIND_IP 127.0.0.1)" || exit 1
exigir_ip FTP_PASSIVE_IP "${FTP_PASSIVE_IP:-$(env_valor FTP_PASSIVE_IP 127.0.0.1)}" || exit 1
exigir_ip PAINEL_BIND_IP "$(env_valor PAINEL_BIND_IP 127.0.0.1)" || exit 1
IFS=',' read -r -a redes_painel <<< "$(env_valor PAINEL_REDES_PERMITIDAS 127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16)"
for rede in "${redes_painel[@]}"; do
  exigir_rede PAINEL_REDES_PERMITIDAS "${rede// /}" || exit 1
done
# Painel publicado por proxy ou túnel: opção de quem instala; vazio = o endereço do cliente é sempre o da conexão.
PAINEL_PROXY_CONFIAVEL="$(env_valor PAINEL_PROXY_CONFIAVEL)"
exigir_proxies "$PAINEL_PROXY_CONFIAVEL" "$(env_valor PAINEL_REDES_PERMITIDAS 127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16)" || exit 1
# TLS do FTP: 0 e 1 deixam passar senha em texto puro e só existem para equipamento antigo.
tls_modo="$(env_valor FTP_TLS_MODE 2)"
case "$tls_modo" in
  0) tls_texto="SEM TLS (texto puro)" ;;
  1) tls_texto="TLS explícito opcional (aceita texto puro)" ;;
  2) tls_texto="TLS explícito obrigatório no login" ;;
  3) tls_texto="TLS explícito obrigatório no login e nos dados" ;;
  *) die "FTP_TLS_MODE deve ser 0 (sem TLS), 1 (opcional), 2 (obrigatório no login) ou 3 (obrigatório no login e nos dados); em $env_file está '$tls_modo'." ;;
esac
# Bloqueio por tentativa no FTP: o padrão da stack; o limite próprio de cada usuário fica no painel.
bloqueio_tentativas="$(env_valor FTP_BLOQUEIO_TENTATIVAS 5)"
[[ "$bloqueio_tentativas" =~ ^(0|[1-9][0-9]{0,2})$ ]] && (( bloqueio_tentativas <= 100 )) \
  || die "FTP_BLOQUEIO_TENTATIVAS deve ficar entre 0 e 100 (0 desliga o bloqueio por tentativa); em $env_file está '$bloqueio_tentativas'."
bloqueio_minutos="$(env_valor FTP_BLOQUEIO_MINUTOS 15)"
[[ "$bloqueio_minutos" =~ ^[1-9][0-9]{0,3}$ ]] && (( bloqueio_minutos <= 1440 )) \
  || die "FTP_BLOQUEIO_MINUTOS deve ficar entre 1 e 1440; em $env_file está '$bloqueio_minutos'."
# Com IP público aceito, senha em texto puro não passa: o TLS tem de ser obrigatório.
if ip_publico_permitido && (( tls_modo < 2 )); then
  die "REDE_PERMITIR_IP_PUBLICO=sim exige FTP_TLS_MODE=2 ou 3; em $env_file está '$tls_modo'. FTP sem TLS na internet entrega a senha a quem escuta."
fi
# TLS por usuário: o administrador dispensa, pelo painel, o equipamento sem suporte a TLS. Só vale sobre o modo 2
# (em 0 e 1 todos já entram sem TLS; o 3 exige TLS também nos dados) e nunca com IP público aceito: fora disso
# a opção fica sem efeito e ninguém é dispensado.
tls_excecoes="$(env_valor FTP_TLS_EXCECOES sim)"
[[ "$tls_excecoes" == sim || "$tls_excecoes" == nao ]] \
  || die "FTP_TLS_EXCECOES deve ser 'sim' ou 'nao'; em $env_file está '$tls_excecoes'."
tls_por_usuario=nao tls_sem_efeito=""
if [[ "$tls_excecoes" == sim ]]; then
  if [[ "$tls_modo" != 2 ]]; then
    tls_sem_efeito="só vale com FTP_TLS_MODE=2; em $env_file está '$tls_modo'"
  elif ip_publico_permitido; then
    tls_sem_efeito="não vale com REDE_PERMITIR_IP_PUBLICO=sim (FTP sem TLS na internet entrega a senha a quem escuta)"
  else
    tls_por_usuario=sim
  fi
fi
# Contato de segurança: o resumo diz se o security.txt está publicado e, com a variável vazia, como publicar.
aviso_contato() {
  if [[ -n "$contato_seguranca" ]]; then
    echo "Contato de segurança: $contato_seguranca, publicado em /.well-known/security.txt do painel."
  else
    echo "Contato de segurança: não publicado. Para publicar, preencha SEGURANCA_CONTATO_EMAIL em $env_file"
    echo "        e rode ./deploy.sh de novo (política do projeto: SECURITY.md)."
  fi
}
# Dispensados do TLS, contados na instalação que acabou de subir: sem nenhum, o FTP recusa a sessão sem TLS antes da senha.
aviso_dispensados() {
  local quantos
  [[ "$tls_por_usuario" == sim ]] || return 0
  quantos="$(compose exec -T ftp grep -c -E '^[a-z_][a-z0-9_-]{0,31}$' /auth/sem-tls.lista 2>/dev/null || true)"
  [[ "$quantos" =~ ^[1-9][0-9]*$ ]] || return 0
  echo "AVISO: TLS por usuário: $quantos usuário(s) dispensado(s) na aba Usuários do painel entram SEM TLS, com senha e"
  echo "       arquivos em texto puro, que podem ser lidos por quem estiver na mesma rede. Os demais continuam"
  echo "       obrigados a usar TLS, mas um equipamento mal configurado manda a senha em texto puro antes de ser"
  echo "       recusado. Use só para equipamento antigo sem suporte a TLS, em rede interna isolada, com o firewall"
  echo "       liberando só esses equipamentos, e volte a exigir o TLS do usuário assim que puder."
}
aviso_tls() {
  [[ -z "$tls_sem_efeito" ]] || echo "TLS por usuário sem efeito: $tls_sem_efeito. Ninguém é dispensado do TLS."
  case "$tls_modo" in
    0) echo "AVISO: FTP_TLS_MODE=0: o FTP está SEM criptografia. Senhas e arquivos passam em texto puro e podem ser" ;;
    1) echo "AVISO: FTP_TLS_MODE=1: o TLS é opcional. Quem entra sem TLS manda senha e arquivos em texto puro, que podem ser" ;;
    *) return 0 ;;
  esac
  echo "       lidos por quem estiver na mesma rede. Use só para equipamento antigo sem suporte a TLS, em rede interna"
  echo "       isolada, com o firewall liberando só esses equipamentos, e volte para FTP_TLS_MODE=2 assim que puder."
}
painel_cn="$(env_valor PAINEL_CERT_CN)"
if [[ "$painel_cn" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  exigir_ip PAINEL_CERT_CN "$painel_cn" || exit 1
fi
acesso_usuarios="$(env_valor PAINEL_ACESSO_USUARIOS_FTP sim)"
[[ "$acesso_usuarios" == sim || "$acesso_usuarios" == nao ]] \
  || die "PAINEL_ACESSO_USUARIOS_FTP deve ser 'sim' ou 'nao'; em $env_file está '$acesso_usuarios'."
aviso_exposicao="$(env_valor PAINEL_AVISO_EXPOSICAO sim)"
[[ "$aviso_exposicao" == sim || "$aviso_exposicao" == nao ]] \
  || die "PAINEL_AVISO_EXPOSICAO deve ser 'sim' ou 'nao'; em $env_file está '$aviso_exposicao'."
painel_admin="$(env_valor PAINEL_ADMIN_USER admin)"
[[ "$painel_admin" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] \
  || die "PAINEL_ADMIN_USER inválido em $env_file: letras minúsculas, números, _ e -; começa com letra ou _; até 32 caracteres."
contato_seguranca="$(env_valor SEGURANCA_CONTATO_EMAIL)"
if [[ -n "$contato_seguranca" ]]; then
  [[ ${#contato_seguranca} -le 254 && "$contato_seguranca" =~ ^[A-Za-z0-9._+-]{1,64}@([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,24}$ ]] \
    || die "SEGURANCA_CONTATO_EMAIL inválido em $env_file: um endereço de e-mail só, como seguranca@exemplo.com.br, ou vazio."
fi
if ip_publico_permitido; then rede_texto="endereço público aceito"; else rede_texto="rede privada"; fi

if [[ "$check_only" == true ]]; then
  if [[ -n "$size" ]]; then
    docker compose --env-file "$env_file" --env-file "$profile_file" config --quiet
  else
    compose config --quiet
  fi
  echo "OK: perfil '$perfil_nome', $rede_texto, recursos do servidor e compose validados; nada foi alterado."
  aviso_tls
  aviso_ip_publico
  aviso_proxy
  exit 0
fi

# Perfil: as chaves de profiles/<perfil>.env vão para o .env, para o `docker compose up -d` direto
# manter os mesmos limites. Sem --size, o .env fica como está.
if [[ -n "$size" ]]; then
  while IFS= read -r linha; do
    [[ "$linha" =~ ^([A-Z_][A-Z0-9_]*)=(.*)$ ]] || continue
    env_gravar "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
  done < "$profile_file"
  env_gravar FTP_PROFILE "$size"
fi

# Portas: nenhuma pode estar em uso por outro programa. As que os containers desta stack já publicam não contam.
if command -v ss >/dev/null 2>&1; then
  declare -A escuta=() propria=()
  while IFS= read -r alvo; do
    [[ -n "$alvo" ]] && escuta["${alvo/#\*:/0.0.0.0:}"]=1
  done < <(ss -Hltn 2>/dev/null | awk '{print $4}')
  for servico in ftp painel nginx; do
    id="$(compose ps -q "$servico" 2>/dev/null || true)"
    [[ -n "$id" ]] || continue
    while IFS= read -r alvo; do
      [[ -n "$alvo" ]] && propria["$alvo"]=1
    done < <(docker port "$id" 2>/dev/null | sed -n 's/.*-> //p')
  done
  ocupadas=()
  porta_em_uso() { # <ip> <porta>
    [[ -z "${propria[$1:$2]:-}" ]] && [[ -n "${escuta[$1:$2]:-}${escuta[0.0.0.0:$2]:-}" ]]
  }
  ftp_ip="$(env_valor FTP_BIND_IP 127.0.0.1)"
  painel_ip="$(env_valor PAINEL_BIND_IP 127.0.0.1)"
  porta_em_uso "$ftp_ip" "$(env_valor FTP_PORT 21)" && ocupadas+=("$ftp_ip:$(env_valor FTP_PORT 21)")
  porta_em_uso "$painel_ip" "$(env_valor PAINEL_PORT 8443)" && ocupadas+=("$painel_ip:$(env_valor PAINEL_PORT 8443)")
  passiva_inicio="$(env_valor FTP_PASSIVE_PORT_START 30000)"
  passiva_fim="$(env_valor FTP_PASSIVE_PORT_END 30049)"
  for ((porta = passiva_inicio; porta <= passiva_fim; porta++)); do
    porta_em_uso "$ftp_ip" "$porta" && ocupadas+=("$ftp_ip:$porta")
  done
  if [[ ${#ocupadas[@]} -gt 0 ]]; then
    die "porta já em uso por outro programa: ${ocupadas[*]:0:8}. Veja quem usa com 'ss -ltnp' e troque FTP_PORT, PAINEL_PORT ou a faixa passiva em $env_file."
  fi
fi

# Pastas dos dados (bind mount). O container ajusta dono e modo de cada uma ao subir.
# O padrão fica em /srv, onde só o root grava: a pasta de cima é criada uma vez para quem instala.
mkdir -p "$data_dir/dados" "$data_dir/auth" "$data_dir/certs" "$data_dir/painel" "$data_dir/nginx" \
  || die "não foi possível criar as pastas em $data_dir. Crie a pasta de cima uma vez para o seu usuário (sudo install -d -o $(id -un) $(dirname -- "$data_dir")) ou aponte DATA_DIR, BACKUP_DIR e TEMP_DIR para outro lugar em $env_file."

# Senha do usuário inicial: gerada forte na primeira execução; nunca regravada se já existe.
# Para usar uma senha específica, grave-a no arquivo antes de rodar.
umask 077
mkdir -p "$secrets_dir"
chmod 0700 "$secrets_dir"
secret_file="$secrets_dir/ftp-usuario-inicial-senha.txt"
if [[ ! -s "$secret_file" ]]; then
  command -v openssl >/dev/null 2>&1 || die "openssl não encontrado no host (necessário para gerar a senha)"
  openssl rand -base64 36 > "$secret_file"
  echo "Gerada uma senha forte em $secret_file (0600). Guarde-a para o cliente FTP."
fi
chmod 0600 "$secret_file"

# Guia da pasta de segredos: diz para que serve cada arquivo. Não guarda segredo nenhum.
cat > "$secrets_dir/LEIAME.txt" <<'LEIAME'
Segredos da allsafe-ftp-stack. Um arquivo por segredo, modo 0600, fora do Git e das imagens.
Este LEIAME não guarda segredo: só explica para que serve cada arquivo.

ftp-usuario-inicial-senha.txt
  Senha do usuário inicial do FTP (o nome dele é FTP_USER, no .env). É a que vai no equipamento
  ou no cliente FTP. Trocar: grave a senha nova neste arquivo (12 caracteres ou mais) e rode
  docker compose restart ftp. Trocada pelo painel ou pelo ./manage-user.sh passwd, a senha nova vale
  e a deste arquivo fica sem uso até o arquivo ser alterado: aí vale a do arquivo, na subida seguinte.
  O usuário inicial é criado uma vez. Removido pelo painel, ele não volta nas subidas seguintes e
  este arquivo fica sem uso.

painel-admin-inicial-senha.txt
  Senha inicial do primeiro administrador do painel web (o nome dele é PAINEL_ADMIN_USER, no .env),
  em texto, gerada na instalação. Serve para a primeira entrada e vale até ser trocada na aba
  Usuários do painel: trocou, apague este arquivo. O ./scripts/painel-senha.sh apaga sozinho
  quando redefine a senha desse administrador.

painel-admin-inicial-senha-hash.txt
  Hash scrypt dessa senha inicial: o container do painel usa para criar o primeiro administrador,
  enquanto não existe nenhum. Não é a senha e não entra no campo de senha. Os administradores e o
  hash da senha atual de cada um ficam em DATA_DIR/painel/administradores, alterado pelo painel.

backup-chave-privada.txt
  Chave que abre as cópias de segurança (./scripts/restaurar.sh). Gerada na instalação e nunca
  regravada. GUARDE UMA CÓPIA FORA DESTE SERVIDOR: sem ela nenhuma cópia abre, e ela não tem como
  ser recuperada. Quem só faz a cópia não precisa dela: pode ficar só no cofre e voltar para cá
  na hora de restaurar.

backup-chave-publica.txt
  Chave que cifra as cópias de segurança (./scripts/backup.sh). Sai da chave privada e é regravada
  pelo ./deploy.sh enquanto a privada estiver aqui. Não é segredo: com ela só se cifra, não se abre.

Perdeu a senha do painel: ./scripts/painel-senha.sh --gerar   (outro administrador: --usuario NOME)
Estes arquivos não entram na cópia do ./scripts/backup.sh: guarde-os no seu cofre de senhas.
LEIAME
chmod 0600 "$secrets_dir/LEIAME.txt"

compose config --quiet
if [[ "$atualizar" == true ]]; then
  # A base é fixada por digest no Dockerfile; sem cache, os pacotes do Debian são baixados de novo.
  compose build --no-cache
else
  compose build
fi

# Senha do primeiro administrador do painel: gerada forte na primeira execução. O container recebe só o
# hash scrypt e cria o administrador PAINEL_ADMIN_USER com ele; a senha em texto fica só no host.
painel_hash="$secrets_dir/painel-admin-inicial-senha-hash.txt"
painel_senha="$secrets_dir/painel-admin-inicial-senha.txt"
if [[ ! -s "$painel_hash" ]]; then
  if [[ ! -s "$painel_senha" ]]; then
    command -v openssl >/dev/null 2>&1 || die "openssl não encontrado no host (necessário para gerar a senha)"
    openssl rand -base64 36 > "$painel_senha"
    echo "Gerada uma senha forte para o painel em $painel_senha (0600)."
  fi
  chmod 0600 "$painel_senha"
  ENV_FILE="$env_file" scripts/painel-senha.sh --inicial < "$painel_senha"
fi
chmod 0600 "$painel_hash"

# Chaves da cópia de segurança (age): a pública cifra, só a privada abre. O par nasce na primeira
# execução, pelo age-keygen da imagem recém-construída, e a privada nunca é regravada. Com a privada
# presente, a pública é sempre tirada dela; só com a pública, o servidor faz cópia e não restaura.
chave_privada="$secrets_dir/backup-chave-privada.txt"
chave_publica="$secrets_dir/backup-chave-publica.txt"
imagem_ftp="$(env_valor FTP_IMAGE allsafe-ftp:local)"
age_keygen() {
  docker run --rm -i --network none --read-only --cap-drop ALL --security-opt no-new-privileges:true \
    --entrypoint age-keygen "$imagem_ftp" "$@"
}
if [[ ! -s "$chave_privada" && ! -s "$chave_publica" ]]; then
  if ! erro="$(age_keygen 2>&1 > "$chave_privada" < /dev/null)"; then
    rm -f -- "$chave_privada"
    die "não foi possível gerar a chave da cópia de segurança: $erro"
  fi
  echo "Gerada a chave da cópia de segurança em $chave_privada (0600)."
  echo "GUARDE UMA CÓPIA DELA FORA DESTE SERVIDOR: sem ela nenhuma cópia de segurança abre (doc/backup.md)."
fi
if [[ -s "$chave_privada" ]]; then
  chmod 0600 "$chave_privada"
  age_keygen -y < "$chave_privada" > "$chave_publica.novo" \
    || { rm -f -- "$chave_publica.novo"; die "$chave_privada não é uma chave age válida. Ponha de volta a chave guardada no cofre; nada foi alterado nela."; }
  mv -f -- "$chave_publica.novo" "$chave_publica"
fi
chmod 0600 "$chave_publica"

# Sobe e espera os três containers ficarem healthy; só então informa onde acessar. O Docker publica
# as portas passivas uma a uma: nos perfis grandes a subida leva minutos, e a espera acompanha.
portas_passivas=$(( $(env_valor FTP_PASSIVE_PORT_END 30049) - $(env_valor FTP_PASSIVE_PORT_START 30000) + 1 ))
if (( portas_passivas > 400 )); then
  echo "Publicando $portas_passivas portas passivas: a subida pode levar alguns minutos."
fi
if ! compose up -d --wait --wait-timeout $(( 180 + portas_passivas / 4 )); then
  compose ps || true
  die "os containers não ficaram healthy. Veja o motivo com: docker compose logs --tail 50 ftp painel nginx"
fi
compose ps

ftp_ip="$(env_valor FTP_BIND_IP 127.0.0.1)"
echo
echo "Pronto: FTP, painel e nginx no ar (healthy), perfil '$(env_valor FTP_PROFILE small)'."
echo "FTP:    $ftp_ip:$(env_valor FTP_PORT 21), $tls_texto, modo passivo $(env_valor FTP_PASSIVE_PORT_START 30000)-$(env_valor FTP_PASSIVE_PORT_END 30049)"
[[ "$tls_por_usuario" != sim ]] || echo "        equipamento sem suporte a TLS: o administrador dispensa o usuário dele na aba Usuários do painel"
ftp_usuario="$(env_valor FTP_USER transfer)"
# Senha do usuário inicial trocada pelo painel ou pelo manage-user.sh: a do arquivo volta a valer quando ele mudar.
# Removido pelo painel ou pelo manage-user.sh, o usuário inicial não é recriado: os usuários são os do painel.
if ! compose exec -T ftp grep -q -- "^$ftp_usuario:" /auth/pureftpd.passwd 2>/dev/null; then
  echo "        usuário inicial '$ftp_usuario' removido pelo administrador; os usuários do FTP são os da aba Usuários do painel"
elif compose exec -T ftp grep -qxF -- "$ftp_usuario" /auth/senha-inicial.trocada 2>/dev/null; then
  echo "        usuário '$ftp_usuario', senha trocada pelo painel (a do arquivo $secret_file volta a valer quando ele for alterado)"
else
  echo "        usuário '$ftp_usuario', senha no arquivo $secret_file"
fi
echo "Painel: https://$(env_valor PAINEL_BIND_IP 127.0.0.1):$(env_valor PAINEL_PORT 8443)  (pelo nginx; certificado autoassinado; $rede_texto, atrás de firewall)"
if [[ -s "$painel_senha" ]]; then
  echo "        usuário '$painel_admin', senha inicial no arquivo $painel_senha"
  echo "        (valem até serem trocados na aba Usuários do painel)"
else
  echo "        usuário e senha: os definidos na aba Usuários ou com ./scripts/painel-senha.sh"
fi
echo "Segredos: $secrets_dir/LEIAME.txt diz para que serve cada arquivo."
echo "Remover: ./deploy.sh --remover  (os dados ficam em $data_dir)"
aviso_contato
aviso_tls
aviso_dispensados
aviso_ip_publico
aviso_proxy
