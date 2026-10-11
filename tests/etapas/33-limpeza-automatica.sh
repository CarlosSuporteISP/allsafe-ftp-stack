#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa AG: limpeza automática. Só o administrador define a regra de cada usuário, com a senha dele, pela tela ou
# pelo terminal. A passada mantém os arquivos mais recentes de cada pasta ou apaga os que passaram do prazo, sem
# tocar em link simbólico, em nome começado por ponto nem no que está fora da pasta do usuário. A etapa roda com a
# passada do painel parada (PAINEL_RETENCAO_MINUTOS=0), para cada passada ser a que ela pede pelo terminal, e só
# no fim liga a passada de minuto em minuto, para vê-la rodar sozinha.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

ret_0="$(env_file="$ENVA" env_valor PAINEL_RETENCAO_MINUTOS 60)"
gravar_env "$ENVA" PAINEL_RETENCAO_MINUTOS 0; dep; r_dep0=$?
# O reinício do painel encerra as sessões e zera a memória das recusas (a auditoria guarda uma por minuto de cada tipo).
dc restart painel > /dev/null 2>&1; painel_de_pe; inicio33=$SECONDS
min_0="$(docker exec "$PAINEL" printenv PAINEL_RETENCAO_MINUTOS)"
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"

tem33() { grep -c -F -- "$1" "$W/corpo" || true; }                                             # <texto>: linhas da última tela com ele
linhas33() { grep -c -E -- "$1" "$W/auditoria" || true; }                                      # <expressão>: linhas da auditoria com ela
etiquetas33() { grep -o -F '<span class="etiqueta atencao" title="Limpeza automática: ' "$W/corpo" | wc -l; }  # usuários com a etiqueta da limpeza na lista
arv33() { docker exec "$FTP" sh -c 'cd "$1" && find . -mindepth 1 -printf "%P\n" | LC_ALL=C sort | tr "\n" " "' sh "$1"; }  # <pasta>: tudo o que há nela, em ordem
soma33() { docker exec "$FTP" sh -c 'find "$@" -xdev -printf "%M %u:%g %s %T@ %p\n" | LC_ALL=C sort | sha256sum | cut -c1-16' sh "$@"; }  # <pasta...>: soma do que há nelas
# O cadastro e as listas de /auth, pelo conteúdo, sem os arquivos de estado que o servidor regrava sozinho.
auth33() { docker exec "$FTP" sh -c 'find /auth -xdev -type f ! -name "*.estado" ! -name ".lock" ! -path "/auth/chegadas/*" -exec sha256sum {} + | LC_ALL=C sort -k2 | sha256sum | cut -c1-16'; }
lista33() { docker exec "$FTP" sha256sum /auth/limites.lista 2>/dev/null | cut -c1-16; }       # soma da lista em que a regra é gravada
planta33() { docker exec -i "$FTP" sh -s; }                                                    # roda no container do FTP o que vier pela entrada
passa33() { docker exec "$PAINEL" python3 /opt/painel/servidor.py --retencao "$@" > "$W/passada" 2>&1; }  # [--simular]: a passada, pedida pelo terminal
linha33() { grep -m1 "^$1 " "$W/passada" || true; }                                            # <usuário>: o que a última passada disse da pasta dele
regra33() { mu retencao "$1" ""; tr '\n' ' ' < "$W/mu.log"; }                                  # <usuário> → "ultimos=<N> dias=<N> "
token33() { c -b "$1" "$B/meus-arquivos" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1; }  # <pote>: token dos formulários do usuário do FTP
# <pote> <token> <usuário> <ultimos> <dias> <arquivo da senha ou ""> [opções do curl...] → "código destino" do formulário
# da limpeza. ORIGEM33 troca o cabeçalho Origin. A tela da resposta fica em $W/corpo.
grava33() {
  local pote="$1" token="$2" usuario="$3" ultimos="$4" dias="$5" senha="$6"; shift 6
  local -a campos=(--data-urlencode "csrf=$token" --data-urlencode "usuario=$usuario" --data-urlencode "ultimos=$ultimos" --data-urlencode "dias=$dias")
  [[ -n "$senha" ]] && campos+=(--data-urlencode "senha_atual@$senha")
  c -o "$W/corpo" -w '%{http_code} %{redirect_url}' -b "$pote" -H "Origin: ${ORIGEM33:-$B}" "$@" "${campos[@]}" "$B/usuarios/limpeza" | sed "s|$B||"
}
# <pasta do usuário> <corte, em segundos> → o que sairia e o que saiu com o motor da limpeza chamado direto, com o
# corte dado: a data de chegada de um arquivo não pode ser recuada, então a regra por dias é provada com o corte
# posto entre dois grupos de arquivos.
motor33() {
  docker exec -i "$PAINEL" python3 - "$@" <<'PYTHON'
import os
import sys
sys.path.insert(0, '/opt/painel')
import limpeza
from aba_arquivos import abrir, partes
for simular in (True, False):
    conta = {'arquivos': 0, 'pastas': 0, 'bytes': 0, 'erros': 0}
    pasta = abrir(partes(sys.argv[1]), True)
    limpeza.limpar_pasta(pasta, {'ultimos': 0, 'dias': 1}, float(sys.argv[2]), conta, simular)
    os.close(pasta)
    print('simular' if simular else 'real', ' '.join(f'{chave}={valor}' for chave, valor in conta.items()))
PYTHON
}

