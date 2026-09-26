# 🩺 Solução de problemas — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [📚 Índice da documentação](README.md)

---

<details>
<summary>🧭 Sumário — clique para expandir</summary>

[🧭 Diagnóstico em 30 segundos](#diagnostico-em-30-segundos) · [❌ O container não sobe](#o-container-nao-sobe) · [🔌 Conecta mas falha no login ou na listagem](#conecta-mas-falha-no-login-ou-na-listagem) · [📁 Problemas de arquivo/permissão](#problemas-de-arquivo-permissao) · [🔐 Certificado / TLS](#certificado-tls) · [🧪 Ferramentas de validação](#ferramentas-de-validacao)

</details>

---

<a name="diagnostico-em-30-segundos"></a>

## 🧭 Diagnóstico em 30 segundos

```bash
docker compose ps                                             # o container está 'running'?
docker inspect --format '{{.State.Health.Status}}' allsafe-ftp  # 'healthy'?
docker compose logs --tail 50 ftp                             # o que o entrypoint / pure-ftpd disse?
```

O `entrypoint.sh` aborta com `FALHA: <motivo>` e o container reinicia em laço —
o motivo está sempre na primeira tentativa do log.

---

<a name="o-container-nao-sobe"></a>

## ❌ O container não sobe

| Mensagem no log | Causa | Correção |
|---|---|---|
| `FALHA: FTP_PASSWORD_FILE nao pode ser lido` | `FTP_PASSWORD_FILE` aponta para um arquivo ausente ou sem permissão de leitura. | Crie [`.secrets/ftp_password.txt`](segredos.md) e `chmod 600`. Confirme que o bind `./.secrets` existe. |
| `FALHA: a senha FTP deve ter pelo menos 12 caracteres` | Senha curta (ou arquivo com espaço/linha em branco). | Regrave o arquivo: `printf '%s' 'senha-com-12+' > .secrets/ftp_password.txt`. |
| `FALHA: FTP_USER invalido` | Nome fora de `^[a-z_][a-z0-9_-]{0,31}$`. | Use minúsculas, sem espaço/acento; comece com letra ou `_`. |
| `FALHA: faixa passiva invalida` / `fora dos limites` | `FTP_PASSIVE_PORT_START/END` não numéricos, `<1024`, `>65535` ou invertidos. | Corrija no `.env`; mantenha `START ≤ END`. |
| `FALHA: FTP_TLS_MODE deve ser 1, 2 ou 3` | Valor inválido. | Use `1`, `2` ou `3` (padrão `2`). |
| `bind: address already in use` | `FTP_PORT` ou a faixa passiva já estão ocupadas no host. | Troque a porta/faixa ou libere quem está usando (`ss -ltnp`). |
| `bind: cannot assign requested address` | `FTP_BIND_IP` não existe no host. | Ajuste para um IP configurado na máquina. |

---

<a name="conecta-mas-falha-no-login-ou-na-listagem"></a>

## 🔌 Conecta mas falha no login ou na listagem

| Sintoma | Causa provável | Correção |
|---|---|---|
| Cliente conecta e cai ao pedir `AUTH TLS` obrigatório | Cliente usando FTP **puro** ou FTPS **implícito** (porta 990). | Configure o cliente para **FTP explícito sobre TLS** na porta de controle. |
| `530 Login authentication failed` | Senha errada, usuário não existe no PureDB, ou UID abaixo de 10000. | `./manage-user.sh list`; recrie com `./manage-user.sh passwd <user>`. |
| Login OK, `LIST`/`STOR` trava e dá timeout | Modo **ativo**, ou faixa passiva/`FTP_PUBLIC_IP` bloqueada/errada. | Use modo **passivo**; libere `30000-30049/tcp` no firewall; `FTP_PUBLIC_IP` = IP que o cliente alcança. |
| `425 Could not open data connection` atrás de NAT | `FTP_PUBLIC_IP` aponta para IP interno. | Defina `FTP_PUBLIC_IP` com o IP público e garanta NAT 1:1 da faixa passiva. |
| Erro de certificado no cliente | Certificado ainda é o autoassinado. | Instale um certificado real — [`operacao.md`](operacao.md#certificado-real-de-producao) — ou, só em teste, desative a verificação no cliente. |
| `421 Too many connections` | `FTP_MAX_CLIENTS` ou `FTP_MAX_CLIENTS_PER_IP` atingido. | Aumente no `.env` (e amplie a faixa passiva junto) e `docker compose up -d`. |

---

<a name="problemas-de-arquivo-permissao"></a>

## 📁 Problemas de arquivo/permissão

| Sintoma | Causa | Correção |
|---|---|---|
| `553 Could not create file` | Diretório do usuário sem dono `ftpdata` (uid 10000). | `docker compose exec ftp chown -R 10000:10000 /data/<user>`. |
| Arquivos entram com permissão inesperada | `umask` do `pure-ftpd` é `133:022` (arquivos sem `x`, sem escrita p/ grupo/outros). | Comportamento esperado; ajuste `-U` no [`entrypoint.sh`](../scripts/entrypoint.sh) se precisar. |
| Cliente não consegue `chmod` | `-R` desabilita `SITE CHMOD`. | Intencional (segurança). Remova `-R` do entrypoint só se realmente necessário. |
| `ls` não mostra todos os arquivos | Limite `-L 10000:8` (10000 arquivos / profundidade 8). | Reduza o nº de arquivos por diretório ou ajuste `-L`. |

---

<a name="certificado-tls"></a>

## 🔐 Certificado / TLS

| Sintoma | Causa | Correção |
|---|---|---|
| Novo certificado não é usado após copiar | Serviço não reiniciado, ou PEM sem a chave. | `docker compose restart ftp`; o PEM deve ter **chave + certificado** juntos, `0600`. |
| `entrypoint` gera autoassinado toda subida | O arquivo `/etc/ssl/private/pure-ftpd.pem` não está persistindo. | Confirme o volume `allsafe-ftp-certs` no [`compose.yaml`](../compose.yaml) (`docker volume ls`). |
| Handshake TLS falha com "certificate expired" | Relógio do host errado, ou certificado vencido (autoassinado dura 825 dias). | Sincronize a hora (`08-time/allsafe-ntp-nts-stack`); regenere/renove o certificado. |

---

<a name="ferramentas-de-validacao"></a>

## 🧪 Ferramentas de validação

```bash
./scripts/validate.sh            # bash -n dos scripts + compose config
./scripts/validate.sh --runtime  # + exige container running e healthcheck healthy
docker compose exec ftp pidof pure-ftpd   # o que o healthcheck testa
```

Ainda travado? Colete e analise:

```bash
docker compose logs --no-color ftp > /tmp/allsafe-ftp.log
docker inspect allsafe-ftp > /tmp/allsafe-ftp.inspect.json
```
