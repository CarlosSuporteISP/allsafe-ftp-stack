#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa S: licença e autoria. O LICENSE é o texto oficial da Apache-2.0, o NOTICE traz a autoria, o MARCA.md
# traz o pedido sobre a marca, todo arquivo de código diz a licença dele e as três imagens levam o LICENSE e o NOTICE.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

painel_de_pe
APACHE2=cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30   # sha256 do texto oficial da Apache-2.0
soma="$(sha256sum LICENSE 2>/dev/null | cut -c1-64)"; oficial=NÃO; [[ "$soma" == "$APACHE2" ]] && oficial=sim
autoria="$(grep -c -F 'Desenvolvido pela allsafe.inf.br' NOTICE 2>/dev/null)"; github="$(grep -c -F 'https://github.com/allsafe-inf' NOTICE 2>/dev/null)"
cita_marca="$(grep -c -F 'MARCA.md' NOTICE 2>/dev/null)"
regras=0
for trecho in 'Uso próprio' 'Contrato ou venda para terceiros' 'um pedido só' '](LICENSE)' '](NOTICE)'; do
  grep -q -F -- "$trecho" MARCA.md 2>/dev/null && regras=$((regras + 1))
done
codigo=0; sem=""
for arquivo in Dockerfile compose.yaml deploy.sh manage-user.sh scripts/*.sh ftp/*.sh painel/*.sh painel/*.py nginx/*.sh nginx/*.conf \
  nginx/*.modelo web/*.css tests/*.sh tests/etapas/*.sh; do
  codigo=$((codigo + 1)); head -n 2 "$arquivo" | grep -q -F 'SPDX-License-Identifier: Apache-2.0' || sem+="$arquivo "
done
ev=""; ok=0
for n in "$FTP" "$PAINEL" "$NGINX"; do
  l=NÃO; docker exec "$n" cat /usr/share/doc/allsafe-ftp-stack/LICENSE 2>/dev/null | cmp -s - LICENSE && l=sim
  a=NÃO; docker exec "$n" cat /usr/share/doc/allsafe-ftp-stack/NOTICE 2>/dev/null | cmp -s - NOTICE && a=sim
  dono="$(docker exec "$n" stat -c '%U:%G %a' /usr/share/doc/allsafe-ftp-stack/LICENSE /usr/share/doc/allsafe-ftp-stack/NOTICE 2>/dev/null | sort -u | tr '\n' ' ')"
  [[ "$l" == sim && "$a" == sim && "$dono" == "root:root 644 " ]] || ok=1
  ev+="$n: LICENSE igual ao do projeto: $l, NOTICE igual: $a, dono e modo: $dono· "
done
fonte="$(docker exec "$NGINX" sh -c 'ls /usr/share/allsafe-nginx/web/marca/fonte 2>/dev/null | wc -l')"
r_lic="$(c -o /dev/null -w '%{http_code} %{redirect_url}' --path-as-is "$B/LICENSE" | sed "s|$B||")"
[[ "$oficial" == sim && "$autoria" -ge 1 && "$github" -ge 1 && "$cita_marca" -ge 1 && "$regras" == 5 && "$codigo" -ge 50 && -z "$sem" && "$ok" == 0 \
  && "$fonte" == 0 && "$r_lic" == "303 /entrar" ]]
caso $? testes 39 "Licença e autoria no projeto e nas três imagens" "LICENSE com o sha256 do texto oficial da Apache-2.0: $oficial · NOTICE: linha de autoria: $autoria, endereço do GitHub: $github, cita o MARCA.md: $cita_marca · MARCA.md com o pedido (uso próprio, contrato ou venda para terceiros, um pedido só, ligação para o LICENSE e o NOTICE): $regras de 5 · arquivos de código conferidos: $codigo, sem a linha SPDX-License-Identifier: Apache-2.0 no começo: ${sem:-nenhum} · ${ev}artes de origem da marca na imagem do nginx: $fonte · GET /LICENSE pelo painel, sem sessão: $r_lic (os dois arquivos ficam na imagem, não são publicados na web)"
