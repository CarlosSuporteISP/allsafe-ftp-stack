#!/usr/bin/env bash
# Etapa M: pastas. Pasta criada pelo painel, pasta escolhida para o usuário, pasta dividida entre usuários,
# criação sem sessão, nome que tenta sair da pasta dos dados e usuário preso à pasta escolhida.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

# O reinício do painel zera a contagem das recusas (uma linha por minuto e por endereço na auditoria)
# e encerra as sessões; daqui em diante vale uma sessão nova do administrador inicial.
dc restart painel > /dev/null 2>&1; painel_de_pe
e_pastas="$(entrar "$J" "$W/painel.senha")"; proibir "$(biscoito_de "$J")"; K="$(csrf)"; proibir "$K"

cria() { envio /arquivos/pasta --data-urlencode "csrf=$K" --data-urlencode "pasta=$1" --data-urlencode "nome=$2"; }  # <pasta de cima> <nome> → "código destino"
novo_usuario() { # <usuário> <pasta> <arquivo da senha> → "código destino"
  envio /usuarios/novo --data-urlencode "csrf=$K" --data-urlencode "usuario=$1" --data-urlencode "pasta=$2" --data-urlencode "senha@$3" --data-urlencode "confirmacao@$3"
}
dono() { docker exec "$FTP" stat -c '%U:%G %a %F' "/data/$1" 2>/dev/null || echo ausente; }   # <pasta>: dono, modo e tipo
pasta_de() { docker exec "$FTP" sh -c "grep '^$1:' /auth/pureftpd.passwd | cut -d: -f6"; }      # <usuário>: pasta gravada no cadastro do FTP
arvore() { docker exec "$FTP" sh -c 'find /data /auth -xdev | sort | sha256sum | cut -c1-16'; }  # tudo o que existe nos dados e no cadastro

nova_senha "$W/u13a.senha"; nova_senha "$W/u13b.senha"; nova_senha "$W/u13c.senha"; nova_senha "$W/u13d.senha"; nova_senha "$W/u13e.senha"

# ------------------------------------------------------------------ pasta criada pelo painel
auditoria; n_antes="$(eventos pasta_criada)"
raiz="$(aba -b "$J" "$B/arquivos")"; formulario="$(grep -c 'action="/arquivos/pasta"' "$W/corpo")"
r_1="$(cria '' clientes)"; r_2="$(cria clientes olt-01)"; d_1="$(dono clientes)"; d_2="$(dono clientes/olt-01)"
depois="$(aba -b "$J" "$B/arquivos?pasta=clientes&m=criada")"; aviso="$(grep -c 'Pasta criada' "$W/corpo")"; na_lista="$(grep -c 'href="/arquivos?pasta=clientes/olt-01"' "$W/corpo")"
dentro="$(aba -b "$J" "$B/arquivos?pasta=clientes/olt-01")"; atalho="$(grep -c 'href="/usuarios/novo?pasta=clientes/olt-01"' "$W/corpo")"
tela="$(aba -b "$J" "$B/usuarios/novo?pasta=clientes/olt-01")"; preenchido="$(grep -c 'name="pasta"[^>]*value="clientes/olt-01"' "$W/corpo")"; sugestao="$(grep -c '<option value="clientes">' "$W/corpo")"
auditoria; n_depois="$(eventos pasta_criada)"; registro="$(grep -c " evento=pasta_criada admin=$ADMIN pasta=clientes/olt-01\$" "$W/auditoria")"
atividade="$(aba -b "$J" "$B/atividade")"; na_atividade="$(grep -c 'Pasta criada' "$W/corpo")"
[[ "$e_pastas" == 303 && "$raiz" == "200 " && "$formulario" == 1 && "$r_1" == "303 /arquivos?pasta=&m=criada" && "$r_2" == "303 /arquivos?pasta=clientes&m=criada" \
  && "$d_1" == "ftpdata:ftpdata 750 directory" && "$d_2" == "ftpdata:ftpdata 750 directory" && "$depois" == "200 " && "$aviso" -ge 1 && "$na_lista" == 1 \
  && "$dentro" == "200 " && "$atalho" == 1 && "$tela" == "200 " && "$preenchido" == 1 && "$sugestao" == 1 \
  && "$n_depois" == $((n_antes + 2)) && "$registro" == 1 && "$atividade" == "200 " && "$na_atividade" -ge 1 ]]
