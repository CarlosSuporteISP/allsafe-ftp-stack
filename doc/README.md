# 📚 Documentação — allsafe-ftp-stack

↩ [README do projeto](../README.md)

## 💡 Em poucas palavras

Esta pasta explica a stack **como ela é hoje**: como instalar, configurar, operar e consertar o servidor FTP que recebe o backup dos equipamentos de rede. Cada guia começa com um resumo para quem nunca viu o projeto e guarda o detalhe técnico em menus recolhidos. O que ainda vai mudar fica no plano, não aqui.

<a href="diagramas/visao-geral-diagrama.mmd"><picture>
  <source media="(prefers-color-scheme: dark)" srcset="diagramas/visao-geral-diagrama-escuro.svg">
  <img src="diagramas/visao-geral-diagrama.svg" alt="Visão geral: o equipamento de rede envia o backup ao Pure-FTPd, que confere o usuário no PureDB e grava o arquivo em /data" width="100%">
</picture></a>

<sub>📐 Nível 1 · Diagrama · 🔍 abrir com zoom e movimento: [no GitHub](diagramas/visao-geral-diagrama.mmd) · [no computador](diagramas/visualizador.html#visao-geral-diagrama)</sub>

**🧭 Sequência:** 📡 Equipamento de rede ➜ ⚙️ Pure-FTPd (`allsafe-ftp`) ➜ 🗄️ PureDB ➜ 💽 `/data` ➜ 🏁 backup guardado

> 🧱 **Uso só em rede privada:** IP privado, atrás de firewall, nunca na internet. Veja [🔐 Segurança](seguranca.md#rede-privada).

---

<details>
<summary>🧭 Sumário — clique para expandir</summary>

[📖 Guias](#guias) · [🧭 Por onde começar](#por-onde-comecar) · [💽 Onde ficam os dados](#onde-ficam-os-dados) · [📐 Diagramas](#diagramas) · [🗺️ Plano](#plano)

</details>

---

<a name="guias"></a>

## 📖 Guias

| Nº | Guia | Assunto |
|---|---|---|
| 1 | [🚀 Instalação](instalacao.md) | Pré-requisitos, passo a passo comentado, primeira validação e como desfazer |
| 2 | [⚙️ Configuração](configuracao.md) | Todas as variáveis do `.env`: nome, para que serve, valores válidos e padrão |
| 3 | [🎚️ Perfis](perfis.md) | Perfis `small`, `medium` e `large`: dimensionamento por porte e impacto na faixa passiva |
| 4 | [🏗️ Arquitetura](arquitetura.md) | Container, imagem, entrypoint, volumes, rede e as opções do `pure-ftpd` |
| 5 | [🔐 Segurança](seguranca.md) | Rede privada e firewall, modelo de ameaça, superfície exposta e o endurecimento do Compose linha a linha |
| 6 | [🔑 Segredos](segredos.md) | O que fica em `.secrets/`, quem gera cada arquivo e como trocar |
| 7 | [⌨️ Scripts](scripts.md) | O que cada script faz, parâmetros e saída esperada |
| 8 | [🧰 Operação](operacao.md) | Usuários, certificado real, backup dos volumes, logs e atualização da imagem |
| 9 | [🚨 Solução de problemas](solucao-de-problemas.md) | Sintoma, causa, como verificar e correção |

---

<a name="por-onde-comecar"></a>

## 🧭 Por onde começar

| Situação | Leia, nesta ordem |
|---|---|
| Primeira vez | [🚀 Instalação](instalacao.md) ➜ [⚙️ Configuração](configuracao.md) ➜ [🎚️ Perfis](perfis.md) |
| Antes de produção | [🧱 Rede privada e firewall](seguranca.md#rede-privada) ➜ [🔐 Segurança](seguranca.md) ➜ [🧰 Operação](operacao.md#certificado-real-de-producao) |
| Algo quebrou | [🚨 Solução de problemas](solucao-de-problemas.md) |

---

<a name="onde-ficam-os-dados"></a>

## 💽 Onde ficam os dados

| O quê | Onde fica hoje | Dentro do container |
|---|---|---|
| Arquivos enviados pelos equipamentos | volume nomeado `allsafe-ftp-data` | `/data` |
| Usuários virtuais (PureDB) | volume nomeado `allsafe-ftp-auth` | `/auth` |
| Chave e certificado TLS | volume nomeado `allsafe-ftp-certs` | `/etc/ssl/private` |
| Senha do usuário inicial | `.secrets/ftp_password.txt`, na pasta do projeto | `/run/.secrets` (somente leitura) |
| Configuração | `.env`, na pasta do projeto | variáveis de ambiente |
| Logs | driver `local` do Docker, 10 MB × 3 | `stdout` |

> ⚠️ Os volumes nomeados ficam em `/var/lib/docker/volumes`, sob controle do Docker. A mudança para pastas fixas do host faz parte do [plano](#plano).

---

<a name="diagramas"></a>

## 📐 Diagramas

Fonte em `.mmd` e imagem em SVG, clara e escura, na pasta [`diagramas/`](diagramas/). Todo diagrama **abre com zoom e movimento**: no GitHub, clicando na imagem (abre o `.mmd`); no computador, pelo [`visualizador.html`](diagramas/visualizador.html) da pasta. Para gerar de novo depois de editar uma fonte:

```bash
/home/carlos/code/padrao-diagramas/renderizar.sh doc/diagramas doc/planos/diagramas
```

| Diagrama | Nível | Onde aparece |
|---|---|---|
| [visao-geral-diagrama.mmd](diagramas/visao-geral-diagrama.mmd) | 1 | [README do projeto](../README.md) e este índice |
| [funcionamento-fluxograma.mmd](diagramas/funcionamento-fluxograma.mmd) | 2 | [README do projeto](../README.md#como-funciona) |
| [arquitetura-mapa.mmd](diagramas/arquitetura-mapa.mmd) | 2 | [README do projeto](../README.md#arquitetura) e [🏗️ Arquitetura](arquitetura.md) |
| [subida-modelo.mmd](diagramas/subida-modelo.mmd) | 3 | [🏗️ Arquitetura](arquitetura.md#subida) |
| [instalacao-diagrama.mmd](diagramas/instalacao-diagrama.mmd) | 1 | [🚀 Instalação](instalacao.md) |
| [configuracao-diagrama.mmd](diagramas/configuracao-diagrama.mmd) | 1 | [⚙️ Configuração](configuracao.md) e [🎚️ Perfis](perfis.md) |
| [seguranca-diagrama.mmd](diagramas/seguranca-diagrama.mmd) | 1 | [🔐 Segurança](seguranca.md) |
| [segredos-diagrama.mmd](diagramas/segredos-diagrama.mmd) | 1 | [🔑 Segredos](segredos.md) |
| [scripts-diagrama.mmd](diagramas/scripts-diagrama.mmd) | 1 | [⌨️ Scripts](scripts.md) |
| [usuarios-diagrama.mmd](diagramas/usuarios-diagrama.mmd) | 1 | [🧰 Operação](operacao.md) |
| [diagnostico-diagrama.mmd](diagramas/diagnostico-diagrama.mmd) | 1 | [🚨 Solução de problemas](solucao-de-problemas.md) |

---

<a name="plano"></a>

## 🗺️ Plano

A criação da stack, o que já foi entregue e as fases em execução (pastas fixas, segredos, rede privada, painel web seguro, instalação em um comando, testes e backup) estão no plano mestre: [🗺️ planos/README.md](planos/README.md).

---

⬅️ [README do projeto](../README.md) · 🏠 [Documentação](README.md) · ➡️ [🚀 Instalação](instalacao.md)
