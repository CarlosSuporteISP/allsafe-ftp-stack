#!/usr/bin/env bash
# Etapa K: administradores do painel. Criar, trocar senha e nome, remover, sessões encerradas, senha
# atual em toda alteração e recuperação do acesso pelo host (scripts/painel-senha.sh).
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O limite de tentativas é por endereço e soma entrada recusada com senha atual recusada: na 5ª em 15
# minutos o endereço fica bloqueado, inclusive para quem acerta. Por isso cada recusa desta etapa está
# contada no comentário, o reinício do painel feito pelo painel-senha.sh (que zera a contagem) fica no
# meio e o caso que estoura o limite de propósito é o último.
A=/administradores
J2="$W/apoio.jar"; J3="$W/plantao.jar"; J4="$W/segunda.jar"; JR="$W/recusa.jar"
for n in 1 3 4 5; do nova_senha "$W/a$n.senha"; done
# Senhas em texto usadas por administradores nesta etapa: nenhuma pode aparecer no arquivo do painel.
texto_admin() { { cat "$1"; echo; } >> "$W/senhas-admin"; }
: > "$W/senhas-admin"; texto_admin "$W/painel.senha"
gerada_na_tela() { sed -n 's/.*<p class="segredo"><code>\([^<]*\)<\/code>.*/\1/p' "$1" | head -1 | tr -d '\n'; }
gerada_no_host() { awk 'achou { print; exit } /^Senha nova do administrador/ { achou = 1 }' "$1" | tr -d '\r\n'; }
quem_entrou() { aba -b "$1" "$B/" > /dev/null; sed -n 's/.*class="quem"[^>]*>\([^<]*\)<.*/\1/p' "$W/corpo" | head -1; }
sem_token() { sed 's/name="token" value="[^"]*"/name="token"/' "$1"; }
soma_admins() { docker exec "$PAINEL" sha256sum /painel/administradores 2>/dev/null | cut -c1-16; }
K="$(csrf)"; proibir "$K"

# ------------------------------------------------------------------ pelo painel
lista="$(aba -b "$J" "$B$A")"; voce="$(grep -o "<strong>$ADMIN</strong> <span class=\"etiqueta\">você</span>" "$W/corpo" | wc -l)"
r_novo="$(envio $A/novo --data-urlencode "csrf=$K" --data-urlencode 'nome=apoio' --data-urlencode "senha@$W/a1.senha" --data-urlencode "confirmacao@$W/a1.senha" --data-urlencode "senha_atual@$W/painel.senha")"
e_apoio="$(COMO=apoio entrar "$J2" "$W/a1.senha")"; proibir "$(biscoito_de "$J2")"; quem_apoio="$(quem_entrou "$J2")"
# Sem senha no formulário, o painel gera uma e mostra uma única vez.
r_gerado="$(c -o "$W/gerada.corpo" -w '%{http_code}' -b "$J" -H "Origin: $B" --data-urlencode "csrf=$K" --data-urlencode 'nome=plantao' --data-urlencode "senha_atual@$W/painel.senha" "$B$A/novo")"
gerada_na_tela "$W/gerada.corpo" > "$W/a2.senha"; proibir "$(cat "$W/a2.senha")"
e_plantao="$(COMO=plantao entrar "$J3" "$W/a2.senha")"; proibir "$(biscoito_de "$J3")"
K3="$(POTE="$J3" csrf)"; proibir "$K3"
for n in 1 2 3; do texto_admin "$W/a$n.senha"; done

