# 🔑 Secrets — allsafe-ftp-stack

[![English](https://img.shields.io/badge/English-0969da?style=for-the-badge)](secrets.md)
[![Português (Brasil)](https://img.shields.io/badge/Portugu%C3%AAs_(Brasil)-6e7781?style=for-the-badge)](../pt-BR/segredos.md)
[![Español](https://img.shields.io/badge/Espa%C3%B1ol-6e7781?style=for-the-badge)](../es/secretos.md)

↩ [Project README](../../README.md) · [Documentation index](README.md)

## 💡 In a few words

The passwords of the stack live in the `.secrets/` folder, which never goes to Git or into the image. There are two: the one of the initial FTP user and the one of the web panel. The same folder holds the key pair that encrypts and opens the backup copy. The installation script creates everything by itself the first time, each one in a file whose name says what it keeps, and leaves in the folder a `LEIAME.txt` that explains them one by one. The FTP server reads its own at start and stores only the hash; the panel receives **only the hash** of its own, never the password.

<!-- diagrama: diagrams/secrets-diagram.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    deploy@{ shape: console, label: "deploy.sh<br>generates the password" }
    arquivo@{ shape: doc, label: ".secrets/ftp-usuario-inicial-senha.txt<br>0600, outside Git" }
    montagem@{ shape: rect, label: "/run/secrets/ftp_usuario_inicial_senha<br>read-only" }
    entry@{ shape: rect, label: "entrypoint<br>reads it and clears it from memory" }
    puredb@{ shape: cyl, label: "PureDB<br>keeps only the hash" }
    fim@{ shape: stadium, label: "password outside the image" }

    deploy --> arquivo --> montagem --> entry --> puredb --> fim
```
<sub>Level 1 · Diagram · [source](diagrams/)</sub>

**Sequence:** `deploy.sh` ➜ `.secrets/ftp-usuario-inicial-senha.txt` ➜ `/run/secrets/ftp_usuario_inicial_senha` (read-only) ➜ entrypoint ➜ PureDB (stores only the hash) ➜ password outside the image

---

<details>
<summary>Contents — click to expand</summary>

[What stays in `.secrets/`](#o-que-fica) · [Changing the password of the initial user](#trocar-a-senha) · [Panel password](#senha-do-painel) · [Using a password of your own](#senha-propria) · [Installation with the old names](#nomes-antigos) · [What else is sensitive](#o-que-mais-e-sensivel)

</details>

---

<a name="o-que-fica"></a>

## 📂 What stays in `.secrets/`

| File | Who generates it | Do you fill it in? | What for |
|---|---|---|---|
| `ftp-usuario-inicial-senha.txt` | [`deploy.sh`](../../deploy.sh), on the first run, if the file does not exist or is empty | Only if you want a password of your own | Password of the initial user (`FTP_USER`) |
| `painel-admin-inicial-senha.txt` | [`deploy.sh`](../../deploy.sh), on the first run | No | **Initial** password of the first panel administrator (`PAINEL_ADMIN_USER`), in text. It stays only on the host and is valid until it is changed in the Users tab; once changed, delete the file |
| `painel-admin-inicial-senha-hash.txt` | [`deploy.sh`](../../deploy.sh) and [`scripts/painel-senha.sh`](../../scripts/painel-senha.sh) | No | `scrypt` hash of that initial password. It is only used to create the first administrator. Of the loose files of the folder, the panel sees this one and the public key of the copy |
| `backup-chave-privada.txt` | [`deploy.sh`](../../deploy.sh), if neither of the two keys exists | No | Key that **opens** the backup copy. Keep a copy off the server: without it no copy restores. See [Backup and restore](backup.md#chave) |
| `backup-chave-publica.txt` | [`deploy.sh`](../../deploy.sh), at every run, from the private one | No | Key that **encrypts** the backup copy. It opens nothing and can stay on the server. The panel receives it as a mounted secret, read-only, to encrypt the [system copy](panel.md#copia-do-sistema) sent to the S3 |
| `LEIAME.txt` | [`deploy.sh`](../../deploy.sh), at every run | No | Says what each file of the folder is for. It keeps no secret |
| `destinos/` | [`deploy.sh`](../../deploy.sh) creates the folder, empty; the panel writes the files | No: through the Destinations tab | Secrets of each S3, of each rclone remote and of each Telegram bot, one per file, with the name of the destination in front: `s3-chave-de-acesso.txt`, `s3-chave-secreta.txt`, `rclone-remoto.txt`, `telegram-token.txt` and `telegram-conversa.txt` in the first of each type, and `s3-2-chave-de-acesso.txt`, `rclone-2-remoto.txt`, `telegram-2-token.txt` and so on in the next ones. The file of the rclone remote holds the whole access and, for SFTP, the server key the test stored. The panel writes and reads them, and none goes back to the screen. To change or remove: through the [Destinations](panel.md#destinos) tab |
| `segundo-fator/` | [`deploy.sh`](../../deploy.sh) creates the folder, empty; the panel writes the files | No: through the Users tab | Key of the second factor of each account of the panel, one per file, written at setup: `<name>.txt` for the administrator and `ftp.<name>.txt` for the FTP user. The codes of that account are generated with it. The list of who has the factor on stays in the data of the panel: deleting the file here does not turn the factor off, and the account stops signing in until it is turned off, by an administrator or from the terminal: [Second factor](panel.md#segundo-fator) |
| `.gitkeep` | already comes in the repository | No | Keeps the folder in the clone |

The name of each file follows the same order: **whose** secret it is (`ftp-usuario-inicial`, `painel-admin-inicial`, `backup`) and **what** is written (`senha` in text, `senha-hash`, `chave-privada` or `chave-publica`).

Seeing the generated passwords, to set up the device and to sign in to the panel for the first time:

```bash
cat .secrets/ftp-usuario-inicial-senha.txt       # initial FTP user
cat .secrets/painel-admin-inicial-senha.txt    # first panel administrator, until the first change
```

**Expected result:** in each command, one line with the password, of 48 characters.

> ⚠️ Never paste the password into a document, a screenshot, a test result or a message. Where the format needs to be shown, use `<REDACTED>`.

---

<a name="trocar-a-senha"></a>

## 🔁 Changing the password of the initial user

There are two paths, and the most recent change always holds.

| Path | How | Valid until |
|---|---|---|
| In the panel or in the terminal | Users ➜ **Change password**, or `./manage-user.sh passwd <usuario>` | The secret file is changed |
| Through the secret file | The three commands below | The next change, by any path |

```bash
printf '%s' 'nova-senha-de-12-ou-mais' > .secrets/ftp-usuario-inicial-senha.txt
chmod 600 .secrets/ftp-usuario-inicial-senha.txt
docker compose restart ftp
```

**Expected result:** the container goes back to `healthy` and the old login starts being refused with `530 Login authentication failed`.

The initial user is created once. Removed in the panel or with `./manage-user.sh del`, it does not come back at the next starts and the secret file is left unused; created again with the same name, the password given at creation holds, until the file is changed.

The password changed in the panel or with `manage-user.sh passwd` survives restarts: the `ftp` service only applies the one from the file again when the **content of the file changes**. Meanwhile, the file keeps the previous password, unused, and the summary of `./deploy.sh` says `senha trocada pelo painel`. For the other users, the change is in the panel or with `manage-user.sh`: see [Operation](operation.md#usuarios).

---

<a name="senha-do-painel"></a>

## 🖥️ Panel password

Each panel administrator has their own user and password. The first one is born at installation, with the name in `PAINEL_ADMIN_USER` and the password in `.secrets/painel-admin-inicial-senha.txt`. Change that password right after the first access, **in the panel**, in the Users tab, and delete the file of the initial password: [Panel administrators](panel.md#administradores).

Without access to the panel, the password is set from the host:

```bash
./scripts/painel-senha.sh --gerar                    # strong password for the first administrator, shown only once
./scripts/painel-senha.sh                            # or: asks for the new password twice, without showing it on the screen
./scripts/painel-senha.sh --usuario NOME --gerar     # another administrator; if NOME does not exist, it is created
```

**Expected result:** `Administrador admin com a senha trocada; painel reiniciado e sessões abertas encerradas.` When the administrator is the one in `PAINEL_ADMIN_USER`, the file `painel-admin-inicial-senha.txt` ceases to exist.

The password must have at least 12 characters and **is not stored anywhere**: the panel keeps only the hash, in `DATA_DIR/painel/administradores`. Keep it in your password vault. Use of the panel: [Web panel](panel.md).

---

<a name="senha-propria"></a>

## ✍️ Using a password of your own

Write it **before** the first deploy, with at least 12 characters:

```bash
printf '%s' 'uma-senha-forte-de-12+-caracteres' > .secrets/ftp-usuario-inicial-senha.txt
chmod 600 .secrets/ftp-usuario-inicial-senha.txt
```

**Expected result:** `deploy.sh` generates no new password and does not show the message `Gerada uma senha forte em ...`.

---

<a name="nomes-antigos"></a>

## 🔀 Installation with the old names

Up to version `0.17.0` the files had other names. `./deploy.sh` recognizes the old ones and **only changes the name**, without reading, copying or changing the content: the passwords stay the same.

| Name up to `0.17.0` | Name from `0.18.0` on |
|---|---|
| `ftp_password.txt` | `ftp-usuario-inicial-senha.txt` |
| `painel_password.txt` | `painel-admin-inicial-senha.txt` |
| `painel_password_hash.txt` | `painel-admin-inicial-senha-hash.txt` |

```bash
./deploy.sh
```

**Expected result:** one line `Convertido: <nome antigo> virou <nome novo>.` for each file that existed, and the three containers `healthy` at the end. Coming from `0.17.0`, the FTP and panel containers are recreated once, because the name of the secret inside them also changed, and the nginx one stays the same; coming from an earlier version, the three are recreated, because the images change. Data, users and passwords stay as they were.

With `./deploy.sh --check-only` nothing is changed: only the warning `AVISO: esta instalação usa nomes antigos` comes out. If the old file and the new one exist at the same time, the new one holds and the script warns you to check and delete the old one.

---

<a name="o-que-mais-e-sensivel"></a>

## 🧾 What else is sensitive

| Item | Where it stays | Protection |
|---|---|---|
| `.env` | root of the stack | `0600`, ignored by Git and by the build |
| TLS private key of the FTP | folder `DATA_DIR/certs`, file `pure-ftpd.pem` | `0600`, outside the repository |
| TLS private key of the panel | folder `DATA_DIR/painel/tls`, file `painel-key.pem` | `0600`, folder `0700`, outside the repository |
| Copy of the TLS key of the panel, for nginx | folder `DATA_DIR/nginx/tls`, file `painel-key.pem` | `0640`, group `10001` (the nginx one), folder `0750`; remade at every start and mounted in nginx read-only |
| Audit log of the panel | folder `DATA_DIR/painel`, file `auditoria.log` | `0600`; it keeps no password, but shows user names and addresses |
| Hash of the user passwords | folder `DATA_DIR/auth`, files `pureftpd.passwd` and `pureftpd.pdb` | `0600`, outside the repository |
| Backup copies made by `scripts/backup.sh` | folder `BACKUP_DIR` | Encrypted with the public key in `.secrets/`, `0600`, folder `0700`, outside the repository; they contain the hash of the passwords, the private keys of the certificates and the files of the devices |

<details>
<summary>Technical detail — generation, mounting and disposal</summary>

- **Generation:** `openssl rand -base64 36` (48 characters). The script applies `umask 077`, `chmod 0700` on the folder and `chmod 0600` on the file, and never rewrites a secret that already exists.
- **Mounting:** [`compose.yaml`](../../compose.yaml) declares the secret `ftp_usuario_inicial_senha` (`SECRETS_DIR/ftp-usuario-inicial-senha.txt`) and delivers it **only** to the `ftp` service, at `/run/secrets/ftp_usuario_inicial_senha`, read-only. The whole `.secrets/` folder is not mounted.
- **No password in a variable:** the `.env` keeps only what is adjustable. `deploy.sh` refuses `FTP_PASSWORD`, `PAINEL_PASSWORD` and `PAINEL_PASSWORD_HASH` in the `.env` and the containers refuse those variables.
- **Reading:** [`ftp/entrypoint.sh`](../../ftp/entrypoint.sh) reads the file without the line breaks, validates the minimum of 12 characters and delivers the password to `pure-pw` through `stdin`. At the first start it creates the user (`pure-pw useradd`); at the following ones, it rewrites the password (`pure-pw passwd`), because `pure-pw usermod` does not change the password. In both cases it passes `-C FTP_MAX_CLIENTS`, which sets the cost of the `argon2id` hash: [Security](security.md#custo-das-senhas).
- **Change in the panel:** each time it applies the secret, the entrypoint writes to `/auth/senha-inicial.aplicada` a fingerprint of it (`sha512-crypt` with its own salt, `0600`), never the password. The change in the panel or with `manage-user.sh passwd` writes `/auth/senha-inicial.trocada`, with the user name only. At start, with the mark present and the fingerprint equal to that of the secret, the password in the user database is kept and the log says `mantida a senha trocada pelo painel`; with a different secret, it is applied and the mark goes away. Both files go into the backup, with the user database.
- **Created once:** when creating the initial user, the entrypoint writes `/auth/usuario-inicial.criado` (`0600`), with its name only. With the mark present and the user out of the database, it is not recreated, and the log says `removido pelo administrador; não é recriado`. An installation earlier than `0.44.0` gets the mark at the first start, with the user that already exists. The mark goes into the backup, with the user database.
- **Disposal:** before the `exec` of `pure-ftpd`, the entrypoint does an `unset` of the internal variable of the password.
- **Panel:** the hash is `scrypt` (N=2^15, r=8, p=1, random salt of 16 bytes), computed inside the panel image, in a disposable container without network. The secret `painel_admin_inicial_senha_hash` reaches **only** the `painel` service, at `/run/secrets/painel_admin_inicial_senha_hash`, read-only, and it is only read at the start in which no administrator exists yet. The current password of each administrator stays as a hash in `DATA_DIR/painel/administradores` (`0600`, owned by `root`), outside `.secrets/`. `painel-admin-inicial-senha.txt` is never mounted in a container.
- **Key of the backup copy:** `age` pair (X25519), generated by `age-keygen` inside the FTP image, in a disposable container without network; nothing is installed on the host. `deploy.sh` only creates the pair when **neither** of the two files exists, never rewrites the private one and, at every run, remakes the public one from it. With the public one only, the server makes copies and does not restore. Neither of the two is mounted in the services: the public one goes to the container of the copy, and the private one, only to the one of the restore, read-only.
- **Git:** [`.gitignore`](../../.gitignore) ignores `.env` and everything in `.secrets/`, keeping only `.gitkeep`.
- **`LEIAME.txt`:** rewritten by `deploy.sh` at every run, with mode `0600`. It carries only the name and the role of each file; it is never mounted in a container.
- **Image:** [`.dockerignore`](../../.dockerignore) leaves `.env` and `.secrets` out of the build context.

</details>

---

⬅️ [Security](security.md) · 🏠 [Documentation](README.md) · ➡️ [Scripts](scripts.md)
