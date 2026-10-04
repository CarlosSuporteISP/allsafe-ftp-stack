# 🔐 Segurança — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [Índice da documentação](README.md)

## 💡 Em poucas palavras

O backup de um equipamento de rede traz senhas e a configuração inteira da rede, então o caminho até o servidor é protegido em camadas: a porta só escuta no IP escolhido, a conexão tem de ser criptografada (a exceção, para equipamento antigo, é ligada à mão e fica avisada), cada usuário fica preso na própria pasta e o container roda com o mínimo de permissões. Se uma camada falhar, as outras continuam valendo. O painel web segue a mesma ideia: fica atrás de um nginx, só HTTPS, só rede interna, uma senha forte e sessão curta.

<!-- diagrama: diagramas/seguranca-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    equip@{ shape: hex, label: "Equipamento de rede" }
    bind@{ shape: rect, label: "Bind e firewall<br>127.0.0.1 por padrão" }
    tls@{ shape: rect, label: "FTPS obrigatório no padrão<br>AUTH TLS, FTP_TLS_MODE=2" }
    puredb@{ shape: cyl, label: "PureDB<br>senha de 12 ou mais" }
    chroot@{ shape: rect, label: "chroot<br>pasta do usuário" }
    container@{ shape: rect, label: "Container endurecido<br>raiz somente leitura" }
    fim@{ shape: stadium, label: "backup protegido" }

    equip --> bind --> tls --> puredb --> chroot --> container --> fim