# Senha trocada por outro administrador: a sessão do alterado cai e a senha antiga deixa de entrar.
r_senha="$(envio $A/senha --data-urlencode "csrf=$K" --data-urlencode 'admin=apoio' --data-urlencode "senha@$W/a3.senha" --data-urlencode "confirmacao@$W/a3.senha" --data-urlencode "senha_atual@$W/painel.senha")"
s_senha="$(aba -b "$J2" "$B/")"
e_velha="$(COMO=apoio entrar "$JR" "$W/a1.senha")"                                   # recusa 1
e_nova="$(COMO=apoio entrar "$J2" "$W/a3.senha")"; proibir "$(biscoito_de "$J2")"
r_nome="$(envio $A/nome --data-urlencode "csrf=$K" --data-urlencode 'admin=apoio' --data-urlencode 'nome=suporte' --data-urlencode "senha_atual@$W/painel.senha")"
s_nome="$(aba -b "$J2" "$B/")"
e_antigo="$(COMO=apoio entrar "$JR" "$W/a3.senha")"                                  # recusa 2
e_suporte="$(COMO=suporte entrar "$J2" "$W/a3.senha")"; proibir "$(biscoito_de "$J2")"; quem_suporte="$(quem_entrou "$J2")"
ftp_antes="$(usuarios_ftp)"
r_remover="$(envio $A/remover --data-urlencode "csrf=$K" --data-urlencode 'admin=plantao' --data-urlencode "senha_atual@$W/painel.senha")"
s_removido="$(aba -b "$J3" "$B/")"
p_removido="$(POTE="$J3" envio /usuarios/novo --data-urlencode 'usuario=equip11' --data-urlencode "csrf=$K3" --data-urlencode "senha@$W/u4.senha" --data-urlencode "confirmacao@$W/u4.senha")"
e_removido="$(COMO=plantao entrar "$JR" "$W/a2.senha")"                              # recusa 3
# A própria senha: a sessão de quem trocou continua; a outra sessão do mesmo administrador cai.
e_segunda="$(entrar "$J4" "$W/painel.senha")"; proibir "$(biscoito_de "$J4")"
r_propria="$(envio $A/senha --data-urlencode "csrf=$K" --data-urlencode "admin=$ADMIN" --data-urlencode "senha@$W/a4.senha" --data-urlencode "confirmacao@$W/a4.senha" --data-urlencode "senha_atual@$W/painel.senha")"
cp "$W/a4.senha" "$W/painel.senha"; texto_admin "$W/painel.senha"
s_atual="$(aba -b "$J" "$B/")"; s_segunda="$(aba -b "$J4" "$B/")"

r="$(aba -b "$J" "$B/atividade")"; ev=""; ok=0
for texto in 'Administrador criado' 'Senha de administrador trocada' 'Administrador renomeado' 'Administrador removido'; do
  n="$(grep -o "$texto" "$W/corpo" | wc -l)"; [[ "$n" -ge 1 ]] || ok=1; ev+="$texto: $n; "
done
auditoria
com_nome="$(grep -c -E " evento=admin_(criado|senha_trocada|renomeado|removido) admin=$ADMIN " "$W/auditoria")"
[[ "$lista" == "200 " && "$voce" == 1 && "$r_novo" == "303 $A?m=criado" && "$e_apoio" == 303 && "$quem_apoio" == apoio \
  && "$r_gerado" == 200 && -s "$W/a2.senha" && "$e_plantao" == 303 && "$r_senha" == "303 $A?m=senha" && "$e_velha" == 401 && "$e_nova" == 303 \
  && "$r_nome" == "303 $A?m=nome" && "$e_antigo" == 401 && "$e_suporte" == 303 && "$quem_suporte" == suporte \
  && "$r_remover" == "303 $A?m=removido" && "$e_removido" == 401 && "$r_propria" == "303 $A?m=senha" \
  && "$(admins)" == "$ADMIN suporte " && "$r" == "200 " && "$ok" == 0 && "$com_nome" == 6 ]]
caso $? testes 22 "Administradores pelo painel" "GET $A: $lista· '$ADMIN' marcado como você: $voce · novo 'apoio' com senha informada: $r_novo, entrada $e_apoio, nome no topo: ${quem_apoio:-nenhum} · novo 'plantao' com senha gerada pelo painel: $r_gerado, entrada com ela: $e_plantao · senha do 'apoio' trocada por '$ADMIN': $r_senha, antiga $e_velha, nova $e_nova · nome 'apoio' → 'suporte': $r_nome, nome antigo $e_antigo, nome novo $e_suporte · 'plantao' removido: $r_remover, entrada depois $e_removido · própria senha: $r_propria · administradores no fim: $(admins)· aba Atividade ($r): $ev eventos com admin=$ADMIN na auditoria: $com_nome de 6"

