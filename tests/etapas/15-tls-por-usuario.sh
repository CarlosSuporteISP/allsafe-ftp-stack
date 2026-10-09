#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa O: TLS por usuário (FTP_TLS_EXCECOES, ligado por padrão). A opção sem efeito com IP público, com outro
# modo de TLS e desligada, o administrador dispensando e voltando a exigir pelo painel (na lista, ao criar e em
# Editar) e pelo terminal, quem entra sem TLS e quem não entra, a recusa antes da senha enquanto ninguém está
# dispensado, a troca de modo sem derrubar sessão, a queda do pure-authd e quem consegue alterar a lista.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel zera a contagem de falhas de entrada e das recusas e encerra as sessões.
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"

UT="$B/usuarios/tls"; U="$W/u15.jar"
# Sem nenhum dispensado, o servidor responde 421 ao comando USER sem TLS e encerra a sessão: a senha nem é
# pedida. O curl trata o 421 como sessão encerrada pelo servidor e sai com 28, na hora, sem esperar o prazo.
# Com dispensado, quem não está na lista manda a senha e recebe o 530 do porteiro.
ANTES_DA_SENHA="28 421"; DEPOIS_DA_SENHA="67 530"
entra() { COMO="$1" entrar "$2" "$3"; }                                      # <usuário> <pote> <arquivo da senha> → código HTTP
# <tls|controle|puro> <usuário> <arquivo da senha> → saída do curl (0 = entrou) e, se o servidor recusou, o código da recusa
tenta() { local r; r="$(ESPERA_PURO="${ESPERA_PURO:-25}" ftp_curl "$1" "$2" "$3" "$F/")"; echo "$r$(resposta '(421|530)' | cut -c1-3 | sed 's/^/ /')"; }
ao_user() { ftp_cru "USER $1" | cut -c1-3 | tr -d '\n'; }                     # <usuário>: resposta do servidor ao USER sem TLS
dispensados() { docker exec "$FTP" sh -c 'cat /auth/sem-tls.lista 2>/dev/null' | tr '\n' ' '; }
soma_lista() { docker exec "$FTP" sh -c 'sha256sum < /auth/sem-tls.lista' 2>/dev/null | cut -c1-16; }
processos15() { docker exec "$FTP" sh -c 'for p in /proc/[0-9]*; do tr "\000" " " < "$p/cmdline" 2>/dev/null; echo; done' | grep -c "^/usr/sbin/$1 "; }  # <programa>
recusas15() { grep -c "porteiro: entrada sem TLS recusada: usuario=$1 origem=" "$W/ftp.log"; }  # <usuário>: linhas do porteiro no log do FTP
trocas15() { docker logs "$FTP" 2>&1 | grep -c 'TLS por usuário: a lista dos dispensados mudou'; }
pedir_tls() { envio /usuarios/tls --data-urlencode "csrf=$K" --data-urlencode "usuario=$1" --data-urlencode "acao=$2"; }  # <usuário> <dispensar|exigir>
criar15() { envio /usuarios/novo --data-urlencode "csrf=$K" --data-urlencode "usuario=$1" --data-urlencode "pasta=clientes15/$1" --data-urlencode "senha@$2" --data-urlencode "confirmacao@$2" "${@:3}"; }  # <usuário> <arquivo da senha> [campos a mais]
contar() { grep -o -- "$1" "$W/corpo" | wc -l; }                               # <trecho>: vezes em que aparece na última tela
# A lista dos dispensados mudou de lado (vazia ou preenchida): o FTP troca o modo de entrada em até 2 s. Espera
# o modo que a lista pede e o servidor atendendo; diz "aberto" (há dispensado) ou "fechado" (ninguém entra sem TLS).
modo15() {
  local _ ultima quer estado
  for _ in $(seq 1 40); do
    if [[ -n "$(dispensados)" ]]; then quer='com exceção por usuário'; estado=aberto; else quer='nenhum dispensado'; estado=fechado; fi
    ultima="$(docker logs "$FTP" 2>&1 | grep '^FTP pronto em 2121/tcp' | tail -1)"
    if [[ "$ultima" == *"$quer"* ]] && docker exec "$FTP" /usr/local/sbin/allsafe-ftp-saude > /dev/null 2>&1; then echo "$estado"; return 0; fi
    sleep 0.25
  done
  echo 'NÃO TROCOU'; return 1
}
# <tls|puro> <usuário> <arquivo da senha> <destino> <taxa>: download lento, para a sessão atravessar a troca de modo
longa15() {
  local -a o=(); [[ "$1" == tls ]] && o=(--ssl-reqd -k)
  ( umask 077; printf 'user = "%s:%s"\n' "$2" "$(tr -d '\r\n' < "$3")" > "$4.cfg" )
  curl -sS --max-time 90 --limit-rate "$5" -K "$4.cfg" "${o[@]}" -o "$4" "$F/grande15.bin" > /dev/null 2>&1; echo "$?" > "$4.saida"; rm -f "$4.cfg"
}

for n in a b c d; do nova_senha "$W/u15$n.senha"; done
printf 'marcador-do-vizinho-%s\n' "$(openssl rand -hex 8)" > "$W/u15.marca"; MARCA="$(cat "$W/u15.marca")"
mu add equip15 "$W/u15a.senha" clientes15/olt-a; r_ma=$?
mu add legado15 "$W/u15b.senha" clientes15/olt-b; r_mb=$?
r_f1="$(ftp_curl tls equip15 "$W/u15a.senha" -T "$W/u15.marca" "$F/marca15.cfg")"

# ------------------------------------------------------------------ a opção sem efeito: IP público aceito
# A etapa 10 deixa REDE_PERMITIR_IP_PUBLICO=sim e uma rede pública liberada no painel. O TLS por usuário vem
# ligado, mas não vale com IP público: ninguém é dispensado, e o painel diz o motivo no lugar dos botões.
padrao="$(env_file=.env.example env_valor FTP_TLS_EXCECOES ausente)"; no_teste="$(env_file="$ENVA" env_valor FTP_TLS_EXCECOES ausente)"
opcao_antes="$(env_file="$ENVA" env_valor REDE_PERMITIR_IP_PUBLICO nao)"; redes_antes="$(env_file="$ENVA" env_valor PAINEL_REDES_PERMITIDAS)"
docker logs "$FTP" > "$W/ftp.log" 2>&1; pub_log="$(grep -c 'TLS por usuário sem efeito: não vale com REDE_PERMITIR_IP_PUBLICO=sim' "$W/ftp.log")"
conferir_deploy; pub_deploy="$?:$(grep -c '^TLS por usuário sem efeito: não vale com REDE_PERMITIR_IP_PUBLICO=sim' "$W/recusa.log")"
mu tls-dispensar legado15; r_d0=$?; lista_0="$(dispensados)"
pub_puro="$(ESPERA_PURO=10 tenta puro legado15 "$W/u15b.senha")"; pub_tls="$(tenta tls legado15 "$W/u15b.senha")"; pub_authd="$(processos15 pure-authd)"
pub_lista="$(aba -b "$J" "$B/usuarios")"; pub_coluna="$(contar '<th>TLS</th>')"; pub_botoes="$(contar 'href="/usuarios/tls?usuario=')"
pub_tela="$(aba -b "$J" "$UT?usuario=legado15")"; pub_texto="$(contar 'TLS por usuário sem efeito')"; pub_motivo="$(contar 'ela não vale com <code>REDE_PERMITIR_IP_PUBLICO=sim</code>')"
pub_envio="$(pedir_tls equip15 dispensar)"; lista_1="$(dispensados)"
pub_seg="$(aba -b "$J" "$B/seguranca")"; pub_linha="$(contar 'Sem exceção por usuário: ela não vale com <code>REDE_PERMITIR_IP_PUBLICO=sim</code>')"; pub_alerta="$(contar 'entram no FTP sem TLS')"
pub_novo="$(aba -b "$J" "$B/usuarios/novo")"; pub_caixa="$(contar 'name="sem_tls"')"
pub_cria="$(criar15 caixa15 "$W/u15c.senha" --data-urlencode 'sem_tls=sim')"; lista_c="$(dispensados)"
pub_editar="$(aba -b "$J" "$B/usuarios/editar?usuario=legado15")"; pub_cartao="$(contar 'Dispensar um usuário do TLS não está disponível nesta instalação: ela não vale com')"; pub_link="$(contar 'href="/usuarios/tls?usuario=')"
mu tls-exigir legado15; r_e0=$?; lista_2="$(dispensados)"
mu del caixa15; r_dc=$?

