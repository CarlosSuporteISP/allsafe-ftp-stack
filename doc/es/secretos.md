# 🔑 Secretos — allsafe-ftp-stack

[![English](https://img.shields.io/badge/English-6e7781?style=for-the-badge)](../en/secrets.md)
[![Português (Brasil)](https://img.shields.io/badge/Portugu%C3%AAs_(Brasil)-6e7781?style=for-the-badge)](../pt-BR/segredos.md)
[![Español](https://img.shields.io/badge/Espa%C3%B1ol-0969da?style=for-the-badge)](secretos.md)

↩ [README del proyecto](../../README.es.md) · [Índice de la documentación](README.md)

## 💡 En pocas palabras

Las contraseñas de la stack viven en la carpeta `.secrets/`, que nunca va al Git ni dentro de la imagen. Son dos: la del usuario inicial del FTP y la del panel web. En la misma carpeta queda el par de claves que cifra y abre la copia de seguridad. El script de instalación crea todo solo la primera vez, cada una en un archivo cuyo nombre dice lo que guarda, y deja en la carpeta un `LEIAME.txt` que explica uno por uno. El servidor FTP lee la suya al arrancar y guarda solamente el hash; el panel recibe **solo el hash** de la suya, nunca la contraseña.

<!-- diagrama: diagramas/secretos-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    deploy@{ shape: console, label: "deploy.sh<br>gera a senha" }
    arquivo@{ shape: doc, label: ".secrets/ftp-usuario-inicial-senha.txt<br>0600, fora do Git" }
    montagem@{ shape: rect, label: "/run/secrets/ftp_usuario_inicial_senha<br>só leitura" }
    entry@{ shape: rect, label: "entrypoint<br>lê e apaga da memória" }
    puredb@{ shape: cyl, label: "PureDB<br>guarda só o hash" }
    fim@{ shape: stadium, label: "senha fora da imagem" }

    deploy --> arquivo --> montagem --> entry --> puredb --> fim
```

<sub>Nivel 1 · Diagrama · [fuente](diagramas/)</sub>

**Secuencia:** `deploy.sh` ➜ `.secrets/ftp-usuario-inicial-senha.txt` ➜ `/run/secrets/ftp_usuario_inicial_senha` (solo lectura) ➜ entrypoint ➜ PureDB (guarda solo el hash) ➜ contraseña fuera de la imagen

---

<details>
<summary>Índice — haga clic para expandir</summary>

[Qué queda en `.secrets/`](#o-que-fica) · [Cambiar la contraseña del usuario inicial](#trocar-a-senha) · [Contraseña del panel](#senha-do-painel) · [Usar una contraseña propia](#senha-propria) · [Instalación con los nombres antiguos](#nomes-antigos) · [Qué más es sensible](#o-que-mais-e-sensivel)

</details>

---

<a name="o-que-fica"></a>

## 📂 Qué queda en `.secrets/`

| Archivo | Quién lo genera | ¿Usted lo completa? | Para qué |
|---|---|---|---|
| `ftp-usuario-inicial-senha.txt` | [`deploy.sh`](../../deploy.sh), en la primera ejecución, si el archivo no existe o está vacío | Solo si quiere una contraseña propia | Contraseña del usuario inicial (`FTP_USER`) |
| `painel-admin-inicial-senha.txt` | [`deploy.sh`](../../deploy.sh), en la primera ejecución | No | Contraseña **inicial** del primer administrador del panel (`PAINEL_ADMIN_USER`), en texto. Queda solo en el host y vale hasta que se cambie en la pestaña Usuarios; una vez cambiada, borre el archivo |
| `painel-admin-inicial-senha-hash.txt` | [`deploy.sh`](../../deploy.sh) y [`scripts/painel-senha.sh`](../../scripts/painel-senha.sh) | No | Hash `scrypt` de esa contraseña inicial. Solo se usa para crear el primer administrador. De los archivos sueltos de la carpeta, el panel ve este y la clave pública de la copia |
| `backup-chave-privada.txt` | [`deploy.sh`](../../deploy.sh), si ninguna de las dos claves existe | No | Clave que **abre** la copia de seguridad. Guarde una copia fuera del servidor: sin ella ninguna copia se restaura. Vea [Copia de seguridad y restauración](backup.md#chave) |
| `backup-chave-publica.txt` | [`deploy.sh`](../../deploy.sh), en cada ejecución, a partir de la privada | No | Clave que **cifra** la copia de seguridad. No abre nada y puede quedar en el servidor. El panel la recibe como secreto montado, solo para lectura, para cifrar la [copia del sistema](panel.md#copia-do-sistema) enviada a S3 |
| `LEIAME.txt` | [`deploy.sh`](../../deploy.sh), en cada ejecución | No | Dice para qué sirve cada archivo de la carpeta. No guarda ningún secreto |
| `destinos/` | [`deploy.sh`](../../deploy.sh) crea la carpeta, vacía; el panel escribe los archivos | No: desde la pestaña Destinos | Secretos de cada S3, de cada remoto del rclone y de cada bot de Telegram, uno por archivo, con el nombre del destino adelante: `s3-chave-de-acesso.txt`, `s3-chave-secreta.txt`, `rclone-remoto.txt`, `telegram-token.txt` y `telegram-conversa.txt` en el primero de cada tipo, y `s3-2-chave-de-acesso.txt`, `rclone-2-remoto.txt`, `telegram-2-token.txt` y así sucesivamente en los siguientes. El archivo del remoto del rclone trae el acceso completo y, en SFTP, la clave del servidor que la prueba guardó. El panel escribe y lee, y ninguno vuelve a la pantalla. Cambiar o eliminar: desde la pestaña [Destinos](panel.md#destinos) |
| `segundo-fator/` | [`deploy.sh`](../../deploy.sh) crea la carpeta, vacía; el panel escribe los archivos | No: desde la pestaña Usuarios | Clave del segundo factor de cada cuenta del panel, una por archivo, guardada en el registro: `<nome>.txt` para el administrador y `ftp.<nome>.txt` para el usuario del FTP. Con ella se generan los códigos de esa cuenta. La lista de quién tiene el factor activado queda en los datos del panel: borrar el archivo aquí no desactiva el factor, y la cuenta deja de entrar hasta que se desactive, por un administrador o desde la terminal: [Segundo factor](panel.md#segundo-fator) |
| `.gitkeep` | ya viene en el repositorio | No | Mantiene la carpeta en el clon |

El nombre de cada archivo sigue el mismo orden: **de quién es** el secreto (`ftp-usuario-inicial`, `painel-admin-inicial`, `backup`) y **qué** está guardado (`senha` en texto, `senha-hash`, `chave-privada` o `chave-publica`).

Ver las contraseñas generadas, para configurar el equipo y para entrar en el panel por primera vez:

```bash
cat .secrets/ftp-usuario-inicial-senha.txt       # usuario inicial del FTP
cat .secrets/painel-admin-inicial-senha.txt    # primer administrador del panel, hasta el primer cambio
```

**Resultado esperado:** en cada comando, una línea con la contraseña, de 48 caracteres.

> ⚠️ Nunca pegue la contraseña en un documento, captura de pantalla, resultado de prueba o mensaje. Donde haga falta mostrar el formato, use `<REDACTED>`.

---

<a name="trocar-a-senha"></a>

## 🔁 Cambiar la contraseña del usuario inicial

Hay dos caminos, y vale siempre el cambio más reciente.

| Camino | Cómo | Hasta cuándo vale |
|---|---|---|
| Desde el panel o desde la terminal | Usuarios ➜ **Cambiar contraseña**, o `./manage-user.sh passwd <usuario>` | Hasta que se modifique el archivo del secreto |
| Por el archivo del secreto | Los tres comandos de abajo | Hasta el próximo cambio, por cualquier camino |

```bash
printf '%s' 'nueva-clave-de-12-o-mas' > .secrets/ftp-usuario-inicial-senha.txt
chmod 600 .secrets/ftp-usuario-inicial-senha.txt
docker compose restart ftp
```

**Resultado esperado:** el contenedor vuelve a `healthy` y el login antiguo pasa a ser rechazado con `530 Login authentication failed`.

El usuario inicial se crea una vez. Eliminado desde el panel o con `./manage-user.sh del`, no vuelve en los arranques siguientes y el archivo del secreto queda sin uso; creado de nuevo con el mismo nombre, vale la contraseña informada en la creación, hasta que se modifique el archivo.

La contraseña cambiada desde el panel o con el `manage-user.sh passwd` sobrevive a los reinicios: el servicio `ftp` solo aplica otra vez la del archivo cuando el **contenido del archivo cambia**. Mientras tanto, el archivo guarda la contraseña anterior, sin uso, y el resumen del `./deploy.sh` dice `senha trocada pelo painel`. Para los demás usuarios, el cambio es desde el panel o con el `manage-user.sh`: vea [Operación](operacion.md#usuarios).

---

<a name="senha-do-painel"></a>

## 🖥️ Contraseña del panel

Cada administrador del panel tiene usuario y contraseña propios. El primero nace en la instalación, con el nombre de `PAINEL_ADMIN_USER` y la contraseña de `.secrets/painel-admin-inicial-senha.txt`. Cambie esa contraseña enseguida después del primer acceso, **desde el panel**, en la pestaña Usuarios, y borre el archivo de la contraseña inicial: [Administradores del panel](panel.md#administradores).

Sin acceso al panel, la contraseña se define desde el host:

```bash
./scripts/painel-senha.sh --gerar                    # contraseña fuerte para el primer administrador, mostrada una sola vez
./scripts/painel-senha.sh                            # o: pregunta la contraseña nueva dos veces, sin mostrarla en pantalla
./scripts/painel-senha.sh --usuario NOME --gerar     # otro administrador; si NOME no existe, se crea
```

**Resultado esperado:** `Administrador admin com a senha trocada; painel reiniciado e sessões abertas encerradas.` Cuando el administrador es el de `PAINEL_ADMIN_USER`, el archivo `painel-admin-inicial-senha.txt` deja de existir.

La contraseña tiene que tener como mínimo 12 caracteres y **no queda guardada en ningún lugar**: el panel guarda solo el hash, en `DATA_DIR/painel/administradores`. Guárdela en su gestor de contraseñas. Uso del panel: [Panel web](panel.md).

---

<a name="senha-propria"></a>

## ✍️ Usar una contraseña propia

Guárdela **antes** del primer deploy, con 12 caracteres como mínimo:

```bash
printf '%s' 'una-clave-fuerte-de-12+-caracteres' > .secrets/ftp-usuario-inicial-senha.txt
chmod 600 .secrets/ftp-usuario-inicial-senha.txt
```

**Resultado esperado:** el `deploy.sh` no genera una contraseña nueva y no muestra el mensaje `Gerada uma senha forte em ...`.

---

<a name="nomes-antigos"></a>

## 🔀 Instalación con los nombres antiguos

Hasta la versión `0.17.0` los archivos tenían otros nombres. El `./deploy.sh` reconoce los antiguos y **solo cambia el nombre**, sin leer, copiar ni modificar el contenido: las contraseñas siguen siendo las mismas.

| Nombre hasta la `0.17.0` | Nombre a partir de la `0.18.0` |
|---|---|
| `ftp_password.txt` | `ftp-usuario-inicial-senha.txt` |
| `painel_password.txt` | `painel-admin-inicial-senha.txt` |
| `painel_password_hash.txt` | `painel-admin-inicial-senha-hash.txt` |

```bash
./deploy.sh
```

**Resultado esperado:** una línea `Convertido: <nome antigo> virou <nome novo>.` por cada archivo que existía, y los tres contenedores `healthy` al final. Viniendo de la `0.17.0`, los contenedores del FTP y del panel se recrean una vez, porque el nombre del secreto dentro de ellos también cambió, y el del nginx sigue igual; viniendo de una versión anterior, los tres se recrean, porque las imágenes cambian. Datos, usuarios y contraseñas quedan como estaban.

Con `./deploy.sh --check-only` nada se modifica: sale solo el aviso `AVISO: esta instalação usa nomes antigos`. Si el archivo antiguo y el nuevo existen al mismo tiempo, vale el nuevo y el script avisa para revisar y borrar el antiguo.

---

<a name="o-que-mais-e-sensivel"></a>

## 🧾 Qué más es sensible

| Ítem | Dónde queda | Protección |
|---|---|---|
| `.env` | raíz de la stack | `0600`, ignorado por Git y por el build |
| Clave privada TLS del FTP | carpeta `DATA_DIR/certs`, archivo `pure-ftpd.pem` | `0600`, fuera del repositorio |
| Clave privada TLS del panel | carpeta `DATA_DIR/painel/tls`, archivo `painel-key.pem` | `0600`, carpeta `0700`, fuera del repositorio |
| Copia de la clave TLS del panel, para el nginx | carpeta `DATA_DIR/nginx/tls`, archivo `painel-key.pem` | `0640`, grupo `10001` (el del nginx), carpeta `0750`; rehecha en cada arranque y montada en el nginx solo para lectura |
| Registro de auditoría del panel | carpeta `DATA_DIR/painel`, archivo `auditoria.log` | `0600`; no guarda contraseña, pero muestra nombres de usuario y direcciones |
| Hash de las contraseñas de los usuarios | carpeta `DATA_DIR/auth`, archivos `pureftpd.passwd` y `pureftpd.pdb` | `0600`, fuera del repositorio |
| Copias de seguridad hechas por el `scripts/backup.sh` | carpeta `BACKUP_DIR` | Cifradas con la clave pública de `.secrets/`, `0600`, carpeta `0700`, fuera del repositorio; contienen el hash de las contraseñas, las claves privadas de los certificados y los archivos de los equipos |

<details>
<summary>Detalle técnico — generación, montaje y descarte</summary>

- **Generación:** `openssl rand -base64 36` (48 caracteres). El script aplica `umask 077`, `chmod 0700` en la carpeta y `chmod 0600` en el archivo, y nunca reescribe un secreto que ya existe.
- **Montaje:** el [`compose.yaml`](../../compose.yaml) declara el secreto `ftp_usuario_inicial_senha` (`SECRETS_DIR/ftp-usuario-inicial-senha.txt`) y lo entrega **solo** al servicio `ftp`, en `/run/secrets/ftp_usuario_inicial_senha`, solo lectura. La carpeta `.secrets/` entera no se monta.
- **Sin contraseña en variable:** el `.env` guarda solo lo que se ajusta. El `deploy.sh` rechaza `FTP_PASSWORD`, `PAINEL_PASSWORD` y `PAINEL_PASSWORD_HASH` en el `.env` y los contenedores rechazan esas variables.
- **Lectura:** el [`ftp/entrypoint.sh`](../../ftp/entrypoint.sh) lee el archivo sin los saltos de línea, valida el mínimo de 12 caracteres y entrega la contraseña al `pure-pw` por el `stdin`. En el primer arranque crea el usuario (`pure-pw useradd`); en los siguientes, reescribe la contraseña (`pure-pw passwd`), porque el `pure-pw usermod` no modifica la contraseña. En los dos casos pasa `-C FTP_MAX_CLIENTS`, que define el costo del hash `argon2id`: [Seguridad](seguridad.md#custo-das-senhas).
- **Cambio desde el panel:** cada vez que aplica el secreto, el entrypoint guarda en `/auth/senha-inicial.aplicada` una huella de él (`sha512-crypt` con sal propia, `0600`), nunca la contraseña. El cambio desde el panel o con el `manage-user.sh passwd` guarda `/auth/senha-inicial.trocada`, solo con el nombre del usuario. En el arranque, con la marca presente y la huella igual a la del secreto, la contraseña del registro se mantiene y el log dice `mantida a senha trocada pelo painel`; con el secreto distinto, este se aplica y la marca sale. Los dos archivos entran en la copia de seguridad, con el registro.
- **Creado una vez:** al crear el usuario inicial, el entrypoint guarda `/auth/usuario-inicial.criado` (`0600`), solo con su nombre. Con la marca presente y el usuario fuera del registro, no se recrea, y el log dice `removido pelo administrador; não é recriado`. Una instalación anterior a la `0.44.0` recibe la marca en el primer arranque, con el usuario que ya existe. La marca entra en la copia de seguridad, con el registro.
- **Descarte:** antes del `exec` del `pure-ftpd`, el entrypoint hace `unset` de la variable interna de la contraseña.
- **Panel:** el hash es `scrypt` (N=2^15, r=8, p=1, sal aleatoria de 16 bytes), calculado dentro de la imagen del panel, en un contenedor descartable sin red. El secreto `painel_admin_inicial_senha_hash` llega **solo** al servicio `painel`, en `/run/secrets/painel_admin_inicial_senha_hash`, solo lectura, y solo se lee en el arranque en que todavía no existe ningún administrador. La contraseña actual de cada administrador queda como hash en `DATA_DIR/painel/administradores` (`0600`, del `root`), fuera de `.secrets/`. El `painel-admin-inicial-senha.txt` nunca se monta en un contenedor.
- **Clave de la copia de seguridad:** par `age` (X25519), generado por `age-keygen` dentro de la imagen del FTP, en un contenedor descartable sin red; nada se instala en el host. El `deploy.sh` solo crea el par cuando **ninguno** de los dos archivos existe, nunca reescribe la privada y, en cada ejecución, rehace la pública a partir de ella. Solo con la pública, el servidor hace la copia y no restaura. Ninguna de las dos se monta en los servicios: la pública va al contenedor de la copia, y la privada, solo al de la restauración, solo lectura.
- **Git:** el [`.gitignore`](../../.gitignore) ignora `.env` y todo lo que está en `.secrets/`, manteniendo solo el `.gitkeep`.
- **`LEIAME.txt`:** reescrito por el `deploy.sh` en cada ejecución, con modo `0600`. Trae solo el nombre y la función de cada archivo; nunca se monta en un contenedor.
- **Imagen:** el [`.dockerignore`](../../.dockerignore) deja `.env` y `.secrets` fuera del contexto de build.

</details>

---

⬅️ [Seguridad](seguridad.md) · 🏠 [Documentación](README.md) · ➡️ [Scripts](scripts.md)
