# ⌨️ Scripts — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [Índice da documentação](README.md)

## 💡 Em poucas palavras

Os scripts da stack são de dois tipos. Os que você roda no host sobem o servidor, cuidam dos usuários, recuperam o acesso ao painel, fazem e restauram a cópia de segurança e conferem se está tudo certo. Os demais ficam dentro dos containers do FTP, do painel e do nginx e são chamados sozinhos; você não os executa direto.

<!-- diagrama: diagramas/scripts-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    usuario@{ shape: person, label: "Usuário" }
    host@{ shape: console, label: "deploy.sh, manage-user.sh<br>e validate.sh, no host" }
    compose@{ shape: rect, label: "Docker Compose" }
    interno@{ shape: console, label: "entrypoints e allsafe-ftp-user<br>dentro dos containers" }
    ftp@{ shape: rect, label: "Pure-FTPd<br>allsafe-ftp" }
    fim@{ shape: stadium, label: "serviço operando" }

    usuario --> host --> compose --> interno --> ftp --> fim
```

<sub>Nível 1 · Diagrama · [fonte](diagramas/)</sub>

**Sequência:** Usuário ➜ scripts do host (`deploy.sh`, `manage-user.sh`, `validate.sh`) ➜ Docker Compose ➜ entrypoints e `allsafe-ftp-user` (nos containers) ➜ Pure-FTPd (`allsafe-ftp`) ➜ serviço operando

---

<details>
<summary>Sumário — clique para expandir</summary>

[Visão geral](#visao-geral) · [`deploy.sh`](#deploy) · [`manage-user.sh`](#manage-user) · [`scripts/painel-senha.sh`](#painel-senha) · [`scripts/backup.sh`](#backup) · [`scripts/restaurar.sh`](#restaurar) · [`scripts/validate.sh`](#validate) · [`scripts/gerar-marca.sh`](#gerar-marca) · [`tests/testar.sh`](#testar) · [`ftp/entrypoint.sh`](#entrypoint) · [`ftp/saude.sh`](#ftp-saude) · [`ftp/porteiro-tls.sh`](#porteiro-tls) · [`painel/entrypoint.sh`](#painel-entrypoint) · [`nginx/entrypoint.sh`](#nginx-entrypoint) · [`nginx/saude.sh`](#nginx-saude) · [`ftp/usuario.sh`](#ftp-user) · [Scripts de apoio](#apoio)

</details>

---

<a name="visao-geral"></a>

## 📋 Visão geral

| Script | Onde roda | Para que serve |
|---|---|---|
| [`deploy.sh`](../deploy.sh) | host | Instala, reaplica, atualiza ou remove a stack em um comando, sem perguntas |
| [`manage-user.sh`](../manage-user.sh) | host | Atalho para criar, trocar senha, remover e listar usuários FTP, e para dispensar um usuário do TLS |
| [`scripts/painel-senha.sh`](../scripts/painel-senha.sh) | host | Recupera o acesso ao painel: define a senha de um administrador ou cria o administrador, gravando só o hash |
| [`scripts/backup.sh`](../scripts/backup.sh) | host | Grava a cópia de segurança de `dados/`, `auth/`, `certs/` e `painel/` em `BACKUP_DIR` |
| [`scripts/restaurar.sh`](../scripts/restaurar.sh) | host | Devolve a stack ao estado de uma cópia, guardando antes o estado atual |
| [`scripts/validate.sh`](../scripts/validate.sh) | host | Checagem de sintaxe, da marca, do Compose de todos os perfis e, opcionalmente, dos três serviços no ar |
| [`scripts/gerar-marca.sh`](../scripts/gerar-marca.sh) | computador de quem troca a logo | Gera os seis arquivos de logo e ícone do painel a partir das duas artes de origem |
| [`tests/testar.sh`](../tests/testar.sh) | host | Bateria de testes funcional, de segurança e de rede, em instância de teste que o próprio script cria e remove |
| [`ftp/entrypoint.sh`](../ftp/entrypoint.sh) | container | Provisiona o usuário inicial e o certificado e executa o `pure-ftpd` |
| [`ftp/saude.sh`](../ftp/saude.sh) | container | Healthcheck: abre a porta de controle e espera a saudação do servidor |
| [`ftp/porteiro-tls.sh`](../ftp/porteiro-tls.sh) | container | Com `FTP_TLS_EXCECOES=sim`, decide a cada entrada se a sessão sem TLS pode seguir para a conferência da senha |
| [`painel/entrypoint.sh`](../painel/entrypoint.sh) | container do painel | Confere a rede privada, gera o certificado do painel, entrega a cópia dele ao nginx e executa o painel |
| [`nginx/entrypoint.sh`](../nginx/entrypoint.sh) | container do nginx | Confere a rede privada, gera a configuração do nginx e o executa, sem root |
| [`nginx/saude.sh`](../nginx/saude.sh) | container do nginx | Healthcheck: pede `/saude` ao painel passando pelo nginx |
| [`ftp/usuario.sh`](../ftp/usuario.sh) | containers do FTP e do painel | Gestão de usuários no PureDB e da lista de quem entra sem TLS, chamada pelo `manage-user.sh` e pelo painel |
| [`scripts/rede-privada.sh`](../scripts/rede-privada.sh) | host e containers | Funções que conferem se um IP ou uma rede é privado e que tratam a opção de IP público; carregado pelos outros scripts |
| [`scripts/ambiente.sh`](../scripts/ambiente.sh) | host | Função que lê uma chave do `.env` sem executar o arquivo; carregado pelos outros scripts |

A pasta [`scripts/`](../scripts/) tem o que roda fora dos containers: no servidor e, no caso do `gerar-marca.sh`, no computador de quem troca a logo. O que roda em container fica na pasta do serviço ([`ftp/`](../ftp/), [`painel/`](../painel/) e [`nginx/`](../nginx/)) e é copiado para a imagem pelo [`Dockerfile`](../Dockerfile). A bateria de testes fica em [`tests/`](../tests/).

---

<a name="deploy"></a>

## 🚀 `deploy.sh`

```bash
./deploy.sh [--size small|medium|large|xlarge|extended] [--atualizar] [--check-only]
./deploy.sh --remover [--apagar-dados [--sim]]
```

| Parâmetro | Efeito |
|---|---|
| sem opção | Instala ou reaplica: cria o `.env`, as pastas e as senhas que faltarem, sobe os containers e espera ficarem `healthy` |
| `--size` | Grava no `.env` os limites de `profiles/<perfil>.env` e o nome em `FTP_PROFILE`, depois de conferir que o servidor aguenta o perfil. Sem a opção, o `.env` fica como está |
| `--atualizar` | Reconstrói as três imagens sem cache, com os pacotes atuais do Debian, e recria os containers |
| `--check-only` | Só valida o perfil, os endereços e as redes, os recursos do servidor e o Compose; não cria nem sobe nada |
| `--remover` | Derruba os containers e a rede; dados, segredos, `.env` e imagens ficam |
| `--apagar-dados` | Com `--remover`: apaga também `dados/`, `auth/`, `certs/`, `painel/` e `nginx/` de `DATA_DIR`, depois de pedir para digitar `apagar` |
| `--sim` | Com `--apagar-dados`: dispensa a confirmação (obrigatório quando não há terminal) |
| `-h`, `--help` | Mostra o uso |

**Resultado esperado:** o comando só termina com `allsafe-ftp`, `allsafe-ftp-painel` e `allsafe-ftp-nginx` em `healthy` e fecha com `Pronto: FTP, painel e nginx no ar (healthy), perfil '<perfil>'.`, os endereços do FTP e do painel, o modo de TLS do FTP e o arquivo onde está cada senha (a senha em si nunca aparece). Com `FTP_TLS_MODE` em `0` ou `1`, a última coisa na tela é o `AVISO` de FTP sem criptografia: [Segurança](seguranca.md#ftp-sem-tls). Com `FTP_TLS_EXCECOES=sim`, a linha do FTP termina em `com exceção por usuário` e o `AVISO` é o da exceção: [Segurança](seguranca.md#tls-por-usuario). Com `--remover`: `Removidos os containers e a rede. Os dados continuam em <DATA_DIR>.` Com `--check-only`: `OK: perfil '<perfil>', rede privada, recursos do servidor e compose validados; nada foi alterado.` Com `REDE_PERMITIR_IP_PUBLICO=sim`, o resumo traz `endereço público aceito` no lugar de `rede privada` e a última coisa na tela é o `ALERTA` de endereço público: [Segurança](seguranca.md#ip-publico).

<details>
<summary>Detalhe técnico — comportamento e códigos de saída</summary>

- **Não faz pergunta.** A única confirmação é a do `--apagar-dados`, dispensada com `--sim`.
- **Requisitos conferidos antes de agir:** `docker`, o plugin `docker compose`, o serviço do Docker respondendo e as portas livres (a do FTP, a do painel e a faixa passiva, no endereço de bind). As portas que a própria stack já publica não contam. Falhou: `ERRO: ...` e código `1`, sem subir nada.
- **Recursos do servidor conferidos antes de gravar:** se o servidor tem menos CPUs que `FTP_CPU_LIMIT` ou menos memória que `FTP_MEMORY_LIMIT`, para com `ERRO: o perfil '<perfil>' pede ... e este servidor tem ...` e código `1`, sem criar nem regravar o `.env` e sem tocar nos containers: [Perfis](perfis.md#o-servidor-aguenta).
- **`FTP_TLS_MODE` conferido antes de agir:** valor fora de `0` a `3` para com `ERRO: FTP_TLS_MODE deve ser 0 (sem TLS), 1 (opcional), 2 (obrigatório no login) ou 3 (obrigatório no login e nos dados)` e código `1`. Em `0` e `1` o deploy segue e avisa no fim.
- **`FTP_TLS_EXCECOES` conferida antes de agir:** valor fora de `nao` e de `sim` para com `ERRO: FTP_TLS_EXCECOES deve ser 'sim' ou 'nao'`; `sim` com outro modo de TLS, com `ERRO: FTP_TLS_EXCECOES=sim exige FTP_TLS_MODE=2`; `sim` com a opção de IP público, com `ERRO: FTP_TLS_EXCECOES=sim não combina com REDE_PERMITIR_IP_PUBLICO=sim`. Sempre com código `1`. Com `sim` válido, o deploy segue e avisa no fim, também no `--check-only`.
- Na primeira execução sem `.env`, copia o [`.env.example`](../.env.example), aplica `0600`, avisa `Criado .env a partir do .env.example: tudo em 127.0.0.1, só este servidor acessa.` e **segue**. Com `--check-only` nada é criado: a validação usa o `.env.example`.
- **Idempotente:** rodado de novo sem mudança, não recria container, não troca senha e não regrava o `.env`.
- **Converte os nomes antigos, a variável:** em `.env` de instalação anterior à `0.9.0`, troca `FTP_PUBLIC_IP` por `FTP_PASSIVE_IP`, no mesmo ponto do arquivo e com o mesmo valor, depois de copiar o `.env` para `BACKUP_DIR/<data>-antes-da-migracao-de-nomes/env` (`0600`), e avisa `Convertido: FTP_PUBLIC_IP virou FTP_PASSIVE_IP`. A troca do nome, sozinha, não recria container; na atualização a partir de uma versão anterior, os três são recriados uma vez, porque as imagens mudam, e usuários, senhas e arquivos ficam como estavam. Com `--check-only`, só avisa `AVISO: esta instalação usa nomes antigos` e não altera nada.
- **Converte os nomes antigos, os segredos:** em instalação feita até a `0.9.0`, dá o nome novo aos três arquivos de `.secrets/` com `mv`, sem ler nem copiar o conteúdo, e avisa `Convertido: <antigo> virou <novo>.` para cada um. Se o antigo e o novo existirem, vale o novo e sai um `AVISO`. Com `--check-only`, só avisa. Tabela dos nomes: [Segredos](segredos.md#nomes-antigos).
- Se `.secrets/ftp-usuario-inicial-senha.txt` estiver vazio ou ausente, gera uma senha forte (`0600`): veja [Segredos](segredos.md).
- Grava o `.secrets/LEIAME.txt` (`0600`), que diz para que serve cada arquivo da pasta e não guarda segredo, e fecha o resumo com `Segredos: .../LEIAME.txt diz para que serve cada arquivo.`
- Recusa `FTP_PASSWORD`, `PAINEL_PASSWORD` e `PAINEL_PASSWORD_HASH` no `.env` e, por padrão, qualquer `FTP_BIND_IP`, `FTP_PASSIVE_IP`, `PAINEL_BIND_IP`, `PAINEL_REDES_PERMITIDAS` ou `PAINEL_CERT_CN` (em forma de IP) fora de rede privada.
- **Opção de IP público:** `REDE_PERMITIR_IP_PUBLICO` diferente de `nao` e de `sim` para com `FALHA: REDE_PERMITIR_IP_PUBLICO deve ser 'nao' ou 'sim'` e código `1`. Com `sim`, aceita IPv4 público de servidor e rede de `/8` a `/32`, continua recusando `0.0.0.0` e rede mais larga, exige `FTP_TLS_MODE` em `2` ou `3` (`ERRO: REDE_PERMITIR_IP_PUBLICO=sim exige FTP_TLS_MODE=2 ou 3`) e mostra o `ALERTA` ao final, também no `--check-only`.
- Se `.secrets/painel-admin-inicial-senha-hash.txt` não existir, gera a senha inicial do painel em `.secrets/painel-admin-inicial-senha.txt` (`0600`) e grava o hash dela, chamando o `scripts/painel-senha.sh --inicial` depois de construir a imagem.
- Confere a `PAINEL_ACESSO_USUARIOS_FTP` antes de agir: valor diferente de `sim` e de `nao` para com `ERRO: PAINEL_ACESSO_USUARIOS_FTP deve ser 'sim' ou 'nao'; ...` e código `1`.
- Confere o `PAINEL_ADMIN_USER` antes de agir: nome fora da regra para com `ERRO: PAINEL_ADMIN_USER inválido em .env: ...` e código `1`. No resumo, mostra o usuário e o arquivo da senha inicial enquanto esse arquivo existir; depois, `usuário e senha: os definidos na aba Administradores ou com ./scripts/painel-senha.sh`.
- Opção desconhecida ou perfil inexistente: mensagem `Opção inválida: ...` ou `ERRO: perfil inexistente: ...` e código `64`.
- O Compose é sempre chamado só com `--env-file .env`. O perfil não é um segundo arquivo na subida: `--size` grava os valores dele no `.env`, por isso um `docker compose up -d` direto mantém os mesmos limites.
- Combinação inválida (`--remover` com `--size`, `--apagar-dados` sem `--remover`, `--sim` sem `--apagar-dados`): `Opção inválida: ...`, o uso e código `64`.
- `--apagar-dados` apaga as pastas por um container descartável sem rede (os arquivos pertencem ao usuário do container, não ao do host) e só aceita `DATA_DIR` com pelo menos dois níveis de pasta.
- Constrói as três imagens com `docker compose build` (`build --no-cache` com `--atualizar`), sobe com `docker compose up -d --wait` e termina mostrando o `docker compose ps` e o resumo. O prazo da espera é de 180 s mais um quarto de segundo por porta passiva (192 s no `small`, 580 s no `extended`), porque o Docker publica as portas uma a uma; acima de 400 portas, avisa `Publicando <n> portas passivas: a subida pode levar alguns minutos.` Se algum container não ficar `healthy` no prazo: `ERRO: os containers não ficaram healthy. Veja o motivo com: docker compose logs --tail 50 ftp painel nginx`.

</details>

---

<a name="manage-user"></a>

## 👤 `manage-user.sh`

```bash
./manage-user.sh list                 # lista os usuários do PureDB
./manage-user.sh add backup-olt       # pede a senha (mínimo de 12 caracteres) sem ecoar
./manage-user.sh add olt01 clientes/olt-01   # o mesmo, com a pasta escolhida dentro de /data
./manage-user.sh passwd backup-olt    # troca a senha
./manage-user.sh del backup-olt       # remove o usuário (os arquivos ficam em /data)
./manage-user.sh tls-dispensar olt-antiga   # deixa o usuário entrar sem TLS (só vale com FTP_TLS_EXCECOES=sim)
./manage-user.sh tls-exigir olt-antiga      # volta a exigir o TLS do usuário
./manage-user.sh tls-lista                  # lista os usuários dispensados do TLS
```

**Resultado esperado:** `add` e `passwd` terminam sem erro e o usuário aparece no `list`; `del` responde `Usuario removido; os dados em /data/<pasta> foram preservados.`, com a pasta real do usuário. O `add` com uma pasta que outro usuário já alcança termina sem erro e mostra uma linha `Aviso:` por usuário. `tls-dispensar` responde `Usuario <nome> dispensado do TLS: vale na proxima entrada, com FTP_TLS_EXCECOES=sim.` e `tls-exigir`, `Usuario <nome> volta a ser obrigado a usar TLS: vale na proxima entrada.`; `tls-lista` mostra um nome por linha, ou nada.

A senha é lida do terminal e enviada pelo `stdin` para o container: não aparece na linha de comando nem no histórico. O script opera a instalação do `.env` desta pasta; para operar outra, aponte o arquivo dela: `ENV_FILE=<arquivo> ./manage-user.sh list`. Regras e casos de uso em [Operação](operacao.md#usuarios).

---

<a name="painel-senha"></a>

## 🔑 `scripts/painel-senha.sh`

Recupera o acesso ao painel pelo host. No dia a dia, usuário e senha são trocados no próprio painel, na aba Administradores.

```bash
./scripts/painel-senha.sh                           # pergunta a senha nova duas vezes, sem ecoar
./scripts/painel-senha.sh --gerar                   # cria uma senha forte e mostra uma única vez
./scripts/painel-senha.sh --usuario NOME --gerar    # outro administrador; se NOME não existe, é criado
```

**Resultado esperado:** `Administrador admin com a senha trocada; painel reiniciado e sessões abertas encerradas.` Para um nome novo, `Administrador NOME criado; ...`.

Sem `--usuario`, o administrador é o de `PAINEL_ADMIN_USER`. A senha tem de ter no mínimo 12 caracteres e só o hash é gravado. Quando usar: [Painel web](painel.md#senha).

<details>
<summary>Detalhe técnico — como o hash é calculado e gravado</summary>

- Lê `SECRETS_DIR`, `DATA_DIR`, `PAINEL_IMAGE` e `PAINEL_ADMIN_USER` do `.env` (ou do arquivo em `ENV_FILE`), sem executar o arquivo.
- A senha também pode vir pela entrada padrão: `./scripts/painel-senha.sh < arquivo`.
- O hash `scrypt` é calculado **dentro da imagem do painel**, em um container descartável sem rede, com a raiz somente leitura e sem capabilities (`docker run --rm -i --network none --read-only --cap-drop ALL`). O host não precisa de Python.
- Quem grava o arquivo de administradores é o painel: o script entrega o hash pela entrada padrão a `servidor.py --administrador NOME`, no container que está no ar (`docker compose exec`) ou, com o painel parado, em um container de uso único, sem os outros serviços (`docker compose run --rm --no-deps`). A alteração fica na auditoria como `admin_definido_no_host`.
- Com o painel no ar, reinicia o serviço `painel` (encerra todas as sessões e zera o bloqueio por tentativas). Com o painel parado, fecha com `...; vale na próxima subida do painel.`
- Quando o administrador é o de `PAINEL_ADMIN_USER`, regrava também o hash de `.secrets/painel-admin-inicial-senha-hash.txt`, por cima do mesmo arquivo, e apaga o `.secrets/painel-admin-inicial-senha.txt`. Para outro administrador, a pasta `.secrets/` não é tocada.
- `--inicial` é de uso do `deploy.sh`: grava só o hash da senha inicial, antes da primeira subida, não reinicia nada e mantém o `painel-admin-inicial-senha.txt`.
- Nome fora da regra: `ERRO: nome de administrador inválido: ...`, código `1`. Opção desconhecida: código `64`. Falta do `.env`, da imagem ou da instalação: `ERRO: ... rode ./deploy.sh primeiro`, código `1`.

</details>

---

<a name="backup"></a>

## ♻️ `scripts/backup.sh`

```bash
./scripts/backup.sh                    # grava a cópia de dados/, auth/, certs/ e painel/ em BACKUP_DIR
./scripts/backup.sh --rotulo <texto>   # o mesmo, com o texto no nome do arquivo
./scripts/backup.sh --listar           # mostra as cópias que existem
```

**Resultado esperado:** `Cópia gravada: <BACKUP_DIR>/<STACK_NAME>-AAAAMMDD-HHMMSS.tar.gz (<tamanho>, <n> itens)`, o lembrete de que o `.env` e os segredos ficam fora da cópia e o comando para restaurá-la.

A stack pode ficar no ar. A cópia sai com modo `0600` e com a soma `.sha256` ao lado; a leitura é feita por um container sem rede, com `DATA_DIR` só para leitura. Uso, conteúdo da cópia e códigos de saída: [Backup e restauração](backup.md#fazer).

---

<a name="restaurar"></a>

## 🔁 `scripts/restaurar.sh`

```bash
./scripts/restaurar.sh <cópia>          # pede para digitar 'restaurar'
./scripts/restaurar.sh <cópia> --sim    # sem pergunta (obrigatório quando não há terminal)
./scripts/restaurar.sh --listar         # mostra as cópias que existem
```

**Resultado esperado:** `Restaurado e no ar (healthy).` e, na última linha, o comando para desfazer.

Confere a cópia antes de alterar qualquer coisa, para a stack, guarda o estado atual em um arquivo com `antes-da-restauracao` no nome, troca o conteúdo e sobe de novo. `<cópia>` é o nome de um arquivo de `BACKUP_DIR` ou um caminho. Passos, recusas e códigos de saída: [Backup e restauração](backup.md#restaurar).

---

<a name="validate"></a>

## 🧪 `scripts/validate.sh`

```bash
./scripts/validate.sh            # sintaxe dos scripts, .env.example comentado, marca e compose config de todos os perfis
./scripts/validate.sh --runtime  # também exige os três serviços running e healthy e o usuário no PureDB
```

**Resultado esperado:** `painel OK: <n> módulos Python`, `.env.example OK: <n> variáveis, todas comentadas e no guia de configuração`, `marca OK: 6 arquivos em web/marca/`, `compose OK com <perfil>.env` para cada perfil e, no fim, `Validacao FTP concluida.` Com `--runtime`, também `servico ftp: running, healthy`, o mesmo para `painel` e `nginx`, e `usuario inicial '<usuário>' presente no PureDB`. Qualquer falha encerra com código diferente de zero.

<details>
<summary>Detalhe técnico — o que cada modo confere</summary>

| Modo | Confere |
|---|---|
| sem parâmetro | `bash -n` em `deploy.sh`, `manage-user.sh` e nos scripts de `scripts/`, `ftp/`, `painel/`, `nginx/` e `tests/`; se o host tiver `python3`, a sintaxe de cada módulo de `painel/` e que todo nome usado em cada um está definido ou importado nele, sem importar nem gravar nada; no `.env.example`, que cada variável tem comentário na linha de cima e está em [Configuração](configuracao.md); em [`web/marca/`](../web/marca/), que os seis arquivos da marca existem e são PNG ou ICO; `docker compose config --quiet` com `.env.example` e cada arquivo de `profiles/` |
| `--runtime` | tudo acima, mais: os serviços `ftp`, `painel` e `nginx` em `running` e `healthy`, e `pure-pw show` do usuário inicial, lido de `FTP_USER` no `.env` |

O modo `--runtime` confere a instalação do `.env` desta pasta. Para conferir outra, aponte o arquivo dela: `ENV_FILE=<arquivo> ./scripts/validate.sh --runtime`. Sem o arquivo, o script para com `ERRO: ... não há instalação para conferir.`

</details>

---

<a name="gerar-marca"></a>

## 🎨 `scripts/gerar-marca.sh`

Gera, em [`web/marca/`](../web/marca/), os seis arquivos de logo e ícone que o painel usa, a partir das duas artes de [`web/marca/fonte/`](../web/marca/fonte/). Só roda quando a logo muda: os arquivos gerados ficam no repositório e a instalação não usa este script. O passo a passo da troca está em [Painel web](painel.md#marca).

```bash
./scripts/gerar-marca.sh                        # placa branca atrás da arte
MARCA_PLACA='#f0f3f6' ./scripts/gerar-marca.sh  # outra cor de placa, no formato #rrggbb
```

**Resultado esperado:** uma linha por arquivo, com o tamanho em bytes, e, no fim, `Marca gerada em web/marca/. Rode ./deploy.sh para o painel passar a usar.` Rodar de novo com as mesmas artes gera arquivos idênticos.

<details>
<summary>Detalhe técnico — o que é gerado</summary>

| Arquivo | Lado | Arte de origem | Onde o painel usa |
|---|---|---|---|
| `favicon.ico` | 16, 32 e 48 pixels no mesmo arquivo | `allsafe-simbolo-512.png` | Ícone da aba do navegador |
| `icone-32.png` | 32 pixels | `allsafe-simbolo-512.png` | Ícone da aba do navegador |
| `icone-192.png` | 192 pixels | `allsafe-simbolo-512.png` | Ícone em tela de alta densidade e em atalho |
| `apple-touch-icon.png` | 180 pixels | `allsafe-simbolo-512.png` | Atalho na tela inicial do celular |
| `simbolo-64.png` | 64 pixels | `allsafe-simbolo-512.png` | Símbolo no topo de todas as telas |
| `logo-320.png` | 320 pixels | `allsafe-logo-2048.png` | Logo da tela de entrada |

- **Placa clara:** a arte é escura em fundo transparente e o painel tem fundo escuro. Cada arquivo sai com a arte, nas cores originais, sobre uma placa de cantos arredondados, que aparece igual em aba clara ou escura do navegador. `MARCA_PLACA` troca a cor da placa; o padrão é `#ffffff`.
- **Como monta:** a arte é recortada na borda, centralizada na placa com 10% de margem, montada em 1024 pixels e reduzida ao tamanho final. Os arquivos saem com 128 cores em 8 bits, sem metadado nem data: os seis somam 22 KB.
- **Artes de origem:** não são alteradas, e não entram na imagem do nginx ([`.dockerignore`](../.dockerignore)).
- **Dependência:** ImageMagick 7 (comando `magick`), só no computador de quem troca a logo. O servidor não precisa dele.
- **Recusas:** `ERRO: o ImageMagick 7 (comando magick) não está instalado neste computador.`, `ERRO: faltam as fontes ...` e `ERRO: MARCA_PLACA aceita só cor no formato #rrggbb.`

