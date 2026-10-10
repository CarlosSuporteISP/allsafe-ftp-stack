#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa AD: bloqueio por endereço, IPv4 e IPv6. O endereço que passa do limite de erros de usuário e senha deixa
# de entrar no FTP (com e sem TLS, em modo passivo e ativo) e no painel, com qualquer conta, e a entrada certa zera
# a contagem dele; a lista na web, o bloqueio novo de endereço e de prefixo, a mudança de prazo, o desbloqueio, o
# terminal, o que nunca é bloqueado sozinho, o bloqueio desligado e as recusas.
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
  formulario="$(c -c "$P30" "$@" "$B/entrar" | sed -n 's/.*name="token" value="\([^"]*\)".*/\1/p' | head -1)"
  c -o /dev/null -w '%{http_code}' -b "$P30" -H "Origin: $B" "$@" --data-urlencode "token=$formulario" \
    --data-urlencode "usuario=$ADMIN" --data-urlencode "senha@$W/errada30.senha" "$B/entrar"
}
ver30() { c -o "$W/corpo" -w '%{http_code}' -H "X-Forwarded-For: $1" "$B$2"; }               # <endereço do cliente> <caminho> → código HTTP
de30() { auditoria; grep -o 'ip=[^ ]* evento=entrada_[a-z]*' "$W/auditoria" | tail -1 | sed -e 's/^ip=//' -e 's/ evento=.*//'; }  # endereço da última entrada na auditoria
prazo_web30() { envio /bloqueios/prazo --data-urlencode "csrf=$K" --data-urlencode "ip=$1" --data-urlencode "dias=$2"; }  # <endereço> <dias> → "código destino"
liberar_web30() { envio /bloqueios/liberar --data-urlencode "csrf=$K" --data-urlencode "ip=$1"; }                          # <endereço> → "código destino"
tem30() { grep -c -F -- "$1" "$W/corpo"; }                                                 # <trecho>: linhas da última tela com ele
linha30() { docker exec "$FTP" cat "$1" 2>/dev/null | tr '\n' ' '; }                        # <arquivo de bloqueio> → "<vale até> <desde> <erros> <quem> "
resta_de30() { local a _; read -r a _ <<< "$(linha30 "$1")"; [[ "$a" =~ ^[0-9]+$ ]] && echo $(( (a - $(date +%s) + 43200) / 86400 )) || echo '?'; }  # <arquivo> → dias que faltam, arredondados
quem_de30() { local _ n q; read -r _ _ n q _ <<< "$(linha30 "$1")"; echo "${n:-?} ${q:-?}"; }  # <arquivo> → "<erros> <quem>"
prefixos30() { docker exec "$FTP" ls -A /auth/prefixos 2>/dev/null | sort | tr '\n' ' '; }  # prefixos com arquivo de bloqueio
novo30() { envio /bloqueios/novo --data-urlencode "csrf=$K" --data-urlencode "alvo=$1" --data-urlencode "dias=$2"; }  # <endereço ou prefixo> <dias> → "código destino"
# <pote> <token> <alvo> <dias> [opções do curl...] → código HTTP de um bloqueio novo; a tela da resposta fica em $W/corpo
recusa30() {
  local pote="$1" token="$2" alvo="$3" dias="$4"; shift 4
  c -o "$W/corpo" -w '%{http_code}' -b "$pote" -H "Origin: $B" "$@" --data-urlencode "csrf=$token" --data-urlencode "alvo=$alvo" --data-urlencode "dias=$dias" "$B/bloqueios/novo"
}
# <usuário> <endereço> → o que o porteiro responde ao pure-authd: auth_ok:0 (segue para a senha) ou auth_ok:-1 (recusado)
porteiro30() { docker exec -e "AUTHD_ACCOUNT=$1" -e "AUTHD_REMOTE_IP=$2" -e AUTHD_ENCRYPTED=1 "$FTP" allsafe-ftp-porteiro 2>/dev/null | head -1; }
# O FTP escuta só em IPv4: para o vigia ver um endereço IPv6, a etapa escreve no /dev/log do container o aviso que
# o Pure-FTPd escreveria, no formato dele. <prioridade> <conta ou ?> <endereço> <NÍVEL> <texto>
aviso30() {
  docker exec -i "$FTP" perl - "$@" <<'PERL'
use Socket;
socket(my $s, AF_UNIX, SOCK_DGRAM, 0) or die "soquete: $!\n";
my @t = localtime; my @m = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my $linha = sprintf('<%d>%s %2d %02d:%02d:%02d pure-ftpd: (%s@%s) [%s] %s', $ARGV[0], $m[$t[4]], $t[3], @t[2, 1, 0], @ARGV[1 .. 4]);
send($s, $linha, 0, pack_sockaddr_un('/dev/log')) or die "envio: $!\n";
PERL
}
falha30() { aviso30 36 '?' "$1" WARNING "Authentication failed for user [$2]"; }            # <endereço> <nome>: senha errada, como o vigia a recebe
certa30() { aviso30 38 "$2" "$1" INFO "$2 is now logged in"; }                              # <endereço> <usuário>: entrada certa, como o vigia a recebe
# <textos...> → uma linha por texto: "<texto> => endereco <escrita>", "prefixo <rede>/<tamanho>", "invalido" ou "servidor"
perl30() {   # a leitura do FTP (ftp/endereco.pl)
  local texto r
  for texto in "$@"; do
    r="$(docker exec "$FTP" perl /usr/local/lib/allsafe/endereco.pl alvo "$texto" 2>/dev/null)"
    case $? in 0) echo "$texto => $r" ;; 1) echo "$texto => invalido" ;; 2) echo "$texto => servidor" ;; *) echo "$texto => ?" ;; esac
  done
}
python30() {   # a leitura do painel (painel/enderecos.py)
  docker exec -i "$PAINEL" python3 - "$@" <<'PYTHON'
import sys
sys.path.insert(0, '/opt/painel')
import enderecos
for texto in sys.argv[1:]:
    print(texto, '=>', ' '.join(parte for parte in enderecos.alvo(texto)[:2] if parte))
PYTHON
}
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
cinco_arq="$(pasta30)"
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
  && "$antes_p" == "0 226" && "$antes_a" == "0 226" && "$ev" == "67 530; 67 530; 67 530; 67 530; 67 530; " && -z "$cinco_arq" \
  && "$sexto" == "67 530" && "$r_preso" == 0 && "$arq_a" == "root:root 600 " && "$quem_a" == "6 ftp" && "$prazo_a" == 10368000 && "$log_a" == 1 \
  && "$dep_p" == "67 530" && "$dep_a" == "67 530" && "$dep_outro" == "67 530" && "$log_rec" -ge 1 && "$de_b" == "0 226" && "$do_host" == "0 226" ]]
caso $? seguranca 106 "Bloqueio por endereço no FTP com TLS: o sexto erro bloqueia por 120 dias" "instância com REDE_PERMITIR_IP_PUBLICO=nao durante a etapa (deploy.sh: saída $r_d0), para a dispensa do TLS valer; padrão da stack: BLOQUEIO_ENDERECO_ERROS=$erros_0, BLOQUEIO_ENDERECO_HORAS=$horas_0, BLOQUEIO_ENDERECO_DIAS=$dias_0; linha de partida do vigia com a regra: $partida_0; /auth/enderecos: ${pasta_0}e vazia · endereço $GA (rede ligada ao FTP depois da partida), com TLS: senha certa em modo passivo $antes_p e em modo ativo $antes_a · duas senhas erradas do usuário end30 e três nomes que não existem: ${ev}arquivos de bloqueio depois dos cinco erros: '${cinco_arq}' · sexto erro: $sexto; arquivo /auth/enderecos/$GA: ${arq_a}com erros e autor '$quem_a' e prazo de $prazo_a s (120 dias = 10368000); registro do FTP com 'endereço bloqueado: origem=$GA erros=6 dias=$dias_0': $log_a · do endereço bloqueado, a senha certa em modo passivo: $dep_p, em modo ativo: $dep_a, e a senha certa de outro usuário: $dep_outro; registro com 'entrada recusada pelo bloqueio do endereço': $log_rec · a mesma conta de outro endereço ($GB): $de_b, e pela porta publicada: $do_host"

