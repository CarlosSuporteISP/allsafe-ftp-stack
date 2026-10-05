#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa O: TLS por usuário (FTP_TLS_EXCECOES). O padrão desligado, o administrador dispensando e voltando
# a exigir pelo painel e pelo terminal, quem entra sem TLS e quem não entra, a queda do pure-authd, as
# combinações que a subida recusa e quem consegue alterar a lista dos dispensados.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel zera a contagem de falhas de entrada e das recusas e encerra as sessões.
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"

UT="$B/usuarios/tls"; U="$W/u15.jar"
entra() { COMO="$1" entrar "$2" "$3"; }                                      # <usuário> <pote> <arquivo da senha> → código HTTP
# <tls|controle|puro> <usuário> <arquivo da senha> → saída do curl (0 = entrou) e, se o servidor recusou, o código da recusa
tenta() { local r; r="$(ESPERA_PURO="${ESPERA_PURO:-25}" ftp_curl "$1" "$2" "$3" "$F/")"; echo "$r$(resposta '(421|530)' | cut -c1-3 | sed 's/^/ /')"; }
dispensados() { docker exec "$FTP" sh -c 'cat /auth/sem-tls.lista 2>/dev/null' | tr '\n' ' '; }
soma_lista() { docker exec "$FTP" sh -c 'sha256sum < /auth/sem-tls.lista' 2>/dev/null | cut -c1-16; }
processos15() { docker exec "$FTP" sh -c 'for p in /proc/[0-9]*; do tr "\000" " " < "$p/cmdline" 2>/dev/null; echo; done' | grep -c "^/usr/sbin/$1 "; }  # <programa>
recusas15() { grep -c "porteiro: entrada sem TLS recusada: usuario=$1 origem=" "$W/ftp.log"; }  # <usuário>: linhas do porteiro no log do FTP
pedir_tls() { envio /usuarios/tls --data-urlencode "csrf=$K" --data-urlencode "usuario=$1" --data-urlencode "acao=$2"; }  # <usuário> <dispensar|exigir>
contar() { grep -o -- "$1" "$W/corpo" | wc -l; }                               # <trecho>: vezes em que aparece na última tela

for n in a b; do nova_senha "$W/u15$n.senha"; done
printf 'marcador-do-vizinho-%s\n' "$(openssl rand -hex 8)" > "$W/u15.marca"; MARCA="$(cat "$W/u15.marca")"
mu add equip15 "$W/u15a.senha" clientes15/olt-a; r_ma=$?
mu add legado15 "$W/u15b.senha" clientes15/olt-b; r_mb=$?
r_f1="$(ftp_curl tls equip15 "$W/u15a.senha" -T "$W/u15.marca" "$F/marca15.cfg")"

# ------------------------------------------------------------------ o padrão: exceção desligada
padrao="$(env_file="$ENVA" env_valor FTP_TLS_EXCECOES ausente)"
mu tls-dispensar legado15; r_d0=$?; lista_0="$(dispensados)"
off_puro="$(ESPERA_PURO=10 tenta puro legado15 "$W/u15b.senha")"; off_tls="$(tenta tls legado15 "$W/u15b.senha")"; off_authd="$(processos15 pure-authd)"
off_lista="$(aba -b "$J" "$B/usuarios")"; off_coluna="$(contar '<th>TLS</th>')"; off_botoes="$(contar 'href="/usuarios/tls?usuario=')"
off_tela="$(aba -b "$J" "$UT?usuario=legado15")"; off_texto="$(contar 'TLS por usuário desligado')"
off_envio="$(pedir_tls equip15 dispensar)"; lista_1="$(dispensados)"
off_seg="$(aba -b "$J" "$B/seguranca")"; off_linha="$(contar 'Sem exceção por usuário (<code>FTP_TLS_EXCECOES=nao</code>)')"
mu tls-exigir legado15; r_e0=$?; lista_2="$(dispensados)"

# A exceção só existe com FTP_TLS_MODE=2 e REDE_PERMITIR_IP_PUBLICO=nao. A etapa 10 deixa a opção de IP público ligada
# e uma rede pública liberada no painel: esta etapa desliga as duas e devolve ao final.
opcao_antes="$(env_file="$ENVA" env_valor REDE_PERMITIR_IP_PUBLICO nao)"; redes_antes="$(env_file="$ENVA" env_valor PAINEL_REDES_PERMITIDAS)"
gravar_env "$ENVA" REDE_PERMITIR_IP_PUBLICO nao
gravar_env "$ENVA" PAINEL_REDES_PERMITIDAS "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
gravar_env "$ENVA" FTP_TLS_EXCECOES sim; dep; r_liga=$?; painel_de_pe
aviso_deploy="$(grep -c '^AVISO: FTP_TLS_EXCECOES=sim' "$W/deploy.log")"
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
docker logs "$FTP" > "$W/ftp.log" 2>&1; pronto="$(grep -c 'TLS=2 com exceção por usuário' "$W/ftp.log")"; on_authd="$(processos15 pure-authd)"