for n in ret33 par33 viz33 fora33; do nova_senha "$W/$n.senha"; done
: > "$W/vazio33.jar"
mu add ret33 "$W/ret33.senha" ret33; r_ret=$?
mu add par33 "$W/par33.senha" par33; r_par=$?
mu add viz33 "$W/viz33.senha" ret33/olt-v; r_viz=$?
mu add fora33 "$W/fora33.senha" fora33; r_fora=$?
# par33 fica com a regra gravada e três arquivos desde já: com a passada parada, nada pode sair deles.
planta33 <<'SH'
set -e; cd /data/par33
for n in 1 2 3; do echo p > "p$n.cfg"; touch -d "$n days ago" "p$n.cfg"; done
chown -hR ftpdata:ftpdata .
SH
mu retencao par33 "" ultimos=1; r_par_regra=$?
auditoria; n_alt="$(eventos retencao_alterada)"; n_sen="$(eventos admin_senha_atual_recusada)"; n_pap="$(eventos recusa_papel)"; n_apl="$(eventos retencao_aplicada)"

# ------------------------------------------------------------------ só o administrador define, com a senha dele
s_antes="$(lista33)"
x_semtoken="$(grava33 "$J" '' ret33 3 '' "$W/painel.senha")"
x_token="$(grava33 "$J" token-errado ret33 3 '' "$W/painel.senha")"
x_origem="$(ORIGEM33=https://fora.example grava33 "$J" "$K" ret33 3 '' "$W/painel.senha")"
x_semsessao="$(grava33 "$W/vazio33.jar" "$K" ret33 3 '' "$W/painel.senha")"
# Senha errada e senha ausente: as duas contam como erro de senha do endereço, por isso são só duas.
x_errada="$(grava33 "$J" "$K" ret33 3 '' "$W/errada.senha")"; x_errada_f="$(tem33 'A sua senha atual não confere. Nada foi alterado.')"
x_semsenha="$(grava33 "$J" "$K" ret33 3 '' '')"; x_semsenha_f="$(tem33 'A sua senha atual não confere. Nada foi alterado.')"
x_val=""; x_val_f=0
for par in ultimos=0 ultimos=100001 ultimos=abc ultimos=-1 ultimos=1.5 dias=0 dias=3651 dias=abc; do
  u33=''; d33=''; if [[ "$par" == ultimos=* ]]; then u33="${par#*=}"; else d33="${par#*=}"; fi
  x_val+="$(grava33 "$J" "$K" ret33 "$u33" "$d33" "$W/painel.senha" | cut -c1-3) "; x_val_f=$(( x_val_f + $(tem33 'Valor inválido em') ))
done
x_nao="$(grava33 "$J" "$K" nao-existe33 3 '' "$W/painel.senha")"; x_nome="$(grava33 "$J" "$K" '../ret33' 3 '' "$W/painel.senha")"
# O usuário do FTP, com a sessão e o token dele: a rota e a tela da limpeza não existem para ele.
e_usu="$(COMO=ret33 entrar "$W/ret33.jar" "$W/ret33.senha")"; proibir "$(biscoito_de "$W/ret33.jar")"; K_u="$(token33 "$W/ret33.jar")"; proibir "$K_u"
u_post="$(grava33 "$W/ret33.jar" "$K_u" ret33 3 '' "$W/ret33.senha")"
u_tela="$(aba -b "$W/ret33.jar" "$B/usuarios/editar?usuario=ret33")"
u_meus="$(aba -b "$W/ret33.jar" "$B/meus-arquivos")"; u_rota="$(tem33 '/usuarios/limpeza')"
auditoria; d_alt=$(( $(eventos retencao_alterada) - n_alt )); d_sen=$(( $(eventos admin_senha_atual_recusada) - n_sen )); d_pap=$(( $(eventos recusa_papel) - n_pap ))
s_depois="$(lista33)"; x_regra="$(regra33 ret33)"
# Entrada certa do administrador: zera a contagem de erros do endereço antes de seguir.
e_adm2="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
# Pelo terminal: valor fora da regra, chave desconhecida, par sem valor e usuário que não existe.
t_lim=""
for par in ultimos=0 ultimos=100001 dias=abc dias=3651; do mu retencao ret33 "" "$par"; t_lim+="$? $(grep -c 'Limite invalido' "$W/mu.log") · "; done
mu retencao ret33 "" cor=1; t_chave="$? $(grep -q 'Uso:' "$W/mu.log" && echo uso)"
mu retencao ret33 "" ultimos; t_par="$? $(grep -q 'Uso:' "$W/mu.log" && echo uso)"
mu retencao nao-existe33 "" ultimos=3; t_nao="$? $(grep -c 'Usuario nao existe: nao-existe33' "$W/mu.log")"
t_regra="$(regra33 ret33)"; s_terminal="$(lista33)"
# O intervalo das passadas: o container do painel recusa o valor fora da regra antes de tocar em qualquer pasta.
ok_int=0; ev_int=""
for valor in -1 1441 abc 1.5 10000; do
  rec="$(recusa_container painel "PAINEL_RETENCAO_MINUTOS=$valor")"; recusou "$rec" 'PAINEL_RETENCAO_MINUTOS deve ficar entre 0 e 1440' || ok_int=1; ev_int+="$valor: $rec; "
