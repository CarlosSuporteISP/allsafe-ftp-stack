# 🔐 Segurança — allsafe-ftp-stack

---

## 🧭 Sumário

[🎯 Modelo de ameaça](#-modelo-de-ameaça) · [🌐 Superfície exposta](#-superfície-exposta) · [🧱 Hardening do `compose.yaml` — linha a linha](#-hardening-do-composeyaml--linha-a-linha) · [🔑 Gestão de segredos](#-gestão-de-segredos) · [🏭 O que endurecer antes de produção](#-o-que-endurecer-antes-de-produção)

---

## 🎯 Modelo de ameaça

| # | Ameaça | Mitigação nesta stack |
|---|---|---|
| 1 | Captura de credenciais/arquivos em trânsito | FTPS **obrigatório** (`FTP_TLS_MODE=2`); sem TLS não há login nem transferência. |
| 2 | Exposição acidental na internet | Bind em `127.0.0.1` por padrão; produção usa **um IP dedicado** + ACL/firewall no host. |
| 3 | Fuga do diretório do usuário (_path traversal_) | `chroot` de todos (`-A`); cada usuário preso em `/data/<user>`. |
| 4 | Uso de contas do sistema para login | Usuários **virtuais** em PureDB + `-u 10000` (UID mínimo). Sem anônimo (`-E`). |
| 5 | Escalonamento a partir do container | `read_only`, `cap_drop: ALL`, `no-new-privileges`, `tmpfs` `noexec`. |
| 6 | Abuso de recursos / DoS local | `-c`/`-C` (limites de sessão), `pids_limit`, `mem_limit`, `cpus`, `ulimits`. |
| 7 | Vazamento de segredo pelo Git ou pela imagem | Senha em [`.secrets/*.txt`](segredos.md) (git-ignored) e `.dockerignore`; nunca em `ENV` da imagem. |
| 8 | Enumeração via DNS reverso / _fingerprint_ | `-H` (sem resolução reversa). |

**Fora de escopo:** proteção de rede (faça ACL no host/borda), _rate-limiting_ de
brute force (use `fail2ban` no host lendo os logs CLF), e antivírus de conteúdo.

---

## 🌐 Superfície exposta

| Porta | Quem deve alcançar |
|---|---|
| `FTP_PORT` (controle) | Só as sub-redes de gerência dos equipamentos que fazem backup. |
| `30000-30049` (dados passivo) | As mesmas origens da porta de controle. |

Tudo o mais fica interno ao container. O painel/administração **não existe** —
gestão é por CLI ([`manage-user.sh`](../manage-user.sh)).

---

## 🧱 Hardening do `compose.yaml` — linha a linha

| Diretiva | Por quê |
|---|---|
| `read_only: true` | Raiz imutável; só os volumes e `tmpfs` são graváveis. |
| `tmpfs: /run, /tmp` com `noexec,nosuid,nodev` | Áreas temporárias sem execução de binário nem `setuid`. |
| `cap_drop: [ALL]` | Zera privilégios e devolve só o mínimo (abaixo). |
| `security_opt: [no-new-privileges:true]` | Impede ganho de privilégio via `setuid`/`setgid` após o start. |
| `pids_limit` | Barreira contra _fork bomb_. |
| `mem_limit` / `cpus` | Contém consumo; evita afetar vizinhos no host. |
| `ulimits.nofile` | Teto de descritores de arquivo. |
| `init: true` | `tini` como PID 1 → _reaping_ de zumbis, sinais corretos. |
| `stop_grace_period: 20s` | Deixa transferências em curso terminarem no `down`. |
| `logging: local` (10m ×3) | Log rotacionado, sem encher disco. |
| `restart: unless-stopped` | Volta após reboot, respeita `stop` manual. |

### 🔓 `cap_add` — por que cada uma

O `pure-ftpd` sobe como `root`, aplica `chroot` e **troca** para um usuário sem
privilégio por sessão. Isso exige:

| Capability | Uso |
|---|---|
| `SYS_CHROOT` | `chroot()` de cada sessão. |
| `SETUID` / `SETGID` | Descer para o uid/gid do usuário virtual. |
| `CHOWN` / `FOWNER` | Ajustar dono/permissão dos diretórios criados (`-j`). |
| `DAC_OVERRIDE` / `DAC_READ_SEARCH` | Ler/gravar nos diretórios dos usuários independentemente do bit de permissão. |
| `NET_BIND_SERVICE` | Reservada; o serviço escuta em `2121` (não privilegiada), mas a capability cobre cenários com `FTP` interno em `<1024`. |
| `SYS_NICE` | Prioridade de I/O de transferências. |
| `AUDIT_WRITE` | Registro de login (PAM/utmp) sem erro. |

Nenhuma delas permite montar filesystem, carregar módulo, `ptrace` ou acessar
`/dev`. Não há `privileged`, nem `docker.sock`, nem `network_mode: host`.

---

## 🔑 Gestão de segredos

- Senha do usuário inicial: [`.secrets/ftp_password.txt`](segredos.md),
  `chmod 600`, montado **ro** em `/run/.secrets/`.
- [`.gitignore`](../.gitignore): `.env` e `.secrets/*.txt` (mantém só `.secrets/.gitkeep`, para a pasta existir no clone).
- [`.dockerignore`](../.dockerignore): `.env`, `.git`, `.secrets`, `doc`, `README.md` — nada de segredo entra na imagem.
- O [`entrypoint.sh`](../scripts/entrypoint.sh) faz `unset` de `FTP_PASSWORD`/`password` antes do `exec`.

---

## 🏭 O que endurecer antes de produção

1. **Certificado real** no lugar do autoassinado — veja
   [`operacao.md`](operacao.md#-certificado-real-de-produção).
2. `FTP_BIND_IP` = IP dedicado; **ACL no firewall** do host para as origens de backup.
3. `fail2ban` no host lendo o log CLF do container (`docker logs allsafe-ftp`).
4. Rever `FTP_MAX_CLIENTS` / faixa passiva conforme o nº real de equipamentos.
5. Backup dos volumes `allsafe-ftp-data` e `allsafe-ftp-auth`
   ([`operacao.md`](operacao.md#️-backup-dos-volumes)).
6. Considerar SFTP (`allsafe-sftp-stack`) onde o
   equipamento suportar — canal único, sem faixa passiva.
