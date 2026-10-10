#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa AF: envio de arquivo pelo painel. O administrador envia para a pasta aberta; o usuário do FTP, só com a
# permissão dele e dentro do que o perfil deixa. O arquivo chega com o dono e o modo dos arquivos do FTP, nunca
# substitui outro, e o envio não sai da pasta de quem envia. Depois, as recusas (pedido forjado, nome e corpo fora
# da regra), um envio por conta e quatro no painel, o envio cortado no meio e o tamanho máximo.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel encerra as sessões e zera a memória das recusas (a auditoria guarda uma por minuto de cada tipo).
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
E32=/data/env32; M32=/meus-arquivos/enviar; A32=/arquivos/enviar
declare -A T32
# <pote> <rota> <token> <pasta> <nome a gravar> <arquivo local> [opções do curl...] → "código destino", como o formulário
# do painel manda: os campos de texto e o arquivo por último. NOME32 é o nome que o navegador daria ao arquivo;
# ORIGEM32=nenhuma tira o cabeçalho Origin; PRAZO32 é o tempo do curl. A tela fica em $W/corpo e os cabeçalhos, em $W/cab32.
manda32() {
  local pote="$1" rota="$2" token="$3" pasta="$4" nome="$5" arquivo="$6"; shift 6
  local -a origem=(-H "Origin: ${ORIGEM32:-$B}")
  [[ "${ORIGEM32:-}" == nenhuma ]] && origem=()
  sleep 0.05
  curl -sk --max-time "${PRAZO32:-60}" -o "${CORPO32:-$W/corpo}" -D "${CAB32:-$W/cab32}" -w '%{http_code} %{redirect_url}' -b "$pote" "${origem[@]}" "$@" \
    --form-string "csrf=$token" --form-string "pasta=$pasta" --form-string "nome=$nome" \
    -F "arquivo=@\"$arquivo\";filename=\"${NOME32:-${arquivo##*/}}\"" "$B$rota" | sed "s|$B||"
}
# <arquivo de saída> <partes...>: corpo multipart escrito à mão, com a marca lim32. Parte "campo=valor" é texto;
# "campo@nome=conteúdo" é arquivo.
corpo32() {
  local saida="$1" parte campo; shift
  : > "$saida"
  for parte in "$@"; do
    campo="${parte%%=*}"
    if [[ "$campo" == *@* ]]; then
      printf -- '--lim32\r\nContent-Disposition: form-data; name="%s"; filename="%s"\r\nContent-Type: application/octet-stream\r\n\r\n%s\r\n' \
        "${campo%%@*}" "${campo#*@}" "${parte#*=}" >> "$saida"
    else
      printf -- '--lim32\r\nContent-Disposition: form-data; name="%s"\r\n\r\n%s\r\n' "$campo" "${parte#*=}" >> "$saida"
    fi
  done
  printf -- '--lim32--\r\n' >> "$saida"
}
# <pote> <rota> <arquivo do corpo> [opções do curl...] → "código destino" do corpo escrito à mão
cru32() {
  local pote="$1" rota="$2" corpo="$3"; shift 3
  sleep 0.05
  curl -sk --max-time 30 -o "$W/corpo" -D "$W/cab32" -w '%{http_code} %{redirect_url}' -b "$pote" -H "Origin: $B" \
    -H 'Content-Type: multipart/form-data; boundary=lim32' "$@" --data-binary "@$corpo" "$B$rota" | sed "s|$B||"
}
foi32() { [[ "$1" == "303 "*"&m=enviado" ]]; }                                                 # <resposta>: o arquivo foi gravado com o nome pedido
tem32() { grep -c -F -- "$1" "$W/corpo" || true; }                                             # <texto>: linhas da última tela com ele
versao32() { head -1 "$W/cab32" | cut -d' ' -f1 | tr -d '\r'; }                                # protocolo da última resposta
modo32() { docker exec "$FTP" stat -c '%U:%G %a %s' "$@" 2>&1 | tr '\n' ' '; }                 # <caminho...>: dono, modo e tamanho
igual32() { docker exec "$FTP" cat "$1" 2>/dev/null | cmp -s - "$2"; }                         # <arquivo no servidor> <arquivo local>
nomes32() { docker exec "$FTP" ls -A "$1" 2>/dev/null | sort | tr '\n' ' '; }                  # <pasta>: o que há nela
arvore32() { docker exec "$FTP" sh -c 'find "$@" -xdev -printf "%M %u:%g %s %p\n" | sort | sha256sum | cut -c1-16' sh "$@"; }  # <pasta...>: soma do que há nelas
# O cadastro e as listas de /auth, sem os arquivos de estado que o servidor regrava sozinho.
auth32() { docker exec "$FTP" sh -c 'find /auth -xdev ! -name "*.estado" ! -name ".lock" -printf "%M %u:%g %s %p\n" | sort | sha256sum | cut -c1-16'; }
dado32() { docker exec "$FTP" stat -c '%U:%G %a %s' "$1" 2>/dev/null; }
certo32() { [[ "$(dado32 "$1")" == "ftpdata:ftpdata 644 $(stat -c %s "$2")" ]] && igual32 "$1" "$2"; }  # <arquivo no servidor> <arquivo local>: dono, modo, tamanho e conteúdo
linhas32() { grep -c -E -- "$1" "$W/auditoria" || true; }                                      # <expressão>: linhas da auditoria com ela
entra32() { COMO="e32$1" entrar "$W/e32$1.jar" "$W/e32$1.senha"; }                             # <c|e|l|s|v> → código HTTP
v32() { aba -b "$W/e32$1.jar" "$B$2"; }                                                        # <conta> <caminho>: GET com a sessão dela
p32() { local de="$1" rota="$2"; shift 2; POTE="$W/e32$de.jar" envio "$rota" --data-urlencode "csrf=${T32[$de]}" "$@"; }  # <conta> <caminho> <campos...>
m32() { local de="$1"; shift; manda32 "$W/e32$de.jar" $M32 "${T32[$de]}" "$@"; }                 # <conta> <pasta> <nome> <arquivo> [opções]: envio com a sessão e o token dela
sessoes32() { # <c|e|l|s|v>...: entra no painel como cada uma e guarda o token dos formulários dela; os códigos HTTP ficam em $e_web
  local n; e_web=""
  for n in "$@"; do
    e_web+="$(entra32 "$n") "; proibir "$(biscoito_de "$W/e32$n.jar")"
    T32[$n]="$(c -b "$W/e32$n.jar" "$B/meus-arquivos" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1)"; proibir "${T32[$n]}"
  done
}
permissao32() { mu limites "$1" ""; grep -c '^enviar=1' "$W/mu.log" || true; }                  # <usuário>: 1 se tem a permissão de enviar pelo painel

