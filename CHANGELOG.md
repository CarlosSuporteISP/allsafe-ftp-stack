# 🏷️ Changelog — allsafe-ftp-stack

Histórico de mudanças por versão. A versão segue o formato `MAJOR.MINOR.PATCH` e fica registrada em [`VERSION`](VERSION).

↩ [README do projeto](README.md)

## [Não lançado]

Nada ainda.

## [0.3.0] - 2026-10-04

Painel web seguro. **Uso só em rede privada, atrás de firewall**: o painel recusa por código endereço e rede que não sejam privados.

### Adicionado

- Painel web no serviço `painel` (container `allsafe-ftp-painel`): cria, troca a senha e remove os usuários do FTP pelo navegador, sem reiniciar o servidor. Abas de visão geral, usuários, segurança e atividade.
- Proteções do painel: só HTTPS (TLS 1.2 ou mais novo), uma senha guardada como hash `scrypt`, sessão de 15 minutos presa ao endereço do cliente, bloqueio depois de cinco senhas erradas, token CSRF e conferência do `Origin`, recusa de cliente fora das redes permitidas e de `Host` desconhecido, cabeçalhos de segurança, nenhum JavaScript e auditoria de cada ação em `DATA_DIR/painel/auditoria.log`.
- Variáveis `PAINEL_IMAGE`, `PAINEL_CONTAINER_NAME`, `PAINEL_BIND_IP`, `PAINEL_PORT`, `PAINEL_REDES_PERMITIDAS`, `PAINEL_SESSAO_MINUTOS`, `PAINEL_CERT_CN`, `PAINEL_MEMORY_LIMIT`, `PAINEL_CPU_LIMIT` e `PAINEL_PIDS_LIMIT` no `.env.example`.
- `scripts/painel-senha.sh`, que troca a senha do painel gravando só o hash; `scripts/painel-entrypoint.sh`; `scripts/ambiente.sh`, que lê uma chave do `.env` sem executar o arquivo.
- Trava (`flock`) nas alterações de usuário: o `manage-user.sh` e o painel nunca gravam o PureDB ao mesmo tempo.
- Guia [🖥️ Painel web](doc/painel.md), diagramas `painel-diagrama.mmd` e `painel-fluxograma.mmd`, e o painel nos guias de configuração, segredos, segurança, arquitetura, scripts, operação, instalação e solução de problemas.

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