done
[[ "$r_dep0" == 0 && "$min_0" == 0 && "$e_adm" == 303 && "$r_ret$r_par$r_viz$r_fora$r_par_regra" == 00000 && "$x_semtoken" == "403 " && "$x_token" == "403 " && "$x_origem" == "403 " \
  && "$x_semsessao" == "303 /entrar" && "$x_errada" == "403 " && "$x_errada_f" -ge 1 && "$x_semsenha" == "403 " && "$x_semsenha_f" -ge 1 \
  && "$x_val" == "400 400 400 400 400 400 400 400 " && "$x_val_f" == 8 && "$x_nao" == "404 " && "$x_nome" == "404 " && "$e_usu" == 303 && -n "$K_u" && "$u_post" == "404 " \
  && "$u_tela" == "404 " && "$u_meus" == "200 " && "$u_rota" == 0 && "$d_alt" == 0 && "$d_sen" == 2 && "$d_pap" -ge 1 && -n "$s_antes" && "$s_antes" == "$s_depois" \
  && "$x_regra" == "ultimos= dias= " && "$e_adm2" == 303 && "$t_lim" == "1 1 · 1 1 · 1 1 · 1 1 · " && "$t_chave" == "2 uso" && "$t_par" == "2 uso" && "$t_nao" == "1 1" \
  && "$t_regra" == "ultimos= dias= " && "$s_terminal" == "$s_antes" && "$ok_int" == 0 ]]
caso $? seguranca 123 "Só o administrador define a limpeza automática, com a senha dele" "formulário da limpeza de ret33 com a sessão do administrador: sem token $x_semtoken, token errado $x_token, Origin de fora $x_origem; sem sessão: $x_semsessao; senha atual errada: $x_errada, sem a senha: $x_semsenha (telas com 'A sua senha atual não confere. Nada foi alterado.': $x_errada_f e $x_semsenha_f; admin_senha_atual_recusada a mais: $d_sen); valores ultimos=0, 100001, abc, -1, 1.5 e dias=0, 3651, abc: $x_val(telas com 'Valor inválido em': $x_val_f de 8); usuário que não existe: $x_nao, nome fora da regra: $x_nome; usuário do FTP ret33 (entrada $e_usu), com a sessão e o token dele: POST $u_post, tela de editar $u_tela, /meus-arquivos $u_meus com a rota da limpeza em $u_rota linha(s), recusa_papel a mais: $d_pap; retencao_alterada a mais: $d_alt; regra de ret33 depois de tudo: $x_regra; soma da lista das regras antes $s_antes, depois $s_depois; pelo terminal (saída e linhas 'Limite invalido') ultimos=0, ultimos=100001, dias=abc, dias=3651: $t_lim; chave desconhecida: $t_chave; par sem valor: $t_par; usuário que não existe: $t_nao; regra depois: $t_regra, soma $s_terminal; container do painel com PAINEL_RETENCAO_MINUTOS fora da regra: $ev_int"

