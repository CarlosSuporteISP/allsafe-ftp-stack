#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa AD: bloqueio por endereço. O endereço que passa do limite de erros de usuário e senha deixa de entrar no
# FTP (com e sem TLS, em modo passivo e ativo) e no painel, com qualquer conta; a lista na web, a mudança de
# prazo, o desbloqueio, o terminal, o que nunca é bloqueado sozinho, o bloqueio desligado e as recusas.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.
#
# Pela porta publicada, todo cliente deste host chega ao FTP com o endereço de saída do container, que nunca é
# bloqueado sozinho. Para ter endereços de fora, a etapa liga duas redes ao container do FTP depois de ele
# subir: o vigia só conhece as redes da partida, então o gateway de cada uma (o host, falando direto com o
# endereço do container nela) é visto como endereço de fora. No painel, o endereço do cliente vem do proxy aceito.

# A parte sem TLS usa usuários dispensados do TLS, e a dispensa não vale com REDE_PERMITIR_IP_PUBLICO=sim: esta
# etapa desliga a opção de IP público e devolve ao final.
opcao_0="$(env_file="$ENVA" env_valor REDE_PERMITIR_IP_PUBLICO nao)"; redes_0="$(env_file="$ENVA" env_valor PAINEL_REDES_PERMITIDAS)"
gravar_env "$ENVA" REDE_PERMITIR_IP_PUBLICO nao
gravar_env "$ENVA" PAINEL_REDES_PERMITIDAS "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
dep; r_d0=$?
# O reinício do painel zera a contagem de falhas de entrada e das recusas e encerra as sessões.
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"