caso $? testes 26 "Pasta criada pelo painel" "formulário Nova pasta na aba Arquivos: $formulario · criar 'clientes' na raiz: $r_1 · criar 'olt-01' dentro dela: $r_2 · no disco, clientes: $d_1; clientes/olt-01: $d_2 · a pasta de cima abre com o aviso ($aviso) e a pasta nova na lista ($na_lista) · na pasta nova, o botão de novo usuário nesta pasta: $atalho; o formulário de usuário abre com a pasta preenchida: $preenchido e a pasta do primeiro nível entre as sugestões: $sugestao · pasta_criada na auditoria: $n_antes → $n_depois, com administrador e caminho: $registro · na aba Atividade: $na_atividade"

# ------------------------------------------------------------------ pasta escolhida e pasta dividida
r_a="$(novo_usuario olt13a clientes/olt-01 "$W/u13a.senha")"; r_b="$(novo_usuario olt13b clientes/olt-01 "$W/u13b.senha")"; r_e="$(novo_usuario eq13e '' "$W/u13e.senha")"
mu add cli13c "$W/u13c.senha" clientes/olt-02/diario; r_c=$?; d_c="$(dono clientes/olt-02/diario)"; d_c1="$(dono clientes/olt-02)"
mu add cli13d "$W/u13d.senha" clientes; r_d=$?; avisos="$(grep -c '^Aviso: /data/clientes e dividida com o usuario ' "$W/mu.log")"
mu add tmp13 "$W/u13e.senha" clientes/olt-03; mu del tmp13; r_del=$?; removido="$(grep -c 'os dados em /data/clientes/olt-03 foram preservados' "$W/mu.log")"
p_a="$(pasta_de olt13a)"; p_b="$(pasta_de olt13b)"; p_c="$(pasta_de cli13c)"; p_d="$(pasta_de cli13d)"; p_e="$(pasta_de eq13e)"
r_envio="$(ftp_curl tls olt13a "$W/u13a.senha" -T "$W/envio.bin" "$F/dividido.cfg")"
r_outro="$(ftp_curl tls olt13b "$W/u13b.senha" -o "$W/dividido.baixado" "$F/dividido.cfg")"
docker exec "$FTP" test -f /data/clientes/olt-01/dividido.cfg; no_disco=$?
r_web="$(c -b "$J" -o "$W/dividido.web" -w '%{http_code}' "$B/arquivos/baixar?arquivo=clientes/olt-01/dividido.cfg")"
lista="$(aba -b "$J" "$B/usuarios")"; divididas="$(grep -o 'class="etiqueta" title="Também alcançada por' "$W/corpo" | wc -l)"
link_a="$(grep -o 'href="/arquivos?pasta=clientes/olt-01"' "$W/corpo" | wc -l)"; link_e="$(grep -c 'href="/arquivos?pasta=eq13e"' "$W/corpo")"
remover="$(aba -b "$J" "$B/usuarios/remover?usuario=olt13a")"; na_remocao="$(grep -c 'clientes/olt-01' "$W/corpo")"; quem_mais="$(grep -c 'também é alcançada por' "$W/corpo")"
da_pasta="$(aba -b "$J" "$B/arquivos?pasta=clientes/olt-01")"; donos="$(grep -c 'Pasta do usuário do FTP: <strong>olt13a, olt13b</strong>' "$W/corpo")"
auditoria; registro="$(grep -c " evento=usuario_criado admin=$ADMIN usuario=olt13a credencial=informada pasta=clientes/olt-01\$" "$W/auditoria")"
registro_e="$(grep -c " evento=usuario_criado admin=$ADMIN usuario=eq13e credencial=informada pasta=eq13e\$" "$W/auditoria")"
[[ "$r_a" == "303 /usuarios?m=criado" && "$r_b" == "303 /usuarios?m=criado" && "$r_e" == "303 /usuarios?m=criado" && "$r_c" == 0 && "$r_d" == 0 && "$avisos" == 3 && "$r_del" == 0 && "$removido" == 1 \
  && "$d_c" == "ftpdata:ftpdata 750 directory" && "$d_c1" == "ftpdata:ftpdata 750 directory" \
  && "$p_a" == /data/clientes/olt-01/./ && "$p_b" == /data/clientes/olt-01/./ && "$p_c" == /data/clientes/olt-02/diario/./ && "$p_d" == /data/clientes/./ && "$p_e" == /data/eq13e/./ \
  && "$r_envio" == 0 && "$r_outro" == 0 && "$no_disco" == 0 && "$r_web" == 200 ]] && cmp -s "$W/envio.bin" "$W/dividido.baixado" && cmp -s "$W/envio.bin" "$W/dividido.web" \
  && [[ "$lista" == "200 " && "$divididas" == 4 && "$link_a" == 2 && "$link_e" == 1 && "$remover" == "200 " && "$na_remocao" -ge 1 && "$quem_mais" == 1 \
  && "$da_pasta" == "200 " && "$donos" == 1 && "$registro" == 1 && "$registro_e" == 1 ]]
