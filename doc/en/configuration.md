# ⚙️ Configuration — allsafe-ftp-stack

🌐 **English** · [Português (Brasil)](../pt-BR/configuracao.md)

↩ [Project README](../../README.md) · [Documentation index](README.md)

## 💡 In a few words

Everything that changes from one installation to another stays in a single file, the `.env`: the IP, the port, the name of the user, the TLS mode and the limits. The size of the server comes from a ready-made profile: when you choose the size, `deploy.sh` writes its capacity numbers to the `.env` itself. Docker Compose reads the `.env` and applies it to the three containers: the FTP, the panel and the nginx that stays in front of the panel.

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

[Minimal production example](#exemplo-minimo-de-producao) · [General](#geral) · [Network and ports](#rede-e-portas) · [Initial user and password](#usuario-inicial-e-senha) · [TLS](#tls) · [Session limits](#limites-de-sessao) · [Web panel](#painel) · [Security contact](#contato-de-seguranca) · [Resource limits of the container](#limites-de-recurso-do-container) · [Docker network](#rede-docker-sub-rede)

</details>

---

<a name="exemplo-minimo-de-producao"></a>

## 🧾 Minimal production example

All the variables live in the `.env`, copied from [`.env.example`](../../.env.example). In the example, the variables come grouped by subject and **each one has, in the line above, a comment saying what it is for**; this guide brings the same, with more detail.

```ini
TZ=America/Sao_Paulo
DATA_DIR=/srv/allsafe-ftp-stack/data
FTP_BIND_IP=192.168.10.20
FTP_PASSIVE_IP=192.168.10.20
FTP_PORT=21
FTP_PASSIVE_PORT_START=30000
FTP_PASSIVE_PORT_END=30049
FTP_USER=backup-rede
FTP_TLS_MODE=2
FTP_CERT_CN=ftp.exemplo.com.br
FTP_MAX_CLIENTS=50
FTP_MAX_CLIENTS_PER_IP=8
FTP_BLOQUEIO_TENTATIVAS=5
FTP_BLOQUEIO_MINUTOS=15
BLOQUEIO_ENDERECO_ERROS=5
BLOQUEIO_ENDERECO_HORAS=24
BLOQUEIO_ENDERECO_DIAS=120
```

No password goes into the `.env`: it stays in `.secrets/ftp-usuario-inicial-senha.txt` ([Secrets](secrets.md)).

After editing the `.env`, validate without starting:

```bash
./deploy.sh --check-only
```

**Expected result:** `OK: perfil 'small', rede privada, recursos do servidor e compose validados; nada foi alterado.` An IP outside the private ranges, a password in the `.env`, an `FTP_TLS_MODE` outside `0` to `3` or a profile larger than the server stop the command with the explanation.

The **Default** column of the tables below is the value of [`.env.example`](../../.env.example). When the variable is missing in the `.env`, [`compose.yaml`](../../compose.yaml) applies the same value, with three exceptions: `FTP_CERT_CN` becomes `localhost`, and `DATA_DIR` and `FTP_PASSIVE_IP` have no default in Compose: without them the command stops with `defina DATA_DIR no .env` or `defina FTP_PASSIVE_IP no .env`.

---

<a name="geral"></a>

## 🌍 General

| Variable | What it is for | Values | Default |
|---|---|---|---|
| `TZ` | Time zone of the container (affects logs and the validity of the certificate) | IANA name, example: `America/Sao_Paulo` | `America/Sao_Paulo` |
| `FTP_IMAGE` | Name and tag of the FTP image, built on the host | `name:tag` | `allsafe-ftp:local` |
| `PAINEL_IMAGE` | Name and tag of the panel image, built on the host | `name:tag` | `allsafe-ftp-painel:local` |
| `NGINX_IMAGE` | Name and tag of the image of the nginx that stays in front of the panel, built on the host | `name:tag` | `allsafe-ftp-nginx:local` |

---

<a name="pastas-e-nomes"></a>

## 📦 Folders and names

| Variable | What it is for | Values | Default |
|---|---|---|---|
| `DATA_DIR` | Folder of the host with the data of the stack: `dados/` (uploaded files), `auth/` (PureDB), `certs/` (TLS of the FTP), `painel/` (certificate and audit log of the panel) and `nginx/` (the socket and the copy of the certificate that nginx reads). Mounted by _bind mount_; the stack creates no named volume | Absolute path | `/srv/allsafe-ftp-stack/data` |
| `BACKUP_DIR` | Folder of the host where `scripts/backup.sh` writes the backup copies, encrypted, and `scripts/restaurar.sh` looks for them. It is born with mode `0700` and has to stay outside `DATA_DIR`: [Backup and restore](backup.md) | Absolute path | `/srv/allsafe-ftp-stack/backups` |
| `TEMP_DIR` | Folder of the host for temporary files: test instance, diagnostic collection | Absolute path | `/srv/allsafe-ftp-stack/tmp` |
| `SECRETS_DIR` | Folder of the secrets, one file per secret, mode `0700`: the initial passwords and the key pair of the backup copy | Absolute path or relative to the project folder | `./.secrets` |
| `STACK_NAME` | Name of the project in Compose | Lowercase letters, numbers and hyphen | `allsafe-ftp-stack` |
| `FTP_CONTAINER_NAME` | Name of the container and of the host of the FTP | Container name | `allsafe-ftp` |
| `PAINEL_CONTAINER_NAME` | Name of the container and of the host of the panel | Container name | `allsafe-ftp-painel` |
| `NGINX_CONTAINER_NAME` | Name of the container and of the host of nginx | Container name | `allsafe-ftp-nginx` |
| `FTP_NETWORK_NAME` | Name of the Docker network of the stack | Network name | `allsafe-ftp-network` |

For a **second instance** on the same host, change the five names, the three images, the folders, the ports (of the FTP and of the panel) and `FTP_SUBNET`. [`deploy.sh`](../../deploy.sh) accepts another file in the place of the `.env`: `ENV_FILE=/caminho/outro.env ./deploy.sh`.

---

<a name="rede-e-portas"></a>

## 🔌 Network and ports

| Variable | What it is for | Values | Default |
|---|---|---|---|
| `REDE_PERMITIR_IP_PUBLICO` | Accepting a public address on the FTP and on the panel. It is optional and is the choice of whoever installs. Read the [alert](#rede-permitir-ip-publico) before turning it on | `nao` or `sim` | `nao` |
| `FTP_BIND_IP` | IP of the **host** where the control port and the passive range listen | Private IP of the host; `0.0.0.0` is always refused; public IP, only with `REDE_PERMITIR_IP_PUBLICO=sim` | `127.0.0.1` |
| `FTP_PORT` | Control port published on the host (mapped to `2121` in the container) | `1` to `65535` | `21` |
| `FTP_PASSIVE_IP` | IP that the server **announces** to the client in passive mode (`PASV` reply): the **internal** IP through which the devices reach the server (note below) | Private IP, reachable by the client; public IP, only with `REDE_PERMITIR_IP_PUBLICO=sim` | `127.0.0.1` |
| `FTP_PASSIVE_PORT_START` | Start of the range of data ports (passive mode) | `1024` to `65535`, less than or equal to the end | `30000` |
| `FTP_PASSIVE_PORT_END` | End of the passive range. Number of ports greater than or equal to `FTP_MAX_CLIENTS` | `1024` to `65535`, greater than or equal to the start | `30049` |

> 🧱 **Private network:** by default only `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12` and `192.168.0.0/16` are accepted. [`deploy.sh`](../../deploy.sh) and the container stop with `não é IP privado` for any other value ([`scripts/rede-privada.sh`](../../scripts/rede-privada.sh)).

<a name="rede-permitir-ip-publico"></a>

> ⚠️ **Alert — `REDE_PERMITIR_IP_PUBLICO=sim` puts the FTP and the panel on the internet.** From the factory the option comes turned off; turning it on is the choice of whoever installs. An exposed server is scanned and receives password attempts all the time. Turn it on only with a firewall on the server allowing the ports only for the addresses of the devices and of whoever administers, with `FTP_TLS_MODE` at `2` or `3` (with the option, `0` and `1` are refused), generated passwords and a reduced `PAINEL_REDES_PERMITIDAS`. Even with `sim`, `0.0.0.0` and a network wider than `/8` are still refused. Without a firewall, the risk belongs to whoever turned the option on. The step by step is in [Security](../pt-BR/seguranca.md#ip-publico). To publish **only the panel**, without exposing the FTP, the path is another one: [`PAINEL_PROXY_CONFIAVEL`](#painel-proxy-confiavel).

> ⚠️ The passive range is published **1:1** (same port on the host and in the container). When widening it, adjust the host firewall too.

<a name="ftp-passive-ip"></a>
<a name="ftp-public-ip"></a>

> **What is `FTP_PASSIVE_IP` for?** In passive mode, the server tells the client on which IP and on which port to open the data connection. Pure-FTPd, inside the container, only knows the address of the Docker network, which the device does not reach; that is why the stack tells it which address to announce (option `-P`). The value is the **private** IP of the host through which the devices arrive, in general the same as `FTP_BIND_IP`. It is only different when there is internal NAT between the device and the server. An internet IP is refused.

> **Installation before `0.10.0`:** the variable was called `FTP_PUBLIC_IP`. `./deploy.sh` changes the name by itself, keeps the value and stores the previous `.env` in `BACKUP_DIR/<data>-antes-da-migracao-de-nomes/env`. Until it runs, the commands that call Compose stop with `defina FTP_PASSIVE_IP no .env`. The files in `.secrets/` also changed name, in `0.11.0`, and are converted in the same run: [Secrets](secrets.md#nomes-antigos).

---

<a name="usuario-inicial-e-senha"></a>

## 👤 Initial user and password

| Variable | What it is for | Values | Default |
|---|---|---|---|
| `FTP_USER` | Name of the initial user, created once, at the first start. Removed through the panel, it is not recreated | Rule `^[a-z_][a-z0-9_-]{0,31}$` | `transfer` |

The **password** of the initial user is not a variable: it stays in `SECRETS_DIR/ftp-usuario-inicial-senha.txt`, created by `deploy.sh`, and reaches the container as the secret `/run/secrets/ftp_usuario_inicial_senha`. A `.env` with `FTP_PASSWORD` filled in is refused. See [Secrets](secrets.md).

Only the initial user comes from the `.env`. The others are created through the [panel](panel.md#usuarios) or with [`manage-user.sh`](../../manage-user.sh): see [Operation](operation.md#usuarios). The password and the folder of the initial user are also changed through them, and it is removed like the others. Changing `FTP_USER` after the installation creates the user of the new name at the next start, also once; the one of the old name stays in the user database until it is removed.

---

<a name="tls"></a>

## 🔐 TLS

| Variable | What it is for | Values | Default |
|---|---|---|---|
| `FTP_TLS_MODE` | TLS policy of `pure-ftpd` (option `-Y`) | `0`, `1`, `2` or `3` (table below) | `2` |
| `FTP_TLS_EXCECOES` | Per-user TLS: with `sim`, the administrator can exempt from TLS, in the Users tab of the panel, the user of a device that does not speak TLS; the others are still required to use it. With nobody exempt, nothing changes: the session without TLS is refused before the password. It only holds with `FTP_TLS_MODE=2` and without `REDE_PERMITIR_IP_PUBLICO=sim`; outside that it has no effect | `sim` or `nao` | `sim` |
| `FTP_CERT_CN` | `CN` and `SAN` of the self-signed certificate generated at the first start. If it is an IPv4, it goes in as `IP:`; otherwise, as `DNS:` | hostname or IPv4 | `ftp.exemplo.com.br` in the example; `localhost` if the variable is missing |

| Mode | Session without TLS | Data channel without encryption | When to use |
|---|---|---|---|
| `0` | **it is the only one that exists**: the server does not offer TLS | always without encryption | only an old device without TLS support |
| `1` | accepted (optional TLS) | accepted | old and new devices on the same server |
| `2` | **refused**: only whoever negotiates TLS gets in | accepted, if the client asks | **default** |
| `3` | **refused** | **refused**: the data also has to be encrypted | all the devices support `PROT P` |

> ⚠️ **Modes `0` and `1`: FTP without encryption.** They exist only for an old device that does not speak TLS. In them, user, password and file pass in **plain text** and can be read by whoever is on the same network path. Use them only on an isolated internal network, with the firewall allowing the port only for those devices, with a user and password dedicated to them, and go back to `2` as soon as you can. While one of those modes is on, the stack warns in three places: at the end of `./deploy.sh`, in the log of the FTP container and on the screens of the panel. Read [Security](../pt-BR/seguranca.md#ftp-sem-tls) first.

> ⚠️ **`FTP_TLS_EXCECOES=sim`: without TLS only for whoever the administrator exempts.** The option comes turned on and, by itself, lets nobody through: the server requires TLS from everyone until an administrator exempts a user, in the Users tab of the panel (when creating or in **Exempt from TLS**) or with `manage-user.sh`. The exempt user sends password and file in **plain text**, and the conditions of use are the same as those of modes `0` and `1`. With `nao`, nobody gets in without TLS, even if already exempted before: the list stays stored and does not hold, and the panel stops offering the exemption. Read [Security](../pt-BR/seguranca.md#tls-por-usuario) first.

A value outside `0` to `3` is refused by `deploy.sh` before any change and, if it reaches the container, it stops with `FALHA: FTP_TLS_MODE deve ser 0, 1, 2 ou 3`. The certificate of the FTP is generated in any mode: when going back to `2`, it is already there.

Of `FTP_TLS_EXCECOES`, only the value is refused: outside `sim` and `nao`, `deploy.sh` and the containers of the FTP and of the panel stop before any change. With `FTP_TLS_MODE` different from `2`, or together with `REDE_PERMITIR_IP_PUBLICO=sim`, the stack starts and the option has **no effect**: nobody is exempted, `deploy.sh` and the log of the FTP say `TLS por usuário sem efeito` with the reason, and the panel replaces the buttons with the same reason. In `0` and `1` everyone already gets in without TLS, `3` requires TLS in the data too, which the device without TLS does not do, and FTP without TLS on the internet hands the password to whoever listens.

> ⚠️ In mode `2`, the default, user and password always travel encrypted, but the content of the file is only encrypted if the client asks for protection of the data channel (`PROT P`). To **force** the encryption of the file, use `FTP_TLS_MODE=3` and check first whether the devices support it.

Replacing the self-signed certificate with a real one: [Operation](operation.md#certificado-real-de-producao).

---

<a name="limites-de-sessao"></a>

## 👥 Session limits

| Variable | What it is for | Values | Default |
|---|---|---|---|
| `FTP_MAX_CLIENTS` | Maximum of simultaneous connections (option `-c`). Align it with the size of the passive range. It also sets the cost of the stored password of each FTP user: [Security](../pt-BR/seguranca.md#custo-das-senhas) | integer greater than zero | `50` |
| `FTP_MAX_CLIENTS_PER_IP` | Maximum of connections per source IP (option `-C`) | integer greater than zero | `8` |
| `FTP_BLOQUEIO_TENTATIVAS` | Blocking by attempts: how many wrong passwords coming from the same address block the user for that address. It is the default of the stack; the limit of each user is adjusted in the panel: [Panel](panel.md#limites) | `0` to `100`; `0` turns it off | `5` |
| `FTP_BLOQUEIO_MINUTOS` | Minutes that the block lasts. It is also the time in which the wrong passwords add up: [Security](../pt-BR/seguranca.md#bloqueio-por-tentativa) | `1` to `1440` | `15` |
| `BLOQUEIO_ENDERECO_ERROS` | Blocking by address: the address that goes past this number of user and password errors, on the FTP or in the panel, no longer gets into either of the two, with any account: [Security](../pt-BR/seguranca.md#bloqueio-por-endereco) | `0` to `100`; `0` turns it off | `5` |
| `BLOQUEIO_ENDERECO_HORAS` | Hours in which the errors of the same address add up | `1` to `720` | `24` |
| `BLOQUEIO_ENDERECO_DIAS` | Days that the block of the address lasts, and the period that the block made by the administrator gets when no other is given. The administrator blocks an address or a prefix, unblocks and changes the period in the Blocks tab of the panel | `1` to `3650` | `120` |

---

<a name="painel"></a>

## 🖥️ Web panel

| Variable | What it is for | Values | Default |
|---|---|---|---|
| `PAINEL_BIND_IP` | IP of the **host** where nginx publishes the panel | Private IP of the host; `0.0.0.0` is always refused; public IP, only with `REDE_PERMITIR_IP_PUBLICO=sim` | `127.0.0.1` |
| `PAINEL_PORT` | HTTPS port of the panel published on the host by nginx (mapped to `8443` in the nginx container) | `1` to `65535` | `8443` |
| `PAINEL_REDES_PERMITIDAS` | Networks from which the panel accepts a client. Whoever is outside gets `403` from nginx, before reaching the panel; the panel checks again | List of **private** networks separated by comma, in CIDR notation; public network (from `/8` to `/32`), only with `REDE_PERMITIR_IP_PUBLICO=sim` | `127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16` |
| `PAINEL_ADMIN_USER` | Name of the first administrator of the panel, created at the first start with the initial password in `.secrets/`. It only holds while no administrator exists: after that, name, password and the other administrators are changed in the Users tab | Lowercase letters, numbers, `_` and `-`; starts with a letter or `_`; up to 32 characters | `admin` |
| `PAINEL_SESSAO_MINUTOS` | Minutes without use until the session ends; with or without use, it ends in 12 hours. The auto-refresh of the Server tab does not count as use. Deleting, renaming and touching an administrator ask for the password again, even with the session open | `1` to `720` | `240` (4 hours) |
| `PAINEL_ENVIO_MAX_MB` | Maximum size, in MB, of each file uploaded through the panel. The administrator always uploads; the FTP user, only with the permission ticked when editing it, in the Limits card. nginx and the panel refuse what goes past the ceiling with `413`; a larger file goes by FTP: [Upload file](panel.md#enviar-arquivo) | `1` to `102400` | `1024` (1 GB) |
| `PAINEL_RETENCAO_MINUTOS` | Minutes between one pass and the next of the automatic cleanup, which deletes the old files from the folders of the users on which the administrator turned the rule on. The first pass goes out 2 minutes after the start of the panel. With no rule on any user, nothing is deleted: [Automatic cleanup](panel.md#limpeza) | `0` to `1440`; `0` stops the cleanup, and the stored rules have no effect | `60` (1 hour) |
| `PAINEL_ACESSO_USUARIOS_FTP` | Sign-in of the FTP users to the panel. With `sim`, each FTP user signs in with the FTP name and password and sees only its own folder, where it does what its profile allows, without any administration screen; with `nao`, only an administrator signs in. The FTP server checks the password, through the internal network of the stack: [FTP user in the panel](panel.md#usuario-ftp) | `sim` or `nao` | `sim` |
| `PAINEL_CERT_CN` | Extra internal name or private IP in the self-signed certificate of the panel | Lowercase name or **private** IP (public IP, only with `REDE_PERMITIR_IP_PUBLICO=sim`); empty for none | empty |
| `PAINEL_PROXY_CONFIAVEL` | Publishing **only the panel** through a proxy or tunnel, without exposing the FTP: the addresses from which nginx accepts `X-Forwarded-For` as the address of whoever accesses. It is optional and is the choice of whoever installs. Read the [alert](#painel-proxy-confiavel) before filling it in | Up to 8 IPv4 addresses separated by comma, one by one, without a mask; each one private (public, only with `REDE_PERMITIR_IP_PUBLICO=sim`) and inside `PAINEL_REDES_PERMITIDAS`; empty not to use it | empty |
| `PAINEL_AVISO_EXPOSICAO` | Exposure warning on the screen of the panel. With `sim`, when `REDE_PERMITIR_IP_PUBLICO=sim` or `PAINEL_PROXY_CONFIAVEL` is filled in, the administrator reads how the installation is published in three places: in the sign next to **Security** in the menu, at the beginning of the Security tab and in the footer. With `nao`, the three disappear. The sign-in screen and the screens of the FTP user never say how the panel was published. The lines **Public address** and **Panel behind a proxy or tunnel** of the Security tab, which only an administrator sees, keep showing the state, and the alert stays in the output of `deploy.sh` and in the log of the containers | `sim` or `nao` | `sim` |
| `PAINEL_MEMORY_LIMIT` | `mem_limit` of the panel, without swap | example: `192M` | `192M` |
| `PAINEL_CPU_LIMIT` | `cpus` of the panel | example: `0.5` | `0.5` |
| `PAINEL_PIDS_LIMIT` | `pids_limit` of the panel | integer | `64` |
| `NGINX_MEMORY_LIMIT` | `mem_limit` of nginx, without swap | example: `64M` | `64M` |
| `NGINX_CPU_LIMIT` | `cpus` of nginx | example: `0.5` | `0.5` |
| `NGINX_PIDS_LIMIT` | `pids_limit` of nginx | integer | `32` |

> 🧱 **Private network:** by default the panel is only for an internal network, behind a firewall. `PAINEL_BIND_IP`, each network in `PAINEL_REDES_PERMITIDAS` and a `PAINEL_CERT_CN` in the form of an IP have to be private: [`deploy.sh`](../../deploy.sh) and the containers of the panel and of nginx stop with `não é IP privado` or `não é rede privada` for any other value. A public address and network only pass with the option [`REDE_PERMITIR_IP_PUBLICO`](#rede-permitir-ip-publico).

<a name="painel-proxy-confiavel"></a>

> ⚠️ **Alert — `PAINEL_PROXY_CONFIAVEL` filled in puts the sign-in screen of the panel within reach of whoever gets to the proxy or to the tunnel.** With the variable empty, which is the default, the address of whoever accesses is always that of the connection and `X-Forwarded-For` is ignored. Filled in, nginx starts using the **last** address of that header, only when the connection comes from an address on the list, for the limit of password attempts, the session, the audit log and the request limits. Who can reach the screen becomes decided at the proxy or at the tunnel: restrict the access there. The FTP does not go through it and stays only on the addresses of the stack. The public name through which the panel is opened goes in `PAINEL_CERT_CN`. The step by step is in [Security](../pt-BR/seguranca.md#painel-por-proxy).

With `PAINEL_SESSAO_MINUTOS`, `PAINEL_ENVIO_MAX_MB` or `PAINEL_RETENCAO_MINUTOS` outside the values of the table, the panel container does not start: it stops with `FALHA: <variável> deve ficar entre <mínimo> e <máximo>` in the log (`docker compose logs painel`), before touching any folder.

The password of the panel is **not** a variable: the initial one stays in `.secrets/`, and that of each administrator, only as a hash, in `DATA_DIR/painel/administradores`. `deploy.sh` and the container refuse `PAINEL_PASSWORD` and `PAINEL_PASSWORD_HASH`, and stop with `PAINEL_ADMIN_USER inválido` for a name outside the rule. See [Secrets](secrets.md#senha-do-painel) and [Administrators of the panel](panel.md#administradores).

The browser never talks straight to the panel: only nginx publishes a port, and it passes the request on to the panel through a socket inside `DATA_DIR/nginx`. The limit of requests per address, the maximum size of the request, HTTP/2 and the time of the idle connection are fixed in the configuration of nginx ([`nginx/nginx.conf.modelo`](../../nginx/nginx.conf.modelo)), without a variable. The profiles in [`profiles/`](../../profiles/) do not touch the variables of the panel or those of nginx.

---

<a name="contato-de-seguranca"></a>

## 📮 Security contact

| Variable | What it is for | Values | Default |
|---|---|---|---|
| `SEGURANCA_CONTATO_EMAIL` | E-mail to which whoever finds a security flaw in this installation should write. Filled in, the panel publishes the address in `/.well-known/security.txt`, without asking for a password, to the networks in `PAINEL_REDES_PERMITIDAS` | A single e-mail address, without `mailto:`; empty not to publish | empty |

The file follows RFC 9116: it is where a researcher, or the scanning tool of the company itself, looks for whom to warn. Use a mailbox read by more than one person, such as `seguranca@suaempresa.com.br`: the address is in sight of whoever reaches the panel.

1. In the `.env`, fill in the variable:

   ```bash
   SEGURANCA_CONTATO_EMAIL=seguranca@suaempresa.com.br
   ```

2. Reapply:

   ```bash
   ./deploy.sh
   ```

3. Check, from a machine on the allowed networks:

   ```bash
   curl -k https://<panel address>:8443/.well-known/security.txt
   ```

**Expected result:** the summary of `deploy.sh` with the line `Contato de segurança: seguranca@suaempresa.com.br, publicado em /.well-known/security.txt do painel.`, three lines in the reply and the Security tab of the panel with the item `Security contact` ticked.

```text
Contact: mailto:seguranca@suaempresa.com.br
Expires: 2027-01-03T00:00:00Z
Preferred-Languages: pt-BR
```

With the variable empty, the same address answers `404` with `contato de segurança não configurado`, and the summary of `deploy.sh` brings `Contato de segurança: não publicado`, with what to fill in. With `REDE_PERMITIR_IP_PUBLICO=sim`, the Security tab starts demanding that it be filled in.

<details>
<summary>Technical detail — validity, validation and what is not published</summary>

- **Validity always in the future:** the `Expires` line is calculated at every request, 90 days ahead, at midnight UTC. The file does not expire with the server up, and the RFC asks for a validity shorter than one year.
- **Always equal to the `.env`:** the text comes from the configuration in effect, not from a stored file. Emptying the variable and running `deploy.sh` takes the file down.
- **Validation at three points:** [`deploy.sh`](../../deploy.sh), the panel container and the panel itself refuse the value that is not a single address: without `@`, domain without a dot, two addresses, space, `mailto:`, URL, `<`, `>`, `%`, line break, part before the `@` with more than 64 characters or address with more than 254. The message is `SEGURANCA_CONTATO_EMAIL inválido`.
- **Only the contact:** the file brings no version, name of the stack or path. There is no `Canonical` line, because the address of the panel changes from one installation to another and the file is not signed.
- **Only that address:** `/security.txt` at the root, the listing of `/.well-known/` and any other name inside it do not exist; without a session, they lead to the sign-in screen.
- **Whose contact it is:** of whoever operates this installation, not of whoever developed the stack. The [security policy](../../SECURITY.md) of the project brings no fixed address: it sends whoever found the flaw to the contact published here.

What else stays open without a password, and why: [Security](../pt-BR/seguranca.md#contato-de-seguranca).

</details>

---

<a name="limites-de-recurso-do-container"></a>

## 🧱 Resource limits of the container

| Variable | What it is for | Values | Default |
|---|---|---|---|
| `FTP_MEMORY_LIMIT` | `mem_limit` of the service, without swap: it is the real ceiling, and the Server tab shows the usage against it | example: `256M`, `512M` | `256M` |
| `FTP_CPU_LIMIT` | `cpus` of the service | example: `0.5`, `1.0`, `2` | `1.0` |
| `FTP_PIDS_LIMIT` | `pids_limit` (barrier against a _fork bomb_) | integer | `128` |
| `FTP_NOFILE` | `ulimit nofile` (soft equal to hard) | integer | `16384` |
| `FTP_PROFILE` | Name of the profile in use. It only informs: `./deploy.sh --size` is what writes it | `small`, `medium`, `large`, `xlarge`, `extended` | `small` |

> These fields, plus `FTP_MAX_CLIENTS*` and the passive range, are what `./deploy.sh --size <profile>` writes from [`profiles/`](../../profiles/). Prefer `./deploy.sh --size medium` to editing the values by hand: see [Profiles](profiles.md). `deploy.sh` checks whether the server has the CPUs and the memory that `FTP_CPU_LIMIT` and `FTP_MEMORY_LIMIT` ask for and refuses what does not fit.

---

<a name="rede-docker-sub-rede"></a>

## 🌐 Docker network (subnet)

The Docker network of this stack has a fixed subnet, changeable through a variable in the `.env`. Use it when the range collides with the LAN or the VPN of the customer.

| Variable | Network | Containers | Default | Example |
|---|---|---|---|---|
| `FTP_SUBNET` | `ftp` (`allsafe-ftp-network`) | `allsafe-ftp`, `allsafe-ftp-painel` and `allsafe-ftp-nginx` | `172.29.1.0/29` | `FTP_SUBNET=10.250.1.0/29` |

On an installation that is already running, the new subnet only holds after recreating the network (the volumes and the data are not affected):

```bash
./deploy.sh --remover      # takes down the containers and the network; the data stays
./deploy.sh                # starts again, with the new network
```

**Expected result:** `docker network inspect allsafe-ftp-network` shows the new subnet.

> The profile in use is written in the `.env`: `deploy.sh` without `--size` and `docker compose up -d` apply the same limits.

<details>
<summary>Technical detail — the address block of the AllSafe stacks</summary>

The AllSafe stacks reserve `172.29.1.0/24` for `/29` networks and `172.29.2.0/24` for `/28` and `/27` networks. This stack uses the first `/29` of the block. The value goes into [`compose.yaml`](../../compose.yaml) as `subnet: ${FTP_SUBNET:-172.29.1.0/29}`.

</details>

---

⬅️ [Installation](installation.md) · 🏠 [Documentation](README.md) · ➡️ [Profiles](profiles.md)
