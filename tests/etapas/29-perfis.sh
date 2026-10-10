#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa AC: perfis de usuário. O que cada perfil faz no FTP (Completo, Envio e Leitura na mesma pasta), a entrega
# do arquivo enviado pelo perfil Envio, o modo das pastas acompanhando os perfis, a tela única de Usuários com o
# seletor de perfil, a troca de perfil pelo painel e as recusas.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel zera a contagem de falhas de entrada e encerra as sessões.
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
P29=/data/perfis29/a; Q29=/data/perfis29/b
f29() { ftp_curl tls "p29$1" "$W/p29$1.senha" "${@:2}"; }                                   # <c|e|l|w> <argumentos do curl...>
modo29() { docker exec "$FTP" stat -c '%U:%G %a' "$@" 2>&1 | tr '\n' ' '; }                 # <caminho...>: dono e modo
e29() { [[ "$(docker exec "$FTP" stat -c '%U:%G %a' "$1" 2>/dev/null)" == "$2" ]]; }        # <caminho> <dono e modo esperados>
ate29() { local fim=$((SECONDS + $1)); shift; until "$@"; do (( SECONDS < fim )) || return 1; sleep 0.2; done; }
perfil29() { mu perfil "$1" ""; tail -1 "$W/mu.log" | tr -d '\r\n'; }                       # <usuário>: o perfil no cadastro
arvore29() { docker exec "$FTP" sh -c 'find /data/perfis29 -xdev -printf "%M %u:%g %s %p\n" | sort | sha256sum | cut -c1-16'; }
cadastro29() { docker exec "$FTP" sh -c 'sha256sum < /auth/pureftpd.passwd | cut -c1-16'; }  # o hash não sai inteiro do container
igual29() { docker exec "$FTP" cat "$1" 2>/dev/null | cmp -s - "$2"; }                      # <arquivo no servidor> <arquivo local>

for n in c e l w; do nova_senha "$W/p29$n.senha"; done
printf 'primeiro-%s\n' "$(openssl rand -hex 8)" > "$W/p29.a"; printf 'segundo-%s\n' "$(openssl rand -hex 8)" > "$W/p29.b"

# ------------------------------------------------------------------ três perfis na mesma pasta
mu add p29c "$W/p29c.senha" perfis29/a; r_c=$?; m_completo="$(modo29 /data /data/perfis29 $P29)"
mu add p29e "$W/p29e.senha" perfis29/a envio; r_e=$?; m_envio="$(modo29 $P29)"
mu add p29l "$W/p29l.senha" perfis29/a leitura; r_l=$?; m_leitura="$(modo29 $P29)"
contas29="$(docker exec "$FTP" grep -E '^p29[cel]:' /auth/pureftpd.passwd | cut -d: -f1,3,4 | tr '\n' ' ')"
lidos29="$(perfil29 p29c) $(perfil29 p29e) $(perfil29 p29l)"

# Completo: envia, cria pasta, renomeia, apaga e grava por cima.
c_envia="$(f29 c -T "$W/p29.a" "$F/c1.cfg")"; c_pasta="$(f29 c -Q 'MKD sub' "$F/")"; c_outro="$(f29 c -T "$W/p29.a" "$F/c2.cfg")"
c_ren="$(f29 c -Q 'RNFR c2.cfg' -Q 'RNTO c3.cfg' "$F/")"; c_apaga="$(f29 c -Q 'DELE c3.cfg' "$F/")"; c_regrava="$(f29 c -T "$W/p29.a" "$F/c1.cfg")"
m_sub="$(modo29 $P29/sub)"

# Envio: lista, baixa e envia. O vigia entrega o arquivo ao ftpdata assim que ele termina de chegar.
e_lista="$(f29 e "$F/")"; e_linhas="$(grep -c . "$W/curl.out")"
e_baixa="$(f29 e -o "$W/p29.baixado" "$F/c1.cfg")"; cmp -s "$W/p29.baixado" "$W/p29.a"; e_igual=$?
e_envia="$(f29 e -T "$W/p29.a" "$F/e1.cfg")"; ate29 15 e29 $P29/e1.cfg 'ftpdata:ftpdata 644'; r_entrega=$?; m_e1="$(modo29 $P29/e1.cfg)"
e_apaga="$(f29 e -Q 'DELE e1.cfg' "$F/")"; e_regrava="$(f29 e -T "$W/p29.b" "$F/e1.cfg")"; e_acrescenta="$(f29 e -a -T "$W/p29.b" "$F/e1.cfg")"
e_ren="$(f29 e -Q 'RNFR e1.cfg' -Q 'RNTO e9.cfg' "$F/")"
e_alheio="$(f29 e -Q 'DELE c1.cfg' "$F/")"; e_alheio_ren="$(f29 e -Q 'RNFR c1.cfg' -Q 'RNTO c9.cfg' "$F/")"; e_alheio_regrava="$(f29 e -T "$W/p29.b" "$F/c1.cfg")"
igual29 $P29/e1.cfg "$W/p29.a"; e_intacto=$?; igual29 $P29/c1.cfg "$W/p29.a"; c_intacto=$?
# Pasta criada pelo Envio: é dele enquanto está vazia e passa ao ftpdata com o primeiro arquivo.
e_mkd="$(f29 e -Q 'MKD esub' "$F/")"; m_esub_vazia="$(modo29 $P29/esub)"
e_dentro="$(f29 e -T "$W/p29.a" "$F/esub/x.cfg")"; ate29 15 e29 $P29/esub 'ftpdata:ftpdata 1775'; r_esub=$?; m_esub="$(modo29 $P29/esub $P29/esub/x.cfg)"
e_dentro_apaga="$(f29 e -Q 'DELE esub/x.cfg' "$F/")"; e_esub_ren="$(f29 e -Q 'RNFR esub' -Q 'RNTO esub9' "$F/")"; e_esub_rmd="$(f29 e -Q 'RMD esub' "$F/")"
e_niveis="$(f29 e --ftp-create-dirs -T "$W/p29.a" "$F/n1/n2/y.cfg")"; ate29 15 e29 $P29/n1/n2/y.cfg 'ftpdata:ftpdata 644'
ate29 15 e29 $P29/n1 'ftpdata:ftpdata 1775'; r_niveis=$?; m_niveis="$(modo29 $P29/n1 $P29/n1/n2 $P29/n1/n2/y.cfg)"
# Pasta criada por FTP por um Completo nasce 0755: o Envio só grava nela depois do primeiro arquivo do Completo.
e_sub_antes="$(f29 e -T "$W/p29.a" "$F/sub/e2.cfg")"; c_sub="$(f29 c -T "$W/p29.a" "$F/sub/c4.cfg")"; ate29 15 e29 $P29/sub 'ftpdata:ftpdata 1775'; r_sub=$?
e_sub_depois="$(f29 e -T "$W/p29.a" "$F/sub/e2.cfg")"; ate29 15 e29 $P29/sub/e2.cfg 'ftpdata:ftpdata 644'

