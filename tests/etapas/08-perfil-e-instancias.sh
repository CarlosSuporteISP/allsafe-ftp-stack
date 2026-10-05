#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa H: troca de perfil e segunda instância no mesmo host.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

perfil() { sed -n "s/^$1=//p" profiles/medium.env | tail -n 1; }
em_bytes() { case "${1: -1}" in G) echo $(( ${1%G} * 1073741824 )) ;; M) echo $(( ${1%M} * 1048576 )) ;; *) echo "$1" ;; esac; }
limites() { docker inspect -f '{{.HostConfig.Memory}} {{.HostConfig.NanoCpus}} {{.HostConfig.PidsLimit}}' "$FTP" 2>/dev/null; }
esperado="$(em_bytes "$(perfil FTP_MEMORY_LIMIT)") $(awk -v c="$(perfil FTP_CPU_LIMIT)" 'BEGIN { printf "%d", c * 1000000000 }') $(perfil FTP_PIDS_LIMIT)"
faixa=$(( $(perfil FTP_PASSIVE_PORT_END) - $(perfil FTP_PASSIVE_PORT_START) + 1 ))
dep --size medium; r=$?
l1="$(limites)"; p1=$(( $(docker port "$FTP" | wc -l) - 1 )); c1="$(docker exec "$FTP" printenv FTP_MAX_CLIENTS 2>/dev/null)"; i1="$(ids)"
dc up -d > "$W/up.log" 2>&1; r_up=$?
l2="$(limites)"; p2=$(( $(docker port "$FTP" | wc -l) - 1 )); i2="$(ids)"
r_l="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" -o "$W/medium.bin" "$F/backup.cfg")"
[[ "$r" == 0 && "$l1" == "$esperado" && "$p1" == "$faixa" && "$c1" == "$(perfil FTP_MAX_CLIENTS)" && "$r_up" == 0 && "$l2" == "$esperado" && "$p2" == "$faixa" && "$i1" == "$i2" && "$r_l" == 0 ]] \
  && cmp -s "$W/envio.bin" "$W/medium.bin" && [[ "$(env_file="$ENVA" env_valor FTP_PROFILE)" == medium ]]
caso $? rede 7 "Troca de perfil" "deploy.sh --size medium: saída $r, saúde $(saude "$FTP" "$PAINEL" "$NGINX")· memória, CPU e processos do FTP: $l1 (perfil: $esperado) · portas passivas: $p1 de $faixa · FTP_MAX_CLIENTS: $c1 · docker compose up -d em seguida: saída $r_up, mesmos containers: $([[ "$i1" == "$i2" ]] && echo sim || echo NÃO), limites $l2, passivas $p2 · arquivo enviado antes: $(cmp -s "$W/envio.bin" "$W/medium.bin" && echo idêntico || echo DIFERENTE)"

