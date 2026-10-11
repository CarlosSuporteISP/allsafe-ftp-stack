# ⌨️ Scripts — allsafe-ftp-stack

🌐 **English** · [Português (Brasil)](../pt-BR/scripts.md)

↩ [Project README](../../README.md) · [Documentation index](README.md)

## 💡 In a few words

The scripts of the stack are of two kinds. The ones you run on the host start the server, take care of the users, recover access to the panel, make and restore the backup copy and check that everything is right. The others stay inside the FTP, panel and nginx containers and are called by themselves; you do not run them directly.

<!-- diagrama: diagrams/scripts-diagram.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    usuario@{ shape: person, label: "User" }
    host@{ shape: console, label: "deploy.sh, manage-user.sh<br>and validate.sh, on the host" }
    compose@{ shape: rect, label: "Docker Compose" }
    interno@{ shape: console, label: "entrypoints and allsafe-ftp-user<br>inside the containers" }
    ftp@{ shape: rect, label: "Pure-FTPd<br>allsafe-ftp" }
    fim@{ shape: stadium, label: "service running" }

    usuario --> host --> compose --> interno --> ftp --> fim
```
<sub>Level 1 · Diagram · [source](diagrams/)</sub>

**Sequence:** User ➜ `deploy.sh`, `manage-user.sh` and `validate.sh`, on the host ➜ Docker Compose ➜ entrypoints and `allsafe-ftp-user` (inside the containers) ➜ Pure-FTPd (`allsafe-ftp`) ➜ service running

---

<details>
<summary>Contents — click to expand</summary>

[Overview](#visao-geral) · [`deploy.sh`](#deploy) · [`manage-user.sh`](#manage-user) · [`scripts/painel-senha.sh`](#painel-senha) · [`scripts/backup.sh`](#backup) · [`scripts/restaurar.sh`](#restaurar) · [`scripts/validate.sh`](#validate) · [`scripts/gerar-marca.sh`](#gerar-marca) · [`tests/testar.sh`](#testar) · [`ftp/entrypoint.sh`](#entrypoint) · [`ftp/saude.sh`](#ftp-saude) · [`ftp/porteiro.pl`](#porteiro) · [`ftp/vigia.pl`](#vigia) · [`painel/entrypoint.sh`](#painel-entrypoint) · [`nginx/entrypoint.sh`](#nginx-entrypoint) · [`nginx/saude.sh`](#nginx-saude) · [`ftp/usuario.sh`](#ftp-user) · [Support scripts](#apoio)

</details>

---

<a name="visao-geral"></a>

## 📋 Overview

| Script | Where it runs | What it is for |
|---|---|---|
| [`deploy.sh`](../../deploy.sh) | host | Installs, reapplies, updates or removes the stack in one command, without questions |
| [`manage-user.sh`](../../manage-user.sh) | host | Shortcut to create, change the password, change the folder, change the profile, adjust limits, unblock, remove and list FTP users, to exempt a user from TLS and to list, block and release addresses |
| [`scripts/painel-senha.sh`](../../scripts/painel-senha.sh) | host | Recovers access to the panel: sets the password of an administrator or creates the administrator, writing only the hash |
| [`scripts/backup.sh`](../../scripts/backup.sh) | host | Writes the encrypted backup copy of `dados/`, `auth/`, `certs/` and `painel/` to `BACKUP_DIR` |
| [`scripts/restaurar.sh`](../../scripts/restaurar.sh) | host | Returns the stack to the state of a copy, storing the current state first |
| [`scripts/validate.sh`](../../scripts/validate.sh) | host | Check of the syntax, of the brand, of the licence, of the Compose of every profile and, optionally, of the three services running |
| [`scripts/gerar-marca.sh`](../../scripts/gerar-marca.sh) | computer of whoever changes the logo | Generates the six logo and icon files of the panel from the two source artworks |
| [`tests/testar.sh`](../../tests/testar.sh) | host | Functional, security and network test suite, on a test instance the script itself creates and removes |
| [`ftp/entrypoint.sh`](../../ftp/entrypoint.sh) | container | Provisions the initial user and the certificate, starts the watcher, `pure-authd` and `pure-ftpd` and ends the container if one of them exits |
| [`ftp/saude.sh`](../../ftp/saude.sh) | container | Healthcheck: opens the control port and waits for the greeting of the server |
| [`ftp/porteiro.pl`](../../ftp/porteiro.pl) | container | Decides at every sign-in, before the password is checked, whether it may go on: refuses the address, IPv4 or IPv6, that is blocked or inside a blocked prefix, the user blocked for wrong passwords and, with per-user TLS in effect, the session without TLS of whoever was not exempted |
| [`ftp/vigia.pl`](../../ftp/vigia.pl) | container | Counts the wrong passwords of each address for each user and the errors of each address, resets the count at the right sign-in, writes the block the gatekeeper applies, hands over to the server the file received in a folder with the Upload or Read only profile, takes to the user folder the file received from an Upload only profile and publishes the network and the resources of the container for the Server tab of the panel |
| [`painel/entrypoint.sh`](../../painel/entrypoint.sh) | panel container | Checks the private network, generates the certificate of the panel, hands its copy to nginx and runs the panel |
| [`nginx/entrypoint.sh`](../../nginx/entrypoint.sh) | nginx container | Checks the private network, generates the nginx configuration and runs it, without root |
| [`nginx/saude.sh`](../../nginx/saude.sh) | nginx container | Healthcheck: requests `/saude` from the panel going through nginx |
| [`ftp/endereco.pl`](../../ftp/endereco.pl) | container | Single reading and writing of the source address, IPv4 or IPv6, and of the prefixes, used by the gatekeeper, by the watcher and by `allsafe-ftp-user`: it is what gives the file name of each block |
| [`ftp/usuario.sh`](../../ftp/usuario.sh) | FTP and panel containers | Management of the users in PureDB, of the profiles, of the limits, of the blocks by attempts and by address and of the list of who signs in without TLS, called by `manage-user.sh` and by the panel |
| [`scripts/rede-privada.sh`](../../scripts/rede-privada.sh) | host and containers | Functions that check whether an IP or a network is private and that handle the public IP option; loaded by the other scripts |
| [`scripts/ambiente.sh`](../../scripts/ambiente.sh) | host | Function that reads a key of the `.env` without executing the file; loaded by the other scripts |

The [`scripts/`](../../scripts/) folder has what runs outside the containers: on the server and, in the case of `gerar-marca.sh`, on the computer of whoever changes the logo. What runs in a container stays in the folder of the service ([`ftp/`](../../ftp/), [`painel/`](../../painel/) and [`nginx/`](../../nginx/)) and is copied to the image by the [`Dockerfile`](../../Dockerfile). The test suite is in [`tests/`](../../tests/).

---

<a name="deploy"></a>

## 🚀 `deploy.sh`

```bash
./deploy.sh [--size small|medium|large|xlarge|extended] [--atualizar] [--check-only]
./deploy.sh --remover [--apagar-dados [--sim]]
```

| Parameter | Effect |
|---|---|
| no option | Installs or reapplies: creates the `.env`, the folders and the passwords that are missing, starts the containers and waits for them to be `healthy` |
| `--size` | Writes to the `.env` the limits of `profiles/<profile>.env` and the name in `FTP_PROFILE`, after checking that the server can take the profile. Without the option, the `.env` stays as it is |
| `--atualizar` | Rebuilds the three images without cache, with the current Debian packages, and recreates the containers |
| `--check-only` | Only validates the profile, the addresses and the networks, the resources of the server and the Compose; creates and starts nothing |
| `--remover` | Takes down the containers and the network; data, secrets, `.env` and images stay |
| `--apagar-dados` | With `--remover`: also deletes `dados/`, `auth/`, `certs/`, `painel/` and `nginx/` from `DATA_DIR`, after asking you to type `apagar` |
| `--sim` | With `--apagar-dados`: skips the confirmation (required when there is no terminal) |
| `-h`, `--help` | Shows the usage |

**Expected result:** the command only ends with `allsafe-ftp`, `allsafe-ftp-painel` and `allsafe-ftp-nginx` in `healthy` and closes with `Pronto: FTP, painel e nginx no ar (healthy), perfil '<perfil>'.`, the addresses of the FTP and of the panel, the TLS mode of the FTP and the file where each password is (the password itself never appears). With `FTP_TLS_MODE` at `0` or `1`, the last thing on the screen is the `AVISO` of FTP without encryption: [Security](security.md#ftp-sem-tls). With `FTP_TLS_EXCECOES=sim`, the FTP line ends in `com exceção por usuário` and the `AVISO` is that of the exception: [Security](security.md#tls-por-usuario). With `--remover`: `Removidos os containers e a rede. Os dados continuam em <DATA_DIR>.` With `--check-only`: `OK: perfil '<perfil>', rede privada, recursos do servidor e compose validados; nada foi alterado.` With `REDE_PERMITIR_IP_PUBLICO=sim`, the summary has `endereço público aceito` in place of `rede privada` and the last thing on the screen is the `ALERTA` of public address: [Security](security.md#ip-publico).

<details>
<summary>Technical detail — behaviour and exit codes</summary>

- **It asks no question.** The only confirmation is that of `--apagar-dados`, skipped with `--sim`.
- **Requirements checked before acting:** `docker`, the `docker compose` plugin, the Docker service answering and the ports free (that of the FTP, that of the panel and the passive range, on the bind address). The ports the stack itself already publishes do not count. If it fails: `ERRO: ...` and code `1`, without starting anything.
- **Server resources checked before writing:** if the server has fewer CPUs than `FTP_CPU_LIMIT` or less memory than `FTP_MEMORY_LIMIT`, it stops with `ERRO: o perfil '<perfil>' pede ... e este servidor tem ...` and code `1`, without creating or rewriting the `.env` and without touching the containers: [Profiles](profiles.md#o-servidor-aguenta).
- **`FTP_TLS_MODE` checked before acting:** a value outside `0` to `3` stops with `ERRO: FTP_TLS_MODE deve ser 0 (sem TLS), 1 (opcional), 2 (obrigatório no login) ou 3 (obrigatório no login e nos dados)` and code `1`. At `0` and `1` the deploy goes on and warns at the end.
- **`FTP_TLS_EXCECOES` checked before acting:** a value other than `nao` and `sim` stops with `ERRO: FTP_TLS_EXCECOES deve ser 'sim' ou 'nao'` and code `1`. With `sim`, the default, the option only applies with `FTP_TLS_MODE=2` and without `REDE_PERMITIR_IP_PUBLICO=sim`: outside that the deploy goes on and says, also in `--check-only`, `TLS por usuário sem efeito: <motivo>. Ninguém é dispensado do TLS.` In effect and with a user already exempted in the panel, the deploy ends with the `AVISO: TLS por usuário: <n> usuário(s) dispensado(s) na aba Usuários do painel entram SEM TLS`.
- On the first run without a `.env`, it copies the [`.env.example`](../../.env.example), applies `0600`, says `Criado .env a partir do .env.example: tudo em 127.0.0.1, só este servidor acessa.` and **goes on**. With `--check-only` nothing is created: the validation uses the `.env.example`.
- **Idempotent:** run again without a change, it does not recreate a container, does not change a password and does not rewrite the `.env`.
- **Converts the old names, the variable:** in the `.env` of an installation older than `0.10.0`, it replaces `FTP_PUBLIC_IP` with `FTP_PASSIVE_IP`, at the same point of the file and with the same value, after copying the `.env` to `BACKUP_DIR/<data>-antes-da-migracao-de-nomes/env` (`0600`), and says `Convertido: FTP_PUBLIC_IP virou FTP_PASSIVE_IP`. The change of the name, alone, does not recreate a container; when updating from an earlier version, the three are recreated once, because the images change, and users, passwords and files stay as they were. With `--check-only`, it only warns `AVISO: esta instalação usa nomes antigos` and changes nothing.
- **Converts the old names, the secrets:** in an installation made up to `0.10.0`, it gives the new name to the three files of `.secrets/` with `mv`, without reading or copying the content, and says `Convertido: <antigo> virou <novo>.` for each one. If the old and the new one exist, the new one applies and an `AVISO` comes out. With `--check-only`, it only warns. Table of the names: [Secrets](secrets.md#nomes-antigos).
- If `.secrets/ftp-usuario-inicial-senha.txt` is empty or missing, it generates a strong password (`0600`): see [Secrets](secrets.md).
- It writes `.secrets/LEIAME.txt` (`0600`), which says what each file of the folder is for and holds no secret, and closes the summary with `Segredos: .../LEIAME.txt diz para que serve cada arquivo.`
- It says, at the end of the summary, whether the security contact is published: `Contato de segurança: <e-mail>, publicado em /.well-known/security.txt do painel.` or, with `SEGURANCA_CONTATO_EMAIL` empty, `Contato de segurança: não publicado.`, with what to fill in. It does not block the installation.
- It refuses `FTP_PASSWORD`, `PAINEL_PASSWORD` and `PAINEL_PASSWORD_HASH` in the `.env` and, by default, any `FTP_BIND_IP`, `FTP_PASSIVE_IP`, `PAINEL_BIND_IP`, `PAINEL_REDES_PERMITIDAS` or `PAINEL_CERT_CN` (in the form of an IP) outside a private network.
- **Public IP option:** `REDE_PERMITIR_IP_PUBLICO` other than `nao` and `sim` stops with `FALHA: REDE_PERMITIR_IP_PUBLICO deve ser 'nao' ou 'sim'` and code `1`. With `sim`, it accepts a public server IPv4 and a network from `/8` to `/32`, still refuses `0.0.0.0` and a wider network, requires `FTP_TLS_MODE` at `2` or `3` (`ERRO: REDE_PERMITIR_IP_PUBLICO=sim exige FTP_TLS_MODE=2 ou 3`) and shows the `ALERTA` at the end, also in `--check-only`.
- **Panel behind a proxy or tunnel:** `PAINEL_PROXY_CONFIAVEL` empty changes nothing. Filled in, each address has to be IPv4, one by one, private (or public with the public IP option) and inside `PAINEL_REDES_PERMITIDAS`, up to 8; outside that, it stops with `FALHA: PAINEL_PROXY_CONFIAVEL: …` and code `1`. Accepted, `--check-only` and the end of the deploy close with `ALERTA: PAINEL_PROXY_CONFIAVEL=…: o painel está publicado por proxy ou túnel, por opção de quem instalou.` See [Security](security.md#painel-por-proxy).
- If `.secrets/painel-admin-inicial-senha-hash.txt` does not exist, it generates the initial password of the panel in `.secrets/painel-admin-inicial-senha.txt` (`0600`) and writes its hash, calling `scripts/painel-senha.sh --inicial` after building the image.
- It checks `PAINEL_ACESSO_USUARIOS_FTP` before acting: a value other than `sim` and `nao` stops with `ERRO: PAINEL_ACESSO_USUARIOS_FTP deve ser 'sim' ou 'nao'; ...` and code `1`.
- It checks `PAINEL_AVISO_EXPOSICAO` before acting: a value other than `sim` and `nao` stops with `ERRO: PAINEL_AVISO_EXPOSICAO deve ser 'sim' ou 'nao'`.
- It checks `PAINEL_ADMIN_USER` before acting: a name outside the rule stops with `ERRO: PAINEL_ADMIN_USER inválido em .env: ...` and code `1`. In the summary, it shows the user and the file of the initial password while that file exists; afterwards, `usuário e senha: os definidos na aba Usuários ou com ./scripts/painel-senha.sh`.
- It checks `SEGURANCA_CONTATO_EMAIL` before acting: filled in with something that is not a single e-mail address, it stops with `ERRO: SEGURANCA_CONTATO_EMAIL inválido em .env: um endereço de e-mail só, como seguranca@exemplo.com.br, ou vazio.` and code `1`. Empty is accepted: the `security.txt` is not published.
- Unknown option or profile that does not exist: message `Opção inválida: ...` or `ERRO: perfil inexistente: ...` and code `64`.
- Compose is always called only with `--env-file .env`. The profile is not a second file at startup: `--size` writes its values to the `.env`, so a direct `docker compose up -d` keeps the same limits.
- Invalid combination (`--remover` with `--size`, `--apagar-dados` without `--remover`, `--sim` without `--apagar-dados`): `Opção inválida: ...`, the usage and code `64`.
- `--apagar-dados` deletes the folders through a throwaway container without network (the files belong to the user of the container, not to that of the host) and only accepts a `DATA_DIR` with at least two folder levels.
- It builds the three images with `docker compose build` (`build --no-cache` with `--atualizar`), starts with `docker compose up -d --wait` and ends showing `docker compose ps` and the summary. The waiting time is 180 s plus a quarter of a second per passive port (192 s on `small`, 580 s on `extended`), because Docker publishes the ports one by one; above 400 ports, it says `Publicando <n> portas passivas: a subida pode levar alguns minutos.` If any container is not `healthy` in time: `ERRO: os containers não ficaram healthy. Veja o motivo com: docker compose logs --tail 50 ftp painel nginx`.

</details>

---

<a name="manage-user"></a>

## 👤 `manage-user.sh`

```bash
./manage-user.sh list                 # lists the users of PureDB
./manage-user.sh add backup-olt       # asks for the password (at least 12 characters) without echoing
./manage-user.sh add olt01 clientes/olt-01   # the same, with the chosen folder inside /data
./manage-user.sh add coletor clientes/olt-01 envio   # the same, with the profile: completo (default), envio, soenvio or leitura
./manage-user.sh perfil backup-olt    # shows the profile of the user
./manage-user.sh perfil backup-olt leitura   # changes the profile; applies at the next sign-in of the user on the FTP
./manage-user.sh passwd backup-olt    # changes the password
./manage-user.sh pasta backup-olt clientes/olt-02   # changes the folder; the files of the previous one stay in it
./manage-user.sh limites backup-olt sessoes=2 download=500 horario=0800-1800   # writes limits of the user only
./manage-user.sh limites backup-olt   # shows the limits of the user
./manage-user.sh limites backup-olt tentativas=3 minutos=30   # wrong passwords until the block and minutes of block, of the user only
./manage-user.sh retencao backup-olt ultimos=30 dias=90   # automatic cleanup of the user folder, applied by the panel
./manage-user.sh retencao backup-olt  # shows the rule of the user (ultimos= dias= turns it off)
./manage-user.sh bloqueios            # lists the blocks by attempts in effect (or only those of one user)
./manage-user.sh desbloquear backup-olt   # removes the blocks of the user (or only that of one source)
./manage-user.sh enderecos            # lists the addresses and the prefixes blocked on the FTP and on the panel
./manage-user.sh endereco-bloquear 203.0.113.7 365   # blocks the address, or changes the period of one already blocked; without the days, the period of the stack
./manage-user.sh endereco-bloquear 2001:db8::7       # the same for an IPv6 address
./manage-user.sh endereco-bloquear 198.51.100.0/24 30   # blocks the whole prefix, IPv4 or IPv6
./manage-user.sh endereco-liberar 203.0.113.7        # releases the address or the prefix: applies at the next request
./manage-user.sh limites backup-olt enviar=1         # lets the user upload files through the panel (enviar= removes it)
./manage-user.sh del backup-olt       # removes the user (the files stay in /data)
./manage-user.sh tls-dispensar olt-antiga   # lets the user sign in without TLS (device that does not speak TLS)
./manage-user.sh tls-exigir olt-antiga      # requires TLS from the user again
./manage-user.sh tls-lista                  # lists the users exempt from TLS
```

**Expected result:** `add` and `passwd` end without error and the user appears in `list`; `pasta` answers `Pasta do usuario <nome>: /data/<pasta>. Os arquivos de /data/<anterior> continuam la.`; `del` answers `Usuario removido; os dados em /data/<pasta> foram preservados.`, with the real folder of the user. `add` with a folder another user already reaches ends without error and shows one `Aviso:` line per user. `tls-dispensar` answers `Usuario <nome> dispensado do TLS: vale na proxima entrada, com FTP_TLS_EXCECOES=sim.` and `tls-exigir`, `Usuario <nome> volta a ser obrigado a usar TLS: vale na proxima entrada.`; `tls-lista` shows one name per line, or nothing. `limites` with at least one pair answers `Limites do usuario <nome> gravados: valem na proxima entrada no FTP.`; with no pair, it shows one line per limit (`sessoes=`, `download=`, `envio=`, `horario=`, `baixar=`, `tentativas=` and `minutos=`), empty where the user has none. `bloqueios` shows one line per block, `usuario=<nome> origem=<ip> senhas_erradas=<n> desde=<data hora> ate=<data hora>`, or `Nenhum bloqueio em vigor.`; `desbloquear` answers `Usuario <nome> desbloqueado (<n> endereco(s)): vale na proxima entrada no FTP.`, or `Usuario <nome> nao tem bloqueio.` `enderecos` shows one line per [blocked address or prefix](security.md#bloqueio-por-endereco), `origem=<ip ou rede/tamanho> por=<ftp|painel|manual> erros=<n> desde=<data hora> ate=<data hora>`, or `Nenhum endereco bloqueado.`; `endereco-bloquear` answers `Endereco <ip> bloqueado: <n> dia(s) a partir de agora, no FTP e no painel.`, or `Prazo do endereco <ip> alterado: <n> dia(s) a partir de agora, no FTP e no painel.` when it was already blocked, and, for a prefix, `Prefixo <rede/tamanho> bloqueado: …` and `Prazo do prefixo <rede/tamanho> alterado: …`; `endereco-liberar` answers `Endereco <ip> liberado: vale no proximo pedido.`, or `Endereco <ip> nao esta bloqueado.`, with `Prefixo` in place of `Endereco` when it is a prefix

The profile says what the user does in the folder: `completo` uploads, downloads, renames and deletes; `envio` uploads and downloads, without deleting or changing what has already arrived; `soenvio` only uploads, without listing or downloading anything; `leitura` only lists and downloads. In `add`, it comes after the folder. `perfil` with the profile name answers `Perfil do usuario <nome>: <perfil>. Vale na proxima entrada no FTP.`; a value outside the four stops with `Perfil invalido: use completo, envio, soenvio ou leitura` and code `1`. What each profile reaches and the limits of Upload and of Upload only are in [Web panel](panel.md#perfis).

The password is read from the terminal and sent through `stdin` to the container: it does not appear on the command line or in the history. The script operates the installation of the `.env` of this folder; to operate another one, point to its file: `ENV_FILE=<file> ./manage-user.sh list`. Rules and use cases in [Operation](operation.md#usuarios).

---

<a name="painel-senha"></a>

## 🔑 `scripts/painel-senha.sh`

Recovers access to the panel from the host. Day to day, user and password are changed in the panel itself, in the Users tab.

```bash
./scripts/painel-senha.sh                           # asks for the new password twice, without echoing
./scripts/painel-senha.sh --gerar                   # creates a strong password and shows it only once
./scripts/painel-senha.sh --usuario NOME --gerar    # another administrator; if NOME does not exist, it is created
```

**Expected result:** `Administrador admin com a senha trocada; painel reiniciado e sessões abertas encerradas.` For a new name, `Administrador NOME criado; ...`.

Without `--usuario`, the administrator is the one in `PAINEL_ADMIN_USER`. The password has to have at least 12 characters and only the hash is written. When to use it: [Web panel](panel.md#senha).

<details>
<summary>Technical detail — how the hash is calculated and written</summary>

- It reads `SECRETS_DIR`, `DATA_DIR`, `PAINEL_IMAGE` and `PAINEL_ADMIN_USER` from the `.env` (or from the file in `ENV_FILE`), without executing the file.
- The password can also come through standard input: `./scripts/painel-senha.sh < arquivo`.
- The `scrypt` hash is calculated **inside the panel image**, in a throwaway container without network, with the root read-only and without capabilities (`docker run --rm -i --network none --read-only --cap-drop ALL`). The host does not need Python.
- The one that writes the administrators file is the panel: the script hands the hash through standard input to `servidor.py --administrador NOME`, in the container that is running (`docker compose exec`) or, with the panel stopped, in a single-use container, without the other services (`docker compose run --rm --no-deps`). The change stays in the audit log as `admin_definido_no_host`.
- With the panel running, it restarts the `painel` service (closes all sessions and resets the block by attempts). With the panel stopped, it closes with `...; vale na próxima subida do painel.`
- When the administrator is the one in `PAINEL_ADMIN_USER`, it also rewrites the hash of `.secrets/painel-admin-inicial-senha-hash.txt`, over the same file, and deletes `.secrets/painel-admin-inicial-senha.txt`. For another administrator, the `.secrets/` folder is not touched.
- `--inicial` is for the use of `deploy.sh`: it writes only the hash of the initial password, before the first start, restarts nothing and keeps `painel-admin-inicial-senha.txt`.
- Name outside the rule: `ERRO: nome de administrador inválido: ...`, code `1`. Unknown option: code `64`. Missing `.env`, image or installation: `ERRO: ... rode ./deploy.sh primeiro`, code `1`.

</details>

---

<a name="backup"></a>

## ♻️ `scripts/backup.sh`

```bash
./scripts/backup.sh                    # writes the encrypted copy of dados/, auth/, certs/ and painel/ to BACKUP_DIR
./scripts/backup.sh --rotulo <texto>   # the same, with the text in the file name
./scripts/backup.sh --listar           # shows the copies that exist
```

**Expected result:** `Cópia gravada: <BACKUP_DIR>/<STACK_NAME>-AAAAMMDD-HHMMSS.tar.gz.age (<tamanho>, cifrada)`, the reminder that the `.env` and the secrets stay outside the copy, the one that only the private key opens it and the command to restore it.

The stack can stay up. The copy comes out encrypted with the public key of `SECRETS_DIR/backup-chave-publica.txt`, with mode `0600` and with the `.sha256` sum next to it; the reading and the encryption are done by a container without network, with `DATA_DIR` read-only. Use, content of the copy and exit codes: [Backup and restore](backup.md#fazer).

---

<a name="restaurar"></a>

## 🔁 `scripts/restaurar.sh`

```bash
./scripts/restaurar.sh <cópia>          # asks you to type 'restaurar'
./scripts/restaurar.sh <cópia> --sim    # without a question (required when there is no terminal)
./scripts/restaurar.sh --listar         # shows the copies that exist
```

**Expected result:** `Restaurado e no ar (healthy).` and, on the last line, the command to undo.

It checks the copy before changing anything, opening it with the key of `SECRETS_DIR/backup-chave-privada.txt`, stops the stack, stores the current state in a file with `antes-da-restauracao` in the name, replaces the content and starts again. `<cópia>` is the name of a file of `BACKUP_DIR` or a path; a copy without encryption, made before `0.29.0`, is still accepted, with a warning. Steps, refusals and exit codes: [Backup and restore](backup.md#restaurar).

---

<a name="validate"></a>

## 🧪 `scripts/validate.sh`

```bash
./scripts/validate.sh            # syntax of the scripts, .env.example commented, paths, brand, security policy, licence and compose config of every profile
./scripts/validate.sh --runtime  # also requires the three services running and healthy and the user in PureDB
```

**Expected result:** `painel OK: <n> módulos Python`, `idioma OK: <n> textos do painel com tradução em inglês, <n> mensagens do comando de usuários`, `.env.example OK: <n> variáveis, todas comentadas e no guia de configuração, nos dois idiomas`, `caminhos OK: nenhum arquivo do repositório cita pasta pessoal`, `marca OK: 6 arquivos em web/marca/`, `política de segurança OK: SECURITY.md aponta para SEGURANCA_CONTATO_EMAIL, sem endereço fixo`, `licença OK: LICENSE (Apache-2.0), NOTICE, MARCA.md e a linha SPDX em <n> arquivos de código`, `compose OK com <perfil>.env` for each profile and, at the end, `Validacao FTP concluida.` With `--runtime`, also `servico ftp: running, healthy`, the same for `painel` and `nginx`, and `usuario inicial '<usuário>' presente no PureDB`. Any failure ends with a code other than zero.

<details>
<summary>Technical detail — what each mode checks</summary>

| Mode | Checks |
|---|---|
| no parameter | `bash -n` on `deploy.sh`, `manage-user.sh` and on the scripts of `scripts/`, `ftp/`, `painel/`, `nginx/` and `tests/`; if the host has `python3`, the syntax of each module of `painel/` and that every name used in each one is defined or imported in it, without importing or writing anything; that each text of the screens has a translation in the English catalogue ([`painel/idioma_en.py`](../../painel/idioma_en.py)), with the same names in braces, the same HTML marks and the same quotation marks, that no translation is left over and that each error message of `allsafe-ftp-user` has its own; in the `.env.example`, that each variable has a comment on the line above and is in [Configuration](configuration.md); that no file of the repository cites a personal folder of a computer (check made only when the folder is a Git repository; the local `.env` stays out); in [`web/marca/`](../../web/marca/), that the six brand files exist and are PNG or ICO; that [`SECURITY.md`](../../SECURITY.md) exists, cites `SEGURANCA_CONTATO_EMAIL` and has no fixed e-mail address; that the [`LICENSE`](../../LICENSE) is the official text of Apache-2.0, checked by the sha256, that the [`NOTICE`](../../NOTICE) has the authorship line and the GitHub address, that [`MARCA.md`](../../MARCA.md) exists and that each code file has the line `SPDX-License-Identifier: Apache-2.0` in one of the first two lines; `docker compose config --quiet` with `.env.example` and each file of `profiles/` |
| `--runtime` | everything above, plus: the services `ftp`, `painel` and `nginx` in `running` and `healthy`, and the initial user, read from `FTP_USER` in the `.env`: present in the user database (`pure-pw show`) or removed by the administrator (mark `/auth/usuario-inicial.criado`) |

The `--runtime` mode checks the installation of the `.env` of this folder. To check another one, point to its file: `ENV_FILE=<file> ./scripts/validate.sh --runtime`. Without the file, the script stops with `ERRO: ... não há instalação para conferir.`

Refusal of the paths: `ERRO: pasta pessoal em arquivo do repositório; use o padrão do .env.example ou leia o valor do .env:`, followed by the file and the line.

Refusal of the security policy: `ERRO: <arquivo> falta, não cita SEGURANCA_CONTATO_EMAIL ou traz um endereço de e-mail fixo.`, for `SECURITY.md` and for `SECURITY.pt-BR.md`

Refusals of the licence: `ERRO: LICENSE falta ou não é o texto oficial da Apache-2.0.`, `ERRO: NOTICE falta ou está sem a linha de autoria e o endereço do GitHub.`, `ERRO: MARCA.md falta.`, `ERRO: TRADEMARK.md falta.` and `ERRO: <arquivo> sem a linha SPDX-License-Identifier: Apache-2.0 no começo.` The licence line goes on the first line of the code file or, when it starts with `#!`, on the second.

