# 🎚️ Perfis de capacidade — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [📚 Índice da documentação](README.md)

## 💡 Em poucas palavras

Um perfil é um tamanho pronto de servidor: pequeno, médio ou grande. Você escolhe o tamanho na hora de subir e o perfil ajusta sozinho quantos equipamentos podem conectar ao mesmo tempo e quanto de CPU e memória o servidor pode usar. O `.env` guarda o que é do cliente (IPs, portas, certificado); o perfil guarda só o dimensionamento, que o `deploy.sh` grava no `.env` quando você escolhe o tamanho.

<!-- diagrama: diagramas/configuracao-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    perfil@{ shape: doc, label: "🎚️ profiles/medium.env<br>limites do perfil" }
    deploy@{ shape: console, label: "⌨️ deploy.sh --size medium<br>grava os limites no .env" }
    env@{ shape: doc, label: "📄 .env<br>ambiente e limites" }
    compose@{ shape: rect, label: "🐳 Docker Compose<br>lê só o .env" }
    ftp@{ shape: rect, label: "⚙️ Pure-FTPd<br>allsafe-ftp" }
    fim@{ shape: stadium, label: "🏁 limites aplicados" }

    perfil --> deploy --> env --> compose --> ftp --> fim
```

<sub>📐 Nível 1 · Diagrama · 🔍 aproximar e mover: controles no canto do diagrama · 📁 [fonte](diagramas/)</sub>

**🧭 Sequência:** 🎚️ `profiles/medium.env` ➜ ⌨️ `deploy.sh --size medium` (grava os limites no `.env`) ➜ 📄 `.env` ➜ 🐳 Docker Compose ➜ ⚙️ Pure-FTPd (`allsafe-ftp`) ➜ 🏁 limites aplicados

---

<details>
<summary>🧭 Sumário — clique para expandir</summary>

[🚀 Como usar](#como-usar) · [📐 Tabela de perfis](#tabela-de-perfis) · [🎛️ Campos dimensionados](#campos-dimensionados) · [⚠️ Faixa passiva e firewall](#faixa-passiva-e-firewall)

</details>

---

<a name="como-usar"></a>

## 🚀 Como usar

Passe o nome do perfil em `--size` para o [`deploy.sh`](../deploy.sh). Ele grava os limites do perfil no `.env`, com o nome em `FTP_PROFILE`, e reaplica a stack. A instalação nasce com o `small`; sem `--size`, o perfil em uso continua valendo:

```bash
./deploy.sh --size medium                 # grava o medium no .env e reaplica
./deploy.sh                               # continua no medium
./deploy.sh --size large --check-only     # só valida o large, não grava nem sobe nada
```

**Resultado esperado:** com `--check-only`, a mensagem `OK: perfil 'large', rede privada e compose validados; nada foi alterado.`; sem ele, o resumo `Pronto: FTP e painel no ar (healthy), perfil 'medium'.` com a faixa passiva nova.

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

O `deploy.sh --size <perfil>` copia cada `CHAVE=VALOR` de `profiles/<perfil>.env` para o `.env` (troca a linha da chave ou acrescenta no fim) e grava `FTP_PROFILE=<perfil>`. O Compose lê só o `.env`: os limites valem também para um `docker compose up -d` direto. Trocar de perfil recria o container do FTP, porque a faixa de portas publicada muda; os dados ficam.

> 📌 Instalou com `--size medium` ou `large` antes da versão `0.4.0`? Rode uma vez `./deploy.sh --size <perfil>` para gravar o perfil no `.env`.

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
