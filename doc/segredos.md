# 🔑 Segredos — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [📚 Índice da documentação](README.md)

## 💡 Em poucas palavras

A senha do usuário inicial do FTP mora em um arquivo só, dentro da pasta `.secrets/`, que nunca vai para o Git nem para dentro da imagem. O script de instalação cria essa senha sozinho na primeira vez. O servidor lê o arquivo ao subir e guarda apenas o hash dela.

<!-- diagrama: diagramas/segredos-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    deploy@{ shape: console, label: "⌨️ deploy.sh<br>gera a senha" }
    arquivo@{ shape: doc, label: "🔑 .secrets/ftp_password.txt<br>0600, fora do Git" }
    montagem@{ shape: rect, label: "🐳 /run/secrets/ftp_password<br>só leitura" }
    entry@{ shape: rect, label: "⚙️ entrypoint<br>lê e apaga da memória" }
    puredb@{ shape: cyl, label: "🗄️ PureDB<br>guarda só o hash" }
    fim@{ shape: stadium, label: "🏁 senha fora da imagem" }

    deploy --> arquivo --> montagem --> entry --> puredb --> fim
```

<sub>📐 Nível 1 · Diagrama · 🔍 aproximar e mover: controles no canto do diagrama · 📁 [fonte](diagramas/)</sub>

**🧭 Sequência:** ⌨️ `deploy.sh` ➜ 🔑 `.secrets/ftp_password.txt` ➜ 🐳 `/run/secrets/ftp_password` (somente leitura) ➜ ⚙️ entrypoint ➜ 🗄️ PureDB (guarda só o hash) ➜ 🏁 senha fora da imagem

---

<details>
<summary>🧭 Sumário — clique para expandir</summary>

[📂 O que fica em `.secrets/`](#o-que-fica) · [🔁 Trocar a senha do usuário inicial](#trocar-a-senha) · [✍️ Usar uma senha própria](#senha-propria) · [🧾 O que mais é sensível](#o-que-mais-e-sensivel)

</details>

---

<a name="o-que-fica"></a>

## 📂 O que fica em `.secrets/`

| Arquivo | Quem gera | Você preenche? | Para quê |
|---|---|---|---|
| `ftp_password.txt` | [`deploy.sh`](../deploy.sh), na primeira execução, se o arquivo não existir ou estiver vazio | Só se quiser uma senha própria | Senha do usuário inicial (`FTP_USER`) |
| `.gitkeep` | já vem no repositório | Não | Mantém a pasta no clone |

Ver a senha gerada, para configurar o equipamento:

```bash
cat .secrets/ftp_password.txt
```

**Resultado esperado:** uma linha com a senha, de cerca de 48 caracteres.

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

A senha do usuário inicial é **reaplicada a cada subida** a partir deste arquivo. Trocar com `./manage-user.sh passwd` sem atualizar o arquivo faz a senha antiga voltar no próximo reinício. Para os demais usuários, a troca é só pelo `manage-user.sh`: veja [🧰 Operação](operacao.md#usuarios).

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
| Chave privada TLS | pasta `DATA_DIR/certs`, arquivo `pure-ftpd.pem` | `0600`, fora do repositório |
| Hash das senhas dos usuários | pasta `DATA_DIR/auth`, arquivos `pureftpd.passwd` e `pureftpd.pdb` | `0600`, fora do repositório |
| Arquivos de backup dos volumes | onde você os guardar | fora da árvore do projeto |

<details>
<summary>🔬 Detalhe técnico — geração, montagem e descarte</summary>

- **Geração:** `openssl rand -base64 36` (48 caracteres). O script aplica `umask 077`, `chmod 0700` na pasta e `chmod 0600` no arquivo, e nunca regrava um segredo que já existe.
- **Montagem:** o [`compose.yaml`](../compose.yaml) declara o segredo `ftp_password` (`SECRETS_DIR/ftp_password.txt`) e o entrega **só** ao serviço `ftp`, em `/run/secrets/ftp_password`, somente leitura. A pasta `.secrets/` inteira não é montada.
- **Sem senha em variável:** o `.env` guarda só o que se ajusta. O `deploy.sh` recusa `FTP_PASSWORD` no `.env` e o container recusa a variável.
- **Leitura:** o [`entrypoint.sh`](../scripts/entrypoint.sh) lê o arquivo sem as quebras de linha, valida o mínimo de 12 caracteres e entrega a senha ao `pure-pw` pelo `stdin`.
- **Descarte:** antes do `exec` do `pure-ftpd`, o entrypoint faz `unset` da variável interna da senha.
- **Git:** o [`.gitignore`](../.gitignore) ignora `.env` e `.secrets/*.txt`, mantendo só o `.gitkeep`.
- **Imagem:** o [`.dockerignore`](../.dockerignore) deixa `.env` e `.secrets` fora do contexto de build.

</details>

---

⬅️ [🔐 Segurança](seguranca.md) · 🏠 [Documentação](README.md) · ➡️ [⌨️ Scripts](scripts.md)
