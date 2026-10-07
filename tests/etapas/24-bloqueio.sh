#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa X: bloqueio por tentativa no FTP. O limite do usuário gravado pelo painel e pelo terminal, o bloqueio
# do usuário para o endereço que errou a senha, o desbloqueio, o vencimento, o padrão da stack, o que não
# conta para o bloqueio, as transferências no registro do container, a queda do vigia e as recusas sem sessão,
# sem token e fora da regra.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel zera a contagem de falhas de entrada e das recusas e encerra as sessões.
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"

U24="$W/u24.jar"
arquivos24() { docker exec "$FTP" sh -c 'ls -A /auth/bloqueios 2>/dev/null' | tr '\n' ' '; }               # tudo o que há na pasta dos bloqueios
de24() { docker exec "$FTP" sh -c 'ls -A /auth/bloqueios 2>/dev/null' | grep -c "^$1@"; }                  # <usuário> → quantos bloqueios ele tem
origem24() { docker exec "$FTP" sh -c 'ls -A /auth/bloqueios 2>/dev/null' | sed -n "s/^$1@//p" | head -1; }  # <usuário> → o endereço bloqueado
conteudo24() { docker exec "$FTP" sh -c "cat '/auth/bloqueios/$1' 2>/dev/null" | tr '\n' ' '; }            # <arquivo> → "<vale até> <desde> <senhas erradas> "
prazo24() { local a b _; read -r a b _ <<< "$(conteudo24 "$1")"; [[ "$a" =~ ^[0-9]+$ && "$b" =~ ^[0-9]+$ ]] && echo $((a - b)) || echo '?'; }  # <arquivo> → segundos de bloqueio
erradas24() { local _ n; read -r _ _ n _ <<< "$(conteudo24 "$1")"; echo "${n:-?}"; }                        # <arquivo> → senhas erradas gravadas
lista24() { docker exec "$FTP" sh -c 'cat /auth/limites.lista 2>/dev/null' | tr '\n' ';'; }
cadastro24() { docker exec "$FTP" sh -c 'cat /auth/pureftpd.passwd /auth/limites.lista 2>/dev/null | sha256sum' | cut -c1-16; }
login24() { local r; r="$(ftp_curl tls "$1" "$2" -l "$F/")"; echo "$r $(resposta '(226|421|530) ' | cut -c1-3)"; }  # <usuário> <arquivo da senha> → "0 226" ou "67 530"
# <usuário> <vezes>: senhas erradas ao mesmo tempo, com TLS → quantas o servidor recusou com 530
erra24() {
  local n; local -a lote=()
  for n in $(seq 1 "$2"); do
    ( ( umask 077; printf 'user = "%s:%s"\n' "$1" "$(tr -d '\r\n' < "$W/errada24.senha")" > "$W/e24.cfg-$n" )
      curl -sS -v --max-time 40 -K "$W/e24.cfg-$n" --ssl-reqd -k -l "$F/" > /dev/null 2> "$W/e24.err-$n"
      grep -a -c '^< 530 ' "$W/e24.err-$n" > "$W/e24.fim-$n"; rm -f "$W/e24.cfg-$n" "$W/e24.err-$n" ) & lote+=("$!")
  done
  wait "${lote[@]}"
  cat "$W"/e24.fim-* 2>/dev/null | grep -c -x 1; rm -f "$W"/e24.fim-*
}
# <usuário> <campo=valor>...: POST /usuarios/limites com os campos dados → "código destino"
limites24() {
  local usuario="$1" par; local -a campos=(--data-urlencode "csrf=$K" --data-urlencode "usuario=$usuario"); shift
  for par in "$@"; do campos+=(--data-urlencode "$par"); done
  envio /usuarios/limites "${campos[@]}"
}
desbloquear24() { envio /usuarios/desbloquear --data-urlencode "csrf=$K" --data-urlencode "usuario=$1"; }  # <usuário> → "código destino"
log24() { docker logs "$FTP" > "$W/ftp.log" 2>&1; }
vigia24() { grep -c -- "vigia: $1" "$W/ftp.log"; }                                                         # <trecho>: linhas do vigia no log do FTP
linha24() { grep -c -x -F -- "vigia: $1" "$W/ftp.log"; }                                                  # <linha inteira do vigia>: vezes em que aparece no log do FTP
contar24() { grep -o -- "$1" "$W/corpo" | wc -l; }                                                         # <trecho>: vezes em que aparece na última tela
# Processos do vigia dentro do container do FTP.
vivos24() { docker exec "$FTP" sh -c 'for p in /proc/[0-9]*; do tr "\000" " " < "$p/cmdline" 2>/dev/null; echo; done' | grep -c '^/usr/bin/perl /usr/local/sbin/allsafe-ftp-vigia'; }

for n in u24 u24b o24 errada24; do nova_senha "$W/$n.senha"; done

