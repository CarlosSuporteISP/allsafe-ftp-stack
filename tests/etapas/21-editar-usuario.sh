#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa U: editar usuário. Pasta trocada pelo painel e pelo terminal, senha do usuário inicial trocada pelo
# painel (vale até o arquivo do segredo mudar), usuário inicial que não é removido e troca de pasta que não
# sai da pasta dos dados nem age sem sessão.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel zera a contagem de falhas de entrada e das recusas e encerra as sessões.
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"

U21="$W/u21.jar"
pasta21() { docker exec "$FTP" sh -c "grep '^$1:' /auth/pureftpd.passwd | cut -d: -f6"; }                 # <usuário>: pasta gravada no cadastro do FTP
# <usuário>: impressão do cadastro dele sem a pasta (campo 6); muda se a senha ou um limite for regravado. O hash não sai do container.
resto21() { docker exec "$FTP" sh -c "grep '^$1:' /auth/pureftpd.passwd | cut -d: -f1-5,7- | sha256sum | cut -c1-16"; }
dono21() { docker exec "$FTP" stat -c '%U:%G %a %F' "/data/$1" 2>/dev/null || echo ausente; }             # <pasta>: dono, modo e tipo
modo21() { docker exec "$FTP" stat -c '%U:%G %a' "/auth/$1" 2>/dev/null || echo ausente; }                # <arquivo de /auth>: dono e modo
arvore21() { docker exec "$FTP" sh -c 'find /data /auth -xdev | sort | sha256sum | cut -c1-16'; }         # tudo o que existe nos dados e no cadastro
cadastro21() { docker exec "$FTP" sh -c 'sha256sum < /auth/pureftpd.passwd' | cut -c1-16; }
troca21() { envio /usuarios/pasta --data-urlencode "csrf=$K" --data-urlencode "usuario=$1" --data-urlencode "pasta=$2"; }  # <usuário> <pasta> → "código destino"
login21() { local r; r="$(ftp_curl tls "$1" "$2" -l "$F/")"; echo "$r $(resposta '(226|530) ' | cut -c1-3)"; }  # <usuário> <arquivo da senha> → "0 226" ou "67 530"
subir21() { dc restart ftp > /dev/null 2>&1; esperar "$FTP"; saude "$FTP"; }                              # reinicia o serviço ftp → saúde

nova_senha "$W/u21.senha"; nova_senha "$W/ini21.senha"; nova_senha "$W/seg21.senha"
printf 'gravado-antes-da-troca-%s\n' "$(openssl rand -hex 8)" > "$W/antes21.cfg"
printf 'gravado-depois-da-troca-%s\n' "$(openssl rand -hex 8)" > "$W/depois21.cfg"

