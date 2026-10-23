# ⚙️ Configuración — allsafe-ftp-stack

[![English](https://img.shields.io/badge/English-6e7781?style=for-the-badge)](../en/configuration.md)
[![Português (Brasil)](https://img.shields.io/badge/Portugu%C3%AAs_(Brasil)-6e7781?style=for-the-badge)](../pt-BR/configuracao.md)
[![Español](https://img.shields.io/badge/Espa%C3%B1ol-0969da?style=for-the-badge)](configuracion.md)

↩ [README del proyecto](../../README.es.md) · [Índice de la documentación](README.md)

## 💡 En pocas palabras

Todo lo que cambia de una instalación a otra queda en un solo archivo, el `.env`: la IP, el puerto, el nombre del usuario, el modo de TLS y los límites. El tamaño del servidor viene de un perfil listo: al elegir el tamaño, el `deploy.sh` guarda sus números de capacidad en el propio `.env`. Docker Compose lee el `.env` y lo aplica a los tres contenedores: el FTP, el panel y el nginx que queda delante del panel.

<!-- diagrama: diagramas/configuracion-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    perfil@{ shape: doc, label: "profiles/medium.env<br>límites del perfil" }
    deploy@{ shape: console, label: "deploy.sh --size medium<br>guarda los límites en el .env" }
    env@{ shape: doc, label: ".env<br>entorno y límites" }
    compose@{ shape: rect, label: "Docker Compose<br>lee solo el .env" }
    ftp@{ shape: rect, label: "Pure-FTPd<br>allsafe-ftp" }
    fim@{ shape: stadium, label: "límites aplicados" }

    perfil --> deploy --> env --> compose --> ftp --> fim
```

<sub>Nivel 1 · Diagrama · [fuente](diagramas/)</sub>

**Secuencia:** `profiles/medium.env` ➜ `deploy.sh --size medium` (guarda los límites en el `.env`) ➜ `.env` ➜ Docker Compose ➜ Pure-FTPd (`allsafe-ftp`) ➜ límites aplicados

---

<details>
<summary>Índice — haga clic para expandir</summary>

[Ejemplo mínimo de producción](#exemplo-minimo-de-producao) · [General](#geral) · [Red y puertos](#rede-e-portas) · [IPv6](#ipv6) · [Usuario inicial y contraseña](#usuario-inicial-e-senha) · [TLS](#tls) · [Límites de sesión](#limites-de-sessao) · [Panel web](#painel) · [Contacto de seguridad](#contato-de-seguranca) · [Límites de recurso del contenedor](#limites-de-recurso-do-container) · [Red Docker](#rede-docker-sub-rede)

</details>

---

<a name="exemplo-minimo-de-producao"></a>

## 🧾 Ejemplo mínimo de producción

Todas las variables viven en el `.env`, copiado de [`.env.example`](../../.env.example). En el ejemplo, las variables vienen agrupadas por tema y **cada una tiene, en la línea de arriba, un comentario que dice para qué sirve**; esta guía trae lo mismo, con más detalle.

```ini
TZ=America/Sao_Paulo
DATA_DIR=/srv/allsafe-ftp-stack/data
FTP_BIND_IP=192.168.10.20
FTP_PASSIVE_IP=192.168.10.20
FTP_PORT=21
FTP_PASSIVE_PORT_START=30000
FTP_PASSIVE_PORT_END=30099
FTP_USER=backup-rede
FTP_TLS_MODE=2
FTP_CERT_CN=ftp.exemplo.com.br
FTP_MAX_CLIENTS=50
FTP_MAX_CLIENTS_PER_IP=8
FTP_BLOQUEIO_TENTATIVAS=5
FTP_BLOQUEIO_MINUTOS=15
BLOQUEIO_ENDERECO_ERROS=5
BLOQUEIO_ENDERECO_HORAS=24
BLOQUEIO_ENDERECO_DIAS=120
```

Ninguna contraseña entra en el `.env`: queda en `.secrets/ftp-usuario-inicial-senha.txt` ([Secretos](secretos.md)).

Después de editar el `.env`, valide sin arrancar:

```bash
./deploy.sh --check-only
```

**Resultado esperado:** `OK: perfil 'small', rede privada, recursos do servidor e compose validados; nada foi alterado.` Una IP fuera de los rangos privados, una contraseña en el `.env`, un `FTP_TLS_MODE` fuera de `0` a `3` o un perfil más grande que el servidor detienen el comando con la explicación.

La columna **Por defecto** de las tablas de abajo es el valor del [`.env.example`](../../.env.example). Cuando la variable falta en el `.env`, el [`compose.yaml`](../../compose.yaml) aplica el mismo valor, con tres excepciones: `FTP_CERT_CN` pasa a ser `localhost`, y `DATA_DIR` y `FTP_PASSIVE_IP` no tienen valor por defecto en Compose: sin ellas el comando se detiene con `defina DATA_DIR no .env` o `defina FTP_PASSIVE_IP no .env`.

---

<a name="geral"></a>

## 🌍 General

| Variable | Para qué sirve | Valores | Por defecto |
|---|---|---|---|
| `TZ` | Huso horario del contenedor (afecta a los logs y a la validez del certificado) | Nombre IANA, ejemplo: `America/Sao_Paulo` | `America/Sao_Paulo` |
| `FTP_IMAGE` | Nombre y tag de la imagen del FTP, construida en el host | `nombre:tag` | `allsafe-ftp:local` |
| `PAINEL_IMAGE` | Nombre y tag de la imagen del panel, construida en el host | `nombre:tag` | `allsafe-ftp-painel:local` |
| `NGINX_IMAGE` | Nombre y tag de la imagen del nginx que queda delante del panel, construida en el host | `nombre:tag` | `allsafe-ftp-nginx:local` |

---

<a name="pastas-e-nomes"></a>

## 📦 Carpetas y nombres

| Variable | Para qué sirve | Valores | Por defecto |
|---|---|---|---|
| `DATA_DIR` | Carpeta del host con los datos de la stack: `dados/` (archivos enviados), `auth/` (PureDB), `certs/` (TLS del FTP), `painel/` (certificado y auditoría del panel) y `nginx/` (el socket y la copia del certificado que lee el nginx). Montada por _bind mount_; la stack no crea volumen con nombre | Ruta absoluta | `/srv/allsafe-ftp-stack/data` |
| `BACKUP_DIR` | Carpeta del host donde el `scripts/backup.sh` guarda las copias de seguridad, cifradas, y el `scripts/restaurar.sh` las busca. Nace con modo `0700` y tiene que quedar fuera de `DATA_DIR`: [Copia de seguridad y restauración](backup.md) | Ruta absoluta | `/srv/allsafe-ftp-stack/backups` |
| `TEMP_DIR` | Carpeta del host para temporales: instancia de prueba, recolección de diagnóstico | Ruta absoluta | `/srv/allsafe-ftp-stack/tmp` |
| `SECRETS_DIR` | Carpeta de los secretos, un archivo por secreto, modo `0700`: las contraseñas iniciales y el par de claves de la copia de seguridad | Ruta absoluta o relativa a la carpeta del proyecto | `./.secrets` |
| `STACK_NAME` | Nombre del proyecto en Compose | Minúsculas, números y guion | `allsafe-ftp-stack` |
| `FTP_CONTAINER_NAME` | Nombre del contenedor y del host del FTP | Nombre de contenedor | `allsafe-ftp` |
| `PAINEL_CONTAINER_NAME` | Nombre del contenedor y del host del panel | Nombre de contenedor | `allsafe-ftp-painel` |
| `NGINX_CONTAINER_NAME` | Nombre del contenedor y del host del nginx | Nombre de contenedor | `allsafe-ftp-nginx` |
| `FTP_NETWORK_NAME` | Nombre de la red Docker de la stack | Nombre de red | `allsafe-ftp-network` |

Para una **segunda instancia** en el mismo host, cambie los cinco nombres, las tres imágenes, las carpetas, los puertos (del FTP y del panel) y la `FTP_SUBNET`; con el IPv6 activado, también la `FTP_SUBNET_IPV6`. El [`deploy.sh`](../../deploy.sh) acepta otro archivo en lugar del `.env`: `ENV_FILE=/caminho/outro.env ./deploy.sh`.

---

<a name="rede-e-portas"></a>

## 🔌 Red y puertos

| Variable | Para qué sirve | Valores | Por defecto |
|---|---|---|---|
| `REDE_PERMITIR_IP_PUBLICO` | Aceptar dirección pública en el FTP y en el panel. Es opcional y es elección de quien instala. Lea la [alerta](#rede-permitir-ip-publico) antes de activarla | `nao` o `sim` | `nao` |
| `FTP_BIND_IP` | IP del **host** donde escuchan el puerto de control y el rango pasivo | IP privada del host; `0.0.0.0` siempre se rechaza; IP pública, solo con `REDE_PERMITIR_IP_PUBLICO=sim` | `127.0.0.1` |
| `FTP_PORT` | Puerto de control publicado en el host (mapeado a `2121` en el contenedor) | `1` a `65535` | `21` |
| `FTP_PASSIVE_IP` | IP que el servidor **anuncia** al cliente en el modo pasivo (respuesta `PASV`): la IP **interna** por la que los equipos llegan al servidor (nota abajo) | IP privada, alcanzable por el cliente; IP pública, solo con `REDE_PERMITIR_IP_PUBLICO=sim` | `127.0.0.1` |
| `FTP_PASSIVE_PORT_START` | Inicio del rango de puertos de datos (modo pasivo) | `1024` a `65535`, menor o igual al fin | `30000` |
| `FTP_PASSIVE_PORT_END` | Fin del rango pasivo. Número de puertos de al menos el doble de `FTP_MAX_CLIENTS` | `1024` a `65535`, mayor o igual al inicio | `30099` |

> 🧱 **Red privada:** por defecto solo se aceptan `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12` y `192.168.0.0/16`. El [`deploy.sh`](../../deploy.sh) y el contenedor se detienen con `não é IP privado` para cualquier otro valor ([`scripts/rede-privada.sh`](../../scripts/rede-privada.sh)). En IPv6 la regla es la misma, con `::1` y el rango local único (`fc00::/7`): [IPv6](#ipv6).

<a name="rede-permitir-ip-publico"></a>

> ⚠️ **Alerta — `REDE_PERMITIR_IP_PUBLICO=sim` pone el FTP y el panel en internet.** De fábrica la opción viene desactivada; activarla es elección de quien instala. Un servidor expuesto es escaneado y recibe intentos de contraseña todo el tiempo. Actívela solo con firewall en el servidor que abra los puertos únicamente a las direcciones de los equipos y de quien administra, con `FTP_TLS_MODE` en `2` o `3` (con la opción, `0` y `1` se rechazan), contraseñas generadas y `PAINEL_REDES_PERMITIDAS` reducida. Incluso con `sim`, `0.0.0.0` y una red más amplia que `/8` siguen rechazadas. Sin firewall, el riesgo es de quien activó la opción. El paso a paso está en [Seguridad](seguridad.md#ip-publico). Para publicar **solo el panel**, sin exponer el FTP, el camino es otro: [`PAINEL_PROXY_CONFIAVEL`](#painel-proxy-confiavel).

> ⚠️ El rango pasivo se publica **1:1** (el mismo puerto en el host y en el contenedor). Al ampliarlo, ajuste también el firewall del host.

<a name="ftp-passive-ip"></a>
<a name="ftp-public-ip"></a>

> **¿Para qué sirve `FTP_PASSIVE_IP`?** En el modo pasivo, el servidor le dice al cliente en qué IP y en qué puerto abrir la conexión de datos. El Pure-FTPd, dentro del contenedor, solo conoce la dirección de la red Docker, que el equipo no alcanza; por eso la stack le informa qué dirección anunciar (opción `-P`). El valor es la IP **privada** del host por la que llegan los equipos, en general la misma de `FTP_BIND_IP`. Solo es diferente cuando existe NAT interno entre el equipo y el servidor. Una IP de internet se rechaza.

> **Instalación anterior a la `0.17.0`:** la variable se llamaba `FTP_PUBLIC_IP`. El `./deploy.sh` cambia el nombre solo, mantiene el valor y guarda el `.env` de antes en `BACKUP_DIR/<data>-antes-da-migracao-de-nomes/env`. Hasta que se ejecute, los comandos que llaman a Compose se detienen con `defina FTP_PASSIVE_IP no .env`. Los archivos de `.secrets/` también cambiaron de nombre, en la `0.18.0`, y se convierten en la misma ejecución: [Secretos](secretos.md#nomes-antigos).

<a name="ipv6"></a>

### IPv6

De fábrica la stack queda solo en IPv4. Con `REDE_IPV6=sim`, el FTP y el panel se publican **también** en IPv6, en los mismos puertos; el IPv4 sigue como está.

| Variable | Para qué sirve | Valores | Por defecto |
|---|---|---|---|
| `REDE_IPV6` | Publicar el FTP y el panel también en IPv6 | `nao` o `sim` | `nao` |
| `FTP_BIND_IPV6` | Dirección IPv6 del **host** donde escuchan el puerto de control y el rango pasivo | IPv6 sin corchetes: `::1` o del rango local único (`fc00::/7`); `::` siempre se rechaza; IPv6 pública, solo con `REDE_PERMITIR_IP_PUBLICO=sim` | `::1` |
| `PAINEL_BIND_IPV6` | Dirección IPv6 del **host** donde el nginx publica el panel | Los mismos de `FTP_BIND_IPV6` | `::1` |
| `FTP_SUBNET_IPV6` | Subred IPv6 de la red Docker de la stack | Rango local único con prefijo `/64` | `fd29:1::/64` |

Con `nao`, las tres últimas no se leen. Después de activarlo o desactivarlo, ejecute el `./deploy.sh`: verifica las direcciones, rehace la red de los contenedores con o sin la subred IPv6 y graba en el `.env` la línea `COMPOSE_FILE`, que pone o quita el archivo [`compose.ipv6.yaml`](../../compose.ipv6.yaml). Así el `docker compose` directo y los demás scripts leen la misma configuración. La línea `COMPOSE_FILE` es del `deploy.sh`: no la edite.

Con `REDE_IPV6=sim`, el `deploy.sh` se detiene antes de cualquier modificación cuando:

- una dirección no se acepta (`não é IPv6 privado`) o la subred no es un rango local único `/64`;
- `PAINEL_REDES_PERMITIDAS` no tiene ninguna red IPv6;
- el IPv6 está desactivado en el kernel del servidor;
- el Docker es anterior a la versión 27.

> **Panel por IPv6:** añada a `PAINEL_REDES_PERMITIDAS` la red IPv6 de quien administra. Quien abre el panel en el propio servidor, en `https://[::1]:8443`, llega al nginx con la dirección de la red Docker en IPv6: para ese acceso, la red que hay que añadir es la de `FTP_SUBNET_IPV6`.

> **Modo pasivo en IPv6:** no existe dirección anunciada que configurar. En IPv6 el cliente usa el modo pasivo extendido (`EPSV`): el servidor informa solo el puerto y el cliente vuelve a la dirección a la que ya está conectado. El rango de puertos es el mismo del IPv4.

---

<a name="usuario-inicial-e-senha"></a>

## 👤 Usuario inicial y contraseña

| Variable | Para qué sirve | Valores | Por defecto |
|---|---|---|---|
| `FTP_USER` | Nombre del usuario inicial, creado una vez, en el primer arranque. Eliminado desde el panel, no se recrea | Regla `^[a-z_][a-z0-9_-]{0,31}$` | `transfer` |

La **contraseña** del usuario inicial no es variable: queda en `SECRETS_DIR/ftp-usuario-inicial-senha.txt`, creada por el `deploy.sh`, y llega al contenedor como el secreto `/run/secrets/ftp_usuario_inicial_senha`. Un `.env` con `FTP_PASSWORD` rellenado se rechaza. Vea [Secretos](secretos.md).

Solo el usuario inicial viene del `.env`. Los demás se crean desde el [panel](panel.md#usuarios) o con [`manage-user.sh`](../../manage-user.sh): vea [Operación](operacion.md#usuarios). La contraseña y la carpeta del usuario inicial también se cambian con ellos, y se elimina como los otros. Cambiar el `FTP_USER` después de la instalación crea el usuario del nombre nuevo en el arranque siguiente, también una vez; el del nombre antiguo sigue en el registro hasta que se elimine.

---

<a name="tls"></a>

## 🔐 TLS

| Variable | Para qué sirve | Valores | Por defecto |
|---|---|---|---|
| `FTP_TLS_MODE` | Política de TLS del `pure-ftpd` (opción `-Y`) | `0`, `1`, `2` o `3` (tabla abajo) | `2` |
| `FTP_TLS_EXCECOES` | TLS por usuario: con `sim`, el administrador puede dispensar del TLS, en la pestaña Usuarios del panel, al usuario de un equipo que no habla TLS; los demás siguen obligados a usarlo. Sin ningún dispensado, nada cambia: la sesión sin TLS se rechaza antes de la contraseña. Solo vale con `FTP_TLS_MODE=2` y sin `REDE_PERMITIR_IP_PUBLICO=sim`; fuera de eso queda sin efecto | `sim` o `nao` | `sim` |
| `FTP_CERT_CN` | `CN` y `SAN` del certificado autofirmado generado en el primer arranque. Si es una IPv4 o una IPv6 (sin corchetes), entra como `IP:`; si no, como `DNS:` | hostname, IPv4 o IPv6 | `ftp.exemplo.com.br` en el ejemplo; `localhost` si la variable falta |

| Modo | Sesión sin TLS | Canal de datos sin cifrado | Cuándo usar |
|---|---|---|---|
| `0` | **es la única que existe**: el servidor no ofrece TLS | siempre sin cifrado | solo equipo antiguo sin soporte de TLS |
| `1` | aceptada (TLS opcional) | aceptado | equipos antiguos y nuevos en el mismo servidor |
| `2` | **rechazada**: solo entra quien negocia TLS | aceptado, si el cliente lo pide | **por defecto** |
| `3` | **rechazada** | **rechazado**: los datos también tienen que ir cifrados | todos los equipos soportan `PROT P` |

> ⚠️ **Modos `0` y `1`: FTP sin cifrado.** Existen solo para equipo antiguo que no habla TLS. En ellos, usuario, contraseña y archivo pasan en **texto plano** y pueden ser leídos por quien esté en el mismo camino de red. Úselos solo en red interna aislada, con el firewall abriendo el puerto solo a esos equipos, con usuario y contraseña dedicados a ellos, y vuelva a `2` en cuanto pueda. Mientras uno de esos modos esté activado, la stack avisa en tres lugares: al final del `./deploy.sh`, en el registro del contenedor del FTP y en las pantallas del panel. Lea antes [Seguridad](seguridad.md#ftp-sem-tls).

> ⚠️ **`FTP_TLS_EXCECOES=sim`: sin TLS solo para quien el administrador dispense.** La opción viene activada y, por sí sola, no libera a nadie: el servidor exige TLS de todos hasta que un administrador dispense a un usuario, en la pestaña Usuarios del panel (al crear o en **Dispensar del TLS**) o con el `manage-user.sh`. El usuario dispensado envía contraseña y archivo en **texto plano**, y las condiciones de uso son las mismas de los modos `0` y `1`. Con `nao`, nadie entra sin TLS, aunque ya haya sido dispensado antes: la lista queda guardada y no vale, y el panel deja de ofrecer la dispensa. Lea antes [Seguridad](seguridad.md#tls-por-usuario).

Un valor fuera de `0` a `3` es rechazado por el `deploy.sh` antes de cualquier modificación y, si llega al contenedor, este se detiene con `FALHA: FTP_TLS_MODE deve ser 0, 1, 2 ou 3`. El certificado del FTP se genera en cualquier modo: al volver a `2`, ya está ahí.

De la `FTP_TLS_EXCECOES`, solo se rechaza el valor: fuera de `sim` y de `nao`, el `deploy.sh` y los contenedores del FTP y del panel se detienen antes de cualquier modificación. Con `FTP_TLS_MODE` diferente de `2`, o junto con `REDE_PERMITIR_IP_PUBLICO=sim`, la stack arranca y la opción queda **sin efecto**: nadie es dispensado, el `deploy.sh` y el registro del FTP dicen `TLS por usuário sem efeito` con el motivo, y el panel cambia los botones por el mismo motivo. En `0` y `1` todos ya entran sin TLS, el `3` exige TLS también en los datos, lo que el equipo sin TLS no hace, y FTP sin TLS en internet entrega la contraseña a quien escucha.

> ⚠️ En el modo `2`, el valor por defecto, usuario y contraseña siempre viajan cifrados, pero el contenido del archivo solo se cifra si el cliente pide protección del canal de datos (`PROT P`). Para **obligar** el cifrado del archivo, use `FTP_TLS_MODE=3` y verifique antes si los equipos lo soportan.

Cambiar el certificado autofirmado por uno real: [Operación](operacion.md#certificado-real-de-producao).

---

<a name="limites-de-sessao"></a>

## 👥 Límites de sesión

| Variable | Para qué sirve | Valores | Por defecto |
|---|---|---|---|
| `FTP_MAX_CLIENTS` | Máximo de conexiones simultáneas (opción `-c`). El rango pasivo debe tener el doble de puertos. También define el costo de la contraseña guardada de cada usuario del FTP: [Seguridad](seguridad.md#custo-das-senhas) | entero mayor que cero | `50` |
| `FTP_MAX_CLIENTS_PER_IP` | Máximo de conexiones por IP de origen (opción `-C`) | entero mayor que cero | `8` |
| `FTP_BLOQUEIO_TENTATIVAS` | Bloqueo por intento: cuántas contraseñas incorrectas venidas de una misma dirección bloquean al usuario para esa dirección. Es el valor por defecto de la stack; el límite propio de cada usuario se ajusta en el panel: [Panel](panel.md#limites) | `0` a `100`; `0` desactiva | `5` |
| `FTP_BLOQUEIO_MINUTOS` | Minutos que dura el bloqueo. Es también el tiempo en que las contraseñas incorrectas se suman: [Seguridad](seguridad.md#bloqueio-por-tentativa) | `1` a `1440` | `15` |
| `BLOQUEIO_ENDERECO_ERROS` | Bloqueo por dirección: la dirección que pasa de este número de errores de usuario y contraseña, en el FTP o en el panel, no entra más en ninguno de los dos, con ninguna cuenta: [Seguridad](seguridad.md#bloqueio-por-endereco) | `0` a `100`; `0` desactiva | `5` |
| `BLOQUEIO_ENDERECO_HORAS` | Horas en que los errores de una misma dirección se suman | `1` a `720` | `24` |
| `BLOQUEIO_ENDERECO_DIAS` | Días que dura el bloqueo de la dirección, y el plazo que recibe el bloqueo hecho por el administrador cuando no informa otro. El administrador bloquea una dirección o un prefijo, libera y cambia el plazo en la pestaña Bloqueos del panel | `1` a `3650` | `120` |

---

<a name="painel"></a>

## 🖥️ Panel web

| Variable | Para qué sirve | Valores | Por defecto |
|---|---|---|---|
| `PAINEL_BIND_IP` | IP del **host** donde el nginx publica el panel | IP privada del host; `0.0.0.0` siempre se rechaza; IP pública, solo con `REDE_PERMITIR_IP_PUBLICO=sim` | `127.0.0.1` |
| `PAINEL_PORT` | Puerto HTTPS del panel publicado en el host por el nginx (mapeado a `8443` en el contenedor del nginx) | `1` a `65535` | `8443` |
| `PAINEL_REDES_PERMITIDAS` | Redes desde las que el panel acepta cliente. Quien está fuera recibe `403` del nginx, antes de llegar al panel; el panel verifica de nuevo | Lista de redes **privadas** separadas por coma, en notación CIDR, IPv4 o IPv6 (en IPv6, privada es `::1/128` o dentro de `fc00::/7`); red pública (de `/8` a `/32` en IPv4, de `/16` a `/128` en IPv6), solo con `REDE_PERMITIR_IP_PUBLICO=sim`. Con `REDE_IPV6=sim`, la lista necesita al menos una red IPv6 ([IPv6](#ipv6)) | `127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16` |
| `PAINEL_ADMIN_USER` | Nombre del primer administrador del panel, creado en el primer arranque con la contraseña inicial de `.secrets/`. Solo vale mientras no existe ningún administrador: después, nombre, contraseña y los otros administradores se modifican en la pestaña Usuarios | Letras minúsculas, números, `_` y `-`; empieza con letra o `_`; hasta 32 caracteres | `admin` |
| `PAINEL_SESSAO_MINUTOS` | Minutos sin uso hasta que la sesión se cierra; con o sin uso, termina en 12 horas. La actualización automática de la pestaña Servidor no cuenta como uso. Borrar, cambiar el nombre y tocar un administrador piden la contraseña de nuevo, incluso con la sesión abierta | `1` a `720` | `240` (4 horas) |
| `PAINEL_ENVIO_MAX_MB` | Tamaño máximo, en MB, de cada archivo enviado por el panel. El administrador siempre envía; el usuario del FTP, solo con el permiso marcado en su edición, en la tarjeta Límites. El nginx y el panel rechazan lo que pasa del tope con `413`; un archivo más grande va por FTP: [Enviar archivo](panel.md#enviar-arquivo) | `1` a `102400` | `1024` (1 GB) |
| `PAINEL_RETENCAO_MINUTOS` | Minutos entre una pasada y otra de la limpieza automática, que borra los archivos antiguos de las carpetas de los usuarios en que el administrador activó la regla. La primera pasada sale 2 minutos después del arranque del panel. Sin regla en ningún usuario, nada se borra: [Limpieza automática](panel.md#limpeza) | `0` a `1440`; `0` detiene la limpieza, y las reglas guardadas quedan sin efecto | `60` (1 hora) |
| `PAINEL_DESTINOS` | Activa la pestaña Destinos del panel, en la que el administrador conecta una carpeta de los datos a un almacenamiento S3, a un remoto del rclone y a un bot de Telegram, y el panel envía solo los archivos que llegan, y en la que queda la copia del sistema a S3. Con `sim`, el contenedor del panel necesita alcanzar internet, o el servidor de la red interna, por HTTPS y, en el remoto del rclone por SFTP, por SSH | `sim` o `nao`; con `nao` la pestaña desaparece del menú, sus rutas responden como camino desconocido, la pestaña Servicio queda sin la parte de los destinos y nada sale del servidor | `sim` |
| `PAINEL_TELEGRAM_API` | Dirección de la API de bot de Telegram. Solo cambia para quien ejecuta un servidor propio de la API de bot | `https://nombre` o `https://nombre:puerto`, en minúsculas y sin ruta | `https://api.telegram.org` |
| `PAINEL_TELEGRAM_MAX_MB` | Mayor archivo, en MB, que el bot envía de una vez. Un archivo más grande no se envía: la conversación recibe solo el aviso con el nombre y el tamaño. El valor por defecto es el tope de la API pública; auméntelo solo con un servidor propio de la API de bot | `1` a `2000` | `50` |
| `PAINEL_ACESSO_USUARIOS_FTP` | Entrada de los usuarios del FTP en el panel. Con `sim`, cada usuario del FTP entra con el nombre y la contraseña del FTP y ve solo su propia carpeta, donde hace lo que su perfil permite, sin ninguna pantalla de administración; con `nao`, solo entra el administrador. Quien verifica la contraseña es el servidor FTP, por la red interna de la stack: [Usuario del FTP en el panel](panel.md#usuario-ftp) | `sim` o `nao` | `sim` |
| `PAINEL_SEGUNDO_FATOR_OBRIGATORIO` | Segundo factor en la entrada del panel. Con `sim`, toda cuenta que entra en el panel, administrador o usuario del FTP, pasa por la contraseña y por el código de una aplicación autenticadora, y quien todavía no registró la aplicación la registra en la propia entrada, justo después de la contraseña; con `nao`, cada administrador activa el suyo, si quiere, y el usuario del FTP entra solo con la contraseña. Vale solo para el panel: en el FTP la entrada sigue siendo usuario y contraseña. A quien actualiza desde una versión anterior a la `1.9.0` se le exige en la entrada siguiente: [Segundo factor en la entrada](panel.md#segundo-fator) | `sim` o `nao` | `sim` |
| `PAINEL_CERT_CN` | Nombre interno o IP privada adicional en el certificado autofirmado del panel | Nombre en minúsculas o IP **privada**, IPv4 o IPv6 sin corchetes (IP pública, solo con `REDE_PERMITIR_IP_PUBLICO=sim`); vacío para ninguno | vacío |
| `PAINEL_PROXY_CONFIAVEL` | Publicar **solo el panel** por un proxy o túnel, sin exponer el FTP: las direcciones de las que el nginx acepta el `X-Forwarded-For` como dirección de quien accede. Es opcional y es elección de quien instala. Lea la [alerta](#painel-proxy-confiavel) antes de rellenarla | Hasta 8 direcciones IPv4 o IPv6 separadas por coma, una a una, sin máscara y sin corchetes; cada una privada (pública, solo con `REDE_PERMITIR_IP_PUBLICO=sim`) y dentro de `PAINEL_REDES_PERMITIDAS`; vacío para no usar | vacío |
| `PAINEL_AVISO_EXPOSICAO` | Aviso de exposición en la pantalla del panel. Con `sim`, cuando `REDE_PERMITIR_IP_PUBLICO=sim` o `PAINEL_PROXY_CONFIAVEL` está rellenada, el administrador lee cómo está publicada la instalación en tres lugares: en la señal al lado de **Seguridad** en el menú, al comienzo de la pestaña Seguridad y en el pie de página. Con `nao`, los tres desaparecen. La pantalla de entrada y las pantallas del usuario del FTP nunca dicen cómo fue publicado el panel. Las líneas **Dirección pública** y **Panel por proxy o túnel** de la pestaña Seguridad, que solo ve el administrador, siguen mostrando el estado, y la alerta sigue en la salida del `deploy.sh` y en el registro de los contenedores | `sim` o `nao` | `sim` |
| `PAINEL_MEMORY_LIMIT` | `mem_limit` del panel, sin swap | ejemplo: `192M` | `192M` |
| `PAINEL_CPU_LIMIT` | Núcleos que el panel puede usar, en promedio. La cuota se mide en períodos de 500 ms (`cpu_period` y `cpu_quota` de Compose, en lugar de `cpus`, que mide en períodos de 100 ms), para que la verificación de una contraseña, que gasta unos 65 ms de procesador de una vez, quepa en la cuota de un período. El `deploy.sh` calcula la cuota de cada período, `PAINEL_CPU_QUOTA`, en microsegundos, y la guarda en el `.env` cuando el valor no es `0.5`: después de cambiarlo, ejecute `./deploy.sh` | número desde `0.01`, con hasta tres decimales; ejemplo: `0.5`, `1` | `0.5` |
| `PAINEL_PIDS_LIMIT` | `pids_limit` del panel | entero | `64` |
| `NGINX_MEMORY_LIMIT` | `mem_limit` del nginx, sin swap | ejemplo: `64M` | `64M` |
| `NGINX_CPU_LIMIT` | `cpus` del nginx | ejemplo: `0.5` | `0.5` |
| `NGINX_PIDS_LIMIT` | `pids_limit` del nginx | entero | `32` |

> 🧱 **Red privada:** por defecto el panel es solo para red interna, detrás de firewall. `PAINEL_BIND_IP`, cada red de `PAINEL_REDES_PERMITIDAS` y un `PAINEL_CERT_CN` en forma de IP tienen que ser privados: el [`deploy.sh`](../../deploy.sh) y los contenedores del panel y del nginx se detienen con `não é IP privado` o `não é rede privada` para cualquier otro valor. Dirección y red públicas solo pasan con la opción [`REDE_PERMITIR_IP_PUBLICO`](#rede-permitir-ip-publico).

<a name="painel-proxy-confiavel"></a>

> ⚠️ **Alerta — `PAINEL_PROXY_CONFIAVEL` rellenada pone la pantalla de entrada del panel al alcance de quien llega al proxy o al túnel.** Con la variable vacía, que es el valor por defecto, la dirección de quien accede es siempre la de la conexión y el `X-Forwarded-For` se ignora. Rellenada, el nginx pasa a usar la **última** dirección de ese encabezado, solo cuando la conexión viene de una dirección de la lista, para el límite de intentos de contraseña, la sesión, la auditoría y los límites de solicitudes. Quién puede llegar a la pantalla pasa a decidirse en el proxy o en el túnel: restrinja el acceso allí. El FTP no pasa por él y sigue solo en las direcciones de la stack. El nombre público por el que se abre el panel va en `PAINEL_CERT_CN`. El paso a paso está en [Seguridad](seguridad.md#painel-por-proxy).

Con `PAINEL_SESSAO_MINUTOS`, `PAINEL_ENVIO_MAX_MB` o `PAINEL_RETENCAO_MINUTOS` fuera de los valores de la tabla, el contenedor del panel no arranca: se detiene con `FALHA: <variável> deve ficar entre <mínimo> e <máximo>` en el log (`docker compose logs painel`), antes de tocar cualquier carpeta.

La contraseña del panel **no** es variable: la inicial queda en `.secrets/`, y la de cada administrador, solo como hash, en `DATA_DIR/painel/administradores`. El `deploy.sh` y el contenedor rechazan `PAINEL_PASSWORD` y `PAINEL_PASSWORD_HASH`, y se detienen con `PAINEL_ADMIN_USER inválido` para un nombre fuera de la regla. Vea [Secretos](secretos.md#senha-do-painel) y [Administradores del panel](panel.md#administradores).

El navegador nunca habla directo con el panel: solo el nginx publica puerto, y reenvía la solicitud al panel por un socket dentro de `DATA_DIR/nginx`. El límite de solicitudes por dirección, el tamaño máximo de la solicitud, el HTTP/2 y el tiempo de la conexión inactiva son fijos en la configuración del nginx ([`nginx/nginx.conf.modelo`](../../nginx/nginx.conf.modelo)), sin variable. Los perfiles de [`profiles/`](../../profiles/) no tocan las variables del panel ni las del nginx.

---

<a name="contato-de-seguranca"></a>

## 📮 Contacto de seguridad

| Variable | Para qué sirve | Valores | Por defecto |
|---|---|---|---|
| `SEGURANCA_CONTATO_EMAIL` | Correo al que debe escribir quien encuentre una falla de seguridad en esta instalación. Rellenado, el panel publica la dirección en `/.well-known/security.txt`, sin pedir contraseña, para las redes de `PAINEL_REDES_PERMITIDAS` | Una sola dirección de correo, sin `mailto:`; vacío para no publicar | vacío |

El archivo sigue la RFC 9116: es donde un investigador, o la herramienta de escaneo de la propia empresa, busca a quién avisar. Use un buzón leído por más de una persona, como `seguranca@suaempresa.com.br`: la dirección queda a la vista de quien alcanza el panel.

1. En el `.env`, rellene la variable:

   ```bash
   SEGURANCA_CONTATO_EMAIL=seguranca@suaempresa.com.br
   ```

2. Aplique de nuevo:

   ```bash
   ./deploy.sh
   ```

3. Verifique, desde una máquina de las redes permitidas:

   ```bash
   curl -k https://<dirección del panel>:8443/.well-known/security.txt
   ```

**Resultado esperado:** el resumen del `deploy.sh` con la línea `Contato de segurança: seguranca@suaempresa.com.br, publicado em /.well-known/security.txt do painel.`, tres líneas en la respuesta y la pestaña Seguridad del panel con el elemento `Contacto de seguridad` marcado.

```text
Contact: mailto:seguranca@suaempresa.com.br
Expires: 2027-01-03T00:00:00Z
Preferred-Languages: pt-BR
```

Con la variable vacía, la misma dirección responde `404` con `contacto de seguridad no configurado`, y el resumen del `deploy.sh` trae `Contato de segurança: não publicado`, con lo que hay que rellenar. Con `REDE_PERMITIR_IP_PUBLICO=sim`, la pestaña Seguridad pasa a exigir que se rellene.

<details>
<summary>Detalle técnico — validez, validación y lo que no se publica</summary>

- **Validez siempre en el futuro:** la línea `Expires` se calcula en cada solicitud, 90 días hacia adelante, a la medianoche UTC. El archivo no vence con el servidor en marcha, y la RFC pide una validez menor a un año.
- **Siempre igual al `.env`:** el texto sale de la configuración en vigor, no de un archivo guardado. Vaciar la variable y ejecutar el `deploy.sh` deja de publicar el archivo.
- **Validación en tres puntos:** el [`deploy.sh`](../../deploy.sh), el contenedor del panel y el propio panel rechazan el valor que no es una sola dirección: sin `@`, dominio sin punto, dos direcciones, espacio, `mailto:`, URL, `<`, `>`, `%`, salto de línea, parte antes del `@` con más de 64 caracteres o dirección con más de 254. El mensaje es `SEGURANCA_CONTATO_EMAIL inválido`.
- **Solo el contacto:** el archivo no trae versión, nombre de la stack ni ruta. No hay línea `Canonical`, porque la dirección del panel cambia de una instalación a otra y el archivo no está firmado.
- **Solo esa dirección:** `/security.txt` en la raíz, la lista de `/.well-known/` y cualquier otro nombre dentro de ella no existen; sin sesión, llevan a la pantalla de entrada.
- **De quién es el contacto:** de quien opera esta instalación, no de quien desarrolló la stack. La [política de seguridad](../../SECURITY.es.md) del proyecto no trae dirección fija: envía a quien encontró la falla al contacto publicado aquí.

Qué más queda abierto sin contraseña, y por qué: [Seguridad](seguridad.md#contato-de-seguranca).

</details>

---

<a name="limites-de-recurso-do-container"></a>

## 🧱 Límites de recurso del contenedor

| Variable | Para qué sirve | Valores | Por defecto |
|---|---|---|---|
| `FTP_MEMORY_LIMIT` | `mem_limit` del servicio, sin swap: es el tope de verdad, y la pestaña Servidor muestra el uso contra él | ejemplo: `256M`, `512M` | `256M` |
| `FTP_CPU_LIMIT` | `cpus` del servicio | ejemplo: `0.5`, `1.0`, `2` | `1.0` |
| `FTP_PIDS_LIMIT` | `pids_limit` (barrera contra _fork bomb_) | entero | `128` |
| `FTP_NOFILE` | `ulimit nofile` (soft igual a hard) | entero | `16384` |
| `FTP_PROFILE` | Nombre del perfil en uso. Solo informa: quien lo guarda es el `./deploy.sh --size` | `small`, `medium`, `large`, `xlarge`, `extended` | `small` |

> Estos campos, más `FTP_MAX_CLIENTS*` y el rango pasivo, son lo que el `./deploy.sh --size <perfil>` guarda a partir de [`profiles/`](../../profiles/). Prefiera `./deploy.sh --size medium` a editar los valores a mano: vea [Perfiles](perfiles.md). El `deploy.sh` verifica si el servidor tiene las CPU y la memoria que piden `FTP_CPU_LIMIT` y `FTP_MEMORY_LIMIT` y rechaza lo que no cabe.

---

<a name="rede-docker-sub-rede"></a>

## 🌐 Red Docker (subred)

La red Docker de esta stack tiene subred fija, que se cambia con una variable en el `.env`. Úsela cuando el rango choque con la LAN o la VPN del cliente.

| Variable | Red | Contenedores | Por defecto | Ejemplo |
|---|---|---|---|---|
| `FTP_SUBNET` | `ftp` (`allsafe-ftp-network`) | `allsafe-ftp`, `allsafe-ftp-painel` y `allsafe-ftp-nginx` | `172.29.1.0/29` | `FTP_SUBNET=10.250.1.0/29` |
| `FTP_SUBNET_IPV6` | La misma red, en IPv6; solo con `REDE_IPV6=sim` | Los mismos | `fd29:1::/64` | `FTP_SUBNET_IPV6=fd00:250:1::/64` |

En una instalación que ya está en marcha, la subred nueva solo vale después de recrear la red (los volúmenes y los datos no se ven afectados):

```bash
./deploy.sh --remover      # detiene los contenedores y elimina la red; los datos quedan
./deploy.sh                # levanta de nuevo, con la red nueva
```

**Resultado esperado:** `docker network inspect allsafe-ftp-network` muestra la subred nueva.

> El perfil en uso está guardado en el `.env`: el `deploy.sh` sin `--size` y el `docker compose up -d` aplican los mismos límites.

<details>
<summary>Detalle técnico — el bloque de direcciones de las stacks AllSafe</summary>

Las stacks AllSafe reservan `172.29.1.0/24` para redes `/29` y `172.29.2.0/24` para redes `/28` y `/27`. Esta stack usa la primera `/29` del bloque. El valor entra en el [`compose.yaml`](../../compose.yaml) como `subnet: ${FTP_SUBNET:-172.29.1.0/29}`.

</details>

---

⬅️ [Instalación](instalacion.md) · 🏠 [Documentación](README.md) · ➡️ [Perfiles](perfiles.md)
