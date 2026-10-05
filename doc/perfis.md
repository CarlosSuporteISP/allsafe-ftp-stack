# 🎚️ Perfis de capacidade — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [Índice da documentação](README.md)

## 💡 Em poucas palavras

Um perfil é um tamanho pronto de servidor. São cinco, do pequeno ao estendido: `small`, `medium`, `large`, `xlarge` e `extended`. Você escolhe o tamanho na hora de subir e o perfil ajusta sozinho quantos equipamentos podem conectar ao mesmo tempo e quanto de CPU e memória o servidor pode usar. O `.env` guarda o que é do cliente (IPs, portas, certificado); o perfil guarda só o dimensionamento, que o `deploy.sh` grava no `.env` quando você escolhe o tamanho. Antes de gravar, ele confere se o servidor aguenta o tamanho pedido.

<!-- diagrama: diagramas/configuracao-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    perfil@{ shape: doc, label: "profiles/medium.env<br>limites do perfil" }
    deploy@{ shape: console, label: "deploy.sh --size medium<br>grava os limites no .env" }
    env@{ shape: doc, label: ".env<br>ambiente e limites" }
    compose@{ shape: rect, label: "Docker Compose<br>lê só o .env" }
    ftp@{ shape: rect, label: "Pure-FTPd<br>allsafe-ftp" }
    fim@{ shape: stadium, label: "limites aplicados" }

    perfil --> deploy --> env --> compose --> ftp --> fim
