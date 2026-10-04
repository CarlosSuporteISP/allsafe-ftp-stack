# 🚨 Solução de problemas — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [📚 Índice da documentação](README.md)

## 💡 Em poucas palavras

Quando algo falha, quase sempre o próprio servidor já disse o motivo. O caminho é sempre o mesmo: ver se o container está de pé, ler a mensagem do log, achar a linha correspondente nas tabelas deste guia, aplicar a correção e conferir de novo.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="diagramas/diagnostico-diagrama-escuro.svg">
  <img src="diagramas/diagnostico-diagrama.svg" alt="Diagnóstico: o usuário vê o estado com docker compose ps, lê os logs, acha a causa nas tabelas deste guia e confere de novo com validate.sh" width="100%">
</picture>

<sub>📐 Nível 1 · Diagrama · fonte: [diagnostico-diagrama.mmd](diagramas/diagnostico-diagrama.mmd)</sub>

**🧭 Sequência:** 👤 Usuário ➜ ⌨️ `docker compose ps` ➜ 📚 `docker compose logs` ➜ 🚨 tabelas deste guia ➜ 🧪 `validate.sh --runtime` ➜ 🏁 serviço saudável

---

<details>
<summary>🧭 Sumário — clique para expandir</summary>

[🧭 Diagnóstico em 30 segundos](#diagnostico-em-30-segundos) · [❌ O container não sobe](#o-container-nao-sobe) · [🔌 Conecta mas falha no login ou na listagem](#conecta-mas-falha-no-login-ou-na-listagem) · [📁 Arquivo e permissão](#problemas-de-arquivo-permissao) · [🔐 Certificado e TLS](#certificado-tls) · [🧪 Ferramentas de validação](#ferramentas-de-validacao)

</details>

---

<a name="diagnostico-em-30-segundos"></a>

## 🧭 Diagnóstico em 30 segundos

```bash
docker compose ps                                               # o container está 'running'?
docker inspect --format '{{.State.Health.Status}}' allsafe-ftp  # 'healthy'?
docker compose logs --tail 50 ftp                               # o que o entrypoint e o pure-ftpd disseram?
```

**Resultado esperado:** `running`, `healthy` e, no log, a linha `FTP pronto em 2121/tcp; ...`. Qualquer coisa diferente aponta para uma das tabelas abaixo.

O `entrypoint.sh` aborta com `FALHA: <motivo>` e o container reinicia em laço: o motivo está sempre na primeira tentativa do log.

---

<a name="o-container-nao-sobe"></a>

## ❌ O container não sobe

| Mensagem no log | Causa | Como verificar | Correção |
|---|---|---|---|
| `FALHA: FTP_PASSWORD_FILE nao pode ser lido` | `FTP_PASSWORD_FILE` aponta para um arquivo ausente ou sem permissão de leitura | `ls -l .secrets/` | Crie `.secrets/ftp_password.txt` e aplique `chmod 600`. Confirme que o bind `./.secrets` existe. Veja [🔑 Segredos](segredos.md) |
| `FALHA: a senha FTP deve ter pelo menos 12 caracteres` | Senha curta, ou arquivo vazio ou só com linha em branco | `wc -c .secrets/ftp_password.txt` | Regrave: `printf '%s' 'senha-com-12+' > .secrets/ftp_password.txt` |
| `FALHA: FTP_USER invalido` | Nome fora de `^[a-z_][a-z0-9_-]{0,31}$` | `grep '^FTP_USER=' .env` | Use minúsculas, sem espaço nem acento; comece com letra ou `_` |
| `FALHA: faixa passiva invalida` ou `fora dos limites` | `FTP_PASSIVE_PORT_START` ou `FTP_PASSIVE_PORT_END` não numéricos, abaixo de `1024`, acima de `65535` ou invertidos | `grep PASSIVE .env profiles/*.env` | Corrija no `.env`; mantenha o início menor ou igual ao fim |
| `FALHA: FTP_TLS_MODE deve ser 1, 2 ou 3` | Valor inválido | `grep '^FTP_TLS_MODE=' .env` | Use `1`, `2` ou `3` (padrão `2`) |
| `bind: address already in use` | `FTP_PORT` ou a faixa passiva já estão ocupadas no host | `ss -ltnp` | Troque a porta ou a faixa, ou libere quem está usando |
| `bind: cannot assign requested address` | `FTP_BIND_IP` não existe no host | `ip -br addr` | Ajuste para um IP configurado na máquina |

---

<a name="conecta-mas-falha-no-login-ou-na-listagem"></a>

## 🔌 Conecta mas falha no login ou na listagem

| Sintoma | Causa provável | Como verificar | Correção |
|---|---|---|---|
| Cliente conecta e cai ao ser exigido o `AUTH TLS` | Cliente usando FTP **puro** ou FTPS **implícito** (porta 990) | Configuração do cliente; log do container | Configure o cliente para **FTP explícito sobre TLS** na porta de controle |
| `530 Login authentication failed` | Senha errada, usuário não existe no PureDB ou UID abaixo de 10000 | `./manage-user.sh list` | Recrie a senha com `./manage-user.sh passwd <usuario>` |
| Login OK, `LIST` ou `STOR` trava e dá timeout | Modo **ativo**, ou faixa passiva ou `FTP_PUBLIC_IP` bloqueados ou errados | `docker compose ps` mostra a faixa publicada; teste a porta `30000/tcp` a partir do cliente | Use modo **passivo**; libere `30000-30049/tcp` no firewall; `FTP_PUBLIC_IP` com o IP que o cliente alcança |
| `425 Could not open data connection` atrás de NAT | `FTP_PUBLIC_IP` aponta para IP interno | `grep '^FTP_PUBLIC_IP=' .env` | Defina `FTP_PUBLIC_IP` com o IP público e garanta NAT 1:1 da faixa passiva |
| Erro de certificado no cliente | O certificado ainda é o autoassinado | `openssl s_client -connect SEU_IP:21 -starttls ftp` mostra o emissor | Instale um certificado real ([🧰 Operação](operacao.md#certificado-real-de-producao)) ou, só em teste, desative a verificação no cliente |
| `421 Too many connections` | `FTP_MAX_CLIENTS` ou `FTP_MAX_CLIENTS_PER_IP` atingido | `docker compose logs --tail 50 ftp` | Suba de perfil com `./deploy.sh --size medium` e libere a faixa passiva nova: [🎚️ Perfis](perfis.md) |

---

<a name="problemas-de-arquivo-permissao"></a>

## 📁 Arquivo e permissão

| Sintoma | Causa | Como verificar | Correção |
|---|---|---|---|
| `553 Could not create file` | Diretório do usuário sem dono `ftpdata` (uid 10000) | `docker compose exec ftp ls -ld /data/<usuario>` | `docker compose exec ftp chown -R 10000:10000 /data/<usuario>` |
| Arquivos entram com permissão inesperada | O `umask` do `pure-ftpd` é `133:022` (arquivos sem execução e sem escrita para grupo e outros) | `docker compose exec ftp ls -l /data/<usuario>` | Comportamento esperado; ajuste `-U` no [`entrypoint.sh`](../scripts/entrypoint.sh) se precisar |
| Cliente não consegue `chmod` | `-R` desabilita o `SITE CHMOD` | Mensagem de recusa no cliente | Intencional, por segurança. Remova `-R` do entrypoint só se for realmente necessário |
| `ls` não mostra todos os arquivos | Limite `-L 10000:8` (10000 arquivos, profundidade 8) | Conte os arquivos da pasta | Reduza o número de arquivos por diretório ou ajuste `-L` |

---

<a name="certificado-tls"></a>

## 🔐 Certificado e TLS

| Sintoma | Causa | Como verificar | Correção |
|---|---|---|---|
| Novo certificado não é usado depois de copiar | Serviço não reiniciado, ou PEM sem a chave | `docker compose exec ftp ls -l /etc/ssl/private/` | `docker compose restart ftp`; o PEM deve ter **chave e certificado** juntos, `0600` |
| O entrypoint gera autoassinado a cada subida | O arquivo `/etc/ssl/private/pure-ftpd.pem` não está persistindo | `docker volume ls` lista `allsafe-ftp-certs`? | Confirme o volume no [`compose.yaml`](../compose.yaml) |
| Handshake TLS falha com "certificate expired" | Relógio do host errado, ou certificado vencido (o autoassinado dura 825 dias) | `date` no host; `openssl s_client -connect SEU_IP:21 -starttls ftp` mostra a validade | Sincronize a hora (stack `allsafe-ntp-nts-stack`); gere ou renove o certificado |

---

<a name="ferramentas-de-validacao"></a>

## 🧪 Ferramentas de validação

```bash
./scripts/validate.sh                     # bash -n dos scripts e compose config
./scripts/validate.sh --runtime           # também exige container running e healthcheck healthy
docker compose exec ftp pidof pure-ftpd   # o que o healthcheck testa
```

**Resultado esperado:** `Validacao FTP concluida.` e o número do processo do `pure-ftpd`.

Ainda travado? Colete e analise:

```bash
docker compose logs --no-color ftp > /tmp/allsafe-ftp.log
docker inspect allsafe-ftp > /tmp/allsafe-ftp.inspect.json
```

**Resultado esperado:** dois arquivos em `/tmp` com o log completo e a configuração efetiva do container.

> ⚠️ O `inspect` traz as variáveis de ambiente do container. Se você usa `FTP_PASSWORD` no `.env` em vez do arquivo de senha, a senha aparece nesse arquivo: apague-a antes de compartilhar.

---

⬅️ [🧰 Operação](operacao.md) · 🏠 [Documentação](README.md) · ➡️ [🗺️ Plano](planos/README.md)
