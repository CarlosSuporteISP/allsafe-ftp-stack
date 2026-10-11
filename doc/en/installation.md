# 🚀 Installation — allsafe-ftp-stack

🌐 **English** · [Português (Brasil)](../pt-BR/instalacao.md)

↩ [Project README](../../README.md) · [Documentation index](README.md)

## 💡 In a few words

You run one command and the FTP server starts by itself, already with a strong password and an encrypted connection, together with the web panel to administer the users and nginx, which stays in front of the panel. It is born serving only the server itself; to serve the internal network, you enter the private IP in the configuration file and run the same command again. At the end, a second script checks whether everything is up. It takes a few minutes and can be undone without losing the files.

<!-- diagrama: diagrams/installation-diagram.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    usuario@{ shape: person, label: "User" }
    deploy@{ shape: console, label: "deploy.sh<br>creates the .env, generates the passwords and starts" }
    stack@{ shape: rect, label: "Docker Compose<br>FTP, panel and nginx" }
    valida@{ shape: console, label: "validate.sh<br>checks the startup" }
    fim@{ shape: stadium, label: "FTP and panel ready" }

    usuario --> deploy --> stack --> valida --> fim
```
<sub>Level 1 · Diagram · [source](diagrams/)</sub>

**Sequence:** User ➜ `deploy.sh` (creates the `.env`, generates the passwords and starts) ➜ Docker Compose (FTP, panel and nginx) ➜ `validate.sh` ➜ FTP and panel ready

---

<details>
<summary>Contents — click to expand</summary>

[Prerequisites](#pre-requisitos) · [1️⃣ Base configuration](#1-configuracao-base) · [2️⃣ Password of the initial user](#2-senha-do-usuario-inicial) · [3️⃣ Starting the stack](#3-subir-a-stack) · [4️⃣ Validating](#4-validar) · [How to undo](#como-desfazer) · [Next steps](#proximos-passos)

</details>

---

<a name="pre-requisitos"></a>

## ✅ Prerequisites

| Item | Detail |
|---|---|
| Docker Engine with Docker Compose v2 or newer | `docker compose version` must answer |
| CPU and memory for the profile | `small` asks for 1 CPU and 256 MB; `extended`, 16 CPUs and 4 GB. `deploy.sh` checks and refuses the profile larger than the server: [Profiles](profiles.md#o-servidor-aguenta) |
| One dedicated IP for the FTP | Do not share the IP with other services; passive mode opens from 50 to 1600 ports, depending on the profile |
| Firewall on the host | Allow `21/tcp` and the passive range of the profile (`30000-30049/tcp` on `small`) **only** for the management networks of the devices, and the panel port (`8443/tcp`) **only** for whoever administers |
| Private network | By default the stack only accepts an internal IP: see [Security](security.md#rede-privada). A public address depends on an option with a warning: [Public IP](security.md#ip-publico) |
| Folder for the data | The default is `/srv/allsafe-ftp-stack`, with `data`, `backups` and `tmp` inside. Whoever installs without being root creates the folder once: `sudo install -d -o "$USER" /srv/allsafe-ftp-stack`. Another place: `DATA_DIR`, `BACKUP_DIR` and `TEMP_DIR` in [Configuration](configuration.md#pastas-e-nomes) |
| Synchronized clock | The TLS certificate depends on the correct date and time (the `allsafe-ntp-nts-stack` stack takes care of that) |

---

<a name="1-configuracao-base"></a>

## 1️⃣ Base configuration

This step is **optional the first time**: without a `.env`, [`deploy.sh`](../../deploy.sh) creates one from the example, with everything on `127.0.0.1` (only the server itself has access), and goes on. To start already serving the internal network, create and adjust the file first:

```bash
cp .env.example .env
chmod 600 .env
```

**Expected result:** the `.env` file now exists at the root of the stack.

Each variable is explained in [Configuration](configuration.md). The fields that **you need** to review:

| Variable | Change to |
|---|---|
| `FTP_BIND_IP` | the dedicated **private** IP of the server (with `127.0.0.1` only the server itself reaches the FTP) |
| `FTP_PASSIVE_IP` | the IP that the client sees; normally the same as `FTP_BIND_IP`. It also has to be private |
| `PAINEL_BIND_IP` | the **private** IP through which the panel will be opened; with `127.0.0.1` it only opens on the server itself |
| `FTP_CERT_CN` | the hostname (example: `ftp.exemplo.com.br`) or IP that goes into the certificate |
| `FTP_USER` | name of the initial user (default `transfer`). Rule: `^[a-z_][a-z0-9_-]{0,31}$` |

> Skipped this step? Adjust the `.env` later and run `./deploy.sh` again: it reapplies the configuration without changing a password or deleting data.

---

<a name="2-senha-do-usuario-inicial"></a>

## 2️⃣ Password of the initial user

Nothing to do here the first time: [`deploy.sh`](../../deploy.sh) **generates a strong password** in `.secrets/ftp-usuario-inicial-senha.txt`, with permission `0600`, if the file is empty or absent. Write it down to set up the FTP client:

```bash
cat .secrets/ftp-usuario-inicial-senha.txt      # after the first deploy
```

**Expected result:** one line with the generated password, of about 48 characters.

To use a password of your own, write it **before** running `deploy.sh`:

```bash
printf '%s' 'uma-senha-forte-de-12+-caracteres' > .secrets/ftp-usuario-inicial-senha.txt
chmod 600 .secrets/ftp-usuario-inicial-senha.txt
```

<details>
<summary>Technical detail — rules of the password</summary>

- The password is generated with `openssl rand -base64 36`; `openssl` is required on the host.
- Minimum of **12 characters**: [`ftp/entrypoint.sh`](../../ftp/entrypoint.sh) refuses shorter passwords.
- The file reaches the container as the secret `/run/secrets/ftp_usuario_inicial_senha`, read-only; the service does not see the rest of `.secrets/`.
- `.txt` files in `.secrets/` are ignored by Git. See [Secrets](secrets.md).
- A password in the `.env` **is not accepted**: `deploy.sh` refuses a `.env` with `FTP_PASSWORD` filled in and the container refuses the variable.

</details>

---

<a name="3-subir-a-stack"></a>

## 3️⃣ Starting the stack

```bash
./deploy.sh                  # another size: ./deploy.sh --size medium (or large, xlarge, extended)
```

**Expected result:** the command only finishes with the three containers `healthy` and closes with the summary:

```text
Pronto: FTP, painel e nginx no ar (healthy), perfil 'small'.
FTP:    127.0.0.1:21, TLS explícito obrigatório no login, modo passivo 30000-30049
        usuário 'transfer', senha no arquivo ./.secrets/ftp-usuario-inicial-senha.txt