# ------------------------------------------------------------------ o administrador dispensa e volta a exigir pelo painel
auditoria; d_antes="$(eventos tls_dispensado)"; x_antes="$(eventos tls_exigido)"
lista="$(aba -b "$J" "$B/usuarios")"; coluna="$(contar '<th>TLS</th>')"; obrigados="$(contar '<td>obrigatório</td>')"; n_usuarios="$(usuarios_ftp | wc -w)"
botao_d="$(contar 'href="/usuarios/tls?usuario=legado15">🔓 Dispensar TLS</a>')"
tela="$(aba -b "$J" "$UT?usuario=legado15")"; pergunta="$(contar 'Sim, deixar este usuário entrar sem TLS')"
antes_puro="$(tenta puro legado15 "$W/u15b.senha")"
r_disp="$(pedir_tls legado15 dispensar)"
aba -b "$J" "$B/usuarios?m=tls_dispensado" > /dev/null; msg_d="$(contar 'Usuário dispensado do TLS: a senha e os arquivos dele passam em texto puro')"
etiqueta="$(contar '<td><span class="etiqueta">⚠️ sem TLS</span></td>')"; botao_x="$(contar 'href="/usuarios/tls?usuario=legado15">🔒 Exigir TLS</a>')"
r_up="$(ESPERA_PURO=25 ftp_curl puro legado15 "$W/u15b.senha" -T "$W/envio.bin" "$F/legado.bin")"
r_down="$(ESPERA_PURO=25 ftp_curl puro legado15 "$W/u15b.senha" -o "$W/u15.baixado" "$F/legado.bin")"
outro_puro="$(tenta puro equip15 "$W/u15a.senha")"; outro_tls="$(tenta tls equip15 "$W/u15a.senha")"; marcado_tls="$(tenta tls legado15 "$W/u15b.senha")"
seg="$(aba -b "$J" "$B/seguranca")"; seg_linha="$(contar 'Exceção por usuário ligada</strong> (<code>FTP_TLS_EXCECOES=sim</code>): 1 usuário(s) entram sem TLS, com senha e arquivos em texto puro: legado15\.')"
seg_alerta="$(contar '1 usuário(s) entram no FTP sem TLS</strong> (legado15)')"
visao="$(aba -b "$J" "$B/")"; visao_texto="$(contar ', com exceção por usuário')"; visao_alerta="$(contar '1 usuário(s) entram no FTP sem TLS</strong> (legado15)')"
aba -b "$J" "$B/atividade" > /dev/null; ativ="$(contar 'Usuário dispensado do TLS')"
e_a="$(entra equip15 "$U" "$W/u15a.senha")"; proibir "$(biscoito_de "$U")"; e_b="$(entra legado15 "$W/b15.jar" "$W/u15b.senha")"; proibir "$(biscoito_de "$W/b15.jar")"
tela_x="$(aba -b "$J" "$UT?usuario=legado15")"; pergunta_x="$(contar 'Sim, voltar a exigir o TLS')"
r_exig="$(pedir_tls legado15 exigir)"
aba -b "$J" "$B/usuarios?m=tls_exigido" > /dev/null; msg_x="$(contar 'O usuário volta a ser obrigado a usar TLS')"; etiqueta_x="$(contar '<td><span class="etiqueta">⚠️ sem TLS</span></td>')"
depois_puro="$(tenta puro legado15 "$W/u15b.senha")"; depois_tls="$(tenta tls legado15 "$W/u15b.senha")"
aba -b "$J" "$B/seguranca" > /dev/null; seg_vazia="$(contar 'sem nenhum usuário dispensado')"; alerta_fim="$(contar 'entram no FTP sem TLS')"
auditoria; d_depois="$(eventos tls_dispensado)"; x_depois="$(eventos tls_exigido)"
reg_d="$(grep -c " evento=tls_dispensado admin=$ADMIN usuario=legado15\$" "$W/auditoria")"; reg_x="$(grep -c " evento=tls_exigido admin=$ADMIN usuario=legado15\$" "$W/auditoria")"
[[ "$e_adm" == 303 && "$r_ma" == 0 && "$r_mb" == 0 && "$r_f1" == 0 && "$r_liga" == 0 && "$aviso_deploy" -ge 1 && "$pronto" -ge 1 && "$on_authd" == 1 \
  && "$lista" == "200 " && "$coluna" == 1 && "$obrigados" == "$n_usuarios" && "$botao_d" == 1 && "$tela" == "200 " && "$pergunta" == 1 && "$antes_puro" == "67 530" \
  && "$r_disp" == "303 /usuarios?m=tls_dispensado" && "$msg_d" == 1 && "$etiqueta" == 1 && "$botao_x" == 1 && "$r_up" == 0 && "$r_down" == 0 \
  && "$outro_puro" == "67 530" && "$outro_tls" == 0 && "$marcado_tls" == 0 && "$seg" == "200 " && "$seg_linha" == 1 && "$seg_alerta" == 1 \
  && "$visao" == "200 " && "$visao_texto" == 1 && "$visao_alerta" == 1 && "$ativ" -ge 1 && "$e_a" == 303 && "$e_b" == 303 \
  && "$tela_x" == "200 " && "$pergunta_x" == 1 && "$r_exig" == "303 /usuarios?m=tls_exigido" && "$msg_x" == 1 && "$etiqueta_x" == 0 \
  && "$depois_puro" == "67 530" && "$depois_tls" == 0 && "$seg_vazia" == 1 && "$alerta_fim" == 0 \
  && "$d_depois" == $((d_antes + 1)) && "$x_depois" == $((x_antes + 1)) && "$reg_d" -ge 1 && "$reg_x" -ge 1 ]] && cmp -s "$W/envio.bin" "$W/u15.baixado"
