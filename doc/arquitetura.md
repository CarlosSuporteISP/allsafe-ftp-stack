# 🏗️ Arquitetura — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [📚 Índice da documentação](README.md)

## 💡 Em poucas palavras

A stack tem dois containers: o servidor FTP e o painel web que administra os usuários dele. Quatro "gavetas" sobrevivem a reinícios: uma para os arquivos enviados, uma para a lista de usuários, uma para o certificado do FTP e uma para o certificado e o histórico do painel. O usuário opera pelo painel ou pelo host, com scripts; os equipamentos de rede conectam pela porta do FTP e enviam o backup.

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
        env@{ shape: doc, label: "📄 .env<br>configuração e limites" }
        segredo@{ shape: doc, label: "🔑 .secrets<br>senha do FTP, hash do painel" }
    end
    subgraph CONTAINERS["🐳 Containers · rede allsafe-ftp-network"]
        painel@{ shape: rect, label: "🖥️ Painel web<br>allsafe-ftp-painel, 8443/tcp" }
        ftp@{ shape: rect, label: "⚙️ Pure-FTPd<br>allsafe-ftp, 2121/tcp" }
        logs@{ shape: docs, label: "📚 log CLF<br>stdout" }
    end
    subgraph VOLUMES["💽 Volumes"]
        vpainel@{ shape: lin-cyl, label: "💽 DATA_DIR/painel<br>/painel, certificado e auditoria" }
        vauth@{ shape: cyl, label: "🗄️ DATA_DIR/auth<br>/auth, PureDB" }
        vcerts@{ shape: lin-cyl, label: "💽 DATA_DIR/certs<br>/etc/ssl/private" }
        vdata@{ shape: lin-cyl, label: "💽 DATA_DIR/dados<br>/data" }
    end
    subgraph RESULTADO["🏁 Resultado"]
        fim@{ shape: stadium, label: "🏁 backup guardado" }
    end

    operador -- "1 · ./deploy.sh" --> scripts
    scripts -- "2 · docker compose build e up -d --wait" --> ftp
    operador -- "3 · HTTPS, TCP 8443" --> painel
    painel -- "4 · cria, troca a senha ou remove o usuário" --> vauth
    equip -- "5 · FTPS, TCP 21 para 2121" --> ftp
    ftp -- "6 · grava o arquivo, passivo 30000 a 30049" --> vdata
    vdata -- "7 · arquivo no volume" --> fim
    scripts -. "cria, lê e grava o perfil" .-> env
    ftp -. "lê a senha na subida, só leitura" .-> segredo
    painel -. "lê o hash a cada entrada, só leitura" .-> segredo
    ftp -. "consulta os usuários" .-> vauth
    ftp -. "lê o certificado" .-> vcerts
    painel -. "grava certificado e auditoria" .-> vpainel
    painel -. "cria a pasta do usuário" .-> vdata
    ftp -. "grava cada transferência" .-> logs