# ------------------------------------------------------------------ a regra pela tela do administrador
t_ed="$(aba -b "$J" "$B/usuarios/editar?usuario=ret33")"
f_cartao="$(tem33 '<section class="cartao estreito" id="limpeza">')"; f_form="$(tem33 '<form method="post" action="/usuarios/limpeza" autocomplete="off">')"
f_ult="$(tem33 'id="limpeza_ultimos" name="ultimos" type="number" min="1" max="100000"')"; f_dias="$(tem33 'id="limpeza_dias" name="dias" type="number" min="1" max="3650"')"
f_desl="$(tem33 'Desligada: nenhum arquivo deste usuário é apagado sozinho.')"; f_lix="$(tem33 'O painel <strong>não tem lixeira</strong>')"
f_viz="$(tem33 'também é alcançada por <strong>viz33</strong>')"; f_parada="$(tem33 'a limpeza automática está parada nesta')"
t_l0="$(aba -b "$J" "$B/usuarios")"; etq_0="$(etiquetas33)"
g_1="$(grava33 "$J" "$K" ret33 4 30 "$W/painel.senha")"; r_1="$(regra33 ret33)"
t_l1="$(aba -b "$J" "$B/usuarios?m=limpeza")"; m_1="$(tem33 'Limpeza automática gravada. Vale na próxima passada do painel.')"; etq_1="$(etiquetas33)"
etq_t="$(tem33 'title="Limpeza automática: mantém só os 4 arquivos mais recentes de cada pasta · apaga o arquivo com mais de 30 dias">limpeza</span>')"
t_e1="$(aba -b "$J" "$B/usuarios/editar?usuario=ret33")"; v_1="$(grep -c -E 'name="ultimos" [^>]*value="4"|name="dias" [^>]*value="30"' "$W/corpo" || true)"
lig_1="$(tem33 '<span class="etiqueta atencao">ligada</span> mantém só os 4 arquivos mais recentes de cada pasta · apaga o arquivo com mais de 30 dias.')"
# Quem tem a pasta alcançada pela regra é avisado na tela dele; quem está fora dela, não.
e_viz="$(COMO=viz33 entrar "$W/viz33.jar" "$W/viz33.senha")"; proibir "$(biscoito_de "$W/viz33.jar")"
e_fora="$(COMO=fora33 entrar "$W/fora33.jar" "$W/fora33.senha")"; proibir "$(biscoito_de "$W/fora33.jar")"
aviso33='Limpeza automática, ligada pelo administrador: o servidor mantém só os 4 arquivos mais recentes de cada pasta · apaga o arquivo com mais de 30 dias, sozinho.'
u_r="$(aba -b "$W/ret33.jar" "$B/meus-arquivos")"; av_r="$(tem33 "$aviso33")"
u_v="$(aba -b "$W/viz33.jar" "$B/meus-arquivos")"; av_v="$(tem33 "$aviso33")"
u_f="$(aba -b "$W/fora33.jar" "$B/meus-arquivos")"; av_f="$(tem33 'Limpeza automática')"
g_2="$(grava33 "$J" "$K" ret33 2 '' "$W/painel.senha")"; r_2="$(regra33 ret33)"
g_3="$(grava33 "$J" "$K" ret33 '' '' "$W/painel.senha")"; r_3="$(regra33 ret33)"
t_l3="$(aba -b "$J" "$B/usuarios?m=limpeza_desligada")"; m_3="$(tem33 'Limpeza automática desligada. Nenhum arquivo deste usuário é apagado sozinho.')"; etq_3="$(etiquetas33)"
u_r3="$(aba -b "$W/ret33.jar" "$B/meus-arquivos")"; av_r3="$(tem33 'Limpeza automática')"
auditoria; d_alt=$(( $(eventos retencao_alterada) - n_alt ))
l_a1="$(linhas33 " evento=retencao_alterada admin=$ADMIN usuario=ret33 ultimos=4 dias=30\$")"; l_a2="$(linhas33 " evento=retencao_alterada admin=$ADMIN usuario=ret33 ultimos=2 dias=-\$")"
l_a3="$(linhas33 " evento=retencao_alterada admin=$ADMIN usuario=ret33 ultimos=- dias=-\$")"
# Com a passada parada: passados os dois minutos em que ela começaria, os três arquivos de par33 continuam lá.
while (( SECONDS - inicio33 < 130 )); do sleep 2; done
p_arv="$(arv33 /data/par33)"; auditoria; d_apl=$(( $(eventos retencao_aplicada) - n_apl ))
passa33 --simular; p_sim="$(linha33 par33)"
mu retencao par33 "" ultimos=; r_par_fim=$?
[[ "$t_ed" == "200 " && "$f_cartao" == 1 && "$f_form" == 1 && "$f_ult" == 1 && "$f_dias" == 1 && "$f_desl" == 1 && "$f_lix" == 1 && "$f_viz" == 1 && "$f_parada" == 1 \
  && "$t_l0" == "200 " && "$etq_0" == 1 && "$g_1" == "303 /usuarios?m=limpeza" && "$r_1" == "ultimos=4 dias=30 " && "$t_l1" == "200 " && "$m_1" -ge 1 && "$etq_1" == 2 \
  && "$etq_t" == 1 && "$t_e1" == "200 " && "$v_1" == 2 && "$lig_1" == 1 && "$e_viz" == 303 && "$e_fora" == 303 && "$u_r" == "200 " && "$av_r" == 1 && "$u_v" == "200 " \
  && "$av_v" == 1 && "$u_f" == "200 " && "$av_f" == 0 && "$g_2" == "303 /usuarios?m=limpeza" && "$r_2" == "ultimos=2 dias= " && "$g_3" == "303 /usuarios?m=limpeza_desligada" \
  && "$r_3" == "ultimos= dias= " && "$t_l3" == "200 " && "$m_3" -ge 1 && "$etq_3" == 1 && "$u_r3" == "200 " && "$av_r3" == 0 && "$d_alt" == 3 && "$l_a1" -ge 1 && "$l_a2" -ge 1 \
  && "$l_a3" -ge 1 && "$p_arv" == "p1.cfg p2.cfg p3.cfg " && "$d_apl" == 0 && "$p_sim" == "par33 /data/par33 (ultimos=1): 2 arquivo(s), 4 bytes, 0 pasta(s) vazia(s), 0 erro(s)" \
  && "$r_par_fim" == 0 ]]
