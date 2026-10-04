# 🏷️ Changelog — allsafe-ftp-stack

Histórico de mudanças por versão. A versão segue o formato `MAJOR.MINOR.PATCH` e fica registrada em [`VERSION`](VERSION).

↩ [README do projeto](README.md)

## [Não lançado]

### Adicionado

- Aviso de uso **só em rede privada, atrás de firewall**, no README e em `doc/seguranca.md`, com exemplo de regra na cadeia `DOCKER-USER`.
- Plano refeito com as fases 04 a 09: pastas fixas, segredos e rede privada; painel web seguro; instalação em um comando; testes automatizados; backup e restauração; documentação final. Um fluxograma por fase.
- Diagramas abrem com zoom e movimento: a imagem liga para o `.mmd` (visualizador do GitHub) e cada pasta `diagramas/` tem um `visualizador.html`.
- `*.pdf` e todo o conteúdo de `.secrets/` no `.gitignore`.
- Plano mestre em `doc/planos/`, com as fases entregues e as fases a fazer, `PROGRESSO.md` e as pastas de teste por tipo (`testes/`, `seguranca/`, `rede/`).
- Diagramas sem cor, com fonte `.mmd` e SVG claro e escuro: 11 em `doc/diagramas/` e 11 em `doc/planos/diagramas/`.
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

## [0.1.0]

Estado da stack antes da adoção do versionamento. Ainda sem tag.

### Adicionado

- Imagem do Pure-FTPd sobre Debian 12, fixada por digest.
- `compose.yaml` endurecido: raiz somente leitura, `cap_drop: ALL`, `no-new-privileges`, limites de memória, CPU e processos, healthcheck.
- Usuários virtuais em PureDB, com `chroot` e senha mínima de 12 caracteres.
- FTPS explícito obrigatório, com certificado autoassinado gerado na primeira subida.
- Senha do usuário inicial em `.secrets/`, fora do Git e da imagem.
- Perfis `small`, `medium` e `large`.
- Scripts `deploy.sh`, `manage-user.sh` e `scripts/validate.sh`.
- Sub-rede Docker fixa e configurável (`FTP_SUBNET`).
