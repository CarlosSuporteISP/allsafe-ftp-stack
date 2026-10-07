#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa Y: HTTP/2 e compressão na frente web. O nginx fala HTTP/2 com o navegador que pede e HTTP/1.1 com
# quem não pede, entrega o estilo já comprimido a quem aceita gzip e mantém a conexão parada por um minuto.
# E o que isso não pode abrir: página com token comprimida, a cópia .gz entregue pelo nome, limite de pedidos
# e de tamanho valendo em um protocolo só, TLS antigo de volta.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel zera a contagem de falhas de entrada e das recusas e encerra as sessões.
dc restart painel > /dev/null 2>&1; painel_de_pe; sleep 3

# O curl não reescreve o arquivo do corpo quando a resposta vem sem corpo (304): ele é esvaziado antes de cada pedido.
pede25() { : > "$W/h2.corpo"; c -D "$W/h2.cab" -o "$W/h2.corpo" -w '%{http_code} %{http_version}' "$@"; }  # [opções do curl...] <endereço> → "código versão"
cab25() { grep -i "^$1:" "$W/h2.cab" | tr -d '\r' | cut -d ' ' -f 2- | paste -s -d ','; }  # <nome>: valor do cabeçalho na última resposta
faltando25() { # cabeçalhos de segurança que a última resposta não trouxe
  local falta="" cabecalho
  for cabecalho in 'content-security-policy:' 'x-content-type-options: nosniff' 'strict-transport-security:' 'x-frame-options: DENY'; do
    grep -q -i "^$cabecalho" "$W/h2.cab" || falta+=" $cabecalho"
  done
  echo "${falta:- nenhum}"
}
alpn25() { # <protocolos oferecidos>: o que o nginx escolhe no aperto de mão do TLS
  local saida; saida="$(openssl s_client -connect "$IP:$PAINEL_PORTA" -alpn "$1" < /dev/null 2>&1 || true)"
  grep -a -o -m1 -E 'ALPN protocol: [a-z0-9/.]+|No ALPN negotiated' <<< "$saida" || echo "sem resposta"
}
reinicios25() { docker inspect -f '{{.RestartCount}}' "$FTP" "$PAINEL" "$NGINX" 2>/dev/null | tr '\n' ' '; }
em_uso25() { docker exec "$NGINX" grep -c -E "^ *$1\$" /run/nginx/nginx.conf 2>/dev/null || true; }  # <diretiva>: linhas na configuração em uso
REINICIOS25="$(reinicios25)"

# ------------------------------------------------------------------ os dois protocolos, com a mesma sessão
a_h2="$(alpn25 h2,http/1.1)"; a_h1="$(alpn25 http/1.1)"
r_2="$(pede25 --http2 "$B/entrar")"; falta_2="$(faltando25)"
r_1="$(pede25 --http1.1 "$B/entrar")"; falta_1="$(faltando25)"
e_adm="$(entrar "$J" "$W/painel.senha" --http2)"; proibir "$(biscoito_de "$J")"
u_2="$(pede25 --http2 -b "$J" "$B/usuarios")"; u_1="$(pede25 --http1.1 -b "$J" "$B/usuarios")"
s_2="$(pede25 --http2 "$B/saude")"; s_1="$(pede25 --http1.1 "$B/saude")"

