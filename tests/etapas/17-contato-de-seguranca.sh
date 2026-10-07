#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa Q: robots.txt e contato de segurança. O aviso aos robôs de busca entregue pelo nginx, o
# security.txt (RFC 9116) que o painel publica com SEGURANCA_CONTATO_EMAIL e o que esses dois endereços,
# abertos sem senha, não entregam: outro arquivo, outro método, caminho que sobe de pasta e valor inválido.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel zera a contagem de falhas de entrada e das recusas e encerra as sessões.
dc restart painel > /dev/null 2>&1; painel_de_pe

pede() { c -D "$W/st.cab" -o "$W/st.corpo" -w '%{http_code}' "$@"; }   # [opções do curl...] <endereço> → código HTTP
tipo_de() { grep -i '^content-type:' "$W/st.cab" | tr -d '\r' | cut -d ' ' -f 2-; }
biscoitos() { grep -c -i '^set-cookie:' "$W/st.cab" || true; }
faltando() { # cabeçalhos de segurança que a última resposta não trouxe
  local falta="" cabecalho
  for cabecalho in 'content-security-policy:' 'x-content-type-options: nosniff' 'strict-transport-security:' 'x-frame-options: DENY'; do
    grep -q -i "^$cabecalho" "$W/st.cab" || falta+=" $cabecalho"
  done
  echo "${falta:- nenhum}"
}
CONTATO=seguranca@exemplo.com.br
SECURITY="$B/.well-known/security.txt"

# ------------------------------------------------------------------ robots.txt
r="$(pede "$B/robots.txt")"; tipo="$(tipo_de)"; falta="$(faltando)"; biscoito="$(biscoitos)"
igual=NÃO; cmp -s web/robots.txt "$W/st.corpo" && igual=sim
regras="$(grep -v '^#' "$W/st.corpo" | tr -d '\r' | paste -s -d ';')"
cache="$(grep -i '^cache-control:' "$W/st.cab" | tr -d '\r')"
r_cabeca="$(c -I -o /dev/null -w '%{http_code}' "$B/robots.txt")"
c "$B/entrar" > "$W/st.entrada"; meta="$(grep -c -F '<meta name="robots" content="noindex, nofollow">' "$W/st.entrada")"
dono="$(docker exec "$NGINX" stat -c '%U:%G %a' /usr/share/allsafe-nginx/web/robots.txt 2>/dev/null)"
no_painel="$(docker logs "$PAINEL" 2>&1 | grep -c 'robots.txt' || true)"
[[ "$r" == 200 && "$tipo" == "text/plain; charset=utf-8" && "$falta" == " nenhum" && "$biscoito" == 0 && "$igual" == sim \
  && "$regras" == "User-agent: *;Disallow: /" && "$cache" == *no-cache && "$r_cabeca" == 200 && "$meta" == 1 && "$dono" == "root:root 644" && "$no_painel" == 0 ]]
caso $? testes 35 "robots.txt entregue pelo nginx" "sem sessão: GET /robots.txt: $r, $tipo, igual ao do projeto: $igual, cabeçalhos de segurança faltando:$falta, cookie: $biscoito, $cache · regras, fora os comentários: $regras · HEAD: $r_cabeca · tela de entrada com a meta robots noindex, nofollow: $meta · dono e modo na imagem do nginx: $dono · pedidos de robots.txt que chegaram ao painel: $no_painel"

# ------------------------------------------------------------------ security.txt: desligado, ligado e desligado de novo
linha_env="$(grep -c '^SEGURANCA_CONTATO_EMAIL=$' "$ENVA")"
r_sem="$(pede "$SECURITY")"; tipo_sem="$(tipo_de)"; corpo_sem="$(tr -d '\r\n' < "$W/st.corpo")"
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"
seg_sem="$(aba -b "$J" "$B/seguranca")"; aba_sem="$(grep -c -F 'Não publicado (<code>SEGURANCA_CONTATO_EMAIL</code> vazio)' "$W/corpo")"
conferir_deploy "SEGURANCA_CONTATO_EMAIL=time+seguranca@sub.exemplo.com.br"; r_aceita=$?