# De volta ao IP privado: a opção passa a valer. Esta etapa desliga a opção de IP público e devolve ao final.
gravar_env "$ENVA" REDE_PERMITIR_IP_PUBLICO nao
gravar_env "$ENVA" PAINEL_REDES_PERMITIDAS "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
dep; r_liga=$?; painel_de_pe
resumo_deploy="$(grep -c 'equipamento sem suporte a TLS: o administrador dispensa o usuário dele na aba Usuários do painel' "$W/deploy.log")"
aviso_vazio="$(grep -c '^AVISO: TLS por usuário' "$W/deploy.log")"
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
m_ini="$(modo15)"; docker logs "$FTP" > "$W/ftp.log" 2>&1; pronto_0="$(grep -c 'TLS=2; TLS por usuário: nenhum dispensado, sessão sem TLS recusada antes da senha' "$W/ftp.log")"; on_authd="$(processos15 pure-authd)"

# ------------------------------------------------------------------ o administrador dispensa e volta a exigir pelo painel
auditoria; d_antes="$(eventos tls_dispensado)"; x_antes="$(eventos tls_exigido)"
lista="$(aba -b "$J" "$B/usuarios")"; coluna="$(contar '<th>TLS</th>')"; obrigados="$(contar '<td>obrigatório</td>')"; n_usuarios="$(usuarios_ftp | wc -w)"
botao_d="$(contar 'href="/usuarios/tls?usuario=legado15">Dispensar TLS</a>')"
tela="$(aba -b "$J" "$UT?usuario=legado15")"; pergunta="$(contar 'Sim, deixar este usuário entrar sem TLS')"
antes_puro="$(tenta puro legado15 "$W/u15b.senha")"
aba -b "$J" "$B/" > /dev/null; visao_antes="$(contar ', com exceção por usuário')"
r_disp="$(pedir_tls legado15 dispensar)"; m_disp="$(modo15)"
docker logs "$FTP" > "$W/ftp.log" 2>&1; pronto="$(grep -c 'TLS=2 com exceção por usuário (1 dispensado(s) do TLS)' "$W/ftp.log")"
aba -b "$J" "$B/usuarios?m=tls_dispensado" > /dev/null; msg_d="$(contar 'Usuário dispensado do TLS: a senha e os arquivos dele passam em texto puro')"
etiqueta="$(contar '<td><span class="etiqueta atencao">sem TLS</span></td>')"; botao_x="$(contar 'href="/usuarios/tls?usuario=legado15">Exigir TLS</a>')"
r_up="$(ESPERA_PURO=25 ftp_curl puro legado15 "$W/u15b.senha" -T "$W/envio.bin" "$F/legado.bin")"
r_down="$(ESPERA_PURO=25 ftp_curl puro legado15 "$W/u15b.senha" -o "$W/u15.baixado" "$F/legado.bin")"
outro_puro="$(tenta puro equip15 "$W/u15a.senha")"; outro_tls="$(tenta tls equip15 "$W/u15a.senha")"; marcado_tls="$(tenta tls legado15 "$W/u15b.senha")"
seg="$(aba -b "$J" "$B/seguranca")"; seg_linha="$(contar 'Exceção por usuário ligada</strong> (<code>FTP_TLS_EXCECOES=sim</code>): 1 usuário(s) entram sem TLS, com senha e arquivos em texto puro: legado15\.')"
seg_alerta="$(contar '1 usuário(s) entram no FTP sem TLS</strong> (legado15)')"
visao="$(aba -b "$J" "$B/")"; visao_texto="$(contar ', com exceção por usuário')"; visao_alerta="$(contar '1 usuário(s) entram no FTP sem TLS</strong> (legado15)')"
aba -b "$J" "$B/atividade" > /dev/null; ativ="$(contar 'Usuário dispensado do TLS')"
e_a="$(entra equip15 "$U" "$W/u15a.senha")"; proibir "$(biscoito_de "$U")"; e_b="$(entra legado15 "$W/b15.jar" "$W/u15b.senha")"; proibir "$(biscoito_de "$W/b15.jar")"
tela_x="$(aba -b "$J" "$UT?usuario=legado15")"; pergunta_x="$(contar 'Sim, voltar a exigir o TLS')"
r_exig="$(pedir_tls legado15 exigir)"; m_exig="$(modo15)"
aba -b "$J" "$B/usuarios?m=tls_exigido" > /dev/null; msg_x="$(contar 'O usuário volta a ser obrigado a usar TLS')"; etiqueta_x="$(contar '<td><span class="etiqueta atencao">sem TLS</span></td>')"
depois_puro="$(tenta puro legado15 "$W/u15b.senha")"; depois_tls="$(tenta tls legado15 "$W/u15b.senha")"
aba -b "$J" "$B/seguranca" > /dev/null; seg_vazia="$(contar 'sem nenhum usuário dispensado: todos entram com TLS')"; alerta_fim="$(contar 'entram no FTP sem TLS')"
auditoria; d_depois="$(eventos tls_dispensado)"; x_depois="$(eventos tls_exigido)"
reg_d="$(grep -c " evento=tls_dispensado admin=$ADMIN usuario=legado15\$" "$W/auditoria")"; reg_x="$(grep -c " evento=tls_exigido admin=$ADMIN usuario=legado15\$" "$W/auditoria")"
[[ "$e_adm" == 303 && "$r_ma" == 0 && "$r_mb" == 0 && "$r_f1" == 0 && "$r_liga" == 0 && "$resumo_deploy" == 1 && "$aviso_vazio" == 0 && "$m_ini" == fechado && "$pronto_0" -ge 1 && "$on_authd" == 1 \
  && "$lista" == "200 " && "$coluna" == 1 && "$obrigados" == "$n_usuarios" && "$botao_d" == 1 && "$tela" == "200 " && "$pergunta" == 1 && "$antes_puro" == "$ANTES_DA_SENHA" && "$visao_antes" == 0 \
  && "$r_disp" == "303 /usuarios?m=tls_dispensado" && "$m_disp" == aberto && "$pronto" -ge 1 && "$msg_d" == 1 && "$etiqueta" == 1 && "$botao_x" == 1 && "$r_up" == 0 && "$r_down" == 0 \
  && "$outro_puro" == "$DEPOIS_DA_SENHA" && "$outro_tls" == 0 && "$marcado_tls" == 0 && "$seg" == "200 " && "$seg_linha" == 1 && "$seg_alerta" == 1 \
  && "$visao" == "200 " && "$visao_texto" == 1 && "$visao_alerta" == 1 && "$ativ" -ge 1 && "$e_a" == 303 && "$e_b" == 303 \
  && "$tela_x" == "200 " && "$pergunta_x" == 1 && "$r_exig" == "303 /usuarios?m=tls_exigido" && "$m_exig" == fechado && "$msg_x" == 1 && "$etiqueta_x" == 0 \
  && "$depois_puro" == "$ANTES_DA_SENHA" && "$depois_tls" == 0 && "$seg_vazia" == 1 && "$alerta_fim" == 0 \
  && "$d_depois" == $((d_antes + 1)) && "$x_depois" == $((x_antes + 1)) && "$reg_d" -ge 1 && "$reg_x" -ge 1 ]] && cmp -s "$W/envio.bin" "$W/u15.baixado"
