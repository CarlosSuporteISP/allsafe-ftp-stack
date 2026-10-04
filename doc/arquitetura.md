# 🏗️ Arquitetura — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [📚 Índice da documentação](README.md)

## 💡 Em poucas palavras

A stack é um servidor FTP dentro de um único container. Ele tem três "gavetas" que sobrevivem a reinícios: uma para os arquivos enviados, uma para a lista de usuários e uma para o certificado de segurança. O usuário opera pelo host com dois scripts; os equipamentos de rede conectam pela porta do FTP e enviam o backup.

<!-- diagrama: diagramas/visao-geral-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    equip@{ shape: hex, label: "📡 Equipamento de rede<br>envia o backup" }
    ftp@{ shape: rect, label: "⚙️ Pure-FTPd<br>allsafe-ftp, FTPS" }
    puredb@{ shape: cyl, label: "🗄️ PureDB<br>usuários virtuais" }
    dados@{ shape: lin-cyl, label: "💽 /data<br>uma pasta por usuário" }
    fim@{ shape: stadium, label: "🏁 backup guardado" }

    equip --> ftp --> puredb --> dados --> fim
```

<sub>📐 Nível 1 · Diagrama · 🔍 aproximar e mover: controles no canto do diagrama · 📁 [fonte](diagramas/)</sub>

**🧭 Sequência:** 📡 Equipamento de rede ➜ ⚙️ Pure-FTPd (`allsafe-ftp`) ➜ 🗄️ PureDB ➜ 💽 `/data` ➜ 🏁 backup guardado

---

<details>
<summary>🧭 Sumário — clique para expandir</summary>

[🗺️ Mapa da arquitetura](#mapa) · [🧩 Componentes](#componentes) · [💽 Volumes](#volumes) · [🌐 Rede](#rede) · [🔄 Modelo da subida](#subida) · [🚩 Opções do `pure-ftpd`](#flags-do-pure-ftpd) · [🩺 Healthcheck](#healthcheck) · [🧱 Endurecimento](#endurecimento-resumo)

</details>

---

<a name="mapa"></a>

## 🗺️ Mapa da arquitetura

<!-- diagrama: diagramas/arquitetura-mapa.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    subgraph USO["👤 Quem usa"]
        operador@{ shape: person, label: "👤 Usuário<br>opera a stack" }
        equip@{ shape: hex, label: "📡 Equipamento de rede<br>cliente FTP" }
    end
    subgraph HOST["🖥️ Host"]
        scripts@{ shape: console, label: "⌨️ deploy.sh<br>manage-user.sh" }
        env@{ shape: doc, label: "📄 .env<br>e perfil" }
        segredo@{ shape: doc, label: "🔑 .secrets<br>ftp_password.txt" }
    end
    subgraph CONTAINER["🐳 Container allsafe-ftp · rede allsafe-ftp-network"]
        ftp@{ shape: rect, label: "⚙️ Pure-FTPd<br>2121/tcp" }
        logs@{ shape: docs, label: "📚 log CLF<br>stdout" }
    end
    subgraph VOLUMES["💽 Volumes"]
        vcerts@{ shape: lin-cyl, label: "💽 DATA_DIR/certs<br>/etc/ssl/private" }
        vauth@{ shape: cyl, label: "🗄️ DATA_DIR/auth<br>/auth, PureDB" }
        vdata@{ shape: lin-cyl, label: "💽 DATA_DIR/dados<br>/data" }
    end
    subgraph RESULTADO["🏁 Resultado"]
        fim@{ shape: stadium, label: "🏁 backup guardado" }
    end

    operador -- "1 · ./deploy.sh --size small" --> scripts
    scripts -- "2 · docker compose up -d --build" --> ftp
    equip -- "3 · FTPS, TCP 21 para 2121" --> ftp
    ftp -- "4 · grava o arquivo, passivo 30000 a 30049" --> vdata
    vdata -- "5 · arquivo no volume" --> fim
    scripts -. "lê" .-> env
    ftp -. "lê na subida, só leitura" .-> segredo
    ftp -. "consulta os usuários" .-> vauth
    ftp -. "lê o certificado" .-> vcerts
    ftp -. "grava cada transferência" .-> logs
```

