# 🔐 Testes de segurança — allsafe-ftp-stack

↩ [🗺️ Plano mestre](../README.md#testes)

## 💡 Em poucas palavras

Aqui ficam os testes que tentam fazer o que **não** deveria ser possível: entrar sem criptografia, sair da própria pasta, entrar como anônimo. Cada um só passa se o servidor recusar. Nenhum foi executado ainda: todos são da fase 06.

---

## 📋 Casos

| Nº | Caso | Comando ou roteiro | Resultado esperado | Último resultado |
|---|---|---|---|---|
| 1 | Login sem TLS | `curl` em FTP puro, sem `--ssl-reqd` | Login recusado | ⏳ A fazer (fase 06) |
| 2 | Login anônimo | Usuário `anonymous` por FTPS | Login recusado | ⏳ A fazer (fase 06) |
| 3 | Fuga do `chroot` | Pedir `../` e `/etc/passwd` depois do login | Fica na pasta do usuário; arquivo do sistema inacessível | ⏳ A fazer (fase 06) |
| 4 | Isolamento entre usuários | Usuário A tenta listar `/data/<usuario-b>` | Recusa | ⏳ A fazer (fase 06) |
| 5 | Senha errada | Login com senha incorreta | `530 Login authentication failed` | ⏳ A fazer (fase 06) |
| 6 | `SITE CHMOD` | Pedir `chmod` em um arquivo enviado | Recusa | ⏳ A fazer (fase 06) |
| 7 | Dados sem criptografia no modo `2` | Login com TLS e transferência sem `PROT P` | Registrar o comportamento real; base para decidir o modo `3` | ⏳ A fazer (fase 06) |
| 8 | Container endurecido | `docker inspect` de `ReadonlyRootfs`, `CapDrop` e `SecurityOpt` | `true`, `ALL` e `no-new-privileges` | ⏳ A fazer (fase 06) |
| 9 | Segredo fora da imagem | Procurar a senha em `docker history` e nas variáveis da imagem | Nada encontrado | ⏳ A fazer (fase 06) |
| 10 | Segredo fora do Git | `git ls-files` e `git log` sem `.env` nem `.secrets/*.txt` | Nada versionado | ⏳ A fazer (fase 06) |

---

## 🗂️ Resultados

Cada execução vira um arquivo em `resultados/`, com o nome `AAAAMMDD-HHMMSS-<o-que>.md` e a saída real. Senhas, tokens e chaves nunca entram: use `<REDACTED>`.

Ainda não há resultado: a pasta `resultados/` nasce com a primeira execução.

---

⬅️ [🧪 Testes funcionais](../testes/README.md) · 🏠 [🗺️ Plano mestre](../README.md) · ➡️ [🌐 Rede](../rede/README.md)
