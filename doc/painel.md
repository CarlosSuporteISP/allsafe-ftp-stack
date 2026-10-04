# 🖥️ Painel web — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [Índice da documentação](README.md)

## 💡 Em poucas palavras

O painel é uma página, aberta pelo navegador **de dentro da rede interna**, para criar, trocar a senha e remover os usuários do FTP, escolher a pasta de cada um, criar pastas e baixar os backups recebidos, sem usar a linha de comando. Cada administrador entra com o próprio usuário e a própria senha, só por HTTPS. O dono dos arquivos também entra: cada usuário do FTP usa o nome e a senha do FTP e só navega e baixa na própria pasta. Quem atende o navegador é o nginx, a porta de entrada: ele barra quem está fora da rede interna e só então passa o pedido ao painel. O que é feito no painel vale no FTP na hora, sem reiniciar nada.

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

> 🧱 **Uso só em rede privada, atrás de firewall.** O painel administra as contas que guardam a configuração da sua rede. Por padrão, ele escuta **apenas em IP privado**, recusa cliente de fora das redes internas e não deve ser publicado na internet nem receber redirecionamento de porta da borda. Quem precisa chegar de fora entra por VPN até a rede interna. Veja [rede privada e firewall](seguranca.md#rede-privada); endereço público só com a opção descrita em [IP público](seguranca.md#ip-publico).

---

<details>
<summary>Sumário — clique para expandir</summary>

[Abrir o painel](#abrir) · [O que há em cada aba](#abas) · [Usuários pelo painel](#usuarios) · [Arquivos e download](#arquivos) · [Usuário do FTP no painel](#usuario-ftp) · [Administradores do painel](#administradores) · [Recuperar o acesso](#senha) · [Certificado do painel](#certificado) · [Abrir para a rede interna](#rede-interna) · [Como o painel decide](#como-decide) · [Auditoria](#auditoria) · [O que protege o painel](#protecoes)

</details>

---

<a name="abrir"></a>

## 🚪 Abrir o painel

O `./deploy.sh` sobe o painel junto com o FTP e mostra o endereço no fim:

```text
Painel: https://127.0.0.1:8443  (pelo nginx; certificado autoassinado; rede privada, atrás de firewall)
```

1. Abra o endereço no navegador. Na instalação padrão, só o próprio servidor alcança (`127.0.0.1`).
2. O navegador avisa que o certificado é autoassinado: confira a impressão digital (comando abaixo) antes de aceitar.
3. Digite o usuário e a senha de administrador. Na primeira instalação, o usuário é o de `PAINEL_ADMIN_USER` (`admin`, se você não trocou no `.env`) e a senha está em `.secrets/painel-admin-inicial-senha.txt`:

```bash
cat .secrets/painel-admin-inicial-senha.txt
```

**Resultado esperado:** a tela **Visão geral**, com o FTP `🟢 No ar` e, no topo, o nome do administrador que entrou.

Impressão digital do certificado do painel, para comparar com a que o navegador mostra:

```bash
docker compose exec painel openssl x509 -in /painel/tls/painel-cert.pem -noout -fingerprint -sha256
```

> ⚠️ Troque a senha inicial depois do primeiro acesso: [Administradores do painel](#administradores). Nunca cole a senha em documento, captura de tela ou mensagem.

---

<a name="abas"></a>

## 🗂️ O que há em cada aba

| Aba | O que mostra | O que dá para fazer |
|---|---|---|
| Visão geral | FTP no ar ou fora, quantidade de usuários, espaço usado e livre, último envio, validade do certificado do FTP o modo de TLS do FTP e os dados para configurar o equipamento (servidor, porta de controle, portas passivas, protocolo) | Só consultar |
| Usuários | Um usuário por linha: pasta no host, com a marca **dividida** quando outro usuário também a alcança, espaço usado, quantidade de arquivos e último envio; com `FTP_TLS_EXCECOES=sim`, a coluna **TLS** diz se o usuário é obrigado a usar TLS | Criar, escolhendo a pasta, trocar a senha, remover e abrir a pasta do usuário na aba Arquivos; com `FTP_TLS_EXCECOES=sim`, dispensar um usuário do TLS e voltar a exigir |
| Arquivos | As pastas dos usuários do FTP e o que há em cada uma: nome, tamanho e data de cada arquivo | Entrar nas pastas, baixar um arquivo pelo navegador, criar uma pasta e abrir o cadastro de usuário já com a pasta aberta |
| Administradores | Um administrador por linha, com a marca **você** na conta de quem está usando o painel e quantas sessões cada um tem abertas | Criar, trocar a senha, trocar o nome e remover |
| Segurança | Conferência da instalação: se endereço público é aceito, endereços do FTP e do painel, modo TLS, com a exceção por usuário e quem está dispensado, a entrada dos usuários do FTP, a frente web (nginx), validade e impressão digital dos dois certificados, redes que podem abrir o painel, regras da sessão, isolamento do container e o lembrete do firewall | Só consultar |
| Atividade | Os últimos 300 registros do painel: entradas, recusas, downloads, pastas criadas e alterações de usuário e de administrador, com data, endereço de origem e quem fez, administrador ou usuário do FTP | Só consultar |

No topo ficam o nome do administrador da sessão e o botão **Sair**, que encerra a sessão na hora.

Quem entra com a conta do FTP não vê nenhuma dessas abas: vê uma tela só, **Meus arquivos**, descrita em [Usuário do FTP no painel](#usuario-ftp).

A foto de cada tela, com a explicação item por item, está em [Fotos da aplicação](aplicacao/README.md).

> ⚠️ Com `FTP_TLS_MODE` em `0` ou `1`, as abas Visão geral e Segurança abrem com um alerta no topo: o FTP está aceitando senha e arquivo em texto puro. O alerta só some quando a variável volta para `2` ou `3`. Veja [Segurança](seguranca.md#ftp-sem-tls).

> ⚠️ Com `FTP_TLS_EXCECOES=sim` e pelo menos um usuário dispensado do TLS, as mesmas abas abrem com o alerta de quantos e quais usuários entram no FTP sem TLS. Ele some quando o último volta a ser obrigado a usar TLS. Veja [Segurança](seguranca.md#tls-por-usuario).

---

<a name="usuarios"></a>

## 👥 Usuários pelo painel

| Quero | Onde | O que acontece |
|---|---|---|
| Criar um usuário | Usuários ➜ **Novo usuário** | Cria a conta e a pasta dela: `DATA_DIR/dados/<usuario>` com o campo **Pasta** em branco, ou a pasta escolhida. Com a senha em branco, o painel gera uma senha forte e a mostra **uma única vez** |
| Trocar a senha | Usuários ➜ **Trocar senha** | A senha antiga deixa de valer no próximo login |
| Remover um usuário | Usuários ➜ **Remover** | Pede confirmação. A conta some; **os arquivos da pasta são preservados** |
| Deixar um usuário entrar sem TLS | Usuários ➜ **Dispensar TLS** | Só existe com `FTP_TLS_EXCECOES=sim`. Pede confirmação e vale na entrada seguinte do usuário; os demais continuam obrigados a usar TLS |
| Voltar a exigir o TLS de um usuário | Usuários ➜ **Exigir TLS** | Pede confirmação e vale na entrada seguinte. Troque a senha dele, que passou em texto puro |

**Resultado esperado:** o usuário criado entra por FTPS logo em seguida, sem reiniciar o FTP.

Os formulários, as mensagens de recusa e a tela da senha gerada estão em [Fotos da aplicação](aplicacao/README.md#usuarios).

Regras, as mesmas do [`manage-user.sh`](../manage-user.sh):

- Nome com letras minúsculas, números, `_` e `-`, começando por letra ou `_`, até 32 caracteres.
- Senha com no mínimo 12 caracteres.
- Pasta: em branco, é o nome do usuário. Escolhida, fica sempre dentro de `DATA_DIR/dados`, com até 4 níveis separados por `/` (`clientes/olt-01`); cada nível tem letras, números, `_`, `-` e ponto, não começa com ponto e vai até 64 caracteres. A pasta é criada se não existir, e o campo sugere as que já existem no primeiro nível.
- Pasta que passa por link simbólico, ou por um nome que já é de um arquivo, é recusada.
- A pasta é escolhida na criação e não muda depois. Para trocar, remova o usuário e crie de novo com a pasta nova: os arquivos continuam onde estavam.
- O **usuário inicial** (`FTP_USER`) não é alterado pelo painel: a senha dele vem de `.secrets/ftp-usuario-inicial-senha.txt` e é reaplicada a cada subida do FTP. Veja [Segredos](segredos.md#trocar-a-senha).

> ⚠️ **Pasta dividida:** dois usuários com a mesma pasta, ou com uma dentro da outra, leem, gravam e apagam os arquivos um do outro. O painel aceita, porque serve para uma conta de consulta na pasta de cima, e avisa: a lista marca a pasta com **dividida** e mostra quem mais a alcança, e a tela de remoção repete o aviso. Para um equipamento não alcançar o backup de outro, dê a cada um a própria pasta.

> ⚠️ **Dispensa do TLS:** o usuário dispensado manda senha e arquivo em texto puro. Use só para o equipamento antigo que não fala TLS, em rede interna isolada, com usuário e senha só dele. As condições e o que a stack garante estão em [Segurança](seguranca.md#tls-por-usuario).

<details>
<summary>Detalhe técnico — a dispensa do TLS no painel</summary>

- A coluna **TLS** e os botões **Dispensar TLS** e **Exigir TLS** só existem com `FTP_TLS_EXCECOES=sim`. Com `nao`, a lista dos dispensados fica guardada, não vale, e a tela responde `404`.
- `GET /usuarios/tls?usuario=<nome>` mostra a confirmação; `POST /usuarios/tls` grava, com o token CSRF da sessão e o campo `acao` em `dispensar` ou `exigir`. Usuário que não existe e nome fora da regra respondem `404`; `acao` diferente volta para a confirmação sem alterar nada.
- Quem grava é o `allsafe-ftp-user`, o mesmo script do `manage-user.sh`, na `sem-tls.lista` de `DATA_DIR/auth`. O painel só lê a lista para montar as telas.
- Remover o usuário tira o nome dele da lista: um usuário novo com o mesmo nome não herda a dispensa.
- Cada alteração fica na auditoria, com o administrador e o usuário: `tls_dispensado` e `tls_exigido`.

</details>

A linha de comando continua valendo: painel e `manage-user.sh` alteram as mesmas contas. Veja [Operação](operacao.md#usuarios).

---

<a name="arquivos"></a>

## 📁 Arquivos e download

A aba Arquivos mostra as pastas de `DATA_DIR/dados`, entrega pelo navegador qualquer arquivo que um equipamento enviou e cria pasta. A **pasta vazia** é a única coisa que o painel grava ali: enviar, renomear e apagar continuam sendo feitos por FTP.

1. Abra a aba **Arquivos**. O primeiro nível tem as pastas dos usuários e as criadas pelo painel. Na aba Usuários, o endereço da coluna **Pasta no host** abre direto a pasta daquele usuário.
2. Clique no nome de uma pasta para entrar. O caminho no alto da lista mostra onde você está e volta a qualquer nível.
3. Clique em **Baixar** na linha do arquivo. O navegador salva o arquivo com o nome original.
4. Para criar uma pasta, entre na pasta onde ela vai ficar, escreva o nome em **Nova pasta** e clique em **Criar pasta**.
5. Para prender um usuário a uma pasta, entre nela e clique em **Novo usuário nesta pasta**: o cadastro abre com o campo **Pasta** preenchido.

**Resultado esperado:** o arquivo salvo é idêntico ao que o equipamento enviou, e a aba Atividade ganha a linha `Arquivo baixado`, com o administrador, o caminho e o tamanho. A pasta criada aparece na lista com o aviso `Pasta criada.`, vazia, já com o dono e a permissão que o FTP usa, e fica na aba Atividade como `Pasta criada`.

| Na lista | O que aparece | O que dá para fazer |
|---|---|---|
| Pasta | Nome e data da última alteração; dentro dela, a linha `Pasta do usuário do FTP` diz de quem é | Entrar |
| Arquivo | Nome, tamanho e data da última alteração | Baixar |
| Item marcado `link simbólico` ou `arquivo especial` | Nome e data | Nada: o painel não abre |

Limites:

- O nome da pasta nova tem letras, números, `_`, `-` e ponto, não começa com ponto e vai até 64 caracteres. Uma pasta por vez: para criar `clientes/olt-01`, crie `clientes`, entre nela e crie `olt-01`.
- Até **8 downloads ao mesmo tempo**, somando administradores e usuários do FTP. O nono recebe a tela `Muitos downloads ao mesmo tempo` (`503`): espere um terminar e repita.
- A lista mostra até **2000 itens** por pasta, com um aviso quando há mais. Pasta maior que isso é consultada por FTP.
- O download **não é retomado**: se a conexão cair, começa de novo.
- Conexão que recebe menos de cerca de 4 KiB por segundo é cortada, e o download aparece na aba Atividade como `Download interrompido`.

<details>
<summary>Detalhe técnico — como o painel abre, entrega o arquivo e cria a pasta</summary>

- **Rotas:** `GET /arquivos?pasta=<caminho>` lista e `GET /arquivos/baixar?arquivo=<caminho>` entrega. `POST /arquivos/pasta` cria uma pasta, com os campos `pasta` (onde) e `nome` e o token CSRF. As três exigem sessão; sem ela, o pedido vai para a tela de entrada. Não existe rota de envio, de troca de nome nem de remoção.
- **Caminho:** sempre relativo a `DATA_DIR/dados` (`/data` no container). Caminho com parte `..`, `.` ou vazia, com byte nulo, com parte de mais de 255 bytes ou com mais de 4096 caracteres recebe `400` e o evento `recusa_caminho`.
- **Abertura:** o painel abre a pasta dos dados e depois cada parte do caminho em relação à anterior, só para leitura e sem seguir link simbólico (`O_RDONLY`, `O_NOFOLLOW`). O que foi conferido é o mesmo que fica aberto: trocar uma pasta por um link no meio do pedido não muda o que é lido. Link simbólico em qualquer nível, mesmo apontando para dentro da própria pasta, recebe `403` e o evento `recusa_caminho`.
- **Pasta nova:** a pasta de destino é aberta do mesmo jeito que na listagem, e a nova é criada em relação a ela (`mkdir` pelo descritor da pasta aberta), com dono `ftpdata` e modo `0750`, os mesmos das pastas criadas pelo FTP. Nome fora da regra, com `/`, `..` ou byte nulo, recebe `400` e o evento `recusa_caminho`; destino que passa por link simbólico, `403`; destino que não existe, `404`; nome já usado por pasta, arquivo ou link, `409`. O painel não cria nada além da pasta vazia.
- **Só arquivo comum:** FIFO, soquete e dispositivo aparecem na lista como `arquivo especial`, sem botão, e o pedido direto recebe `404`.
- **Entrega:** `Content-Type: application/octet-stream` e `Content-Disposition: attachment`, com o nome em duas formas (RFC 6266 e RFC 8187): reduzido a ASCII e inteiro, em UTF-8. Com o `nosniff` e a `Content-Security-Policy` de toda resposta, o navegador salva o arquivo e nunca o abre, mesmo que seja uma página HTML.
- **Memória e disco:** o arquivo sai em blocos de 64 KiB, sem ser carregado na memória. O nginx repassa no ritmo do navegador, sem gravar arquivo temporário (`proxy_max_temp_file_size 0`), então o tamanho do arquivo não é limitado pelo `/tmp` do container.
- **Sem retomada:** a resposta leva `Accept-Ranges: none` e o painel ignora o cabeçalho `Range`.
- **Ritmo mínimo:** cada bloco tem 15 segundos para sair; passado isso, o painel fecha a conexão e libera a vaga do download.
- **Nome fora do UTF-8:** aparece na lista com o sinal de substituição no lugar do byte inválido, e é baixado do mesmo jeito.
- **Auditoria:** `pasta_criada` registra o administrador e o caminho; `arquivo_baixado` e `arquivo_interrompido` registram quem baixou, o caminho e os bytes entregues; o conteúdo do arquivo nunca é registrado.

</details>

---

<a name="usuario-ftp"></a>

## 📥 Usuário do FTP no painel

O dono dos arquivos pega os próprios backups pelo navegador, sem depender de quem administra: entra no mesmo endereço do painel, com **o nome e a senha do FTP**, e vê uma tela só, **Meus arquivos**, com a pasta dele. Não há conta nova para criar nem senha nova para guardar.

1. Abra o endereço do painel, de uma rede que esteja em `PAINEL_REDES_PERMITIDAS`.
2. Digite o usuário e a senha do FTP, os mesmos que o equipamento usa. A entrada leva alguns segundos: quem confere a senha é o próprio servidor FTP.
3. Na tela **Meus arquivos**, clique no nome de uma pasta para entrar; o caminho no alto da lista volta a qualquer nível, a partir de **Início**.
4. Clique em **Baixar** na linha do arquivo. O navegador salva o arquivo com o nome original.
5. Clique em **Sair** ao terminar.

**Resultado esperado:** o arquivo salvo é idêntico ao que o equipamento enviou, e a aba Atividade, que só o administrador vê, ganha as linhas `Entrada aceita` e `Arquivo baixado`, com o nome do usuário do FTP, o caminho e o tamanho.

| O usuário do FTP | No painel |
|---|---|
| Vê | Só a pasta do cadastro dele e o que há dentro dela: nome, tamanho e data. O caminho da pasta no servidor não aparece |
| Faz | Navega e baixa. Enviar, renomear e apagar continuam sendo feitos por FTP |
| Não alcança | Nenhuma aba de administração: Usuários, Arquivos de todos, Administradores, Segurança e Atividade respondem `404` para ele |
| Divide com outro usuário | Só o que já divide no FTP: quem tem a mesma pasta, ou uma pasta dentro da outra, vê pelo painel os mesmos arquivos que vê por FTP |

Regras:

- Entra todo usuário do cadastro do FTP, inclusive o usuário inicial (`FTP_USER`), com a senha que vale no FTP naquele momento.
- A sessão acompanha o cadastro: trocar a senha do usuário, removê-lo ou recriá-lo com outra pasta, pelo painel ou pelo `manage-user.sh`, encerra as sessões dele no pedido seguinte.
- Nome igual ao de um administrador entra **só** como administrador, com a senha de administrador. Se um administrador é criado com o nome de um usuário do FTP, a sessão desse usuário é encerrada e ele deixa de entrar no painel; por FTP, nada muda.
- Até **3 sessões** por usuário do FTP: a quarta entrada encerra a mais antiga. Até **2 downloads ao mesmo tempo** por usuário; o terceiro recebe a tela `Muitos downloads ao mesmo tempo` (`503`).
- Cinco erros de usuário ou senha em 15 minutos bloqueiam o endereço, do mesmo jeito que na entrada do administrador.
- Com o servidor FTP parado, quem já entrou continua navegando e baixando, e ninguém novo entra com conta do FTP; o administrador entra normalmente.

Para o painel aceitar **só administradores**, troque a variável no `.env` e rode o `deploy.sh`:

```bash
PAINEL_ACESSO_USUARIOS_FTP=nao
```

**Resultado esperado:** a tela de entrada volta ao texto `Painel de administração da stack.`, a conta do FTP recebe `Não foi possível entrar.` e a aba Segurança mostra a entrada dos usuários do FTP como desligada. O FTP continua aceitando os mesmos usuários.

> ⚠️ Com `FTP_TLS_MODE=0` o servidor FTP não tem TLS, e a conferência da senha vai em texto puro do painel até ele. Esse trecho não sai da rede interna da stack, dentro do próprio servidor, e a aba Segurança mostra o aviso. Do navegador até o painel continua sendo HTTPS.

<details>
<summary>Detalhe técnico — como a conta do FTP entra e o que ela alcança</summary>

- **Ordem da entrada:** primeiro a conta de administrador, pelo hash `scrypt`. Se não for administrador com aquela senha, e a entrada dos usuários estiver ligada, o painel confere no servidor FTP. A conferência é feita para todo nome válido, exista ou não e seja ou não de administrador; o resultado só é aproveitado quando o nome não é de administrador.
- **Quem confere a senha:** o `pure-ftpd`. O painel abre uma conexão em `ftp:2121`, na rede do Compose, faz o login e sai; não lê o hash do cadastro nem refaz a conta dele. Nos modos de TLS `1`, `2` e `3`, a conexão é TLS 1.2 ou superior e o certificado recebido é comparado, byte a byte, com a parte pública que o serviço `ftp` grava em `/auth/ftp-cert.pem`; se for outro, a senha não é enviada e a entrada é recusada.
- **Tempo da entrada:** o hash do cadastro é `argon2id`, e o servidor FTP leva cerca de 3 segundos para aceitar uma senha e de 3 a 6 segundos a mais, sorteados, para recusar. O painel repassa esse tempo. Por isso o nome que existe demora mais para ser recusado que o nome que não existe, a mesma diferença que se mede direto na porta do FTP; a tela e o código da resposta são os mesmos nos dois casos.
- **Limites da conferência:** duas conferências por vez, com até 5 segundos de espera pela vez e 15 segundos por etapa da conversa. Sem resposta nesse prazo, servidor fora do ar, lotado ou com outro certificado, a entrada é recusada com `401`, conta como erro e fica na auditoria como `entrada_falha conferencia=ftp_indisponivel`.
- **Sessão:** guarda o nome, a pasta do cadastro e o resumo SHA-256 da linha inteira do usuário em `/auth/pureftpd.passwd`, lidos antes e depois da conferência, que têm de ser iguais. A cada pedido, o painel relê a linha: se mudou, se sumiu, se o nome virou de administrador ou se a entrada foi desligada, a sessão é encerrada, o cookie é apagado e o evento `sessao_encerrada` registra o usuário e o motivo (`cadastro_alterado`, `nome_de_administrador` ou `acesso_desligado`).
- **Rotas:** a sessão do usuário do FTP tem tabela própria: `GET /` (leva a `/meus-arquivos`), `GET /meus-arquivos?pasta=<caminho>`, `GET /meus-arquivos/baixar?arquivo=<caminho>` e `POST /sair`. Qualquer outra rota responde `404`; quando é uma rota de administração, fica o evento `recusa_papel`, com o usuário e o caminho. Para o administrador, `/meus-arquivos` não existe.
- **Caminho:** sempre relativo à pasta do cadastro, que é a raiz dele. Passa pelas mesmas conferências da [aba Arquivos](#arquivos): parte por parte, sem `..`, sem seguir link simbólico, só arquivo comum, entrega como anexo, em blocos e sem retomada. Na auditoria, o caminho vai inteiro, a partir da pasta dos dados.
- **Pasta ainda não criada:** a pasta de um usuário novo nasce no primeiro login por FTP; antes disso, a tela mostra a lista vazia.
- **Sessões cheias:** quando o painel chega ao teto de 50 sessões, sai primeiro a sessão menos usada de usuário do FTP; a entrada de um usuário não derruba a de um administrador.

</details>

---

<a name="administradores"></a>

## 🛡️ Administradores do painel

Cada pessoa que administra o painel tem o **próprio usuário e a própria senha**. Todos têm o mesmo acesso, e o que cada um faz fica na aba Atividade com o nome de quem fez. O primeiro administrador nasce na instalação, com o nome de `PAINEL_ADMIN_USER`; os outros são criados aqui.

| Quero | Onde | O que acontece |
|---|---|---|
| Criar um administrador | Administradores ➜ **Novo administrador** | Cria a conta. Com a senha em branco, o painel gera uma senha forte e a mostra **uma única vez** |
| Trocar a senha, a minha ou a de outro | Administradores ➜ **Trocar senha** | A senha antiga deixa de valer na hora e as outras sessões desse administrador são encerradas |
| Trocar o nome, o meu ou o de outro | Administradores ➜ **Trocar nome** | A entrada passa a ser pelo nome novo; a senha continua a mesma |
| Remover um administrador | Administradores ➜ **Remover** | A conta some e as sessões dela são encerradas |

**Resultado esperado:** a lista volta com o aviso da alteração (`Administrador criado.`, `Senha trocada.`, `Nome trocado.` ou `Administrador removido.`) e o administrador novo entra logo em seguida, sem reiniciar nada.

Regras:

- **Toda alteração pede a sua senha atual**, a de quem está usando o painel, no campo **Sua senha atual**. Um navegador esquecido aberto não basta para criar um administrador nem para trocar a senha de outro.
- Nome com letras minúsculas, números, `_` e `-`, começando por letra ou `_`, até 32 caracteres. Senha com no mínimo 12 caracteres.
- **Ninguém remove a própria conta:** o botão Remover só aparece nas contas dos outros. Assim sempre sobra um administrador.
- Até 20 administradores.
- Trocar o nome do primeiro administrador pelo painel não mexe no `.env`: o `PAINEL_ADMIN_USER` só é usado enquanto não existe nenhum administrador.

<details>
<summary>Detalhe técnico — onde os administradores ficam</summary>

- **Arquivo:** `DATA_DIR/painel/administradores` (`/painel/administradores` no container), `0600`, do `root`, uma linha `nome:hash` por administrador. Só o hash `scrypt` é gravado; a senha em texto não fica em lugar nenhum.
- **Primeira subida:** sem nenhum administrador no arquivo, o painel cria o de `PAINEL_ADMIN_USER` com o hash do segredo `painel_admin_inicial_senha_hash` e registra `admin_inicial_criado`. Depois disso, quem manda é o arquivo.
- **Instalação anterior à `0.12.0`:** na primeira subida depois da atualização, o painel cria o administrador `admin` (ou o nome de `PAINEL_ADMIN_USER`) com a mesma senha que já valia.
- **Gravação:** o painel escreve um arquivo ao lado e troca de uma vez, uma alteração por vez: uma queda no meio não deixa o painel sem administrador.
- **Senha atual recusada:** responde `403`, registra `admin_senha_atual_recusada` e conta no mesmo limite da tela de entrada: cinco recusas em 15 minutos bloqueiam o endereço (`429`).
- **Sessões:** a troca de senha, a troca de nome e a remoção encerram as sessões do administrador alterado. Quando a alteração é na própria conta, a sessão em uso continua e as outras caem.
- **Cópia de segurança:** o arquivo entra na cópia do `scripts/backup.sh`, junto com o resto de `painel/`, e volta na restauração: veja [Backup e restauração](backup.md#restaurar).

</details>

---

<a name="senha"></a>

## 🔑 Recuperar o acesso

Perdeu a senha e não há outro administrador para trocá-la pelo painel? Quem tem acesso ao servidor define uma nova, pelo host. Não existe recuperação pelo navegador.

| Quero | Comando |
|---|---|
| Senha nova para o primeiro administrador (`PAINEL_ADMIN_USER`) | `./scripts/painel-senha.sh --gerar` (mostra uma única vez) |
| Escolher a senha, em vez de gerar | `./scripts/painel-senha.sh` (pergunta duas vezes) |
| Senha nova para outro administrador | `./scripts/painel-senha.sh --usuario NOME --gerar` |
| Criar um administrador pelo host | o mesmo comando, com um `NOME` que ainda não existe |

**Resultado esperado:**

```text
Administrador admin com a senha trocada; painel reiniciado e sessões abertas encerradas.
```

Depois disso, a senha antiga é recusada e quem estava dentro do painel volta para a tela de entrada. Quando o administrador é o de `PAINEL_ADMIN_USER`, o arquivo `.secrets/painel-admin-inicial-senha.txt` (a senha inicial em texto) é apagado. Detalhe em [Scripts](scripts.md#painel-senha) e [Segredos](segredos.md#senha-do-painel).

> ⚠️ O script reinicia o painel, e o nginx junto: o painel fica alguns segundos fora do ar e todos os administradores entram de novo.

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
| `PAINEL_BIND_IP` | o IP **privado** do servidor na rede de gerência (`0.0.0.0` é sempre recusado; IP público, só com a [opção própria](seguranca.md#ip-publico)) |
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

Cada pedido passa por três conferências antes de mudar alguma coisa: a rede de origem (nginx), o usuário e a senha, e o token do formulário (painel). O download de um arquivo passa pelas duas primeiras e pela conferência do caminho pedido. A senha do administrador é conferida pelo painel; a do usuário do FTP, pelo servidor FTP.

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
        senha@{ shape: diam, label: "usuário e senha<br>conferem?" }
        hash@{ shape: doc, label: "administradores<br>DATA_DIR/painel, nome e hash da senha" }
        ftp@{ shape: rect, label: "Pure-FTPd<br>allsafe-ftp, rede interna da stack" }
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
    subgraph ARQUIVOS["Arquivos"]
        caminho@{ shape: diam, label: "caminho dentro<br>da pasta dos dados?" }
        dados@{ shape: lin-cyl, label: "DATA_DIR/dados<br>pastas dos usuários" }
    end
    subgraph RESULTADO["Resultado"]
        fim@{ shape: stadium, label: "usuário pronto no FTP" }
        baixado@{ shape: stadium, label: "arquivo baixado" }
        criada@{ shape: stadium, label: "pasta criada" }
        recusa@{ shape: stadium, label: "pedido recusado" }
    end

    usuario -- "1 · abre https, TCP 8443" --> nginx
    nginx -- "2 · confere a origem e a taxa de pedidos" --> rede
    rede -- "3a · sim: repassa pelo soquete Unix" --> painel
    rede -- "3b · não: 403 ou 429" --> recusa
    painel -- "4 · pede usuário e senha" --> senha
    senha -. "5a · compara com o hash do administrador" .-> hash
    senha -. "5b · não é administrador: o servidor FTP confere a senha" .-> ftp
    senha -- "6a · sim: abre a sessão do administrador ou do usuário do FTP" --> sessao
    senha -- "6b · não: 5 erros bloqueiam o endereço" --> recusa
    sessao -- "7 · administrador envia o formulário" --> pedido
    pedido -- "8a · sim: executa" --> cmd
    pedido -- "8b · não: sem token CSRF ou de outra origem" --> recusa
    cmd -- "9 · grava o usuário" --> puredb
    puredb -- "10 · vale no próximo login, sem reiniciar o FTP" --> fim
    sessao -- "11 · em Arquivos ou em Meus arquivos, pede um arquivo ou cria uma pasta" --> caminho
    caminho -. "12 · abre parte por parte, sem seguir link simbólico" .-> dados
    caminho -- "13a · sim, arquivo: entrega como anexo" --> baixado
    caminho -- "13b · sim, pasta nova: cria vazia" --> criada
    caminho -- "13c · não: 400, 403, 404 ou 409" --> recusa
    cmd -. "cria a pasta do usuário, se faltar" .-> dados
    painel -. "registra cada ação" .-> auditoria
```

<sub>Nível 2 · Fluxograma · [fonte](diagramas/)</sub>

| Nº | De ➜ Para | O que acontece |
|---|---|---|
| 1 | Usuário ➜ nginx | O navegador abre `https://<endereço>:8443`; só HTTPS, com TLS 1.2 ou 1.3 |
| 2 | nginx ➜ rede permitida e dentro do limite? | O endereço de origem é comparado com `PAINEL_REDES_PERMITIDAS`, e o pedido, com os limites de taxa, de conexões e de tamanho |
| 3a | rede permitida e dentro do limite? ➜ Painel web | Sim: o nginx repassa o pedido pelo soquete Unix, com o endereço do cliente |
| 3b | rede permitida e dentro do limite? ➜ pedido recusado | Não: `403` para rede de fora, `429` para pedidos demais; o painel nem recebe o pedido |
| 4 | Painel web ➜ usuário e senha conferem? | O painel confere de novo a rede e o nome de host e mostra a tela de entrada, que pede usuário e senha |
| 5a | usuário e senha conferem? ➜ administradores | A senha digitada é comparada com o hash `scrypt` do administrador, em `DATA_DIR/painel/administradores`; nome que não existe passa pela mesma conta |
| 5b | usuário e senha conferem? ➜ Pure-FTPd | Não é administrador com essa senha e a entrada dos usuários do FTP está ligada: o painel entra no servidor FTP com o nome e a senha, pela rede interna da stack, e sai em seguida; quem diz se a senha vale é o servidor |
| 6a | usuário e senha conferem? ➜ sessão | Sim: abre a sessão, com cookie e token CSRF. A do administrador alcança todas as abas; a do usuário do FTP, só a tela Meus arquivos |
| 6b | usuário e senha conferem? ➜ pedido recusado | Não: `401`, sem dizer qual dos dois errou; cinco erros em 15 minutos bloqueiam o endereço (`429`) |
| 7 | sessão ➜ pedido legítimo? | Cada formulário enviado pelo administrador traz o token CSRF da sessão e a origem do próprio painel; na sessão do usuário do FTP, o único formulário é o de sair |
| 8a | pedido legítimo? ➜ `allsafe-ftp-user` | Sim: o painel chama o comando, com a senha pela entrada padrão |
| 8b | pedido legítimo? ➜ pedido recusado | Não: `403`, sem alterar nada |
| 9 | `allsafe-ftp-user` ➜ PureDB | A conta é gravada em `DATA_DIR/auth`, com trava para uma alteração por vez; a dispensa do TLS de um usuário fica na `sem-tls.lista`, na mesma pasta |
| 10 | PureDB ➜ usuário pronto no FTP | O FTP lê o banco a cada login: vale na hora, sem reiniciar |
| 11 | sessão ➜ caminho dentro da pasta dos dados? | Na aba Arquivos, o administrador abre uma pasta, pede um arquivo ou cria uma pasta; na tela Meus arquivos, o usuário do FTP abre uma pasta ou pede um arquivo. O caminho pedido é conferido parte por parte |
| 12 | caminho dentro da pasta dos dados? ➜ `DATA_DIR/dados` | O painel abre cada parte sem seguir link simbólico: a partir da pasta dos dados, para o administrador, e a partir da pasta do cadastro, para o usuário do FTP |
| 13a | caminho dentro da pasta dos dados? ➜ arquivo baixado | Sim, arquivo: sai como anexo, em blocos, e o download fica na auditoria |
| 13b | caminho dentro da pasta dos dados? ➜ pasta criada | Sim, pasta nova: nasce vazia, do usuário `ftpdata`, e fica na auditoria |
| 13c | caminho dentro da pasta dos dados? ➜ pedido recusado | Não: `400` para caminho ou nome que tenta sair da pasta, `403` para link simbólico, `404` para o que não existe, `409` para nome já usado |

**Apoio**

| Quem | Usa | Como |
|---|---|---|
| usuário e senha conferem? | administradores (`DATA_DIR/painel/administradores`) | lê a cada entrada |
| usuário e senha conferem? | Pure-FTPd (`allsafe-ftp`, rede interna da stack) | entra com o nome e a senha do usuário do FTP e sai em seguida, em TLS com o certificado conferido |
| caminho dentro da pasta dos dados? | `DATA_DIR/dados` | lê a pasta e o arquivo pedidos; grava só a pasta nova, vazia |
| `allsafe-ftp-user` | `DATA_DIR/dados` | cria a pasta do usuário novo, se ela ainda não existe |
| Painel web | `auditoria.log` | registra cada entrada, recusa e alteração |

</details>

---

<a name="auditoria"></a>

## 📜 Auditoria

Tudo o que o painel faz fica em `DATA_DIR/painel/auditoria.log` (`0600`, do `root`) e aparece na aba Atividade.

```text
2026-10-04T08:33:49-0300 ip=172.29.1.1 evento=usuario_criado admin=admin usuario=equip01 credencial=informada pasta=equip01
2026-10-04T08:33:47-0300 ip=172.29.1.1 evento=entrada_ok admin=admin
2026-10-04T08:33:46-0300 ip=172.29.1.1 evento=entrada_falha
```

| Evento | Quando acontece |
|---|---|
| `painel_iniciado` | O painel subiu |
| `entrada_ok` · `entrada_falha` · `entrada_bloqueada` | Entrada aceita, com o administrador (`admin=`) ou o usuário do FTP (`usuario=`) · usuário ou senha errados, sem o nome digitado, e com `conferencia=ftp_indisponivel` quando o servidor FTP não pôde conferir a senha · endereço bloqueado por excesso de erros |
| `saida` | Alguém clicou em **Sair**, administrador ou usuário do FTP |
| `sessao_encerrada` | A sessão de um usuário do FTP acabou antes da hora, com o usuário e o motivo: `cadastro_alterado` (senha ou pasta trocada, usuário removido), `nome_de_administrador` ou `acesso_desligado` |
| `recusa_papel` | Um usuário do FTP pediu uma tela ou um formulário de administração, com o usuário e o caminho pedido |
| `usuario_criado` · `senha_trocada` · `usuario_removido` | Alteração de usuário do FTP, com o administrador que fez; a criação leva também a pasta do usuário |
| `tls_dispensado` · `tls_exigido` | Um administrador dispensou um usuário do TLS · voltou a exigir; com o administrador e o usuário |
| `pasta_criada` | Pasta criada pela aba Arquivos, com o administrador e o caminho |
| `arquivo_baixado` · `arquivo_interrompido` | Download pela aba Arquivos ou pela tela Meus arquivos, completo · cortado antes do fim; com quem baixou, o caminho e os bytes entregues |
| `admin_inicial_criado` | Primeira subida: o painel criou o administrador de `PAINEL_ADMIN_USER` |
| `admin_criado` · `admin_senha_trocada` · `admin_renomeado` · `admin_removido` | Alteração de administrador pelo painel, com quem fez e quem foi alterado |
| `admin_senha_atual_recusada` | Alteração de administrador recusada: a senha atual de quem pediu não conferiu |
| `admin_definido_no_host` | O `scripts/painel-senha.sh` criou um administrador ou trocou a senha dele |
| `falha_comando` | O `allsafe-ftp-user` devolveu erro |
| `recusa_csrf` · `recusa_origem` · `recusa_host` · `recusa_rede` | Pedido recusado: sem token, de outra origem, com nome de host inválido ou de rede não permitida |
| `recusa_caminho` | Abas Arquivos e Usuários e tela Meus arquivos: caminho ou nome de pasta que tenta sair da pasta dos dados ou que passa por link simbólico |

Quem está fora das redes permitidas é barrado antes, pelo nginx: essa recusa fica no log dele (`docker compose logs nginx`), não aqui. O `recusa_rede` só aparece se um pedido assim chegar ao painel.

Senha, token e cookie **nunca** são gravados. O nome digitado em uma entrada recusada também não: é comum a senha cair nesse campo por engano. O conteúdo dos arquivos baixados também não. As transferências dos equipamentos não ficam aqui: estão no log do FTP, em [Operação](operacao.md#logs).

---

<a name="protecoes"></a>

## 🛡️ O que protege o painel

| Camada | Proteção |
|---|---|
| Frente web | O nginx é a única porta publicada do painel; o painel atende só por soquete Unix e não escuta em porta de rede |
| Rede | Por padrão, bind só em IP privado e `PAINEL_REDES_PERMITIDAS` só com redes privadas, aplicada pelo nginx e conferida de novo pelo painel; `deploy.sh` e os dois containers recusam o resto. Com `REDE_PERMITIR_IP_PUBLICO=sim`, o painel mostra o alerta na entrada, no rodapé e na aba Segurança |
| Transporte | Só HTTPS, TLS 1.2 ou 1.3; HTTP puro recebe `400` |
| Volume de pedidos | No nginx, por endereço: 20 pedidos por segundo (rajada de 40), 16 conexões e 16 KiB por pedido; o que passa disso recebe `429` ou `413` |
| Entrada | Usuário e senha por administrador; senha de no mínimo 12 caracteres, guardada só como hash `scrypt`; a recusa não diz se o erro foi no usuário ou na senha; cinco erros bloqueiam o endereço por 15 minutos |
| Usuário do FTP | Entra com o nome e a senha do FTP, conferidos pelo próprio servidor FTP, e alcança só a tela Meus arquivos, na pasta do cadastro, para navegar e baixar; as telas de administração respondem `404`; a sessão acaba quando o cadastro dele muda; `PAINEL_ACESSO_USUARIOS_FTP=nao` desliga esta entrada |
| Administradores | Toda alteração de administrador pede a senha atual de quem está alterando; o administrador alterado tem as sessões encerradas; ninguém remove a própria conta |
| Sessão | Cookie `__Host-sessao` com `Secure`, `HttpOnly` e `SameSite=Strict`, presa ao endereço de origem; encerra com 15 minutos sem uso e, de qualquer forma, em 8 horas |
| Arquivos | A aba Arquivos lê e cria pasta vazia, e só dentro de `DATA_DIR/dados`: caminho que tenta sair da pasta é recusado, link simbólico não é seguido, o arquivo sai sempre como anexo e no máximo 8 downloads correm ao mesmo tempo, 2 por usuário do FTP; o painel não envia, não renomeia e não apaga |
| Pastas dos usuários | Cada usuário do FTP fica preso (`chroot`) na pasta do cadastro; a pasta escolhida não sai de `DATA_DIR/dados` nem passa por link simbólico; pasta alcançada por mais de um usuário aparece marcada como **dividida** |
| Formulários | Token CSRF por sessão e conferência de `Origin`: o envio tem de partir do próprio painel; corpo limitado a 8 KiB |
| Navegador | `Content-Security-Policy` sem script, `X-Frame-Options: DENY`, `nosniff`, `Referrer-Policy: same-origin`, HSTS e `no-store`; a página não carrega nada de fora |
| Containers | Raiz somente leitura, `cap_drop: ALL`, `no-new-privileges`, sem socket do Docker, limites de CPU, memória e processos; o nginx roda sem root e sem nenhuma capability |

<details>
<summary>Detalhe técnico — implementação</summary>

- **Código:** os módulos de [`painel/`](../painel/), só com a biblioteca padrão do Python 3.13 do Debian 13, listados [logo abaixo](#modulos); a aparência está em [`web/estilo.css`](../web/estilo.css), que o nginx entrega direto, sem passar pelo painel. Não há JavaScript, fonte nem imagem externa.
- **Imagem:** alvo `painel` do [`Dockerfile`](../Dockerfile), sobre a mesma base do FTP (traz o `pure-pw` e o `allsafe-ftp-user`). Imagem `PAINEL_IMAGE`, container `PAINEL_CONTAINER_NAME`.
- **Entrada do container:** [`painel/entrypoint.sh`](../painel/entrypoint.sh) recusa senha em variável, confere o `PAINEL_ADMIN_USER`, o IP e as redes privados, ajusta dono e modo de `/painel` e do arquivo de administradores, gera o certificado, copia-o para a pasta do nginx e executa o servidor.
- **Frente web:** alvo `nginx` do [`Dockerfile`](../Dockerfile), nginx 1.26 do Debian 13, configurado por [`nginx/nginx.conf.modelo`](../nginx/nginx.conf.modelo). O painel escuta no soquete `/nginx/painel.sock` (`0660`, grupo `10001`) e só aceita pedido com exatamente um `X-Real-IP` válido; sem ele, responde `400`. Detalhe em [Segurança](seguranca.md#painel).
- **Hash da senha:** `scrypt` com `N=2^15`, `r=8`, `p=1` e sal de 16 bytes, no formato `scrypt$15$8$1$<sal>$<resumo>`. Cada administrador tem o seu, em `/painel/administradores`; o arquivo é lido a cada entrada e a comparação é em tempo constante. Usuário que não existe passa pela mesma conta e recebe a mesma resposta. O segredo `/run/secrets/painel_admin_inicial_senha_hash` só é usado na subida em que ainda não existe nenhum administrador.
- **Sessão:** o token do cookie tem 256 bits aleatórios e o servidor guarda só o resumo SHA-256 dele, em memória, com o nome do administrador ou do usuário do FTP que entrou. Reiniciar o painel encerra todas as sessões e zera a contagem de erros de entrada.
- **Tela de entrada:** o formulário leva um token assinado (HMAC) com validade curta, para a entrada também não aceitar pedido forjado por outro site.
- **Origem do envio:** todo `POST` tem de trazer `Origin` igual ao endereço do painel (`https://` mais o `Host`). A política `Referrer-Policy: same-origin` faz o navegador mandar a origem real no envio que parte do próprio painel e `Origin: null` no que parte de outro endereço; `null` e origem de fora recebem `403` e o evento `recusa_origem`.
- **Nome de host:** o cabeçalho `Host` tem de ser um IP privado, `localhost` ou o `PAINEL_CERT_CN`; outro nome recebe `400`. Com `REDE_PERMITIR_IP_PUBLICO=sim`, qualquer endereço IPv4 é aceito no lugar do nome.
- **Usuários do FTP:** o painel monta as mesmas pastas `DATA_DIR/auth` e `DATA_DIR/dados` do serviço `ftp` e chama o mesmo `allsafe-ftp-user`, com `flock` em `/auth/.lock`. Por isso não precisa do socket do Docker.
- **Arquivos:** a aba Arquivos lê a mesma pasta `DATA_DIR/dados`, sempre com abertura só para leitura; a única gravação é a pasta vazia de `POST /arquivos/pasta`. Detalhe em [Arquivos e download](#arquivos).
- **Usuário do FTP no painel:** a senha é conferida por um login no serviço `ftp`, pela rede do Compose, e a sessão dele só tem as rotas de `/meus-arquivos` e a saída. Detalhe em [Usuário do FTP no painel](#usuario-ftp).
- **Capabilities devolvidas:** `CHOWN`, `DAC_OVERRIDE` e `FOWNER`, para criar as pastas com o dono `ftpdata` e gravar em `/auth`. Nenhuma de rede.
- **Saúde:** `python3 /opt/painel/servidor.py --saude` pede `/saude` pelo soquete Unix. O healthcheck do nginx faz o mesmo pedido por TLS, em `127.0.0.1:8443`, e confere o caminho inteiro.
- **Limites:** `PAINEL_MEMORY_LIMIT`, `PAINEL_CPU_LIMIT` e `PAINEL_PIDS_LIMIT`, em [Configuração](configuracao.md#painel).

</details>

<a name="modulos"></a>

<details>
<summary>Detalhe técnico — módulos do código</summary>

O código fica em [`painel/`](../painel/), um assunto por arquivo, e vai inteiro para `/opt/painel` na imagem. O ponto de entrada é o `servidor.py`; os outros são importados por ele.

| Módulo | O que tem |
|---|---|
| [`servidor.py`](../painel/servidor.py) | Ponto de entrada: sobe o servidor, cria o primeiro administrador e atende os modos `--hash`, `--saude` e `--administrador` |
| [`config.py`](../painel/config.py) | Caminhos, limites e a leitura das variáveis do container, com as recusas de rede e de sessão |
| [`senha.py`](../painel/senha.py) | Hash `scrypt` das senhas dos administradores e a conferência em tempo constante |
| [`administradores.py`](../painel/administradores.py) | Leitura e gravação do arquivo de administradores, uma alteração por vez |
| [`sessao.py`](../painel/sessao.py) | Sessões em memória, de administrador e de usuário do FTP, limite de tentativas e token do formulário de entrada |
| [`auditoria.py`](../painel/auditoria.py) | Gravação e leitura do `auditoria.log` |
| [`estado.py`](../painel/estado.py) | Leitura do estado da stack (usuários, uso das pastas, FTP no ar, certificados, quem entra sem TLS) e a chamada do `allsafe-ftp-user` |
| [`pagina.py`](../painel/pagina.py) | Moldura das telas e os textos que mais de uma aba usa |
| [`atendimento.py`](../painel/atendimento.py) | Soquete Unix, cabeçalhos de segurança, conferências de todo pedido (endereço do cliente, rede, `Host`, origem, sessão e CSRF), roteamento por papel (administrador ou usuário do FTP) e a entrega de arquivo em blocos |
| [`rotas.py`](../painel/rotas.py) | Tabelas de método e caminho para a função que responde: uma para o administrador e outra para o usuário do FTP |
| [`entrada.py`](../painel/entrada.py) | Tela de entrada, entrada com usuário e senha, do administrador e do usuário do FTP, e saída |
| [`conta_ftp.py`](../painel/conta_ftp.py) | Conta do usuário do FTP no painel: leitura do cadastro dele, conferência da senha no servidor FTP e os motivos que encerram a sessão |
| [`aba_visao_geral.py`](../painel/aba_visao_geral.py) | Aba Visão geral |
| [`aba_usuarios.py`](../painel/aba_usuarios.py) | Aba Usuários: lista, criação com a pasta escolhida, troca de senha, remoção e a dispensa do TLS por usuário |
| [`aba_arquivos.py`](../painel/aba_arquivos.py) | Aba Arquivos: navegação pelas pastas dos usuários, download e criação de pasta vazia |
| [`aba_meus_arquivos.py`](../painel/aba_meus_arquivos.py) | Tela Meus arquivos, do usuário do FTP: navegação e download dentro da pasta dele |
| [`aba_administradores.py`](../painel/aba_administradores.py) | Aba Administradores: lista, criação, troca de senha, troca de nome e remoção |
| [`aba_seguranca.py`](../painel/aba_seguranca.py) | Aba Segurança |
| [`aba_atividade.py`](../painel/aba_atividade.py) | Aba Atividade |

Os módulos não gravam nada na imagem: a raiz do container é somente leitura e o Python roda sem gerar `.pyc`. O `./scripts/validate.sh` confere a sintaxe de todos e que nenhum usa nome que não definiu nem importou.

</details>

---

⬅️ [Backup e restauração](backup.md) · 🏠 [Documentação](README.md) · ➡️ [Fotos da aplicação](aplicacao/README.md)
