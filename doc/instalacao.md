# 🚀 Instalação — allsafe-ftp-stack

Guia passo a passo. Para a versão curta, veja a seção
[🚀 Instalação rápida](../README.md#-instalação-rápida) do `README.md`.

---

## 🧭 Sumário

[✅ Pré-requisitos](#-pré-requisitos) · [1️⃣ Configuração base](#1️-configuração-base) · [2️⃣ Senha do usuário inicial](#2️-senha-do-usuário-inicial) · [3️⃣ Subir a stack](#3️-subir-a-stack) · [4️⃣ Validar](#4️-validar) · [♻️ Como desfazer](#️-como-desfazer) · [⏭️ Próximos passos](#️-próximos-passos)

---

## ✅ Pré-requisitos

| Item | Detalhe |
|---|---|
| 🐳 Docker Engine + Compose v2 | `docker compose version` deve responder. |
| 🌐 Um IP dedicado para o FTP | Não compartilhe o IP com outros serviços; o modo passivo abre 50 portas. |
| 🔥 Firewall no host | Libere `21/tcp` e `30000-30049/tcp` **só** para as redes de gerência dos equipamentos. |
| 🕰️ Relógio sincronizado | O certificado TLS depende de data/hora corretas (veja `../../08-time/allsafe-ntp-nts-stack/`). |

---

## 1️⃣ Configuração base

```bash
cp .env.example .env
```

Isto cria o [`.env`](../.env.example). Cada variável está explicada em
[`configuracao.md`](configuracao.md). Os campos que **você precisa** rever:

| Variável | Troque para |
|---|---|
| `FTP_BIND_IP` | o IP dedicado do servidor (em produção, **nunca** `127.0.0.1`). |
| `FTP_PUBLIC_IP` | o IP que o cliente enxerga — igual ao `FTP_BIND_IP`, ou o IP público se houver NAT 1:1. |
| `FTP_CERT_CN` | o hostname (ex.: `ftp.exemplo.com.br`) ou IP que vai no certificado. |
| `FTP_USER` | nome do usuário inicial (padrão `transfer`). Regra: `^[a-z_][a-z0-9_-]{0,31}$`. |

---

## 2️⃣ Senha do usuário inicial

Nada a fazer aqui na primeira vez: o [`deploy.sh`](../deploy.sh) **gera uma senha
forte** (`openssl rand -base64 36`) em `.secrets/ftp_password.txt` com permissão
`0600` se o arquivo estiver vazio/ausente. Anote-a para configurar o cliente FTP:

```bash
cat .secrets/ftp_password.txt      # após o primeiro deploy
```

Para usar uma senha própria, grave-a **antes** de rodar o `deploy.sh`:

```bash
printf '%s' 'uma-senha-forte-de-12+-caracteres' > .secrets/ftp_password.txt
chmod 600 .secrets/ftp_password.txt
```

- Mínimo **12 caracteres** — o [`entrypoint.sh`](../scripts/entrypoint.sh) recusa senhas menores (a gerada tem ~48).
- O arquivo é montado somente-leitura em `/run/.secrets/ftp_password.txt` (via `FTP_PASSWORD_FILE`).
- Arquivos `.txt` de [`.secrets/`](segredos.md) são ignorados pelo Git.
- Alternativa (não recomendada): definir `FTP_PASSWORD` direto no `.env` e deixar `FTP_PASSWORD_FILE` vazio.

---

## 3️⃣ Subir a stack

```bash
./deploy.sh --size small     # ou: medium | large (padrão: small)
```

O [`deploy.sh`](../deploy.sh):

1. resolve o perfil `--size` e carrega [`profiles/<perfil>.env`](../profiles/) por cima do `.env`;
2. cria o `.env` a partir do exemplo se ele não existir (e para, pedindo revisão);
3. roda `docker compose config --quiet` (falha cedo se o `.env` estiver inválido) — com `--check-only` para por aqui;
4. `docker compose up -d --build`;
5. `docker compose ps`.

Qual perfil usar: [`perfis.md`](perfis.md).

Na **primeira** subida o [`entrypoint.sh`](../scripts/entrypoint.sh):

- cria `/data/$FTP_USER` com dono `ftpdata`;
- grava o usuário no PureDB (`/auth/pureftpd.pdb`);
- gera um **certificado autoassinado** RSA 3072 (825 dias) em
  `/etc/ssl/private/pure-ftpd.pem`, com SAN de acordo com `FTP_CERT_CN` (IP ou DNS);
- executa o `pure-ftpd` escutando em `:2121`.

---

## 4️⃣ Validar

```bash
./scripts/validate.sh            # sintaxe dos scripts + compose (sem subir nada)
./scripts/validate.sh --runtime  # exige container 'running' e healthcheck 'healthy'
```

Teste manual com um cliente (FTP **explícito** sobre TLS, modo passivo):

```bash
# lftp respeita FTPS explícito por padrão
lftp -u "$FTP_USER" -e 'set ssl:verify-certificate no; ls; bye' ftp://SEU_IP
```

> ⚠️ Como o certificado inicial é autoassinado, o cliente vai reclamar da
> validação até você instalar um certificado real — veja
> [`operacao.md`](operacao.md#-certificado-real-de-produção).

---

## ♻️ Como desfazer

```bash
docker compose down             # remove o container, mantém os volumes
docker compose down -v          # remove TAMBÉM os volumes (apaga dados, PureDB e certificado)
```

Os arquivos dos usuários ficam no volume `allsafe-ftp-data`; enquanto você não
usar `-v`, nada é perdido.

---

## ⏭️ Próximos passos

- Criar mais usuários: [`operacao.md`](operacao.md#-usuários).
- Colocar em produção: [`seguranca.md`](seguranca.md) + certificado real.
- Monitoramento: a stack `allsafe-zabbix-isp-stack` acompanha o container.
