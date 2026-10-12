# ♻️ Backup and restore — allsafe-ftp-stack

🌐 **English** · [Português (Brasil)](../pt-BR/backup.md)

↩ [Project README](../../README.md) · [Documentation index](README.md)

## 💡 In a few words

One command keeps everything that belongs to the stack: the files uploaded by the devices, the users, the certificates and the history of the panel. The result is a single file, **encrypted**, with date and time in the name, written to `BACKUP_DIR`: whoever gets the file reads nothing in it without the key that stays in `.secrets/`. Another command takes the stack back to the state of that file and, before replacing anything, keeps the current state, so that the restore can be undone. The passwords in `.secrets/`, the key that opens the copy and the `.env` stay out of it: keep them apart, off the server.

<!-- diagrama: diagrams/backup-diagram.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    origem@{ shape: lin-cyl, label: "DATA_DIR<br>dados, auth, certs and painel" }
    backup@{ shape: console, label: "scripts/backup.sh<br>reads and encrypts, no network" }
    copia@{ shape: doc, label: "BACKUP_DIR<br>encrypted copy and sha256 sum" }
    restaurar@{ shape: console, label: "scripts/restaurar.sh<br>opens, keeps the current one and swaps" }
    destino@{ shape: lin-cyl, label: "DATA_DIR<br>contents of the copy" }
    fim@{ shape: stadium, label: "stack back" }

    origem --> backup --> copia --> restaurar --> destino --> fim
