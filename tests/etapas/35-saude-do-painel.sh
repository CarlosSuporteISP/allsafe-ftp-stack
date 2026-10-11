#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Etapa AI: verificação de saúde do painel. O Docker a roda dentro do container a cada 20 s, e ela precisa caber na
# cota de processador de um período: subindo o painel inteiro para fazer um pedido, cada verificação batia no limite
# e somava no contador da aba Servidor sem carga nenhuma.
# Trecho da bateria: carregado pelo tests/testar.sh, na ordem do nome do arquivo; não roda sozinho.

painel_de_pe
t_sau="$(docker inspect -f '{{json .Config.Healthcheck.Test}}' "$PAINEL")"
docker exec "$PAINEL" python3 -I -S /opt/painel/saude.py; r_leve=$?
docker exec "$PAINEL" python3 /opt/painel/servidor.py --saude; r_modo=$?
# Sem o soquete do painel, a mesma verificação reprova: container da mesma imagem, sem rede e sem volume.
docker run --rm --network none --read-only --entrypoint python3 "$(docker inspect -f '{{.Config.Image}}' "$PAINEL")" -I -S /opt/painel/saude.py; r_sem=$?
# <comando...>: processador gasto por uma execução dele dentro do container do painel, em ms, a maior de cinco
gasto35() { docker exec "$PAINEL" python3 -I -S -c 'import resource, subprocess, sys
maior = 0
for _ in range(5):
    antes = resource.getrusage(resource.RUSAGE_CHILDREN)
    subprocess.run(sys.argv[1:])
    depois = resource.getrusage(resource.RUSAGE_CHILDREN)
    maior = max(maior, depois.ru_utime + depois.ru_stime - antes.ru_utime - antes.ru_stime)
print(round(maior * 1000))' "$@"; }
ms_leve="$(gasto35 python3 -I -S /opt/painel/saude.py)"; ms_modo="$(gasto35 python3 /opt/painel/servidor.py --saude)"
read -r cota _ <<< "$(docker exec "$PAINEL" cat /sys/fs/cgroup/cpu.max)"; [[ "$cota" =~ ^[0-9]+$ ]] && cota=$((cota / 1000))
[[ "$t_sau" == '["CMD","python3","-I","-S","/opt/painel/saude.py"]' && "$r_leve" == 0 && "$r_modo" == 0 && "$r_sem" == 1 \
  && "$ms_leve" =~ ^[0-9]+$ && "$cota" =~ ^[0-9]+$ && "$cota" -ge 1 && "$ms_leve" -lt "$cota" ]]
caso $? testes 83 "Verificação de saúde do painel cabe na cota de processador" "healthcheck do container do painel: $t_sau; saude.py com o painel no ar: saída $r_leve; servidor.py --saude: saída $r_modo; saude.py em container da mesma imagem, sem o soquete: saída $r_sem; processador de uma verificação, a maior de cinco: $ms_leve ms pelo saude.py e $ms_modo ms subindo o painel inteiro; cota do container em um período de 100 ms: $cota ms"
