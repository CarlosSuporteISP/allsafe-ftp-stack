#!/usr/bin/env bash
# Leitura e gravação do arquivo de ambiente, usadas pelos scripts do host (carregue com `source`).
# O arquivo nunca é executado: só a linha da chave pedida é lida ou trocada.

# env_valor <chave> [padrão]: valor da chave em $env_file; a última ocorrência vale, como no Compose.
env_valor() {
  local valor
  valor="$(sed -n "s/^[[:space:]]*$1=//p" "${env_file:-.env}" | tail -n 1)"
  valor="${valor%\"}"; valor="${valor#\"}"; valor="${valor%\'}"; valor="${valor#\'}"
  printf '%s' "${valor:-${2:-}}"
}

# env_gravar <chave> <valor>: troca a linha da chave em $env_file ou acrescenta no fim.
# Não regrava se o valor já é o pedido; grava no mesmo arquivo, que mantém dono e modo.
env_gravar() {
  local arquivo="${env_file:-.env}" novo
  [[ "$(env_valor "$1")" == "$2" ]] && grep -q "^$1=" "$arquivo" && return 0
  novo="$(CHAVE="$1" VALOR="$2" awk '
    BEGIN { chave = ENVIRON["CHAVE"]; valor = ENVIRON["VALOR"]; feito = 0 }
    index($0, chave "=") == 1 { if (!feito) { print chave "=" valor; feito = 1 }; next }
    { print }
    END { if (!feito) print chave "=" valor }' "$arquivo")"
  printf '%s\n' "$novo" > "$arquivo"
}
