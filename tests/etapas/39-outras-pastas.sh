#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa AM: outras pastas do usuário no painel web. Além da pasta do cadastro, que continua só dele, o administrador
# libera a um usuário outras pastas, cada uma com a permissão dela (leitura, envio ou completo), pelo terminal ou
# pelo painel. A etapa prova que a pasta sem liberação não abre, o que cada permissão deixa fazer, que a permissão é
# conferida no servidor a cada pedido (retirar e trocar valem com a sessão aberta), que o pedido não sai da pasta
# liberada, que só o administrador libera, as recusas fora da regra e o teto por usuário. Na rede: o FTP continua
# preso à pasta do cadastro e o corpo grande só passa na rota de envio. No fim, o que acompanha o cadastro.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel encerra as sessões e zera a memória das recusas (a auditoria guarda uma por minuto de cada tipo):
# a primeira recusa de cada tipo nesta etapa é a que fica gravada, e a ordem dos casos conta com isso.
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
P39=/data/f39; F39=0
declare -A T39
igual39() { [[ "$1" == "$2" ]] || F39=1; }                                                      # <obtido> <esperado>
ha39() { [[ "$1" =~ ^[0-9]+$ && "$1" -ge 1 ]] || F39=1; }                                       # <contagem>: ao menos uma
id39() { printf '%s' "$1" | sha256sum | cut -c1-16; }                                           # <pasta> → identificador dela no endereço
tem39() { grep -c -F -- "$1" "$W/corpo" || true; }                                              # <texto>: linhas da última tela com ele
junta39() { cat "$W/corpo" >> "$W/f39.telas"; }                                                 # guarda a última tela
nas39() { grep -c -a -E -- "$1" "$W/f39.telas" || true; }                                       # <expressão>: linhas das telas guardadas com ela
lista39() { docker exec "$FTP" sh -c 'sort /auth/pastas.lista 2> /dev/null' | tr '\n' ';'; }    # a lista das outras pastas
de39() { docker exec "$FTP" sh -c 'grep "^$1 " /auth/pastas.lista 2> /dev/null' sh "$1" | tr -d '\n'; }  # <usuário>: a linha dele
nomes39() { docker exec "$FTP" sh -c 'cd "$1" 2> /dev/null && find . -mindepth 1 | sort | tr "\n" " "' sh "$1"; }  # <pasta>: o que há nela
modo39() { docker exec "$FTP" stat -c '%U:%G %a' "$@" 2>&1 | tr '\n' ' '; }                     # <caminho...>: dono e modo
no_servidor39() { docker exec "$FTP" cat "$1" 2> /dev/null | cmp -s - "$2"; }                   # <arquivo no servidor> <arquivo local>
poe39() { docker exec -i "$FTP" sh -c 'cat > "$1" && chown ftpdata:ftpdata "$1" && chmod 644 "$1"' sh "$1" < "$2"; }  # <arquivo no servidor> <arquivo local>
entra39() { COMO="p39$1" entrar "$W/p39$1.jar" "$W/p39$1.senha"; }                              # <a|b> → código HTTP
sessoes39() { # <a|b>...: entra no painel como cada uma e guarda o token dos formulários dela; os códigos HTTP ficam em $e_web
  local n; e_web=""
  for n in "$@"; do
    e_web+="$(entra39 "$n") "; proibir "$(biscoito_de "$W/p39$n.jar")"
    T39[$n]="$(c -b "$W/p39$n.jar" "$B/meus-arquivos" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1)"; proibir "${T39[$n]}"
  done
}
v39() { c -o "$W/corpo" -w '%{http_code}' -b "$W/p39$1.jar" "$B$2"; }                           # <conta> <caminho> → código
va39() { c -o "$W/corpo" -w '%{http_code}' -b "$J" "$B$1"; }                                    # <caminho> → código, como administrador
p39() { # <conta> <caminho> <campos...> → "código destino", com a sessão e o token dela
  local de="$1" rota="$2"; shift 2
  c -o "$W/corpo" -w '%{http_code} %{redirect_url}' -b "$W/p39$de.jar" -H "Origin: $B" --data-urlencode "csrf=${T39[$de]}" "$@" "$B$rota" \
    | sed -e "s|$B||" -e 's/ $//'
}
m39() { # <conta> <identificador> <pasta> <arquivo local> → "código destino" do envio para a pasta liberada
  sleep 0.05
  curl -sk --max-time 60 -o "$W/corpo" -w '%{http_code} %{redirect_url}' -b "$W/p39$1.jar" -H "Origin: $B" --form-string "csrf=${T39[$1]}" \
    --form-string "pasta=$3" --form-string 'nome=' -F "arquivo=@\"$4\"" "$B/pastas/$2/enviar" | sed -e "s|$B||" -e 's/ $//'
}
a39() { # <caminho> <campos...> → "código destino", como administrador
  local rota="$1"; shift
  c -o "$W/corpo" -w '%{http_code} %{redirect_url}' -b "$J" -H "Origin: $B" --data-urlencode "csrf=$K" "$@" "$B$rota" | sed -e "s|$B||" -e 's/ $//'
}
o39() { a39 /usuarios/outras --data-urlencode "usuario=$1" --data-urlencode "pasta=$2" --data-urlencode "permissao=$3"; }  # <usuário> <pasta> <permissão>
t39() { local usuario="$1"; shift; mu outras "$usuario" "" "$@"; echo "$? $(tail -1 "$W/mu.log" | tr -d '\r\n')"; }       # <usuário> [pasta permissão] → "saída mensagem"
novas39() { auditoria; tail -n +"$((N39 + 1))" "$W/auditoria" > "$W/f39.aud"; }                 # a auditoria desta etapa
aud39() { grep -c -a -F -- "evento=$1" "$W/f39.aud" || true; }                                  # <evento e campos>: linhas com eles
grande39() { # <pote> <token> <caminho> <campo>: formulário com 3 MB em um campo → código
  c -o /dev/null -w '%{http_code}' -b "$1" -H "Origin: $B" --data-urlencode "csrf=$2" --data-urlencode "$4@$W/f39-grande.bin" "$B$3"
}

