#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa AE: idioma das telas. Português por padrão e inglês pelo botão, na tela de entrada (cookie do navegador)
# e depois dela (escolha gravada por conta); todas as telas de administrador e de usuário do FTP em inglês, sem
# sobra de português; a troca recusada sem token, de outra origem e com idioma que não existe; o cookie, que não
# vale como sessão; e a volta, que só leva a tela do próprio painel.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel zera a contagem de falhas de entrada e das recusas e encerra as sessões.
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"

I31="$W/i31.jar"; J31="$W/j31.jar"; N31="$W/n31.jar"; A31="$W/a31.jar"; BLOQUEADO31=203.0.113.31
COOKIE31='__Host-idioma=%s; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=31536000'
lingua31() { sed -n 's/.*<html lang="\([^"]*\)".*/\1/p' "${1:-$W/corpo}" | head -1; }                  # [arquivo] → valor de lang da página
ficha31() { sed -n 's/.*name="token" value="\([^"]*\)".*/\1/p' "$1" | head -1; }                      # <arquivo>: token do formulário de entrada
token31() { c -b "$1" "$B/meus-arquivos" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1; }  # <pote>: token dos formulários do usuário do FTP
apertado31() { grep -o 'name="idioma" value="[a-z]*" lang="[A-Za-z-]*" title="[^"]*" aria-pressed="true"' "${1:-$W/corpo}" | cut -d '"' -f 4 | tr '\n' ' '; }  # botão de idioma marcado
biscoito31() { grep -i '^set-cookie:' "${1:-$W/i31.cab}" | tr -d '\r' | cut -d ' ' -f 2- | tr '\n' '|'; }  # [cabeçalhos] → os cookies da resposta
gravado31() { docker exec "$PAINEL" sh -c 'cat /painel/idiomas 2>/dev/null' | tr '\n' ' '; }          # escolhas gravadas, uma por conta
tem31() { grep -c -F -- "$1" "${2:-$W/corpo}"; }                                                     # <trecho> [arquivo]: linhas com ele
tem_linha31() { [[ " $1" == *" $2 "* ]]; }                                                              # <escolhas gravadas> <linha>
# <arquivo>: o que sobrou de português na tela, fora do botão de idioma (letra acentuada e palavras de tela)
resto31() {
  sed -e 's/<form class="idioma".*English<\/span><\/button><\/div><\/form>//' "${1:-$W/corpo}" > "$W/i31.limpo"
  { grep -o -E '[A-Za-z]*(á|à|â|ã|é|ê|í|ó|ô|õ|ú|ç|Á|À|Â|Ã|É|Ê|Í|Ó|Ô|Õ|Ú|Ç)[A-Za-z]*' "$W/i31.limpo"
    grep -o -w -E 'Senha|Entrar|Sair|Arquivos|Arquivo|Pasta|Pastas|Nome|Novo|Nova|Editar|Remover|Criar|Salvar|Cancelar|Voltar|Apagar|Renomear|Baixar|Abrir|Buscar|Atividade|Bloqueios|Servidor|Perfil|Completo|Envio|Leitura|Tamanho|Quando|Detalhe|Origem|Prazo|Desde|Hoje' "$W/i31.limpo"
  } | sort -u | head -8 | tr '\n' ' '
}
# <pote> <idioma> [opções do curl...] → "código destino", de quem ainda não entrou; cabeçalhos em i31.cab
fora31() {
  local pote="$1" lingua="$2"; shift 2
  c -b "$pote" -c "$pote" -o "$W/i31.entrada" "$B/entrar"
  c -o /dev/null -D "$W/i31.cab" -w '%{http_code} %{redirect_url}' -b "$pote" -c "$pote" -H "Origin: $B" \
    --data-urlencode "token=$(ficha31 "$W/i31.entrada")" --data-urlencode "idioma=$lingua" "$@" "$B/idioma" | sed "s|$B||"
}
# <pote> <token> <idioma> [opções do curl...] → "código destino", com sessão; corpo em $W/corpo e cabeçalhos em i31.cab
troca31() {
  local pote="$1" ficha="$2" lingua="$3"; shift 3
  c -o "$W/corpo" -D "$W/i31.cab" -w '%{http_code} %{redirect_url}' -b "$pote" -c "$pote" -H "Origin: $B" \
    --data-urlencode "csrf=$ficha" --data-urlencode "idioma=$lingua" "$@" "$B/idioma" | sed "s|$B||"
}
# <pote> <códigos aceitos> <caminhos...>: cada tela tem de vir em inglês e sem sobra; os desvios ficam em $ev31
ver31() {
  local pote="$1" aceitos="$2" caminho r l s; shift 2
  for caminho in "$@"; do
    r="$(aba -b "$pote" "$B$caminho")"; l="$(lingua31)"; s="$(resto31)"; telas31=$((telas31 + 1))
    [[ "$r" =~ ^($aceitos)\ $ && "$l" == en && -z "$s" ]] || { ruins31=$((ruins31 + 1)); ev31+="$caminho: $r· lang=$l · sobras: ${s:-nenhuma}; "; }
  done
}