</details>

---

<a name="testar"></a>

## 🧪 `tests/testar.sh`

Roda a bateria de testes da stack: funcional, de segurança e de rede. O script sobe uma instância de teste separada, testa, grava os resultados e remove tudo o que criou. A instalação desta pasta não é tocada e pode estar no ar ou não.

```bash
./tests/testar.sh                        # sobe a instância de teste, testa, grava os resultados e remove
./tests/testar.sh --resultados <pasta>   # grava os resultados em outra pasta
./tests/testar.sh --manter               # deixa a instância de teste no ar para investigar
./tests/testar.sh --limpar               # só remove a instância de teste e a pasta dela
```

**Resultado esperado:** uma linha por caso, com `✅` ou `❌`, o resumo de cada bateria com o caminho do arquivo de resultado e, no fim, `Bateria aprovada: nenhum desvio.` A execução leva perto de cinco minutos.

> ⚠️ A instância de teste só sobe em IP privado: `TESTE_IP` fora das faixas privadas é recusado antes de qualquer container subir. A opção de IP público é testada com endereços de documentação (`203.0.113.0/24` e `198.51.100.0/24`), sem publicar porta fora do IP de teste.

| Saída | Significado |
|---|---|
| `0` | todos os casos passaram |
| `1` | algum caso teve desvio; o arquivo de resultado diz qual e mostra a evidência |
| `2` | uso errado ou requisito ausente no host |
| `3` | um segredo apareceu em um arquivo de resultado; o arquivo é apagado |

