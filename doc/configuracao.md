# ⚙️ Configuração — allsafe-ftp-stack

↩ [README do projeto](../README.md) · [📚 Índice da documentação](README.md)

## 💡 Em poucas palavras

Tudo o que muda de uma instalação para outra fica em um arquivo só, o `.env`: o IP, a porta, o nome do usuário e os limites. O porte do servidor vem de um segundo arquivo, o perfil, que só troca os números de capacidade. O Docker Compose junta os dois e aplica ao servidor FTP.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="diagramas/configuracao-diagrama-escuro.svg">
  <img src="diagramas/configuracao-diagrama.svg" alt="Configuração: o .env traz os valores do ambiente, o perfil sobrescreve os limites, o Docker Compose junta os dois e aplica ao Pure-FTPd" width="100%">
</picture>

<sub>📐 Nível 1 · Diagrama · fonte: [configuracao-diagrama.mmd](diagramas/configuracao-diagrama.mmd)</sub>

**🧭 Sequência:** 📄 `.env` ➜ 🎚️ `profiles/small.env` ➜ 🐳 Docker Compose ➜ ⚙️ Pure-FTPd (`allsafe-ftp`) ➜ 🏁 limites aplicados

---

<details>
<summary>🧭 Sumário — clique para expandir</summary>

