#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa V: apagar e renomear pelo painel. Arquivo e pasta renomeados e apagados na aba Arquivos, usuário
# removido junto com a pasta dele, caminho que tenta sair da pasta dos dados, pasta de usuário protegida,
# pedido sem sessão, sem token e sem a senha atual, e pasta grande apagada em mais de um pedido.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel zera a contagem de falhas de entrada e das recusas e encerra as sessões. A etapa usa
# três conferências de senha atual recusadas de propósito, abaixo das cinco que bloqueiam o endereço.
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"

U22="$W/u22.jar"; Q="$B/arquivos"
existe22() { docker exec "$FTP" sh -c "test -e '/data/$1' || test -L '/data/$1'" && echo sim || echo não; }   # <caminho>: existe nos dados (link conta)
soma22() { docker exec "$FTP" sh -c "sha256sum < '/data/$1'" 2>/dev/null | cut -c1-64; }                     # <caminho>: soma do conteúdo
dono22() { docker exec "$FTP" stat -c '%U:%G %a %F' "/data/$1" 2>/dev/null || echo ausente; }                # <caminho>: dono, modo e tipo
arvore22() { docker exec "$FTP" sh -c 'find /data /auth -xdev | sort | sha256sum | cut -c1-16'; }            # tudo o que existe nos dados e no cadastro
# Nomes do que há em /auth e o conteúdo do cadastro do FTP: muda se algo de lá for apagado ou regravado. O hash não sai do container.
auth22() { docker exec "$FTP" sh -c '{ find /auth -xdev | sort; cat /auth/pureftpd.passwd; } | sha256sum | cut -c1-16'; }
cria22() { envio /usuarios/novo --data-urlencode "csrf=$K" --data-urlencode "usuario=$1" --data-urlencode "pasta=$2" --data-urlencode "senha@$3" --data-urlencode "confirmacao@$3"; }  # <usuário> <pasta> <arquivo da senha>
renomeia22() { envio /arquivos/renomear --data-urlencode "csrf=$K" --data-urlencode "item=$1" --data-urlencode "nome=$2"; }  # <item> <nome novo> → "código destino"
apaga22() { # <item> [arquivo da senha atual] [valor da caixa de confirmação] → "código destino"
  envio /arquivos/apagar --data-urlencode "csrf=$K" --data-urlencode "item=$1" --data-urlencode "confirmar=${3-sim}" --data-urlencode "senha_atual@${2:-$W/painel.senha}"
}
remove22() { # <usuário> [sim: apagar a pasta junto] [arquivo da senha atual] → "código destino"
  local -a campos=(--data-urlencode "csrf=$K" --data-urlencode "usuario=$1" --data-urlencode 'confirmar=sim')
  [[ -n "${2:-}" ]] && campos+=(--data-urlencode "apagar_pasta=$2")
  [[ -n "${3:-}" ]] && campos+=(--data-urlencode "senha_atual@$3")
  envio /usuarios/remover "${campos[@]}"
}
login22() { local r; r="$(ftp_curl tls "$1" "$2" -l "$F/")"; echo "$r $(resposta '(226|530) ' | cut -c1-3)"; }  # <usuário> <arquivo da senha> → "0 226" ou "67 530"
no_cadastro22() { usuarios_ftp | tr ' ' '\n' | grep -c -x -F "$1"; }

nova_senha "$W/u22.senha"; nova_senha "$W/r22.senha"; nova_senha "$W/errada22.senha"
printf 'config-do-equipamento-%s\n' "$(openssl rand -hex 8)" > "$W/a22.cfg"; soma_a="$(sha256sum < "$W/a22.cfg" | cut -c1-64)"
head -c 65536 /dev/urandom > "$W/b22.bin"