for n in a b c s; do nova_senha "$W/p39$n.senha"; done
printf 'relatorio-%s\n' "$(openssl rand -hex 8)" > "$W/f39.rel"; printf 'privado-%s\n' "$(openssl rand -hex 8)" > "$W/f39.seg"
printf 'um-%s\n' "$(openssl rand -hex 8)" > "$W/f39-um.cfg"; printf 'tres-%s\n' "$(openssl rand -hex 8)" > "$W/f39-tres.cfg"
head -c 3000000 /dev/urandom > "$W/f39-grande.bin"
REL39="$(cat "$W/f39.rel")"; SEG39="$(cat "$W/f39.seg")"
mu add p39a "$W/p39a.senha" f39/a; r_add="$?"; mu add p39b "$W/p39b.senha" f39/b leitura; r_add+=" $?"
mu add p39s "$W/p39s.senha" f39/s soenvio; r_add+=" $?"; mu limites p39a "" enviar=1; r_add+=" $?"
# A pasta comum e uma pasta dentro da de p39a, com um arquivo em cada lado e um link da comum para a pasta de p39a.
docker exec "$FTP" sh -c "mkdir -p $P39/comum $P39/a/dentro && chown ftpdata:ftpdata $P39 $P39/a $P39/comum $P39/a/dentro \
  && chmod 750 $P39/comum $P39/a/dentro && ln -sfn $P39/a $P39/comum/atalho"
poe39 $P39/comum/relatorio.cfg "$W/f39.rel"; poe39 $P39/a/segredo-de-a.cfg "$W/f39.seg"
C39="$(id39 f39/comum)"; A39="$(id39 f39/a)"; D39="$(id39 f39/a/dentro)"
sessoes39 a b
auditoria; N39="$(wc -l < "$W/auditoria")"

# ------------------------------------------------------------------ sem liberação a pasta não abre
F39=0; : > "$W/f39.telas"; igual39 "$r_add" '0 0 0 0'; igual39 "$e_adm" 303; igual39 "$e_web" '303 303 '
s_b="$(v39 b "/pastas/$C39")"; junta39; s_a="$(v39 a "/pastas/$C39")"; junta39; s_dono="$(v39 b "/pastas/$A39")"; junta39
s_baixa="$(v39 b "/pastas/$C39/baixar?arquivo=relatorio.cfg")"; junta39; s_fora="$(v39 b /pastas/zzzz)"; junta39
s_cria="$(p39 b "/pastas/$C39/pasta" --data-urlencode 'pasta=' --data-urlencode 'nome=de-b')"; s_envia="$(m39 b "$C39" '' "$W/f39-um.cfg")"
s_adm="$(va39 "/pastas/$C39")"; junta39; s_menu="$(v39 b /meus-arquivos)"; s_grupo="$(tem39 'Pastas liberadas')"
s_veio="$(nas39 "$REL39")"; s_nomes="$(nomes39 $P39/comum)"; novas39; s_aud="$(aud39 "recusa_pasta usuario=p39b caminho=/pastas/$C39")"
igual39 "$s_b $s_a $s_dono $s_baixa $s_fora" '404 404 404 404 404'; igual39 "$s_cria" 404; igual39 "$s_envia" 404; igual39 "$s_adm" 404
igual39 "$s_menu $s_grupo" '200 0'; igual39 "$s_veio" 0; igual39 "$s_nomes" './atalho ./relatorio.cfg '; ha39 "$s_aud"
caso "$F39" seguranca 156 "Pasta sem liberação não abre, para o usuário nem pelo endereço" \
  "usuários p39a (completo) e p39b (leitura) criados e no painel: $r_add, entradas $e_web· pasta f39/comum sem liberação: p39b $s_b, p39a $s_a, baixar $s_baixa, criar pasta $s_cria, enviar $s_envia · pasta do cadastro de p39a pedida por p39b: $s_dono · identificador fora do formato: $s_fora · administrador em /pastas: $s_adm · conteúdo do arquivo nas respostas: $s_veio · menu de p39b com 'Pastas liberadas': $s_grupo · pasta depois: $s_nomes· auditoria recusa_pasta de p39b: $s_aud"

# ------------------------------------------------------------------ liberar, trocar e retirar, pelo terminal e pelo painel
F39=0
l_t="$(t39 p39b f39/comum leitura)"; l_modo="$(modo39 /auth/pastas.lista)"; l_1="$(lista39)"; mu outras p39b ""; l_ver="$(tr '\n' ';' < "$W/mu.log")"
l_a="$(o39 p39a f39/comum completo)"; l_troca="$(o39 p39b f39/comum envio)"
l_tela="$(va39 '/usuarios/editar?usuario=p39b')"; l_cartao="$(tem39 'id="outras"')"; l_linha="$(tem39 '<code>f39/comum</code>')"
l_nova="$(o39 p39b f39/nova leitura)"; l_nova_m="$(modo39 $P39/nova)"; l_tira="$(o39 p39b f39/nova nenhuma)"
docker exec "$FTP" test -d $P39/nova; l_fica=$?
l_volta="$(t39 p39b f39/comum leitura)"; l_2="$(lista39)"
novas39; l_aud1="$(aud39 "pasta_liberada admin=$ADMIN usuario=p39a pasta=f39/comum permissao=completo anterior=-")"
l_aud2="$(aud39 "pasta_liberada admin=$ADMIN usuario=p39b pasta=f39/comum permissao=envio anterior=leitura")"
l_aud3="$(aud39 "pasta_retirada admin=$ADMIN usuario=p39b pasta=f39/nova permissao=leitura")"
l_log="$(va39 /atividade)"; l_log1="$(tem39 'Outra pasta liberada a usuário')"; l_log2="$(tem39 'Outra pasta retirada de usuário')"
igual39 "$l_t" '0 Pasta /data/f39/comum liberada ao usuario p39b no painel web: leitura.'; igual39 "$l_modo" 'root:root 600 '
igual39 "$l_1" 'p39b f39/comum=leitura;'; igual39 "$l_ver" 'f39/comum leitura;'
igual39 "$l_a" '303 /usuarios/editar?usuario=p39a&m=liberada#outras'; igual39 "$l_troca" '303 /usuarios/editar?usuario=p39b&m=trocada#outras'
igual39 "$l_tela" 200; ha39 "$l_cartao"; ha39 "$l_linha"; igual39 "$l_nova" '303 /usuarios/editar?usuario=p39b&m=liberada#outras'
igual39 "$l_nova_m" 'ftpdata:ftpdata 750 '; igual39 "$l_tira" '303 /usuarios/editar?usuario=p39b&m=retirada#outras'; igual39 "$l_fica" 0
igual39 "$l_volta" '0 Pasta /data/f39/comum liberada ao usuario p39b no painel web: leitura.'
igual39 "$l_2" 'p39a f39/comum=completo;p39b f39/comum=leitura;'; ha39 "$l_aud1"; ha39 "$l_aud2"; ha39 "$l_aud3"; igual39 "$l_log" 200; ha39 "$l_log1"; ha39 "$l_log2"
caso "$F39" testes 109 "Outra pasta liberada, trocada e retirada pelo terminal e pelo painel" \
  "manage-user.sh outras p39b f39/comum leitura: $l_t · /auth/pastas.lista: $l_modo, conteúdo: $l_1 · manage-user.sh outras p39b: $l_ver · painel, POST /usuarios/outras: liberar a p39a $l_a; trocar a de p39b para envio $l_troca · tela do usuário: $l_tela, cartão Outras pastas: $l_cartao, linha da pasta: $l_linha · pasta que não existia: $l_nova, criada com $l_nova_m; retirada: $l_tira, pasta continua: $([[ $l_fica == 0 ]] && echo sim || echo NÃO) · lista no fim: $l_2 · auditoria: pasta_liberada $l_aud1 e $l_aud2, pasta_retirada $l_aud3 · aba Log: $l_log, liberada $l_log1, retirada $l_log2"