<details>
<summary>Detalhe técnico — a instância de teste, as variáveis e o que cada bateria cobre</summary>

**Requisitos no host:** `docker` com o plugin Compose, `curl` com suporte a FTPS, `openssl`, `ss`, `tar` e `sha256sum`. O caso que confere os segredos fora do Git só roda se a pasta for um repositório Git.

**A instância de teste** usa nomes, portas, sub-rede, dados e segredos próprios:

| Item | Instância de teste | Variável para trocar |
|---|---|---|
| Containers e imagens | `allsafe-ftp-teste`, `allsafe-ftp-teste-painel`, `allsafe-ftp-teste-nginx` | — |
| Endereço | `127.0.0.2` | `TESTE_IP` |
| Porta do FTP | `2121` | `TESTE_FTP_PORT` |
| Porta do painel | `8444` | `TESTE_PAINEL_PORT` |
| Faixa passiva | `32000` a `32019` | `TESTE_PASSIVA_INICIO` |
| Sub-rede Docker | `172.29.2.0/29` | `TESTE_SUBNET` |
| Primeiro administrador do painel | `gestor`, de propósito diferente do padrão | `TESTE_ADMIN` |
| Segunda instância, usada no caso das duas instâncias no mesmo host | `allsafe-ftp-teste-b`, portas seguintes, `172.29.3.0/29` | `TESTE_SUBNET_B` |
| Pasta de trabalho, dados, segredos e cópias de segurança | `TEMP_DIR/testar` | `TEMP_DIR` |

