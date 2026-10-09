#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa I: backup e restauração.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

copias="$T/copias"
# A cópia é cifrada: quem abre é o age da imagem, com a chave privada da instância de teste.
abrir_copia() { # <arquivo> <chave privada> <comando que lê o tar da entrada padrão...>
  local arquivo="$1" chave="$2"; shift 2
  docker run --rm -i --network none --read-only --cap-drop ALL --security-opt no-new-privileges:true \
    --user "$(id -u):$(id -g)" -v "$chave":/run/secrets/backup_chave:ro --entrypoint bash "$IMG_FTP" \
    -c 'set -o pipefail; age -d -i /run/secrets/backup_chave 2>/dev/null | "$@"' abrir "$@" < "$arquivo"
}
restaurar() { ENV_FILE="$ENVA" ./scripts/restaurar.sh "$1" --sim < /dev/null > "$2" 2>&1; }
no_ar_igual() { [[ "$1" == "$(ids)" && "$(saude "$FTP" "$PAINEL" "$NGINX")" == "healthy healthy healthy " ]] && echo 'instância intacta' || echo 'instância ALTERADA'; }
r_e="$(ftp_curl tls equip09 "$W/u6.senha" -T "$W/envio.bin" "$F/copia.cfg")"
ENV_FILE="$ENVA" ./scripts/backup.sh < /dev/null > "$W/backup.log" 2>&1; r_bk=$?
copia="$(sed -n 's/^Cópia gravada: \(.*\.tar\.gz\.age\) (.*/\1/p' "$W/backup.log")"
modos="$(stat -c '%a' "$copias" "$copia" "$copia.sha256" 2>/dev/null | tr '\n' ' ')"
abrir_copia "$copia" "$S/backup-chave-privada.txt" tar -tzf - > "$W/copia.lista" 2>/dev/null
de_fora="$(grep -c -v -E '^(dados|auth|certs|painel)(/|$)' "$W/copia.lista" || true)"
# Hash não é senha em texto: o dos administradores do painel entra na cópia, como o dos usuários do FTP.
senhas="$(abrir_copia "$copia" "$S/backup-chave-privada.txt" tar -xzOf - 2>/dev/null | grep -c -a -F -f <(grep -v '^scrypt\$' "$W/proibidos") || true)"
# Depois da cópia: o arquivo é apagado, o usuário é removido e entra um usuário que a cópia não tem.
r_dele="$(ftp_curl tls equip09 "$W/u6.senha" -Q "DELE copia.cfg" "$F/")"
mu del equip09; r_del=$?
nova_senha "$W/u9.senha"; mu add equip10 "$W/u9.senha"
r_sem="$(ftp_curl tls equip09 "$W/u6.senha" "$F/")"; r_novo="$(ftp_curl tls equip10 "$W/u9.senha" "$F/")"
# Cópia adulterada: recusada pela soma antes de qualquer alteração.
{ cat "$copia"; printf 'x'; } > "$copias/adulterada.tar.gz.age" 2>/dev/null
sed "s|$(basename "$copia")|adulterada.tar.gz.age|" "$copia.sha256" > "$copias/adulterada.tar.gz.age.sha256" 2>/dev/null
a_ids="$(ids)"
restaurar adulterada.tar.gz.age "$W/restaurar-ruim.log"; r_ruim=$?
intacta="$([[ "$a_ids" == "$(ids)" && "$(saude "$FTP" "$PAINEL" "$NGINX")" == "healthy healthy healthy " && " $(usuarios_ftp)" == *" equip10 "* ]] && echo 'instância intacta' || echo 'instância ALTERADA')"
restaurar "$(basename "$copia")" "$W/restaurar.log"; r_rs=$?
saude_rs="$(saude "$FTP" "$PAINEL" "$NGINX")"
r_l="$(ftp_curl tls equip09 "$W/u6.senha" -o "$W/copia.bin" "$F/copia.cfg")"; volta="$(sha256sum < "$W/copia.bin" 2>/dev/null | cut -c1-64)"
r_10="$(ftp_curl tls equip10 "$W/u9.senha" "$F/")"; r_i="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" "$F/")"
de_volta="$(entrar "$J" "$W/painel.senha")"; proibir "$(awk '$6 == "__Host-sessao" {print $7}' "$J")"
anteriores="$(find "$copias" -maxdepth 1 -name '*-antes-da-restauracao.tar.gz.age' 2>/dev/null | wc -l)"
[[ "$r_e" == 0 && "$r_bk" == 0 && -s "$copia" && "$modos" == "700 600 600 " && "$de_fora" == 0 && "$senhas" == 0 \
  && "$r_dele" == 0 && "$r_del" == 0 && "$r_sem" == 67 && "$r_novo" == 0 && "$r_ruim" == 1 && "$intacta" == 'instância intacta' \
  && "$r_rs" == 0 && "$saude_rs" == "healthy healthy healthy " && "$r_l" == 0 && "$volta" == "$soma" && "$r_10" == 67 && "$r_i" == 0 \
  && "$de_volta" == 303 && "$anteriores" == 1 ]]