A30="$NOME-network-30a"; B30="$NOME-network-30b"; U30="$W/u30.jar"; S30="$W/s30.jar"; Z30="$W/z30.jar"; P30="$W/p30.jar"
erros_0="$(env_file="$ENVA" env_valor BLOQUEIO_ENDERECO_ERROS 5)"; horas_0="$(env_file="$ENVA" env_valor BLOQUEIO_ENDERECO_HORAS 24)"
dias_0="$(env_file="$ENVA" env_valor BLOQUEIO_ENDERECO_DIAS 120)"; proxy_0="$(env_file="$ENVA" env_valor PAINEL_PROXY_CONFIAVEL)"
ate30() { local fim=$((SECONDS + $1)); shift; until "$@"; do (( SECONDS < fim )) || return 1; sleep 0.2; done; }
na_rede30() { docker inspect -f "{{(index .NetworkSettings.Networks \"$1\").$2}}" "$FTP" 2>/dev/null; }  # <rede> <IPAddress|Gateway>
# Liga as duas redes ao container do FTP (de novo depois de cada deploy que o recria) e guarda por onde falar com
# ele em cada uma (FA, FB) e com que endereço o host chega por ela (GA, GB).
ligar30() {
  local rede
  for rede in "$A30" "$B30"; do docker network connect "$rede" "$FTP" > /dev/null 2>&1; done
  FA="ftp://$(na_rede30 "$A30" IPAddress):2121"; FB="ftp://$(na_rede30 "$B30" IPAddress):2121"
  GA="$(na_rede30 "$A30" Gateway)"; GB="$(na_rede30 "$B30" Gateway)"
}
# <base> <tls|puro> <usuário> <arquivo da senha> [opções do curl...] → "0 226" (entrou e listou) ou "67 530" (recusado)
tenta30() { local base="$1" modo="$2" r; shift 2; r="$(ESPERA_PURO=25 ftp_curl "$modo" "$1" "$2" "${@:3}" -l "$base/")"; echo "$r $(resposta '(226|421|530) ' | cut -c1-3)"; }
erra30() { tenta30 "$1" "$2" "$3" "$W/errada30.senha" "${@:4}"; }                         # <base> <tls|puro> <usuário> [opções]: senha errada
preso30() { docker exec "$FTP" test -f "/auth/enderecos/$1"; }                             # <endereço>: tem bloqueio gravado
solto30() { ! preso30 "$1"; }
conteudo30() { docker exec "$FTP" sh -c "cat '/auth/enderecos/$1' 2>/dev/null" | tr '\n' ' '; }  # <endereço> → "<vale até> <desde> <erros> <quem> "
prazo30() { local a b _; read -r a b _ <<< "$(conteudo30 "$1")"; [[ "$a" =~ ^[0-9]+$ && "$b" =~ ^[0-9]+$ ]] && echo $((a - b)) || echo '?'; }  # segundos entre o bloqueio e o fim
resta30() { local a _; read -r a _ <<< "$(conteudo30 "$1")"; [[ "$a" =~ ^[0-9]+$ ]] && echo $(( (a - $(date +%s) + 43200) / 86400 )) || echo '?'; }  # dias que faltam, arredondados
quem30() { local _ n q; read -r _ _ n q _ <<< "$(conteudo30 "$1")"; echo "${n:-?} ${q:-?}"; }  # <endereço> → "<erros> <quem>"
pasta30() { docker exec "$FTP" sh -c 'ls -A /auth/enderecos 2>/dev/null' | sort | tr '\n' ' '; }  # endereços com arquivo de bloqueio
dono30() { docker exec "$FTP" stat -c '%U:%G %a' "$@" 2>&1 | tr '\n' ' '; }
vigia30() { docker logs "$FTP" 2>&1 | grep -c -F -- "$1"; }                                # <trecho>: linhas do registro do container do FTP
# <trecho>: linhas do registro desde a última subida do container do FTP (o registro atravessa os reinícios)
partida30() { docker logs --since "$(docker inspect -f '{{.State.StartedAt}}' "$FTP")" "$FTP" 2>&1 | grep -c -F -- "$1"; }
# [opções do curl...] → código HTTP de uma entrada no painel com a senha errada do administrador
errar30() {
  local formulario
  formulario="$(c -c "$P30" "$@" "$B/entrar" | sed -n 's/.*name="token" value="\([^"]*\)".*/\1/p')"
  c -o /dev/null -w '%{http_code}' -b "$P30" -H "Origin: $B" "$@" --data-urlencode "token=$formulario" \
    --data-urlencode "usuario=$ADMIN" --data-urlencode "senha@$W/errada30.senha" "$B/entrar"
}
ver30() { c -o "$W/corpo" -w '%{http_code}' -H "X-Forwarded-For: $1" "$B$2"; }               # <endereço do cliente> <caminho> → código HTTP
de30() { auditoria; grep -o 'ip=[^ ]* evento=entrada_[a-z]*' "$W/auditoria" | tail -1 | sed -e 's/^ip=//' -e 's/ evento=.*//'; }  # endereço da última entrada na auditoria
prazo_web30() { envio /bloqueios/prazo --data-urlencode "csrf=$K" --data-urlencode "ip=$1" --data-urlencode "dias=$2"; }  # <endereço> <dias> → "código destino"
liberar_web30() { envio /bloqueios/liberar --data-urlencode "csrf=$K" --data-urlencode "ip=$1"; }                          # <endereço> → "código destino"
tem30() { grep -c -F -- "$1" "$W/corpo"; }                                                 # <trecho>: linhas da última tela com ele
PARTIDA30='pronto: endereço com mais de %s erros de usuário e senha em %s h fica bloqueado por %s dias, no FTP e no painel'
TEXTO30='endereço bloqueado por excesso de erros de usuário e senha'

for n in end30 st30a st30b errada30 adm30; do nova_senha "$W/$n.senha"; done
mu add end30 "$W/end30.senha" bloqueio30/a; r_u1=$?
mu add st30a "$W/st30a.senha" bloqueio30/b; r_u2=$?
mu add st30b "$W/st30b.senha" bloqueio30/c; r_u3=$?
# Os dois equipamentos sem TLS: com dispensado na lista, o FTP troca o modo de entrada em até 2 s.
mu tls-dispensar st30a; r_t1=$?; mu tls-dispensar st30b; r_t2=$?
puro30() { [[ "$(tenta30 "$F" puro st30a "$W/st30a.senha")" == "0 226" ]]; }
ate30 20 puro30; r_puro=$?
docker network create --subnet "${TESTE_SUBNET_C:-172.29.3.8/29}" "$A30" > /dev/null 2>&1; r_ra=$?
docker network create --subnet "${TESTE_SUBNET_D:-172.29.3.16/29}" "$B30" > /dev/null 2>&1; r_rb=$?
ligar30
GP="$(na_rede30 "$NOME-network" Gateway)"   # por ele chegam os clientes deste host pela porta publicada

# ------------------------------------------------------------------ FTP com TLS: o sexto erro bloqueia o endereço
partida_0="$(partida30 "$(printf "$PARTIDA30" "$erros_0" "$horas_0" "$dias_0")")"; pasta_0="$(dono30 /auth/enderecos)"; vazia_0="$(pasta30)"
antes_p="$(tenta30 "$FA" tls end30 "$W/end30.senha")"; antes_a="$(tenta30 "$FA" tls end30 "$W/end30.senha" --ftp-port -)"
ev=""
for n in 1 2; do ev+="$(erra30 "$FA" tls end30); "; done
for n in 1 2 3; do ev+="$(erra30 "$FA" tls "fantasma30$n"); "; done
sleep 2   # o vigia lê o registro do servidor: dá tempo de o quinto erro ser contado
cinco_arq="$(pasta30)"; cinco_certa="$(tenta30 "$FA" tls end30 "$W/end30.senha")"
sexto="$(erra30 "$FA" tls fantasma304)"
ate30 10 preso30 "$GA"; r_preso=$?
arq_a="$(dono30 "/auth/enderecos/$GA")"; quem_a="$(quem30 "$GA")"; prazo_a="$(prazo30 "$GA")"
log_a="$(vigia30 "endereço bloqueado: origem=$GA erros=6 dias=$dias_0")"
dep_p="$(tenta30 "$FA" tls end30 "$W/end30.senha")"; dep_a="$(tenta30 "$FA" tls end30 "$W/end30.senha" --ftp-port -)"
dep_outro="$(tenta30 "$FA" tls st30a "$W/st30a.senha")"
log_rec="$(vigia30 "entrada recusada pelo bloqueio do endereço: origem=$GA")"
de_b="$(tenta30 "$FB" tls end30 "$W/end30.senha")"; do_host="$(tenta30 "$F" tls end30 "$W/end30.senha")"
[[ "$r_d0" == 0 && "$e_adm" == 303 && -n "$K" && "$r_u1$r_u2$r_u3$r_t1$r_t2$r_puro$r_ra$r_rb" == 00000000 && -n "$GA" && -n "$GB" && "$GA" != "$GB" && -n "$GP" \
  && "$erros_0 $horas_0 $dias_0" == "5 24 120" && "$partida_0" == 1 && "$pasta_0" == "root:root 700 " && -z "$vazia_0" \
  && "$antes_p" == "0 226" && "$antes_a" == "0 226" && "$ev" == "67 530; 67 530; 67 530; 67 530; 67 530; " && -z "$cinco_arq" && "$cinco_certa" == "0 226" \
  && "$sexto" == "67 530" && "$r_preso" == 0 && "$arq_a" == "root:root 600 " && "$quem_a" == "6 ftp" && "$prazo_a" == 10368000 && "$log_a" == 1 \
  && "$dep_p" == "67 530" && "$dep_a" == "67 530" && "$dep_outro" == "67 530" && "$log_rec" -ge 1 && "$de_b" == "0 226" && "$do_host" == "0 226" ]]
caso $? seguranca 106 "Bloqueio por endereço no FTP com TLS: o sexto erro bloqueia por 120 dias" "instância com REDE_PERMITIR_IP_PUBLICO=nao durante a etapa (deploy.sh: saída $r_d0), para a dispensa do TLS valer; padrão da stack: BLOQUEIO_ENDERECO_ERROS=$erros_0, BLOQUEIO_ENDERECO_HORAS=$horas_0, BLOQUEIO_ENDERECO_DIAS=$dias_0; linha de partida do vigia com a regra: $partida_0; /auth/enderecos: ${pasta_0}e vazia · endereço $GA (rede ligada ao FTP depois da partida), com TLS: senha certa em modo passivo $antes_p e em modo ativo $antes_a · duas senhas erradas do usuário end30 e três nomes que não existem: ${ev}arquivos de bloqueio depois dos cinco erros: '${cinco_arq}', e a senha certa ainda entra: $cinco_certa · sexto erro: $sexto; arquivo /auth/enderecos/$GA: ${arq_a}com erros e autor '$quem_a' e prazo de $prazo_a s (120 dias = 10368000); registro do FTP com 'endereço bloqueado: origem=$GA erros=6 dias=$dias_0': $log_a · do endereço bloqueado, a senha certa em modo passivo: $dep_p, em modo ativo: $dep_a, e a senha certa de outro usuário: $dep_outro; registro com 'entrada recusada pelo bloqueio do endereço': $log_rec · a mesma conta de outro endereço ($GB): $de_b, e pela porta publicada: $do_host"

# ------------------------------------------------------------------ FTP sem TLS: a mesma regra
antes_s="$(tenta30 "$FB" puro st30a "$W/st30a.senha")"; antes_sa="$(tenta30 "$FB" puro st30a "$W/st30a.senha" --ftp-port -)"
ev=""
for n in 1 2 3; do ev+="$(erra30 "$FB" puro st30a); "; done
for n in 1 2; do ev+="$(erra30 "$FB" puro st30b); "; done
# Usuário que não é dispensado, sem TLS: o porteiro recusa antes de a senha ser conferida, e isso não é erro de senha.
sem_tls="$(tenta30 "$FB" puro end30 "$W/end30.senha")"
sleep 2
cinco_b="$(solto30 "$GB" && echo nenhum || echo gravado)"; cinco_certa_b="$(tenta30 "$FB" puro st30a "$W/st30a.senha")"
sexto_b="$(erra30 "$FB" puro st30b)"
ate30 10 preso30 "$GB"; r_preso_b=$?
quem_b="$(quem30 "$GB")"; prazo_b="$(prazo30 "$GB")"
dep_s="$(tenta30 "$FB" puro st30a "$W/st30a.senha")"; dep_sa="$(tenta30 "$FB" puro st30a "$W/st30a.senha" --ftp-port -)"; dep_st="$(tenta30 "$FB" tls end30 "$W/end30.senha")"
host_s="$(tenta30 "$F" puro st30a "$W/st30a.senha")"; pasta_2="$(pasta30)"
[[ "$antes_s" == "0 226" && "$antes_sa" == "0 226" && "$ev" == "67 530; 67 530; 67 530; 67 530; 67 530; " && "$sem_tls" == "67 530" && "$cinco_b" == nenhum \
  && "$cinco_certa_b" == "0 226" && "$sexto_b" == "67 530" && "$r_preso_b" == 0 && "$quem_b" == "6 ftp" && "$prazo_b" == 10368000 \
  && "$dep_s" == "67 530" && "$dep_sa" == "67 530" && "$dep_st" == "67 530" && "$host_s" == "0 226" \
  && "$pasta_2" == "$(printf '%s\n' "$GA" "$GB" | sort | tr '\n' ' ')" ]]
caso $? seguranca 107 "Bloqueio por endereço no FTP sem TLS, em modo passivo e ativo" "endereço $GB, sem TLS, com os usuários dispensados st30a e st30b: senha certa em modo passivo $antes_s e em modo ativo $antes_sa · três senhas erradas de st30a e duas de st30b: ${ev}e uma entrada sem TLS de usuário que não é dispensado (recusada antes de a senha ser conferida, não conta): $sem_tls; bloqueio depois disso: $cinco_b, e a senha certa ainda entra: $cinco_certa_b · sexto erro: $sexto_b; arquivo do endereço com erros e autor '$quem_b' e prazo de $prazo_b s · do endereço bloqueado, senha certa sem TLS em modo passivo: $dep_s, em modo ativo: $dep_sa, e com TLS: $dep_st · o mesmo usuário pela porta publicada: $host_s · endereços bloqueados: $pasta_2"

# ------------------------------------------------------------------ quem nunca é bloqueado sozinho
interno_0="$(vigia30 '(rede interna da stack: não conta para o bloqueio)')"
ev=""
for n in 1 2 3 4 5 6 7; do ev+="$(erra30 "$F" tls "fantasma30h$n"); "; done
sleep 2
host_arq="$(solto30 "$GP" && echo nenhum || echo gravado)"; host_certa="$(tenta30 "$F" tls end30 "$W/end30.senha")"
# Senha errada de usuário do FTP na entrada do painel: quem pergunta ao FTP é o painel, de dentro da rede da stack.
p_1="$(COMO=end30 entrar "$U30" "$W/errada30.senha")"; p_2="$(COMO=end30 entrar "$U30" "$W/errada30.senha")"
sleep 2
interno_1="$(vigia30 '(rede interna da stack: não conta para o bloqueio)')"; pasta_3="$(pasta30)"
[[ "$ev" == "67 530; 67 530; 67 530; 67 530; 67 530; 67 530; 67 530; " && "$host_arq" == nenhum && "$host_certa" == "0 226" \
  && "$p_1" == 401 && "$p_2" == 401 && $((interno_1 - interno_0)) -ge 2 && "$pasta_3" == "$pasta_2" ]]
caso $? seguranca 108 "Endereço de saída do container e rede interna da stack não são bloqueados sozinhos" "sete nomes que não existem pela porta publicada (o FTP vê o endereço de saída do container, $GP, que é o de todo cliente deste host): ${ev}bloqueio de $GP: $host_arq, e a senha certa segue entrando: $host_certa · duas entradas no painel com a senha errada de um usuário do FTP (a conferência vem do container do painel): $p_1 e $p_2; linhas '(rede interna da stack: não conta para o bloqueio)' a mais no registro do FTP: $((interno_1 - interno_0)) · endereços bloqueados antes: ${pasta_2}· depois: $pasta_3"

# ------------------------------------------------------------------ a lista na web: acompanhar, mudar o prazo e desbloquear
auditoria; n_prazo="$(eventos endereco_prazo)"; n_solto="$(eventos endereco_desbloqueado)"
t_lista="$(aba -b "$J" "$B/bloqueios")"
l_a="$(tem30 "<td class=\"origem\"><strong><code>$GA</code></strong></td><td data-rotulo=\"Bloqueado por\">6 erros no FTP</td>")"; l_b="$(tem30 "<td class=\"origem\"><strong><code>$GB</code></strong></td><td data-rotulo=\"Bloqueado por\">6 erros no FTP</td>")"
l_regra="$(tem30 'O endereço que passa de 5 erros de usuário e senha em 24 horas, no FTP ou no painel, fica 120 dias sem entrar nos dois.')"
l_total="$(tem30 'Agora: 2 endereços bloqueados.')"; l_menu="$(tem30 'href="/bloqueios"')"
t_um="$(aba -b "$J" "$B/bloqueios/endereco?ip=$GA")"
u_titulo="$(tem30 "Bloqueio de <code>$GA</code>")"; u_dias="$(tem30 'name="dias" type="number" min="1" max="3650" step="1" required value="120"')"
u_autor="$(tem30 'Bloqueado por <strong>FTP</strong>, com 6 erros de usuário e senha')"; u_liberar="$(tem30 'action="/bloqueios/liberar"')"
t_nao="$(aba -b "$J" "$B/bloqueios/endereco?ip=203.0.113.200")"
desde_a="$(conteudo30 "$GA" | cut -d' ' -f2)"
r_prazo="$(prazo_web30 "$GA" 200)"; resta_a="$(resta30 "$GA")"; quem_a2="$(quem30 "$GA")"; desde_a2="$(conteudo30 "$GA" | cut -d' ' -f2)"
t_prazo="$(aba -b "$J" "$B/bloqueios?m=prazo")"; m_prazo="$(tem30 'Prazo do bloqueio alterado.')"
r_solto="$(liberar_web30 "$GB")"; solto_b="$(solto30 "$GB" && echo sim || echo nao)"; volta_b="$(tenta30 "$FB" tls end30 "$W/end30.senha")"; volta_bs="$(tenta30 "$FB" puro st30a "$W/st30a.senha")"
t_solto="$(aba -b "$J" "$B/bloqueios?m=liberado")"; m_solto="$(tem30 'Endereço liberado: ele volta a entrar no FTP e no painel.')"; m_total="$(tem30 'Agora: 1 endereço bloqueado.')"; m_b="$(tem30 "<code>$GB</code>")"
r_denovo="$(liberar_web30 "$GB")"
auditoria
a_prazo="$(grep -c " evento=endereco_prazo admin=$ADMIN endereco=$GA dias=200\$" "$W/auditoria")"; a_solto="$(grep -c " evento=endereco_desbloqueado admin=$ADMIN endereco=$GB\$" "$W/auditoria")"
d_prazo=$(( $(eventos endereco_prazo) - n_prazo )); d_solto=$(( $(eventos endereco_desbloqueado) - n_solto ))
t_seg="$(aba -b "$J" "$B/seguranca")"; s_linha="$(tem30 'Bloqueio por endereço')"; s_agora="$(tem30 '<a href="/bloqueios">1 endereço bloqueado agora</a>')"
t_ativ="$(aba -b "$J" "$B/atividade")"; v_prazo="$(tem30 'Prazo do bloqueio de endereço alterado')"; v_solto="$(tem30 'Endereço desbloqueado')"
[[ "$t_lista" == "200 " && "$l_a" == 1 && "$l_b" == 1 && "$l_regra" == 1 && "$l_total" == 1 && "$l_menu" -ge 1 \
  && "$t_um" == "200 " && "$u_titulo" == 1 && "$u_dias" == 1 && "$u_autor" == 1 && "$u_liberar" == 1 && "$t_nao" == "303 /bloqueios?m=ausente" \
  && "$r_prazo" == "303 /bloqueios?m=prazo" && "$resta_a" == 200 && "$quem_a2" == "6 ftp" && -n "$desde_a" && "$desde_a2" == "$desde_a" && "$t_prazo" == "200 " && "$m_prazo" == 1 \
  && "$r_solto" == "303 /bloqueios?m=liberado" && "$solto_b" == sim && "$volta_b" == "0 226" && "$volta_bs" == "0 226" && "$t_solto" == "200 " && "$m_solto" == 1 && "$m_total" == 1 && "$m_b" == 0 \
  && "$r_denovo" == "303 /bloqueios?m=ausente" && "$a_prazo" == 1 && "$a_solto" == 1 && "$d_prazo" == 1 && "$d_solto" == 1 \
  && "$t_seg" == "200 " && "$s_linha" -ge 1 && "$s_agora" == 1 && "$t_ativ" == "200 " && "$v_prazo" -ge 1 && "$v_solto" -ge 1 ]]
caso $? testes 61 "Aba Bloqueios: lista dos endereços, mudança de prazo e desbloqueio" "GET /bloqueios: $t_lista, linha de $GA (FTP, 6 erros): $l_a, linha de $GB: $l_b, a regra em vigor escrita: $l_regra, 'Agora: 2 endereços bloqueados.': $l_total, item no menu: $l_menu · tela do endereço $GA: $t_um, com o título: $u_titulo, o campo dos dias com o prazo da stack (120): $u_dias, quem bloqueou e com quantos erros: $u_autor, e o formulário de desbloqueio: $u_liberar; a de um endereço que não está bloqueado: $t_nao · prazo de $GA mudado para 200 dias: $r_prazo; dias que faltam no arquivo: $resta_a, erros e autor mantidos: '$quem_a2', início mantido: $([[ "$desde_a2" == "$desde_a" ]] && echo sim || echo NÃO); aviso na tela: $m_prazo · $GB desbloqueado: $r_solto; arquivo removido: $solto_b; no pedido seguinte ele entra no FTP com TLS: $volta_b e sem TLS: $volta_bs; aviso na tela: $m_solto, 'Agora: 1 endereço bloqueado.': $m_total, linhas com $GB: $m_b; desbloquear de novo: $r_denovo · auditoria: endereco_prazo com o administrador, o endereço e os dias: $a_prazo, endereco_desbloqueado: $a_solto · aba Segurança: $t_seg, linha 'Bloqueio por endereço': $s_linha, com o total e o atalho para a lista: $s_agora · aba Atividade: $t_ativ, 'Prazo do bloqueio de endereço alterado': $v_prazo, 'Endereço desbloqueado': $v_solto"

# ------------------------------------------------------------------ o terminal: listar, bloquear, mudar o prazo e liberar
mu enderecos; r_l1=$?; x_lista="$(grep -c "^origem=$GA por=ftp erros=6 desde=" "$W/mu.log")"; x_so="$(grep -c '^origem=' "$W/mu.log")"
mu endereco-bloquear 203.0.113.9 "" 30; r_m1=$?; x_m1="$(grep -c -x 'Endereco 203.0.113.9 bloqueado: 30 dia(s) a partir de agora, no FTP e no painel.' "$W/mu.log")"
arq_m="$(dono30 /auth/enderecos/203.0.113.9)"; quem_m="$(quem30 203.0.113.9)"; prazo_m="$(prazo30 203.0.113.9)"
mu endereco-bloquear 203.0.113.9 "" 45; r_m2=$?; x_m2="$(grep -c -x 'Prazo do endereco 203.0.113.9 alterado: 45 dia(s) a partir de agora, no FTP e no painel.' "$W/mu.log")"; resta_m="$(resta30 203.0.113.9)"
mu endereco-bloquear 203.0.113.10; r_m3=$?; x_m3="$(grep -c -x 'Endereco 203.0.113.10 bloqueado: 120 dia(s) a partir de agora, no FTP e no painel.' "$W/mu.log")"
sleep 5   # a lista da aba é relida a cada 5 s
t_manual="$(aba -b "$J" "$B/bloqueios")"; w_manual="$(tem30 '<td class="origem"><strong><code>203.0.113.9</code></strong></td><td data-rotulo="Bloqueado por">Administrador</td>')"
# O bloqueio feito à mão vale para qualquer endereço de fora do servidor, na hora, e a liberação também.
mu endereco-bloquear "$GB" "" 1; r_m4=$?; preso_t="$(tenta30 "$FB" tls end30 "$W/end30.senha")"; preso_ts="$(tenta30 "$FB" puro st30a "$W/st30a.senha" --ftp-port -)"
mu endereco-liberar "$GB"; r_m5=$?; x_m5="$(grep -c -x "Endereco $GB liberado: vale no proximo pedido." "$W/mu.log")"; solto_t="$(tenta30 "$FB" tls end30 "$W/end30.senha")"
mu endereco-liberar "$GB"; r_m6=$?; x_m6="$(grep -c -x "Endereco $GB nao esta bloqueado." "$W/mu.log")"
pasta_4="$(pasta30)"; ev=""; ok=0
for v in 127.0.0.1 0.1.2.3; do
  mu endereco-bloquear "$v" "" 5; r=$?; [[ "$r" != 0 && "$(grep -c '^Endereco nao bloqueavel' "$W/mu.log")" == 1 ]] || ok=1; ev+="$v: saída $r; "
done
for v in 1.2.3 01.2.3.4 256.1.1.1 '../x' '1.2.3.4;id' '2001:db8::1'; do
  mu endereco-bloquear "$v" "" 5; r=$?; [[ "$r" != 0 && "$(grep -c '^Endereco invalido' "$W/mu.log")" == 1 ]] || ok=1; ev+="$v: saída $r; "
  mu endereco-liberar "$v"; r=$?; [[ "$r" != 0 ]] || ok=1
done
for v in 0 3651 abc -5 1.5; do
  mu endereco-bloquear 203.0.113.11 "" "$v"; r=$?; [[ "$r" != 0 && "$(grep -c '^Prazo invalido: de 1 a 3650 dias' "$W/mu.log")" == 1 ]] || ok=1; ev+="dias=$v: saída $r; "
done
pasta_5="$(pasta30)"
mu endereco-liberar 203.0.113.9; r_m7=$?; mu endereco-liberar 203.0.113.10; r_m8=$?; pasta_6="$(pasta30)"
[[ "$r_l1" == 0 && "$x_lista" == 1 && "$x_so" == 1 && "$r_m1" == 0 && "$x_m1" == 1 && "$arq_m" == "root:root 600 " && "$quem_m" == "0 manual" && "$prazo_m" == 2592000 \
  && "$r_m2" == 0 && "$x_m2" == 1 && "$resta_m" == 45 && "$r_m3" == 0 && "$x_m3" == 1 && "$t_manual" == "200 " && "$w_manual" == 1 \
  && "$r_m4" == 0 && "$preso_t" == "67 530" && "$preso_ts" == "67 530" && "$r_m5" == 0 && "$x_m5" == 1 && "$solto_t" == "0 226" && "$r_m6" == 0 && "$x_m6" == 1 \
  && "$ok" == 0 && "$pasta_5" == "$pasta_4" && "$r_m7" == 0 && "$r_m8" == 0 && "$pasta_6" == "$GA " ]]
caso $? testes 62 "Bloqueio por endereço pelo terminal: listar, bloquear, mudar o prazo e liberar" "manage-user.sh enderecos: saída $r_l1, linha de $GA (por=ftp erros=6): $x_lista, de $x_so · endereco-bloquear 203.0.113.9 30: saída $r_m1, mensagem: $x_m1, arquivo ${arq_m}com erros e autor '$quem_m' e prazo de $prazo_m s (30 dias = 2592000); de novo com 45: saída $r_m2, 'Prazo ... alterado': $x_m2, dias que faltam: $resta_m; sem os dias (vale o prazo da stack, 120): saída $r_m3, mensagem: $x_m3 · na aba Bloqueios: $t_manual, linha de 203.0.113.9 por Administrador: $w_manual · $GB bloqueado pelo terminal: saída $r_m4; a senha certa dele com TLS: $preso_t e sem TLS em modo ativo: $preso_ts; endereco-liberar: saída $r_m5, mensagem: $x_m5, e ele entra: $solto_t; liberar de novo: saída $r_m6, 'nao esta bloqueado': $x_m6 · fora da regra, todos recusados com a mensagem própria: ${ev}pasta dos bloqueios igual à de antes: $([[ "$pasta_5" == "$pasta_4" ]] && echo sim || echo NÃO) · no fim, com os endereços de exemplo liberados: $pasta_6"

# ------------------------------------------------------------------ a tela é do administrador: recusas
intacto="$(conteudo30 "$GA")"; auditoria; n_papel="$(eventos recusa_papel)"; c_antes="$(eventos recusa_csrf)"; o_antes="$(eventos recusa_origem)"; n_prazo="$(eventos endereco_prazo)"; n_solto="$(eventos endereco_desbloqueado)"
campos=(--data-urlencode "ip=$GA")
r_sem="$(aba "$B/bloqueios")"; r_sem_um="$(aba "$B/bloqueios/endereco?ip=$GA")"
r_sem_post="$(c -o /dev/null -w '%{http_code} %{redirect_url}' -H "Origin: $B" --data-urlencode "csrf=$K" "${campos[@]}" "$B/bloqueios/liberar" | sed "s|$B||")"
r_falso="$(c -o /dev/null -w '%{http_code} %{redirect_url}' -b '__Host-sessao=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' -H "Origin: $B" --data-urlencode "csrf=$K" "${campos[@]}" "$B/bloqueios/liberar" | sed "s|$B||")"
r_token="$(envio /bloqueios/liberar "${campos[@]}")"; r_token_p="$(envio /bloqueios/prazo "${campos[@]}" --data-urlencode 'dias=1')"
r_errado="$(envio /bloqueios/liberar --data-urlencode 'csrf=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' "${campos[@]}")"
r_origem="$(c -o /dev/null -w '%{http_code}' -b "$J" -H 'Origin: https://site-de-fora.example' --data-urlencode "csrf=$K" "${campos[@]}" "$B/bloqueios/liberar")"
r_get="$(aba -b "$J" "$B/bloqueios/liberar?ip=$GA")"; r_get_p="$(aba -b "$J" "$B/bloqueios/prazo?ip=$GA&dias=1")"
# Com a sessão de um usuário do FTP (perfil Completo): as rotas dos bloqueios não existem para ele.
e_usu="$(COMO=end30 entrar "$U30" "$W/end30.senha")"; proibir "$(biscoito_de "$U30")"
UK="$(c -b "$U30" "$B/meus-arquivos" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1)"; proibir "$UK"
r_usu="$(aba -b "$U30" "$B/bloqueios")"; r_usu_um="$(aba -b "$U30" "$B/bloqueios/endereco?ip=$GA")"
r_usu_l="$(POTE="$U30" envio /bloqueios/liberar --data-urlencode "csrf=$UK" "${campos[@]}")"
r_usu_p="$(POTE="$U30" envio /bloqueios/prazo --data-urlencode "csrf=$UK" "${campos[@]}" --data-urlencode 'dias=1')"
u_menu="$(c -b "$U30" "$B/meus-arquivos" | grep -c 'href="/bloqueios"')"
ev=""; ok=0
for v in 0 3651 abc -5 1.5 1e2 0x10 '１' 12345 ''; do
  r="$(prazo_web30 "$GA" "$v")"; [[ "$r" == "400 " ]] || ok=1; ev+="dias='$v': $r; "
done
for v in 203.0.113.200 999.1.1.1 127.0.0.1 '../x' "$GA/" ''; do
  r="$(prazo_web30 "$v" 5)"; s="$(liberar_web30 "$v")"
  [[ "$r" == "303 /bloqueios?m=ausente" && "$s" == "303 /bloqueios?m=ausente" ]] || ok=1; ev+="ip='$v': $r e $s; "
done
auditoria
d_papel=$(( $(eventos recusa_papel) - n_papel )); a_papel="$(grep -c " evento=recusa_papel usuario=end30 caminho=/bloqueios perfil=completo\$" "$W/auditoria")"
d_csrf=$(( $(eventos recusa_csrf) - c_antes )); d_origem=$(( $(eventos recusa_origem) - o_antes ))
d_prazo=$(( $(eventos endereco_prazo) - n_prazo )); d_solto=$(( $(eventos endereco_desbloqueado) - n_solto ))
[[ "$r_sem" == "303 /entrar" && "$r_sem_um" == "303 /entrar" && "$r_sem_post" == "303 /entrar" && "$r_falso" == "303 /entrar" && "$r_token" == "403 " && "$r_token_p" == "403 " \
  && "$r_errado" == "403 " && "$r_origem" == 403 && "$r_get" == "404 " && "$r_get_p" == "404 " && "$e_usu" == 303 && -n "$UK" \
  && "$r_usu" == "404 " && "$r_usu_um" == "404 " && "$r_usu_l" == "404 " && "$r_usu_p" == "404 " && "$u_menu" == 0 && "$ok" == 0 \
  && "$d_papel" -ge 1 && "$a_papel" -ge 1 && "$d_csrf" -ge 1 && "$d_origem" -ge 1 && "$d_prazo" == 0 && "$d_solto" == 0 && -n "$intacto" && "$(conteudo30 "$GA")" == "$intacto" ]]
caso $? seguranca 109 "Aba Bloqueios só para administrador, com token, e prazo dentro da regra" "sem sessão: lista $r_sem, tela do endereço $r_sem_um, desbloqueio $r_sem_post; com cookie inventado: $r_falso · com a sessão do administrador: sem token no desbloqueio $r_token e no prazo $r_token_p, com token errado $r_errado, com Origin de outro site $r_origem, GET nas rotas de envio: $r_get e $r_get_p · com a sessão e o token de um usuário do FTP (entrada: $e_usu): lista $r_usu, tela do endereço $r_usu_um, desbloqueio $r_usu_l, prazo $r_usu_p; item Bloqueios no menu dele: $u_menu · fora da regra, com a sessão do administrador: ${ev}· auditoria: recusa_papel a mais: $d_papel (com o usuário, o caminho e o perfil: $a_papel), recusa_csrf a mais: $d_csrf, recusa_origem a mais: $d_origem, endereco_prazo a mais: $d_prazo, endereco_desbloqueado a mais: $d_solto · arquivo do bloqueio de $GA igual ao de antes: $([[ "$(conteudo30 "$GA")" == "$intacto" ]] && echo sim || echo NÃO)"

# ------------------------------------------------------------------ recusas de configuração, antes de mexer em qualquer coisa
rec_e1="$(recusa_deploy BLOQUEIO_ENDERECO_ERROS=101)"; rec_e2="$(recusa_deploy BLOQUEIO_ENDERECO_ERROS=-1)"; rec_e3="$(recusa_deploy BLOQUEIO_ENDERECO_ERROS=abc)"
rec_h1="$(recusa_deploy BLOQUEIO_ENDERECO_HORAS=0)"; rec_h2="$(recusa_deploy BLOQUEIO_ENDERECO_HORAS=721)"
rec_d1="$(recusa_deploy BLOQUEIO_ENDERECO_DIAS=0)"; rec_d2="$(recusa_deploy BLOQUEIO_ENDERECO_DIAS=3651)"
rec_cf1="$(recusa_container ftp BLOQUEIO_ENDERECO_ERROS=101)"; rec_cf2="$(recusa_container ftp BLOQUEIO_ENDERECO_HORAS=0)"; rec_cf3="$(recusa_container ftp BLOQUEIO_ENDERECO_DIAS=3651)"
rec_cp1="$(recusa_container painel BLOQUEIO_ENDERECO_ERROS=abc)"; rec_cp2="$(recusa_container painel BLOQUEIO_ENDERECO_HORAS=721)"; rec_cp3="$(recusa_container painel BLOQUEIO_ENDERECO_DIAS=0)"

# ------------------------------------------------------------------ painel: o endereço que o proxy aceito informa
# Com o padrão (5), o limite curto da entrada (cinco falhas, 15 minutos de espera) chega antes do sexto erro. A
# bateria prova o painel com o limite em 3: o quarto erro bloqueia. O prazo vai para 2 dias e a janela, para 1 hora.
mu endereco-liberar "$GA"; r_limpa=$?
origem30="$(de30)"
gravar_env "$ENVA" PAINEL_PROXY_CONFIAVEL "$origem30"
gravar_env "$ENVA" BLOQUEIO_ENDERECO_ERROS 3; gravar_env "$ENVA" BLOQUEIO_ENDERECO_HORAS 1; gravar_env "$ENVA" BLOQUEIO_ENDERECO_DIAS 2
dep; r_d2=$?
saude_2="$(saude "$FTP" "$PAINEL" "$NGINX")"; ligar30; partida_2="$(partida30 "$(printf "$PARTIDA30" 3 1 2)")"
e_adm2="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
X=198.51.100.60; Y=198.51.100.61; Z=198.51.100.62
auditoria; n_rec="$(grep -c "ip=$X evento=recusa_endereco" "$W/auditoria")"
antes_x="$(ver30 "$X" /entrar)"
ev=""; for n in 1 2 3; do ev+="$(errar30 -H "X-Forwarded-For: $X") "; done
tres_x="$(solto30 "$X" && echo nenhum || echo gravado)"; ainda_x="$(ver30 "$X" /entrar)"
quarta_x="$(errar30 -H "X-Forwarded-For: $X")"
ate30 10 preso30 "$X"; r_preso_x=$?
arq_x="$(dono30 "/auth/enderecos/$X")"; quem_x="$(quem30 "$X")"; prazo_x="$(prazo30 "$X")"
dep_x="$(ver30 "$X" /entrar)"; texto_x="$(tem30 "$TEXTO30")"; saude_x="$(ver30 "$X" /saude)"
certa_x="$(entrar "$S30" "$W/painel.senha" -H "X-Forwarded-For: $X")"
outro_y="$(ver30 "$Y" /entrar)"; certa_y="$(entrar "$S30" "$W/painel.senha" -H "X-Forwarded-For: $Y")"; proibir "$(biscoito_de "$S30")"
auditoria
a_bloq="$(grep -c "ip=$X evento=endereco_bloqueado erros=4 dias=2\$" "$W/auditoria")"; a_rec=$(( $(grep -c "ip=$X evento=recusa_endereco" "$W/auditoria") - n_rec ))
t_painel="$(aba -b "$J" "$B/bloqueios")"; w_x="$(tem30 "<td class=\"origem\"><strong><code>$X</code></strong></td><td data-rotulo=\"Bloqueado por\">4 erros no painel</td>")"
w_regra="$(tem30 'O endereço que passa de 3 erros de usuário e senha em 1 hora, no FTP ou no painel, fica 2 dias sem entrar nos dois.')"
# Sem o cabeçalho, o endereço é o do próprio proxy aceito, atrás do qual estão todos os visitantes: nunca é bloqueado sozinho.
ev_p=""; for n in 1 2 3 4; do ev_p+="$(errar30) "; done
proxy_arq="$(solto30 "$origem30" && echo nenhum || echo gravado)"; proxy_ok="$(aba -b "$J" "$B/usuarios")"
# Sessão aberta e confirmação por senha: três entradas erradas e uma confirmação errada do mesmo endereço.
certa_z="$(entrar "$Z30" "$W/painel.senha" -H "X-Forwarded-For: $Z")"; proibir "$(biscoito_de "$Z30")"
KZ="$(c -b "$Z30" -H "X-Forwarded-For: $Z" "$B/usuarios/novo" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1)"; proibir "$KZ"
aberta_z="$(aba -b "$Z30" -H "X-Forwarded-For: $Z" "$B/usuarios")"
ev_z=""; for n in 1 2 3; do ev_z+="$(errar30 -H "X-Forwarded-For: $Z") "; done
conf_z="$(c -o /dev/null -w '%{http_code}' -b "$Z30" -H "Origin: $B" -H "X-Forwarded-For: $Z" --data-urlencode "csrf=$KZ" --data-urlencode 'perfil=administrador' \
  --data-urlencode 'usuario=adm30' --data-urlencode "senha@$W/adm30.senha" --data-urlencode "confirmacao@$W/adm30.senha" --data-urlencode "senha_atual@$W/errada30.senha" "$B/usuarios/novo")"
