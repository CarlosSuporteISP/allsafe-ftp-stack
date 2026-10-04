# 🔑 Segredos — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [Índice da documentação](README.md)

## 💡 Em poucas palavras

As senhas da stack moram na pasta `.secrets/`, que nunca vai para o Git nem para dentro da imagem. São duas: a do usuário inicial do FTP e a do painel web. O script de instalação cria as duas sozinho na primeira vez. O servidor FTP lê a dele ao subir e guarda apenas o hash; o painel recebe **só o hash** da dele, nunca a senha.

<!-- diagrama: diagramas/segredos-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    deploy@{ shape: console, label: "deploy.sh<br>gera a senha" }
    arquivo@{ shape: doc, label: ".secrets/ftp_password.txt<br>0600, fora do Git" }
    montagem@{ shape: rect, label: "/run/secrets/ftp_password<br>só leitura" }
    entry@{ shape: rect, label: "entrypoint<br>lê e apaga da memória" }
    puredb@{ shape: cyl, label: "PureDB<br>guarda só o hash" }
    fim@{ shape: stadium, label: "senha fora da imagem" }

    deploy --> arquivo --> montagem --> entry --> puredb --> fim
```

<sub>Nível 1 · Diagrama · [fonte](diagramas/)</sub>

**Sequência:** `deploy.sh` ➜ `.secrets/ftp_password.txt` ➜ `/run/secrets/ftp_password` (somente leitura) ➜ entrypoint ➜ PureDB (guarda só o hash) ➜ senha fora da imagem

---

<details>
<summary>Sumário — clique para expandir</summary>

[O que fica em `.secrets/`](#o-que-fica) · [Trocar a senha do usuário inicial](#trocar-a-senha) · [Senha do painel](#senha-do-painel) · [Usar uma senha própria](#senha-propria) · [O que mais é sensível](#o-que-mais-e-sensivel)

</details>

---

<a name="o-que-fica"></a>

## 📂 O que fica em `.secrets/`

| Arquivo | Quem gera | Você preenche? | Para quê |
|---|---|---|---|
| `ftp_password.txt` | [`deploy.sh`](../deploy.sh), na primeira execução, se o arquivo não existir ou estiver vazio | Só se quiser uma senha própria | Senha do usuário inicial (`FTP_USER`) |
| `painel_password.txt` | [`deploy.sh`](../deploy.sh), na primeira execução | Não | Senha **inicial** do painel, em texto. Fica só no host e é apagada na primeira troca |
| `painel_password_hash.txt` | [`deploy.sh`](../deploy.sh) e [`scripts/painel-senha.sh`](../scripts/painel-senha.sh) | Não | Hash `scrypt` da senha do painel. É o único arquivo que o painel enxerga |
| `.gitkeep` | já vem no repositório | Não | Mantém a pasta no clone |

Ver as senhas geradas, para configurar o equipamento e para entrar no painel pela primeira vez:

```bash
cat .secrets/ftp_password.txt       # usuário inicial do FTP
cat .secrets/painel_password.txt    # painel, até a primeira troca
```

**Resultado esperado:** em cada comando, uma linha com a senha, de 48 caracteres.

> ⚠️ Nunca cole a senha em documento, captura de tela, resultado de teste ou mensagem. Onde for preciso mostrar o formato, use `<REDACTED>`.

---

<a name="trocar-a-senha"></a>

## 🔁 Trocar a senha do usuário inicial

```bash
printf '%s' 'nova-senha-de-12-ou-mais' > .secrets/ftp_password.txt
chmod 600 .secrets/ftp_password.txt
docker compose restart ftp
```

**Resultado esperado:** o container volta a `healthy` e o login antigo passa a ser recusado com `530 Login authentication failed`.

A senha do usuário inicial é **reaplicada a cada subida** a partir deste arquivo. Trocar com `./manage-user.sh passwd` sem atualizar o arquivo faz a senha antiga voltar no próximo reinício. Para os demais usuários, a troca é só pelo `manage-user.sh`: veja [Operação](operacao.md#usuarios).

---

<a name="senha-do-painel"></a>

## 🖥️ Senha do painel

O painel tem uma senha só, de administrador. Troque a senha inicial logo depois do primeiro acesso:

```bash
./scripts/painel-senha.sh            # pergunta a senha nova duas vezes, sem mostrar na tela
./scripts/painel-senha.sh --gerar    # ou: cria uma senha forte e mostra uma única vez
```

**Resultado esperado:** `Hash gravado em ./.secrets/painel_password_hash.txt; painel reiniciado e sessões abertas encerradas.` O arquivo `painel_password.txt` deixa de existir.

A senha nova tem de ter no mínimo 12 caracteres e **não fica gravada em lugar nenhum**: guarde-a no seu cofre de senhas. Se for perdida, rode o mesmo script de novo. Uso do painel: [Painel web](painel.md).

---

<a name="senha-propria"></a>

## ✍️ Usar uma senha própria

Grave-a **antes** do primeiro deploy, com no mínimo 12 caracteres:

```bash
printf '%s' 'uma-senha-forte-de-12+-caracteres' > .secrets/ftp_password.txt
chmod 600 .secrets/ftp_password.txt
```

**Resultado esperado:** o `deploy.sh` não gera senha nova e não mostra a mensagem `Gerada uma senha forte em ...`.

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
- **Montagem:** o [`compose.yaml`](../compose.yaml) declara o segredo `ftp_password` (`SECRETS_DIR/ftp_password.txt`) e o entrega **só** ao serviço `ftp`, em `/run/secrets/ftp_password`, somente leitura. A pasta `.secrets/` inteira não é montada.
- **Sem senha em variável:** o `.env` guarda só o que se ajusta. O `deploy.sh` recusa `FTP_PASSWORD`, `PAINEL_PASSWORD` e `PAINEL_PASSWORD_HASH` no `.env` e os containers recusam essas variáveis.
- **Leitura:** o [`entrypoint.sh`](../scripts/entrypoint.sh) lê o arquivo sem as quebras de linha, valida o mínimo de 12 caracteres e entrega a senha ao `pure-pw` pelo `stdin`.
- **Descarte:** antes do `exec` do `pure-ftpd`, o entrypoint faz `unset` da variável interna da senha.
- **Painel:** o hash é `scrypt` (N=2^15, r=8, p=1, sal aleatório de 16 bytes), calculado dentro da imagem do painel, em um container descartável sem rede. O segredo `painel_password_hash` chega **só** ao serviço `painel`, em `/run/secrets/painel_password_hash`, somente leitura, e é lido a cada tentativa de entrada. O `painel_password.txt` nunca é montado em container.
- **Git:** o [`.gitignore`](../.gitignore) ignora `.env` e `.secrets/*.txt`, mantendo só o `.gitkeep`.
- **Imagem:** o [`.dockerignore`](../.dockerignore) deixa `.env` e `.secrets` fora do contexto de build.

</details>

---

⬅️ [Segurança](seguranca.md) · 🏠 [Documentação](README.md) · ➡️ [Scripts](scripts.md)
