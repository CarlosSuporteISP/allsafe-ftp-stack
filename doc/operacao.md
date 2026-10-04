# 🧰 Operação — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [📚 Índice da documentação](README.md)

## 💡 Em poucas palavras

Este guia reúne as tarefas do dia a dia: criar a conta de um equipamento novo, trocar uma senha, instalar o certificado definitivo, guardar uma cópia dos arquivos, ler os registros e atualizar o servidor. As contas também podem ser administradas pelo navegador, no [🖥️ painel web](painel.md); aqui está o caminho pela linha de comando. Todos os comandos rodam na pasta raiz da stack.

<!-- diagrama: diagramas/usuarios-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    usuario@{ shape: person, label: "👤 Usuário" }
    manage@{ shape: console, label: "⌨️ manage-user.sh<br>add, passwd, del, list" }
    interno@{ shape: console, label: "⌨️ allsafe-ftp-user<br>dentro do container" }
    puredb@{ shape: cyl, label: "🗄️ PureDB<br>contas virtuais" }
    pasta@{ shape: lin-cyl, label: "💽 /data<br>pasta do usuário" }
    fim@{ shape: stadium, label: "🏁 conta pronta" }

    usuario --> manage --> interno --> puredb --> pasta --> fim
```

<sub>📐 Nível 1 · Diagrama · 🔍 aproximar e mover: controles no canto do diagrama · 📁 [fonte](diagramas/)</sub>

**🧭 Sequência:** 👤 Usuário ➜ ⌨️ `manage-user.sh` ➜ ⌨️ `allsafe-ftp-user` ➜ 🗄️ PureDB ➜ 💽 `/data` ➜ 🏁 conta pronta

---

<details>
<summary>🧭 Sumário — clique para expandir</summary>

[👤 Usuários](#usuarios) · [🔏 Certificado real de produção](#certificado-real-de-producao) · [♻️ Backup dos volumes](#backup-dos-volumes) · [📜 Logs](#logs) · [⬆️ Atualização da imagem](#atualizacao-da-imagem) · [🔍 Inspeção rápida](#inspecao-rapida) · [⏹️ Parar e remover](#parar-remover)

</details>

---

<a name="usuarios"></a>

## 👤 Usuários

Gestão pelo host com [`manage-user.sh`](../manage-user.sh). O [painel](painel.md#usuarios) faz as mesmas operações, com as mesmas regras:

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

O `manage-user.sh` encapsula o [`scripts/ftp-user.sh`](../scripts/ftp-user.sh), que roda dentro do container como `allsafe-ftp-user`. As mudanças são gravadas em `/auth/pureftpd.passwd` e recompiladas em `/auth/pureftpd.pdb` (pasta `DATA_DIR/auth` do host). Não é preciso reiniciar o serviço: o `pure-ftpd` consulta o banco a cada login. O painel chama o mesmo script, e uma trava (`/auth/.lock`) impede duas alterações ao mesmo tempo.

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

## ♻️ Backup dos dados

Pastas a salvar: `DATA_DIR/dados` (arquivos) e `DATA_DIR/auth` (PureDB). A `DATA_DIR/certs` é reconstruível se você tiver o PEM guardado em outro lugar. A `DATA_DIR/painel` guarda o certificado do painel, que é refeito sozinho, e o `auditoria.log`: para manter o histórico, acrescente `painel` ao fim do comando. A leitura é feita por um container, porque `auth/` pertence ao `root`.

```bash
DATA_DIR=/home/carlos/code/data/allsafe-ftp-stack      # o DATA_DIR do seu .env
BACKUP_DIR=/home/carlos/code/backups/allsafe-ftp-stack # o BACKUP_DIR do seu .env
mkdir -p "$BACKUP_DIR"
docker run --rm --network none -v "$DATA_DIR":/origem:ro -v "$BACKUP_DIR":/destino \
  --entrypoint tar allsafe-ftp:local czf "/destino/$(date +%Y%m%d-%H%M%S)-dados-auth.tar.gz" -C /origem dados auth
```

**Resultado esperado:** um arquivo `AAAAMMDD-HHMMSS-dados-auth.tar.gz` em `BACKUP_DIR`.

Restauração, com a stack parada:

```bash
docker compose down
docker run --rm --network none -v "$DATA_DIR":/destino -v "$BACKUP_DIR":/origem:ro \
  --entrypoint tar allsafe-ftp:local xzf /origem/AAAAMMDD-HHMMSS-dados-auth.tar.gz -C /destino
