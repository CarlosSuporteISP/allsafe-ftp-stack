# 📚 Documentação — allsafe-ftp-stack

Índice da pasta `doc/`. A porta de entrada da stack é o
[`README.md`](../README.md) da raiz.

| Guia | Assunto |
|---|---|
| [`instalacao.md`](instalacao.md) | Pré-requisitos, passo a passo comentado, primeira validação e como desfazer. |
| [`configuracao.md`](configuracao.md) | Todas as variáveis do [`.env`](../.env.example): nome, para que serve, valores válidos e default. |
| [`perfis.md`](perfis.md) | Perfis `small`/`medium`/`large` de [`profiles/`](../profiles/): dimensionamento por porte e impacto na faixa passiva. |
| [`arquitetura.md`](arquitetura.md) | Container, imagem, [`entrypoint.sh`](../scripts/entrypoint.sh), volumes, rede e as flags do `pure-ftpd`. |
| [`seguranca.md`](seguranca.md) | Modelo de ameaça, superfície exposta e o hardening do [`compose.yaml`](../compose.yaml) linha a linha. |
| [`segredos.md`](segredos.md) | O que fica em [`.secrets/`](../.secrets/), quem gera cada arquivo e como trocar. |
| [`scripts.md`](scripts.md) | O que cada script faz ([`deploy.sh`](../deploy.sh), [`manage-user.sh`](../manage-user.sh) e os de [`scripts/`](../scripts/)), parâmetros e saída esperada. |
| [`operacao.md`](operacao.md) | Usuários, certificado real, backup dos volumes, logs e atualização da imagem. |
| [`solucao-de-problemas.md`](solucao-de-problemas.md) | Sintoma → causa → correção; como ler healthcheck e logs. |

<a name="por-onde-comecar"></a>

## 🗺️ Por onde começar

1. Primeira vez: [`instalacao.md`](instalacao.md) → [`configuracao.md`](configuracao.md) → [`perfis.md`](perfis.md).
2. Antes de produção: [`seguranca.md`](seguranca.md) → [`operacao.md`](operacao.md) (seção do certificado real).
3. Algo quebrou: [`solucao-de-problemas.md`](solucao-de-problemas.md).