# ------------------------------------------------------------------ limite do usuário pelo painel, bloqueio e desbloqueio
r_novo="$(envio /usuarios/novo --data-urlencode "csrf=$K" --data-urlencode 'usuario=blq24' --data-urlencode "senha@$W/u24.senha" --data-urlencode "confirmacao@$W/u24.senha")"
mu add outro24 "$W/o24.senha"; r_outro=$?
l_0="$(login24 blq24 "$W/u24.senha")"
tela="$(aba -b "$J" "$B/usuarios/editar?usuario=blq24")"
campo_t="$(grep -c 'name="tentativas" type="number" min="0" max="100"' "$W/corpo")"; campo_m="$(grep -c 'name="minutos" type="number" min="1" max="1440"' "$W/corpo")"
padrao_t="$(contar24 'vazio: 5, o padrão da stack; 0: este usuário nunca é bloqueado')"; padrao_m="$(contar24 'vazio: 15, o padrão da stack')"; cartao_0="$(contar24 'id="bloqueios"')"
auditoria; n_antes="$(eventos bloqueio_removido)"
r_grava="$(limites24 blq24 'tentativas=3' 'minutos=2')"; l_painel="$(lista24)"
aba -b "$J" "$B/usuarios" > /dev/null; etiqueta_l="$(contar24 'title="Limites próprios: senhas erradas até o bloqueio: 3 · minutos de bloqueio: 2"')"; etiqueta_0="$(contar24 'vindas de: ')"
t_tent="$(aba -b "$J" "$B/usuarios/editar?usuario=blq24" > /dev/null; grep -c 'name="tentativas"[^>]* value="3"' "$W/corpo")"; t_min="$(grep -c 'name="minutos"[^>]* value="2"' "$W/corpo")"
auditoria; registro_l="$(grep -c " evento=limites_alterados admin=$ADMIN usuario=blq24 sessoes=- download=- envio=- horario=- baixar=- tentativas=3 minutos=2\$" "$W/auditoria")"
# Duas erradas e a certa, duas vezes: a entrada certa zera a contagem, e as quatro erradas não bloqueiam.
e_1="$(erra24 blq24 2)"; l_1="$(login24 blq24 "$W/u24.senha")"; e_2="$(erra24 blq24 2)"; l_2="$(login24 blq24 "$W/u24.senha")"; b_antes="$(de24 blq24)"
# A terceira errada em sequência bloqueia: a senha certa passa a ser recusada para o endereço que errou.
e_3="$(erra24 blq24 3)"; l_3="$(login24 blq24 "$W/u24.senha")"; b_depois="$(de24 blq24)"; ORIGEM24="$(origem24 blq24)"; ARQ24="blq24@$ORIGEM24"
porta_saida="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.Gateway}}{{end}}' "$FTP")"
modo="$(docker exec "$FTP" stat -c '%U:%G %a' /auth/bloqueios "/auth/bloqueios/$ARQ24" 2>/dev/null | tr '\n' ' ')"; b_erradas="$(erradas24 "$ARQ24")"; b_prazo="$(prazo24 "$ARQ24")"
log24; v_contadas="$(vigia24 "entrada recusada: usuario=blq24 origem=$ORIGEM24 senhas_erradas=")"; v_ultima="$(vigia24 "entrada recusada: usuario=blq24 origem=$ORIGEM24 senhas_erradas=3 de 3")"
v_bloqueio="$(vigia24 "entrada bloqueada: usuario=blq24 origem=$ORIGEM24 senhas_erradas=3 minutos=2")"; v_recusa="$(vigia24 "entrada recusada pelo bloqueio: usuario=blq24 origem=$ORIGEM24")"
v_entradas="$(vigia24 "entrada: usuario=blq24 origem=$ORIGEM24")"; nos_logs="$(segredos_em "$W/ftp.log")"
# O bloqueio é só deste usuário e só para aquele endereço: outro usuário do mesmo endereço entra, e ele entra no painel.
l_outro="$(login24 outro24 "$W/o24.senha")"; e_painel="$(COMO=blq24 entrar "$U24" "$W/u24.senha")"; proibir "$(biscoito_de "$U24")"
aba -b "$J" "$B/usuarios" > /dev/null; etiqueta_b="$(contar24 "title=\"Senhas erradas demais no FTP, vindas de: $ORIGEM24\">⛔ bloqueado")"
aba -b "$J" "$B/usuarios/editar?usuario=blq24" > /dev/null; cartao_1="$(contar24 'id="bloqueios"')"; linha_1="$(contar24 "<td><code>$ORIGEM24</code></td><td>3</td>")"; botao_1="$(contar24 'action="/usuarios/desbloquear"')"
aba -b "$J" "$B/seguranca" > /dev/null; seg_1="$(contar24 'Bloqueado agora: blq24\.')"; seg_regra="$(contar24 '5 senhas erradas do mesmo endereço bloqueiam o usuário para aquele endereço por 15 minutos')"
r_desb="$(desbloquear24 blq24)"; b_fim="$(de24 blq24)"; l_4="$(login24 blq24 "$W/u24.senha")"
aba -b "$J" "$B/usuarios?m=desbloqueado" > /dev/null; aviso="$(contar24 'Bloqueio removido')"; etiqueta_f="$(contar24 'vindas de: ')"
aba -b "$J" "$B/usuarios/editar?usuario=blq24" > /dev/null; cartao_2="$(contar24 'id="bloqueios"')"
aba -b "$J" "$B/seguranca" > /dev/null; seg_2="$(contar24 'Nenhum usuário bloqueado agora')"
auditoria; n_depois="$(eventos bloqueio_removido)"; registro_d="$(grep -c " evento=bloqueio_removido admin=$ADMIN usuario=blq24 origens=1\$" "$W/auditoria")"
atividade="$(aba -b "$J" "$B/atividade")"; na_atividade="$(contar24 'Bloqueio do usuário no FTP removido')"
[[ "$e_adm" == 303 && "$r_novo" == "303 /usuarios?m=criado" && "$r_outro" == 0 && "$l_0" == "0 226" && "$tela" == "200 " && "$campo_t" == 1 && "$campo_m" == 1 \
  && "$padrao_t" == 1 && "$padrao_m" == 1 && "$cartao_0" == 0 && "$r_grava" == "303 /usuarios?m=limites" && "$l_painel" == "blq24 tentativas=3 minutos=2;" \
  && "$etiqueta_l" == 1 && "$etiqueta_0" == 0 && "$t_tent" == 1 && "$t_min" == 1 && "$registro_l" == 1 \
  && "$e_1" == 2 && "$l_1" == "0 226" && "$e_2" == 2 && "$l_2" == "0 226" && "$b_antes" == 0 \
  && "$e_3" == 3 && "$l_3" == "67 530" && "$b_depois" == 1 && "$ORIGEM24" =~ ^[0-9a-fA-F.:]{2,45}$ && "$modo" == "root:root 700 root:root 600 " && "$b_erradas" == 3 && "$b_prazo" == 120 \
  && "$v_contadas" == 7 && "$v_ultima" == 1 && "$v_bloqueio" == 1 && "$v_recusa" == 1 && "$v_entradas" -ge 3 && "$nos_logs" == 0 \
  && "$l_outro" == "0 226" && "$e_painel" == 303 && "$etiqueta_b" == 1 && "$cartao_1" == 1 && "$linha_1" == 1 && "$botao_1" == 1 && "$seg_1" == 1 && "$seg_regra" == 1 \
  && "$r_desb" == "303 /usuarios?m=desbloqueado" && "$b_fim" == 0 && "$l_4" == "0 226" && "$aviso" -ge 1 && "$etiqueta_f" == 0 && "$cartao_2" == 0 && "$seg_2" == 1 \
  && "$n_depois" == $((n_antes + 1)) && "$registro_d" == 1 && "$atividade" == "200 " && "$na_atividade" -ge 1 ]]