for n in id31c id31e id31l id31s a31 errada31; do nova_senha "$W/$n.senha"; done
mu add id31c "$W/id31c.senha" idioma31/a; r_u1=$?
mu add id31e "$W/id31e.senha" idioma31/a envio; r_u2=$?
mu add id31l "$W/id31l.senha" idioma31/a leitura; r_u3=$?
mu add id31s "$W/id31s.senha" idioma31/b soenvio; r_u4=$?
r_f="$(ftp_curl tls id31c "$W/id31c.senha" --ftp-create-dirs -T "$W/envio.bin" "$F/sub/backup.cfg")"
mu endereco-bloquear "$BLOQUEADO31" "" 2; r_b=$?
arq_0="$(gravado31)"

# ------------------------------------------------------------------ tela de entrada: o navegador guarda a escolha
rm -f "$I31"
c -b "$I31" -c "$I31" -D "$W/i31.cab" -o "$W/corpo" "$B/entrar"
pt_lang="$(lingua31)"; pt_titulo="$(tem31 '<h1>Entrar no painel</h1>')"; pt_botao="$(apertado31)"; pt_cookie="$(biscoito31)"
campos="$(grep -o 'name="token" value="[^"]*"' "$W/corpo" | wc -l)"; fichas="$(grep -o 'name="token" value="[^"]*"' "$W/corpo" | sort -u | wc -l)"
r_en="$(fora31 "$I31" en)"; c_en="$(biscoito31)"
c -b "$I31" -o "$W/corpo" "$B/entrar"
en_lang="$(lingua31)"; en_titulo="$(tem31 '<h1>Sign in to the panel</h1>')"; en_botao="$(apertado31)"; en_resto="$(resto31)"
# Senha errada com a tela em inglês: a recusa também sai em inglês (falha 1 desta etapa).
r_erro="$(c -o "$W/corpo" -w '%{http_code}' -b "$I31" -H "Origin: $B" --data-urlencode "token=$(ficha31 "$W/corpo")" \
  --data-urlencode "usuario=$ADMIN" --data-urlencode "senha@$W/errada31.senha" "$B/entrar")"
erro_lang="$(lingua31)"; erro_texto="$(tem31 'Could not sign in.')"; erro_resto="$(resto31)"
r_pt="$(fora31 "$I31" pt)"; c_pt="$(biscoito31)"
c -b "$I31" -o "$W/corpo" "$B/entrar"; volta_lang="$(lingua31)"; volta_botao="$(apertado31)"
[[ "$e_adm" == 303 && "$pt_lang" == pt-BR && "$pt_titulo" == 1 && "$pt_botao" == "pt " && -z "$pt_cookie" && "$campos" == 2 && "$fichas" == 1 \
  && "$r_en" == "303 /entrar" && "$c_en" == "$(printf "$COOKIE31" en)|" && "$en_lang" == en && "$en_titulo" == 1 && "$en_botao" == "en " && -z "$en_resto" \
  && "$r_erro" == 401 && "$erro_lang" == en && "$erro_texto" == 1 && -z "$erro_resto" \
  && "$r_pt" == "303 /entrar" && "$c_pt" == "$(printf "$COOKIE31" pt)|" && "$volta_lang" == pt-BR && "$volta_botao" == "pt " ]]
caso $? testes 63 "Idioma na tela de entrada: português por padrão, inglês pelo botão e de volta" "GET /entrar sem cookie: lang=$pt_lang, título em português: $pt_titulo, botão marcado: $pt_botao, cookies na resposta: ${pt_cookie:-nenhum}, campos token: $campos com $fichas valor · POST /idioma com o token do formulário e idioma=en: $r_en, Set-Cookie: $c_en · tela de entrada depois: lang=$en_lang, título em inglês: $en_titulo, botão marcado: $en_botao, sobras de português: ${en_resto:-nenhuma} · senha errada com a tela em inglês: $r_erro, lang=$erro_lang, recusa em inglês: $erro_texto, sobras: ${erro_resto:-nenhuma} · POST /idioma com idioma=pt: $r_pt, Set-Cookie: $c_pt · tela de entrada depois: lang=$volta_lang, botão marcado: $volta_botao"

