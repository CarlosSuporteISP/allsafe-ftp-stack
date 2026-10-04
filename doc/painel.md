# 🖥️ Painel web — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [📚 Índice da documentação](README.md)

## 💡 Em poucas palavras

O painel é uma página, aberta pelo navegador **de dentro da rede interna**, para criar, trocar a senha e remover os usuários do FTP sem usar a linha de comando. Entra-se com uma senha de administrador, só por HTTPS. O que é feito no painel vale no FTP na hora, sem reiniciar nada.

<!-- diagrama: diagramas/painel-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    usuario@{ shape: person, label: "👤 Usuário<br>navegador na rede interna" }
    painel@{ shape: rect, label: "🖥️ Painel web<br>allsafe-ftp-painel, HTTPS" }
    cmd@{ shape: rect, label: "⚙️ allsafe-ftp-user<br>cria, troca a senha, remove" }
    puredb@{ shape: cyl, label: "🗄️ PureDB<br>usuários virtuais" }
    fim@{ shape: stadium, label: "🏁 usuário pronto no FTP" }

    usuario --> painel --> cmd --> puredb --> fim
```

<sub>📐 Nível 1 · Diagrama · 🔍 aproximar e mover: controles no canto do diagrama · 📁 [fonte](diagramas/)</sub>

**🧭 Sequência:** 👤 Usuário (navegador na rede interna) ➜ 🖥️ Painel web (`allsafe-ftp-painel`, HTTPS) ➜ ⚙️ `allsafe-ftp-user` ➜ 🗄️ PureDB ➜ 🏁 usuário pronto no FTP

> 🧱 **Uso só em rede privada, atrás de firewall.** O painel administra as contas que guardam a configuração da sua rede. Ele escuta **apenas em IP privado**, recusa cliente de fora das redes internas e **nunca** deve ser publicado na internet nem receber redirecionamento de porta da borda. Quem precisa chegar de fora entra por VPN até a rede interna. Veja [🧱 rede privada e firewall](seguranca.md#rede-privada).

---

<details>
<summary>🧭 Sumário — clique para expandir</summary>

[🚪 Abrir o painel](#abrir) · [🗂️ O que há em cada aba](#abas) · [👥 Usuários pelo painel](#usuarios) · [🔑 Senha do painel](#senha) · [🔏 Certificado do painel](#certificado) · [🌐 Abrir para a rede interna](#rede-interna) · [🔄 Como o painel decide](#como-decide) · [📜 Auditoria](#auditoria) · [🛡️ O que protege o painel](#protecoes)

</details>

---

<a name="abrir"></a>

## 🚪 Abrir o painel

O `./deploy.sh` sobe o painel junto com o FTP e mostra o endereço no fim:

```text
Painel: https://127.0.0.1:8443  (certificado autoassinado; só rede privada, atrás de firewall)
```

1. Abra o endereço no navegador. Na instalação padrão, só o próprio servidor alcança (`127.0.0.1`).
2. O navegador avisa que o certificado é autoassinado: confira a impressão digital (comando abaixo) antes de aceitar.
3. Digite a senha de administrador. Na primeira instalação ela está em `.secrets/painel_password.txt`:

```bash
cat .secrets/painel_password.txt
```

**Resultado esperado:** a tela **📊 Visão geral**, com o FTP `🟢 No ar`.

Impressão digital do certificado do painel, para comparar com a que o navegador mostra:

```bash
docker compose exec painel openssl x509 -in /painel/tls/painel-cert.pem -noout -fingerprint -sha256
```

> ⚠️ Troque a senha inicial depois do primeiro acesso: [🔑 Senha do painel](#senha). Nunca cole a senha em documento, captura de tela ou mensagem.

> 📸 PENDENTE: capturas reais das telas do painel (uma por aba), a gerar com a instalação definitiva no ar.

---

<a name="abas"></a>

## 🗂️ O que há em cada aba

| Aba | O que mostra | O que dá para fazer |
|---|---|---|
| 📊 Visão geral | FTP no ar ou fora, quantidade de usuários, espaço usado e livre, último envio, validade do certificado do FTP e os dados para configurar o equipamento (servidor, porta de controle, portas passivas, protocolo) | Só consultar |
| 👥 Usuários | Um usuário por linha: pasta no host, espaço usado, quantidade de arquivos e último envio | Criar, trocar a senha e remover |
| 🔐 Segurança | Conferência da instalação: endereços do FTP e do painel, modo TLS, validade e impressão digital dos dois certificados, redes que podem abrir o painel, regras da sessão, isolamento do container e o lembrete do firewall | Só consultar |
| 📜 Atividade | Os últimos 300 registros do painel: entradas, recusas e alterações de usuário, com data e endereço de origem | Só consultar |

O botão **Sair**, no topo, encerra a sessão na hora.

---

<a name="usuarios"></a>

## 👥 Usuários pelo painel

| Quero | Onde | O que acontece |
|---|---|---|
| Criar um usuário | 👥 Usuários ➜ **Novo usuário** | Cria a conta e a pasta `DATA_DIR/dados/<usuario>`. Com a senha em branco, o painel gera uma senha forte e a mostra **uma única vez** |
| Trocar a senha | 👥 Usuários ➜ **Trocar senha** | A senha antiga deixa de valer no próximo login |
| Remover um usuário | 👥 Usuários ➜ **Remover** | Pede confirmação. A conta some; **os arquivos da pasta são preservados** |

**Resultado esperado:** o usuário criado entra por FTPS logo em seguida, sem reiniciar o FTP.

Regras, as mesmas do [`manage-user.sh`](../manage-user.sh):

- Nome com letras minúsculas, números, `_` e `-`, começando por letra ou `_`, até 32 caracteres.
- Senha com no mínimo 12 caracteres.
- O **usuário inicial** (`FTP_USER`) não é alterado pelo painel: a senha dele vem de `.secrets/ftp_password.txt` e é reaplicada a cada subida do FTP. Veja [🔑 Segredos](segredos.md#trocar-a-senha).

A linha de comando continua valendo: painel e `manage-user.sh` alteram as mesmas contas. Veja [🧰 Operação](operacao.md#usuarios).

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

Depois da troca, a senha antiga é recusada, quem estava dentro do painel volta para a tela de entrada e o arquivo `.secrets/painel_password.txt` (a senha inicial em texto) é apagado. Detalhe em [🔑 Segredos](segredos.md#senha-do-painel).

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

**Resultado esperado:** o navegador abre o painel sem aviso e a aba 🔐 Segurança mostra a validade e a impressão digital do certificado novo.

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

Depois, **libere a porta do painel no firewall do host só para a rede de gerência**: [🧱 rede privada e firewall](seguranca.md#rede-privada).

**Resultado esperado:** de uma máquina da rede de gerência, `https://<PAINEL_BIND_IP>:8443` abre a tela de entrada; de qualquer outra rede, a porta não responde.