for n in c e l s v; do nova_senha "$W/e32$n.senha"; done
head -c 1500 /dev/urandom | base64 > "$W/e32.a"; head -c 900 /dev/urandom | base64 > "$W/e32.b"
printf '%s' "$(cat "$W/e32.b")" > "$W/e32.semfim"   # sem a quebra de linha do fim: é o que cabe em um corpo escrito à mão
head -c $((3 * 1048576 + 123)) /dev/urandom > "$W/e32.medio"; head -c 163840 /dev/urandom > "$W/e32.lento"; : > "$W/e32.vazio"
mu add e32c "$W/e32c.senha" env32/c; r_c=$?
mu add e32e "$W/e32e.senha" env32/e envio; r_e=$?
mu add e32l "$W/e32l.senha" env32/l leitura; r_l=$?
mu add e32s "$W/e32s.senha" env32/s soenvio; r_s=$?
mu add e32v "$W/e32v.senha" env32/v; r_v=$?
r_pasta="$(envio /arquivos/pasta --data-urlencode "csrf=$K" --data-urlencode 'pasta=env32' --data-urlencode 'nome=adm')"

# ------------------------------------------------------------------ o administrador envia para a pasta aberta
auditoria; n_env="$(eventos arquivo_enviado)"
tela="$(aba -b "$J" "$B/arquivos?pasta=env32/adm")"
f_acao="$(tem32 'action="/arquivos/enviar" enctype="multipart/form-data"')"; f_pasta="$(grep -A2 -F 'action="/arquivos/enviar"' "$W/corpo" | grep -c -F 'name="pasta" value="env32/adm"')"
f_arq="$(tem32 'name="arquivo" type="file" required')"; f_nome="$(tem32 'name="nome" maxlength="64"')"
r_1="$(NOME32=a1.cfg manda32 "$J" $A32 "$K" env32/adm '' "$W/e32.a")"; certo32 $E32/adm/a1.cfg "$W/e32.a"; a_1=$?
t_ok="$(aba -b "$J" "$B/arquivos?pasta=env32/adm&m=enviado")"; fala_ok="$(tem32 'Arquivo enviado.')"; na_lista="$(tem32 'a1.cfg')"
# O campo "Gravar com o nome" vale mais que o nome que o navegador manda.
r_2="$(NOME32='nome qualquer.TXT' manda32 "$J" $A32 "$K" env32/adm a2.cfg "$W/e32.a")"; certo32 $E32/adm/a2.cfg "$W/e32.a"; a_2=$?
# Nome que já existe: recusado, e o arquivo que estava lá fica como estava.
r_rep="$(NOME32=a1.cfg manda32 "$J" $A32 "$K" env32/adm '' "$W/e32.b")"; fala_rep="$(tem32 'Nome já usado')"; certo32 $E32/adm/a1.cfg "$W/e32.a"; a_rep=$?
# Arquivo de 3 MiB, por HTTP/2 e por HTTP/1.1.
r_h2="$(NOME32=m-h2.bin manda32 "$J" $A32 "$K" env32/adm '' "$W/e32.medio")"; v_h2="$(versao32)"; certo32 $E32/adm/m-h2.bin "$W/e32.medio"; a_h2=$?
r_h1="$(NOME32=m-h1.bin manda32 "$J" $A32 "$K" env32/adm '' "$W/e32.medio" --http1.1)"; v_h1="$(versao32)"; certo32 $E32/adm/m-h1.bin "$W/e32.medio"; a_h1=$?
# Navegador que manda o caminho junto com o nome: vale só o último pedaço.
r_win="$(NOME32='C:\fakepath\b1.cfg' manda32 "$J" $A32 "$K" env32/adm '' "$W/e32.a")"; certo32 $E32/adm/b1.cfg "$W/e32.a"; a_win=$?
r_bar="$(NOME32='sub/dir/b2.cfg' manda32 "$J" $A32 "$K" env32/adm '' "$W/e32.a")"; certo32 $E32/adm/b2.cfg "$W/e32.a"; a_bar=$?
# Arquivo vazio é arquivo; formulário sem arquivo escolhido não grava nada.
r_zero="$(NOME32=zero.cfg manda32 "$J" $A32 "$K" env32/adm '' "$W/e32.vazio")"; m_zero="$(dado32 $E32/adm/zero.cfg)"
corpo32 "$W/e32.corpo" "csrf=$K" 'pasta=env32/adm' 'nome=' 'arquivo@='
r_nada="$(cru32 "$J" $A32 "$W/e32.corpo")"; fala_nada="$(tem32 'Nenhum arquivo escolhido')"
# Até oito campos de texto antes do arquivo são aceitos.
corpo32 "$W/e32.corpo" "csrf=$K" 'pasta=env32/adm' 'nome=oito.cfg' 'a=1' 'b=2' 'c=3' 'd=4' 'e=5' "arquivo@x.cfg=$(cat "$W/e32.semfim")"
r_oito="$(cru32 "$J" $A32 "$W/e32.corpo")"; certo32 $E32/adm/oito.cfg "$W/e32.semfim"; a_oito=$?
rm -f "$W/e32.corpo"
auditoria; d_env=$(( $(eventos arquivo_enviado) - n_env ))
l_env="$(linhas32 " evento=arquivo_enviado admin=$ADMIN arquivo=env32/adm/a1\.cfg bytes=$(stat -c %s "$W/e32.a")\$")"
l_medio="$(linhas32 " evento=arquivo_enviado admin=$ADMIN arquivo=env32/adm/m-h[12]\.bin bytes=$(stat -c %s "$W/e32.medio")\$")"
adm_fim="$(nomes32 $E32/adm)"
[[ "$e_adm" == 303 && "$r_pasta" == "303 "* && "$tela" == "200 " && "$f_acao" == 1 && "$f_pasta" == 1 && "$f_arq" == 1 && "$f_nome" == 1 ]] \
  && foi32 "$r_1" && [[ "$a_1" == 0 && "$t_ok" == "200 " && "$fala_ok" -ge 1 && "$na_lista" -ge 1 ]] && foi32 "$r_2" && [[ "$a_2" == 0 \
  && "$r_rep" == "409 " && "$fala_rep" -ge 1 && "$a_rep" == 0 ]] && foi32 "$r_h2" && foi32 "$r_h1" && [[ "$v_h2" == HTTP/2 && "$v_h1" == HTTP/1.1 && "$a_h2" == 0 && "$a_h1" == 0 ]] \
  && foi32 "$r_win" && foi32 "$r_bar" && [[ "$a_win" == 0 && "$a_bar" == 0 ]] && foi32 "$r_zero" && [[ "$m_zero" == "ftpdata:ftpdata 644 0" \
  && "$r_nada" == "400 " && "$fala_nada" -ge 1 ]] && foi32 "$r_oito" && [[ "$a_oito" == 0 && "$d_env" == 8 && "$l_env" == 1 && "$l_medio" == 2 \
  && "$adm_fim" == "a1.cfg a2.cfg b1.cfg b2.cfg m-h1.bin m-h2.bin oito.cfg zero.cfg " ]]