# ------------------------------------------------------------------ FTP sem TLS: a mesma regra
antes_s="$(tenta30 "$FB" puro st30a "$W/st30a.senha")"; antes_sa="$(tenta30 "$FB" puro st30a "$W/st30a.senha" --ftp-port -)"
ev=""
for n in 1 2 3; do ev+="$(erra30 "$FB" puro st30a); "; done
for n in 1 2; do ev+="$(erra30 "$FB" puro st30b); "; done
# Usuário que não é dispensado, sem TLS: o porteiro recusa antes de a senha ser conferida, e isso não é erro de senha.
sem_tls="$(tenta30 "$FB" puro end30 "$W/end30.senha")"
sleep 2
cinco_b="$(solto30 "$GB" && echo nenhum || echo gravado)"
sexto_b="$(erra30 "$FB" puro st30b)"
ate30 10 preso30 "$GB"; r_preso_b=$?
quem_b="$(quem30 "$GB")"; prazo_b="$(prazo30 "$GB")"
dep_s="$(tenta30 "$FB" puro st30a "$W/st30a.senha")"; dep_sa="$(tenta30 "$FB" puro st30a "$W/st30a.senha" --ftp-port -)"; dep_st="$(tenta30 "$FB" tls end30 "$W/end30.senha")"
host_s="$(tenta30 "$F" puro st30a "$W/st30a.senha")"; pasta_2="$(pasta30)"
[[ "$antes_s" == "0 226" && "$antes_sa" == "0 226" && "$ev" == "67 530; 67 530; 67 530; 67 530; 67 530; " && "$sem_tls" == "67 530" && "$cinco_b" == nenhum \
  && "$sexto_b" == "67 530" && "$r_preso_b" == 0 && "$quem_b" == "6 ftp" && "$prazo_b" == 10368000 \
  && "$dep_s" == "67 530" && "$dep_sa" == "67 530" && "$dep_st" == "67 530" && "$host_s" == "0 226" \
  && "$pasta_2" == "$(printf '%s\n' "$GA" "$GB" | sort | tr '\n' ' ')" ]]
caso $? seguranca 107 "Bloqueio por endereço no FTP sem TLS, em modo passivo e ativo" "endereço $GB, sem TLS, com os usuários dispensados st30a e st30b: senha certa em modo passivo $antes_s e em modo ativo $antes_sa · três senhas erradas de st30a e duas de st30b: ${ev}e uma entrada sem TLS de usuário que não é dispensado (recusada antes de a senha ser conferida, não conta): $sem_tls; bloqueio depois disso: $cinco_b · sexto erro: $sexto_b; arquivo do endereço com erros e autor '$quem_b' e prazo de $prazo_b s · do endereço bloqueado, senha certa sem TLS em modo passivo: $dep_s, em modo ativo: $dep_sa, e com TLS: $dep_st · o mesmo usuário pela porta publicada: $host_s · endereços bloqueados: $pasta_2"

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
l_total="$(tem30 'Agora: 2 bloqueios em vigor.')"; l_menu="$(tem30 'href="/bloqueios"')"
t_um="$(aba -b "$J" "$B/bloqueios/endereco?ip=$GA")"
u_titulo="$(tem30 "Bloqueio de <code>$GA</code>")"; u_dias="$(tem30 'name="dias" type="number" min="1" max="3650" step="1" required value="120"')"
u_autor="$(tem30 'Bloqueado por <strong>FTP</strong>, com 6 erros de usuário e senha')"; u_liberar="$(tem30 'action="/bloqueios/liberar"')"
t_nao="$(aba -b "$J" "$B/bloqueios/endereco?ip=203.0.113.200")"
desde_a="$(conteudo30 "$GA" | cut -d' ' -f2)"
r_prazo="$(prazo_web30 "$GA" 200)"; resta_a="$(resta30 "$GA")"; quem_a2="$(quem30 "$GA")"; desde_a2="$(conteudo30 "$GA" | cut -d' ' -f2)"
t_prazo="$(aba -b "$J" "$B/bloqueios?m=prazo")"; m_prazo="$(tem30 'Prazo do bloqueio alterado.')"
r_solto="$(liberar_web30 "$GB")"; solto_b="$(solto30 "$GB" && echo sim || echo nao)"; volta_b="$(tenta30 "$FB" tls end30 "$W/end30.senha")"; volta_bs="$(tenta30 "$FB" puro st30a "$W/st30a.senha")"
t_solto="$(aba -b "$J" "$B/bloqueios?m=liberado")"; m_solto="$(tem30 'Bloqueio desfeito: quem estava nele volta a entrar no FTP e no painel.')"; m_total="$(tem30 'Agora: 1 bloqueio em vigor.')"; m_b="$(tem30 "<code>$GB</code>")"
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
caso $? testes 61 "Aba Bloqueios: lista dos endereços, mudança de prazo e desbloqueio" "GET /bloqueios: $t_lista, linha de $GA (FTP, 6 erros): $l_a, linha de $GB: $l_b, a regra em vigor escrita: $l_regra, 'Agora: 2 bloqueios em vigor.': $l_total, item no menu: $l_menu · tela do endereço $GA: $t_um, com o título: $u_titulo, o campo dos dias com o prazo da stack (120): $u_dias, quem bloqueou e com quantos erros: $u_autor, e o formulário de desbloqueio: $u_liberar; a de um endereço que não está bloqueado: $t_nao · prazo de $GA mudado para 200 dias: $r_prazo; dias que faltam no arquivo: $resta_a, erros e autor mantidos: '$quem_a2', início mantido: $([[ "$desde_a2" == "$desde_a" ]] && echo sim || echo NÃO); aviso na tela: $m_prazo · $GB desbloqueado: $r_solto; arquivo removido: $solto_b; no pedido seguinte ele entra no FTP com TLS: $volta_b e sem TLS: $volta_bs; aviso na tela: $m_solto, 'Agora: 1 bloqueio em vigor.': $m_total, linhas com $GB: $m_b; desbloquear de novo: $r_denovo · auditoria: endereco_prazo com o administrador, o endereço e os dias: $a_prazo, endereco_desbloqueado: $a_solto · aba Segurança: $t_seg, linha 'Bloqueio por endereço': $s_linha, com o total e o atalho para a lista: $s_agora · aba Log: $t_ativ, 'Prazo do bloqueio de endereço alterado': $v_prazo, 'Endereço desbloqueado': $v_solto"

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
for v in 1.2.3 01.2.3.4 256.1.1.1 '../x' '1.2.3.4;id'; do
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

# ------------------------------------------------------------------ a entrada certa zera a contagem do endereço
certas_0="$(vigia30 "entrada: usuario=end30 origem=$GB")"
ev=""; for n in 1 2 3 4 5; do ev+="$(erra30 "$FB" tls "fantasma30z$n"); "; done
sleep 2
zf_certa="$(tenta30 "$FB" tls end30 "$W/end30.senha")"
sleep 2   # o vigia lê a entrada certa antes dos erros seguintes
certas_1="$(vigia30 "entrada: usuario=end30 origem=$GB")"
ev_2=""; for n in 6 7 8 9 10; do ev_2+="$(erra30 "$FB" tls "fantasma30z$n"); "; done
sleep 2
zf_arq="$(solto30 "$GB" && echo nenhum || echo gravado)"; zf_entra="$(tenta30 "$FB" tls end30 "$W/end30.senha")"
sleep 2
# Sem entrada certa no meio, o sexto erro seguido bloqueia.
ev_3=""; for n in 11 12 13 14 15; do ev_3+="$(erra30 "$FB" tls "fantasma30z$n"); "; done
sleep 2
zf_cinco="$(solto30 "$GB" && echo nenhum || echo gravado)"; zf_sexto="$(erra30 "$FB" tls fantasma30z16)"
ate30 10 preso30 "$GB"; r_zf=$?
zf_quem="$(quem30 "$GB")"; zf_preso="$(tenta30 "$FB" tls end30 "$W/end30.senha")"
mu endereco-liberar "$GB"; r_zl=$?; zf_volta="$(tenta30 "$FB" tls end30 "$W/end30.senha")"; zf_pasta="$(pasta30)"
[[ "$ev" == "67 530; 67 530; 67 530; 67 530; 67 530; " && "$zf_certa" == "0 226" && $((certas_1 - certas_0)) == 1 && "$ev_2" == "$ev" && "$zf_arq" == nenhum && "$zf_entra" == "0 226" \
  && "$ev_3" == "$ev" && "$zf_cinco" == nenhum && "$zf_sexto" == "67 530" && "$r_zf" == 0 && "$zf_quem" == "6 ftp" && "$zf_preso" == "67 530" \
  && "$r_zl" == 0 && "$zf_volta" == "0 226" && "$zf_pasta" == "$GA " ]]