```

<sub>Nível 1 · Diagrama · [fonte](diagramas/)</sub>

**Sequência:** `profiles/medium.env` ➜ `deploy.sh --size medium` (grava os limites no `.env`) ➜ `.env` ➜ Docker Compose ➜ Pure-FTPd (`allsafe-ftp`) ➜ limites aplicados

---

<details>
<summary>Sumário — clique para expandir</summary>

[Como usar](#como-usar) · [Tabela de perfis](#tabela-de-perfis) · [O servidor aguenta?](#o-servidor-aguenta) · [Campos dimensionados](#campos-dimensionados) · [Tempo de subida](#tempo-de-subida) · [Faixa passiva e firewall](#faixa-passiva-e-firewall)

</details>

---

<a name="como-usar"></a>

## 🚀 Como usar

Passe o nome do perfil em `--size` para o [`deploy.sh`](../deploy.sh). Ele grava os limites do perfil no `.env`, com o nome em `FTP_PROFILE`, e reaplica a stack. A instalação nasce com o `small`; sem `--size`, o perfil em uso continua valendo:

```bash
./deploy.sh --size medium                 # grava o medium no .env e reaplica
./deploy.sh                               # continua no medium
./deploy.sh --size xlarge --check-only    # só valida o xlarge, não grava nem sobe nada
```

**Resultado esperado:** com `--check-only`, a mensagem `OK: perfil 'xlarge', rede privada, recursos do servidor e compose validados; nada foi alterado.`; sem ele, o resumo `Pronto: FTP, painel e nginx no ar (healthy), perfil 'medium'.` com a faixa passiva nova.

---

<a name="tabela-de-perfis"></a>

## 📐 Tabela de perfis

| Perfil | Host de referência | Sessões simultâneas | Uso típico |
|---|---|---|---|
| [`small`](../profiles/small.env) | 2 vCPU · 2 GB · SSD | até ~50 (`FTP_MAX_CLIENTS=50`) | provedor pequeno ou médio; backup de configuração é tráfego pequeno e esporádico: **cobre a maioria dos casos** |
| [`medium`](../profiles/medium.env) | 4 vCPU · 4 GB · SSD | até ~120 | coleta noturna em lote de ~50 a ~200 equipamentos |
| [`large`](../profiles/large.env) | 8 vCPU · 8 GB · NVMe | até ~300 | mais de 200 equipamentos ou vários coletores empurrando backup ao mesmo tempo |
| [`xlarge`](../profiles/xlarge.env) | 16 vCPU · 16 GB · NVMe | até ~600 | operação grande, com várias regiões ou vários coletores no mesmo servidor |
| [`extended`](../profiles/extended.env) | 32 vCPU · 32 GB · NVMe | até ~1200 | o maior porte: servidor dedicado, milhares de equipamentos enviando em janelas curtas |

Os números são **pontos de partida**, não garantia de capacidade. FTP de backup raramente precisa de mais que `small`; suba de perfil só se vir `421 Too many connections` ou saturação de CPU ou memória do container. Os cinco perfis existem para a mesma stack servir em qualquer máquina, da VPS pequena ao servidor dedicado.

<details>
<summary>Detalhe técnico — os valores de cada perfil</summary>

| Campo | `small` | `medium` | `large` | `xlarge` | `extended` |
|---|---|---|---|---|---|
| `FTP_MAX_CLIENTS` | `50` | `120` | `300` | `600` | `1200` |
| `FTP_MAX_CLIENTS_PER_IP` | `8` | `12` | `24` | `48` | `96` |
| `FTP_PASSIVE_PORT_START` | `30000` | `30000` | `30000` | `30000` | `30000` |
| `FTP_PASSIVE_PORT_END` | `30049` | `30149` | `30399` | `30799` | `31599` |
| Portas passivas | 50 | 150 | 400 | 800 | 1600 |
| `FTP_MEMORY_LIMIT` | `256M` | `512M` | `1G` | `2G` | `4G` |
| `FTP_CPU_LIMIT` | `1.0` | `2.0` | `4.0` | `8.0` | `16.0` |
| `FTP_PIDS_LIMIT` | `128` | `256` | `512` | `1024` | `2048` |
| `FTP_NOFILE` | `16384` | `32768` | `65536` | `131072` | `262144` |

O `deploy.sh --size <perfil>` copia cada `CHAVE=VALOR` de `profiles/<perfil>.env` para o `.env` (troca a linha da chave ou acrescenta no fim) e grava `FTP_PROFILE=<perfil>`. O Compose lê só o `.env`: os limites valem também para um `docker compose up -d` direto. Trocar de perfil recria o container do FTP, porque a faixa de portas publicada muda; os dados ficam. Os perfis não mexem no painel nem no nginx: os limites deles são os mesmos em qualquer porte.

> Instalou com `--size medium` ou `large` antes da versão `0.4.0`? Rode uma vez `./deploy.sh --size <perfil>` para gravar o perfil no `.env`.

</details>

---

<a name="o-servidor-aguenta"></a>

## 🧮 O servidor aguenta?

Antes de criar ou alterar o `.env`, o `deploy.sh` compara o que o perfil pede com o que o servidor tem. Se o servidor tiver menos CPUs que `FTP_CPU_LIMIT` ou menos memória que `FTP_MEMORY_LIMIT`, o comando para e **nada é alterado**: o `.env` continua como estava e os containers continuam no ar.

```bash
./deploy.sh --size extended --check-only
```

**Resultado esperado**, em um servidor de 4 CPUs: `ERRO: o perfil 'extended' pede 16.0 CPUs (FTP_CPU_LIMIT) e este servidor tem 4. Use um perfil menor com --size ou ajuste FTP_CPU_LIMIT em .env.` Para a memória, a mensagem é a mesma, com `FTP_MEMORY_LIMIT` e o total do servidor em MiB.

| Perfil | O servidor precisa ter, no mínimo |
|---|---|
| `small` | 1 CPU · 256 MB |
| `medium` | 2 CPUs · 512 MB |
| `large` | 4 CPUs · 1 GB |
| `xlarge` | 8 CPUs · 2 GB |
| `extended` | 16 CPUs · 4 GB |

Esse mínimo é só o que o container do FTP pode ocupar. O host de referência da [tabela de perfis](#tabela-de-perfis) tem o dobro, para sobrar para o sistema, o painel, o nginx e o disco.

---

<a name="campos-dimensionados"></a>

## 🎛️ Campos dimensionados

| Campo | Efeito |
|---|---|
| `FTP_MAX_CLIENTS` | opção `-c` do `pure-ftpd`: teto de conexões simultâneas. Também é a opção `-C` do `pure-pw`, que define o custo da senha gravada: [Segurança](seguranca.md#custo-das-senhas) |
| `FTP_MAX_CLIENTS_PER_IP` | opção `-C`: teto por IP de origem |
| `FTP_PASSIVE_PORT_START` e `FTP_PASSIVE_PORT_END` | faixa de portas de dados (modo passivo), publicada **1:1** no host |
| `FTP_MEMORY_LIMIT` e `FTP_CPU_LIMIT` | `mem_limit` e `cpus` do serviço |
| `FTP_PIDS_LIMIT` | `pids_limit` (barreira contra _fork bomb_) |
| `FTP_NOFILE` | `ulimit nofile` (soft igual a hard) |

Descrição completa de cada variável em [Configuração](configuracao.md).

---

<a name="tempo-de-subida"></a>

## ⏱️ Tempo de subida

O Docker publica as portas passivas uma a uma. Nos perfis grandes, subir, trocar de perfil e remover levam minutos, e não segundos. O `deploy.sh` avisa (`Publicando 1600 portas passivas: a subida pode levar alguns minutos.`) e espera o tempo proporcional ao número de portas antes de desistir.

| Perfil | Portas passivas | Espera máxima do `deploy.sh` |
|---|---|---|
| `small` | 50 | 192 s |
| `medium` | 150 | 217 s |
| `large` | 400 | 280 s |
| `xlarge` | 800 | 380 s |
| `extended` | 1600 | 580 s |

A espera máxima é de 180 s mais um quarto de segundo por porta passiva. No portão da versão `0.5.0`, em um host de 16 CPUs, a instalação do `small` terminou em 25 s e a troca para o `extended` em cerca de 200 s; o seu tempo varia com a máquina. Voltar do `extended` para um perfil menor ou remover a stack também leva minutos, porque o Docker desfaz as mesmas portas uma a uma. Programe a troca de perfil para fora da janela de backup.

---

<a name="faixa-passiva-e-firewall"></a>

## ⚠️ Faixa passiva e firewall

Cada perfil amplia a faixa passiva junto com `FTP_MAX_CLIENTS` (`small` 50 portas, `medium` 150, `large` 400, `xlarge` 800, `extended` 1600). Ao trocar de perfil:

1. libere a nova faixa, de `30000` até o fim do perfil, em TCP, no firewall do host, só para as sub-redes de gerência;
2. se houver NAT, garanta o mapeamento **1:1** da faixa inteira;
3. mantenha `FTP_PASSIVE_IP` com o IP que o cliente realmente alcança.

**Resultado esperado:** depois do `./deploy.sh --size <perfil>`, `docker compose ps` mostra a faixa nova publicada.

> ⚠️ Não coloque IPs, credenciais ou particularidades de cliente nos arquivos de perfil: isso pertence ao `.env` e à pasta `.secrets/` locais. Veja [Segredos](segredos.md).

---

⬅️ [Configuração](configuracao.md) · 🏠 [Documentação](README.md) · ➡️ [Arquitetura](arquitetura.md)