caso $? testes 9 "Backup e restauração" "backup.sh: saída $r_bk, $(basename "${copia:-ausente}"), $(grep -c . "$W/copia.lista") itens, modos da pasta, da cópia e da soma: $modos· itens fora de dados, auth, certs e painel: $de_fora · senhas em texto na cópia: $senhas · depois da cópia: arquivo apagado ($r_dele), usuário removido ($r_del, login $r_sem), usuário novo (login $r_novo) · cópia adulterada: saída $r_ruim, $(grep -o 'a soma sha256[^:]*não confere' "$W/restaurar-ruim.log" | sed 's| de .* não| não|' | head -1), $intacta · restaurar.sh: saída $r_rs, saúde $saude_rs· usuário da cópia: login e download $r_l, sha256 $([[ "$volta" == "$soma" ]] && echo idêntico || echo DIFERENTE) · usuário criado depois da cópia: $r_10 (67 = recusado) · usuário inicial: $r_i · painel: $de_volta · estado anterior guardado: $anteriores cópia"

# Cópia cifrada: o arquivo não abre sem a chave, e nada do que há dentro aparece em texto.
cabecalho="$(head -c 21 -- "$copia" 2>/dev/null | tr -d '\0')"
tar -tzf "$copia" > /dev/null 2>&1; r_tar=$?
em_texto="$(grep -c -a -E "pureftpd\.passwd|equip09|$USUARIO/" "$copia" 2>/dev/null || true)"
com_chave="$(grep -c -x -F 'auth/pureftpd.passwd' "$W/copia.lista")"
[[ "$cabecalho" == 'age-encryption.org/v1' && "$r_tar" != 0 && "$em_texto" == 0 && "$com_chave" == 1 && "$(basename "$copia")" == *.tar.gz.age ]]
caso $? seguranca 90 "Cópia de segurança cifrada" "arquivo $(basename "${copia:-ausente}") · cabeçalho: ${cabecalho:-ausente} · tar no host, sem a chave: saída $r_tar (0 = abriria) · nomes de arquivo e de usuário em texto dentro dele: $em_texto · aberta com a chave privada da instância: lista de usuários presente ($com_chave)"

# Sem a chave, com a chave de outra instalação, alterada ou cortada: recusada antes de qualquer troca.
a_ids="$(ids)"
cp -p -- "$S/backup-chave-privada.txt" "$W/chave.guardada"
rm -f -- "$S/backup-chave-privada.txt"
restaurar "$(basename "$copia")" "$W/restaurar-sem-chave.log"; r_semchave=$?
docker run --rm --network none --read-only --cap-drop ALL --entrypoint age-keygen "$IMG_FTP" > "$S/backup-chave-privada.txt" 2>/dev/null
restaurar "$(basename "$copia")" "$W/restaurar-outra-chave.log"; r_outra=$?
cp -p -- "$W/chave.guardada" "$S/backup-chave-privada.txt"
cp -- "$copia" "$copias/alterada.tar.gz.age"
printf 'X' | dd of="$copias/alterada.tar.gz.age" bs=1 seek=$(( $(stat -c '%s' "$copia") / 2 )) conv=notrunc status=none
restaurar alterada.tar.gz.age "$W/restaurar-alterada.log"; r_alterada=$?
head -c $(( $(stat -c '%s' "$copia") / 2 )) -- "$copia" > "$copias/cortada.tar.gz.age"
restaurar cortada.tar.gz.age "$W/restaurar-cortada.log"; r_cortada=$?
intacta="$(no_ar_igual "$a_ids")"
[[ "$r_semchave" == 1 && "$r_outra" == 1 && "$r_alterada" == 1 && "$r_cortada" == 1 && "$intacta" == 'instância intacta' ]] \
  && grep -q 'a chave que a abre não está' "$W/restaurar-sem-chave.log" && grep -q 'não abre com a chave' "$W/restaurar-outra-chave.log" \
  && grep -q 'não abre com a chave' "$W/restaurar-alterada.log" && grep -q 'não abre com a chave' "$W/restaurar-cortada.log" \
  && [[ "$(cat "$W"/restaurar-sem-chave.log "$W"/restaurar-outra-chave.log "$W"/restaurar-alterada.log "$W"/restaurar-cortada.log | grep -c 'Nada foi tocado')" == 4 ]]
caso $? seguranca 91 "Cópia só abre com a chave certa e inteira" "restaurar.sh sem a chave privada: saída $r_semchave · com a chave de outra instalação: $r_outra · com um byte trocado no meio, sem arquivo .sha256: $r_alterada · cortada pela metade: $r_cortada · as quatro com \"Nada foi tocado\": $(cat "$W"/restaurar-sem-chave.log "$W"/restaurar-outra-chave.log "$W"/restaurar-alterada.log "$W"/restaurar-cortada.log | grep -c 'Nada foi tocado') · $intacta"
rm -f -- "$copias/adulterada.tar.gz.age" "$copias/adulterada.tar.gz.age.sha256" "$copias/alterada.tar.gz.age" "$copias/cortada.tar.gz.age"