caso $? testes 68 "Administrador envia arquivo pelo painel para a pasta aberta" "entrada do administrador: $e_adm; pasta env32/adm criada pelo painel: $r_pasta · tela da pasta: $tela, formulário para /arquivos/enviar em multipart: $f_acao, com a pasta aberta no campo oculto: $f_pasta, campo do arquivo: $f_arq, campo 'Gravar com o nome': $f_nome · envio de a1.cfg: $r_1, no servidor com dono ftpdata:ftpdata, modo 644, tamanho e conteúdo iguais: $([[ $a_1 == 0 ]] && echo sim || echo não); tela seguinte: $t_ok, com 'Arquivo enviado.': $fala_ok e o nome na lista: $na_lista · arquivo de nome 'nome qualquer.TXT' com 'Gravar com o nome' = a2.cfg: $r_2, gravado como a2.cfg: $([[ $a_2 == 0 ]] && echo sim || echo não) · a1.cfg de novo, com outro conteúdo: $r_rep, 'Nome já usado' na tela: $fala_rep, a1.cfg igual ao primeiro: $([[ $a_rep == 0 ]] && echo sim || echo não) · arquivo de $(stat -c %s "$W/e32.medio") bytes por $v_h2: $r_h2 e por $v_h1: $r_h1, os dois iguais ao original: $([[ $a_h2 == 0 && $a_h1 == 0 ]] && echo sim || echo não) · nome mandado como 'C:\\fakepath\\b1.cfg': $r_win, gravado b1.cfg: $([[ $a_win == 0 ]] && echo sim || echo não); como 'sub/dir/b2.cfg': $r_bar, gravado b2.cfg: $([[ $a_bar == 0 ]] && echo sim || echo não) · arquivo vazio: $r_zero ($m_zero) · formulário sem arquivo escolhido: $r_nada, 'Nenhum arquivo escolhido': $fala_nada · oito campos de texto antes do arquivo: $r_oito · auditoria: arquivo_enviado a mais: $d_env, linha de a1.cfg com o administrador, o caminho e os bytes: $l_env, linhas dos dois de 3 MiB: $l_medio · na pasta, no fim: $adm_fim"

# ------------------------------------------------------------------ o usuário do FTP envia só com a permissão dele
auditoria; n_rec="$(eventos recusa_envio)"; n_pap="$(eventos recusa_papel)"
sessoes32 c e l s; e_usu="$e_web"
# Completo, sem a permissão: a tela não tem o formulário e o envio é recusado.
t_c0="$(v32 c /meus-arquivos)"; c0_form="$(tem32 "action=\"$M32\"")"; c0_fala="$(tem32 'Enviar arquivo, só por FTP')"
r_c0="$(NOME32=c1.cfg m32 c '' '' "$W/e32.a")"; c0_recusa="$(tem32 'Envio não permitido')"; c0_nada="$(nomes32 $E32/c)"
# A permissão dada pelo terminal vale na hora, com a sessão dele aberta.
mu limites e32c "" enviar=1; r_lim=$?; tem_c="$(permissao32 e32c)"
t_c1="$(v32 c /meus-arquivos)"; c1_form="$(tem32 "action=\"$M32\" enctype=\"multipart/form-data\"")"; c1_fala="$(tem32 'Esta conta também envia arquivo por aqui')"
r_c1="$(NOME32=c1.cfg m32 c '' '' "$W/e32.a")"; certo32 $E32/c/c1.cfg "$W/e32.a"; a_c1=$?
r_ftp="$(ftp_curl tls e32c "$W/e32c.senha" -o "$W/e32.baixado" "$F/c1.cfg")"; cmp -s "$W/e32.baixado" "$W/e32.a"; a_ftp=$?
# Em uma pasta de dentro, criada por ele.
r_sub="$(p32 c /meus-arquivos/pasta --data-urlencode 'pasta=' --data-urlencode 'nome=sub')"
r_c2="$(NOME32=c2.cfg m32 c sub '' "$W/e32.b")"; certo32 $E32/c/sub/c2.cfg "$W/e32.b"; a_c2=$?
# Envio: permissão dada pelo painel. Nome repetido é recusado, como no FTP.
r_dar="$(envio /usuarios/limites --data-urlencode "csrf=$K" --data-urlencode 'usuario=e32e' --data-urlencode 'enviar=sim')"; tem_e="$(permissao32 e32e)"
t_edit="$(aba -b "$J" "$B/usuarios/editar?usuario=e32e")"; caixa="$(grep -c 'name="enviar" value="sim" checked' "$W/corpo" || true)"
r_e1="$(NOME32=e1.cfg m32 e '' '' "$W/e32.a")"; certo32 $E32/e/e1.cfg "$W/e32.a"; a_e1=$?
r_e2="$(NOME32=e1.cfg m32 e '' '' "$W/e32.b")"; certo32 $E32/e/e1.cfg "$W/e32.a"; a_e2=$?
# Tirar a permissão também vale na hora: pelo painel (formulário sem a caixa marcada) e pelo terminal.
r_tirar="$(envio /usuarios/limites --data-urlencode "csrf=$K" --data-urlencode 'usuario=e32e')"; sem_e="$(permissao32 e32e)"
r_e3="$(NOME32=e3.cfg m32 e '' '' "$W/e32.a")"; e3_recusa="$(tem32 'Envio não permitido')"
mu limites e32c "" enviar=; r_lim2=$?; sem_c="$(permissao32 e32c)"
r_c3="$(NOME32=c3.cfg m32 c '' '' "$W/e32.a")"
mu limites e32c "" enviar=2; r_lim3=$?; fala_lim="$(grep -c 'enviar aceita vazio ou 1' "$W/mu.log" || true)"
# Só envio: sem a permissão, a tela não tem formulário; com ela, envia, e o nome repetido ganha a data e a hora.
t_s0="$(v32 s /meus-arquivos)"; s0_form="$(tem32 "action=\"$M32\"")"; s0_fala="$(tem32 'Ela envia arquivo por FTP e mais nada.')"
r_s0="$(NOME32=s1.cfg m32 s '' '' "$W/e32.a")"
mu limites e32s "" enviar=1
t_s1="$(v32 s /meus-arquivos)"; s1_form="$(tem32 "action=\"$M32\"")"; s1_fala="$(tem32 'Ela envia arquivo, por FTP ou por esta tela, e mais nada.')"
r_s1="$(NOME32=s1.cfg m32 s '' '' "$W/e32.a")"; certo32 $E32/s/s1.cfg "$W/e32.a"; a_s1=$?
r_s2="$(NOME32=s1.cfg m32 s '' '' "$W/e32.b")"; certo32 $E32/s/s1.cfg "$W/e32.a"; a_s2=$?
com_data="$(docker exec "$FTP" ls "$E32/s" | grep -E '^s1-[0-9]{8}-[0-9]{6}\.cfg$' | head -1)"; certo32 "$E32/s/${com_data:-nenhum}" "$W/e32.b"; a_data=$?
t_s2="$(v32 s '/meus-arquivos?pasta=&m=enviado_com_data')"; s2_fala="$(tem32 'o novo foi guardado com a data e a hora no nome')"; s_nomes="$(docker exec "$FTP" ls "$E32/s" | wc -l)"
# Leitura: a permissão não muda o perfil. A tela não tem formulário e a rota de envio não existe para ele.
mu limites e32l "" enviar=1
t_l="$(v32 l /meus-arquivos)"; l_form="$(tem32 "action=\"$M32\"")"
r_l1="$(NOME32=l1.cfg m32 l '' '' "$W/e32.a")"; l_nada="$(nomes32 $E32/l)"
auditoria; d_rec=$(( $(eventos recusa_envio) - n_rec )); d_pap=$(( $(eventos recusa_papel) - n_pap ))
l_rec="$(linhas32 ' evento=recusa_envio usuario=e32c perfil=completo$')"; l_pap="$(linhas32 " evento=recusa_papel usuario=e32l caminho=$M32 perfil=leitura\$")"
l_usu="$(linhas32 " evento=arquivo_enviado usuario=e32c arquivo=env32/c/sub/c2\.cfg bytes=$(stat -c %s "$W/e32.b")\$")"
[[ "$r_c$r_e$r_l$r_s$r_v" == 00000 && "$e_usu" == "303 303 303 303 " && "$t_c0" == "200 " && "$c0_form" == 0 && "$c0_fala" -ge 1 && "$r_c0" == "403 " && "$c0_recusa" -ge 1 && -z "$c0_nada" \
  && "$r_lim" == 0 && "$tem_c" == 1 && "$t_c1" == "200 " && "$c1_form" == 1 && "$c1_fala" -ge 1 ]] && foi32 "$r_c1" && [[ "$a_c1" == 0 && "$r_ftp" == 0 && "$a_ftp" == 0 \
  && "$r_sub" == "303 "* ]] && foi32 "$r_c2" && [[ "$a_c2" == 0 && "$r_dar" == "303 "* && "$tem_e" == 1 && "$t_edit" == "200 " && "$caixa" == 1 ]] && foi32 "$r_e1" && [[ "$a_e1" == 0 \
  && "$r_e2" == "409 " && "$a_e2" == 0 && "$r_tirar" == "303 "* && "$sem_e" == 0 && "$r_e3" == "403 " && "$e3_recusa" -ge 1 && "$r_lim2" == 0 && "$sem_c" == 0 && "$r_c3" == "403 " \
  && "$r_lim3" != 0 && "$fala_lim" == 1 && "$t_s0" == "200 " && "$s0_form" == 0 && "$s0_fala" -ge 1 && "$r_s0" == "403 " && "$t_s1" == "200 " && "$s1_form" == 1 && "$s1_fala" -ge 1 ]] \
  && foi32 "$r_s1" && [[ "$a_s1" == 0 && "$r_s2" == "303 "*"&m=enviado_com_data" && "$a_s2" == 0 && -n "$com_data" && "$a_data" == 0 && "$t_s2" == "200 " && "$s2_fala" -ge 1 && "$s_nomes" == 2 \
  && "$t_l" == "200 " && "$l_form" == 0 && "$r_l1" == "404 " && -z "$l_nada" && "$d_rec" -ge 1 && "$l_rec" -ge 1 && "$d_pap" -ge 1 && "$l_pap" -ge 1 && "$l_usu" == 1 ]]