caso $? testes 31 "Administrador dispensa um usuário do TLS e volta a exigir, pelo painel" "FTP_TLS_EXCECOES=sim (o padrão) com FTP_TLS_MODE=2 e IP privado (deploy.sh: saída $r_liga, linha do resumo que aponta a aba Usuários: $resumo_deploy, aviso de dispensado sem ninguém dispensado: $aviso_vazio; FTP $m_ini, log 'nenhum dispensado, sessão sem TLS recusada antes da senha': $pronto_0; pure-authd no container: $on_authd) · aba Usuários: $lista, coluna TLS: $coluna, 'obrigatório' em $obrigados de $n_usuarios usuários, botão Dispensar TLS de legado15: $botao_d · tela de confirmação: $tela com a pergunta: $pergunta · legado15 sem TLS antes: $antes_puro; Visão geral ', com exceção por usuário' antes: $visao_antes · POST dispensar: $r_disp, FTP $m_disp (log 'TLS=2 com exceção por usuário (1 dispensado(s) do TLS)': $pronto), mensagem com o alerta de texto puro: $msg_d, etiqueta 'sem TLS' na lista: $etiqueta, botão Exigir TLS: $botao_x · legado15 sem TLS envia (saída $r_up) e baixa (saída $r_down) o arquivo, $(cmp -s "$W/envio.bin" "$W/u15.baixado" && echo idêntico || echo DIFERENTE) · equip15, não dispensado, sem TLS: $outro_puro; com TLS: $outro_tls; legado15 com TLS: $marcado_tls · aba Segurança: ${seg}linha do TLS com a exceção e o nome: $seg_linha, alerta no topo: $seg_alerta · Visão geral: ${visao}texto ', com exceção por usuário': $visao_texto, alerta: $visao_alerta · aba Atividade mostra a dispensa: $ativ · entrada no painel de equip15: $e_a e de legado15: $e_b · tela para voltar a exigir: $tela_x com a pergunta: $pergunta_x · POST exigir: $r_exig, FTP $m_exig, mensagem: $msg_x, etiqueta na lista: $etiqueta_x · legado15 sem TLS depois: $depois_puro; com TLS: $depois_tls · aba Segurança 'sem nenhum usuário dispensado': $seg_vazia, alerta: $alerta_fim · auditoria: tls_dispensado $d_antes → $d_depois e tls_exigido $x_antes → $x_depois, com administrador e usuário: $reg_d e $reg_x (curl: 0 = entrou, 28 = o servidor encerrou a sessão, 67 = login recusado; 421 = recusa na resposta ao USER, antes da senha; 530 = recusa depois da senha; aberto = o FTP aceita sessão sem TLS de quem foi dispensado; fechado = recusa toda sessão sem TLS)"

# ------------------------------------------------------------------ pelo terminal, e a opção sem efeito com IP público
mu tls-dispensar legado15; r_t1=$?; m_t1="$(grep -c 'Usuario legado15 dispensado do TLS' "$W/mu.log")"; f_t1="$(modo15)"
mu tls-lista; r_tl=$?; l_1="$(tr '\n' ' ' < "$W/mu.log")"
t_puro="$(tenta puro legado15 "$W/u15b.senha")"
aba -b "$J" "$B/usuarios" > /dev/null; no_painel="$(contar '<td><span class="etiqueta atencao">sem TLS</span></td>')"
mu tls-dispensar ninguem15; r_t2=$?; m_t2="$(grep -c 'Usuario nao existe: ninguem15' "$W/mu.log")"
mu tls-dispensar '../../auth/x'; r_t3=$?
mu tls-exigir legado15; r_t4=$?; m_t4="$(grep -c 'Usuario legado15 volta a ser obrigado a usar TLS' "$W/mu.log")"; l_2="$(dispensados)"; f_t4="$(modo15)"; t_exigido="$(tenta puro legado15 "$W/u15b.senha")"
# Removido e recriado com o mesmo nome: a dispensa não volta junto.
mu tls-dispensar legado15; f_t5="$(modo15)"; mu del legado15; r_del=$?; l_3="$(dispensados)"; f_t6="$(modo15)"
mu add legado15 "$W/u15b.senha" clientes15/olt-b; r_re=$?; t_recriado="$(tenta puro legado15 "$W/u15b.senha")"; t_recriado_tls="$(tenta tls legado15 "$W/u15b.senha")"
# O usuário inicial também pode ser dispensado.
mu tls-dispensar "$USUARIO"; r_i1=$?; f_i1="$(modo15)"; i_puro="$(tenta puro "$USUARIO" "$W/inicial.senha")"
mu tls-exigir "$USUARIO"; r_i2=$?; f_i2="$(modo15)"; i_exigido="$(tenta puro "$USUARIO" "$W/inicial.senha")"; l_4="$(dispensados)"
[[ "$padrao" == sim && "$no_teste" == sim && "$opcao_antes" == sim && "$pub_log" -ge 1 && "$pub_deploy" == "0:1" && "$r_d0" == 0 && "$lista_0" == "legado15 " && "$pub_puro" == "$ANTES_DA_SENHA" && "$pub_tls" == 0 && "$pub_authd" == 1 \
  && "$pub_lista" == "200 " && "$pub_coluna" == 0 && "$pub_botoes" == 0 && "$pub_tela" == "404 " && "$pub_texto" -ge 1 && "$pub_motivo" == 1 && "$pub_envio" == "404 " && "$lista_1" == "legado15 " \
  && "$pub_seg" == "200 " && "$pub_linha" == 1 && "$pub_alerta" == 0 && "$pub_novo" == "200 " && "$pub_caixa" == 0 && "$pub_cria" == "303 /usuarios?m=criado" && "$lista_c" == "legado15 " \
  && "$pub_editar" == "200 " && "$pub_cartao" == 1 && "$pub_link" == 0 && "$r_e0" == 0 && -z "$lista_2" && "$r_dc" == 0 \
  && "$r_t1" == 0 && "$m_t1" == 1 && "$f_t1" == aberto && "$r_tl" == 0 && "$l_1" == "legado15 " && "$t_puro" == 0 && "$no_painel" == 1 && "$r_t2" == 1 && "$m_t2" == 1 && "$r_t3" != 0 \
  && "$r_t4" == 0 && "$m_t4" == 1 && -z "$l_2" && "$f_t4" == fechado && "$t_exigido" == "$ANTES_DA_SENHA" && "$f_t5" == aberto && "$r_del" == 0 && -z "$l_3" && "$f_t6" == fechado && "$r_re" == 0 \
  && "$t_recriado" == "$ANTES_DA_SENHA" && "$t_recriado_tls" == 0 && "$r_i1" == 0 && "$f_i1" == aberto && "$i_puro" == 0 && "$r_i2" == 0 && "$f_i2" == fechado && "$i_exigido" == "$ANTES_DA_SENHA" && -z "$l_4" ]]
