#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa AH: destinos de fora. O administrador grava pelo painel um armazenamento S3 e um bot do Telegram, com a senha
# dele; o painel envia sozinho o que chega na pasta escolhida, em passadas. A etapa sobe, na rede da instância de
# teste, um serviço de exemplo dos dois (tests/apoio/simulador_destinos.py), com certificado de uma autoridade criada
# aqui, e confere pelo registro dele o que chegou: nome, tamanho e soma de cada arquivo, e nenhuma operação além das
# de gravar e de enviar. As chaves, o token e a conversa são gerados na hora e não entram em evidência. No fim, a cópia
# do sistema: o painel cifra as quatro pastas e envia ao S3 de exemplo, e o scripts/restaurar.sh abre o que chegou.
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
# A aba Serviço: o cartão de um destino sai do <h2> dele até o fim da seção, e cada lista recolhida fica em uma linha só.
cartao34() { awk -v rotulo="$1 <span class=\"etiqueta" 'index($0, "<section class=\"cartao\"><h2>") && index($0, rotulo) { dentro = 1 } dentro { print } dentro && index($0, "</section>") { dentro = 0 }' "$W/corpo"; }  # <rótulo do destino>: o cartão dele na última tela
trecho34() { cartao34 "$1" | sed -n "s|.*<summary>$2</summary>||p" | sed 's|</details>.*||'; }   # <rótulo> <título da lista>: os itens dela
lista34() { trecho34 "$1" "$2" | sed 's|</code>|\n|g' | sed -n 's|.*<code>||p' | tr '\n' ' '; }      # <rótulo> <título da lista>: os arquivos dela, na ordem da tela
motivo34() { trecho34 "$1" 'Últimos não enviados' | sed -n "s|.*<li><code>$2</code><span class=\"suave\">\([^<]*\)</span>.*|\1|p" | sed 's/.* · //'; }  # <rótulo> <arquivo>: por que ele não foi
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
copia34() { docker exec "$PAINEL" python3 /opt/painel/servidor.py --copia "$@" > "$W/copia34" 2>&1; }  # [enviar]: a cópia do sistema pelo terminal; saída em $W/copia34
tc34() { grep -c -x -F -- "$1" "$W/copia34" || true; }                                         # <linha>: vezes em que a última saída do terminal da cópia a traz
botao34() { envio /destinos/copia/agora --data-urlencode "csrf=${1-$K}"; }                     # [token]: o botão Copiar e enviar agora
gcopia34() { # <pote> <token> <arquivo da senha ou ""> [campo=valor]... → "código destino" do formulário da cópia do sistema
  local pote="$1" token="$2" senha="$3" par nome; shift 3
  local -A campo=([destino]=s3 [prefixo]=copia34/sistema [dias]=0 [hora]=03:00)
  for par in "$@"; do campo[${par%%=*}]="${par#*=}"; done
  local -a dados=(--data-urlencode "csrf=$token")
  for nome in "${!campo[@]}"; do dados+=(--data-urlencode "$nome=${campo[$nome]}"); done
  [[ -n "$senha" ]] && dados+=(--data-urlencode "senha_atual@$senha")
  c -o "$W/corpo" -w '%{http_code} %{redirect_url}' -b "$pote" -H "Origin: ${ORIGEM34:-$B}" "${dados[@]}" "$B/destinos/copia" | sed "s|$B||"
}
rotasc34() { # <pote> <token> → os códigos das três rotas da cópia do sistema: o formulário, a gravação e o botão
  local pote="$1" token="$2" r
  r="$(aba -b "$pote" "$B/destinos/copia" | cut -c1-3) "
  r+="$(gcopia34 "$pote" "$token" "" | cut -c1-3) "
  r+="$(POTE="$pote" botao34 "$token" | cut -c1-3) "
  echo "$r"
}
recusac34() { # <frase> <campo=valor>: formulário da cópia fora da regra ➜ 400 com a frase na tela; acumula em ok_ci e ev_ci
  local frase="$1" r; shift
  r="$(gcopia34 "$J" "$K" "$W/painel.senha" "$@")"
  [[ "$r" == "400 " && "$(tem34 "$frase")" -ge 1 ]] || ok_ci=1
  ev_ci+="$*: $r'$frase' $(tem34 "$frase"); "
}
copias34() { sim34 "$1" "(l['chave'] or '').startswith('copia34/')${2:+ and ($2)}"; }            # <linhas a pular> [condição]: pedidos ao S3 com chave da cópia do sistema
conf34() { # [texto a recusar]: grava o config.json do simulador, de uma vez
  ( umask 077; printf '{"s3_id":"%s","s3_segredo":"%s","regiao":"sa-teste-1","buckets":["balde34"],"bot_token":"%s","conversa":"%s","conversas":["%s"],"telegram_max":600000,"recusar":"%s","guardar":"copia34/"}\n' \
      "$(cat "$D34/s3-id")" "$(cat "$D34/s3-secreta")" "$(cat "$D34/token")" "$(cat "$D34/conversa")" "$(cat "$D34/conversa-b")" "${1:-}" > "$D34/config.novo" ) && mv "$D34/config.novo" "$D34/config.json"
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
grava34() { # <s3|telegram> <pote> <token> <arquivo da senha ou ""> [campo=valor | campo@arquivo | -campo]... → "código destino"; id=novo cria outro do tipo, id=<destino> altera, copiar=<destino> traz o acesso dele
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
rotas34() { # <pote> <token> → os códigos das onze rotas dos destinos: cinco de leitura e seis de envio
  local pote="$1" token="$2" rota r=""
  for rota in /destinos /destinos/s3 /destinos/telegram '/destinos/remover?destino=s3' '/destinos/arquivo?tipo=s3&arquivo=dst34/a1.txt'; do r+="$(aba -b "$pote" "$B$rota" | cut -c1-3) "; done
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
  printf -- '-100%010d' "$n34" > conversa; printf -- '-100%010d' "$((n34 + 1))" > conversa-errada; printf -- '-100%010d' "$((n34 + 2))" > conversa-b
) > "$W/cert34.log" 2>&1; r_cert=$?
: > "$D34/lista"
for n in s3-id s3-secreta s3-secreta-errada token token-errado conversa conversa-errada conversa-b; do
  proibir "$(cat "$D34/$n")"; { cat "$D34/$n"; echo; } >> "$D34/lista"
done
proibir "$(sed -n 2p "$D34/ca.key")"; proibir "$(sed -n 2p "$D34/servidor.key")"
conf34
S3_34=("chave_id@$D34/s3-id" "chave_secreta@$D34/s3-secreta"); TG_34=("token@$D34/token" "conversa@$D34/conversa")
# O simulador entra na rede da instância com os nomes dos dois serviços, sem privilégio e sem escrita fora da pasta dele.
docker rm -f "$SIM34" > /dev/null 2>&1
docker run -d --name "$SIM34" --no-healthcheck --network "$NOME-network" --network-alias s3.simulador.test \
  --network-alias balde34.s3.simulador.test --network-alias bot.simulador.test --network-alias outro.simulador.test \
  --read-only --cap-drop ALL --security-opt no-new-privileges --user "$(id -u):$(id -g)" --tmpfs /tmp:size=512m \
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
# O usuário do FTP, com a sessão e o token dele: nenhuma das onze rotas existe para ele.
e_usu="$(COMO=dst34 entrar "$W/dst34.jar" "$W/dst34.senha")"; proibir "$(biscoito_de "$W/dst34.jar")"; K_u="$(token34 "$W/dst34.jar")"; proibir "$K_u"
u_rotas="$(rotas34 "$W/dst34.jar" "$K_u")"; u_meus="$(aba -b "$W/dst34.jar" "$B/meus-arquivos")"; u_menu="$(tem34 '/destinos')"
auditoria; d_gra=$(( $(eventos destino_gravado) - n_gra )); d_sen=$(( $(eventos admin_senha_atual_recusada) - n_sen )); d_pap=$(( $(eventos recusa_papel) - n_pap ))
c_conf="$(docker exec "$PAINEL" sh -c 'ls /painel/destinos 2>/dev/null | grep -c "\.conf$"' || true)"; c_seg="$(ls -A "$S/destinos" 2>/dev/null | wc -l)"
[[ "$r_dep0" == 0 && "$e_adm" == 303 && "$r_cert" == 0 && "$r_sim" == 0 && "$sim_pronto" == 1 && "$r_usu$r_pla" == 00 && "$t_ini" == "200 " && "$f_ini" == 3 && "$f_menu" -ge 1 \
  && "$x_semtoken" == "403 " && "$x_token" == "403 " && "$x_origem" == "403 " && "$x_semsessao" == "303 /entrar" && "$x_errada" == "403 " && "$x_errada_f" -ge 1 \
  && "$x_semsenha" == "403 " && "$x_semsenha_f" -ge 1 && "$e_adm2" == 303 && "$ok_inv" == 0 && "$x_dest_p" == "404 " && "$x_dest_g" == "404 " && "$e_usu" == 303 && -n "$K_u" \
  && "$u_rotas" == "404 404 404 404 404 404 404 404 404 404 404 " && "$u_meus" == "200 " && "$u_menu" == 0 && "$d_gra" == 0 && "$d_sen" == 2 && "$d_pap" -ge 1 && "$c_conf" == 0 && "$c_seg" == 0 ]]
caso $? seguranca 125 "Destinos: só o administrador grava, com sessão, token e senha" "deploy.sh com a API do bot apontada para o serviço de exemplo: saída $r_dep0; simulador na rede da instância: docker run $r_sim, pronto $sim_pronto; tela dos destinos com o administrador: $t_ini, os três 'não configurado' ($f_ini) e a aba no menu ($f_menu); formulário do S3 com a sessão dele: sem token $x_semtoken, token errado $x_token, Origin de fora $x_origem; sem sessão: $x_semsessao; senha atual errada: $x_errada, sem a senha: $x_semsenha (telas com 'A sua senha atual não confere. Nada foi alterado.': $x_errada_f e $x_semsenha_f; admin_senha_atual_recusada a mais: $d_sen); formulário fora da regra, recusado com 400 e o motivo na tela antes de qualquer senha: $ev_inv destino que não existe: no teste $x_dest_p, na tela de remover $x_dest_g; usuário do FTP dst34 com a sessão e o token dele, nas onze rotas (5 de leitura, 6 de envio): $u_rotas (recusa_papel a mais: $d_pap), tela dele: $u_meus, sem '/destinos' ($u_menu); depois de tudo: destino_gravado a mais: $d_gra, arquivos de configuração em /painel/destinos: $c_conf, arquivos de segredo na pasta dos segredos: $c_seg"

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
# A aba Serviço, com a passada parada no segundo arquivo: o primeiro entre os enviados, os outros dois na fila.
sv_a="$(aba -b "$J" "$B/servico")"; sv_ae="$(lista34 'Armazenamento S3' 'Últimos enviados')"; sv_af="$(lista34 'Armazenamento S3' 'Próximos da fila')"
sv_an="$(cartao34 'Armazenamento S3' | sed -n 's|.*<dt>Na fila</dt><dd>\([^<]*\)</dd>.*|\1|p')"; sv_ap="$(cartao34 'Armazenamento S3' | grep -c -F 'A última passada parou antes do fim: o serviço respondeu com o código 500. A seguinte recomeça do mesmo arquivo.' || true)"
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
# A aba Serviço, depois da recusa: o arquivo deixado para trás entre os não enviados, com o motivo; o seguinte, entre os enviados; a fila, vazia.
aba -b "$J" "$B/servico" > /dev/null; sv_be="$(lista34 'Armazenamento S3' 'Últimos enviados')"; sv_bn="$(lista34 'Armazenamento S3' 'Últimos não enviados')"
sv_bm="$(motivo34 'Armazenamento S3' dst34/q1-recusa34.txt)"; sv_bf="$(lista34 'Armazenamento S3' 'Próximos da fila')"; sv_bp="$(cartao34 'Armazenamento S3' | grep -c -F 'parou antes do fim' || true)"
sv_bg="$(aba -b "$J" "$B/")"; sv_bv="$(tem34 'href="/servico">ver o serviço</a>')"
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
# A aba Serviço, depois da passada do bot: os dois entregues entre os enviados; os dois grandes e o vazio entre os não enviados, cada um com o motivo.
aba -b "$J" "$B/servico" > /dev/null; sv_ce="$(lista34 'Bot do Telegram' 'Últimos enviados' | unicos34)"; sv_cn="$(lista34 'Bot do Telegram' 'Últimos não enviados' | unicos34)"
sv_cm="$(for n in g1.bin g2.bin vazio.txt; do printf '%s; ' "$(motivo34 'Bot do Telegram' "tg34/$n")"; done)"
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

# ------------------------------------------------------------------ a aba Serviço: o que foi, o que não foi e o que falta, por destino
GRANDE34='o arquivo é maior do que o serviço aceita'
[[ "$sv_a" == "200 " && "$sv_ae" == "dst34/p1.txt "* && "$sv_af" == "dst34/p2.txt dst34/p3.txt " && "$sv_an" == "2 arquivos · "* && "$sv_ap" == 1 \
  && "$sv_be" == "dst34/q2.txt dst34/p3.txt dst34/p2.txt dst34/p1.txt "* && "$sv_bn" == "dst34/q1-recusa34.txt "* && "$sv_bm" == "o serviço respondeu com o código 400" \
  && -z "$sv_bf" && "$sv_bp" == 0 && "$sv_bg" == "200 " && "$sv_bv" -ge 1 && "$sv_ce" == "tg34/b1.txt tg34/sub/b2.txt " && "$sv_cn" == "tg34/g1.bin tg34/g2.bin tg34/vazio.txt " \
  && "$sv_cm" == "$GRANDE34; $GRANDE34; o arquivo está vazio, e o bot não envia arquivo vazio; " ]]
caso $? testes 112 "Aba Serviço: enviados, não enviados e fila por destino" "aba Serviço ($sv_a) com a passada do S3 parada no segundo de três arquivos: Últimos enviados começa por '$sv_ae', Próximos da fila com '$sv_af', Na fila '$sv_an' e o aviso da parada com o código 500 no cartão ($sv_ap); depois do arquivo recusado três vezes: Últimos enviados começa por '$sv_be', Últimos não enviados por '$sv_bn' com o motivo '$sv_bm', fila sem arquivo ('$sv_bf') e o cartão sem o aviso de parada ($sv_bp); Visão geral ($sv_bg) com o atalho 'ver o serviço' ($sv_bv); cartão do bot depois da passada dele: enviados '$sv_ce', não enviados '$sv_cn', com os motivos '$sv_cm'"

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
aba -b "$J" "$B/destinos" > /dev/null; f_esp="$(faltam34 'À espera de outro destino' '1 arquivo já gravado no S3 sai do servidor quando os outros destinos da pasta o entregarem')"
passa34 s3; r_m3b=$?; p_m3b="$(doterminal34 telegram) | $(doterminal34 s3)"; h_m3b="$(ha34 dst34/m3.bin)"
c_m3="$(doc34 0 dst34/m3.bin "$s_m3" 3000) $(obj34 0 dst34/m3.bin "$s_m3" 3000)"
aba -b "$J" "$B/destinos" > /dev/null; f_esp2="$(tem34 'À espera de outro destino')"
[[ "$r_c0" == 0 && "$g_tm" == "303 /destinos?m=gravado" && "$r_tm" == 0 && "$g_mv" == "303 /destinos?m=gravado" && "$f_mv" -ge 1 \
  && "$r_m1" == 0 && "$p_m1" == "telegram: 1 arquivo(s), $L3; chegou ao fim | s3: 1 arquivo(s), $A3; chegou ao fim" && "$h_m1" == nao && "$h_a1" == sim && "$c_m1" == "1 1 1" \
  && "$r_m2" == 1 && "$p_m2" == "telegram: 1 arquivo(s), $L3; chegou ao fim | s3: 0 arquivo(s), 0 bytes, $SEM34; parou: http_500" && "$h_m2" == sim \
  && "$r_m2b" == 0 && "$p_m2b" == "telegram: 0 arquivo(s), 0 bytes, $SEM34; chegou ao fim | s3: 1 arquivo(s), $A3; chegou ao fim" && "$h_m2b" == nao && "$c_m2" == "1 1" \
  && "$r_m3" == 1 && "$p_m3" == "telegram: 0 arquivo(s), 0 bytes, $SEM34; parou: http_500 | s3: 1 arquivo(s), $L3; chegou ao fim" && "$h_m3" == sim && "$f_esp" == 0 \
  && "$r_m3b" == 0 && "$p_m3b" == "telegram: 1 arquivo(s), $L3; chegou ao fim | s3: 0 arquivo(s), 0 bytes, 1 apagado(s) do servidor, 0 acima do limite do bot, 0 ignorado(s), 0 recusado(s); chegou ao fim" \
  && "$h_m3b" == nao && "$c_m3" == "1 1" && "$f_esp2" == 0 ]]
caso $? testes 78 "Guardar no S3: o arquivo sai do servidor depois de gravado e de o bot entregar" "passada de cópia antes da troca: saída $r_c0; bot regravado na pasta do S3: $g_tm (primeira passada dele: $r_tm); S3 regravado com o modo Guardar: $g_mv, cartão com o modo ($f_mv); m1, com tudo no ar: saída $r_m1, '$p_m1', ainda no servidor: $h_m1, a1.txt (enviado antes da troca) ainda no servidor: $h_a1; documento do m1, objeto do m1 e objeto do a1.txt no simulador: $c_m1; m2, com o S3 respondendo 500: saída $r_m2, '$p_m2', no servidor: $h_m2; passada seguinte: saída $r_m2b, '$p_m2b', no servidor: $h_m2b, documento e objeto do m2: $c_m2; m3, com o bot respondendo 500: saída $r_m3, '$p_m3', no servidor: $h_m3, textos de 'À espera de outro destino' que faltam no cartão: $f_esp; passada seguinte: saída $r_m3b, '$p_m3b', no servidor: $h_m3b, documento e objeto do m3: $c_m3, 'À espera de outro destino' no cartão: $f_esp2"

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

# ------------------------------------------------------------------ vários destinos do mesmo tipo
# Até aqui a etapa tinha um S3 e um bot. O segundo de cada tipo nasce com o acesso do primeiro (o segredo é copiado no
# servidor, sem passar pelo navegador) e leva outra pasta a outro lugar: outro prefixo no bucket, outra conversa do bot.
planta34 <<'SH'
mkdir -p /data/tg34/dois && cd /data/tg34/dois && for n in d1 d2; do echo "$n da pasta dos dois destinos" > "$n.txt"; done
chown -R ftpdata:ftpdata /data/tg34/dois
SH
auditoria; n_ua="$(eventos destino_gravado)"; m_ua=$(marca34)
ua_tela="$(aba -b "$J" "$B/destinos")"
ua_links="$(faltam34 'href="/destinos/s3?id=novo"' 'href="/destinos/s3?id=novo&amp;copiar=s3"' 'href="/destinos/telegram?id=novo"' 'href="/destinos/telegram?id=novo&amp;copiar=telegram"')"
ua_form="$(aba -b "$J" "$B/destinos/s3?id=novo&copiar=s3")"
ua_campos="$(faltam34 'name="id" value="novo"' 'name="copiar" value="s3"' 'Destino novo com o acesso de' 'em branco usa o do destino de origem' 'name="nome"')"
ua_g="$(grava34 s3 "$J" "$K" "$W/painel.senha" id=novo copiar=s3 'nome=Cópia B' pasta=tg34/dois prefixo=copias/outra)"
auditoria; ua_l="$(linhas34 " evento=destino_gravado admin=$ADMIN destino=s3-2 situacao=ligado pasta=tg34/dois intervalo=1440 modo=copiar segredos=copiados origem=s3\$")"
aba -b "$J" "$B/destinos" > /dev/null
ua_cartao="$(faltam34 'Armazenamento S3: Cópia B' 'href="/destinos/s3?id=s3-2"' 'href="/destinos/remover?destino=s3-2"' 'name="destino" value="s3-2"')"
# O segredo copiado assina certo: o teste do destino novo grava o objeto dele, no prefixo dele.
ua_t="$(testa34 s3-2)"; ua_ot="$(sim34 "$m_ua" "l['op']=='gravar' and l['chave']=='copias/outra/allsafe-ftp-stack-teste.txt' and l['bucket']=='balde34'")"
passa34 s3-2; ua_r=$?
ua_o="$(sim34 "$m_ua" "l['op']=='gravar' and l['chave']=='copias/outra/tg34/dois/d1.txt' and l['sha256']=='$(soma34 tg34/dois/d1.txt)'")"
ua_o+=" $(sim34 "$m_ua" "l['op']=='gravar' and l['chave']=='copias/outra/tg34/dois/d2.txt' and l['sha256']=='$(soma34 tg34/dois/d2.txt)'")"
ua_o+=" $(sim34 "$m_ua" "l['op']=='gravar' and (l['chave'].startswith('copias/teste/tg34/') or l['chave'].startswith('copias/outra/dst34/'))")"
# O segundo bot: o token do primeiro, copiado, e outra conversa, digitada. Só o que chega depois de gravado é enviado.
ua_gb="$(grava34 telegram "$J" "$K" "$W/painel.senha" id=novo copiar=telegram nome=Plantao pasta=tg34/dois "conversa@$D34/conversa-b")"
auditoria; ua_lb="$(linhas34 " evento=destino_gravado admin=$ADMIN destino=telegram-2 situacao=ligado pasta=tg34/dois intervalo=1440 segredos=copiados origem=telegram\$")"
ua_tb="$(testa34 telegram-2)"; ua_om="$(sim34 "$m_ua" "l['op']=='sendMessage' and l['codigo']==200 and l['qual']==1") $(sim34 "$m_ua" "l['op']=='sendMessage' and l['qual']!=1")"
planta34 <<'SH'
cd /data/tg34/dois && echo 'd3 chegou depois do segundo bot' > d3.txt && chown ftpdata:ftpdata d3.txt
SH
passa34 telegram-2; ua_rb=$?
ua_d="$(sim34 "$m_ua" "l['op']=='sendDocument' and l['codigo']==200 and l['arquivo']=='d3.txt' and l['qual']==1 and l['sha256']=='$(soma34 tg34/dois/d3.txt)'")"
ua_d+=" $(sim34 "$m_ua" "l['op']=='sendDocument' and l['qual']!=1") $(sim34 "$m_ua" "l['op']=='sendDocument' and l['arquivo'] in ('d1.txt', 'd2.txt')")"
# Um arquivo por segredo, cada destino com os dele; a comparação é entre os arquivos, sem mostrar o conteúdo.
ua_seg="$(LC_ALL=C ls "$S/destinos" 2>/dev/null | tr '\n' ' ')"; ua_modo="$(stat -c %a "$S/destinos"/*.txt 2>/dev/null | sort -u | tr '\n' ' ')"
cmp -s "$S/destinos/s3-chave-de-acesso.txt" "$S/destinos/s3-2-chave-de-acesso.txt" && cmp -s "$S/destinos/s3-chave-secreta.txt" "$S/destinos/s3-2-chave-secreta.txt" \
  && cmp -s "$S/destinos/telegram-token.txt" "$S/destinos/telegram-2-token.txt"; ua_igual=$?
cmp -s "$S/destinos/telegram-conversa.txt" "$S/destinos/telegram-2-conversa.txt"; ua_outra=$?
terminal34; ua_ordem="$(cut -d: -f1 "$W/terminal34" | tr '\n' ' ')"
ua_nomes="$(grep -c -E '^s3-2: ligado; pasta /data/tg34/dois; a cada 1440 min; última passada: [0-9]+ arquivo\(s\), .*; nome: Cópia B$' "$W/terminal34" || true)"
ua_nomes+=" $(grep -c -E '^telegram-2: ligado; pasta /data/tg34/dois; a cada 1440 min; última passada: [0-9]+ arquivo\(s\), .*; nome: Plantao$' "$W/terminal34" || true)"
# Alterar o segundo sem digitar segredo: ficam os dele, e o primeiro não muda.
ua_s3="$(situ34 s3)"
ua_ga="$(grava34 s3 "$J" "$K" "$W/painel.senha" id=s3-2 'nome=Cópia B' pasta=tg34/dois prefixo=copias/outra intervalo=720)"
auditoria; ua_la="$(linhas34 " evento=destino_gravado admin=$ADMIN destino=s3-2 situacao=ligado pasta=tg34/dois intervalo=720 modo=copiar segredos=mantidos\$")"
ua_s3b="$(situ34 s3)"; ua_ta="$(testa34 s3-2)"; d_ua=$(( $(eventos destino_gravado) - n_ua ))
[[ "$ua_tela" == "200 " && "$ua_links" == 0 && "$ua_form" == "200 " && "$ua_campos" == 0 && "$ua_g" == "303 /destinos?m=gravado" && "$ua_l" == 1 && "$ua_cartao" == 0 \
  && "$ua_t" == "303 /destinos?m=teste" && "$ua_ot" == 1 && "$ua_r" == 0 && "$ua_o" == "1 1 0" \
  && "$ua_gb" == "303 /destinos?m=gravado" && "$ua_lb" == 1 && "$ua_tb" == "303 /destinos?m=teste" && "$ua_om" == "1 0" && "$ua_rb" == 0 && "$ua_d" == "1 0 0" \
  && "$ua_seg" == "s3-2-chave-de-acesso.txt s3-2-chave-secreta.txt s3-chave-de-acesso.txt s3-chave-secreta.txt telegram-2-conversa.txt telegram-2-token.txt telegram-conversa.txt telegram-token.txt " \
  && "$ua_modo" == "600 " && "$ua_igual" == 0 && "$ua_outra" == 1 && "$ua_ordem" == "telegram telegram-2 rclone s3 s3-2 " && "$ua_nomes" == "1 1" \
  && "$ua_ga" == "303 /destinos?m=gravado" && "$ua_la" == 1 && "$ua_s3" == "$ua_s3b" && "$ua_s3" == "s3: ligado; pasta /data/dst34/sub; a cada 1440 min; "* \
  && "$ua_ta" == "303 /destinos?m=teste" && "$d_ua" == 3 ]]
caso $? testes 84 "Segundo S3 e segundo bot, criados com o acesso do primeiro" "tela dos destinos ($ua_tela) com um S3 e um bot: links de destino novo e de 'Novo com o mesmo acesso' que faltam: $ua_links; formulário de S3 novo com o acesso do primeiro: $ua_form, campos ocultos id e copiar, aviso da cópia, nota 'em branco usa o do destino de origem' e campo Nome que faltam: $ua_campos; gravado sem digitar nenhuma chave, com o nome 'Cópia B', a pasta tg34/dois e o prefixo copias/outra: $ua_g, linha destino_gravado destino=s3-2 com segredos=copiados origem=s3: $ua_l; cartão 'Armazenamento S3: Cópia B' com Alterar, Remover e os botões dele, itens que faltam: $ua_cartao; botão Testar do destino novo: $ua_t, objeto de teste em copias/outra no simulador (assinatura conferida com a chave copiada): $ua_ot; passada dele: saída $ua_r; d1.txt e d2.txt em copias/outra com o SHA-256 de cada um, e objetos no prefixo ou na pasta do outro S3: $ua_o; segundo bot com o token copiado e outra conversa, nome 'Plantao': $ua_gb, linha destino_gravado destino=telegram-2 com segredos=copiados origem=telegram: $ua_lb; teste dele: $ua_tb, mensagens na segunda conversa e fora dela: $ua_om; d3.txt, plantado depois: passada com saída $ua_rb, documento na segunda conversa com o SHA-256, documentos fora dela e documentos de d1 e d2 (anteriores ao bot): $ua_d; arquivos de segredo: $ua_seg(modos: $ua_modo), chaves e token do segundo iguais aos do primeiro (cmp: $ua_igual) e conversa diferente (cmp: $ua_outra); ordem das linhas do terminal: $ua_ordem, linhas do s3-2 e do telegram-2 com pasta, intervalo e nome: $ua_nomes; s3-2 alterado para 720 minutos sem digitar segredo: $ua_ga, linha com segredos=mantidos: $ua_la, teste depois da alteração: $ua_ta; linha do primeiro S3 no terminal igual antes e depois ('${ua_s3%%; última*}'); linhas destino_gravado a mais: $d_ua"

# ------------------------------------------------------------------ o mesmo lugar duas vezes, o limite por tipo e o Guardar com outro S3
REP34='Este destino já existe:'; CHEIO34='Este tipo já tem os 20 destinos que o painel aceita: remova um antes de criar outro.'
auditoria; n_ub="$(eventos destino_gravado)"
ub_rep="$(grava34 s3 "$J" "$K" "$W/painel.senha" id=novo copiar=s3 pasta=dst34)"; ub_repf="$(tem34 "$REP34")"
ub_rep+="$(grava34 s3 "$J" "$K" "$W/painel.senha" id=s3-2 'nome=Cópia B' pasta=dst34/sub intervalo=720)"; ub_repf+=" $(tem34 "$REP34")"; ub_s2="$(situ34 s3-2)"
ub_rep+="$(grava34 telegram "$J" "$K" "$W/painel.senha" id=novo copiar=telegram pasta=dst34/sub)"; ub_repf+=" $(tem34 "$REP34")"
ub_rep+="$(grava34 telegram "$J" "$K" "$W/painel.senha" id=novo copiar=telegram pasta=tg34 "conversa@$D34/conversa-b")"; ub_repf+=" $(tem34 "$REP34")"
auditoria; ub_n=$(( $(eventos destino_gravado) - n_ub ))
# O mesmo bot e a mesma conversa em outra pasta, que não cruza com nenhuma: é outro destino.
ub_t3="$(grava34 telegram "$J" "$K" "$W/painel.senha" id=novo copiar=telegram pasta=tg34/sub)"; ub_t3s="$(situ34 telegram-3)"
cmp -s "$S/destinos/telegram-token.txt" "$S/destinos/telegram-3-token.txt" && cmp -s "$S/destinos/telegram-conversa.txt" "$S/destinos/telegram-3-conversa.txt"; ub_t3i=$?
ub_t3r="$(envio /destinos/remover --data-urlencode "csrf=$K" --data-urlencode "destino=telegram-3" --data-urlencode "senha_atual@$W/painel.senha")"
ub_t3k="$(ls "$S/destinos" 2>/dev/null | grep -c '^telegram-3-' || true)"
# O limite por tipo: com os vinte nomes do S3 ocupados (configurações plantadas, sem segredos), não se cria outro.
docker exec "$PAINEL" sh -c 'cd /painel/destinos && for n in $(seq 3 20); do cp s3-2.conf "s3-$n.conf" || exit 1; done'; ub_pl=$?
ub_ch="$(aba -b "$J" "$B/destinos/s3?id=novo")"
ub_chg="$(grava34 s3 "$J" "$K" "$W/painel.senha" id=novo "${S3_34[@]}" pasta=tg34/sub prefixo=copias/cheio)"
ub_cht="$(aba -b "$J" "$B/destinos?m=cheio")"; ub_chl="$(tem34 "$CHEIO34") $(vezes34 'href="/destinos/s3?id=novo') $(vezes34 'href="/destinos/telegram?id=novo"')"
ub_lp="$(docker exec "$PAINEL" sh -c 'cd /painel/destinos && for n in $(seq 3 20); do rm -f "s3-$n.conf" "s3-$n.estado"; done; ls | grep -c -E "^s3-([3-9]|1[0-9]|20)\."' || true)"
ub_liv="$(aba -b "$J" "$B/destinos/s3?id=novo")"; ub_k="$(ls "$S/destinos" 2>/dev/null | wc -l)"
# Guardar com outro S3 na mesma pasta: o arquivo só sai do servidor depois que todos os destinos da pasta o têm.
ub_g2="$(grava34 s3 "$J" "$K" "$W/painel.senha" id=s3-2 'nome=Cópia B' pasta=dst34/sub prefixo=copias/outra)"; passa34 s3-2; ub_r0=$?; passa34 s3; ub_r0="$ub_r0$?"; passa34 telegram; ub_r0="$ub_r0$?"
ub_gm="$(grava34 s3 "$J" "$K" "$W/painel.senha" modo=mover estilo=host pasta=dst34/sub)"
novo34 sub/n1.bin; ub_s="$(soma34 dst34/sub/n1.bin)"; auditoria; n_ubf="$(linhas34 ' evento=destino_falhou destino=s3-2 motivo=http_400$')"
conf34 copias/outra
passa34 s3; ub_r1=$?; ub_p1="$(doterminal34 telegram) | $(doterminal34 s3-2) | $(doterminal34 s3)"; ub_h1="$(ha34 dst34/sub/n1.bin)"
aba -b "$J" "$B/destinos" > /dev/null; ub_esp="$(faltam34 'À espera de outro destino' '1 arquivo já gravado no S3 sai do servidor quando os outros destinos da pasta o entregarem')"
conf34
passa34 s3; ub_r2=$?; ub_p2="$(doterminal34 telegram) | $(doterminal34 s3-2) | $(doterminal34 s3)"; ub_h2="$(ha34 dst34/sub/n1.bin)"
ub_o="$(obj34 0 dst34/sub/n1.bin "$ub_s" 3000) $(sim34 0 "l['op']=='gravar' and l['chave']=='copias/outra/dst34/sub/n1.bin' and l['bytes']==3000 and l['sha256']=='$ub_s'") $(doc34 0 dst34/sub/n1.bin "$ub_s" 3000)"
aba -b "$J" "$B/destinos" > /dev/null; ub_esp2="$(tem34 'À espera de outro destino')"
auditoria; ub_lf=$(( $(linhas34 ' evento=destino_falhou destino=s3-2 motivo=http_400$') - n_ubf ))
ub_gc="$(grava34 s3 "$J" "$K" "$W/painel.senha" estilo=host pasta=dst34/sub)"
[[ "$ub_rep" == "400 400 400 400 " && "$ub_repf" != *0* && "$ub_s2" == "s3-2: ligado; pasta /data/tg34/dois; a cada 720 min; "* && "$ub_n" == 0 \
  && "$ub_t3" == "303 /destinos?m=gravado" && "$ub_t3s" == "telegram-3: ligado; pasta /data/tg34/sub; a cada 1440 min; "* && "$ub_t3i" == 0 && "$ub_t3r" == "303 /destinos?m=removido" && "$ub_t3k" == 0 \
  && "$ub_pl" == 0 && "$ub_ch" == "303 /destinos?m=cheio" && "$ub_chg" == "303 /destinos?m=cheio" && "$ub_cht" == "200 " && "$ub_chl" == "1 0 1" && "$ub_lp" == 0 && "$ub_liv" == "200 " && "$ub_k" == 8 \
  && "$ub_g2" == "303 /destinos?m=gravado" && "$ub_r0" == 000 && "$ub_gm" == "303 /destinos?m=gravado" \
  && "$ub_r1" == 1 && "$ub_p1" == "telegram: 1 arquivo(s), $L3; chegou ao fim | s3-2: 0 arquivo(s), 0 bytes, $SEM34; parou: http_400 | s3: 1 arquivo(s), $L3; chegou ao fim" && "$ub_h1" == sim && "$ub_esp" == 0 \
  && "$ub_r2" == 0 && "$ub_p2" == "telegram: 0 arquivo(s), 0 bytes, $SEM34; chegou ao fim | s3-2: 1 arquivo(s), $L3; chegou ao fim | s3: 0 arquivo(s), 0 bytes, 1 apagado(s) do servidor, 0 acima do limite do bot, 0 ignorado(s), 0 recusado(s); chegou ao fim" \
  && "$ub_h2" == nao && "$ub_o" == "1 1 1" && "$ub_esp2" == 0 && "$ub_lf" == 1 && "$ub_gc" == "303 /destinos?m=gravado" ]]
caso $? testes 85 "Destino repetido, limite por tipo e Guardar à espera de outro S3" "a mesma pasta, ou uma que a contém, ao mesmo lugar, quatro tentativas (S3 novo com o endereço, o bucket e o prefixo do primeiro na pasta que contém a dele; s3-2 alterado para a pasta e o prefixo do primeiro; bot novo com o token e a conversa do primeiro em pasta de dentro da dele; bot novo com o token e a conversa do telegram-2 na pasta que contém a dele): $ub_rep, cada tela com '$REP34' ($ub_repf vezes), s3-2 segue em '${ub_s2%%; última*}' e linhas destino_gravado a mais: $ub_n; o mesmo bot e a mesma conversa em pasta que não cruza com nenhuma (tg34/sub): $ub_t3, vira '${ub_t3s%%; nenhuma*}', com token e conversa iguais aos do primeiro (cmp: $ub_t3i); removido com a senha: $ub_t3r, arquivos de segredo dele que sobraram: $ub_t3k; limite: configurações s3-3 a s3-20 plantadas (saída $ub_pl), formulário de S3 novo: $ub_ch, gravação de S3 novo com as chaves digitadas: $ub_chg, tela da lista: $ub_cht, com o aviso '$CHEIO34', links de S3 novo e link de bot novo: $ub_chl; configurações plantadas que sobraram depois de apagadas: $ub_lp, formulário de S3 novo de volta: $ub_liv, arquivos de segredo: $ub_k; Guardar: s3-2 regravado na pasta do primeiro (dst34/sub) com o prefixo copias/outra: $ub_g2, passadas dos dois S3 e do bot antes da troca: saídas $ub_r0, primeiro S3 no modo Guardar: $ub_gm; n1.bin com o simulador recusando copias/outra: saída $ub_r1, '$ub_p1', no servidor: $ub_h1, textos de 'À espera de outro destino' que faltam no cartão: $ub_esp; passada seguinte: saída $ub_r2, '$ub_p2', no servidor: $ub_h2; objeto em copias/teste, objeto em copias/outra e documento do bot, com o SHA-256: $ub_o; 'À espera de outro destino' no cartão: $ub_esp2; destino_falhou destino=s3-2 motivo=http_400 a mais: $ub_lf; primeiro S3 de volta ao modo de cópia: $ub_gc"

# ------------------------------------------------------------------ vários destinos: identificador fora da regra e telas só do administrador
# Com o s3-2 e o telegram-2 gravados. Nada daqui chega ao serviço de fora, grava destino ou muda arquivo de segredo.
auditoria; n_uc="$(eventos destino_gravado)"; m_uc=$(marca34); uc_seg="$(LC_ALL=C ls "$S/destinos" 2>/dev/null | tr '\n' ' ')"
uc_get=""
for n in telegram s3-21 s3-9 s3-1 ../s3 'novo&copiar=telegram' 'novo&copiar=s3-9' 'novo&copiar=x'; do uc_get+="$(aba -b "$J" "$B/destinos/s3?id=$n" | cut -c1-3) "; done
uc_get+="$(aba -b "$J" "$B/destinos/telegram?id=s3-2" | cut -c1-3) $(aba -b "$J" "$B/destinos/telegram?id=novo&copiar=s3" | cut -c1-3) "
# Formulário completo, com as chaves certas e a senha: o que recusa é o identificador.
uc_post=""
for n in id=s3-9 id=s3-21 id=telegram-2 'id=novo copiar=telegram' 'id=novo copiar=s3-9'; do
  # shellcheck disable=SC2086  # um ou dois campos por volta
  uc_post+="$(grava34 s3 "$J" "$K" "$W/painel.senha" $n "${S3_34[@]}" pasta=tg34/sub prefixo=copias/fora | cut -c1-3) "
done
uc_post+="$(grava34 telegram "$J" "$K" "$W/painel.senha" id=s3-2 "${TG_34[@]}" pasta=tg34/sub | cut -c1-3) "
auditoria; uc_n=$(( $(eventos destino_gravado) - n_uc )); uc_seg2="$(LC_ALL=C ls "$S/destinos" 2>/dev/null | tr '\n' ' ')"
uc_conf="$(docker exec "$PAINEL" sh -c 'ls /painel/destinos | grep -c "\.conf$"' || true)"
# O usuário do FTP dono da pasta, com a sessão e o token dele: não cria destino com o acesso do administrador nem chega à escolha.
E34='/destinos/arquivo?tipo=s3&arquivo=dst34/a1.txt'
uc_usu="$(aba -b "$W/dst34.jar" "$B/destinos/s3?id=novo&copiar=s3" | cut -c1-3) $(aba -b "$W/dst34.jar" "$B/destinos/s3?id=s3-2" | cut -c1-3) $(aba -b "$W/dst34.jar" "$B$E34" | cut -c1-3)"
uc_usu+=" $(grava34 s3 "$W/dst34.jar" "$K_u2" "" id=novo copiar=s3 pasta=dst34 prefixo=copias/usuario | cut -c1-3) $(POTE="$W/dst34.jar" arq34 "$K_u2" s3-2 dst34/a1.txt | cut -c1-3) $(POTE="$W/dst34.jar" arq34 "$K_u2" telegram-2 a1.txt | cut -c1-3)"
uc_sem="$(aba -b "$W/vazio34.jar" "$B$E34")$(aba -b "$W/vazio34.jar" "$B/destinos/s3?id=novo&copiar=s3")"
# A tela de escolha: só para tipo que existe e arquivo comum de dentro dos dados.
uc_esc="$(aba -b "$J" "$B$E34")"; uc_tipo=""
for n in ftp s3-2 S3 ''; do uc_tipo+="$(aba -b "$J" "$B/destinos/arquivo?tipo=$n&arquivo=dst34/a1.txt" | cut -c1-3) "; done
uc_cam=""
for n in dst34/../dst34/a1.txt /dst34/a1.txt dst34/nao-existe.txt dst34/sub ''; do uc_cam+="$(aba -b "$J" "$B/destinos/arquivo?tipo=s3&arquivo=$n" | cut -c1-3) "; done
uc_arq="$(arq34 "$K" s3-21 dst34/a1.txt)$(arq34 "$K" telegram-1 dst34/a1.txt)$(arq34 "$K" s3-9 dst34/a1.txt)"
d_uc=$(( $(marca34) - m_uc ))
# Depois da cópia de acesso, os segredos seguem fora das telas, da auditoria, do terminal e das configurações.
: > "$W/telas34b"; uc_tel=""
for n in /destinos '/destinos/s3?id=s3-2' '/destinos/s3?id=novo&copiar=s3' '/destinos/telegram?id=telegram-2' '/destinos/telegram?id=novo&copiar=telegram' '/destinos/remover?destino=s3-2' "$E34" '/destinos/arquivo?tipo=telegram&arquivo=dst34/a1.txt'; do
  uc_tel+="$(aba -b "$J" "$B$n" | cut -c1-3) "; cat "$W/corpo" >> "$W/telas34b"
done
uc_rej="$(grava34 s3 "$J" "$K" "$W/painel.senha" id=novo copiar=s3 intervalo=4 pasta=tg34/sub prefixo=copias/fora "${S3_34[@]}")"; cat "$W/corpo" >> "$W/telas34b"
uc_rej+="$(grava34 telegram "$J" "$K" "$W/painel.senha" id=novo copiar=telegram intervalo=4 pasta=tg34/sub "conversa@$D34/conversa-b")"; cat "$W/corpo" >> "$W/telas34b"
uc_v="$(vaza34 "$W/telas34b")"; uc_nt="$(grep -c -F 'em branco usa o do destino de origem' "$W/telas34b" || true)"
auditoria; uc_va="$(vaza34 "$W/auditoria")"; terminal34; uc_vt="$(vaza34 "$W/terminal34")"; uc_lt="$(grep -c -E '^(s3|telegram)(-2)?: ' "$W/terminal34" || true)"
docker exec "$PAINEL" sh -c 'cat /painel/destinos/*.conf /painel/destinos/*.estado' > "$W/estado34b" 2>&1; uc_ve="$(vaza34 "$W/estado34b")"; uc_ne="$(grep -c -F 'Cópia B' "$W/estado34b" || true)"
# Controle: a mesma busca acha os oito segredos onde eles têm de estar, um por arquivo.
uc_c="$(cat "$S/destinos"/*.txt 2>/dev/null | grep -c -F -f "$D34/lista" || true)"
[[ "$uc_get" == "404 404 404 404 404 404 404 404 404 404 " && "$uc_post" == "404 404 404 404 404 404 " && "$uc_n" == 0 && "$uc_seg2" == "$uc_seg" && "$uc_conf" == 4 \
  && "$uc_usu" == "404 404 404 404 404 404" && "$uc_sem" == "303 /entrar303 /entrar" && "$uc_esc" == "200 " && "$uc_tipo" == "404 404 404 404 " && "$uc_cam" == "400 400 404 404 404 " \
  && "$uc_arq" == "404 404 303 /arquivos?pasta=dst34&m=destino_falha&d=s3-9&f=segredo" && "$d_uc" == 0 \
  && "$uc_tel" == "200 200 200 200 200 200 200 200 " && "$uc_rej" == "400 400 " && "$uc_v" == 0 && "$uc_nt" -ge 2 && "$uc_va" == 0 && "$uc_vt" == 0 && "$uc_lt" == 4 \
  && "$uc_ve" == 0 && "$uc_ne" -ge 1 && "$uc_c" == 8 ]]
caso $? seguranca 132 "Vários destinos: identificador fora da regra, telas só do administrador e segredo copiado fora das telas" "com s3, s3-2, telegram e telegram-2 gravados; formulário do S3 com id de outro tipo, fora da faixa (s3-21, s3-1), sem configuração (s3-9), com '..' e com copiar de outro tipo, sem configuração ou fora do formato, e formulário do bot com id e copiar de S3: $uc_get; gravação com o formulário completo, as chaves certas e a senha, com id sem configuração, fora da faixa, de outro tipo e copiar de outro tipo ou sem configuração, e a do bot com id de S3: $uc_post; linhas destino_gravado a mais: $uc_n, configurações gravadas: $uc_conf, arquivos de segredo iguais antes e depois: $([[ "$uc_seg2" == "$uc_seg" ]] && echo sim || echo nao); usuário do FTP dst34 com a sessão e o token dele (formulário de destino novo com o acesso do primeiro, formulário do s3-2, tela de escolha, gravação de destino novo com copiar=s3, envio de arquivo ao s3-2 e ao telegram-2): $uc_usu; sem sessão, a tela de escolha e o formulário de cópia: $uc_sem; tela de escolha com o administrador: $uc_esc; com tipo que não existe (ftp, s3-2, S3, vazio): $uc_tipo; com caminho que sai da pasta, absoluto, inexistente, de pasta e vazio: $uc_cam; envio de arquivo para s3-21, telegram-1 e s3-9 (nome aceito, sem configuração): $uc_arq; pedidos que o simulador recebeu em tudo isso: $d_uc; busca pelos segredos da etapa (com a segunda conversa) nas telas da lista, dos formulários de alterar e de copiar dos dois tipos, de remover e de escolha (códigos $uc_tel) e em dois formulários de cópia recusados com segredo digitado ($uc_rej): $uc_v linhas (a nota 'em branco usa o do destino de origem' aparece $uc_nt vezes); na auditoria: $uc_va; no terminal: $uc_vt (com $uc_lt linhas de destino); nas configurações e nos andamentos: $uc_ve (com o nome 'Cópia B' $uc_ne vez); controle, a mesma busca na pasta dos segredos: $uc_c arquivos"

# ------------------------------------------------------------------ com dois destinos do tipo, o botão pergunta qual; remover tira só o escolhido
ud_t="$(aba -b "$J" "$B/arquivos?pasta=dst34")"
ud_f="$(faltam34 '<form id="para-s3" method="get" action="/destinos/arquivo" hidden><input type="hidden" name="tipo" value="s3"></form>' '<form id="para-telegram" method="get" action="/destinos/arquivo" hidden><input type="hidden" name="tipo" value="telegram"></form>') $(vezes34 'method="post" action="/destinos/arquivo"')"
ud_e="$(aba -b "$J" "$B$E34")"
ud_ef="$(faltam34 'Destino que recebe' 'name="destino" value="s3" checked>' 'name="destino" value="s3-2">' '<code>dst34/a1.txt</code>' '<strong>Armazenamento S3: Cópia B</strong>: <code>balde34</code> / <code>copias/outra</code>' 'name="arquivo" value="dst34/a1.txt"')"
ud_et="$(aba -b "$J" "$B/destinos/arquivo?tipo=telegram&arquivo=dst34/a1.txt")"
ud_etf="$(faltam34 'name="destino" value="telegram" checked>' 'name="destino" value="telegram-2">' '<strong>Bot do Telegram: Plantao</strong>')"
m_ud=$(marca34); ud_e0="$(estado34 s3-2) $(estado34 telegram-2)"; auditoria; n_ud="$(eventos destino_arquivo)"
ud_x="$(arq34 "$K" s3-2 dst34/a1.txt)"
ud_o="$(sim34 "$m_ud" "l['op']=='gravar' and l['chave']=='copias/outra/dst34/a1.txt' and l['sha256']=='$(soma34 dst34/a1.txt)'") $(sim34 "$m_ud" "l['op']=='gravar' and l['chave'].startswith('copias/teste/')")"
aba -b "$J" "$B/arquivos?pasta=dst34&m=destino_ok&d=s3-2" > /dev/null; ud_ok="$(tem34 'Armazenamento S3: Cópia B: arquivo enviado.')"
ud_xb="$(arq34 "$K" telegram-2 dst34/a1.txt)"
ud_d="$(sim34 "$m_ud" "l['op']=='sendDocument' and l['codigo']==200 and l['arquivo']=='a1.txt' and l['qual']==1 and l['sha256']=='$(soma34 dst34/a1.txt)'") $(sim34 "$m_ud" "l['op']=='sendDocument' and l['qual']!=1")"
ud_e1="$(estado34 s3-2) $(estado34 telegram-2)"
auditoria; d_ud=$(( $(eventos destino_arquivo) - n_ud ))
ud_l="$(linhas34 " evento=destino_arquivo admin=$ADMIN destino=s3-2 arquivo=dst34/a1\.txt bytes=$(tam34 dst34/a1.txt) resultado=ok\$")"
ud_l+=" $(linhas34 " evento=destino_arquivo admin=$ADMIN destino=telegram-2 arquivo=dst34/a1\.txt bytes=$(tam34 dst34/a1.txt) resultado=ok\$")"
# Remover o segundo S3: saem a configuração, o andamento e os segredos dele, e só os dele.
ud_rt="$(aba -b "$J" "$B/destinos/remover?destino=s3-2")"; ud_rtf="$(tem34 'Armazenamento S3: Cópia B')"
ud_r="$(envio /destinos/remover --data-urlencode "csrf=$K" --data-urlencode "destino=s3-2" --data-urlencode "senha_atual@$W/painel.senha")"
ud_seg="$(LC_ALL=C ls "$S/destinos" 2>/dev/null | tr '\n' ' ')"; ud_conf="$(docker exec "$PAINEL" sh -c 'ls /painel/destinos | grep -c "^s3-2\."' || true)"
aba -b "$J" "$B/arquivos?pasta=dst34" > /dev/null
ud_um="$(faltam34 '<form id="para-s3" method="post" action="/destinos/arquivo" autocomplete="off" hidden>' '<input type="hidden" name="destino" value="s3"></form>' '<form id="para-telegram" method="get" action="/destinos/arquivo" hidden>') $(vezes34 'name="tipo" value="s3"')"
terminal34; ud_ter="$(cut -d: -f1 "$W/terminal34" | tr '\n' ' ')"
ud_rb="$(envio /destinos/remover --data-urlencode "csrf=$K" --data-urlencode "destino=telegram-2" --data-urlencode "senha_atual@$W/painel.senha")"
ud_seg2="$(LC_ALL=C ls "$S/destinos" 2>/dev/null | tr '\n' ' ')"; terminal34; ud_ter2="$(cut -d: -f1 "$W/terminal34" | tr '\n' ' ')"
auditoria; ud_lr="$(linhas34 " evento=destino_removido admin=$ADMIN destino=s3-2\$") $(linhas34 " evento=destino_removido admin=$ADMIN destino=telegram-2\$")"
# O que já foi enviado continua no destino, e os primeiros seguem com os segredos deles.
ud_del="$(sim34 "$m_ua" "l['metodo']=='DELETE'")"; ud_fica="$(sim34 "$m_ua" "l['op']=='gravar' and l['chave'].startswith('copias/outra/')")"; ud_tes="$(testa34 s3) $(testa34 telegram)"
[[ "$ud_t" == "200 " && "$ud_f" == "0 0" && "$ud_e" == "200 " && "$ud_ef" == 0 && "$ud_et" == "200 " && "$ud_etf" == 0 \
  && "$ud_x" == "303 /arquivos?pasta=dst34&m=destino_ok&d=s3-2" && "$ud_o" == "1 0" && "$ud_ok" -ge 1 && "$ud_xb" == "303 /arquivos?pasta=dst34&m=destino_ok&d=telegram-2" && "$ud_d" == "1 0" \
  && "$ud_e0" == "$ud_e1" && ${#ud_e0} == 129 && "$d_ud" == 2 && "$ud_l" == "1 1" && "$ud_rt" == "200 " && "$ud_rtf" -ge 1 && "$ud_r" == "303 /destinos?m=removido" \
  && "$ud_seg" == "s3-chave-de-acesso.txt s3-chave-secreta.txt telegram-2-conversa.txt telegram-2-token.txt telegram-conversa.txt telegram-token.txt " && "$ud_conf" == 0 \
  && "$ud_um" == "0 0" && "$ud_ter" == "telegram telegram-2 rclone s3 " && "$ud_rb" == "303 /destinos?m=removido" \
  && "$ud_seg2" == "s3-chave-de-acesso.txt s3-chave-secreta.txt telegram-conversa.txt telegram-token.txt " && "$ud_ter2" == "telegram rclone s3 " && "$ud_lr" == "1 1" \
  && "$ud_del" == 0 && "$ud_fica" -ge 4 && "$ud_tes" == "303 /destinos?m=teste 303 /destinos?m=teste" ]]
caso $? testes 86 "Com dois destinos do tipo, o botão do arquivo pergunta qual; remover tira só o escolhido" "aba Arquivos em dst34 ($ud_t) com dois S3 e dois bots prontos: formulários ocultos de escolha (method=get, com o tipo) que faltam e formulários de envio direto: $ud_f; tela de escolha do S3: $ud_e, itens que faltam (legenda, os dois destinos com o primeiro marcado, o arquivo, o nome 'Cópia B' com o bucket e o prefixo dele): $ud_ef; a do bot: $ud_et, itens que faltam: $ud_etf; a1.txt enviado ao s3-2: $ud_x, objeto em copias/outra com o SHA-256 e objetos novos em copias/teste: $ud_o, aviso 'Armazenamento S3: Cópia B: arquivo enviado.': $ud_ok; ao telegram-2: $ud_xb, documento na segunda conversa e documentos fora dela: $ud_d; andamento dos dois igual antes e depois (somas com ${#ud_e0} caracteres); linhas destino_arquivo a mais: $d_ud, a do s3-2 e a do telegram-2 com resultado=ok: $ud_l; tela de remover o s3-2: $ud_rt, com o nome dele: $ud_rtf; removido com a senha: $ud_r, arquivos de segredo: $ud_seg, configuração e andamento dele que sobraram: $ud_conf; aba Arquivos depois: formulário de envio direto ao S3 e de escolha do bot que faltam, e campo de tipo do S3: $ud_um; terminal: $ud_ter; telegram-2 removido: $ud_rb, arquivos de segredo: $ud_seg2, terminal: $ud_ter2; linhas destino_removido do s3-2 e do telegram-2: $ud_lr; pedidos DELETE que o simulador recebeu desde a criação do segundo destino: $ud_del, objetos de copias/outra que seguem no registro dele: $ud_fica; teste do primeiro S3 e do primeiro bot depois das remoções: $ud_tes"

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
terminal34; cat "$W/passada" >> "$W/terminal34"; v_ter="$(vaza34 "$W/terminal34")"; n_ter="$(grep -c -E '^(s3|telegram)(-[0-9]+)?: ' "$W/terminal34" || true)"
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

# ------------------------------------------------------------------ nada apaga nem lê no destino, por nenhum caminho do código
# Os três módulos de saída são chamados direto, dentro do container do painel, como faria um código novo que tentasse
# apagar: o pedido tem de morrer antes de sair. Os dois de controle, com credencial que não vale, chegam ao simulador.
m_131=$(marca34)
r_131="$(docker exec -i "$PAINEL" python3 - <<'PYTHON'
import sys
sys.path.insert(0, '/opt/painel')
import s3, saida, telegram


def tenta(chamada):
    try:
        chamada()
    except saida.Falha as falha:
        return falha.motivo
    return 'passou'


balde = s3.Destino({'endpoint': 'https://s3.simulador.test:8443', 'estilo': 'caminho', 'bucket': 'balde34', 'regiao': 'sa-teste-1'},
                   'AKIACONTROLE131', 'nao-vale-131', prazo=10)
bot = telegram.Bot('https://bot.simulador.test:8443', '123456:' + 'A' * 35, '-100131', prazo=10)
chave, vazio = 'copias/teste/a1.txt', 'application/x-www-form-urlencoded'
recusas = [tenta(lambda: balde.pedir(metodo, alvo, consulta)) for metodo, alvo, consulta in (
    ('DELETE', chave, []), ('DELETE', chave, [('versionId', 'x')]), ('DELETE', chave, [('uploadId', '')]),
    ('DELETE', chave, [('uploadId', 'x'), ('versionId', 'x')]), ('DELETE', '', [('uploadId', 'x')]), ('DELETE', '', []),
    ('POST', chave, [('delete', '')]), ('POST', '', [('delete', '')]), ('POST', chave, []), ('PUT', chave, [('lifecycle', '')]),
    ('PUT', '', [('lifecycle', '')]), ('PUT', '', []), ('GET', chave, []), ('GET', '', []), ('HEAD', chave, []), ('delete', chave, []))]
recusas += [tenta(lambda: saida.pedir(balde.ligacao, metodo, '/balde34/' + chave, {})) for metodo in ('GET', 'HEAD', 'PATCH', 'OPTIONS')]
recusas += [tenta(lambda: bot.chamar(operacao, vazio, b'', 0)) for operacao in (
    'deleteMessage', 'deleteMessages', 'editMessageText', 'getUpdates', 'setWebhook', 'banChatMember', 'sendmessage', '')]
controle = [tenta(lambda: balde.pedir('PUT', 'copias/teste/controle-131', corpo=b'x')), tenta(lambda: bot.avisar('controle 131'))]
print(len(recusas), ' '.join(sorted(set(recusas))), '·', ' '.join(controle))
PYTHON
)"
d_131="$(sim34 "$m_131" "True")"; c_131="$(sim34 "$m_131" "l['erro']=='InvalidAccessKeyId' and l['metodo']=='PUT'") $(sim34 "$m_131" "l['servico']=='telegram' and l['codigo']==401 and l['op']=='sendMessage'")"
# Em toda a etapa: nenhum pedido de apagar que não seja o de desfazer um envio em partes.
a_131="$(sim34 0 "l['servico']=='s3' and (l['op']=='outra' or (l['metodo']=='DELETE' and l['consulta']!=['uploadId']))")"; b_131="$(( $(sim34 0 "l['servico']=='telegram' and l['op'] not in ('sendDocument', 'sendMessage')") - k_bot ))"
# Controle: o registro acusa quem apaga um objeto, mesmo com a chave certa de quem só deveria gravar.
m_k131=$(marca34)
s_131="$(docker exec -i "$SIM34" python3 - <<'PYTHON'
import http.client, ssl
ligacao = http.client.HTTPSConnection('127.0.0.1', 8443, context=ssl._create_unverified_context(), timeout=10)
ligacao.request('DELETE', '/balde34/copias/teste/a1.txt')
print(ligacao.getresponse().status)
PYTHON
)"
k_131="$(sim34 "$m_k131" "l['servico']=='s3' and l['metodo']=='DELETE' and l['consulta']==[]")"
f_131="$(grep -c -F ".pedir('DELETE'" "$root_dir"/painel/*.py | awk -F: '{n += $2} END {print n}') $(grep -c -E "^    '(GET|HEAD|PATCH)'" "$root_dir/painel/s3.py" || true)"
[[ "$r_131" == "28 proibido · recusado recusado" && "$d_131" == 2 && "$c_131" == "1 1" && "$a_131" == 0 && "$b_131" == 0 && "$s_131" == 403 && "$k_131" == 1 && "$f_131" == "1 0" ]]
caso $? seguranca 131 "Nenhum pedido de apagar, ler ou mexer no bucket e na conversa sai do painel" "chamadas feitas direto aos módulos de saída, dentro do container do painel (DELETE de objeto, com versão, com identificador de envio vazio, com parâmetro a mais e no bucket; apagar vários por POST; POST sem consulta; PUT de regra do bucket e de bucket; GET e HEAD; método em minúsculas; GET, HEAD, PATCH e OPTIONS direto na conexão; deleteMessage, deleteMessages, editMessageText, getUpdates, setWebhook, banChatMember, operação em minúsculas e vazia): quantas e o que cada uma levantou: $r_131 (depois do ponto, os dois pedidos de controle, permitidos e com credencial que não vale); pedidos que chegaram ao simulador durante as chamadas: $d_131, sendo o PUT e o sendMessage de controle: $c_131; em toda a etapa, pedidos ao S3 com DELETE de objeto ou fora da lista: $a_131, operações do bot fora das duas, descontado o pedido de controle do caso 128, feito de dentro do simulador: $b_131; controle, DELETE de objeto feito de dentro do simulador: código $s_131, linhas no registro: $k_131; no código do painel, chamadas com DELETE e métodos de leitura na lista do s3.py: $f_131"

# ------------------------------------------------------------------ PAINEL_DESTINOS=nao desliga tudo
gravar_env "$ENVA" PAINEL_DESTINOS nao; dep; r_dep1=$?; painel_de_pe
e_adm3="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
t_men="$(aba -b "$J" "$B/usuarios")"; f_men="$(tem34 'href="/destinos"')"; a_rotas="$(rotas34 "$J" "$K")"
a_rotasc="$(rotasc34 "$J" "$K")"; copia34; r_cnao="$? $(grep -c -F 'FALHA: os destinos estão desligados nesta instalação (PAINEL_DESTINOS=nao)' "$W/copia34" || true)"
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
[[ "$r_dep1" == 0 && "$e_adm3" == 303 && "$t_men" == "200 " && "$f_men" == 0 && "$a_rotas" == "404 404 404 404 404 404 404 404 404 404 404 " && "$r_ter1" == 1 && "$f_ter1" == 1 \
  && "$ok_var" == 0 && "$d_nao" == 0 && "$r_dep2" == 0 && "$e_adm4" == 303 && "$t_men2" == "200 " && "$f_men2" -ge 1 && "$d_sim" == 1 ]]
caso $? seguranca 129 "PAINEL_DESTINOS=nao desliga os destinos; variável fora da regra é recusada" "deploy.sh com PAINEL_DESTINOS=nao: saída $r_dep1; menu do administrador ($t_men) com a aba Destinos: $f_men; as onze rotas com a sessão e o token dele: $a_rotas; terminal: saída $r_ter1, 'os destinos estão desligados nesta instalação' ($f_ter1); com o andamento do S3 apagado, pedidos que o simulador recebeu em 75 s: $d_nao; container do painel com a variável fora da regra: $ev_var de volta a PAINEL_DESTINOS=sim: saída $r_dep2, aba no menu ($f_men2) e o arquivo reenviado sozinho pela passada (controle): $d_sim"

# ------------------------------------------------------------------ a cópia do sistema para o S3
# O sistema inteiro (auth, dados, certs e painel) em um arquivo só, cifrado com a chave pública da cópia e enviado em
# partes pelo próprio painel. O simulador guarda em $D34/objetos o que chega no prefixo copia34/, e é esse arquivo que
# a etapa abre com a chave privada da instância de teste e entrega ao scripts/restaurar.sh. A pasta cop34 fica fora
# das que o S3 e o bot vigiam: o que a etapa muda nela não vira envio.
planta34 <<'SH'
mkdir -p /data/cop34 && cd /data/cop34 && echo 'fica na cópia do sistema' > fica.txt && head -c 300000 /dev/urandom > corpo.bin
chown -R ftpdata:ftpdata /data/cop34
SH
cs_fica="$(soma34 cop34/fica.txt)"; m_c0=$(marca34)
# Antes de configurar: o cartão oferece a configuração, o terminal diz que não há, e o botão pedido mesmo assim não copia.
cs_t0="$(aba -b "$J" "$B/destinos")"; cs_f0="$(faltam34 '<section class="cartao dobra"><details class="como"><summary><h2>' 'Cópia do sistema <span class="etiqueta">não configurada</span>' 'href="/destinos/copia"')"
copia34; cs_r0="$? $(tc34 'cópia do sistema: não configurada') $(tc34 'nenhuma cópia ainda')"
cs_b0="$(botao34)"
cs_tf="$(aba -b "$J" "$B/destinos/copia")"; cs_ff="$(faltam34 'name="destino" value="s3" checked' 'name="prefixo" value="copia-do-sistema"' 'name="dias"' 'name="hora"' 'name="senha_atual"')"
# Formulário fora da regra: recusado antes de pedir a senha, e nada é gravado.
ok_ci=0; ev_ci=""
recusac34 'Escolha um armazenamento S3 com os segredos gravados.' destino=telegram
recusac34 'Escolha um armazenamento S3 com os segredos gravados.' destino=s3-9
recusac34 'Prefixo inválido: até 8 níveis separados por barra, com letras, números, _, - e ponto.' prefixo=../fora
recusac34 'Rotina inválida: de 0 a 30 dias.' dias=31
recusac34 'Rotina inválida: de 0 a 30 dias.' dias=x
recusac34 'Hora inválida: use HH:MM, de 00:00 a 23:59.' hora=25:00
cs_x="$(gcopia34 "$J" "$K" "")"; cs_fx="$(tem34 'A sua senha atual não confere. Nada foi alterado.')"
cs_cx="$(docker exec "$PAINEL" test -e /painel/destinos/copia.conf && echo sim || echo nao)"
cs_e1="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
# Gravada com a senha do administrador, só pelo botão: a rotina fica para o caso 90.
cs_g="$(gcopia34 "$J" "$K" "$W/painel.senha")"
cs_tg="$(aba -b "$J" "$B/destinos?m=copia_gravada")"
cs_fg="$(faltam34 'Cópia do sistema gravada. A rotina vale a partir de agora.' '<section class="cartao dobra"><details class="como"><summary><h2>' 'Cópia do sistema <span class="etiqueta">só pelo botão</span>' '<code>balde34</code> / <code>copia34/sistema</code>' 'só pelo botão ou pelo terminal' 'nenhuma ainda' 'action="/destinos/copia/agora"')"
auditoria; cs_lg="$(linhas34 " evento=copia_gravada admin=$ADMIN destino=s3 prefixo=copia34/sistema dias=0 hora=03:00\$")"
# O botão: a tela volta na hora e a cópia é feita em segundo plano, por um processo à parte do painel.
m_c1=$(marca34); cs_b="$(botao34)"
aba -b "$J" "$B/destinos?m=copia_pedida" > /dev/null; cs_fb="$(tem34 'Cópia do sistema pedida: ela é feita em segundo plano. Atualize a tela para acompanhar.')"
aguarda34 ' evento=copia_enviada origem=tela destino=s3 objeto=copia34/sistema/' 1 180; cs_ra=$?
cs_l="$(grep -E " evento=copia_enviada origem=tela destino=s3 objeto=copia34/sistema/$NOME-[0-9]{8}-[0-9]{6}\.tar\.gz\.age bytes=[0-9]+ partes=[0-9]+ arquivos=[0-9]+ mudaram=[0-9]+ fora=[0-9]+\$" "$W/auditoria" | tail -n 1)"
cs_n="$(sed -n -E 's|.* objeto=copia34/sistema/([^ ]+) bytes=.*|\1|p' <<< "$cs_l")"; cs_by="$(sed -n -E 's|.* bytes=([0-9]+) partes=.*|\1|p' <<< "$cs_l")"
cs_pa="$(sed -n -E 's|.* partes=([0-9]+) arquivos=.*|\1|p' <<< "$cs_l")"; cs_ar="$(sed -n -E 's|.* arquivos=([0-9]+) mudaram=.*|\1|p' <<< "$cs_l")"; cs_fo="$(sed -n -E 's|.* fora=([0-9]+)$|\1|p' <<< "$cs_l")"
cs_lp="$(linhas34 " evento=copia_pedida admin=$ADMIN resultado=sem_destino\$") $(linhas34 " evento=copia_pedida admin=$ADMIN resultado=ok\$")"
cs_va="$(vaza34 "$W/auditoria")"
# O que chegou ao S3: um envio em partes concluído, o arquivo da soma, e nada além de gravar.
cs_sa="$(copias34 "$m_c1" "l['op']=='abrir_partes' and l['chave']=='copia34/sistema/$cs_n'")"; cs_sp="$(copias34 "$m_c1" "l['op']=='parte' and l['chave']=='copia34/sistema/$cs_n'")"
cs_ss="$(sim34 "$m_c1" "l['op']=='gravar' and l['chave']=='copia34/sistema/$cs_n' and l['bytes']==${cs_by:-0} and l['partes']==${cs_pa:-0}" "l['sha256']")"
cs_s2="$(copias34 "$m_c1" "l['op']=='gravar' and l['chave']=='copia34/sistema/$cs_n.sha256' and l['bytes']==$(( 67 + ${#cs_n} ))")"
cs_so="$(copias34 "$m_c1" "l['op'] not in ('abrir_partes', 'parte', 'gravar')")"
# O objeto guardado: cifrado, com a soma que o arquivo ao lado diz, e só abre com a chave privada da cópia.
cs_arq="$D34/objetos/$cs_n"
cs_o="$( cd "$D34/objetos" 2> /dev/null && sha256sum --status -c "$cs_n.sha256" 2> /dev/null; echo $? ) $(sha256sum "$cs_arq" 2> /dev/null | cut -c1-64) $(head -c 21 "$cs_arq" 2> /dev/null) $(stat -c %s "$cs_arq" 2> /dev/null)"
abrir_copia "$cs_arq" "$S/backup-chave-privada.txt" tar -tzf - > "$W/copia34.lista" 2> /dev/null; cs_ab=$?
cs_li="$(grep -c -v -E '^(dados|auth|certs|painel)(/|$)' "$W/copia34.lista" || true) $(grep -c -x -F -e auth/pureftpd.passwd -e dados/cop34/fica.txt -e dados/cop34/corpo.bin -e painel/destinos/copia.conf -e painel/auditoria.log "$W/copia34.lista" || true) $(grep -c -E '^painel/destinos/(copia\.estado|\.trava-copia)$' "$W/copia34.lista" || true)"
cs_ce="$(grep -c -E '^certs/.' "$W/copia34.lista" || true)"
# Fila (o cano do conjunto A) não entra na cópia e é contada como de fora.
docker exec "$FTP" sh -c 'cd /data && find . -type p | sed "s|^\./|dados/|"' > "$W/copia34.canos"
cs_can="$(wc -l < "$W/copia34.canos") $(grep -c -x -F -f "$W/copia34.canos" "$W/copia34.lista" || true)"
cs_cf="$(abrir_copia "$cs_arq" "$S/backup-chave-privada.txt" tar -xzOf - dados/cop34/fica.txt 2> /dev/null | sha256sum | cut -c1-64)"
cs_se="$(abrir_copia "$cs_arq" "$S/backup-chave-privada.txt" tar -xzOf - 2> /dev/null | vaza34 /dev/stdin)"
aba -b "$J" "$B/destinos" > /dev/null; cs_fu="$(faltam34 "<code>$cs_n</code>" 'action="/destinos/copia/agora"')$(tem34 'não foi concluída')"; cs_v="$(vaza34 "$W/corpo") $cs_va"
[[ "$cs_t0" == "200 " && "$cs_f0" == 0 && "$cs_r0" == "0 1 1" && "$cs_b0" == "303 /destinos?m=copia_falha&f=sem_destino" && "$cs_tf" == "200 " && "$cs_ff" == 0 && "$ok_ci" == 0 \
  && "$cs_x" == "403 " && "$cs_fx" -ge 1 && "$cs_cx" == nao && "$cs_e1" == 303 && "$cs_g" == "303 /destinos?m=copia_gravada" && "$cs_tg" == "200 " && "$cs_fg" == 0 && "$cs_lg" == 1 \
  && "$cs_b" == "303 /destinos?m=copia_pedida" && "$cs_fb" -ge 1 && "$cs_ra" == 0 && -n "$cs_n" && "$cs_by" -gt 0 && "$cs_pa" -ge 1 && "$cs_ar" -ge 5 && "$cs_lp" == "1 1" \
  && "$cs_sa" == 1 && "$cs_sp" == "$cs_pa" && "$cs_ss" =~ ^[0-9a-f]{64}$ && "$cs_s2" == 1 && "$cs_so" == 0 && "$cs_o" == "0 $cs_ss age-encryption.org/v1 $cs_by" \
  && "$cs_ab" == 0 && "$cs_li" == "0 5 0" && "$cs_ce" -ge 1 && "${cs_can%% *}" -ge 1 && "${cs_can##* }" == 0 && "$cs_fo" -ge "${cs_can%% *}" && "$cs_cf" == "$cs_fica" && "$cs_se" == 0 \
  && "$cs_fu" == 00 && "$cs_v" == "0 0" ]]
caso $? testes 87 "Cópia do sistema: configurada e pedida pelo painel, chega cifrada ao S3 com o arquivo da soma" "antes de configurar: aba Destinos ($cs_t0) com o cartão recolhido, 'não configurada' e o link Configurar, textos que faltam: $cs_f0; servidor.py --copia: saída, 'não configurada' e 'nenhuma cópia ainda': $cs_r0; botão pedido assim mesmo: $cs_b0; formulário ($cs_tf), campos que faltam: $cs_ff; formulário fora da regra: $ev_ci; gravação sem a senha: $cs_x, 'A sua senha atual não confere' ($cs_fx), copia.conf gravado: $cs_cx; nova entrada: $cs_e1; gravação com a senha: $cs_g, tela ($cs_tg) com a mensagem e o cartão recolhido, com 'só pelo botão', bucket e pasta e o botão, textos que faltam: $cs_fg, linha copia_gravada na auditoria: $cs_lg; botão Copiar e enviar agora: $cs_b, tela com 'feita em segundo plano' ($cs_fb); espera pela linha copia_enviada origem=tela: saída $cs_ra; objeto $cs_n, $cs_by bytes em $cs_pa parte(s), $cs_ar arquivo(s), $cs_fo de fora; linhas copia_pedida com sem_destino e com ok: $cs_lp; no simulador, para a chave do objeto: envios em partes abertos $cs_sa, partes $cs_sp, conclusão com o mesmo tamanho e as mesmas partes: soma ${cs_ss:0:16}…, arquivo .sha256 com o tamanho esperado: $cs_s2, pedidos com chave da cópia que não são de gravar: $cs_so; o arquivo guardado: sha256sum -c do .sha256, soma, cabeçalho e tamanho: $(cut -d' ' -f1 <<< "$cs_o") ${cs_o:2:16}… $(cut -d' ' -f3- <<< "$cs_o"); aberto com a chave privada da cópia (saída $cs_ab): itens fora de dados, auth, certs e painel, os cinco esperados (cadastro, os dois arquivos de cop34, copia.conf e a auditoria) e o andamento ou a trava da própria cópia: $cs_li; itens de certs: $cs_ce; filas em /data e quantas delas estão na cópia: $cs_can; soma do fica.txt de dentro da cópia igual à do servidor: $([[ "$cs_cf" == "$cs_fica" ]] && echo sim || echo nao); linhas do conteúdo com segredo dos destinos: $cs_se; cartão com o nome do objeto e o botão (faltam) e 'não foi concluída': $cs_fu; linhas com segredo dos destinos na tela e na auditoria: $cs_v"

# A restauração: o que mudou depois da cópia some, e o que ela levou volta. A auditoria também volta ao momento da
# cópia: por isso as linhas dela foram conferidas antes.
cs_u0="$(usuarios_ftp)"
planta34 <<'SH'
cd /data/cop34 && echo 'criado depois da cópia' > depois34.txt && chown ftpdata:ftpdata depois34.txt && rm -f fica.txt
SH
nova_senha "$W/cop34.senha"; mu add depois34 "$W/cop34.senha"; cs_ua=$?; cs_u1="$(usuarios_ftp)"; cs_h0="$(ha34 cop34/depois34.txt) $(ha34 cop34/fica.txt)"
restaurar "$cs_arq" "$W/copia34.restaura"; cs_rr=$?
cs_rl="$(grep -c -E '^Cópia: .*, soma sha256 conferida\)$' "$W/copia34.restaura" || true) $(grep -c -x -F 'Restaurado e no ar (healthy).' "$W/copia34.restaura" || true)"
painel_de_pe; cs_sd="$(saude "$FTP" "$PAINEL" "$NGINX")"
cs_e2="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
cs_h="$(ha34 cop34/depois34.txt) $(ha34 cop34/fica.txt)"; cs_f2="$(soma34 cop34/fica.txt 2> /dev/null)"; cs_u2="$(usuarios_ftp)"
# O andamento da cópia não vai dentro dela: depois de restaurar, o painel tem a configuração e nenhuma cópia feita.
copia34; cs_r2="$? $(tc34 'cópia do sistema: s3 (balde34/copia34/sistema); só pelo botão ou pelo terminal') $(tc34 'nenhuma cópia ainda') $(grep -c -F 'interrompida' "$W/copia34" || true)"
[[ "$cs_ua" == 0 && " $cs_u1" == *" depois34 "* && " $cs_u0" != *" depois34 "* && "$cs_h0" == "sim nao" && "$cs_rr" == 0 && "$cs_rl" == "1 1" && "$cs_sd" == "healthy healthy healthy " && "$cs_e2" == 303 \
  && "$cs_h" == "nao sim" && "$cs_f2" == "$cs_fica" && "$cs_u2" == "$cs_u0" && "$cs_r2" == "0 1 1 0" ]]
caso $? testes 88 "Cópia do sistema feita pelo painel é restaurada pelo restaurar.sh" "depois da cópia: usuário depois34 criado (saída $cs_ua), arquivo novo em cop34 e fica.txt apagado (depois34.txt e fica.txt no servidor: $cs_h0); restaurar.sh com o objeto que o S3 de exemplo guardou: saída $cs_rr, linhas 'soma sha256 conferida' e 'Restaurado e no ar (healthy).': $cs_rl; containers: $cs_sd; entrada do administrador: $cs_e2; depois34.txt e fica.txt no servidor: $cs_h, soma do fica.txt igual à de antes: $([[ "$cs_f2" == "$cs_fica" ]] && echo sim || echo nao); usuários do FTP iguais aos de antes da mudança: $([[ "$cs_u2" == "$cs_u0" ]] && echo sim || echo nao) ($cs_u2); servidor.py --copia: saída, linha da configuração, 'nenhuma cópia ainda' e 'interrompida': $cs_r2"

# Falha no meio: o serviço aceita abrir o envio em partes e recusa a primeira parte. O painel desfaz o envio (o único
# pedido de apagar que existe, e ele não toca em objeto) e nada fica no destino.
m_c2=$(marca34); cs_no="$(ls "$D34/objetos" | wc -l)"
echo 's3 500 1 1 copia34' > "$D34/falhar"; copia34 enviar; cs_rf=$?; rm -f "$D34/falhar"
cs_lf="$(tc34 'cópia do sistema: falhou: http_500; nenhum objeto ficou no destino')"
cs_sf="$(copias34 "$m_c2" "l['op']=='abrir_partes'") $(copias34 "$m_c2" "l['codigo']==500 and l['erro']=='Forcado' and l['metodo']=='PUT' and l['consulta']==['partNumber', 'uploadId']") $(copias34 "$m_c2" "l['op']=='abandonar'") $(copias34 "$m_c2" "l['op'] in ('gravar', 'parte')")"
auditoria; cs_af="$(linhas34 ' evento=copia_falhou origem=terminal motivo=http_500 partes=0$')"; cs_nf="$(ls "$D34/objetos" | wc -l)"
aba -b "$J" "$B/destinos" > /dev/null; cs_ft="$(faltam34 '<section class="cartao dobra"><details class="como" open><summary><h2>' 'não foi concluída: o serviço respondeu com o código 500.' 'action="/destinos/copia/agora"')"
copia34; cs_r3="$? $(tc34 'última cópia: falhou: http_500; nenhum objeto ficou no destino')"
[[ "$cs_rf" == 1 && "$cs_lf" == 1 && "$cs_sf" == "1 1 1 0" && "$cs_af" == 1 && "$cs_no" == 2 && "$cs_nf" == 2 && "$cs_ft" == 0 && "$cs_r3" == "0 1" ]]
caso $? testes 89 "Cópia do sistema: a falha no meio desfaz o envio em partes e nada fica no destino" "S3 de exemplo recusando com 500 a primeira parte; servidor.py --copia enviar: saída $cs_rf, linha 'falhou: http_500; nenhum objeto ficou no destino': $cs_lf; no simulador, com chave da cópia: envios em partes abertos, parte recusada com 500, envio desfeito e pedidos de parte ou de objeto aceitos: $cs_sf; linha copia_falhou origem=terminal motivo=http_500 partes=0 na auditoria: $cs_af; arquivos guardados pelo simulador antes e depois: $cs_no e $cs_nf; cartão já aberto, com 'não foi concluída: o serviço respondeu com o código 500' e o botão, textos que faltam: $cs_ft; servidor.py --copia: saída e 'última cópia: falhou: http_500': $cs_r3"

# Pelo terminal: uso errado recusado, e a cópia feita na hora diz o objeto, o tamanho e a soma, que é a do simulador.
copia34 outra; cs_uo="$? $(grep -c -F 'FALHA: uso: --copia [enviar]' "$W/copia34" || true)"
m_c3=$(marca34); copia34 enviar; cs_rt=$?
cs_lt="$(grep -E "^cópia do sistema: s3:balde34/copia34/sistema/$NOME-[0-9]{8}-[0-9]{6}\.tar\.gz\.age; [0-9]+ bytes em [0-9]+ parte\(s\); [0-9]+ arquivo\(s\), [0-9]+ mudaram durante a leitura, [0-9]+ de fora \(soquete, fila ou dispositivo\); sha256 [0-9a-f]{64}\$" "$W/copia34" | tail -n 1)"
cs_nt="$(sed -n -E 's|^cópia do sistema: s3:balde34/copia34/sistema/([^;]+);.*|\1|p' <<< "$cs_lt")"; cs_ht="${cs_lt##* }"; cs_vt="$(vaza34 "$W/copia34")"
cs_st="$(sim34 "$m_c3" "l['op']=='gravar' and l['chave']=='copia34/sistema/$cs_nt'" "l['sha256']")"; cs_dt="$(sha256sum "$D34/objetos/$cs_nt" 2> /dev/null | cut -c1-64)"
auditoria; cs_at="$(linhas34 " evento=copia_enviada origem=terminal destino=s3 objeto=copia34/sistema/$cs_nt ")"
# A rotina: marcada para daqui a um minuto e meio, faz a cópia sozinha na hora, uma vez só.
cs_hr="$(docker exec "$PAINEL" python3 -c 'import time; print(time.strftime("%H:%M", time.localtime(time.time() + 90)))')"
cs_gr="$(gcopia34 "$J" "$K" "$W/painel.senha" dias=1 "hora=$cs_hr")"
aba -b "$J" "$B/destinos" > /dev/null; cs_fr="$(faltam34 'Cópia do sistema <span class="etiqueta">rotina ligada</span>' "todo dia, às $cs_hr (hora do servidor)")"
aguarda34 ' evento=copia_enviada origem=rotina destino=s3 objeto=copia34/sistema/' 1 240; cs_rw=$?; cs_ini=$SECONDS

# Enquanto a rotina tem mais de um minuto para provar que não repete: quem não é o administrador não alcança a cópia.
e_usu3="$(COMO=dst34 entrar "$W/dst34.jar" "$W/dst34.senha")"; proibir "$(biscoito_de "$W/dst34.jar")"; K_u3="$(token34 "$W/dst34.jar")"; proibir "$K_u3"
m_133=$(marca34); auditoria; n_cp="$(eventos copia_pedida)"; n_cg="$(eventos copia_gravada)"
cs_k0="$(docker exec "$PAINEL" sha256sum /painel/destinos/copia.conf | cut -c1-64)"
cs_ru="$(rotasc34 "$W/dst34.jar" "$K_u3")"
# A aba Serviço, enquanto isso: só o administrador a abre, ela não tem ação nenhuma e não mostra segredo nem endereço do destino.
auditoria; n_sg="$(eventos 'recusa_papel usuario=dst34 caminho=/servico')"
sg_u="$(aba -b "$W/dst34.jar" "$B/servico" | cut -c1-3) $(POTE="$W/dst34.jar" envio /servico --data-urlencode "csrf=$K_u3" | cut -c1-3)"
sg_um="$(aba -b "$W/dst34.jar" "$B/meus-arquivos" | cut -c1-3) $(tem34 '/servico')"
sg_s="$(aba -b "$W/vazio34.jar" "$B/servico")"; sg_p="$(envio /servico --data-urlencode "csrf=$K" | cut -c1-3)"
sg_k0="$(docker exec "$PAINEL" sh -c 'cat /painel/destinos/*.conf | sha256sum' | cut -c1-64)"; sg_c0=$(marca34)
sg_a="$(aba -b "$J" "$B/servico")"; sg_c=$(( $(marca34) - sg_c0 )); sg_k1="$(docker exec "$PAINEL" sh -c 'cat /painel/destinos/*.conf | sha256sum' | cut -c1-64)"
sg_v="$(vaza34 "$W/corpo")"; sg_d="$(tem34 'balde34') $(tem34 'copias/teste') $(tem34 "$FIM34")"; sg_m="$(tem34 'href="/servico"')"; sg_t="$(faltam34 'Armazenamento S3 <span class="etiqueta' 'Bot do Telegram <span class="etiqueta' 'Últimos enviados')"
sg_f="$(grep -o '<form[^>]*>' "$W/corpo" | grep -c -v -e 'action="/idioma"' -e 'action="/sair"' || true)"
auditoria; sg_r=$(( $(eventos 'recusa_papel usuario=dst34 caminho=/servico') - n_sg ))
cs_z="$(gcopia34 "$J" "" "$W/painel.senha" prefixo=copia34/invasor)$(gcopia34 "$J" token-errado "$W/painel.senha" prefixo=copia34/invasor)$(ORIGEM34=https://fora.example gcopia34 "$J" "$K" "$W/painel.senha" prefixo=copia34/invasor)$(gcopia34 "$W/vazio34.jar" "$K" "$W/painel.senha" prefixo=copia34/invasor)"
cs_zb="$(botao34 '')$(botao34 token-errado)$(c -o /dev/null -w '%{http_code} %{redirect_url}' -b "$J" -H 'Origin: https://fora.example' --data-urlencode "csrf=$K" "$B/destinos/copia/agora" | sed "s|$B||")$(POTE="$W/vazio34.jar" botao34)"
# A chave privada da cópia não existe no painel: ele só tem a pública, e enxerga os certificados sem poder escrever.
cs_seg="$(docker exec "$PAINEL" ls /run/secrets | tr '\n' ' ')"
cs_pub="$(docker exec "$PAINEL" cat /run/secrets/backup_chave_publica | cmp -s - "$S/backup-chave-publica.txt"; echo $?)"
cs_priv="$(docker exec "$PAINEL" sh -c 'grep -r -l -a -F AGE-SECRET-KEY /run/secrets /painel /certs /auth 2> /dev/null | wc -l') $(grep -c -F AGE-SECRET-KEY "$S/backup-chave-privada.txt" || true)"
cs_ro="$(docker exec "$PAINEL" sh -c 'touch /certs/x34 2> /dev/null && echo gravou || echo recusou') $(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/certs"}}{{.RW}}{{end}}{{end}}' "$PAINEL")"
while (( SECONDS - cs_ini < 75 )); do sleep 3; done
auditoria; cs_d133="$(copias34 "$m_133") $(( $(eventos copia_pedida) - n_cp )) $(( $(eventos copia_gravada) - n_cg ))"; cs_lr="$(linhas34 ' evento=copia_enviada origem=rotina ') $(linhas34 ' evento=copia_falhou origem=rotina ')"
cs_k1="$(docker exec "$PAINEL" sha256sum /painel/destinos/copia.conf | cut -c1-64)"

# A cópia vai para o S3 escolhido mesmo com ele desligado para as pastas; removido esse destino, ela fica sem destino.
cs_g2="$(grava34 s3 "$J" "$K" "$W/painel.senha" id=novo copiar=s3 pasta=cop34 prefixo=copias/outra34 -ligado)"
cs_g3="$(gcopia34 "$J" "$K" "$W/painel.senha" destino=s3-2 prefixo=copia34/outra)"
m_c4=$(marca34); copia34 enviar; cs_r4=$?; cs_s4="$(copias34 "$m_c4" "l['op']=='gravar' and l['chave'].startswith('copia34/outra/$NOME-') and l['chave'].endswith('.tar.gz.age')") $(copias34 "$m_c4" "l['chave'].startswith('copia34/sistema/')")"
cs_tr="$(aba -b "$J" "$B/destinos/remover?destino=s3-2")$(tem34 'Este é o destino da cópia do sistema: sem ele, a cópia fica sem destino e a rotina dela para.')"
cs_tr+=" $(aba -b "$J" "$B/destinos/remover?destino=s3")$(tem34 'Este é o destino da cópia do sistema')"
auditoria; n_rs="$(linhas34 " evento=destino_removido admin=$ADMIN destino=s3-2\$")"
cs_rm="$(envio /destinos/remover --data-urlencode "csrf=$K" --data-urlencode "destino=s3-2" --data-urlencode "senha_atual@$W/painel.senha")"
auditoria; cs_ls="$(linhas34 " evento=copia_sem_destino admin=$ADMIN destino=s3-2\$") $(( $(linhas34 " evento=destino_removido admin=$ADMIN destino=s3-2\$") - n_rs ))"
m_c5=$(marca34)
copia34; cs_r5="$? $(tc34 'cópia do sistema: não configurada')"
copia34 enviar; cs_r6="$? $(tc34 'cópia do sistema: falhou: sem_destino; nenhum objeto ficou no destino')"
cs_b5="$(botao34)"
aba -b "$J" "$B/destinos?m=copia_falha&f=sem_destino" > /dev/null
cs_f5="$(faltam34 'Cópia do sistema: não começou. Motivo: a cópia do sistema não tem um S3 escolhido com os segredos gravados.' 'Cópia do sistema <span class="etiqueta">não configurada</span>')"
cs_d5="$(copias34 "$m_c5")"; cs_c5="$(docker exec "$PAINEL" test -e /painel/destinos/copia.conf && echo sim || echo nao) $(ls "$S/destinos" 2> /dev/null | tr '\n' ' ')"
# Em todo o trecho da cópia: nenhum pedido de ler, listar ou apagar; o único envio em partes desfeito é o da falha forçada.
cs_ap="$(sim34 "$m_c0" "l['servico']=='s3' and l['op']=='outra'") $(sim34 "$m_c0" "l['op']=='abandonar'")"

[[ "$e_usu3" == 303 && -n "$K_u3" && "$cs_ru" == "404 404 404 " && "$cs_z" == "403 403 403 303 /entrar" && "$cs_zb" == "403 403 403 303 /entrar" && "$cs_d133" == "0 0 0" && "$cs_k1" == "$cs_k0" && -n "$cs_k0" \
  && "$a_rotasc" == "404 404 404 " && "$r_cnao" == "1 1" && "$cs_seg" == "backup_chave_publica painel_admin_inicial_senha_hash " && "$cs_pub" == 0 && "$cs_priv" == "0 1" && "$cs_ro" == "recusou false" \
  && "$cs_ap" == "0 1" && "$cs_vt" == 0 ]]
caso $? seguranca 133 "Cópia do sistema: só o administrador, com sessão, token e senha; a chave privada fica fora do painel e nada é apagado no destino" "usuário do FTP dst34 (entrada $e_usu3) nas três rotas da cópia (formulário, gravação e botão): $cs_ru; gravação pelo administrador sem token, com token errado, com origem de fora e sem sessão: $cs_z; o botão, nas mesmas quatro: $cs_zb; depois delas e de mais de um minuto: pedidos ao S3 com chave da cópia, linhas copia_pedida e linhas copia_gravada a mais: $cs_d133; copia.conf igual ao de antes: $([[ -n "$cs_k0" && "$cs_k1" == "$cs_k0" ]] && echo sim || echo nao); com PAINEL_DESTINOS=nao, as três rotas com a sessão do administrador: $a_rotasc, e servidor.py --copia (saída e 'os destinos estão desligados nesta instalação'): $r_cnao; segredos montados no painel: $cs_seg; chave pública igual à do host (cmp): $cs_pub; arquivos com chave privada da cópia em /run/secrets, /painel, /certs e /auth, e o controle (a mesma busca no arquivo da chave privada, no host): $cs_priv; escrita em /certs e o modo da montagem (RW): $cs_ro; no simulador, em todo o trecho da cópia: pedidos de ler, listar ou apagar e envios em partes desfeitos (o da falha forçada): $cs_ap; linhas com segredo dos destinos na saída do terminal: $cs_vt"

# ------------------------------------------------------------------ a aba Serviço: só do administrador, só leitura e sem segredo
[[ "$sg_u" == "404 404" && "$sg_um" == "200 0" && "$sg_s" == "303 /entrar" && "$sg_p" == 404 && "$sg_a" == "200 " && "$sg_t" == 0 && "$sg_m" -ge 1 && "$sg_f" == 0 \
  && "$sg_v" == 0 && "$sg_d" == "0 0 0" && "$sg_c" == 0 && "$sg_k1" == "$sg_k0" && -n "$sg_k0" && "$sg_r" == 1 ]]
caso $? seguranca 162 "Aba Serviço: só o administrador, só leitura e sem segredo" "usuário do FTP dst34, com a sessão e o token dele: GET e POST em /servico $sg_u, com $sg_r recusa_papel na auditoria; tela dele ($sg_um: código e vezes em que /servico aparece); sem sessão: $sg_s; POST do administrador, com o token dele: $sg_p (a aba não tem rota de envio); aba com o administrador: $sg_a, cartões dos destinos e listas na tela (faltam $sg_t), no menu ($sg_m), formulários além do idioma e da saída: $sg_f; linhas com chave do S3, token do bot ou conversa: $sg_v; vezes do bucket, do prefixo e do endereço do destino: $sg_d; pedidos ao serviço de exemplo ao abrir a tela: $sg_c; soma dos .conf dos destinos igual antes e depois"

[[ "$cs_uo" == "1 1" && "$cs_rt" == 0 && -n "$cs_nt" && "$cs_nt" != "$cs_n" && "$cs_ht" =~ ^[0-9a-f]{64}$ && "$cs_st" == "$cs_ht" && "$cs_dt" == "$cs_ht" && "$cs_at" == 1 \
  && "$cs_gr" == "303 /destinos?m=copia_gravada" && "$cs_fr" == 0 && "$cs_rw" == 0 && "$cs_lr" == "1 0" \
  && "$cs_g2" == "303 /destinos?m=gravado" && "$cs_g3" == "303 /destinos?m=copia_gravada" && "$cs_r4" == 0 && "$cs_s4" == "1 0" && "$cs_tr" == "200 1 200 0" \
  && "$cs_rm" == "303 /destinos?m=removido" && "$cs_ls" == "1 1" && "$cs_r5" == "0 1" && "$cs_r6" == "1 1" && "$cs_b5" == "303 /destinos?m=copia_falha&f=sem_destino" && "$cs_f5" == 0 && "$cs_d5" == 0 \
  && "$cs_c5" == "nao s3-chave-de-acesso.txt s3-chave-secreta.txt telegram-conversa.txt telegram-token.txt " ]]
caso $? testes 90 "Cópia do sistema pelo terminal, pela rotina e sem o destino dela" "servidor.py --copia com argumento que não existe: saída e mensagem de uso: $cs_uo; --copia enviar: saída $cs_rt, objeto $cs_nt, soma da linha igual à do simulador e à do arquivo guardado: $([[ -n "$cs_ht" && "$cs_st" == "$cs_ht" && "$cs_dt" == "$cs_ht" ]] && echo sim || echo nao), linha copia_enviada origem=terminal: $cs_at; rotina gravada para $cs_hr, todo dia: $cs_gr, cartão com 'rotina ligada' e a hora, textos que faltam: $cs_fr; espera pela cópia da rotina: saída $cs_rw; mais de um minuto depois, linhas copia_enviada e copia_falhou da rotina: $cs_lr; segundo S3 com o acesso do primeiro, desligado: $cs_g2; cópia apontada para ele: $cs_g3; --copia enviar: saída $cs_r4, objetos no prefixo novo e pedidos no prefixo antigo: $cs_s4; tela de remover o s3-2 e o aviso do destino da cópia, e a do s3 sem ele: $cs_tr; remoção com a senha: $cs_rm, linhas copia_sem_destino e destino_removido: $cs_ls; depois: --copia (saída e 'não configurada'): $cs_r5, --copia enviar (saída e 'falhou: sem_destino'): $cs_r6, botão: $cs_b5, tela com o motivo e o cartão 'não configurada', textos que faltam: $cs_f5, pedidos ao S3 com chave da cópia: $cs_d5; copia.conf no painel e os segredos que restaram: $cs_c5"

# ------------------------------------------------------------------ pelo terminal e a remoção
passou34 s3; terminal34; r_sit=$?
l_sit="$(grep -c -E '^telegram: ligado; pasta /data/dst34; a cada 1440 min; última passada: [0-9]+ arquivo\(s\), ' "$W/terminal34" || true) $(grep -c -E '^s3: ligado; pasta /data/dst34/sub; a cada 1440 min; última passada: [0-9]+ arquivo\(s\), ' "$W/terminal34" || true)"
u_ter=""
terminal34 enviar; u_ter+="$? $(grep -c -F 'FALHA: uso: --destinos [enviar <destino> [--sem-espera]]; o destino é o nome que a lista mostra' "$W/terminal34" || true) · "
terminal34 enviar ftp; u_ter+="$? $(grep -c -F 'FALHA: uso: --destinos [enviar <destino> [--sem-espera]]; o destino é o nome que a lista mostra' "$W/terminal34" || true) · "
terminal34 enviar s3 --depressa; u_ter+="$? $(grep -c -F 'FALHA: uso: --destinos [enviar <destino> [--sem-espera]]; o destino é o nome que a lista mostra' "$W/terminal34" || true) · "
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
s_depois="$(ls "$S/destinos" 2>/dev/null | tr '\n' ' ')"; c_depois="$(docker exec "$PAINEL" sh -c 'ls /painel/destinos | grep -E "^(s3|telegram)(-[0-9]+)?\.(conf|estado)$" | tr "\n" " "')"
h_fim="$(ha34 dst34/a1.txt) $(ha34 dst34/sub/a3.txt) $(ha34 dst34/grande.bin)"
# Remoção do bot e, sem nenhum destino, nada sai: nem pelo terminal.
g_rem2="$(envio /destinos/remover --data-urlencode "csrf=$K" --data-urlencode "destino=telegram" --data-urlencode "senha_atual@$W/painel.senha")"
s_fim="$(ls -A "$S/destinos" 2>/dev/null | wc -l)"; c_fim="$(docker exec "$PAINEL" sh -c 'ls /painel/destinos | grep -c -E "^(s3|telegram)(-[0-9]+)?\.(conf|estado)$"' || true)"
terminal34; r_sit2=$?; l_sit2="$(tr '\n' ';' < "$W/terminal34")"
novo34 depois.bin; m_fim=$(marca34); terminal34 enviar s3 --sem-espera; r_fim=$?; terminal34 enviar telegram --sem-espera; r_fim="$r_fim$?"; d_fim=$(( $(marca34) - m_fim ))
auditoria; l_rem="$(linhas34 " evento=destino_removido admin=$ADMIN destino=s3\$") $(linhas34 " evento=destino_removido admin=$ADMIN destino=telegram\$")"
[[ "$r_sit" == 0 && "$l_sit" == "1 1" && "$u_ter" == "1 1 · 1 1 · 1 1 · " && "$g_des" == "303 /destinos?m=gravado" && "$a_des" == "303 /destinos?m=falha&d=s3&f=desligado" && "$f_des" -ge 1 \
  && "$r_des" == 1 && "$f_des2" == 1 && "$s_des" == "s3: desligado" && "$t_rem" == "200 " && "$f_rem" -ge 1 && "$x_rem" == "403 " && "$e_adm5" == 303 \
  && "$s_antes" == "s3-chave-de-acesso.txt s3-chave-secreta.txt telegram-conversa.txt telegram-token.txt " && "$g_rem" == "303 /destinos?m=removido" && "$t_rem2" == "200 " && "$f_rem2" == 0 \
  && "$s_depois" == "telegram-conversa.txt telegram-token.txt " && "$c_depois" == "telegram.conf telegram.estado " && "$h_fim" == "sim sim sim" && "$g_rem2" == "303 /destinos?m=removido" \
  && "$s_fim" == 0 && "$c_fim" == 0 && "$r_sit2" == 0 && "$l_sit2" == "telegram: não configurado;rclone: não configurado;s3: não configurado;" && "$r_fim" == 11 && "$d_fim" == 0 && "$l_rem" == "1 1" ]]
caso $? testes 80 "Destinos pelo terminal e remoção de um destino" "servidor.py --destinos: saída $r_sit, linhas 'ligado; pasta; a cada 1440 min; última passada' do bot e do S3: $l_sit; uso errado (sem destino, destino que não existe, opção que não existe), saída e mensagem de uso: $u_ter; S3 regravado desligado: $g_des; botão Enviar agora: $a_des, tela com 'o destino está desligado ou sem os segredos' ($f_des); pelo terminal: saída $r_des, 'não configurado, desligado ou sem os segredos' ($f_des2), situação '$s_des'; tela de remover o S3: $t_rem, com o botão 'Sim, remover o destino' ($f_rem); sem a senha: $x_rem; com a senha: $g_rem, tela $t_rem2 (textos que faltam: aviso de removido, um 'não configurado' e o bot 'ligado': $f_rem2); pasta dos segredos antes: $s_antes depois: $s_depois; em /painel/destinos: $c_depois; arquivos do servidor (a1.txt, sub/a3.txt, grande.bin): $h_fim; bot removido: $g_rem2, arquivos de segredo: $s_fim, de configuração e andamento: $c_fim; terminal: saída $r_sit2, '$l_sit2'; arquivo novo e passada pedida pelo terminal para os dois: saídas $r_fim, pedidos que o simulador recebeu: $d_fim; destino_removido na auditoria (S3 e bot): $l_rem"

# Sem destino nenhum, a aba Arquivos volta a não ter botão, e a rota pedida mesmo assim não envia.
b_fim="$(aba -b "$J" "$B/arquivos?pasta=dst34")$(vezes34 'para-')"; b_fim_bx="$(vezes34 ' download>')"
m_xfim=$(marca34); x_fim="$(POTE="$J" envio /destinos/arquivo --data-urlencode "csrf=$K" --data-urlencode destino=s3 --data-urlencode arquivo=dst34/a1.txt)"; d_xfim=$(( $(marca34) - m_xfim ))
[[ "$b_ini" == "200 0" && "$b_ini_bx" -ge 4 && "$b_s3" == "1 0 0" && "$e_usu2" == 303 && -n "$K_u2" && "$u_tela" == "200 " && "$u_bot" == "${u_bot%% *} 0 0" && "${u_bot%% *}" -ge 1 \
  && "$u_arq" == "404 404 " && "$z_semtoken" == "403 " && "$z_token" == "403 " && "$z_origem" == "403 " && "$z_semsessao" == "303 /entrar" && "$z_dest" == "404 " \
  && "$z_cam" == "400 400 403 404 404 404 404 " && "$d_130" == 0 && "$d_arq2" == 0 && "$d_cam" -ge 1 && "$b_nao" == "200 0" && "$b_nao_bx" -ge 4 \
  && "$b_bot" == "0 1" && "$b_fim" == "200 0" && "$b_fim_bx" -ge 4 && "$x_fim" == "303 /arquivos?pasta=dst34&m=destino_falha&d=s3&f=segredo" && "$d_xfim" == 0 ]]
caso $? seguranca 130 "Envio de um arquivo ao destino: só o administrador, com token, e botão só com o destino gravado" "aba Arquivos em dst34 antes de qualquer destino gravado: código e botões de envio $b_ini (links Baixar na mesma tela: $b_ini_bx); só com o S3 gravado: formulário do S3, formulário do bot e a diferença entre os botões do S3 e os links Baixar: $b_s3; com os dois gravados e a sessão do administrador: sem token $z_semtoken, token errado $z_token, Origin de fora $z_origem; sem sessão: $z_semsessao; destino que não existe: $z_dest; caminho com '..', caminho começado por barra, link simbólico, arquivo que não existe, pasta, FIFO e campo vazio: $z_cam(recusa_caminho a mais na auditoria: $d_cam); usuário do FTP dono da pasta, com a sessão ($e_usu2) e o token dele: Meus arquivos $u_tela, com o a1.txt na lista, botões de envio e '/destinos' na tela: $u_bot; a rota com o caminho como ele vê e como o administrador vê: $u_arq; pedidos que o simulador recebeu durante todas as recusas: $d_130, destino_arquivo a mais na auditoria: $d_arq2; com PAINEL_DESTINOS=nao, a aba Arquivos do administrador: $b_nao (links Baixar: $b_nao_bx) e a rota entre as onze que respondem 404; depois de removido o S3: formulário do S3 e do bot na tela: $b_bot; depois de removidos os dois: $b_fim (links Baixar: $b_fim_bx), e a rota pedida mesmo assim: $x_fim, pedidos ao simulador: $d_xfim"

docker rm -f "$SIM34" > /dev/null 2>&1
mu del dst34
docker exec "$FTP" rm -rf /data/dst34 /data/tg34 /data/cop34
docker exec "$PAINEL" rm -f /painel/destinos/ca.pem /painel/destinos/copia.conf /painel/destinos/copia.estado /painel/destinos/.trava-copia
rm -rf "$D34"; rm -f "$W"/dst34.* "$W"/i34.* "$W/vazio34.jar" "$W/passada" "$W/cert34.log" "$W/sim34.log" "$W/telas34" "$W/logs34" "$W/inspect34" "$W/terminal34" "$W/estado34" "$W/telas34b" "$W/estado34b" "$W/copia34" "$W/copia34.lista" "$W/copia34.canos" "$W/copia34.restaura" "$W/cop34.senha"
gravar_env "$ENVA" PAINEL_TELEGRAM_API "$api_0"; gravar_env "$ENVA" PAINEL_TELEGRAM_MAX_MB "$max_0"; gravar_env "$ENVA" PAINEL_DESTINOS "$des_0"; dep
painel_de_pe