# ------------------------------------------------------------------ a tela da pasta liberada, nas três permissões
F39=0
u_menu="$(v39 b /meus-arquivos)"; u_grupo="$(tem39 'class="grupo">Pastas liberadas')"; u_link="$(tem39 "href=\"/pastas/$C39\" title=\"f39/comum\"")"; u_nome="$(tem39 'class="nome-pasta">comum<')"
u_l="$(v39 b "/pastas/$C39")"; u_titulo="$(tem39 '<title>Pasta liberada')"; u_ativa="$(tem39 "href=\"/pastas/$C39\" title=\"f39/comum\" class=\"ativa\"")"
u_arq="$(tem39 'relatorio.cfg')"; u_fala="$(tem39 'Nesta pasta a permissão desta conta é de leitura')"; u_l_p="$(tem39 "action=\"/pastas/$C39/pasta\"")"; u_l_e="$(tem39 "action=\"/pastas/$C39/enviar\"")"
c -o "$W/f39.baixado" -b "$W/p39b.jar" "$B/pastas/$C39/baixar?arquivo=relatorio.cfg"; cmp -s "$W/f39.rel" "$W/f39.baixado"; u_igual=$?
u_c="$(v39 a "/pastas/$C39")"; u_c_p="$(tem39 "action=\"/pastas/$C39/pasta\"")"; u_c_e="$(tem39 "action=\"/pastas/$C39/enviar\"")"
u_cria="$(p39 a "/pastas/$C39/pasta" --data-urlencode 'pasta=' --data-urlencode 'nome=sub')"
u_envia="$(m39 a "$C39" sub "$W/f39-um.cfg")"; u_modo="$(modo39 $P39/comum/sub $P39/comum/sub/f39-um.cfg)"; no_servidor39 $P39/comum/sub/f39-um.cfg "$W/f39-um.cfg"; u_chegou=$?
u_ren="$(p39 a "/pastas/$C39/renomear" --data-urlencode 'item=sub/f39-um.cfg' --data-urlencode 'nome=dois.cfg' --data-urlencode "senha_atual@$W/p39a.senha")"
u_envia2="$(m39 a "$C39" sub "$W/f39-tres.cfg")"
u_apaga="$(p39 a "/pastas/$C39/apagar" --data-urlencode 'item=sub/f39-tres.cfg' --data-urlencode 'confirmar=sim' --data-urlencode "senha_atual@$W/p39a.senha")"
u_nomes="$(nomes39 $P39/comum)"; u_outro="$(v39 b "/pastas/$C39?pasta=sub")"; u_ve="$(tem39 'dois.cfg')"
# Envio: cria pasta; arquivo, só com a permissão de envio pelo painel da conta.
u_t="$(t39 p39b f39/comum envio)"; u_e="$(v39 b "/pastas/$C39")"; u_e_p="$(tem39 "action=\"/pastas/$C39/pasta\"")"; u_e_e="$(tem39 "action=\"/pastas/$C39/enviar\"")"; u_e_fala="$(tem39 'não envia arquivo para esta pasta')"
u_e_cria="$(p39 b "/pastas/$C39/pasta" --data-urlencode 'pasta=' --data-urlencode 'nome=de-b')"
mu limites p39b "" enviar=1; u_perm=$?; u_p="$(v39 b "/pastas/$C39")"; u_p_e="$(tem39 "action=\"/pastas/$C39/enviar\"")"
u_p_envia="$(m39 b "$C39" de-b "$W/f39-tres.cfg")"; no_servidor39 $P39/comum/de-b/f39-tres.cfg "$W/f39-tres.cfg"; u_p_chegou=$?
mu limites p39b "" enviar=; u_perm+=" $?"; u_volta="$(t39 p39b f39/comum leitura)"
u_adm="$(va39 /usuarios)"; u_adm_g="$(tem39 'Pastas liberadas')"
novas39; u_aud1="$(aud39 'arquivo_baixado usuario=p39b arquivo=f39/comum/relatorio.cfg')"; u_aud2="$(aud39 'pasta_criada usuario=p39a pasta=f39/comum/sub')"
u_aud3="$(aud39 'arquivo_enviado usuario=p39a arquivo=f39/comum/sub/f39-um.cfg')"; u_aud4="$(aud39 'arquivo_enviado usuario=p39b arquivo=f39/comum/de-b/f39-tres.cfg')"
igual39 "$u_menu $u_grupo" '200 1'; ha39 "$u_link"; ha39 "$u_nome"; igual39 "$u_l" 200; ha39 "$u_titulo"; ha39 "$u_ativa"; ha39 "$u_arq"; ha39 "$u_fala"
igual39 "$u_l_p $u_l_e" '0 0'; igual39 "$u_igual" 0; igual39 "$u_c" 200; ha39 "$u_c_p"; ha39 "$u_c_e"
igual39 "$u_cria" "303 /pastas/$C39?pasta=&m=criada"; igual39 "$u_envia" "303 /pastas/$C39?pasta=sub&m=enviado"; igual39 "$u_modo" 'ftpdata:ftpdata 750 ftpdata:ftpdata 644 '
igual39 "$u_chegou" 0; igual39 "$u_ren" "303 /pastas/$C39?pasta=sub&m=renomeado"; igual39 "$u_envia2" "303 /pastas/$C39?pasta=sub&m=enviado"
igual39 "$u_apaga" "303 /pastas/$C39?pasta=sub&m=apagado"; igual39 "$u_nomes" './atalho ./relatorio.cfg ./sub ./sub/dois.cfg '; igual39 "$u_outro" 200; ha39 "$u_ve"
igual39 "$u_t" '0 Pasta /data/f39/comum liberada ao usuario p39b no painel web: envio.'; igual39 "$u_e" 200; ha39 "$u_e_p"; igual39 "$u_e_e" 0; ha39 "$u_e_fala"
igual39 "$u_e_cria" "303 /pastas/$C39?pasta=&m=criada"; igual39 "$u_perm" '0 0'; igual39 "$u_p" 200; ha39 "$u_p_e"
igual39 "$u_p_envia" "303 /pastas/$C39?pasta=de-b&m=enviado"; igual39 "$u_p_chegou" 0; igual39 "${u_volta%% *}" 0; igual39 "$u_adm $u_adm_g" '200 0'
ha39 "$u_aud1"; ha39 "$u_aud2"; ha39 "$u_aud3"; ha39 "$u_aud4"
caso "$F39" testes 110 "Pasta liberada na tela do usuário: leitura, envio e completo" \
  "menu de p39b: $u_menu, grupo Pastas liberadas: $u_grupo, link da pasta: $u_link · leitura (p39b): tela $u_l, título: $u_titulo, item ativo no menu: $u_ativa, arquivo na lista: $u_arq, formulários de pasta e de envio: $u_l_p e $u_l_e, download igual ao arquivo: $([[ $u_igual == 0 ]] && echo sim || echo NÃO) · completo (p39a, com envio pelo painel): tela $u_c, formulários: $u_c_p e $u_c_e; cria pasta $u_cria; envia $u_envia, pasta e arquivo com $u_modo, igual no servidor: $([[ $u_chegou == 0 ]] && echo sim || echo NÃO); renomeia $u_ren; apaga $u_apaga; pasta depois: $u_nomes· p39b vê o que p39a enviou: $u_outro, $u_ve · envio (p39b): $u_t; tela $u_e, formulário de pasta: $u_e_p, de envio: $u_e_e, cria pasta $u_e_cria; com a permissão de envio pelo painel: formulário $u_p_e, envia $u_p_envia, igual no servidor: $([[ $u_p_chegou == 0 ]] && echo sim || echo NÃO) · administrador sem o grupo no menu: $u_adm, $u_adm_g · auditoria: download $u_aud1, pasta criada $u_aud2, envios $u_aud3 e $u_aud4"

