#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa N: usuário do FTP no painel. Entrada com o nome e a senha do FTP, tela Meus arquivos, download,
# sessão que acompanha o cadastro, a chave PAINEL_ACESSO_USUARIOS_FTP, os modos de TLS, telas de
# administração fora do alcance, usuário preso à própria pasta, entrada que não abre brecha e limites.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel zera a contagem de falhas de entrada e das recusas e encerra as sessões.
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"

M="$B/meus-arquivos"; U="$W/u14.jar"
entra() { COMO="$1" entrar "$2" "$3"; }                                      # <usuário> <pote> <arquivo da senha> → código HTTP
destino() { grep -i '^location:' "$W/entrada.cab" | tr -d '\r' | cut -d ' ' -f 2; }  # para onde a última entrada mandou
token_de() { c -b "$1" "$M" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1; }  # <pote>: token dos formulários do usuário
soma14() { sha256sum < "$1" 2>/dev/null | cut -c1-64; }
arvore14() { docker exec "$FTP" sh -c 'find /data /auth -xdev | sort | sha256sum | cut -c1-16'; }
tempo() { date +%s.%N; }
duracao() { awk -v a="$1" -v b="$(tempo)" 'BEGIN { printf "%.1f", b - a }'; }  # <início>: segundos até agora
sem_token() { sed 's/name="token" value="[^"]*"/name="token"/' "$1" | sha256sum | cut -c1-16; }  # tela de entrada sem o token, que muda a cada pedido

for n in a b c d t; do nova_senha "$W/u14$n.senha"; done
printf 'marcador-do-vizinho-%s\n' "$(openssl rand -hex 8)" > "$W/vizinho.cfg"; MARCA="$(cat "$W/vizinho.cfg")"
mu add equip14 "$W/u14a.senha" clientes14/olt-a; r_ma=$?
mu add vizinho14 "$W/u14b.senha" clientes14/olt-b; r_mb=$?
r_f1="$(ftp_curl tls equip14 "$W/u14a.senha" --ftp-create-dirs -T "$W/envio.bin" "$F/diario/backup.cfg")"
r_f2="$(ftp_curl tls vizinho14 "$W/u14b.senha" -T "$W/vizinho.cfg" "$F/vizinho.cfg")"