# Leitura: lista e baixa, inclusive em subpasta; nada do que grava passa e a pasta fica como estava.
a_antes="$(arvore29)"
l_lista="$(f29 l "$F/")"; l_linhas="$(grep -c . "$W/curl.out")"
l_baixa="$(f29 l -o "$W/p29.baixado" "$F/e1.cfg")"; cmp -s "$W/p29.baixado" "$W/p29.a"; l_igual=$?
l_baixa_sub="$(f29 l -o "$W/p29.baixado" "$F/esub/x.cfg")"
l_envia="$(f29 l -T "$W/p29.b" "$F/l1.cfg")"; l_regrava="$(f29 l -T "$W/p29.b" "$F/c1.cfg")"; l_acrescenta="$(f29 l -a -T "$W/p29.b" "$F/c1.cfg")"
l_apaga="$(f29 l -Q 'DELE c1.cfg' "$F/")"; l_ren="$(f29 l -Q 'RNFR c1.cfg' -Q 'RNTO c9.cfg' "$F/")"; l_mkd="$(f29 l -Q 'MKD lsub' "$F/")"; l_rmd="$(f29 l -Q 'RMD esub' "$F/")"
l_em_sub="$(f29 l -T "$W/p29.b" "$F/esub/l2.cfg")"
a_depois="$(arvore29)"
# O Completo continua mexendo no que o Envio mandou.
c_apaga_e1="$(f29 c -Q 'DELE e1.cfg' "$F/")"; c_ren_esub="$(f29 c -Q 'RNFR esub' -Q 'RNTO esub2' "$F/")"
docker logs "$FTP" > "$W/p29.log" 2>&1; sem_entrega="$(grep -a -c 'entrega nao feita' "$W/p29.log" || true)"

[[ "$r_c" == 0 && "$r_e" == 0 && "$r_l" == 0 && "$contas29" == "p29c:10000:10000 p29e:10002:10000 p29l:10003:10003 " && "$lidos29" == "completo envio leitura" \
  && "$c_envia" == 0 && "$c_pasta" == 0 && "$c_outro" == 0 && "$c_ren" == 0 && "$c_apaga" == 0 && "$c_regrava" == 0 \
  && "$e_lista" == 0 && "$e_linhas" -ge 2 && "$e_baixa" == 0 && "$e_igual" == 0 && "$e_envia" == 0 && "$r_entrega" == 0 && "$e_mkd" == 0 && "$e_dentro" == 0 \
  && "$r_esub" == 0 && "$e_niveis" == 0 && "$r_niveis" == 0 && "$m_niveis" == "ftpdata:ftpdata 1775 ftpdata:ftpdata 1775 ftpdata:ftpdata 644 " \
  && "$c_sub" == 0 && "$r_sub" == 0 && "$e_sub_depois" == 0 && "$l_lista" == 0 && "$l_linhas" -ge 4 && "$l_baixa" == 0 && "$l_igual" == 0 && "$l_baixa_sub" == 0 \
  && "$c_apaga_e1" == 0 && "$c_ren_esub" == 0 && "$sem_entrega" == 0 ]]
caso $? testes 56 "Perfis no FTP" "três usuários em perfis29/a, criados pelo manage-user.sh (saídas $r_c $r_e $r_l): uid e gid no cadastro: $contas29· perfil lido de volta: $lidos29 · Completo: envia $c_envia, cria pasta $c_pasta, renomeia $c_ren, apaga $c_apaga, grava por cima $c_regrava · Envio: lista $e_lista ($e_linhas linhas), baixa $e_baixa (conteúdo $([[ "$e_igual" == 0 ]] && echo igual || echo DIFERENTE)), envia $e_envia, arquivo entregue ao servidor: $m_e1· cria pasta $e_mkd e envia nela $e_dentro: $m_esub· envio com dois níveis de pasta criados no caminho $e_niveis: $m_niveis· pasta criada por FTP pelo Completo: antes do primeiro arquivo dele $e_sub_antes, depois $e_sub_depois · Leitura: lista $l_lista ($l_linhas linhas), baixa $l_baixa (conteúdo $([[ "$l_igual" == 0 ]] && echo igual || echo DIFERENTE)), baixa em subpasta $l_baixa_sub · Completo apaga o que o Envio mandou $c_apaga_e1 e renomeia a pasta dele $c_ren_esub · 'entrega nao feita' no registro do vigia: $sem_entrega (códigos de saída do curl: 0 = feito)"

[[ "$m_e1" == "ftpdata:ftpdata 644 " && "$e_apaga" == 21 && "$e_regrava" == 25 && "$e_acrescenta" == 25 && "$e_ren" == 21 && "$e_alheio" == 21 && "$e_alheio_ren" == 21 \
  && "$e_alheio_regrava" == 25 && "$e_intacto" == 0 && "$c_intacto" == 0 && "$m_esub_vazia" == "ftpenvio:ftpdata 755 " \
  && "$m_esub" == "ftpdata:ftpdata 1775 ftpdata:ftpdata 644 " && "$e_dentro_apaga" == 21 && "$e_esub_ren" == 21 && "$e_esub_rmd" == 21 && "$e_sub_antes" == 25 ]]
