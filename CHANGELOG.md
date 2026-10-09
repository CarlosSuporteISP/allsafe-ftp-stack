# 🏷️ Changelog — allsafe-ftp-stack

Histórico de mudanças por versão. A versão segue o formato `MAJOR.MINOR.PATCH` e fica registrada em [`VERSION`](VERSION).

↩ [README do projeto](README.md)

## [Não lançado]

Nada ainda.

## [0.25.0] - 2026-10-09

A cópia de segurança passa a sair cifrada: quem pegar o arquivo não lê nada dele sem a chave privada, que fica em `.secrets/` e deve ser guardada também fora do servidor.

### Adicionado

- **Cópia de segurança cifrada**: o `scripts/backup.sh` grava `<STACK_NAME>-AAAAMMDD-HHMMSS.tar.gz.age`, cifrado com `age` para a chave pública de `.secrets/backup-chave-publica.txt`. A cifra é feita em fluxo, dentro do container da cópia: nada sem cifra chega ao disco. Não há opção para desligar.
- **Par de chaves da cópia em `.secrets/`**: o `deploy.sh` cria `backup-chave-privada.txt` e `backup-chave-publica.txt` (`0600`) quando nenhum dos dois existe, nunca regrava a privada e refaz a pública a partir dela a cada execução. Com só a pública no servidor, ele faz cópia e não restaura.
- **Restauração com a chave**: o `scripts/restaurar.sh` abre a cópia inteira com `.secrets/backup-chave-privada.txt` antes de tocar em qualquer coisa. Sem a chave, com a chave de outra instalação, com a cópia cortada ou com um byte trocado, para com `Nada foi tocado.`
- Caso 53 da bateria funcional e casos 90, 91 e 92 de segurança: cópia cifrada e ilegível sem a chave, recusas da restauração, cópia antiga sem cifra e regras das chaves. O caso 77 de segurança passa a pedir pela web também a chave privada da cópia, e os casos 14, 39 e 10 de segurança e o 21 funcional contam os dois arquivos novos de `.secrets/`.

### Alterado

- **Cópia antiga, sem cifra, continua restaurando**, com o aviso `esta cópia não é cifrada`, e o `--listar` a marca com `(sem cifra: feita antes da 0.25.0)`.
- **Saída do `backup.sh`**: a linha `Cópia gravada` mostra o tamanho e `cifrada`, sem a contagem de itens, e uma linha nova lembra de guardar a chave privada fora do servidor. A contagem de itens segue na saída do `restaurar.sh`.
- **O `tar` deixa de ser exigido no host pelo `backup.sh`**: o empacotamento já era feito no container.
- **Imagem do FTP com o pacote `age` do Debian**: de 208 MB para 218 MB. As imagens do painel e do nginx não mudam e nada novo é instalado no host.

### Corrigido

- **Erros do container da cópia apareciam pela metade**: uma linha do `backup.sh` descartava as mensagens de erro do `tar` dali em diante. Agora o motivo da falha aparece inteiro.

### Segurança

- Uma cópia que saia do servidor (mídia perdida, outra máquina, pasta de rede) deixa de entregar os hashes das senhas, as chaves privadas dos certificados e os arquivos dos equipamentos. Cada bloco da cópia é autenticado: alteração ou corte faz a abertura falhar.

### Ao atualizar

- Rode `./deploy.sh`: ele reconstrói a imagem do FTP, com o `age`, e cria o par de chaves da cópia. Nada muda no `.env` nem nos dados.
- **Guarde `.secrets/backup-chave-privada.txt` fora do servidor**, em um cofre de senhas, separada das cópias. Sem ela nenhuma cópia cifrada abre, e não há como recuperá-la.
- As cópias feitas antes desta versão ficam como estão em `BACKUP_DIR`, sem cifra. Faça uma cópia nova e apague as antigas.
- Rotina que procura as cópias por `*.tar.gz` passa a procurar por `*.tar.gz.age`; o padrão `*.tar.gz*` da documentação pega os dois.

## [0.24.2] - 2026-10-09

Revisão de usabilidade do painel: o topo deixa de repetir o nome da aba, todo cartão da Visão geral leva ao detalhe, e as telas ficam confortáveis no celular.

### Corrigido

- **Título repetido nas abas**: em tela larga, o título da página dizia o mesmo que a aba marcada no topo, com o mesmo ícone. O título continua no documento para leitor de tela e aparece em tela estreita, onde as abas rolam para o lado.
- **Cartões da Visão geral sem saída**: só Usuários e Certificado levavam ao detalhe. Agora os cinco cartões terminam num atalho, com o mesmo peso e na mesma posição: Segurança, Usuários e Arquivos.
- **Atalho "ver a lista" pequeno demais**: os atalhos dos cartões ganharam tamanho de texto normal, peso e seta.
- **Dados para configurar o equipamento**: a tabela esticava o valor para longe do rótulo; virou uma lista de rótulo e valor juntos, e o endereço do servidor não quebra mais no meio.
- **Topo no celular**: a marca e a saída ficam numa linha e as abas em outra, rolando para o lado, em vez de empilhar em várias linhas. Em tela larga, o topo se alinha à coluna do conteúdo.
- **Alvos de toque**: abas, botões e campos passam a ter 44 px de altura; os botões das tabelas ganham essa altura em tela de toque.

### Alterado

- **Avisos, erros e confirmações** deixam a faixa colorida na lateral e ficam com a borda inteira na cor do estado.
- **Texto do rodapé e do cabeçalho das tabelas** sobe para 14 px, e os cartões ficam com cantos de 12 px.
- **Cores dos botões e larguras** passam a variáveis da folha de estilo, sem valor solto repetido.
- **Fotos da aplicação refeitas** nesta versão, com o topo e a Visão geral novos.

## [0.24.1] - 2026-10-07

Duas correções de leitura nas telas de usuário do painel, e a documentação revisada de ponta a ponta: fotos refeitas, guia da aplicação com as telas novas e diagramas redesenhados.

### Corrigido

- **Caixa "Equipamento sem suporte a TLS" em Novo usuário**: o texto ficava repartido em pedaços ao lado da caixa; agora é um bloco só, com "sem TLS" em destaque.
- **Endereço de origem no cartão Bloqueios da tela Editar**: o endereço quebrava em duas linhas; agora fica inteiro numa linha.

### Alterado

- **Fotos da aplicação refeitas** nesta versão: 38 no guia da aplicação e 7 no README, com a coluna TLS, a etiqueta `inicial` e as telas das versões `0.21.0` a `0.24.0`.
- **Guia da aplicação** com as telas que faltavam: Editar, Limites, Bloqueios, Renomear e Apagar arquivo, usuário novo já dispensado do TLS, cartão TLS e remoção do usuário inicial com a pasta.
- **Diagramas redesenhados** para caber na tela sem linha cruzada: o fluxograma do painel foi dividido em dois, a entrada e os pedidos de uma sessão aberta, e o mapa da arquitetura deixou o `.env`, os segredos e o registro para o modelo da subida. As sequências escritas abaixo de cada um acompanham os números novos.

## [0.24.0] - 2026-10-07

O equipamento sem suporte a TLS passa a ser liberado pelo painel, usuário por usuário, ao criar ou ao editar, sem mexer no `.env`. Enquanto ninguém é dispensado, nada muda: a sessão sem TLS é recusada antes de a senha ser enviada.

### Adicionado

- **Caixa "Equipamento sem suporte a TLS" em Novo usuário**: o usuário já nasce dispensado do TLS, com o alerta de que a senha e os arquivos dele passam em texto puro.
- **Cartão TLS na tela Editar** do usuário, para dispensar e para voltar a exigir, além dos botões **Dispensar TLS** e **Exigir TLS** da aba Usuários.
- Caso 52 da bateria funcional e caso 89 de segurança: usuário criado já dispensado, cartão do TLS, troca do modo de entrada com sessões abertas e opção sem efeito.

### Alterado

- **`FTP_TLS_EXCECOES=sim` passa a ser o padrão.** A opção sozinha não libera ninguém: o servidor exige TLS de todos até um administrador dispensar um usuário.
- **Sessão sem TLS só é aceita enquanto houver usuário dispensado.** Sem nenhum, o Pure-FTPd recusa a sessão sem TLS antes da senha, como no modo `2` puro. Ao dispensar o primeiro, o serviço `ftp` troca o processo que escuta a porta, sem reiniciar o container e sem derrubar as sessões em andamento, e volta ao modo fechado quando o último volta a ser obrigado. Antes, com a opção ligada, toda sessão sem TLS era aceita até a recusa do porteiro, mesmo sem nenhum dispensado.
- **Fora das condições, a opção fica sem efeito em vez de impedir a subida.** Com `FTP_TLS_MODE` diferente de `2` ou com `REDE_PERMITIR_IP_PUBLICO=sim`, a stack sobe, ninguém é dispensado, e o `./deploy.sh`, o registro do container e o painel dizem o motivo. Só o valor fora de `sim` e de `nao` continua recusado.
- O resumo e os avisos do `./deploy.sh` e a linha `FTP pronto` do registro dizem quantos usuários estão dispensados; a aba Segurança e a Visão geral do painel seguem o mesmo texto.

### Segurança

- A senha de um equipamento configurado sem TLS por engano deixa de passar em texto puro nas instalações em que ninguém foi dispensado: o servidor recusa na resposta ao nome do usuário, antes de a senha ser enviada.
- O serviço `ftp` encerra o container se o observador da lista dos dispensados parar, como já fazia com o `pure-authd`, o vigia e o `pure-ftpd`.

### Ao atualizar

Instalação anterior a esta versão traz `FTP_TLS_EXCECOES=nao` gravado no `.env`, e o `./deploy.sh` respeita o que está lá: a opção continua fora do painel. Para tê-la, troque para `FTP_TLS_EXCECOES=sim` e rode `./deploy.sh`. Quem já usava `sim` não precisa fazer nada: os usuários dispensados continuam dispensados.

## [0.23.0] - 2026-10-07

O usuário inicial do FTP passa a ser removido pelo painel, como os outros, com ou sem a pasta. Ele é criado uma vez, na instalação, e não volta sozinho.

### Adicionado

- **Remover o usuário inicial pelo painel.** O usuário de `FTP_USER` ganha o botão **Remover** na aba Usuários, com a mesma tela dos demais: a caixa para apagar também a pasta pede a senha do administrador. Pelo terminal, `./manage-user.sh del <usuario>` faz o mesmo, sem apagar a pasta.
- Caso 51 da bateria funcional: remoção sem e com a pasta, subidas seguintes sem o usuário, criação de novo com o mesmo nome e volta pelo terminal.

### Alterado

- **O usuário inicial é criado uma vez.** O serviço `ftp` deixa a marca `/auth/usuario-inicial.criado` ao criá-lo e, nas subidas seguintes, não o recria se ele foi removido: o log diz `removido pelo administrador; não é recriado`. Antes, ele voltava a cada subida, com a senha do arquivo do segredo.
- **Criado de novo com o mesmo nome, vale a senha informada**, no painel ou no `./manage-user.sh add`, até o arquivo `.secrets/ftp-usuario-inicial-senha.txt` ser alterado.
- `./scripts/validate.sh --runtime` aceita o usuário inicial removido pelo administrador, e o resumo do `./deploy.sh` diz quando ele não existe mais.
- A resposta `409` do painel para a remoção do usuário inicial deixa de existir.

### Ao atualizar

Nada a fazer. Na primeira subida depois da atualização, o usuário inicial que já existe recebe a marca e continua como está.

## [0.22.2] - 2026-10-07

O padrão das três pastas da stack deixa de ser a pasta do computador onde ela é desenvolvida e passa a ser `/srv/allsafe-ftp-stack`. Instalação que já existe não muda: o `.env` dela continua valendo.

### Alterado

- **Pastas padrão em `/srv/allsafe-ftp-stack`.** No `.env.example`, `DATA_DIR`, `BACKUP_DIR` e `TEMP_DIR` passam a `/srv/allsafe-ftp-stack/data`, `/srv/allsafe-ftp-stack/backups` e `/srv/allsafe-ftp-stack/tmp`. Quem instala sem ser root cria a pasta de cima uma vez (`sudo install -d -o "$USER" /srv/allsafe-ftp-stack`) ou aponta as três para outro lugar no `.env`.
- **`deploy.sh` diz o que fazer quando não consegue criar a pasta de dados**: a mensagem traz o comando que cria a pasta de cima para o usuário e a alternativa de trocar as três pastas. Nada é construído nem sobe antes disso.
- **Guias sem caminho de um computador**: os comandos de [Backup e restauração](doc/backup.md), [Operação](doc/operacao.md) e [Solução de problemas](doc/solucao-de-problemas.md) leem `DATA_DIR`, `BACKUP_DIR` e `TEMP_DIR` do `.env`, e [Configuração](doc/configuracao.md) mostra o padrão novo.