# ------------------------------------------------------------------ renomear e apagar na aba Arquivos
r_novo="$(cria22 arq22 arq22 "$W/u22.senha")"
r_f1="$(ftp_curl tls arq22 "$W/u22.senha" -T "$W/a22.cfg" "$F/antigo.cfg")"
r_f2="$(ftp_curl tls arq22 "$W/u22.senha" --ftp-create-dirs -T "$W/a22.cfg" "$F/diario/relat%C3%B3rio%20final.cfg")"
r_f3="$(ftp_curl tls arq22 "$W/u22.senha" -T "$W/b22.bin" "$F/outro.cfg")"
d_antes="$(dono22 arq22/antigo.cfg)"; soma_outro="$(soma22 arq22/outro.cfg)"
auditoria; n_ren="$(eventos item_renomeado)"; n_apa="$(eventos item_apagado)"
lista="$(aba -b "$J" "$Q?pasta=arq22")"; b_ren="$(grep -c 'href="/arquivos/renomear?item=arq22/antigo.cfg"' "$W/corpo")"
b_apa="$(grep -c 'href="/arquivos/apagar?item=arq22/antigo.cfg"' "$W/corpo")"; b_pasta="$(grep -c 'href="/arquivos/apagar?item=arq22/diario"' "$W/corpo")"
tela="$(aba -b "$J" "$B/arquivos/renomear?item=arq22/antigo.cfg")"; f_ren="$(grep -c 'action="/arquivos/renomear"' "$W/corpo")"
r_ren="$(renomeia22 arq22/antigo.cfg novo.cfg)"
e_antigo="$(existe22 arq22/antigo.cfg)"; s_novo="$(soma22 arq22/novo.cfg)"; d_novo="$(dono22 arq22/novo.cfg)"
r_l="$(ftp_curl tls arq22 "$W/u22.senha" -l "$F/")"; no_ftp="$(grep -c '^novo.cfg' "$W/curl.out")"; no_ftp_antigo="$(grep -c '^antigo.cfg' "$W/curl.out")"
r_sobre="$(renomeia22 arq22/novo.cfg outro.cfg)"; r_mesmo="$(renomeia22 arq22/novo.cfg novo.cfg)"
s_novo_2="$(soma22 arq22/novo.cfg)"; s_outro_2="$(soma22 arq22/outro.cfg)"
# Nome com acento e espaço: o caminho volta pelo campo escondido da tela, codificado.
tela_ac="$(aba -b "$J" "$B/arquivos/renomear?item=arq22/diario/relat%C3%B3rio%20final.cfg")"
item_ac="$(sed -n 's/.*name="item" value="\([^"]*\)".*/\1/p' "$W/corpo" | head -1)"
r_ac="$(renomeia22 "$item_ac" relatorio-final.cfg)"
r_pasta="$(renomeia22 arq22/diario mensal)"; s_ac="$(soma22 arq22/mensal/relatorio-final.cfg)"; e_diario="$(existe22 arq22/diario)"
tela_apa="$(aba -b "$J" "$B/arquivos/apagar?item=arq22/outro.cfg")"; f_apa="$(grep -c 'action="/arquivos/apagar"' "$W/corpo")"
caixa="$(grep -c 'type="checkbox" name="confirmar" value="sim" required' "$W/corpo")"; pede="$(grep -c 'name="senha_atual" type="password" required' "$W/corpo")"
r_sem_caixa="$(apaga22 arq22/outro.cfg "" nao)"; r_errada="$(apaga22 arq22/outro.cfg "$W/errada22.senha")"; ainda="$(existe22 arq22/outro.cfg)"
r_apa="$(apaga22 arq22/outro.cfg)"; foi="$(existe22 arq22/outro.cfg)"
# Pasta com mais de um lote de arquivos, pastas uma dentro da outra e dois links simbólicos para o cadastro do FTP.
docker exec "$FTP" sh -c 'cd /data/arq22/mensal && mkdir -p a/b/c && seq 1 1150 | sed "s/^/f-/" | xargs touch && touch a/b/c/fundo.cfg && ln -s /auth a/atalho && ln -s /auth/pureftpd.passwd a/b/cadastro'; r_prep=$?
auth_antes="$(auth22)"
tela_p="$(aba -b "$J" "$B/arquivos/apagar?item=arq22/mensal")"; conta="$(grep -c '1152 arquivo(s)' "$W/corpo")"
r_apa_p="$(apaga22 arq22/mensal)"; foi_p="$(existe22 arq22/mensal)"; auth_depois="$(auth22)"
aviso="$(aba -b "$J" "$Q?pasta=arq22&m=apagado")"; n_aviso="$(grep -c 'Apagado\.' "$W/corpo")"
# Nome com um byte fora do UTF-8: o caminho vai codificado no campo, como a tela o entrega.
docker exec "$FTP" sh -c 'printf x > "/data/arq22/ruim-$(printf "\377").cfg"'; r_ruim=$?
t_ruim="$(aba -b "$J" "$B/arquivos/apagar?item=arq22/ruim-%FF.cfg")"; item_ruim="$(sed -n 's/.*name="item" value="\([^"]*\)".*/\1/p' "$W/corpo" | head -1)"
r_apa_ruim="$(apaga22 "$item_ruim")"; sobra_ruim="$(docker exec "$FTP" sh -c 'ls /data/arq22 | grep -c "^ruim-"')"
r_l2="$(ftp_curl tls arq22 "$W/u22.senha" -l "$F/")"; resta="$(tr -d '\r' < "$W/curl.out" | grep -v -x -e '\.' -e '\.\.' | sort | tr '\n' ' ')"
auditoria; n_ren_2="$(eventos item_renomeado)"; n_apa_2="$(eventos item_apagado)"
reg_ren="$(grep -c " evento=item_renomeado admin=$ADMIN tipo=arquivo de=arq22/antigo.cfg para=arq22/novo.cfg\$" "$W/auditoria")"
reg_ren_p="$(grep -c " evento=item_renomeado admin=$ADMIN tipo=pasta de=arq22/diario para=arq22/mensal\$" "$W/auditoria")"
reg_apa="$(grep -c " evento=item_apagado admin=$ADMIN tipo=arquivo caminho=arq22/outro.cfg itens=1\$" "$W/auditoria")"
reg_apa_p="$(grep -c " evento=item_apagado admin=$ADMIN tipo=pasta caminho=arq22/mensal itens=1158\$" "$W/auditoria")"
atividade="$(aba -b "$J" "$B/atividade")"; na_atividade="$(grep -c -E 'Arquivo ou pasta renomeado|Arquivo ou pasta apagado' "$W/corpo")"
[[ "$e_adm" == 303 && "$r_novo" == "303 /usuarios?m=criado" && "$r_f1" == 0 && "$r_f2" == 0 && "$r_f3" == 0 \
  && "$lista" == "200 " && "$b_ren" == 1 && "$b_apa" == 1 && "$b_pasta" == 1 && "$tela" == "200 " && "$f_ren" == 1 \
  && "$r_ren" == "303 /arquivos?pasta=arq22&m=renomeado" && "$e_antigo" == não && "$s_novo" == "$soma_a" && "$d_novo" == "$d_antes" && "$d_novo" != ausente \
  && "$r_l" == 0 && "$no_ftp" == 1 && "$no_ftp_antigo" == 0 && "$r_sobre" == "409 " && "$r_mesmo" == "409 " && "$s_novo_2" == "$soma_a" && "$s_outro_2" == "$soma_outro" \
  && "$tela_ac" == "200 " && "$item_ac" == 'arq22/diario/relat%C3%B3rio%20final.cfg' && "$r_ac" == "303 /arquivos?pasta=arq22/diario&m=renomeado" \
  && "$r_pasta" == "303 /arquivos?pasta=arq22&m=renomeado" && "$s_ac" == "$soma_a" && "$e_diario" == não \
  && "$tela_apa" == "200 " && "$f_apa" == 1 && "$caixa" == 1 && "$pede" == 1 && "$r_sem_caixa" == "400 " && "$r_errada" == "403 " && "$ainda" == sim \
  && "$r_apa" == "303 /arquivos?pasta=arq22&m=apagado" && "$foi" == não && "$r_prep" == 0 && "$tela_p" == "200 " && "$conta" == 1 \
  && "$r_apa_p" == "303 /arquivos?pasta=arq22&m=apagado" && "$foi_p" == não && "$auth_antes" == "$auth_depois" && "$aviso" == "200 " && "$n_aviso" -ge 1 \
  && "$r_ruim" == 0 && "$t_ruim" == "200 " && "$item_ruim" == 'arq22/ruim-%FF.cfg' && "$r_apa_ruim" == "303 /arquivos?pasta=arq22&m=apagado" && "$sobra_ruim" == 0 \
  && "$r_l2" == 0 && "$resta" == "novo.cfg " && "$n_ren_2" == $((n_ren + 3)) && "$n_apa_2" == $((n_apa + 3)) \
  && "$reg_ren" == 1 && "$reg_ren_p" == 1 && "$reg_apa" == 1 && "$reg_apa_p" == 1 && "$atividade" == "200 " && "$na_atividade" -ge 1 ]]
caso $? testes 43 "Arquivo e pasta renomeados e apagados pelo painel" "usuário arq22 criado pelo painel ($r_novo), três arquivos enviados por FTPS (saídas $r_f1, $r_f2 e $r_f3) · na lista da pasta, botão Renomear do arquivo: $b_ren, Apagar do arquivo: $b_apa, Apagar da pasta: $b_pasta · tela Renomear: $tela, formulário: $f_ren · POST /arquivos/renomear antigo.cfg para novo.cfg: $r_ren · o nome antigo existe: $e_antigo · conteúdo $([[ "$s_novo" == "$soma_a" ]] && echo igual || echo DIFERENTE), dono e modo $([[ "$d_novo" == "$d_antes" ]] && echo iguais || echo DIFERENTES) ($d_novo) · o usuário vê pelo FTP (saída $r_l) o nome novo: $no_ftp, o antigo: $no_ftp_antigo · renomear para um nome que já existe: $r_sobre· para o mesmo nome: $r_mesmo· os dois arquivos $([[ "$s_novo_2" == "$soma_a" && "$s_outro_2" == "$soma_outro" ]] && echo intactos || echo ALTERADOS) · arquivo 'relatório final.cfg', tela: $tela_ac, caminho no campo escondido: $item_ac, renomeado: $r_ac · pasta diario renomeada para mensal: $r_pasta, o arquivo de dentro $([[ "$s_ac" == "$soma_a" ]] && echo 'continua igual' || echo MUDOU) · tela Apagar: $tela_apa, formulário: $f_apa, caixa de confirmação obrigatória: $caixa, senha atual obrigatória: $pede · apagar sem marcar a caixa: $r_sem_caixa· com a senha atual errada: $r_errada· o arquivo continua: $ainda · com a caixa e a senha: $r_apa · existe depois: $foi · pasta mensal com 1152 arquivos, 3 pastas uma dentro da outra e 2 links para o cadastro do FTP (preparo $r_prep), tela: $tela_p, quantidade na tela: $conta · apagar a pasta: $r_apa_p · existe depois: $foi_p · cadastro do FTP e o que há em /auth $([[ "$auth_antes" == "$auth_depois" ]] && echo intactos || echo ALTERADOS) · aviso na lista: $n_aviso · arquivo com um byte fora do UTF-8 no nome (preparo $r_ruim), tela: $t_ruim, caminho no campo escondido: $item_ruim, apagado: $r_apa_ruim · arquivos com esse nome depois: $sobra_ruim · o usuário vê pelo FTP (saída $r_l2): $resta· auditoria item_renomeado: $n_ren → $n_ren_2, item_apagado: $n_apa → $n_apa_2 · linhas com o administrador, o tipo e os caminhos, renomear arquivo: $reg_ren, renomear pasta: $reg_ren_p, apagar arquivo: $reg_apa, apagar pasta com 1158 itens: $reg_apa_p · aba Atividade: $na_atividade"

# ------------------------------------------------------------------ usuário removido junto com a pasta
r_a="$(cria22 rem22a rem22a "$W/r22.senha")"; r_b="$(cria22 rem22b div22 "$W/r22.senha")"; r_c="$(cria22 rem22c div22 "$W/r22.senha")"; r_d="$(cria22 rem22d div22/dentro "$W/r22.senha")"
r_f1="$(ftp_curl tls rem22a "$W/r22.senha" -T "$W/a22.cfg" "$F/backup.cfg")"
r_f2="$(ftp_curl tls rem22a "$W/r22.senha" --ftp-create-dirs -T "$W/a22.cfg" "$F/semana/b.cfg")"
r_f3="$(ftp_curl tls rem22b "$W/r22.senha" -T "$W/a22.cfg" "$F/dividido.cfg")"
r_f4="$(ftp_curl tls rem22d "$W/r22.senha" -T "$W/a22.cfg" "$F/de-dentro.cfg")"
e_usu="$(COMO=rem22a entrar "$U22" "$W/r22.senha")"; proibir "$(biscoito_de "$U22")"; s_antes="$(aba -b "$U22" "$B/meus-arquivos")"
auditoria; n_rem="$(eventos usuario_removido)"; n_apa="$(eventos item_apagado)"
t_a="$(aba -b "$J" "$B/usuarios/remover?usuario=rem22a")"; caixa_a="$(grep -c 'type="checkbox" name="apagar_pasta" value="sim"' "$W/corpo")"; conta_a="$(grep -c 'tem 2 arquivo(s)' "$W/corpo")"
t_b="$(aba -b "$J" "$B/usuarios/remover?usuario=rem22b")"; caixa_b="$(grep -c 'name="apagar_pasta"' "$W/corpo")"; motivo_b="$(grep -c 'não é apagada junto' "$W/corpo")"
r_sem_senha="$(remove22 rem22a sim)"; fica_a="$(no_cadastro22 rem22a)"; pasta_a="$(existe22 rem22a/backup.cfg)"
r_mesma="$(remove22 rem22b sim "$W/painel.senha")"; r_fora="$(remove22 rem22d sim "$W/painel.senha")"
fica_b="$(no_cadastro22 rem22b)"; fica_d="$(no_cadastro22 rem22d)"; pasta_b="$(existe22 div22/dividido.cfg)"; pasta_d="$(existe22 div22/dentro/de-dentro.cfg)"
r_rem_a="$(remove22 rem22a sim "$W/painel.senha")"; saiu_a="$(no_cadastro22 rem22a)"; sumiu_a="$(existe22 rem22a)"
l_a="$(login22 rem22a "$W/r22.senha")"; s_depois="$(aba -b "$U22" "$B/meus-arquivos")"
aviso="$(aba -b "$J" "$B/usuarios?m=removido_com_pasta")"; n_aviso="$(grep -c 'Usuário removido e pasta apagada' "$W/corpo")"
r_rem_c="$(remove22 rem22c)"; saiu_c="$(no_cadastro22 rem22c)"; pasta_c="$(existe22 div22/dividido.cfg)"
r_dentro="$(remove22 rem22b sim "$W/painel.senha")"; fica_b_2="$(no_cadastro22 rem22b)"
r_rem_d="$(remove22 rem22d)"; pasta_d_2="$(existe22 div22/dentro/de-dentro.cfg)"
r_rem_b="$(remove22 rem22b sim "$W/painel.senha")"; saiu_b="$(no_cadastro22 rem22b)"; sumiu_b="$(existe22 div22)"
auditoria; n_rem_2="$(eventos usuario_removido)"; n_apa_2="$(eventos item_apagado)"
reg_rem="$(grep -c " evento=usuario_removido admin=$ADMIN usuario=rem22a pasta=rem22a\$" "$W/auditoria")"
reg_sem="$(grep -c " evento=usuario_removido admin=$ADMIN usuario=rem22c\$" "$W/auditoria")"
reg_apa="$(grep -c " evento=item_apagado admin=$ADMIN tipo=pasta caminho=rem22a itens=4 usuario=rem22a\$" "$W/auditoria")"
reg_apa_b="$(grep -c " evento=item_apagado admin=$ADMIN tipo=pasta caminho=div22 itens=4 usuario=rem22b\$" "$W/auditoria")"
l_outro="$(login22 arq22 "$W/u22.senha")"
[[ "$r_a" == "303 /usuarios?m=criado" && "$r_b" == "303 /usuarios?m=criado" && "$r_c" == "303 /usuarios?m=criado" && "$r_d" == "303 /usuarios?m=criado" \
  && "$r_f1" == 0 && "$r_f2" == 0 && "$r_f3" == 0 && "$r_f4" == 0 && "$e_usu" == 303 && "$s_antes" == "200 " \
  && "$t_a" == "200 " && "$caixa_a" == 1 && "$conta_a" == 1 && "$t_b" == "200 " && "$caixa_b" == 0 && "$motivo_b" == 1 \
  && "$r_sem_senha" == "403 " && "$fica_a" == 1 && "$pasta_a" == sim && "$r_mesma" == "409 " && "$r_fora" == "409 " \
  && "$fica_b" == 1 && "$fica_d" == 1 && "$pasta_b" == sim && "$pasta_d" == sim \
  && "$r_rem_a" == "303 /usuarios?m=removido_com_pasta" && "$saiu_a" == 0 && "$sumiu_a" == não && "$l_a" == "67 530" && "$s_depois" == "303 /entrar" \
  && "$aviso" == "200 " && "$n_aviso" -ge 1 && "$r_rem_c" == "303 /usuarios?m=removido" && "$saiu_c" == 0 && "$pasta_c" == sim \
  && "$r_dentro" == "409 " && "$fica_b_2" == 1 && "$r_rem_d" == "303 /usuarios?m=removido" && "$pasta_d_2" == sim \
  && "$r_rem_b" == "303 /usuarios?m=removido_com_pasta" && "$saiu_b" == 0 && "$sumiu_b" == não \
  && "$n_rem_2" == $((n_rem + 4)) && "$n_apa_2" == $((n_apa + 2)) && "$reg_rem" == 1 && "$reg_sem" == 1 && "$reg_apa" == 1 && "$reg_apa_b" == 1 && "$l_outro" == "0 226" ]]
caso $? testes 44 "Usuário removido junto com a pasta" "pelo painel, rem22a na pasta rem22a ($r_a), rem22b e rem22c na pasta div22 ($r_b e $r_c) e rem22d em div22/dentro ($r_d); arquivos enviados por FTPS (saídas $r_f1, $r_f2, $r_f3 e $r_f4) · tela Remover de rem22a: $t_a, caixa 'apagar também a pasta': $caixa_a, quantidade de arquivos na tela: $conta_a · tela de rem22b, que divide a pasta: $t_b, caixa: $caixa_b, aviso de que a pasta não é apagada junto: $motivo_b · remover rem22a com a caixa e sem a senha atual: $r_sem_senha· continua no cadastro: $fica_a, arquivo dele existe: $pasta_a · com a caixa, usuário de pasta dividida (rem22b): $r_mesma· usuário com a pasta dentro da de outro (rem22d): $r_fora· os dois continuam no cadastro: $fica_b e $fica_d, arquivos: $pasta_b e $pasta_d · rem22a com a caixa e a senha: $r_rem_a · no cadastro: $saiu_a, a pasta existe: $sumiu_a, login no FTP: $l_a · sessão dele no painel, antes: $s_antes, depois: $s_depois · aviso na lista: $n_aviso · rem22c sem a caixa: $r_rem_c · no cadastro: $saiu_c, o arquivo da pasta existe: $pasta_c · rem22b com a caixa enquanto rem22d tem a pasta dentro da dele: $r_dentro· continua no cadastro: $fica_b_2 · rem22d sem a caixa: $r_rem_d · o arquivo dele existe: $pasta_d_2 · rem22b, agora sozinho na pasta, com a caixa e a senha: $r_rem_b · no cadastro: $saiu_b, a pasta div22 existe: $sumiu_b · auditoria usuario_removido: $n_rem → $n_rem_2, item_apagado: $n_apa → $n_apa_2 · linha da remoção com a pasta: $reg_rem, sem a pasta: $reg_sem, da pasta apagada com 4 itens e o nome do usuário: $reg_apa e $reg_apa_b · outro usuário entra no FTP depois de tudo: $l_outro"

# ------------------------------------------------------------------ apagar e renomear que tentam sair, sem sessão e sem senha
docker exec "$FTP" sh -c 'ln -s /auth /data/arq22/atalho && ln -s /auth/pureftpd.passwd /data/arq22/cadastro.lnk && mkdir -p /data/solta22/sub && printf x > /data/solta22/sub/x.cfg && printf x > /data/solta22/y.cfg'; r_ln=$?
r_cli="$(cria22 cli22u cli22/olt "$W/r22.senha")"
antes="$(arvore22)"; auth_antes="$(auth22)"; auditoria
n_antes="$(eventos recusa_caminho)"; c_antes="$(eventos recusa_csrf)"; o_antes="$(eventos recusa_origem)"; s_antes="$(eventos admin_senha_atual_recusada)"; p_antes="$(eventos recusa_papel)"
ev=""; ok=0; longo="$(printf 'a%.0s' $(seq 1 65))"
for item in '..' '../auth' '/etc/passwd' 'arq22/../../auth' 'arq22//novo.cfg' './arq22/novo.cfg' 'arq22/.' ''; do
  r="$(apaga22 "$item")"; r2="$(renomeia22 "$item" x.cfg)"; [[ "$r" == "400 " && "$r2" == "400 " ]] || ok=1; ev+="'$item': $r/ $r2; "
done
r_nulo="$(envio /arquivos/renomear --data "csrf=$K&item=arq22/a%00b&nome=x.cfg")"; r_nulo_2="$(envio /arquivos/renomear --data "csrf=$K&item=arq22/a%2500b&nome=x.cfg")"
r_link="$(apaga22 arq22/atalho/pureftpd.passwd)"; r_link_ren="$(renomeia22 arq22/atalho/pureftpd.passwd x.cfg)"
t_link="$(aba -b "$J" "$B/arquivos/apagar?item=arq22/atalho/pureftpd.passwd")"; t_link_ren="$(aba -b "$J" "$B/arquivos/renomear?item=arq22/atalho/pureftpd.passwd")"
r_falta="$(apaga22 arq22/nao-existe.cfg)"; r_falta_ren="$(renomeia22 arq22/nao-existe.cfg x.cfg)"
ev_nome=""
for nome in '..' '.' '../novo.cfg' 'a/b' '/etc' '.oculta' '' 'com espaço' 'ação' "$longo"; do
  r="$(renomeia22 arq22/novo.cfg "$nome")"; [[ "$r" == "400 " ]] || ok=1; ev_nome+="'${nome:0:12}': $r; "
done
# Pasta de usuário do FTP, e pasta que tem a de um usuário dentro: só saem junto com o usuário.
r_casa="$(apaga22 arq22)"; r_casa_ren="$(renomeia22 arq22 outra22)"; r_cima="$(apaga22 cli22)"; r_cima_ren="$(renomeia22 cli22 outra22)"
t_casa="$(aba -b "$J" "$B/arquivos/apagar?item=arq22")"; t_cima="$(aba -b "$J" "$B/arquivos/renomear?item=cli22")"
campos=(--data-urlencode 'item=solta22/y.cfg' --data-urlencode 'confirmar=sim' --data-urlencode "senha_atual@$W/painel.senha" --data-urlencode 'nome=z.cfg')
ev_sessao=""
for rota in /arquivos/apagar /arquivos/renomear; do
  r_sem="$(c -o /dev/null -w '%{http_code} %{redirect_url}' -H "Origin: $B" --data-urlencode "csrf=$K" "${campos[@]}" "$B$rota" | sed "s|$B||")"
  r_falso="$(c -o /dev/null -w '%{http_code} %{redirect_url}' -b '__Host-sessao=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' -H "Origin: $B" --data-urlencode "csrf=$K" "${campos[@]}" "$B$rota" | sed "s|$B||")"
  r_token="$(envio "$rota" "${campos[@]}")"
  r_errado="$(envio "$rota" --data-urlencode 'csrf=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' "${campos[@]}")"
  r_origem="$(c -o /dev/null -w '%{http_code}' -b "$J" -H 'Origin: https://site-de-fora.example' --data-urlencode "csrf=$K" "${campos[@]}" "$B$rota")"
  [[ "$r_sem" == "303 /entrar" && "$r_falso" == "303 /entrar" && "$r_token" == "403 " && "$r_errado" == "403 " && "$r_origem" == 403 ]] || ok=1
  ev_sessao+="POST $rota sem cookie: $r_sem, com cookie de sessão inventado: $r_falso, com sessão e sem o token: $r_token, com token errado: $r_errado, com o token certo e Origin de fora: $r_origem; "
done
r_senha="$(apaga22 solta22/y.cfg "$W/errada22.senha")"
# Com a sessão do próprio usuário do FTP: as rotas de renomear e de apagar não existem para ele, e a tela dele não tem os botões.
e_usu="$(COMO=arq22 entrar "$U22" "$W/u22.senha")"; proibir "$(biscoito_de "$U22")"
UK="$(c -b "$U22" "$B/meus-arquivos" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1)"; proibir "$UK"
r_usu="$(POTE="$U22" envio /arquivos/apagar --data-urlencode "csrf=$UK" --data-urlencode 'item=arq22/novo.cfg' --data-urlencode 'confirmar=sim' --data-urlencode "senha_atual@$W/u22.senha")"
r_usu_ren="$(POTE="$U22" envio /arquivos/renomear --data-urlencode "csrf=$UK" --data-urlencode 'item=arq22/novo.cfg' --data-urlencode 'nome=meu.cfg')"
r_usu_tela="$(aba -b "$U22" "$B/arquivos/apagar?item=arq22/novo.cfg")"; r_usu_tela_ren="$(aba -b "$U22" "$B/arquivos/renomear?item=arq22/novo.cfg")"
r_usu_lista="$(aba -b "$U22" "$B/meus-arquivos")"; botoes_usu="$(grep -c -E 'href="/arquivos/(renomear|apagar)' "$W/corpo")"
auditoria; n_depois="$(eventos recusa_caminho)"; c_depois="$(eventos recusa_csrf)"; o_depois="$(eventos recusa_origem)"; s_depois="$(eventos admin_senha_atual_recusada)"; p_depois="$(eventos recusa_papel)"
depois="$(arvore22)"; auth_meio="$(auth22)"
# O link simbólico em si é apagado; o destino dele, não. A pasta que não é de usuário sai inteira.
r_apa_link="$(apaga22 arq22/cadastro.lnk)"; r_apa_atalho="$(apaga22 arq22/atalho)"; r_apa_solta="$(apaga22 solta22)"
e_link="$(existe22 arq22/cadastro.lnk)"; e_atalho="$(existe22 arq22/atalho)"; e_solta="$(existe22 solta22)"; auth_depois="$(auth22)"
l_fim="$(login22 arq22 "$W/u22.senha")"
[[ "$r_ln" == 0 && "$r_cli" == "303 /usuarios?m=criado" && "$r_nulo" == "400 " && "$r_nulo_2" == "400 " \
  && "$r_link" == "403 " && "$r_link_ren" == "403 " && "$t_link" == "403 " && "$t_link_ren" == "403 " && "$r_falta" == "404 " && "$r_falta_ren" == "404 " \
  && "$r_casa" == "409 " && "$r_casa_ren" == "409 " && "$r_cima" == "409 " && "$r_cima_ren" == "409 " && "$t_casa" == "409 " && "$t_cima" == "409 " \
  && "$r_senha" == "403 " && "$e_usu" == 303 && -n "$UK" && "$r_usu" == "404 " && "$r_usu_ren" == "404 " && "$r_usu_tela" == "404 " && "$r_usu_tela_ren" == "404 " \
  && "$r_usu_lista" == "200 " && "$botoes_usu" == 0 && "$antes" == "$depois" && "$auth_antes" == "$auth_meio" \
  && "$n_depois" -gt "$n_antes" && "$c_depois" -gt "$c_antes" && "$o_depois" -gt "$o_antes" && "$s_depois" == $((s_antes + 1)) && "$p_depois" -gt "$p_antes" \
  && "$r_apa_link" == "303 /arquivos?pasta=arq22&m=apagado" && "$r_apa_atalho" == "303 /arquivos?pasta=arq22&m=apagado" && "$r_apa_solta" == "303 /arquivos?pasta=&m=apagado" \
  && "$e_link" == não && "$e_atalho" == não && "$e_solta" == não && "$auth_antes" == "$auth_depois" && "$l_fim" == "0 226" ]] || ok=1
caso $ok seguranca 82 "Apagar e renomear não saem da pasta dos dados nem agem sem sessão e sem senha" "com sessão, token, caixa e senha válidos, caminho recusado em apagar/ renomear: ${ev}com byte nulo: $r_nulo· com byte nulo codificado no campo: $r_nulo_2· por dentro de um link simbólico para /auth, apagar: $r_link· renomear: $r_link_ren· telas: $t_link e $t_link_ren· item que não existe: $r_falta e $r_falta_ren· nome novo recusado: ${ev_nome}pasta de um usuário do FTP, apagar: $r_casa· renomear: $r_casa_ren· pasta que tem a de um usuário dentro, apagar: $r_cima· renomear: $r_cima_ren· telas: $t_casa e $t_cima· ${ev_sessao}com tudo certo e a senha atual errada: $r_senha· com a sessão do próprio usuário do FTP (entrada $e_usu), apagar: $r_usu· renomear: $r_usu_ren· telas: $r_usu_tela e $r_usu_tela_ren· botões de renomear ou apagar na tela Meus arquivos ($r_usu_lista): $botoes_usu · depois de todas as recusas, pastas dos dados e do cadastro $([[ "$antes" == "$depois" ]] && echo inalteradas || echo ALTERADAS), cadastro do FTP $([[ "$auth_antes" == "$auth_meio" ]] && echo inalterado || echo ALTERADO) · recusa_caminho na auditoria: $n_antes → $n_depois · recusa_csrf: $c_antes → $c_depois · recusa_origem: $o_antes → $o_depois · admin_senha_atual_recusada: $s_antes → $s_depois · recusa_papel: $p_antes → $p_depois · apagar o link simbólico para o cadastro: $r_apa_link · o link para a pasta /auth: $r_apa_atalho · a pasta solta22, que não é de usuário: $r_apa_solta · existem depois: $e_link, $e_atalho e $e_solta · o cadastro do FTP e o que há em /auth $([[ "$auth_antes" == "$auth_depois" ]] && echo 'continuam intactos' || echo 'FORAM ALTERADOS') · o usuário continua entrando no FTP: $l_fim"

# ------------------------------------------------------------------ pasta grande: um pedido apaga até o limite
docker exec "$FTP" sh -c 'mkdir /data/muitos22 && cd /data/muitos22 && seq 1 50001 | xargs touch'; r_prep=$?
auditoria; n_apa="$(eventos item_apagado)"
campos=(--data-urlencode "csrf=$K" --data-urlencode 'item=muitos22' --data-urlencode 'confirmar=sim' --data-urlencode "senha_atual@$W/painel.senha")
r_1="$(aba -b "$J" -H "Origin: $B" "${campos[@]}" "$B/arquivos/apagar")"; parte="$(grep -c 'Apagado em parte' "$W/corpo")"; quantos="$(grep -c '<strong>50000</strong> item' "$W/corpo")"
repetir="$(grep -c 'href="/arquivos/apagar?item=muitos22"' "$W/corpo")"; sobra="$(docker exec "$FTP" sh -c 'ls /data/muitos22 | wc -l')"
s_meio="$(saude "$PAINEL")"; r_tela="$(aba -b "$J" "$B/usuarios")"
r_2="$(apaga22 muitos22)"; e_fim="$(existe22 muitos22)"
auditoria; n_apa_2="$(eventos item_apagado)"
reg_1="$(grep -c " evento=item_apagado admin=$ADMIN tipo=pasta caminho=muitos22 itens=50000 completo=nao\$" "$W/auditoria")"
reg_2="$(grep -c " evento=item_apagado admin=$ADMIN tipo=pasta caminho=muitos22 itens=2\$" "$W/auditoria")"
[[ "$r_prep" == 0 && "$r_1" == "200 " && "$parte" == 1 && "$quantos" == 1 && "$repetir" == 1 && "$sobra" == 1 && "$s_meio" == "healthy " && "$r_tela" == "200 " \
  && "$r_2" == "303 /arquivos?pasta=&m=apagado" && "$e_fim" == não && "$n_apa_2" == $((n_apa + 2)) && "$reg_1" == 1 && "$reg_2" == 1 ]]
caso $? seguranca 83 "Pasta grande apagada em mais de um pedido" "pasta muitos22 com 50001 arquivos (preparo $r_prep) · primeiro POST /arquivos/apagar: $r_1, tela 'Apagado em parte': $parte, com 50000 itens apagados: $quantos, botão de repetir: $repetir · arquivos que sobraram na pasta: $sobra · painel depois do pedido: $s_meio, aba Usuários: $r_tela · segundo pedido: $r_2 · a pasta existe depois: $e_fim · auditoria item_apagado: $n_apa → $n_apa_2, linha do primeiro pedido com 50000 itens e completo=nao: $reg_1, do segundo com 2 itens: $reg_2"
