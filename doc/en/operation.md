# 🧰 Operation — allsafe-ftp-stack

🌐 **English** · [Português (Brasil)](../pt-BR/operacao.md)

↩ [Project README](../../README.md) · [Documentation index](README.md)

## 💡 In a few words

This guide gathers the day-to-day tasks: creating the account of a new device, changing a password, installing the definitive certificate, keeping a copy of the files, reading the logs and updating the server. The accounts can also be administered in the browser, in the [web panel](panel.md); here is the path through the command line. All the commands run in the root folder of the stack.

<!-- diagrama: diagrams/users-diagram.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    usuario@{ shape: person, label: "User" }
    manage@{ shape: console, label: "manage-user.sh<br>add, passwd, pasta, del, list" }
    interno@{ shape: console, label: "allsafe-ftp-user<br>inside the container" }
    puredb@{ shape: cyl, label: "PureDB<br>virtual accounts" }
    pasta@{ shape: lin-cyl, label: "/data<br>user folder" }
    fim@{ shape: stadium, label: "account ready" }

    usuario --> manage --> interno --> puredb --> pasta --> fim
```
<sub>Level 1 · Diagram · [source](diagrams/)</sub>

**Sequence:** User ➜ `manage-user.sh` ➜ `allsafe-ftp-user` ➜ PureDB ➜ `/data` ➜ account ready

---

<details>
<summary>Contents — click to expand</summary>

[Users](#usuarios) · [Real production certificate](#certificado-real-de-producao) · [Backup of the data](#backup-dos-volumes) · [Logs](#logs) · [Image update](#atualizacao-da-imagem) · [↩️ Going back a version](#voltar-de-versao) · [Quick inspection](#inspecao-rapida) · [Stopping and removing](#parar-remover)

</details>

---

<a name="usuarios"></a>

## 👤 Users

Management from the host with [`manage-user.sh`](../../manage-user.sh). The [panel](panel.md#usuarios) does the same operations, with the same rules:

```bash
./manage-user.sh add cliente01      # creates the user and /data/cliente01 (asks for the password)
./manage-user.sh add olt01 clientes/olt-01   # creates the user in the chosen folder, /data/clientes/olt-01
./manage-user.sh passwd cliente01   # changes the password (asks for the new one)
./manage-user.sh pasta cliente01 clientes/olt-02   # changes the folder; the files of the previous one stay in it
./manage-user.sh limites cliente01 sessoes=2 download=500 horario=0800-1800   # writes limits only for this user
./manage-user.sh limites cliente01  # shows the limits of this user
./manage-user.sh limites olt01 tentativas=3 minutos=30   # blocking by attempts only for this user: 3 wrong passwords, 30 minutes
./manage-user.sh retencao olt01 ultimos=30   # automatic cleanup: keeps only the 30 most recent files of each of its folders
./manage-user.sh retencao cliente01 dias=15  # deletes the file that has been on the server for more than 15 days
./manage-user.sh retencao olt01     # shows its rule (retencao olt01 ultimos= dias= turns it off)
./manage-user.sh bloqueios          # lists whom the FTP is refusing for too many wrong passwords
./manage-user.sh desbloquear olt01  # takes the blocks off the user (or off a single address: desbloquear olt01 10.0.0.5)
./manage-user.sh enderecos          # lists the addresses and the prefixes blocked on the FTP and in the panel
./manage-user.sh endereco-liberar 203.0.113.7        # unblocks a blocked address or prefix
./manage-user.sh endereco-bloquear 203.0.113.7 365   # blocks an address, or changes the period of one already blocked
./manage-user.sh endereco-bloquear 198.51.100.0/24 30   # blocks a whole prefix, IPv4 or IPv6
./manage-user.sh list               # lists the users in PureDB
./manage-user.sh del cliente01      # removes the user and KEEPS its folder
./manage-user.sh tls-dispensar olt-antiga   # lets the user sign in without TLS (device that does not speak TLS)
./manage-user.sh tls-exigir olt-antiga      # requires its TLS again
./manage-user.sh tls-lista                  # lists who is exempt from TLS
```

**Expected result:** after `add`, the user appears in `list` and can already sign in through FTPS; after `pasta`, the answer is `Pasta do usuario <nome>: /data/<pasta>. Os arquivos de /data/<anterior> continuam la.`; after `del`, it disappears from `list` and the folder stays in the volume.

Rules:

- Name of the user: `^[a-z_][a-z0-9_-]{0,31}$`.
- Password: minimum of **12 characters** (refused below that).
- Folder: without the third parameter, it is `/data/<user>`. With it, it always stays inside `/data` (`DATA_DIR/dados` on the host), with up to 4 levels separated by `/`; each level has letters, numbers, `_`, `-` and dot, does not start with a dot and goes up to 64 characters. The folder is created if it does not exist. A folder that goes through a symbolic link or through a file is refused, and nothing is created.
- `add` of an existing name answers `Usuario ja existe`. To change the folder of someone who already exists, use `pasta`, with the same rules: it takes effect at the next sign-in, does not change the password and neither moves nor deletes a file. A user that does not exist: `Usuario nao existe: <nome>`.
- `limites` accepts one or more `key=value` pairs, and only touches the keys given: `sessoes` (sessions at the same time on the FTP), `download` and `envio` (KB per second, from 1 to 10,000,000), `horario` (`HHMM-HHMM`, in the time zone of `TZ`, and it may go past midnight), `baixar` (downloads at the same time through the panel, from 1 to 8), `tentativas` (wrong passwords on the FTP until the block, from 0 to 100; `0`: never blocked) and `minutos` (time of the block, from 1 to 1440). An empty value (`download=`) takes the limit off; without any pair, it shows those the user has. It takes effect at its next sign-in on the FTP. What each limit does is in [Web panel](panel.md#limites).
- `bloqueios` lists the blocks by attempts in effect, one per line, with the user, the address, the wrong passwords, the start and the end; with a name, only its own. With none, it answers `Nenhum bloqueio em vigor.` `desbloquear <user>` takes all the blocks off the user, and with the address at the end, only the one of that address. It takes effect at the next sign-in. Changing `tentativas` or `minutos`, changing the password and removing the user also take its blocks off: [Security](../pt-BR/seguranca.md#bloqueio-por-tentativa).
- `enderecos` lists the addresses and the prefixes with blocking by address, IPv4 and IPv6, one per line, with who blocked, the errors, the start and the end; with none, it answers `Nenhum endereco bloqueado.` `endereco-liberar <address or prefix>` takes the block off, and is the way out for the administrator whose own address got blocked. `endereco-bloquear <address or prefix> [days]` blocks an address, or a whole network, on the FTP and in the panel or, for what is already blocked, changes only the period; without the days, `BLOQUEIO_ENDERECO_DIAS` holds. A prefix is only blocked by the administrator, here or in the Blocks tab: the stack never blocks a network by itself. Everything takes effect at the next request: [Security](../pt-BR/seguranca.md#bloqueio-por-endereco).
- `del` **does not delete files** and answers with the folder that stayed. To take the folder out together with the user, use the panel: Users ➜ **Remove**, with the box to delete the folder, in [Web panel](panel.md#usuarios). After `del`, the folder that stayed is deleted in the Files tab.
- `tls-dispensar` and `tls-exigir` take effect in moments, without restarting the container and without dropping whoever is connected, and only for a user that exists (`Usuario nao existe: <nome>`). The exemption only has effect with `FTP_TLS_EXCECOES=sim` (the default), `FTP_TLS_MODE=2` and without `REDE_PERMITIR_IP_PUBLICO=sim`; outside that, it stays stored. `del` takes the user off the list.

> ⚠️ **Shared folder:** two users with the same folder, or with one inside the other, read, write and delete each other's files. `add` accepts and warns, one `Aviso:` line per user that starts sharing the folder. For a device not to reach the backup of another, give each one its own folder.

> ⚠️ **Exemption from TLS:** the exempt user sends password and file in plain text. Only for an old device that does not speak TLS, on an isolated internal network: [Security](../pt-BR/seguranca.md#tls-por-usuario).

> ⚠️ The user set in `FTP_USER` is created once, at the first start, with the password in `.secrets/ftp-usuario-inicial-senha.txt`. Its password and its folder are changed like those of the others; the changed password holds until the secret file is altered: [Secrets](secrets.md#trocar-a-senha). It is removed like the others, through the panel or with `del`, and does not come back at the following starts; to have it again, create a user with the same name. To rename it, create the new one with `add`, migrate the data and remove the old one.

<details>
<summary>Technical detail — where the change is written</summary>

`manage-user.sh` wraps [`ftp/usuario.sh`](../../ftp/usuario.sh), which runs inside the container as `allsafe-ftp-user`. The changes are written to `/auth/pureftpd.passwd` and recompiled into `/auth/pureftpd.pdb` (folder `DATA_DIR/auth` of the host). There is no need to restart the service: `pure-ftpd` consults the database at every login. The panel calls the same script, and a lock (`/auth/.lock`) prevents two changes at the same time. The exemption from TLS stays in `/auth/sem-tls.lista`, one name per line, read by the server at every sign-in. The limits of sessions, of rate and of schedule stay in the line of the user itself in the user database; the one of downloads through the panel and those of the blocking by attempts, in `/auth/limites.lista`. Each block in effect is a file in `/auth/bloqueios`.

</details>

---

<a name="certificado-real-de-producao"></a>

## 🔏 Real production certificate

The initial certificate is **self-signed**, generated at the first start. To install a real one:

```bash
# 1. Concatenate key and full chain into a single PEM (key first)
cat privkey.pem fullchain.pem > pure-ftpd.pem
chmod 600 pure-ftpd.pem