ate30 10 preso30 "$Z"; r_preso_z=$?
quem_z="$(quem30 "$Z")"; fechada_z="$(aba -b "$Z30" -H "X-Forwarded-For: $Z" "$B/usuarios")"; criado_z="$(admins | grep -c -w adm30)"
r_solto_z="$(liberar_web30 "$Z")"; volta_z="$(aba -b "$Z30" -H "X-Forwarded-For: $Z" "$B/usuarios")"
r_solto_x="$(liberar_web30 "$X")"; volta_x="$(ver30 "$X" /entrar)"
[[ "$r_limpa" == 0 && -n "$origem30" && "$r_d2" == 0 && "$saude_2" == "healthy healthy healthy " && "$partida_2" == 1 && "$e_adm2" == 303 && -n "$K" \
  && "$antes_x" == 200 && "$ev" == "401 401 401 " && "$tres_x" == nenhum && "$ainda_x" == 200 && "$quarta_x" == 401 && "$r_preso_x" == 0 \
  && "$arq_x" == "root:root 600 " && "$quem_x" == "4 painel" && "$prazo_x" == 172800 && "$dep_x" == 403 && "$texto_x" == 1 && "$saude_x" == 403 && "$certa_x" == 403 \
  && "$outro_y" == 200 && "$certa_y" == 303 && "$a_bloq" == 1 && "$a_rec" -ge 1 && "$t_painel" == "200 " && "$w_x" == 1 && "$w_regra" == 1 \
  && "$ev_p" == "401 401 401 401 " && "$proxy_arq" == nenhum && "$proxy_ok" == "200 " \
  && "$certa_z" == 303 && -n "$KZ" && "$aberta_z" == "200 " && "$ev_z" == "401 401 401 " && "$conf_z" == 403 && "$r_preso_z" == 0 && "$quem_z" == "4 painel" \
  && "$fechada_z" == "403 " && "$criado_z" == 0 && "$r_solto_z" == "303 /bloqueios?m=liberado" && "$volta_z" == "200 " \
  && "$r_solto_x" == "303 /bloqueios?m=liberado" && "$volta_x" == 200 ]]