# ------------------------------------------------------------------ pasta trocada pelo painel e pelo terminal
r_novo="$(envio /usuarios/novo --data-urlencode "csrf=$K" --data-urlencode 'usuario=edit21' --data-urlencode "senha@$W/u21.senha" --data-urlencode "confirmacao@$W/u21.senha")"
r_f1="$(ftp_curl tls edit21 "$W/u21.senha" -T "$W/antes21.cfg" "$F/antes.cfg")"
p_antes="$(pasta21 edit21)"; resto_antes="$(resto21 edit21)"
e_usu="$(COMO=edit21 entrar "$U21" "$W/u21.senha")"; proibir "$(biscoito_de "$U21")"; s_antes="$(aba -b "$U21" "$B/meus-arquivos")"
auditoria; n_antes="$(eventos pasta_trocada)"
lista="$(aba -b "$J" "$B/usuarios")"; botao="$(grep -c 'href="/usuarios/editar?usuario=edit21"' "$W/corpo")"; botao_ini="$(grep -c "href=\"/usuarios/editar?usuario=$USUARIO\"" "$W/corpo")"
tela="$(aba -b "$J" "$B/usuarios/editar?usuario=edit21")"; formulario="$(grep -c 'action="/usuarios/pasta"' "$W/corpo")"; atual="$(grep -c 'Pasta atual: <code>[^<]*/edit21</code>' "$W/corpo")"
r_troca="$(troca21 edit21 clientes21/olt-nova)"
p_painel="$(pasta21 edit21)"; d_nova="$(dono21 clientes21/olt-nova)"; d_cima="$(dono21 clientes21)"
docker exec "$FTP" test -f /data/edit21/antes.cfg; ficou=$?
r_l="$(ftp_curl tls edit21 "$W/u21.senha" -l "$F/")"; ve_antigo="$(grep -c 'antes.cfg' "$W/curl.out")"
r_f2="$(ftp_curl tls edit21 "$W/u21.senha" -T "$W/depois21.cfg" "$F/depois.cfg")"
docker exec "$FTP" test -f /data/clientes21/olt-nova/depois.cfg; chegou=$?
resto_painel="$(resto21 edit21)"; s_depois="$(aba -b "$U21" "$B/meus-arquivos")"
aviso="$(aba -b "$J" "$B/usuarios?m=pasta")"; n_aviso="$(grep -c 'Pasta trocada' "$W/corpo")"; na_lista="$(grep -c 'href="/arquivos?pasta=clientes21/olt-nova"' "$W/corpo")"
auditoria; n_depois="$(eventos pasta_trocada)"; registro="$(grep -c " evento=pasta_trocada admin=$ADMIN usuario=edit21 pasta=clientes21/olt-nova anterior=edit21\$" "$W/auditoria")"
atividade="$(aba -b "$J" "$B/atividade")"; na_atividade="$(grep -c 'Pasta do usuário trocada' "$W/corpo")"
mu pasta edit21 "" clientes21/olt-terminal; r_mu=$?; fala="$(grep -c 'Os arquivos de /data/clientes21/olt-nova continuam la' "$W/mu.log")"
p_terminal="$(pasta21 edit21)"; d_terminal="$(dono21 clientes21/olt-terminal)"; resto_terminal="$(resto21 edit21)"
docker exec "$FTP" test -f /data/clientes21/olt-nova/depois.cfg; ficou_2=$?
r_l2="$(ftp_curl tls edit21 "$W/u21.senha" -l "$F/")"; ve_2="$(grep -c -E 'antes.cfg|depois.cfg' "$W/curl.out")"
[[ "$e_adm" == 303 && "$r_novo" == "303 /usuarios?m=criado" && "$r_f1" == 0 && "$p_antes" == /data/edit21/./ && "$e_usu" == 303 && "$s_antes" == "200 " \
  && "$lista" == "200 " && "$botao" == 1 && "$botao_ini" == 1 && "$tela" == "200 " && "$formulario" == 1 && "$atual" == 1 \
  && "$r_troca" == "303 /usuarios?m=pasta" && "$p_painel" == /data/clientes21/olt-nova/./ && "$d_nova" == "ftpdata:ftpdata 750 directory" && "$d_cima" == "ftpdata:ftpdata 750 directory" \
  && "$ficou" == 0 && "$r_l" == 0 && "$ve_antigo" == 0 && "$r_f2" == 0 && "$chegou" == 0 && "$resto_painel" == "$resto_antes" && "$s_depois" == "303 /entrar" \
  && "$aviso" == "200 " && "$n_aviso" -ge 1 && "$na_lista" == 1 && "$n_depois" == $((n_antes + 1)) && "$registro" == 1 && "$atividade" == "200 " && "$na_atividade" -ge 1 \
  && "$r_mu" == 0 && "$fala" == 1 && "$p_terminal" == /data/clientes21/olt-terminal/./ && "$d_terminal" == "ftpdata:ftpdata 750 directory" && "$resto_terminal" == "$resto_antes" \
  && "$ficou_2" == 0 && "$r_l2" == 0 && "$ve_2" == 0 ]]