caso $? testes 47 "Bloqueio por tentativa no FTP: limite do usuário pelo painel, bloqueio e desbloqueio" "usuário blq24 criado pelo painel ($r_novo), entra no FTP: $l_0 · tela Editar: $tela, campo das senhas erradas (0 a 100): $campo_t, campo dos minutos (1 a 1440): $campo_m, padrão da stack mostrado nos dois (5 e 15): $padrao_t e $padrao_m, cartão Bloqueios antes de haver bloqueio: $cartao_0 · POST /usuarios/limites com 3 senhas erradas e 2 minutos: $r_grava, lista dos limites: $l_painel etiqueta limites com o resumo: $etiqueta_l, de volta na tela: $t_tent e $t_min, auditoria com cada limite: $registro_l · 2 senhas erradas (recusadas com 530: $e_1), a certa: $l_1, mais 2 erradas ($e_2), a certa: $l_2, bloqueios: $b_antes (a entrada certa zerou a contagem) · 3 senhas erradas em seguida ($e_3) e a senha certa: $l_3 · bloqueios: $b_depois, para a origem $ORIGEM24 (saída da rede da stack: ${porta_saida:-?}) · pasta e arquivo do bloqueio: $modo· senhas erradas gravadas: $b_erradas, prazo: $b_prazo s · no registro do FTP, senhas erradas contadas: $v_contadas, a terceira de 3: $v_ultima, bloqueio: $v_bloqueio, tentativa com a senha certa recusada pelo bloqueio: $v_recusa, entradas certas: $v_entradas, senhas no registro: $nos_logs · outro usuário, do mesmo endereço: $l_outro · o próprio blq24 no painel: $e_painel · etiqueta bloqueado na lista, com a origem: $etiqueta_b · tela Editar, cartão Bloqueios: $cartao_1, linha com a origem e as 3 senhas erradas: $linha_1, botão Desbloquear: $botao_1 · aba Segurança, regra da stack: $seg_regra, bloqueado agora: $seg_1 · POST /usuarios/desbloquear: $r_desb, bloqueios: $b_fim, senha certa: $l_4 · aviso na lista: $aviso, etiqueta: $etiqueta_f, cartão Bloqueios: $cartao_2, aba Segurança sem bloqueado: $seg_2 · auditoria bloqueio_removido: $n_antes → $n_depois, linha com o administrador, o usuário e a quantidade de origens: $registro_d · aba Atividade: $atividade, evento na tela: $na_atividade"