# ------------------------------------------------------------------ depois da entrada: a escolha é da conta
e_2="$(entrar "$J31" "$W/painel.senha")"; proibir "$(biscoito_de "$J31")"          # segunda sessão do administrador, aberta antes da troca
e_c="$(COMO=id31c entrar "$W/id31c.jar" "$W/id31c.senha")"; proibir "$(biscoito_de "$W/id31c.jar")"; KC="$(token31 "$W/id31c.jar")"; proibir "$KC"
t_antes="$(aba -b "$J" "$B/usuarios")"; antes_lang="$(lingua31)"; antes_botao="$(apertado31)"
r_t1="$(troca31 "$J" "$K" en -e "$B/bloqueios?q=203&m=liberado")"; c_t1="$(biscoito31)"
arq_1="$(gravado31)"; modo_1="$(docker exec "$PAINEL" stat -c '%a' /painel/idiomas 2>&1)"
t_1="$(aba -b "$J" "$B/usuarios")"; l_1="$(lingua31)"; b_1="$(apertado31)"; h_1="$(tem31 '<h1 class="titulo-aba">Users</h1>')"
t_2="$(aba -b "$J31" "$B/usuarios")"; l_2="$(lingua31)"
t_c="$(aba -b "$W/id31c.jar" "$B/meus-arquivos")"; l_c="$(lingua31)"
# Entrada nova, em navegador que nunca escolheu: vale o que a conta escolheu, e o navegador passa a guardar.
e_3="$(entrar "$N31" "$W/painel.senha")"; proibir "$(biscoito_de "$N31")"; c_3="$(grep -i -c '^set-cookie: __Host-idioma=en; ' "$W/entrada.cab")"
t_3="$(aba -b "$N31" "$B/")"; l_3="$(lingua31)"
# O usuário do FTP escolhe o dele, e a volta é para a tela em que ele estava.
r_tc="$(troca31 "$W/id31c.jar" "$KC" en -e "$B/meus-arquivos?pasta=sub")"; arq_2="$(gravado31)"
t_c2="$(aba -b "$W/id31c.jar" "$B/meus-arquivos")"; l_c2="$(lingua31)"
# Um segundo administrador: nasce em português, escolhe inglês, e a escolha acompanha o nome novo e sai com a conta.
r_novo="$(envio /usuarios/novo --data-urlencode "csrf=$K" --data-urlencode 'perfil=administrador' --data-urlencode 'usuario=idioma31' --data-urlencode "senha@$W/a31.senha" --data-urlencode "confirmacao@$W/a31.senha" --data-urlencode "senha_atual@$W/painel.senha")"
e_a="$(COMO=idioma31 entrar "$A31" "$W/a31.senha")"; proibir "$(biscoito_de "$A31")"; KA="$(POTE="$A31" csrf)"; proibir "$KA"
t_a="$(aba -b "$A31" "$B/usuarios")"; l_a="$(lingua31)"
r_ta="$(troca31 "$A31" "$KA" en)"; arq_3="$(gravado31)"

# ------------------------------------------------------------------ todas as telas em inglês
telas31=0; ruins31=0; ev31=""; perfis31=""
ver31 "$J" 200 / /usuarios /usuarios/novo "/usuarios/novo?pasta=idioma31/a" "/usuarios/editar?usuario=id31c" "/usuarios/editar?usuario=id31e" \
  "/usuarios/editar?usuario=id31l" "/usuarios/editar?usuario=id31s" "/usuarios/senha?usuario=id31c" "/usuarios/remover?usuario=id31c" \
  /arquivos "/arquivos?pasta=idioma31" "/arquivos?pasta=idioma31/a" "/arquivos?pasta=idioma31/a/sub" "/arquivos/renomear?item=idioma31/a/sub/backup.cfg" \
  "/arquivos/renomear?item=idioma31/a/sub" "/arquivos/apagar?item=idioma31/a/sub/backup.cfg" "/arquivos/apagar?item=idioma31/a/sub" \
  "/usuarios/novo?perfil=administrador" "/administradores/senha?admin=$ADMIN" "/administradores/senha?admin=idioma31" "/administradores/nome?admin=idioma31" \
  "/administradores/remover?admin=idioma31" /seguranca /servidor /bloqueios "/bloqueios?q=203.0.113" "/bloqueios?q=198.18" \
  "/bloqueios/endereco?ip=$BLOQUEADO31" /atividade