[[ "$s_senha" == "303 /entrar" && "$s_nome" == "303 /entrar" && "$s_removido" == "303 /entrar" && "$p_removido" == "303 /entrar" \
  && "$ftp_antes" == "$(usuarios_ftp)" && "$e_segunda" == 303 && "$s_atual" == "200 " && "$s_segunda" == "303 /entrar" ]]
caso $? seguranca 48 "Sessão de administrador alterado" "cookie do administrador depois de outro trocar a senha dele: $s_senha · depois de trocarem o nome: $s_nome · depois de removido: GET $s_removido, POST /usuarios/novo com o token dele: $p_removido, usuário do FTP criado: $([[ "$ftp_antes" == "$(usuarios_ftp)" ]] && echo não || echo SIM) · quem troca a própria senha: sessão em uso $s_atual· outra sessão aberta do mesmo administrador: $s_segunda"

# ------------------------------------------------------------------ recuperação pelo host
# 1) Sem opção de nome: o administrador de PAINEL_ADMIN_USER. Painel no ar: grava, reinicia e derruba as sessões.
semente_antes="$(sha256sum < "$S/painel-admin-inicial-senha-hash.txt" | cut -c1-16)"
ENV_FILE="$ENVA" ./scripts/painel-senha.sh --gerar < /dev/null > "$W/recuperar-1.out" 2> "$W/recuperar-1.err"; r1=$?
gerada_no_host "$W/recuperar-1.out" > "$W/painel.senha"; proibir "$(cat "$W/painel.senha")"; texto_admin "$W/painel.senha"
proibir "$(head -1 "$S/painel-admin-inicial-senha-hash.txt" 2>/dev/null)"
painel_de_pe; pe1=$?
semente_depois="$(sha256sum < "$S/painel-admin-inicial-senha-hash.txt" | cut -c1-16)"
texto_inicial="$([[ -e "$S/painel-admin-inicial-senha.txt" ]] && echo 'AINDA EXISTE' || echo removido)"
s_reinicio="$(aba -b "$J" "$B/")"
auditoria; f_antes="$(eventos entrada_falha)"
e_velha_host="$(entrar "$JR" "$W/a4.senha")"; cp "$W/entrada.corpo" "$W/recusa-senha.corpo"   # recusa 1 (contagem zerada pelo reinício)
aviso_senha="$(sed -n 's/.*role="alert">\([^<]*\)<.*/\1/p' "$W/entrada.corpo" | head -1)"

# Nome que não existe e nome fora da regra: mesma resposta da senha errada, e o que foi digitado não é gravado.
e_fantasma="$(COMO=fantasma-de-teste entrar "$JR" "$W/a4.senha")"; cp "$W/entrada.corpo" "$W/recusa-nome.corpo"   # recusa 2
e_torto="$(COMO='Fantasma;de teste' entrar "$JR" "$W/a4.senha")"                                                   # recusa 3
iguais=0; cmp -s <(sem_token "$W/recusa-senha.corpo") <(sem_token "$W/recusa-nome.corpo") || iguais=1
cmp -s <(sem_token "$W/recusa-senha.corpo") <(sem_token "$W/entrada.corpo") || iguais=1
auditoria; f_depois="$(eventos entrada_falha)"
docker logs "$PAINEL" > "$W/log-painel" 2>&1; docker logs "$NGINX" > "$W/log-nginx" 2>&1
digitado=$(( $(grep -c -i 'fantasma' "$W/auditoria") + $(grep -c -i 'fantasma' "$W/log-painel") + $(grep -c -i 'fantasma' "$W/log-nginx") ))
[[ "$e_velha_host" == 401 && "$e_fantasma" == 401 && "$e_torto" == 401 && "$iguais" == 0 && "$aviso_senha" != *enha* && "$aviso_senha" != *suário* \
  && "$f_depois" == $((f_antes + 3)) && "$digitado" == 0 ]]
