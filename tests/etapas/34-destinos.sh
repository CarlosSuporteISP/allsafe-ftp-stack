#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa AH: destinos de fora. O administrador grava pelo painel um armazenamento S3 e um bot do Telegram, com a senha
# dele; o painel envia sozinho o que chega na pasta escolhida, em passadas. A etapa sobe, na rede da instância de
# teste, um serviço de exemplo dos dois (tests/apoio/simulador_destinos.py), com certificado de uma autoridade criada
# aqui, e confere pelo registro dele o que chegou: nome, tamanho e soma de cada arquivo, e nenhuma operação além das
# de gravar e de enviar. As chaves, o token e a conversa são gerados na hora e não entram em evidência.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

api_0="$(env_file="$ENVA" env_valor PAINEL_TELEGRAM_API https://api.telegram.org)"
max_0="$(env_file="$ENVA" env_valor PAINEL_TELEGRAM_MAX_MB 50)"
des_0="$(env_file="$ENVA" env_valor PAINEL_DESTINOS sim)"
gravar_env "$ENVA" PAINEL_TELEGRAM_API https://bot.simulador.test:8443; gravar_env "$ENVA" PAINEL_TELEGRAM_MAX_MB 1
gravar_env "$ENVA" PAINEL_DESTINOS sim; dep; r_dep0=$?
# O reinício do painel encerra as sessões e zera a memória das recusas (a auditoria guarda uma por minuto de cada tipo).
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"

SIM34="$NOME-simulador"; D34="$W/sim34"; FIM34=https://s3.simulador.test:8443; DATA34='\d\d/\d\d/\d{4}\s\d\d:\d\d'
SEM34='0 apagado(s) do servidor, 0 acima do limite do bot, 0 ignorado(s), 0 recusado(s)'
tem34() { grep -c -F -- "$1" "$W/corpo" || true; }                                             # <texto>: linhas da última tela com ele
vezes34() { grep -o -F -- "$1" "$W/corpo" | wc -l; }                                           # <texto>: quantas vezes ele está na última tela
faltam34() { local texto n=0; for texto in "$@"; do grep -q -F -- "$texto" "$W/corpo" || n=$((n + 1)); done; echo "$n"; }  # <texto...>: quantos não estão na última tela
linhas34() { grep -c -E -- "$1" "$W/auditoria" || true; }                                      # <expressão>: linhas da auditoria com ela
planta34() { docker exec -i "$FTP" sh -s; }                                                    # roda no container do FTP o que vier pela entrada
soma34() { docker exec "$FTP" sha256sum "/data/$1" | cut -c1-64; }                             # <arquivo dentro de /data>: SHA-256 dele
tam34() { docker exec "$FTP" stat -c %s "/data/$1"; }                                          # <arquivo dentro de /data>: tamanho dele
ha34() { docker exec "$FTP" test -e "/data/$1" && echo sim || echo nao; }                      # <arquivo dentro de /data>: ainda está no servidor?
marca34() { [[ -f "$D34/chamadas.jsonl" ]] && wc -l < "$D34/chamadas.jsonl" || echo 0; }       # pedidos que o simulador já registrou
token34() { c -b "$1" "$B/meus-arquivos" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1; }  # <pote>: token dos formulários do usuário do FTP
vaza34() { grep -c -a -F -f "$D34/lista" "$1" 2>/dev/null || true; }                           # <arquivo>: linhas com algum segredo dos destinos
terminal34() { docker exec "$PAINEL" python3 /opt/painel/servidor.py --destinos "$@" > "$W/terminal34" 2>&1; }  # [argumentos]: os destinos pelo terminal
situ34() { docker exec "$PAINEL" python3 /opt/painel/servidor.py --destinos 2>&1 | grep -m1 "^$1: " || true; }  # <destino>: a linha dele no terminal
doterminal34() { grep -m1 "^$1: " "$W/passada" || true; }                                      # <destino>: o que a última passada pedida disse dele
passou34() { # <destino>: espera a primeira passada da configuração gravada (a automática vem em até um minuto)
  local marca=$SECONDS
  while (( SECONDS - marca < 100 )) && [[ "$(situ34 "$1")" != *'última passada: '* ]]; do sleep 3; done
  [[ "$(situ34 "$1")" == *'última passada: '* ]]
}
aguarda34() { # <expressão> <vezes> [segundos]: espera a auditoria ter a linha esse número de vezes
  local marca=$SECONDS
  while auditoria; (( $(linhas34 "$1") < $2 )) && (( SECONDS - marca < ${3:-100} )); do sleep 3; done
  (( $(linhas34 "$1") >= $2 ))
}
testa34() { envio /destinos/testar --max-time 40 --data-urlencode "csrf=$K" --data-urlencode "destino=$1"; }  # <destino>: o botão Testar
conf34() { # [texto a recusar]: grava o config.json do simulador, de uma vez
  ( umask 077; printf '{"s3_id":"%s","s3_segredo":"%s","regiao":"sa-teste-1","buckets":["balde34"],"bot_token":"%s","conversa":"%s","telegram_max":600000,"recusar":"%s"}\n' \
      "$(cat "$D34/s3-id")" "$(cat "$D34/s3-secreta")" "$(cat "$D34/token")" "$(cat "$D34/conversa")" "${1:-}" > "$D34/config.novo" ) && mv "$D34/config.novo" "$D34/config.json"
}
sim34() { # <linhas a pular> <condição em Python sobre a linha l> [o que imprimir de cada uma]: sem o 3º, a contagem
  docker exec -i "$SIM34" python3 - "$@" <<'PYTHON'
import collections, json, re, sys
pular, condicao = int(sys.argv[1]), sys.argv[2]
mostrar = sys.argv[3] if len(sys.argv) > 3 else ''
try:
    linhas = open('/sim/chamadas.jsonl', encoding='utf-8').read().splitlines()[pular:]
except OSError:
    linhas = []
achados = []
for linha in linhas:
    l = collections.defaultdict(lambda: None, json.loads(linha))
    if eval(condicao):
        achados.append(str(eval(mostrar)) if mostrar else '')
print(' '.join(achados) if mostrar else len(achados))
PYTHON
}
unicos34() { tr ' ' '\n' | grep . | LC_ALL=C sort -u | tr '\n' ' '; }                           # valores sem repetição, em ordem
obj34() { # <linhas a pular> <arquivo dentro de /data> [soma] [bytes]: objetos gravados com a chave, o tamanho e a soma dele
  sim34 "$1" "l['op']=='gravar' and l['chave']=='copias/teste/$2' and l['bytes']==${4:-$(tam34 "$2")} and l['sha256']=='${3:-$(soma34 "$2")}'"
}
doc34() { # <linhas a pular> <arquivo dentro de /data> [soma] [bytes]: documentos entregues pelo bot com nome, tamanho, soma e legenda dele
  sim34 "$1" "l['op']=='sendDocument' and l['codigo']==200 and l['arquivo']=='${2##*/}' and l['bytes']==${4:-$(tam34 "$2")} and l['sha256']=='${3:-$(soma34 "$2")}' and bool(re.fullmatch(r'$2\n.+ · $DATA34', l['legenda'] or ''))"
}
passa34() { # <destino>: passada pelo terminal, sem a espera dos dois minutos; saída em $W/passada
  local _ codigo=1
  for _ in $(seq 1 30); do
    docker exec "$PAINEL" python3 /opt/painel/servidor.py --destinos enviar "$1" --sem-espera > "$W/passada" 2>&1; codigo=$?
    grep -q -F 'outra passada está em andamento' "$W/passada" || return "$codigo"
    sleep 2
  done
  return "$codigo"
}
grava34() { # <s3|telegram> <pote> <token> <arquivo da senha ou ""> [campo=valor | campo@arquivo | -campo]... → "código destino"
  local destino="$1" pote="$2" token="$3" senha="$4" par nome; shift 4
  local -A campo=([pasta]=dst34 [intervalo]=1440 [ligado]=sim) arquivo=()
  if [[ "$destino" == s3 ]]; then
    campo+=([endpoint]="$FIM34" [regiao]=sa-teste-1 [bucket]=balde34 [prefixo]=copias/teste [estilo]=caminho [modo]=copiar)
  else campo[pasta]=tg34; campo[idioma]=pt; fi
  for par in "$@"; do
    if [[ "$par" == -* ]]; then unset "campo[${par#-}]" "arquivo[${par#-}]"
    elif [[ "$par" =~ ^([a-z_]+)@(.+)$ ]]; then arquivo[${BASH_REMATCH[1]}]="${BASH_REMATCH[2]}"; unset "campo[${BASH_REMATCH[1]}]"   # segredo lido do arquivo
    else campo[${par%%=*}]="${par#*=}"; unset "arquivo[${par%%=*}]"; fi
  done
  local -a dados=(--data-urlencode "csrf=$token")
  for nome in "${!campo[@]}"; do dados+=(--data-urlencode "$nome=${campo[$nome]}"); done
  for nome in "${!arquivo[@]}"; do dados+=(--data-urlencode "$nome@${arquivo[$nome]}"); done
  [[ -n "$senha" ]] && dados+=(--data-urlencode "senha_atual@$senha")
  c -o "$W/corpo" -w '%{http_code} %{redirect_url}' -b "$pote" -H "Origin: ${ORIGEM34:-$B}" "${dados[@]}" "$B/destinos/$destino" | sed "s|$B||"
}
rotulo34() { local par r=""; for par in "$@"; do [[ "$par" == *@* ]] || r+="$par "; done; echo "${r% }"; }  # os campos, sem os que vêm de arquivo
recusa34() { # <destino> <frase> [campo...]: formulário fora da regra ➜ 400 com a frase na tela; acumula em ok_inv e ev_inv
  local destino="$1" frase="$2" r; shift 2
  r="$(grava34 "$destino" "$J" "$K" "$W/painel.senha" "${SEG34[@]}" "$@")"
  [[ "$r" == "400 " && "$(tem34 "$frase")" -ge 1 ]] || ok_inv=1
  ev_inv+="$destino $(rotulo34 "$@"): $r'$frase' $(tem34 "$frase"); "
}
prova34() { # <motivo esperado> <o que é> [campo...]: grava o S3 desligado com os campos e pede o teste; acumula em ok_prova e ev_prova
  local esperado="$1" nome="$2" g r; shift 2
  g="$(grava34 s3 "$J" "$K" "$W/painel.senha" -ligado "${S3_34[@]}" "$@")"; r="$(testa34 s3)"
  [[ "$g" == "303 /destinos?m=gravado" && "$r" == "303 /destinos?m=falha&d=s3&f=$esperado" ]] || ok_prova=1
  ev_prova+="$nome ($(rotulo34 "$@")): gravação $g, teste $r; "
}
rotas34() { # <pote> <token> → os códigos das dez rotas dos destinos: quatro de leitura e seis de envio
  local pote="$1" token="$2" rota r=""
  for rota in /destinos /destinos/s3 /destinos/telegram '/destinos/remover?destino=s3'; do r+="$(aba -b "$pote" "$B$rota" | cut -c1-3) "; done
  for rota in s3 telegram testar agora remover arquivo; do
    r+="$(POTE="$pote" envio "/destinos/$rota" --data-urlencode "csrf=$token" --data-urlencode "destino=s3" | cut -c1-3) "
  done
  echo "$r"
}

# ------------------------------------------------------------------ o serviço de exemplo
# Autoridade e certificado só desta etapa, com as extensões que o Python 3.13 exige de um certificado de servidor.
rm -rf "$D34"; ( umask 077; mkdir -p "$D34" )
n34=$(( RANDOM * RANDOM + 1000 ))
(
  umask 077; cd "$D34" || exit 1
  printf '[req]\ndistinguished_name=dn\nx509_extensions=ca\nprompt=no\n[dn]\nCN=Autoridade de teste da bateria\n[ca]\nbasicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign\nsubjectKeyIdentifier=hash\n' > ca.cnf
  printf 'basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=serverAuth\nsubjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid\nsubjectAltName=DNS:s3.simulador.test,DNS:*.s3.simulador.test,DNS:bot.simulador.test\n' > servidor.ext
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 2 -config ca.cnf -keyout ca.key -out ca.pem \
    && openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -subj '/CN=s3.simulador.test' -keyout servidor.key -out servidor.csr \
    && openssl x509 -req -in servidor.csr -CA ca.pem -CAkey ca.key -CAcreateserial -days 2 -extfile servidor.ext -out servidor.pem || exit 1
  printf 'AKIA%s' "$(openssl rand -hex 8 | tr a-f A-F)" > s3-id
  for n in s3-secreta s3-secreta-errada; do openssl rand -base64 30 | tr -d '\n' > "$n"; done
  for n in token token-errado; do
    printf '%s:%s' "$(( 100000000 + RANDOM * RANDOM % 900000000 ))" "$(openssl rand -base64 48 | tr -d '\n=' | tr '+/' '-_' | cut -c1-35)" > "$n"
  done
  printf -- '-100%010d' "$n34" > conversa; printf -- '-100%010d' "$((n34 + 1))" > conversa-errada
) > "$W/cert34.log" 2>&1; r_cert=$?
: > "$D34/lista"
for n in s3-id s3-secreta s3-secreta-errada token token-errado conversa conversa-errada; do
  proibir "$(cat "$D34/$n")"; { cat "$D34/$n"; echo; } >> "$D34/lista"
