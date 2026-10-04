# 🚀 Instalação — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [Índice da documentação](README.md)

## 💡 Em poucas palavras

Você roda um comando e o servidor FTP sobe sozinho, já com senha forte e conexão criptografada, junto com o painel web para administrar os usuários e o nginx, que fica na frente do painel. Ele nasce atendendo só o próprio servidor; para atender a rede interna, você informa o IP privado no arquivo de configuração e roda o mesmo comando de novo. No fim, um segundo script confere se está tudo no ar. Leva poucos minutos e dá para desfazer sem perder os arquivos.

<!-- diagrama: diagramas/instalacao-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    usuario@{ shape: person, label: "Usuário" }
    deploy@{ shape: console, label: "deploy.sh<br>cria o .env, gera as senhas e sobe" }
    stack@{ shape: rect, label: "Docker Compose<br>FTP, painel e nginx" }
    valida@{ shape: console, label: "validate.sh<br>confere a subida" }
    fim@{ shape: stadium, label: "FTP e painel prontos" }

    usuario --> deploy --> stack --> valida --> fim
```

<sub>Nível 1 · Diagrama · [fonte](diagramas/)</sub>

**Sequência:** Usuário ➜ `deploy.sh` (cria o `.env`, gera as senhas e sobe) ➜ Docker Compose (FTP, painel e nginx) ➜ `validate.sh` ➜ FTP e painel prontos

---

<details>
<summary>Sumário — clique para expandir</summary>

[Pré-requisitos](#pre-requisitos) · [1️⃣ Configuração base](#1-configuracao-base) · [2️⃣ Senha do usuário inicial](#2-senha-do-usuario-inicial) · [3️⃣ Subir a stack](#3-subir-a-stack) · [4️⃣ Validar](#4-validar) · [Como desfazer](#como-desfazer) · [Próximos passos](#proximos-passos)

</details>

---

<a name="pre-requisitos"></a>

## ✅ Pré-requisitos

| Item | Detalhe |
|---|---|
| Docker Engine com Docker Compose v2 ou mais novo | `docker compose version` deve responder |
| CPU e memória para o perfil | O `small` pede 1 CPU e 256 MB; o `extended`, 16 CPUs e 4 GB. O `deploy.sh` confere e recusa o perfil maior que o servidor: [Perfis](perfis.md#o-servidor-aguenta) |
| Um IP dedicado para o FTP | Não compartilhe o IP com outros serviços; o modo passivo abre de 50 a 1600 portas, conforme o perfil |
| Firewall no host | Libere `21/tcp` e a faixa passiva do perfil (`30000-30049/tcp` no `small`) **só** para as redes de gerência dos equipamentos, e a porta do painel (`8443/tcp`) **só** para quem administra |
| Rede privada | A stack só aceita IP interno: veja [Segurança](seguranca.md#rede-privada) |
| Relógio sincronizado | O certificado TLS depende de data e hora corretas (a stack `allsafe-ntp-nts-stack` cuida disso) |

---

<a name="1-configuracao-base"></a>

## 1️⃣ Configuração base

Este passo é **opcional na primeira vez**: sem `.env`, o [`deploy.sh`](../deploy.sh) cria um a partir do exemplo, com tudo em `127.0.0.1` (só o próprio servidor acessa), e segue. Para já subir atendendo a rede interna, crie e ajuste o arquivo antes:

```bash
cp .env.example .env
chmod 600 .env
```

**Resultado esperado:** o arquivo `.env` passa a existir na raiz da stack.

Cada variável está explicada em [Configuração](configuracao.md). Os campos que **você precisa** rever:

| Variável | Troque para |
|---|---|
| `FTP_BIND_IP` | o IP **privado** dedicado do servidor (com `127.0.0.1` só o próprio servidor alcança o FTP) |
| `FTP_PASSIVE_IP` | o IP que o cliente enxerga; normalmente igual ao `FTP_BIND_IP`. Também tem de ser privado |
| `PAINEL_BIND_IP` | o IP **privado** por onde o painel será aberto; com `127.0.0.1` ele só abre no próprio servidor |
| `FTP_CERT_CN` | o hostname (exemplo: `ftp.exemplo.com.br`) ou IP que vai no certificado |
| `FTP_USER` | nome do usuário inicial (padrão `transfer`). Regra: `^[a-z_][a-z0-9_-]{0,31}$` |

> Pulou este passo? Ajuste o `.env` depois e rode `./deploy.sh` de novo: ele reaplica a configuração sem trocar senha nem apagar dado.

---

<a name="2-senha-do-usuario-inicial"></a>

## 2️⃣ Senha do usuário inicial

Nada a fazer aqui na primeira vez: o [`deploy.sh`](../deploy.sh) **gera uma senha forte** em `.secrets/ftp-usuario-inicial-senha.txt`, com permissão `0600`, se o arquivo estiver vazio ou ausente. Anote-a para configurar o cliente FTP:

```bash
cat .secrets/ftp-usuario-inicial-senha.txt      # depois do primeiro deploy
```

**Resultado esperado:** uma linha com a senha gerada, de cerca de 48 caracteres.

Para usar uma senha própria, grave-a **antes** de rodar o `deploy.sh`:

```bash
printf '%s' 'uma-senha-forte-de-12+-caracteres' > .secrets/ftp-usuario-inicial-senha.txt
chmod 600 .secrets/ftp-usuario-inicial-senha.txt
```

<details>
<summary>Detalhe técnico — regras da senha</summary>

- A senha é gerada com `openssl rand -base64 36`; o `openssl` é exigido no host.
- Mínimo de **12 caracteres**: o [`ftp/entrypoint.sh`](../ftp/entrypoint.sh) recusa senhas menores.
- O arquivo chega ao container como o segredo `/run/secrets/ftp_usuario_inicial_senha`, somente leitura; o serviço não vê o resto de `.secrets/`.
- Arquivos `.txt` de `.secrets/` são ignorados pelo Git. Veja [Segredos](segredos.md).
- Senha no `.env` **não é aceita**: o `deploy.sh` recusa um `.env` com `FTP_PASSWORD` preenchido e o container recusa a variável.

</details>

---

<a name="3-subir-a-stack"></a>

## 3️⃣ Subir a stack

```bash
./deploy.sh                  # outro porte: ./deploy.sh --size medium (ou large, xlarge, extended)
```

**Resultado esperado:** o comando só termina com os três containers `healthy` e fecha com o resumo:

```text
Pronto: FTP, painel e nginx no ar (healthy), perfil 'small'.
FTP:    127.0.0.1:21, TLS explícito obrigatório no login, modo passivo 30000-30049
        usuário 'transfer', senha no arquivo ./.secrets/ftp-usuario-inicial-senha.txt
