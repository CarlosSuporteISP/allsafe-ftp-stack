#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa T: método HEAD (RFC 9110, seção 9.3.2). O painel responde ao HEAD com o código e os cabeçalhos do GET,
# sem o corpo: nas telas, no security.txt, no download do administrador e no do usuário do FTP. O HEAD de um
# arquivo não baixa nada: não ocupa vaga de download nem entra na auditoria.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel zera a contagem de falhas de entrada e das recusas e encerra as sessões.
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"

U20="$W/u20.jar"; A20="$B/arquivos/baixar?arquivo=equip20/h20.bin"; M20="$B/meus-arquivos/baixar?arquivo=h20.bin"
cab20() { grep -i "^$2:" "$1" | tr -d '\r' | cut -d ' ' -f 2-; }   # <arquivo de cabeçalhos> <cabeçalho>
soma20() { sha256sum < "$1" 2>/dev/null | cut -c1-64; }
ev=""; diferentes=0
par() { # <rótulo> [opções do curl...] <endereço>: o HEAD tem de trazer o código e os cabeçalhos do GET, e nenhum corpo
  local rotulo="$1" g h nome falta=""; shift
  g="$(c -D "$W/h20.g" -o "$W/h20.corpo" -w '%{http_code}' "$@")"
  h="$(c --head -D "$W/h20.h" -o /dev/null -w '%{http_code} %{size_download}' "$@")"
  for nome in content-type content-length location content-disposition; do
    [[ "$(cab20 "$W/h20.g" "$nome")" == "$(cab20 "$W/h20.h" "$nome")" ]] || falta+=" $nome"
  done
  for nome in content-security-policy x-content-type-options strict-transport-security x-frame-options; do
    [[ -n "$(cab20 "$W/h20.h" "$nome")" ]] || falta+=" $nome"
  done
  [[ "$h" == "$g 0" && -z "$falta" && "$(cab20 "$W/h20.g" content-length)" == "$(wc -c < "$W/h20.corpo")" ]] || diferentes=$((diferentes + 1))
  ev+="$rotulo: GET $g com $(wc -c < "$W/h20.corpo") bytes, HEAD ${h% *} com ${h#* } bytes e Content-Length $(cab20 "$W/h20.h" content-length)${falta:+, cabeçalhos diferentes ou ausentes:$falta}; "
}

nova_senha "$W/u20.senha"; mu add equip20 "$W/u20.senha"; r_mu=$?
head -c 70000 /dev/urandom > "$W/h20.bin"
r_ftp="$(ftp_curl tls equip20 "$W/u20.senha" -T "$W/h20.bin" "$F/h20.bin")"
e_usu="$(COMO=equip20 entrar "$U20" "$W/u20.senha")"; proibir "$(biscoito_de "$U20")"

# ------------------------------------------------------------------ o HEAD traz o que o GET traria, sem o corpo
par "sem sessão, /entrar" "$B/entrar"
par "sem sessão, /" "$B/"
par "sem sessão, /.well-known/security.txt" "$B/.well-known/security.txt"
par "administrador, /usuarios/novo" -b "$J" "$B/usuarios/novo"
par "administrador, /arquivos?pasta=equip20" -b "$J" "$B/arquivos?pasta=equip20"
par "administrador, endereço que não existe" -b "$J" "$B/nao-existe"
par "administrador, arquivo que não existe" -b "$J" "$B/arquivos/baixar?arquivo=equip20/nao-existe.bin"
par "usuário do FTP, /" -b "$U20" "$B/"
par "usuário do FTP, /meus-arquivos" -b "$U20" "$B/meus-arquivos"
par "usuário do FTP, /usuarios" -b "$U20" "$B/usuarios"
r_sem="$(c --head -D "$W/h20.h" -o /dev/null -w '%{http_code}' "$B/usuarios")"; destino_sem="$(cab20 "$W/h20.h" location)"

