#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa Z: usuário inicial removido pelo painel. A instalação o cria uma vez; removido, com ou sem a pasta,
# ele não volta nas subidas seguintes do serviço ftp. Criado de novo com o mesmo nome, fica com a senha
# informada, e não com a do arquivo do segredo.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel zera a contagem de falhas de entrada e das recusas e encerra as sessões.
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"

cadastrado26() { usuarios_ftp | tr ' ' '\n' | grep -c -x -F "$USUARIO"; }                                   # 1 se o usuário inicial está no cadastro
login26() { local r; r="$(ftp_curl tls "$1" "$2" -l "$F/")"; echo "$r $(resposta '(226|530) ' | cut -c1-3)"; }  # <usuário> <arquivo da senha> → "0 226" ou "67 530"
subir26() { dc restart ftp > /dev/null 2>&1; esperar "$FTP"; saude "$FTP"; }                                # reinicia o serviço ftp → saúde
pasta26() { docker exec "$FTP" stat -c '%U:%G %a %F' "/data/$USUARIO" 2>/dev/null || echo ausente; }        # a pasta de fábrica do usuário inicial
marca26() { docker exec "$FTP" sh -c "stat -c '%U:%G %a' /auth/$1 2>/dev/null && cat /auth/$1" 2>/dev/null | tr '\n' ' ' || true; }  # <arquivo de /auth>: dono, modo e conteúdo (só o nome)
mantidas26() { docker logs "$FTP" 2>&1 | grep -c -F "Usuário inicial '$USUARIO': mantida a senha trocada pelo painel"; }
recusas26() { docker logs "$FTP" 2>&1 | grep -c -F "Usuário inicial '$USUARIO': removido pelo administrador; não é recriado."; }
remove26() { # [sim: apagar a pasta junto] → "código destino"
  local -a campos=(--data-urlencode "csrf=$K" --data-urlencode "usuario=$USUARIO" --data-urlencode 'confirmar=sim')
  [[ -z "${1:-}" ]] || campos+=(--data-urlencode "apagar_pasta=$1" --data-urlencode "senha_atual@$W/painel.senha")
  envio /usuarios/remover "${campos[@]}"
}

nova_senha "$W/u26.senha"; nova_senha "$W/ini26.senha"
printf 'gravado-antes-de-remover-%s\n' "$(openssl rand -hex 8)" > "$W/antes26.cfg"
soma_antes="$(somas)"; segredo_antes="$(sha256sum < "$S/ftp-usuario-inicial-senha.txt" | cut -c1-16)"
r_outro_novo="$(envio /usuarios/novo --data-urlencode "csrf=$K" --data-urlencode 'usuario=outro26' --data-urlencode "senha@$W/u26.senha" --data-urlencode "confirmacao@$W/u26.senha")"

# Como a instalação deixou: o usuário existe, entra com a senha do segredo e tem a marca de criado.
m_criado="$(marca26 usuario-inicial.criado)"; l_ini="$(login26 "$USUARIO" "$W/inicial.senha")"
r_envio="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" -T "$W/antes26.cfg" "$F/antes26.cfg")"
auditoria; n_antes="$(eventos usuario_removido)"