caso $? testes 31 "Administrador dispensa um usuário do TLS e volta a exigir, pelo painel" "FTP_TLS_EXCECOES=sim com FTP_TLS_MODE=2 (deploy.sh: saída $r_liga, avisos da exceção: $aviso_deploy; log do FTP 'TLS=2 com exceção por usuário': $pronto; pure-authd no container: $on_authd) · aba Usuários: $lista, coluna TLS: $coluna, 'obrigatório' em $obrigados de $n_usuarios usuários, botão Dispensar TLS de legado15: $botao_d · tela de confirmação: $tela com a pergunta: $pergunta · legado15 sem TLS antes: $antes_puro · POST dispensar: $r_disp, mensagem com o alerta de texto puro: $msg_d, etiqueta 'sem TLS' na lista: $etiqueta, botão Exigir TLS: $botao_x · legado15 sem TLS envia (saída $r_up) e baixa (saída $r_down) o arquivo, $(cmp -s "$W/envio.bin" "$W/u15.baixado" && echo idêntico || echo DIFERENTE) · equip15, não dispensado, sem TLS: $outro_puro; com TLS: $outro_tls; legado15 com TLS: $marcado_tls · aba Segurança: ${seg}linha do TLS com a exceção e o nome: $seg_linha, alerta no topo: $seg_alerta · Visão geral: ${visao}texto ', com exceção por usuário': $visao_texto, alerta: $visao_alerta · aba Atividade mostra a dispensa: $ativ · entrada no painel de equip15: $e_a e de legado15: $e_b · tela para voltar a exigir: $tela_x com a pergunta: $pergunta_x · POST exigir: $r_exig, mensagem: $msg_x, etiqueta na lista: $etiqueta_x · legado15 sem TLS depois: $depois_puro; com TLS: $depois_tls · aba Segurança 'sem nenhum usuário dispensado': $seg_vazia, alerta: $alerta_fim · auditoria: tls_dispensado $d_antes → $d_depois e tls_exigido $x_antes → $x_depois, com administrador e usuário: $reg_d e $reg_x (curl: 0 = entrou, 67 = login recusado; 530 = resposta do servidor)"

