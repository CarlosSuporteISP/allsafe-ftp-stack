# 🏗️ Arquitetura — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [📚 Índice da documentação](README.md)

---

<details>
<summary>🧭 Sumário — clique para expandir</summary>

[🧩 Componentes](#componentes) · [💾 Volumes](#volumes) · [🌐 Rede](#rede) · [🔄 Fluxo da primeira subida](#fluxo-da-primeira-subida) · [🚩 Flags do `pure-ftpd`](#flags-do-pure-ftpd) · [🩺 Healthcheck](#healthcheck) · [🧱 Endurecimento (resumo)](#endurecimento-resumo)

</details>

---

<a name="componentes"></a>

## 🧩 Componentes

| Peça | Onde | Papel |
|---|---|---|
| Serviço `ftp` | [`compose.yaml`](../compose.yaml) | Único container da stack (`allsafe-ftp`). |
| Imagem | [`Dockerfile`](../Dockerfile) | `debian:bookworm-slim` pinada por digest + `pure-ftpd`, `pure-ftpd-common`, `openssl`, `procps`, `ca-certificates`. |
| Usuário do processo de dados | `Dockerfile` | `ftpdata`, uid/gid **10000**, shell `nologin`, sem home. |
| Entrypoint | [`scripts/entrypoint.sh`](../scripts/entrypoint.sh) → `/usr/local/sbin/allsafe-ftp-entrypoint` | Provisiona usuário + certificado e faz `exec` do `pure-ftpd`. |
| Gestão de usuários | [`scripts/ftp-user.sh`](../scripts/ftp-user.sh) → `/usr/local/sbin/allsafe-ftp-user` | `add`/`passwd`/`del`/`list` no PureDB, chamado de fora por [`manage-user.sh`](../manage-user.sh). |

---

<a name="volumes"></a>

## 💾 Volumes

| Volume (nome) | Monta em | Guarda |
|---|---|---|
| `allsafe-ftp-data` | `/data` | Arquivos dos usuários — um diretório `chroot` por usuário (`/data/<user>`). |
| `allsafe-ftp-auth` | `/auth` | Base **PureDB**: `pureftpd.passwd` (texto) e `pureftpd.pdb` (compilada), ambos `0600`. |
| `allsafe-ftp-certs` | `/etc/ssl/private` | `pure-ftpd.pem` — chave + certificado concatenados, `0600`. |
| _bind_ `./.secrets` | `/run/.secrets` (ro) | Arquivo da senha do usuário inicial. |

`tmpfs` para `/run` (8 MiB) e `/tmp` (16 MiB), ambos `noexec,nosuid,nodev`.

---

<a name="rede"></a>

## 🌐 Rede

- Rede bridge dedicada `allsafe-ftp-network`.
- Publicações no host (ver [`configuracao.md`](configuracao.md#rede-e-portas)):
  - `FTP_BIND_IP:FTP_PORT → 2121/tcp` (controle);
  - `FTP_BIND_IP:30000-30049 → 30000-30049/tcp` (dados, passivo, 1:1).
- Sem DNS reverso (`-H`): o `pure-ftpd` nunca resolve o IP do cliente.

---

<a name="fluxo-da-primeira-subida"></a>

## 🔄 Fluxo da primeira subida

```text
docker compose up
        │
        ▼
entrypoint.sh
 ├─ lê a senha (FTP_PASSWORD_FILE ou FTP_PASSWORD) e valida ≥ 12 caracteres
 ├─ valida FTP_USER, faixa passiva e FTP_TLS_MODE
 ├─ install -d  /auth (0750)  e  /data/$FTP_USER (dono ftpdata, 0750)
 ├─ pure-pw useradd|usermod  +  pure-pw mkdb  → /auth/pureftpd.pdb
 ├─ se /etc/ssl/private/pure-ftpd.pem não existe:
 │     openssl req -x509 rsa:3072 -sha256 -days 825  (SAN IP: ou DNS: conforme FTP_CERT_CN)
 ├─ unset das variáveis de senha
 └─ exec pure-ftpd ...  (PID 1, via `init: true`)
```

Nas subidas seguintes o usuário é **atualizado** (`usermod`) e o certificado
existente é **mantido**.

---

<a name="flags-do-pure-ftpd"></a>

## 🚩 Flags do `pure-ftpd`

Linha final do [`entrypoint.sh`](../scripts/entrypoint.sh):

| Flag | Efeito |
|---|---|
| `-A` | `chroot` de **todos** os usuários no próprio diretório. |
| `-E` | Proíbe login anônimo. |
| `-H` | Não resolve DNS reverso do cliente. |
| `-j` | Cria o diretório home do usuário se não existir. |
| `-R` | Proíbe `chmod` pelo cliente. |
| `-c <n>` | Máx. de clientes simultâneos (`FTP_MAX_CLIENTS`). |
| `-C <n>` | Máx. de clientes por IP (`FTP_MAX_CLIENTS_PER_IP`). |
| `-I 15` | Timeout de ociosidade: 15 min. |
| `-L 10000:8` | Limite de `ls`: 10000 arquivos / profundidade 8. |
| `-u 10000` | UID mínimo autorizado a logar (bloqueia contas de sistema). |
| `-U 133:022` | `umask` — 133 para arquivos, 022 para diretórios. |
| `-l puredb:/auth/pureftpd.pdb` | Backend de autenticação. |
| `-p START:END` | Faixa de portas passivas. |
| `-P <ip>` | IP anunciado no `PASV` (`FTP_PUBLIC_IP`). |
| `-S 0.0.0.0,2121` | Escuta na porta 2121 (não privilegiada). |
| `-Y <modo>` | Política TLS (`FTP_TLS_MODE`). |
| `-O clf:/dev/stdout` | Log de acesso em formato CLF no `stdout`. |

---

<a name="healthcheck"></a>

## 🩺 Healthcheck

```yaml
test: ["CMD-SHELL", "pidof pure-ftpd >/dev/null"]
interval: 20s   timeout: 5s   retries: 5   start_period: 20s
```

Verifica apenas que o processo está vivo. Para uma checagem funcional (usuário
existe no PureDB), use [`scripts/validate.sh --runtime`](../scripts/validate.sh).

---

<a name="endurecimento-resumo"></a>

## 🧱 Endurecimento (resumo)

`read_only: true` · `cap_drop: ALL` + apenas as capabilities necessárias ao
`pure-ftpd` (chroot, troca de uid/gid, `nice`) · `no-new-privileges: true` ·
`pids_limit`, `mem_limit`, `cpus`, `ulimits.nofile` · `logging: local` com
rotação. Detalhe e justificativa de cada `cap_add` em
[`seguranca.md`](seguranca.md).