### Adicionado

- **`scripts/validate.sh` recusa pasta pessoal em arquivo do repositório**: caminho que só existe em um computador não é publicado. O `.env` local fica fora da conferência.
- Caso 88 de segurança na bateria: o padrão do `.env.example`, a recusa do `validate.sh` com um arquivo plantado e a mensagem do `deploy.sh` para a pasta que não dá para criar.

### Ao atualizar

Nada a fazer. Instalação nova feita a partir desta versão usa `/srv/allsafe-ftp-stack`, salvo se o `.env` disser outro lugar.

## [0.22.1] - 2026-10-07

A frente web ficou mais rápida, com medida de antes e depois na instância de teste: o painel passa a abrir em HTTP/2, o estilo vai comprimido e a conexão do navegador é mantida entre um clique e outro. Nenhuma tela, variável ou comando mudou.

### Alterado

- **HTTP/2 no painel.** O nginx fala HTTP/2 com o navegador que pede e continua em HTTP/1.1 com quem não pede. A página, o estilo e as imagens chegam por uma conexão só, com um aperto de mão do TLS: a tela de entrada inteira passou de 11,0 ms, em cinco conexões, para 8,8 ms, em uma. Cada conexão leva no máximo 16 pedidos ao mesmo tempo, o mesmo número do limite de conexões por endereço.
- **Estilo comprimido.** O `estilo.css` vai com 2175 bytes para o navegador que aceita gzip, em vez de 6957. A cópia comprimida é feita uma vez, na construção da imagem do nginx: nada é comprimido a cada pedido.
- **Conexão parada mantida por 60 segundos**, em vez de 15. O clique feito depois de 20 ou de 45 segundos parado reaproveita a conexão: 0,8 ms, contra 2,0 ms com conexão nova.
- **O que a medida deixou como estava.** Página do painel continua sem compressão, porque traz o token do formulário. As imagens da marca continuam revalidadas a cada uso, para a troca da marca aparecer na hora: a revalidação custa 0,04 ms. O nginx continua com um processo em todos os portes, e o cache de arquivo aberto não mostrou diferença.
- **Custo medido do HTTP/2 no download.** O arquivo de 300 MiB baixado pelo painel levou 0,69 s em HTTP/2 e 0,45 s em HTTP/1.1, com o nginx no limite de meio processador. Os dois ficam acima do que uma rede de 1 Gbit/s entrega.

### Adicionado

- **Casos de teste 50 (funcional) e 87 (segurança)**, em `tests/etapas/25-http2-e-compressao.sh`: os dois protocolos com a mesma sessão, o estilo comprimido e inteiro, a tela de entrada em uma conexão, a página com token sempre sem compressão, a cópia comprimida sem endereço e os limites de pedidos e de tamanho nos dois protocolos, com o campo de 8300 bytes recusado e o de 4000 aceito em cada um. A bateria passa a 50 casos funcionais, 87 de segurança e 13 de rede.

### Segurança

- **Limite de tamanho por endereço e por cabeçalho: 5 KiB, com 20 KiB no conjunto.** Antes valia o padrão do nginx, 8 KiB por campo e 32 KiB no conjunto. Em HTTP/2 o nginx mede o campo ainda comprimido, e com 8 KiB passavam endereço e cabeçalho de até 13 mil bytes; com 5 KiB, nenhum campo acima de 8192 bytes passa em nenhum dos dois protocolos. Em HTTP/1.1 a recusa continua com `414` ou `400`; em HTTP/2, o nginx encerra a conexão. Achado pela bateria, no caso 75 de segurança, que passa a fazer cada pedido grande ou malformado nos dois protocolos.

### Ao atualizar

Rode `./deploy.sh`: ele refaz a imagem do nginx, com a cópia comprimida do estilo, e sobe a configuração nova. Nada muda no `.env`, nos segredos nem nos dados.

## [0.22.0] - 2026-10-07

O FTP passa a bloquear quem erra a senha vezes demais: o endereço que erra a senha de um usuário cinco vezes em 15 minutos fica bloqueado para aquele usuário pelo mesmo tempo. O administrador ajusta o limite e o tempo de cada usuário no painel, vê quem está bloqueado e desbloqueia. O registro do container passa a trazer cada entrada e cada transferência do FTP.

### Adicionado

- **Bloqueio por tentativa no FTP.** As senhas erradas são contadas por usuário e por endereço de origem. No limite, o endereço fica bloqueado para aquele usuário: até o fim do prazo, nem a senha certa entra dali. Os outros endereços, os outros usuários e a entrada do usuário no painel continuam como estavam. A entrada certa zera a contagem.
- **Variáveis `FTP_BLOQUEIO_TENTATIVAS` e `FTP_BLOQUEIO_MINUTOS`** no `.env`, com o padrão da stack: `5` senhas erradas (de 0 a 100; `0` desliga) e `15` minutos (de 1 a 1440). Os minutos são também o tempo em que as senhas erradas se somam.
- **Limite próprio de cada usuário, no cartão Limites da tela Editar:** os campos **Senhas erradas no FTP até o bloqueio** e **Minutos de bloqueio**. Em branco, vale o padrão da stack; `0` no primeiro quer dizer que o usuário nunca é bloqueado.
- **Cartão Bloqueios na tela Editar e marca `bloqueado` na lista de usuários.** O cartão mostra cada endereço bloqueado, as senhas erradas, a hora do bloqueio e até quando ele vale, com o botão **Desbloquear**.
- **Comandos `./manage-user.sh bloqueios [usuario]` e `./manage-user.sh desbloquear <usuario> [origem]`**, e as chaves `tentativas` e `minutos` no comando `limites`.
- **Vigia do FTP (`ftp/vigia.pl`).** Processo novo do serviço `ftp`, que recebe o registro do `pure-ftpd` dentro do container, conta as senhas erradas e grava os bloqueios em `/auth/bloqueios`. É escrito em Perl, com o `perl-base` que a imagem do Debian já traz: nenhum pacote novo.
- **Entradas do FTP no registro do container.** Cada entrada, cada senha errada e cada bloqueio sai em uma linha `vigia:`, com o usuário e o endereço, sem senha.
- **Transferências do FTP no registro do container.** Cada arquivo enviado, baixado, renomeado e apagado pelo FTP sai em uma linha `vigia: envio:`, `vigia: download:`, `vigia: renomeado:` ou `vigia: apagado:`, com o usuário, o endereço, o arquivo e, nos dois primeiros, o tamanho.
- **Evento `bloqueio_removido` na auditoria**, a linha `Bloqueio do usuário no FTP removido` na aba Atividade e o item **Bloqueio por tentativa no FTP** na aba Segurança, com quem está bloqueado agora.
- **Casos de teste 47, 48 e 49 (funcional) e 85 e 86 (segurança).** A bateria passa a 49 casos funcionais, 86 de segurança e 13 de rede.

### Alterado

- **O `pure-authd` e o porteiro rodam sempre.** Antes só rodavam com `FTP_TLS_EXCECOES=sim`. O porteiro (`ftp/porteiro.sh`, antes `ftp/porteiro-tls.sh`) confere a cada entrada se o usuário está bloqueado para o endereço e, com a exceção de TLS ligada, se ele pode entrar sem TLS.
- **O serviço `ftp` tem três processos, e a queda de qualquer um encerra o container**, que o Docker sobe de novo: vigia, `pure-authd` e `pure-ftpd`. A mensagem de `FALHA` passa a dizer qual saiu. O healthcheck exige os dois soquetes antes de abrir a porta.
- **Trocar a senha de um usuário tira os bloqueios dele**, e mudar o limite ou os minutos também. Remover o usuário tira os bloqueios e os limites.
- **O backup leva os bloqueios em vigor**, junto com o resto de `auth/`. Bloqueio vencido ou com conteúdo fora do formato não bloqueia ninguém.
- **Guia de segurança.** Seção nova do bloqueio por tentativa, com o fluxograma, o que conta e o que não conta como senha errada e os limites da proteção; a recomendação de `fail2ban` saiu, porque o bloqueio agora é da própria stack.

### Corrigido

- **Registro das transferências do FTP.** A opção `-O clf:/dev/stdout` do `pure-ftpd` nunca gravou linha nenhuma: o servidor não abre o arquivo de registro por link simbólico, e `/dev/stdout` é um. O registro do container não trazia as transferências, embora a documentação dissesse que sim. A opção saiu, e as transferências passam a sair pelo vigia.

### Segurança

- **Nome de arquivo no registro.** O nome vem do cliente: caractere de controle e de direção do texto vira `?` antes de a linha ser escrita, o nome vai por último na linha, o tamanho é lido do fim do aviso do servidor e o tipo do aviso, do começo dele. Um nome escolhido pelo cliente não quebra a linha, não se passa por outro campo nem faz um arquivo apagado sair como enviado.
- **Não contam como senha errada:** a rede interna da stack, de onde o painel confere a senha de quem entra nele; a entrada sem TLS recusada pelo porteiro; a tentativa feita durante o bloqueio; o nome que não está no cadastro e o nome fora da regra. Assim, quem não tem a senha não estende o bloqueio de um usuário nem enche a lista com nomes inventados.
- **Quem pode ser bloqueado de propósito.** Quem alcança a porta do FTP a partir do mesmo endereço de um equipamento pode errar a senha dele e bloqueá-lo para aquele endereço. O bloqueio não alcança os outros endereços, e o administrador o tira no painel; para a conta que não pode parar, use `0` no limite do usuário.
- **Entrada fora do horário do usuário conta como senha errada**, porque o servidor responde às duas do mesmo jeito.

### Ao atualizar

Rode `./deploy.sh`. O bloqueio já sobe ligado, com 5 senhas erradas e 15 minutos. Para mudar o padrão, defina `FTP_BLOQUEIO_TENTATIVAS` e `FTP_BLOQUEIO_MINUTOS` no `.env`; para desligar, `FTP_BLOQUEIO_TENTATIVAS=0`. Equipamento que hoje tenta entrar com senha errada gravada passa a ser bloqueado: confira o registro (`docker compose logs ftp | grep 'vigia: entrada recusada'`) depois da subida.

## [0.21.0] - 2026-10-07

Cada usuário do FTP passa a ter limites próprios, gravados pelo administrador no painel: quantas sessões abre, a que velocidade baixa e envia, em que horário entra e quantos arquivos baixa por vez pelo painel. Vale para a conta de um equipamento e para a de uma pessoa.

### Adicionado

- **Limites por usuário, na tela Editar da aba Usuários.** O cartão **Limites** tem cinco campos, todos opcionais: sessões no FTP ao mesmo tempo, taxa de download e taxa de envio em KB/s, horário de entrada (início e fim, com janela que atravessa a meia-noite) e downloads ao mesmo tempo pelo painel. Campo em branco deixa o usuário sem aquele limite. Na lista, a marca **limites** mostra quem tem limite próprio e, ao passar o ponteiro, quais.
- **Comando `./manage-user.sh limites <usuario>`.** Com pares `chave=valor` (`sessoes`, `download`, `envio`, `horario`, `baixar`), grava; sem par, mostra os limites do usuário; valor vazio tira o limite. É o mesmo comando que o painel chama.
- **A taxa de download vale também no painel.** O arquivo que o usuário baixa em **Meus arquivos** sai na mesma taxa do FTP. O download do administrador não tem taxa.
- **Evento `limites_alterados` na auditoria**, com o administrador, o usuário e os cinco valores, e a linha `Limites do usuário alterados` na aba Atividade.
- **Módulo `limites.py` no painel**, que lê os limites, confere o formulário e monta o resumo da lista.
- **Casos de teste 45 e 46 (funcional) e 84 (segurança).** A bateria passa a 46 casos funcionais, 84 de segurança e 13 de rede.

### Alterado