caso $? seguranca 115 "Entrada com usuário e senha certos zera a contagem de erros do endereço no FTP" "endereço $GB, com TLS, limite da stack em $erros_0 erros · cinco nomes que não existem: ${ev}entrada com a senha certa de end30: $zf_certa; linha 'entrada: usuario=end30 origem=$GB' a mais no registro do FTP: $((certas_1 - certas_0)) · mais cinco erros (dez ao todo em poucos segundos): ${ev_2}bloqueio de $GB: $zf_arq, e a senha certa entra: $zf_entra · sem entrada certa no meio, cinco erros: ${ev_3}bloqueio: $zf_cinco; o sexto: $zf_sexto; arquivo do endereço com erros e autor '$zf_quem', e a senha certa passa a receber: $zf_preso · liberado pelo terminal (saída $r_zl): $zf_volta; endereços bloqueados: $zf_pasta"

# ------------------------------------------------------------------ IPv6 no vigia e no porteiro
V6=2001:db8:30::7; V6L=2001:0DB8:0030:0000:0000:0000:0000:0007; V6V=2001:db8:30::8; V6Z=2001:db8:30::9; M4=203.0.113.77
r_av=0
for n in 1 2 3; do falha30 "$V6" "fantasma30s$n" || r_av=1; done
for n in 4 5; do falha30 "$V6L" "fantasma30s$n" || r_av=1; done
sleep 2
s6_cinco="$(solto30 "$V6" && echo nenhum || echo gravado)"; s6_antes="$(porteiro30 end30 "$V6")"
falha30 "$V6L" fantasma30s6 || r_av=1
ate30 10 preso30 "$V6"; r_s6=$?
s6_arq="$(dono30 "/auth/enderecos/$V6")"; s6_quem="$(quem30 "$V6")"; s6_prazo="$(prazo30 "$V6")"; s6_log="$(vigia30 "endereço bloqueado: origem=$V6 erros=6 dias=$dias_0")"
s6_p="$(porteiro30 end30 "$V6")"; s6_pl="$(porteiro30 end30 "$V6L")"; s6_pv="$(porteiro30 end30 "$V6V")"
# O IPv4 escrito dentro de IPv6 é o mesmo endereço IPv4: um bloqueio só, com o nome do IPv4.
for n in 1 2 3 4 5 6; do falha30 "::ffff:$M4" "fantasma30m$n" || r_av=1; done
ate30 10 preso30 "$M4"; r_m4=$?
m4_quem="$(quem30 "$M4")"; m4_p="$(porteiro30 end30 "$M4")"; m4_pm="$(porteiro30 end30 "::ffff:$M4")"
# A entrada certa zera a contagem do endereço IPv6, e o endereço do próprio servidor não é contado.
for n in 1 2 3 4 5; do falha30 "$V6Z" "fantasma30y$n" || r_av=1; done
certa30 "$V6Z" end30 || r_av=1
for n in 6 7 8 9 10; do falha30 "$V6Z" "fantasma30y$n" || r_av=1; done
for n in 1 2 3 4 5 6 7; do falha30 ::1 "fantasma30l$n" || r_av=1; done
sleep 2
s6_zera="$(solto30 "$V6Z" && echo nenhum || echo gravado)"; s6_zlog="$(vigia30 "entrada: usuario=end30 origem=$V6Z")"; s6_local="$(solto30 ::1 && echo nenhum || echo gravado)"
s6_pasta="$(pasta30)"
mu endereco-liberar "$V6L"; r_l6=$?; x_l6="$(grep -c -x "Endereco $V6 liberado: vale no proximo pedido." "$W/mu.log")"
mu endereco-liberar "$M4"; r_l4=$?
s6_volta="$(porteiro30 end30 "$V6")"; s6_fim="$(pasta30)"
[[ "$r_av" == 0 && "$s6_cinco" == nenhum && "$s6_antes" == "auth_ok:0" && "$r_s6" == 0 && "$s6_arq" == "root:root 600 " && "$s6_quem" == "6 ftp" && "$s6_prazo" == 10368000 && "$s6_log" == 1 \
  && "$s6_p" == "auth_ok:-1" && "$s6_pl" == "auth_ok:-1" && "$s6_pv" == "auth_ok:0" && "$r_m4" == 0 && "$m4_quem" == "6 ftp" && "$m4_p" == "auth_ok:-1" && "$m4_pm" == "auth_ok:-1" \
  && "$s6_zera" == nenhum && "$s6_zlog" == 1 && "$s6_local" == nenhum && "$s6_pasta" == "$(printf '%s\n' "$GA" "$V6" "$M4" | sort | tr '\n' ' ')" \
  && "$r_l6" == 0 && "$x_l6" == 1 && "$r_l4" == 0 && "$s6_volta" == "auth_ok:0" && "$s6_fim" == "$GA " ]]
caso $? seguranca 116 "Bloqueio por endereço com IPv6 no FTP: o vigia conta e o porteiro recusa" "o FTP escuta só em IPv4: o aviso de senha errada foi escrito no /dev/log do container, no formato do Pure-FTPd, e o porteiro foi chamado como o pure-authd o chama (avisos entregues: $([[ "$r_av" == 0 ]] && echo todos || echo NÃO)) · endereço $V6: três erros nessa escrita e dois na longa e maiúscula ($V6L); bloqueio depois dos cinco: $s6_cinco, porteiro: $s6_antes · sexto erro, na escrita longa: arquivo /auth/enderecos/$V6: ${s6_arq}com erros e autor '$s6_quem' e prazo de $s6_prazo s (120 dias = 10368000); registro do FTP com 'endereço bloqueado: origem=$V6 erros=6 dias=$dias_0': $s6_log · porteiro para o endereço: $s6_p, para a escrita longa dele: $s6_pl, para o vizinho $V6V: $s6_pv · seis erros de ::ffff:$M4 (IPv4 escrito dentro de IPv6): bloqueio de $M4 com erros e autor '$m4_quem'; porteiro para $M4: $m4_p e para ::ffff:$M4: $m4_pm · $V6Z: cinco erros, uma entrada certa de end30 e mais cinco erros: bloqueio $s6_zera, linha 'entrada: usuario=end30 origem=$V6Z' no registro: $s6_zlog · sete erros de ::1 (o próprio servidor): bloqueio $s6_local · endereços bloqueados: $s6_pasta· liberar pelo terminal com a escrita longa: saída $r_l6, mensagem com a escrita única: $x_l6; porteiro depois: $s6_volta; endereços bloqueados no fim: $s6_fim"

