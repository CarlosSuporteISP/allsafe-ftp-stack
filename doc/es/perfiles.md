# 🎚️ Perfiles de capacidad — allsafe-ftp-stack

[![English](https://img.shields.io/badge/English-6e7781?style=for-the-badge)](../en/profiles.md)
[![Português (Brasil)](https://img.shields.io/badge/Portugu%C3%AAs_(Brasil)-6e7781?style=for-the-badge)](../pt-BR/perfis.md)
[![Español](https://img.shields.io/badge/Espa%C3%B1ol-0969da?style=for-the-badge)](perfiles.md)

↩ [README del proyecto](../../README.es.md) · [Índice de la documentación](README.md)

## 💡 En pocas palabras

Un perfil es un tamaño predefinido de servidor. Son cinco, del pequeño al extendido: `small`, `medium`, `large`, `xlarge` y `extended`. Usted elige el tamaño al momento de levantar la stack y el perfil ajusta por sí solo cuántos equipos pueden conectarse al mismo tiempo y cuánta CPU y memoria puede usar el servidor. El `.env` guarda lo que es del cliente (IP, puertos, certificado); el perfil guarda solo el dimensionamiento, que el `deploy.sh` escribe en el `.env` cuando usted elige el tamaño. Antes de escribir, verifica si el servidor soporta el tamaño pedido.

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

[Cómo usar](#como-usar) · [Tabla de perfiles](#tabela-de-perfis) · [¿El servidor lo soporta?](#o-servidor-aguenta) · [Campos dimensionados](#campos-dimensionados) · [Tiempo de arranque](#tempo-de-subida) · [Rango pasivo y firewall](#faixa-passiva-e-firewall)

</details>

---

<a name="como-usar"></a>

## 🚀 Cómo usar

Pase el nombre del perfil en `--size` al [`deploy.sh`](../../deploy.sh). Este guarda los límites del perfil en el `.env`, con el nombre en `FTP_PROFILE`, y aplica de nuevo la stack. La instalación nace con el `small`; sin `--size`, el perfil en uso sigue vigente:

```bash
./deploy.sh --size medium                 # guarda el medium en el .env y aplica de nuevo
./deploy.sh                               # sigue en el medium
./deploy.sh --size xlarge --check-only    # solo valida el xlarge, no guarda ni levanta nada
```

**Resultado esperado:** con `--check-only`, el mensaje `OK: perfil 'xlarge', rede privada, recursos do servidor e compose validados; nada foi alterado.`; sin él, el resumen `Pronto: FTP, painel e nginx no ar (healthy), perfil 'medium'.` con el nuevo rango pasivo.

---

<a name="tabela-de-perfis"></a>

## 📐 Tabla de perfiles

| Perfil | Host de referencia | Sesiones simultáneas | Uso típico |
|---|---|---|---|
| [`small`](../../profiles/small.env) | 2 vCPU · 2 GB · SSD | hasta ~50 (`FTP_MAX_CLIENTS=50`) | proveedor pequeño o mediano; la copia de seguridad de configuración es tráfico pequeño y esporádico: **cubre la mayoría de los casos** |
| [`medium`](../../profiles/medium.env) | 4 vCPU · 4 GB · SSD | hasta ~120 | recolección nocturna por lotes de ~50 a ~200 equipos |
| [`large`](../../profiles/large.env) | 8 vCPU · 8 GB · NVMe | hasta ~300 | más de 200 equipos o varios recolectores enviando copias de seguridad al mismo tiempo |
| [`xlarge`](../../profiles/xlarge.env) | 16 vCPU · 16 GB · NVMe | hasta ~600 | operación grande, con varias regiones o varios recolectores en el mismo servidor |
| [`extended`](../../profiles/extended.env) | 32 vCPU · 32 GB · NVMe | hasta ~1200 | el porte mayor: servidor dedicado, miles de equipos enviando en ventanas cortas |

Los números son **puntos de partida**, no garantía de capacidad. El FTP de copias de seguridad rara vez necesita más que `small`; suba de perfil solo si ve `421 Too many connections` o saturación de CPU o de memoria del contenedor. Los cinco perfiles existen para que la misma stack sirva en cualquier máquina, de la VPS pequeña al servidor dedicado.

<details>
<summary>Detalle técnico — los valores de cada perfil</summary>

| Campo | `small` | `medium` | `large` | `xlarge` | `extended` |
|---|---|---|---|---|---|
| `FTP_MAX_CLIENTS` | `50` | `120` | `300` | `600` | `1200` |
| `FTP_MAX_CLIENTS_PER_IP` | `8` | `12` | `24` | `48` | `96` |
| `FTP_PASSIVE_PORT_START` | `30000` | `30000` | `30000` | `30000` | `30000` |
| `FTP_PASSIVE_PORT_END` | `30049` | `30149` | `30399` | `30799` | `31599` |
| Puertos pasivos | 50 | 150 | 400 | 800 | 1600 |
| `FTP_MEMORY_LIMIT` | `256M` | `512M` | `1G` | `2G` | `4G` |
| `FTP_CPU_LIMIT` | `1.0` | `2.0` | `4.0` | `8.0` | `16.0` |
| `FTP_PIDS_LIMIT` | `128` | `256` | `512` | `1024` | `2048` |
| `FTP_NOFILE` | `16384` | `32768` | `65536` | `131072` | `262144` |

El `deploy.sh --size <perfil>` copia cada `CLAVE=VALOR` de `profiles/<perfil>.env` al `.env` (cambia la línea de la clave o la agrega al final) y guarda `FTP_PROFILE=<perfil>`. Compose lee solo el `.env`: los límites valen también para un `docker compose up -d` directo. Cambiar de perfil recrea el contenedor del FTP, porque cambia el rango de puertos publicado; los datos quedan. Los perfiles no tocan el panel ni el nginx: sus límites son los mismos en cualquier porte.

> ¿Instaló con `--size medium` o `large` antes de la versión `0.6.0`? Ejecute una vez `./deploy.sh --size <perfil>` para guardar el perfil en el `.env`.

</details>

---

<a name="o-servidor-aguenta"></a>

## 🧮 ¿El servidor lo soporta?

Antes de crear o modificar el `.env`, el `deploy.sh` compara lo que pide el perfil con lo que tiene el servidor. Si el servidor tiene menos CPU que `FTP_CPU_LIMIT` o menos memoria que `FTP_MEMORY_LIMIT`, el comando se detiene y **nada se modifica**: el `.env` queda como estaba y los contenedores siguen en marcha.

```bash
./deploy.sh --size extended --check-only
```

**Resultado esperado**, en un servidor de 4 CPU: `ERRO: o perfil 'extended' pede 16.0 CPUs (FTP_CPU_LIMIT) e este servidor tem 4. Use um perfil menor com --size ou ajuste FTP_CPU_LIMIT em .env.` Para la memoria, el mensaje es el mismo, con `FTP_MEMORY_LIMIT` y el total del servidor en MiB.

| Perfil | El servidor debe tener, como mínimo |
|---|---|
| `small` | 1 CPU · 256 MB |
| `medium` | 2 CPU · 512 MB |
| `large` | 4 CPU · 1 GB |
| `xlarge` | 8 CPU · 2 GB |
| `extended` | 16 CPU · 4 GB |

Ese mínimo es solo lo que el contenedor del FTP puede ocupar. El host de referencia de la [tabla de perfiles](#tabela-de-perfis) tiene el doble, para que sobre para el sistema, el panel, el nginx y el disco.

---

<a name="campos-dimensionados"></a>

## 🎛️ Campos dimensionados

| Campo | Efecto |
|---|---|
| `FTP_MAX_CLIENTS` | opción `-c` del `pure-ftpd`: tope de conexiones simultáneas. También es la opción `-C` del `pure-pw`, que define el costo de la contraseña guardada: [Seguridad](seguridad.md#custo-das-senhas) |
| `FTP_MAX_CLIENTS_PER_IP` | opción `-C`: tope por IP de origen |
| `FTP_PASSIVE_PORT_START` y `FTP_PASSIVE_PORT_END` | rango de puertos de datos (modo pasivo), publicado **1:1** en el host |
| `FTP_MEMORY_LIMIT` y `FTP_CPU_LIMIT` | `mem_limit` (sin swap) y `cpus` del servicio |
| `FTP_PIDS_LIMIT` | `pids_limit` (barrera contra _fork bomb_) |
| `FTP_NOFILE` | `ulimit nofile` (soft igual a hard) |

Descripción completa de cada variable en [Configuración](configuracion.md).

---

<a name="tempo-de-subida"></a>

## ⏱️ Tiempo de arranque

Docker publica los puertos pasivos uno por uno. En los perfiles grandes, levantar, cambiar de perfil y eliminar llevan minutos, y no segundos. El `deploy.sh` avisa (`Publicando 1600 portas passivas: a subida pode levar alguns minutos.`) y espera el tiempo proporcional al número de puertos antes de desistir.

| Perfil | Puertos pasivos | Espera máxima del `deploy.sh` |
|---|---|---|
| `small` | 50 | 192 s |
| `medium` | 150 | 217 s |
| `large` | 400 | 280 s |
| `xlarge` | 800 | 380 s |
| `extended` | 1600 | 580 s |

La espera máxima es de 180 s más un cuarto de segundo por puerto pasivo. En la validación de la versión `0.7.0`, en un host de 16 CPU, la instalación del `small` terminó en 25 s y el cambio al `extended` en cerca de 200 s; su tiempo varía con la máquina. Volver del `extended` a un perfil menor o eliminar la stack también lleva minutos, porque Docker deshace los mismos puertos uno por uno. Programe el cambio de perfil fuera de la ventana de copias de seguridad.

---

<a name="faixa-passiva-e-firewall"></a>

## ⚠️ Rango pasivo y firewall

Cada perfil amplía el rango pasivo junto con `FTP_MAX_CLIENTS` (`small` 50 puertos, `medium` 150, `large` 400, `xlarge` 800, `extended` 1600). Al cambiar de perfil:

1. libere el nuevo rango, de `30000` hasta el final del perfil, en TCP, en el firewall del host, solo para las subredes de gestión;
2. si hay NAT, garantice el mapeo **1:1** del rango completo;
3. mantenga `FTP_PASSIVE_IP` con la IP que el cliente realmente alcanza.

**Resultado esperado:** después del `./deploy.sh --size <perfil>`, `docker compose ps` muestra el nuevo rango publicado.

> ⚠️ No coloque IP, credenciales ni particularidades de cliente en los archivos de perfil: eso pertenece al `.env` y a la carpeta `.secrets/` locales. Vea [Secretos](secretos.md).

---

⬅️ [Configuración](configuracion.md) · 🏠 [Documentación](README.md) · ➡️ [Arquitectura](arquitectura.md)