caso $? seguranca 110 "Bloqueio por endereço no painel: entrada e confirmação por senha" "deploy.sh com BLOQUEIO_ENDERECO_ERROS=3, BLOQUEIO_ENDERECO_HORAS=1, BLOQUEIO_ENDERECO_DIAS=2 e o proxy aceito $origem30: saída $r_d2, saúde $saude_2· linha de partida do vigia com a regra nova: $partida_2 (com o padrão 5, o limite curto da entrada, de cinco falhas, chega antes do sexto erro: o painel é provado com o limite em 3) · endereço $X, informado pelo proxy: tela de entrada antes $antes_x; três entradas com a senha errada: ${ev}bloqueio: $tres_x, tela de entrada: $ainda_x · quarta: $quarta_x; arquivo ${arq_x}com erros e autor '$quem_x' e prazo de $prazo_x s (2 dias = 172800); auditoria com endereco_bloqueado erros=4 dias=2: $a_bloq · do endereço bloqueado: tela de entrada $dep_x com o texto '$TEXTO30': $texto_x, /saude $saude_x, entrada com a senha certa $certa_x; recusa_endereco na auditoria: $a_rec · de outro endereço ($Y): tela $outro_y, entrada com a senha certa $certa_y · na aba Bloqueios: $t_painel, linha de $X por Painel com 4 erros: $w_x, a regra em vigor: $w_regra · quatro entradas erradas sem o cabeçalho (o endereço é o do próprio proxy): ${ev_p}bloqueio de $origem30: $proxy_arq, e a sessão do administrador segue: $proxy_ok · endereço $Z com sessão aberta ($certa_z, aba Usuários $aberta_z): três entradas erradas ${ev_z}e uma confirmação com a senha atual errada, ao criar administrador: $conf_z; bloqueio com erros e autor '$quem_z'; a sessão aberta dele passa a receber: $fechada_z; administrador criado: $criado_z · desbloqueio pela web: $r_solto_z, e a sessão volta a abrir: $volta_z; o de $X: $r_solto_x, tela de entrada: $volta_x"