# ------------------------------------------------------------------ o terminal com IPv6 e com prefixo; a mesma leitura no FTP e no painel
PT='/auth/prefixos/2001:db8:5::_48'
pref_0="$(prefixos30)"; pref_dono="$(dono30 /auth/prefixos)"
mu endereco-bloquear 2001:DB8:0:0:0:0:0:7 "" 3; r_t1=$?; x_t1="$(grep -c -x 'Endereco 2001:db8::7 bloqueado: 3 dia(s) a partir de agora, no FTP e no painel.' "$W/mu.log")"
t6_arq="$(dono30 /auth/enderecos/2001:db8::7)"; t6_quem="$(quem30 2001:db8::7)"; t6_p="$(porteiro30 end30 2001:db8:0::7)"
mu endereco-bloquear 2001:db8:5:9::1/48 "" 7; r_t2=$?; x_t2="$(grep -c -x 'Prefixo 2001:db8:5::/48 bloqueado: 7 dia(s) a partir de agora, no FTP e no painel.' "$W/mu.log")"
t6_parq="$(dono30 "$PT")"; t6_pquem="$(quem_de30 "$PT")"; t6_dentro="$(porteiro30 end30 2001:db8:5:ffff::9)"; t6_fora="$(porteiro30 end30 2001:db8:6::9)"
mu endereco-bloquear 2001:db8:5::/48 "" 9; r_t3=$?; x_t3="$(grep -c -x 'Prazo do prefixo 2001:db8:5::/48 alterado: 9 dia(s) a partir de agora, no FTP e no painel.' "$W/mu.log")"; t6_resta="$(resta_de30 "$PT")"
mu endereco-bloquear 192.0.2.130/25 "" 4; r_t4=$?; x_t4="$(grep -c -x 'Prefixo 192.0.2.128/25 bloqueado: 4 dia(s) a partir de agora, no FTP e no painel.' "$W/mu.log")"
t4_dentro="$(porteiro30 end30 192.0.2.200)"; t4_fora="$(porteiro30 end30 192.0.2.5)"
mu endereco-bloquear ::ffff:203.0.113.78 "" 2; r_t5=$?; x_t5="$(grep -c -x 'Endereco 203.0.113.78 bloqueado: 2 dia(s) a partir de agora, no FTP e no painel.' "$W/mu.log")"
mu enderecos; r_t6=$?
x_l1="$(grep -c '^origem=2001:db8::7 por=manual erros=0 desde=' "$W/mu.log")"; x_l2="$(grep -c '^origem=2001:db8:5::/48 por=manual erros=0 desde=' "$W/mu.log")"
x_l3="$(grep -c '^origem=192.0.2.128/25 por=manual erros=0 desde=' "$W/mu.log")"; x_l4="$(grep -c '^origem=203.0.113.78 por=manual erros=0 desde=' "$W/mu.log")"; x_lt="$(grep -c '^origem=' "$W/mu.log")"
sleep 5   # a lista da aba é relida a cada 5 s
t_pref="$(aba -b "$J" "$B/bloqueios")"; w_pref="$(tem30 '<td class="origem"><strong><code>2001:db8:5::/48</code></strong></td><td data-rotulo="Bloqueado por">Administrador</td>')"; w_tot="$(tem30 'Agora: 5 bloqueios em vigor.')"
mu endereco-liberar 2001:DB8:5::/48; r_t7=$?; x_t7="$(grep -c -x 'Prefixo 2001:db8:5::/48 liberado: vale no proximo pedido.' "$W/mu.log")"; t6_livre="$(porteiro30 end30 2001:db8:5:ffff::9)"
mu endereco-liberar 2001:db8:5::/48; r_t8=$?; x_t8="$(grep -c -x 'Prefixo 2001:db8:5::/48 nao esta bloqueado.' "$W/mu.log")"
mu endereco-liberar 192.0.2.128/25; r_t9=$?; mu endereco-liberar 2001:db8::7; r_t10=$?; mu endereco-liberar 203.0.113.78; r_t11=$?
pasta_a="$(pasta30)"; pref_a="$(prefixos30)"; ev=""; ok=0
for v in 10.0.0.0/7 192.0.2.0/32 2001:db8::/15 2001:db8::/128 '2001:db8::1%eth0' 2001:db8::/ 2001:db8:::1 12345::1 203.0.113.0/024; do
  mu endereco-bloquear "$v" "" 5; r=$?; [[ "$r" != 0 && "$(grep -c '^Endereco invalido' "$W/mu.log")" == 1 ]] || ok=1; ev+="$v: saída $r; "
  mu endereco-liberar "$v"; r=$?; [[ "$r" != 0 ]] || ok=1
done
for v in ::1 ::/16 127.0.0.0/8 0.0.0.0/8 ::ffff:127.0.0.1; do
  mu endereco-bloquear "$v" "" 5; r=$?; [[ "$r" != 0 && "$(grep -c '^Endereco nao bloqueavel' "$W/mu.log")" == 1 ]] || ok=1; ev+="$v: saída $r; "
done
pasta_b="$(pasta30)"; pref_b="$(prefixos30)"
# O nome do arquivo de bloqueio é o endereço numa escrita só: o FTP (Perl) e o painel (Python) têm de ler igual.
TEXTOS30=(203.0.113.7 01.2.3.4 1.2.3 256.1.1.1 127.0.0.1 0.1.2.3 2001:db8::7 2001:DB8:0:0:0:0:0:7 2001:db8:0:0:1:0:0:1 2001:0:0:1:0:0:0:1 2001:db8:0:1:1:1:1:1
  1:: ::1 :: 1::2::3 12345::1 64:ff9b::1.2.3.4 ::ffff:1.2.3.4 ::FFFF:203.0.113.7 ::ffff:127.0.0.1 ::1.2.3.4 '2001:db8::1%eth0' fe80::1
  203.0.113.9/24 10.0.0.0/8 10.0.0.0/7 192.0.2.6/31 192.0.2.0/32 127.0.0.0/8 0.0.0.0/8 2001:db8:5:9::1/48 2001:DB8::/16 2001:db8::/15 2001:db8::1/127
  2001:db8::/128 ::/16 ::ffff:203.0.113.9/24 203.0.113.0/024 203.0.113.0/ 1:2:3:4:5:6:7:: ::ffff:01.2.3.4 2001:db8::1.2.3 :1 abc '')
igual_p="$(perl30 "${TEXTOS30[@]}")"; igual_y="$(python30 "${TEXTOS30[@]}")"
igual_n="$(grep -c . <<< "$igual_p")"; igual_d="$(diff <(echo "$igual_p") <(echo "$igual_y") | grep -c '^[<>]')"; igual_q="$(grep -c -F '=> ?' <<< "$igual_p")"
igual_e=0
for v in '2001:db8:0:0:1:0:0:1 => endereco 2001:db8::1:0:0:1' '2001:0:0:1:0:0:0:1 => endereco 2001:0:0:1::1' '64:ff9b::1.2.3.4 => endereco 64:ff9b::102:304' '::ffff:1.2.3.4 => endereco 1.2.3.4' \
  '2001:db8:5:9::1/48 => prefixo 2001:db8:5::/48' '192.0.2.6/31 => prefixo 192.0.2.6/31' '10.0.0.0/7 => invalido' '01.2.3.4 => invalido' '::/16 => servidor' '::ffff:127.0.0.1 => servidor'; do
  grep -q -x -F -- "$v" <<< "$igual_p" && igual_e=$((igual_e + 1))
done
[[ -z "$pref_0" && "$pref_dono" == "root:root 700 " && "$r_t1" == 0 && "$x_t1" == 1 && "$t6_arq" == "root:root 600 " && "$t6_quem" == "0 manual" && "$t6_p" == "auth_ok:-1" \
  && "$r_t2" == 0 && "$x_t2" == 1 && "$t6_parq" == "root:root 600 " && "$t6_pquem" == "0 manual" && "$t6_dentro" == "auth_ok:-1" && "$t6_fora" == "auth_ok:0" \
  && "$r_t3" == 0 && "$x_t3" == 1 && "$t6_resta" == 9 && "$r_t4" == 0 && "$x_t4" == 1 && "$t4_dentro" == "auth_ok:-1" && "$t4_fora" == "auth_ok:0" && "$r_t5" == 0 && "$x_t5" == 1 \
  && "$r_t6" == 0 && "$x_l1" == 1 && "$x_l2" == 1 && "$x_l3" == 1 && "$x_l4" == 1 && "$x_lt" == 5 && "$t_pref" == "200 " && "$w_pref" == 1 && "$w_tot" == 1 \
  && "$r_t7" == 0 && "$x_t7" == 1 && "$t6_livre" == "auth_ok:0" && "$r_t8" == 0 && "$x_t8" == 1 && "$r_t9" == 0 && "$r_t10" == 0 && "$r_t11" == 0 \
  && "$pasta_a" == "$GA " && -z "$pref_a" && "$ok" == 0 && "$pasta_b" == "$pasta_a" && -z "$pref_b" \
  && "$igual_n" == "${#TEXTOS30[@]}" && "$igual_d" == 0 && "$igual_q" == 0 && "$igual_e" == 10 ]]