done
proibir "$(sed -n 2p "$D34/ca.key")"; proibir "$(sed -n 2p "$D34/servidor.key")"
conf34
S3_34=("chave_id@$D34/s3-id" "chave_secreta@$D34/s3-secreta"); TG_34=("token@$D34/token" "conversa@$D34/conversa")
# O simulador entra na rede da instância com os nomes dos dois serviços, sem privilégio e sem escrita fora da pasta dele.
docker rm -f "$SIM34" > /dev/null 2>&1
docker run -d --name "$SIM34" --no-healthcheck --network "$NOME-network" --network-alias s3.simulador.test \
  --network-alias balde34.s3.simulador.test --network-alias bot.simulador.test --network-alias outro.simulador.test \
  --read-only --cap-drop ALL --security-opt no-new-privileges --user "$(id -u):$(id -g)" --tmpfs /tmp:size=128m \
  -v "$D34:/sim" -v "$root_dir/tests/apoio/simulador_destinos.py:/simulador.py:ro" \
  --entrypoint python3 "$IMG_PAINEL" /simulador.py /sim /sim/servidor.pem /sim/servidor.key 8443 > /dev/null 2> "$W/sim34.log"; r_sim=$?
for n in $(seq 1 30); do docker logs "$SIM34" 2>&1 | grep -q -F 'simulador dos destinos pronto' && break; sleep 1; done
sim_pronto="$(docker logs "$SIM34" 2>&1 | grep -c -F 'simulador dos destinos pronto' || true)"

# A pasta de um usuário (dst34) para o S3 e uma pasta solta (tg34) para o bot. No conjunto A, o que a passada envia
# (cinco arquivos, um deles vazio e um com espaço e acento no nome) e o que ela não toca: nome começado por ponto,
# link simbólico e FIFO.
nova_senha "$W/dst34.senha"; mu add dst34 "$W/dst34.senha" dst34; r_usu=$?
planta34 <<'SH'
set -e
mkdir -p /data/dst34/sub /data/dst34/.pasta /data/tg34/sub
cd /data/dst34
echo um > a1.txt; head -c 70000 /dev/urandom > a2.bin; echo tres > sub/a3.txt; : > vazio.txt; echo quatro > 'relatório final.txt'
echo oculto > .oculto; echo x > .pasta/x.txt; ln -s a1.txt atalho; mkfifo cano
chown -hR ftpdata:ftpdata .
cd /data/tg34; echo antes > antes.txt; chown -hR ftpdata:ftpdata .
SH
r_pla=$?; plantio34=$SECONDS
b_A=0; for n in a1.txt a2.bin sub/a3.txt vazio.txt 'relatório final.txt'; do b_A=$(( b_A + $(tam34 "dst34/$n") )); done

# ------------------------------------------------------------------ só o administrador, com token e senha
auditoria; n_gra="$(eventos destino_gravado)"; n_sen="$(eventos admin_senha_atual_recusada)"; n_pap="$(eventos recusa_papel)"
b_ini="$(aba -b "$J" "$B/arquivos?pasta=dst34")$(vezes34 'para-')"; b_ini_bx="$(vezes34 ' download>')"
t_ini="$(aba -b "$J" "$B/destinos")"; f_ini="$(vezes34 '<span class="etiqueta">não configurado</span>')"; f_menu="$(tem34 'href="/destinos"')"
x_semtoken="$(grava34 s3 "$J" '' "$W/painel.senha" "${S3_34[@]}")"
x_token="$(grava34 s3 "$J" token-errado "$W/painel.senha" "${S3_34[@]}")"
x_origem="$(ORIGEM34=https://fora.example grava34 s3 "$J" "$K" "$W/painel.senha" "${S3_34[@]}")"
: > "$W/vazio34.jar"; x_semsessao="$(grava34 s3 "$W/vazio34.jar" "$K" "$W/painel.senha" "${S3_34[@]}")"
# Senha errada e senha ausente, com o formulário certo: as duas contam como erro de senha do endereço, por isso são só duas.
x_errada="$(grava34 s3 "$J" "$K" "$W/errada.senha" "${S3_34[@]}")"; x_errada_f="$(tem34 'A sua senha atual não confere. Nada foi alterado.')"
x_semsenha="$(grava34 telegram "$J" "$K" '' "${TG_34[@]}")"; x_semsenha_f="$(tem34 'A sua senha atual não confere. Nada foi alterado.')"
e_adm2="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
# Formulário fora da regra: recusado antes de a senha ser conferida, com o motivo na tela.
ok_inv=0; ev_inv=""; SEG34=("${S3_34[@]}")
recusa34 s3 'Endereço inválido:' endpoint=http://s3.simulador.test
recusa34 s3 'Endereço inválido:' endpoint=https://s3.simulador.test/pasta
recusa34 s3 'Bucket inválido:' bucket=Balde_34
recusa34 s3 'Intervalo inválido:' intervalo=4
recusa34 s3 'Intervalo inválido:' intervalo=1441
recusa34 s3 'Escolha a forma do endereço do bucket.' estilo=outro
recusa34 s3 'Escolha o que acontece com o arquivo depois do envio.' modo=apagar
recusa34 s3 'Pasta inválida:' pasta=../x
recusa34 s3 'A pasta não existe dentro dos dados.' pasta=nao-existe34
recusa34 s3 'Preencha os dois segredos do destino' -chave_id -chave_secreta
recusa34 s3 'Chave secreta inválida:' chave_secreta=curta
SEG34=("${TG_34[@]}")
recusa34 telegram 'Token inválido:' token=123
recusa34 telegram 'Conversa inválida:' conversa=abc
recusa34 telegram 'Idioma não aceito.' idioma=xx
x_dest_p="$(envio /destinos/testar --data-urlencode "csrf=$K" --data-urlencode "destino=x")"; x_dest_g="$(aba -b "$J" "$B/destinos/remover?destino=x")"
# O usuário do FTP, com a sessão e o token dele: nenhuma das dez rotas existe para ele.
e_usu="$(COMO=dst34 entrar "$W/dst34.jar" "$W/dst34.senha")"; proibir "$(biscoito_de "$W/dst34.jar")"; K_u="$(token34 "$W/dst34.jar")"; proibir "$K_u"
u_rotas="$(rotas34 "$W/dst34.jar" "$K_u")"; u_meus="$(aba -b "$W/dst34.jar" "$B/meus-arquivos")"; u_menu="$(tem34 '/destinos')"
auditoria; d_gra=$(( $(eventos destino_gravado) - n_gra )); d_sen=$(( $(eventos admin_senha_atual_recusada) - n_sen )); d_pap=$(( $(eventos recusa_papel) - n_pap ))
c_conf="$(docker exec "$PAINEL" sh -c 'ls /painel/destinos 2>/dev/null | grep -c "\.conf$"' || true)"; c_seg="$(ls -A "$S/destinos" 2>/dev/null | wc -l)"
[[ "$r_dep0" == 0 && "$e_adm" == 303 && "$r_cert" == 0 && "$r_sim" == 0 && "$sim_pronto" == 1 && "$r_usu$r_pla" == 00 && "$t_ini" == "200 " && "$f_ini" == 2 && "$f_menu" -ge 1 \
  && "$x_semtoken" == "403 " && "$x_token" == "403 " && "$x_origem" == "403 " && "$x_semsessao" == "303 /entrar" && "$x_errada" == "403 " && "$x_errada_f" -ge 1 \
  && "$x_semsenha" == "403 " && "$x_semsenha_f" -ge 1 && "$e_adm2" == 303 && "$ok_inv" == 0 && "$x_dest_p" == "404 " && "$x_dest_g" == "404 " && "$e_usu" == 303 && -n "$K_u" \
  && "$u_rotas" == "404 404 404 404 404 404 404 404 404 404 " && "$u_meus" == "200 " && "$u_menu" == 0 && "$d_gra" == 0 && "$d_sen" == 2 && "$d_pap" -ge 1 && "$c_conf" == 0 && "$c_seg" == 0 ]]
caso $? seguranca 125 "Destinos: só o administrador grava, com sessão, token e senha" "deploy.sh com a API do bot apontada para o serviço de exemplo: saída $r_dep0; simulador na rede da instância: docker run $r_sim, pronto $sim_pronto; tela dos destinos com o administrador: $t_ini, os dois 'não configurado' ($f_ini) e a aba no menu ($f_menu); formulário do S3 com a sessão dele: sem token $x_semtoken, token errado $x_token, Origin de fora $x_origem; sem sessão: $x_semsessao; senha atual errada: $x_errada, sem a senha: $x_semsenha (telas com 'A sua senha atual não confere. Nada foi alterado.': $x_errada_f e $x_semsenha_f; admin_senha_atual_recusada a mais: $d_sen); formulário fora da regra, recusado com 400 e o motivo na tela antes de qualquer senha: $ev_inv destino que não existe: no teste $x_dest_p, na tela de remover $x_dest_g; usuário do FTP dst34 com a sessão e o token dele, nas dez rotas (4 de leitura, 6 de envio): $u_rotas (recusa_papel a mais: $d_pap), tela dele: $u_meus, sem '/destinos' ($u_menu); depois de tudo: destino_gravado a mais: $d_gra, arquivos de configuração em /painel/destinos: $c_conf, arquivos de segredo na pasta dos segredos: $c_seg"

# ------------------------------------------------------------------ só HTTPS, com certificado conferido e endereço aceito
# O S3 fica gravado desligado: o botão Testar funciona assim, e nenhuma passada sai enquanto o conjunto A assenta.
auditoria; n_tes="$(eventos destino_teste)"; m_127=$(marca34); ok_prova=0; ev_prova=""
prova34 tls 'autoridade ainda não instalada'
docker exec -i "$PAINEL" sh -c 'cat > /painel/destinos/ca.pem' < "$D34/ca.pem"; r_ca=$?
prova34 tls 'nome que não está no certificado' endpoint=https://outro.simulador.test:8443
aba -b "$J" "$B/destinos?m=falha&d=s3&f=tls" > /dev/null; f_tls="$(tem34 'Armazenamento S3: não deu certo. Motivo: o certificado do serviço não foi aceito.')"
prova34 endereco 'o próprio container, pelo nome' endpoint=https://localhost
prova34 endereco 'o próprio container, pelo endereço' endpoint=https://127.0.0.1
prova34 endereco 'endereço de metadados de nuvem' endpoint=https://169.254.169.254
prova34 dns 'nome que não existe' endpoint=https://nao-existe.simulador.test
prova34 conexao 'porta sem serviço' endpoint=https://s3.simulador.test:8444
prova34 recusado 'chave secreta errada' "chave_secreta@$D34/s3-secreta-errada"
prova34 nao_encontrado 'bucket que não existe' bucket=balde-outro
m_307=$(marca34); echo 's3 307' > "$D34/falhar"; prova34 endereco 'serviço que manda o pedido para outro endereço (307)'; rm -f "$D34/falhar"
l_307="$(sim34 "$m_307" "True" "str(l['codigo'])+':'+str(l['erro'])")"
g_fim="$(grava34 s3 "$J" "$K" "$W/painel.senha" -ligado "${S3_34[@]}")"
auditoria; d_tes=""
for n in tls endereco dns conexao recusado nao_encontrado; do d_tes+="$n $(linhas34 " evento=destino_teste admin=$ADMIN destino=s3 resultado=$n\$") · "; done
o_127="$(sim34 "$m_127" "l['op']=='gravar'")"; s_127="$(situ34 s3)"
[[ "$ok_prova" == 0 && "$r_ca" == 0 && "$f_tls" -ge 1 && "$l_307" == "307:Forcado" && "$g_fim" == "303 /destinos?m=gravado" && "$o_127" == 0 \
  && "$d_tes" == "tls 2 · endereco 4 · dns 1 · conexao 1 · recusado 1 · nao_encontrado 1 · " && "$s_127" == "s3: desligado; pasta /data/dst34; a cada 1440 min; nenhuma passada ainda" ]]
