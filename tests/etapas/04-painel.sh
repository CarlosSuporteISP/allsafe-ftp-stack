#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa D: painel. Sessão, abas, CSRF, cabeçalhos, usuários pela web e auditoria.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

codigo="$(c -o "$W/corpo" -w '%{http_code}' "$B/saude")"
[[ "$codigo" == 200 && "$(tr -d '\n' < "$W/corpo")" == ok ]]; caso $? testes 11 "Saúde do painel" "GET /saude: $codigo, corpo: $(tr -d '\n' < "$W/corpo")"

ev=""; ok=0
for caminho in / /usuarios /administradores /seguranca /atividade; do
  r="$(aba "$B$caminho")"; [[ "$r" == "303 /entrar" && "$(grep -c -E '<table|name="csrf"' "$W/corpo")" == 0 ]] || ok=1
  ev+="GET $caminho: $r; "
done
caso $ok seguranca 22 "Aba sem sessão" "$ev nenhum dado da aba no corpo"

c -D "$W/cabecalhos" -o /dev/null "$B/entrar"; faltam=""
for cabecalho in 'content-security-policy:' 'x-frame-options:' 'x-content-type-options: nosniff' 'strict-transport-security:' 'cache-control: no-store'; do
  grep -q -i "^$cabecalho" "$W/cabecalhos" || faltam+=" $cabecalho"
done
[[ -z "$faltam" ]]; caso $? seguranca 29 "Cabeçalhos de segurança" "$(grep -i -E '^(x-frame-options|x-content-type-options|strict-transport-security|cache-control):' "$W/cabecalhos" | tr -d '\r' | tr '\n' ';') CSP: $(grep -c -i '^content-security-policy:' "$W/cabecalhos") · faltando:${faltam:- nenhum}"

# Arquivos estáticos (pasta web/): quem entrega é o nginx, sem sessão e sem passar pelo painel.
r="$(c -D "$W/estatico.cab" -o "$W/estatico.corpo" -w '%{http_code}' "$B/estilo.css")"; faltam=""
for cabecalho in 'content-type: text/css' 'content-security-policy:' 'x-content-type-options: nosniff' 'strict-transport-security:' 'etag:'; do
  grep -q -i "^$cabecalho" "$W/estatico.cab" || faltam+=" $cabecalho"
done
na_pagina="$(c "$B/entrar" | grep -c 'href="/estilo.css"')"
no_painel="$(docker exec "$PAINEL" find /opt /usr/share -name 'estilo.css' 2>/dev/null | wc -l)"
r_post="$(c -o /dev/null -w '%{http_code}' -X POST "$B/estilo.css")"; r_fora="$(c -o /dev/null -w '%{http_code}' "$B/estilo.css/../nginx.conf")"
[[ "$r" == 200 && -z "$faltam" && "$no_painel" == 0 && "$na_pagina" -ge 1 && "$r_post" != 200 && "$r_fora" != 200 ]] && cmp -s web/estilo.css "$W/estatico.corpo"
caso $? testes 20 "Arquivos estáticos pelo nginx" "GET /estilo.css sem sessão: $r, $(grep -i '^content-type:' "$W/estatico.cab" | tr -d '\r') · igual a web/estilo.css: $(cmp -s web/estilo.css "$W/estatico.corpo" && echo sim || echo NÃO) · cabeçalhos faltando:${faltam:- nenhum} · tela de entrada aponta para ele: $na_pagina · cópias dentro do container do painel: $no_painel · POST: $r_post · caminho com ../: $r_fora"

