#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa L: aba Arquivos do painel. Navegação, download pelo navegador, fuga da pasta, link simbólico,
# entrega só como anexo e limite de downloads ao mesmo tempo.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# A etapa anterior termina com o endereço bloqueado pelo limite de tentativas: o reinício do painel
# tira o bloqueio e encerra as sessões; daqui em diante vale uma sessão nova do administrador inicial.
dc restart painel > /dev/null 2>&1; painel_de_pe
e_arq="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"

Q="$B/arquivos"; D="$B/arquivos/baixar?arquivo"
baixa() { c -b "$J" -D "$W/arq.cab" -o "$1" -w '%{http_code}' "$D=$2"; }   # <destino> <caminho já codificado> → código HTTP
cab() { grep -i "^$1:" "$W/arq.cab" | tr -d '\r' | cut -d ' ' -f 2-; }        # <cabeçalho> da última resposta do baixa
soma_de() { sha256sum < "$1" 2>/dev/null | cut -c1-64; }
vazou() { cat "$@" 2>/dev/null | grep -c -a -E 'root:|scrypt\$|\$[0-9a-z]+\$' || true; }  # linha de /etc/passwd, hash do painel ou do FTP

nova_senha "$W/u12.senha"; mu add equip12 "$W/u12.senha"
head -c $((40 * 1024 * 1024)) /dev/urandom > "$W/grande.bin"
printf '<!doctype html><script>alert(1)</script>\n' > "$W/pagina.html"
r_f1="$(ftp_curl tls equip12 "$W/u12.senha" -T "$W/envio.bin" "$F/arquivos.cfg")"
r_f2="$(ftp_curl tls equip12 "$W/u12.senha" --ftp-create-dirs -T "$W/envio.bin" "$F/diario/relat%C3%B3rio%20final.cfg")"
r_f3="$(ftp_curl tls equip12 "$W/u12.senha" -T "$W/grande.bin" "$F/grande.bin")"
r_f4="$(ftp_curl tls equip12 "$W/u12.senha" -T "$W/pagina.html" "$F/pagina.html")"
soma_envio="$(soma_de "$W/envio.bin")"; soma_grande="$(soma_de "$W/grande.bin")"

# ------------------------------------------------------------------ navegação e download
auditoria; n_antes="$(eventos arquivo_baixado)"
raiz="$(aba -b "$J" "$Q")"; na_raiz="$(grep -c 'href="/arquivos?pasta=equip12"' "$W/corpo")"; menu="$(grep -c '<a href="/arquivos"[^>]*><svg[^>]*><use href="#i-pasta"/></svg>Arquivos</a>' "$W/corpo")"
pasta="$(aba -b "$J" "$Q?pasta=equip12")"; no_link="$(grep -c 'href="/arquivos/baixar?arquivo=equip12/arquivos.cfg"' "$W/corpo")"; tam="$(grep -c '64,0[^<]*KiB' "$W/corpo")"
r="$(baixa "$W/baixado.cfg" equip12/arquivos.cfg)"; tipo="$(cab content-type)"; comprimento="$(cab content-length)"; disposicao="$(cab content-disposition)"
auditoria; n_depois="$(eventos arquivo_baixado)"; registro="$(grep -c " evento=arquivo_baixado admin=$ADMIN arquivo=equip12/arquivos.cfg bytes=65536" "$W/auditoria")"
atividade="$(aba -b "$J" "$B/atividade")"; na_atividade="$(grep -c 'Arquivo baixado' "$W/corpo")"
[[ "$e_arq" == 303 && "$r_f1" == 0 && "$raiz" == "200 " && "$na_raiz" -ge 1 && "$menu" == 1 && "$pasta" == "200 " && "$no_link" == 1 && "$tam" -ge 1 && "$r" == 200 \
  && "$(soma_de "$W/baixado.cfg")" == "$soma_envio" && "$tipo" == application/octet-stream && "$comprimento" == 65536 \
  && "$disposicao" == 'attachment; filename="arquivos.cfg"; filename*=UTF-8'"''"'arquivos.cfg' \
  && "$n_depois" == $((n_antes + 1)) && "$registro" == 1 && "$atividade" == "200 " && "$na_atividade" -ge 1 ]]
