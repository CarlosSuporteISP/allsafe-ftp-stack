# 🎚️ Capacity profiles — allsafe-ftp-stack

🌐 **English** · [Português (Brasil)](../pt-BR/perfis.md)

↩ [Project README](../../README.md) · [Documentation index](README.md)

## 💡 In a few words

A profile is a ready-made server size. There are five, from small to extended: `small`, `medium`, `large`, `xlarge` and `extended`. You choose the size when starting the stack and the profile adjusts by itself how many devices can connect at the same time and how much CPU and memory the server can use. The `.env` keeps what belongs to the customer (IPs, ports, certificate); the profile keeps only the sizing, which `deploy.sh` writes to the `.env` when you choose the size. Before writing, it checks whether the server can handle the size requested.

<!-- diagrama: diagrams/configuration-diagram.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    perfil@{ shape: doc, label: "profiles/medium.env<br>profile limits" }
    deploy@{ shape: console, label: "deploy.sh --size medium<br>writes the limits to the .env" }
    env@{ shape: doc, label: ".env<br>environment and limits" }
    compose@{ shape: rect, label: "Docker Compose<br>reads only the .env" }
    ftp@{ shape: rect, label: "Pure-FTPd<br>allsafe-ftp" }
    fim@{ shape: stadium, label: "limits applied" }

    perfil --> deploy --> env --> compose --> ftp --> fim
