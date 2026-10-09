#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa AB: aba Servidor. Os três containers da stack na tela, cada um com o uso contra o limite que recebeu, e os
# recursos da máquina; a rede do FTP e os recursos de cada container publicados e lidos pelo painel, a aba fora do
# alcance de quem não é administrador, os arquivos de estado lidos sem confiança e a atualização automática, que não
# mantém a sessão aberta. No fim, o tempo da sessão volta ao que era.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel zera a contagem de falhas de entrada e encerra as sessões.
dc restart painel > /dev/null 2>&1; painel_de_pe
e_adm="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"
U28="$W/u28.jar"; A28="$W/a28.jar"; C28="$W/c28.jar"
estado28() { docker exec "$FTP" cat /auth/rede.estado 2>/dev/null | tr -d '\n'; }                 # a linha que o vigia publicou
recebido28() { estado28 | cut -d ' ' -f 3; }                                                      # bytes recebidos desde que o ftp subiu
cadastro28() { docker exec "$FTP" sh -c 'sha256sum < /auth/pureftpd.passwd | cut -c1-16'; }       # o hash não sai inteiro do container
atualiza28() { grep -i -c '^refresh: 10; url=/servidor?auto=1' "$1" 2>/dev/null || true; }        # <cabeçalhos>: pedido de nova leitura em 10 s
doze28='^[0-9]+( [0-9]+){11}$'                                                                    # a linha de recursos de um container
publicado28() { docker exec "$1" cat "$2" 2>/dev/null | tr -d '\n'; }                             # <container> <arquivo>
# <container>: os limites dele como a tela escreve ("de 0,5 núcleo", "de 64,0 MiB", "de 32"), um por linha
limites28() {
  docker inspect -f '{{.HostConfig.NanoCpus}} {{.HostConfig.Memory}} {{.HostConfig.PidsLimit}}' "$1" | awk '{
    n = sprintf("%.2f", $1 / 1e9); sub(/0+$/, "", n); sub(/\.$/, "", n); sub(/\./, ",", n)
    m = $2 / 1048576; u = "MiB"; if (m >= 1024) { m /= 1024; u = "GiB" }
    m = sprintf("%.1f", m); sub(/\./, ",", m)
    printf "de %s\302\240%s\nde %s\302\240%s\n>[0-9.]+ de %d</span>\n", n, ($1 >= 2e9 ? "núcleos" : "núcleo"), m, u, $3 }'
}
# <espera em s> <comando...>: repete o comando até ele passar ou o tempo acabar
ate28() { local fim=$((SECONDS + $1)); shift; until "$@"; do (( SECONDS < fim )) || return 1; sleep 1; done; }

nova_senha "$W/u28.senha"; mu add equip28 "$W/u28.senha" equip28; r_mu=$?
head -c 1048576 /dev/urandom > "$W/s28.bin"

# ------------------------------------------------------------------ a aba, com o que a máquina e a stack informam
tem28() { [[ -n "$(estado28)" ]]; }
ate28 20 tem28; antes28="$(recebido28)"; modo28="$(docker exec "$FTP" stat -c '%U:%G %a %F' /auth/rede.estado 2>&1)"
r_ftp="$(ftp_curl tls equip28 "$W/u28.senha" -T "$W/s28.bin" "$F/s28.bin")"
cresceu28() { local agora; agora="$(recebido28)"; [[ "$agora" =~ ^[0-9]+$ && "$agora" -ge $((antes28 + 1048576)) ]]; }
ate28 20 cresceu28; r_cresceu=$?; depois28="$(recebido28)"; linha28="$(estado28)"
r_aba="$(c -o "$W/corpo" -D "$W/s28.cab" -w '%{http_code}' -b "$J" "$B/servidor")"; cp "$W/corpo" "$W/s28.html"
servicos28="$(grep -o -E '</svg>(Servidor FTP|Painel|Frente web \(nginx\))<span class="saude bom">' "$W/s28.html" | wc -l)"
# Cada container publica o que usa e o limite que recebeu; a tela escreve os três limites de cada um, e nenhum tem swap.
limites_tela=0; sem_swap=0; publicados28=0
for nome in "$FTP" "$PAINEL" "$NGINX"; do
  certos=0
  while IFS= read -r limite; do grep -q -E "$limite" "$W/s28.html" && certos=$((certos + 1)); done < <(limites28 "$nome")
  [[ "$certos" == 3 ]] && limites_tela=$((limites_tela + 1))
  [[ "$(docker inspect -f '{{eq .HostConfig.Memory .HostConfig.MemorySwap}}' "$nome")" == true \
    && "$(docker exec "$nome" cat /sys/fs/cgroup/memory.swap.max 2>/dev/null)" == 0 ]] && sem_swap=$((sem_swap + 1))