```
<sub>Level 1 · Diagram · [source](diagrams/)</sub>

**Sequence:** `DATA_DIR` (`dados`, `auth`, `certs` and `painel`) ➜ `scripts/backup.sh` ➜ `BACKUP_DIR` (encrypted copy and `.sha256` sum) ➜ `scripts/restaurar.sh` ➜ `DATA_DIR` (contents of the copy) ➜ stack back

---

<details>
<summary>Contents — click to expand</summary>

[What goes into the copy](#o-que-entra) · [The key of the copy](#chave) · [Making the copy](#fazer) · [Restoring](#restaurar) · [Undoing a restore](#desfazer) · [Keeping the `.env` and the secrets](#segredos) · [Restoring on another server](#outro-servidor) · [Automatic copy and cleanup](#automatica) · [Copy in S3, by the panel](#no-s3)

</details>

---

<a name="o-que-entra"></a>

## 📦 What goes into the copy

| Folder of `DATA_DIR` | What it keeps | Goes into the copy |
|---|---|---|
| `dados/` | Files uploaded by the devices, one folder per user, and `.entrada/`, the entry area of the accounts with the Upload only profile, empty outside the instant of each upload | Yes |
| `auth/` | FTP users, with the hash of each password, the limits of each one, the list of who is exempt from TLS and the blocks in effect, by attempts and by address | Yes |
| `certs/` | Certificate and private key of the FTP | Yes |
| `painel/` | Certificate and private key of the panel, the administrators (name and password hash), the `auditoria.log`, the language of the screens chosen by each account and the settings and the progress of the [destinations](panel.md#destinos) and of the system copy to S3, without their secrets | Yes |
| `nginx/` | Panel socket and copy of the certificate, remade at every start | No |

These stay out, and need to be kept apart: the `.env` and the `.secrets/` folder, where the key that opens the copy is. See [The key of the copy](#chave) and [Keeping the `.env` and the secrets](#segredos).

> ⚠️ The copy contains the hash of the passwords of the users, the private keys of the certificates and the files of the devices. That is why it comes out encrypted, with mode `0600`, in a `0700` folder. A copy that stays only on the same server does not protect against the loss of the server: take the `.tar.gz.age` and the `.sha256` to another machine or medium, and keep the private key **somewhere else**, never together with the copies.

---

<a name="chave"></a>

## 🔐 The key of the copy

The copy is encrypted with a key pair, created by `./deploy.sh` the first time and kept in `.secrets/`:

| File | What it does | Where it needs to be |
|---|---|---|
| `backup-chave-publica.txt` | Encrypts. With it a copy is made, but none is opened | On the server, for `scripts/backup.sh` and for the [copy the panel sends to S3](#no-s3) |
| `backup-chave-privada.txt` | Opens. It is the only thing that reads a copy | In a password vault, off the server. On the server, only `scripts/restaurar.sh` uses it |

> ⚠️ **Without the private key no copy opens, and there is no way to recover it.** Keep `backup-chave-privada.txt` off the server right after the installation, separate from the backup copies. Whoever has the key and a copy reads everything that is in it.

What to do in each situation:

| Situation | What to do |
|---|---|
| New installation, or update from a version before `0.48.0` | Run `./deploy.sh`: it creates the pair and warns `Gerada a chave da cópia de segurança`. Keep the private one in the vault |
| Server that makes the copy and must not open it | With the private one already in the vault, delete it from the server. `scripts/backup.sh` keeps working with the public one. To restore, bring the private one back to `.secrets/backup-chave-privada.txt`, with mode `0600` |
| Replacing the pair | Delete the two files and run `./deploy.sh`, which creates a new pair and recreates the panel container, so that the copy it sends to S3 leaves encrypted with the new key. The copies made before only open with the old private one: keep it in the vault while those copies exist |
| The public key disappeared or was changed | Run `./deploy.sh`: with the private one present, it remakes the public one from it |
| Copy made before `0.48.0`, without encryption | It still restores, with the warning `esta cópia não é cifrada`, and `--listar` marks it with `(sem cifra: feita antes da 0.48.0)`. Make a new copy and delete the old one |

`./deploy.sh` never rewrites the private key that already exists. There is no option to turn the encryption off.

---

<a name="fazer"></a>

## 💾 Making the copy

The stack can stay up; the devices keep uploading during the copy.

```bash
./scripts/backup.sh                          # writes the copy to BACKUP_DIR
./scripts/backup.sh --rotulo antes-da-troca  # the same, with a text in the name of the file
./scripts/backup.sh --listar                 # shows the copies that exist
```

**Expected result:**

```text
Cópia gravada: <BACKUP_DIR>/allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz.age (<tamanho>, cifrada)
Fora da cópia: .env e os segredos de ./.secrets. Guarde-os à parte (doc/backup.md).
Só a chave privada abre a cópia (backup-chave-privada.txt, de ./.secrets): guarde-a também fora deste servidor.
Restaurar: ./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz.age
```

Next to each copy stays a `.sha256` file, with the sum that the restore checks before using the copy. `--listar` shows `Cópias em <BACKUP_DIR>:` and one line per file, with the size, and the mark `(sem cifra: feita antes da 0.48.0)` on the old copies; with no copy at all, `Nenhuma cópia em <BACKUP_DIR>.`

The label accepts lowercase letters, numbers and hyphen, up to 40 characters. The copy takes close to the size of `DATA_DIR/dados` after compression: check the free space in `BACKUP_DIR` before the first one.

<details>
<summary>Technical detail — how the copy is made and exit codes</summary>

- **A disposable container does the reading**, because part of the files belongs to `root` and to the FTP user: `docker run --rm --network none --read-only --cap-drop ALL --cap-add DAC_READ_SEARCH`, with `DATA_DIR` mounted read-only. The container has no network and does not write to `DATA_DIR`.
- **The list of users goes in whole:** `auth/` is copied with the same lock that the panel and `manage-user.sh` use (`/auth/.lock`, wait of up to 30 seconds) and the lock is released right after. A change of user never stays half done in the copy.
- **Stream encryption:** inside the container, the output of `tar` with `gzip` goes straight to `age` (Debian package, only in the FTP image), which encrypts to the public key in `SECRETS_DIR/backup-chave-publica.txt` (X25519 and ChaCha20-Poly1305). Nothing unencrypted reaches the disk, and the container does not receive the private key. Each block of the copy is authenticated: one changed byte or a cut in the file makes the opening fail.
- **The file only appears when ready:** the writing is done to `<name>.parcial` and renamed at the end. If the command is interrupted, the partial file is deleted.
- **Owner and mode preserved:** `tar` writes the user and group numbers (`--numeric-owner`), and the restore gives them back the same.
- **Name of the file:** `<STACK_NAME>-AAAAMMDD-HHMMSS[-label].tar.gz.age`.
- **No rotation:** the script does not delete an old copy. See [Automatic copy and cleanup](#automatica).
- **Another installation:** `ENV_FILE=<file> ./scripts/backup.sh` copies the installation of that environment file.

| Exit | Meaning |
|---|---|
| `0` | copy written. With `AVISO: algum arquivo mudou enquanto era lido`, an upload was in progress: the copy is valid, but that file may be incomplete |
| `1` | nothing was written. The `ERRO:` message tells the reason: `.env`, image or public key absent (run `./deploy.sh`), invalid public key, `DATA_DIR/auth` nonexistent, `BACKUP_DIR` inside `DATA_DIR`, failure in the reading or failure in the encryption |
| `64` | invalid option, label outside the format or `--rotulo` without text |

</details>

---

<a name="restaurar"></a>

## 🔁 Restoring

The restore **replaces** the current contents of `dados/`, `auth/`, `certs/` and `painel/` with those of the copy. The stack stops during the swap and starts again at the end; in that interval the devices cannot upload.

```bash
./scripts/restaurar.sh --listar                                            # choose the copy
./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz.age        # asks you to type 'restaurar'
./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz.age --sim  # without the question, for automation
```

The copy can be given only by the name, searched in `BACKUP_DIR`, or by the full path. The private key has to be in `.secrets/backup-chave-privada.txt`: see [The key of the copy](#chave).

**Expected result:**

```text
Cópia: <BACKUP_DIR>/allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz.age (<tamanho>, <n> itens, soma sha256 conferida)
Parando a stack...
Estado atual guardado em: <BACKUP_DIR>/allsafe-ftp-stack-AAAAMMDD-HHMMSS-antes-da-restauracao.tar.gz.age
Subindo a stack...
Restaurado e no ar (healthy).
Usuários, arquivos, certificados, administradores do painel e auditoria voltaram ao estado da cópia.
A senha do usuário inicial do FTP é a de ./.secrets, que não faz parte da cópia, ou a trocada pelo painel, se a cópia a trazia.
Desfazer: ./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS-antes-da-restauracao.tar.gz.age
```

What changes after restoring:

- Users created after the copy cease to exist; those removed after it come back.
- Each user comes back with the password and the folder it had in the copy. The initial user (`FTP_USER`) stays with the password in `.secrets/ftp-usuario-inicial-senha.txt`; if in the copy its password had been changed through the panel and the file has not changed since then, the one in the copy holds. If in the copy it had already been removed, it stays removed.
- The passwords come back with the cost with which they were stored. A copy made before `0.29.0`, or on a smaller size, brings passwords with the previous cost: the Security tab of the panel lists whose, and the current cost takes effect when the password is changed.
- The administrators of the panel come back as those of the copy, each one with the password it had: whoever was created after it ceases to exist and everyone signs in again. A copy made before `0.22.0` has no administrators: the panel creates the one in `PAINEL_ADMIN_USER` with the hash in `.secrets/painel-admin-inicial-senha-hash.txt`.
- If the stack was stopped, it stays stopped: `Restaurado. A stack estava parada e continua parada: suba com ./deploy.sh`.

> ⚠️ The copy is checked before any change. If the sum does not match, if the file does not open with the key or if it is not a copy of this stack, the command stops with `ERRO: ... Nada foi tocado.` and the stack goes on as it was.

<details>
<summary>Technical detail — order of the steps, refusals and exit codes</summary>

Order of what the script does:

1. Checks the copy: the sum of the `.sha256` (if the file exists next to it; without it, it warns `soma não conferida` and goes on), the opening of the whole copy with the private key in `SECRETS_DIR/backup-chave-privada.txt` (a copy without encryption, made before `0.48.0`, is read directly and gets a warning), the presence of `auth/pureftpd.passwd` and the absence of any item outside `dados/`, `auth/`, `certs/` and `painel/`.
2. Asks for the confirmation: typing `restaurar`, or `--sim`. Without a terminal, it only runs with `--sim`.
3. Stops the containers, if they were up (`docker compose stop`).
4. Keeps the current state, also encrypted, with `scripts/backup.sh --rotulo antes-da-restauracao`. If that copy fails, nothing is changed and the stack starts again.
5. Empties the four folders and extracts the copy, through a disposable container without network, with a read-only root, `DATA_DIR` mounted and the private key mounted read-only (`--cap-drop ALL`, plus `CHOWN`, `DAC_OVERRIDE` and `FOWNER`, to give back owner and mode).
6. Starts the containers and waits for them to be `healthy` (`docker compose up -d --wait`, limit of 300 seconds), if they were up.

| Message | When |
|---|---|
| `ERRO: cópia não encontrada: ...` | the name does not exist in `BACKUP_DIR` nor as a path |
| `ERRO: a soma sha256 de ... não confere: a cópia está corrompida ou foi alterada. Nada foi tocado.` | the copy does not match the `.sha256` next to it |
| `ERRO: a cópia é cifrada e a chave que a abre não está em ... Nada foi tocado.` | `backup-chave-privada.txt` is not in `SECRETS_DIR`: bring it from the vault |
| `ERRO: ... não abre com a chave de ...: chave de outra instalação, cópia corrompida ou alterada. Nada foi tocado.` | the key is not the one of the copy, or the file was cut or changed |
| `ERRO: ... não é uma cópia cifrada nem um arquivo .tar.gz legível. Nada foi tocado.` | file of another format |
| `ERRO: ... tem itens fora de dados/, auth/, certs/ e painel/: não é uma cópia desta stack. Nada foi tocado.` | copy from another origin |
| `ERRO: ... não tem a lista de usuários (auth/pureftpd.passwd): não é uma cópia desta stack. Nada foi tocado.` | copy without the users |
| `ERRO: restauração sem terminal exige --sim.` | called by a script or `cron` without the option |
| `ERRO: confirmação não recebida; nada foi alterado.` | the word typed was not `restaurar` |
| `ERRO: a restauração falhou no meio: ...` | failure during the extraction (full disk, for example). The stack stays stopped: restore again, with the same copy or with the `antes-da-restauracao` one |

| Exit | Meaning |
|---|---|
| `0` | restored |
| `1` | refused or failed; the `ERRO:` message tells the reason |
| `64` | invalid use: unknown option, no copy given or more than one |

Another installation: `ENV_FILE=<file> ./scripts/restaurar.sh <copy>`.

</details>

---

<a name="desfazer"></a>

## ↩️ Undoing a restore

Every restore keeps first the state it found, in a file with `antes-da-restauracao` in the name. To go back to it, restore that file; the exact command appears in the last line of the restore:

```bash
./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS-antes-da-restauracao.tar.gz.age
```

**Expected result:** `Restaurado e no ar (healthy).`, with the users and the files from before the restore.

---

<a name="segredos"></a>

## 🔑 Keeping the `.env` and the secrets

The copy does not take the `.env` or the `.secrets/` folder, so that a backup file that leaks does not hand over the passwords in plain text or the key that opens it. Keep both in a password vault, separate from the copies:

| What to keep | What it is for on the way back |
|---|---|
| `.secrets/backup-chave-privada.txt` | Opens the backup copies. Without it, no encrypted copy restores |
| `.env` | Addresses, ports, profile and limits of the installation |
| `.secrets/ftp-usuario-inicial-senha.txt` | Password of the initial user of the FTP |
| `.secrets/painel-admin-inicial-senha-hash.txt` | Hash of the initial password of the first administrator of the panel |
| `.secrets/destinos/` | S3 keys, access of the rclone remote, Telegram bot token and receiving chat, written by the panel in the Destinations tab |
| `.secrets/segundo-fator/` | Key of the second factor of each account of the panel, administrator and FTP user, written by the panel at setup |

The private key is the only one with no way back: without it the copy does not open. Without the others, the stack comes back all the same: `./deploy.sh` creates a new `.env` and new passwords, and the secrets of the destinations are typed again in the Destinations tab, in **Change**; until then, the card shows the **secrets missing** tag and nothing is sent. In that case, the initial user gets the new password, which needs to be set on the device that uses it. The other users and the administrators of the panel are not affected: the hash of their password is in the copy. Details of each file in [Secrets](secrets.md).

The copy takes the list of who has the [second factor](panel.md#segundo-fator) on, but not the key of each one. If the `.secrets/segundo-fator/` folder does not come back along, the account with the factor on does not sign in (`503`): turn its factor off from the terminal (FTP user: `ftp.NAME`). At the next sign-in, the account sets up the app again, with a new key; with `PAINEL_SEGUNDO_FATOR_OBRIGATORIO=nao`, it signs in with the password only and the administrator turns it on again in the panel:

```bash
docker compose exec painel python3 /opt/painel/servidor.py --segundo-fator desligar NAME
```

---

<a name="outro-servidor"></a>

## 🚚 Restoring on another server

1. Bring the project to the new server and write the key kept in the vault to `.secrets/backup-chave-privada.txt`, with mode `0600`: without it the copy does not open. If you kept them, bring the `.env` and the rest of `.secrets/` too.
2. Install, to create the folders, the images and the containers. With the private key in place, `./deploy.sh` does not create another one and remakes the public one from it:

   ```bash
   ./deploy.sh
   ```

3. Copy the `.tar.gz.age` and the `.sha256` to the `BACKUP_DIR` folder of the new server.
4. Restore:

   ```bash
   ./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz.age
   ```

**Expected result:** `Restaurado e no ar (healthy).`, with the users and the files of the copy.

If `./deploy.sh` ran before the key arrived, it created a new pair: write the kept key over `.secrets/backup-chave-privada.txt`, run `./deploy.sh` again and restore.

If the address of the server changed, adjust `FTP_BIND_IP`, `FTP_PASSIVE_IP` and `PAINEL_BIND_IP` in the `.env` before `./deploy.sh`: see [Configuration](configuration.md). The certificate of the panel is remade by itself when the addresses change; the one of the FTP comes back as in the copy.

---

<a name="automatica"></a>

## ⏰ Automatic copy and cleanup

`backup.sh` asks no question and does not need a terminal, so it can run from the `cron` of the user that administers the stack. Example, every day at 2:30, with the result in the system log:

```bash
30 2 * * * cd /caminho/da/stack && ./scripts/backup.sh 2>&1 | logger -t allsafe-ftp-backup
```

Choose a time outside the window in which the devices upload their backups.

The script does not delete an old copy. To remove those older than 30 days, encrypted or not, together with the `.sha256` of each one:

```bash
BACKUP_DIR="$(sed -n 's/^BACKUP_DIR=//p' .env | tail -n 1)"   # the BACKUP_DIR of your .env
find "$BACKUP_DIR" -maxdepth 1 -name 'allsafe-ftp-stack-*.tar.gz*' -mtime +30 -print -delete
```

**Expected result:** the path of each file removed; no line when there is no copy older than 30 days.

To have the copy outside the server without depending on `cron`, the panel makes the same copy and sends it to an S3, with its own schedule: see [Copy in S3, by the panel](#no-s3).

---

<a name="no-s3"></a>

## ☁️ Copy in S3, by the panel

The panel makes the same copy and sends it straight to an S3 storage, without going through `BACKUP_DIR`: by the **Copy and send now** button, by schedule or by the terminal. How to set it up is in [System copy to S3](panel.md#copia-do-sistema). Each copy is two objects in the chosen folder of the bucket, and the panel deletes neither:

| Object | What it is |
|---|---|
| `<pasta>/<STACK_NAME>-AAAAMMDD-HHMMSS.tar.gz.age` | The copy, encrypted with the same public key of `scripts/backup.sh` |
| `<pasta>/<STACK_NAME>-AAAAMMDD-HHMMSS.tar.gz.age.sha256` | The sum the restore checks |

<!-- diagrama: diagrams/backup-s3-diagram.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    origem@{ shape: lin-cyl, label: "DATA_DIR<br>dados, auth, certs and painel" }
    painel@{ shape: rect, label: "panel<br>reads, encrypts and sends" }
    bucket@{ shape: bucket, label: "S3 bucket<br>encrypted copy and sha256 sum" }
    baixar@{ shape: manual, label: "download the two objects<br>to BACKUP_DIR" }
    restaurar@{ shape: console, label: "scripts/restaurar.sh<br>checks, opens and swaps" }
    destino@{ shape: lin-cyl, label: "DATA_DIR<br>contents of the copy" }
    fim@{ shape: stadium, label: "stack back" }

    origem --> painel --> bucket --> baixar --> restaurar --> destino --> fim
```

