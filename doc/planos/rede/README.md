# 🌐 Testes de rede — allsafe-ftp-stack

↩ [🗺️ Plano mestre](../README.md#testes)

## 💡 Em poucas palavras

Aqui ficam os testes que conferem por onde a stack responde: em qual endereço e porta o FTP e o painel escutam, se a faixa de portas de dados está publicada e se o limite de conexões funciona. Nenhum foi executado ainda: todos são da fase 07.

---

## 📋 Casos

| Nº | Caso | Comando ou roteiro | Resultado esperado | Último resultado |
|---|---|---|---|---|
| 1 | Bind da porta de controle | `ss -ltn` no host | Escuta só em `FTP_BIND_IP:FTP_PORT` | ⏳ A fazer (fase 07) |
| 2 | Faixa passiva publicada | `docker compose ps` | Faixa do perfil publicada 1:1 | ⏳ A fazer (fase 07) |
| 3 | Transferência em modo passivo | `curl --ssl-reqd --ftp-pasv` | Listagem e envio concluídos | ⏳ A fazer (fase 07) |
| 4 | Endereço anunciado | Resposta do `PASV` no modo detalhado do `curl` | Traz o `FTP_PUBLIC_IP` | ⏳ A fazer (fase 07) |
| 5 | Limite de sessões por IP | Abrir mais sessões que `FTP_MAX_CLIENTS_PER_IP` | Sessão excedente recusada com `421` | ⏳ A fazer (fase 07) |
| 6 | Sub-rede Docker | `docker network inspect` da rede da stack | Sub-rede igual a `FTP_SUBNET` | ⏳ A fazer (fase 07) |
| 7 | Troca de perfil | `./deploy.sh --size medium` e depois `docker compose up -d` | Faixa passiva e limites do perfil `medium` nos dois casos | ⏳ A fazer (fase 07) |
| 8 | Duas instâncias no mesmo host | Instância de teste com nomes, portas e sub-rede diferentes | As duas sobem sem conflito | ⏳ A fazer (fase 07) |
| 9 | Bind do painel | `ss -ltn` no host | Escuta só em `PAINEL_BIND_IP:PAINEL_PORT` | ⏳ A fazer (fase 07) |
| 10 | Painel só em HTTPS | `curl -k https://` e `curl http://` na porta do painel | HTTPS responde; HTTP não | ⏳ A fazer (fase 07) |
| 11 | Nenhuma porta além das previstas | `docker compose ps` | Só controle, faixa passiva e painel publicados | ⏳ A fazer (fase 07) |
| 12 | Painel alcança o FTP pela rede interna | Aba de visão geral | Mostra o FTP como ativo, sem depender da porta publicada | ⏳ A fazer (fase 07) |

---

## 🗂️ Resultados

Cada execução vira um arquivo em `resultados/`, com o nome `AAAAMMDD-HHMMSS-<o-que>.md` e a saída real. Senhas, tokens e chaves nunca entram: use `<REDACTED>`.

Ainda não há resultado: a pasta `resultados/` nasce com a primeira execução.

---

⬅️ [🔐 Segurança](../seguranca/README.md) · 🏠 [🗺️ Plano mestre](../README.md) · ➡️ [README do projeto](../../../README.md)