# ------------------------------------------------------------------ a permissão vale no servidor
F39=0; p_antes="$(nomes39 $P39/comum)"
p_l1="$(p39 b "/pastas/$C39/pasta" --data-urlencode 'pasta=' --data-urlencode 'nome=forjada')"; p_l2="$(m39 b "$C39" '' "$W/f39-um.cfg")"
p_l3="$(v39 b "/pastas/$C39/renomear?item=relatorio.cfg")"
p_l4="$(p39 b "/pastas/$C39/renomear" --data-urlencode 'item=relatorio.cfg' --data-urlencode 'nome=x.cfg' --data-urlencode "senha_atual@$W/p39b.senha")"
p_l5="$(p39 b "/pastas/$C39/apagar" --data-urlencode 'item=relatorio.cfg' --data-urlencode 'confirmar=sim' --data-urlencode "senha_atual@$W/p39b.senha")"
novas39; p_aud1="$(aud39 "recusa_papel usuario=p39b caminho=/pastas/$C39/pasta perfil=leitura")"
p_t="$(t39 p39b f39/comum envio)"; p_e1="$(v39 b "/pastas/$C39/renomear?item=relatorio.cfg")"
p_e2="$(p39 b "/pastas/$C39/renomear" --data-urlencode 'item=relatorio.cfg' --data-urlencode 'nome=x.cfg' --data-urlencode "senha_atual@$W/p39b.senha")"
p_e3="$(p39 b "/pastas/$C39/apagar" --data-urlencode 'item=relatorio.cfg' --data-urlencode 'confirmar=sim' --data-urlencode "senha_atual@$W/p39b.senha")"
# Com a permissão de envio na pasta e sem a permissão de envio pelo painel da conta, o arquivo não entra.
p_e4="$(m39 b "$C39" '' "$W/f39-um.cfg")"; p_e4_fala="$(tem39 'Envio não permitido')"
novas39; p_aud2="$(aud39 'recusa_envio usuario=p39b perfil=envio')"
p_volta="$(t39 p39b f39/comum leitura)"; p_depois="$(nomes39 $P39/comum)"
igual39 "$p_l1 $p_l2 $p_l3 $p_l4 $p_l5" '404 404 404 404 404'; ha39 "$p_aud1"; igual39 "${p_t%% *}" 0; igual39 "$p_e1 $p_e2 $p_e3" '404 404 404'
igual39 "$p_e4" 403; ha39 "$p_e4_fala"; ha39 "$p_aud2"; igual39 "${p_volta%% *}" 0; igual39 "$p_depois" "$p_antes"
caso "$F39" seguranca 157 "Permissão da pasta liberada vale no servidor, em pedido forjado" \
  "p39b com leitura em f39/comum: criar pasta $p_l1, enviar $p_l2, tela de renomear $p_l3, renomear $p_l4, apagar $p_l5; auditoria recusa_papel com perfil=leitura: $p_aud1 · com envio: tela de renomear $p_e1, renomear $p_e2, apagar $p_e3; enviar sem a permissão de envio pelo painel: $p_e4, 'Envio não permitido' na tela: $p_e4_fala, auditoria recusa_envio: $p_aud2 · pasta $([[ "$p_depois" == "$p_antes" ]] && echo 'igual antes e depois' || echo MUDOU): $p_depois"

