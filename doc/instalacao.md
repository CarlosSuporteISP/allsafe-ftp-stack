# 🚀 Instalação — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [📚 Índice da documentação](README.md)

## 💡 Em poucas palavras

Você copia o arquivo de configuração, informa o IP do servidor, roda um script e o servidor FTP sobe sozinho, já com senha forte e conexão criptografada. No fim, um segundo script confere se está tudo no ar. Leva poucos minutos e dá para desfazer sem perder os arquivos.

<!-- diagrama: diagramas/instalacao-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    usuario@{ shape: person, label: "👤 Usuário" }
    env@{ shape: doc, label: "📄 .env<br>IP, porta e usuário" }
    deploy@{ shape: console, label: "⌨️ deploy.sh<br>gera a senha e sobe" }
    ftp@{ shape: rect, label: "⚙️ Pure-FTPd<br>allsafe-ftp" }
    valida@{ shape: console, label: "🧪 validate.sh<br>confere a subida" }
    fim@{ shape: stadium, label: "🏁 FTP pronto" }

    usuario --> env --> deploy --> ftp --> valida --> fim
```

<sub>📐 Nível 1 · Diagrama · 🔍 aproximar e mover: controles no canto do diagrama · 📁 [fonte](diagramas/)</sub>

**🧭 Sequência:** 👤 Usuário ➜ 📄 `.env` ➜ ⌨️ `deploy.sh` ➜ ⚙️ Pure-FTPd (`allsafe-ftp`) ➜ 🧪 `validate.sh` ➜ 🏁 FTP pronto

---

<details>
<summary>🧭 Sumário — clique para expandir</summary>

[✅ Pré-requisitos](#pre-requisitos) · [1️⃣ Configuração base](#1-configuracao-base) · [2️⃣ Senha do usuário inicial](#2-senha-do-usuario-inicial) · [3️⃣ Subir a stack](#3-subir-a-stack) · [4️⃣ Validar](#4-validar) · [♻️ Como desfazer](#como-desfazer) · [⏭️ Próximos passos](#proximos-passos)

</details>

---

<a name="pre-requisitos"></a>

## ✅ Pré-requisitos

| Item | Detalhe |
|---|---|
| 🐳 Docker Engine com Docker Compose v2 ou mais novo | `docker compose version` deve responder |
| 🌐 Um IP dedicado para o FTP | Não compartilhe o IP com outros serviços; o modo passivo abre 50 portas |
| 🔥 Firewall no host | Libere `21/tcp` e `30000-30049/tcp` **só** para as redes de gerência dos equipamentos |
| 🕰️ Relógio sincronizado | O certificado TLS depende de data e hora corretas (a stack `allsafe-ntp-nts-stack` cuida disso) |

---

<a name="1-configuracao-base"></a>

## 1️⃣ Configuração base

```bash
cp .env.example .env
```

**Resultado esperado:** o arquivo `.env` passa a existir na raiz da stack.

Cada variável está explicada em [⚙️ Configuração](configuracao.md). Os campos que **você precisa** rever:

| Variável | Troque para |
|---|---|
| `FTP_BIND_IP` | o IP dedicado do servidor (em produção, **nunca** `127.0.0.1`) |
| `FTP_PUBLIC_IP` | o IP que o cliente enxerga: igual ao `FTP_BIND_IP`, ou o IP público se houver NAT 1:1 |
| `FTP_CERT_CN` | o hostname (exemplo: `ftp.exemplo.com.br`) ou IP que vai no certificado |
| `FTP_USER` | nome do usuário inicial (padrão `transfer`). Regra: `^[a-z_][a-z0-9_-]{0,31}$` |

> 💡 Se você pular este passo, a primeira execução do `deploy.sh` cria o `.env` a partir do exemplo e para, com a mensagem `Edite <pasta>/.env e execute novamente.`

---

<a name="2-senha-do-usuario-inicial"></a>

## 2️⃣ Senha do usuário inicial

Nada a fazer aqui na primeira vez: o [`deploy.sh`](../deploy.sh) **gera uma senha forte** em `.secrets/ftp_password.txt`, com permissão `0600`, se o arquivo estiver vazio ou ausente. Anote-a para configurar o cliente FTP:

```bash
cat .secrets/ftp_password.txt      # depois do primeiro deploy
```

**Resultado esperado:** uma linha com a senha gerada, de cerca de 48 caracteres.

Para usar uma senha própria, grave-a **antes** de rodar o `deploy.sh`:

```bash
printf '%s' 'uma-senha-forte-de-12+-caracteres' > .secrets/ftp_password.txt
chmod 600 .secrets/ftp_password.txt
```

<details>
<summary>🔬 Detalhe técnico — regras da senha</summary>

- A senha é gerada com `openssl rand -base64 36`; o `openssl` é exigido no host.
- Mínimo de **12 caracteres**: o [`entrypoint.sh`](../scripts/entrypoint.sh) recusa senhas menores.
- O arquivo chega ao container como o segredo `/run/secrets/ftp_password`, somente leitura; o serviço não vê o resto de `.secrets/`.
- Arquivos `.txt` de `.secrets/` são ignorados pelo Git. Veja [🔑 Segredos](segredos.md).
- Senha no `.env` **não é aceita**: o `deploy.sh` recusa um `.env` com `FTP_PASSWORD` preenchido e o container recusa a variável.

</details>

---

<a name="3-subir-a-stack"></a>

## 3️⃣ Subir a stack

```bash
./deploy.sh --size small     # ou: medium | large (padrão: small)
```

**Resultado esperado:** a tabela do `docker compose ps` com o container `allsafe-ftp` em `health: starting` e, segundos depois, `healthy`. Na primeira vez aparece também `Gerada uma senha forte em .secrets/ftp_password.txt (0600). Guarde-a para o cliente FTP.`

Qual perfil usar: [🎚️ Perfis](perfis.md).

<details>
<summary>🔬 Detalhe técnico — o que o <code>deploy.sh</code> e o entrypoint fazem</summary>

O [`deploy.sh`](../deploy.sh), nesta ordem:

1. resolve o perfil de `--size` e confere que `profiles/<perfil>.env` existe;
2. cria o `.env` a partir do exemplo se ele não existir (e para, pedindo revisão);
3. gera a senha em `.secrets/ftp_password.txt` se o arquivo estiver vazio;
4. roda `docker compose --env-file .env --env-file profiles/<perfil>.env config --quiet`, que falha cedo se a configuração estiver inválida; com `--check-only` para por aqui, com `OK: perfil '<perfil>' e compose validados; nada foi alterado.`;
5. `docker compose up -d --build`;
6. `docker compose ps`.

Na **primeira** subida o [`entrypoint.sh`](../scripts/entrypoint.sh):

- cria `/data/$FTP_USER` com dono `ftpdata`;
- grava o usuário no PureDB (`/auth/pureftpd.pdb`);
- gera um **certificado autoassinado** RSA 3072, válido por 825 dias, em `/etc/ssl/private/pure-ftpd.pem`, com SAN de acordo com `FTP_CERT_CN` (IP ou DNS);
- executa o `pure-ftpd` escutando em `:2121`.

O modelo completo da subida está em [🏗️ Arquitetura](arquitetura.md#subida).

</details>

---

<a name="4-validar"></a>

## 4️⃣ Validar

```bash
./scripts/validate.sh            # sintaxe dos scripts e Compose de todos os perfis, sem subir nada
./scripts/validate.sh --runtime  # exige o container 'running', 'healthy' e o usuário no PureDB
```

**Resultado esperado:** `compose OK com large.env`, `compose OK com medium.env`, `compose OK com small.env` e, no fim, `Validacao FTP concluida.`

Teste manual com um cliente (FTP **explícito** sobre TLS, modo passivo):

```bash
# o lftp usa FTPS explícito por padrão
lftp -u "$FTP_USER" -e 'set ssl:verify-certificate no; ls; bye' ftp://SEU_IP
```

**Resultado esperado:** o `lftp` pede a senha e lista a pasta do usuário, vazia na primeira vez.

> ⚠️ Como o certificado inicial é autoassinado, o cliente vai reclamar da validação até você instalar um certificado real. Veja [🧰 Operação](operacao.md#certificado-real-de-producao).

---

<a name="como-desfazer"></a>

## ♻️ Como desfazer

```bash
docker compose down             # remove o container, mantém os volumes
docker compose down -v          # remove TAMBÉM os volumes (apaga dados, PureDB e certificado)
```

**Resultado esperado:** `docker compose ps` não lista mais o `allsafe-ftp`.

Os arquivos dos usuários ficam em `DATA_DIR/dados`, no host: `docker compose down` não apaga nada.

---

<a name="proximos-passos"></a>

## ⏭️ Próximos passos

- Criar mais usuários: [🧰 Operação](operacao.md#usuarios).
- Colocar em produção: [🔐 Segurança](seguranca.md) e o certificado real.
- Monitoramento: a stack `allsafe-zabbix-isp-stack` acompanha o container.

---

⬅️ [README do projeto](../README.md) · 🏠 [Documentação](README.md) · ➡️ [⚙️ Configuração](configuracao.md)
