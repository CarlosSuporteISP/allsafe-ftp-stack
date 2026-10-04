# 🧪 Resultado — validação estática

↩ [🧪 Testes funcionais](../README.md)

| Campo | Valor |
|---|---|
| Data | 2026-10-04 06:30:44 |
| Caso | 1 · Validação estática |
| Branch | `docs/padrao-doc-e-plano` |
| Ambiente | Docker Engine 29.8.2 · Docker Compose 5.5.1 · Bash 5.2 |
| Resultado | ✅ Aprovado (código de saída `0`) |

## ⌨️ Comando

```bash
./scripts/validate.sh
```

## 📜 Saída

```text
compose OK com large.env
compose OK com medium.env
compose OK com small.env
Validacao FTP concluida.
```

## 🔬 O que foi coberto

- `bash -n` em `deploy.sh`, `manage-user.sh` e `scripts/*.sh`.
- `docker compose config --quiet` com `.env.example` e cada perfil de `profiles/`.

## ⚠️ O que não foi coberto

Nenhum teste com o servidor no ar: a stack não está instalada neste host e o plano ainda não foi executado. Login, envio, download, `chroot` e recusa sem TLS ficam para a fase 06.

---

⬅️ [🧪 Testes funcionais](../README.md) · 🏠 [🗺️ Plano mestre](../../README.md)
