#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa W: limites por usuário. Sessões, taxas e horário gravados pelo painel e aplicados pelo FTP,
# downloads pelo painel no limite do usuário e limites que recusam valor fora da regra, sem sessão e sem token.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel zera a contagem de falhas de entrada e das recusas e encerra as sessões.
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"

U23="$W/u23.jar"
# <usuário>: os campos de limite do cadastro do FTP (envio, download, sessões e horário). O hash não sai do container.
campos23() { docker exec "$FTP" sh -c "grep '^$1:' /auth/pureftpd.passwd | cut -d: -f7,8,11,18"; }
# <usuário>: impressão do que não é limite (senha, pasta e os campos de cota, que a stack não usa).
resto23() { docker exec "$FTP" sh -c "grep '^$1:' /auth/pureftpd.passwd | cut -d: -f1-6,9,10,12-17 | sha256sum | cut -c1-16"; }
lista23() { docker exec "$FTP" sh -c 'cat /auth/limites.lista 2>/dev/null' | tr '\n' ';'; }
modo23() { docker exec "$FTP" stat -c '%U:%G %a' "/auth/$1" 2>/dev/null || echo ausente; }
cadastro23() { docker exec "$FTP" sh -c 'cat /auth/pureftpd.passwd /auth/limites.lista 2>/dev/null | sha256sum' | cut -c1-16; }
# <usuário> <campo=valor>...: POST /usuarios/limites com os campos dados → "código destino"
limites23() {
  local usuario="$1" par; local -a campos=(--data-urlencode "csrf=$K" --data-urlencode "usuario=$usuario"); shift
  for par in "$@"; do campos+=(--data-urlencode "$par"); done
  envio /usuarios/limites "${campos[@]}"
}
login23() { local r; r="$(ftp_curl tls "$1" "$2" -l "$F/")"; echo "$r $(resposta '(226|421|530) ' | cut -c1-3)"; }  # <usuário> <arquivo da senha> → "0 226" ou "67 530"
agora23() { docker exec "$FTP" date +%H; }                                                                 # hora do container do FTP
hora23() { printf '%02d:00' $(( (10#$(agora23) + $1) % 24 )); }                                              # <horas à frente> → HH:00
cru23() { local a="${1/:/}" b="${2/:/}"; echo "$(( 10#$a ))-$(( 10#$b ))"; }                                 # <HH:MM> <HH:MM> → o horário como o pure-pw grava
ms23() { echo $(( ($(date +%s%N) - $1) / 1000000 )); }                                                       # <início em ns> → milissegundos passados
soma23() { sha256sum < "$1" 2>/dev/null | cut -c1-64; }
na_tela23() { aba -b "$J" "$B/usuarios/editar?usuario=$1" > /dev/null; grep -c "name=\"$2\"[^>]* value=\"$3\"" "$W/corpo"; }  # <usuário> <campo> <valor>

nova_senha "$W/u23.senha"
head -c 2048000 /dev/urandom > "$W/l2m.bin"; head -c 300000 /dev/urandom > "$W/l300.bin"
( umask 077; printf 'user = "%s:%s"\n' lim23 "$(tr -d '\r\n' < "$W/u23.senha")" > "$W/preso23.cfg" )

# ------------------------------------------------------------------ limites gravados pelo painel e aplicados pelo FTP
r_novo="$(envio /usuarios/novo --data-urlencode "csrf=$K" --data-urlencode 'usuario=lim23' --data-urlencode "senha@$W/u23.senha" --data-urlencode "confirmacao@$W/u23.senha")"
a="$(date +%s%N)"; r_e0="$(ftp_curl tls lim23 "$W/u23.senha" -T "$W/l300.bin" "$F/l300.bin")"; e_livre="$(ms23 "$a")"
r_e1="$(ftp_curl tls lim23 "$W/u23.senha" -T "$W/l2m.bin" "$F/l2m.bin")"
a="$(date +%s%N)"; r_d0="$(ftp_curl tls lim23 "$W/u23.senha" -o "$W/l2m.volta" "$F/l2m.bin")"; d_livre="$(ms23 "$a")"
c_antes="$(campos23 lim23)"; resto_antes="$(resto23 lim23)"
e_usu="$(COMO=lim23 entrar "$U23" "$W/u23.senha")"; proibir "$(biscoito_de "$U23")"; s_antes="$(aba -b "$U23" "$B/meus-arquivos")"
tela="$(aba -b "$J" "$B/usuarios/editar?usuario=lim23")"; formulario="$(grep -c 'action="/usuarios/limites"' "$W/corpo")"; cota_tela="$(grep -c -E 'name="(arquivos|mb)"' "$W/corpo")"
auditoria; n_antes="$(eventos limites_alterados)"; i_antes="$(grep -c ' evento=entrada_falha .*conferencia=ftp_indisponivel' "$W/auditoria")"
dentro_i="$(hora23 23)"; dentro_f="$(hora23 2)"; fora_i="$(hora23 2)"; fora_f="$(hora23 4)"
# Os campos de cota, mandados à força, são ignorados: a tela não os tem e o comando não os aceita.
r_grava="$(limites23 lim23 'sessoes=1' 'download=100' 'envio=100' "inicio=$dentro_i" "fim=$dentro_f" 'baixar=1' 'arquivos=5' 'mb=5')"
c_painel="$(campos23 lim23)"; resto_painel="$(resto23 lim23)"; l_painel="$(lista23)"
m_lista="$(modo23 limites.lista)"; m_passwd="$(modo23 pureftpd.passwd)"; m_pdb="$(modo23 pureftpd.pdb)"
s_depois="$(aba -b "$U23" "$B/meus-arquivos")"
aviso="$(aba -b "$J" "$B/usuarios?m=limites")"; n_aviso="$(grep -c 'Limites gravados' "$W/corpo")"
etiqueta="$(grep -c 'title="Limites próprios: sessões no FTP: 1 · download em KB/s: 100 · envio em KB/s: 100 · horário: [0-9:]* às [0-9:]* · downloads pelo painel: 1"' "$W/corpo")"
t_sessoes="$(na_tela23 lim23 sessoes 1)"; t_inicio="$(na_tela23 lim23 inicio "$dentro_i")"; t_fim="$(na_tela23 lim23 fim "$dentro_f")"; t_baixar="$(na_tela23 lim23 baixar 1)"
auditoria; n_depois="$(eventos limites_alterados)"
registro="$(grep -c " evento=limites_alterados admin=$ADMIN usuario=lim23 sessoes=1 download=100 envio=100 horario=${dentro_i/:/}-${dentro_f/:/} baixar=1 tentativas=- minutos=-\$" "$W/auditoria")"
atividade="$(aba -b "$J" "$B/atividade")"; na_atividade="$(grep -c 'Limites do usuário alterados' "$W/corpo")"
# Uma sessão presa em um download na taxa do usuário: a segunda não entra no FTP nem no painel.
( a="$(date +%s%N)"; curl -sS --max-time 90 -K "$W/preso23.cfg" --ssl-reqd -k -o "$W/l2m.lento" "$F/l2m.bin" 2> /dev/null; echo "$? $(ms23 "$a")" > "$W/preso23.fim" ) & preso=$!
sleep 5
l_segunda="$(login23 lim23 "$W/u23.senha")"; e_ocupado="$(COMO=lim23 entrar "$U23" "$W/u23.senha")"
wait "$preso"; read -r r_preso d_lento < "$W/preso23.fim"; rm -f "$W/preso23.cfg"
auditoria; i_depois="$(grep -c ' evento=entrada_falha .*conferencia=ftp_indisponivel' "$W/auditoria")"
l_solta="$(login23 lim23 "$W/u23.senha")"
a="$(date +%s%N)"; r_e2="$(ftp_curl tls lim23 "$W/u23.senha" -T "$W/l300.bin" "$F/l300-lento.bin")"; e_lento="$(ms23 "$a")"
# Fora do horário, o FTP recusa a entrada como recusa senha errada; o painel, que confere a senha no FTP, também.
r_fora="$(limites23 lim23 'sessoes=1' "inicio=$fora_i" "fim=$fora_f")"; c_fora="$(campos23 lim23)"; l_lista_fora="$(lista23)"
l_fora="$(login23 lim23 "$W/u23.senha")"; e_fora="$(COMO=lim23 entrar "$U23" "$W/u23.senha")"
r_limpa="$(limites23 lim23)"; c_limpo="$(campos23 lim23)"; l_limpo="$(lista23)"; resto_limpo="$(resto23 lim23)"
aba -b "$J" "$B/usuarios" > /dev/null; etiqueta_fim="$(grep -c 'title="Limites próprios: sessões' "$W/corpo")"
a="$(date +%s%N)"; r_d2="$(ftp_curl tls lim23 "$W/u23.senha" -o "$W/l2m.volta" "$F/l2m.bin")"; d_fim="$(ms23 "$a")"
# Pelo terminal: o mesmo comando do painel grava, mostra (com os zeros do horário de volta) e tira.
mu limites lim23 "" sessoes=2 download=50 horario=0000-0630 baixar=3; t_grava=$?; fala="$(grep -c '^Limites do usuario lim23 gravados' "$W/mu.log")"
c_terminal="$(campos23 lim23)"; l_terminal="$(lista23)"
mu limites lim23; t_mostra=$?; mostra="$(tr '\n' ' ' < "$W/mu.log")"
t_painel_i="$(na_tela23 lim23 inicio 00:00)"; t_painel_f="$(na_tela23 lim23 fim 06:30)"; t_painel_d="$(na_tela23 lim23 download 50)"
mu limites lim23 "" sessoes= download= horario= baixar=; t_tira=$?; c_tirado="$(campos23 lim23)"; l_tirado="$(lista23)"
# Usuário removido sai da lista dos limites; os limites do usuário inicial atravessam o reinício do FTP.
mu add tmp23 "$W/u23.senha"; mu limites tmp23 "" sessoes=3 baixar=2; l_tmp="$(lista23)"; mu del tmp23; t_del=$?; l_del="$(lista23)"
mu limites "$USUARIO" "" sessoes=3 download=100 baixar=1; c_ini="$(campos23 "$USUARIO")"; l_ini="$(lista23)"
dc restart ftp > /dev/null 2>&1; esperar "$FTP"; s_ini="$(saude "$FTP")"; c_ini_2="$(campos23 "$USUARIO")"; l_ini_2="$(lista23)"
mu limites "$USUARIO" "" sessoes= download= baixar=; c_ini_3="$(campos23 "$USUARIO")"; l_ini_3="$(lista23)"
[[ "$e_adm" == 303 && "$r_novo" == "303 /usuarios?m=criado" && "$r_e0" == 0 && "$r_e1" == 0 && "$r_d0" == 0 && "$c_antes" == ":::" \
  && "$e_usu" == 303 && "$s_antes" == "200 " && "$tela" == "200 " && "$formulario" == 1 && "$cota_tela" == 0 \
  && "$r_grava" == "303 /usuarios?m=limites" && "$c_painel" == "102400:102400:1:$(cru23 "$dentro_i" "$dentro_f")" && "$resto_painel" == "$resto_antes" && "$l_painel" == "lim23 baixar=1;" \
  && "$m_lista" == "root:root 600" && "$m_passwd" == "root:root 600" && "$m_pdb" == "root:root 600" && "$s_depois" == "303 /entrar" \
  && "$aviso" == "200 " && "$n_aviso" -ge 1 && "$etiqueta" == 1 && "$t_sessoes" == 1 && "$t_inicio" == 1 && "$t_fim" == 1 && "$t_baixar" == 1 \
  && "$n_depois" == $((n_antes + 1)) && "$registro" == 1 && "$atividade" == "200 " && "$na_atividade" -ge 1 \
  && "$l_segunda" == *" 421" && "$e_ocupado" == 401 && "$i_depois" == $((i_antes + 1)) && "$r_preso" == 0 && "$(soma23 "$W/l2m.lento")" == "$(soma23 "$W/l2m.bin")" \
  && $((d_lento - d_livre)) -ge 15000 && "$l_solta" == "0 226" && "$r_e2" == 0 && $((e_lento - e_livre)) -ge 3500 \
  && "$r_fora" == "303 /usuarios?m=limites" && "$c_fora" == "::1:$(cru23 "$fora_i" "$fora_f")" && -z "$l_lista_fora" && "$l_fora" == *" 530" && "$e_fora" == 401 \
  && "$r_limpa" == "303 /usuarios?m=limites" && "$c_limpo" == ":::" && -z "$l_limpo" && "$resto_limpo" == "$resto_antes" && "$etiqueta_fim" == 0 && "$r_d2" == 0 && "$d_fim" -lt $((d_livre + 4000)) \
  && "$t_grava" == 0 && "$fala" == 1 && "$c_terminal" == ":51200:2:0-630" && "$l_terminal" == "lim23 baixar=3;" \
  && "$t_mostra" == 0 && "$mostra" == *"sessoes=2 download=50 envio= horario=0000-0630 baixar=3"* && "$t_painel_i" == 1 && "$t_painel_f" == 1 && "$t_painel_d" == 1 \
  && "$t_tira" == 0 && "$c_tirado" == ":::" && -z "$l_tirado" \
  && "$l_tmp" == "tmp23 baixar=2;" && "$t_del" == 0 && -z "$l_del" && "$c_ini" == ":102400:3:" && "$l_ini" == "$USUARIO baixar=1;" \
  && "$s_ini" == "healthy " && "$c_ini_2" == "$c_ini" && "$l_ini_2" == "$l_ini" && "$c_ini_3" == ":::" && -z "$l_ini_3" ]]
caso $? testes 45 "Limites do usuário gravados pelo painel e aplicados pelo FTP" "usuário lim23 criado pelo painel ($r_novo); sem limite, envio de 300 KB em $e_livre ms (saída $r_e0) e download de 2 MB em $d_livre ms (saída $r_d0); campos de limite no cadastro (envio:download:sessões:horário): $c_antes · tela Editar: $tela, formulário dos limites: $formulario, campos de cota na tela: $cota_tela · POST /usuarios/limites com 1 sessão, download e envio a 100 KB/s, horário das $dentro_i às $dentro_f, 1 download pelo painel e dois campos de cota mandados à força: $r_grava · cadastro: $c_painel · lista dos downloads pelo painel: $l_painel · senha, pasta e campos de cota do cadastro $([[ "$resto_painel" == "$resto_antes" ]] && echo inalterados || echo ALTERADOS) · limites.lista: $m_lista, pureftpd.passwd: $m_passwd, pureftpd.pdb: $m_pdb · sessão do usuário no painel, antes: $s_antes, depois: $s_depois · aviso na lista: $n_aviso, etiqueta limites com o resumo: $etiqueta · de volta na tela Editar: sessões $t_sessoes, início $t_inicio, fim $t_fim, downloads $t_baixar · auditoria limites_alterados: $n_antes → $n_depois, linha com o administrador, o usuário e cada limite: $registro · aba Atividade: $atividade, evento na tela: $na_atividade · com uma sessão presa em um download, a segunda entrada no FTP: $l_segunda (421 = sessões do usuário ocupadas) e no painel: $e_ocupado (conferência ftp_indisponivel na auditoria: $i_antes → $i_depois) · o download preso terminou com saída $r_preso em $d_lento ms, conteúdo $([[ "$(soma23 "$W/l2m.lento")" == "$(soma23 "$W/l2m.bin")" ]] && echo igual || echo DIFERENTE) · depois dele, entrada no FTP: $l_solta · envio de 300 KB a 100 KB/s: $e_lento ms (saída $r_e2) · horário trocado para das $fora_i às $fora_f, sem os outros limites: $r_fora, cadastro: $c_fora, lista: ${l_lista_fora:-vazia} · entrada fora do horário no FTP: $l_fora, no painel: $e_fora · todos os campos vazios: $r_limpa, cadastro: $c_limpo, lista: ${l_limpo:-vazia}, etiqueta na lista: $etiqueta_fim, senha e pasta $([[ "$resto_limpo" == "$resto_antes" ]] && echo inalteradas || echo ALTERADAS), download de 2 MB em $d_fim ms (saída $r_d2) · pelo terminal, manage-user.sh limites com 2 sessões, download a 50 KB/s, horário 0000-0630 e 3 downloads: saída $t_grava, cadastro: $c_terminal, lista: $l_terminal · manage-user.sh limites lim23 (saída $t_mostra): $mostra· a tela Editar mostra o início 00:00: $t_painel_i, o fim 06:30: $t_painel_f, o download 50: $t_painel_d · valores vazios pelo terminal: saída $t_tira, cadastro: $c_tirado, lista: ${l_tirado:-vazia} · usuário tmp23 com limite de downloads, lista: $l_tmp depois de removido (saída $t_del): ${l_del:-vazia} · usuário inicial com 3 sessões, download a 100 KB/s e 1 download, cadastro: $c_ini, lista: $l_ini depois de reiniciar o FTP ($s_ini): $c_ini_2 e $l_ini_2 limites tirados: $c_ini_3, lista: ${l_ini_3:-vazia}"

# ------------------------------------------------------------------ downloads pelo painel no limite do usuário
M23="$B/meus-arquivos/baixar?arquivo=l2m.bin"
e_1="$(COMO=lim23 entrar "$U23" "$W/u23.senha")"; proibir "$(biscoito_de "$U23")"
a="$(date +%s%N)"; r_p0="$(c -b "$U23" -o "$W/l2m.painel" -w '%{http_code}' "$M23")"; p_livre="$(ms23 "$a")"; soma_livre="$(soma23 "$W/l2m.painel")"
r_grava="$(limites23 lim23 'download=200' 'baixar=1')"; c_painel="$(campos23 lim23)"; l_painel="$(lista23)"
s_caiu="$(aba -b "$U23" "$B/meus-arquivos")"
e_2="$(COMO=lim23 entrar "$U23" "$W/u23.senha")"; proibir "$(biscoito_de "$U23")"
auditoria; b_antes="$(grep -c ' evento=arquivo_baixado .*usuario=lim23 ' "$W/auditoria")"
( a="$(date +%s%N)"; r="$(curl -sk --max-time 90 -b "$U23" -o "$W/l2m.painel" -w '%{http_code}' "$M23")"; echo "$r $(ms23 "$a")" > "$W/painel23.fim" ) & lento=$!
sleep 2
r_2="$(c -b "$U23" -D "$W/u23.cab" -o "$W/corpo" -w '%{http_code}' "$M23")"; espera="$(grep -i '^retry-after:' "$W/u23.cab" | tr -d '\r' | cut -d ' ' -f 2)"
aviso="$(grep -c 'O limite deste usuário é de 1 arquivo(s) por vez' "$W/corpo")"; tela_segue="$(aba -b "$U23" "$B/meus-arquivos")"
a="$(date +%s%N)"; r_adm="$(c -b "$J" -o "$W/l2m.adm" -w '%{http_code}' "$B/arquivos/baixar?arquivo=lim23/l2m.bin")"; p_adm="$(ms23 "$a")"
wait "$lento"; read -r r_1 p_lento < "$W/painel23.fim"; soma_lenta="$(soma23 "$W/l2m.painel")"
r_3="$(c -b "$U23" -o /dev/null -w '%{http_code}' "$B/meus-arquivos/baixar?arquivo=l300.bin")"
# Só o limite do painel muda: a linha do usuário no cadastro do FTP fica igual e a sessão dele continua.
r_so_painel="$(limites23 lim23 'download=200' 'baixar=2')"; s_fica="$(aba -b "$U23" "$B/meus-arquivos")"; l_dois="$(lista23)"
r_limpa="$(limites23 lim23)"; c_limpo="$(campos23 lim23)"; l_limpo="$(lista23)"
e_3="$(COMO=lim23 entrar "$U23" "$W/u23.senha")"; proibir "$(biscoito_de "$U23")"
a="$(date +%s%N)"; r_p2="$(c -b "$U23" -o "$W/l2m.painel" -w '%{http_code}' "$M23")"; p_fim="$(ms23 "$a")"
auditoria; b_depois="$(grep -c ' evento=arquivo_baixado .*usuario=lim23 ' "$W/auditoria")"
[[ "$e_1" == 303 && "$r_p0" == 200 && "$soma_livre" == "$(soma23 "$W/l2m.bin")" \
  && "$r_grava" == "303 /usuarios?m=limites" && "$c_painel" == ":204800::" && "$l_painel" == "lim23 baixar=1;" && "$s_caiu" == "303 /entrar" && "$e_2" == 303 \
  && "$r_2" == 503 && "$espera" == 30 && "$aviso" == 1 && "$tela_segue" == "200 " && "$r_adm" == 200 && "$(soma23 "$W/l2m.adm")" == "$(soma23 "$W/l2m.bin")" && "$p_adm" -lt $((p_livre + 4000)) \
  && "$r_1" == 200 && "$soma_lenta" == "$(soma23 "$W/l2m.bin")" && $((p_lento - p_livre)) -ge 7000 && "$r_3" == 200 \
  && "$r_so_painel" == "303 /usuarios?m=limites" && "$s_fica" == "200 " && "$l_dois" == "lim23 baixar=2;" \
  && "$r_limpa" == "303 /usuarios?m=limites" && "$c_limpo" == ":::" && -z "$l_limpo" && "$e_3" == 303 && "$r_p2" == 200 && "$p_fim" -lt $((p_livre + 4000)) \
  && "$b_depois" -ge $((b_antes + 3)) ]]
caso $? testes 46 "Downloads pelo painel no limite do usuário" "lim23 entra no painel ($e_1) e baixa o arquivo de 2 MB sem limite: $r_p0 em $p_livre ms, conteúdo $([[ "$soma_livre" == "$(soma23 "$W/l2m.bin")" ]] && echo igual || echo DIFERENTE) · limites gravados pelo painel, download a 200 KB/s e 1 download por vez: $r_grava, cadastro: $c_painel, lista: $l_painel · a sessão dele cai ($s_caiu) e ele entra de novo ($e_2) · com um download em andamento, o segundo: $r_2, Retry-After: ${espera:-ausente}, aviso do limite de 1 por vez: $aviso, a tela Meus arquivos enquanto isso: $tela_segue· o administrador baixa o mesmo arquivo sem a taxa do usuário: $r_adm em $p_adm ms · o download em andamento terminou: $r_1 em $p_lento ms, conteúdo $([[ "$soma_lenta" == "$(soma23 "$W/l2m.bin")" ]] && echo igual || echo DIFERENTE) · depois dele, outro download: $r_3 · só o limite do painel trocado para 2: $r_so_painel, sessão do usuário: $s_fica(continua), lista: $l_dois · todos os campos vazios: $r_limpa, cadastro: $c_limpo, lista: ${l_limpo:-vazia} · ele entra de novo ($e_3) e baixa sem limite: $r_p2 em $p_fim ms · arquivo_baixado de lim23 na auditoria: $b_antes → $b_depois"

# ------------------------------------------------------------------ limites fora da regra, sem sessão e sem token
antes="$(cadastro23)"; auditoria; n_antes="$(eventos limites_alterados)"; c_antes="$(eventos recusa_csrf)"; o_antes="$(eventos recusa_origem)"
ev=""; ok=0
for par in 'sessoes=0' 'sessoes=-1' 'sessoes=abc' 'sessoes=1.5' 'sessoes=99999999' 'download=0' 'download=10000001' 'envio=1e3' 'envio=10000001' 'download= 1 2' 'envio=0x10' 'baixar=0' 'baixar=999' 'sessoes=１'; do
  r="$(limites23 lim23 "$par")"; [[ "$r" == "400 " ]] || ok=1; ev+="$par: $r; "
done
r_so_inicio="$(limites23 lim23 'inicio=08:00')"; r_so_fim="$(limites23 lim23 'fim=18:00')"; r_iguais="$(limites23 lim23 'inicio=08:00' 'fim=08:00')"
r_hora="$(limites23 lim23 'inicio=25:00' 'fim=26:00')"; r_formato="$(limites23 lim23 'inicio=0800' 'fim=1800')"
r_injeta="$(limites23 lim23 'inicio=08:00' 'fim=18:00 -r 0.0.0.0/0')"; r_opcao="$(limites23 lim23 'sessoes=1 -d /auth')"
tela="$(aba -b "$J" "$B/usuarios/editar?usuario=lim23")"
r_nulo="$(envio /usuarios/limites --data "csrf=$K&usuario=lim23&sessoes=1%00")"; r_linha="$(envio /usuarios/limites --data "csrf=$K&usuario=lim23&sessoes=1%0Aoutro%3A")"
r_falta="$(limites23 nao-existe23 'sessoes=1')"; r_nome="$(limites23 '../lim23' 'sessoes=1')"
campos=(--data-urlencode 'usuario=lim23' --data-urlencode 'sessoes=1')
r_sem="$(c -o /dev/null -w '%{http_code} %{redirect_url}' -H "Origin: $B" --data-urlencode "csrf=$K" "${campos[@]}" "$B/usuarios/limites" | sed "s|$B||")"
r_falso="$(c -o /dev/null -w '%{http_code} %{redirect_url}' -b '__Host-sessao=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' -H "Origin: $B" --data-urlencode "csrf=$K" "${campos[@]}" "$B/usuarios/limites" | sed "s|$B||")"
r_token="$(envio /usuarios/limites "${campos[@]}")"
r_errado="$(envio /usuarios/limites --data-urlencode 'csrf=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' "${campos[@]}")"
r_origem="$(c -o /dev/null -w '%{http_code}' -b "$J" -H 'Origin: https://site-de-fora.example' --data-urlencode "csrf=$K" "${campos[@]}" "$B/usuarios/limites")"
r_get="$(aba -b "$J" "$B/usuarios/limites?usuario=lim23&sessoes=1")"
# Com a sessão do próprio usuário do FTP: a rota dos limites não existe para ele.
e_usu="$(COMO=lim23 entrar "$U23" "$W/u23.senha")"; proibir "$(biscoito_de "$U23")"
UK="$(c -b "$U23" "$B/meus-arquivos" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1)"; proibir "$UK"
r_usu="$(POTE="$U23" envio /usuarios/limites --data-urlencode "csrf=$UK" "${campos[@]}")"
mu limites lim23 "" sessoes=0; t_1=$?
mu limites lim23 "" horario=0800-0800; t_2=$?
mu limites lim23 "" outro=1; t_3=$?
mu limites lim23 "" sessoes; t_4=$?
mu limites lim23 "" arquivos=5; t_6=$?; mu limites lim23 "" mb=5; t_7=$?
mu limites nao-existe23 "" sessoes=1; t_5=$?; f_5="$(grep -c '^Usuario nao existe: nao-existe23' "$W/mu.log")"
auditoria; n_depois="$(eventos limites_alterados)"; c_depois="$(eventos recusa_csrf)"; o_depois="$(eventos recusa_origem)"; depois="$(cadastro23)"
l_fim="$(login23 lim23 "$W/u23.senha")"
[[ "$e_adm" == 303 && "$tela" == "200 " \
  && "$r_so_inicio" == "400 " && "$r_so_fim" == "400 " && "$r_iguais" == "400 " && "$r_hora" == "400 " && "$r_formato" == "400 " && "$r_injeta" == "400 " && "$r_opcao" == "400 " \
  && "$r_nulo" == "400 " && "$r_linha" == "400 " && "$r_falta" == "404 " && "$r_nome" == "404 " \
  && "$r_sem" == "303 /entrar" && "$r_falso" == "303 /entrar" && "$r_token" == "403 " && "$r_errado" == "403 " && "$r_origem" == 403 && "$r_get" == "404 " \
  && "$e_usu" == 303 && -n "$UK" && "$r_usu" == "404 " \
  && "$t_1" != 0 && "$t_2" != 0 && "$t_3" != 0 && "$t_4" != 0 && "$t_5" != 0 && "$f_5" == 1 && "$t_6" == 2 && "$t_7" == 2 \
  && "$antes" == "$depois" && "$n_depois" == "$n_antes" && "$c_depois" -gt "$c_antes" && "$o_depois" -gt "$o_antes" && "$l_fim" == "0 226" ]] || ok=1
caso $ok seguranca 84 "Limites recusam valor fora da regra, sem sessão e sem token" "com sessão e token válidos, valor recusado: ${ev}só o início do horário: $r_so_inicio· só o fim: $r_so_fim· início igual ao fim: $r_iguais· hora que não existe: $r_hora· horário sem os dois pontos: $r_formato· opção do pure-pw depois do horário: $r_injeta· depois de um número: $r_opcao· número com byte nulo: $r_nulo· com quebra de linha: $r_linha· usuário que não existe: $r_falta· nome de usuário com ../: $r_nome· POST /usuarios/limites sem cookie: $r_sem · com cookie de sessão inventado: $r_falso · com sessão e sem o token: $r_token· com token errado: $r_errado· com o token certo e Origin de fora: $r_origem · GET no mesmo endereço: $r_get(só POST existe) · com a sessão do próprio usuário do FTP (entrada $e_usu): $r_usu· pelo terminal, sessões 0: saída $t_1, horário com início igual ao fim: saída $t_2, chave que não existe: saída $t_3, par sem o sinal de igual: saída $t_4, usuário que não existe: saída $t_5 (mensagem: $f_5), cota de arquivos: saída $t_6, cota de espaço: saída $t_7 (o comando não tem cota) · cadastro e lista de limites $([[ "$antes" == "$depois" ]] && echo inalterados || echo ALTERADOS) · limites_alterados na auditoria: $n_antes → $n_depois · recusa_csrf: $c_antes → $c_depois · recusa_origem: $o_antes → $o_depois · o usuário continua entrando no FTP: $l_fim"