Painel: https://127.0.0.1:8443  (pelo nginx; certificado autoassinado; só rede privada, atrás de firewall)
        senha inicial no arquivo ./.secrets/painel-admin-inicial-senha.txt; troque com ./scripts/painel-senha.sh
Segredos: ./.secrets/LEIAME.txt diz para que serve cada arquivo.
Remover: ./deploy.sh --remover  (os dados ficam em <DATA_DIR>)
```

O resumo diz **onde** está cada senha e nunca a mostra. O `LEIAME.txt` da pasta `.secrets/` explica para que serve cada arquivo dela. Na primeira vez aparecem também `Gerada uma senha forte em .secrets/ftp-usuario-inicial-senha.txt (0600). Guarde-a para o cliente FTP.` e `Gerada uma senha forte para o painel em .secrets/painel-admin-inicial-senha.txt (0600).`

Abra o endereço do painel no navegador e entre com a senha de `.secrets/painel-admin-inicial-senha.txt`. O primeiro acesso, o aviso de certificado e a troca da senha estão em [Painel web](painel.md#abrir).

Qual perfil usar: [Perfis](perfis.md). Nos perfis `xlarge` e `extended` a subida leva minutos, porque o Docker publica as portas passivas uma a uma: [tempo de subida](perfis.md#tempo-de-subida).

> ⚠️ **Equipamento antigo que não fala TLS?** O padrão exige TLS e recusa esse equipamento. Existe a opção `FTP_TLS_MODE=0` (ou `1`), que aceita FTP em texto puro e deixa senha e arquivo legíveis para quem estiver na mesma rede. Leia as condições antes de ligar: [Segurança](seguranca.md#ftp-sem-tls).

<details>
<summary>Detalhe técnico — o que o <code>deploy.sh</code> e o entrypoint fazem</summary>

O [`deploy.sh`](../deploy.sh), nesta ordem:

1. confere os requisitos: `docker`, o plugin `docker compose` e o serviço do Docker respondendo;
2. confere que o servidor tem as CPUs e a memória que o perfil pede; se não tiver, para sem alterar nada;
3. cria o `.env` a partir do exemplo (`0600`) se ele não existir, e segue; em instalação com os nomes antigos, troca `FTP_PUBLIC_IP` por `FTP_PASSIVE_IP` no `.env`, depois de copiá-lo para `BACKUP_DIR`, e dá o nome novo aos arquivos de `.secrets/`;
4. recusa senha no `.env`, endereço ou rede fora de IP privado e `FTP_TLS_MODE` fora de `0` a `3`;
5. com `--size`, grava no `.env` os valores de `profiles/<perfil>.env` e o nome do perfil em `FTP_PROFILE`; sem `--size`, o `.env` fica como está;
6. confere que a porta do FTP, a do painel e a faixa passiva estão livres no host (as que a própria stack já publica não contam); porta ocupada para o comando com `ERRO: porta já em uso por outro programa: ...`;
7. cria as pastas `dados/`, `auth/`, `certs/`, `painel/` e `nginx/` em `DATA_DIR` gera a senha em `.secrets/ftp-usuario-inicial-senha.txt` se o arquivo estiver vazio e grava o `.secrets/LEIAME.txt`;
8. roda `docker compose --env-file .env config --quiet`, que falha cedo se a configuração estiver inválida;
9. `docker compose build`, que constrói as três imagens (com `--atualizar`, `build --no-cache`);
10. gera a senha inicial do painel e grava o hash dela, se ainda não houver hash;
11. `docker compose up -d --wait`, que só volta com os três containers `healthy` (limite de 180 s mais um quarto de segundo por porta passiva);
12. `docker compose ps`, o resumo com os endereços, o modo de TLS e o lugar de cada senha e, nos modos `0` e `1`, o aviso de FTP sem criptografia.

Com `--check-only`, o script para depois do passo 4 e de um `config --quiet`, sem criar `.env`, pasta ou senha, com `OK: perfil '<perfil>', rede privada, recursos do servidor e compose validados; nada foi alterado.`

Na **primeira** subida o [`ftp/entrypoint.sh`](../ftp/entrypoint.sh):

- cria `/data/$FTP_USER` com dono `ftpdata`;
- grava o usuário no PureDB (`/auth/pureftpd.pdb`);
- gera um **certificado autoassinado** RSA 3072, válido por 825 dias, em `/etc/ssl/private/pure-ftpd.pem`, com SAN de acordo com `FTP_CERT_CN` (IP ou DNS);
- executa o `pure-ftpd` escutando em `:2121`.

Com o FTP `healthy`, o painel inicia: gera o próprio certificado autoassinado (EC P-256, 825 dias) em `DATA_DIR/painel/tls`, entrega uma cópia ao nginx e abre o soquete Unix em `DATA_DIR/nginx`. Com o painel `healthy`, o nginx inicia e escuta em `:8443`.

O modelo completo da subida está em [Arquitetura](arquitetura.md#subida).

</details>

---

<a name="4-validar"></a>

## 4️⃣ Validar

```bash
./scripts/validate.sh            # sintaxe dos scripts e Compose de todos os perfis, sem subir nada
./scripts/validate.sh --runtime  # exige os três serviços 'running' e 'healthy' e o usuário no PureDB
```

**Resultado esperado:** `painel/servidor.py OK` (se o host tiver `python3`), uma linha `compose OK com <perfil>.env` para cada um dos cinco perfis e, no fim, `Validacao FTP concluida.`

Teste manual com um cliente (FTP **explícito** sobre TLS, modo passivo):

```bash
# o lftp usa FTPS explícito por padrão
lftp -u "$FTP_USER" -e 'set ssl:verify-certificate no; ls; bye' ftp://SEU_IP
```

**Resultado esperado:** o `lftp` pede a senha e lista a pasta do usuário, vazia na primeira vez.

> ⚠️ Como o certificado inicial é autoassinado, o cliente vai reclamar da validação até você instalar um certificado real. Veja [Operação](operacao.md#certificado-real-de-producao).

---

<a name="como-desfazer"></a>

## ♻️ Como desfazer

```bash
./deploy.sh --remover           # remove os containers e a rede; dados, segredos e .env ficam
```

**Resultado esperado:** `Removidos os containers e a rede. Os dados continuam em <DATA_DIR>.` e `docker compose ps` não lista mais o `allsafe-ftp`, o `allsafe-ftp-painel` nem o `allsafe-ftp-nginx`. Um novo `./deploy.sh` sobe tudo de volta com os mesmos dados e as mesmas senhas.

Os arquivos dos usuários, o PureDB e os certificados ficam em `DATA_DIR`, no host: a remoção não apaga nada (nem um `docker compose down -v` apagaria). Para apagar de vez, use `./deploy.sh --remover --apagar-dados`: ele pede para digitar `apagar` e remove as pastas `dados/`, `auth/`, `certs/`, `painel/` e `nginx/` de `DATA_DIR`; os segredos e o `.env` continuam.

---

<a name="proximos-passos"></a>

## ⏭️ Próximos passos

- Trocar a senha inicial do painel: [Segredos](segredos.md#senha-do-painel).
- Criar mais usuários: pelo [painel](painel.md#usuarios) ou por [Operação](operacao.md#usuarios).
- Colocar em produção: [Segurança](seguranca.md#o-que-endurecer-antes-de-producao) e o certificado real.
- Monitoramento: a stack `allsafe-zabbix-isp-stack` acompanha o container.

---

⬅️ [README do projeto](../README.md) · 🏠 [Documentação](README.md) · ➡️ [Configuração](configuracao.md)
