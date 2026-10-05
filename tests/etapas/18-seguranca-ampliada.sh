#!/usr/bin/env bash
# Etapa R: segurança ampliada. Quatro perguntas, cada uma com os seus casos: abre alguma coisa sem senha?
# Abre com senha aleatória? Dá para exaurir a stack (rajada de senhas, de pedidos e de conexões, conexão
# parada, pedido malformado)? Dá para chegar ao cadastro das senhas sem passar pela entrada (pela web, pelo
# FTP, por outro container, pelo host)? E dois casos funcionais: tudo roda em Docker, sem systemd, e a senha
# do usuário inicial é a do segredo a cada subida.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel zera a contagem de falhas de entrada e das recusas e encerra as sessões.
dc restart painel > /dev/null 2>&1; painel_de_pe
INICIO18="$(date +%s)"

ms() { echo $(( ($(date +%s%N) - $1) / 1000000 )); }                 # <início em ns> → milissegundos passados
seg() { awk -v m="$1" 'BEGIN { printf "%.1f s", m / 1000 }'; }       # <milissegundos> → "7.8 s"
reinicios() { docker inspect -f '{{.RestartCount}}' "$FTP" "$PAINEL" "$NGINX" 2>/dev/null | tr '\n' ' '; }
memoria() { docker stats --no-stream --format '{{.Name}} {{.MemPerc}}' "$FTP" "$PAINEL" "$NGINX" 2>/dev/null | tr '\n' ' '; }
aleatoria() { openssl rand -base64 24 | tr -d '\n' > "$1"; }         # <arquivo>: senha que ninguém cadastrou
inventado() { openssl rand -base64 32 | tr '+/' '-_' | tr -d '=\n'; }  # valor com cara de cookie de sessão
# Login no FTP com TLS e lista da pasta, sem -v e com arquivo de configuração próprio, para rodar várias de uma vez.
tenta() { # <usuário> <arquivo da senha> → "saída do curl, código do FTP, segundos"
  ( umask 077; cfg="$W/r18.$BASHPID.cfg"; codigo=0
    printf 'user = "%s:%s"\n' "$1" "$(tr -d '\r\n' < "$2")" > "$cfg"
    r="$(curl -s --max-time 90 -K "$cfg" --ssl-reqd -k -o /dev/null -w '%{response_code} %{time_total}' "$F/")" || codigo=$?
    rm -f "$cfg"; echo "$codigo $r" )
}
tempo_de() { echo "${1##* }" | cut -d. -f1; }                        # <resultado do tenta> → segundos inteiros
dur() { awk -v s="${1##* }" 'BEGIN { printf "%.1f s", s }'; }          # <resultado do tenta> → "0.9 s"
# Usuário gravado como nas versões até a 0.18.0: pure-pw sem -C, direto no container do FTP.
antigo() { # <nome> <arquivo da senha>
  { cat "$2"; echo; cat "$2"; echo; } | docker exec -i -e NOME18="$1" "$FTP" sh -c 'install -d -o ftpdata -g ftpdata -m 0750 "/data/$NOME18" \
    && pure-pw useradd "$NOME18" -f /auth/pureftpd.passwd -u ftpdata -g ftpdata -d "/data/$NOME18" > /dev/null && pure-pw mkdb /auth/pureftpd.pdb -f /auth/pureftpd.passwd' > /dev/null 2>&1
}
# Conversa com o FTP em TLS, sem login: devolve a resposta de cada comando.
ftp_tls_cru() { # <espera no fim> <comando...>
  local espera="$1" comando; shift
  { for comando in "$@"; do printf '%s\r\n' "$comando"; sleep 0.2; done; sleep "$espera"; } \
    | timeout 60 openssl s_client -quiet -starttls ftp -connect "$IP:$FTP_PORTA" 2>/dev/null | tr -d '\r' | grep -a -E '^[0-9]{3} '
}
# Pedido escrito à mão para o painel, em TLS: devolve o código da resposta.
http_cru() { # <texto do pedido, com \r\n>
  { printf '%b' "$1"; sleep 2; } | timeout 30 openssl s_client -quiet -connect "$IP:$PAINEL_PORTA" 2>/dev/null \
    | head -1 | tr -d '\r' | awk '{print $2}'
}
custo() { docker exec "$FTP" grep "^$1:" /auth/pureftpd.passwd | cut -d: -f2 | cut -d '$' -f 4; }  # <usuário> → só os parâmetros do argon2id, nunca o hash
memoria_do_custo() { echo "$1" | sed -n 's/^m=\([0-9]*\),.*/\1/p'; }
# Nomes do cadastro com mais memória por conferência do que a referência, na ordem e no formato da aba Segurança.
# Do campo da senha só sai o número da memória.
acima_do_custo() { # <memória de referência>
  docker exec "$FTP" awk -F: -v ref="$1" '{ split($2, p, "$"); m = p[4]; sub(/^m=/, "", m); sub(/,.*/, "", m)
    if (m !~ /^[0-9]+$/ || m + 0 > ref + 0) print $1 }' /auth/pureftpd.passwd | LC_ALL=C sort | paste -sd, | sed 's/,/, /g'
}
quantos() { [[ -z "$1" ]] && echo 0 || echo "$1" | tr ',' '\n' | wc -l; }  # <lista separada por vírgula>
tem_fixo() { local n; n="$(grep -a -c -F -- "$1" "$W/corpo" 2>/dev/null)"; echo "${n:-0}"; }  # <texto literal> → linhas do corpo com ele
PAROU=()
abrir() { # <quantas>: conexões com o painel que não mandam nada
  local i fd; PAROU=()
  for ((i = 0; i < $1; i++)); do { exec {fd}<>"/dev/tcp/$IP/$PAINEL_PORTA"; } 2>/dev/null && PAROU+=("$fd"); done
}
fechar() { local fd; for fd in "${PAROU[@]}"; do exec {fd}>&-; done; PAROU=(); }
tela() { rm -f "$W/corpo"; aba "$@"; }                               # como o aba, sem sobra do corpo anterior
tem() { local n; n="$(grep -a -c -E "$1" "$W/corpo" 2>/dev/null)"; echo "${n:-0}"; }  # <expressão> → linhas do corpo com ela
mapfile -t ROTAS18 < <(sed -n "s/^ *('\(GET\|POST\)', '\([^']*\)').*/\1 \2/p" painel/rotas.py | sort -u)

