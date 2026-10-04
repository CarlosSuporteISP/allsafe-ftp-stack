# 🖥️ Painel web — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [Índice da documentação](README.md)

## 💡 Em poucas palavras

O painel é uma página, aberta pelo navegador **de dentro da rede interna**, para criar, trocar a senha e remover os usuários do FTP sem usar a linha de comando. Entra-se com uma senha de administrador, só por HTTPS. Quem atende o navegador é o nginx, a porta de entrada: ele barra quem está fora da rede interna e só então passa o pedido ao painel. O que é feito no painel vale no FTP na hora, sem reiniciar nada.

<!-- diagrama: diagramas/painel-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    usuario@{ shape: person, label: "Usuário<br>navegador na rede interna" }
    nginx@{ shape: rect, label: "nginx<br>allsafe-ftp-nginx, HTTPS" }
    painel@{ shape: rect, label: "Painel web<br>allsafe-ftp-painel" }
    cmd@{ shape: rect, label: "allsafe-ftp-user<br>cria, troca a senha, remove" }
    puredb@{ shape: cyl, label: "PureDB<br>usuários virtuais" }
    fim@{ shape: stadium, label: "usuário pronto no FTP" }

    usuario --> nginx --> painel --> cmd --> puredb --> fim
```

<sub>Nível 1 · Diagrama · [fonte](diagramas/)</sub>

**Sequência:** Usuário (navegador na rede interna) ➜ nginx (`allsafe-ftp-nginx`, HTTPS) ➜ Painel web (`allsafe-ftp-painel`) ➜ `allsafe-ftp-user` ➜ PureDB ➜ usuário pronto no FTP

> 🧱 **Uso só em rede privada, atrás de firewall.** O painel administra as contas que guardam a configuração da sua rede. Ele escuta **apenas em IP privado**, recusa cliente de fora das redes internas e **nunca** deve ser publicado na internet nem receber redirecionamento de porta da borda. Quem precisa chegar de fora entra por VPN até a rede interna. Veja [rede privada e firewall](seguranca.md#rede-privada).

---

<details>
<summary>Sumário — clique para expandir</summary>

[Abrir o painel](#abrir) · [O que há em cada aba](#abas) · [Usuários pelo painel](#usuarios) · [Senha do painel](#senha) · [Certificado do painel](#certificado) · [Abrir para a rede interna](#rede-interna) · [Como o painel decide](#como-decide) · [Auditoria](#auditoria) · [O que protege o painel](#protecoes)

</details>

---

<a name="abrir"></a>

## 🚪 Abrir o painel

O `./deploy.sh` sobe o painel junto com o FTP e mostra o endereço no fim:

```text
Painel: https://127.0.0.1:8443  (pelo nginx; certificado autoassinado; só rede privada, atrás de firewall)
```

1. Abra o endereço no navegador. Na instalação padrão, só o próprio servidor alcança (`127.0.0.1`).
2. O navegador avisa que o certificado é autoassinado: confira a impressão digital (comando abaixo) antes de aceitar.
3. Digite a senha de administrador. Na primeira instalação ela está em `.secrets/painel_password.txt`:

```bash
cat .secrets/painel_password.txt
```

**Resultado esperado:** a tela **Visão geral**, com o FTP `🟢 No ar`.

Impressão digital do certificado do painel, para comparar com a que o navegador mostra:

```bash
docker compose exec painel openssl x509 -in /painel/tls/painel-cert.pem -noout -fingerprint -sha256
```

> ⚠️ Troque a senha inicial depois do primeiro acesso: [Senha do painel](#senha). Nunca cole a senha em documento, captura de tela ou mensagem.

---

<a name="abas"></a>

## 🗂️ O que há em cada aba

| Aba | O que mostra | O que dá para fazer |
|---|---|---|
| Visão geral | FTP no ar ou fora, quantidade de usuários, espaço usado e livre, último envio, validade do certificado do FTP o modo de TLS do FTP e os dados para configurar o equipamento (servidor, porta de controle, portas passivas, protocolo) | Só consultar |
| Usuários | Um usuário por linha: pasta no host, espaço usado, quantidade de arquivos e último envio | Criar, trocar a senha e remover |
| Segurança | Conferência da instalação: endereços do FTP e do painel, modo TLS, a frente web (nginx), validade e impressão digital dos dois certificados, redes que podem abrir o painel, regras da sessão, isolamento do container e o lembrete do firewall | Só consultar |
| Atividade | Os últimos 300 registros do painel: entradas, recusas e alterações de usuário, com data e endereço de origem | Só consultar |

O botão **Sair**, no topo, encerra a sessão na hora.

> ⚠️ Com `FTP_TLS_MODE` em `0` ou `1`, as abas Visão geral e Segurança abrem com um alerta no topo: o FTP está aceitando senha e arquivo em texto puro. O alerta só some quando a variável volta para `2` ou `3`. Veja [Segurança](seguranca.md#ftp-sem-tls).

---

<a name="usuarios"></a>

## 👥 Usuários pelo painel

| Quero | Onde | O que acontece |
|---|---|---|
| Criar um usuário | Usuários ➜ **Novo usuário** | Cria a conta e a pasta `DATA_DIR/dados/<usuario>`. Com a senha em branco, o painel gera uma senha forte e a mostra **uma única vez** |
| Trocar a senha | Usuários ➜ **Trocar senha** | A senha antiga deixa de valer no próximo login |
| Remover um usuário | Usuários ➜ **Remover** | Pede confirmação. A conta some; **os arquivos da pasta são preservados** |

**Resultado esperado:** o usuário criado entra por FTPS logo em seguida, sem reiniciar o FTP.

Regras, as mesmas do [`manage-user.sh`](../manage-user.sh):

- Nome com letras minúsculas, números, `_` e `-`, começando por letra ou `_`, até 32 caracteres.
- Senha com no mínimo 12 caracteres.
- O **usuário inicial** (`FTP_USER`) não é alterado pelo painel: a senha dele vem de `.secrets/ftp_password.txt` e é reaplicada a cada subida do FTP. Veja [Segredos](segredos.md#trocar-a-senha).

A linha de comando continua valendo: painel e `manage-user.sh` alteram as mesmas contas. Veja [Operação](operacao.md#usuarios).

---

<a name="senha"></a>

## 🔑 Senha do painel

O painel tem **uma** senha de administrador. Só o hash dela fica guardado, em `.secrets/painel_password_hash.txt`.

| Quero | Comando |
|---|---|
| Escolher a senha nova | `./scripts/painel-senha.sh` (pergunta duas vezes) |
| Deixar o script gerar uma senha forte | `./scripts/painel-senha.sh --gerar` (mostra uma única vez) |

**Resultado esperado:**

```text
Hash gravado em ./.secrets/painel_password_hash.txt; painel reiniciado e sessões abertas encerradas.
```

Depois da troca, a senha antiga é recusada, quem estava dentro do painel volta para a tela de entrada e o arquivo `.secrets/painel_password.txt` (a senha inicial em texto) é apagado. Detalhe em [Segredos](segredos.md#senha-do-painel).

> ⚠️ Perdeu a senha? Rode `./scripts/painel-senha.sh` de novo no servidor: quem tem acesso ao host define uma nova. Não existe recuperação pelo navegador.

---

<a name="certificado"></a>

## 🔏 Certificado do painel

Na primeira subida o painel gera um certificado **autoassinado**, válido para `localhost`, `127.0.0.1`, o `PAINEL_BIND_IP` e o `PAINEL_CERT_CN`. Ele é refeito sozinho quando esses endereços mudam ou quando faltam menos de 30 dias para vencer.

Para usar um certificado da sua autoridade certificadora interna:

```bash
install -m 0644 certificado.pem "$DATA_DIR/painel/tls/painel-cert.pem"
install -m 0600 chave.pem       "$DATA_DIR/painel/tls/painel-key.pem"
rm "$DATA_DIR/painel/tls/painel-san.txt"      # sem este arquivo, a stack não refaz o certificado
docker compose restart painel
```

**Resultado esperado:** o navegador abre o painel sem aviso e a aba Segurança mostra a validade e a impressão digital do certificado novo. O reinício do painel leva o certificado para o nginx e reinicia o nginx junto: o painel fica alguns segundos fora do ar.

`DATA_DIR/painel` pertence ao `root`: rode os comandos com `sudo`, trocando `$DATA_DIR` pelo valor do seu `.env`.

---

<a name="rede-interna"></a>

## 🌐 Abrir para a rede interna

Por padrão o painel só responde no próprio servidor. Para abrir pela rede de gerência, ajuste o `.env` e rode o `deploy.sh` de novo:

| Variável | Troque para |
|---|---|
| `PAINEL_BIND_IP` | o IP **privado** do servidor na rede de gerência (nunca `0.0.0.0` nem IP público) |
| `PAINEL_REDES_PERMITIDAS` | só as redes internas de onde o painel é administrado, por exemplo `10.10.0.0/24` |
| `PAINEL_CERT_CN` | o nome interno pelo qual o painel é aberto, se houver (o `PAINEL_BIND_IP` já entra no certificado) |

Depois, **libere a porta do painel no firewall do host só para a rede de gerência**: [rede privada e firewall](seguranca.md#rede-privada).

**Resultado esperado:** de uma máquina da rede de gerência, `https://<PAINEL_BIND_IP>:8443` abre a tela de entrada; de qualquer outra rede, a porta não responde.