# Telas de recusa e de aviso, que também são do painel: a de quem tenta remover a si mesmo, a que não existe e as
# que dependem do modo de TLS da instância.
ver31 "$J" '200|400|403|404|409' "/administradores/remover?admin=$ADMIN" /nao-existe "/usuarios/editar?usuario=ninguem31" "/usuarios/tls?usuario=id31c" \
  "/arquivos?pasta=nao-existe-31"
# Os avisos que cada lista mostra depois de uma ação, pedidos pelo nome que vai na consulta.
for n in criado criado_sem_tls criado_tls_falhou senha pasta perfil limites desbloqueado removido removido_com_pasta tls_dispensado tls_exigido \
  admin_criado admin_senha admin_nome admin_removido; do ver31 "$J" 200 "/usuarios?m=$n"; done
for n in prazo liberado ausente; do ver31 "$J" 200 "/bloqueios?m=$n"; done
for n in criada renomeado apagado limite erro ocupado; do ver31 "$J" 200 "/arquivos?pasta=idioma31/a&m=$n"; done
telas_adm=$telas31
ver31 "$W/id31c.jar" 200 /meus-arquivos "/meus-arquivos?pasta=sub" "/meus-arquivos/renomear?item=sub/backup.cfg" "/meus-arquivos/apagar?item=sub/backup.cfg" "/meus-arquivos/apagar?item=sub"
ver31 "$W/id31c.jar" '403|404' /usuarios /nao-existe
for n in e l s; do
  e_p="$(COMO="id31$n" entrar "$W/id31$n.jar" "$W/id31$n.senha")"; proibir "$(biscoito_de "$W/id31$n.jar")"
  r_p="$(troca31 "$W/id31$n.jar" "$(token31 "$W/id31$n.jar")" en)"; perfis31+="$e_p $r_p· "
  ver31 "$W/id31$n.jar" 200 /meus-arquivos
  ver31 "$W/id31$n.jar" '403|404' "/meus-arquivos/apagar?item=sub"
done
# Formulário devolvido com erro e recusa por falta de token: as duas telas saem no idioma da conta.
r_ruim="$(c -o "$W/corpo" -w '%{http_code}' -b "$J" -H "Origin: $B" --data-urlencode "csrf=$K" --data-urlencode 'usuario=UPPER case' --data-urlencode "senha@$W/id31c.senha" --data-urlencode "confirmacao@$W/id31c.senha" "$B/usuarios/novo")"
ruim_lang="$(lingua31)"; ruim_resto="$(resto31)"
r_rep="$(c -o "$W/corpo" -w '%{http_code}' -b "$J" -H "Origin: $B" --data-urlencode "csrf=$K" --data-urlencode 'usuario=id31c' --data-urlencode "senha@$W/id31c.senha" --data-urlencode "confirmacao@$W/id31c.senha" "$B/usuarios/novo")"
rep_texto="$(tem31 'There is already a user with this name.')"; rep_resto="$(resto31)"
# Mensagem que vem do comando de usuários do FTP, que fala português: o painel traduz a que conhece e repassa a outra.
do_comando="$(docker exec "$PAINEL" python3 -B -c "
import sys; sys.path.insert(0, '/opt/painel')
import idioma
frases = ('Usuario ja existe: id31c', 'Limite invalido: sessoes aceita vazio ou um inteiro de 1 a 50', 'Frase que o painel nao conhece')
idioma.usar('en'); print(' | '.join(idioma.do_comando(frase) for frase in frases))
idioma.usar('pt'); print(idioma.do_comando(frases[0]))" 2>&1 | tr '\n' '#')"
# Datas: ano-mês-dia em inglês e dia/mês/ano em português, na mesma tela.
t_data="$(aba -b "$J" "$B/atividade")"; iso_en="$(grep -c -E 'class="quando">[0-9]{4}-[0-9]{2}-[0-9]{2}[^0-9]' "$W/corpo")"; br_en="$(grep -c -E '>[0-9]{2}/[0-9]{2}/[0-9]{4}[^0-9]' "$W/corpo")"
t_data2="$(aba -b "$W/id31l.jar" "$B/meus-arquivos?pasta=sub")"; iso_arq="$(grep -c -E '>[0-9]{4}-[0-9]{2}-[0-9]{2}[^0-9<]+[0-9]{2}:[0-9]{2}<' "$W/corpo")"
[[ "$r_u1" == 0 && "$r_u2" == 0 && "$r_u3" == 0 && "$r_u4" == 0 && "$r_f" == 0 && "$r_b" == 0 && "$ruins31" == 0 && "$telas31" -ge 70 \
  && "$perfis31" == "303 303 /· 303 303 /· 303 303 /· " && "$r_ruim" == 400 && "$ruim_lang" == en && -z "$ruim_resto" && "$r_rep" =~ ^(400|409)$ && "$rep_texto" == 1 && -z "$rep_resto" \
  && "$do_comando" == "User already exists: id31c | Invalid limit: sessoes accepts empty or a whole number from 1 to 50 | Frase que o painel nao conhece#Usuario ja existe: id31c#" \
  && "$t_data" == "200 " && "$iso_en" -ge 1 && "$br_en" == 0 && "$t_data2" == "200 " && "$iso_arq" -ge 1 ]]