# ------------------------------------------------------------------ pelo terminal, e o padrão desligado
mu tls-dispensar legado15; r_t1=$?; m_t1="$(grep -c 'Usuario legado15 dispensado do TLS' "$W/mu.log")"
mu tls-lista; r_tl=$?; l_1="$(tr '\n' ' ' < "$W/mu.log")"
t_puro="$(tenta puro legado15 "$W/u15b.senha")"
aba -b "$J" "$B/usuarios" > /dev/null; no_painel="$(contar '<td><span class="etiqueta">⚠️ sem TLS</span></td>')"
mu tls-dispensar ninguem15; r_t2=$?; m_t2="$(grep -c 'Usuario nao existe: ninguem15' "$W/mu.log")"
mu tls-dispensar '../../auth/x'; r_t3=$?
mu tls-exigir legado15; r_t4=$?; m_t4="$(grep -c 'Usuario legado15 volta a ser obrigado a usar TLS' "$W/mu.log")"; l_2="$(dispensados)"; t_exigido="$(tenta puro legado15 "$W/u15b.senha")"
# Removido e recriado com o mesmo nome: a dispensa não volta junto.
mu tls-dispensar legado15; mu del legado15; r_del=$?; l_3="$(dispensados)"
mu add legado15 "$W/u15b.senha" clientes15/olt-b; r_re=$?; t_recriado="$(tenta puro legado15 "$W/u15b.senha")"; t_recriado_tls="$(tenta tls legado15 "$W/u15b.senha")"
# O usuário inicial também pode ser dispensado: o que não se troca pelo painel é a senha dele.
mu tls-dispensar "$USUARIO"; r_i1=$?; i_puro="$(tenta puro "$USUARIO" "$W/inicial.senha")"
mu tls-exigir "$USUARIO"; r_i2=$?; i_exigido="$(tenta puro "$USUARIO" "$W/inicial.senha")"; l_4="$(dispensados)"
[[ "$padrao" == nao && "$r_d0" == 0 && "$lista_0" == "legado15 " && "$off_puro" != 0* && "$off_tls" == 0 && "$off_authd" == 0 && "$off_lista" == "200 " && "$off_coluna" == 0 && "$off_botoes" == 0 \
  && "$off_tela" == "404 " && "$off_texto" -ge 1 && "$off_envio" == "404 " && "$lista_1" == "legado15 " && "$off_seg" == "200 " && "$off_linha" == 1 && "$r_e0" == 0 && -z "$lista_2" \
  && "$r_t1" == 0 && "$m_t1" == 1 && "$r_tl" == 0 && "$l_1" == "legado15 " && "$t_puro" == 0 && "$no_painel" == 1 && "$r_t2" == 1 && "$m_t2" == 1 && "$r_t3" != 0 \
  && "$r_t4" == 0 && "$m_t4" == 1 && -z "$l_2" && "$t_exigido" == "67 530" && "$r_del" == 0 && -z "$l_3" && "$r_re" == 0 && "$t_recriado" == "67 530" && "$t_recriado_tls" == 0 \
  && "$r_i1" == 0 && "$i_puro" == 0 && "$r_i2" == 0 && "$i_exigido" == "67 530" && -z "$l_4" ]]
caso $? testes 32 "TLS por usuário pelo terminal e o padrão desligado" "padrão da instalação: FTP_TLS_EXCECOES=$padrao · com ela desligada: manage-user.sh tls-dispensar legado15 grava a lista (saída $r_d0, lista: ${lista_0:-vazia}) e não muda nada: legado15 sem TLS: $off_puro, com TLS: $off_tls, pure-authd no container: $off_authd · no painel: aba Usuários $off_lista, coluna TLS: $off_coluna, botões de TLS: $off_botoes; GET /usuarios/tls: $off_tela('TLS por usuário desligado': $off_texto); POST /usuarios/tls: $off_envio, lista depois: ${lista_1:-vazia}; aba Segurança 'Sem exceção por usuário': $off_linha · com ela ligada: tls-dispensar legado15: saída $r_t1, tls-lista: ${l_1:-vazia}, legado15 sem TLS: $t_puro, etiqueta no painel: $no_painel · tls-dispensar de quem não existe: saída $r_t2 ('Usuario nao existe': $m_t2); com nome fora da regra: saída $r_t3 · tls-exigir legado15: saída $r_t4, lista: ${l_2:-vazia}, sem TLS: $t_exigido · dispensado, removido (del: saída $r_del, lista: ${l_3:-vazia}) e recriado (add: saída $r_re): sem TLS $t_recriado, com TLS $t_recriado_tls · usuário inicial $USUARIO dispensado (saída $r_i1): sem TLS $i_puro; exigido de novo (saída $r_i2): $i_exigido, lista: ${l_4:-vazia}"

