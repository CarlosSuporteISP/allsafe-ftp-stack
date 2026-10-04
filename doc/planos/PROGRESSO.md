# 📄 PROGRESSO — allsafe-ftp-stack

↩ [🗺️ Plano mestre](README.md)

| Campo | Valor |
|---|---|
| Status | 🔄 Em execução — fase 04 a começar |
| Última atualização | 2026-10-04 — por Claude Code (VS Code) |
| Branch | `feat/painel-web-e-pastas-fixas` |
| Tamanho | 🟡 Médio |

---

## 🧱 Fases

| Nº | Fase | Status | Concluída em |
|---|---|---|---|
| 01 | Base da stack | ✅ Concluído | 2026-09-11 |
| 02 | Perfis e operação | ✅ Concluído | 2026-09-25 |
| 03 | Documentação e plano no padrão | ✅ Concluído | 2026-10-04 |
| 04 | Pastas fixas, segredos e rede privada | ⏳ A fazer | — |
| 05 | Painel web seguro | ⏳ A fazer | — |
| 06 | Instalação em um comando | ⏳ A fazer | — |
| 07 | Testes automatizados | ⏳ A fazer | — |
| 08 | Backup e restauração | ⏳ A fazer | — |
| 09 | Documentação final e capturas | ⏳ A fazer | — |

---

## ▶️ Próximo passo

O usuário mandou executar o plano inteiro, uma fase emendada na outra, sem perguntar entre elas.

1. Abrir a [fase 04](README.md#fase-04) e começar pelo passo 1: variáveis de pasta e de nome no `.env.example`, sem `FTP_PASSWORD` nem `FTP_PASSWORD_FILE`.
2. Seguir os passos na ordem, validar no portão, registrar aqui e fazer commit.
3. Emendar a fase 05, e assim até a 09.

Ordens do usuário que valem para todas as fases:

- Commit e push **deste plano antes de executar**, e de novo ao final.
- **Cada publicação avança a versão** (`VERSION`, `CHANGELOG.md`, selo do README) e ganha a tag `vX.Y.Z`: fase 04 = `0.2.0`, 05 = `0.3.0`, 06 = `0.4.0`, 07 = `0.5.0`, 08 = `0.6.0`, 09 = `1.0.0`.
- Diagrama novo ou alterado: editar o `.mmd` e rodar o `renderizar.sh`, que atualiza os blocos Mermaid dos `.md`.
- A stack é só para **IP privado, interno, atrás de firewall**: avisar na documentação e recusar por código.
- O painel web tem de ser **seguro**.
- `.env` só com variável ajustável; senha, token, chave e identificador de integração só em `.secrets/`.
- PDF só a pedido, e nunca no Git.

---

## 📖 Ler antes de continuar

| Arquivo | Por quê |
|---|---|
| [Plano mestre](README.md) | Fases, portões, riscos e pendências |
| [`compose.yaml`](../../compose.yaml) | Volumes, nomes, rede e segredos que a fase 04 altera; serviço que a fase 05 acrescenta |
| [`scripts/entrypoint.sh`](../../scripts/entrypoint.sh) | Leitura da senha e validações que a fase 04 altera |
| [`scripts/ftp-user.sh`](../../scripts/ftp-user.sh) | Regra de usuário e senha que o painel reutiliza |
| [`deploy.sh`](../../deploy.sh) | Fluxo de instalação, alterado nas fases 04, 05 e 06 |
| [`.env.example`](../../.env.example) | Variáveis atuais |

Não leia nem exponha o `.env` e o conteúdo de `.secrets/`.

---

## 🧠 Decisões tomadas

| Decisão | Motivo |
|---|---|
| Tamanho 🟡 Médio, fases como seções do plano mestre | Dois serviços em um host, com dependência de ordem entre as mudanças |
| _Bind mount_ nas pastas fixas em vez de volumes nomeados | Dado em caminho conhecido, backup simples |
| Senhas só em `.secrets/`, entregues por `secrets:` do Compose | Regra do usuário; cada serviço vê só o segredo dele |
| Senha do FTP inicial em texto (`0600`), senha do painel só como hash scrypt | O entrypoint e o equipamento precisam do valor da primeira; a segunda só é conferida |
| Recusa por código de `0.0.0.0` e de IP público | Aviso sozinho não impede o erro |
| Painel próprio em Python, só biblioteca padrão, sem JavaScript | Menor superfície de ataque; nenhuma dependência externa para manter |
| Painel altera usuários pela pasta `auth` compartilhada, sem socket do Docker | O socket equivale a root no host |
| Instalação em um comando com padrão em `127.0.0.1` | Sobe sem perguntas e sem ficar acessível pela rede |
| Perfil gravado no `.env` | `docker compose up -d` direto mantém os limites |
| Testes com `curl --ssl-reqd` a partir do host, em instância isolada | Já instalado; testa a porta publicada sem tocar na instância definitiva |
| Firewall do host: só documentar | É sistema fora do projeto |
| Créditos: usuário, Claude e projetos oficiais | Determinação do usuário |
| A versão avança a cada publicação, com tag: `0.1.1` agora, uma versão por fase e `1.0.0` na fase 09 | Ordem do usuário; a sequência está no [plano mestre](README.md#versoes) |
| Diagramas nos `.md` como bloco Mermaid, direto do `.mmd`, com fundo escuro; SVG só na pasta | Ordem do usuário: zoom e movimento no próprio diagrama |

---

## ⚠️ Problemas

| Problema | Situação |
|---|---|
| `gh` não autenticado neste host | O PR é aberto pelo usuário, pelo link de comparação; Release, descrição e tópicos ficam em Pendências |
| `lftp` e `shellcheck` ausentes | Não são obrigatórios; os testes usam `curl` |

---

## 🧪 Comandos para validar

```bash
git status --short                       # árvore limpa ao fim de cada fase
./scripts/validate.sh                    # 'Validacao FTP concluida.'
docker ps -a --filter name=allsafe-ftp   # o que está no ar neste host
```

---

## 🛑 Como derrubar

Nada no ar ainda. A partir da fase 06: `./deploy.sh --remover` derruba e preserva os dados; com `--apagar-dados`, apaga também `DATA_DIR`.

---

## 🙋 Depende do usuário

- Aplicar as regras de firewall no host, quando abrir a stack para a rede interna.
- Aceitar o PR da branch `feat/painel-web-e-pastas-fixas`.
- Release no GitHub de cada tag (depende do `gh` autenticado).
- Licença.
- Descrição e tópicos do repositório (`gh repo edit`, no plano mestre).
- Envio ao remoto `empresa`.

---

⬅️ [🗺️ Plano mestre](README.md) · 🏠 [Documentação](../README.md) · ➡️ [🧪 Testes](testes/README.md)