Todas as variáveis em [⚙️ Configuração](configuracao.md#painel).

<details>
<summary>🔬 Detalhe técnico — o endereço que o painel enxerga</summary>

O container fica atrás do NAT do Docker. Um cliente da rede interna chega com o próprio IP; já um acesso feito **do próprio servidor** chega com o IP do gateway da rede do Compose (`172.29.1.1` na sub-rede padrão `172.29.1.0/29`). Os dois casos estão cobertos pela lista padrão de `PAINEL_REDES_PERMITIDAS`. Ao restringir a lista a uma rede só, inclua a sub-rede do Compose (`FTP_SUBNET`) se quiser continuar abrindo o painel de dentro do servidor.

A lista é uma **segunda barreira**, aplicada pelo painel antes de qualquer tela. A primeira é o firewall do host, que o painel não enxerga.

</details>

---

<a name="como-decide"></a>

## 🔄 Como o painel decide

<!-- diagrama: diagramas/painel-fluxograma.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    subgraph QUEM["👤 Quem usa"]
        usuario@{ shape: person, label: "👤 Usuário<br>navegador na rede interna" }
    end
    subgraph ENTRADA["🚪 Entrada"]
        painel@{ shape: rect, label: "🖥️ Painel web<br>allsafe-ftp-painel, HTTPS" }
        rede@{ shape: diam, label: "❓ rede<br>permitida?" }
        senha@{ shape: diam, label: "❓ senha<br>confere?" }
        hash@{ shape: doc, label: "🔑 hash da senha<br>painel_password_hash" }
    end
    subgraph SESSAO["🔒 Sessão"]
        sessao@{ shape: rect, label: "🔒 sessão de 15 min<br>cookie e token CSRF" }
        pedido@{ shape: diam, label: "❓ pedido<br>legítimo?" }
    end
    subgraph USUARIOS["👥 Usuários do FTP"]
        cmd@{ shape: rect, label: "⚙️ allsafe-ftp-user<br>pure-pw" }
        puredb@{ shape: cyl, label: "🗄️ PureDB<br>DATA_DIR/auth" }
        auditoria@{ shape: docs, label: "📚 auditoria.log<br>DATA_DIR/painel" }
    end
    subgraph RESULTADO["🏁 Resultado"]
        fim@{ shape: stadium, label: "🏁 usuário pronto no FTP" }
        recusa@{ shape: stadium, label: "⛔ pedido recusado" }
    end

    usuario -- "1 · abre https, TCP 8443" --> painel
    painel -- "2 · confere o endereço de origem" --> rede
    rede -- "3a · ✅ sim: pede a senha" --> senha
    rede -- "3b · ❌ não" --> recusa
    senha -. "4 · compara com o hash" .-> hash
    senha -- "5a · ✅ sim: abre a sessão" --> sessao
    senha -- "5b · ❌ não: 5 erros bloqueiam o endereço" --> recusa
    sessao -- "6 · envia o formulário" --> pedido
    pedido -- "7a · ✅ sim: executa" --> cmd
    pedido -- "7b · ❌ não: sem token CSRF ou de outra origem" --> recusa
    cmd -- "8 · grava o usuário" --> puredb
    puredb -- "9 · vale no próximo login, sem reiniciar o FTP" --> fim
    painel -. "registra cada ação" .-> auditoria
```

<sub>📐 Nível 2 · Fluxograma · 🔍 aproximar e mover: controles no canto do diagrama · 📁 [fonte](diagramas/)</sub>

| Nº | De ➜ Para | O que acontece |
|---|---|---|
| 1 | 👤 Usuário ➜ 🖥️ Painel web | O navegador abre `https://<endereço>:8443`; só HTTPS, com TLS 1.2 ou mais novo |
| 2 | 🖥️ Painel web ➜ ❓ rede permitida? | O endereço de origem é comparado com `PAINEL_REDES_PERMITIDAS` |
| 3a | ❓ rede permitida? ➜ ❓ senha confere? | ✅ Sim: aparece a tela de entrada |
| 3b | ❓ rede permitida? ➜ ⛔ pedido recusado | ❌ Não: `403`, sem mostrar tela nenhuma |
| 4 | ❓ senha confere? ➜ 🔑 hash da senha | A senha digitada é comparada com o hash `scrypt` de `/run/secrets/painel_password_hash` |
| 5a | ❓ senha confere? ➜ 🔒 sessão | ✅ Sim: abre a sessão, com cookie e token CSRF |
| 5b | ❓ senha confere? ➜ ⛔ pedido recusado | ❌ Não: `401`; cinco erros em 15 minutos bloqueiam o endereço (`429`) |
| 6 | 🔒 sessão ➜ ❓ pedido legítimo? | Cada formulário enviado traz o token CSRF da sessão e a origem do próprio painel |
| 7a | ❓ pedido legítimo? ➜ ⚙️ `allsafe-ftp-user` | ✅ Sim: o painel chama o comando, com a senha pela entrada padrão |
| 7b | ❓ pedido legítimo? ➜ ⛔ pedido recusado | ❌ Não: `403`, sem alterar nada |
| 8 | ⚙️ `allsafe-ftp-user` ➜ 🗄️ PureDB | A conta é gravada em `DATA_DIR/auth`, com trava para uma alteração por vez |
| 9 | 🗄️ PureDB ➜ 🏁 usuário pronto no FTP | O FTP lê o banco a cada login: vale na hora, sem reiniciar |

**🧷 Apoio**

| Quem | Usa | Como |
|---|---|---|
| ❓ senha confere? | 🔑 hash da senha (`painel_password_hash`) | lê a cada entrada, somente leitura |
| 🖥️ Painel web | 📚 `auditoria.log` | registra cada entrada, recusa e alteração |

---

<a name="auditoria"></a>

## 📜 Auditoria

Tudo o que o painel faz fica em `DATA_DIR/painel/auditoria.log` (`0600`, do `root`) e aparece na aba 📜 Atividade.

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

Senha, token e cookie **nunca** são gravados. As transferências dos equipamentos não ficam aqui: estão no log do FTP, em [🧰 Operação](operacao.md#logs).

---

<a name="protecoes"></a>

## 🛡️ O que protege o painel

| Camada | Proteção |
|---|---|
| Rede | Bind só em IP privado; `PAINEL_REDES_PERMITIDAS` só com redes privadas; `deploy.sh` e container recusam o resto |
| Transporte | Só HTTPS, TLS 1.2 ou mais novo; HTTP puro não tem resposta |
| Entrada | Senha de no mínimo 12 caracteres, guardada como hash `scrypt`; cinco erros bloqueiam o endereço por 15 minutos |
| Sessão | Cookie `__Host-sessao` com `Secure`, `HttpOnly` e `SameSite=Strict`, presa ao endereço de origem; encerra com 15 minutos sem uso e, de qualquer forma, em 8 horas |
| Formulários | Token CSRF por sessão e conferência de `Origin`; corpo limitado a 8 KiB |
| Navegador | `Content-Security-Policy` sem script, `X-Frame-Options: DENY`, `nosniff`, HSTS e `no-store`; a página não carrega nada de fora |
| Container | Raiz somente leitura, `cap_drop: ALL`, `no-new-privileges`, sem socket do Docker, limites de CPU, memória e processos |

<details>
<summary>🔬 Detalhe técnico — implementação</summary>

- **Código:** [`painel/servidor.py`](../painel/servidor.py), só com a biblioteca padrão do Python 3.11 do Debian 12; a aparência está em [`painel/estilo.css`](../painel/estilo.css). Não há JavaScript, fonte nem imagem externa.
- **Imagem:** alvo `painel` do [`Dockerfile`](../Dockerfile), sobre a mesma base do FTP (traz o `pure-pw` e o `allsafe-ftp-user`). Imagem `PAINEL_IMAGE`, container `PAINEL_CONTAINER_NAME`.
- **Entrada do container:** [`scripts/painel-entrypoint.sh`](../scripts/painel-entrypoint.sh) recusa senha em variável, confere IP e redes privados, ajusta dono e modo de `/painel`, gera o certificado e executa o servidor.
- **Hash da senha:** `scrypt` com `N=2^15`, `r=8`, `p=1` e sal de 16 bytes, no formato `scrypt$15$8$1$<sal>$<resumo>`. É lido de `/run/secrets/painel_password_hash` a cada entrada e comparado em tempo constante.
- **Sessão:** o token do cookie tem 256 bits aleatórios e o servidor guarda só o resumo SHA-256 dele, em memória. Reiniciar o painel encerra todas as sessões e zera a contagem de erros de entrada.
- **Tela de entrada:** o formulário leva um token assinado (HMAC) com validade curta, para a entrada também não aceitar pedido forjado por outro site.
- **Nome de host:** o cabeçalho `Host` tem de ser um IP privado, `localhost` ou o `PAINEL_CERT_CN`; outro nome recebe `400`.
- **Usuários do FTP:** o painel monta as mesmas pastas `DATA_DIR/auth` e `DATA_DIR/dados` do serviço `ftp` e chama o mesmo `allsafe-ftp-user`, com `flock` em `/auth/.lock`. Por isso não precisa do socket do Docker.
- **Capabilities devolvidas:** `CHOWN`, `DAC_OVERRIDE` e `FOWNER`, para criar a pasta do usuário com o dono `ftpdata` e gravar em `/auth`. Nenhuma de rede.
- **Saúde:** `python3 /opt/painel/servidor.py --saude` abre `https://localhost:8443/saude` validando o certificado; por isso `localhost` está sempre no certificado gerado.
- **Limites:** `PAINEL_MEMORY_LIMIT`, `PAINEL_CPU_LIMIT` e `PAINEL_PIDS_LIMIT`, em [⚙️ Configuração](configuracao.md#painel).

</details>

---

⬅️ [🧰 Operação](operacao.md) · 🏠 [Documentação](README.md) · ➡️ [🚨 Solução de problemas](solucao-de-problemas.md)