caso $? seguranca 127 "Destino só por HTTPS, com certificado conferido e endereço aceito" "S3 gravado desligado e botão Testar, a cada troca: $ev_prova autoridade da etapa instalada em /painel/destinos/ca.pem: saída $r_ca; tela da falha com 'o certificado do serviço não foi aceito': $f_tls; resposta 307 do serviço: o simulador recebeu só $l_307, sem pedido para o endereço novo; destino_teste na auditoria, por resultado: $d_tes; objetos gravados no simulador durante as recusas: $o_127; no terminal: $s_127"

# Só o S3 gravado, e desligado: a aba Arquivos ganha o botão dele, que envia um arquivo de fora da pasta do destino.
aba -b "$J" "$B/arquivos?pasta=dst34" > /dev/null; b_s3="$(vezes34 'id="para-s3"') $(vezes34 'id="para-telegram"') $(( $(vezes34 'form="para-s3"') - $(vezes34 ' download>') ))"
m_des=$(marca34); v_des="$(POTE="$J" envio /destinos/arquivo --max-time 40 --data-urlencode "csrf=$K" --data-urlencode destino=s3 --data-urlencode arquivo=tg34/antes.txt)"
v_obj="$(sim34 "$m_des" "l['op']=='gravar' and l['chave']=='copias/teste/tg34/antes.txt' and l['sha256']=='$(soma34 tg34/antes.txt)'")"; v_sit="$(situ34 s3)"

# ------------------------------------------------------------------ S3 gravado, testado e a primeira passada
# A passada do painel só leva o arquivo que está há dois minutos sem mudar: o destino só é ligado depois disso.
while (( SECONDS - plantio34 < 125 )); do sleep 3; done
g_74="$(grava34 s3 "$J" "$K" "$W/painel.senha" "${S3_34[@]}")"
t_car="$(aba -b "$J" "$B/destinos?m=gravado")"
f_car="$(faltam34 '<code>https://s3.simulador.test:8443</code>' '<code>balde34</code> / <code>copias/teste</code>' '<code>sa-teste-1</code>' '<code>dst34</code>' 'a cada 1440 minutos' \
  'Copiar: o arquivo continua no servidor' 'gravados; não aparecem na tela' 'Destino gravado. Vale a partir da próxima passada.' '<span class="etiqueta">ligado</span>')"
m_t1=$(marca34); t_1="$(testa34 s3)"; aba -b "$J" "$B/destinos?m=teste" > /dev/null; f_tes="$(tem34 'Teste concluído: o destino recebeu.')"
o_t1="$(sim34 "$m_t1" "l['op']=='gravar' and l['chave']=='copias/teste/allsafe-ftp-stack-teste.txt' and l['bucket']=='balde34' and l['estilo']=='caminho'")"
g_alt="$(grava34 s3 "$J" "$K" "$W/painel.senha" intervalo=720)"
t_for="$(aba -b "$J" "$B/destinos/s3")"; f_man="$(vezes34 'em branco mantém o gravado')"
m_t2=$(marca34); t_2="$(testa34 s3)"; o_t2="$(sim34 "$m_t2" "l['op']=='gravar' and l['chave']=='copias/teste/allsafe-ftp-stack-teste.txt'")"
auditoria
l_gra="$(linhas34 " evento=destino_gravado admin=$ADMIN destino=s3 situacao=ligado pasta=dst34 intervalo=1440 modo=copiar segredos=trocados\$")"
l_alt="$(linhas34 " evento=destino_gravado admin=$ADMIN destino=s3 situacao=ligado pasta=dst34 intervalo=720 modo=copiar segredos=mantidos\$")"
l_tes="$(linhas34 " evento=destino_teste admin=$ADMIN destino=s3 resultado=ok\$")"
s_arq="$(ls "$S/destinos" 2>/dev/null | tr '\n' ' ')"; s_modo="$(stat -c %a "$S/destinos"/*.txt 2>/dev/null | sort -u | tr '\n' ' ')"
[[ "$g_74" == "303 /destinos?m=gravado" && "$t_car" == "200 " && "$f_car" == 0 && "$t_1" == "303 /destinos?m=teste" && "$f_tes" -ge 1 && "$o_t1" == 1 && "$g_alt" == "303 /destinos?m=gravado" \
  && "$t_for" == "200 " && "$f_man" == 2 && "$t_2" == "303 /destinos?m=teste" && "$o_t2" == 1 && "$l_gra" == 1 && "$l_alt" == 1 && "$l_tes" == 2 \
  && "$s_arq" == "s3-chave-de-acesso.txt s3-chave-secreta.txt " && "$s_modo" == "600 " ]]
caso $? testes 74 "Destino S3 gravado pelo administrador, com teste de gravação" "formulário do S3 com a senha do administrador: $g_74; cartão: $t_car, textos esperados que faltam (endereço, bucket e prefixo, região, pasta, intervalo, modo Copiar, 'gravados; não aparecem na tela', aviso de gravado e etiqueta 'ligado'): $f_car; botão Testar: $t_1, tela com 'Teste concluído: o destino recebeu.' ($f_tes) e o objeto de teste gravado no bucket do simulador, com a assinatura conferida por ele: $o_t1; alteração do intervalo para 720 sem digitar os segredos: $g_alt, formulário $t_for com 'em branco mantém o gravado' nos dois campos ($f_man) e novo teste aprovado: $t_2 ($o_t2 objeto); auditoria: destino_gravado com segredos=trocados $l_gra, com intervalo=720 e segredos=mantidos $l_alt, destino_teste resultado=ok $l_tes; na pasta dos segredos: $s_arq(modo $s_modo)"

aguarda34 " evento=destino_enviado destino=s3 arquivos=5 bytes=$b_A apagados=0 grandes=0 ignorados=0 erros=0\$" 1 100; r_p75=$?
o_A=""; for n in a1.txt a2.bin sub/a3.txt vazio.txt 'relatório final.txt'; do o_A+="$(obj34 0 "dst34/$n") "; done
o_fora="$(sim34 0 "any(x in (l['chave'] or '') for x in ('oculto', '.pasta', 'atalho', 'cano'))")"
passa34 s3; r_rep=$?; p_rep="$(doterminal34 s3)"; o_A2=""; for n in a1.txt 'relatório final.txt'; do o_A2+="$(obj34 0 "dst34/$n") "; done
t_c75="$(aba -b "$J" "$B/destinos")"; f_c75="$(faltam34 'Última passada' 'Enviado desde que foi ligado' '<dd>5 arquivos · ')"
[[ "$r_p75" == 0 && "$o_A" == "1 1 1 1 1 " && "$o_fora" == 0 && "$r_rep" == 0 && "$p_rep" == "s3: 0 arquivo(s), 0 bytes, $SEM34; chegou ao fim" && "$o_A2" == "1 1 " \
  && "$t_c75" == "200 " && "$f_c75" == 0 ]]
caso $? testes 75 "Passada do S3: envia o que está na pasta, uma vez só" "primeira passada, sozinha, depois de o destino ser ligado: destino_enviado com arquivos=5 e bytes=$b_A na auditoria (espera: $r_p75); objetos no simulador com a chave prefixo/caminho, o tamanho e o SHA-256 de cada arquivo (a1.txt, a2.bin, sub/a3.txt, vazio.txt e 'relatório final.txt'): $o_A; pedidos com nome começado por ponto, link simbólico ou FIFO: $o_fora; passada seguinte, pelo terminal: saída $r_rep, '$p_rep', e os mesmos objetos continuam uma vez só ($o_A2); cartão: $t_c75, textos que faltam ('Última passada', 'Enviado desde que foi ligado', '5 arquivos'): $f_c75"

# ------------------------------------------------------------------ o bot: gravado e testado; o conjunto B assenta
gt_1="$(grava34 telegram "$J" "$K" "$W/painel.senha" -ligado "token@$D34/token" "conversa@$D34/conversa-errada")"; tt_1="$(testa34 telegram)"
gt_2="$(grava34 telegram "$J" "$K" "$W/painel.senha" -ligado "token@$D34/token-errado" "conversa@$D34/conversa")"; tt_2="$(testa34 telegram)"
gt_3="$(grava34 telegram "$J" "$K" "$W/painel.senha" "${TG_34[@]}")"; m_tt=$(marca34); tt_3="$(testa34 telegram)"
o_tt="$(sim34 "$m_tt" "l['op']=='sendMessage' and l['codigo']==200 and l['texto']=='Teste do painel da allsafe-ftp-stack: o bot consegue enviar para esta conversa.'")"
t_ctg="$(aba -b "$J" "$B/destinos")"; f_ctg="$(faltam34 '<code>tg34</code>' 'Maior arquivo que o bot envia' 'Token do bot e conversa' 'Idioma das mensagens')"
# Conjunto B, na pasta do bot, criado depois de ele ser ligado: dois arquivos pequenos, um vazio, um que o serviço
# recusa pelo tamanho (o limite do simulador é menor que o do painel) e um acima do limite do próprio painel (1 MB).
planta34 <<'SH'
set -e
cd /data/tg34
for f in b1.txt sub/b2.txt; do echo "conteudo de $f" > "$f"; chown ftpdata:ftpdata "$f"; done
: > vazio.txt; chown ftpdata:ftpdata vazio.txt
head -c 700000 /dev/urandom > g1.bin; chown ftpdata:ftpdata g1.bin
head -c 1572864 /dev/urandom > g2.bin; chown ftpdata:ftpdata g2.bin
SH
r_plb=$?; plantioB=$SECONDS; b_B=$(( $(tam34 tg34/b1.txt) + $(tam34 tg34/sub/b2.txt) ))

# ------------------------------------------------------------------ S3: arquivo grande em partes
planta34 <<'SH'
head -c 41943040 /dev/urandom > /data/dst34/grande.bin && chown ftpdata:ftpdata /data/dst34/grande.bin
SH
s_gr="$(soma34 dst34/grande.bin)"
# A falha forçada entra na terceira chamada: a abertura e a primeira parte passam, a segunda parte recebe 500.
m_g1=$(marca34); echo 's3 500 1 2 a' > "$D34/falhar"; passa34 s3; r_g1=$?; p_g1="$(doterminal34 s3)"; rm -f "$D34/falhar"
g1_abr="$(sim34 "$m_g1" "l['op']=='abrir_partes' and l['chave']=='copias/teste/dst34/grande.bin'")"; g1_par="$(sim34 "$m_g1" "l['op']=='parte'" "l['numero']")"
g1_for="$(sim34 "$m_g1" "l['erro']=='Forcado' and l['codigo']==500 and l['metodo']=='PUT'")"; g1_aba="$(sim34 "$m_g1" "l['op']=='abandonar'")"; g1_gra="$(sim34 "$m_g1" "l['op']=='gravar'")"
m_g2=$(marca34); passa34 s3; r_g2=$?; p_g2="$(doterminal34 s3)"
g2_par="$(sim34 "$m_g2" "l['op']=='parte' and l['chave']=='copias/teste/dst34/grande.bin'" "str(l['numero'])+':'+str(l['bytes'])")"
g2_gra="$(sim34 "$m_g2" "l['op']=='gravar' and l['chave']=='copias/teste/dst34/grande.bin' and l['partes']==3 and l['bytes']==41943040 and l['sha256']=='$s_gr'")"

