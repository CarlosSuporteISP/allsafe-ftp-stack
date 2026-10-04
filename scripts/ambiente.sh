#!/usr/bin/env bash
# Leitura do arquivo de ambiente, usada pelos scripts do host (carregue com `source`).
# O arquivo nunca é executado: só a linha da chave pedida é lida.

# env_valor <chave> [padrão]: valor da chave em $env_file; a última ocorrência vale, como no Compose.
env_valor() {
  local valor
  valor="$(sed -n "s/^[[:space:]]*$1=//p" "${env_file:-.env}" | tail -n 1)"
  valor="${valor%\"}"; valor="${valor#\"}"; valor="${valor%\'}"; valor="${valor#\'}"
  printf '%s' "${valor:-${2:-}}"
}
