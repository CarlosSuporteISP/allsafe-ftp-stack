# 📁 allsafe-ftp-stack

> Servidor **FTP dedicado** (Pure-FTPd) para backup de configuração de
> equipamentos de rede — usuários virtuais, `chroot` e **FTPS obrigatório**.

Stack de um container só. Usa o banco local **PureDB** em vez de PostgreSQL:
menos memória, menos superfície de ataque e autenticação sem latência de rede.
O `root filesystem` é somente leitura, as `capabilities` são mínimas e os
segredos ficam fora da imagem e do Git.

---

<details>
<summary>🧭 Sumário — clique para expandir</summary>

[✨ Destaques](#destaques) · [🚀 Instalação rápida](#instalacao) · [🏗️ Arquitetura](#arquitetura) · [🔌 Portas e binds](#portas) · [🔐 Segurança](#seguranca) · [📊 Perfis de capacidade](#perfis-de-capacidade) · [🗂️ Estrutura de arquivos](#arquivos) · [📚 Documentação completa](#documentacao) · [🔗 Stacks relacionadas](#relacionadas)

</details>

---

<a name="destaques"></a>

## ✨ Destaques

- 🔒 **FTPS explícito obrigatório** (`AUTH TLS`) — sem TLS, sem login.
- 🧍 **Usuários virtuais** em PureDB — não são contas do sistema; cada um em seu `chroot`.
- 🚪 **Bind local por padrão** (`127.0.0.1`) — você expõe só um IP dedicado, com ACL no host.
- 🛡️ **Container endurecido** — `read_only`, `cap_drop: ALL`, `no-new-privileges`, limites de CPU/memória/PIDs.
- 🔑 **Segredos em arquivo** (`.secrets/`), nunca na imagem nem no `compose.yaml`.
- 📜 **Logs no `stdout`** em formato CLF, rotacionados pelo Docker.

---

<a name="instalacao"></a>

## 🚀 Instalação rápida

```bash
cp .env.example .env                                    # 1. configuração base
$EDITOR .env                                            # 2. ajuste os campos abaixo
./deploy.sh --size small                                # 3. valida e sobe (perfil small|medium|large)
./scripts/validate.sh --runtime                         # 4. confere o container no ar
```

O `deploy.sh` **gera uma senha forte** em `.secrets/ftp_password.txt` (`0600`) na
primeira execução se o arquivo estiver vazio — guarde-a para o cliente FTP. Para
usar uma senha própria, grave-a nesse arquivo antes de rodar.

O `--size` escolhe o dimensionamento (`profiles/<perfil>.env`); o padrão é
`small`. Detalhe em [`doc/perfis.md`](doc/perfis.md).

Ajuste em [`.env`](.env.example) antes do passo 4:

| Variável | Troque para |
|---|---|
| `FTP_BIND_IP` | o IP dedicado do servidor (não deixe `127.0.0.1` em produção) |
| `FTP_PUBLIC_IP` | o IP que o cliente enxerga (o mesmo, ou o IP público do NAT) |
| `FTP_CERT_CN` | o hostname (ou IP) que vai no certificado |

Passo a passo comentado em [`doc/instalacao.md`](doc/instalacao.md).

---

<a name="arquitetura"></a>

## 🏗️ Arquitetura

```text
cliente FTPS ──▶ FTP_BIND_IP:21  (+ passivo 30000-30049)
                        │
                 [ allsafe-ftp ]  container único, Pure-FTPd em :2121
                        │
     ┌──────────────────┼───────────────────────┐
 allsafe-ftp-data   allsafe-ftp-auth      allsafe-ftp-certs
 (/data, arquivos)  (/auth, PureDB)       (/etc/ssl/private, .pem)
```

- **Imagem:** [`Dockerfile`](Dockerfile) — `debian:bookworm-slim` (pinada por
  digest) + `pure-ftpd`, usuário `ftpdata` uid/gid **10000**.
- **Entrypoint:** [`scripts/entrypoint.sh`](scripts/entrypoint.sh) — cria/atualiza
  o usuário inicial, gera o certificado autoassinado na primeira subida e sobe o
  `pure-ftpd`.
- Detalhe completo em [`doc/arquitetura.md`](doc/arquitetura.md).

---

<a name="portas"></a>

## 🔌 Portas e binds

| Porta (host) | Protocolo | Bind padrão | Para que serve |
|---|---|---|---|
| `${FTP_PORT:-21}` | TCP | `${FTP_BIND_IP:-127.0.0.1}` | canal de controle FTP (mapeada para `:2121` no container) |
| `30000-30049` | TCP | `${FTP_BIND_IP:-127.0.0.1}` | canal de dados em **modo passivo** (50 portas = 50 clientes) |

A faixa passiva é 1:1 entre host e container. Ao mudar `FTP_PASSIVE_PORT_*`,
alinhe a quantidade de portas ao `FTP_MAX_CLIENTS`.

---

<a name="seguranca"></a>

## 🔐 Segurança

- 🚪 Bind em `127.0.0.1` por padrão — exponha só um IP dedicado e aplique ACL/firewall no host.
- 🔒 TLS **obrigatório** (`FTP_TLS_MODE=2`), `chroot` em todos, sem usuário anônimo, sem DNS reverso.
- 🧱 `read_only` no root filesystem, `cap_drop: ALL` (só as estritamente
  necessárias voltam), `no-new-privileges`, limites de CPU/memória/PIDs e `nofile`.
- 🔑 Senha via [`.secrets/ftp_password.txt`](doc/segredos.md) (mín. 12
  caracteres, `0600`), fora da imagem e ignorada pelo Git.
- 📜 Logs rotacionados (`max-size: 10m`, `max-file: 3`).

Modelo de ameaça e o hardening linha a linha em [`doc/seguranca.md`](doc/seguranca.md).

---

<a name="perfis-de-capacidade"></a>

## 📊 Perfis de capacidade

`./deploy.sh --size <perfil>` carrega `profiles/<perfil>.env` **depois** do
`.env`, sobrescrevendo só o dimensionamento (limites de sessão, faixa passiva,
CPU/memória/PIDs/`nofile`).

| Perfil | Host de referência | Sessões simultâneas | Quando usar |
|---|---|---|---|
| [`small`](profiles/small.env) | 2 vCPU · 2 GB | ~50 | padrão — cobre a maioria dos provedores |
| [`medium`](profiles/medium.env) | 4 vCPU · 4 GB | ~120 | coleta noturna em lote (~50–200 equipamentos) |
| [`large`](profiles/large.env) | 8 vCPU · 8 GB | ~300 | +200 equipamentos ou vários coletores concorrentes |

Cada perfil amplia a faixa passiva junto com `FTP_MAX_CLIENTS` — ajuste o
firewall do host ao trocar. Tabela completa em [`doc/perfis.md`](doc/perfis.md).

---

<a name="arquivos"></a>

## 🗂️ Estrutura de arquivos

| Caminho | O que é |
|---|---|
| [`compose.yaml`](compose.yaml) | Definição do serviço, volumes, rede, limites e healthcheck. |
| [`Dockerfile`](Dockerfile) | Imagem: Debian slim + Pure-FTPd + usuário `ftpdata`. |
| [`deploy.sh`](deploy.sh) | Valida o `compose` e sobe a stack (`up -d --build`). |
| [`manage-user.sh`](manage-user.sh) | Atalho do host para `add`/`passwd`/`del`/`list` de usuários. |
| [`scripts/entrypoint.sh`](scripts/entrypoint.sh) | Provisiona usuário inicial + certificado e executa o `pure-ftpd`. |
| [`scripts/ftp-user.sh`](scripts/ftp-user.sh) | Gestão de usuários **dentro** do container (chamado pelo `manage-user.sh`). |
| [`scripts/validate.sh`](scripts/validate.sh) | Checagem de sintaxe/compose (todos os perfis) e, com `--runtime`, do container no ar. |
| [`profiles/`](profiles/small.env) | Perfis de capacidade (`--size small\|medium\|large`): sessões, faixa passiva e limites de recurso. |
| [`.env.example`](.env.example) | Modelo de configuração — copie para `.env`. |
| [`.secrets/`](doc/segredos.md) | Senha do usuário inicial (`.txt` ignorados pelo Git). |
| [`doc/`](doc/README.md) | Documentação completa. |

---

<a name="documentacao"></a>

## 📚 Documentação completa

Índice: [📚 doc/README.md](doc/README.md).

| Guia | Assunto |
|---|---|
| [`doc/instalacao.md`](doc/instalacao.md) | Pré-requisitos e passo a passo comentado |
| [`doc/configuracao.md`](doc/configuracao.md) | Todas as variáveis do [`.env`](.env.example) |
| [`doc/perfis.md`](doc/perfis.md) | Perfis `small`/`medium`/`large`: dimensionamento e faixa passiva |
| [`doc/arquitetura.md`](doc/arquitetura.md) | Container, entrypoint, volumes e flags do Pure-FTPd |
| [`doc/seguranca.md`](doc/seguranca.md) | Modelo de ameaça e hardening aplicado |
| [`doc/scripts.md`](doc/scripts.md) | O que cada script faz, parâmetros e saída esperada |
| [`doc/operacao.md`](doc/operacao.md) | Usuários, certificado real, backup, logs, atualização |
| [`doc/solucao-de-problemas.md`](doc/solucao-de-problemas.md) | Erros comuns e como diagnosticar |

---

<a name="relacionadas"></a>

## 🔗 Stacks relacionadas

- `allsafe-sftp-stack` · `allsafe-scp-stack` · `allsafe-tftp-stack` — outros servidores de transferência para backup de equipamentos.
- `allsafe-zabbix-isp-stack` — monitora o container desta stack.
- 📦 `dev/README.md` e `dev/install.sh` — no pacote local AllSafe (fora deste repositório) instalam esta stack junto das outras.