# Cópia feita antes da cifra (.tar.gz): continua restaurável, com aviso.
antiga="$copias/$NOME-20000101-000000.tar.gz"
abrir_copia "$copia" "$S/backup-chave-privada.txt" cat > "$antiga" 2>/dev/null
ENV_FILE="$ENVA" ./scripts/restaurar.sh --listar > "$W/listar.log" 2>&1
restaurar "$(basename "$antiga")" "$W/restaurar-antiga.log"; r_antiga=$?
saude_antiga="$(saude "$FTP" "$PAINEL" "$NGINX")"
r_la="$(ftp_curl tls equip09 "$W/u6.senha" -o "$W/copia-antiga.bin" "$F/copia.cfg")"; volta_a="$(sha256sum < "$W/copia-antiga.bin" 2>/dev/null | cut -c1-64)"
guardadas="$(find "$copias" -maxdepth 1 -name '*-antes-da-restauracao.tar.gz.age' 2>/dev/null | wc -l)"
[[ "$r_antiga" == 0 && "$saude_antiga" == "healthy healthy healthy " && "$r_la" == 0 && "$volta_a" == "$soma" && "$guardadas" == 2 ]] \
  && grep -q 'AVISO: esta cópia não é cifrada' "$W/restaurar-antiga.log" && grep -q -F "$(basename "$antiga")  (sem cifra" "$W/listar.log"
caso $? testes 53 "Cópia antiga, sem cifra, ainda restaura" "restaurar.sh com um .tar.gz sem cifra: saída $r_antiga, saúde $saude_antiga· aviso de cópia sem cifra: $(grep -c 'AVISO: esta cópia não é cifrada' "$W/restaurar-antiga.log") · marcada no --listar: $(grep -c '(sem cifra' "$W/listar.log") · download depois dela: $r_la, sha256 $([[ "$volta_a" == "$soma" ]] && echo idêntico || echo DIFERENTE) · estado anterior guardado cifrado: $guardadas cópias"
rm -f -- "$antiga"

# Chaves da cópia: 0600, a privada nunca regravada, a pública sempre tirada dela; sem a pública não há cópia.
modos_chave="$(stat -c '%a' "$S/backup-chave-privada.txt" "$S/backup-chave-publica.txt" 2>/dev/null | tr '\n' ' ')"
soma_privada="$(sha256sum < "$S/backup-chave-privada.txt")"; soma_publica="$(sha256sum < "$S/backup-chave-publica.txt")"
printf 'age1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq\n' > "$S/backup-chave-publica.txt"
ENV_FILE="$ENVA" ./scripts/backup.sh --rotulo chave-trocada < /dev/null > "$W/backup-chave-trocada.log" 2>&1; r_trocada=$?
dep; r_dep=$?
mesma_privada="$([[ "$soma_privada" == "$(sha256sum < "$S/backup-chave-privada.txt")" ]] && echo sim || echo NÃO)"
publica_refeita="$([[ "$soma_publica" == "$(sha256sum < "$S/backup-chave-publica.txt")" ]] && echo sim || echo NÃO)"
geradas="$(grep -c 'Gerada a chave da cópia' "$W/deploy.log")"
mv -- "$S/backup-chave-publica.txt" "$W/publica.guardada"
ENV_FILE="$ENVA" ./scripts/backup.sh --rotulo sem-chave < /dev/null > "$W/backup-sem-chave.log" 2>&1; r_sempub=$?
mv -- "$W/publica.guardada" "$S/backup-chave-publica.txt"
sobras="$(find "$copias" -maxdepth 1 \( -name '*chave-trocada*' -o -name '*sem-chave*' -o -name '*.parcial' \) 2>/dev/null | wc -l)"
[[ "$modos_chave" == "600 600 " && "$r_trocada" == 1 && "$r_dep" == 0 && "$mesma_privada" == sim && "$publica_refeita" == sim && "$geradas" == 0 \
  && "$r_sempub" == 1 && "$sobras" == 0 && "$(saude "$FTP" "$PAINEL" "$NGINX")" == "healthy healthy healthy " ]] \
  && grep -q 'rode ./deploy.sh' "$W/backup-sem-chave.log"
caso $? seguranca 92 "Chaves da cópia de segurança" "modos da privada e da pública: $modos_chave· cópia com a pública trocada por uma inválida: saída $r_trocada · deploy.sh de novo: saída $r_dep, privada a mesma: $mesma_privada, pública refeita a partir dela: $publica_refeita, chaves geradas de novo: $geradas · cópia sem a chave pública: saída $r_sempub, manda rodar o deploy.sh · arquivos de cópia deixados pelas recusas: $sobras"
