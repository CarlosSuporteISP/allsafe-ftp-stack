# ♻️ Copia de seguridad y restauración — allsafe-ftp-stack

[![English](https://img.shields.io/badge/English-6e7781?style=for-the-badge)](../en/backup.md)
[![Português (Brasil)](https://img.shields.io/badge/Portugu%C3%AAs_(Brasil)-6e7781?style=for-the-badge)](../pt-BR/backup.md)
[![Español](https://img.shields.io/badge/Espa%C3%B1ol-0969da?style=for-the-badge)](backup.md)

↩ [README del proyecto](../../README.es.md) · [Índice de la documentación](README.md)

## 💡 En pocas palabras

Un comando guarda todo lo que la stack tiene de suyo: los archivos enviados por los equipos, los usuarios, los certificados y el historial del panel. El resultado es un solo archivo, **cifrado**, con fecha y hora en el nombre, guardado en `BACKUP_DIR`: quien tome el archivo no lee nada de él sin la clave que queda en `.secrets/`. Otro comando devuelve la stack al estado de ese archivo y, antes de cambiar cualquier cosa, guarda el estado actual, para que la restauración pueda deshacerse. Las contraseñas de `.secrets/`, la clave que abre la copia y el `.env` quedan fuera de ella: guárdelos aparte, fuera del servidor.

<!-- diagrama: diagramas/backup-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    origem@{ shape: lin-cyl, label: "DATA_DIR<br>dados, auth, certs y painel" }
    backup@{ shape: console, label: "scripts/backup.sh<br>lee y cifra, sin red" }
    copia@{ shape: doc, label: "BACKUP_DIR<br>copia cifrada y suma sha256" }
    restaurar@{ shape: console, label: "scripts/restaurar.sh<br>abre, guarda lo actual y cambia" }
    destino@{ shape: lin-cyl, label: "DATA_DIR<br>contenido de la copia" }
    fim@{ shape: stadium, label: "stack de vuelta" }

    origem --> backup --> copia --> restaurar --> destino --> fim
```

<sub>Nivel 1 · Diagrama · [fuente](diagramas/)</sub>

**Secuencia:** `DATA_DIR` (`dados`, `auth`, `certs` y `painel`) ➜ `scripts/backup.sh` ➜ `BACKUP_DIR` (copia cifrada y suma `.sha256`) ➜ `scripts/restaurar.sh` ➜ `DATA_DIR` (contenido de la copia) ➜ stack de vuelta

---

<details>
<summary>Índice — haga clic para expandir</summary>

[Qué entra en la copia](#o-que-entra) · [La clave de la copia](#chave) · [Hacer la copia](#fazer) · [Restaurar](#restaurar) · [Deshacer una restauración](#desfazer) · [Guardar el `.env` y los secretos](#segredos) · [Restaurar en otro servidor](#outro-servidor) · [Copia automática y limpieza](#automatica) · [Copia en S3, desde el panel](#no-s3)

</details>

---

<a name="o-que-entra"></a>

## 📦 Qué entra en la copia

| Carpeta de `DATA_DIR` | Qué guarda | Entra en la copia |
|---|---|---|
| `dados/` | Archivos enviados por los equipos, una carpeta por usuario, y `.entrada/`, el área de entrada de las cuentas de perfil Solo envío, vacía fuera del instante de cada envío | Sí |
| `auth/` | Usuarios del FTP, con el hash de cada contraseña, los límites propios de cada uno, la lista de quién está dispensado del TLS y los bloqueos en vigor, por intento y por dirección | Sí |
| `certs/` | Certificado y clave privada del FTP | Sí |
| `painel/` | Certificado y clave privada del panel, los administradores (nombre y hash de la contraseña), el `auditoria.log`, el idioma de las pantallas elegido por cada cuenta y la configuración y el avance de los [destinos](panel.md#destinos) y de la copia del sistema a S3, sin sus secretos | Sí |
| `nginx/` | Socket del panel y copia del certificado, rehechos en cada arranque | No |

Quedan fuera, y hay que guardarlos aparte: el `.env` y la carpeta `.secrets/`, donde está la clave que abre la copia. Vea [La clave de la copia](#chave) y [Guardar el `.env` y los secretos](#segredos).

> ⚠️ La copia contiene el hash de las contraseñas de los usuarios, las claves privadas de los certificados y los archivos de los equipos. Por eso sale cifrada, con modo `0600`, en una carpeta `0700`. Una copia que queda solo en el mismo servidor no protege contra la pérdida del servidor: lleve el `.tar.gz.age` y el `.sha256` a otra máquina o medio, y guarde la clave privada **en otro lugar**, nunca junto con las copias.

---

<a name="chave"></a>

## 🔐 La clave de la copia

La copia se cifra con un par de claves, creado por el `./deploy.sh` la primera vez y guardado en `.secrets/`:

| Archivo | Qué hace | Dónde tiene que estar |
|---|---|---|
| `backup-chave-publica.txt` | Cifra. Con ella se hace la copia, pero no se abre ninguna | En el servidor, para el `scripts/backup.sh` y para la [copia que el panel envía a S3](#no-s3) |
| `backup-chave-privada.txt` | Abre. Es lo único que lee una copia | En un gestor de contraseñas, fuera del servidor. En el servidor, solo el `scripts/restaurar.sh` la usa |

> ⚠️ **Sin la clave privada ninguna copia se abre, y no hay cómo recuperarla.** Guarde `backup-chave-privada.txt` fuera del servidor apenas termine la instalación, separada de las copias de seguridad. Quien tiene la clave y una copia lee todo lo que hay en ella.

Qué hacer en cada situación:

| Situación | Qué hacer |
|---|---|
| Instalación nueva, o actualización desde una versión anterior a la `0.48.0` | Ejecute `./deploy.sh`: crea el par y avisa `Gerada a chave da cópia de segurança`. Guarde la privada en el gestor de contraseñas |
| Servidor que hace la copia y no puede abrirla | Con la privada ya en el gestor de contraseñas, bórrela del servidor. El `scripts/backup.sh` sigue funcionando con la pública. Para restaurar, traiga la privada de vuelta a `.secrets/backup-chave-privada.txt`, con modo `0600` |
| Cambiar el par | Borre los dos archivos y ejecute `./deploy.sh`, que crea un par nuevo y recrea el contenedor del panel, para que la copia que él envía a S3 salga cifrada con la clave nueva. Las copias hechas antes solo se abren con la privada antigua: manténgala en el gestor de contraseñas mientras esas copias existan |
| La clave pública desapareció o fue modificada | Ejecute `./deploy.sh`: con la privada presente, rehace la pública a partir de ella |
| Copia hecha antes de la `0.48.0`, sin cifrado | Sigue restaurándose, con el aviso `esta cópia não é cifrada`, y el `--listar` la marca con `(sem cifra: feita antes da 0.48.0)`. Haga una copia nueva y borre la antigua |

El `./deploy.sh` nunca reescribe la clave privada que ya existe. No hay opción para desactivar el cifrado.

---

<a name="fazer"></a>

## 💾 Hacer la copia

La stack puede quedar en marcha; los equipos siguen enviando durante la copia.

```bash
./scripts/backup.sh                          # guarda la copia en BACKUP_DIR
./scripts/backup.sh --rotulo antes-da-troca  # lo mismo, con un texto en el nombre del archivo
./scripts/backup.sh --listar                 # muestra las copias que existen
```

**Resultado esperado:**

```text
Cópia gravada: <BACKUP_DIR>/allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz.age (<tamanho>, cifrada)
Fora da cópia: .env e os segredos de ./.secrets. Guarde-os à parte (doc/backup.md).
Só a chave privada abre a cópia (backup-chave-privada.txt, de ./.secrets): guarde-a também fora deste servidor.
Restaurar: ./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz.age
```

Al lado de cada copia queda un archivo `.sha256`, con la suma que la restauración verifica antes de usar la copia. El `--listar` muestra `Cópias em <BACKUP_DIR>:` y una línea por archivo, con el tamaño, y la marca `(sem cifra: feita antes da 0.48.0)` en las copias antiguas; sin ninguna copia, `Nenhuma cópia em <BACKUP_DIR>.`

El rótulo acepta letras minúsculas, números y guion, hasta 40 caracteres. La copia ocupa cerca del tamaño de `DATA_DIR/dados` después de comprimido: verifique el espacio libre en `BACKUP_DIR` antes de la primera.

<details>
<summary>Detalle técnico — cómo se hace la copia y códigos de salida</summary>

- **Quien lee es un contenedor descartable**, porque parte de los archivos pertenece al `root` y al usuario del FTP: `docker run --rm --network none --read-only --cap-drop ALL --cap-add DAC_READ_SEARCH`, con `DATA_DIR` montada solo para lectura. El contenedor no tiene red y no escribe en `DATA_DIR`.
- **La lista de usuarios entra entera:** `auth/` se copia con el mismo bloqueo que usan el panel y el `manage-user.sh` (`/auth/.lock`, espera de hasta 30 segundos) y el bloqueo se suelta enseguida. Una modificación de usuario nunca queda a medias en la copia.
- **Cifrado en flujo:** dentro del contenedor, la salida del `tar` con `gzip` va directo al `age` (paquete de Debian, solo en la imagen del FTP), que cifra para la clave pública de `SECRETS_DIR/backup-chave-publica.txt` (X25519 y ChaCha20-Poly1305). Nada sin cifrar llega al disco, y el contenedor no recibe la clave privada. Cada bloque de la copia está autenticado: un byte cambiado o un corte en el archivo hace fallar la apertura.
- **El archivo solo aparece listo:** la escritura se hace en `<nome>.parcial` y se renombra al final. Si el comando se interrumpe, el parcial se borra.
- **Dueño y modo preservados:** el `tar` guarda los números de usuario y grupo (`--numeric-owner`), y la restauración los devuelve iguales.
- **Nombre del archivo:** `<STACK_NAME>-AAAAMMDD-HHMMSS[-rótulo].tar.gz.age`.
- **Sin rotación:** el script no borra copias antiguas. Vea [Copia automática y limpieza](#automatica).
- **Otra instalación:** `ENV_FILE=<arquivo> ./scripts/backup.sh` copia la instalación de ese archivo de entorno.

| Salida | Significado |
|---|---|
| `0` | copia guardada. Con `AVISO: algum arquivo mudou enquanto era lido`, había un envío en curso: la copia vale, pero ese archivo puede estar incompleto |
| `1` | no se guardó nada. El mensaje `ERRO:` dice el motivo: `.env`, imagen o clave pública ausentes (ejecute el `./deploy.sh`), clave pública inválida, `DATA_DIR/auth` inexistente, `BACKUP_DIR` dentro de `DATA_DIR`, falla en la lectura o falla en el cifrado |
| `64` | opción inválida, rótulo fuera del formato o `--rotulo` sin texto |

</details>

---

<a name="restaurar"></a>

## 🔁 Restaurar

La restauración **sustituye** el contenido actual de `dados/`, `auth/`, `certs/` y `painel/` por el de la copia. La stack se detiene durante el cambio y arranca de nuevo al final; en ese intervalo los equipos no logran enviar.

```bash
./scripts/restaurar.sh --listar                                            # elija la copia
./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz.age        # pide escribir 'restaurar'
./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz.age --sim  # sin pregunta, para automatización
```

La copia puede indicarse solo por el nombre, buscado en `BACKUP_DIR`, o por la ruta completa. La clave privada tiene que estar en `.secrets/backup-chave-privada.txt`: vea [La clave de la copia](#chave).

**Resultado esperado:**

```text
Cópia: <BACKUP_DIR>/allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz.age (<tamanho>, <n> itens, soma sha256 conferida)
Parando a stack...
Estado atual guardado em: <BACKUP_DIR>/allsafe-ftp-stack-AAAAMMDD-HHMMSS-antes-da-restauracao.tar.gz.age
Subindo a stack...
Restaurado e no ar (healthy).
Usuários, arquivos, certificados, administradores do painel e auditoria voltaram ao estado da cópia.
A senha do usuário inicial do FTP é a de ./.secrets, que não faz parte da cópia, ou a trocada pelo painel, se a cópia a trazia.
Desfazer: ./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS-antes-da-restauracao.tar.gz.age
```

Qué cambia después de restaurar:

- Los usuarios creados después de la copia dejan de existir; los eliminados después de ella vuelven.
- Cada usuario vuelve con la contraseña y la carpeta que tenía en la copia. El usuario inicial (`FTP_USER`) queda con la contraseña de `.secrets/ftp-usuario-inicial-senha.txt`; si en la copia su contraseña estaba cambiada desde el panel y el archivo no cambió desde entonces, vale la de la copia. Si en la copia ya había sido eliminado, sigue eliminado.
- Las contraseñas vuelven con el costo con que fueron guardadas. Una copia hecha antes de la `0.29.0`, o en un porte menor, trae contraseñas con el costo anterior: la pestaña Seguridad del panel lista de quién, y el costo actual pasa a valer cuando se cambia la contraseña.
- Los administradores del panel vuelven a ser los de la copia, cada uno con la contraseña que tenía: quien fue creado después de ella deja de existir y todos entran de nuevo. Una copia hecha antes de la `0.22.0` no tiene administradores: el panel crea el de `PAINEL_ADMIN_USER` con el hash de `.secrets/painel-admin-inicial-senha-hash.txt`.
- Si la stack estaba detenida, sigue detenida: `Restaurado. A stack estava parada e continua parada: suba com ./deploy.sh`.

> ⚠️ La copia se verifica antes de cualquier modificación. Si la suma no coincide, si el archivo no se abre con la clave o si no es una copia de esta stack, el comando se detiene con `ERRO: ... Nada foi tocado.` y la stack sigue como estaba.

<details>
<summary>Detalle técnico — orden de los pasos, rechazos y códigos de salida</summary>

Orden de lo que hace el script:

1. Verifica la copia: la suma del `.sha256` (si el archivo existe al lado; sin él, avisa `soma não conferida` y sigue), la apertura de la copia entera con la clave privada de `SECRETS_DIR/backup-chave-privada.txt` (una copia sin cifrado, hecha antes de la `0.48.0`, se lee directo y recibe un aviso), la presencia de `auth/pureftpd.passwd` y la ausencia de cualquier elemento fuera de `dados/`, `auth/`, `certs/` y `painel/`.
2. Pide la confirmación: escribir `restaurar`, o `--sim`. Sin terminal, solo se ejecuta con `--sim`.
3. Detiene los contenedores, si estaban en marcha (`docker compose stop`).
4. Guarda el estado actual, también cifrado, con `scripts/backup.sh --rotulo antes-da-restauracao`. Si esa copia falla, nada se modifica y la stack arranca de nuevo.
5. Vacía las cuatro carpetas y extrae la copia, con un contenedor descartable sin red, con la raíz de solo lectura, `DATA_DIR` montada y la clave privada montada solo para lectura (`--cap-drop ALL`, más `CHOWN`, `DAC_OVERRIDE` y `FOWNER`, para devolver dueño y modo).
6. Levanta los contenedores y espera a que queden `healthy` (`docker compose up -d --wait`, plazo de 300 segundos), si estaban en marcha.

| Mensaje | Cuándo |
|---|---|
| `ERRO: cópia não encontrada: ...` | el nombre no existe en `BACKUP_DIR` ni como ruta |
| `ERRO: a soma sha256 de ... não confere: a cópia está corrompida ou foi alterada. Nada foi tocado.` | la copia no coincide con el `.sha256` de al lado |
| `ERRO: a cópia é cifrada e a chave que a abre não está em ... Nada foi tocado.` | `backup-chave-privada.txt` no está en `SECRETS_DIR`: tráigala del gestor de contraseñas |
| `ERRO: ... não abre com a chave de ...: chave de outra instalação, cópia corrompida ou alterada. Nada foi tocado.` | la clave no es la de la copia, o el archivo fue cortado o modificado |
| `ERRO: ... não é uma cópia cifrada nem um arquivo .tar.gz legível. Nada foi tocado.` | archivo de otro formato |
| `ERRO: ... tem itens fora de dados/, auth/, certs/ e painel/: não é uma cópia desta stack. Nada foi tocado.` | copia de otro origen |
| `ERRO: ... não tem a lista de usuários (auth/pureftpd.passwd): não é uma cópia desta stack. Nada foi tocado.` | copia sin los usuarios |
| `ERRO: restauração sem terminal exige --sim.` | llamado por un script o por `cron` sin la opción |
| `ERRO: confirmação não recebida; nada foi alterado.` | la palabra escrita no fue `restaurar` |
| `ERRO: a restauração falhou no meio: ...` | falla durante la extracción (disco lleno, por ejemplo). La stack queda detenida: restaure de nuevo, con la misma copia o con la `antes-da-restauracao` |

| Salida | Significado |
|---|---|
| `0` | restaurado |
| `1` | rechazado o falló; el mensaje `ERRO:` dice el motivo |
| `64` | uso inválido: opción desconocida, ninguna copia indicada o más de una |

Otra instalación: `ENV_FILE=<arquivo> ./scripts/restaurar.sh <cópia>`.

</details>

---

<a name="desfazer"></a>

## ↩️ Deshacer una restauración

Toda restauración guarda antes el estado que encontró, en un archivo con `antes-da-restauracao` en el nombre. Para volver a él, restaure ese archivo; el comando exacto aparece en la última línea de la restauración:

```bash
./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS-antes-da-restauracao.tar.gz.age
```

**Resultado esperado:** `Restaurado e no ar (healthy).`, con los usuarios y los archivos de antes de la restauración.

---

<a name="segredos"></a>

## 🔑 Guardar el `.env` y los secretos

La copia no lleva el `.env` ni la carpeta `.secrets/`, para que un archivo de copia de seguridad que se filtre no entregue las contraseñas en texto ni la clave que lo abre. Guarde los dos en un gestor de contraseñas, separados de las copias:

| Qué guardar | Para qué sirve a la vuelta |
|---|---|
| `.secrets/backup-chave-privada.txt` | Abre las copias de seguridad. Sin ella, ninguna copia cifrada se restaura |
| `.env` | Direcciones, puertos, perfil y límites de la instalación |
| `.secrets/ftp-usuario-inicial-senha.txt` | Contraseña del usuario inicial del FTP |
| `.secrets/painel-admin-inicial-senha-hash.txt` | Hash de la contraseña inicial del primer administrador del panel |
| `.secrets/destinos/` | Claves del S3, acceso del remoto del rclone, token del bot de Telegram y conversación que recibe, guardados por el panel en la pestaña Destinos |
| `.secrets/segundo-fator/` | Clave del segundo factor de cada cuenta del panel, administrador y usuario del FTP, guardada por el panel en el registro |

La clave privada es la única sin vuelta atrás: sin ella la copia no se abre. Sin los otros, la stack vuelve igual: el `./deploy.sh` crea un `.env` nuevo y contraseñas nuevas, y los secretos de los destinos se escriben de nuevo en la pestaña Destinos, en **Modificar**; hasta entonces, la tarjeta muestra la marca **faltan los secretos** y no se envía nada. En ese caso, el usuario inicial pasa a tener la contraseña nueva, que hay que configurar en el equipo que lo usa. Los demás usuarios y los administradores del panel no se ven afectados: el hash de su contraseña está en la copia. Detalles de cada archivo en [Secretos](secretos.md).

La copia lleva la lista de quién tiene el [segundo factor](panel.md#segundo-fator) activado, pero no la clave de cada uno. Si la carpeta `.secrets/segundo-fator/` no vuelve junto, la cuenta con el factor activado no entra (`503`): desactive su factor desde la terminal (usuario del FTP: `ftp.NOME`). En la entrada siguiente, la cuenta registra la aplicación de nuevo, con una clave nueva; con `PAINEL_SEGUNDO_FATOR_OBRIGATORIO=nao`, entra solo con la contraseña y el administrador lo activa de nuevo desde el panel:

```bash
docker compose exec painel python3 /opt/painel/servidor.py --segundo-fator desligar NOME
```

---

<a name="outro-servidor"></a>

## 🚚 Restaurar en otro servidor

1. Traiga el proyecto al servidor nuevo y guarde la clave conservada en el gestor de contraseñas en `.secrets/backup-chave-privada.txt`, con modo `0600`: sin ella la copia no se abre. Si los guardó, traiga también el `.env` y el resto de `.secrets/`.
2. Instale, para crear las carpetas, las imágenes y los contenedores. Con la clave privada en su lugar, el `./deploy.sh` no crea otra y rehace la pública a partir de ella:

   ```bash
   ./deploy.sh
   ```

3. Copie el `.tar.gz.age` y el `.sha256` a la carpeta `BACKUP_DIR` del servidor nuevo.
4. Restaure:

   ```bash
   ./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz.age
   ```

**Resultado esperado:** `Restaurado e no ar (healthy).`, con los usuarios y los archivos de la copia.

Si el `./deploy.sh` se ejecutó antes de que llegara la clave, creó un par nuevo: escriba la clave conservada sobre `.secrets/backup-chave-privada.txt`, ejecute el `./deploy.sh` de nuevo y restaure.

Si la dirección del servidor cambió, ajuste `FTP_BIND_IP`, `FTP_PASSIVE_IP` y `PAINEL_BIND_IP` en el `.env` antes del `./deploy.sh`: vea [Configuración](configuracion.md). El certificado del panel se rehace solo cuando las direcciones cambian; el del FTP vuelve a ser el de la copia.

---

<a name="automatica"></a>

## ⏰ Copia automática y limpieza

El `backup.sh` no hace preguntas y no necesita terminal, así que puede ejecutarse por el `cron` del usuario que administra la stack. Ejemplo, todos los días a las 2h30, con el resultado en el registro del sistema:

```bash
30 2 * * * cd /caminho/da/stack && ./scripts/backup.sh 2>&1 | logger -t allsafe-ftp-backup
```

Elija un horario fuera de la ventana en que los equipos envían sus copias de seguridad.

El script no borra copias antiguas. Para eliminar las que tienen más de 30 días, cifradas o no, junto con el `.sha256` de cada una:

```bash
BACKUP_DIR="$(sed -n 's/^BACKUP_DIR=//p' .env | tail -n 1)"   # el BACKUP_DIR de su .env
find "$BACKUP_DIR" -maxdepth 1 -name 'allsafe-ftp-stack-*.tar.gz*' -mtime +30 -print -delete
```

**Resultado esperado:** la ruta de cada archivo eliminado; ninguna línea cuando no hay copia con más de 30 días.

Para tener la copia fuera del servidor sin depender del `cron`, el panel hace la misma copia y la envía a un S3, con rutina propia: vea [Copia en S3, desde el panel](#no-s3).

---

<a name="no-s3"></a>

## ☁️ Copia en S3, desde el panel

El panel hace la misma copia y la envía directo a un almacenamiento S3, sin pasar por `BACKUP_DIR`: con el botón **Copiar y enviar ahora**, por rutina o desde la terminal. Cómo configurarlo está en [Copia del sistema a S3](panel.md#copia-do-sistema). Cada copia son dos objetos en la carpeta elegida del bucket, y el panel no borra ninguno:

| Objeto | Qué es |
|---|---|
| `<pasta>/<STACK_NAME>-AAAAMMDD-HHMMSS.tar.gz.age` | La copia, cifrada con la misma clave pública del `scripts/backup.sh` |
| `<pasta>/<STACK_NAME>-AAAAMMDD-HHMMSS.tar.gz.age.sha256` | La suma que la restauración verifica |

<!-- diagrama: diagramas/backup-s3-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    origem@{ shape: lin-cyl, label: "DATA_DIR<br>dados, auth, certs y painel" }
    painel@{ shape: rect, label: "panel<br>lee, cifra y envía" }
    bucket@{ shape: bucket, label: "bucket S3<br>copia cifrada y suma sha256" }
    baixar@{ shape: manual, label: "descargar los dos objetos<br>a BACKUP_DIR" }
    restaurar@{ shape: console, label: "scripts/restaurar.sh<br>verifica, abre y cambia" }
    destino@{ shape: lin-cyl, label: "DATA_DIR<br>contenido de la copia" }
    fim@{ shape: stadium, label: "stack de vuelta" }

    origem --> painel --> bucket --> baixar --> restaurar --> destino --> fim
```

<sub>Nivel 1 · Diagrama · [fuente](diagramas/)</sub>

**Secuencia:** `DATA_DIR` (`dados`, `auth`, `certs` y `painel`) ➜ panel (lee, cifra y envía) ➜ bucket S3 (copia cifrada y suma `.sha256`) ➜ descargar los dos objetos a `BACKUP_DIR` ➜ `scripts/restaurar.sh` ➜ `DATA_DIR` (contenido de la copia) ➜ stack de vuelta

Para restaurar a partir de ella:

1. Descargue los dos objetos del bucket a la carpeta `BACKUP_DIR` del servidor, con la herramienta de su servicio S3. El panel no descarga: solo escribe en el bucket.
2. Verifique que la clave privada está en `.secrets/backup-chave-privada.txt`: vea [La clave de la copia](#chave).
3. Restaure:

   ```bash
   ./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz.age
   ```

**Resultado esperado:** la primera línea trae `soma sha256 conferida`, y la restauración termina con `Restaurado e no ar (healthy).`, como en [Restaurar](#restaurar).

- La copia del panel lleva las mismas cuatro carpetas, y queda fuera lo mismo: el `.env` y la carpeta `.secrets/`, con los secretos de los destinos.
- Después de restaurar, la configuración de la copia del sistema es la que estaba en la copia, y la línea **Última copia** de la tarjeta vuelve a empezar en **ninguna todavía**.
- En otro servidor, sin la carpeta `.secrets/destinos`, la tarjeta muestra la marca **faltan los secretos**, y la rutina no envía hasta que las claves del S3 se guarden de nuevo, en **Modificar**.
- El archivo que estaba llegando durante la copia puede haber entrado incompleto: la tarjeta y la terminal dicen cuántos cambiaron durante la lectura.
- La copia del panel y la del `scripts/backup.sh` no dependen una de la otra. La de S3 es la que sobrevive a la pérdida del servidor; la de `BACKUP_DIR` es la que el `restaurar.sh` encuentra sin descargar nada.

---

⬅️ [Operación](operacion.md) · 🏠 [Documentación](README.md) · ➡️ [Panel web](panel.md)
