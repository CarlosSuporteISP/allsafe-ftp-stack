# 📸 Application screenshots — allsafe-ftp-stack

🌐 **English** · [Português (Brasil)](../../pt-BR/aplicacao/README.md)

↩ [Project README](../../../README.md) · [Documentation index](../README.md)

## 💡 In a few words

Every screen of the web panel, menu by menu, with a screenshot of each one and an explanation of what can be done on it. The screenshots are real captures of version **0.31.1**, in dark theme and in English, with example users, such as `olt-centro`, `switch-core` and `roteador-borda`. The panel follows the light or dark theme of the system and also opens in Portuguese: see [Language](#idioma). Click any screenshot to open it at full size.

The panel has a sign-in screen, seven tabs for whoever administers it (Overview, Users, Files, Server, Security, Blocks and Log) and one screen for the FTP user, which changes with the profile of the account: My files or File upload. The administrators are in the Users tab, together with the FTP accounts. How to open it, how to create administrators and what protects the panel are in [Web panel](../panel.md).

> 🧱 **Private network use only:** by default, the panel opens only on a private IP, behind a firewall, off the internet. See [Security](../security.md#rede-privada).

<details>
<summary>Contents — click to expand</summary>

[Sign in](#entrar) · [Overview](#visao-geral) · [Users](#usuarios) · [Administrators](#administradores) · [Files](#arquivos) · [My files](#meus-arquivos) · [Server](#servidor) · [Security](#seguranca) · [Blocks](#bloqueios) · [Log](#atividade) · [Language](#idioma) · [How the screenshots were made](#como-foram-feitas)

</details>

---

<a name="entrar"></a>

## 🚪 Sign in

<a href="images/entrar.png"><img src="images/entrar.png" alt="Sign-in screen of the panel: on the left, the logo, the headline Backups and files, kept in one place, four points about the stack and the scene of OLT, radio, router, switch, company, person and camera sending over FTPS to the folders of the server, with the Pause motion button; on the right, the title Sign in to the panel, the User and Password fields, the Sign in button, the note that use is restricted to authorized people and the PT and EN buttons" width="100%"></a>

<sub><b>v0.31.1</b> · sign-in screen · captured on 2026-10-10</sub>

**What it is for:** checking the user name and the password before showing any data of the stack. It is the same screen for whoever administers and for the FTP user.

**How to get there:** open `https://<panel address>:8443` in the browser. Without a session, any address of the panel leads to this screen.

| Screen item | What it does |
|---|---|
| **User** | Takes the name of the administrator or the name of the FTP user. On the first installation, the administrator is the one in `PAINEL_ADMIN_USER` (`admin`, if it was not changed) |
| **Password** | Takes the password of the account. The one of the first administrator is in `.secrets/painel-admin-inicial-senha.txt`; the one of the FTP user is the same the device uses |
| **Sign in** | Checks the account: the administrator goes to the Overview tab and the FTP user, to the My files screen |
| Text below the title | Says who signs in through this screen. With `PAINEL_ACESSO_USUARIOS_FTP=nao`, it becomes `Administration panel of the stack.` |
| Note below the button | Reminds that use is restricted to authorized people and that sign-in attempts are recorded. The sign-in screen does not say how the installation is published: only the administrator reads that, after signing in |
| **PT** · **EN** | Switch the language of the screen before sign-in; the choice is kept in the browser: see [Language](#idioma) |
| Left side | Presents the stack: the headline, three points (each device confined to its own folder, panel over HTTPS only and the session time without use) and the scene in which router, switch, OLT and radio send the backup over FTPS to the folders. On a narrow screen, only the logo and the headline remain |
| **Pause motion** | Stops the animation of the scene and resumes it; with the system set to reduce motion, the scene already opens stopped |

<details>
<summary>Sign in ➜ Sign-in refused — click to expand</summary>

### Sign in ➜ Sign-in refused

<a href="images/entrar-recusada.png"><img src="images/entrar-recusada.png" alt="Sign-in screen with the message Could not sign in above the User and Password fields" width="100%"></a>

<sub><b>v0.31.1</b> · sign-in screen, sign-in refused · captured on 2026-10-10</sub>

| Message | When it appears | What to do |
|---|---|---|
| Could not sign in. | The user name or the password is wrong; the screen does not say which of the two | Check both fields and try again |
| Too many attempts. Wait a few minutes and try again. | Five wrong sign-ins from the same address in 15 minutes | Wait for the block to pass; the right account is refused too while it lasts |
| The page expired. Try again. | The screen stayed open too long before being submitted | Submit again |
| address blocked for too many user name and password errors | The address is on the list of the Blocks tab: by default, it went over 5 user name and password errors in 24 hours, on FTP or on the panel. It is plain text, without the sign-in screen, on any address of the panel | Ask an administrator to unblock it: see [Blocks](#bloqueios) |

</details>

<details>
<summary>Technical detail — sign-in and session</summary>

- Route `GET /entrar` shows the form; `POST /entrar` checks the administrator account first, by the `scrypt` hash in `DATA_DIR/painel/administradores`, and then, if the sign-in of FTP users is on, the FTP account, by a login on the FTP server itself.
- Response `401` for a wrong user name or password, `429` for a blocked address and `400` for an expired form. Each case writes `entrada_falha` or `entrada_bloqueada` to the [audit log](../panel.md#auditoria), without the name that was typed.
- The address on the block list gets `403` in plain text on every route, even with an open session, with the event `recusa_endereco`: see [Blocking by address](../security.md#bloqueio-por-endereco).
- Signing in with the FTP account takes a few seconds: it is the time the FTP server spends checking the password. See [FTP user in the panel](../panel.md#usuario-ftp).
- The session lives in the cookie `__Host-sessao` (`Secure`, `HttpOnly`, `SameSite=Strict`) and closes after 4 hours without use or after 12 hours, whichever comes first.
- A submission is only accepted when it comes from the panel itself: the `Origin` header has to be the address of the panel. Details in [Web panel](../panel.md#protecoes).

</details>

---

<a name="visao-geral"></a>

## 📊 Overview

<a href="images/visao-geral.png"><img src="images/visao-geral.png" alt="Overview tab with the menu on the left, in two groups, the FTP server band, which says Up and TLS required on sign-in, the four measurements Users, Space used, Last upload and FTP certificate, each with the shortcut to the detail, the Server and containers card, with the CPU and the memory of the server and of the containers, the charts Files received per day, Last upload per user and Space per folder, the Recent activity card, with the last six records, and the Details to set up the device card" width="100%"></a>

<sub><b>v0.31.1</b> · Overview menu · captured on 2026-10-10</sub>

**What it is for:** seeing at once whether the FTP is up and which details to type into the device that will send the backup.

**How to get there:** it is the first screen of the administrator after sign-in; menu ➜ **Overview**.

| Screen item | What it shows |
|---|---|
| **FTP server** | `Up` or `Down`, and the TLS mode in use, with a shortcut to the Security tab |
| **Users** | Number of FTP users, with a shortcut to the Users tab |
| **Space used** | Sum of the users' folders and the free space on the disk, with a shortcut to the folders, in the Files tab |
| **Last upload** | Date of the newest file among all folders, with a shortcut to the Files tab |
| **FTP certificate** | The date the certificate expires and how many days are left, with a shortcut to the fingerprint, in the Security tab |
| **Server and containers** | CPU and memory of the whole server and of the three containers of the stack, in use and allocated, with a shortcut to the Server tab |
| **Files received per day** | One column per day for the last 14 days, with the total of the period on top. It counts what is in the folders now, by the date of each file: what was deleted or replaced is not counted |
| **Last upload per user** | The users split by the date of the newest file in the folder of each one: in the last 24 hours, between 1 and 7 days, more than 7 days ago and with no file in the folder. Below, the list of those who have not uploaded for more than 7 days, with a shortcut to the Users tab |
| **Space per folder** | The folders that take the most space, from the largest to the smallest, each with the bar, the size and the number of files, and the shortcut to the folder in the Files tab |
| **Recent activity** | The last six records of the panel, with the time and the address of whoever did it, and the shortcut to the Log tab |
| **Details to set up the device** | Server, control port, passive ports, protocol and where the user comes from: what to fill in on the device |
| Menu of every screen | On the left, on a screen 1280 px wide or more: the symbol and the name, the seven tabs in two groups (**Operation** and **System**), each with its icon and the tab in use marked, and, at the bottom, the language buttons **PT** and **EN**, the name and the role of whoever signed in and the **Sign out** button. On a narrower screen, the menu becomes a band at the top, with the tabs in a row that scrolls sideways. With the installation published, a warning sign stays next to **Security** |
| Title of each tab | The name of the tab and a sentence that says what it is for |
| Footer of every screen | The version of the stack, the private network reminder (or, for the administrator only, how the installation is published), the authorship and the address of the official repository |

Nothing is changed through this tab.

<details>
<summary>Overview ➜ Alert of user without TLS — click to expand</summary>

### Overview ➜ Alert of user without TLS

<a href="images/visao-geral-alerta-tls.png"><img src="images/visao-geral-alerta-tls.png" alt="Overview tab with the alert at the top that two users, central-pabx and radio-antigo, sign in to FTP without TLS, and the FTP server card showing TLS required on sign-in, with per-user exception" width="100%"></a>

<sub><b>v0.31.1</b> · Overview menu, alert of user without TLS · captured on 2026-10-10</sub>

| Alert at the top of the screen | When it appears | How it goes away |
|---|---|---|
| How many and which users sign in to FTP without TLS | With at least one user exempt from TLS | When the last one is required to use TLS again, in [Users ➜ Require TLS](#usuarios) |
| The FTP accepts password and file in plain text | With `FTP_TLS_MODE` at `0` or `1` | When the variable goes back to `2` or `3` |

The same alert opens the Security tab. The conditions for exempting a user are in [TLS per user](../security.md#tls-por-usuario) and those of FTP without TLS, in [Device without TLS](../security.md#ftp-sem-tls).

</details>

<details>
<summary>Technical detail — where each number comes from</summary>

- Route `GET /`.
- `Up` is the answer of the control port of the `ftp` service, over the internal network of the stack (`ftp:2121`).
- Users come from the FTP user database (`DATA_DIR/auth`); space, number of files and last upload are read from `DATA_DIR/dados`.
- The **Server and containers** card shows the same readings as the [Server tab](#servidor).
- Server, port and passive range are the values of `FTP_PASSIVE_IP`, `FTP_PORT` and `FTP_PASSIVE_PORT_*` in the `.env`: see [Configuration](../configuration.md#rede-e-portas).

</details>

---

<a name="usuarios"></a>

## 👥 Users

<a href="images/usuarios.png"><img src="images/usuarios.png" alt="Users tab with the New user button and the list of accounts: first the administrator admin, with the tag you, then the FTP users, each with the profile below the name and the tags initial, limits, cleanup and blocked, the folder, with the tag shared on two of them, usage, files, last upload, the TLS column, with required on every row, the actions Edit, Exempt from TLS, Change password and Remove and, below the list, the collapsed section How profiles and tags work" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu · captured on 2026-10-10</sub>

**What it is for:** creating the account of each device or person, choosing its profile, choosing and changing the folder it is confined to, changing the password, giving it limits of its own, allowing file upload through the panel, turning on the automatic cleanup of old files, removing the block for wrong passwords and removing the account, with or without the folder, without the command line. It is also where the administrators of the panel are.

**How to get there:** menu ➜ **Users**.

| Screen item | What it does |
|---|---|
| **New user** | Opens the registration form, for an FTP user or an administrator |
| User and profile | Name of the account and, below it, its profile: Administrator, Full, Upload, Upload only or Read only. The tag `initial` marks the user created by the installation (`FTP_USER`) |
| Administrator rows | They stay at the top of the list, without folder or TLS, with the tag `you` on the account in use: see [Administrators](#administradores) |
| Folder | Where the files of that user are kept on the server. The address opens the folder in the Files tab |
| Tag `shared` | The folder is reached by more than one user: each one handles the files of the other as far as their profile allows |
| Tag `limits` | The user has a limit of their own, saved in **Edit**; hovering the mouse shows each one |
| Tag `cleanup` | Automatic cleanup is on for the user, in **Edit**: the panel deletes the old files of their folder on its own; hovering the mouse shows the rule |
| Tag `blocked` | The FTP is refusing the user for too many wrong passwords coming from one address; it goes away on its own at the end of the period, or in **Edit** |
| Usage · Files · Last upload | Space taken, number of files and date of the most recent upload |
| TLS column · **Exempt from TLS** · **Require TLS** | How the user signs in to FTP and the way to change it: see [Users ➜ TLS per user](#usuarios) |
| **Edit** | Opens the screen of the user, with the change of profile and of folder, the limits of their own, the automatic cleanup and the blocks |
| **Change password** | Opens the password change form of that user |
| **Remove** | Opens the removal confirmation of that user, including the initial one |
| **How profiles and tags work** | Collapsed below the list: explains each profile, says in which folder of the server the users are confined and what the tags `shared`, `limits`, `cleanup`, `blocked` and `no TLS` mean |

The initial user has its password and folder changed and is removed like the others. Once removed, it does not come back on the next starts of the FTP; to have it again, create a user with the same name. The password changed here holds until the file `.secrets/ftp-usuario-inicial-senha.txt` is changed. See [Secrets](../secrets.md#trocar-a-senha).

The profile decides what the account does, on FTP and in the panel:

| Profile | On FTP | In the panel |
|---|---|---|
| Administrator | Not an FTP account | Every tab: see [Administrators](#administradores) |
| Full | Lists, downloads, uploads, creates folders, renames, deletes and overwrites | My files screen: browses, downloads, creates folders, renames and deletes; with the permission, uploads files |
| Upload | Lists, downloads, uploads and creates folders. Does not delete, rename or overwrite what has already arrived | My files screen: browses, downloads and creates folders; with the permission, uploads files |
| Upload only | Uploads and creates folders. Does not list or download anything, not even what it uploaded itself | File upload screen: the details for sending by FTP; with the permission, uploads files through it |
| Read only | Only lists and downloads | My files screen: browses and downloads; does not upload |

The permission to upload files through the panel is given user by user, in the **Limits** card of the **Edit** screen: see [Users ➜ Limits](#usuarios). Without it, the account only uploads by FTP.

The screen of each profile is in [My files](#meus-arquivos); the rules, the shared folder and what changes on a switch, in [Web panel](../panel.md#perfis).

<details>
<summary>Users ➜ New user — click to expand</summary>

### Users ➜ New user

<a href="images/usuarios-novo.png"><img src="images/usuarios-novo.png" alt="New user form with the Profile field, which lists Administrator, Full, Upload, Upload only and Read only, each with what it allows, the fields User name, Folder, Password and Repeat the password, the shared folder warning, the Device without TLS support box, unticked, with the plain text alert, and the Create user and Cancel buttons" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, New user form · captured on 2026-10-10</sub>

| Field | Required | What to fill in |
|---|---|---|
| Profile | Yes | Full, Upload, Upload only or Read only, for the FTP account. Administrator registers whoever administers the panel: see [Administrators ➜ New administrator](#administradores) |
| User name | Yes | Lowercase letters, numbers, `_` and `-`; starts with a letter or `_`; up to 32 characters |
| Folder | No | Left blank, it is the user name. When chosen, it stays inside `DATA_DIR/dados`, with up to 4 levels separated by `/`, and is created if it does not exist. The field suggests the folders that already exist |
| Password | No | 12 characters or more. Left blank, the panel generates a strong password |
| Repeat the password | Only with the password filled in | The same password |
| **Device without TLS support** box | No | Tick it only for the old device that does not speak TLS: the user is born already exempt. Unticked, the user only signs in with TLS |

**Expected result:** the list comes back with the message `User created.` and the user already signs in over FTPS, without restarting the FTP, confined to the chosen folder and with the chosen profile.

> ⚠️ **Shared folder:** two users with the same folder, or with one inside the other, reach each other's files, each one as far as their profile allows. In the user list at the start of this section, `filiais/olt-norte` is inside `filiais`, the folder of a lookup account, with the Read only profile, and both carry the tag `shared`: the lookup account downloads what the OLT uploaded and does not write or delete anything. For one device not to reach the backup of another, give each one its own folder.

</details>

<details>
<summary>Users ➜ New user refused — click to expand</summary>

### Users ➜ New user refused

<a href="images/usuarios-novo-recusado.png"><img src="images/usuarios-novo-recusado.png" alt="New user form with the message There is already a user with this name above the fields" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, registration refused · captured on 2026-10-10</sub>

The panel returns the form with the reason at the top and nothing is created.

| Message | Reason |
|---|---|
| Invalid name. See the rule below the field. | The name breaks the rule of letters, numbers, `_` and `-` |
| There is already a user with this name. | The name is already in use |
| Invalid folder. See the rule below the field. | The folder breaks the rule, has more than 4 levels or a level starts with a dot |
| The two passwords do not match. | The two password fields differ |
| The password must have 12 to 128 characters. | Password too short or too long |

A folder that goes through a symbolic link, or through a name that already belongs to a file, is refused too, with the reason in the same band.

</details>

<details>
<summary>Users ➜ Password generated by the panel — click to expand</summary>

### Users ➜ Password generated by the panel

<a href="images/usuarios-senha-gerada.png"><img src="images/usuarios-senha-gerada.png" alt="User created screen with the password generated by the panel, here replaced by REDACTED, and the warning that it will not be shown again" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, generated password · captured on 2026-10-10</sub>

It appears when the two password fields are left blank, on registration or on a password change. The password is shown **only once**: copy it to the device or to the password vault before leaving the screen. In the screenshot, the value was replaced by `<REDACTED>`.

</details>

<details>
<summary>Users ➜ Edit — click to expand</summary>

### Users ➜ Edit

<a href="images/usuarios-editar.png"><img src="images/usuarios-editar.png" alt="Edit user screen of roteador-borda, with the Profile card, which lists the four FTP profiles, with what each one allows, and has the Save profile button, the Folder card, which shows the current folder and the New folder field, the TLS card, which says the user only signs in with TLS and has the Exempt from TLS button, the Limits card filled in with sessions, rates, hours, downloads through the panel, wrong passwords before the block and minutes of block, with the box that allows file upload through the panel, and the Automatic cleanup card, off" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, Edit user screen · captured on 2026-10-10</sub>

It gathers what changes in a user without creating it again. The name does not change: it is with it that the device signs in to FTP.

| Card | What it does |
|---|---|
| Top | Shows the user, leads to **Change password** and goes back to the list |
| **Blocks** | Only appears when the FTP is refusing the user for too many wrong passwords: see [Users ➜ Blocks](#usuarios) |
| **Profile** | Shows the profile of the account and switches to another of the four FTP profiles |
| **Folder** | Shows the current folder, with the number of files and the space taken, and changes the folder of the user |
| **TLS** | Says whether the user signs in with or without TLS and leads to the confirmation of the change: see [Users ➜ TLS per user](#usuarios) |
| **Limits** | Saves the user's own limits and the permission to upload files through the panel: see [Users ➜ Limits](#usuarios) |
| **Automatic cleanup** | Turns on, changes and turns off the rule that deletes the old files of the user's folder on its own: see [Users ➜ Automatic cleanup](#usuarios) |

**Profile change:** select the profile and click **Save profile**. The list comes back with the message `Profile changed. It applies on the user's next FTP sign-in.` The change closes the session of the user in the panel; the FTP session that is already open carries on with the previous profile until it ends. The card reminds of two points of care:

- **Upload:** the file belongs to the server as soon as it finishes arriving, and from then on the user does not delete it, rename it or overwrite it. A device that always uploads with the same file name needs the Full profile.
- **Upload only:** a repeated name does not replace the previous file, and the new one is stored with the date and time in its name. A device that uploads with a temporary name and renames at the end, or that checks the upload by listing the folder, needs another profile.

Administrator is not among the options: administrator and FTP user are separate registrations, and going from one to the other means removing the account and creating the other.

| Field of the Folder card | Required | What to fill in |
|---|---|---|
| New folder | Yes | The same rule as on registration: inside `DATA_DIR/dados`, with up to 4 levels separated by `/`; it is created if it does not exist |

**Expected result:** after **Change folder**, the list comes back with the message `Folder changed. The files of the previous folder stay in it.` The user lands in the new folder on the next FTP login, and their session in the panel is closed. With automatic cleanup on, the change turns the rule off, since it belonged to the previous folder, and the message ends with `Automatic cleanup was turned off: the rule belonged to the previous folder.`

| Message | Reason |
|---|---|
| This is already the user's folder. | The new folder is the same as the current one |
| Invalid folder. See the rule below the field. | The folder breaks the rule, has more than 4 levels or a level starts with a dot |

> ⚠️ **The files do not follow the change:** what was in the previous folder stays in it, neither moved nor deleted, and the user no longer reaches it.

</details>

<details>
<summary>Users ➜ Limits — click to expand</summary>

### Users ➜ Limits

<a href="images/usuarios-limites-gravados.png"><img src="images/usuarios-limites-gravados.png" alt="Users tab with the message Limits saved, they apply on the user's next FTP sign-in, and the tag limits next to the name roteador-borda" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, limits saved · captured on 2026-10-10</sub>

The **Limits** card of the **Edit** screen applies only to that user, whether it is the account of a device, which only uploads, or that of a person, who signs in, uploads and downloads. A blank field means no limit of its own: the one of the stack applies.

| Field | Where it applies | What to fill in |
|---|---|---|
| Simultaneous FTP sessions | FTP | From 1 to the `FTP_MAX_CLIENTS` of the stack |
| Download rate, in KB per second | FTP and the user's downloads through the panel | From 1 to 10,000,000 |
| Upload rate, in KB per second | FTP and the user's uploads through the panel | From 1 to 10,000,000 |
| Hours when FTP accepts sign-in: from · to | FTP and the user's sign-in to the panel | Start and end, in hours and minutes; it may cross midnight, such as `22:00` to `06:00` |
| Simultaneous downloads through the panel | Panel | From 1 to 8; left blank, 2 |
| Wrong FTP passwords before the block | FTP | From 1 to 100; `0`: this user is never blocked; left blank, the default of the stack |
| Minutes of block | FTP | From 1 to 1440; left blank, the default of the stack |
| **Allow this user to upload files through the panel**, to their folder, box | Panel | Ticked, the account uploads files through its screen, besides FTP. It applies to the Full, Upload and Upload only profiles; the Read only profile does not upload. Unticked, the user only uploads by FTP |

**Expected result:** after **Save limits**, the list comes back with the message `Limits saved. They apply on the user's next FTP sign-in.` and the tag `limits` next to the name; hovering the mouse over it shows each limit of the user. To remove a limit, clear the field and save again.

The upload permission applies immediately. A file uploaded through the panel is at most the size of `PAINEL_ENVIO_MAX_MB` (1024 MB, by default), follows the upload rate of the user and never replaces a file that already exists: see [My files ➜ Upload file](#meus-arquivos).

In the screenshot of the **Edit** screen, `roteador-borda` has 2 sessions, 2048 KB per second of download, 1024 of upload, sign-in from `22:00` to `06:00`, 1 download at a time through the panel and a 30-minute block on the third wrong password.

> ⚠️ **Upload rate and small files:** with the upload rate set, the server holds each uploaded file for about `256 ÷ rate` seconds. For a device that sends many small files, use a high rate or leave it blank. The values and what each limit changes for the user are in [Web panel](../panel.md#limites).

</details>

<details>
<summary>Users ➜ Automatic cleanup — click to expand</summary>

### Users ➜ Automatic cleanup

<a href="images/usuarios-editar-limpeza.png"><img src="images/usuarios-editar-limpeza.png" alt="Edit user screen of olt-centro at the Automatic cleanup card: the state Off, the fields Keep only the most recent files, with 30, and Delete the file older than this many days, with 60, the warning that the panel has no recycle bin, the Your current password field and the Save cleanup button" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, Automatic cleanup card · captured on 2026-10-10</sub>

The **Automatic cleanup** card of the **Edit** screen makes the panel delete, on its own, the old files of that user's folder and of the folders inside it. It starts turned off: with no rule saved, no file is deleted on its own.

| Field | Required | What to fill in |
|---|---|---|
| Keep only the most recent files | No | How many files stay in each folder, from 1 to 100,000; the oldest ones go. The count is per folder: with `30`, each folder keeps its 30 most recent files |
| Delete the file older than this many days | No | Days on the server, from 1 to 3,650, counted since the file arrived or was changed |
| Your current password | Yes | The password of whoever is using the panel, to confirm |

A blank field turns that rule off, and both blank turn the cleanup off. With both filled in, the file that goes past either one is deleted.

<a href="images/usuarios-limpeza-gravada.png"><img src="images/usuarios-limpeza-gravada.png" alt="Users tab with the message Automatic cleanup saved, it applies on the next run of the panel, and the tag cleanup next to the name olt-centro" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, automatic cleanup saved · captured on 2026-10-10</sub>

**Expected result:** after **Save cleanup**, the list comes back with the message `Automatic cleanup saved. It applies on the next run of the panel.` and the tag `cleanup` next to the name; hovering the mouse over it shows the rule. Saved with both fields blank, the message is `Automatic cleanup turned off. No file of this user is deleted on its own.`

In the screenshot, `olt-centro` keeps the 30 most recent files of each folder and no file older than 60 days.

| What the cleanup does | How |
|---|---|
| When it runs | On its own, every `PAINEL_RETENCAO_MINUTOS` minutes (60, by default); with `0`, the rule stays saved and is not applied, and the card says so |
| What never goes | Symbolic links and files or folders whose name starts with a dot |
| Subfolder | The one the cleanup empties goes with it; the folder of the user stays |
| Shared folder | The rule deletes the old files of every user that reaches the folder, and the card says who they are |
| Folder change | Turns the rule off, since it belonged to the previous folder |
| Record | Each run that deletes something is in the Log tab, with the user and the amount |

> ⚠️ **The cleanup cannot be undone:** the panel has no recycle bin, and what the cleanup deletes only comes back from a backup. With the rule by days, a device that stops uploading is left with no file at all after the period: for device backups, prefer keeping the most recent ones. The full rules are in [Web panel](../panel.md#limpeza).

</details>

<details>
<summary>Users ➜ Blocks — click to expand</summary>

### Users ➜ Blocks

<a href="images/usuarios-editar-bloqueios.png"><img src="images/usuarios-editar-bloqueios.png" alt="Edit user screen of switch-core with the Blocks card: the blocked origin, the number of wrong passwords, the time of the block, until when it holds and the Unblock button" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, Blocks card · captured on 2026-10-10</sub>

The address that gets the password of a user wrong on FTP too many times is blocked for that user, for the configured time: until then, not even the right password gets in from there. In the list, the name gains the tag `blocked`; hovering the mouse over it shows the addresses.

| Card item | What it shows |
|---|---|
| Origin | The address the wrong passwords came from |
| Wrong passwords | How many were counted up to the block |
| Blocked on · Until | The time of the block and the time it goes away on its own |
| **Unblock** | Removes every block of the user immediately |

1. Fix the password on the device: if it keeps getting it wrong, the block comes back.
2. Click **Unblock**.

<a href="images/usuarios-desbloqueado.png"><img src="images/usuarios-desbloqueado.png" alt="Users tab with the message Block removed, the user can sign in to FTP again, and the name switch-core without the tag blocked" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, after the unblock · captured on 2026-10-10</sub>

**Expected result:** the list comes back with the message `Block removed. The user can sign in to FTP again.`, without the tag `blocked`, and the next sign-in of the device goes through.

In the screenshot, the origin is the address of the host on the internal network of the photographed stack, because the wrong passwords came from the server itself. What counts as a wrong password is in [Security](../security.md#bloqueio-por-tentativa).

This is the short block, of one user for one address. The address that fails too much, with any account, is blocked as a whole, on FTP and on the panel: see [Blocks](#bloqueios).

</details>

<details>
<summary>Users ➜ Change password — click to expand</summary>

### Users ➜ Change password

<a href="images/usuarios-trocar-senha.png"><img src="images/usuarios-trocar-senha.png" alt="Change password form of the user switch-core, with the Password and Repeat the password fields and the Change password and Cancel buttons" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, Change password form · captured on 2026-10-10</sub>

| Field | Required | What to fill in |
|---|---|---|
| Password | No | 12 characters or more. Left blank, the panel generates a strong password |
| Repeat the password | Only with the password filled in | The same password |

**Expected result:** the list comes back with the message `Password changed.`, the old password stops working on the next login of the device and the session of that user in the panel, if there is one, is closed.

</details>

<details>
<summary>Users ➜ Remove — click to expand</summary>

### Users ➜ Remove

<a href="images/usuarios-remover.png"><img src="images/usuarios-remover.png" alt="Remove user screen of ap-deposito, with the warning about the files in the folder, the box Also delete the folder and everything in it ticked, the Your current password field and the buttons Yes, remove the user and Cancel" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, removal confirmation · captured on 2026-10-10</sub>

| Screen item | What it does |
|---|---|
| Warning about the files | Shows how many files the user has, how much they take and in which folder they stay; in a shared folder, it says who else reaches it |
| **Also delete the folder and everything in it** box | Only appears when the folder belongs to this user alone. Ticked, the folder goes together with the account, with everything inside it and with no recycle bin |
| **Your current password** | Asked for only when the box is ticked: it is the password of whoever is using the panel |
| **Yes, remove the user** | Deletes the account: the login stops working immediately |
| **Cancel** | Goes back to the list without changing anything |

<a href="images/usuarios-removido.png"><img src="images/usuarios-removido.png" alt="Users tab after the removal, with the message User removed and folder deleted" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, after the removal · captured on 2026-10-10</sub>

**Expected result:** with the box ticked and the right password, as in the screenshot, the list comes back with the message `User removed and folder deleted.` and the folder is gone. Without the box, the message is `User removed. The files stay in the folder.`: the folder stays in `DATA_DIR/dados` and remains visible in the Files tab, where it can be deleted later.

<a href="images/usuarios-remover-inicial.png"><img src="images/usuarios-remover-inicial.png" alt="Remove user screen of the initial user transfer, with the warning that, once removed, it does not come back on the next starts of the ftp service, the box Also delete the folder and everything in it ticked, the Your current password field and the buttons Yes, remove the user and Cancel" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, removal of the initial user · captured on 2026-10-10</sub>

The initial user, the `FTP_USER` of the installation (`transfer`, in the example), is removed the same way, with or without the folder. The screen warns that it does not come back on the next starts of the `ftp` service: to have it again, create a user with the same name.

</details>

<details>
<summary>Users ➜ TLS per user — click to expand</summary>

### Users ➜ TLS per user

<a href="images/usuarios-tls.png"><img src="images/usuarios-tls.png" alt="Users tab with the warning that the user was exempted from TLS and their password and files travel in plain text, the TLS column, which shows required or no TLS on each row, and the Exempt from TLS and Require TLS buttons next to Edit, Change password and Remove" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, TLS column · captured on 2026-10-10</sub>

The column and the two buttons are for the old device that does not speak TLS: it alone is exempted, and the others remain required. The same is done on creation, with the **Device without TLS support** box of **New user**, and in the **TLS** card of the **Edit** screen.

| Screen item | What it does |
|---|---|
| TLS column | `required` for whoever only signs in with TLS and `no TLS` for whoever was exempted |
| **Exempt from TLS** | Opens the confirmation to let that user sign in without TLS |
| **Require TLS** | Opens the confirmation to require TLS again from whoever is exempt |
| **Device without TLS support** box, in **New user** | Creates the user already exempt from TLS; unticked, the user only signs in with TLS |
| **TLS** card, in **Edit** | Says how that user signs in and leads to the same confirmation |

<a href="images/usuarios-novo-sem-tls.png"><img src="images/usuarios-novo-sem-tls.png" alt="New user form filled in for central-pabx, with the Device without TLS support box ticked and the alert that the password and the files of this user will travel in plain text" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, new user without TLS · captured on 2026-10-10</sub>

On creation, the ticked box saves the user already exempt, and the list comes back with the message `User created and exempted from TLS: their password and files travel in plain text.`

<a href="images/usuarios-editar-tls.png"><img src="images/usuarios-editar-tls.png" alt="Edit user screen of central-pabx, with the TLS card warning that this user signs in without TLS and the Require TLS button" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, TLS card of the Edit screen · captured on 2026-10-10</sub>

On the **Edit** screen, the **TLS** card says how the user signs in and has the button to change it: **Exempt from TLS** for whoever is required, **Require TLS** for whoever is exempt. For the user that already exists, the button opens the confirmation:

<a href="images/usuarios-tls-dispensar.png"><img src="images/usuarios-tls-dispensar.png" alt="Exempt from TLS screen of the user radio-antigo, with the warning that the password and the files will travel in plain text and the buttons Yes, let this user sign in without TLS and Cancel" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, confirmation of the exemption from TLS · captured on 2026-10-10</sub>

**Expected result:** the list comes back with the message `User exempted from TLS: their password and files travel in plain text.`, their row shows `no TLS` and the Overview and Security tabs open with the alert. The exemption applies within moments, without dropping whoever is connected. On requiring it again, the message is `The user is required to use TLS again.`

> ⚠️ **Exemption from TLS:** the exempt user sends password and file in plain text. Use it only for the old device that does not speak TLS, on an isolated internal network, with a folder and a password of its own, and change the password when requiring it again. The conditions are in [TLS per user](../security.md#tls-por-usuario).

</details>

<details>
<summary>Technical detail — routes and command used</summary>

- Routes: `GET /usuarios`, `/usuarios/novo`, `/usuarios/editar?usuario=<name>`, `/usuarios/senha?usuario=<name>`, `/usuarios/remover?usuario=<name>` and `/usuarios/tls?usuario=<name>`; the submission of each form is a `POST` to the same route, with the CSRF token of the session. The exception is the Edit screen, which sends the profile to `POST /usuarios/perfil`, the folder to `POST /usuarios/pasta`, the limits to `POST /usuarios/limites`, the automatic cleanup to `POST /usuarios/limpeza` and the unblock to `POST /usuarios/desbloquear`.
- The exemption from TLS applies with `FTP_TLS_EXCECOES=sim`, which is the default, `FTP_TLS_MODE=2` and without `REDE_PERMITIR_IP_PUBLICO=sim`. Outside that, the column, the buttons and the box disappear, the route `/usuarios/tls` answers `404` and the list of exempt users stays stored, without effect.
- The panel calls the same `allsafe-ftp-user` as [`manage-user.sh`](../../../manage-user.sh): panel and command line change the same accounts. See [Operation](../operation.md#usuarios).
- Each change writes `usuario_criado`, `senha_trocada`, `pasta_trocada`, `perfil_trocado`, `limites_alterados`, `retencao_alterada`, `bloqueio_removido`, `usuario_removido`, `tls_dispensado` or `tls_exigido` to the [audit log](../panel.md#auditoria), with the administrator who did it and without the password.
- The generated password has 32 random characters and is not kept: only the hash goes to the FTP user database.
- Sessions, rates and hours are kept in the FTP user database, and it is `pure-ftpd` that applies them on each sign-in; the downloads through the panel and the blocking by attempts are kept in files of the stack itself: [Limits per user](../panel.md#limites).
- The rule of the automatic cleanup is kept in a file of the stack itself, and the panel is what applies it, writing `retencao_aplicada` on each run that deletes something and `retencao_falhou` when it does not finish: [Automatic cleanup](../panel.md#limpeza).
- Changing the wrong passwords before the block or the minutes of block removes the blocks of the user; changing their password and removing them does too.
- In the **New user** form, the fields of each kind of account appear according to the selected profile, without JavaScript; the submission is always `POST /usuarios/novo`.
- The rules of the folder and what the `shared` mark checks are in [Users through the panel](../panel.md#usuarios); how the profile is applied on FTP, in [Profiles](../panel.md#perfis).

</details>

---

<a name="administradores"></a>

## 🛡️ Administrators

<a href="images/administradores.png"><img src="images/administradores.png" alt="Users tab with three administrators at the top of the list, admin, with the tag you, noc-plantao and suporte, each with the Administrator profile, the open sessions and the actions Change password, Change name and Remove, and, below them, the FTP users" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, administrators in the list · captured on 2026-10-10</sub>

**What it is for:** giving each person who administers the panel their own user name and password, and changing the user name and the password of the first administrator after the installation.

**How to get there:** menu ➜ **Users**. There is no tab of its own: the administrators stay at the top of the list, before the FTP users.

| Screen item | What it does |
|---|---|
| **New user** | Opens the registration; with the **Administrator** profile selected, the account created is an administrator |
| User and profile | Name of the account, with `Administrator` below it. The tag `you` marks the account of whoever is using the panel |
| Folder | In place of the folder, `Whole panel` and how many browsers are inside the panel with that account right now |
| **Change password** | Opens the password change, one's own or another's |
| **Change name** | Opens the change of the sign-in name, one's own or another's |
| **Remove** | Opens the removal confirmation. It does not appear on one's own account: this way there is always one administrator left |

All of them have the same access, and what each one does is in the Log tab with the name of whoever did it. The panel accepts up to 20 administrators. Administrator and FTP user are separate registrations: there is no switching from one to the other, only removing the account and creating the other.

<details>
<summary>Administrators ➜ New administrator — click to expand</summary>

### Administrators ➜ New administrator

<a href="images/administradores-novo.png"><img src="images/administradores-novo.png" alt="New user form with the Administrator profile selected: the Profile field, the fields User name, Password, Repeat the password and Your current password, without the folder and without the TLS box, and the Create user and Cancel buttons" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, New user form with the Administrator profile · captured on 2026-10-10</sub>

Click **New user** and select the **Administrator** profile: the folder and TLS fields give way to your current password.

| Field | Required | What to fill in |
|---|---|---|
| Profile | Yes | Administrator |
| User name | Yes | Lowercase letters, numbers, `_` and `-`; starts with a letter or `_`; up to 32 characters |
| Password | No | 12 characters or more. Left blank, the panel generates a strong password and shows it only once |
| Repeat the password | Only with the password filled in | The same password |
| Your current password | Yes | The password of whoever is using the panel, to confirm |

**Expected result:** the list comes back with the message `Administrator created.` and the new administrator signs in right away, without restarting anything.

</details>

<details>
<summary>Administrators ➜ Change password — click to expand</summary>

### Administrators ➜ Change password

<a href="images/administradores-trocar-senha.png"><img src="images/administradores-trocar-senha.png" alt="Change administrator password form, of the administrator suporte, with the fields Password, Repeat the password and Your current password and the Change password and Cancel buttons" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, Change administrator password form · captured on 2026-10-10</sub>

| Field | Required | What to fill in |
|---|---|---|
| Password | No | The new password, with 12 characters or more. Left blank, the panel generates one |
| Repeat the password | Only with the password filled in | The same password |
| Your current password | Yes | The password of whoever is using the panel, to confirm |

**Expected result:** the list comes back with the message `Password changed. The other sessions of this administrator were closed.` and the old password stops working immediately.

This is where the initial password of the installation is changed after the first access. With no administrator able to sign in, the password is reset from the server: [Recovering access](../panel.md#senha).

</details>

<details>
<summary>Administrators ➜ Change name — click to expand</summary>

### Administrators ➜ Change name

<a href="images/administradores-trocar-nome.png"><img src="images/administradores-trocar-nome.png" alt="Change administrator name form, of the administrator suporte, with the New name field filled in with suporte-redes, the Your current password field and the Change name and Cancel buttons" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, Change administrator name form · captured on 2026-10-10</sub>

| Field | Required | What to fill in |
|---|---|---|
| New name | Yes | The same rule as the user name; different from the current one and from every other administrator |
| Your current password | Yes | The password of whoever is using the panel, to confirm |

**Expected result:** the list comes back with the message `Name changed. The other sessions of this administrator were closed.` Sign-in is now by the new name, with the same password.

Changing the name of the first administrator through the panel does not touch the `.env`: `PAINEL_ADMIN_USER` is only used while no administrator exists.

</details>

<details>
<summary>Administrators ➜ Remove — click to expand</summary>

### Administrators ➜ Remove

<a href="images/administradores-remover.png"><img src="images/administradores-remover.png" alt="Remove administrator screen asking for confirmation to remove noc-plantao, with the Your current password field and the buttons Yes, remove the administrator and Cancel" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, administrator removal confirmation · captured on 2026-10-10</sub>

| Screen item | What it does |
|---|---|
| Your current password | Confirms that whoever asks for the removal is the owner of the session |
| **Yes, remove the administrator** | Deletes the account: it stops signing in immediately and its open sessions are closed |
| **Cancel** | Goes back to the list without changing anything |

**Expected result:** the list comes back with the message `Administrator removed. Their sessions were closed.` The FTP users and the files do not change.

</details>

<details>
<summary>Technical detail — refusal messages, routes and file</summary>

| Message | Reason |
|---|---|
| Your current password does not match. Nothing was changed. | The Your current password field is wrong; five refusals in 15 minutes block the address |
| There is already an administrator with this name. | The name is already in use |
| The new name is the same as the current one. | The name change changed nothing |
| Limit of 20 administrators reached: remove one before creating another. | The panel already has 20 administrators |

- Registration is `POST /usuarios/novo`, with the profile `administrador`. The old addresses still work: `GET /administradores` leads to the Users tab and `GET /administradores/novo`, to the form with the Administrator profile selected.
- Routes of the other screens: `GET /administradores/senha?admin=<name>`, `/administradores/nome?admin=<name>` and `/administradores/remover?admin=<name>`; the submission of each form is a `POST` to the same route, with the CSRF token of the session.
- The administrators are kept in `DATA_DIR/painel/administradores` (`0600`, owned by `root`), one `name:hash` line per account. Only the `scrypt` hash is written.
- Each change writes `admin_criado`, `admin_senha_trocada`, `admin_renomeado` or `admin_removido` to the [audit log](../panel.md#auditoria), with who did it and who was changed; the wrong current password writes `admin_senha_atual_recusada`.
- The full rules are in [Administrators of the panel](../panel.md#administradores).

</details>

---

<a name="arquivos"></a>

## 📁 Files

<a href="images/arquivos.png"><img src="images/arquivos.png" alt="Files tab at the first level, with the list of the users' folders, the date of each one, the Rename and Delete buttons on each row and the New folder and Upload file cards" width="100%"></a>

<sub><b>v0.31.1</b> · Files menu · captured on 2026-10-10</sub>

**What it is for:** seeing what each device uploaded, downloading a backup through the browser, uploading a file to any folder, creating the folder of a new user, renaming and deleting files and folders, without an FTP client.

**How to get there:** menu ➜ **Files**. In the Users tab, the address in the **Folder** column opens the folder of that user directly.

| Screen item | What it does |
|---|---|
| Path at the top of the list | Shows the open folder and goes back to any level |
| Name of a folder | Enters the folder |
| Size · Modified | Size of the file and date of the last change |
| **Download** | Hands the file to the browser, with the original name |
| **Rename** | Opens the screen that changes the name of the file or of the folder, inside the same folder, and asks for your current password; a name that already exists is refused |
| **Delete** | Opens the confirmation screen: it shows what is going away, asks for the ticked box and your current password and deletes for good, with no recycle bin |
| **New folder** | Creates an empty folder inside the one that is open |
| **Upload file** | Takes a file from the browser and writes it to the folder that is open; a name that already exists is refused |
| **New user in this folder** | Inside a folder, opens the user registration with the Folder field filled in |

The panel browses, downloads, uploads, creates folders, renames and deletes. The devices keep uploading by FTP: the upload from here is for the one-off file, of whoever is at the browser. The folder of an FTP user is not renamed or deleted from here: it goes together with the user, in [Users ➜ Remove](#usuarios). The rules and the limits are in [Web panel](../panel.md#arquivos).

<details>
<summary>Files ➜ Folder of a user and download — click to expand</summary>

### Files ➜ Folder of a user and download

<a href="images/arquivos-pasta.png"><img src="images/arquivos-pasta.png" alt="Files tab inside the folder roteador-borda, with the path at the top, the line that says which FTP user the folder belongs to, the New user in this folder button and the Download, Rename and Delete buttons on each file" width="100%"></a>

<sub><b>v0.31.1</b> · Files menu, folder of a user · captured on 2026-10-10</sub>

1. Click the name of the folder to enter it.
2. Check, in the line `Folder of the FTP user`, whose folder it is.
3. Click **Download** on the row of the file.

**Expected result:** the browser saves the file with the original name, identical to what the device uploaded, and the Log tab gains the line `File downloaded`, with the administrator, the path and the size.

| Limit | Value |
|---|---|
| Downloads at the same time | 8, adding up administrators and FTP users; the next one gets the screen `Too many downloads at the same time` |
| Items shown per folder | 2000, with a warning when there are more |
| Resume | There is none: if the connection drops, the download starts over |

</details>

<details>
<summary>Files ➜ New folder — click to expand</summary>

### Files ➜ New folder

<a href="images/arquivos-pasta-criada.png"><img src="images/arquivos-pasta-criada.png" alt="Files tab with the message Folder created and the folder clientes in the list" width="100%"></a>

<sub><b>v0.31.1</b> · Files menu, folder created · captured on 2026-10-10</sub>

| Field | Required | What to fill in |
|---|---|---|
| Name of the folder | Yes | Letters, numbers, `_`, `-` and dot; does not start with a dot; up to 64 characters. One folder at a time: to create `clientes/olt-01`, create `clientes`, enter it and create `olt-01` |

**Expected result:** the list comes back with the message `Folder created.` and the new folder, empty, already with the owner and the permission that the FTP uses. For a device to write to it, enter the folder and click **New user in this folder**.

| Message | Reason |
|---|---|
| Path not accepted. | The name breaks the rule or tries to leave the data folder |
| There is already a folder or a file with this name. | The name is already in use in that folder |
| The panel does not follow symbolic links. | The destination goes through a symbolic link |
| Folder or file not found. | The destination folder no longer exists |

</details>

<details>
<summary>Files ➜ Upload file — click to expand</summary>

### Files ➜ Upload file

<a href="images/arquivos-enviado.png"><img src="images/arquivos-enviado.png" alt="Files tab inside the folder clientes, with the message File uploaded, the file planilha-de-clientes.csv in the list and the Upload file card, with the Save as and File fields and the Upload file button" width="100%"></a>

<sub><b>v0.31.1</b> · Files menu, after the upload · captured on 2026-10-10</sub>

1. Enter the folder where the file should stay.
2. In the **Upload file** card, choose the file.
3. Click **Upload file**.

| Field | Required | What to fill in |
|---|---|---|
| Save as | No | The name the file gets on the server: letters, numbers, `_`, `-` and dot; does not start with a dot; up to 64 characters. Left blank, the name of the chosen file is kept |
| File | Yes | The file to upload, one at a time; the label of the field says which folder it will be written to |

**Expected result:** the folder comes back with the message `File uploaded.` and the file in the list, already with the owner and the permission that the FTP uses, and the Log tab gains the line `File uploaded through the panel`, with the administrator, the path and the size.

| Limit | Value |
|---|---|
| Size of each file | The one in `PAINEL_ENVIO_MAX_MB`: 1024 MB, by default |
| Uploads at the same time | 4, adding up administrators and FTP users; the next one gets the screen `Too many uploads at the same time` |
| Name that already exists in the folder | It is not replaced: the upload is refused |
| Resume | There is none: if the connection drops, what arrived is discarded and the upload starts over |

| Message or screen | Reason |
|---|---|
| Screen `No file chosen` | The form was submitted without a file |
| Screen `Name not accepted` | The name of the file, or the one in the **Save as** field, breaks the rule |
| Screen `Name already in use` | There is already a folder or a file with this name in that folder; nothing is replaced |
| File too large: the panel accepts up to 1.0 GiB per file. | The file goes over the size of `PAINEL_ENVIO_MAX_MB`; the value in the message follows the variable |
| Screen `No space left` | The server has no free space for the file |

</details>

<details>
<summary>Files ➜ Rename — click to expand</summary>

### Files ➜ Rename

<a href="images/arquivos-renomear.png"><img src="images/arquivos-renomear.png" alt="Rename screen of the file switch-core-antigo.cfg, with the folder it is in, the New name field filled in, the Your current password field and the Change name and Cancel buttons" width="100%"></a>

<sub><b>v0.31.1</b> · Files menu, Rename screen · captured on 2026-10-10</sub>

| Field | Required | What to fill in |
|---|---|---|
| New name | Yes | Letters, numbers, `_`, `-` and dot; does not start with a dot; up to 64 characters |
| Your current password | Yes | The password of whoever is using the panel, to confirm |

<a href="images/arquivos-renomeado.png"><img src="images/arquivos-renomeado.png" alt="Files tab inside the folder switch-core, with the message Name changed and the file with the new name in the list" width="100%"></a>

<sub><b>v0.31.1</b> · Files menu, after the name change · captured on 2026-10-10</sub>

**Expected result:** the folder comes back with the message `Name changed.` and the item with the new name, in the same place. The panel does not move from one folder to another, and the device that writes with the old name creates another file on the next upload.

| Message | Reason |
|---|---|
| Name not accepted. See the rule below the field. | The name breaks the rule |
| The item already has this name. | The new name is the same as the current one |
| There is already a folder or a file with this name. | The name is already in use in that folder; nothing is replaced |
| Your current password does not match. Nothing was changed. | The Your current password field is wrong; five refusals in 15 minutes block the address |

</details>

<details>
<summary>Files ➜ Delete — click to expand</summary>

### Files ➜ Delete

<a href="images/arquivos-apagar.png"><img src="images/arquivos-apagar.png" alt="Delete screen of the file teste-de-envio.txt, with its size, date and folder, the warning that the panel has no recycle bin, the confirmation box ticked, the Your current password field and the Delete for good and Cancel buttons" width="100%"></a>

<sub><b>v0.31.1</b> · Files menu, delete confirmation · captured on 2026-10-10</sub>

| Screen item | What it does |
|---|---|
| First line | Says what is going away: the file, with the size and the date, or the folder, with the number of files and the space of everything inside it |
| **I checked the name and want to delete** box | Required: without it nothing is deleted |
| **Your current password** | The password of whoever is using the panel, to confirm |
| **Delete for good** | Deletes the file, or the folder with everything inside it |
| **Cancel** | Goes back to the folder without changing anything |

<a href="images/arquivos-apagado.png"><img src="images/arquivos-apagado.png" alt="Files tab inside the folder switch-core, with the message Deleted and the list without the file teste-de-envio.txt" width="100%"></a>

<sub><b>v0.31.1</b> · Files menu, after deleting · captured on 2026-10-10</sub>

**Expected result:** the folder comes back with the message `Deleted.` and without the item, and the Log tab gains the line `File or folder deleted`.

> ⚠️ **Deleting cannot be undone:** the panel has no recycle bin, and what was deleted only comes back from a backup. See [Backup](../backup.md).

| Message or screen | Reason |
|---|---|
| Tick the confirmation box. Nothing was deleted. | The box was left unticked |
| Your current password does not match. Nothing was deleted. | The Your current password field is wrong; five refusals in 15 minutes block the address |
| Screen `Partly deleted` | The folder holds more than the panel deletes in one request: repeat to continue |
| Screen `Nothing was deleted` | The panel is already deleting another folder, or an item could not be removed |

<a href="images/arquivos-pasta-de-usuario.png"><img src="images/arquivos-pasta-de-usuario.png" alt="Folder of an FTP user screen, which refuses to delete the folder roteador-borda because it is the folder of a user and points to Users, Edit and Users, Remove" width="100%"></a>

<sub><b>v0.31.1</b> · Files menu, user folder refused · captured on 2026-10-10</sub>

The folder of an FTP user, and the folder that has the one of a user inside it, is not renamed or deleted through the Files tab: the user database would be left pointing to a folder that does not exist. To give the user another folder, use **Users ➜ Edit**; to delete the folder together with the user, **Users ➜ Remove**. What is inside it is renamed and deleted item by item.

</details>

<details>
<summary>Technical detail — routes and protections</summary>

- Routes: `GET /arquivos?pasta=<path>` lists, `GET /arquivos/baixar?arquivo=<path>` hands over and `POST /arquivos/pasta` creates the folder, with the CSRF token. `GET /arquivos/renomear?item=<path>` and `GET /arquivos/apagar?item=<path>` show the screen of each action, and the submission is a `POST` to the same route. `POST /arquivos/enviar` takes the file, as `multipart/form-data`, with the CSRF token.
- The path is always relative to `DATA_DIR/dados`, opened part by part and without following symbolic links. A path with `..` gets `400` and a symbolic link, `403`, both with the event `recusa_caminho`.
- The file goes out as an attachment (`Content-Disposition: attachment`, RFC 6266 and RFC 8187), in 64 KiB blocks, without being loaded into memory: the browser saves it and never opens it.
- The new folder is born with the owner `ftpdata` and the mode `0750`, the same as the folders created by FTP.
- The uploaded file is written straight to disk, without being loaded into memory and without a name, in the destination folder itself, and only gets a name when it arrives whole, by `link()`, which does not replace what exists. The interrupted upload leaves nothing behind in the folder, and the panel does not open or interpret the content.
- The name is changed by a single system call, which refuses the name that already exists; the folder is emptied from the inside out, and a symbolic link inside it is deleted as a link, without touching the destination.
- One delete request removes up to 50,000 items or works for up to 20 seconds, and the panel does one deletion at a time.
- The folder of an FTP user, or the one that has one inside it, answers `409` on the screen and on the submission.
- The events `arquivo_baixado`, `arquivo_interrompido`, `arquivo_enviado`, `envio_interrompido`, `pasta_criada`, `item_renomeado` and `item_apagado` are in the [audit log](../panel.md#auditoria); the content of the file is never recorded.
- The full behaviour is in [Files and download](../panel.md#arquivos) and in [Upload file](../panel.md#enviar-arquivo).

</details>

---

<a name="meus-arquivos"></a>

## 📥 My files

<a href="images/meus-arquivos.png"><img src="images/meus-arquivos.png" alt="My files screen of the user olt-centro, with the Full profile, with the folders 2026-09 and 2026-10 and a configuration file, the automatic cleanup warning above the list, the Open or Download, Rename and Delete buttons on each row, the New folder and Upload file cards and, in the menu, only the My files tab, the PT and EN buttons, the name of the user and the Sign out button" width="100%"></a>

<sub><b>v0.31.1</b> · My files screen, of the FTP user with the Full profile · captured on 2026-10-10</sub>

**What it is for:** the owner of the files browses their own folder and downloads the backups through the browser, without depending on whoever administers and without a new account. What else they do depends on the profile of the account and, for file upload, on the permission the administrator gives.

**How to get there:** open the address of the panel and sign in with **the FTP name and password**, the same ones the device uses. It is the only screen the FTP user sees.

| Screen item | What it does | Profiles that have it |
|---|---|---|
| Path at the top of the list | Shows the open folder, starting from **Home**, and goes back to any level | Full, Upload and Read only |
| Name of a folder · **Open** | Enters the folder | Full, Upload and Read only |
| Size · Modified | Size of the file and date of the last change | Full, Upload and Read only |
| **Download** | Hands the file to the browser, with the original name | Full, Upload and Read only |
| **New folder** | Creates an empty folder inside the one that is open | Full and Upload |
| **Upload file** | Takes a file from the browser and writes it to the folder that is open | Full, Upload and Upload only, with the permission to upload through the panel |
| **Rename** | Opens the screen that changes the name of the file or of the folder, inside the same folder, and asks for the FTP password of the account | Full |
| **Delete** | Opens the confirmation, which asks for the FTP password of the account; deletes for good, with no recycle bin | Full |
| Automatic cleanup warning | Above the list, when the administrator turned on the cleanup of the folder: it states the rule and reminds that what goes does not come back | Full, Upload and Read only |
| **What this account can do** | Collapsed below the list: says what the profile of the account allows and whether it uploads files from here | Full, Upload and Read only |
| **PT** · **EN** | Switch the language of the account: see [Language](#idioma) | All |
| **Sign out** | Closes the session immediately | All |

The user sees only the folder of their registration and what is inside it. The path of the folder on the server does not appear, and the menu has only the screen of the account, without the administration tabs, with the name of the user and the role **FTP user**. The button the profile does not have does not appear, and the action requested directly by the address answers `404`. Uploading a file from here depends on a permission the administrator gives to each account: without it, the **Upload file** card does not appear and upload is by FTP only. The account with the Upload only profile has another screen: see [My files ➜ Upload only profile](#meus-arquivos).

<details>
<summary>My files ➜ Inside a folder — click to expand</summary>

### My files ➜ Inside a folder

<a href="images/meus-arquivos-pasta.png"><img src="images/meus-arquivos-pasta.png" alt="My files screen of the user olt-centro inside the folder 2026-10, with ten backup files, the size and the date of each one and the Download, Rename and Delete buttons on each row" width="100%"></a>

<sub><b>v0.31.1</b> · My files screen, inside a folder · captured on 2026-10-10</sub>

1. Click the name of the folder to enter it.
2. Click **Download** on the row of the file.
3. Click **Home**, in the path at the top, to go back to the folder of the user.

**Expected result:** the saved file is identical to what the device uploaded, and the Log tab, which only the administrator sees, gains the line `File downloaded`, with the name of the FTP user, the path and the size.

| Limit | Value |
|---|---|
| Sessions per FTP user | 3; the fourth sign-in closes the oldest one |
| Downloads at the same time per user | 2, or the number saved in their limits; the next one gets the screen `Too many downloads at the same time` |
| After changing the password, the folder or the profile, or removing the user | Their session is closed on the next request |

</details>

<details>
<summary>My files ➜ Upload file — click to expand</summary>

### My files ➜ Upload file

<a href="images/meus-arquivos-enviado.png"><img src="images/meus-arquivos-enviado.png" alt="My files screen of the user olt-centro with the message File uploaded, the file olt-centro-manual.cfg in the list and the Upload file card, with the Save as and File fields and the Upload file button" width="100%"></a>

<sub><b>v0.31.1</b> · My files screen, after the upload · captured on 2026-10-10</sub>

The **Upload file** card appears for the account that has the permission **Allow this user to upload files through the panel**, ticked by the administrator in [Users ➜ Limits](#usuarios). The Read only profile does not upload, with or without the permission.

1. Enter the folder where the file should stay.
2. In the **Upload file** card, choose the file.
3. Click **Upload file**.

| Field | Required | What to fill in |
|---|---|---|
| Save as | No | The name the file gets on the server; left blank, the name of the chosen file is kept |
| File | Yes | The file to upload, one at a time |

**Expected result:** the folder comes back with the message `File uploaded.` and the file in the list, and the Log tab, which only the administrator sees, gains the line `File uploaded through the panel`, with the name of the FTP user, the path and the size.

| Rule | How it applies |
|---|---|
| Size of each file | The one in `PAINEL_ENVIO_MAX_MB`: 1024 MB, by default |
| Uploads at the same time | One per account; the next one gets the screen `Too many uploads at the same time` |
| Rate | The upload rate saved in the limits of the user, if there is one |
| Name that already exists | With the Full and Upload profiles, the upload is refused and nothing is replaced. With the Upload only profile, the new file is stored with the date and time in its name |
| Without the permission | The upload requested directly by the address gets the screen `Upload not allowed` and is recorded |

</details>

<details>
<summary>My files ➜ Upload profile — click to expand</summary>

### My files ➜ Upload profile

<a href="images/meus-arquivos-envio.png"><img src="images/meus-arquivos-envio.png" alt="My files screen of the user roteador-borda, with the Upload profile, with the backup files of the router, only the Download button on each row and the New folder form, without Rename, Delete or Upload file" width="100%"></a>

<sub><b>v0.31.1</b> · My files screen, Upload profile · captured on 2026-10-10</sub>

The account with the Upload profile browses, downloads and creates folders. There is no **Rename** or **Delete**: what has already reached the server stays as it arrived, on FTP and on the panel. In the screenshot, `roteador-borda` does not have the permission to upload through the panel, and the **Upload file** card does not appear.

</details>

<details>
<summary>My files ➜ Read only profile — click to expand</summary>

### My files ➜ Read only profile

<a href="images/meus-arquivos-leitura.png"><img src="images/meus-arquivos-leitura.png" alt="My files screen of the user consulta-filiais, with the Read only profile, with the folder olt-norte and only the Open button, without New folder, Rename or Delete" width="100%"></a>

<sub><b>v0.31.1</b> · My files screen, Read only profile · captured on 2026-10-10</sub>

The account with the Read only profile only browses and downloads, and does not upload by any path. In the screenshot, the folder of `consulta-filiais` is `filiais`, which has the folder of `olt-filial-norte` inside it: the lookup account downloads what the OLT uploaded and writes nothing.

</details>

<details>
<summary>My files ➜ Upload only profile — click to expand</summary>

### My files ➜ Upload only profile

<a href="images/meus-arquivos-so-envio.png"><img src="images/meus-arquivos-so-envio.png" alt="File upload screen of the user olt-pop-sul, with the Upload only profile, with the Upload file card, the path of each file in three steps, from the device to the folder of the user, the details for sending by FTP and the explanation of what the account does, without a list of files" width="100%"></a>

<sub><b>v0.31.1</b> · File upload screen, Upload only profile · captured on 2026-10-10</sub>

The account with the Upload only profile does not see the backups, not even the ones it uploaded itself. In place of My files, it opens the **File upload** screen, which explains the path of the file and has the details to set up the device.

| Card | What it shows |
|---|---|
| **Upload file** | Only with the permission to upload through the panel: takes a file from the browser and stores it in the folder of the user, without showing what is in it |
| **The path of each file** | Three steps: the device uploads by FTP, the server receives it in an entry area that belongs to that account alone and the file is stored in the folder of the user, out of its reach |
| **Details for sending by FTP** | Server, control port, passive ports, protocol and the user: what to fill in on the device |
| **What this account does** | That it only uploads, that the folder of the session is empty again after each upload and that the file with a repeated name is stored with the date and time in its name, without replacing the previous one |

With the permission, the account uploads by FTP or through this screen, and nothing else: the message `File uploaded.` confirms the arrival, and the file with a repeated name comes back with `File uploaded. There was already one with this name: the new one was stored with the date and time in its name.`

Whoever needs to check or download what was uploaded asks an administrator or uses an account with another profile. The rules of this profile are in [Web panel](../panel.md#perfis).

</details>

<details>
<summary>Technical detail — what the FTP account reaches</summary>

- Routes of the session of the FTP user, by profile. Upload only: `GET /` (leads to `/meus-arquivos`), `GET /meus-arquivos`, `POST /idioma` and `POST /sair`. Read only adds `GET /meus-arquivos?pasta=<path>` and `GET /meus-arquivos/baixar?arquivo=<path>`. Upload adds `POST /meus-arquivos/pasta`. With the permission to upload through the panel, Upload only, Upload and Full gain `POST /meus-arquivos/enviar`; without it, the route answers `403`, with the event `recusa_envio`. Full adds `GET` and `POST` on `/meus-arquivos/renomear?item=<path>` and `/meus-arquivos/apagar?item=<path>`.
- Any other route answers `404`. When it is an administration route, or an action the profile of the account does not have, the event `recusa_papel` is recorded, with the user, the path and the profile.
- Renaming and deleting check the FTP password of the account; the wrong password writes `usuario_senha_atual_recusada`.
- The one that checks the password is `pure-ftpd`, by a login on the internal network of the stack; the panel does not read the hash of the user database.
- The path is always relative to the folder of the registration, which is its root, with the same checks as the [Files tab](#arquivos).
- `PAINEL_ACESSO_USUARIOS_FTP=nao` turns this sign-in off: the panel starts accepting administrators only.
- The full behaviour is in [FTP user in the panel](../panel.md#usuario-ftp).

</details>

---

<a name="servidor"></a>

## 🖥️ Server

<a href="images/servidor.png"><img src="images/servidor.png" alt="Server tab with the Auto-refresh button, the Stack containers card, with one box for the FTP server, one for the Panel and one for the Web front end, each with CPU, memory and processes in use and allocated and the chart of the last minute, and the Server resources card, with CPU, memory, disk and FTP network" width="100%"></a>

<sub><b>v0.31.1</b> · Server menu · captured on 2026-10-10</sub>

**What it is for:** following how much each container of the stack uses of what was allocated to it and how much is left on the machine the stack runs on.

**How to get there:** menu ➜ **Server**; in the Overview, the shortcut `see the server` of the **Server and containers** card.

| Screen item | What it shows |
|---|---|
| **Auto-refresh** | Reloads the tab every 10 seconds; turned on, it becomes **Stop refreshing**. The automatic reload does not renew the session: without use by whoever is in front of the screen, it closes in the usual time |
| Summary line | How many cores and how much memory were allocated to the three containers, how much is in use now and the size of the server |
| **FTP server** · **Panel** · **Web front end** | One box per container (`ftp`, `painel` and `nginx`): `Up` and for how long, CPU, memory and processes, each with the use and the allocated limit, and the chart of the CPU in the last minute, with the peak |
| CPU limit reached · Killed for lack of memory | How many times the container hit the CPU limit and how many times it was killed for lack of memory |
| Last line of each box | What is specific to the service: sign-in blocks in force, on FTP; administrator sessions, on the panel; validity of the certificate, on the web front end |
| **Server resources** ➜ CPU | Use of the whole machine, with the 1-minute average, the load average, how long it has been on and the model of the processor |
| **Server resources** ➜ Memory | In use, available, cached and swap |
| **Server resources** ➜ Disk | Use of the disk of the data folder, split into FTP folders, other data and free |
| **Server resources** ➜ FTP network | How much the FTP receives and sends now, the peaks, the totals since the service started and the errors and drops |
| Line `Read at` | The time of the reading that is on the screen |
| **How these measurements are read** | Collapsed at the end of the tab: where each number comes from and how long the history is kept |

Nothing is changed through this tab, and only the administrator sees it. The limits of each container are those of `*_CPU_LIMIT`, `*_MEMORY_LIMIT` and `*_PIDS_LIMIT` in the `.env`: see [Configuration](../configuration.md#limites-de-recurso-do-container).

<details>
<summary>Technical detail — where the measurements come from</summary>

- Route `GET /servidor`; with `?auto=1`, the response carries the `Refresh` header of 10 seconds. The page does not use JavaScript.
- Each container reads its own use and the limits it received in `compose.yaml`; none of them accesses the Docker of the host.
- The history keeps the last 10 minutes, with one reading every 5 seconds, and starts over when the panel restarts.
- The memory in use does not count the file cache the system releases when it needs to.
- The full behaviour is in [Web panel](../panel.md#servidor).

</details>

---

<a name="seguranca"></a>

## 🔐 Security

<a href="images/seguranca.png"><img src="images/seguranca.png" alt="Security tab with the summary of the check at the top, which says how many items are in order, and one line per item: public address, panel behind a proxy or tunnel, addresses of the FTP and of the panel, TLS mode, the two certificates, allowed networks, session, sign-in of FTP users, blocking by attempts on FTP, with the name of the blocked user, blocking by address, with the number of blocked addresses, cost of the passwords, security contact, container and firewall" width="100%"></a>

<sub><b>v0.31.1</b> · Security menu · captured on 2026-10-10</sub>

**What it is for:** checking, on one screen, whether the installation is within what the stack requires: private network, TLS, valid certificates, isolated panel and published security contact.

**How to get there:** menu ➜ **Security**.

| Screen item | What it shows |
|---|---|
| Summary at the top | How many items were checked, how many are in order, how many need attention, how many have a problem and how many the panel does not check or do not apply |
| Public address | Whether the stack refuses a public address (the default) or whether it was accepted with `REDE_PERMITIR_IP_PUBLICO=sim`; with `PAINEL_AVISO_EXPOSICAO=nao`, this is where it is said that the warning of the menu, of the top of the tab and of the footer is hidden |
| Panel behind a proxy or tunnel | Whether the panel accepts the client address informed by a proxy or tunnel (`PAINEL_PROXY_CONFIAVEL`) and from which addresses it accepts it; left blank, which is the default, the line says the panel is not published that way |
| FTP address · IP announced in passive mode | Where the FTP listens and the IP it tells the client, marked as private or public |
| FTP TLS | The mode in use (`FTP_TLS_MODE`), whether the per-user exception is on and who is exempt |
| FTP certificate · Panel certificate | Validity and SHA-256 fingerprint, to compare with the one the FTP client and the browser show |
| Panel address · Web front end | Where nginx publishes the panel and how it forwards the requests |
| Who can open the panel | The networks of `PAINEL_REDES_PERMITIDAS`; a public network in the list is highlighted |
| Session | Time without use, maximum time and block for wrong sign-in |
| Sign-in of FTP users | Whether the FTP users sign in to the panel (`PAINEL_ACESSO_USUARIOS_FTP`) and how their password is checked |
| Blocking by attempts on FTP | How many wrong passwords from the same address block a user and for how long (`FTP_BLOQUEIO_TENTATIVAS` and `FTP_BLOQUEIO_MINUTOS`), and who is blocked now |
| Blocking by address | How many user name and password errors, in how many hours, block an address on FTP and on the panel, for how many days (`BLOQUEIO_ENDERECO_ERROS`, `BLOQUEIO_ENDERECO_HORAS` and `BLOQUEIO_ENDERECO_DIAS`), and how many are blocked now, with the shortcut to the Blocks tab |
| Cost of FTP passwords | Whether every password is stored with the cost of the current size profile, or which users still have the previous one |
| Security contact | The e-mail published in `/.well-known/security.txt` (`SEGURANCA_CONTATO_EMAIL`), or the warning that there is no contact |
| Panel container | Read-only root and no access to the Docker of the host |
| Host firewall | Reminder: the panel does not see the firewall; the check is up to whoever administers the server |

Nothing is changed through this tab. The example firewall rules are in [Security](../security.md#rede-privada).

<details>
<summary>Security ➜ Alert of user without TLS — click to expand</summary>

### Security ➜ Alert of user without TLS

<a href="images/seguranca-tls-por-usuario.png"><img src="images/seguranca-tls-por-usuario.png" alt="Security tab with the alert at the top that two users, central-pabx and radio-antigo, sign in to FTP without TLS, and the FTP TLS line with the attention mark and the names of the exempt users" width="100%"></a>

<sub><b>v0.31.1</b> · Security menu, alert of user without TLS · captured on 2026-10-10</sub>

With at least one user exempt from TLS, the tab opens with the alert and the **FTP TLS** line swaps the checked mark for the attention one, with the number and the names of those who sign in without TLS.

**Expected result:** after **Users ➜ Require TLS** on the last exempt user, the alert goes away and the line says again that everyone signs in with TLS.

</details>

<details>
<summary>Technical detail — what each line reads</summary>

- Route `GET /seguranca`.
- The fingerprints are calculated from the files of `DATA_DIR/certs` (FTP) and `DATA_DIR/painel/tls` (panel), the same ones the services use.
- The lines with address and network come from the `.env`. By default the stack refuses to start with a value that is not private; with `REDE_PERMITIR_IP_PUBLICO=sim`, the public address and network appear with the attention mark: [Security](../security.md#ip-publico).
- The cost of the passwords compares the memory stored in the password of each user with the one of the current size profile, calculated from `FTP_MAX_CLIENTS`; the hash does not leave the user database: [Cost of the passwords](../security.md#custo-das-senhas).
- The contact is the value of `SEGURANCA_CONTATO_EMAIL`; the file `/.well-known/security.txt` follows RFC 9116: [Security contact](../security.md#contato-de-seguranca).
- The last line has no checked mark on purpose: no container of the stack reads the firewall rules of the host.

</details>

---

<a name="bloqueios"></a>

## 🚫 Blocks

<a href="images/bloqueios.png"><img src="images/bloqueios.png" alt="Blocks tab with the rule in use below the title, the Block address button, four blocked addresses, in IPv4 and in IPv6, for errors on FTP, for errors on the panel and by an administrator, each with since when, until when and the Change period and Unblock buttons, and the Users blocked on FTP card, with the user switch-core" width="100%"></a>

<sub><b>v0.31.1</b> · Blocks menu · captured on 2026-10-10</sub>

**What it is for:** following the addresses that got user name and password wrong too many times, releasing one of them, blocking for a longer or a shorter time and blocking a new address, or a whole network, before it gets anything wrong.

**How to get there:** menu ➜ **Blocks**; in the Security tab, the **Blocking by address** line says how many are blocked.

| Screen item | What it shows or does |
|---|---|
| Sentence below the title | The rule in use (how many errors, in how many hours and for how many days) and how many addresses are blocked now |
| **Block address** | Opens the screen that blocks a new address or a prefix: see [Blocks ➜ Block address](#bloqueios) |
| Address or prefix | The address, IPv4 or IPv6, or the whole network that cannot connect to FTP or to the panel |
| Blocked by | How many errors were counted and where, `on FTP` or `on the panel`; `Administrator` on the block made by whoever administers |
| Since · Until | When the block started and when it goes away on its own, with the period in days |
| **Change period** | Opens the screen of the address, at the **Period** card |
| **Unblock** | Opens the same screen, at the **Unblock** card |
| **Search address** | Search field, which appears when the list goes over 10 addresses |
| **How blocking by address works** | Collapsed below the list: what the block refuses, what resets the count of errors and what is never blocked on its own |
| **Users blocked on FTP** | The short block, of one user for one address, with the shortcut **Open the user**: see [Users ➜ Blocks](#usuarios) |

The blocked address is refused with any account, even with the right password, on FTP (with and without TLS, in active or passive mode) and on the panel. By default, the block comes on the sixth user name and password error in 24 hours and lasts 120 days: these are the values of `BLOQUEIO_ENDERECO_ERROS`, `BLOQUEIO_ENDERECO_HORAS` and `BLOQUEIO_ENDERECO_DIAS`, and with `BLOQUEIO_ENDERECO_ERROS=0` the automatic block is turned off. It applies to IPv4 and to IPv6. On its own, the block is always of one address, and the sign-in with the right user name and password resets the count of its errors; a prefix, only the administrator blocks. The server itself, the internal network of the stack and the proxies of `PAINEL_PROXY_CONFIAVEL` are never blocked on their own. The rules are in [Security](../security.md#bloqueio-por-endereco).

> ⚠️ **Shared address:** devices that reach the server from the same address, behind NAT, are blocked together. Before unblocking, find out which of them has the wrong password.

<details>
<summary>Blocks ➜ Block address — click to expand</summary>

### Blocks ➜ Block address

<a href="images/bloqueios-novo.png"><img src="images/bloqueios-novo.png" alt="Block address or prefix screen, with the Address or prefix field filled in with 2001:db8:12::/64, the Keep blocked for field with 90, the note about what the panel does not block and the Block and Cancel buttons" width="100%"></a>

<sub><b>v0.31.1</b> · Blocks menu, Block address or prefix screen · captured on 2026-10-10</sub>

| Field | Required | What to fill in |
|---|---|---|
| Address or prefix | Yes | An address, IPv4 or IPv6, such as `203.0.113.7` or `2001:db8::7`, or a whole network, such as `203.0.113.0/24`. An IPv4 prefix goes from `/8` to `/31` and an IPv6 one, from `/16` to `/127` |
| Keep blocked for | Yes | Days counted from now, from 1 to 3650; it comes filled in with the period of the automatic block |

<a href="images/bloqueios-bloqueado.png"><img src="images/bloqueios-bloqueado.png" alt="Blocks tab with the message Block saved, it applies to FTP and to the panel from the next request, and the prefix 2001:db8:12::/64 in the list, blocked by Administrator, for 90 days" width="100%"></a>

<sub><b>v0.31.1</b> · Blocks menu, after the block · captured on 2026-10-10</sub>

**Expected result:** after **Block**, the list comes back with the message `Block saved: it applies to FTP and to the panel from the next request.` and the new row, with `Administrator` in the **Blocked by** column. What was blocked no longer connects to FTP or to the panel, with any account, until the period ends or someone unblocks it. An address that was already in the list only has its period changed, with the message `Block period changed.`

| Message | Reason |
|---|---|
| Invalid address or prefix: use an IPv4 address, an IPv6 address or a prefix, such as 203.0.113.7, 2001:db8::7 or 203.0.113.0/24. | What was typed is not an address or a prefix, or the prefix is too wide |
| This address belongs to the server itself: it cannot be blocked. | The target is the server itself |
| Invalid period: 1 to 3650 days. | The period is out of range |
| This block would catch the address you are using the panel from | The target is, or contains, the address of whoever is asking for the block; the message says which one it is and ends with `Nothing was blocked.` |
| This block would catch the internal network of the stack or a trusted proxy | The target is, or contains, the internal network of the stack or a proxy of `PAINEL_PROXY_CONFIAVEL`, through which the visitors arrive |

> ⚠️ **A prefix blocks everyone inside it:** a whole blocked network takes along the devices that are in it, including those that sign in with the right password. Check the prefix before saving and prefer the single address when it is enough.

</details>

<details>
<summary>Blocks ➜ Change period — click to expand</summary>

### Blocks ➜ Change period

<a href="images/bloqueios-endereco.png"><img src="images/bloqueios-endereco.png" alt="Block of 192.0.2.61 screen with the Period card, which says who blocked it, since when and until when, the Keep blocked for field filled in with 365 and the Save period button, and the Unblock card, with the Unblock button" width="100%"></a>

<sub><b>v0.31.1</b> · Blocks menu, screen of the address · captured on 2026-10-10</sub>

| Field | Required | What to fill in |
|---|---|---|
| Keep blocked for | Yes | Days counted from now, from 1 to 3650. The new period replaces the current one: it is for blocking longer or for shortening the block |

<a href="images/bloqueios-prazo-alterado.png"><img src="images/bloqueios-prazo-alterado.png" alt="Blocks tab with the message Block period changed and the address 192.0.2.61 blocked for 365 days" width="100%"></a>

<sub><b>v0.31.1</b> · Blocks menu, after the period change · captured on 2026-10-10</sub>

**Expected result:** after **Save period**, the list comes back with the message `Block period changed.` and the **Until** column shows the new date. A number out of range returns the screen with `Invalid period: 1 to 3650 days.`

</details>

<details>
<summary>Blocks ➜ Unblock — click to expand</summary>

### Blocks ➜ Unblock

1. Fix the password on the device: if it keeps getting it wrong, the block comes back.
2. Click **Unblock** on the row of the address.
3. On the screen of the address, click **Unblock**.

<a href="images/bloqueios-liberado.png"><img src="images/bloqueios-liberado.png" alt="Blocks tab with the message Block removed, whoever was in it can connect to FTP and to the panel again, and three addresses in the list, without 198.51.100.24" width="100%"></a>

<sub><b>v0.31.1</b> · Blocks menu, after the unblock · captured on 2026-10-10</sub>

**Expected result:** the list comes back with the message `Block removed: whoever was in it can connect to FTP and to the panel again.`, the address connects again on the next request and the count of its errors starts over. For a prefix, every address in it connects again. If the block had already gone away, the message is `This block is no longer in force.`

The administrator whose own address got blocked does not open the panel: the release is from the server, with `./manage-user.sh endereco-liberar <address>`.

</details>

<details>
<summary>Technical detail — routes and events</summary>

- Routes: `GET /bloqueios` lists, with `?q=<text>` for the search; `GET /bloqueios/novo` shows the blocking screen and `POST /bloqueios/novo` saves the block; `GET /bloqueios/endereco?ip=<address or prefix>` shows the screen of the address; `POST /bloqueios/prazo` saves the period and `POST /bloqueios/liberar` unblocks. Every `POST` carries the CSRF token of the session.
- The list is a single one for FTP and for the panel; from the terminal, it is the one of `./manage-user.sh enderecos`, and the manual block is `./manage-user.sh endereco-bloquear <address or prefix> [days]`.
- The events `endereco_bloqueado`, `endereco_bloqueado_manual`, `endereco_prazo`, `endereco_desbloqueado` and, on each request refused on the panel, `recusa_endereco` are in the [audit log](../panel.md#auditoria).
- The full behaviour is in [Blocks](../panel.md#bloqueios).

</details>

---

<a name="atividade"></a>

## 📜 Log

<a href="images/atividade.png"><img src="images/atividade.png" alt="Log tab with the records of the panel in four columns: when, from where, with the whole address on a single line or on the server, what happened, with one icon per event, and the detail, such as file downloaded, folder created, administrator created, address unblocked and screen outside the role or profile requested by an FTP user" width="100%"></a>

<sub><b>v0.31.1</b> · Log menu · captured on 2026-10-10</sub>

**What it is for:** knowing who signed in to the panel, from where, what was changed and who downloaded each file.

**How to get there:** menu ➜ **Log**.

| Column | What it shows |
|---|---|
| When | Date and time of the record, from the newest to the oldest |
| From | Address of whoever made the request, always whole and on a single line, whether IPv4 or IPv6; `on the server` for what the panel itself records, such as the start of the service |
| What happened | The event, in one sentence and with an icon: the table below lists the main ones. Refusal and block come out in red; change not completed and interrupted download, in yellow |
| Detail | Who did it (`administrator` or `user`), who or what was changed, the path and the size of the file. Password and token never appear |

| What happened | When it appears |
|---|---|
| Panel started · Initial administrator created | The service of the panel started, with the version, and the account of the first administrator was created on installation |
| Sign-in · Sign-in refused · Sign-in blocked by the attempt limit · Sign-out | Someone signed in, got the user name or the password wrong, had the address blocked or signed out |
| User created · Password changed · User folder changed · User profile changed · User removed | Change of an FTP user, with the administrator who did it |
| User limits changed · FTP block of the user removed | Limits saved, with the value of each one, and block for wrong password removed in **Edit** |
| User automatic cleanup changed · Automatic cleanup: old files deleted · Automatic cleanup not completed | The rule saved or turned off in **Edit**, with the administrator who did it; each run that deleted something, with the user and the amount; and the run that did not finish |
| Address blocked for user name and password errors · Address or prefix blocked by the administrator · Address block period changed · Address unblocked · Request from a blocked address | The panel blocked an address, an administrator blocked, changed the period or released it in the Blocks tab, and each refused request from a blocked address |
| User exempted from TLS · User requires TLS again | Change of the TLS of a user |
| File downloaded · Download interrupted | Download through the Files tab or through the My files screen, complete or cut before the end |
| File uploaded through the panel · Upload interrupted · Upload through the panel without the permission | Upload through the Files tab, through the My files screen or through the File upload screen, complete or cut before the end, and the upload requested by an account that does not have the permission |
| Folder created · File or folder renamed · File or folder deleted | Change through the Files tab or through the My files screen, with the path; the deleted one also appears when the folder goes together with the user |
| Administrator created · Administrator password changed · Administrator renamed · Administrator removed | Change of an administrator, with who did it and who was changed |
| Current password refused | Change of an administrator refused by the confirmation password |
| FTP password refused on confirmation | An FTP user got their own password wrong when confirming a name change or a deletion on the My files screen |
| Screen outside the role or profile requested by an FTP user | An FTP user requested an administration tab, or an action their profile does not have, and got `404` |
| FTP user session closed | The password, the folder or the profile of the user changed, or the user was removed |
| File path refused | Request that tries to leave the data folder or that goes through a symbolic link |

The tab shows the last 300 records, and the collapsed **What is recorded**, below the list, sums up what goes into them. The transfers of the devices by FTP are not here: they are in the FTP log, in [Operation](../operation.md#logs).

<details>
<summary>Technical detail — file and events</summary>

- Route `GET /atividade`.
- The records come from `DATA_DIR/painel/auditoria.log` (`0600`, owned by `root`). The full list of events, with the name of each one in the file, is in [Web panel](../panel.md#auditoria).
- The name typed in a refused sign-in is not written: it is common for the password to end up in that field by mistake.
- In the screenshot, `172.29.5.1` is the address of the host seen by the internal network of the photographed stack: the access came from the server itself.

</details>

---

<a name="idioma"></a>

## 🌐 Language

<a href="images/entrar-portugues.png"><img src="images/entrar-portugues.png" alt="Sign-in screen in Portuguese: the headline Backups e arquivos, guardados em um lugar só, the title Entrar no painel, the Usuário and Senha fields, the Entrar button and, below the note, the PT and EN buttons" width="100%"></a>

<sub><b>v0.31.1</b> · sign-in screen, in Portuguese · captured on 2026-10-10</sub>

**What it is for:** using the panel in Portuguese or in English. Each account chooses its own, and the choice of one does not change the screen of the others.

**How to get there:** **PT** and **EN** buttons, at the bottom of the menu of every screen and below the note of the sign-in screen.

| Item | How it works |
|---|---|
| **PT** · **EN** | Switch the language immediately, on the same screen. Portuguese is the default |
| On the sign-in screen | The choice is kept in the browser, for one year |
| After sign-in | The choice is kept on the server, one per account, of administrator or of FTP user: it applies in any browser the account signs in from |
| Account that never chose | Signs in with the language the browser kept and, without that, in Portuguese |
| In English | The date becomes `year-month-day` and the numbers use a decimal point |
| What does not change | Names of users, folders and files, the audit log file and the messages of the FTP and of the scripts |

<a href="images/visao-geral-portugues.png"><img src="images/visao-geral-portugues.png" alt="Overview tab in Portuguese, with the menu, the alert of users without TLS, the measurements, the charts and the recent activity in Portuguese, the dates in day/month/year and the numbers with a decimal comma" width="100%"></a>

<sub><b>v0.31.1</b> · Overview menu, in Portuguese · captured on 2026-10-10</sub>

<a href="images/usuarios-portugues.png"><img src="images/usuarios-portugues.png" alt="Users tab in Portuguese: the title Usuários, the profiles Completo, Envio, Só envio and Leitura, the tags você, limites, dividida and inicial, the TLS column with obrigatório and sem TLS and the buttons Editar, Dispensar TLS, Exigir TLS, Trocar senha, Trocar nome and Remover" width="100%"></a>

<sub><b>v0.31.1</b> · Users menu, in Portuguese · captured on 2026-10-10</sub>

<details>
<summary>Technical detail — where the choice is kept</summary>

- The switch is a `POST /idioma`, with the token of the session or, on the sign-in screen, the one of the form; there is no switch by `GET`.
- On the sign-in screen, the choice goes in the cookie `__Host-idioma` (`Secure`, `HttpOnly`, `SameSite=Lax`), which only accepts `pt` or `en`.
- After sign-in, it is kept in `DATA_DIR/painel/idiomas` (`0600`), one line per account.
- The language switch does not create an audit record.
- The full behaviour is in [Language](../panel.md#idioma).

</details>

---

<a name="como-foram-feitas"></a>

## 🎞️ How the screenshots were made

Real captures of the running panel, made with Playwright on Google Chrome, at 1440×900, in dark theme and in English; three screens were repeated in Portuguese, for the [Language](#idioma) section. The guide in Portuguese has the same screens, photographed with the panel in Portuguese. The photographed stack was a demonstration installation, separate from the installation in use: it came up on `127.0.0.4`, with its own container names, network, data folder and secrets, and received example users and files over FTPS; the uploads through the panel used example files, created for the screenshot. Where the panel states the folder of the server, as in the caption of the Users tab and on the **Edit** screen, the demonstration shows the default folder of `.env.example`, in place of the temporary folder it actually came up in.

No password appears in the images: the password fields are masked by the browser and the generated password was replaced by `<REDACTED>` before the capture. The fingerprints are those of the self-signed certificates of the photographed installation; each installation generates its own. The e-mail of the security contact is an example address.

The addresses of the Blocks tab are documentation addresses (RFC 5737 and `2001:db8::/32`, from RFC 3849) and entered the list through the same command the FTP and the panel use to block. `172.29.5.1` is the host seen by the internal network of the demonstration: the access and the wrong passwords came from the server itself. In the Server tab and in the **Server and containers** card, the server resources are those of the machine the demonstration ran on.

To open the images outside GitHub, with zoom and pan: [`images/visualizador.html`](images/visualizador.html).

---

⬅️ [Web panel](../panel.md) · 🏠 [Documentation](../README.md) · ➡️ [Troubleshooting](../troubleshooting.md)
