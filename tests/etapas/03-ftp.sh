#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa C: FTP. Login, envio, download, usuários pelo terminal, chroot e recusas.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

head -c 65536 /dev/urandom > "$W/envio.bin"; soma="$(sha256sum < "$W/envio.bin" | cut -c1-64)"
r="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" "$F/")"
[[ "$r" == 0 ]]; caso $? testes 3 "Login por FTPS" "usuário inicial, curl --ssl-reqd: saída $r · $(resposta 230)"

r="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" --disable-epsv -T "$W/envio.bin" "$F/backup.cfg")"; pasv="$(resposta 227)"
gravado="$(docker exec "$FTP" stat -c '%s bytes, dono %U, modo %a' "/data/$USUARIO/backup.cfg" 2>/dev/null)"
[[ "$r" == 0 && "$gravado" == "65536 bytes"* ]]; caso $? testes 4 "Envio de arquivo" "curl -T: saída $r · em DATA_DIR/dados/$USUARIO: ${gravado:-arquivo ausente}"
anunciado=""; porta_dados=0
if [[ "$pasv" =~ \(([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+),([0-9]+)\) ]]; then
  anunciado="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}.${BASH_REMATCH[4]}"; porta_dados=$(( BASH_REMATCH[5] * 256 + BASH_REMATCH[6] ))
fi
[[ "$anunciado" == "$IP" && "$porta_dados" -ge "$PASSIVA" && "$porta_dados" -lt $((PASSIVA + 20)) ]]
caso $? rede 4 "Endereço anunciado" "resposta do PASV: ${pasv:-ausente} · endereço $anunciado (FTP_PASSIVE_IP=$IP) · porta $porta_dados, dentro da faixa $PASSIVA-$((PASSIVA + 19))"
r2="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" --disable-epsv "$F/")"
[[ "$r" == 0 && "$r2" == 0 ]] && grep -q 'backup\.cfg' "$W/curl.out"
caso $? rede 3 "Transferência em modo passivo" "envio com PASV: saída $r · listagem com PASV: saída $r2, arquivo enviado $(grep -q 'backup\.cfg' "$W/curl.out" && echo presente || echo AUSENTE) na listagem"

r="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" -o "$W/volta.bin" "$F/backup.cfg")"; volta="$(sha256sum < "$W/volta.bin" 2>/dev/null | cut -c1-64)"
[[ "$r" == 0 && "$volta" == "$soma" ]]; caso $? testes 5 "Download e comparação" "curl -o: saída $r · sha256 $([[ "$volta" == "$soma" ]] && echo idêntico || echo DIFERENTE) (${soma:0:16}…)"

# Segunda execução do deploy.sh: nada é recriado, senha e dado ficam como estavam.
a_ids="$(ids)"; a_somas="$(somas)"; dep; r=$?
rv="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" -o "$W/volta2.bin" "$F/backup.cfg")"
[[ "$ok10" == 1 && "$r" == 0 && "$a_somas" == "$(somas)" && "$a_ids" == "$(ids)" && "$rv" == 0 ]] && cmp -s "$W/envio.bin" "$W/volta2.bin" && [[ "$(grep -c -E '^(Criado|Gerada)' "$W/deploy.log")" == 0 ]]
caso $? testes 10 "Instalação em um comando" "$ev10 · 2ª execução: saída $r, criados: $(grep -c -E '^(Criado|Gerada)' "$W/deploy.log"), segredos $([[ "$a_somas" == "$(somas)" ]] && echo iguais || echo MUDARAM), containers $([[ "$a_ids" == "$(ids)" ]] && echo 'os mesmos' || echo RECRIADOS), arquivo enviado $(cmp -s "$W/envio.bin" "$W/volta2.bin" && echo idêntico || echo DIFERENTE)"

mu add equip01 "$W/u1.senha"; r_add=$?; mu add equip02 "$W/u2.senha"
mu list; listado="$(grep -c -E '^equip0[12][[:space:]]' "$W/mu.log")"
r_a="$(ftp_curl tls equip01 "$W/u1.senha" -T "$W/envio.bin" "$F/a.cfg")"

r_pwd="$(ftp_curl tls equip01 "$W/u1.senha" -Q "CWD .." -Q "CWD ../../.." -Q PWD "$F/")"; pwd_ftp="$(resposta 257)"
r_etc="$(ftp_curl tls equip01 "$W/u1.senha" -o "$W/passwd" "$F//etc/passwd")"; resp_etc="$(resposta 5)"
r_sobe="$(ftp_curl tls equip01 "$W/u1.senha" --path-as-is -o "$W/passwd" "$F/../../etc/passwd")"
[[ "$r_pwd" == 0 && "$pwd_ftp" == *'"/"'* && "$r_etc" != 0 && "$r_sobe" != 0 && ! -s "$W/passwd" ]]
caso $? seguranca 3 "Fuga do chroot" "depois de CWD .. e CWD ../../..: $pwd_ftp · /etc/passwd: curl saída $r_etc ($resp_etc) · ../../etc/passwd: curl saída $r_sobe · arquivo do sistema recebido: $([[ -s "$W/passwd" ]] && echo SIM || echo não)"