caso $? testes 69 "Usuário do FTP envia pelo painel só com a permissão dele, dentro do que o perfil deixa" "contas criadas (Completo, Envio, Leitura, Só envio e uma segunda Completo): $r_c$r_e$r_l$r_s$r_v; entradas no painel: $e_usu· Completo sem a permissão: tela $t_c0, formulário de envio: $c0_form, aviso 'Enviar arquivo, só por FTP': $c0_fala; envio: $r_c0, 'Envio não permitido': $c0_recusa, pasta dele: '$c0_nada' · permissão dada pelo terminal (limites enviar=1: saída $r_lim, na lista: $tem_c), com a mesma sessão: tela $t_c1, formulário: $c1_form; envio de c1.cfg: $r_c1, com dono ftpdata:ftpdata, modo 644 e conteúdo igual: $([[ $a_c1 == 0 ]] && echo sim || echo não); o mesmo arquivo baixado por FTP: curl $r_ftp, igual: $([[ $a_ftp == 0 ]] && echo sim || echo não) · pasta sub criada por ele: $r_sub; envio para ela: $r_c2, gravado em sub/c2.cfg: $([[ $a_c2 == 0 ]] && echo sim || echo não) · Envio com a permissão dada pelo painel (POST /usuarios/limites com enviar=sim: $r_dar, na lista: $tem_e, caixa marcada em Editar usuário: $caixa): e1.cfg: $r_e1; e1.cfg de novo, com outro conteúdo: $r_e2, o primeiro intacto: $([[ $a_e2 == 0 ]] && echo sim || echo não) · permissão tirada pelo painel ($r_tirar, na lista: $sem_e): envio seguinte $r_e3; tirada pelo terminal (saída $r_lim2, na lista: $sem_c): envio seguinte do Completo $r_c3; enviar=2 no terminal: saída $r_lim3 · Só envio sem a permissão: tela $t_s0, formulário: $s0_form, envio: $r_s0; com ela: tela $t_s1, formulário: $s1_form, s1.cfg: $r_s1; s1.cfg de novo, com outro conteúdo: $r_s2, o primeiro intacto: $([[ $a_s2 == 0 ]] && echo sim || echo não), o novo guardado com a data e a hora no nome: $([[ -n "$com_data" && $a_data == 0 ]] && echo sim || echo não), arquivos na pasta: $s_nomes; tela seguinte $t_s2 com o aviso: $s2_fala · Leitura com enviar=1: tela $t_l, formulário: $l_form, envio: $r_l1, pasta dele: '$l_nada' · auditoria: recusa_envio a mais: $d_rec (linha de e32c com o perfil: $l_rec), recusa_papel a mais: $d_pap (linha de e32l em $M32: $l_pap), arquivo_enviado de e32c com o caminho desde /data e os bytes: $l_usu"

# ------------------------------------------------------------------ pedido forjado, nome e corpo fora da regra
docker exec "$FTP" ln -s /auth $E32/adm/atalho
auditoria; n_csrf="$(eventos recusa_csrf)"; n_ori="$(eventos recusa_origem)"; n_cam="$(eventos recusa_caminho)"; n_env="$(eventos arquivo_enviado)"
arv_0="$(arvore32 $E32)"; auth_0="$(auth32)"
x_semtoken="$(NOME32=x.cfg manda32 "$J" $A32 '' env32/adm '' "$W/e32.a")"; x_semtoken_f="$(tem32 'Formulário sem token válido')"
x_errado="$(NOME32=x.cfg manda32 "$J" $A32 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' env32/adm '' "$W/e32.a")"
x_alheio="$(NOME32=x.cfg manda32 "$J" $A32 "${T32[c]}" env32/adm '' "$W/e32.a")"
x_origem="$(ORIGEM32='https://site-de-fora.example' NOME32=x.cfg manda32 "$J" $A32 "$K" env32/adm '' "$W/e32.a")"; x_origem_f="$(tem32 'O envio não partiu deste painel.')"
x_referer="$(ORIGEM32=nenhuma NOME32=x.cfg manda32 "$J" $A32 "$K" env32/adm '' "$W/e32.a" -H 'Referer: https://site-de-fora.example/pagina')"
x_sessao="$(NOME32=x.cfg manda32 "$W/e32.vazio" $A32 "$K" env32/adm '' "$W/e32.a")"
x_falso="$(NOME32=x.cfg manda32 "$W/e32.vazio" $A32 "$K" env32/adm '' "$W/e32.a" -H 'Cookie: __Host-sessao=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA')"
# Nome fora da regra, no campo "Gravar com o nome" e no nome que o navegador manda.
ev_nome=""; ok_nome=0
for v in '../fora.cfg' 'sub/x.cfg' '.oculto' 'a b.cfg' 'nome;x' 'ação.cfg' "$(printf 'n%.0s' $(seq 1 65))"; do
  r="$(NOME32=x.cfg manda32 "$J" $A32 "$K" env32/adm "$v" "$W/e32.a")"; [[ "$r" == "400 " && "$(tem32 'Nome não aceito')" -ge 1 ]] || ok_nome=1; ev_nome+="'$v': $r; "