caso $? testes 32 "TLS por usuário pelo terminal e a opção sem efeito com IP público" "padrão da instalação: FTP_TLS_EXCECOES=$padrao (na instância de teste: $no_teste) · com REDE_PERMITIR_IP_PUBLICO=$opcao_antes a opção fica sem efeito: log do FTP 'TLS por usuário sem efeito: não vale com REDE_PERMITIR_IP_PUBLICO=sim': $pub_log, deploy.sh --check-only (saída:linhas do aviso): $pub_deploy · manage-user.sh tls-dispensar legado15 grava a lista (saída $r_d0, lista: ${lista_0:-vazia}) e não muda nada: legado15 sem TLS: $pub_puro, com TLS: $pub_tls, pure-authd no container: $pub_authd · no painel: aba Usuários $pub_lista, coluna TLS: $pub_coluna, botões de TLS: $pub_botoes; GET /usuarios/tls: $pub_tela('TLS por usuário sem efeito': $pub_texto, com o motivo: $pub_motivo); POST /usuarios/tls: $pub_envio, lista depois: ${lista_1:-vazia}; aba Segurança 'Sem exceção por usuário' com o motivo: $pub_linha, alerta de dispensado no topo: $pub_alerta; Novo usuário $pub_novo, caixa do TLS: $pub_caixa; POST de novo usuário com sem_tls=sim forjado: $pub_cria, lista depois: ${lista_c:-vazia}; Editar $pub_editar, cartão do TLS com o motivo: $pub_cartao, link para dispensar: $pub_link · com a opção valendo (IP privado): tls-dispensar legado15: saída $r_t1, FTP $f_t1, tls-lista: ${l_1:-vazia}, legado15 sem TLS: $t_puro, etiqueta no painel: $no_painel · tls-dispensar de quem não existe: saída $r_t2 ('Usuario nao existe': $m_t2); com nome fora da regra: saída $r_t3 · tls-exigir legado15: saída $r_t4, lista: ${l_2:-vazia}, FTP $f_t4, sem TLS: $t_exigido · dispensado (FTP $f_t5), removido (del: saída $r_del, lista: ${l_3:-vazia}, FTP $f_t6) e recriado (add: saída $r_re): sem TLS $t_recriado, com TLS $t_recriado_tls · usuário inicial $USUARIO dispensado (saída $r_i1, FTP $f_i1): sem TLS $i_puro; exigido de novo (saída $r_i2, FTP $f_i2): $i_exigido, lista: ${l_4:-vazia}"

# ------------------------------------------------------------------ dispensar ao criar e o cartão do TLS em Editar
auditoria; c_antes="$(eventos usuario_criado)"; d_antes="$(eventos tls_dispensado)"
n_tela="$(aba -b "$J" "$B/usuarios/novo")"; n_caixa="$(contar 'name="sem_tls" value="sim"')"; n_marcada="$(contar 'name="sem_tls" value="sim" checked')"; n_aviso="$(contar 'Sem marcar a caixa, o usuário só entra com TLS')"
r_n1="$(criar15 novo15 "$W/u15c.senha" --data-urlencode 'sem_tls=sim')"; f_n1="$(modo15)"; l_n1="$(dispensados)"
aba -b "$J" "$B/usuarios?m=criado_sem_tls" > /dev/null; msg_n1="$(contar 'Usuário criado e dispensado do TLS: a senha e os arquivos dele passam em texto puro')"; etq_n1="$(contar '<td><span class="etiqueta atencao">sem TLS</span></td>')"
n1_puro="$(tenta puro novo15 "$W/u15c.senha")"; n1_tls="$(tenta tls novo15 "$W/u15c.senha")"
# Sem a caixa, e com a caixa em outro valor que não o do formulário: o usuário nasce obrigado a usar TLS.
r_n2="$(criar15 comtls15 "$W/u15d.senha")"; r_n3="$(criar15 valor15 "$W/u15d.senha" --data-urlencode 'sem_tls=on')"; l_n3="$(dispensados)"
n2_puro="$(tenta puro comtls15 "$W/u15d.senha")"; n2_tls="$(tenta tls comtls15 "$W/u15d.senha")"; n3_puro="$(tenta puro valor15 "$W/u15d.senha")"
# Recusa do formulário (nome fora da regra): nada é criado e a caixa volta marcada.
r_n4="$(c -o "$W/corpo" -w '%{http_code}' -b "$J" -H "Origin: $B" --data-urlencode "csrf=$K" --data-urlencode 'usuario=Nome Errado' --data-urlencode 'sem_tls=sim' "$B/usuarios/novo")"; n4_marcada="$(contar 'name="sem_tls" value="sim" checked')"
# Senha gerada pelo painel: a tela que mostra a senha também diz que o usuário ficou dispensado.
r_n5="$(c -o "$W/u15.gerada" -w '%{http_code}' -b "$J" -H "Origin: $B" --data-urlencode "csrf=$K" --data-urlencode 'usuario=gerado15' --data-urlencode 'pasta=clientes15/gerado15' --data-urlencode 'sem_tls=sim' "$B/usuarios/novo")"
sed -n 's/.*<p class="segredo"><code>\([^<]*\)<\/code>.*/\1/p' "$W/u15.gerada" | head -1 | tr -d '\n' > "$W/u15e.senha"; proibir "$(cat "$W/u15e.senha")"
n5_nota="$(grep -c 'role="alert">Usuário criado e dispensado do TLS' "$W/u15.gerada")"; n5_puro="$(tenta puro gerado15 "$W/u15e.senha")"; l_n5="$(dispensados)"
# Editar mostra como o usuário entra e leva à mesma confirmação da lista.
ed_d="$(aba -b "$J" "$B/usuarios/editar?usuario=novo15")"; ed_cartao="$(contar '<section class="cartao estreito" id="tls">')"; ed_texto="$(contar 'Este usuário entra <strong>sem TLS</strong>')"
ed_link="$(contar 'href="/usuarios/tls?usuario=novo15">Exigir TLS</a>')"
ed_c="$(aba -b "$J" "$B/usuarios/editar?usuario=comtls15")"; ec_texto="$(contar 'Este usuário só entra com <strong>TLS</strong>')"; ec_link="$(contar 'href="/usuarios/tls?usuario=comtls15">Dispensar TLS</a>')"
ed_tela="$(aba -b "$J" "$UT?usuario=novo15")"; ed_pergunta="$(contar 'Sim, voltar a exigir o TLS')"
r_n6="$(pedir_tls novo15 exigir)"; l_n6="$(dispensados)"; f_n6="$(modo15)"; n6_puro="$(tenta puro novo15 "$W/u15c.senha")"; n6_tls="$(tenta tls novo15 "$W/u15c.senha")"
aba -b "$J" "$B/usuarios/editar?usuario=novo15" > /dev/null; ed_volta="$(contar 'href="/usuarios/tls?usuario=novo15">Dispensar TLS</a>')"
auditoria; c_depois="$(eventos usuario_criado)"; d_depois="$(eventos tls_dispensado)"
reg_n1="$(grep -c " evento=tls_dispensado admin=$ADMIN usuario=novo15\$" "$W/auditoria")"; reg_n5="$(grep -c " evento=tls_dispensado admin=$ADMIN usuario=gerado15\$" "$W/auditoria")"
na_auditoria="$(segredos_em "$W/auditoria")"
ok_del=0; for n in novo15 comtls15 valor15 gerado15; do mu del "$n" || ok_del=1; done; l_n7="$(dispensados)"; f_n7="$(modo15)"
[[ "$n_tela" == "200 " && "$n_caixa" == 1 && "$n_marcada" == 0 && "$n_aviso" == 1 && "$r_n1" == "303 /usuarios?m=criado_sem_tls" && "$f_n1" == aberto && "$l_n1" == "novo15 " && "$msg_n1" == 1 && "$etq_n1" == 1 \
  && "$n1_puro" == 0 && "$n1_tls" == 0 && "$r_n2" == "303 /usuarios?m=criado" && "$r_n3" == "303 /usuarios?m=criado" && "$l_n3" == "novo15 " && "$n2_puro" == "$DEPOIS_DA_SENHA" && "$n2_tls" == 0 && "$n3_puro" == "$DEPOIS_DA_SENHA" \
  && "$r_n4" == 400 && "$n4_marcada" == 1 && "$r_n5" == 200 && -s "$W/u15e.senha" && "$n5_nota" == 1 && "$n5_puro" == 0 && "$l_n5" == "gerado15 novo15 " \
  && "$ed_d" == "200 " && "$ed_cartao" == 1 && "$ed_texto" == 1 && "$ed_link" == 1 && "$ed_c" == "200 " && "$ec_texto" == 1 && "$ec_link" == 1 && "$ed_tela" == "200 " && "$ed_pergunta" == 1 \
  && "$r_n6" == "303 /usuarios?m=tls_exigido" && "$l_n6" == "gerado15 " && "$f_n6" == aberto && "$n6_puro" == "$DEPOIS_DA_SENHA" && "$n6_tls" == 0 && "$ed_volta" == 1 \
  && "$c_depois" == $((c_antes + 4)) && "$d_depois" == $((d_antes + 2)) && "$reg_n1" == 1 && "$reg_n5" == 1 && "$na_auditoria" == 0 && "$ok_del" == 0 && -z "$l_n7" && "$f_n7" == fechado ]]
