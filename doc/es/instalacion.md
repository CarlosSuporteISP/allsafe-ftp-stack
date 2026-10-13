# 🚀 Instalación — allsafe-ftp-stack

[![English](https://img.shields.io/badge/English-6e7781?style=for-the-badge)](../en/installation.md)
[![Português (Brasil)](https://img.shields.io/badge/Portugu%C3%AAs_(Brasil)-6e7781?style=for-the-badge)](../pt-BR/instalacao.md)
[![Español](https://img.shields.io/badge/Espa%C3%B1ol-0969da?style=for-the-badge)](instalacion.md)

↩ [README del proyecto](../../README.es.md) · [Índice de la documentación](README.md)

## 💡 En pocas palabras

Usted ejecuta un comando y el servidor FTP arranca solo, ya con contraseña fuerte y conexión cifrada, junto con el panel web para administrar los usuarios y el nginx, que queda delante del panel. Nace atendiendo solo al propio servidor; para atender a la red interna, usted informa la IP privada en el archivo de configuración y ejecuta el mismo comando de nuevo. Al final, un segundo script verifica que todo esté en marcha. Lleva pocos minutos y se puede deshacer sin perder los archivos.

<!-- diagrama: diagramas/instalacion-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    usuario@{ shape: person, label: "Usuario" }
    deploy@{ shape: console, label: "deploy.sh<br>crea el .env, genera las contraseñas y levanta" }
    stack@{ shape: rect, label: "Docker Compose<br>FTP, panel y nginx" }
    valida@{ shape: console, label: "validate.sh<br>verifica el arranque" }
    fim@{ shape: stadium, label: "FTP y panel listos" }

    usuario --> deploy --> stack --> valida --> fim
```

<sub>Nivel 1 · Diagrama · [fuente](diagramas/)</sub>

**Secuencia:** Usuario ➜ `deploy.sh` (crea el `.env`, genera las contraseñas y levanta) ➜ Docker Compose (FTP, panel y nginx) ➜ `validate.sh` ➜ FTP y panel listos

---

<details>
<summary>Índice — haga clic para expandir</summary>

[Requisitos previos](#pre-requisitos) · [1️⃣ Configuración base](#1-configuracao-base) · [2️⃣ Contraseña del usuario inicial](#2-senha-do-usuario-inicial) · [3️⃣ Levantar la stack](#3-subir-a-stack) · [4️⃣ Validar](#4-validar) · [Cómo deshacer](#como-desfazer) · [Próximos pasos](#proximos-passos)

</details>

---

<a name="pre-requisitos"></a>

## ✅ Requisitos previos

| Ítem | Detalle |
|---|---|
| Docker Engine con Docker Compose v2 o más nuevo | `docker compose version` debe responder |
| CPU y memoria para el perfil | El `small` pide 1 CPU y 256 MB; el `extended`, 16 CPU y 4 GB. El `deploy.sh` verifica y rechaza el perfil mayor que el servidor: [Perfiles](perfiles.md#o-servidor-aguenta) |
| Una IP dedicada para el FTP | No comparta la IP con otros servicios; el modo pasivo abre de 50 a 1600 puertos, según el perfil |
| Firewall en el host | Libere `21/tcp` y el rango pasivo del perfil (`30000-30049/tcp` en el `small`) **solo** para las redes de gestión de los equipos, y el puerto del panel (`8443/tcp`) **solo** para quien administra |
| Red privada | Por defecto la stack solo acepta IP interna: vea [Seguridad](seguridad.md#rede-privada). La dirección pública depende de una opción con alerta: [IP pública](seguridad.md#ip-publico) |
| Carpeta para los datos | El valor por defecto es `/srv/allsafe-ftp-stack`, con `data`, `backups` y `tmp` dentro. Quien instala sin ser root crea la carpeta una vez: `sudo install -d -o "$USER" /srv/allsafe-ftp-stack`. Otro lugar: `DATA_DIR`, `BACKUP_DIR` y `TEMP_DIR` en [Configuración](configuracion.md#pastas-e-nomes) |
| Reloj sincronizado | El certificado TLS depende de fecha y hora correctas (la stack `allsafe-ntp-nts-stack` se encarga de eso) |

---

<a name="1-configuracao-base"></a>

## 1️⃣ Configuración base

Este paso es **opcional la primera vez**: sin `.env`, el [`deploy.sh`](../../deploy.sh) crea uno a partir del ejemplo, con todo en `127.0.0.1` (solo el propio servidor accede), y sigue. Para arrancar ya atendiendo a la red interna, cree y ajuste el archivo antes:

```bash
cp .env.example .env
chmod 600 .env
```

**Resultado esperado:** el archivo `.env` pasa a existir en la raíz de la stack.

Cada variable está explicada en [Configuración](configuracion.md). Los campos que **usted necesita** revisar:

| Variable | Cambie a |
|---|---|
| `FTP_BIND_IP` | la IP **privada** dedicada del servidor (con `127.0.0.1` solo el propio servidor alcanza el FTP) |
| `FTP_PASSIVE_IP` | la IP que ve el cliente; normalmente igual a `FTP_BIND_IP`. También tiene que ser privada |
| `PAINEL_BIND_IP` | la IP **privada** por donde se abrirá el panel; con `127.0.0.1` solo abre en el propio servidor |
| `FTP_CERT_CN` | el hostname (ejemplo: `ftp.exemplo.com.br`) o la IP que va en el certificado |
| `FTP_USER` | nombre del usuario inicial (por defecto `transfer`). Regla: `^[a-z_][a-z0-9_-]{0,31}$` |

> ¿Saltó este paso? Ajuste el `.env` después y ejecute `./deploy.sh` de nuevo: aplica otra vez la configuración sin cambiar contraseña ni borrar datos.

---

<a name="2-senha-do-usuario-inicial"></a>

## 2️⃣ Contraseña del usuario inicial

Nada que hacer aquí la primera vez: el [`deploy.sh`](../../deploy.sh) **genera una contraseña fuerte** en `.secrets/ftp-usuario-inicial-senha.txt`, con permiso `0600`, si el archivo está vacío o ausente. Anótela para configurar el cliente FTP:

```bash
cat .secrets/ftp-usuario-inicial-senha.txt      # después del primer deploy
```

**Resultado esperado:** una línea con la contraseña generada, de cerca de 48 caracteres.

Para usar una contraseña propia, guárdela **antes** de ejecutar el `deploy.sh`:

```bash
printf '%s' 'una-clave-fuerte-de-12+-caracteres' > .secrets/ftp-usuario-inicial-senha.txt
chmod 600 .secrets/ftp-usuario-inicial-senha.txt
```

<details>
<summary>Detalle técnico — reglas de la contraseña</summary>

- La contraseña se genera con `openssl rand -base64 36`; el `openssl` se exige en el host.
- Mínimo de **12 caracteres**: el [`ftp/entrypoint.sh`](../../ftp/entrypoint.sh) rechaza contraseñas menores.
- El archivo llega al contenedor como el secreto `/run/secrets/ftp_usuario_inicial_senha`, solo lectura; el servicio no ve el resto de `.secrets/`.
- Git ignora los archivos `.txt` de `.secrets/`. Vea [Secretos](secretos.md).
- Contraseña en el `.env` **no se acepta**: el `deploy.sh` rechaza un `.env` con `FTP_PASSWORD` completado y el contenedor rechaza la variable.

</details>

---

<a name="3-subir-a-stack"></a>

## 3️⃣ Levantar la stack

```bash
./deploy.sh                  # otro porte: ./deploy.sh --size medium (o large, xlarge, extended)
```

**Resultado esperado:** el comando solo termina con los tres contenedores `healthy` y cierra con el resumen:

```text
Pronto: FTP, painel e nginx no ar (healthy), perfil 'small'.
FTP:    127.0.0.1:21, TLS explícito obrigatório no login, modo passivo 30000-30049
        usuário 'transfer', senha no arquivo ./.secrets/ftp-usuario-inicial-senha.txt
Painel: https://127.0.0.1:8443  (pelo nginx; certificado autoassinado; rede privada, atrás de firewall)
        usuário 'admin', senha inicial no arquivo ./.secrets/painel-admin-inicial-senha.txt
        (valem até serem trocados na aba Usuários do painel)
Segredos: ./.secrets/LEIAME.txt diz para que serve cada arquivo.
Remover: ./deploy.sh --remover  (os dados ficam em <DATA_DIR>)
Contato de segurança: não publicado. Para publicar, preencha SEGURANCA_CONTATO_EMAIL em .env
        e rode ./deploy.sh de novo (política do projeto: SECURITY.md).
```

El resumen dice **dónde** está cada contraseña y nunca la muestra. El `LEIAME.txt` de la carpeta `.secrets/` explica para qué sirve cada archivo de ella. La primera vez aparecen también `Gerada uma senha forte em .secrets/ftp-usuario-inicial-senha.txt (0600). Guarde-a para o cliente FTP.`, `Gerada uma senha forte para o painel em .secrets/painel-admin-inicial-senha.txt (0600).` y `Gerada a chave da cópia de segurança em .secrets/backup-chave-privada.txt (0600).`, con el recordatorio de guardar esa clave fuera del servidor: [Copia de seguridad y restauración](backup.md#chave).

Abra la dirección del panel en el navegador y entre con el usuario `admin` (el de `PAINEL_ADMIN_USER`) y la contraseña de `.secrets/painel-admin-inicial-senha.txt`. El primer acceso, el aviso de certificado y el cambio del usuario y de la contraseña están en [Panel web](panel.md#abrir).

Qué perfil usar: [Perfiles](perfiles.md). En los perfiles `xlarge` y `extended` el arranque lleva minutos, porque Docker publica los puertos pasivos uno por uno: [tiempo de arranque](perfiles.md#tempo-de-subida).

> ⚠️ **¿Equipo antiguo que no habla TLS?** El valor por defecto exige TLS y rechaza ese equipo. Para aceptar sin TLS solo a su usuario, un administrador lo dispensa en el panel, al crear el usuario o en Usuarios ➜ **Dispensar del TLS**; para aceptar a todos, existe la `FTP_TLS_MODE=0` (o `1`). Por cualquier camino, quien entra sin TLS deja contraseña y archivo legibles para quien esté en la misma red. Lea las condiciones antes: [Seguridad](seguridad.md#ftp-sem-tls).

<details>
<summary>Detalle técnico — qué hacen el <code>deploy.sh</code> y el entrypoint</summary>

El [`deploy.sh`](../../deploy.sh), en este orden:

1. verifica los requisitos: `docker`, el plugin `docker compose` y el servicio de Docker respondiendo;
2. verifica que el servidor tenga las CPU y la memoria que pide el perfil; si no las tiene, se detiene sin modificar nada;
3. crea el `.env` a partir del ejemplo (`0600`) si no existe, y sigue; en una instalación con los nombres antiguos, cambia `FTP_PUBLIC_IP` por `FTP_PASSIVE_IP` en el `.env`, después de copiarlo a `BACKUP_DIR`, y da el nombre nuevo a los archivos de `.secrets/`;
4. rechaza contraseña en el `.env`, dirección o red fuera de IP privada (salvo con `REDE_PERMITIR_IP_PUBLICO=sim`) y `FTP_TLS_MODE` fuera de `0` a `3`;
5. con `--size`, guarda en el `.env` los valores de `profiles/<perfil>.env` y el nombre del perfil en `FTP_PROFILE`; sin `--size`, el `.env` queda como está;
6. verifica que el puerto del FTP, el del panel y el rango pasivo estén libres en el host (los que la propia stack ya publica no cuentan); un puerto ocupado detiene el comando con `ERRO: porta já em uso por outro programa: ...`;
7. crea las carpetas `dados/`, `auth/`, `certs/`, `painel/` y `nginx/` en `DATA_DIR` (sin permiso para crear, se detiene con `ERRO: não foi possível criar as pastas em ...` y el comando que crea la carpeta superior), genera la contraseña en `.secrets/ftp-usuario-inicial-senha.txt` si el archivo está vacío y escribe el `.secrets/LEIAME.txt`;
8. ejecuta `docker compose --env-file .env config --quiet`, que falla temprano si la configuración es inválida;
9. `docker compose build`, que construye las tres imágenes (con `--atualizar`, `build --no-cache`);
10. genera la contraseña inicial del panel y guarda su hash, si todavía no hay hash, y crea el par de claves de la copia de seguridad, si ninguna de las dos existe (con la privada presente, solo rehace la pública);
11. `docker compose up -d --wait`, que solo vuelve con los tres contenedores `healthy` (límite de 180 s más un cuarto de segundo por puerto pasivo);
12. `docker compose ps`, el resumen con las direcciones, el modo de TLS y el lugar de cada contraseña y, en los modos `0` y `1`, el aviso de FTP sin cifrado.

Con `--check-only`, el script se detiene después del paso 4 y de un `config --quiet`, sin crear `.env`, carpeta ni contraseña, con `OK: perfil '<perfil>', rede privada, recursos do servidor e compose validados; nada foi alterado.`

En el **primer** arranque el [`ftp/entrypoint.sh`](../../ftp/entrypoint.sh):

- crea `/data/$FTP_USER` con dueño `ftpdata`;
- guarda el usuario en el PureDB (`/auth/pureftpd.pdb`);
- genera un **certificado autofirmado** RSA 3072, válido por 825 días, en `/etc/ssl/private/pure-ftpd.pem`, con SAN de acuerdo con `FTP_CERT_CN` (IP o DNS);
- ejecuta el `pure-ftpd` escuchando en `:2121`.

Con el FTP `healthy`, el panel inicia: genera su propio certificado autofirmado (EC P-256, 825 días) en `DATA_DIR/painel/tls`, entrega una copia al nginx y abre el socket Unix en `DATA_DIR/nginx`. Con el panel `healthy`, el nginx inicia y escucha en `:8443`.

El modelo completo del arranque está en [Arquitectura](arquitectura.md#subida).

</details>

---

<a name="4-validar"></a>

## 4️⃣ Validar

```bash
./scripts/validate.sh            # sintaxis de los scripts y Compose de todos los perfiles, sin levantar nada
./scripts/validate.sh --runtime  # exige los tres servicios 'running' y 'healthy' y el usuario en el PureDB
```

**Resultado esperado:** `painel OK: <n> módulos Python` (si el host tiene `python3`), una línea `compose OK com <perfil>.env` para cada uno de los cinco perfiles y, al final, `Validacao FTP concluida.`

Prueba manual con un cliente (FTP **explícito** sobre TLS, modo pasivo):

```bash
# el lftp usa FTPS explícito por defecto
lftp -u "$FTP_USER" -e 'set ssl:verify-certificate no; ls; bye' ftp://SU_IP
```

**Resultado esperado:** el `lftp` pide la contraseña y lista la carpeta del usuario, vacía la primera vez.

> ⚠️ Como el certificado inicial es autofirmado, el cliente va a reclamar por la validación hasta que usted instale un certificado real. Vea [Operación](operacion.md#certificado-real-de-producao).

---

<a name="como-desfazer"></a>

## ♻️ Cómo deshacer

```bash
./deploy.sh --remover           # elimina los contenedores y la red; datos, secretos y .env quedan
```

**Resultado esperado:** `Removidos os containers e a rede. Os dados continuam em <DATA_DIR>.` y `docker compose ps` ya no lista el `allsafe-ftp`, el `allsafe-ftp-painel` ni el `allsafe-ftp-nginx`. Un nuevo `./deploy.sh` levanta todo de vuelta con los mismos datos y las mismas contraseñas.

Los archivos de los usuarios, el PureDB y los certificados quedan en `DATA_DIR`, en el host: la eliminación no borra nada (ni un `docker compose down -v` lo borraría). Para borrar del todo, use `./deploy.sh --remover --apagar-dados`: pide escribir `apagar` y elimina las carpetas `dados/`, `auth/`, `certs/`, `painel/` y `nginx/` de `DATA_DIR`; los secretos y el `.env` siguen.

---

<a name="proximos-passos"></a>

## ⏭️ Próximos pasos

- Cambiar la contraseña inicial del panel: [Secretos](secretos.md#senha-do-painel).
- Crear más usuarios: desde el [panel](panel.md#usuarios) o por [Operación](operacion.md#usuarios).
- Poner en producción: [Seguridad](seguridad.md#o-que-endurecer-antes-de-producao) y el certificado real.
- Monitoreo: la stack `allsafe-zabbix-isp-stack` acompaña al contenedor.

---

⬅️ [README del proyecto](../../README.es.md) · 🏠 [Documentación](README.md) · ➡️ [Configuración](configuracion.md)