Painel: https://127.0.0.1:8443  (pelo nginx; certificado autoassinado; rede privada, atrás de firewall)
        usuário 'admin', senha inicial no arquivo ./.secrets/painel-admin-inicial-senha.txt
        (valem até serem trocados na aba Usuários do painel)
Segredos: ./.secrets/LEIAME.txt diz para que serve cada arquivo.
Remover: ./deploy.sh --remover  (os dados ficam em <DATA_DIR>)
Contato de segurança: não publicado. Para publicar, preencha SEGURANCA_CONTATO_EMAIL em .env
        e rode ./deploy.sh de novo (política do projeto: SECURITY.md).
```

The summary says **where** each password is and never shows it. The `LEIAME.txt` of the `.secrets/` folder explains what each of its files is for. The first time, these also appear: `Gerada uma senha forte em .secrets/ftp-usuario-inicial-senha.txt (0600). Guarde-a para o cliente FTP.`, `Gerada uma senha forte para o painel em .secrets/painel-admin-inicial-senha.txt (0600).` and `Gerada a chave da cópia de segurança em .secrets/backup-chave-privada.txt (0600).`, with the reminder to keep that key off the server: [Backup and restore](backup.md#chave).

Open the address of the panel in the browser and sign in with the user `admin` (the one in `PAINEL_ADMIN_USER`) and the password in `.secrets/painel-admin-inicial-senha.txt`. The first access, the certificate warning and the change of the user and of the password are in [Web panel](panel.md#abrir).

Which profile to use: [Profiles](profiles.md). On the `xlarge` and `extended` profiles the startup takes minutes, because Docker publishes the passive ports one by one: [startup time](profiles.md#tempo-de-subida).

> ⚠️ **Old device that does not speak TLS?** The default requires TLS and refuses that device. To accept without TLS only its user, an administrator exempts it in the panel, when creating the user or in Users ➜ **Exempt from TLS**; to accept it from everyone, there is `FTP_TLS_MODE=0` (or `1`). On either path, whoever gets in without TLS leaves password and file readable to whoever is on the same network. Read the conditions first: [Security](security.md#ftp-sem-tls).

<details>
<summary>Technical detail — what <code>deploy.sh</code> and the entrypoint do</summary>

[`deploy.sh`](../../deploy.sh), in this order:

1. checks the requirements: `docker`, the `docker compose` plugin and the Docker service answering;
2. checks that the server has the CPUs and the memory that the profile asks for; if it does not, it stops without changing anything;
3. creates the `.env` from the example (`0600`) if it does not exist, and goes on; on an installation with the old names, it replaces `FTP_PUBLIC_IP` with `FTP_PASSIVE_IP` in the `.env`, after copying it to `BACKUP_DIR`, and gives the new name to the files in `.secrets/`;
4. refuses a password in the `.env`, an address or network outside private IP (unless with `REDE_PERMITIR_IP_PUBLICO=sim`) and `FTP_TLS_MODE` outside `0` to `3`;
5. with `--size`, writes to the `.env` the values of `profiles/<profile>.env` and the name of the profile in `FTP_PROFILE`; without `--size`, the `.env` stays as it is;
6. checks that the FTP port, the panel port and the passive range are free on the host (those that the stack itself already publishes do not count); a busy port stops the command with `ERRO: porta já em uso por outro programa: ...`;
7. creates the folders `dados/`, `auth/`, `certs/`, `painel/` and `nginx/` in `DATA_DIR` (without permission to create them, it stops with `ERRO: não foi possível criar as pastas em ...` and the command that creates the folder above), generates the password in `.secrets/ftp-usuario-inicial-senha.txt` if the file is empty and writes `.secrets/LEIAME.txt`;
8. runs `docker compose --env-file .env config --quiet`, which fails early if the configuration is invalid;
9. `docker compose build`, which builds the three images (with `--atualizar`, `build --no-cache`);
10. generates the initial password of the panel and writes its hash, if there is no hash yet, and creates the key pair of the backup copy, if neither of the two exists (with the private one present, it only remakes the public one);
11. `docker compose up -d --wait`, which only returns with the three containers `healthy` (limit of 180 s plus a quarter of a second per passive port);
12. `docker compose ps`, the summary with the addresses, the TLS mode and the place of each password and, in modes `0` and `1`, the warning of FTP without encryption.

With `--check-only`, the script stops after step 4 and a `config --quiet`, without creating a `.env`, a folder or a password, with `OK: perfil '<perfil>', rede privada, recursos do servidor e compose validados; nada foi alterado.`

At the **first** start, [`ftp/entrypoint.sh`](../../ftp/entrypoint.sh):

- creates `/data/$FTP_USER` owned by `ftpdata`;
- writes the user to PureDB (`/auth/pureftpd.pdb`);
- generates a **self-signed certificate** RSA 3072, valid for 825 days, in `/etc/ssl/private/pure-ftpd.pem`, with a SAN according to `FTP_CERT_CN` (IP or DNS);
- runs `pure-ftpd` listening on `:2121`.

With the FTP `healthy`, the panel starts: it generates its own self-signed certificate (EC P-256, 825 days) in `DATA_DIR/painel/tls`, delivers a copy to nginx and opens the Unix socket in `DATA_DIR/nginx`. With the panel `healthy`, nginx starts and listens on `:8443`.

The full model of the startup is in [Architecture](architecture.md#subida).

</details>

---

<a name="4-validar"></a>

## 4️⃣ Validating

```bash
./scripts/validate.sh            # syntax of the scripts and Compose of every profile, without starting anything
./scripts/validate.sh --runtime  # requires the three services 'running' and 'healthy' and the user in PureDB
```

**Expected result:** `painel OK: <n> módulos Python` (if the host has `python3`), one line `compose OK com <perfil>.env` for each of the five profiles and, at the end, `Validacao FTP concluida.`

Manual test with a client (**explicit** FTP over TLS, passive mode):

```bash
# lftp uses explicit FTPS by default
lftp -u "$FTP_USER" -e 'set ssl:verify-certificate no; ls; bye' ftp://SEU_IP
```

**Expected result:** `lftp` asks for the password and lists the user folder, empty the first time.

> ⚠️ As the initial certificate is self-signed, the client will complain about the validation until you install a real certificate. See [Operation](operation.md#certificado-real-de-producao).

---

<a name="como-desfazer"></a>

## ♻️ How to undo

```bash
./deploy.sh --remover           # removes the containers and the network; data, secrets and .env stay
```

**Expected result:** `Removidos os containers e a rede. Os dados continuam em <DATA_DIR>.` and `docker compose ps` no longer lists `allsafe-ftp`, `allsafe-ftp-painel` or `allsafe-ftp-nginx`. A new `./deploy.sh` brings everything back with the same data and the same passwords.

The files of the users, PureDB and the certificates stay in `DATA_DIR`, on the host: the removal deletes nothing (not even a `docker compose down -v` would). To delete for good, use `./deploy.sh --remover --apagar-dados`: it asks you to type `apagar` and removes the folders `dados/`, `auth/`, `certs/`, `painel/` and `nginx/` from `DATA_DIR`; the secrets and the `.env` stay.

---

<a name="proximos-passos"></a>

## ⏭️ Next steps

- Changing the initial password of the panel: [Secrets](secrets.md#senha-do-painel).
- Creating more users: in the [panel](panel.md#usuarios) or through [Operation](operation.md#usuarios).
- Going to production: [Security](security.md#o-que-endurecer-antes-de-producao) and the real certificate.
- Monitoring: the `allsafe-zabbix-isp-stack` stack follows the container.

---

⬅️ [Project README](../../README.md) · 🏠 [Documentation](README.md) · ➡️ [Configuration](configuration.md)