# ------------------------------------------------------------------ removido sem a pasta: não volta, e os arquivos ficam
r_rem="$(remove26)"; c_1="$(cadastrado26)"; l_1="$(login26 "$USUARIO" "$W/inicial.senha")"; p_1="$(pasta26)"
aba -b "$J" "$B/usuarios" > /dev/null; na_lista="$(grep -c "usuario=$USUARIO\"" "$W/corpo")"
m_trocada="$(marca26 senha-inicial.trocada)"; m_criado_1="$(marca26 usuario-inicial.criado)"
rec_antes="$(recusas26)"; s_1="$(subir26)"; rec_1="$(recusas26)"
c_2="$(cadastrado26)"; l_2="$(login26 "$USUARIO" "$W/inicial.senha")"; l_outro_1="$(login26 outro26 "$W/u26.senha")"
ficou="$(docker exec "$FTP" cat "/data/$USUARIO/antes26.cfg" 2>/dev/null | cmp -s - "$W/antes26.cfg" && echo igual || echo DIFERENTE)"
ENV_FILE="$ENVA" ./scripts/validate.sh --runtime > "$W/runtime26.log" 2>&1; r_val=$?
l_val="$(grep -c -x -F "usuario inicial '$USUARIO' removido pelo administrador (o serviço ftp não o recria)" "$W/runtime26.log")"
dep; r_dep=$?; painel_de_pe; esperar "$FTP"
resumo="$(grep -c -F "usuário inicial '$USUARIO' removido pelo administrador; os usuários do FTP são os da aba Usuários do painel" "$W/deploy.log")"
resumo_senha="$(grep -c -F "usuário '$USUARIO', senha" "$W/deploy.log")"; c_3="$(cadastrado26)"

# ------------------------------------------------------------------ criado de novo com o mesmo nome: vale a senha informada
r_novo="$(envio /usuarios/novo --data-urlencode "csrf=$K" --data-urlencode "usuario=$USUARIO" --data-urlencode "senha@$W/ini26.senha" --data-urlencode "confirmacao@$W/ini26.senha")"
l_novo="$(login26 "$USUARIO" "$W/ini26.senha")"; l_segredo="$(login26 "$USUARIO" "$W/inicial.senha")"
r_volta="$(ftp_curl tls "$USUARIO" "$W/ini26.senha" -o "$W/volta26.cfg" "$F/antes26.cfg")"; volta="$(cmp -s "$W/volta26.cfg" "$W/antes26.cfg" && echo igual || echo DIFERENTE)"
man_antes="$(mantidas26)"; s_2="$(subir26)"; man_depois="$(mantidas26)"; l_novo_2="$(login26 "$USUARIO" "$W/ini26.senha")"; l_segredo_2="$(login26 "$USUARIO" "$W/inicial.senha")"

# ------------------------------------------------------------------ removido com a pasta: nem o usuário nem a pasta voltam
t_rem="$(aba -b "$J" "$B/usuarios/remover?usuario=$USUARIO")"; caixa="$(grep -c 'type="checkbox" name="apagar_pasta" value="sim"' "$W/corpo")"
r_rem_pasta="$(remove26 sim)"; c_4="$(cadastrado26)"; p_2="$(pasta26)"
s_3="$(subir26)"; c_5="$(cadastrado26)"; p_3="$(pasta26)"; l_3="$(login26 "$USUARIO" "$W/ini26.senha")"; l_outro_2="$(login26 outro26 "$W/u26.senha")"
auditoria; n_depois="$(eventos usuario_removido)"

# De volta ao que a instalação deixou, pelo terminal: o mesmo nome, com a senha do arquivo do segredo.
mu add "$USUARIO" "$W/inicial.senha"; r_mu=$?
l_fim="$(login26 "$USUARIO" "$W/inicial.senha")"; s_4="$(subir26)"; l_fim_2="$(login26 "$USUARIO" "$W/inicial.senha")"; p_4="$(pasta26)"
mu del outro26; r_del=$?; docker exec "$FTP" rm -rf /data/outro26
segredo_depois="$(sha256sum < "$S/ftp-usuario-inicial-senha.txt" | cut -c1-16)"