http="$(curl -s --max-time 6 -o "$W/puro" -w '%{http_code}' "http://$IP:$PAINEL_PORTA/entrar")"; form_http="$(grep -c 'name="senha"' "$W/puro" 2>/dev/null)"
https="$(c -o "$W/corpo" -w '%{http_code}' "$B/entrar")"; form_https="$(grep -c 'name="senha"' "$W/corpo")"
[[ "$http" != 200 && "${form_http:-0}" == 0 ]]; caso $? seguranca 30 "Sem HTTP" "HTTP puro na porta do painel: código $http, formulário de entrada no corpo: ${form_http:-0}"
[[ "$https" == 200 && "$form_https" == 1 && "$http" != 200 && "${form_http:-0}" == 0 ]]
caso $? rede 10 "Painel só em HTTPS" "https://: $https, com a tela de entrada · http://: $http, sem a tela de entrada"

t11="$(tls_painel tls1_1)"; t12="$(tls_painel tls1_2)"; t13="$(tls_painel tls1_3)"
[[ "$t11" == recusado && "$t12" == "New, TLSv1.2" && "$t13" == "New, TLSv1.3" ]]
caso $? seguranca 31 "TLS antigo" "TLS 1.0: $(tls_painel tls1) · TLS 1.1: $t11 · TLS 1.2: $t12 · TLS 1.3: $t13"

codigo="$(entrar "$J" "$W/painel.senha")"; destino_entrada="$(grep -i '^location:' "$W/entrada.cab" | tr -d '\r' | cut -d' ' -f2)"
biscoito="$(grep -i '^set-cookie:' "$W/entrada.cab" | tr -d '\r')"
proibir "$(awk '$6 == "__Host-sessao" {print $7}' "$J")"
K="$(csrf)"; proibir "$K"
geral="$(aba -b "$J" "$B/")"
[[ "$codigo" == 303 && "$destino_entrada" == / && "$geral" == "200 " ]] && grep -q '<h1[^>]*>Visão geral</h1>' "$W/corpo"
quem="$(sed -n 's/.*class="quem"[^>]*>\([^<]*\)<.*/\1/p' "$W/corpo" | head -1)"; auditoria
[[ "$quem" == "$ADMIN" && "$(eventos admin_inicial_criado)" == 1 ]] || false
caso $? testes 12 "Entrada" "POST /entrar com o usuário '$ADMIN' (PAINEL_ADMIN_USER) e a senha inicial: $codigo → $destino_entrada · GET / com a sessão: $geral· $(grep -o '<h1[^>]*>[^<]*</h1>' "$W/corpo" | head -1 | sed 's/<[^>]*>//g') · administrador mostrado no topo: ${quem:-nenhum} · admin_inicial_criado na auditoria: $(eventos admin_inicial_criado)"
ok=0; for atributo in '__Host-sessao=' 'Path=/' 'Secure' 'HttpOnly' 'SameSite=Strict'; do [[ "$biscoito" == *"$atributo"* ]] || ok=1; done
caso $ok seguranca 28 "Atributos do cookie" "$(sed -E 's/(__Host-sessao=)[^;]+/\1<REDACTED>/' <<< "$biscoito")"

no_ar="$(grep -c 'No ar' "$W/corpo")"; contagem="$(sed -n 's/.*Usuários<\/h2><p class="numero">\([0-9]*\)<.*/\1/p' "$W/corpo" | head -1)"
certificado="$(sed -n 's/.*Certificado do FTP<\/h2><p class="numero menor">\([^<]*\)<.*/\1/p' "$W/corpo" | head -1)"
reais="$(usuarios_ftp | wc -w)"
[[ "$no_ar" -ge 1 && -n "$contagem" && "$contagem" == "$reais" && -n "$certificado" ]]
caso $? testes 13 "Visão geral" "servidor FTP: $([[ "$no_ar" -ge 1 ]] && echo 'No ar' || echo 'FORA DO AR') · usuários na aba: ${contagem:-?}, no PureDB: $reais · certificado do FTP: ${certificado:-ausente}"
saudacao="$(docker exec "$PAINEL" python3 -c 'import socket; s = socket.create_connection(("ftp", 2121), 5); print(s.recv(200).decode(errors="replace").splitlines()[0][:60])' 2>&1 | head -1)"
[[ "$no_ar" -ge 1 && "$saudacao" == 220* && "$(docker port "$PAINEL" | wc -l)" == 0 ]]
caso $? rede 12 "Painel alcança o FTP pela rede interna" "visão geral: $([[ "$no_ar" -ge 1 ]] && echo 'No ar' || echo 'FORA DO AR') · de dentro do painel, ftp:2121 responde: $saudacao · portas publicadas pelo painel: $(docker port "$PAINEL" | wc -l)"