# ------------------------------------------------------------------ o pedido não sai da pasta liberada
F39=0; : > "$W/f39.telas"
f_1="$(v39 b "/pastas/$C39?pasta=../a")"; junta39; f_2="$(v39 b "/pastas/$C39/baixar?arquivo=../a/segredo-de-a.cfg")"; junta39
f_3="$(v39 b "/pastas/$C39?pasta=atalho")"; junta39; f_3_nome="$(tem39 'segredo-de-a')"; f_4="$(v39 b "/pastas/$C39/baixar?arquivo=atalho/segredo-de-a.cfg")"; junta39
f_t="$(t39 p39b f39/a/dentro leitura)"; f_5="$(v39 b "/pastas/$D39")"; junta39; f_6="$(v39 b "/pastas/$A39")"; junta39
f_7="$(v39 b "/pastas/$D39?pasta=..")"; junta39; f_8="$(v39 b "/pastas/$D39/baixar?arquivo=../segredo-de-a.cfg")"; junta39
f_veio="$(nas39 "$SEG39")"; novas39; f_aud="$(aud39 'recusa_caminho usuario=p39b caminho=../a')"
igual39 "$f_1 $f_2" '400 400'; igual39 "$f_3 $f_3_nome $f_4" '403 0 403'; igual39 "${f_t%% *}" 0; igual39 "$f_5 $f_6" '200 404'; igual39 "$f_7 $f_8" '400 400'
igual39 "$f_veio" 0; ha39 "$f_aud"
caso "$F39" seguranca 158 "Pedido não sai da pasta liberada: caminho com .., link simbólico e pasta de cima" \
  "p39b em f39/comum: ?pasta=../a $f_1, baixar ../a/segredo-de-a.cfg $f_2 · link simbólico para a pasta de p39a: ?pasta=atalho $f_3, nome do arquivo na tela: $f_3_nome, baixar atalho/segredo-de-a.cfg $f_4 · liberada só f39/a/dentro: a pasta $f_5, a de cima (f39/a) $f_6, ?pasta=.. $f_7, baixar ../segredo-de-a.cfg $f_8 · conteúdo do arquivo de p39a nas respostas: $f_veio · auditoria recusa_caminho: $f_aud"

# ------------------------------------------------------------------ retirar e trocar valem no pedido seguinte
F39=0; : > "$W/f39.telas"; x_antes="$(biscoito_de "$W/p39b.jar")"
x_1="$(v39 b "/pastas/$C39")"; x_t="$(t39 p39b f39/comum nenhuma)"
x_2="$(v39 b "/pastas/$C39")"; junta39; x_3="$(v39 b "/pastas/$C39/baixar?arquivo=relatorio.cfg")"; junta39; x_veio="$(nas39 "$REL39")"
x_4="$(v39 b /meus-arquivos)"; x_link="$(tem39 "href=\"/pastas/$C39\"")"; x_a="$(v39 a "/pastas/$C39")"
x_p1="$(o39 p39b f39/comum completo)"; x_5="$(v39 b "/pastas/$C39")"; x_5_p="$(tem39 "action=\"/pastas/$C39/pasta\"")"
x_p2="$(o39 p39b f39/comum leitura)"; x_6="$(v39 b "/pastas/$C39")"; x_6_p="$(tem39 "action=\"/pastas/$C39/pasta\"")"
x_7="$(p39 b "/pastas/$C39/pasta" --data-urlencode 'pasta=' --data-urlencode 'nome=tarde')"
docker exec "$FTP" test -f $P39/comum/relatorio.cfg; x_fica=$?
igual39 "$x_1" 200; igual39 "$x_t" '0 Pasta /data/f39/comum retirada do usuario p39b. Os arquivos continuam la.'; igual39 "$x_2 $x_3 $x_veio" '404 404 0'
igual39 "$x_4 $x_link" '200 0'; igual39 "$x_a" 200; igual39 "$x_p1" '303 /usuarios/editar?usuario=p39b&m=liberada#outras'; igual39 "$x_5" 200; ha39 "$x_5_p"
igual39 "$x_p2" '303 /usuarios/editar?usuario=p39b&m=trocada#outras'; igual39 "$x_6 $x_6_p" '200 0'; igual39 "$x_7" 404; igual39 "$x_fica" 0
igual39 "$(biscoito_de "$W/p39b.jar")" "$x_antes"
caso "$F39" seguranca 159 "Retirada e troca de permissão valem no pedido seguinte, com a sessão aberta" \
  "p39b em f39/comum antes: $x_1 · manage-user.sh outras ... nenhuma: $x_t · mesma sessão depois: tela $x_2, baixar $x_3, conteúdo do arquivo na resposta: $x_veio; Meus arquivos $x_4, link da pasta no menu: $x_link; p39a continua: $x_a · liberada de novo pelo painel com completo: $x_p1, tela $x_5, formulário de pasta: $x_5_p · trocada para leitura: $x_p2, tela $x_6, formulário: $x_6_p, criar pasta $x_7 · arquivo continua na pasta: $([[ $x_fica == 0 ]] && echo sim || echo NÃO) · cookie de sessão de p39b: $([[ "$(biscoito_de "$W/p39b.jar")" == "$x_antes" ]] && echo 'o mesmo' || echo MUDOU)"

