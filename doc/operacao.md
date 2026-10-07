# 🧰 Operação — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [Índice da documentação](README.md)

## 💡 Em poucas palavras

Este guia reúne as tarefas do dia a dia: criar a conta de um equipamento novo, trocar uma senha, instalar o certificado definitivo, guardar uma cópia dos arquivos, ler os registros e atualizar o servidor. As contas também podem ser administradas pelo navegador, no [painel web](painel.md); aqui está o caminho pela linha de comando. Todos os comandos rodam na pasta raiz da stack.

<!-- diagrama: diagramas/usuarios-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    usuario@{ shape: person, label: "Usuário" }
    manage@{ shape: console, label: "manage-user.sh<br>add, passwd, pasta, del, list" }
    interno@{ shape: console, label: "allsafe-ftp-user<br>dentro do container" }
    puredb@{ shape: cyl, label: "PureDB<br>contas virtuais" }
    pasta@{ shape: lin-cyl, label: "/data<br>pasta do usuário" }
    fim@{ shape: stadium, label: "conta pronta" }

    usuario --> manage --> interno --> puredb --> pasta --> fim
```

<sub>Nível 1 · Diagrama · [fonte](diagramas/)</sub>

**Sequência:** Usuário ➜ `manage-user.sh` ➜ `allsafe-ftp-user` ➜ PureDB ➜ `/data` ➜ conta pronta

---

<details>
<summary>Sumário — clique para expandir</summary>

[Usuários](#usuarios) · [Certificado real de produção](#certificado-real-de-producao) · [Backup dos dados](#backup-dos-volumes) · [Logs](#logs) · [Atualização da imagem](#atualizacao-da-imagem) · [↩️ Voltar de versão](#voltar-de-versao) · [Inspeção rápida](#inspecao-rapida) · [Parar e remover](#parar-remover)

</details>

---

<a name="usuarios"></a>

## 👤 Usuários

Gestão pelo host com [`manage-user.sh`](../manage-user.sh). O [painel](painel.md#usuarios) faz as mesmas operações, com as mesmas regras:

```bash
./manage-user.sh add cliente01      # cria o usuário e /data/cliente01 (pede a senha)
./manage-user.sh add olt01 clientes/olt-01   # cria o usuário na pasta escolhida, /data/clientes/olt-01
./manage-user.sh passwd cliente01   # troca a senha (pede a nova)
./manage-user.sh pasta cliente01 clientes/olt-02   # troca a pasta; os arquivos da anterior continuam nela
./manage-user.sh limites cliente01 sessoes=2 download=500 horario=0800-1800   # grava limites só dele
./manage-user.sh limites cliente01  # mostra os limites dele
./manage-user.sh list               # lista os usuários do PureDB
./manage-user.sh del cliente01      # remove o usuário e MANTÉM a pasta dele
./manage-user.sh tls-dispensar olt-antiga   # deixa o usuário entrar sem TLS (só vale com FTP_TLS_EXCECOES=sim)
./manage-user.sh tls-exigir olt-antiga      # volta a exigir o TLS dele
./manage-user.sh tls-lista                  # lista quem está dispensado do TLS
```

**Resultado esperado:** depois do `add`, o usuário aparece no `list` e já consegue entrar por FTPS; depois do `pasta`, a resposta é `Pasta do usuario <nome>: /data/<pasta>. Os arquivos de /data/<anterior> continuam la.`; depois do `del`, some do `list` e a pasta continua no volume.

Regras:

- Nome do usuário: `^[a-z_][a-z0-9_-]{0,31}$`.
- Senha: mínimo de **12 caracteres** (recusada abaixo disso).
- Pasta: sem o terceiro parâmetro, é `/data/<usuario>`. Com ele, fica sempre dentro de `/data` (`DATA_DIR/dados` no host), com até 4 níveis separados por `/`; cada nível tem letras, números, `_`, `-` e ponto, não começa com ponto e vai até 64 caracteres. A pasta é criada se não existir. Pasta que passa por link simbólico ou por um arquivo é recusada, e nada é criado.
- `add` de um nome existente responde `Usuario ja existe`. Para mudar a pasta de quem já existe, use `pasta`, com as mesmas regras: vale na entrada seguinte, não troca a senha e não move nem apaga arquivo. Usuário que não existe: `Usuario nao existe: <nome>`.
- `limites` aceita um ou mais pares `chave=valor`, e só mexe nas chaves informadas: `sessoes` (sessões ao mesmo tempo no FTP), `download` e `envio` (KB por segundo, de 1 a 10.000.000), `horario` (`HHMM-HHMM`, no fuso do `TZ`, podendo passar da meia-noite) e `baixar` (downloads ao mesmo tempo pelo painel, de 1 a 8). Valor vazio (`download=`) tira o limite; sem nenhum par, mostra os que o usuário tem. Vale na entrada seguinte dele no FTP. O que cada limite faz está em [Painel web](painel.md#limites).
- `del` **não apaga arquivos** e responde com a pasta que ficou. Para tirar a pasta junto com o usuário, use o painel: Usuários ➜ **Remover**, com a caixa de apagar a pasta, em [Painel web](painel.md#usuarios). Depois do `del`, a pasta que ficou é apagada na aba Arquivos.
- `tls-dispensar` e `tls-exigir` valem na entrada seguinte do usuário, sem reiniciar, e só para usuário que existe (`Usuario nao existe: <nome>`). A dispensa só tem efeito com `FTP_TLS_EXCECOES=sim`; com `nao`, fica guardada. O `del` tira o usuário da lista.

> ⚠️ **Pasta dividida:** dois usuários com a mesma pasta, ou com uma dentro da outra, leem, gravam e apagam os arquivos um do outro. O `add` aceita e avisa, uma linha `Aviso:` por usuário que passa a dividir a pasta. Para um equipamento não alcançar o backup de outro, dê a cada um a própria pasta.

> ⚠️ **Dispensa do TLS:** o usuário dispensado manda senha e arquivo em texto puro. Só para equipamento antigo que não fala TLS, em rede interna isolada: [Segurança](seguranca.md#tls-por-usuario).

> ⚠️ O usuário definido em `FTP_USER` é criado na primeira subida, com a senha de `.secrets/ftp-usuario-inicial-senha.txt`, e não é removido pelo painel. A senha e a pasta dele são trocadas como as dos demais; a senha trocada vale até o arquivo do segredo ser alterado: [Segredos](segredos.md#trocar-a-senha). Para renomeá-lo, crie o novo com `add`, migre os dados e remova o antigo.

<details>
<summary>Detalhe técnico — onde a mudança é gravada</summary>

O `manage-user.sh` encapsula o [`ftp/usuario.sh`](../ftp/usuario.sh), que roda dentro do container como `allsafe-ftp-user`. As mudanças são gravadas em `/auth/pureftpd.passwd` e recompiladas em `/auth/pureftpd.pdb` (pasta `DATA_DIR/auth` do host). Não é preciso reiniciar o serviço: o `pure-ftpd` consulta o banco a cada login. O painel chama o mesmo script, e uma trava (`/auth/.lock`) impede duas alterações ao mesmo tempo. A dispensa do TLS fica em `/auth/sem-tls.lista`, um nome por linha, lida pelo servidor a cada entrada. Os limites de sessões, de taxa e de horário ficam na própria linha do usuário no cadastro; o de downloads pelo painel, em `/auth/limites.lista`.

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
- O [`ftp/entrypoint.sh`](../ftp/entrypoint.sh) só gera o autoassinado **se o arquivo não existir**: o seu não será sobrescrito.
- Renovação: repita os passos 1 a 3 (por exemplo, por `cron` no host, puxando do seu cliente ACME).
- Apague a cópia local do `pure-ftpd.pem` depois de instalar: ela contém a chave privada.

---

<a name="backup-dos-volumes"></a>

## ♻️ Backup dos dados

Um comando guarda os arquivos dos equipamentos, os usuários, os certificados e a auditoria do painel em um arquivo de `BACKUP_DIR`; outro devolve a stack ao estado de uma cópia:

```bash
./scripts/backup.sh                                              # grava a cópia, com a stack no ar
./scripts/backup.sh --listar                                     # mostra as cópias que existem
./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz  # volta ao estado da cópia
```

**Resultado esperado:** `Cópia gravada: <BACKUP_DIR>/allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz (...)` no primeiro comando e, na restauração, `Restaurado e no ar (healthy).`

O que entra na cópia, como desfazer uma restauração, como restaurar em outro servidor e como agendar a cópia estão em [Backup e restauração](backup.md).

Para pegar **um arquivo só**, enviado por um equipamento, use a aba Arquivos do painel: [Arquivos e download](painel.md#arquivos). O dono dos arquivos pega os dele do mesmo jeito, entrando no painel com o usuário e a senha do FTP: [Usuário do FTP no painel](painel.md#usuario-ftp). No host, o mesmo arquivo está na pasta do usuário, dentro de `DATA_DIR/dados`: a aba Usuários mostra o caminho de cada um.

> ⚠️ A cópia contém o hash das senhas e as chaves privadas dos certificados: trate como dado sensível e leve-a também para fora do servidor. O `.env` e os arquivos de `.secrets/` não entram na cópia: guarde-os à parte, em um cofre de senhas.

---

<a name="migracao"></a>

## 🚚 Migrar dos volumes nomeados (instalação anterior à 0.2.0)

Até a versão `0.1.x` os dados ficavam em volumes nomeados do Docker (`allsafe-ftp-data`, `allsafe-ftp-auth`, `allsafe-ftp-certs`). A partir da `0.2.0` ficam em `DATA_DIR`. A migração **copia**, não move: os volumes antigos continuam intactos até você decidir apagá-los.

```bash
docker compose down                       # 1. para a stack antiga (sem -v)
git pull                                  # 2. traz a versão nova
# 3. no .env: acrescente as chaves novas do .env.example (DATA_DIR, BACKUP_DIR, TEMP_DIR, SECRETS_DIR,
#    STACK_NAME, FTP_CONTAINER_NAME, FTP_NETWORK_NAME) e apague FTP_PASSWORD e FTP_PASSWORD_FILE.
#    Se a senha estava no .env, grave-a em .secrets/ftp-usuario-inicial-senha.txt (chmod 600).
DATA_DIR=/home/carlos/code/data/allsafe-ftp-stack   # o DATA_DIR do seu .env
mkdir -p "$DATA_DIR"/{dados,auth,certs}
docker build -q -t allsafe-ftp:local .    # 4. imagem nova, usada para copiar
for par in allsafe-ftp-data:dados allsafe-ftp-auth:auth allsafe-ftp-certs:certs; do
  docker run --rm --network none -v "${par%%:*}":/origem:ro -v "$DATA_DIR/${par##*:}":/destino \
    --entrypoint cp allsafe-ftp:local -a /origem/. /destino/
