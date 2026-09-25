# 📊 Perfis de capacidade — [`profiles/`](../profiles/)

↩ voltar para [`README.md` (índice)](README.md) · [`../README.md` (projeto)](../README.md)

Os arquivos de [`profiles/`](../profiles/) sobrescrevem os valores gerais de
[`../.env`](../.env.example) durante o deploy. Passe o nome em `--size` para
[`../deploy.sh`](../deploy.sh) (padrão: `small`). O `.env` guarda a configuração
do cliente (IPs, portas, imagem, certificado); o perfil, só o dimensionamento.

```bash
./deploy.sh --size medium          # sobe com profiles/medium.env
./deploy.sh --size large --check-only
```

---

## 🧭 Sumário

[📐 Tabela de perfis](#-tabela-de-perfis) · [🎛️ Campos dimensionados](#️-campos-dimensionados) · [⚠️ Faixa passiva e firewall](#️-faixa-passiva-e-firewall)

---

## 📐 Tabela de perfis

| Perfil | Host de referência | Sessões simultâneas | Uso típico |
|---|---|---|---|
| [`small`](../profiles/small.env) | 2 vCPU · 2 GB · SSD | até ~50 (`FTP_MAX_CLIENTS=50`) | provedor pequeno/médio; backup de config é tráfego pequeno e esporádico — **cobre a maioria dos casos** |
| [`medium`](../profiles/medium.env) | 4 vCPU · 4 GB · SSD | até ~120 | coleta noturna em lote de ~50 a ~200 equipamentos |
| [`large`](../profiles/large.env) | 8 vCPU · 8 GB · NVMe | até ~300 | +200 equipamentos ou vários coletores empurrando backup ao mesmo tempo |

Os números são **pontos de partida**, não garantia de capacidade. FTP de backup
raramente precisa de mais que `small`; suba de perfil só se vir `421 Too many
connections` ou saturação de CPU/memória do container.

---

## 🎛️ Campos dimensionados

| Campo | Efeito |
|---|---|
| `FTP_MAX_CLIENTS` | `-c` do `pure-ftpd` — teto de conexões simultâneas. |
| `FTP_MAX_CLIENTS_PER_IP` | `-C` — teto por IP de origem. |
| `FTP_PASSIVE_PORT_START` / `FTP_PASSIVE_PORT_END` | faixa de portas de dados (modo passivo), publicada **1:1** no host. |
| `FTP_MEMORY_LIMIT` / `FTP_CPU_LIMIT` | `mem_limit` / `cpus` do serviço. |
| `FTP_PIDS_LIMIT` | `pids_limit` (barreira contra _fork bomb_). |
| `FTP_NOFILE` | `ulimit nofile` (soft = hard). |

Descrição completa de cada variável em [`configuracao.md`](configuracao.md).

---

## ⚠️ Faixa passiva e firewall

Cada perfil amplia a faixa passiva junto com `FTP_MAX_CLIENTS` (small 50 portas,
medium 150, large 400). Ao trocar de perfil:

1. libere a nova faixa em `30000-END/tcp` no firewall do host, só para as
   sub-redes de gerência;
2. se houver NAT, garanta o mapeamento **1:1** da faixa inteira;
3. mantenha `FTP_PUBLIC_IP` com o IP que o cliente realmente alcança.

Não coloque IPs, credenciais ou particularidades de cliente nestes arquivos —
isso pertence ao [`../.env`](../.env.example) e à [`../.secrets/`](segredos.md) locais.