# ------------------------------------------------------------------ só o administrador libera
F39=0; : > "$W/f39.telas"; a_antes="$(lista39)"; a_telas=""
a_1="$(p39 a /usuarios/outras --data-urlencode 'usuario=p39a' --data-urlencode 'pasta=f39/b' --data-urlencode 'permissao=completo')"
a_2="$(v39 a '/usuarios/editar?usuario=p39a')"; a_2_c="$(tem39 'id="outras"')"
a_3="$(c -o /dev/null -w '%{http_code}' -b "$J" -H "Origin: $B" --data-urlencode 'usuario=p39b' --data-urlencode 'pasta=f39/comum' --data-urlencode 'permissao=completo' "$B/usuarios/outras")"
a_depois="$(lista39)"
# A tela de quem recebeu a pasta não diz quem mais a alcança, nem de quem é a pasta de cima.
for tela in /meus-arquivos "/pastas/$C39" "/pastas/$C39?pasta=sub" "/pastas/$D39"; do a_telas+="$(v39 b "$tela") "; junta39; done
a_nomes="$(nas39 'p39a|p39s')"
igual39 "$a_1" 404; igual39 "$a_2 $a_2_c" '404 0'; igual39 "$a_3" 403; igual39 "$a_depois" "$a_antes"; igual39 "$a_telas" '200 200 200 200 '; igual39 "$a_nomes" 0
caso "$F39" seguranca 160 "Só o administrador libera pasta, e a tela do usuário não diz quem mais a alcança" \
  "p39a (usuário do FTP) em POST /usuarios/outras, com a sessão e o token dele: $a_1; em /usuarios/editar: $a_2, cartão Outras pastas: $a_2_c · administrador sem o token do formulário: $a_3 · lista $([[ "$a_depois" == "$a_antes" ]] && echo 'igual antes e depois' || echo MUDOU): $a_depois· telas de p39b (Meus arquivos, pasta liberada, subpasta, pasta dentro da de p39a): $a_telas· nome de outra conta nelas: $a_nomes"

# ------------------------------------------------------------------ liberação fora da regra, e o teto por usuário
F39=0; r_antes="$(lista39)"
r_t1="$(t39 p39b f39/comum total)"; r_t2="$(t39 p39b ../etc leitura)"; r_t3="$(t39 p39b f39/b leitura)"; r_t4="$(t39 p39s f39/comum leitura)"
r_t5="$(t39 p39zz f39/comum leitura)"; r_t6="$(t39 p39b f39/comum/atalho leitura)"
r_p1="$(o39 p39b f39/comum leitura)"; r_p1_f="$(tem39 'O usuário já tem esta pasta com esta permissão.')"
r_p2="$(o39 p39b f39/comum total)"; r_p2_f="$(tem39 'Permissão inválida.')"
r_p3="$(o39 p39b ../etc leitura)"; r_p3_f="$(tem39 'Pasta inválida. Veja a regra abaixo do campo.')"
r_p4="$(o39 p39b f39/b leitura)"; r_p4_f="$(tem39 'Esta já é a pasta do usuário: ele a alcança sem liberação.')"
r_p5="$(o39 p39b f39/comum/atalho leitura)"; r_p5_f="$(tem39 'A pasta passa por um link simbólico, que não é aceito.')"
r_p6="$(o39 p39s f39/comum leitura)"; r_p7="$(o39 p39zz f39/comum leitura)"
r_p8="$(o39 p39b f39/nada nenhuma)"; r_p8_f="$(tem39 'Esta pasta não está liberada a este usuário.')"
r_so="$(va39 '/usuarios/editar?usuario=p39s')"; r_so_f="$(tem39 'Não se aplica ao perfil Só envio')"; r_so_form="$(tem39 'action="/usuarios/outras"')"
r_meio="$(lista39)"
# p39b tem duas (f39/comum e f39/a/dentro): mais dezoito chegam ao teto de vinte.
r_feitas=0; for n in $(seq -w 1 18); do [[ "$(o39 p39b "f39/t/n$n" leitura)" == '303 '* ]] && r_feitas=$((r_feitas + 1)); done
r_cheia="$(de39 p39b | tr ' ' '\n' | grep -c '=')"
r_21="$(o39 p39b f39/t/n19 leitura)"; r_21_f="$(tem39 'Limite atingido: o usuário já tem 20 outras pastas.')"; r_21_t="$(t39 p39b f39/t/n20 leitura)"
r_troca="$(o39 p39b f39/t/n01 completo)"
r_tiradas=0; for n in $(seq -w 1 18); do [[ "$(o39 p39b "f39/t/n$n" nenhuma)" == '303 '* ]] && r_tiradas=$((r_tiradas + 1)); done
r_pastas="$(docker exec "$FTP" sh -c "ls $P39/t | wc -l")"; r_depois="$(lista39)"
igual39 "$r_t1" '1 Permissao invalida: use leitura, envio, completo ou nenhuma'; [[ "$r_t2" == '1 Pasta invalida:'* ]] || F39=1
igual39 "$r_t3" '1 Pasta recusada: /data/f39/b ja e a pasta do usuario p39b'; igual39 "$r_t4" '1 Pasta recusada: usuario de perfil soenvio nao recebe outras pastas'
igual39 "$r_t5" '1 Usuario nao existe: p39zz'; igual39 "$r_t6" '1 Pasta recusada: /data/f39/comum/atalho e link simbolico'
igual39 "$r_p1" 409; ha39 "$r_p1_f"; igual39 "$r_p2" 400; ha39 "$r_p2_f"; igual39 "$r_p3" 400; ha39 "$r_p3_f"; igual39 "$r_p4" 409; ha39 "$r_p4_f"
igual39 "$r_p5" 400; ha39 "$r_p5_f"; igual39 "$r_p6 $r_p7" '409 404'; igual39 "$r_p8" 409; ha39 "$r_p8_f"; igual39 "$r_so" 200; ha39 "$r_so_f"; igual39 "$r_so_form" 0
igual39 "$r_meio" "$r_antes"; igual39 "$r_feitas $r_cheia" '18 20'; igual39 "$r_21" 409; ha39 "$r_21_f"
igual39 "$r_21_t" '1 Limite atingido: o usuario p39b ja tem 20 outras pastas'; igual39 "$r_troca" '303 /usuarios/editar?usuario=p39b&m=trocada#outras'
igual39 "$r_tiradas $r_pastas" '18 18'; igual39 "$r_depois" "$r_antes"
caso "$F39" seguranca 161 "Liberação fora da regra recusada, e teto de vinte outras pastas por usuário" \
  "terminal: permissão fora da lista: $r_t1; pasta com ..: $r_t2; a pasta do próprio cadastro: $r_t3; conta só envio: $r_t4; usuário que não existe: $r_t5; link simbólico: $r_t6 · painel: mesma permissão de novo $r_p1; permissão fora da lista $r_p2; pasta com .. $r_p3; pasta do próprio cadastro $r_p4; link simbólico $r_p5; conta só envio $r_p6; usuário que não existe $r_p7; retirar a que ele não tem $r_p8; mensagens na tela: $r_p1_f $r_p2_f $r_p3_f $r_p4_f $r_p5_f $r_p8_f · tela da conta só envio: $r_so, 'Não se aplica ao perfil Só envio': $r_so_f, formulário: $r_so_form · lista depois das recusas $([[ "$r_meio" == "$r_antes" ]] && echo igual || echo MUDOU) · teto: $r_feitas liberadas, p39b com $r_cheia; a 21ª pelo painel: $r_21, mensagem: $r_21_f; pelo terminal: $r_21_t; trocar permissão com o teto cheio: $r_troca; retiradas: $r_tiradas, pastas que continuam: $r_pastas · lista no fim $([[ "$r_depois" == "$r_antes" ]] && echo 'igual à do começo' || echo MUDOU): $r_depois"