done
./deploy.sh                               # 5. sobe com as pastas novas
```

**Resultado esperado:** container `healthy`, os usuários entram com a mesma senha e os arquivos aparecem na pasta de cada usuário, dentro de `DATA_DIR/dados`.

Só depois de conferir, e por decisão sua, apague os volumes antigos: `docker volume rm allsafe-ftp-data allsafe-ftp-auth allsafe-ftp-certs`.

---

<a name="logs"></a>

## 📜 Logs

```bash
docker compose logs -f ftp          # segue o log (acesso em formato CLF e mensagens do entrypoint)
docker compose logs --since 1h ftp  # última hora
docker compose logs -f painel       # subida do painel e avisos do servidor web
docker compose logs -f nginx        # subida do nginx e os pedidos que ele recusou
```

**Resultado esperado:** a linha `FTP pronto em 2121/tcp; ...` da subida e uma linha CLF por transferência; no painel, a linha `Painel pronto no soquete /nginx/painel.sock, atrás do nginx; ...`; no nginx, `nginx pronto em 8443/tcp (HTTPS), à frente do painel; ...`.

O nginx registra só o que ele mesmo recusa, uma linha por pedido, no formato `ip método caminho código` (exemplo: `10.99.0.7 GET /entrar 403`). Com `FTP_TLS_MODE` em `0` ou `1`, o log do FTP traz a cada subida o `AVISO` de FTP sem criptografia: [Segurança](seguranca.md#ftp-sem-tls). Com `FTP_TLS_EXCECOES=sim`, traz o `AVISO` com a quantidade de usuários dispensados e uma linha `porteiro: entrada sem TLS recusada: usuario=<nome> origem=<ip>` para cada entrada sem TLS de quem não foi dispensado: [Segurança](seguranca.md#tls-por-usuario).

O que foi feito pelo painel (entradas, saídas, usuários criados, alterados e removidos, arquivos baixados) fica no `auditoria.log`, visível na aba `📜 Atividade`: veja [Painel web](painel.md#auditoria).

Rotação pelo Docker: `max-size: 10m`, `max-file: 3` (veja o [`compose.yaml`](../compose.yaml)). Para o `fail2ban`, aponte o filtro para a saída de `docker logs allsafe-ftp`.

---

<a name="atualizacao-da-imagem"></a>

## ⬆️ Atualização da imagem

```bash
./deploy.sh --atualizar            # refaz as três imagens sem cache e recria os containers (dados preservados)
./scripts/validate.sh --runtime    # confere os três serviços 'running' e 'healthy'
```

**Resultado esperado:** `Validacao FTP concluida.` e os usuários e arquivos intactos. As sessões abertas no painel são encerradas.

> O `--atualizar` reinstala os pacotes com a versão atual do repositório Debian. O perfil em uso está no `.env` e continua valendo.

<details>
<summary>Detalhe técnico — base fixada por digest</summary>

A base no [`Dockerfile`](../Dockerfile) está **fixada por digest**: um `docker compose build --pull` não troca a base sozinho. Para pegar uma base nova, atualize o digest do `FROM` e rode `./deploy.sh --atualizar`. Enquanto o `Dockerfile` não muda, um `docker compose build` comum reaproveita a camada de instalação dos pacotes; o `--atualizar` usa `build --no-cache`, que refaz essa camada e reinstala os pacotes na versão atual do repositório Debian. As três imagens (FTP, painel e nginx) saem da mesma base, `debian:trixie-slim` (Debian 13).

</details>

<a name="voltar-de-versao"></a>

<details>
<summary>Detalhe técnico — voltar para a versão anterior</summary>

Os dados, os usuários, as senhas e os certificados ficam em `DATA_DIR` e em `.secrets/`, fora do código: voltar de versão é trocar os arquivos do projeto e subir de novo. Remova **antes**, ainda com os arquivos da versão atual, porque só ela conhece todos os containers que criou:

```bash
./deploy.sh --remover      # 1. versão atual: derruba os três containers e a rede; os dados ficam
git checkout v0.4.0        # 2. volta os arquivos do projeto para a tag da versão anterior
./deploy.sh                # 3. sobe a versão anterior com os mesmos dados
```

**Resultado esperado:** os containers da versão anterior em `healthy`, com os mesmos usuários, senhas e certificados.

> ⚠️ `FTP_TLS_MODE=0` só existe a partir da `0.5.0`: antes do passo 3, volte a variável para `1`, `2` ou `3`. As chaves novas do `.env` (as `NGINX_*`) são ignoradas pela versão anterior e podem ficar.

</details>

---

<a name="inspecao-rapida"></a>

## 🔍 Inspeção rápida

```bash
docker compose ps                                   # estado e portas
docker inspect --format '{{.State.Health.Status}}' allsafe-ftp
docker inspect --format '{{.State.Health.Status}}' allsafe-ftp-painel
docker inspect --format '{{.State.Health.Status}}' allsafe-ftp-nginx
./manage-user.sh list                               # usuários do PureDB
docker compose exec ftp pure-pw show transfer -f /auth/pureftpd.passwd
```

**Resultado esperado:** os três containers `running` e `healthy`, a lista de usuários e os dados do usuário `transfer` (pasta, uid e gid; a senha aparece só como hash).

---

<a name="parar-remover"></a>

## ⏹️ Parar e remover

```bash
docker compose stop                       # para sem remover
./deploy.sh --remover                     # remove os containers e a rede; os dados continuam em DATA_DIR
./deploy.sh --remover --apagar-dados      # remove e apaga as pastas de DATA_DIR (pede para digitar "apagar")
```

**Resultado esperado:** `docker compose ps` vazio. As pastas `dados/`, `auth/`, `certs/`, `painel/` e `nginx/` de `DATA_DIR` e os segredos continuam no host; apagar os dados é uma decisão à parte, só com `--apagar-dados`.

> ⚠️ Os dados ficam em pastas do host: nem o `docker compose down -v` os apaga. O `--apagar-dados` **não tem volta**: faça o [backup](#backup-dos-volumes) antes. Sem terminal (em script), ele só roda com `--sim`. Os segredos e o `.env` não são apagados.

---

⬅️ [Scripts](scripts.md) · 🏠 [Documentação](README.md) · ➡️ [Backup e restauração](backup.md)