done
for v in '.oculto' 'a b.cfg' '..' 'nome;x'; do
  r="$(NOME32="$v" manda32 "$J" $A32 "$K" env32/adm '' "$W/e32.a")"; [[ "$r" == "400 " && "$(tem32 'Nome não aceito')" -ge 1 ]] || ok_nome=1; ev_nome+="arquivo de nome '$v': $r; "
done
# Pasta de destino fora da regra, que não existe, escondida ou alcançada por link simbólico.
x_cima="$(NOME32=x.cfg manda32 "$J" $A32 "$K" '../env32' '' "$W/e32.a")"; x_cima_f="$(tem32 'Caminho não aceito.')"
x_ponto="$(NOME32=x.cfg manda32 "$J" $A32 "$K" 'env32/./adm' '' "$W/e32.a")"
x_falta="$(NOME32=x.cfg manda32 "$J" $A32 "$K" 'env32/nao-existe' '' "$W/e32.a")"
x_entrada="$(NOME32=x.cfg manda32 "$J" $A32 "$K" '.entrada' '' "$W/e32.a")"
x_link="$(NOME32=x.cfg manda32 "$J" $A32 "$K" 'env32/adm/atalho' '' "$W/e32.a")"; x_link_f="$(tem32 'Link simbólico não é seguido pelo painel.')"
x_arquivo="$(NOME32=x.cfg manda32 "$J" $A32 "$K" 'env32/adm/a1.cfg' '' "$W/e32.a")"
# Corpo fora da forma que o formulário manda.
x_tipo="$(c -o "$W/corpo" -w '%{http_code}' -b "$J" -H "Origin: $B" --data-urlencode "csrf=$K" --data-urlencode 'pasta=env32/adm' --data-urlencode 'nome=x.cfg' "$B$A32")"; x_tipo_f="$(tem32 'Formato de envio não aceito.')"
# Em pedaços, o corpo chega ao painel sem tamanho declarado. O arquivo é o de 3 MiB: corpo que cabe inteiro na
# primeira leitura do nginx é repassado por ele já com o tamanho.
x_semtam="$(NOME32=x.cfg manda32 "$J" $A32 "$K" env32/adm '' "$W/e32.medio" --http1.1 -H 'Transfer-Encoding: chunked')"; x_semtam_f="$(tem32 'Envio sem tamanho declarado.')"
corpo32 "$W/e32.corpo" "csrf=$K" 'pasta=env32/adm' 'nome=x.cfg' "arquivo@x.cfg=$(cat "$W/e32.semfim")"
x_marca="$(cru32 "$J" $A32 "$W/e32.corpo" | cut -c1-3)"   # corpo escrito à mão, com tamanho: é aceito (prova que a forma dos corpos seguintes está certa)
docker exec "$FTP" rm -f $E32/adm/x.cfg
corpo32 "$W/e32.corpo" "arquivo@x.cfg=$(cat "$W/e32.semfim")" "csrf=$K" 'pasta=env32/adm' 'nome=x.cfg'
x_ordem="$(cru32 "$J" $A32 "$W/e32.corpo")"
ev_mal=""; ok_mal=0
mal32() { # <descrição> <partes do corpo...>: o corpo tem de ser recusado como malformado
  local nome="$1" r; shift
  corpo32 "$W/e32.corpo" "$@"; r="$(cru32 "$J" $A32 "$W/e32.corpo")"
  [[ "$r" == "400 " && "$(tem32 'Envio malformado.')" -ge 1 ]] || ok_mal=1; ev_mal+="$nome: $r; "
}
mal32 'campo repetido' "csrf=$K" 'pasta=env32/adm' 'pasta=env32/c' 'nome=x.cfg' 'arquivo@x.cfg=conteudo'
mal32 'nove campos de texto' "csrf=$K" 'pasta=env32/adm' 'nome=x.cfg' 'a=1' 'b=2' 'c=3' 'd=4' 'e=5' 'f=6' 'arquivo@x.cfg=conteudo'
mal32 'arquivo em campo de outro nome' "csrf=$K" 'pasta=env32/adm' 'nome=x.cfg' 'outro@x.cfg=conteudo'
mal32 'nome de campo fora da regra' "csrf=$K" 'pasta=env32/adm' 'Nome=x.cfg' 'arquivo@x.cfg=conteudo'
mal32 'campo de texto de 5000 bytes' "csrf=$K" "pasta=$(printf 'p%.0s' $(seq 1 5000))" 'nome=x.cfg' 'arquivo@x.cfg=conteudo'
mal32 'sem o arquivo' "csrf=$K" 'pasta=env32/adm' 'nome=x.cfg'
printf -- '--lim32\r\nContent-Disposition: form-data; name="csrf"\r\n\r\n%s\r\n--lim32\r\nContent-Disposition: form-data; name="arquivo"; filename="x.cfg"\r\n\r\nconteudo' "$K" > "$W/e32.corpo"
r="$(cru32 "$J" $A32 "$W/e32.corpo")"; [[ "$r" == "400 " ]] || ok_mal=1; ev_mal+="corpo sem o fecho: $r; "
printf 'isto não é multipart\r\n' > "$W/e32.corpo"
r="$(cru32 "$J" $A32 "$W/e32.corpo")"; [[ "$r" == "400 " && "$(tem32 'Envio malformado.')" -ge 1 ]] || ok_mal=1; ev_mal+="corpo sem a marca: $r; "
rm -f "$W/e32.corpo"
auditoria; d_csrf=$(( $(eventos recusa_csrf) - n_csrf )); d_ori=$(( $(eventos recusa_origem) - n_ori )); d_cam=$(( $(eventos recusa_caminho) - n_cam )); d_env=$(( $(eventos arquivo_enviado) - n_env ))
l_csrf="$(linhas32 " evento=recusa_csrf caminho=$A32\$")"; l_ori="$(linhas32 " evento=recusa_origem caminho=$A32\$")"
arv_1="$(arvore32 $E32)"; auth_1="$(auth32)"; x_sobra="$(docker exec "$FTP" sh -c 'find /data/env32 /auth -name "x.cfg" -o -name "fora.cfg" -o -name ".oculto" | wc -l')"
docker exec "$FTP" rm -f $E32/adm/atalho
# A auditoria guarda uma linha por minuto de cada tipo de recusa do mesmo endereço: a conta é de pelo menos uma.
[[ "$x_semtoken" == "403 " && "$x_semtoken_f" -ge 1 && "$x_errado" == "403 " && "$x_alheio" == "403 " && "$x_origem" == "403 " && "$x_origem_f" -ge 1 && "$x_referer" == "403 " \
  && "$x_sessao" == "303 /entrar" && "$x_falso" == "303 /entrar" && "$ok_nome" == 0 && "$x_cima" == "400 " && "$x_cima_f" -ge 1 && "$x_ponto" == "400 " && "$x_falta" == "404 " && "$x_entrada" == "404 " \
  && "$x_link" == "403 " && "$x_link_f" -ge 1 && "$x_arquivo" == "404 " && "$x_tipo" == 415 && "$x_tipo_f" -ge 1 && "$x_semtam" == "411 " && "$x_semtam_f" -ge 1 && "$x_marca" == 303 \
  && "$x_ordem" == "403 " && "$ok_mal" == 0 && "$d_csrf" -ge 1 && "$l_csrf" -ge 1 && "$d_ori" -ge 1 && "$l_ori" -ge 1 && "$d_cam" -ge 1 && "$d_env" == 1 \
  && -n "$arv_0" && "$arv_0" == "$arv_1" && "$auth_0" == "$auth_1" && "$x_sobra" == 0 ]]