# ------------------------------------------------------------------ o bloqueio de um serviço vale no outro
vale_0="$(tenta30 "$FA" tls end30 "$W/end30.senha")"; web_0="$(ver30 "$GB" /entrar)"; pasta_7="$(pasta30)"
ev=""; for n in 1 2 3 4; do ev+="$(errar30 -H "X-Forwarded-For: $GA") "; done
ate30 10 preso30 "$GA"; r_v1=$?
quem_va="$(quem30 "$GA")"
ftp_a="$(tenta30 "$FA" tls end30 "$W/end30.senha")"; ftp_aa="$(tenta30 "$FA" tls end30 "$W/end30.senha" --ftp-port -)"
ftp_as="$(tenta30 "$FA" puro st30a "$W/st30a.senha")"; ftp_asa="$(tenta30 "$FA" puro st30a "$W/st30a.senha" --ftp-port -)"
ev_f=""; for n in 1 2 3 4; do ev_f+="$(erra30 "$FB" tls "fantasma30v$n"); "; done
ate30 10 preso30 "$GB"; r_v2=$?
quem_vb="$(quem30 "$GB")"; prazo_vb="$(prazo30 "$GB")"; log_vb="$(vigia30 "endereço bloqueado: origem=$GB erros=4 dias=2")"
web_b="$(ver30 "$GB" /entrar)"; web_bt="$(tem30 "$TEXTO30")"; web_bs="$(entrar "$S30" "$W/painel.senha" -H "X-Forwarded-For: $GB")"
sleep 5   # a lista da aba é relida a cada 5 s
t_dois="$(aba -b "$J" "$B/bloqueios")"; w_a="$(tem30 "<td class=\"origem\"><strong><code>$GA</code></strong></td><td data-rotulo=\"Bloqueado por\">4 erros no painel</td>")"; w_b="$(tem30 "<td class=\"origem\"><strong><code>$GB</code></strong></td><td data-rotulo=\"Bloqueado por\">4 erros no FTP</td>")"
r_sa="$(liberar_web30 "$GA")"; r_sb="$(liberar_web30 "$GB")"
ftp_volta="$(tenta30 "$FA" tls end30 "$W/end30.senha")"; ftp_volta_s="$(tenta30 "$FA" puro st30a "$W/st30a.senha")"; web_volta="$(ver30 "$GB" /entrar)"; pasta_8="$(pasta30)"
[[ "$vale_0" == "0 226" && "$web_0" == 200 && -z "$pasta_7" && "$ev" == "401 401 401 401 " && "$r_v1" == 0 && "$quem_va" == "4 painel" \
  && "$ftp_a" == "67 530" && "$ftp_aa" == "67 530" && "$ftp_as" == "67 530" && "$ftp_asa" == "67 530" \
  && "$ev_f" == "67 530; 67 530; 67 530; 67 530; " && "$r_v2" == 0 && "$quem_vb" == "4 ftp" && "$prazo_vb" == 172800 && "$log_vb" == 1 \
  && "$web_b" == 403 && "$web_bt" == 1 && "$web_bs" == 403 && "$t_dois" == "200 " && "$w_a" == 1 && "$w_b" == 1 \
  && "$r_sa" == "303 /bloqueios?m=liberado" && "$r_sb" == "303 /bloqueios?m=liberado" && "$ftp_volta" == "0 226" && "$ftp_volta_s" == "0 226" && "$web_volta" == 200 && -z "$pasta_8" ]]