# ------------------------------------------------------------------ tudo em Docker, sem systemd
ev=""; ok=0
for n in "$FTP" "$PAINEL" "$NGINX"; do
  p1="$(docker exec "$n" cat /proc/1/comm 2>/dev/null)"; tini="$(docker exec "$n" /sbin/docker-init --version 2>/dev/null | head -1)"
  politica="$(docker inspect -f '{{.HostConfig.Init}} {{.HostConfig.RestartPolicy.Name}}' "$n" 2>/dev/null)"
  unidade="$(docker exec "$n" sh -c 'ls -d /run/systemd/system 2>/dev/null | wc -l')"
  [[ "$p1" == docker-init && "$tini" == tini* && "$politica" == "true unless-stopped" && "$unidade" == 0 ]] || ok=1
  ev+="$n: processo 1 $p1 ($tini), init e reinício do Docker: $politica, /run/systemd/system: $unidade · "
done
servicos="$(dc config --services 2>/dev/null | sort | tr '\n' ' ')"
citam="$(grep -r -l -i -E 'systemd|systemctl' --include='*.sh' --include='*.yaml' --include='*.py' --include='*.conf' --include='Dockerfile' \
  --exclude-dir=.git --exclude-dir=doc --exclude-dir=tests . 2>/dev/null | wc -l)"
unidades="$(find . -path ./.git -prune -o \( -name '*.service' -o -name '*.timer' -o -name '*.socket' \) -print 2>/dev/null | grep -v '^./doc/planos/' | wc -l)"
[[ "$ok" == 0 && "$servicos" == "ftp nginx painel " && "$citam" == 0 && "$unidades" == 0 ]]
caso $? testes 37 "Tudo em Docker, sem systemd" "serviços do Compose: $servicos· ${ev}arquivos do projeto (roteiros, Compose, painel, nginx, Dockerfile) que citam systemd ou systemctl: $citam · arquivos de unidade (.service, .timer, .socket) no projeto: $unidades"

# ------------------------------------------------------------------ nada abre sem senha: painel
antes_u="$(usuarios_ftp)"; antes_a="$(admins)"; total=0; fora_do_esperado=""
for rota in "${ROTAS18[@]}"; do
  metodo="${rota%% *}"; caminho="${rota#* }"
  if [[ "$metodo" == GET ]]; then
    sem="$(tela --path-as-is "$B$caminho?usuario=$USUARIO&admin=$ADMIN")"
    com="$(tela --path-as-is -b "__Host-sessao=$(inventado)" "$B$caminho?usuario=$USUARIO&admin=$ADMIN")"
  else
    sem="$(tela -H "Origin: $B" --data-urlencode 'csrf=x' --data-urlencode 'usuario=intruso18' --data-urlencode 'nome=intruso18' \
      --data-urlencode 'pasta=intruso18' --data-urlencode 'senha=uma-senha-qualquer-18' --data-urlencode 'confirmacao=uma-senha-qualquer-18' "$B$caminho")"
    com="$(tela -H "Origin: $B" -b "__Host-sessao=$(inventado)" --data-urlencode 'csrf=x' --data-urlencode 'usuario=intruso18' --data-urlencode 'nome=intruso18' \
      --data-urlencode 'pasta=intruso18' --data-urlencode 'senha=uma-senha-qualquer-18' --data-urlencode 'confirmacao=uma-senha-qualquer-18' "$B$caminho")"
  fi
  total=$((total + 2))
  [[ "$sem" == "303 /entrar" && "$com" == "303 /entrar" && ! -s "$W/corpo" ]] || fora_do_esperado+="$metodo $caminho: $sem / $com · "