```
<sub>Level 1 · Diagram · [source](diagrams/)</sub>

**Sequence:** `profiles/medium.env` ➜ `deploy.sh --size medium` (writes the limits to the `.env`) ➜ `.env` ➜ Docker Compose ➜ Pure-FTPd (`allsafe-ftp`) ➜ limits applied

---

<details>
<summary>Contents — click to expand</summary>

[How to use](#como-usar) · [Table of profiles](#tabela-de-perfis) · [Can the server handle it?](#o-servidor-aguenta) · [Sized fields](#campos-dimensionados) · [Startup time](#tempo-de-subida) · [Passive range and firewall](#faixa-passiva-e-firewall)

</details>

---

<a name="como-usar"></a>

## 🚀 How to use

Pass the name of the profile in `--size` to [`deploy.sh`](../../deploy.sh). It writes the limits of the profile to the `.env`, with the name in `FTP_PROFILE`, and reapplies the stack. The installation is born with `small`; without `--size`, the profile in use stays in effect:

```bash
./deploy.sh --size medium                 # writes medium to the .env and reapplies
./deploy.sh                               # stays on medium
./deploy.sh --size xlarge --check-only    # only validates xlarge, writes nothing and starts nothing
```

**Expected result:** with `--check-only`, the message `OK: perfil 'xlarge', rede privada, recursos do servidor e compose validados; nada foi alterado.`; without it, the summary `Pronto: FTP, painel e nginx no ar (healthy), perfil 'medium'.` with the new passive range.

---

<a name="tabela-de-perfis"></a>

## 📐 Table of profiles

| Profile | Reference host | Simultaneous sessions | Typical use |
|---|---|---|---|
| [`small`](../../profiles/small.env) | 2 vCPU · 2 GB · SSD | up to ~50 (`FTP_MAX_CLIENTS=50`) | small or medium provider; configuration backup is small and sporadic traffic: **covers most cases** |
| [`medium`](../../profiles/medium.env) | 4 vCPU · 4 GB · SSD | up to ~120 | nightly batch collection of ~50 to ~200 devices |
| [`large`](../../profiles/large.env) | 8 vCPU · 8 GB · NVMe | up to ~300 | more than 200 devices or several collectors pushing backups at the same time |
| [`xlarge`](../../profiles/xlarge.env) | 16 vCPU · 16 GB · NVMe | up to ~600 | large operation, with several regions or several collectors on the same server |
| [`extended`](../../profiles/extended.env) | 32 vCPU · 32 GB · NVMe | up to ~1200 | the largest size: dedicated server, thousands of devices uploading in short windows |

The numbers are **starting points**, not a guarantee of capacity. A backup FTP rarely needs more than `small`; move up a profile only if you see `421 Too many connections` or CPU or memory saturation in the container. The five profiles exist so that the same stack serves on any machine, from the small VPS to the dedicated server.

<details>
<summary>Technical detail — the values of each profile</summary>

| Field | `small` | `medium` | `large` | `xlarge` | `extended` |
|---|---|---|---|---|---|
| `FTP_MAX_CLIENTS` | `50` | `120` | `300` | `600` | `1200` |
| `FTP_MAX_CLIENTS_PER_IP` | `8` | `12` | `24` | `48` | `96` |
| `FTP_PASSIVE_PORT_START` | `30000` | `30000` | `30000` | `30000` | `30000` |
| `FTP_PASSIVE_PORT_END` | `30049` | `30149` | `30399` | `30799` | `31599` |
| Passive ports | 50 | 150 | 400 | 800 | 1600 |
| `FTP_MEMORY_LIMIT` | `256M` | `512M` | `1G` | `2G` | `4G` |
| `FTP_CPU_LIMIT` | `1.0` | `2.0` | `4.0` | `8.0` | `16.0` |
| `FTP_PIDS_LIMIT` | `128` | `256` | `512` | `1024` | `2048` |
| `FTP_NOFILE` | `16384` | `32768` | `65536` | `131072` | `262144` |

`deploy.sh --size <profile>` copies each `KEY=VALUE` from `profiles/<profile>.env` to the `.env` (it replaces the line of the key or adds it at the end) and writes `FTP_PROFILE=<profile>`. Compose reads only the `.env`: the limits also hold for a direct `docker compose up -d`. Changing the profile recreates the FTP container, because the published port range changes; the data stays. The profiles do not touch the panel or nginx: their limits are the same at any size.

> Installed with `--size medium` or `large` before version `0.4.0`? Run `./deploy.sh --size <profile>` once to write the profile to the `.env`.

</details>

---

<a name="o-servidor-aguenta"></a>

## 🧮 Can the server handle it?

Before creating or changing the `.env`, `deploy.sh` compares what the profile asks for with what the server has. If the server has fewer CPUs than `FTP_CPU_LIMIT` or less memory than `FTP_MEMORY_LIMIT`, the command stops and **nothing is changed**: the `.env` stays as it was and the containers stay up.

```bash
./deploy.sh --size extended --check-only
```

**Expected result**, on a server with 4 CPUs: `ERRO: o perfil 'extended' pede 16.0 CPUs (FTP_CPU_LIMIT) e este servidor tem 4. Use um perfil menor com --size ou ajuste FTP_CPU_LIMIT em .env.` For memory, the message is the same, with `FTP_MEMORY_LIMIT` and the total of the server in MiB.

| Profile | The server needs to have, at least |
|---|---|
| `small` | 1 CPU · 256 MB |
| `medium` | 2 CPUs · 512 MB |
| `large` | 4 CPUs · 1 GB |
| `xlarge` | 8 CPUs · 2 GB |
| `extended` | 16 CPUs · 4 GB |

That minimum is only what the FTP container can take. The reference host of the [table of profiles](#tabela-de-perfis) has twice as much, to leave room for the system, the panel, nginx and the disk.

---

<a name="campos-dimensionados"></a>

## 🎛️ Sized fields

| Field | Effect |
|---|---|
| `FTP_MAX_CLIENTS` | option `-c` of `pure-ftpd`: ceiling of simultaneous connections. It is also the option `-C` of `pure-pw`, which sets the cost of the stored password: [Security](../pt-BR/seguranca.md#custo-das-senhas) |
| `FTP_MAX_CLIENTS_PER_IP` | option `-C`: ceiling per source IP |
| `FTP_PASSIVE_PORT_START` and `FTP_PASSIVE_PORT_END` | range of data ports (passive mode), published **1:1** on the host |
| `FTP_MEMORY_LIMIT` and `FTP_CPU_LIMIT` | `mem_limit` (without swap) and `cpus` of the service |
| `FTP_PIDS_LIMIT` | `pids_limit` (barrier against a _fork bomb_) |
| `FTP_NOFILE` | `ulimit nofile` (soft equal to hard) |

Full description of each variable in [Configuration](configuration.md).

---

<a name="tempo-de-subida"></a>

## ⏱️ Startup time

Docker publishes the passive ports one by one. On the large profiles, starting, changing the profile and removing take minutes, not seconds. `deploy.sh` warns (`Publicando 1600 portas passivas: a subida pode levar alguns minutos.`) and waits a time proportional to the number of ports before giving up.

| Profile | Passive ports | Maximum wait of `deploy.sh` |
|---|---|---|
| `small` | 50 | 192 s |
| `medium` | 150 | 217 s |
| `large` | 400 | 280 s |
| `xlarge` | 800 | 380 s |
| `extended` | 1600 | 580 s |

The maximum wait is 180 s plus a quarter of a second per passive port. At the gate of version `0.5.0`, on a host with 16 CPUs, the installation of `small` finished in 25 s and the change to `extended` in about 200 s; your time varies with the machine. Going back from `extended` to a smaller profile or removing the stack also takes minutes, because Docker undoes the same ports one by one. Schedule the change of profile outside the backup window.

---

<a name="faixa-passiva-e-firewall"></a>

## ⚠️ Passive range and firewall

Each profile widens the passive range together with `FTP_MAX_CLIENTS` (`small` 50 ports, `medium` 150, `large` 400, `xlarge` 800, `extended` 1600). When changing the profile:

1. allow the new range, from `30000` to the end of the profile, in TCP, in the host firewall, only for the management subnets;
2. if there is NAT, make sure of the **1:1** mapping of the whole range;
3. keep `FTP_PASSIVE_IP` with the IP that the client really reaches.

**Expected result:** after `./deploy.sh --size <profile>`, `docker compose ps` shows the new range published.

> ⚠️ Do not put IPs, credentials or customer particulars in the profile files: that belongs to the local `.env` and `.secrets/` folder. See [Secrets](secrets.md).

---

⬅️ [Configuration](configuration.md) · 🏠 [Documentation](README.md) · ➡️ [Architecture](architecture.md)