# ------------------------------------------------------------------ sem TLS só entra quem foi dispensado
mu tls-dispensar legado15; r_marca=$?
docker logs "$FTP" > "$W/ftp.log" 2>&1; p_antes="$(recusas15 equip15)"; m_antes="$(recusas15 legado15)"; f_antes="$(grep -c 'usuario=(nome fora da regra)' "$W/ftp.log")"
s_certa="$(tenta puro equip15 "$W/u15a.senha")"          # não dispensado, senha certa
s_errada="$(tenta puro legado15 "$W/errada.senha")"      # dispensado, senha errada
s_alheia="$(tenta puro legado15 "$W/u15a.senha")"        # dispensado, com a senha de outro usuário
s_ninguem="$(tenta puro ninguem15 "$W/errada.senha")"    # usuário que não existe
s_estranho="$(tenta puro '../../auth/sem-tls.lista' "$W/errada.senha")"
s_maiusculo="$(tenta puro LEGADO15 "$W/u15b.senha")"     # o nome do dispensado em maiúsculas não é o dispensado
c_certa="$(tenta tls equip15 "$W/u15a.senha")"; c_controle="$(tenta controle equip15 "$W/u15a.senha")"; c_errada="$(tenta tls equip15 "$W/errada.senha")"
m_certa="$(tenta puro legado15 "$W/u15b.senha")"
# O dispensado continua preso à própria pasta: o arquivo do vizinho e o cadastro não saem por ele.
r_viz="$(ESPERA_PURO=25 ftp_curl puro legado15 "$W/u15b.senha" --path-as-is -o "$W/u15.fuga" "$F/../olt-a/marca15.cfg")"
r_cad="$(ESPERA_PURO=25 ftp_curl puro legado15 "$W/u15b.senha" --path-as-is -o "$W/u15.fuga2" "$F/../../../auth/pureftpd.passwd")"
ESPERA_PURO=25 ftp_curl puro legado15 "$W/u15b.senha" "$F/../" --path-as-is > /dev/null; ve_vizinho="$(grep -c -E 'olt-a|marca15|clientes15' "$W/curl.out")"
vazou15="$(cat "$W/u15.fuga" "$W/u15.fuga2" 2>/dev/null | grep -c -a -E "$MARCA|equip15:|argon2")"
docker logs "$FTP" > "$W/ftp.log" 2>&1; p_depois="$(recusas15 equip15)"; m_depois="$(recusas15 legado15)"; f_depois="$(grep -c 'usuario=(nome fora da regra)' "$W/ftp.log")"
n_ninguem="$(recusas15 ninguem15)"; nos_logs="$(segredos_em "$W/ftp.log")"
permissoes="$(docker exec "$FTP" stat -c '%a %U:%G' /auth/sem-tls.lista /run/pure-authd.sock | tr '\n' ' ')"
[[ "$r_marca" == 0 && "$s_certa" == "67 530" && "$s_errada" == "67 530" && "$s_alheia" == "67 530" && "$s_ninguem" == "67 530" && "$s_estranho" == "67 530" && "$s_maiusculo" == "67 530" \
  && "$c_certa" == 0 && "$c_controle" == 0 && "$c_errada" == "67 530" && "$m_certa" == 0 && "$r_viz" != 0 && "$r_cad" != 0 && "$ve_vizinho" == 0 && "$vazou15" == 0 \
  && "$p_depois" == $((p_antes + 1)) && "$m_depois" == "$m_antes" && "$n_ninguem" -ge 1 && "$f_depois" -ge $((f_antes + 1)) && "$nos_logs" == 0 && "$permissoes" == "600 root:root 600 root:root " ]]
caso $? seguranca 64 "Sem TLS só entra quem o administrador dispensou" "com legado15 dispensado e equip15 não · sem TLS: equip15 com a senha certa: $s_certa · legado15 com senha errada: $s_errada, com a senha de equip15: $s_alheia · usuário que não existe: $s_ninguem · nome '../../auth/sem-tls.lista': $s_estranho · LEGADO15 em maiúsculas com a senha de legado15: $s_maiusculo · legado15 com a senha certa: $m_certa · com TLS: equip15 com a senha certa: $c_certa, com TLS só no login: $c_controle, com senha errada: $c_errada · legado15, sem TLS, pede o arquivo do vizinho por ..: saída $r_viz; o cadastro do FTP: saída $r_cad; pastas ou arquivos do vizinho na listagem de ..: $ve_vizinho; conteúdo do vizinho, linha de cadastro ou hash no que veio: $vazou15 · log do FTP: recusas do porteiro para equip15: $p_antes → $p_depois (uma, a da senha certa em texto puro), para legado15: $m_antes → $m_depois (a senha errada dele é recusada pelo cadastro, não pelo porteiro), para o nome que não existe: $n_ninguem, 'nome fora da regra' no lugar do que o cliente mandou: $f_antes → $f_depois · senhas, tokens e cookies no log do FTP: $nos_logs · lista dos dispensados e soquete do pure-authd (modo e dono): $permissoes(curl: 0 = entrou, 67 = login recusado; 530 = resposta do servidor)"