# ------------------------------------------------------------------ terminal, vencimento, padrão da stack e o que tira o bloqueio
mu limites blq24 "" tentativas=2 minutos=1; t_grava=$?; l_term="$(lista24)"
mu limites blq24; mostra="$(tr '\n' ' ' < "$W/mu.log")"
e_1="$(erra24 blq24 2)"; l_1="$(login24 blq24 "$W/u24.senha")"; p_1="$(prazo24 "$ARQ24")"; read -r vence _ <<< "$(conteudo24 "$ARQ24")"
mu bloqueios; t_b=$?; fala_b="$(grep -c "^usuario=blq24 origem=$ORIGEM24 senhas_erradas=2 desde=[0-9: -]* ate=[0-9: -]*\$" "$W/mu.log")"
mu bloqueios blq24; fala_dele="$(grep -c '^usuario=blq24 ' "$W/mu.log")"; mu bloqueios outro24; fala_outro="$(grep -c '^Nenhum bloqueio em vigor' "$W/mu.log")"
# O bloqueio de 1 minuto vence sozinho: a senha certa volta a entrar, sem ninguém desbloquear.
falta=$(( ${vence:-0} - $(date +%s) + 2 )); (( falta > 0 && falta < 90 )) && sleep "$falta"
l_venceu="$(login24 blq24 "$W/u24.senha")"; mu bloqueios blq24; fala_venceu="$(grep -c '^Nenhum bloqueio em vigor' "$W/mu.log")"
# Desbloqueio pelo terminal: origem que não é a do bloqueio não tira nada; a certa tira.
e_2="$(erra24 blq24 2)"; l_2="$(login24 blq24 "$W/u24.senha")"
mu desbloquear blq24 "" 192.0.2.9; t_d0=$?; fala_d0="$(grep -c '^Usuario blq24 nao tem bloqueio para 192.0.2.9' "$W/mu.log")"; b_d0="$(de24 blq24)"
mu desbloquear blq24 "" "$ORIGEM24"; t_d1=$?; fala_d1="$(grep -c '^Usuario blq24 desbloqueado (1 endereco(s))' "$W/mu.log")"; b_d1="$(de24 blq24)"; l_3="$(login24 blq24 "$W/u24.senha")"
# tentativas=0: o usuário nunca é bloqueado, erre quantas vezes errar.
mu limites blq24 "" tentativas=0 minutos=; l_zero="$(lista24)"; e_zero="$(erra24 blq24 6)"; b_zero="$(de24 blq24)"; l_4="$(login24 blq24 "$W/u24.senha")"
aba -b "$J" "$B/usuarios" > /dev/null; etiqueta_z="$(contar24 'title="Limites próprios: senhas erradas até o bloqueio: nunca bloqueia"')"
log24; v_desligado="$(vigia24 "entrada recusada: usuario=blq24 origem=$ORIGEM24 (bloqueio por tentativa desligado)")"
# Sem limite próprio vale o padrão da stack: 5 senhas erradas, 15 minutos.
mu limites blq24 "" tentativas= minutos=; l_vazio="$(lista24)"
e_4="$(erra24 blq24 4)"; l_5="$(login24 blq24 "$W/u24.senha")"; e_5="$(erra24 blq24 5)"; l_6="$(login24 blq24 "$W/u24.senha")"; p_padrao="$(prazo24 "$ARQ24")"; n_padrao="$(erradas24 "$ARQ24")"
# Trocar a senha tira o bloqueio: quem corrigiu a senha no equipamento não espera o prazo.
mu passwd blq24 "$W/u24b.senha"; t_senha=$?; b_senha="$(de24 blq24)"; l_7="$(login24 blq24 "$W/u24b.senha")"
# Mudar a regra do bloqueio tira os bloqueios do usuário; gravar o mesmo valor, ou outro limite, não tira.
mu limites blq24 "" tentativas=2; e_6="$(erra24 blq24 2)"; b_r0="$(de24 blq24)"
mu limites blq24 "" tentativas=2; b_r1="$(de24 blq24)"; mu limites blq24 "" sessoes=3; b_r2="$(de24 blq24)"; mu limites blq24 "" minutos=5 sessoes=; b_r3="$(de24 blq24)"
# O bloqueio é um arquivo no volume do cadastro: atravessa o reinício do FTP.
e_7="$(erra24 blq24 2)"; b_r4="$(de24 blq24)"; p_r4="$(prazo24 "$ARQ24")"
dc restart ftp > /dev/null 2>&1; esperar "$FTP"; s_reinicio="$(saude "$FTP")"; b_r5="$(de24 blq24)"; l_8="$(login24 blq24 "$W/u24b.senha")"; l_outro="$(login24 outro24 "$W/o24.senha")"
# Usuário removido leva os bloqueios: um usuário novo com o mesmo nome não nasce bloqueado.
mu add tmp24 "$W/o24.senha"; mu limites tmp24 "" tentativas=1; e_tmp="$(erra24 tmp24 1)"; b_tmp="$(de24 tmp24)"; l_tmp="$(login24 tmp24 "$W/o24.senha")"
mu del tmp24; t_del=$?; b_del="$(de24 tmp24)"; mu add tmp24 "$W/o24.senha"; l_novo="$(login24 tmp24 "$W/o24.senha")"; mu del tmp24
mu limites blq24 "" tentativas= minutos=; b_r6="$(de24 blq24)"; l_limpa="$(lista24)"
# Desligado na stack: sem limite próprio ninguém é bloqueado; com limite próprio, sim. Depois, o padrão de volta.
gravar_env "$ENVA" FTP_BLOQUEIO_TENTATIVAS 0; dep; r_desliga=$?; esperar "$FTP"; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
log24; v_pronto_0="$(vigia24 'pronto: bloqueio por tentativa desligado na stack (FTP_BLOQUEIO_TENTATIVAS=0)')"
aba -b "$J" "$B/seguranca" > /dev/null; seg_0="$(contar24 '<strong>Desligado na stack</strong>')"
aba -b "$J" "$B/usuarios/editar?usuario=blq24" > /dev/null; nota_0="$(contar24 'vazio: o padrão da stack, que está desligado')"
e_8="$(erra24 blq24 6)"; b_s0="$(de24 blq24)"; l_9="$(login24 blq24 "$W/u24b.senha")"
r_proprio="$(limites24 blq24 'tentativas=2')"; e_9="$(erra24 blq24 2)"; b_s1="$(de24 blq24)"; l_10="$(login24 blq24 "$W/u24b.senha")"; p_s1="$(prazo24 "$ARQ24")"
gravar_env "$ENVA" FTP_BLOQUEIO_TENTATIVAS 5; dep; r_liga=$?; esperar "$FTP"; painel_de_pe; s_fim="$(saude "$FTP" "$PAINEL" "$NGINX")"
e_adm2="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
log24; v_pronto_5="$(vigia24 'pronto: 5 senhas erradas do mesmo endereço bloqueiam o usuário para ele por 15 min')"; b_s2="$(de24 blq24)"
aba -b "$J" "$B/seguranca" > /dev/null; seg_5="$(contar24 '5 senhas erradas do mesmo endereço')"; seg_preso="$(contar24 'Bloqueado agora: blq24\.')"
r_tira="$(limites24 blq24)"; b_s3="$(de24 blq24)"; l_11="$(login24 blq24 "$W/u24b.senha")"; l_fim="$(lista24)"
[[ "$t_grava" == 0 && "$l_term" == "blq24 tentativas=2 minutos=1;" && "$mostra" == *"tentativas=2 minutos=1 "* \
  && "$e_1" == 2 && "$l_1" == "67 530" && "$p_1" == 60 && "$t_b" == 0 && "$fala_b" == 1 && "$fala_dele" == 1 && "$fala_outro" == 1 \
  && "$l_venceu" == "0 226" && "$fala_venceu" == 1 \
  && "$e_2" == 2 && "$l_2" == "67 530" && "$t_d0" == 0 && "$fala_d0" == 1 && "$b_d0" == 1 && "$t_d1" == 0 && "$fala_d1" == 1 && "$b_d1" == 0 && "$l_3" == "0 226" \
  && "$l_zero" == "blq24 tentativas=0;" && "$e_zero" == 6 && "$b_zero" == 0 && "$l_4" == "0 226" && "$etiqueta_z" == 1 && "$v_desligado" -ge 6 \
  && -z "$l_vazio" && "$e_4" == 4 && "$l_5" == "0 226" && "$e_5" == 5 && "$l_6" == "67 530" && "$p_padrao" == 900 && "$n_padrao" == 5 \
  && "$t_senha" == 0 && "$b_senha" == 0 && "$l_7" == "0 226" \
  && "$e_6" == 2 && "$b_r0" == 1 && "$b_r1" == 1 && "$b_r2" == 1 && "$b_r3" == 0 \
  && "$e_7" == 2 && "$b_r4" == 1 && "$p_r4" == 300 && "$s_reinicio" == "healthy " && "$b_r5" == 1 && "$l_8" == "67 530" && "$l_outro" == "0 226" \
  && "$e_tmp" == 1 && "$b_tmp" == 1 && "$l_tmp" == "67 530" && "$t_del" == 0 && "$b_del" == 0 && "$l_novo" == "0 226" && "$b_r6" == 0 && -z "$l_limpa" \
  && "$r_desliga" == 0 && "$e_adm" == 303 && "$v_pronto_0" -ge 1 && "$seg_0" == 1 && "$nota_0" == 1 && "$e_8" == 6 && "$b_s0" == 0 && "$l_9" == "0 226" \
  && "$r_proprio" == "303 /usuarios?m=limites" && "$e_9" == 2 && "$b_s1" == 1 && "$l_10" == "67 530" && "$p_s1" == 900 \
  && "$r_liga" == 0 && "$s_fim" == "healthy healthy healthy " && "$e_adm2" == 303 && "$v_pronto_5" -ge 1 && "$b_s2" == 1 && "$seg_5" == 1 && "$seg_preso" == 1 \
  && "$r_tira" == "303 /usuarios?m=limites" && "$b_s3" == 0 && "$l_11" == "0 226" && -z "$l_fim" ]]
