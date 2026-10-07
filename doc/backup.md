# ♻️ Backup e restauração — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [Índice da documentação](README.md)

## 💡 Em poucas palavras

Um comando guarda tudo o que a stack tem de seu: os arquivos enviados pelos equipamentos, os usuários, os certificados e o histórico do painel. O resultado é um arquivo só, com data e hora no nome, gravado em `BACKUP_DIR`. Outro comando devolve a stack ao estado desse arquivo e, antes de trocar qualquer coisa, guarda o estado atual, para a restauração poder ser desfeita. As senhas de `.secrets/` e o `.env` ficam de fora: guarde-os à parte.

<!-- diagrama: diagramas/backup-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    origem@{ shape: lin-cyl, label: "DATA_DIR<br>dados, auth, certs e painel" }
    backup@{ shape: console, label: "scripts/backup.sh<br>lê por container sem rede" }
    copia@{ shape: doc, label: "BACKUP_DIR<br>cópia .tar.gz e soma sha256" }
    restaurar@{ shape: console, label: "scripts/restaurar.sh<br>para, guarda o atual e troca" }
    destino@{ shape: lin-cyl, label: "DATA_DIR<br>conteúdo da cópia" }
    fim@{ shape: stadium, label: "stack de volta" }

    origem --> backup --> copia --> restaurar --> destino --> fim