caso $? testes 52 "Usuário criado já dispensado do TLS e o cartão do TLS em Editar" "Novo usuário: $n_tela, caixa 'entrar sem TLS': $n_caixa (marcada de início: $n_marcada), aviso de texto puro ao lado: $n_aviso · POST com a caixa marcada: $r_n1, FTP $f_n1, lista dos dispensados: ${l_n1:-vazia}, mensagem com o alerta: $msg_n1, etiqueta 'sem TLS' na lista: $etq_n1; novo15 sem TLS: $n1_puro, com TLS: $n1_tls · sem a caixa: $r_n2; com sem_tls=on forjado: $r_n3; lista: ${l_n3:-vazia}; comtls15 sem TLS: $n2_puro, com TLS: $n2_tls; valor15 sem TLS: $n3_puro · nome fora da regra com a caixa marcada: $r_n4, caixa de volta marcada: $n4_marcada · senha gerada pelo painel com a caixa marcada: $r_n5, nota da dispensa na tela da senha: $n5_nota, gerado15 sem TLS com a senha da tela: $n5_puro, lista: ${l_n5:-vazia} · Editar de novo15: $ed_d, cartão do TLS: $ed_cartao, 'entra sem TLS': $ed_texto, link Exigir TLS: $ed_link; Editar de comtls15: $ed_c, 'só entra com TLS': $ec_texto, link Dispensar TLS: $ec_link · pelo link, a confirmação: $ed_tela com a pergunta: $ed_pergunta; POST exigir: $r_n6, lista: ${l_n6:-vazia}, FTP $f_n6 (gerado15 segue dispensado), novo15 sem TLS: $n6_puro, com TLS: $n6_tls, Editar volta a oferecer Dispensar TLS: $ed_volta · auditoria: usuario_criado $c_antes → $c_depois, tls_dispensado $d_antes → $d_depois, com administrador e usuário: $reg_n1 e $reg_n5; senhas, tokens e cookies na auditoria: $na_auditoria · os quatro removidos (falhas: $ok_del): lista ${l_n7:-vazia}, FTP $f_n7"

# ------------------------------------------------------------------ sem TLS só entra quem foi dispensado
mu tls-dispensar legado15; r_marca=$?; f_marca="$(modo15)"
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
[[ "$r_marca" == 0 && "$f_marca" == aberto && "$s_certa" == "$DEPOIS_DA_SENHA" && "$s_errada" == "$DEPOIS_DA_SENHA" && "$s_alheia" == "$DEPOIS_DA_SENHA" && "$s_ninguem" == "$DEPOIS_DA_SENHA" && "$s_estranho" == "$DEPOIS_DA_SENHA" && "$s_maiusculo" == "$DEPOIS_DA_SENHA" \
  && "$c_certa" == 0 && "$c_controle" == 0 && "$c_errada" == "$DEPOIS_DA_SENHA" && "$m_certa" == 0 && "$r_viz" != 0 && "$r_cad" != 0 && "$ve_vizinho" == 0 && "$vazou15" == 0 \
  && "$p_depois" == $((p_antes + 1)) && "$m_depois" == "$m_antes" && "$n_ninguem" -ge 1 && "$f_depois" -ge $((f_antes + 1)) && "$nos_logs" == 0 && "$permissoes" == "600 root:root 600 root:root " ]]
caso $? seguranca 64 "Sem TLS só entra quem o administrador dispensou" "com legado15 dispensado e equip15 não (FTP $f_marca) · sem TLS: equip15 com a senha certa: $s_certa · legado15 com senha errada: $s_errada, com a senha de equip15: $s_alheia · usuário que não existe: $s_ninguem · nome '../../auth/sem-tls.lista': $s_estranho · LEGADO15 em maiúsculas com a senha de legado15: $s_maiusculo · legado15 com a senha certa: $m_certa · com TLS: equip15 com a senha certa: $c_certa, com TLS só no login: $c_controle, com senha errada: $c_errada · legado15, sem TLS, pede o arquivo do vizinho por ..: saída $r_viz; o cadastro do FTP: saída $r_cad; pastas ou arquivos do vizinho na listagem de ..: $ve_vizinho; conteúdo do vizinho, linha de cadastro ou hash no que veio: $vazou15 · log do FTP: recusas do porteiro para equip15: $p_antes → $p_depois (uma, a da senha certa em texto puro), para legado15: $m_antes → $m_depois (a senha errada dele é recusada pelo cadastro, não pelo porteiro), para o nome que não existe: $n_ninguem, 'nome fora da regra' no lugar do que o cliente mandou: $f_antes → $f_depois · senhas, tokens e cookies no log do FTP: $nos_logs · lista dos dispensados e soquete do pure-authd (modo e dono): $permissoes(curl: 0 = entrou, 67 = login recusado; 530 = resposta do servidor)"

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
v_modo="$(modo15)"; v_authd="$(processos15 pure-authd)"; v_marcado="$(tenta puro legado15 "$W/u15b.senha")"; v_outro="$(tenta puro equip15 "$W/u15a.senha")"; v_tls="$(tenta tls equip15 "$W/u15a.senha")"
v_painel="$(aba -b "$J" "$B/usuarios")"; v_lista="$(dispensados)"
# A recusa por falta de TLS não é senha errada: todas as tentativas acima não bloqueiam equip15.
v_bloqueios="$(docker exec "$FTP" sh -c 'ls /auth/bloqueios 2>/dev/null' | grep -c '^equip15@')"
[[ "$vivos" == 1 && "$v_bloqueios" == 0 && "$passou" == 0 && "$paralelo_passou" == 0 && "$(wc -w <<< "$em_paralelo")" == 8 && "$r_volta" == 0 && "$rc_depois" -gt "$rc_antes" && "$ini_depois" != "$ini_antes" \
  && "$ids_antes" == "$(ids)" && "$q_depois" == $((q_antes + 1)) && "$nos_logs" == 0 && "$v_modo" == aberto && "$v_authd" == 1 && "$v_marcado" == 0 && "$v_outro" == "$DEPOIS_DA_SENHA" && "$v_tls" == 0 \
  && "$v_painel" == "200 " && "$v_lista" == "legado15 " ]]
