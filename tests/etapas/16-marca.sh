#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa P: marca. A logo e o ícone entregues pelo nginx, a autoria no rodapé de todas as telas e o que
# a pasta da marca não entrega: nome fora da lista, as fontes, outro método e caminho que sobe de pasta.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel zera a contagem de falhas de entrada e das recusas e encerra as sessões.
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"

MARCA=(favicon.ico marca/icone-32.png marca/icone-192.png marca/apple-touch-icon.png marca/simbolo-64.png marca/logo-320.png)
pede() { c -D "$W/marca.cab" -o "$W/marca.corpo" -w '%{http_code}' "$@"; }   # [opções do curl...] <endereço> → código HTTP
tipo_de() { grep -i '^content-type:' "$W/marca.cab" | tr -d '\r' | cut -d ' ' -f 2-; }
imagem() { head -c 4 "$1" 2>/dev/null | od -An -tx1 | tr -d ' \n' | grep -c -E '^(89504e47|00000100)$' || true; }  # 1 = PNG ou ICO

# ------------------------------------------------------------------ logo e ícone
ev=""; ok=0
for nome in "${MARCA[@]}"; do
  r="$(pede "$B/$nome")"; tipo="$(tipo_de)"; faltam=""
  for cabecalho in 'content-security-policy:' 'x-content-type-options: nosniff' 'strict-transport-security:' 'etag:'; do
    grep -q -i "^$cabecalho" "$W/marca.cab" || faltam+=" $cabecalho"
  done
  esperado=image/png; [[ "$nome" == favicon.ico ]] && esperado=image/x-icon
  igual=NÃO; cmp -s "web/marca/${nome#marca/}" "$W/marca.corpo" && igual=sim
  biscoito="$(grep -c -i '^set-cookie:' "$W/marca.cab" || true)"
  [[ "$r" == 200 && "$tipo" == "$esperado" && -z "$faltam" && "$igual" == sim && "$biscoito" == 0 ]] || ok=1
  ev+="/$nome: $r, $tipo, igual ao do projeto: $igual, cabeçalhos faltando:${faltam:- nenhum}, cookie: $biscoito; "
done
c "$B/entrar" > "$W/entrada.html"
na_entrada=0
for trecho in '<link rel="icon" href="/favicon.ico" sizes="16x16 32x32 48x48">' '<link rel="icon" href="/marca/icone-32.png" type="image/png" sizes="32x32">' \
  '<link rel="icon" href="/marca/icone-192.png" type="image/png" sizes="192x192">' '<link rel="apple-touch-icon" href="/marca/apple-touch-icon.png">' \
  '<img class="logo-entrada" src="/marca/logo-320.png" alt="ALL-SAFE" width="128" height="128">' '<img src="/marca/simbolo-64.png" alt="" width="28" height="28">AllSafe FTP'; do
  grep -q -F "$trecho" "$W/entrada.html" && na_entrada=$((na_entrada + 1))
done
visao="$(aba -b "$J" "$B/")"; no_topo="$(grep -c -F '<img src="/marca/simbolo-64.png" alt="" width="28" height="28">AllSafe FTP' "$W/corpo")"; sem_logo_grande="$(grep -c 'logo-320' "$W/corpo")"
# Toda imagem e todo ícone que as duas telas pedem existe.
pedidos="$(cat "$W/entrada.html" "$W/corpo" | grep -o -E '(src|href)="/(marca/[^"]*|favicon[^"]*)"' | cut -d '"' -f 2 | sort -u)"; quebrados=0
for caminho in $pedidos; do [[ "$(pede "$B$caminho")" == 200 && "$(imagem "$W/marca.corpo")" == 1 ]] || quebrados=$((quebrados + 1)); done
antigo="$(aba "$B/favicon.svg")"; no_codigo="$(docker exec "$PAINEL" grep -c -r 'favicon.svg' /opt/painel 2>/dev/null | awk -F: '{s += $2} END {print s + 0}')"
no_painel="$(docker exec "$PAINEL" find / -xdev \( -name 'favicon.ico' -o -name 'icone-*.png' -o -name 'apple-touch-icon.png' -o -name 'simbolo-64.png' -o -name 'logo-320.png' \) 2>/dev/null | wc -l)"
fontes="$(docker exec "$NGINX" find / -xdev \( -name 'allsafe-logo-2048.png' -o -name 'allsafe-simbolo-512.png' -o -name 'fonte' \) 2>/dev/null | wc -l)"
na_imagem="$(docker exec "$NGINX" sh -c 'ls /usr/share/allsafe-nginx/web/marca | wc -l')"
[[ "$ok" == 0 && "$e_adm" == 303 && "$na_entrada" == 6 && "$visao" == "200 " && "$no_topo" == 1 && "$sem_logo_grande" == 0 && "$(wc -w <<< "$pedidos")" == 6 && "$quebrados" == 0 \
  && "$antigo" == "303 /entrar" && "$no_codigo" == 0 && "$no_painel" == 0 && "$fontes" == 0 && "$na_imagem" == 6 ]]
