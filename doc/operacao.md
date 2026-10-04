# 🧰 Operação — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [📚 Índice da documentação](README.md)

## 💡 Em poucas palavras

Este guia reúne as tarefas do dia a dia: criar a conta de um equipamento novo, trocar uma senha, instalar o certificado definitivo, guardar uma cópia dos arquivos, ler os registros e atualizar o servidor. Todos os comandos rodam na pasta raiz da stack.

<a href="diagramas/usuarios-diagrama.mmd"><picture>
  <source media="(prefers-color-scheme: dark)" srcset="diagramas/usuarios-diagrama-escuro.svg">
  <img src="diagramas/usuarios-diagrama.svg" alt="Gestão de usuários: o usuário roda o manage-user.sh, que chama o allsafe-ftp-user no container, grava a conta no PureDB e cria a pasta em /data" width="100%">
</picture></a>

<sub>📐 Nível 1 · Diagrama · 🔍 abrir com zoom e movimento: [no GitHub](diagramas/usuarios-diagrama.mmd) · [no computador](diagramas/visualizador.html#usuarios-diagrama)</sub>

**🧭 Sequência:** 👤 Usuário ➜ ⌨️ `manage-user.sh` ➜ ⌨️ `allsafe-ftp-user` ➜ 🗄️ PureDB ➜ 💽 `/data` ➜ 🏁 conta pronta

---

<details>
<summary>🧭 Sumário — clique para expandir</summary>

[👤 Usuários](#usuarios) · [🔏 Certificado real de produção](#certificado-real-de-producao) · [♻️ Backup dos volumes](#backup-dos-volumes) · [📜 Logs](#logs) · [⬆️ Atualização da imagem](#atualizacao-da-imagem) · [🔍 Inspeção rápida](#inspecao-rapida) · [⏹️ Parar e remover](#parar-remover)

</details>

---

<a name="usuarios"></a>

## 👤 Usuários

Gestão pelo host com [`manage-user.sh`](../manage-user.sh):

```bash
./manage-user.sh add cliente01      # cria o usuário e /data/cliente01 (pede a senha)
./manage-user.sh passwd cliente01   # troca a senha (pede a nova)
./manage-user.sh list               # lista os usuários do PureDB
./manage-user.sh del cliente01      # remove o usuário e MANTÉM /data/cliente01
```

**Resultado esperado:** depois do `add`, o usuário aparece no `list` e já consegue entrar por FTPS; depois do `del`, some do `list` e a pasta continua no volume.

Regras:

- Nome do usuário: `^[a-z_][a-z0-9_-]{0,31}$`.
- Senha: mínimo de **12 caracteres** (recusada abaixo disso).
- `del` **não apaga arquivos**: remova `/data/<usuario>` à mão se quiser.

> ⚠️ O usuário definido em `FTP_USER` é recriado ou atualizado a cada subida, com a senha de `.secrets/ftp_password.txt`. Para renomeá-lo, crie o novo com `add`, migre os dados e remova o antigo. Para trocar a senha dele, veja [🔑 Segredos](segredos.md#trocar-a-senha).

<details>
<summary>🔬 Detalhe técnico — onde a mudança é gravada</summary>

O `manage-user.sh` encapsula o [`scripts/ftp-user.sh`](../scripts/ftp-user.sh), que roda dentro do container como `allsafe-ftp-user`. As mudanças são gravadas em `/auth/pureftpd.passwd` e recompiladas em `/auth/pureftpd.pdb` (volume `allsafe-ftp-auth`). Não é preciso reiniciar o serviço: o `pure-ftpd` consulta o banco a cada login.

</details>

---

<a name="certificado-real-de-producao"></a>

## 🔏 Certificado real de produção

O certificado inicial é **autoassinado**, gerado na primeira subida. Para instalar um real:

```bash
# 1. Concatene chave e cadeia completa em um único PEM (chave primeiro)
cat privkey.pem fullchain.pem > pure-ftpd.pem
chmod 600 pure-ftpd.pem

# 2. Copie para o volume, no lugar do autoassinado
docker compose cp pure-ftpd.pem ftp:/etc/ssl/private/pure-ftpd.pem

# 3. Reinicie o serviço
docker compose restart ftp
```

**Resultado esperado:** o cliente conecta sem aviso de certificado e o container volta a `healthy`.

- O arquivo precisa conter **chave, certificado e intermediárias** no mesmo PEM, `0600`.
- O [`entrypoint.sh`](../scripts/entrypoint.sh) só gera o autoassinado **se o arquivo não existir**: o seu não será sobrescrito.
- Renovação: repita os passos 1 a 3 (por exemplo, por `cron` no host, puxando do seu cliente ACME).
- Apague a cópia local do `pure-ftpd.pem` depois de instalar: ela contém a chave privada.

---

<a name="backup-dos-volumes"></a>

## ♻️ Backup dos volumes

Volumes a salvar: `allsafe-ftp-data` (arquivos) e `allsafe-ftp-auth` (PureDB). O `allsafe-ftp-certs` é reconstruível se você tiver o PEM guardado em outro lugar.

```bash
# Backup: um tar.gz de cada volume
for v in allsafe-ftp-data allsafe-ftp-auth; do
  docker run --rm -v "$v":/src:ro -v "$PWD":/dst alpine \
    tar czf "/dst/$v-$(date +%Y%m%d).tar.gz" -C /src .
done
```

**Resultado esperado:** dois arquivos `allsafe-ftp-data-AAAAMMDD.tar.gz` e `allsafe-ftp-auth-AAAAMMDD.tar.gz` na pasta atual.

Restauração, com a stack parada:

```bash
docker compose down
docker run --rm -v allsafe-ftp-data:/dst -v "$PWD":/src alpine \
  sh -c 'cd /dst && tar xzf /src/allsafe-ftp-data-AAAAMMDD.tar.gz'
docker compose up -d
```

**Resultado esperado:** o container volta a `healthy` e os arquivos reaparecem na pasta do usuário.

> ⚠️ Os arquivos de backup gerados aqui **não** entram no repositório: guarde-os fora da árvore do projeto. O `allsafe-ftp-auth` contém o hash das senhas; trate a cópia como dado sensível.

---

<a name="logs"></a>

## 📜 Logs

```bash
docker compose logs -f ftp          # segue o log (acesso em formato CLF e mensagens do entrypoint)
docker compose logs --since 1h ftp  # última hora
```

**Resultado esperado:** a linha `FTP pronto em 2121/tcp; ...` da subida e uma linha CLF por transferência.

Rotação pelo Docker: `max-size: 10m`, `max-file: 3` (veja o [`compose.yaml`](../compose.yaml)). Para o `fail2ban`, aponte o filtro para a saída de `docker logs allsafe-ftp`.

---

<a name="atualizacao-da-imagem"></a>

## ⬆️ Atualização da imagem

```bash
docker compose build --pull        # refaz a imagem
./deploy.sh --size small           # recria o container com o mesmo perfil (volumes preservados)
./scripts/validate.sh --runtime    # confere 'running' e 'healthy'
```

**Resultado esperado:** `Validacao FTP concluida.` e os usuários e arquivos intactos.

> ⚠️ Recrie o container sempre pelo `deploy.sh` com o **mesmo perfil** da instalação. Um `docker compose up -d` puro lê só o `.env` e devolve os limites e a faixa passiva aos valores dele.

<details>
<summary>🔬 Detalhe técnico — base fixada por digest</summary>

A base no [`Dockerfile`](../Dockerfile) está **fixada por digest**: o `--pull` não troca a base sozinho. Para pegar uma base nova, atualize o digest do `FROM` e refaça o build. Enquanto o `Dockerfile` não muda, o Docker reaproveita a camada de instalação dos pacotes; para reinstalá-los com a versão atual do repositório Debian, acrescente `--no-cache` ao build.

</details>

---

<a name="inspecao-rapida"></a>

## 🔍 Inspeção rápida

```bash
docker compose ps                                   # estado e portas
docker inspect --format '{{.State.Health.Status}}' allsafe-ftp
docker compose exec ftp pure-pw list -f /auth/pureftpd.passwd
docker compose exec ftp pure-pw show transfer -f /auth/pureftpd.passwd
```

**Resultado esperado:** `running`, `healthy`, a lista de usuários e os dados do usuário `transfer` (pasta, uid e gid; a senha aparece só como hash).

---

<a name="parar-remover"></a>

## ⏹️ Parar e remover

```bash
docker compose stop      # para sem remover
docker compose down      # remove o container e a rede, mantém os volumes
docker compose down -v   # remove TAMBÉM os volumes (apaga tudo)
```

**Resultado esperado:** `docker compose ps` vazio; com `-v`, `docker volume ls` não lista mais os três volumes `allsafe-ftp-*`.

> ⚠️ `docker compose down -v` apaga os arquivos recebidos, os usuários e o certificado. Faça o [backup](#backup-dos-volumes) antes.

---

⬅️ [⌨️ Scripts](scripts.md) · 🏠 [Documentação](README.md) · ➡️ [🚨 Solução de problemas](solucao-de-problemas.md)