caso $? testes 27 "Pasta escolhida e pasta dividida" "pelo painel, olt13a e olt13b na pasta clientes/olt-01: $r_a e $r_b · usuário sem pasta informada (eq13e): $r_e, pasta no cadastro: $p_e · pela linha de comando, cli13c em clientes/olt-02/diario (saída $r_c; níveis criados: $d_c1 e $d_c) e cli13d em clientes (saída $r_d, avisos de pasta dividida: $avisos); a remoção de um usuário de clientes/olt-03 informa a pasta real: $removido · pasta no cadastro: olt13a $p_a, olt13b $p_b, cli13c $p_c, cli13d $p_d · olt13a envia por FTPS (saída $r_envio), olt13b baixa o mesmo arquivo (saída $r_outro, $(cmp -s "$W/envio.bin" "$W/dividido.baixado" && echo idêntico || echo DIFERENTE)), o painel entrega de clientes/olt-01 ($r_web, $(cmp -s "$W/envio.bin" "$W/dividido.web" && echo idêntico || echo DIFERENTE)) · aba Usuários: $divididas pastas marcadas como dividida, link para a pasta real: $link_a (olt13a e olt13b) e $link_e (eq13e) · tela de remoção mostra a pasta real ($na_remocao) e quem mais a alcança ($quem_mais) · aba Arquivos mostra de quem é a pasta: $donos · usuario_criado com a pasta na auditoria: $registro e $registro_e"

# ------------------------------------------------------------------ criar pasta sem sessão e sem token
antes="$(arvore)"; auditoria; n_antes="$(eventos recusa_csrf)"; o_antes="$(eventos recusa_origem)"
campos=(--data-urlencode 'pasta=clientes' --data-urlencode 'nome=sem-sessao')
r_sem="$(c -o /dev/null -w '%{http_code} %{redirect_url}' -H "Origin: $B" --data-urlencode "csrf=$K" "${campos[@]}" "$B/arquivos/pasta" | sed "s|$B||")"
r_falso="$(c -o /dev/null -w '%{http_code} %{redirect_url}' -b '__Host-sessao=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' -H "Origin: $B" --data-urlencode "csrf=$K" "${campos[@]}" "$B/arquivos/pasta" | sed "s|$B||")"
r_token="$(envio /arquivos/pasta "${campos[@]}")"
r_errado="$(envio /arquivos/pasta --data-urlencode 'csrf=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' "${campos[@]}")"
r_origem="$(c -o /dev/null -w '%{http_code}' -b "$J" -H 'Origin: https://site-de-fora.example' --data-urlencode "csrf=$K" "${campos[@]}" "$B/arquivos/pasta")"
r_get="$(aba -b "$J" "$B/arquivos/pasta?pasta=clientes&nome=sem-sessao")"
auditoria; n_depois="$(eventos recusa_csrf)"; o_depois="$(eventos recusa_origem)"; depois="$(arvore)"
[[ "$r_sem" == "303 /entrar" && "$r_falso" == "303 /entrar" && "$r_token" == "403 " && "$r_errado" == "403 " && "$r_origem" == 403 && "$r_get" == "404 " \
  && "$antes" == "$depois" && "$n_depois" -gt "$n_antes" && "$o_depois" -gt "$o_antes" ]]