<sub>📐 Nível 2 · Mapa · 🔍 aproximar e mover: controles no canto do diagrama · 📁 [fonte](diagramas/)</sub>

| Nº | De ➜ Para | O que acontece |
|---|---|---|
| 1 | 👤 Usuário ➜ ⌨️ `deploy.sh` | O usuário executa `./deploy.sh --size small` no host |
| 2 | ⌨️ `deploy.sh` ➜ ⚙️ Pure-FTPd | O script valida o Compose e roda `docker compose up -d --build` |
| 3 | 📡 Equipamento de rede ➜ ⚙️ Pure-FTPd | O cliente conecta por FTPS em `21/tcp`, mapeada para `2121/tcp` |
| 4 | ⚙️ Pure-FTPd ➜ 💽 `DATA_DIR/dados` | O arquivo é gravado pelo canal passivo `30000-30049/tcp` |
| 5 | 💽 `DATA_DIR/dados` ➜ 🏁 backup guardado | O arquivo fica na pasta do usuário, no host |

**🧷 Apoio**

| Quem | Usa | Como |
|---|---|---|
| ⌨️ `deploy.sh` e `manage-user.sh` | 📄 `.env` e perfil | lê |
| ⚙️ Pure-FTPd | 🔑 `.secrets/ftp_password.txt` | lê na subida, somente leitura |
| ⚙️ Pure-FTPd | 🗄️ `DATA_DIR/auth` (PureDB) | consulta os usuários |
| ⚙️ Pure-FTPd | 💽 `DATA_DIR/certs` | lê o certificado |
| ⚙️ Pure-FTPd | 📚 log CLF (`stdout`) | grava cada transferência |

---

<a name="componentes"></a>

## 🧩 Componentes

| Peça | Onde | Papel |
|---|---|---|
| Serviço `ftp` | [`compose.yaml`](../compose.yaml) | Único container da stack (`allsafe-ftp`) |
| Imagem | [`Dockerfile`](../Dockerfile) | `debian:bookworm-slim` fixada por digest, com `pure-ftpd`, `pure-ftpd-common`, `openssl`, `procps` e `ca-certificates` |
| Usuário do processo de dados | [`Dockerfile`](../Dockerfile) | `ftpdata`, uid e gid **10000**, shell `nologin`, sem home |
| Entrypoint | [`scripts/entrypoint.sh`](../scripts/entrypoint.sh), instalado como `/usr/local/sbin/allsafe-ftp-entrypoint` | Provisiona usuário e certificado e faz `exec` do `pure-ftpd` |
| Gestão de usuários | [`scripts/ftp-user.sh`](../scripts/ftp-user.sh), instalado como `/usr/local/sbin/allsafe-ftp-user` | `add`, `passwd`, `del` e `list` no PureDB, chamado de fora por [`manage-user.sh`](../manage-user.sh) |

O que cada script faz, com parâmetros e saída: [⌨️ Scripts](scripts.md).

---

<a name="volumes"></a>

## 💽 Volumes

| Volume (nome) | Monta em | Guarda |
|---|---|---|
| `DATA_DIR/dados` | `/data` | Arquivos dos usuários: um diretório `chroot` por usuário (`/data/<usuario>`) |
| `DATA_DIR/auth` | `/auth` | Base **PureDB**: `pureftpd.passwd` (texto, com o hash das senhas) e `pureftpd.pdb` (compilada), ambos `0600` |
| `DATA_DIR/certs` | `/etc/ssl/private` | `pure-ftpd.pem`: chave e certificado concatenados, `0600` |
| segredo `ftp_password` (`SECRETS_DIR/ftp_password.txt`) | `/run/secrets/ftp_password` (somente leitura) | Senha do usuário inicial; é o único arquivo de `.secrets/` que o serviço vê |