caso $? testes 70 "Administrador liga, muda e desliga a limpeza automática de um usuário pelo painel" "tela de editar ret33: $t_ed, com o cartão da limpeza ($f_cartao), o formulário ($f_form), os campos de arquivos mantidos ($f_ult) e de dias ($f_dias), 'Desligada: nenhum arquivo deste usuário é apagado sozinho.' ($f_desl), o aviso de que não há lixeira ($f_lix), o de que a pasta também é alcançada por viz33 ($f_viz) e o de passada parada ($f_parada); lista de usuários antes: $etq_0 etiqueta de limpeza (a de par33); 4 arquivos e 30 dias: $g_1, regra gravada: $r_1, mensagem na lista: $m_1, etiquetas: $etq_1, a de ret33 com a regra por extenso: $etq_t, tela de editar com os dois valores nos campos ($v_1 de 2) e a regra ligada ($lig_1); aviso da regra em /meus-arquivos de ret33: $av_r, de viz33 (pasta dentro da dele): $av_v, de fora33 (pasta fora): $av_f; só 2 arquivos: $g_2, regra: $r_2; os dois campos vazios: $g_3, regra: $r_3, mensagem de desligada: $m_3, etiquetas: $etq_3, aviso em /meus-arquivos de ret33: $av_r3; retencao_alterada a mais: $d_alt, com as linhas de 4 e 30 ($l_a1), de 2 ($l_a2) e de desligada ($l_a3); passada parada (PAINEL_RETENCAO_MINUTOS=$min_0), $((SECONDS - inicio33)) s depois da partida do painel: pasta de par33 (regra ultimos=1) com $p_arv, retencao_aplicada a mais: $d_apl; a simulação diz o que sairia: $p_sim"

# ------------------------------------------------------------------ manter os mais recentes, pelo terminal
planta33 <<'SH'
set -e; cd /data/ret33
for n in 01 02 03 04 05 06 07 08 09 10; do head -c 1000 /dev/zero > "f$n.cfg"; touch -d "$n days ago" "f$n.cfg"; done
echo x > .oculto; touch -d '40 days ago' .oculto
ln -s f10.cfg atalho
mkdir -p olt-a olt-b olt-c vazia .guardado
for n in 1 2 3 4 5; do head -c 500 /dev/zero > "olt-a/b$n.cfg"; touch -d "$n days ago" "olt-a/b$n.cfg"; done
for n in 1 2; do echo y > "olt-b/c$n.cfg"; touch -d "$n days ago" "olt-b/c$n.cfg"; done
echo z > olt-c/d1.cfg; touch -d '90 days ago' olt-c/d1.cfg
for n in 1 2 3 4 5; do echo g > ".guardado/g$n"; touch -d "$n days ago" ".guardado/g$n"; done
chown -hR ftpdata:ftpdata .
SH
r_planta=$?
guardados33='.guardado .guardado/g1 .guardado/g2 .guardado/g3 .guardado/g4 .guardado/g5 .oculto atalho'
mu retencao ret33 "" ultimos=3; r_g=$?; g_fala="$(grep -c 'Limpeza automatica do usuario ret33 gravada: vale na proxima passada do painel.' "$W/mu.log")"; g_regra="$(regra33 ret33)"
auditoria; n_apl="$(eventos retencao_aplicada)"
s_0="$(soma33 /data/ret33)"; passa33 --simular; r_sim=$?; sim_linha="$(linha33 ret33)"; sim_nota="$(grep -c -F 'Simulação: nada foi apagado.' "$W/passada")"; s_1="$(soma33 /data/ret33)"
passa33; r_real=$?; real_linha="$(linha33 ret33)"; real_arv="$(arv33 /data/ret33)"
passa33; de_novo="$(linha33 ret33)"
auditoria; d_apl=$(( $(eventos retencao_aplicada) - n_apl ))
l_apl="$(linhas33 ' ip=- evento=retencao_aplicada usuario=ret33 pasta=ret33 arquivos=9 pastas=0 bytes=8000 erros=0 ultimos=3 dias=-$')"
# As duas regras juntas: sai o arquivo que passar de qualquer uma.
mu retencao ret33 "" ultimos=1 dias=3650; r_j=$?; j_regra="$(regra33 ret33)"
passa33; j_linha="$(linha33 ret33)"; j_arv="$(arv33 /data/ret33)"
# Valor vazio desliga aquela regra; sem nenhuma, a passada não tem o que fazer.
mu retencao ret33 "" dias=; k_1="$(regra33 ret33)"
mu retencao ret33 "" ultimos=; k_2="$(regra33 ret33)"
passa33; k_nada="$(grep -c -F 'Nenhum usuário com limpeza automática.' "$W/passada")"
# Trocar a pasta do usuário desliga a regra: ela era da pasta anterior.
mu retencao ret33 "" ultimos=2
mu pasta ret33 "" ret33b; r_troca=$?; troca_fala="$(grep -c 'Limpeza automatica do usuario ret33 desligada: a regra era da pasta anterior.' "$W/mu.log")"; troca_regra="$(regra33 ret33)"
mu pasta ret33 "" ret33; r_volta=$?; volta_regra="$(regra33 ret33)"; volta_arv="$(arv33 /data/ret33)"
[[ "$r_planta" == 0 && "$r_g" == 0 && "$g_fala" == 1 && "$g_regra" == "ultimos=3 dias= " && "$r_sim" == 0 && "$sim_nota" == 1 && -n "$s_0" && "$s_0" == "$s_1" \
  && "$sim_linha" == "ret33 /data/ret33 (ultimos=3): 9 arquivo(s), 8000 bytes, 0 pasta(s) vazia(s), 0 erro(s)" && "$r_real" == 0 && "$real_linha" == "$sim_linha" \
  && "$real_arv" == "$guardados33 f01.cfg f02.cfg f03.cfg olt-a olt-a/b1.cfg olt-a/b2.cfg olt-a/b3.cfg olt-b olt-b/c1.cfg olt-b/c2.cfg olt-c olt-c/d1.cfg olt-v vazia " \
  && "$de_novo" == "ret33 /data/ret33 (ultimos=3): 0 arquivo(s), 0 bytes, 0 pasta(s) vazia(s), 0 erro(s)" && "$d_apl" == 1 && "$l_apl" -ge 1 && "$r_j" == 0 \
  && "$j_regra" == "ultimos=1 dias=3650 " && "$j_linha" == "ret33 /data/ret33 (ultimos=1 dias=3650): 5 arquivo(s), 3002 bytes, 0 pasta(s) vazia(s), 0 erro(s)" \
  && "$j_arv" == "$guardados33 f01.cfg olt-a olt-a/b1.cfg olt-b olt-b/c1.cfg olt-c olt-c/d1.cfg olt-v vazia " && "$k_1" == "ultimos=1 dias= " && "$k_2" == "ultimos= dias= " \
  && "$k_nada" == 1 && "$r_troca" == 0 && "$troca_fala" == 1 && "$troca_regra" == "ultimos= dias= " && "$r_volta" == 0 && "$volta_regra" == "ultimos= dias= " && "$volta_arv" == "$j_arv" ]]