caso $? testes 65 "Todas as telas em inglês: administrador e os quatro perfis de usuário do FTP, sem sobra de português" "usuários de apoio criados (completo, envio, leitura, só envio): $r_u1 $r_u2 $r_u3 $r_u4, arquivo enviado por FTP: $r_f, endereço $BLOQUEADO31 bloqueado pelo terminal: $r_b · $telas31 telas pedidas com a conta em inglês ($telas_adm de administrador, as demais dos quatro perfis de usuário do FTP), cada uma conferida em três pontos: código esperado, <html lang=\"en\"> e nenhuma letra acentuada nem palavra de tela em português fora do botão de idioma; entram as telas de formulário, de confirmação, de recusa e os avisos de cada lista · telas com desvio: $ruins31 ${ev31:+($ev31)}· entrada e troca de idioma dos perfis envio, leitura e só envio: $perfis31· formulário de usuário devolvido com nome fora da regra: $r_ruim, lang=$ruim_lang, sobras: ${ruim_resto:-nenhuma} · usuário que já existe: $r_rep, mensagem em inglês: $rep_texto, sobras: ${rep_resto:-nenhuma} · mensagens do comando de usuários do FTP passadas pelo painel em inglês e, a primeira, em português: $do_comando · aba Atividade em inglês: $t_data, datas ano-mês-dia: $iso_en, datas dia/mês/ano: $br_en · pasta do usuário de leitura em inglês: $t_data2, datas ano-mês-dia com hora: $iso_arq"

# ------------------------------------------------------------------ recusas da troca
auditoria; csrf_0="$(eventos recusa_csrf)"; origem_0="$(eventos recusa_origem)"; arq_4="$(gravado31)"
x_1="$(troca31 "$J" "" pt)"; x_texto="$(tem31 'Form without a valid token. Open the page again and repeat.')"       # sem o token
x_2="$(troca31 "$J" "$(openssl rand -hex 32)" pt)"                                                              # token inventado
x_3="$(troca31 "$J" "$KC" pt)"                                                                                  # token de outra sessão
x_4="$(c -o /dev/null -w '%{http_code} %{redirect_url}' -b "$J" -H 'Origin: https://outro.example' --data-urlencode "csrf=$K" --data-urlencode 'idioma=pt' "$B/idioma")"
x_5="$(troca31 "$J" "$K" fr)"; x_texto5="$(tem31 'Language not accepted.')"                                       # idioma que não existe
x_6="$(troca31 "$J" "$K" '')"                                                                                   # sem o campo
x_7="$(troca31 "$J" "$K" 'en; Path=/x')"                                                                        # valor que tenta montar outro cookie
x_8="$(aba -b "$J" "$B/idioma?idioma=pt")"                                                              # por GET não há troca
# Campos a mais não mudam de quem é a escolha: a troca vale só para a conta da sessão.
x_9="$(troca31 "$W/id31e.jar" "$(token31 "$W/id31e.jar")" pt --data-urlencode "admin=$ADMIN" --data-urlencode "usuario=$ADMIN" --data-urlencode 'conta=admin' --data-urlencode 'tipo=admin')"
auditoria; csrf_1="$(eventos recusa_csrf)"; origem_1="$(eventos recusa_origem)"; arq_5="$(gravado31)"
t_x="$(aba -b "$J" "$B/usuarios")"; l_x="$(lingua31)"
# Sem sessão: só com o token do formulário de entrada, que o painel assina.
y_1="$(c -o /dev/null -D "$W/i31.cab" -w '%{http_code} %{redirect_url}' -H "Origin: $B" --data-urlencode 'idioma=en' "$B/idioma" | sed "s|$B||")"; yc_1="$(biscoito31)"
y_2="$(c -o /dev/null -D "$W/i31.cab" -w '%{http_code} %{redirect_url}' -H "Origin: $B" --data-urlencode "token=$(date +%s).$(openssl rand -hex 32)" --data-urlencode 'idioma=en' "$B/idioma" | sed "s|$B||")"; yc_2="$(biscoito31)"
rm -f "$I31"; y_3="$(fora31 "$I31" fr)"; yc_3="$(biscoito31)"
y_4="$(c -o /dev/null -D "$W/i31.cab" -w '%{http_code} %{redirect_url}' "$B/idioma?idioma=en" | sed "s|$B||")"; yc_4="$(biscoito31)"
y_6="$(c -o /dev/null -D "$W/i31.cab" -w '%{http_code}' -H 'Origin: https://outro.example' --data-urlencode "token=$(ficha31 "$W/i31.entrada")" --data-urlencode 'idioma=en' "$B/idioma")"; yc_6="$(biscoito31)"
[[ "$x_1" == "403 " && "$x_texto" == 1 && "$x_2" == "403 " && "$x_3" == "403 " && "$x_4" == "403 " && "$x_5" == "400 " && "$x_texto5" == 1 && "$x_6" == "400 " && "$x_7" == "400 " \
  && "$x_8" == "404 " && "$x_9" == "303 /" && "$arq_4" == *"usuario:id31e:en "* && "$arq_5" == "${arq_4/usuario:id31e:en/usuario:id31e:pt}" && $((csrf_1 - csrf_0)) -ge 1 && $((origem_1 - origem_0)) -ge 1 && "$t_x" == "200 " && "$l_x" == en \
  && "$y_1" == "303 /entrar" && -z "$yc_1" && "$y_2" == "303 /entrar" && -z "$yc_2" && "$y_3" == "303 /entrar" && -z "$yc_3" && "$y_4" == "303 /entrar" && -z "$yc_4" \
  && "$y_6" == 403 && -z "$yc_6" ]]