# ------------------------------------------------------------------ S3: a falha encerra a passada
auditoria; n_f500="$(linhas34 ' evento=destino_falhou destino=s3 motivo=http_500$')"
planta34 <<'SH'
cd /data/dst34 && for n in 1 2 3; do echo "p$n" > "p$n.txt"; chown ftpdata:ftpdata "p$n.txt"; done
SH
# A primeira gravação passa e a segunda recebe 500: a passada para ali, sem tentar o terceiro arquivo.
m_p=$(marca34); echo 's3 500 1 1 b' > "$D34/falhar"; passa34 s3; r_p1=$?; p_p1="$(doterminal34 s3)"; rm -f "$D34/falhar"
o_p1="$(sim34 "$m_p" "l['servico']=='s3'" "str(l['codigo'])+':'+l['chave'].rsplit('/', 1)[-1]")"
aba -b "$J" "$B/destinos" > /dev/null; f_parou="$(tem34 'A última passada parou antes do fim: o serviço respondeu com o código 500. A seguinte recomeça do mesmo arquivo.')"
passa34 s3; r_p2=$?; p_p2="$(doterminal34 s3)"; o_p=""; for n in 1 2 3; do o_p+="$(obj34 0 "dst34/p$n.txt") "; done
auditoria; d_f500=$(( $(linhas34 ' evento=destino_falhou destino=s3 motivo=http_500$') - n_f500 ))
# O arquivo que o serviço recusa com 4xx: duas passadas param nele, a terceira o deixa para trás e segue.
conf34 recusa34
planta34 <<'SH'
cd /data/dst34 && for n in q1-recusa34 q2; do echo "$n" > "$n.txt"; chown ftpdata:ftpdata "$n.txt"; done
SH
t_q2="$(tam34 dst34/q2.txt)"
passa34 s3; r_q1=$?; p_q1="$(doterminal34 s3)"; passa34 s3; r_q2=$?; p_q2="$(doterminal34 s3)"; passa34 s3; r_q3=$?; p_q3="$(doterminal34 s3)"
conf34
auditoria; l_f400="$(linhas34 ' evento=destino_falhou destino=s3 motivo=http_400$')"; l_pul="$(linhas34 ' evento=destino_pulado destino=s3 arquivo=dst34/q1-recusa34.txt motivo=http_400$')"
o_q1="$(sim34 0 "l['op']=='gravar' and 'recusa34' in l['chave']")"; o_q1r="$(sim34 0 "l['erro']=='InvalidRequest' and 'recusa34' in l['chave']")"; o_q2="$(obj34 0 dst34/q2.txt)"
[[ "$r_p1" == 1 && "$p_p1" == "s3: 1 arquivo(s), 3 bytes, $SEM34; parou: http_500" && "$o_p1" == "200:p1.txt 500:p2.txt" && "$f_parou" -ge 1 && "$r_p2" == 0 \
  && "$p_p2" == "s3: 2 arquivo(s), 6 bytes, $SEM34; chegou ao fim" && "$o_p" == "1 1 1 " && "$d_f500" == 1 && "$r_q1$r_q2$r_q3" == 110 \
  && "$p_q1" == "s3: 0 arquivo(s), 0 bytes, $SEM34; parou: http_400" && "$p_q2" == "$p_q1" \
  && "$p_q3" == "s3: 1 arquivo(s), $t_q2 bytes, 0 apagado(s) do servidor, 0 acima do limite do bot, 0 ignorado(s), 1 recusado(s); chegou ao fim" \
  && "$l_f400" == 1 && "$l_pul" == 1 && "$o_q1" == 0 && "$o_q1r" -ge 2 && "$o_q2" == 1 ]]
caso $? testes 77 "S3: a falha encerra a passada e a seguinte recomeça do mesmo arquivo" "três arquivos novos (p1, p2 e p3) e o serviço respondendo 500 na segunda gravação: saída $r_p1, '$p_p1', pedidos que o simulador recebeu: $o_p1 (o terceiro nem foi tentado); cartão com 'A última passada parou antes do fim: o serviço respondeu com o código 500. A seguinte recomeça do mesmo arquivo.': $f_parou; destino_falhou motivo=http_500 a mais na auditoria: $d_f500; passada seguinte: saída $r_p2, '$p_p2', e cada um dos três gravado uma vez só: $o_p; arquivo que o serviço recusa com 400 (q1) e outro depois dele (q2): 1ª passada saída $r_q1, '$p_q1'; 2ª saída $r_q2, '$p_q2'; 3ª saída $r_q3, '$p_q3'; auditoria: destino_falhou motivo=http_400 $l_f400 (o motivo repetido não repete a linha), destino_pulado do q1 $l_pul; no simulador: q1 recusado $o_q1r vezes e gravado $o_q1, q2 gravado $o_q2"

# ------------------------------------------------------------------ o bot: envia o que chega e avisa do que passa do limite
while (( SECONDS - plantioB < 125 )); do sleep 3; done
a_79="$(envio /destinos/agora --data-urlencode "csrf=$K" --data-urlencode "destino=telegram")"
aba -b "$J" "$B/destinos?m=pedido" > /dev/null; f_ped="$(tem34 'Passada pedida: o painel começa em instantes.')"
aguarda34 " evento=destino_enviado destino=telegram arquivos=2 bytes=$b_B apagados=0 grandes=2 ignorados=1 erros=0\$" 1 100; r_p79=$?
l_ped="$(linhas34 " evento=destino_pedido admin=$ADMIN destino=telegram\$")"
d_b="$(doc34 0 tg34/b1.txt) $(doc34 0 tg34/sub/b2.txt)"
d_413="$(sim34 0 "l['op']=='sendDocument' and l['codigo']==413 and l['bytes']==700000")"
av_g="$(for n in g1 g2; do sim34 0 "l['op']=='sendMessage' and l['codigo']==200 and (l['texto'] or '').startswith('Arquivo maior que o limite de envio do bot (') and '\ntg34/$n.bin\n' in l['texto'] and bool(re.search(r' · $DATA34\$', l['texto']))"; done | tr '\n' ' ')"
d_g2="$(sim34 0 "l['op']=='sendDocument' and l['bytes']==1572864")"; d_vaz="$(sim34 0 "l['op']=='sendDocument' and l['arquivo']=='vazio.txt'")"
d_ant="$(sim34 0 "l['servico']=='telegram' and 'antes.txt' in ((l['arquivo'] or '') + (l['texto'] or '') + (l['legenda'] or ''))")"
# Pelo terminal: a API pede para ir mais devagar (429) e o painel espera e repete o mesmo envio, uma vez.
planta34 <<'SH'
cd /data/tg34 && echo b3 > b3.txt && chown ftpdata:ftpdata b3.txt
SH
m_b3=$(marca34); echo 'telegram 429 1' > "$D34/falhar"; passa34 telegram; r_b3=$?; p_b3="$(doterminal34 telegram)"; rm -f "$D34/falhar"
d_429="$(sim34 "$m_b3" "l['op']=='sendDocument'" "l['codigo']")"; d_b3="$(doc34 0 tg34/b3.txt)"
# Idioma das mensagens trocado, sem digitar os segredos: o andamento continua (nada é reenviado) e o aviso sai em inglês.
g_en="$(grava34 telegram "$J" "$K" "$W/painel.senha" idioma=en)"
planta34 <<'SH'
cd /data/tg34 && head -c 1572864 /dev/urandom > g3.bin && chown ftpdata:ftpdata g3.bin
SH
passa34 telegram; r_g3=$?; p_g3="$(doterminal34 telegram)"
av_g3="$(sim34 0 "l['op']=='sendMessage' and (l['texto'] or '').startswith('File larger than the bot sending limit (') and '\ntg34/g3.bin\n' in l['texto'] and bool(re.search(r' · \d{4}-\d\d-\d\d\s\d\d:\d\d\$', l['texto']))")"
d_b_fim="$(doc34 0 tg34/b1.txt) $(doc34 0 tg34/sub/b2.txt) $(doc34 0 tg34/b3.txt)"
auditoria; l_gen="$(linhas34 " evento=destino_gravado admin=$ADMIN destino=telegram situacao=ligado pasta=tg34 intervalo=1440 segredos=mantidos\$")"
[[ "$gt_1" == "303 /destinos?m=gravado" && "$tt_1" == "303 /destinos?m=falha&d=telegram&f=nao_encontrado" && "$gt_2" == "303 /destinos?m=gravado" \
  && "$tt_2" == "303 /destinos?m=falha&d=telegram&f=recusado" && "$gt_3" == "303 /destinos?m=gravado" && "$tt_3" == "303 /destinos?m=teste" && "$o_tt" == 1 \
  && "$t_ctg" == "200 " && "$f_ctg" == 0 && "$r_plb" == 0 && "$a_79" == "303 /destinos?m=pedido" && "$f_ped" -ge 1 && "$r_p79" == 0 && "$l_ped" == 1 && "$d_b" == "1 1" \
  && "$d_413" == 1 && "$av_g" == "1 1 " && "$d_g2" == 0 && "$d_vaz" == 0 && "$d_ant" == 0 && "$r_b3" == 0 && "$p_b3" == "telegram: 1 arquivo(s), 3 bytes, $SEM34; chegou ao fim" \
  && "$d_429" == "429 200" && "$d_b3" == 1 && "$g_en" == "303 /destinos?m=gravado" && "$r_g3" == 0 \
  && "$p_g3" == "telegram: 0 arquivo(s), 0 bytes, 0 apagado(s) do servidor, 1 acima do limite do bot, 0 ignorado(s), 0 recusado(s); chegou ao fim" \
  && "$av_g3" == 1 && "$d_b_fim" == "1 1 1" && "$l_gen" == 1 ]]
caso $? testes 79 "Bot do Telegram: envia o que chega e avisa do que passa do limite" "bot gravado desligado com a conversa errada: $gt_1, teste $tt_1; com o token errado: $gt_2, teste $tt_2; ligado com os certos: $gt_3, teste $tt_3 e a mensagem de teste na conversa ($o_tt); cartão: $t_ctg, textos que faltam (pasta, limite, idioma e segredos): $f_ctg; cinco arquivos criados depois de ligar (dois pequenos, um vazio, um de 700000 bytes e um de 1572864, com o limite do painel em 1 MB e o do serviço em 600000 bytes) e, passados os dois minutos, o botão Enviar agora: $a_79, tela com 'Passada pedida' ($f_ped), destino_pedido $l_ped e destino_enviado com arquivos=2 bytes=$b_B grandes=2 ignorados=1 (espera: $r_p79); documentos entregues com nome, tamanho, SHA-256 e legenda 'caminho, tamanho · data' (b1.txt e sub/b2.txt): $d_b; o de 700000 bytes recusado pelo serviço com 413: $d_413; avisos 'Arquivo maior que o limite de envio do bot' com o caminho e a data (g1 e g2): $av_g; documento de 1572864 bytes enviado: $d_g2; arquivo vazio enviado: $d_vaz; arquivo que já estava na pasta antes de o bot ser ligado: $d_ant; pelo terminal, com o serviço respondendo 429 uma vez: saída $r_b3, '$p_b3', respostas ao envio do b3.txt: $d_429, entregue $d_b3 vez; idioma trocado para inglês sem digitar os segredos: $g_en (destino_gravado com segredos=mantidos: $l_gen), arquivo novo acima do limite: saída $r_g3, '$p_g3', aviso 'File larger than the bot sending limit' com a data em ano-mês-dia: $av_g3; b1, b2 e b3 entregues uma vez só no total: $d_b_fim"