# ------------------------------------------------------------------ pure-authd morto: o FTP encerra e volta inteiro
rajada() { # <n>: tentativa sem TLS de equip15, com a senha certa, em paralelo com a queda
  ( umask 077; printf 'user = "equip15:%s"\n' "$(tr -d '\r\n' < "$W/u15a.senha")" > "$W/u15.cfg-$1" )
  curl -sS --max-time 25 -K "$W/u15.cfg-$1" "$F/" > /dev/null 2>&1; echo "$?" > "$W/u15.rajada-$1"; rm -f "$W/u15.cfg-$1"
}
rc_antes="$(docker inspect -f '{{.RestartCount}}' "$FTP")"; ini_antes="$(docker inspect -f '{{.State.StartedAt}}' "$FTP")"; ids_antes="$(ids)"
docker logs "$FTP" > "$W/ftp.log" 2>&1; q_antes="$(grep -c 'FALHA: o pure-authd saiu' "$W/ftp.log")"; vivos="$(processos15 pure-authd)"
lote=(); for n in 1 2 3; do rajada "$n" & lote+=("$!"); done
# O container cai junto com o pure-authd e leva o docker exec: a prova da queda é o registro do FTP, conferido adiante.
docker exec "$FTP" sh -c 'for p in /proc/[0-9]*; do if grep -qa "^/usr/sbin/pure-authd" "$p/cmdline" 2>/dev/null; then kill -9 "${p#/proc/}"; fi; done' > /dev/null 2>&1
for n in 4 5 6 7 8; do rajada "$n" & lote+=("$!"); sleep 0.05; done
tentativas=0; passou=0; codigos=""
for _ in $(seq 1 40); do  # até o container voltar e ficar saudável: nenhuma tentativa sem TLS de quem não foi dispensado pode entrar
  r="$(ESPERA_PURO=25 ftp_curl puro equip15 "$W/u15a.senha" "$F/")"; tentativas=$((tentativas + 1)); codigos+="$r "; [[ "$r" == 0 ]] && passou=$((passou + 1))
  [[ "$(docker inspect -f '{{.RestartCount}}' "$FTP")" -gt "$rc_antes" && "$(docker inspect -f '{{.State.Health.Status}}' "$FTP")" == healthy ]] && break
  sleep 1
done
wait "${lote[@]}" 2>/dev/null
em_paralelo="$(cat "$W"/u15.rajada-* 2>/dev/null | tr '\n' ' ')"; paralelo_passou="$(cat "$W"/u15.rajada-* 2>/dev/null | grep -c -x 0)"
esperar "$FTP"; r_volta=$?
rc_depois="$(docker inspect -f '{{.RestartCount}}' "$FTP")"; ini_depois="$(docker inspect -f '{{.State.StartedAt}}' "$FTP")"
docker logs "$FTP" > "$W/ftp.log" 2>&1; q_depois="$(grep -c 'FALHA: o pure-authd saiu' "$W/ftp.log")"; nos_logs="$(segredos_em "$W/ftp.log")"
v_authd="$(processos15 pure-authd)"; v_marcado="$(tenta puro legado15 "$W/u15b.senha")"; v_outro="$(tenta puro equip15 "$W/u15a.senha")"; v_tls="$(tenta tls equip15 "$W/u15a.senha")"
v_painel="$(aba -b "$J" "$B/usuarios")"; v_lista="$(dispensados)"
[[ "$vivos" == 1 && "$passou" == 0 && "$paralelo_passou" == 0 && "$(wc -w <<< "$em_paralelo")" == 8 && "$r_volta" == 0 && "$rc_depois" -gt "$rc_antes" && "$ini_depois" != "$ini_antes" \
  && "$ids_antes" == "$(ids)" && "$q_depois" == $((q_antes + 1)) && "$nos_logs" == 0 && "$v_authd" == 1 && "$v_marcado" == 0 && "$v_outro" == "67 530" && "$v_tls" == 0 \
  && "$v_painel" == "200 " && "$v_lista" == "legado15 " ]]
caso $? seguranca 65 "pure-authd morto: o FTP encerra em vez de liberar a entrada sem TLS" "kill -9 no pure-authd dentro do container do FTP (processos pure-authd antes: $vivos) · 8 tentativas sem TLS de equip15, não dispensado e com a senha certa, disparadas junto com a queda: saídas do curl $em_paralelo(entraram: $paralelo_passou) · mais $tentativas em sequência até o container voltar: $codigos(entraram: $passou) · log do FTP 'FALHA: o pure-authd saiu': $q_antes → $q_depois · reinícios do container: $rc_antes → $rc_depois, mesmo container (os três com os mesmos IDs: $([[ "$ids_antes" == "$(ids)" ]] && echo sim || echo NÃO)), saudável de novo: $([[ "$r_volta" == 0 ]] && echo sim || echo NÃO) · depois da volta: pure-authd no container: $v_authd, legado15 sem TLS: $v_marcado, equip15 sem TLS: $v_outro, equip15 com TLS: $v_tls, lista dos dispensados: ${v_lista:-vazia}, aba Usuários: $v_painel· senhas no log do FTP: $nos_logs (curl: 0 = entrou, 7 = porta fechada, 56 e 28 = conexão cortada, 67 = login recusado)"