caso $? testes 33 "Logo e ícone do painel entregues pelo nginx" "sem sessão: $ev· tela de entrada com os 4 ícones, a logo e o símbolo no topo: $na_entrada de 6 · Visão geral: $visao· símbolo no topo: $no_topo, logo grande fora da tela de entrada: $sem_logo_grande · imagens e ícones pedidos pelas duas telas: $(wc -w <<< "$pedidos"), quebrados: $quebrados · ícone antigo /favicon.svg: $antigo, citações no código do painel: $no_codigo · cópias da marca dentro do container do painel: $no_painel · arquivos em web/marca do nginx: $na_imagem, fontes da marca na imagem: $fontes"

# ------------------------------------------------------------------ autoria no rodapé
nova_senha "$W/u16.senha"; mu add equip16 "$W/u16.senha"
e_u="$(COMO=equip16 entrar "$W/u16.jar" "$W/u16.senha")"; proibir "$(biscoito_de "$W/u16.jar")"
versao="$(cat VERSION)"
rodape() { # <arquivo com a tela> → "autoria site github versão outros-endereços"
  local autoria site github com_versao fora
  autoria="$(grep -c -F '<p class="autoria">Desenvolvido pela <a href="https://allsafe.inf.br" target="_blank" rel="noopener noreferrer">allsafe.inf.br</a>' "$1")"
  site="$(grep -o -F 'href="https://allsafe.inf.br"' "$1" | wc -l)"
  github="$(grep -o -F '<a href="https://github.com/allsafe-inf" target="_blank" rel="noopener noreferrer">github.com/allsafe-inf</a>' "$1" | wc -l)"
  com_versao="$(grep -c -F "<p>allsafe-ftp-stack v$versao · " "$1")"
  fora="$(grep -o -E '(href|src|action)="[a-z]+:[^"]*"' "$1" | grep -v -c -F -e '"https://allsafe.inf.br"' -e '"https://github.com/allsafe-inf"' || true)"
  echo "$autoria $site $github $com_versao $fora"
}
ev=""; ok=0; telas=0
confere() { # <rótulo> <código esperado> <código recebido>: a tela que ficou em $W/corpo
  local r; r="$(rodape "$W/corpo")"; telas=$((telas + 1))
  [[ "$3" == "$2"* && "$r" == "1 1 1 1 0" ]] || ok=1
  ev+="$1: ${3% } [$r]; "
}
r="$(aba "$B/entrar")"; confere 'tela de entrada' 200 "$r"
printf 'senha-errada-%s' "$RANDOM" > "$W/errada16.senha"
r="$(COMO=ninguem16 entrar "$W/x16.jar" "$W/errada16.senha")"; cp "$W/entrada.corpo" "$W/corpo"; confere 'entrada recusada' 401 "$r"
for caminho in / /usuarios /usuarios/novo /arquivos /administradores /seguranca /atividade; do
  r="$(aba -b "$J" "$B$caminho")"; confere "administrador em $caminho" 200 "$r"
done
r="$(aba -b "$J" "$B/nao-existe-16")"; confere 'página que não existe' 404 "$r"
r="$(aba -b "$W/u16.jar" "$B/meus-arquivos")"; confere 'usuário do FTP em /meus-arquivos' 200 "$r"
politica="$(c -D - -o /dev/null "$B/entrar" | grep -i '^referrer-policy:' | tr -d '\r')"
csp="$(c -D - -o /dev/null "$B/entrar" | grep -i '^content-security-policy:' | tr -d '\r')"
[[ "$ok" == 0 && "$e_u" == 303 && "$telas" == 11 && "$politica" == *same-origin && "$csp" == *"default-src 'none'"* && "$csp" == *"img-src 'self'"* ]]
caso $? testes 34 "Autoria no rodapé de todas as telas" "em cada tela: código [linha da autoria, links para allsafe.inf.br, link para github.com/allsafe-inf com rel noopener noreferrer, linha da versão $versao, endereços de fora além desses dois] · $ev· telas conferidas: $telas · entrada de equip16 (usuário do FTP): $e_u · $politica (o site de destino não recebe o endereço do painel) · CSP da tela: imagem só do próprio painel"

# ------------------------------------------------------------------ o que a pasta da marca não entrega
ev=""; ok=0; : > "$W/marca-recusas"
nega() { # <rótulo> <opções do curl e endereço...>: a resposta não pode ser 200 nem trazer imagem ou configuração
  local rotulo="$1" r; shift
  r="$(pede --path-as-is "$@")"
  [[ "$r" != 200 && "$(imagem "$W/marca.corpo")" == 0 ]] || ok=1
  cat "$W/marca.corpo" >> "$W/marca-recusas"; ev+="$rotulo: $r; "
}
nega 'lista da pasta' "$B/marca/"
nega 'pasta sem barra' "$B/marca"
nega 'fonte da logo' "$B/marca/fonte/allsafe-logo-2048.png"
nega 'fonte do símbolo' "$B/marca/fonte/allsafe-simbolo-512.png"
nega 'nome fora da lista' "$B/marca/outro.png"
nega 'nome em maiúsculas' "$B/marca/LOGO-320.PNG"
nega 'outra extensão' "$B/marca/logo-320.svg"
nega 'sobe de pasta' "$B/marca/logo-320.png/../../../../etc/allsafe-nginx/nginx.conf.modelo"
nega 'sobe de pasta codificado' "$B/marca/..%2f..%2f..%2f..%2fetc%2fpasswd"
nega 'sobe até a configuração em uso' "$B/marca/../../../../run/nginx/nginx.conf"
nega 'chave do certificado' "$B/marca/../../../../nginx/tls/painel-key.pem"
nega 'byte nulo' "$B/marca/logo-320.png%00.txt"
nega 'sufixo depois do nome' "$B/marca/logo-320.png/"
nega 'ícone com sufixo' "$B/favicon.ico/../nginx.conf"
for metodo in POST PUT DELETE; do
  nega "$metodo na logo" -X "$metodo" --data 'x=1' "$B/marca/logo-320.png"
  nega "$metodo no ícone" -X "$metodo" --data 'x=1' "$B/favicon.ico"
done
vazou_cfg="$(grep -c -a -E 'worker_processes|ssl_certificate|PRIVATE KEY|root:x:' "$W/marca-recusas" || true)"
r_depois="$(pede "$B/marca/logo-320.png")"; intacta=NÃO; cmp -s web/marca/logo-320.png "$W/marca.corpo" && intacta=sim
grava="$(docker exec "$NGINX" sh -c 'touch /usr/share/allsafe-nginx/web/marca/x 2>&1; echo "saída $?"' | tail -1)"
dono="$(docker exec "$NGINX" stat -c '%U:%G %a' /usr/share/allsafe-nginx/web/marca/logo-320.png 2>/dev/null)"
# As imagens vêm do nginx: nenhum pedido delas chega ao painel nem entra na auditoria.
auditoria; na_auditoria="$(grep -c -E 'marca/|favicon' "$W/auditoria" || true)"
[[ "$ok" == 0 && "$vazou_cfg" == 0 && "$r_depois" == 200 && "$intacta" == sim && "$grava" != "saída 0" && "$dono" == "root:root 644" && "$na_auditoria" == 0 ]]
caso $? seguranca 67 "Pasta da marca entrega só os seis arquivos, só para leitura" "sem sessão (nenhuma resposta pode ser 200 nem trazer imagem): $ev· linhas de configuração, de chave ou de /etc/passwd nas respostas: $vazou_cfg · depois dos envios, a logo: $r_depois, igual à do projeto: $intacta · gravar na pasta de dentro do container do nginx: $grava · dono e modo da logo na imagem: $dono · pedidos da marca na auditoria do painel: $na_auditoria"

mu del equip16
rm -f "$W"/u16* "$W/x16.jar" "$W/errada16.senha" "$W"/marca.* "$W/marca-recusas" "$W/entrada.html"