# ------------------------------------------------------------------ rede: no FTP a conta continua presa à pasta do cadastro
F39=0
n_l="$(ftp_curl tls p39b "$W/p39b.senha" "$F/")"; n_ve="$(grep -c -E 'relatorio|comum|dentro' "$W/curl.out" || true)"
n_pwd="$(ftp_curl tls p39b "$W/p39b.senha" -Q "CWD .." -Q PWD "$F/")"; n_onde="$(resposta 257)"
n_c1="$(ftp_curl tls p39b "$W/p39b.senha" -Q "CWD /data/f39/comum" "$F/")"; n_c1_r="$(resposta 5)"
n_c2="$(ftp_curl tls p39b "$W/p39b.senha" -Q "CWD ../comum" "$F/")"
n_c3="$(ftp_curl tls p39b "$W/p39b.senha" --path-as-is -o "$W/f39.alheio" "$F/../comum/relatorio.cfg")"
n_c4="$(ftp_curl tls p39b "$W/p39b.senha" --path-as-is -o "$W/f39.alheio" "$F/../a/dentro/")"
# p39a tem completo na pasta comum: pelo FTP, envia para a pasta dele e não para a comum.
n_a1="$(ftp_curl tls p39a "$W/p39a.senha" -T "$W/f39-um.cfg" "$F/por-ftp.cfg")"; no_servidor39 $P39/a/por-ftp.cfg "$W/f39-um.cfg"; n_a1_ok=$?
n_a2="$(ftp_curl tls p39a "$W/p39a.senha" --path-as-is -T "$W/f39-um.cfg" "$F/../comum/por-ftp.cfg")"
n_a3="$(ftp_curl tls p39a "$W/p39a.senha" -Q "CWD /data/f39/comum" "$F/")"
n_nao="$(docker exec "$FTP" sh -c "find $P39/comum $P39/a/comum -name por-ftp.cfg 2> /dev/null | wc -l")"
n_web="$(v39 b "/pastas/$C39")"
igual39 "$n_l $n_ve" '0 0'; igual39 "$n_pwd" 0; [[ "$n_onde" == *'"/"'* ]] || F39=1
[[ "$n_c1" != 0 && "$n_c2" != 0 && "$n_c3" != 0 && "$n_c4" != 0 && ! -s "$W/f39.alheio" ]] || F39=1
igual39 "$n_a1 $n_a1_ok" '0 0'; [[ "$n_a2" != 0 && "$n_a3" != 0 ]] || F39=1; igual39 "$n_nao" 0; igual39 "$n_web" 200
caso "$F39" rede 18 "FTP continua preso à pasta do cadastro, com outras pastas liberadas no painel" \
  "p39b (leitura em f39/comum e em f39/a/dentro no painel) por FTP com TLS: lista a própria pasta: saída $n_l, nomes das outras pastas à vista: $n_ve; depois de CWD ..: $n_onde · CWD /data/f39/comum: curl saída $n_c1 ($n_c1_r) · CWD ../comum: saída $n_c2 · baixar ../comum/relatorio.cfg: saída $n_c3 · listar ../a/dentro/: saída $n_c4 · arquivo recebido: $([[ -s "$W/f39.alheio" ]] && echo SIM || echo não) · p39a (completo em f39/comum no painel): envia para a própria pasta: saída $n_a1, igual no servidor: $([[ $n_a1_ok == 0 ]] && echo sim || echo NÃO); envia para ../comum: saída $n_a2; CWD /data/f39/comum: saída $n_a3; arquivo na pasta comum: $n_nao · a mesma pasta pelo painel, para p39b: $n_web"

# ------------------------------------------------------------------ rede: corpo grande só na rota de envio da pasta liberada
F39=0
g_envia="$(m39 a "$C39" sub "$W/f39-grande.bin")"; no_servidor39 $P39/comum/sub/f39-grande.bin "$W/f39-grande.bin"; g_chegou=$?
g_1="$(grande39 "$W/p39a.jar" "${T39[a]}" "/pastas/$C39/pasta" nome)"; g_2="$(grande39 "$W/p39a.jar" "${T39[a]}" "/pastas/$C39/renomear" nome)"
g_3="$(grande39 "$W/p39a.jar" "${T39[a]}" "/pastas/$C39/apagar" item)"; g_4="$(grande39 "$J" "$K" /usuarios/outras pasta)"
g_nomes="$(nomes39 $P39/comum/sub)"
igual39 "$g_envia" "303 /pastas/$C39?pasta=sub&m=enviado"; igual39 "$g_chegou" 0; igual39 "$g_1 $g_2 $g_3 $g_4" '413 413 413 413'
igual39 "$g_nomes" './dois.cfg ./f39-grande.bin '
caso "$F39" rede 19 "Corpo grande só passa na rota de envio da pasta liberada" \
  "arquivo de 3000000 bytes em /pastas/<identificador>/enviar: $g_envia, igual no servidor: $([[ $g_chegou == 0 ]] && echo sim || echo NÃO) · formulário com 3 MB em um campo: /pastas/<identificador>/pasta $g_1, /renomear $g_2, /apagar $g_3; /usuarios/outras (administrador) $g_4 · subpasta depois: $g_nomes"