<sub>Level 1 · Diagram · [source](diagrams/)</sub>

**Sequence:** `DATA_DIR` (`dados`, `auth`, `certs` and `painel`) ➜ panel (reads, encrypts and sends) ➜ S3 bucket (encrypted copy and `.sha256` sum) ➜ download the two objects to `BACKUP_DIR` ➜ `scripts/restaurar.sh` ➜ `DATA_DIR` (contents of the copy) ➜ stack back

To restore from it:

1. Download the two objects from the bucket to the `BACKUP_DIR` folder of the server, with the tool of your S3 service. The panel does not download: it only writes to the bucket.
2. Check that the private key is in `.secrets/backup-chave-privada.txt`: see [The key of the copy](#chave).
3. Restore:

   ```bash
   ./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz.age
   ```

**Expected result:** the first line brings `soma sha256 conferida` (sum checked), and the restore ends with `Restaurado e no ar (healthy).`, as in [Restoring](#restaurar).

- The copy of the panel takes the same four folders, and the same stays out: the `.env` and the `.secrets/` folder, with the secrets of the destinations.
- After restoring, the settings of the system copy are the ones that were in the copy, and the **Last copy** line of the card starts again at **none yet**.
- On another server, without the `.secrets/destinos` folder, the card shows the tag **secrets missing**, and the schedule does not send until the S3 keys are saved again, in **Change**.
- A file that was arriving during the copy may have gone in incomplete: the card and the terminal say how many changed while being read.
- The copy of the panel and the one of `scripts/backup.sh` do not depend on each other. The one in S3 is the one that survives the loss of the server; the one in `BACKUP_DIR` is the one `restaurar.sh` finds without downloading anything.

---

⬅️ [Operation](operation.md) · 🏠 [Documentation](README.md) · ➡️ [Web panel](panel.md)