caso $? seguranca 99 "Perfil Envio não apaga nem altera" "com o usuário p29e (Envio), depois de o arquivo dele chegar e passar ao servidor ($m_e1) · apagar: $e_apaga · gravar por cima: $e_regrava · acrescentar: $e_acrescenta · renomear: $e_ren · arquivo de outro usuário da pasta: apagar $e_alheio, renomear $e_alheio_ren, gravar por cima $e_alheio_regrava · conteúdo do arquivo dele $([[ "$e_intacto" == 0 ]] && echo intacto || echo ALTERADO) e o do outro $([[ "$c_intacto" == 0 ]] && echo intacto || echo ALTERADO) · pasta criada por ele: vazia $m_esub_vazia· com o primeiro arquivo $m_esub· apagar o arquivo de dentro: $e_dentro_apaga, renomear a pasta: $e_esub_ren, remover a pasta: $e_esub_rmd · enviar em pasta do Completo ainda sem a marca do envio: $e_sub_antes (curl: 21 = comando recusado pelo servidor, 25 = envio recusado)"

[[ "$l_envia" == 25 && "$l_regrava" == 25 && "$l_acrescenta" == 25 && "$l_apaga" == 21 && "$l_ren" == 21 && "$l_mkd" == 21 && "$l_rmd" == 21 && "$l_em_sub" == 25 \
  && -n "$a_antes" && "$a_antes" == "$a_depois" ]]
caso $? seguranca 100 "Perfil Leitura só lista e baixa" "com o usuário p29l (Leitura), na pasta que ele divide com um Completo e um Envio · enviar: $l_envia · gravar por cima: $l_regrava · acrescentar: $l_acrescenta · apagar: $l_apaga · renomear: $l_ren · criar pasta: $l_mkd · remover pasta: $l_rmd · enviar em subpasta: $l_em_sub · nomes, donos, modos e tamanhos de tudo em perfis29 $([[ "$a_antes" == "$a_depois" ]] && echo 'iguais antes e depois' || echo DIFERENTES) (curl: 21 = comando recusado pelo servidor, 25 = envio recusado)"

# ------------------------------------------------------------------ modo das pastas acompanha os perfis
mu perfil p29e "" leitura; r_t1=$?; m_t1="$(modo29 $P29 $P29/sub)"                       # um Completo e dois Leitura
mu perfil p29e "" completo; mu perfil p29l "" completo; r_t2=$?; m_t2="$(modo29 $P29 $P29/sub)"   # só Completo
mu perfil p29e "" envio; r_t3=$?; m_t3="$(modo29 $P29 $P29/sub)"                         # volta o Envio
mu perfil p29e "" dono; r_inv=$?; fala_inv="$(grep -c '^Perfil invalido' "$W/mu.log")"; depois_inv="$(perfil29 p29e)"
mu pasta p29e "" perfis29/b; r_p=$?; m_pasta="$(modo29 $P29 $Q29)"
# Sobra de um envio que não foi entregue (container parado no meio): a partida do ftp conserta.
docker exec "$FTP" sh -c "echo sobra > $Q29/sobra.cfg && mkdir $Q29/psobra && chmod 755 $Q29/psobra && chown ftpenvio:ftpdata $Q29/sobra.cfg $Q29/psobra"
m_sobra_antes="$(modo29 $Q29/sobra.cfg $Q29/psobra)"
dc restart ftp > /dev/null 2>&1; esperar "$FTP"; r_sobe=$?; m_sobra="$(modo29 $Q29/sobra.cfg $Q29/psobra $Q29)"
e_apos="$(f29 e -T "$W/p29.a" "$F/depois.cfg")"; ate29 15 e29 $Q29/depois.cfg 'ftpdata:ftpdata 644'; r_apos=$?
mu del p29e; r_d=$?; m_removido="$(modo29 $Q29)"
[[ "$m_completo" == "root:root 700 ftpdata:ftpdata 750 ftpdata:ftpdata 750 " && "$m_envio" == "ftpdata:ftpdata 1770 " && "$m_leitura" == "ftpdata:ftpdata 1775 " \
  && "$m_sub" == "ftpdata:ftpdata 755 " && "$r_t1" == 0 && "$m_t1" == "ftpdata:ftpdata 755 ftpdata:ftpdata 755 " && "$r_t2" == 0 && "$m_t2" == "ftpdata:ftpdata 750 ftpdata:ftpdata 750 " \
  && "$r_t3" == 0 && "$m_t3" == "ftpdata:ftpdata 1770 ftpdata:ftpdata 1770 " && "$r_inv" != 0 && "$fala_inv" == 1 && "$depois_inv" == envio \
  && "$r_p" == 0 && "$m_pasta" == "ftpdata:ftpdata 750 ftpdata:ftpdata 1770 " && "$m_sobra_antes" == "ftpenvio:ftpdata 644 ftpenvio:ftpdata 755 " \
  && "$r_sobe" == 0 && "$m_sobra" == "ftpdata:ftpdata 644 ftpdata:ftpdata 1770 ftpdata:ftpdata 1770 " && "$e_apos" == 0 && "$r_apos" == 0 \
  && "$r_d" == 0 && "$m_removido" == "ftpdata:ftpdata 750 " ]]
caso $? seguranca 101 "Modo das pastas acompanha os perfis" "/data, a pasta de cima e a casa com um só Completo: $m_completo· com um Envio junto: $m_envio· com um Leitura junto: $m_leitura· pasta criada por FTP dentro dela: $m_sub· Envio trocado para Leitura (saída $r_t1), casa e pasta de dentro: $m_t1· todos Completo ($r_t2): $m_t2· de volta ao Envio ($r_t3): $m_t3· perfil que não existe: saída $r_inv, mensagem 'Perfil invalido': $fala_inv, perfil continua $depois_inv · Envio levado para outra pasta ($r_p), a antiga e a nova: $m_pasta· arquivo e pasta deixados sem entrega: $m_sobra_antes→ depois de reiniciar o ftp (pronto: $r_sobe): $m_sobra· envio depois do reinício: $e_apos, entregue: $r_apos · Envio removido ($r_d), a pasta dele: $m_removido"

