# 🔑 Segredos — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [Índice da documentação](README.md)

## 💡 Em poucas palavras

As senhas da stack moram na pasta `.secrets/`, que nunca vai para o Git nem para dentro da imagem. São duas: a do usuário inicial do FTP e a do painel web. O script de instalação cria as duas sozinho na primeira vez, cada uma em um arquivo cujo nome diz o que ele guarda, e deixa na pasta um `LEIAME.txt` que explica um por um. O servidor FTP lê a dele ao subir e guarda apenas o hash; o painel recebe **só o hash** da dele, nunca a senha.

<!-- diagrama: diagramas/segredos-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    deploy@{ shape: console, label: "deploy.sh<br>gera a senha" }
    arquivo@{ shape: doc, label: ".secrets/ftp-usuario-inicial-senha.txt<br>0600, fora do Git" }
    montagem@{ shape: rect, label: "/run/secrets/ftp_usuario_inicial_senha<br>só leitura" }
    entry@{ shape: rect, label: "entrypoint<br>lê e apaga da memória" }
    puredb@{ shape: cyl, label: "PureDB<br>guarda só o hash" }
    fim@{ shape: stadium, label: "senha fora da imagem" }

    deploy --> arquivo --> montagem --> entry --> puredb --> fim
```

<sub>Nível 1 · Diagrama · [fonte](diagramas/)</sub>

**Sequência:** `deploy.sh` ➜ `.secrets/ftp-usuario-inicial-senha.txt` ➜ `/run/secrets/ftp_usuario_inicial_senha` (somente leitura) ➜ entrypoint ➜ PureDB (guarda só o hash) ➜ senha fora da imagem

---

<details>
<summary>Sumário — clique para expandir</summary>

[O que fica em `.secrets/`](#o-que-fica) · [Trocar a senha do usuário inicial](#trocar-a-senha) · [Senha do painel](#senha-do-painel) · [Usar uma senha própria](#senha-propria) · [Instalação com os nomes antigos](#nomes-antigos) · [O que mais é sensível](#o-que-mais-e-sensivel)

</details>

---

<a name="o-que-fica"></a>

## 📂 O que fica em `.secrets/`

| Arquivo | Quem gera | Você preenche? | Para quê |
|---|---|---|---|
| `ftp-usuario-inicial-senha.txt` | [`deploy.sh`](../deploy.sh), na primeira execução, se o arquivo não existir ou estiver vazio | Só se quiser uma senha própria | Senha do usuário inicial (`FTP_USER`) |
| `painel-admin-inicial-senha.txt` | [`deploy.sh`](../deploy.sh), na primeira execução | Não | Senha **inicial** do primeiro administrador do painel (`PAINEL_ADMIN_USER`), em texto. Fica só no host e vale até ser trocada na aba Administradores; trocou, apague o arquivo |
| `painel-admin-inicial-senha-hash.txt` | [`deploy.sh`](../deploy.sh) e [`scripts/painel-senha.sh`](../scripts/painel-senha.sh) | Não | Hash `scrypt` dessa senha inicial. É o único arquivo da pasta que o painel enxerga, e só é usado para criar o primeiro administrador |
| `LEIAME.txt` | [`deploy.sh`](../deploy.sh), a cada execução | Não | Diz para que serve cada arquivo da pasta. Não guarda segredo nenhum |
| `.gitkeep` | já vem no repositório | Não | Mantém a pasta no clone |

O nome de cada arquivo segue a mesma ordem: **de quem é** a senha (`ftp-usuario-inicial`, `painel-admin-inicial`) e **o que** está gravado (`senha` em texto ou `senha-hash`).

Ver as senhas geradas, para configurar o equipamento e para entrar no painel pela primeira vez:

```bash
cat .secrets/ftp-usuario-inicial-senha.txt       # usuário inicial do FTP
cat .secrets/painel-admin-inicial-senha.txt    # primeiro administrador do painel, até a primeira troca
```

**Resultado esperado:** em cada comando, uma linha com a senha, de 48 caracteres.

> ⚠️ Nunca cole a senha em documento, captura de tela, resultado de teste ou mensagem. Onde for preciso mostrar o formato, use `<REDACTED>`.

---

<a name="trocar-a-senha"></a>

## 🔁 Trocar a senha do usuário inicial

Há dois caminhos, e vale sempre a troca mais recente.

| Caminho | Como | Até quando vale |
|---|---|---|
| Pelo painel ou pelo terminal | Usuários ➜ **Trocar senha**, ou `./manage-user.sh passwd <usuario>` | Até o arquivo do segredo ser alterado |
| Pelo arquivo do segredo | Os três comandos abaixo | Até a próxima troca, por qualquer caminho |

```bash
printf '%s' 'nova-senha-de-12-ou-mais' > .secrets/ftp-usuario-inicial-senha.txt
chmod 600 .secrets/ftp-usuario-inicial-senha.txt
docker compose restart ftp
```

**Resultado esperado:** o container volta a `healthy` e o login antigo passa a ser recusado com `530 Login authentication failed`.

O usuário inicial é criado uma vez. Removido pelo painel ou com `./manage-user.sh del`, ele não volta nas subidas seguintes e o arquivo do segredo fica sem uso; criado de novo com o mesmo nome, vale a senha informada na criação, até o arquivo ser alterado.

A senha trocada pelo painel ou pelo `manage-user.sh passwd` sobrevive aos reinícios: o serviço `ftp` só aplica a do arquivo de novo quando o **conteúdo do arquivo muda**. Enquanto isso, o arquivo guarda a senha anterior, sem uso, e o resumo do `./deploy.sh` diz `senha trocada pelo painel`. Para os demais usuários, a troca é pelo painel ou pelo `manage-user.sh`: veja [Operação](operacao.md#usuarios).

---

<a name="senha-do-painel"></a>

## 🖥️ Senha do painel

Cada administrador do painel tem usuário e senha próprios. O primeiro nasce na instalação, com o nome de `PAINEL_ADMIN_USER` e a senha de `.secrets/painel-admin-inicial-senha.txt`. Troque essa senha logo depois do primeiro acesso, **pelo painel**, na aba Administradores, e apague o arquivo da senha inicial: [Administradores do painel](painel.md#administradores).

Sem acesso ao painel, a senha é definida pelo host:

```bash
./scripts/painel-senha.sh --gerar                    # senha forte para o primeiro administrador, mostrada uma única vez
./scripts/painel-senha.sh                            # ou: pergunta a senha nova duas vezes, sem mostrar na tela
./scripts/painel-senha.sh --usuario NOME --gerar     # outro administrador; se NOME não existe, é criado
```

**Resultado esperado:** `Administrador admin com a senha trocada; painel reiniciado e sessões abertas encerradas.` Quando o administrador é o de `PAINEL_ADMIN_USER`, o arquivo `painel-admin-inicial-senha.txt` deixa de existir.

A senha tem de ter no mínimo 12 caracteres e **não fica gravada em lugar nenhum**: o painel guarda só o hash, em `DATA_DIR/painel/administradores`. Guarde-a no seu cofre de senhas. Uso do painel: [Painel web](painel.md).

---

<a name="senha-propria"></a>

## ✍️ Usar uma senha própria

Grave-a **antes** do primeiro deploy, com no mínimo 12 caracteres:

```bash
printf '%s' 'uma-senha-forte-de-12+-caracteres' > .secrets/ftp-usuario-inicial-senha.txt
chmod 600 .secrets/ftp-usuario-inicial-senha.txt
```

**Resultado esperado:** o `deploy.sh` não gera senha nova e não mostra a mensagem `Gerada uma senha forte em ...`.

---

<a name="nomes-antigos"></a>

## 🔀 Instalação com os nomes antigos

Até a versão `0.9.0` os arquivos tinham outros nomes. O `./deploy.sh` reconhece os antigos e **só troca o nome**, sem ler, copiar nem alterar o conteúdo: as senhas continuam as mesmas.

| Nome até a `0.9.0` | Nome a partir da `0.10.0` |
|---|---|
| `ftp_password.txt` | `ftp-usuario-inicial-senha.txt` |
| `painel_password.txt` | `painel-admin-inicial-senha.txt` |
| `painel_password_hash.txt` | `painel-admin-inicial-senha-hash.txt` |

```bash
./deploy.sh
```

**Resultado esperado:** uma linha `Convertido: <nome antigo> virou <nome novo>.` para cada arquivo que existia, e os três containers `healthy` no fim. Vindo da `0.9.0`, os containers do FTP e do painel são recriados uma vez, porque o nome do segredo dentro deles também mudou, e o do nginx continua o mesmo; vindo de versão anterior, os três são recriados, porque as imagens mudam. Dados, usuários e senhas ficam como estavam.

Com `./deploy.sh --check-only` nada é alterado: sai só o aviso `AVISO: esta instalação usa nomes antigos`. Se o arquivo antigo e o novo existirem ao mesmo tempo, vale o novo e o script avisa para conferir e apagar o antigo.

---

<a name="o-que-mais-e-sensivel"></a>

## 🧾 O que mais é sensível

| Item | Onde fica | Proteção |
|---|---|---|
| `.env` | raiz da stack | `0600`, ignorado pelo Git e pelo build |
| Chave privada TLS do FTP | pasta `DATA_DIR/certs`, arquivo `pure-ftpd.pem` | `0600`, fora do repositório |
| Chave privada TLS do painel | pasta `DATA_DIR/painel/tls`, arquivo `painel-key.pem` | `0600`, pasta `0700`, fora do repositório |
| Cópia da chave TLS do painel, para o nginx | pasta `DATA_DIR/nginx/tls`, arquivo `painel-key.pem` | `0640`, grupo `10001` (o do nginx), pasta `0750`; refeita a cada subida e montada no nginx só para leitura |
| Registro de auditoria do painel | pasta `DATA_DIR/painel`, arquivo `auditoria.log` | `0600`; não guarda senha, mas mostra nomes de usuário e endereços |
| Hash das senhas dos usuários | pasta `DATA_DIR/auth`, arquivos `pureftpd.passwd` e `pureftpd.pdb` | `0600`, fora do repositório |
| Cópias de segurança feitas pelo `scripts/backup.sh` | pasta `BACKUP_DIR` | `0600`, pasta `0700`, fora do repositório; contêm o hash das senhas e as chaves privadas dos certificados |

<details>
<summary>Detalhe técnico — geração, montagem e descarte</summary>

- **Geração:** `openssl rand -base64 36` (48 caracteres). O script aplica `umask 077`, `chmod 0700` na pasta e `chmod 0600` no arquivo, e nunca regrava um segredo que já existe.
- **Montagem:** o [`compose.yaml`](../compose.yaml) declara o segredo `ftp_usuario_inicial_senha` (`SECRETS_DIR/ftp-usuario-inicial-senha.txt`) e o entrega **só** ao serviço `ftp`, em `/run/secrets/ftp_usuario_inicial_senha`, somente leitura. A pasta `.secrets/` inteira não é montada.
- **Sem senha em variável:** o `.env` guarda só o que se ajusta. O `deploy.sh` recusa `FTP_PASSWORD`, `PAINEL_PASSWORD` e `PAINEL_PASSWORD_HASH` no `.env` e os containers recusam essas variáveis.
- **Leitura:** o [`ftp/entrypoint.sh`](../ftp/entrypoint.sh) lê o arquivo sem as quebras de linha, valida o mínimo de 12 caracteres e entrega a senha ao `pure-pw` pelo `stdin`. Na primeira subida ele cria o usuário (`pure-pw useradd`); nas seguintes, regrava a senha (`pure-pw passwd`), porque o `pure-pw usermod` não altera senha. Nos dois casos passa `-C FTP_MAX_CLIENTS`, que define o custo do hash `argon2id`: [Segurança](seguranca.md#custo-das-senhas).
- **Troca pelo painel:** a cada vez que aplica o segredo, o entrypoint grava em `/auth/senha-inicial.aplicada` uma impressão dele (`sha512-crypt` com sal próprio, `0600`), nunca a senha. A troca pelo painel ou pelo `manage-user.sh passwd` grava `/auth/senha-inicial.trocada`, só com o nome do usuário. Na subida, com a marca presente e a impressão igual à do segredo, a senha do cadastro é mantida e o log diz `mantida a senha trocada pelo painel`; com o segredo diferente, ele é aplicado e a marca sai. Os dois arquivos entram no backup, com o cadastro.
- **Criado uma vez:** ao criar o usuário inicial, o entrypoint grava `/auth/usuario-inicial.criado` (`0600`), só com o nome dele. Com a marca presente e o usuário fora do cadastro, ele não é recriado, e o log diz `removido pelo administrador; não é recriado`. Instalação anterior à `0.23.0` ganha a marca na primeira subida, com o usuário que já existe. A marca entra no backup, com o cadastro.
- **Descarte:** antes do `exec` do `pure-ftpd`, o entrypoint faz `unset` da variável interna da senha.
- **Painel:** o hash é `scrypt` (N=2^15, r=8, p=1, sal aleatório de 16 bytes), calculado dentro da imagem do painel, em um container descartável sem rede. O segredo `painel_admin_inicial_senha_hash` chega **só** ao serviço `painel`, em `/run/secrets/painel_admin_inicial_senha_hash`, somente leitura, e só é lido na subida em que ainda não existe nenhum administrador. A senha atual de cada administrador fica como hash em `DATA_DIR/painel/administradores` (`0600`, do `root`), fora de `.secrets/`. O `painel-admin-inicial-senha.txt` nunca é montado em container.
- **Git:** o [`.gitignore`](../.gitignore) ignora `.env` e tudo o que está em `.secrets/`, mantendo só o `.gitkeep`.
- **`LEIAME.txt`:** regravado pelo `deploy.sh` a cada execução, com modo `0600`. Traz só o nome e a função de cada arquivo; nunca é montado em container.
- **Imagem:** o [`.dockerignore`](../.dockerignore) deixa `.env` e `.secrets` fora do contexto de build.

</details>

---

⬅️ [Segurança](seguranca.md) · 🏠 [Documentação](README.md) · ➡️ [Scripts](scripts.md)