caso $? seguranca 65 "pure-authd morto: o FTP encerra em vez de liberar a entrada sem TLS" "kill -9 no pure-authd dentro do container do FTP (processos pure-authd antes: $vivos) · 8 tentativas sem TLS de equip15, não dispensado e com a senha certa, disparadas junto com a queda: saídas do curl $em_paralelo(entraram: $paralelo_passou) · mais $tentativas em sequência até o container voltar: $codigos(entraram: $passou) · log do FTP 'FALHA: o pure-authd saiu': $q_antes → $q_depois · reinícios do container: $rc_antes → $rc_depois, mesmo container (os três com os mesmos IDs: $([[ "$ids_antes" == "$(ids)" ]] && echo sim || echo NÃO)), saudável de novo: $([[ "$r_volta" == 0 ]] && echo sim || echo NÃO) · depois da volta: FTP $v_modo, pure-authd no container: $v_authd, legado15 sem TLS: $v_marcado, equip15 sem TLS: $v_outro, equip15 com TLS: $v_tls, bloqueios por tentativa de equip15 depois de todas as recusas sem TLS: $v_bloqueios, lista dos dispensados: ${v_lista:-vazia}, aba Usuários: $v_painel· senhas no log do FTP: $nos_logs (curl: 0 = entrou, 7 = porta fechada, 56 e 28 = conexão cortada, 67 = login recusado)"

# ------------------------------------------------------------------ sem dispensado, recusa antes da senha; a troca de modo não derruba sessão
head -c 4194304 /dev/urandom > "$W/u15.grande"
r_g1="$(ftp_curl tls equip15 "$W/u15a.senha" -T "$W/u15.grande" "$F/grande15.bin")"; r_g2="$(ftp_curl tls legado15 "$W/u15b.senha" -T "$W/u15.grande" "$F/grande15.bin")"
u_aberto="$(ao_user equip15)"                                                   # com dispensado, o servidor pede a senha a qualquer nome
rc_antes="$(docker inspect -f '{{.RestartCount}}' "$FTP")"; ini_antes="$(docker inspect -f '{{.State.StartedAt}}' "$FTP")"; ids_antes="$(ids)"; tr_antes="$(trocas15)"
mu tls-exigir legado15; r_x1=$?; x1="$(modo15)"
u_fechado="$(ao_user equip15)"; u_ex="$(ao_user legado15)"; u_ninguem="$(ao_user ninguem15)"; u_estranho="$(ao_user '../../auth/sem-tls.lista')"
x1_puro="$(tenta puro equip15 "$W/u15a.senha")"; x1_tls="$(tenta tls equip15 "$W/u15a.senha")"; x1_controle="$(tenta controle equip15 "$W/u15a.senha")"
docker logs "$FTP" > "$W/ftp.log" 2>&1; pr_antes="$(recusas15 equip15)"
# Duas sessões em andamento atravessam as trocas: a de equip15, com TLS, as duas; a de legado15, sem TLS, a que volta a fechar.
longa15 tls equip15 "$W/u15a.senha" "$W/u15.longa-tls" 300k & s_tls=$!
sleep 1
mu tls-dispensar legado15; r_x2=$?; x2="$(modo15)"
longa15 puro legado15 "$W/u15b.senha" "$W/u15.longa-puro" 400k & s_puro=$!
sleep 1
mu tls-exigir legado15; r_x3=$?; x3="$(modo15)"
viva_tls="$(kill -0 "$s_tls" 2>/dev/null && echo sim || echo NÃO)"; viva_puro="$(kill -0 "$s_puro" 2>/dev/null && echo sim || echo NÃO)"
x3_puro="$(tenta puro legado15 "$W/u15b.senha")"; x3_tls="$(tenta tls legado15 "$W/u15b.senha")"
wait "$s_tls" "$s_puro" 2>/dev/null
fim_s_tls="$(cat "$W/u15.longa-tls.saida" 2>/dev/null)"; fim_s_puro="$(cat "$W/u15.longa-puro.saida" 2>/dev/null)"
igual_tls="$(cmp -s "$W/u15.grande" "$W/u15.longa-tls" && echo idêntico || echo DIFERENTE)"; igual_puro="$(cmp -s "$W/u15.grande" "$W/u15.longa-puro" && echo idêntico || echo DIFERENTE)"
rc_depois="$(docker inspect -f '{{.RestartCount}}' "$FTP")"; ini_depois="$(docker inspect -f '{{.State.StartedAt}}' "$FTP")"; tr_depois="$(trocas15)"; saude_fim="$(docker inspect -f '{{.State.Health.Status}}' "$FTP")"
docker logs "$FTP" > "$W/ftp.log" 2>&1; pr_depois="$(recusas15 equip15)"; falhas_fim="$(grep -c '^FALHA: ' "$W/ftp.log")"; nos_logs="$(segredos_em "$W/ftp.log")"
x_authd="$(processos15 pure-authd)"
[[ "$r_g1" == 0 && "$r_g2" == 0 && "$u_aberto" == 331 && "$r_x1" == 0 && "$x1" == fechado && "$u_fechado" == 421 && "$u_ex" == 421 && "$u_ninguem" == 421 && "$u_estranho" == 421 \
  && "$x1_puro" == "$ANTES_DA_SENHA" && "$x1_tls" == 0 && "$x1_controle" == 0 && "$r_x2" == 0 && "$x2" == aberto && "$r_x3" == 0 && "$x3" == fechado && "$viva_tls" == sim && "$viva_puro" == sim \
  && "$x3_puro" == "$ANTES_DA_SENHA" && "$x3_tls" == 0 && "$fim_s_tls" == 0 && "$fim_s_puro" == 0 && "$igual_tls" == idêntico && "$igual_puro" == idêntico \
  && "$rc_depois" == "$rc_antes" && "$ini_depois" == "$ini_antes" && "$ids_antes" == "$(ids)" && "$tr_depois" == $((tr_antes + 3)) && "$saude_fim" == healthy && "$pr_depois" == "$pr_antes" \
  && "$falhas_fim" == "$q_depois" && "$nos_logs" == 0 && "$x_authd" == 1 ]]
caso $? seguranca 89 "Sem dispensado, a sessão sem TLS é recusada antes da senha; a troca de modo não derruba sessão" "com legado15 dispensado, resposta ao USER sem TLS de equip15: $u_aberto (o servidor pede a senha) · legado15 volta a ser obrigado (saída $r_x1, FTP $x1): resposta ao USER sem TLS de equip15: $u_fechado, de legado15: $u_ex, de quem não existe: $u_ninguem, de nome fora da regra: $u_estranho; equip15 sem TLS com a senha certa: $x1_puro, com TLS: $x1_tls, com TLS só no login: $x1_controle; recusas do porteiro para equip15 no log: $pr_antes → $pr_depois (a senha não chegou a ser enviada) · com um download de 4 MiB de equip15 em andamento com TLS: legado15 dispensado (saída $r_x2, FTP $x2), começa um download de 4 MiB sem TLS, e volta a ser obrigado (saída $r_x3, FTP $x3) · depois das trocas, sessão com TLS ainda em andamento: $viva_tls, sessão sem TLS ainda em andamento: $viva_puro; nova sessão de legado15 sem TLS: $x3_puro, com TLS: $x3_tls · ao terminar: download com TLS saída $fim_s_tls ($igual_tls), download sem TLS saída $fim_s_puro ($igual_puro) · trocas de modo no log do FTP: $tr_antes → $tr_depois; reinícios do container: $rc_antes → $rc_depois, mesmo início: $([[ "$ini_depois" == "$ini_antes" ]] && echo sim || echo NÃO), os três containers com os mesmos IDs: $([[ "$ids_antes" == "$(ids)" ]] && echo sim || echo NÃO), saúde: $saude_fim, pure-authd no container: $x_authd, linhas 'FALHA:' no log além da queda provocada no caso anterior: $((falhas_fim - q_depois)) · senhas no log do FTP: $nos_logs (331 = o servidor pede a senha; 421 = recusa na resposta ao USER, antes da senha; curl: 0 = entrou ou baixou, 28 = o servidor encerrou a sessão, 67 = login recusado)"
achado seguranca "A sessão sem TLS que já estava aberta continua até terminar depois que o administrador volta a exigir o TLS do usuário" "A regra do TLS vale na entrada: a troca de modo não derruba sessão, nem a de quem perdeu a dispensa. Uma sessão nova desse usuário sem TLS é recusada antes da senha. Para cortar na hora, quem administra o servidor reinicia o serviço do FTP (docker compose restart ftp), que encerra todas as sessões; como a senha passou em texto puro, o painel orienta a trocá-la em seguida."
achado seguranca "A troca de modo recomeça a contagem de conexões do servidor FTP" "O processo que escuta a porta é trocado, e é ele que conta as sessões abertas para FTP_MAX_CLIENTS e para o limite por endereço. As sessões abertas antes da troca continuam, mas deixam de contar: até elas terminarem, o servidor pode aceitar mais sessões do que o teto do porte. A troca só acontece quando a lista dos dispensados sai de vazia ou volta a ficar vazia, por ação do administrador."

