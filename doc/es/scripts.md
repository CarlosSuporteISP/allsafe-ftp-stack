# ⌨️ Scripts — allsafe-ftp-stack

[![English](https://img.shields.io/badge/English-6e7781?style=for-the-badge)](../en/scripts.md)
[![Português (Brasil)](https://img.shields.io/badge/Portugu%C3%AAs_(Brasil)-6e7781?style=for-the-badge)](../pt-BR/scripts.md)
[![Español](https://img.shields.io/badge/Espa%C3%B1ol-0969da?style=for-the-badge)](scripts.md)

↩ [README del proyecto](../../README.es.md) · [Índice de la documentación](README.md)

## 💡 En pocas palabras

Los scripts de la stack son de dos tipos. Los que usted ejecuta en el host levantan el servidor, cuidan de los usuarios, recuperan el acceso al panel, hacen y restauran la copia de seguridad y verifican si todo está bien. Los demás quedan dentro de los contenedores del FTP, del panel y de nginx y se llaman por sí solos; usted no los ejecuta directamente.

<!-- diagrama: diagramas/scripts-diagrama.mmd -->
```mermaid
%%{init: {"theme": "dark"}}%%
flowchart LR
    usuario@{ shape: person, label: "Usuário" }
    host@{ shape: console, label: "deploy.sh, manage-user.sh<br>e validate.sh, no host" }
    compose@{ shape: rect, label: "Docker Compose" }
    interno@{ shape: console, label: "entrypoints e allsafe-ftp-user<br>dentro dos containers" }
    ftp@{ shape: rect, label: "Pure-FTPd<br>allsafe-ftp" }
    fim@{ shape: stadium, label: "serviço operando" }

    usuario --> host --> compose --> interno --> ftp --> fim
```

<sub>Nivel 1 · Diagrama · [fuente](diagramas/)</sub>

**Secuencia:** Usuario ➜ scripts del host (`deploy.sh`, `manage-user.sh`, `validate.sh`) ➜ Docker Compose ➜ entrypoints y `allsafe-ftp-user` (en los contenedores) ➜ Pure-FTPd (`allsafe-ftp`) ➜ servicio operando

---

<details>
<summary>Índice — haga clic para expandir</summary>

[Visión general](#visao-geral) · [`deploy.sh`](#deploy) · [`manage-user.sh`](#manage-user) · [`scripts/painel-senha.sh`](#painel-senha) · [`scripts/backup.sh`](#backup) · [`scripts/restaurar.sh`](#restaurar) · [`scripts/validate.sh`](#validate) · [`scripts/gerar-marca.sh`](#gerar-marca) · [`tests/testar.sh`](#testar) · [`ftp/entrypoint.sh`](#entrypoint) · [`ftp/saude.sh`](#ftp-saude) · [`ftp/porteiro.pl`](#porteiro) · [`ftp/vigia.pl`](#vigia) · [`painel/entrypoint.sh`](#painel-entrypoint) · [`nginx/entrypoint.sh`](#nginx-entrypoint) · [`nginx/saude.sh`](#nginx-saude) · [`ftp/usuario.sh`](#ftp-user) · [Scripts de apoyo](#apoio)

</details>

---

<a name="visao-geral"></a>

## 📋 Visión general

| Script | Dónde se ejecuta | Para qué sirve |
|---|---|---|
| [`deploy.sh`](../../deploy.sh) | host | Instala, aplica de nuevo, actualiza o elimina la stack en un comando, sin preguntas |
| [`manage-user.sh`](../../manage-user.sh) | host | Acceso directo para crear, cambiar contraseña, cambiar carpeta, cambiar el perfil, ajustar límites, desbloquear, eliminar y listar usuarios FTP, para dispensar a un usuario del TLS y para listar, bloquear y liberar direcciones |
| [`scripts/painel-senha.sh`](../../scripts/painel-senha.sh) | host | Recupera el acceso al panel: define la contraseña de un administrador o crea el administrador, guardando solo el hash |
| [`scripts/backup.sh`](../../scripts/backup.sh) | host | Guarda la copia de seguridad cifrada de `dados/`, `auth/`, `certs/` y `painel/` en `BACKUP_DIR` |
| [`scripts/restaurar.sh`](../../scripts/restaurar.sh) | host | Devuelve la stack al estado de una copia, guardando antes el estado actual |
| [`scripts/validate.sh`](../../scripts/validate.sh) | host | Verificación de sintaxis, de la marca, de la licencia, del Compose de todos los perfiles y, opcionalmente, de los tres servicios en marcha |
| [`scripts/gerar-marca.sh`](../../scripts/gerar-marca.sh) | computadora de quien cambia el logo | Genera los seis archivos de logo e ícono del panel a partir de las dos artes de origen |
| [`tests/testar.sh`](../../tests/testar.sh) | host | Batería de pruebas funcional, de seguridad y de red, en una instancia de prueba que el propio script crea y elimina |
| [`ftp/entrypoint.sh`](../../ftp/entrypoint.sh) | contenedor | Provisiona el usuario inicial y el certificado, levanta el vigía, el `pure-authd` y el `pure-ftpd` y cierra el contenedor si uno de ellos sale |
| [`ftp/saude.sh`](../../ftp/saude.sh) | contenedor | Healthcheck: abre el puerto de control y espera el saludo del servidor |
| [`ftp/porteiro.pl`](../../ftp/porteiro.pl) | contenedor | Decide en cada entrada, antes de la verificación de la contraseña, si puede seguir: rechaza la dirección, IPv4 o IPv6, que está bloqueada o dentro de un prefijo bloqueado, al usuario bloqueado por contraseñas incorrectas y, con el TLS por usuario en vigor, la sesión sin TLS de quien no fue dispensado |
| [`ftp/vigia.pl`](../../ftp/vigia.pl) | contenedor | Cuenta las contraseñas incorrectas de cada dirección para cada usuario y los errores de cada dirección, pone el conteo en cero en la entrada correcta, guarda el bloqueo que el portero aplica, entrega al servidor el archivo recibido en una carpeta con perfil Envío o Lectura, lleva a la carpeta del usuario el archivo recibido de un perfil Solo envío y publica la red y los recursos del contenedor para la pestaña Servidor del panel |
| [`painel/entrypoint.sh`](../../painel/entrypoint.sh) | contenedor del panel | Verifica la red privada, genera el certificado del panel, entrega su copia a nginx y ejecuta el panel |
| [`nginx/entrypoint.sh`](../../nginx/entrypoint.sh) | contenedor de nginx | Verifica la red privada, genera la configuración de nginx y lo ejecuta, sin root |
| [`nginx/saude.sh`](../../nginx/saude.sh) | contenedor de nginx | Healthcheck: pide `/saude` al panel pasando por nginx |
| [`ftp/endereco.pl`](../../ftp/endereco.pl) | contenedor | Lectura y escritura única de la dirección de origen, IPv4 o IPv6, y de los prefijos, usada por el portero, por el vigía y por el `allsafe-ftp-user`: es ella la que da el nombre del archivo de cada bloqueo |
| [`ftp/usuario.sh`](../../ftp/usuario.sh) | contenedores del FTP y del panel | Gestión de usuarios en el PureDB, de los perfiles, de los límites, de los bloqueos por intento y por dirección y de la lista de quien entra sin TLS, llamada por el `manage-user.sh` y por el panel |
| [`scripts/rede-privada.sh`](../../scripts/rede-privada.sh) | host y contenedores | Funciones que verifican si una IP o una red es privada y que tratan la opción de IP pública; cargado por los otros scripts |
| [`scripts/ambiente.sh`](../../scripts/ambiente.sh) | host | Función que lee una clave del `.env` sin ejecutar el archivo; cargado por los otros scripts |

La carpeta [`scripts/`](../../scripts/) tiene lo que se ejecuta fuera de los contenedores: en el servidor y, en el caso del `gerar-marca.sh`, en la computadora de quien cambia el logo. Lo que se ejecuta en contenedor queda en la carpeta del servicio ([`ftp/`](../../ftp/), [`painel/`](../../painel/) y [`nginx/`](../../nginx/)) y se copia a la imagen por el [`Dockerfile`](../../Dockerfile). La batería de pruebas queda en [`tests/`](../../tests/).

---

<a name="deploy"></a>

## 🚀 `deploy.sh`

```bash
./deploy.sh [--size small|medium|large|xlarge|extended] [--atualizar] [--check-only]
./deploy.sh --remover [--apagar-dados [--sim]]
```

| Parámetro | Efecto |
|---|---|
| sin opción | Instala o aplica de nuevo: crea el `.env`, las carpetas y las contraseñas que falten, levanta los contenedores y espera a que queden `healthy` |
| `--size` | Guarda en el `.env` los límites de `profiles/<perfil>.env` y el nombre en `FTP_PROFILE`, después de verificar que el servidor soporta el perfil. Sin la opción, el `.env` queda como está |
| `--atualizar` | Reconstruye las tres imágenes sin caché, con los paquetes actuales de Debian, y crea de nuevo los contenedores |
| `--check-only` | Solo valida el perfil, las direcciones y las redes, los recursos del servidor y el Compose; no crea ni levanta nada |
| `--remover` | Derriba los contenedores y la red; datos, secretos, `.env` e imágenes quedan |
| `--apagar-dados` | Con `--remover`: borra también `dados/`, `auth/`, `certs/`, `painel/` y `nginx/` de `DATA_DIR`, después de pedir que se escriba `apagar` |
| `--sim` | Con `--apagar-dados`: dispensa la confirmación (obligatorio cuando no hay terminal) |
| `-h`, `--help` | Muestra el uso |

**Resultado esperado:** el comando solo termina con `allsafe-ftp`, `allsafe-ftp-painel` y `allsafe-ftp-nginx` en `healthy` y cierra con `Pronto: FTP, painel e nginx no ar (healthy), perfil '<perfil>'.`, las direcciones del FTP y del panel, el modo de TLS del FTP y el archivo donde está cada contraseña (la contraseña en sí nunca aparece). Con `FTP_TLS_MODE` en `0` o `1`, lo último en la pantalla es el `AVISO` de FTP sin cifrado: [Seguridad](seguridad.md#ftp-sem-tls). Con `FTP_TLS_EXCECOES=sim`, la línea del FTP termina en `com exceção por usuário` y el `AVISO` es el de la excepción: [Seguridad](seguridad.md#tls-por-usuario). Con `--remover`: `Removidos os containers e a rede. Os dados continuam em <DATA_DIR>.` Con `--check-only`: `OK: perfil '<perfil>', rede privada, recursos do servidor e compose validados; nada foi alterado.` Con `REDE_PERMITIR_IP_PUBLICO=sim`, el resumen trae `endereço público aceito` en lugar de `rede privada` y lo último en la pantalla es el `ALERTA` de dirección pública: [Seguridad](seguridad.md#ip-publico).

<details>
<summary>Detalle técnico — comportamiento y códigos de salida</summary>

- **No hace preguntas.** La única confirmación es la del `--apagar-dados`, dispensada con `--sim`.
- **Requisitos verificados antes de actuar:** `docker`, el plugin `docker compose`, el servicio de Docker respondiendo y los puertos libres (el del FTP, el del panel y el rango pasivo, en la dirección de bind). Los puertos que la propia stack ya publica no cuentan. Falló: `ERRO: ...` y código `1`, sin levantar nada.
- **Recursos del servidor verificados antes de guardar:** si el servidor tiene menos CPU que `FTP_CPU_LIMIT` o menos memoria que `FTP_MEMORY_LIMIT`, se detiene con `ERRO: o perfil '<perfil>' pede ... e este servidor tem ...` y código `1`, sin crear ni reescribir el `.env` y sin tocar los contenedores: [Perfiles](perfiles.md#o-servidor-aguenta).
- **`FTP_TLS_MODE` verificado antes de actuar:** un valor fuera de `0` a `3` se detiene con `ERRO: FTP_TLS_MODE deve ser 0 (sem TLS), 1 (opcional), 2 (obrigatório no login) ou 3 (obrigatório no login e nos dados)` y código `1`. En `0` y `1` el deploy sigue y avisa al final.
- **`FTP_TLS_EXCECOES` verificada antes de actuar:** un valor fuera de `nao` y de `sim` se detiene con `ERRO: FTP_TLS_EXCECOES deve ser 'sim' ou 'nao'` y código `1`. Con `sim`, el valor por defecto, la opción solo vale con `FTP_TLS_MODE=2` y sin `REDE_PERMITIR_IP_PUBLICO=sim`: fuera de eso el deploy sigue y dice, también en el `--check-only`, `TLS por usuário sem efeito: <motivo>. Ninguém é dispensado do TLS.` En vigor y con un usuario ya dispensado en el panel, el deploy termina con el `AVISO: TLS por usuário: <n> usuário(s) dispensado(s) na aba Usuários do painel entram SEM TLS`.
- En la primera ejecución sin `.env`, copia el [`.env.example`](../../.env.example), aplica `0600`, avisa `Criado .env a partir do .env.example: tudo em 127.0.0.1, só este servidor acessa.` y **sigue**. Con `--check-only` no se crea nada: la validación usa el `.env.example`.
- **Idempotente:** ejecutado de nuevo sin cambios, no crea de nuevo el contenedor, no cambia la contraseña y no reescribe el `.env`.
- **Convierte los nombres antiguos, la variable:** en el `.env` de una instalación anterior a la `0.17.0`, cambia `FTP_PUBLIC_IP` por `FTP_PASSIVE_IP`, en el mismo punto del archivo y con el mismo valor, después de copiar el `.env` a `BACKUP_DIR/<data>-antes-da-migracao-de-nomes/env` (`0600`), y avisa `Convertido: FTP_PUBLIC_IP virou FTP_PASSIVE_IP`. El cambio del nombre, por sí solo, no crea de nuevo el contenedor; en la actualización desde una versión anterior, los tres se crean de nuevo una vez, porque las imágenes cambian, y usuarios, contraseñas y archivos quedan como estaban. Con `--check-only`, solo avisa `AVISO: esta instalação usa nomes antigos` y no modifica nada.
- **Convierte los nombres antiguos, los secretos:** en una instalación hecha hasta la `0.17.0`, da el nombre nuevo a los tres archivos de `.secrets/` con `mv`, sin leer ni copiar el contenido, y avisa `Convertido: <antigo> virou <novo>.` para cada uno. Si el antiguo y el nuevo existen, vale el nuevo y sale un `AVISO`. Con `--check-only`, solo avisa. Tabla de los nombres: [Secretos](secretos.md#nomes-antigos).
- Si `.secrets/ftp-usuario-inicial-senha.txt` está vacío o ausente, genera una contraseña fuerte (`0600`): vea [Secretos](secretos.md).
- Guarda el `.secrets/LEIAME.txt` (`0600`), que dice para qué sirve cada archivo de la carpeta y no guarda secretos, y cierra el resumen con `Segredos: .../LEIAME.txt diz para que serve cada arquivo.`
- Dice, al final del resumen, si el contacto de seguridad está publicado: `Contato de segurança: <e-mail>, publicado em /.well-known/security.txt do painel.` o, con `SEGURANCA_CONTATO_EMAIL` vacía, `Contato de segurança: não publicado.`, con lo que hay que rellenar. No bloquea la instalación.
- Rechaza `FTP_PASSWORD`, `PAINEL_PASSWORD` y `PAINEL_PASSWORD_HASH` en el `.env` y, por defecto, cualquier `FTP_BIND_IP`, `FTP_PASSIVE_IP`, `PAINEL_BIND_IP`, `PAINEL_REDES_PERMITIDAS` o `PAINEL_CERT_CN` (en forma de IP) fuera de red privada.
- **Opción de IP pública:** `REDE_PERMITIR_IP_PUBLICO` distinta de `nao` y de `sim` se detiene con `FALHA: REDE_PERMITIR_IP_PUBLICO deve ser 'nao' ou 'sim'` y código `1`. Con `sim`, acepta IPv4 pública de servidor y red de `/8` a `/32`, sigue rechazando `0.0.0.0` y una red más ancha, exige `FTP_TLS_MODE` en `2` o `3` (`ERRO: REDE_PERMITIR_IP_PUBLICO=sim exige FTP_TLS_MODE=2 ou 3`) y muestra el `ALERTA` al final, también en el `--check-only`.
- **Panel por proxy o túnel:** `PAINEL_PROXY_CONFIAVEL` vacía no cambia nada. Rellenada, cada dirección tiene que ser IPv4, una a una, privada (o pública con la opción de IP pública) y estar dentro de `PAINEL_REDES_PERMITIDAS`, hasta 8; fuera de eso, se detiene con `FALHA: PAINEL_PROXY_CONFIAVEL: …` y código `1`. Aceptada, el `--check-only` y el final del deploy cierran con `ALERTA: PAINEL_PROXY_CONFIAVEL=…: o painel está publicado por proxy ou túnel, por opção de quem instalou.` Vea [Seguridad](seguridad.md#painel-por-proxy).
- Si `.secrets/painel-admin-inicial-senha-hash.txt` no existe, genera la contraseña inicial del panel en `.secrets/painel-admin-inicial-senha.txt` (`0600`) y guarda su hash, llamando al `scripts/painel-senha.sh --inicial` después de construir la imagen.
- Verifica la `PAINEL_ACESSO_USUARIOS_FTP` antes de actuar: un valor distinto de `sim` y de `nao` se detiene con `ERRO: PAINEL_ACESSO_USUARIOS_FTP deve ser 'sim' ou 'nao'; ...` y código `1`.
- Verifica la `PAINEL_AVISO_EXPOSICAO` antes de actuar: un valor distinto de `sim` y de `nao` se detiene con `ERRO: PAINEL_AVISO_EXPOSICAO deve ser 'sim' ou 'nao'`.
- Verifica el `PAINEL_ADMIN_USER` antes de actuar: un nombre fuera de la regla se detiene con `ERRO: PAINEL_ADMIN_USER inválido em .env: ...` y código `1`. En el resumen, muestra el usuario y el archivo de la contraseña inicial mientras ese archivo exista; después, `usuário e senha: os definidos na aba Usuários ou com ./scripts/painel-senha.sh`.
- Verifica el `SEGURANCA_CONTATO_EMAIL` antes de actuar: rellenado con algo que no es una sola dirección de correo, se detiene con `ERRO: SEGURANCA_CONTATO_EMAIL inválido em .env: um endereço de e-mail só, como seguranca@exemplo.com.br, ou vazio.` y código `1`. Vacío se acepta: el `security.txt` no se publica.
- Opción desconocida o perfil inexistente: mensaje `Opção inválida: ...` o `ERRO: perfil inexistente: ...` y código `64`.
- El Compose se llama siempre solo con `--env-file .env`. El perfil no es un segundo archivo en el arranque: `--size` guarda sus valores en el `.env`, por eso un `docker compose up -d` directo mantiene los mismos límites.
- Combinación inválida (`--remover` con `--size`, `--apagar-dados` sin `--remover`, `--sim` sin `--apagar-dados`): `Opção inválida: ...`, el uso y código `64`.
- `--apagar-dados` borra las carpetas por un contenedor descartable sin red (los archivos pertenecen al usuario del contenedor, no al del host) y solo acepta `DATA_DIR` con al menos dos niveles de carpeta.
- Construye las tres imágenes con `docker compose build` (`build --no-cache` con `--atualizar`), levanta con `docker compose up -d --wait` y termina mostrando el `docker compose ps` y el resumen. El plazo de la espera es de 180 s más un cuarto de segundo por puerto pasivo (192 s en el `small`, 580 s en el `extended`), porque Docker publica los puertos uno a uno; por encima de 400 puertos, avisa `Publicando <n> portas passivas: a subida pode levar alguns minutos.` Si algún contenedor no queda `healthy` en el plazo: `ERRO: os containers não ficaram healthy. Veja o motivo com: docker compose logs --tail 50 ftp painel nginx`.

</details>

---

<a name="manage-user"></a>

## 👤 `manage-user.sh`

```bash
./manage-user.sh list                 # lista los usuarios del PureDB
./manage-user.sh add backup-olt       # pide la contraseña (mínimo de 12 caracteres) sin eco
./manage-user.sh add olt01 clientes/olt-01   # lo mismo, con la carpeta elegida dentro de /data
./manage-user.sh add coletor clientes/olt-01 envio   # lo mismo, con el perfil: completo (por defecto), envio, soenvio o leitura
./manage-user.sh perfil backup-olt    # muestra el perfil del usuario
./manage-user.sh perfil backup-olt leitura   # cambia el perfil; vale en la próxima entrada del usuario en el FTP
./manage-user.sh passwd backup-olt    # cambia la contraseña
./manage-user.sh pasta backup-olt clientes/olt-02   # cambia la carpeta; los archivos de la anterior siguen en ella
./manage-user.sh limites backup-olt sessoes=2 download=500 horario=0800-1800   # guarda límites solo del usuario
./manage-user.sh limites backup-olt   # muestra los límites del usuario
./manage-user.sh limites backup-olt tentativas=3 minutos=30   # contraseñas incorrectas hasta el bloqueo y minutos de bloqueo, solo del usuario
./manage-user.sh retencao backup-olt ultimos=30 dias=90   # limpieza automática de la carpeta del usuario, aplicada por el panel
./manage-user.sh retencao backup-olt  # muestra la regla del usuario (ultimos= dias= desactiva)
./manage-user.sh bloqueios            # lista los bloqueos por intento en vigor (o solo los de un usuario)
./manage-user.sh desbloquear backup-olt   # quita los bloqueos del usuario (o solo el de un origen)
./manage-user.sh enderecos            # lista las direcciones y los prefijos bloqueados en el FTP y en el panel
./manage-user.sh endereco-bloquear 203.0.113.7 365   # bloquea la dirección, o cambia el plazo de una ya bloqueada; sin los días, el plazo de la stack
./manage-user.sh endereco-bloquear 2001:db8::7       # lo mismo para una dirección IPv6
./manage-user.sh endereco-bloquear 198.51.100.0/24 30   # bloquea el prefijo entero, IPv4 o IPv6
./manage-user.sh endereco-liberar 203.0.113.7        # libera la dirección o el prefijo: vale en la próxima solicitud
./manage-user.sh limites backup-olt enviar=1         # permite que el usuario envíe archivos por el panel (enviar= lo quita)
./manage-user.sh del backup-olt       # elimina el usuario (los archivos quedan en /data)
./manage-user.sh tls-dispensar olt-antiga   # deja al usuario entrar sin TLS (equipo que no habla TLS)
./manage-user.sh tls-exigir olt-antiga      # vuelve a exigir el TLS del usuario
./manage-user.sh tls-lista                  # lista los usuarios dispensados del TLS
```

**Resultado esperado:** `add` y `passwd` terminan sin error y el usuario aparece en el `list`; `pasta` responde `Pasta do usuario <nome>: /data/<pasta>. Os arquivos de /data/<anterior> continuam la.`; `del` responde `Usuario removido; os dados em /data/<pasta> foram preservados.`, con la carpeta real del usuario. El `add` con una carpeta que otro usuario ya alcanza termina sin error y muestra una línea `Aviso:` por usuario. `tls-dispensar` responde `Usuario <nome> dispensado do TLS: vale na proxima entrada, com FTP_TLS_EXCECOES=sim.` y `tls-exigir`, `Usuario <nome> volta a ser obrigado a usar TLS: vale na proxima entrada.`; `tls-lista` muestra un nombre por línea, o nada. `limites` con al menos un par responde `Limites do usuario <nome> gravados: valem na proxima entrada no FTP.`; sin ningún par, muestra una línea por límite (`sessoes=`, `download=`, `envio=`, `horario=`, `baixar=`, `tentativas=` y `minutos=`), vacía en lo que el usuario no tiene. `bloqueios` muestra una línea por bloqueo, `usuario=<nome> origem=<ip> senhas_erradas=<n> desde=<data hora> ate=<data hora>`, o `Nenhum bloqueio em vigor.`; `desbloquear` responde `Usuario <nome> desbloqueado (<n> endereco(s)): vale na proxima entrada no FTP.`, o `Usuario <nome> nao tem bloqueio.` `enderecos` muestra una línea por [dirección o prefijo bloqueado](seguridad.md#bloqueio-por-endereco), `origem=<ip ou rede/tamanho> por=<ftp|painel|manual> erros=<n> desde=<data hora> ate=<data hora>`, o `Nenhum endereco bloqueado.`; `endereco-bloquear` responde `Endereco <ip> bloqueado: <n> dia(s) a partir de agora, no FTP e no painel.`, o `Prazo do endereco <ip> alterado: <n> dia(s) a partir de agora, no FTP e no painel.` cuando ya estaba bloqueada, y, para un prefijo, `Prefixo <rede/tamanho> bloqueado: …` y `Prazo do prefixo <rede/tamanho> alterado: …`; `endereco-liberar` responde `Endereco <ip> liberado: vale no proximo pedido.`, o `Endereco <ip> nao esta bloqueado.`, con `Prefixo` en lugar de `Endereco` cuando es un prefijo

El perfil dice lo que el usuario hace en la carpeta: `completo` envía, descarga, renombra y borra; `envio` envía y descarga, sin borrar ni modificar lo que ya llegó; `soenvio` solo envía, sin listar ni descargar nada; `leitura` solo lista y descarga. En el `add`, viene después de la carpeta. `perfil` con el nombre del perfil responde `Perfil do usuario <nome>: <perfil>. Vale na proxima entrada no FTP.`; un valor fuera de los cuatro se detiene con `Perfil invalido: use completo, envio, soenvio ou leitura` y código `1`. Lo que cada perfil alcanza y los límites del Envío y del Solo envío están en [Panel web](panel.md#perfis).

La contraseña se lee de la terminal y se envía por el `stdin` al contenedor: no aparece en la línea de comando ni en el historial. El script opera la instalación del `.env` de esta carpeta; para operar otra, apunte a su archivo: `ENV_FILE=<arquivo> ./manage-user.sh list`. Reglas y casos de uso en [Operación](operacion.md#usuarios).

---

<a name="painel-senha"></a>

## 🔑 `scripts/painel-senha.sh`

Recupera el acceso al panel desde el host. En el día a día, usuario y contraseña se cambian en el propio panel, en la pestaña Usuarios.

```bash
./scripts/painel-senha.sh                           # pregunta la contraseña nueva dos veces, sin eco
./scripts/painel-senha.sh --gerar                   # crea una contraseña fuerte y la muestra una sola vez
./scripts/painel-senha.sh --usuario NOME --gerar    # otro administrador; si NOME no existe, se crea
```

**Resultado esperado:** `Administrador admin com a senha trocada; painel reiniciado e sessões abertas encerradas.` Para un nombre nuevo, `Administrador NOME criado; ...`.

Sin `--usuario`, el administrador es el de `PAINEL_ADMIN_USER`. La contraseña tiene que tener como mínimo 12 caracteres y solo se guarda el hash. Cuándo usarlo: [Panel web](panel.md#senha).

<details>
<summary>Detalle técnico — cómo se calcula y se guarda el hash</summary>

- Lee `SECRETS_DIR`, `DATA_DIR`, `PAINEL_IMAGE` y `PAINEL_ADMIN_USER` del `.env` (o del archivo en `ENV_FILE`), sin ejecutar el archivo.
- La contraseña también puede venir por la entrada estándar: `./scripts/painel-senha.sh < arquivo`.
- El hash `scrypt` se calcula **dentro de la imagen del panel**, en un contenedor descartable sin red, con la raíz de solo lectura y sin capabilities (`docker run --rm -i --network none --read-only --cap-drop ALL`). El host no necesita Python.
- Quien guarda el archivo de administradores es el panel: el script entrega el hash por la entrada estándar a `servidor.py --administrador NOME`, en el contenedor que está en marcha (`docker compose exec`) o, con el panel detenido, en un contenedor de un solo uso, sin los otros servicios (`docker compose run --rm --no-deps`). La modificación queda en la auditoría como `admin_definido_no_host`.
- Con el panel en marcha, reinicia el servicio `painel` (cierra todas las sesiones y pone en cero el bloqueo por intentos). Con el panel detenido, cierra con `...; vale na próxima subida do painel.`
- Cuando el administrador es el de `PAINEL_ADMIN_USER`, reescribe también el hash de `.secrets/painel-admin-inicial-senha-hash.txt`, por encima del mismo archivo, y borra el `.secrets/painel-admin-inicial-senha.txt`. Para otro administrador, la carpeta `.secrets/` no se toca.
- `--inicial` es de uso del `deploy.sh`: guarda solo el hash de la contraseña inicial, antes del primer arranque, no reinicia nada y mantiene el `painel-admin-inicial-senha.txt`.
- Nombre fuera de la regla: `ERRO: nome de administrador inválido: ...`, código `1`. Opción desconocida: código `64`. Falta del `.env`, de la imagen o de la instalación: `ERRO: ... rode ./deploy.sh primeiro`, código `1`.

</details>

---

<a name="backup"></a>

## ♻️ `scripts/backup.sh`

```bash
./scripts/backup.sh                    # guarda la copia cifrada de dados/, auth/, certs/ y painel/ en BACKUP_DIR
./scripts/backup.sh --rotulo <texto>   # lo mismo, con el texto en el nombre del archivo
./scripts/backup.sh --listar           # muestra las copias que existen
```

**Resultado esperado:** `Cópia gravada: <BACKUP_DIR>/<STACK_NAME>-AAAAMMDD-HHMMSS.tar.gz.age (<tamanho>, cifrada)`, el recordatorio de que el `.env` y los secretos quedan fuera de la copia, el de que solo la clave privada la abre y el comando para restaurarla.

La stack puede seguir en marcha. La copia sale cifrada con la clave pública de `SECRETS_DIR/backup-chave-publica.txt`, con modo `0600` y con la suma `.sha256` al lado; la lectura y el cifrado los hace un contenedor sin red, con `DATA_DIR` solo para lectura. Uso, contenido de la copia y códigos de salida: [Copia de seguridad y restauración](backup.md#fazer).

---

<a name="restaurar"></a>

## 🔁 `scripts/restaurar.sh`

```bash
./scripts/restaurar.sh <cópia>          # pide que se escriba 'restaurar'
./scripts/restaurar.sh <cópia> --sim    # sin pregunta (obligatorio cuando no hay terminal)
./scripts/restaurar.sh --listar         # muestra las copias que existen
```

**Resultado esperado:** `Restaurado e no ar (healthy).` y, en la última línea, el comando para deshacer.

Verifica la copia antes de modificar cualquier cosa, abriéndola con la clave de `SECRETS_DIR/backup-chave-privada.txt`, detiene la stack, guarda el estado actual en un archivo con `antes-da-restauracao` en el nombre, cambia el contenido y levanta de nuevo. `<cópia>` es el nombre de un archivo de `BACKUP_DIR` o una ruta; la copia sin cifrado, hecha antes de la `0.48.0`, todavía se acepta, con aviso. Pasos, rechazos y códigos de salida: [Copia de seguridad y restauración](backup.md#restaurar).

---

<a name="validate"></a>

## 🧪 `scripts/validate.sh`

```bash
./scripts/validate.sh            # sintaxis de los scripts, .env.example comentado, rutas, marca, política de seguridad, licencia y compose config de todos los perfiles
./scripts/validate.sh --runtime  # también exige los tres servicios running y healthy y el usuario en el PureDB
```

**Resultado esperado:** `painel OK: <n> módulos Python`, `idioma OK: <n> textos do painel com tradução em inglês e em espanhol, <n> mensagens do comando de usuários`, `.env.example OK: <n> variáveis, todas comentadas e no guia de configuração, nos dois idiomas`, `caminhos OK: nenhum arquivo do repositório cita pasta pessoal`, `marca OK: 6 arquivos em web/marca/`, `política de segurança OK: SECURITY.md aponta para SEGURANCA_CONTATO_EMAIL, sem endereço fixo`, `licença OK: LICENSE (Apache-2.0), NOTICE, MARCA.md e a linha SPDX em <n> arquivos de código`, `compose OK com <perfil>.env` para cada perfil y, al final, `Validacao FTP concluida.` Con `--runtime`, también `servico ftp: running, healthy`, lo mismo para `painel` y `nginx`, y `usuario inicial '<usuário>' presente no PureDB`. Cualquier falla termina con código distinto de cero.

<details>
<summary>Detalle técnico — qué verifica cada modo</summary>

| Modo | Verifica |
|---|---|
| sin parámetro | `bash -n` en `deploy.sh`, `manage-user.sh` y en los scripts de `scripts/`, `ftp/`, `painel/`, `nginx/` y `tests/`; si el host tiene `python3`, la sintaxis de cada módulo de `painel/` y que todo nombre usado en cada uno está definido o importado en él, sin importar ni escribir nada; que cada texto de las pantallas tiene traducción en el catálogo del inglés ([`painel/idioma_en.py`](../../painel/idioma_en.py)) y en el del español ([`painel/idioma_es.py`](../../painel/idioma_es.py)), con los mismos nombres entre llaves, las mismas marcas del HTML y las mismas comillas, que ninguna traducción sobra y que cada mensaje de error del `allsafe-ftp-user` tiene la suya; en el `.env.example`, que cada variable tiene comentario en la línea de arriba y está en [Configuración](configuracion.md); que ningún archivo del repositorio cita la carpeta personal de una computadora (verificación hecha solo cuando la carpeta es un repositorio Git; el `.env` local queda fuera); en [`web/marca/`](../../web/marca/), que los seis archivos de la marca existen y son PNG o ICO; que el [`SECURITY.md`](../../SECURITY.md) existe, cita `SEGURANCA_CONTATO_EMAIL` y no trae una dirección de correo fija; que el [`LICENSE`](../../LICENSE) es el texto oficial de la Apache-2.0, verificado por el sha256, que el [`NOTICE`](../../NOTICE) trae la línea de autoría y la dirección de GitHub, que el [`MARCA.md`](../../MARCA.es.md) existe y que cada archivo de código tiene la línea `SPDX-License-Identifier: Apache-2.0` en una de las dos primeras líneas; `docker compose config --quiet` con `.env.example` y cada archivo de `profiles/` |
| `--runtime` | todo lo anterior, más: los servicios `ftp`, `painel` y `nginx` en `running` y `healthy`, y el usuario inicial, leído de `FTP_USER` en el `.env`: presente en el registro (`pure-pw show`) o eliminado por el administrador (marca `/auth/usuario-inicial.criado`) |

El modo `--runtime` verifica la instalación del `.env` de esta carpeta. Para verificar otra, apunte a su archivo: `ENV_FILE=<arquivo> ./scripts/validate.sh --runtime`. Sin el archivo, el script se detiene con `ERRO: ... não há instalação para conferir.`

Rechazo de las rutas: `ERRO: pasta pessoal em arquivo do repositório; use o padrão do .env.example ou leia o valor do .env:`, seguida del archivo y de la línea.

Rechazo de la política de seguridad: `ERRO: <arquivo> falta, não cita SEGURANCA_CONTATO_EMAIL ou traz um endereço de e-mail fixo.`, para el `SECURITY.md` y para el `SECURITY.pt-BR.md`

Rechazos de la licencia: `ERRO: LICENSE falta ou não é o texto oficial da Apache-2.0.`, `ERRO: NOTICE falta ou está sem a linha de autoria e o endereço do GitHub.`, `ERRO: MARCA.md falta.`, `ERRO: TRADEMARK.md falta.` y `ERRO: <arquivo> sem a linha SPDX-License-Identifier: Apache-2.0 no começo.` La línea de la licencia va en la primera línea del archivo de código o, cuando empieza con `#!`, en la segunda.

</details>

---

<a name="gerar-marca"></a>

## 🎨 `scripts/gerar-marca.sh`

Genera, en [`web/marca/`](../../web/marca/), los seis archivos de logo e ícono que el panel usa, a partir de las dos artes de [`web/marca/fonte/`](../../web/marca/fonte/). Solo se ejecuta cuando el logo cambia: los archivos generados quedan en el repositorio y la instalación no usa este script. El paso a paso del cambio está en [Panel web](panel.md#marca).

```bash
./scripts/gerar-marca.sh                        # placa blanca detrás del arte
MARCA_PLACA='#f0f3f6' ./scripts/gerar-marca.sh  # otro color de placa, en el formato #rrggbb
```

**Resultado esperado:** una línea por archivo, con el tamaño en bytes, y, al final, `Marca gerada em web/marca/. Rode ./deploy.sh para o painel passar a usar.` Ejecutarlo de nuevo con las mismas artes genera archivos idénticos.

<details>
<summary>Detalle técnico — qué se genera</summary>

| Archivo | Lado | Arte de origen | Dónde lo usa el panel |
|---|---|---|---|
| `favicon.ico` | 16, 32 y 48 píxeles en el mismo archivo | `allsafe-simbolo-512.png` | Ícono de la pestaña del navegador |
| `icone-32.png` | 32 píxeles | `allsafe-simbolo-512.png` | Ícono de la pestaña del navegador |
| `icone-192.png` | 192 píxeles | `allsafe-simbolo-512.png` | Ícono en pantalla de alta densidad y en acceso directo |
| `apple-touch-icon.png` | 180 píxeles | `allsafe-simbolo-512.png` | Acceso directo en la pantalla de inicio del celular |
| `simbolo-64.png` | 64 píxeles | `allsafe-simbolo-512.png` | Símbolo en el menú de todas las pantallas |
| `logo-320.png` | 320 píxeles | `allsafe-logo-2048.png` | Logo de la pantalla de entrada |

- **Placa clara:** el arte es oscuro en fondo transparente y el panel tiene fondo oscuro. Cada archivo sale con el arte, en los colores originales, sobre una placa de esquinas redondeadas, que aparece igual en una pestaña clara u oscura del navegador. `MARCA_PLACA` cambia el color de la placa; el valor por defecto es `#ffffff`.
- **Cómo se arma:** el arte se recorta en el borde, se centra en la placa con 10% de margen, se arma en 1024 píxeles y se reduce al tamaño final. Los archivos salen con 128 colores en 8 bits, sin metadatos ni fecha: los seis suman 22 KB.
- **Artes de origen:** no se modifican, y no entran en la imagen de nginx ([`.dockerignore`](../../.dockerignore)).
- **Dependencia:** ImageMagick 7 (comando `magick`), solo en la computadora de quien cambia el logo. El servidor no lo necesita.
- **Rechazos:** `ERRO: o ImageMagick 7 (comando magick) não está instalado neste computador.`, `ERRO: faltam as fontes ...` y `ERRO: MARCA_PLACA aceita só cor no formato #rrggbb.`

</details>

---

<a name="testar"></a>

## 🧪 `tests/testar.sh`

Ejecuta la batería de pruebas de la stack: funcional, de seguridad y de red. El script levanta una instancia de prueba separada, prueba, guarda los resultados y elimina todo lo que creó. La instalación de esta carpeta no se toca y puede estar en marcha o no.

```bash
./tests/testar.sh                        # levanta la instancia de prueba, prueba, guarda los resultados y elimina
./tests/testar.sh --resultados <pasta>   # guarda los resultados en otra carpeta
./tests/testar.sh --manter               # deja la instancia de prueba en marcha para investigar
./tests/testar.sh --limpar               # solo elimina la instancia de prueba y su carpeta
```

**Resultado esperado:** una línea por caso, con `✅` o `❌`, el resumen de cada batería con la ruta del archivo de resultado y, al final, `Bateria aprovada: nenhum desvio.` La ejecución lleva cerca de 1 hora y 40 minutos.

> ⚠️ La instancia de prueba solo arranca en IP privada: `TESTE_IP` fuera de los rangos privados se rechaza antes de que cualquier contenedor arranque. La opción de IP pública se prueba con direcciones de documentación (`203.0.113.0/24` y `198.51.100.0/24`), sin publicar puertos fuera de la IP de prueba.

| Salida | Significado |
|---|---|
| `0` | todos los casos pasaron |
| `1` | algún caso tuvo un desvío; el archivo de resultado dice cuál y muestra la evidencia |
| `2` | uso incorrecto o requisito ausente en el host |
| `3` | un secreto apareció en un archivo de resultado; el archivo se borra |

<details>
<summary>Detalle técnico — la instancia de prueba, las variables y lo que cubre cada batería</summary>

**Requisitos en el host:** `docker` con el plugin Compose, `curl` con soporte de FTPS, `openssl`, `ss`, `tar`, `sha256sum`, `ssh-keygen` y `setsid`. El caso que verifica los secretos fuera de Git solo se ejecuta si la carpeta es un repositorio Git.

**La instancia de prueba** usa nombres, puertos, subred, datos y secretos propios:

| Elemento | Instancia de prueba | Variable para cambiar |
|---|---|---|
| Contenedores e imágenes | `allsafe-ftp-teste`, `allsafe-ftp-teste-painel`, `allsafe-ftp-teste-nginx` | — |
| Dirección | `127.0.0.2` | `TESTE_IP` |
| Puerto del FTP | `2121` | `TESTE_FTP_PORT` |
| Puerto del panel | `8444` | `TESTE_PAINEL_PORT` |
| Rango pasivo | `32000` a `32019` | `TESTE_PASSIVA_INICIO` |
| Subred Docker | `172.29.2.0/29` | `TESTE_SUBNET` |
| Primer administrador del panel | `gestor`, a propósito distinto del valor por defecto | `TESTE_ADMIN` |
| Segunda instancia, usada en el caso de las dos instancias en el mismo host | `allsafe-ftp-teste-b`, puertos siguientes, `172.29.3.0/29` | `TESTE_SUBNET_B` |
| Carpeta de trabajo, datos, secretos y copias de seguridad | `TEMP_DIR/testar` | `TEMP_DIR`, leída del entorno, después del `.env` y, sin los dos, del `.env.example` |

Las contraseñas de la instancia de prueba se generan en el momento, quedan solo en `TEMP_DIR/testar` y desaparecen con ella. El script rechaza ejecutarse si `TEMP_DIR/testar` ya existe y no fue creada por él, y si el `.env` de esta carpeta usa `STACK_NAME=allsafe-ftp-teste`.

**Lo que cubre cada batería:**

| Batería | Casos | Ejemplos |
|---|---|---|
| Funcional | 106 | instalación en un comando, login por FTPS, envío y descarga con comparación, ciclo de usuario por la terminal y por el panel, reinicio sin pérdida, healthcheck del FTP, copia de seguridad y restauración, archivos estáticos entregados por nginx, conversión de los nombres antiguos por el `deploy.sh`, administradores por el panel, recuperación del acceso desde el host, descarga por el panel (archivo pequeño, subcarpeta, nombre con tilde y archivo de 40 MiB, con la suma verificada), carpeta creada por el panel, usuario con carpeta elegida y carpeta compartida entre usuarios (también en un registro de dos mil usuarios, comparada con la verificación de todos contra todos), usuario del FTP que entra en el panel y descarga sus propios archivos, su sesión acompañando el registro y la variable que desactiva la entrada, su entrada en cada modo de TLS, y el TLS por usuario: dispensa y vuelta por el panel y por la terminal, usuario creado ya dispensado, la tarjeta del TLS en Editar y la opción sin efecto con IP pública, y la marca: logo e ícono entregados por nginx y la autoría en el pie de página de todas las pantallas, el `robots.txt` y el `security.txt` con el contacto de seguridad, la ejecución solo en Docker, sin systemd, la contraseña del usuario inicial aplicada de nuevo desde el secreto en cada arranque, la licencia y la autoría en el proyecto y dentro de las tres imágenes, el `HEAD` del panel igual al `GET`, sin el cuerpo, la carpeta del usuario cambiada por el panel y por la terminal, sin mover archivos, la contraseña y la carpeta del usuario inicial cambiadas por el panel, valiendo hasta que el secreto cambie, el archivo y la carpeta renombrados y borrados por el panel, el usuario eliminado junto con la carpeta, los límites por usuario guardados por el panel y por la terminal y aplicados por el FTP, las descargas por el panel en el límite del usuario, el bloqueo por intento en el FTP: límite del usuario por el panel y por la terminal, bloqueo, vencimiento, desbloqueo, reinicio y valor por defecto de la stack, las transferencias por el FTP en el registro del contenedor, y el frente web: HTTP/2 y HTTP/1.1 con la misma sesión, el estilo comprimido para quien acepta gzip y la conexión mantenida entre un clic y otro, y el usuario inicial eliminado por el panel, que no vuelve en el arranque siguiente, la pestaña Servidor coherente con la máquina y con los límites de cada contenedor, los perfiles en el FTP: Completo, Envío y Lectura, cada uno con lo que puede hacer, y la pantalla única de usuarios, con administradores y usuarios del FTP en la misma lista y el cambio de perfil, el bloqueo por dirección por la pestaña Bloqueos y por la terminal: dirección y prefijo, IPv4 e IPv6, extender, acortar y desbloquear, el idioma: portugués por defecto, la elección guardada por cuenta y todas las pantallas en inglés, el envío por el panel, por el administrador y por el usuario del FTP con su permiso, y la limpieza automática: activada por el panel, manteniendo los más recientes de cada carpeta y borrando lo que pasó del plazo, y los destinos de fuera: S3 y bot de Telegram guardados por el administrador y probados, la pasada que envía cada archivo una sola vez y recomienza desde el mismo archivo después de la falla, el archivo grande en partes, el modo Conservar en S3, el aviso de lo que pasa del límite del bot, el archivo que llega entero saliendo en instantes, el envío de un archivo por el botón de la pestaña Archivos, los destinos por la terminal, el segundo S3 y el segundo bot creados con el acceso del primero, el destino repetido y el límite de 20 por tipo rechazados, el Conservar en S3 a la espera de otro S3, la elección del destino en el envío de un archivo y la eliminación de un solo destino, la copia del sistema enviada por el panel al S3, cifrada y con el archivo de la suma, su restauración por el `restaurar.sh`, la falla a la mitad sin nada en el destino, la copia por la terminal y por la rutina, y la verificación de salud del panel dentro de la cuota de procesador del contenedor, y el remoto del rclone: los archivos de la carpeta llegando a un servidor SFTP y a un WebDAV de prueba con la misma suma, la clave privada, la clave cifrada con frase, el acceso copiado de otro destino y la modificación que mantiene el acceso, el envío de un archivo por el botón, el archivo nuevo en la pasada siguiente, la eliminación que no toca lo que ya fue enviado y el formulario de las cuatro nubes guardando un remoto que el rclone acepta, y el segundo factor: el administrador activándolo con la clave de la pantalla y entrando con contraseña y código, la cuenta sin el secreto en el servidor y el desactivar por la terminal, cada administrador activando solo el suyo y otro desactivándolo, el factor acompañando el cambio de nombre y saliendo con el administrador eliminado, los vectores de la RFC 6238, la dirección de la aplicación y el código QR, y el segundo factor obligatorio: el administrador y el usuario del FTP registrándolo en la entrada y pasando a entrar con el código, el FTP todavía solo con la contraseña, el administrador restableciendo el de un usuario, el desactivar por la terminal, la eliminación del usuario llevándose el factor y la vuelta al factor opcional, y los tipos nuevos del remoto del rclone: los 35 en la pantalla de elección, cada uno guardando un remoto que el rclone acepta, y el FTP con TLS guardando de extremo a extremo en un servidor de la propia stack |
| Seguridad | 151 | login sin TLS y anónimo rechazados, fuga del `chroot`, aislamiento entre usuarios, rechazos del `deploy.sh` y de los contenedores a IP pública, la opción de IP pública (solo con `sim`, "todos" siempre rechazado, TLS obligatorio, valor inválido, alerta en ejecución), CSRF, `Origin` de fuera y `Origin: null`, `Host` de fuera, límite de intentos, encabezados, TLS antiguo, ningún secreto en el `.env`, en Git, en los logs, en la auditoría y en el `LEIAME.txt` de la carpeta de secretos, entrada que no revela nombres de administrador, contraseña actual en toda modificación de administrador, sesiones del administrador modificado cerradas, archivo de administradores solo con hash, pestaña Archivos sin sesión, fuga de la carpeta por la pestaña Archivos, enlace simbólico no seguido, archivo entregado solo como adjunto, límite de descargas al mismo tiempo, creación de carpeta sin sesión y sin token, nombre de carpeta que intenta salir de la carpeta de los datos, usuario encerrado en la carpeta elegida, usuario del FTP sin alcance a la administración del panel, encerrado en su propia carpeta en el panel, su entrada sin brecha (pantallas iguales en el rechazo, nombre de administrador, servidor FTP detenido, certificado cambiado, bloqueo por intentos), los límites de sesiones y de descargas por usuario, y el TLS por usuario: sin TLS solo entra quien fue dispensado, sin ningún dispensado la sesión sin TLS se rechaza antes de la contraseña, el cambio de modo no derriba la sesión en curso, el FTP se cierra si el `pure-authd` muere, la opción sin efecto o desactivada, el valor rechazado en el arranque y quién puede modificar la lista, y la carpeta de la marca, que entrega solo los seis archivos, solo para lectura, las direcciones abiertas sin contraseña del `robots.txt` y del `security.txt`, que no entregan nada más, y la seguridad ampliada: ninguna ruta del panel y ningún comando del FTP sin login, contraseña aleatoria en el FTP y en el panel, ráfaga de contraseñas, de solicitudes y de conexiones, conexión detenida, solicitud grande o malformada, registro de las contraseñas fuera del alcance de la web, del FTP, de los otros contenedores y del host, costo de la contraseña del FTP según el porte, el cambio de carpeta, el renombrar y el borrar, que no salen de la carpeta de los datos ni actúan sin sesión, sin token y sin la contraseña del administrador, la carpeta grande borrada en más de una solicitud, los límites por usuario, que rechazan un valor fuera de la regla, sin sesión y sin token, y el bloqueo por intento: archivo de bloqueo falsificado, nombre fuera del registro, caída del vigía, y desbloqueo y límites sin sesión, sin token y fuera de la regla, y el HTTP/2 y la compresión, que no abren nada: página con token siempre entera, copia comprimida sin dirección y los límites de solicitudes y de tamaño valiendo en los dos protocolos, ninguna carpeta personal en archivo del repositorio, y el panel por proxy o túnel: dirección del cliente falsificada en encabezado ignorada, con y sin proxy declarado, contraseña incorrecta y sesión contadas por la dirección del cliente, y el aviso de exposición oculto solo en la pantalla, la pestaña Servidor fuera del alcance de quien no es administrador y los archivos de estado cambiados por texto con marcado y por enlace, y los perfiles: Envío no borra, no renombra y no escribe por encima de lo que ya llegó, Lectura no escribe nada, el modo de las carpetas acompaña el cambio de perfil, de carpeta y la eliminación, y el cambio de perfil rechazado sin sesión, sin token, por usuario del FTP y con valor fuera de la lista, y el bloqueo por dirección: el sexto error bloquea por 120 días en el FTP, con TLS y sin él, y en el panel, en IPv4 e IPv6, el bloqueado en uno no entra en el otro, la entrada correcta pone el conteo en cero, la dirección de la stack y la del servidor no se bloquean por sí solas, la pestaña solo para administrador, el bloqueo nuevo rechaza la propia dirección y el prefijo es solo del administrador, el cambio de idioma solo por `POST` del propio panel, con token, la cookie de idioma, que no vale como sesión, el envío por el panel: solicitud falsificada, nombre fuera de la regla, cuerpo malformado, salida de la carpeta, demasiados envíos al mismo tiempo y tamaño máximo, en el panel y en nginx, y la limpieza automática, que solo el administrador define, con su contraseña, y que no sale de la carpeta del usuario ni sigue enlaces simbólicos, y los destinos de fuera: solo el administrador guarda, con sesión, token y contraseña, los secretos fuera de las pantallas y de los registros, salida solo por HTTPS, con certificado verificado y dirección aceptada, el bot que solo envía y el S3 que solo guarda, ninguna solicitud de borrar, leer o tocar el bucket y la conversación saliendo del panel, la variable que desactiva todo, y el envío de un archivo solo por el administrador, con token, y con el botón solo después de guardado el destino, y, con varios destinos, el nombre fuera de la regla rechazado, las pantallas solo del administrador y el secreto copiado fuera de las pantallas, y la copia del sistema solo por el administrador, con la clave privada fuera del panel y nada borrado en el destino, y el remoto del rclone: solo el administrador guarda, con token y contraseña, solo lo que el panel conoce va al archivo del remoto, sin la clave del servidor nada sale y un servidor con otra clave se rechaza, el remoto solo recibe, sin ningún subcomando que liste, descargue, mueva o borre, el acceso fuera de las pantallas, de la auditoría, de los registros y de la lista de procesos, el archivo del remoto modificado por fuera dejando el destino sin acceso, el formulario largo solo en su ruta, con tope en el panel y en nginx, y el certificado verificado, la dirección del propio contenedor rechazada y el motivo de la falla sin el texto del rclone, y el segundo factor: la contraseña correcta sin abrir sesión, el código incorrecto o ya usado rechazado, el usuario del FTP entrando sin código y fuera de las pantallas y de las rutas, la espera fijada a la dirección y al plazo, el tope de esperas, la pausa de la cuenta, los cinco códigos incorrectos que derriban la espera y retienen la dirección, y la clave fuera de la auditoría, del registro y de los datos del panel, y el registro en la entrada: la espera que no abre ninguna pantalla, el código incorrecto que no guarda nada, la cuenta con factor que no recibe otra clave, el usuario del FTP fuera del factor de los otros, la pantalla de restablecer sin clave y la línea fuera de la regla que no se vuelve cuenta, y la lista cerrada del remoto del rclone: tipo, opción y archivo de remoto de fuera de ella rechazados, el FTP que no sale sin TLS, cada tipo y cada opción de la lista verificados contra el rclone de la imagen, los secretos de los tipos nuevos fuera de las pantallas y de los registros y el servidor en dirección interna rechazado |
| Red | 14 | puertos publicados solo en la IP configurada, dirección anunciada en el modo pasivo, límite de sesiones por IP, panel solo en HTTPS, cambio de perfil, dos instancias en el mismo host, red pública en el panel solo con la opción, proxy del panel declarado dirección a dirección y dentro de las redes permitidas |

**Organización:** el [`tests/testar.sh`](../../tests/testar.sh) prepara la instancia de prueba y carga el [`tests/comum.sh`](../../tests/comum.sh), con las funciones de registro, de FTP, del panel y de escritura de los resultados. Los casos quedan en [`tests/etapas/`](../../tests/etapas/), un archivo por etapa, ejecutados en el orden del nombre: cada etapa parte del estado que dejó la anterior y no se ejecuta sola. En la etapa de los destinos, el [`tests/apoio/simulador_destinos.py`](../../tests/apoio/simulador_destinos.py) hace el papel del S3 y de la API de bot dentro de la red de la instancia de prueba, y, en la etapa del remoto del rclone, el [`tests/apoio/servidor_rclone.sh`](../../tests/apoio/servidor_rclone.sh) levanta en la misma red un servidor SFTP y un WebDAV de prueba, con el rclone de la imagen del panel. El servidor FTP con TLS de prueba es un contenedor de la imagen del FTP de la propia instancia, y el [`tests/apoio/rclone_tipos.py`](../../tests/apoio/rclone_tipos.py) verifica la lista de tipos del panel contra el rclone de la imagen, en un contenedor sin red: la batería no habla con ningún servicio de fuera.

**Resultados:** tres archivos Markdown, uno por batería, con fecha, comando, versión, entorno, la tabla de los casos con la evidencia de cada uno y los hallazgos. No se guarda ninguna contraseña, token, cookie ni hash: antes de terminar, el script busca en los tres archivos los secretos que usó y, si encuentra alguno, borra el archivo y sale con `3`. Sin `--resultados`, van a la carpeta del plan, si existe, o a `TEMP_DIR/resultados`.

**Limpieza:** al terminar, o al ser interrumpido, el script elimina los contenedores, la red, las imágenes y la carpeta de la instancia de prueba. Con `--manter`, nada se elimina hasta el `--limpar`.

</details>

---

<a name="entrypoint"></a>

## ⚙️ `ftp/entrypoint.sh`

Se ejecuta en cada inicio del contenedor. No tiene parámetros: todo viene de las variables de [Configuración](configuracion.md).

1. Verifica que `FTP_BIND_IP` y `FTP_PASSIVE_IP` son IP privadas, o públicas de servidor con `REDE_PERMITIR_IP_PUBLICO=sim` ([`rede-privada.sh`](../../scripts/rede-privada.sh)), lee la contraseña del secreto `/run/secrets/ftp_usuario_inicial_senha`, ajusta dueño y modo de `/data` (`0700`, del `root`), `/auth` y `/etc/ssl/private` y crea el usuario inicial `FTP_USER`, una vez, dejando la marca `/auth/usuario-inicial.criado` (`0600`, solo con su nombre); si ya existe, reescribe su contraseña con la del secreto (rechaza contraseña con menos de 12 caracteres); si fue eliminado, no lo crea de nuevo, y el log dice `removido pelo administrador; não é recriado`. Si la contraseña fue cambiada por el panel y el secreto no cambió desde entonces, se mantiene, y el log dice `mantida a senha trocada pelo painel`. El costo del hash de la contraseña acompaña a `FTP_MAX_CLIENTS`.
2. Genera un certificado autofirmado para `FTP_CERT_CN` si `DATA_DIR/certs` está vacía, y guarda su parte pública en `/auth/ftp-cert.pem`.
3. Con perfil Envío, Solo envío o Lectura en el registro, rehace el modo de las carpetas de los usuarios, entrega al `ftpdata` lo que un envío dejó sin entrega y lleva a la carpeta del usuario lo que quedó en el área de entrada de cada Solo envío (`allsafe-ftp-user ajustar`). Levanta el [vigía](#vigia), que cuenta las contraseñas incorrectas, y el `pure-authd`, que llama al [portero](#porteiro) en cada entrada.
4. Levanta el `pure-ftpd` con el modo de TLS, el `chroot`, los límites y el rango pasivo del `.env`. Con `FTP_TLS_MODE` en `0` o `1`, o con usuario dispensado del TLS, escribe antes un `AVISO` en el log.
5. Con el TLS por usuario en vigor, levanta el observador, que verifica la lista de los dispensados cada segundo. Cuando pasa de vacía a rellenada, o al contrario, solo se cambia el proceso del `pure-ftpd` que escucha el puerto: las sesiones en curso continúan y el contenedor no se reinicia.
6. Queda vigilando los procesos: si uno de ellos sale por otro motivo, cierra el contenedor, y Docker lo levanta de nuevo.

**Resultado esperado:** las líneas `vigia: pronto: 5 senhas erradas do mesmo endereço bloqueiam o usuário para ele por 15 min; ...` y `FTP pronto em 2121/tcp; TLS=2; TLS por usuário: nenhum dispensado, sessão sem TLS recusada antes da senha; passivo=30000-30049` en el log del contenedor; con un usuario dispensado, `FTP pronto em 2121/tcp; TLS=2 com exceção por usuário (1 dispensado(s) do TLS); passivo=30000-30049`. En cada cambio, la línea `TLS por usuário: a lista dos dispensados mudou; o FTP troca o modo de entrada sem derrubar as sessões em andamento.` viene antes de un nuevo `FTP pronto`. Con la opción sin efecto, el arranque dice `TLS por usuário sem efeito: só vale com FTP_TLS_MODE=2; está <modo>.` o `TLS por usuário sem efeito: não vale com REDE_PERMITIR_IP_PUBLICO=sim (...)`, y sigue.

<details>
<summary>Detalle técnico — proceso 1 y mensajes de falla</summary>

Con `init: true`, el proceso 1 del contenedor es el `tini`, que inicia el entrypoint. El entrypoint sigue vivo, con el vigía, el `pure-authd` y el `pure-ftpd` como hijos, les reenvía la señal de parada y, si uno de los tres sale por sí solo, cierra los otros y sale con código `1`.

Cuando una validación falla, el script sale con `FALHA: <motivo>`:

| Mensaje | Cuándo |
|---|---|
| `FALHA: segredo /run/secrets/ftp_usuario_inicial_senha ausente` | `.secrets/ftp-usuario-inicial-senha.txt` no existe: ejecute el `deploy.sh` |
| `FALHA: FTP_PASSWORD não é aceita` | hay contraseña en variable de entorno; solo se lee del secreto |
| `FALHA: FTP_BIND_IP=… não é IP privado` (o `FTP_PASSIVE_IP`) | la dirección está fuera de los rangos privados y la opción de IP pública está en `nao`; el contenedor se reinicia en bucle hasta la corrección |
| `FALHA: FTP_BIND_IP=… não é um endereço IPv4 de servidor` (o `FTP_PASSIVE_IP`) | con la opción en `sim`, el valor es `0.0.0.0`, multicast o reservado |
| `FALHA: REDE_PERMITIR_IP_PUBLICO deve ser 'nao' ou 'sim'` | la opción tiene otro valor |
| `FALHA: REDE_PERMITIR_IP_PUBLICO=sim exige FTP_TLS_MODE=2 ou 3` | la opción está activada con el TLS del FTP en `0` o `1` |
| `FALHA: FTP_USER invalido` | el nombre no sigue `^[a-z_][a-z0-9_-]{0,31}$` |
| `FALHA: a senha FTP deve ter pelo menos 12 caracteres` | contraseña corta o archivo vacío |
| `FALHA: faixa passiva invalida` | inicio o fin no numéricos |
| `FALHA: faixa passiva fora dos limites` | por debajo de `1024`, por encima de `65535` o invertido |
| `FALHA: FTP_TLS_MODE deve ser 0, 1, 2 ou 3` | valor fuera de la lista |
| `FALHA: FTP_MAX_CLIENTS deve ser um inteiro maior que zero` (o `FTP_MAX_CLIENTS_PER_IP`) | el límite de sesiones no es un entero de 1 a 99999 |
| `FALHA: FTP_TLS_EXCECOES deve ser 'nao' ou 'sim'` | la excepción por usuario tiene otro valor |
| `FALHA: FTP_BLOQUEIO_TENTATIVAS deve ficar entre 0 e 100 (0 desliga o bloqueio por tentativa)` | el límite de contraseñas incorrectas de la stack no es un entero de 0 a 100 |
| `FALHA: FTP_BLOQUEIO_MINUTOS deve ficar entre 1 e 1440` | los minutos de bloqueo de la stack no son un entero de 1 a 1440 |
| `FALHA: /auth/bloqueios é link simbólico: remova-o` | la carpeta de los bloqueos, en `DATA_DIR/auth`, fue cambiada por un enlace |
| `FALHA: BLOQUEIO_ENDERECO_ERROS deve ficar entre 0 e 100 (0 desliga o bloqueio por endereço)` | el límite de errores por dirección no es un entero de 0 a 100 |
| `FALHA: BLOQUEIO_ENDERECO_HORAS deve ficar entre 1 e 720` | las horas en que se suman los errores de una dirección no son un entero de 1 a 720 |
| `FALHA: BLOQUEIO_ENDERECO_DIAS deve ficar entre 1 e 3650` | los días de bloqueo de la dirección no son un entero de 1 a 3650 |
| `FALHA: /auth/enderecos é link simbólico: remova-o` | la carpeta de los bloqueos por dirección, en `DATA_DIR/auth`, fue cambiada por un enlace |
| `FALHA: /auth/chegadas é link simbólico: remova-o` | la carpeta de los avisos de llegada, en `DATA_DIR/auth`, fue cambiada por un enlace |
| `FALHA: o vigia não abriu o soquete /dev/log: o FTP não sobe sem a contagem das senhas erradas` | el vigía no inició |
| `FALHA: o pure-authd não abriu o soquete /run/pure-authd.sock: o FTP não sobe sem o porteiro` | el `pure-authd` no inició |
| `FALHA: o pure-authd saiu: o container encerra para ninguém entrar sem a conferência do porteiro` (o `o vigia saiu`, `o pure-ftpd saiu`, o `o observador da lista do TLS saiu`) | uno de los procesos vigilados se detuvo después del arranque; Docker levanta el contenedor de nuevo |

No es falla, y el contenedor arranca: `AVISO: FTP_TLS_MODE=0, FTP sem TLS: senhas e arquivos trafegam em texto puro. Só para equipamento sem suporte a TLS, em rede interna isolada.` (o `FTP_TLS_MODE=1, TLS opcional: ...`). El aviso se repite en cada arranque mientras el modo esté activado. Con `FTP_TLS_EXCECOES=sim`, el aviso es `AVISO: FTP_TLS_EXCECOES=sim: <n> usuário(s) marcado(s) no painel entram sem TLS, com senha e arquivos em texto puro. ...`.

La corrección de cada una está en [Solución de problemas](solucion-de-problemas.md#o-container-nao-sobe). El modelo completo del arranque está en [Arquitectura](arquitectura.md#subida).

</details>

---

<a name="ftp-saude"></a>

## 🩺 `ftp/saude.sh`

Es el healthcheck del contenedor del FTP, instalado como `/usr/local/sbin/allsafe-ftp-saude`. No se llama directamente: Docker lo ejecuta cada 20 segundos.

<details>
<summary>Detalle técnico — qué verifica</summary>

Abre el puerto de control (`127.0.0.1:2121`, desde dentro del contenedor), espera hasta 4 segundos por el saludo del servidor y cierra la conexión con `QUIT`. Considera saludable el saludo `220` (listo) y también el `421` (límite de conexiones alcanzado: el servidor está lleno, pero atendiendo). Puerto cerrado, o abierto sin saludo, cuenta como falla: después de cinco fallas seguidas Docker marca el contenedor como `unhealthy`. La prueba no hace login y no usa contraseña. Antes de abrir el puerto exige el socket `/run/pure-authd.sock` y el `/dev/log`: sin el `pure-authd` o sin el vigía, el FTP no cuenta como saludable.

Para ejecutarlo a mano: `docker compose exec ftp /usr/local/sbin/allsafe-ftp-saude; echo $?` (`0` = atendiendo).

</details>

---

<a name="porteiro"></a>

## 🚪 `ftp/porteiro.pl`

Es el portero del FTP, instalado en la imagen como `/usr/local/sbin/allsafe-ftp-porteiro`. No se llama directamente: el `pure-authd` lo ejecuta en cada entrada, antes de la verificación de la contraseña. No verifica la contraseña: solo decide si la entrada puede seguir hacia ella.

**Resultado esperado:** la entrada sin impedimento sigue hacia la verificación de la contraseña. La dirección con [bloqueo por dirección](seguridad.md#bloqueio-por-endereco) en vigor, o dentro de un prefijo bloqueado, recibe `530` con cualquier cuenta. El usuario con [bloqueo por intento](seguridad.md#bloqueio-por-tentativa) en vigor para la dirección recibe `530`. Con el TLS por usuario en vigor y algún usuario dispensado, la sesión sin TLS de quien no fue dispensado recibe `530`, y el log del contenedor recibe la línea `porteiro: entrada sem TLS recusada: usuario=<nome> origem=<ip> (a senha enviada passou em texto puro: troque-a)`.

<details>
<summary>Detalle técnico — qué responde</summary>

- Recibe del `pure-authd`, en variables de entorno, el nombre (`AUTHD_ACCOUNT`), si la sesión tiene TLS (`AUTHD_ENCRYPTED`) y la dirección de origen (`AUTHD_REMOTE_IP`). La contraseña también llega en variable y **no** se lee, se guarda ni se registra.
- Responde `auth_ok:0`, la respuesta "no es conmigo", cuando ninguna de las tres reglas rechaza: el `pure-ftpd` sigue hacia el PureDB, que verifica la contraseña. Responde `auth_ok:-1`, el rechazo definitivo, cuando una de ellas rechaza: el cliente recibe `530` con la contraseña correcta o incorrecta.
- **Bloqueo por dirección**, la primera regla: el origen, IPv4 o IPv6, es leído y escrito por el [`ftp/endereco.pl`](../../ftp/endereco.pl), de la misma manera que en el vigía y en el panel. El portero rechaza cuando no es del propio servidor (`127.0.0.0/8`, `0.0.0.0/8` y `::/16`) y existe el archivo común `/auth/enderecos/<origem>`, o un archivo de `/auth/prefixos` cuya red lo cubre, con la primera línea empezando por un número de hasta 12 dígitos mayor que la hora actual. Vale para cualquier nombre, con TLS o sin él. Archivo vencido o fuera de ese formato no bloquea.
- **Escritura única de la dirección:** IPv4 sin cero a la izquierda; IPv6 en minúsculas y comprimido; el IPv6 que lleva un IPv4 (`::ffff:a.b.c.d`) vale como el IPv4; la dirección con zona se rechaza. El prefijo es la red con el tamaño, de `/8` a `/31` en IPv4 y de `/16` a `/127` en IPv6, y su archivo es `/auth/prefixos/<rede>_<tamanho>`. Llamado como programa, `endereco.pl alvo <texto>` escribe `endereco <endereço>` o `prefixo <rede>/<tamanho>`, y sale con `1` cuando el texto no es ni lo uno ni lo otro y con `2` cuando es del propio servidor: así es como el `allsafe-ftp-user` verifica lo que el administrador pide bloquear.
- **TLS por usuario**, solo con la opción en vigor (`FTP_TLS_EXCECOES=sim`, `FTP_TLS_MODE=2` y sin IP pública aceptada), que el entrypoint marca en `/run/allsafe/tls-por-usuario`: sin ningún dispensado, el `pure-ftpd` rechaza la sesión sin TLS antes de la contraseña y el portero ni siquiera es llamado; con alguno, la sesión sin TLS solo sigue cuando el nombre está en una línea entera de `/auth/sem-tls.lista`. Lista ausente o ilegible cuenta como lista vacía: nadie entra sin TLS. El rechazo deja una marca en `/run/allsafe/recusa/`, para que el vigía no lo cuente como contraseña incorrecta.
- **Bloqueo por intento:** rechaza cuando existe el archivo común `/auth/bloqueios/<usuario>@<origem>` y su primera línea empieza por un número de hasta 12 dígitos mayor que la hora actual. Archivo vencido o fuera de ese formato no bloquea.
- Solo se vuelve ruta de archivo o línea de registro el nombre dentro de la regla `^[a-z_][a-z0-9_-]{0,31}$` y el origen en formato de dirección. En el registro, el nombre fuera de la regla se vuelve `(nome fora da regra)` y el origen fuera del formato se vuelve `?`: lo que el cliente envió no va crudo al log. La línea sale por la salida de error del proceso 1 del contenedor, porque el `pure-authd` cierra la del script.

</details>

---

<a name="vigia"></a>

## 👁️ `ftp/vigia.pl`

Es el vigía de las entradas del FTP, instalado en la imagen como `/usr/local/sbin/allsafe-ftp-vigia`. No se llama directamente: el entrypoint lo levanta antes del servidor. Cuenta las contraseñas incorrectas de cada dirección para cada usuario, guarda el bloqueo que el portero aplica y escribe en el log del contenedor cada entrada y cada transferencia. Avisa al panel de cada archivo que acaba de llegar entero, para que el bot de Telegram lo envíe sin esperar. También publica los contadores de red y los recursos del contenedor (procesador, memoria y procesos, con los límites), que la pestaña Servidor del panel muestra.

**Resultado esperado:** en el arranque, `vigia: pronto: 5 senhas erradas do mesmo endereço bloqueiam o usuário para ele por 15 min; limite próprio do usuário em Editar, na aba Usuários do painel`, con los valores del `.env`. Después, una línea por entrada y por transferencia en el log del contenedor:

| Línea | Cuándo |
|---|---|
| `vigia: entrada: usuario=<nome> origem=<ip>` | Entrada correcta; el conteo de esa dirección para el usuario vuelve a cero |
| `vigia: entrada recusada: usuario=<nome> origem=<ip> senhas_erradas=<n> de <limite>` | Contraseña incorrecta, sumada |
| `vigia: entrada bloqueada: usuario=<nome> origem=<ip> senhas_erradas=<n> minutos=<m>` | La contraseña incorrecta completó el límite y el bloqueo fue guardado |
| `vigia: entrada recusada pelo bloqueio: usuario=<nome> origem=<ip>` | Intento hecho durante el bloqueo |
| `vigia: entrada recusada: usuario=<nome> origem=<ip> (bloqueio por tentativa desligado)` | El límite del usuario, o el de la stack, es `0` |
| `vigia: entrada recusada: usuario=<nome> origem=<ip> (não está no cadastro)` | Nombre dentro de la regla, sin usuario con él |
| `vigia: entrada recusada: usuario=<nome> origem=<ip> (rede interna da stack: não conta para o bloqueio)` | Contraseña del usuario del FTP incorrecta en la pantalla del panel |
| `vigia: entrada recusada: nome fora da regra, origem=<ip>` | El nombre enviado no cabe en la regla de los nombres; no va al log |
| `vigia: envio: usuario=<nome> origem=<ip> bytes=<n> arquivo=<caminho>` | Archivo recibido por el FTP; la ruta es la de dentro del contenedor, a partir de `/data` |
| `vigia: download: usuario=<nome> origem=<ip> bytes=<n> arquivo=<caminho>` | Archivo descargado por el FTP |
| `vigia: renomeado: usuario=<nome> origem=<ip> nomes=[<de>]->[<para>]` | Archivo o carpeta renombrado o movido por el FTP; los nombres son los que el cliente envió |
| `vigia: apagado: usuario=<nome> origem=<ip> arquivo=<caminho>` | Archivo borrado por el FTP |
| `vigia: entrega nao feita (<motivo>): usuario=<nome> arquivo=<caminho>` | El archivo recibido en carpeta con perfil Envío o Lectura no pudo ser pasado al `ftpdata`, o el recibido de un perfil Solo envío no pudo ser llevado a la carpeta del usuario: la carpeta o el archivo desapareció, o es enlace simbólico. En el Solo envío, el archivo sigue en el área de entrada y el siguiente inicio del servicio lo intenta de nuevo |
| `Entrega nao feita (<motivo>): /data/.entrada/<nome>/<arquivo>` y `AVISO: ficou arquivo sem entrega em /data/.entrada/<nome>` | En el inicio del servicio, en el cambio de perfil o en la eliminación del usuario, un elemento del área de entrada del Solo envío no es archivo común del `ftpsoenvio` y quedó donde estaba |

<details>
<summary>Detalle técnico — cómo cuenta</summary>

- **De dónde viene el aviso:** el `pure-ftpd` solo avisa de la contraseña incorrecta por el registro del sistema. El vigía abre el socket `/dev/log`, solo para el `root`, y lee cada línea que el servidor escribe allí. La línea se verifica de principio a fin: lo que el cliente escribió solo aparece al final de ella, y solo se vuelve conteo el nombre dentro de la regla.
- **La contraseña no le llega:** el aviso trae el nombre y la dirección.
- **Límite y plazo:** los del usuario, en `/auth/limites.lista` (`tentativas=` y `minutos=`), o los de la stack (`FTP_BLOQUEIO_TENTATIVAS` y `FTP_BLOQUEIO_MINUTOS`). El registro y la lista se releen cuando el archivo cambia.
- **Conteo:** en la memoria, por usuario y dirección, solo de las contraseñas incorrectas más nuevas que los minutos de bloqueo; hasta 10.000 pares. Reiniciar el contenedor pone en cero el conteo en curso y no quita el bloqueo.
- **Bloqueo:** el archivo `/auth/bloqueios/<usuario>@<endereco>`, `0600`, guardado por cambio de nombre, con hasta cuándo vale, desde cuándo y cuántas contraseñas incorrectas; hasta 4.096 archivos. De minuto en minuto, el vigía borra los vencidos y los inválidos.
- **Bloqueo por dirección:** además del conteo por usuario, suma los errores de usuario y contraseña de cada dirección, con cualquier nombre, registrado o no, dentro de `BLOQUEIO_ENDERECO_HORAS`; hasta 10.000 direcciones en la memoria. El error que pasa de `BLOQUEIO_ENDERECO_ERROS` guarda `/auth/enderecos/<endereco>`, `0600`, por cambio de nombre, con hasta cuándo vale (`BLOQUEIO_ENDERECO_DIAS`), desde cuándo, cuántos errores y `ftp`; hasta 10.000 archivos. Vale para IPv4 e IPv6, en la escritura única del [`ftp/endereco.pl`](../../ftp/endereco.pl). No cuentan la red interna de la stack, el rechazo del portero por falta de TLS y el intento hecho durante un bloqueo; la dirección de salida del contenedor y las del propio servidor nunca se bloquean. Los vencidos salen en la misma limpieza de minuto en minuto, que también borra los prefijos vencidos de `/auth/prefixos`.
- **Entrada correcta:** la entrada aceptada por el servidor (`<nome> is now logged in`) pone en cero el conteo de esa dirección para el usuario y el conteo de la dirección. El bloqueo ya guardado no sale con ella: solo en el plazo o por el administrador.
- **Prefijo:** el vigía nunca guarda prefijo. Solo el administrador bloquea una red entera, por el panel o por el `manage-user.sh`; el vigía y el portero solo lo respetan, y el error venido de una dirección cubierta por prefijo es intento durante bloqueo, que no cuenta.
- **Red:** cada 5 s, suma los contadores de las interfaces del contenedor en `/proc/net/dev`, fuera de la `lo`, y guarda una línea de siete números en `/auth/rede.estado` (`0600`): instante, segundos del intervalo, bytes recibidos y enviados desde que el contenedor arrancó, bytes recibidos y enviados en el intervalo, y errores y descartes. Guarda por cambio de nombre, con el bloqueo del registro (`/auth/.lock`), solo cuando los contadores cambian y una vez más cuando el tráfico se detiene; con el bloqueo ocupado, esa lectura no se publica. Una falla en la lectura o en la escritura no detiene al vigía.
- **Recursos del contenedor:** en el mismo ciclo de 5 s, lee el grupo de control del contenedor (`/sys/fs/cgroup`) y guarda una línea de doce números en `/auth/recursos.estado` (`0600`): instante, instante en que el vigía inició, milisegundos del intervalo, microsegundos de procesador gastados en él, cuota y período del límite de procesador, memoria en uso y límite, procesos y límite, veces en que el límite de procesador retuvo al contenedor y veces en que faltó memoria. Límite `0` quiere decir sin límite. Publica en las dos primeras lecturas y, después, cuando el uso cambia (1% de un núcleo, 1 MiB de memoria, procesos o contadores) o cada minuto, de la misma manera que la red: por cambio de nombre, con el bloqueo del registro.
- **Lo que no cuenta:** dirección de la red interna de la stack, rechazo del portero por falta de TLS, intento durante el bloqueo, nombre fuera del registro y nombre fuera de la regla.
- **Por qué Perl:** la imagen del FTP no tiene Python, y el `perl-base` ya viene en la imagen base de Debian. El vigía usa solo sus módulos, sin paquete nuevo.
- **Transferencias:** el `pure-ftpd` avisa por el mismo registro de cada archivo enviado, descargado, renombrado y borrado, y el vigía escribe la línea. El nombre del archivo va al final, y el tamaño se lee del final del aviso: un nombre elegido por el cliente no se hace pasar por otro campo. El aviso se reconoce por el comienzo, que es del servidor: un archivo borrado cuyo nombre imita el final de un envío sigue registrado como borrado. El carácter de control y de dirección del texto se vuelve `?`; el nombre en UTF-8 pasa; la ruta se corta en 400 caracteres. Lo que se hizo por el panel queda en su auditoría, no aquí.
- El aviso y el error del `pure-ftpd` siguen hacia el log del contenedor como `vigia: pure-ftpd: <texto> origem=<ip>`; conexión, salida, carpeta creada y carpeta borrada no se repiten.
- **Llegada anunciada:** en cada envío concluido por el FTP, con el archivo ya en el lugar en que queda (en el perfil Solo envío, en la carpeta del usuario), guarda un archivo en `/auth/chegadas`, carpeta `0700` del `root` que el entrypoint crea y vacía en el arranque, con su ruta dentro de los datos. El nombre es `<instante>-<série>`, guardado por cambio de nombre, con el bloqueo del registro (`/auth/.lock`). El panel lee y borra el aviso cada 2 s, y es por él que el [bot de Telegram](panel.md#destinos) envía el archivo sin la espera de dos minutos. El aviso no elige lo que se envía: solo dispensa la espera de un archivo que la pasada encontraría de cualquier manera, dentro de la carpeta del destino. Hasta 2.000 avisos en espera; lo que el panel no recoge en 5 minutos sale. Con el bloqueo ocupado en ese instante, el tope alcanzado o la carpeta fuera del alcance, el aviso no se guarda, y el archivo sale por la espera normal. El archivo renombrado o movido por el FTP no se anuncia.
- Si el vigía se detiene, el entrypoint cierra el contenedor: sin él, nadie más sería bloqueado.

</details>

---

<a name="painel-entrypoint"></a>

## 🖥️ `painel/entrypoint.sh`

Se ejecuta en cada inicio del contenedor del panel. No tiene parámetros: todo viene de las variables de [Configuración](configuracion.md#painel).

1. Rechaza contraseña en variable, exige el secreto `/run/secrets/painel_admin_inicial_senha_hash` y verifica el `PAINEL_ADMIN_USER` y el `SEGURANCA_CONTATO_EMAIL`.
2. Verifica que `PAINEL_BIND_IP`, cada red de `PAINEL_REDES_PERMITIDAS` y el `PAINEL_CERT_CN` (si es IP) son privados, o públicos aceptados con `REDE_PERMITIR_IP_PUBLICO=sim`.
3. Ajusta dueño y modo de `/painel` (`0700`, del `root`) y del archivo de administradores (`0600`, del `root`), también después de una restauración, y genera el certificado autofirmado del panel cuando falta, cuando las direcciones cambian o cuando faltan menos de 30 días para vencer.
4. Prepara la carpeta `/nginx` (`0750`, grupo `10001`, el de nginx): copia el certificado y la clave a `/nginx/tls`, borra el socket del arranque anterior y crea `/nginx/estado` (`0700`, del usuario de nginx), la carpeta en que nginx publica los recursos de su contenedor.
5. Ejecuta el servidor [`painel/servidor.py`](../../painel/servidor.py), el punto de entrada de los [módulos del panel](panel.md#modulos), que abre el socket `/nginx/painel.sock`. El panel no abre puerto de red.

**Resultado esperado:** la línea `Painel pronto no soquete /nginx/painel.sock, atrás do nginx; sessão de 240 min; redes permitidas: ...` en el log del contenedor.

<details>
<summary>Detalle técnico — mensajes de falla</summary>

| Mensaje | Cuándo |
|---|---|
| `FALHA: PAINEL_PASSWORD não é aceita` (o `PAINEL_PASSWORD_HASH`) | hay contraseña o hash en variable de entorno; el panel solo lee el secreto |
| `FALHA: segredo /run/secrets/painel_admin_inicial_senha_hash ausente` | `.secrets/painel-admin-inicial-senha-hash.txt` no existe: ejecute el `deploy.sh` |
| `FALHA: PAINEL_BIND_IP=… não é IP privado` (o `PAINEL_CERT_CN`) | dirección fuera de los rangos privados, con la opción de IP pública en `nao` |
| `FALHA: PAINEL_REDES_PERMITIDAS: '…' não é rede privada` | la lista tiene red pública o `0.0.0.0/0`, con la opción de IP pública en `nao` |
| `FALHA: PAINEL_PROXY_CONFIAVEL: …` | la lista de proxies tiene red entera, valor que no es IPv4, dirección pública sin la opción de IP pública, dirección fuera de `PAINEL_REDES_PERMITIDAS` o más de 8 direcciones |
| `FALHA: PAINEL_BIND_IP=… não é um endereço IPv4 de servidor` (o `PAINEL_CERT_CN`) | con la opción en `sim`, el valor es `0.0.0.0`, multicast o reservado |
| `FALHA: PAINEL_REDES_PERMITIDAS: '…' não é uma rede IPv4 aceita` | con la opción en `sim`, la red es más ancha que `/8`, como `0.0.0.0/0` |
| `FALHA: REDE_PERMITIR_IP_PUBLICO deve ser 'nao' ou 'sim'` | la opción tiene otro valor |
| `FALHA: PAINEL_REDES_PERMITIDAS está vazia` | la variable llegó vacía al contenedor |
| `FALHA: PAINEL_ACESSO_USUARIOS_FTP deve ser 'sim' ou 'nao'` | la entrada de los usuarios del FTP tiene otro valor |
| `FALHA: PAINEL_AVISO_EXPOSICAO deve ser 'sim' ou 'nao'` | el aviso de exposición en la pantalla tiene otro valor |
| `FALHA: FTP_TLS_EXCECOES deve ser 'nao' ou 'sim'` | la excepción de TLS por usuario tiene valor inválido, la misma verificación del contenedor del FTP |
| `FALHA: PAINEL_ADMIN_USER inválido: ...` | el nombre del primer administrador tiene mayúscula, espacio, más de 32 caracteres o carácter fuera de `a-z`, `0-9`, `_` y `-` |
| `FALHA: SEGURANCA_CONTATO_EMAIL inválido: ...` | el contacto de seguridad está rellenado y no es una sola dirección de correo: tiene `mailto:`, espacio, dos direcciones, `%`, o dominio sin punto |
| `FALHA: FTP_MAX_CLIENTS deve ser um inteiro maior que zero` | el límite de sesiones del FTP, que el panel usa para guardar la contraseña con el costo del porte, no es un entero de 1 a 99999 |
| `FALHA: PAINEL_CERT_CN inválido` | nombre con mayúscula, espacio o carácter fuera de `a-z`, `0-9`, `.` y `-` |
| `FALHA: pastas /auth e /data ausentes` | el panel arrancó sin las carpetas del servicio `ftp` |
| `FALHA: pasta /nginx ausente` | el panel arrancó sin la carpeta `DATA_DIR/nginx`, por donde nginx lo alcanza: ejecute el `deploy.sh` |
| `FALHA: não foi possível gerar o certificado do painel` | `DATA_DIR/painel` sin espacio o sin permiso de escritura |

El certificado es EC P-256, válido por 825 días. El archivo `painel-san.txt`, a su lado, marca que fue generado por la stack: sin ese archivo, el certificado se trata como propio y nunca se rehace. La copia a `/nginx/tls` se rehace en cada arranque (certificado `0644`, clave `0640`): es la que nginx presenta al navegador. Vea [Panel web](panel.md#certificado).

</details>

---

<a name="nginx-entrypoint"></a>

## 🚦 `nginx/entrypoint.sh`

Se ejecuta en cada inicio del contenedor de nginx, ya como usuario sin privilegio (`10001`). No tiene parámetros: recibe solo `TZ` y `PAINEL_REDES_PERMITIDAS`.

1. Rechaza ejecutarse como root.
2. Verifica que cada red de `PAINEL_REDES_PERMITIDAS` es privada, o pública aceptada con `REDE_PERMITIR_IP_PUBLICO=sim`.
3. Espera hasta 30 segundos por el socket del panel (`/nginx/painel.sock`) y por la copia del certificado (`/nginx/tls`).
4. Genera la configuración en `/run/nginx/nginx.conf` a partir de [`nginx/nginx.conf.modelo`](../../nginx/nginx.conf.modelo), cambiando el marcador de las redes por una línea `allow` para cada red permitida.
5. Pone en segundo plano la publicación de los recursos del contenedor: cada 5 s lee su grupo de control y guarda en `/estado/recursos.estado` (`0600`) la misma línea de doce números del vigía del ftp, cuando el uso cambia o cada minuto. Sin la carpeta `/estado`, avisa en el log y arranca de la misma manera.
6. Prueba la configuración y ejecuta el `nginx`.

**Resultado esperado:** la línea `nginx pronto em 8443/tcp (HTTPS), à frente do painel; redes permitidas: ...` en el log del contenedor.

<details>
<summary>Detalle técnico — mensajes de falla</summary>

| Mensaje | Cuándo |
|---|---|
| `FALHA: o nginx desta stack não roda como root: confira 'user' no compose.yaml` | el servicio fue modificado para arrancar como root |
| `FALHA: PAINEL_REDES_PERMITIDAS está vazia` | la variable llegó vacía al contenedor |
| `FALHA: PAINEL_REDES_PERMITIDAS: '…' não é rede privada. Por padrão esta stack é só para rede interna.` | la lista tiene red pública o `0.0.0.0/0`, con la opción de IP pública en `nao` |
| `FALHA: PAINEL_PROXY_CONFIAVEL: …` | la lista de proxies tiene red entera, valor que no es IPv4, dirección pública sin la opción de IP pública, dirección fuera de `PAINEL_REDES_PERMITIDAS` o más de 8 direcciones |
| `FALHA: PAINEL_REDES_PERMITIDAS: '…' não é uma rede IPv4 aceita` | con la opción en `sim`, la red es más ancha que `/8`, como `0.0.0.0/0` |
| `FALHA: REDE_PERMITIR_IP_PUBLICO deve ser 'nao' ou 'sim'` | la opción tiene otro valor |
| `FALHA: soquete do painel ausente em /nginx/painel.sock: o serviço painel está no ar?` | el panel no arrancó o `DATA_DIR/nginx` no está montada en los dos contenedores |
| `FALHA: certificado do painel ausente ou ilegível em /nginx/tls` | el panel no copió el certificado, o el permiso de la carpeta fue modificado a mano |
| `FALHA: configuração do nginx recusada` | el modelo fue editado y quedó inválido; el error del `nginx -t` aparece justo arriba |

La configuración generada queda en `tmpfs` y desaparece cuando el contenedor se detiene: quien manda es el modelo, dentro de la imagen. `127.0.0.1` entra siempre en la lista de redes, para el healthcheck.

</details>

---

<a name="nginx-saude"></a>

## 🩺 `nginx/saude.sh`

Es el healthcheck del contenedor de nginx, instalado como `/usr/local/sbin/allsafe-nginx-saude`. No se llama directamente: Docker lo ejecuta a intervalos.

<details>
<summary>Detalle técnico — qué verifica</summary>

Abre una conexión TLS de verdad en `127.0.0.1:8443`, desde dentro del contenedor, y pide `/saude`. Solo considera saludable si la respuesta es `HTTP/1.1 200` con el cuerpo `ok`. Como la solicitud pasa por nginx y llega al panel por el socket, una sola prueba verifica los dos. La cadena del certificado no se verifica, para que la prueba valga también con certificado de una autoridad interna.

</details>

---

<a name="ftp-user"></a>

## 👥 `ftp/usuario.sh`

Instalado en las imágenes del FTP y del panel como `/usr/local/sbin/allsafe-ftp-user`. No se llama directamente: use el [`manage-user.sh`](../../manage-user.sh) o el [panel](panel.md#usuarios).

<details>
<summary>Detalle técnico — qué hace dentro del contenedor</summary>

- Acepta `add|passwd|pasta|del|list|tls-dispensar|tls-exigir|tls-lista [usuario] [pasta] [perfil]`, con la carpeta solo en el `add` y en el `pasta` y el perfil solo en el `add`, `perfil <usuario> [completo|envio|soenvio|leitura]`, `ajustar`, y `limites <usuario> [sessoes=N] [download=KB] [envio=KB] [horario=HHMM-HHMM] [baixar=N] [tentativas=N] [minutos=N] [enviar=1]`, y valida el nombre (`^[a-z_][a-z0-9_-]{0,31}$`).
- La carpeta, cuando se informa, tiene hasta 4 niveles separados por `/`; cada nivel coincide con `[A-Za-z0-9_][A-Za-z0-9._-]{0,63}`. Fuera de eso, responde `Pasta invalida: ...` y sale con código `1`, antes de leer la contraseña.
- Lee la contraseña del `stdin` y rechaza menos de 12 caracteres con `Senha deve ter pelo menos 12 caracteres`.
- `add` rechaza nombre que ya existe (`Usuario ja existe`), verifica la carpeta nivel por nivel (enlace simbólico o archivo en la ruta: `Pasta recusada: ...`), crea los niveles que faltan con dueño `ftpdata` y modo `0750` y registra el usuario con `pure-pw useradd`, con la carpeta como directorio del `chroot`. Sin la carpeta, usa `/data/<usuario>`.
- Si otro usuario tiene la misma carpeta, una de arriba o una de dentro, el `add` concluye y escribe `Aviso: /data/<pasta> e dividida com o usuario <nome> ...`, una línea por usuario.
- `add` y `passwd` pasan al `pure-pw` la opción `-C` con el `FTP_MAX_CLIENTS` del contenedor, que define el costo del hash `argon2id` de la contraseña; un valor que no es entero mayor que cero se detiene con `FTP_MAX_CLIENTS deve ser um inteiro maior que zero` y código `1`.
- El perfil es la identidad de sistema guardada en el registro: `completo` es `ftpdata:ftpdata`, `envio` es `ftpenvio:ftpdata`, `soenvio` es `ftpsoenvio:ftpsoenvio` y `leitura` es `ftpleitura:ftpleitura`. `add` sin perfil crea `completo`; perfil fuera de los cuatro se detiene con `Perfil invalido: use completo, envio, soenvio ou leitura` y código `1`, antes de leer la contraseña.
- En el `soenvio`, el directorio del `chroot` guardado en el registro es el área de entrada, `/data/.entrada/<usuario>` (`0700` del `ftpsoenvio`, dentro de `/data/.entrada`, `0700` del `root`), y la carpeta del usuario va en el campo de descripción, sin el `/data/`. El `list` muestra las dos: `<usuario>`, `/data/.entrada/<usuario>/./` y la carpeta. El área que pasa por enlace simbólico, o que existe y no es carpeta, se detiene con `Area de entrada recusada: ...` y código `1`.
- Quien mueve el archivo es el [`ftp/entrada.pl`](../../ftp/entrada.pl), instalado como `/usr/local/lib/allsafe/entrada.pl` y cargado por el vigía: abre el origen y el destino nivel por nivel a partir de `/data`, sin seguir enlace simbólico, enlaza el archivo en el destino con `link()`, que no sustituye lo que existe, verifica que es el mismo archivo, lo pasa al `ftpdata` y lo saca del área. El nombre repetido recibe `-AAAAMMDD-HHMMSS` antes de la extensión, y un número cuando hasta ese se repite. Llamado como programa, con el usuario y la carpeta, entrega lo que quedó en el área y sale con `1` si algo no pudo ser entregado.
- `perfil` sin el nombre del perfil muestra el del usuario. Con él, guarda solo el uid y el gid del usuario, con `pure-pw usermod -u -g`: la contraseña, la carpeta y los archivos no cambian. Entrar en el `soenvio` o salir de él cambia también el directorio del `chroot`: al entrar, se crea el área de entrada; al salir, lo que quedó en ella se entrega a la carpeta del usuario y se borra; si algo no pudo ser entregado, el área queda, con `Aviso: ficou em /data/.entrada/<usuario> o que nao pode ser entregue em /data/<pasta>.`
- Después de `add`, `perfil`, `pasta` y `del`, el modo de cada carpeta de usuario se rehace según quién la alcanza: `0750` solo con `completo`, más escritura del grupo y el bit de permanencia con un `envio` (`1770`), más lectura para los otros con un `leitura` (`0755` o `1775`). Las carpetas de dentro acompañan cuando el modo cambia; la carpeta que salió del registro vuelve a lo que los otros usuarios piden.
- `ajustar` es del inicio del servicio `ftp`: rehace el modo de las carpetas, pasa al `ftpdata` las carpetas y los archivos de un solo nombre que todavía son del `ftpenvio`, entrega lo que quedó en el área de entrada de cada `soenvio` y borra de ella las carpetas vacías. No es para uso con sesión abierta.
- `passwd` usa `pure-pw passwd`; `del` usa `pure-pw userdel`, **no** borra la carpeta y dice cuál es. En el `soenvio`, entrega antes lo que quedó en el área de entrada y borra el área. Quien borra la carpeta junto con el usuario es el panel, después del `del`: [Panel web](panel.md#usuarios).
- `pasta` exige usuario que existe (`Usuario nao existe: <nome>`), verifica y crea la carpeta como el `add` y guarda solo el directorio del usuario, con `pure-pw usermod -d`, o, en el `soenvio`, solo la descripción, con `-c`: la contraseña y los demás campos del registro no cambian, y ningún archivo se mueve ni se borra. Avisa de la carpeta compartida como el `add`.
- `passwd` del usuario inicial (`FTP_USER`) guarda también `/auth/senha-inicial.trocada` (`0600`), solo con su nombre: es lo que hace que el entrypoint mantenga esa contraseña mientras el secreto no cambie.
- `del` del usuario inicial guarda `/auth/usuario-inicial.criado` y borra la marca de la contraseña: el entrypoint no lo crea de nuevo. `add` con su nombre guarda las dos marcas: el usuario vuelve con la contraseña informada.
- `tls-dispensar` y `tls-exigir` ponen y quitan el nombre de `/auth/sem-tls.lista` (`0600`), un nombre por línea, en orden. Solo aceptan usuario que existe: si no, `Usuario nao existe: <nome>` y código `1`. La lista se guarda en un archivo al lado y se cambia de nombre, para que nunca se lea por la mitad, y en cada escritura salen de ella los nombres que ya no están en el registro. `del` quita al usuario de la lista; `tls-lista` la muestra. El FTP relee la lista cada segundo: la modificación vale en instantes, sin reiniciar.
- `limites` exige usuario que existe y verifica todos los pares antes de guardar: `sessoes` de 1 a 99999, `download` y `envio` de 1 a 10000000, `baixar` de 1 a 8 y `horario` en `HHMM-HHMM`, con inicio distinto del fin. El valor fuera de la regla se detiene con `Limite invalido: ...` y código `1`; clave desconocida o par sin `=`, con el uso y código `2`. Sesiones, tasas y horario van al registro con `pure-pw usermod` (`-y`, `-t`, `-T` y `-z`), y el valor vacío quita el límite; `baixar` va a `/auth/limites.lista` (`0600`), una línea `<usuario> baixar=<n>` por usuario, guardada al lado y cambiada de nombre como la lista del TLS. Sin ningún par, muestra los límites, con las tasas en KB por segundo y el horario con cuatro dígitos de cada lado. `del` quita al usuario de la lista.
- `limites` con `enviar=1` da al usuario el permiso de enviar archivos por el panel, y `enviar=` lo quita; otro valor se detiene con `Limite invalido: enviar aceita vazio ou 1`. El par va a la línea del usuario en `/auth/limites.lista`, no toca el registro del FTP y el panel lo lee en cada envío: vale en el acto. Vea [Enviar archivo por el panel](panel.md#enviar-arquivo).
- `endereco-bloquear` y `endereco-liberar` pasan lo que recibieron por el [`ftp/endereco.pl`](../../ftp/endereco.pl) y guardan o borran el archivo en la escritura única: dirección en `/auth/enderecos/<endereco>`, hasta 10.000, y prefijo en `/auth/prefixos/<rede>_<tamanho>`, hasta 1.000, los dos `0600`, con `manual` al final de la línea. Los días van de 1 a 3650; sin ellos, vale `BLOQUEIO_ENDERECO_DIAS`. Errores, con código `1`: `Endereco invalido: use um IPv4, um IPv6 ou um prefixo, como 203.0.113.7, 2001:db8::7 ou 203.0.113.0/24`, `Endereco nao bloqueavel: <texto> e do proprio servidor`, `Prazo invalido: de 1 a 3650 dias` y `Teto de <n> enderecos bloqueados: libere algum antes` (o `prefixos`).
- `retencao` exige usuario que existe y verifica los pares antes de guardar: `ultimos` de 1 a 100000 y `dias` de 1 a 3650. Los dos van a la línea del usuario en `/auth/limites.lista`, sin tocar los otros pares de ella, y el valor vacío quita esa parte. Sin ningún par, muestra la regla en dos líneas, `ultimos=` y `dias=`. El comando solo guarda: quien borra los archivos es el panel, cada `PAINEL_RETENCAO_MINUTOS`. `pasta` quita la regla del usuario y avisa en una línea más: fue activada mirando la carpeta anterior. Vea [Limpieza automática](panel.md#limpeza).
- Después de cada cambio, regenera el `pureftpd.pdb` con `pure-pw mkdb` y mantiene los dos archivos en `0600`.
- Antes de modificar, toma el bloqueo `/auth/.lock` (`flock`, espera hasta 30 segundos): el FTP, el `manage-user.sh` y el panel nunca escriben al mismo tiempo.
- `list` pasa el archivo por la variable `PURE_PASSWDFILE`, porque el `pure-pw list` no acepta `-f` justo después de la acción.
- Uso inválido: muestra las formas aceptadas, `Uso: ... add|passwd|pasta|del|list|tls-dispensar|tls-exigir|tls-lista [usuario] [pasta] [perfil]`, `... perfil <usuario> [completo|envio|soenvio|leitura]`, `... limites <usuario> [sessoes=N] [download=KB] [envio=KB] [horario=HHMM-HHMM] [baixar=N] [tentativas=N] [minutos=N] [enviar=1]`, `... retencao <usuario> [ultimos=N] [dias=N]`, `... bloqueios [usuario]`, `... desbloquear <usuario> [origem]`, `... enderecos`, `... endereco-bloquear <endereco ou prefixo> [dias]` y `... endereco-liberar <endereco ou prefixo>`, y sale con código `2`.

</details>

---

<a name="apoio"></a>

## 🧩 Scripts de apoyo

No se ejecutan: otros scripts los cargan con `source`.

| Script | Función | Quién lo usa |
|---|---|---|
| [`scripts/rede-privada.sh`](../../scripts/rede-privada.sh) | `ip_privado` y `cidr_privado` aceptan solo `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12` y `192.168.0.0/16`; `ip_utilizavel` y `cidr_utilizavel` dicen qué pasa con la opción de IP pública (IPv4 de `1` a `223` en el primer octeto, red de `/8` a `/32`); `exigir_ip` y `exigir_rede` aplican la regla y escriben la `FALHA`; `conferir_opcao_ip_publico` rechaza valor fuera de `nao` y `sim`; `aviso_ip_publico` escribe el `ALERTA` | `deploy.sh`, `tests/testar.sh`, `ftp/entrypoint.sh`, `painel/entrypoint.sh` y `nginx/entrypoint.sh` |
| [`scripts/ambiente.sh`](../../scripts/ambiente.sh) | `env_valor <chave> [padrão]`: lee una clave del `.env` sin ejecutar el archivo; la última ocurrencia vale, como en Compose. `env_gravar <chave> <valor>`: cambia la línea de la clave o la agrega al final, sin reescribir cuando el valor ya es el pedido | `deploy.sh`, `manage-user.sh`, `painel-senha.sh`, `backup.sh`, `restaurar.sh`, `validate.sh` y `testar.sh` |

---

⬅️ [Secretos](secretos.md) · 🏠 [Documentación](README.md) · ➡️ [Operación](operacion.md)