# ------------------------------------------------------------------ combinações recusadas e quem altera a lista
ev=""; ok=0
while IFS='|' read -r troca texto; do
  # shellcheck disable=SC2086
  d="$(recusa_deploy $troca)"; kf="$(recusa_container ftp $troca)"; kp="$(recusa_container painel $troca)"
  certa=sim; recusou "$d" "$texto" && [[ "$kf" == "saída 1 · "*"$texto"* && "$kp" == "saída 1 · "*"$texto"* ]] || { ok=1; certa=NÃO; }
  ev+="$troca: deploy.sh ${d%% · *}, container do ftp ${kf%% · *}, do painel ${kp%% · *}, mensagem esperada nos três: $certa; "
done <<'TROCAS'
FTP_TLS_EXCECOES=talvez|FTP_TLS_EXCECOES deve ser
FTP_TLS_EXCECOES=SIM|FTP_TLS_EXCECOES deve ser
FTP_TLS_EXCECOES=sim FTP_TLS_MODE=0|FTP_TLS_EXCECOES=sim exige FTP_TLS_MODE=2
FTP_TLS_EXCECOES=sim FTP_TLS_MODE=1|FTP_TLS_EXCECOES=sim exige FTP_TLS_MODE=2
FTP_TLS_EXCECOES=sim FTP_TLS_MODE=3|FTP_TLS_EXCECOES=sim exige FTP_TLS_MODE=2
FTP_TLS_EXCECOES=sim REDE_PERMITIR_IP_PUBLICO=sim|FTP_TLS_EXCECOES=sim não combina com REDE_PERMITIR_IP_PUBLICO=sim
TROCAS
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
e_u="$(entra equip15 "$U" "$W/u15a.senha")"; proibir "$(biscoito_de "$U")"
UK="$(c -b "$U" "$B/meus-arquivos" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1)"; proibir "$UK"
auditoria; n_antes="$(eventos recusa_papel)"; d_antes="$(eventos tls_dispensado)"; x_antes="$(eventos tls_exigido)"; soma_antes="$(soma_lista)"
g_usuario="$(aba -b "$U" "$UT?usuario=equip15")"; no_corpo="$(grep -c -E 'legado15|Dispensar|sem TLS' "$W/corpo")"
p_usuario="$(POTE="$U" envio /usuarios/tls --data-urlencode "csrf=$UK" --data-urlencode 'usuario=equip15' --data-urlencode 'acao=dispensar')"
p_usuario_x="$(POTE="$U" envio /usuarios/tls --data-urlencode "csrf=$UK" --data-urlencode 'usuario=legado15' --data-urlencode 'acao=exigir')"
g_anonimo="$(aba "$UT?usuario=equip15")"
p_anonimo="$(POTE=/dev/null envio /usuarios/tls --data-urlencode 'usuario=equip15' --data-urlencode 'acao=dispensar')"
p_sem_token="$(envio /usuarios/tls --data-urlencode 'usuario=equip15' --data-urlencode 'acao=dispensar')"
p_origem="$(c -o /dev/null -w '%{http_code}' -b "$J" -H 'Origin: https://outro.exemplo.com.br' --data-urlencode "csrf=$K" --data-urlencode 'usuario=equip15' --data-urlencode 'acao=dispensar' "$UT")"
g_inexistente="$(aba -b "$J" "$UT?usuario=ninguem15")"; p_inexistente="$(pedir_tls ninguem15 dispensar)"
p_nome="$(pedir_tls '../../auth/sem-tls.lista' dispensar)"; p_acao="$(pedir_tls equip15 apagar)"; p_vazia="$(pedir_tls equip15 '')"
auditoria; n_depois="$(eventos recusa_papel)"; d_depois="$(eventos tls_dispensado)"; x_depois="$(eventos tls_exigido)"
registro="$(grep -c ' evento=recusa_papel usuario=equip15 caminho=/usuarios/tls' "$W/auditoria")"; na_auditoria="$(segredos_em "$W/auditoria")"
soma_depois="$(soma_lista)"; l_fim="$(dispensados)"; s_fim="$(tenta puro equip15 "$W/u15a.senha")"
# De volta ao padrão: a lista fica guardada, mas ninguém entra sem TLS e o pure-authd nem sobe.
gravar_env "$ENVA" FTP_TLS_EXCECOES nao; gravar_env "$ENVA" REDE_PERMITIR_IP_PUBLICO "$opcao_antes"
[[ -n "$redes_antes" ]] && gravar_env "$ENVA" PAINEL_REDES_PERMITIDAS "$redes_antes"
dep; r_desliga=$?; painel_de_pe
fim_puro="$(ESPERA_PURO=10 tenta puro legado15 "$W/u15b.senha")"; fim_tls="$(tenta tls legado15 "$W/u15b.senha")"; fim_authd="$(processos15 pure-authd)"; fim_lista="$(dispensados)"
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
[[ "$ok" == 0 && "$e_u" == 303 && "$g_usuario" == "404 " && "$no_corpo" == 0 && "$p_usuario" == "404 " && "$p_usuario_x" == "404 " && "$g_anonimo" == "303 /entrar" && "$p_anonimo" == "303 /entrar" \
  && "$p_sem_token" == "403 " && "$p_origem" == 403 && "$g_inexistente" == "404 " && "$p_inexistente" == "404 " && "$p_nome" == "404 " && "$p_acao" == "303 /usuarios/tls?usuario=equip15" \
  && "$p_vazia" == "303 /usuarios/tls?usuario=equip15" && "$n_depois" -gt "$n_antes" && "$registro" -ge 1 && "$d_depois" == "$d_antes" && "$x_depois" == "$x_antes" && "$na_auditoria" == 0 \
  && -n "$soma_antes" && "$soma_antes" == "$soma_depois" && "$l_fim" == "legado15 " && "$s_fim" == "67 530" \
  && "$r_desliga" == 0 && "$fim_puro" != 0* && "$fim_tls" == 0 && "$fim_authd" == 0 && "$fim_lista" == "legado15 " && "$e_adm" == 303 ]]