antes="$(usuarios_ftp)"
r="$(envio /usuarios/novo --data-urlencode 'usuario=invasor' --data-urlencode "senha@$W/u4.senha" --data-urlencode "confirmacao@$W/u4.senha")"
[[ "$r" == "403 " && "$antes" == "$(usuarios_ftp)" ]]; caso $? seguranca 25 "Envio sem token CSRF" "POST /usuarios/novo com sessão e sem o token: $r· usuários $([[ "$antes" == "$(usuarios_ftp)" ]] && echo inalterados || echo ALTERADOS)"
r="$(c -o /dev/null -w '%{http_code}' -b "$J" -H 'Origin: https://site-de-fora.example' --data-urlencode 'usuario=invasor' --data-urlencode "csrf=$K" --data-urlencode "senha@$W/u4.senha" --data-urlencode "confirmacao@$W/u4.senha" "$B/usuarios/novo")"
[[ "$r" == 403 && "$antes" == "$(usuarios_ftp)" ]]; caso $? seguranca 26 "Envio com Origin de fora" "POST com o token certo e Origin https://site-de-fora.example: $r · usuários $([[ "$antes" == "$(usuarios_ftp)" ]] && echo inalterados || echo ALTERADOS)"
# O navegador manda "Origin: null" quando o envio parte de outro endereço ou de página sem referência. A política
# same-origin faz o envio do próprio painel levar a origem real; com no-referrer, até ele chegaria como "null".
politica="$(grep -i '^referrer-policy:' "$W/cabecalhos" | tr -d '\r' | cut -d ' ' -f 2-)"
r="$(c -o /dev/null -w '%{http_code}' -b "$J" -H 'Origin: null' --data-urlencode 'usuario=invasor' --data-urlencode "csrf=$K" --data-urlencode "senha@$W/u4.senha" --data-urlencode "confirmacao@$W/u4.senha" "$B/usuarios/novo")"
[[ "$politica" == same-origin && "$r" == 403 && "$antes" == "$(usuarios_ftp)" ]]; caso $? seguranca 38 "Envio com Origin null" "Referrer-Policy da resposta: ${politica:-ausente} · POST com o token certo e Origin null: $r · usuários $([[ "$antes" == "$(usuarios_ftp)" ]] && echo inalterados || echo ALTERADOS)"
r="$(c -o /dev/null -w '%{http_code}' -b "$J" -H 'Host: painel.exemplo.com.br' "$B/")"
[[ "$r" == 400 ]]; caso $? seguranca 27 "Cabeçalho Host inesperado" "GET / com Host: painel.exemplo.com.br: $r"

ev=""; ok=0; pastas_antes="$(docker exec "$FTP" sh -c 'ls -A /data | wc -l')"
for nome in '../x' 'equip 01' 'equip;01' 'Equip01' '-equip'; do
  r="$(envio /usuarios/novo --data-urlencode "usuario=$nome" --data-urlencode "csrf=$K" --data-urlencode "senha@$W/u4.senha" --data-urlencode "confirmacao@$W/u4.senha")"
  [[ "$r" == "400 " ]] || ok=1; ev+="'$nome': $r; "
