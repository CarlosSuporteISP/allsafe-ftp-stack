# 🏷️ Marca ALL-SAFE — allsafe-ftp-stack

[![English](https://img.shields.io/badge/English-6e7781?style=for-the-badge)](TRADEMARK.md)
[![Português (Brasil)](https://img.shields.io/badge/Portugu%C3%AAs_(Brasil)-6e7781?style=for-the-badge)](MARCA.md)
[![Español](https://img.shields.io/badge/Espa%C3%B1ol-0969da?style=for-the-badge)](MARCA.es.md)

↩ [README del proyecto](README.es.md) · [Licencia](LICENSE) · [Aviso de autoría](NOTICE)

## 💡 En pocas palabras

Esta stack es libre: cualquier persona o empresa puede usarla, copiarla, modificarla y distribuirla, gratis o cobrando, bajo la [Licencia Apache 2.0](LICENSE). ALL-SAFE hace **un solo pedido**: cuando la stack se entregue por contrato o se venda a terceros, quite el logo y el ícono de ALL-SAFE. En el uso propio, todo puede quedar como vino.

---

<details>
<summary>Índice — haga clic para expandir</summary>

[Qué se puede](#o-que-pode) · [Uso propio](#uso-proprio) · [Contrato o venta a terceros](#venda) · [Autoría](#autoria) · [Qué cubre la licencia](#o-que-a-licenca-cobre)

</details>

---

<a name="o-que-pode"></a>

## ⚖️ Qué se puede

| Situación | Usar, copiar, modificar y distribuir | Logo e ícono de ALL-SAFE |
|---|---|---|
| Uso propio: instalar y operar la stack en la propia empresa, en el propio proveedor, en laboratorio o en estudio | Libre | Pueden quedar |
| Distribuir gratis, con o sin modificación | Libre | Pueden quedar |
| Contrato o venta a terceros: vender, revender, entregar como servicio, incorporar en otro producto o instalar para un cliente | Libre | Salen: se quitan o se cambian por los de quien entrega |

---

<a name="uso-proprio"></a>

## 🏠 Uso propio

Quien instala la stack para guardar sus propias copias de seguridad no necesita cambiar nada: el logo, el ícono y el pie de página del panel quedan como vinieron. Vale también para quien modifica el código para uso interno y para quien pasa la stack a otros gratis.

**Resultado esperado:** el panel sigue con el logo de ALL-SAFE en la pantalla de entrada, el símbolo en la parte superior y `Desarrollado por allsafe.inf.br` en el pie de página.

---

<a name="venda"></a>

## 🛒 Contrato o venta a terceros

Vender está permitido por la licencia, y no depende de un contrato con ALL-SAFE. El pedido es este: quien entrega la stack por contrato o la vende a terceros quita el logo y el ícono de ALL-SAFE del panel, para que el cliente no tome la entrega por un producto de ALL-SAFE.

1. Cambie el logo y el ícono del panel por los propios: [Marca del panel](doc/es/panel.md#marca) muestra cómo, en un comando.
2. Revise la pantalla de entrada, la parte superior y la pestaña del navegador.

**Resultado esperado:** el cliente final ve la marca de quien entregó en la pantalla de entrada, en la parte superior y en la pestaña del navegador.

---

<a name="autoria"></a>

## ✍️ Autoría

El archivo [`NOTICE`](NOTICE), con la línea `Desenvolvido pela allsafe.inf.br` y la dirección [github.com/allsafe-inf](https://github.com/allsafe-inf), acompaña toda copia junto con el [`LICENSE`](LICENSE): es lo que la propia Licencia Apache pide a quien distribuye.

El panel trae la misma línea en el pie de página de las pantallas. Viene así de fábrica y no está entre los archivos de la marca: quien modifica el código decide si la mantiene.

---

<a name="o-que-a-licenca-cobre"></a>

## 📄 Qué cubre la licencia

| Parte del proyecto | Regla |
|---|---|
| Código, configuración, scripts, pruebas y documentación | [Licencia Apache 2.0](LICENSE): uso, copia, modificación y redistribución libres, con el `LICENSE` y el `NOTICE` incluidos |
| Nombre ALL-SAFE, logo e ícono: los archivos de [`web/marca/`](web/marca/) y de `web/marca/fonte/` | Marca de ALL-SAFE, fuera de la licencia del código: vale el pedido de este documento |

<details>
<summary>Detalle técnico — haga clic para expandir</summary>

- **Marca fuera de la licencia:** la Apache 2.0 no concede el uso de nombres comerciales, marcas y logotipos de quien licencia, salvo para indicar el origen del trabajo (sección 6). Este documento es el pedido de ALL-SAFE sobre la marca; no cambia lo que la licencia concede sobre el código.
- **Autoría en el `NOTICE`:** la licencia manda que quien redistribuye lleve consigo el contenido del `NOTICE` (sección 4, ítem d) y mantenga los avisos de autoría del código (sección 4, ítem c).
- **Versión modificada:** quien redistribuye el código modificado avisa, en los archivos que cambió, que fueron modificados (sección 4, ítem b).
- **Imágenes Docker:** los destinos de compilación `ftp`, `painel` y `nginx` llevan el `LICENSE` y el `NOTICE` en `/usr/share/doc/allsafe-ftp-stack/`. Solo la imagen del nginx lleva archivos de la marca, los seis de `web/marca/`; los artes de origen quedan fuera de todas.
- **Software de terceros:** los paquetes de Debian que traen las imágenes mantienen la licencia de cada uno, en `/usr/share/doc/<pacote>/copyright`.

</details>

---

⬅️ [README del proyecto](README.es.md) · 🏠 [Documentación](doc/es/README.md) · ➡️ [Marca del panel](doc/es/panel.md#marca)
