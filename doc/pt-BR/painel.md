# 🖥️ Painel web — allsafe-ftp-stack

🌐 [English](../en/panel.md) · **Português (Brasil)**

↩ [README do projeto](../../README.pt-BR.md) · [Índice da documentação](README.md)

## 💡 Em poucas palavras

O painel é uma página, aberta pelo navegador **de dentro da rede interna**, para criar, trocar a senha e remover os usuários do FTP, escolher a pasta de cada um, criar pastas e baixar os backups recebidos, sem usar a linha de comando. Cada administrador entra com o próprio usuário e a própria senha, só por HTTPS. O dono dos arquivos também entra: cada usuário do FTP usa o nome e a senha do FTP e alcança só a própria pasta, onde faz o que o [perfil](#perfis) dele deixa. Quem atende o navegador é o nginx, a porta de entrada: ele barra quem está fora da rede interna e só então passa o pedido ao painel. O que é feito no painel vale no FTP na hora, sem reiniciar nada.

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

[Abrir o painel](#abrir) · [O que há em cada aba](#abas) · [Idioma das telas](#idioma) · [Usuários pelo painel](#usuarios) · [Perfis](#perfis) · [Arquivos e download](#arquivos) · [Usuário do FTP no painel](#usuario-ftp) · [Destinos: S3, rclone e bot do Telegram](#destinos) · [Servidor: containers e recursos](#servidor) · [Administradores do painel](#administradores) · [Recuperar o acesso](#senha) · [Certificado do painel](#certificado) · [Abrir para a rede interna](#rede-interna) · [Marca do painel](#marca) · [Como o painel decide](#como-decide) · [Auditoria](#auditoria) · [O que protege o painel](#protecoes)

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

**Resultado esperado:** a tela **Visão geral**, com o FTP `No ar` e, no menu, o nome do administrador que entrou.

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
| Visão geral | FTP no ar ou fora, quantidade de usuários, espaço usado e livre, último envio, validade do certificado do FTP, o modo de TLS do FTP, a faixa **Servidor e containers** (processador e memória do servidor e dos containers da stack, cada um com o uso contra o que há ou o que foi alocado), os arquivos recebidos por dia nos últimos 14 dias, o último envio de cada usuário, o espaço de cada pasta, os dados para configurar o equipamento (servidor, porta de controle, portas passivas, protocolo) e os últimos registros da atividade | Só consultar; cada cartão termina no atalho para a aba do detalhe |
| Usuários | Todas as contas em uma lista, cada uma com o **perfil** embaixo do nome. Primeiro os administradores do painel, com a marca **você** na conta de quem está usando o painel e quantas sessões cada um tem abertas; depois os usuários do FTP, um por linha: pasta, com a marca **dividida** quando outro usuário também a alcança, e o nome, com a marca **bloqueado** quando o FTP o está recusando por senhas erradas demais, espaço usado, quantidade de arquivos e último envio; a coluna **TLS** diz se o usuário é obrigado a usar TLS | Criar, escolhendo o perfil (Administrador, Completo, Envio, Só envio ou Leitura), a pasta e, para equipamento sem suporte a TLS, já dispensado do TLS; editar, para trocar o perfil, a pasta e os limites e tirar um bloqueio; trocar a senha; remover, com a pasta dele ou sem ela; abrir a pasta do usuário na aba Arquivos; dispensar um usuário do TLS e voltar a exigir; trocar a senha e o nome de um administrador e removê-lo |
| Arquivos | As pastas dos usuários do FTP e o que há em cada uma: nome, tamanho e data de cada arquivo | Entrar nas pastas, pelo nome ou pelo botão **Abrir**, baixar um arquivo pelo navegador, enviar um arquivo para a pasta aberta, criar uma pasta, trocar o nome e apagar arquivo e pasta, mandar um arquivo na hora a um [destino](#destinos) gravado, e abrir o cadastro de usuário já com a pasta aberta |
| Destinos | Os lugares de fora para onde o painel envia sozinho os arquivos das pastas, armazenamentos S3, remotos do rclone e bots do Telegram: se cada um está ligado, a pasta, o intervalo, a última passada e o total enviado, sem mostrar os segredos | **Configurar**, **Testar**, **Enviar agora**, **Alterar** e **Remover** cada destino; com o destino gravado, a aba Arquivos ganha o botão de enviar um arquivo na hora: veja [Destinos](#destinos) |
| Servidor | Os três containers da stack (servidor FTP, painel e frente web), cada um com o que usa de processador, memória e processos contra o que foi alocado a ele, e, separados, os recursos do servidor em que a stack roda: processador, memória, disco e rede do FTP, com o estado, a medida de agora e o histórico dos últimos minutos | Só consultar; **Atualizar sozinha** refaz a leitura a cada 10 s, sem contar como uso da sessão: veja [Servidor](#servidor) |
| Segurança | Conferência da instalação, com o resumo de quantos itens estão em ordem, pedem atenção ou são conferidos no servidor: se endereço público é aceito, se o painel está publicado por proxy ou túnel, endereços do FTP e do painel, modo TLS, com a exceção por usuário e quem está dispensado, a entrada dos usuários do FTP, a frente web (nginx), validade e impressão digital dos dois certificados, redes que podem abrir o painel, regras da sessão, o custo das senhas do FTP, com os usuários que ainda estão com o custo anterior, o contato de segurança publicado em `/.well-known/security.txt`, isolamento do container e o lembrete do firewall | Só consultar |
| Bloqueios | Os endereços e os prefixos, IPv4 e IPv6, com [bloqueio por endereço](seguranca.md#bloqueio-por-endereco): a regra em vigor, o total e, por bloqueio, quem bloqueou (o FTP, o painel ou o administrador), com quantos erros, desde quando e até quando. Embaixo, quando há, os usuários com bloqueio por tentativa no FTP | **Bloquear endereço**, para bloquear à mão um endereço ou um prefixo, procurar um endereço, **Mudar prazo**, para bloquear por mais tempo ou encurtar, e **Desbloquear**; abrir o usuário que está com bloqueio por tentativa |
| Log | Os últimos 300 registros do painel: entradas, recusas, downloads, envios, pastas criadas, bloqueios e alterações de usuário e de administrador, com data, endereço de origem e quem fez, administrador ou usuário do FTP | Só consultar |

O menu fica à esquerda em tela de 1280 px de largura ou mais: o símbolo e o nome, as abas em dois grupos (**Operação**, com Visão geral, Usuários, Arquivos e Destinos, e **Sistema**, com Servidor, Segurança, Bloqueios e Log), a aba em uso marcada e, embaixo, o botão de [idioma](#idioma) (**PT** e **EN**), o nome e o papel de quem entrou e o botão **Sair**, que encerra a sessão na hora. Em tela mais estreita, o menu vira uma faixa em cima, com as abas numa linha que rola para o lado. Com a instalação publicada (endereço público aceito ou painel por proxy ou túnel), o administrador vê um sinal de alerta ao lado de **Segurança**, em qualquer aba em que estiver. Os gráficos são desenhados pelo próprio painel, sem script, e todo número do desenho está também escrito ao lado dele. No rodapé de todas as telas ficam a versão e a autoria: veja [Marca do painel](#marca).

Cada aba abre com uma faixa no azul da marca, o mesmo do menu e da tela de entrada, nos temas claro e escuro: o ícone da aba, o título, uma linha que diz o que a tela mostra e, à direita, a ação principal. Em tela com mais de 900 px de largura, a faixa leva também a cena do caminho do backup, a da tela de entrada, em miniatura: os pacotes atravessam uma vez, na chegada à tela, e param. Com **Atualizar sozinha** ligada na aba Servidor, ou com o sistema pedindo menos movimento, nada se mexe. Tela de formulário (novo usuário, editar, trocar senha, renomear, apagar) leva a faixa fina, só com o título.

As listas se ajustam à largura da tela, sem rolagem lateral da página:

| Lista | Até 640 px de largura | Tela média | Tela larga |
|---|---|---|---|
| Usuários | Um bloco por conta, com o rótulo de cada dado e as ações embaixo | De 641 a 1095 px, um bloco por conta: nome e perfil em cima, os dados lado a lado e as ações embaixo | A partir de 1096 px, tabela, com as ações duas por linha; a partir de 1600 px, em uma linha |
| Arquivos e Meus arquivos | Um bloco por item, com o tamanho, a data e as ações embaixo do nome | De 641 a 899 px, o nome, o tamanho e a data em uma linha e as ações na linha de baixo | A partir de 900 px, tabela |
| Log | Um bloco por registro | De 641 a 959 px, a data, o endereço e o fato em uma linha e o detalhe embaixo | A partir de 960 px, tabela |
| Bloqueios | Um bloco por endereço, com o rótulo de cada dado e as ações embaixo | De 641 a 1095 px, um bloco por endereço, com os dados lado a lado e as ações embaixo | A partir de 1096 px, tabela |
| Conferência da aba Segurança | A marca e o item em cima e a situação embaixo, na largura inteira | Tabela | Tabela |

Lista sem nada para mostrar (pasta vazia, Log sem registro) diz o que falta e quando passa a aparecer. O texto longo de cada tela, como a explicação dos perfis e das etiquetas da aba Usuários, fica recolhido em uma linha embaixo da lista e abre com um clique.

Quem entra com a conta do FTP não vê nenhuma dessas abas: vê uma tela só, **Meus arquivos**, descrita em [Usuário do FTP no painel](#usuario-ftp).

A foto de cada tela, com a explicação item por item, está em [Fotos da aplicação](aplicacao/README.md).

> ⚠️ Com `FTP_TLS_MODE` em `0` ou `1`, as abas Visão geral e Segurança abrem com um alerta no começo da tela: o FTP está aceitando senha e arquivo em texto puro. O alerta só some quando a variável volta para `2` ou `3`. Veja [Segurança](seguranca.md#ftp-sem-tls).

> ⚠️ Com pelo menos um usuário dispensado do TLS, as mesmas abas abrem com o alerta de quantos e quais usuários entram no FTP sem TLS. Ele some quando o último volta a ser obrigado a usar TLS. Veja [Segurança](seguranca.md#tls-por-usuario).

---

<a name="idioma"></a>

## 🌍 Idioma das telas

O painel fala **português**, que é o padrão, e **inglês**. A troca é pelo botão **PT** e **EN**, cada lado com a bandeira do idioma (a do Brasil e a dos Estados Unidos), que fica no menu, junto do nome de quem entrou, e também na tela de entrada. O idioma em uso aparece marcado.

| Onde o botão é usado | O que muda | Onde a escolha fica |
|---|---|---|
| Na tela de entrada | A tela de entrada daquele navegador | No navegador, por um ano |
| Depois da entrada | As telas da conta: todas as sessões abertas dela e as próximas entradas, em qualquer navegador | No servidor, uma por conta |

Cada conta escolhe o seu, administrador ou usuário do FTP: a escolha de uma não muda a tela de nenhuma outra. A conta que nunca escolheu entra no idioma que o navegador guardou na tela de entrada e, sem isso, em português. Depois da troca, o painel volta para a tela em que o botão foi usado.

Em inglês mudam todas as telas, os avisos, os erros dos formulários e a descrição de cada registro da aba Log; a data passa a `ano-mês-dia` e os números usam ponto decimal e vírgula de milhar. Não mudam os nomes de usuário, de pasta e de arquivo, o arquivo de auditoria, as mensagens do FTP e as dos scripts do terminal.

<details>
<summary>Detalhe técnico — como o idioma é guardado e trocado</summary>

- **Por conta:** `DATA_DIR/painel/idiomas` (`/painel/idiomas` no container), `0600`, do `root`, uma linha `admin:<nome>:<pt|en>` ou `usuario:<nome>:<pt|en>` por conta que escolheu. O arquivo é gravado ao lado e trocado de uma vez. A linha acompanha o administrador que troca de nome e sai quando a conta é removida pelo painel. A de usuário removido pelo terminal sai na troca de idioma seguinte, de qualquer conta; até lá, um usuário criado com o mesmo nome entra no idioma do anterior.
- **No navegador:** cookie `__Host-idioma`, com `Secure`, `HttpOnly`, `SameSite=Lax` e validade de um ano, gravado na troca e em toda entrada. Só `pt` e `en` são lidos: outro valor é ignorado. Ele não é sessão e não abre nenhuma tela.
- **Troca:** `POST /idioma`, com o token dos outros formulários da sessão; antes da entrada, com o token do formulário de entrada. Por `GET` não há troca, e idioma fora da lista recebe `400`. A volta sai do caminho da tela de origem e só quando ele é uma tela do papel da sessão: nos outros casos, o começo do painel.
- **Textos:** o texto em português é o que está no código, e o catálogo do inglês é o [`painel/idioma_en.py`](../../painel/idioma_en.py). Texto sem tradução sairia em português; o `./scripts/validate.sh` recusa o código em que falta ou sobra tradução.
- **Bandeiras:** são desenhadas dentro da própria página, pelo [`painel/icones.py`](../../painel/icones.py), como os outros ícones: não são emoji nem arquivo de imagem, e nada é buscado fora do painel.
- **Auditoria:** a troca de idioma não gera registro. As recusas dela são as de qualquer formulário: `recusa_csrf` e `recusa_origem`.

</details>

---

<a name="usuarios"></a>

## 👥 Usuários pelo painel

| Quero | Onde | O que acontece |
|---|---|---|
| Criar um usuário | Usuários ➜ **Novo usuário** | Cria a conta, com o perfil marcado, e a pasta dela: `DATA_DIR/dados/<usuario>` com o campo **Pasta** em branco, ou a pasta escolhida. Com a senha em branco, o painel gera uma senha forte e a mostra **uma única vez** |
| Escolher o que o usuário pode fazer | Usuários ➜ **Novo usuário**, campo **Perfil**; depois, **Editar**, cartão **Perfil** | O usuário passa a ter o perfil escolhido na entrada seguinte dele no FTP: veja [Perfis](#perfis) |
| Criar um usuário para equipamento sem suporte a TLS | Usuários ➜ **Novo usuário**, com a caixa **Equipamento sem suporte a TLS** | O usuário já nasce dispensado do TLS e o equipamento entra em seguida. Sem marcar a caixa, o usuário só entra com TLS |
| Trocar a senha | Usuários ➜ **Trocar senha** | A senha antiga deixa de valer no próximo login |
| Trocar a pasta | Usuários ➜ **Editar** | O usuário passa a entrar na pasta nova na entrada seguinte. **Os arquivos da pasta anterior continuam nela**, sem serem movidos nem apagados |
| Limitar um usuário | Usuários ➜ **Editar**, cartão **Limites** | Sessões ao mesmo tempo, taxa de download e de envio, horário de entrada e downloads ao mesmo tempo pelo painel, só para aquele usuário. Campo em branco: vale o limite da stack. Vale na entrada seguinte dele no FTP |
| Remover um usuário | Usuários ➜ **Remover** | Pede confirmação. A conta some; **os arquivos da pasta são preservados** |
| Remover um usuário e a pasta dele | Usuários ➜ **Remover**, com a caixa **Apagar também a pasta e tudo o que há nela** | Pede também a sua senha atual. A conta some e a pasta é apagada com tudo o que tem dentro, **sem lixeira**. A caixa só aparece quando a pasta é só dele |
| Deixar um usuário entrar sem TLS | Usuários ➜ **Dispensar TLS**, ou a caixa **Equipamento sem suporte a TLS** em **Novo usuário** | Pede confirmação e vale em instantes, sem derrubar quem está conectado; os demais continuam obrigados a usar TLS |
| Voltar a exigir o TLS de um usuário | Usuários ➜ **Exigir TLS**, ou **Editar**, cartão **TLS** | Pede confirmação e vale em instantes, para as entradas seguintes dele. Troque a senha dele, que passou em texto puro |

**Resultado esperado:** o usuário criado entra por FTPS logo em seguida, sem reiniciar o FTP.

Os formulários, as mensagens de recusa e a tela da senha gerada estão em [Fotos da aplicação](aplicacao/README.md#usuarios).

Regras, as mesmas do [`manage-user.sh`](../../manage-user.sh):

- Nome com letras minúsculas, números, `_` e `-`, começando por letra ou `_`, até 32 caracteres.
- Senha com no mínimo 12 caracteres.
- Pasta: em branco, é o nome do usuário. Escolhida, fica sempre dentro de `DATA_DIR/dados`, com até 4 níveis separados por `/` (`clientes/olt-01`); cada nível tem letras, números, `_`, `-` e ponto, não começa com ponto e vai até 64 caracteres. A pasta é criada se não existir, e o campo sugere as que já existem no primeiro nível.
- Pasta que passa por link simbólico, ou por um nome que já é de um arquivo, é recusada.
- A pasta é escolhida na criação e trocada depois em **Editar**, com as mesmas regras. A troca não mexe na senha nem nos arquivos: o que estava na pasta anterior continua lá, e a pasta nova é criada se não existir.
- O **usuário inicial** (`FTP_USER`) tem a senha e a pasta trocadas e é removido como os demais. Ele é criado uma vez, pela instalação: removido, não volta nas subidas seguintes do FTP, e para tê-lo de novo basta criar um usuário com o mesmo nome, que fica com a senha informada. A senha trocada pelo painel vale até o arquivo `.secrets/ftp-usuario-inicial-senha.txt` ser alterado: na subida seguinte do FTP, passa a valer a do arquivo. Veja [Segredos](segredos.md#trocar-a-senha).

<a name="perfis"></a>

Perfil de cada conta, escolhido em **Novo usuário** e trocado em **Editar**, cartão **Perfil**. O perfil vale no FTP e na entrada do usuário pelo painel:

| Perfil | No FTP | No painel |
|---|---|---|
| Administrador | Não é conta do FTP | Todas as abas: veja [Administradores do painel](#administradores) |
| Completo | Lista, baixa, envia, cria pasta, renomeia, apaga e grava por cima | Tela Meus arquivos: navega, baixa, cria pasta, troca o nome e apaga |
| Envio | Lista, baixa, envia e cria pasta. Não apaga, não renomeia e não grava por cima do que já chegou | Tela Meus arquivos: navega, baixa e cria pasta |
| Só envio | Envia e cria pasta. Não lista e não baixa nada, nem o que ele mesmo enviou | Tela Envio de arquivos: os dados para enviar por FTP e, com a permissão do administrador, o envio pelo painel |
| Leitura | Só lista e baixa | Tela Meus arquivos: navega e baixa |

- Usuário criado antes da `0.51.0`, ou sem perfil informado, é **Completo**: nada muda para quem já usa a stack.
- **Envio guarda o que recebeu.** O arquivo passa a ser do servidor assim que termina de chegar: daí em diante o usuário não o apaga, não o renomeia e não grava por cima. Equipamento que envia sempre com o mesmo nome de arquivo precisa do perfil Completo, ou de um nome com data.
- **Só envio não vê os backups.** A conta entra em uma área de entrada só dela, fora da pasta dos backups, e o servidor leva cada arquivo para a pasta do usuário assim que ele termina de chegar. Quem tem a senha desse equipamento envia, e mais nada: não lista, não baixa, não apaga e não troca o nome de nenhum arquivo já recebido.
- **Leitura não grava nada:** nem arquivo, nem pasta, em nenhum nível da pasta dele.
- **Pasta dividida:** quem tem a mesma pasta, ou uma dentro da outra, alcança os arquivos do outro até onde o próprio perfil deixa. Um Leitura baixa o que o Envio mandou; um Envio não apaga o que o Completo gravou.
- **No painel, o perfil decide o que existe:** a tela mostra só os botões do perfil, e a ação que ele não tem responde `404` mesmo pedida direto pelo endereço. Enviar arquivo pelo painel depende de uma permissão própria, dada pelo administrador: veja [Enviar arquivo pelo painel](#enviar-arquivo).
- **Troca de perfil:** vale na entrada seguinte do usuário no FTP e encerra a sessão dele no painel. A sessão de FTP que já está aberta segue com o perfil anterior até sair.
- **Administrador e usuário do FTP são cadastros separados**, com a senha guardada em lugares diferentes: não há troca de um para o outro. Remova a conta e crie a outra.

Três limites do perfil Envio, para não contar com o que ele não faz:

- Entre o fim do envio e a entrega ao servidor passa um instante, de milissegundos, em que o arquivo ainda é do usuário.
- Pasta criada pelo próprio Envio continua dele enquanto está vazia: ele a remove ou renomeia até gravar o primeiro arquivo nela.
- Pasta criada **por FTP** por um usuário Completo só recebe arquivo do Envio depois que o Completo grava o primeiro arquivo nela. Pasta criada pela aba Arquivos recebe na hora.

Cinco comportamentos do perfil Só envio, para escolher sabendo:

- **Nome repetido não substitui:** o arquivo que chega com o nome de um que já está na pasta ganha a data e a hora antes da extensão (`backup.rsc` vira `backup-20261009-153000.rsc`), e o anterior fica como estava.
- **O cliente não confere o envio pela lista:** a lista da conta vem vazia, e o tamanho do arquivo enviado não é informado. Programa que envia com um nome temporário e troca o nome no fim, ou que lista a pasta para confirmar, precisa do perfil Envio.
- **Envio interrompido é entregue como chegou:** o pedaço recebido vai para a pasta com o nome do arquivo, e a nova tentativa ganha a data e a hora. Continuar o envio de onde parou não funciona neste perfil.
- **Pastas do caminho:** a pasta que o cliente cria antes de enviar nasce na pasta do usuário junto com o primeiro arquivo dela. Pasta criada e deixada vazia não chega à pasta do usuário.
- **Mesma pasta para vários:** um Só envio pode dividir a pasta com um Completo, um Envio ou um Leitura. Eles veem e baixam o que o Só envio mandou; ele não vê o que os outros gravaram.

<details>
<summary>Detalhe técnico — como o perfil é aplicado</summary>

- **Cadastro:** o perfil é a identidade de sistema da conta no PureDB, e não uma lista à parte: Completo é `ftpdata:ftpdata` (`10000:10000`), Envio é `ftpenvio:ftpdata` (`10002:10000`), Leitura é `ftpleitura:ftpleitura` (`10003:10003`) e Só envio é `ftpsoenvio:ftpsoenvio` (`10004:10004`). Quem recusa o apagamento ou a gravação é o sistema de arquivos, para qualquer comando do FTP.
- **Área de entrada do Só envio:** a pasta da sessão dele no cadastro é `/data/.entrada/<usuário>`, `0700` do `ftpsoenvio`, dentro de `/data/.entrada`, `0700` do `root`. A pasta de destino fica guardada no campo de descrição do cadastro. A cada envio, o vigia do FTP liga o arquivo na pasta de destino sem substituir o que existe, confere que é o mesmo arquivo, passa-o ao `ftpdata` e o tira da área. As duas pontas são abertas nível por nível a partir de `/data`, sem seguir link simbólico; só entra arquivo comum, com um nome só e ainda do `ftpsoenvio`. A aba Arquivos não mostra a área nem a abre pelo endereço.
- **Modo da pasta:** calculado por quem a alcança. Só Completo: `0750`. Com um Envio: `1770`, em que o grupo grava e cada um só apaga o que é dele. Com um Leitura: mais leitura para os outros (`0755` ou `1775`). As pastas de dentro acompanham quando o modo muda. `DATA_DIR/dados` fica `0700`, do `root`: nenhuma conta do FTP sai da própria pasta.
- **Entrega:** a cada envio em pasta com Envio ou Leitura, o vigia do FTP passa o arquivo ao `ftpdata`, e as pastas do caminho, ao `ftpdata` com o modo da pasta do usuário. Só mexe em arquivo comum, com um nome só e ainda do `ftpenvio`. O que não pôde ser entregue fica no registro do `ftp` como `entrega nao feita`.
- **Partida do `ftp`:** com Envio, Só envio ou Leitura no cadastro, a subida refaz o modo das pastas e entrega o que ficou sem entrega, antes de aceitar a primeira sessão. Na área de entrada, apaga as pastas que ficaram vazias; o que não é arquivo comum do `ftpsoenvio` fica onde está, com `AVISO: ficou arquivo sem entrega` no registro do `ftp`.
- **Troca e remoção do Só envio:** ao sair do perfil e ao remover o usuário, o que ainda está na área é entregue e a área é apagada. Os arquivos da pasta de destino ficam.
- **Sessão do painel:** a marca da sessão do usuário do FTP é o resumo da linha dele no cadastro; a troca de perfil muda a linha, e a sessão acaba sozinha, com `sessao_encerrada` e o motivo `cadastro_alterado`.

</details>

<a name="limites"></a>

Limites por usuário, no cartão **Limites** da tela **Editar**. Servem tanto para a conta de um equipamento, que só envia, quanto para a de uma pessoa, que entra, envia e baixa:

| Limite | Onde vale | Valor | Em branco |
|---|---|---|---|
| Sessões ao mesmo tempo | FTP | De 1 ao `FTP_MAX_CLIENTS` da stack | Só os limites da stack: `FTP_MAX_CLIENTS` no total e `FTP_MAX_CLIENTS_PER_IP` por endereço |
| Taxa de download | FTP e downloads dele pelo painel | De 1 a 10.000.000 KB por segundo | Sem teto |
| Taxa de envio | FTP e envios dele pelo painel | De 1 a 10.000.000 KB por segundo | Sem teto |
| Horário de entrada | FTP e entrada dele no painel | Início e fim, em horas e minutos; pode passar da meia-noite (`22:00` às `06:00`) | Entra a qualquer hora |
| Downloads ao mesmo tempo | Painel | De 1 a 8 | 2 |
| Senhas erradas no FTP até o bloqueio | FTP | De 1 a 100; `0`: este usuário nunca é bloqueado | O padrão da stack, `FTP_BLOQUEIO_TENTATIVAS` (5) |
| Minutos de bloqueio | FTP | De 1 a 1440 | O padrão da stack, `FTP_BLOQUEIO_MINUTOS` (15) |
| Envio pelo painel | Painel | Caixa **Permitir que este usuário envie arquivo pelo painel, para a pasta dele**, marcada ou não; vale nos perfis Só envio, Envio e Completo | Sem marcar: o usuário só envia por FTP |

**Resultado esperado:** a lista de usuários volta com o aviso `Limites gravados` e a marca **limites** ao lado do nome; passando o mouse sobre ela, aparece cada limite que o usuário tem. Para tirar um limite, apague o campo e grave de novo. A permissão de envio pelo painel é dada na edição, depois de o usuário existir, e vale na hora, sem encerrar a sessão dele: veja [Enviar arquivo pelo painel](#enviar-arquivo).

<a name="bloqueios"></a>

**Bloqueio por tentativa.** O endereço que erra a senha de um usuário no FTP vezes demais fica bloqueado para aquele usuário, pelo tempo configurado: até lá, nem a senha certa entra dali. Os outros endereços, os outros usuários e a entrada dele no painel continuam como estavam. Para tirar o bloqueio antes do prazo:

1. Na aba Usuários, o nome aparece com a marca **bloqueado**; passando o mouse sobre ela, aparecem os endereços.
2. Clique em **Editar**. O cartão **Bloqueios** lista cada endereço, com as senhas erradas, a hora do bloqueio e até quando ele vale.
3. Corrija a senha no equipamento e clique em **Desbloquear**.

**Resultado esperado:** a lista de usuários volta com o aviso `Bloqueio removido. O usuário volta a poder entrar no FTP.`, sem a marca **bloqueado**, e a entrada seguinte do equipamento passa. O que conta e o que não conta como senha errada está em [Segurança](seguranca.md#bloqueio-por-tentativa).

> ⚠️ **O que muda para o usuário:** fora do horário, o FTP recusa a entrada como recusa senha errada, e com todas as sessões dele ocupadas, responde que não aceita mais conexões do mesmo usuário. Nos dois casos ele também não entra no painel, porque é o FTP que confere a senha.

> ⚠️ **Equipamento com a senha errada gravada:** ele tenta de novo sozinho, chega ao limite e fica bloqueado; se continuar tentando depois do prazo, é bloqueado outra vez. Corrija a senha no equipamento antes de desbloquear. Equipamentos que chegam ao FTP pelo mesmo endereço, com o mesmo usuário, são bloqueados juntos.

> ⚠️ **Taxa de envio e arquivo pequeno:** com a taxa de envio definida, o servidor segura cada arquivo enviado por cerca de `256 ÷ taxa` segundos, além do tempo do envio. Com 50 KB por segundo, um arquivo de 1 KB leva 5 segundos; com 1.000, um quarto de segundo. Para equipamento que manda muitos arquivos pequenos, use uma taxa alta ou deixe em branco.

> ⚠️ **Pasta dividida:** dois usuários com a mesma pasta, ou com uma dentro da outra, leem, gravam e apagam os arquivos um do outro. O painel aceita, porque serve para uma conta de consulta na pasta de cima, e avisa: a lista marca a pasta com **dividida** e mostra quem mais a alcança, e a tela de remoção repete o aviso. Para um equipamento não alcançar o backup de outro, dê a cada um a própria pasta.

> ⚠️ **Apagar a pasta junto não tem volta:** o painel não tem lixeira, e o que sai dali só volta do [backup](backup.md). A tela de remoção mostra quantos arquivos a pasta tem antes de pedir a confirmação. A caixa não aparece, e o pedido é recusado, quando outro usuário usa a mesma pasta, uma de dentro ou uma de fora dela: remova antes os outros ou troque a pasta deles em **Editar**.

> ⚠️ **Dispensa do TLS:** o usuário dispensado manda senha e arquivo em texto puro. Use só para o equipamento antigo que não fala TLS, em rede interna isolada, com usuário e senha só dele. As condições e o que a stack garante estão em [Segurança](seguranca.md#tls-por-usuario).

<a name="limpeza"></a>

**Limpeza automática.** No cartão **Limpeza automática** da tela **Editar**, o administrador escolhe o que o painel apaga sozinho na pasta do usuário e nas pastas de dentro dela. Vem desligada: sem regra, nada é apagado.

| Regra | O que faz | Valor | Em branco |
|---|---|---|---|
| Manter só os arquivos mais recentes | Em **cada pasta**, ficam os arquivos de data de modificação mais nova, na quantidade escolhida; os mais antigos saem | De 1 a 100.000 | Não conta os arquivos |
| Apagar depois de tantos dias | Sai o arquivo que está há mais dias que isso no servidor | De 1 a 3.650 | Não olha a idade |

Com as duas preenchidas, sai o arquivo que passar de qualquer uma. A contagem é por pasta: com `30` na pasta de um usuário que guarda cada equipamento em uma subpasta, ficam os 30 arquivos mais recentes de cada equipamento.

1. Na aba Usuários, clique em **Editar** no usuário.
2. No cartão **Limpeza automática**, preencha uma regra ou as duas.
3. Digite a sua senha e clique em **Gravar limpeza**.

**Resultado esperado:** a lista de usuários volta com o aviso de que a limpeza foi gravada e a marca **limpeza** ao lado do nome; passando o mouse sobre ela, aparece a regra. A regra vale na passada seguinte, que acontece a cada `PAINEL_RETENCAO_MINUTOS` (60 minutos, no padrão). Para desligar, apague os dois campos e grave de novo. O usuário vê a regra na tela Meus arquivos, em um aviso acima da lista.

> ⚠️ **A limpeza não tem volta:** o painel não tem lixeira, e o que sai dali só volta do [backup](backup.md). Antes de ligar, veja o que sairia com `--simular`, no detalhe técnico abaixo.

> ⚠️ **Regra por dias em backup de equipamento:** se o equipamento parar de enviar, os arquivos que ele já mandou continuam envelhecendo e saem todos no prazo. Para backup de equipamento, prefira manter os mais recentes, que sempre deixa os últimos na pasta.

> ⚠️ **Pasta dividida:** a regra alcança a pasta do usuário e tudo o que está dentro dela, inclusive a pasta de outro usuário que fique ali. O cartão avisa quais usuários são alcançados.

<details>
<summary>Detalhe técnico — a dispensa do TLS no painel</summary>

- A dispensa vale com `FTP_TLS_EXCECOES=sim`, que é o padrão, `FTP_TLS_MODE=2` e sem `REDE_PERMITIR_IP_PUBLICO=sim`. Fora disso ela fica sem efeito: a coluna **TLS**, os botões e a caixa do **Novo usuário** somem, a tela de confirmação responde `404`, o cartão **TLS** de **Editar** e a aba Segurança dizem o motivo, e a lista dos dispensados fica guardada sem valer.
- A caixa do **Novo usuário** manda `sem_tls=sim`. O usuário é criado e depois dispensado: se a dispensa falhar, ele fica obrigado a usar TLS e o aviso manda repetir em **Editar**. Com a dispensa sem efeito, o campo é ignorado.
- Sem nenhum dispensado, o FTP recusa a sessão sem TLS antes de a senha ser enviada. Com o primeiro dispensado, e de novo quando o último volta a ser obrigado, o FTP troca o modo de entrada em cerca de um segundo, sem reiniciar o container e sem derrubar as sessões em andamento.
- `GET /usuarios/tls?usuario=<nome>` mostra a confirmação, aberta pela lista ou pelo cartão **TLS** de **Editar**; `POST /usuarios/tls` grava, com o token CSRF da sessão e o campo `acao` em `dispensar` ou `exigir`. Usuário que não existe e nome fora da regra respondem `404`; `acao` diferente volta para a confirmação sem alterar nada.
- Quem grava é o `allsafe-ftp-user`, o mesmo script do `manage-user.sh`, na `sem-tls.lista` de `DATA_DIR/auth`. O painel só lê a lista para montar as telas.
- Remover o usuário tira o nome dele da lista: um usuário novo com o mesmo nome não herda a dispensa.
- Cada alteração fica na auditoria, com o administrador e o usuário: `tls_dispensado` e `tls_exigido`.

</details>

<details>
<summary>Detalhe técnico — os limites por usuário</summary>

- `POST /usuarios/limites` grava todos de uma vez, com o token CSRF da sessão e os campos `usuario`, `sessoes`, `download`, `envio`, `inicio`, `fim`, `baixar`, `tentativas` e `minutos`. Campo em branco tira o limite. Valor fora da regra, início sem fim ou início igual ao fim respondem `400`, com a tela de volta e o que foi digitado; usuário que não existe e nome fora da regra, `404`. Nada é gravado pela metade.
- **Quem guarda e quem aplica:** sessões, taxas e horário ficam na linha do usuário em `/auth/pureftpd.passwd`, gravados com `pure-pw usermod`, e quem os aplica é o `pure-ftpd`, a cada entrada. O limite de downloads pelo painel fica em `/auth/limites.lista` (`0600`), e quem o aplica é o painel. Os dois campos do bloqueio por tentativa ficam na mesma lista, e quem os aplica é o vigia do serviço `ftp`: [Scripts](scripts.md#vigia). Todos são gravados pelo `allsafe-ftp-user limites`, o mesmo comando do [`manage-user.sh`](../../manage-user.sh).
- **Horário:** vale no fuso do container, o da variável `TZ`. O `pure-pw` guarda as horas sem os zeros da esquerda (`08:00` às `18:00` fica `800-1800`); o painel e o `manage-user.sh` mostram sempre com quatro dígitos.
- **Taxa de download no painel:** os downloads que o próprio usuário faz na tela Meus arquivos saem na taxa dele. Os que o administrador faz na aba Arquivos, não.
- **Sessão do usuário no painel:** trocar um limite que fica no cadastro do FTP muda a linha dele, e as sessões dele no painel são encerradas no pedido seguinte. Trocar só o limite de downloads pelo painel não encerra nada e vale no download seguinte.
- **Entrada recusada pelo limite:** fora do horário, o FTP responde `530`, e o painel, `401`, como para senha errada: conta como erro de entrada. Com as sessões ocupadas, o FTP responde `421` depois de conferir a senha, e o painel, `401`, com `entrada_falha conferencia=ftp_indisponivel` na auditoria.
- **Usuário inicial:** os limites dele ficam de uma subida para a outra; o serviço `ftp` só reaplica a senha.
- **Bloqueio:** mudar `tentativas` ou `minutos` tira os bloqueios que o usuário tem; gravar os outros limites, não. Trocar a senha dele e removê-lo também tiram. `POST /usuarios/desbloquear`, com o token CSRF da sessão e o campo `usuario`, tira todos os bloqueios do usuário de uma vez e grava `bloqueio_removido` na auditoria, com o administrador, o usuário e a quantidade de endereços; usuário que não existe e nome fora da regra respondem `404`. O painel só lê `/auth/bloqueios` para montar as telas: quem grava o bloqueio é o vigia, e quem o tira é o `allsafe-ftp-user desbloquear`, o mesmo comando do `manage-user.sh`. Para tirar o bloqueio de um endereço só, use o terminal: [Operação](operacao.md#usuarios).
- Remover o usuário tira o nome dele da `limites.lista`: um usuário novo com o mesmo nome não herda o limite.
- Cada gravação fica na auditoria como `limites_alterados`, com o administrador, o usuário e o valor de cada limite (`-` no que ficou em branco).

</details>

<details>
<summary>Detalhe técnico — a limpeza automática</summary>

- `POST /usuarios/limpeza` grava a regra, com o token CSRF da sessão e os campos `usuario`, `ultimos`, `dias` e `senha_atual`, a senha de quem está na sessão. Senha errada ou em branco recebe `403`, e nada é gravado; desligar a regra pede a senha do mesmo jeito. Só administrador tem essa rota.
- **Quem guarda:** a regra fica na linha do usuário em `/auth/limites.lista`, nas chaves `ultimos=` e `dias=`, gravada pelo `allsafe-ftp-user` (ação `retencao`), o mesmo comando do `manage-user.sh`. Usuário sem pasta dentro de `DATA_DIR/dados` não tem o cartão.
- **Quem aplica:** o [`limpeza.py`](../../painel/limpeza.py), em uma linha de execução do próprio painel: a primeira passada sai 2 minutos depois da subida, e as seguintes, a cada `PAINEL_RETENCAO_MINUTOS`. Com `0`, nenhuma passada acontece e a tela avisa.
- **O que sai:** só arquivo comum. Ficam como estão o link simbólico, tudo o que tem o nome começado por ponto (arquivo ou pasta), a área de entrada do perfil Só envio e o que está em outro sistema de arquivos montado dentro da pasta.
- **Qual data conta:** manter os mais recentes ordena pela data de modificação do arquivo. Apagar por dias olha a data mais nova entre a de modificação e a de mudança no servidor: o arquivo que chegou hoje com data antiga não sai no mesmo dia.
- **Subpastas:** a regra desce pelas pastas de dentro, até 64 níveis e 10.000 subpastas por pasta em cada passada. A subpasta que a limpeza esvaziou sai junto; a que já estava vazia, não. A pasta do usuário nunca sai.
- **Caminho:** a pasta é aberta nível por nível, sem seguir link simbólico, e percorrida pelo descritor dela, como na aba Arquivos. Os arquivos saem em lotes de 1.000, com uma pausa entre um lote e outro, para o disco e os pedidos do painel seguirem atendidos.
- **Dois usuários na mesma pasta com a mesma regra:** a pasta é percorrida uma vez por passada.
- **Trocar a pasta do usuário desliga a regra dele:** ela foi ligada olhando a pasta anterior. A lista de usuários volta com o aviso, e a regra precisa ser gravada de novo. Remover o usuário tira o nome dele da `limites.lista`.
- **Pelo terminal:** `docker compose exec painel python3 /opt/painel/servidor.py --retencao --simular` mostra, por usuário, quantos arquivos e bytes sairiam agora, sem apagar nada; sem o `--simular`, faz a passada na hora. O `./manage-user.sh retencao <usuario>` mostra e grava a regra: veja [Operação](operacao.md#usuarios).
- **Auditoria:** `retencao_alterada`, com o administrador, o usuário e a regra; `retencao_aplicada`, a cada passada em que algo saiu ou falhou, com o usuário, a pasta, os arquivos, as pastas, os bytes, os erros e a regra; `retencao_falhou`, quando uma passada não termina. As duas últimas não têm endereço: quem fez foi o painel.

</details>

<details>
<summary>Detalhe técnico — a remoção com a pasta</summary>

- `POST /usuarios/remover` com o campo `apagar_pasta=sim` pede também o campo `senha_atual`, a senha de quem está na sessão. Senha errada ou em branco recebe `403`, grava `admin_senha_atual_recusada` e conta como erro de entrada: cinco bloqueiam o endereço por 15 minutos (`429`). Nada é removido.
- Usuário sem pasta dentro de `DATA_DIR/dados`, ou com a pasta alcançada por outro usuário (a mesma, uma de dentro ou uma de fora), recebe `409` e nada é removido.
- A ordem é fixa: primeiro a conta sai do cadastro, pelo `allsafe-ftp-user`, depois a pasta é apagada. Se a conta não sair, a pasta não é tocada.
- A pasta é apagada como na aba Arquivos, com os mesmos limites por pedido: veja [Arquivos e download](#arquivos). Pasta grande demais para um pedido fica apagada em parte, com a conta já removida, e a tela aponta a aba Arquivos para terminar.
- A auditoria grava `usuario_removido`, com `pasta=<pasta>`, e `item_apagado`, com a quantidade de itens e o `usuario=` que era o dono.

</details>

A linha de comando continua valendo: painel e `manage-user.sh` alteram as mesmas contas. Veja [Operação](operacao.md#usuarios).

---

<a name="arquivos"></a>

## 📁 Arquivos e download

A aba Arquivos mostra as pastas de `DATA_DIR/dados`, entrega pelo navegador qualquer arquivo que um equipamento enviou, recebe arquivo para a pasta aberta, cria pasta, troca o nome e apaga arquivo e pasta. O envio de todo dia, o do equipamento, continua sendo por FTP; o do painel serve para o arquivo avulso, mandado do navegador: veja [Enviar arquivo pelo painel](#enviar-arquivo).

1. Abra a aba **Arquivos**. O primeiro nível tem as pastas dos usuários e as criadas pelo painel. Na aba Usuários, o endereço da coluna **Pasta** abre direto a pasta daquele usuário.
2. Clique no nome de uma pasta para entrar. O caminho no alto da lista mostra onde você está e volta a qualquer nível.
3. Clique em **Baixar** na linha do arquivo. O navegador salva o arquivo com o nome original.
4. Para criar uma pasta, entre na pasta onde ela vai ficar, escreva o nome em **Nova pasta** e clique em **Criar pasta**.
5. Para enviar um arquivo, entre na pasta onde ele vai ficar, escolha o arquivo no cartão **Enviar arquivo** e clique em **Enviar arquivo**. Para gravar com outro nome, preencha **Gravar com o nome**.
6. Para prender um usuário a uma pasta, entre nela e clique em **Novo usuário nesta pasta**: o cadastro abre com o campo **Pasta** preenchido.
7. Para trocar o nome de um arquivo ou de uma pasta, clique em **Renomear** na linha dele, escreva o nome novo, digite a sua senha atual e clique em **Trocar nome**. O item continua na mesma pasta.
8. Para apagar um arquivo ou uma pasta, clique em **Apagar** na linha dele, marque a caixa de confirmação, digite a sua senha atual e clique em **Apagar de vez**.
9. Para mandar um arquivo ao bot do Telegram, ao remoto do rclone ou ao S3 na hora, clique em **Telegram**, em **rclone** ou em **S3** na linha dele. Os botões aparecem depois que o destino é gravado: veja [Destinos](#destinos).

**Resultado esperado:** o arquivo salvo é idêntico ao que o equipamento enviou, e a aba Log ganha a linha `Arquivo baixado`, com o administrador, o caminho e o tamanho. A pasta criada aparece na lista com o aviso `Pasta criada.`, vazia, já com o dono e a permissão que o FTP usa, e fica na aba Log como `Pasta criada`. O arquivo enviado aparece na lista com o aviso `Arquivo enviado.`, com o dono e a permissão dos arquivos que chegam por FTP, e fica na aba Log como `Arquivo enviado pelo painel`. O item renomeado aparece com o nome novo e o aviso `Nome trocado.`, com o mesmo conteúdo, dono e permissão; o apagado some da lista com o aviso `Apagado.`. Os dois ficam na aba Log, como `Arquivo ou pasta renomeado` e `Arquivo ou pasta apagado`.

> ⚠️ **Apagar não tem volta.** O painel não tem lixeira: a pasta sai com tudo o que tem dentro, e o que foi apagado só volta do [backup](backup.md). A tela de confirmação mostra o caminho e, para pasta, quantos arquivos ela tem.

| Na lista | O que aparece | O que dá para fazer |
|---|---|---|
| Pasta | Nome e data da última alteração; dentro dela, a linha `Pasta do usuário do FTP` diz de quem é | Entrar, pelo nome ou pelo botão **Abrir**, renomear e apagar |
| Arquivo | Nome, tamanho e data da última alteração | Baixar, renomear e apagar; com um destino gravado, enviar ao bot do Telegram, ao remoto do rclone ou ao S3 |
| Item marcado `link simbólico` ou `arquivo especial` | Nome e data | Renomear e apagar; o painel não abre nem baixa, e mostra **não abre aqui** no lugar do botão. Apagar um link simbólico apaga só o link, nunca aquilo para onde ele aponta |

Limites:

- O nome da pasta nova tem letras, números, `_`, `-` e ponto, não começa com ponto e vai até 64 caracteres. Uma pasta por vez: para criar `clientes/olt-01`, crie `clientes`, entre nela e crie `olt-01`.
- O nome novo de um item renomeado segue a mesma regra. Renomear não muda o item de pasta e não substitui outro: nome que já existe na pasta é recusado. A troca pede a senha atual de quem está na sessão, como o apagamento.
- **Pasta de usuário do FTP não é renomeada nem apagada pela aba Arquivos**, nem a pasta que tem a de um usuário dentro: o cadastro deixaria de apontar para uma pasta que existe. O que está dentro dela pode ser renomeado e apagado. Para tirar a pasta inteira, remova o usuário com a caixa **Apagar também a pasta**, em [Usuários pelo painel](#usuarios); para mudar o nome, crie a pasta nova e troque a do usuário em **Editar**.
- Um pedido de apagar remove até **50.000 itens** ou trabalha por até **20 segundos**. Pasta maior que isso é apagada em parte: a tela `Apagado em parte` diz quantos itens saíram e traz o botão para repetir, com a confirmação e a senha de novo.
- **Um apagamento por vez** em todo o painel. O segundo, pedido enquanto o primeiro trabalha, recebe a tela `Nada foi apagado` (`503`), com o aviso de que o painel já está apagando outra pasta: espere e repita.
- Até **8 downloads ao mesmo tempo**, somando administradores e usuários do FTP. O nono recebe a tela `Muitos downloads ao mesmo tempo` (`503`): espere um terminar e repita.
- A lista mostra até **2000 itens** por pasta, com um aviso quando há mais. Pasta maior que isso é consultada por FTP.
- O download **não é retomado**: se a conexão cair, começa de novo.
- Conexão que recebe menos de cerca de 4 KiB por segundo é cortada, e o download aparece na aba Log como `Download interrompido`.

<a name="enviar-arquivo"></a>

**Enviar arquivo pelo painel.** O cartão **Enviar arquivo** fica embaixo da lista e grava na pasta que está aberta. O administrador sempre envia, pela aba Arquivos. O usuário do FTP envia pela tela dele, e só com a caixa **Permitir que este usuário envie arquivo pelo painel** marcada nos [limites](#limites) dele; a permissão serve para os perfis Só envio, Envio e Completo, e o perfil Leitura não envia.

| Regra | Como funciona |
|---|---|
| Tamanho | Até `PAINEL_ENVIO_MAX_MB` por arquivo, 1024 MB no padrão; o cartão mostra o teto em vigor. Arquivo maior vai por FTP. Veja [Configuração](configuracao.md#painel) |
| Nome | O do arquivo escolhido ou o do campo **Gravar com o nome**: letras, números, `_`, `-` e ponto, não começa com ponto, até 64 caracteres |
| Nome que já existe | Nunca é substituído: o envio é recusado. No perfil Só envio, que não vê a pasta, o arquivo novo é guardado com a data e a hora no nome (`-AAAAMMDD-HHMMSS` antes da extensão) e a tela avisa |
| Dono e permissão | Os mesmos dos arquivos que chegam por FTP: o arquivo enviado pelo painel é lido, baixado e apagado como qualquer outro |
| Taxa | A taxa de envio do usuário vale também aqui; o administrador envia sem teto |
| Ao mesmo tempo | Um arquivo por vez por usuário do FTP e até 4 em todo o painel |
| Envio que cai no meio | Nada fica na pasta: o arquivo só ganha nome depois de chegar inteiro. O envio não é retomado: repita |

| A tela responde | Motivo | O que fazer |
|---|---|---|
| `Envio não permitido` (`403`) | A conta do FTP não tem a permissão de enviar pelo painel | Um administrador marca a caixa em Usuários ➜ **Editar** ➜ **Limites** |
| `Nenhum arquivo escolhido` (`400`) | O formulário foi enviado sem arquivo | Escolha o arquivo e envie de novo |
| `Nome não aceito` (`400`) | O nome do arquivo está fora da regra | Troque o nome do arquivo ou preencha **Gravar com o nome** |
| `Nome já usado` (`409`) | Já existe pasta ou arquivo com o nome, e nada foi substituído | Envie com outro nome, ou apague ou renomeie o que está lá |
| `Arquivo grande demais` (`413`) | O arquivo passa do teto | Envie por FTP, ou aumente `PAINEL_ENVIO_MAX_MB` e rode o `deploy.sh` |
| `Muitos envios ao mesmo tempo` (`503`) | A conta já está enviando um arquivo, ou o painel já recebe 4 | Espere terminar e repita |
| `Sem espaço` (`507`) | O servidor não tem espaço livre para o arquivo | Libere espaço em `DATA_DIR/dados` e repita |
| `Arquivo não gravado` (`500`) | O sistema recusou a gravação | Confira a aba Log e o log do painel: veja [Solução de problemas](solucao-de-problemas.md) |

**Resultado esperado:** a pasta volta com o aviso `Arquivo enviado.` e o arquivo na lista; no perfil Só envio, a tela volta com `Arquivo enviado.` ou, quando o nome já existia, com `Arquivo enviado. Já havia um com este nome: o novo foi guardado com a data e a hora no nome.`.

<details>
<summary>Detalhe técnico — como o painel abre, entrega e recebe o arquivo, cria a pasta, renomeia e apaga</summary>

- **Rotas:** `GET /arquivos?pasta=<caminho>` lista e `GET /arquivos/baixar?arquivo=<caminho>` entrega. `POST /arquivos/pasta` cria uma pasta, com os campos `pasta` (onde) e `nome` e o token CSRF. `GET /arquivos/renomear?item=<caminho>` e `GET /arquivos/apagar?item=<caminho>` mostram a tela de cada ação; `POST /arquivos/renomear` leva os campos `item`, `nome` e `senha_atual`, e `POST /arquivos/apagar`, os campos `item`, `confirmar=sim` e `senha_atual`, os dois com o token CSRF. `POST /arquivos/enviar` recebe um arquivo. Todas exigem sessão de administrador; sem sessão, o pedido vai para a tela de entrada.
- **Caminho:** sempre relativo a `DATA_DIR/dados` (`/data` no container). Caminho com parte `..`, `.` ou vazia, com byte nulo, com parte de mais de 255 bytes ou com mais de 4096 caracteres recebe `400` e o evento `recusa_caminho`.
- **Abertura:** o painel abre a pasta dos dados e depois cada parte do caminho em relação à anterior, só para leitura e sem seguir link simbólico (`O_RDONLY`, `O_NOFOLLOW`). O que foi conferido é o mesmo que fica aberto: trocar uma pasta por um link no meio do pedido não muda o que é lido. Link simbólico em qualquer nível, mesmo apontando para dentro da própria pasta, recebe `403` e o evento `recusa_caminho`.
- **Pasta nova:** a pasta de destino é aberta do mesmo jeito que na listagem, e a nova é criada em relação a ela (`mkdir` pelo descritor da pasta aberta), com dono `ftpdata` e modo `0750`, os mesmos das pastas criadas pelo FTP. Nome fora da regra, com `/`, `..` ou byte nulo, recebe `400` e o evento `recusa_caminho`; destino que passa por link simbólico, `403`; destino que não existe, `404`; nome já usado por pasta, arquivo ou link, `409`.
- **Envio:** `POST /arquivos/enviar`, em `multipart/form-data`, com os campos `csrf`, `pasta` e `nome` antes e o arquivo por último. Só essa forma é aceita: outra recebe `400` (`Envio malformado.`), e pedido que não é `multipart/form-data`, `415`. A origem, a sessão e o token são conferidos antes de o arquivo ser lido, e o tamanho dele sai do `Content-Length`. O arquivo é escrito sem nome na própria pasta de destino (`O_TMPFILE`), em blocos, sem ficar inteiro na memória nem passar por arquivo temporário; recebe o dono `ftpdata` e o modo `0644`, vai para o disco (`fsync`) e só então ganha o nome, por `link()`. Nome que já existe faz o `link()` falhar, e a resposta é `409`; envio cortado não deixa resto na pasta, responde `400` e grava `envio_interrompido`. Antes de receber, o painel compara o tamanho com o espaço livre da pasta (`507`). Até 4 envios ao mesmo tempo; o seguinte recebe `503` com `Retry-After: 30`.
- **Envio no nginx:** só `/arquivos/enviar` e `/meus-arquivos/enviar` aceitam corpo grande, de até `PAINEL_ENVIO_MAX_MB` mais 1 MB; nas outras rotas o limite é o dos formulários. O nginx repassa o corpo ao painel enquanto ele chega, sem gravar em disco (`proxy_request_buffering off`), e espera até 300 segundos por dado. Corpo acima do teto é recusado pelo nginx com `413` e um texto curto, antes de chegar ao painel; envio sem tamanho declarado, em pedaços, recebe `411`.
- **Renomear:** a pasta onde o item está é aberta do mesmo jeito que na listagem, e a troca é feita em relação a ela, por uma chamada só (`renameat2` com `RENAME_NOREPLACE`): se o nome novo já existe, o sistema recusa, e não há intervalo em que outro processo possa colocar algo no lugar. Sistema de arquivos que não aceita essa opção cai na conferência seguida da troca. Nome novo fora da regra recebe `400` e o evento `recusa_caminho`; nome igual ao atual ou já usado, `409`; caminho por dentro de link simbólico, `403`; item que não existe, `404`. A senha atual de quem está na sessão é conferida depois do nome e antes da troca, do mesmo jeito que no apagamento: errada ou em branco, `403`, o evento `admin_senha_atual_recusada` e um erro de entrada a mais para o endereço.
- **Apagar:** pede a caixa `confirmar=sim` (`400` sem ela) e a senha atual de quem está na sessão: senha errada ou em branco recebe `403`, grava `admin_senha_atual_recusada` e conta como erro de entrada, e cinco erros bloqueiam o endereço por 15 minutos (`429`). A pasta é esvaziada de dentro para fora, sempre pelo descritor da pasta aberta e sem seguir link simbólico (`O_NOFOLLOW`): um link dentro dela é apagado como link, e o que está do outro lado dele não é tocado, esteja dentro ou fora de `DATA_DIR/dados`. O painel desce até 64 pastas uma dentro da outra.
- **Limites do apagamento:** 50.000 itens ou 20 segundos por pedido, abaixo dos 30 segundos que o nginx espera pelo painel. Ao bater em um deles, o painel para, responde `200` com a tela `Apagado em parte` e grava `item_apagado` com `completo=nao`. Um apagamento por vez: o segundo recebe `503` com `Retry-After: 30`. Item que não pôde ser removido (permissão, erro de disco) para o pedido com a tela `Nada foi apagado` (`500`) ou `Apagado em parte`.
- **Pasta de usuário:** antes de renomear ou apagar, o painel relê o cadastro do FTP. Se o item é a pasta de um usuário, ou tem a pasta de um usuário dentro, a tela e o `POST` respondem `409`, com os nomes dos usuários.
- **Campo `item`:** vai na tela codificado em percentual e volta do mesmo jeito, para o nome com byte fora do UTF-8 chegar inteiro ao painel.
- **Só arquivo comum no download:** FIFO, soquete e dispositivo aparecem na lista como `arquivo especial`, sem o botão de baixar, e o pedido direto de download recebe `404`.
- **Entrega:** `Content-Type: application/octet-stream` e `Content-Disposition: attachment`, com o nome em duas formas (RFC 6266 e RFC 8187): reduzido a ASCII e inteiro, em UTF-8. Com o `nosniff` e a `Content-Security-Policy` de toda resposta, o navegador salva o arquivo e nunca o abre, mesmo que seja uma página HTML.
- **Memória e disco:** o arquivo sai em blocos de 64 KiB, sem ser carregado na memória. O nginx repassa no ritmo do navegador, sem gravar arquivo temporário (`proxy_max_temp_file_size 0`), então o tamanho do arquivo não é limitado pelo `/tmp` do container.
- **Sem retomada:** a resposta leva `Accept-Ranges: none` e o painel ignora o cabeçalho `Range`.
- **Só os cabeçalhos (`HEAD`):** o pedido `HEAD` do mesmo endereço devolve o tamanho e o nome do arquivo, sem o conteúdo. Não ocupa vaga de download nem entra na auditoria.
- **Ritmo mínimo:** cada bloco tem 15 segundos para sair; passado isso, o painel fecha a conexão e libera a vaga do download.
- **Nome fora do UTF-8:** aparece na lista com o sinal de substituição no lugar do byte inválido, e é baixado do mesmo jeito.
- **Auditoria:** `pasta_criada` registra o administrador e o caminho; `arquivo_enviado`, quem enviou, o caminho e os bytes; `envio_interrompido`, o envio que parou antes do fim; `item_renomeado`, o administrador, o tipo (`arquivo`, `pasta`, `link` ou `especial`) e os caminhos de antes e de depois; `item_apagado`, o administrador, o tipo, o caminho e a quantidade de itens removidos; `arquivo_baixado` e `arquivo_interrompido` registram quem baixou, o caminho e os bytes entregues; o conteúdo do arquivo nunca é registrado.

</details>

---

<a name="usuario-ftp"></a>

## 📥 Usuário do FTP no painel

O dono dos arquivos pega os próprios backups pelo navegador, sem depender de quem administra: entra no mesmo endereço do painel, com **o nome e a senha do FTP**, e vê uma tela só, **Meus arquivos**, com a pasta dele e o que o [perfil](#perfis) dele deixa fazer. Não há conta nova para criar nem senha nova para guardar.

1. Abra o endereço do painel, de uma rede que esteja em `PAINEL_REDES_PERMITIDAS`.
2. Digite o usuário e a senha do FTP, os mesmos que o equipamento usa. A entrada leva alguns segundos: quem confere a senha é o próprio servidor FTP.
3. Na tela **Meus arquivos**, clique no nome de uma pasta, ou em **Abrir**, para entrar; o caminho no alto da lista volta a qualquer nível, a partir de **Início**.
4. Clique em **Baixar** na linha do arquivo. O navegador salva o arquivo com o nome original.
5. Com o perfil Envio ou Completo, o cartão **Nova pasta**, abaixo da lista, cria uma pasta vazia dentro da que está aberta.
6. Com a permissão de envio pelo painel, dada pelo administrador, o cartão **Enviar arquivo** grava um arquivo na pasta que está aberta: veja [Enviar arquivo pelo painel](#enviar-arquivo).
7. Com o perfil Completo, cada linha tem **Renomear** e **Apagar**. Os dois pedem a senha do FTP da própria conta; apagar pede também a caixa de confirmação, e não tem lixeira.
8. Clique em **Sair** ao terminar.

**Resultado esperado:** o arquivo salvo é idêntico ao que o equipamento enviou, e a aba Log, que só o administrador vê, ganha as linhas `Entrada` e `Arquivo baixado`, com o nome do usuário do FTP, o caminho e o tamanho. Pasta criada, arquivo enviado, nome trocado e item apagado ganham a linha deles, com o mesmo usuário.

| O usuário do FTP | No painel |
|---|---|
| Vê | Só a pasta do cadastro dele e o que há dentro dela: nome, tamanho e data. O caminho da pasta no servidor não aparece |
| Faz | Leitura: navega e baixa. Envio: também cria pasta. Completo: também troca o nome e apaga, do jeito da [aba Arquivos](#arquivos) e só dentro da pasta dele. Só envio: não vê arquivo nenhum; a tela dele, **Envio de arquivos**, mostra o endereço, a porta e o modo para enviar por FTP. Enviar arquivo é por FTP, até onde o [perfil](#perfis) deixa, e também pelo painel quando o administrador dá à conta a [permissão de envio](#enviar-arquivo): nos perfis Envio e Completo, para a pasta aberta; no Só envio, pela tela dele, sem ver o que já está guardado |
| Não alcança | Nenhuma aba de administração: Usuários, Arquivos de todos, Servidor, Segurança, Bloqueios e Log respondem `404` para ele. A ação que o perfil não tem responde `404` também |
| Divide com outro usuário | Só o que já divide no FTP: quem tem a mesma pasta, ou uma pasta dentro da outra, vê pelo painel os mesmos arquivos que vê por FTP |

Regras:

- Entra todo usuário do cadastro do FTP, inclusive o usuário inicial (`FTP_USER`), com a senha que vale no FTP naquele momento.
- A sessão acompanha o cadastro: trocar a senha, a pasta, o perfil ou um limite do FTP do usuário, ou removê-lo, pelo painel ou pelo `manage-user.sh`, encerra as sessões dele no pedido seguinte. Dar ou tirar a permissão de envio pelo painel e gravar a limpeza automática não encerram a sessão.
- Nome igual ao de um administrador entra **só** como administrador, com a senha de administrador. Se um administrador é criado com o nome de um usuário do FTP, a sessão desse usuário é encerrada e ele deixa de entrar no painel; por FTP, nada muda.
- **Apagar e trocar o nome pedem a senha do FTP** de quem está na sessão, conferida pelo servidor FTP como na entrada: senha errada ou em branco recebe `403`, grava `usuario_senha_atual_recusada` e conta como erro de entrada. Os limites do apagamento são os da [aba Arquivos](#arquivos).
- **Enviar pelo painel depende da permissão da conta**, lida a cada envio: o administrador dá ou tira, e vale na hora. Sem ela, o cartão **Enviar arquivo** não aparece e o pedido direto recebe `403` e o evento `recusa_envio`. As regras do envio são as de [Enviar arquivo pelo painel](#enviar-arquivo): um arquivo por vez por conta, na taxa de envio dela.
- **Pasta de outro usuário** dentro da dele não tem o nome trocado nem é apagada por ele (`409`); a tela não diz de quem é a pasta. O que está dentro dela ele altera item por item, como já faz por FTP.
- Até **3 sessões** por usuário do FTP: a quarta entrada encerra a mais antiga. Até **2 downloads ao mesmo tempo** por usuário, ou o número que o administrador gravou nos [limites](#limites) dele; o seguinte recebe a tela `Muitos downloads ao mesmo tempo` (`503`).
- Os [limites](#limites) do usuário valem aqui também: os downloads saem na taxa de download dele, e fora do horário dele, ou com todas as sessões dele no FTP ocupadas, a entrada é recusada.
- Cinco erros de usuário ou senha em 15 minutos bloqueiam o endereço, do mesmo jeito que na entrada do administrador.
- Com o servidor FTP parado, quem já entrou continua navegando, baixando, enviando e criando pasta; trocar nome e apagar respondem `503`, porque a senha não pode ser conferida, e ninguém novo entra com conta do FTP. O administrador entra normalmente.

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
- **Tempo da entrada:** o hash do cadastro é `argon2id`, e o servidor FTP leva menos de 1 segundo para conferir uma senha gravada com o custo do porte e de 3 a 6 segundos a mais, sorteados, para recusar. O painel repassa esse tempo. Como só o nome que existe tem a senha conferida, ele demora um pouco mais para ser recusado que o nome que não existe, a mesma diferença que se mede direto na porta do FTP ([Segurança](seguranca.md#custo-das-senhas)); a tela e o código da resposta são os mesmos nos dois casos.
- **Limites da conferência:** duas conferências por vez, com até 5 segundos de espera pela vez e 15 segundos por etapa da conversa. Sem resposta nesse prazo, servidor fora do ar, lotado ou com outro certificado, a entrada é recusada com `401`, conta como erro e fica na auditoria como `entrada_falha conferencia=ftp_indisponivel`.
- **Sessão:** guarda o nome, a pasta do cadastro, o perfil e o resumo SHA-256 da linha inteira do usuário em `/auth/pureftpd.passwd`, lidos antes e depois da conferência, que têm de ser iguais. A cada pedido, o painel relê a linha: se mudou, se sumiu, se o nome virou de administrador ou se a entrada foi desligada, a sessão é encerrada, o cookie é apagado e o evento `sessao_encerrada` registra o usuário e o motivo (`cadastro_alterado`, `nome_de_administrador` ou `acesso_desligado`).
- **Rotas:** cada perfil tem a tabela de rotas dele, escolhida pelo perfil guardado na sessão. Leitura: `GET /` (leva a `/meus-arquivos`), `GET /meus-arquivos?pasta=<caminho>`, `GET /meus-arquivos/baixar?arquivo=<caminho>` e `POST /sair`. Envio: mais `POST /meus-arquivos/pasta` e `POST /meus-arquivos/enviar`. Completo: mais `GET` e `POST` em `/meus-arquivos/renomear` e em `/meus-arquivos/apagar`. Só envio: `GET /`, `GET /meus-arquivos`, que mostra a tela Envio de arquivos sem ler pasta nenhuma, `POST /meus-arquivos/enviar` e `POST /sair`. A rota de envio existe para o perfil, e a permissão da conta é conferida a cada pedido. Qualquer outra rota responde `404`; quando é uma rota de administração ou de outro perfil, fica o evento `recusa_papel`, com o usuário, o caminho e o perfil. Para o administrador, `/meus-arquivos` não existe.
- **Ações:** são as mesmas funções da aba Arquivos, com a pasta do cadastro como raiz: token do formulário, conferência de `Origin`, nome novo validado, sem trocar o item de pasta nem substituir outro, e apagamento de dentro para fora sem seguir link simbólico.
- **Senha na confirmação:** o servidor FTP confere a senha, e o painel só a aceita se a linha do cadastro for a mesma com que a sessão foi aberta. Sem resposta do servidor FTP, responde `503`, grava `falha_comando` com `acao=confirmar_senha` e nada é apagado nem tem o nome trocado.
- **Caminho:** sempre relativo à pasta do cadastro, que é a raiz dele. Passa pelas mesmas conferências da [aba Arquivos](#arquivos): parte por parte, sem `..`, sem seguir link simbólico, só arquivo comum, entrega como anexo, em blocos e sem retomada. Na auditoria, o caminho vai inteiro, a partir da pasta dos dados.
- **Pasta ainda não criada:** a pasta de um usuário novo nasce no primeiro login por FTP; antes disso, a tela mostra a lista vazia.
- **Sessões cheias:** quando o painel chega ao teto de 50 sessões, sai primeiro a sessão menos usada de usuário do FTP; a entrada de um usuário não derruba a de um administrador.

</details>

---

<a name="destinos"></a>

## ☁️ Destinos: S3, rclone e bot do Telegram

Na aba **Destinos**, o administrador liga pastas dos dados a lugares fora do servidor, e o painel passa a enviar sozinho o que chega nelas. São três tipos de destino: o **armazenamento S3**, para ter a segunda cópia ou para guardar os arquivos fora e liberar o disco, o **remoto do rclone**, para o que o S3 não alcança (um servidor SFTP ou WebDAV, ou uma nuvem de arquivos), e o **bot do Telegram**, que entrega cada arquivo novo a uma pessoa, a um grupo ou a um canal. Cada tipo aceita até 20 destinos, cada um com a pasta, o intervalo e os segredos dele, e um não depende do outro. A aba vem sem nenhum: enquanto o administrador não gravar um, nada sai do servidor. Só administrador abre a aba.

| Destino | O que envia | Quando | O que fica no servidor |
|---|---|---|---|
| Armazenamento S3 | Todos os arquivos da pasta escolhida e das pastas de dentro dela, inclusive os que já estavam lá quando o destino foi ligado | A cada intervalo gravado, de 5 a 1440 minutos | Em **Copiar**, tudo; em **Guardar no S3**, o arquivo sai depois que o destino confirma a gravação |
| Remoto do rclone | Todos os arquivos da pasta escolhida e das pastas de dentro dela, inclusive os que já estavam lá quando o destino foi ligado | A cada intervalo gravado, de 5 a 1440 minutos | Tudo: o remoto só recebe |
| Bot do Telegram | Só os arquivos que chegarem depois de o destino ser ligado, um por mensagem, com o caminho, o tamanho e a data | Em poucos segundos, quando o arquivo chega inteiro por FTP ou pelo painel; o que aparece na pasta de outro jeito, a cada intervalo gravado, de 5 a 1440 minutos | Tudo: o bot nunca apaga |

<details>
<summary>Fluxograma do envio aos destinos, com a sequência escrita — clique para expandir</summary>

<!-- diagrama: diagramas/destinos-fluxograma.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    subgraph ORIGEM["Origem"]
        equip@{ shape: hex, label: "Equipamento de rede<br>cliente FTP" }
    end
    subgraph SERVIDOR["Servidor · container painel"]
        pasta@{ shape: lin-cyl, label: "pasta enviada<br>DATA_DIR/data" }
        passada@{ shape: rect, label: "passada do destino<br>painel/destinos.py" }
        inteiro@{ shape: diam, label: "arquivo<br>chegou inteiro?" }
        https@{ shape: rect, label: "saída por HTTPS<br>painel/saida.py" }
        rclone@{ shape: rect, label: "rclone<br>painel/rclone.py" }
        andamento@{ shape: cyl, label: "andamento do destino<br>DATA_DIR/painel/destinos" }
        segredos@{ shape: docs, label: "segredos do destino<br>SECRETS_DIR/destinos, 0600" }
    end
    subgraph FORA["Fora do servidor"]
        bot@{ shape: cloud, label: "bot do Telegram<br>conversa que recebe" }
        s3@{ shape: bucket, label: "bucket S3<br>Copiar ou Guardar no S3" }
        remoto@{ shape: cloud, label: "remoto do rclone<br>SFTP, WebDAV ou nuvem" }
    end
    subgraph RESULTADO["Resultado"]
        confirmou@{ shape: diam, label: "o destino<br>confirmou?" }
        enviado@{ shape: stadium, label: "arquivo enviado<br>uma vez só" }
        parou@{ shape: stadium, label: "passada encerrada<br>motivo no cartão" }
        depois@{ shape: stadium, label: "ainda chegando<br>fica para a próxima" }
    end

    equip -- "1 · envia o arquivo, FTP" --> pasta
    pasta -- "2 · lida a cada intervalo" --> passada
    passada -- "3 · confere cada arquivo novo" --> inteiro
    inteiro -- "4a · não" -----> depois
    inteiro -- "4b · sim: bot e S3" --> https
    inteiro -- "4c · sim: remoto do rclone" --> rclone
    https -- "5a · envia a mensagem, HTTPS" ---> bot
    https -- "5b · grava o objeto, HTTPS" ---> s3
    rclone -- "5c · grava o arquivo, HTTPS ou SSH" ---> remoto
    bot -- "6a · responde" --> confirmou
    s3 -- "6b · responde" --> confirmou
    remoto -- "6c · responde" --> confirmou
    confirmou -- "7a · sim: anota e segue" --> enviado
    confirmou -- "7b · não: para" --> parou
    passada -. "lê a configuração e grava o andamento" .-> andamento
    https -. "lê as chaves e o token" .-> segredos
    rclone -. "lê o acesso do remoto" .-> segredos
```

<sub>Nível 2 · Mapa · [fonte](diagramas/)</sub>

| Nº | De ➜ Para | O que acontece |
|---|---|---|
| 1 | Equipamento de rede ➜ pasta enviada | O arquivo chega por FTP, ou pelo envio do painel, à pasta que o destino envia |
| 2 | pasta enviada ➜ passada do destino | A cada intervalo gravado, ou pelo botão **Enviar agora**, o painel lê a pasta e as pastas de dentro dela |
| 3 | passada do destino ➜ arquivo chegou inteiro? | O painel confere, na ordem da chegada, cada arquivo que o destino ainda não recebeu |
| 4a | arquivo chegou inteiro? ➜ ainda chegando | Não: o arquivo mudou há menos de dois minutos e fica para uma próxima passada |
| 4b | arquivo chegou inteiro? ➜ saída por HTTPS | Sim, com bot ou S3: o pedido sai por HTTPS, com o certificado e o endereço conferidos. O bot não espera os dois minutos do arquivo que o FTP ou o painel avisou que terminou de chegar |
| 4c | arquivo chegou inteiro? ➜ rclone | Sim, com remoto do rclone: o painel chama o rclone, um arquivo por vez, só para gravar |
| 5a | saída por HTTPS ➜ bot do Telegram | O bot entrega o arquivo à conversa, em uma mensagem; acima do limite do bot vai só o aviso |
| 5b | saída por HTTPS ➜ bucket S3 | O painel grava o objeto no bucket, em partes quando é grande |
| 5c | rclone ➜ remoto do rclone | O rclone grava o arquivo na pasta do remoto, por HTTPS ou, no SFTP, por SSH com a chave do servidor conferida |
| 6a | bot do Telegram ➜ o destino confirmou? | O serviço do bot responde ao pedido |
| 6b | bucket S3 ➜ o destino confirmou? | O serviço do S3 responde ao pedido |
| 6c | remoto do rclone ➜ o destino confirmou? | O rclone termina e diz se gravou |
| 7a | o destino confirmou? ➜ arquivo enviado | Sim: o painel anota o arquivo como enviado e segue para o próximo; com **Guardar no S3**, o arquivo sai do servidor depois de entregue por todos os destinos que o levam |
| 7b | o destino confirmou? ➜ passada encerrada | Não: a passada para, o cartão mostra o motivo e a seguinte recomeça do mesmo arquivo |

**Apoio**

| Quem | Usa | Como |
|---|---|---|
| passada do destino | andamento do destino (`DATA_DIR/painel/destinos`) | lê a configuração e grava até onde o envio foi |
| saída por HTTPS | segredos do destino (`SECRETS_DIR/destinos`) | lê as chaves do S3, o token do bot e a conversa |
| rclone | segredos do destino (`SECRETS_DIR/destinos`) | lê o acesso do remoto e trabalha em uma cópia dele |

</details>

**Armazenamento S3.** Serve qualquer serviço que fale o protocolo do S3, na nuvem ou na rede interna. Antes de começar, crie o bucket no serviço e uma chave que só possa gravar nele.

1. Na aba Destinos, clique em **Configurar** no cartão **Armazenamento S3**.
2. Preencha o **Endereço do serviço** (`https://nome` ou `https://nome:porta`, sem o bucket), a **Região**, o **Bucket** e, se quiser, o **Prefixo**, que é a pasta dentro do bucket.
3. Em **Endereço do bucket**, escolha **No caminho** (`https://nome/bucket/arquivo`) ou **No nome** (`https://bucket.nome/arquivo`), como o serviço pede.
4. Digite a **Chave de acesso** e a **Chave secreta**.
5. Preencha a **Pasta enviada** (em branco é a pasta dos dados inteira) e o **Intervalo entre as passadas**.
6. Em **Depois do envio**, escolha **Copiar** ou **Guardar no S3**.
7. Digite a sua senha e clique em **Gravar**.
8. De volta à aba, clique em **Testar**.

**Resultado esperado:** a aba volta com o aviso **Destino gravado**, e o cartão mostra a marca **ligado**, o endereço, o bucket, a pasta e que as chaves estão gravadas, sem mostrá-las. O **Testar** grava um objeto pequeno, `allsafe-ftp-stack-teste.txt`, no prefixo escolhido e responde **Teste concluído: o destino recebeu**. A primeira passada começa em até um minuto e envia tudo o que já está na pasta; a linha **Última passada** diz quantos arquivos saíram.

> ⚠️ **Guardar no S3 deixa uma cópia só:** o arquivo sai do servidor depois de gravado no destino, e o painel não tem lixeira nem baixa de volta. A primeira passada envia tudo o que já está na pasta e, com Guardar no S3, tudo isso sai do servidor. Comece em **Copiar**, confira os objetos no bucket e só então troque: a troca vale para o que for enviado dali em diante.

> ⚠️ **Trocar o endereço, o bucket, o prefixo, a forma do endereço ou a pasta recomeça do zero:** tudo o que está na pasta é enviado de novo, para o lugar novo.

**Remoto do rclone.** O rclone é o programa de envio de arquivos que vem dentro da imagem do painel, em versão fixa. Por ele, a pasta vai para um servidor **SFTP** ou **WebDAV**, ou para uma conta do **Google Drive**, do **OneDrive**, do **Dropbox** ou do **pCloud**. Tudo é preenchido na tela: o painel não pede nada no terminal do servidor.

1. Na aba Destinos, clique em **Configurar** no cartão **Remoto do rclone**.
2. Escolha o **Tipo do remoto** e clique em **Continuar**.
3. Preencha a **Pasta no remoto**, que é onde os arquivos são gravados (em branco é a pasta em que o remoto entra), a **Pasta enviada** e o **Intervalo entre as passadas**.
4. Em **Acesso do remoto**, preencha os campos do tipo escolhido, como na tabela abaixo.
5. Digite a sua senha e clique em **Gravar**.
6. De volta à aba, clique em **Testar**.

| Tipo do remoto | O que o acesso pede | Opcional |
|---|---|---|
| SFTP | **Servidor**, **Usuário** e a **Senha** ou a **Chave privada**, com a **Frase da chave privada** quando a chave é cifrada | **Porta** (em branco é a 22) e **Chave pública do servidor** (em branco, o Testar guarda a que o servidor apresentar) |
| WebDAV | **Endereço**, só HTTPS, e o **Usuário** com a **Senha**, ou o **Token de acesso** | **Programa do servidor** |
| Google Drive | **Token da conta**, ou **Credencial da conta de serviço** | **Alcance**, **Pasta de partida**, **Drive compartilhado**, **Identificação do aplicativo** e **Segredo do aplicativo** |
| OneDrive | **Token da conta**, **Identificação do drive** e **Tipo do drive** | **Região**, **Organização**, **Identificação do aplicativo** e **Segredo do aplicativo** |
| Dropbox | **Token da conta** | **Identificação do aplicativo** e **Segredo do aplicativo** |
| pCloud | **Token da conta** | **Região da conta**, **Identificação do aplicativo** e **Segredo do aplicativo** |

**Resultado esperado:** a aba volta com o aviso **Destino gravado**, e o cartão mostra a marca **ligado**, o tipo do remoto, a pasta no remoto, a pasta enviada e que o acesso está gravado, sem mostrá-lo. O **Testar** grava um arquivo pequeno, `allsafe-ftp-stack-teste.txt`, na pasta do remoto e responde **Teste concluído: o destino recebeu**. A primeira passada começa em até um minuto e envia tudo o que já está na pasta; a linha **Última passada** diz quantos arquivos saíram.

- **O remoto só recebe.** O painel pede ao rclone que grave cada arquivo, e nada mais: não lista, não baixa, não sincroniza e não apaga nada no remoto. O arquivo continua no servidor.
- **SFTP pede o Testar antes do primeiro envio.** O cartão fica com a marca **falta testar** até o teste guardar a chave que o servidor apresentar. Depois dele, a linha **Chave do servidor** mostra a impressão digital dessa chave: confira com a do servidor. Sem a chave guardada nada é enviado, e, se ela mudar depois, o envio para com o motivo na tela.
- **O token das nuvens é obtido fora do painel**, em um computador com navegador e com o rclone: o comando `rclone authorize` seguido do tipo (`drive`, `onedrive`, `dropbox` ou `pcloud`) abre a página da conta e imprime o token, que é colado no campo **Token da conta**. O painel não abre essa página. Depois de gravado, o painel guarda sozinho o token que o serviço renova.
- **O tipo fica fixo depois de gravado.** Para outro tipo, crie outro destino.
- **O acesso não volta para a tela.** Em **Alterar**, os campos do acesso em branco mantêm o gravado; para trocar qualquer parte dele, preencha o acesso inteiro de novo. No SFTP, o acesso gravado de novo sem a **Chave pública do servidor** pede outro **Testar**.
- **O caminho no remoto é o mesmo dos dados.** `backups/roteador/config.rsc`, com a pasta no remoto `copias`, vira `copias/backups/roteador/config.rsc`, e grava por cima do que tiver o mesmo nome. O arquivo de teste fica no remoto.
- **Certificado conferido.** No WebDAV e nas nuvens, o painel só fala HTTPS com o certificado conferido. Servidor WebDAV com autoridade da própria rede usa o mesmo `ca.pem` do S3, descrito mais abaixo.

> ⚠️ **Trocar a pasta no remoto, a pasta enviada ou o lugar do acesso recomeça do zero:** tudo o que está na pasta é enviado de novo, para o lugar novo. O lugar do acesso é o servidor, a porta e o usuário, no SFTP; o endereço e o usuário, no WebDAV; e, nas nuvens, a pasta de partida, o drive ou a região da conta.

**Bot do Telegram.** Antes de começar, crie o bot no criador de bots do Telegram e guarde o token que ele entrega. Ponha o bot no grupo ou no canal que vai receber; para uma pessoa, ela precisa ter iniciado a conversa com o bot.

1. Na aba Destinos, clique em **Configurar** no cartão **Bot do Telegram**.
2. Digite o **Token do bot** e a **Conversa que recebe**: o número da pessoa ou do grupo (o de grupo começa com `-`) ou o `@nome` do canal.
3. Preencha a **Pasta enviada** e o **Intervalo entre as passadas**, e escolha o **Idioma das mensagens**.
4. Digite a sua senha e clique em **Gravar**.
5. De volta à aba, clique em **Testar**.

**Resultado esperado:** a conversa recebe a mensagem de teste do painel, e a aba responde **Teste concluído: o destino recebeu**. Dali em diante, cada arquivo que chegar na pasta por FTP ou pelo painel vai para a conversa em poucos segundos, como documento, com o caminho, o tamanho e a data na legenda.

O bot **só envia**. O painel usa o envio de arquivo e o envio de mensagem da API de bot, e nada mais: não lê a conversa, não registra endereço de retorno e não aceita comando.

O maior arquivo que o bot envia de uma vez é o de [`PAINEL_TELEGRAM_MAX_MB`](configuracao.md#painel), 50 MB no padrão, que é o teto da API pública. Arquivo maior não é enviado: a conversa recebe um aviso com o caminho, o tamanho e a data, e o arquivo continua no servidor. Arquivo vazio não é enviado, porque a API não aceita.

**Vários destinos do mesmo tipo.** Depois do primeiro destino de um tipo, a aba ganha no alto o botão **Novo S3**, **Novo remoto** ou **Novo bot**, e cada cartão ganha o **Novo com o mesmo acesso**. Serve para mandar outra pasta ao mesmo bucket, a mesma pasta a outro bucket, outra pasta ao mesmo servidor pelo rclone ou outra pasta a outro grupo pelo mesmo bot.

1. No cartão do destino que já funciona, clique em **Novo com o mesmo acesso**.
2. Dê um **Nome** ao destino, para reconhecê-lo na tela.
3. Troque a **Pasta enviada** ou o lugar: o prefixo ou o bucket, no S3; a pasta no remoto, no rclone; a conversa, no bot.
4. Deixe em branco os segredos que são os mesmos, digite a sua senha e clique em **Gravar**. No rclone, o acesso é um só: em branco vale o do destino de origem inteiro e, para usar outro, ele é preenchido inteiro.

**Resultado esperado:** a aba volta com o aviso **Destino gravado** e um cartão a mais, com o tipo e o nome dado, como **Armazenamento S3: Clientes**. O segredo deixado em branco é copiado do destino de origem dentro do servidor, sem passar pelo navegador, e o **Testar** do cartão novo confirma que ele vale. O remoto SFTP criado assim leva junto a chave do servidor já guardada, e não pede outro teste.

- **Novo S3**, **Novo remoto** e **Novo bot** abrem o formulário em branco, para um destino com outras chaves, com outro remoto ou com outro bot.
- Dois destinos não levam a mesma pasta, ou uma pasta de dentro dela, ao mesmo lugar: o painel recusa com **Este destino já existe**. O mesmo lugar é o mesmo endereço, bucket e prefixo, no S3; o mesmo tipo de remoto, servidor, usuário e pasta no remoto, no rclone; e o mesmo bot com a mesma conversa, no Telegram.
- Cada tipo aceita até 20 destinos. Com os 20 gravados, os botões de destino novo somem até um ser removido.
- Cada destino tem o andamento dele: alterar, testar ou remover um não mexe nos outros.
- O bot novo envia só o que chegar depois de gravado; o S3 novo e o remoto do rclone novo enviam tudo o que já está na pasta.

**Vários destinos na mesma pasta.** Em cada passada, os bots entregam primeiro, depois os remotos do rclone, os S3 que copiam e, por último, os que guardam. Com um S3 em **Guardar no S3**, o arquivo só sai do servidor depois de gravado nele e entregue por todos os outros destinos ligados que levam aquele arquivo, bots, remotos do rclone e outros S3; enquanto algum não entrega, o cartão desse S3 mostra a linha **À espera de outro destino**.

**Os botões de cada cartão:**

| Botão | O que faz | Pede a senha |
|---|---|---|
| Testar | Grava o objeto de teste no S3 ou o arquivo de teste no remoto do rclone, ou envia a mensagem de teste pelo bot, com o que está gravado. No remoto SFTP, guarda também a chave do servidor. Funciona com o destino desligado | Não |
| Enviar agora | Pede uma passada fora de hora. O painel começa em instantes, e a tela não espera por ela: atualize para acompanhar | Não |
| Alterar | Abre o formulário com o que está gravado. Campo de segredo em branco mantém o gravado | Sim, para gravar |
| Novo com o mesmo acesso | Abre o formulário de um destino novo do mesmo tipo. Campo de segredo em branco copia o deste destino, no servidor | Sim, para gravar |
| Remover | Apaga a configuração, o andamento e os segredos deste destino, e só dele. O que já foi enviado continua lá, e nenhum arquivo do servidor é apagado | Sim |

**Enviar um arquivo na hora.** Depois que um destino é gravado, cada arquivo da aba [Arquivos](#arquivos) ganha um botão com o nome dele, **Telegram**, **rclone** ou **S3**, ao lado do **Baixar**. O botão envia aquele arquivo ao destino naquele momento, com o que está gravado.

1. Abra a aba **Arquivos** e entre na pasta do arquivo.
2. Na linha do arquivo, clique em **Telegram**, em **rclone** ou em **S3**.
3. Com mais de um destino pronto daquele tipo, escolha na tela seguinte o **Destino que recebe** e clique em **Enviar**.

**Resultado esperado:** a tela volta para a mesma pasta com o aviso **Bot do Telegram: arquivo enviado**, **Remoto do rclone: arquivo enviado** ou **Armazenamento S3: arquivo enviado**, com o nome do destino quando ele tem um. Quando o envio passa de 20 segundos, o aviso diz que ele continua em segundo plano, e o resultado aparece na aba Log. Quando não dá certo, o aviso traz o motivo em uma frase.

- O botão serve para qualquer arquivo dos dados, dentro ou fora da pasta do destino, e funciona com o destino desligado.
- O arquivo nunca é apagado por esse envio, nem com o S3 em **Guardar no S3**, e o que as passadas enviam não muda: um arquivo que ainda não saiu continua na vez dele.
- Pelo bot, o arquivo vazio e o que passa do limite não saem, e o aviso diz o motivo. Enviar de novo um arquivo que já foi entrega outra mensagem na conversa; no S3 e no rclone, grava por cima do mesmo nome.
- Um envio pedido pelo botão por vez: enquanto um não termina, o seguinte é recusado com o aviso de tentar de novo.
- Pelo rclone, o arquivo vai para a pasta no remoto com o mesmo caminho que tem dentro dos dados. Para um remoto SFTP que ainda não passou pelo **Testar**, o botão responde que falta a chave do servidor.
- Só o administrador tem o botão, e ele só aparece para o tipo que tem um destino gravado com os segredos.

**O que entra em uma passada:**

- Só arquivo comum. Link simbólico e tudo o que tem o nome começado por ponto, arquivo ou pasta, ficam de fora.
- O arquivo entra depois de dois minutos sem mudar, para o que ainda está chegando não sair pela metade. O botão **Enviar agora** respeita essa espera, e o cartão mostra na linha **Ainda chegando** quantos arquivos ficaram para uma próxima passada.
- O bot não espera os dois minutos do arquivo que o servidor FTP avisou que terminou de chegar, nem do que foi enviado pelo painel: esse sai em poucos segundos. O S3 e o remoto do rclone esperam sempre.
- O arquivo que troca de nome ou de pasta pelo FTP, e o que é copiado direto no servidor, não tem aviso de chegada: espera os dois minutos e, enquanto espera, segura os que chegaram depois dele, para a ordem não se perder.
- A ordem é a da chegada ao servidor. Uma falha do destino encerra a passada, e a seguinte recomeça do mesmo arquivo: nada é pulado nem enviado duas vezes.
- No S3, o nome do objeto é o prefixo mais o caminho do arquivo dentro dos dados: `backups/roteador/config.rsc`, com o prefixo `copias`, vira `copias/backups/roteador/config.rsc`. No rclone, a regra é a mesma, com a pasta no remoto no lugar do prefixo.
- Arquivo que troca de nome é enviado de novo, com o nome novo. Pasta que troca de nome não reenvia os arquivos de dentro.

Quando a última passada para antes do fim, o cartão mostra o motivo em uma frase. O que cada motivo quer dizer e o que fazer está em [Solução de problemas](solucao-de-problemas.md#destinos).

<a name="copia-do-sistema"></a>

**Cópia do sistema para o S3.** No alto da aba, o cartão **Cópia do sistema** manda o sistema inteiro a um dos armazenamentos S3 gravados: o painel junta as pastas `auth`, `dados`, `certs` e `painel` em um arquivo só, cifrado com a chave pública da cópia. É a mesma cópia que o [`scripts/backup.sh`](backup.md#fazer) grava em `BACKUP_DIR`, e o `scripts/restaurar.sh` a abre com a chave privada: veja [Cópia no S3, pelo painel](backup.md#no-s3). O cartão oferece o **Configurar** depois que existe um S3 com os segredos gravados.

1. No cartão **Cópia do sistema**, clique em **Configurar**.
2. Escolha o **Armazenamento S3 que recebe**.
3. Preencha a **Pasta no bucket**, que é só das cópias do sistema: `copia-do-sistema` no padrão; em branco é a raiz do bucket.
4. Em **Rotina**, digite de quantos em quantos dias a cópia é feita, de 1 a 30, e a **Hora da rotina**, na hora do servidor. Com `0`, a cópia só sai pelo botão ou pelo terminal.
5. Digite a sua senha e clique em **Gravar**.
6. De volta à aba, clique em **Copiar e enviar agora**.

**Resultado esperado:** a aba volta com o aviso **Cópia do sistema gravada. A rotina vale a partir de agora.**, e o cartão mostra o destino, o bucket e a pasta, a rotina e a marca **rotina ligada** ou **só pelo botão**. Depois do botão, o aviso é **Cópia do sistema pedida: ela é feita em segundo plano. Atualize a tela para acompanhar.** Enquanto a cópia roda, o cartão tem a marca **em andamento** e a linha **Agora**, com o tamanho e as partes já enviadas; no fim, a linha **Última cópia** traz a data, o tamanho, a quantidade de arquivos e o nome do objeto.

- Cada cópia são dois objetos na pasta escolhida: `<STACK_NAME>-AAAAMMDD-HHMMSS.tar.gz.age` e o `.sha256` dele, com a soma que a restauração confere.
- O painel só envia. Nenhuma cópia antiga é apagada: elas se acumulam no bucket, e o prazo de cada uma é o da regra de expiração do próprio bucket.
- A cópia usa o endereço, o bucket e as chaves do S3 escolhido, e funciona com esse destino desligado. A pasta dela é a do formulário da cópia, e não o prefixo do destino.
- O `.env` e os segredos da instalação não entram, nem os dos destinos: guarde-os à parte, com a chave privada da cópia, como em [Guardar o `.env` e os segredos](backup.md#segredos).
- Uma cópia por vez: com uma em andamento, o botão some do cartão, e outro pedido é recusado com o motivo.
- A cópia é feita em segundo plano, com a prioridade mais baixa, dentro do limite de processador do painel. O tempo cresce com o tamanho dos dados: marque a rotina para a hora de menos uso.
- O arquivo que muda enquanto é lido entra como foi lido, e o cartão diz quantos mudaram: é o de um envio em andamento, que pode estar incompleto na cópia.
- Quando a cópia para antes do fim, nenhum objeto fica no destino, e o cartão mostra **A última cópia, de (data), não foi concluída**, com o motivo em uma frase. A rotina tenta de novo no dia seguinte, na mesma hora.
- A cópia feita pelo botão ou pelo terminal conta para a rotina: a seguinte sai quando a última que deu certo completa os dias gravados.
- Remover o S3 que recebe a cópia deixa a cópia sem destino, e a rotina dela para: a tela de remoção avisa antes, e o cartão volta para **não configurada**.
- Só o administrador tem o cartão, o formulário e o botão.

Pelo terminal, a situação da cópia e uma cópia na hora, que só volta quando termina:

```bash
docker compose exec painel python3 /opt/painel/servidor.py --copia
docker compose exec painel python3 /opt/painel/servidor.py --copia enviar
```

**Resultado esperado:** o primeiro mostra `cópia do sistema: s3 (<bucket>/<pasta>); a cada 1 dia(s), às 03:00` e a linha `última cópia:`, ou `nenhuma cópia ainda`. O segundo termina com `cópia do sistema: s3:<bucket>/<pasta>/<objeto>; <n> bytes em <n> parte(s); <n> arquivo(s), 0 mudaram durante a leitura, 0 de fora (soquete, fila ou dispositivo); sha256 <soma>` e sai com `0`. Quando a cópia não é concluída, a linha é `cópia do sistema: falhou: <motivo>; nenhum objeto ficou no destino`, e a saída é `1`.

**Onde ficam os segredos.** As chaves de cada S3, o acesso de cada remoto do rclone e o token e a conversa de cada bot ficam no servidor, um por arquivo, na pasta `destinos` de `SECRETS_DIR`, e nunca voltam para a tela, para o Log nem para a auditoria. Como os outros segredos da instalação, não entram na [cópia de segurança](backup.md): depois de restaurar uma cópia, o cartão mostra a marca **faltam os segredos** e nada é enviado até eles serem gravados de novo, em **Alterar**.

**S3 ou WebDAV na rede interna com autoridade própria.** O painel só fala HTTPS e confere o certificado do serviço. Se o certificado do seu S3 ou do seu servidor WebDAV foi emitido por uma autoridade da própria rede, entregue o certificado dela ao painel, em PEM:

```bash
docker compose exec -T painel sh -c 'cat > /painel/destinos/ca.pem' < autoridade-da-rede.pem
```

**Resultado esperado:** o comando volta sem mensagem, e o **Testar** seguinte já aceita o certificado, sem reiniciar nada.

**Desligar tudo.** Com [`PAINEL_DESTINOS=nao`](configuracao.md#painel) no `.env` e um `./deploy.sh`, a aba sai do menu, nenhuma passada acontece e o painel não abre nenhuma conexão para fora. O que estava gravado fica guardado e volta a valer com `sim`.

<details>
<summary>Detalhe técnico — os destinos de fora</summary>

- **Rotas:** `GET /destinos` mostra um cartão por destino; `GET` e `POST /destinos/s3`, `/destinos/rclone` e `/destinos/telegram` mostram e gravam o formulário do tipo, e o campo `id` diz de qual destino: em branco, o primeiro do tipo; `novo`, um destino novo; ou o nome de um que existe. Com `id=novo`, o campo `copiar` leva o nome do destino de onde vêm os segredos deixados em branco; `POST /destinos/testar` e `POST /destinos/agora` levam o campo `destino`, com o nome do destino; `GET /destinos/arquivo` leva `tipo` e `arquivo` e mostra a escolha do destino, quando o tipo tem mais de um pronto; `POST /destinos/arquivo` leva `destino` e `arquivo`, o caminho dentro dos dados; `GET` e `POST /destinos/remover` confirmam e removem. Todo `POST` leva o token CSRF da sessão. Gravar e remover pedem também `senha_atual`, a senha de quem está na sessão: errada ou em branco recebe `403`, grava `admin_senha_atual_recusada` e conta como erro de entrada. Só administrador tem essas rotas: para o usuário do FTP, respondem `404`.
- **Formulário:** campo fora da regra responde `400`, com a tela de volta e o que foi digitado, menos os segredos, que nunca são devolvidos. A pasta precisa existir dentro dos dados. O formulário do rclone leva o campo `remoto`, com o tipo, que só vale no destino novo, e os campos do acesso, com `r_` na frente do nome; por causa da chave privada e da credencial, é a única rota que aceita corpo de até 32 KiB, e as outras continuam em 8 KiB. Nome de destino fora da regra, de outro tipo ou sem configuração responde `404`; destino repetido responde `400`, e destino novo em tipo que já tem os 20 volta para a lista (`303`) com o aviso, sem gravar nada.
- **Nomes:** o primeiro destino de cada tipo chama-se `s3`, `rclone` ou `telegram`; os seguintes, `s3-2` a `s3-20`, `rclone-2` a `rclone-20` e `telegram-2` a `telegram-20`. O destino novo recebe o menor nome livre do tipo, e o nome de um destino removido volta a ficar livre. O campo **Nome** do formulário é só o que a tela mostra, com até 40 caracteres: os arquivos, a auditoria e o terminal usam o nome fixo.
- **Quem guarda:** a configuração fica em `DATA_DIR/painel/destinos/<destino>.conf` e o andamento, em `<destino>.estado`; os dois entram na cópia de segurança. Os segredos ficam em `SECRETS_DIR/destinos`, com o modo `0600` e o nome do destino na frente: `<destino>-chave-de-acesso.txt` e `<destino>-chave-secreta.txt`, no S3; `<destino>-remoto.txt`, no rclone; e `<destino>-token.txt` e `<destino>-conversa.txt`, no bot. A cópia de acesso entre dois destinos acontece nessa pasta, de arquivo para arquivo. É a única pasta de segredos em que o painel escreve. Apagar um desses arquivos no servidor desliga o envio daquele destino na passada seguinte.
- **Quem aplica:** o [`destinos.py`](../../painel/destinos.py), em uma linha de execução do próprio painel, que colhe os avisos de chegada a cada 2 s e confere a cada minuto qual destino está na hora. Uma passada por vez, nesta ordem: os bots, os remotos do rclone, os S3 que copiam e, por último, os que guardam.
- **Chegada anunciada:** o [vigia](scripts.md#vigia) do servidor FTP grava um aviso em `/auth/chegadas`, pasta `0700` do root, para cada envio que o Pure-FTPd registra como concluído, e o envio pelo painel avisa direto. O [`chegadas.py`](../../painel/chegadas.py) colhe e apaga os avisos, e 3 s depois de um aviso novo o painel faz uma passada do bot. O aviso não escolhe o que é enviado: só dispensa a espera de um arquivo que a passada encontraria de qualquer jeito, dentro da pasta do destino. Vale por 4 minutos no painel, e o vigia apaga o que ninguém colheu em 5. Com o cadastro do FTP em uso naquele instante, ou com 2000 avisos à espera, o vigia não grava o aviso, e o arquivo sai pela espera de dois minutos. Quando a passada do bot deixa arquivo à espera, o painel volta sozinho cerca de dois minutos depois. A passada pedida pelo terminal não usa os avisos.
- **Um arquivo só:** o `POST /destinos/arquivo` abre o arquivo com as mesmas conferências da aba Arquivos (`400`, `403` ou `404` para caminho fora da regra, link simbólico, pasta ou arquivo que não existe) e envia em uma linha de execução própria. A tela espera até 20 s; depois disso, o envio segue sozinho. Não lê nem grava o andamento das passadas. Arquivo que muda durante o envio responde com o motivo, para ser repetido.
- **Saída do painel:** o [`saida.py`](../../painel/saida.py) é a única porta por onde o painel fala com alguém de fora da stack. Só HTTPS, com TLS 1.2 ou mais novo e o certificado conferido contra as autoridades da imagem e contra a de `ca.pem`, quando existe. O nome é resolvido uma vez, e a conexão vai para o endereço que foi conferido. O painel não sai para o próprio container, para endereço de enlace, de grupo ou reservado, e não segue redirecionamento. Cada operação de rede tem 30 s de prazo.
- **S3:** o [`s3.py`](../../painel/s3.py) assina cada pedido com a assinatura versão 4, com o SHA-256 do corpo dentro dela. Arquivo de até 32 MiB vai em um pedido; acima disso, em partes de 16 MiB ou mais, e o envio em partes é abandonado no destino quando falha. O painel só grava: não lê, não lista e não apaga nada no bucket, e a chave só precisa de `s3:PutObject` e `s3:AbortMultipartUpload`. A lista do que pode sair está no próprio `s3.py`: gravar um objeto, abrir, enviar e concluir um envio em partes, e desfazer um envio em partes que não terminou. Qualquer outro pedido é recusado antes de sair do painel, venha da tela, da rotina ou do terminal. Gravar de novo na mesma chave substitui o objeto: para guardar o que havia antes, ligue as versões no bucket. Arquivo maior que 5 TiB conta como ignorado.
- **rclone:** o [`rclone.py`](../../painel/rclone.py) chama o binário `/usr/local/bin/rclone` da imagem, com versão e soma SHA-256 fixas no `Dockerfile`; nada é baixado nem atualizado em execução. Do rclone saem dois subcomandos, e nenhum outro: `rcat`, que grava no remoto o que recebe pela entrada padrão, e `obscure`, que cifra a senha para o arquivo do remoto. Listar, baixar, mover, sincronizar e apagar não estão na lista e são recusados antes de existir um processo, venha o pedido da tela, da rotina ou do terminal. O arquivo do remoto é montado a partir de uma lista fechada de tipos, de campos e da forma de cada valor: o que o rclone tem de perigoso para quem escreve a configuração (comando a executar, arquivo a ler, proxy, certificado sem conferência, remoto que embrulha outro, pasta local) não está na lista. O arquivo é conferido de novo a cada leitura, pela mesma lista: alterado por fora, o destino fica sem acesso e o rclone não é chamado. O rclone trabalha em uma cópia do arquivo, em `/tmp/rclone`, com o modo `0600`, apagada depois de cada execução; dela o painel só guarda o token renovado das nuvens e, no teste do SFTP, a chave do servidor. A senha entra pela entrada padrão do `obscure`, nunca pela linha de comando, e a lista de processos mostra só o caminho da cópia e o do arquivo no remoto. Um rclone por vez, com `GOMAXPROCS=2` e `GOMEMLIMIT=64MiB`, dentro dos limites do container do painel. O nome é resolvido antes, e o painel não chama o rclone para o próprio container nem para endereço de enlace, de grupo ou reservado. Cada operação de rede tem o prazo de 30 s, o teste inteiro tem 20 s, e uma operação que falha é repetida até três vezes dentro do mesmo envio. O texto de erro do rclone serve só para escolher o motivo, em uma palavra: ele pode trazer servidor, usuário e caminho, e não vai para a tela, para o Log nem para a auditoria. No SFTP, o rclone não abre terminal no servidor nem pede a ele a soma do arquivo.
- **Guardar no S3:** o arquivo só é apagado depois de o destino confirmar a gravação, e só se não mudou desde o envio. Quando outro destino ligado leva o mesmo arquivo, bot, remoto do rclone ou S3, o apagamento espera por ele. Com esse outro parado, os arquivos já gravados esperam em uma fila de até 20.000; cheia, o S3 que guarda para de enviar até o outro voltar.
- **Telegram:** o [`telegram.py`](../../painel/telegram.py) só chama `sendDocument` e `sendMessage`, sempre por `POST`, no endereço de `PAINEL_TELEGRAM_API`; qualquer outra operação da API de bot, como a de apagar mensagem, é recusada antes de sair do painel. Entre um envio e o seguinte há uma pausa de 3 s. Quando a API pede para ir mais devagar, o painel espera o tempo pedido, até 30 s, e repete o envio uma vez. Arquivo que a API recusa pelo tamanho, mesmo abaixo de `PAINEL_TELEGRAM_MAX_MB`, vira aviso.
- **Arquivo que o destino recusa:** resposta `4xx` que não é de permissão, de prazo (`408`) nem de pressa (`429`), na terceira passada seguida com o mesmo arquivo, deixa esse arquivo para trás, para os seguintes saírem, e grava `destino_pulado`.
- **Série:** trocar o endereço, o bucket, o prefixo, a forma do endereço ou a pasta do S3, a pasta do bot, ou a pasta no remoto, a pasta enviada ou o lugar do acesso do remoto do rclone, começa uma série nova, e o andamento anterior é esquecido. O mesmo acontece com o bot desligado e ligado de novo, que passa a enviar só o que chegar dali em diante. Trocar o intervalo, o modo, o idioma ou os segredos mantém o andamento.
- **Cópia do sistema:** `GET` e `POST /destinos/copia` mostram e gravam o formulário, com a senha atual, e `POST /destinos/copia/agora` é o botão. Quem faz a cópia é o [`copia.py`](../../painel/copia.py), em um processo à parte (`servidor.py --copia enviar`) e com a prioridade mais baixa: a tela, a rotina e o terminal disparam o mesmo comando, e uma trava em arquivo garante uma cópia por vez. O arquivo `tar` das quatro pastas passa pelo `gzip` e pelo `age` em fluxo e sai em um envio em partes: nada sem cifra chega ao disco, e cada parte, já cifrada, é montada em `DATA_DIR/painel/destinos` antes de sair. A parte tem 16 MiB ou mais e cresce com o disco em uso, para a cópia caber no número de partes do protocolo; sem o tamanho de uma parte mais 64 MiB livres, a cópia não começa. O painel recebe só a chave pública da cópia, como segredo montado, e a pasta `certs` só para leitura: a chave privada não chega ao container. A lista de usuários é lida com a trava de quem altera usuário, com espera de até 30 segundos. Link simbólico entra como link; soquete, fila e dispositivo ficam de fora e são contados. O objeto é `<pasta>/<STACK_NAME>-AAAAMMDD-HHMMSS.tar.gz.age`, e o `.sha256` é gravado depois dele: só então a cópia conta como feita. Na falha, o envio em partes é desfeito no destino. A chave do bucket precisa das mesmas duas permissões dos destinos, `s3:PutObject` e `s3:AbortMultipartUpload`. A configuração fica em `DATA_DIR/painel/destinos/copia.conf` e o andamento, em `copia.estado`, que não entra na cópia enviada. A rotina confere a cada minuto e faz uma tentativa por dia, na hora marcada. No terminal, o motivo da falha sai em código: `sem_destino`, `segredo`, `chave`, `cifra`, `cadastro`, `espaco`, `profundo`, `disco`, `interno`, `soma` ou o do pedido ao serviço, como `http_500`.
- **Auditoria da cópia do sistema:** `copia_gravada`, com o administrador, o destino, a pasta no bucket, os dias e a hora; `copia_pedida`, com o administrador e o resultado do botão; `copia_enviada`, com a origem (`tela`, `rotina` ou `terminal`), o destino, o objeto, os bytes, as partes, os arquivos, os que mudaram e os de fora; `copia_falhou`, com a origem, o motivo e as partes enviadas até ali; `copia_sem_destino`, quando o S3 da cópia é removido. `copia_enviada` e `copia_falhou` não têm endereço: quem fez foi o painel.
- **Pelo terminal:** `docker compose exec painel python3 /opt/painel/servidor.py --destinos` mostra a situação de cada destino e a última passada, sem segredo; `--destinos enviar <destino>`, com o nome que a lista mostra, faz a passada na hora e sai com `1` quando ela para antes do fim; com `--sem-espera`, não aguarda os dois minutos de um arquivo sem mudar.
- **Auditoria:** `destino_gravado`, com o administrador, o destino, a situação, a pasta, o intervalo, o modo do S3 ou o tipo do remoto do rclone (`remoto=`, e nada mais do remoto: nem servidor, nem usuário, nem pasta) e se os segredos foram trocados, mantidos ou copiados, com o destino de origem; `destino_teste`, com o resultado; `destino_pedido`; `destino_removido`; `destino_arquivo`, com o administrador, o destino, o arquivo, os bytes e o resultado do envio pedido pelo botão; `destino_enviado`, a cada passada que enviou, apagou, avisou do limite ou teve arquivo recusado, com os arquivos, os bytes, os apagados, os que passaram do limite do bot, os ignorados e os recusados; `destino_falhou`, com o motivo, quando ele muda; `destino_pulado`, com o arquivo e o motivo. As três últimas não têm endereço: quem fez foi o painel. Nenhuma leva segredo nem texto vindo do serviço de fora.

</details>

---

<a name="servidor"></a>

## 📈 Servidor: containers e recursos

A aba **Servidor** tem duas partes separadas: os containers desta stack, cada um com o que usa contra o que foi alocado a ele, e o servidor em que ela roda. Só administrador a abre. Os cartões se arrumam sozinhos pela largura da tela: cada um tem pelo menos 236 px e cabem tantos por linha quantos a tela comporta, de um no celular a seis numa tela de 1920 px; os das duas partes ficam da mesma largura. A partir de 2080 px de largura, que é também o que se vê ao diminuir o zoom do navegador, as duas partes ficam lado a lado, numa linha só de sete cartões.

**Containers da stack.** Uma linha no alto soma o que foi alocado aos três containers e o que eles usam agora, ao lado do que o servidor tem. Abaixo, um cartão por container:

| No cartão | O que mostra | Quando pede atenção |
|---|---|---|
| Estado | No ar ou fora do ar, o nome do serviço no `compose.yaml` e há quanto tempo o container está no ar | Fora do ar |
| Processador | Núcleos em uso contra os alocados (`*_CPU_LIMIT`), com a parte em % e a barra | Barra em outra cor a partir de 80% e de 95% |
| Memória | Memória em uso contra a alocada (`*_MEMORY_LIMIT`) | **Atenção** a partir de 80%; **Memória no limite** a partir de 95% |
| Processos | Processos de agora contra o teto (`*_PIDS_LIMIT`) | Barra em outra cor a partir de 80% e de 95% |
| Histórico | O uso do processador nos últimos minutos, em % do que foi alocado, com o pico escrito embaixo | Só informa |
| Limite de processador atingido | Parte do período do histórico em que a cota de processador do container acabou: `nunca`, `menos de 1% do tempo` ou a porcentagem. O contador do grupo de controle (`nr_throttled`) vale desde a subida, soma cada período de 100 ms em que a cota acabou e nunca volta; a tela usa só o que ele andou entre as leituras guardadas | Só informa: a subida do container e todo pedido mais pesado usam a cota inteira por um instante. Falta processador quando a porcentagem é grande e não baixa: aumente `*_CPU_LIMIT` |
| Encerrado por falta de memória | Quantas vezes o sistema encerrou um processo do container por falta de memória | **Atenção** quando não é `nunca` |
| Linha própria | No servidor FTP, os bloqueios de entrada em vigor; no painel, as sessões de administrador abertas; na frente web, a validade do certificado | Bloqueio em vigor ou certificado perto do fim |

**Recursos do servidor.** A máquina inteira, e não só o que a stack usa dela:

| Cartão | O que mostra | Quando pede atenção |
|---|---|---|
| Processador | Uso de agora, núcleos em uso contra os que o servidor tem, média do último minuto, carga média (1, 5 e 15 minutos), há quanto tempo o servidor está ligado e o modelo | Média do último minuto em 80% ou mais; problema em 95% ou mais |
| Memória | Em uso contra o total, disponível, em cache e swap | Menos de 15% disponível; problema com menos de 5% |
| Disco | Em uso contra o total do disco em que fica a pasta dos dados, com a parte que é das pastas do FTP, os outros dados e o livre | Menos de 15% livre; problema com menos de 5% |
| Rede do FTP | Velocidade de agora, recebendo e enviando, o pico do período, o total desde que o serviço do FTP iniciou e os erros e descartes | Só informa |

- A rede é só a do serviço do FTP: é por ela que os backups dos equipamentos chegam. No desenho, a linha cheia é o que chega e a tracejada, o que sai.
- O histórico cobre até os últimos 10 minutos, com uma leitura a cada 5 s. Ele fica na memória do painel e recomeça quando o painel reinicia. Cada desenho vai de zero até pouco acima do pico do período, para a linha ter forma mesmo com uso baixo; o pico está escrito embaixo.
- Os containers não têm swap: o limite de memória de cada um é o teto de verdade. A memória em uso não conta o cache de arquivo que o sistema solta quando precisa, como no `docker stats`.
- **Atualizar sozinha** refaz a leitura a cada 10 s; **Parar a atualização** volta ao normal. A atualização automática não conta como uso do painel: a sessão encerra depois do tempo de `PAINEL_SESSAO_MINUTOS` sem ação de quem está na tela.
- A **Visão geral** traz o resumo em quatro medidas (processador e memória do servidor e dos containers), com o atalho para esta aba.

<details>
<summary>Detalhe técnico — de onde vêm os números</summary>

- **Servidor:** o painel lê `/proc/stat`, `/proc/meminfo`, `/proc/loadavg`, `/proc/uptime` e `/proc/cpuinfo`, que o container dele já enxerga. O disco é o da pasta `/data`.
- **Containers:** cada container lê o próprio grupo de controle (`/sys/fs/cgroup`), a cada 5 s. O painel lê o dele direto. O vigia do serviço ftp publica em `/auth/recursos.estado` (`0600`, do `root`) e o nginx, em `/estado/recursos.estado` (`0600`, do usuário dele), que é a única pasta em que o nginx grava (`DATA_DIR/nginx/estado`, `0700`).
- **A linha publicada:** doze números: instante, instante em que o container iniciou, milissegundos do intervalo, microssegundos de processador gastos nele, cota e período do limite de processador, memória em uso e limite, processos e limite, vezes em que o limite de processador segurou o container e vezes em que faltou memória. Limite `0` quer dizer sem limite.
- **Quando publica:** nas duas primeiras leituras, e depois quando o uso muda (1% de um núcleo, 1 MiB de memória, processos ou contadores) ou a cada minuto. A gravação é por troca de nome. Leitura com mais de 90 s não vale: o cartão fica **sem leitura**.
- **Rede:** quem lê a do FTP é o vigia do serviço ftp, a cada 5 s, em `/proc/net/dev` do container dele, e publica uma linha de sete números em `/auth/rede.estado` (`0600`): instante, intervalo, bytes recebidos e enviados no total e no intervalo, e erros e descartes. Ele grava com a trava do cadastro, só quando os contadores mudam e mais uma vez quando o tráfego para. Leitura com mais de 12 s quer dizer rede parada.
- **Leitura sem confiança:** o painel abre cada arquivo sem seguir link simbólico, não espera por arquivo que não seja comum, lê só o começo e só aceita a quantidade certa de números. Qualquer outra coisa vira **sem leitura** no cartão, e nada do arquivo vai para a tela.
- **O que não foi usado:** nenhum soquete do Docker, nenhuma pasta do servidor montada a mais e nenhum script. A atualização é o cabeçalho `Refresh`, que só sai em `GET /servidor?auto=1`.
- **Sessão:** `GET /servidor?auto=1` não renova o tempo de uso da sessão. Sem sessão, a rota manda para a entrada; com a sessão de um usuário do FTP, responde `404` e grava `recusa_papel`.
- A versão do núcleo do sistema não aparece na tela.

</details>

---

<a name="administradores"></a>

## 🛡️ Administradores do painel

Cada pessoa que administra o painel tem o **próprio usuário e a própria senha**. Todos têm o mesmo acesso, e o que cada um faz fica na aba Log com o nome de quem fez. O primeiro administrador nasce na instalação, com o nome de `PAINEL_ADMIN_USER`; os outros são criados na aba Usuários, com o perfil **Administrador**. Os administradores ficam no começo da lista dessa aba, com as ações na linha de cada um.

| Quero | Onde | O que acontece |
|---|---|---|
| Criar um administrador | Usuários ➜ **Novo usuário**, com o perfil **Administrador** | Cria a conta. Os campos de pasta e de TLS saem da tela, e entra o da sua senha atual. Com a senha em branco, o painel gera uma senha forte e a mostra **uma única vez** |
| Trocar a senha, a minha ou a de outro | Usuários ➜ **Trocar senha**, na linha do administrador | A senha antiga deixa de valer na hora e as outras sessões desse administrador são encerradas |
| Trocar o nome, o meu ou o de outro | Usuários ➜ **Trocar nome**, na linha do administrador | A entrada passa a ser pelo nome novo; a senha continua a mesma |
| Remover um administrador | Usuários ➜ **Remover**, na linha do administrador | A conta some e as sessões dela são encerradas |

**Resultado esperado:** a lista volta com o aviso da alteração (`Administrador criado.`, `Senha trocada.`, `Nome trocado.` ou `Administrador removido.`, com o aviso das sessões encerradas) e o administrador novo entra logo em seguida, sem reiniciar nada.

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
- **Instalação anterior à `0.22.0`:** na primeira subida depois da atualização, o painel cria o administrador `admin` (ou o nome de `PAINEL_ADMIN_USER`) com a mesma senha que já valia.
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

<a name="marca"></a>

## 🎨 Marca do painel

O painel mostra a logo da ALL-SAFE em quatro lugares e a autoria em um:

| Onde | O que aparece | Arquivo |
|---|---|---|
| Aba do navegador e favoritos | Ícone | `favicon.ico`, `icone-32.png` e `icone-192.png` |
| Atalho na tela inicial do celular | Ícone | `apple-touch-icon.png` |
| Menu de todas as telas | Símbolo, ao lado do nome | `simbolo-64.png` |
| Tela de entrada | Logo completa | `logo-320.png` |
| Rodapé de todas as telas | `Desenvolvido pela allsafe.inf.br`, com o endereço do site e o do GitHub | texto do painel |

Os seis arquivos ficam em [`web/marca/`](../../web/marca/) e são entregues pelo nginx.

> ⚠️ **Contrato ou venda para terceiros:** quem usa a stack para si pode manter a logo e o ícone. Quem a entrega em contrato ou a vende para terceiros tira ou troca os dois. É o único pedido da ALL-SAFE, explicado em [Marca ALL-SAFE](../../MARCA.md).

**Trocar a logo e o ícone:**

1. Substitua as duas artes de [`web/marca/fonte/`](../../web/marca/fonte/), mantendo os nomes: `allsafe-logo-2048.png` (logo completa) e `allsafe-simbolo-512.png` (só o símbolo). Use PNG quadrado, de preferência com fundo transparente.
2. Gere os seis arquivos:

   ```bash
   ./scripts/gerar-marca.sh
   ```

3. Reaplique a stack:

   ```bash
   ./deploy.sh
   ```

**Resultado esperado:** o script lista os seis arquivos, com o tamanho de cada um, e termina com `Marca gerada em web/marca/. Rode ./deploy.sh para o painel passar a usar.` Depois do `deploy.sh`, a tela de entrada mostra a logo nova. Se a aba do navegador continuar com o ícone antigo, veja [Solução de problemas](solucao-de-problemas.md#painel).

A linha `Desenvolvido pela allsafe.inf.br` continua no rodapé de todas as telas, com qualquer logo: ela é mantida em toda cópia, de uso próprio ou vendida.

<details>
<summary>Detalhe técnico — como a marca é entregue</summary>

- **Sem o ImageMagick:** o `gerar-marca.sh` precisa dele só no computador de quem troca a logo. Também serve substituir direto os seis arquivos de `web/marca/`, com os mesmos nomes e tamanhos: a tabela está em [Scripts](scripts.md#gerar-marca).
- **Placa clara:** a arte é escura e o painel tem fundo escuro; o script põe a arte sobre uma placa clara de cantos arredondados, sem alterar as cores dela. `MARCA_PLACA='#rrggbb'` troca a cor da placa.
- **Só os seis nomes existem:** o nginx entrega `/favicon.ico` e os cinco PNG de `/marca/`, só para leitura, com os cabeçalhos de segurança de [`nginx/cabecalhos.conf`](../../nginx/cabecalhos.conf) e `Cache-Control: no-cache`. Outro nome, a lista da pasta e as artes de origem não são entregues, e as artes de origem nem entram na imagem.
- **Sem conteúdo de fora:** o painel continua com `img-src 'self'`: só carrega imagem do próprio endereço. Os dois links do rodapé abrem em outra aba com `rel="noopener noreferrer"`, e o `Referrer-Policy: same-origin` não repassa o endereço do painel ao site de destino.
- **Conferência:** o `./scripts/validate.sh` recusa a pasta sem um dos seis arquivos, ou com arquivo que não é PNG nem ICO.

</details>

---

<a name="como-decide"></a>

## 🔄 Como o painel decide

Cada pedido passa por três conferências antes de mudar alguma coisa: a rede de origem (nginx), o usuário e a senha, e a origem e o token do formulário (painel). O download de um arquivo passa pelas duas primeiras e pela conferência do caminho pedido. A senha do administrador é conferida pelo painel; a do usuário do FTP, pelo servidor FTP. O primeiro fluxograma vai da abertura da página até a sessão; o segundo mostra o que acontece com cada pedido da sessão.

<details>
<summary>Fluxogramas do painel, com a sequência escrita — clique para expandir</summary>

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
        hash@{ shape: doc, label: "administradores<br>nome e hash da senha" }
        ftp@{ shape: rect, label: "Pure-FTPd<br>allsafe-ftp, rede interna" }
    end
    subgraph SESSAO["Sessão"]
        sessao@{ shape: rect, label: "sessão de 4 h<br>cookie e token CSRF" }
        pedidos@{ shape: subproc, label: "pedidos da sessão<br>fluxograma dos pedidos" }
    end
    subgraph RESULTADO["Resultado"]
        atendido@{ shape: stadium, label: "pedido atendido" }
        recusa@{ shape: stadium, label: "pedido recusado" }
    end

    usuario -- "1 · abre https, TCP 8443" --> nginx
    nginx -- "2 · confere a origem e a taxa de pedidos" --> rede
    rede -- "3a · sim: repassa pelo soquete Unix" --> painel
    rede -- "3b · não: 403 ou 429" --> recusa
    painel -- "4 · pede usuário e senha e confere" --> senha
    senha -- "5a · sim: abre a sessão do administrador ou do usuário do FTP" --> sessao
    senha -- "5b · não: 5 erros bloqueiam o endereço" --> recusa
    sessao -- "6 · cada pedido passa pelas conferências" --> pedidos
    pedidos -- "7a · aceito" --> atendido
    pedidos -- "7b · recusado" --> recusa
    painel -. "administrador: compara com o hash" .-> hash
    painel -. "outro nome: o servidor FTP confere a senha" .-> ftp
```

<sub>Nível 2 · Fluxograma · [fonte](diagramas/)</sub>

| Nº | De ➜ Para | O que acontece |
|---|---|---|
| 1 | Usuário ➜ nginx | O navegador abre `https://<endereço>:8443`; só HTTPS, com TLS 1.2 ou 1.3, em HTTP/2 quando o navegador aceita |
| 2 | nginx ➜ rede permitida e dentro do limite? | O endereço de origem é comparado com `PAINEL_REDES_PERMITIDAS`, e o pedido, com os limites de taxa, de conexões e de tamanho |
| 3a | rede permitida e dentro do limite? ➜ Painel web | Sim: o nginx repassa o pedido pelo soquete Unix, com o endereço do cliente |
| 3b | rede permitida e dentro do limite? ➜ pedido recusado | Não: `403` para rede de fora, `429` para pedidos demais; o painel nem recebe o pedido |
| 4 | Painel web ➜ usuário e senha conferem? | O painel confere de novo a rede e o nome de host, mostra a tela de entrada, que pede usuário e senha, e confere o que foi digitado |
| 5a | usuário e senha conferem? ➜ sessão de 4 h | Sim: abre a sessão, com cookie e token CSRF. A do administrador alcança todas as abas; a do usuário do FTP, só a tela Meus arquivos |
| 5b | usuário e senha conferem? ➜ pedido recusado | Não: `401`, sem dizer qual dos dois errou; cinco erros em 15 minutos bloqueiam o endereço (`429`) |
| 6 | sessão de 4 h ➜ pedidos da sessão | Cada pedido feito com a sessão aberta passa pelas conferências do fluxograma dos pedidos, logo abaixo |
| 7a | pedidos da sessão ➜ pedido atendido | Aceito: o usuário fica pronto no FTP, o arquivo é baixado ou a alteração é feita |
| 7b | pedidos da sessão ➜ pedido recusado | Recusado: nada muda, e a recusa fica na auditoria |

**Apoio**

| Quem | Usa | Como |
|---|---|---|
| Painel web | administradores (`DATA_DIR/painel/administradores`) | compara a senha digitada com o hash `scrypt` do administrador, a cada entrada; nome que não existe passa pela mesma conta |
| Painel web | Pure-FTPd (`allsafe-ftp`, rede interna da stack) | não é administrador com essa senha e a entrada dos usuários do FTP está ligada: entra no servidor FTP com o nome e a senha e sai em seguida, em TLS com o certificado conferido; quem diz se a senha vale é o servidor |

**Pedidos da sessão**

O que o painel faz com cada pedido depois da entrada: o formulário que cria, edita ou remove um usuário, e a pasta ou o arquivo pedido na aba Arquivos ou na tela Meus arquivos.

<!-- diagrama: diagramas/painel-pedidos-fluxograma.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    subgraph SESSAO["Sessão"]
        painel@{ shape: rect, label: "Painel web<br>sessão aberta, token CSRF" }
        pedido@{ shape: diam, label: "origem e token<br>conferem?" }
        auditoria@{ shape: docs, label: "auditoria.log<br>DATA_DIR/painel" }
    end
    subgraph USUARIOS["Usuários do FTP"]
        cmd@{ shape: rect, label: "allsafe-ftp-user<br>pure-pw" }
        puredb@{ shape: cyl, label: "PureDB<br>DATA_DIR/auth" }
    end
    subgraph ARQUIVOS["Arquivos"]
        caminho@{ shape: diam, label: "caminho dentro<br>da pasta dos dados?" }
        dados@{ shape: lin-cyl, label: "DATA_DIR/dados<br>pastas dos usuários" }
    end
    subgraph RESULTADO["Resultado"]
        fim@{ shape: stadium, label: "usuário pronto no FTP" }
        barrado@{ shape: stadium, label: "403<br>envio recusado" }
        feito@{ shape: stadium, label: "arquivo baixado, enviado<br>ou alteração feita" }
        recusa@{ shape: stadium, label: "pedido recusado" }
    end

    painel -- "1 · envia um formulário, de usuário ou de arquivos" --> pedido
    pedido -- "2a · sim, usuário: executa" --> cmd
    pedido -- "2b · sim, arquivos: confere o caminho" --> caminho
    pedido -- "2c · não: fora do painel ou sem token" --> barrado
    cmd -- "3 · grava o usuário e cria a pasta dele, se faltar" --> puredb
    puredb -- "4 · vale no próximo login, sem reiniciar o FTP" --> fim
    painel -- "5 · em Arquivos ou em Meus arquivos, abre uma pasta ou baixa um arquivo" --> caminho
    caminho -- "6a · sim: abre parte por parte, sem seguir link simbólico" --> dados
    caminho -- "6b · não: 400, 403, 404 ou 409" --> recusa
    dados -- "7 · entrega o arquivo, grava o enviado, cria a pasta, renomeia ou apaga" --> feito
    painel -. "registra cada ação" .-> auditoria
```

<sub>Nível 2 · Fluxograma · [fonte](diagramas/)</sub>

| Nº | De ➜ Para | O que acontece |
|---|---|---|
| 1 | Painel web ➜ origem e token conferem? | Todo formulário enviado é conferido duas vezes: a origem tem de ser o próprio painel e o token CSRF tem de ser o da sessão. Formulário de usuário, só o administrador tem; os de arquivos, o administrador e o usuário do FTP, este conforme o perfil dele |
| 2a | origem e token conferem? ➜ `allsafe-ftp-user` | Sim, formulário de usuário: o painel chama o comando, com a senha pela entrada padrão |
| 2b | origem e token conferem? ➜ caminho dentro da pasta dos dados? | Sim, formulário de arquivos, da aba Arquivos ou da tela Meus arquivos (enviar arquivo, criar pasta, renomear ou apagar): segue para a conferência do caminho |
| 2c | origem e token conferem? ➜ 403 | Não: `403`, sem alterar nada, para o envio que não partiu do painel ou que veio sem o token da sessão |
| 3 | `allsafe-ftp-user` ➜ PureDB | A conta é gravada em `DATA_DIR/auth`, com trava para uma alteração por vez, e a pasta do usuário novo é criada em `DATA_DIR/dados`, se ainda não existe; a dispensa do TLS de um usuário fica na `sem-tls.lista`, na mesma pasta do banco |
| 4 | PureDB ➜ usuário pronto no FTP | O FTP lê o banco a cada login: vale na hora, sem reiniciar |
| 5 | Painel web ➜ caminho dentro da pasta dos dados? | Na aba Arquivos, o administrador abre uma pasta ou baixa um arquivo; na tela Meus arquivos, o usuário do FTP faz o mesmo, só na pasta dele. Esses pedidos não levam formulário, e o caminho é conferido do mesmo jeito |
| 6a | caminho dentro da pasta dos dados? ➜ `DATA_DIR/dados` | Sim: o painel abre cada parte do caminho sem seguir link simbólico, a partir da pasta dos dados, para o administrador, e a partir da pasta do cadastro, para o usuário do FTP |
| 6b | caminho dentro da pasta dos dados? ➜ pedido recusado | Não: `400` para caminho ou nome que tenta sair da pasta, `403` para link simbólico, `404` para o que não existe, `409` para nome já usado |
| 7 | `DATA_DIR/dados` ➜ arquivo baixado, enviado ou alteração feita | O arquivo sai como anexo, em blocos; o arquivo enviado só ganha nome na pasta depois de chegar inteiro, sem substituir o que existe; a pasta nova nasce vazia, do usuário `ftpdata`; o arquivo ou a pasta escolhida é renomeada ou apagada |

**Apoio**

| Quem | Usa | Como |
|---|---|---|
| Painel web | `auditoria.log` (`DATA_DIR/painel`) | registra cada entrada, recusa, download e alteração |

</details>

---

<a name="auditoria"></a>

## 📜 Auditoria

Tudo o que o painel faz fica em `DATA_DIR/painel/auditoria.log` (`0600`, do `root`) e aparece na aba Log.

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
| `recusa_papel` | Um usuário do FTP pediu uma tela ou um formulário de administração, ou uma ação que o perfil dele não tem; com o usuário, o caminho pedido e o perfil |
| `usuario_criado` · `senha_trocada` · `pasta_trocada` · `usuario_removido` | Alteração de usuário do FTP, com o administrador que fez; a criação leva também a pasta e o perfil do usuário, a troca de pasta, a nova e a anterior, e a remoção, a pasta, quando ela foi apagada junto |
| `perfil_trocado` | Perfil de um usuário do FTP trocado, com o administrador, o usuário, o perfil novo e o anterior |
| `limites_alterados` | Limites de um usuário do FTP gravados, com o administrador, o usuário e o valor de cada limite; `-` no que ficou em branco |
| `retencao_alterada` | Limpeza automática de um usuário do FTP gravada ou desligada, com o administrador, o usuário e a regra; `-` no que ficou em branco |
| `retencao_aplicada` · `retencao_falhou` | A limpeza automática apagou arquivos antigos, com o usuário, a pasta, os arquivos, as pastas vazias e os bytes que saíram, os erros e a regra · uma passada não terminou, com o motivo. Sem endereço: quem fez foi o painel |
| `bloqueio_removido` | Um administrador tirou o bloqueio por tentativa de um usuário no FTP, com o administrador, o usuário e a quantidade de endereços desbloqueados |
| `endereco_bloqueado` | O painel bloqueou o endereço que passou do limite de erros de usuário e senha, com a quantidade de erros e os dias |
| `endereco_bloqueado_manual` | Um administrador bloqueou à mão um endereço ou um prefixo, pela aba Bloqueios, com o administrador, o endereço ou o prefixo e os dias |
| `endereco_prazo` · `endereco_desbloqueado` | Um administrador mudou o prazo do bloqueio de um endereço ou de um prefixo · liberou o bloqueio; com o administrador, o endereço ou o prefixo e, na mudança, os dias |
| `recusa_endereco` | Pedido de um endereço bloqueado, recusado com `403` antes de qualquer rota |
| `tls_dispensado` · `tls_exigido` | Um administrador dispensou um usuário do TLS · voltou a exigir; com o administrador e o usuário |
| `pasta_criada` | Pasta criada pela aba Arquivos ou pela tela Meus arquivos, com quem criou (administrador ou usuário do FTP) e o caminho |
| `item_renomeado` · `item_apagado` | Arquivo ou pasta com o nome trocado · apagado, pela aba Arquivos, pela tela Meus arquivos ou junto com o usuário; com quem fez (administrador ou usuário do FTP), o tipo e o caminho. O renomeado leva o caminho de antes e o de depois; o apagado, a quantidade de itens removidos, `completo=nao` quando o pedido parou no limite e `usuario=` quando a pasta saiu junto com o dono |
| `arquivo_baixado` · `arquivo_interrompido` | Download pela aba Arquivos ou pela tela Meus arquivos, completo · cortado antes do fim; com quem baixou, o caminho e os bytes entregues |
| `arquivo_enviado` · `envio_interrompido` | Arquivo enviado pelo painel, pela aba Arquivos ou pela tela do usuário do FTP · envio que parou antes do fim, sem nada gravado; com quem enviou, o caminho e os bytes |
| `recusa_envio` | Usuário do FTP que pediu o envio pelo painel sem ter a permissão, com o usuário e o perfil |
| `destino_gravado` · `destino_removido` | Um administrador gravou a configuração de um [destino](#destinos), S3, remoto do rclone ou bot do Telegram · removeu o destino; com o administrador e o destino, e, na gravação, a situação, a pasta, o intervalo, o modo do S3 ou o tipo do remoto e se os segredos foram trocados ou mantidos |
| `destino_teste` · `destino_pedido` | Um administrador clicou em **Testar**, com o resultado · em **Enviar agora**; com o administrador e o destino |
| `destino_arquivo` | Um administrador mandou um arquivo ao destino pelo botão da aba Arquivos, com o administrador, o destino, o arquivo, os bytes e o resultado |
| `destino_enviado` · `destino_falhou` · `destino_pulado` | Uma passada enviou, apagou, avisou do limite ou teve arquivo recusado, com o destino e as contagens · parou antes do fim, com o motivo, quando ele muda · deixou para trás um arquivo que o destino recusa, com o arquivo e o motivo. Sem endereço: quem fez foi o painel |
| `copia_gravada` · `copia_pedida` · `copia_sem_destino` | Um administrador gravou a [cópia do sistema para o S3](#copia-do-sistema), com o destino, a pasta no bucket, os dias e a hora · clicou em **Copiar e enviar agora**, com o resultado · removeu o S3 que recebia a cópia |
| `copia_enviada` · `copia_falhou` | A cópia do sistema chegou ao S3, com a origem (`tela`, `rotina` ou `terminal`), o destino, o objeto, os bytes, as partes e os arquivos · parou antes do fim, com a origem e o motivo. Sem endereço: quem fez foi o painel |
| `admin_inicial_criado` | Primeira subida: o painel criou o administrador de `PAINEL_ADMIN_USER` |
| `admin_criado` · `admin_senha_trocada` · `admin_renomeado` · `admin_removido` | Alteração de administrador pelo painel, com quem fez e quem foi alterado |
| `admin_senha_atual_recusada` | Alteração de administrador ou apagamento recusado: a senha atual de quem pediu não conferiu; com o administrador e o caminho pedido |
| `usuario_senha_atual_recusada` | Apagamento recusado na tela Meus arquivos: a senha do FTP de quem pediu não conferiu; com o usuário e o caminho pedido |
| `admin_definido_no_host` | O `scripts/painel-senha.sh` criou um administrador ou trocou a senha dele |
| `falha_comando` | O `allsafe-ftp-user` devolveu erro, ou o sistema recusou gravar, renomear ou apagar um item |
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
| Rede | Por padrão, bind só em IP privado e `PAINEL_REDES_PERMITIDAS` só com redes privadas, aplicada pelo nginx e conferida de novo pelo painel; `deploy.sh` e os dois containers recusam o resto. Com `REDE_PERMITIR_IP_PUBLICO=sim`, o painel mostra o alerta só ao administrador: no menu, na aba Segurança e no rodapé |
| Transporte | Só HTTPS, TLS 1.2 ou 1.3, em HTTP/2 ou HTTP/1.1; HTTP puro recebe `400` |
| Volume de pedidos | No nginx, por endereço: 20 pedidos por segundo (rajada de 40), 16 conexões, 16 KiB por pedido e 5 KiB por endereço ou cabeçalho, em HTTP/2 e em HTTP/1.1; o que passa disso recebe `429`, `413`, `414` ou `400`, ou tem a conexão HTTP/2 encerrada |
| Entrada | Usuário e senha por administrador; senha de no mínimo 12 caracteres, guardada só como hash `scrypt`; a recusa não diz se o erro foi no usuário ou na senha; cinco erros bloqueiam o endereço por 15 minutos |
| Usuário do FTP | Entra com o nome e a senha do FTP, conferidos pelo próprio servidor FTP, e alcança só a tela Meus arquivos, na pasta do cadastro, para o que o perfil dele deixa; as telas de administração respondem `404`; a sessão acaba quando o cadastro dele muda; `PAINEL_ACESSO_USUARIOS_FTP=nao` desliga esta entrada |
| Perfis | O que cada usuário do FTP faz é limitado pelo perfil dele, aplicado pelo sistema de arquivos do servidor e não pela tela: Leitura não grava, Envio não apaga nem altera o que já chegou, Só envio não lista nem baixa; a troca de perfil encerra a sessão dele no painel |
| Administradores | Toda alteração de administrador pede a senha atual de quem está alterando; o administrador alterado tem as sessões encerradas; ninguém remove a própria conta |
| Apagar | Todo apagamento, de arquivo, de pasta ou da pasta junto com o usuário, pede a caixa de confirmação e a senha atual de quem está apagando: um navegador esquecido aberto não apaga backup |
| Sessão | Cookie `__Host-sessao` com `Secure`, `HttpOnly` e `SameSite=Strict`, presa ao endereço de origem; encerra com 4 horas sem uso (`PAINEL_SESSAO_MINUTOS`) e, de qualquer forma, em 12 horas |
| Arquivos | A aba Arquivos lê, recebe arquivo, cria pasta vazia, renomeia e apaga, e só dentro de `DATA_DIR/dados`: caminho que tenta sair da pasta é recusado, link simbólico não é seguido, renomear não muda o item de pasta nem substitui outro e pede a senha de quem está na sessão, como apagar, pasta de usuário do FTP só sai junto com o usuário, o arquivo sai sempre como anexo e no máximo 8 downloads correm ao mesmo tempo, 2 por usuário do FTP; arquivo enviado pelo painel nunca substitui outro, só ganha nome depois de chegar inteiro, tem teto de tamanho e, para o usuário do FTP, depende da permissão dada pelo administrador; o usuário do FTP só faz, dentro da pasta dele, o que o perfil dele deixa |
| Pastas dos usuários | Cada usuário do FTP fica preso (`chroot`) na pasta do cadastro; a pasta escolhida não sai de `DATA_DIR/dados` nem passa por link simbólico; pasta alcançada por mais de um usuário aparece marcada como **dividida** |
| Formulários | Token CSRF por sessão e conferência de `Origin`: o envio tem de partir do próprio painel; corpo limitado a 8 KiB, menos no envio de arquivo, que tem as duas rotas dele e o teto de `PAINEL_ENVIO_MAX_MB` |
| Idioma | A troca é um formulário como os outros, com token e `Origin`; o cookie do idioma só leva `pt` ou `en` e não vale como sessão; a volta depois da troca só leva a tela do próprio painel |
| Destinos de fora | Só o administrador configura, com a senha atual, e só ele manda um arquivo pelo botão da aba Arquivos; o painel sai só por HTTPS, com o certificado conferido, ou, no remoto SFTP do rclone, por SSH com a chave do servidor conferida, e não vai para o próprio container nem para endereço reservado; o rclone só grava: listar, baixar, mover, sincronizar e apagar são recusados antes de existir um processo; as chaves do S3, o acesso do remoto do rclone, o token do bot e a conversa ficam em arquivos `0600` e nunca voltam para a tela nem para a auditoria; o bot só envia: o painel não lê a conversa nem aceita comando; a cópia do sistema para o S3 sai cifrada com a chave pública, e a chave que a abre não chega ao painel; `PAINEL_DESTINOS=nao` desliga tudo |
| Navegador | `Content-Security-Policy` sem script, `X-Frame-Options: DENY`, `nosniff`, `Referrer-Policy: same-origin`, HSTS e `no-store`; a página não carrega nada de fora |
| Containers | Raiz somente leitura, `cap_drop: ALL`, `no-new-privileges`, sem socket do Docker, limites de CPU, memória e processos; o nginx roda sem root e sem nenhuma capability |

<details>
<summary>Detalhe técnico — implementação</summary>

- **Código:** os módulos de [`painel/`](../../painel/), só com a biblioteca padrão do Python 3.13 do Debian 13, listados [logo abaixo](#modulos); a aparência está em [`web/estilo.css`](../../web/estilo.css) e a logo e o ícone em [`web/marca/`](../../web/marca/), que o nginx entrega direto, sem passar pelo painel, como o [`web/robots.txt`](../../web/robots.txt). Cada página aponta para o estilo com a marca do conteúdo dele (`/estilo.css?v=` e os 12 primeiros dígitos do SHA-256 do arquivo, gravados na construção da imagem do painel): estilo novo é endereço novo, e nem o navegador nem um proxy no caminho entregam o antigo depois de uma atualização. O `/.well-known/security.txt` é o painel que monta, a cada pedido, com o e-mail de `SEGURANCA_CONTATO_EMAIL`: [Configuração](configuracao.md#contato-de-seguranca). Não há JavaScript, fonte nem imagem externa.
- **Imagem:** alvo `painel` do [`Dockerfile`](../../Dockerfile), sobre a mesma base do FTP (traz o `pure-pw` e o `allsafe-ftp-user`). Imagem `PAINEL_IMAGE`, container `PAINEL_CONTAINER_NAME`.
- **Entrada do container:** [`painel/entrypoint.sh`](../../painel/entrypoint.sh) recusa senha em variável, confere o `PAINEL_ADMIN_USER`, o IP e as redes privados, ajusta dono e modo de `/painel` e do arquivo de administradores, gera o certificado, copia-o para a pasta do nginx e executa o servidor.
- **Frente web:** alvo `nginx` do [`Dockerfile`](../../Dockerfile), nginx 1.26 do Debian 13, configurado por [`nginx/nginx.conf.modelo`](../../nginx/nginx.conf.modelo). Com o navegador, o nginx fala HTTP/2, ou HTTP/1.1 se o navegador não pedir, e mantém a conexão parada por 60 segundos; com o painel, HTTP/1.1, uma conexão por pedido. O `estilo.css` vai comprimido para quem aceita gzip, a partir da cópia feita na construção da imagem; página do painel nunca é comprimida. Em HTTP/2, o download de arquivo grande usa mais processador por byte: 300 MiB levaram 0,69 s, contra 0,45 s em HTTP/1.1, medidos com o nginx no limite de meio processador, os dois acima do que uma rede de 1 Gbit/s entrega. O painel escuta no soquete `/nginx/painel.sock` (`0660`, grupo `10001`) e só aceita pedido com exatamente um `X-Real-IP` válido; sem ele, responde `400`. Detalhe em [Segurança](seguranca.md#painel).
- **Hash da senha:** `scrypt` com `N=2^15`, `r=8`, `p=1` e sal de 16 bytes, no formato `scrypt$15$8$1$<sal>$<resumo>`. Cada administrador tem o seu, em `/painel/administradores`; o arquivo é lido a cada entrada e a comparação é em tempo constante. Usuário que não existe passa pela mesma conta e recebe a mesma resposta. O segredo `/run/secrets/painel_admin_inicial_senha_hash` só é usado na subida em que ainda não existe nenhum administrador.
- **Sessão:** o token do cookie tem 256 bits aleatórios e o servidor guarda só o resumo SHA-256 dele, em memória, com o nome do administrador ou do usuário do FTP que entrou. Reiniciar o painel encerra todas as sessões e zera a contagem de erros de entrada.
- **Tela de entrada:** o formulário leva um token assinado (HMAC) com validade curta, para a entrada também não aceitar pedido forjado por outro site.
- **Origem do envio:** todo `POST` tem de trazer `Origin` igual ao endereço do painel (`https://` mais o `Host`). A política `Referrer-Policy: same-origin` faz o navegador mandar a origem real no envio que parte do próprio painel e `Origin: null` no que parte de outro endereço; `null` e origem de fora recebem `403` e o evento `recusa_origem`.
- **Nome de host:** o cabeçalho `Host` tem de ser um IP privado, `localhost` ou o `PAINEL_CERT_CN`; outro nome recebe `400`. Com `REDE_PERMITIR_IP_PUBLICO=sim`, qualquer endereço IPv4 é aceito no lugar do nome.
- **Endereço de quem acessa:** é o da conexão que chega ao nginx. `X-Forwarded-For` é ignorado, a não ser com `PAINEL_PROXY_CONFIAVEL`: aí vale o último endereço do cabeçalho, só em conexão vinda do proxy escolhido, e o painel mostra o aviso só ao administrador: no menu, na aba Segurança e no rodapé. Veja [Só o painel publicado](seguranca.md#painel-por-proxy).
- **Usuários do FTP:** o painel monta as mesmas pastas `DATA_DIR/auth` e `DATA_DIR/dados` do serviço `ftp` e chama o mesmo `allsafe-ftp-user`, com `flock` em `/auth/.lock`. Por isso não precisa do socket do Docker.
- **Arquivos:** a aba Arquivos lê a mesma pasta `DATA_DIR/dados`, sempre com abertura só para leitura; as gravações são a pasta vazia de `POST /arquivos/pasta`, a troca de nome e o apagamento, as três em relação à pasta aberta e nenhuma com conteúdo vindo do navegador. Detalhe em [Arquivos e download](#arquivos).
- **Usuário do FTP no painel:** a senha é conferida por um login no serviço `ftp`, pela rede do Compose, e a sessão dele só tem as rotas de `/meus-arquivos` e a saída. Detalhe em [Usuário do FTP no painel](#usuario-ftp).
- **Capabilities devolvidas:** `CHOWN`, `DAC_OVERRIDE` e `FOWNER`, para criar as pastas com o dono `ftpdata` e gravar em `/auth`. Nenhuma de rede.
- **Saúde:** `python3 -I -S /opt/painel/saude.py` pede `/saude` pelo soquete Unix, sem carregar os módulos do painel, para caber na cota de processador do container; `servidor.py --saude` faz o mesmo pedido. O healthcheck do nginx faz o mesmo pedido por TLS, em `127.0.0.1:8443`, e confere o caminho inteiro.
- **Limites:** `PAINEL_MEMORY_LIMIT`, `PAINEL_CPU_LIMIT` e `PAINEL_PIDS_LIMIT`, em [Configuração](configuracao.md#painel).

</details>

<a name="modulos"></a>

<details>
<summary>Detalhe técnico — módulos do código</summary>

O código fica em [`painel/`](../../painel/), um assunto por arquivo, e vai inteiro para `/opt/painel` na imagem. O ponto de entrada é o `servidor.py`; os outros são importados por ele.

| Módulo | O que tem |
|---|---|
| [`servidor.py`](../../painel/servidor.py) | Ponto de entrada: sobe o servidor, cria o primeiro administrador e atende os modos `--hash`, `--saude`, `--administrador`, `--retencao`, `--destinos` e `--copia` |
| [`saude.py`](../../painel/saude.py) | Verificação de saúde do container: o pedido de `/saude` pelo soquete Unix, só com a biblioteca de soquete |
| [`config.py`](../../painel/config.py) | Caminhos, limites e a leitura das variáveis do container, com as recusas de rede e de sessão |
| [`senha.py`](../../painel/senha.py) | Hash `scrypt` das senhas dos administradores e a conferência em tempo constante |
| [`administradores.py`](../../painel/administradores.py) | Leitura e gravação do arquivo de administradores, uma alteração por vez |
| [`sessao.py`](../../painel/sessao.py) | Sessões em memória, de administrador e de usuário do FTP, limite de tentativas e token do formulário de entrada |
| [`auditoria.py`](../../painel/auditoria.py) | Gravação e leitura do `auditoria.log` |
| [`estado.py`](../../painel/estado.py) | Leitura do estado da stack (usuários, uso das pastas, FTP no ar, certificados, quem entra sem TLS) e a chamada do `allsafe-ftp-user` |
| [`confirmacao.py`](../../painel/confirmacao.py) | Confirmação pela senha atual de quem está na sessão, pedida nas alterações de administrador, na troca de nome de arquivo ou pasta e em tudo o que apaga arquivo ou pasta |
| [`pagina.py`](../../painel/pagina.py) | Moldura das telas, com o menu, o símbolo e a autoria no rodapé, e os textos que mais de uma aba usa |
| [`idioma.py`](../../painel/idioma.py) | Idioma das telas: o texto de cada pedido em português ou em inglês, o formato da data e dos números, o cookie da tela de entrada e a escolha gravada de cada conta |
| [`idioma_en.py`](../../painel/idioma_en.py) | Catálogo do inglês: cada texto das telas em português e a tradução dele, e as mensagens de erro do `allsafe-ftp-user` que o painel mostra |
| [`icones.py`](../../painel/icones.py) | Os ícones do painel, desenhados em linha: saem dentro do HTML de cada tela, sem arquivo de imagem |
| [`graficos.py`](../../painel/graficos.py) | Os gráficos (colunas por dia, faixa dividida, barras e linha do tempo), em SVG montado no servidor, sem script e sem estilo dentro do HTML; os números ficam também em texto |
| [`cena.py`](../../painel/cena.py) | A cena em três dimensões da tela de entrada e a miniatura dela na faixa que abre cada aba, só com HTML e CSS |
| [`atendimento.py`](../../painel/atendimento.py) | Soquete Unix, cabeçalhos de segurança, conferências de todo pedido (endereço do cliente, rede, `Host`, origem, sessão e CSRF), roteamento por papel (administrador ou usuário do FTP) e a entrega de arquivo em blocos |
| [`rotas.py`](../../painel/rotas.py) | Tabelas de método e caminho para a função que responde: uma para o administrador e uma para cada perfil de usuário do FTP |
| [`entrada.py`](../../painel/entrada.py) | Tela de entrada, entrada com usuário e senha, do administrador e do usuário do FTP, e saída |
| [`conta_ftp.py`](../../painel/conta_ftp.py) | Conta do usuário do FTP no painel: leitura do cadastro dele, conferência da senha no servidor FTP e os motivos que encerram a sessão |
| [`aba_visao_geral.py`](../../painel/aba_visao_geral.py) | Aba Visão geral |
| [`limites.py`](../../painel/limites.py) | Limites próprios de cada usuário do FTP: leitura do cadastro e da `limites.lista`, conferência do formulário e o resumo da lista |
| [`retencao.py`](../../painel/retencao.py) | Limpeza automática: a regra de cada usuário do FTP, lida da `limites.lista`, a conferência do formulário e o resumo da lista |
| [`limpeza.py`](../../painel/limpeza.py) | Limpeza automática: a passada que aplica a regra de cada usuário na pasta dele, pela linha de execução do painel ou pelo terminal (`servidor.py --retencao`) |
| [`aba_usuarios.py`](../../painel/aba_usuarios.py) | Aba Usuários: lista única de administradores e usuários do FTP, criação com o perfil e a pasta escolhidos, edição (perfil, pasta, limites e bloqueios), troca de senha, remoção e a dispensa do TLS por usuário |
| [`aba_arquivos.py`](../../painel/aba_arquivos.py) | Aba Arquivos: navegação pelas pastas dos usuários, download, envio de arquivo, criação de pasta vazia, troca de nome e apagamento de arquivo e de pasta, e os botões de enviar um arquivo a um destino gravado |
| [`envio.py`](../../painel/envio.py) | Envio de arquivo pelo navegador: leitura do corpo `multipart/form-data` em fluxo, do soquete para o disco, sem guardar o arquivo na memória |
| [`aba_meus_arquivos.py`](../../painel/aba_meus_arquivos.py) | Tela Meus arquivos, do usuário do FTP: navegação, download e as ações do perfil dentro da pasta dele; para o perfil Só envio, a tela Envio de arquivos |
| [`copia.py`](../../painel/copia.py) | Cópia do sistema para o S3: a configuração e o andamento, o arquivo das quatro pastas cifrado em fluxo e enviado em partes, a rotina e o disparo pela tela ou pelo terminal (`servidor.py --copia`) |
| [`destinos.py`](../../painel/destinos.py) | Destinos de fora: a configuração, os segredos e o andamento de cada um, a passada que envia o que chegou, pela linha de execução do painel ou pelo terminal (`servidor.py --destinos`), o teste e o envio de um arquivo só |
| [`chegadas.py`](../../painel/chegadas.py) | Avisos de chegada: os arquivos que o servidor FTP e o envio pelo painel dão como inteiros, para o bot do Telegram enviar sem esperar |
| [`saida.py`](../../painel/saida.py) | Saída do painel para fora da stack: HTTPS com o certificado conferido, a recusa dos endereços que o painel não alcança e os motivos de falha |
| [`s3.py`](../../painel/s3.py) | Armazenamento S3: a assinatura versão 4 dos pedidos, o envio em um pedido ou em partes e a conferência dos campos do formulário |
| [`telegram.py`](../../painel/telegram.py) | Bot do Telegram: o envio de documento e de mensagem, e a conferência do token e da conversa |
| [`rclone.py`](../../painel/rclone.py) | Remoto do rclone: a lista fechada de tipos e de campos, o arquivo do remoto e a conferência dele a cada leitura, a chamada do binário só para gravar um arquivo e para cifrar a senha, a chave do servidor SFTP e o motivo da falha em uma palavra |
| [`aba_destinos.py`](../../painel/aba_destinos.py) | Aba Destinos: um cartão por destino, os formulários, a escolha do tipo do remoto do rclone, a escolha do destino, o teste, o pedido de passada, a remoção e o envio de um arquivo pelo botão da aba Arquivos |
| [`recursos.py`](../../painel/recursos.py) | Recursos do servidor e de cada container da stack: leitura do processador, da memória e da rede do FTP, do grupo de controle do painel e do que o ftp e o nginx publicam, e o histórico dos últimos 10 minutos, guardado na memória |
| [`aba_servidor.py`](../../painel/aba_servidor.py) | Aba Servidor: os containers da stack, com o uso contra o alocado, os cartões de processador, memória, disco e rede do servidor, e a faixa de resumo da Visão geral |
| [`aba_administradores.py`](../../painel/aba_administradores.py) | Administradores do painel: criação pelo formulário de Novo usuário, troca de senha, troca de nome e remoção; a lista é a da aba Usuários |
| [`aba_seguranca.py`](../../painel/aba_seguranca.py) | Aba Segurança |
| [`enderecos.py`](../../painel/enderecos.py) | Bloqueio por endereço: a escrita única do endereço, IPv4 ou IPv6, a leitura dos bloqueios de endereço e de prefixo em vigor, a contagem dos erros de usuário e senha de cada endereço, zerada na entrada certa, e o pedido de bloqueio ao `allsafe-ftp-user` |
| [`aba_bloqueios.py`](../../painel/aba_bloqueios.py) | Aba Bloqueios: lista dos endereços e dos prefixos bloqueados, busca, bloqueio à mão de endereço ou de prefixo, mudança de prazo e desbloqueio (`GET /bloqueios`, `GET` e `POST /bloqueios/novo`, `GET /bloqueios/endereco?ip=<endereço>`, `POST /bloqueios/prazo` e `POST /bloqueios/liberar`) |
| [`aba_atividade.py`](../../painel/aba_atividade.py) | Aba Log |

Os módulos não gravam nada na imagem: a raiz do container é somente leitura e o Python roda sem gerar `.pyc`. O `./scripts/validate.sh` confere a sintaxe de todos, que nenhum usa nome que não definiu nem importou e que cada texto das telas tem tradução no catálogo do inglês.

</details>

---

⬅️ [Backup e restauração](backup.md) · 🏠 [Documentação](README.md) · ➡️ [Fotos da aplicação](aplicacao/README.md)