caso $? testes 41 "Pasta do usuário trocada pelo painel e pelo terminal" "usuário edit21 criado pelo painel ($r_novo), pasta no cadastro: $p_antes, um arquivo enviado por FTPS (saída $r_f1) · botão Editar na lista: $botao para edit21 e $botao_ini para o usuário inicial · tela Editar: $tela, formulário da pasta: $formulario, pasta atual na tela: $atual · POST /usuarios/pasta para clientes21/olt-nova: $r_troca · cadastro: $p_painel · pasta criada: $d_nova, a de cima: $d_cima · o arquivo enviado antes $([[ "$ficou" == 0 ]] && echo 'continua na pasta anterior' || echo SUMIU) e $([[ "$ve_antigo" == 0 ]] && echo 'não aparece' || echo APARECE) no login seguinte (saída $r_l) · envio novo (saída $r_f2) $([[ "$chegou" == 0 ]] && echo 'cai na pasta nova' || echo 'NÃO caiu na pasta nova') · senha e demais campos do cadastro $([[ "$resto_painel" == "$resto_antes" ]] && echo inalterados || echo ALTERADOS) · sessão do usuário no painel, antes: $s_antes, depois: $s_depois · aviso na lista: $n_aviso, link da pasta nova: $na_lista · auditoria pasta_trocada: $n_antes → $n_depois, linha com o administrador, o usuário, a pasta nova e a anterior: $registro · aba Atividade: $na_atividade · manage-user.sh pasta edit21 clientes21/olt-terminal: saída $r_mu, avisa que os arquivos continuam na anterior: $fala · cadastro: $p_terminal · pasta: $d_terminal · senha e demais campos $([[ "$resto_terminal" == "$resto_antes" ]] && echo inalterados || echo ALTERADOS) · arquivo da pasta anterior $([[ "$ficou_2" == 0 ]] && echo preservado || echo SUMIU), arquivos de outras pastas à vista no login: $ve_2"