```

<sub>📐 Nível 2 · Mapa · 🔍 aproximar e mover: controles no canto do diagrama · 📁 [fonte](diagramas/)</sub>

| Nº | De ➜ Para | O que acontece |
|---|---|---|
| 1 | 👤 Usuário ➜ ⌨️ `deploy.sh` | O usuário executa `./deploy.sh` no host |
| 2 | ⌨️ `deploy.sh` ➜ ⚙️ Pure-FTPd | O script valida a configuração, constrói as imagens (`docker compose build`), sobe os dois containers (`up -d --wait`) e espera ficarem `healthy` |
| 3 | 👤 Usuário ➜ 🖥️ Painel web | O usuário abre o painel por HTTPS em `8443/tcp` |
| 4 | 🖥️ Painel web ➜ 🗄️ `DATA_DIR/auth` | O painel cria, troca a senha ou remove o usuário no PureDB |
| 5 | 📡 Equipamento de rede ➜ ⚙️ Pure-FTPd | O cliente conecta por FTPS em `21/tcp`, mapeada para `2121/tcp` |
| 6 | ⚙️ Pure-FTPd ➜ 💽 `DATA_DIR/dados` | O arquivo é gravado pelo canal passivo `30000-30049/tcp` |
| 7 | 💽 `DATA_DIR/dados` ➜ 🏁 backup guardado | O arquivo fica na pasta do usuário, no host |

**🧷 Apoio**

| Quem | Usa | Como |
|---|---|---|
| ⌨️ `deploy.sh` e `manage-user.sh` | 📄 `.env` | cria, lê e grava o perfil |
| ⚙️ Pure-FTPd | 🔑 `.secrets` (`ftp_password.txt`) | lê a senha na subida, somente leitura |
| 🖥️ Painel web | 🔑 `.secrets` (`painel_password_hash.txt`) | lê o hash a cada entrada, somente leitura |
| ⚙️ Pure-FTPd | 🗄️ `DATA_DIR/auth` (PureDB) | consulta os usuários |
| ⚙️ Pure-FTPd | 💽 `DATA_DIR/certs` | lê o certificado |
| 🖥️ Painel web | 💽 `DATA_DIR/painel` | grava o certificado e a auditoria |
| 🖥️ Painel web | 💽 `DATA_DIR/dados` | cria a pasta do usuário |
| ⚙️ Pure-FTPd | 📚 log CLF (`stdout`) | grava cada transferência |

---

<a name="componentes"></a>

## 🧩 Componentes

| Peça | Onde | Papel |
|---|---|---|
| Serviço `ftp` | [`compose.yaml`](../compose.yaml) | Container do servidor FTP (`allsafe-ftp`) |
| Serviço `painel` | [`compose.yaml`](../compose.yaml) | Container do painel web (`allsafe-ftp-painel`); só inicia depois de o `ftp` ficar `healthy` |
| Imagens | [`Dockerfile`](../Dockerfile) | Uma base e dois alvos. Base: `debian:bookworm-slim` fixada por digest, com `pure-ftpd`, `pure-ftpd-common`, `openssl`, `procps` e `ca-certificates`. Alvo `ftp`: a base e o entrypoint do FTP. Alvo `painel`: a base, `python3` e o painel |
| Usuário do processo de dados | [`Dockerfile`](../Dockerfile) | `ftpdata`, uid e gid **10000**, shell `nologin`, sem home |
| Entrypoint | [`scripts/entrypoint.sh`](../scripts/entrypoint.sh), instalado como `/usr/local/sbin/allsafe-ftp-entrypoint` | Provisiona usuário e certificado e faz `exec` do `pure-ftpd` |
| Gestão de usuários | [`scripts/ftp-user.sh`](../scripts/ftp-user.sh), instalado nas duas imagens como `/usr/local/sbin/allsafe-ftp-user` | `add`, `passwd`, `del` e `list` no PureDB, chamado de fora por [`manage-user.sh`](../manage-user.sh) e, dentro do painel, pelo servidor web |
| Painel web | [`painel/servidor.py`](../painel/servidor.py) e [`painel/estilo.css`](../painel/estilo.css), em `/opt/painel` | Servidor HTTPS em Python, só com a biblioteca padrão e sem JavaScript: telas, sessão e auditoria |
| Entrypoint do painel | [`scripts/painel-entrypoint.sh`](../scripts/painel-entrypoint.sh), instalado como `/usr/local/sbin/allsafe-painel-entrypoint` | Confere a rede privada, gera o certificado e faz `exec` do servidor |

O que cada script faz, com parâmetros e saída: [⌨️ Scripts](scripts.md). Uso e proteções do painel: [🖥️ Painel web](painel.md).

---

<a name="volumes"></a>

## 💽 Volumes

| Pasta no host | Monta em | Quem monta | Guarda |
|---|---|---|---|
| `DATA_DIR/dados` | `/data` | `ftp` e `painel` | Arquivos dos usuários: um diretório `chroot` por usuário (`/data/<usuario>`) |
| `DATA_DIR/auth` | `/auth` | `ftp` e `painel` | Base **PureDB**: `pureftpd.passwd` (texto, com o hash das senhas) e `pureftpd.pdb` (compilada), ambos `0600`; `ftp-cert.pem`, cópia do certificado do FTP **sem a chave**; `.lock`, a trava das alterações |
| `DATA_DIR/certs` | `/etc/ssl/private` | só `ftp` | `pure-ftpd.pem`: chave e certificado concatenados, `0600` |
| `DATA_DIR/painel` | `/painel` | só `painel` | `tls/painel-cert.pem`, `tls/painel-key.pem` (`0600`) e `auditoria.log` (`0600`); pasta `0700` |
| segredo `ftp_password` (`SECRETS_DIR/ftp_password.txt`) | `/run/secrets/ftp_password` (somente leitura) | só `ftp` | Senha do usuário inicial |
| segredo `painel_password_hash` (`SECRETS_DIR/painel_password_hash.txt`) | `/run/secrets/painel_password_hash` (somente leitura) | só `painel` | Hash `scrypt` da senha do painel |

Cada serviço vê um único arquivo de `.secrets/`. Além disso, cada container tem dois `tmpfs`: `/run` (8 MiB) e `/tmp` (16 MiB), ambos `noexec,nosuid,nodev`.

---

<a name="rede"></a>

## 🌐 Rede

- Rede bridge dedicada `allsafe-ftp-network`, sub-rede `172.29.1.0/29` (variável `FTP_SUBNET`), com os dois containers.
- Publicações no host (veja [⚙️ Configuração](configuracao.md#rede-e-portas) e [🖥️ Painel web](configuracao.md#painel)):

| Publicação | Para quê |
|---|---|
| `FTP_BIND_IP:FTP_PORT` ➜ `2121/tcp` | canal de controle |
| `FTP_BIND_IP:30000-30049` ➜ `30000-30049/tcp` | canal de dados, modo passivo, 1:1 |
| `PAINEL_BIND_IP:PAINEL_PORT` ➜ `8443/tcp` | painel web, HTTPS |

- O painel não conversa com o FTP pela rede: os dois dividem as pastas `auth` e `dados`.
- Quem abre o painel pelo próprio servidor, em `127.0.0.1`, chega ao container com o endereço do gateway desta rede (`172.29.1.1`), que já está dentro das redes permitidas por padrão.
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
        deploy@{ shape: console, label: "⌨️ deploy.sh<br>instala em um comando" }
    end
    subgraph HOST["🖥️ Host"]
        env@{ shape: doc, label: "📄 .env<br>configuração e limites" }
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
    deploy -- "2 · docker compose build e up -d --wait" --> compose
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
| 1 | 👤 Usuário ➜ ⌨️ `deploy.sh` | Executa `./deploy.sh` | — | Sem `.env`, o script cria um a partir do exemplo e segue; antes de agir confere Docker, Compose e portas livres |
| 2 | ⌨️ `deploy.sh` ➜ 🐳 Docker Compose | Roda `docker compose build` e `up -d --wait` com o `.env` | — | Antes roda `config --quiet`; configuração inválida não sobe |
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
| 🐳 Docker Compose | 📄 `.env` | lê |
| ⚙️ entrypoint | 🔑 `.secrets/ftp_password.txt` | lê, somente leitura |
| ⚙️ entrypoint | 💽 `/data` | cria a pasta do usuário |
| 👥 `pure-pw` | 🗄️ PureDB (`/auth/pureftpd.pdb`) | grava |
| 🔏 `openssl` | 📄 `pure-ftpd.pem` | grava |
| ⚙️ `pure-ftpd` | 📄 `pure-ftpd.pem` | lê |
| ⚙️ `pure-ftpd` | 🗄️ PureDB | consulta |

Nas subidas seguintes o usuário inicial é **atualizado** (`usermod`) e o certificado existente é **mantido**. Com o FTP `healthy`, o Compose inicia o painel: o que o entrypoint dele confere está em [⌨️ Scripts](scripts.md#painel-entrypoint).

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

O painel tem o dele, que abre uma conexão HTTPS de verdade com o próprio servidor:

```yaml
test: ["CMD", "python3", "/opt/painel/servidor.py", "--saude"]
interval: 20s   timeout: 8s   retries: 5   start_period: 20s
```

---

<a name="endurecimento-resumo"></a>

## 🧱 Endurecimento

| Medida | Onde |
|---|---|
| Raiz somente leitura | `read_only: true` |
| Sem privilégios além do necessário | `cap_drop: ALL`; o `ftp` recebe só as capabilities que o `pure-ftpd` usa (chroot, troca de uid e gid, `nice`) e o `painel`, só três (`CHOWN`, `DAC_OVERRIDE`, `FOWNER`) |
| Sem controle do Docker | nenhum container monta o socket do Docker |
| Sem ganho de privilégio | `no-new-privileges: true` |
| Limites de recurso | `pids_limit`, `mem_limit`, `cpus`, `ulimits.nofile` |
| Log com rotação | `logging: local`, 10 MB × 3 |

Justificativa de cada diretiva e de cada `cap_add`: [🔐 Segurança](seguranca.md#hardening-do-compose-yaml-linha-a-linha).

---

⬅️ [🎚️ Perfis](perfis.md) · 🏠 [Documentação](README.md) · ➡️ [🔐 Segurança](seguranca.md)