caso $? seguranca 111 "Endereço bloqueado pelo painel não entra no FTP, e o bloqueado pelo FTP não entra no painel" "antes: $GA no FTP $vale_0, $GB na tela de entrada do painel $web_0, endereços bloqueados: '${pasta_7}' · quatro entradas erradas no painel vindas de $GA: ${ev}bloqueio com erros e autor '$quem_va'; no FTP, a senha certa desse endereço com TLS em modo passivo: $ftp_a e ativo: $ftp_aa, sem TLS em modo passivo: $ftp_as e ativo: $ftp_asa · quatro nomes que não existem no FTP vindos de $GB: ${ev_f}bloqueio com erros e autor '$quem_vb', prazo de $prazo_vb s, registro do FTP com 'endereço bloqueado: origem=$GB erros=4 dias=2': $log_vb; no painel, a tela de entrada desse endereço: $web_b com o texto da recusa: $web_bt, e a entrada com a senha certa: $web_bs · aba Bloqueios: $t_dois, $GA por Painel: $w_a, $GB por FTP: $w_b · desbloqueio dos dois pela web: $r_sa e $r_sb; $GA volta ao FTP com TLS: $ftp_volta e sem TLS: $ftp_volta_s; $GB volta à tela de entrada: $web_volta; endereços bloqueados: '${pasta_8}'"