As senhas da instância de teste são geradas na hora, ficam só em `TEMP_DIR/testar` e somem com ela. O script recusa rodar se `TEMP_DIR/testar` já existir e não tiver sido criada por ele, e se o `.env` desta pasta usar `STACK_NAME=allsafe-ftp-teste`.

**O que cada bateria cobre:**

| Bateria | Casos | Exemplos |
|---|---|---|
| Funcional | 34 | instalação em um comando, login por FTPS, envio e download com comparação, ciclo de usuário pelo terminal e pelo painel, reinício sem perda, healthcheck do FTP, backup e restauração, arquivos estáticos entregues pelo nginx, conversão dos nomes antigos pelo `deploy.sh`, administradores pelo painel, recuperação do acesso pelo host, download pelo painel (arquivo pequeno, subpasta, nome com acento e arquivo de 40 MiB, com a soma conferida), pasta criada pelo painel, usuário com pasta escolhida e pasta dividida entre usuários, usuário do FTP que entra no painel e baixa os próprios arquivos, sessão dele acompanhando o cadastro e a variável que desliga a entrada, a entrada dele em cada modo de TLS, e o TLS por usuário: dispensa e volta pelo painel e pelo terminal, com o padrão desligado, e a marca: logo e ícone entregues pelo nginx e a autoria no rodapé de todas as telas |
| Segurança | 67 | login sem TLS e anônimo recusados, fuga do `chroot`, isolamento entre usuários, recusas do `deploy.sh` e dos containers a IP público, a opção de IP público (só com `sim`, "todos" sempre recusado, TLS obrigatório, valor inválido, alerta em execução), CSRF, `Origin` de fora e `Origin: null`, `Host` de fora, limite de tentativas, cabeçalhos, TLS antigo, nenhum segredo no `.env`, no Git, nos logs, na auditoria e no `LEIAME.txt` da pasta de segredos, entrada que não revela nomes de administrador, senha atual em toda alteração de administrador, sessões do administrador alterado encerradas, arquivo de administradores só com hash, aba Arquivos sem sessão, fuga da pasta pela aba Arquivos, link simbólico não seguido, arquivo entregue só como anexo, limite de downloads ao mesmo tempo, criação de pasta sem sessão e sem token, nome de pasta que tenta sair da pasta dos dados, usuário preso à pasta escolhida, usuário do FTP sem alcance à administração do painel, preso à própria pasta no painel, entrada dele sem brecha (telas iguais na recusa, nome de administrador, servidor FTP parado, certificado trocado, bloqueio por tentativas), os limites de sessões e de downloads por usuário, e o TLS por usuário: sem TLS só entra quem foi dispensado, o FTP encerra se o `pure-authd` morre, as combinações recusadas na subida e quem pode alterar a lista, e a pasta da marca, que entrega só os seis arquivos, só para leitura |
| Rede | 13 | portas publicadas só no IP configurado, endereço anunciado no modo passivo, limite de sessões por IP, painel só em HTTPS, troca de perfil, duas instâncias no mesmo host, rede pública no painel só com a opção |

