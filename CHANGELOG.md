# 🏷️ Changelog — allsafe-ftp-stack

Histórico de mudanças por versão. A versão segue o formato `MAJOR.MINOR.PATCH` e fica registrada em [`VERSION`](VERSION).

↩ [README do projeto](README.md)

## [Não lançado]

Nada ainda.

## [1.0.0] - 2026-10-04

Primeira versão pronta para produção: o painel passa a aceitar a entrada pelo navegador e a documentação ganha as fotos de todas as telas. **Uso só em rede privada, atrás de firewall.**

### Adicionado

- Guia [Fotos da aplicação](doc/aplicacao/README.md): todas as telas do painel, menu por menu, com capturas reais, para que serve cada uma, como chegar e o que há na tela.
- Imagem principal e uma imagem de cada aba do painel no [README](README.md#imagens).
- Um caso na bateria de segurança, que passa a 38: a resposta traz `Referrer-Policy: same-origin` e o envio com `Origin: null` é recusado.

### Alterado

- **`Referrer-Policy`:** de `no-referrer` para `same-origin`, no painel e nas respostas do nginx. O endereço da página continua sem sair para outro site; só o próprio painel o recebe.
- Lista de usuários do painel: o nome não quebra de linha e a coluna da pasta ganha a largura que sobrava na de ações.
- Selo de status do README: de em desenvolvimento para estável.

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
