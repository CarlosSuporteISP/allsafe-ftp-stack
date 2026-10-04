# 🧪 Testes funcionais — allsafe-ftp-stack

↩ [🗺️ Plano mestre](../README.md#testes)

## 💡 Em poucas palavras

Aqui ficam os testes que mostram se a stack funciona: se os scripts e o Compose estão corretos e se um equipamento consegue entrar, enviar e baixar um arquivo. Só a validação estática já foi executada; os testes com o servidor no ar são da fase 06.

---

## 📋 Casos

| Nº | Caso | Comando ou roteiro | Resultado esperado | Último resultado |
|---|---|---|---|---|
| 1 | Validação estática | `./scripts/validate.sh` | `compose OK` com os três perfis e `Validacao FTP concluida.` | ✅ 2026-10-04 06:30 — [resultado](resultados/20261004-063044-validacao-estatica.md) |
| 2 | Validação em execução | `./scripts/validate.sh --runtime` | Serviço `running`, `healthy` e usuário inicial no PureDB | ⏳ A fazer (fase 06) |
| 3 | Login por FTPS | `curl --ssl-reqd` com o usuário inicial | Login aceito, listagem da pasta | ⏳ A fazer (fase 06) |
| 4 | Envio de arquivo | `curl --ssl-reqd -T <arquivo>` | Arquivo gravado em `/data/<usuario>` | ⏳ A fazer (fase 06) |
| 5 | Download e comparação | Baixar o arquivo enviado e comparar o `sha256sum` | Conteúdo idêntico | ⏳ A fazer (fase 06) |
| 6 | Ciclo de usuário | `manage-user.sh add`, login, `passwd`, login, `del` | Cada etapa reflete no login; a pasta fica depois do `del` | ⏳ A fazer (fase 06) |
| 7 | Senha curta | `manage-user.sh add` com menos de 12 caracteres | Recusa com `Senha deve ter pelo menos 12 caracteres` | ⏳ A fazer (fase 06) |
| 8 | Reinício | `docker compose restart ftp` | Usuários e arquivos preservados | ⏳ A fazer (fase 06) |
| 9 | Backup e restauração | `scripts/backup.sh` e `scripts/restaurar.sh` | Arquivo restaurado idêntico ao enviado | ⏳ A fazer (fase 07) |

---

## 🗂️ Resultados

Cada execução vira um arquivo em [`resultados/`](resultados/), com o nome `AAAAMMDD-HHMMSS-<o-que>.md` e a saída real do comando. Senhas, tokens e chaves nunca entram: use `<REDACTED>`.

| Data | Arquivo | Resultado |
|---|---|---|
| 2026-10-04 06:30 | [20261004-063044-validacao-estatica.md](resultados/20261004-063044-validacao-estatica.md) | ✅ Aprovado |

---

⬅️ [📄 PROGRESSO](../PROGRESSO.md) · 🏠 [🗺️ Plano mestre](../README.md) · ➡️ [🔐 Segurança](../seguranca/README.md)