Além deles, dois `tmpfs`: `/run` (8 MiB) e `/tmp` (16 MiB), ambos `noexec,nosuid,nodev`.

---

<a name="rede"></a>

## 🌐 Rede

- Rede bridge dedicada `allsafe-ftp-network`, sub-rede `172.29.1.0/29` (variável `FTP_SUBNET`).
- Publicações no host (veja [⚙️ Configuração](configuracao.md#rede-e-portas)):

| Publicação | Para quê |
|---|---|
| `FTP_BIND_IP:FTP_PORT` ➜ `2121/tcp` | canal de controle |
| `FTP_BIND_IP:30000-30049` ➜ `30000-30049/tcp` | canal de dados, modo passivo, 1:1 |

- Sem DNS reverso (`-H`): o `pure-ftpd` nunca resolve o IP do cliente.

---

<a name="subida"></a>

## 🔄 Modelo da subida

O que acontece entre o `./deploy.sh` e o container `healthy`.

<!-- diagrama: diagramas/subida-modelo.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    subgraph OPERACAO["👤 Operação"]
        operador@{ shape: person, label: "👤 Usuário" }
        deploy@{ shape: console, label: "⌨️ deploy.sh<br>--size small" }
    end
    subgraph HOST["🖥️ Host"]
        env@{ shape: doc, label: "📄 .env<br>e profiles/small.env" }
        segredo@{ shape: doc, label: "🔑 .secrets<br>ftp_password.txt" }
        compose@{ shape: rect, label: "🐳 Docker Compose<br>compose.yaml" }
    end
    subgraph CONTAINER["🐳 Container allsafe-ftp · raiz somente leitura"]
        entry@{ shape: rect, label: "⚙️ entrypoint<br>allsafe-ftp-entrypoint" }
        valida@{ shape: diam, label: "❓ variáveis<br>válidas?" }
        pw@{ shape: rect, label: "👥 pure-pw<br>cria ou atualiza o usuário" }
        puredb@{ shape: cyl, label: "🗄️ PureDB<br>/auth/pureftpd.pdb" }
        dados@{ shape: lin-cyl, label: "💽 /data<br>pasta do usuário" }
        certq@{ shape: diam, label: "❓ certificado<br>existe?" }
        gera@{ shape: rect, label: "🔏 openssl<br>autoassinado, 825 dias" }
        cert@{ shape: doc, label: "📄 pure-ftpd.pem<br>/etc/ssl/private" }
        pure@{ shape: rect, label: "⚙️ pure-ftpd<br>0.0.0.0, 2121" }
        saude@{ shape: rect, label: "🩺 healthcheck<br>pidof pure-ftpd" }
    end
    subgraph RESULTADO["🏁 Resultado"]
        pronto@{ shape: stadium, label: "🏁 FTP pronto<br>healthy" }
        falha@{ shape: stadium, label: "⛔ FALHA no log<br>container não sobe" }
    end

    operador -- "1 · executa" --> deploy
    deploy -- "2 · docker compose up -d --build" --> compose
    compose -- "3 · inicia o container" --> entry
    entry -- "4 · confere usuário, senha, faixa e TLS" --> valida
    valida -- "5a · ✅ sim" --> pw
    valida -- "5b · ❌ não" --> falha
    pw -- "6 · banco compilado" --> certq
    certq -- "7a · ✅ sim: reutiliza" --> pure
    certq -- "7b · ❌ não" --> gera
    gera -- "8 · certificado pronto" --> pure
    pure -- "9 · conferido a cada 20 s" --> saude
    saude -- "10 · processo vivo" --> pronto
    deploy -. "gera a senha se vazio, 0600" .-> segredo
    compose -. "lê" .-> env
    entry -. "lê, só leitura" .-> segredo
    entry -. "cria a pasta" .-> dados
    pw -. "grava" .-> puredb
    gera -. "grava" .-> cert
    pure -. "lê" .-> cert
    pure -. "consulta" .-> puredb
```

<sub>📐 Nível 3 · Modelo · 🔍 aproximar e mover: controles no canto do diagrama · 📁 [fonte](diagramas/)</sub>

| Nº | De ➜ Para | O que acontece | Protocolo e porta | Regra |
|---|---|---|---|---|
| 1 | 👤 Usuário ➜ ⌨️ `deploy.sh` | Executa `./deploy.sh --size small` | — | Sem `.env`, o script cria um a partir do exemplo e para |
| 2 | ⌨️ `deploy.sh` ➜ 🐳 Docker Compose | Roda `docker compose up -d --build` com `.env` e o perfil | — | Antes roda `config --quiet`; configuração inválida não sobe |
| 3 | 🐳 Docker Compose ➜ ⚙️ entrypoint | Inicia o container `allsafe-ftp` | — | Raiz somente leitura, `tini` como processo 1 |
| 4 | ⚙️ entrypoint ➜ ❓ variáveis válidas? | Confere usuário, senha, faixa passiva e modo TLS | — | Nome `^[a-z_][a-z0-9_-]{0,31}$`, senha de 12 ou mais, faixa entre `1024` e `65535`, TLS `1`, `2` ou `3` |
| 5a | ❓ variáveis válidas? ➜ 👥 `pure-pw` | ✅ Sim: cria (`useradd`) ou atualiza (`usermod`) o usuário inicial | — | Usuário virtual com uid e gid `ftpdata`, home `/data/<usuario>` |
| 5b | ❓ variáveis válidas? ➜ ⛔ FALHA no log | ❌ Não: o entrypoint sai com `FALHA: <motivo>` | — | O container reinicia em laço até a correção |
| 6 | 👥 `pure-pw` ➜ ❓ certificado existe? | Compila o banco com `pure-pw mkdb` e segue | — | `pureftpd.passwd` e `pureftpd.pdb` ficam `0600` |
| 7a | ❓ certificado existe? ➜ ⚙️ `pure-ftpd` | ✅ Sim: reutiliza o `pure-ftpd.pem` | — | O certificado existente nunca é sobrescrito |
| 7b | ❓ certificado existe? ➜ 🔏 `openssl` | ❌ Não: gera um autoassinado | — | RSA 3072, SHA-256, 825 dias, SAN `IP:` ou `DNS:` conforme `FTP_CERT_CN` |
| 8 | 🔏 `openssl` ➜ ⚙️ `pure-ftpd` | Certificado pronto, `0600` | — | As variáveis de senha são apagadas (`unset`) antes do `exec` |
| 9 | ⚙️ `pure-ftpd` ➜ 🩺 healthcheck | Processo conferido a cada 20 s | TCP `2121` e `30000-30049` | `start_period` de 20 s, 5 tentativas |
| 10 | 🩺 healthcheck ➜ 🏁 FTP pronto | Processo vivo: container `healthy` | — | Confere só o processo, não o login |

**🧷 Apoio**

| Quem | Usa | Como |
|---|---|---|
| ⌨️ `deploy.sh` | 🔑 `.secrets/ftp_password.txt` | gera a senha se o arquivo estiver vazio, `0600` |
| 🐳 Docker Compose | 📄 `.env` e `profiles/small.env` | lê |
| ⚙️ entrypoint | 🔑 `.secrets/ftp_password.txt` | lê, somente leitura |
| ⚙️ entrypoint | 💽 `/data` | cria a pasta do usuário |
| 👥 `pure-pw` | 🗄️ PureDB (`/auth/pureftpd.pdb`) | grava |
| 🔏 `openssl` | 📄 `pure-ftpd.pem` | grava |
| ⚙️ `pure-ftpd` | 📄 `pure-ftpd.pem` | lê |
| ⚙️ `pure-ftpd` | 🗄️ PureDB | consulta |

Nas subidas seguintes o usuário inicial é **atualizado** (`usermod`) e o certificado existente é **mantido**.

<details>
<summary>🔬 Detalhe técnico — quem é o processo 1</summary>

Com `init: true` no [`compose.yaml`](../compose.yaml), o processo 1 do container é o `tini` (`docker-init`). Ele inicia o entrypoint, que termina com `exec /usr/sbin/pure-ftpd`: o `pure-ftpd` toma o lugar do entrypoint e fica como filho direto do `tini`, que repassa os sinais e recolhe processos órfãos.

Ao terminar, o entrypoint escreve no log: `FTP pronto em 2121/tcp; TLS=<modo>; passivo=<inicio>-<fim>`.

</details>

---

<a name="flags-do-pure-ftpd"></a>

## 🚩 Opções do `pure-ftpd`

Linha final do [`entrypoint.sh`](../scripts/entrypoint.sh):

| Opção | Efeito |
|---|---|
| `-A` | `chroot` de **todos** os usuários no próprio diretório |
| `-E` | Proíbe login anônimo |
| `-H` | Não resolve DNS reverso do cliente |
| `-j` | Cria o diretório home do usuário se não existir |
| `-R` | Proíbe `chmod` pelo cliente |
| `-c <n>` | Máximo de clientes simultâneos (`FTP_MAX_CLIENTS`) |
| `-C <n>` | Máximo de clientes por IP (`FTP_MAX_CLIENTS_PER_IP`) |
| `-I 15` | Tempo máximo de ociosidade: 15 minutos |
| `-L 10000:8` | Limite de `ls`: 10000 arquivos, profundidade 8 |
| `-u 10000` | UID mínimo autorizado a logar (bloqueia contas de sistema) |
| `-U 133:022` | `umask`: 133 para arquivos, 022 para diretórios |
| `-l puredb:/auth/pureftpd.pdb` | Backend de autenticação |
| `-p INICIO:FIM` | Faixa de portas passivas |
| `-P <ip>` | IP anunciado no `PASV` (`FTP_PUBLIC_IP`) |
| `-S 0.0.0.0,2121` | Escuta na porta 2121 (não privilegiada) |
| `-Y <modo>` | Política TLS (`FTP_TLS_MODE`): veja [⚙️ Configuração](configuracao.md#tls) |
| `-O clf:/dev/stdout` | Log de acesso em formato CLF no `stdout` |

---

<a name="healthcheck"></a>

## 🩺 Healthcheck

```yaml
test: ["CMD-SHELL", "pidof pure-ftpd >/dev/null"]
interval: 20s   timeout: 5s   retries: 5   start_period: 20s
```

Verifica apenas que o processo está vivo. Para uma checagem funcional (o usuário existe no PureDB), use `./scripts/validate.sh --runtime`: veja [⌨️ Scripts](scripts.md#validate).

---

<a name="endurecimento-resumo"></a>

## 🧱 Endurecimento

| Medida | Onde |
|---|---|
| Raiz somente leitura | `read_only: true` |
| Sem privilégios além do necessário | `cap_drop: ALL` e só as capabilities que o `pure-ftpd` usa (chroot, troca de uid e gid, `nice`) |
| Sem ganho de privilégio | `no-new-privileges: true` |
| Limites de recurso | `pids_limit`, `mem_limit`, `cpus`, `ulimits.nofile` |
| Log com rotação | `logging: local`, 10 MB × 3 |

Justificativa de cada diretiva e de cada `cap_add`: [🔐 Segurança](seguranca.md#hardening-do-compose-yaml-linha-a-linha).

---

⬅️ [🎚️ Perfis](perfis.md) · 🏠 [Documentação](README.md) · ➡️ [🔐 Segurança](seguranca.md)
