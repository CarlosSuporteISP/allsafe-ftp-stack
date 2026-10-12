# 🧰 Operación — allsafe-ftp-stack

[![English](https://img.shields.io/badge/English-6e7781?style=for-the-badge)](../en/operation.md)
[![Português (Brasil)](https://img.shields.io/badge/Portugu%C3%AAs_(Brasil)-6e7781?style=for-the-badge)](../pt-BR/operacao.md)
[![Español](https://img.shields.io/badge/Espa%C3%B1ol-0969da?style=for-the-badge)](operacion.md)

↩ [README del proyecto](../../README.es.md) · [Índice de la documentación](README.md)

## 💡 En pocas palabras

Esta guía reúne las tareas del día a día: crear la cuenta de un equipo nuevo, cambiar una contraseña, instalar el certificado definitivo, guardar una copia de los archivos, leer los registros y actualizar el servidor. Las cuentas también pueden administrarse desde el navegador, en el [panel web](panel.md); aquí está el camino por la línea de comandos. Todos los comandos se ejecutan en la carpeta raíz de la stack.

<!-- diagrama: diagramas/usuarios-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    usuario@{ shape: person, label: "Usuario" }
    manage@{ shape: console, label: "manage-user.sh<br>add, passwd, pasta, del, list" }
    interno@{ shape: console, label: "allsafe-ftp-user<br>dentro del contenedor" }
    puredb@{ shape: cyl, label: "PureDB<br>cuentas virtuales" }
    pasta@{ shape: lin-cyl, label: "/data<br>carpeta del usuario" }
    fim@{ shape: stadium, label: "cuenta lista" }

    usuario --> manage --> interno --> puredb --> pasta --> fim
```

<sub>Nivel 1 · Diagrama · [fuente](diagramas/)</sub>

**Secuencia:** Usuario ➜ `manage-user.sh` ➜ `allsafe-ftp-user` ➜ PureDB ➜ `/data` ➜ cuenta lista

---

<details>
<summary>Índice — haga clic para expandir</summary>

[Usuarios](#usuarios) · [Certificado real de producción](#certificado-real-de-producao) · [Copia de seguridad de los datos](#backup-dos-volumes) · [Logs](#logs) · [Actualización de la imagen](#atualizacao-da-imagem) · [↩️ Volver de versión](#voltar-de-versao) · [Inspección rápida](#inspecao-rapida) · [Detener y eliminar](#parar-remover)

</details>

---

<a name="usuarios"></a>

## 👤 Usuarios

Gestión desde el host con [`manage-user.sh`](../../manage-user.sh). El [panel](panel.md#usuarios) hace las mismas operaciones, con las mismas reglas:

```bash
./manage-user.sh add cliente01      # crea el usuario y /data/cliente01 (pide la contraseña)
./manage-user.sh add olt01 clientes/olt-01   # crea el usuario en la carpeta elegida, /data/clientes/olt-01
./manage-user.sh passwd cliente01   # cambia la contraseña (pide la nueva)
./manage-user.sh pasta cliente01 clientes/olt-02   # cambia la carpeta; los archivos de la anterior siguen en ella
./manage-user.sh limites cliente01 sessoes=2 download=500 horario=0800-1800   # guarda límites solo de él
./manage-user.sh limites cliente01  # muestra sus límites
./manage-user.sh limites olt01 tentativas=3 minutos=30   # bloqueo por intento solo de él: 3 contraseñas incorrectas, 30 minutos
./manage-user.sh retencao olt01 ultimos=30   # limpieza automática: mantiene solo los 30 archivos más recientes de cada carpeta suya
./manage-user.sh retencao cliente01 dias=15  # borra el archivo que lleva más de 15 días en el servidor
./manage-user.sh retencao olt01     # muestra su regla (retencao olt01 ultimos= dias= la desactiva)
./manage-user.sh bloqueios          # lista a quién el FTP está rechazando por demasiadas contraseñas incorrectas
./manage-user.sh desbloquear olt01  # quita los bloqueos del usuario (o de una sola dirección: desbloquear olt01 10.0.0.5)
./manage-user.sh enderecos          # lista las direcciones y los prefijos bloqueados en el FTP y en el panel
./manage-user.sh endereco-liberar 203.0.113.7        # libera una dirección o un prefijo bloqueado
./manage-user.sh endereco-bloquear 203.0.113.7 365   # bloquea una dirección, o cambia el plazo de una ya bloqueada
./manage-user.sh endereco-bloquear 198.51.100.0/24 30   # bloquea un prefijo entero, IPv4 o IPv6
./manage-user.sh list               # lista los usuarios del PureDB
./manage-user.sh del cliente01      # elimina el usuario y MANTIENE su carpeta
./manage-user.sh tls-dispensar olt-antiga   # deja al usuario entrar sin TLS (equipo que no habla TLS)
./manage-user.sh tls-exigir olt-antiga      # vuelve a exigirle el TLS
./manage-user.sh tls-lista                  # lista quién está dispensado del TLS
```

**Resultado esperado:** después del `add`, el usuario aparece en el `list` y ya logra entrar por FTPS; después del `pasta`, la respuesta es `Pasta do usuario <nome>: /data/<pasta>. Os arquivos de /data/<anterior> continuam la.`; después del `del`, desaparece del `list` y la carpeta sigue en el volumen.

Reglas:

- Nombre del usuario: `^[a-z_][a-z0-9_-]{0,31}$`.
- Contraseña: mínimo de **12 caracteres** (rechazada por debajo de eso).
- Carpeta: sin el tercer parámetro, es `/data/<usuario>`. Con él, queda siempre dentro de `/data` (`DATA_DIR/dados` en el host), con hasta 4 niveles separados por `/`; cada nivel tiene letras, números, `_`, `-` y punto, no empieza con punto y llega hasta 64 caracteres. La carpeta se crea si no existe. Una carpeta que pasa por un enlace simbólico o por un archivo se rechaza, y no se crea nada.
- `add` de un nombre existente responde `Usuario ja existe`. Para cambiar la carpeta de quien ya existe, use `pasta`, con las mismas reglas: vale en la entrada siguiente, no cambia la contraseña y no mueve ni borra archivos. Usuario que no existe: `Usuario nao existe: <nome>`.
- `limites` acepta uno o más pares `chave=valor`, y solo toca las claves informadas: `sessoes` (sesiones al mismo tiempo en el FTP), `download` y `envio` (KB por segundo, de 1 a 10.000.000), `horario` (`HHMM-HHMM`, en el huso del `TZ`, pudiendo pasar de la medianoche), `baixar` (descargas al mismo tiempo desde el panel, de 1 a 8), `tentativas` (contraseñas incorrectas en el FTP hasta el bloqueo, de 0 a 100; `0`: nunca se bloquea) y `minutos` (tiempo del bloqueo, de 1 a 1440). Un valor vacío (`download=`) quita el límite; sin ningún par, muestra los que tiene el usuario. Vale en su entrada siguiente en el FTP. Lo que hace cada límite está en [Panel web](panel.md#limites).
- `bloqueios` lista los bloqueos por intento en vigor, uno por línea, con el usuario, la dirección, las contraseñas incorrectas, el inicio y el fin; con un nombre, solo los de él. Sin ninguno, responde `Nenhum bloqueio em vigor.` `desbloquear <usuario>` quita todos los bloqueos del usuario, y con la dirección al final, solo el de esa dirección. Vale en la entrada siguiente. Cambiar `tentativas` o `minutos`, cambiar la contraseña y eliminar al usuario también quitan sus bloqueos: [Seguridad](seguridad.md#bloqueio-por-tentativa).
- `enderecos` lista las direcciones y los prefijos con bloqueo por dirección, IPv4 e IPv6, uno por línea, con quién bloqueó, los errores, el inicio y el fin; sin ninguno, responde `Nenhum endereco bloqueado.` `endereco-liberar <endereco ou prefixo>` quita el bloqueo, y es la salida para el administrador que quedó con la propia dirección bloqueada. `endereco-bloquear <endereco ou prefixo> [dias]` bloquea una dirección, o una red entera, en el FTP y en el panel o, en lo que ya está bloqueado, cambia solo el plazo; sin los días, vale `BLOQUEIO_ENDERECO_DIAS`. Un prefijo solo lo bloquea el administrador, por aquí o desde la pestaña Bloqueos: la stack nunca bloquea una red por sí sola. Todo vale en la solicitud siguiente: [Seguridad](seguridad.md#bloqueio-por-endereco).
- `del` **no borra archivos** y responde con la carpeta que quedó. Para quitar la carpeta junto con el usuario, use el panel: Usuarios ➜ **Eliminar**, con la casilla de borrar la carpeta, en [Panel web](panel.md#usuarios). Después del `del`, la carpeta que quedó se borra en la pestaña Archivos.
- `tls-dispensar` y `tls-exigir` valen en instantes, sin reiniciar el contenedor y sin desconectar a quien está conectado, y solo para un usuario que existe (`Usuario nao existe: <nome>`). La dispensa solo tiene efecto con `FTP_TLS_EXCECOES=sim` (el valor por defecto), `FTP_TLS_MODE=2` y sin `REDE_PERMITIR_IP_PUBLICO=sim`; fuera de eso, queda guardada. El `del` quita al usuario de la lista.

> ⚠️ **Carpeta compartida:** dos usuarios con la misma carpeta, o con una dentro de la otra, leen, escriben y borran los archivos uno del otro. El `add` acepta y avisa, una línea `Aviso:` por cada usuario que pasa a compartir la carpeta. Para que un equipo no alcance la copia de seguridad de otro, dé a cada uno su propia carpeta.

> ⚠️ **Dispensa del TLS:** el usuario dispensado envía contraseña y archivo en texto plano. Solo para equipo antiguo que no habla TLS, en red interna aislada: [Seguridad](seguridad.md#tls-por-usuario).

> ⚠️ El usuario definido en `FTP_USER` se crea una vez, en el primer arranque, con la contraseña de `.secrets/ftp-usuario-inicial-senha.txt`. Su contraseña y su carpeta se cambian como las de los demás; la contraseña cambiada vale hasta que se modifique el archivo del secreto: [Secretos](secretos.md#trocar-a-senha). Se elimina como los otros, desde el panel o con `del`, y no vuelve en los arranques siguientes; para tenerlo de nuevo, cree un usuario con el mismo nombre. Para renombrarlo, cree el nuevo con `add`, migre los datos y elimine el antiguo.

<details>
<summary>Detalle técnico — dónde se guarda el cambio</summary>

El `manage-user.sh` encapsula el [`ftp/usuario.sh`](../../ftp/usuario.sh), que se ejecuta dentro del contenedor como `allsafe-ftp-user`. Los cambios se guardan en `/auth/pureftpd.passwd` y se recompilan en `/auth/pureftpd.pdb` (carpeta `DATA_DIR/auth` del host). No hace falta reiniciar el servicio: el `pure-ftpd` consulta la base en cada login. El panel llama al mismo script, y un bloqueo de archivo (`/auth/.lock`) impide dos modificaciones al mismo tiempo. La dispensa del TLS queda en `/auth/sem-tls.lista`, un nombre por línea, leída por el servidor en cada entrada. Los límites de sesiones, de tasa y de horario quedan en la propia línea del usuario en el registro; el de descargas desde el panel y los del bloqueo por intento, en `/auth/limites.lista`. Cada bloqueo en vigor es un archivo en `/auth/bloqueios`.

</details>

---

<a name="certificado-real-de-producao"></a>

## 🔏 Certificado real de producción

El certificado inicial es **autofirmado**, generado en el primer arranque. Para instalar uno real:

```bash
# 1. Concatene clave y cadena completa en un único PEM (clave primero)
cat privkey.pem fullchain.pem > pure-ftpd.pem
chmod 600 pure-ftpd.pem

# 2. Copie al volumen, en el lugar del autofirmado
docker compose cp pure-ftpd.pem ftp:/etc/ssl/private/pure-ftpd.pem

# 3. Reinicie el servicio
docker compose restart ftp
```

**Resultado esperado:** el cliente conecta sin aviso de certificado y el contenedor vuelve a `healthy`.

- El archivo debe contener **clave, certificado e intermedios** en el mismo PEM, `0600`.
- El [`ftp/entrypoint.sh`](../../ftp/entrypoint.sh) solo genera el autofirmado **si el archivo no existe**: el suyo no será sobrescrito.
- Renovación: repita los pasos 1 a 3 (por ejemplo, por `cron` en el host, tomándolo de su cliente ACME).
- Borre la copia local del `pure-ftpd.pem` después de instalar: contiene la clave privada.

---

<a name="backup-dos-volumes"></a>

## ♻️ Copia de seguridad de los datos

Un comando guarda los archivos de los equipos, los usuarios, los certificados y la auditoría del panel en un archivo de `BACKUP_DIR`; otro devuelve la stack al estado de una copia:

```bash
./scripts/backup.sh                                                  # guarda la copia cifrada, con la stack en marcha
./scripts/backup.sh --listar                                         # muestra las copias que existen
./scripts/restaurar.sh allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz.age  # vuelve al estado de la copia
```

**Resultado esperado:** `Cópia gravada: <BACKUP_DIR>/allsafe-ftp-stack-AAAAMMDD-HHMMSS.tar.gz.age (<tamanho>, cifrada)` en el primer comando y, en la restauración, `Restaurado e no ar (healthy).`

Qué entra en la copia, cómo guardar la clave que la abre, cómo deshacer una restauración, cómo restaurar en otro servidor y cómo programar la copia están en [Copia de seguridad y restauración](backup.md).

Para tomar **un solo archivo**, enviado por un equipo, use la pestaña Archivos del panel: [Archivos y descarga](panel.md#arquivos). El dueño de los archivos toma los suyos del mismo modo, entrando en el panel con el usuario y la contraseña del FTP: [Usuario del FTP en el panel](panel.md#usuario-ftp). En el host, el mismo archivo está en la carpeta del usuario, dentro de `DATA_DIR/dados`: la pestaña Usuarios muestra la ruta de cada uno.

> ⚠️ La copia contiene el hash de las contraseñas y las claves privadas de los certificados, y por eso sale cifrada: llévela también fuera del servidor. Solo `.secrets/backup-chave-privada.txt` la abre: guarde esa clave en un gestor de contraseñas, separada de las copias, junto con el `.env` y los otros archivos de `.secrets/`, que tampoco entran en la copia.

---

<a name="migracao"></a>

## 🚚 Migrar de los volúmenes con nombre (instalación anterior a la 0.3.0)

Hasta la versión `0.1.x` los datos quedaban en volúmenes con nombre de Docker (`allsafe-ftp-data`, `allsafe-ftp-auth`, `allsafe-ftp-certs`). A partir de la `0.3.0` quedan en `DATA_DIR`. La migración **copia**, no mueve: los volúmenes antiguos siguen intactos hasta que usted decida borrarlos.

```bash
docker compose down                       # 1. detiene la stack antigua (sin -v)
git pull                                  # 2. trae la versión nueva
# 3. en el .env: agregue las claves nuevas del .env.example (DATA_DIR, BACKUP_DIR, TEMP_DIR, SECRETS_DIR,
#    STACK_NAME, FTP_CONTAINER_NAME, FTP_NETWORK_NAME) y borre FTP_PASSWORD y FTP_PASSWORD_FILE.
#    Si la contraseña estaba en el .env, guárdela en .secrets/ftp-usuario-inicial-senha.txt (chmod 600).
DATA_DIR="$(sed -n 's/^DATA_DIR=//p' .env | tail -n 1)"   # el DATA_DIR de su .env
mkdir -p "$DATA_DIR"/{dados,auth,certs}
docker build -q -t allsafe-ftp:local .    # 4. imagen nueva, usada para copiar
for par in allsafe-ftp-data:dados allsafe-ftp-auth:auth allsafe-ftp-certs:certs; do
  docker run --rm --network none -v "${par%%:*}":/origem:ro -v "$DATA_DIR/${par##*:}":/destino \
    --entrypoint cp allsafe-ftp:local -a /origem/. /destino/
done
./deploy.sh                               # 5. arranca con las carpetas nuevas
```

**Resultado esperado:** contenedor `healthy`, los usuarios entran con la misma contraseña y los archivos aparecen en la carpeta de cada usuario, dentro de `DATA_DIR/dados`.

Solo después de verificar, y por decisión suya, borre los volúmenes antiguos: `docker volume rm allsafe-ftp-data allsafe-ftp-auth allsafe-ftp-certs`.

---

<a name="logs"></a>

## 📜 Logs

```bash
docker compose logs -f ftp          # sigue el log (entradas, transferencias y mensajes del entrypoint)
docker compose logs --since 1h ftp  # última hora
docker compose logs -f painel       # arranque del panel y avisos del servidor web
docker compose logs -f nginx        # arranque del nginx y las solicitudes que rechazó
```

**Resultado esperado:** la línea `FTP pronto em 2121/tcp; ...` del arranque y, después, una línea `vigia:` por entrada y por transferencia; en el panel, la línea `Painel pronto no soquete /nginx/painel.sock, atrás do nginx; ...`; en el nginx, `nginx pronto em 8443/tcp (HTTPS), à frente do painel; ...`.

El nginx registra solo lo que él mismo rechaza, una línea por solicitud, en el formato `ip método caminho código` (ejemplo: `10.99.0.7 GET /entrar 403`). Con `FTP_TLS_MODE` en `0` o `1`, el log del FTP trae en cada arranque el `AVISO` de FTP sin cifrado: [Seguridad](seguridad.md#ftp-sem-tls). Con `FTP_TLS_EXCECOES=sim`, trae el `AVISO` con la cantidad de usuarios dispensados y una línea `porteiro: entrada sem TLS recusada: usuario=<nome> origem=<ip>` por cada entrada sin TLS de quien no fue dispensado: [Seguridad](seguridad.md#tls-por-usuario).

El vigía del servicio `ftp` registra cada entrada en el FTP, con el usuario y la dirección: `vigia: entrada:` en la que pasó, `vigia: entrada recusada:` en la contraseña incorrecta, con el conteo, y `vigia: entrada bloqueada:` cuando la dirección llega al límite. Registra también cada archivo enviado (`vigia: envio:`), descargado (`vigia: download:`), renombrado (`vigia: renomeado:`) y borrado (`vigia: apagado:`) por el FTP, con el tamaño en los dos primeros. Las líneas están en [Scripts](scripts.md#vigia). Para ver solo ellas:

```bash
docker compose logs ftp | grep 'vigia:'
```

**Resultado esperado:** una línea por entrada, por rechazo y por transferencia, sin contraseña; quien está bloqueado ahora sale en `./manage-user.sh bloqueios`. Para ver solo lo que un usuario envió y descargó: `docker compose logs ftp | grep -E 'vigia: (envio|download): usuario=<nome> '`.

Lo que se hizo desde el panel (entradas, salidas, usuarios creados, modificados y eliminados, archivos descargados) queda en el `auditoria.log`, visible en la pestaña Log: vea [Panel web](panel.md#auditoria).

Rotación por Docker: `max-size: 10m`, `max-file: 3` (vea el [`compose.yaml`](../../compose.yaml)).

---

<a name="atualizacao-da-imagem"></a>

## ⬆️ Actualización de la imagen

```bash
./deploy.sh --atualizar            # rehace las tres imágenes sin caché y recrea los contenedores (datos preservados)
./scripts/validate.sh --runtime    # verifica los tres servicios 'running' y 'healthy'
```

**Resultado esperado:** `Validacao FTP concluida.` y los usuarios y archivos intactos. Las sesiones abiertas en el panel se cierran.

> El `--atualizar` reinstala los paquetes con la versión actual del repositorio Debian. El perfil en uso está en el `.env` y sigue vigente.

<details>
<summary>Detalle técnico — base fijada por digest</summary>

La base en el [`Dockerfile`](../../Dockerfile) está **fijada por digest**: un `docker compose build --pull` no cambia la base por sí solo. Para tomar una base nueva, actualice el digest del `FROM` y ejecute `./deploy.sh --atualizar`. Mientras el `Dockerfile` no cambie, un `docker compose build` común reutiliza la capa de instalación de los paquetes; el `--atualizar` usa `build --no-cache`, que rehace esa capa y reinstala los paquetes en la versión actual del repositorio Debian. Las tres imágenes (FTP, panel y nginx) salen de la misma base, `debian:trixie-slim` (Debian 13).

</details>

<a name="voltar-de-versao"></a>

<details>
<summary>Detalle técnico — volver a la versión anterior</summary>

Los datos, los usuarios, las contraseñas y los certificados quedan en `DATA_DIR` y en `.secrets/`, fuera del código: volver de versión es cambiar los archivos del proyecto y arrancar de nuevo. Elimine **antes**, todavía con los archivos de la versión actual, porque solo ella conoce todos los contenedores que creó:

```bash
./deploy.sh --remover      # 1. versión actual: baja los tres contenedores y la red; los datos quedan
git checkout v0.6.0        # 2. vuelve los archivos del proyecto a la etiqueta de la versión anterior
./deploy.sh                # 3. arranca la versión anterior con los mismos datos
```

**Resultado esperado:** los contenedores de la versión anterior en `healthy`, con los mismos usuarios, contraseñas y certificados.

> ⚠️ `FTP_TLS_MODE=0` solo existe a partir de la `0.7.0`: antes del paso 3, vuelva la variable a `1`, `2` o `3`. Las claves nuevas del `.env` (las `NGINX_*`) son ignoradas por la versión anterior y pueden quedar.

</details>

---

<a name="inspecao-rapida"></a>

## 🔍 Inspección rápida

```bash
docker compose ps                                   # estado y puertos
docker inspect --format '{{.State.Health.Status}}' allsafe-ftp
docker inspect --format '{{.State.Health.Status}}' allsafe-ftp-painel
docker inspect --format '{{.State.Health.Status}}' allsafe-ftp-nginx
./manage-user.sh list                               # usuarios del PureDB
docker compose exec ftp pure-pw show transfer -f /auth/pureftpd.passwd
```

**Resultado esperado:** los tres contenedores `running` y `healthy`, la lista de usuarios y los datos del usuario `transfer` (carpeta, uid y gid; la contraseña aparece solo como hash).

---

<a name="parar-remover"></a>

## ⏹️ Detener y eliminar

```bash
docker compose stop                       # detiene sin eliminar
./deploy.sh --remover                     # elimina los contenedores y la red; los datos siguen en DATA_DIR
./deploy.sh --remover --apagar-dados      # elimina y borra las carpetas de DATA_DIR (pide escribir "apagar")
```

**Resultado esperado:** `docker compose ps` vacío. Las carpetas `dados/`, `auth/`, `certs/`, `painel/` y `nginx/` de `DATA_DIR` y los secretos siguen en el host; borrar los datos es una decisión aparte, solo con `--apagar-dados`.

> ⚠️ Los datos quedan en carpetas del host: ni el `docker compose down -v` los borra. El `--apagar-dados` **no tiene vuelta atrás**: haga la [copia de seguridad](#backup-dos-volumes) antes. Sin terminal (en un script), solo se ejecuta con `--sim`. Los secretos y el `.env` no se borran.

---

⬅️ [Scripts](scripts.md) · 🏠 [Documentación](README.md) · ➡️ [Copia de seguridad y restauración](backup.md)
