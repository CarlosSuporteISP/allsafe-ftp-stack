#!/usr/bin/env bash
# Etapa E: recusas de configuração (senha no .env, IP e rede fora do permitido) e segredo fora do Git.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

d="$(recusa_deploy FTP_PASSWORD=valor-de-exemplo-sem-uso)"; migracao="$(grep -c 'Migração' "$W/recusa.log")"
k="$(recusa_container ftp FTP_PASSWORD=valor-de-exemplo-sem-uso)"
recusou "$d" 'ainda traz FTP_PASSWORD' && [[ "$migracao" -ge 1 && "$k" != "saída 0 "* && "$k" == *'não é mais aceita'* ]]
caso $? seguranca 15 ".env antigo com senha" "deploy.sh: $d, explica a migração: $([[ "$migracao" -ge 1 ]] && echo sim || echo NÃO) · container: $k"
ev=""
par() { # <nº> <nome> <serviço do container> <CHAVE=valor> <texto esperado>
  local d k; d="$(recusa_deploy "$4")"; k="$(recusa_container "$3" "$4")"
  recusou "$d" "$5" && [[ "$k" != "saída 0 "* && "$k" == *"$5"* ]]
  caso $? seguranca "$1" "$2" "$4 · deploy.sh: $d · container do $3: $k$ev"
}
par 16 "Bind do FTP em todas as interfaces" ftp FTP_BIND_IP=0.0.0.0 'não é IP privado'
par 17 "Bind do FTP em IP público" ftp FTP_BIND_IP=8.8.8.8 'não é IP privado'
par 18 "IP anunciado público" ftp FTP_PUBLIC_IP=8.8.8.8 'não é IP privado'
par 19 "Bind do painel fora de IP privado" painel PAINEL_BIND_IP=0.0.0.0 'não é IP privado'
ev=" · container do nginx: $(recusa_container nginx PAINEL_REDES_PERMITIDAS=0.0.0.0/0)"
[[ "$ev" == *'saída 1 '*'não é rede privada'* ]] || ev+=" (NÃO RECUSOU)"
par 20 "Rede permitida pública no painel" painel PAINEL_REDES_PERMITIDAS=0.0.0.0/0 'não é rede privada'
[[ "$ev" != *'NÃO RECUSOU'* ]] || { falhas=$((falhas + 1)); sed -i -e '/^20\t/s/\t✅\t/\t❌\t/' "$W/casos-seguranca.tsv"; }
ev=""

chaves='^[A-Za-z0-9_]*(PASSWORD|PASSWD|SECRET|TOKEN|HASH|API_KEY|PRIVATE_KEY)[A-Za-z0-9_]*=.+'
caminhos='^[A-Za-z0-9_]*_(DIR|FILE|PATH)='   # caminho de onde o segredo mora não é segredo
n_env="$(grep -i -E "$chaves" "$ENVA" | grep -c -v -E "$caminhos")"; n_exemplo="$(grep -i -E "$chaves" .env.example | grep -c -v -E "$caminhos")"; n_valor="$(segredos_em "$ENVA")"
[[ "$n_env" == 0 && "$n_exemplo" == 0 && "$n_valor" == 0 ]]
caso $? seguranca 11 "Nenhuma senha no .env" "chaves de senha, token, hash ou chave preenchidas · .env da instância: $n_env · .env.example: $n_exemplo · valores dos segredos no .env: $n_valor"

if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  no_indice="$(git ls-files -- .env .secrets | grep -c -v -x -e '.secrets/.gitkeep' -e '.secrets/README.md')"
  no_historico="$(git log --all --diff-filter=A --name-only --format= -- .env .secrets 2>/dev/null | grep -v -x -e '.secrets/.gitkeep' -e '.secrets/README.md' -e '' | sort -u | wc -l)"
  ignorados=0
  for arquivo in .env .secrets/ftp_password.txt .secrets/painel_password.txt .secrets/painel_password_hash.txt; do
    git check-ignore -q "$arquivo" || ignorados=1
  done
  no_git="$(git grep -c -I -F -f "$W/proibidos" 2>/dev/null | wc -l)"
  [[ "$no_indice" == 0 && "$no_historico" == 0 && "$ignorados" == 0 && "$no_git" == 0 ]]
  caso $? seguranca 10 "Segredo fora do Git" "git ls-files com .env ou arquivo de .secrets além do .gitkeep e do README.md: $no_indice · no histórico (git log --all): $no_historico · .env e os três segredos ignorados pelo .gitignore: $([[ "$ignorados" == 0 ]] && echo sim || echo NÃO) · arquivos versionados com um segredo desta bateria: $no_git"
else
  fora seguranca 10 "Segredo fora do Git" "a pasta não é um repositório Git"
fi