# ------------------------------------------------------------------ as outras pastas acompanham o cadastro
F39=0
# A pasta liberada a alguém não troca de nome nem é apagada, por quem for: a liberação ficaria apontando para o que não existe.
k_1="$(p39 a /meus-arquivos/renomear --data-urlencode 'item=dentro' --data-urlencode 'nome=outra' --data-urlencode "senha_atual@$W/p39a.senha")"; k_1_n="$(tem39 p39b)"
k_2="$(p39 a /meus-arquivos/apagar --data-urlencode 'item=dentro' --data-urlencode 'confirmar=sim' --data-urlencode "senha_atual@$W/p39a.senha")"; k_2_n="$(tem39 p39b)"
k_3="$(a39 /arquivos/renomear --data-urlencode 'item=f39/comum' --data-urlencode 'nome=comum2' --data-urlencode "senha_atual@$W/painel.senha")"
k_4="$(a39 /arquivos/apagar --data-urlencode 'item=f39' --data-urlencode 'confirmar=sim' --data-urlencode "senha_atual@$W/painel.senha")"
docker exec "$FTP" test -d $P39/comum -a -d $P39/a/dentro; k_ficam=$?
# O que o administrador vê: quem mais alcança cada pasta, e a remoção do usuário que não leva a pasta alcançada por outro.
k_arq="$(va39 '/arquivos?pasta=f39/comum')"; k_arq_f="$(tem39 'Pasta liberada no painel a: <strong>p39a, p39b</strong>')"; k_arq2="$(va39 '/arquivos?pasta=f39/b')"; k_arq2_f="$(tem39 'Pasta liberada no painel a')"
k_ed="$(va39 '/usuarios/editar?usuario=p39a')"; k_ed_f="$(tem39 'inteira ou em parte, a: <strong>p39b</strong>')"
k_rem="$(va39 '/usuarios/remover?usuario=p39a')"; k_rem_f="$(tem39 'também é alcançada por: <strong>p39b</strong>')"; k_rem_c="$(tem39 'name="apagar_pasta"')"
k_5="$(a39 /usuarios/remover --data-urlencode 'usuario=p39a' --data-urlencode 'confirmar=sim' --data-urlencode 'apagar_pasta=sim' --data-urlencode "senha_atual@$W/painel.senha")"
k_vive="$(usuarios_ftp | tr ' ' '\n' | grep -c '^p39a$')"; no_servidor39 $P39/a/segredo-de-a.cfg "$W/f39.seg"; k_seg=$?
# Uma conta a mais: a troca da pasta do cadastro, a troca para só envio e a remoção levam as outras pastas dela.
mu add p39c "$W/p39c.senha" f39/c; k_add=$?; k_t1="$(t39 p39c f39/y leitura)"; k_t2="$(t39 p39c f39/x envio)"; k_c0="$(de39 p39c)"
mu pasta p39c "" f39/y; k_pasta=$?; k_c1="$(de39 p39c)"
mu perfil p39c "" soenvio; k_perfil=$?; k_c2="$(de39 p39c)"
mu perfil p39c "" completo; k_t3="$(t39 p39c f39/x leitura)"; k_c3="$(de39 p39c)"
mu del p39c; k_del=$?; k_c4="$(de39 p39c)"; docker exec "$FTP" test -d $P39/x; k_x=$?
mu del p39b; k_fim="$?"; mu del p39a; k_fim+=" $?"; mu del p39s; k_fim+=" $?"; k_lista="$(lista39)"; k_restam="$(usuarios_ftp | tr ' ' '\n' | grep -c '^p39')"
igual39 "$k_1 $k_1_n" '409 0'; igual39 "$k_2 $k_2_n" '409 0'; igual39 "$k_3 $k_4" '409 409'; igual39 "$k_ficam" 0
igual39 "$k_arq" 200; ha39 "$k_arq_f"; igual39 "$k_arq2 $k_arq2_f" '200 0'; igual39 "$k_ed" 200; ha39 "$k_ed_f"; igual39 "$k_rem" 200; ha39 "$k_rem_f"; igual39 "$k_rem_c" 0
igual39 "$k_5" 409; igual39 "$k_vive $k_seg" '1 0'; igual39 "$k_add ${k_t1%% *} ${k_t2%% *}" '0 0 0'; igual39 "$k_c0" 'p39c f39/x=envio f39/y=leitura'
igual39 "$k_pasta" 0; igual39 "$k_c1" 'p39c f39/x=envio'; igual39 "$k_perfil" 0; igual39 "$k_c2" ''; igual39 "${k_t3%% *}" 0; igual39 "$k_c3" 'p39c f39/x=leitura'
igual39 "$k_del" 0; igual39 "$k_c4" ''; igual39 "$k_x" 0; igual39 "$k_fim" '0 0 0'; igual39 "$k_lista" ''; igual39 "$k_restam" 0
caso "$F39" testes 111 "Outras pastas acompanham o cadastro, e a pasta liberada não é renomeada nem apagada" \
  "pasta f39/a/dentro, liberada a p39b: o dono (p39a) renomeia $k_1 e apaga $k_2, nome de p39b na tela: $k_1_n e $k_2_n · administrador renomeia f39/comum: $k_3; apaga f39, que contém pastas liberadas: $k_4 · as pastas continuam: $([[ $k_ficam == 0 ]] && echo sim || echo NÃO) · aba Arquivos em f39/comum: $k_arq, 'Pasta liberada no painel a: p39a, p39b': $k_arq_f; em f39/b: $k_arq2_f · cartão Pasta de p39a diz que p39b a alcança: $k_ed_f · remover p39a: a tela avisa: $k_rem_f, oferece apagar a pasta: $k_rem_c; pedido com apagar_pasta=sim: $k_5; p39a continua: $k_vive, arquivo dele intacto: $([[ $k_seg == 0 ]] && echo sim || echo NÃO) · p39c com duas pastas: '$k_c0'; pasta do cadastro trocada para f39/y: saída $k_pasta, fica '$k_c1'; perfil trocado para soenvio: saída $k_perfil, fica '$k_c2'; de volta a completo com f39/x: '$k_c3'; removido: saída $k_del, fica '$k_c4', a pasta f39/x continua: $([[ $k_x == 0 ]] && echo sim || echo NÃO) · no fim, p39b, p39a e p39s removidos: $k_fim, lista: '$k_lista', usuários da etapa no cadastro: $k_restam"

docker exec "$FTP" rm -rf $P39
rm -f "$W"/f39* "$W"/p39?.jar