done
modo_ftp28="$(docker exec "$FTP" stat -c '%U:%G %a %F' /auth/recursos.estado 2>&1)"
modo_nginx28="$(docker exec "$NGINX" stat -c '%u:%g %a %F' /estado/recursos.estado 2>&1)"
[[ "$(publicado28 "$FTP" /auth/recursos.estado)" =~ $doze28 ]] && publicados28=$((publicados28 + 1))
[[ "$(publicado28 "$NGINX" /estado/recursos.estado)" =~ $doze28 ]] && publicados28=$((publicados28 + 1))
alocado28="$(grep -c -F 'Alocado aos 3 containers' "$W/s28.html")"
cartoes28=0
for titulo in Processador Memória Disco 'Rede do FTP'; do
  grep -q -F "</svg>$titulo<span class=\"saude " "$W/s28.html" && cartoes28=$((cartoes28 + 1))
done
nucleos_host="$(grep -c '^cpu[0-9]' /proc/stat)"; nucleos_tela="$(grep -c -E "<p class=\"suave\">[0-9,]+ de $nucleos_host[^a-z<]{1,2}núcleos? em uso</p>" "$W/s28.html")"
sem_leitura28="$(grep -c -F 'sem leitura' "$W/s28.html")"; total28="$(grep -c -F '<dt>Total recebido</dt>' "$W/s28.html")"
menu28="$(grep -c -F 'href="/servidor"' "$W/s28.html")"; script28="$(grep -c -i '<script' "$W/s28.html")"
sem_auto="$(atualiza28 "$W/s28.cab")"
r_auto="$(c -o "$W/corpo" -D "$W/s28.cab" -w '%{http_code}' -b "$J" "$B/servidor?auto=1")"; com_auto="$(atualiza28 "$W/s28.cab")"
parar28="$(grep -c -F 'Parar a atualização' "$W/corpo")"
[[ "$e_adm" == 303 && "$r_mu" == 0 && "$modo28" == "root:root 600 regular file" && "$r_ftp" == 0 && "$r_cresceu" == 0 \
  && "$linha28" =~ ^[0-9]+(\ [0-9]+){6}$ && "$r_aba" == 200 && "$servicos28" == 3 && "$limites_tela" == 3 && "$sem_swap" == 3 \
  && "$publicados28" == 2 && "$modo_ftp28" == "root:root 600 regular file" && "$modo_nginx28" == "10001:10001 600 regular file" \
  && "$alocado28" == 1 && "$cartoes28" == 4 && "$nucleos_tela" == 1 \
  && "$sem_leitura28" == 0 && "$total28" == 1 && "$menu28" -ge 1 && "$script28" == 0 && "$sem_auto" == 0 && "$r_auto" == 200 \
  && "$com_auto" == 1 && "$parar28" == 1 ]]
