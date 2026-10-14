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
read -r cota periodo <<< "$(docker exec "$PAINEL" cat /sys/fs/cgroup/cpu.max)"; [[ "$cota" =~ ^[0-9]+$ ]] && cota=$((cota / 1000))
[[ "$periodo" =~ ^[0-9]+$ ]] && periodo=$((periodo / 1000))
[[ "$t_sau" == '["CMD","python3","-I","-S","/opt/painel/saude.py"]' && "$r_leve" == 0 && "$r_modo" == 0 && "$r_sem" == 1 \
  && "$ms_leve" =~ ^[0-9]+$ && "$cota" =~ ^[0-9]+$ && "$cota" -ge 1 && "$ms_leve" -lt "$cota" ]]
caso $? testes 83 "Verificação de saúde do painel cabe na cota de processador" "healthcheck do container do painel: $t_sau; saude.py com o painel no ar: saída $r_leve; servidor.py --saude: saída $r_modo; saude.py em container da mesma imagem, sem o soquete: saída $r_sem; processador de uma verificação, a maior de cinco: $ms_leve ms pelo saude.py e $ms_modo ms subindo o painel inteiro; cota do container: $cota ms a cada $periodo ms"

# Cota de processador do painel em períodos de 500 ms, com a mesma média de PAINEL_CPU_LIMIT. A conferência de senha
# gasta uns 65 ms de processador de uma vez: com `cpus: 0.5` (50 ms a cada 100 ms) a cota acabava a cada entrada e a
# linha "Limite de processador atingido" da aba Servidor acusava sem faltar processador.
maximo35() { docker exec "$PAINEL" cat /sys/fs/cgroup/cpu.max 2>/dev/null | tr '\n' ' '; }
# Seis conferências de senha no container do painel, uma a cada 0,3 s, com a senha gerada lá dentro e nunca impressa.
# → "<períodos em que a cota acabou> <processador da conferência mais cara, em ms> <sim|nao: todas conferiram>"
conferir35() { docker exec -i "$PAINEL" python3 -I - <<'PYEOF'
import secrets, sys, time
sys.path.insert(0, '/opt/painel')
import senha


def contido():
    with open('/sys/fs/cgroup/cpu.stat', encoding='ascii') as arq:
        return next(int(linha.split()[1]) for linha in arq if linha.startswith('nr_throttled '))


segredo = secrets.token_urlsafe(24)
guardado = senha.gerar_hash(segredo)
time.sleep(1)
antes, maior, todas = contido(), 0.0, True
for _ in range(6):
    inicio = time.process_time()
    todas = senha.senha_confere(segredo, guardado) and todas
    maior = max(maior, time.process_time() - inicio)
    time.sleep(0.3)
print(contido() - antes, round(maior * 1000), 'sim' if todas else 'nao')
PYEOF
}
cpu_0="$(env_file="$ENVA" env_valor PAINEL_CPU_LIMIT 0.5)"
m_05="$(maximo35)"; q_05="$(grep -c '^PAINEL_CPU_QUOTA=' "$ENVA")"
read -r contidos35 ms_senha35 todas35 <<< "$(conferir35 2> "$W/conferir35.err")"
gravar_env "$ENVA" PAINEL_CPU_LIMIT 1.5; dep; r_15=$?; painel_de_pe; esperar "$PAINEL"
m_15="$(maximo35)"; q_15="$(env_file="$ENVA" env_valor PAINEL_CPU_QUOTA)"
gravar_env "$ENVA" PAINEL_CPU_LIMIT meio; ENV_FILE="$ENVA" ./deploy.sh --check-only < /dev/null > "$W/cota-invalida.log" 2>&1; r_inv=$?
n_inv="$(grep -c '^ERRO: PAINEL_CPU_LIMIT inválido' "$W/cota-invalida.log")"; m_inv="$(maximo35)"
gravar_env "$ENVA" PAINEL_CPU_LIMIT "$cpu_0"; dep; r_05=$?; painel_de_pe; esperar "$PAINEL"
m_fim="$(maximo35)"; q_fim="$(env_file="$ENVA" env_valor PAINEL_CPU_QUOTA)"
[[ "$cpu_0" == 0.5 && "$m_05" == '250000 500000 ' && "$q_05" == 0 && "$contidos35" == 0 && "$ms_senha35" =~ ^[0-9]+$ && "$todas35" == sim \
  && "$r_15" == 0 && "$m_15" == '750000 500000 ' && "$q_15" == 750000 && "$r_inv" != 0 && "$n_inv" == 1 && "$m_inv" == "$m_15" \
  && "$r_05" == 0 && "$m_fim" == '250000 500000 ' && "$q_fim" == 250000 && "$(saude "$FTP" "$PAINEL" "$NGINX")" == "healthy healthy healthy " ]]
caso $? testes 113 "Cota de processador do painel comporta a conferência de senha" "cpu.max do container do painel com PAINEL_CPU_LIMIT=$cpu_0: $m_05(esperado 250000 500000: 250 ms a cada 500 ms), linhas PAINEL_CPU_QUOTA no .env: $q_05; seis conferências de senha, uma a cada 0,3 s: todas conferem: $todas35, a mais cara gastou $ms_senha35 ms de processador, períodos em que a cota acabou: $contidos35; PAINEL_CPU_LIMIT=1.5 e deploy.sh: saída $r_15, cpu.max $m_15(esperado 750000 500000), PAINEL_CPU_QUOTA no .env: $q_15; PAINEL_CPU_LIMIT=meio e deploy.sh --check-only: saída $r_inv, com o erro que diz o que corrigir ($n_inv), container sem mudança; de volta a $cpu_0: saída $r_05, cpu.max $m_fim, PAINEL_CPU_QUOTA no .env: $q_fim; saúde: $(saude "$FTP" "$PAINEL" "$NGINX")"
