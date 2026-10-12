#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa AJ: destino rclone. O administrador grava pelo painel, com a senha dele, um remoto do rclone (SFTP, WebDAV ou
# nuvem de arquivos), e o painel envia o que chega na pasta escolhida: só envia. A etapa sobe, na rede da instância de
# teste, um servidor de arquivos (tests/apoio/servidor_rclone.sh: WebDAV com certificado de uma autoridade criada aqui
# e SFTP, pelo `rclone serve` da imagem do painel) e confere na pasta dele o que chegou: nome e soma de cada arquivo,
# e nada apagado. As quatro nuvens são gravadas desligadas e conferidas com o rclone em container sem rede: nenhum
# pedido sai para terceiros. A senha, a frase, as chaves e os tokens são gerados na hora e não entram em evidência.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel encerra as sessões e zera a memória das recusas (a auditoria guarda uma por minuto de cada tipo).
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"

REM36="$NOME-remoto"; D36="$W/rem36"; GRAVADO36='303 /destinos?m=gravado'; TESTADO36='303 /destinos?m=teste'
A36=(a1.txt a2.bin sub/a3.txt vazio.txt 'relatório final.txt')
SEM36='0 apagado(s) do servidor, 0 acima do limite do bot, 0 ignorado(s), 0 recusado(s)'
tem36() { grep -c -F -- "$1" "$W/corpo" || true; }                                             # <texto>: linhas da última tela com ele
vezes36() { grep -o -F -- "$1" "$W/corpo" | wc -l; }                                           # <texto>: quantas vezes ele está na última tela
linhas36() { grep -c -E -- "$1" "$W/auditoria" || true; }                                      # <expressão>: linhas da auditoria com ela
planta36() { docker exec -i "$FTP" sh -s; }                                                    # roda no container do FTP o que vier pela entrada
soma36() { docker exec "$FTP" sha256sum "/data/$1" | cut -c1-64; }                             # <arquivo dentro de /data>: SHA-256 dele
tam36() { docker exec "$FTP" stat -c %s "/data/$1"; }                                          # <arquivo dentro de /data>: tamanho dele
ha36() { docker exec "$FTP" test -e "/data/$1" && echo sim || echo nao; }                      # <arquivo dentro de /data>: ainda está no servidor?
la36() { [[ -f "$1" ]] && sha256sum "$1" | cut -c1-64 || echo falta; }                         # <arquivo no servidor de teste>: SHA-256 do que chegou
conta36() { find "$@" -type f 2> /dev/null | wc -l; }                                          # <pasta...>: arquivos que o servidor de teste guarda
token36() { c -b "$1" "$B/meus-arquivos" | sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' | head -1; }  # <pote>: o token da sessão do usuário do FTP
vaza36() { grep -c -a -F -f "$D36/lista" "$1" 2>/dev/null || true; }                           # <arquivo>: linhas com a senha, a frase, uma chave ou um token desta etapa
situ36() { docker exec "$PAINEL" python3 /opt/painel/servidor.py --destinos 2>&1 | grep -m1 "^$1: " || true; }  # <destino>: a linha dele no terminal
doterminal36() { grep -m1 "^$1: " "$W/passada" || true; }                                      # <destino>: a linha dele na última passada pedida
segredo36() { echo "$S/destinos/$1-remoto.txt"; }                                              # <destino>: o arquivo do remoto dele, no host
rotulo36() { local par r=""; for par in "$@"; do [[ "$par" == *@* ]] || r+="$par "; done; echo "${r% }"; }  # os campos, sem os que vêm de arquivo
igual36() { [[ "$1" == "$2" ]] || F36=1; }                                                     # <obtido> <esperado>: marca o caso em andamento quando diferem
passou36() { # <destino>: até 150 s pela primeira passada dele, a que a rotina faz sozinha
  local marca=$SECONDS
  while (( SECONDS - marca < 150 )) && [[ "$(situ36 "$1")" != *'última passada: '* ]]; do sleep 3; done
  [[ "$(situ36 "$1")" == *'última passada: '* ]]
}
passa36() { # <destino>: passada pelo terminal, sem a espera dos dois minutos; saída em $W/passada
  local _ codigo=1
  for _ in $(seq 1 30); do
    docker exec "$PAINEL" python3 /opt/painel/servidor.py --destinos enviar "$1" --sem-espera > "$W/passada" 2>&1; codigo=$?
    grep -q -F 'outra passada está em andamento' "$W/passada" || return "$codigo"
    sleep 2
  done
  return "$codigo"
}
testa36() { envio /destinos/testar --max-time 40 --data-urlencode "csrf=$K" --data-urlencode "destino=$1"; }  # <destino>: o botão Testar
arq36() { # <token> <destino> <arquivo dentro de /data>: o botão de envio da linha do arquivo; a sessão é $POTE, ou a do administrador
  POTE="${POTE:-$J}" envio /destinos/arquivo --max-time 60 --data-urlencode "csrf=$1" --data-urlencode "destino=$2" --data-urlencode "arquivo=$3"
}
remove36() { envio /destinos/remover --data-urlencode "csrf=$K" --data-urlencode "destino=$1" --data-urlencode "senha_atual@$W/painel.senha"; }  # <destino>
grava36() { # <pote> <token> <arquivo da senha ou ""> [campo=valor | campo@arquivo | -campo]... → "código destino"; id=novo cria outro, id=<destino> altera, copiar=<destino> traz o acesso dele
  local pote="$1" token="$2" senha="$3" par nome; shift 3
  local -A campo=([pasta]=dst36 [intervalo]=1440 [ligado]=sim) arquivo=()
  for par in "$@"; do
    if [[ "$par" == -* ]]; then unset "campo[${par#-}]" "arquivo[${par#-}]"
    elif [[ "$par" =~ ^([a-z_]+)@(.+)$ ]]; then arquivo[${BASH_REMATCH[1]}]="${BASH_REMATCH[2]}"; unset "campo[${BASH_REMATCH[1]}]"   # segredo lido do arquivo
    else campo[${par%%=*}]="${par#*=}"; unset "arquivo[${par%%=*}]"; fi
  done
  local -a dados=(--data-urlencode "csrf=$token")
  for nome in "${!campo[@]}"; do dados+=(--data-urlencode "$nome=${campo[$nome]}"); done
  for nome in "${!arquivo[@]}"; do dados+=(--data-urlencode "$nome@${arquivo[$nome]}"); done
  [[ -n "$senha" ]] && dados+=(--data-urlencode "senha_atual@$senha")
  c -o "$W/corpo" -w '%{http_code} %{redirect_url}' -b "$pote" -H "Origin: ${ORIGEM36:-$B}" "${dados[@]}" "$B/destinos/rclone" | sed "s|$B||"
}
recusa36() { # <frase> [campo...]: formulário fora da regra ➜ 400 com a frase na tela; acumula em ok_inv e ev_inv
  local frase="$1" r; shift
  r="$(grava36 "$J" "$K" "$W/painel.senha" "$@")"
  [[ "$r" == "400 " && "$(tem36 "$frase")" -ge 1 ]] || ok_inv=1
  ev_inv+="$(rotulo36 "$@"): $r'$frase' $(tem36 "$frase"); "
}
prova36() { # <destino> <motivo esperado> <o que é> [campo...]: regrava o destino desligado com os campos e pede o teste; acumula em ok_prova e ev_prova
  local id="$1" esperado="$2" nome="$3" g r; shift 3
  g="$(grava36 "$J" "$K" "$W/painel.senha" "id=$id" -ligado "$@")"; r="$(testa36 "$id")"
  [[ "$g" == "$GRAVADO36" && "$r" == "303 /destinos?m=falha&d=$id&f=$esperado" ]] || ok_prova=1
  ev_prova+="$nome: gravação $g, teste $r; "
}
chegou36() { # <pasta do remoto no servidor de teste> <arquivo...>: quantos estão lá com a soma que têm no servidor da stack
  local base="$1" n=0 arq; shift
  for arq in "$@"; do [[ "$(la36 "$base/dst36/$arq")" == "$(soma36 "dst36/$arq")" ]] && n=$((n + 1)); done
  echo "$n"
}
digitais36() { # <pasta da chave>: a impressão digital SHA-256 de cada chave pública daquele servidor SFTP
  local pub
  for pub in "$D36/$1"/serve-sftp/*.pub; do awk '{print $2}' "$pub" | base64 -d | openssl dgst -sha256 -binary | base64 | tr -d '='; echo; done | grep .
}
nocartao36() { grep -o 'SHA256:[A-Za-z0-9+/]\{43\}' "$W/corpo" | cut -d: -f2 | sort -u | grep -c -x -F -f <(digitais36 "$1") || true; }  # <pasta da chave>: impressões da tela que são daquele servidor
guardar36() { # <destino>: põe na lista do que não pode vazar a senha e a frase como o rclone as cifra no arquivo do remoto
  local valor
  while IFS= read -r valor; do proibir "$valor"; printf '%s\n' "$valor" >> "$D36/lista"; done \
    < <(sed -n -E 's/^(pass|key_file_pass) = //p' "$(segredo36 "$1")" 2> /dev/null)
}
sobe36() { # <pasta da chave do SFTP por senha>: (re)cria o servidor de teste → "sim" quando as três portas respondem
  local cache="$1" porta pronto=nao _
  docker rm -f "$REM36" > /dev/null 2>&1
  docker run -d --name "$REM36" --no-healthcheck --network "$NOME-network" --network-alias sftp.remoto36.test \
    --network-alias dav.remoto36.test --network-alias outro.remoto36.test \
    --read-only --cap-drop ALL --security-opt no-new-privileges --user "$(id -u):$(id -g)" --tmpfs /tmp:size=16m,mode=1777 \
    -v "$D36/rem:/rem:ro" -v "$D36/srv:/srv" -v "$D36/srv-b:/srv-b" -v "$D36/$cache:/cache" -v "$D36/cache-b:/cache-b" \
    -v "$D36/saida:/saida" -v "$root_dir/tests/apoio/servidor_rclone.sh:/servidor.sh:ro" \
    --entrypoint sh "$IMG_PAINEL" /servidor.sh > /dev/null 2>> "$W/rem36.log" || { echo nao; return 1; }
  for _ in $(seq 1 40); do
    pronto=sim
    for porta in 8443 2022 2023; do
      docker exec "$REM36" python3 -c 'import socket, sys; socket.create_connection(("127.0.0.1", int(sys.argv[1])), 2)' "$porta" 2> /dev/null || pronto=nao
    done
    [[ "$pronto" == sim ]] && break
    sleep 1
  done
  echo "$pronto"
}

# ------------------------------------------------------------------ o servidor de teste e os segredos da etapa
# Autoridade e certificado só desta etapa, a senha e a frase, um par de chaves sem cifra e outro cifrado, e os tokens
# de exemplo das nuvens. A frase da chave cifrada vai ao ssh-keygen por um programa de pergunta, nunca pela linha de comando.
rm -rf "$D36"; ( umask 077; mkdir -p "$D36/rem" "$D36/cache" "$D36/cache-x" "$D36/cache-b" "$D36/saida" ); mkdir -p "$D36/srv" "$D36/srv-b"
(
  umask 077; cd "$D36" || exit 1
  printf '[req]\ndistinguished_name=dn\nx509_extensions=ca\nprompt=no\n[dn]\nCN=Autoridade de teste da bateria\n[ca]\nbasicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign\nsubjectKeyIdentifier=hash\n' > ca.cnf
  printf 'basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=serverAuth\nsubjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid\nsubjectAltName=DNS:dav.remoto36.test\n' > servidor.ext
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -days 2 -config ca.cnf -keyout ca.key -out ca.pem \
    && openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -nodes -subj '/CN=dav.remoto36.test' -keyout rem/servidor.key -out servidor.csr \
    && openssl x509 -req -in servidor.csr -CA ca.pem -CAkey ca.key -CAcreateserial -days 2 -extfile servidor.ext -out rem/servidor.pem || exit 1
  for n in rem/senha.txt errada.txt frase.txt acesso.txt renovacao.txt; do openssl rand -hex 20 | tr -d '\n' > "$n"; done
  printf '#!/bin/sh\ncat "%s/frase.txt"\n' "$D36" > pergunta.sh; chmod 700 pergunta.sh
  ssh-keygen -q -t ed25519 -N '' -C '' -f chave || exit 1
  SSH_ASKPASS="$D36/pergunta.sh" SSH_ASKPASS_REQUIRE=force setsid -w ssh-keygen -q -t ed25519 -C '' -f chave-frase < /dev/null || exit 1
  cat chave.pub chave-frase.pub > rem/autorizadas
  printf '{"access_token":"%s","token_type":"Bearer","refresh_token":"%s","expiry":"2030-01-01T00:00:00Z"}' "$(cat acesso.txt)" "$(cat renovacao.txt)" > token.json
  for n in 10 34 60; do head -c "${n}000" /dev/zero | tr '\0' A > "grande-$n"; done
) > "$W/cert36.log" 2>&1; r_cert=$?
: > "$D36/lista"
for n in rem/senha.txt errada.txt frase.txt acesso.txt renovacao.txt; do proibir "$(cat "$D36/$n")"; { cat "$D36/$n"; echo; } >> "$D36/lista"; done
for n in ca.key rem/servidor.key chave chave-frase; do proibir "$(sed -n 2p "$D36/$n")"; done
for n in chave chave-frase; do sed -n 2p "$D36/$n" >> "$D36/lista"; done
r_rem="$(sobe36 cache)"
for n in "$D36"/cache*/serve-sftp/id_*; do [[ "$n" == *.pub || ! -f "$n" ]] || proibir "$(sed -n 2p "$n")"; done
versao36="$(docker exec "$PAINEL" rclone version 2> /dev/null | head -1)"; quer36="rclone v$(sed -n 's/^ARG RCLONE=//p' "$root_dir/Dockerfile")"
# Os acessos: SFTP por senha, WebDAV, SFTP por chave e SFTP por chave cifrada com a frase.
SF36=(remoto=sftp r_host=sftp.remoto36.test r_port=2022 r_user=teste "r_pass@$D36/rem/senha.txt")
DV36=(remoto=webdav r_url=https://dav.remoto36.test:8443 r_vendor=rclone r_user=teste "r_pass@$D36/rem/senha.txt")
CH36=(remoto=sftp r_host=sftp.remoto36.test r_port=2023 r_user=teste "r_key_pem@$D36/chave")
CF36=(remoto=sftp r_host=sftp.remoto36.test r_port=2023 r_user=teste "r_key_pem@$D36/chave-frase" "r_key_file_pass@$D36/frase.txt")

# A pasta de um usuário (dst36), com o que a passada envia (cinco arquivos, um deles vazio e um com espaço e acento no
# nome) e o que ela não toca: nome começado por ponto, link simbólico e FIFO. No servidor de teste, um arquivo que já
# estava lá antes de qualquer envio: tem de continuar igual até o fim.
nova_senha "$W/dst36.senha"; mu add dst36 "$W/dst36.senha" dst36; r_usu=$?
planta36 <<'SH'
set -e
mkdir -p /data/dst36/sub /data/dst36/.pasta
cd /data/dst36
echo um > a1.txt; head -c 70000 /dev/urandom > a2.bin; echo tres > sub/a3.txt; : > vazio.txt; echo quatro > 'relatório final.txt'
echo oculto > .oculto; echo x > .pasta/x.txt; ln -s a1.txt atalho; mkfifo cano
chown -hR ftpdata:ftpdata .
SH
r_pla=$?; plantio36=$SECONDS
b_A=0; for n in "${A36[@]}"; do b_A=$(( b_A + $(tam36 "dst36/$n") )); done
mkdir -p "$D36/srv/painel36/sftp"; echo 'já estava no servidor de teste' > "$D36/srv/painel36/sftp/sentinela.txt"
s_sen0="$(la36 "$D36/srv/painel36/sftp/sentinela.txt")"; s_a1="$(soma36 dst36/a1.txt)"

# ------------------------------------------------------------------ só o administrador, com token e senha
auditoria; n_sen="$(eventos admin_senha_atual_recusada)"
t_ini="$(aba -b "$J" "$B/destinos")"; f_ini="$(tem36 'Remoto do rclone')"
t_tipo="$(aba -b "$J" "$B/destinos/rclone?id=novo")"; f_tipo="$(tem36 'O tipo fica fixo depois de gravado')"
t_form="$(aba -b "$J" "$B/destinos/rclone?id=novo&remoto=sftp")"; f_form="$(vezes36 'name="r_') $(vezes36 'name="remoto" value="sftp"')"
x_semtoken="$(grava36 "$J" '' "$W/painel.senha" "${SF36[@]}")"
x_token="$(grava36 "$J" token-errado "$W/painel.senha" "${SF36[@]}")"
x_origem="$(ORIGEM36=https://fora.example grava36 "$J" "$K" "$W/painel.senha" "${SF36[@]}")"
: > "$W/vazio36.jar"; x_semsessao="$(grava36 "$W/vazio36.jar" "$K" "$W/painel.senha" "${SF36[@]}")"
# Senha errada, com o formulário certo: conta como erro de senha do endereço, por isso é uma só.
x_errada="$(grava36 "$J" "$K" "$W/errada.senha" "${SF36[@]}")"; x_errada_f="$(tem36 'A sua senha atual não confere. Nada foi alterado.')"
e_adm2="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
# Formulário fora da regra: recusado antes de a senha ser conferida, com o motivo na tela. Tipo e campo fora da lista,
# endereço sem HTTPS, e o que o leitor de configuração do rclone trataria: aspas, crase e %(nome)s.
ok_inv=0; ev_inv=""
recusa36 'Escolha o tipo do remoto.' remoto=ftp r_host=sftp.remoto36.test r_user=teste "r_pass@$D36/rem/senha.txt"
recusa36 'Escolha o tipo do remoto.' remoto=local r_host=sftp.remoto36.test
recusa36 'Pasta no remoto inválida:' "${SF36[@]}" caminho=../x
recusa36 'Pasta no remoto inválida:' "${SF36[@]}" 'caminho=a:b'
recusa36 'A pasta não existe dentro dos dados.' "${SF36[@]}" pasta=nao-existe36
recusa36 'Intervalo inválido:' "${SF36[@]}" intervalo=4
recusa36 'Endereço: em branco ou fora do formato.' "${DV36[@]}" r_url=http://dav.remoto36.test:8443
recusa36 'Programa do servidor: em branco ou fora do formato.' "${DV36[@]}" r_vendor=outro
recusa36 'Servidor: em branco ou fora do formato.' "${SF36[@]}" 'r_host=a"b'
recusa36 'Usuário: em branco ou fora do formato.' "${SF36[@]}" 'r_user=te`id`'
recusa36 'Usuário: em branco ou fora do formato.' "${SF36[@]}" 'r_user=%(host)s'
recusa36 'Porta: em branco ou fora do formato.' "${SF36[@]}" r_port=70000
recusa36 'Chave pública do servidor: em branco ou fora do formato.' "${SF36[@]}" 'r_host_keys=ssh-ed25519 curta'
recusa36 'Chave privada: em branco ou fora do formato.' "${SF36[@]}" -r_pass r_key_pem=nao-e-chave
recusa36 'A frase vale só para chave privada cifrada' "${CF36[@]}" -r_key_file_pass
recusa36 'A frase vale só para chave privada cifrada' "${CH36[@]}" "r_key_file_pass@$D36/frase.txt"
recusa36 'Acesso incompleto:' "${SF36[@]}" -r_pass
recusa36 'Senha: em branco ou fora do formato.' remoto=webdav r_url=https://dav.remoto36.test:8443 r_user=teste
recusa36 'Acesso incompleto:' remoto=drive r_scope=drive
recusa36 'Token de acesso: em branco ou fora do formato.' remoto=webdav r_url=https://dav.remoto36.test:8443 'r_bearer_token=%(url)s'
recusa36 'Token da conta: em branco ou fora do formato.' remoto=dropbox 'r_token={"x":1}'
recusa36 'Preencha o acesso do remoto' remoto=sftp
# A última barreira, direto na função que confere o que vai para o arquivo: aspas ou crase no começo, %(, barra no fim e letra fora do ASCII.
x_valor="$(docker exec -w /opt/painel "$PAINEL" python3 -B -c '
import re, sys, rclone
qualquer, recusados = re.compile(r".+"), 0
for valor in sys.argv[1:]:
    try:
        rclone.guardado("texto", qualquer, valor)
    except ValueError:
        recusados += 1
print(recusados, "de", len(sys.argv) - 1, "recusados;", "comum aceito:", rclone.guardado("texto", qualquer, "servidor.exemplo"))' '"a' '`a' 'a%(b)s' 'a\' 'á' 2>&1)"
x_nada="$(situ36 rclone)|$(ls "$S/destinos"/rclone* 2> /dev/null | wc -l)"
# O limite do corpo. Só a rota do remoto do rclone aceita formulário longo (até 32 KiB no painel, 40k no nginx):
# 10 kB são lidos nela e recusados pelo conteúdo, e na rota do S3 nem são lidos; 34 kB param no painel e 60 kB, no nginx.
l_10="$(grava36 "$J" "$K" "$W/painel.senha" "${SF36[@]}" "r_key_pem@$D36/grande-10")"; l_10f="$(tem36 'Chave privada: em branco ou fora do formato.')"
l_s3="$(c -o "$W/corpo" -w '%{http_code}' -b "$J" -H "Origin: $B" --data-urlencode "csrf=$K" --data-urlencode "chave_secreta@$D36/grande-10" "$B/destinos/s3")"; l_s3f="$(tem36 'Envio grande demais.')"
l_34="$(grava36 "$J" "$K" "$W/painel.senha" "${SF36[@]}" "r_key_pem@$D36/grande-34")"; l_34f="$(tem36 'Envio grande demais.')"
l_60="$(grava36 "$J" "$K" "$W/painel.senha" "${SF36[@]}" "r_key_pem@$D36/grande-60")"; l_60f="$(tem36 'Envio grande demais.')"
# Campos demais: o formulário do remoto leva até 24.
l_25="$(grava36 "$J" "$K" "$W/painel.senha" "${SF36[@]}" e01=1 e02=1 e03=1 e04=1 e05=1 e06=1 e07=1 e08=1 e09=1 e10=1 e11=1 e12=1 e13=1 e14=1 e15=1)"; l_25f="$(tem36 'Envio malformado.')"
l_nada="$(situ36 rclone)"
F36=0
igual36 "$l_10 $l_10f" '400  1'; igual36 "$l_s3 $l_s3f" '413 1'; igual36 "$l_34 $l_34f" '413  1'; igual36 "$l_60 $l_60f" '413  0'
igual36 "$l_25 $l_25f" '400  1'; igual36 "$l_nada" 'rclone: não configurado'
caso "$F36" seguranca 139 "Remoto do rclone: o formulário longo vale só na rota dele e tem teto no painel e no nginx" \
  "10 kB em /destinos/rclone: $l_10(lido e recusado pelo conteúdo: $l_10f); os mesmos 10 kB em /destinos/s3: $l_s3 do painel (Envio grande demais: $l_s3f); 34 kB em /destinos/rclone: $l_34 do painel (Envio grande demais: $l_34f); 60 kB: $l_60 do nginx (texto do painel: $l_60f); 25 campos: $l_25(Envio malformado: $l_25f); nada gravado: $l_nada"

# ------------------------------------------------------------------ SFTP por senha: sem a chave do servidor nada sai
# Entram no formulário três campos que o rclone conhece e o painel não aceita: ficam de fora do arquivo gravado.
g_sf="$(grava36 "$J" "$K" "$W/painel.senha" "${SF36[@]}" caminho=painel36/sftp nome=Arquivo 'r_ssh=touch /tmp/marca36' r_key_file=/etc/passwd r_shell_type=unix)"
guardar36 rclone
x_fora="$(grep -c -E '^(ssh|key_file) = |^shell_type = unix' "$(segredo36 rclone)" || true) $(grep -c -x -F 'shell_type = none' "$(segredo36 rclone)" || true) $(grep -c -x -F 'type = sftp' "$(segredo36 rclone)" || true)"
t_sf="$(aba -b "$J" "$B/destinos")"; f_falta="$(vezes36 '<span class="etiqueta atencao">falta testar</span>') $(tem36 'O painel ainda não guardou a chave deste servidor.')"
passa36 rclone; r_sem=$?; p_sem="$(doterminal36 rclone)"
m_sem="$(arq36 "$K" rclone dst36/a1.txt)"
n_sem="$(conta36 "$D36/srv/painel36")"
# O Testar guarda a chave que o servidor apresentou, e a ficha passa a mostrar a impressão digital dela.
m_tes="$(testa36 rclone)"
t_tes="$(aba -b "$J" "$B/destinos")"; f_tes="$(vezes36 'falta testar') $(tem36 'Chave do servidor') $(nocartao36 cache)"
n_tes="$(find "$D36/srv/painel36/sftp" -name allsafe-ftp-stack-teste.txt -type f | wc -l)"
passa36 rclone; r_p1=$?; p_p1="$(doterminal36 rclone)"
c_sf="$(chegou36 "$D36/srv/painel36/sftp" "${A36[@]}")"; n_sf="$(conta36 "$D36/srv/painel36/sftp/dst36")"
o_sf="$(find "$D36/srv/painel36" \( -name '.oculto' -o -name 'x.txt' -o -name atalho -o -name cano \) | wc -l)"
passa36 rclone; r_p2=$?; p_p2="$(doterminal36 rclone)"
auditoria
a_sf="$(linhas36 " evento=destino_gravado admin=$ADMIN destino=rclone situacao=ligado pasta=dst36 intervalo=1440 remoto=sftp segredos=trocados\$")"
a_te="$(linhas36 " evento=destino_teste admin=$ADMIN destino=rclone resultado=ok\$")"
a_en="$(linhas36 " evento=destino_enviado destino=rclone arquivos=5 bytes=$b_A apagados=0 grandes=0 ignorados=0 erros=0\$")"
a_sc="$(linhas36 ' evento=destino_falhou destino=rclone motivo=sem_chave$')"
a_ar="$(linhas36 " evento=destino_arquivo admin=$ADMIN destino=rclone arquivo=dst36/a1.txt bytes=[0-9]+ resultado=sem_chave\$")"

# O usuário do FTP, com a sessão e o token dele: nenhuma rota do rclone existe para ele, e a tela dele não tem o botão
# que a do administrador já mostra.
b_adm="$(aba -b "$J" "$B/arquivos?pasta=dst36")$(vezes36 'id="para-rclone"')"
e_usu="$(COMO=dst36 entrar "$W/dst36.jar" "$W/dst36.senha")"; proibir "$(biscoito_de "$W/dst36.jar")"; K_u="$(token36 "$W/dst36.jar")"; proibir "$K_u"
u_rotas=""
for n in /destinos/rclone '/destinos/rclone?id=rclone' '/destinos/rclone?id=novo&remoto=sftp' '/destinos/arquivo?tipo=rclone&arquivo=dst36/a1.txt'; do
  u_rotas+="$(aba -b "$W/dst36.jar" "$B$n" | cut -c1-3) "
done
u_rotas+="$(grava36 "$W/dst36.jar" "$K_u" "$W/dst36.senha" id=rclone "${SF36[@]}" caminho=painel36/outro | cut -c1-3) "
u_rotas+="$(POTE="$W/dst36.jar" arq36 "$K_u" rclone dst36/a1.txt | cut -c1-3) "
for n in testar agora remover; do
  u_rotas+="$(POTE="$W/dst36.jar" envio "/destinos/$n" --data-urlencode "csrf=$K_u" --data-urlencode "destino=rclone" | cut -c1-3) "
done
u_meus="$(aba -b "$W/dst36.jar" "$B/meus-arquivos")"; u_tela="$(tem36 'a1.txt') $(vezes36 'para-') $(vezes36 '/destinos')"
u_dps="$(situ36 rclone)"; auditoria; d_sen=$(( $(eventos admin_senha_atual_recusada) - n_sen ))
F36="$ok_inv"
igual36 "$e_adm $e_adm2 $e_usu" '303 303 303'; igual36 "$t_ini$f_ini" '200 1'; igual36 "$t_tipo$f_tipo" '200 1'; [[ "$t_form" == '200 ' && "$f_form" == '7 1' ]] || F36=1
igual36 "$x_semtoken|$x_token|$x_origem|$x_semsessao|$x_errada$x_errada_f" '403 |403 |403 |303 /entrar|403 1'; igual36 "$d_sen" 1
igual36 "$x_valor" '5 de 5 recusados; comum aceito: servidor.exemplo'; igual36 "$x_nada" 'rclone: não configurado|0'
igual36 "$g_sf" "$GRAVADO36"; igual36 "$x_fora" '0 1 1'
igual36 "$b_adm" '200 1'; igual36 "$u_rotas" '404 404 404 404 404 404 404 404 404 '; igual36 "$u_meus$u_tela" '200 1 0 0'
[[ "$u_dps" == 'rclone: ligado; pasta /data/dst36; a cada 1440 min; última passada: 0 arquivo(s), 0 bytes'* && "$u_dps" == *'; nome: Arquivo' ]] || F36=1
caso "$F36" seguranca 134 "Remoto do rclone: só o administrador grava, com token e senha, e só o que o painel conhece vai para o arquivo" \
  "tela dos destinos $t_ini(cartão do rclone: $f_ini); escolha do tipo $t_tipo(aviso do tipo fixo: $f_tipo); formulário do SFTP $t_form(campos do acesso e tipo: $f_form); sem token: $x_semtoken; token errado: $x_token; Origin de fora: $x_origem; sem sessão: $x_semsessao; senha errada: $x_errada(aviso $x_errada_f, $d_sen recusa de senha na auditoria); recusados com 400 e o motivo na tela: $ev_inv; valores direto na conferência do arquivo (aspas, crase, %(, barra no fim e letra fora do ASCII): $x_valor; depois das recusas: $x_nada arquivo(s) de segredo; gravação certa: $g_sf, com os campos ssh, key_file e shell_type do formulário fora do arquivo (linhas deles, shell_type = none, type = sftp): $x_fora; administrador vê o formulário do botão do rclone: $b_adm; usuário do FTP nas nove rotas (quatro de leitura e cinco de envio): $u_rotas; tela dele $u_meus(arquivo, botões de destino, ligações para os destinos: $u_tela); o destino depois das tentativas dele: $u_dps"

# ------------------------------------------------------------------ WebDAV: a rotina faz sozinha a primeira passada
# Sem a autoridade no painel, o certificado do servidor de teste não é aceito: nada chega. Com ela, o destino é
# gravado ligado quando os arquivos já têm mais de dois minutos, e a etapa só espera.
g_dv0="$(grava36 "$J" "$K" "$W/painel.senha" id=novo -ligado "${DV36[@]}" caminho=painel36/dav)"; guardar36 rclone-2
m_dv0="$(testa36 rclone-2)"; n_dv0="$(conta36 "$D36/srv/painel36/dav")"
docker exec -i "$PAINEL" sh -c 'cat > /painel/destinos/ca.pem' < "$D36/ca.pem"; r_ca=$?
m_dv="$(testa36 rclone-2)"
while (( SECONDS - plantio36 < 125 )); do sleep 3; done
g_dv="$(grava36 "$J" "$K" "$W/painel.senha" id=rclone-2 remoto=webdav caminho=painel36/dav)"
passou36 rclone-2; r_dv=$?; p_dv="$(situ36 rclone-2)"
c_dv="$(chegou36 "$D36/srv/painel36/dav" "${A36[@]}")"; n_dv="$(conta36 "$D36/srv/painel36/dav/dst36")"
auditoria
a_dv="$(linhas36 " evento=destino_gravado admin=$ADMIN destino=rclone-2 situacao=desligado pasta=dst36 intervalo=1440 remoto=webdav segredos=trocados\$") $(linhas36 " evento=destino_gravado admin=$ADMIN destino=rclone-2 situacao=ligado pasta=dst36 intervalo=1440 remoto=webdav segredos=mantidos\$")"
a_dve="$(linhas36 " evento=destino_enviado destino=rclone-2 arquivos=5 bytes=$b_A apagados=0 grandes=0 ignorados=0 erros=0\$")"
F36=0
igual36 "$r_cert $r_rem $r_usu $r_pla $r_ca" '0 sim 0 0 0'; igual36 "$versao36" "$quer36"
igual36 "$f_falta" '1 1'; igual36 "$m_tes" "$TESTADO36"; igual36 "$n_tes" 1
igual36 "$r_p1 $p_p1" "0 rclone: 5 arquivo(s), $b_A bytes, $SEM36; chegou ao fim"; igual36 "$c_sf $n_sf $o_sf" '5 5 0'
igual36 "$r_p2 $p_p2" "0 rclone: 0 arquivo(s), 0 bytes, $SEM36; chegou ao fim"
igual36 "$g_dv0|$m_dv|$g_dv" "$GRAVADO36|$TESTADO36|$GRAVADO36"; igual36 "$r_dv" 0
igual36 "$p_dv" "rclone-2: ligado; pasta /data/dst36; a cada 1440 min; última passada: 5 arquivo(s), $b_A bytes, $SEM36; chegou ao fim"
igual36 "$c_dv $n_dv" '5 5'; igual36 "$a_sf $a_te $a_en" '1 1 1'; igual36 "$a_dv $a_dve" '1 1 1'
caso "$F36" testes 91 "Remoto do rclone: os arquivos da pasta chegam ao SFTP e ao WebDAV de teste com a mesma soma" \
  "preparação (certificado, servidor de teste, usuário, plantio, autoridade no painel): $r_cert $r_rem $r_usu $r_pla $r_ca; imagem do painel: $versao36 (o Dockerfile pede $quer36); SFTP gravado: $g_sf, ficha com falta testar e o aviso da chave: $f_falta; Testar: $m_tes, arquivo de teste no servidor: $n_tes; passada pelo terminal: saída $r_p1, $p_p1; no servidor de teste, com a mesma soma: $c_sf de 5 (um vazio e um com espaço e acento), arquivos na pasta: $n_sf, oculto, link e FIFO: $o_sf; passada repetida: saída $r_p2, $p_p2; WebDAV gravado desligado: $g_dv0, Testar com a autoridade: $m_dv, ligado: $g_dv; passada da rotina, sem pedido (0 = aconteceu em até 150 s): $r_dv, $p_dv; com a mesma soma: $c_dv de 5, arquivos na pasta: $n_dv; auditoria (gravação, teste e envio do SFTP; as duas gravações e o envio do WebDAV): $a_sf $a_te $a_en · $a_dv $a_dve"

# ------------------------------------------------------------------ chave privada, chave cifrada e acesso copiado
# Cada um segue o caminho do primeiro: gravado ligado, a passada para em sem_chave, o Testar guarda a chave e a
# passada seguinte envia. O servidor da porta 2023 tem outra chave, e grava em outra pasta.
g_ch="$(grava36 "$J" "$K" "$W/painel.senha" id=novo "${CH36[@]}" caminho=painel36/chave)"
passa36 rclone-3; r_ch0=$?; p_ch0="$(doterminal36 rclone-3)"; m_ch="$(testa36 rclone-3)"; passa36 rclone-3; r_ch=$?; p_ch="$(doterminal36 rclone-3)"
c_ch="$(chegou36 "$D36/srv-b/painel36/chave" "${A36[@]}")"
g_cf="$(grava36 "$J" "$K" "$W/painel.senha" id=novo "${CF36[@]}" caminho=painel36/frase)"; guardar36 rclone-4
passa36 rclone-4; r_cf0=$?; p_cf0="$(doterminal36 rclone-4)"; m_cf="$(testa36 rclone-4)"; passa36 rclone-4; r_cf=$?; p_cf="$(doterminal36 rclone-4)"
c_cf="$(chegou36 "$D36/srv-b/painel36/frase" "${A36[@]}")"
t_ch="$(aba -b "$J" "$B/destinos")"; f_ch="$(nocartao36 cache) $(nocartao36 cache-b) $(vezes36 'falta testar')"
# Destino novo com o acesso do primeiro: o acesso é copiado no servidor, com a chave já guardada, e não pede teste.
t_cp="$(aba -b "$J" "$B/destinos/rclone?id=novo&copiar=rclone")"; f_cp="$(tem36 'Deixe os campos do acesso em branco para usar o do destino de origem') $(vezes36 'sftp.remoto36.test')"
g_cp="$(grava36 "$J" "$K" "$W/painel.senha" id=novo copiar=rclone -ligado remoto=sftp caminho=painel36/copia)"
t_cp2="$(aba -b "$J" "$B/destinos")"; f_cp2="$(vezes36 'falta testar')"
igual_cp="$(cmp -s "$(segredo36 rclone)" "$(segredo36 rclone-5)" && echo igual || echo diferente)"
g_cp2="$(grava36 "$J" "$K" "$W/painel.senha" id=rclone-5 remoto=sftp caminho=painel36/copia)"
passou36 rclone-5; r_cp=$?; p_cp="$(situ36 rclone-5)"; c_cp="$(chegou36 "$D36/srv/painel36/copia" "${A36[@]}")"
# O mesmo lugar com a mesma pasta já existe; e o tipo gravado não muda pelo formulário.
g_rep="$(grava36 "$J" "$K" "$W/painel.senha" id=novo "${SF36[@]}" caminho=painel36/sftp)"; f_rep="$(tem36 'Este destino já existe:')"
g_fix="$(grava36 "$J" "$K" "$W/painel.senha" id=rclone remoto=webdav caminho=painel36/sftp nome=Arquivo)"; f_fix="$(grep -c -x -F 'type = sftp' "$(segredo36 rclone)" || true)"
passa36 rclone; r_fix=$?; p_fix="$(doterminal36 rclone)"
auditoria
a_ch="$(linhas36 " evento=destino_gravado admin=$ADMIN destino=rclone-3 situacao=ligado pasta=dst36 intervalo=1440 remoto=sftp segredos=trocados\$") $(linhas36 " evento=destino_gravado admin=$ADMIN destino=rclone-4 situacao=ligado pasta=dst36 intervalo=1440 remoto=sftp segredos=trocados\$")"
a_cp="$(linhas36 " evento=destino_gravado admin=$ADMIN destino=rclone-5 situacao=desligado pasta=dst36 intervalo=1440 remoto=sftp segredos=copiados origem=rclone\$") $(linhas36 " evento=destino_gravado admin=$ADMIN destino=rclone-5 situacao=ligado pasta=dst36 intervalo=1440 remoto=sftp segredos=mantidos\$")"
a_fix="$(linhas36 " evento=destino_gravado admin=$ADMIN destino=rclone situacao=ligado pasta=dst36 intervalo=1440 remoto=sftp segredos=mantidos\$")"
F36=0
igual36 "$g_ch|$g_cf|$g_cp|$g_cp2" "$GRAVADO36|$GRAVADO36|$GRAVADO36|$GRAVADO36"
igual36 "$r_ch0 $p_ch0" "1 rclone-3: 0 arquivo(s), 0 bytes, $SEM36; parou: sem_chave"; igual36 "$r_cf0 $p_cf0" "1 rclone-4: 0 arquivo(s), 0 bytes, $SEM36; parou: sem_chave"
igual36 "$m_ch|$m_cf" "$TESTADO36|$TESTADO36"
igual36 "$r_ch $p_ch" "0 rclone-3: 5 arquivo(s), $b_A bytes, $SEM36; chegou ao fim"; igual36 "$r_cf $p_cf" "0 rclone-4: 5 arquivo(s), $b_A bytes, $SEM36; chegou ao fim"
igual36 "$c_ch $c_cf" '5 5'; [[ "$t_ch" == '200 ' && "${f_ch%% *}" -ge 1 && "$(cut -d' ' -f2 <<< "$f_ch")" -ge 1 && "${f_ch##* }" == 0 ]] || F36=1
igual36 "$t_cp$f_cp" '200 1 0'; igual36 "$t_cp2$f_cp2 $igual_cp" '200 0 igual'; igual36 "$r_cp" 0
igual36 "$p_cp" "rclone-5: ligado; pasta /data/dst36; a cada 1440 min; última passada: 5 arquivo(s), $b_A bytes, $SEM36; chegou ao fim"; igual36 "$c_cp" 5
igual36 "$g_rep$f_rep" '400 1'; igual36 "$g_fix $f_fix" "$GRAVADO36 1"; igual36 "$r_fix $p_fix" "0 rclone: 0 arquivo(s), 0 bytes, $SEM36; chegou ao fim"
igual36 "$a_ch $a_cp $a_fix" '1 1 1 1 1'
caso "$F36" testes 92 "Remoto do rclone: chave privada, chave cifrada com frase, acesso copiado de outro destino e alteração que mantém o acesso" \
  "SFTP por chave: $g_ch, antes do Testar: saída $r_ch0, $p_ch0; Testar: $m_ch; depois: saída $r_ch, $p_ch; com a mesma soma: $c_ch de 5; chave cifrada com a frase: $g_cf, antes: saída $r_cf0, $p_cf0; Testar: $m_cf; depois: saída $r_cf, $p_cf; com a mesma soma: $c_cf de 5; fichas $t_ch(impressões digitais do servidor da porta 2022, do da porta 2023 e fichas com falta testar: $f_ch); tela de destino novo com o acesso do primeiro $t_cp(aviso dos campos em branco e vezes em que o servidor aparece: $f_cp); gravado desligado: $g_cp, sem falta testar ($f_cp2), arquivo do remoto $igual_cp ao de origem; ligado sem preencher o acesso: $g_cp2, passada da rotina (0 = aconteceu): $r_cp, $p_cp, com a mesma soma: $c_cp de 5; mesmo lugar com a mesma pasta: $g_rep(Este destino já existe: $f_rep); alteração pedindo outro tipo: $g_fix, o arquivo continua type = sftp: $f_fix, e o andamento também: saída $r_fix, $p_fix; auditoria (chave, chave cifrada, cópia desligada com a origem, cópia ligada com o acesso mantido, alteração do primeiro): $a_ch $a_cp $a_fix"

# ------------------------------------------------------------------ botão por arquivo, arquivo novo e remoção
planta36 <<'SH'
cd /data/dst36 && echo manual > manual.txt && chown ftpdata:ftpdata manual.txt
SH
t_bot="$(aba -b "$J" "$B/arquivos?pasta=dst36")"; f_bot="$(vezes36 '<form id="para-rclone" method="get" action="/destinos/arquivo"') $(vezes36 'form="para-rclone"')"
t_esc="$(aba -b "$J" "$B/destinos/arquivo?tipo=rclone&arquivo=dst36/manual.txt")"; f_esc="$(tem36 'Destino que recebe') $(vezes36 'name="destino" value="rclone')"
n_antes="$(find "$D36/srv" "$D36/srv-b" -name manual.txt -type f | wc -l)"
m_man="$(arq36 "$K" rclone-2 dst36/manual.txt)"
t_man="$(aba -b "$J" "$B/arquivos?pasta=dst36&m=destino_ok&d=rclone-2")"; f_man="$(tem36 'Remoto do rclone 2: arquivo enviado.')"
n_man="$(find "$D36/srv" "$D36/srv-b" -name manual.txt -type f | wc -l)"; c_man="$(chegou36 "$D36/srv/painel36/dav" manual.txt)"
m_inv="$(arq36 "$K" rclone-2 dst36/nao-existe.txt | cut -c1-3) $(arq36 "$K" rclone-2 ../auth/pureftpd.passwd | cut -c1-3) $(arq36 "$K" rclone-9 dst36/a1.txt | cut -c1-3)"
# O arquivo novo sai na passada seguinte de quem ainda não o tem, e só ele.
passa36 rclone; r_nov=$?; p_nov="$(doterminal36 rclone)"; c_nov="$(chegou36 "$D36/srv/painel36/sftp" manual.txt)"
# Remover pede a senha e apaga a configuração e o segredo do destino; o que ele já enviou continua no servidor de teste.
n_cp="$(conta36 "$D36/srv/painel36/copia")"
t_rem="$(aba -b "$J" "$B/destinos/remover?destino=rclone-5")"; f_rem="$(tem36 'Sim, remover o destino')"
m_rem0="$(envio /destinos/remover --data-urlencode "csrf=$K" --data-urlencode "destino=rclone-5")"; e_adm3="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"
h_rem0="$([[ -f "$(segredo36 rclone-5)" ]] && echo sim || echo nao)"
m_rem="$(remove36 rclone-5)"
h_rem="$([[ -e "$(segredo36 rclone-5)" ]] && echo sim || echo nao) $(docker exec "$PAINEL" sh -c 'ls /painel/destinos/ | grep -c "^rclone-5\."' || true) $(situ36 rclone-5 | wc -l)"
n_cp2="$(conta36 "$D36/srv/painel36/copia")"; h_dados="$(ha36 dst36/a1.txt) $(ha36 dst36/manual.txt)"
auditoria
a_man="$(linhas36 " evento=destino_arquivo admin=$ADMIN destino=rclone-2 arquivo=dst36/manual.txt bytes=7 resultado=ok\$")"
a_rem="$(linhas36 " evento=destino_removido admin=$ADMIN destino=rclone-5\$")"
F36=0
[[ "$t_bot" == '200 ' && "${f_bot%% *}" == 1 && "${f_bot##* }" -ge 5 ]] || F36=1; igual36 "$t_esc$f_esc" '200 1 5'
igual36 "$n_antes $m_man $n_man $c_man" '0 303 /arquivos?pasta=dst36&m=destino_ok&d=rclone-2 1 1'; igual36 "$t_man$f_man" '200 1'; igual36 "$m_inv" '404 400 303'
igual36 "$r_nov $p_nov $c_nov" "0 rclone: 1 arquivo(s), 7 bytes, $SEM36; chegou ao fim 1"
igual36 "$t_rem$f_rem" '200 1'; igual36 "${m_rem0%% *} $h_rem0 $e_adm3" '403 sim 303'; igual36 "$m_rem" '303 /destinos?m=removido'; igual36 "$h_rem" 'nao 0 0'
[[ "$n_cp" == "$n_cp2" && "$n_cp" -ge 5 ]] || F36=1; igual36 "$h_dados" 'sim sim'; igual36 "$a_man $a_rem" '1 1'
caso "$F36" testes 93 "Remoto do rclone: o botão da linha envia um arquivo só, o arquivo novo sai na passada seguinte e remover não toca no que já foi enviado" \
  "aba Arquivos $t_bot(formulário de escolha do rclone e botões: $f_bot); tela de escolha $t_esc(título e destinos prontos: $f_esc); manual.txt no servidor de teste antes: $n_antes; envio para o rclone-2: $m_man, aviso na tela: $f_man, cópias no servidor de teste: $n_man, com a mesma soma: $c_man; arquivo que não existe, caminho para fora dos dados e destino que não existe: $m_inv; passada do primeiro destino: saída $r_nov, $p_nov, manual.txt com a mesma soma: $c_nov; tela de remover $t_rem(botão de confirmação: $f_rem); remover sem a senha: $m_rem0, segredo ainda lá: $h_rem0; com a senha: $m_rem; segredo, arquivos da configuração e linha no terminal depois: $h_rem; arquivos que ele enviou, antes e depois: $n_cp e $n_cp2; a1.txt e manual.txt no servidor da stack: $h_dados; auditoria (envio do arquivo e remoção): $a_man $a_rem"

# ------------------------------------------------------------------ as quatro nuvens: o formulário grava o que o rclone aceita
# Gravadas desligadas, com token de exemplo, e nunca testadas pelo painel. O arquivo do remoto vai para um container
# sem rede, onde o rclone da imagem tenta gravar: configuração aceita é a que só falha ao procurar o nome do serviço.
nuvem36() { # <tipo> [campo...]: grava, confere com o rclone sem rede e remove; acumula em ok_nuv e ev_nuv
  local tipo="$1" g tela autoriza tipo_ok rede vazou r; shift
  tela="$(aba -b "$J" "$B/destinos/rclone?id=novo&remoto=$tipo")"; autoriza="$(tem36 "rclone authorize $tipo")"
  g="$(grava36 "$J" "$K" "$W/painel.senha" id=novo -ligado "remoto=$tipo" caminho=copias/teste "r_token@$D36/token.json" "$@")"
  tipo_ok="$(grep -c -x -F "type = $tipo" "$(segredo36 rclone-5)" 2> /dev/null || true)"
  docker run --rm --name "$NOME-export" --network none --read-only --cap-drop ALL --security-opt no-new-privileges \
    --user "$(id -u):$(id -g)" --tmpfs /tmp:size=16m,mode=1777 -e HOME=/tmp -v "$(segredo36 rclone-5):/remoto.conf:ro" \
    --entrypoint sh "$IMG_PAINEL" -c 'cp /remoto.conf /tmp/r.conf && echo x | rclone --config /tmp/r.conf --retries 1 --low-level-retries 1 --contimeout 5s --timeout 10s rcat --size 2 destino:copias/teste/x.txt' \
    > "$D36/nuvem-$tipo.log" 2>&1
  rede="$(grep -c -E 'lookup |dial tcp|no such host|network is unreachable' "$D36/nuvem-$tipo.log" || true)"
  vazou="$(vaza36 "$D36/nuvem-$tipo.log")"; r="$(remove36 rclone-5)"
  [[ "$tela" == '200 ' && "$autoriza" -ge 1 && "$g" == "$GRAVADO36" && "$tipo_ok" == 1 && "$rede" -ge 1 && "$vazou" == 0 && "$r" == '303 /destinos?m=removido' ]] || ok_nuv=1
  ev_nuv+="$tipo: formulário $tela(comando rclone authorize $tipo na tela: $autoriza), gravação $g, type = $tipo no arquivo: $tipo_ok, linhas do rclone sem rede com falha de nome ou de ligação: $rede, com token: $vazou, remoção $r; "
}
ok_nuv=0; ev_nuv=""
nuvem36 drive r_scope=drive.file
nuvem36 onedrive r_drive_id=b1c2d3e4f5a6b7c8 r_drive_type=personal
nuvem36 dropbox
nuvem36 pcloud r_hostname=api.pcloud.com
auditoria
a_nuv="$(linhas36 " evento=destino_gravado admin=$ADMIN destino=rclone-5 situacao=desligado pasta=dst36 intervalo=1440 remoto=(drive|onedrive|dropbox|pcloud) segredos=trocados\$") $(linhas36 ' evento=destino_teste .* destino=rclone-5 ')"
F36="$ok_nuv"; igual36 "$a_nuv" '4 0'
caso "$F36" testes 94 "Remoto do rclone: o formulário das quatro nuvens grava um remoto que o rclone aceita" \
  "${ev_nuv}auditoria (gravações com o tipo, e testes pedidos ao painel): $a_nuv"

# ------------------------------------------------------------------ só envia
# Nenhum subcomando além dos dois da lista vira linha de comando; o terminal não tem outro verbo; e o que sai do
# servidor da stack continua no servidor de teste.
x_sub="$(docker exec -w /opt/painel "$PAINEL" python3 -B -c '
import sys, rclone, saida
recusados = 0
for subcomando in sys.argv[1:]:
    try:
        rclone.linha_de(subcomando)
    except saida.Falha as falha:
        recusados += falha.motivo == "proibido"
print(recusados, "de", len(sys.argv) - 1, "recusados; aceitos:", " ".join(rclone.SUBCOMANDOS))' \
  sync move delete purge copy copyto moveto ls lsf cat mkdir rmdir rmdirs deletefile cleanup serve config selfupdate mount rcd rc touch dedupe 2>&1)"
docker exec "$PAINEL" python3 /opt/painel/servidor.py --destinos apagar rclone > "$W/terminal36" 2>&1; r_verbo=$?; x_verbo="$(grep -c '^FALHA: uso: --destinos \[enviar <destino> \[--sem-espera\]\]' "$W/terminal36" || true)"
n_ant="$(conta36 "$D36/srv" "$D36/srv-b")"
planta36 <<'SH'
rm -f /data/dst36/a1.txt
SH
passa36 rclone; r_apg=$?; p_apg="$(doterminal36 rclone)"
h_apg="$(ha36 dst36/a1.txt) $([[ "$(la36 "$D36/srv/painel36/sftp/dst36/a1.txt")" == "$s_a1" ]] && echo igual || echo diferente) $([[ "$(la36 "$D36/srv/painel36/dav/dst36/a1.txt")" == "$s_a1" ]] && echo igual || echo diferente)"
n_dep="$(conta36 "$D36/srv" "$D36/srv-b")"

# ------------------------------------------------------------------ a chave do servidor não é a guardada
# O servidor de teste volta com outra chave no SFTP da porta 2022: a passada, o botão do arquivo e o Testar param em
# chave_trocada e nada chega. Com a chave de antes de volta, o envio segue sem gravar nada de novo.
planta36 <<'SH'
cd /data/dst36 && echo depois > depois.txt && chown ftpdata:ftpdata depois.txt
SH
r_troca="$(sobe36 cache-x)"
for n in "$D36"/cache-x/serve-sftp/id_*; do [[ "$n" == *.pub || ! -f "$n" ]] || proibir "$(sed -n 2p "$n")"; done
passa36 rclone; r_tro=$?; p_tro="$(doterminal36 rclone)"
m_tro="$(arq36 "$K" rclone dst36/depois.txt)"; m_tro2="$(testa36 rclone)"
n_tro="$(find "$D36/srv/painel36/sftp" -name depois.txt | wc -l)"
t_tro="$(aba -b "$J" "$B/destinos")"; f_tro="$(tem36 'a chave do servidor não é a que o painel guardou') $(nocartao36 cache) $(nocartao36 cache-x)"
r_volta="$(sobe36 cache)"
passa36 rclone; r_vol=$?; p_vol="$(doterminal36 rclone)"; c_vol="$(chegou36 "$D36/srv/painel36/sftp" depois.txt)"
auditoria
a_tro="$(linhas36 ' evento=destino_falhou destino=rclone motivo=chave_trocada$') $(linhas36 " evento=destino_teste admin=$ADMIN destino=rclone resultado=chave_trocada\$") $(linhas36 " evento=destino_arquivo admin=$ADMIN destino=rclone arquivo=dst36/depois.txt bytes=7 resultado=chave_trocada\$")"
F36=0
igual36 "$r_sem $p_sem" "1 rclone: 0 arquivo(s), 0 bytes, $SEM36; parou: sem_chave"; igual36 "$m_sem" '303 /arquivos?pasta=dst36&m=destino_falha&d=rclone&f=sem_chave'
igual36 "$n_sem" 1; igual36 "$a_sc $a_ar" '1 1'; igual36 "$m_tes" "$TESTADO36"; [[ "$f_tes" == '0 '* && "${f_tes##* }" == 1 ]] || F36=1
igual36 "$r_troca $r_volta" 'sim sim'; igual36 "$r_tro $p_tro" "1 rclone: 0 arquivo(s), 0 bytes, $SEM36; parou: chave_trocada"
igual36 "$m_tro|$m_tro2" '303 /arquivos?pasta=dst36&m=destino_falha&d=rclone&f=chave_trocada|303 /destinos?m=falha&d=rclone&f=chave_trocada'
igual36 "$n_tro" 0; [[ "$t_tro" == '200 ' && "${f_tro%% *}" -ge 1 && "${f_tro#* }" == '1 0' ]] || F36=1
igual36 "$r_vol $p_vol $c_vol" "0 rclone: 1 arquivo(s), 7 bytes, $SEM36; chegou ao fim 1"; igual36 "$a_tro" '1 1 1'
caso "$F36" seguranca 135 "Remoto do rclone: sem a chave do servidor nada sai, o Testar a guarda, e servidor com outra chave é recusado" \
  "SFTP gravado sem chave de servidor: passada com saída $r_sem, $p_sem; botão do arquivo: $m_sem; no servidor de teste só o arquivo que já estava: $n_sem; auditoria (falha da passada, envio do arquivo): $a_sc $a_ar; Testar: $m_tes; ficha depois (falta testar, linha da chave do servidor, impressão igual à de uma chave pública do servidor de teste): $f_tes; servidor de teste recriado com outra chave: $r_troca; passada: saída $r_tro, $p_tro; botão do arquivo: $m_tro; Testar: $m_tro2; depois.txt no servidor de teste: $n_tro; ficha $t_tro(motivo explicado, impressão da chave guardada, impressão da chave nova: $f_tro); chave de antes de volta: $r_volta; passada: saída $r_vol, $p_vol, com a mesma soma: $c_vol; auditoria (falha da passada, teste e envio do arquivo com chave_trocada): $a_tro"

# ------------------------------------------------------------------ arquivo do remoto mexido por fora
# Uma linha a mais no segredo (um comando de SSH, que o rclone executaria) e o destino fica sem acesso: o painel não
# chama o rclone com um arquivo que ele mesmo não gravaria.
( umask 077; docker exec "$PAINEL" cat /segredos/rclone-remoto.txt > "$D36/guardado" )
docker exec "$PAINEL" sh -c 'echo "ssh = touch /tmp/marca36" >> /segredos/rclone-remoto.txt'; r_mex=$?
s_mex="$(situ36 rclone)"; m_mex="$(testa36 rclone)"; m_mex2="$(arq36 "$K" rclone dst36/depois.txt)"
passa36 rclone; r_mexp=$?; p_mex="$(grep -c -F 'FALHA: rclone: não configurado, desligado ou sem os segredos' "$W/passada" || true)"
t_mex="$(aba -b "$J" "$B/destinos")"; f_mex="$(vezes36 '<span class="etiqueta atencao">faltam os segredos</span>')"
h_mex="$(docker exec "$PAINEL" sh -c 'test -e /tmp/marca36 && echo sim || echo nao') $(docker exec "$REM36" sh -c 'test -e /tmp/marca36 && echo sim || echo nao')"
# Outro tipo no lugar do gravado: o remoto local do rclone gravaria dentro do próprio container.
docker exec -i "$PAINEL" sh -c 'cat > /segredos/rclone-remoto.txt' <<'CONF'
[destino]
type = local
CONF
s_loc="$(situ36 rclone)"; m_loc="$(testa36 rclone)"
docker exec -i "$PAINEL" sh -c 'cat > /segredos/rclone-remoto.txt' < "$D36/guardado"; r_dev=$?
s_dev="$(situ36 rclone)"; m_dev="$(testa36 rclone)"; d_dev="$(stat -c %a "$(segredo36 rclone)")"
F36=0
igual36 "$r_mex $r_dev" '0 0'; [[ "$s_mex" == 'rclone: ligado, faltam os segredos; '* && "$s_loc" == 'rclone: ligado, faltam os segredos; '* && "$s_dev" == 'rclone: ligado; '* ]] || F36=1
igual36 "$m_mex|$m_mex2|$m_loc" '303 /destinos?m=falha&d=rclone&f=segredo|303 /arquivos?pasta=dst36&m=destino_falha&d=rclone&f=segredo|303 /destinos?m=falha&d=rclone&f=segredo'
igual36 "$r_mexp $p_mex" '1 1'; igual36 "$t_mex$f_mex" '200 1'; igual36 "$h_mex" 'nao nao'; igual36 "$m_dev $d_dev" "$TESTADO36 600"
caso "$F36" seguranca 138 "Remoto do rclone: arquivo do remoto alterado por fora deixa o destino sem acesso, sem o rclone ser chamado" \
  "linha de comando de SSH acrescentada ao segredo (0 = feito): $r_mex; terminal: ${s_mex%%;*}; Testar: $m_mex; botão do arquivo: $m_mex2; passada: saída $r_mexp, aviso de destino sem os segredos: $p_mex; ficha $t_mex(faltam os segredos: $f_mex); marca do comando no painel e no servidor de teste: $h_mex; tipo trocado para local: ${s_loc%%;*}; Testar: $m_loc; arquivo de antes devolvido (0 = feito): $r_dev; terminal: ${s_dev%%;*}; Testar: $m_dev; modo do arquivo: $d_dev"

# ------------------------------------------------------------------ segredos fora de tudo, com um envio em andamento
# Um arquivo grande dá tempo de ler a lista de processos do painel durante o envio: a linha do rclone leva a cópia
# da configuração e o alvo, e nenhum segredo. Depois, o que as telas, os registros e a auditoria mostram.
id_ant="$(docker inspect -f '{{.Id}} {{.RestartCount}}' "$PAINEL" 2>/dev/null | cut -c1-12,65-)"
planta36 <<'SH'
head -c 100663296 /dev/urandom > /data/dst36/grande.bin && chown ftpdata:ftpdata /data/dst36/grande.bin
SH
: > "$W/proc36"; : > "$W/copia36"
( passa36 rclone; echo "$?" > "$W/passada36.saida" ) &
envio36=$!
while kill -0 "$envio36" 2> /dev/null; do
  docker exec "$PAINEL" sh -c 'for f in /proc/[0-9]*/cmdline; do tr "\0" " " < "$f" 2> /dev/null; echo; done' 2> /dev/null | grep -a -F ' rcat ' >> "$W/proc36"
  [[ -s "$W/copia36" ]] || docker exec "$PAINEL" sh -c 'stat -c "%a %n" /tmp/rclone/*.conf' >> "$W/copia36" 2> /dev/null
done
wait "$envio36"; r_gra="$(cat "$W/passada36.saida")"; p_gra="$(doterminal36 rclone)"
c_gra="$(chegou36 "$D36/srv/painel36/sftp" grande.bin)"
v_proc="$(grep -c -a . "$W/proc36" || true) $(grep -c -a -E '^/usr/local/bin/rclone --config /tmp/rclone/rclone\.conf .* rcat --size 100663296 destino:painel36/sftp/dst36/grande\.bin *$' "$W/proc36" || true) $(vaza36 "$W/proc36") $(grep -c -a -E 'remoto36|teste@|[-_](pass|user|host|url|token)[ =]|RCLONE_' "$W/proc36" || true)"
v_copia="$(sort -u "$W/copia36" | tr '\n' ' ')$(docker exec "$PAINEL" sh -c 'ls /tmp/rclone/*.conf 2> /dev/null | wc -l')"
v_cgroup="$(docker exec "$PAINEL" sh -c 'cat /sys/fs/cgroup/pids.events; grep oom_kill /sys/fs/cgroup/memory.events' | tr '\n' ' ')"
id_dep="$(docker inspect -f '{{.Id}} {{.RestartCount}}' "$PAINEL" 2>/dev/null | cut -c1-12,65-)"
: > "$W/telas36"
for n in /destinos '/destinos/rclone?id=rclone' '/destinos/rclone?id=rclone-2' '/destinos/rclone?id=rclone-4' '/destinos/rclone?id=novo&copiar=rclone-4' \
    '/destinos/remover?destino=rclone' '/arquivos?pasta=dst36' '/destinos/arquivo?tipo=rclone&arquivo=dst36/a2.bin' '/destinos?m=falha&d=rclone&f=chave_trocada' /log /servidor; do
  aba -b "$J" "$B$n" > /dev/null; cat "$W/corpo" >> "$W/telas36"
done
v_telas="$(grep -c -a . "$W/telas36" || true) $(vaza36 "$W/telas36") $(grep -c -a -F -e 'remoto36.test' -e 'serve-sftp' "$W/telas36" || true)"
auditoria
v_aud="$(vaza36 "$W/auditoria") $(grep -c -E 'remoto36|painel36|teste@|:2022|:2023|:8443' "$W/auditoria" || true) $(grep -c -E ' destino=rclone(-[0-9]+)? .* remoto=(sftp|webdav|drive|onedrive|dropbox|pcloud) ' "$W/auditoria" || true)"
: > "$W/logs36"; for n in "$FTP" "$PAINEL" "$NGINX"; do docker logs "$n" >> "$W/logs36" 2>&1; docker inspect "$n" >> "$W/logs36" 2>&1; done
docker exec "$PAINEL" python3 /opt/painel/servidor.py --destinos >> "$W/logs36" 2>&1
docker exec "$PAINEL" sh -c 'cat /painel/destinos/rclone*.conf /painel/destinos/rclone*.estado' >> "$W/logs36" 2>&1
v_logs="$(grep -c -a . "$W/logs36" || true) $(vaza36 "$W/logs36")"
# O controle: a mesma busca encontra os segredos onde eles têm de estar, e só ali.
v_seg="$(cat "$S/destinos"/rclone*-remoto.txt | vaza36 /dev/stdin) $(stat -c '%a' "$S/destinos"/rclone*-remoto.txt | sort -u | tr '\n' ' ')$([[ "$(stat -c %u "$S/destinos"/rclone*-remoto.txt | sort -u)" == "$(stat -c %u "$S/destinos")" ]] && echo 'dono da pasta' || echo 'outro dono')"
F36=0
igual36 "$r_gra $p_gra $c_gra" "0 rclone: 1 arquivo(s), 100663296 bytes, $SEM36; chegou ao fim 1"
[[ "${v_proc%% *}" -ge 1 && "$(cut -d' ' -f2 <<< "$v_proc")" == "${v_proc%% *}" && "$(cut -d' ' -f3- <<< "$v_proc")" == '0 0' ]] || F36=1
igual36 "$v_copia" '600 /tmp/rclone/rclone.conf 0'; igual36 "$v_cgroup" 'max 0 oom_kill 0 '; igual36 "$id_ant" "$id_dep"
[[ "${v_telas%% *}" -ge 100 && "${v_telas#* }" == '0 0' ]] || F36=1
[[ "$v_aud" == '0 0 '* && "${v_aud##* }" -ge 10 ]] || F36=1; [[ "${v_logs%% *}" -ge 100 && "${v_logs##* }" == 0 ]] || F36=1
[[ "${v_seg%% *}" -ge 4 && "${v_seg#* }" == '600 dono da pasta' ]] || F36=1
caso "$F36" seguranca 137 "Remoto do rclone: senha, frase, chave e servidor fora das telas, da auditoria, dos registros e da lista de processos" \
  "envio de 96 MiB: saída $r_gra, $p_gra, com a mesma soma: $c_gra; lista de processos do painel durante o envio (linhas do rclone, linhas na forma esperada, com segredo, com servidor, usuário ou senha): $v_proc; cópia da configuração durante o envio e cópias em /tmp/rclone depois: $v_copia; limites do painel (pids e memória): $v_cgroup; container e reinícios antes e depois: $id_ant e $id_dep; onze telas do administrador (linhas, com segredo, com o nome do servidor de teste): $v_telas; auditoria (linhas com segredo, com servidor, porta, usuário ou pasta do remoto, linhas de gravação com o tipo): $v_aud; registros e inspeção dos três containers, terminal e arquivos de configuração e de andamento (linhas, com segredo): $v_logs; controle, nos arquivos do remoto (linhas com segredo, modo, dono): $v_seg"

# ------------------------------------------------------------------ para onde o painel aceita ir, e o que ele diz quando não chega
# Dois destinos de prova, desligados, regravados a cada caso. O teste do painel diz o motivo, sem o texto do rclone.
ok_prova=0; ev_prova=""
g_pw="$(grava36 "$J" "$K" "$W/painel.senha" id=novo -ligado "${DV36[@]}" caminho=painel36/prova)"; guardar36 rclone-5
g_ps="$(grava36 "$J" "$K" "$W/painel.senha" id=novo -ligado "${SF36[@]}" caminho=painel36/prova)"; guardar36 rclone-6
prova36 rclone-5 tls 'WebDAV com nome que não está no certificado' "${DV36[@]}" r_url=https://outro.remoto36.test:8443 caminho=painel36/prova
prova36 rclone-5 endereco 'WebDAV no próprio container' "${DV36[@]}" r_url=https://localhost:8443 caminho=painel36/prova
prova36 rclone-5 dns 'WebDAV com nome que não existe' "${DV36[@]}" r_url=https://nao-existe.remoto36.test:8443 caminho=painel36/prova
prova36 rclone-5 conexao 'WebDAV em porta fechada' "${DV36[@]}" r_url=https://dav.remoto36.test:8444 caminho=painel36/prova
prova36 rclone-5 recusado 'WebDAV com senha errada' "${DV36[@]}" "r_pass@$D36/errada.txt" caminho=painel36/prova; guardar36 rclone-5
prova36 rclone-6 endereco 'SFTP no próprio container' "${SF36[@]}" r_host=127.0.0.1 caminho=painel36/prova
prova36 rclone-6 conexao 'SFTP em porta fechada' "${SF36[@]}" r_port=2099 caminho=painel36/prova
prova36 rclone-6 recusado 'SFTP com senha errada' "${SF36[@]}" "r_pass@$D36/errada.txt" caminho=painel36/prova; guardar36 rclone-6
# Sem a autoridade no painel, o certificado do servidor de teste deixa de ser aceito.
docker exec "$PAINEL" rm -f /painel/destinos/ca.pem
prova36 rclone-5 tls 'WebDAV certo, sem a autoridade no painel' "${DV36[@]}" caminho=painel36/prova
t_pro="$(aba -b "$J" "$B/destinos?m=falha&d=rclone-5&f=tls")"; f_pro="$(tem36 'Remoto do rclone 5: não deu certo. Motivo: o certificado do serviço não foi aceito.')"
n_pro="$(conta36 "$D36/srv/painel36/prova" "$D36/srv-b/painel36/prova")"
auditoria
a_pro=""; for n in tls endereco dns conexao recusado; do a_pro+="$n $(linhas36 " evento=destino_teste admin=$ADMIN destino=rclone-[56] resultado=$n\$") "; done
F36="$ok_prova"
igual36 "$g_dv0|$m_dv0|$n_dv0" "$GRAVADO36|303 /destinos?m=falha&d=rclone-2&f=tls|0"; igual36 "$g_pw|$g_ps" "$GRAVADO36|$GRAVADO36"
igual36 "$t_pro$f_pro" '200 1'; igual36 "$n_pro" 0; igual36 "$a_pro" 'tls 2 endereco 2 dns 1 conexao 2 recusado 2 '
caso "$F36" seguranca 140 "Remoto do rclone: certificado conferido, endereço do próprio container recusado e motivo da falha sem o texto do rclone" \
  "WebDAV gravado antes de a autoridade entrar no painel: $g_dv0, Testar: $m_dv0, arquivos no servidor de teste: $n_dv0; destinos de prova: $g_pw e $g_ps; $ev_prova; tela da falha $t_pro(motivo explicado: $f_pro); arquivos que os testes recusados deixaram no servidor de teste: $n_pro; auditoria, testes por resultado: $a_pro"

# ------------------------------------------------------------------ nada apagado no servidor de teste, e a limpeza
# Remove os seis destinos pelo painel: o que cada um enviou continua no servidor de teste, o arquivo que já estava lá
# continua igual e o que foi apagado no servidor da stack também.
n_fim0="$(conta36 "$D36/srv" "$D36/srv-b")"; m_fim=""
for n in rclone-6 rclone-5 rclone-4 rclone-3 rclone-2 rclone; do m_fim+="$(remove36 "$n" | cut -c1-3) "; done
n_fim="$(conta36 "$D36/srv" "$D36/srv-b")"; s_sen="$(la36 "$D36/srv/painel36/sftp/sentinela.txt")"
s_fim="$([[ "$(la36 "$D36/srv/painel36/sftp/dst36/a1.txt")" == "$s_a1" ]] && echo igual || echo diferente)"
x_fim="$(situ36 rclone)|$(ls "$S/destinos"/rclone* 2> /dev/null | wc -l)|$(docker exec "$PAINEL" sh -c 'ls /painel/destinos/ | grep -c "^rclone"' || true)"
h_fim="$(ha36 dst36/a2.bin) $(ha36 dst36/grande.bin) $(ha36 dst36/a1.txt)"
v_reg="$(grep -c -a -i -E 'delete|remove|rmdir|purge' "$D36/saida"/*.log 2> /dev/null | awk -F: '{ s += $NF } END { print s + 0 }')"
F36=0
igual36 "$x_sub" '23 de 23 recusados; aceitos: rcat obscure'; igual36 "$r_verbo $x_verbo" '1 1'
igual36 "$r_apg $p_apg" "0 rclone: 0 arquivo(s), 0 bytes, $SEM36; chegou ao fim"; igual36 "$h_apg" 'nao igual igual'; igual36 "$n_ant" "$n_dep"
igual36 "$m_fim" '303 303 303 303 303 303 '; igual36 "$n_fim0" "$n_fim"; [[ "$n_fim" -ge 25 ]] || F36=1
igual36 "$s_sen0 $s_fim" "$s_sen igual"; igual36 "$x_fim" 'rclone: não configurado|0|0'; igual36 "$h_fim" 'sim sim nao'; igual36 "$v_reg" 0
caso "$F36" seguranca 136 "Remoto do rclone: só envia; nenhum subcomando que lista, baixa, move ou apaga, e nada some do servidor de teste" \
  "subcomandos pedidos à função que monta a linha do rclone: $x_sub; verbo que não existe no terminal: saída $r_verbo, aviso de uso: $x_verbo; a1.txt apagado no servidor da stack e passada: saída $r_apg, $p_apg; a1.txt na stack, no SFTP e no WebDAV de teste: $h_apg; arquivos no servidor de teste antes e depois: $n_ant e $n_dep; remoção dos seis destinos: $m_fim; arquivos no servidor de teste antes e depois dela: $n_fim0 e $n_fim; arquivo que já estava no servidor de teste, antes de tudo e no fim: ${s_sen0:0:16} e ${s_sen:0:16}; a1.txt no SFTP de teste no fim: $s_fim; destinos, segredos e configurações do rclone depois da remoção: $x_fim; a2.bin, grande.bin e a1.txt no servidor da stack: $h_fim; linhas de apagar no registro do servidor de teste: $v_reg"

# ------------------------------------------------------------------ limpeza
docker rm -f "$REM36" > /dev/null 2>&1
mu del dst36
docker exec "$FTP" rm -rf /data/dst36 > /dev/null 2>&1
docker exec "$PAINEL" rm -f /painel/destinos/ca.pem > /dev/null 2>&1
rm -rf "$D36"; rm -f "$W"/dst36.* "$W/vazio36.jar" "$W/proc36" "$W/copia36" "$W/telas36" "$W/logs36" "$W/terminal36" "$W/passada36.saida"
painel_de_pe