caso $? seguranca 46 "Administrador inexistente não é revelado" "POST /entrar com '$ADMIN' e senha errada: $e_velha_host · com nome que não existe: $e_fantasma · com nome fora da regra: $e_torto · as três páginas $([[ "$iguais" == 0 ]] && echo 'são iguais' || echo 'são DIFERENTES'), tirando o token do formulário · aviso na tela: $aviso_senha · entrada_falha na auditoria: $f_antes → $f_depois · nome digitado na auditoria e no registro do painel e do nginx: $digitado ocorrências"

e_nova_host="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"

# 2) Outro administrador, senha pela entrada padrão. O hash da senha inicial não muda.
ENV_FILE="$ENVA" ./scripts/painel-senha.sh --usuario suporte < "$W/a5.senha" > "$W/recuperar-2.out" 2> "$W/recuperar-2.err"; r2=$?
texto_admin "$W/a5.senha"; painel_de_pe; pe2=$?
semente_outro="$(sha256sum < "$S/painel-admin-inicial-senha-hash.txt" | cut -c1-16)"
e_suporte_host="$(COMO=suporte entrar "$J2" "$W/a5.senha")"; proibir "$(biscoito_de "$J2")"

# 3) Painel parado, administrador que ainda não existe: criado em um container de uso único.
dc stop painel > /dev/null 2>&1
ENV_FILE="$ENVA" ./scripts/painel-senha.sh --usuario resgate --gerar < /dev/null > "$W/recuperar-3.out" 2> "$W/recuperar-3.err"; r3=$?
gerada_no_host "$W/recuperar-3.out" > "$W/a6.senha"; proibir "$(cat "$W/a6.senha")"; texto_admin "$W/a6.senha"
sobras="$(docker ps -aq --filter "label=com.docker.compose.project=$NOME" --filter 'label=com.docker.compose.oneoff=True' | wc -l)"
dc start painel > /dev/null 2>&1; painel_de_pe; pe3=$?
e_resgate="$(COMO=resgate entrar "$W/resgate.jar" "$W/a6.senha")"; proibir "$(biscoito_de "$W/resgate.jar")"
de_volta="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
auditoria
no_host="$(grep -c ' evento=admin_definido_no_host ' "$W/auditoria")"; criados_no_host="$(grep -c ' evento=admin_definido_no_host admin=resgate resultado=criado' "$W/auditoria")"
[[ "$r1" == 0 && "$pe1" == 0 && -s "$W/painel.senha" && "$semente_antes" != "$semente_depois" && "$texto_inicial" == removido \
  && "$(stat -c '%a' "$S/painel-admin-inicial-senha-hash.txt")" == 600 && "$s_reinicio" == "303 /entrar" && "$e_velha_host" == 401 && "$e_nova_host" == 303 \
  && "$r2" == 0 && "$pe2" == 0 && "$semente_outro" == "$semente_depois" && "$e_suporte_host" == 303 \
  && "$r3" == 0 && "$pe3" == 0 && "$sobras" == 0 && -s "$W/a6.senha" && "$e_resgate" == 303 && "$de_volta" == 303 \
  && "$(admins)" == "$ADMIN suporte resgate " && "$no_host" == 3 && "$criados_no_host" == 1 && "$(eventos admin_inicial_criado)" == 1 ]] \
  && grep -q -x "Administrador $ADMIN com a senha trocada; painel reiniciado e sessões abertas encerradas." "$W/recuperar-1.out" \
  && grep -q -x 'Administrador suporte com a senha trocada; painel reiniciado e sessões abertas encerradas.' "$W/recuperar-2.out" \
  && grep -q -x 'Administrador resgate criado; vale na próxima subida do painel.' "$W/recuperar-3.out"