# ------------------------------------------------------------------ opção sem efeito ou desligada, valores recusados e quem altera a lista
mu tls-dispensar legado15; r_m6=$?; f_m6="$(modo15)"
ev=""; ok=0
while IFS='|' read -r troca texto; do
  # shellcheck disable=SC2086
  d="$(recusa_deploy $troca)"; kf="$(recusa_container ftp $troca)"; kp="$(recusa_container painel $troca)"
  certa=sim; recusou "$d" "$texto" && [[ "$kf" == "saída 1 · "*"$texto"* && "$kp" == "saída 1 · "*"$texto"* ]] || { ok=1; certa=NÃO; }
  ev+="$troca: deploy.sh ${d%% · *}, container do ftp ${kf%% · *}, do painel ${kp%% · *}, mensagem esperada nos três: $certa; "
done <<'TROCAS'
FTP_TLS_EXCECOES=talvez|FTP_TLS_EXCECOES deve ser
FTP_TLS_EXCECOES=SIM|FTP_TLS_EXCECOES deve ser
TROCAS
# Fora do modo 2 a opção não recusa a subida: fica sem efeito, e o deploy.sh diz o motivo.
ev_modo=""; ok_modo=0
for modo in 0 1 3; do
  antes="$(ids)"; conferir_deploy "FTP_TLS_MODE=$modo"; r="$?"; linha="$(grep -c "^TLS por usuário sem efeito: só vale com FTP_TLS_MODE=2; em .* está '$modo'" "$W/recusa.log")"
  [[ "$r" == 0 && "$linha" == 1 && "$antes" == "$(ids)" ]] || ok_modo=1
  ev_modo+="FTP_TLS_MODE=$modo: saída $r, aviso 'sem efeito': $linha; "
done
# Com FTP_TLS_MODE=3 de verdade: o dispensado da lista não entra sem TLS, e o painel troca os botões pelo motivo.
gravar_env "$ENVA" FTP_TLS_MODE 3; dep; r_m3=$?; painel_de_pe
e_adm3="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
docker logs "$FTP" > "$W/ftp.log" 2>&1; m3_log="$(grep -c 'TLS por usuário sem efeito: só vale com FTP_TLS_MODE=2; está 3' "$W/ftp.log")"; m3_lista="$(dispensados)"
m3_puro="$(ESPERA_PURO=10 tenta puro legado15 "$W/u15b.senha")"; m3_tls="$(tenta tls legado15 "$W/u15b.senha")"; m3_user="$(ao_user legado15)"
aba -b "$J" "$B/usuarios" > /dev/null; m3_coluna="$(contar '<th>TLS</th>')"
m3_tela="$(aba -b "$J" "$UT?usuario=legado15")"; m3_motivo="$(contar 'ela só vale com <code>FTP_TLS_MODE=2</code>, e o FTP está em outro modo')"
m3_envio="$(pedir_tls legado15 exigir)"
aba -b "$J" "$B/seguranca" > /dev/null; m3_seg="$(contar 'Sem exceção por usuário: ela só vale com <code>FTP_TLS_MODE=2</code>')"; m3_alerta="$(contar 'entram no FTP sem TLS')"
aba -b "$J" "$B/usuarios/novo" > /dev/null; m3_caixa="$(contar 'name="sem_tls"')"
# Desligada no .env (FTP_TLS_EXCECOES=nao), de volta ao modo 2: a lista segue guardada e ninguém entra sem TLS.
gravar_env "$ENVA" FTP_TLS_MODE 2; gravar_env "$ENVA" FTP_TLS_EXCECOES nao; dep; r_nao=$?; painel_de_pe
e_adm4="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
nao_puro="$(ESPERA_PURO=10 tenta puro legado15 "$W/u15b.senha")"; nao_tls="$(tenta tls legado15 "$W/u15b.senha")"; nao_authd="$(processos15 pure-authd)"; nao_lista="$(dispensados)"
nao_resumo="$(grep -c 'equipamento sem suporte a TLS: o administrador dispensa' "$W/deploy.log")"
nao_tela="$(aba -b "$J" "$UT?usuario=legado15")"; nao_motivo="$(contar 'a opção está desligada (<code>FTP_TLS_EXCECOES=nao</code>)')"
aba -b "$J" "$B/seguranca" > /dev/null; nao_seg="$(contar 'Sem exceção por usuário: a opção está desligada (<code>FTP_TLS_EXCECOES=nao</code>)')"
aba -b "$J" "$B/usuarios/novo" > /dev/null; nao_caixa="$(contar 'name="sem_tls"')"
# De volta ao padrão, com a opção valendo, para as recusas de papel, de token e de nome.
gravar_env "$ENVA" FTP_TLS_EXCECOES sim; dep; r_sim=$?; painel_de_pe; f_sim="$(modo15)"
aviso_deploy="$(grep -c '^AVISO: TLS por usuário: 1 usuário(s) dispensado(s) na aba Usuários do painel entram SEM TLS' "$W/deploy.log")"
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
e_u="$(entra equip15 "$U" "$W/u15a.senha")"; proibir "$(biscoito_de "$U")"
UK="$(c -b "$U" "$B/meus-arquivos" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1)"; proibir "$UK"
auditoria; n_antes="$(eventos recusa_papel)"; d_antes="$(eventos tls_dispensado)"; x_antes="$(eventos tls_exigido)"; soma_antes="$(soma_lista)"
g_usuario="$(aba -b "$U" "$UT?usuario=equip15")"; no_corpo="$(grep -c -E 'legado15|Dispensar|sem TLS' "$W/corpo")"
p_usuario="$(POTE="$U" envio /usuarios/tls --data-urlencode "csrf=$UK" --data-urlencode 'usuario=equip15' --data-urlencode 'acao=dispensar')"
p_usuario_x="$(POTE="$U" envio /usuarios/tls --data-urlencode "csrf=$UK" --data-urlencode 'usuario=legado15' --data-urlencode 'acao=exigir')"
p_usuario_n="$(POTE="$U" envio /usuarios/novo --data-urlencode "csrf=$UK" --data-urlencode 'usuario=intruso15' --data-urlencode 'sem_tls=sim')"
g_anonimo="$(aba "$UT?usuario=equip15")"
p_anonimo="$(POTE=/dev/null envio /usuarios/tls --data-urlencode 'usuario=equip15' --data-urlencode 'acao=dispensar')"
p_sem_token="$(envio /usuarios/tls --data-urlencode 'usuario=equip15' --data-urlencode 'acao=dispensar')"
p_origem="$(c -o /dev/null -w '%{http_code}' -b "$J" -H 'Origin: https://outro.exemplo.com.br' --data-urlencode "csrf=$K" --data-urlencode 'usuario=equip15' --data-urlencode 'acao=dispensar' "$UT")"
g_inexistente="$(aba -b "$J" "$UT?usuario=ninguem15")"; p_inexistente="$(pedir_tls ninguem15 dispensar)"
p_nome="$(pedir_tls '../../auth/sem-tls.lista' dispensar)"; p_acao="$(pedir_tls equip15 apagar)"; p_vazia="$(pedir_tls equip15 '')"
auditoria; n_depois="$(eventos recusa_papel)"; d_depois="$(eventos tls_dispensado)"; x_depois="$(eventos tls_exigido)"
registro="$(grep -c ' evento=recusa_papel usuario=equip15 caminho=/usuarios/tls' "$W/auditoria")"; na_auditoria="$(segredos_em "$W/auditoria")"
soma_depois="$(soma_lista)"; l_fim="$(dispensados)"; s_fim="$(tenta puro equip15 "$W/u15a.senha")"; intruso="$(usuarios_ftp | grep -c -w intruso15)"
[[ "$r_m6" == 0 && "$f_m6" == aberto && "$ok" == 0 && "$ok_modo" == 0 && "$r_m3" == 0 && "$e_adm3" == 303 && "$m3_log" -ge 1 && "$m3_lista" == "legado15 " && "$m3_puro" == "$ANTES_DA_SENHA" && "$m3_tls" == 0 && "$m3_user" == 421 \
  && "$m3_coluna" == 0 && "$m3_tela" == "404 " && "$m3_motivo" == 1 && "$m3_envio" == "404 " && "$m3_seg" == 1 && "$m3_alerta" == 0 && "$m3_caixa" == 0 \
  && "$r_nao" == 0 && "$e_adm4" == 303 && "$nao_puro" == "$ANTES_DA_SENHA" && "$nao_tls" == 0 && "$nao_authd" == 1 && "$nao_lista" == "legado15 " && "$nao_resumo" == 0 && "$nao_tela" == "404 " && "$nao_motivo" == 1 && "$nao_seg" == 1 && "$nao_caixa" == 0 \
  && "$r_sim" == 0 && "$f_sim" == aberto && "$aviso_deploy" == 1 && "$e_adm" == 303 \
  && "$e_u" == 303 && "$g_usuario" == "404 " && "$no_corpo" == 0 && "$p_usuario" == "404 " && "$p_usuario_x" == "404 " && "$p_usuario_n" == "404 " && "$intruso" == 0 && "$g_anonimo" == "303 /entrar" && "$p_anonimo" == "303 /entrar" \
  && "$p_sem_token" == "403 " && "$p_origem" == 403 && "$g_inexistente" == "404 " && "$p_inexistente" == "404 " && "$p_nome" == "404 " && "$p_acao" == "303 /usuarios/tls?usuario=equip15" \
  && "$p_vazia" == "303 /usuarios/tls?usuario=equip15" && "$n_depois" -gt "$n_antes" && "$registro" -ge 1 && "$d_depois" == "$d_antes" && "$x_depois" == "$x_antes" && "$na_auditoria" == 0 \
  && -n "$soma_antes" && "$soma_antes" == "$soma_depois" && "$l_fim" == "legado15 " && "$s_fim" == "$DEPOIS_DA_SENHA" ]]