r_l="$(ftp_curl tls equip02 "$W/u2.senha" "$F/")"; ve="$(grep -c 'a\.cfg' "$W/curl.out")"
r_c1="$(ftp_curl tls equip02 "$W/u2.senha" -Q "CWD /data/equip01" "$F/")"; resp_c1="$(resposta 5)"
r_c2="$(ftp_curl tls equip02 "$W/u2.senha" -Q "CWD ../equip01" "$F/")"
r_c3="$(ftp_curl tls equip02 "$W/u2.senha" --path-as-is -o "$W/alheio" "$F/../equip01/a.cfg")"
[[ "$r_a" == 0 && "$r_l" == 0 && "$ve" == 0 && "$r_c1" != 0 && "$r_c2" != 0 && "$r_c3" != 0 && ! -s "$W/alheio" ]]
caso $? seguranca 4 "Isolamento entre usuários" "equip02 lista a própria pasta: saída $r_l, arquivos do equip01 à vista: $ve · CWD /data/equip01: curl saída $r_c1 ($resp_c1) · CWD ../equip01: saída $r_c2 · baixar ../equip01/a.cfg: saída $r_c3, arquivo recebido: $([[ -s "$W/alheio" ]] && echo SIM || echo não)"

modo_antes="$(docker exec "$FTP" stat -c %a /data/equip01/a.cfg 2>/dev/null)"
r="$(ftp_curl tls equip01 "$W/u1.senha" -Q "SITE CHMOD 777 a.cfg" "$F/")"; resp="$(resposta 5)"
modo_depois="$(docker exec "$FTP" stat -c %a /data/equip01/a.cfg 2>/dev/null)"
[[ "$r" != 0 && -n "$modo_antes" && "$modo_antes" == "$modo_depois" ]]
caso $? seguranca 6 "SITE CHMOD" "SITE CHMOD 777: curl saída $r ($resp) · modo do arquivo antes $modo_antes, depois $modo_depois"

r_1="$(ftp_curl tls equip01 "$W/u1.senha" "$F/")"; mu passwd equip01 "$W/u3.senha"; r_pw=$?
r_velha="$(ftp_curl tls equip01 "$W/u1.senha" "$F/")"; r_nova="$(ftp_curl tls equip01 "$W/u3.senha" "$F/")"
mu del equip01; r_del=$?; r_fim="$(ftp_curl tls equip01 "$W/u3.senha" "$F/")"
docker exec "$FTP" test -f /data/equip01/a.cfg; pasta=$?
mu del equip02
[[ "$r_add" == 0 && "$listado" == 2 && "$r_1" == 0 && "$r_pw" == 0 && "$r_velha" == 67 && "$r_nova" == 0 && "$r_del" == 0 && "$r_fim" == 67 && "$pasta" == 0 ]]
caso $? testes 6 "Ciclo de usuário pelo terminal" "add: saída $r_add, na lista: $listado de 2, login $r_1 · passwd: saída $r_pw, senha antiga $r_velha, nova $r_nova · del: saída $r_del, login $r_fim · pasta e arquivo depois do del: $([[ "$pasta" == 0 ]] && echo preservados || echo AUSENTES) (curl: 0 = entrou, 67 = login recusado)"

printf 'curta\n' | ENV_FILE="$ENVA" ./manage-user.sh add equip03 > "$W/curta.log" 2>&1; r=$?
[[ "$r" != 0 && " $(usuarios_ftp)" != *" equip03 "* ]] && grep -q 'Senha deve ter pelo menos 12 caracteres' "$W/curta.log"
caso $? testes 7 "Senha curta" "manage-user.sh add com 5 caracteres: saída $r · $(grep -o 'Senha deve ter[^"]*' "$W/curta.log" | head -1) · usuário criado: $([[ " $(usuarios_ftp)" == *" equip03 "* ]] && echo SIM || echo não)"

resp="$(ftp_cru "USER $USUARIO")"; r="$(ftp_curl puro "$USUARIO" "$W/inicial.senha" "$F/")"
[[ "$r" != 0 && -n "$resp" && ! "$resp" =~ ^(230|331) ]]
caso $? seguranca 1 "Login sem TLS" "USER em texto puro: $resp · curl sem --ssl-reqd: saída $r"

r="$(ftp_curl tls anonymous "$W/anonimo.senha" "$F/")"; resp="$(resposta '[45]')"
[[ "$r" == 67 ]]; caso $? seguranca 2 "Login anônimo" "usuário anonymous por FTPS: curl saída $r ($resp)"

r="$(ftp_curl tls "$USUARIO" "$W/errada.senha" "$F/")"; resp="$(resposta 530)"
[[ "$r" == 67 && "$resp" == 530* ]]; caso $? seguranca 5 "Senha errada" "curl saída $r · $resp"

# Modo 2: só --ftp-ssl-control mede "TLS no login, dados sem proteção" (junto com --ssl-reqd, o curl protege tudo).
m2_claro="$(ftp_curl controle "$USUARIO" "$W/inicial.senha" -o "$W/claro.bin" "$F/backup.cfg")"; m2_resp="$(resposta '(150|226|4|5)')"
m2_tls="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" -o "$W/claro.bin" "$F/backup.cfg")"

limite="$(env_file="$ENVA" env_valor FTP_MAX_CLIENTS_PER_IP 8)"; abertas=(); aceitas=0; sleep 2
for ((i = 1; i <= limite; i++)); do
  { exec {fd}<>"/dev/tcp/$IP/$FTP_PORTA"; } 2>/dev/null || continue
  abertas+=("$fd"); [[ "$(ftp_ler "$fd")" == 220* ]] && aceitas=$((aceitas + 1))
done
excedente="$(ftp_cru)"
for fd in "${abertas[@]}"; do exec {fd}>&-; done
[[ "$aceitas" == "$limite" && "$excedente" == 421* ]]
caso $? rede 5 "Limite de sessões por IP" "FTP_MAX_CLIENTS_PER_IP=$limite: $aceitas sessões aceitas (220) · a seguinte: $excedente"