# ------------------------------------------------------------------ tela única e troca de perfil pelo painel
W29="$W/p29w.jar"; M29="$B/meus-arquivos"
lista="$(aba -b "$J" "$B/usuarios")"; cp "$W/corpo" "$W/p29.lista"
na_lista="$(grep -c -F '<strong>p29c</strong><span class="perfil">Completo</span>' "$W/p29.lista")"
adm_na_lista="$(grep -c -F "<strong>$ADMIN</strong> <span class=\"etiqueta\">você</span><span class=\"perfil\">Administrador</span>" "$W/p29.lista")"
menu29="$(grep -o '<nav.*</nav>' "$W/p29.lista" | grep -o 'href="/administradores"' | wc -l)"
novo="$(aba -b "$J" "$B/usuarios/novo")"; opcoes29="$(grep -o -E 'name="perfil" value="(administrador|completo|envio|leitura)"' "$W/corpo" | sort -u | wc -l)"
auditoria; n_criado="$(grep -c ' evento=usuario_criado .* usuario=p29w .* perfil=leitura$' "$W/auditoria")"
r_novo="$(envio /usuarios/novo --data-urlencode "csrf=$K" --data-urlencode 'perfil=leitura' --data-urlencode 'usuario=p29w' --data-urlencode 'pasta=perfis29/w' --data-urlencode "senha@$W/p29w.senha" --data-urlencode "confirmacao@$W/p29w.senha")"
auditoria; n_criado=$(( $(grep -c ' evento=usuario_criado .* usuario=p29w .* perfil=leitura$' "$W/auditoria") - n_criado ))
p_novo="$(perfil29 p29w)"; m_novo="$(modo29 /data/perfis29/w)"; w_envia_antes="$(f29 w -T "$W/p29.a" "$F/w1.cfg")"
e_w="$(COMO=p29w entrar "$W29" "$W/p29w.senha")"; proibir "$(biscoito_de "$W29")"; s_antes="$(aba -b "$W29" "$M29")"
editar="$(aba -b "$J" "$B/usuarios/editar?usuario=p29w")"; marcado="$(grep -o -E 'name="perfil" value="[a-z]+" checked' "$W/corpo" | tr '\n' ' ')"
r_troca="$(envio /usuarios/perfil --data-urlencode "csrf=$K" --data-urlencode 'usuario=p29w' --data-urlencode 'perfil=envio')"
p_troca="$(perfil29 p29w)"; m_troca="$(modo29 /data/perfis29/w)"; s_depois="$(aba -b "$W29" "$M29")"
w_envia="$(f29 w -T "$W/p29.a" "$F/w1.cfg")"; ate29 15 e29 /data/perfis29/w/w1.cfg 'ftpdata:ftpdata 644'; r_w=$?; w_apaga="$(f29 w -Q 'DELE w1.cfg' "$F/")"
aba -b "$J" "$B/usuarios" > /dev/null; na_lista_w="$(grep -c -F '<strong>p29w</strong><span class="perfil">Envio</span>' "$W/corpo")"
r="$(aba -b "$J" "$B/atividade")"; na_atividade="$(grep -c 'Perfil do usuário trocado' "$W/corpo")"
auditoria; n_troca="$(grep -c " evento=perfil_trocado admin=$ADMIN usuario=p29w perfil=envio anterior=leitura\$" "$W/auditoria")"
[[ "$lista" == "200 " && "$na_lista" == 1 && "$adm_na_lista" == 1 && "$menu29" == 0 && "$novo" == "200 " && "$opcoes29" == 4 \
  && "$r_novo" == "303 /usuarios?m=criado" && "$n_criado" == 1 && "$p_novo" == leitura && "$m_novo" == "ftpdata:ftpdata 755 " && "$w_envia_antes" == 25 \
  && "$e_w" == 303 && "$s_antes" == "200 " && "$editar" == "200 " && "$marcado" == 'name="perfil" value="leitura" checked ' \
  && "$r_troca" == "303 /usuarios?m=perfil" && "$p_troca" == envio && "$m_troca" == "ftpdata:ftpdata 1770 " && "$s_depois" == "303 /entrar" \
  && "$w_envia" == 0 && "$r_w" == 0 && "$w_apaga" == 21 && "$na_lista_w" == 1 && "$r" == "200 " && "$na_atividade" -ge 1 && "$n_troca" == 1 ]]
caso $? testes 57 "Tela única de usuários e troca de perfil" "GET /usuarios: $lista· '$ADMIN' na lista com o perfil Administrador: $adm_na_lista, p29c com Completo: $na_lista, link do menu para /administradores: $menu29 · GET /usuarios/novo: $novo· perfis no seletor: $opcoes29 de 4 · POST /usuarios/novo com perfil=leitura: $r_novo, usuario_criado com perfil=leitura na auditoria: $n_criado, perfil no cadastro: $p_novo, pasta: $m_novo· envio dele pelo FTP: $w_envia_antes · entrada dele no painel: $e_w, Meus arquivos: $s_antes· tela Editar ($editar) marca: $marcado· POST /usuarios/perfil com perfil=envio: $r_troca, perfil no cadastro: $p_troca, pasta: $m_troca· sessão dele no painel depois da troca: $s_depois · agora envia pelo FTP: $w_envia (entregue: $r_w) e não apaga: $w_apaga · na lista com Envio: $na_lista_w · aba Atividade ($r) com 'Perfil do usuário trocado': $na_atividade, perfil_trocado na auditoria: $n_troca"

