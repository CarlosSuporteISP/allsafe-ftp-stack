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
| `FALHA: segredo /run/secrets/ftp_usuario_inicial_senha ausente` | `.secrets/ftp-usuario-inicial-senha.txt` não existe | `ls -l .secrets/` | Rode `./deploy.sh`, que cria o arquivo com uma senha forte. Veja [Segredos](segredos.md) |
| `FALHA: FTP_BIND_IP=… não é IP privado` (ou `FTP_PASSIVE_IP`) | Endereço fora de `127/8`, `10/8`, `172.16/12` e `192.168/16`; o container reinicia em laço | `grep -E "FTP_(BIND|PASSIVE)_IP" .env` | Use o IP **interno** do servidor. A stack não aceita `0.0.0.0` e, por padrão, nem IP público: veja [Segurança](seguranca.md#rede-privada) |
| `FALHA: REDE_PERMITIR_IP_PUBLICO deve ser 'nao' ou 'sim'; está '…'` (no `deploy.sh` e nos três containers) | A opção de IP público tem outro valor, como `true` ou `1` | `grep '^REDE_PERMITIR_IP_PUBLICO=' .env` | Use `nao`, o padrão. `sim` só depois de ler o alerta: [Segurança](seguranca.md#ip-publico) |
| `FALHA: …=… não é um endereço IPv4 de servidor` ou `não é uma rede IPv4 aceita` | Com `REDE_PERMITIR_IP_PUBLICO=sim`, o valor é `0.0.0.0`, multicast, reservado ou uma rede mais larga que `/8` | `grep -E '^(FTP_BIND_IP|FTP_PASSIVE_IP|PAINEL_BIND_IP|PAINEL_REDES_PERMITIDAS|PAINEL_CERT_CN)=' .env` | Informe o endereço e as redes um a um; "todos" não é aceito nem com a opção ligada |
| `REDE_PERMITIR_IP_PUBLICO=sim exige FTP_TLS_MODE=2 ou 3` (no `deploy.sh` e no container do FTP) | A opção de IP público está ligada com o FTP sem TLS ou com TLS opcional | `grep -E '^(REDE_PERMITIR_IP_PUBLICO|FTP_TLS_MODE)=' .env` | Volte `FTP_TLS_MODE` para `2` ou desligue a opção. Equipamento sem TLS só em rede interna: [Segurança](seguranca.md#ftp-sem-tls) |
| `FTP_TLS_EXCECOES deve ser …` (no `deploy.sh` e nos containers do FTP e do painel) | A exceção de TLS por usuário tem valor diferente de `nao` e de `sim`. Nada foi alterado | `grep '^FTP_TLS_EXCECOES=' .env` | Use `nao`, o padrão, ou `sim`: [Configuração](configuracao.md#tls) |
| `FTP_TLS_EXCECOES=sim exige FTP_TLS_MODE=2` (no `deploy.sh` e nos containers do FTP e do painel) | A exceção por usuário está ligada com o TLS em `0`, `1` ou `3` | `grep -E '^FTP_TLS_(EXCECOES|MODE)=' .env` | Volte `FTP_TLS_MODE` para `2` ou desligue a exceção: [Segurança](seguranca.md#tls-por-usuario) |
| `FTP_TLS_EXCECOES=sim não combina com REDE_PERMITIR_IP_PUBLICO=sim` (no `deploy.sh` e nos containers do FTP e do painel) | As duas opções estão ligadas: usuário sem TLS em servidor que aceita endereço público | `grep -E '^(FTP_TLS_EXCECOES|REDE_PERMITIR_IP_PUBLICO)=' .env` | Desligue uma das duas. Equipamento sem TLS só em rede interna: [Segurança](seguranca.md#tls-por-usuario) |
| `FALHA: o pure-authd saiu: o container encerra para ninguém entrar sem a conferência do TLS por usuário` (ou `o pure-ftpd saiu`), e o `allsafe-ftp` reinicia | Com `FTP_TLS_EXCECOES=sim`, um dos dois processos do FTP parou. O container encerra de propósito e o Docker o sobe de novo | `docker compose logs --tail 50 ftp`; `docker inspect -f '{{.RestartCount}}' allsafe-ftp` | Uma vez só, nada a fazer: o FTP volta sozinho em segundos. Se repetir, colete os registros: [Ferramentas de validação](#ferramentas-de-validacao) |
| `FALHA: o pure-authd não abriu o soquete /run/pure-authd.sock: o FTP não sobe sem o porteiro do TLS` | Com `FTP_TLS_EXCECOES=sim`, o processo que consulta a lista dos dispensados não iniciou | `docker compose logs --tail 50 ftp` | Rode `./deploy.sh` de novo. Se continuar, desligue a exceção (`FTP_TLS_EXCECOES=nao`) para o FTP voltar com TLS obrigatório e colete os registros |
| `defina FTP_PASSIVE_IP no .env` (em qualquer comando que chama o Compose) | `.env` de instalação anterior à `0.9.0`, ainda com `FTP_PUBLIC_IP` | `grep -E "^FTP_(PUBLIC|PASSIVE)_IP=" .env` | Rode `./deploy.sh`: ele troca o nome sozinho, mantém o valor e guarda o `.env` de antes em `BACKUP_DIR`. Veja [Configuração](configuracao.md#ftp-passive-ip) |
| `ERRO: .env ainda traz FTP_PASSWORD` (no `deploy.sh`) | `.env` de uma versão anterior, com senha | `grep -c "^FTP_PASSWORD" .env` | Grave a senha em `.secrets/ftp-usuario-inicial-senha.txt` (`chmod 600`) e apague `FTP_PASSWORD` e `FTP_PASSWORD_FILE` do `.env` |
| `bind source path does not exist` ao subir | Pasta de `DATA_DIR` ausente (o Compose não cria) | `ls "$DATA_DIR"` | Rode `./deploy.sh`, que cria `dados/`, `auth/`, `certs/`, `painel/` e `nginx/` |
| `allsafe-ftp` em `unhealthy`, com o container rodando e sem `FALHA` no log | O `pure-ftpd` está vivo, mas não responde na porta de controle. O Docker só sinaliza: não reinicia o container sozinho | `docker compose exec ftp /usr/local/sbin/allsafe-ftp-saude; echo $?` (`0` = atendendo) | `docker compose restart ftp`. Se voltar a acontecer, colete os registros: [Ferramentas de validação](#ferramentas-de-validacao) |
| `FALHA: a senha FTP deve ter pelo menos 12 caracteres` | Senha curta, ou arquivo vazio ou só com linha em branco | `wc -c .secrets/ftp-usuario-inicial-senha.txt` | Regrave: `printf '%s' 'senha-com-12+' > .secrets/ftp-usuario-inicial-senha.txt` |
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
| `530 Login authentication failed` sem TLS, com a senha certa, em servidor com `FTP_TLS_EXCECOES=sim` | O usuário não está dispensado do TLS. A senha passou em texto puro | `./manage-user.sh tls-lista`; `docker compose logs ftp \| grep porteiro` | Configure o equipamento para TLS e troque a senha. Se ele não fala TLS, dispense o usuário na aba Usuários do painel ou com `./manage-user.sh tls-dispensar <usuario>`: [Segurança](seguranca.md#tls-por-usuario) |
| Usuário dispensado do TLS continua sem entrar sem TLS (`421` ou tempo esgotado) | A `FTP_TLS_EXCECOES` está em `nao`: a lista dos dispensados fica guardada e não vale | `grep '^FTP_TLS_EXCECOES=' .env` | Defina `FTP_TLS_EXCECOES=sim` e rode `./deploy.sh` |
| Login OK, `LIST` ou `STOR` trava e dá timeout | Modo **ativo**, ou faixa passiva ou `FTP_PASSIVE_IP` bloqueados ou errados | `docker compose ps` mostra a faixa publicada; teste a porta `30000/tcp` a partir do cliente | Use modo **passivo**; libere no firewall a faixa passiva do perfil (`30000-30049/tcp` no `small`); `FTP_PASSIVE_IP` com o IP que o cliente alcança |
| `425 Could not open data connection` | `FTP_PASSIVE_IP` aponta para um IP que o cliente não alcança | `grep '^FTP_PASSIVE_IP=' .env` | Defina `FTP_PASSIVE_IP` com o IP que o cliente alcança e libere a faixa passiva até ele. Por padrão a stack só aceita IP privado |
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

Se o equipamento não tiver mesmo como falar TLS (confira o manual e a versão do firmware antes), há dois caminhos. O primeiro é dispensar do TLS só o usuário dele, com `FTP_TLS_EXCECOES=sim` e o botão **Dispensar TLS** da aba Usuários do painel: os demais continuam obrigados. O segundo são os modos `FTP_TLS_MODE=1` (opcional) e `FTP_TLS_MODE=0` (sem TLS), que valem para todos. Em qualquer um, quem entra sem TLS manda senha e arquivo em **texto puro**: leia as condições em [Segurança](seguranca.md#ftp-sem-tls) antes de ligar.

Com a exceção por usuário ligada, o mesmo teste muda de resposta: o servidor pede a senha e responde `530 Login authentication failed` para o usuário que não está dispensado, mesmo com a senha certa.

---

<a name="problemas-de-arquivo-permissao"></a>

## 📁 Arquivo e permissão

| Sintoma | Causa | Como verificar | Correção |
|---|---|---|---|
| `553 Could not create file` | Diretório do usuário sem dono `ftpdata` (uid 10000) | `docker compose exec ftp ls -ld /data/<usuario>` | `docker compose exec ftp chown -R 10000:10000 /data/<usuario>` |
| Arquivos entram com permissão inesperada | O `umask` do `pure-ftpd` é `133:022` (arquivos sem execução e sem escrita para grupo e outros) | `docker compose exec ftp ls -l /data/<usuario>` | Comportamento esperado; ajuste `-U` no [`ftp/entrypoint.sh`](../ftp/entrypoint.sh) se precisar |
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
| `endereço não aceito` (`400`) | O painel foi aberto por um nome que ele não conhece, ou por IP público sem `REDE_PERMITIR_IP_PUBLICO=sim` | O endereço digitado | Abra pelo IP privado, ou cadastre o nome interno em `PAINEL_CERT_CN` e rode o `deploy.sh` |
| `Muitas tentativas. Aguarde alguns minutos e tente de novo.` (`429`) | Cinco erros em 15 minutos, vindos do mesmo endereço, somando entrada recusada e senha atual recusada na aba Administradores | Aba `📜 Atividade` ou `auditoria.log` | Espere 15 minutos, ou `docker compose restart painel`, que zera o bloqueio (o nginx reinicia junto) |
| `Não foi possível entrar.` (`401`) | Usuário ou senha errados; a tela não diz qual dos dois | O usuário é o de `PAINEL_ADMIN_USER` só até ser trocado no painel: `sudo cut -d: -f1 "$DATA_DIR/painel/administradores"` lista os nomes | Entre com o nome certo; se a senha se perdeu, veja a linha seguinte |
| `Não foi possível entrar.` (`401`) com o usuário e a senha do FTP | Senha do FTP errada; entrada dos usuários desligada; nome igual ao de um administrador, que só entra com a senha de administrador; ou servidor FTP parado ou lotado | `grep '^PAINEL_ACESSO_USUARIOS_FTP=' .env`; `docker compose ps ftp`; na aba `📜 Atividade`, a linha `entrada_falha` com `conferencia=ftp_indisponivel` diz que o servidor FTP não pôde conferir | Confira a senha entrando por FTP; ligue a entrada com `PAINEL_ACESSO_USUARIOS_FTP=sim` e `./deploy.sh`; com o FTP parado, veja [O container não sobe](#o-container-nao-sobe) |
| A entrada demora de 3 a 9 segundos | Quem confere a senha do usuário do FTP é o servidor FTP: cerca de 3 segundos para aceitar e de 3 a 6 a mais para recusar. A senha errada de administrador espera o mesmo, porque o nome também é conferido no FTP | — | É o esperado. A entrada do administrador com a senha certa não passa pelo FTP e é imediata |
| O usuário do FTP volta sozinho para a tela de entrada | A senha dele foi trocada, ele foi removido ou recriado com outra pasta, um administrador foi criado com o mesmo nome, ou a entrada dos usuários foi desligada | Aba `📜 Atividade`, linha `Sessão de usuário do FTP encerrada`, com o motivo | Entre de novo com a senha atual. Com nome igual ao de um administrador, só a conta de administrador entra |
| Tela não encontrada (`404`) para quem entrou com a conta do FTP | As abas de administração não existem para o usuário do FTP | O nome no topo do painel | Use a tela Meus arquivos; para administrar, saia e entre com uma conta de administrador |
| Senha do painel perdida | A senha não fica gravada, só o hash | — | Outro administrador troca na aba Administradores; sem nenhum, `./scripts/painel-senha.sh --gerar` (outro administrador: `--usuario NOME`): veja [Painel web](painel.md#senha) |
| `contato de segurança não configurado` (`404`) em `/.well-known/security.txt` | `SEGURANCA_CONTATO_EMAIL` está vazia, ou foi preenchida e o `deploy.sh` ainda não rodou | `grep '^SEGURANCA_CONTATO_EMAIL=' .env`; aba `🔐 Segurança`, item `Contato de segurança` | Preencha com um e-mail e rode o `./deploy.sh`: [Configuração](configuracao.md#contato-de-seguranca) |
| `SEGURANCA_CONTATO_EMAIL inválido` no `deploy.sh` ou no registro do painel | O valor não é um endereço de e-mail só: tem `mailto:`, espaço, dois endereços ou domínio sem ponto | `grep '^SEGURANCA_CONTATO_EMAIL=' .env` | Deixe um endereço só, como `seguranca@suaempresa.com.br`, ou vazio, e rode o `./deploy.sh` |
| `A sua senha atual não confere. Nada foi alterado.` (`403`) | Toda alteração de administrador pede a senha de quem está na sessão, não a do administrador alterado | O nome no topo do painel | Digite a sua senha no campo **Sua senha atual** |
| `Esta é a sua conta` (`409`) | Ninguém remove a própria conta de administrador | — | Entre com outro administrador para remover esta |
| `Muitos downloads ao mesmo tempo` (`503`) | O painel entrega até 8 arquivos por vez, somando administradores e usuários do FTP, e até 2 por usuário do FTP | Aba `📜 Atividade`: os downloads em curso ainda não aparecem; os terminados, sim | Espere um terminar e repita. A resposta traz `Retry-After: 30` |
| `Link simbólico não é seguido pelo painel.` (`403`) | O caminho pedido passa por um link simbólico; o painel não segue nenhum, nem para dentro da própria pasta | Na lista, o item aparece com a marca `link simbólico` | Baixe o arquivo pelo caminho real dele, ou por FTP |
| `Caminho não aceito.` (`400`) na aba Arquivos | Endereço montado à mão, com `..`, barra no início, barra dobrada ou caractere nulo | O endereço digitado | Navegue pelos links da aba Arquivos, a partir da primeira tela |
| `Nome não aceito` (`400`) ao criar uma pasta | O nome tem `/`, espaço, acento, começa com ponto ou passa de 64 caracteres | O nome digitado | Use letras, números, `_`, `-` e ponto. Para uma pasta dentro de outra, crie a de cima, entre nela e crie a de dentro |
| `Nome já usado` (`409`) ao criar uma pasta | Já existe pasta, arquivo ou link simbólico com esse nome naquela pasta | A lista da aba Arquivos | Escolha outro nome, ou use a pasta que já existe |
| `Pasta inválida. Veja a regra abaixo do campo.` (`400`) ao criar um usuário | A pasta tem mais de 4 níveis, `..`, barra no início, nível começando por ponto ou caractere fora da regra | O campo **Pasta** | Corrija a pasta, ou deixe em branco para usar o nome do usuário |
| `A pasta passa por um link simbólico, que não é aceito.` ou `Já existe um arquivo com este nome no caminho da pasta.` (`400`) | Um dos níveis da pasta escolhida é link simbólico ou arquivo; o painel e o `manage-user.sh` (`Pasta recusada: ...`) não seguem nem substituem | Aba Arquivos: o item aparece com a marca `link simbólico` ou como arquivo | Escolha outra pasta, ou remova o link ou o arquivo por FTP |
| `Já existe um usuário com este nome.` (`409`) ou `Usuario ja existe` | O nome já está no cadastro; a pasta de um usuário não muda depois de criado | Aba Usuários ou `./manage-user.sh list` | Use outro nome. Para trocar a pasta, remova o usuário e crie de novo: os arquivos ficam onde estavam |
| Um equipamento enxerga arquivos de outro | Os dois usuários têm a mesma pasta, ou a de um fica dentro da do outro | Aba Usuários: a pasta aparece com a marca **dividida** e o nome de quem mais a alcança | Recrie um dos usuários com a própria pasta: [Usuários pelo painel](painel.md#usuarios) |
| O download para no meio | Conexão caiu, ou recebeu menos de cerca de 4 KiB por segundo; o painel não retoma download | Aba `📜 Atividade`, linha `Download interrompido`, com os bytes entregues | Baixe de novo, por uma conexão mais rápida; arquivo muito grande em enlace lento sai melhor por FTP |
| Um arquivo aparece na lista sem o botão **Baixar** | É link simbólico ou arquivo especial (FIFO, soquete, dispositivo): o painel só entrega arquivo comum | A marca ao lado do nome | Por FTP ou no host, na pasta do usuário, dentro de `DATA_DIR/dados` |
| A aba do navegador continua com o ícone antigo depois de trocar a logo | O navegador guarda o ícone da aba por conta própria, mesmo com o painel mandando conferir a cada pedido | `curl -k -s https://<IP>:<porta>/favicon.ico \| sha256sum` e `sha256sum web/marca/favicon.ico` dão o mesmo resultado | Feche e abra a aba, ou limpe os dados do site no navegador. Se os resultados forem diferentes, falta rodar o `./deploy.sh` |
| `ERRO: web/marca/<arquivo> falta ou não é uma imagem válida.` no `validate.sh`, ou a construção da imagem do nginx para em `web/marca` | Um dos seis arquivos da marca foi apagado ou trocado por algo que não é PNG nem ICO | `ls -l web/marca/` | `./scripts/gerar-marca.sh` e depois `./deploy.sh`: [Painel web](painel.md#marca) |
| `ERRO: o ImageMagick 7 (comando magick) não está instalado neste computador.` | O `gerar-marca.sh` precisa do ImageMagick 7; o servidor não precisa dele para rodar a stack | `magick -version` | Rode o script em um computador que tenha o ImageMagick 7 e leve a pasta `web/marca/` para o servidor |
| A sessão cai sozinha | 15 minutos sem uso, teto de 8 horas, troca do endereço do cliente ou reinício do painel | `grep '^PAINEL_SESSAO_MINUTOS=' .env` | Entre de novo. O tempo sem uso vai de `1` a `120` minutos |
| `O envio não partiu deste painel.` ou `Formulário sem token válido.` (`403`) | Aba antiga, depois de sair ou de a sessão vencer, ou painel aberto por um intermediário que troca o endereço. Em versão anterior à `0.8.0`, o navegador era recusado em todo envio, inclusive na entrada | `cat VERSION` | Abra a página de novo, direto pelo endereço do painel, e repita. Em versão anterior à `0.8.0`, atualize a stack |
| O usuário inicial não pode ser alterado (`409`) | O `FTP_USER` é recriado a cada subida a partir de `.secrets/ftp-usuario-inicial-senha.txt` | — | Troque a senha dele pelo arquivo: [Segredos](segredos.md#trocar-a-senha) |
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
./tests/testar.sh                       # bateria completa em instância de teste separada
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