# ------------------------------------------------------------------ HEAD de um arquivo: só os cabeçalhos
auditoria; b_antes="$(eventos arquivo_baixado)"; i_antes="$(eventos arquivo_interrompido)"
par "administrador, download" -b "$J" "$A20"; disposicao="$(cab20 "$W/h20.h" content-disposition)"; tamanho="$(cab20 "$W/h20.h" content-length)"
soma_adm="$(soma20 "$W/h20.corpo")"
par "usuário do FTP, download" -b "$U20" "$M20"; soma_usu="$(soma20 "$W/h20.corpo")"
auditoria; b_pares="$(eventos arquivo_baixado)"
# Mais HEAD do que vagas de download (8 no painel, 2 por usuário): se o HEAD ocupasse vaga, o GET seguinte daria 503.
for _ in $(seq 1 12); do c --head -b "$J" -o /dev/null "$A20"; done
for _ in 1 2 3 4; do c --head -b "$U20" -o /dev/null "$M20"; done
r_adm="$(c -b "$J" -o "$W/h20.adm" -w '%{http_code}' "$A20")"; r_usu="$(c -b "$U20" -o "$W/h20.usu" -w '%{http_code}' "$M20")"
auditoria; b_depois="$(eventos arquivo_baixado)"; i_depois="$(eventos arquivo_interrompido)"

# ------------------------------------------------------------------ pedido cru, registro e os outros métodos
{ printf 'HEAD /entrar HTTP/1.1\r\nHost: %s\r\nConnection: close\r\n\r\n' "$IP:$PAINEL_PORTA"; sleep 2; } \
  | timeout 30 openssl s_client -quiet -connect "$IP:$PAINEL_PORTA" 2> /dev/null > "$W/h20.cru"
cru="$(head -1 "$W/h20.cru" | tr -d '\r')"; sobra="$(awk 'f { n += length($0) + 1 } /^\r$/ { f = 1 } END { print n + 0 }' "$W/h20.cru")"
no_log="$(docker logs "$PAINEL" 2>&1 | grep -c ' HEAD /arquivos/baixar 200 0/70000 bytes')"
r_opt="$(c -X OPTIONS -o /dev/null -w '%{http_code}' "$B/entrar")"
s_todos="$(saude "$FTP" "$PAINEL" "$NGINX")"
[[ "$e_adm" == 303 && "$r_mu" == 0 && "$r_ftp" == 0 && "$e_usu" == 303 && "$diferentes" == 0 && "$r_sem" == 303 && "$destino_sem" == /entrar \
  && "$tamanho" == 70000 && "$disposicao" == 'attachment; filename="h20.bin"; filename*=UTF-8'"''"'h20.bin' \
  && "$soma_adm" == "$(soma20 "$W/h20.bin")" && "$soma_usu" == "$soma_adm" && "$b_pares" == $((b_antes + 2)) \
  && "$r_adm" == 200 && "$r_usu" == 200 && "$(soma20 "$W/h20.adm")" == "$soma_adm" && "$(soma20 "$W/h20.usu")" == "$soma_adm" \
  && "$b_depois" == $((b_antes + 4)) && "$i_depois" == "$i_antes" && "$cru" == 'HTTP/1.1 200 OK' && "$sobra" == 0 && "$no_log" -ge 13 \
  && "$r_opt" =~ ^(4[0-9][0-9]|501)$ && "$s_todos" == "healthy healthy healthy " ]]
caso $? testes 40 "HEAD responde como o GET, sem o corpo" "GET e HEAD do mesmo endereço, comparados no código, em Content-Type, Content-Length, Location e Content-Disposition, com os cabeçalhos de segurança no HEAD: $ev· endereços com diferença: $diferentes · HEAD /usuarios sem sessão: $r_sem para $destino_sem · arquivo de 70000 bytes: HEAD com Content-Length $tamanho e $disposicao · 12 HEAD seguidos do administrador e 4 do usuário do FTP, mais do que as vagas de download, e o GET em seguida: $r_adm e $r_usu, iguais ao enviado: $([[ "$(soma20 "$W/h20.adm")" == "$soma_adm" && "$(soma20 "$W/h20.usu")" == "$soma_adm" ]] && echo sim || echo NÃO) · eventos arquivo_baixado na auditoria: $b_antes antes, $b_depois depois dos 4 GET, nenhum pelos 18 HEAD; arquivo_interrompido: $i_antes antes, $i_depois depois · registro do painel com HEAD /arquivos/baixar 200 0/70000 bytes: $no_log linhas · pedido cru HEAD /entrar: $cru, $sobra bytes depois dos cabeçalhos · OPTIONS /entrar: $r_opt · saúde: $s_todos"

# ------------------------------------------------------------------ como a etapa deixa a instância
docker exec "$FTP" rm -f /data/equip20/h20.bin
mu del equip20
rm -f "$W"/h20.* "$W"/u20.*
unset -f cab20 soma20 par