caso $? testes 48 "Bloqueio por tentativa no FTP: terminal, vencimento e padrão da stack" "manage-user.sh limites com 2 senhas erradas e 1 minuto: saída $t_grava, lista: $l_term · manage-user.sh limites blq24: $mostra· 2 senhas erradas ($e_1) e a senha certa: $l_1, prazo do bloqueio: $p_1 s · manage-user.sh bloqueios (saída $t_b), linha com usuário, origem, senhas erradas, desde e até: $fala_b, só os de blq24: $fala_dele, os de outro usuário: nenhum ($fala_outro) · passado o minuto, sem desbloquear, a senha certa: $l_venceu, bloqueios em vigor: nenhum ($fala_venceu) · bloqueado de novo ($e_2 erradas, senha certa: $l_2), manage-user.sh desbloquear com outra origem: saída $t_d0, aviso de que não há bloqueio para ela: $fala_d0, bloqueios: $b_d0 · com a origem do bloqueio: saída $t_d1, mensagem: $fala_d1, bloqueios: $b_d1, senha certa: $l_3 · tentativas=0 (lista: $l_zero): 6 senhas erradas ($e_zero), bloqueios: $b_zero, senha certa: $l_4, etiqueta nunca bloqueia na lista: $etiqueta_z, recusas registradas como bloqueio desligado: $v_desligado · sem limite próprio (lista: ${l_vazio:-vazia}), vale o da stack: 4 erradas ($e_4) e a certa: $l_5, 5 erradas ($e_5) e a certa: $l_6, senhas erradas gravadas: $n_padrao, prazo: $p_padrao s · senha trocada pelo terminal (saída $t_senha): bloqueios: $b_senha, entrada com a senha nova: $l_7 · bloqueado com limite próprio de 2 ($e_6 erradas, bloqueios: $b_r0), gravar o mesmo limite: $b_r1, gravar outro limite (sessões): $b_r2, mudar os minutos do bloqueio: $b_r3 · bloqueado com 5 minutos ($e_7 erradas, bloqueios: $b_r4, prazo: $p_r4 s), FTP reiniciado ($s_reinicio): bloqueios: $b_r5, senha certa: $l_8, outro usuário: $l_outro · usuário tmp24 com limite de 1: 1 errada ($e_tmp), bloqueios: $b_tmp, senha certa: $l_tmp removido (saída $t_del): bloqueios: $b_del, criado de novo com o mesmo nome: $l_novo · limites de blq24 tirados: bloqueios: $b_r6, lista: ${l_limpa:-vazia} · FTP_BLOQUEIO_TENTATIVAS=0 e deploy.sh (saída $r_desliga): registro do vigia com o bloqueio desligado: $v_pronto_0, aba Segurança com o alerta: $seg_0, nota no campo da tela Editar: $nota_0, 6 senhas erradas ($e_8), bloqueios: $b_s0, senha certa: $l_9 · limite próprio de 2 gravado pelo painel ($r_proprio) com a stack desligada: 2 erradas ($e_9), bloqueios: $b_s1, senha certa: $l_10, prazo: $p_s1 s · FTP_BLOQUEIO_TENTATIVAS=5 e deploy.sh (saída $r_liga): $s_fim, registro do vigia com a regra: $v_pronto_5, o bloqueio continua depois de recriar o container: $b_s2, aba Segurança com a regra: $seg_5 e com blq24 bloqueado: $seg_preso · limites tirados pelo painel ($r_tira): bloqueios: $b_s3, senha certa: $l_11, lista: ${l_fim:-vazia}"

# ------------------------------------------------------------------ transferências no registro do FTP
# O Pure-FTPd avisa o vigia de cada arquivo enviado, baixado, renomeado e apagado, e o vigia escreve a linha.
head -c 70000 /dev/urandom > "$W/t24.bin"; printf 'x' > "$W/t24.um"
log24; n_envio="$(vigia24 'envio: usuario=outro24 ')"; n_baixa="$(vigia24 'download: usuario=outro24 ')"
x_envio="$(ftp_curl tls outro24 "$W/o24.senha" -T "$W/t24.bin" "$F/t24%20relat%C3%B3rio.bin")"
x_baixa="$(ftp_curl tls outro24 "$W/o24.senha" -o "$W/t24.volta" "$F/t24%20relat%C3%B3rio.bin")"; cmp -s "$W/t24.bin" "$W/t24.volta"; x_igual=$?
x_falta="$(ftp_curl tls outro24 "$W/o24.senha" -o /dev/null "$F/t24-nao-existe.bin")"
# Pasta e arquivo cujo caminho imita o fim da linha de um envio: o tamanho registrado é o verdadeiro, lido do fim.
x_falso="$(ftp_curl tls outro24 "$W/o24.senha" --ftp-create-dirs -T "$W/t24.um" "$F/t24%20uploaded%20%20(999%20bytes,%201.00KB/sec)")"
x_muda="$(ftp_curl tls outro24 "$W/o24.senha" -Q 'RNFR t24 relatório.bin' -Q 'RNTO t24-novo.bin' -Q 'DELE t24-novo.bin' \
  -Q 'DELE t24 uploaded  (999 bytes, 1.00KB/sec)' -Q 'RMD t24 uploaded  (999 bytes, 1.00KB' -l "$F/")"; x_sobra="$(tr -d '\r' < "$W/curl.out" | grep -c -v -x -E '\.{0,2}')"
sleep 1; log24; quem="usuario=outro24 origem=$ORIGEM24"
v_envio="$(linha24 "envio: $quem bytes=70000 arquivo=/data/outro24/t24 relatório.bin")"
v_baixa="$(linha24 "download: $quem bytes=70000 arquivo=/data/outro24/t24 relatório.bin")"
v_falso="$(linha24 "envio: $quem bytes=1 arquivo=/data/outro24/t24 uploaded  (999 bytes, 1.00KB/sec)")"; v_999="$(vigia24 '[a-z]*: .* bytes=999 ')"
v_muda="$(linha24 "renomeado: $quem nomes=[t24 relatório.bin]->[t24-novo.bin]")"
v_apaga="$(linha24 "apagado: $quem arquivo=/data/outro24/t24-novo.bin")"; v_apaga_2="$(linha24 "apagado: $quem arquivo=/data/outro24/t24 uploaded  (999 bytes, 1.00KB/sec)")"
d_envio=$(( $(vigia24 'envio: usuario=outro24 ') - n_envio )); d_baixa=$(( $(vigia24 'download: usuario=outro24 ') - n_baixa ))
altlog="$(grep -c 'altlog' "$W/ftp.log")"; nos_logs="$(segredos_em "$W/ftp.log")"
[[ "$x_envio" == 0 && "$x_baixa" == 0 && "$x_igual" == 0 && "$x_falta" != 0 && "$x_falso" == 0 && "$x_muda" == 0 && "$x_sobra" == 0 \
  && "$v_envio" == 1 && "$v_baixa" == 1 && "$v_falso" == 1 && "$v_999" == 0 && "$v_muda" == 1 && "$v_apaga" == 1 && "$v_apaga_2" == 1 \
  && "$d_envio" == 2 && "$d_baixa" == 1 && "$altlog" == 0 && "$nos_logs" == 0 ]]