caso $? seguranca 57 "Criar pasta sem sessão e sem token" "POST /arquivos/pasta sem cookie: $r_sem · com cookie de sessão inventado: $r_falso · com sessão e sem o token: $r_token· com token errado: $r_errado· com o token certo e Origin de fora: $r_origem · GET no mesmo endereço, com sessão: $r_get(só POST existe) · pastas dos dados e do cadastro $([[ "$antes" == "$depois" ]] && echo inalteradas || echo ALTERADAS) · recusa_csrf na auditoria: $n_antes → $n_depois · recusa_origem: $o_antes → $o_depois"

# ------------------------------------------------------------------ nome de pasta que tenta sair
docker exec "$FTP" sh -c 'ln -s /auth /data/clientes/atalho && printf x > /data/clientes/olt-01/arquivo.cfg'; r_ln=$?
antes="$(arvore)"; auditoria; n_antes="$(eventos recusa_caminho)"; ev=""; ok=0
longo="$(printf 'a%.0s' $(seq 1 65))"
for nome in '..' '.' '../auth' 'a/b' '/etc' '.oculta' '' 'com espaço' 'ação' "$longo"; do
  r="$(cria clientes "$nome")"; [[ "$r" == "400 " ]] || ok=1; ev+="'${nome:0:12}': $r; "
done
r_nulo="$(envio /arquivos/pasta --data "csrf=$K&pasta=clientes&nome=a%00b")"; [[ "$r_nulo" == "400 " ]] || ok=1
ev_pai=""
for pai in '..' 'clientes/../..' '/etc' 'clientes//olt-01' './clientes'; do
  r="$(cria "$pai" nova)"; [[ "$r" == "400 " ]] || ok=1; ev_pai+="'$pai': $r; "
done
r_link="$(cria clientes/atalho nova)"; r_falta="$(cria clientes/nao-existe nova)"
r_repetida="$(cria clientes olt-01)"; r_arquivo="$(cria clientes/olt-01 arquivo.cfg)"; r_sobre_link="$(cria clientes atalho)"
auditoria; n_depois="$(eventos recusa_caminho)"; depois="$(arvore)"
[[ "$r_ln" == 0 && "$r_link" == "403 " && "$r_falta" == "404 " && "$r_repetida" == "409 " && "$r_arquivo" == "409 " && "$r_sobre_link" == "409 " \
  && "$antes" == "$depois" && "$n_depois" -gt "$n_antes" ]] || ok=1
caso $ok seguranca 58 "Nome de pasta que tenta sair" "com sessão e token válidos, nome recusado: ${ev}com byte nulo: $r_nulo· pasta de cima recusada: ${ev_pai}por link simbólico para /auth: $r_link· que não existe: $r_falta· nome de pasta que já existe: $r_repetida· nome de arquivo que já existe: $r_arquivo· nome de um link simbólico: $r_sobre_link· pastas dos dados e do cadastro $([[ "$antes" == "$depois" ]] && echo inalteradas || echo ALTERADAS) · recusa_caminho na auditoria: $n_antes → $n_depois"

