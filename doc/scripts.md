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

[Visão geral](#visao-geral) · [`deploy.sh`](#deploy) · [`manage-user.sh`](#manage-user) · [`scripts/painel-senha.sh`](#painel-senha) · [`scripts/backup.sh`](#backup) · [`scripts/restaurar.sh`](#restaurar) · [`scripts/validate.sh`](#validate) · [`scripts/gerar-marca.sh`](#gerar-marca) · [`tests/testar.sh`](#testar) · [`ftp/entrypoint.sh`](#entrypoint) · [`ftp/saude.sh`](#ftp-saude) · [`ftp/porteiro.sh`](#porteiro) · [`ftp/vigia.pl`](#vigia) · [`painel/entrypoint.sh`](#painel-entrypoint) · [`nginx/entrypoint.sh`](#nginx-entrypoint) · [`nginx/saude.sh`](#nginx-saude) · [`ftp/usuario.sh`](#ftp-user) · [Scripts de apoio](#apoio)

</details>

---

<a name="visao-geral"></a>

## 📋 Visão geral

| Script | Onde roda | Para que serve |
|---|---|---|
| [`deploy.sh`](../deploy.sh) | host | Instala, reaplica, atualiza ou remove a stack em um comando, sem perguntas |
| [`manage-user.sh`](../manage-user.sh) | host | Atalho para criar, trocar senha, trocar pasta, trocar o perfil, ajustar limites, desbloquear, remover e listar usuários FTP, e para dispensar um usuário do TLS |
| [`scripts/painel-senha.sh`](../scripts/painel-senha.sh) | host | Recupera o acesso ao painel: define a senha de um administrador ou cria o administrador, gravando só o hash |
| [`scripts/backup.sh`](../scripts/backup.sh) | host | Grava a cópia de segurança cifrada de `dados/`, `auth/`, `certs/` e `painel/` em `BACKUP_DIR` |
| [`scripts/restaurar.sh`](../scripts/restaurar.sh) | host | Devolve a stack ao estado de uma cópia, guardando antes o estado atual |
| [`scripts/validate.sh`](../scripts/validate.sh) | host | Checagem de sintaxe, da marca, da licença, do Compose de todos os perfis e, opcionalmente, dos três serviços no ar |
| [`scripts/gerar-marca.sh`](../scripts/gerar-marca.sh) | computador de quem troca a logo | Gera os seis arquivos de logo e ícone do painel a partir das duas artes de origem |
| [`tests/testar.sh`](../tests/testar.sh) | host | Bateria de testes funcional, de segurança e de rede, em instância de teste que o próprio script cria e remove |
| [`ftp/entrypoint.sh`](../ftp/entrypoint.sh) | container | Provisiona o usuário inicial e o certificado, sobe o vigia, o `pure-authd` e o `pure-ftpd` e encerra o container se um deles sair |
| [`ftp/saude.sh`](../ftp/saude.sh) | container | Healthcheck: abre a porta de controle e espera a saudação do servidor |
| [`ftp/porteiro.sh`](../ftp/porteiro.sh) | container | Decide a cada entrada, antes da conferência da senha, se ela pode seguir: recusa o usuário bloqueado por senhas erradas e, com o TLS por usuário valendo, a sessão sem TLS de quem não foi dispensado |
| [`ftp/vigia.pl`](../ftp/vigia.pl) | container | Conta as senhas erradas de cada endereço para cada usuário, grava o bloqueio que o porteiro aplica, entrega ao servidor o arquivo recebido em pasta com perfil Envio ou Leitura e publica a rede e os recursos do container para a aba Servidor do painel |
| [`painel/entrypoint.sh`](../painel/entrypoint.sh) | container do painel | Confere a rede privada, gera o certificado do painel, entrega a cópia dele ao nginx e executa o painel |
| [`nginx/entrypoint.sh`](../nginx/entrypoint.sh) | container do nginx | Confere a rede privada, gera a configuração do nginx e o executa, sem root |
| [`nginx/saude.sh`](../nginx/saude.sh) | container do nginx | Healthcheck: pede `/saude` ao painel passando pelo nginx |
| [`ftp/usuario.sh`](../ftp/usuario.sh) | containers do FTP e do painel | Gestão de usuários no PureDB, dos perfis, dos limites, dos bloqueios e da lista de quem entra sem TLS, chamada pelo `manage-user.sh` e pelo painel |
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
- **`FTP_TLS_EXCECOES` conferida antes de agir:** valor fora de `nao` e de `sim` para com `ERRO: FTP_TLS_EXCECOES deve ser 'sim' ou 'nao'` e código `1`. Com `sim`, o padrão, a opção só vale com `FTP_TLS_MODE=2` e sem `REDE_PERMITIR_IP_PUBLICO=sim`: fora disso o deploy segue e diz, também no `--check-only`, `TLS por usuário sem efeito: <motivo>. Ninguém é dispensado do TLS.` Valendo e com usuário já dispensado no painel, o deploy termina com o `AVISO: TLS por usuário: <n> usuário(s) dispensado(s) na aba Usuários do painel entram SEM TLS`.
- Na primeira execução sem `.env`, copia o [`.env.example`](../.env.example), aplica `0600`, avisa `Criado .env a partir do .env.example: tudo em 127.0.0.1, só este servidor acessa.` e **segue**. Com `--check-only` nada é criado: a validação usa o `.env.example`.
- **Idempotente:** rodado de novo sem mudança, não recria container, não troca senha e não regrava o `.env`.
- **Converte os nomes antigos, a variável:** em `.env` de instalação anterior à `0.9.0`, troca `FTP_PUBLIC_IP` por `FTP_PASSIVE_IP`, no mesmo ponto do arquivo e com o mesmo valor, depois de copiar o `.env` para `BACKUP_DIR/<data>-antes-da-migracao-de-nomes/env` (`0600`), e avisa `Convertido: FTP_PUBLIC_IP virou FTP_PASSIVE_IP`. A troca do nome, sozinha, não recria container; na atualização a partir de uma versão anterior, os três são recriados uma vez, porque as imagens mudam, e usuários, senhas e arquivos ficam como estavam. Com `--check-only`, só avisa `AVISO: esta instalação usa nomes antigos` e não altera nada.
- **Converte os nomes antigos, os segredos:** em instalação feita até a `0.9.0`, dá o nome novo aos três arquivos de `.secrets/` com `mv`, sem ler nem copiar o conteúdo, e avisa `Convertido: <antigo> virou <novo>.` para cada um. Se o antigo e o novo existirem, vale o novo e sai um `AVISO`. Com `--check-only`, só avisa. Tabela dos nomes: [Segredos](segredos.md#nomes-antigos).
- Se `.secrets/ftp-usuario-inicial-senha.txt` estiver vazio ou ausente, gera uma senha forte (`0600`): veja [Segredos](segredos.md).
- Grava o `.secrets/LEIAME.txt` (`0600`), que diz para que serve cada arquivo da pasta e não guarda segredo, e fecha o resumo com `Segredos: .../LEIAME.txt diz para que serve cada arquivo.`
- Diz, no fim do resumo, se o contato de segurança está publicado: `Contato de segurança: <e-mail>, publicado em /.well-known/security.txt do painel.` ou, com `SEGURANCA_CONTATO_EMAIL` vazia, `Contato de segurança: não publicado.`, com o que preencher. Não bloqueia a instalação.
- Recusa `FTP_PASSWORD`, `PAINEL_PASSWORD` e `PAINEL_PASSWORD_HASH` no `.env` e, por padrão, qualquer `FTP_BIND_IP`, `FTP_PASSIVE_IP`, `PAINEL_BIND_IP`, `PAINEL_REDES_PERMITIDAS` ou `PAINEL_CERT_CN` (em forma de IP) fora de rede privada.
- **Opção de IP público:** `REDE_PERMITIR_IP_PUBLICO` diferente de `nao` e de `sim` para com `FALHA: REDE_PERMITIR_IP_PUBLICO deve ser 'nao' ou 'sim'` e código `1`. Com `sim`, aceita IPv4 público de servidor e rede de `/8` a `/32`, continua recusando `0.0.0.0` e rede mais larga, exige `FTP_TLS_MODE` em `2` ou `3` (`ERRO: REDE_PERMITIR_IP_PUBLICO=sim exige FTP_TLS_MODE=2 ou 3`) e mostra o `ALERTA` ao final, também no `--check-only`.
- **Painel por proxy ou túnel:** `PAINEL_PROXY_CONFIAVEL` vazia não muda nada. Preenchida, cada endereço tem de ser IPv4, um a um, privado (ou público com a opção de IP público) e estar dentro de `PAINEL_REDES_PERMITIDAS`, até 8; fora disso, para com `FALHA: PAINEL_PROXY_CONFIAVEL: …` e código `1`. Aceita, o `--check-only` e o fim do deploy fecham com `ALERTA: PAINEL_PROXY_CONFIAVEL=…: o painel está publicado por proxy ou túnel, por opção de quem instalou.` Veja [Segurança](seguranca.md#painel-por-proxy).
- Se `.secrets/painel-admin-inicial-senha-hash.txt` não existir, gera a senha inicial do painel em `.secrets/painel-admin-inicial-senha.txt` (`0600`) e grava o hash dela, chamando o `scripts/painel-senha.sh --inicial` depois de construir a imagem.
- Confere a `PAINEL_ACESSO_USUARIOS_FTP` antes de agir: valor diferente de `sim` e de `nao` para com `ERRO: PAINEL_ACESSO_USUARIOS_FTP deve ser 'sim' ou 'nao'; ...` e código `1`.
- Confere a `PAINEL_AVISO_EXPOSICAO` antes de agir: valor diferente de `sim` e de `nao` para com `ERRO: PAINEL_AVISO_EXPOSICAO deve ser 'sim' ou 'nao'`.
- Confere o `PAINEL_ADMIN_USER` antes de agir: nome fora da regra para com `ERRO: PAINEL_ADMIN_USER inválido em .env: ...` e código `1`. No resumo, mostra o usuário e o arquivo da senha inicial enquanto esse arquivo existir; depois, `usuário e senha: os definidos na aba Usuários ou com ./scripts/painel-senha.sh`.
- Confere o `SEGURANCA_CONTATO_EMAIL` antes de agir: preenchido com algo que não é um endereço de e-mail só, para com `ERRO: SEGURANCA_CONTATO_EMAIL inválido em .env: um endereço de e-mail só, como seguranca@exemplo.com.br, ou vazio.` e código `1`. Vazio é aceito: o `security.txt` não é publicado.
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
./manage-user.sh add coletor clientes/olt-01 envio   # o mesmo, com o perfil: completo (padrão), envio ou leitura
./manage-user.sh perfil backup-olt    # mostra o perfil do usuário
./manage-user.sh perfil backup-olt leitura   # troca o perfil; vale na próxima entrada do usuário no FTP
./manage-user.sh passwd backup-olt    # troca a senha
./manage-user.sh pasta backup-olt clientes/olt-02   # troca a pasta; os arquivos da anterior continuam nela
./manage-user.sh limites backup-olt sessoes=2 download=500 horario=0800-1800   # grava limites só do usuário
./manage-user.sh limites backup-olt   # mostra os limites do usuário
./manage-user.sh limites backup-olt tentativas=3 minutos=30   # senhas erradas até o bloqueio e minutos de bloqueio, só do usuário
./manage-user.sh bloqueios            # lista os bloqueios por tentativa em vigor (ou só os de um usuário)
./manage-user.sh desbloquear backup-olt   # tira os bloqueios do usuário (ou só o de uma origem)
./manage-user.sh del backup-olt       # remove o usuário (os arquivos ficam em /data)
./manage-user.sh tls-dispensar olt-antiga   # deixa o usuário entrar sem TLS (equipamento que não fala TLS)
./manage-user.sh tls-exigir olt-antiga      # volta a exigir o TLS do usuário
./manage-user.sh tls-lista                  # lista os usuários dispensados do TLS
```

**Resultado esperado:** `add` e `passwd` terminam sem erro e o usuário aparece no `list`; `pasta` responde `Pasta do usuario <nome>: /data/<pasta>. Os arquivos de /data/<anterior> continuam la.`; `del` responde `Usuario removido; os dados em /data/<pasta> foram preservados.`, com a pasta real do usuário. O `add` com uma pasta que outro usuário já alcança termina sem erro e mostra uma linha `Aviso:` por usuário. `tls-dispensar` responde `Usuario <nome> dispensado do TLS: vale na proxima entrada, com FTP_TLS_EXCECOES=sim.` e `tls-exigir`, `Usuario <nome> volta a ser obrigado a usar TLS: vale na proxima entrada.`; `tls-lista` mostra um nome por linha, ou nada. `limites` com pelo menos um par responde `Limites do usuario <nome> gravados: valem na proxima entrada no FTP.`; sem par nenhum, mostra uma linha por limite (`sessoes=`, `download=`, `envio=`, `horario=`, `baixar=`, `tentativas=` e `minutos=`), vazia no que o usuário não tem. `bloqueios` mostra uma linha por bloqueio, `usuario=<nome> origem=<ip> senhas_erradas=<n> desde=<data hora> ate=<data hora>`, ou `Nenhum bloqueio em vigor.`; `desbloquear` responde `Usuario <nome> desbloqueado (<n> endereco(s)): vale na proxima entrada no FTP.`, ou `Usuario <nome> nao tem bloqueio.`

O perfil diz o que o usuário faz na pasta: `completo` envia, baixa, renomeia e apaga; `envio` envia e baixa, sem apagar nem alterar o que já chegou; `leitura` só lista e baixa. No `add`, ele vem depois da pasta. `perfil` com o nome do perfil responde `Perfil do usuario <nome>: <perfil>. Vale na proxima entrada no FTP.`; valor fora dos três para com `Perfil invalido: use completo, envio ou leitura` e código `1`. O que cada perfil alcança e os limites do Envio estão em [Painel web](painel.md#perfis).

A senha é lida do terminal e enviada pelo `stdin` para o container: não aparece na linha de comando nem no histórico. O script opera a instalação do `.env` desta pasta; para operar outra, aponte o arquivo dela: `ENV_FILE=<arquivo> ./manage-user.sh list`. Regras e casos de uso em [Operação](operacao.md#usuarios).

---

<a name="painel-senha"></a>

## 🔑 `scripts/painel-senha.sh`

Recupera o acesso ao painel pelo host. No dia a dia, usuário e senha são trocados no próprio painel, na aba Usuários.

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
./scripts/backup.sh                    # grava a cópia cifrada de dados/, auth/, certs/ e painel/ em BACKUP_DIR
./scripts/backup.sh --rotulo <texto>   # o mesmo, com o texto no nome do arquivo
./scripts/backup.sh --listar           # mostra as cópias que existem
```

**Resultado esperado:** `Cópia gravada: <BACKUP_DIR>/<STACK_NAME>-AAAAMMDD-HHMMSS.tar.gz.age (<tamanho>, cifrada)`, o lembrete de que o `.env` e os segredos ficam fora da cópia, o de que só a chave privada a abre e o comando para restaurá-la.

A stack pode ficar no ar. A cópia sai cifrada com a chave pública de `SECRETS_DIR/backup-chave-publica.txt`, com modo `0600` e com a soma `.sha256` ao lado; a leitura e a cifra são feitas por um container sem rede, com `DATA_DIR` só para leitura. Uso, conteúdo da cópia e códigos de saída: [Backup e restauração](backup.md#fazer).

---

<a name="restaurar"></a>

## 🔁 `scripts/restaurar.sh`

```bash
./scripts/restaurar.sh <cópia>          # pede para digitar 'restaurar'
./scripts/restaurar.sh <cópia> --sim    # sem pergunta (obrigatório quando não há terminal)
./scripts/restaurar.sh --listar         # mostra as cópias que existem
```

**Resultado esperado:** `Restaurado e no ar (healthy).` e, na última linha, o comando para desfazer.

Confere a cópia antes de alterar qualquer coisa, abrindo-a com a chave de `SECRETS_DIR/backup-chave-privada.txt`, para a stack, guarda o estado atual em um arquivo com `antes-da-restauracao` no nome, troca o conteúdo e sobe de novo. `<cópia>` é o nome de um arquivo de `BACKUP_DIR` ou um caminho; cópia sem cifra, feita antes da `0.25.0`, ainda é aceita, com aviso. Passos, recusas e códigos de saída: [Backup e restauração](backup.md#restaurar).

---

<a name="validate"></a>

## 🧪 `scripts/validate.sh`

```bash
./scripts/validate.sh            # sintaxe dos scripts, .env.example comentado, caminhos, marca, política de segurança, licença e compose config de todos os perfis
./scripts/validate.sh --runtime  # também exige os três serviços running e healthy e o usuário no PureDB
```

**Resultado esperado:** `painel OK: <n> módulos Python`, `.env.example OK: <n> variáveis, todas comentadas e no guia de configuração`, `caminhos OK: nenhum arquivo do repositório cita pasta pessoal`, `marca OK: 6 arquivos em web/marca/`, `política de segurança OK: SECURITY.md aponta para SEGURANCA_CONTATO_EMAIL, sem endereço fixo`, `licença OK: LICENSE (Apache-2.0), NOTICE, MARCA.md e a linha SPDX em <n> arquivos de código`, `compose OK com <perfil>.env` para cada perfil e, no fim, `Validacao FTP concluida.` Com `--runtime`, também `servico ftp: running, healthy`, o mesmo para `painel` e `nginx`, e `usuario inicial '<usuário>' presente no PureDB`. Qualquer falha encerra com código diferente de zero.

<details>
<summary>Detalhe técnico — o que cada modo confere</summary>

| Modo | Confere |
|---|---|
| sem parâmetro | `bash -n` em `deploy.sh`, `manage-user.sh` e nos scripts de `scripts/`, `ftp/`, `painel/`, `nginx/` e `tests/`; se o host tiver `python3`, a sintaxe de cada módulo de `painel/` e que todo nome usado em cada um está definido ou importado nele, sem importar nem gravar nada; no `.env.example`, que cada variável tem comentário na linha de cima e está em [Configuração](configuracao.md); que nenhum arquivo do repositório cita pasta pessoal de um computador (conferência feita só quando a pasta é um repositório Git; o `.env` local fica fora); em [`web/marca/`](../web/marca/), que os seis arquivos da marca existem e são PNG ou ICO; que o [`SECURITY.md`](../SECURITY.md) existe, cita `SEGURANCA_CONTATO_EMAIL` e não traz endereço de e-mail fixo; que o [`LICENSE`](../LICENSE) é o texto oficial da Apache-2.0, conferido pelo sha256, que o [`NOTICE`](../NOTICE) traz a linha de autoria e o endereço do GitHub, que o [`MARCA.md`](../MARCA.md) existe e que cada arquivo de código tem a linha `SPDX-License-Identifier: Apache-2.0` em uma das duas primeiras linhas; `docker compose config --quiet` com `.env.example` e cada arquivo de `profiles/` |
| `--runtime` | tudo acima, mais: os serviços `ftp`, `painel` e `nginx` em `running` e `healthy`, e o usuário inicial, lido de `FTP_USER` no `.env`: presente no cadastro (`pure-pw show`) ou removido pelo administrador (marca `/auth/usuario-inicial.criado`) |

O modo `--runtime` confere a instalação do `.env` desta pasta. Para conferir outra, aponte o arquivo dela: `ENV_FILE=<arquivo> ./scripts/validate.sh --runtime`. Sem o arquivo, o script para com `ERRO: ... não há instalação para conferir.`

Recusa dos caminhos: `ERRO: pasta pessoal em arquivo do repositório; use o padrão do .env.example ou leia o valor do .env:`, seguida do arquivo e da linha.

Recusa da política de segurança: `ERRO: SECURITY.md falta, não cita SEGURANCA_CONTATO_EMAIL ou traz um endereço de e-mail fixo.`

Recusas da licença: `ERRO: LICENSE falta ou não é o texto oficial da Apache-2.0.`, `ERRO: NOTICE falta ou está sem a linha de autoria e o endereço do GitHub.`, `ERRO: MARCA.md falta.` e `ERRO: <arquivo> sem a linha SPDX-License-Identifier: Apache-2.0 no começo.` A linha da licença vai na primeira linha do arquivo de código ou, quando ele começa com `#!`, na segunda.

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
| `simbolo-64.png` | 64 pixels | `allsafe-simbolo-512.png` | Símbolo no menu de todas as telas |
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

**Resultado esperado:** uma linha por caso, com `✅` ou `❌`, o resumo de cada bateria com o caminho do arquivo de resultado e, no fim, `Bateria aprovada: nenhum desvio.` A execução leva perto de 25 minutos.

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
| Pasta de trabalho, dados, segredos e cópias de segurança | `TEMP_DIR/testar` | `TEMP_DIR`, lida do ambiente, depois do `.env` e, sem os dois, do `.env.example` |

As senhas da instância de teste são geradas na hora, ficam só em `TEMP_DIR/testar` e somem com ela. O script recusa rodar se `TEMP_DIR/testar` já existir e não tiver sido criada por ele, e se o `.env` desta pasta usar `STACK_NAME=allsafe-ftp-teste`.

**O que cada bateria cobre:**

| Bateria | Casos | Exemplos |
|---|---|---|
| Funcional | 57 | instalação em um comando, login por FTPS, envio e download com comparação, ciclo de usuário pelo terminal e pelo painel, reinício sem perda, healthcheck do FTP, backup e restauração, arquivos estáticos entregues pelo nginx, conversão dos nomes antigos pelo `deploy.sh`, administradores pelo painel, recuperação do acesso pelo host, download pelo painel (arquivo pequeno, subpasta, nome com acento e arquivo de 40 MiB, com a soma conferida), pasta criada pelo painel, usuário com pasta escolhida e pasta dividida entre usuários (também em um cadastro de dois mil usuários, comparada com a conferência de todos contra todos), usuário do FTP que entra no painel e baixa os próprios arquivos, sessão dele acompanhando o cadastro e a variável que desliga a entrada, a entrada dele em cada modo de TLS, e o TLS por usuário: dispensa e volta pelo painel e pelo terminal, usuário criado já dispensado, o cartão do TLS em Editar e a opção sem efeito com IP público, e a marca: logo e ícone entregues pelo nginx e a autoria no rodapé de todas as telas, o `robots.txt` e o `security.txt` com o contato de segurança, a execução só em Docker, sem systemd, a senha do usuário inicial reaplicada do segredo a cada subida, a licença e a autoria no projeto e dentro das três imagens, o `HEAD` do painel igual ao `GET`, sem o corpo, a pasta do usuário trocada pelo painel e pelo terminal, sem mover arquivo, a senha e a pasta do usuário inicial trocadas pelo painel, valendo até o segredo mudar, o arquivo e a pasta renomeados e apagados pelo painel, o usuário removido junto com a pasta, os limites por usuário gravados pelo painel e pelo terminal e aplicados pelo FTP, os downloads pelo painel no limite do usuário, o bloqueio por tentativa no FTP: limite do usuário pelo painel e pelo terminal, bloqueio, vencimento, desbloqueio, reinício e padrão da stack, as transferências pelo FTP no registro do container, e a frente web: HTTP/2 e HTTP/1.1 com a mesma sessão, o estilo comprimido para quem aceita gzip e a conexão mantida entre um clique e outro, e o usuário inicial removido pelo painel, que não volta na subida seguinte, a aba Servidor coerente com a máquina e com os limites de cada container, os perfis no FTP: Completo, Envio e Leitura, cada um com o que pode fazer, e a tela única de usuários, com administradores e usuários do FTP na mesma lista e a troca de perfil |
| Segurança | 102 | login sem TLS e anônimo recusados, fuga do `chroot`, isolamento entre usuários, recusas do `deploy.sh` e dos containers a IP público, a opção de IP público (só com `sim`, "todos" sempre recusado, TLS obrigatório, valor inválido, alerta em execução), CSRF, `Origin` de fora e `Origin: null`, `Host` de fora, limite de tentativas, cabeçalhos, TLS antigo, nenhum segredo no `.env`, no Git, nos logs, na auditoria e no `LEIAME.txt` da pasta de segredos, entrada que não revela nomes de administrador, senha atual em toda alteração de administrador, sessões do administrador alterado encerradas, arquivo de administradores só com hash, aba Arquivos sem sessão, fuga da pasta pela aba Arquivos, link simbólico não seguido, arquivo entregue só como anexo, limite de downloads ao mesmo tempo, criação de pasta sem sessão e sem token, nome de pasta que tenta sair da pasta dos dados, usuário preso à pasta escolhida, usuário do FTP sem alcance à administração do painel, preso à própria pasta no painel, entrada dele sem brecha (telas iguais na recusa, nome de administrador, servidor FTP parado, certificado trocado, bloqueio por tentativas), os limites de sessões e de downloads por usuário, e o TLS por usuário: sem TLS só entra quem foi dispensado, sem nenhum dispensado a sessão sem TLS é recusada antes da senha, a troca de modo não derruba sessão em andamento, o FTP encerra se o `pure-authd` morre, a opção sem efeito ou desligada, o valor recusado na subida e quem pode alterar a lista, e a pasta da marca, que entrega só os seis arquivos, só para leitura, os endereços abertos sem senha do `robots.txt` e do `security.txt`, que não entregam mais nada, e a segurança ampliada: nenhuma rota do painel e nenhum comando do FTP sem login, senha aleatória no FTP e no painel, rajada de senhas, de pedidos e de conexões, conexão parada, pedido grande ou malformado, cadastro das senhas fora do alcance da web, do FTP, dos outros containers e do host, custo da senha do FTP conforme o porte, a troca de pasta, o renomear e o apagar, que não saem da pasta dos dados nem agem sem sessão, sem token e sem a senha do administrador, a pasta grande apagada em mais de um pedido, os limites por usuário, que recusam valor fora da regra, sem sessão e sem token, e o bloqueio por tentativa: arquivo de bloqueio forjado, nome fora do cadastro, queda do vigia, e desbloqueio e limites sem sessão, sem token e fora da regra, e o HTTP/2 e a compressão, que não abrem nada: página com token sempre inteira, cópia comprimida sem endereço e os limites de pedidos e de tamanho valendo nos dois protocolos, nenhuma pasta pessoal em arquivo do repositório, e o painel por proxy ou túnel: endereço do cliente forjado em cabeçalho ignorado, com e sem proxy declarado, senha errada e sessão contadas pelo endereço do cliente, e o aviso de exposição oculto só na tela, a aba Servidor fora do alcance de quem não é administrador e os arquivos de estado trocados por texto com marcação e por link, e os perfis: Envio não apaga, não renomeia e não grava por cima do que já chegou, Leitura não grava nada, o modo das pastas acompanha a troca de perfil, de pasta e a remoção, e a troca de perfil recusada sem sessão, sem token, por usuário do FTP e com valor fora da lista |
| Rede | 14 | portas publicadas só no IP configurado, endereço anunciado no modo passivo, limite de sessões por IP, painel só em HTTPS, troca de perfil, duas instâncias no mesmo host, rede pública no painel só com a opção, proxy do painel declarado endereço a endereço e dentro das redes permitidas |

**Organização:** o [`tests/testar.sh`](../tests/testar.sh) prepara a instância de teste e carrega o [`tests/comum.sh`](../tests/comum.sh), com as funções de registro, de FTP, do painel e de gravação dos resultados. Os casos ficam em [`tests/etapas/`](../tests/etapas/), um arquivo por etapa, executados na ordem do nome: cada etapa parte do estado que a anterior deixou e não roda sozinha.

**Resultados:** três arquivos Markdown, um por bateria, com data, comando, versão, ambiente, a tabela dos casos com a evidência de cada um e os achados. Nenhuma senha, token, cookie ou hash é gravado: antes de terminar, o script procura nos três arquivos os segredos que usou e, se achar, apaga o arquivo e sai com `3`. Sem `--resultados`, eles vão para a pasta do plano, se ela existir, ou para `TEMP_DIR/resultados`.

**Limpeza:** ao terminar, ou ao ser interrompido, o script remove os containers, a rede, as imagens e a pasta da instância de teste. Com `--manter`, nada é removido até o `--limpar`.

</details>

---

<a name="entrypoint"></a>

## ⚙️ `ftp/entrypoint.sh`

Roda a cada início do container. Não tem parâmetros: tudo vem das variáveis de [Configuração](configuracao.md).

1. Confere que `FTP_BIND_IP` e `FTP_PASSIVE_IP` são IPs privados, ou públicos de servidor com `REDE_PERMITIR_IP_PUBLICO=sim` ([`rede-privada.sh`](../scripts/rede-privada.sh)), lê a senha do segredo `/run/secrets/ftp_usuario_inicial_senha`, ajusta dono e modo de `/data` (`0700`, do `root`), `/auth` e `/etc/ssl/private` e cria o usuário inicial `FTP_USER`, uma vez, deixando a marca `/auth/usuario-inicial.criado` (`0600`, só com o nome dele); se ele já existe, regrava a senha dele com a do segredo (recusa senha com menos de 12 caracteres); se foi removido, não o recria, e o log diz `removido pelo administrador; não é recriado`. Se a senha foi trocada pelo painel e o segredo não mudou desde então, ela é mantida, e o log diz `mantida a senha trocada pelo painel`. O custo do hash da senha acompanha `FTP_MAX_CLIENTS`.
2. Gera um certificado autoassinado para `FTP_CERT_CN` se `DATA_DIR/certs` estiver vazia, e grava a parte pública dele em `/auth/ftp-cert.pem`.
3. Com perfil Envio ou Leitura no cadastro, refaz o modo das pastas dos usuários e entrega ao `ftpdata` o que um envio deixou sem entrega (`allsafe-ftp-user ajustar`). Sobe o [vigia](#vigia), que conta as senhas erradas, e o `pure-authd`, que chama o [porteiro](#porteiro) a cada entrada.
4. Sobe o `pure-ftpd` com o modo de TLS, o `chroot`, os limites e a faixa passiva do `.env`. Com `FTP_TLS_MODE` em `0` ou `1`, ou com usuário dispensado do TLS, grava antes um `AVISO` no log.
5. Com o TLS por usuário valendo, sobe o observador, que confere a lista dos dispensados a cada segundo. Quando ela passa de vazia a preenchida, ou o contrário, só o processo do `pure-ftpd` que escuta a porta é trocado: as sessões em andamento continuam e o container não reinicia.
6. Fica vigiando os processos: se um deles sair por outro motivo, encerra o container, e o Docker o sobe de novo.

**Resultado esperado:** as linhas `vigia: pronto: 5 senhas erradas do mesmo endereço bloqueiam o usuário para ele por 15 min; ...` e `FTP pronto em 2121/tcp; TLS=2; TLS por usuário: nenhum dispensado, sessão sem TLS recusada antes da senha; passivo=30000-30049` no log do container; com um usuário dispensado, `FTP pronto em 2121/tcp; TLS=2 com exceção por usuário (1 dispensado(s) do TLS); passivo=30000-30049`. A cada troca, a linha `TLS por usuário: a lista dos dispensados mudou; o FTP troca o modo de entrada sem derrubar as sessões em andamento.` vem antes de um novo `FTP pronto`. Com a opção sem efeito, a subida diz `TLS por usuário sem efeito: só vale com FTP_TLS_MODE=2; está <modo>.` ou `TLS por usuário sem efeito: não vale com REDE_PERMITIR_IP_PUBLICO=sim (...)`, e segue.

<details>
<summary>Detalhe técnico — processo 1 e mensagens de falha</summary>

Com `init: true`, o processo 1 do container é o `tini`, que inicia o entrypoint. O entrypoint continua vivo, com o vigia, o `pure-authd` e o `pure-ftpd` como filhos, repassa a eles o sinal de parada e, se um dos três sair sozinho, encerra os outros e sai com código `1`.

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
| `FALHA: FTP_MAX_CLIENTS deve ser um inteiro maior que zero` (ou `FTP_MAX_CLIENTS_PER_IP`) | o limite de sessões não é um inteiro de 1 a 99999 |
| `FALHA: FTP_TLS_EXCECOES deve ser 'nao' ou 'sim'` | a exceção por usuário tem outro valor |
| `FALHA: FTP_BLOQUEIO_TENTATIVAS deve ficar entre 0 e 100 (0 desliga o bloqueio por tentativa)` | o limite de senhas erradas da stack não é um inteiro de 0 a 100 |
| `FALHA: FTP_BLOQUEIO_MINUTOS deve ficar entre 1 e 1440` | os minutos de bloqueio da stack não são um inteiro de 1 a 1440 |
| `FALHA: /auth/bloqueios é link simbólico: remova-o` | a pasta dos bloqueios, em `DATA_DIR/auth`, foi trocada por um link |
| `FALHA: o vigia não abriu o soquete /dev/log: o FTP não sobe sem a contagem das senhas erradas` | o vigia não iniciou |
| `FALHA: o pure-authd não abriu o soquete /run/pure-authd.sock: o FTP não sobe sem o porteiro` | o `pure-authd` não iniciou |
| `FALHA: o pure-authd saiu: o container encerra para ninguém entrar sem a conferência do porteiro` (ou `o vigia saiu`, `o pure-ftpd saiu`, ou `o observador da lista do TLS saiu`) | um dos processos vigiados parou depois da subida; o Docker sobe o container de novo |

Não é falha, e o container sobe: `AVISO: FTP_TLS_MODE=0, FTP sem TLS: senhas e arquivos trafegam em texto puro. Só para equipamento sem suporte a TLS, em rede interna isolada.` (ou `FTP_TLS_MODE=1, TLS opcional: ...`). O aviso se repete a cada subida enquanto o modo estiver ligado. Com `FTP_TLS_EXCECOES=sim`, o aviso é `AVISO: FTP_TLS_EXCECOES=sim: <n> usuário(s) marcado(s) no painel entram sem TLS, com senha e arquivos em texto puro. ...`.

A correção de cada uma está em [Solução de problemas](solucao-de-problemas.md#o-container-nao-sobe). O modelo completo da subida está em [Arquitetura](arquitetura.md#subida).

</details>

---

<a name="ftp-saude"></a>

## 🩺 `ftp/saude.sh`

É o healthcheck do container do FTP, instalado como `/usr/local/sbin/allsafe-ftp-saude`. Não é chamado direto: o Docker o executa a cada 20 segundos.

<details>
<summary>Detalhe técnico — o que ele confere</summary>

Abre a porta de controle (`127.0.0.1:2121`, de dentro do container), espera até 4 segundos pela saudação do servidor e encerra a conexão com `QUIT`. Considera saudável a saudação `220` (pronto) e também a `421` (limite de conexões atingido: o servidor está cheio, mas atendendo). Porta fechada, ou aberta sem saudação, conta como falha: depois de cinco falhas seguidas o Docker marca o container como `unhealthy`. O teste não faz login e não usa senha. Antes de abrir a porta ele exige o soquete `/run/pure-authd.sock` e o `/dev/log`: sem o `pure-authd` ou sem o vigia, o FTP não conta como saudável.

Para rodar à mão: `docker compose exec ftp /usr/local/sbin/allsafe-ftp-saude; echo $?` (`0` = atendendo).

</details>

---

<a name="porteiro"></a>

## 🚪 `ftp/porteiro.sh`

É o porteiro do FTP, instalado na imagem como `/usr/local/sbin/allsafe-ftp-porteiro`. Não é chamado direto: o `pure-authd` o executa a cada entrada, antes da conferência da senha. Ele não confere senha: só decide se a entrada pode seguir para ela.

**Resultado esperado:** a entrada sem impedimento segue para a conferência da senha. O usuário com [bloqueio por tentativa](seguranca.md#bloqueio-por-tentativa) valendo para o endereço recebe `530`. Com o TLS por usuário valendo e algum usuário dispensado, a sessão sem TLS de quem não foi dispensado recebe `530`, e o log do container ganha a linha `porteiro: entrada sem TLS recusada: usuario=<nome> origem=<ip> (a senha enviada passou em texto puro: troque-a)`.

<details>
<summary>Detalhe técnico — o que ele responde</summary>

- Recebe do `pure-authd`, em variáveis de ambiente, o nome (`AUTHD_ACCOUNT`), se a sessão tem TLS (`AUTHD_ENCRYPTED`) e o endereço de origem (`AUTHD_REMOTE_IP`). A senha também chega em variável e **não** é lida, gravada nem registrada.
- Responde `auth_ok:0`, a resposta "não é comigo", quando nenhuma das duas regras recusa: o `pure-ftpd` segue para o PureDB, que confere a senha. Responde `auth_ok:-1`, a recusa definitiva, quando uma delas recusa: o cliente recebe `530` com a senha certa ou errada.
- **TLS por usuário**, só com a opção valendo (`FTP_TLS_EXCECOES=sim`, `FTP_TLS_MODE=2` e sem IP público aceito), que o entrypoint marca em `/run/allsafe/tls-por-usuario`: sem nenhum dispensado, o `pure-ftpd` recusa a sessão sem TLS antes da senha e o porteiro nem é chamado; com algum, a sessão sem TLS só segue quando o nome está em uma linha inteira de `/auth/sem-tls.lista`. Lista ausente ou ilegível conta como lista vazia: ninguém entra sem TLS. A recusa deixa uma marca em `/run/allsafe/recusa/`, para o vigia não a contar como senha errada.
- **Bloqueio por tentativa:** recusa quando existe o arquivo comum `/auth/bloqueios/<usuario>@<origem>` e a primeira linha dele começa por um número de até 12 dígitos maior que a hora atual. Arquivo vencido ou fora desse formato não bloqueia.
- Só vira caminho de arquivo ou linha de registro o nome dentro da regra `^[a-z_][a-z0-9_-]{0,31}$` e a origem em formato de endereço. No registro, o nome fora da regra vira `(nome fora da regra)` e a origem fora do formato vira `?`: o que o cliente mandou não vai cru para o log. A linha sai pela saída de erro do processo 1 do container, porque o `pure-authd` fecha a do script.

</details>

---

<a name="vigia"></a>

## 👁️ `ftp/vigia.pl`

É o vigia das entradas do FTP, instalado na imagem como `/usr/local/sbin/allsafe-ftp-vigia`. Não é chamado direto: o entrypoint o sobe antes do servidor. Ele conta as senhas erradas de cada endereço para cada usuário, grava o bloqueio que o porteiro aplica e escreve no log do container cada entrada e cada transferência. Também publica os contadores de rede e os recursos do container (processador, memória e processos, com os limites), que a aba Servidor do painel mostra.

**Resultado esperado:** na subida, `vigia: pronto: 5 senhas erradas do mesmo endereço bloqueiam o usuário para ele por 15 min; limite próprio do usuário em Editar, na aba Usuários do painel`, com os valores do `.env`. Depois, uma linha por entrada e por transferência no log do container:

| Linha | Quando |
|---|---|
| `vigia: entrada: usuario=<nome> origem=<ip>` | Entrada certa; a contagem daquele endereço para o usuário volta a zero |
| `vigia: entrada recusada: usuario=<nome> origem=<ip> senhas_erradas=<n> de <limite>` | Senha errada, somada |
| `vigia: entrada bloqueada: usuario=<nome> origem=<ip> senhas_erradas=<n> minutos=<m>` | A senha errada completou o limite e o bloqueio foi gravado |
| `vigia: entrada recusada pelo bloqueio: usuario=<nome> origem=<ip>` | Tentativa feita durante o bloqueio |
| `vigia: entrada recusada: usuario=<nome> origem=<ip> (bloqueio por tentativa desligado)` | O limite do usuário, ou o da stack, é `0` |
| `vigia: entrada recusada: usuario=<nome> origem=<ip> (não está no cadastro)` | Nome dentro da regra, sem usuário com ele |
| `vigia: entrada recusada: usuario=<nome> origem=<ip> (rede interna da stack: não conta para o bloqueio)` | Senha do usuário do FTP errada na tela do painel |
| `vigia: entrada recusada: nome fora da regra, origem=<ip>` | O nome enviado não cabe na regra dos nomes; ele não vai para o log |
| `vigia: envio: usuario=<nome> origem=<ip> bytes=<n> arquivo=<caminho>` | Arquivo recebido pelo FTP; o caminho é o de dentro do container, a partir de `/data` |
| `vigia: download: usuario=<nome> origem=<ip> bytes=<n> arquivo=<caminho>` | Arquivo baixado pelo FTP |
| `vigia: renomeado: usuario=<nome> origem=<ip> nomes=[<de>]->[<para>]` | Arquivo ou pasta renomeado ou movido pelo FTP; os nomes são os que o cliente enviou |
| `vigia: apagado: usuario=<nome> origem=<ip> arquivo=<caminho>` | Arquivo apagado pelo FTP |
| `vigia: entrega nao feita (<motivo>): usuario=<nome> arquivo=<caminho>` | O arquivo recebido em pasta com perfil Envio ou Leitura não pôde ser passado ao `ftpdata`: a pasta ou o arquivo sumiu, ou é link simbólico |

<details>
<summary>Detalhe técnico — como ele conta</summary>

- **De onde vem o aviso:** o `pure-ftpd` só avisa da senha errada pelo registro do sistema. O vigia abre o soquete `/dev/log`, só para o `root`, e lê cada linha que o servidor grava ali. A linha é conferida do início ao fim: o que o cliente digitou só aparece no fim dela, e só vira contagem o nome dentro da regra.
- **A senha não chega a ele:** o aviso traz o nome e o endereço.
- **Limite e prazo:** os do usuário, em `/auth/limites.lista` (`tentativas=` e `minutos=`), ou os da stack (`FTP_BLOQUEIO_TENTATIVAS` e `FTP_BLOQUEIO_MINUTOS`). O cadastro e a lista são relidos quando o arquivo muda.
- **Contagem:** na memória, por usuário e endereço, só das senhas erradas mais novas que os minutos de bloqueio; até 10.000 pares. Reiniciar o container zera a contagem em andamento e não tira bloqueio.
- **Bloqueio:** o arquivo `/auth/bloqueios/<usuario>@<endereco>`, `0600`, gravado por troca de nome, com até quando vale, desde quando e quantas senhas erradas; até 4.096 arquivos. De minuto em minuto, o vigia apaga os vencidos e os inválidos.
- **Rede:** a cada 5 s, soma os contadores das interfaces do container em `/proc/net/dev`, fora a `lo`, e grava uma linha de sete números em `/auth/rede.estado` (`0600`): instante, segundos do intervalo, bytes recebidos e enviados desde que o container subiu, bytes recebidos e enviados no intervalo, e erros e descartes. Grava por troca de nome, com a trava do cadastro (`/auth/.lock`), só quando os contadores mudam e mais uma vez quando o tráfego para; com a trava ocupada, aquela leitura não é publicada. Falha na leitura ou na gravação não para o vigia.
- **Recursos do container:** no mesmo ciclo de 5 s, lê o grupo de controle do container (`/sys/fs/cgroup`) e grava uma linha de doze números em `/auth/recursos.estado` (`0600`): instante, instante em que o vigia iniciou, milissegundos do intervalo, microssegundos de processador gastos nele, cota e período do limite de processador, memória em uso e limite, processos e limite, vezes em que o limite de processador segurou o container e vezes em que faltou memória. Limite `0` quer dizer sem limite. Publica nas duas primeiras leituras e, depois, quando o uso muda (1% de um núcleo, 1 MiB de memória, processos ou contadores) ou a cada minuto, do mesmo jeito que a rede: por troca de nome, com a trava do cadastro.
- **O que não conta:** endereço da rede interna da stack, recusa do porteiro por falta de TLS, tentativa durante o bloqueio, nome fora do cadastro e nome fora da regra.
- **Por que Perl:** a imagem do FTP não tem Python, e o `perl-base` já vem na imagem base do Debian. O vigia usa só os módulos dele, sem pacote novo.
- **Transferências:** o `pure-ftpd` avisa pelo mesmo registro de cada arquivo enviado, baixado, renomeado e apagado, e o vigia escreve a linha. O nome do arquivo vai por último, e o tamanho é lido do fim do aviso: um nome escolhido pelo cliente não se passa por outro campo. O aviso é reconhecido pelo começo, que é do servidor: um arquivo apagado cujo nome imita o fim de um envio continua registrado como apagado. Caractere de controle e de direção do texto vira `?`; nome em UTF-8 passa; o caminho é cortado em 400 caracteres. O que foi feito pelo painel fica na auditoria dele, não aqui.
- Aviso e erro do `pure-ftpd` seguem para o log do container como `vigia: pure-ftpd: <texto> origem=<ip>`; conexão, saída, pasta criada e pasta apagada não são repetidas.
- Se o vigia parar, o entrypoint encerra o container: sem ele, ninguém mais seria bloqueado.

</details>

---

<a name="painel-entrypoint"></a>

## 🖥️ `painel/entrypoint.sh`

Roda a cada início do container do painel. Não tem parâmetros: tudo vem das variáveis de [Configuração](configuracao.md#painel).

1. Recusa senha em variável, exige o segredo `/run/secrets/painel_admin_inicial_senha_hash` e confere o `PAINEL_ADMIN_USER` e o `SEGURANCA_CONTATO_EMAIL`.
2. Confere que `PAINEL_BIND_IP`, cada rede de `PAINEL_REDES_PERMITIDAS` e o `PAINEL_CERT_CN` (se for IP) são privados, ou públicos aceitos com `REDE_PERMITIR_IP_PUBLICO=sim`.
3. Ajusta dono e modo de `/painel` (`0700`, do `root`) e do arquivo de administradores (`0600`, do `root`), também depois de uma restauração, e gera o certificado autoassinado do painel quando ele falta, quando os endereços mudam ou quando faltam menos de 30 dias para vencer.
4. Prepara a pasta `/nginx` (`0750`, grupo `10001`, o do nginx): copia o certificado e a chave para `/nginx/tls`, apaga o soquete da subida anterior e cria `/nginx/estado` (`0700`, do usuário do nginx), a pasta em que o nginx publica os recursos do container dele.
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
| `FALHA: PAINEL_PROXY_CONFIAVEL: …` | a lista de proxies tem rede inteira, valor que não é IPv4, endereço público sem a opção de IP público, endereço fora de `PAINEL_REDES_PERMITIDAS` ou mais de 8 endereços |
| `FALHA: PAINEL_BIND_IP=… não é um endereço IPv4 de servidor` (ou `PAINEL_CERT_CN`) | com a opção em `sim`, o valor é `0.0.0.0`, multicast ou reservado |
| `FALHA: PAINEL_REDES_PERMITIDAS: '…' não é uma rede IPv4 aceita` | com a opção em `sim`, a rede é mais larga que `/8`, como `0.0.0.0/0` |
| `FALHA: REDE_PERMITIR_IP_PUBLICO deve ser 'nao' ou 'sim'` | a opção tem outro valor |
| `FALHA: PAINEL_REDES_PERMITIDAS está vazia` | a variável chegou vazia ao container |
| `FALHA: PAINEL_ACESSO_USUARIOS_FTP deve ser 'sim' ou 'nao'` | a entrada dos usuários do FTP tem outro valor |
| `FALHA: PAINEL_AVISO_EXPOSICAO deve ser 'sim' ou 'nao'` | o aviso de exposição na tela tem outro valor |
| `FALHA: FTP_TLS_EXCECOES deve ser 'nao' ou 'sim'` | a exceção de TLS por usuário tem valor inválido, a mesma conferência do container do FTP |
| `FALHA: PAINEL_ADMIN_USER inválido: ...` | o nome do primeiro administrador tem maiúscula, espaço, mais de 32 caracteres ou caractere fora de `a-z`, `0-9`, `_` e `-` |
| `FALHA: SEGURANCA_CONTATO_EMAIL inválido: ...` | o contato de segurança está preenchido e não é um endereço de e-mail só: tem `mailto:`, espaço, dois endereços, `%`, ou domínio sem ponto |
| `FALHA: FTP_MAX_CLIENTS deve ser um inteiro maior que zero` | o limite de sessões do FTP, que o painel usa para gravar a senha com o custo do porte, não é um inteiro de 1 a 99999 |
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
5. Põe em segundo plano a publicação dos recursos do container: a cada 5 s lê o grupo de controle dele e grava em `/estado/recursos.estado` (`0600`) a mesma linha de doze números do vigia do ftp, quando o uso muda ou a cada minuto. Sem a pasta `/estado`, avisa no log e sobe do mesmo jeito.
6. Testa a configuração e executa o `nginx`.

**Resultado esperado:** a linha `nginx pronto em 8443/tcp (HTTPS), à frente do painel; redes permitidas: ...` no log do container.

<details>
<summary>Detalhe técnico — mensagens de falha</summary>

| Mensagem | Quando |
|---|---|
| `FALHA: o nginx desta stack não roda como root: confira 'user' no compose.yaml` | o serviço foi alterado para subir como root |
| `FALHA: PAINEL_REDES_PERMITIDAS está vazia` | a variável chegou vazia ao container |
| `FALHA: PAINEL_REDES_PERMITIDAS: '…' não é rede privada. Por padrão esta stack é só para rede interna.` | a lista tem rede pública ou `0.0.0.0/0`, com a opção de IP público em `nao` |
| `FALHA: PAINEL_PROXY_CONFIAVEL: …` | a lista de proxies tem rede inteira, valor que não é IPv4, endereço público sem a opção de IP público, endereço fora de `PAINEL_REDES_PERMITIDAS` ou mais de 8 endereços |
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

- Aceita `add|passwd|pasta|del|list|tls-dispensar|tls-exigir|tls-lista [usuario] [pasta] [perfil]`, com a pasta só no `add` e no `pasta` e o perfil só no `add`, `perfil <usuario> [completo|envio|leitura]`, `ajustar`, e `limites <usuario> [sessoes=N] [download=KB] [envio=KB] [horario=HHMM-HHMM] [baixar=N]`, e valida o nome (`^[a-z_][a-z0-9_-]{0,31}$`).
- A pasta, quando informada, tem até 4 níveis separados por `/`; cada nível casa com `[A-Za-z0-9_][A-Za-z0-9._-]{0,63}`. Fora disso, responde `Pasta invalida: ...` e sai com código `1`, antes de ler a senha.
- Lê a senha do `stdin` e recusa menos de 12 caracteres com `Senha deve ter pelo menos 12 caracteres`.
- `add` recusa nome que já existe (`Usuario ja existe`), confere a pasta nível por nível (link simbólico ou arquivo no caminho: `Pasta recusada: ...`), cria os níveis que faltam com dono `ftpdata` e modo `0750` e registra o usuário com `pure-pw useradd`, com a pasta como diretório do `chroot`. Sem a pasta, usa `/data/<usuario>`.
- Se outro usuário tem a mesma pasta, uma de cima ou uma de dentro, o `add` conclui e escreve `Aviso: /data/<pasta> e dividida com o usuario <nome> ...`, uma linha por usuário.
- `add` e `passwd` passam ao `pure-pw` a opção `-C` com o `FTP_MAX_CLIENTS` do container, que define o custo do hash `argon2id` da senha; valor que não é inteiro maior que zero para com `FTP_MAX_CLIENTS deve ser um inteiro maior que zero` e código `1`.
- O perfil é a identidade de sistema gravada no cadastro: `completo` é `ftpdata:ftpdata`, `envio` é `ftpenvio:ftpdata` e `leitura` é `ftpleitura:ftpleitura`. `add` sem perfil cria `completo`; perfil fora dos três para com `Perfil invalido: use completo, envio ou leitura` e código `1`, antes de ler a senha.
- `perfil` sem o nome do perfil mostra o do usuário. Com ele, grava só o uid e o gid do usuário, com `pure-pw usermod -u -g`: a senha, a pasta e os arquivos não mudam.
- Depois de `add`, `perfil`, `pasta` e `del`, o modo de cada pasta de usuário é refeito por quem a alcança: `0750` só com `completo`, mais gravação do grupo e o bit de permanência com um `envio` (`1770`), mais leitura para os outros com um `leitura` (`0755` ou `1775`). As pastas de dentro acompanham quando o modo muda; a pasta que saiu do cadastro volta ao que os outros usuários pedem.
- `ajustar` é da partida do serviço `ftp`: refaz o modo das pastas e passa ao `ftpdata` as pastas e os arquivos de um só nome que ainda são do `ftpenvio`. Não é para uso com sessão aberta.
- `passwd` usa `pure-pw passwd`; `del` usa `pure-pw userdel`, **não** apaga a pasta e diz qual é ela. Quem apaga a pasta junto com o usuário é o painel, depois do `del`: [Painel web](painel.md#usuarios).
- `pasta` exige usuário que existe (`Usuario nao existe: <nome>`), confere e cria a pasta como o `add` e grava só o diretório do usuário, com `pure-pw usermod -d`: a senha e os demais campos do cadastro não mudam, e nenhum arquivo é movido nem apagado. Avisa da pasta dividida como o `add`.
- `passwd` do usuário inicial (`FTP_USER`) grava também `/auth/senha-inicial.trocada` (`0600`), só com o nome dele: é o que faz o entrypoint manter essa senha enquanto o segredo não mudar.
- `del` do usuário inicial grava `/auth/usuario-inicial.criado` e apaga a marca da senha: o entrypoint não o recria. `add` com o nome dele grava as duas marcas: o usuário volta com a senha informada.
- `tls-dispensar` e `tls-exigir` põem e tiram o nome de `/auth/sem-tls.lista` (`0600`), um nome por linha, em ordem. Só aceitam usuário que existe: senão, `Usuario nao existe: <nome>` e código `1`. A lista é gravada em um arquivo ao lado e trocada de nome, para nunca ser lida pela metade, e a cada gravação saem dela os nomes que já não estão no cadastro. `del` tira o usuário da lista; `tls-lista` a mostra. O FTP relê a lista a cada segundo: a alteração vale em instantes, sem reiniciar.
- `limites` exige usuário que existe e confere todos os pares antes de gravar: `sessoes` de 1 a 99999, `download` e `envio` de 1 a 10000000, `baixar` de 1 a 8 e `horario` em `HHMM-HHMM`, com início diferente do fim. Valor fora da regra para com `Limite invalido: ...` e código `1`; chave desconhecida ou par sem `=`, com o uso e código `2`. Sessões, taxas e horário vão para o cadastro com `pure-pw usermod` (`-y`, `-t`, `-T` e `-z`), e valor vazio tira o limite; `baixar` vai para `/auth/limites.lista` (`0600`), uma linha `<usuario> baixar=<n>` por usuário, gravada ao lado e trocada de nome como a lista do TLS. Sem par nenhum, mostra os limites, com as taxas em KB por segundo e o horário com quatro dígitos de cada lado. `del` tira o usuário da lista.
- Depois de cada mudança, regenera o `pureftpd.pdb` com `pure-pw mkdb` e mantém os dois arquivos em `0600`.
- Antes de alterar, pega a trava `/auth/.lock` (`flock`, espera até 30 segundos): o FTP, o `manage-user.sh` e o painel nunca gravam ao mesmo tempo.
- `list` passa o arquivo pela variável `PURE_PASSWDFILE`, porque o `pure-pw list` não aceita `-f` logo depois da ação.
- Uso inválido: mostra as formas aceitas, `Uso: ... add|passwd|pasta|del|list|tls-dispensar|tls-exigir|tls-lista [usuario] [pasta] [perfil]`, `... perfil <usuario> [completo|envio|leitura]`, `... limites <usuario> [sessoes=N] [download=KB] [envio=KB] [horario=HHMM-HHMM] [baixar=N] [tentativas=N] [minutos=N]`, `... bloqueios [usuario]` e `... desbloquear <usuario> [origem]`, e sai com código `2`.

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