# ------------------------------------------------------------------ entrada, tela Meus arquivos e download
auditoria; n_antes="$(eventos 'arquivo_baixado usuario=equip14 ')"
t0="$(tempo)"; e_usu="$(entra equip14 "$U" "$W/u14a.senha")"; t_usu="$(duracao "$t0")"; d_usu="$(destino)"; proibir "$(biscoito_de "$U")"
raiz="$(aba -b "$U" "$B/")"
tela="$(aba -b "$U" "$M")"; UK="$(sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' "$W/corpo" | head -1)"; proibir "$UK"
menu="$(grep -o '<nav.*</nav>' "$W/corpo" | grep -o '<a href="[^"]*"' | cut -d ' ' -f 2 | tr '\n' ' ')"  # só os links: o ícone também tem href
quem_e="$(grep -c 'class="quem">equip14<span>Usuário do FTP<' "$W/corpo")"
adm_na_tela="$(grep -o -E 'href="/(usuarios|arquivos|administradores|atividade|seguranca)|action="/arquivos/pasta"' "$W/corpo" | wc -l)"
caminho_real="$(grep -c -E "clientes14|olt-a|/data|$T" "$W/corpo")"; pasta_diario="$(grep -c 'href="/meus-arquivos?pasta=diario"' "$W/corpo")"
sub="$(aba -b "$U" "$M?pasta=diario")"; link="$(grep -c 'href="/meus-arquivos/baixar?arquivo=diario/backup.cfg"' "$W/corpo")"; trilha="$(grep -c '<a href="/meus-arquivos">Início</a> / <strong>diario</strong>' "$W/corpo")"
r_b="$(c -b "$U" -D "$W/u14.cab" -o "$W/u14.baixado" -w '%{http_code}' "$M/baixar?arquivo=diario/backup.cfg")"
anexo="$(grep -i '^content-disposition:' "$W/u14.cab" | tr -d '\r' | cut -d ' ' -f 2-)"
auditoria; n_depois="$(eventos 'arquivo_baixado usuario=equip14 ')"
r_entrada="$(grep -c ' evento=entrada_ok usuario=equip14$' "$W/auditoria")"
r_baixado="$(grep -c ' evento=arquivo_baixado usuario=equip14 arquivo=clientes14/olt-a/diario/backup.cfg bytes=65536$' "$W/auditoria")"
r_sair="$(POTE="$U" envio /sair --data-urlencode "csrf=$UK")"; depois_de_sair="$(aba -b "$U" "$M")"
auditoria; r_saida="$(grep -c ' evento=saida usuario=equip14$' "$W/auditoria")"
linha_seg="$(aba -b "$J" "$B/seguranca")"; na_seguranca="$(grep -c 'Entrada dos usuários do FTP' "$W/corpo")"; ligada="$(grep -c 'PAINEL_ACESSO_USUARIOS_FTP=sim' "$W/corpo")"
entrada_tela="$(c "$B/entrar" | grep -c 'Usuários do FTP entram com o nome e a senha do FTP')"
[[ "$e_adm" == 303 && "$r_ma" == 0 && "$r_mb" == 0 && "$r_f1" == 0 && "$r_f2" == 0 && "$e_usu" == 303 && "$d_usu" == /meus-arquivos && "$raiz" == "303 /meus-arquivos" && "$tela" == "200 " \
  && "$menu" == 'href="/meus-arquivos" ' && "$quem_e" == 1 && "$adm_na_tela" == 0 && "$caminho_real" == 0 && "$pasta_diario" == 1 && "$sub" == "200 " && "$link" == 1 && "$trilha" == 1 \
  && "$r_b" == 200 && "$(soma14 "$W/u14.baixado")" == "$(soma14 "$W/envio.bin")" && "$anexo" == 'attachment; filename="backup.cfg"'* && "$n_depois" == $((n_antes + 1)) && "$r_entrada" -ge 1 && "$r_baixado" -ge 1 \
  && "$r_sair" == "303 /entrar" && "$depois_de_sair" == "303 /entrar" && "$r_saida" -ge 1 && "$linha_seg" == "200 " && "$na_seguranca" == 1 && "$ligada" == 1 && "$entrada_tela" == 1 ]]
caso $? testes 28 "Usuário do FTP entra no painel e baixa os próprios arquivos" "equip14 (pasta clientes14/olt-a) entra com o nome e a senha do FTP: $e_usu em $t_usu s, destino $d_usu · GET /: $raiz · GET /meus-arquivos: $tela· menu: ${menu:-vazio}· nome no topo como usuário do FTP: $quem_e · links ou formulários de administração na tela: $adm_na_tela · caminho do servidor na tela: $caminho_real · subpasta diario: $sub, caminho com link para o início: $trilha, link de download: $link · download: $r_b, sha256 $([[ "$(soma14 "$W/u14.baixado")" == "$(soma14 "$W/envio.bin")" ]] && echo idêntico || echo DIFERENTE), Content-Disposition: $anexo · auditoria: entrada_ok usuario=equip14: $r_entrada, arquivo_baixado com usuário, caminho real e bytes: $r_baixado, saida usuario=equip14: $r_saida · POST /sair: $r_sair; depois, GET /meus-arquivos: $depois_de_sair · a tela de entrada explica os dois tipos de conta: $entrada_tela · aba Segurança mostra a entrada dos usuários ligada: $ligada"

# ------------------------------------------------------------------ a sessão acompanha o cadastro; a chave que desliga
auditoria; n_antes="$(eventos sessao_encerrada)"
e_1="$(entra equip14 "$U" "$W/u14a.senha")"; proibir "$(biscoito_de "$U")"; antes_troca="$(aba -b "$U" "$M")"
mu passwd equip14 "$W/u14c.senha"; r_troca=$?
depois_troca="$(aba -b "$U" -D "$W/u14.cab" "$M")"; apagado="$(grep -i -c '^set-cookie: __Host-sessao=; .*Max-Age=0' "$W/u14.cab")"
e_antiga="$(entra equip14 "$W/x14.jar" "$W/u14a.senha")"; e_nova="$(entra equip14 "$U" "$W/u14c.senha")"; proibir "$(biscoito_de "$U")"
mu add temp14 "$W/u14t.senha" clientes14/olt-a; e_t="$(entra temp14 "$W/t14.jar" "$W/u14t.senha")"; proibir "$(biscoito_de "$W/t14.jar")"; antes_del="$(aba -b "$W/t14.jar" "$M")"
mu del temp14; depois_del="$(aba -b "$W/t14.jar" "$M")"; outro_segue="$(aba -b "$U" "$M")"
auditoria; n_depois="$(eventos sessao_encerrada)"; motivo="$(grep -c ' evento=sessao_encerrada usuario=\(equip14\|temp14\) motivo=cadastro_alterado$' "$W/auditoria")"
gravar_env "$ENVA" PAINEL_ACESSO_USUARIOS_FTP nao; dep; r_nao=$?; painel_de_pe
e_fechado="$(entra equip14 "$W/x14.jar" "$W/u14c.senha")"; tela_fechada="$(grep -c 'Painel de administração da stack' "$W/entrada.corpo")"; fala_de_ftp="$(grep -c 'Usuários do FTP' "$W/entrada.corpo")"
e_adm_fechado="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; seg_fechada="$(aba -b "$J" "$B/seguranca")"; desligada="$(grep -c 'PAINEL_ACESSO_USUARIOS_FTP=nao' "$W/corpo")"
ftp_segue="$(ftp_curl tls equip14 "$W/u14c.senha" -o "$W/u14.ftp" "$F/diario/backup.cfg")"
gravar_env "$ENVA" PAINEL_ACESSO_USUARIOS_FTP sim; dep; r_sim=$?; painel_de_pe
e_reaberto="$(entra equip14 "$U" "$W/u14c.senha")"; proibir "$(biscoito_de "$U")"
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
r_invalido="$(recusa_deploy PAINEL_ACESSO_USUARIOS_FTP=talvez)"; r_cont="$(recusa_container painel PAINEL_ACESSO_USUARIOS_FTP=talvez)"
[[ "$e_1" == 303 && "$antes_troca" == "200 " && "$r_troca" == 0 && "$depois_troca" == "303 /entrar" && "$apagado" == 1 && "$e_antiga" == 401 && "$e_nova" == 303 \
  && "$e_t" == 303 && "$antes_del" == "200 " && "$depois_del" == "303 /entrar" && "$outro_segue" == "200 " && "$n_depois" == $((n_antes + 2)) && "$motivo" -ge 2 \
  && "$r_nao" == 0 && "$e_fechado" == 401 && "$tela_fechada" == 1 && "$fala_de_ftp" == 0 && "$e_adm_fechado" == 303 && "$seg_fechada" == "200 " && "$desligada" == 1 && "$ftp_segue" == 0 \
  && "$r_sim" == 0 && "$e_reaberto" == 303 && "$e_adm" == 303 ]] && recusou "$r_invalido" "PAINEL_ACESSO_USUARIOS_FTP deve ser 'sim' ou 'nao'" && recusou "$r_cont" "PAINEL_ACESSO_USUARIOS_FTP deve ser 'sim' ou 'nao'"
caso $? testes 29 "Sessão do usuário acompanha o cadastro e a chave que desliga a entrada" "sessão de equip14 antes de a senha do FTP ser trocada pelo terminal: $antes_troca· depois: $depois_troca, cookie apagado na resposta: $apagado; entrada com a senha antiga: $e_antiga, com a nova: $e_nova · sessão de temp14 antes de ele ser removido: $antes_del· depois: $depois_del; a sessão do outro usuário segue: $outro_segue· sessao_encerrada na auditoria: $n_antes → $n_depois, com usuário e motivo: $motivo · PAINEL_ACESSO_USUARIOS_FTP=nao (deploy.sh: saída $r_nao): entrada de equip14 com a senha certa: $e_fechado, tela de entrada volta ao texto de administração: $tela_fechada, entrada do administrador: $e_adm_fechado, aba Segurança mostra desligada: $desligada, o mesmo usuário por FTPS: saída $ftp_segue · de volta a sim (saída $r_sim): entrada de equip14: $e_reaberto · valor inválido no deploy.sh: $r_invalido · no container do painel: $r_cont"

# ------------------------------------------------------------------ entrada do usuário em cada modo de TLS do FTP
# Os modos 0 e 1 só existem com REDE_PERMITIR_IP_PUBLICO=nao (o deploy.sh recusa os dois com a opção ligada, caso 43).
# A etapa 10 deixa a opção ligada e uma rede pública liberada no painel: este caso desliga as duas e devolve ao final.
opcao_antes="$(env_file="$ENVA" env_valor REDE_PERMITIR_IP_PUBLICO nao)"; redes_antes="$(env_file="$ENVA" env_valor PAINEL_REDES_PERMITIDAS)"
gravar_env "$ENVA" REDE_PERMITIR_IP_PUBLICO nao
gravar_env "$ENVA" PAINEL_REDES_PERMITIDAS "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"
ev="com REDE_PERMITIR_IP_PUBLICO=nao · "; ok=0
for modo in 0 1 3; do
  gravar_env "$ENVA" FTP_TLS_MODE "$modo"; dep; r=$?; painel_de_pe
  e_m="$(entra equip14 "$W/m14.jar" "$W/u14c.senha")"; proibir "$(biscoito_de "$W/m14.jar")"; lista_m="$(aba -b "$W/m14.jar" "$M?pasta=diario")"
  e_r="$(entra equip14 "$W/x14.jar" "$W/errada.senha")"
  e_a="$(entrar "$W/a14.jar" "$W/painel.senha")"; proibir "$(biscoito_de "$W/a14.jar")"; aba -b "$W/a14.jar" "$B/seguranca" > /dev/null
  puro="$(grep -c 'Entrada dos usuários do FTP.*<strong>em texto puro</strong>' "$W/corpo")"; conferido="$(grep -c 'Entrada dos usuários do FTP.*em TLS e com o certificado dele conferido' "$W/corpo")"
  if [[ "$modo" == 0 ]]; then esperado="1 0"; else esperado="0 1"; fi
  [[ "$r" == 0 && "$e_m" == 303 && "$lista_m" == "200 " && "$e_r" == 401 && "$e_a" == 303 && "$puro $conferido" == "$esperado" ]] || ok=1
  ev+="modo $modo (deploy.sh: saída $r): senha certa $e_m, pasta $lista_m, senha errada $e_r, aba Segurança diz $([[ "$puro" == 1 ]] && echo 'texto puro na rede interna' || echo 'TLS com certificado conferido') · "
done
gravar_env "$ENVA" FTP_TLS_MODE 2; gravar_env "$ENVA" REDE_PERMITIR_IP_PUBLICO "$opcao_antes"
[[ -n "$redes_antes" ]] && gravar_env "$ENVA" PAINEL_REDES_PERMITIDAS "$redes_antes"
dep; r=$?; painel_de_pe
e_m="$(entra equip14 "$U" "$W/u14c.senha")"; proibir "$(biscoito_de "$U")"
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
[[ "$ok" == 0 && "$r" == 0 && "$e_m" == 303 && "$e_adm" == 303 ]]
caso $? testes 30 "Entrada do usuário do FTP em cada modo de TLS" "${ev}de volta ao modo 2 e a REDE_PERMITIR_IP_PUBLICO=$opcao_antes (saída $r): senha certa $e_m"

# ------------------------------------------------------------------ telas de administração fora do alcance
UK="$(token_de "$U")"; proibir "$UK"
auditoria; n_antes="$(eventos recusa_papel)"; u_antes="$(usuarios_ftp)"; a_antes="$(admins)"; arv_antes="$(arvore14)"
: > "$W/u14.respostas"; gets=0; gets_404=0
for caminho in /usuarios /usuarios/novo "/usuarios/senha?usuario=vizinho14" "/usuarios/remover?usuario=vizinho14" /arquivos "/arquivos?pasta=clientes14/olt-b" \
  "/arquivos/baixar?arquivo=clientes14/olt-b/vizinho.cfg" /administradores /administradores/novo "/administradores/senha?admin=$ADMIN" "/administradores/nome?admin=$ADMIN" \
  "/administradores/remover?admin=$ADMIN" /seguranca /atividade; do
  r="$(aba -b "$U" "$B$caminho")"; cat "$W/corpo" >> "$W/u14.respostas"; gets=$((gets + 1)); [[ "$r" == "404 " ]] && gets_404=$((gets_404 + 1))
done
p_1="$(POTE="$U" envio /usuarios/novo --data-urlencode "csrf=$UK" --data-urlencode 'usuario=intruso14' --data-urlencode "senha@$W/u14d.senha" --data-urlencode "confirmacao@$W/u14d.senha")"
p_2="$(POTE="$U" envio /usuarios/remover --data-urlencode "csrf=$UK" --data-urlencode 'usuario=vizinho14')"
p_3="$(POTE="$U" envio /usuarios/senha --data-urlencode "csrf=$UK" --data-urlencode 'usuario=vizinho14' --data-urlencode "senha@$W/u14d.senha" --data-urlencode "confirmacao@$W/u14d.senha")"
p_4="$(POTE="$U" envio /arquivos/pasta --data-urlencode "csrf=$UK" --data-urlencode 'pasta=' --data-urlencode 'nome=intrusa14')"
p_5="$(POTE="$U" envio /administradores/novo --data-urlencode "csrf=$UK" --data-urlencode 'nome=intruso14' --data-urlencode "senha@$W/u14d.senha" --data-urlencode "confirmacao@$W/u14d.senha" --data-urlencode "senha_atual@$W/u14c.senha")"
p_6="$(POTE="$U" envio /administradores/remover --data-urlencode "csrf=$UK" --data-urlencode "admin=$ADMIN" --data-urlencode "senha_atual@$W/u14c.senha")"
p_sem="$(POTE="$U" envio /usuarios/remover --data-urlencode 'usuario=vizinho14')"
vazou14="$(grep -c -a -F "$MARCA" "$W/u14.respostas")"; nomes="$(grep -c -a 'vizinho14' "$W/u14.respostas")"
auditoria; n_depois="$(eventos recusa_papel)"; registro="$(grep -c ' evento=recusa_papel usuario=equip14 caminho=/' "$W/auditoria")"
adm_1="$(aba -b "$J" "$M")"; adm_2="$(aba -b "$J" "$M/baixar?arquivo=diario/backup.cfg")"; sem_sessao="$(aba "$M")"; sem_sessao_b="$(aba "$M/baixar?arquivo=diario/backup.cfg")"
segue="$(aba -b "$U" "$M")"
[[ "$gets" == 14 && "$gets_404" == 14 && "$p_1" == "404 " && "$p_2" == "404 " && "$p_3" == "404 " && "$p_4" == "404 " && "$p_5" == "404 " && "$p_6" == "404 " && "$p_sem" == "403 " \
  && "$u_antes" == "$(usuarios_ftp)" && "$a_antes" == "$(admins)" && "$arv_antes" == "$(arvore14)" && "$vazou14" == 0 && "$nomes" == 0 && "$n_depois" -gt "$n_antes" && "$registro" -ge 1 \
  && "$adm_1" == "404 " && "$adm_2" == "404 " && "$sem_sessao" == "303 /entrar" && "$sem_sessao_b" == "303 /entrar" && "$segue" == "200 " ]]
caso $? seguranca 60 "Usuário do FTP não alcança a administração" "com a sessão de equip14, $gets telas de administração pedidas (usuários, arquivos de todos, administradores, segurança, atividade): $gets_404 com 404 · com o token da sessão dele, POST para criar usuário: $p_1· remover usuário: $p_2· trocar senha de outro: $p_3· criar pasta: $p_4· criar administrador: $p_5· remover administrador: $p_6· sem token: $p_sem· usuários do FTP, administradores e árvore de dados e cadastro: $([[ "$u_antes" == "$(usuarios_ftp)" && "$a_antes" == "$(admins)" && "$arv_antes" == "$(arvore14)" ]] && echo 'os mesmos antes e depois' || echo MUDARAM) · conteúdo do arquivo do vizinho nas respostas: $vazou14; nome de outro usuário: $nomes · recusa_papel na auditoria: $n_antes → $n_depois (uma linha por minuto e por endereço), com usuário e caminho: $registro · a sessão dele segue valendo na tela dele: $segue· administrador em /meus-arquivos: ${adm_1}e no download: $adm_2· sem sessão: $sem_sessao e $sem_sessao_b"

# ------------------------------------------------------------------ preso à própria pasta
docker exec "$FTP" sh -c 'cd /data/clientes14/olt-a && ln -s ../olt-b atalho-pasta && ln -s ../olt-b/vizinho.cfg atalho-arquivo && ln -s /auth/pureftpd.passwd atalho-cadastro'
auditoria; n_antes="$(eventos recusa_caminho)"
: > "$W/u14.respostas"; ev=""; ok=0; pedidos=0
for alvo in 'pasta=..' 'pasta=../olt-b' 'pasta=/data/clientes14/olt-b' 'pasta=diario/../../olt-b' 'pasta=%2e%2e/olt-b' 'pasta=..%2Folt-b' 'pasta=atalho-pasta' 'pasta=clientes14/olt-b' 'pasta=.' 'pasta=diario%00/../../olt-b'; do
  r="$(aba --path-as-is -b "$U" "$M?$alvo")"; cat "$W/corpo" >> "$W/u14.respostas"; pedidos=$((pedidos + 1))
  [[ "$r" == "400 " || "$r" == "403 " || "$r" == "404 " ]] || ok=1; ev+="$alvo ${r% }; "
done
for alvo in 'arquivo=../olt-b/vizinho.cfg' 'arquivo=/data/clientes14/olt-b/vizinho.cfg' 'arquivo=diario/../../olt-b/vizinho.cfg' 'arquivo=..%2Folt-b%2Fvizinho.cfg' 'arquivo=atalho-arquivo' 'arquivo=atalho-pasta/vizinho.cfg' \
  'arquivo=atalho-cadastro' 'arquivo=/auth/pureftpd.passwd' 'arquivo=..%2F..%2F..%2Fauth%2Fpureftpd.passwd' 'arquivo=/etc/passwd' 'arquivo=clientes14/olt-b/vizinho.cfg' 'arquivo=diario'; do
  r="$(aba --path-as-is -b "$U" "$M/baixar?$alvo")"; cat "$W/corpo" >> "$W/u14.respostas"; pedidos=$((pedidos + 1))
  [[ "$r" == "400 " || "$r" == "403 " || "$r" == "404 " ]] || ok=1; ev+="$alvo ${r% }; "
done
vazou14="$(grep -c -a -F "$MARCA" "$W/u14.respostas")"; hashes="$(grep -c -a -E 'root:|\$argon2|scrypt\$|vizinho14' "$W/u14.respostas")"
lista="$(aba -b "$U" "$M")"; links="$(grep -o 'class="etiqueta">link simbólico<' "$W/corpo" | wc -l)"; sem_baixar="$(grep -o 'href="/meus-arquivos/baixar?arquivo=atalho' "$W/corpo" | wc -l)"
proprio="$(c -b "$U" -o "$W/u14.baixado" -w '%{http_code}' "$M/baixar?arquivo=diario/backup.cfg")"
auditoria; n_depois="$(eventos recusa_caminho)"; registro="$(grep -c ' evento=recusa_caminho usuario=equip14 caminho=' "$W/auditoria")"
docker exec "$FTP" rm -f /data/clientes14/olt-a/atalho-pasta /data/clientes14/olt-a/atalho-arquivo /data/clientes14/olt-a/atalho-cadastro
[[ "$ok" == 0 && "$pedidos" == 22 && "$vazou14" == 0 && "$hashes" == 0 && "$lista" == "200 " && "$links" == 3 && "$sem_baixar" == 0 && "$proprio" == 200 && "$n_depois" -gt "$n_antes" && "$registro" -ge 1 ]] \
  && cmp -s "$W/envio.bin" "$W/u14.baixado"
caso $? seguranca 61 "Usuário do FTP preso à própria pasta no painel" "equip14 (pasta clientes14/olt-a) pede a pasta e o arquivo do vizinho (clientes14/olt-b), o cadastro do FTP e /etc/passwd por .., caminho absoluto, caminho codificado e link simbólico: $pedidos pedidos, todos recusados · $ev conteúdo do arquivo do vizinho nas respostas: $vazou14 · linha de cadastro, hash ou nome de outro usuário: $hashes · os 3 links simbólicos aparecem na lista como link: $links, com botão de download: $sem_baixar · o arquivo dele segue baixando: $proprio, $(cmp -s "$W/envio.bin" "$W/u14.baixado" && echo idêntico || echo DIFERENTE) · recusa_caminho na auditoria: $n_antes → $n_depois, com usuário: $registro"

# ------------------------------------------------------------------ a entrada não abre brecha
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
e_u="$(entra equip14 "$U" "$W/u14c.senha")"; proibir "$(biscoito_de "$U")"
auditoria; f_antes="$(eventos entrada_falha)"
t0="$(tempo)"; e_errada="$(entra equip14 "$W/x14.jar" "$W/errada.senha")"; t_errada="$(duracao "$t0")"; tela_errada="$(sem_token "$W/entrada.corpo")"
t0="$(tempo)"; e_ninguem="$(entra ninguem14 "$W/x14.jar" "$W/errada.senha")"; t_ninguem="$(duracao "$t0")"; tela_ninguem="$(sem_token "$W/entrada.corpo")"
t0="$(tempo)"; e_admin="$(entrar "$W/x14.jar" "$W/errada.senha")"; t_admin="$(duracao "$t0")"; tela_admin="$(sem_token "$W/entrada.corpo")"
# Usuário do FTP com o mesmo nome do administrador: a senha do FTP não abre o painel; a do administrador abre a administração.
mu add "$ADMIN" "$W/u14d.senha" clientes14/olt-b; r_homonimo=$?
e_homonimo="$(entrar "$W/x14.jar" "$W/u14d.senha")"; e_dono="$(entrar "$W/a14.jar" "$W/painel.senha")"; d_dono="$(destino)"; proibir "$(biscoito_de "$W/a14.jar")"
ftp_homonimo="$(ftp_curl tls "$ADMIN" "$W/u14d.senha" -o "$W/u14.ftp" "$F/vizinho.cfg")"; mu del "$ADMIN"
auditoria; f_depois="$(eventos entrada_falha)"; p_antes="$(grep -c ' evento=sessao_encerrada usuario=equip14 motivo=nome_de_administrador$' "$W/auditoria")"
# Administrador criado com o nome de um usuário do FTP que está com sessão aberta: a sessão do usuário acaba.
antes_adm="$(aba -b "$U" "$M")"
r_novo="$(envio /administradores/novo --data-urlencode "csrf=$K" --data-urlencode 'nome=equip14' --data-urlencode "senha@$W/u14d.senha" --data-urlencode "confirmacao@$W/u14d.senha" --data-urlencode "senha_atual@$W/painel.senha")"
depois_adm="$(aba -b "$U" "$M")"
r_rem="$(envio /administradores/remover --data-urlencode "csrf=$K" --data-urlencode 'admin=equip14' --data-urlencode "senha_atual@$W/painel.senha")"
auditoria; por_nome="$(grep -c ' evento=sessao_encerrada usuario=equip14 motivo=nome_de_administrador$' "$W/auditoria")"
[[ "$e_adm" == 303 && "$e_u" == 303 && "$e_errada" == 401 && "$e_ninguem" == 401 && "$e_admin" == 401 && "$tela_errada" == "$tela_ninguem" && "$tela_errada" == "$tela_admin" \
  && "$r_homonimo" == 0 && "$e_homonimo" == 401 && "$e_dono" == 303 && "$d_dono" == / && "$ftp_homonimo" == 0 && "$f_depois" == $((f_antes + 4)) \
  && "$antes_adm" == "200 " && "$r_novo" == "303 /administradores?m=criado" && "$depois_adm" == "303 /entrar" && "$r_rem" == "303 /administradores?m=removido" && "$por_nome" == $((p_antes + 1)) ]]
ok_a=$?

# Servidor FTP parado: quem já entrou segue lendo a própria pasta (os arquivos vêm do disco); entrada nova não passa.
dc restart painel > /dev/null 2>&1; painel_de_pe
e_u="$(entra equip14 "$U" "$W/u14c.senha")"; proibir "$(biscoito_de "$U")"
auditoria; i_antes="$(grep -c ' evento=entrada_falha conferencia=ftp_indisponivel$' "$W/auditoria")"
dc stop ftp > /dev/null 2>&1
parado_sessao="$(aba -b "$U" "$M?pasta=diario")"; e_parado="$(entra vizinho14 "$W/x14.jar" "$W/u14b.senha")"; e_adm_parado="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"
dc start ftp > /dev/null 2>&1; esperar "$FTP"; r_volta=$?
volta_sessao="$(aba -b "$U" "$M")"
# Certificado diferente do que o serviço ftp publicou em /auth: a conferência não envia a senha e a entrada não passa.
docker exec "$FTP" sh -c 'cp -p /auth/ftp-cert.pem /auth/ftp-cert.guardado && openssl req -x509 -newkey rsa:2048 -nodes -keyout /dev/null -subj /CN=outro -days 1 -out /auth/ftp-cert.pem 2>/dev/null && chmod 644 /auth/ftp-cert.pem'; r_cert=$?
e_cert="$(entra vizinho14 "$W/x14.jar" "$W/u14b.senha")"
docker exec "$FTP" sh -c 'cat /auth/ftp-cert.guardado > /auth/ftp-cert.pem && rm -f /auth/ftp-cert.guardado'
auditoria; indisponivel="$(grep -c ' evento=entrada_falha conferencia=ftp_indisponivel$' "$W/auditoria")"
# Limite de tentativas: vale para a entrada do usuário do FTP como vale para a do administrador.
e_3="$(entra ninguem14 "$W/x14.jar" "$W/errada.senha")"; e_4="$(entra ninguem14 "$W/x14.jar" "$W/errada.senha")"; e_5="$(entra equip14 "$W/x14.jar" "$W/errada.senha")"
e_6="$(entra vizinho14 "$W/x14.jar" "$W/u14b.senha")"; e_6_adm="$(entrar "$W/x14.jar" "$W/painel.senha")"
auditoria; bloqueios="$(eventos entrada_bloqueada)"; na_auditoria="$(segredos_em "$W/auditoria")"
docker logs "$PAINEL" > "$W/painel.log" 2>&1; docker logs "$FTP" > "$W/ftp.log" 2>&1; nos_logs="$(( $(segredos_em "$W/painel.log") + $(segredos_em "$W/ftp.log") ))"
nomes_errados="$(grep -c -a 'ninguem14' "$W/auditoria")"
[[ "$ok_a" == 0 && "$e_u" == 303 && "$parado_sessao" == "200 " && "$e_parado" == 401 && "$e_adm_parado" == 303 && "$r_volta" == 0 && "$volta_sessao" == "200 " \
  && "$r_cert" == 0 && "$e_cert" == 401 && "$indisponivel" == $((i_antes + 2)) && "$e_3" == 401 && "$e_4" == 401 && "$e_5" == 401 && "$e_6" == 429 && "$e_6_adm" == 429 && "$bloqueios" -ge 2 \
  && "$na_auditoria" == 0 && "$nos_logs" == 0 && "$nomes_errados" == 0 ]]
caso $? seguranca 62 "Entrada do usuário do FTP não abre brecha" "senha errada de equip14: $e_errada em $t_errada s · usuário que não existe: $e_ninguem em $t_ninguem s · nome do administrador com senha errada: $e_admin em $t_admin s · as três telas, sem o token: $([[ "$tela_errada" == "$tela_ninguem" && "$tela_errada" == "$tela_admin" ]] && echo iguais || echo DIFERENTES) · usuário do FTP criado com o nome do administrador '$ADMIN': a senha do FTP no painel dá $e_homonimo e por FTPS, saída $ftp_homonimo; a senha do administrador dá $e_dono, destino $d_dono · entrada_falha na auditoria: $f_antes → $f_depois · administrador criado com o nome equip14 ($r_novo): a sessão do usuário, antes $antes_adm, passa a $depois_adm (sessao_encerrada motivo=nome_de_administrador: $p_antes → $por_nome) · servidor FTP parado: sessão aberta lê a pasta: $parado_sessao, entrada nova com a senha certa: $e_parado, administrador: $e_adm_parado; FTP de volta (espera: $r_volta), a sessão segue: $volta_sessao· certificado em /auth trocado por outro: entrada com a senha certa: $e_cert · entrada_falha conferencia=ftp_indisponivel: $i_antes → $indisponivel · mais três falhas ($e_3, $e_4, $e_5) e a sexta tentativa, com a senha certa: $e_6; a do administrador: $e_6_adm; entrada_bloqueada: $bloqueios · senhas, tokens e cookies na auditoria: $na_auditoria; nos logs do painel e do FTP: $nos_logs · nome digitado em tentativa recusada na auditoria: $nomes_errados"
achado seguranca "A recusa de uma senha pelo painel leva o tempo do servidor FTP: nesta execução, $t_errada s para usuário que existe, $t_ninguem s para nome que não existe e $t_admin s para nome de administrador (entrada aceita: $t_usu s)" "O Pure-FTPd confere o hash argon2id do cadastro (cerca de 3 s) e ainda espera de 3 a 6 s, ao acaso, antes de recusar. O painel repassa esse tempo sem acrescentar pista: nome de administrador demora o mesmo que nome inexistente. Usuário do FTP que existe demora mais para ser recusado, e quem alcança a porta do FTP já mede a mesma diferença lá; pelo painel são no máximo 5 tentativas por endereço a cada 15 minutos."

# ------------------------------------------------------------------ limites do usuário
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
docker exec "$FTP" sh -c 'head -c 41943040 /dev/urandom > /data/clientes14/olt-a/grande.bin && chown ftpdata:ftpdata /data/clientes14/olt-a/grande.bin'
ev=""; ok=0
for n in 1 2 3 4; do r="$(entra equip14 "$W/s14-$n.jar" "$W/u14c.senha")"; proibir "$(biscoito_de "$W/s14-$n.jar")"; [[ "$r" == 303 ]] || ok=1; ev+="$r "; done
s_1="$(aba -b "$W/s14-1.jar" "$M")"; s_2="$(aba -b "$W/s14-2.jar" "$M")"; s_3="$(aba -b "$W/s14-3.jar" "$M")"; s_4="$(aba -b "$W/s14-4.jar" "$M")"
e_v="$(entra vizinho14 "$W/v14.jar" "$W/u14b.senha")"; proibir "$(biscoito_de "$W/v14.jar")"
auditoria; n_antes="$(eventos arquivo_interrompido)"; lentos=()
for n in 2 3; do
  curl -sk --max-time 40 --limit-rate 4k -b "$W/s14-$n.jar" -o /dev/null "$M/baixar?arquivo=grande.bin" & lentos+=("$!")
  sleep 0.1
done
sleep 2
r_3="$(c -b "$W/s14-4.jar" -D "$W/u14.cab" -o "$W/corpo" -w '%{http_code}' "$M/baixar?arquivo=diario/backup.cfg")"; espera="$(grep -i '^retry-after:' "$W/u14.cab" | tr -d '\r' | cut -d ' ' -f 2)"
aviso="$(grep -c 'O limite deste usuário é de 2 arquivo(s) por vez' "$W/corpo")"; tela_segue="$(aba -b "$W/s14-4.jar" "$M")"
r_viz="$(c -b "$W/v14.jar" -o "$W/u14.viz" -w '%{http_code}' "$M/baixar?arquivo=vizinho.cfg")"
r_adm="$(c -b "$J" -o "$W/u14.adm" -w '%{http_code}' "$B/arquivos/baixar?arquivo=clientes14/olt-a/diario/backup.cfg")"
kill "${lentos[@]}" 2>/dev/null; wait "${lentos[@]}" 2>/dev/null
for _ in $(seq 1 20); do  # o painel percebe o fim de cada download quando o nginx fecha a conexão com ele
  auditoria; n_depois="$(eventos arquivo_interrompido)"; [[ "$n_depois" -ge $((n_antes + 2)) ]] && break
  sleep 0.5
done
r_depois="$(c -b "$W/s14-4.jar" -o "$W/u14.baixado" -w '%{http_code}' "$M/baixar?arquivo=diario/backup.cfg")"
docker exec "$FTP" rm -f /data/clientes14/olt-a/grande.bin
[[ "$ok" == 0 && "$e_adm" == 303 && "$s_1" == "303 /entrar" && "$s_2" == "200 " && "$s_3" == "200 " && "$s_4" == "200 " && "$e_v" == 303 && "$r_3" == 503 && "$espera" == 30 && "$aviso" == 1 && "$tela_segue" == "200 " \
  && "$r_viz" == 200 && "$r_adm" == 200 && "$n_depois" -ge $((n_antes + 2)) && "$r_depois" == 200 ]] && cmp -s "$W/vizinho.cfg" "$W/u14.viz" && cmp -s "$W/envio.bin" "$W/u14.adm" && cmp -s "$W/envio.bin" "$W/u14.baixado"
caso $? seguranca 63 "Limites do usuário do FTP no painel" "quatro entradas seguidas de equip14: $ev· a 1ª sessão: $s_1· a 2ª, a 3ª e a 4ª: $s_2$s_3$s_4· dois downloads lentos do arquivo de 40 MiB em andamento pelo mesmo usuário · o 3º download dele: $r_3, Retry-After: ${espera:-ausente}, aviso do limite por usuário: $aviso; a tela dele enquanto isso: $tela_segue· download de outro usuário (vizinho14): $r_viz, $(cmp -s "$W/vizinho.cfg" "$W/u14.viz" && echo idêntico || echo DIFERENTE) · download do administrador: $r_adm, $(cmp -s "$W/envio.bin" "$W/u14.adm" && echo idêntico || echo DIFERENTE) · com os dois encerrados no meio (arquivo_interrompido: $n_antes → $n_depois), novo download dele: $r_depois, $(cmp -s "$W/envio.bin" "$W/u14.baixado" && echo idêntico || echo DIFERENTE)"

mu del equip14; mu del vizinho14
docker exec "$FTP" rm -rf /data/clientes14
rm -f "$W"/u14* "$W"/s14-*.jar "$W"/[axmtv]14.jar "$W/vizinho.cfg" "$W/painel.log" "$W/ftp.log"