caso $? seguranca 119 "Envio pelo painel recusa pedido forjado, nome fora da regra e corpo malformado" "com a sessão do administrador, POST /arquivos/enviar · sem token: $x_semtoken, com token errado: $x_errado, com o token de outra sessão: $x_alheio; Origin de outro site: $x_origem; sem Origin e com Referer de outro site: $x_referer; sem sessão: $x_sessao; com cookie inventado: $x_falso · nome fora da regra, todos com 400 e 'Nome não aceito': $ev_nome· pasta de destino com '..': $x_cima, com '.': $x_ponto, que não existe: $x_falta, a área de entrada do Só envio: $x_entrada, por link simbólico para /auth: $x_link, que é um arquivo: $x_arquivo · corpo que não é multipart (urlencoded): $x_tipo; sem tamanho declarado (3 MiB em pedaços, HTTP/1.1): $x_semtam, com 'Envio sem tamanho declarado.': $x_semtam_f; corpo escrito à mão, com tamanho: $x_marca; arquivo antes dos campos (o token não é lido): $x_ordem · corpo malformado, todos com 400: $ev_mal· auditoria: recusa_csrf a mais: $d_csrf, recusa_origem a mais: $d_ori, recusa_caminho a mais: $d_cam, arquivo_enviado a mais: $d_env (só o do corpo aceito, apagado em seguida) · soma de /data/env32 antes $arv_0 e depois $arv_1; de /auth antes $auth_0 e depois $auth_1; arquivos das tentativas no disco: $x_sobra"

# ------------------------------------------------------------------ o envio não sai da pasta de quem envia
mu limites e32c "" enviar=1; mu limites e32e "" enviar=1
sessoes32 v; e_v="$e_web"
docker exec "$FTP" sh -c "ln -s $E32/e $E32/c/vizinho && ln -s /auth $E32/c/cadastro"
e_0="$(arvore32 $E32/e $E32/adm $E32/l $E32/v)"; auth_0="$(auth32)"; c_0="$(nomes32 $E32/c)"; s_0="$(docker exec "$FTP" ls "$E32/s" | wc -l)"
ev_fuga=""; ok_fuga=0
for v in '..' '../e' '../../auth' '../../../etc' 'sub/../../e' '/data/env32/e' '/etc' 'env32/e' 'vizinho' 'cadastro' 'sub/../vizinho' '%2e%2e/e' '..%2fe' '....//e' '..\e'; do
  r="$(NOME32=invasor.cfg m32 c "$v" '' "$W/e32.a" | cut -c1-3)"; [[ "$r" == 400 || "$r" == 403 || "$r" == 404 ]] || ok_fuga=1; ev_fuga+="'$v': $r; "
done
for v in '../e/invasor.cfg' '..' 'vizinho/invasor.cfg' '/data/env32/e/invasor.cfg' '..\e\invasor.cfg'; do
  r="$(NOME32=x.cfg m32 c '' "$v" "$W/e32.a" | cut -c1-3)"; [[ "$r" == 400 ]] || ok_fuga=1; ev_fuga+="gravar como '$v': $r; "
done
# A rota do administrador não existe para o usuário; o token de uma conta não vale na sessão de outra.
z_adm="$(NOME32=invasor.cfg manda32 "$W/e32c.jar" $A32 "${T32[c]}" env32/e '' "$W/e32.a")"
z_token="$(NOME32=invasor.cfg manda32 "$W/e32e.jar" $M32 "${T32[c]}" '' '' "$W/e32.a")"
z_admtoken="$(NOME32=invasor.cfg manda32 "$W/e32c.jar" $M32 "$K" '' '' "$W/e32.a")"
# Só envio: o campo da pasta não é lido; o arquivo fica na pasta dele.
z_so="$(NOME32=so-fuga.cfg m32 s '../c' '' "$W/e32.a")"; certo32 $E32/s/so-fuga.cfg "$W/e32.a"; a_so=$?
z_so2="$(NOME32=so-fuga2.cfg m32 s '/data/env32/e' '' "$W/e32.a")"; certo32 $E32/s/so-fuga2.cfg "$W/e32.a"; a_so2=$?
# Conta sem a permissão não a ganha mandando o campo junto.
z_semperm="$(NOME32=invasor.cfg manda32 "$W/e32v.jar" $M32 "${T32[v]}" '' '' "$W/e32.a" --form-string 'enviar=sim' --form-string 'perfil=administrador' --form-string 'usuario=e32c')"; tem_v="$(permissao32 e32v)"
# O envio certo, na própria pasta, continua valendo.
z_certo="$(NOME32=meu.cfg m32 c sub '' "$W/e32.a")"; certo32 $E32/c/sub/meu.cfg "$W/e32.a"; a_certo=$?
docker exec "$FTP" rm -f $E32/c/vizinho $E32/c/cadastro
e_1="$(arvore32 $E32/e $E32/adm $E32/l $E32/v)"; auth_1="$(auth32)"; c_1="$(nomes32 $E32/c)"; s_1="$(docker exec "$FTP" ls "$E32/s" | wc -l)"
invasores="$(docker exec "$FTP" sh -c 'find /data /auth /etc /tmp -xdev \( -name "invasor*" -o -name "x.cfg" \) 2>/dev/null | wc -l')"
[[ "$ok_fuga" == 0 && "$z_adm" == "404 " && "$z_token" == "403 " && "$z_admtoken" == "403 " ]] && foi32 "$z_so" && foi32 "$z_so2" && [[ "$a_so" == 0 && "$a_so2" == 0 \
  && "$e_v" == "303 " && "$z_semperm" == "403 " && "$tem_v" == 0 ]] && foi32 "$z_certo" && [[ "$a_certo" == 0 && -n "$e_0" && "$e_0" == "$e_1" && "$auth_0" == "$auth_1" \
  && "$c_0" == "c1.cfg cadastro sub vizinho " && "$c_1" == "c1.cfg sub " && "$s_1" == $((s_0 + 2)) && "$invasores" == 0 ]]
caso $? seguranca 120 "Envio pelo painel não sai da pasta de quem envia" "e32c (Completo, com a permissão) e, na pasta dele, dois links simbólicos plantados: um para a pasta de e32e e um para /auth · pasta de destino pedida, todas recusadas (400, 403 ou 404): $ev_fuga· rota do administrador com a sessão e o token dele: $z_adm; token de e32c na sessão de e32e: $z_token; token do administrador na sessão de e32c: $z_admtoken · Só envio pedindo a pasta '../c': $z_so, gravado na pasta dele: $([[ $a_so == 0 ]] && echo sim || echo não); pedindo '/data/env32/e': $z_so2, na pasta dele: $([[ $a_so2 == 0 ]] && echo sim || echo não) · conta sem a permissão (entrada $e_v) mandando os campos enviar=sim, perfil=administrador e usuario=e32c: $z_semperm, permissão na lista depois: $tem_v · envio certo, para a pasta sub dele: $z_certo · soma das pastas das outras contas antes $e_0 e depois $e_1; de /auth antes $auth_0 e depois $auth_1; pasta de e32c antes '$c_0' e depois '$c_1'; arquivos na de e32s: $s_0 e $s_1; arquivos das tentativas em /data, /auth, /etc e /tmp: $invasores"