caso $? testes 24 "Download pelo painel" "arquivo de 65536 bytes enviado por FTPS pelo usuário equip12: saída $r_f1 · GET /arquivos: $raiz· pasta equip12 na lista: $na_raiz, aba no menu: $menu · GET /arquivos?pasta=equip12: $pasta· botão Baixar do arquivo: $no_link, tamanho mostrado: $tam · download: $r, sha256 $([[ "$(soma_de "$W/baixado.cfg")" == "$soma_envio" ]] && echo idêntico || echo DIFERENTE) ao enviado (${soma_envio:0:16}…) · Content-Type: $tipo · Content-Length: $comprimento · Content-Disposition: $disposicao · arquivo_baixado na auditoria: $n_antes → $n_depois, com administrador, caminho e bytes: $registro · na aba Atividade: $na_atividade"

sub="$(aba -b "$J" "$Q?pasta=equip12/diario")"
link="$(sed -n 's/.*href="\(\/arquivos\/baixar?arquivo=equip12\/diario\/[^"]*\)".*/\1/p' "$W/corpo" | head -1)"; trilha="$(grep -c 'href="/arquivos?pasta=equip12">equip12</a>' "$W/corpo")"
r_sub="$(c -b "$J" -D "$W/arq.cab" -o "$W/baixado-sub.cfg" -w '%{http_code}' "$B$link")"; disposicao="$(cab content-disposition)"
r_g="$(baixa "$W/baixado-grande.bin" equip12/grande.bin)"; comprimento="$(cab content-length)"
temporarios="$(docker exec "$NGINX" sh -c 'find /tmp/nginx -type f | wc -l')"; tmp_nginx="$(docker exec "$NGINX" sh -c "df -k /tmp/nginx | awk 'NR == 2 {print \$2}'")"
usuarios_aba="$(aba -b "$J" "$B/usuarios")"; da_lista="$(grep -c 'href="/arquivos?pasta=equip12"' "$W/corpo")"
[[ "$r_f2" == 0 && "$r_f3" == 0 && "$sub" == "200 " && "$link" == '/arquivos/baixar?arquivo=equip12/diario/relat%C3%B3rio%20final.cfg' && "$trilha" == 1 && "$r_sub" == 200 \
  && "$(soma_de "$W/baixado-sub.cfg")" == "$soma_envio" && "$disposicao" == *"filename*=UTF-8''relat%C3%B3rio%20final.cfg" \
  && "$r_g" == 200 && "$comprimento" == 41943040 && "$(soma_de "$W/baixado-grande.bin")" == "$soma_grande" && "$temporarios" == 0 && "$tmp_nginx" -lt 40960 \
  && "$usuarios_aba" == "200 " && "$da_lista" == 1 ]]
caso $? testes 25 "Subpasta, nome com acento e arquivo grande" "GET /arquivos?pasta=equip12/diario: $sub· link do arquivo 'relatório final.cfg': ${link:-ausente} · caminho com link para a pasta de cima: $trilha · download pelo link: $r_sub, sha256 $([[ "$(soma_de "$W/baixado-sub.cfg")" == "$soma_envio" ]] && echo idêntico || echo DIFERENTE) · Content-Disposition: $disposicao · arquivo de 40 MiB enviado por FTPS (saída $r_f3) e baixado pelo painel: $r_g, Content-Length $comprimento, sha256 $([[ "$(soma_de "$W/baixado-grande.bin")" == "$soma_grande" ]] && echo idêntico || echo DIFERENTE) · /tmp/nginx tem $tmp_nginx KiB e ficou com $temporarios arquivo(s) temporário(s) · aba Usuários aponta para a pasta do usuário: $da_lista"
rm -f "$W/baixado-grande.bin"

# ------------------------------------------------------------------ sem sessão
ev=""; ok=0; : > "$W/sem-sessao"
for caminho in '/arquivos' '/arquivos?pasta=equip12' '/arquivos/baixar?arquivo=equip12/arquivos.cfg'; do
  r="$(aba "$B$caminho")"; [[ "$r" == "303 /entrar" && ! -s "$W/corpo" ]] || ok=1; cat "$W/corpo" >> "$W/sem-sessao"; ev+="GET $caminho: $r; "
done
r_falso="$(aba -b '__Host-sessao=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' "$B/arquivos/baixar?arquivo=equip12/arquivos.cfg")"; cat "$W/corpo" >> "$W/sem-sessao"
r_post="$(envio '/arquivos/baixar?arquivo=equip12/arquivos.cfg' --data-urlencode "csrf=$K")"
[[ "$r_falso" == "303 /entrar" && "$r_post" == "404 " && ! -s "$W/sem-sessao" ]] || ok=1
caso $ok seguranca 52 "Arquivos sem sessão" "$ev com cookie de sessão inventado: $r_falso· bytes recebidos nas quatro respostas: $(wc -c < "$W/sem-sessao") · POST no endereço do download, com sessão e token: $r_post(só GET existe)"

# ------------------------------------------------------------------ fuga da pasta
ev=""; ok=0; : > "$W/fuga"; auditoria; n_antes="$(eventos recusa_caminho)"
for tentativa in 'arquivo=../auth/pureftpd.passwd' 'arquivo=equip12/../../auth/pureftpd.passwd' 'arquivo=/etc/passwd' 'arquivo=%2e%2e/%2e%2e/etc/passwd' \
                 'arquivo=..%2f..%2fpainel%2fadministradores' 'arquivo=equip12//arquivos.cfg' 'arquivo=equip12/arquivos.cfg%00.txt' 'arquivo=./equip12/arquivos.cfg'; do
  r="$(c --path-as-is -b "$J" -o "$W/corpo" -w '%{http_code}' "$B/arquivos/baixar?$tentativa")"; [[ "$r" == 400 ]] || ok=1; cat "$W/corpo" >> "$W/fuga"; ev+="$tentativa: $r; "
done
for tentativa in 'pasta=..' 'pasta=/' 'pasta=equip12/../..' 'pasta=%2e%2e%2fauth'; do
  r="$(c --path-as-is -b "$J" -o "$W/corpo" -w '%{http_code}' "$B/arquivos?$tentativa")"; [[ "$r" == 400 ]] || ok=1; cat "$W/corpo" >> "$W/fuga"; ev+="$tentativa: $r; "
done
r_pasta="$(baixa "$W/corpo" equip12)"; cat "$W/corpo" >> "$W/fuga"; r_nada="$(baixa "$W/corpo" equip12/nao-existe.cfg)"; cat "$W/corpo" >> "$W/fuga"
auditoria; n_depois="$(eventos recusa_caminho)"; fora_da_pasta="$(vazou "$W/fuga")"
[[ "$r_pasta" == 404 && "$r_nada" == 404 && "$fora_da_pasta" == 0 && "$n_depois" -gt "$n_antes" ]] || ok=1
caso $ok seguranca 53 "Fuga da pasta pela aba Arquivos" "com sessão válida · $ev pasta pedida como arquivo: $r_pasta · arquivo que não existe: $r_nada · linhas de /etc/passwd, do PureDB ou dos administradores nas respostas: $fora_da_pasta · recusa_caminho na auditoria (uma linha por minuto e por endereço): $n_antes → $n_depois"

# ------------------------------------------------------------------ link simbólico
docker exec "$FTP" sh -c 'ln -s /auth/pureftpd.passwd /data/equip12/atalho.cfg && ln -s /auth /data/equip12/pasta-atalho && ln -s arquivos.cfg /data/equip12/interno.cfg'; r_ln=$?
docker exec "$PAINEL" test -r /data/equip12/atalho.cfg; alcanca=$?
: > "$W/links"; lista="$(aba -b "$J" "$Q?pasta=equip12")"
marcados="$(grep -o 'link simbólico' "$W/corpo" | wc -l)"; com_botao="$(grep -c -E 'baixar\?arquivo=equip12/(atalho|interno)\.cfg|pasta=equip12/pasta-atalho' "$W/corpo")"
r_a="$(baixa "$W/corpo" equip12/atalho.cfg)"; cat "$W/corpo" >> "$W/links"
r_i="$(baixa "$W/corpo" equip12/interno.cfg)"; cat "$W/corpo" >> "$W/links"
r_p="$(aba -b "$J" "$Q?pasta=equip12/pasta-atalho")"; cat "$W/corpo" >> "$W/links"
r_d="$(baixa "$W/corpo" equip12/pasta-atalho/pureftpd.passwd)"; cat "$W/corpo" >> "$W/links"
pelo_link="$(vazou "$W/links")"
docker exec "$FTP" rm -f /data/equip12/atalho.cfg /data/equip12/pasta-atalho /data/equip12/interno.cfg
[[ "$r_ln" == 0 && "$alcanca" == 0 && "$lista" == "200 " && "$marcados" == 3 && "$com_botao" == 0 && "$r_a" == 403 && "$r_i" == 403 && "$r_p" == "403 " && "$r_d" == 403 && "$pelo_link" == 0 ]]
caso $? seguranca 54 "Link simbólico na aba Arquivos" "links criados dentro da pasta do usuário: para /auth/pureftpd.passwd, para a pasta /auth e para um arquivo da própria pasta (saída $r_ln; o root do painel alcançaria o alvo: $([[ "$alcanca" == 0 ]] && echo sim || echo não)) · na lista: $marcados marcados como link simbólico, com botão ou link de abrir: $com_botao · baixar o link para o PureDB: $r_a · o link interno: $r_i · abrir a pasta-link: $r_p· baixar por dentro dela: $r_d · linhas do PureDB nas respostas: $pelo_link"

# ------------------------------------------------------------------ só como anexo
docker exec "$FTP" sh -c 'printf x > "/data/equip12/a\"b;c.cfg"'
r="$(baixa "$W/baixado.html" equip12/pagina.html)"; tipo="$(cab content-type)"; disposicao="$(cab content-disposition)"; faltam=""
for cabecalho in 'x-content-type-options: nosniff' 'content-security-policy:' 'cache-control: no-store' 'x-frame-options:' 'accept-ranges: none'; do
  grep -q -i "^$cabecalho" "$W/arq.cab" || faltam+=" $cabecalho"
done
r_n="$(baixa "$W/corpo" 'equip12/a%22b%3Bc.cfg')"; disposicao_n="$(cab content-disposition)"; linhas_cab="$(grep -c -i '^content-disposition:' "$W/arq.cab")"
docker exec "$FTP" rm -f '/data/equip12/a"b;c.cfg'
[[ "$r_f4" == 0 && "$r" == 200 && "$tipo" == application/octet-stream && "$disposicao" == 'attachment; filename="pagina.html"'* && -z "$faltam" ]] && cmp -s "$W/pagina.html" "$W/baixado.html" \
  && [[ "$r_n" == 200 && "$linhas_cab" == 1 && "$disposicao_n" == 'attachment; filename="a_b_c.cfg"; filename*=UTF-8'"''"'a%22b%3Bc.cfg' ]]
caso $? seguranca 55 "Arquivo entregue só como anexo" "página HTML com script enviada por FTPS (saída $r_f4) e baixada pelo painel: $r · Content-Type: $tipo · Content-Disposition: $disposicao · cabeçalhos faltando:${faltam:- nenhum} · arquivo com aspas e ponto e vírgula no nome: $r_n, Content-Disposition: $disposicao_n"

# ------------------------------------------------------------------ limite de downloads ao mesmo tempo
auditoria; n_antes="$(eventos arquivo_interrompido)"; lentos=()
for _ in 1 2 3 4 5 6 7 8; do
  curl -sk --max-time 40 --limit-rate 4k -b "$J" -o /dev/null "$D=equip12/grande.bin" & lentos+=("$!")
  sleep 0.1
done
sleep 2
r_9="$(baixa "$W/corpo" equip12/arquivos.cfg)"; espera="$(cab retry-after)"; r_tela="$(aba -b "$J" "$B/usuarios")"
kill "${lentos[@]}" 2>/dev/null; wait "${lentos[@]}" 2>/dev/null
for _ in $(seq 1 20); do  # o painel percebe o fim de cada download quando o nginx fecha a conexão com ele
  auditoria; n_depois="$(eventos arquivo_interrompido)"; [[ "$n_depois" -ge $((n_antes + 8)) ]] && break
  sleep 1
done
r_depois="$(baixa "$W/baixado.cfg" equip12/arquivos.cfg)"
[[ "$r_9" == 503 && "$espera" == 30 && "$r_tela" == "200 " && "$r_depois" == 200 && "$(soma_de "$W/baixado.cfg")" == "$soma_envio" && "$n_depois" -ge $((n_antes + 8)) \
  && "$(saude "$PAINEL" "$NGINX")" == "healthy healthy " ]]
caso $? seguranca 56 "Limite de downloads ao mesmo tempo" "8 downloads lentos do arquivo de 40 MiB em andamento · o 9º: $r_9, Retry-After: ${espera:-ausente} · aba Usuários enquanto isso: $r_tela· com os 8 encerrados no meio, novo download: $r_depois, sha256 $([[ "$(soma_de "$W/baixado.cfg")" == "$soma_envio" ]] && echo idêntico || echo DIFERENTE) · arquivo_interrompido na auditoria: $n_antes → $n_depois · saúde do painel e do nginx: $(saude "$PAINEL" "$NGINX")"

rm -f "$W/grande.bin"; mu del equip12