# ------------------------------------------------------------------ recusas
e_w="$(COMO=p29w entrar "$W29" "$W/p29w.senha")"; proibir "$(biscoito_de "$W29")"
WK="$(c -b "$W29" "$M29" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1)"; proibir "$WK"
c_antes="$(cadastro29)"; u_antes="$(usuarios_ftp)"; a_antes="$(admins)"; auditoria; n_antes="$(eventos perfil_trocado)"
x_1="$(envio /usuarios/perfil --data-urlencode "csrf=$K" --data-urlencode 'usuario=p29w' --data-urlencode 'perfil=dono')"
x_2="$(envio /usuarios/perfil --data-urlencode "csrf=$K" --data-urlencode 'usuario=p29w' --data-urlencode 'perfil=administrador')"
x_3="$(envio /usuarios/perfil --data-urlencode "csrf=$K" --data-urlencode 'usuario=p29w')"
x_4="$(envio /usuarios/perfil --data-urlencode "csrf=$K" --data-urlencode 'usuario=p29w' --data-urlencode 'perfil=envio')"
x_5="$(envio /usuarios/perfil --data-urlencode "csrf=$K" --data-urlencode 'usuario=nao-existe29' --data-urlencode 'perfil=leitura')"
x_6="$(envio /usuarios/perfil --data-urlencode 'usuario=p29w' --data-urlencode 'perfil=leitura')"
x_7="$(c -o /dev/null -w '%{http_code} %{redirect_url}' -H "Origin: $B" --data-urlencode 'usuario=p29w' --data-urlencode 'perfil=completo' "$B/usuarios/perfil" | sed "s|$B||")"
x_8="$(POTE="$W29" envio /usuarios/perfil --data-urlencode "csrf=$WK" --data-urlencode 'usuario=p29w' --data-urlencode 'perfil=completo')"
x_9="$(envio /usuarios/novo --data-urlencode "csrf=$K" --data-urlencode 'perfil=raiz' --data-urlencode 'usuario=intruso29' --data-urlencode "senha@$W/p29w.senha" --data-urlencode "confirmacao@$W/p29w.senha")"
# Administrador pelo formulário único pede a senha atual de quem cria, como antes.
x_10="$(envio /usuarios/novo --data-urlencode "csrf=$K" --data-urlencode 'perfil=administrador' --data-urlencode 'usuario=intruso29' --data-urlencode "senha@$W/p29w.senha" --data-urlencode "confirmacao@$W/p29w.senha")"   # recusa 1
mu add intruso29 "$W/p29w.senha" perfis29/x raiz; x_11=$?; x_12="$(docker exec "$FTP" sh -c 'ls -d /data/perfis29/x 2>/dev/null | wc -l')"
auditoria; n_depois="$(eventos perfil_trocado)"
[[ "$e_w" == 303 && -n "$WK" && "$x_1" == "400 " && "$x_2" == "400 " && "$x_3" == "400 " && "$x_4" == "409 " && "$x_5" == "404 " && "$x_6" == "403 " && "$x_7" == "303 /entrar" \
  && "$x_8" == "404 " && "$x_9" == "400 " && "$x_10" == "403 " && "$x_11" != 0 && "$x_12" == 0 && -n "$c_antes" && "$c_antes" == "$(cadastro29)" \
  && "$u_antes" == "$(usuarios_ftp)" && "$a_antes" == "$(admins)" && "$n_antes" == "$n_depois" && "$(perfil29 p29w)" == envio ]]
caso $? seguranca 102 "Perfil recusado" "POST /usuarios/perfil com sessão e token de administrador · perfil que não existe: $x_1· perfil=administrador: $x_2· sem o campo: $x_3· o perfil que o usuário já tem: $x_4· usuário que não existe: $x_5· sem o token: $x_6· sem sessão: $x_7 · com a sessão e o token do próprio usuário do FTP: $x_8· POST /usuarios/novo com perfil que não existe: $x_9· com perfil=administrador e sem a senha atual: $x_10· manage-user.sh add com perfil que não existe: saída $x_11, pasta criada: $x_12 · cadastro do FTP $([[ "$c_antes" == "$(cadastro29)" ]] && echo idêntico || echo ALTERADO), usuários $([[ "$u_antes" == "$(usuarios_ftp)" ]] && echo inalterados || echo ALTERADOS), administradores $([[ "$a_antes" == "$(admins)" ]] && echo inalterados || echo ALTERADOS) · perfil_trocado na auditoria: $n_antes → $n_depois"

# ------------------------------------------------------------------ o perfil vale também no painel
# p29c (Completo) e p29l (Leitura) dividem perfis29/a; p29w (Envio) está em perfis29/w; p29e volta com a pasta dentro da de p29c.
mu perfil p29l "" leitura; r_pl=$?; mu add p29e "$W/p29e.senha" perfis29/a/dentro; r_pe=$?
docker exec "$FTP" ln -s /data/perfis29/w "$P29/atalho29"
declare -A T29
entra29() { COMO="p29$1" entrar "$W/p29$1.jar" "$W/p29$1.senha"; }                                    # <c|l|w> → código HTTP
v29() { aba -b "$W/p29$1.jar" "$B$2"; }                                                           # <c|l|w> <caminho>: GET com a sessão dele
p29() { local de="$1" rota="$2"; shift 2; POTE="$W/p29$de.jar" envio "$rota" --data-urlencode "csrf=${T29[$de]}" "$@"; }   # <c|l|w> <caminho> <campos...>
tem29() { grep -c -E "$1" "$W/corpo" || true; }                                                   # <expressão>: linhas da última tela com ela
baixa29() { c -b "$W/p29$1.jar" -o "$W/p29.baixado" -w '%{http_code}' "$M29/baixar?arquivo=$2"; }    # <c|l|w> <arquivo> → código HTTP
tem_no_servidor29() { docker exec "$FTP" sh -c 'ls -d "$@" 2>/dev/null | wc -l' sh "$@"; }          # <caminho...>: quantos existem
sessoes29() { # <c|l|w>...: entra no painel como cada um e guarda o token dos formulários dele; os códigos HTTP ficam em $e_web
  local n; e_web=""
  for n in "$@"; do
    e_web+="$(entra29 "$n") "; proibir "$(biscoito_de "$W/p29$n.jar")"
    T29[$n]="$(c -b "$W/p29$n.jar" "$M29" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1)"; proibir "${T29[$n]}"
  done
}
linhas29() { grep -c -E "$1" "$W/auditoria" || true; }                                             # <expressão>: linhas da auditoria com ela
sessoes29 l w c