```

<sub>Nível 1 · Diagrama · [fonte](diagramas/)</sub>

**Sequência:** Equipamento de rede ➜ Bind e firewall ➜ FTPS obrigatório no padrão (`FTP_TLS_MODE=2`) ➜ PureDB (senha de 12 ou mais) ➜ chroot ➜ Container endurecido ➜ backup protegido

---

<details>
<summary>Sumário — clique para expandir</summary>

[Só em rede privada](#rede-privada) · [FTP sem TLS](#ftp-sem-tls) · [Antes de produção](#o-que-endurecer-antes-de-producao) · [Modelo de ameaça](#modelo-de-ameaca) · [Superfície exposta](#superficie-exposta) · [Proteções do painel](#painel) · [Endurecimento do `compose.yaml`](#hardening-do-compose-yaml-linha-a-linha) · [Gestão de segredos](#gestao-de-segredos)

</details>

---

<a name="rede-privada"></a>

## 🧱 Só em rede privada, atrás de firewall

> ⚠️ **Esta stack não é para a internet.** FTP é um protocolo antigo, o que passa por ele aqui são configurações inteiras de rede, e o painel web administra os usuários. Use **apenas em rede interna**, com IP privado, atrás de firewall.

| Regra | O que fazer |
|---|---|
| IP privado | `FTP_BIND_IP`, `FTP_PUBLIC_IP` e `PAINEL_BIND_IP` só em `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` ou `127.0.0.1`. Nunca `0.0.0.0`, nunca IP público |
| Firewall do host | Liberar a porta de controle e a faixa passiva **só** para as redes internas que enviam backup, e a porta do painel **só** para as máquinas de quem administra; o resto é descartado |
| Redes do painel | `PAINEL_REDES_PERMITIDAS` reduzida à rede de administração; a lista só aceita rede privada |
| Firewall de borda | Nenhum redirecionamento de porta da internet para este host |
| Acesso de fora | Se alguém de fora precisar chegar, é por VPN até a rede interna, não abrindo a porta |

<details>
<summary>Detalhe técnico — firewall com Docker</summary>

O Docker publica as portas por regras próprias de NAT, **antes** das cadeias `INPUT` do host: uma regra comum de `ufw` ou de `INPUT` não bloqueia porta publicada por container. A cadeia certa é a `DOCKER-USER`, e a porta de destino tem de ser conferida pela conexão original, porque ali o destino já foi trocado para a porta do container.

Exemplo com `iptables`, liberando só a rede de gerência `10.10.0.0/24` na interface `eth0` (troque pelos valores reais):

```bash
iptables -I DOCKER-USER -i eth0 -p tcp -m conntrack --ctdir ORIGINAL --ctorigdstport 21 ! -s 10.10.0.0/24 -j DROP
iptables -I DOCKER-USER -i eth0 -p tcp -m conntrack --ctdir ORIGINAL --ctorigdstport 30000:30049 ! -s 10.10.0.0/24 -j DROP
iptables -I DOCKER-USER -i eth0 -p tcp -m conntrack --ctdir ORIGINAL --ctorigdstport 8443 ! -s 10.10.0.0/24 -j DROP
```

**Resultado esperado:** de uma máquina fora de `10.10.0.0/24`, as portas `21/tcp` e `8443/tcp` não respondem; de dentro, o login por FTPS e o painel funcionam.

> O exemplo **não foi aplicado nem testado neste projeto**: o firewall do host é de quem opera o servidor. Teste em janela de manutenção e torne a regra persistente com a ferramenta da sua distribuição.

Além do firewall, o `deploy.sh` e os containers **recusam por código** bind, IP anunciado e rede permitida fora de IP privado: veja [Rede e portas](configuracao.md#rede-e-portas) e [Painel web](configuracao.md#painel).

</details>

---

<a name="ftp-sem-tls"></a>

## ⚠️ FTP sem TLS: só para equipamento antigo

> ⚠️ **O padrão desta stack é TLS obrigatório (`FTP_TLS_MODE=2`). Os modos `0` e `1` desligam essa proteção.** Eles existem só porque há equipamento de rede antigo que não fala TLS e, sem isso, não conseguiria enviar o backup. Com eles, usuário, senha e arquivo passam em **texto puro**: quem estiver no caminho da rede lê tudo.

| Modo | O que acontece | O que fica exposto |
|---|---|---|
| `FTP_TLS_MODE=0` | O servidor **não oferece TLS**. Todo cliente entra em texto puro; quem exige TLS não consegue conectar | Usuário, senha e conteúdo de **todos** os backups, de todos os equipamentos |
| `FTP_TLS_MODE=1` | O TLS é **opcional**. Quem pede TLS usa; quem não pede entra em texto puro | Usuário, senha e backup de quem entra sem TLS. Nada obriga os demais a usar TLS: um equipamento mal configurado passa a enviar em texto puro sem ninguém notar |

O backup de um equipamento de rede costuma trazer senhas, comunidades SNMP e chaves. Com a senha do FTP capturada, o invasor também lê e sobrescreve os backups daquele usuário.

**Só use se todas as condições abaixo forem verdadeiras:**

1. O equipamento realmente não fala TLS: confirme no manual ou com o teste de [Solução de problemas](solucao-de-problemas.md#ftp-sem-tls).
2. O tráfego fica em **rede interna isolada** (rede de gerência), sem passar por rede de usuário, Wi-Fi, internet ou enlace de terceiro sem VPN.
3. O **firewall** libera a porta de controle e a faixa passiva **só para os IPs desses equipamentos**: [rede privada](#rede-privada).
4. Cada equipamento antigo tem **usuário e senha só dele**, não usados em nenhum outro lugar. O `chroot` limita o estrago à pasta daquele usuário.
5. Há data para voltar ao `2`: quando o equipamento for trocado ou atualizado, o modo volta e as senhas que passaram em texto puro são trocadas.

Prefira, nesta ordem: uma **segunda instância** só para os equipamentos antigos, mantendo a principal em `2` ([Configuração](configuracao.md#pastas-e-nomes)); depois o modo `1`; por último o modo `0`.

Para ligar, edite `FTP_TLS_MODE` no `.env` e reaplique:

```bash
./deploy.sh
```

**Resultado esperado:** o resumo traz `FTP:    127.0.0.1:21, SEM TLS (texto puro), modo passivo 30000-30049` (ou `TLS explícito opcional (aceita texto puro)` no modo `1`) e termina com o aviso:

```text
AVISO: FTP_TLS_MODE=0: o FTP está SEM criptografia. Senhas e arquivos passam em texto puro e podem ser
       lidos por quem estiver na mesma rede. Use só para equipamento antigo sem suporte a TLS, em rede interna
       isolada, com o firewall liberando só esses equipamentos, e volte para FTP_TLS_MODE=2 assim que puder.