caso $? testes 55 "Aba Servidor: containers da stack e recursos da máquina" "GET /servidor como administrador: $r_aba · containers no ar na tela (ftp, painel, nginx): $servicos28 de 3 · com os limites de processador, memória e processos iguais aos do Docker: $limites_tela de 3 · sem swap (limite com swap igual ao de memória e memory.swap.max em 0): $sem_swap de 3 · linha de doze números publicada pelo ftp e pelo nginx: $publicados28 de 2 · /auth/recursos.estado: $modo_ftp28 · /estado/recursos.estado do nginx: $modo_nginx28 · soma do alocado na tela: $alocado28 · cartões do servidor (processador, memória, disco, rede): $cartoes28 de 4 · núcleos do servidor: $nucleos_host, escritos na tela: $([[ "$nucleos_tela" == 1 ]] && echo sim || echo NÃO) · /auth/rede.estado: $modo28, sete números: $([[ "$linha28" =~ ^[0-9]+(\ [0-9]+){6}$ ]] && echo sim || echo NÃO) · envio de 1 MiB por FTPS (saída $r_ftp): bytes recebidos de $antes28 para $depois28 · cartão da rede com leitura: $([[ "$sem_leitura28" == 0 && "$total28" == 1 ]] && echo sim || echo NÃO) · <script> na tela: $script28 · cabeçalho Refresh sem pedir: $sem_auto, com ?auto=1 ($r_auto): $com_auto, com o botão de parar: $parar28"

# ------------------------------------------------------------------ só administrador, e o arquivo da rede lido sem confiança
s_1="$(c -o "$W/corpo" -D "$W/s28.cab" -w '%{http_code} %{redirect_url}' "$B/servidor?auto=1" | sed "s|$B||")"; s_1_auto="$(atualiza28 "$W/s28.cab")"
s_1_dado="$(grep -c -E 'Processador|Núcleos' "$W/corpo")"; s_2="$(aba "$B/servidor")"
e_u="$(COMO=equip28 entrar "$U28" "$W/u28.senha")"; proibir "$(biscoito_de "$U28")"
auditoria; n_antes="$(eventos 'recusa_papel usuario=equip28 caminho=/servidor')"
u_1="$(aba -b "$U28" "$B/servidor")"; u_dado="$(grep -c -E 'Processador|Núcleos|Rede do FTP' "$W/corpo")"
u_2="$(c -o "$W/corpo" -D "$W/s28.cab" -w '%{http_code}' -b "$U28" "$B/servidor?auto=1")"; u_auto="$(atualiza28 "$W/s28.cab")"
u_menu="$(c -b "$U28" "$B/meus-arquivos" | grep -c -F 'href="/servidor"')"
auditoria; n_depois="$(eventos 'recusa_papel usuario=equip28 caminho=/servidor')"
nucleo28="$(grep -c -F "$(uname -r)" "$W/s28.html")"
# Arquivo com o que não é número, e depois um link para o cadastro: o painel não lê nenhum dos dois. O vigia publica
# de novo na leitura seguinte, por isso a tela é pedida logo depois da troca, até cinco vezes.
soma_0="$(cadastro28)"; lixo28=1; link28=1; vazou28=0
for _ in 1 2 3 4 5; do
  docker exec "$FTP" sh -c 'printf "1 2 3 4 5 6 <b>marca28</b>\n" > /auth/rede.estado'
  r_lixo="$(aba -b "$J" "$B/servidor")"; vazou28=$((vazou28 + $(grep -c -F 'marca28' "$W/corpo")))
  [[ "$r_lixo" == "200 " && "$(grep -c -F 'sem leitura' "$W/corpo")" == 1 ]] && { lixo28=0; break; }
done
for _ in 1 2 3 4 5; do
  docker exec "$FTP" sh -c 'rm -f /auth/rede.estado && ln -s /auth/pureftpd.passwd /auth/rede.estado'
  r_link="$(aba -b "$J" "$B/servidor")"; vazou28=$((vazou28 + $(grep -c -F 'equip28' "$W/corpo")))
  [[ "$r_link" == "200 " && "$(grep -c -F 'sem leitura' "$W/corpo")" == 1 ]] && { link28=0; break; }