antes="$(ids)"; gravar_env "$ENVA" SEGURANCA_CONTATO_EMAIL "$CONTATO"; dep; r_liga=$?; painel_de_pe; depois="$(ids)"
resumo_com="$(grep -c -F "Contato de segurança: $CONTATO, publicado em /.well-known/security.txt do painel." "$W/deploy.log")"
ftp_mantido=NÃO; [[ "${antes%% *}" == "${depois%% *}" ]] && ftp_mantido=sim
r_com="$(pede "$SECURITY")"; tipo_com="$(tipo_de)"; falta_com="$(faltando)"; biscoito_com="$(biscoitos)"; cp "$W/st.corpo" "$W/st.txt"
linhas="$(grep -c . "$W/st.txt")"; retornos="$(grep -c $'\r' "$W/st.txt" || true)"
contato="$(sed -n 1p "$W/st.txt")"; expira="$(sed -n 's/^Expires: //p' "$W/st.txt")"; idioma="$(sed -n 3p "$W/st.txt")"
formato=NÃO; [[ "$expira" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T00:00:00Z$ ]] && formato=sim
dias=$(( ( $(date -u -d "$expira" +%s 2>/dev/null || echo 0) - $(date -u +%s) ) / 86400 ))
e_adm2="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"
r_sessao="$(pede -b "$J" "$SECURITY")"; mesmo=NÃO; cmp -s "$W/st.txt" "$W/st.corpo" && mesmo=sim
seg_com="$(aba -b "$J" "$B/seguranca")"; aba_com="$(grep -c -F "Publicado em <code>/.well-known/security.txt</code>: quem achar uma falha nesta instalação escreve para <code>$CONTATO</code>" "$W/corpo")"

# ------------------------------------------------------------------ o que os dois endereços sem senha não entregam
ev=""; ok=0; : > "$W/st.recusas"
nega() { # <rótulo> <opções do curl e endereço...>: a resposta não pode ser 200
  local rotulo="$1" r; shift
  r="$(pede --path-as-is "$@")"
  [[ "$r" != 200 ]] || ok=1
  cat "$W/st.corpo" >> "$W/st.recusas"; ev+="$rotulo: $r; "
}
nega 'lista da pasta .well-known' "$B/.well-known/"
nega 'pasta sem barra' "$B/.well-known"
nega 'outro nome na pasta' "$B/.well-known/outro.txt"
nega 'security.txt na raiz' "$B/security.txt"
nega 'nome em maiúsculas' "$B/.well-known/SECURITY.TXT"
nega 'sufixo depois do nome' "$SECURITY/"
nega 'sobe de pasta' "$SECURITY/../../etc/passwd"
nega 'sobe de pasta codificado' "$B/.well-known/..%2f..%2fetc%2fpasswd"
nega 'byte nulo' "$SECURITY%00.html"
nega 'robots.txt com sufixo' "$B/robots.txt/"
nega 'cópia do robots.txt' "$B/robots.txt.bak"
nega 'robots.txt em maiúsculas' "$B/ROBOTS.TXT"
nega 'sobe do robots.txt até a configuração em uso' "$B/robots.txt/../../../../run/nginx/nginx.conf"
nega 'sobe do robots.txt até a chave do certificado' "$B/robots.txt/../../../../nginx/tls/painel-key.pem"
nega 'endereço que o painel não aceita' -H 'Host: painel.exemplo.invalid' "$SECURITY"
for metodo in POST PUT DELETE; do
  nega "$metodo no security.txt" -X "$metodo" --data 'x=1' "$SECURITY"
  nega "$metodo no robots.txt" -X "$metodo" --data 'x=1' "$B/robots.txt"
done
vazou_cfg="$(grep -c -a -E 'worker_processes|ssl_certificate|PRIVATE KEY|root:x:' "$W/st.recusas" || true)"
vazou_contato="$(grep -c -a -F "$CONTATO" "$W/st.recusas" || true)"
# O arquivo publicado traz o contato, a validade e o idioma, e mais nada: nem versão, nem nome da stack, nem caminho.
alem="$(grep -c -v -E '^(Contact: mailto:[^ ]+|Expires: [0-9TZ:-]+|Preferred-Languages: pt-BR)$' "$W/st.txt" || true)"
servidor="$(grep -i '^server:' "$W/st.cab" | tr -d '\r')"
ev_r=""; ok_r=0; recusados=0
while IFS= read -r valor; do
  rd="$(recusa_deploy "SEGURANCA_CONTATO_EMAIL=$valor")"; rc="$(recusa_container painel "SEGURANCA_CONTATO_EMAIL=$valor")"
  { recusou "$rd" 'SEGURANCA_CONTATO_EMAIL inválido' && recusou "$rc" 'SEGURANCA_CONTATO_EMAIL inválido'; } || ok_r=1
  recusados=$((recusados + 1)); ev_r+="[$valor] deploy.sh: ${rd%% ·*}, painel: ${rc%% ·*}; "
