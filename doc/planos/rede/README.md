# 🌐 Testes de rede — allsafe-ftp-stack

↩ [🗺️ Plano mestre](../README.md#testes)

## 💡 Em poucas palavras

Aqui ficam os testes que conferem por onde o servidor responde: em qual endereço e porta ele escuta, se a faixa de portas de dados está publicada e se o limite de conexões funciona. Nenhum foi executado ainda: todos são da fase 06.

---

## 📋 Casos

| Nº | Caso | Comando ou roteiro | Resultado esperado | Último resultado |
|---|---|---|---|---|
| 1 | Bind da porta de controle | `ss -ltn` no host | Escuta só em `FTP_BIND_IP:FTP_PORT` | ⏳ A fazer (fase 06) |
| 2 | Faixa passiva publicada | `docker compose ps` | Faixa do perfil publicada 1:1 | ⏳ A fazer (fase 06) |
| 3 | Transferência em modo passivo | `curl --ssl-reqd --ftp-pasv` | Listagem e envio concluídos | ⏳ A fazer (fase 06) |
| 4 | Endereço anunciado | Resposta do `PASV` no modo detalhado do `curl` | Traz o `FTP_PUBLIC_IP` | ⏳ A fazer (fase 06) |
| 5 | Limite de sessões por IP | Abrir mais sessões que `FTP_MAX_CLIENTS_PER_IP` | Sessão excedente recusada com `421` | ⏳ A fazer (fase 06) |
| 6 | Sub-rede Docker | `docker network inspect allsafe-ftp-network` | Sub-rede igual a `FTP_SUBNET` | ⏳ A fazer (fase 06) |
| 7 | Troca de perfil | `./deploy.sh --size medium` | Faixa passiva e limites do perfil `medium` | ⏳ A fazer (fase 06) |
| 8 | Duas instâncias no mesmo host | Instância de teste com nomes e portas diferentes | As duas sobem sem conflito | ⏳ A fazer (fase 06) |

---

## 🗂️ Resultados

Cada execução vira um arquivo em `resultados/`, com o nome `AAAAMMDD-HHMMSS-<o-que>.md` e a saída real. Senhas, tokens e chaves nunca entram: use `<REDACTED>`.

Ainda não há resultado: a pasta `resultados/` nasce com a primeira execução.

---

⬅️ [🔐 Segurança](../seguranca/README.md) · 🏠 [🗺️ Plano mestre](../README.md) · ➡️ [README do projeto](../../../README.md)
