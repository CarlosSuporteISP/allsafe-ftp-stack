#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Entrada do container do nginx, a frente web do painel. Por padrão, só para rede privada.
# Roda sem root: gera a configuração em /run/nginx a partir do modelo, das redes permitidas e dos proxies aceitos.
set -Eeuo pipefail

die() { echo "FALHA: $*" >&2; exit 1; }
# shellcheck source=scripts/rede-privada.sh
source /usr/local/lib/allsafe/rede-privada.sh

modelo=/etc/allsafe-nginx/nginx.conf.modelo
configuracao=/run/nginx/nginx.conf
soquete=/nginx/painel.sock
certificado=/nginx/tls/painel-cert.pem
chave=/nginx/tls/painel-key.pem

[[ "$(id -u)" != 0 ]] || die "o nginx desta stack não roda como root: confira 'user' no compose.yaml"

conferir_opcao_ip_publico
PAINEL_REDES_PERMITIDAS="${PAINEL_REDES_PERMITIDAS:-127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16}"
IFS=',' read -r -a redes <<< "$PAINEL_REDES_PERMITIDAS"
[[ ${#redes[@]} -gt 0 ]] || die "PAINEL_REDES_PERMITIDAS está vazia"
regras=$'        allow 127.0.0.1;\n'
for rede in "${redes[@]}"; do
  rede="${rede// /}"
  exigir_rede PAINEL_REDES_PERMITIDAS "$rede" || exit 1
  regras+="        allow ${rede};"$'\n'
done
# Painel publicado por proxy ou túnel: os endereços de onde X-Forwarded-For é aceito. Vazio = de nenhum.
PAINEL_PROXY_CONFIAVEL="${PAINEL_PROXY_CONFIAVEL:-}"
exigir_proxies "$PAINEL_PROXY_CONFIAVEL" "$PAINEL_REDES_PERMITIDAS" || exit 1
proxies=""
IFS=',' read -r -a confiaveis <<< "$PAINEL_PROXY_CONFIAVEL"
for proxy in "${confiaveis[@]}"; do
  [[ -n "${proxy// /}" ]] && proxies+="        ${proxy// /} 1;"$'\n'
done

# O painel sobe antes: cria o soquete e entrega a cópia do certificado. Espera curta, para o caso de
# os dois containers serem iniciados juntos pelo Docker (reinício do host).
for _ in $(seq 1 30); do
  [[ -S "$soquete" && -r "$certificado" && -r "$chave" ]] && break
  sleep 1
done
[[ -S "$soquete" ]] || die "soquete do painel ausente em $soquete: o serviço painel está no ar?"
[[ -r "$certificado" && -r "$chave" ]] || die "certificado do painel ausente ou ilegível em /nginx/tls"

while IFS= read -r linha; do
  if [[ "$linha" == "@REDES@" ]]; then
    printf '%s' "$regras"
  elif [[ "$linha" == "@PROXIES@" ]]; then
    printf '%s' "$proxies"
  else
    printf '%s\n' "$linha"
  fi
done < "$modelo" > "$configuracao"

nginx -e stderr -q -t -c "$configuracao" || die "configuração do nginx recusada"

# Recursos deste container, para a aba Servidor do painel, que só enxerga os dele. O container lê o próprio cgroup e
# grava uma linha de doze números em /estado, a única pasta em que o nginx escreve; o painel a lê sem confiar nela.
# Os campos são os mesmos que o vigia do ftp publica (ftp/vigia.pl): instante, instante de início, milissegundos do
# intervalo, microssegundos de processador gastos nele, cota e período do limite de processador, memória em uso e
# limite, processos e limite, vezes em que o limite de processador segurou o container e vezes em que faltou memória.
# Container parado publica uma vez por minuto; com uso, a cada 5 s. Sem /estado, o nginx sobe do mesmo jeito.
publicar_recursos() {
  local cg=/sys/fs/cgroup destino=/estado/recursos.estado inicio=$EPOCHSECONDS
  local antes_ms=0 vezes=0 g_cpu=0 g_memoria=0 g_processos=0 g_contido=0 g_faltou=0
  local agora_ms cpu contido cota periodo memoria inativa limite processos teto faltou nome valor intervalo gasto diferenca campo
  while :; do
    agora_ms=$(( ${EPOCHREALTIME/[.,]/} / 1000 ))
    cpu=0 contido=0 cota=0 periodo=0 memoria=0 inativa=0 limite=0 processos=0 teto=0 faltou=0
    while read -r nome valor; do
      case "$nome" in usage_usec) cpu=$valor ;; nr_throttled) contido=$valor ;; esac
    done < "$cg/cpu.stat"
    read -r cota periodo < "$cg/cpu.max"
    read -r memoria < "$cg/memory.current"
    while read -r nome valor; do
      [[ "$nome" == inactive_file ]] && { inativa=$valor; break; }
    done < "$cg/memory.stat"
    read -r limite < "$cg/memory.max"
    read -r processos < "$cg/pids.current"
    read -r teto < "$cg/pids.max"
    while read -r nome valor; do
      [[ "$nome" == oom_kill ]] && faltou=$valor
    done < "$cg/memory.events"
    # "max" (sem limite) e qualquer coisa que não seja número viram 0.
    for campo in cpu contido cota periodo memoria inativa limite processos teto faltou; do
      [[ "${!campo}" =~ ^[0-9]{1,18}$ ]] || printf -v "$campo" 0
    done
    memoria=$(( memoria > inativa ? memoria - inativa : 0 ))
    intervalo=$(( antes_ms ? agora_ms - antes_ms : 0 ))
    gasto=$(( vezes && cpu > g_cpu ? cpu - g_cpu : 0 ))
    diferenca=$(( memoria > g_memoria ? memoria - g_memoria : g_memoria - memoria ))
    if (( vezes < 2 || intervalo >= 60000 || gasto >= intervalo * 10 || diferenca >= 1048576
          || processos != g_processos || contido != g_contido || faltou != g_faltou )); then
      if printf '%s\n' "$(( agora_ms / 1000 )) $inicio $intervalo $gasto $cota $periodo $memoria $limite $processos $teto $contido $faltou" \
           > "$destino.novo" && mv -f "$destino.novo" "$destino"; then
        antes_ms=$agora_ms g_cpu=$cpu g_memoria=$memoria g_processos=$processos g_contido=$contido g_faltou=$faltou
        (( vezes < 2 )) && vezes=$(( vezes + 1 ))
      fi
    fi
    sleep 5
  done
}
if [[ -d /estado && -w /estado ]]; then
  ( set +Eeu; umask 077; publicar_recursos ) 2>/dev/null &
else
  echo "aviso: /estado ausente ou sem escrita: a aba Servidor do painel fica sem os recursos do nginx" >&2
fi
aviso_ip_publico >&2
aviso_proxy >&2
echo "nginx pronto em 8443/tcp (HTTPS), à frente do painel; redes permitidas: ${PAINEL_REDES_PERMITIDAS}; proxy ou túnel aceito: ${PAINEL_PROXY_CONFIAVEL:-nenhum}"
exec nginx -e stderr -c "$configuracao"
