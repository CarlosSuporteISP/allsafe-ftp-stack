# 🏷️ ALL-SAFE trademark — allsafe-ftp-stack

[![English](https://img.shields.io/badge/English-0969da?style=for-the-badge)](TRADEMARK.md)
[![Português (Brasil)](https://img.shields.io/badge/Portugu%C3%AAs_(Brasil)-6e7781?style=for-the-badge)](MARCA.md)
[![Español](https://img.shields.io/badge/Espa%C3%B1ol-6e7781?style=for-the-badge)](MARCA.es.md)

↩ [Project README](README.md) · [License](LICENSE) · [Notice of authorship](NOTICE)

## 💡 In a few words

This stack is free: any person or company can use, copy, change and distribute it, for free or for a charge, under the [Apache License 2.0](LICENSE). ALL-SAFE makes **a single request**: when the stack is delivered under a contract or sold to third parties, take out the ALL-SAFE logo and icon. In own use, everything can stay as it came.

---

<details>
<summary>Contents — click to expand</summary>

[What is allowed](#o-que-pode) · [Own use](#uso-proprio) · [Contract or sale to third parties](#venda) · [Authorship](#autoria) · [What the license covers](#o-que-a-licenca-cobre)

</details>

---

<a name="o-que-pode"></a>

## ⚖️ What is allowed

| Situation | Use, copy, change and distribute | ALL-SAFE logo and icon |
|---|---|---|
| Own use: installing and operating the stack in your own company, in your own provider, in a lab or for study | Free | They can stay |
| Distributing for free, with or without changes | Free | They can stay |
| Contract or sale to third parties: selling, reselling, delivering as a service, embedding in another product or installing for a customer | Free | They come out: they are removed or replaced by those of whoever delivers |

---

<a name="uso-proprio"></a>

## 🏠 Own use

Whoever installs the stack to keep their own backups does not need to change anything: the logo, the icon and the footer of the panel stay as they came. The same holds for whoever changes the code for internal use and for whoever passes the stack on for free.

**Expected result:** the panel keeps the ALL-SAFE logo on the sign-in screen, the symbol at the top and `Developed by allsafe.inf.br` in the footer.

---

<a name="venda"></a>

## 🛒 Contract or sale to third parties

Selling is allowed by the license, and does not depend on a contract with ALL-SAFE. The request is this: whoever delivers the stack under a contract or sells it to third parties takes the ALL-SAFE logo and icon out of the panel, so that the customer does not take the delivery for an ALL-SAFE product.

1. Replace the logo and the icon of the panel with your own: [Panel brand](doc/en/panel.md#marca) shows how, in one command.
2. Check the sign-in screen, the top and the browser tab.

**Expected result:** the end customer sees the brand of whoever delivered on the sign-in screen, at the top and in the browser tab.

---

<a name="autoria"></a>

## ✍️ Authorship

The [`NOTICE`](NOTICE) file, with the line `Desenvolvido pela allsafe.inf.br` and the address [github.com/allsafe-inf](https://github.com/allsafe-inf), goes with every copy together with the [`LICENSE`](LICENSE): it is what the Apache License itself asks of whoever distributes.

The panel carries the same line in the footer of the screens. It comes like that by default and is not among the brand files: whoever changes the code decides whether to keep it.

---

<a name="o-que-a-licenca-cobre"></a>

## 📄 What the license covers

| Part of the project | Rule |
|---|---|
| Code, configuration, scripts, tests and documentation | [Apache License 2.0](LICENSE): free use, copy, change and redistribution, with the `LICENSE` and the `NOTICE` along |
| ALL-SAFE name, logo and icon: the files in [`web/marca/`](web/marca/) and in `web/marca/fonte/` | ALL-SAFE trademark, outside the license of the code: the request of this document applies |

<details>
<summary>Technical detail — click to expand</summary>

- **Trademark outside the license:** Apache 2.0 does not grant the use of the trade names, trademarks and logos of the licensor, except to state the origin of the work (section 6). This document is the request of ALL-SAFE about the trademark; it does not change what the license grants over the code.
- **Authorship in the `NOTICE`:** the license requires whoever redistributes to take along the content of the `NOTICE` (section 4, item d) and to keep the authorship notices of the code (section 4, item c).
- **Changed version:** whoever redistributes the changed code states, in the files they changed, that they were changed (section 4, item b).
- **Docker images:** the targets `ftp`, `painel` and `nginx` carry the `LICENSE` and the `NOTICE` in `/usr/share/doc/allsafe-ftp-stack/`. Only the nginx image carries brand files, the six in `web/marca/`; the source artworks stay out of all of them.
- **Third-party software:** the Debian packages that the images bring keep the license of each one, in `/usr/share/doc/<package>/copyright`.

</details>

---

⬅️ [Project README](README.md) · 🏠 [Documentation](doc/en/README.md) · ➡️ [Panel brand](doc/en/panel.md#marca)