caso $? seguranca 66 "Combinações recusadas na subida e quem altera a lista dos dispensados" "$ev(saída 1 = recusado, instância intacta nas seis) · com a sessão de equip15 (usuário do FTP no painel, entrada: $e_u): GET /usuarios/tls: $g_usuario(nome de outro usuário ou botão no corpo: $no_corpo); POST para se dispensar: $p_usuario· POST para tirar a dispensa de legado15: $p_usuario_x· sem sessão: GET $g_anonimo e POST $p_anonimo · administrador sem o token: $p_sem_token· com Origin de outro site: $p_origem · usuário que não existe: GET $g_inexistente· POST $p_inexistente· nome '../../auth/sem-tls.lista': $p_nome· ação fora de dispensar e exigir: $p_acao; ação vazia: $p_vazia · recusa_papel na auditoria: $n_antes → $n_depois, com usuário e caminho: $registro · tls_dispensado: $d_antes → $d_depois, tls_exigido: $x_antes → $x_depois · senhas, tokens e cookies na auditoria: $na_auditoria · lista dos dispensados com a mesma soma antes e depois: $([[ -n "$soma_antes" && "$soma_antes" == "$soma_depois" ]] && echo sim || echo NÃO) (${l_fim:-vazia}); equip15 sem TLS: $s_fim · de volta a FTP_TLS_EXCECOES=nao (deploy.sh: saída $r_desliga): a lista segue guardada (${fim_lista:-vazia}), legado15 sem TLS: $fim_puro, com TLS: $fim_tls, pure-authd no container: $fim_authd"
achado seguranca "Com FTP_TLS_EXCECOES=sim, o servidor aceita o comando USER sem TLS de qualquer nome, para poder decidir depois da senha: o cliente mal configurado de um usuário não dispensado envia a senha em texto puro antes de receber o 530" "Custo assumido da exceção, e o motivo de ela vir desligada, exigir FTP_TLS_MODE=2 e não combinar com REDE_PERMITIR_IP_PUBLICO=sim. A sessão não entra, o porteiro registra a tentativa no log do FTP com o nome e a origem ('a senha enviada passou em texto puro: troque-a') e o painel avisa no topo quantos usuários estão dispensados. Sem a exceção, o servidor recusa o USER antes de a senha ser enviada."

mu del equip15; mu del legado15
docker exec "$FTP" rm -rf /data/clientes15
rm -f "$W"/u15* "$W/b15.jar" "$W/ftp.log"
