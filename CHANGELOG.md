# 🏷️ Changelog — allsafe-ftp-stack

Histórico de mudanças por versão. A versão segue o formato `MAJOR.MINOR.PATCH` e fica registrada em [`VERSION`](VERSION).

↩ [README do projeto](README.md)

## [Não lançado]

Nada ainda.

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