# ------------------------------------------------------------------ um envio por conta, quatro no painel, envio cortado
for n in c e s v; do mu limites "e32$n" "" enviar=1 envio=8; done
sessoes32 c e s v; e_lento="$e_web"
auditoria; n_cor="$(eventos envio_interrompido)"; n_env="$(eventos arquivo_enviado)"
inicio=$SECONDS
for n in c e s v; do
  ( NOME32="lento-$n.bin" PRAZO32=90 CORPO32="$W/e32.$n.corpo" CAB32="$W/e32.$n.cab" m32 "$n" '' '' "$W/e32.lento" > "$W/e32.$n.r" 2>&1 ) &
done
sleep 4
# Com os quatro em curso (160 KB a 8 KB/s, 20 s cada): a mesma conta não envia outro, e o painel não aceita um quinto.
q_conta="$(NOME32=outro.bin PRAZO32=20 m32 c '' '' "$W/e32.a")"; q_conta_f="$(tem32 'Esta conta envia um arquivo por vez.')"; q_conta_r="$(grep -c -i '^retry-after: 30' "$W/cab32" || true)"
q_quinto="$(NOME32=quinto.bin PRAZO32=20 manda32 "$J" $A32 "$K" env32/adm '' "$W/e32.a")"; q_quinto_f="$(tem32 'O painel recebe até 4 arquivos por vez.')"; q_quinto_r="$(grep -c -i '^retry-after: 30' "$W/cab32" || true)"
q_tela="$(aba -b "$J" "$B/arquivos?pasta=env32/adm")"; q_usu="$(v32 e /meus-arquivos)"; q_saude="$(c -o /dev/null -w '%{http_code}' "$B/saude")"
q_meio="$(docker exec "$FTP" sh -c 'find /data/env32 -name "lento-*" -o -name "outro.bin" -o -name "quinto.bin" | wc -l')"
wait
duracao=$((SECONDS - inicio)); q_r=""; q_iguais=0
for n in c e v; do q_r+="$(cat "$W/e32.$n.r") "; certo32 "$E32/$n/lento-$n.bin" "$W/e32.lento" || q_iguais=1; done
q_r+="$(cat "$W/e32.s.r") "; certo32 "$E32/s/lento-s.bin" "$W/e32.lento" || q_iguais=1
# Terminados os quatro, as vagas voltam.
q_depois="$(NOME32=quinto.bin manda32 "$J" $A32 "$K" env32/adm '' "$W/e32.a")"
# Envio cortado no meio: nada é gravado, a auditoria registra, e a vaga da conta volta.
inicio=$SECONDS
q_corte="$(NOME32=cortado.bin PRAZO32=3 m32 c '' '' "$W/e32.lento")"; t_corte=$((SECONDS - inicio))
ate32() { local fim=$((SECONDS + $1)); shift; until "$@"; do (( SECONDS < fim )) || return 1; sleep 0.5; done; }
registrou32() { auditoria; [[ $(( $(eventos envio_interrompido) - n_cor )) -ge 1 ]]; }
ate32 15 registrou32; r_reg=$?
l_cor="$(linhas32 ' evento=envio_interrompido usuario=e32c arquivo=env32/c/cortado\.bin bytes=163840$')"
q_resto="$(docker exec "$FTP" sh -c 'find /data/env32 -name "cortado*" | wc -l')"; q_semnome="$(nomes32 $E32/c)"
# A taxa fica na linha do usuário no cadastro do FTP: mudá-la encerra a sessão dele no painel, como qualquer mudança da linha.
for n in c e s v; do mu limites "e32$n" "" envio=; done
q_caiu="$(NOME32=depois.cfg m32 c '' '' "$W/e32.a")"; sessoes32 c; e_volta="$e_web"
q_volta="$(NOME32=depois.cfg m32 c '' '' "$W/e32.a")"; certo32 $E32/c/depois.cfg "$W/e32.a"; a_volta=$?
auditoria; d_env=$(( $(eventos arquivo_enviado) - n_env ))
[[ "$e_lento" == "303 303 303 303 " && "$q_conta" == "503 " && "$q_conta_f" -ge 1 && "$q_conta_r" == 1 && "$q_quinto" == "503 " && "$q_quinto_f" -ge 1 && "$q_quinto_r" == 1 \
  && "$q_tela" == "200 " && "$q_usu" == "200 " && "$q_saude" == 200 && "$q_meio" == 0 && "$duracao" -ge 15 && "$duracao" -le 60 && "$q_iguais" == 0 \
  && "$q_r" == "303 /meus-arquivos?pasta=&m=enviado 303 /meus-arquivos?pasta=&m=enviado 303 /meus-arquivos?pasta=&m=enviado 303 /meus-arquivos?pasta=&m=enviado " ]] \
  && foi32 "$q_depois" && [[ "$q_corte" != 303* && "$t_corte" -le 6 && "$r_reg" == 0 && "$l_cor" == 1 && "$q_resto" == 0 && "$q_semnome" == "c1.cfg lento-c.bin sub " ]] \
  && [[ "$q_caiu" == "303 /entrar" && "$e_volta" == "303 " ]] && foi32 "$q_volta" && [[ "$a_volta" == 0 && "$d_env" == 6 ]]
caso $? seguranca 121 "Envio pelo painel: um por conta, quatro no painel, e envio cortado não deixa resto" "quatro contas com a taxa de envio de 8 KB/s (entradas: $e_lento) enviando 163840 bytes ao mesmo tempo · com os quatro em curso · outro envio da mesma conta: $q_conta, 'Esta conta envia um arquivo por vez.': $q_conta_f, Retry-After de 30: $q_conta_r; quinto envio, do administrador: $q_quinto, 'O painel recebe até 4 arquivos por vez.': $q_quinto_f, Retry-After de 30: $q_quinto_r; tela do administrador: $q_tela, tela de outro usuário: $q_usu, /saude: $q_saude; arquivos em envio com nome no disco: $q_meio · os quatro: $q_r, em $duracao s, todos com dono ftpdata:ftpdata, modo 644 e conteúdo igual: $([[ $q_iguais == 0 ]] && echo sim || echo não) · depois deles, o envio do administrador: $q_depois · envio de e32c cortado aos 3 s (curl: '$q_corte', em $t_corte s): linha envio_interrompido com a conta, o caminho e os 163840 bytes: $l_cor, arquivos 'cortado' no disco: $q_resto, pasta dele: '$q_semnome' · taxas tiradas (a linha do cadastro mudou): envio com a sessão de antes $q_caiu, nova entrada $e_volta, envio seguinte de e32c: $q_volta · auditoria: arquivo_enviado a mais: $d_env"