# Leitura: navega e baixa. A tela não tem o formulário de pasta nem os botões de renomear e de apagar.
t_l="$(v29 l /meus-arquivos)"; l_fala="$(tem29 'perfil desta conta é de leitura')"; l_form="$(tem29 'action="/meus-arquivos/pasta"')"
l_botoes="$(tem29 '/meus-arquivos/(renomear|apagar)')"; l_baixar="$(tem29 'href="/meus-arquivos/baixar\?arquivo=c1\.cfg"')"
b_l="$(baixa29 l c1.cfg)"; cmp -s "$W/p29.baixado" "$W/p29.a"; b_l_igual=$?
# Envio: também cria pasta, e o que ele manda por FTP entra nela.
t_w="$(v29 w /meus-arquivos)"; w_fala="$(tem29 'perfil desta conta é de envio')"; w_form="$(tem29 'action="/meus-arquivos/pasta"')"; w_botoes="$(tem29 '/meus-arquivos/(renomear|apagar)')"
r_w_pasta="$(p29 w /meus-arquivos/pasta --data-urlencode 'pasta=' --data-urlencode 'nome=web29')"; m_web="$(modo29 /data/perfis29/w/web29)"; m_casa_w="$(modo29 /data/perfis29/w)"
r_w_dentro="$(p29 w /meus-arquivos/pasta --data-urlencode 'pasta=web29' --data-urlencode 'nome=dia')"; r_w_repete="$(p29 w /meus-arquivos/pasta --data-urlencode 'pasta=' --data-urlencode 'nome=web29')"
w_ftp="$(f29 w -T "$W/p29.a" "$F/web29/w2.cfg")"; ate29 15 e29 /data/perfis29/w/web29/w2.cfg 'ftpdata:ftpdata 644'; r_w_ftp=$?
b_w="$(baixa29 w web29/w2.cfg)"; cmp -s "$W/p29.baixado" "$W/p29.a"; b_w_igual=$?
# Completo: cria pasta, troca o nome e apaga, com a senha do FTP dele.
t_c="$(v29 c /meus-arquivos)"; c_fala="$(tem29 'Apagar pede a sua senha do FTP')"; c_form="$(tem29 'action="/meus-arquivos/pasta"')"
c_b_ren="$(tem29 'href="/meus-arquivos/renomear\?item=c1\.cfg"')"; c_b_apa="$(tem29 'href="/meus-arquivos/apagar\?item=c1\.cfg"')"; c_adm="$(tem29 'href="/arquivos')"
r_c_pasta="$(p29 c /meus-arquivos/pasta --data-urlencode 'pasta=' --data-urlencode 'nome=org29')"; m_org="$(modo29 $P29/org29)"; m_casa_c="$(modo29 $P29)"
tela_ren="$(v29 c '/meus-arquivos/renomear?item=c1.cfg')"; ren_acao="$(tem29 'action="/meus-arquivos/renomear"')"; ren_onde="$(tem29 '<code>Início</code>')"
r_c_ren="$(p29 c /meus-arquivos/renomear --data-urlencode 'item=c1.cfg' --data-urlencode 'nome=c1-web.cfg')"
r_c_ren_sub="$(p29 c /meus-arquivos/renomear --data-urlencode 'item=n1/n2/y.cfg' --data-urlencode 'nome=z.cfg')"
tela_apa="$(v29 c '/meus-arquivos/apagar?item=c1-web.cfg')"; apa_acao="$(tem29 'action="/meus-arquivos/apagar"')"; apa_senha="$(tem29 'Sua senha do FTP')"
r_c_apa="$(p29 c /meus-arquivos/apagar --data-urlencode 'item=c1-web.cfg' --data-urlencode 'confirmar=sim' --data-urlencode "senha_atual@$W/p29c.senha")"
r_c_apa_pasta="$(p29 c /meus-arquivos/apagar --data-urlencode 'item=sub' --data-urlencode 'confirmar=sim' --data-urlencode "senha_atual@$W/p29c.senha")"
aviso29="$(v29 c '/meus-arquivos?pasta=&m=apagado')"; n_aviso29="$(tem29 'Apagado\.')"
sairam="$(tem_no_servidor29 $P29/c1.cfg $P29/c1-web.cfg $P29/sub $P29/n1/n2/y.cfg)"; ficaram="$(tem_no_servidor29 $P29/n1/n2/z.cfg $P29/org29 /data/perfis29/w/web29/dia)"
auditoria
a_baixa="$(grep -c ' evento=arquivo_baixado usuario=p29l arquivo=perfis29/a/c1.cfg bytes=' "$W/auditoria")"
a_pasta="$(grep -c ' evento=pasta_criada usuario=p29w pasta=perfis29/w/web29$' "$W/auditoria")"
a_ren="$(grep -c ' evento=item_renomeado usuario=p29c tipo=arquivo de=perfis29/a/c1.cfg para=perfis29/a/c1-web.cfg$' "$W/auditoria")"
a_apa="$(grep -c ' evento=item_apagado usuario=p29c tipo=pasta caminho=perfis29/a/sub itens=3$' "$W/auditoria")"
[[ "$r_pl" == 0 && "$r_pe" == 0 && "$e_web" == "303 303 303 " && -n "${T29[l]}" && -n "${T29[w]}" && -n "${T29[c]}" \
  && "$t_l" == "200 " && "$l_fala" == 1 && "$l_form" == 0 && "$l_botoes" == 0 && "$l_baixar" == 1 && "$b_l" == 200 && "$b_l_igual" == 0 \
  && "$t_w" == "200 " && "$w_fala" == 1 && "$w_form" == 1 && "$w_botoes" == 0 && "$r_w_pasta" == "303 /meus-arquivos?pasta=&m=criada" \
  && "$m_web" == "ftpdata:ftpdata 1770 " && "$m_web" == "$m_casa_w" && "$r_w_dentro" == "303 /meus-arquivos?pasta=web29&m=criada" && "$r_w_repete" == "409 " \
  && "$w_ftp" == 0 && "$r_w_ftp" == 0 && "$b_w" == 200 && "$b_w_igual" == 0 \
  && "$t_c" == "200 " && "$c_fala" == 1 && "$c_form" == 1 && "$c_b_ren" == 1 && "$c_b_apa" == 1 && "$c_adm" == 0 \
  && "$r_c_pasta" == "303 /meus-arquivos?pasta=&m=criada" && "$m_org" == "ftpdata:ftpdata 755 " && "$m_org" == "$m_casa_c" \
  && "$tela_ren" == "200 " && "$ren_acao" == 1 && "$ren_onde" == 1 && "$r_c_ren" == "303 /meus-arquivos?pasta=&m=renomeado" \
  && "$r_c_ren_sub" == "303 /meus-arquivos?pasta=n1/n2&m=renomeado" && "$tela_apa" == "200 " && "$apa_acao" == 1 && "$apa_senha" == 1 \
  && "$r_c_apa" == "303 /meus-arquivos?pasta=&m=apagado" && "$r_c_apa_pasta" == "303 /meus-arquivos?pasta=&m=apagado" && "$aviso29" == "200 " && "$n_aviso29" -ge 1 \
  && "$sairam" == 0 && "$ficaram" == 3 && "$a_baixa" == 1 && "$a_pasta" == 1 && "$a_ren" == 1 && "$a_apa" == 1 ]]
