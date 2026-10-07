# 🏷️ Marca ALL-SAFE — allsafe-ftp-stack

↩ [README do projeto](README.md) · [Licença](LICENSE) · [Aviso de autoria](NOTICE)

## 💡 Em poucas palavras

Esta stack é livre: qualquer pessoa ou empresa pode usar, copiar, alterar e distribuir, de graça ou cobrando, pela [Licença Apache 2.0](LICENSE). A ALL-SAFE faz **um pedido só**: quando a stack for entregue em contrato ou vendida para terceiros, tire a logo e o ícone da ALL-SAFE. No uso próprio, tudo pode ficar como veio.

---

<details>
<summary>Sumário — clique para expandir</summary>

[O que pode](#o-que-pode) · [Uso próprio](#uso-proprio) · [Contrato ou venda para terceiros](#venda) · [Autoria](#autoria) · [O que a licença cobre](#o-que-a-licenca-cobre)

</details>

---

<a name="o-que-pode"></a>

## ⚖️ O que pode

| Situação | Usar, copiar, alterar e distribuir | Logo e ícone da ALL-SAFE |
|---|---|---|
| Uso próprio: instalar e operar a stack na própria empresa, no próprio provedor, em laboratório ou em estudo | Livre | Podem ficar |
| Distribuir de graça, com ou sem alteração | Livre | Podem ficar |
| Contrato ou venda para terceiros: vender, revender, entregar como serviço, embutir em outro produto ou instalar para um cliente | Livre | Saem: são tirados ou trocados pelos de quem entrega |

---

<a name="uso-proprio"></a>

## 🏠 Uso próprio

Quem instala a stack para guardar os próprios backups não precisa mudar nada: a logo, o ícone e o rodapé do painel ficam como vieram. Vale também para quem altera o código para uso interno e para quem passa a stack adiante de graça.

**Resultado esperado:** o painel continua com a logo da ALL-SAFE na tela de entrada, o símbolo no topo e `Desenvolvido pela allsafe.inf.br` no rodapé.

---

<a name="venda"></a>

## 🛒 Contrato ou venda para terceiros

Vender é permitido pela licença, e não depende de contrato com a ALL-SAFE. O pedido é este: quem entrega a stack em contrato ou a vende para terceiros tira a logo e o ícone da ALL-SAFE do painel, para o cliente não tomar a entrega por um produto da ALL-SAFE.

1. Troque a logo e o ícone do painel pelos próprios: [Marca do painel](doc/painel.md#marca) mostra como, em um comando.
2. Confira a tela de entrada, o topo e a aba do navegador.

**Resultado esperado:** o cliente final vê a marca de quem entregou na tela de entrada, no topo e na aba do navegador.

---

<a name="autoria"></a>

## ✍️ Autoria

O arquivo [`NOTICE`](NOTICE), com a linha `Desenvolvido pela allsafe.inf.br` e o endereço [github.com/allsafe-inf](https://github.com/allsafe-inf), acompanha toda cópia junto com o [`LICENSE`](LICENSE): é o que a própria Licença Apache pede de quem distribui.

O painel traz a mesma linha no rodapé das telas. Ela vem assim de fábrica e não está entre os arquivos da marca: quem altera o código decide se a mantém.

---

<a name="o-que-a-licenca-cobre"></a>

## 📄 O que a licença cobre

| Parte do projeto | Regra |
|---|---|
| Código, configuração, roteiros, testes e documentação | [Licença Apache 2.0](LICENSE): uso, cópia, alteração e redistribuição livres, com o `LICENSE` e o `NOTICE` junto |
| Nome ALL-SAFE, logo e ícone: os arquivos de [`web/marca/`](web/marca/) e de `web/marca/fonte/` | Marca da ALL-SAFE, fora da licença do código: vale o pedido deste documento |

<details>
<summary>Detalhe técnico — clique para expandir</summary>

- **Marca fora da licença:** a Apache 2.0 não concede o uso de nomes comerciais, marcas e logotipos de quem licencia, a não ser para dizer a origem do trabalho (seção 6). Este documento é o pedido da ALL-SAFE sobre a marca; ele não muda o que a licença concede sobre o código.
- **Autoria no `NOTICE`:** a licença manda quem redistribui levar junto o conteúdo do `NOTICE` (seção 4, item d) e manter os avisos de autoria do código (seção 4, item c).
- **Versão alterada:** quem redistribui o código alterado avisa, nos arquivos que mudou, que eles foram alterados (seção 4, item b).
- **Imagens Docker:** os alvos `ftp`, `painel` e `nginx` levam o `LICENSE` e o `NOTICE` em `/usr/share/doc/allsafe-ftp-stack/`. Só a imagem do nginx leva arquivos da marca, os seis de `web/marca/`; as artes de origem ficam fora de todas.
- **Software de terceiros:** os pacotes do Debian que as imagens trazem mantêm a licença de cada um, em `/usr/share/doc/<pacote>/copyright`.

</details>

---

⬅️ [README do projeto](README.md) · 🏠 [Documentação](doc/README.md) · ➡️ [Marca do painel](doc/painel.md#marca)
