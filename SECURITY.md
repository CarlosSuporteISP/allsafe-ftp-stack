# 🔐 Security policy — allsafe-ftp-stack

🌐 **English** · [Português (Brasil)](SECURITY.pt-BR.md)

↩ [Project README](README.md) · [Security](doc/pt-BR/seguranca.md) · [Configuration](doc/en/configuration.md#contato-de-seguranca)

## 💡 In a few words

Found a security flaw? Report it in private, before disclosing it. This file carries no fixed address: each installation publishes its own contact, which whoever operates it sets in the `SEGURANCA_CONTATO_EMAIL` variable of the `.env`. The panel delivers the contact at `/.well-known/security.txt`, without asking for a password.

---

<details>
<summary>Contents — click to expand</summary>

[Whom to tell](#para-quem-avisar) · [What to send](#o-que-mandar) · [Who operates the installation](#quem-opera) · [Versions that receive fixes](#versoes)

</details>

---

<a name="para-quem-avisar"></a>

## 📮 Whom to tell

| Where the flaw is | Whom to tell |
|---|---|
| In an installation: the FTP, the panel or the server of a company | The contact that the installation itself publishes at `/.well-known/security.txt` |
| In the code of the stack: something that holds for any installation | Whoever delivered the stack; in the official repository, [github.com/allsafe-inf/allsafe-ftp-stack](https://github.com/allsafe-inf/allsafe-ftp-stack), an issue asking for a private channel, without the details of the flaw |

1. Read the contact of the installation, from a machine in the networks allowed to the panel:

   ```bash
   curl -k https://<panel address>:8443/.well-known/security.txt
   ```

2. Write to the address in the `Contact` line.

**Expected result:** three lines, with the contact, the expiry and the language.

```text
Contact: mailto:<contact of the installation>
Expires: <date, always in the future>
Preferred-Languages: pt-BR
```

The `404` response with `contato de segurança não configurado` says that the installation has not published a contact: tell its administrator through the channel you already use with them.

---

<a name="o-que-mandar"></a>

## 📝 What to send

| Send | Do not send |
|---|---|
| The version of the stack, from the `VERSION` file | Password, token or key, not even to show that it worked |
| What was done, step by step, and what happened | Content of `.secrets/` or of the `.env` |
| What the flaw allows: reading, changing, taking down | A backup file of a device or of a customer |
| Profile, TLS mode and whether the installation accepts a public address | A proof made on someone else's installation without their authorization |

Test only on your own installation or on a lab one. The test suite of the project starts a separate instance for that: [Test suite](doc/en/scripts.md#testar).

---

<a name="quem-opera"></a>

## 🧭 Who operates the installation

The contact belongs to whoever operates, not to whoever developed the stack. The variable comes empty, and `security.txt` only exists after it is filled in.

1. In the `.env`, fill in the variable with a mailbox read by more than one person:

   ```bash
   SEGURANCA_CONTATO_EMAIL=<e-mail of the security team>
   ```

2. Apply again:

   ```bash
   ./deploy.sh
   ```

**Expected result:** the summary of `deploy.sh` with the line `Contato de segurança: <e-mail>, publicado em /.well-known/security.txt do painel.` and the Security tab of the panel with the `Security contact` item checked.

The full step by step, with the check, is in [Configuration](doc/en/configuration.md#contato-de-seguranca).

---

<a name="versoes"></a>

## 🏷️ Versions that receive fixes

| Version | Receives fixes |
|---|---|
| The last one published, the one in the [`VERSION`](VERSION) file | Yes |
| The previous ones | No: the fix comes out in a new version |

Every fix goes into [`CHANGELOG.md`](CHANGELOG.md) and is applied with `./deploy.sh`, without touching the `.env`, the secrets, the user database or the data.

<details>
<summary>Technical detail — click to expand</summary>

- **File format:** `security.txt` follows RFC 9116 and stays at the path of RFC 8615. The panel builds it at every request, with the expiry 90 days ahead, and does not write it to disk.
- **Who reaches it:** only the networks in `PAINEL_REDES_PERMITIDAS`; outside them, nginx answers `403` before any content.
- **Checked value:** `deploy.sh`, the panel container and the panel itself refuse what is not a single e-mail address. The message is `SEGURANCA_CONTATO_EMAIL inválido`.
- **Installation with a public address:** with `REDE_PERMITIR_IP_PUBLICO=sim`, the Security tab of the panel shows the contact as an alert while the variable is empty.
- **What the stack already checks:** the controls and the standards followed are in [Security](doc/pt-BR/seguranca.md), and the security test cases, in [Test suite](doc/en/scripts.md#testar).

</details>

---

⬅️ [Project README](README.md) · 🏠 [Documentation](doc/en/README.md) · ➡️ [Security](doc/pt-BR/seguranca.md)