caso $? testes 67 "Bloqueio de IPv6 e de prefixo pelo terminal, com a mesma leitura do endereço no FTP e no painel" "/auth/prefixos: ${pref_dono}e vazia · endereco-bloquear 2001:DB8:0:0:0:0:0:7 3: saída $r_t1, mensagem com a escrita única (2001:db8::7): $x_t1, arquivo ${t6_arq}com erros e autor '$t6_quem'; porteiro para 2001:db8:0::7: $t6_p · prefixo 2001:db8:5:9::1/48 por 7 dias: saída $r_t2, 'Prefixo 2001:db8:5::/48 bloqueado': $x_t2, arquivo ${t6_parq}com erros e autor '$t6_pquem'; porteiro para um endereço de dentro: $t6_dentro e para um de fora: $t6_fora; de novo com 9 dias: saída $r_t3, 'Prazo do prefixo ... alterado': $x_t3, dias que faltam: $t6_resta · prefixo 192.0.2.130/25: saída $r_t4, 'Prefixo 192.0.2.128/25 bloqueado': $x_t4, de dentro: $t4_dentro, de fora: $t4_fora · ::ffff:203.0.113.78: saída $r_t5, 'Endereco 203.0.113.78 bloqueado': $x_t5 · manage-user.sh enderecos: saída $r_t6, linhas do IPv6: $x_l1, do prefixo IPv6: $x_l2, do prefixo IPv4: $x_l3, do IPv4: $x_l4, de $x_lt · na aba Bloqueios: $t_pref, linha do prefixo por Administrador: $w_pref, 'Agora: 5 bloqueios em vigor.': $w_tot · endereco-liberar do prefixo: saída $r_t7, mensagem: $x_t7, porteiro para o endereço de dentro: $t6_livre; de novo: saída $r_t8, 'nao esta bloqueado': $x_t8 · fora da regra, todos recusados com a mensagem própria: ${ev}pastas dos bloqueios iguais às de antes: $([[ "$pasta_b" == "$pasta_a" && "$pref_b" == "$pref_a" ]] && echo sim || echo NÃO) · $igual_n textos lidos pelo FTP (ftp/endereco.pl) e pelo painel (painel/enderecos.py): linhas diferentes $igual_d, sem resposta $igual_q, conferidos com o valor esperado $igual_e de 10 (entre eles 2001:db8:0:0:1:0:0:1 ➜ 2001:db8::1:0:0:1, 64:ff9b::1.2.3.4 ➜ 64:ff9b::102:304, ::ffff:1.2.3.4 ➜ 1.2.3.4, 2001:db8:5:9::1/48 ➜ 2001:db8:5::/48, 10.0.0.0/7 inválido e ::/16 do próprio servidor)"

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

# ------------------------------------------------------------------ painel: IPv6 e a entrada certa que zera a contagem
W6=2001:db8:30::a1; W6L=2001:0DB8:0030:0000:0000:0000:0000:00A1; W6V=2001:db8:30::a2; W4=198.51.100.63
antes_6="$(ver30 "$W6" /entrar)"
ev=""; for n in 1 2; do ev+="$(errar30 -H "X-Forwarded-For: $W6") "; done; ev+="$(errar30 -H "X-Forwarded-For: $W6L") "
tres_6="$(solto30 "$W6" && echo nenhum || echo gravado)"
quarta_6="$(errar30 -H "X-Forwarded-For: $W6L")"
ate30 10 preso30 "$W6"; r_preso_6=$?
arq_6="$(dono30 "/auth/enderecos/$W6")"; quem_6="$(quem30 "$W6")"; prazo_6="$(prazo30 "$W6")"
dep_6="$(ver30 "$W6" /entrar)"; texto_6="$(tem30 "$TEXTO30")"; dep_6l="$(ver30 "$W6L" /entrar)"; viz_6="$(ver30 "$W6V" /entrar)"
ftp_6="$(porteiro30 end30 "$W6")"; ftp_6v="$(porteiro30 end30 "$W6V")"
auditoria; a_6="$(grep -c "ip=$W6 evento=endereco_bloqueado erros=4 dias=2\$" "$W/auditoria")"
sleep 5   # a lista da aba é relida a cada 5 s
t_6="$(aba -b "$J" "$B/bloqueios")"; w_6="$(tem30 "<td class=\"origem\"><strong><code>$W6</code></strong></td><td data-rotulo=\"Bloqueado por\">4 erros no painel</td>")"
t_6um="$(aba -b "$J" --get --data-urlencode "ip=$W6" "$B/bloqueios/endereco")"; u_6="$(tem30 "Bloqueio de <code>$W6</code>")"; u_6a="$(tem30 'Bloqueado por <strong>Painel</strong>, com 4 erros de usuário e senha')"
t_6longa="$(aba -b "$J" --get --data-urlencode "ip=$W6L" "$B/bloqueios/endereco")"
r_solto_6="$(liberar_web30 "$W6")"; volta_6="$(ver30 "$W6L" /entrar)"; ftp_6d="$(porteiro30 end30 "$W6")"
# Entrada certa no meio: a contagem do endereço recomeça. São cinco falhas ao todo no endereço, o que o limite
# curto da entrada deixa passar (a sexta em 15 minutos receberia 429, com ou sem bloqueio).
ev_4="$(errar30 -H "X-Forwarded-For: $W4") $(errar30 -H "X-Forwarded-For: $W4") "
certa_4="$(COMO=end30 entrar "$S30" "$W/end30.senha" -H "X-Forwarded-For: $W4")"; proibir "$(biscoito_de "$S30")"
ev_4+="$(errar30 -H "X-Forwarded-For: $W4") $(errar30 -H "X-Forwarded-For: $W4") "
quatro_4="$(solto30 "$W4" && echo nenhum || echo gravado)"
quinta_4="$(errar30 -H "X-Forwarded-For: $W4")"
sleep 1
cinco_4="$(solto30 "$W4" && echo nenhum || echo gravado)"; tela_4="$(ver30 "$W4" /entrar)"; pasta_w="$(pasta30)"
[[ "$antes_6" == 200 && "$ev" == "401 401 401 " && "$tres_6" == nenhum && "$quarta_6" == 401 && "$r_preso_6" == 0 && "$arq_6" == "root:root 600 " && "$quem_6" == "4 painel" && "$prazo_6" == 172800 \
  && "$dep_6" == 403 && "$texto_6" == 1 && "$dep_6l" == 403 && "$viz_6" == 200 && "$ftp_6" == "auth_ok:-1" && "$ftp_6v" == "auth_ok:0" && "$a_6" == 1 \
  && "$t_6" == "200 " && "$w_6" == 1 && "$t_6um" == "200 " && "$u_6" == 1 && "$u_6a" == 1 && "$t_6longa" == "303 /bloqueios?m=ausente" \
  && "$r_solto_6" == "303 /bloqueios?m=liberado" && "$volta_6" == 200 && "$ftp_6d" == "auth_ok:0" \
  && "$ev_4" == "401 401 401 401 " && "$certa_4" == 303 && "$quatro_4" == nenhum && "$quinta_4" == 401 && "$cinco_4" == nenhum && "$tela_4" == 200 && -z "$pasta_w" ]]