done <<FIM
sem-arroba
a@b
dois@exemplo.com.br,outro@exemplo.com.br
com espaco@exemplo.com.br
mailto:seguranca@exemplo.com.br
https://exemplo.com.br/contato
seguranca@exemplo.com.br>
<x>@exemplo.com.br
seguranca@-exemplo.com.br
seguranca@exemplo..com.br
100%certo@exemplo.com.br
seguranca@exemplo.com.br\nContact: mailto:outro@exemplo.com.br
$(printf 'a%.0s' {1..65})@exemplo.com.br
FIM
r_ainda="$(pede "$SECURITY")"; intacto=NÃO; cmp -s "$W/st.txt" "$W/st.corpo" && intacto=sim
auditoria; pedidos_get="$(grep -c 'security.txt' "$W/auditoria" || true)"; envios_recusados="$(grep -c 'evento=recusa_origem caminho=/.well-known/security.txt' "$W/auditoria" || true)"

gravar_env "$ENVA" SEGURANCA_CONTATO_EMAIL ""; dep; r_desliga=$?; painel_de_pe
resumo_sem="$(grep -c '^Contato de segurança: não publicado. Para publicar, preencha SEGURANCA_CONTATO_EMAIL' "$W/deploy.log")"
r_volta="$(pede "$SECURITY")"; contato_volta="$(grep -c -a -F "$CONTATO" "$W/st.corpo" || true)"

[[ "$linha_env" == 1 && "$r_sem" == 404 && "$tipo_sem" == "text/plain; charset=utf-8" && "$corpo_sem" == "contato de segurança não configurado" && "$e_adm" == 303 \
  && "$seg_sem" == "200 " && "$aba_sem" == 1 && "$r_aceita" == 0 && "$r_liga" == 0 && "$ftp_mantido" == sim && "$r_com" == 200 && "$tipo_com" == "text/plain; charset=utf-8" \
  && "$falta_com" == " nenhum" && "$biscoito_com" == 0 && "$linhas" == 3 && "$retornos" == 0 && "$contato" == "Contact: mailto:$CONTATO" && "$formato" == sim \
  && "$dias" -ge 89 && "$dias" -le 90 && "$idioma" == "Preferred-Languages: pt-BR" && "$e_adm2" == 303 && "$r_sessao" == 200 && "$mesmo" == sim \
  && "$seg_com" == "200 " && "$aba_com" == 1 && "$r_desliga" == 0 && "$r_volta" == 404 && "$contato_volta" == 0 && "$resumo_com" == 1 && "$resumo_sem" == 1 ]]
caso $? testes 36 "security.txt publicado com o contato de segurança" "padrão da instalação: SEGURANCA_CONTATO_EMAIL vazia no .env ($linha_env linha) · sem contato: GET /.well-known/security.txt: $r_sem, $tipo_sem, \"$corpo_sem\"; aba Segurança: $seg_sem· linha Não publicado: $aba_sem · deploy.sh --check-only com time+seguranca@sub.exemplo.com.br: saída $r_aceita · com SEGURANCA_CONTATO_EMAIL=$CONTATO (deploy.sh: saída $r_liga, linha do contato publicado no resumo: $resumo_com, container do FTP mantido: $ftp_mantido): $r_com, $tipo_com, cabeçalhos de segurança faltando:$falta_com, cookie: $biscoito_com · conteúdo: $linhas linhas, retornos de carro: $retornos · $contato · Expires: $expira (formato RFC 3339: $formato, daqui a $dias dias) · $idioma · com a sessão do administrador: $r_sessao, o mesmo texto: $mesmo · aba Segurança: $seg_com· linha Publicado, com o contato: $aba_com · variável esvaziada de novo (deploy.sh: saída $r_desliga, linha do contato não publicado no resumo: $resumo_sem): $r_volta, contato na resposta: $contato_volta"

[[ "$ok" == 0 && "$vazou_cfg" == 0 && "$vazou_contato" == 0 && "$alem" == 0 && "$servidor" != *[0-9]* && "$ok_r" == 0 && "$recusados" == 13 \
  && "$r_ainda" == 200 && "$intacto" == sim && "$pedidos_get" == "$envios_recusados" ]]
caso $? seguranca 68 "robots.txt e security.txt, abertos sem senha, não entregam mais nada" "com o contato publicado, sem sessão (nenhuma resposta pode ser 200): $ev· linhas de configuração, de chave ou de /etc/passwd nas respostas: $vazou_cfg · o contato fora do security.txt: $vazou_contato · linhas do security.txt além de Contact, Expires e Preferred-Languages: $alem · cabeçalho do servidor: ${servidor:-ausente} · valores recusados de SEGURANCA_CONTATO_EMAIL ($recusados; saída 1 = recusado, instância intacta): $ev_r· depois de tudo, o security.txt: $r_ainda, o mesmo texto: $intacto · linhas da auditoria com security.txt: $pedidos_get, todas de envio recusado por origem: $envios_recusados"

rm -f "$W"/st.*
