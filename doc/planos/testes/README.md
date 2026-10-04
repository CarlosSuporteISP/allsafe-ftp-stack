# 🧪 Testes funcionais — allsafe-ftp-stack

↩ [🗺️ Plano mestre](../README.md#testes)

## 💡 Em poucas palavras

Aqui ficam os testes que mostram se a stack funciona: se os scripts e o Compose estão corretos, se um equipamento consegue entrar, enviar e baixar um arquivo e se o painel web cria, altera e remove usuários. A validação estática e o portão da fase 04 já foram executados; a bateria completa, com o servidor e o painel no ar, é da fase 07.

---

## 📋 Casos

### ⚙️ FTP

| Nº | Caso | Comando ou roteiro | Resultado esperado | Último resultado |
|---|---|---|---|---|
| 1 | Validação estática | `./scripts/validate.sh` | `compose OK` com os três perfis e `Validacao FTP concluida.` | ✅ 2026-10-04 06:30 — [resultado](resultados/20261004-063044-validacao-estatica.md) |
| 2 | Validação em execução | `./scripts/validate.sh --runtime` | Serviços `running`, `healthy` e usuário inicial no PureDB | ⏳ A fazer (fase 07) |
| 3 | Login por FTPS | `curl --ssl-reqd` com o usuário inicial | Login aceito, listagem da pasta | ⏳ A fazer (fase 07) |
| 4 | Envio de arquivo | `curl --ssl-reqd -T <arquivo>` | Arquivo gravado em `DATA_DIR/dados/<usuario>` | ⏳ A fazer (fase 07) |
| 5 | Download e comparação | Baixar o arquivo enviado e comparar o `sha256sum` | Conteúdo idêntico | ⏳ A fazer (fase 07) |
| 6 | Ciclo de usuário pelo terminal | `manage-user.sh add`, login, `passwd`, login, `del` | Cada etapa reflete no login; a pasta fica depois do `del` | ⏳ A fazer (fase 07) |
| 7 | Senha curta | `manage-user.sh add` com menos de 12 caracteres | Recusa com `Senha deve ter pelo menos 12 caracteres` | ⏳ A fazer (fase 07) |
| 8 | Reinício | `docker compose restart ftp` | Usuários e arquivos preservados | ⏳ A fazer (fase 07) |
| 9 | Backup e restauração | `scripts/backup.sh` e `scripts/restaurar.sh` | Arquivo restaurado idêntico ao enviado | ⏳ A fazer (fase 08) |
| 10 | Instalação em um comando | `./deploy.sh` em pasta limpa, duas vezes | Uma execução, sem perguntas; a segunda não muda senha nem dados | ⏳ A fazer (fase 06) |

### 🖥️ Painel web

| Nº | Caso | Comando ou roteiro | Resultado esperado | Último resultado |
|---|---|---|---|---|
| 11 | Saúde do painel | `curl` em `/saude` | `200` com `ok` | ⏳ A fazer (fase 07) |
| 12 | Entrada | Enviar a senha certa na tela de entrada | Sessão criada; a visão geral abre | ⏳ A fazer (fase 07) |
| 13 | Visão geral | Abrir a aba com sessão | Estado do FTP, validade do certificado e contagem de usuários | ⏳ A fazer (fase 07) |
| 14 | Novo usuário pelo painel | Criar o usuário e entrar por FTPS com ele | Login e envio funcionam, sem reiniciar o FTP | ⏳ A fazer (fase 07) |
| 15 | Troca de senha pelo painel | Trocar e entrar por FTPS | A senha nova vale; a antiga é recusada | ⏳ A fazer (fase 07) |
| 16 | Remoção pelo painel | Remover, confirmar e tentar entrar por FTPS | Login recusado; os arquivos continuam na pasta | ⏳ A fazer (fase 07) |
| 17 | Atividade | Abrir a aba depois dos casos 12 a 16 | Entrada e alterações registradas, sem senha | ⏳ A fazer (fase 07) |
| 18 | Saída | Usar o botão de sair e abrir uma aba | Volta para a tela de entrada | ⏳ A fazer (fase 07) |

---

## 🗂️ Resultados

Cada execução vira um arquivo em [`resultados/`](resultados/), com o nome `AAAAMMDD-HHMMSS-<o-que>.md` e a saída real do comando. Senhas, tokens e chaves nunca entram: use `<REDACTED>`.

| Data | Arquivo | Resultado |
|---|---|---|
| 2026-10-04 06:30 | [20261004-063044-validacao-estatica.md](resultados/20261004-063044-validacao-estatica.md) | ✅ Aprovado |
| 2026-10-04 08:00 | [20261004-080025-portao-fase-04.md](resultados/20261004-080025-portao-fase-04.md) | ✅ Aprovado — portão da fase 04 e roteiro de migração |

---

⬅️ [📄 PROGRESSO](../PROGRESSO.md) · 🏠 [🗺️ Plano mestre](../README.md) · ➡️ [🔐 Segurança](../seguranca/README.md)
