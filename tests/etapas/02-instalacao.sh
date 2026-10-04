#!/usr/bin/env bash
# Etapa B: instalação em um comando, portas publicadas, containers e segredos.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

inicio=$(date +%s); dep; r=$?; duracao=$(( $(date +%s) - inicio ))
if [[ "$r" != 0 ]]; then
  caso 1 testes 10 "Instalação em um comando" "deploy.sh: saída $r · $(grep -E '^(ERRO|FALHA)' "$W/deploy.log" | head -2)"
  echo "A instância de teste não subiu; a bateria para aqui. Últimas linhas do deploy.sh:" >&2
  tail -5 "$W/deploy.log" | limpo >&2
  encerrar
fi
for arquivo in "$S"/*.txt; do proibir "$(head -1 "$arquivo")"; done
tr -d '\r\n' < "$S/ftp_password.txt" > "$W/inicial.senha"
tr -d '\r\n' < "$S/painel_password.txt" > "$W/painel.senha"
printf 'senha-errada-de-teste' > "$W/errada.senha"; printf 'teste@exemplo.com.br' > "$W/anonimo.senha"
for n in 1 2 3 4 5 6; do nova_senha "$W/u$n.senha"; done
ev10="1ª execução: saída 0 em $duracao s, sem terminal · criados: $(grep -c -E '^(Criado|Gerada)' "$W/deploy.log") (o .env e duas senhas) · saúde: $(saude "$FTP" "$PAINEL" "$NGINX")· senhas na saída: $(segredos_em "$W/deploy.log")"
ok10=1; [[ "$(saude "$FTP" "$PAINEL" "$NGINX")" == "healthy healthy healthy " && "$(segredos_em "$W/deploy.log")" == 0 ]] || ok10=0

modos="$(stat -c '%a' "$S" "$S"/*.txt | tr '\n' ' ')"
[[ "$modos" == "700 600 600 600 " ]]; caso $? seguranca 14 "Permissão dos segredos" "pasta e arquivos (ftp_password, painel_password, painel_password_hash): $modos"

ENV_FILE="$ENVA" ./scripts/validate.sh --runtime > "$W/runtime.log" 2>&1; r=$?
[[ "$r" == 0 && "$(grep -c 'running, healthy' "$W/runtime.log")" == 3 ]] && grep -q "presente no PureDB" "$W/runtime.log"
caso $? testes 2 "Validação em execução" "validate.sh --runtime: saída $r · $(grep -E '^(servico|usuario)' "$W/runtime.log" | tr '\n' ';')"

escuta="$(ss -Hltn | awk '{print $4}')"
controle="$(docker port "$FTP" 2121/tcp 2>/dev/null | tr '\n' ' ')"
[[ "$controle" == "$IP:$FTP_PORTA " ]] && grep -q -x -F "$IP:$FTP_PORTA" <<< "$escuta" && ! grep -q -x -E "(0\.0\.0\.0|\*|\[::\]):$FTP_PORTA" <<< "$escuta"
caso $? rede 1 "Bind da porta de controle" "docker port 2121/tcp: $controle· ss: $(grep -c -x -F "$IP:$FTP_PORTA" <<< "$escuta") escuta em $IP:$FTP_PORTA, $(grep -c -x -E "(0\.0\.0\.0|\*|\[::\]):$FTP_PORTA" <<< "$escuta") em todas as interfaces"

publicadas=0; no_host=0
for ((porta = PASSIVA; porta < PASSIVA + 20; porta++)); do
  [[ "$(docker port "$FTP" "$porta/tcp" 2>/dev/null)" == "$IP:$porta" ]] && publicadas=$((publicadas + 1))
  grep -q -x -F "$IP:$porta" <<< "$escuta" && no_host=$((no_host + 1))
done
[[ "$publicadas" == 20 && "$no_host" == 20 ]]
caso $? rede 2 "Faixa passiva publicada" "faixa $PASSIVA-$((PASSIVA + 19)): $publicadas de 20 publicadas 1:1 em $IP · $no_host em escuta no host"

subrede="$(docker network inspect -f '{{range .IPAM.Config}}{{.Subnet}}{{end}}' "$NOME-network" 2>/dev/null)"
[[ "$subrede" == "$SUBREDE" ]]; caso $? rede 6 "Sub-rede Docker" "rede $NOME-network: $subrede · FTP_SUBNET: $SUBREDE"

painel_pub="$(docker port "$NGINX" 2>/dev/null | tr '\n' ' ')"
[[ "$painel_pub" == "8443/tcp -> $IP:$PAINEL_PORTA " ]] && grep -q -x -F "$IP:$PAINEL_PORTA" <<< "$escuta" && ! grep -q -x -E "(0\.0\.0\.0|\*|\[::\]):$PAINEL_PORTA" <<< "$escuta"
caso $? rede 9 "Bind do painel" "nginx publica: $painel_pub· ss: $(grep -c -x -F "$IP:$PAINEL_PORTA" <<< "$escuta") escuta em $IP:$PAINEL_PORTA, $(grep -c -x -E "(0\.0\.0\.0|\*|\[::\]):$PAINEL_PORTA" <<< "$escuta") em todas as interfaces"

p_ftp="$(docker port "$FTP" | wc -l)"; p_painel="$(docker port "$PAINEL" | wc -l)"; p_nginx="$(docker port "$NGINX" | wc -l)"
p_fora="$(docker port "$FTP"; docker port "$PAINEL"; docker port "$NGINX")"; p_fora="$(grep -c -v -F -- "-> $IP:" <<< "$p_fora")"
[[ "$p_ftp" == 21 && "$p_painel" == 0 && "$p_nginx" == 1 && ( "$p_fora" == 0 || -z "$p_fora" ) ]]
caso $? rede 11 "Nenhuma porta além das previstas" "ftp: $p_ftp (controle + 20 passivas) · painel: $p_painel · nginx: $p_nginx · publicadas fora de $IP: ${p_fora:-0}"

ev=""; ok=0
for n in "$FTP" "$PAINEL" "$NGINX"; do
  d="$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}} {{.HostConfig.CapDrop}} {{.HostConfig.SecurityOpt}} privilegiado={{.HostConfig.Privileged}}' "$n" 2>/dev/null)"
  [[ "$d" == "true [ALL] [no-new-privileges:true] privilegiado=false" ]] || ok=1
  ev+="$n: $d; "
done
usuario_nginx="$(docker inspect -f '{{.Config.User}}' "$NGINX" 2>/dev/null)"; [[ "$usuario_nginx" == 10001:10001 ]] || ok=1
caso $ok seguranca 8 "Container endurecido" "$ev nginx roda como $usuario_nginx (sem root)"

soquetes="$(docker inspect -f '{{range .Mounts}}{{println .Source}}{{end}}' "$FTP" "$PAINEL" "$NGINX" 2>/dev/null | grep -c 'docker\.sock')"
[[ "$soquetes" == 0 ]]; caso $? seguranca 35 "Sem socket do Docker" "montagens com docker.sock nos três containers: $soquetes"

docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$FTP" "$PAINEL" "$NGINX" > "$W/variaveis" 2>/dev/null
n_nome="$(grep -c -i -E '^[^=]*(password|passwd|secret|token|hash|_key)[^=]*=' "$W/variaveis")"; n_valor="$(segredos_em "$W/variaveis")"
[[ "$n_nome" == 0 && "$n_valor" == 0 ]]
caso $? seguranca 12 "Nenhuma senha em variável de ambiente" "$(grep -c . "$W/variaveis") variáveis nos três containers · com nome de senha, token, hash ou chave: $n_nome · com o valor de um segredo: $n_valor"

s_ftp="$(docker exec "$FTP" ls /run/secrets 2>/dev/null | tr '\n' ' ')"; s_painel="$(docker exec "$PAINEL" ls /run/secrets 2>/dev/null | tr '\n' ' ')"
s_nginx="$(docker exec "$NGINX" ls /run/secrets 2>/dev/null | tr '\n' ' ')"
[[ "$s_ftp" == "ftp_password " && "$s_painel" == "painel_password_hash " && -z "$s_nginx" ]]
caso $? seguranca 13 "Cada serviço vê só o próprio segredo" "ftp: ${s_ftp:-nenhum }· painel: ${s_painel:-nenhum }· nginx: ${s_nginx:-nenhum}"

ev=""; ok=0
for imagem in "$IMG_FTP" "$IMG_PAINEL" "$IMG_NGINX"; do
  h="$(docker history --no-trunc "$imagem" 2>/dev/null | grep -c -a -F -f "$W/proibidos")"
  v="$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$imagem" 2>/dev/null | grep -c -i -E 'password|passwd|secret|token|hash|_key')"
  docker create --name "$NOME-export" "$imagem" > /dev/null 2>&1
  a="$(docker export "$NOME-export" 2>/dev/null | grep -c -a -F -f "$W/proibidos")"
  docker rm -f "$NOME-export" > /dev/null 2>&1
  [[ "$h" == 0 && "$v" == 0 && "$a" == 0 ]] || ok=1
  ev+="$imagem: histórico $h, variáveis $v, arquivos $a; "
done
caso $ok seguranca 9 "Segredo fora da imagem" "ocorrências das senhas e do hash desta instalação · $ev"