# ------------------------------------------------------------------ Guardar no S3: sai do servidor depois de gravado e entregue
passa34 s3; r_c0=$?
# O bot passa a olhar a mesma pasta do S3: o que já está nela não é dele, só o que chegar daqui em diante.
g_tm="$(grava34 telegram "$J" "$K" "$W/painel.senha" pasta=dst34 idioma=pt)"; passou34 telegram; r_tm=$?
g_mv="$(grava34 s3 "$J" "$K" "$W/painel.senha" modo=mover)"
aba -b "$J" "$B/destinos" > /dev/null; f_mv="$(tem34 'Guardar no S3: o arquivo sai do servidor depois de gravado no destino')"
novo34() { docker exec "$FTP" sh -c 'head -c 3000 /dev/urandom > "/data/dst34/$1" && chown ftpdata:ftpdata "/data/dst34/$1"' sh "$1"; }  # <nome>: arquivo novo de 3000 bytes
L3='3000 bytes, 0 apagado(s) do servidor, 0 acima do limite do bot, 0 ignorado(s), 0 recusado(s)'
A3='3000 bytes, 1 apagado(s) do servidor, 0 acima do limite do bot, 0 ignorado(s), 0 recusado(s)'
# m1: o bot entrega, o S3 grava e o arquivo sai do servidor na mesma passada.
novo34 m1.bin; s_m1="$(soma34 dst34/m1.bin)"
passa34 s3; r_m1=$?; p_m1="$(doterminal34 telegram) | $(doterminal34 s3)"; h_m1="$(ha34 dst34/m1.bin)"; h_a1="$(ha34 dst34/a1.txt)"
c_m1="$(doc34 0 dst34/m1.bin "$s_m1" 3000) $(obj34 0 dst34/m1.bin "$s_m1" 3000) $(obj34 0 dst34/a1.txt)"
# m2: o S3 falha. O bot entrega, nada é apagado; na passada seguinte o S3 grava e o arquivo sai.
novo34 m2.bin; s_m2="$(soma34 dst34/m2.bin)"
echo 's3 500' > "$D34/falhar"; passa34 s3; r_m2=$?; p_m2="$(doterminal34 telegram) | $(doterminal34 s3)"; rm -f "$D34/falhar"; h_m2="$(ha34 dst34/m2.bin)"
passa34 s3; r_m2b=$?; p_m2b="$(doterminal34 telegram) | $(doterminal34 s3)"; h_m2b="$(ha34 dst34/m2.bin)"
c_m2="$(doc34 0 dst34/m2.bin "$s_m2" 3000) $(obj34 0 dst34/m2.bin "$s_m2" 3000)"
# m3: o bot falha. O S3 grava e o arquivo fica à espera do bot; quando ele entrega, a passada do S3 apaga.
novo34 m3.bin; s_m3="$(soma34 dst34/m3.bin)"
echo 'telegram 500' > "$D34/falhar"; passa34 s3; r_m3=$?; p_m3="$(doterminal34 telegram) | $(doterminal34 s3)"; rm -f "$D34/falhar"; h_m3="$(ha34 dst34/m3.bin)"
aba -b "$J" "$B/destinos" > /dev/null; f_esp="$(faltam34 'À espera do bot' '1 arquivo já gravado no S3 sai do servidor quando o bot do Telegram o entregar')"
passa34 s3; r_m3b=$?; p_m3b="$(doterminal34 telegram) | $(doterminal34 s3)"; h_m3b="$(ha34 dst34/m3.bin)"
c_m3="$(doc34 0 dst34/m3.bin "$s_m3" 3000) $(obj34 0 dst34/m3.bin "$s_m3" 3000)"
aba -b "$J" "$B/destinos" > /dev/null; f_esp2="$(tem34 'À espera do bot')"
[[ "$r_c0" == 0 && "$g_tm" == "303 /destinos?m=gravado" && "$r_tm" == 0 && "$g_mv" == "303 /destinos?m=gravado" && "$f_mv" -ge 1 \
  && "$r_m1" == 0 && "$p_m1" == "telegram: 1 arquivo(s), $L3; chegou ao fim | s3: 1 arquivo(s), $A3; chegou ao fim" && "$h_m1" == nao && "$h_a1" == sim && "$c_m1" == "1 1 1" \
  && "$r_m2" == 1 && "$p_m2" == "telegram: 1 arquivo(s), $L3; chegou ao fim | s3: 0 arquivo(s), 0 bytes, $SEM34; parou: http_500" && "$h_m2" == sim \
  && "$r_m2b" == 0 && "$p_m2b" == "telegram: 0 arquivo(s), 0 bytes, $SEM34; chegou ao fim | s3: 1 arquivo(s), $A3; chegou ao fim" && "$h_m2b" == nao && "$c_m2" == "1 1" \
  && "$r_m3" == 1 && "$p_m3" == "telegram: 0 arquivo(s), 0 bytes, $SEM34; parou: http_500 | s3: 1 arquivo(s), $L3; chegou ao fim" && "$h_m3" == sim && "$f_esp" == 0 \
  && "$r_m3b" == 0 && "$p_m3b" == "telegram: 1 arquivo(s), $L3; chegou ao fim | s3: 0 arquivo(s), 0 bytes, 1 apagado(s) do servidor, 0 acima do limite do bot, 0 ignorado(s), 0 recusado(s); chegou ao fim" \
  && "$h_m3b" == nao && "$c_m3" == "1 1" && "$f_esp2" == 0 ]]
caso $? testes 78 "Guardar no S3: o arquivo sai do servidor depois de gravado e de o bot entregar" "passada de cópia antes da troca: saída $r_c0; bot regravado na pasta do S3: $g_tm (primeira passada dele: $r_tm); S3 regravado com o modo Guardar: $g_mv, cartão com o modo ($f_mv); m1, com tudo no ar: saída $r_m1, '$p_m1', ainda no servidor: $h_m1, a1.txt (enviado antes da troca) ainda no servidor: $h_a1; documento do m1, objeto do m1 e objeto do a1.txt no simulador: $c_m1; m2, com o S3 respondendo 500: saída $r_m2, '$p_m2', no servidor: $h_m2; passada seguinte: saída $r_m2b, '$p_m2b', no servidor: $h_m2b, documento e objeto do m2: $c_m2; m3, com o bot respondendo 500: saída $r_m3, '$p_m3', no servidor: $h_m3, textos de 'À espera do bot' que faltam no cartão: $f_esp; passada seguinte: saída $r_m3b, '$p_m3b', no servidor: $h_m3b, documento e objeto do m3: $c_m3, 'À espera do bot' no cartão: $f_esp2"

# ------------------------------------------------------------------ S3: o bucket no nome do endereço
# Estilo e pasta trocados: é outro lugar, e a primeira passada envia o que há na pasta nova.
m_h=$(marca34); g_host="$(grava34 s3 "$J" "$K" "$W/painel.senha" estilo=host pasta=dst34/sub)"
passa34 s3; passou34 s3; r_h=$?
o_host="$(sim34 "$m_h" "l['op']=='gravar' and l['chave']=='copias/teste/dst34/sub/a3.txt' and l['estilo']=='host' and l['bucket']=='balde34' and l['sha256']=='$(soma34 dst34/sub/a3.txt)'")"
o_host_n="$(sim34 "$m_h" "l['servico']=='s3'")"
[[ "$r_g1" == 1 && "$p_g1" == "s3: 0 arquivo(s), 0 bytes, $SEM34; parou: http_500" && "$g1_abr" == 1 && "$g1_par" == 1 && "$g1_for" == 1 && "$g1_aba" == 1 && "$g1_gra" == 0 \
  && "$r_g2" == 0 && "$p_g2" == "s3: 1 arquivo(s), 41943040 bytes, $SEM34; chegou ao fim" && "$g2_par" == "1:16777216 2:16777216 3:8388608" && "$g2_gra" == 1 \
  && "$g_host" == "303 /destinos?m=gravado" && "$r_h" == 0 && "$o_host" == 1 && "$o_host_n" == 1 ]]
caso $? testes 76 "S3: arquivo grande em partes e bucket no nome do endereço" "arquivo de 41943040 bytes, com o serviço respondendo 500 na segunda parte: saída $r_g1, '$p_g1'; no simulador: envio em partes aberto $g1_abr, parte recebida: $g1_par, parte recusada $g1_for, envio abandonado pelo painel $g1_aba, objeto gravado $g1_gra; passada seguinte: saída $r_g2, '$p_g2', partes e tamanhos: $g2_par, objeto fechado com 3 partes, 41943040 bytes e o SHA-256 do arquivo: $g2_gra; S3 regravado com o bucket no nome do endereço e a pasta dst34/sub: $g_host, primeira passada do lugar novo (espera: $r_h): pedidos ao S3: $o_host_n, objeto copias/teste/dst34/sub/a3.txt recebido em balde34.s3.simulador.test com o SHA-256 do arquivo: $o_host"

# ------------------------------------------------------------------ o bot envia em instantes o que chega inteiro
# O bot está em dst34 e o S3, em dst34/sub. O envio por FTP e o envio pelo painel são anunciados à linha de execução
# dos destinos: o bot não espera os dois minutos nem o intervalo. O S3 não recebe anúncio. O arquivo que aparece por
# outro caminho (i2, criado dentro do container) não é anunciado: espera os dois minutos e segura a fila atrás dele.
sha34() { sha256sum < "$1" | cut -c1-64; }                                                     # <arquivo local>: SHA-256 dele
entrega34() { # <linhas a pular> <arquivo dentro de /data> <soma> <segundos>: espera o bot entregar; devolve os segundos que levou
  local marca=$SECONDS
  while (( SECONDS - marca < $4 )) && [[ "$(doc34 "$1" "$2" "$3" 3000)" == 0 ]]; do sleep 1; done
  echo $(( SECONDS - marca ))
}
manda34() { # <pasta> <nome> <arquivo local>: envio pelo painel, com a sessão do administrador → "código destino"
  c --max-time 60 -o /dev/null -w '%{http_code} %{redirect_url}' -b "$J" -H "Origin: $B" --form-string "csrf=$K" --form-string "pasta=$1" \
    --form-string "nome=$2" -F "arquivo=@\"$3\";filename=\"$2\"" "$B/arquivos/enviar" | sed "s|$B||"
}
arq34() { POTE="${POTE:-$J}" envio /destinos/arquivo --max-time 40 --data-urlencode "csrf=$1" --data-urlencode "destino=$2" --data-urlencode "arquivo=$3"; }  # <token> <destino> <arquivo>: o botão da linha do arquivo
especial34() { # <nome> <texto>: quantas linhas da lista com esse nome têm o texto
  sed 's#</tr>#\n#g' "$W/corpo" | grep -F "$1</span>" | grep -c -F -- "$2" || true
}
estado34() { docker exec "$PAINEL" sha256sum "/painel/destinos/$1.estado" | cut -c1-64; }      # <destino>: soma do andamento dele
L1=' evento=destino_enviado destino=telegram arquivos=1 bytes=3000 apagados=0 grandes=0 ignorados=0 erros=0$'
L2=' evento=destino_enviado destino=telegram arquivos=2 bytes=6000 apagados=0 grandes=0 ignorados=0 erros=0$'
for n in a b c; do head -c 3000 /dev/urandom > "$W/i34.$n"; done
auditoria; n_l1="$(linhas34 "$L1")"; n_l2="$(linhas34 "$L2")"; m_81=$(marca34)
# Por FTP, dentro da pasta do S3 também: o bot entrega; o S3, nem com o botão Enviar agora, antes dos dois minutos.
f_i1="$(ftp_curl tls dst34 "$W/dst34.senha" -T "$W/i34.a" "$F/sub/i1.bin")"; s_i1="$(entrega34 "$m_81" dst34/sub/i1.bin "$(sha34 "$W/i34.a")" 30)"
d_i1="$(doc34 "$m_81" dst34/sub/i1.bin "$(sha34 "$W/i34.a")" 3000)"; aguarda34 "$L1" $(( n_l1 + 1 )) 30; r_l1=$?
a_i1="$(envio /destinos/agora --data-urlencode "csrf=$K" --data-urlencode "destino=s3")"
UM34='1 arquivo mudou há menos de dois minutos e ainda pode estar chegando: vai em uma próxima passada'
marca=$SECONDS; while aba -b "$J" "$B/destinos" > /dev/null; (( SECONDS - marca < 25 )) && [[ "$(tem34 "$UM34")" == 0 ]]; do sleep 2; done
f_um="$(faltam34 'Ainda chegando' "$UM34")"; o_i1="$(sim34 "$m_81" "l['servico']=='s3'")"
# Pelo painel, com a sessão do administrador.
m_ip=$(marca34); p_ip="$(manda34 dst34 i-painel.bin "$W/i34.b")"; s_ip="$(entrega34 "$m_ip" dst34/i-painel.bin "$(sha34 "$W/i34.b")" 30)"
d_ip="$(doc34 "$m_ip" dst34/i-painel.bin "$(sha34 "$W/i34.b")" 3000)"; aguarda34 "$L1" $(( n_l1 + 2 )) 30; r_l1b=$?
# i2 sem anúncio e, logo depois, i3 por FTP: nenhum dos dois sai enquanto o i2 não assenta.
novo34 i2.bin; s_i2="$(soma34 dst34/i2.bin)"; m_c=$(marca34); inicio_c=$SECONDS
f_i3="$(ftp_curl tls dst34 "$W/dst34.senha" -T "$W/i34.c" "$F/i3.bin")"
DOIS34='2 arquivos mudaram há menos de dois minutos e ainda podem estar chegando: vão em uma próxima passada'
marca=$SECONDS; while aba -b "$J" "$B/destinos" > /dev/null; (( SECONDS - marca < 25 )) && [[ "$(tem34 "$DOIS34")" == 0 ]]; do sleep 2; done
f_dois="$(faltam34 'Ainda chegando' "$DOIS34")"
while (( SECONDS - inicio_c < 14 )); do sleep 1; done
d_cedo="$(sim34 "$m_c" "l['servico']=='telegram'")"