done
abertos=""; for caminho in /entrar /saude /robots.txt /favicon.ico; do abertos+="$caminho $(c -o /dev/null -w '%{http_code}' "$B$caminho") · "; done
criou="$(docker exec "$FTP" sh -c 'ls -d /data/intruso18 2>/dev/null | wc -l')"
[[ ${#ROTAS18[@]} -ge 27 && -z "$fora_do_esperado" && "$antes_u" == "$(usuarios_ftp)" && "$antes_a" == "$(admins)" && "$criou" == 0 ]]
caso $? seguranca 69 "Nenhuma rota do painel abre sem sessão" "as ${#ROTAS18[@]} rotas de painel/rotas.py (administrador e usuário do FTP), cada uma sem cookie e com um cookie de sessão inventado, os POST com Origin certo e campos preenchidos: $total pedidos, todos 303 para /entrar com corpo vazio${fora_do_esperado:+, MENOS: $fora_do_esperado} · usuários do FTP e administradores iguais antes e depois · pasta /data/intruso18 criada: $criou · o que responde sem sessão: $abertos"

# ------------------------------------------------------------------ nada abre sem senha: FTP
comandos=("LIST" "NLST" "RETR backup.cfg" "STOR invasor.cfg" "CWD /" "PWD" "MKD invasor" "DELE backup.cfg" "RNFR backup.cfg" "SIZE backup.cfg" "MDTM backup.cfg" "PASV" "SITE HELP")
com_tls="$(ftp_tls_cru 2 "${comandos[@]}")"; n_tls="$(printf '%s\n' "$com_tls" | grep -c '^530 ')"; outras_tls="$(printf '%s\n' "$com_tls" | grep -c -v '^530 ')"
sem_tls_18="$(ftp_cru "${comandos[@]}")"; n_puro="$(printf '%s\n' "$sem_tls_18" | grep -c '^530 ')"; outras_puro="$(printf '%s\n' "$sem_tls_18" | grep -c -v '^530 ')"
vazia="$(ftp_tls_cru 12 "USER $USUARIO" "PASS " "PWD" | cut -c1-3 | tr '\n' ' ')"
so_nome="$(ftp_tls_cru 2 "USER $USUARIO" "LIST" "PWD" | cut -c1-3 | tr '\n' ' ')"
[[ "$n_tls" == "${#comandos[@]}" && "$outras_tls" == 0 && "$n_puro" == "${#comandos[@]}" && "$outras_puro" == 0 && "$vazia" == "331 530 530 " && "$so_nome" == "331 530 530 " ]]
caso $? seguranca 70 "FTP não aceita comando antes do login nem senha vazia" "${#comandos[@]} comandos sem login (${comandos[*]}): em TLS, $n_tls respostas 530 e $outras_tls de outro tipo; sem TLS, $n_puro respostas 530 e $outras_puro de outro tipo · USER $USUARIO, PASS vazia e PWD: $vazia· USER $USUARIO sem PASS, LIST e PWD: $so_nome"

# ------------------------------------------------------------------ custo da senha do FTP e aviso das antigas
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
clientes="$(docker exec "$FTP" printenv FTP_MAX_CLIENTS)"; c_ini="$(custo "$USUARIO")"; m_ini="$(memoria_do_custo "$c_ini")"
nova_senha "$W/u18.senha"; nova_senha "$W/u18b.senha"
r_painel="$(envio /usuarios/novo --data-urlencode 'usuario=equip18' --data-urlencode "csrf=$K" --data-urlencode "senha@$W/u18.senha" --data-urlencode "confirmacao@$W/u18.senha")"
mu add equip18b "$W/u18b.senha"; r_mu=$?
c_painel="$(custo equip18)"; c_mu="$(custo equip18b)"; m_esperada=$((65536 / clientes))
ja_estavam="$(acima_do_custo "$m_ini")"   # quem já vinha com o custo de um porte menor (a bateria completa muda o porte na etapa 08)
antigo antigo18 "$W/u18b.senha"
lista_antes="$(acima_do_custo "$m_ini")"
c_antigo="$(custo antigo18)"; m_antigo="$(memoria_do_custo "$c_antigo")"
t_antigo="$(tenta antigo18 "$W/u18b.senha")"; t_novo="$(tenta equip18 "$W/u18.senha")"
seg_antes="$(tela -b "$J" "$B/seguranca")"; avisa="$(tem_fixo "<strong>$(quantos "$lista_antes") usuário(s) com a senha gravada com o custo anterior</strong>: $lista_antes. ")"; hash_tela="$(tem 'argon2id|m=[0-9]+,t=')"
r_troca="$(envio /usuarios/senha --data-urlencode 'usuario=antigo18' --data-urlencode "csrf=$K" --data-urlencode "senha@$W/u18.senha" --data-urlencode "confirmacao@$W/u18.senha")"
c_trocado="$(custo antigo18)"; m_trocado="$(memoria_do_custo "$c_trocado")"; t_trocado="$(tenta antigo18 "$W/u18.senha")"
seg_depois="$(tela -b "$J" "$B/seguranca")"; em_dia="$(tem 'Todas as senhas estão gravadas com o custo do porte atual')"; ainda="$(tem 'custo anterior')"
lista_depois="$(acima_do_custo "$m_ini")"
if [[ -z "$ja_estavam" ]]; then
  [[ "$em_dia" == 1 && "$ainda" == 0 ]]; depois_ok=$?
else
  [[ "$em_dia" == 0 && "$(tem_fixo "<strong>$(quantos "$ja_estavam") usuário(s) com a senha gravada com o custo anterior</strong>: $ja_estavam. ")" == 1 ]]; depois_ok=$?
fi
[[ "$m_ini" == "$m_esperada" && "$m_ini" -lt 8192 && "$r_painel" == 303* && "$r_mu" == 0 && "$(memoria_do_custo "$c_painel")" == "$m_ini" \
  && "$(memoria_do_custo "$c_mu")" == "$m_ini" && "$m_antigo" == 8192 \
  && "$t_antigo" == "0 226 "* && "$t_novo" == "0 226 "* && "$seg_antes" == "200 " && "$avisa" == 1 && "$hash_tela" == 0 && "$r_troca" == 303* \
  && "$m_trocado" == "$m_ini" && "$t_trocado" == "0 226 "* && "$seg_depois" == "200 " && "$depois_ok" == 0 \
  && ", $lista_antes, " == *", antigo18, "* && "$lista_depois" == "$ja_estavam" && ", $ja_estavam, " != *", antigo18, "* ]]
caso $? seguranca 80 "Custo da senha do FTP acompanha o porte, com aviso das senhas antigas" "FTP_MAX_CLIENTS=$clientes, memória esperada por conferência: 65536 / $clientes = $m_esperada KiB · argon2id do usuário inicial: $c_ini · criado pelo painel ($r_painel): $c_painel · criado pelo manage-user.sh (saída $r_mu): $c_mu · gravado como até a 0.18.0, sem a opção: $c_antigo · login certo com o custo antigo: $(dur "$t_antigo"); com o atual: $(dur "$t_novo") · já estavam no cadastro com o custo de um porte menor: ${ja_estavam:-ninguém} · aba Segurança com o antigo no cadastro: $seg_antes, aviso com exatamente os nomes acima do custo atual ($lista_antes): $avisa, hash ou parâmetro na tela: $hash_tela · troca da senha dele pelo painel ($r_troca): $c_trocado, login $(dur "$t_trocado") · aba Segurança depois: $seg_depois, \"todas com o custo do porte atual\": $em_dia, linhas com aviso: $ainda, acima do custo atual no cadastro: ${lista_depois:-ninguém}"
achado seguranca "Custo do argon2id das senhas do FTP" "Sem a opção -C, o pure-pw supõe 8 logins ao mesmo tempo e grava $c_antigo: o login inteiro, com uma conferência de senha, levou $(dur "$t_antigo") nesta máquina. Com -C FTP_MAX_CLIENTS ($clientes) ele grava m=$m_ini (65536 / $clientes, em KiB) e o login levou $(dur "$t_novo"). O número de passadas (t) o pure-pw calibra a cada gravação, pelo tempo que o hash leva naquele momento: por isso ele varia de um usuário para outro. A senha já gravada só muda de custo quando é trocada; a aba Segurança lista quem ainda está com o custo anterior."

# ------------------------------------------------------------------ cadastro e segredos fora do alcance da web
alvos=(/auth/pureftpd.passwd /auth/pureftpd.pdb /pureftpd.passwd /painel/administradores /painel/auditoria.log /auditoria.log
  /.env /.secrets/ftp-usuario-inicial-senha.txt /run/secrets/painel_admin_inicial_senha_hash /.git/config /compose.yaml /nginx/tls/painel-key.pem
  /etc/passwd /proc/self/environ /marca/../../auth/pureftpd.passwd /%2e%2e/%2e%2e/auth/pureftpd.passwd /arquivos/..%2f..%2fauth/pureftpd.passwd)
entregou=0; vazou=0; ev_sem=""; ev_com=""
for alvo in "${alvos[@]}"; do
  sem="$(tela --path-as-is "$B$alvo")"; vazou=$((vazou + $(tem 'argon2id|scrypt\$|BEGIN |root:x:|FTP_USER=')))
  com="$(tela --path-as-is -b "$J" "$B$alvo")"; vazou=$((vazou + $(tem 'argon2id|scrypt\$|BEGIN |root:x:|FTP_USER=')))
  [[ "${sem%% *}" =~ ^(303|400|404)$ && "${com%% *}" =~ ^(400|404)$ ]] || entregou=$((entregou + 1))
  ev_sem+="${sem%% *} "; ev_com+="${com%% *} "
done
telas=0; com_hash=0
for rota in "${ROTAS18[@]}"; do
  [[ "$rota" == GET* ]] || continue
  r="$(tela --path-as-is -b "$J" "$B${rota#* }?usuario=equip18&admin=$ADMIN")"; [[ "$r" == 200* ]] && telas=$((telas + 1))
  com_hash=$((com_hash + $(tem 'argon2id|scrypt\$[0-9]|\$7\$|m=[0-9]+,t=[0-9]+')))
done
[[ "$e_adm" == 303 && "$entregou" == 0 && "$vazou" == 0 && "$telas" -ge 10 && "$com_hash" == 0 ]]
caso $? seguranca 77 "Cadastro e segredos fora do alcance da web" "${#alvos[@]} endereços pedidos sem normalizar o caminho (cadastro do FTP, administradores, auditoria, .env, .secrets, /run/secrets, .git, compose.yaml, chave do TLS, /etc/passwd, /proc/self/environ e caminhos que sobem de pasta) · sem sessão: $ev_sem· com sessão de administrador: $ev_com· respostas fora de 303, 400 e 404: $entregou · linhas de hash, chave, /etc/passwd ou .env nas respostas: $vazou · telas do administrador abertas com sessão (as de usuário, com equip18): $telas, linhas com hash ou parâmetro de hash nelas: $com_hash"

# ------------------------------------------------------------------ senha do usuário inicial: a do segredo, a cada subida
soma_antes="$(somas)"; cp -p "$S/ftp-usuario-inicial-senha.txt" "$W/r18.segredo"; nova_senha "$W/inicial18.senha"
cat "$W/inicial18.senha" > "$S/ftp-usuario-inicial-senha.txt"
dc restart ftp > /dev/null 2>&1; esperar "$FTP"; s_1="$(saude "$FTP")"
r_nova="$(tenta "$USUARIO" "$W/inicial18.senha")"; r_velha="$(tenta "$USUARIO" "$W/inicial.senha")"; c_reaplicado="$(custo "$USUARIO")"
cat "$W/r18.segredo" > "$S/ftp-usuario-inicial-senha.txt"; rm -f "$W/r18.segredo"
dc restart ftp > /dev/null 2>&1; esperar "$FTP"; s_2="$(saude "$FTP")"
r_volta="$(tenta "$USUARIO" "$W/inicial.senha")"; r_trocada="$(tenta "$USUARIO" "$W/inicial18.senha")"; r_outro="$(tenta equip18 "$W/u18.senha")"
[[ "$s_1" == "healthy " && "$r_nova" == "0 226 "* && "$r_velha" == "67 530 "* && "$c_reaplicado" == "$c_ini" && "$s_2" == "healthy " \
  && "$r_volta" == "0 226 "* && "$r_trocada" == "67 530 "* && "$r_outro" == "0 226 "* && "$soma_antes" == "$(somas)" ]]
caso $? testes 38 "Senha do usuário inicial reaplicada do segredo a cada subida" "senha nova gravada em .secrets/ftp-usuario-inicial-senha.txt e docker compose restart ftp: $s_1· login com a nova: ${r_nova% *} · com a anterior: ${r_velha% *} · argon2id regravado: $c_reaplicado · arquivo de volta ao que era e novo reinício: $s_2· login com a de antes: ${r_volta% *} · com a que saiu: ${r_trocada% *} · outro usuário (equip18) não muda: ${r_outro% *} · segredos iguais aos do início: $([[ "$soma_antes" == "$(somas)" ]] && echo sim || echo NÃO)"

# ------------------------------------------------------------------ cadastro fora do alcance de quem entra no FTP
ev=""; levou=0
for alvo in /auth/pureftpd.passwd /auth/pureftpd.pdb /painel/administradores /run/secrets/ftp_usuario_inicial_senha /etc/ssl/private/pure-ftpd.pem /proc/self/environ \
  %2e%2e/%2e%2e/auth/pureftpd.passwd %2e%2e/auth/pureftpd.passwd; do
  rm -f "$W/r18.furto"
  r="$(ftp_curl tls equip18 "$W/u18.senha" --path-as-is -o "$W/r18.furto" "$F/$alvo")"; resp="$(resposta '(4|5)' | cut -c1-3)"
  [[ "$r" != 0 && ! -s "$W/r18.furto" ]] || levou=$((levou + 1))
  ev+="$alvo: curl $r (${resp:-sem resposta}) · "
done
r_pasta="$(ftp_curl tls equip18 "$W/u18.senha" "$F//auth/")"; resp_pasta="$(resposta '(4|5)' | cut -c1-3)"
r_raiz="$(ftp_curl tls equip18 "$W/u18.senha" "$F/")"; do_cadastro="$(grep -a -c -E 'pureftpd|administradores|auth' "$W/curl.out")"
rm -f "$W/r18.furto"
[[ "$levou" == 0 && "$r_pasta" != 0 && "$r_raiz" == 0 && "$do_cadastro" == 0 ]]
caso $? seguranca 78 "Cadastro fora do alcance de quem entra no FTP" "usuário equip18, com a senha certa e TLS, pedindo por caminho absoluto e subindo de pasta: ${ev}arquivos entregues: $levou · lista de /auth: curl $r_pasta (${resp_pasta:-sem resposta}) · lista da pasta dele: curl $r_raiz, linhas com nome de arquivo do cadastro: $do_cadastro"

# ------------------------------------------------------------------ cadastro fora do alcance dos outros containers e do host
D18="$(env_file="$ENVA" env_valor DATA_DIR)"
montagens() { docker inspect -f '{{range .Mounts}}{{.Destination}}({{if .RW}}rw{{else}}ro{{end}}) {{end}}' "$1" 2>/dev/null; }
m_nginx="$(montagens "$NGINX")"; m_ftp="$(montagens "$FTP")"; m_painel="$(montagens "$PAINEL")"
ve_nginx="$(docker exec "$NGINX" sh -c 'ls -d /auth /painel /data /run/secrets 2>/dev/null | wc -l')"; ve_ftp="$(docker exec "$FTP" sh -c 'ls -d /painel /nginx 2>/dev/null | wc -l')"
modos_ftp="$(docker exec "$FTP" stat -c '%n %U:%G %a' /auth /auth/pureftpd.passwd /auth/pureftpd.pdb 2>&1 | tr '\n' ' ')"
modos_painel="$(docker exec "$PAINEL" stat -c '%n %U:%G %a' /painel /painel/administradores /painel/auditoria.log 2>&1 | tr '\n' ' ')"
tipos_ftp="$(docker exec "$FTP" cut -d: -f2 /auth/pureftpd.passwd | cut -d '$' -f 2 | sort -u | tr '\n' ' ')"
tipos_painel="$(docker exec "$PAINEL" cut -d: -f2 /painel/administradores | cut -d '$' -f 1 | sort -u | tr '\n' ' ')"
if [[ "$(id -u)" == 0 ]]; then
  no_host="bateria rodando como root: leitura pelo host não se aplica"; negados=4
else
  negados=0
  for pasta in auth painel certs nginx; do ls "$D18/$pasta" > /dev/null 2>&1 || negados=$((negados + 1)); done
  cat "$D18/auth/pureftpd.passwd" > /dev/null 2>&1 && negados=0
  no_host="usuário comum do host (uid $(id -u)) lendo DATA_DIR/auth, painel, certs e nginx: $negados de 4 recusadas"
fi
escutas() { # <container> → portas TCP em escuta, fora o DNS interno do Docker (127.0.0.11)
  local porta saida=""
  for porta in $(docker exec "$1" sh -c 'cat /proc/net/tcp /proc/net/tcp6 2>/dev/null' | awk '$4 == "0A" && $2 !~ /^0B00007F:/ {split($2, p, ":"); print p[2]}' | sort -u); do
    saida+="$((16#$porta)) "
  done
  echo "${saida:-nenhuma }"
}
e_ftp="$(escutas "$FTP")"; e_painel="$(escutas "$PAINEL")"; e_nginx="$(escutas "$NGINX")"; publica="$(docker port "$PAINEL" 2>/dev/null | wc -l)"
[[ "$m_nginx" == "/nginx(ro) " && "$m_ftp" != */painel* && "$ve_nginx" == 0 && "$ve_ftp" == 0 \
  && "$modos_ftp" == "/auth root:root 750 /auth/pureftpd.passwd root:root 600 /auth/pureftpd.pdb root:root 600 " \
  && "$modos_painel" == "/painel root:root 700 /painel/administradores root:root 600 /painel/auditoria.log root:root 600 " \
  && "$tipos_ftp" == "argon2id " && "$tipos_painel" == "scrypt " && "$negados" == 4 && "$e_ftp" == "$FTP_PORTA " && "$e_painel" == "nenhuma " && "$e_nginx" == "8443 " && "$publica" == 0 ]]
caso $? seguranca 79 "Cadastro fora do alcance dos outros containers e do host" "montagens do nginx: $m_nginx· do ftp: $m_ftp· do painel: $m_painel· pastas /auth, /painel, /data e /run/secrets dentro do nginx: $ve_nginx · /painel e /nginx dentro do ftp: $ve_ftp · $modos_ftp· $modos_painel· formato das senhas no cadastro do FTP: $tipos_ftp· no dos administradores: $tipos_painel· $no_host · portas em escuta (fora o DNS interno do Docker): ftp $e_ftp· painel $e_painel· nginx $e_nginx· portas publicadas pelo painel: $publica"

# ------------------------------------------------------------------ senha aleatória e exaustão: FTP
limite="$(docker exec "$FTP" printenv FTP_MAX_CLIENTS_PER_IP)"; rajada=$((limite - 1)); pids=()
s_certa="$(tenta "$USUARIO" "$W/inicial.senha")"
: > "$W/r18.rajada"; t0="$(date +%s%N)"
for ((i = 1; i <= rajada; i++)); do aleatoria "$W/r18.s$i"; tenta "$USUARIO" "$W/r18.s$i" >> "$W/r18.rajada" & pids+=($!); done
sleep 0.3; no_meio="$(tenta "$USUARIO" "$W/inicial.senha")"
wait "${pids[@]}"; t_rajada="$(ms "$t0")"
entraram="$(grep -c -v '^67 530 ' "$W/r18.rajada")"; recusadas="$(grep -c '^67 530 ' "$W/r18.rajada")"
ev_existe=""; ev_falta=""
for i in 1 2 3; do
  aleatoria "$W/r18.s0"
  r="$(tenta "$USUARIO" "$W/r18.s0")"; ev_existe+="$(dur "$r"), "; [[ "$r" == "67 530 "* ]] || entraram=$((entraram + 1))
  r="$(tenta "ninguem18$i" "$W/r18.s0")"; ev_falta+="$(dur "$r"), "; [[ "$r" == "67 530 "* ]] || entraram=$((entraram + 1))
done
depois="$(tenta "$USUARIO" "$W/inicial.senha")"
# A mesma rajada em um usuário com a senha gravada como até a 0.18.0, para a comparação (só evidência).
antigo antigo18r "$W/u18b.senha"; pids=()
for ((i = 1; i <= rajada; i++)); do tenta antigo18r "$W/r18.s$i" > /dev/null & pids+=($!); done
sleep 0.3; no_meio_antigo="$(tenta antigo18r "$W/u18b.senha")"
wait "${pids[@]}"; mu del antigo18r
s_ftp="$(saude "$FTP")"
[[ "$s_certa" == "0 226 "* && "$recusadas" == "$rajada" && "$entraram" == 0 && "$no_meio" == "0 226 "* && "$(tempo_de "$no_meio")" -lt 25 && "$depois" == "0 226 "* && "$s_ftp" == "healthy " ]]
caso $? seguranca 71 "Senha aleatória no FTP não entra nem segura quem tem a senha" "login certo sozinho: $(dur "$s_certa") · $rajada senhas aleatórias ao mesmo tempo no usuário $USUARIO, de um só endereço (FTP_MAX_CLIENTS_PER_IP=$limite): $recusadas recusadas com 530, em $(seg "$t_rajada") · login certo no meio da rajada: ${no_meio% *}, em $(dur "$no_meio") (limite do caso: 25 s) · mais 6 senhas aleatórias, uma por vez, com nome que existe e nome que não existe: entraram $entraram · login certo depois: ${depois% *}, em $(dur "$depois") · a mesma rajada em um usuário com a senha gravada como até a 0.18.0 (m=8192): login certo no meio em $(dur "$no_meio_antigo") · FTP: $s_ftp"
achado seguranca "Tempo de recusa no FTP" "Recusa de senha errada, três medidas de cada: ${ev_existe%, } para um nome que existe e ${ev_falta%, } para um nome que não existe. O pure-ftpd só confere a senha (argon2id) quando o nome está no cadastro, e a espera que ele faz antes de recusar varia de uma tentativa para a outra: a diferença entre os dois casos fica menor que essa variação, mas não é zero, e quem repete a medida muitas vezes pode chegar a saber se um nome existe. O que protege a conta é a senha, de 12 caracteres ou mais, e a rede: FTP só para os endereços que precisam, no firewall do host."
achado seguranca "Senha errada no FTP" "O pure-ftpd não bloqueia endereço por tentativa: cada senha errada custa ao atacante a espera do servidor (${ev_existe%%,*}) e uma das $limite sessões que o endereço dele pode abrir. Com a senha gravada como até a 0.18.0, $rajada tentativas ao mesmo tempo seguraram o login certo por $(dur "$no_meio_antigo") nesta máquina; com o custo atual, $(dur "$no_meio")."

# ------------------------------------------------------------------ exaustão: rajada de conexões no FTP
abertas=(); aceitas=0; negadas=0; ultima=""; antes_r="$(reinicios)"; sleep 2
for ((i = 0; i < 60; i++)); do
  { exec {fd}<>"/dev/tcp/$IP/$FTP_PORTA"; } 2>/dev/null || continue
  abertas+=("$fd"); r="$(ftp_ler "$fd")"
  case "$r" in 220*) aceitas=$((aceitas + 1)) ;; 421*) negadas=$((negadas + 1)); ultima="$r" ;; esac
done
for fd in "${abertas[@]}"; do exec {fd}>&-; done; sleep 3
depois="$(tenta "$USUARIO" "$W/inicial.senha")"; s_ftp="$(saude "$FTP")"
[[ "${#abertas[@]}" == 60 && "$aceitas" == "$limite" && "$negadas" == $((60 - limite)) && "$depois" == "0 226 "* && "$s_ftp" == "healthy " && "$antes_r" == "$(reinicios)" ]]
caso $? seguranca 76 "Rajada de conexões no FTP não derruba o serviço" "60 conexões abertas de uma vez, de um só endereço, sem login: $aceitas aceitas (220), $negadas recusadas ($ultima) · fechadas, login certo: ${depois% *}, em $(dur "$depois") · FTP: $s_ftp· reinícios dos containers antes e depois: $antes_r/ $(reinicios)"

# ------------------------------------------------------------------ senha aleatória: painel
dc restart painel > /dev/null 2>&1; painel_de_pe
auditoria; f0="$(eventos entrada_falha)"; b0="$(eventos entrada_bloqueada)"; o0="$(eventos entrada_ok)"
ev=""; sessoes=0; recusas=0
for nome in "$ADMIN" "$USUARIO" ninguem18 equip18 "$ADMIN"; do
  aleatoria "$W/r18.p"; r="$(COMO="$nome" entrar "$W/r18.jar" "$W/r18.p")"; ev+="$nome $r · "
  [[ "$r" == 401 ]] && recusas=$((recusas + 1))
  sessoes=$((sessoes + $(grep -c -i '^set-cookie: __Host-sessao=[A-Za-z0-9_-]' "$W/entrada.cab")))
done
t0="$(date +%s%N)"; bloqueadas=0
for i in $(seq 1 20); do
  aleatoria "$W/r18.p"; r="$(entrar "$W/r18.jar" "$W/r18.p")"
  [[ "$r" == 429 && "$(grep -c 'Muitas tentativas' "$W/entrada.corpo")" == 1 ]] && bloqueadas=$((bloqueadas + 1))
  sessoes=$((sessoes + $(grep -c -i '^set-cookie: __Host-sessao=[A-Za-z0-9_-]' "$W/entrada.cab")))
done
t_bloqueio="$(ms "$t0")"
r_certa="$(entrar "$W/r18.jar" "$W/painel.senha")"
ev_cookie=""; for i in 1 2 3; do ev_cookie+="$(c -o /dev/null -w '%{http_code}' -b "__Host-sessao=$(inventado)" "$B/usuarios") "; done
auditoria; f1=$(( $(eventos entrada_falha) - f0 )); b1=$(( $(eventos entrada_bloqueada) - b0 )); o1=$(( $(eventos entrada_ok) - o0 ))
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
[[ "$recusas" == 5 && "$sessoes" == 0 && "$bloqueadas" == 20 && "$t_bloqueio" -lt 20000 && "$r_certa" == 429 && "$ev_cookie" == "303 303 303 " \
  && "$f1" == 5 && "$b1" == 21 && "$o1" == 0 && "$e_adm" == 303 ]]
caso $? seguranca 72 "Senha aleatória no painel não entra e bloqueia o endereço" "5 senhas aleatórias, com nome de administrador, de usuário do FTP e nome que não existe: $ev· 20 seguintes: $bloqueadas com 429 e \"Muitas tentativas\", em $(seg "$t_bloqueio") no total (sem conferência de senha) · senha certa durante o bloqueio: $r_certa · sessões abertas: $sessoes · 3 cookies de sessão inventados em /usuarios: $ev_cookie· auditoria: entrada_falha +$f1, entrada_bloqueada +$b1, entrada_ok +$o1 · depois do reinício do painel, senha certa: $e_adm"

# ------------------------------------------------------------------ exaustão: rajada de pedidos no painel
antes_r="$(reinicios)"; sleep 3
curl -sk --max-time 40 --parallel --parallel-immediate --parallel-max 40 -o /dev/null -w '%{http_code}\n' "$B/entrar?n=[1-300]" 2> /dev/null > "$W/r18.codigos"
n200="$(grep -c '^200$' "$W/r18.codigos")"; n429="$(grep -c '^429$' "$W/r18.codigos")"; outros_c="$(grep -v -E '^(200|429)$' "$W/r18.codigos" | sort | uniq -c | tr '\n' ' ')"
sleep 4; r_depois="$(c -o /dev/null -w '%{http_code}' "$B/entrar")"; r_sessao="$(aba -b "$J" "$B/usuarios")"; s_todos="$(saude "$FTP" "$PAINEL" "$NGINX")"; uso="$(memoria)"
cheio="$(printf '%s\n' "$uso" | tr ' ' '\n' | grep '%' | tr -d '%' | awk '$1 >= 90' | wc -l)"
[[ "$n200" -ge 1 && "$n429" -ge 1 && $((n200 + n429)) == 300 && "$r_depois" == 200 && "$r_sessao" == "200 " && "$s_todos" == "healthy healthy healthy " && "$antes_r" == "$(reinicios)" && "$cheio" == 0 ]]
caso $? seguranca 73 "Rajada de pedidos não derruba o painel" "300 pedidos a /entrar, 40 ao mesmo tempo, de um só endereço: $n200 atendidos (200), $n429 recusados pelo nginx (429), outros códigos: ${outros_c:-nenhum} · 4 s depois: /entrar $r_depois, sessão do administrador em /usuarios: $r_sessao· saúde: $s_todos· reinícios antes e depois: $antes_r/ $(reinicios)· memória usada do limite de cada container: $uso"

# ------------------------------------------------------------------ exaustão: pedidos grandes ou malformados
head -c 9000 /dev/zero | tr '\0' a > "$W/r18.9k"; head -c 200000 /dev/zero | tr '\0' a > "$W/r18.200k"
muitos=(); for i in $(seq 1 200); do muitos+=(-H "X-T$i: $i"); done
ev=""; atendidos=0; sleep 2
pede18() { # <nome> <opções do curl...>: pedido que o painel tem de recusar sem cair
  local nome="$1" r; shift
  r="$(c -o /dev/null -w '%{http_code}' "$@")"
  [[ "$r" =~ ^(4[0-9][0-9]|501)$ ]] || atendidos=$((atendidos + 1))
  ev+="$nome $r · "
}
pede18 "corpo de 9 mil bytes" -H "Origin: $B" --data-binary "@$W/r18.9k" "$B/entrar"
pede18 "corpo de 200 mil bytes" -H "Origin: $B" --data-binary "@$W/r18.200k" "$B/entrar"
pede18 "corpo em pedaços (chunked)" -H "Origin: $B" -H 'Transfer-Encoding: chunked' --data-binary "@$W/r18.9k" "$B/entrar"
pede18 "endereço de 9 mil bytes" "$B/entrar?$(cat "$W/r18.9k")"
pede18 "cabeçalho de 9 mil bytes" -H "X-Teste: $(cat "$W/r18.9k")" "$B/entrar"
pede18 "200 cabeçalhos" "${muitos[@]}" "$B/entrar"
pede18 "PUT" -X PUT "$B/entrar"
pede18 "DELETE" -X DELETE "$B/"
pede18 "TRACE" -X TRACE "$B/"
pede18 "método inventado" -X ABCDEFGHIJ "$B/"
pede18 "HTTP sem TLS na porta do HTTPS" "http://$IP:$PAINEL_PORTA/entrar"
cru18() { # <nome> <texto do pedido>
  local r; r="$(http_cru "$2")"
  [[ "$r" =~ ^(4[0-9][0-9]|501)$ ]] || atendidos=$((atendidos + 1))
  ev+="$1 ${r:-sem resposta} · "
}
cru18 "sem Host" 'GET /entrar HTTP/1.1\r\n\r\n'
cru18 "linha de pedido inválida" 'LIXO\r\n\r\n'
cru18 "Content-Length negativo" "POST /entrar HTTP/1.1\r\nHost: $IP:$PAINEL_PORTA\r\nContent-Length: -5\r\n\r\n"
cru18 "Content-Length repetido" "POST /entrar HTTP/1.1\r\nHost: $IP:$PAINEL_PORTA\r\nContent-Length: 5\r\nContent-Length: 6\r\n\r\nabcde"
sleep 2; r_depois="$(c -o /dev/null -w '%{http_code}' "$B/entrar")"; s_todos="$(saude "$FTP" "$PAINEL" "$NGINX")"
erros="$(docker logs --since "$INICIO18" "$PAINEL" 2>&1 | grep -c -E 'Traceback|erro ao atender')"
[[ "$atendidos" == 0 && "$r_depois" == 200 && "$s_todos" == "healthy healthy healthy " && "$erros" == 0 ]]
caso $? seguranca 75 "Pedido grande ou malformado é recusado sem derrubar o painel" "${ev}respostas fora de 4xx e 501: $atendidos · depois: /entrar $r_depois · saúde: $s_todos· erros e Traceback no log do painel desde o início da etapa: $erros"

# ------------------------------------------------------------------ exaustão: conexões lentas e paradas
antes_r="$(reinicios)"
# Quem alimenta o openssl segura a conexão aberta sem mandar o resto: é o nginx que tem de fechar.
( t0="$(date +%s%N)"; { exec {fd}<>"/dev/tcp/$IP/$PAINEL_PORTA"; } 2>/dev/null; IFS= read -r -t 40 -u "$fd" _; echo "$(ms "$t0")" > "$W/r18.lenta1" ) &
p1=$!
( t0="$(date +%s%N)"; timeout 45 openssl s_client -quiet -connect "$IP:$PAINEL_PORTA" < <(printf 'GET /entrar HTTP/1.1\r\nHost: x\r\n'; exec sleep 28 2> /dev/null) > "$W/r18.resp2" 2> /dev/null
  echo "$(ms "$t0")" > "$W/r18.lenta2" ) &
p2=$!
( t0="$(date +%s%N)"; timeout 45 openssl s_client -quiet -connect "$IP:$PAINEL_PORTA" \
    < <(printf 'POST /entrar HTTP/1.1\r\nHost: %s\r\nOrigin: %s\r\nContent-Length: 500\r\n\r\nabc' "$IP:$PAINEL_PORTA" "$B"; exec sleep 28 2> /dev/null) > "$W/r18.resp3" 2> /dev/null
  echo "$(ms "$t0")" > "$W/r18.lenta3" ) &
p3=$!
wait "$p1" "$p2" "$p3"
l1="$(cat "$W/r18.lenta1" 2>/dev/null || echo 99999)"; l2="$(cat "$W/r18.lenta2" 2>/dev/null || echo 99999)"; l3="$(cat "$W/r18.lenta3" 2>/dev/null || echo 99999)"
atendidas="$(cat "$W/r18.resp2" "$W/r18.resp3" 2>/dev/null | grep -a -c -E '^HTTP/1\.[01] (2|3)')"
abrir 300; n_paradas="${#PAROU[@]}"
durante="$(c -o /dev/null -w '%{http_code}' "$B/entrar") $(aba -b "$J" "$B/usuarios")"
fechar; sleep 2
r_depois="$(c -o /dev/null -w '%{http_code}' "$B/entrar")"; s_todos="$(saude "$FTP" "$PAINEL" "$NGINX")"
reuso="$(docker logs --since "$INICIO18" "$NGINX" 2>&1 | grep -c 'worker_connections are not enough')"
[[ "$l1" -lt 25000 && "$l2" -lt 25000 && "$l3" -lt 25000 && "$atendidas" == 0 && "$n_paradas" -ge 290 && "$durante" == "200 200 " && "$r_depois" == 200 \
  && "$s_todos" == "healthy healthy healthy " && "$antes_r" == "$(reinicios)" ]]
caso $? seguranca 74 "Conexão lenta ou parada é fechada e não ocupa o lugar dos outros" "conexão que não manda nada: fechada pelo nginx em $(seg "$l1") · TLS com cabeçalho que não termina: $(seg "$l2") · TLS com corpo que não chega: $(seg "$l3") (limite do caso: 25 s) · respostas 2xx ou 3xx a esses pedidos: $atendidas · $n_paradas conexões paradas de uma vez, de um só endereço: /entrar e /usuarios com sessão durante: $durante· depois de fechadas: $r_depois · saúde: $s_todos· reinícios antes e depois: $antes_r/ $(reinicios)"
achado seguranca "Conexões paradas no nginx" "O nginx do painel aceita 256 conexões (worker_connections). Com 300 paradas de um só endereço ele registrou $reuso vez(es) \"worker_connections are not enough, reusing connections\": fecha as conexões ociosas mais antigas para atender as novas, e o pedido normal seguiu respondendo. Cada conexão parada cai sozinha em 15 s."

# ------------------------------------------------------------------ como a etapa deixa a instância
mu del equip18; mu del equip18b; mu del antigo18
rm -f "$W"/r18.* "$W"/u18*.senha "$W/inicial18.senha"
unset -f pede18 cru18 montagens escutas tela tem antigo