# ------------------------------------------------------------------ usuário inicial: senha e pasta pelo painel, sem remoção
soma_antes="$(somas)"; cp -p "$S/ftp-usuario-inicial-senha.txt" "$W/r21.segredo"; p_ini_antes="$(pasta21 "$USUARIO")"
tela="$(aba -b "$J" "$B/usuarios/senha?usuario=$USUARIO")"; nota="$(grep -c 'vale até o arquivo' "$W/corpo")"
r_senha="$(envio /usuarios/senha --data-urlencode "csrf=$K" --data-urlencode "usuario=$USUARIO" --data-urlencode "senha@$W/ini21.senha" --data-urlencode "confirmacao@$W/ini21.senha")"
l_painel="$(login21 "$USUARIO" "$W/ini21.senha")"; l_segredo="$(login21 "$USUARIO" "$W/inicial.senha")"
m_marca="$(modo21 senha-inicial.trocada)"; m_impressao="$(modo21 senha-inicial.aplicada)"
docker exec "$FTP" cat /auth/senha-inicial.aplicada /auth/senha-inicial.trocada > "$W/marcas21" 2>/dev/null
formato="$(head -1 "$W/marcas21" | grep -c -E '^\$6\$[A-Za-z0-9./]{1,16}\$[A-Za-z0-9./]{86}$')"; senha_em_claro="$(segredos_em "$W/marcas21")"; rm -f "$W/marcas21"
r_pasta="$(troca21 "$USUARIO" inicial21)"
s_1="$(subir21)"; mantida="$(docker logs "$FTP" 2>&1 | grep -c 'mantida a senha trocada pelo painel')"
l_painel_2="$(login21 "$USUARIO" "$W/ini21.senha")"; l_segredo_2="$(login21 "$USUARIO" "$W/inicial.senha")"; p_ini="$(pasta21 "$USUARIO")"
dep; r_dep=$?; painel_de_pe
resumo_trocada="$(grep -c -F "usuário '$USUARIO', senha trocada pelo painel (a do arquivo" "$W/deploy.log")"; resumo_arquivo="$(grep -c -F "usuário '$USUARIO', senha no arquivo" "$W/deploy.log")"
# O arquivo do segredo muda: na subida seguinte vale a senha dele, e a marca da troca pelo painel sai.
cat "$W/seg21.senha" > "$S/ftp-usuario-inicial-senha.txt"
s_2="$(subir21)"
l_novo_segredo="$(login21 "$USUARIO" "$W/seg21.senha")"; l_painel_3="$(login21 "$USUARIO" "$W/ini21.senha")"; m_marca_2="$(modo21 senha-inicial.trocada)"; p_ini_2="$(pasta21 "$USUARIO")"
cat "$W/r21.segredo" > "$S/ftp-usuario-inicial-senha.txt"; rm -f "$W/r21.segredo"
s_3="$(subir21)"
l_volta="$(login21 "$USUARIO" "$W/inicial.senha")"; l_saiu="$(login21 "$USUARIO" "$W/seg21.senha")"
r_pasta_volta="$(troca21 "$USUARIO" "$USUARIO")"; p_ini_3="$(pasta21 "$USUARIO")"
t_rem="$(aba -b "$J" "$B/usuarios/remover?usuario=$USUARIO")"
r_rem="$(envio /usuarios/remover --data-urlencode "csrf=$K" --data-urlencode "usuario=$USUARIO" --data-urlencode 'confirmar=sim')"
existe="$(usuarios_ftp | tr ' ' '\n' | grep -c -x -F "$USUARIO")"; r_outro="$(login21 edit21 "$W/u21.senha")"
[[ "$tela" == "200 " && "$nota" == 1 && "$r_senha" == "303 /usuarios?m=senha" && "$l_painel" == "0 226" && "$l_segredo" == "67 530" \
  && "$m_marca" == "root:root 600" && "$m_impressao" == "root:root 600" && "$formato" == 1 && "$senha_em_claro" == 0 && "$r_pasta" == "303 /usuarios?m=pasta" \
  && "$s_1" == "healthy " && "$mantida" -ge 1 && "$l_painel_2" == "0 226" && "$l_segredo_2" == "67 530" && "$p_ini" == /data/inicial21/./ \
  && "$r_dep" == 0 && "$resumo_trocada" == 1 && "$resumo_arquivo" == 0 \
  && "$s_2" == "healthy " && "$l_novo_segredo" == "0 226" && "$l_painel_3" == "67 530" && "$m_marca_2" == ausente && "$p_ini_2" == /data/inicial21/./ \
  && "$s_3" == "healthy " && "$l_volta" == "0 226" && "$l_saiu" == "67 530" && "$r_pasta_volta" == "303 /usuarios?m=pasta" && "$p_ini_3" == "$p_ini_antes" \
  && "$t_rem" == "409 " && "$r_rem" == "409 " && "$existe" == 1 && "$r_outro" == "0 226" && "$soma_antes" == "$(somas)" ]]
caso $? testes 42 "Usuário inicial: senha e pasta trocadas pelo painel, até o segredo mudar" "tela Trocar senha do usuário inicial: $tela, com a nota de até quando vale: $nota · POST /usuarios/senha: $r_senha · login com a senha do painel: $l_painel · com a do segredo: $l_segredo · marca da troca em /auth: $m_marca · impressão do segredo aplicado: $m_impressao, no formato sha512-crypt com sal: $formato, senhas em claro nos dois arquivos: $senha_em_claro · POST /usuarios/pasta para inicial21: $r_pasta · reinício do serviço ftp com o segredo igual: $s_1· linha 'mantida a senha trocada pelo painel' no log: $mantida · login com a do painel: $l_painel_2 · com a do segredo: $l_segredo_2 · pasta no cadastro: $p_ini · ./deploy.sh (saída $r_dep) com a linha 'senha trocada pelo painel' no resumo: $resumo_trocada, e a linha 'senha no arquivo': $resumo_arquivo · segredo alterado e novo reinício: $s_2· login com a senha nova do segredo: $l_novo_segredo · com a do painel: $l_painel_3 · marca da troca: $m_marca_2 · pasta mantida: $p_ini_2 · segredo de volta ao que era e novo reinício: $s_3· login com a de antes: $l_volta · com a que saiu: $l_saiu · pasta de volta pelo painel: $r_pasta_volta, cadastro: $p_ini_3 · remover o usuário inicial, tela: $t_rem· POST: $r_rem· continua no cadastro: $existe · outro usuário entra durante tudo: $r_outro · arquivos de segredo $([[ "$soma_antes" == "$(somas)" ]] && echo 'iguais aos do início' || echo DIFERENTES)"

# ------------------------------------------------------------------ troca de pasta que tenta sair, sem sessão e sem token
docker exec "$FTP" sh -c 'ln -s /auth /data/clientes21/atalho && printf x > /data/clientes21/arquivo.cfg'; r_ln=$?
antes="$(arvore21)"; cad_antes="$(cadastro21)"; auditoria; n_antes="$(eventos recusa_caminho)"; c_antes="$(eventos recusa_csrf)"; o_antes="$(eventos recusa_origem)"
ev=""; ok=0; longo="$(printf 'a%.0s' $(seq 1 65))"
for pasta in '..' '../auth' '/etc' '/data/edit21' '.oculta' 'a/b/c/d/e' 'clientes21/../..' 'clientes21//x' 'com espaço' 'ação' "$longo" ''; do
  r="$(troca21 edit21 "$pasta")"; [[ "$r" == "400 " ]] || ok=1; ev+="'${pasta:0:16}': $r; "
done
r_nulo="$(envio /usuarios/pasta --data "csrf=$K&usuario=edit21&pasta=a%00b")"; [[ "$r_nulo" == "400 " ]] || ok=1
r_link="$(troca21 edit21 clientes21/atalho/x)"; r_sobre_link="$(troca21 edit21 clientes21/atalho)"
r_arquivo="$(troca21 edit21 clientes21/arquivo.cfg)"; r_sob_arquivo="$(troca21 edit21 clientes21/arquivo.cfg/x)"
r_mesma="$(troca21 edit21 clientes21/olt-terminal)"; r_falta="$(troca21 nao-existe21 qualquer21)"; r_nome="$(troca21 '../edit21' qualquer21)"
campos=(--data-urlencode 'usuario=edit21' --data-urlencode 'pasta=fuga21')
r_sem="$(c -o /dev/null -w '%{http_code} %{redirect_url}' -H "Origin: $B" --data-urlencode "csrf=$K" "${campos[@]}" "$B/usuarios/pasta" | sed "s|$B||")"
r_falso="$(c -o /dev/null -w '%{http_code} %{redirect_url}' -b '__Host-sessao=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' -H "Origin: $B" --data-urlencode "csrf=$K" "${campos[@]}" "$B/usuarios/pasta" | sed "s|$B||")"
r_token="$(envio /usuarios/pasta "${campos[@]}")"
r_errado="$(envio /usuarios/pasta --data-urlencode 'csrf=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' "${campos[@]}")"
r_origem="$(c -o /dev/null -w '%{http_code}' -b "$J" -H 'Origin: https://site-de-fora.example' --data-urlencode "csrf=$K" "${campos[@]}" "$B/usuarios/pasta")"
r_get="$(aba -b "$J" "$B/usuarios/pasta?usuario=edit21&pasta=fuga21")"
# Com a sessão do próprio usuário do FTP: as rotas de edição não existem para ele.
e_usu="$(COMO=edit21 entrar "$U21" "$W/u21.senha")"; proibir "$(biscoito_de "$U21")"
UK="$(c -b "$U21" "$B/meus-arquivos" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1)"; proibir "$UK"
r_usu="$(POTE="$U21" envio /usuarios/pasta --data-urlencode "csrf=$UK" "${campos[@]}")"; r_usu_tela="$(aba -b "$U21" "$B/usuarios/editar?usuario=edit21")"
r_usu_senha="$(POTE="$U21" envio /usuarios/senha --data-urlencode "csrf=$UK" --data-urlencode 'usuario=edit21' --data-urlencode "senha@$W/ini21.senha" --data-urlencode "confirmacao@$W/ini21.senha")"
mu pasta edit21 "" ../fora21; t_1=$?; f_1="$(grep -c '^Pasta invalida' "$W/mu.log")"
mu pasta nao-existe21 "" qualquer21; t_2=$?; f_2="$(grep -c '^Usuario nao existe: nao-existe21' "$W/mu.log")"
mu pasta edit21 "" clientes21/atalho/x; t_3=$?; f_3="$(grep -c '^Pasta recusada: /data/clientes21/atalho e link simbolico' "$W/mu.log")"
mu pasta edit21; t_4=$?
auditoria; n_depois="$(eventos recusa_caminho)"; c_depois="$(eventos recusa_csrf)"; o_depois="$(eventos recusa_origem)"; depois="$(arvore21)"; cad_depois="$(cadastro21)"
l_fim="$(login21 edit21 "$W/u21.senha")"
[[ "$r_ln" == 0 && "$r_link" == "400 " && "$r_sobre_link" == "400 " && "$r_arquivo" == "400 " && "$r_sob_arquivo" == "400 " && "$r_mesma" == "409 " && "$r_falta" == "404 " && "$r_nome" == "404 " \
  && "$r_sem" == "303 /entrar" && "$r_falso" == "303 /entrar" && "$r_token" == "403 " && "$r_errado" == "403 " && "$r_origem" == 403 && "$r_get" == "404 " \
  && "$e_usu" == 303 && -n "$UK" && "$r_usu" == "404 " && "$r_usu_tela" == "404 " && "$r_usu_senha" == "404 " \
  && "$t_1" != 0 && "$f_1" == 1 && "$t_2" != 0 && "$f_2" == 1 && "$t_3" != 0 && "$f_3" == 1 && "$t_4" != 0 \
  && "$antes" == "$depois" && "$cad_antes" == "$cad_depois" && "$n_depois" -gt "$n_antes" && "$c_depois" -gt "$c_antes" && "$o_depois" -gt "$o_antes" && "$l_fim" == "0 226" ]] || ok=1
caso $ok seguranca 81 "Troca de pasta não sai da pasta dos dados nem age sem sessão" "com sessão e token válidos, pasta recusada: ${ev}com byte nulo: $r_nulo· por dentro de um link simbólico para /auth: $r_link· o próprio link: $r_sobre_link· nome de um arquivo: $r_arquivo· por dentro de um arquivo: $r_sob_arquivo· a pasta que o usuário já tem: $r_mesma· usuário que não existe: $r_falta· nome de usuário com ../: $r_nome· POST /usuarios/pasta sem cookie: $r_sem · com cookie de sessão inventado: $r_falso · com sessão e sem o token: $r_token· com token errado: $r_errado· com o token certo e Origin de fora: $r_origem · GET no mesmo endereço: $r_get(só POST existe) · com a sessão do próprio usuário do FTP (entrada $e_usu), trocar a pasta: $r_usu· abrir a tela Editar: $r_usu_tela· trocar a senha: $r_usu_senha· pelo terminal, pasta com ../: saída $t_1 (mensagem: $f_1), usuário que não existe: saída $t_2 (mensagem: $f_2), por dentro do link: saída $t_3 (mensagem: $f_3), sem a pasta: saída $t_4 · pastas dos dados e do cadastro $([[ "$antes" == "$depois" ]] && echo inalteradas || echo ALTERADAS) · arquivo do cadastro $([[ "$cad_antes" == "$cad_depois" ]] && echo inalterado || echo ALTERADO) · recusa_caminho na auditoria: $n_antes → $n_depois · recusa_csrf: $c_antes → $c_depois · recusa_origem: $o_antes → $o_depois · o usuário continua entrando no FTP: $l_fim"