# ------------------------------------------------------------------ tamanho máximo do arquivo
max_0="$(env_file="$ENVA" env_valor PAINEL_ENVIO_MAX_MB 1024)"
gravar_env "$ENVA" PAINEL_ENVIO_MAX_MB 1
dep; r_dep=$?; saude_1="$(saude "$FTP" "$PAINEL" "$NGINX")"; painel_de_pe
e_max="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
sessoes32 c; e_max_c="$e_web"
head -c 1048576 /dev/urandom > "$W/e32.exato"; head -c 1048577 /dev/urandom > "$W/e32.passa"; head -c 1600000 /dev/urandom > "$W/e32.meio"
t_max="$(aba -b "$J" "$B/arquivos?pasta=env32/adm")"; max_fala="$(grep -c -E 'Até 1,0.{1,8}MiB por arquivo' "$W/corpo" || true)"
g_exato="$(NOME32=exato.bin manda32 "$J" $A32 "$K" env32/adm '' "$W/e32.exato")"; certo32 $E32/adm/exato.bin "$W/e32.exato"; a_exato=$?
g_passa="$(NOME32=passa.bin manda32 "$J" $A32 "$K" env32/adm '' "$W/e32.passa")"; g_passa_f="$(tem32 'Arquivo grande demais')"; g_passa_v="$(versao32)"
g_passa1="$(NOME32=passa.bin manda32 "$J" $A32 "$K" env32/adm '' "$W/e32.passa" --http1.1)"; g_passa1_f="$(tem32 'Arquivo grande demais')"; g_passa1_v="$(versao32)"
g_meio="$(NOME32=meio.bin manda32 "$J" $A32 "$K" env32/adm '' "$W/e32.meio")"; g_meio_f="$(tem32 'Arquivo grande demais')"
# Acima do que o nginx deixa passar (o máximo mais 1 MiB), quem recusa é ele, antes do painel.
g_nginx="$(NOME32=grande.bin manda32 "$J" $A32 "$K" env32/adm '' "$W/e32.medio" | cut -c1-3)"; g_nginx_f="$(tem32 'arquivo grande demais para o envio pelo painel')"
g_nginx1="$(NOME32=grande.bin manda32 "$J" $A32 "$K" env32/adm '' "$W/e32.medio" --http1.1 | cut -c1-3)"; g_nginx1_f="$(tem32 'arquivo grande demais para o envio pelo painel')"
# O usuário do FTP tem o mesmo teto.
g_usu="$(NOME32=passa.bin m32 c '' '' "$W/e32.passa")"; g_usu_n="$(NOME32=grande.bin m32 c '' '' "$W/e32.medio" | cut -c1-3)"
g_usu_ok="$(NOME32=exato.bin m32 c '' '' "$W/e32.exato")"; certo32 $E32/c/exato.bin "$W/e32.exato"; a_usu=$?
# Fora das rotas de envio, o teto do corpo continua o de formulário.
g_outra="$(c -o /dev/null -w '%{http_code}' -b "$J" -H "Origin: $B" --data-urlencode "csrf=$K" --data-urlencode 'pasta=env32/adm' --data-urlencode "nome=$(printf 'n%.0s' $(seq 1 20000))" "$B/arquivos/pasta")"
g_disco="$(docker exec "$FTP" sh -c 'find /data/env32 -name "passa.bin" -o -name "meio.bin" -o -name "grande.bin" | wc -l')"
ev_rec=""; ok_rec=0
for valor in 0 102401 abc -1 1.5; do
  rec="$(recusa_container painel "PAINEL_ENVIO_MAX_MB=$valor")"; recusou "$rec" 'PAINEL_ENVIO_MAX_MB deve ficar entre 1 e 102400' || ok_rec=1; ev_rec+="painel com $valor: $rec; "
  rec="$(recusa_container nginx "PAINEL_ENVIO_MAX_MB=$valor")"; recusou "$rec" 'PAINEL_ENVIO_MAX_MB deve ficar entre 1 e 102400' || ok_rec=1; ev_rec+="nginx com $valor: $rec; "
done
gravar_env "$ENVA" PAINEL_ENVIO_MAX_MB "$max_0"
dep; r_fim=$?; saude_fim="$(saude "$FTP" "$PAINEL" "$NGINX")"; painel_de_pe
e_fim="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
g_volta="$(NOME32=volta.bin manda32 "$J" $A32 "$K" env32/adm '' "$W/e32.medio")"; certo32 $E32/adm/volta.bin "$W/e32.medio"; a_volta=$?
[[ "$r_dep" == 0 && "$saude_1" == "healthy healthy healthy " && "$e_max" == 303 && "$e_max_c" == "303 " && "$t_max" == "200 " && "$max_fala" -ge 1 ]] && foi32 "$g_exato" && [[ "$a_exato" == 0 \
  && "$g_passa" == "413 " && "$g_passa_f" -ge 1 && "$g_passa_v" == HTTP/2 && "$g_passa1" == "413 " && "$g_passa1_f" -ge 1 && "$g_passa1_v" == HTTP/1.1 && "$g_meio" == "413 " && "$g_meio_f" -ge 1 \
  && "$g_nginx" == 413 && "$g_nginx_f" -ge 1 && "$g_nginx1" == 413 && "$g_nginx1_f" -ge 1 && "$g_usu" == "413 " && "$g_usu_n" == 413 ]] && foi32 "$g_usu_ok" && [[ "$a_usu" == 0 \
  && "$g_outra" == 413 && "$g_disco" == 0 && "$ok_rec" == 0 && "$r_fim" == 0 && "$saude_fim" == "healthy healthy healthy " && "$e_fim" == 303 ]] && foi32 "$g_volta" && [[ "$a_volta" == 0 ]]
caso $? seguranca 122 "Envio pelo painel respeita o tamanho máximo, no painel e no nginx" "deploy.sh com PAINEL_ENVIO_MAX_MB=1 (antes: $max_0): saída $r_dep, saúde $saude_1· tela da pasta: $t_max, com 'Até 1,0 MiB por arquivo.': $max_fala · arquivo de 1048576 bytes: $g_exato, igual no servidor: $([[ $a_exato == 0 ]] && echo sim || echo não) · de 1048577 bytes por $g_passa_v: $g_passa, 'Arquivo grande demais': $g_passa_f; por $g_passa1_v: $g_passa1, aviso: $g_passa1_f; de 1600000 bytes: $g_meio, aviso: $g_meio_f · de $(stat -c %s "$W/e32.medio") bytes, acima do que o nginx repassa: $g_nginx por HTTP/2 e $g_nginx1 por HTTP/1.1, com o texto do nginx 'arquivo grande demais para o envio pelo painel': $g_nginx_f e $g_nginx1_f · usuário do FTP com a permissão: 1048577 bytes $g_usu, 3 MiB $g_usu_n, 1048576 bytes $g_usu_ok · POST /arquivos/pasta com corpo de 20 KB: $g_outra · arquivos recusados no disco: $g_disco · valor fora de 1 a 102400, containers que não sobem: $ev_rec· deploy.sh com o valor de antes: saída $r_fim, saúde $saude_fim; arquivo de 3 MiB depois: $g_volta"

for n in c e l s v; do mu del "e32$n"; done
docker exec "$FTP" rm -rf /data/env32
rm -f "$W"/e32.* "$W"/e32?.jar
