#!/usr/bin/env bash
# Etapa I: backup e restauração.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

copias="$T/copias"
r_e="$(ftp_curl tls equip09 "$W/u6.senha" -T "$W/envio.bin" "$F/copia.cfg")"
ENV_FILE="$ENVA" ./scripts/backup.sh < /dev/null > "$W/backup.log" 2>&1; r_bk=$?
copia="$(sed -n 's/^Cópia gravada: \(.*\.tar\.gz\) (.*/\1/p' "$W/backup.log")"
modos="$(stat -c '%a' "$copias" "$copia" "$copia.sha256" 2>/dev/null | tr '\n' ' ')"
tar -tzf "$copia" > "$W/copia.lista" 2>/dev/null
de_fora="$(grep -c -v -E '^(dados|auth|certs|painel)(/|$)' "$W/copia.lista" || true)"
# Hash não é senha em texto: o dos administradores do painel entra na cópia, como o dos usuários do FTP.
senhas="$(tar -xzOf "$copia" 2>/dev/null | grep -c -a -F -f <(grep -v '^scrypt\$' "$W/proibidos") || true)"
# Depois da cópia: o arquivo é apagado, o usuário é removido e entra um usuário que a cópia não tem.
r_dele="$(ftp_curl tls equip09 "$W/u6.senha" -Q "DELE copia.cfg" "$F/")"
mu del equip09; r_del=$?
nova_senha "$W/u9.senha"; mu add equip10 "$W/u9.senha"
r_sem="$(ftp_curl tls equip09 "$W/u6.senha" "$F/")"; r_novo="$(ftp_curl tls equip10 "$W/u9.senha" "$F/")"
# Cópia adulterada: recusada pela soma antes de qualquer alteração.
{ cat "$copia"; printf 'x'; } > "$copias/adulterada.tar.gz" 2>/dev/null
sed "s|$(basename "$copia")|adulterada.tar.gz|" "$copia.sha256" > "$copias/adulterada.tar.gz.sha256" 2>/dev/null
a_ids="$(ids)"
ENV_FILE="$ENVA" ./scripts/restaurar.sh adulterada.tar.gz --sim < /dev/null > "$W/restaurar-ruim.log" 2>&1; r_ruim=$?
intacta="$([[ "$a_ids" == "$(ids)" && "$(saude "$FTP" "$PAINEL" "$NGINX")" == "healthy healthy healthy " && " $(usuarios_ftp)" == *" equip10 "* ]] && echo 'instância intacta' || echo 'instância ALTERADA')"
ENV_FILE="$ENVA" ./scripts/restaurar.sh "$(basename "$copia")" --sim < /dev/null > "$W/restaurar.log" 2>&1; r_rs=$?
saude_rs="$(saude "$FTP" "$PAINEL" "$NGINX")"
r_l="$(ftp_curl tls equip09 "$W/u6.senha" -o "$W/copia.bin" "$F/copia.cfg")"; volta="$(sha256sum < "$W/copia.bin" 2>/dev/null | cut -c1-64)"
r_10="$(ftp_curl tls equip10 "$W/u9.senha" "$F/")"; r_i="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" "$F/")"
de_volta="$(entrar "$J" "$W/painel.senha")"; proibir "$(awk '$6 == "__Host-sessao" {print $7}' "$J")"
anteriores="$(find "$copias" -maxdepth 1 -name '*-antes-da-restauracao.tar.gz' 2>/dev/null | wc -l)"
[[ "$r_e" == 0 && "$r_bk" == 0 && -s "$copia" && "$modos" == "700 600 600 " && "$de_fora" == 0 && "$senhas" == 0 \
  && "$r_dele" == 0 && "$r_del" == 0 && "$r_sem" == 67 && "$r_novo" == 0 && "$r_ruim" == 1 && "$intacta" == 'instância intacta' \
  && "$r_rs" == 0 && "$saude_rs" == "healthy healthy healthy " && "$r_l" == 0 && "$volta" == "$soma" && "$r_10" == 67 && "$r_i" == 0 \
  && "$de_volta" == 303 && "$anteriores" == 1 ]]
caso $? testes 9 "Backup e restauração" "backup.sh: saída $r_bk, $(basename "${copia:-ausente}"), $(grep -c . "$W/copia.lista") itens, modos da pasta, da cópia e da soma: $modos· itens fora de dados, auth, certs e painel: $de_fora · senhas em texto na cópia: $senhas · depois da cópia: arquivo apagado ($r_dele), usuário removido ($r_del, login $r_sem), usuário novo (login $r_novo) · cópia adulterada: saída $r_ruim, $(grep -o 'a soma sha256[^:]*não confere' "$W/restaurar-ruim.log" | sed 's| de .* não| não|' | head -1), $intacta · restaurar.sh: saída $r_rs, saúde $saude_rs· usuário da cópia: login e download $r_l, sha256 $([[ "$volta" == "$soma" ]] && echo idêntico || echo DIFERENTE) · usuário criado depois da cópia: $r_10 (67 = recusado) · usuário inicial: $r_i · painel: $de_volta · estado anterior guardado: $anteriores cópia"
