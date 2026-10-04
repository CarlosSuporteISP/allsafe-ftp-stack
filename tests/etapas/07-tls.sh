#!/usr/bin/env bash
# Etapa G: TLS obrigatório também nos dados.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

gravar_env "$ENVA" FTP_TLS_MODE 3; dep; r=$?
m3_claro="$(ftp_curl controle "$USUARIO" "$W/inicial.senha" -o "$W/claro3.bin" "$F/backup.cfg")"; m3_resp="$(resposta '(150|226|4|5)')"
m3_tls="$(ftp_curl tls "$USUARIO" "$W/inicial.senha" -o "$W/claro3.bin" "$F/backup.cfg")"
gravar_env "$ENVA" FTP_TLS_MODE 2
[[ "$r" == 0 && "$m2_tls" == 0 && "$m3_tls" == 0 && "$m3_claro" != 0 ]]
caso $? seguranca 7 "Dados sem criptografia no modo 2" "login com TLS e dados sem proteção (curl --ftp-ssl-control) · modo 2: curl saída $m2_claro ($m2_resp) · modo 3: curl saída $m3_claro ($m3_resp) · TLS no login e nos dados: modo 2 saída $m2_tls, modo 3 saída $m3_tls"
if [[ "$m2_claro" == 0 ]]; then
  achado seguranca "No modo 2 (padrão), o servidor aceita os dados sem criptografia de um cliente que protege só o login" "A senha nunca passa em texto puro, mas o arquivo pode passar se o equipamento não pedir a proteção dos dados. O modo 3 recusa (curl saída $m3_claro); a troca do padrão depende de teste com os equipamentos reais"
fi