caso $? testes 71 "Limpeza automática mantém os arquivos mais recentes de cada pasta" "pasta de ret33 com 10 arquivos de 1000 bytes, olt-a com 5 de 500, olt-b com 2, olt-c com 1 de 90 dias, uma pasta vazia, um arquivo e uma pasta com o nome começado por ponto e um link simbólico; ./manage-user.sh retencao ret33 ultimos=3: saída $r_g, regra $g_regra; simulação: $sim_linha, com o aviso de que nada foi apagado ($sim_nota) e a soma da pasta igual ($s_0 e $s_1); passada: $real_linha; ficou: $real_arv; segunda passada: $de_novo; retencao_aplicada a mais: $d_apl, com a linha da passada ($l_apl); ultimos=1 dias=3650 ($j_regra): $j_linha; ficou: $j_arv; dias vazio: $k_1; ultimos vazio: $k_2; passada sem nenhuma regra diz 'Nenhum usuário com limpeza automática.': $k_nada; com ultimos=2, trocar a pasta de ret33: saída $r_troca, aviso de que a regra foi desligada: $troca_fala, regra: $troca_regra; de volta à pasta de antes: regra $volta_regra, arquivos como estavam"

# ------------------------------------------------------------------ apagar o que passou do prazo
planta33 <<'SH'
set -e; cd /data/ret33
find . -mindepth 1 -maxdepth 1 ! -name olt-v -exec rm -rf {} +
mkdir -p velha/dentro mista ja-vazia
for f in velho1.cfg velho2.cfg velha/dentro/v.cfg mista/v.cfg .oculto-velho; do echo a > "$f"; done
ln -s velho1.cfg atalho-velho
chown -hR ftpdata:ftpdata .
SH
r_velhos=$?
sleep 2; corte33="$(date +%s)"; sleep 2
planta33 <<'SH'
set -e; cd /data/ret33
for f in novo1.cfg mista/n.cfg antigo-que-chegou-agora.cfg; do echo b > "$f"; chown ftpdata:ftpdata "$f"; done
touch -d '300 days ago' antigo-que-chegou-agora.cfg
SH
r_novos=$?
# Pela regra gravada, nada sai: todos chegaram agora, mesmo o que tem data de 300 dias.
mu retencao ret33 "" dias=1; r_d=$?; d_regra="$(regra33 ret33)"
passa33; d_linha="$(linha33 ret33)"; d_arv="$(arv33 /data/ret33)"
m_corte="$(motor33 ret33 "$corte33" | tr '\n' ' ')"; m_arv="$(arv33 /data/ret33)"
# Com o corte depois de tudo, sai o que sobrou: a pasta do usuário continua lá, vazia do que a limpeza alcança.
m_tudo="$(motor33 ret33 "$(( $(date +%s) + 60 ))" | tail -1)"; m_fim="$(arv33 /data/ret33)"; m_pasta="$(docker exec "$FTP" stat -c '%F %U:%G' /data/ret33 2>&1)"
mu retencao ret33 "" dias=
[[ "$r_velhos" == 0 && "$r_novos" == 0 && "$r_d" == 0 && "$d_regra" == "ultimos= dias=1 " && "$d_linha" == "ret33 /data/ret33 (dias=1): 0 arquivo(s), 0 bytes, 0 pasta(s) vazia(s), 0 erro(s)" \
  && "$d_arv" == ".oculto-velho antigo-que-chegou-agora.cfg atalho-velho ja-vazia mista mista/n.cfg mista/v.cfg novo1.cfg olt-v velha velha/dentro velha/dentro/v.cfg velho1.cfg velho2.cfg " \
  && "$m_corte" == "simular arquivos=4 pastas=0 bytes=8 erros=0 real arquivos=4 pastas=2 bytes=8 erros=0 " \
  && "$m_arv" == ".oculto-velho antigo-que-chegou-agora.cfg atalho-velho ja-vazia mista mista/n.cfg novo1.cfg olt-v " \
  && "$m_tudo" == "real arquivos=3 pastas=1 bytes=6 erros=0" && "$m_fim" == ".oculto-velho atalho-velho ja-vazia olt-v " && "$m_pasta" == "directory ftpdata:ftpdata" ]]