caso $? seguranca 113 "Troca de idioma só por POST do próprio painel, com token, e para idioma que existe" "com sessão de administrador, POST /idioma sem o token: $x_1(recusa em inglês: $x_texto) · com token inventado: $x_2· com o token de outra sessão: $x_3· de outra origem, com o token certo: $x_4· idioma=fr: $x_5(mensagem: $x_texto5) · sem o campo idioma: $x_6· idioma com atributos de cookie no valor: $x_7· GET /idioma?idioma=pt: $x_8· usuário do FTP id31e pedindo português com os campos admin, usuario, conta e tipo a mais: $x_9 · escolhas gravadas antes: ${arq_4:-nenhuma}· depois: ${arq_5:-nenhuma}(só mudou a do usuário que pediu) · eventos recusa_csrf a mais: $((csrf_1 - csrf_0)) · recusa_origem a mais: $((origem_1 - origem_0)) (a auditoria grava uma recusa repetida do mesmo endereço por minuto) · tela do administrador depois das recusas: $t_x, lang=$l_x · sem sessão, POST /idioma sem token: $y_1, cookies: ${yc_1:-nenhum} · com token forjado: $y_2, cookies: ${yc_2:-nenhum} · idioma=fr com o token do formulário: $y_3, cookies: ${yc_3:-nenhum} · por GET: $y_4, cookies: ${yc_4:-nenhum} · de outra origem: $y_6, cookies: ${yc_6:-nenhum}"