caso $? seguranca 117 "Bloqueio por endereço no painel com IPv6, e entrada certa zerando a contagem" "limite em 3 erros, 2 dias · endereço $W6, informado pelo proxy aceito: tela de entrada $antes_6; duas entradas erradas nessa escrita e uma na longa e maiúscula ($W6L): ${ev}bloqueio: $tres_6 · quarta, na escrita longa: $quarta_6; arquivo /auth/enderecos/$W6: ${arq_6}com erros e autor '$quem_6' e prazo de $prazo_6 s; auditoria com ip=$W6 evento=endereco_bloqueado erros=4 dias=2: $a_6 · do endereço bloqueado: tela de entrada $dep_6 com o texto da recusa: $texto_6, pela escrita longa: $dep_6l; do vizinho $W6V: $viz_6; no FTP, o porteiro para o endereço: $ftp_6 e para o vizinho: $ftp_6v · aba Bloqueios: $t_6, linha de $W6 por Painel com 4 erros: $w_6; tela do endereço: $t_6um, com o título: $u_6 e o autor: $u_6a; a tela pedida com a escrita longa: $t_6longa · desbloqueio pela web: $r_solto_6; tela de entrada pela escrita longa: $volta_6, porteiro: $ftp_6d · endereço $W4: duas entradas erradas, a entrada certa de um usuário do FTP ($certa_4) e mais duas erradas: ${ev_4}bloqueio: $quatro_4 (sem a entrada certa, a quarta bloquearia); a quinta, terceira desde a entrada certa: $quinta_4, bloqueio: $cinco_4, tela de entrada: $tela_4 · endereços bloqueados no fim: '${pasta_w}'"

# ------------------------------------------------------------------ a web: bloquear endereço e prefixo, estender, encurtar e desbloquear
auditoria; n_manual="$(eventos endereco_bloqueado_manual)"; n_prazo="$(eventos endereco_prazo)"; n_solto="$(eventos endereco_desbloqueado)"
N6=2001:db8:aa::1; NP=2001:db8:99::/48; NPA='/auth/prefixos/2001:db8:99::_48'; N4=192.0.2.0/25; N4A=/auth/prefixos/192.0.2.0_25
t_novo="$(aba -b "$J" "$B/bloqueios/novo")"; f_alvo="$(tem30 'name="alvo"')"; f_dias="$(tem30 'name="dias" type="number" min="1" max="3650" step="1" required value="2"')"; f_acao="$(tem30 'action="/bloqueios/novo"')"
r_n1="$(novo30 2001:DB8:AA:0:0:0:0:1 10)"; arq_n="$(dono30 "/auth/enderecos/$N6")"; quem_n="$(quem30 "$N6")"; prazo_n="$(prazo30 "$N6")"
r_n2="$(novo30 "$N6" 30)"; resta_n2="$(resta30 "$N6")"
r_n3="$(prazo_web30 "$N6" 1)"; resta_n3="$(resta30 "$N6")"; quem_n3="$(quem30 "$N6")"
web_n="$(ver30 "$N6" /entrar)"; ftp_n="$(porteiro30 end30 "$N6")"
r_p1="$(novo30 2001:db8:99:1::5/48 15)"; arq_p="$(dono30 "$NPA")"; pasta_p="$(dono30 /auth/prefixos)"; quem_p="$(quem_de30 "$NPA")"; resta_p="$(resta_de30 "$NPA")"
web_pd="$(ver30 2001:db8:99:ffff::1 /entrar)"; txt_pd="$(tem30 "$TEXTO30")"; ftp_pd="$(porteiro30 end30 2001:db8:99:ffff::1)"; web_pf="$(ver30 2001:db8:98::1 /entrar)"; ftp_pf="$(porteiro30 end30 2001:db8:98::1)"
r_p2="$(prazo_web30 "$NP" 60)"; resta_p2="$(resta_de30 "$NPA")"
r_p3="$(novo30 192.0.2.77/25 15)"; arq_4="$(dono30 "$N4A")"
web_4d="$(ver30 192.0.2.5 /entrar)"; ftp_4d="$(porteiro30 end30 192.0.2.5)"; web_4f="$(ver30 192.0.2.200 /entrar)"; ftp_4f="$(porteiro30 end30 192.0.2.200)"
sleep 5   # a lista da aba é relida a cada 5 s
t_tres="$(aba -b "$J" "$B/bloqueios?m=bloqueado")"
l_p="$(tem30 "<td class=\"origem\"><strong><code>$NP</code></strong></td><td data-rotulo=\"Bloqueado por\">Administrador</td>")"; l_4="$(tem30 "<td class=\"origem\"><strong><code>$N4</code></strong></td><td data-rotulo=\"Bloqueado por\">Administrador</td>")"
l_6="$(tem30 "<td class=\"origem\"><strong><code>$N6</code></strong></td><td data-rotulo=\"Bloqueado por\">Administrador</td>")"; l_tres="$(tem30 'Agora: 3 bloqueios em vigor.')"
l_botao="$(tem30 'href="/bloqueios/novo"')"; l_coluna="$(tem30 '<th>Endereço ou prefixo</th>')"; l_aviso="$(tem30 'Bloqueio gravado: vale no FTP e no painel a partir do próximo pedido.')"
t_pre="$(aba -b "$J" --get --data-urlencode "ip=$NP" "$B/bloqueios/endereco")"; u_pre="$(tem30 "Bloqueio de <code>$NP</code>")"; u_volta="$(tem30 'Os endereços deste prefixo voltam a entrar no FTP e no painel no próximo pedido.')"; u_adm="$(tem30 'Bloqueado por <strong>Administrador</strong>, em ')"
# Prefixo que pega um endereço de verdade do FTP: a entrada dele é recusada com a senha certa, e nada é gravado por baixo do prefixo.
pre_ga="$(docker exec "$FTP" perl /usr/local/lib/allsafe/endereco.pl alvo "$GA/29" 2>/dev/null | cut -d' ' -f2)"
rec_0="$(vigia30 "entrada recusada pelo bloqueio do endereço: origem=$GA")"
r_g1="$(novo30 "$GA/29" 1)"; ftp_g="$(tenta30 "$FA" tls end30 "$W/end30.senha")"; ftp_gs="$(tenta30 "$FA" puro st30a "$W/st30a.senha" --ftp-port -)"
ev=""; for n in 1 2 3 4; do ev+="$(erra30 "$FA" tls "fantasma30p$n"); "; done
sleep 2
rec_1="$(vigia30 "entrada recusada pelo bloqueio do endereço: origem=$GA")"; baixo_g="$(solto30 "$GA" && echo nenhum || echo gravado)"; web_g="$(ver30 "$GA" /entrar)"; ftp_gb="$(tenta30 "$FB" tls end30 "$W/end30.senha")"
r_g2="$(liberar_web30 "$pre_ga")"; volta_g="$(tenta30 "$FA" tls end30 "$W/end30.senha")"; web_gv="$(ver30 "$GA" /entrar)"
r_s1="$(liberar_web30 "$N6")"; r_s2="$(liberar_web30 "$NP")"; r_s3="$(liberar_web30 "$N4")"; r_s4="$(liberar_web30 "$NP")"
web_fim="$(ver30 2001:db8:99:ffff::1 /entrar)"; ftp_fim="$(porteiro30 end30 192.0.2.5)"; pasta_f="$(pasta30)"; pref_f="$(prefixos30)"
auditoria
a_n1="$(grep -c " evento=endereco_bloqueado_manual admin=$ADMIN endereco=$N6 dias=10\$" "$W/auditoria")"; a_n2="$(grep -c " evento=endereco_prazo admin=$ADMIN endereco=$N6 dias=30\$" "$W/auditoria")"
a_n3="$(grep -c " evento=endereco_prazo admin=$ADMIN endereco=$N6 dias=1\$" "$W/auditoria")"; a_p1="$(grep -c " evento=endereco_bloqueado_manual admin=$ADMIN endereco=$NP dias=15\$" "$W/auditoria")"
a_p2="$(grep -c " evento=endereco_prazo admin=$ADMIN endereco=$NP dias=60\$" "$W/auditoria")"; a_p3="$(grep -c " evento=endereco_bloqueado_manual admin=$ADMIN endereco=$N4 dias=15\$" "$W/auditoria")"
a_s="$(grep -c " evento=endereco_desbloqueado admin=$ADMIN endereco=$NP\$" "$W/auditoria")"
d_manual=$(( $(eventos endereco_bloqueado_manual) - n_manual )); d_prazo=$(( $(eventos endereco_prazo) - n_prazo )); d_solto=$(( $(eventos endereco_desbloqueado) - n_solto ))
t_log="$(aba -b "$J" "$B/atividade")"; v_manual="$(tem30 'Endereço ou prefixo bloqueado pelo administrador')"
[[ "$t_novo" == "200 " && "$f_alvo" == 1 && "$f_dias" == 1 && "$f_acao" == 1 \
  && "$r_n1" == "303 /bloqueios?m=bloqueado" && "$arq_n" == "root:root 600 " && "$quem_n" == "0 manual" && "$prazo_n" == 864000 \
  && "$r_n2" == "303 /bloqueios?m=prazo" && "$resta_n2" == 30 && "$r_n3" == "303 /bloqueios?m=prazo" && "$resta_n3" == 1 && "$quem_n3" == "0 manual" && "$web_n" == 403 && "$ftp_n" == "auth_ok:-1" \
  && "$r_p1" == "303 /bloqueios?m=bloqueado" && "$arq_p" == "root:root 600 " && "$pasta_p" == "root:root 700 " && "$quem_p" == "0 manual" && "$resta_p" == 15 \
  && "$web_pd" == 403 && "$txt_pd" == 1 && "$ftp_pd" == "auth_ok:-1" && "$web_pf" == 200 && "$ftp_pf" == "auth_ok:0" && "$r_p2" == "303 /bloqueios?m=prazo" && "$resta_p2" == 60 \
  && "$r_p3" == "303 /bloqueios?m=bloqueado" && "$arq_4" == "root:root 600 " && "$web_4d" == 403 && "$ftp_4d" == "auth_ok:-1" && "$web_4f" == 200 && "$ftp_4f" == "auth_ok:0" \
  && "$t_tres" == "200 " && "$l_p" == 1 && "$l_4" == 1 && "$l_6" == 1 && "$l_tres" == 1 && "$l_botao" -ge 1 && "$l_coluna" == 1 && "$l_aviso" == 1 \
  && "$t_pre" == "200 " && "$u_pre" == 1 && "$u_volta" == 1 && "$u_adm" == 1 \
  && -n "$pre_ga" && "$r_g1" == "303 /bloqueios?m=bloqueado" && "$ftp_g" == "67 530" && "$ftp_gs" == "67 530" && "$ev" == "67 530; 67 530; 67 530; 67 530; " \
  && $((rec_1 - rec_0)) -ge 6 && "$baixo_g" == nenhum && "$web_g" == 403 && "$ftp_gb" == "0 226" && "$r_g2" == "303 /bloqueios?m=liberado" && "$volta_g" == "0 226" && "$web_gv" == 200 \
  && "$r_s1" == "303 /bloqueios?m=liberado" && "$r_s2" == "303 /bloqueios?m=liberado" && "$r_s3" == "303 /bloqueios?m=liberado" && "$r_s4" == "303 /bloqueios?m=ausente" \
  && "$web_fim" == 200 && "$ftp_fim" == "auth_ok:0" && -z "$pasta_f" && -z "$pref_f" \
  && "$a_n1" == 1 && "$a_n2" == 1 && "$a_n3" == 1 && "$a_p1" == 1 && "$a_p2" == 1 && "$a_p3" == 1 && "$a_s" == 1 && "$d_manual" == 4 && "$d_prazo" == 3 && "$d_solto" == 4 \
  && "$t_log" == "200 " && "$v_manual" -ge 1 ]]