caso $? testes 72 "Limpeza automática apaga o arquivo que passou do prazo, pela data em que chegou" "pasta de ret33 com um grupo de arquivos (dois na raiz, um em velha/dentro, um em mista, um com o nome começado por ponto, um link simbólico e uma pasta já vazia) e, 4 s depois, outro grupo (um na raiz, um em mista e um com a data de modificação recuada 300 dias); regra dias=1 ($d_regra), pela passada: $d_linha; ficou: $d_arv; motor da limpeza com o corte entre os dois grupos, simulado e de verdade: $m_corte; ficou: $m_arv; com o corte depois de tudo: $m_tudo; ficou: $m_fim; a pasta do usuário: $m_pasta"

# ------------------------------------------------------------------ a limpeza não sai da pasta nem segue link
planta33 <<'SH'
set -e
cd /data/fora33; for n in 1 2 3; do echo x > "x$n.cfg"; touch -d "$n days ago" "x$n.cfg"; done; chown -hR ftpdata:ftpdata .
cd /data/ret33
find . -mindepth 1 -maxdepth 1 ! -name olt-v -exec rm -rf {} +
for n in 1 2 3 4; do echo a > "a$n.cfg"; touch -d "$n days ago" "a$n.cfg"; echo v > "olt-v/v$n.cfg"; touch -d "$n days ago" "olt-v/v$n.cfg"; done
ln -s /data/fora33/x1.cfg para-arquivo; ln -s /data/fora33 para-pasta; ln -s /auth para-auth
mkdir .entrada; for n in 1 2 3; do echo e > ".entrada/e$n"; echo o > ".oculto$n"; done
mkfifo cano
chown -hR ftpdata:ftpdata .
SH
r_cerca=$?
mu retencao ret33 "" ultimos=1; mu retencao par33 "" ultimos=1
auditoria; n_apl="$(eventos retencao_aplicada)"
s_fora0="$(soma33 /data/fora33)"; s_auth0="$(auth33)"; s_par0="$(soma33 /data/par33)"
passa33 --simular; i_sim="$(linha33 ret33)"
# A pasta de par33 dá lugar a um link simbólico para a de outro usuário: a passada não a abre.
docker exec "$FTP" sh -c 'mv /data/par33 /data/par33.guardada && ln -s /data/fora33 /data/par33'; r_link=$?
passa33; i_linha="$(linha33 ret33)"; i_arv="$(arv33 /data/ret33)"; i_par="$(linha33 par33)"
docker exec "$FTP" sh -c 'rm /data/par33 && mv /data/par33.guardada /data/par33'; r_desfaz=$?
s_fora1="$(soma33 /data/fora33)"; s_auth1="$(auth33)"; s_par1="$(soma33 /data/par33)"
auditoria; d_apl=$(( $(eventos retencao_aplicada) - n_apl )); l_par="$(grep -c ' evento=retencao_aplicada usuario=par33 ' "$W/auditoria" || true)"
mu retencao ret33 "" ultimos=
[[ "$r_cerca" == 0 && "$i_sim" == "ret33 /data/ret33 (ultimos=1): 6 arquivo(s), 12 bytes, 0 pasta(s) vazia(s), 0 erro(s)" && "$r_link" == 0 && "$i_linha" == "$i_sim" \
  && "$i_arv" == ".entrada .entrada/e1 .entrada/e2 .entrada/e3 .oculto1 .oculto2 .oculto3 a1.cfg cano olt-v olt-v/v1.cfg para-arquivo para-auth para-pasta " \
  && "$i_par" == "par33 /data/par33 (ultimos=1): a pasta não pôde ser aberta" && "$r_desfaz" == 0 && -n "$s_fora0" && "$s_fora0" == "$s_fora1" && -n "$s_auth0" && "$s_auth0" == "$s_auth1" \
  && -n "$s_par0" && "$s_par0" == "$s_par1" && "$d_apl" == 1 && "$l_par" == 0 ]]
