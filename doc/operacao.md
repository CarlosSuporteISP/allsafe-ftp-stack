# 🛠️ Operação — allsafe-ftp-stack

Tarefas do dia a dia. Todos os comandos rodam na raiz da stack.

---

## 🧭 Sumário

[👤 Usuários](#-usuários) · [🔏 Certificado real de produção](#-certificado-real-de-produção) · [♻️ Backup dos volumes](#️-backup-dos-volumes) · [📜 Logs](#-logs) · [⬆️ Atualização da imagem](#️-atualização-da-imagem) · [🔍 Inspeção rápida](#-inspeção-rápida) · [⏹️ Parar / remover](#️-parar--remover)

---

## 👤 Usuários

Gestão pelo host com [`manage-user.sh`](../manage-user.sh) (encapsula o
[`scripts/ftp-user.sh`](../scripts/ftp-user.sh) dentro do container):

```bash
./manage-user.sh add cliente01      # cria o usuário e /data/cliente01 (pede a senha)
./manage-user.sh passwd cliente01   # troca a senha (pede a nova)
./manage-user.sh list               # lista os usuários do PureDB
./manage-user.sh del cliente01      # remove o usuário — MANTÉM /data/cliente01
```

Regras:

- Nome do usuário: `^[a-z_][a-z0-9_-]{0,31}$`.
- Senha: mínimo **12 caracteres** (recusada abaixo disso).
- `del` **não apaga arquivos** — remova `/data/<user>` à mão se quiser.
- As mudanças são gravadas em `/auth/pureftpd.passwd` e recompiladas em
  `/auth/pureftpd.pdb` (volume `allsafe-ftp-auth`).

> O usuário definido em `FTP_USER` é recriado/atualizado a cada `up`. Para
> renomeá-lo, crie o novo com `add`, migre os dados e remova o antigo.

---

## 🔏 Certificado real de produção

O certificado inicial é **autoassinado** (gerado na 1ª subida). Para um real:

```bash
# 1. Concatene chave + cadeia completa em um único PEM (chave primeiro)
cat privkey.pem fullchain.pem > pure-ftpd.pem
chmod 600 pure-ftpd.pem

# 2. Copie para o volume, no lugar do autoassinado
docker compose cp pure-ftpd.pem ftp:/etc/ssl/private/pure-ftpd.pem

# 3. Reinicie o serviço
docker compose restart ftp
```

- O arquivo precisa conter **chave + certificado (+ intermediárias)** no mesmo PEM, `0600`.
- O `entrypoint.sh` só gera o autoassinado **se o arquivo não existir** — o seu não será sobrescrito.
- Renovação: repita os passos 1–3 (ex.: via `cron` no host puxando do seu ACME).

---

## ♻️ Backup dos volumes

Volumes a salvar: `allsafe-ftp-data` (arquivos) e `allsafe-ftp-auth` (PureDB).
O `allsafe-ftp-certs` é reconstruível se você tiver o PEM guardado em outro lugar.

```bash
# Backup (tar.gz de cada volume)
for v in allsafe-ftp-data allsafe-ftp-auth; do
  docker run --rm -v "$v":/src:ro -v "$PWD":/dst alpine \
    tar czf "/dst/$v-$(date +%Y%m%d).tar.gz" -C /src .
done

# Restauração (com a stack parada)
docker compose down
docker run --rm -v allsafe-ftp-data:/dst -v "$PWD":/src alpine \
  sh -c 'cd /dst && tar xzf /src/allsafe-ftp-data-AAAAMMDD.tar.gz'
docker compose up -d
```

> Os arquivos de backup gerados aqui **não** entram no repositório — guarde-os
> fora da árvore do projeto.

---

## 📜 Logs

```bash
docker compose logs -f ftp          # segue o log (acesso em formato CLF + mensagens do entrypoint)
docker compose logs --since 1h ftp  # última hora
```

Rotação pelo Docker: `max-size: 10m`, `max-file: 3` (ver [`compose.yaml`](../compose.yaml)).
Para `fail2ban`, aponte o filtro para a saída de `docker logs allsafe-ftp`.

---

## ⬆️ Atualização da imagem

```bash
docker compose build --pull        # rebase na base Debian mais recente
docker compose up -d               # recria o container (volumes preservados)
./scripts/validate.sh --runtime    # confere 'running' + 'healthy'
```

A base no [`Dockerfile`](../Dockerfile) está **pinada por digest** — para pegar
uma base nova, atualize o digest do `FROM` e refaça o build.

---

## 🔍 Inspeção rápida

```bash
docker compose ps                                   # estado e portas
docker inspect --format '{{.State.Health.Status}}' allsafe-ftp
docker compose exec ftp pure-pw list -f /auth/pureftpd.passwd
docker compose exec ftp pure-pw show transfer -f /auth/pureftpd.passwd
```

---

## ⏹️ Parar / remover

```bash
docker compose stop      # para sem remover
docker compose down      # remove container e rede, mantém volumes
docker compose down -v   # remove TAMBÉM os volumes (apaga tudo)
```
