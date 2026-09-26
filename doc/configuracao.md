# ⚙️ Configuração — allsafe-ftp-stack

Todas as variáveis vivem no [`.env`](../.env.example) (copiado de
`.env.example`). O [`compose.yaml`](../compose.yaml) aplica um _default_ quando a
variável está ausente — a coluna **Default** abaixo é esse valor.

---

## 🧭 Sumário

[🌍 Geral](#-geral) · [🔌 Rede e portas](#-rede-e-portas) · [👤 Usuário inicial e senha](#-usuário-inicial-e-senha) · [🔐 TLS](#-tls) · [👥 Limites de sessão](#-limites-de-sessão) · [🧱 Limites de recurso do container](#-limites-de-recurso-do-container) · [🧾 Exemplo mínimo de produção](#-exemplo-mínimo-de-produção) · [🌐 Rede Docker](#-rede-docker-sub-rede)

---

## 🌍 Geral

| Variável | Para que serve | Valores | Default |
|---|---|---|---|
| `TZ` | Fuso horário do container (afeta logs e validade do certificado). | Nome IANA, ex.: `America/Sao_Paulo` | `America/Sao_Paulo` |
| `FTP_IMAGE` | Tag da imagem construída/local. | `nome:tag` | `allsafe-ftp:local` |

---

## 🔌 Rede e portas

| Variável | Para que serve | Valores | Default |
|---|---|---|---|
| `FTP_BIND_IP` | IP do **host** onde a porta de controle e a faixa passiva escutam. | IP do host; `0.0.0.0` para todos (evite) | `127.0.0.1` |
| `FTP_PORT` | Porta de controle publicada no host (mapeada para `2121` no container). | `1`–`65535` | `21` |
| `FTP_PUBLIC_IP` | IP anunciado ao cliente na resposta `PASV`. Precisa ser alcançável pelo cliente. | IP público/roteável | `127.0.0.1` |
| `FTP_PASSIVE_PORT_START` | Início da faixa de portas de dados (modo passivo). | `1024`–`65535`, ≤ _END_ | `30000` |
| `FTP_PASSIVE_PORT_END` | Fim da faixa passiva. Nº de portas ≥ `FTP_MAX_CLIENTS`. | `1024`–`65535`, ≥ _START_ | `30049` |

> A faixa passiva é publicada **1:1** (mesma porta no host e no container). Ao
> ampliá-la, ajuste também o firewall do host.

---

## 👤 Usuário inicial e senha

| Variável | Para que serve | Valores | Default |
|---|---|---|---|
| `FTP_USER` | Nome do usuário virtual criado/atualizado a cada subida. | Regex `^[a-z_][a-z0-9_-]{0,31}$` | `transfer` |
| `FTP_PASSWORD` | Senha em texto puro (use só se **não** usar arquivo). | ≥ 12 caracteres | _vazio_ |
| `FTP_PASSWORD_FILE` | Caminho, **dentro do container**, do arquivo com a senha. Tem precedência sobre `FTP_PASSWORD`. | Caminho legível; padrão aponta para o bind `.secrets/` | `/run/.secrets/ftp_password.txt` |

Só o usuário inicial vem do `.env`. Os demais são criados com
[`manage-user.sh`](../manage-user.sh) — veja [`operacao.md`](operacao.md#-usuários).

---

## 🔐 TLS

| Variável | Para que serve | Valores | Default |
|---|---|---|---|
| `FTP_TLS_MODE` | Política de TLS do `pure-ftpd` (`-Y`). | `1` = opcional (aceita texto puro) · `2` = **obrigatório** no controle e dados · `3` = obrigatório + exige TLS já no `CCC` | `2` |
| `FTP_CERT_CN` | `CN`/`SAN` do certificado autoassinado gerado na 1ª subida. Se for um IPv4, entra como `IP:`; senão como `DNS:`. | hostname ou IPv4 | `ftp.exemplo.com.br` (no exemplo) / `localhost` (fallback do entrypoint) |

Trocar o certificado autoassinado por um real: [`operacao.md`](operacao.md#-certificado-real-de-produção).

---

## 👥 Limites de sessão

| Variável | Para que serve | Valores | Default |
|---|---|---|---|
| `FTP_MAX_CLIENTS` | Máximo de conexões simultâneas (`-c`). Alinhe ao tamanho da faixa passiva. | inteiro > 0 | `50` |
| `FTP_MAX_CLIENTS_PER_IP` | Máximo de conexões por IP de origem (`-C`). | inteiro > 0 | `8` |

---

## 🧱 Limites de recurso do container

| Variável | Para que serve | Valores | Default |
|---|---|---|---|
| `FTP_MEMORY_LIMIT` | `mem_limit` do serviço. | ex.: `256M`, `512M` | `256M` |
| `FTP_CPU_LIMIT` | `cpus` do serviço. | ex.: `0.5`, `1.0`, `2` | `1.0` |
| `FTP_PIDS_LIMIT` | `pids_limit` (barreira contra _fork bomb_). | inteiro | `128` |
| `FTP_NOFILE` | `ulimit nofile` (soft = hard). | inteiro | `16384` |

> Estes campos (mais `FTP_MAX_CLIENTS*` e a faixa passiva) são o que os
> [`profiles/`](../profiles/) sobrescrevem. Prefira `./deploy.sh --size medium`
> a editar os valores à mão — veja [`perfis.md`](perfis.md).

---

## 🧾 Exemplo mínimo de produção

```ini
TZ=America/Sao_Paulo
FTP_BIND_IP=203.0.113.10
FTP_PUBLIC_IP=203.0.113.10
FTP_PORT=21
FTP_PASSIVE_PORT_START=30000
FTP_PASSIVE_PORT_END=30049
FTP_USER=backup-rede
FTP_PASSWORD=
FTP_PASSWORD_FILE=/run/.secrets/ftp_password.txt
FTP_TLS_MODE=2
FTP_CERT_CN=ftp.exemplo.com.br
FTP_MAX_CLIENTS=50
FTP_MAX_CLIENTS_PER_IP=8
```

Depois de editar o `.env`, valide sem subir:

```bash
docker compose --env-file .env config --quiet && echo OK
```

## 🌐 Rede Docker (sub-rede)

Cada rede Docker desta stack tem sub-rede fixa (padrão do bloco AllSafe
`172.29.1.0/24` para /29 e `172.29.2.0/24` para /28 e /27), trocável por uma variável
no `.env` — use quando a faixa colidir com a LAN/VPN do cliente.

| Variável | Rede | Containers | Padrão | Exemplo |
|---|---|---|---|---|
| `FTP_SUBNET` | `ftp` | ftp | `172.29.1.0/29` | `FTP_SUBNET=10.250.1.0/29` |

Numa instalação que já está rodando, a sub-rede nova só vale depois de recriar a
rede (os volumes/dados não são afetados):

```bash
docker compose down
docker compose up -d
```
