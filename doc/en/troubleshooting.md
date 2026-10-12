# 🚨 Troubleshooting — allsafe-ftp-stack

🌐 **English** · [Português (Brasil)](../pt-BR/solucao-de-problemas.md)

↩ [Project README](../../README.md) · [Documentation index](README.md)

## 💡 In a few words

When something fails, the server itself has almost always already said why. The path is always the same: see whether the container is up, read the message in the log, find the matching row in the tables of this guide, apply the fix and check again.

<!-- diagrama: diagrams/diagnosis-diagram.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    usuario@{ shape: person, label: "User<br>saw the problem" }
    estado@{ shape: console, label: "docker compose ps<br>state and health" }
    logs@{ shape: docs, label: "docker compose logs<br>FALHA message" }
    tabela@{ shape: doc, label: "tables in this guide<br>cause and fix" }
    valida@{ shape: console, label: "validate.sh --runtime<br>checks again" }
    fim@{ shape: stadium, label: "service healthy" }

    usuario --> estado --> logs --> tabela --> valida --> fim
```
<sub>Level 1 · Diagram · [source](diagrams/)</sub>

**Sequence:** User ➜ `docker compose ps` ➜ `docker compose logs` ➜ tables in this guide ➜ `validate.sh --runtime` ➜ service healthy

---

<details>
<summary>Contents — click to expand</summary>

[Diagnosis in 30 seconds](#diagnostico-em-30-segundos) · [The container does not start](#o-container-nao-sobe) · [Connects but fails at login or listing](#conecta-mas-falha-no-login-ou-na-listagem) · [Device without TLS](#ftp-sem-tls) · [File and permission](#problemas-de-arquivo-permissao) · [Certificate and TLS](#certificado-tls) · [Web panel](#painel) · [Destinations: S3 and Telegram bot](#destinos) · [Validation tools](#ferramentas-de-validacao)

</details>

---

<a name="diagnostico-em-30-segundos"></a>

## 🧭 Diagnosis in 30 seconds

```bash
docker compose ps                                               # are the three containers 'running' and 'healthy'?
docker compose logs --tail 50 ftp                               # what did the entrypoint and pure-ftpd say?
docker compose logs --tail 50 painel                            # and the panel?
docker compose logs --tail 50 nginx                             # and nginx, which sits in front of the panel?
```

**Expected result:** the three containers (`allsafe-ftp`, `allsafe-ftp-painel` and `allsafe-ftp-nginx`) `running` and `healthy` and, in the log, the lines `FTP pronto em 2121/tcp; ...`, `Painel pronto no soquete /nginx/painel.sock, atrás do nginx; ...` and `nginx pronto em 8443/tcp (HTTPS), à frente do painel; ...`. Anything different points to one of the tables below.

The three entrypoints abort with `FALHA: <motivo>` and the container restarts in a loop: the reason is always in the first attempt of the log.

---

<a name="o-container-nao-sobe"></a>

## ❌ The container does not start

| Message in the log | Cause | How to check | Fix |
|---|---|---|---|
| `ERRO: porta já em uso por outro programa: <IP>:<porta>` (in `deploy.sh`) | Another program on the host already listens on the port of the FTP, of the panel or of the passive range | `ss -ltnp` | Change `FTP_PORT`, `PAINEL_PORT` or the passive range in the `.env`, or stop the other program, and run `./deploy.sh` again |
| `ERRO: não foi possível criar as pastas em <DATA_DIR>` (in `deploy.sh`) | Whoever runs `deploy.sh` cannot write to the folder above `DATA_DIR` (by default, `/srv`, where only root writes). Nothing was built or started | `ls -ld /srv /srv/allsafe-ftp-stack` | Create the folder once for your user, with the command the message shows (`sudo install -d -o <user> /srv/allsafe-ftp-stack`), or point `DATA_DIR`, `BACKUP_DIR` and `TEMP_DIR` somewhere else in the `.env`: [Configuration](configuration.md#pastas-e-nomes). Then, `./deploy.sh` again |
| `ERRO: os containers não ficaram healthy` (in `deploy.sh`) | One of the containers stopped or did not answer in time (180 s plus a quarter of a second per passive port) | `docker compose logs --tail 50 ftp painel nginx` | Fix the cause shown in the log (the rows below cover the most common ones) and run `./deploy.sh` again |
| `ERRO: o perfil '…' pede … CPUs (FTP_CPU_LIMIT) e este servidor tem …` (or `de memória (FTP_MEMORY_LIMIT)`), in `deploy.sh` | The chosen profile is larger than the server. Nothing was changed | `nproc` and `free -m` | Use a smaller profile with `--size`: [Profiles](profiles.md#o-servidor-aguenta) |
| `ERRO: FTP_TLS_MODE deve ser 0 (sem TLS), 1 (opcional), 2 (obrigatório no login) ou 3 (…)` (in `deploy.sh`) | Value outside `0` to `3` in the `.env`. Nothing was changed | `grep '^FTP_TLS_MODE=' .env` | Use `2`, the default: [Configuration](configuration.md#tls) |
| `ERRO: Docker não encontrado`, `ERRO: plugin Docker Compose não encontrado` or `ERRO: sem acesso ao Docker` (in `deploy.sh`) | Docker stopped, no permission for the user, or no Compose plugin | `docker info` and `docker compose version` | Start Docker, join the `docker` group or install the Compose v2 plugin |
| `ERRO: ... não é uma chave age válida` (in `deploy.sh`) | `.secrets/backup-chave-privada.txt` was changed or replaced by another file. Nothing was changed in it | `ls -l .secrets/backup-chave-*.txt` | Write back the key kept in the vault. Without it, the copies made before do not open: to start a new pair, delete the two files and run `./deploy.sh`. See [Backup and restore](backup.md#chave) |
| `FALHA: segredo /run/secrets/ftp_usuario_inicial_senha ausente` | `.secrets/ftp-usuario-inicial-senha.txt` does not exist | `ls -l .secrets/` | Run `./deploy.sh`, which creates the file with a strong password. See [Secrets](secrets.md) |
| `FALHA: FTP_BIND_IP=… não é IP privado` (or `FTP_PASSIVE_IP`) | Address outside `127/8`, `10/8`, `172.16/12` and `192.168/16`; the container restarts in a loop | `grep -E "FTP_(BIND|PASSIVE)_IP" .env` | Use the **internal** IP of the server. The stack does not accept `0.0.0.0` and, by default, no public IP either: see [Security](security.md#rede-privada) |
| `FALHA: REDE_PERMITIR_IP_PUBLICO deve ser 'nao' ou 'sim'; está '…'` (in `deploy.sh` and in the three containers) | The public IP option has another value, such as `true` or `1` | `grep '^REDE_PERMITIR_IP_PUBLICO=' .env` | Use `nao`, the default. `sim` only after reading the warning: [Security](security.md#ip-publico) |
| `FALHA: …=… não é um endereço IPv4 de servidor` or `não é uma rede IPv4 aceita` | With `REDE_PERMITIR_IP_PUBLICO=sim`, the value is `0.0.0.0`, multicast, reserved or a network wider than `/8` | `grep -E '^(FTP_BIND_IP|FTP_PASSIVE_IP|PAINEL_BIND_IP|PAINEL_REDES_PERMITIDAS|PAINEL_CERT_CN)=' .env` | Give the address and the networks one by one; "all" is not accepted even with the option on |
| `REDE_PERMITIR_IP_PUBLICO=sim exige FTP_TLS_MODE=2 ou 3` (in `deploy.sh` and in the FTP container) | The public IP option is on with the FTP without TLS or with optional TLS | `grep -E '^(REDE_PERMITIR_IP_PUBLICO|FTP_TLS_MODE)=' .env` | Set `FTP_TLS_MODE` back to `2` or turn the option off. A device without TLS only on an internal network: [Security](security.md#ftp-sem-tls) |
| `FTP_TLS_EXCECOES deve ser …` (in `deploy.sh` and in the FTP and panel containers) | The per-user TLS exception has a value other than `nao` and `sim`. Nothing was changed | `grep '^FTP_TLS_EXCECOES=' .env` | Use `sim`, the default, or `nao`: [Configuration](configuration.md#tls) |
| `TLS por usuário sem efeito: só vale com FTP_TLS_MODE=2` (in `deploy.sh` and in the FTP log), and the panel without the **TLS** column | The TLS of the FTP is at `0`, `1` or `3`: the per-user exemption only exists on top of mode `2`. It is a warning, and the installation starts | `grep -E '^FTP_TLS_(EXCECOES\|MODE)=' .env` | To exempt a single device, set `FTP_TLS_MODE` back to `2` and run `./deploy.sh`: [Security](security.md#tls-por-usuario) |
| `TLS por usuário sem efeito: não vale com REDE_PERMITIR_IP_PUBLICO=sim` (in `deploy.sh` and in the FTP log), and the panel without the **TLS** column | The server accepts a public address: nobody is exempt from TLS, even if on the list. It is a warning, and the installation starts | `grep -E '^(FTP_TLS_EXCECOES\|REDE_PERMITIR_IP_PUBLICO)=' .env` | A device without TLS only on an internal network: [Security](security.md#tls-por-usuario) |
| `FALHA: o pure-authd saiu: o container encerra para ninguém entrar sem a conferência do porteiro` (or `o vigia saiu`, `o pure-ftpd saiu`, or `o observador da lista do TLS saiu`), and `allsafe-ftp` restarts | One of the FTP processes stopped. The container ends on purpose and Docker starts it again | `docker compose logs --tail 50 ftp`; `docker inspect -f '{{.RestartCount}}' allsafe-ftp` | If it happens only once, nothing to do: the FTP comes back by itself in seconds. If it repeats, collect the logs: [Validation tools](#ferramentas-de-validacao) |
| `FALHA: o pure-authd não abriu o soquete /run/pure-authd.sock: o FTP não sobe sem o porteiro` or `FALHA: o vigia não abriu o soquete /dev/log: o FTP não sobe sem a contagem das senhas erradas` | The process that checks the blocks and per-user TLS, or the one that counts the wrong passwords, did not start | `docker compose logs --tail 50 ftp` | Run `./deploy.sh` again. If it continues, collect the logs: [Validation tools](#ferramentas-de-validacao) |
| `FALHA: FTP_BLOQUEIO_TENTATIVAS deve ficar entre 0 e 100 (0 desliga o bloqueio por tentativa)` or `FALHA: FTP_BLOQUEIO_MINUTOS deve ficar entre 1 e 1440` (in the FTP and panel containers) | The default of blocking by attempts is out of range or is not a number | `grep '^FTP_BLOQUEIO_' .env` | Fix it in the `.env` and run `./deploy.sh`. The default is `5` and `15`: [Configuration](configuration.md#limites-de-sessao) |
| `FALHA: /auth/bloqueios é link simbólico: remova-o` | The folder of the blocks in `DATA_DIR/auth` was replaced by a link | `ls -ld "$DATA_DIR/auth/bloqueios"` | Delete the link and run `./deploy.sh`: the folder is recreated empty |
| `FALHA: BLOQUEIO_ENDERECO_ERROS deve ficar entre 0 e 100 (0 desliga o bloqueio por endereço)`, `FALHA: BLOQUEIO_ENDERECO_HORAS deve ficar entre 1 e 720` or `FALHA: BLOQUEIO_ENDERECO_DIAS deve ficar entre 1 e 3650` (in `deploy.sh` and in the FTP and panel containers) | The rule of blocking by address is out of range or is not a number. Nothing was changed | `grep '^BLOQUEIO_ENDERECO_' .env` | Fix it in the `.env` and run `./deploy.sh`. The default is `5`, `24` and `120`: [Configuration](configuration.md) |
| `FALHA: /auth/enderecos é link simbólico: remova-o` | The folder of the blocks by address in `DATA_DIR/auth` was replaced by a link | `ls -ld "$DATA_DIR/auth/enderecos"` | Delete the link and run `./deploy.sh`: the folder is recreated empty |
| `defina FTP_PASSIVE_IP no .env` (in any command that calls Compose) | `.env` of an installation older than `0.17.0`, still with `FTP_PUBLIC_IP` | `grep -E "^FTP_(PUBLIC|PASSIVE)_IP=" .env` | Run `./deploy.sh`: it changes the name by itself, keeps the value and stores the previous `.env` in `BACKUP_DIR`. See [Configuration](configuration.md#ftp-passive-ip) |
| `ERRO: .env ainda traz FTP_PASSWORD` (in `deploy.sh`) | `.env` of an earlier version, with a password | `grep -c "^FTP_PASSWORD" .env` | Write the password to `.secrets/ftp-usuario-inicial-senha.txt` (`chmod 600`) and delete `FTP_PASSWORD` and `FTP_PASSWORD_FILE` from the `.env` |
| `bind source path does not exist` at start | Folder of `DATA_DIR` missing (Compose does not create it) | `ls "$DATA_DIR"` | Run `./deploy.sh`, which creates `dados/`, `auth/`, `certs/`, `painel/` and `nginx/` |
| `allsafe-ftp` in `unhealthy`, with the container running and no `FALHA` in the log | `pure-ftpd` is alive, but does not answer on the control port. Docker only flags it: it does not restart the container by itself | `docker compose exec ftp /usr/local/sbin/allsafe-ftp-saude; echo $?` (`0` = answering) | `docker compose restart ftp`. If it happens again, collect the logs: [Validation tools](#ferramentas-de-validacao) |
| `FALHA: a senha FTP deve ter pelo menos 12 caracteres` | Short password, or file empty or with only a blank line | `wc -c .secrets/ftp-usuario-inicial-senha.txt` | Write it again: `printf '%s' 'senha-com-12+' > .secrets/ftp-usuario-inicial-senha.txt` |
| `FALHA: FTP_USER invalido` | Name outside `^[a-z_][a-z0-9_-]{0,31}$` | `grep '^FTP_USER=' .env` | Use lowercase, with no space or accent; start with a letter or `_` |
| `FALHA: faixa passiva invalida` or `fora dos limites` | `FTP_PASSIVE_PORT_START` or `FTP_PASSIVE_PORT_END` not numeric, below `1024`, above `65535` or inverted | `grep PASSIVE .env profiles/*.env` | Fix it in the `.env`; keep the start lower than or equal to the end |
| `FALHA: FTP_TLS_MODE deve ser 0, 1, 2 ou 3` | Invalid value | `grep '^FTP_TLS_MODE=' .env` | Use `2`, the default. `0` and `1` are only for a device without TLS: [Configuration](configuration.md#tls) |
| `bind: address already in use` | `FTP_PORT` or the passive range are already taken on the host | `ss -ltnp` | Change the port or the range, or free whoever is using it |
| `bind: cannot assign requested address` | `FTP_BIND_IP` does not exist on the host | `ip -br addr` | Set it to an IP configured on the machine |

---

<a name="conecta-mas-falha-no-login-ou-na-listagem"></a>

## 🔌 Connects but fails at login or listing

| Symptom | Likely cause | How to check | Fix |
|---|---|---|---|
| The client connects and drops when `AUTH TLS` is required | Client using **plain** FTP or **implicit** FTPS (port 990) | Client configuration; container log | Configure the client for **explicit FTP over TLS** on the control port. If the device has no TLS: [Old device](#ftp-sem-tls) |
| The client asks for TLS and the server refuses `AUTH TLS` | The server is at `FTP_TLS_MODE=0`, without TLS | `grep '^FTP_TLS_MODE=' .env`; the `AVISO` at the end of `./deploy.sh` | Go back to `FTP_TLS_MODE=2` and run `./deploy.sh`, or use mode `1` if there is an old device on the same server |
| `530 Login authentication failed` | Wrong password, user does not exist in PureDB or UID below 10000 | `./manage-user.sh list` | Set the password again with `./manage-user.sh passwd <user>` |
| `530 Login authentication failed` with the right password, only at certain hours, after about 5 seconds of waiting | The user has its own schedule and the sign-in was attempted outside it. The server answers as it answers to a wrong password | `./manage-user.sh limites <user>` shows `horario=`; `docker compose exec ftp date` shows the time the server uses | Adjust or remove the schedule in **Edit**, in the Users tab, or with `./manage-user.sh limites <user> horario=`: [Web panel](panel.md#limites) |
| `530 Login authentication failed` with the right password, at any time, only from one address | That address got the password of the user wrong too many times and is blocked for it. Until the end of the period, not even the right password gets in from there | `./manage-user.sh bloqueios <user>`; in the panel, the **blocked** mark next to the name | Fix the password on the device and remove the block: **Edit** ➜ **Unblock**, in the Users tab, or `./manage-user.sh desbloquear <user>`. Without that, it goes away by itself at the end of the period: [Security](security.md#bloqueio-por-tentativa) |
| `530 Login authentication failed` with the right password, for all users coming from one address | The address went over the limit of user name and password errors, or was blocked by the administrator, alone or inside a prefix, and is under blocking by address: it does not get into the FTP or the panel, with any account | `./manage-user.sh enderecos`; in the panel, the Blocks tab; `docker compose logs ftp \| grep 'bloqueio do endereço'` | Fix the password on the device that was getting it wrong and release the address: **Unblock**, in the Blocks tab, or `./manage-user.sh endereco-liberar <address or prefix>`, with what appears in `origem=` in the list. With several devices behind the same address, review the limit: [Security](security.md#bloqueio-por-endereco) |
| The user is blocked again right after being unblocked | The device still has the wrong password stored and retries by itself, or another device uses the same user from the same address with the old password | `docker compose logs ftp \| grep 'vigia: entrada recusada'` shows the user and the address of each wrong password | Fix the password on every device that uses that user, then unblock. Give each device its own user |
| `530 Login authentication failed` without TLS, with the right password | The user is not exempt from TLS, and another one is. The password travelled in plain text | `./manage-user.sh tls-lista`; `docker compose logs ftp \| grep porteiro` | Configure the device for TLS and change the password. If it does not speak TLS, exempt the user in the Users tab of the panel or with `./manage-user.sh tls-dispensar <user>`: [Security](security.md#tls-por-usuario) |
| A user exempt from TLS still cannot sign in without TLS (`421` or timeout) | Per-user TLS has no effect: `FTP_TLS_EXCECOES=nao`, `FTP_TLS_MODE` other than `2` or `REDE_PERMITIR_IP_PUBLICO=sim`. The list of exempt users is kept and does not apply | Security tab of the panel, row **FTP TLS**; `./deploy.sh --check-only` | Leave `FTP_TLS_EXCECOES=sim` and `FTP_TLS_MODE=2` and run `./deploy.sh`. An installation older than `0.45.0` has `FTP_TLS_EXCECOES=nao` written in the `.env` |
| Login OK, `LIST` or `STOR` hangs and times out | **Active** mode, or passive range or `FTP_PASSIVE_IP` blocked or wrong | `docker compose ps` shows the published range; test port `30000/tcp` from the client | Use **passive** mode; open the passive range of the profile on the firewall (`30000-30049/tcp` on `small`); `FTP_PASSIVE_IP` with the IP the client reaches |
| `425 Could not open data connection` | `FTP_PASSIVE_IP` points to an IP the client does not reach | `grep '^FTP_PASSIVE_IP=' .env` | Set `FTP_PASSIVE_IP` to the IP the client reaches and open the passive range up to it. By default the stack only accepts a private IP |
| Certificate error on the client | The certificate is still the self-signed one | `openssl s_client -connect SEU_IP:21 -starttls ftp` shows the issuer | Install a real certificate ([Operation](operation.md#certificado-real-de-producao)) or, only for testing, turn verification off on the client |
| `421 I can't accept more than <n> connections as the same user` | The user reached its own limit of sessions on the FTP | `./manage-user.sh limites <user>` shows `sessoes=` | Close the connections left over on the device, or raise the limit in **Edit**, in the Users tab: [Web panel](panel.md#limites) |
| Uploading a small file takes seconds | The user has an upload rate: each uploaded file takes at least 256 ÷ rate seconds, whatever the size | `./manage-user.sh limites <user>` shows `envio=` | Raise or remove the upload rate in **Edit**, in the Users tab |
| `421 Too many connections` | `FTP_MAX_CLIENTS` or `FTP_MAX_CLIENTS_PER_IP` reached | `docker compose logs --tail 50 ftp` | Move up a profile with `./deploy.sh --size medium` and open the new passive range: [Profiles](profiles.md) |

---

<a name="ftp-sem-tls"></a>

### Old device that does not speak TLS

The symptom is always the same: the device connects to the control port and the session drops before login. By default (`FTP_TLS_MODE=2`), the server refuses whoever does not ask for TLS. Confirm by simulating the device, without TLS:

```bash
curl -v --max-time 10 --user backup-olt ftp://SEU_IP:21/
```

**Expected result**, with the server at the default: `421-Sorry, cleartext sessions and weak ciphers are not accepted on this server.` and `curl` giving up right after. That is the server working as it should.

If the device really has no way to speak TLS (check the manual and the firmware version first), there are two paths. The first is to exempt from TLS only its user, in the Users tab of the panel, with the **Device without TLS support** box when creating it or with the **Exempt from TLS** button afterwards: the others remain required. The second is the modes `FTP_TLS_MODE=1` (optional) and `FTP_TLS_MODE=0` (without TLS), which apply to everyone. In either, whoever signs in without TLS sends password and file in **plain text**: read the conditions in [Security](security.md#ftp-sem-tls) before turning it on.

While there is any exempt user, the same test changes its answer: the server asks for the password and answers `530 Login authentication failed` for the user who is not exempt, even with the right password.

---

<a name="problemas-de-arquivo-permissao"></a>

## 📁 File and permission

| Symptom | Cause | How to check | Fix |
|---|---|---|---|
| `553 Could not create file` | User directory not owned by `ftpdata` (uid 10000) | `docker compose exec ftp ls -ld /data/<user>` | `docker compose exec ftp chown -R 10000:10000 /data/<user>` |
| Files arrive with an unexpected permission | The `umask` of `pure-ftpd` is `133:022` (files without execution and without write for group and others) | `docker compose exec ftp ls -l /data/<user>` | Expected behaviour; adjust `-U` in [`ftp/entrypoint.sh`](../../ftp/entrypoint.sh) if needed |
| The client cannot `chmod` | `-R` disables `SITE CHMOD` | Refusal message on the client | Intentional, for security. Remove `-R` from the entrypoint only if it is really needed |
| `ls` does not show all files | Limit `-L 10000:8` (10000 files, depth 8) | Count the files in the folder | Reduce the number of files per directory or adjust `-L` |
| The upload ends without error, but the client list comes back empty and it cannot find the file it has just sent | The user has the Upload only [profile](panel.md#perfis): it uploads and does not see the backup folder. The file is in the user folder | `./manage-user.sh perfil <user>`; the file appears in the Files tab of the panel and the `vigia: envio:` line of the log has the final path | Expected behaviour. A client that checks the upload through the list needs the Upload profile |
| The client uploads with a temporary name and fails when renaming at the end, or fails when resuming an interrupted upload | Upload only profile: the file leaves the entry area as soon as it finishes arriving, and the client no longer reaches it | `./manage-user.sh perfil <user>` | Turn off the temporary name and upload resume on the client, or use the Upload profile |
| The file arrives with the date and time in the name, such as `backup-20261009-153000.rsc` | Upload only profile: there was already a file with the same name in the folder, and the one that arrives does not replace the previous one | `docker compose exec ftp ls -l /data/<folder>` | Expected behaviour. To have a single name, upload with the date in the name or use the Full profile, which overwrites |
| In the folder there is a file smaller than expected and, next to it, the same name with the date and time | Upload only profile: the first upload was interrupted and delivered as it arrived; the new attempt got the date and time | The size of both, in the Files tab, and the `vigia: envio:` lines of the log, with the bytes of each | Delete the incomplete one through the Files tab. If the connection always drops, check the network of the device |
| `AVISO: ficou arquivo sem entrega em /data/.entrada/<usuario>` in the log of `ftp`, or `vigia: entrega nao feita` | In the entry area of an Upload only user there is an item that is not a regular file of `ftpsoenvio` (symbolic link, file with another owner), or the user folder is gone | `docker compose exec ftp ls -la /data/.entrada/<user>` and `./manage-user.sh list` | Recreate the folder with `./manage-user.sh pasta <user> <folder>`; what is a regular file is delivered at the next start of `ftp`. What is not stays in the area until removed by whoever manages the server |

---

<a name="certificado-tls"></a>

## 🔐 Certificate and TLS

| Symptom | Cause | How to check | Fix |
|---|---|---|---|
| The new certificate is not used after copying | Service not restarted, or PEM without the key | `docker compose exec ftp ls -l /etc/ssl/private/` | `docker compose restart ftp`; the PEM must have **key and certificate** together, `0600` |
| The entrypoint generates a self-signed one at every start | The file `/etc/ssl/private/pure-ftpd.pem` is not persisting | `ls -ld "$DATA_DIR/certs"` on the host | Confirm the `DATA_DIR` of the `.env` and the `certs/` folder inside it |
| TLS handshake fails with "certificate expired" | Wrong host clock, or expired certificate (the self-signed one lasts 825 days) | `date` on the host; `openssl s_client -connect SEU_IP:21 -starttls ftp` shows the validity | Synchronise the time (stack `allsafe-ntp-nts-stack`); generate or renew the certificate |

---

<a name="painel"></a>

## 🖥️ Web panel

| Symptom | Cause | How to check | Fix |
|---|---|---|---|
| The browser does not open the address (connection refused or timeout) | nginx stopped, address different from `PAINEL_BIND_IP` or firewall | `docker compose ps nginx painel`; `grep '^PAINEL_' .env` | Open it by the IP and port of the `.env`. With `PAINEL_BIND_IP=127.0.0.1` the panel only opens on the server itself |
| `pedido não aceito` (`400`) when opening with `http://` | The panel port only speaks HTTPS | The address typed | Use `https://` |
| `pedido não aceito` (`413` or another `4xx`), or the page does not load when opening a folder with a very long path | Request larger than 16 KiB, address or header larger than 5 KiB, or malformed request, refused by nginx. In HTTP/2, an address that is too large closes the connection, and the browser shows a protocol error instead of the message | `docker compose logs --tail 20 nginx` | Repeat through the browser, directly at the panel address |
| `painel indisponível; tente de novo em instantes` (`502`) | nginx is up and the panel is stopped or restarting | `docker compose ps painel`; `docker compose logs --tail 20 painel` | Wait a few seconds; if it does not come back, `./deploy.sh` |
| `pedidos demais deste endereço; aguarde alguns segundos` (`429`) | More than 20 requests per second from the same address (burst of 40) or more than 16 connections, which in HTTP/2 are 16 requests open at the same time: a script querying the panel, or several people leaving through the same address | `docker compose logs --tail 20 nginx` | Wait a few seconds. The limit is fixed in [`nginx/nginx.conf.modelo`](../../nginx/nginx.conf.modelo) |
| Certificate warning in the browser | The initial certificate is self-signed | The fingerprint shown in the Security tab | Check the fingerprint and accept, or install your own certificate: [Web panel](panel.md#certificado) |
| `cliente fora das redes permitidas` (`403`) | The client address is not in `PAINEL_REDES_PERMITIDAS`. The refusal comes from nginx and stays in its log, with the address seen | `grep '^PAINEL_REDES_PERMITIDAS=' .env`; `docker compose logs --tail 20 nginx` | Include the **private** network of whoever administers and run `deploy.sh`. To open it from the server itself, keep the subnet of the stack (`FTP_SUBNET`) on the list |
| `address not accepted` (`400`) | The panel was opened by a name it does not know, or by a public IP without `REDE_PERMITIR_IP_PUBLICO=sim` | The address typed | Open it by the private IP, or register the internal name in `PAINEL_CERT_CN` and run `deploy.sh` |
| Behind a proxy or tunnel, every access appears with the proxy address in the Log tab, and a wrong password from one person blocks the sign-in of everyone | The proxy is not in `PAINEL_PROXY_CONFIAVEL`, or does not send `X-Forwarded-For` | `grep '^PAINEL_PROXY_CONFIAVEL=' .env`; `docker compose logs --tail 5 nginx` shows the address seen in the first field | Put the address the proxy arrives with in `PAINEL_PROXY_CONFIAVEL` and run `deploy.sh`: [Security](security.md#painel-por-proxy) |
| `The submission did not come from this panel.` (`403`) when signing in through a proxy | The proxy changes the `Host`, or forwards the name without the port the browser used | On the proxy, the forwarded `Host` header | Forward the `Host` as the browser sent it (in nginx, `proxy_set_header Host $http_host`) and put the public name in `PAINEL_CERT_CN` |
| `FALHA: PAINEL_PROXY_CONFIAVEL: …` (in `deploy.sh` and in the panel and nginx containers) | The list has a whole network, a value that is not IPv4, a public address without `REDE_PERMITIR_IP_PUBLICO=sim`, an address outside `PAINEL_REDES_PERMITIDAS` or more than 8 addresses | `grep -E '^PAINEL_(PROXY_CONFIAVEL|REDES_PERMITIDAS)=' .env` | Give the proxy address, one by one and without a mask, inside the allowed networks |
| `Too many attempts. Wait a few minutes and try again.` (`429`) | Five errors in 15 minutes, coming from the same address, adding up refused sign-in and current password refused when changing an administrator | Log tab or `auditoria.log` | Wait 15 minutes, or `docker compose restart painel`, which resets the block (nginx restarts along) |
| Blank page with the text `address blocked for too many user name and password errors` (`403`), on any screen of the panel | The address of whoever accesses is under blocking by address, for errors on the FTP or on the panel or for a block by the administrator, of an address or of a prefix. It also applies to whoever already had the session open | On the server, `./manage-user.sh enderecos`; from another address, the Blocks tab | Another administrator clicks **Unblock**, or, on the server, `./manage-user.sh endereco-liberar <address or prefix>`: [Security](security.md#bloqueio-por-endereco) |
| `Could not sign in.` (`401`) | Wrong user or password; the screen does not say which of the two | The user is the one in `PAINEL_ADMIN_USER` only until it is changed in the panel: `sudo cut -d: -f1 "$DATA_DIR/painel/administradores"` lists the names | Sign in with the right name; if the password was lost, see the next row |
| `Could not sign in.` (`401`) with the user and password of the FTP | Wrong FTP password; user sign-in turned off; name equal to that of an administrator, who only signs in with the administrator password; user outside its schedule or with all its sessions taken; or FTP server stopped or full | `grep '^PAINEL_ACESSO_USUARIOS_FTP=' .env`; `docker compose ps ftp`; in the Log tab, the `entrada_falha` line with `conferencia=ftp_indisponivel` says the FTP server could not check; `./manage-user.sh limites <user>` shows the schedule and the sessions of the user | Check the password by signing in over FTP; turn sign-in on with `PAINEL_ACESSO_USUARIOS_FTP=sim` and `./deploy.sh`; with the FTP stopped, see [The container does not start](#o-container-nao-sobe) |
| The refused sign-in takes 3 to 7 seconds | The one that checks the password of the FTP user is the FTP server: less than 1 second to accept and 3 to 6 more, drawn at random, to refuse. A password stored before `0.29.0` takes about 3 seconds to be checked, until it is changed. The wrong administrator password waits the same, because the name is also checked on the FTP | — | It is expected. The sign-in of the administrator with the right password does not go through the FTP and is immediate |
| The FTP user goes back to the sign-in screen by itself | Its FTP password, folder or a limit was changed, it was removed, an administrator was created with the same name, or user sign-in was turned off | Log tab, line `FTP user session closed`, with the reason | Sign in again with the current password. With a name equal to that of an administrator, only the administrator account signs in |
| Page not found (`404`) for whoever signed in with the FTP account | The administration tabs do not exist for the FTP user | The name and the role in the panel menu | Use the My files screen; to administer, sign out and sign in with an administrator account |
| Panel password lost | The password is not stored, only the hash | — | Another administrator changes it in the Users tab; with none, `./scripts/painel-senha.sh --gerar` (another administrator: `--usuario NAME`): see [Web panel](panel.md#senha) |
| `security contact not configured` (`404`) at `/.well-known/security.txt` | `SEGURANCA_CONTATO_EMAIL` is empty, or was filled in and `deploy.sh` has not run yet | `grep '^SEGURANCA_CONTATO_EMAIL=' .env`; Security tab, item `Security contact` | Fill it in with an e-mail and run `./deploy.sh`: [Configuration](configuration.md#contato-de-seguranca) |
| `SEGURANCA_CONTATO_EMAIL inválido` in `deploy.sh` or in the panel log | The value is not a single e-mail address: it has `mailto:`, a space, two addresses or a domain without a dot | `grep '^SEGURANCA_CONTATO_EMAIL=' .env` | Leave a single address, such as `seguranca@suaempresa.com.br`, or empty, and run `./deploy.sh` |
| `Your current password does not match. Nothing was changed.` or `Nothing was deleted.` (`403`) | Every change to an administrator, every rename and every deletion of a file or folder ask for the password of whoever is in the session, not that of the administrator being changed nor that of another FTP user | The name at the top of the panel | Type your password in the **Your current password** field. Five errors block the address for 15 minutes |
| `This is your account` (`409`) | Nobody removes their own administrator account | — | Sign in with another administrator to remove this one |
| `Too many downloads at the same time` (`503`) | The panel delivers up to 8 files at a time, adding up administrators and FTP users, and up to 2 per FTP user | Log tab: downloads in progress do not appear yet; finished ones do | Wait for one to finish and repeat. The answer carries `Retry-After: 30` |
| The **Upload file** card does not appear for the FTP user, or the upload answers `Upload not allowed` (`403`) | The account does not have the permission to upload through the panel, or its profile is Read only, which does not upload. Without the permission, the user only uploads over FTP | Users tab ➜ **Edit**: the box **Allow this user to upload files through the panel**; in the Log tab, `Upload through the panel without the permission` | Tick the box and save, or `./manage-user.sh limites <user> enviar=1`. It applies at once, without closing the user's session: [Upload file through the panel](panel.md#enviar-arquivo) |
| `file too large to upload through the panel`, in plain text, or `File too large` (`413`) | The file is over `PAINEL_ENVIO_MAX_MB`. nginx cuts the upload before it reaches the panel and answers the plain text; the panel answers the screen when only the file, without the rest of the form, is over the limit | `grep PAINEL_ENVIO_MAX_MB .env` | Upload over FTP, which does not have this limit, or raise `PAINEL_ENVIO_MAX_MB` in the `.env` and run `./deploy.sh`: [Configuration](configuration.md#painel) |
| `Name already in use` (`409`) on upload | There is already a file or a folder with that name in the destination folder, and the panel never replaces what exists | The folder list | Fill in the name field with another name, or rename the old file first |
| `Too many uploads at the same time` (`503`) | The panel receives up to 4 files at a time, adding up everyone, and one at a time from each FTP user | Log tab: uploads in progress do not appear yet; finished ones do | Wait for it to finish and repeat. The answer carries `Retry-After: 30` |
| `No space left` (`507`) | The disk of `DATA_DIR` has no space for the file. Nothing of the upload stays written | `df -h` on the path of `DATA_DIR`; Server tab | Free up space and upload again: [Automatic cleanup](panel.md#limpeza) deletes what is old by rule |
| `Submission without a declared size.` (`411`) | The program that uploaded did not state the size of the request, as in chunked upload. The browser always states it | — | Upload through the panel form, in the browser, or over FTP |
| The upload through the panel stops halfway and the file does not appear in the folder | The connection dropped, or the upload went more than 300 seconds without traffic. The file only gets a name in the folder after arriving whole: an interrupted upload leaves no piece | Log tab: `Upload interrupted` | Upload again. A large file on a slow link goes better over FTP |
| `The panel does not follow symbolic links.` (`403`) | The requested path goes through a symbolic link; the panel follows none, not even into its own folder | In the list, the item appears with the `symbolic link` mark | Download the file by its real path, or over FTP |
| `Path not accepted.` (`400`) in the Files tab | Address built by hand, with `..`, leading slash, double slash or null character | The address typed | Browse through the links of the Files tab, from the first screen |
| `Name not accepted` (`400`) when creating a folder | The name has `/`, a space, an accent, starts with a dot or is over 64 characters | The name typed | Use letters, numbers, `_`, `-` and dot. For a folder inside another, create the upper one, go into it and create the inner one |
| `Folder of an FTP user` (`409`) when renaming or deleting in the Files tab | The folder is that of an FTP user, or has that of a user inside: the user database would point to a folder that does not exist | The screen says which users; Users tab, **Folder** column | To delete, remove the user with the box to delete the folder. To change the name, create the new folder and change the user's in **Edit**. What is inside the folder is renamed and deleted item by item |
| `There is already a folder or a file with this name.` or `The item already has this name.` (`409`) when renaming | Renaming never replaces another item | The list of the Files tab | Choose another name, or first delete the item that has the name |
| `Tick the confirmation box. Nothing was deleted.` (`400`) | The delete request arrived without the box ticked | The Delete screen | Check the name of the item, tick the box and repeat |
| `Partly deleted` when deleting a folder | The folder has more than 50,000 items or took more than 20 seconds: the panel deletes up to the limit and stops; or an item could not be removed | The screen says how many items went and the reason; Log tab, line `File or folder deleted` | Click **Repeat**, tick the box and type the password again, until the folder disappears from the list |
| `Nothing was deleted` (`503`) with the notice that the panel is already deleting another folder | The panel does one deletion at a time | — | Wait for the other to finish and repeat. The answer carries `Retry-After: 30` |
| `Nothing was deleted` (`500`) | The system refused to remove the item: permission changed by hand in `DATA_DIR/dados` or disk error | `docker compose logs painel`; Log tab, event `falha_comando` | Check the owner and permission of the folder on the host and the disk; then repeat |
| The **Also delete the folder** box does not appear when removing a user, or the request gets `409` | Another user uses the same folder, one inside it or one outside it, or the user database points outside `DATA_DIR/dados` | The Remove screen says who else reaches the folder | First remove the other users or change their folder in **Edit**; or remove only the user and delete what you want in the Files tab |
| `Name already in use` (`409`) when creating a folder | There is already a folder, file or symbolic link with that name in that folder | The list of the Files tab | Choose another name, or use the folder that already exists |
| `Invalid folder. See the rule below the field.` (`400`) when creating a user | The folder has more than 4 levels, `..`, leading slash, a level starting with a dot or a character outside the rule | The **Folder** field | Fix the folder, or leave it blank to use the user name |
| `The folder goes through a symbolic link, which is not accepted.` or `There is already a file with this name in the folder path.` (`400`) | One of the levels of the chosen folder is a symbolic link or a file; the panel and `manage-user.sh` (`Pasta recusada: ...`) neither follow nor replace it | Files tab: the item appears with the `symbolic link` mark or as a file | Choose another folder, or delete the link or the file in the Files tab |
| `There is already a user with this name.` (`409`) or `Usuario ja existe` | The name is already in the user database | Users tab or `./manage-user.sh list` | Use another name. To change the folder of someone who already exists, use Users ➜ **Edit** or `./manage-user.sh pasta`: the files stay where they were |
| One device sees files of another | The two users have the same folder, or that of one is inside that of the other | Users tab: the folder appears with the **shared** mark and the name of who else reaches it | Recreate one of the users with its own folder: [Users through the panel](panel.md#usuarios) |
| The download stops halfway | Connection dropped, or received less than about 4 KiB per second; the panel does not resume downloads | Log tab, line `Download interrupted`, with the bytes delivered | Download again, over a faster connection; a very large file on a slow link goes better over FTP |
| A file appears in the list without the **Download** button | It is a symbolic link or a special file (FIFO, socket, device): the panel only delivers regular files | The mark next to the name | Over FTP or on the host, in the user folder, inside `DATA_DIR/dados` |
| The browser tab still has the old icon after changing the logo | The browser keeps the tab icon on its own, even with the panel telling it to check at every request | `curl -k -s https://<IP>:<port>/favicon.ico \| sha256sum` and `sha256sum web/marca/favicon.ico` give the same result | Close and open the tab, or clear the site data in the browser. If the results are different, `./deploy.sh` still has to be run |
| `ERRO: web/marca/<arquivo> falta ou não é uma imagem válida.` in `validate.sh`, or the build of the nginx image stops at `web/marca` | One of the six brand files was deleted or replaced by something that is neither PNG nor ICO | `ls -l web/marca/` | `./scripts/gerar-marca.sh` and then `./deploy.sh`: [Web panel](panel.md#marca) |
| `ERRO: LICENSE falta ou não é o texto oficial da Apache-2.0.`, `ERRO: NOTICE falta ...` or `ERRO: <arquivo> sem a linha SPDX-License-Identifier: Apache-2.0 no começo.` in `validate.sh`, or the build of the images stops at `LICENSE NOTICE` | `LICENSE` or `NOTICE` was deleted or changed, or a new code file was left without the licence line | `git status --short LICENSE NOTICE` and the message, which names the file | `git checkout -- LICENSE NOTICE` brings both back; in the new file, put `# SPDX-License-Identifier: Apache-2.0` on the first line, or on the second when it starts with `#!` |
| `ERRO: o ImageMagick 7 (comando magick) não está instalado neste computador.` | `gerar-marca.sh` needs ImageMagick 7; the server does not need it to run the stack | `magick -version` | Run the script on a computer that has ImageMagick 7 and take the `web/marca/` folder to the server |
| The **FTP network** card of the Server tab says **no reading** | The FTP service has just started, or its watcher is not publishing the network | `docker exec allsafe-ftp ls -l /auth/rede.estado` | Wait a few seconds and open the tab again. If the file does not exist, `docker logs allsafe-ftp --tail 30` shows whether the watcher started; `./deploy.sh` rebuilds the container |
| A container card of the Server tab says **no reading** | The container has just started, or stopped publishing its resources: a reading older than 90 s does not count | `docker exec allsafe-ftp ls -l /auth/recursos.estado` and `docker exec allsafe-ftp-nginx ls -l /estado/recursos.estado` | Wait a few seconds and open the tab again. If the nginx file does not exist, `docker logs allsafe-ftp-nginx --tail 30` shows the warning about the `/estado` folder; `./deploy.sh` rebuilds the containers and the folder |
| The session drops with the Server tab open on **Auto-refresh** | Automatic refresh does not count as use of the panel | `grep '^PAINEL_SESSAO_MINUTOS=' .env` | Sign in again. To follow for longer, raise the idle time, from `1` to `120` minutes |
| The session drops by itself | 4 hours without use, ceiling of 12 hours, change of the client address or restart of the panel | `grep '^PAINEL_SESSAO_MINUTOS=' .env` | Sign in again. The idle time goes from `1` to `720` minutes |
| `The submission did not come from this panel.` or `Form without a valid token.` (`403`) | Old tab, after signing out or after the session expired, or panel opened through an intermediary that changes the address. In a version older than `0.14.0`, the browser was refused on every submission, including sign-in | `cat VERSION` | Open the page again, directly at the panel address, and repeat. In a version older than `0.14.0`, update the stack |
| I removed the initial user and want it back | `FTP_USER` is created once, at installation; once removed, the `ftp` service does not recreate it, and the log says `removido pelo administrador; não é recriado` | `docker compose logs ftp \| grep 'Usuário inicial'` | Users ➜ **New user**, with the same name and the password you want, or `./manage-user.sh add <user>` |
| I changed the password of the initial user through the panel and, after a restart, the one in the file applies again | The file `.secrets/ftp-usuario-inicial-senha.txt` was changed after the change: the `ftp` service applies the file whenever its content changes | `docker compose logs ftp \| grep 'Usuário inicial'` | Change it again through the panel, or write the desired password to the file: [Secrets](secrets.md#trocar-a-senha) |
| `Invalid folder`, `The folder goes through a symbolic link` or `There is already a file with this name` when changing the folder (`400`) | The folder breaks the rules, or goes through a symbolic link or through a name that already belongs to a file | — | Use up to 4 levels separated by `/`, with letters, numbers, `_`, `-` and dot: [Panel](panel.md#usuarios) |
| `This is already the user's folder.` (`409`) | The requested folder is the one the user already has | — | Nothing to do |
| I changed `.secrets/ftp-usuario-inicial-senha.txt`, restarted `ftp` and the old password still applies | Version older than `0.29.0`: the password in the file was only written when the initial user was created | `cat VERSION` | Update the stack: the password in the file is then applied at the start following each change to it |
| Security tab with `Cost of FTP passwords` in alert | There is a user with the password stored before `0.29.0`, or on a smaller size: each sign-in attempt with that name takes more of the FTP processor | — | Change the password of each user listed, in the Users tab or with `./manage-user.sh passwd`: [Security](security.md#custo-das-senhas) |
| `FALHA: FTP_MAX_CLIENTS deve ser um inteiro maior que zero` (or `FTP_MAX_CLIENTS_PER_IP`) in the log of `ftp` or of `painel` | The value in the `.env` is not an integer from 1 to 99999 | `grep '^FTP_MAX_CLIENTS' .env` | Fix the value or apply a profile with `./deploy.sh --size <profile>` |
| `allsafe-ftp-painel` restarting in a loop | The panel entrypoint refused the configuration | `docker compose logs --tail 20 painel` | Fix it according to the `FALHA:` message: [Scripts](scripts.md#painel-entrypoint) |
| `allsafe-ftp-nginx` restarting in a loop | The nginx entrypoint refused the configuration or found neither the socket nor the certificate of the panel | `docker compose logs --tail 20 nginx` | Fix it according to the `FALHA:` message: [Scripts](scripts.md#nginx-entrypoint). When in doubt, `./deploy.sh` recreates the `nginx/` folder and starts in the right order |
| `dependency failed to start: container allsafe-ftp is unhealthy` | The panel only starts after the FTP, and nginx after the panel | `docker compose logs --tail 50 ftp` | Solve the FTP first, through the table [The container does not start](#o-container-nao-sobe) |
| `bind: address already in use` on the panel port (container `allsafe-ftp-nginx`) | `PAINEL_PORT` taken by another service on the same IP | `ss -ltnp` | Change `PAINEL_PORT` in the `.env` |

---

<a name="destinos"></a>

## ☁️ Destinations: S3 and Telegram bot

When a test, a send with the button or a run does not work, the panel gives the reason in one sentence: in the notice on the page, on the card of the destination (**The last run stopped before the end**) and in the Log tab. The state of each destination and the last run also come out from the terminal, with no secret. The output of this command is in Portuguese:

```bash
docker compose exec painel python3 /opt/painel/servidor.py --destinos
```

**Expected result:** one line per destination: `não configurado` (not configured), or `ligado` (on) or `desligado` (off) with the folder, the interval and the last run. With `--copia` in place of `--destinos`, it prints the state of the [system copy to S3](panel.md#copia-do-sistema) and the last copy.

| The panel says | Cause | How to check | Fix |
|---|---|---|---|
| `the address name was not found` | The name of the service does not resolve from inside the panel container | `docker compose exec painel getent hosts <name>` | Fix the **Service address**, or the DNS of the server |
| `the address is not accepted by the panel, or the service sent the request to another address` | The name leads to an address the panel does not reach (its own container, a link-local, multicast or reserved address), or S3 answered with a redirect: a bucket in another region or an address that is not the one of the service | The **Region** and the **Service address** in the record of the bucket, at the service | In **Change**, save the region and the address of the bucket |
| `could not connect to the service` | Service down, port closed or server with no way out to the internet | On the server: `curl -sS -o /dev/null -w '%{http_code}\n' https://<name>:<port>` | Allow HTTPS from the server out to the service; the next run resumes from the same file |
| `the service certificate was not accepted` | Certificate expired, for another name or issued by an authority the panel does not know | `openssl s_client -connect <name>:<port> -servername <name> </dev/null 2>/dev/null \| openssl x509 -noout -subject -issuer -dates` | S3 on the internal network with its own authority: hand its certificate to the panel, as in [Destinations](panel.md#destinos) |
| `the service did not answer in time` | Slow link or service: each network operation has 30 s | The time of the `Upload to the destination not completed` lines in the Log tab | Nothing to do if it happened once: the next run resumes from the same file. If it repeats, check the link |
| `the service answer was not understood` | The address is not that of an S3 service, or an intermediary is answering in its place | The **Service address** | Save the address of the service, without the bucket and without a path |
| `the service refused the credential or the permission` | S3: wrong key, key without permission to write to the bucket or server clock off. Bot: token no longer valid, bot out of the group or the channel, or blocked by the person | `date` on the server; **Test** on the card | In **Change**, save the keys or the token again; put the bot back in the chat |
| `the bucket or the chat does not exist for this credential` | S3: wrong bucket name, bucket of another account or **Bucket address** in the form the service does not use. Bot: wrong chat number, or the person has not started the chat with the bot yet | The bucket name at the service; the chat number | Fix it in **Change** and click **Test** |
| `the file is larger than the service accepts` | With the **Telegram** button: the file is above [`PAINEL_TELEGRAM_MAX_MB`](configuration.md#painel). In S3: more than 5 TiB, or the service refused it for its size | The size in the Files tab | Through the bot, the large file does not go; send it with the **S3** button or download it through the panel |
| `the file is empty, and the bot does not send an empty file` | A 0-byte file sent with the **Telegram** button | The size in the Files tab | Nothing to do: the bot API does not accept it. S3 stores an empty file |
| `the file name does not fit the destination` | The prefix plus the path of the file go over 1024 bytes, the maximum of an object name | The path of the file | Shorten the prefix or the path |
| `the file changed during the send: repeat when it has finished arriving` | The file was still arriving when the button was clicked | The date of the file in the Files tab | Wait for the upload of the device to finish and click again |
| `another send requested from the screen is running: try again in a moment` | The previous send requested with the button has not finished yet | Log tab: the line `File sent to the destination on request` appears when it ends | Wait and click again |
| `another test is running: try again in a moment` | Two clicks on **Test** at the same time | — | Wait a few seconds |
| `a file could not be read` | Permission changed by hand in `DATA_DIR/dados` or disk error | `docker compose logs --tail 30 painel` | Check owner and permission of the folder on the host and the disk |
| `the chosen folder no longer exists inside the data` | The folder of the destination was renamed or deleted | Files tab | In **Change**, choose the folder that exists, or create the folder again |
| `the destination secrets are missing: save them again`, or the card with the **secrets missing** tag | A backup was restored, or the files in `SECRETS_DIR/destinos` were deleted | The tag on the card | In **Change**, type the keys or the token and the chat again |
| `the destination is off or has no secrets` when clicking **Send now** | A run only happens with the destination on and with its secrets | The tag on the card | In **Change**, mark the destination as on. For a single file, use the button of the Files tab, which works with the destination off |
| `S3 is waiting for the other destinations of the same folder to deliver what is left before deleting more files` | With **Keep in S3** and another destination of the same folder stopped, bot or S3, the queue of what waits for it is full | The reason on the card of the stopped destination | Solve the stopped destination by its reason, or remove it: S3 sends again |
| `the service answered with code <number>` | An answer the panel did not expect: `5xx` is a problem on the side of the service, `429` is too many requests | The state of the service | Wait: the next run resumes from the same file. If the same file is refused three runs in a row, it is left behind and the Log tab gets `File refused by the destination left behind` |
| `the system copy has no S3 chosen with its secrets saved` | The S3 that received the copy was removed, or no S3 is saved with its keys | The **System copy** card, with the tag **not configured** | Save the S3, with the keys, and choose it in **Configure**, on the card of the copy |
| `the public key of the copy is missing in this installation` | The file `backup-chave-publica.txt` is not in `SECRETS_DIR`, does not hold a key, or the panel container is from before it existed | `docker compose exec painel test -s /run/secrets/backup_chave_publica; echo $?` (`0` is present) | `./deploy.sh`, which takes the public key from the private one, or creates the pair, and recreates the panel |
| `the encryption of the copy failed` | `age` stopped before the end, usually for lack of memory in the panel container | `docker compose logs --tail 30 painel` and the memory of the panel, in the Server tab | Request the copy again, at an hour of less use |
| `users were being changed and their list could not be read in time` | A user was being created, changed or removed, and the lock of the list was not released in 30 seconds | — | Request the copy again |
| `there is not enough disk space on the server to assemble one part of the copy` | Each part, already encrypted, is assembled in `DATA_DIR/painel` before leaving, and the disk does not have free the size of one part plus 64 MiB | `df -h` on the folder of `DATA_DIR` | Free up space. The part has 16 MiB or more and grows with the disk in use: about 1 GiB for each 9 TiB |
| `there are too many folders, one inside the other, for the panel to open` | A folder tree deeper than the open files limit of the container | — | Reduce the depth of the folders, or make the copy with `scripts/backup.sh` |
| `another system copy is in progress` | The button was clicked, or the terminal called, with a copy running | The tag **in progress** on the card | Wait for it to end |
| `the copy was written to the destination, but the file with its checksum was not: make another copy` | The service failed after writing the copy and before writing the `.sha256` | The objects in the folder of the copy, in the bucket | Request another copy. The one left without the `.sha256` still restores, with the warning `soma não conferida` |
| **The previous copy was interrupted by the panel restart** | The panel container restarted, or the stack was updated, in the middle of the copy | `docker compose ps painel`, with the uptime | Click **Copy and send now**. The multipart upload left unfinished takes up space in the bucket until it is undone: put in the bucket the rule that expires incomplete multipart uploads |
| The schedule of the system copy did not run | `0` days saved (tag **button only**), the last copy has fewer days than the schedule, the destination is without its secrets, or the schedule was saved after today's time: it applies from the next set time on | The tag and the **Schedule** and **Last copy** lines of the card; `docker compose exec painel python3 /opt/painel/servidor.py --copia` | In **Change**, on the card of the copy, save the days and the time |
| The bot did not send right away a file that arrived | The file arrived under one name and was renamed or moved by FTP, was copied straight onto the server, or the arrival notice was not written: without the notice, the wait of two minutes without changing applies | The **Still arriving** line on the card of the bot | Nothing to do: it goes by itself after the wait. To send it now, use the **Telegram** button on the line of the file |
| The bot did not send the files that were already in the folder | The bot only sends what arrives after it is turned on | The **Last run** line of the card | Send each one with the **Telegram** button of the Files tab |
| The chat received a notice instead of the file | The file is above the limit of the bot | The size in the notice | The file stays on the server: download it through the panel |
| The **Telegram** and **S3** buttons do not appear in the Files tab | The destination was not saved, has no secrets, or `PAINEL_DESTINOS=nao`. The My files screen, of the FTP user, never has these buttons | The Destinations tab; `grep '^PAINEL_DESTINOS=' .env` | Save the destination in the Destinations tab |
| The Destinations tab is not in the menu | `PAINEL_DESTINOS=nao`, or the session is of an FTP user | `grep '^PAINEL_DESTINOS=' .env` | `PAINEL_DESTINOS=sim` and `./deploy.sh` |

---

<a name="ferramentas-de-validacao"></a>

## 🧪 Validation tools

```bash
./scripts/validate.sh                     # bash -n of the scripts and compose config
./scripts/validate.sh --runtime           # also requires the three services running and healthy
docker compose exec ftp /usr/local/sbin/allsafe-ftp-saude && echo atendendo   # what the healthcheck tests
./tests/testar.sh                       # full test suite on a separate test instance
```

**Expected result:** `Validacao FTP concluida.`, `atendendo` and `Bateria aprovada: nenhum desvio.` The test suite does not touch the installation in use; if it passes and your installation fails, the difference is in the `.env`, in the data or in the network of the host. See [Scripts](scripts.md#testar).

Still stuck? Collect and analyse:

```bash
TEMP_DIR="$(sed -n 's/^TEMP_DIR=//p' .env | tail -n 1)"   # the TEMP_DIR of your .env
mkdir -p "$TEMP_DIR"
docker compose logs --no-color ftp painel nginx > "$TEMP_DIR/allsafe-ftp.log"
docker inspect allsafe-ftp allsafe-ftp-painel allsafe-ftp-nginx > "$TEMP_DIR/allsafe-ftp.inspect.json"
```

**Expected result:** two files in `TEMP_DIR` with the full log and the effective configuration of the containers. Delete them when done.

> ⚠️ `inspect` includes the environment variables of the container. None of them is a password (the password only exists in the secret), but the file shows IPs and paths of the host: review it before sharing.

---

⬅️ [Application screenshots](application/README.md) · 🏠 [Documentation](README.md)