caso $? testes 66 "Aba Bloqueios: bloquear endereço e prefixo, IPv4 e IPv6, estender, encurtar e desbloquear" "tela GET /bloqueios/novo: $t_novo, campo do endereço ou prefixo: $f_alvo, campo dos dias com o prazo da stack (2): $f_dias, formulário: $f_acao · endereço escrito 2001:DB8:AA:0:0:0:0:1 por 10 dias: $r_n1; arquivo /auth/enderecos/$N6 (a escrita única): ${arq_n}com erros e autor '$quem_n' e prazo de $prazo_n s (10 dias = 864000) · o mesmo endereço de novo, com 30 dias (estender): $r_n2, dias que faltam: $resta_n2; pela tela dele, para 1 dia (encurtar): $r_n3, dias que faltam: $resta_n3, autor mantido: '$quem_n3'; tela de entrada desse endereço: $web_n, porteiro do FTP: $ftp_n · prefixo escrito 2001:db8:99:1::5/48 por 15 dias: $r_p1; arquivo $NPA: ${arq_p}pasta ${pasta_p}com erros e autor '$quem_p', dias que faltam: $resta_p; endereço de dentro: tela de entrada $web_pd com o texto da recusa: $txt_pd, porteiro: $ftp_pd; de fora: $web_pf e $ftp_pf; prazo do prefixo para 60 dias: $r_p2, dias que faltam: $resta_p2 · prefixo IPv4 escrito 192.0.2.77/25: $r_p3, arquivo $N4A: ${arq_4}de dentro (192.0.2.5): $web_4d e $ftp_4d, de fora (192.0.2.200): $web_4f e $ftp_4f · lista: $t_tres, linha de $NP por Administrador: $l_p, de $N4: $l_4, de $N6: $l_6, 'Agora: 3 bloqueios em vigor.': $l_tres, botão do bloqueio novo: $l_botao, coluna 'Endereço ou prefixo': $l_coluna, aviso 'Bloqueio gravado': $l_aviso · tela do prefixo: $t_pre, título: $u_pre, 'Os endereços deste prefixo voltam a entrar': $u_volta, autor sem contagem de erros: $u_adm · prefixo $pre_ga, que pega o endereço $GA: $r_g1; do endereço, a senha certa no FTP com TLS: $ftp_g e sem TLS em modo ativo: $ftp_gs; quatro nomes que não existem: ${ev}linhas 'entrada recusada pelo bloqueio do endereço: origem=$GA' a mais no registro: $((rec_1 - rec_0)); bloqueio do endereço por baixo do prefixo: $baixo_g; tela de entrada do painel: $web_g; de outro endereço ($GB) no FTP: $ftp_gb; prefixo desbloqueado pela web: $r_g2, FTP: $volta_g, tela de entrada: $web_gv · desbloqueio pela web do endereço: $r_s1, do prefixo IPv6: $r_s2, do IPv4: $r_s3, e do prefixo já liberado: $r_s4; endereço de dentro do prefixo IPv6 na tela de entrada: $web_fim, de dentro do IPv4 no porteiro: $ftp_fim; endereços bloqueados: '${pasta_f}', prefixos: '${pref_f}' · auditoria: endereco_bloqueado_manual do endereço com 10 dias: $a_n1, do prefixo IPv6 com 15: $a_p1, do IPv4: $a_p3, a mais ao todo: $d_manual (com o prefixo de $GA); endereco_prazo com 30 dias: $a_n2, com 1: $a_n3, do prefixo com 60: $a_p2, a mais: $d_prazo; endereco_desbloqueado do prefixo: $a_s, a mais: $d_solto · aba Log: $t_log, 'Endereço ou prefixo bloqueado pelo administrador': $v_manual"

