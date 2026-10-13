# 🔐 Política de seguridad — allsafe-ftp-stack

[![English](https://img.shields.io/badge/English-6e7781?style=for-the-badge)](SECURITY.md)
[![Português (Brasil)](https://img.shields.io/badge/Portugu%C3%AAs_(Brasil)-6e7781?style=for-the-badge)](SECURITY.pt-BR.md)
[![Español](https://img.shields.io/badge/Espa%C3%B1ol-0969da?style=for-the-badge)](SECURITY.es.md)

↩ [README del proyecto](README.es.md) · [Seguridad](doc/es/seguridad.md) · [Configuración](doc/es/configuracion.md#contato-de-seguranca)

## 💡 En pocas palabras

¿Encontró una falla de seguridad? Avise en privado, antes de divulgarla. Este archivo no trae una dirección fija: cada instalación publica su contacto, que quien opera define en la variable `SEGURANCA_CONTATO_EMAIL` del `.env`. El panel entrega el contacto en `/.well-known/security.txt`, sin pedir contraseña.

---

<details>
<summary>Índice — haga clic para expandir</summary>

[A quién avisar](#para-quem-avisar) · [Qué enviar](#o-que-mandar) · [Quien opera la instalación](#quem-opera) · [Versiones que reciben corrección](#versoes)

</details>

---

<a name="para-quem-avisar"></a>

## 📮 A quién avisar

| Dónde está la falla | A quién avisar |
|---|---|
| En una instalación: el FTP, el panel o el servidor de una empresa | El contacto que la propia instalación publica en `/.well-known/security.txt` |
| En el código de la stack: algo que vale para cualquier instalación | Quien entregó la stack; en el repositorio oficial, [github.com/allsafe-inf/allsafe-ftp-stack](https://github.com/allsafe-inf/allsafe-ftp-stack), una issue que pida un canal privado, sin los detalles de la falla |

1. Lea el contacto de la instalación, desde una máquina de las redes permitidas al panel:

   ```bash
   curl -k https://<dirección del panel>:8443/.well-known/security.txt
   ```

2. Escriba a la dirección de la línea `Contact`.

**Resultado esperado:** tres líneas, con el contacto, la validez y el idioma.

```text
Contact: mailto:<contacto de la instalación>
Expires: <fecha, siempre en el futuro>
Preferred-Languages: pt-BR
```

La respuesta `404` con `contacto de seguridad no configurado` indica que la instalación no publicó un contacto: avise a su administrador por el canal que ya usa con él.

---

<a name="o-que-mandar"></a>

## 📝 Qué enviar

| Envíe | No envíe |
|---|---|
| La versión de la stack, del archivo `VERSION` | Contraseña, token o clave, ni para mostrar que funcionó |
| Lo que se hizo, paso a paso, y lo que ocurrió | Contenido de `.secrets/` o del `.env` |
| Lo que la falla permite: leer, modificar, derribar | Archivo de copia de seguridad de un equipo o de un cliente |
| Perfil, modo de TLS y si la instalación acepta dirección pública | Prueba hecha en la instalación de otra persona sin su autorización |

Pruebe solo en la propia instalación o en una de laboratorio. La batería del proyecto levanta una instancia separada para eso: [Batería de pruebas](doc/es/scripts.md#testar).

---

<a name="quem-opera"></a>

## 🧭 Quien opera la instalación

El contacto es de quien opera, no de quien desarrolló la stack. La variable viene vacía de fábrica, y el `security.txt` solo existe después de completarla.

1. En el `.env`, complete la variable con un buzón leído por más de una persona:

   ```bash
   SEGURANCA_CONTATO_EMAIL=<correo del equipo de seguridad>
   ```

2. Aplique de nuevo:

   ```bash
   ./deploy.sh
   ```

**Resultado esperado:** el resumen del `deploy.sh` con la línea `Contato de segurança: <e-mail>, publicado em /.well-known/security.txt do painel.` y la pestaña Seguridad del panel con el ítem `Contacto de seguridad` marcado.

El paso a paso completo, con la verificación, está en [Configuración](doc/es/configuracion.md#contato-de-seguranca).

---

<a name="versoes"></a>

## 🏷️ Versiones que reciben corrección

| Versión | Recibe corrección |
|---|---|
| La última publicada, la del archivo [`VERSION`](VERSION) | Sí |
| Las anteriores | No: la corrección sale en una versión nueva |

Toda corrección entra en el [`CHANGELOG.md`](CHANGELOG.md) y se aplica con `./deploy.sh`, sin tocar el `.env`, los secretos, el registro de usuarios ni los datos.

<details>
<summary>Detalle técnico — haga clic para expandir</summary>

- **Formato del archivo:** el `security.txt` sigue la RFC 9116 y queda en la ruta de la RFC 8615. El panel lo arma en cada solicitud, con la validez 90 días por delante, y no lo guarda en disco.
- **Quién lo alcanza:** solo las redes de `PAINEL_REDES_PERMITIDAS`; fuera de ellas, el nginx responde `403` antes de cualquier contenido.
- **Valor verificado:** el `deploy.sh`, el contenedor del panel y el propio panel rechazan lo que no es una sola dirección de correo. El mensaje es `SEGURANCA_CONTATO_EMAIL inválido`.
- **Instalación con dirección pública:** con `REDE_PERMITIR_IP_PUBLICO=sim`, la pestaña Seguridad del panel muestra el contacto en alerta mientras la variable esté vacía.
- **Lo que la stack ya verifica:** los controles y las normas seguidas están en [Seguridad](doc/es/seguridad.md), y los casos de prueba de seguridad, en [Batería de pruebas](doc/es/scripts.md#testar).

</details>

---

⬅️ [README del proyecto](README.es.md) · 🏠 [Documentación](doc/es/README.md) · ➡️ [Seguridad](doc/es/seguridad.md)