caso $? seguranca 124 "Limpeza automática não sai da pasta do usuário nem segue link simbólico" "pasta de ret33 com 4 arquivos, links simbólicos para um arquivo e para a pasta de outro usuário (fora33, com 3 arquivos) e para /auth, uma pasta e três arquivos com o nome começado por ponto, um arquivo especial (FIFO) e a pasta de viz33 (olt-v, com 4 arquivos); regra ultimos=1, simulada: $i_sim; de verdade: $i_linha; ficou: $i_arv (a pasta de viz33 fica dentro da de ret33: a regra a alcança, como a tela avisa); soma da pasta de fora33 antes $s_fora0, depois $s_fora1; soma de /auth antes $s_auth0, depois $s_auth1; pasta de par33 (regra ultimos=1, 3 arquivos) trocada por um link para a de fora33: $i_par; soma dos arquivos de par33 antes $s_par0, depois $s_par1; retencao_aplicada a mais: $d_apl, de par33: $l_par"

# ------------------------------------------------------------------ a passada roda sozinha
gravar_env "$ENVA" PAINEL_RETENCAO_MINUTOS 1; dep; r_dep1=$?
painel_de_pe; inicio33=$SECONDS
min_1="$(docker exec "$PAINEL" printenv PAINEL_RETENCAO_MINUTOS)"
e_adm3="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"
t_min="$(aba -b "$J" "$B/usuarios/editar?usuario=par33")"; f_min="$(tem33 'O painel aplica a regra a cada minuto.')"; f_anda="$(tem33 'a limpeza automática está parada nesta')"
auditoria; n_apl="$(eventos retencao_aplicada)"; a_0="$(arv33 /data/par33)"
# A primeira passada vem dois minutos depois da partida do painel.
while (( SECONDS - inicio33 < 180 )) && [[ "$(arv33 /data/par33)" != "p1.cfg " ]]; do sleep 3; done
a_1="$(arv33 /data/par33)"; t_1=$((SECONDS - inicio33))
planta33 <<'SH'
set -e; cd /data/par33
for n in 4 5; do echo q > "q$n.cfg"; touch -d "$n hours ago" "q$n.cfg"; done
chown ftpdata:ftpdata q4.cfg q5.cfg
SH
# As seguintes, a cada minuto.
marca33=$SECONDS
while (( SECONDS - marca33 < 90 )) && [[ "$(arv33 /data/par33)" != "q4.cfg " ]]; do sleep 3; done
a_2="$(arv33 /data/par33)"; t_2=$((SECONDS - marca33))
auditoria; d_apl=$(( $(eventos retencao_aplicada) - n_apl )); d_falhou="$(eventos retencao_falhou)"
l_soz="$(linhas33 ' ip=- evento=retencao_aplicada usuario=par33 pasta=par33 arquivos=[12] pastas=0 bytes=[24] erros=0 ultimos=1 dias=-$')"
gravar_env "$ENVA" PAINEL_RETENCAO_MINUTOS "$ret_0"; dep; r_dep2=$?
painel_de_pe; min_2="$(docker exec "$PAINEL" printenv PAINEL_RETENCAO_MINUTOS)"; saude_33="$(saude "$FTP" "$PAINEL" "$NGINX")"
[[ "$r_dep1" == 0 && "$min_1" == 1 && "$e_adm3" == 303 && "$t_min" == "200 " && "$f_min" == 1 && "$f_anda" == 0 && "$a_0" == "p1.cfg p2.cfg p3.cfg " && "$a_1" == "p1.cfg " \
  && "$t_1" -ge 60 && "$a_2" == "q4.cfg " && "$d_apl" -ge 2 && "$l_soz" -ge 2 && "$d_falhou" == 0 && "$r_dep2" == 0 && "$min_2" == "$ret_0" ]]
caso $? testes 73 "Limpeza automática roda sozinha, no intervalo de PAINEL_RETENCAO_MINUTOS" "deploy.sh com PAINEL_RETENCAO_MINUTOS=1: saída $r_dep1, no container: $min_1; tela de editar par33: $t_min, com 'O painel aplica a regra a cada minuto.' ($f_min) e sem o aviso de passada parada ($f_anda); pasta de par33 (regra ultimos=1) logo depois da partida: $a_0; depois da primeira passada, $t_1 s depois da partida: $a_1; mais dois arquivos novos e, $t_2 s depois: $a_2; retencao_aplicada a mais: $d_apl, com ip=- e a conta de par33: $l_soz; retencao_falhou: $d_falhou; de volta a PAINEL_RETENCAO_MINUTOS=$ret_0: saída $r_dep2, no container: $min_2, saúde $saude_33"

for n in ret33 par33 viz33 fora33; do mu del "$n"; done
docker exec "$FTP" rm -rf /data/ret33 /data/ret33b /data/par33 /data/fora33
rm -f "$W"/ret33.* "$W"/par33.* "$W"/viz33.* "$W"/fora33.* "$W/vazio33.jar" "$W/passada"