caso $? testes 49 "Transferências no registro do FTP: envio, download, renomear e apagar" "outro24 envia 't24 relatório.bin' de 70000 bytes por FTPS (curl $x_envio), baixa (curl $x_baixa, conteúdo $([[ "$x_igual" == 0 ]] && echo igual || echo DIFERENTE)), pede um arquivo que não existe (curl $x_falta), envia 1 byte para o caminho 't24 uploaded  (999 bytes, 1.00KB/sec)' (curl $x_falso), renomeia e apaga (curl $x_muda, sobra na pasta: $x_sobra) · no registro do container, linha 'vigia: envio:' com usuário, origem $ORIGEM24, bytes=70000 e o arquivo: $v_envio · 'vigia: download:' igual: $v_baixa · 'vigia: envio:' do caminho que imita a linha, com bytes=1: $v_falso, linha com bytes=999: $v_999 · 'vigia: renomeado:' com os dois nomes: $v_muda · 'vigia: apagado:' dos dois arquivos: $v_apaga e $v_apaga_2 · linhas de envio novas de outro24: $d_envio (2 envios), de download: $d_baixa (o pedido do arquivo que não existe não gera linha) · erro de altlog no registro: $altlog · senhas no registro: $nos_logs"

# ------------------------------------------------------------------ o bloqueio não abre brecha
mu limites blq24 "" tentativas=2 minutos=10; e_0="$(erra24 blq24 2)"; b_0="$(de24 blq24)"; c_0="$(conteudo24 "$ARQ24")"
# Tentativa durante o bloqueio não estica o prazo nem regrava o arquivo: quem insiste não prende o usuário para sempre.
e_1="$(erra24 blq24 3)"; l_1="$(login24 blq24 "$W/u24b.senha")"; c_1="$(conteudo24 "$ARQ24")"
# Nome que não está no cadastro e nome fora da regra não viram arquivo nem contagem.
pasta_antes="$(arquivos24)"; antes="$(cadastro24)"
e_ninguem="$(erra24 ninguem24 6)"; e_estranho="$(erra24 '../../auth/bloqueios/x' 2)"; e_maiusculo="$(erra24 BLQ24 2)"
pasta_depois="$(arquivos24)"; fora_auth="$(docker exec "$FTP" sh -c 'ls -A / /auth /auth/bloqueios' | grep -c -x -E 'x|BLQ24@.*|ninguem24@.*')"
log24; v_ninguem="$(vigia24 "entrada recusada: usuario=ninguem24 origem=$ORIGEM24 (não está no cadastro)")"; v_regra="$(vigia24 "entrada recusada: nome fora da regra, origem=$ORIGEM24")"
# Link simbólico e arquivo vencido ou inválido, postos à mão na pasta dos bloqueios, não bloqueiam ninguém nem são seguidos.
ALVO24="/auth/bloqueios/outro24@$ORIGEM24"
# A etiqueta de blq24, que está bloqueado, já aparece na lista: a conta é de quantas há antes e depois.
aba -b "$J" "$B/usuarios" > /dev/null; etiqueta_antes="$(contar24 "vindas de: $ORIGEM24")"
docker exec "$FTP" ln -s /auth/pureftpd.passwd "$ALVO24"; l_link="$(login24 outro24 "$W/o24.senha")"
aba -b "$J" "$B/usuarios" > /dev/null; etiqueta_link="$(contar24 "vindas de: $ORIGEM24")"
mu bloqueios outro24; fala_link="$(grep -c '^Nenhum bloqueio em vigor' "$W/mu.log")"; mu desbloquear outro24; fala_tira="$(grep -c '^Usuario outro24 nao tem bloqueio' "$W/mu.log")"
cadastro_link="$(cadastro24)"; docker exec "$FTP" rm -f "$ALVO24"
docker exec "$FTP" sh -c "printf '1 1 9\n' > '$ALVO24'"; l_vencido="$(login24 outro24 "$W/o24.senha")"
docker exec "$FTP" sh -c "printf 'sempre 1 9\n' > '$ALVO24'"; l_invalido="$(login24 outro24 "$W/o24.senha")"
docker exec "$FTP" sh -c "printf '99999999999999999999 1 9\n' > '$ALVO24'"; l_longo="$(login24 outro24 "$W/o24.senha")"
aba -b "$J" "$B/usuarios" > /dev/null; etiqueta_plantado="$(contar24 "vindas de: $ORIGEM24")"; docker exec "$FTP" rm -f "$ALVO24"
# As senhas, certas e erradas, não aparecem no registro do FTP nem na auditoria; o soquete do registro é só do root.
log24; nos_logs="$(segredos_em "$W/ftp.log")"; auditoria; na_auditoria="$(segredos_em "$W/auditoria")"
soquete="$(docker exec "$FTP" stat -c '%F %U:%G %a' /dev/log 2>/dev/null)"
# Vigia morto: o container encerra e volta inteiro, e o bloqueio feito antes continua valendo.
rc_antes="$(docker inspect -f '{{.RestartCount}}' "$FTP")"; ids_antes="$(ids)"; q_antes="$(grep -c 'FALHA: o vigia saiu' "$W/ftp.log")"; vivos="$(vivos24)"
# O container cai junto com o vigia e leva o docker exec: a prova da queda é o registro do FTP.
docker exec "$FTP" sh -c 'for p in /proc/[0-9]*; do if grep -qa "^/usr/bin/perl" "$p/cmdline" 2>/dev/null; then kill -9 "${p#/proc/}"; fi; done' > /dev/null 2>&1
for _ in $(seq 1 60); do
  [[ "$(docker inspect -f '{{.RestartCount}}' "$FTP")" -gt "$rc_antes" && "$(docker inspect -f '{{.State.Health.Status}}' "$FTP")" == healthy ]] && break
  sleep 1