preparar "$ENVB" -b "$((FTP_PORTA + 1))" "$((PAINEL_PORTA + 1))" "$((PASSIVA + 100))" "$SUBREDE_B"
a_ids="$(ids)"
ENV_FILE="$ENVB" ./deploy.sh < /dev/null > "$W/deploy-b.log" 2>&1; r=$?
for arquivo in "$T/segredos-b"/*-senha*.txt; do [[ -f "$arquivo" ]] && proibir "$(head -1 "$arquivo")"; done
tr -d '\r\n' < "$T/segredos-b/ftp-usuario-inicial-senha.txt" > "$W/inicial-b.senha" 2>/dev/null
saude_b="$(saude "$NOME-b" "$NOME-b-painel" "$NOME-b-nginx")"; saude_a="$(saude "$FTP" "$PAINEL" "$NGINX")"
FB="ftp://$IP:$((FTP_PORTA + 1))"
r_b="$(ftp_curl tls "$USUARIO" "$W/inicial-b.senha" "$FB/")"; r_cruzado="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" "$FB/")"
r_a="$(ftp_curl tls equip09 "$W/u6.senha" "$F/")"; r_ab="$(ftp_curl tls equip09 "$W/u6.senha" "$FB/")"
painel_b="$(c -o /dev/null -w '%{http_code}' "https://$IP:$((PAINEL_PORTA + 1))/saude")"
sub_b="$(docker network inspect -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' "$NOME-b-network" 2>/dev/null)"

# Conversão dos nomes antigos, na segunda instância: ela volta aos nomes usados até a 0.9.0 (a variável
# FTP_PUBLIC_IP e os três arquivos *_password*.txt) e o deploy.sh tem de converter sozinho, sem perder nada.
SB="$T/segredos-b"; b_ids="$(docker inspect -f '{{.Id}}' "$NOME-b" "$NOME-b-painel" "$NOME-b-nginx" 2>/dev/null | cut -c1-12 | tr '\n' ' ')"
sed -i 's/^FTP_PASSIVE_IP=/FTP_PUBLIC_IP=/' "$ENVB"
mv "$SB/ftp-usuario-inicial-senha.txt" "$SB/ftp_password.txt"
mv "$SB/painel-admin-inicial-senha.txt" "$SB/painel_password.txt"
mv "$SB/painel-admin-inicial-senha-hash.txt" "$SB/painel_password_hash.txt"
soma_antes="$(cat "$SB/ftp_password.txt" "$SB/painel_password.txt" "$SB/painel_password_hash.txt" | sha256sum | cut -c1-64)"
ENV_FILE="$ENVB" ./deploy.sh --check-only < /dev/null > "$W/migra-conferir.log" 2>&1; r_c=$?
so_aviso="$([[ "$(grep -c '^AVISO: esta instalação usa nomes antigos' "$W/migra-conferir.log")" == 1 && -f "$SB/ftp_password.txt" && "$(grep -c '^FTP_PUBLIC_IP=' "$ENVB")" == 1 && ! -e "$T/copias-b" ]] && echo 'avisa e não altera' || echo 'ALTEROU OU NÃO AVISOU')"
ENV_FILE="$ENVB" ./deploy.sh < /dev/null > "$W/migra.log" 2>&1; r_m=$?
convertidos="$(grep -c '^Convertido: ' "$W/migra.log")"
nomes_b="$(find "$SB" -maxdepth 1 -type f -printf '%f\n' | sort | tr '\n' ' ')"
soma_depois="$(cat "$SB/ftp-usuario-inicial-senha.txt" "$SB/painel-admin-inicial-senha.txt" "$SB/painel-admin-inicial-senha-hash.txt" 2>/dev/null | sha256sum | cut -c1-64)"
copia_env="$(find "$T/copias-b" -mindepth 2 -maxdepth 2 -path '*-antes-da-migracao-de-nomes/env' 2>/dev/null | head -1)"
na_copia="$(find "$T/copias-b" -type f 2>/dev/null | wc -l)"; modo_copia="$(stat -c '%a' "${copia_env:-/nonexistent}" 2>/dev/null)"
r_mb="$(ftp_curl tls "$USUARIO" "$W/inicial-b.senha" "$FB/")"
ftp_curl tls "$USUARIO" "$W/inicial-b.senha" --disable-epsv "$FB/" > /dev/null; pasv_b="$(grep -a -c "^< 227 .*(${IP//./,}," "$W/curl.err")"
[[ "$r_c" == 0 && "$so_aviso" == 'avisa e não altera' && "$r_m" == 0 && "$convertidos" == 4 \
  && "$nomes_b" == "LEIAME.txt ftp-usuario-inicial-senha.txt painel-admin-inicial-senha-hash.txt painel-admin-inicial-senha.txt " \
  && "$soma_antes" == "$soma_depois" && "$(grep -c '^FTP_PASSIVE_IP=' "$ENVB")" == 1 && "$(grep -c '^FTP_PUBLIC_IP=' "$ENVB")" == 0 \
  && "$(env_file="$ENVB" env_valor FTP_PASSIVE_IP)" == "$IP" && -n "$copia_env" && "$na_copia" == 1 && "$modo_copia" == 600 \
  && "$(grep -c '^FTP_PUBLIC_IP=' "$copia_env")" == 1 && "$(segredos_em "$W/migra.log")" == 0 \
  && "$(saude "$NOME-b" "$NOME-b-painel" "$NOME-b-nginx")" == "healthy healthy healthy " && "$r_mb" == 0 && "$pasv_b" -ge 1 ]]
caso $? testes 21 "Conversão dos nomes antigos" "instalação com FTP_PUBLIC_IP e ftp_password.txt, painel_password.txt e painel_password_hash.txt · deploy.sh --check-only: saída $r_c, $so_aviso · deploy.sh: saída $r_m, $convertidos linhas 'Convertido' (a variável e os três arquivos) · pasta de segredos: $nomes_b· conteúdo dos três: $([[ "$soma_antes" == "$soma_depois" ]] && echo idêntico || echo DIFERENTE) · .env: FTP_PASSIVE_IP=$(env_file="$ENVB" env_valor FTP_PASSIVE_IP), linhas com FTP_PUBLIC_IP: $(grep -c '^FTP_PUBLIC_IP=' "$ENVB") · cópia do .env anterior em BACKUP_DIR: $na_copia arquivo, modo ${modo_copia:-ausente} (segredo não é copiado) · senhas na saída: $(segredos_em "$W/migra.log") · saúde: $(saude "$NOME-b" "$NOME-b-painel" "$NOME-b-nginx")· login com a mesma senha: $r_mb · endereço anunciado no passivo: $([[ "$pasv_b" -ge 1 ]] && echo "$IP" || echo OUTRO) · mesmos containers: $([[ "$b_ids" == "$(docker inspect -f '{{.Id}}' "$NOME-b" "$NOME-b-painel" "$NOME-b-nginx" 2>/dev/null | cut -c1-12 | tr '\n' ' ')" ]] && echo sim || echo 'não (recriados)')"

ENV_FILE="$ENVB" ./deploy.sh --remover --apagar-dados --sim < /dev/null >> "$W/deploy-b.log" 2>&1; r_rm=$?
[[ "$r" == 0 && "$saude_b" == "healthy healthy healthy " && "$saude_a" == "healthy healthy healthy " && "$r_b" == 0 && "$r_cruzado" == 67 && "$r_a" == 0 && "$r_ab" == 67 \
  && "$painel_b" == 200 && "$sub_b" == "$SUBREDE_B" && "$r_rm" == 0 && "$a_ids" == "$(ids)" && "$(saude "$FTP" "$PAINEL" "$NGINX")" == "healthy healthy healthy " ]]
caso $? rede 8 "Duas instâncias no mesmo host" "segunda instância ($NOME-b, portas $((FTP_PORTA + 1)) e $((PAINEL_PORTA + 1)), sub-rede $sub_b): deploy.sh saída $r, saúde $saude_b· primeira: saúde $saude_a· login na segunda com a senha dela: $r_b, com a senha da primeira: $r_cruzado · usuário criado na primeira: login nela $r_a, na segunda $r_ab · painel da segunda: $painel_b · remoção da segunda: saída $r_rm, primeira com os mesmos containers: $([[ "$a_ids" == "$(ids)" ]] && echo sim || echo NÃO) (67 = login recusado)"