[🧾 Exemplo mínimo de produção](#exemplo-minimo-de-producao) · [🌍 Geral](#geral) · [🔌 Rede e portas](#rede-e-portas) · [👤 Usuário inicial e senha](#usuario-inicial-e-senha) · [🔐 TLS](#tls) · [👥 Limites de sessão](#limites-de-sessao) · [🧱 Limites de recurso do container](#limites-de-recurso-do-container) · [🌐 Rede Docker](#rede-docker-sub-rede)

</details>

---

<a name="exemplo-minimo-de-producao"></a>

## 🧾 Exemplo mínimo de produção

Todas as variáveis vivem no `.env`, copiado de [`.env.example`](../.env.example).

```ini
TZ=America/Sao_Paulo
FTP_BIND_IP=203.0.113.10
FTP_PUBLIC_IP=203.0.113.10
FTP_PORT=21
FTP_PASSIVE_PORT_START=30000
FTP_PASSIVE_PORT_END=30049
FTP_USER=backup-rede
FTP_PASSWORD=
FTP_PASSWORD_FILE=/run/.secrets/ftp_password.txt
FTP_TLS_MODE=2
FTP_CERT_CN=ftp.exemplo.com.br
FTP_MAX_CLIENTS=50
FTP_MAX_CLIENTS_PER_IP=8
```

Depois de editar o `.env`, valide sem subir:

```bash
docker compose --env-file .env config --quiet && echo OK
```

**Resultado esperado:** `OK`. Qualquer erro de sintaxe ou de valor aparece antes, com o nome da variável.

A coluna **Padrão** das tabelas abaixo é o valor do [`.env.example`](../.env.example). Quando a variável falta no `.env`, o [`compose.yaml`](../compose.yaml) aplica o mesmo valor, com duas exceções: `FTP_CERT_CN` vira `localhost` e `FTP_PASSWORD_FILE` fica vazio, o que faz o container parar com `FALHA: a senha FTP deve ter pelo menos 12 caracteres`.

---

<a name="geral"></a>

## 🌍 Geral

| Variável | Para que serve | Valores | Padrão |
|---|---|---|---|
| `TZ` | Fuso horário do container (afeta logs e validade do certificado) | Nome IANA, exemplo: `America/Sao_Paulo` | `America/Sao_Paulo` |
| `FTP_IMAGE` | Nome e tag da imagem construída no host | `nome:tag` | `allsafe-ftp:local` |

---

<a name="rede-e-portas"></a>

## 🔌 Rede e portas

| Variável | Para que serve | Valores | Padrão |
|---|---|---|---|
| `FTP_BIND_IP` | IP do **host** onde a porta de controle e a faixa passiva escutam | IP do host; `0.0.0.0` para todos (evite) | `127.0.0.1` |
| `FTP_PORT` | Porta de controle publicada no host (mapeada para `2121` no container) | `1` a `65535` | `21` |
| `FTP_PUBLIC_IP` | IP anunciado ao cliente na resposta `PASV`. Precisa ser alcançável pelo cliente | IP público ou roteável | `127.0.0.1` |
| `FTP_PASSIVE_PORT_START` | Início da faixa de portas de dados (modo passivo) | `1024` a `65535`, menor ou igual ao fim | `30000` |
| `FTP_PASSIVE_PORT_END` | Fim da faixa passiva. Número de portas maior ou igual a `FTP_MAX_CLIENTS` | `1024` a `65535`, maior ou igual ao início | `30049` |

> ⚠️ A faixa passiva é publicada **1:1** (mesma porta no host e no container). Ao ampliá-la, ajuste também o firewall do host.

---

<a name="usuario-inicial-e-senha"></a>

## 👤 Usuário inicial e senha

| Variável | Para que serve | Valores | Padrão |
|---|---|---|---|
| `FTP_USER` | Nome do usuário virtual criado ou atualizado a cada subida | Regra `^[a-z_][a-z0-9_-]{0,31}$` | `transfer` |
| `FTP_PASSWORD` | Senha em texto puro (use só se **não** usar arquivo) | 12 caracteres ou mais | _vazio_ |
| `FTP_PASSWORD_FILE` | Caminho, **dentro do container**, do arquivo com a senha. Tem precedência sobre `FTP_PASSWORD` | Caminho legível; o padrão aponta para o bind `.secrets/` | `/run/.secrets/ftp_password.txt` |

Só o usuário inicial vem do `.env`. Os demais são criados com [`manage-user.sh`](../manage-user.sh): veja [🧰 Operação](operacao.md#usuarios).

---

<a name="tls"></a>

## 🔐 TLS

| Variável | Para que serve | Valores | Padrão |
|---|---|---|---|
| `FTP_TLS_MODE` | Política de TLS do `pure-ftpd` (opção `-Y`) | `1`, `2` ou `3` (tabela abaixo) | `2` |
| `FTP_CERT_CN` | `CN` e `SAN` do certificado autoassinado gerado na primeira subida. Se for um IPv4, entra como `IP:`; senão, como `DNS:` | hostname ou IPv4 | `ftp.exemplo.com.br` no exemplo; `localhost` se a variável faltar |

| Modo | Sessão sem TLS | Canal de dados sem criptografia |
|---|---|---|
| `1` | aceita (TLS opcional) | aceito |
| `2` | **recusada**: só entra quem negocia TLS | aceito, se o cliente pedir |
| `3` | **recusada** | **recusado**: os dados também têm de ser criptografados |

> ⚠️ No modo `2`, o padrão, usuário e senha sempre trafegam criptografados, mas o conteúdo do arquivo só é criptografado se o cliente pedir proteção do canal de dados (`PROT P`). Para **obrigar** a criptografia do arquivo, use `FTP_TLS_MODE=3` e confira antes se os equipamentos suportam.

Trocar o certificado autoassinado por um real: [🧰 Operação](operacao.md#certificado-real-de-producao).

---

<a name="limites-de-sessao"></a>

## 👥 Limites de sessão

| Variável | Para que serve | Valores | Padrão |
|---|---|---|---|
| `FTP_MAX_CLIENTS` | Máximo de conexões simultâneas (opção `-c`). Alinhe ao tamanho da faixa passiva | inteiro maior que zero | `50` |
| `FTP_MAX_CLIENTS_PER_IP` | Máximo de conexões por IP de origem (opção `-C`) | inteiro maior que zero | `8` |

---

<a name="limites-de-recurso-do-container"></a>

## 🧱 Limites de recurso do container

| Variável | Para que serve | Valores | Padrão |
|---|---|---|---|
| `FTP_MEMORY_LIMIT` | `mem_limit` do serviço | exemplo: `256M`, `512M` | `256M` |
| `FTP_CPU_LIMIT` | `cpus` do serviço | exemplo: `0.5`, `1.0`, `2` | `1.0` |
| `FTP_PIDS_LIMIT` | `pids_limit` (barreira contra _fork bomb_) | inteiro | `128` |
| `FTP_NOFILE` | `ulimit nofile` (soft igual a hard) | inteiro | `16384` |

> 💡 Estes campos, mais `FTP_MAX_CLIENTS*` e a faixa passiva, são o que os perfis de [`profiles/`](../profiles/) sobrescrevem. Prefira `./deploy.sh --size medium` a editar os valores à mão: veja [🎚️ Perfis](perfis.md).

---

<a name="rede-docker-sub-rede"></a>

## 🌐 Rede Docker (sub-rede)

A rede Docker desta stack tem sub-rede fixa, trocável por uma variável no `.env`. Use quando a faixa colidir com a LAN ou a VPN do cliente.

| Variável | Rede | Containers | Padrão | Exemplo |
|---|---|---|---|---|
| `FTP_SUBNET` | `ftp` (`allsafe-ftp-network`) | `allsafe-ftp` | `172.29.1.0/29` | `FTP_SUBNET=10.250.1.0/29` |

Numa instalação que já está rodando, a sub-rede nova só vale depois de recriar a rede (os volumes e os dados não são afetados):

```bash
docker compose down
./deploy.sh --size small   # use o mesmo perfil da instalação
```

**Resultado esperado:** `docker network inspect allsafe-ftp-network` mostra a sub-rede nova.

> ⚠️ Suba de novo pelo `deploy.sh`, com o perfil em uso. Um `docker compose up -d` puro lê só o `.env` e devolve os limites e a faixa passiva aos valores dele.

<details>
<summary>🔬 Detalhe técnico — o bloco de endereços das stacks AllSafe</summary>

As stacks AllSafe reservam `172.29.1.0/24` para redes `/29` e `172.29.2.0/24` para redes `/28` e `/27`. Esta stack usa a primeira `/29` do bloco. O valor entra no [`compose.yaml`](../compose.yaml) como `subnet: ${FTP_SUBNET:-172.29.1.0/29}`.

</details>

---

⬅️ [🚀 Instalação](instalacao.md) · 🏠 [Documentação](README.md) · ➡️ [🎚️ Perfis](perfis.md)