caso $? testes 23 "Recuperação do acesso pelo host" "painel-senha.sh --gerar (administrador de PAINEL_ADMIN_USER, painel no ar): saída $r1 · $(tail -1 "$W/recuperar-1.out") · sessão aberta antes: $s_reinicio · senha antiga: $e_velha_host · senha gerada: $e_nova_host · hash da senha inicial em .secrets: $([[ "$semente_antes" != "$semente_depois" ]] && echo regravado || echo 'O MESMO'), arquivo da senha inicial em texto: $texto_inicial · --usuario suporte com a senha pela entrada padrão: saída $r2 · $(tail -1 "$W/recuperar-2.out") · entrada $e_suporte_host, hash da senha inicial $([[ "$semente_outro" == "$semente_depois" ]] && echo intacto || echo ALTERADO) · --usuario resgate --gerar com o painel parado: saída $r3 · $(tail -1 "$W/recuperar-3.out") · containers de uso único que sobraram: $sobras · entrada depois de subir: $e_resgate · administradores: $(admins)· admin_definido_no_host na auditoria: $no_host (criado: $criados_no_host) · admin_inicial_criado depois dos reinícios: $(eventos admin_inicial_criado)"

# ------------------------------------------------------------------ recusas que não gastam tentativa
antes="$(admins)"
r_tela="$(aba -b "$J" "$B$A/remover?admin=$ADMIN")"
r="$(envio $A/remover --data-urlencode "csrf=$K" --data-urlencode "admin=$ADMIN" --data-urlencode "senha_atual@$W/painel.senha")"
aba -b "$J" "$B$A" > /dev/null
link_proprio="$(grep -o "remover?admin=$ADMIN\"" "$W/corpo" | wc -l)"; link_outros="$(grep -o 'remover?admin=[a-z0-9_-]*"' "$W/corpo" | wc -l)"
[[ "$r_tela" == "409 " && "$r" == "409 " && "$antes" == "$(admins)" && "$link_proprio" == 0 && "$link_outros" == 2 ]]
caso $? seguranca 49 "Ninguém remove a própria conta" "GET $A/remover?admin=$ADMIN na sessão de '$ADMIN': $r_tela· POST com a senha atual certa: $r· administradores $([[ "$antes" == "$(admins)" ]] && echo inalterados || echo ALTERADOS): $(admins)· botão Remover na lista: $link_proprio para a própria conta, $link_outros para os outros"

modo="$(docker exec "$PAINEL" stat -c '%a %U:%G' /painel/administradores 2>/dev/null)"; pasta="$(docker exec "$PAINEL" stat -c '%a %U:%G' /painel 2>/dev/null)"
docker exec "$PAINEL" cat /painel/administradores > "$W/administradores" 2>/dev/null
linhas="$(grep -c . "$W/administradores")"
no_formato="$(grep -c -E '^[a-z_][a-z0-9_-]{0,31}:scrypt\$15\$8\$1\$[A-Za-z0-9_=+/-]+\$[A-Za-z0-9_=+/-]+$' "$W/administradores")"
em_texto="$(grep -c -a -F -f "$W/senhas-admin" "$W/administradores" || true)"
provisorio="$(docker exec "$PAINEL" sh -c 'ls /painel' 2>/dev/null | grep -c '\.novo$' || true)"
pelo_host="$([[ -r "$T/dados/painel/administradores" ]] && echo SIM || echo não)"
[[ "$modo" == "600 root:root" && "$pasta" == "700 root:root" && "$linhas" == 3 && "$no_formato" == 3 && "$em_texto" == 0 && "$provisorio" == 0 \
  && ( "$EUID" == 0 || "$pelo_host" == não ) ]]
caso $? seguranca 50 "Arquivo de administradores só com hash" "/painel/administradores: $modo, pasta $pasta · $linhas linhas, $no_formato no formato nome:scrypt\$15\$8\$1\$sal\$resumo · $(grep -c . "$W/senhas-admin") senhas usadas nesta bateria procuradas em texto: $em_texto ocorrências · arquivo provisório esquecido: $provisorio · lido pelo usuário comum do host: $pelo_host"