# ------------------------------------------------------------------ a web recusa: o próprio endereço, a stack, o servidor, fora da regra e quem não é administrador
auditoria; n_manual="$(eventos endereco_bloqueado_manual)"; n_prazo="$(eventos endereco_prazo)"; c_antes="$(eventos recusa_csrf)"; o_antes="$(eventos recusa_origem)"; n_papel="$(eventos recusa_papel)"
pasta_r0="$(pasta30)"; pref_r0="$(prefixos30)"
PROPRIO30="Este bloqueio pegaria o endereço de onde você está usando o painel ($Z). Nada foi bloqueado."
STACK30='Este bloqueio pegaria a rede interna da stack ou um proxy confiável, por onde chegam os visitantes. Nada foi bloqueado.'
rede_stack="$(docker network inspect -f '{{(index .IPAM.Config 0).Subnet}}' "$NOME-network" 2>/dev/null)"; ip_painel="$(docker inspect -f "{{(index .NetworkSettings.Networks \"$NOME-network\").IPAddress}}" "$PAINEL" 2>/dev/null)"
aberta_r="$(aba -b "$Z30" -H "X-Forwarded-For: $Z" "$B/bloqueios/novo")"
ev=""; ok=0
for v in "$Z" 198.51.100.0/24 198.0.0.0/8 "::ffff:$Z"; do
  r="$(recusa30 "$Z30" "$KZ" "$v" 5 -H "X-Forwarded-For: $Z")"; [[ "$r" == 400 && "$(tem30 "$PROPRIO30")" == 1 ]] || ok=1; ev+="$v: $r; "
done
ev_s=""
for v in "$origem30" "$rede_stack" "$ip_painel" 172.16.0.0/12; do
  r="$(recusa30 "$Z30" "$KZ" "$v" 5 -H "X-Forwarded-For: $Z")"; [[ -n "$v" && "$r" == 400 && "$(tem30 "$STACK30")" == 1 ]] || ok=1; ev_s+="$v: $r; "
done
ev_l=""
for v in 127.0.0.1 ::1 0.1.2.3 127.0.0.0/8 ::/16 0.0.0.0/8 ::ffff:127.0.0.1; do
  r="$(recusa30 "$J" "$K" "$v" 5)"; [[ "$r" == 400 && "$(tem30 'Este endereço é do próprio servidor: não pode ser bloqueado.')" == 1 ]] || ok=1; ev_l+="$v: $r; "
done
ev_i=""
for v in 10.0.0.0/7 192.0.2.1/32 2001:db8::/15 2001:db8::/128 abc '2001:db8::1%eth0' '' '1.2.3.4;id' '../x' 01.2.3.4 203.0.113.0/24/1 203.0.113.0/024 "$(printf '203.0.113.7\n203.0.113.8')"; do
  r="$(recusa30 "$J" "$K" "$v" 5)"; [[ "$r" == 400 && "$(tem30 'Endereço ou prefixo inválido: use um IPv4, um IPv6 ou um prefixo')" == 1 ]] || ok=1; ev_i+="'$(tr '\n' '|' <<< "$v" | sed 's/|$//')': $r; "
done
ev_d=""
for v in 0 3651 abc -5 1.5 1e2 0x10 '１' 12345 ''; do
  r="$(recusa30 "$J" "$K" 203.0.113.50 "$v")"; [[ "$r" == 400 && "$(tem30 'Prazo inválido: de 1 a 3650 dias.')" == 1 ]] || ok=1; ev_d+="dias='$v': $r; "
done
campos=(--data-urlencode 'alvo=203.0.113.51' --data-urlencode 'dias=5')
r_token="$(envio /bloqueios/novo "${campos[@]}")"; r_errado="$(envio /bloqueios/novo --data-urlencode 'csrf=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' "${campos[@]}")"
r_origem="$(c -o /dev/null -w '%{http_code}' -b "$J" -H 'Origin: https://site-de-fora.example' --data-urlencode "csrf=$K" "${campos[@]}" "$B/bloqueios/novo")"
r_sem="$(aba "$B/bloqueios/novo")"; r_sem_post="$(c -o /dev/null -w '%{http_code} %{redirect_url}' -H "Origin: $B" --data-urlencode "csrf=$K" "${campos[@]}" "$B/bloqueios/novo" | sed "s|$B||")"
# Usuário do FTP (perfil Completo), com a sessão e o token dele: a rota não existe para ele.
e_usu="$(COMO=end30 entrar "$U30" "$W/end30.senha")"; proibir "$(biscoito_de "$U30")"
UK="$(c -b "$U30" "$B/meus-arquivos" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1)"; proibir "$UK"
r_usu="$(aba -b "$U30" "$B/bloqueios/novo")"; r_usu_p="$(POTE="$U30" envio /bloqueios/novo --data-urlencode "csrf=$UK" "${campos[@]}")"
# Prefixo é só do administrador: o programa que grava o bloqueio não aceita prefixo em nome do FTP nem do painel.
docker exec "$FTP" allsafe-ftp-user endereco-bloquear 203.0.113.0/24 5 ftp 6 > "$W/mu.log" 2>&1; r_af=$?
docker exec "$FTP" allsafe-ftp-user endereco-bloquear 2001:db8:77::/48 5 painel 4 > "$W/mu.log" 2>&1; r_ap=$?
docker exec "$FTP" allsafe-ftp-user endereco-bloquear 203.0.113.53 5 root 0 > "$W/mu.log" 2>&1; r_ar=$?
auditoria
d_manual=$(( $(eventos endereco_bloqueado_manual) - n_manual )); d_prazo=$(( $(eventos endereco_prazo) - n_prazo ))
# A auditoria guarda uma linha por minuto de cada tipo de recusa do mesmo endereço: a conta é de pelo menos uma.
d_csrf=$(( $(eventos recusa_csrf) - c_antes )); d_origem=$(( $(eventos recusa_origem) - o_antes )); d_papel=$(( $(eventos recusa_papel) - n_papel ))
pasta_r1="$(pasta30)"; pref_r1="$(prefixos30)"
[[ "$aberta_r" == "200 " && -n "$rede_stack" && -n "$ip_painel" && "$ok" == 0 && "$r_token" == "403 " && "$r_errado" == "403 " && "$r_origem" == 403 && "$r_sem" == "303 /entrar" && "$r_sem_post" == "303 /entrar" \
  && "$e_usu" == 303 && -n "$UK" && "$r_usu" == "404 " && "$r_usu_p" == "404 " && "$r_af" != 0 && "$r_ap" != 0 && "$r_ar" != 0 \
  && "$d_manual" == 0 && "$d_prazo" == 0 && "$d_csrf" -ge 1 && "$d_origem" -ge 1 && "$d_papel" -ge 1 && -z "$pasta_r0" && -z "$pref_r0" && -z "$pasta_r1" && -z "$pref_r1" ]]
caso $? seguranca 118 "Bloqueio novo pela web: recusa o próprio endereço, a stack, o servidor e o que está fora da regra; prefixo só do administrador" "administrador com sessão vinda de $Z (tela do bloqueio novo: $aberta_r), tentando bloquear o que pega o endereço dele, todos com 400 e o aviso 'Este bloqueio pegaria o endereço de onde você está usando o painel': ${ev}· o que pega o proxy aceito, a rede interna da stack ou o container do painel, com 400 e o aviso 'Este bloqueio pegaria a rede interna da stack ou um proxy confiável': ${ev_s}· do próprio servidor, com 400 e 'Este endereço é do próprio servidor': ${ev_l}· fora da regra, com 400 e 'Endereço ou prefixo inválido': ${ev_i}· prazo fora da regra, com 400 e 'Prazo inválido: de 1 a 3650 dias.': ${ev_d}· todas as recusas com a resposta esperada: $([[ "$ok" == 0 ]] && echo sim || echo NÃO) · sem token: $r_token, com token errado: $r_errado, com Origin de outro site: $r_origem; sem sessão: tela $r_sem e envio $r_sem_post · usuário do FTP com a sessão e o token dele (entrada: $e_usu): tela $r_usu, envio $r_usu_p · pelo programa que grava (allsafe-ftp-user endereco-bloquear), prefixo em nome do FTP: saída $r_af, em nome do painel: saída $r_ap; autor que não existe: saída $r_ar · auditoria: endereco_bloqueado_manual a mais: $d_manual, endereco_prazo a mais: $d_prazo, recusa_csrf a mais: $d_csrf, recusa_origem a mais: $d_origem, recusa_papel a mais: $d_papel · endereços bloqueados antes '${pasta_r0}' e depois '${pasta_r1}'; prefixos antes '${pref_r0}' e depois '${pref_r1}'"

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