# ------------------------------------------------------------------ o botão da linha do arquivo, na aba Arquivos
# Enquanto o i2 assenta. O envio de um arquivo só usa o que está gravado, não mexe no andamento das passadas e não
# apaga nada, nem com o S3 no modo Guardar.
t_82="$(aba -b "$J" "$B/arquivos?pasta=dst34")"; n_bx="$(vezes34 ' download>')"
b_82="$(vezes34 'id="para-telegram"') $(vezes34 'id="para-s3"') $(( $(vezes34 'form="para-telegram"') - n_bx )) $(( $(vezes34 'form="para-s3"') - n_bx ))"
b_esp="$(especial34 atalho 'não abre aqui'):$(especial34 atalho 'form="para-') $(especial34 cano 'não abre aqui'):$(especial34 cano 'form="para-')"
auditoria; n_arq="$(eventos destino_arquivo)"; e_tg0="$(estado34 telegram)"; e_s30="$(estado34 s3)"; m_82=$(marca34)
x_tg="$(arq34 "$K" telegram dst34/a1.txt)"; d_a1="$(doc34 "$m_82" dst34/a1.txt)"
aba -b "$J" "$B/arquivos?pasta=dst34&m=destino_ok&d=telegram" > /dev/null; f_tgok="$(tem34 'Bot do Telegram: arquivo enviado.')"
x_vaz="$(arq34 "$K" telegram dst34/vazio.txt)"
aba -b "$J" "$B/arquivos?pasta=dst34&m=destino_falha&d=telegram&f=vazio" > /dev/null; f_vaz="$(tem34 'Bot do Telegram: não deu certo. Motivo: o arquivo está vazio, e o bot não envia arquivo vazio.')"
x_lim="$(arq34 "$K" telegram dst34/grande.bin)"
d_82="$(sim34 "$m_82" "l['servico']=='telegram'")"; e_tg1="$(estado34 telegram)"
x_s3="$(arq34 "$K" s3 dst34/a1.txt)"; x_s3v="$(arq34 "$K" s3 dst34/vazio.txt)"
o_82="$(sim34 "$m_82" "l['op']=='gravar' and l['estilo']=='host' and l['chave']=='copias/teste/dst34/a1.txt' and l['sha256']=='$(soma34 dst34/a1.txt)'") $(sim34 "$m_82" "l['op']=='gravar' and l['chave']=='copias/teste/dst34/vazio.txt' and l['bytes']==0")"
aba -b "$J" "$B/arquivos?pasta=dst34&m=destino_ok&d=s3" > /dev/null; f_s3ok="$(tem34 'Armazenamento S3: arquivo enviado.')"
e_s31="$(estado34 s3)"
# Com o S3 no modo Guardar: o arquivo enviado pelo botão continua no servidor.
g_mv2="$(grava34 s3 "$J" "$K" "$W/painel.senha" modo=mover estilo=host pasta=dst34/sub)"
x_mv="$(arq34 "$K" s3 dst34/sub/a3.txt)"; h_a3="$(ha34 dst34/sub/a3.txt)"
o_mv="$(sim34 "$m_82" "l['op']=='gravar' and l['chave']=='copias/teste/dst34/sub/a3.txt' and l['sha256']=='$(soma34 dst34/sub/a3.txt)'")"
g_cp2="$(grava34 s3 "$J" "$K" "$W/painel.senha" estilo=host pasta=dst34/sub)"
auditoria; d_arq=$(( $(eventos destino_arquivo) - n_arq ))
l_arq="$(linhas34 " evento=destino_arquivo admin=$ADMIN destino=telegram arquivo=dst34/a1\.txt bytes=$(tam34 dst34/a1.txt) resultado=ok\$")"
l_arq+=" $(linhas34 " evento=destino_arquivo admin=$ADMIN destino=telegram arquivo=dst34/vazio\.txt bytes=0 resultado=vazio\$")"
l_arq+=" $(linhas34 " evento=destino_arquivo admin=$ADMIN destino=telegram arquivo=dst34/grande\.bin bytes=41943040 resultado=limite\$")"
l_arq+=" $(linhas34 " evento=destino_arquivo admin=$ADMIN destino=s3 arquivo=dst34/a1\.txt bytes=$(tam34 dst34/a1.txt) resultado=ok\$")"
l_arq+=" $(linhas34 " evento=destino_arquivo admin=$ADMIN destino=s3 arquivo=dst34/sub/a3\.txt bytes=$(tam34 dst34/sub/a3.txt) resultado=ok\$")"

# ------------------------------------------------------------------ o botão é só do administrador, com token
# Ainda dentro da espera do i2: nenhuma destas recusas chega ao serviço de fora nem vira envio na auditoria.
m_130=$(marca34); auditoria; n_arq2="$(eventos destino_arquivo)"; n_cam="$(eventos recusa_caminho)"
z_semtoken="$(arq34 '' telegram dst34/a1.txt)"; z_token="$(arq34 token-errado telegram dst34/a1.txt)"
z_origem="$(c -o /dev/null -w '%{http_code} %{redirect_url}' -b "$J" -H 'Origin: https://fora.example' --data-urlencode "csrf=$K" --data-urlencode destino=telegram --data-urlencode arquivo=dst34/a1.txt "$B/destinos/arquivo" | sed "s|$B||")"
z_semsessao="$(POTE="$W/vazio34.jar" arq34 "$K" telegram dst34/a1.txt)"
z_dest="$(arq34 "$K" ftp dst34/a1.txt)"
z_cam="$(arq34 "$K" telegram dst34/../dst34/a1.txt)$(arq34 "$K" s3 /dst34/a1.txt)$(arq34 "$K" telegram dst34/atalho)$(arq34 "$K" telegram dst34/nao-existe.txt)$(arq34 "$K" s3 dst34/sub)$(arq34 "$K" telegram dst34/cano)$(arq34 "$K" telegram '')"
# O usuário do FTP dono da pasta: não vê botão em Meus arquivos e a rota não existe para ele.
e_usu2="$(COMO=dst34 entrar "$W/dst34.jar" "$W/dst34.senha")"; proibir "$(biscoito_de "$W/dst34.jar")"; K_u2="$(token34 "$W/dst34.jar")"; proibir "$K_u2"
u_tela="$(aba -b "$W/dst34.jar" "$B/meus-arquivos")"; u_bot="$(tem34 'a1.txt') $(vezes34 'para-') $(vezes34 '/destinos')"
u_arq="$(POTE="$W/dst34.jar" arq34 "$K_u2" telegram a1.txt)$(POTE="$W/dst34.jar" arq34 "$K_u2" s3 dst34/a1.txt)"
auditoria; d_130=$(( $(marca34) - m_130 )); d_arq2=$(( $(eventos destino_arquivo) - n_arq2 )); d_cam=$(( $(eventos recusa_caminho) - n_cam ))

# Passados os dois minutos, a linha de execução volta sozinha e entrega o i2 e o i3, nessa ordem, uma vez cada.
marca=$SECONDS; while (( SECONDS - inicio_c < 200 )) && [[ "$(doc34 "$m_c" dst34/i3.bin "$(sha34 "$W/i34.c")" 3000)" == 0 ]]; do sleep 3; done
s_fila=$(( SECONDS - inicio_c )); aguarda34 "$L2" $(( n_l2 + 1 )) 30; r_l2=$?
d_fila="$(sim34 "$m_c" "l['op']=='sendDocument' and l['arquivo'] in ('i2.bin', 'i3.bin')" "l['arquivo']+':'+str(l['codigo'])")"
d_i23="$(doc34 "$m_c" dst34/i2.bin "$s_i2" 3000) $(doc34 "$m_c" dst34/i3.bin "$(sha34 "$W/i34.c")" 3000)"
d_tot="$(doc34 0 dst34/sub/i1.bin "$(sha34 "$W/i34.a")" 3000) $(doc34 0 dst34/i-painel.bin "$(sha34 "$W/i34.b")" 3000) $(doc34 0 dst34/a1.txt)"
aba -b "$J" "$B/destinos" > /dev/null; f_dois2="$(tem34 "$DOIS34")"
[[ "$f_i1" == 0 && "$s_i1" -le 20 && "$d_i1" == 1 && "$r_l1" == 0 && "$a_i1" == "303 /destinos?m=pedido" && "$f_um" == 0 && "$o_i1" == 0 \
  && "$p_ip" == "303 /arquivos?pasta=dst34&m=enviado" && "$s_ip" -le 20 && "$d_ip" == 1 && "$r_l1b" == 0 && "$f_i3" == 0 && "$f_dois" == 0 && "$d_cedo" == 0 \
  && "$s_fila" -ge 100 && "$s_fila" -lt 200 && "$r_l2" == 0 && "$d_fila" == "i2.bin:200 i3.bin:200" && "$d_i23" == "1 1" && "$d_tot" == "1 1 1" && "$f_dois2" == 0 ]]
caso $? testes 81 "Bot do Telegram: o arquivo que chega inteiro sai em instantes" "bot na pasta dst34 e S3 em dst34/sub, os dois com intervalo de 1440 minutos; arquivo de 3000 bytes enviado por FTP para dst34/sub (curl: $f_i1): documento na conversa, com o SHA-256 do arquivo enviado, em $s_i1 s ($d_i1 vez; destino_enviado com arquivos=1 na auditoria: espera $r_l1); o S3 não recebe o anúncio: botão Enviar agora dele logo em seguida: $a_i1, textos de 'Ainda chegando' e '1 arquivo mudou há menos de dois minutos' que faltam no cartão: $f_um, pedidos que o simulador do S3 recebeu: $o_i1; arquivo enviado pelo painel, pelo administrador: $p_ip, documento na conversa em $s_ip s ($d_ip vez; auditoria: espera $r_l1b); arquivo criado dentro do container, sem anúncio (i2), e outro por FTP logo depois (i3, curl: $f_i3): textos de 'Ainda chegando' e '2 arquivos mudaram há menos de dois minutos' que faltam no cartão do bot: $f_dois, pedidos ao bot nos primeiros 14 s: $d_cedo; sem ninguém pedir, os dois na conversa $s_fila s depois do i2, na ordem de chegada: $d_fila (cada um com o SHA-256 dele: $d_i23; destino_enviado com arquivos=2: espera $r_l2); no total, i1, o do painel e o a1.txt (pedido pelo botão no meio da espera) uma vez cada: $d_tot; '2 arquivos mudaram' no cartão depois da entrega: $f_dois2"