done
esperar "$FTP"; r_volta=$?; rc_depois="$(docker inspect -f '{{.RestartCount}}' "$FTP")"
log24; q_depois="$(grep -c 'FALHA: o vigia saiu' "$W/ftp.log")"; v_vivos="$(vivos24)"
b_volta="$(de24 blq24)"; c_volta="$(conteudo24 "$ARQ24")"; l_volta="$(login24 blq24 "$W/u24b.senha")"; l_outro="$(login24 outro24 "$W/o24.senha")"
[[ "$e_0" == 2 && "$b_0" == 1 && -n "$c_0" && "$e_1" == 3 && "$l_1" == "67 530" && "$c_1" == "$c_0" \
  && "$e_ninguem" == 6 && "$e_estranho" == 2 && "$e_maiusculo" == 2 && "$pasta_depois" == "$pasta_antes" && "$pasta_antes" == "$ARQ24 " && "$fora_auth" == 0 \
  && "$v_ninguem" -ge 6 && "$v_regra" -ge 4 \
  && "$l_link" == "0 226" && "$etiqueta_antes" == 1 && "$etiqueta_link" == 1 && "$fala_link" == 1 && "$fala_tira" == 1 && "$cadastro_link" == "$antes" \
  && "$l_vencido" == "0 226" && "$l_invalido" == "0 226" && "$l_longo" == "0 226" && "$etiqueta_plantado" == 1 \
  && "$nos_logs" == 0 && "$na_auditoria" == 0 && "$soquete" == "socket root:root 700" \
  && "$vivos" == 1 && "$r_volta" == 0 && "$rc_depois" -gt "$rc_antes" && "$ids_antes" == "$(ids)" && "$q_depois" == $((q_antes + 1)) && "$v_vivos" == 1 \
  && "$b_volta" == 1 && "$c_volta" == "$c_0" && "$l_volta" == "67 530" && "$l_outro" == "0 226" ]]
caso $? seguranca 85 "Bloqueio por tentativa não abre brecha" "blq24 bloqueado com 2 senhas erradas ($e_0, bloqueios: $b_0) · durante o bloqueio, mais 3 senhas erradas ($e_1) e a senha certa ($l_1): arquivo do bloqueio $([[ "$c_1" == "$c_0" ]] && echo 'igual, o prazo não estica' || echo ALTERADO) · 6 senhas erradas para um nome que não está no cadastro ($e_ninguem), 2 para o nome '../../auth/bloqueios/x' ($e_estranho) e 2 para BLQ24 em maiúsculas ($e_maiusculo): pasta dos bloqueios $([[ "$pasta_depois" == "$pasta_antes" ]] && echo 'igual' || echo ALTERADA) (${pasta_depois:-vazia}), arquivos criados com esses nomes: $fora_auth, no registro: fora do cadastro $v_ninguem, nome fora da regra $v_regra · link simbólico para o cadastro posto com o nome do bloqueio de outro24: ele entra ($l_link), etiquetas de bloqueado na lista: $etiqueta_antes → $etiqueta_link (só a de blq24), manage-user.sh bloqueios: nenhum ($fala_link), desbloquear não segue o link ($fala_tira), cadastro $([[ "$cadastro_link" == "$antes" ]] && echo inalterado || echo ALTERADO) · arquivo de bloqueio vencido: $l_vencido, com texto no lugar do prazo: $l_invalido, com número de 20 dígitos: $l_longo, etiquetas na lista: $etiqueta_plantado (só a de blq24) · senhas no registro do FTP: $nos_logs, na auditoria: $na_auditoria · soquete /dev/log: $soquete · kill -9 no vigia (processos antes: $vivos): o container voltou (espera: $r_volta, reinícios: $rc_antes → $rc_depois, mesmos containers: $([[ "$ids_antes" == "$(ids)" ]] && echo sim || echo NÃO)), FALHA: o vigia saiu no registro: $q_antes → $q_depois, vigia de volta: $v_vivos · o bloqueio de antes continua: $b_volta, arquivo $([[ "$c_volta" == "$c_0" ]] && echo igual || echo ALTERADO), senha certa: $l_volta, outro usuário: $l_outro"

# ------------------------------------------------------------------ recusas: sem sessão, sem token e fora da regra
antes="$(cadastro24)"; pasta_antes="$(arquivos24)"; auditoria; n_antes="$(eventos bloqueio_removido)"; m_antes="$(eventos limites_alterados)"; c_antes="$(eventos recusa_csrf)"; o_antes="$(eventos recusa_origem)"
campos=(--data-urlencode 'usuario=blq24')
r_sem="$(c -o /dev/null -w '%{http_code} %{redirect_url}' -H "Origin: $B" --data-urlencode "csrf=$K" "${campos[@]}" "$B/usuarios/desbloquear" | sed "s|$B||")"
r_falso="$(c -o /dev/null -w '%{http_code} %{redirect_url}' -b '__Host-sessao=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' -H "Origin: $B" --data-urlencode "csrf=$K" "${campos[@]}" "$B/usuarios/desbloquear" | sed "s|$B||")"
r_token="$(envio /usuarios/desbloquear "${campos[@]}")"
r_errado="$(envio /usuarios/desbloquear --data-urlencode 'csrf=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' "${campos[@]}")"
r_origem="$(c -o /dev/null -w '%{http_code}' -b "$J" -H 'Origin: https://site-de-fora.example' --data-urlencode "csrf=$K" "${campos[@]}" "$B/usuarios/desbloquear")"
r_get="$(aba -b "$J" "$B/usuarios/desbloquear?usuario=blq24")"
r_falta="$(desbloquear24 nao-existe24)"; r_nome="$(desbloquear24 '../blq24')"; r_vazio="$(desbloquear24 '')"
# Com a sessão do próprio usuário bloqueado (ele entra no painel): a rota do desbloqueio não existe para ele.
e_usu="$(COMO=blq24 entrar "$U24" "$W/u24b.senha")"; proibir "$(biscoito_de "$U24")"
UK="$(c -b "$U24" "$B/meus-arquivos" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1)"; proibir "$UK"
r_usu="$(POTE="$U24" envio /usuarios/desbloquear --data-urlencode "csrf=$UK" "${campos[@]}")"
r_usu_lim="$(POTE="$U24" envio /usuarios/limites --data-urlencode "csrf=$UK" "${campos[@]}" --data-urlencode 'tentativas=0')"
ev=""; ok=0
for par in 'tentativas=101' 'tentativas=-1' 'tentativas=abc' 'tentativas=1.5' 'tentativas=0x1' 'tentativas=１' 'minutos=0' 'minutos=1441' 'minutos=-5' 'minutos=1e2'; do
  r="$(limites24 blq24 "$par")"; [[ "$r" == "400 " ]] || ok=1; ev+="$par: $r; "
