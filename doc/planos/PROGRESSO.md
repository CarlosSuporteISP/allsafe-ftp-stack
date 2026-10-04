# 📄 PROGRESSO — allsafe-ftp-stack

↩ [🗺️ Plano mestre](README.md)

| Campo | Valor |
|---|---|
| Status | ⛔ Bloqueado — aguarda a ordem do usuário para executar a fase 04 |
| Última atualização | 2026-10-04 06:45 — por Claude Code (Flatpak/VS Code) |
| Branch | `docs/padrao-doc-e-plano` |
| Tamanho | 🟡 Médio |

---

## 🧱 Fases

| Nº | Fase | Status | Concluída em |
|---|---|---|---|
| 01 | Base da stack | ✅ Concluído | 2026-09-11 |
| 02 | Perfis e operação | ✅ Concluído | 2026-09-25 |
| 03 | Documentação e plano no padrão | ✅ Concluído | 2026-10-04 |
| 04 | Pastas fixas e instância isolada | ⛔ Bloqueado (ordem do usuário) | — |
| 05 | Instalação em um comando | ⏳ A fazer | — |
| 06 | Testes automatizados | ⏳ A fazer | — |
| 07 | Backup, restauração e produção | ⏳ A fazer | — |

---

## ▶️ Próximo passo

> ⚠️ **Não executar sem a ordem do usuário.** O pedido desta entrega foi criar a documentação e o plano, fazer commit e push, e **não executar ainda**.

Quando o usuário mandar executar:

1. Criar a branch `feat/pastas-fixas` a partir da `main` atualizada.
2. Abrir a [fase 04](README.md#fase-04) e seguir os passos na ordem, começando pelo passo 1 (`DATA_DIR`, `BACKUP_DIR` e `TEMP_DIR` no `.env.example`).
3. Validar no portão da fase, registrar o resultado e seguir para a fase 05.

---

## 📖 Ler antes de continuar

| Arquivo | Por quê |
|---|---|
| [Plano mestre](README.md) | Fases, portões, riscos e pendências |
| [`compose.yaml`](../../compose.yaml) | Volumes, nomes e rede que a fase 04 altera |
| [`deploy.sh`](../../deploy.sh) | Fluxo de instalação que a fase 05 altera |
| [`scripts/validate.sh`](../../scripts/validate.sh) | Validação existente, base da fase 06 |
| [`.env.example`](../../.env.example) | Variáveis atuais |

Não leia nem exponha o `.env` e o conteúdo de `.secrets/`.

---

## 🧠 Decisões tomadas

| Decisão | Motivo |
|---|---|
| Tamanho 🟡 Médio, fases como seções do plano mestre | Um serviço, com dependência de ordem entre as mudanças e dados a preservar |
| Fases 01 a 03 registradas como entregues | Já existiam no repositório ou foram feitas nesta entrega |
| _Bind mount_ nas pastas fixas em vez de volumes nomeados | Dado em caminho conhecido, backup simples |
| Instalação em um comando com padrão em `127.0.0.1` | Sobe sem perguntas e sem expor nada |
| Testes com `curl --ssl-reqd` a partir do host | Já instalado e testa a porta publicada; `lftp` como alternativa |
| Nenhuma alteração de código da stack na fase 03 | Pedido do usuário: só criar, sem executar |
| Créditos: usuário, Claude e projetos oficiais | Determinação do usuário |
| Versão em `0.1.0`, sem tag | Tag e release só por ordem |

---

## ⚠️ Problemas

| Problema | Situação |
|---|---|
| `gh` não autenticado neste host | O PR é aberto pelo usuário, pelo link de comparação; descrição e tópicos ficam em Pendências |
| Stack não instalada neste host | Só a validação estática pôde ser executada |
| `lftp` e `shellcheck` ausentes | Instalar na fase 06, se forem usados |

---

## 🧪 Comandos para validar

```bash
git status --short                 # só documentação, diagramas, VERSION e CHANGELOG.md
./scripts/validate.sh              # 'Validacao FTP concluida.'
./deploy.sh --check-only           # valida perfil e Compose sem subir nada (exige o .env)
docker ps -a --filter name=allsafe-ftp   # nenhuma instância neste host
```

---

## 🙋 Depende do usuário

- Ordem para executar a fase 04.
- Confirmar ou ajustar as fases 04 a 07.
- Aceitar o PR da branch `docs/padrao-doc-e-plano`.
- Versão, tag e release.
- Licença.
- Descrição e tópicos do repositório (`gh repo edit`, no plano mestre).
- Envio ao remoto `empresa`.

---

⬅️ [🗺️ Plano mestre](README.md) · 🏠 [Documentação](../README.md) · ➡️ [🧪 Testes](testes/README.md)