caso $? seguranca 66 "Opção sem efeito ou desligada, valores recusados na subida e quem altera a lista dos dispensados" "valor fora de sim e nao: $ev(saída 1 = recusado, instância intacta nas duas) · fora do modo 2 o deploy.sh --check-only aceita e avisa: $ev_modo· com legado15 na lista (FTP $f_m6) e FTP_TLS_MODE=3 de verdade (deploy.sh: saída $r_m3): log do FTP 'TLS por usuário sem efeito: só vale com FTP_TLS_MODE=2; está 3': $m3_log, lista guardada: ${m3_lista:-vazia}, legado15 sem TLS: $m3_puro (resposta ao USER: $m3_user), com TLS: $m3_tls; painel: coluna TLS: $m3_coluna, GET /usuarios/tls: $m3_tela(motivo do modo: $m3_motivo), POST: $m3_envio, aba Segurança com o motivo: $m3_seg, alerta de dispensado: $m3_alerta, caixa no Novo usuário: $m3_caixa · com FTP_TLS_EXCECOES=nao e FTP_TLS_MODE=2 (deploy.sh: saída $r_nao): lista guardada: ${nao_lista:-vazia}, legado15 sem TLS: $nao_puro, com TLS: $nao_tls, pure-authd no container: $nao_authd, linha do resumo que aponta a aba Usuários: $nao_resumo; painel: GET /usuarios/tls: $nao_tela(motivo 'a opção está desligada': $nao_motivo), aba Segurança: $nao_seg, caixa no Novo usuário: $nao_caixa · de volta a FTP_TLS_EXCECOES=sim (deploy.sh: saída $r_sim, FTP $f_sim, aviso de 1 dispensado no resumo: $aviso_deploy) · com a sessão de equip15 (usuário do FTP no painel, entrada: $e_u): GET /usuarios/tls: $g_usuario(nome de outro usuário ou botão no corpo: $no_corpo); POST para se dispensar: $p_usuario· POST para tirar a dispensa de legado15: $p_usuario_x· POST de novo usuário já dispensado: $p_usuario_n(criado: $intruso) · sem sessão: GET $g_anonimo e POST $p_anonimo · administrador sem o token: $p_sem_token· com Origin de outro site: $p_origem · usuário que não existe: GET $g_inexistente· POST $p_inexistente· nome '../../auth/sem-tls.lista': $p_nome· ação fora de dispensar e exigir: $p_acao; ação vazia: $p_vazia · recusa_papel na auditoria: $n_antes → $n_depois, com usuário e caminho: $registro · tls_dispensado: $d_antes → $d_depois, tls_exigido: $x_antes → $x_depois · senhas, tokens e cookies na auditoria: $na_auditoria · lista dos dispensados com a mesma soma antes e depois: $([[ -n "$soma_antes" && "$soma_antes" == "$soma_depois" ]] && echo sim || echo NÃO) (${l_fim:-vazia}); equip15 sem TLS: $s_fim"
achado seguranca "Enquanto houver usuário dispensado do TLS, o servidor aceita o comando USER sem TLS de qualquer nome, para poder decidir depois da senha: o cliente mal configurado de um usuário não dispensado envia a senha em texto puro antes de receber o 530" "Custo assumido da dispensa, e o motivo de ela só valer com FTP_TLS_MODE=2 e sem REDE_PERMITIR_IP_PUBLICO=sim. A sessão não entra, o porteiro registra a tentativa no log do FTP com o nome e a origem ('a senha enviada passou em texto puro: troque-a') e o painel avisa no topo quantos usuários estão dispensados. Sem nenhum dispensado, o servidor recusa o USER antes de a senha ser enviada."

# A instância volta ao que a etapa recebeu: ninguém dispensado e a opção de IP público como estava.
mu del equip15; mu del legado15
gravar_env "$ENVA" REDE_PERMITIR_IP_PUBLICO "$opcao_antes"
[[ -n "$redes_antes" ]] && gravar_env "$ENVA" PAINEL_REDES_PERMITIDAS "$redes_antes"
dep; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
docker exec "$FTP" rm -rf /data/clientes15
rm -f "$W"/u15* "$W/b15.jar" "$W/ftp.log"