done
pastas_depois="$(docker exec "$FTP" sh -c 'ls -A /data | wc -l')"
[[ "$antes" == "$(usuarios_ftp)" && "$pastas_antes" == "$pastas_depois" ]] || ok=1
caso $ok seguranca 32 "Nome de usuário malicioso" "$ev usuários $([[ "$antes" == "$(usuarios_ftp)" ]] && echo inalterados || echo ALTERADOS) · pastas em /data: $pastas_depois (eram $pastas_antes)"
printf 'curta123' > "$W/curta.senha"
r="$(envio /usuarios/novo --data-urlencode 'usuario=equip05' --data-urlencode "csrf=$K" --data-urlencode "senha@$W/curta.senha" --data-urlencode "confirmacao@$W/curta.senha")"
[[ "$r" == "400 " && "$antes" == "$(usuarios_ftp)" ]]; caso $? seguranca 33 "Senha fraca no painel" "novo usuário com senha de 8 caracteres: $r· usuário criado: $([[ "$antes" == "$(usuarios_ftp)" ]] && echo não || echo SIM)"
r="$(head -c 20000 /dev/zero | tr '\0' a | c -o /dev/null -w '%{http_code}' -b "$J" -H "Origin: $B" --data-binary @- "$B/usuarios/novo")"
[[ "$r" == 413 ]]; caso $? seguranca 34 "Corpo grande demais" "POST de 20000 bytes (limite de 16 k no nginx): $r"

iniciado="$(docker inspect -f '{{.State.StartedAt}}' "$FTP")"
r="$(envio /usuarios/novo --data-urlencode 'usuario=equip04' --data-urlencode "csrf=$K" --data-urlencode "senha@$W/u4.senha" --data-urlencode "confirmacao@$W/u4.senha")"
r_login="$(ftp_curl tls equip04 "$W/u4.senha" "$F/")"; r_envio="$(ftp_curl tls equip04 "$W/u4.senha" -T "$W/envio.bin" "$F/painel.cfg")"
mesmo="$([[ "$iniciado" == "$(docker inspect -f '{{.State.StartedAt}}' "$FTP")" ]] && echo não || echo SIM)"
[[ "$r" == "303 /usuarios?m=criado" && "$r_login" == 0 && "$r_envio" == 0 && "$mesmo" == não ]]
caso $? testes 14 "Novo usuário pelo painel" "POST /usuarios/novo: $r · FTPS com o usuário novo: login $r_login, envio $r_envio · FTP reiniciado: $mesmo"
r="$(envio /usuarios/senha --data-urlencode 'usuario=equip04' --data-urlencode "csrf=$K" --data-urlencode "senha@$W/u5.senha" --data-urlencode "confirmacao@$W/u5.senha")"
r_velha="$(ftp_curl tls equip04 "$W/u4.senha" "$F/")"; r_nova="$(ftp_curl tls equip04 "$W/u5.senha" "$F/")"
[[ "$r" == "303 /usuarios?m=senha" && "$r_velha" == 67 && "$r_nova" == 0 ]]
caso $? testes 15 "Troca de senha pelo painel" "POST /usuarios/senha: $r · FTPS com a senha antiga: $r_velha (67 = recusado) · com a nova: $r_nova"
r="$(envio /usuarios/remover --data-urlencode 'usuario=equip04' --data-urlencode "csrf=$K" --data-urlencode 'confirmar=sim')"
r_login="$(ftp_curl tls equip04 "$W/u5.senha" "$F/")"; docker exec "$FTP" test -f /data/equip04/painel.cfg; pasta=$?
[[ "$r" == "303 /usuarios?m=removido" && "$r_login" == 67 && "$pasta" == 0 ]]
caso $? testes 16 "Remoção pelo painel" "POST /usuarios/remover: $r · FTPS depois: $r_login (67 = recusado) · arquivo na pasta: $([[ "$pasta" == 0 ]] && echo preservado || echo AUSENTE)"

