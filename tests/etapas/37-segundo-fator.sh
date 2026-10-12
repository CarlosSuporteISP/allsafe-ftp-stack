#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa AK: segundo fator da entrada do painel. O administrador liga o dele com a chave que a tela mostra e a senha, e
# daí em diante a senha certa não abre sessão: abre uma espera de cinco minutos, e só o código do aplicativo entra.
# A etapa faz o papel do aplicativo: lê a chave da tela e calcula o código do passo de 30 segundos com a função do
# próprio painel, que o caso dos vetores da RFC 6238 confere à parte. A chave vai ao container pela entrada, nunca
# pela linha de comando, e nem ela nem os códigos entram em evidência.
# No fim, a etapa liga a obrigação (PAINEL_SEGUNDO_FATOR_OBRIGATORIO=sim) e prova o cadastro feito na entrada, pelo
# administrador e pelo usuário do FTP, e devolve a instância com o fator opcional, como o resto da bateria espera.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel encerra as sessões e zera a contagem de falhas de entrada do endereço.
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"

N37="$W/n37.jar"; A37="$W/a37.jar"; U37="$W/u37.jar"; X37="$W/x37.jar"; P37="$S/segundo-fator"
LIGADO37='303 /usuarios?m=fator_ligado'; DESLIGADO37='303 /usuarios?m=fator_desligado'
destino37() { grep -i '^location:' "${1:-$W/entrada.cab}" | tr -d '\r' | cut -d ' ' -f 2 | sed "s|$B||"; }   # [cabeçalhos] → para onde a resposta manda
# [cabeçalhos] → os cookies que a resposta grava, pelo nome; o que ela apaga leva "(vazio)"
biscoitos37() { grep -i '^set-cookie:' "${1:-$W/entrada.cab}" | tr -d '\r' | sed -E 's/^[^ ]+ ([^=]+)=([^;]*);.*/\1 \2/' | awk '{ print $1 ($2 == "" ? "(vazio)" : "") }' | sort | tr '\n' ' '; }
etapa37() { awk '$6 == "__Host-etapa" {print $7}' "$1"; }                                         # <pote>: valor do cookie da espera
tem37() { grep -c -F -- "$1" "${2:-$W/corpo}" || true; }                                          # <trecho> [arquivo]: linhas com ele
lista37() { docker exec "$PAINEL" sh -c 'cat /painel/segundo-fator 2>/dev/null' | tr '\n' ' '; }  # contas com o fator ligado
guardado37() { [[ -f "$P37/$1.txt" ]] && echo "$(stat -c %a "$P37/$1.txt") $(tr -d '\n' < "$P37/$1.txt" | wc -c)" || echo ausente; }  # <conta>: modo e tamanho do segredo
terminal37() { docker exec "$PAINEL" python3 /opt/painel/servidor.py --segundo-fator "$@" 2>&1; }  # o modo de terminal do segundo fator
token37() { c -b "$1" "$B/meus-arquivos" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1; }  # <pote>: token dos formulários do usuário do FTP
igual37() { [[ "$1" == "$2" ]] || F37=1; }                                                        # <obtido> <esperado>: marca o caso em andamento quando diferem
calma37() { while (( $(date +%s) % 30 > 23 )); do sleep 1; done; }                                # longe da virada do passo de 30 segundos
# <arquivo de saída>: a chave que a tela de ligar acabou de mostrar (em $W/corpo), sem os espaços
chave37() {
  local mostrada; mostrada="$(sed -n 's/.*<p class="segredo"><code>\([A-Z2-7 ]*\)<\/code>.*/\1/p' "$W/corpo" | head -1)"
  printf '%s' "$mostrada" | tr -d ' ' > "$1"; proibir "$mostrada"; proibir "$(cat "$1")"
}
# <arquivo da chave> <passo: -1, 0 ou 1; ou "errado"> <arquivo de saída>: o código daquele passo, ou seis dígitos que não valem em nenhum dos três
codigo37() {
  docker exec -i "$PAINEL" python3 -B -c '
import sys, time
sys.path.insert(0, "/opt/painel")
import fator
chave, agora = sys.stdin.read().strip(), int(time.time()) // 30
if sys.argv[1] == "errado":
    validos = {fator.codigo_de(chave, agora + passo) for passo in (-2, -1, 0, 1, 2)}
    sys.stdout.write(next(c for c in ("000000", "111111", "222222", "333333", "444444", "555555") if c not in validos))
else:
    sys.stdout.write(fator.codigo_de(chave, agora + int(sys.argv[1])))' "$2" < "$1" > "$3"
}
# <pote> <arquivo do código> [opções do curl...] → "código destino" do formulário do código (ou do caminho em CAMINHO37); corpo em $W/corpo, cabeçalhos em $W/f37.cab
passo37() {
  local pote="$1" codigo="$2" ficha; shift 2
  ficha="$(c -b "$pote" "$B${CAMINHO37:-/entrar/codigo}" | sed -n 's/.*name="token" value="\([^"]*\)".*/\1/p' | head -1)"
  c -o "$W/corpo" -D "$W/f37.cab" -w '%{http_code} %{redirect_url}' -b "$pote" -c "$pote" -H "Origin: $B" \
    --data-urlencode "token=$ficha" --data-urlencode "codigo@$codigo" "$@" "$B${CAMINHO37:-/entrar/codigo}" | sed "s|$B||"
}
# <pote> <token> <arquivo do código> <arquivo da senha> [campos...] → "código destino" do formulário de ligar
liga37() { local pote="$1" token="$2" codigo="$3" senha="$4"; shift 4; POTE="$pote" envio /administradores/fator/ligar --data-urlencode "csrf=$token" --data-urlencode "codigo@$codigo" --data-urlencode "senha_atual@$senha" "$@"; }
# <pote> <token> <conta> <arquivo da senha> → "código destino" do formulário de desligar
desliga37() { POTE="$1" envio /administradores/fator/desligar --data-urlencode "csrf=$2" --data-urlencode "admin=$3" --data-urlencode "senha_atual@$4"; }

for n in a37 f37 errada37; do nova_senha "$W/$n.senha"; done
# Os administradores que as etapas anteriores deixaram: a etapa termina com os mesmos, e nenhum deles liga o fator aqui.
ADM37="$(admins)"; OUTROS37="$(printf '%s' "$ADM37" | tr ' ' '\n' | grep -v -x -F -e "$ADMIN" -e '' | paste -s -d , | sed 's/,/, /g')"
SEG37='Todos os administradores entram com a senha e o código'; [[ -z "$OUTROS37" ]] || SEG37="Entram só com a senha: $OUTROS37."
auditoria; a_lig0="$(eventos admin_fator_ligado)"; a_des0="$(eventos 'admin_fator_desligado ')"; a_sen0="$(eventos entrada_senha_ok)"
a_rec0="$(eventos entrada_codigo_recusado)"; a_sem0="$(eventos entrada_fator_sem_segredo)"; a_host0="$(eventos admin_fator_desligado_no_host)"

# ------------------------------------------------------------------ ligar e entrar com o código
# Sem o fator, a tela de ligar mostra o código QR e a chave; ligada, a mesma rota passa a ser a de desligar e a chave
# não volta à tela. A chave fica em um arquivo 0600 do host, e o nome da conta, em uma lista nos dados do painel.
x_antes="$(lista37)|$(terminal37 | grep -m1 "^$ADMIN: ")"
t_lig="$(aba -b "$J" "$B/administradores/fator?admin=$ADMIN")"; q_lig="$(tem37 '<svg class="qr"') $(tem37 'action="/administradores/fator/ligar"')"
chave37 "$W/c37.chave"; n_chave="$(wc -c < "$W/c37.chave")"
t_de_novo="$(aba -b "$J" "$B/administradores/fator?admin=$ADMIN")"; chave37 "$W/c37.outra"; cmp -s "$W/c37.chave" "$W/c37.outra" && mesma=sim || mesma=nao
calma37; codigo37 "$W/c37.chave" errado "$W/c37.errado"; codigo37 "$W/c37.chave" -1 "$W/c37.cod"
r_errado="$(liga37 "$J" "$K" "$W/c37.errado" "$W/painel.senha")"; x_errado="$(lista37)|$(guardado37 "$ADMIN")"
r_lig="$(liga37 "$J" "$K" "$W/c37.cod" "$W/painel.senha")"
x_lig="$(lista37)|$(guardado37 "$ADMIN")"; [[ "$(tr -d '\n' < "$P37/$ADMIN.txt" 2> /dev/null)" == "$(cat "$W/c37.chave")" ]] && mesmo_arquivo=sim || mesmo_arquivo=nao
t_dep="$(aba -b "$J" "$B/administradores/fator?admin=$ADMIN")"; q_dep="$(tem37 '<svg class="qr"') $(tem37 'class="segredo"') $(tem37 'action="/administradores/fator/desligar"')"
t_usu="$(aba -b "$J" "$B/usuarios")"; q_usu="$(tem37 'segundo fator ligado')"
t_seg="$(aba -b "$J" "$B/seguranca")"; q_seg="$(tem37 "$SEG37")"
x_term="$(terminal37 | grep -m1 "^$ADMIN: ")"

# Entrada nova: a senha certa leva ao código e não abre sessão.
e_1="$(entrar "$N37" "$W/painel.senha")"; d_1="$(destino37)"; b_1="$(biscoitos37)"; proibir "$(etapa37 "$N37")"
k_1="$(grep -i -c '^set-cookie: __Host-etapa=[A-Za-z0-9_-]\{40,\}; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=300' "$W/entrada.cab")"
t_cod="$(aba -b "$N37" "$B/entrar/codigo")"; q_cod="$(tem37 'name="codigo"') $(tem37 'autocomplete="one-time-code"')"
t_fechado="$(aba -b "$N37" "$B/usuarios")"
# O cookie da espera não vale como sessão.
sed 's/__Host-etapa/__Host-sessao/' "$N37" > "$X37"; t_troca="$(aba -b "$X37" "$B/usuarios")"; rm -f "$X37"
# Recusas: sem o token do formulário, de outra origem, código errado e o código que já ligou o fator.
calma37; codigo37 "$W/c37.chave" errado "$W/c37.errado"
r_sem_token="$(c -o /dev/null -w '%{http_code}' -b "$N37" -H "Origin: $B" --data-urlencode "codigo@$W/c37.errado" "$B/entrar/codigo")"
r_origem="$(c -o /dev/null -w '%{http_code}' -b "$N37" -H 'Origin: https://outro.example' --data-urlencode "codigo@$W/c37.errado" "$B/entrar/codigo")"
r_cod_errado="$(passo37 "$N37" "$W/c37.errado")"; q_cod_errado="$(tem37 'O código não confere')"
r_repetido="$(passo37 "$N37" "$W/c37.cod")"
s_antes="$(biscoito_de "$N37" | wc -c)"
# O código do passo atual entra; se a virada do passo deixou o atual igual ao que ligou, o seguinte entra.
codigo37 "$W/c37.chave" 0 "$W/c37.cod2"; r_certo="$(passo37 "$N37" "$W/c37.cod2")"
[[ "$r_certo" == '303 /' ]] || { codigo37 "$W/c37.chave" 1 "$W/c37.cod2"; r_certo="$(passo37 "$N37" "$W/c37.cod2")"; }
b_2="$(biscoitos37 "$W/f37.cab")"; proibir "$(biscoito_de "$N37")"; t_aberto="$(aba -b "$N37" "$B/usuarios")"
# O mesmo código não entra duas vezes, nem em outra espera.
e_2="$(entrar "$A37" "$W/painel.senha")"; proibir "$(etapa37 "$A37")"; r_duas="$(passo37 "$A37" "$W/c37.cod2")"
auditoria
F37=0
igual37 "$e_adm" 303; igual37 "$x_antes" "|$ADMIN: desligado"; igual37 "$t_lig $q_lig $n_chave $mesma" '200  1 1 32 sim'; igual37 "${t_de_novo%% *}" 200
igual37 "${r_errado%% *}|$x_errado" '400||ausente'; igual37 "$r_lig" "$LIGADO37"; igual37 "$x_lig|$mesmo_arquivo" "$ADMIN |600 32|sim"
igual37 "$t_dep $q_dep" '200  0 0 1'; igual37 "$t_usu $q_usu" '200  1'; igual37 "$t_seg $q_seg" '200  1'; igual37 "$x_term" "$ADMIN: ligado"
igual37 "$e_1 $d_1|$b_1|$k_1" '303 /entrar/codigo|__Host-etapa __Host-idioma |1'; igual37 "$t_cod $q_cod" '200  1 1'
igual37 "$r_certo|$b_2" '303 /|__Host-etapa(vazio) __Host-sessao '; igual37 "$t_aberto" '200 '
igual37 "$(( $(eventos admin_fator_ligado) - a_lig0 )) $(( $(eventos entrada_senha_ok) - a_sen0 ))" '1 2'
caso "$F37" testes 95 "Segundo fator: o administrador liga com a chave da tela e passa a entrar com senha e código" \
  "antes: lista \"${x_antes%%|*}\", terminal \"${x_antes#*|}\"; tela de ligar: $t_lig, código QR e formulário: $q_lig, chave de $n_chave caracteres, a mesma ao reabrir a tela: $mesma; código errado: $r_errado, lista e segredo depois: $x_errado; código certo com a senha: $r_lig; lista e segredo no host (modo e tamanho): $x_lig, igual à chave da tela: $mesmo_arquivo; a mesma rota depois de ligado: $t_dep, código QR, chave e formulário de desligar: $q_dep; lista de usuários com \"segundo fator ligado\": $q_usu; aba Segurança com quem ainda entra só com a senha (${OUTROS37:-ninguém}): $q_seg; terminal: $x_term; entrada nova com a senha certa: $e_1 $d_1, cookies gravados: $b_1; tela do código: $t_cod, campo do código: $q_cod; código do aplicativo: $r_certo, cookies: $b_2; painel com a sessão nova: $t_aberto; eventos admin_fator_ligado e entrada_senha_ok a mais: $(( $(eventos admin_fator_ligado) - a_lig0 )) e $(( $(eventos entrada_senha_ok) - a_sen0 ))"

F37=0
igual37 "$k_1" 1; igual37 "$s_antes" 0; igual37 "$t_fechado" '303 /entrar'; igual37 "$t_troca" '303 /entrar'
igual37 "$r_sem_token $r_origem" '400 403'; igual37 "$r_cod_errado $q_cod_errado" '401  1'; igual37 "$r_repetido" '401 '; igual37 "$e_2 $r_duas" '303 401 '
igual37 "$(( $(eventos entrada_codigo_recusado) - a_rec0 ))" 3
caso "$F37" seguranca 141 "Segundo fator: a senha certa não abre sessão, e código errado ou já usado não entra" \
  "cookie da espera com Path=/, Secure, HttpOnly, SameSite=Strict e Max-Age=300: $k_1; cookie de sessão depois da senha certa: $s_antes bytes; painel com o cookie da espera: $t_fechado; cookie da espera apresentado como sessão: $t_troca; código sem o token do formulário: $r_sem_token; de outra origem: $r_origem; código errado: $r_cod_errado, aviso na tela: $q_cod_errado; o código que ligou o fator, repetido: $r_repetido; o código que acabou de entrar, em outra espera: $r_duas; eventos entrada_codigo_recusado a mais: $(( $(eventos entrada_codigo_recusado) - a_rec0 ))"

# ------------------------------------------------------------------ segredo ausente e a saída pelo terminal
# Fator ligado e segredo fora do servidor (cópia restaurada sem a pasta dos segredos): a conta não entra, o painel diz
# por quê, e o terminal desliga. A cópia dos dados não leva o segredo, então a falta dele fecha, não abre.
mv "$P37/$ADMIN.txt" "$W/c37.guardado"
e_3="$(entrar "$A37" "$W/painel.senha")"; d_3="$(destino37)"; proibir "$(etapa37 "$A37")"
t_sem="$(aba -b "$A37" "$B/entrar/codigo")"; q_sem="$(tem37 'o segredo dele não está no servidor')"
codigo37 "$W/c37.chave" 1 "$W/c37.cod3"; r_sem="$(passo37 "$A37" "$W/c37.cod3")"; s_sem="$(biscoito_de "$A37" | wc -c)"
x_sem="$(terminal37 | grep -m1 "^$ADMIN: ")"
t_seg2="$(aba -b "$N37" "$B/seguranca")"; q_seg2="$(tem37 'Ligado sem o segredo no servidor')"
x_des="$(terminal37 desligar "$ADMIN" | tail -1)"; x_des2="$(terminal37 desligar "$ADMIN" | tail -1)"
terminal37 desligar ninguem37 > "$W/c37.saida" 2>&1; r_nao=$?; x_nao="$(tail -1 "$W/c37.saida")"
terminal37 apagar "$ADMIN" > "$W/c37.saida" 2>&1; r_uso=$?; x_uso="$(tail -1 "$W/c37.saida")"
x_fim="$(lista37)|$(guardado37 "$ADMIN")|$(terminal37 | grep -m1 "^$ADMIN: ")"
e_4="$(entrar "$A37" "$W/painel.senha")"; d_4="$(destino37)"; proibir "$(biscoito_de "$A37")"
rm -f "$W/c37.guardado"; auditoria
F37=0
igual37 "$e_3 $d_3" '303 /entrar/codigo'; igual37 "$t_sem $q_sem" '503  1'; igual37 "${r_sem%% *} $s_sem" '503 0'
igual37 "$x_sem" "$ADMIN: ligado, sem o segredo no servidor (a conta não entra até ser desligado)"; igual37 "$t_seg2 $q_seg2" '200  1'
igual37 "$x_des" "$ADMIN: segundo fator desligado"; igual37 "$x_des2" "$ADMIN: o segundo fator já estava desligado"
igual37 "$r_nao" 1; [[ "$x_nao" == *'administrador não encontrado'* ]] || F37=1; igual37 "$r_uso" 1; [[ "$x_uso" == *'uso: --segundo-fator'* ]] || F37=1
igual37 "$x_fim" "|ausente|$ADMIN: desligado"; igual37 "$e_4 $d_4" '303 /'
igual37 "$(( $(eventos admin_fator_desligado_no_host) - a_host0 ))" 1; [[ "$(( $(eventos entrada_fator_sem_segredo) - a_sem0 ))" -ge 1 ]] || F37=1
caso "$F37" testes 96 "Segundo fator: sem o segredo no servidor a conta não entra, e o terminal desliga" \
  "segredo tirado da pasta do host, com a conta na lista; senha certa: $e_3 $d_3; tela do código: $t_sem, aviso do segredo ausente: $q_sem; código certo: ${r_sem%% *}, cookie de sessão: $s_sem bytes; terminal: $x_sem; aba Segurança com o alerta: $q_seg2; --segundo-fator desligar: $x_des; de novo: $x_des2; conta que não existe: saída $r_nao, $x_nao; verbo que não existe: saída $r_uso; lista, segredo e terminal no fim: $x_fim; entrada só com a senha: $e_4 $d_4; eventos admin_fator_desligado_no_host a mais: $(( $(eventos admin_fator_desligado_no_host) - a_host0 ))"

# ------------------------------------------------------------------ outro administrador, troca de nome e remoção
# Cada administrador liga só o dele; qualquer administrador desliga o de outro, com a própria senha. O fator acompanha
# a troca de nome e sai com a conta. O reinício zera a contagem de falhas do endereço, que os códigos recusados de
# propósito, acima, já encheram em parte.
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm2="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
r_novo="$(envio /usuarios/novo --data-urlencode "csrf=$K" --data-urlencode 'perfil=administrador' --data-urlencode 'usuario=fat37' --data-urlencode "senha@$W/a37.senha" --data-urlencode "confirmacao@$W/a37.senha" --data-urlencode "senha_atual@$W/painel.senha")"
rm -f "$A37"; e_5="$(COMO=fat37 entrar "$A37" "$W/a37.senha")"; proibir "$(biscoito_de "$A37")"; KA="$(POTE="$A37" csrf)"; proibir "$KA"
t_alheio="$(aba -b "$A37" "$B/administradores/fator?admin=$ADMIN")"; q_alheio="$(tem37 'class="segredo"') $(tem37 '<svg class="qr"')"
t_proprio="$(aba -b "$A37" "$B/administradores/fator?admin=fat37")"; chave37 "$W/c37.chave2"
# O formulário de ligar não aceita outra conta como alvo: o campo a mais é ignorado e quem fica com o fator é quem enviou.
calma37; codigo37 "$W/c37.chave2" -1 "$W/c37.cod4"
r_lig2="$(liga37 "$A37" "$KA" "$W/c37.cod4" "$W/a37.senha" --data-urlencode "admin=$ADMIN")"; x_lig2="$(lista37)|$(guardado37 fat37)|$(guardado37 "$ADMIN")"
t_dele="$(aba -b "$J" "$B/administradores/fator?admin=fat37")"; q_dele="$(tem37 'class="segredo"') $(tem37 'action="/administradores/fator/desligar"')"
r_nome="$(envio /administradores/nome --data-urlencode "csrf=$K" --data-urlencode 'admin=fat37' --data-urlencode 'nome=fat37b' --data-urlencode "senha_atual@$W/painel.senha")"
x_nome="$(lista37)|$(guardado37 fat37)|$(guardado37 fat37b)"
rm -f "$A37"; e_6="$(COMO=fat37b entrar "$A37" "$W/a37.senha")"; d_6="$(destino37)"; proibir "$(etapa37 "$A37")"
codigo37 "$W/c37.chave2" 0 "$W/c37.cod5"; r_ent="$(passo37 "$A37" "$W/c37.cod5")"
[[ "$r_ent" == '303 /' ]] || { codigo37 "$W/c37.chave2" 1 "$W/c37.cod5"; r_ent="$(passo37 "$A37" "$W/c37.cod5")"; }
proibir "$(biscoito_de "$A37")"
# Desligar o de outro pede a senha de quem desliga: com a senha errada nada muda.
r_des_errada="$(desliga37 "$J" "$K" fat37b "$W/errada37.senha")"; x_des_errada="$(lista37)"
r_des_outro="$(desliga37 "$J" "$K" fat37b "$W/painel.senha")"; x_des_outro="$(lista37)|$(guardado37 fat37b)"
rm -f "$A37"; e_7="$(COMO=fat37b entrar "$A37" "$W/a37.senha")"; d_7="$(destino37)"; proibir "$(biscoito_de "$A37")"; KA="$(POTE="$A37" csrf)"; proibir "$KA"
# Liga de novo, com outra chave, e a conta é removida: o fator sai junto.
t_proprio2="$(aba -b "$A37" "$B/administradores/fator?admin=fat37b")"; chave37 "$W/c37.chave3"; cmp -s "$W/c37.chave2" "$W/c37.chave3" && outra=nao || outra=sim
calma37; codigo37 "$W/c37.chave3" -1 "$W/c37.cod6"; r_lig3="$(liga37 "$A37" "$KA" "$W/c37.cod6" "$W/a37.senha")"; x_lig3="$(lista37)|$(guardado37 fat37b)"
auditoria
F37=0
igual37 "$e_adm2 $r_novo $e_5" '303 303 /usuarios?m=admin_criado 303'; igual37 "$t_alheio $q_alheio" '409  0 0'; igual37 "${t_proprio%% *}" 200
igual37 "$r_lig2" "$LIGADO37"; igual37 "$x_lig2" 'fat37 |600 32|ausente'; igual37 "$t_dele $q_dele" '200  0 1'
igual37 "$r_nome" '303 /usuarios?m=admin_nome'; igual37 "$x_nome" 'fat37b |ausente|600 32'; igual37 "$e_6 $d_6 $r_ent" '303 /entrar/codigo 303 /'
igual37 "$x_des_errada" 'fat37b '; [[ "$r_des_errada" != 303* ]] || F37=1; igual37 "$r_des_outro" "$DESLIGADO37"; igual37 "$x_des_outro" '|ausente'
igual37 "$e_7 $d_7" '303 /'; igual37 "${t_proprio2%% *} $outra" '200 sim'; igual37 "$r_lig3" "$LIGADO37"; igual37 "$x_lig3" 'fat37b |600 32'
igual37 "$(( $(eventos 'admin_fator_desligado ') - a_des0 ))" 1
caso "$F37" testes 97 "Segundo fator: cada administrador liga só o dele, outro desliga, e o fator acompanha o nome" \
  "administrador fat37 criado: $r_novo; tela do fator de $ADMIN, desligado, aberta por fat37: $t_alheio, chave e código QR: $q_alheio; fat37 liga com o campo admin=$ADMIN a mais: $r_lig2; lista, segredo de fat37 e de $ADMIN: $x_lig2; tela do fator de fat37 aberta por $ADMIN: $t_dele, chave e formulário de desligar: $q_dele; troca do nome para fat37b: $r_nome; lista, segredo no nome antigo e no novo: $x_nome; entrada de fat37b: $e_6 $d_6, com o código da mesma chave: $r_ent; $ADMIN desliga o de fat37b com a senha errada: $r_des_errada, lista: $x_des_errada; com a senha certa: $r_des_outro, lista e segredo: $x_des_outro; entrada de fat37b só com a senha: $e_7 $d_7; liga de novo: $r_lig3, chave diferente da primeira: $outra, lista e segredo: $x_lig3; eventos admin_fator_desligado a mais: $(( $(eventos 'admin_fator_desligado ') - a_des0 ))"

# ------------------------------------------------------------------ usuário do FTP
# O segundo fator é dos administradores: o usuário do FTP entra como antes e não alcança as telas nem as rotas dele.
mu add f37 "$W/f37.senha" fat37; r_u=$?
e_u="$(COMO=f37 entrar "$U37" "$W/f37.senha")"; d_u="$(destino37)"; b_u="$(biscoitos37)"; proibir "$(biscoito_de "$U37")"; KU="$(token37 "$U37")"; proibir "$KU"
ev_u=""
for caminho in "/administradores/fator?admin=$ADMIN" '/administradores/fator?admin=fat37b' /administradores/fator; do ev_u+="$(aba -b "$U37" "$B$caminho")"; done
p_u1="$(liga37 "$U37" "$KU" "$W/c37.cod6" "$W/f37.senha")"; p_u2="$(desliga37 "$U37" "$KU" fat37b "$W/f37.senha")"; x_u="$(lista37)"
t_u="$(aba -b "$U37" "$B/entrar/codigo")"
F37=0
igual37 "$r_u $e_u" '0 303'; [[ "$b_u" == *'__Host-sessao '* && "$b_u" != *'__Host-etapa '* && "$d_u" != /entrar* ]] || F37=1
igual37 "$ev_u" '404 404 404 '; igual37 "${p_u1%% *} ${p_u2%% *}" '404 404'; igual37 "$x_u" 'fat37b '; igual37 "$t_u" '303 /entrar'
caso "$F37" seguranca 142 "Segundo fator: usuário do FTP entra sem código e não alcança as telas nem as rotas" \
  "usuário f37 criado: $r_u; entrada dele no painel: $e_u $d_u, cookies gravados: $b_u; telas do segundo fator com a sessão dele: $ev_u; formulário de ligar: $p_u1; formulário de desligar o de fat37b: $p_u2; lista depois: $x_u; tela do código sem espera aberta: $t_u"

# ------------------------------------------------------------------ o cálculo, o código QR e os limites, sem a rede
# Roda no container do painel, com os módulos dele: os seis vetores da RFC 6238 (SHA-1), a folga de um passo, o
# endereço que o aplicativo lê, o código QR de um endereço de exemplo (a soma do SVG é a de um desenho que um leitor
# de fora leu certo), a espera presa ao endereço e ao prazo, o teto de esperas e a pausa da conta. A conta fat37b está
# com o fator ligado: a pausa é conferida com o segredo dela, lido dentro do container e não impresso.
docker exec -i "$PAINEL" python3 -B - > "$W/c37.unidade" 2>&1 <<'PY37'
import hashlib, sys, time
sys.path.insert(0, '/opt/painel')
import fator, qr, sessao
from config import ETAPAS_MAX, FATOR_ERROS_MAX, VALIDADE_ETAPA
chave = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ'    # "12345678901234567890", o segredo de exemplo da RFC 6238
vetores = {59: '287082', 1111111109: '081804', 1111111111: '050471', 1234567890: '005924', 2000000000: '279037', 20000000000: '353130'}
print('rfc', sum(fator.codigo_de(chave, instante // 30) == codigo for instante, codigo in vetores.items()), 'de', len(vetores))
agora = 1111111109
print('folga', ' '.join('sim' if fator.contador_do(chave, fator.codigo_de(chave, agora // 30 + passo), agora) is not None else 'nao' for passo in (-2, -1, 0, 1, 2)))
print('formato', ' '.join('sim' if fator.contador_do(chave, texto, 59) is not None else 'nao' for texto in ('287082', '287 082', '28708', '2870820', 'abcdef', '')))
endereco = fator.endereco('exemplo', chave)
print('endereco', endereco)
desenho = qr.matriz(endereco.encode())
print('qr', len(desenho), hashlib.sha256(qr.svg(desenho, 'QR').encode()).hexdigest())
print('longo', len(fator.endereco('a' * 32, chave, 'x' * 60)) <= 213, len(fator.endereco('a' * 32, chave, 'x' * 200)) <= 213)
try:
    qr.matriz(b'x' * 214); print('teto aceito')
except ValueError:
    print('teto recusado')
espera = sessao.criar_etapa('192.0.2.10', 'exemplo', 'pt')
print('espera', sessao.buscar_etapa(espera, '192.0.2.10') is not None, sessao.buscar_etapa(espera, '192.0.2.11') is None, sessao.buscar_etapa(espera, '192.0.2.10') is None)
espera = sessao.criar_etapa('192.0.2.10', 'exemplo', 'pt')
sessao.ETAPAS[sessao.resumo_token(espera)]['criada'] -= VALIDADE_ETAPA + 1
print('prazo', sessao.buscar_etapa(espera, '192.0.2.10') is None)
for _ in range(ETAPAS_MAX + 50):
    sessao.criar_etapa('192.0.2.10', 'exemplo', 'pt')
print('esperas', len(sessao.ETAPAS) == ETAPAS_MAX)
guardada, passo = fator.segredo_de('fat37b'), int(time.time()) // 30
validos = {fator.codigo_de(guardada, passo + vizinho) for vizinho in (-2, -1, 0, 1, 2)}
errado = next(codigo for codigo in ('000000', '111111', '222222', '333333', '444444', '555555') if codigo not in validos)
respostas = [fator.conferir('fat37b', errado) for _ in range(FATOR_ERROS_MAX)]
print('pausa', respostas.count('codigo'), fator.conferir('fat37b', fator.codigo_de(guardada, passo)) or 'aceito', fator.conferir('ninguem37', errado))
PY37
r_uni=$?; u37() { grep -m1 "^$1 " "$W/c37.unidade" | cut -d ' ' -f 2-; }
F37=0
igual37 "$r_uni" 0; igual37 "$(u37 rfc)" '6 de 6'; igual37 "$(u37 folga)" 'nao sim sim sim nao'; igual37 "$(u37 formato)" 'sim sim nao nao nao nao'
igual37 "$(u37 endereco)" 'otpauth://totp/AllSafe%20FTP%3Aexemplo?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&issuer=AllSafe%20FTP'
igual37 "$(u37 qr)" '41 8795c6696c442db8078d7e52f414b83db6d89ec485b6f6418d11fe82efddf5d3'; igual37 "$(u37 longo)" 'True True'; igual37 "$(grep -c '^teto recusado$' "$W/c37.unidade")" 1
caso "$F37" testes 98 "Segundo fator: vetores da RFC 6238, endereço do aplicativo e código QR" \
  "códigos dos seis instantes de teste da RFC 6238 (SHA-1, 6 dígitos, passo de 30 s): $(u37 rfc); código de dois passos antes, um antes, o atual, um depois e dois depois: $(u37 folga); aceitos \"287082\", \"287 082\", cinco dígitos, sete dígitos, letras e vazio: $(u37 formato); endereço de exemplo: $(u37 endereco); código QR dele, lado em módulos e SHA-256 do SVG: $(u37 qr); endereço com nome de servidor de 60 e de 200 caracteres dentro de 213 bytes: $(u37 longo); texto de 214 bytes no código QR: $(grep -c '^teto recusado$' "$W/c37.unidade") recusa"

F37=0
igual37 "$(u37 espera)" 'True True True'; igual37 "$(u37 prazo)" True; igual37 "$(u37 esperas)" True; igual37 "$(u37 pausa)" '10 pausa segredo'
caso "$F37" seguranca 143 "Segundo fator: espera presa ao endereço e ao prazo, teto de esperas e pausa da conta" \
  "espera aberta por 192.0.2.10: vale para ele, não vale para 192.0.2.11 e é apagada pela tentativa: $(u37 espera); espera com mais de 5 minutos recusada: $(u37 prazo); 250 esperas pedidas e 200 guardadas: $(u37 esperas); códigos errados contados na conta, resposta ao código certo depois deles e resposta para conta sem segredo: $(u37 pausa)"

# ------------------------------------------------------------------ cinco códigos errados
# O reinício zera a contagem do endereço. Cinco códigos errados derrubam a espera e seguram o endereço, como cinco
# senhas erradas: o código certo, depois disso, não encontra espera, e a senha certa espera os 15 minutos.
dc restart painel > /dev/null 2>&1; painel_de_pe
auditoria; a_rec1="$(eventos entrada_codigo_recusado)"; a_ok1="$(grep -c ' evento=entrada_ok admin=fat37b' "$W/auditoria" || true)"
rm -f "$A37"; e_8="$(COMO=fat37b entrar "$A37" "$W/a37.senha")"; d_8="$(destino37)"; proibir "$(etapa37 "$A37")"
calma37; codigo37 "$W/c37.chave3" errado "$W/c37.errado"; ev_5=""
for i in 1 2 3 4 5; do ev_5+="$(passo37 "$A37" "$W/c37.errado")"; done
q_5="$(tem37 'name="usuario"') $(tem37 'name="codigo"')"; b_5="$(biscoitos37 "$W/f37.cab")"
codigo37 "$W/c37.chave3" 0 "$W/c37.cod7"; r_tarde="$(passo37 "$A37" "$W/c37.cod7")"
e_9="$(COMO=fat37b entrar "$A37" "$W/a37.senha")"; s_9="$(biscoito_de "$A37" | wc -c)"
auditoria; n_rec="$(( $(eventos entrada_codigo_recusado) - a_rec1 ))"; n_ok="$(( $(grep -c ' evento=entrada_ok admin=fat37b' "$W/auditoria" || true) - a_ok1 ))"
docker logs "$PAINEL" > "$W/c37.logs" 2>&1; v_aud="$(segredos_em "$W/auditoria")"; v_log="$(segredos_em "$W/c37.logs")"
v_dados="$(cat "$W/c37.chave" "$W/c37.chave2" "$W/c37.chave3" | fold -w 32 | docker exec -i "$PAINEL" sh -c 'grep -r -l -F -f /dev/stdin /painel 2> /dev/null | wc -l')"
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
F37=0
igual37 "$e_8 $d_8" '303 /entrar/codigo'; igual37 "$ev_5" '401 401 401 401 401 '; igual37 "$q_5|$b_5" '1 0|__Host-etapa(vazio) '
igual37 "$r_tarde" '303 /entrar'; igual37 "$e_9 $s_9" '429 0'; igual37 "$n_rec $n_ok" '5 0'; igual37 "$v_aud $v_log $v_dados" '0 0 0'; igual37 "$e_adm" 303
caso "$F37" seguranca 144 "Segundo fator: cinco códigos errados derrubam a espera e seguram o endereço; a chave não vaza" \
  "entrada de fat37b com a senha certa: $e_8 $d_8; cinco códigos errados: $ev_5; a quinta resposta traz o formulário de usuário e senha e o do código: $q_5, cookies: $b_5; código certo em seguida: $r_tarde; senha certa em seguida: $e_9, cookie de sessão: $s_9 bytes; eventos entrada_codigo_recusado e entrada_ok de fat37b a mais: $n_rec e $n_ok; linhas com chave, código de espera, cookie ou token desta etapa na auditoria e no registro do painel: $v_aud e $v_log; arquivos dos dados do painel com alguma das três chaves: $v_dados"

# ------------------------------------------------------------------ remoção da conta e limpeza
r_rem="$(envio /administradores/remover --data-urlencode "csrf=$K" --data-urlencode 'admin=fat37b' --data-urlencode "senha_atual@$W/painel.senha")"
x_rem="$(lista37)|$(guardado37 fat37b)|$(ls "$P37" 2> /dev/null | wc -l)|$(admins)"
F37=0
igual37 "$r_rem" '303 /usuarios?m=admin_removido'; igual37 "$x_rem" "|ausente|0|$ADM37"
caso "$F37" testes 99 "Segundo fator: sai junto com o administrador removido" \
  "remoção de fat37b, com o fator ligado: $r_rem; lista, segredo dele, arquivos na pasta dos segredos do fator e administradores que ficaram: $x_rem"

# ------------------------------------------------------------------ fator obrigatório: o cadastro na entrada
# Com PAINEL_SEGUNDO_FATOR_OBRIGATORIO=sim, a senha certa de quem não tem o fator abre uma espera de dez minutos que só
# serve à tela do cadastro: a chave fica na espera, é gravada com o primeiro código certo e a sessão abre na hora. Vale
# para o administrador e para o usuário do FTP que entra no painel; no FTP nada muda. A bateria roda com nao: este
# trecho liga a obrigação, prova o cadastro e devolve a instância como estava. Nenhum código errado vai à tela do
# código aqui: no cadastro, o código errado não é erro de entrada e não conta para o bloqueio do endereço.
gravar_env "$ENVA" PAINEL_SEGUNDO_FATOR_OBRIGATORIO sim; dep; r_sim37=$?; painel_de_pe
B37="$W/b37.jar"
lista37o() { lista37 | tr ' ' '\n' | grep . | sort | tr '\n' ' '; }                               # a lista do fator, em ordem
cadastra37() { CAMINHO37=/entrar/cadastro passo37 "$@"; }                                         # <pote> <arquivo do código> → "código destino" do formulário do cadastro
chaves_em37() { tr -d ' ' < "$W/corpo" | grep -c -F -f <(cat "$@" | fold -w 32) || true; }        # <arquivos de chave...>: linhas de $W/corpo com alguma delas
arquivo37() { [[ "$(tr -d '\n' 2> /dev/null < "$P37/$1.txt")" == "$(cat "$2")" ]] && echo sim || echo nao; }  # <conta> <arquivo da chave>: o segredo guardado é essa chave?
auditoria; a_cad0="$(eventos fator_cadastrado_na_entrada)"; a_rec2="$(eventos entrada_codigo_recusado)"; a_fal2="$(eventos entrada_falha)"
a_zer0="$(eventos usuario_fator_desligado)"; a_host2="$(eventos admin_fator_desligado_no_host)"

# Duas entradas do administrador com a senha certa: cada uma recebe a espera dela, com uma chave própria.
rm -f "$N37" "$A37" "$B37"
e_10="$(entrar "$N37" "$W/painel.senha")"; d_10="$(destino37)"; b_10="$(biscoitos37)"; proibir "$(etapa37 "$N37")"; s_10="$(biscoito_de "$N37" | wc -c)"
k_10="$(grep -i -c '^set-cookie: __Host-etapa=[A-Za-z0-9_-]\{40,\}; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=600' "$W/entrada.cab")"
t_cad="$(aba -b "$N37" "$B/entrar/cadastro")"; q_cad="$(tem37 '<svg class="qr"') $(tem37 'action="/entrar/cadastro"') $(tem37 'name="senha')"
chave37 "$W/c37.chave4"; n_chave4="$(wc -c < "$W/c37.chave4")"
t_cad2="$(aba -b "$N37" "$B/entrar/cadastro")"; chave37 "$W/c37.outra"; cmp -s "$W/c37.chave4" "$W/c37.outra" && mesma4=sim || mesma4=nao
e_11="$(entrar "$A37" "$W/painel.senha")"; d_11="$(destino37)"; proibir "$(etapa37 "$A37")"
t_cad3="$(aba -b "$A37" "$B/entrar/cadastro")"; chave37 "$W/c37.chave5"; cmp -s "$W/c37.chave4" "$W/c37.chave5" && outra5=nao || outra5=sim
# A espera do cadastro não é sessão, a tela do cadastro não existe sem ela, e levada à tela do código ela cai.
t_f1="$(aba -b "$N37" "$B/usuarios")"; t_f2="$(aba -b "$N37" "$B/meus-arquivos")"
sed 's/__Host-etapa/__Host-sessao/' "$N37" > "$X37"; t_f3="$(aba -b "$X37" "$B/usuarios")"; rm -f "$X37"
t_f4="$(aba "$B/entrar/cadastro")"
e_b="$(entrar "$B37" "$W/painel.senha")"; proibir "$(etapa37 "$B37")"; t_b1="$(aba -b "$B37" "$B/entrar/codigo")"; t_b2="$(aba -b "$B37" "$B/entrar/cadastro")"
# Recusas do formulário: sem o token, de outra origem e com um código que não é o da chave da tela.
calma37; codigo37 "$W/c37.chave4" errado "$W/c37.errado"; codigo37 "$W/c37.chave4" -1 "$W/c37.cod8"
r_st="$(c -o /dev/null -w '%{http_code}' -b "$N37" -H "Origin: $B" --data-urlencode "codigo@$W/c37.cod8" "$B/entrar/cadastro")"
r_or="$(c -o /dev/null -w '%{http_code}' -b "$N37" -H 'Origin: https://outro.example' --data-urlencode "codigo@$W/c37.cod8" "$B/entrar/cadastro")"
r_ce="$(cadastra37 "$N37" "$W/c37.errado")"; q_ce="$(tem37 'O código não confere com a chave desta tela')"
chave37 "$W/c37.outra"; cmp -s "$W/c37.chave4" "$W/c37.outra" && mesma_ce=sim || mesma_ce=nao
x_ce="$(lista37)|$(guardado37 "$ADMIN")"
# O primeiro código certo grava a chave e abre a sessão.
r_cad="$(cadastra37 "$N37" "$W/c37.cod8")"; b_cad="$(biscoitos37 "$W/f37.cab")"; proibir "$(biscoito_de "$N37")"
x_cad="$(lista37)|$(guardado37 "$ADMIN")|$(arquivo37 "$ADMIN" "$W/c37.chave4")"; t_ab="$(aba -b "$N37" "$B/usuarios")"
auditoria; n_cad1="$(( $(eventos fator_cadastrado_na_entrada) - a_cad0 ))"; n_rec2="$(( $(eventos entrada_codigo_recusado) - a_rec2 ))"; n_fal2="$(( $(eventos entrada_falha) - a_fal2 ))"
# A outra espera do mesmo administrador caiu com o cadastro, e a chave dela não substitui a gravada.
codigo37 "$W/c37.chave5" 0 "$W/c37.cod9"; r_2a="$(cadastra37 "$A37" "$W/c37.cod9")"; x_2a="$(guardado37 "$ADMIN")|$(arquivo37 "$ADMIN" "$W/c37.chave4")"
# A mesma recusa, na função: conta que já tem fator não é regravada pelo cadastro da entrada.
u_novo="$(docker exec "$PAINEL" python3 -B -c '
import sys
sys.path.insert(0, "/opt/painel")
import fator
antes = fator.segredo_de(sys.argv[1])
print(fator.ligar(sys.argv[1], fator.novo_segredo(), 1, so_novo=True), bool(antes) and fator.segredo_de(sys.argv[1]) == antes)' "$ADMIN" 2>&1)"
# Entrada seguinte: a senha leva ao código, e a espera do código não serve ao cadastro (cai, em outro pote).
e_12="$(entrar "$J" "$W/painel.senha")"; d_12="$(destino37)"; proibir "$(etapa37 "$J")"
rm -f "$A37"; e_13="$(entrar "$A37" "$W/painel.senha")"; d_13="$(destino37)"; proibir "$(etapa37 "$A37")"
t_c1="$(aba -b "$A37" "$B/entrar/cadastro")"; t_c2="$(aba -b "$A37" "$B/entrar/codigo")"
codigo37 "$W/c37.chave4" 0 "$W/c37.cod10"; r_12="$(passo37 "$J" "$W/c37.cod10")"
[[ "$r_12" == '303 /' ]] || { codigo37 "$W/c37.chave4" 1 "$W/c37.cod10"; r_12="$(passo37 "$J" "$W/c37.cod10")"; }
proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
t_seg3="$(aba -b "$J" "$B/seguranca")"; q_seg3="$(tem37 'PAINEL_SEGUNDO_FATOR_OBRIGATORIO=sim')"
auditoria; docker logs "$PAINEL" > "$W/c37.logs" 2>&1; v_aud2="$(segredos_em "$W/auditoria")"; v_log2="$(segredos_em "$W/c37.logs")"
F37=0
igual37 "$r_sim37" 0; igual37 "$e_10 $d_10|$b_10|$k_10|$s_10" '303 /entrar/cadastro|__Host-etapa __Host-idioma |1|0'
igual37 "$t_cad $q_cad $n_chave4 $mesma4" '200  1 1 0 32 sim'; igual37 "${t_cad2%% *}" 200
igual37 "$r_cad|$b_cad" '303 /|__Host-etapa(vazio) __Host-sessao '; igual37 "$x_cad" "$ADMIN |600 32|sim"; igual37 "$t_ab" '200 '
igual37 "$e_12 $d_12 $r_12" '303 /entrar/codigo 303 /'; igual37 "${t_seg3%% *}" 200; [[ "$q_seg3" -ge 1 ]] || F37=1; igual37 "$n_cad1" 1
caso "$F37" testes 101 "Fator obrigatório: administrador sem fator cadastra na entrada e passa a entrar com o código" \
  "deploy com PAINEL_SEGUNDO_FATOR_OBRIGATORIO=sim: saída $r_sim37; entrada de $ADMIN, sem fator, com a senha certa: $e_10 $d_10, cookies gravados: $b_10, cookie de sessão: $s_10 bytes; tela do cadastro: $t_cad, código QR, formulário e campo de senha: $q_cad, chave de $n_chave4 caracteres, a mesma ao reabrir a tela: $mesma4; primeiro código certo: $r_cad, cookies: $b_cad; lista, segredo no host (modo e tamanho) e igual à chave da tela: $x_cad; aba Usuários com a sessão aberta: $t_ab; entrada seguinte: $e_12 $d_12, com o código: $r_12; aba Segurança diz que o fator é obrigatório: $q_seg3; eventos fator_cadastrado_na_entrada a mais: $n_cad1"

F37=0
igual37 "$k_10 $s_10" '1 0'; igual37 "$t_f1|$t_f2|$t_f3|$t_f4" '303 /entrar|303 /entrar|303 /entrar|303 /entrar'
igual37 "$e_b $t_b1|$t_b2" '303 303 /entrar|303 /entrar'; igual37 "$r_st $r_or" '400 403'; igual37 "$v_aud2 $v_log2" '0 0'
caso "$F37" seguranca 145 "Fator obrigatório: a espera do cadastro não abre o painel, e a chave não vai para a auditoria" \
  "cookie da espera com Path=/, Secure, HttpOnly, SameSite=Strict e Max-Age=600: $k_10; cookie de sessão depois da senha certa: $s_10 bytes; aba Usuários e Meus arquivos com o cookie da espera: $t_f1 e $t_f2; cookie da espera apresentado como sessão: $t_f3; tela do cadastro sem espera aberta: $t_f4; outra espera de cadastro levada à tela do código: $t_b1, e de volta ao cadastro: $t_b2; cadastro sem o token do formulário: $r_st; de outra origem: $r_or; linhas com chave, código de espera, cookie ou token desta etapa na auditoria e no registro do painel: $v_aud2 e $v_log2"

F37=0
igual37 "$r_ce $q_ce $mesma_ce" '400  1 sim'; igual37 "$x_ce" '|ausente'; igual37 "$n_rec2 $n_fal2" '0 0'
igual37 "$e_11 $d_11 $outra5" '303 /entrar/cadastro sim'; igual37 "$r_2a" '303 /entrar'; igual37 "$x_2a" '600 32|sim'; igual37 "$u_novo" 'False True'
igual37 "$e_13 $d_13|$t_c1|$t_c2" '303 /entrar/codigo|303 /entrar|303 /entrar'
caso "$F37" seguranca 146 "Fator obrigatório: código errado não cadastra, e conta que já tem fator não recebe outra chave" \
  "código errado no cadastro: $r_ce, aviso na tela: $q_ce, a mesma chave na tela: $mesma_ce; lista e segredo depois: $x_ce; eventos entrada_codigo_recusado e entrada_falha a mais: $n_rec2 e $n_fal2; segunda entrada de $ADMIN antes do cadastro: $e_11 $d_11, com outra chave: $outra5; código certo da segunda chave depois do cadastro da primeira: $r_2a; segredo guardado (modo e tamanho) e igual à primeira chave: $x_2a; fator.ligar com so_novo em conta que já tem fator, e segredo intacto: $u_novo; espera do código levada ao cadastro: $t_c1, e de volta ao código: $t_c2"

# ------------------------------------------------------------------ fator obrigatório: usuário do FTP
# O usuário do FTP cadastra na entrada do painel e cai em Meus arquivos; no FTP, continua entrando só com a senha. A
# conta do fator dele é ftp.<nome>. Ele não alcança as telas de fator da administração, e o administrador zera o fator
# dele sem ver chave nenhuma.
rm -f "$U37" "$A37"
e_u1="$(COMO=f37 entrar "$U37" "$W/f37.senha")"; d_u1="$(destino37)"; proibir "$(etapa37 "$U37")"
t_u1="$(aba -b "$U37" "$B/entrar/cadastro")"; q_u1="$(tem37 '<svg class="qr"') $(tem37 'action="/entrar/cadastro"')"; chave37 "$W/c37.chave6"
t_u2="$(aba -b "$U37" "$B/meus-arquivos")"
calma37; codigo37 "$W/c37.chave6" -1 "$W/c37.cod11"; r_u1="$(cadastra37 "$U37" "$W/c37.cod11")"; b_u1="$(biscoitos37 "$W/f37.cab")"; proibir "$(biscoito_de "$U37")"
x_u1="$(lista37o)|$(guardado37 ftp.f37)|$(arquivo37 ftp.f37 "$W/c37.chave6")"; t_u3="$(aba -b "$U37" "$B/meus-arquivos")"
r_ftp="$(ftp_curl tls f37 "$W/f37.senha" "$F/")"; q_ftp="$(resposta 230 | cut -c1-3)"
e_u2="$(COMO=f37 entrar "$A37" "$W/f37.senha")"; d_u2="$(destino37)"; proibir "$(etapa37 "$A37")"
codigo37 "$W/c37.chave6" 0 "$W/c37.cod12"; r_u2="$(passo37 "$A37" "$W/c37.cod12")"
[[ "$r_u2" == '303 /meus-arquivos' ]] || { codigo37 "$W/c37.chave6" 1 "$W/c37.cod12"; r_u2="$(passo37 "$A37" "$W/c37.cod12")"; }
proibir "$(biscoito_de "$A37")"
DUAS37="$(printf '%s\n' "$ADMIN" ftp.f37 | sort | tr '\n' ' ')"
F37=0
igual37 "$e_u1 $d_u1" '303 /entrar/cadastro'; igual37 "$t_u1 $q_u1" '200  1 1'; igual37 "$t_u2" '303 /entrar'
igual37 "$r_u1|$b_u1" '303 /meus-arquivos|__Host-etapa(vazio) __Host-sessao '; igual37 "$x_u1" "$DUAS37|600 32|sim"; igual37 "$t_u3" '200 '
igual37 "$r_ftp $q_ftp" '0 230'; igual37 "$e_u2 $d_u2 $r_u2" '303 /entrar/codigo 303 /meus-arquivos'
caso "$F37" testes 102 "Fator obrigatório: usuário do FTP cadastra na entrada do painel, e no FTP entra só com a senha" \
  "entrada de f37 no painel, sem fator, com a senha certa: $e_u1 $d_u1; tela do cadastro: $t_u1, código QR e formulário: $q_u1; Meus arquivos com o cookie da espera: $t_u2; primeiro código certo: $r_u1, cookies: $b_u1; lista, segredo de ftp.f37 no host (modo e tamanho) e igual à chave da tela: $x_u1; Meus arquivos com a sessão aberta: $t_u3; FTPS de f37 só com a senha: saída $r_ftp do curl, resposta $q_ftp; entrada seguinte no painel: $e_u2 $d_u2, com o código: $r_u2"

# Com a sessão dele: as telas e os formulários de fator da administração não existem, e o cadastro não reabre.
KU="$(token37 "$U37")"; proibir "$KU"; ev_u2=""
for caminho in "/administradores/fator?admin=$ADMIN" '/usuarios/fator?usuario=f37' /usuarios/fator; do ev_u2+="$(aba -b "$U37" "$B$caminho")"; done
p_u3="$(POTE="$U37" envio /usuarios/fator/desligar --data-urlencode "csrf=$KU" --data-urlencode 'usuario=f37' --data-urlencode "senha_atual@$W/f37.senha")"
p_u4="$(desliga37 "$U37" "$KU" "$ADMIN" "$W/f37.senha")"; t_u4="$(aba -b "$U37" "$B/entrar/cadastro")"
x_u2="$(lista37o)|$(arquivo37 "$ADMIN" "$W/c37.chave4")|$(arquivo37 ftp.f37 "$W/c37.chave6")"; cmp -s "$W/c37.chave4" "$W/c37.chave6" && distintas=nao || distintas=sim
# A tela em que o administrador zera o fator do usuário, e a lista de usuários, não trazem chave nem código QR.
t_z="$(aba -b "$J" "$B/usuarios/fator?usuario=f37")"; q_z="$(tem37 'class="segredo"') $(tem37 '<svg class="qr"') $(tem37 'action="/usuarios/fator/desligar"')"; v_z="$(chaves_em37 "$W/c37.chave4" "$W/c37.chave6")"
t_l="$(aba -b "$J" "$B/usuarios")"; q_l="$(tem37 'href="/usuarios/fator?usuario=f37"')"; v_l="$(chaves_em37 "$W/c37.chave4" "$W/c37.chave6")"
F37=0
igual37 "$ev_u2" '404 404 404 '; igual37 "${p_u3%% *} ${p_u4%% *}" '404 404'; igual37 "$t_u4" '303 /entrar'; igual37 "$x_u2|$distintas" "$DUAS37|sim|sim|sim"
igual37 "$t_z $q_z $v_z" '200  0 0 1 0'; igual37 "${t_l%% *} $v_l" '200 0'; [[ "$q_l" -ge 1 ]] || F37=1
caso "$F37" seguranca 147 "Fator obrigatório: usuário do FTP não alcança o fator de ninguém, e o administrador não vê chave" \
  "telas de fator da administração com a sessão de f37: $ev_u2; formulário de zerar o próprio fator: $p_u3; formulário de desligar o de $ADMIN: $p_u4; tela do cadastro com a sessão dele, sem espera: $t_u4; lista, segredo de $ADMIN e de ftp.f37 intactos: $x_u2, chaves diferentes: $distintas; tela de zerar o fator de f37 aberta por $ADMIN: $t_z, chave, código QR e formulário: $q_z, linhas com alguma das duas chaves: $v_z; lista de usuários com o botão do fator de f37: $q_l, linhas com alguma das duas chaves: $v_l"

# O administrador zera, o terminal desliga e a remoção do usuário leva o fator junto; cada cadastro novo traz outra chave.
r_z="$(envio /usuarios/fator/desligar --data-urlencode "csrf=$K" --data-urlencode 'usuario=f37' --data-urlencode "senha_atual@$W/painel.senha")"
x_z="$(lista37o)|$(guardado37 ftp.f37)"; t_l2="$(aba -b "$J" "$B/usuarios")"; q_l2="$(tem37 'href="/usuarios/fator?usuario=f37"')"
rm -f "$U37"; e_u3="$(COMO=f37 entrar "$U37" "$W/f37.senha")"; d_u3="$(destino37)"; proibir "$(etapa37 "$U37")"
t_u5="$(aba -b "$U37" "$B/entrar/cadastro")"; chave37 "$W/c37.chave7"; cmp -s "$W/c37.chave6" "$W/c37.chave7" && nova7=nao || nova7=sim
calma37; codigo37 "$W/c37.chave7" -1 "$W/c37.cod13"; r_u3="$(cadastra37 "$U37" "$W/c37.cod13")"; proibir "$(biscoito_de "$U37")"
x_t1="$(terminal37 | grep -m1 '^ftp\.f37: ')"; x_t2="$(terminal37 desligar ftp.f37 | tail -1)"; x_t3="$(lista37o)|$(guardado37 ftp.f37)"
rm -f "$U37"; e_u4="$(COMO=f37 entrar "$U37" "$W/f37.senha")"; d_u4="$(destino37)"; proibir "$(etapa37 "$U37")"
t_u6="$(aba -b "$U37" "$B/entrar/cadastro")"; chave37 "$W/c37.chave8"; cmp -s "$W/c37.chave7" "$W/c37.chave8" && nova8=nao || nova8=sim
calma37; codigo37 "$W/c37.chave8" -1 "$W/c37.cod14"; r_u4="$(cadastra37 "$U37" "$W/c37.cod14")"; proibir "$(biscoito_de "$U37")"
x_u4="$(lista37o)|$(guardado37 ftp.f37)|$(stat -c %a "$P37")"
# Linhas fora da regra de conta, postas à mão na lista: o painel e o terminal não as leem como conta.
docker exec "$PAINEL" sh -c 'printf "%s\n" ../fora ftp.ftp.x Maiuscula ftp. "a b" >> /painel/segundo-fator'
n_bruta="$(docker exec "$PAINEL" sh -c 'grep -c . /painel/segundo-fator')"
n_term="$(terminal37 | grep -c .)"; n_fora="$(terminal37 | grep -c -e fora -e 'ftp\.ftp' -e Maiuscula -e 'ftp\.:' -e 'a b' || true)"
t_l3="$(aba -b "$J" "$B/usuarios")"; t_s3="$(aba -b "$J" "$B/seguranca")"
# A remoção do usuário pelo painel apaga o fator dele, e a lista regravada fica só com as contas válidas.
r_rm="$(envio /usuarios/remover --data-urlencode 'usuario=f37' --data-urlencode "csrf=$K" --data-urlencode 'confirmar=sim')"
x_rm="$(lista37)|$(guardado37 ftp.f37)|$(terminal37 | grep -c '^ftp\.' || true)"
auditoria; docker logs "$PAINEL" > "$W/c37.logs" 2>&1; v_aud3="$(segredos_em "$W/auditoria")"; v_log3="$(segredos_em "$W/c37.logs")"
v_dados3="$(cat "$W/c37.chave4" "$W/c37.chave5" "$W/c37.chave6" "$W/c37.chave7" "$W/c37.chave8" | fold -w 32 | docker exec -i "$PAINEL" sh -c 'grep -r -l -F -f /dev/stdin /painel 2> /dev/null | wc -l')"
n_cad2="$(( $(eventos fator_cadastrado_na_entrada) - a_cad0 ))"; n_zer="$(( $(eventos usuario_fator_desligado) - a_zer0 ))"; n_host2="$(( $(eventos admin_fator_desligado_no_host) - a_host2 ))"
F37=0
igual37 "$r_z" '303 /usuarios?m=fator_zerado'; igual37 "$x_z|$q_l2" "$ADMIN |ausente|0"; igual37 "$e_u3 $d_u3 $nova7 $r_u3" '303 /entrar/cadastro sim 303 /meus-arquivos'
igual37 "$x_t1" 'ftp.f37: ligado'; igual37 "$x_t2" 'ftp.f37: segundo fator desligado'; igual37 "$x_t3" "$ADMIN |ausente"
igual37 "$e_u4 $d_u4 $nova8 $r_u4" '303 /entrar/cadastro sim 303 /meus-arquivos'; igual37 "${x_u4%|*}" "$DUAS37|600 32"
igual37 "$r_rm" '303 /usuarios?m=removido'; igual37 "$x_rm" "$ADMIN |ausente|0"; igual37 "$n_cad2 $n_zer $n_host2" '4 1 1'
caso "$F37" testes 103 "Fator obrigatório: o administrador zera o do usuário do FTP, o terminal desliga e a remoção leva junto" \
  "$ADMIN zera o fator de f37, com a senha: $r_z; lista, segredo e botão do fator na lista de usuários depois: $x_z e $q_l2; entrada seguinte de f37: $e_u3 $d_u3, chave nova: $nova7, cadastro: $r_u3; terminal: \"$x_t1\", desligar: \"$x_t2\", lista e segredo depois: $x_t3; terceira entrada: $e_u4 $d_u4, chave nova: $nova8, cadastro: $r_u4; remoção de f37 pelo painel, com o fator ligado: $r_rm; lista, segredo e contas ftp. no terminal depois: $x_rm; eventos fator_cadastrado_na_entrada, usuario_fator_desligado e admin_fator_desligado_no_host a mais: $n_cad2, $n_zer e $n_host2"

F37=0
igual37 "$x_u4" "$DUAS37|600 32|700"; igual37 "$n_bruta" 7; igual37 "$n_term $n_fora" "$(( $(printf '%s' "$ADM37" | wc -w) + 1 )) 0"
igual37 "${t_l3%% *} ${t_s3%% *}" '200 200'; igual37 "${x_rm%%|*}" "$ADMIN "; igual37 "$v_aud3 $v_log3 $v_dados3" '0 0 0'
caso "$F37" seguranca 148 "Fator obrigatório: segredo do usuário do FTP em arquivo 0600, e linha fora da regra não vira conta" \
  "lista, segredo de ftp.f37 no host (modo e tamanho) e modo da pasta dos segredos do fator: $x_u4; lista com cinco linhas fora da regra postas à mão: $n_bruta linhas; contas que o terminal mostra e, entre elas, as de fora da regra: $n_term e $n_fora; abas Usuários e Segurança com a lista assim: ${t_l3%% *} e ${t_s3%% *}; lista regravada pela remoção do usuário: \"${x_rm%%|*}\"; linhas com chave, código de espera, cookie ou token desta etapa na auditoria e no registro do painel, e arquivos dos dados do painel com alguma chave: $v_aud3, $v_log3 e $v_dados3"

# ------------------------------------------------------------------ de volta ao fator opcional
# Com nao, a entrada é a de antes: quem tem o fator continua entrando com o código, quem não tem entra só com a senha,
# e a tela do cadastro não existe. Valor fora de sim e nao é recusado pelo deploy.sh e pelo container.
gravar_env "$ENVA" PAINEL_SEGUNDO_FATOR_OBRIGATORIO nao; dep; r_nao37=$?; painel_de_pe
e_n1="$(entrar "$J" "$W/painel.senha")"; d_n1="$(destino37)"; proibir "$(etapa37 "$J")"
calma37; codigo37 "$W/c37.chave4" 0 "$W/c37.cod15"; r_n1="$(passo37 "$J" "$W/c37.cod15")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
r_n2="$(desliga37 "$J" "$K" "$ADMIN" "$W/painel.senha")"; x_n2="$(lista37)|$(ls "$P37" 2> /dev/null | wc -l)|$(admins)"
rm -f "$N37"; e_n3="$(entrar "$N37" "$W/painel.senha")"; d_n3="$(destino37)"; b_n3="$(biscoitos37)"; proibir "$(biscoito_de "$N37")"
t_n4="$(aba "$B/entrar/cadastro")"; t_n5="$(aba -b "$J" "$B/seguranca")"; q_n5="$(tem37 'PAINEL_SEGUNDO_FATOR_OBRIGATORIO=sim')"
r_inv37="$(recusa_deploy PAINEL_SEGUNDO_FATOR_OBRIGATORIO=talvez)"; r_cont37="$(recusa_container painel PAINEL_SEGUNDO_FATOR_OBRIGATORIO=talvez)"
F37=0
igual37 "$r_nao37" 0; igual37 "$e_n1 $d_n1 $r_n1" '303 /entrar/codigo 303 /'; igual37 "$r_n2" "$DESLIGADO37"; igual37 "$x_n2" "|0|$ADM37"
igual37 "$e_n3 $d_n3" '303 /'; [[ "$b_n3" == *'__Host-sessao '* && "$b_n3" != *'__Host-etapa '* ]] || F37=1; igual37 "$t_n4" '303 /entrar'; igual37 "${t_n5%% *} $q_n5" '200 0'
recusou "$r_inv37" "PAINEL_SEGUNDO_FATOR_OBRIGATORIO deve ser 'sim' ou 'nao'" || F37=1; recusou "$r_cont37" "PAINEL_SEGUNDO_FATOR_OBRIGATORIO deve ser 'sim' ou 'nao'" || F37=1
caso "$F37" testes 104 "Fator opcional: com nao a entrada volta a ser a de antes, e valor fora de sim e nao é recusado" \
  "deploy com PAINEL_SEGUNDO_FATOR_OBRIGATORIO=nao: saída $r_nao37; entrada de $ADMIN, com o fator cadastrado: $e_n1 $d_n1, com o código: $r_n1; ele desliga o próprio fator: $r_n2; lista, arquivos na pasta dos segredos do fator e administradores: $x_n2; entrada seguinte, só com a senha: $e_n3 $d_n3, cookies gravados: $b_n3; tela do cadastro: $t_n4; aba Segurança diz que o fator é obrigatório: $q_n5; valor talvez no deploy.sh: $r_inv37; no container do painel: $r_cont37"

mu del f37    # o usuário já saiu pelo painel; fica para o caso de a remoção acima ter falhado
docker exec "$FTP" rm -rf /data/fat37 > /dev/null 2>&1
rm -f "$N37" "$A37" "$U37" "$B37" "$W"/c37.* "$W/a37.senha" "$W/f37.senha" "$W/errada37.senha"
painel_de_pe