# ------------------------------------------------------------------ desligado, recusas de configuração e a volta ao padrão
gravar_env "$ENVA" BLOQUEIO_ENDERECO_ERROS 0
dep; r_d3=$?
saude_3="$(saude "$FTP" "$PAINEL" "$NGINX")"; ligar30
partida_3="$(partida30 'pronto: bloqueio por endereço desligado (BLOQUEIO_ENDERECO_ERROS=0)')"
e_adm3="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
ev=""; for n in 1 2 3 4 5 6 7; do ev+="$(erra30 "$FA" tls "fantasma30d$n"); "; done
ev_w=""; for n in 1 2 3 4; do ev_w+="$(errar30 -H "X-Forwarded-For: $X") "; done
sleep 2
pasta_9="$(pasta30)"; des_ftp="$(tenta30 "$FA" tls end30 "$W/end30.senha")"; des_web="$(ver30 "$X" /entrar)"
t_des="$(aba -b "$J" "$B/bloqueios")"; w_des="$(tem30 'O bloqueio automático está desligado')"
t_seg3="$(aba -b "$J" "$B/seguranca")"; s_des="$(tem30 '<strong>Desligado na stack</strong> (<code>BLOQUEIO_ENDERECO_ERROS=0</code>)')"
# Desligado, o bloqueio feito pelo administrador continua valendo nos dois serviços.
mu endereco-bloquear "$GA" "" 1; r_m9=$?; man_ftp="$(tenta30 "$FA" tls end30 "$W/end30.senha")"; man_web="$(ver30 "$GA" /entrar)"
mu endereco-liberar "$GA"; r_m10=$?; man_volta="$(tenta30 "$FA" tls end30 "$W/end30.senha")"
gravar_env "$ENVA" BLOQUEIO_ENDERECO_ERROS "$erros_0"; gravar_env "$ENVA" BLOQUEIO_ENDERECO_HORAS "$horas_0"; gravar_env "$ENVA" BLOQUEIO_ENDERECO_DIAS "$dias_0"
gravar_env "$ENVA" PAINEL_PROXY_CONFIAVEL "$proxy_0"
gravar_env "$ENVA" REDE_PERMITIR_IP_PUBLICO "$opcao_0"
[[ -n "$redes_0" ]] && gravar_env "$ENVA" PAINEL_REDES_PERMITIDAS "$redes_0"
dep; r_d4=$?
saude_4="$(saude "$FTP" "$PAINEL" "$NGINX")"; partida_4="$(partida30 "$(printf "$PARTIDA30" "$erros_0" "$horas_0" "$dias_0")")"; pasta_10="$(pasta30)"
for n in end30 st30a st30b; do mu del "$n"; done
docker exec "$FTP" rm -rf /data/bloqueio30
for n in "$A30" "$B30"; do docker network disconnect -f "$n" "$FTP" > /dev/null 2>&1; docker network rm "$n" > /dev/null 2>&1; done
redes_fim="$(docker network ls -q --filter "name=$NOME-network-30" | wc -l)"; usuarios_fim="$(usuarios_ftp | tr ' ' '\n' | grep -c -E '^(end30|st30[ab])$')"
MSG_E='BLOQUEIO_ENDERECO_ERROS deve ficar entre 0 e 100 (0 desliga o bloqueio por endereço)'; MSG_H='BLOQUEIO_ENDERECO_HORAS deve ficar entre 1 e 720'; MSG_D='BLOQUEIO_ENDERECO_DIAS deve ficar entre 1 e 3650'
recusou "$rec_e1" "$MSG_E" && recusou "$rec_e2" "$MSG_E" && recusou "$rec_e3" "$MSG_E" && recusou "$rec_h1" "$MSG_H" && recusou "$rec_h2" "$MSG_H" \
  && recusou "$rec_d1" "$MSG_D" && recusou "$rec_d2" "$MSG_D" && recusou "$rec_cf1" "$MSG_E" && recusou "$rec_cf2" "$MSG_H" && recusou "$rec_cf3" "$MSG_D" \
  && recusou "$rec_cp1" "$MSG_E" && recusou "$rec_cp2" "$MSG_H" && recusou "$rec_cp3" "$MSG_D" \
  && [[ "$r_d3" == 0 && "$saude_3" == "healthy healthy healthy " && "$partida_3" == 1 && "$e_adm3" == 303 \
  && "$ev" == "67 530; 67 530; 67 530; 67 530; 67 530; 67 530; 67 530; " && "$ev_w" == "401 401 401 401 " && -z "$pasta_9" && "$des_ftp" == "0 226" && "$des_web" == 200 \
  && "$t_des" == "200 " && "$w_des" == 1 && "$t_seg3" == "200 " && "$s_des" == 1 \
  && "$r_m9" == 0 && "$man_ftp" == "67 530" && "$man_web" == 403 && "$r_m10" == 0 && "$man_volta" == "0 226" \
  && "$r_d4" == 0 && "$saude_4" == "healthy healthy healthy " && "$partida_4" == 1 && -z "$pasta_10" && "$redes_fim" == 0 && "$usuarios_fim" == 0 ]]