# ------------------------------------------------------------------ o cookie e a volta
c -o "$W/corpo" -b '__Host-idioma=fr' "$B/entrar"; z_1="$(lingua31)"
c -o "$W/corpo" -b '__Host-idioma=en"><script>alert(31)</script>' "$B/entrar"; z_2="$(lingua31)"; z_2s="$(tem31 'alert(31)')"
c -o "$W/corpo" -b '__Host-idioma=EN' "$B/entrar"; z_3="$(lingua31)"
c -o "$W/corpo" -b 'idioma=en; x__Host-idioma=en' "$B/entrar"; z_4="$(lingua31)"
c -o "$W/corpo" -b '__Host-idioma=en' "$B/entrar"; z_5="$(lingua31)"
z_6="$(aba -b '__Host-idioma=en' "$B/usuarios")"                                                               # o cookie de idioma não é sessão
# Com sessão, quem manda é a escolha da conta: o cookie de outro idioma não muda a tela.
z_7="$(aba -b "__Host-sessao=$(biscoito_de "$J"); __Host-idioma=pt" "$B/usuarios")"; z_7l="$(lingua31)"
# A volta sai do caminho da tela de origem, e só se ele for uma tela do papel da sessão.
v_1="$(troca31 "$J" "$K" en -e 'https://outro.example/seguranca')"
v_2="$(troca31 "$J" "$K" en -e "$B//outro.example/")"
v_3="$(troca31 "$J" "$K" en -e "$B/nao-existe")"
v_4="$(troca31 "$J" "$K" en -e "$B/arquivos?pasta=idioma31/a&m=apagado")"
v_5="$(troca31 "$J" "$K" en -e "$B/usuarios/novo")"
v_6="$(troca31 "$J" "$K" en)"
v_7="$(troca31 "$W/id31c.jar" "$KC" en -e "$B/usuarios")"
v_8="$(troca31 "$W/id31l.jar" "$(token31 "$W/id31l.jar")" en -e "$B/meus-arquivos/apagar?item=sub")"
dono_arq="$(docker exec "$PAINEL" stat -c '%U %a' /painel/idiomas 2>&1)"; dono_painel="$(docker exec "$PAINEL" id -un 2>&1)"
fora_da_regra="$(docker exec "$PAINEL" sh -c "grep -c -v -E '^(admin|usuario):[a-z_][a-z0-9_-]{0,31}:(pt|en)\$' /painel/idiomas")"
[[ "$z_1" == pt-BR && "$z_2" == pt-BR && "$z_2s" == 0 && "$z_3" == pt-BR && "$z_4" == pt-BR && "$z_5" == en && "$z_6" == "303 /entrar" && "$z_7" == "200 " && "$z_7l" == en \
  && "$v_1" == "303 /seguranca" && "$v_2" == "303 /" && "$v_3" == "303 /" && "$v_4" == "303 /arquivos?pasta=idioma31%2Fa" && "$v_5" == "303 /usuarios/novo" && "$v_6" == "303 /" \
  && "$v_7" == "303 /" && "$v_8" == "303 /" && "$dono_arq" == "$dono_painel 600" && "$fora_da_regra" == 0 ]]
caso $? seguranca 114 "Cookie de idioma não vale como sessão, valor fora da regra é ignorado e a volta só leva a tela do painel" "tela de entrada com __Host-idioma=fr: lang=$z_1 · com marcação no valor: lang=$z_2, trecho devolvido na página: $z_2s · com EN em maiúsculas: lang=$z_3 · com nomes parecidos (idioma, x__Host-idioma): lang=$z_4 · com __Host-idioma=en: lang=$z_5 · GET /usuarios só com o cookie de idioma: $z_6 · sessão de conta em inglês com __Host-idioma=pt: $z_7, lang=$z_7l · volta com Referer de outro site (/seguranca): $v_1 · com //outro.example/ no caminho: $v_2 · com tela que não existe: $v_3 · com pasta e aviso na consulta: $v_4 · com /usuarios/novo: $v_5 · sem Referer: $v_6 · usuário do FTP com Referer de tela de administrador: $v_7 · usuário de leitura com Referer de tela que o perfil não tem: $v_8 · /painel/idiomas: $dono_arq (o painel roda como $dono_painel), linhas fora do formato: $fora_da_regra"