[[ "$e_adm" == 303 && "$r_outro_novo" == "303 /usuarios?m=criado" && "$m_criado" == "root:root 600 $USUARIO " && "$l_ini" == "0 226" && "$r_envio" == 0 \
  && "$r_rem" == "303 /usuarios?m=removido" && "$c_1" == 0 && "$l_1" == "67 530" && "$p_1" == "ftpdata:ftpdata 750 directory" && "$na_lista" == 0 \
  && -z "$m_trocada" && "$m_criado_1" == "root:root 600 $USUARIO " \
  && "$s_1" == "healthy " && "$rec_antes" == 0 && "$rec_1" == 1 && "$c_2" == 0 && "$l_2" == "67 530" && "$l_outro_1" == "0 226" && "$ficou" == igual \
  && "$r_val" == 0 && "$l_val" == 1 && "$r_dep" == 0 && "$resumo" == 1 && "$resumo_senha" == 0 && "$c_3" == 0 \
  && "$r_novo" == "303 /usuarios?m=criado" && "$l_novo" == "0 226" && "$l_segredo" == "67 530" && "$r_volta" == 0 && "$volta" == igual \
  && "$s_2" == "healthy " && "$l_novo_2" == "0 226" && "$l_segredo_2" == "67 530" && "$((man_depois - man_antes))" == 1 \
  && "$t_rem" == "200 " && "$caixa" == 1 && "$r_rem_pasta" == "303 /usuarios?m=removido_com_pasta" && "$c_4" == 0 && "$p_2" == ausente \
  && "$s_3" == "healthy " && "$c_5" == 0 && "$p_3" == ausente && "$l_3" == "67 530" && "$l_outro_2" == "0 226" && "$((n_depois - n_antes))" == 2 \
  && "$r_mu" == 0 && "$l_fim" == "0 226" && "$s_4" == "healthy " && "$l_fim_2" == "0 226" && "$p_4" == "ftpdata:ftpdata 750 directory" && "$r_del" == 0 \
  && "$segredo_antes" == "$segredo_depois" && "$soma_antes" == "$(somas)" ]]
caso $? testes 51 "Usuário inicial removido pelo painel não volta na subida seguinte" "como a instalação deixou: marca de criado em /auth $m_criado, login com a senha do segredo: $l_ini, um arquivo enviado: $r_envio · POST /usuarios/remover sem a caixa da pasta: $r_rem · no cadastro: $c_1, na lista do painel: $na_lista, login: $l_1, pasta: $p_1 · marca da senha trocada: ${m_trocada:-ausente}, marca de criado: $m_criado_1 · reinício do serviço ftp: $s_1· linha 'removido pelo administrador; não é recriado' no log, antes e depois: $rec_antes e $rec_1 · no cadastro: $c_2, login: $l_2, arquivo na pasta: $ficou, outro usuário entra: $l_outro_1 · validate.sh --runtime: saída $r_val, linha do usuário removido: $l_val · deploy.sh: saída $r_dep, resumo com o usuário removido: $resumo, com senha de usuário inicial: $resumo_senha, no cadastro: $c_3 · criado de novo pelo painel com o mesmo nome: $r_novo · login com a senha informada: $l_novo, com a do segredo: $l_segredo, arquivo de antes baixado: $r_volta, $volta · reinício: $s_2· login com a informada: $l_novo_2, com a do segredo: $l_segredo_2, linhas 'mantida a senha trocada pelo painel' a mais no log: $((man_depois - man_antes)) · tela Remover: $t_rem, caixa da pasta: $caixa · POST com a caixa e a senha do administrador: $r_rem_pasta · no cadastro: $c_4, pasta: $p_2 · reinício: $s_3· no cadastro: $c_5, pasta: $p_3, login: $l_3, outro usuário entra: $l_outro_2 · eventos usuario_removido a mais na auditoria: $((n_depois - n_antes)) · de volta pelo terminal (manage-user.sh add, senha do segredo): saída $r_mu, login: $l_fim, depois de reiniciar ($s_4): $l_fim_2, pasta: $p_4 · arquivo do segredo $([[ "$segredo_antes" == "$segredo_depois" ]] && echo igual || echo DIFERENTE) · arquivos de segredo $([[ "$soma_antes" == "$(somas)" ]] && echo 'iguais aos do início' || echo DIFERENTES)"