Todas as variáveis em [Configuração](configuracao.md#painel).

<details>
<summary>Detalhe técnico — o endereço que o painel enxerga</summary>

O nginx fica atrás do NAT do Docker. Um cliente da rede interna chega com o próprio IP; já um acesso feito **do próprio servidor** chega com o IP do gateway da rede do Compose (`172.29.1.1` na sub-rede padrão `172.29.1.0/29`). Os dois casos estão cobertos pela lista padrão de `PAINEL_REDES_PERMITIDAS`. Ao restringir a lista a uma rede só, inclua a sub-rede do Compose (`FTP_SUBNET`) se quiser continuar abrindo o painel de dentro do servidor.

O nginx entrega o endereço que viu ao painel no cabeçalho `X-Real-IP`, sempre sobrescrito por ele: o que o cliente mandar nesse cabeçalho, ou em `X-Forwarded-For`, é descartado. É esse endereço que vale para a sessão, para o bloqueio por senha errada e para a auditoria.

A lista é aplicada duas vezes: pelo nginx, antes de o pedido chegar ao painel, e pelo painel, antes de qualquer tela. Na frente das duas está o firewall do host, que a stack não enxerga nem altera.

</details>

---

<a name="como-decide"></a>

## 🔄 Como o painel decide

Cada pedido passa por três conferências antes de mudar alguma coisa: a rede de origem (nginx), a senha e o token do formulário (painel).

<details>
<summary>Fluxograma do painel, com a sequência escrita — clique para expandir</summary>

<!-- diagrama: diagramas/painel-fluxograma.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    subgraph QUEM["Quem usa"]
        usuario@{ shape: person, label: "Usuário<br>navegador na rede interna" }
    end
    subgraph FRENTE["Frente web"]
        nginx@{ shape: rect, label: "nginx<br>allsafe-ftp-nginx, HTTPS" }
        rede@{ shape: diam, label: "rede permitida<br>e dentro do limite?" }
    end
    subgraph ENTRADA["Entrada"]
        painel@{ shape: rect, label: "Painel web<br>allsafe-ftp-painel, soquete Unix" }
        senha@{ shape: diam, label: "senha<br>confere?" }
        hash@{ shape: doc, label: "hash da senha<br>painel_password_hash" }
    end
    subgraph SESSAO["Sessão"]
        sessao@{ shape: rect, label: "sessão de 15 min<br>cookie e token CSRF" }
        pedido@{ shape: diam, label: "pedido<br>legítimo?" }
    end
    subgraph USUARIOS["Usuários do FTP"]
        cmd@{ shape: rect, label: "allsafe-ftp-user<br>pure-pw" }
        puredb@{ shape: cyl, label: "PureDB<br>DATA_DIR/auth" }
        auditoria@{ shape: docs, label: "auditoria.log<br>DATA_DIR/painel" }
    end
    subgraph RESULTADO["Resultado"]
        fim@{ shape: stadium, label: "usuário pronto no FTP" }
        recusa@{ shape: stadium, label: "pedido recusado" }
    end

    usuario -- "1 · abre https, TCP 8443" --> nginx
    nginx -- "2 · confere a origem e a taxa de pedidos" --> rede
    rede -- "3a · sim: repassa pelo soquete Unix" --> painel
    rede -- "3b · não: 403 ou 429" --> recusa
    painel -- "4 · pede a senha" --> senha
    senha -. "5 · compara com o hash" .-> hash
    senha -- "6a · sim: abre a sessão" --> sessao
    senha -- "6b · não: 5 erros bloqueiam o endereço" --> recusa
    sessao -- "7 · envia o formulário" --> pedido
    pedido -- "8a · sim: executa" --> cmd
    pedido -- "8b · não: sem token CSRF ou de outra origem" --> recusa
    cmd -- "9 · grava o usuário" --> puredb
    puredb -- "10 · vale no próximo login, sem reiniciar o FTP" --> fim
    painel -. "registra cada ação" .-> auditoria
```

<sub>Nível 2 · Fluxograma · [fonte](diagramas/)</sub>

| Nº | De ➜ Para | O que acontece |
|---|---|---|
| 1 | Usuário ➜ nginx | O navegador abre `https://<endereço>:8443`; só HTTPS, com TLS 1.2 ou 1.3 |
| 2 | nginx ➜ rede permitida e dentro do limite? | O endereço de origem é comparado com `PAINEL_REDES_PERMITIDAS`, e o pedido, com os limites de taxa, de conexões e de tamanho |
| 3a | rede permitida e dentro do limite? ➜ Painel web | Sim: o nginx repassa o pedido pelo soquete Unix, com o endereço do cliente |
| 3b | rede permitida e dentro do limite? ➜ pedido recusado | Não: `403` para rede de fora, `429` para pedidos demais; o painel nem recebe o pedido |
| 4 | Painel web ➜ senha confere? | O painel confere de novo a rede e o nome de host e mostra a tela de entrada |
| 5 | senha confere? ➜ hash da senha | A senha digitada é comparada com o hash `scrypt` de `/run/secrets/painel_password_hash` |
| 6a | senha confere? ➜ sessão | Sim: abre a sessão, com cookie e token CSRF |
| 6b | senha confere? ➜ pedido recusado | Não: `401`; cinco erros em 15 minutos bloqueiam o endereço (`429`) |
| 7 | sessão ➜ pedido legítimo? | Cada formulário enviado traz o token CSRF da sessão e a origem do próprio painel |
| 8a | pedido legítimo? ➜ `allsafe-ftp-user` | Sim: o painel chama o comando, com a senha pela entrada padrão |
| 8b | pedido legítimo? ➜ pedido recusado | Não: `403`, sem alterar nada |
| 9 | `allsafe-ftp-user` ➜ PureDB | A conta é gravada em `DATA_DIR/auth`, com trava para uma alteração por vez |
| 10 | PureDB ➜ usuário pronto no FTP | O FTP lê o banco a cada login: vale na hora, sem reiniciar |

**Apoio**

| Quem | Usa | Como |
|---|---|---|
| senha confere? | hash da senha (`painel_password_hash`) | lê a cada entrada, somente leitura |
| Painel web | `auditoria.log` | registra cada entrada, recusa e alteração |

</details>

---

<a name="auditoria"></a>

## 📜 Auditoria

Tudo o que o painel faz fica em `DATA_DIR/painel/auditoria.log` (`0600`, do `root`) e aparece na aba Atividade.

```text
2026-10-04T08:33:49-0300 ip=172.29.1.1 evento=usuario_criado usuario=equip01 credencial=informada
2026-10-04T08:33:46-0300 ip=172.29.1.1 evento=entrada_falha
```

| Evento | Quando acontece |
|---|---|
| `painel_iniciado` | O painel subiu |
| `entrada_ok` · `entrada_falha` · `entrada_bloqueada` | Entrada aceita · senha errada · endereço bloqueado por excesso de erros |
| `saida` | Alguém clicou em **Sair** |
| `usuario_criado` · `senha_trocada` · `usuario_removido` | Alteração de usuário do FTP |
| `falha_comando` | O `allsafe-ftp-user` devolveu erro |
| `recusa_csrf` · `recusa_origem` · `recusa_host` · `recusa_rede` | Pedido recusado: sem token, de outra origem, com nome de host inválido ou de rede não permitida |

Quem está fora das redes permitidas é barrado antes, pelo nginx: essa recusa fica no log dele (`docker compose logs nginx`), não aqui. O `recusa_rede` só aparece se um pedido assim chegar ao painel.

Senha, token e cookie **nunca** são gravados. As transferências dos equipamentos não ficam aqui: estão no log do FTP, em [Operação](operacao.md#logs).

---

<a name="protecoes"></a>

## 🛡️ O que protege o painel

| Camada | Proteção |
|---|---|
| Frente web | O nginx é a única porta publicada do painel; o painel atende só por soquete Unix e não escuta em porta de rede |
| Rede | Bind só em IP privado; `PAINEL_REDES_PERMITIDAS` só com redes privadas, aplicada pelo nginx e conferida de novo pelo painel; `deploy.sh` e os dois containers recusam o resto |
| Transporte | Só HTTPS, TLS 1.2 ou 1.3; HTTP puro recebe `400` |
| Volume de pedidos | No nginx, por endereço: 20 pedidos por segundo (rajada de 40), 16 conexões e 16 KiB por pedido; o que passa disso recebe `429` ou `413` |
| Entrada | Senha de no mínimo 12 caracteres, guardada como hash `scrypt`; cinco erros bloqueiam o endereço por 15 minutos |
| Sessão | Cookie `__Host-sessao` com `Secure`, `HttpOnly` e `SameSite=Strict`, presa ao endereço de origem; encerra com 15 minutos sem uso e, de qualquer forma, em 8 horas |
| Formulários | Token CSRF por sessão e conferência de `Origin`; corpo limitado a 8 KiB |
| Navegador | `Content-Security-Policy` sem script, `X-Frame-Options: DENY`, `nosniff`, HSTS e `no-store`; a página não carrega nada de fora |
| Containers | Raiz somente leitura, `cap_drop: ALL`, `no-new-privileges`, sem socket do Docker, limites de CPU, memória e processos; o nginx roda sem root e sem nenhuma capability |

<details>
<summary>Detalhe técnico — implementação</summary>

- **Código:** [`painel/servidor.py`](../painel/servidor.py), só com a biblioteca padrão do Python 3.13 do Debian 13; a aparência está em [`painel/estilo.css`](../painel/estilo.css). Não há JavaScript, fonte nem imagem externa.
- **Imagem:** alvo `painel` do [`Dockerfile`](../Dockerfile), sobre a mesma base do FTP (traz o `pure-pw` e o `allsafe-ftp-user`). Imagem `PAINEL_IMAGE`, container `PAINEL_CONTAINER_NAME`.
- **Entrada do container:** [`scripts/painel-entrypoint.sh`](../scripts/painel-entrypoint.sh) recusa senha em variável, confere IP e redes privados, ajusta dono e modo de `/painel`, gera o certificado, copia-o para a pasta do nginx e executa o servidor.
- **Frente web:** alvo `nginx` do [`Dockerfile`](../Dockerfile), nginx 1.26 do Debian 13, configurado por [`nginx/nginx.conf.modelo`](../nginx/nginx.conf.modelo). O painel escuta no soquete `/nginx/painel.sock` (`0660`, grupo `10001`) e só aceita pedido com exatamente um `X-Real-IP` válido; sem ele, responde `400`. Detalhe em [Segurança](seguranca.md#painel).
- **Hash da senha:** `scrypt` com `N=2^15`, `r=8`, `p=1` e sal de 16 bytes, no formato `scrypt$15$8$1$<sal>$<resumo>`. É lido de `/run/secrets/painel_password_hash` a cada entrada e comparado em tempo constante.
- **Sessão:** o token do cookie tem 256 bits aleatórios e o servidor guarda só o resumo SHA-256 dele, em memória. Reiniciar o painel encerra todas as sessões e zera a contagem de erros de entrada.
- **Tela de entrada:** o formulário leva um token assinado (HMAC) com validade curta, para a entrada também não aceitar pedido forjado por outro site.
- **Nome de host:** o cabeçalho `Host` tem de ser um IP privado, `localhost` ou o `PAINEL_CERT_CN`; outro nome recebe `400`.
- **Usuários do FTP:** o painel monta as mesmas pastas `DATA_DIR/auth` e `DATA_DIR/dados` do serviço `ftp` e chama o mesmo `allsafe-ftp-user`, com `flock` em `/auth/.lock`. Por isso não precisa do socket do Docker.
- **Capabilities devolvidas:** `CHOWN`, `DAC_OVERRIDE` e `FOWNER`, para criar a pasta do usuário com o dono `ftpdata` e gravar em `/auth`. Nenhuma de rede.
- **Saúde:** `python3 /opt/painel/servidor.py --saude` pede `/saude` pelo soquete Unix. O healthcheck do nginx faz o mesmo pedido por TLS, em `127.0.0.1:8443`, e confere o caminho inteiro.
- **Limites:** `PAINEL_MEMORY_LIMIT`, `PAINEL_CPU_LIMIT` e `PAINEL_PIDS_LIMIT`, em [Configuração](configuracao.md#painel).

</details>

---

⬅️ [Operação](operacao.md) · 🏠 [Documentação](README.md) · ➡️ [Solução de problemas](solucao-de-problemas.md)