</details>

---

<a name="gerar-marca"></a>

## 🎨 `scripts/gerar-marca.sh`

Generates, in [`web/marca/`](../../web/marca/), the six logo and icon files the panel uses, from the two artworks of [`web/marca/fonte/`](../../web/marca/fonte/). It only runs when the logo changes: the generated files stay in the repository and the installation does not use this script. The step by step of the change is in [Web panel](panel.md#marca).

```bash
./scripts/gerar-marca.sh                        # white plate behind the artwork
MARCA_PLACA='#f0f3f6' ./scripts/gerar-marca.sh  # another plate colour, in the format #rrggbb
```

**Expected result:** one line per file, with the size in bytes, and, at the end, `Marca gerada em web/marca/. Rode ./deploy.sh para o painel passar a usar.` Running again with the same artworks generates identical files.

<details>
<summary>Technical detail — what is generated</summary>

| File | Side | Source artwork | Where the panel uses it |
|---|---|---|---|
| `favicon.ico` | 16, 32 and 48 pixels in the same file | `allsafe-simbolo-512.png` | Icon of the browser tab |
| `icone-32.png` | 32 pixels | `allsafe-simbolo-512.png` | Icon of the browser tab |
| `icone-192.png` | 192 pixels | `allsafe-simbolo-512.png` | Icon on a high-density screen and on a shortcut |
| `apple-touch-icon.png` | 180 pixels | `allsafe-simbolo-512.png` | Shortcut on the home screen of the phone |
| `simbolo-64.png` | 64 pixels | `allsafe-simbolo-512.png` | Symbol in the menu of every screen |
| `logo-320.png` | 320 pixels | `allsafe-logo-2048.png` | Logo of the sign-in screen |

- **Light plate:** the artwork is dark on a transparent background and the panel has a dark background. Each file comes out with the artwork, in the original colours, on a plate with rounded corners, which looks the same on a light or dark browser tab. `MARCA_PLACA` changes the colour of the plate; the default is `#ffffff`.
- **How it is assembled:** the artwork is trimmed at the border, centred on the plate with a 10% margin, assembled at 1024 pixels and reduced to the final size. The files come out with 128 colours in 8 bits, without metadata or date: the six add up to 22 KB.
- **Source artworks:** they are not changed, and do not go into the nginx image ([`.dockerignore`](../../.dockerignore)).
- **Dependency:** ImageMagick 7 (command `magick`), only on the computer of whoever changes the logo. The server does not need it.
- **Refusals:** `ERRO: o ImageMagick 7 (comando magick) não está instalado neste computador.`, `ERRO: faltam as fontes ...` and `ERRO: MARCA_PLACA aceita só cor no formato #rrggbb.`

</details>

---

<a name="testar"></a>

## 🧪 `tests/testar.sh`

Runs the test suite of the stack: functional, security and network. The script starts a separate test instance, tests, writes the results and removes everything it created. The installation of this folder is not touched and may be running or not.

```bash
./tests/testar.sh                        # starts the test instance, tests, writes the results and removes
./tests/testar.sh --resultados <pasta>   # writes the results to another folder
./tests/testar.sh --manter               # leaves the test instance running to investigate
./tests/testar.sh --limpar               # only removes the test instance and its folder
```

**Expected result:** one line per case, with `✅` or `❌`, the summary of each suite with the path of the result file and, at the end, `Bateria aprovada: nenhum desvio.` The run takes about 1 hour.

> ⚠️ The test instance only starts on a private IP: `TESTE_IP` outside the private ranges is refused before any container starts. The public IP option is tested with documentation addresses (`203.0.113.0/24` and `198.51.100.0/24`), without publishing a port outside the test IP.

| Exit | Meaning |
|---|---|
| `0` | all cases passed |
| `1` | some case had a deviation; the result file says which one and shows the evidence |
| `2` | wrong usage or requirement missing on the host |
| `3` | a secret appeared in a result file; the file is deleted |

<details>
<summary>Technical detail — the test instance, the variables and what each suite covers</summary>

**Requirements on the host:** `docker` with the Compose plugin, `curl` with FTPS support, `openssl`, `ss`, `tar` and `sha256sum`. The case that checks the secrets outside Git only runs if the folder is a Git repository.

**The test instance** uses its own names, ports, subnet, data and secrets:

| Item | Test instance | Variable to change |
|---|---|---|
| Containers and images | `allsafe-ftp-teste`, `allsafe-ftp-teste-painel`, `allsafe-ftp-teste-nginx` | — |
| Address | `127.0.0.2` | `TESTE_IP` |
| FTP port | `2121` | `TESTE_FTP_PORT` |
| Panel port | `8444` | `TESTE_PAINEL_PORT` |
| Passive range | `32000` to `32019` | `TESTE_PASSIVA_INICIO` |
| Docker subnet | `172.29.2.0/29` | `TESTE_SUBNET` |
| First administrator of the panel | `gestor`, different from the default on purpose | `TESTE_ADMIN` |
| Second instance, used in the case of the two instances on the same host | `allsafe-ftp-teste-b`, following ports, `172.29.3.0/29` | `TESTE_SUBNET_B` |
| Working folder, data, secrets and backup copies | `TEMP_DIR/testar` | `TEMP_DIR`, read from the environment, then from the `.env` and, without the two, from the `.env.example` |

The passwords of the test instance are generated on the spot, stay only in `TEMP_DIR/testar` and go away with it. The script refuses to run if `TEMP_DIR/testar` already exists and was not created by it, and if the `.env` of this folder uses `STACK_NAME=allsafe-ftp-teste`.

**What each suite covers:**

| Suite | Cases | Examples |
|---|---|---|
| Functional | 73 | installation in one command, login over FTPS, upload and download with comparison, user cycle through the terminal and through the panel, restart without loss, healthcheck of the FTP, backup and restore, static files delivered by nginx, conversion of the old names by `deploy.sh`, administrators through the panel, recovery of access from the host, download through the panel (small file, subfolder, name with an accent and a 40 MiB file, with the sum checked), folder created through the panel, user with a chosen folder and folder shared between users (also in a user database of two thousand users, compared with the check of all against all), FTP user who signs in to the panel and downloads their own files, their session following the user database and the variable that turns sign-in off, their sign-in in each TLS mode, and per-user TLS: exemption and return through the panel and through the terminal, user created already exempt, the TLS card in Edit and the option without effect with a public IP, and the brand: logo and icon delivered by nginx and the authorship in the footer of every screen, the `robots.txt` and the `security.txt` with the security contact, the execution only in Docker, without systemd, the password of the initial user reapplied from the secret at every start, the licence and the authorship in the project and inside the three images, the `HEAD` of the panel equal to the `GET`, without the body, the user folder changed through the panel and through the terminal, without moving a file, the password and the folder of the initial user changed through the panel, applying until the secret changes, the file and the folder renamed and deleted through the panel, the user removed together with the folder, the per-user limits written through the panel and through the terminal and applied by the FTP, the downloads through the panel at the limit of the user, blocking by attempts on the FTP: user limit through the panel and through the terminal, block, expiry, unblock, restart and default of the stack, the transfers over FTP in the container log, and the web front end: HTTP/2 and HTTP/1.1 with the same session, the style compressed for whoever accepts gzip and the connection kept between one click and the next, and the initial user removed through the panel, which does not come back at the following start, the Server tab consistent with the machine and with the limits of each container, the profiles on the FTP: Full, Upload and Read only, each with what it can do, and the single users screen, with administrators and FTP users in the same list and the change of profile, blocking by address through the Blocks tab and through the terminal: address and prefix, IPv4 and IPv6, extend, shorten and unblock, the language: Portuguese by default, the choice stored per account and every screen in English, the upload through the panel, by the administrator and by the FTP user with their permission, and the automatic cleanup: turned on through the panel, keeping the most recent files of each folder and deleting what is past the period |
| Security | 124 | login without TLS and anonymous refused, escape from the `chroot`, isolation between users, refusals of `deploy.sh` and of the containers to a public IP, the public IP option (only with `sim`, "all" always refused, TLS required, invalid value, alert while running), CSRF, outside `Origin` and `Origin: null`, outside `Host`, limit of attempts, headers, old TLS, no secret in the `.env`, in Git, in the logs, in the audit log and in the `LEIAME.txt` of the secrets folder, sign-in that does not reveal administrator names, current password in every change to an administrator, sessions of the changed administrator closed, administrators file with the hash only, Files tab without a session, escape from the folder through the Files tab, symbolic link not followed, file delivered only as an attachment, limit of downloads at the same time, folder creation without a session and without a token, folder name that tries to leave the data folder, user tied to the chosen folder, FTP user without reach to the administration of the panel, tied to their own folder in the panel, their sign-in without a gap (same screens on refusal, administrator name, FTP server stopped, certificate replaced, block by attempts), the limits of sessions and of downloads per user, and per-user TLS: without TLS only who was exempted gets in, with nobody exempt the session without TLS is refused before the password, the change of mode does not drop a session in progress, the FTP ends if `pure-authd` dies, the option without effect or turned off, the value refused at startup and who can change the list, and the brand folder, which delivers only the six files, read-only, the addresses open without a password of the `robots.txt` and of the `security.txt`, which deliver nothing else, and the extended security: no route of the panel and no command of the FTP without login, random password on the FTP and on the panel, burst of passwords, of requests and of connections, idle connection, large or malformed request, password database out of reach of the web, of the FTP, of the other containers and of the host, cost of the FTP password according to the size, the change of folder, the rename and the delete, which do not leave the data folder nor act without a session, without a token and without the administrator password, the large folder deleted in more than one request, the per-user limits, which refuse a value outside the rule, without a session and without a token, and blocking by attempts: forged block file, name outside the user database, fall of the watcher, and unblock and limits without a session, without a token and outside the rule, and HTTP/2 and compression, which open nothing: page with a token always whole, compressed copy without an address and the limits of requests and of size applying on both protocols, no personal folder in a file of the repository, and the panel behind a proxy or tunnel: client address forged in a header ignored, with and without a declared proxy, wrong password and session counted by the client address, and the exposure warning hidden only on the screen, the Server tab out of reach of whoever is not an administrator and the state files replaced by text with markup and by a link, and the profiles: Upload does not delete, does not rename and does not write over what has already arrived, Read only writes nothing, the mode of the folders follows the change of profile, of folder and the removal, and the change of profile refused without a session, without a token, by an FTP user and with a value outside the list, and blocking by address: the sixth error blocks for 120 days on the FTP, with TLS and without, and on the panel, in IPv4 and IPv6, the one blocked on one does not get into the other, the right sign-in resets the count, the address of the stack and that of the server are not blocked by themselves, the tab for the administrator only, the new block refuses the own address and the prefix is the administrator's only, the change of language only by `POST` from the panel itself, with a token, the language cookie, which does not count as a session, the upload through the panel: forged request, name outside the rule, malformed body, escape from the folder, too many uploads at the same time and maximum size, on the panel and on nginx, and the automatic cleanup, which only the administrator sets, with their password, and which does not leave the user folder nor follow a symbolic link |
| Network | 14 | ports published only on the configured IP, address announced in passive mode, limit of sessions per IP, panel only over HTTPS, change of profile, two instances on the same host, public network on the panel only with the option, panel proxy declared address by address and inside the allowed networks |

**Organisation:** [`tests/testar.sh`](../../tests/testar.sh) prepares the test instance and loads [`tests/comum.sh`](../../tests/comum.sh), with the functions of logging, of FTP, of the panel and of writing the results. The cases are in [`tests/etapas/`](../../tests/etapas/), one file per stage, executed in the order of the name: each stage starts from the state the previous one left and does not run alone.

**Results:** three Markdown files, one per suite, with date, command, version, environment, the table of the cases with the evidence of each one and the findings. No password, token, cookie or hash is written: before ending, the script looks in the three files for the secrets it used and, if it finds any, deletes the file and exits with `3`. Without `--resultados`, they go to the plan folder, if it exists, or to `TEMP_DIR/resultados`.

**Cleanup:** when it ends, or when it is interrupted, the script removes the containers, the network, the images and the folder of the test instance. With `--manter`, nothing is removed until `--limpar`.

</details>

---

<a name="entrypoint"></a>

## ⚙️ `ftp/entrypoint.sh`

Runs at every start of the container. It has no parameters: everything comes from the variables of [Configuration](configuration.md).

1. Checks that `FTP_BIND_IP` and `FTP_PASSIVE_IP` are private IPs, or public server ones with `REDE_PERMITIR_IP_PUBLICO=sim` ([`rede-privada.sh`](../../scripts/rede-privada.sh)), reads the password from the secret `/run/secrets/ftp_usuario_inicial_senha`, adjusts owner and mode of `/data` (`0700`, of `root`), `/auth` and `/etc/ssl/private` and creates the initial user `FTP_USER`, once, leaving the mark `/auth/usuario-inicial.criado` (`0600`, with its name only); if it already exists, rewrites its password with that of the secret (refuses a password with fewer than 12 characters); if it was removed, does not recreate it, and the log says `removido pelo administrador; não é recriado`. If the password was changed through the panel and the secret has not changed since then, it is kept, and the log says `mantida a senha trocada pelo painel`. The cost of the password hash follows `FTP_MAX_CLIENTS`.
2. Generates a self-signed certificate for `FTP_CERT_CN` if `DATA_DIR/certs` is empty, and writes its public part to `/auth/ftp-cert.pem`.
3. With an Upload, Upload only or Read only profile in the user database, redoes the mode of the user folders, hands over to `ftpdata` what an upload left undelivered and takes to the user folder what stayed in the entry area of each Upload only (`allsafe-ftp-user ajustar`). Starts the [watcher](#vigia), which counts the wrong passwords, and `pure-authd`, which calls the [gatekeeper](#porteiro) at every sign-in.
4. Starts `pure-ftpd` with the TLS mode, the `chroot`, the limits and the passive range of the `.env`. With `FTP_TLS_MODE` at `0` or `1`, or with a user exempt from TLS, it first writes an `AVISO` to the log.
5. With per-user TLS in effect, starts the observer, which checks the list of exempt users every second. When it goes from empty to filled, or the opposite, only the `pure-ftpd` process that listens on the port is replaced: the sessions in progress continue and the container does not restart.
6. Keeps watching the processes: if one of them exits for another reason, it ends the container, and Docker starts it again.

**Expected result:** the lines `vigia: pronto: 5 senhas erradas do mesmo endereço bloqueiam o usuário para ele por 15 min; ...` and `FTP pronto em 2121/tcp; TLS=2; TLS por usuário: nenhum dispensado, sessão sem TLS recusada antes da senha; passivo=30000-30049` in the container log; with one exempt user, `FTP pronto em 2121/tcp; TLS=2 com exceção por usuário (1 dispensado(s) do TLS); passivo=30000-30049`. At each change, the line `TLS por usuário: a lista dos dispensados mudou; o FTP troca o modo de entrada sem derrubar as sessões em andamento.` comes before a new `FTP pronto`. With the option without effect, the startup says `TLS por usuário sem efeito: só vale com FTP_TLS_MODE=2; está <modo>.` or `TLS por usuário sem efeito: não vale com REDE_PERMITIR_IP_PUBLICO=sim (...)`, and goes on.

<details>
<summary>Technical detail — process 1 and failure messages</summary>

With `init: true`, process 1 of the container is `tini`, which starts the entrypoint. The entrypoint stays alive, with the watcher, `pure-authd` and `pure-ftpd` as children, passes the stop signal on to them and, if one of the three exits by itself, ends the others and exits with code `1`.

When a validation fails, the script exits with `FALHA: <motivo>`:

| Message | When |
|---|---|
| `FALHA: segredo /run/secrets/ftp_usuario_inicial_senha ausente` | `.secrets/ftp-usuario-inicial-senha.txt` does not exist: run `deploy.sh` |
| `FALHA: FTP_PASSWORD não é aceita` | there is a password in an environment variable; it is only read from the secret |
| `FALHA: FTP_BIND_IP=… não é IP privado` (or `FTP_PASSIVE_IP`) | the address is outside the private ranges and the public IP option is at `nao`; the container restarts in a loop until fixed |
| `FALHA: FTP_BIND_IP=… não é um endereço IPv4 de servidor` (or `FTP_PASSIVE_IP`) | with the option at `sim`, the value is `0.0.0.0`, multicast or reserved |
| `FALHA: REDE_PERMITIR_IP_PUBLICO deve ser 'nao' ou 'sim'` | the option has another value |
| `FALHA: REDE_PERMITIR_IP_PUBLICO=sim exige FTP_TLS_MODE=2 ou 3` | the option is on with the TLS of the FTP at `0` or `1` |
| `FALHA: FTP_USER invalido` | the name does not follow `^[a-z_][a-z0-9_-]{0,31}$` |
| `FALHA: a senha FTP deve ter pelo menos 12 caracteres` | short password or empty file |
| `FALHA: faixa passiva invalida` | start or end not numeric |
| `FALHA: faixa passiva fora dos limites` | below `1024`, above `65535` or inverted |
| `FALHA: FTP_TLS_MODE deve ser 0, 1, 2 ou 3` | value outside the list |
| `FALHA: FTP_MAX_CLIENTS deve ser um inteiro maior que zero` (or `FTP_MAX_CLIENTS_PER_IP`) | the limit of sessions is not an integer from 1 to 99999 |
| `FALHA: FTP_TLS_EXCECOES deve ser 'nao' ou 'sim'` | the per-user exception has another value |
| `FALHA: FTP_BLOQUEIO_TENTATIVAS deve ficar entre 0 e 100 (0 desliga o bloqueio por tentativa)` | the limit of wrong passwords of the stack is not an integer from 0 to 100 |
| `FALHA: FTP_BLOQUEIO_MINUTOS deve ficar entre 1 e 1440` | the minutes of block of the stack are not an integer from 1 to 1440 |
| `FALHA: /auth/bloqueios é link simbólico: remova-o` | the folder of the blocks, in `DATA_DIR/auth`, was replaced by a link |
| `FALHA: BLOQUEIO_ENDERECO_ERROS deve ficar entre 0 e 100 (0 desliga o bloqueio por endereço)` | the limit of errors per address is not an integer from 0 to 100 |
| `FALHA: BLOQUEIO_ENDERECO_HORAS deve ficar entre 1 e 720` | the hours in which the errors of an address add up are not an integer from 1 to 720 |
| `FALHA: BLOQUEIO_ENDERECO_DIAS deve ficar entre 1 e 3650` | the days of block of the address are not an integer from 1 to 3650 |
| `FALHA: /auth/enderecos é link simbólico: remova-o` | the folder of the blocks by address, in `DATA_DIR/auth`, was replaced by a link |
| `FALHA: o vigia não abriu o soquete /dev/log: o FTP não sobe sem a contagem das senhas erradas` | the watcher did not start |
| `FALHA: o pure-authd não abriu o soquete /run/pure-authd.sock: o FTP não sobe sem o porteiro` | `pure-authd` did not start |
| `FALHA: o pure-authd saiu: o container encerra para ninguém entrar sem a conferência do porteiro` (or `o vigia saiu`, `o pure-ftpd saiu`, or `o observador da lista do TLS saiu`) | one of the watched processes stopped after startup; Docker starts the container again |

It is not a failure, and the container starts: `AVISO: FTP_TLS_MODE=0, FTP sem TLS: senhas e arquivos trafegam em texto puro. Só para equipamento sem suporte a TLS, em rede interna isolada.` (or `FTP_TLS_MODE=1, TLS opcional: ...`). The warning repeats at every start while the mode is on. With `FTP_TLS_EXCECOES=sim`, the warning is `AVISO: FTP_TLS_EXCECOES=sim: <n> usuário(s) marcado(s) no painel entram sem TLS, com senha e arquivos em texto puro. ...`.

The fix for each one is in [Troubleshooting](troubleshooting.md#o-container-nao-sobe). The full startup model is in [Architecture](architecture.md#subida).

</details>

---

<a name="ftp-saude"></a>

## 🩺 `ftp/saude.sh`

It is the healthcheck of the FTP container, installed as `/usr/local/sbin/allsafe-ftp-saude`. It is not called directly: Docker runs it every 20 seconds.

<details>
<summary>Technical detail — what it checks</summary>

It opens the control port (`127.0.0.1:2121`, from inside the container), waits up to 4 seconds for the greeting of the server and closes the connection with `QUIT`. It considers healthy the greeting `220` (ready) and also `421` (connection limit reached: the server is full, but answering). Port closed, or open without a greeting, counts as a failure: after five failures in a row Docker marks the container as `unhealthy`. The test does not log in and uses no password. Before opening the port it requires the socket `/run/pure-authd.sock` and `/dev/log`: without `pure-authd` or without the watcher, the FTP does not count as healthy.

To run it by hand: `docker compose exec ftp /usr/local/sbin/allsafe-ftp-saude; echo $?` (`0` = answering).

</details>

---

<a name="porteiro"></a>

## 🚪 `ftp/porteiro.pl`

It is the gatekeeper of the FTP, installed in the image as `/usr/local/sbin/allsafe-ftp-porteiro`. It is not called directly: `pure-authd` runs it at every sign-in, before the password is checked. It does not check the password: it only decides whether the sign-in may go on to it.

**Expected result:** the sign-in without an impediment goes on to the password check. The address with [blocking by address](security.md#bloqueio-por-endereco) in effect, or inside a blocked prefix, gets `530` with any account. The user with [blocking by attempts](security.md#bloqueio-por-tentativa) in effect for the address gets `530`. With per-user TLS in effect and some user exempt, the session without TLS of whoever was not exempted gets `530`, and the container log gains the line `porteiro: entrada sem TLS recusada: usuario=<nome> origem=<ip> (a senha enviada passou em texto puro: troque-a)`.

<details>
<summary>Technical detail — what it answers</summary>

- It receives from `pure-authd`, in environment variables, the name (`AUTHD_ACCOUNT`), whether the session has TLS (`AUTHD_ENCRYPTED`) and the source address (`AUTHD_REMOTE_IP`). The password also arrives in a variable and is **not** read, written or logged.
- It answers `auth_ok:0`, the "not mine" answer, when none of the three rules refuses: `pure-ftpd` goes on to PureDB, which checks the password. It answers `auth_ok:-1`, the definitive refusal, when one of them refuses: the client gets `530` with the right or the wrong password.
- **Blocking by address**, the first rule: the source, IPv4 or IPv6, is read and written by [`ftp/endereco.pl`](../../ftp/endereco.pl), in the same way as in the watcher and in the panel. The gatekeeper refuses when it is not of the server itself (`127.0.0.0/8`, `0.0.0.0/8` and `::/16`) and there is the regular file `/auth/enderecos/<origem>`, or a file of `/auth/prefixos` whose network covers it, with the first line starting with a number of up to 12 digits greater than the current time. It applies to any name, with TLS or without. An expired file or one outside that format does not block.
- **Single writing of the address:** IPv4 without a leading zero; IPv6 in lowercase and compressed; the IPv6 that carries an IPv4 (`::ffff:a.b.c.d`) counts as the IPv4; an address with a zone is refused. The prefix is the network with the size, from `/8` to `/31` in IPv4 and from `/16` to `/127` in IPv6, and its file is `/auth/prefixos/<rede>_<tamanho>`. Called as a program, `endereco.pl alvo <texto>` writes `endereco <endereço>` or `prefixo <rede>/<tamanho>`, and exits with `1` when the text is neither one nor the other and with `2` when it is of the server itself: that is how `allsafe-ftp-user` checks what the administrator asks to block.
- **Per-user TLS**, only with the option in effect (`FTP_TLS_EXCECOES=sim`, `FTP_TLS_MODE=2` and no public IP accepted), which the entrypoint marks in `/run/allsafe/tls-por-usuario`: with nobody exempt, `pure-ftpd` refuses the session without TLS before the password and the gatekeeper is not even called; with someone, the session without TLS only goes on when the name is on a whole line of `/auth/sem-tls.lista`. A missing or unreadable list counts as an empty list: nobody gets in without TLS. The refusal leaves a mark in `/run/allsafe/recusa/`, so that the watcher does not count it as a wrong password.
- **Blocking by attempts:** it refuses when there is the regular file `/auth/bloqueios/<usuario>@<origem>` and its first line starts with a number of up to 12 digits greater than the current time. An expired file or one outside that format does not block.
- Only the name inside the rule `^[a-z_][a-z0-9_-]{0,31}$` and the source in address format become a file path or a log line. In the log, the name outside the rule becomes `(nome fora da regra)` and the source outside the format becomes `?`: what the client sent does not go raw to the log. The line goes out through the error output of process 1 of the container, because `pure-authd` closes that of the script.

</details>

---

<a name="vigia"></a>

## 👁️ `ftp/vigia.pl`

It is the watcher of the FTP sign-ins, installed in the image as `/usr/local/sbin/allsafe-ftp-vigia`. It is not called directly: the entrypoint starts it before the server. It counts the wrong passwords of each address for each user, writes the block the gatekeeper applies and writes each sign-in and each transfer to the container log. It also publishes the network counters and the resources of the container (processor, memory and processes, with the limits), which the Server tab of the panel shows.

**Expected result:** at startup, `vigia: pronto: 5 senhas erradas do mesmo endereço bloqueiam o usuário para ele por 15 min; limite próprio do usuário em Editar, na aba Usuários do painel`, with the values of the `.env`. Afterwards, one line per sign-in and per transfer in the container log:

| Line | When |
|---|---|
| `vigia: entrada: usuario=<nome> origem=<ip>` | Right sign-in; the count of that address for the user goes back to zero |
| `vigia: entrada recusada: usuario=<nome> origem=<ip> senhas_erradas=<n> de <limite>` | Wrong password, added up |
| `vigia: entrada bloqueada: usuario=<nome> origem=<ip> senhas_erradas=<n> minutos=<m>` | The wrong password completed the limit and the block was written |
| `vigia: entrada recusada pelo bloqueio: usuario=<nome> origem=<ip>` | Attempt made during the block |
| `vigia: entrada recusada: usuario=<nome> origem=<ip> (bloqueio por tentativa desligado)` | The limit of the user, or that of the stack, is `0` |
| `vigia: entrada recusada: usuario=<nome> origem=<ip> (não está no cadastro)` | Name inside the rule, with no user under it |
| `vigia: entrada recusada: usuario=<nome> origem=<ip> (rede interna da stack: não conta para o bloqueio)` | Wrong password of the FTP user on the panel screen |
| `vigia: entrada recusada: nome fora da regra, origem=<ip>` | The name sent does not fit the rule of names; it does not go to the log |
| `vigia: envio: usuario=<nome> origem=<ip> bytes=<n> arquivo=<caminho>` | File received over FTP; the path is the one inside the container, from `/data` |
| `vigia: download: usuario=<nome> origem=<ip> bytes=<n> arquivo=<caminho>` | File downloaded over FTP |
| `vigia: renomeado: usuario=<nome> origem=<ip> nomes=[<de>]->[<para>]` | File or folder renamed or moved over FTP; the names are the ones the client sent |
| `vigia: apagado: usuario=<nome> origem=<ip> arquivo=<caminho>` | File deleted over FTP |
| `vigia: entrega nao feita (<motivo>): usuario=<nome> arquivo=<caminho>` | The file received in a folder with the Upload or Read only profile could not be passed to `ftpdata`, or the one received from an Upload only profile could not be taken to the user folder: the folder or the file is gone, or is a symbolic link. In Upload only, the file stays in the entry area and the next start of the service tries again |
| `Entrega nao feita (<motivo>): /data/.entrada/<nome>/<arquivo>` and `AVISO: ficou arquivo sem entrega em /data/.entrada/<nome>` | At the start of the service, at the change of profile or at the removal of the user, an item of the entry area of Upload only is not a regular file of `ftpsoenvio` and stayed where it was |

<details>
<summary>Technical detail — how it counts</summary>

- **Where the notice comes from:** `pure-ftpd` only reports the wrong password through the system log. The watcher opens the socket `/dev/log`, for `root` only, and reads each line the server writes there. The line is checked from start to end: what the client typed only appears at its end, and only the name inside the rule becomes a count.
- **The password does not reach it:** the notice has the name and the address.
- **Limit and period:** those of the user, in `/auth/limites.lista` (`tentativas=` and `minutos=`), or those of the stack (`FTP_BLOQUEIO_TENTATIVAS` and `FTP_BLOQUEIO_MINUTOS`). The user database and the list are read again when the file changes.
- **Count:** in memory, per user and address, only of the wrong passwords newer than the minutes of block; up to 10,000 pairs. Restarting the container resets the count in progress and does not remove a block.
- **Block:** the file `/auth/bloqueios/<usuario>@<endereco>`, `0600`, written by rename, with until when it applies, since when and how many wrong passwords; up to 4,096 files. Every minute, the watcher deletes the expired and the invalid ones.
- **Blocking by address:** besides the count per user, it adds up the user name and password errors of each address, with any name, registered or not, within `BLOQUEIO_ENDERECO_HORAS`; up to 10,000 addresses in memory. The error that goes over `BLOQUEIO_ENDERECO_ERROS` writes `/auth/enderecos/<endereco>`, `0600`, by rename, with until when it applies (`BLOQUEIO_ENDERECO_DIAS`), since when, how many errors and `ftp`; up to 10,000 files. It applies to IPv4 and IPv6, in the single writing of [`ftp/endereco.pl`](../../ftp/endereco.pl). The internal network of the stack, the refusal of the gatekeeper for lack of TLS and the attempt made during a block do not count; the outbound address of the container and those of the server itself are never blocked. The expired ones go out in the same cleanup every minute, which also deletes the expired prefixes of `/auth/prefixos`.
- **Right sign-in:** the sign-in accepted by the server (`<nome> is now logged in`) resets the count of that address for the user and the count of the address. A block already written does not go away with it: only at the end of the period or by the administrator.
- **Prefix:** the watcher never writes a prefix. Only the administrator blocks a whole network, through the panel or through `manage-user.sh`; the watcher and the gatekeeper only respect it, and the error coming from an address covered by a prefix is an attempt during a block, which does not count.
- **Network:** every 5 s, it adds up the counters of the interfaces of the container in `/proc/net/dev`, except `lo`, and writes a line of seven numbers to `/auth/rede.estado` (`0600`): instant, seconds of the interval, bytes received and sent since the container started, bytes received and sent in the interval, and errors and drops. It writes by rename, with the lock of the user database (`/auth/.lock`), only when the counters change and once more when the traffic stops; with the lock taken, that reading is not published. A failure in the reading or in the writing does not stop the watcher.
- **Resources of the container:** in the same 5 s cycle, it reads the control group of the container (`/sys/fs/cgroup`) and writes a line of twelve numbers to `/auth/recursos.estado` (`0600`): instant, instant at which the watcher started, milliseconds of the interval, microseconds of processor spent in it, quota and period of the processor limit, memory in use and limit, processes and limit, times the processor limit held the container back and times memory ran out. Limit `0` means no limit. It publishes on the first two readings and, afterwards, when the use changes (1% of a core, 1 MiB of memory, processes or counters) or every minute, in the same way as the network: by rename, with the lock of the user database.
- **What does not count:** address of the internal network of the stack, refusal of the gatekeeper for lack of TLS, attempt during the block, name outside the user database and name outside the rule.
- **Why Perl:** the FTP image has no Python, and `perl-base` already comes in the Debian base image. The watcher uses only its modules, with no new package.
- **Transfers:** `pure-ftpd` reports through the same log each file uploaded, downloaded, renamed and deleted, and the watcher writes the line. The file name goes last, and the size is read from the end of the notice: a name chosen by the client does not pass for another field. The notice is recognised by its beginning, which is the server's: a deleted file whose name imitates the end of an upload is still logged as deleted. A control character and a text direction character become `?`; a name in UTF-8 passes; the path is cut at 400 characters. What was done through the panel stays in its audit log, not here.
- Warning and error of `pure-ftpd` go on to the container log as `vigia: pure-ftpd: <texto> origem=<ip>`; connection, exit, folder created and folder deleted are not repeated.
- If the watcher stops, the entrypoint ends the container: without it, nobody else would be blocked.

</details>

---

<a name="painel-entrypoint"></a>

## 🖥️ `painel/entrypoint.sh`

Runs at every start of the panel container. It has no parameters: everything comes from the variables of [Configuration](configuration.md#painel).

1. Refuses a password in a variable, requires the secret `/run/secrets/painel_admin_inicial_senha_hash` and checks `PAINEL_ADMIN_USER` and `SEGURANCA_CONTATO_EMAIL`.
2. Checks that `PAINEL_BIND_IP`, each network of `PAINEL_REDES_PERMITIDAS` and `PAINEL_CERT_CN` (if it is an IP) are private, or public ones accepted with `REDE_PERMITIR_IP_PUBLICO=sim`.
3. Adjusts owner and mode of `/painel` (`0700`, of `root`) and of the administrators file (`0600`, of `root`), also after a restore, and generates the self-signed certificate of the panel when it is missing, when the addresses change or when fewer than 30 days are left before it expires.
4. Prepares the `/nginx` folder (`0750`, group `10001`, that of nginx): copies the certificate and the key to `/nginx/tls`, deletes the socket of the previous start and creates `/nginx/estado` (`0700`, of the nginx user), the folder in which nginx publishes the resources of its container.
5. Runs the server [`painel/servidor.py`](../../painel/servidor.py), the entry point of the [panel modules](panel.md#modulos), which opens the socket `/nginx/painel.sock`. The panel opens no network port.

**Expected result:** the line `Painel pronto no soquete /nginx/painel.sock, atrás do nginx; sessão de 240 min; redes permitidas: ...` in the container log.

<details>
<summary>Technical detail — failure messages</summary>

| Message | When |
|---|---|
| `FALHA: PAINEL_PASSWORD não é aceita` (or `PAINEL_PASSWORD_HASH`) | there is a password or hash in an environment variable; the panel only reads the secret |
| `FALHA: segredo /run/secrets/painel_admin_inicial_senha_hash ausente` | `.secrets/painel-admin-inicial-senha-hash.txt` does not exist: run `deploy.sh` |
| `FALHA: PAINEL_BIND_IP=… não é IP privado` (or `PAINEL_CERT_CN`) | address outside the private ranges, with the public IP option at `nao` |
| `FALHA: PAINEL_REDES_PERMITIDAS: '…' não é rede privada` | the list has a public network or `0.0.0.0/0`, with the public IP option at `nao` |
| `FALHA: PAINEL_PROXY_CONFIAVEL: …` | the list of proxies has a whole network, a value that is not IPv4, a public address without the public IP option, an address outside `PAINEL_REDES_PERMITIDAS` or more than 8 addresses |
| `FALHA: PAINEL_BIND_IP=… não é um endereço IPv4 de servidor` (or `PAINEL_CERT_CN`) | with the option at `sim`, the value is `0.0.0.0`, multicast or reserved |
| `FALHA: PAINEL_REDES_PERMITIDAS: '…' não é uma rede IPv4 aceita` | with the option at `sim`, the network is wider than `/8`, such as `0.0.0.0/0` |
| `FALHA: REDE_PERMITIR_IP_PUBLICO deve ser 'nao' ou 'sim'` | the option has another value |
| `FALHA: PAINEL_REDES_PERMITIDAS está vazia` | the variable reached the container empty |
| `FALHA: PAINEL_ACESSO_USUARIOS_FTP deve ser 'sim' ou 'nao'` | the sign-in of the FTP users has another value |
| `FALHA: PAINEL_AVISO_EXPOSICAO deve ser 'sim' ou 'nao'` | the exposure warning on the screen has another value |
| `FALHA: FTP_TLS_EXCECOES deve ser 'nao' ou 'sim'` | the per-user TLS exception has an invalid value, the same check as in the FTP container |
| `FALHA: PAINEL_ADMIN_USER inválido: ...` | the name of the first administrator has an uppercase letter, a space, more than 32 characters or a character outside `a-z`, `0-9`, `_` and `-` |
| `FALHA: SEGURANCA_CONTATO_EMAIL inválido: ...` | the security contact is filled in and is not a single e-mail address: it has `mailto:`, a space, two addresses, `%`, or a domain without a dot |
| `FALHA: FTP_MAX_CLIENTS deve ser um inteiro maior que zero` | the limit of sessions of the FTP, which the panel uses to write the password with the cost of the size, is not an integer from 1 to 99999 |
| `FALHA: PAINEL_CERT_CN inválido` | name with an uppercase letter, a space or a character outside `a-z`, `0-9`, `.` and `-` |
| `FALHA: pastas /auth e /data ausentes` | the panel started without the folders of the `ftp` service |
| `FALHA: pasta /nginx ausente` | the panel started without the folder `DATA_DIR/nginx`, through which nginx reaches it: run `deploy.sh` |
| `FALHA: não foi possível gerar o certificado do painel` | `DATA_DIR/painel` without space or without write permission |

The certificate is EC P-256, valid for 825 days. The file `painel-san.txt`, next to it, marks that it was generated by the stack: without that file, the certificate is treated as your own and is never redone. The copy to `/nginx/tls` is redone at every start (certificate `0644`, key `0640`): it is the one nginx presents to the browser. See [Web panel](panel.md#certificado).

</details>

---

<a name="nginx-entrypoint"></a>

## 🚦 `nginx/entrypoint.sh`

Runs at every start of the nginx container, already as an unprivileged user (`10001`). It has no parameters: it receives only `TZ` and `PAINEL_REDES_PERMITIDAS`.

1. Refuses to run as root.
2. Checks that each network of `PAINEL_REDES_PERMITIDAS` is private, or a public one accepted with `REDE_PERMITIR_IP_PUBLICO=sim`.
3. Waits up to 30 seconds for the socket of the panel (`/nginx/painel.sock`) and for the copy of the certificate (`/nginx/tls`).
4. Generates the configuration in `/run/nginx/nginx.conf` from [`nginx/nginx.conf.modelo`](../../nginx/nginx.conf.modelo), replacing the marker of the networks with one `allow` line for each allowed network.
5. Puts in the background the publication of the resources of the container: every 5 s it reads its control group and writes to `/estado/recursos.estado` (`0600`) the same line of twelve numbers as the watcher of the ftp, when the use changes or every minute. Without the `/estado` folder, it warns in the log and starts all the same.
6. Tests the configuration and runs `nginx`.

**Expected result:** the line `nginx pronto em 8443/tcp (HTTPS), à frente do painel; redes permitidas: ...` in the container log.

<details>
<summary>Technical detail — failure messages</summary>

| Message | When |
|---|---|
| `FALHA: o nginx desta stack não roda como root: confira 'user' no compose.yaml` | the service was changed to start as root |
| `FALHA: PAINEL_REDES_PERMITIDAS está vazia` | the variable reached the container empty |
| `FALHA: PAINEL_REDES_PERMITIDAS: '…' não é rede privada. Por padrão esta stack é só para rede interna.` | the list has a public network or `0.0.0.0/0`, with the public IP option at `nao` |
| `FALHA: PAINEL_PROXY_CONFIAVEL: …` | the list of proxies has a whole network, a value that is not IPv4, a public address without the public IP option, an address outside `PAINEL_REDES_PERMITIDAS` or more than 8 addresses |
| `FALHA: PAINEL_REDES_PERMITIDAS: '…' não é uma rede IPv4 aceita` | with the option at `sim`, the network is wider than `/8`, such as `0.0.0.0/0` |
| `FALHA: REDE_PERMITIR_IP_PUBLICO deve ser 'nao' ou 'sim'` | the option has another value |
| `FALHA: soquete do painel ausente em /nginx/painel.sock: o serviço painel está no ar?` | the panel did not start or `DATA_DIR/nginx` is not mounted in the two containers |
| `FALHA: certificado do painel ausente ou ilegível em /nginx/tls` | the panel did not copy the certificate, or the permission of the folder was changed by hand |
| `FALHA: configuração do nginx recusada` | the template was edited and became invalid; the error of `nginx -t` appears right above |

The generated configuration stays in `tmpfs` and goes away when the container stops: the template, inside the image, is what rules. `127.0.0.1` always goes into the list of networks, for the healthcheck.

</details>

---

<a name="nginx-saude"></a>

## 🩺 `nginx/saude.sh`

It is the healthcheck of the nginx container, installed as `/usr/local/sbin/allsafe-nginx-saude`. It is not called directly: Docker runs it at intervals.

<details>
<summary>Technical detail — what it checks</summary>

It opens a real TLS connection on `127.0.0.1:8443`, from inside the container, and requests `/saude`. It only considers it healthy if the answer is `HTTP/1.1 200` with the body `ok`. Since the request goes through nginx and reaches the panel through the socket, a single test checks both. The certificate chain is not checked, so that the test also holds with a certificate from an internal authority.

</details>

---

<a name="ftp-user"></a>

## 👥 `ftp/usuario.sh`

Installed in the FTP and panel images as `/usr/local/sbin/allsafe-ftp-user`. It is not called directly: use [`manage-user.sh`](../../manage-user.sh) or the [panel](panel.md#usuarios).

<details>
<summary>Technical detail — what it does inside the container</summary>

- It accepts `add|passwd|pasta|del|list|tls-dispensar|tls-exigir|tls-lista [usuario] [pasta] [perfil]`, with the folder only in `add` and in `pasta` and the profile only in `add`, `perfil <usuario> [completo|envio|soenvio|leitura]`, `ajustar`, and `limites <usuario> [sessoes=N] [download=KB] [envio=KB] [horario=HHMM-HHMM] [baixar=N] [tentativas=N] [minutos=N] [enviar=1]`, and validates the name (`^[a-z_][a-z0-9_-]{0,31}$`).
- The folder, when given, has up to 4 levels separated by `/`; each level matches `[A-Za-z0-9_][A-Za-z0-9._-]{0,63}`. Outside that, it answers `Pasta invalida: ...` and exits with code `1`, before reading the password.
- It reads the password from `stdin` and refuses fewer than 12 characters with `Senha deve ter pelo menos 12 caracteres`.
- `add` refuses a name that already exists (`Usuario ja existe`), checks the folder level by level (symbolic link or file in the path: `Pasta recusada: ...`), creates the missing levels with owner `ftpdata` and mode `0750` and registers the user with `pure-pw useradd`, with the folder as the `chroot` directory. Without the folder, it uses `/data/<usuario>`.
- If another user has the same folder, one above or one inside, `add` completes and writes `Aviso: /data/<pasta> e dividida com o usuario <nome> ...`, one line per user.
- `add` and `passwd` pass to `pure-pw` the `-C` option with the `FTP_MAX_CLIENTS` of the container, which sets the cost of the `argon2id` hash of the password; a value that is not an integer greater than zero stops with `FTP_MAX_CLIENTS deve ser um inteiro maior que zero` and code `1`.
- The profile is the system identity written in the user database: `completo` is `ftpdata:ftpdata`, `envio` is `ftpenvio:ftpdata`, `soenvio` is `ftpsoenvio:ftpsoenvio` and `leitura` is `ftpleitura:ftpleitura`. `add` without a profile creates `completo`; a profile outside the four stops with `Perfil invalido: use completo, envio, soenvio ou leitura` and code `1`, before reading the password.
- In `soenvio`, the `chroot` directory written in the user database is the entry area, `/data/.entrada/<usuario>` (`0700` of `ftpsoenvio`, inside `/data/.entrada`, `0700` of `root`), and the user folder goes in the description field, without the `/data/`. `list` shows both: `<usuario>`, `/data/.entrada/<usuario>/./` and the folder. An area that goes through a symbolic link, or that exists and is not a folder, stops with `Area de entrada recusada: ...` and code `1`.
- The one that moves the file is [`ftp/entrada.pl`](../../ftp/entrada.pl), installed as `/usr/local/lib/allsafe/entrada.pl` and loaded by the watcher: it opens the source and the destination level by level from `/data`, without following a symbolic link, links the file at the destination with `link()`, which does not replace what exists, checks that it is the same file, passes it to `ftpdata` and removes it from the area. A repeated name gets `-AAAAMMDD-HHMMSS` before the extension, and a number when even that repeats. Called as a program, with the user and the folder, it delivers what stayed in the area and exits with `1` if something could not be delivered.
- `perfil` without the profile name shows that of the user. With it, it writes only the uid and the gid of the user, with `pure-pw usermod -u -g`: the password, the folder and the files do not change. Going into `soenvio` or leaving it also changes the `chroot` directory: on going in, the entry area is created; on leaving, what stayed in it is delivered to the user folder and it is deleted; if something could not be delivered, the area stays, with `Aviso: ficou em /data/.entrada/<usuario> o que nao pode ser entregue em /data/<pasta>.`
- After `add`, `perfil`, `pasta` and `del`, the mode of each user folder is redone according to who reaches it: `0750` with `completo` only, plus group write and the sticky bit with an `envio` (`1770`), plus read for others with a `leitura` (`0755` or `1775`). The inner folders follow when the mode changes; the folder that left the user database goes back to what the other users ask for.
- `ajustar` is for the start of the `ftp` service: it redoes the mode of the folders, passes to `ftpdata` the single-name folders and files that still belong to `ftpenvio`, delivers what stayed in the entry area of each `soenvio` and deletes the empty folders from it. It is not for use with a session open.
- `passwd` uses `pure-pw passwd`; `del` uses `pure-pw userdel`, does **not** delete the folder and says which one it is. In `soenvio`, it first delivers what stayed in the entry area and deletes the area. The one that deletes the folder together with the user is the panel, after the `del`: [Web panel](panel.md#usuarios).
- `pasta` requires a user that exists (`Usuario nao existe: <nome>`), checks and creates the folder as `add` does and writes only the directory of the user, with `pure-pw usermod -d`, or, in `soenvio`, only the description, with `-c`: the password and the other fields of the user database do not change, and no file is moved or deleted. It warns about the shared folder as `add` does.
- `passwd` of the initial user (`FTP_USER`) also writes `/auth/senha-inicial.trocada` (`0600`), with its name only: it is what makes the entrypoint keep that password while the secret does not change.
- `del` of the initial user writes `/auth/usuario-inicial.criado` and deletes the mark of the password: the entrypoint does not recreate it. `add` with its name writes the two marks: the user comes back with the password given.
- `tls-dispensar` and `tls-exigir` put the name in and take it out of `/auth/sem-tls.lista` (`0600`), one name per line, in order. They only accept a user that exists: otherwise, `Usuario nao existe: <nome>` and code `1`. The list is written to a file next to it and renamed, so that it is never read halfway, and at each writing the names that are no longer in the user database leave it. `del` takes the user out of the list; `tls-lista` shows it. The FTP reads the list again every second: the change applies in moments, without restarting.
- `limites` requires a user that exists and checks all the pairs before writing: `sessoes` from 1 to 99999, `download` and `envio` from 1 to 10000000, `baixar` from 1 to 8 and `horario` in `HHMM-HHMM`, with the start different from the end. A value outside the rule stops with `Limite invalido: ...` and code `1`; an unknown key or a pair without `=`, with the usage and code `2`. Sessions, rates and schedule go to the user database with `pure-pw usermod` (`-y`, `-t`, `-T` and `-z`), and an empty value removes the limit; `baixar` goes to `/auth/limites.lista` (`0600`), one line `<usuario> baixar=<n>` per user, written next to it and renamed like the TLS list. With no pair, it shows the limits, with the rates in KB per second and the schedule with four digits on each side. `del` takes the user out of the list.
- `limites` with `enviar=1` gives the user the permission to upload files through the panel, and `enviar=` removes it; another value stops with `Limite invalido: enviar aceita vazio ou 1`. The pair goes to the line of the user in `/auth/limites.lista`, does not touch the FTP user database and is read by the panel at each upload: it applies at once. See [Upload file through the panel](panel.md#enviar-arquivo).
- `endereco-bloquear` and `endereco-liberar` pass what they received through [`ftp/endereco.pl`](../../ftp/endereco.pl) and write or delete the file in the single writing: address in `/auth/enderecos/<endereco>`, up to 10,000, and prefix in `/auth/prefixos/<rede>_<tamanho>`, up to 1,000, both `0600`, with `manual` at the end of the line. The days go from 1 to 3650; without them, `BLOQUEIO_ENDERECO_DIAS` applies. Errors, with code `1`: `Endereco invalido: use um IPv4, um IPv6 ou um prefixo, como 203.0.113.7, 2001:db8::7 ou 203.0.113.0/24`, `Endereco nao bloqueavel: <texto> e do proprio servidor`, `Prazo invalido: de 1 a 3650 dias` and `Teto de <n> enderecos bloqueados: libere algum antes` (or `prefixos`).
- `retencao` requires a user that exists and checks the pairs before writing: `ultimos` from 1 to 100000 and `dias` from 1 to 3650. Both go to the line of the user in `/auth/limites.lista`, without touching its other pairs, and an empty value removes that part. With no pair, it shows the rule in two lines, `ultimos=` and `dias=`. The command only writes: the one that deletes the files is the panel, every `PAINEL_RETENCAO_MINUTOS`. `pasta` removes the rule of the user and warns in one more line: it was turned on looking at the previous folder. See [Automatic cleanup](panel.md#limpeza).
- After each change, it regenerates `pureftpd.pdb` with `pure-pw mkdb` and keeps the two files at `0600`.
- Before changing, it takes the lock `/auth/.lock` (`flock`, waits up to 30 seconds): the FTP, `manage-user.sh` and the panel never write at the same time.
- `list` passes the file through the variable `PURE_PASSWDFILE`, because `pure-pw list` does not accept `-f` right after the action.
- Invalid usage: it shows the accepted forms, `Uso: ... add|passwd|pasta|del|list|tls-dispensar|tls-exigir|tls-lista [usuario] [pasta] [perfil]`, `... perfil <usuario> [completo|envio|soenvio|leitura]`, `... limites <usuario> [sessoes=N] [download=KB] [envio=KB] [horario=HHMM-HHMM] [baixar=N] [tentativas=N] [minutos=N] [enviar=1]`, `... retencao <usuario> [ultimos=N] [dias=N]`, `... bloqueios [usuario]`, `... desbloquear <usuario> [origem]`, `... enderecos`, `... endereco-bloquear <endereco ou prefixo> [dias]` and `... endereco-liberar <endereco ou prefixo>`, and exits with code `2`.

</details>

---

<a name="apoio"></a>

## 🧩 Support scripts

They are not executed: other scripts load them with `source`.

| Script | Function | Who uses it |
|---|---|---|
| [`scripts/rede-privada.sh`](../../scripts/rede-privada.sh) | `ip_privado` and `cidr_privado` accept only `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12` and `192.168.0.0/16`; `ip_utilizavel` and `cidr_utilizavel` say what passes with the public IP option (IPv4 from `1` to `223` in the first octet, network from `/8` to `/32`); `exigir_ip` and `exigir_rede` apply the rule and write the `FALHA`; `conferir_opcao_ip_publico` refuses a value other than `nao` and `sim`; `aviso_ip_publico` writes the `ALERTA` | `deploy.sh`, `tests/testar.sh`, `ftp/entrypoint.sh`, `painel/entrypoint.sh` and `nginx/entrypoint.sh` |
| [`scripts/ambiente.sh`](../../scripts/ambiente.sh) | `env_valor <chave> [padrão]`: reads a key of the `.env` without executing the file; the last occurrence applies, as in Compose. `env_gravar <chave> <valor>`: replaces the line of the key or appends it at the end, without rewriting when the value is already the one asked for | `deploy.sh`, `manage-user.sh`, `painel-senha.sh`, `backup.sh`, `restaurar.sh`, `validate.sh` and `testar.sh` |

---

⬅️ [Secrets](secrets.md) · 🏠 [Documentation](README.md) · ➡️ [Operation](operation.md)
