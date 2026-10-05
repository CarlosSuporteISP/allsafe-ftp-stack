# ⚙️ Configuração — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [Índice da documentação](README.md)

## 💡 Em poucas palavras

Tudo o que muda de uma instalação para outra fica em um arquivo só, o `.env`: o IP, a porta, o nome do usuário, o modo de TLS e os limites. O porte do servidor vem de um perfil pronto: ao escolher o tamanho, o `deploy.sh` grava os números de capacidade dele no próprio `.env`. O Docker Compose lê o `.env` e aplica aos três containers: o FTP, o painel e o nginx que fica na frente do painel.

<!-- diagrama: diagramas/configuracao-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    perfil@{ shape: doc, label: "profiles/medium.env<br>limites do perfil" }
    deploy@{ shape: console, label: "deploy.sh --size medium<br>grava os limites no .env" }
    env@{ shape: doc, label: ".env<br>ambiente e limites" }
    compose@{ shape: rect, label: "Docker Compose<br>lê só o .env" }
    ftp@{ shape: rect, label: "Pure-FTPd<br>allsafe-ftp" }
    fim@{ shape: stadium, label: "limites aplicados" }

    perfil --> deploy --> env --> compose --> ftp --> fim
```

<sub>Nível 1 · Diagrama · [fonte](diagramas/)</sub>

**Sequência:** `profiles/medium.env` ➜ `deploy.sh --size medium` (grava os limites no `.env`) ➜ `.env` ➜ Docker Compose ➜ Pure-FTPd (`allsafe-ftp`) ➜ limites aplicados

---

<details>
<summary>Sumário — clique para expandir</summary>

[Exemplo mínimo de produção](#exemplo-minimo-de-producao) · [Geral](#geral) · [Rede e portas](#rede-e-portas) · [Usuário inicial e senha](#usuario-inicial-e-senha) · [TLS](#tls) · [Limites de sessão](#limites-de-sessao) · [Painel web](#painel) · [Contato de segurança](#contato-de-seguranca) · [Limites de recurso do container](#limites-de-recurso-do-container) · [Rede Docker](#rede-docker-sub-rede)

</details>

---

<a name="exemplo-minimo-de-producao"></a>

## 🧾 Exemplo mínimo de produção

Todas as variáveis vivem no `.env`, copiado de [`.env.example`](../.env.example). No exemplo, as variáveis vêm agrupadas por assunto e **cada uma tem, na linha de cima, um comentário dizendo para que serve**; este guia traz o mesmo, com mais detalhe.

```ini
TZ=America/Sao_Paulo
DATA_DIR=/home/carlos/code/data/allsafe-ftp-stack
FTP_BIND_IP=192.168.10.20
FTP_PASSIVE_IP=192.168.10.20
FTP_PORT=21
FTP_PASSIVE_PORT_START=30000
FTP_PASSIVE_PORT_END=30049
FTP_USER=backup-rede
FTP_TLS_MODE=2
FTP_CERT_CN=ftp.exemplo.com.br
FTP_MAX_CLIENTS=50
FTP_MAX_CLIENTS_PER_IP=8
```

Nenhuma senha entra no `.env`: ela fica em `.secrets/ftp-usuario-inicial-senha.txt` ([Segredos](segredos.md)).

Depois de editar o `.env`, valide sem subir:

```bash
./deploy.sh --check-only
```

**Resultado esperado:** `OK: perfil 'small', rede privada, recursos do servidor e compose validados; nada foi alterado.` Um IP fora das faixas privadas, uma senha no `.env`, um `FTP_TLS_MODE` fora de `0` a `3` ou um perfil maior que o servidor param o comando com a explicação.

A coluna **Padrão** das tabelas abaixo é o valor do [`.env.example`](../.env.example). Quando a variável falta no `.env`, o [`compose.yaml`](../compose.yaml) aplica o mesmo valor, com três exceções: `FTP_CERT_CN` vira `localhost`, e `DATA_DIR` e `FTP_PASSIVE_IP` não têm padrão no Compose: sem elas o comando para com `defina DATA_DIR no .env` ou `defina FTP_PASSIVE_IP no .env`.

---

<a name="geral"></a>

## 🌍 Geral

| Variável | Para que serve | Valores | Padrão |
|---|---|---|---|
| `TZ` | Fuso horário do container (afeta logs e validade do certificado) | Nome IANA, exemplo: `America/Sao_Paulo` | `America/Sao_Paulo` |
| `FTP_IMAGE` | Nome e tag da imagem do FTP, construída no host | `nome:tag` | `allsafe-ftp:local` |
| `PAINEL_IMAGE` | Nome e tag da imagem do painel, construída no host | `nome:tag` | `allsafe-ftp-painel:local` |
| `NGINX_IMAGE` | Nome e tag da imagem do nginx que fica na frente do painel, construída no host | `nome:tag` | `allsafe-ftp-nginx:local` |

---

<a name="pastas-e-nomes"></a>

## 📦 Pastas e nomes

| Variável | Para que serve | Valores | Padrão |
|---|---|---|---|
| `DATA_DIR` | Pasta do host com os dados da stack: `dados/` (arquivos enviados), `auth/` (PureDB), `certs/` (TLS do FTP), `painel/` (certificado e auditoria do painel) e `nginx/` (o soquete e a cópia do certificado que o nginx lê). Montada por _bind mount_; a stack não cria volume nomeado | Caminho absoluto | `/home/carlos/code/data/allsafe-ftp-stack` |
| `BACKUP_DIR` | Pasta do host onde o `scripts/backup.sh` grava as cópias de segurança e o `scripts/restaurar.sh` as procura. Nasce com modo `0700` e tem de ficar fora de `DATA_DIR`: [Backup e restauração](backup.md) | Caminho absoluto | `/home/carlos/code/backups/allsafe-ftp-stack` |
| `TEMP_DIR` | Pasta do host para temporários: instância de teste, coleta de diagnóstico | Caminho absoluto | `/home/carlos/code/tmp/allsafe-ftp-stack` |
| `SECRETS_DIR` | Pasta dos segredos, um arquivo por segredo, modo `0700` | Caminho absoluto ou relativo à pasta do projeto | `./.secrets` |
| `STACK_NAME` | Nome do projeto no Compose | Minúsculas, números e hífen | `allsafe-ftp-stack` |
| `FTP_CONTAINER_NAME` | Nome do container e do host do FTP | Nome de container | `allsafe-ftp` |
| `PAINEL_CONTAINER_NAME` | Nome do container e do host do painel | Nome de container | `allsafe-ftp-painel` |
| `NGINX_CONTAINER_NAME` | Nome do container e do host do nginx | Nome de container | `allsafe-ftp-nginx` |
| `FTP_NETWORK_NAME` | Nome da rede Docker da stack | Nome de rede | `allsafe-ftp-network` |

Para uma **segunda instância** no mesmo host, troque os cinco nomes, as três imagens, as pastas, as portas (do FTP e do painel) e a `FTP_SUBNET`. O [`deploy.sh`](../deploy.sh) aceita outro arquivo no lugar do `.env`: `ENV_FILE=/caminho/outro.env ./deploy.sh`.

---

<a name="rede-e-portas"></a>

## 🔌 Rede e portas

| Variável | Para que serve | Valores | Padrão |
|---|---|---|---|
| `REDE_PERMITIR_IP_PUBLICO` | Aceitar endereço público no FTP e no painel. Leia o [alerta](#rede-permitir-ip-publico) antes de ligar | `nao` ou `sim` | `nao` |
| `FTP_BIND_IP` | IP do **host** onde a porta de controle e a faixa passiva escutam | IP privado do host; `0.0.0.0` é sempre recusado; IP público, só com `REDE_PERMITIR_IP_PUBLICO=sim` | `127.0.0.1` |
| `FTP_PORT` | Porta de controle publicada no host (mapeada para `2121` no container) | `1` a `65535` | `21` |
| `FTP_PASSIVE_IP` | IP que o servidor **anuncia** ao cliente no modo passivo (resposta `PASV`): o IP **interno** pelo qual os equipamentos chegam ao servidor (nota abaixo) | IP privado, alcançável pelo cliente; IP público, só com `REDE_PERMITIR_IP_PUBLICO=sim` | `127.0.0.1` |
| `FTP_PASSIVE_PORT_START` | Início da faixa de portas de dados (modo passivo) | `1024` a `65535`, menor ou igual ao fim | `30000` |
| `FTP_PASSIVE_PORT_END` | Fim da faixa passiva. Número de portas maior ou igual a `FTP_MAX_CLIENTS` | `1024` a `65535`, maior ou igual ao início | `30049` |

> 🧱 **Rede privada:** por padrão só são aceitos `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12` e `192.168.0.0/16`. O [`deploy.sh`](../deploy.sh) e o container param com `não é IP privado` para qualquer outro valor ([`scripts/rede-privada.sh`](../scripts/rede-privada.sh)).

<a name="rede-permitir-ip-publico"></a>

> ⚠️ **Alerta — `REDE_PERMITIR_IP_PUBLICO=sim` põe o FTP e o painel na internet.** Servidor exposto é varrido e recebe tentativa de senha o tempo todo. Ligue só com firewall no servidor liberando as portas apenas para os endereços dos equipamentos e de quem administra, com `FTP_TLS_MODE` em `2` ou `3` (com a opção, `0` e `1` são recusados), senhas geradas e `PAINEL_REDES_PERMITIDAS` reduzida. Mesmo com `sim`, `0.0.0.0` e rede mais larga que `/8` continuam recusados. Sem firewall, o risco é de quem ligou a opção. O passo a passo está em [Segurança](seguranca.md#ip-publico).

> ⚠️ A faixa passiva é publicada **1:1** (mesma porta no host e no container). Ao ampliá-la, ajuste também o firewall do host.

<a name="ftp-passive-ip"></a>
<a name="ftp-public-ip"></a>

> **Para que serve `FTP_PASSIVE_IP`?** No modo passivo, o servidor diz ao cliente em qual IP e em qual porta abrir a conexão de dados. O Pure-FTPd, dentro do container, só conhece o endereço da rede Docker, que o equipamento não alcança; por isso a stack informa a ele qual endereço anunciar (opção `-P`). O valor é o IP **privado** do host pelo qual os equipamentos chegam, em geral o mesmo de `FTP_BIND_IP`. Só é diferente quando existe NAT interno entre o equipamento e o servidor. IP de internet é recusado.

> **Instalação anterior à `0.9.0`:** a variável se chamava `FTP_PUBLIC_IP`. O `./deploy.sh` troca o nome sozinho, mantém o valor e guarda o `.env` de antes em `BACKUP_DIR/<data>-antes-da-migracao-de-nomes/env`. Até ele rodar, os comandos que chamam o Compose param com `defina FTP_PASSIVE_IP no .env`. Os arquivos de `.secrets/` também mudaram de nome, na `0.10.0`, e são convertidos na mesma execução: [Segredos](segredos.md#nomes-antigos).

---

<a name="usuario-inicial-e-senha"></a>

## 👤 Usuário inicial e senha

| Variável | Para que serve | Valores | Padrão |
|---|---|---|---|
| `FTP_USER` | Nome do usuário virtual criado ou atualizado a cada subida | Regra `^[a-z_][a-z0-9_-]{0,31}$` | `transfer` |
A **senha** do usuário inicial não é variável: fica em `SECRETS_DIR/ftp-usuario-inicial-senha.txt`, criada pelo `deploy.sh`, e chega ao container como o segredo `/run/secrets/ftp_usuario_inicial_senha`. Um `.env` com `FTP_PASSWORD` preenchido é recusado. Veja [Segredos](segredos.md).

Só o usuário inicial vem do `.env`. Os demais são criados com [`manage-user.sh`](../manage-user.sh): veja [Operação](operacao.md#usuarios).

---

<a name="tls"></a>

## 🔐 TLS

| Variável | Para que serve | Valores | Padrão |
|---|---|---|---|
| `FTP_TLS_MODE` | Política de TLS do `pure-ftpd` (opção `-Y`) | `0`, `1`, `2` ou `3` (tabela abaixo) | `2` |
| `FTP_TLS_EXCECOES` | TLS por usuário: com `sim`, os usuários que um administrador dispensar na aba Usuários do painel entram sem TLS, e os demais continuam obrigados a usar. Exige `FTP_TLS_MODE=2` e não liga junto com `REDE_PERMITIR_IP_PUBLICO=sim` | `nao` ou `sim` | `nao` |
| `FTP_CERT_CN` | `CN` e `SAN` do certificado autoassinado gerado na primeira subida. Se for um IPv4, entra como `IP:`; senão, como `DNS:` | hostname ou IPv4 | `ftp.exemplo.com.br` no exemplo; `localhost` se a variável faltar |

| Modo | Sessão sem TLS | Canal de dados sem criptografia | Quando usar |
|---|---|---|---|
| `0` | **é a única que existe**: o servidor não oferece TLS | sempre sem criptografia | só equipamento antigo sem suporte a TLS |
| `1` | aceita (TLS opcional) | aceito | equipamentos antigos e novos no mesmo servidor |
| `2` | **recusada**: só entra quem negocia TLS | aceito, se o cliente pedir | **padrão** |
| `3` | **recusada** | **recusado**: os dados também têm de ser criptografados | todos os equipamentos suportam `PROT P` |

> ⚠️ **Modos `0` e `1`: FTP sem criptografia.** Existem só para equipamento antigo que não fala TLS. Neles, usuário, senha e arquivo passam em **texto puro** e podem ser lidos por quem estiver no mesmo caminho de rede. Use apenas em rede interna isolada, com o firewall liberando a porta só para esses equipamentos, com usuário e senha dedicados a eles, e volte para `2` assim que puder. Enquanto um desses modos estiver ligado, a stack avisa em três lugares: no fim do `./deploy.sh`, no registro do container do FTP e nas telas do painel. Leia antes [Segurança](seguranca.md#ftp-sem-tls).

> ⚠️ **`FTP_TLS_EXCECOES=sim`: sem TLS só para quem o administrador dispensar.** O servidor continua exigindo TLS de todos, menos dos usuários que um administrador dispensar, um a um, na aba Usuários do painel ou com o `manage-user.sh`. O usuário dispensado manda senha e arquivo em **texto puro**, e as condições de uso são as mesmas dos modos `0` e `1`. Com `nao`, o padrão, ninguém entra sem TLS, mesmo que já tenha sido dispensado antes: a lista fica guardada e não vale. Leia antes [Segurança](seguranca.md#tls-por-usuario).

Um valor fora de `0` a `3` é recusado pelo `deploy.sh` antes de qualquer alteração e, se chegar ao container, ele para com `FALHA: FTP_TLS_MODE deve ser 0, 1, 2 ou 3`. O certificado do FTP é gerado em qualquer modo: ao voltar para `2`, ele já está lá.

A `FTP_TLS_EXCECOES` também é conferida antes de qualquer alteração, pelo `deploy.sh` e pelos containers do FTP e do painel: valor fora de `nao` e de `sim`, `sim` com `FTP_TLS_MODE` diferente de `2` e `sim` junto com `REDE_PERMITIR_IP_PUBLICO=sim` são recusados. Em `0` e `1` todos já entram sem TLS, e o `3` exige TLS também nos dados, o que o equipamento sem TLS não faz.

> ⚠️ No modo `2`, o padrão, usuário e senha sempre trafegam criptografados, mas o conteúdo do arquivo só é criptografado se o cliente pedir proteção do canal de dados (`PROT P`). Para **obrigar** a criptografia do arquivo, use `FTP_TLS_MODE=3` e confira antes se os equipamentos suportam.

Trocar o certificado autoassinado por um real: [Operação](operacao.md#certificado-real-de-producao).

---

<a name="limites-de-sessao"></a>

## 👥 Limites de sessão

| Variável | Para que serve | Valores | Padrão |
|---|---|---|---|
| `FTP_MAX_CLIENTS` | Máximo de conexões simultâneas (opção `-c`). Alinhe ao tamanho da faixa passiva. Também define o custo da senha gravada de cada usuário do FTP: [Segurança](seguranca.md#custo-das-senhas) | inteiro maior que zero | `50` |
| `FTP_MAX_CLIENTS_PER_IP` | Máximo de conexões por IP de origem (opção `-C`) | inteiro maior que zero | `8` |

---

<a name="painel"></a>

## 🖥️ Painel web

| Variável | Para que serve | Valores | Padrão |
|---|---|---|---|
| `PAINEL_BIND_IP` | IP do **host** onde o nginx publica o painel | IP privado do host; `0.0.0.0` é sempre recusado; IP público, só com `REDE_PERMITIR_IP_PUBLICO=sim` | `127.0.0.1` |
| `PAINEL_PORT` | Porta HTTPS do painel publicada no host pelo nginx (mapeada para `8443` no container do nginx) | `1` a `65535` | `8443` |
| `PAINEL_REDES_PERMITIDAS` | Redes de onde o painel aceita cliente. Quem está fora recebe `403` do nginx, antes de chegar ao painel; o painel confere de novo | Lista de redes **privadas** separadas por vírgula, em notação CIDR; rede pública (de `/8` a `/32`), só com `REDE_PERMITIR_IP_PUBLICO=sim` | `127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16` |
| `PAINEL_ADMIN_USER` | Nome do primeiro administrador do painel, criado na primeira subida com a senha inicial de `.secrets/`. Só vale enquanto não existe nenhum administrador: depois, nome, senha e os outros administradores são alterados na aba Administradores | Letras minúsculas, números, `_` e `-`; começa com letra ou `_`; até 32 caracteres | `admin` |
| `PAINEL_SESSAO_MINUTOS` | Minutos sem uso até a sessão encerrar (o teto de 8 horas não muda) | `1` a `120` | `15` |
| `PAINEL_ACESSO_USUARIOS_FTP` | Entrada dos usuários do FTP no painel. Com `sim`, cada usuário do FTP entra com o nome e a senha do FTP e só navega e baixa na própria pasta, sem nenhuma tela de administração; com `nao`, só administrador entra. Quem confere a senha é o servidor FTP, pela rede interna da stack: [Usuário do FTP no painel](painel.md#usuario-ftp) | `sim` ou `nao` | `sim` |
| `PAINEL_CERT_CN` | Nome interno ou IP privado a mais no certificado autoassinado do painel | Nome em minúsculas ou IP **privado** (IP público, só com `REDE_PERMITIR_IP_PUBLICO=sim`); vazio para nenhum | vazio |
| `PAINEL_MEMORY_LIMIT` | `mem_limit` do painel | exemplo: `192M` | `192M` |
| `PAINEL_CPU_LIMIT` | `cpus` do painel | exemplo: `0.5` | `0.5` |
| `PAINEL_PIDS_LIMIT` | `pids_limit` do painel | inteiro | `64` |
| `NGINX_MEMORY_LIMIT` | `mem_limit` do nginx | exemplo: `64M` | `64M` |
| `NGINX_CPU_LIMIT` | `cpus` do nginx | exemplo: `0.5` | `0.5` |
| `NGINX_PIDS_LIMIT` | `pids_limit` do nginx | inteiro | `32` |

> 🧱 **Rede privada:** por padrão o painel é só para rede interna, atrás de firewall. `PAINEL_BIND_IP`, cada rede de `PAINEL_REDES_PERMITIDAS` e um `PAINEL_CERT_CN` em forma de IP têm de ser privados: o [`deploy.sh`](../deploy.sh) e os containers do painel e do nginx param com `não é IP privado` ou `não é rede privada` para qualquer outro valor. Endereço e rede públicos só passam com a opção [`REDE_PERMITIR_IP_PUBLICO`](#rede-permitir-ip-publico).

A senha do painel **não** é variável: a inicial fica em `.secrets/`, e a de cada administrador, só como hash, em `DATA_DIR/painel/administradores`. O `deploy.sh` e o container recusam `PAINEL_PASSWORD` e `PAINEL_PASSWORD_HASH`, e param com `PAINEL_ADMIN_USER inválido` para um nome fora da regra. Veja [Segredos](segredos.md#senha-do-painel) e [Administradores do painel](painel.md#administradores).

O navegador nunca fala direto com o painel: só o nginx publica porta, e ele repassa o pedido ao painel por um soquete dentro de `DATA_DIR/nginx`. O limite de pedidos por endereço e o tamanho máximo do pedido são fixos na configuração do nginx ([`nginx/nginx.conf.modelo`](../nginx/nginx.conf.modelo)), sem variável. Os perfis de [`profiles/`](../profiles/) não mexem nas variáveis do painel nem nas do nginx.

---

<a name="contato-de-seguranca"></a>

## 📮 Contato de segurança

| Variável | Para que serve | Valores | Padrão |
|---|---|---|---|
| `SEGURANCA_CONTATO_EMAIL` | E-mail para onde quem achar uma falha de segurança nesta instalação deve escrever. Preenchido, o painel publica o endereço em `/.well-known/security.txt`, sem pedir senha, para as redes de `PAINEL_REDES_PERMITIDAS` | Um endereço de e-mail só, sem `mailto:`; vazio para não publicar | vazio |

O arquivo segue a RFC 9116: é onde um pesquisador, ou a ferramenta de varredura da própria empresa, procura para quem avisar. Use uma caixa lida por mais de uma pessoa, como `seguranca@suaempresa.com.br`: o endereço fica à vista de quem alcança o painel.

1. No `.env`, preencha a variável:

   ```bash
   SEGURANCA_CONTATO_EMAIL=seguranca@suaempresa.com.br
   ```

2. Reaplique:

   ```bash
   ./deploy.sh
   ```

3. Confira, de uma máquina das redes permitidas:

   ```bash
   curl -k https://<endereço do painel>:8443/.well-known/security.txt
   ```

**Resultado esperado:** três linhas, e a aba Segurança do painel com o item `Contato de segurança` marcado.

```text
Contact: mailto:seguranca@suaempresa.com.br
Expires: 2027-01-03T00:00:00Z
Preferred-Languages: pt-BR
```

Com a variável vazia, o mesmo endereço responde `404` com `contato de segurança não configurado`. Com `REDE_PERMITIR_IP_PUBLICO=sim`, a aba Segurança passa a cobrar o preenchimento.

<details>
<summary>Detalhe técnico — validade, validação e o que não é publicado</summary>

- **Validade sempre no futuro:** a linha `Expires` é calculada a cada pedido, 90 dias à frente, à meia-noite UTC. O arquivo não vence com o servidor no ar, e a RFC pede validade menor que um ano.
- **Sempre igual ao `.env`:** o texto sai da configuração em vigor, não de arquivo gravado. Esvaziar a variável e rodar o `deploy.sh` tira o arquivo do ar.
- **Validação em três pontos:** o [`deploy.sh`](../deploy.sh), o container do painel e o próprio painel recusam o valor que não é um endereço só: sem `@`, domínio sem ponto, dois endereços, espaço, `mailto:`, URL, `<`, `>`, `%`, quebra de linha, parte antes do `@` com mais de 64 caracteres ou endereço com mais de 254. A mensagem é `SEGURANCA_CONTATO_EMAIL inválido`.
- **Só o contato:** o arquivo não traz versão, nome da stack nem caminho. Não há linha `Canonical`, porque o endereço do painel muda de uma instalação para outra e o arquivo não é assinado.
- **Só esse endereço:** `/security.txt` na raiz, a lista de `/.well-known/` e qualquer outro nome dentro dela não existem; sem sessão, levam à tela de entrada.
- **De quem é o contato:** de quem opera esta instalação, não de quem desenvolveu a stack.

O que mais fica aberto sem senha, e por quê: [Segurança](seguranca.md#contato-de-seguranca).

</details>

---

<a name="limites-de-recurso-do-container"></a>

## 🧱 Limites de recurso do container

| Variável | Para que serve | Valores | Padrão |
|---|---|---|---|
| `FTP_MEMORY_LIMIT` | `mem_limit` do serviço | exemplo: `256M`, `512M` | `256M` |
| `FTP_CPU_LIMIT` | `cpus` do serviço | exemplo: `0.5`, `1.0`, `2` | `1.0` |
| `FTP_PIDS_LIMIT` | `pids_limit` (barreira contra _fork bomb_) | inteiro | `128` |
| `FTP_NOFILE` | `ulimit nofile` (soft igual a hard) | inteiro | `16384` |
| `FTP_PROFILE` | Nome do perfil em uso. Só informa: quem grava é o `./deploy.sh --size` | `small`, `medium`, `large`, `xlarge`, `extended` | `small` |

> Estes campos, mais `FTP_MAX_CLIENTS*` e a faixa passiva, são o que o `./deploy.sh --size <perfil>` grava a partir de [`profiles/`](../profiles/). Prefira `./deploy.sh --size medium` a editar os valores à mão: veja [Perfis](perfis.md). O `deploy.sh` confere se o servidor tem as CPUs e a memória que `FTP_CPU_LIMIT` e `FTP_MEMORY_LIMIT` pedem e recusa o que não cabe.

---

<a name="rede-docker-sub-rede"></a>

## 🌐 Rede Docker (sub-rede)

A rede Docker desta stack tem sub-rede fixa, trocável por uma variável no `.env`. Use quando a faixa colidir com a LAN ou a VPN do cliente.

| Variável | Rede | Containers | Padrão | Exemplo |
|---|---|---|---|---|
| `FTP_SUBNET` | `ftp` (`allsafe-ftp-network`) | `allsafe-ftp`, `allsafe-ftp-painel` e `allsafe-ftp-nginx` | `172.29.1.0/29` | `FTP_SUBNET=10.250.1.0/29` |

Numa instalação que já está rodando, a sub-rede nova só vale depois de recriar a rede (os volumes e os dados não são afetados):

```bash
./deploy.sh --remover      # derruba os containers e a rede; os dados ficam
./deploy.sh                # sobe de novo, com a rede nova
```

**Resultado esperado:** `docker network inspect allsafe-ftp-network` mostra a sub-rede nova.

> O perfil em uso está gravado no `.env`: o `deploy.sh` sem `--size` e o `docker compose up -d` aplicam os mesmos limites.

<details>
<summary>Detalhe técnico — o bloco de endereços das stacks AllSafe</summary>

As stacks AllSafe reservam `172.29.1.0/24` para redes `/29` e `172.29.2.0/24` para redes `/28` e `/27`. Esta stack usa a primeira `/29` do bloco. O valor entra no [`compose.yaml`](../compose.yaml) como `subnet: ${FTP_SUBNET:-172.29.1.0/29}`.

</details>

---

⬅️ [Instalação](instalacao.md) · 🏠 [Documentação](README.md) · ➡️ [Perfis](perfis.md)