```

<sub>Nível 1 · Diagrama · [fonte](diagramas/)</sub>

**Sequência:** `DATA_DIR` (`dados`, `auth`, `certs` e `painel`) ➜ `scripts/backup.sh` ➜ `BACKUP_DIR` (cópia `.tar.gz` e soma `.sha256`) ➜ `scripts/restaurar.sh` ➜ `DATA_DIR` (conteúdo da cópia) ➜ stack de volta

---

<details>
<summary>Sumário — clique para expandir</summary>

[O que entra na cópia](#o-que-entra) · [Fazer a cópia](#fazer) · [Restaurar](#restaurar) · [Desfazer uma restauração](#desfazer) · [Guardar o `.env` e os segredos](#segredos) · [Restaurar em outro servidor](#outro-servidor) · [Cópia automática e limpeza](#automatica)

</details>

---

<a name="o-que-entra"></a>

## 📦 O que entra na cópia

| Pasta de `DATA_DIR` | O que guarda | Entra na cópia |
|---|---|---|
| `dados/` | Arquivos enviados pelos equipamentos, uma pasta por usuário | Sim |
| `auth/` | Usuários do FTP, com o hash de cada senha, os limites próprios de cada um, a lista de quem está dispensado do TLS e os bloqueios por tentativa em vigor | Sim |
| `certs/` | Certificado e chave privada do FTP | Sim |
| `painel/` | Certificado e chave privada do painel, os administradores (nome e hash da senha) e o `auditoria.log` | Sim |
| `nginx/` | Soquete do painel e cópia do certificado, refeitos a cada subida | Não |

Ficam fora, e precisam ser guardados à parte: o `.env` e a pasta `.secrets/`. Veja [Guardar o `.env` e os segredos](#segredos).

> ⚠️ A cópia contém o hash das senhas dos usuários e as chaves privadas dos certificados. Trate o arquivo como dado sensível: `BACKUP_DIR` nasce com modo `0700` e cada cópia com `0600`. Uma cópia que fica só no mesmo servidor não protege contra a perda do servidor: leve o `.tar.gz` e o `.sha256` para outra máquina ou mídia, com o mesmo cuidado.

---

<a name="fazer"></a>

## 💾 Fazer a cópia

A stack pode ficar no ar; os equipamentos continuam enviando durante a cópia.

```bash
./scripts/backup.sh                          # grava a cópia em BACKUP_DIR
./scripts/backup.sh --rotulo antes-da-troca  # o mesmo, com um texto no nome do arquivo
./scripts/backup.sh --listar                 # mostra as cópias que existem
```

**Resultado esperado:**

```text
Cópia gravada: <BACKUP_DIR>/allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz (<tamanho>, <n> itens)
Fora da cópia: .env e os segredos de ./.secrets. Guarde-os à parte (doc/backup.md).
Restaurar: ./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz
```

Ao lado de cada cópia fica um arquivo `.sha256`, com a soma que a restauração confere antes de usar a cópia. O `--listar` mostra `Cópias em <BACKUP_DIR>:` e uma linha por arquivo, com o tamanho; sem cópia nenhuma, `Nenhuma cópia em <BACKUP_DIR>.`

O rótulo aceita letras minúsculas, números e hífen, até 40 caracteres. A cópia ocupa perto do tamanho de `DATA_DIR/dados` depois de comprimido: confira o espaço livre em `BACKUP_DIR` antes da primeira.

<details>
<summary>Detalhe técnico — como a cópia é feita e códigos de saída</summary>

- **Quem lê é um container descartável**, porque parte dos arquivos pertence ao `root` e ao usuário do FTP: `docker run --rm --network none --read-only --cap-drop ALL --cap-add DAC_READ_SEARCH`, com `DATA_DIR` montada só para leitura. O container não tem rede e não grava em `DATA_DIR`.
- **A lista de usuários entra inteira:** `auth/` é copiada com a mesma trava que o painel e o `manage-user.sh` usam (`/auth/.lock`, espera de até 30 segundos) e a trava é solta em seguida. Uma alteração de usuário nunca fica pela metade na cópia.
- **O arquivo só aparece pronto:** a gravação é feita em `<nome>.parcial` e renomeada no fim. Se o comando for interrompido, o parcial é apagado.
- **Dono e modo preservados:** o `tar` grava os números de usuário e grupo (`--numeric-owner`), e a restauração os devolve iguais.
- **Nome do arquivo:** `<STACK_NAME>-AAAAMMDD-HHMMSS[-rótulo].tar.gz`.
- **Sem rotação:** o script não apaga cópia antiga. Veja [Cópia automática e limpeza](#automatica).
- **Outra instalação:** `ENV_FILE=<arquivo> ./scripts/backup.sh` copia a instalação daquele arquivo de ambiente.

| Saída | Significado |
|---|---|
| `0` | cópia gravada. Com `AVISO: algum arquivo mudou enquanto era lido`, um envio estava em andamento: a cópia vale, mas aquele arquivo pode estar incompleto |
| `1` | nada foi gravado. A mensagem `ERRO:` diz o motivo: `.env` ou imagem ausentes (rode o `./deploy.sh`), `DATA_DIR/auth` inexistente, `BACKUP_DIR` dentro de `DATA_DIR` ou falha na leitura |
| `64` | opção inválida, rótulo fora do formato ou `--rotulo` sem texto |

</details>

---

<a name="restaurar"></a>

## 🔁 Restaurar

A restauração **substitui** o conteúdo atual de `dados/`, `auth/`, `certs/` e `painel/` pelo da cópia. A stack para durante a troca e sobe de novo ao final; nesse intervalo os equipamentos não conseguem enviar.

```bash
./scripts/restaurar.sh --listar                                        # escolha a cópia
./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz        # pede para digitar 'restaurar'
./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz --sim  # sem pergunta, para automação
```

A cópia pode ser informada só pelo nome, procurado em `BACKUP_DIR`, ou pelo caminho completo.

**Resultado esperado:**

```text
Cópia: <BACKUP_DIR>/allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz (<tamanho>, <n> itens, soma sha256 conferida)
Parando a stack...
Estado atual guardado em: <BACKUP_DIR>/allsafe-ftp-stack-AAAAMMDD-HHMMSS-antes-da-restauracao.tar.gz
Subindo a stack...
Restaurado e no ar (healthy).
Usuários, arquivos, certificados, administradores do painel e auditoria voltaram ao estado da cópia.
A senha do usuário inicial do FTP é a de ./.secrets, que não faz parte da cópia, ou a trocada pelo painel, se a cópia a trazia.
Desfazer: ./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS-antes-da-restauracao.tar.gz
```

O que muda depois de restaurar:

- Usuários criados depois da cópia deixam de existir; os removidos depois dela voltam.
- Cada usuário volta com a senha e a pasta que tinha na cópia. O usuário inicial (`FTP_USER`) fica com a senha de `.secrets/ftp-usuario-inicial-senha.txt`; se na cópia a senha dele estava trocada pelo painel e o arquivo não mudou desde então, vale a da cópia. Se na cópia ele já tinha sido removido, continua removido.
- As senhas voltam com o custo com que foram gravadas. Cópia feita antes da `0.18.1`, ou em um porte menor, traz senhas com o custo anterior: a aba Segurança do painel lista de quem, e o custo atual passa a valer quando a senha é trocada.
- Os administradores do painel voltam os da cópia, cada um com a senha que tinha: quem foi criado depois dela deixa de existir e todos entram de novo. Cópia feita antes da `0.12.0` não tem administradores: o painel cria o de `PAINEL_ADMIN_USER` com o hash de `.secrets/painel-admin-inicial-senha-hash.txt`.
- Se a stack estava parada, continua parada: `Restaurado. A stack estava parada e continua parada: suba com ./deploy.sh`.

> ⚠️ A cópia é conferida antes de qualquer alteração. Se a soma não confere, se o arquivo não abre ou se ele não é uma cópia desta stack, o comando para com `ERRO: ... Nada foi tocado.` e a stack segue como estava.

<details>
<summary>Detalhe técnico — ordem dos passos, recusas e códigos de saída</summary>

Ordem do que o script faz:

1. Confere a cópia: a soma do `.sha256` (se o arquivo existir ao lado; sem ele, avisa `soma não conferida` e segue), a leitura do `.tar.gz`, a presença de `auth/pureftpd.passwd` e a ausência de qualquer item fora de `dados/`, `auth/`, `certs/` e `painel/`.
2. Pede a confirmação: digitar `restaurar`, ou `--sim`. Sem terminal, só roda com `--sim`.
3. Para os containers, se estavam no ar (`docker compose stop`).
4. Guarda o estado atual com `scripts/backup.sh --rotulo antes-da-restauracao`. Se essa cópia falhar, nada é alterado e a stack sobe de novo.
5. Esvazia as quatro pastas e extrai a cópia, por um container descartável sem rede, com a raiz somente leitura e só `DATA_DIR` montada (`--cap-drop ALL`, mais `CHOWN`, `DAC_OVERRIDE` e `FOWNER`, para devolver dono e modo).
6. Sobe os containers e espera ficarem `healthy` (`docker compose up -d --wait`, prazo de 300 segundos), se estavam no ar.

| Mensagem | Quando |
|---|---|
| `ERRO: cópia não encontrada: ...` | o nome não existe em `BACKUP_DIR` nem como caminho |
| `ERRO: a soma sha256 de ... não confere: a cópia está corrompida ou foi alterada. Nada foi tocado.` | o `.tar.gz` não bate com o `.sha256` ao lado |
| `ERRO: ... não é um arquivo .tar.gz legível. Nada foi tocado.` | arquivo truncado ou de outro formato |
| `ERRO: ... tem itens fora de dados/, auth/, certs/ e painel/: não é uma cópia desta stack. Nada foi tocado.` | `.tar.gz` de outra origem |
| `ERRO: ... não tem a lista de usuários (auth/pureftpd.passwd): não é uma cópia desta stack. Nada foi tocado.` | `.tar.gz` sem os usuários |
| `ERRO: restauração sem terminal exige --sim.` | chamado por script ou `cron` sem a opção |
| `ERRO: confirmação não recebida; nada foi alterado.` | a palavra digitada não foi `restaurar` |
| `ERRO: a restauração falhou no meio: ...` | falha durante a extração (disco cheio, por exemplo). A stack fica parada: restaure de novo, com a mesma cópia ou com a `antes-da-restauracao` |

| Saída | Significado |
|---|---|
| `0` | restaurado |
| `1` | recusado ou falhou; a mensagem `ERRO:` diz o motivo |
| `64` | uso inválido: opção desconhecida, nenhuma cópia informada ou mais de uma |

Outra instalação: `ENV_FILE=<arquivo> ./scripts/restaurar.sh <cópia>`.

</details>

---

<a name="desfazer"></a>

## ↩️ Desfazer uma restauração

Toda restauração guarda antes o estado que encontrou, em um arquivo com `antes-da-restauracao` no nome. Para voltar a ele, restaure esse arquivo; o comando exato aparece na última linha da restauração:

```bash
./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS-antes-da-restauracao.tar.gz
```

**Resultado esperado:** `Restaurado e no ar (healthy).`, com os usuários e os arquivos de antes da restauração.

---

<a name="segredos"></a>

## 🔑 Guardar o `.env` e os segredos

A cópia não leva o `.env` nem a pasta `.secrets/`, para que um arquivo de backup que vaze não entregue as senhas em texto. Guarde os dois em um cofre de senhas, separados das cópias:

| O que guardar | Para que serve na volta |
|---|---|
| `.env` | Endereços, portas, perfil e limites da instalação |
| `.secrets/ftp-usuario-inicial-senha.txt` | Senha do usuário inicial do FTP |
| `.secrets/painel-admin-inicial-senha-hash.txt` | Hash da senha inicial do primeiro administrador do painel |

Sem eles, a stack volta do mesmo jeito: o `./deploy.sh` cria um `.env` novo e senhas novas. Nesse caso, o usuário inicial passa a ter a senha nova, que precisa ser configurada no equipamento que o usa. Os demais usuários e os administradores do painel não são afetados: o hash da senha deles está na cópia. Detalhes de cada arquivo em [Segredos](segredos.md).

---

<a name="outro-servidor"></a>

## 🚚 Restaurar em outro servidor

1. Traga o projeto para o servidor novo e, se você os guardou, o `.env` e a pasta `.secrets/` para dentro dele.
2. Instale, para criar as pastas, as imagens e os containers:

   ```bash
   ./deploy.sh
   ```

3. Copie o `.tar.gz` e o `.sha256` para a pasta `BACKUP_DIR` do servidor novo.
4. Restaure:

   ```bash
   ./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz
   ```

**Resultado esperado:** `Restaurado e no ar (healthy).`, com os usuários e os arquivos da cópia.

Se o endereço do servidor mudou, ajuste `FTP_BIND_IP`, `FTP_PASSIVE_IP` e `PAINEL_BIND_IP` no `.env` antes do `./deploy.sh`: veja [Configuração](configuracao.md). O certificado do painel é refeito sozinho quando os endereços mudam; o do FTP volta o da cópia.

---

<a name="automatica"></a>

## ⏰ Cópia automática e limpeza

O `backup.sh` não faz pergunta e não precisa de terminal, então pode rodar pelo `cron` do usuário que administra a stack. Exemplo, todo dia às 2h30, com o resultado no registro do sistema:

```bash
30 2 * * * cd /caminho/da/stack && ./scripts/backup.sh 2>&1 | logger -t allsafe-ftp-backup
```

Escolha um horário fora da janela em que os equipamentos enviam os backups deles.

O script não apaga cópia antiga. Para remover as que têm mais de 30 dias, junto com o `.sha256` de cada uma:

```bash
BACKUP_DIR="$(sed -n 's/^BACKUP_DIR=//p' .env | tail -n 1)"   # o BACKUP_DIR do seu .env
find "$BACKUP_DIR" -maxdepth 1 -name 'allsafe-ftp-stack-*.tar.gz*' -mtime +30 -print -delete
```

**Resultado esperado:** o caminho de cada arquivo removido; nenhuma linha quando não há cópia com mais de 30 dias.

---

⬅️ [Operação](operacao.md) · 🏠 [Documentação](README.md) · ➡️ [Painel web](painel.md)
