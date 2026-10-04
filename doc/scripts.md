# ⌨️ Scripts — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [📚 Índice da documentação](README.md)

## 💡 Em poucas palavras

A stack tem cinco scripts. Três você roda no host: um sobe o servidor, outro cuida dos usuários e o terceiro confere se está tudo certo. Os outros dois ficam dentro do container e são chamados pelos primeiros; você não os executa direto.

<a href="diagramas/scripts-diagrama.mmd"><picture>
  <source media="(prefers-color-scheme: dark)" srcset="diagramas/scripts-diagrama-escuro.svg">
  <img src="diagramas/scripts-diagrama.svg" alt="Scripts: o usuário roda os scripts do host, que chamam o Docker Compose, que aciona o entrypoint e o allsafe-ftp-user dentro do container" width="100%">
</picture></a>

<sub>📐 Nível 1 · Diagrama · 🔍 abrir com zoom e movimento: [no GitHub](diagramas/scripts-diagrama.mmd) · [no computador](diagramas/visualizador.html#scripts-diagrama)</sub>

**🧭 Sequência:** 👤 Usuário ➜ ⌨️ scripts do host (`deploy.sh`, `manage-user.sh`, `validate.sh`) ➜ 🐳 Docker Compose ➜ ⌨️ entrypoint e `allsafe-ftp-user` ➜ ⚙️ Pure-FTPd (`allsafe-ftp`) ➜ 🏁 serviço operando

---

<details>
<summary>🧭 Sumário — clique para expandir</summary>

[📋 Visão geral](#visao-geral) · [🚀 `deploy.sh`](#deploy) · [👤 `manage-user.sh`](#manage-user) · [🧪 `scripts/validate.sh`](#validate) · [⚙️ `scripts/entrypoint.sh`](#entrypoint) · [👥 `scripts/ftp-user.sh`](#ftp-user)

</details>

---

<a name="visao-geral"></a>

## 📋 Visão geral

| Script | Onde roda | Para que serve |
|---|---|---|
| [`deploy.sh`](../deploy.sh) | host | Valida o Compose com o perfil escolhido e sobe a stack |
| [`manage-user.sh`](../manage-user.sh) | host | Atalho para criar, trocar senha, remover e listar usuários FTP |
| [`scripts/validate.sh`](../scripts/validate.sh) | host | Checagem de sintaxe, do Compose de todos os perfis e, opcionalmente, do container no ar |
| [`scripts/entrypoint.sh`](../scripts/entrypoint.sh) | container | Provisiona o usuário inicial e o certificado e executa o `pure-ftpd` |
| [`scripts/ftp-user.sh`](../scripts/ftp-user.sh) | container | Gestão de usuários no PureDB, chamada pelo `manage-user.sh` |

Os dois da pasta [`scripts/`](../scripts/) que rodam no container são copiados para a imagem pelo [`Dockerfile`](../Dockerfile).

---

<a name="deploy"></a>

## 🚀 `deploy.sh`

```bash
./deploy.sh [--size small|medium|large] [--check-only]
```

| Parâmetro | Efeito |
|---|---|
| `--size` | Carrega `profiles/<perfil>.env` por cima do `.env` (padrão `small`) |
| `--check-only` | Só valida perfil e Compose; não sobe nada |
| `-h`, `--help` | Mostra o uso |

**Resultado esperado:** a tabela do `docker compose ps` com `allsafe-ftp` em `health: starting` e, segundos depois, `healthy`. Com `--check-only`: `OK: perfil '<perfil>' e compose validados; nada foi alterado.`

<details>
<summary>🔬 Detalhe técnico — comportamento e códigos de saída</summary>

- Na primeira execução sem `.env`, copia o [`.env.example`](../.env.example), aplica `0600`, mostra `Edite <pasta>/.env e execute novamente.` e sai com código `1`.
- Se `.secrets/ftp_password.txt` estiver vazio ou ausente, gera uma senha forte (`0600`): veja [🔑 Segredos](segredos.md).
- Opção desconhecida ou perfil inexistente: mensagem `Opção inválida: ...` ou `ERRO: perfil inexistente: ...` e código `64`.
- O Compose é sempre chamado com `--env-file .env --env-file profiles/<perfil>.env`; o perfil vence o `.env`.
- Sobe com `docker compose up -d --build` e termina mostrando o `docker compose ps`. Não espera o `healthy`.

</details>

---

<a name="manage-user"></a>

## 👤 `manage-user.sh`

```bash
./manage-user.sh list                 # lista os usuários do PureDB
./manage-user.sh add backup-olt       # pede a senha (mínimo de 12 caracteres) sem ecoar
./manage-user.sh passwd backup-olt    # troca a senha
./manage-user.sh del backup-olt       # remove o usuário (os arquivos ficam em /data)
```

**Resultado esperado:** `add` e `passwd` terminam sem erro e o usuário aparece no `list`; `del` responde `Usuario removido; os dados em /data/<usuario> foram preservados.`

A senha é lida do terminal e enviada pelo `stdin` para o container: não aparece na linha de comando nem no histórico. Regras e casos de uso em [🧰 Operação](operacao.md#usuarios).

---

<a name="validate"></a>

## 🧪 `scripts/validate.sh`

```bash
./scripts/validate.sh            # bash -n dos scripts e compose config de todos os perfis
./scripts/validate.sh --runtime  # também exige o container running e healthy e o usuário no PureDB
```

**Resultado esperado:** `compose OK com <perfil>.env` para cada perfil e, no fim, `Validacao FTP concluida.` Qualquer falha encerra com código diferente de zero.

<details>
<summary>🔬 Detalhe técnico — o que cada modo confere</summary>

| Modo | Confere |
|---|---|
| sem parâmetro | `bash -n` em `deploy.sh`, `manage-user.sh` e `scripts/*.sh`; `docker compose config --quiet` com `.env.example` e cada arquivo de `profiles/` |
| `--runtime` | tudo acima, mais: serviço `ftp` em `running`, saúde `healthy` e `pure-pw show` do usuário inicial |

> ⚠️ No modo `--runtime`, o usuário conferido vem da variável `FTP_USER` **do shell**, com padrão `transfer`; o script não lê o `.env`. Se o seu usuário inicial tem outro nome, rode `FTP_USER=<usuario> ./scripts/validate.sh --runtime`.

</details>

---

<a name="entrypoint"></a>

## ⚙️ `scripts/entrypoint.sh`

Roda a cada início do container. Não tem parâmetros: tudo vem das variáveis de [⚙️ Configuração](configuracao.md).

1. Lê a senha do arquivo montado em `FTP_PASSWORD_FILE` e cria ou atualiza o usuário inicial `FTP_USER` (recusa senha com menos de 12 caracteres).
2. Gera um certificado autoassinado para `FTP_CERT_CN` se o volume de certificados estiver vazio.
3. Executa o `pure-ftpd` com TLS, `chroot`, limites e faixa passiva do `.env`.

**Resultado esperado:** a linha `FTP pronto em 2121/tcp; TLS=2; passivo=30000-30049` no log do container.

<details>
<summary>🔬 Detalhe técnico — processo 1 e mensagens de falha</summary>

Com `init: true`, o processo 1 do container é o `tini`; o entrypoint é iniciado por ele e termina com `exec`, deixando o `pure-ftpd` no seu lugar.

Quando uma validação falha, o script sai com `FALHA: <motivo>`:

| Mensagem | Quando |
|---|---|
| `FALHA: FTP_PASSWORD_FILE nao pode ser lido` | o arquivo apontado não existe ou não pode ser lido |
| `FALHA: FTP_USER invalido` | o nome não segue `^[a-z_][a-z0-9_-]{0,31}$` |
| `FALHA: a senha FTP deve ter pelo menos 12 caracteres` | senha curta ou arquivo vazio |
| `FALHA: faixa passiva invalida` | início ou fim não numéricos |
| `FALHA: faixa passiva fora dos limites` | abaixo de `1024`, acima de `65535` ou invertida |
| `FALHA: FTP_TLS_MODE deve ser 1, 2 ou 3` | valor fora da lista |

A correção de cada uma está em [🚨 Solução de problemas](solucao-de-problemas.md#o-container-nao-sobe). O modelo completo da subida está em [🏗️ Arquitetura](arquitetura.md#subida).

</details>

---

<a name="ftp-user"></a>

## 👥 `scripts/ftp-user.sh`

Instalado na imagem como `/usr/local/sbin/allsafe-ftp-user`. Não é chamado diretamente: use o [`manage-user.sh`](../manage-user.sh).

<details>
<summary>🔬 Detalhe técnico — o que ele faz dentro do container</summary>

- Aceita `add|passwd|del|list [usuario]` e valida o nome (`^[a-z_][a-z0-9_-]{0,31}$`).
- Lê a senha do `stdin` e recusa menos de 12 caracteres com `Senha deve ter pelo menos 12 caracteres`.
- `add` cria `/data/<usuario>` com dono `ftpdata` e modo `0750` e registra o usuário com `pure-pw useradd`.
- `passwd` usa `pure-pw passwd`; `del` usa `pure-pw userdel` e **não** apaga a pasta.
- Depois de cada mudança, regenera o `pureftpd.pdb` com `pure-pw mkdb` e mantém os dois arquivos em `0600`.
- Uso inválido: mostra `Uso: ... add|passwd|del|list [usuario]` e sai com código `2`.

</details>

---

⬅️ [🔑 Segredos](segredos.md) · 🏠 [Documentação](README.md) · ➡️ [🧰 Operação](operacao.md)