r_d="$(recusa_deploy 'PAINEL_ADMIN_USER=Admin')"; r_c="$(recusa_container painel 'PAINEL_ADMIN_USER=../raiz')"
recusou "$r_d" 'PAINEL_ADMIN_USER inválido' && recusou "$r_c" 'PAINEL_ADMIN_USER inválido'
caso $? seguranca 51 "Nome de administrador inválido" "PAINEL_ADMIN_USER=Admin no deploy.sh --check-only: $r_d · PAINEL_ADMIN_USER=../raiz direto no container do painel: $r_c"

# ------------------------------------------------------------------ senha atual em toda alteração (por último: estoura o limite)
antes="$(admins)"; soma_antes="$(soma_admins)"; auditoria; n_antes="$(eventos admin_senha_atual_recusada)"; b_antes="$(eventos entrada_bloqueada)"
r_a="$(envio $A/novo --data-urlencode "csrf=$K" --data-urlencode 'nome=intruso' --data-urlencode "senha@$W/a1.senha" --data-urlencode "confirmacao@$W/a1.senha" --data-urlencode "senha_atual@$W/errada.senha")"   # recusa 1
r_b="$(envio $A/senha --data-urlencode "csrf=$K" --data-urlencode 'admin=suporte' --data-urlencode "senha@$W/a1.senha" --data-urlencode "confirmacao@$W/a1.senha")"                                              # recusa 2
r_c="$(envio $A/nome --data-urlencode "csrf=$K" --data-urlencode 'admin=suporte' --data-urlencode 'nome=intruso' --data-urlencode "senha_atual@$W/errada.senha")"                                               # recusa 3
r_d="$(envio $A/remover --data-urlencode "csrf=$K" --data-urlencode 'admin=suporte' --data-urlencode "senha_atual@$W/errada.senha")"                                                                          # recusa 4
e_suporte_fim="$(COMO=suporte entrar "$J2" "$W/a5.senha")"; proibir "$(biscoito_de "$J2")"
r_e="$(envio $A/remover --data-urlencode "csrf=$K" --data-urlencode 'admin=suporte' --data-urlencode "senha_atual@$W/errada.senha")"                                                                          # recusa 5: limite
r_f="$(envio $A/remover --data-urlencode "csrf=$K" --data-urlencode 'admin=suporte' --data-urlencode "senha_atual@$W/painel.senha")"
auditoria; n_depois="$(eventos admin_senha_atual_recusada)"; b_depois="$(eventos entrada_bloqueada)"
[[ "$r_a" == "403 " && "$r_b" == "403 " && "$r_c" == "403 " && "$r_d" == "403 " && "$e_suporte_fim" == 303 && "$r_e" == "403 " && "$r_f" == "429 " \
  && "$antes" == "$(admins)" && "$soma_antes" == "$(soma_admins)" && "$n_depois" == $((n_antes + 5)) && "$b_depois" == $((b_antes + 1)) ]]
caso $? seguranca 47 "Alteração só com a senha atual" "com sessão e token válidos · criar com a senha atual errada: $r_a· trocar a senha de outro sem o campo: $r_b· trocar o nome com ela errada: $r_c· remover com ela errada: $r_d· o alvo continua entrando: $e_suporte_fim · 5ª recusa do endereço: $r_e· em seguida, a senha atual certa: $r_f(bloqueado pelo limite de tentativas) · administradores $([[ "$antes" == "$(admins)" ]] && echo inalterados || echo ALTERADOS), arquivo $([[ "$soma_antes" == "$(soma_admins)" ]] && echo idêntico || echo DIFERENTE) · admin_senha_atual_recusada na auditoria: $n_antes → $n_depois · entrada_bloqueada: $b_antes → $b_depois"

# Com --manter, a instância fica no ar: o reinício tira o bloqueio que o caso acima deixou no endereço.
if [[ "$manter" == true ]]; then dc restart painel > /dev/null 2>&1; painel_de_pe; fi