# ------------------------------------------------------------------ usuário preso à pasta escolhida
r_segredo="$(ftp_curl tls cli13c "$W/u13c.senha" -T "$W/envio.bin" "$F/reservado.cfg")"
r_pwd="$(ftp_curl tls olt13a "$W/u13a.senha" -Q "CWD .." -Q "CWD ../../.." -Q PWD "$F/")"; pwd_ftp="$(resposta 257)"
r_l="$(ftp_curl tls olt13a "$W/u13a.senha" -l "$F/")"; ve="$(grep -c -E 'olt-02|reservado' "$W/curl.out")"
r_c1="$(ftp_curl tls olt13a "$W/u13a.senha" -Q "CWD /data/clientes/olt-02" "$F/")"; resp_c1="$(resposta 5)"
r_c2="$(ftp_curl tls olt13a "$W/u13a.senha" --path-as-is -o "$W/alheio" "$F/../olt-02/diario/reservado.cfg")"
r_c3="$(ftp_curl tls olt13a "$W/u13a.senha" --path-as-is -o "$W/passwd13" "$F/../../../auth/pureftpd.passwd")"
r_cima="$(ftp_curl tls cli13d "$W/u13d.senha" -o "$W/de-cima" "$F/olt-02/diario/reservado.cfg")"
antes="$(arvore)"; usuarios_antes="$(usuarios_ftp)"; ev=""; ok=0
for pasta in '../auth' '/etc' 'clientes/../../auth' 'clientes//olt-01' '.oculta' 'a/b/c/d/e' 'clientes/atalho' 'clientes/atalho/nova' 'clientes/olt-01/arquivo.cfg' 'com espaço'; do
  r="$(novo_usuario inv13 "$pasta" "$W/u13e.senha")"; [[ "$r" == "400 " ]] || ok=1; ev+="'$pasta': $r; "
done
ev_cmd=""
for pasta in '../auth' '/etc' 'clientes/../../auth' '.oculta' 'a/b/c/d/e' 'clientes/atalho' 'clientes/atalho/nova' 'clientes/olt-01/arquivo.cfg'; do
  mu add inv13 "$W/u13e.senha" "$pasta"; r=$?; [[ "$r" != 0 ]] && grep -q -E '^Pasta (invalida|recusada)' "$W/mu.log" || ok=1; ev_cmd+="'$pasta': saída $r; "
done
mu add olt13a "$W/u13e.senha" pasta-de-quem-ja-existe; r_existe=$?; ja_existe="$(grep -c '^Usuario ja existe' "$W/mu.log")"
depois="$(arvore)"
[[ "$r_segredo" == 0 && "$r_pwd" == 0 && "$pwd_ftp" == '257 "/"'* && "$r_l" == 0 && "$ve" == 0 && "$r_c1" != 0 && "$r_c2" != 0 && ! -s "$W/alheio" && "$r_c3" != 0 && ! -s "$W/passwd13" \
  && "$r_cima" == 0 && "$antes" == "$depois" && "$usuarios_antes" == "$(usuarios_ftp)" && "$r_existe" != 0 && "$ja_existe" == 1 ]] && cmp -s "$W/envio.bin" "$W/de-cima" || ok=1
caso $ok seguranca 59 "Usuário preso à pasta escolhida" "olt13a (pasta clientes/olt-01) depois de CWD .. e CWD ../../..: $pwd_ftp · lista a própria pasta: saída $r_l, pasta ou arquivo do cli13c à vista: $ve · CWD /data/clientes/olt-02: curl saída $r_c1 ($resp_c1) · baixar ../olt-02/diario/reservado.cfg: saída $r_c2, arquivo recebido: $([[ -s "$W/alheio" ]] && echo SIM || echo não) · baixar ../../../auth/pureftpd.passwd: saída $r_c3, recebido: $([[ -s "$W/passwd13" ]] && echo SIM || echo não) · cli13d, com a pasta de cima (clientes), alcança o arquivo do cli13c: saída $r_cima, como a marca de pasta dividida avisa · pasta de usuário recusada no painel: ${ev}· na linha de comando: ${ev_cmd}· usuário que já existe, com outra pasta: saída $r_existe · usuários $([[ "$usuarios_antes" == "$(usuarios_ftp)" ]] && echo inalterados || echo ALTERADOS) · pastas dos dados e do cadastro $([[ "$antes" == "$depois" ]] && echo inalteradas || echo ALTERADAS)"

docker exec "$FTP" rm -f /data/clientes/atalho /data/clientes/olt-01/arquivo.cfg
for nome in olt13a olt13b cli13c cli13d eq13e; do mu del "$nome"; done
