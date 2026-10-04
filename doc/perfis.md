# 🎚️ Perfis de capacidade — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [📚 Índice da documentação](README.md)

## 💡 Em poucas palavras

Um perfil é um tamanho pronto de servidor: pequeno, médio ou grande. Você escolhe o tamanho na hora de subir e o perfil ajusta sozinho quantos equipamentos podem conectar ao mesmo tempo e quanto de CPU e memória o servidor pode usar. O `.env` guarda o que é do cliente (IPs, portas, certificado); o perfil guarda só o dimensionamento.

<!-- diagrama: diagramas/configuracao-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    env@{ shape: doc, label: "📄 .env<br>valores do ambiente" }
    perfil@{ shape: doc, label: "🎚️ profiles/small.env<br>limites do perfil" }
    compose@{ shape: rect, label: "🐳 Docker Compose<br>junta os dois" }
    ftp@{ shape: rect, label: "⚙️ Pure-FTPd<br>allsafe-ftp" }
    fim@{ shape: stadium, label: "🏁 limites aplicados" }

    env --> perfil --> compose --> ftp --> fim
```

<sub>📐 Nível 1 · Diagrama · 🔍 aproximar e mover: controles no canto do diagrama · 📁 [fonte](diagramas/)</sub>

**🧭 Sequência:** 📄 `.env` ➜ 🎚️ `profiles/small.env` ➜ 🐳 Docker Compose ➜ ⚙️ Pure-FTPd (`allsafe-ftp`) ➜ 🏁 limites aplicados

---

<details>
<summary>🧭 Sumário — clique para expandir</summary>

[🚀 Como usar](#como-usar) · [📐 Tabela de perfis](#tabela-de-perfis) · [🎛️ Campos dimensionados](#campos-dimensionados) · [⚠️ Faixa passiva e firewall](#faixa-passiva-e-firewall)

</details>

---

<a name="como-usar"></a>

## 🚀 Como usar

Passe o nome do perfil em `--size` para o [`deploy.sh`](../deploy.sh) (padrão: `small`):

```bash
./deploy.sh --size medium                 # sobe com profiles/medium.env
./deploy.sh --size large --check-only     # só valida, não sobe nada
```

**Resultado esperado:** com `--check-only`, a mensagem `OK: perfil 'large' e compose validados; nada foi alterado.`; sem ele, a tabela do `docker compose ps`.

---

<a name="tabela-de-perfis"></a>

## 📐 Tabela de perfis

| Perfil | Host de referência | Sessões simultâneas | Uso típico |
|---|---|---|---|
| [`small`](../profiles/small.env) | 2 vCPU · 2 GB · SSD | até ~50 (`FTP_MAX_CLIENTS=50`) | provedor pequeno ou médio; backup de configuração é tráfego pequeno e esporádico: **cobre a maioria dos casos** |
| [`medium`](../profiles/medium.env) | 4 vCPU · 4 GB · SSD | até ~120 | coleta noturna em lote de ~50 a ~200 equipamentos |
| [`large`](../profiles/large.env) | 8 vCPU · 8 GB · NVMe | até ~300 | mais de 200 equipamentos ou vários coletores empurrando backup ao mesmo tempo |

Os números são **pontos de partida**, não garantia de capacidade. FTP de backup raramente precisa de mais que `small`; suba de perfil só se vir `421 Too many connections` ou saturação de CPU ou memória do container.

<details>
<summary>🔬 Detalhe técnico — os valores de cada perfil</summary>

| Campo | `small` | `medium` | `large` |
|---|---|---|---|
| `FTP_MAX_CLIENTS` | `50` | `120` | `300` |
| `FTP_MAX_CLIENTS_PER_IP` | `8` | `12` | `24` |
| `FTP_PASSIVE_PORT_START` | `30000` | `30000` | `30000` |
| `FTP_PASSIVE_PORT_END` | `30049` | `30149` | `30399` |
| `FTP_MEMORY_LIMIT` | `256M` | `512M` | `1G` |
| `FTP_CPU_LIMIT` | `1.0` | `2.0` | `4.0` |
| `FTP_PIDS_LIMIT` | `128` | `256` | `512` |
| `FTP_NOFILE` | `16384` | `32768` | `65536` |

O `deploy.sh` passa os dois arquivos ao Compose, nesta ordem: `--env-file .env --env-file profiles/<perfil>.env`. O último vence, por isso o perfil sobrescreve o `.env`.

</details>

---

<a name="campos-dimensionados"></a>

## 🎛️ Campos dimensionados

| Campo | Efeito |
|---|---|
| `FTP_MAX_CLIENTS` | opção `-c` do `pure-ftpd`: teto de conexões simultâneas |
| `FTP_MAX_CLIENTS_PER_IP` | opção `-C`: teto por IP de origem |
| `FTP_PASSIVE_PORT_START` e `FTP_PASSIVE_PORT_END` | faixa de portas de dados (modo passivo), publicada **1:1** no host |
| `FTP_MEMORY_LIMIT` e `FTP_CPU_LIMIT` | `mem_limit` e `cpus` do serviço |
| `FTP_PIDS_LIMIT` | `pids_limit` (barreira contra _fork bomb_) |
| `FTP_NOFILE` | `ulimit nofile` (soft igual a hard) |

Descrição completa de cada variável em [⚙️ Configuração](configuracao.md).

---

<a name="faixa-passiva-e-firewall"></a>

## ⚠️ Faixa passiva e firewall

Cada perfil amplia a faixa passiva junto com `FTP_MAX_CLIENTS` (`small` 50 portas, `medium` 150, `large` 400). Ao trocar de perfil:

1. libere a nova faixa, de `30000` até o fim do perfil, em TCP, no firewall do host, só para as sub-redes de gerência;
2. se houver NAT, garanta o mapeamento **1:1** da faixa inteira;
3. mantenha `FTP_PUBLIC_IP` com o IP que o cliente realmente alcança.

**Resultado esperado:** depois do `./deploy.sh --size <perfil>`, `docker compose ps` mostra a faixa nova publicada.

> ⚠️ Não coloque IPs, credenciais ou particularidades de cliente nos arquivos de perfil: isso pertence ao `.env` e à pasta `.secrets/` locais. Veja [🔑 Segredos](segredos.md).

---

⬅️ [⚙️ Configuração](configuracao.md) · 🏠 [Documentação](README.md) · ➡️ [🏗️ Arquitetura](arquitetura.md)