r="$(aba -b "$J" "$B/atividade")"; ev=""; ok=0
for texto in 'Entrada' 'Usuário criado' 'Senha trocada' 'Usuário removido'; do
  n="$(grep -o "$texto" "$W/corpo" | wc -l)"; [[ "$n" -ge 1 ]] || ok=1; ev+="$texto: $n; "
done
# o token CSRF da própria sessão faz parte dos formulários da página: o que não pode aparecer é senha nem cookie
grep -v -x -F -e "$K" "$W/proibidos" > "$W/proibidos-pagina"
na_pagina="$(grep -c -a -F -f "$W/proibidos-pagina" "$W/corpo" || true)"
[[ "$r" == "200 " && "$na_pagina" == 0 ]] || ok=1
caso $ok testes 17 "Atividade" "GET /atividade: $r· $ev senhas ou cookie de sessão na página: $na_pagina"

r="$(envio /sair --data-urlencode "csrf=$K")"; depois="$(aba -b "$J" "$B/")"
[[ "$r" == "303 /entrar" && "$depois" == "303 /entrar" ]]
caso $? testes 18 "Saída" "POST /sair: $r · abrir a visão geral em seguida: $depois"
antes="$(usuarios_ftp)"
r2="$(envio /usuarios/novo --data-urlencode 'usuario=equip06' --data-urlencode "csrf=$K" --data-urlencode "senha@$W/u4.senha" --data-urlencode "confirmacao@$W/u4.senha")"
[[ "$depois" == "303 /entrar" && "$r2" == "303 /entrar" && "$antes" == "$(usuarios_ftp)" ]]
caso $? seguranca 37 "Sessão encerrada" "cookie antigo em GET /: $depois · em POST /usuarios/novo, com o token antigo: $r2 · usuário criado: $([[ "$antes" == "$(usuarios_ftp)" ]] && echo não || echo SIM)"

auditoria; f_antes="$(eventos entrada_falha)"
r="$(entrar "$W/errado.jar" "$W/errada.senha")"; aviso="$(sed -n 's/.*role="alert">\([^<]*\)<.*/\1/p' "$W/entrada.corpo" | head -1)"
auditoria; f_depois="$(eventos entrada_falha)"
[[ "$r" == 401 && "$f_depois" == $((f_antes + 1)) && "$aviso" != *enha* ]]
caso $? seguranca 23 "Senha errada" "POST /entrar com senha errada: $r · aviso na tela: $aviso · entrada_falha na auditoria: $f_antes → $f_depois"
ev=""; for _ in 2 3 4 5; do ev+="$(entrar "$W/errado.jar" "$W/errada.senha") "; done
sexta="$(entrar "$W/errado.jar" "$W/errada.senha")"; certa="$(entrar "$W/errado.jar" "$W/painel.senha")"
auditoria
[[ "$ev" == "401 401 401 401 " && "$sexta" == 429 && "$certa" == 429 && "$(eventos entrada_bloqueada)" -ge 2 ]]
caso $? seguranca 24 "Limite de tentativas" "2ª a 5ª senha errada: $ev· 6ª: $sexta · senha certa em seguida: $certa · entrada_bloqueada na auditoria: $(eventos entrada_bloqueada)"

docker logs "$FTP" > "$W/log-ftp" 2>&1; docker logs "$PAINEL" > "$W/log-painel" 2>&1; docker logs "$NGINX" > "$W/log-nginx" 2>&1
n_aud="$(segredos_em "$W/auditoria")"; n_logs=$(( $(segredos_em "$W/log-ftp") + $(segredos_em "$W/log-painel") + $(segredos_em "$W/log-nginx") ))
[[ -s "$W/auditoria" && "$n_aud" == 0 && "$n_logs" == 0 ]]
caso $? seguranca 36 "Auditoria sem segredo" "auditoria.log: $(grep -c . "$W/auditoria") linhas, $(grep -c . "$W/proibidos") valores procurados (senhas, hash, cookie e token), $n_aud ocorrências · logs dos três containers: $n_logs ocorrências"