**Organização:** o [`tests/testar.sh`](../tests/testar.sh) prepara a instância de teste e carrega o [`tests/comum.sh`](../tests/comum.sh), com as funções de registro, de FTP, do painel e de gravação dos resultados. Os casos ficam em [`tests/etapas/`](../tests/etapas/), um arquivo por etapa, executados na ordem do nome: cada etapa parte do estado que a anterior deixou e não roda sozinha.

**Resultados:** três arquivos Markdown, um por bateria, com data, comando, versão, ambiente, a tabela dos casos com a evidência de cada um e os achados. Nenhuma senha, token, cookie ou hash é gravado: antes de terminar, o script procura nos três arquivos os segredos que usou e, se achar, apaga o arquivo e sai com `3`. Sem `--resultados`, eles vão para a pasta do plano, se ela existir, ou para `TEMP_DIR/resultados`.

**Limpeza:** ao terminar, ou ao ser interrompido, o script remove os containers, a rede, as imagens e a pasta da instância de teste. Com `--manter`, nada é removido até o `--limpar`.

</details>

---

<a name="entrypoint"></a>

## ⚙️ `ftp/entrypoint.sh`

Roda a cada início do container. Não tem parâmetros: tudo vem das variáveis de [Configuração](configuracao.md).

1. Confere que `FTP_BIND_IP` e `FTP_PASSIVE_IP` são IPs privados, ou públicos de servidor com `REDE_PERMITIR_IP_PUBLICO=sim` ([`rede-privada.sh`](../scripts/rede-privada.sh)), lê a senha do segredo `/run/secrets/ftp_usuario_inicial_senha`, ajusta dono e modo de `/data`, `/auth` e `/etc/ssl/private` e cria ou atualiza o usuário inicial `FTP_USER` (recusa senha com menos de 12 caracteres).
2. Gera um certificado autoassinado para `FTP_CERT_CN` se `DATA_DIR/certs` estiver vazia, e grava a parte pública dele em `/auth/ftp-cert.pem`.
3. Executa o `pure-ftpd` com o modo de TLS, o `chroot`, os limites e a faixa passiva do `.env`. Com `FTP_TLS_MODE` em `0` ou `1`, grava antes um `AVISO` no log.
4. Com `FTP_TLS_EXCECOES=sim`, sobe antes o `pure-authd`, que chama o [porteiro](#porteiro-tls) a cada entrada, e fica vigiando os dois processos: se um deles sair, encerra o container.

**Resultado esperado:** a linha `FTP pronto em 2121/tcp; TLS=2; passivo=30000-30049` no log do container; com a exceção por usuário, `FTP pronto em 2121/tcp; TLS=2 com exceção por usuário; passivo=30000-30049`.

<details>
<summary>Detalhe técnico — processo 1 e mensagens de falha</summary>

Com `init: true`, o processo 1 do container é o `tini`; o entrypoint é iniciado por ele e termina com `exec`, deixando o `pure-ftpd` no seu lugar. Com `FTP_TLS_EXCECOES=sim` não há `exec`: o entrypoint continua vivo, com o `pure-authd` e o `pure-ftpd` como filhos, repassa a eles o sinal de parada e, se um dos dois sair sozinho, encerra o outro e sai com código `1`.

Quando uma validação falha, o script sai com `FALHA: <motivo>`:

| Mensagem | Quando |
|---|---|
| `FALHA: segredo /run/secrets/ftp_usuario_inicial_senha ausente` | `.secrets/ftp-usuario-inicial-senha.txt` não existe: rode o `deploy.sh` |
| `FALHA: FTP_PASSWORD não é aceita` | há senha em variável de ambiente; ela só é lida do segredo |
| `FALHA: FTP_BIND_IP=… não é IP privado` (ou `FTP_PASSIVE_IP`) | o endereço está fora das faixas privadas e a opção de IP público está em `nao`; o container reinicia em laço até a correção |
| `FALHA: FTP_BIND_IP=… não é um endereço IPv4 de servidor` (ou `FTP_PASSIVE_IP`) | com a opção em `sim`, o valor é `0.0.0.0`, multicast ou reservado |
| `FALHA: REDE_PERMITIR_IP_PUBLICO deve ser 'nao' ou 'sim'` | a opção tem outro valor |
| `FALHA: REDE_PERMITIR_IP_PUBLICO=sim exige FTP_TLS_MODE=2 ou 3` | a opção está ligada com o TLS do FTP em `0` ou `1` |
| `FALHA: FTP_USER invalido` | o nome não segue `^[a-z_][a-z0-9_-]{0,31}$` |
| `FALHA: a senha FTP deve ter pelo menos 12 caracteres` | senha curta ou arquivo vazio |
| `FALHA: faixa passiva invalida` | início ou fim não numéricos |
| `FALHA: faixa passiva fora dos limites` | abaixo de `1024`, acima de `65535` ou invertida |
| `FALHA: FTP_TLS_MODE deve ser 0, 1, 2 ou 3` | valor fora da lista |
| `FALHA: FTP_TLS_EXCECOES deve ser 'nao' ou 'sim'` | a exceção por usuário tem outro valor |
| `FALHA: FTP_TLS_EXCECOES=sim exige FTP_TLS_MODE=2` | a exceção está ligada com o TLS em `0`, `1` ou `3` |
| `FALHA: FTP_TLS_EXCECOES=sim não combina com REDE_PERMITIR_IP_PUBLICO=sim` | a exceção está ligada junto com a opção de IP público |
| `FALHA: o pure-authd não abriu o soquete /run/pure-authd.sock: o FTP não sobe sem o porteiro do TLS` | com a exceção ligada, o `pure-authd` não iniciou em 10 segundos |
| `FALHA: o pure-authd saiu: o container encerra para ninguém entrar sem a conferência do TLS por usuário` (ou `o pure-ftpd saiu`) | com a exceção ligada, um dos dois processos parou depois da subida; o Docker sobe o container de novo |

Não é falha, e o container sobe: `AVISO: FTP_TLS_MODE=0, FTP sem TLS: senhas e arquivos trafegam em texto puro. Só para equipamento sem suporte a TLS, em rede interna isolada.` (ou `FTP_TLS_MODE=1, TLS opcional: ...`). O aviso se repete a cada subida enquanto o modo estiver ligado. Com `FTP_TLS_EXCECOES=sim`, o aviso é `AVISO: FTP_TLS_EXCECOES=sim: <n> usuário(s) marcado(s) no painel entram sem TLS, com senha e arquivos em texto puro. ...`.

A correção de cada uma está em [Solução de problemas](solucao-de-problemas.md#o-container-nao-sobe). O modelo completo da subida está em [Arquitetura](arquitetura.md#subida).

</details>

---

<a name="ftp-saude"></a>

## 🩺 `ftp/saude.sh`

É o healthcheck do container do FTP, instalado como `/usr/local/sbin/allsafe-ftp-saude`. Não é chamado direto: o Docker o executa a cada 20 segundos.

<details>
<summary>Detalhe técnico — o que ele confere</summary>

Abre a porta de controle (`127.0.0.1:2121`, de dentro do container), espera até 4 segundos pela saudação do servidor e encerra a conexão com `QUIT`. Considera saudável a saudação `220` (pronto) e também a `421` (limite de conexões atingido: o servidor está cheio, mas atendendo). Porta fechada, ou aberta sem saudação, conta como falha: depois de cinco falhas seguidas o Docker marca o container como `unhealthy`. O teste não faz login e não usa senha. Com `FTP_TLS_EXCECOES=sim`, antes de abrir a porta ele exige o soquete `/run/pure-authd.sock`: sem o `pure-authd`, o FTP não conta como saudável.

Para rodar à mão: `docker compose exec ftp /usr/local/sbin/allsafe-ftp-saude; echo $?` (`0` = atendendo).

</details>

---

<a name="porteiro-tls"></a>

## 🚪 `ftp/porteiro-tls.sh`

É o porteiro do TLS por usuário, instalado na imagem do FTP como `/usr/local/sbin/allsafe-ftp-porteiro-tls`. Não é chamado direto: com `FTP_TLS_EXCECOES=sim`, o `pure-authd` o executa a cada entrada, antes da conferência da senha. Com `nao`, não é usado.

**Resultado esperado:** a sessão com TLS e a do usuário dispensado seguem para a conferência da senha; a sessão sem TLS de qualquer outro recebe `530`, e o log do container ganha a linha `porteiro: entrada sem TLS recusada: usuario=<nome> origem=<ip> (a senha enviada passou em texto puro: troque-a)`.

<details>
<summary>Detalhe técnico — o que ele responde</summary>

- Recebe do `pure-authd`, em variáveis de ambiente, o nome (`AUTHD_ACCOUNT`), se a sessão tem TLS (`AUTHD_ENCRYPTED`) e o endereço de origem (`AUTHD_REMOTE_IP`). A senha também chega em variável e **não** é lida, gravada nem registrada.
- Responde `auth_ok:0` quando a sessão tem TLS ou quando o nome, dentro da regra `^[a-z_][a-z0-9_-]{0,31}$`, está em uma linha inteira de `/auth/sem-tls.lista`. É a resposta "não é comigo": o `pure-ftpd` segue para o PureDB, que confere a senha.
- Nos outros casos responde `auth_ok:-1`, a recusa definitiva: o cliente recebe `530` com a senha certa ou errada.
- No registro da recusa, nome fora da regra vira `(nome fora da regra)` e origem fora do formato de endereço vira `?`: o que o cliente mandou não vai cru para o log. A linha sai pela saída de erro do processo 1 do container, porque o `pure-authd` fecha a do script.
- Lista ausente ou ilegível conta como lista vazia: ninguém entra sem TLS.

</details>

---

<a name="painel-entrypoint"></a>

## 🖥️ `painel/entrypoint.sh`

Roda a cada início do container do painel. Não tem parâmetros: tudo vem das variáveis de [Configuração](configuracao.md#painel).

1. Recusa senha em variável, exige o segredo `/run/secrets/painel_admin_inicial_senha_hash` e confere o `PAINEL_ADMIN_USER`.
2. Confere que `PAINEL_BIND_IP`, cada rede de `PAINEL_REDES_PERMITIDAS` e o `PAINEL_CERT_CN` (se for IP) são privados, ou públicos aceitos com `REDE_PERMITIR_IP_PUBLICO=sim`.
3. Ajusta dono e modo de `/painel` (`0700`, do `root`) e do arquivo de administradores (`0600`, do `root`), também depois de uma restauração, e gera o certificado autoassinado do painel quando ele falta, quando os endereços mudam ou quando faltam menos de 30 dias para vencer.
4. Prepara a pasta `/nginx` (`0750`, grupo `10001`, o do nginx): copia o certificado e a chave para `/nginx/tls` e apaga o soquete da subida anterior.
5. Executa o servidor [`painel/servidor.py`](../painel/servidor.py), o ponto de entrada dos [módulos do painel](painel.md#modulos), que abre o soquete `/nginx/painel.sock`. O painel não abre porta de rede.

**Resultado esperado:** a linha `Painel pronto no soquete /nginx/painel.sock, atrás do nginx; sessão de 15 min; redes permitidas: ...` no log do container.

<details>
<summary>Detalhe técnico — mensagens de falha</summary>

| Mensagem | Quando |
|---|---|
| `FALHA: PAINEL_PASSWORD não é aceita` (ou `PAINEL_PASSWORD_HASH`) | há senha ou hash em variável de ambiente; o painel só lê o segredo |
| `FALHA: segredo /run/secrets/painel_admin_inicial_senha_hash ausente` | `.secrets/painel-admin-inicial-senha-hash.txt` não existe: rode o `deploy.sh` |
| `FALHA: PAINEL_BIND_IP=… não é IP privado` (ou `PAINEL_CERT_CN`) | endereço fora das faixas privadas, com a opção de IP público em `nao` |
| `FALHA: PAINEL_REDES_PERMITIDAS: '…' não é rede privada` | a lista tem rede pública ou `0.0.0.0/0`, com a opção de IP público em `nao` |
| `FALHA: PAINEL_BIND_IP=… não é um endereço IPv4 de servidor` (ou `PAINEL_CERT_CN`) | com a opção em `sim`, o valor é `0.0.0.0`, multicast ou reservado |
| `FALHA: PAINEL_REDES_PERMITIDAS: '…' não é uma rede IPv4 aceita` | com a opção em `sim`, a rede é mais larga que `/8`, como `0.0.0.0/0` |
| `FALHA: REDE_PERMITIR_IP_PUBLICO deve ser 'nao' ou 'sim'` | a opção tem outro valor |
| `FALHA: PAINEL_REDES_PERMITIDAS está vazia` | a variável chegou vazia ao container |
| `FALHA: PAINEL_ACESSO_USUARIOS_FTP deve ser 'sim' ou 'nao'` | a entrada dos usuários do FTP tem outro valor |
| `FALHA: FTP_TLS_EXCECOES deve ser 'nao' ou 'sim'`, `FALHA: FTP_TLS_EXCECOES=sim exige FTP_TLS_MODE=2` ou `FALHA: FTP_TLS_EXCECOES=sim não combina com REDE_PERMITIR_IP_PUBLICO=sim` | a exceção de TLS por usuário tem valor inválido ou está ligada em uma combinação recusada, a mesma conferência do container do FTP |
| `FALHA: PAINEL_ADMIN_USER inválido: ...` | o nome do primeiro administrador tem maiúscula, espaço, mais de 32 caracteres ou caractere fora de `a-z`, `0-9`, `_` e `-` |
| `FALHA: PAINEL_CERT_CN inválido` | nome com maiúscula, espaço ou caractere fora de `a-z`, `0-9`, `.` e `-` |
| `FALHA: pastas /auth e /data ausentes` | o painel subiu sem as pastas do serviço `ftp` |
| `FALHA: pasta /nginx ausente` | o painel subiu sem a pasta `DATA_DIR/nginx`, por onde o nginx o alcança: rode o `deploy.sh` |
| `FALHA: não foi possível gerar o certificado do painel` | `DATA_DIR/painel` sem espaço ou sem permissão de escrita |

O certificado é EC P-256, válido por 825 dias. O arquivo `painel-san.txt`, ao lado dele, marca que foi gerado pela stack: sem esse arquivo, o certificado é tratado como próprio e nunca é refeito. A cópia para `/nginx/tls` é refeita a cada subida (certificado `0644`, chave `0640`): é ela que o nginx apresenta ao navegador. Veja [Painel web](painel.md#certificado).

</details>

---

<a name="nginx-entrypoint"></a>

## 🚦 `nginx/entrypoint.sh`

Roda a cada início do container do nginx, já como usuário sem privilégio (`10001`). Não tem parâmetros: recebe só `TZ` e `PAINEL_REDES_PERMITIDAS`.

1. Recusa rodar como root.
2. Confere que cada rede de `PAINEL_REDES_PERMITIDAS` é privada, ou pública aceita com `REDE_PERMITIR_IP_PUBLICO=sim`.
3. Espera até 30 segundos pelo soquete do painel (`/nginx/painel.sock`) e pela cópia do certificado (`/nginx/tls`).
4. Gera a configuração em `/run/nginx/nginx.conf` a partir de [`nginx/nginx.conf.modelo`](../nginx/nginx.conf.modelo), trocando o marcador das redes por uma linha `allow` para cada rede permitida.
5. Testa a configuração e executa o `nginx`.

**Resultado esperado:** a linha `nginx pronto em 8443/tcp (HTTPS), à frente do painel; redes permitidas: ...` no log do container.

<details>
<summary>Detalhe técnico — mensagens de falha</summary>

| Mensagem | Quando |
|---|---|
| `FALHA: o nginx desta stack não roda como root: confira 'user' no compose.yaml` | o serviço foi alterado para subir como root |
| `FALHA: PAINEL_REDES_PERMITIDAS está vazia` | a variável chegou vazia ao container |
| `FALHA: PAINEL_REDES_PERMITIDAS: '…' não é rede privada. Por padrão esta stack é só para rede interna.` | a lista tem rede pública ou `0.0.0.0/0`, com a opção de IP público em `nao` |
| `FALHA: PAINEL_REDES_PERMITIDAS: '…' não é uma rede IPv4 aceita` | com a opção em `sim`, a rede é mais larga que `/8`, como `0.0.0.0/0` |
| `FALHA: REDE_PERMITIR_IP_PUBLICO deve ser 'nao' ou 'sim'` | a opção tem outro valor |
| `FALHA: soquete do painel ausente em /nginx/painel.sock: o serviço painel está no ar?` | o painel não subiu ou `DATA_DIR/nginx` não está montada nos dois containers |
| `FALHA: certificado do painel ausente ou ilegível em /nginx/tls` | o painel não copiou o certificado, ou a permissão da pasta foi alterada à mão |
| `FALHA: configuração do nginx recusada` | o modelo foi editado e ficou inválido; o erro do `nginx -t` aparece logo acima |

A configuração gerada fica em `tmpfs` e some quando o container para: quem manda é o modelo, dentro da imagem. `127.0.0.1` entra sempre na lista de redes, para o healthcheck.

</details>

---

<a name="nginx-saude"></a>

## 🩺 `nginx/saude.sh`

É o healthcheck do container do nginx, instalado como `/usr/local/sbin/allsafe-nginx-saude`. Não é chamado direto: o Docker o executa em intervalos.

<details>
<summary>Detalhe técnico — o que ele confere</summary>

Abre uma conexão TLS de verdade em `127.0.0.1:8443`, de dentro do container, e pede `/saude`. Só considera saudável se a resposta for `HTTP/1.1 200` com o corpo `ok`. Como o pedido passa pelo nginx e chega ao painel pelo soquete, um único teste confere os dois. A cadeia do certificado não é conferida, para o teste valer também com certificado de uma autoridade interna.

</details>

---

<a name="ftp-user"></a>

## 👥 `ftp/usuario.sh`

Instalado nas imagens do FTP e do painel como `/usr/local/sbin/allsafe-ftp-user`. Não é chamado diretamente: use o [`manage-user.sh`](../manage-user.sh) ou o [painel](painel.md#usuarios).

<details>
<summary>Detalhe técnico — o que ele faz dentro do container</summary>

- Aceita `add|passwd|del|list|tls-dispensar|tls-exigir|tls-lista [usuario] [pasta]`, com a pasta só no `add`, e valida o nome (`^[a-z_][a-z0-9_-]{0,31}$`).
- A pasta, quando informada, tem até 4 níveis separados por `/`; cada nível casa com `[A-Za-z0-9_][A-Za-z0-9._-]{0,63}`. Fora disso, responde `Pasta invalida: ...` e sai com código `1`, antes de ler a senha.
- Lê a senha do `stdin` e recusa menos de 12 caracteres com `Senha deve ter pelo menos 12 caracteres`.
- `add` recusa nome que já existe (`Usuario ja existe`), confere a pasta nível por nível (link simbólico ou arquivo no caminho: `Pasta recusada: ...`), cria os níveis que faltam com dono `ftpdata` e modo `0750` e registra o usuário com `pure-pw useradd`, com a pasta como diretório do `chroot`. Sem a pasta, usa `/data/<usuario>`.
- Se outro usuário tem a mesma pasta, uma de cima ou uma de dentro, o `add` conclui e escreve `Aviso: /data/<pasta> e dividida com o usuario <nome> ...`, uma linha por usuário.
- `passwd` usa `pure-pw passwd`; `del` usa `pure-pw userdel`, **não** apaga a pasta e diz qual é ela.
- `tls-dispensar` e `tls-exigir` põem e tiram o nome de `/auth/sem-tls.lista` (`0600`), um nome por linha, em ordem. Só aceitam usuário que existe: senão, `Usuario nao existe: <nome>` e código `1`. A lista é gravada em um arquivo ao lado e trocada de nome, para nunca ser lida pela metade, e a cada gravação saem dela os nomes que já não estão no cadastro. `del` tira o usuário da lista; `tls-lista` a mostra.
- Depois de cada mudança, regenera o `pureftpd.pdb` com `pure-pw mkdb` e mantém os dois arquivos em `0600`.
- Antes de alterar, pega a trava `/auth/.lock` (`flock`, espera até 30 segundos): o FTP, o `manage-user.sh` e o painel nunca gravam ao mesmo tempo.
- `list` passa o arquivo pela variável `PURE_PASSWDFILE`, porque o `pure-pw list` não aceita `-f` logo depois da ação.
- Uso inválido: mostra `Uso: ... add|passwd|del|list|tls-dispensar|tls-exigir|tls-lista [usuario] [pasta]` e sai com código `2`.

</details>

---

<a name="apoio"></a>

## 🧩 Scripts de apoio

Não são executados: outros scripts os carregam com `source`.

| Script | Função | Quem usa |
|---|---|---|
| [`scripts/rede-privada.sh`](../scripts/rede-privada.sh) | `ip_privado` e `cidr_privado` aceitam só `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12` e `192.168.0.0/16`; `ip_utilizavel` e `cidr_utilizavel` dizem o que passa com a opção de IP público (IPv4 de `1` a `223` no primeiro octeto, rede de `/8` a `/32`); `exigir_ip` e `exigir_rede` aplicam a regra e escrevem a `FALHA`; `conferir_opcao_ip_publico` recusa valor fora de `nao` e `sim`; `aviso_ip_publico` escreve o `ALERTA` | `deploy.sh`, `tests/testar.sh`, `ftp/entrypoint.sh`, `painel/entrypoint.sh` e `nginx/entrypoint.sh` |
| [`scripts/ambiente.sh`](../scripts/ambiente.sh) | `env_valor <chave> [padrão]`: lê uma chave do `.env` sem executar o arquivo; a última ocorrência vale, como no Compose. `env_gravar <chave> <valor>`: troca a linha da chave ou acrescenta no fim, sem regravar quando o valor já é o pedido | `deploy.sh`, `manage-user.sh`, `painel-senha.sh`, `backup.sh`, `restaurar.sh`, `validate.sh` e `testar.sh` |

---

⬅️ [Segredos](segredos.md) · 🏠 [Documentação](README.md) · ➡️ [Operação](operacao.md)