caso $? seguranca 112 "Bloqueio por endereço desligado por opção, valores fora da regra recusados e volta ao padrão" "deploy.sh com BLOQUEIO_ENDERECO_ERROS=101: $rec_e1 · com -1: $rec_e2 · com abc: $rec_e3 · com BLOQUEIO_ENDERECO_HORAS=0: $rec_h1 · com 721: $rec_h2 · com BLOQUEIO_ENDERECO_DIAS=0: $rec_d1 · com 3651: $rec_d2 · container do FTP sozinho com ERROS=101: $rec_cf1 · com HORAS=0: $rec_cf2 · com DIAS=3651: $rec_cf3 · container do painel sozinho com ERROS=abc: $rec_cp1 · com HORAS=721: $rec_cp2 · com DIAS=0: $rec_cp3 · com BLOQUEIO_ENDERECO_ERROS=0: saída $r_d3, saúde $saude_3· linha de partida 'bloqueio por endereço desligado': $partida_3 · sete nomes que não existem no FTP vindos de $GA: ${ev}quatro entradas erradas no painel vindas de $X: ${ev_w}endereços bloqueados: '${pasta_9}', $GA entra no FTP: $des_ftp, $X abre a tela de entrada: $des_web · aba Bloqueios: $t_des, 'O bloqueio automático está desligado': $w_des; aba Segurança: $t_seg3, 'Desligado na stack': $s_des · bloqueio feito pelo terminal com a opção desligada: saída $r_m9, FTP $man_ftp, painel $man_web; liberado: saída $r_m10, FTP $man_volta · de volta ao padrão ($erros_0 erros, $horas_0 h, $dias_0 dias, sem proxy): saída $r_d4, saúde $saude_4· linha de partida com a regra: $partida_4, endereços bloqueados: '${pasta_10}', redes da etapa que sobraram: $redes_fim, usuários da etapa que sobraram: $usuarios_fim"