```

A stack não deixa o modo passar despercebido. Enquanto ele estiver ligado, o alerta aparece em:

| Onde | O que aparece |
|---|---|
| Fim do `./deploy.sh` e do `./deploy.sh --check-only` | O `AVISO` de três linhas acima |
| Resumo do `./deploy.sh` | `SEM TLS (texto puro)` ou `TLS explícito opcional (aceita texto puro)` na linha do FTP |
| Registro do container (`docker compose logs ftp`) | A cada subida: `AVISO: FTP_TLS_MODE=0, FTP sem TLS: senhas e arquivos trafegam em texto puro. Só para equipamento sem suporte a TLS, em rede interna isolada.` |
| Painel, telas Visão geral e Segurança | Faixa de alerta no topo e o item `TLS do FTP` marcado com |

O aviso informa, não bloqueia: a decisão é de quem opera o servidor. O painel web **não** é afetado por esta variável e continua só em HTTPS.

<details>
<summary>Detalhe técnico — o que muda no Pure-FTPd</summary>

`FTP_TLS_MODE` é repassada à opção `-Y` do `pure-ftpd`. Com `-Y 0`, o servidor não anuncia `AUTH TLS` e o comando é recusado; com `-Y 1`, aceita as duas formas; com `-Y 2`, recusa a sessão em texto puro com `421-Sorry, cleartext sessions and weak ciphers are not accepted on this server.`; com `-Y 3`, exige também `PROT P` no canal de dados.

O certificado do FTP é gerado em qualquer modo, e as demais camadas continuam valendo: bind só em IP privado, usuários virtuais, `chroot`, limites de sessão e container endurecido. O que se perde é o sigilo e a integridade do que trafega.

Um valor fora de `0` a `3` é recusado duas vezes: pelo [`deploy.sh`](../deploy.sh), antes de qualquer alteração, e pelo [`ftp/entrypoint.sh`](../ftp/entrypoint.sh), com `FALHA: FTP_TLS_MODE deve ser 0, 1, 2 ou 3`.

</details>

---

<a name="o-que-endurecer-antes-de-producao"></a>

## 🏭 Antes de produção

1. **Certificado real** no lugar do autoassinado: [Operação](operacao.md#certificado-real-de-producao).
2. `FTP_BIND_IP` com o IP **privado** dedicado e **regra no firewall** do host liberando só as origens de backup: [rede privada](#rede-privada).
3. **Painel:** trocar a senha inicial ([Segredos](segredos.md#senha-do-painel)), reduzir `PAINEL_REDES_PERMITIDAS` à rede de administração e liberar a porta do painel no firewall só para ela. Em `PAINEL_BIND_IP=127.0.0.1` o painel só abre no próprio servidor.
4. `fail2ban` no host lendo o log CLF do container (`docker logs allsafe-ftp`).
5. Rever `FTP_MAX_CLIENTS` e a faixa passiva conforme o número real de equipamentos: [Perfis](perfis.md).
6. Cópia de segurança agendada e levada para fora do servidor: [Backup e restauração](backup.md#automatica).
7. Conferir que `FTP_TLS_MODE` está em `2` ou `3`. Se um equipamento antigo exigir `0` ou `1`, siga antes [FTP sem TLS](#ftp-sem-tls).
8. Avaliar `FTP_TLS_MODE=3`, que obriga a criptografia também do arquivo: [Configuração](configuracao.md#tls).
9. Considerar SFTP (`allsafe-sftp-stack`) onde o equipamento suportar: canal único, sem faixa passiva.

**Resultado esperado:** `./deploy.sh --size <perfil> --check-only` responde `OK` com os valores de produção e, de fora da rede de gerência, as portas `21/tcp` e a do painel não respondem.

---

<a name="modelo-de-ameaca"></a>

## 🎯 Modelo de ameaça

| Nº | Ameaça | Mitigação nesta stack |
|---|---|---|
| 1 | Captura de credenciais em trânsito | FTPS **obrigatório** no padrão (`FTP_TLS_MODE=2`): sem TLS não há login, então usuário e senha sempre trafegam criptografados. Os modos `0` e `1` abrem mão desta proteção: [FTP sem TLS](#ftp-sem-tls) |
| 2 | Exposição acidental na internet | Bind em `127.0.0.1` por padrão; produção usa **um IP privado dedicado**, com firewall no host e sem redirecionamento de porta da borda |
| 3 | Fuga do diretório do usuário (_path traversal_) | `chroot` de todos (`-A`); cada usuário preso em `/data/<usuario>` |
| 4 | Uso de contas do sistema para login | Usuários **virtuais** em PureDB e `-u 10000` (UID mínimo). Sem anônimo (`-E`) |
| 5 | Escalonamento a partir do container | `read_only`, `cap_drop: ALL`, `no-new-privileges`, `tmpfs` com `noexec` |
| 6 | Abuso de recursos ou negação de serviço local | `-c` e `-C` (limites de sessão), `pids_limit`, `mem_limit`, `cpus`, `ulimits` |
| 7 | Vazamento de segredo pelo Git ou pela imagem | Senha em `.secrets/*.txt` (ignorado pelo Git) e `.dockerignore`; nunca em `ENV` da imagem. Veja [Segredos](segredos.md) |
| 8 | Enumeração por DNS reverso ou _fingerprint_ | `-H` (sem resolução reversa) |
| 9 | Adivinhação da senha do painel | Senha inicial de 48 caracteres, guardada só como hash `scrypt`; cinco erros em 15 minutos bloqueiam o endereço (`429`); antes disso, o nginx limita os pedidos por endereço |
| 10 | Ação forjada no painel (CSRF, _clickjacking_) | Token CSRF por sessão, conferência do `Origin`, cookie `SameSite=Strict`, `frame-ancestors 'none'` e `X-Frame-Options: DENY` |
| 11 | Roubo da sessão do painel | Só HTTPS, fechado no nginx (TLS 1.2 ou 1.3); cookie `__Host-` com `Secure` e `HttpOnly`; sessão presa ao endereço do cliente, 15 minutos sem uso e teto de 8 horas |
| 12 | Painel exposto fora da rede interna | Bind só em IP privado; lista de redes permitidas aplicada pelo nginx e conferida de novo pelo painel; conferência do `Host`; o `deploy.sh` e os containers recusam valor público |
| 13 | Painel comprometido atingir o host | Sem socket do Docker, raiz somente leitura, três capabilities, só a biblioteca padrão do Python e nenhum JavaScript |
| 14 | Enxurrada de pedidos ou pedido malformado no painel | O nginx recebe primeiro: 20 pedidos por segundo por endereço (rajada de 40), 16 conexões por endereço, pedido de até 16 KiB e prazos de 15 s. O que passa disso recebe `429`, `413` ou `400` sem chegar ao painel |
| 15 | Falha no servidor web exposto | O painel não publica porta nem escuta na rede: só o nginx fica exposto, e ele roda sem root, sem nenhuma capability, com raiz somente leitura, enxergando só `DATA_DIR/nginx` em leitura, sem a senha e sem o hash |

> ⚠️ **Limite da ameaça nº 1:** no modo `2`, o conteúdo do arquivo só é criptografado se o cliente pedir proteção do canal de dados (`PROT P`). Um equipamento que negocia TLS no login e envia os dados sem proteção é aceito. Só o modo `3` recusa esse caso. A troca do padrão está registrada no plano do projeto.

**Fora de escopo:** proteção de rede (faça ACL no host ou na borda), limitação de tentativas de força bruta **no FTP** (use `fail2ban` no host lendo os logs CLF; o painel tem limite próprio) e antivírus de conteúdo.

---

<a name="superficie-exposta"></a>

## 🌐 Superfície exposta

| Porta | Quem deve alcançar |
|---|---|
| `FTP_PORT` (controle) | Só as sub-redes de gerência dos equipamentos que fazem backup |
| Faixa passiva (dados): `30000-30049` no `small`, até `31599` no `extended` | As mesmas origens da porta de controle |
| `PAINEL_PORT` (painel, HTTPS, publicada pelo nginx) | Só as máquinas de quem administra a stack |

Todo o resto fica interno aos containers. O painel não publica porta: quem atende na `PAINEL_PORT` é o nginx. A gestão dos usuários é pelo [painel](painel.md) ou por linha de comando, com [`manage-user.sh`](../manage-user.sh).

---

<a name="painel"></a>

## 🖥️ Proteções do painel

| Proteção | Como funciona |
|---|---|
| nginx na frente | Só o nginx publica a porta do painel. Ele fecha o HTTPS, confere a rede e a taxa de pedidos e repassa ao painel por um soquete interno; o painel não escuta em porta de rede |
| Só rede interna | O nginx recusa o cliente fora de `PAINEL_REDES_PERMITIDAS` com `403`, antes de chegar ao painel; o painel confere de novo e recusa com `400` o pedido com `Host` que não seja IP privado, `localhost` ou o `PAINEL_CERT_CN` |
| Só HTTPS | TLS 1.2 ou 1.3. HTTP puro na porta do painel recebe `400` (`pedido não aceito`), sem nenhuma tela |
| Limite de pedidos | 20 pedidos por segundo por endereço, com rajada de 40, e 16 conexões por endereço; acima disso, `429`. Pedido maior que 16 KiB recebe `413` |
| Uma senha, só como hash | `scrypt` em `.secrets/painel_password_hash.txt`; o container nunca vê a senha em texto |
| Limite de tentativas de senha | Cinco senhas erradas em 15 minutos bloqueiam o endereço do cliente |
| Sessão curta | 15 minutos sem uso (`PAINEL_SESSAO_MINUTOS`) e teto de 8 horas; presa ao endereço do cliente; encerrada em `🚪 Sair` e quando o painel reinicia |
| Formulário protegido | Token CSRF por sessão e conferência do `Origin` em todo envio; `Referrer-Policy: same-origin` para o navegador informar a origem só ao próprio painel |
| Página fechada | Sem JavaScript, sem conteúdo de terceiros, sem ser embutida em outra página (`Content-Security-Policy`) |
| Auditoria | Cada entrada, saída e mudança de usuário vai para `DATA_DIR/painel/auditoria.log`, sem senha |
| Usuário inicial preservado | O `FTP_USER` não pode ser alterado nem removido pelo painel |

O que cada proteção significa na prática e o fluxograma da decisão: [Painel web](painel.md#protecoes).

> Tudo acima foi conferido nos portões de validação das versões `0.3.0` (painel) e `0.5.0` (nginx na frente), em instância de teste. O firewall do host continua sendo de quem opera o servidor.

---

<a name="hardening-do-compose-yaml-linha-a-linha"></a>

## 🧱 Endurecimento do `compose.yaml`

Os três containers sobem sem `privileged`, sem `docker.sock` e sem `network_mode: host`. O detalhe de cada linha do [`compose.yaml`](../compose.yaml) está abaixo.

<details>
<summary>Detalhe técnico — cada diretiva e o motivo</summary>

| Diretiva | Por quê |
|---|---|
| `read_only: true` | Raiz imutável; só os volumes e `tmpfs` são graváveis |
| `tmpfs: /run, /tmp` com `noexec,nosuid,nodev` | Áreas temporárias sem execução de binário nem `setuid` |
| `cap_drop: [ALL]` | Zera privilégios e devolve só o mínimo (tabela seguinte) |
| `security_opt: [no-new-privileges:true]` | Impede ganho de privilégio por `setuid` ou `setgid` depois do início |
| `pids_limit` | Barreira contra _fork bomb_ |
| `mem_limit` e `cpus` | Contém o consumo; evita afetar vizinhos no host |
| `ulimits.nofile` | Teto de descritores de arquivo |
| `init: true` | `tini` como processo 1: recolhe processos zumbis e repassa os sinais |
| `stop_grace_period: 20s` | Deixa transferências em curso terminarem no `down` |
| `logging: local` (10 MB × 3) | Log rotacionado, sem encher o disco |
| `restart: unless-stopped` | Volta depois de reiniciar o host, respeita `stop` manual |

</details>

<details>
<summary>Detalhe técnico — <code>cap_add</code>: por que cada uma</summary>

O `pure-ftpd` sobe como `root`, aplica `chroot` e **troca** para um usuário sem privilégio por sessão. Isso exige:

| Capability | Uso |
|---|---|
| `SYS_CHROOT` | `chroot()` de cada sessão |
| `SETUID` e `SETGID` | Descer para o uid e gid do usuário virtual |
| `CHOWN` e `FOWNER` | Ajustar dono e permissão dos diretórios criados (`-j`) |
| `DAC_OVERRIDE` e `DAC_READ_SEARCH` | Ler e gravar nos diretórios dos usuários independentemente do bit de permissão |
| `NET_BIND_SERVICE` | Exigida pelo `pure-ftpd` na partida, mesmo com o serviço em `2121` (porta não privilegiada): sem ela o servidor encerra e o container não sobe |
| `SYS_NICE` | Prioridade de I/O das transferências |
| `AUDIT_WRITE` | Registro de login (PAM e utmp) sem erro |

Nenhuma delas permite montar sistema de arquivos, carregar módulo, usar `ptrace` ou acessar `/dev`.

</details>

<details>
<summary>Detalhe técnico — o serviço <code>painel</code></summary>

O painel usa as mesmas diretivas do `ftp` (`read_only`, `tmpfs`, `cap_drop: [ALL]`, `no-new-privileges`, `init`, `logging`), com limites menores: `192M` de memória, `0.5` CPU e `64` processos. Só inicia depois de o `ftp` ficar `healthy`.

| Capability | Uso |
|---|---|
| `CHOWN` | Entregar ao `ftpdata` a pasta do usuário criado e ajustar o dono de `/painel` |
| `FOWNER` | Ajustar a permissão da pasta do usuário depois de entregue ao `ftpdata` |
| `DAC_OVERRIDE` | Ler o tamanho das pastas dos usuários, que pertencem ao `ftpdata` com modo `0750` |

O painel **não** tem `SYS_CHROOT`, `SETUID`, `SETGID` nem `NET_BIND_SERVICE`, e **não escuta em porta de rede**: atende por um soquete Unix, `/nginx/painel.sock`, que só o root do container e o grupo do nginx abrem (`0660`, dono `0:10001`). O endereço do cliente vem do nginx, em `X-Real-IP`; pedido que chegue ao soquete sem esse cabeçalho, com dois ou com valor que não é IP recebe `400`. Não monta `DATA_DIR/certs`: a chave privada do FTP fica fora do alcance dele. Para mostrar a impressão digital, lê `ftp-cert.pem`, a cópia **sem a chave** que o entrypoint do FTP grava em `DATA_DIR/auth`.

</details>

<details>
<summary>Detalhe técnico — o serviço <code>nginx</code></summary>

O nginx é o único container que publica a porta do painel, e por isso é o mais fechado dos três. Só inicia depois de o `painel` ficar `healthy`.

| Diretiva | Valor | Por quê |
|---|---|---|
| `user` | `10001:10001` | O processo nunca é root: o entrypoint para com `FALHA: o nginx desta stack não roda como root` se for |
| `cap_drop` | `ALL`, sem `cap_add` | Nenhuma capability. A porta interna é a `8443`, não privilegiada |
| `read_only` e `tmpfs` | raiz imutável; `/run/nginx` e `/tmp/nginx` em memória | A configuração é gerada a cada subida em `/run/nginx`, a partir de [`nginx/nginx.conf.modelo`](../nginx/nginx.conf.modelo) |
| Volume | `DATA_DIR/nginx` em `/nginx`, **somente leitura** | É tudo o que ele enxerga: o soquete do painel e a cópia do certificado |
| Limites | `64M` de memória, `0.5` CPU, `32` processos | Um servidor web pequeno não precisa de mais |
| Ambiente | só `TZ` e `PAINEL_REDES_PERMITIDAS` | Não recebe senha, hash nem segredo do Compose |

O que a configuração fixa: TLS 1.2 e 1.3 com cifras ECDHE; só as redes de `PAINEL_REDES_PERMITIDAS`, depois `deny all`; 20 pedidos por segundo por endereço, com rajada de 40; 16 conexões por endereço; pedido de até 16 KiB; prazos de 15 s; `server_tokens off`. O endereço do cliente segue para o painel em `X-Real-IP`, sempre sobrescrito pelo nginx; `X-Forwarded-For` e `Forwarded` vindos do cliente são apagados.

O nginx registra só o que ele mesmo recusa, no formato `ip método caminho código`, sem a consulta da URL e sem cabeçalho: nenhum cookie e nenhuma senha chegam ao registro.

</details>

---

<a name="gestao-de-segredos"></a>

## 🔑 Gestão de segredos

- Senha do usuário inicial: `.secrets/ftp_password.txt`, `chmod 600`, entregue **só** ao serviço `ftp` como o segredo `/run/secrets/ftp_password`, somente leitura. O `.env` não guarda senha. Veja [Segredos](segredos.md).
- Senha do painel: só o hash `scrypt`, em `.secrets/painel_password_hash.txt`, entregue **só** ao serviço `painel` como `/run/secrets/painel_password_hash`. A senha inicial em texto (`painel_password.txt`) fica no host e é apagada na primeira troca.
- Chave do certificado do painel: gerada em `DATA_DIR/painel/tls` e copiada a cada subida para `DATA_DIR/nginx/tls`, que o nginx monta somente leitura (chave `0640`, grupo `10001`; pasta `0750`). Veja [Segredos](segredos.md).
- [`.gitignore`](../.gitignore): `.env` e `.secrets/*.txt` (mantém só `.secrets/.gitkeep`, para a pasta existir no clone).
- [`.dockerignore`](../.dockerignore): `.env`, `.env.example`, `.git`, `.gitignore`, `.secrets`, `doc`, `profiles`, `README.md`, `deploy.sh` e `manage-user.sh`. `*.pdf` também fica fora. Chegam ao build o `Dockerfile`, o `compose.yaml`, o `CHANGELOG.md`, o `VERSION` e as pastas `scripts/`, `painel/` e `nginx/`, e o `Dockerfile` copia só os scripts, o painel, a configuração do nginx e o `VERSION`; nada de segredo entra na imagem.
- O [`ftp/entrypoint.sh`](../ftp/entrypoint.sh) recusa senha em variável de ambiente e faz `unset` da variável interna da senha antes do `exec`. O [`painel/entrypoint.sh`](../painel/entrypoint.sh) recusa `PAINEL_PASSWORD` e `PAINEL_PASSWORD_HASH`.

---

⬅️ [Arquitetura](arquitetura.md) · 🏠 [Documentação](README.md) · ➡️ [Segredos](segredos.md)