done
# O vigia troca o link pelo arquivo dele: o cadastro, para onde o link apontava, fica como estava.
r_ftp2="$(ftp_curl tls equip28 "$W/u28.senha" "$F/")"
de_volta28() { [[ "$(docker exec "$FTP" stat -c '%F' /auth/rede.estado 2>/dev/null)" == "regular file" && "$(estado28)" =~ ^[0-9]+(\ [0-9]+){6}$ ]]; }
ate28 20 de_volta28; r_volta=$?
# O mesmo com os recursos que o nginx publica, na única pasta em que ele escreve: doze campos com marcação, e depois
# um link para o cadastro do FTP, que o painel enxerga. O cartão do nginx fica sem leitura e nada do arquivo vai à tela.
sem28() { grep -o -E 'Frente web \(nginx\)<span class="saude [a-z]+">.{0,400}sem leitura: ela aparece' "$W/corpo" | wc -l; }
# O nginx pode publicar entre a troca e o pedido: a tela é pedida logo depois da troca, até três vezes.
for _ in 1 2 3; do
  docker exec "$NGINX" sh -c 'printf "1 2 3 4 5 6 7 8 9 10 11 <b>marca28</b>\n" > /estado/recursos.estado'
  r_lixo_n="$(aba -b "$J" "$B/servidor")"; vazou28=$((vazou28 + $(grep -c -F 'marca28' "$W/corpo"))); lixo_n="$(sem28)"
  [[ "$lixo_n" == 1 ]] && break
done
for _ in 1 2 3; do
  docker exec "$NGINX" sh -c 'rm -f /estado/recursos.estado && ln -s /auth/pureftpd.passwd /estado/recursos.estado'
  r_link_n="$(aba -b "$J" "$B/servidor")"; vazou28=$((vazou28 + $(grep -c -F 'equip28' "$W/corpo"))); link_n="$(sem28)"
  [[ "$link_n" == 1 ]] && break
done
# Parado, o nginx publica uma vez por minuto: a leitura seguinte troca o link pelo arquivo dele.
de_volta_n28() { [[ "$(docker exec "$NGINX" stat -c '%F' /estado/recursos.estado 2>/dev/null)" == "regular file" && "$(publicado28 "$NGINX" /estado/recursos.estado)" =~ $doze28 ]]; }
ate28 80 de_volta_n28; r_volta_n=$?; aba -b "$J" "$B/servidor" > /dev/null; volta_n="$(sem28)"; soma_1="$(cadastro28)"
[[ "$s_1" == "303 /entrar" && "$s_1_auto" == 0 && "$s_1_dado" == 0 && "$s_2" == "303 /entrar" && "$e_u" == 303 && "$u_1" == "404 " \
  && "$u_dado" == 0 && "$u_2" == 404 && "$u_auto" == 0 && "$u_menu" == 0 && "$n_depois" -gt "$n_antes" && "$nucleo28" == 0 \
  && "$lixo28" == 0 && "$link28" == 0 && "$vazou28" == 0 && "$r_ftp2" == 0 && "$r_volta" == 0 && "$r_lixo_n" == "200 " && "$lixo_n" == 1 \
  && "$r_link_n" == "200 " && "$link_n" == 1 && "$r_volta_n" == 0 && "$volta_n" == 0 && -n "$soma_0" && "$soma_0" == "$soma_1" ]]