[[ "$v_des" == "303 /arquivos?pasta=tg34&m=destino_ok&d=s3" && "$v_obj" == 1 && "$v_sit" == "s3: desligado; pasta /data/dst34; a cada 1440 min; nenhuma passada ainda" \
  && "$t_82" == "200 " && "$n_bx" -ge 5 && "$b_82" == "1 1 0 0" && "$b_esp" == "1:0 1:0" \
  && "$x_tg" == "303 /arquivos?pasta=dst34&m=destino_ok&d=telegram" && "$d_a1" == 1 && "$f_tgok" -ge 1 && "$x_vaz" == "303 /arquivos?pasta=dst34&m=destino_falha&d=telegram&f=vazio" && "$f_vaz" -ge 1 \
  && "$x_lim" == "303 /arquivos?pasta=dst34&m=destino_falha&d=telegram&f=limite" && "$d_82" == 1 && "$e_tg0" == "$e_tg1" && ${#e_tg0} == 64 \
  && "$x_s3" == "303 /arquivos?pasta=dst34&m=destino_ok&d=s3" && "$x_s3v" == "$x_s3" && "$o_82" == "1 1" && "$f_s3ok" -ge 1 && "$e_s30" == "$e_s31" && ${#e_s30} == 64 \
  && "$g_mv2" == "303 /destinos?m=gravado" && "$x_mv" == "303 /arquivos?pasta=dst34/sub&m=destino_ok&d=s3" && "$h_a3" == sim && "$o_mv" == 1 && "$g_cp2" == "303 /destinos?m=gravado" \
  && "$d_arq" == 6 && "$l_arq" == "1 1 1 1 1" ]]
caso $? testes 82 "Envio de um arquivo pelo botão da aba Arquivos" "com o S3 gravado e desligado, antes de qualquer passada, arquivo de fora da pasta dele (tg34/antes.txt): $v_des, objeto com o SHA-256 no simulador: $v_obj, e o terminal segue com '$v_sit'; com os dois destinos ligados, aba Arquivos em dst34: $t_82, links Baixar: $n_bx; formulários ocultos do bot e do S3 e, depois, a diferença entre os botões de cada destino e os links Baixar: $b_82; linha do link simbólico e linha do FIFO, cada uma com a quantidade de botões de destino: $b_esp; a1.txt pelo bot: $x_tg, documento com nome, tamanho, SHA-256 e legenda na conversa: $d_a1, tela com 'Bot do Telegram: arquivo enviado.' ($f_tgok); arquivo vazio pelo bot: $x_vaz, tela com o motivo ($f_vaz); arquivo de 41943040 bytes pelo bot, com o limite em 1 MB: $x_lim; pedidos que o bot do simulador recebeu nos três: $d_82; andamento do bot igual antes e depois: $([[ "$e_tg0" == "$e_tg1" ]] && echo sim || echo nao); a1.txt e arquivo vazio para o S3: $x_s3 e $x_s3v, objetos no simulador (a1.txt com o bucket no nome do endereço e o SHA-256; vazio com 0 bytes): $o_82, tela com 'Armazenamento S3: arquivo enviado.' ($f_s3ok); andamento do S3 igual antes e depois: $([[ "$e_s30" == "$e_s31" ]] && echo sim || echo nao); S3 regravado no modo Guardar: $g_mv2, sub/a3.txt pelo botão: $x_mv, objeto gravado: $o_mv, arquivo ainda no servidor: $h_a3; S3 de volta ao modo Copiar: $g_cp2; destino_arquivo a mais na auditoria: $d_arq, com administrador, destino, arquivo, bytes e resultado (a1 pelo bot ok, vazio, limite, a1 no S3 ok, a3 no S3 ok): $l_arq"

# ------------------------------------------------------------------ segredos fora das telas e dos registros
: > "$W/telas34"
for n in /destinos /destinos/s3 /destinos/telegram '/destinos/remover?destino=s3' /atividade '/arquivos?pasta=dst34' '/arquivos?pasta=dst34&m=destino_ok&d=telegram'; do aba -b "$J" "$B$n" > /dev/null; cat "$W/corpo" >> "$W/telas34"; done
# Formulário recusado com os segredos digitados: a tela volta sem eles.
r_rej="$(grava34 s3 "$J" "$K" "$W/painel.senha" intervalo=4 "${S3_34[@]}") $(grava34 telegram "$J" "$K" "$W/painel.senha" intervalo=4 pasta=dst34 "${TG_34[@]}")"; cat "$W/corpo" >> "$W/telas34"
r_rej+=" $(grava34 s3 "$J" "$K" "$W/painel.senha" intervalo=4 "${S3_34[@]}")"; cat "$W/corpo" >> "$W/telas34"
v_tel="$(vaza34 "$W/telas34")"; n_tel="$(grep -c -F 'gravados; não aparecem na tela' "$W/telas34" || true)"
auditoria; v_aud="$(vaza34 "$W/auditoria")"; n_aud="$(eventos destino_gravado)"
for n in "$FTP" "$PAINEL" "$NGINX"; do docker logs "$n" 2>&1; done > "$W/logs34"; v_log="$(vaza34 "$W/logs34")"; n_log="$(grep -c -F 'destino_enviado' "$W/logs34" || true)"
docker inspect "$FTP" "$PAINEL" "$NGINX" > "$W/inspect34" 2>&1; v_ins="$(vaza34 "$W/inspect34")"; n_ins="$(grep -c -F 'PAINEL_TELEGRAM_API' "$W/inspect34" || true)"
terminal34; cat "$W/passada" >> "$W/terminal34"; v_ter="$(vaza34 "$W/terminal34")"; n_ter="$(grep -c -E '^(s3|telegram): ' "$W/terminal34" || true)"
docker exec "$PAINEL" sh -c 'cat /painel/destinos/*.conf /painel/destinos/*.estado' > "$W/estado34" 2>&1; v_est="$(vaza34 "$W/estado34")"; n_est="$(grep -c -F 'serie' "$W/estado34" || true)"
# Controle: a mesma busca acha os quatro segredos onde eles têm de estar, na pasta dos segredos, um por arquivo.
v_seg="$(cat "$S/destinos"/*.txt 2>/dev/null | grep -c -F -f "$D34/lista" || true)"; s_arq2="$(ls "$S/destinos" 2>/dev/null | wc -l)"; s_modo2="$(stat -c %a "$S/destinos"/*.txt 2>/dev/null | sort -u | tr '\n' ' ')"
[[ "$r_rej" == "400  400  400 " && "$v_tel" == 0 && "$n_tel" -ge 2 && "$v_aud" == 0 && "$n_aud" -ge 10 && "$v_log" == 0 && "$n_log" -ge 1 && "$v_ins" == 0 && "$n_ins" -ge 1 \
  && "$v_ter" == 0 && "$n_ter" -ge 2 && "$v_est" == 0 && "$n_est" -ge 2 && "$v_seg" == 4 && "$s_arq2" == 4 && "$s_modo2" == "600 " ]]
caso $? seguranca 126 "Segredos dos destinos fora das telas e dos registros" "busca pelas chaves do S3, pelo token do bot e pela conversa (os certos e os errados que a etapa digitou), em linhas com algum deles: telas dos destinos, os dois formulários, a tela de remover, a aba Log, a aba Arquivos com os botões de envio e três formulários recusados com os segredos digitados (códigos $r_rej): $v_tel (as telas dizem 'gravados; não aparecem na tela' $n_tel vezes); auditoria: $v_aud (com $n_aud linhas destino_gravado); saída dos três containers: $v_log (com destino_enviado $n_log vezes); docker inspect dos três: $v_ins (com PAINEL_TELEGRAM_API $n_ins vezes); terminal (--destinos e a última passada): $v_ter (linhas de destino: $n_ter); arquivos de configuração e de andamento em /painel/destinos: $v_est (com 'serie' $n_est vezes); controle, na pasta dos segredos: $v_seg linhas com segredo em $s_arq2 arquivos, modo $s_modo2"

# ------------------------------------------------------------------ o bot só envia; o S3 só grava
# Tudo o que o painel pediu aos dois serviços desde o começo da etapa, pelo registro do simulador.
m_128=$(marca34)
b_ops="$(sim34 0 "l['servico']=='telegram'" "l['op']" | unicos34)"; b_met="$(sim34 0 "l['servico']=='telegram'" "l['metodo']" | unicos34)"; b_out="$(sim34 0 "l['outra']")"
s_ops="$(sim34 0 "l['servico']=='s3' and l['op']" "l['op']" | unicos34)"; s_met="$(sim34 0 "l['servico']=='s3' and l['metodo']" "l['metodo']" | unicos34)"
s_ler="$(sim34 0 "l['servico']=='s3' and (l['op']=='outra' or l['metodo'] in ('GET', 'HEAD'))")"
# Controle: o registro acusa quando alguém lê mensagens do bot ou lê um objeto do bucket.
s_son="$(docker exec -i "$SIM34" python3 - <<'PYTHON'
import http.client, json, ssl
contexto = ssl._create_unverified_context()
token = json.load(open('/sim/config.json'))['bot_token']
for metodo, caminho in (('POST', f'/bot{token}/getUpdates'), ('GET', '/balde34/x')):
    ligacao = http.client.HTTPSConnection('127.0.0.1', 8443, context=contexto, timeout=10)
    ligacao.request(metodo, caminho, body=b'' if metodo == 'POST' else None)
    print(ligacao.getresponse().status, end=' ')
    ligacao.close()
PYTHON
)"
k_bot="$(sim34 "$m_128" "l['outra'] and l['op']=='getUpdates'")"; k_s3="$(sim34 "$m_128" "l['servico']=='s3' and l['metodo']=='GET' and l['erro']=='AccessDenied'")"
f_cod="$(grep -l -E 'getUpdates|setWebhook|getMe\b|deleteMessage|editMessage|getChat' "$root_dir"/painel/*.py | wc -l)"
[[ "$b_ops" == "sendDocument sendMessage " && "$b_met" == "POST " && "$b_out" == 0 && "$s_ops" == "abandonar abrir_partes gravar parte " && "$s_met" == "PUT " && "$s_ler" == 0 \
  && "$s_son" == "200 403 " && "$k_bot" == 1 && "$k_s3" == 1 && "$f_cod" == 0 ]]
caso $? seguranca 128 "O bot só envia e o S3 só grava" "registro do simulador, de todos os pedidos do painel na etapa: operações pedidas à API do bot: $b_ops(métodos: $b_met), outras operações: $b_out; operações no S3: $s_ops(método dos pedidos recusados: $s_met), leitura, lista ou remoção de objeto: $s_ler; controle do registro, com dois pedidos feitos pela etapa (ler mensagens do bot e ler um objeto): respostas $s_son, linha de operação estranha ao bot $k_bot, leitura de objeto $k_s3; arquivos do painel com o nome de alguma operação de leitura ou de comando da API do bot: $f_cod"

# ------------------------------------------------------------------ PAINEL_DESTINOS=nao desliga tudo
gravar_env "$ENVA" PAINEL_DESTINOS nao; dep; r_dep1=$?; painel_de_pe
e_adm3="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
t_men="$(aba -b "$J" "$B/usuarios")"; f_men="$(tem34 'href="/destinos"')"; a_rotas="$(rotas34 "$J" "$K")"
b_nao="$(aba -b "$J" "$B/arquivos?pasta=dst34")$(vezes34 'para-')"; b_nao_bx="$(vezes34 ' download>')"
terminal34; r_ter1=$?; f_ter1="$(grep -c -F 'FALHA: os destinos estão desligados nesta instalação (PAINEL_DESTINOS=nao)' "$W/terminal34" || true)"
# O andamento do S3 é apagado: se as passadas estivessem rodando, a primeira reenviaria o a3.txt em até um minuto.
docker exec "$PAINEL" rm -f /painel/destinos/s3.estado; m_nao=$(marca34); inicio_nao=$SECONDS
# Enquanto isso, as três variáveis: o container do painel recusa o valor fora da regra antes de tocar em qualquer pasta.
ok_var=0; ev_var=""
for par in "PAINEL_DESTINOS=talvez|PAINEL_DESTINOS deve ser 'sim' ou 'nao'" "PAINEL_TELEGRAM_API=http://bot.exemplo|PAINEL_TELEGRAM_API deve ser um endereço https://nome[:porta], em minúsculas e sem caminho" \
  "PAINEL_TELEGRAM_API=https://bot.exemplo/api|PAINEL_TELEGRAM_API deve ser um endereço" "PAINEL_TELEGRAM_API=https://Bot.exemplo|PAINEL_TELEGRAM_API deve ser um endereço" \
  "PAINEL_TELEGRAM_MAX_MB=0|PAINEL_TELEGRAM_MAX_MB deve ficar entre 1 e 2000" "PAINEL_TELEGRAM_MAX_MB=2001|PAINEL_TELEGRAM_MAX_MB deve ficar entre 1 e 2000" \
  "PAINEL_TELEGRAM_MAX_MB=abc|PAINEL_TELEGRAM_MAX_MB deve ficar entre 1 e 2000"; do
  rec="$(recusa_container painel "${par%%|*}")"; recusou "$rec" "${par#*|}" || ok_var=1; ev_var+="${par%%|*}: $rec; "
done
while (( SECONDS - inicio_nao < 75 )); do sleep 3; done
d_nao=$(( $(marca34) - m_nao ))
gravar_env "$ENVA" PAINEL_DESTINOS sim; dep; r_dep2=$?; painel_de_pe
e_adm4="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
t_men2="$(aba -b "$J" "$B/usuarios")"; f_men2="$(tem34 'href="/destinos"')"
# Controle: com as passadas de volta, o a3.txt é reenviado sozinho.
marca=$SECONDS; while (( SECONDS - marca < 110 )) && [[ "$(sim34 "$m_nao" "l['op']=='gravar' and l['chave']=='copias/teste/dst34/sub/a3.txt'")" == 0 ]]; do sleep 3; done
d_sim="$(sim34 "$m_nao" "l['op']=='gravar' and l['chave']=='copias/teste/dst34/sub/a3.txt'")"
[[ "$r_dep1" == 0 && "$e_adm3" == 303 && "$t_men" == "200 " && "$f_men" == 0 && "$a_rotas" == "404 404 404 404 404 404 404 404 404 404 " && "$r_ter1" == 1 && "$f_ter1" == 1 \
  && "$ok_var" == 0 && "$d_nao" == 0 && "$r_dep2" == 0 && "$e_adm4" == 303 && "$t_men2" == "200 " && "$f_men2" -ge 1 && "$d_sim" == 1 ]]
caso $? seguranca 129 "PAINEL_DESTINOS=nao desliga os destinos; variável fora da regra é recusada" "deploy.sh com PAINEL_DESTINOS=nao: saída $r_dep1; menu do administrador ($t_men) com a aba Destinos: $f_men; as dez rotas com a sessão e o token dele: $a_rotas; terminal: saída $r_ter1, 'os destinos estão desligados nesta instalação' ($f_ter1); com o andamento do S3 apagado, pedidos que o simulador recebeu em 75 s: $d_nao; container do painel com a variável fora da regra: $ev_var de volta a PAINEL_DESTINOS=sim: saída $r_dep2, aba no menu ($f_men2) e o arquivo reenviado sozinho pela passada (controle): $d_sim"

# ------------------------------------------------------------------ pelo terminal e a remoção
passou34 s3; terminal34; r_sit=$?
l_sit="$(grep -c -E '^telegram: ligado; pasta /data/dst34; a cada 1440 min; última passada: [0-9]+ arquivo\(s\), ' "$W/terminal34" || true) $(grep -c -E '^s3: ligado; pasta /data/dst34/sub; a cada 1440 min; última passada: [0-9]+ arquivo\(s\), ' "$W/terminal34" || true)"
u_ter=""
terminal34 enviar; u_ter+="$? $(grep -c -F 'FALHA: uso: --destinos [enviar <s3|telegram> [--sem-espera]]' "$W/terminal34" || true) · "
terminal34 enviar ftp; u_ter+="$? $(grep -c -F 'FALHA: uso: --destinos [enviar <s3|telegram> [--sem-espera]]' "$W/terminal34" || true) · "
terminal34 enviar s3 --depressa; u_ter+="$? $(grep -c -F 'FALHA: uso: --destinos [enviar <s3|telegram> [--sem-espera]]' "$W/terminal34" || true) · "
# Destino desligado: nem o botão nem o terminal fazem a passada.
g_des="$(grava34 s3 "$J" "$K" "$W/painel.senha" -ligado estilo=host pasta=dst34/sub)"
a_des="$(envio /destinos/agora --data-urlencode "csrf=$K" --data-urlencode "destino=s3")"
aba -b "$J" "$B/destinos?m=falha&d=s3&f=desligado" > /dev/null; f_des="$(tem34 'Armazenamento S3: não deu certo. Motivo: o destino está desligado ou sem os segredos.')"
terminal34 enviar s3 --sem-espera; r_des=$?; f_des2="$(grep -c -F 'FALHA: s3: não configurado, desligado ou sem os segredos' "$W/terminal34" || true)"; s_des="$(situ34 s3 | cut -d';' -f1)"
# Remoção do S3: tela de confirmação, senha do administrador, e só a configuração e os segredos dele saem.
t_rem="$(aba -b "$J" "$B/destinos/remover?destino=s3")"; f_rem="$(tem34 'Sim, remover o destino')"
x_rem="$(envio /destinos/remover --data-urlencode "csrf=$K" --data-urlencode "destino=s3")"
e_adm5="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
s_antes="$(ls "$S/destinos" 2>/dev/null | tr '\n' ' ')"
g_rem="$(envio /destinos/remover --data-urlencode "csrf=$K" --data-urlencode "destino=s3" --data-urlencode "senha_atual@$W/painel.senha")"
t_rem2="$(aba -b "$J" "$B/destinos?m=removido")"; f_rem2="$(faltam34 'Destino removido: a configuração e os segredos dele foram apagados.' '<span class="etiqueta">não configurado</span>' '<span class="etiqueta">ligado</span>')"
aba -b "$J" "$B/arquivos?pasta=dst34" > /dev/null; b_bot="$(vezes34 'id="para-s3"') $(vezes34 'id="para-telegram"')"
s_depois="$(ls "$S/destinos" 2>/dev/null | tr '\n' ' ')"; c_depois="$(docker exec "$PAINEL" sh -c 'ls /painel/destinos | grep -E "\.(conf|estado)$" | tr "\n" " "')"
h_fim="$(ha34 dst34/a1.txt) $(ha34 dst34/sub/a3.txt) $(ha34 dst34/grande.bin)"
# Remoção do bot e, sem nenhum destino, nada sai: nem pelo terminal.
g_rem2="$(envio /destinos/remover --data-urlencode "csrf=$K" --data-urlencode "destino=telegram" --data-urlencode "senha_atual@$W/painel.senha")"
s_fim="$(ls -A "$S/destinos" 2>/dev/null | wc -l)"; c_fim="$(docker exec "$PAINEL" sh -c 'ls /painel/destinos | grep -c -E "\.(conf|estado)$"' || true)"
terminal34; r_sit2=$?; l_sit2="$(tr '\n' ';' < "$W/terminal34")"
novo34 depois.bin; m_fim=$(marca34); terminal34 enviar s3 --sem-espera; r_fim=$?; terminal34 enviar telegram --sem-espera; r_fim="$r_fim$?"; d_fim=$(( $(marca34) - m_fim ))
auditoria; l_rem="$(linhas34 " evento=destino_removido admin=$ADMIN destino=s3\$") $(linhas34 " evento=destino_removido admin=$ADMIN destino=telegram\$")"
[[ "$r_sit" == 0 && "$l_sit" == "1 1" && "$u_ter" == "1 1 · 1 1 · 1 1 · " && "$g_des" == "303 /destinos?m=gravado" && "$a_des" == "303 /destinos?m=falha&d=s3&f=desligado" && "$f_des" -ge 1 \
  && "$r_des" == 1 && "$f_des2" == 1 && "$s_des" == "s3: desligado" && "$t_rem" == "200 " && "$f_rem" -ge 1 && "$x_rem" == "403 " && "$e_adm5" == 303 \
  && "$s_antes" == "s3-chave-de-acesso.txt s3-chave-secreta.txt telegram-conversa.txt telegram-token.txt " && "$g_rem" == "303 /destinos?m=removido" && "$t_rem2" == "200 " && "$f_rem2" == 0 \
  && "$s_depois" == "telegram-conversa.txt telegram-token.txt " && "$c_depois" == "telegram.conf telegram.estado " && "$h_fim" == "sim sim sim" && "$g_rem2" == "303 /destinos?m=removido" \
  && "$s_fim" == 0 && "$c_fim" == 0 && "$r_sit2" == 0 && "$l_sit2" == "telegram: não configurado;s3: não configurado;" && "$r_fim" == 11 && "$d_fim" == 0 && "$l_rem" == "1 1" ]]
caso $? testes 80 "Destinos pelo terminal e remoção de um destino" "servidor.py --destinos: saída $r_sit, linhas 'ligado; pasta; a cada 1440 min; última passada' do bot e do S3: $l_sit; uso errado (sem destino, destino que não existe, opção que não existe), saída e mensagem de uso: $u_ter; S3 regravado desligado: $g_des; botão Enviar agora: $a_des, tela com 'o destino está desligado ou sem os segredos' ($f_des); pelo terminal: saída $r_des, 'não configurado, desligado ou sem os segredos' ($f_des2), situação '$s_des'; tela de remover o S3: $t_rem, com o botão 'Sim, remover o destino' ($f_rem); sem a senha: $x_rem; com a senha: $g_rem, tela $t_rem2 (textos que faltam: aviso de removido, um 'não configurado' e o bot 'ligado': $f_rem2); pasta dos segredos antes: $s_antes depois: $s_depois; em /painel/destinos: $c_depois; arquivos do servidor (a1.txt, sub/a3.txt, grande.bin): $h_fim; bot removido: $g_rem2, arquivos de segredo: $s_fim, de configuração e andamento: $c_fim; terminal: saída $r_sit2, '$l_sit2'; arquivo novo e passada pedida pelo terminal para os dois: saídas $r_fim, pedidos que o simulador recebeu: $d_fim; destino_removido na auditoria (S3 e bot): $l_rem"

# Sem destino nenhum, a aba Arquivos volta a não ter botão, e a rota pedida mesmo assim não envia.
b_fim="$(aba -b "$J" "$B/arquivos?pasta=dst34")$(vezes34 'para-')"; b_fim_bx="$(vezes34 ' download>')"
m_xfim=$(marca34); x_fim="$(POTE="$J" envio /destinos/arquivo --data-urlencode "csrf=$K" --data-urlencode destino=s3 --data-urlencode arquivo=dst34/a1.txt)"; d_xfim=$(( $(marca34) - m_xfim ))
[[ "$b_ini" == "200 0" && "$b_ini_bx" -ge 4 && "$b_s3" == "1 0 0" && "$e_usu2" == 303 && -n "$K_u2" && "$u_tela" == "200 " && "$u_bot" == "${u_bot%% *} 0 0" && "${u_bot%% *}" -ge 1 \
  && "$u_arq" == "404 404 " && "$z_semtoken" == "403 " && "$z_token" == "403 " && "$z_origem" == "403 " && "$z_semsessao" == "303 /entrar" && "$z_dest" == "404 " \
  && "$z_cam" == "400 400 403 404 404 404 404 " && "$d_130" == 0 && "$d_arq2" == 0 && "$d_cam" -ge 1 && "$b_nao" == "200 0" && "$b_nao_bx" -ge 4 \
  && "$b_bot" == "0 1" && "$b_fim" == "200 0" && "$b_fim_bx" -ge 4 && "$x_fim" == "303 /arquivos?pasta=dst34&m=destino_falha&d=s3&f=segredo" && "$d_xfim" == 0 ]]
caso $? seguranca 130 "Envio de um arquivo ao destino: só o administrador, com token, e botão só com o destino gravado" "aba Arquivos em dst34 antes de qualquer destino gravado: código e botões de envio $b_ini (links Baixar na mesma tela: $b_ini_bx); só com o S3 gravado: formulário do S3, formulário do bot e a diferença entre os botões do S3 e os links Baixar: $b_s3; com os dois gravados e a sessão do administrador: sem token $z_semtoken, token errado $z_token, Origin de fora $z_origem; sem sessão: $z_semsessao; destino que não existe: $z_dest; caminho com '..', caminho começado por barra, link simbólico, arquivo que não existe, pasta, FIFO e campo vazio: $z_cam(recusa_caminho a mais na auditoria: $d_cam); usuário do FTP dono da pasta, com a sessão ($e_usu2) e o token dele: Meus arquivos $u_tela, com o a1.txt na lista, botões de envio e '/destinos' na tela: $u_bot; a rota com o caminho como ele vê e como o administrador vê: $u_arq; pedidos que o simulador recebeu durante todas as recusas: $d_130, destino_arquivo a mais na auditoria: $d_arq2; com PAINEL_DESTINOS=nao, a aba Arquivos do administrador: $b_nao (links Baixar: $b_nao_bx) e a rota entre as dez que respondem 404; depois de removido o S3: formulário do S3 e do bot na tela: $b_bot; depois de removidos os dois: $b_fim (links Baixar: $b_fim_bx), e a rota pedida mesmo assim: $x_fim, pedidos ao simulador: $d_xfim"

docker rm -f "$SIM34" > /dev/null 2>&1
mu del dst34
docker exec "$FTP" rm -rf /data/dst34 /data/tg34
docker exec "$PAINEL" rm -f /painel/destinos/ca.pem
rm -rf "$D34"; rm -f "$W"/dst34.* "$W"/i34.* "$W/vazio34.jar" "$W/passada" "$W/cert34.log" "$W/sim34.log" "$W/telas34" "$W/logs34" "$W/inspect34" "$W/terminal34" "$W/estado34"
gravar_env "$ENVA" PAINEL_TELEGRAM_API "$api_0"; gravar_env "$ENVA" PAINEL_TELEGRAM_MAX_MB "$max_0"; gravar_env "$ENVA" PAINEL_DESTINOS "$des_0"; dep
painel_de_pe