# ------------------------------------------------------------------ a escolha acompanha a conta e sai com ela
r_nome="$(envio /administradores/nome --data-urlencode "csrf=$K" --data-urlencode 'admin=idioma31' --data-urlencode 'nome=idioma31b' --data-urlencode "senha_atual@$W/painel.senha")"; arq_6="$(gravado31)"
r_rem="$(envio /administradores/remover --data-urlencode "csrf=$K" --data-urlencode 'admin=idioma31b' --data-urlencode "senha_atual@$W/painel.senha")"; arq_7="$(gravado31)"
r_remu="$(envio /usuarios/remover --data-urlencode "csrf=$K" --data-urlencode 'usuario=id31c' --data-urlencode 'confirmar=sim')"; arq_8="$(gravado31)"
# De volta ao português: é o que fica gravado para o administrador da instância.
r_t9="$(troca31 "$J" "$K" pt -e "$B/usuarios")"; c_t9="$(biscoito31)"; t_9="$(aba -b "$J" "$B/usuarios")"; l_9="$(lingua31)"; h_9="$(tem31 '<h1 class="titulo-aba">Usuários</h1>')"
t_92="$(aba -b "$J31" "$B/usuarios")"; l_92="$(lingua31)"
for n in id31e id31l id31s; do mu del "$n"; done
# Conta removida pelo terminal: a escolha dela sai na próxima troca de qualquer conta.
r_t10="$(troca31 "$J" "$K" pt)"; arq_9="$(gravado31)"
mu endereco-liberar "$BLOQUEADO31"; r_l=$?
docker exec "$FTP" rm -rf /data/idioma31
usuarios_fim="$(usuarios_ftp | tr ' ' '\n' | grep -c -E '^id31[cels]$')"; admins_fim="$(admins | tr ' ' '\n' | grep -c '^idioma31')"
[[ "$e_2" == 303 && "$e_c" == 303 && "$t_antes" == "200 " && "$antes_lang" == pt-BR && "$antes_botao" == "pt " && ( -z "$arq_0" || "$arq_0" == "admin:$ADMIN:pt " ) \
  && "$r_t1" == "303 /bloqueios?q=203" && "$c_t1" == "$(printf "$COOKIE31" en)|" && "$arq_1" == "admin:$ADMIN:en " && "$modo_1" == 600 \
  && "$t_1" == "200 " && "$l_1" == en && "$b_1" == "en " && "$h_1" == 1 && "$t_2" == "200 " && "$l_2" == en && "$t_c" == "200 " && "$l_c" == pt-BR \
  && "$e_3" == 303 && "$c_3" == 1 && "$t_3" == "200 " && "$l_3" == en \
  && "$r_tc" == "303 /meus-arquivos?pasta=sub" && "$arq_2" == "admin:$ADMIN:en usuario:id31c:en " && "$t_c2" == "200 " && "$l_c2" == en \
  && "$r_novo" == "303 /usuarios"* && "$e_a" == 303 && "$t_a" == "200 " && "$l_a" == pt-BR && "$r_ta" == "303 /" ]] && tem_linha31 "$arq_3" "admin:idioma31:en" \
  && [[ "$r_nome" == "303 "* ]] && tem_linha31 "$arq_6" "admin:idioma31b:en" && ! tem_linha31 "$arq_6" "admin:idioma31:en" \
  && [[ "$r_rem" == "303 "* ]] && ! tem_linha31 "$arq_7" "admin:idioma31b:en" && tem_linha31 "$arq_7" "usuario:id31c:en" \
  && [[ "$r_remu" == "303 "* ]] && ! tem_linha31 "$arq_8" "usuario:id31c:en" \
  && [[ "$r_t9" == "303 /usuarios" && "$c_t9" == "$(printf "$COOKIE31" pt)|" && "$t_9" == "200 " && "$l_9" == pt-BR && "$h_9" == 1 && "$t_92" == "200 " && "$l_92" == pt-BR \
  && "$r_t10" == "303 /" && "$arq_9" == "admin:$ADMIN:pt " && "$r_l" == 0 && "$usuarios_fim" == 0 && "$admins_fim" == 0 ]]
caso $? testes 64 "Idioma por conta: a escolha é gravada, vale em toda sessão da conta, acompanha o nome novo e sai com a conta" "duas sessões do administrador e uma do usuário id31c abertas: $e_adm $e_2 $e_c · antes: lang=$antes_lang, botão marcado: $antes_botao, escolhas gravadas: ${arq_0:-nenhuma} · POST /idioma com idioma=en e Referer de /bloqueios?q=203&m=liberado: $r_t1, Set-Cookie: $c_t1 · /painel/idiomas: $arq_1(modo $modo_1) · a mesma sessão: $t_1, lang=$l_1, botão marcado: $b_1, título Users: $h_1 · a outra sessão da conta: $t_2, lang=$l_2 · o usuário do FTP, que não escolheu: $t_c, lang=$l_c · entrada nova do administrador em navegador sem cookie: $e_3, cookie de idioma en na resposta: $c_3, tela: $t_3, lang=$l_3 · o usuário do FTP escolhe inglês: $r_tc, gravado: $arq_2, tela: $t_c2, lang=$l_c2 · administrador idioma31 criado: $r_novo, entra: $e_a, tela: $t_a, lang=$l_a (não herda o idioma de quem criou), escolhe inglês: $r_ta, gravado: $arq_3· renomeado para idioma31b: $r_nome, gravado: $arq_6· removido: $r_rem, gravado: $arq_7· usuário id31c removido pelo painel: $r_remu, gravado: ${arq_8:-nada} · de volta ao português: $r_t9, Set-Cookie: $c_t9, tela: $t_9, lang=$l_9, título Usuários: $h_9, a outra sessão: $t_92, lang=$l_92 · usuários de apoio removidos pelo terminal e mais uma troca: $r_t10, gravado: $arq_9· endereço liberado: $r_l · sobras: $usuarios_fim usuários e $admins_fim administradores da etapa"
