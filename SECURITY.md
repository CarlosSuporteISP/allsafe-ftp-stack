# 🔐 Política de segurança — allsafe-ftp-stack

↩ [README do projeto](README.md) · [Segurança](doc/seguranca.md) · [Configuração](doc/configuracao.md#contato-de-seguranca)

## 💡 Em poucas palavras

Achou uma falha de segurança? Avise em particular, antes de divulgar. Este arquivo não traz um endereço fixo: cada instalação publica o contato dela, que quem opera define na variável `SEGURANCA_CONTATO_EMAIL` do `.env`. O painel entrega o contato em `/.well-known/security.txt`, sem pedir senha.

---

<details>
<summary>Sumário — clique para expandir</summary>

[Para quem avisar](#para-quem-avisar) · [O que mandar](#o-que-mandar) · [Quem opera a instalação](#quem-opera) · [Versões que recebem correção](#versoes)

</details>

---

<a name="para-quem-avisar"></a>

## 📮 Para quem avisar

| Onde está a falha | Para quem avisar |
|---|---|
| Em uma instalação: o FTP, o painel ou o servidor de uma empresa | O contato que a própria instalação publica em `/.well-known/security.txt` |
| No código da stack: algo que vale para qualquer instalação | Quem entregou a stack; no repositório oficial, [github.com/allsafe-inf/allsafe-ftp-stack](https://github.com/allsafe-inf/allsafe-ftp-stack), uma issue pedindo um canal privado, sem os detalhes da falha |

1. Leia o contato da instalação, de uma máquina das redes permitidas ao painel:

   ```bash
   curl -k https://<endereço do painel>:8443/.well-known/security.txt
   ```

2. Escreva para o endereço da linha `Contact`.

**Resultado esperado:** três linhas, com o contato, a validade e o idioma.

```text
Contact: mailto:<contato da instalação>
Expires: <data, sempre no futuro>
Preferred-Languages: pt-BR
```

A resposta `404` com `contato de segurança não configurado` diz que a instalação não publicou contato: avise o administrador dela pelo canal que já usa com ele.

---

<a name="o-que-mandar"></a>

## 📝 O que mandar

| Mande | Não mande |
|---|---|
| A versão da stack, do arquivo `VERSION` | Senha, token ou chave, nem para mostrar que funcionou |
| O que foi feito, passo a passo, e o que aconteceu | Conteúdo de `.secrets/` ou do `.env` |
| O que a falha permite: ler, alterar, derrubar | Arquivo de backup de equipamento ou de cliente |
| Perfil, modo de TLS e se a instalação aceita endereço público | Prova feita em instalação de outra pessoa sem a autorização dela |

Teste só na própria instalação ou em uma de laboratório. A bateria do projeto sobe uma instância separada para isso: [Bateria de testes](doc/scripts.md#testar).

---

<a name="quem-opera"></a>

## 🧭 Quem opera a instalação

O contato é de quem opera, não de quem desenvolveu a stack. A variável vem vazia de fábrica, e o `security.txt` só existe depois de preenchida.

1. No `.env`, preencha a variável com uma caixa lida por mais de uma pessoa:

   ```bash
   SEGURANCA_CONTATO_EMAIL=<e-mail da equipe de segurança>
   ```

2. Reaplique:

   ```bash
   ./deploy.sh
   ```

**Resultado esperado:** o resumo do `deploy.sh` com a linha `Contato de segurança: <e-mail>, publicado em /.well-known/security.txt do painel.` e a aba Segurança do painel com o item `Contato de segurança` marcado.

O passo a passo completo, com a conferência, está em [Configuração](doc/configuracao.md#contato-de-seguranca).

---

<a name="versoes"></a>

## 🏷️ Versões que recebem correção

| Versão | Recebe correção |
|---|---|
| A última publicada, a do arquivo [`VERSION`](VERSION) | Sim |
| As anteriores | Não: a correção sai em versão nova |

Toda correção entra no [`CHANGELOG.md`](CHANGELOG.md) e é aplicada com `./deploy.sh`, sem tocar no `.env`, nos segredos, no cadastro nem nos dados.

<details>
<summary>Detalhe técnico — clique para expandir</summary>

- **Formato do arquivo:** o `security.txt` segue a RFC 9116 e fica no caminho da RFC 8615. O painel o monta a cada pedido, com a validade 90 dias à frente, e não o grava em disco.
- **Quem alcança:** só as redes de `PAINEL_REDES_PERMITIDAS`; fora delas, o nginx responde `403` antes de qualquer conteúdo.
- **Valor conferido:** o `deploy.sh`, o container do painel e o próprio painel recusam o que não é um endereço de e-mail só. A mensagem é `SEGURANCA_CONTATO_EMAIL inválido`.
- **Instalação com endereço público:** com `REDE_PERMITIR_IP_PUBLICO=sim`, a aba Segurança do painel mostra o contato em alerta enquanto a variável estiver vazia.
- **O que a stack já confere:** os controles e as normas seguidas estão em [Segurança](doc/seguranca.md), e os casos de teste de segurança, em [Bateria de testes](doc/scripts.md#testar).

</details>

---

⬅️ [README do projeto](README.md) · 🏠 [Documentação](doc/README.md) · ➡️ [Segurança](doc/seguranca.md)