# ------------------------------------------------------------------ o estilo: inteiro para quem não pede, comprimido para quem aceita gzip
r_plano="$(pede25 --http2 "$B/estilo.css")"; enc_plano="$(cab25 content-encoding)"; etag_plano="$(cab25 etag)"; vary_plano="$(cab25 vary)"
tam_plano="$(wc -c < "$W/h2.corpo")"; igual_plano=NÃO; cmp -s web/estilo.css "$W/h2.corpo" && igual_plano=sim
ev_gz=""; ok_gz=0
for modo in --http2 --http1.1; do
  r_gz="$(pede25 "$modo" -H 'Accept-Encoding: gzip, deflate, br, zstd' "$B/estilo.css")"; enc_gz="$(cab25 content-encoding)"; etag_gz="$(cab25 etag)"
  vary_gz="$(cab25 vary)"; tipo_gz="$(cab25 content-type)"; cache_gz="$(cab25 cache-control)"; falta_gz="$(faltando25)"; tam_gz="$(wc -c < "$W/h2.corpo")"
  igual_gz=NÃO; gunzip -c "$W/h2.corpo" 2> /dev/null | cmp -s web/estilo.css - && igual_gz=sim
  r_304="$(pede25 "$modo" -H 'Accept-Encoding: gzip' -H "If-None-Match: $etag_gz" "$B/estilo.css")"; tam_304="$(wc -c < "$W/h2.corpo")"
  [[ "$r_gz" == "200 ${modo#--http}" && "$enc_gz" == gzip && "$etag_gz" == \"*\" && "$etag_gz" != "$etag_plano" && "$vary_gz" == Accept-Encoding && "$tipo_gz" == text/css \
    && "$cache_gz" == no-cache && "$falta_gz" == " nenhum" && "$igual_gz" == sim && $((tam_gz * 2)) -lt "$tam_plano" && "$r_304" == "304 ${modo#--http}" && "$tam_304" == 0 ]] || ok_gz=1
  ev_gz+="HTTP/${modo#--http}: $r_gz, Content-Encoding: ${enc_gz:-ausente}, $tam_gz bytes, descomprimido igual ao do projeto: $igual_gz, $tipo_gz, Vary: ${vary_gz:-ausente}, Cache-Control: ${cache_gz:-ausente}, ETag forte: $([[ "$etag_gz" == \"*\" ]] && echo sim || echo NÃO), cabeçalhos de segurança faltando:$falta_gz, revalidação com If-None-Match: $r_304 com $tam_304 bytes; "
done
ev_ae=""; ok_ae=0
while IFS='|' read -r aceita esperado; do
  pede25 -H "Accept-Encoding: $aceita" "$B/estilo.css" > /dev/null; veio="$(cab25 content-encoding)"
  [[ "${veio:-nenhuma}" == "$esperado" ]] || ok_ae=1
  ev_ae+="[$aceita] ${veio:-nenhuma}; "
done <<'ACEITA'
br|nenhuma
deflate|nenhuma
gzip;q=0|nenhuma
identity|nenhuma
br, gzip|gzip
ACEITA
dono="$(docker exec "$NGINX" stat -c '%U:%G %a' /usr/share/allsafe-nginx/web/estilo.css.gz 2>/dev/null)"

# ------------------------------------------------------------------ uma conexão para a tela inteira, e a conexão parada
saidas=(); for endereco in /entrar /estilo.css /marca/logo-320.png /marca/icone-32.png /favicon.ico; do saidas+=(-o /dev/null "$B$endereco"); done
sleep 1; curl -sk --max-time 20 --http2 --parallel --parallel-max 6 -w '%{http_code} %{http_version} %{num_connects}\n' "${saidas[@]}" > "$W/h2.tela" 2> /dev/null
t_certas="$(grep -c '^200 2 ' "$W/h2.tela")"; t_conexoes="$(awk '{s += $3} END {print s + 0}' "$W/h2.tela")"
# --rate 3/m espaça os dois pedidos do mesmo processo em 20 s; conexões abertas pelo segundo: 0 = a mesma do primeiro.
curl -sk --max-time 30 --http2 --rate 3/m -o /dev/null -o /dev/null -w '%{num_connects} %{http_code}\n' "$B/entrar" "$B/entrar" > "$W/h2.parada" 2> /dev/null
parada="$(sed -n 2p "$W/h2.parada")"
c_h2="$(em_uso25 'http2 on;')"; c_fluxos="$(em_uso25 'http2_max_concurrent_streams 16;')"; c_parada="$(em_uso25 'keepalive_timeout 60s;')"
c_pronta="$(em_uso25 'gzip_static on;')"; c_na_hora="$(em_uso25 'gzip on;')"
s_todos="$(saude "$FTP" "$PAINEL" "$NGINX")"

[[ "$a_h2" == "ALPN protocol: h2" && "$a_h1" == "ALPN protocol: http/1.1" && "$r_2" == "200 2" && "$r_1" == "200 1.1" && "$falta_2" == " nenhum" && "$falta_1" == " nenhum" \
  && "$e_adm" == 303 && "$u_2" == "200 2" && "$u_1" == "200 1.1" && "$s_2" == "200 2" && "$s_1" == "200 1.1" \
  && "$r_plano" == "200 2" && -z "$enc_plano" && "$etag_plano" == \"*\" && "$vary_plano" == Accept-Encoding && "$igual_plano" == sim && "$ok_gz" == 0 && "$ok_ae" == 0 \
  && "$dono" == "root:root 644" && "$t_certas" == 5 && "$t_conexoes" == 1 && "$parada" == "0 200" \
  && "$c_h2" == 1 && "$c_fluxos" == 1 && "$c_parada" == 1 && "$c_pronta" == 1 && "$c_na_hora" == 0 && "$s_todos" == "healthy healthy healthy " ]]
caso $? testes 50 "HTTP/2 no painel, estilo comprimido e conexão mantida" "aperto de mão do TLS oferecendo h2 e http/1.1: $a_h2; oferecendo só http/1.1: $a_h1 · GET /entrar (código e versão do HTTP): pedindo HTTP/2 $r_2, cabeçalhos de segurança faltando:$falta_2; pedindo HTTP/1.1 $r_1, faltando:$falta_1 · entrada do administrador por HTTP/2: $e_adm; a mesma sessão em /usuarios: $u_2 e $u_1 · /saude: $s_2 e $s_1 · /estilo.css sem pedir compressão: $r_plano, Content-Encoding: ${enc_plano:-ausente}, $tam_plano bytes, igual ao do projeto: $igual_plano, Vary: ${vary_plano:-ausente} · aceitando gzip: $ev_gz· o que o navegador aceita e a compressão que recebe: $ev_ae· cópia comprimida na imagem do nginx, dono e modo: $dono · tela de entrada inteira (página, estilo e três imagens ao mesmo tempo) por HTTP/2: $t_certas de 5 com 200, em $t_conexoes conexão · segundo pedido do mesmo cliente depois de 20 s parado (conexões novas e código): $parada · na configuração em uso: http2 on $c_h2, http2_max_concurrent_streams 16 $c_fluxos, keepalive_timeout 60s $c_parada, gzip_static on $c_pronta (só no estilo), gzip on $c_na_hora · saúde: $s_todos"

# ------------------------------------------------------------------ o que não é comprimido, nos dois protocolos
ev=""; ok=0
inteira() { # <código esperado> <rótulo> <opções do curl e endereço...>: mesmo aceitando toda compressão, a resposta vem sem Content-Encoding
  local esperado="$1" rotulo="$2" modo r enc bytes; shift 2
  for modo in --http2 --http1.1; do
    r="$(pede25 "$modo" -H 'Accept-Encoding: gzip, deflate, br, zstd' "$@")"; enc="$(cab25 content-encoding)"; bytes="$(head -c 2 "$W/h2.corpo" | od -An -tx1 | tr -d ' \n')"
    [[ "$r" == "$esperado ${modo#--http}" && -z "$enc" && "$bytes" != 1f8b ]] || ok=1
    ev+="$rotulo (HTTP/${modo#--http}): ${r%% *}, ${enc:-sem compressão}; "
  done
}
inteira 200 'tela de entrada, com o token do formulário' "$B/entrar"
inteira 200 'aba Usuários, com a sessão' -b "$J" "$B/usuarios"
inteira 200 'formulário de usuário novo, com o token' -b "$J" "$B/usuarios/novo"
inteira 200 'aba Segurança' -b "$J" "$B/seguranca"
inteira 404 'endereço que não existe, com a sessão' -b "$J" "$B/nao-existe-25"
inteira 200 'robots.txt' "$B/robots.txt"
inteira 200 'ícone' "$B/favicon.ico"
inteira 200 'logo' "$B/marca/logo-320.png"
inteira 200 'saúde' "$B/saude"
com_token="$(c --http2 -H 'Accept-Encoding: gzip, deflate, br, zstd' "$B/entrar" | grep -c 'name="token" value="')"

# ------------------------------------------------------------------ a cópia comprimida não tem endereço
ev_n=""
nega25() { # <rótulo> <opções do curl e endereço...>: a resposta não pode ser 200 nem trazer um arquivo gzip
  local rotulo="$1" r bytes; shift
  r="$(pede25 --path-as-is -H 'Accept-Encoding: gzip' "$@")"; bytes="$(head -c 2 "$W/h2.corpo" | od -An -tx1 | tr -d ' \n')"
  [[ "${r%% *}" != 200 && "$bytes" != 1f8b ]] || ok=1
  ev_n+="$rotulo: ${r%% *}; "
}
nega25 'cópia comprimida pelo nome' "$B/estilo.css.gz"
nega25 'a mesma, com a sessão do administrador' -b "$J" "$B/estilo.css.gz"
nega25 'pela pasta da marca' "$B/marca/estilo.css.gz"
nega25 'subindo da pasta da marca' "$B/marca/../estilo.css.gz"
nega25 'estilo com barra no fim' "$B/estilo.css/"
nega25 'estilo em maiúsculas' "$B/ESTILO.CSS"
nega25 'byte nulo' "$B/estilo.css%00.gz"
nega25 'cópia do robots.txt' "$B/robots.txt.gz"
nega25 'envio no lugar do estilo' -X POST --data 'x=1' "$B/estilo.css"

# ------------------------------------------------------------------ os limites valem nos dois protocolos
# Campo do pedido (endereço ou cabeçalho): 5k como chega em HTTP/1.1 e 5k comprimido em HTTP/2, onde a letra "a" é
# das que mais comprimem (5 bits). 8300 letras "a" não cabem em nenhum dos dois; 4000 cabem nos dois.
head -c 100000 /dev/zero | tr '\0' a > "$W/h2.grande"; campo_grande="$(head -c 8300 /dev/zero | tr '\0' a)"; campo_normal="$(head -c 4000 /dev/zero | tr '\0' a)"
varios=(); for i in 1 2 3 4 5; do varios+=(-H "X-Campo$i: ${campo_normal}${campo_normal:0:500}"); done
campo25() { # <modo> <opções do curl e endereço...> → código; "fechada" = o nginx encerrou a conexão HTTP/2 sem atender (saída 16 do curl)
  local r s; r="$(c "$@" -o /dev/null -w '%{http_code}')"; s=$?
  [[ "$1" == --http2 && "$r" == 000 && "$s" == 16 ]] && r=fechada
  echo "$r"
}
c_campo="$(em_uso25 'large_client_header_buffers 4 5k;')"
ev_l=""
for modo in --http2 --http1.1; do
  r_corpo="$(c "$modo" -o /dev/null -w '%{http_code}' -H "Origin: $B" --data-binary "@$W/h2.grande" "$B/entrar")"
  r_cab="$(campo25 "$modo" -H "X-Grande: $campo_grande" "$B/entrar")"; r_end="$(campo25 "$modo" "$B/entrar?x=$campo_grande")"; r_soma="$(campo25 "$modo" "${varios[@]}" "$B/entrar")"
  r_cab_normal="$(campo25 "$modo" -H "X-Normal: $campo_normal" "$B/entrar")"; r_end_normal="$(campo25 "$modo" "$B/entrar?x=$campo_normal")"
  # Rajada de um só endereço: em HTTP/2, os pedidos vão juntos pela mesma conexão; em HTTP/1.1, uma conexão por pedido.
  junto=(--parallel-immediate); [[ "$modo" == --http2 ]] && junto=()
  sleep 4; curl -sk --max-time 40 "$modo" --parallel "${junto[@]}" --parallel-max 40 -o /dev/null -w '%{http_code} %{http_version} %{num_connects}\n' "$B/entrar?n=[1-300]" 2> /dev/null > "$W/h2.rajada"
  n200="$(grep -c "^200 ${modo#--http} " "$W/h2.rajada")"; n429="$(grep -c "^429 ${modo#--http} " "$W/h2.rajada")"; conexoes="$(awk '{s += $3} END {print s + 0}' "$W/h2.rajada")"
  sleep 4; r_depois="$(c "$modo" -o /dev/null -w '%{http_code}' "$B/entrar")"
  [[ "$r_corpo" == 413 && "$r_cab" =~ ^(4[0-9][0-9]|fechada)$ && "$r_end" =~ ^(4[0-9][0-9]|fechada)$ && "$r_soma" =~ ^(4[0-9][0-9]|fechada)$ \
    && "$r_cab_normal" == 200 && "$r_end_normal" == 200 && "$n200" -ge 1 && "$n429" -ge 1 && $((n200 + n429)) == 300 && "$r_depois" == 200 ]] || ok=1
  ev_l+="HTTP/${modo#--http}: envio de 100000 bytes: $r_corpo; cabeçalho de 8300 bytes: $r_cab; endereço de 8300 bytes: $r_end; cinco cabeçalhos de 4500 bytes: $r_soma; cabeçalho de 4000 bytes: $r_cab_normal; endereço de 4000 bytes: $r_end_normal; 300 pedidos a /entrar, 40 ao mesmo tempo, em $conexoes conexões: $n200 atendidos (200) e $n429 recusados (429); 4 s depois: $r_depois; "
done
sem_tls="$(curl -s --max-time 10 --http2-prior-knowledge -o /dev/null -w '%{http_code}' "http://$IP:$PAINEL_PORTA/entrar")"
a_outro="$(alpn25 spdy/3)"; t_10="$(tls_painel tls1)"; t_11="$(tls_painel tls1_1)"; t_12="$(tls_painel tls1_2)"; t_13="$(tls_painel tls1_3)"
r_sessao="$(aba -b "$J" "$B/usuarios")"; s_fim="$(saude "$FTP" "$PAINEL" "$NGINX")"

[[ "$ok" == 0 && "$c_campo" == 1 && "$com_token" == 1 && "$sem_tls" != 200 && "$a_outro" == "No ALPN negotiated" && "$t_10" == recusado && "$t_11" == recusado \
  && "$t_12" == "New, TLSv1.2" && "$t_13" == "New, TLSv1.3" && "$r_sessao" == "200 " && "$s_fim" == "healthy healthy healthy " && "$REINICIOS25" == "$(reinicios25)" ]]
caso $? seguranca 87 "HTTP/2 e compressão não abrem nada: página com token inteira e limites nos dois protocolos" "aceitando gzip, deflate, br e zstd, nenhuma resposta além do estilo vem comprimida: $ev· tela de entrada pedida com compressão traz o token legível: $com_token · a cópia comprimida não tem endereço (nenhuma resposta pode ser 200 nem trazer arquivo gzip): $ev_n· limites: $ev_l· HTTP/2 sem TLS na porta do painel: $sem_tls · aperto de mão oferecendo só um protocolo que o nginx não fala (spdy/3): $a_outro · TLS 1.0: $t_10, TLS 1.1: $t_11, TLS 1.2: $t_12, TLS 1.3: $t_13 · sessão do administrador depois de tudo, em /usuarios: $r_sessao· saúde: $s_fim· reinícios antes e depois: $REINICIOS25/ $(reinicios25)"

rm -f "$W"/h2.*