done
mu limites blq24 "" tentativas=101; t_1=$?; mu limites blq24 "" minutos=0; t_2=$?; mu limites blq24 "" minutos=1441; t_3=$?; mu limites blq24 "" tentativas=-1; t_4=$?
mu desbloquear blq24 "" '1.2.3.4;id'; t_5=$?; f_5="$(grep -c '^Origem invalida' "$W/mu.log")"; mu desbloquear blq24 "" '../../auth'; t_6=$?
mu desbloquear '../blq24'; t_7=$?; mu desbloquear; t_8=$?; mu bloqueios '../blq24'; t_9=$?
auditoria; n_depois="$(eventos bloqueio_removido)"; m_depois="$(eventos limites_alterados)"; c_depois="$(eventos recusa_csrf)"; o_depois="$(eventos recusa_origem)"
depois="$(cadastro24)"; pasta_depois="$(arquivos24)"; l_preso="$(login24 blq24 "$W/u24b.senha")"
# As duas variáveis da stack fora da faixa: o deploy.sh, o container do ftp e o do painel recusam com a mesma regra.
ev_var=""
while IFS='|' read -r troca texto; do
  # shellcheck disable=SC2086
  d="$(recusa_deploy $troca)"; kf="$(recusa_container ftp $troca)"; kp="$(recusa_container painel $troca)"
  certa=sim; recusou "$d" "$texto" && [[ "$kf" == "saída 1 · "*"$texto"* && "$kp" == "saída 1 · "*"$texto"* ]] || { ok=1; certa=NÃO; }
  ev_var+="$troca: deploy.sh ${d%% · *}, container do ftp ${kf%% · *}, do painel ${kp%% · *}, mensagem esperada nos três: $certa; "
done <<'TROCAS'
FTP_BLOQUEIO_TENTATIVAS=101|FTP_BLOQUEIO_TENTATIVAS deve ficar entre 0 e 100
FTP_BLOQUEIO_TENTATIVAS=-1|FTP_BLOQUEIO_TENTATIVAS deve ficar entre 0 e 100
FTP_BLOQUEIO_TENTATIVAS=cinco|FTP_BLOQUEIO_TENTATIVAS deve ficar entre 0 e 100
FTP_BLOQUEIO_MINUTOS=0|FTP_BLOQUEIO_MINUTOS deve ficar entre 1 e 1440
FTP_BLOQUEIO_MINUTOS=1441|FTP_BLOQUEIO_MINUTOS deve ficar entre 1 e 1440
FTP_BLOQUEIO_MINUTOS=1.5|FTP_BLOQUEIO_MINUTOS deve ficar entre 1 e 1440
TROCAS
a_zero="$(aceite_deploy FTP_BLOQUEIO_TENTATIVAS=0 FTP_BLOQUEIO_MINUTOS=1440)"
# Fim da etapa: os usuários saem, e com eles os limites e os bloqueios.
mu del blq24; t_fim=$?; mu del outro24; sobra="$(arquivos24)$(lista24)"; s_fim="$(saude "$FTP" "$PAINEL" "$NGINX")"
[[ "$r_sem" == "303 /entrar" && "$r_falso" == "303 /entrar" && "$r_token" == "403 " && "$r_errado" == "403 " && "$r_origem" == 403 && "$r_get" == "404 " \
  && "$r_falta" == "404 " && "$r_nome" == "404 " && "$r_vazio" == "404 " && "$e_usu" == 303 && -n "$UK" && "$r_usu" == "404 " && "$r_usu_lim" == "404 " \
  && "$t_1" != 0 && "$t_2" != 0 && "$t_3" != 0 && "$t_4" != 0 && "$t_5" == 1 && "$f_5" == 1 && "$t_6" == 1 && "$t_7" != 0 && "$t_8" != 0 && "$t_9" != 0 \
  && "$antes" == "$depois" && "$pasta_antes" == "$pasta_depois" && "$pasta_antes" == "$ARQ24 " && "$l_preso" == "67 530" \
  && "$n_depois" == "$n_antes" && "$m_depois" == "$m_antes" && "$c_depois" -gt "$c_antes" && "$o_depois" -gt "$o_antes" \
  && "$a_zero" == "saída 0 · OK:"* && "$a_zero" != *ALTERADA* && "$t_fim" == 0 && -z "$sobra" && "$s_fim" == "healthy healthy healthy " ]] || ok=1
caso $ok seguranca 86 "Desbloqueio e limites do bloqueio recusam sem sessão, sem token e fora da regra" "com blq24 bloqueado · POST /usuarios/desbloquear sem cookie: $r_sem · com cookie de sessão inventado: $r_falso · com sessão e sem o token: $r_token· com token errado: $r_errado· com o token certo e Origin de fora: $r_origem · GET no mesmo endereço: $r_get(só POST existe) · usuário que não existe: $r_falta· nome com ../: $r_nome· sem o nome: $r_vazio· com a sessão do próprio blq24 (entrada no painel $e_usu): desbloquear $r_usu, gravar tentativas=0 nos próprios limites $r_usu_lim· com sessão e token válidos, limite recusado: ${ev}pelo terminal, tentativas 101: saída $t_1, minutos 0: saída $t_2, minutos 1441: saída $t_3, tentativas -1: saída $t_4, desbloquear com origem '1.2.3.4;id': saída $t_5 (mensagem: $f_5), com origem '../../auth': saída $t_6, com usuário '../blq24': saída $t_7, sem usuário: saída $t_8, bloqueios de '../blq24': saída $t_9 · depois de tudo, cadastro e limites $([[ "$antes" == "$depois" ]] && echo inalterados || echo ALTERADOS), pasta dos bloqueios $([[ "$pasta_antes" == "$pasta_depois" ]] && echo igual || echo ALTERADA), blq24 com a senha certa: $l_preso (continua bloqueado) · auditoria bloqueio_removido: $n_antes → $n_depois, limites_alterados: $m_antes → $m_depois, recusa_csrf: $c_antes → $c_depois, recusa_origem: $o_antes → $o_depois · variáveis da stack fora da faixa: ${ev_var}no limite da faixa (0 e 1440): $a_zero · usuários da etapa removidos (saída $t_fim): bloqueios e limites que sobraram: ${sobra:-nenhum}, containers: $s_fim"
