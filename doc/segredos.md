# 🔑 Segredos — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [📚 Índice da documentação](README.md)

## 💡 Em poucas palavras

A senha do usuário inicial do FTP mora em um arquivo só, dentro da pasta `.secrets/`, que nunca vai para o Git nem para dentro da imagem. O script de instalação cria essa senha sozinho na primeira vez. O servidor lê o arquivo ao subir e guarda apenas o hash dela.

<a href="diagramas/segredos-diagrama.mmd"><picture>
  <source media="(prefers-color-scheme: dark)" srcset="diagramas/segredos-diagrama-escuro.svg">
  <img src="diagramas/segredos-diagrama.svg" alt="Caminho da senha: o deploy.sh gera o arquivo em .secrets, o container o monta somente leitura, o entrypoint lê e o PureDB guarda só o hash" width="100%">
</picture></a>

<sub>📐 Nível 1 · Diagrama · 🔍 abrir com zoom e movimento: [no GitHub](diagramas/segredos-diagrama.mmd) · [no computador](diagramas/visualizador.html#segredos-diagrama)</sub>

**🧭 Sequência:** ⌨️ `deploy.sh` ➜ 🔑 `.secrets/ftp_password.txt` ➜ 🐳 `/run/.secrets` (somente leitura) ➜ ⚙️ entrypoint ➜ 🗄️ PureDB (guarda só o hash) ➜ 🏁 senha fora da imagem

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
| Chave privada TLS | volume `allsafe-ftp-certs`, arquivo `pure-ftpd.pem` | `0600`, fora do repositório |
| Hash das senhas dos usuários | volume `allsafe-ftp-auth`, arquivos `pureftpd.passwd` e `pureftpd.pdb` | `0600`, fora do repositório |
| Arquivos de backup dos volumes | onde você os guardar | fora da árvore do projeto |

<details>
<summary>🔬 Detalhe técnico — geração, montagem e descarte</summary>

- **Geração:** `openssl rand -base64 36` (48 caracteres); sem `openssl` no host, 48 caracteres de `/dev/urandom` no alfabeto `A-Za-z0-9_-`. O script aplica `umask 077` e `chmod 0600`.
- **Montagem:** o [`compose.yaml`](../compose.yaml) monta `./.secrets` em `/run/.secrets` como somente leitura; a variável `FTP_PASSWORD_FILE` aponta para `/run/.secrets/ftp_password.txt`.
- **Leitura:** o [`entrypoint.sh`](../scripts/entrypoint.sh) lê o arquivo sem as quebras de linha, valida o mínimo de 12 caracteres e entrega a senha ao `pure-pw` pelo `stdin`.
- **Descarte:** antes do `exec` do `pure-ftpd`, o entrypoint faz `unset` das variáveis de senha.
- **Git:** o [`.gitignore`](../.gitignore) ignora `.env` e `.secrets/*.txt`, mantendo só o `.gitkeep`.
- **Imagem:** o [`.dockerignore`](../.dockerignore) deixa `.env` e `.secrets` fora do contexto de build.

</details>

---

⬅️ [🔐 Segurança](seguranca.md) · 🏠 [Documentação](README.md) · ➡️ [⌨️ Scripts](scripts.md)
