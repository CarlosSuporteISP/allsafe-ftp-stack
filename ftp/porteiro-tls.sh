#!/usr/bin/env bash
# Porteiro do TLS por usuário (FTP_TLS_EXCECOES=sim). O pure-authd chama este script a cada entrada,
# antes da conferência da senha. Ele não confere senha: só decide se a sessão pode seguir para ela.
#   auth_ok:0   "não é comigo": o pure-ftpd segue para o PureDB, que confere a senha;
#   auth_ok:-1  recusa definitiva: o cliente recebe 530, com a senha certa ou errada.
# Com TLS, toda conta segue. Sem TLS, só a conta que o administrador marcou em /auth/sem-tls.lista.
# A senha chega em AUTHD_PASSWORD e não é lida, gravada nem registrada aqui.
lista=/auth/sem-tls.lista
conta="${AUTHD_ACCOUNT:-}"

if [[ "${AUTHD_ENCRYPTED:-0}" == 1 ]]; then
  resposta=0
elif [[ "$conta" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] && grep -qxF -- "$conta" "$lista" 2>/dev/null; then
  resposta=0
else
  resposta=-1
  # O que o cliente mandou como nome pode ser qualquer coisa: só vai para o registro o nome que cabe na regra.
  [[ "$conta" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || conta="(nome fora da regra)"
  origem="${AUTHD_REMOTE_IP:-}"
  [[ "$origem" =~ ^[0-9a-fA-F.:]{2,45}$ ]] || origem="?"
  # O pure-authd fecha a saída de erro de quem ele chama: o registro vai pela do processo 1, que é a do container.
  { echo "porteiro: entrada sem TLS recusada: usuario=$conta origem=$origem (a senha enviada passou em texto puro: troque-a)" > /proc/1/fd/2; } 2>/dev/null || true
fi
printf 'auth_ok:%s\nend\n' "$resposta"