caso $? testes 58 "Meus arquivos conforme o perfil" "entrada no painel de p29l (Leitura), p29w (Envio) e p29c (Completo): $e_web· Leitura: tela $t_l, texto do perfil: $l_fala, formulário de nova pasta: $l_form, botões de renomear ou apagar: $l_botoes, botão Baixar: $l_baixar, download $b_l (conteúdo $([[ "$b_l_igual" == 0 ]] && echo igual || echo DIFERENTE)) · Envio: tela $t_w, texto do perfil: $w_fala, formulário de nova pasta: $w_form, botões de renomear ou apagar: $w_botoes · cria a pasta web29: $r_w_pasta, dono e modo: $m_web(a pasta dele: $m_casa_w) · outra dentro dela: $r_w_dentro · o mesmo nome de novo: $r_w_repete · envio por FTP na pasta criada: $w_ftp (entregue: $r_w_ftp), download dele pelo painel: $b_w (conteúdo $([[ "$b_w_igual" == 0 ]] && echo igual || echo DIFERENTE)) · Completo: tela $t_c, texto do perfil: $c_fala, formulário de nova pasta: $c_form, botão Renomear: $c_b_ren, botão Apagar: $c_b_apa, link para a aba do administrador: $c_adm · cria a pasta org29: $r_c_pasta, dono e modo: $m_org(a pasta dele: $m_casa_c) · tela Renomear: $tela_ren · troca o nome de c1.cfg: $r_c_ren · de um arquivo dois níveis abaixo: $r_c_ren_sub · tela Apagar ($tela_apa) pede 'Sua senha do FTP': $apa_senha · apaga o arquivo: $r_c_apa · apaga a pasta sub com o que há nela: $r_c_apa_pasta · aviso 'Apagado.': $n_aviso29 · dos 4 itens renomeados ou apagados, continuam no lugar antigo: $sairam; dos 3 criados ou renomeados, existem: $ficaram · auditoria com o caminho a partir da pasta dos dados: arquivo_baixado $a_baixa, pasta_criada $a_pasta, item_renomeado $a_ren, item_apagado (itens=3) $a_apa"

