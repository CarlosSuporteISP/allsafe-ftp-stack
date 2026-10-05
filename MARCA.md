# 🏷️ Marca ALL-SAFE — allsafe-ftp-stack

↩ [README do projeto](README.md) · [Licença](LICENSE) · [Aviso de autoria](NOTICE)

## 💡 Em poucas palavras

O código desta stack é livre: pode ser usado, copiado, alterado e redistribuído por qualquer pessoa ou empresa, de graça ou cobrando, pela [Licença Apache 2.0](LICENSE). A marca não vai junto: o nome ALL-SAFE, a logo e o ícone continuam sendo da ALL-SAFE. Quem usa a stack para si pode deixar tudo como está. Quem vende ou revende sem contrato com a ALL-SAFE troca a logo e o ícone e não liga o produto à empresa. Em todos os casos a linha `Desenvolvido pela allsafe.inf.br` é mantida.

---

<details>
<summary>Sumário — clique para expandir</summary>

[O que pode e o que não pode](#o-que-pode) · [Uso próprio](#uso-proprio) · [Venda e revenda](#venda) · [Autoria](#autoria) · [O que a licença cobre](#o-que-a-licenca-cobre)

</details>

---

<a name="o-que-pode"></a>

## ⚖️ O que pode e o que não pode

| Situação | Logo e ícone da ALL-SAFE | Ligar o produto à ALL-SAFE | Linha de autoria |
|---|---|---|---|
| Uso próprio: instalar e operar a stack na própria empresa, no próprio provedor, em laboratório ou em estudo | Podem ficar | Não se aplica | Mantida |
| Venda, revenda ou oferta como serviço, com contrato com a ALL-SAFE | Conforme o contrato | Conforme o contrato | Mantida |
| Venda, revenda ou oferta como serviço, sem contrato com a ALL-SAFE | Trocados pelos de quem vende | Proibido | Mantida |

---

<a name="uso-proprio"></a>

## 🏠 Uso próprio

Quem instala a stack para guardar os próprios backups não precisa mudar nada: a logo, o ícone e o rodapé do painel ficam como vieram. Vale também para quem altera o código para uso interno.

**Resultado esperado:** o painel continua com a logo da ALL-SAFE na tela de entrada, o símbolo no topo e `Desenvolvido pela allsafe.inf.br` no rodapé.

---

<a name="venda"></a>

## 🛒 Venda e revenda

Vender é permitido pela licença do código. O que a ALL-SAFE **proíbe** é ligar o nome dela a uma venda sem que exista contrato entre as duas partes. Entra aqui toda oferta paga a terceiros: vender a stack, revender, entregar como serviço, embutir em outro produto ou cobrar pela instalação como produto próprio.

Sem contrato com a ALL-SAFE, quem vende:

1. Troca a logo e o ícone do painel pelos próprios: [Marca do painel](doc/painel.md#marca) mostra como, em um comando.
2. Não usa o nome ALL-SAFE, a logo nem o ícone no produto, no site, na proposta, no contrato nem no material de venda.
3. Não apresenta a ALL-SAFE como fornecedora, parceira, revendedora, responsável pelo suporte ou pela garantia.
4. Mantém a linha de autoria: veja [Autoria](#autoria).

**Resultado esperado:** o cliente final vê a marca de quem vendeu na tela de entrada, no topo e na aba do navegador, e `Desenvolvido pela allsafe.inf.br` no rodapé.

> ⚠️ **Contrato primeiro.** Para vender com a marca ALL-SAFE, ou como parceiro, o contrato vem antes da oferta. O contato está em [allsafe.inf.br](https://allsafe.inf.br).

---

<a name="autoria"></a>

## ✍️ Autoria

A linha `Desenvolvido pela allsafe.inf.br`, com o endereço [github.com/allsafe-inf](https://github.com/allsafe-inf), é mantida em toda cópia, alterada ou não, de uso próprio ou vendida. Ela fica em dois lugares:

| Onde | Como é mantida |
|---|---|
| Arquivo [`NOTICE`](NOTICE) | Acompanha toda cópia e toda versão derivada, junto com o [`LICENSE`](LICENSE) |
| Rodapé de todas as telas do painel | Texto do código do painel; não está entre os arquivos da marca e não muda quando a logo é trocada |

A linha de autoria diz quem desenvolveu o software. Ela não diz que a ALL-SAFE vende, apoia ou responde pelo produto de quem redistribui: por isso ela fica mesmo em quem troca a logo, e não conta como ligação com a empresa.

---

<a name="o-que-a-licenca-cobre"></a>

## 📄 O que a licença cobre

| Parte do projeto | Regra |
|---|---|
| Código, configuração, roteiros, testes e documentação | [Licença Apache 2.0](LICENSE): uso, cópia, alteração e redistribuição livres, com o `LICENSE` e o `NOTICE` junto |
| Nome ALL-SAFE, logo e ícone: os arquivos de [`web/marca/`](web/marca/) e de `web/marca/fonte/` | Marca da ALL-SAFE, fora da licença do código: valem as regras deste documento |

<details>
<summary>Detalhe técnico — clique para expandir</summary>

- **Marca fora da licença:** a Apache 2.0 não concede o uso de nomes comerciais, marcas e logotipos de quem licencia, a não ser para dizer a origem do trabalho (seção 6). Este documento é a regra da ALL-SAFE para a marca; ele não muda o que a licença concede sobre o código.
- **Autoria no `NOTICE`:** a licença manda quem redistribui levar junto o conteúdo do `NOTICE` (seção 4, item d) e manter os avisos de autoria do código (seção 4, item c).
- **Versão alterada:** quem redistribui o código alterado avisa, nos arquivos que mudou, que eles foram alterados (seção 4, item b).
- **Imagens Docker:** os alvos `ftp`, `painel` e `nginx` levam o `LICENSE` e o `NOTICE` em `/usr/share/doc/allsafe-ftp-stack/`. Só a imagem do nginx leva arquivos da marca, os seis de `web/marca/`; as artes de origem ficam fora de todas.
- **Software de terceiros:** os pacotes do Debian que as imagens trazem mantêm a licença de cada um, em `/usr/share/doc/<pacote>/copyright`.

</details>

---

⬅️ [README do projeto](README.md) · 🏠 [Documentação](doc/README.md) · ➡️ [Marca do painel](doc/painel.md#marca)
