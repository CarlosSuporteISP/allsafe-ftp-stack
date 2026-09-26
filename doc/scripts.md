# 🧰 Scripts — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [📚 Índice da documentação](README.md)

O que cada script da stack faz, quando rodar e o que esperar. Os da pasta
[`scripts/`](../scripts/) vão para dentro da imagem; [`deploy.sh`](../deploy.sh)
e [`manage-user.sh`](../manage-user.sh) rodam no host.

| Script | Onde roda | Para que serve |
|---|---|---|
| [`deploy.sh`](../deploy.sh) | host | Valida o compose com o perfil escolhido e sobe a stack. |
| [`manage-user.sh`](../manage-user.sh) | host | Atalho para criar, trocar senha, remover e listar usuários FTP. |
| [`scripts/entrypoint.sh`](../scripts/entrypoint.sh) | container | Provisiona usuário inicial e certificado e executa o `pure-ftpd`. |
| [`scripts/ftp-user.sh`](../scripts/ftp-user.sh) | container | Gestão de usuários no PureDB, chamada pelo `manage-user.sh`. |
| [`scripts/validate.sh`](../scripts/validate.sh) | host | Checagem de sintaxe, compose de todos os perfis e, opcionalmente, do container no ar. |

---

<a name="deploy"></a>

## 🚀 `deploy.sh`

```bash
./deploy.sh [--size small|medium|large] [--check-only]
```

| Parâmetro | Efeito |
|---|---|
| `--size` | Carrega `profiles/<perfil>.env` por cima do `.env` (padrão `small`). |
| `--check-only` | Só valida perfil e compose; não sobe nada. |

Na primeira execução sem `.env`, copia o [`.env.example`](../.env.example) e
para, pedindo a revisão. Se `.secrets/ftp_password.txt` estiver vazio, gera uma
senha forte (`0600`). Saída esperada: a tabela do `docker compose ps` com
`allsafe-ftp` em `health: starting` e, segundos depois, `healthy`.

<a name="manage-user"></a>

## 👤 `manage-user.sh`

```bash
./manage-user.sh list                 # lista usuários do PureDB
./manage-user.sh add backup-olt       # pede a senha (mín. 12 caracteres) sem ecoar
./manage-user.sh passwd backup-olt    # troca a senha
./manage-user.sh del backup-olt       # remove o usuário (os arquivos ficam em /data)
```

A senha é lida do terminal e enviada pelo `stdin` para o container: não aparece
na linha de comando nem no histórico. Detalhe em
[`operacao.md`](operacao.md).

<a name="entrypoint"></a>

## 🧩 `scripts/entrypoint.sh`

Roda a cada início do container, como processo 1 (via `init`):

1. lê a senha do arquivo montado em `FTP_PASSWORD_FILE` e cria ou atualiza o
   usuário inicial `FTP_USER` (recusa senha com menos de 12 caracteres);
2. gera um certificado autoassinado para `FTP_CERT_CN` se o volume de
   certificados estiver vazio;
3. executa o `pure-ftpd` com TLS, `chroot`, limites e faixa passiva do `.env`.

Não há parâmetros: tudo vem das variáveis de [`configuracao.md`](configuracao.md).

<a name="ftp-user"></a>

## 🗝️ `scripts/ftp-user.sh`

Instalado na imagem como `/usr/local/sbin/allsafe-ftp-user`. Aceita
`add|passwd|del|list [usuario]`, valida o nome (`^[a-z_][a-z0-9_-]{0,31}$`),
lê a senha do `stdin`, atualiza o `pureftpd.passwd`, regenera o `pureftpd.pdb`
e mantém os dois em `0600`. Não é chamado diretamente pelo operador; use o
[`manage-user.sh`](../manage-user.sh).

<a name="validate"></a>

## ✅ `scripts/validate.sh`

```bash
./scripts/validate.sh            # bash -n + compose config de todos os perfis
./scripts/validate.sh --runtime  # também exige o container running + healthy e o usuário no PureDB
```

Saída esperada: `compose OK com <perfil>.env` para cada perfil e, no fim,
`Validacao FTP concluida.`. Qualquer falha encerra com código diferente de zero.
