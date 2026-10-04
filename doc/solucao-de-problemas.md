# 🚨 Solução de problemas — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [Índice da documentação](README.md)

## 💡 Em poucas palavras

Quando algo falha, quase sempre o próprio servidor já disse o motivo. O caminho é sempre o mesmo: ver se o container está de pé, ler a mensagem do log, achar a linha correspondente nas tabelas deste guia, aplicar a correção e conferir de novo.

<!-- diagrama: diagramas/diagnostico-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    usuario@{ shape: person, label: "Usuário<br>viu o problema" }
    estado@{ shape: console, label: "docker compose ps<br>estado e saúde" }
    logs@{ shape: docs, label: "docker compose logs<br>mensagem FALHA" }
    tabela@{ shape: doc, label: "tabelas deste guia<br>causa e correção" }
    valida@{ shape: console, label: "validate.sh --runtime<br>confere de novo" }
    fim@{ shape: stadium, label: "serviço saudável" }

    usuario --> estado --> logs --> tabela --> valida --> fim
```

<sub>Nível 1 · Diagrama · [fonte](diagramas/)</sub>

**Sequência:** Usuário ➜ `docker compose ps` ➜ `docker compose logs` ➜ tabelas deste guia ➜ `validate.sh --runtime` ➜ serviço saudável

---

<details>
<summary>Sumário — clique para expandir</summary>

[Diagnóstico em 30 segundos](#diagnostico-em-30-segundos) · [O container não sobe](#o-container-nao-sobe) · [Conecta mas falha no login ou na listagem](#conecta-mas-falha-no-login-ou-na-listagem) · [Equipamento sem TLS](#ftp-sem-tls) · [Arquivo e permissão](#problemas-de-arquivo-permissao) · [Certificado e TLS](#certificado-tls) · [Painel web](#painel) · [Ferramentas de validação](#ferramentas-de-validacao)

</details>

---

<a name="diagnostico-em-30-segundos"></a>

## 🧭 Diagnóstico em 30 segundos

```bash
docker compose ps                                               # os três containers estão 'running' e 'healthy'?
docker compose logs --tail 50 ftp                               # o que o entrypoint e o pure-ftpd disseram?
docker compose logs --tail 50 painel                            # e o painel?
docker compose logs --tail 50 nginx                             # e o nginx, que fica na frente do painel?
```

**Resultado esperado:** os três containers (`allsafe-ftp`, `allsafe-ftp-painel` e `allsafe-ftp-nginx`) `running` e `healthy` e, no log, as linhas `FTP pronto em 2121/tcp; ...`, `Painel pronto no soquete /nginx/painel.sock, atrás do nginx; ...` e `nginx pronto em 8443/tcp (HTTPS), à frente do painel; ...`. Qualquer coisa diferente aponta para uma das tabelas abaixo.

Os três entrypoints abortam com `FALHA: <motivo>` e o container reinicia em laço: o motivo está sempre na primeira tentativa do log.

---

<a name="o-container-nao-sobe"></a>

## ❌ O container não sobe

| Mensagem no log | Causa | Como verificar | Correção |
|---|---|---|---|
| `ERRO: porta já em uso por outro programa: <IP>:<porta>` (no `deploy.sh`) | Outro programa do host já escuta na porta do FTP, do painel ou da faixa passiva | `ss -ltnp` | Troque `FTP_PORT`, `PAINEL_PORT` ou a faixa passiva no `.env`, ou pare o outro programa, e rode `./deploy.sh` de novo |
| `ERRO: os containers não ficaram healthy` (no `deploy.sh`) | Um dos containers parou ou não respondeu no prazo (180 s mais um quarto de segundo por porta passiva) | `docker compose logs --tail 50 ftp painel nginx` | Corrija a causa mostrada no log (as linhas abaixo cobrem as mais comuns) e rode `./deploy.sh` de novo |
| `ERRO: o perfil '…' pede … CPUs (FTP_CPU_LIMIT) e este servidor tem …` (ou `de memória (FTP_MEMORY_LIMIT)`), no `deploy.sh` | O perfil escolhido é maior que o servidor. Nada foi alterado | `nproc` e `free -m` | Use um perfil menor com `--size`: [Perfis](perfis.md#o-servidor-aguenta) |
| `ERRO: FTP_TLS_MODE deve ser 0 (sem TLS), 1 (opcional), 2 (obrigatório no login) ou 3 (…)` (no `deploy.sh`) | Valor fora de `0` a `3` no `.env`. Nada foi alterado | `grep '^FTP_TLS_MODE=' .env` | Use `2`, o padrão: [Configuração](configuracao.md#tls) |
| `ERRO: Docker não encontrado`, `ERRO: plugin Docker Compose não encontrado` ou `ERRO: sem acesso ao Docker` (no `deploy.sh`) | Docker parado, sem permissão para o usuário, ou sem o plugin Compose | `docker info` e `docker compose version` | Inicie o Docker, entre no grupo `docker` ou instale o plugin Compose v2 |
| `FALHA: segredo /run/secrets/ftp_password ausente` | `.secrets/ftp_password.txt` não existe | `ls -l .secrets/` | Rode `./deploy.sh`, que cria o arquivo com uma senha forte. Veja [Segredos](segredos.md) |
| `FALHA: FTP_BIND_IP=… não é IP privado` (ou `FTP_PUBLIC_IP`) | Endereço fora de `127/8`, `10/8`, `172.16/12` e `192.168/16`; o container reinicia em laço | `grep -E "FTP_(BIND|PUBLIC)_IP" .env` | Use o IP **interno** do servidor. A stack não aceita `0.0.0.0` nem IP público: veja [Segurança](seguranca.md#rede-privada) |
| `ERRO: .env ainda traz FTP_PASSWORD` (no `deploy.sh`) | `.env` de uma versão anterior, com senha | `grep -c "^FTP_PASSWORD" .env` | Grave a senha em `.secrets/ftp_password.txt` (`chmod 600`) e apague `FTP_PASSWORD` e `FTP_PASSWORD_FILE` do `.env` |
| `bind source path does not exist` ao subir | Pasta de `DATA_DIR` ausente (o Compose não cria) | `ls "$DATA_DIR"` | Rode `./deploy.sh`, que cria `dados/`, `auth/`, `certs/`, `painel/` e `nginx/` |
| `allsafe-ftp` em `unhealthy`, com o container rodando e sem `FALHA` no log | O `pure-ftpd` está vivo, mas não responde na porta de controle. O Docker só sinaliza: não reinicia o container sozinho | `docker compose exec ftp /usr/local/sbin/allsafe-ftp-saude; echo $?` (`0` = atendendo) | `docker compose restart ftp`. Se voltar a acontecer, colete os registros: [Ferramentas de validação](#ferramentas-de-validacao) |
| `FALHA: a senha FTP deve ter pelo menos 12 caracteres` | Senha curta, ou arquivo vazio ou só com linha em branco | `wc -c .secrets/ftp_password.txt` | Regrave: `printf '%s' 'senha-com-12+' > .secrets/ftp_password.txt` |
| `FALHA: FTP_USER invalido` | Nome fora de `^[a-z_][a-z0-9_-]{0,31}$` | `grep '^FTP_USER=' .env` | Use minúsculas, sem espaço nem acento; comece com letra ou `_` |
| `FALHA: faixa passiva invalida` ou `fora dos limites` | `FTP_PASSIVE_PORT_START` ou `FTP_PASSIVE_PORT_END` não numéricos, abaixo de `1024`, acima de `65535` ou invertidos | `grep PASSIVE .env profiles/*.env` | Corrija no `.env`; mantenha o início menor ou igual ao fim |
| `FALHA: FTP_TLS_MODE deve ser 0, 1, 2 ou 3` | Valor inválido | `grep '^FTP_TLS_MODE=' .env` | Use `2`, o padrão. `0` e `1` são só para equipamento sem TLS: [Configuração](configuracao.md#tls) |
| `bind: address already in use` | `FTP_PORT` ou a faixa passiva já estão ocupadas no host | `ss -ltnp` | Troque a porta ou a faixa, ou libere quem está usando |
| `bind: cannot assign requested address` | `FTP_BIND_IP` não existe no host | `ip -br addr` | Ajuste para um IP configurado na máquina |

---

<a name="conecta-mas-falha-no-login-ou-na-listagem"></a>

## 🔌 Conecta mas falha no login ou na listagem

| Sintoma | Causa provável | Como verificar | Correção |
|---|---|---|---|
| Cliente conecta e cai ao ser exigido o `AUTH TLS` | Cliente usando FTP **puro** ou FTPS **implícito** (porta 990) | Configuração do cliente; log do container | Configure o cliente para **FTP explícito sobre TLS** na porta de controle. Se o equipamento não tem TLS: [Equipamento antigo](#ftp-sem-tls) |
| O cliente pede TLS e o servidor recusa o `AUTH TLS` | O servidor está em `FTP_TLS_MODE=0`, sem TLS | `grep '^FTP_TLS_MODE=' .env`; o `AVISO` no fim do `./deploy.sh` | Volte para `FTP_TLS_MODE=2` e rode `./deploy.sh`, ou use o modo `1` se houver equipamento antigo no mesmo servidor |
| `530 Login authentication failed` | Senha errada, usuário não existe no PureDB ou UID abaixo de 10000 | `./manage-user.sh list` | Recrie a senha com `./manage-user.sh passwd <usuario>` |
| Login OK, `LIST` ou `STOR` trava e dá timeout | Modo **ativo**, ou faixa passiva ou `FTP_PUBLIC_IP` bloqueados ou errados | `docker compose ps` mostra a faixa publicada; teste a porta `30000/tcp` a partir do cliente | Use modo **passivo**; libere no firewall a faixa passiva do perfil (`30000-30049/tcp` no `small`); `FTP_PUBLIC_IP` com o IP que o cliente alcança |
| `425 Could not open data connection` | `FTP_PUBLIC_IP` aponta para um IP que o cliente não alcança | `grep '^FTP_PUBLIC_IP=' .env` | Defina `FTP_PUBLIC_IP` com o IP **privado** que o cliente alcança e libere a faixa passiva até ele. A stack não aceita IP público |
| Erro de certificado no cliente | O certificado ainda é o autoassinado | `openssl s_client -connect SEU_IP:21 -starttls ftp` mostra o emissor | Instale um certificado real ([Operação](operacao.md#certificado-real-de-producao)) ou, só em teste, desative a verificação no cliente |
| `421 Too many connections` | `FTP_MAX_CLIENTS` ou `FTP_MAX_CLIENTS_PER_IP` atingido | `docker compose logs --tail 50 ftp` | Suba de perfil com `./deploy.sh --size medium` e libere a faixa passiva nova: [Perfis](perfis.md) |

---

<a name="ftp-sem-tls"></a>

### Equipamento antigo que não fala TLS

O sintoma é sempre o mesmo: o equipamento conecta na porta de controle e a sessão cai antes do login. No padrão (`FTP_TLS_MODE=2`), o servidor recusa quem não pede TLS. Confirme simulando o equipamento, sem TLS:

```bash
curl -v --max-time 10 --user backup-olt ftp://SEU_IP:21/
```

**Resultado esperado**, com o servidor no padrão: `421-Sorry, cleartext sessions and weak ciphers are not accepted on this server.` e o `curl` desistindo em seguida. É o servidor funcionando como deve.

Se o equipamento não tiver mesmo como falar TLS (confira o manual e a versão do firmware antes), a stack tem dois modos para ele, `FTP_TLS_MODE=1` (opcional) e `FTP_TLS_MODE=0` (sem TLS). Os dois mandam senha e arquivo em **texto puro**: leia as condições em [Segurança](seguranca.md#ftp-sem-tls) antes de ligar.

---

<a name="problemas-de-arquivo-permissao"></a>

## 📁 Arquivo e permissão

| Sintoma | Causa | Como verificar | Correção |
|---|---|---|---|
| `553 Could not create file` | Diretório do usuário sem dono `ftpdata` (uid 10000) | `docker compose exec ftp ls -ld /data/<usuario>` | `docker compose exec ftp chown -R 10000:10000 /data/<usuario>` |
| Arquivos entram com permissão inesperada | O `umask` do `pure-ftpd` é `133:022` (arquivos sem execução e sem escrita para grupo e outros) | `docker compose exec ftp ls -l /data/<usuario>` | Comportamento esperado; ajuste `-U` no [`entrypoint.sh`](../scripts/entrypoint.sh) se precisar |
| Cliente não consegue `chmod` | `-R` desabilita o `SITE CHMOD` | Mensagem de recusa no cliente | Intencional, por segurança. Remova `-R` do entrypoint só se for realmente necessário |
| `ls` não mostra todos os arquivos | Limite `-L 10000:8` (10000 arquivos, profundidade 8) | Conte os arquivos da pasta | Reduza o número de arquivos por diretório ou ajuste `-L` |

---

<a name="certificado-tls"></a>

## 🔐 Certificado e TLS

| Sintoma | Causa | Como verificar | Correção |
|---|---|---|---|
| Novo certificado não é usado depois de copiar | Serviço não reiniciado, ou PEM sem a chave | `docker compose exec ftp ls -l /etc/ssl/private/` | `docker compose restart ftp`; o PEM deve ter **chave e certificado** juntos, `0600` |
| O entrypoint gera autoassinado a cada subida | O arquivo `/etc/ssl/private/pure-ftpd.pem` não está persistindo | `ls -ld "$DATA_DIR/certs"` no host | Confirme o `DATA_DIR` do `.env` e a pasta `certs/` dentro dele |
| Handshake TLS falha com "certificate expired" | Relógio do host errado, ou certificado vencido (o autoassinado dura 825 dias) | `date` no host; `openssl s_client -connect SEU_IP:21 -starttls ftp` mostra a validade | Sincronize a hora (stack `allsafe-ntp-nts-stack`); gere ou renove o certificado |

---

<a name="painel"></a>

## 🖥️ Painel web

| Sintoma | Causa | Como verificar | Correção |
|---|---|---|---|
| O navegador não abre o endereço (conexão recusada ou tempo esgotado) | nginx parado, endereço diferente do `PAINEL_BIND_IP` ou firewall | `docker compose ps nginx painel`; `grep '^PAINEL_' .env` | Abra pelo IP e pela porta do `.env`. Com `PAINEL_BIND_IP=127.0.0.1` o painel só abre no próprio servidor |
| `pedido não aceito` (`400`) ao abrir com `http://` | A porta do painel só fala HTTPS | O endereço digitado | Use `https://` |
| `pedido não aceito` (`413` ou outro `4xx`) | Pedido maior que 16 KiB ou malformado, recusado pelo nginx | `docker compose logs --tail 20 nginx` | Repita pelo navegador, direto no endereço do painel |
| `painel indisponível; tente de novo em instantes` (`502`) | O nginx está no ar e o painel está parado ou reiniciando | `docker compose ps painel`; `docker compose logs --tail 20 painel` | Aguarde alguns segundos; se não voltar, `./deploy.sh` |
| `pedidos demais deste endereço; aguarde alguns segundos` (`429`) | Mais de 20 pedidos por segundo do mesmo endereço (rajada de 40) ou mais de 16 conexões: script consultando o painel, ou várias pessoas saindo pelo mesmo endereço | `docker compose logs --tail 20 nginx` | Aguarde alguns segundos. O limite é fixo em [`nginx/nginx.conf.modelo`](../nginx/nginx.conf.modelo) |
| Aviso de certificado no navegador | O certificado inicial é autoassinado | A impressão digital mostrada na aba `🔐 Segurança` | Confira a impressão digital e aceite, ou instale um certificado próprio: [Painel web](painel.md#certificado) |
| `cliente fora das redes permitidas` (`403`) | O endereço do cliente não está em `PAINEL_REDES_PERMITIDAS`. A recusa é do nginx e fica no log dele, com o endereço visto | `grep '^PAINEL_REDES_PERMITIDAS=' .env`; `docker compose logs --tail 20 nginx` | Inclua a rede **privada** de quem administra e rode o `deploy.sh`. Para abrir pelo próprio servidor, mantenha a sub-rede da stack (`FTP_SUBNET`) na lista |
| `endereço não aceito` (`400`) | O painel foi aberto por um nome que ele não conhece, ou por IP público | O endereço digitado | Abra pelo IP privado, ou cadastre o nome interno em `PAINEL_CERT_CN` e rode o `deploy.sh` |
| `Muitas tentativas. Aguarde alguns minutos e tente de novo.` (`429`) | Cinco senhas erradas em 15 minutos, vindas do mesmo endereço | Aba `📜 Atividade` ou `auditoria.log` | Espere 15 minutos, ou `docker compose restart painel`, que zera o bloqueio (o nginx reinicia junto) |
| Senha do painel perdida | A senha não fica gravada, só o hash | — | `./scripts/painel-senha.sh --gerar`: veja [Segredos](segredos.md#senha-do-painel) |
| A sessão cai sozinha | 15 minutos sem uso, teto de 8 horas, troca do endereço do cliente ou reinício do painel | `grep '^PAINEL_SESSAO_MINUTOS=' .env` | Entre de novo. O tempo sem uso vai de `1` a `120` minutos |
| `O envio não partiu deste painel.` ou `Formulário sem token válido.` (`403`) | Aba antiga, depois de sair ou de a sessão vencer, ou painel aberto por um intermediário que troca o endereço. Em versão anterior à `1.0.0`, o navegador era recusado em todo envio, inclusive na entrada | `cat VERSION` | Abra a página de novo, direto pelo endereço do painel, e repita. Em versão anterior à `1.0.0`, atualize a stack |
| O usuário inicial não pode ser alterado (`409`) | O `FTP_USER` é recriado a cada subida a partir de `.secrets/ftp_password.txt` | — | Troque a senha dele pelo arquivo: [Segredos](segredos.md#trocar-a-senha) |
| `allsafe-ftp-painel` reiniciando em laço | O entrypoint do painel recusou a configuração | `docker compose logs --tail 20 painel` | Corrija conforme a mensagem `FALHA:`: [Scripts](scripts.md#painel-entrypoint) |
| `allsafe-ftp-nginx` reiniciando em laço | O entrypoint do nginx recusou a configuração ou não achou o soquete nem o certificado do painel | `docker compose logs --tail 20 nginx` | Corrija conforme a mensagem `FALHA:`: [Scripts](scripts.md#nginx-entrypoint). Na dúvida, `./deploy.sh` recria a pasta `nginx/` e sobe na ordem certa |
| `dependency failed to start: container allsafe-ftp is unhealthy` | O painel só sobe depois do FTP, e o nginx depois do painel | `docker compose logs --tail 50 ftp` | Resolva primeiro o FTP, pela tabela [O container não sobe](#o-container-nao-sobe) |
| `bind: address already in use` na porta do painel (container `allsafe-ftp-nginx`) | `PAINEL_PORT` ocupada por outro serviço no mesmo IP | `ss -ltnp` | Troque `PAINEL_PORT` no `.env` |

---

<a name="ferramentas-de-validacao"></a>

## 🧪 Ferramentas de validação

```bash
./scripts/validate.sh                     # bash -n dos scripts e compose config
./scripts/validate.sh --runtime           # também exige os três serviços running e healthy
docker compose exec ftp /usr/local/sbin/allsafe-ftp-saude && echo atendendo   # o que o healthcheck testa
./scripts/testar.sh                       # bateria completa em instância de teste separada
```

**Resultado esperado:** `Validacao FTP concluida.`, `atendendo` e `Bateria aprovada: nenhum desvio.` A bateria não toca na instalação em uso; se ela passa e a sua instalação falha, a diferença está no `.env`, nos dados ou na rede do host. Veja [Scripts](scripts.md#testar).

Ainda travado? Colete e analise:

```bash
TEMP_DIR=/home/carlos/code/tmp/allsafe-ftp-stack   # o TEMP_DIR do seu .env
mkdir -p "$TEMP_DIR"
docker compose logs --no-color ftp painel nginx > "$TEMP_DIR/allsafe-ftp.log"
docker inspect allsafe-ftp allsafe-ftp-painel allsafe-ftp-nginx > "$TEMP_DIR/allsafe-ftp.inspect.json"
```

**Resultado esperado:** dois arquivos em `TEMP_DIR` com o log completo e a configuração efetiva dos containers. Apague-os ao terminar.

> ⚠️ O `inspect` traz as variáveis de ambiente do container. Nenhuma delas é senha (a senha só existe no segredo), mas o arquivo mostra IPs e caminhos do host: revise antes de compartilhar.

---

⬅️ [Fotos da aplicação](aplicacao/README.md) · 🏠 [Documentação](README.md)
