#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Porteiro do FTP. O pure-authd chama este script a cada entrada, antes da conferência da senha.
# Ele não confere senha: só decide se a sessão pode seguir para ela.
#   auth_ok:0   "não é comigo": o pure-ftpd segue para o PureDB, que confere a senha;
#   auth_ok:-1  recusa definitiva: o cliente recebe 530, com a senha certa ou errada.
# Três regras, nesta ordem:
#   bloqueio por endereço: a origem com /auth/enderecos/<origem> ainda valendo é recusada com qualquer conta,
#     com ou sem TLS. Gravam esse arquivo o vigia, o painel e o administrador (allsafe-ftp-user
#     endereco-bloquear); apagá-lo libera o endereço;
#   TLS por usuário (só com a opção valendo, que o entrypoint marca em /run/allsafe/tls-por-usuario):
#     com TLS toda conta segue; sem TLS, só a que o administrador marcou em /auth/sem-tls.lista. Sem nenhum
#     dispensado o pure-ftpd nem chega aqui com sessão sem TLS: ele a recusa antes da senha;
#   bloqueio por tentativa: a conta com /auth/bloqueios/<conta>@<origem> ainda valendo é recusada. Quem
#     grava esse arquivo é o vigia (allsafe-ftp-vigia), que conta as senhas erradas; apagá-lo desbloqueia.
# A senha chega em AUTHD_PASSWORD e não é lida, gravada nem registrada aqui.
lista=/auth/sem-tls.lista
conta="${AUTHD_ACCOUNT:-}"
origem="${AUTHD_REMOTE_IP:-}"
[[ "$origem" =~ ^[0-9a-fA-F.:]{2,45}$ ]] || origem="?"
# O que o cliente mandou como nome pode ser qualquer coisa: só vira caminho ou registro o nome que cabe na regra.
if [[ "$conta" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then nome_valido=sim; else nome_valido=nao; fi
resposta=0
ipv4='^((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])$'
vale() { # <arquivo>: o bloqueio gravado nele ainda vale. Vencido, não vale mais; quem o apaga é o vigia.
  local expira=0
  read -r expira _ < "$1" 2>/dev/null || true
  [[ "$expira" =~ ^[0-9]{1,12}$ ]] && (( 10#$expira > EPOCHSECONDS ))
}

if [[ "$origem" =~ $ipv4 && "$origem" != 127.* && -f "/auth/enderecos/$origem" ]] && vale "/auth/enderecos/$origem"; then
  resposta=-1
elif [[ -e /run/allsafe/tls-por-usuario && "${AUTHD_ENCRYPTED:-0}" != 1 ]] \
  && ! { [[ "$nome_valido" == sim ]] && grep -qxF -- "$conta" "$lista" 2>/dev/null; }; then
  resposta=-1
  if [[ "$nome_valido" == sim ]]; then
    # Marca para o vigia: esta recusa não é senha errada e não conta para o bloqueio.
    [[ "$origem" == "?" ]] || { : > "/run/allsafe/recusa/$origem@$conta.$$"; } 2>/dev/null || true
  else
    conta="(nome fora da regra)"
  fi
  # O pure-authd fecha a saída de erro de quem ele chama: o registro vai pela do processo 1, que é a do container.
  { echo "porteiro: entrada sem TLS recusada: usuario=$conta origem=$origem (a senha enviada passou em texto puro: troque-a)" > /proc/1/fd/2; } 2>/dev/null || true
elif [[ "$nome_valido" == sim && "$origem" != "?" && -f "/auth/bloqueios/$conta@$origem" ]] && vale "/auth/bloqueios/$conta@$origem"; then
  resposta=-1
fi
printf 'auth_ok:%s\nend\n' "$resposta"