caso $? seguranca 97 "Aba Servidor só para administrador, com os arquivos de estado lidos sem confiança" "sem sessão, GET /servidor: $s_2· GET /servidor?auto=1: $s_1· cabeçalho Refresh: $s_1_auto, dado da aba no corpo: $s_1_dado · com a sessão do usuário do FTP equip28 (entrada $e_u): GET /servidor $u_1· com ?auto=1: $u_2, cabeçalho Refresh: $u_auto, dado da aba no corpo: $u_dado, item Servidor no menu dele: $u_menu, recusas de papel na auditoria (uma por minuto do mesmo endereço): de $n_antes para $n_depois · versão do núcleo do sistema na tela do administrador: $nucleo28 · /auth/rede.estado trocado por texto com marcação: tela $r_lixo· rede sem leitura: $([[ "$lixo28" == 0 ]] && echo sim || echo NÃO) · trocado por link para o cadastro do FTP: tela $r_link· rede sem leitura: $([[ "$link28" == 0 ]] && echo sim || echo NÃO) · texto do arquivo ou do cadastro na tela: $vazou28 · depois de um login por FTPS (saída $r_ftp2), o vigia publica de novo um arquivo comum com sete números: $([[ "$r_volta" == 0 ]] && echo sim || echo NÃO) · recursos do nginx trocados por texto com marcação: tela $r_lixo_n· cartão do nginx sem leitura: $lixo_n · trocados por link para o cadastro do FTP: tela $r_link_n· cartão do nginx sem leitura: $link_n · em até 80 s o nginx publica de novo um arquivo comum com doze números: $([[ "$r_volta_n" == 0 ]] && echo sim || echo NÃO), cartão sem leitura depois disso: $volta_n · cadastro do FTP igual ao de antes: $([[ -n "$soma_0" && "$soma_0" == "$soma_1" ]] && echo sim || echo NÃO)"

# ------------------------------------------------------------------ a atualização automática não mantém a sessão
sessao_0="$(env_file="$ENVA" env_valor PAINEL_SESSAO_MINUTOS 15)"
gravar_env "$ENVA" PAINEL_SESSAO_MINUTOS 1
dep; r_dep=$?; saude_1="$(saude "$FTP" "$PAINEL" "$NGINX")"; painel_de_pe
e_a="$(entrar "$A28" "$W/painel.senha")"; proibir "$(biscoito_de "$A28")"
e_c="$(entrar "$C28" "$W/painel.senha")"; proibir "$(biscoito_de "$C28")"
# Oito pedidos, um a cada 10 s: a sessão A só pede a atualização automática; a sessão C abre a aba como quem usa o painel.
ev_a=""; ev_c=""; a_200=0; c_200=0; a_ultimo=""
for _ in 1 2 3 4 5 6 7 8; do
  sleep 10
  a_ultimo="$(aba -b "$A28" "$B/servidor?auto=1")"; r_c="$(aba -b "$C28" "$B/servidor")"
  [[ "$a_ultimo" == "200 " ]] && a_200=$((a_200 + 1)); [[ "$r_c" == "200 " ]] && c_200=$((c_200 + 1))
  ev_a+="$a_ultimo"; ev_c+="$r_c"
done
a_fim="$(aba -b "$A28" "$B/")"; c_fim="$(aba -b "$C28" "$B/")"
gravar_env "$ENVA" PAINEL_SESSAO_MINUTOS "$sessao_0"
dep; r_fim=$?; saude_fim="$(saude "$FTP" "$PAINEL" "$NGINX")"; painel_de_pe
[[ "$r_dep" == 0 && "$saude_1" == "healthy healthy healthy " && "$e_a" == 303 && "$e_c" == 303 && "$a_200" -ge 4 && "$a_200" -le 6 \
  && "$a_ultimo" == "303 /entrar" && "$a_fim" == "303 /entrar" && "$c_200" == 8 && "$c_fim" == "200 " \
  && "$r_fim" == 0 && "$saude_fim" == "healthy healthy healthy " ]]
caso $? seguranca 98 "Atualização automática da aba Servidor não mantém a sessão aberta" "deploy.sh com PAINEL_SESSAO_MINUTOS=1: saída $r_dep, saúde $saude_1· duas sessões de administrador abertas ($e_a e $e_c) e oito pedidos em cada uma, um a cada 10 s · sessão que só pede /servidor?auto=1: $ev_a· depois, GET /: $a_fim· sessão que abre /servidor sem o auto: $ev_c· depois, GET /: $c_fim· de volta a PAINEL_SESSAO_MINUTOS=$sessao_0: saída $r_fim, saúde $saude_fim"