# O que o perfil não tem não existe para ele, mesmo com a sessão, o token e a senha certos; e ninguém sai da própria pasta.
# A auditoria grava uma recusa de cada tipo por minuto e por endereço: o painel é reiniciado antes de cada perfil, para a
# primeira recusa dele ficar registrada. O reinício encerra as sessões, e cada um entra de novo.
L29_L=' evento=recusa_papel usuario=p29l caminho=/meus-arquivos/pasta perfil=leitura$'
L29_W=' evento=recusa_papel usuario=p29w caminho=/meus-arquivos/renomear perfil=envio$'
L29_C=' evento=recusa_caminho usuario=p29w caminho=\.\./fora29$'
L29_S=' evento=usuario_senha_atual_recusada usuario=p29c caminho=/meus-arquivos/apagar$'
L29_F=' evento=(pasta_criada|item_renomeado|item_apagado) '
a_antes="$(arvore29)"; c_antes="$(cadastro29)"
dc restart painel > /dev/null 2>&1; painel_de_pe; sessoes29 l; e_103="$e_web"; auditoria
n_papel="$(eventos recusa_papel)"; n_senha="$(eventos usuario_senha_atual_recusada)"; n_caminho="$(eventos recusa_caminho)"; n_feito="$(linhas29 "$L29_F")"
n_l="$(linhas29 "$L29_L")"; n_w="$(linhas29 "$L29_W")"; n_c="$(linhas29 "$L29_C")"; n_s="$(linhas29 "$L29_S")"
y_l1="$(p29 l /meus-arquivos/pasta --data-urlencode 'pasta=' --data-urlencode 'nome=l-web')"
y_l2="$(v29 l '/meus-arquivos/renomear?item=esub2')"; y_l3="$(p29 l /meus-arquivos/renomear --data-urlencode 'item=esub2' --data-urlencode 'nome=l-ren')"
y_l4="$(v29 l '/meus-arquivos/apagar?item=esub2')"
y_l5="$(p29 l /meus-arquivos/apagar --data-urlencode 'item=esub2' --data-urlencode 'confirmar=sim' --data-urlencode "senha_atual@$W/p29l.senha")"
dc restart painel > /dev/null 2>&1; painel_de_pe; sessoes29 w c; e_103+="$e_web"
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
y_w1="$(v29 w '/meus-arquivos/renomear?item=w1.cfg')"; y_w2="$(p29 w /meus-arquivos/renomear --data-urlencode 'item=w1.cfg' --data-urlencode 'nome=w-ren.cfg')"
y_w3="$(v29 w '/meus-arquivos/apagar?item=w1.cfg')"
y_w4="$(p29 w /meus-arquivos/apagar --data-urlencode 'item=w1.cfg' --data-urlencode 'confirmar=sim' --data-urlencode "senha_atual@$W/p29w.senha")"
y_w5="$(p29 w /meus-arquivos/pasta --data-urlencode 'pasta=..' --data-urlencode 'nome=fora29')"; y_w6="$(p29 w /meus-arquivos/pasta --data-urlencode 'pasta=' --data-urlencode 'nome=../fora29')"
# Completo: a senha de outro usuário não serve, a caixa de confirmação é exigida e o caminho não sai da pasta dele.
y_c1="$(p29 c /meus-arquivos/apagar --data-urlencode 'item=esub2' --data-urlencode 'confirmar=sim' --data-urlencode "senha_atual@$W/p29w.senha")"
y_c2="$(p29 c /meus-arquivos/apagar --data-urlencode 'item=esub2' --data-urlencode "senha_atual@$W/p29c.senha")"
y_c3="$(p29 c /meus-arquivos/renomear --data-urlencode 'item=../w/w1.cfg' --data-urlencode 'nome=meu.cfg')"
y_c4="$(p29 c /meus-arquivos/apagar --data-urlencode 'item=perfis29/w/w1.cfg' --data-urlencode 'confirmar=sim' --data-urlencode "senha_atual@$W/p29c.senha")"
y_c5="$(p29 c /meus-arquivos/renomear --data-urlencode 'item=atalho29/w1.cfg' --data-urlencode 'nome=meu.cfg')"; y_c6="$(baixa29 c atalho29/w1.cfg)"
# A pasta de outro usuário, dentro da dele: não sai nem muda de nome por aqui, e a tela não diz de quem é.
y_c7="$(p29 c /meus-arquivos/apagar --data-urlencode 'item=dentro' --data-urlencode 'confirmar=sim' --data-urlencode "senha_atual@$W/p29c.senha")"
y_c8="$(p29 c /meus-arquivos/renomear --data-urlencode 'item=dentro' --data-urlencode 'nome=dentro2')"
y_c9="$(v29 c '/meus-arquivos/apagar?item=dentro')"; sem_nome="$(tem29 'outro usuário do FTP')"; com_nome="$(grep -c -F 'p29e' "$W/corpo" || true)"
# As rotas da tela Meus arquivos não existem para o administrador.
y_a="$(aba -b "$J" "$B/meus-arquivos/apagar?item=esub2")"
auditoria
d_leitura=$(( $(linhas29 "$L29_L") - n_l )); d_envio=$(( $(linhas29 "$L29_W") - n_w )); d_fuga=$(( $(linhas29 "$L29_C") - n_c )); a_senha=$(( $(linhas29 "$L29_S") - n_s ))
d_papel=$(( $(eventos recusa_papel) - n_papel )); d_senha=$(( $(eventos usuario_senha_atual_recusada) - n_senha )); d_caminho=$(( $(eventos recusa_caminho) - n_caminho ))
d_feito=$(( $(linhas29 "$L29_F") - n_feito ))
[[ "$e_103" == "303 303 303 " && "$e_adm" == 303 && -n "${T29[l]}" && -n "${T29[w]}" && -n "${T29[c]}" && -n "$K" \
  && "$y_l1" == "404 " && "$y_l2" == "404 " && "$y_l3" == "404 " && "$y_l4" == "404 " && "$y_l5" == "404 " && "$y_w1" == "404 " && "$y_w2" == "404 " && "$y_w3" == "404 " \
  && "$y_w4" == "404 " && "$y_w5" == "400 " && "$y_w6" == "400 " && "$y_c1" == "403 " && "$y_c2" == "400 " && "$y_c3" == "400 " && "$y_c4" == "404 " && "$y_c5" == "403 " \
  && "$y_c6" == 403 && "$y_c7" == "409 " && "$y_c8" == "409 " && "$y_c9" == "409 " && "$sem_nome" == 1 && "$com_nome" == 0 && "$y_a" == "404 " \
  && "$d_leitura" == 1 && "$d_envio" == 1 && "$d_papel" -ge 2 && "$d_senha" == 1 && "$a_senha" == 1 && "$d_fuga" == 1 && "$d_caminho" -ge 1 && "$d_feito" == 0 \
  && -n "$a_antes" && "$a_antes" == "$(arvore29)" && -n "$c_antes" && "$c_antes" == "$(cadastro29)" ]]
caso $? seguranca 103 "Painel recusa o que o perfil não tem" "cada pedido com a sessão e o token do próprio usuário, e a senha certa onde ela é pedida · Leitura (p29l): criar pasta $y_l1· tela Renomear $y_l2· renomear $y_l3· tela Apagar $y_l4· apagar $y_l5· Envio (p29w): tela Renomear $y_w1· renomear $y_w2· tela Apagar $y_w3· apagar $y_w4· criar pasta em '..': $y_w5· com o nome '../fora29': $y_w6· Completo (p29c): apagar com a senha de outro usuário $y_c1· sem a caixa de confirmação $y_c2· renomear '../w/w1.cfg' $y_c3· apagar 'perfis29/w/w1.cfg', caminho que só existe fora da pasta dele $y_c4· renomear por um link simbólico que aponta para a pasta de outro usuário $y_c5· baixar por ele $y_c6 · pasta de outro usuário dentro da dele: apagar $y_c7· renomear $y_c8· tela Apagar $y_c9, diz 'outro usuário do FTP': $sem_nome, mostra o nome dele: $com_nome · administrador em /meus-arquivos/apagar: $y_a· auditoria, que grava uma recusa de cada tipo por minuto e por endereço, com o painel reiniciado antes de cada perfil (entradas depois dos reinícios: $e_103· administrador: $e_adm): recusa_papel +$d_papel, a primeira de p29l com perfil=leitura: $d_leitura, a primeira de p29w com perfil=envio: $d_envio · recusa_caminho +$d_caminho, a de p29w em '../fora29': $d_fuga · usuario_senha_atual_recusada +$d_senha, a de p29c em /meus-arquivos/apagar: $a_senha · pasta criada, item renomeado ou apagado: +$d_feito · nomes, donos, modos e tamanhos de tudo em perfis29 $([[ "$a_antes" == "$(arvore29)" ]] && echo 'iguais antes e depois' || echo DIFERENTES) · cadastro do FTP $([[ "$c_antes" == "$(cadastro29)" ]] && echo idêntico || echo ALTERADO)"

for n in c e l w; do mu del "p29$n"; done
docker exec "$FTP" rm -rf /data/perfis29