# 2. Copy to the volume, in the place of the self-signed one
docker compose cp pure-ftpd.pem ftp:/etc/ssl/private/pure-ftpd.pem

# 3. Restart the service
docker compose restart ftp
```

**Expected result:** the client connects without a certificate warning and the container goes back to `healthy`.

- The file needs to contain **key, certificate and intermediates** in the same PEM, `0600`.
- [`ftp/entrypoint.sh`](../../ftp/entrypoint.sh) only generates the self-signed one **if the file does not exist**: yours will not be overwritten.
- Renewal: repeat steps 1 to 3 (for example, by `cron` on the host, pulling from your ACME client).
- Delete the local copy of `pure-ftpd.pem` after installing: it contains the private key.

---

<a name="backup-dos-volumes"></a>

## ♻️ Backup of the data

One command keeps the files of the devices, the users, the certificates and the audit log of the panel in a file in `BACKUP_DIR`; another takes the stack back to the state of a copy:

```bash
./scripts/backup.sh                                                  # writes the encrypted copy, with the stack up
./scripts/backup.sh --listar                                         # shows the copies that exist
./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz.age  # goes back to the state of the copy
```

**Expected result:** `Cópia gravada: <BACKUP_DIR>/allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz.age (<tamanho>, cifrada)` in the first command and, in the restore, `Restaurado e no ar (healthy).`

What goes into the copy, how to keep the key that opens it, how to undo a restore, how to restore on another server and how to schedule the copy are in [Backup and restore](backup.md).

To get **a single file**, uploaded by a device, use the Files tab of the panel: [Files and download](panel.md#arquivos). The owner of the files gets its own the same way, signing in to the panel with the FTP user and password: [FTP user in the panel](panel.md#usuario-ftp). On the host, the same file is in the folder of the user, inside `DATA_DIR/dados`: the Users tab shows the path of each one.

> ⚠️ The copy contains the hash of the passwords and the private keys of the certificates, and that is why it comes out encrypted: take it off the server too. Only `.secrets/backup-chave-privada.txt` opens it: keep that key in a password vault, separate from the copies, together with the `.env` and the other files in `.secrets/`, which do not go into the copy either.

---

<a name="migracao"></a>

## 🚚 Migrating from the named volumes (installation before 0.2.0)

Up to version `0.1.x` the data stayed in named Docker volumes (`allsafe-ftp-data`, `allsafe-ftp-auth`, `allsafe-ftp-certs`). From `0.2.0` on it stays in `DATA_DIR`. The migration **copies**, it does not move: the old volumes stay intact until you decide to delete them.

```bash
docker compose down                       # 1. stops the old stack (without -v)
git pull                                  # 2. brings the new version
# 3. in the .env: add the new keys of the .env.example (DATA_DIR, BACKUP_DIR, TEMP_DIR, SECRETS_DIR,
#    STACK_NAME, FTP_CONTAINER_NAME, FTP_NETWORK_NAME) and delete FTP_PASSWORD and FTP_PASSWORD_FILE.
#    If the password was in the .env, write it to .secrets/ftp-usuario-inicial-senha.txt (chmod 600).
DATA_DIR="$(sed -n 's/^DATA_DIR=//p' .env | tail -n 1)"   # the DATA_DIR of your .env
mkdir -p "$DATA_DIR"/{dados,auth,certs}
docker build -q -t allsafe-ftp:local .    # 4. new image, used to copy
for par in allsafe-ftp-data:dados allsafe-ftp-auth:auth allsafe-ftp-certs:certs; do
  docker run --rm --network none -v "${par%%:*}":/origem:ro -v "$DATA_DIR/${par##*:}":/destino \
    --entrypoint cp allsafe-ftp:local -a /origem/. /destino/
