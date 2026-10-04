# 🔐 Testes de segurança — allsafe-ftp-stack

↩ [🗺️ Plano mestre](../README.md#testes)

## 💡 Em poucas palavras

Aqui ficam os testes que tentam fazer o que **não** deveria ser possível: entrar sem criptografia, sair da própria pasta, abrir o painel sem senha, publicar a stack em IP público. Cada um só passa se o sistema recusar. Nenhum foi executado ainda: todos são da fase 07.

---

## 📋 Casos

### ⚙️ FTP

| Nº | Caso | Comando ou roteiro | Resultado esperado | Último resultado |
|---|---|---|---|---|
| 1 | Login sem TLS | `curl` em FTP puro, sem `--ssl-reqd` | Login recusado | ⏳ A fazer (fase 07) |
| 2 | Login anônimo | Usuário `anonymous` por FTPS | Login recusado | ⏳ A fazer (fase 07) |
| 3 | Fuga do `chroot` | Pedir `../` e `/etc/passwd` depois do login | Fica na pasta do usuário; arquivo do sistema inacessível | ⏳ A fazer (fase 07) |
| 4 | Isolamento entre usuários | Usuário A tenta listar a pasta do usuário B | Recusa | ⏳ A fazer (fase 07) |
| 5 | Senha errada | Login com senha incorreta | `530 Login authentication failed` | ⏳ A fazer (fase 07) |
| 6 | `SITE CHMOD` | Pedir `chmod` em um arquivo enviado | Recusa | ⏳ A fazer (fase 07) |
| 7 | Dados sem criptografia no modo `2` | Login com TLS e transferência sem `PROT P` | Registrar o comportamento real; base para decidir o modo `3` | ⏳ A fazer (fase 07) |
| 8 | Container endurecido | `docker inspect` de `ReadonlyRootfs`, `CapDrop` e `SecurityOpt`, nos dois serviços | `true`, `ALL` e `no-new-privileges` | ⏳ A fazer (fase 07) |

### 🔑 Segredos

| Nº | Caso | Comando ou roteiro | Resultado esperado | Último resultado |
|---|---|---|---|---|
| 9 | Segredo fora da imagem | Procurar a senha em `docker history` e nas variáveis das imagens | Nada encontrado | ⏳ A fazer (fase 07) |
| 10 | Segredo fora do Git | `git ls-files` e `git log` sem `.env` nem arquivo de `.secrets/` além do `.gitkeep` | Nada versionado | ⏳ A fazer (fase 07) |
| 11 | Nenhuma senha no `.env` | Procurar chave com `PASSWORD`, `TOKEN` ou `SECRET` preenchida no `.env` e no `.env.example` | Nenhuma | ⏳ A fazer (fase 07) |
| 12 | Nenhuma senha em variável de ambiente | `docker inspect` das variáveis dos dois containers | Nenhuma senha nem hash | ⏳ A fazer (fase 07) |
| 13 | Cada serviço vê só o próprio segredo | `ls /run/secrets` em cada container | `ftp`: só `ftp_password`; `painel`: só `painel_password_hash` | ⏳ A fazer (fase 07) |
| 14 | Permissão dos segredos | `stat` em `.secrets/` e nos arquivos | Pasta `700`, arquivos `600` | ⏳ A fazer (fase 07) |
| 15 | `.env` antigo com senha | `deploy.sh` com `FTP_PASSWORD` preenchido | Recusa e explica a migração | ⏳ A fazer (fase 07) |

### 🧱 Rede privada

| Nº | Caso | Comando ou roteiro | Resultado esperado | Último resultado |
|---|---|---|---|---|
| 16 | Bind do FTP em todas as interfaces | `FTP_BIND_IP=0.0.0.0` | `deploy.sh` e container recusam | ⏳ A fazer (fase 07) |
| 17 | Bind do FTP em IP público | `FTP_BIND_IP=8.8.8.8` | `deploy.sh` e container recusam | ⏳ A fazer (fase 07) |
| 18 | IP anunciado público | `FTP_PUBLIC_IP=8.8.8.8` | `deploy.sh` e container recusam | ⏳ A fazer (fase 07) |
| 19 | Bind do painel fora de IP privado | `PAINEL_BIND_IP=0.0.0.0` | `deploy.sh` e container recusam | ⏳ A fazer (fase 07) |
| 20 | Rede permitida pública no painel | `PAINEL_REDES_PERMITIDAS=0.0.0.0/0` | Container recusa | ⏳ A fazer (fase 07) |
| 21 | Função `ip_privado` | Tabela de endereços privados, públicos, CGNAT e malformados | Aceita só loopback e as três faixas privadas | ⏳ A fazer (fase 07) |

### 🖥️ Painel web

| Nº | Caso | Comando ou roteiro | Resultado esperado | Último resultado |
|---|---|---|---|---|
| 22 | Aba sem sessão | Abrir cada aba sem cookie | Redireciona para a entrada; nada é mostrado | ⏳ A fazer (fase 07) |
| 23 | Senha errada | Enviar senha incorreta | Recusa, sem dizer o motivo exato; registra na auditoria | ⏳ A fazer (fase 07) |
| 24 | Limite de tentativas | Seis tentativas erradas do mesmo IP | A partir da sexta, recusa até com a senha certa | ⏳ A fazer (fase 07) |
| 25 | Envio sem token CSRF | `POST` com sessão válida e sem o token | Recusado; nada é alterado | ⏳ A fazer (fase 07) |
| 26 | Envio com `Origin` de fora | `POST` com `Origin` de outro endereço | Recusado; nada é alterado | ⏳ A fazer (fase 07) |
| 27 | Cabeçalho `Host` inesperado | Pedido com `Host` de nome público | Recusado | ⏳ A fazer (fase 07) |
| 28 | Atributos do cookie | Cabeçalho `Set-Cookie` da entrada | `__Host-`, `Secure`, `HttpOnly`, `SameSite=Strict` | ⏳ A fazer (fase 07) |
| 29 | Cabeçalhos de segurança | Cabeçalhos de qualquer resposta | CSP, `X-Frame-Options`, `nosniff`, HSTS, `no-store` | ⏳ A fazer (fase 07) |
| 30 | Sem HTTP | Pedido em HTTP puro na porta do painel | Sem resposta útil; só HTTPS atende | ⏳ A fazer (fase 07) |
| 31 | TLS antigo | `openssl s_client -tls1_1` | Recusado | ⏳ A fazer (fase 07) |
| 32 | Nome de usuário malicioso | Criar usuário com `../x`, espaço e `;` | Recusado pela validação; nada é criado | ⏳ A fazer (fase 07) |
| 33 | Senha fraca no painel | Criar usuário com senha de menos de 12 caracteres | Recusado | ⏳ A fazer (fase 07) |
| 34 | Corpo grande demais | `POST` acima do limite | Recusado com `413` | ⏳ A fazer (fase 07) |
| 35 | Sem socket do Docker | `docker inspect` das montagens do painel | Nenhum `docker.sock` | ⏳ A fazer (fase 07) |
| 36 | Auditoria sem segredo | Procurar senha e token em `auditoria.log` | Nada encontrado | ⏳ A fazer (fase 07) |
| 37 | Sessão encerrada | Reutilizar o cookie depois de sair | Recusado | ⏳ A fazer (fase 07) |

---

## 🗂️ Resultados

Cada execução vira um arquivo em `resultados/`, com o nome `AAAAMMDD-HHMMSS-<o-que>.md` e a saída real. Senhas, tokens e chaves nunca entram: use `<REDACTED>`.

Ainda não há resultado: a pasta `resultados/` nasce com a primeira execução.

---

⬅️ [🧪 Testes funcionais](../testes/README.md) · 🏠 [🗺️ Plano mestre](../README.md) · ➡️ [🌐 Rede](../rede/README.md)