- **Quem aplica os limites do FTP é o próprio Pure-FTPd.** Sessões, taxas e horário ficam no cadastro dos usuários virtuais (`pure-pw usermod -y`, `-t`, `-T` e `-z`); o limite de downloads pelo painel fica em `/auth/limites.lista`, com dono `root` e modo `0600`. Os limites valem na próxima entrada do usuário.
- **Limite do FTP trocado encerra a sessão do usuário no painel**, como já acontecia com a senha e com a pasta. Trocar só o limite de downloads pelo painel não encerra.
- **Entrada no painel fora do horário ou com as sessões ocupadas.** Quem confere a senha do painel é o FTP: o usuário fora do horário dele, ou com todas as sessões dele ocupadas, recebe a mesma resposta de usuário ou senha errados.
- **Limite de downloads ao mesmo tempo.** Continua em 2 por usuário do FTP quando o campo está em branco, e passa a ser o valor do campo, de 1 a 8, quando preenchido. Acima dele, a resposta continua `503` com `Retry-After`.
- **Usuário removido sai da lista dos limites**, e os limites do usuário inicial atravessam o reinício do servidor.

### Observações

- **Taxa de envio e arquivo pequeno.** Com taxa de envio, o Pure-FTPd segura cada arquivo enviado por pelo menos 256 ÷ taxa segundos, seja qual for o tamanho: a 50 KB/s, cerca de 5 segundos por arquivo. Para equipamento que envia muitos arquivos pequenos, use taxa alta ou deixe o campo em branco.
- **Fuso do horário.** O horário é conferido no relógio do servidor FTP, no fuso da variável `TZ`.

## [0.20.0] - 2026-10-06

O painel passa a renomear e apagar arquivo e pasta, e a remover o usuário do FTP junto com a pasta dele. O que antes pedia um cliente de FTP ou o terminal do servidor agora é feito pelo navegador.

### Adicionado

- **Renomear, na aba Arquivos.** O botão **Renomear** de cada linha troca o nome do arquivo ou da pasta, dentro da mesma pasta. O nome novo segue a regra do nome de pasta, e renomear nunca substitui outro item: nome que já existe é recusado.
- **Apagar, na aba Arquivos.** O botão **Apagar** abre a tela de confirmação, que mostra o que vai sair e, para pasta, quantos arquivos ela tem. Apagar pede a caixa de confirmação marcada e **a senha atual do administrador**. A pasta sai com tudo o que tem dentro. **Não há lixeira:** o que foi apagado só volta do backup.
- **Remover o usuário com a pasta, na aba Usuários.** A tela **Remover** ganha a caixa **Apagar também a pasta e tudo o que há nela**, que também pede a senha atual. Sem a caixa, tudo continua como antes: a conta sai e os arquivos ficam.
- **Eventos `item_renomeado` e `item_apagado` na auditoria**, com o administrador, o tipo e o caminho, e as linhas `Arquivo ou pasta renomeado` e `Arquivo ou pasta apagado` na aba Atividade. O `usuario_removido` passa a levar `pasta=` quando a pasta saiu junto.
- **Casos de teste 43 e 44 (funcional) e 82 e 83 (segurança).** A bateria passa a 44 casos funcionais, 83 de segurança e 13 de rede.

### Alterado

- **Pasta de usuário do FTP só sai junto com o usuário.** A aba Arquivos não renomeia nem apaga a pasta que é a de um usuário, nem a que tem a de um usuário dentro: o cadastro ficaria apontando para uma pasta que não existe. O que está dentro dela é renomeado e apagado normalmente.
- **Remoção com a pasta recusada em pasta dividida.** A caixa não aparece, e o pedido é recusado, quando outro usuário usa a mesma pasta, uma de dentro ou uma de fora dela.
- **Limites do apagamento.** Um pedido apaga até 50.000 itens ou trabalha por até 20 segundos; pasta maior é apagada em mais de um pedido, com a tela `Apagado em parte` e o botão de repetir. O painel faz um apagamento por vez.
- **Link simbólico e arquivo especial.** Continuam sem abrir nem baixar, e passam a poder ser renomeados e apagados. Apagar um link apaga só o link, nunca aquilo para onde ele aponta.
- **Usuário do FTP no painel.** Nada muda para ele: continua só navegando e baixando na própria pasta.
- **Código do painel.** A conferência da senha atual, que era da aba Administradores, vai para o módulo `confirmacao.py`, usado também por tudo o que apaga.
- **Ao atualizar:** nada muda no `.env`, nos segredos nem nos dados. São recriados os três containers.

### Segurança

- O caminho de renomear e de apagar passa pelas mesmas conferências da leitura: `..`, caminho absoluto e byte nulo recebem `400`, e caminho por dentro de link simbólico, `403`. A ação é feita em relação à pasta já aberta, e o apagamento não segue link.
- A senha atual errada em um apagamento conta para o bloqueio do endereço, como a da entrada: cinco erros em 15 minutos.

## [0.19.0] - 2026-10-06

O painel passa a editar o usuário do FTP: troca a pasta de quem já existe e troca a senha e a pasta do usuário inicial, que antes só mudava pelo arquivo do segredo.

### Adicionado

- **Tela Editar, na aba Usuários.** O botão **Editar** de cada usuário abre a tela dele, com a troca da pasta. Valem as regras da criação: a pasta fica dentro de `DATA_DIR/dados`, é criada se não existir, e link simbólico ou arquivo no caminho são recusados. A troca vale na entrada seguinte do usuário, não mexe na senha e **não move nem apaga arquivo**: o que estava na pasta anterior continua nela.
- **`./manage-user.sh pasta <usuario> <pasta>`.** A mesma troca pelo terminal, com as mesmas regras e a resposta `Pasta do usuario <nome>: /data/<pasta>. Os arquivos de /data/<anterior> continuam la.`
- **Senha e pasta do usuário inicial pelo painel.** O usuário inicial (`FTP_USER`) ganha os botões **Editar** e **Trocar senha**, e o `./manage-user.sh passwd` vale para ele. Continua sem o botão **Remover**.
- **Evento `pasta_trocada` na auditoria**, com o administrador, o usuário, a pasta nova e a anterior, e a linha `Pasta do usuário trocada` na aba Atividade.
- **Casos de teste 41 e 42 (funcional) e 81 (segurança).** A bateria passa a 42 casos funcionais, 81 de segurança e 13 de rede.

### Alterado