docker compose up -d
```

**Resultado esperado:** o container volta a `healthy` e os arquivos reaparecem na pasta do usuário.

> ⚠️ A cópia **não** entra no repositório. Ela contém o hash das senhas (`auth/`): trate como dado sensível. Os arquivos de `.secrets/` não entram na cópia: guarde-os à parte, em um cofre de senhas.

---

<a name="migracao"></a>

## 🚚 Migrar dos volumes nomeados (instalação anterior à 0.2.0)

Até a versão `0.1.x` os dados ficavam em volumes nomeados do Docker (`allsafe-ftp-data`, `allsafe-ftp-auth`, `allsafe-ftp-certs`). A partir da `0.2.0` ficam em `DATA_DIR`. A migração **copia**, não move: os volumes antigos continuam intactos até você decidir apagá-los.

```bash
docker compose down                       # 1. para a stack antiga (sem -v)
git pull                                  # 2. traz a versão nova
# 3. no .env: acrescente as chaves novas do .env.example (DATA_DIR, BACKUP_DIR, TEMP_DIR, SECRETS_DIR,
#    STACK_NAME, FTP_CONTAINER_NAME, FTP_NETWORK_NAME) e apague FTP_PASSWORD e FTP_PASSWORD_FILE.
#    Se a senha estava no .env, grave-a em .secrets/ftp_password.txt (chmod 600).
DATA_DIR=/home/carlos/code/data/allsafe-ftp-stack   # o DATA_DIR do seu .env
mkdir -p "$DATA_DIR"/{dados,auth,certs}
docker build -q -t allsafe-ftp:local .    # 4. imagem nova, usada para copiar
for par in allsafe-ftp-data:dados allsafe-ftp-auth:auth allsafe-ftp-certs:certs; do
  docker run --rm --network none -v "${par%%:*}":/origem:ro -v "$DATA_DIR/${par##*:}":/destino \
    --entrypoint cp allsafe-ftp:local -a /origem/. /destino/
done
./deploy.sh                               # 5. sobe com as pastas novas
```

**Resultado esperado:** container `healthy`, os usuários entram com a mesma senha e os arquivos aparecem em `DATA_DIR/dados/<usuario>`.

Só depois de conferir, e por decisão sua, apague os volumes antigos: `docker volume rm allsafe-ftp-data allsafe-ftp-auth allsafe-ftp-certs`.

---

<a name="logs"></a>

## 📜 Logs

```bash
docker compose logs -f ftp          # segue o log (acesso em formato CLF e mensagens do entrypoint)
docker compose logs --since 1h ftp  # última hora
docker compose logs -f painel       # subida do painel e avisos do servidor web
```

**Resultado esperado:** a linha `FTP pronto em 2121/tcp; ...` da subida e uma linha CLF por transferência; no painel, a linha `Painel pronto em 8443/tcp (HTTPS); ...`.

O que foi feito pelo painel (entradas, saídas, usuários criados, alterados e removidos) fica no `auditoria.log`, visível na aba `📜 Atividade`: veja [🖥️ Painel web](painel.md#auditoria).

Rotação pelo Docker: `max-size: 10m`, `max-file: 3` (veja o [`compose.yaml`](../compose.yaml)). Para o `fail2ban`, aponte o filtro para a saída de `docker logs allsafe-ftp`.

---

<a name="atualizacao-da-imagem"></a>

## ⬆️ Atualização da imagem

```bash
docker compose build --pull        # refaz as duas imagens
./deploy.sh --size small           # recria os containers com o mesmo perfil (dados preservados)
./scripts/validate.sh --runtime    # confere 'running' e 'healthy'
```

**Resultado esperado:** `Validacao FTP concluida.` e os usuários e arquivos intactos. As sessões abertas no painel são encerradas.

> ⚠️ Recrie os containers sempre pelo `deploy.sh` com o **mesmo perfil** da instalação. Um `docker compose up -d` puro lê só o `.env` e devolve os limites e a faixa passiva aos valores dele.

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
docker inspect --format '{{.State.Health.Status}}' allsafe-ftp-painel
./manage-user.sh list                               # usuários do PureDB
docker compose exec ftp pure-pw show transfer -f /auth/pureftpd.passwd
```

**Resultado esperado:** os dois containers `running` e `healthy`, a lista de usuários e os dados do usuário `transfer` (pasta, uid e gid; a senha aparece só como hash).

---

<a name="parar-remover"></a>

## ⏹️ Parar e remover

```bash
docker compose stop      # para sem remover
docker compose down      # remove os containers e a rede; os dados continuam em DATA_DIR
```

**Resultado esperado:** `docker compose ps` vazio. As pastas `dados/`, `auth/`, `certs/` e `painel/` de `DATA_DIR` e os segredos continuam no host; apagar os dados é uma decisão à parte, manual.

> ⚠️ Os dados ficam em pastas do host: nem o `docker compose down -v` os apaga. Para apagar de vez, remova as pastas de `DATA_DIR` à mão, depois do [backup](#backup-dos-volumes).

---

⬅️ [⌨️ Scripts](scripts.md) · 🏠 [Documentação](README.md) · ➡️ [🖥️ Painel web](painel.md)