done
./deploy.sh                               # 5. starts with the new folders
```

**Expected result:** container `healthy`, the users sign in with the same password and the files appear in the folder of each user, inside `DATA_DIR/dados`.

Only after checking, and by your decision, delete the old volumes: `docker volume rm allsafe-ftp-data allsafe-ftp-auth allsafe-ftp-certs`.

---

<a name="logs"></a>

## 📜 Logs

```bash
docker compose logs -f ftp          # follows the log (sign-ins, transfers and messages of the entrypoint)
docker compose logs --since 1h ftp  # last hour
docker compose logs -f painel       # start of the panel and warnings of the web server
docker compose logs -f nginx        # start of nginx and the requests it refused
```

**Expected result:** the line `FTP pronto em 2121/tcp; ...` of the start and, after that, one `vigia:` line per sign-in and per transfer; in the panel, the line `Painel pronto no soquete /nginx/painel.sock, atrás do nginx; ...`; in nginx, `nginx pronto em 8443/tcp (HTTPS), à frente do painel; ...`.

nginx logs only what it refuses itself, one line per request, in the format `ip method path code` (example: `10.99.0.7 GET /entrar 403`). With `FTP_TLS_MODE` at `0` or `1`, the FTP log brings at every start the `AVISO` of FTP without encryption: [Security](../pt-BR/seguranca.md#ftp-sem-tls). With `FTP_TLS_EXCECOES=sim`, it brings the `AVISO` with the number of exempt users and one line `porteiro: entrada sem TLS recusada: usuario=<nome> origem=<ip>` for each sign-in without TLS by someone who was not exempted: [Security](../pt-BR/seguranca.md#tls-por-usuario).

The watcher of the `ftp` service logs each sign-in on the FTP, with the user and the address: `vigia: entrada:` on the one that passed, `vigia: entrada recusada:` on the wrong password, with the count, and `vigia: entrada bloqueada:` when the address reaches the limit. It also logs each file uploaded (`vigia: envio:`), downloaded (`vigia: download:`), renamed (`vigia: renomeado:`) and deleted (`vigia: apagado:`) through the FTP, with the size in the first two. The lines are in [Scripts](scripts.md#vigia). To see only them:

```bash
docker compose logs ftp | grep 'vigia:'
```

**Expected result:** one line per sign-in, per refusal and per transfer, without a password; who is blocked now comes out in `./manage-user.sh bloqueios`. To see only what a user uploaded and downloaded: `docker compose logs ftp | grep -E 'vigia: (envio|download): usuario=<nome> '`.

What was done through the panel (sign-ins, sign-outs, users created, changed and removed, files downloaded) stays in `auditoria.log`, visible in the Log tab: see [Web panel](panel.md#auditoria).

Rotation by Docker: `max-size: 10m`, `max-file: 3` (see [`compose.yaml`](../../compose.yaml)).

---

<a name="atualizacao-da-imagem"></a>

## ⬆️ Image update

```bash
./deploy.sh --atualizar            # rebuilds the three images without cache and recreates the containers (data preserved)
./scripts/validate.sh --runtime    # checks the three services 'running' and 'healthy'
```

**Expected result:** `Validacao FTP concluida.` and the users and files intact. The sessions open in the panel are ended.

> `--atualizar` reinstalls the packages with the current version of the Debian repository. The profile in use is in the `.env` and stays in effect.

<details>
<summary>Technical detail — base pinned by digest</summary>

The base in the [`Dockerfile`](../../Dockerfile) is **pinned by digest**: a `docker compose build --pull` does not change the base by itself. To get a new base, update the digest of the `FROM` and run `./deploy.sh --atualizar`. While the `Dockerfile` does not change, an ordinary `docker compose build` reuses the layer that installs the packages; `--atualizar` uses `build --no-cache`, which remakes that layer and reinstalls the packages at the current version of the Debian repository. The three images (FTP, panel and nginx) come from the same base, `debian:trixie-slim` (Debian 13).

</details>

<a name="voltar-de-versao"></a>

<details>
<summary>Technical detail — going back to the previous version</summary>

The data, the users, the passwords and the certificates stay in `DATA_DIR` and in `.secrets/`, outside the code: going back a version is replacing the files of the project and starting again. Remove **first**, still with the files of the current version, because only it knows all the containers it created:

```bash
./deploy.sh --remover      # 1. current version: takes down the three containers and the network; the data stays
git checkout v0.4.0        # 2. takes the files of the project back to the tag of the previous version
./deploy.sh                # 3. starts the previous version with the same data
```

**Expected result:** the containers of the previous version in `healthy`, with the same users, passwords and certificates.

> ⚠️ `FTP_TLS_MODE=0` only exists from `0.5.0` on: before step 3, set the variable back to `1`, `2` or `3`. The new keys of the `.env` (the `NGINX_*` ones) are ignored by the previous version and can stay.

</details>

---

<a name="inspecao-rapida"></a>

## 🔍 Quick inspection

```bash
docker compose ps                                   # state and ports
docker inspect --format '{{.State.Health.Status}}' allsafe-ftp
docker inspect --format '{{.State.Health.Status}}' allsafe-ftp-painel
docker inspect --format '{{.State.Health.Status}}' allsafe-ftp-nginx
./manage-user.sh list                               # users in PureDB
docker compose exec ftp pure-pw show transfer -f /auth/pureftpd.passwd
```

**Expected result:** the three containers `running` and `healthy`, the list of users and the data of the user `transfer` (folder, uid and gid; the password appears only as a hash).

---

<a name="parar-remover"></a>

## ⏹️ Stopping and removing

```bash
docker compose stop                       # stops without removing
./deploy.sh --remover                     # removes the containers and the network; the data stays in DATA_DIR
./deploy.sh --remover --apagar-dados      # removes and deletes the folders of DATA_DIR (asks you to type "apagar")
```

**Expected result:** `docker compose ps` empty. The folders `dados/`, `auth/`, `certs/`, `painel/` and `nginx/` of `DATA_DIR` and the secrets stay on the host; deleting the data is a separate decision, only with `--apagar-dados`.

> ⚠️ The data stays in folders of the host: not even `docker compose down -v` deletes it. `--apagar-dados` **has no way back**: make the [backup](#backup-dos-volumes) first. Without a terminal (in a script), it only runs with `--sim`. The secrets and the `.env` are not deleted.

---

⬅️ [Scripts](scripts.md) · 🏠 [Documentation](README.md) · ➡️ [Backup and restore](backup.md)