- **Senha do usuário inicial: vale a troca mais recente.** O serviço `ftp` deixa de regravar a senha do segredo em toda subida. Trocada pelo painel ou pelo `manage-user.sh passwd`, a senha nova sobrevive aos reinícios; o arquivo `.secrets/ftp-usuario-inicial-senha.txt` volta a valer na subida seguinte a uma alteração dele. Sem troca pelo painel, nada muda: a senha do arquivo continua sendo aplicada. Veja [Segredos](doc/segredos.md#trocar-a-senha).
- **Dois arquivos novos em `DATA_DIR/auth`**, modo `0600`: `senha-inicial.aplicada`, uma impressão do segredo aplicado (`sha512-crypt` com sal próprio, nunca a senha), e `senha-inicial.trocada`, só com o nome do usuário. Os dois entram no backup, com o cadastro.
- **Resumo do `deploy.sh`.** Com a senha do usuário inicial trocada pelo painel, a linha do FTP diz `senha trocada pelo painel` e avisa que a do arquivo volta a valer quando ele for alterado.
- **Pasta do usuário inicial.** O entrypoint do FTP só cria `DATA_DIR/dados/<FTP_USER>` enquanto ela é a pasta dele; trocada, a pasta escolhida é mantida nas subidas seguintes.
- **Custo das senhas, na aba Segurança.** A referência passa a ser o custo do porte, calculado de `FTP_MAX_CLIENTS`, e não mais o da senha do usuário inicial. O resultado mostrado é o mesmo.
- **Sessão do usuário do FTP no painel.** A troca de pasta encerra as sessões dele, como a troca de senha já fazia.
- **Ao atualizar:** nada muda no `.env`, nos segredos nem nos dados; a senha de cada usuário continua a mesma. São recriados os containers do FTP e do painel. O usuário inicial continua na pasta `DATA_DIR/dados/<FTP_USER>` e com a senha do arquivo do segredo.

## [0.18.9] - 2026-10-06

O projeto ganha a política de segurança, sem endereço fixo: quem acha uma falha é mandado para o contato que cada instalação publica, definido por quem a opera em `SEGURANCA_CONTATO_EMAIL`, no `.env`.

### Adicionado

- **[`SECURITY.md`](SECURITY.md).** Diz para quem avisar de uma falha, o que mandar, o que não mandar e quais versões recebem correção. O contato não fica escrito no arquivo: é o que a instalação publica em `/.well-known/security.txt`, com a variável `SEGURANCA_CONTATO_EMAIL`, que existe desde a `0.18.0`.
- **Linha do contato no resumo do `deploy.sh`.** O resumo passa a terminar com `Contato de segurança: <e-mail>, publicado em /.well-known/security.txt do painel.` ou, com a variável vazia, `Contato de segurança: não publicado.`, com o que preencher. A instalação não é bloqueada.
- **Conferência no `scripts/validate.sh`.** O `SECURITY.md` tem de existir, citar a variável e não trazer endereço de e-mail fixo; a linha nova é `política de segurança OK: SECURITY.md aponta para SEGURANCA_CONTATO_EMAIL, sem endereço fixo`.

### Alterado

- **Comentário da variável no [`.env.example`](.env.example) e guia de [Configuração](doc/configuracao.md#contato-de-seguranca)** dizem que a política do projeto aponta para o contato da instalação. [Segurança](doc/seguranca.md#contato-de-seguranca), [Instalação](doc/instalacao.md), [Scripts](doc/scripts.md#deploy) e o índice da [documentação](doc/README.md) acompanham.
- **Caso 36 da bateria** confere também as duas linhas do resumo do `deploy.sh`, com o contato e sem ele. O número de casos não muda.
- **Ao atualizar:** nada muda no `.env`, nos segredos, no cadastro nem nos dados; a variável continua vazia até ser preenchida. É recriado o container do painel, porque a imagem dele leva o número da versão; o do FTP continua em execução.

## [0.18.8] - 2026-10-06

A regra da marca fica com um pedido só: a stack é livre para usar e distribuir, e a logo da ALL-SAFE sai quando houver contrato ou venda para terceiros. Nenhum código da stack mudou.

### Alterado

- **[`MARCA.md`](MARCA.md) reescrito.** Usar, copiar, alterar e distribuir continua livre pela [Licença Apache 2.0](LICENSE), de graça ou cobrando, e não depende de contrato com a ALL-SAFE. O pedido é um: quem entrega a stack em contrato ou a vende para terceiros tira ou troca a logo e o ícone. No uso próprio e na distribuição de graça, os dois podem ficar.
- **Linha de autoria do rodapé.** Continua vindo de fábrica no painel, mas deixa de ser pedida de quem altera o código. O [`NOTICE`](NOTICE) continua acompanhando toda cópia, como a licença determina.
- **[`NOTICE`](NOTICE), seção Licença do [README](README.md#licenca) e [Marca do painel](doc/painel.md#marca)** com o mesmo texto.
- **Ao atualizar:** nada muda no `.env`, nos segredos, no cadastro nem nos dados. O `NOTICE` entra nas três imagens: os três containers são recriados.

## [0.18.7] - 2026-10-06

Sem alteração. A tag `v0.18.7` foi criada por engano no commit da `0.18.6` e, como tag publicada não é apagada nem movida, a numeração seguiu para a `0.18.8`. Não tem Release.

## [0.18.6] - 2026-10-06

Os créditos do README passam a citar o nginx e o Python, que a stack usa desde as versões `0.5.0` e `0.3.0`. Nenhum código da stack mudou.

### Adicionado

- **nginx e Python nos créditos.** A tabela dos [projetos oficiais usados](README.md#creditos) ganha os dois, com o uso de cada um na stack, a licença, a página oficial e o código-fonte.

### Corrigido

- **Frase "Ao atualizar" das notas `0.18.3` e `0.18.5`.** As duas diziam que os três containers eram recriados. Medido na atualização da `0.18.2` para a `0.18.5`: o do FTP continuou em execução, porque nada do que entra na imagem dele mudou nessas versões.

### Alterado

- **Ao atualizar:** nada muda no `.env`, nos segredos, no cadastro nem nos dados. É recriado o container do painel, porque a imagem dele leva o número da versão; o do FTP continua em execução.

## [0.18.5] - 2026-10-05

O painel passa a responder ao método `HEAD`, que a RFC 9110 pede de todo servidor HTTP.

### Corrigido

- **`HEAD` respondia `501` no painel.** Nas telas, no `security.txt` e no download, o `HEAD` agora traz o código e os cabeçalhos que o `GET` traria, sem o corpo. O `HEAD` de um arquivo devolve o tamanho e o nome e não conta como download: não ocupa vaga nem entra na auditoria. Na [tabela de conformidade](doc/seguranca.md#conformidade-rfc), a linha da RFC 9110, seção 9.1, passa de desvio a atendida: 23 normas atendidas e uma parcial.
- **Duração da bateria no guia.** O [guia dos scripts](doc/scripts.md) dizia perto de cinco minutos; a bateria completa leva perto de 25.

### Adicionado

- Um caso na bateria funcional, que passa a 40: `GET` e `HEAD` comparados em doze endereços, sem sessão, com o administrador e com o usuário do FTP, no código e nos cabeçalhos; dezoito `HEAD` de um arquivo sem nenhum registro de download; e o pedido cru, sem nenhum byte depois dos cabeçalhos.

### Alterado

- **Ao atualizar:** nada muda no `.env`, nos segredos, no cadastro nem nos dados. As imagens são reconstruídas e só é recriado o container cuja imagem mudou: o do FTP continua em execução.

## [0.18.4] - 2026-10-05

A documentação ganha as fotos de todas as telas do painel, a tabela de conformidade com as RFCs e a medida do peso de cada serviço. Nenhum código da stack mudou.

### Adicionado

- **Fotos de todas as telas:** [fotos da aplicação](doc/aplicacao/README.md) passa de 12 para 26 capturas, menu por menu, com as abas Arquivos e Administradores, a tela Meus arquivos do usuário do FTP, o download de um backup, a criação de pasta e o TLS por usuário. O [README](README.md#imagens) mostra uma foto de cada aba.
- **Conformidade com as RFCs:** [tabela](doc/seguranca.md#conformidade-rfc) com as 24 normas que a stack usa no FTP, no TLS, no HTTP, nos cookies, no download, nas senhas e nos endereços, o que ela faz de cada uma e a situação: 22 atendidas, uma parcial (a memória do `argon2id`, abaixo da que a RFC 9106 recomenda) e um desvio (o `HEAD` responde `501` nas telas do painel, e a RFC 9110 pede que seja atendido).
- **Peso das linguagens e dos serviços:** no [README](README.md#tecnologias), a memória em repouso, o tamanho das imagens, o tempo de resposta do painel e o tamanho do código, medidos na instância de teste.

### Alterado

- **Fotos refeitas na versão atual:** as 12 capturas que já existiam foram refeitas com a marca, os administradores e as colunas novas da aba Usuários.
- **Ao atualizar:** nada muda no `.env`, nos segredos, no cadastro nem nos dados.

## [0.18.3] - 2026-10-05

A lista de usuários do painel deixa de cortar os botões de ação em telas de computador.

### Corrigido

- **Botão `Remover` cortado na aba Usuários.** Com `FTP_TLS_EXCECOES=sim` a lista ganha a coluna TLS e o botão `Dispensar TLS`. Em janelas de 1024 a 1440 px de largura a tabela passava de 55 a 131 px da área visível: o botão `Remover` ficava cortado e o caminho da pasta quebrava em até oito linhas. Agora os botões de ação descem para a linha de baixo quando falta espaço, a área útil do painel vai de 1100 para 1280 px e as etiquetas (`inicial`, `dividida`, `sem TLS`, `você`) não quebram no meio. Em tela de celular nada muda.

### Alterado

- **Ao atualizar:** nada muda no `.env`, nos segredos, no cadastro nem nos dados. As imagens são reconstruídas e só é recriado o container cuja imagem mudou: o do FTP continua em execução.

## [0.18.2] - 2026-10-05

O projeto passa a ter licença: o código é livre pela Apache 2.0, e o nome, a logo e o ícone da ALL-SAFE têm regra própria.

### Adicionado

- **Licença do código:** [`LICENSE`](LICENSE), com o texto oficial da Licença Apache 2.0. Qualquer pessoa ou empresa pode usar, copiar, alterar e redistribuir a stack, de graça ou cobrando, levando junto o `LICENSE` e o `NOTICE`.
- **Autoria:** [`NOTICE`](NOTICE), com a linha `Desenvolvido pela allsafe.inf.br` e o endereço do GitHub. Ele acompanha toda cópia e toda versão derivada.
- **Regra da marca:** [`MARCA.md`](MARCA.md). No uso próprio, a logo e o ícone podem ficar. Quem vende, revende ou entrega como serviço sem contrato com a ALL-SAFE troca os dois e não liga o produto à empresa. A linha de autoria é mantida em todos os casos.
- As três imagens levam o `LICENSE` e o `NOTICE` em `/usr/share/doc/allsafe-ftp-stack/`.
- Linha `SPDX-License-Identifier: Apache-2.0` no começo de cada arquivo de código.
- `./scripts/validate.sh` confere o `LICENSE` pelo sha256 do texto oficial, a autoria no `NOTICE`, o `MARCA.md` e a linha da licença em cada arquivo de código, e imprime `licença OK: ...`.
- Bateria: etapa 19, com 1 caso funcional: licença e autoria no projeto e dentro das três imagens.
- Documentação: seção [Licença](README.md#licenca) e selo no README, e a regra de venda e revenda em [Marca do painel](doc/painel.md#marca).

### Alterado

- **Ao atualizar:** nada muda no `.env`, nos segredos, no cadastro nem nos dados. As imagens são reconstruídas e os três containers, recriados.

## [0.18.1] - 2026-10-05

A bateria de segurança passa a responder a quatro perguntas a cada versão: abre alguma coisa sem senha, abre com senha aleatória, dá para derrubar por exaustão e dá para ler o cadastro das senhas sem passar pela entrada. Ela achou dois defeitos, corrigidos nesta versão.

### Corrigido

- **Rajada de senhas erradas segurava a entrada de quem tinha a senha certa.** A senha de cada usuário do FTP era gravada com o custo que o `pure-pw` usa quando supõe 8 sessões: cerca de 3 segundos de processador por conferência. Na máquina de teste, 7 senhas erradas ao mesmo tempo, de um só endereço, seguravam por cerca de 50 segundos a entrada de quem tinha a senha certa. O custo passa a acompanhar o porte (`pure-pw -C FTP_MAX_CLIENTS`): a conferência leva menos de 1 segundo e a mesma rajada atrasa a entrada em cerca de 8 segundos.
- **A senha do usuário inicial não era reaplicada do segredo.** A documentação dizia que a senha de `.secrets/ftp-usuario-inicial-senha.txt` valia a cada subida, mas ela só era gravada na criação do usuário: trocar o arquivo e reiniciar o `ftp` deixava a senha antiga valendo. Agora o `ftp/entrypoint.sh` regrava a senha a cada subida.

### Adicionado

- Validação de `FTP_MAX_CLIENTS` e `FTP_MAX_CLIENTS_PER_IP` no container do `ftp`: valor que não é inteiro maior que zero para o serviço com `FALHA: FTP_MAX_CLIENTS deve ser um inteiro maior que zero`.
- Aba Segurança: item `Custo das senhas do FTP`, com os usuários que ainda estão com a senha gravada com o custo anterior. O painel lê só o parâmetro de memória de cada linha do cadastro; o hash não aparece na tela.
- Bateria: etapa 18, com 2 casos funcionais (tudo em Docker, sem systemd; senha do usuário inicial reaplicada do segredo) e 12 de segurança: nenhuma rota do painel e nenhum comando do FTP sem login, senha aleatória no FTP e no painel, rajada de senhas, de pedidos e de conexões, conexão parada, pedido grande ou malformado, cadastro das senhas fora do alcance da web, do FTP, dos outros containers e do host, e custo da senha conforme o porte. São 38 casos funcionais, 80 de segurança e 13 de rede.
- Documentação: [o que a bateria tenta e o que acontece](doc/seguranca.md#sem-senha-e-exaustao) e o [custo das senhas do FTP](doc/seguranca.md#custo-das-senhas), com os limites conhecidos.

### Alterado

- **Ao atualizar:** as senhas já gravadas continuam com o custo anterior até serem trocadas. A do usuário inicial é regravada na primeira subida; as demais aparecem na aba Segurança e são acertadas com a troca da senha, na aba Usuários ou com `./manage-user.sh passwd`. As senhas desses usuários continuam valendo.
- **Ao atualizar:** se a senha do usuário inicial foi trocada só com `./manage-user.sh passwd`, sem atualizar `.secrets/ftp-usuario-inicial-senha.txt`, a senha do arquivo volta a valer na primeira subida. Grave no arquivo a senha em uso antes de atualizar.
- O serviço `painel` recebe `FTP_MAX_CLIENTS`, para gravar as senhas com o mesmo custo do serviço `ftp`.

## [0.18.0] - 2026-10-04

O painel passa a publicar o contato de segurança da instalação, em `/.well-known/security.txt`, e o `robots.txt`. **Por padrão, uso só em rede privada, atrás de firewall.**

### Adicionado

- **Contato de segurança (RFC 9116):** a variável `SEGURANCA_CONTATO_EMAIL` do `.env` recebe o e-mail para onde quem achar uma falha na instalação deve escrever. Preenchida, o painel publica `/.well-known/security.txt` com o contato, a validade e o idioma, sem pedir senha, para as redes de `PAINEL_REDES_PERMITIDAS`. Vazia, que é o padrão, o endereço responde `404`. Guia em [Configuração](doc/configuracao.md#contato-de-seguranca).
- **Validade que não vence:** a linha `Expires` é calculada a cada pedido, 90 dias à frente; o arquivo sai sempre da configuração em vigor.
- **`robots.txt` (RFC 9309):** [`web/robots.txt`](web/robots.txt), entregue pelo nginx, pede aos robôs de busca que não indexem nada do painel.
- **Aba Segurança:** item `Contato de segurança`, com o e-mail publicado ou, com a variável vazia, o aviso de que não há para onde escrever; em alerta quando endereço público é aceito.
- **Validação do e-mail** no `deploy.sh`, no container do painel e no painel: só um endereço, sem `mailto:`, espaço, `%`, `<`, `>` nem quebra de linha. Valor fora da regra para com `SEGURANCA_CONTATO_EMAIL inválido`.
- Seção [Contato de segurança e robôs de busca](doc/seguranca.md#contato-de-seguranca) em Segurança, com o que os dois endereços entregam e o que não entregam.
- Bateria de testes: dois casos funcionais (`robots.txt` entregue pelo nginx; `security.txt` publicado com o contato de segurança) e um de segurança (os dois endereços, abertos sem senha, não entregam mais nada).

### Alterado

- O `.env.example` passa a ter 45 variáveis, com a seção Contato de segurança.

## [0.17.0] - 2026-10-04

O painel passa a mostrar a logo e o ícone da ALL-SAFE e, no rodapé de todas as telas, a autoria: desenvolvido pela allsafe.inf.br. **Por padrão, uso só em rede privada, atrás de firewall.**

### Adicionado

- **Logo e ícone no painel:** ícone na aba do navegador (`favicon.ico`, com 16, 32 e 48 pixels, e PNG de 32, 180 e 192 pixels), símbolo no topo de todas as telas e logo na tela de entrada. Guia em [Marca do painel](doc/painel.md#marca).
- **Autoria no rodapé de todas as telas**, inclusive na de entrada, na de tela não encontrada e na do usuário do FTP: `Desenvolvido pela allsafe.inf.br`, com os endereços [allsafe.inf.br](https://allsafe.inf.br) e [github.com/allsafe-inf](https://github.com/allsafe-inf). Os links abrem em outra aba e o site de destino não recebe o endereço do painel.
- **Pasta [`web/marca/`](web/marca/):** os seis arquivos que o painel usa, 22 KB no total, e, em `fonte/`, as duas artes de origem, sem alteração.
- **[`scripts/gerar-marca.sh`](scripts/gerar-marca.sh):** gera os seis arquivos a partir das artes de origem, sobre uma placa clara, para a arte escura aparecer no fundo escuro do painel e em aba escura do navegador. `MARCA_PLACA` troca a cor da placa. Só roda quando a logo muda: a instalação não depende dele nem do ImageMagick.
- **Entrega pelo nginx:** em `/favicon.ico` e em `/marca/` só existem os seis nomes, só para leitura, com os cabeçalhos de segurança; as artes de origem não entram na imagem.
- **`./scripts/validate.sh`** confere que os seis arquivos existem e são PNG ou ICO: `marca OK: 6 arquivos em web/marca/`.
- Bateria de testes: dois casos funcionais (logo e ícone entregues pelo nginx; autoria no rodapé de todas as telas) e um de segurança (a pasta da marca entrega só os seis arquivos, só para leitura).

### Alterado

- O topo das telas e a tela de entrada mostram a logo no lugar do emoji que fazia esse papel.
- O rodapé passa a ter duas linhas: a versão com o aviso de rede privada, e a autoria.
- README com a logo no cabeçalho e a ALL-SAFE nos créditos.

### Removido

- O ícone em SVG que o painel gerava em `/favicon.svg`: o endereço deixa de existir.

## [0.16.0] - 2026-10-04

O administrador passa a escolher, no painel, quais usuários entram no FTP sem TLS: serve para o equipamento antigo que não fala TLS, sem abrir mão do TLS dos demais. A opção nasce desligada. **Por padrão, uso só em rede privada, atrás de firewall.**

### Adicionado

- **TLS por usuário (`FTP_TLS_EXCECOES`):** com `sim`, o servidor continua exigindo TLS de todos, menos dos usuários que um administrador dispensar, um a um. O padrão é `nao`, e nada muda para quem não ligar. Guia em [TLS por usuário](doc/seguranca.md#tls-por-usuario).
- **Dispensa pelo painel:** na aba Usuários, a coluna **TLS** mostra quem é obrigado e quem entra sem TLS, e os botões **Dispensar TLS** e **Exigir TLS** alteram um usuário por vez, com confirmação. Qualquer administrador altera; vale na entrada seguinte do usuário, sem reiniciar.
- **Dispensa pelo terminal:** `./manage-user.sh tls-dispensar <usuario>`, `tls-exigir <usuario>` e `tls-lista`.
- **Recusa antes da senha:** sem TLS, o usuário que não foi dispensado recebe `530` com a senha certa ou errada, e a recusa fica no registro do container, com o usuário e a origem. Quem é removido sai da lista: um usuário novo com o mesmo nome não herda a dispensa.
- **Falha fechada:** se o processo que consulta a lista dos dispensados (`pure-authd`) parar, o container do FTP encerra e o Docker o sobe de novo; ninguém entra sem a conferência. O healthcheck do FTP passa a exigir esse processo quando a exceção está ligada.
- **Combinações recusadas** pelo `deploy.sh` e pelos containers do FTP e do painel: valor fora de `nao` e de `sim`, `sim` com `FTP_TLS_MODE` diferente de `2` e `sim` junto com `REDE_PERMITIR_IP_PUBLICO=sim`.
- **Avisos:** o `AVISO` no fim do `./deploy.sh` e no registro do container, a faixa de alerta nas abas Visão geral e Segurança com a quantidade e os nomes dos dispensados, e os eventos `tls_dispensado` e `tls_exigido` na auditoria, com o administrador que fez.
- Bateria de testes: dois casos funcionais (dispensa e volta pelo painel; pelo terminal e com o padrão desligado) e três de segurança (sem TLS só entra quem foi dispensado; `pure-authd` morto encerra o FTP; combinações recusadas e quem altera a lista).

### Alterado

- Com `FTP_TLS_EXCECOES=sim`, o container do FTP roda dois processos, `pure-authd` e `pure-ftpd`, vigiados pelo entrypoint. Com `nao`, continua como antes: só o `pure-ftpd`.
- A seção de equipamento sem TLS do guia de segurança passa a comparar os quatro caminhos: segunda instância, exceção por usuário, modo `1` e modo `0`.

### Segurança

- Com a exceção ligada, o servidor só sabe quem é o usuário depois de receber o nome. O equipamento de um usuário **não dispensado** que esteja configurado sem TLS manda a senha em texto puro antes de ser recusado: a entrada é negada e registrada, e a senha tem de ser trocada. Com `nao`, a sessão sem TLS é recusada antes de a senha ser enviada.

### Atualização a partir da 0.15.x

Rode `./deploy.sh`. A variável nova é opcional: sem ela no `.env`, vale `nao`, e o TLS continua obrigatório para todos, como antes. Para usar, defina `FTP_TLS_EXCECOES=sim`, com `FTP_TLS_MODE=2` e `REDE_PERMITIR_IP_PUBLICO=nao`, rode `./deploy.sh` e dispense os usuários no painel. Não há mudança nos dados.

## [0.15.0] - 2026-10-04

O dono dos arquivos passa a baixar os próprios backups pelo navegador: cada usuário do FTP entra no painel com o nome e a senha do FTP e vê só a pasta dele. A administração continua só com os administradores. **Por padrão, uso só em rede privada, atrás de firewall.**

### Adicionado

- **Entrada do usuário do FTP no painel:** na mesma tela de entrada, o usuário do FTP digita o nome e a senha do FTP e chega à tela **Meus arquivos**, com a pasta do cadastro dele: navega pelas subpastas e baixa os arquivos. Não cria, não envia, não renomeia e não apaga. Guia em [Usuário do FTP no painel](doc/painel.md#usuario-ftp).
- **Senha conferida pelo servidor FTP:** o painel faz um login no serviço `ftp`, pela rede interna da stack, em TLS e com o certificado dele conferido; não lê o hash do cadastro. Com `FTP_TLS_MODE=0`, essa conferência vai em texto puro, sem sair da rede interna, e a aba Segurança avisa.
- **Variável `PAINEL_ACESSO_USUARIOS_FTP`:** `sim` (padrão) liga a entrada dos usuários do FTP; `nao` deixa o painel só para administradores. Valor diferente é recusado pelo `deploy.sh` e pelo container do painel.
- **Sem alcance à administração:** para o usuário do FTP, as abas e os formulários de administração respondem `404`, com o evento `recusa_papel` na auditoria. Nome igual ao de um administrador entra só como administrador, com a senha de administrador.
- **Sessão que acompanha o cadastro:** trocar a senha do usuário, removê-lo, recriá-lo com outra pasta, criar um administrador com o mesmo nome ou desligar a entrada encerra a sessão dele no pedido seguinte, com o evento `sessao_encerrada` e o motivo.
- **Limites por usuário do FTP:** até 3 sessões, a quarta entrada encerra a mais antiga, e até 2 downloads ao mesmo tempo, dentro do teto de 8 do painel. Os erros de entrada contam no mesmo limite de cinco em 15 minutos por endereço.
- **Aba Segurança:** linha nova com a entrada dos usuários do FTP, ligada ou desligada, e como a senha é conferida.
- Bateria de testes: três casos funcionais (entrada e download do usuário do FTP; sessão que acompanha o cadastro e a variável que desliga; entrada em cada modo de TLS) e quatro de segurança (administração fora do alcance; preso à própria pasta; entrada sem brecha; limites de sessões e de downloads).

### Alterado

- Na auditoria, os eventos `entrada_ok`, `saida`, `arquivo_baixado`, `arquivo_interrompido` e `recusa_caminho`, que levam `admin=<nome>`, levam `usuario=<nome>` quando quem fez foi um usuário do FTP; a entrada recusada porque o servidor FTP não pôde conferir a senha leva `conferencia=ftp_indisponivel`.
- Com a entrada dos usuários ligada, a senha errada na tela de entrada demora de 3 a 9 segundos para ser recusada, também para nome de administrador: o tempo é o do servidor FTP, que confere todo nome válido. A entrada do administrador com a senha certa continua imediata.
- A tela de entrada explica os dois tipos de conta quando a entrada dos usuários está ligada.

### Atualização a partir da 0.14.x

Rode `./deploy.sh`. A variável nova é opcional: sem ela no `.env`, vale `sim`, e os usuários do FTP que já existem passam a entrar no painel com a senha que têm. Para manter o painel só com administradores, acrescente `PAINEL_ACESSO_USUARIOS_FTP=nao` ao `.env` antes de rodar. Não há mudança nos dados.

## [0.14.0] - 2026-10-04

Quem administra passa a escolher a pasta de cada usuário do FTP e a criar pastas pelo navegador. Sem escolha, nada muda: a pasta continua sendo a do nome do usuário. **Por padrão, uso só em rede privada, atrás de firewall.**

### Adicionado

- **Pasta escolhida por usuário:** o cadastro de usuário, no painel, ganhou o campo **Pasta**, e o [`manage-user.sh`](manage-user.sh), um terceiro parâmetro: `./manage-user.sh add olt01 clientes/olt-01`. A pasta fica sempre dentro de `DATA_DIR/dados`, com até 4 níveis, e é criada se não existir. Em branco, continua sendo a do nome do usuário. Guia em [Usuários pelo painel](doc/painel.md#usuarios).
- **Nova pasta na aba Arquivos:** o formulário **Nova pasta** cria uma pasta vazia dentro da que está aberta, com o dono e a permissão que o FTP usa; o botão **Novo usuário nesta pasta** abre o cadastro com a pasta preenchida. O painel continua sem enviar, renomear e apagar. Guia em [Arquivos e download](doc/painel.md#arquivos).
- **Pasta dividida avisada:** dois usuários com a mesma pasta, ou com uma dentro da outra, alcançam os arquivos um do outro. O painel aceita e avisa: alerta no cadastro, a marca **dividida** na lista, com o nome de quem mais alcança a pasta, e o mesmo aviso na tela de remoção. Na linha de comando, o `add` escreve uma linha `Aviso:` por usuário.
- **Só dentro da pasta dos dados:** pasta com `..`, barra no início, nível começando por ponto ou caractere fora da regra é recusada (`400`), no painel e na linha de comando; pasta que passa por link simbólico ou por um arquivo também. A pasta nova é criada em relação à pasta já aberta, sem seguir link; nome já usado recebe `409`.
- **Auditoria:** evento `pasta_criada`, com o administrador e o caminho, e a pasta no evento `usuario_criado`.
- Bateria de testes: dois casos funcionais (pasta criada pelo painel; pasta escolhida e pasta dividida) e três de segurança (criar pasta sem sessão e sem token, nome de pasta que tenta sair, usuário preso à pasta escolhida).

### Alterado

- A aba Usuários mostra a pasta real de cada usuário, lida do cadastro, e a aba Visão geral soma o espaço sem contar duas vezes a pasta dividida.
- `./manage-user.sh del` responde com a pasta real do usuário removido.
- `./manage-user.sh add` de um nome que já existe responde `Usuario ja existe`, sem criar pasta e sem alterar o usuário; a senha é trocada com `passwd`.

### Atualização a partir da 0.13.x

Rode `./deploy.sh`. Não há variável nova nem mudança nos dados: os usuários que já existem continuam na pasta deles.

## [0.13.0] - 2026-10-04

Os backups recebidos passam a ser consultados e baixados pelo navegador, na aba nova Arquivos do painel. O painel só lê: enviar, renomear e apagar continuam sendo feitos por FTP. **Por padrão, uso só em rede privada, atrás de firewall.**

### Adicionado

- **Aba Arquivos:** as pastas de `DATA_DIR/dados`, uma por usuário do FTP, com nome, tamanho e data de cada arquivo, navegação por subpasta e o caminho no alto da lista. Guia em [Arquivos e download](doc/painel.md#arquivos).
- **Download pelo navegador:** o botão **Baixar** entrega o arquivo com o nome original, em blocos, sem carregá-lo na memória e sem limite de tamanho. O arquivo sai sempre como anexo (`application/octet-stream` e `Content-Disposition: attachment`, com o nome nas formas da RFC 6266 e da RFC 8187): o navegador salva, nunca abre.
- **Só dentro da pasta dos dados:** o caminho é conferido parte por parte e aberto só para leitura, sem seguir link simbólico. Caminho com `..`, absoluto ou com byte nulo recebe `400`; link simbólico, `403`; link simbólico e arquivo especial aparecem na lista sem botão.
- **Limite de downloads:** até 8 ao mesmo tempo, somando todos os administradores; o nono recebe `503` com `Retry-After`, e as outras telas continuam respondendo.
- **Auditoria:** eventos `arquivo_baixado`, `arquivo_interrompido` e `recusa_caminho`, com o administrador, o caminho e os bytes entregues, visíveis na aba Atividade.
- Na aba Usuários, a coluna **Pasta no host** abre a pasta do usuário na aba Arquivos.
- Bateria de testes: dois casos funcionais (download pelo painel; subpasta, nome com acento e arquivo de 40 MiB) e cinco de segurança (aba Arquivos sem sessão, fuga da pasta, link simbólico, arquivo só como anexo e limite de downloads ao mesmo tempo).

### Alterado

- [`nginx/nginx.conf.modelo`](nginx/nginx.conf.modelo): o nginx repassa a resposta do painel no ritmo do navegador, sem arquivo temporário (`proxy_max_temp_file_size 0`), para o download não depender do `/tmp` do container.

### Atualização a partir da 0.12.x

Rode `./deploy.sh`. Não há variável nova nem mudança nos dados: a aba Arquivos aparece para todos os administradores.

## [0.12.0] - 2026-10-04

O painel deixa de ter uma senha só: cada administrador entra com o próprio usuário e a própria senha, e os administradores são criados, alterados e removidos pelo próprio painel. Quem atualiza continua entrando com a senha que já usava, agora com o usuário `admin`. **Por padrão, uso só em rede privada, atrás de firewall.**

### Adicionado

- **Entrada com usuário e senha:** a tela de entrada pede os dois. A recusa é a mesma para usuário que não existe e para senha errada, e o nome digitado em uma entrada recusada não vai para a auditoria nem para os logs.
- **`PAINEL_ADMIN_USER`** (padrão `admin`) no [`.env.example`](.env.example): o nome do primeiro administrador, criado na primeira subida com a senha inicial de `.secrets/`. Depois disso, a variável não é mais consultada. Nome fora da regra é recusado pelo `deploy.sh` e pelo container.
- **Aba Administradores:** lista com as sessões abertas de cada um, criação (com senha informada ou gerada pelo painel, mostrada uma única vez), troca de senha, troca de nome e remoção. Até 20 administradores, todos com o mesmo acesso: [Administradores do painel](doc/painel.md#administradores).
- **Senha atual em toda alteração de administrador:** criar, trocar senha, trocar nome e remover pedem a senha de quem está na sessão. A recusa conta no mesmo limite da tela de entrada: cinco erros em 15 minutos bloqueiam o endereço.
- **Sessões encerradas na alteração:** trocar a senha, trocar o nome ou remover um administrador encerra as sessões dele. Ninguém remove a própria conta.
- **Auditoria com o administrador:** as entradas e as alterações de usuário passam a registrar quem fez (`admin=`), e há eventos novos para os administradores (`admin_inicial_criado`, `admin_criado`, `admin_senha_trocada`, `admin_renomeado`, `admin_removido`, `admin_senha_atual_recusada`, `admin_definido_no_host`). O nome de quem está na sessão aparece no topo do painel.
- [`scripts/painel-senha.sh`](scripts/painel-senha.sh): opção `--usuario NOME`, para definir pelo host a senha de qualquer administrador ou criar um novo, com o painel no ar ou parado.
- Bateria de testes: dois casos funcionais (administradores pelo painel e recuperação do acesso pelo host) e seis de segurança (administrador inexistente não é revelado, alteração só com a senha atual, sessão de administrador alterado, ninguém remove a própria conta, arquivo de administradores só com hash e nome de administrador inválido).

### Alterado

- **Onde a senha do painel fica:** o nome e o hash `scrypt` da senha de cada administrador ficam em `DATA_DIR/painel/administradores` (`0600`, do `root`), gravado pelo painel. O segredo `.secrets/painel-admin-inicial-senha-hash.txt` passa a servir só para criar o primeiro administrador.
- **Cópia de segurança:** os administradores entram na cópia do `scripts/backup.sh`, só com o hash, e voltam na restauração; a mensagem final do [`scripts/restaurar.sh`](scripts/restaurar.sh) diz isso.
- [`scripts/painel-senha.sh`](scripts/painel-senha.sh): passa a ser o caminho de recuperação do acesso. A mensagem final muda para `Administrador NOME com a senha trocada; painel reiniciado e sessões abertas encerradas.`
- [`deploy.sh`](deploy.sh): o resumo mostra o usuário do painel ao lado do arquivo da senha inicial, e o `LEIAME.txt` de `.secrets/` explica o papel novo de cada arquivo.
- Bateria de testes: a instância de teste sobe com o primeiro administrador `gestor` (`TESTE_ADMIN`), de propósito diferente do padrão.

### Atualização a partir da 0.11.x

Rode `./deploy.sh`. Na primeira subida, o painel cria o administrador `admin` com a senha que já valia; para outro nome, defina `PAINEL_ADMIN_USER` no `.env` **antes** de atualizar, ou troque o nome depois, na aba Administradores. As sessões abertas são encerradas.

## [0.11.1] - 2026-10-04

O código do painel, que era um arquivo só, passa a ser dividido em módulos, um assunto por arquivo. Nada muda para quem usa: as mesmas telas, as mesmas respostas, a mesma auditoria. **Por padrão, uso só em rede privada, atrás de firewall.**

### Alterado

- **Painel em módulos:** o `painel/servidor.py` fica como ponto de entrada (servidor e modos `--hash` e `--saude`) e o restante vai para treze módulos ao lado dele: configuração, senha, sessão, auditoria, estado da stack, moldura das telas, atendimento, rotas, entrada e uma aba por arquivo. Lista em [Painel web](doc/painel.md#modulos). Os caminhos usados pelo `compose.yaml`, pelo entrypoint e pelo `scripts/painel-senha.sh` são os mesmos.
- [`Dockerfile`](Dockerfile): o alvo `painel` copia todos os módulos de `painel/` para `/opt/painel`.
- [`scripts/validate.sh`](scripts/validate.sh): confere a sintaxe de cada módulo do painel e que todo nome usado em cada um está definido ou importado nele; a linha de resultado passa a ser `painel OK: <n> módulos Python`.

## [0.11.0] - 2026-10-04

A stack ganha uma opção para aceitar endereço público, desligada por padrão e acompanhada de alerta. Quem não ligar a opção não percebe diferença. **Por padrão, uso só em rede privada, atrás de firewall.**

### Adicionado

- **`REDE_PERMITIR_IP_PUBLICO`** (`nao` ou `sim`, padrão `nao`) no [`.env.example`](.env.example), com o alerta nos comentários da variável: [IP público](doc/seguranca.md#ip-publico). Com `sim`, `FTP_BIND_IP`, `FTP_PASSIVE_IP`, `PAINEL_BIND_IP` e `PAINEL_CERT_CN` aceitam IPv4 público de servidor e `PAINEL_REDES_PERMITIDAS` aceita rede pública de `/8` a `/32`.
- **Alerta em execução:** com a opção ligada, o `deploy.sh` (também no `--check-only`), o registro dos três containers e o painel (tela de entrada, rodapé e a linha **Endereço público** da aba Segurança) avisam que a stack aceita endereço público e que a proteção passa a ser o firewall do servidor.
- **Travas que continuam com a opção ligada:** `0.0.0.0`, multicast e endereços reservados são recusados; rede mais larga que `/8`, como `0.0.0.0/0`, é recusada; `FTP_TLS_MODE` em `0` ou `1` é recusado; valor diferente de `nao` e de `sim` para tudo antes de qualquer outra conferência.
- Bateria de testes: seis casos de segurança (funções da opção, IP público só com a opção, "todos" sempre recusado, TLS obrigatório, valor inválido e alerta em execução) e um de rede (rede pública no painel só com a opção). A opção é testada com endereços de documentação, sem publicar porta fora do IP de teste.

### Alterado

- As mensagens de recusa dizem que a rede privada é o padrão e apontam a opção: `Por padrão esta stack é só para rede interna` e `IP público só com REDE_PERMITIR_IP_PUBLICO=sim, e com firewall`.
- O resumo do `./deploy.sh --check-only` e a linha do painel ao final do `deploy.sh` trazem `rede privada` ou `endereço público aceito`, conforme a opção.
- A tela de entrada do painel mostra o mesmo aviso de rede das outras telas.
- [`scripts/rede-privada.sh`](scripts/rede-privada.sh): `exigir_ip` e `exigir_rede` no lugar de `exigir_ip_privado`, mais `conferir_opcao_ip_publico` e `aviso_ip_publico`, usadas pelo `deploy.sh` e pelos três entrypoints.

## [0.10.1] - 2026-10-04

O [`.env.example`](.env.example) passa a explicar cada variável. Nenhum valor, nome ou comportamento muda. **Uso só em rede privada, atrás de firewall.**

### Alterado

- **`.env.example` comentado:** as 40 variáveis vêm agrupadas por assunto (geral, nomes, pastas, rede, servidor FTP, painel, perfil e limites) e cada uma tem, na linha de cima, um comentário dizendo para que serve. O `.env` de quem já instalou não é tocado.
- [`scripts/validate.sh`](scripts/validate.sh) confere que nenhuma variável do exemplo fica sem comentário nem fora do guia de [Configuração](doc/configuracao.md).

### Corrigido

- [Configuração](doc/configuracao.md) citava `FTP_PASSWORD_FILE`, que deixou de existir na `0.2.0`, entre os padrões do Compose; o texto agora traz as variáveis que de fato não têm padrão (`DATA_DIR` e `FTP_PASSIVE_IP`).
- [Scripts](doc/scripts.md) lista todas as pastas de script que o `validate.sh` confere.

## [0.10.0] - 2026-10-04

Os arquivos de `.secrets/` passam a dizer no nome o que guardam, e a pasta ganha um `LEIAME.txt` que explica cada um. As senhas não mudam. **Uso só em rede privada, atrás de firewall.**

### Alterado

- **Nomes dos arquivos de segredo:** [Segredos](doc/segredos.md#o-que-fica).

  | Antes | Agora | O que guarda |
  |---|---|---|
  | `ftp_password.txt` | `ftp-usuario-inicial-senha.txt` | Senha do usuário inicial do FTP |
  | `painel_password.txt` | `painel-admin-inicial-senha.txt` | Senha inicial do painel, em texto |
  | `painel_password_hash.txt` | `painel-admin-inicial-senha-hash.txt` | Hash da senha do painel |

- Os segredos do [`compose.yaml`](compose.yaml) acompanham: `ftp_usuario_inicial_senha` e `painel_admin_inicial_senha_hash`, em `/run/secrets/` de cada container.

### Adicionado

- **`.secrets/LEIAME.txt`**, gravado pelo [`deploy.sh`](deploy.sh) com modo `0600`: diz para que serve cada arquivo da pasta e não guarda segredo nenhum. O resumo do `deploy.sh` aponta para ele.
- **Conversão automática dos arquivos no `deploy.sh`:** os três arquivos antigos só mudam de nome, sem que o conteúdo seja lido ou copiado. Com `--check-only`, só avisa. Se o antigo e o novo existirem, vale o novo.
- Um caso na bateria de segurança, que passa a 39: o `LEIAME.txt` existe, tem modo `0600`, explica os três arquivos e não traz senha nem hash. O caso da conversão na bateria funcional passa a cobrir também os três arquivos.

### Ao atualizar

Rode `./deploy.sh` uma vez: ele dá o nome novo aos arquivos e recria os containers do FTP e do painel, porque o nome do segredo dentro deles mudou. Dados, usuários e senhas ficam como estavam: [Segredos](doc/segredos.md#nomes-antigos).

## [0.9.0] - 2026-10-04

A variável do IP anunciado no modo passivo muda de nome: `FTP_PUBLIC_IP` vira `FTP_PASSIVE_IP`. O valor e o comportamento são os mesmos; o nome antigo sugeria IP de internet, e a stack só aceita IP privado. **Uso só em rede privada, atrás de firewall.**

### Alterado

- **`FTP_PUBLIC_IP` vira `FTP_PASSIVE_IP`** no [`.env.example`](.env.example), no [`compose.yaml`](compose.yaml), no FTP e no painel. É o IP que o servidor informa ao cliente no modo passivo: [Configuração](doc/configuracao.md#ftp-passive-ip).

### Adicionado

- **Conversão automática no [`deploy.sh`](deploy.sh):** em `.env` de instalação anterior, troca o nome da variável no mesmo ponto do arquivo, com o mesmo valor, e guarda o `.env` de antes em `BACKUP_DIR/<data>-antes-da-migracao-de-nomes/env`. A troca do nome, sozinha, não recria container; na atualização a partir de uma versão anterior, os três são recriados uma vez, porque as imagens mudam, e usuários, senhas e arquivos ficam como estavam. Com `--check-only`, só avisa.
- Um caso na bateria funcional, que passa a 21: instalação com o nome antigo, convertida pelo `deploy.sh` sem perder o valor, a senha nem os containers.

### Ao atualizar

Rode `./deploy.sh` uma vez. Até ele rodar, os comandos que chamam o Compose param com `defina FTP_PASSIVE_IP no .env`.

## [0.8.2] - 2026-10-04

As imagens do FTP e do painel deixam de levar dois pacotes que nada na stack usava. Nada muda para quem usa. **Uso só em rede privada, atrás de firewall.**

### Removido

- **`procps` e `ca-certificates` fora das imagens do FTP e do painel.** Nenhum script da stack chama `ps`, `pgrep` ou `top`, e nenhum serviço abre conexão de saída que precise conferir certificado de terceiros: os certificados do FTP e do painel são gerados na própria instalação. Com eles sai `libproc2-0` e, na imagem do FTP, `libncursesw6` (no painel, o Python continua a usá-la). O `pidof`, usado pela bateria de testes, vem de outro pacote e continua na imagem.

### Tamanho das imagens

Medido com `docker image inspect`, as duas versões construídas no mesmo host e no mesmo dia.

| Imagem | Antes (`0.8.1`) | Agora (`0.8.2`) | Pacotes |
|---|---|---|---|
| FTP | 211,3 MB | 207,5 MB | 104 ➜ 100 |
| Painel | 261,1 MB | 257,8 MB | 117 ➜ 114 |
| nginx | 145,2 MB | 145,2 MB | sem mudança |

## [0.8.1] - 2026-10-04

As pastas do projeto passam a seguir a divisão por serviço. Nada muda para quem usa: os comandos do dia a dia, o `.env`, os segredos e os dados continuam iguais. **Uso só em rede privada, atrás de firewall.**

### Alterado

- **Uma pasta por serviço**, com o que vai dentro de cada imagem: [`ftp/`](ftp/), [`painel/`](painel/) e [`nginx/`](nginx/). A pasta [`scripts/`](scripts/) fica só com o que roda no servidor.
- **Arquivos estáticos em [`web/`](web/)**, entregues direto pelo nginx. O painel deixa de servir a folha de estilo; a aparência é a mesma.
- **Cabeçalhos de segurança do nginx em um arquivo só**, [`nginx/cabecalhos.conf`](nginx/cabecalhos.conf), usado nas páginas de erro e nos arquivos estáticos.
- **Bateria de testes em [`tests/`](tests/)**: `tests/testar.sh` chama as funções de `tests/comum.sh` e os casos de `tests/etapas/`, um arquivo por etapa. O comando passa de `./scripts/testar.sh` para `./tests/testar.sh`.
- Um caso na bateria funcional, que passa a 20: a folha de estilo chega pelo nginx, com os cabeçalhos de segurança, e o painel não a entrega mais.

### Arquivos que mudaram de lugar

| Antes | Agora |
|---|---|
| `scripts/entrypoint.sh` | `ftp/entrypoint.sh` |
| `scripts/ftp-saude.sh` | `ftp/saude.sh` |
| `scripts/ftp-user.sh` | `ftp/usuario.sh` |
| `scripts/painel-entrypoint.sh` | `painel/entrypoint.sh` |
| `scripts/nginx-entrypoint.sh` | `nginx/entrypoint.sh` |
| `scripts/nginx-saude.sh` | `nginx/saude.sh` |
| `painel/estilo.css` | `web/estilo.css` |
| `scripts/testar.sh` | `tests/testar.sh`, `tests/comum.sh` e `tests/etapas/` |

## [0.8.0] - 2026-10-04

O painel passa a aceitar a entrada pelo navegador e a documentação ganha as fotos de todas as telas. **Uso só em rede privada, atrás de firewall.**

Esta versão foi publicada primeiro como `1.0.0` e renumerada para `0.8.0` no mesmo dia: a `1.0.0` fica reservada para a primeira versão pronta para produção. A tag e a Release `v1.0.0` deixaram de existir; o conteúdo é o mesmo.

### Adicionado

- Guia [Fotos da aplicação](doc/aplicacao/README.md): todas as telas do painel, menu por menu, com capturas reais, para que serve cada uma, como chegar e o que há na tela.
- Imagem principal e uma imagem de cada aba do painel no [README](README.md#imagens).
- Um caso na bateria de segurança, que passa a 38: a resposta traz `Referrer-Policy: same-origin` e o envio com `Origin: null` é recusado.

### Alterado

- **`Referrer-Policy`:** de `no-referrer` para `same-origin`, no painel e nas respostas do nginx. O endereço da página continua sem sair para outro site; só o próprio painel o recebe.
- Lista de usuários do painel: o nome não quebra de linha e a coluna da pasta ganha a largura que sobrava na de ações.

### Corrigido

- **O painel recusava todo envio feito por navegador, inclusive a entrada**, com `403` e a mensagem `O envio não partiu deste painel.` Com `Referrer-Policy: no-referrer`, o navegador manda `Origin: null` em todo formulário, e o painel exige `Origin` igual ao próprio endereço. O defeito existia desde a `0.3.0`, quando o painel foi criado, e não aparecia nos testes porque a bateria envia os formulários com `curl`, informando o `Origin` certo. A correção foi conferida com o Google Chrome: entrada, cadastro, troca de senha e remoção de usuário.

## [0.7.0] - 2026-10-04

Backup e restauração em um comando e healthcheck do FTP que confere se o servidor atende. **Uso só em rede privada, atrás de firewall.**

### Adicionado

- **`scripts/backup.sh`:** grava `dados/`, `auth/`, `certs/` e `painel/` de `DATA_DIR` em um arquivo `.tar.gz` de `BACKUP_DIR`, com data e hora no nome, modo `0600` e a soma `.sha256` ao lado. Funciona com a stack no ar; a leitura é feita por um container sem rede. O `.env` e os segredos de `.secrets/` não entram na cópia.
- **`scripts/restaurar.sh`:** confere a cópia antes de tocar em qualquer coisa (soma, formato e conteúdo), para a stack, guarda o estado atual em um arquivo com `antes-da-restauracao` no nome, troca o conteúdo e sobe de novo. A restauração pode ser desfeita com um comando.
- **`scripts/ftp-saude.sh`:** healthcheck do FTP, instalado na imagem como `/usr/local/sbin/allsafe-ftp-saude`.
- Guia [Backup e restauração](doc/backup.md): o que entra na cópia, o que guardar à parte, restauração em outro servidor e cópia agendada.
- Dois casos na bateria funcional, que passa a 19: o ciclo de backup e restauração e o healthcheck do FTP.

### Alterado

- **Healthcheck do FTP:** abre a porta de controle e espera a saudação do servidor; antes conferia só se o processo existia. Um `pure-ftpd` vivo que não atende passa a deixar o container `unhealthy`.
- A seção de backup de [Operação](doc/operacao.md#backup-dos-volumes) usa os dois scripts no lugar dos comandos manuais.
- [Segurança](doc/seguranca.md#hardening-do-compose-yaml-linha-a-linha): a capacidade `NET_BIND_SERVICE` é exigida pelo `pure-ftpd` na partida; o texto anterior a dava como reservada.

### Corrigido

- `scripts/testar.sh` acusava segredo nos resultados (saída `3`) quando a bateria parava antes de a instância de teste ter senhas.

## [0.6.0] - 2026-10-04

Testes automatizados: um comando roda a bateria funcional, de segurança e de rede. **Uso só em rede privada, atrás de firewall.**

### Adicionado

- **`scripts/testar.sh`:** sobe uma instância de teste separada (em `127.0.0.2`, com nomes, portas, sub-rede, dados e segredos próprios), roda 18 casos funcionais, 37 de segurança e 12 de rede, grava um arquivo de resultado por bateria e remove tudo o que criou. A instalação em uso não é tocada. Opções `--resultados`, `--manter` e `--limpar`.
- A bateria confere os próprios resultados contra as senhas, o hash, o cookie e o token que usou: se algum aparecer, o arquivo é apagado e a saída é `3`.
- `ENV_FILE` no `manage-user.sh` e no `validate.sh --runtime`, para operar e conferir a instalação de outro arquivo de ambiente.
- Seção do `testar.sh` em [Scripts](doc/scripts.md#testar) e a bateria na seção Testes do README e em [Solução de problemas](doc/solucao-de-problemas.md#ferramentas-de-validacao).

### Alterado

- `validate.sh --runtime` confere os três serviços (`ftp`, `painel` e `nginx`) em `running` e `healthy` e lê o usuário inicial de `FTP_USER` no `.env`; antes conferia só o `ftp` e lia a variável do shell.

## [0.5.4] - 2026-10-04

Mapa da arquitetura aberto no README. Nenhuma mudança no funcionamento da stack.

### Alterado

- **Dois diagramas abertos no README:** o da abertura e o mapa da arquitetura, que saiu do menu recolhido e aparece direto na seção Arquitetura, com a sequência escrita. Os fluxogramas completos do FTP e do painel e as tabelas continuam em menus recolhidos.

## [0.5.3] - 2026-10-04

Documentação mais limpa: menos emojis e sem avisos de coisa que falta. Nenhuma mudança no funcionamento da stack.

### Alterado

- **Emojis só no essencial:** ficam um por título de seção, os alertas de rede privada e de atenção, as marcas de estado, a seta das sequências e a navegação do rodapé. Saíram das tabelas, das listas, dos textos de link, dos menus recolhidos e das legendas dos diagramas. No README, de 270 para 59, dos quais 39 são a seta das sequências.
- **Legenda dos diagramas mais curta:** nível, tipo e link da fonte.

### Removido

- **Avisos de falta:** as marcas de captura pendente, a frase sobre testes que ainda não existem, a linha de status do plano e a seção de licença sem licença definida. Cada item entra na documentação quando existir.
- **Coluna de ícones** da tabela de destaques.

## [0.5.2] - 2026-10-04

Página do repositório mais leve: só o principal fica aberto. Nenhuma mudança no funcionamento da stack.

### Alterado

- **Menus recolhidos no README:** os fluxogramas completos do FTP e do painel, o mapa da arquitetura, a tabela de peças, as tecnologias, as portas, os perfis, a lista de proteções, a estrutura de arquivos e os projetos oficiais passaram para menus recolhidos, cada um com uma frase de resumo fora do menu. Ficam abertos o que é, os destaques, a instalação rápida, o aviso de rede privada e o índice da documentação.
- **Um diagrama aberto por página:** no README e nos guias de arquitetura e do painel, só o diagrama da abertura fica aberto; os outros carregam quando o menu é aberto. Medido na página do repositório: quatro diagramas carregados na abertura antes, um depois.

## [0.5.1] - 2026-10-04

Diagramas mais leves para abrir no repositório. Nenhuma mudança no funcionamento da stack.

### Alterado

- **Diagramas sem emoji:** os 13 arquivos `.mmd` de `doc/diagramas/` e os blocos de diagrama dos guias e do README perderam os emojis dos nós, dos grupos e das setas; ficam a forma de cada nó, o nome real e a função. Os emojis continuam no texto da documentação e nas tabelas de sequência e de apoio, logo abaixo de cada diagrama.

## [0.5.0] - 2026-10-04

nginx na frente do painel, cinco portes, base Debian 13 e opção de FTP sem TLS para equipamento antigo. **Uso só em rede privada, atrás de firewall.**

### Adicionado

- **nginx na frente do painel:** serviço `nginx` (container `allsafe-ftp-nginx`), a única porta publicada do painel. Fecha o HTTPS (TLS 1.2 e 1.3), recusa quem está fora de `PAINEL_REDES_PERMITIDAS`, limita a taxa de pedidos (20 por segundo, rajada de 40) e as conexões (16) por endereço e o tamanho do pedido (16 KiB). Roda sem root, sem nenhuma capability e com a raiz somente leitura.
- Portes **`xlarge`** e **`extended`**, em `profiles/xlarge.env` e `profiles/extended.env`: a stack passa a ter cinco perfis (`small`, `medium`, `large`, `xlarge`, `extended`), até 1200 sessões e 1600 portas passivas.
- **Conferência dos recursos do servidor:** o `deploy.sh` recusa, sem alterar nada, o perfil que pede mais CPU ou memória do que o servidor tem.
- **`FTP_TLS_MODE=0`, FTP sem TLS, só para equipamento antigo que não fala TLS.** Senhas e arquivos trafegam em texto puro: o `deploy.sh`, o registro do container e o painel (telas Visão geral e Segurança) avisam enquanto o modo `0` ou `1` estiver ligado. O padrão continua `2`, TLS obrigatório no login.
- Variáveis `NGINX_IMAGE`, `NGINX_CONTAINER_NAME`, `NGINX_MEMORY_LIMIT`, `NGINX_CPU_LIMIT` e `NGINX_PIDS_LIMIT` no `.env.example`; pasta `DATA_DIR/nginx`, criada pelo `deploy.sh`.
- `scripts/nginx-entrypoint.sh`, `scripts/nginx-saude.sh`, `nginx/nginx.conf.modelo` e as páginas de erro em `nginx/erro/`.
- Seção sobre o FTP sem TLS em [Segurança](doc/seguranca.md#ftp-sem-tls), o porquê do nome `FTP_PUBLIC_IP` em [Configuração](doc/configuracao.md#ftp-public-ip) e o serviço `nginx` em todos os guias e diagramas.

### Alterado

- **Base Debian 13 (trixie)** nas três imagens, fixada por digest, no lugar do Debian 12: Pure-FTPd 1.0.50-2.2, OpenSSL 3.5, Python 3.13 e nginx 1.26.
- **O painel não escuta mais em porta de rede:** atende só o nginx, por soquete Unix em `DATA_DIR/nginx`, e recebe dele o endereço do cliente (`X-Real-IP`). O endereço e a porta de acesso continuam os mesmos (`PAINEL_BIND_IP` e `PAINEL_PORT`).
- O healthcheck do painel passa a ser feito pelo soquete; o do nginx pede `/saude` por TLS e confere os dois de uma vez.
- O `deploy.sh` espera os **três** containers ficarem `healthy`, com prazo proporcional à faixa passiva (180 s mais um quarto de segundo por porta), e avisa quando a publicação das portas vai demorar.
- `./deploy.sh --remover --apagar-dados` apaga também a pasta `nginx/` de `DATA_DIR`.
- O resumo do `deploy.sh` e a tela Visão geral do painel mostram o modo de TLS em uso.

### Atualização e retorno

- **Atualizar da `0.4.0`:** troque os arquivos e rode `./deploy.sh`. Usuários, senhas, dados, certificados e o `.env` são preservados; o container do painel deixa de publicar porta e o nginx assume a mesma.
- **Voltar para a `0.4.0`:** rode `./deploy.sh --remover` ainda com os arquivos da `0.5.0`, volte os arquivos e rode `./deploy.sh`. Com `FTP_TLS_MODE=0`, troque antes para `1`, `2` ou `3`: a `0.4.0` não aceita o `0`.

## [0.4.0] - 2026-10-04

### Adicionado

- **Instalação em um comando:** `./deploy.sh`, sem perguntas. Sem `.env`, o script cria um a partir do exemplo (tudo em `127.0.0.1`) e segue, em vez de parar e pedir uma segunda execução.
- Conferência dos requisitos antes de agir: `docker`, plugin `docker compose`, serviço do Docker e portas livres (FTP, painel e faixa passiva).
- `./deploy.sh --atualizar`: reconstrói as imagens sem cache, com os pacotes atuais do Debian.
- `./deploy.sh --remover`: derruba os containers e a rede, preservando dados, segredos, `.env` e imagens. Com `--apagar-dados`, apaga também as pastas de `DATA_DIR`, depois de confirmação (ou `--sim`).
- Resumo final com os endereços do FTP e do painel, o usuário inicial e o arquivo onde está cada senha, sem mostrar senha.
- Variável `FTP_PROFILE` no `.env`, com o nome do perfil em uso.

### Alterado

- **O perfil passa a ser gravado no `.env`:** `./deploy.sh --size <perfil>` copia os limites de `profiles/<perfil>.env` para o `.env`. O Compose lê só o `.env`, e um `docker compose up -d` direto mantém os limites.
- Sem `--size`, o `deploy.sh` não reaplica mais o `small`: mantém o perfil em uso. **Quem instalou com `--size medium` ou `large` antes desta versão precisa rodar uma vez `./deploy.sh --size <perfil>`** para gravar o perfil no `.env`.
- O `deploy.sh` espera os dois containers ficarem `healthy` (`up -d --wait`, limite de 180 s) e falha com a indicação do log quando isso não acontece.
- `./deploy.sh --check-only` sem `.env` valida com o `.env.example` e não cria nada.

### Corrigido

- Um `docker compose up -d` fora do `deploy.sh` devolvia os limites e a faixa passiva aos valores do `.env`, desfazendo o perfil escolhido.
- A documentação indicava `docker compose build --pull` para atualizar; com a base fixada por digest e a camada de pacotes em cache, ele não atualizava nada.

## [0.3.0] - 2026-10-04

Painel web seguro. **Uso só em rede privada, atrás de firewall**: o painel recusa por código endereço e rede que não sejam privados.

### Adicionado

- Painel web no serviço `painel` (container `allsafe-ftp-painel`): cria, troca a senha e remove os usuários do FTP pelo navegador, sem reiniciar o servidor. Abas de visão geral, usuários, segurança e atividade.
- Proteções do painel: só HTTPS (TLS 1.2 ou mais novo), uma senha guardada como hash `scrypt`, sessão de 15 minutos presa ao endereço do cliente, bloqueio depois de cinco senhas erradas, token CSRF e conferência do `Origin`, recusa de cliente fora das redes permitidas e de `Host` desconhecido, cabeçalhos de segurança, nenhum JavaScript e auditoria de cada ação em `DATA_DIR/painel/auditoria.log`.
- Variáveis `PAINEL_IMAGE`, `PAINEL_CONTAINER_NAME`, `PAINEL_BIND_IP`, `PAINEL_PORT`, `PAINEL_REDES_PERMITIDAS`, `PAINEL_SESSAO_MINUTOS`, `PAINEL_CERT_CN`, `PAINEL_MEMORY_LIMIT`, `PAINEL_CPU_LIMIT` e `PAINEL_PIDS_LIMIT` no `.env.example`.
- `scripts/painel-senha.sh`, que troca a senha do painel gravando só o hash; `scripts/painel-entrypoint.sh`; `scripts/ambiente.sh`, que lê uma chave do `.env` sem executar o arquivo.
- Trava (`flock`) nas alterações de usuário: o `manage-user.sh` e o painel nunca gravam o PureDB ao mesmo tempo.
- Guia [Painel web](doc/painel.md), diagramas `painel-diagrama.mmd` e `painel-fluxograma.mmd`, e o painel nos guias de configuração, segredos, segurança, arquitetura, scripts, operação, instalação e solução de problemas.

### Alterado

- `Dockerfile` com uma base e dois alvos (`ftp` e `painel`); o Compose passa a ter dois serviços, e o painel só inicia depois de o FTP ficar `healthy`.
- `deploy.sh` confere também os endereços do painel, cria `DATA_DIR/painel`, gera a senha inicial do painel em `.secrets/painel_password.txt`, constrói as imagens antes de subir e mostra o endereço do painel no fim. Recusa `PAINEL_PASSWORD` e `PAINEL_PASSWORD_HASH` no `.env`.
- O entrypoint do FTP grava em `DATA_DIR/auth` uma cópia do certificado **sem a chave**, para o painel mostrar a impressão digital.
- `scripts/validate.sh` confere a sintaxe do painel quando o host tem `python3`.
- Mapa da arquitetura e modelo da subida redesenhados com o painel.

### Corrigido

- `./manage-user.sh list` falhava com `Unable to open the passwd file`: o `pure-pw list` não aceita `-f` logo depois da ação.
- A conferência do usuário inicial no `validate.sh --runtime` casava com qualquer nome que terminasse igual; agora compara o nome inteiro.
- A documentação dizia que `docker compose down -v` apaga os dados: desde a `0.2.0` eles ficam em pastas do host, que o Docker não remove.

## [0.2.1] - 2026-10-04

### Alterado

- O plano de criação e mudança deixa de ser publicado neste repositório: fica na pasta local `doc/planos/` (fora do Git da stack) e em um repositório privado próprio. A documentação passa a citá-lo sem link.
- A legenda dos diagramas aponta só para o fonte `.mmd`.

### Removido

- Imagens SVG dos diagramas (44 arquivos, 5,1 MB): os guias mostram o diagrama direto do `.mmd`; os SVG são gerados no computador pelo `renderizar.sh` e ficam só na pasta local (`*.svg` no `.gitignore`).
- `doc/planos/` do repositório (`doc/planos/` no `.gitignore`).

## [0.2.0] - 2026-10-04

Pastas fixas, segredos fora do `.env` e recusa de IP público. **Quem já tinha a `0.1.x` instalada precisa migrar**: veja [Migrar dos volumes nomeados](doc/operacao.md#migracao).

### Adicionado

- `DATA_DIR`, `BACKUP_DIR`, `TEMP_DIR` e `SECRETS_DIR` no `.env.example`: dados em `DATA_DIR/dados`, `DATA_DIR/auth` e `DATA_DIR/certs`.
- `STACK_NAME`, `FTP_CONTAINER_NAME` e `FTP_NETWORK_NAME`: uma segunda instância no mesmo host não colide com a primeira.
- `scripts/rede-privada.sh`: `deploy.sh` e container recusam `0.0.0.0`, IP público e CGNAT em `FTP_BIND_IP` e `FTP_PUBLIC_IP`.
- `deploy.sh` cria as pastas e gera a senha do usuário inicial em `.secrets/ftp_password.txt` (`0600`), sem nunca regravar a que já existe; `ENV_FILE` permite outro arquivo de ambiente.
- Roteiro de migração dos volumes nomeados e resultado datado do portão da fase.

### Alterado

- Volumes nomeados do Docker viram _bind mount_ nas pastas de `DATA_DIR`.
- A senha chega ao container só por `secrets:` do Compose, em `/run/secrets/ftp_password`; a pasta `.secrets/` deixa de ser montada inteira.
- Guias de configuração, segredos, segurança, operação, scripts, instalação e solução de problemas atualizados; coleta de diagnóstico em `TEMP_DIR`.

### Removido

- `FTP_PASSWORD` e `FTP_PASSWORD_FILE`: o `deploy.sh` recusa o `.env` que ainda os traz e explica a migração.

## [0.1.1] - 2026-10-04

Documentação e plano refeitos. O código da stack é o mesmo da `0.1.0`.

### Adicionado

- Aviso de uso **só em rede privada, atrás de firewall**, no README e em `doc/seguranca.md`, com exemplo de regra na cadeia `DOCKER-USER`.
- Plano refeito com as fases 04 a 09: pastas fixas, segredos e rede privada; painel web seguro; instalação em um comando; testes automatizados; backup e restauração; documentação final. Um fluxograma por fase.
- Diagramas direto do fonte `.mmd` em todos os guias, com fundo escuro e controles de aproximar e mover no próprio diagrama. O SVG escuro, o de fundo branco e o `visualizador.html` ficam só na pasta `diagramas/`.
- Sequência de versões até a `1.0.0`, registrada no plano mestre.
- `*.pdf` e todo o conteúdo de `.secrets/` no `.gitignore`.
- Plano mestre em `doc/planos/`, com as fases entregues e as fases a fazer, `PROGRESSO.md` e as pastas de teste por tipo (`testes/`, `seguranca/`, `rede/`).
- Diagramas sem cor própria, com fonte `.mmd`: 11 em `doc/diagramas/` e 11 em `doc/planos/diagramas/`.
- Guia `doc/segredos.md` ampliado, com a troca da senha do usuário inicial.
- Resultado datado da validação estática.
- `VERSION` e este `CHANGELOG.md`.

### Alterado

- README da raiz e todos os guias de `doc/` reescritos em dois níveis: explicação para leigo e detalhe técnico recolhido.
- Créditos revistos, com os projetos oficiais citados com licença, origem e fonte.

### Corrigido

- Tabela dos modos de TLS: o modo `2` exige TLS no login e aceita dados sem criptografia se o cliente pedir; só o modo `3` recusa.
- Documentação do processo 1 do container: é o `tini`, não o entrypoint.
- Lista do `.dockerignore`, padrão de `FTP_PASSWORD_FILE` e recriação do container sem o perfil.
- Referências a arquivos inexistentes (`dev/README.md`, `dev/install.sh`) retiradas.

## [0.1.0] - 2026-10-04

Estado da stack na adoção do versionamento: servidor FTP, perfis e operação pelo terminal.

### Adicionado

- Imagem do Pure-FTPd sobre Debian 12, fixada por digest.
- `compose.yaml` endurecido: raiz somente leitura, `cap_drop: ALL`, `no-new-privileges`, limites de memória, CPU e processos, healthcheck.
- Usuários virtuais em PureDB, com `chroot` e senha mínima de 12 caracteres.
- FTPS explícito obrigatório, com certificado autoassinado gerado na primeira subida.
- Senha do usuário inicial em `.secrets/`, fora do Git e da imagem.
- Perfis `small`, `medium` e `large`.
- Scripts `deploy.sh`, `manage-user.sh` e `scripts/validate.sh`.
- Sub-rede Docker fixa e configurável (`FTP_SUBNET`).
