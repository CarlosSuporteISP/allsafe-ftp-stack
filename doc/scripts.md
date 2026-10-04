# ⌨️ Scripts — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [📚 Índice da documentação](README.md)

## 💡 Em poucas palavras

A stack tem cinco scripts. Três você roda no host: um sobe o servidor, outro cuida dos usuários e o terceiro confere se está tudo certo. Os outros dois ficam dentro do container e são chamados pelos primeiros; você não os executa direto.

<!-- diagrama: diagramas/scripts-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    usuario@{ shape: person, label: "👤 Usuário" }
    host@{ shape: console, label: "⌨️ deploy.sh, manage-user.sh<br>e validate.sh, no host" }
    compose@{ shape: rect, label: "🐳 Docker Compose" }
    interno@{ shape: console, label: "⌨️ entrypoint e allsafe-ftp-user<br>dentro do container" }
    ftp@{ shape: rect, label: "⚙️ Pure-FTPd<br>allsafe-ftp" }
    fim@{ shape: stadium, label: "🏁 serviço operando" }

    usuario --> host --> compose --> interno --> ftp --> fim
```

<sub>📐 Nível 1 · Diagrama · 🔍 aproximar e mover: controles no canto do diagrama · 📁 [fonte](diagramas/)</sub>

**🧭 Sequência:** 👤 Usuário ➜ ⌨️ scripts do host (`deploy.sh`, `manage-user.sh`, `validate.sh`) ➜ 🐳 Docker Compose ➜ ⌨️ entrypoint e `allsafe-ftp-user` ➜ ⚙️ Pure-FTPd (`allsafe-ftp`) ➜ 🏁 serviço operando

---

<details>
<summary>🧭 Sumário — clique para expandir</summary>

[📋 Visão geral](#visao-geral) · [🚀 `deploy.sh`](#deploy) · [👤 `manage-user.sh`](#manage-user) · [🔑 `scripts/painel-senha.sh`](#painel-senha) · [🧪 `scripts/validate.sh`](#validate) · [⚙️ `scripts/entrypoint.sh`](#entrypoint) · [🖥️ `scripts/painel-entrypoint.sh`](#painel-entrypoint) · [👥 `scripts/ftp-user.sh`](#ftp-user) · [🧩 Scripts de apoio](#apoio)

</details>

---

<a name="visao-geral"></a>

## 📋 Visão geral

| Script | Onde roda | Para que serve |
|---|---|---|
| [`deploy.sh`](../deploy.sh) | host | Instala, reaplica, atualiza ou remove a stack em um comando, sem perguntas |
| [`manage-user.sh`](../manage-user.sh) | host | Atalho para criar, trocar senha, remover e listar usuários FTP |
| [`scripts/painel-senha.sh`](../scripts/painel-senha.sh) | host | Troca a senha do painel, gravando só o hash |
| [`scripts/validate.sh`](../scripts/validate.sh) | host | Checagem de sintaxe, do Compose de todos os perfis e, opcionalmente, do container no ar |
| [`scripts/entrypoint.sh`](../scripts/entrypoint.sh) | container | Provisiona o usuário inicial e o certificado e executa o `pure-ftpd` |
| [`scripts/painel-entrypoint.sh`](../scripts/painel-entrypoint.sh) | container do painel | Confere a rede privada, gera o certificado do painel e executa o servidor web |
| [`scripts/ftp-user.sh`](../scripts/ftp-user.sh) | os dois containers | Gestão de usuários no PureDB, chamada pelo `manage-user.sh` e pelo painel |
| [`scripts/rede-privada.sh`](../scripts/rede-privada.sh) | host e containers | Funções que conferem se um IP ou uma rede é privado; carregado pelos outros scripts |
| [`scripts/ambiente.sh`](../scripts/ambiente.sh) | host | Função que lê uma chave do `.env` sem executar o arquivo; carregado pelos outros scripts |

Os scripts da pasta [`scripts/`](../scripts/) que rodam em container são copiados para a imagem pelo [`Dockerfile`](../Dockerfile).

---

<a name="deploy"></a>

## 🚀 `deploy.sh`

```bash
./deploy.sh [--size small|medium|large] [--atualizar] [--check-only]
./deploy.sh --remover [--apagar-dados [--sim]]
```

| Parâmetro | Efeito |
|---|---|
| sem opção | Instala ou reaplica: cria o `.env`, as pastas e as senhas que faltarem, sobe os containers e espera ficarem `healthy` |
| `--size` | Grava no `.env` os limites de `profiles/<perfil>.env` e o nome em `FTP_PROFILE`. Sem a opção, o `.env` fica como está |
| `--atualizar` | Reconstrói as duas imagens sem cache, com os pacotes atuais do Debian, e recria os containers |
| `--check-only` | Só valida o perfil, a rede privada e o Compose; não cria nem sobe nada |
| `--remover` | Derruba os containers e a rede; dados, segredos, `.env` e imagens ficam |
| `--apagar-dados` | Com `--remover`: apaga também `dados/`, `auth/`, `certs/` e `painel/` de `DATA_DIR`, depois de pedir para digitar `apagar` |
| `--sim` | Com `--apagar-dados`: dispensa a confirmação (obrigatório quando não há terminal) |
| `-h`, `--help` | Mostra o uso |

**Resultado esperado:** o comando só termina com `allsafe-ftp` e `allsafe-ftp-painel` em `healthy` e fecha com `Pronto: FTP e painel no ar (healthy), perfil '<perfil>'.`, os endereços do FTP e do painel e o arquivo onde está cada senha (a senha em si nunca aparece). Com `--remover`: `Removidos os containers e a rede. Os dados continuam em <DATA_DIR>.` Com `--check-only`: `OK: perfil '<perfil>', rede privada e compose validados; nada foi alterado.`

<details>
<summary>🔬 Detalhe técnico — comportamento e códigos de saída</summary>

- **Não faz pergunta.** A única confirmação é a do `--apagar-dados`, dispensada com `--sim`.
- **Requisitos conferidos antes de agir:** `docker`, o plugin `docker compose`, o serviço do Docker respondendo e as portas livres (a do FTP, a do painel e a faixa passiva, no endereço de bind). As portas que a própria stack já publica não contam. Falhou: `ERRO: ...` e código `1`, sem subir nada.
- Na primeira execução sem `.env`, copia o [`.env.example`](../.env.example), aplica `0600`, avisa `Criado .env a partir do .env.example: tudo em 127.0.0.1, só este servidor acessa.` e **segue**. Com `--check-only` nada é criado: a validação usa o `.env.example`.
- **Idempotente:** rodado de novo sem mudança, não recria container, não troca senha e não regrava o `.env`.
- Se `.secrets/ftp_password.txt` estiver vazio ou ausente, gera uma senha forte (`0600`): veja [🔑 Segredos](segredos.md).
- Recusa `FTP_PASSWORD`, `PAINEL_PASSWORD` e `PAINEL_PASSWORD_HASH` no `.env`, e qualquer `FTP_BIND_IP`, `FTP_PUBLIC_IP`, `PAINEL_BIND_IP`, `PAINEL_REDES_PERMITIDAS` ou `PAINEL_CERT_CN` (em forma de IP) fora de rede privada.
- Se `.secrets/painel_password_hash.txt` não existir, gera a senha inicial do painel em `.secrets/painel_password.txt` (`0600`) e grava o hash dela, chamando o `scripts/painel-senha.sh --inicial` depois de construir a imagem.
- Opção desconhecida ou perfil inexistente: mensagem `Opção inválida: ...` ou `ERRO: perfil inexistente: ...` e código `64`.
- O Compose é sempre chamado só com `--env-file .env`. O perfil não é um segundo arquivo na subida: `--size` grava os valores dele no `.env`, por isso um `docker compose up -d` direto mantém os mesmos limites.
- Combinação inválida (`--remover` com `--size`, `--apagar-dados` sem `--remover`, `--sim` sem `--apagar-dados`): `Opção inválida: ...`, o uso e código `64`.
- `--apagar-dados` apaga as pastas por um container descartável sem rede (os arquivos pertencem ao usuário do container, não ao do host) e só aceita `DATA_DIR` com pelo menos dois níveis de pasta.
- Constrói as duas imagens com `docker compose build` (`build --no-cache` com `--atualizar`), sobe com `docker compose up -d --wait --wait-timeout 180` e termina mostrando o `docker compose ps` e o resumo. Se algum container não ficar `healthy` no prazo: `ERRO: os containers não ficaram healthy. Veja o motivo com: docker compose logs --tail 50 ftp painel`.

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

<a name="painel-senha"></a>

## 🔑 `scripts/painel-senha.sh`

```bash
./scripts/painel-senha.sh            # pergunta a senha nova duas vezes, sem ecoar
./scripts/painel-senha.sh --gerar    # cria uma senha forte e mostra uma única vez
```

**Resultado esperado:** `Hash gravado em ./.secrets/painel_password_hash.txt; painel reiniciado e sessões abertas encerradas.`

A senha tem de ter no mínimo 12 caracteres. Só o hash é gravado; o arquivo `.secrets/painel_password.txt` da instalação é apagado. Quando usar: [🖥️ Painel web](painel.md#senha).

<details>
<summary>🔬 Detalhe técnico — como o hash é calculado</summary>

- Lê `SECRETS_DIR` e `PAINEL_IMAGE` do `.env` (ou do arquivo em `ENV_FILE`), sem executar o arquivo.
- A senha também pode vir pela entrada padrão: `./scripts/painel-senha.sh < arquivo`.
- O hash `scrypt` é calculado **dentro da imagem do painel**, em um container descartável sem rede, com a raiz somente leitura e sem capabilities (`docker run --rm -i --network none --read-only --cap-drop ALL`). O host não precisa de Python.
- O hash é gravado por cima do mesmo arquivo: o segredo é um _bind mount_ de arquivo, e trocar o arquivo por outro faria o container continuar vendo o antigo.
- Depois de gravar, reinicia o serviço `painel` (encerra as sessões). Se o painel não estiver rodando, o hash vale na próxima subida.
- `--inicial` é de uso do `deploy.sh`: não reinicia nada e mantém o `painel_password.txt`.
- Opção desconhecida: código `64`. Falta do `.env` ou da imagem: `ERRO: ... rode ./deploy.sh primeiro`, código `1`.

</details>

---

<a name="validate"></a>

## 🧪 `scripts/validate.sh`

```bash
./scripts/validate.sh            # bash -n dos scripts e compose config de todos os perfis
./scripts/validate.sh --runtime  # também exige o container running e healthy e o usuário no PureDB
```

**Resultado esperado:** `painel/servidor.py OK`, `compose OK com <perfil>.env` para cada perfil e, no fim, `Validacao FTP concluida.` Qualquer falha encerra com código diferente de zero.

<details>
<summary>🔬 Detalhe técnico — o que cada modo confere</summary>

| Modo | Confere |
|---|---|
| sem parâmetro | `bash -n` em `deploy.sh`, `manage-user.sh` e `scripts/*.sh`; a sintaxe de `painel/servidor.py`, se o host tiver `python3`; `docker compose config --quiet` com `.env.example` e cada arquivo de `profiles/` |
| `--runtime` | tudo acima, mais: serviço `ftp` em `running`, saúde `healthy` e `pure-pw show` do usuário inicial |

> ⚠️ No modo `--runtime`, o usuário conferido vem da variável `FTP_USER` **do shell**, com padrão `transfer`; o script não lê o `.env`. Se o seu usuário inicial tem outro nome, rode `FTP_USER=<usuario> ./scripts/validate.sh --runtime`.

</details>

---

<a name="entrypoint"></a>

## ⚙️ `scripts/entrypoint.sh`

Roda a cada início do container. Não tem parâmetros: tudo vem das variáveis de [⚙️ Configuração](configuracao.md).

1. Confere que `FTP_BIND_IP` e `FTP_PUBLIC_IP` são IPs privados ([`rede-privada.sh`](../scripts/rede-privada.sh)), lê a senha do segredo `/run/secrets/ftp_password`, ajusta dono e modo de `/data`, `/auth` e `/etc/ssl/private` e cria ou atualiza o usuário inicial `FTP_USER` (recusa senha com menos de 12 caracteres).
2. Gera um certificado autoassinado para `FTP_CERT_CN` se `DATA_DIR/certs` estiver vazia, e grava a parte pública dele em `/auth/ftp-cert.pem`.
3. Executa o `pure-ftpd` com TLS, `chroot`, limites e faixa passiva do `.env`.

**Resultado esperado:** a linha `FTP pronto em 2121/tcp; TLS=2; passivo=30000-30049` no log do container.

<details>
<summary>🔬 Detalhe técnico — processo 1 e mensagens de falha</summary>

Com `init: true`, o processo 1 do container é o `tini`; o entrypoint é iniciado por ele e termina com `exec`, deixando o `pure-ftpd` no seu lugar.

Quando uma validação falha, o script sai com `FALHA: <motivo>`:

| Mensagem | Quando |
|---|---|
| `FALHA: segredo /run/secrets/ftp_password ausente` | `.secrets/ftp_password.txt` não existe: rode o `deploy.sh` |
| `FALHA: FTP_PASSWORD não é mais aceita` | há senha em variável de ambiente; ela só é lida do segredo |
| `FALHA: FTP_BIND_IP=… não é IP privado` (ou `FTP_PUBLIC_IP`) | o endereço está fora das faixas privadas; o container reinicia em laço até a correção |
| `FALHA: FTP_USER invalido` | o nome não segue `^[a-z_][a-z0-9_-]{0,31}$` |
| `FALHA: a senha FTP deve ter pelo menos 12 caracteres` | senha curta ou arquivo vazio |
| `FALHA: faixa passiva invalida` | início ou fim não numéricos |
| `FALHA: faixa passiva fora dos limites` | abaixo de `1024`, acima de `65535` ou invertida |
| `FALHA: FTP_TLS_MODE deve ser 1, 2 ou 3` | valor fora da lista |

A correção de cada uma está em [🚨 Solução de problemas](solucao-de-problemas.md#o-container-nao-sobe). O modelo completo da subida está em [🏗️ Arquitetura](arquitetura.md#subida).

</details>

---

<a name="painel-entrypoint"></a>

## 🖥️ `scripts/painel-entrypoint.sh`

Roda a cada início do container do painel. Não tem parâmetros: tudo vem das variáveis de [⚙️ Configuração](configuracao.md#painel).

1. Recusa senha em variável e exige o segredo `/run/secrets/painel_password_hash`.
2. Confere que `PAINEL_BIND_IP`, cada rede de `PAINEL_REDES_PERMITIDAS` e o `PAINEL_CERT_CN` (se for IP) são privados.
3. Ajusta dono e modo de `/painel` (`0700`, do `root`) e gera o certificado autoassinado do painel quando ele falta, quando os endereços mudam ou quando faltam menos de 30 dias para vencer.
4. Executa o servidor [`painel/servidor.py`](../painel/servidor.py).

**Resultado esperado:** a linha `Painel pronto em 8443/tcp (HTTPS); sessão de 15 min; redes permitidas: ...` no log do container.

<details>
<summary>🔬 Detalhe técnico — mensagens de falha</summary>

| Mensagem | Quando |
|---|---|
| `FALHA: PAINEL_PASSWORD não é aceita` (ou `PAINEL_PASSWORD_HASH`) | há senha ou hash em variável de ambiente; o painel só lê o segredo |
| `FALHA: segredo /run/secrets/painel_password_hash ausente` | `.secrets/painel_password_hash.txt` não existe: rode o `deploy.sh` |
| `FALHA: PAINEL_BIND_IP=… não é IP privado` (ou `PAINEL_CERT_CN`) | endereço fora das faixas privadas |
| `FALHA: PAINEL_REDES_PERMITIDAS: '…' não é rede privada` | a lista tem rede pública ou `0.0.0.0/0` |
| `FALHA: PAINEL_CERT_CN inválido` | nome com maiúscula, espaço ou caractere fora de `a-z`, `0-9`, `.` e `-` |
| `FALHA: pastas /auth e /data ausentes` | o painel subiu sem as pastas do serviço `ftp` |
| `FALHA: não foi possível gerar o certificado do painel` | `DATA_DIR/painel` sem espaço ou sem permissão de escrita |

O certificado é EC P-256, válido por 825 dias. O arquivo `painel-san.txt`, ao lado dele, marca que foi gerado pela stack: sem esse arquivo, o certificado é tratado como próprio e nunca é refeito. Veja [🖥️ Painel web](painel.md#certificado).

</details>

---

<a name="ftp-user"></a>

## 👥 `scripts/ftp-user.sh`

Instalado nas duas imagens como `/usr/local/sbin/allsafe-ftp-user`. Não é chamado diretamente: use o [`manage-user.sh`](../manage-user.sh) ou o [painel](painel.md#usuarios).

<details>
<summary>🔬 Detalhe técnico — o que ele faz dentro do container</summary>

- Aceita `add|passwd|del|list [usuario]` e valida o nome (`^[a-z_][a-z0-9_-]{0,31}$`).
- Lê a senha do `stdin` e recusa menos de 12 caracteres com `Senha deve ter pelo menos 12 caracteres`.
- `add` cria `/data/<usuario>` com dono `ftpdata` e modo `0750` e registra o usuário com `pure-pw useradd`.
- `passwd` usa `pure-pw passwd`; `del` usa `pure-pw userdel` e **não** apaga a pasta.
- Depois de cada mudança, regenera o `pureftpd.pdb` com `pure-pw mkdb` e mantém os dois arquivos em `0600`.
- Antes de alterar, pega a trava `/auth/.lock` (`flock`, espera até 30 segundos): o FTP, o `manage-user.sh` e o painel nunca gravam ao mesmo tempo.
- `list` passa o arquivo pela variável `PURE_PASSWDFILE`, porque o `pure-pw list` não aceita `-f` logo depois da ação.
- Uso inválido: mostra `Uso: ... add|passwd|del|list [usuario]` e sai com código `2`.

</details>

---

<a name="apoio"></a>

## 🧩 Scripts de apoio

Não são executados: outros scripts os carregam com `source`.

| Script | Função | Quem usa |
|---|---|---|
| [`scripts/rede-privada.sh`](../scripts/rede-privada.sh) | `ip_privado`, `cidr_privado` e `exigir_ip_privado`: aceitam só `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12` e `192.168.0.0/16` | `deploy.sh`, `entrypoint.sh` e `painel-entrypoint.sh` |
| [`scripts/ambiente.sh`](../scripts/ambiente.sh) | `env_valor <chave> [padrão]`: lê uma chave do `.env` sem executar o arquivo; a última ocorrência vale, como no Compose. `env_gravar <chave> <valor>`: troca a linha da chave ou acrescenta no fim, sem regravar quando o valor já é o pedido | `deploy.sh` e `painel-senha.sh` |

---

⬅️ [🔑 Segredos](segredos.md) · 🏠 [Documentação](README.md) · ➡️ [🧰 Operação](operacao.md)
