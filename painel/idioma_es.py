# SPDX-License-Identifier: Apache-2.0
"""Catálogo do espanhol: o texto em português, que é a chave, e o texto em espanhol.

As chaves são as do catálogo do inglês (idioma_en.py), na mesma ordem. A tradução mantém os nomes entre chaves, as
marcas do HTML e as aspas da chave; os valores entram depois, já prontos para o HTML. O scripts/validate.sh confere
se cada texto do código tem tradução aqui e se não sobra nenhuma.
"""
import re

ES = {
    'A sua conta de administrador não existe mais. Saia e entre de novo.':
        'Su cuenta de administrador ya no existe. Salga y vuelva a entrar.',
    'Administrador não encontrado':
        'Administrador no encontrado',
    'Ninguém remove a própria conta, para o painel nunca ficar sem administrador. Peça a outro '
    'administrador para removê-la.':
        'Nadie elimina su propia cuenta, para que el panel nunca quede sin administrador. Pida a otro '
        'administrador que la elimine.',
    'A sua senha antiga deixa de valer na hora e as outras sessões desse administrador são encerradas.':
        'Su contraseña antigua deja de valer en el acto y las demás sesiones de este administrador se cierran.',
    'A senha de <strong>{nome}</strong> antiga deixa de valer na hora e as outras sessões desse '
    'administrador são encerradas.':
        'La contraseña antigua de <strong>{nome}</strong> deja de valer en el acto y las demás sesiones de '
        'este administrador se cierran.',
    'Já existe um administrador com este nome.':
        'Ya existe un administrador con este nombre.',
    'Limite de {maximo} administradores atingido: remova um antes de criar outro.':
        'Límite de {maximo} administradores alcanzado: elimine uno antes de crear otro.',
    'Administrador criado':
        'Administrador creado',
    'Trocar senha':
        'Cambiar contraseña',
    'Este administrador não existe mais.':
        'Este administrador ya no existe.',
    'Senha trocada':
        'Contraseña cambiada',
    'Trocar nome':
        'Cambiar nombre',
    'Remover administrador':
        'Eliminar administrador',
    'Nome inválido. Veja a regra abaixo do campo.':
        'Nombre no válido. Vea la regla debajo del campo.',
    'O nome novo é igual ao atual.':
        'El nombre nuevo es igual al actual.',
    'Voltar para a lista':
        'Volver a la lista',
    'Administrador <strong>{nome}</strong>. Senha gerada pelo painel:':
        'Administrador <strong>{nome}</strong>. Contraseña generada por el panel:',
    'Copie agora para o seu cofre de senhas ou entregue a quem vai usar. Ela <strong>não será mostrada '
    'de novo</strong>: o painel guarda só o hash.':
        'Cópiela ahora en su gestor de contraseñas o entréguela a quien la va a usar. <strong>No se mostrará '
        'de nuevo</strong>: el panel guarda solo el hash.',
    'Já copiei: voltar para a lista':
        'Ya la copié: volver a la lista',
    'Trocar senha de administrador':
        'Cambiar contraseña de administrador',
    'Cancelar':
        'Cancelar',
    'Trocar nome de administrador':
        'Cambiar nombre de administrador',
    'Administrador <strong>{nome}</strong>. A senha continua a mesma; o nome antigo deixa de entrar na '
    'hora.':
        'Administrador <strong>{nome}</strong>. La contraseña sigue siendo la misma; el nombre antiguo deja '
        'de entrar en el acto.',
    'Nome novo':
        'Nombre nuevo',
    'Letras minúsculas, números, <code>_</code> e <code>-</code>; começa com letra ou <code>_</code>; '
    'até 32 caracteres.':
        'Letras minúsculas, números, <code>_</code> y <code>-</code>; empieza con letra o <code>_</code>; '
        'hasta 32 caracteres.',
    'Esta é a sua conta':
        'Esta es su cuenta',
    'Remover <strong>{nome}</strong>? Ele deixa de entrar no painel na hora e as sessões abertas dele '
    'são encerradas. Os usuários do FTP e os arquivos não mudam.':
        '¿Eliminar <strong>{nome}</strong>? Deja de entrar en el panel en el acto y sus sesiones abiertas se '
        'cierran. Los usuarios del FTP y los archivos no cambian.',
    'Sim, remover o administrador':
        'Sí, eliminar el administrador',
    'Não foi possível gravar o arquivo de administradores:':
        'No fue posible guardar el archivo de administradores:',
    'erro de disco':
        'error de disco',
    'Letras, números, <code>_</code>, <code>-</code> e ponto; não começa com ponto; até 64 caracteres.':
        'Letras, números, <code>_</code>, <code>-</code> y punto; no empieza con punto; hasta 64 caracteres.',
    'Caminho não aceito.':
        'Ruta no aceptada.',
    'Link simbólico não é seguido pelo painel.':
        'El panel no sigue enlaces simbólicos.',
    'Pasta ou arquivo não encontrado.':
        'Carpeta o archivo no encontrado.',
    'Pasta criada.':
        'Carpeta creada.',
    'Nome trocado.':
        'Nombre cambiado.',
    'Apagado.':
        'Borrado.',
    'A pasta tem mais do que o painel apaga de uma vez ({maximo} itens ou {prazo} segundos por '
    'pedido). Repita para continuar.':
        'La carpeta tiene más de lo que el panel borra de una vez ({maximo} elementos o {prazo} segundos por '
        'solicitud). Repita para continuar.',
    'Um item não pôde ser apagado, ou a pasta recebeu arquivo durante a limpeza. Confira a pasta e '
    'repita.':
        'Un elemento no pudo borrarse, o la carpeta recibió un archivo durante la limpieza. Revise la '
        'carpeta y repita.',
    'O painel já está apagando outra pasta. Espere terminar e repita.':
        'El panel ya está borrando otra carpeta. Espere a que termine y repita.',
    'Trocar o nome da pasta <strong>{nome}</strong>, em {onde}.':
        'Cambiar el nombre de la carpeta <strong>{nome}</strong>, en {onde}.',
    'Trocar o nome do arquivo <strong>{nome}</strong>, em {onde}.':
        'Cambiar el nombre del archivo <strong>{nome}</strong>, en {onde}.',
    'Trocar o nome do link simbólico <strong>{nome}</strong>, em {onde}.':
        'Cambiar el nombre del enlace simbólico <strong>{nome}</strong>, en {onde}.',
    'Trocar o nome do arquivo especial <strong>{nome}</strong>, em {onde}.':
        'Cambiar el nombre del archivo especial <strong>{nome}</strong>, en {onde}.',
    'Apagar a pasta <strong>{nome}</strong> e <strong>tudo o que há dentro dela</strong>: {arquivos} '
    'arquivo(s), {tamanho}, em {onde}?':
        '¿Borrar la carpeta <strong>{nome}</strong> y <strong>todo lo que hay dentro de ella</strong>: '
        '{arquivos} archivo(s), {tamanho}, en {onde}?',
    'Apagar o arquivo <strong>{nome}</strong>, de {tamanho}, modificado em {quando}, em {onde}?':
        '¿Borrar el archivo <strong>{nome}</strong>, de {tamanho}, modificado el {quando}, en {onde}?',
    'Apagar o link simbólico <strong>{nome}</strong>; o destino dele não é tocado, em {onde}?':
        '¿Borrar el enlace simbólico <strong>{nome}</strong>; su destino no se toca, en {onde}?',
    'Apagar o arquivo especial <strong>{nome}</strong>; o destino dele não é tocado, em {onde}?':
        '¿Borrar el archivo especial <strong>{nome}</strong>; su destino no se toca, en {onde}?',
    'A pasta <strong>{nome}</strong> não é renomeada por aqui: é a pasta, ou tem dentro dela a pasta, '
    'de {de_quem}.':
        'La carpeta <strong>{nome}</strong> no se renombra desde aquí: es la carpeta, o contiene la carpeta, '
        'de {de_quem}.',
    'A pasta <strong>{nome}</strong> não é apagada por aqui: é a pasta, ou tem dentro dela a pasta, de '
    '{de_quem}.':
        'La carpeta <strong>{nome}</strong> no se borra desde aquí: es la carpeta, o contiene la carpeta, de '
        '{de_quem}.',
    'Tamanho':
        'Tamaño',
    'Modificado':
        'Modificado',
    'A pasta nasce vazia, dentro da sua pasta no FTP.':
        'La carpeta nace vacía, dentro de su carpeta en el FTP.',
    'A pasta nasce vazia; para um equipamento gravar nela, crie um usuário com esta pasta.':
        'La carpeta nace vacía; para que un equipo grabe en ella, cree un usuario con esta carpeta.',
    'outro usuário do FTP':
        'otro usuario del FTP',
    'Peça ao administrador do painel.':
        'Pídalo al administrador del panel.',
    'Para dar outra pasta a um usuário, use <strong>Usuários ➜ Editar</strong>. Para apagar a pasta '
    'junto com o usuário, use <strong>Usuários ➜ Remover</strong>.':
        'Para dar otra carpeta a un usuario, use <strong>Usuarios ➜ Editar</strong>. Para borrar la carpeta '
        'junto con el usuario, use <strong>Usuarios ➜ Eliminar</strong>.',
    'Apagado em parte':
        'Borrado en parte',
    'Nada foi apagado':
        'No se borró nada',
    'Início':
        'Inicio',
    'Renomear':
        'Renombrar',
    'Apagar':
        'Borrar',
    'Pasta vazia':
        'Carpeta vacía',
    'O que for enviado para ela por FTP aparece aqui.':
        'Lo que se envíe a ella por FTP aparece aquí.',
    'Arquivos':
        'Archivos',
    'Nova pasta':
        'Nueva carpeta',
    'Nome da pasta, criada dentro de <code>{onde}</code>':
        'Nombre de la carpeta, creada dentro de <code>{onde}</code>',
    'Criar pasta':
        'Crear carpeta',
    'O limite deste usuário é de {quantos} arquivo(s) por vez.':
        'El límite de este usuario es de {quantos} archivo(s) por vez.',
    'Meus arquivos':
        'Mis archivos',
    'link simbólico':
        'enlace simbólico',
    'arquivo especial':
        'archivo especial',
    'Esta pasta tem mais de {maximo} itens: a lista mostra só os primeiros {maximo}. Para ver todos, '
    'entre por FTP.':
        'Esta carpeta tiene más de {maximo} elementos: la lista muestra solo los primeros {maximo}. Para '
        'verlos todos, entre por FTP.',
    'Pasta do usuário do FTP: <strong>{donos}</strong>.':
        'Carpeta del usuario del FTP: <strong>{donos}</strong>.',
    'Novo usuário nesta pasta':
        'Nuevo usuario en esta carpeta',
    'Nome não aceito':
        'Nombre no aceptado',
    'Use letras, números, _, - e ponto; o nome não começa com ponto e tem até 64 caracteres.':
        'Use letras, números, _, - y punto; el nombre no empieza con punto y tiene hasta 64 caracteres.',
    'Nome já usado':
        'Nombre ya usado',
    'Já existe uma pasta ou um arquivo com este nome.':
        'Ya existe una carpeta o un archivo con este nombre.',
    'Pasta não criada':
        'Carpeta no creada',
    'Não foi possível criar a pasta.':
        'No fue posible crear la carpeta.',
    'ou mais':
        'o más',
    '<strong>{itens}</strong> item(ns) apagado(s); o restante continua no lugar.':
        '<strong>{itens}</strong> elemento(s) borrado(s); el resto sigue en su lugar.',
    'O painel entrega até {maximo} arquivos por vez.':
        'El panel entrega hasta {maximo} archivos por vez.',
    'Pedido recusado':
        'Solicitud rechazada',
    'Voltar para {tela}':
        'Volver a {tela}',
    'pasta':
        'carpeta',
    'Abrir':
        'Abrir',
    'Nome':
        'Nombre',
    'Ações':
        'Acciones',
    'Voltar para a pasta':
        'Volver a la carpeta',
    'Pasta de usuário do FTP':
        'Carpeta de usuario del FTP',
    'O que está dentro dela pode ser renomeado e apagado item por item.':
        'Lo que hay dentro de ella puede renombrarse y borrarse elemento por elemento.',
    'O item continua na mesma pasta: o painel não move de uma pasta para outra. O equipamento que '
    'grava com o nome antigo cria outro arquivo no envio seguinte.':
        'El elemento sigue en la misma carpeta: el panel no mueve de una carpeta a otra. El equipo que graba '
        'con el nombre antiguo crea otro archivo en el envío siguiente.',
    'Nome não aceito. Veja a regra abaixo do campo.':
        'Nombre no aceptado. Vea la regla debajo del campo.',
    'O item já tem este nome.':
        'El elemento ya tiene este nombre.',
    'O painel <strong>não tem lixeira</strong>: o que for apagado só volta de uma cópia de segurança.':
        'El panel <strong>no tiene papelera</strong>: lo que se borre solo vuelve de una copia de seguridad.',
    'Conferi o nome e quero apagar':
        'Revisé el nombre y quiero borrar',
    'Apagar de vez':
        'Borrar definitivamente',
    'Marque a caixa de confirmação. Nada foi apagado.':
        'Marque la casilla de confirmación. No se borró nada.',
    'Repetir':
        'Repetir',
    'Voltar':
        'Volver',
    'Baixar':
        'Descargar',
    'não abre aqui':
        'no se abre aquí',
    'O que os equipamentos já enviaram, pasta por pasta.':
        'Lo que los equipos ya enviaron, carpeta por carpeta.',
    'O que dá para fazer nesta aba':
        'Qué se puede hacer en esta pestaña',
    'Não foi possível trocar o nome.':
        'No fue posible cambiar el nombre.',
    'Muitos downloads ao mesmo tempo':
        'Demasiadas descargas al mismo tiempo',
    'Espere um deles terminar e repita.':
        'Espere a que una de ellas termine y repita.',
    'para apagar':
        'para borrar',
    'administrador':
        'administrador',
    'usuário':
        'usuario',
    'versão':
        'versión',
    'ação':
        'acción',
    'conferência':
        'verificación',
    'senha':
        'contraseña',
    'conta':
        'cuenta',
    'conta nova':
        'cuenta nueva',
    'pasta anterior':
        'carpeta anterior',
    'endereço pedido':
        'dirección solicitada',
    'tamanho':
        'tamaño',
    'endereço':
        'dirección',
    'Quem entrou e o que foi feito no painel: os últimos 300 registros, do mais novo para o mais '
    'antigo.':
        'Quién entró y qué se hizo en el panel: los últimos 300 registros, del más nuevo al más antiguo.',
    'Painel iniciado':
        'Panel iniciado',
    'Entrada':
        'Entrada',
    'Entrada recusada':
        'Entrada rechazada',
    'Entrada bloqueada pelo limite de tentativas':
        'Entrada bloqueada por el límite de intentos',
    'Saída':
        'Salida',
    'Sessão de usuário do FTP encerrada':
        'Sesión de usuario del FTP cerrada',
    'Usuário criado':
        'Usuario creado',
    'Pasta do usuário trocada':
        'Carpeta del usuario cambiada',
    'Perfil do usuário trocado':
        'Perfil del usuario cambiado',
    'Limites do usuário alterados':
        'Límites del usuario modificados',
    'Bloqueio do usuário no FTP removido':
        'Bloqueo del usuario en el FTP eliminado',
    'Endereço bloqueado por erros de usuário e senha':
        'Dirección bloqueada por errores de usuario y contraseña',
    'Prazo do bloqueio de endereço alterado':
        'Plazo del bloqueo de dirección modificado',
    'Endereço desbloqueado':
        'Dirección desbloqueada',
    'Usuário removido':
        'Usuario eliminado',
    'Usuário dispensado do TLS':
        'Usuario dispensado del TLS',
    'Usuário volta a exigir TLS':
        'El usuario vuelve a exigir TLS',
    'Alteração não concluída':
        'Cambio no concluido',
    'Arquivo baixado':
        'Archivo descargado',
    'Pasta criada':
        'Carpeta creada',
    'Arquivo ou pasta renomeado':
        'Archivo o carpeta renombrado',
    'Arquivo ou pasta apagado':
        'Archivo o carpeta borrado',
    'Download interrompido':
        'Descarga interrumpida',
    'Arquivo enviado pelo painel':
        'Archivo enviado por el panel',
    'Envio interrompido':
        'Envío interrumpido',
    'Envio pelo painel sem a permissão':
        'Envío por el panel sin el permiso',
    'Administrador inicial criado':
        'Administrador inicial creado',
    'Senha de administrador trocada':
        'Contraseña de administrador cambiada',
    'Administrador renomeado':
        'Administrador renombrado',
    'Administrador removido':
        'Administrador eliminado',
    'Administrador definido pelo host':
        'Administrador definido por el host',
    'Senha atual recusada':
        'Contraseña actual rechazada',
    'Senha do FTP recusada na confirmação':
        'Contraseña del FTP rechazada en la confirmación',
    'Envio sem token válido':
        'Envío sin token válido',
    'Envio de outra origem':
        'Envío desde otro origen',
    'Endereço não aceito':
        'Dirección no aceptada',
    'Cliente fora das redes permitidas':
        'Cliente fuera de las redes permitidas',
    'Pedido de endereço bloqueado':
        'Solicitud desde una dirección bloqueada',
    'Caminho de arquivo recusado':
        'Ruta de archivo rechazada',
    'Tela fora do papel ou do perfil pedida por usuário do FTP':
        'Pantalla fuera del rol o del perfil solicitada por usuario del FTP',
    'Nada registrado ainda':
        'Nada registrado todavía',
    'Cada entrada no painel e cada alteração feita por ele passa a aparecer aqui.':
        'Cada entrada en el panel y cada cambio hecho por él pasa a aparecer aquí.',
    'Log':
        'Log',
    'no servidor':
        'en el servidor',
    'Nada registrado ainda.':
        'Nada registrado todavía.',
    'De onde':
        'Desde dónde',
    'Quando':
        'Cuándo',
    'O que aconteceu':
        'Qué ocurrió',
    'Detalhe':
        'Detalle',
    'O que fica registrado':
        'Qué queda registrado',
    'Senha e token nunca são gravados. As transferências dos equipamentos ficam no log do serviço FTP.':
        'La contraseña y el token nunca se guardan. Las transferencias de los equipos quedan en el log del '
        'servicio FTP.',
    '{erros} erros no FTP':
        '{erros} errores en el FTP',
    '{erros} erros no painel':
        '{erros} errores en el panel',
    'Bloqueio desfeito: quem estava nele volta a entrar no FTP e no painel.':
        'Bloqueo deshecho: quien estaba en él vuelve a entrar en el FTP y en el panel.',
    'Prazo do bloqueio alterado.':
        'Plazo del bloqueo modificado.',
    'Este bloqueio não está mais em vigor.':
        'Este bloqueo ya no está en vigor.',
    'O endereço que passa de {erros} de usuário e senha em {horas}, no FTP ou no painel, fica {dias} '
    'sem entrar nos dois.':
        'La dirección que pasa de {erros} de usuario y contraseña en {horas}, en el FTP o en el panel, queda '
        '{dias} sin entrar en los dos.',
    'menos de 1 dia':
        'menos de 1 día',
    '{dias} dias':
        '{dias} días',
    'O bloqueio automático está desligado (<code>BLOQUEIO_ENDERECO_ERROS=0</code>): aqui ficam só os endereços '
    'e prefixos bloqueados pelo administrador.':
        'El bloqueo automático está desactivado (<code>BLOQUEIO_ENDERECO_ERROS=0</code>): aquí quedan solo '
        'las direcciones y los prefijos bloqueados por el administrador.',
    'nenhum endereço bloqueado':
        'ninguna dirección bloqueada',
    '1 bloqueio em vigor':
        '1 bloqueo en vigor',
    '{n} bloqueios em vigor':
        '{n} bloqueos en vigor',
    'Bloqueado por <strong>{quem}</strong>, com {erros} erros de usuário e senha, em {desde}.':
        'Bloqueado por <strong>{quem}</strong>, con {erros} errores de usuario y contraseña, el {desde}.',
    'Bloqueado por <strong>{quem}</strong>, em {desde}.':
        'Bloqueado por <strong>{quem}</strong>, el {desde}.',
    '{n} erro':
        '{n} error',
    '{n} erros':
        '{n} errores',
    '{n} minuto':
        '{n} minuto',
    '{n} minutos':
        '{n} minutos',
    '{n} hora':
        '{n} hora',
    '{n} horas':
        '{n} horas',
    '{n} dia':
        '{n} día',
    '{n} dias':
        '{n} días',
    'Endereço ou prefixo bloqueado pelo administrador':
        'Dirección o prefijo bloqueado por el administrador',
    'Bloquear endereço':
        'Bloquear dirección',
    'Vale para IPv4 e para IPv6. Sozinho, o bloqueio é sempre de um endereço, e a entrada com usuário e senha '
    'certos zera a contagem dos erros dele. Prefixo, que é uma rede inteira, só o administrador bloqueia: em '
    'IPv6 o equipamento costuma trocar de endereço dentro da própria rede, e é o prefixo dela que o segura.':
        'Vale para IPv4 y para IPv6. Por sí solo, el bloqueo es siempre de una dirección, y la entrada con '
        'usuario y contraseña correctos pone a cero el conteo de sus errores. Un prefijo, que es una red '
        'entera, solo lo bloquea el administrador: en IPv6 el equipo suele cambiar de dirección dentro de la '
        'propia red, y es el prefijo de ella el que lo detiene.',
    'Os endereços deste prefixo voltam a entrar no FTP e no painel no próximo pedido.':
        'Las direcciones de este prefijo vuelven a entrar en el FTP y en el panel en la próxima solicitud.',
    'Bloquear endereço ou prefixo':
        'Bloquear dirección o prefijo',
    'O que for bloqueado aqui não entra mais no FTP nem no painel, com conta nenhuma, até o prazo vencer ou '
    'alguém desbloquear.':
        'Lo que se bloquee aquí ya no entra en el FTP ni en el panel, con ninguna cuenta, hasta que venza el '
        'plazo o alguien lo desbloquee.',
    'Endereço ou prefixo <span class="suave">(IPv4 ou IPv6)</span>':
        'Dirección o prefijo <span class="suave">(IPv4 o IPv6)</span>',
    'Um endereço, como <code>203.0.113.7</code> ou <code>2001:db8::7</code>, ou uma rede inteira, como '
    '<code>203.0.113.0/24</code> ou <code>2001:db8:12::/64</code>. Prefixo aceito: IPv4 de /8 a /31 e IPv6 de '
    '/16 a /127.':
        'Una dirección, como <code>203.0.113.7</code> o <code>2001:db8::7</code>, o una red entera, como '
        '<code>203.0.113.0/24</code> o <code>2001:db8:12::/64</code>. Prefijo aceptado: IPv4 de /8 a /31 e '
        'IPv6 de /16 a /127.',
    'O painel não bloqueia o endereço de onde você o está usando, a rede interna da stack nem os proxies de '
    '<code>PAINEL_PROXY_CONFIAVEL</code>. O que já está bloqueado só tem o prazo trocado.':
        'El panel no bloquea la dirección desde la que usted lo está usando, la red interna de la stack ni '
        'los proxies de <code>PAINEL_PROXY_CONFIAVEL</code>. A lo que ya está bloqueado solo se le cambia el plazo.',
    'Bloquear':
        'Bloquear',
    'Este endereço é do próprio servidor: não pode ser bloqueado.':
        'Esta dirección es del propio servidor: no puede bloquearse.',
    'Este bloqueio pegaria o endereço de onde você está usando o painel ({ip}). Nada foi bloqueado.':
        'Este bloqueo alcanzaría la dirección desde la que usted está usando el panel ({ip}). No se bloqueó nada.',
    'Este bloqueio pegaria a rede interna da stack ou um proxy confiável, por onde chegam os visitantes. Nada '
    'foi bloqueado.':
        'Este bloqueo alcanzaría la red interna de la stack o un proxy de confianza, por donde llegan los '
        'visitantes. No se bloqueó nada.',
    'Bloqueio gravado: vale no FTP e no painel a partir do próximo pedido.':
        'Bloqueo guardado: vale en el FTP y en el panel a partir de la próxima solicitud.',
    'Endereço ou prefixo inválido: use um IPv4, um IPv6 ou um prefixo, como 203.0.113.7, 2001:db8::7 ou '
    '203.0.113.0/24.':
        'Dirección o prefijo no válido: use un IPv4, un IPv6 o un prefijo, como 203.0.113.7, 2001:db8::7 o '
        '203.0.113.0/24.',
    'Usuários bloqueados no FTP':
        'Usuarios bloqueados en el FTP',
    'Bloqueio curto, de um usuário para um endereço: os outros usuários seguem entrando por ele. Vence '
    'sozinho e é desfeito em Editar, na aba Usuários.':
        'Bloqueo corto, de un usuario para una dirección: los demás usuarios siguen entrando por ella. Vence '
        'solo y se deshace en Editar, en la pestaña Usuarios.',
    'Usuário':
        'Usuario',
    'Origem':
        'Origen',
    'Senhas erradas':
        'Contraseñas incorrectas',
    'Bloqueado em':
        'Bloqueado el',
    'Até':
        'Hasta',
    'Nenhum endereço bloqueado com esse trecho':
        'Ninguna dirección bloqueada con ese fragmento',
    'Confira o que foi digitado ou veja a lista inteira.':
        'Revise lo que se escribió o vea la lista entera.',
    'Bloqueios':
        'Bloqueos',
    'Bloqueio de {ip}':
        'Bloqueo de {ip}',
    'Nenhum endereço bloqueado agora':
        'Ninguna dirección bloqueada ahora',
    'Quem passar do limite de erros de usuário e senha, no FTP ou no painel, aparece aqui.':
        'Quien pase del límite de errores de usuario y contraseña, en el FTP o en el panel, aparece aquí.',
    'Nada é bloqueado sozinho nesta instalação: só pelo administrador, aqui ou no terminal do servidor.':
        'Nada se bloquea solo en esta instalación: solo por el administrador, aquí o en el terminal del servidor.',
    'Procurar endereço':
        'Buscar dirección',
    'Procurar':
        'Buscar',
    'Mostrando os {mostrados} mais recentes de {achados}: use a busca para chegar aos outros.':
        'Mostrando los {mostrados} más recientes de {achados}: use la búsqueda para llegar a los demás.',
    'Prazo inválido: de 1 a 3650 dias.':
        'Plazo no válido: de 1 a 3650 días.',
    'Bloqueado por':
        'Bloqueado por',
    'Desde':
        'Desde',
    'Mudar prazo':
        'Cambiar plazo',
    'Desbloquear':
        'Desbloquear',
    'Endereço ou prefixo':
        'Dirección o prefijo',
    'Bloqueio de <code>{ip}</code>':
        'Bloqueo de <code>{ip}</code>',
    'Prazo':
        'Plazo',
    'Vale até <strong>{ate}</strong> ({falta}).':
        'Vale hasta <strong>{ate}</strong> ({falta}).',
    'Manter bloqueado por <span class="suave">(dias, contados de agora; de 1 a 3650)</span>':
        'Mantener bloqueado por <span class="suave">(días, contados desde ahora; de 1 a 3650)</span>',
    'O prazo novo substitui o atual: serve para bloquear por mais tempo ou para encurtar o bloqueio.':
        'El plazo nuevo sustituye al actual: sirve para bloquear por más tiempo o para acortar el bloqueo.',
    'Gravar prazo':
        'Guardar plazo',
    'O endereço volta a entrar no FTP e no painel no próximo pedido, e a contagem dos erros dele '
    'recomeça.':
        'La dirección vuelve a entrar en el FTP y en el panel en la próxima solicitud, y el conteo de sus '
        'errores vuelve a empezar.',
    'Antes de desbloquear, corrija a senha no equipamento: se ele continuar errando, o bloqueio volta.':
        'Antes de desbloquear, corrija la contraseña en el equipo: si sigue fallando, el bloqueo vuelve.',
    'Abrir o usuário':
        'Abrir el usuario',
    '{regra} Agora: {total}.':
        '{regra} Ahora: {total}.',
    'Como funciona o bloqueio por endereço':
        'Cómo funciona el bloqueo por dirección',
    'Não foi possível gravar:':
        'No fue posible guardar:',
    'Não foi possível desbloquear:':
        'No fue posible desbloquear:',
    'Ver todos':
        'Ver todos',
    'Nunca são bloqueados sozinhos o próprio servidor, a rede interna da stack e os proxies de '
    '<code>PAINEL_PROXY_CONFIAVEL</code>. Administrador que ficou com o próprio endereço bloqueado '
    'libera pelo servidor: <code>./manage-user.sh endereco-liberar &lt;endereço&gt;</code>.':
        'Nunca se bloquean solos el propio servidor, la red interna de la stack y los proxies de '
        '<code>PAINEL_PROXY_CONFIAVEL</code>. El administrador que quedó con su propia dirección bloqueada '
        'la libera desde el servidor: <code>./manage-user.sh endereco-liberar &lt;dirección&gt;</code>.',
    'O endereço bloqueado é recusado com qualquer conta, mesmo com a senha certa, no FTP (com e sem '
    'TLS, em modo ativo ou passivo) e no painel. Desbloquear vale no próximo pedido; mudar o prazo '
    'serve para bloquear por mais tempo ou para encurtar.':
        'La dirección bloqueada se rechaza con cualquier cuenta, incluso con la contraseña correcta, en el '
        'FTP (con y sin TLS, en modo activo o pasivo) y en el panel. Desbloquear vale en la próxima '
        'solicitud; cambiar el plazo sirve para bloquear por más tiempo o para acortarlo.',
    'Arquivos da pasta do usuário <strong>{usuario}</strong> no FTP.':
        'Archivos de la carpeta del usuario <strong>{usuario}</strong> en el FTP.',
    'Os arquivos da sua pasta no FTP, para navegar e baixar.':
        'Los archivos de su carpeta en el FTP, para navegar y descargar.',
    'Aqui você navega e baixa. O perfil desta conta é de leitura: ela não cria, não envia, não '
    'renomeia e não apaga nada, nem aqui nem por FTP. Todo download fica registrado.':
        'Aquí usted navega y descarga. El perfil de esta cuenta es de lectura: no crea, no envía, no '
        'renombra y no borra nada, ni aquí ni por FTP. Toda descarga queda registrada.',
    'Os arquivos da sua pasta no FTP, para navegar, baixar e criar pasta.':
        'Los archivos de su carpeta en el FTP, para navegar, descargar y crear carpetas.',
    'Os arquivos da sua pasta no FTP, para navegar, baixar e organizar.':
        'Los archivos de su carpeta en el FTP, para navegar, descargar y organizar.',
    'FTP sem TLS (texto puro), modo passivo':
        'FTP sin TLS (texto plano), modo pasivo',
    'FTPS explícito (FTP com TLS) ou, só para equipamento sem TLS, FTP em texto puro; modo passivo':
        'FTPS explícito (FTP con TLS) o, solo para equipos sin TLS, FTP en texto plano; modo pasivo',
    'FTPS explícito (FTP com TLS), também no canal de dados; modo passivo':
        'FTPS explícito (FTP con TLS), también en el canal de datos; modo pasivo',
    'Envio de arquivos':
        'Envío de archivos',
    'O caminho de cada arquivo':
        'La ruta de cada archivo',
    'O equipamento envia':
        'El equipo envía',
    'por FTP, com o usuário e a senha desta conta':
        'por FTP, con el usuario y la contraseña de esta cuenta',
    'O servidor recebe':
        'El servidor recibe',
    'em uma área de entrada que é só desta conta':
        'en un área de entrada que es solo de esta cuenta',
    'O arquivo é guardado':
        'El archivo se guarda',
    'na pasta do usuário, fora do alcance desta conta':
        'en la carpeta del usuario, fuera del alcance de esta cuenta',
    'Dados para enviar por FTP':
        'Datos para enviar por FTP',
    'Servidor':
        'Servidor',
    'Porta de controle':
        'Puerto de control',
    'Portas passivas':
        'Puertos pasivos',
    'Protocolo':
        'Protocolo',
    'Usuário e senha':
        'Usuario y contraseña',
    '<strong>{usuario}</strong>, com a mesma senha desta entrada':
        '<strong>{usuario}</strong>, con la misma contraseña de esta entrada',
    'O que esta conta faz':
        'Qué hace esta cuenta',
    'Depois de enviar, a pasta da sessão volta a ficar vazia: é o esperado. Arquivo enviado com um '
    'nome que já existe não substitui o anterior: o novo é guardado com a data e a hora no nome. Quem '
    'precisa conferir ou baixar o que foi enviado pede a um administrador ou usa uma conta de outro '
    'perfil.':
        'Después de enviar, la carpeta de la sesión vuelve a quedar vacía: es lo esperado. Un archivo '
        'enviado con un nombre que ya existe no sustituye al anterior: el nuevo se guarda con la fecha y la '
        'hora en el nombre. Quien necesita revisar o descargar lo enviado se lo pide a un administrador o '
        'usa una cuenta de otro perfil.',
    'O que esta conta pode fazer':
        'Qué puede hacer esta cuenta',
    'Esta conta só envia: o que chega fica guardado no servidor.':
        'Esta cuenta solo envía: lo que llega queda guardado en el servidor.',
    'FTPS explícito (FTP com TLS), modo passivo':
        'FTPS explícito (FTP con TLS), modo pasivo',
    '<strong>IP público</strong>: alcançável pela internet se o firewall não barrar':
        '<strong>IP pública</strong>: alcanzable desde internet si el firewall no lo impide',
    '<strong>desligado</strong>: senhas e arquivos trafegam em texto puro. Só para equipamento sem '
    'suporte a TLS, em rede interna isolada.':
        '<strong>desactivado</strong>: las contraseñas y los archivos viajan en texto plano. Solo para '
        'equipos sin soporte de TLS, en red interna aislada.',
    'opcional: aceita login sem criptografia. Use só com equipamento legado.':
        'opcional: acepta inicio de sesión sin cifrado. Úselo solo con equipos antiguos.',
    'obrigatório no login; os dados seguem o que o cliente pedir.':
        'obligatorio en el inicio de sesión; los datos siguen lo que pida el cliente.',
    'obrigatório no login e nos dados.':
        'obligatorio en el inicio de sesión y en los datos.',
    'modo desconhecido':
        'modo desconocido',
    'IP privado, só o próprio host alcança':
        'IP privada, solo el propio host la alcanza',
    'IP privado, alcançável pela rede interna deste endereço':
        'IP privada, alcanzable por la red interna de esta dirección',
    'O aviso do menu, do rodapé e do começo desta aba está oculto '
    '(<code>PAINEL_AVISO_EXPOSICAO=nao</code>).':
        'El aviso del menú, del pie de página y del comienzo de esta pestaña está oculto '
        '(<code>PAINEL_AVISO_EXPOSICAO=nao</code>).',
    'Endereço público':
        'Dirección pública',
    'Painel por proxy ou túnel':
        'Panel por proxy o túnel',
    'Endereço do FTP':
        'Dirección del FTP',
    'Endereço do FTP em IPv6':
        'Dirección del FTP en IPv6',
    'IP anunciado no modo passivo':
        'IP anunciada en el modo pasivo',
    'TLS do FTP':
        'TLS del FTP',
    'Certificado do FTP':
        'Certificado del FTP',
    'Endereço do painel':
        'Dirección del panel',
    'Endereço do painel em IPv6':
        'Dirección del panel en IPv6',
    'Frente web':
        'Frente web',
    'O navegador fala com o nginx, a única porta publicada do painel: ele fecha o HTTPS, limita redes '
    'e taxa de pedidos e repassa por soquete Unix. O painel não escuta em porta de rede.':
        'El navegador habla con nginx, el único puerto publicado del panel: cierra el HTTPS, limita redes y '
        'tasa de solicitudes y reenvía por socket Unix. El panel no escucha en puerto de red.',
    'Certificado do painel':
        'Certificado del panel',
    'Quem pode abrir o painel':
        'Quién puede abrir el panel',
    'Sessão':
        'Sesión',
    'Encerra com {prazo} sem uso e, de qualquer forma, em {teto}. Apagar, trocar nome de arquivo ou pasta e '
    'mexer em administrador pedem a senha de novo, mesmo com a sessão aberta. {falhas} entradas erradas '
    'bloqueiam o endereço por 15 minutos.':
        'Se cierra con {prazo} sin uso y, de todos modos, en {teto}. Borrar, cambiar el nombre de un archivo '
        'o carpeta y tocar un administrador piden la contraseña de nuevo, incluso con la sesión abierta. '
        '{falhas} entradas incorrectas bloquean la dirección por 15 minutos.',
    'Entrada dos usuários do FTP':
        'Entrada de los usuarios del FTP',
    'Bloqueio por tentativa no FTP':
        'Bloqueo por intento en el FTP',
    'Bloqueio por endereço':
        'Bloqueo por dirección',
    'Custo das senhas do FTP':
        'Costo de las contraseñas del FTP',
    'Contato de segurança':
        'Contacto de seguridad',
    'Container do painel':
        'Contenedor del panel',
    'Firewall do host':
        'Firewall del host',
    'Segurança':
        'Seguridad',
    '<strong>Exceção por usuário ligada</strong> (<code>FTP_TLS_EXCECOES=sim</code>): {quantos} '
    'usuário(s) entram sem TLS, com senha e arquivos em texto puro: {nomes}. Quem tenta entrar sem TLS '
    'sem estar dispensado é recusado, mas a senha já passou em texto puro: o log do FTP registra a '
    'tentativa.':
        '<strong>Excepción por usuario activada</strong> (<code>FTP_TLS_EXCECOES=sim</code>): {quantos} '
        'usuario(s) entran sin TLS, con contraseña y archivos en texto plano: {nomes}. Quien intenta entrar '
        'sin TLS sin estar dispensado es rechazado, pero la contraseña ya pasó en texto plano: el log del '
        'FTP registra el intento.',
    'Exceção por usuário ligada (<code>FTP_TLS_EXCECOES=sim</code>), sem nenhum usuário dispensado: '
    'todos entram com TLS, e a sessão sem TLS é recusada antes de a senha ser enviada. A dispensa de '
    'um equipamento sem suporte a TLS é feita em <a href="/usuarios">Usuários</a>.':
        'Excepción por usuario activada (<code>FTP_TLS_EXCECOES=sim</code>), sin ningún usuario dispensado: '
        'todos entran con TLS, y la sesión sin TLS se rechaza antes de que se envíe la contraseña. La '
        'dispensa de un equipo sin soporte de TLS se hace en <a href="/usuarios">Usuarios</a>.',
    'Sem exceção por usuário: {motivo}.':
        'Sin excepción por usuario: {motivo}.',
    'Recusado por código (<code>REDE_PERMITIR_IP_PUBLICO=nao</code>): FTP e painel só escutam em IP '
    'privado. Aceitar é opção de quem instala.':
        'Rechazada por código (<code>REDE_PERMITIR_IP_PUBLICO=nao</code>): el FTP y el panel solo escuchan '
        'en IP privada. Aceptarla es opción de quien instala.',
    'Não usado (<code>PAINEL_PROXY_CONFIAVEL</code> vazio): o endereço do cliente é sempre o da '
    'conexão, e <code>X-Forwarded-For</code> é ignorado. Publicar só o painel por proxy ou túnel é '
    'opção de quem instala.':
        'No usado (<code>PAINEL_PROXY_CONFIAVEL</code> vacío): la dirección del cliente es siempre la de la '
        'conexión, y <code>X-Forwarded-For</code> se ignora. Publicar solo el panel por proxy o túnel es '
        'opción de quien instala.',
    'Clientes de <code>{redes}</code>; os demais são recusados pelo nginx, antes de chegar ao painel.':
        'Clientes de <code>{redes}</code>; los demás son rechazados por nginx, antes de llegar al panel.',
    'Desligada (<code>PAINEL_ACESSO_USUARIOS_FTP=nao</code>): só administrador entra no painel.':
        'Desactivada (<code>PAINEL_ACESSO_USUARIOS_FTP=nao</code>): solo el administrador entra en el panel.',
    '<strong>{quantos} usuário(s) com a senha gravada com o custo anterior</strong>: {nomes}. Cada '
    'tentativa de entrada com esses nomes ocupa mais o processador do FTP. O custo atual passa a valer '
    'quando a senha é trocada, na aba Usuários.':
        '<strong>{quantos} usuario(s) con la contraseña guardada con el costo anterior</strong>: {nomes}. '
        'Cada intento de entrada con esos nombres ocupa más el procesador del FTP. El costo actual pasa a '
        'valer cuando se cambia la contraseña, en la pestaña Usuarios.',
    'Todas as senhas estão gravadas com o custo do porte atual (<code>FTP_MAX_CLIENTS</code>).':
        'Todas las contraseñas están guardadas con el costo del dimensionamiento actual '
        '(<code>FTP_MAX_CLIENTS</code>).',
    'Publicado em <code>/.well-known/security.txt</code>: quem achar uma falha nesta instalação '
    'escreve para <code>{contato}</code>.':
        'Publicado en <code>/.well-known/security.txt</code>: quien encuentre un fallo en esta instalación '
        'escribe a <code>{contato}</code>.',
    'O painel não enxerga o firewall. Confira você: as portas do FTP e do painel devem estar liberadas '
    'só para os endereços que precisam, na cadeia <code>DOCKER-USER</code>':
        'El panel no ve el firewall. Revíselo usted: los puertos del FTP y del panel deben estar abiertos '
        'solo para las direcciones que los necesitan, en la cadena <code>DOCKER-USER</code>',
    '<strong>Aceito</strong> (<code>REDE_PERMITIR_IP_PUBLICO=sim</code>): a proteção contra a internet '
    'passa a ser o firewall do servidor, o TLS obrigatório e as senhas geradas.':
        '<strong>Aceptada</strong> (<code>REDE_PERMITIR_IP_PUBLICO=sim</code>): la protección contra '
        'internet pasa a ser el firewall del servidor, el TLS obligatorio y las contraseñas generadas.',
    '<strong>Em uso</strong> (<code>PAINEL_PROXY_CONFIAVEL={proxies}</code>): o endereço de quem '
    'acessa é o que o proxy informa em <code>X-Forwarded-For</code>, e é ele que conta as senhas '
    'erradas, prende a sessão e vai para a auditoria. Quem pode chegar à tela de entrada é decidido no '
    'proxy ou no túnel. O FTP não passa por ele.':
        '<strong>En uso</strong> (<code>PAINEL_PROXY_CONFIAVEL={proxies}</code>): la dirección de quien '
        'accede es la que el proxy informa en <code>X-Forwarded-For</code>, y es ella la que cuenta las '
        'contraseñas incorrectas, ata la sesión y va a la auditoría. Quién puede llegar a la pantalla de '
        'entrada se decide en el proxy o en el túnel. El FTP no pasa por él.',
    'IP privado.':
        'IP privada.',
    '<strong>IP público</strong>.':
        '<strong>IP pública</strong>.',
    'Modo':
        'Modo',
    'só HTTPS':
        'solo HTTPS',
    '<strong>Bloqueado agora: {nomes}.</strong>':
        '<strong>Bloqueado ahora: {nomes}.</strong>',
    'Nenhum usuário bloqueado agora.':
        'Ningún usuario bloqueado ahora.',
    'Nenhum endereço bloqueado agora.':
        'Ninguna dirección bloqueada ahora.',
    'Não publicado (<code>SEGURANCA_CONTATO_EMAIL</code> vazio): quem achar uma falha nesta instalação '
    'não tem para onde escrever.':
        'No publicado (<code>SEGURANCA_CONTATO_EMAIL</code> vacío): quien encuentre un fallo en esta '
        'instalación no tiene adónde escribir.',
    'Raiz somente leitura':
        'Raíz de solo lectura',
    'Raiz gravável: confira o <code>read_only</code>':
        'Raíz escribible: revise el <code>read_only</code>',
    'Resumo da conferência':
        'Resumen de la verificación',
    '{quantos} itens conferidos':
        '{quantos} elementos verificados',
    '<strong>Rede pública na lista: {redes}.</strong>':
        '<strong>Red pública en la lista: {redes}.</strong>',
    'Ligada (<code>PAINEL_ACESSO_USUARIOS_FTP=sim</code>): cada usuário do FTP entra com o nome e a '
    'senha do FTP e só navega e baixa na pasta dele. Quem confere a senha é o próprio servidor FTP, '
    'pela rede interna da stack,':
        'Activada (<code>PAINEL_ACESSO_USUARIOS_FTP=sim</code>): cada usuario del FTP entra con el nombre y '
        'la contraseña del FTP y solo navega y descarga en su carpeta. Quien comprueba la contraseña es el '
        'propio servidor FTP, por la red interna de la stack,',
    '<strong>em texto puro</strong>, porque o FTP está sem TLS.':
        '<strong>en texto plano</strong>, porque el FTP está sin TLS.',
    'em TLS e com o certificado dele conferido.':
        'en TLS y con su certificado verificado.',
    'O limite próprio de cada usuário fica em Editar, na aba Usuários.':
        'El límite propio de cada usuario está en Editar, en la pestaña Usuarios.',
    'O endereço que passa de {erros} de usuário e senha em {horas}, no FTP ou no painel, fica {dias} '
    'sem entrar nos dois (<code>BLOQUEIO_ENDERECO_ERROS</code>, <code>BLOQUEIO_ENDERECO_HORAS</code> e '
    '<code>BLOQUEIO_ENDERECO_DIAS</code>).':
        'La dirección que pasa de {erros} de usuario y contraseña en {horas}, en el FTP o en el panel, queda '
        '{dias} sin entrar en los dos (<code>BLOQUEIO_ENDERECO_ERROS</code>, '
        '<code>BLOQUEIO_ENDERECO_HORAS</code> y <code>BLOQUEIO_ENDERECO_DIAS</code>).',
    '<strong>Desligado na stack</strong> (<code>BLOQUEIO_ENDERECO_ERROS=0</code>): nenhum endereço é '
    'bloqueado sozinho.':
        '<strong>Desactivado en la stack</strong> (<code>BLOQUEIO_ENDERECO_ERROS=0</code>): ninguna '
        'dirección se bloquea sola.',
    'e sem acesso ao Docker do host.':
        'y sin acceso al Docker del host.',
    '<strong>Há um socket do Docker montado: remova.</strong>':
        '<strong>Hay un socket de Docker montado: quítelo.</strong>',
    '<strong>Com endereço público aceito, é o firewall que separa a stack da internet.</strong>':
        '<strong>Con dirección pública aceptada, es el firewall el que separa la stack de internet.</strong>',
    'e nenhuma delas pode ser redirecionada da internet.':
        'y ninguno de ellos puede redirigirse desde internet.',
    'O que protege o servidor nesta instalação, conferido agora.':
        'Lo que protege al servidor en esta instalación, verificado ahora.',
    '{n} endereço bloqueado agora':
        '{n} dirección bloqueada ahora',
    '{n} endereços bloqueados agora':
        '{n} direcciones bloqueadas ahora',
    '<strong>Com endereço público aceito, preencha.</strong>':
        '<strong>Con dirección pública aceptada, complételo.</strong>',
    '{tentativas} senhas erradas do mesmo endereço bloqueiam o usuário para aquele endereço por '
    '{minutos} minutos (<code>FTP_BLOQUEIO_TENTATIVAS</code> e <code>FTP_BLOQUEIO_MINUTOS</code>).':
        '{tentativas} contraseñas incorrectas desde la misma dirección bloquean al usuario para esa '
        'dirección por {minutos} minutos (<code>FTP_BLOQUEIO_TENTATIVAS</code> y <code>FTP_BLOQUEIO_MINUTOS</code>).',
    '<strong>Desligado na stack</strong> (<code>FTP_BLOQUEIO_TENTATIVAS=0</code>): só é bloqueado o '
    'usuário que tem limite próprio.':
        '<strong>Desactivado en la stack</strong> (<code>FTP_BLOQUEIO_TENTATIVAS=0</code>): solo se bloquea '
        'al usuario que tiene límite propio.',
    'em ordem':
        'en orden',
    'pedem atenção':
        'piden atención',
    'com problema':
        'con problema',
    'que o painel não confere ou não se aplicam':
        'que el panel no verifica o que no se aplican',
    '{parte} de {todo}':
        '{parte} de {todo}',
    'Cada container lê o próprio uso e os limites que recebeu no <code>compose.yaml</code> '
    '(<code>*_CPU_LIMIT</code>, <code>*_MEMORY_LIMIT</code> e <code>*_PIDS_LIMIT</code> no '
    '<code>.env</code>), sem swap; a memória em uso não conta o cache de arquivo que o sistema solta '
    'quando precisa. O histórico guarda os últimos {periodo}, com uma leitura a cada {intervalo} s, e '
    'recomeça quando o painel reinicia; cada desenho vai de zero até pouco acima do pico do período. '
    '<strong>Limite de processador atingido</strong> é a parte desse período em que a cota do '
    'container acabou: ele usa a cota inteira por um instante quando sobe e em cada pedido mais pesado, '
    'e só falta processador quando essa parte é grande e não baixa. '
    'Na rede, a linha cheia é o que chega e a tracejada, o que sai, e os totais contam desde que o '
    'serviço do FTP iniciou; o disco é o da pasta dos dados.':
        'Cada contenedor lee su propio uso y los límites que recibió en el <code>compose.yaml</code> '
        '(<code>*_CPU_LIMIT</code>, <code>*_MEMORY_LIMIT</code> y <code>*_PIDS_LIMIT</code> en el '
        '<code>.env</code>), sin swap; la memoria en uso no cuenta la caché de archivos que el sistema '
        'libera cuando la necesita. El historial guarda los últimos {periodo}, con una lectura cada '
        '{intervalo} s, y vuelve a empezar cuando el panel se reinicia; cada dibujo va de cero hasta poco '
        'por encima del pico del período. <strong>Límite de procesador alcanzado</strong> es la parte de ese '
        'período en la que la cuota del contenedor se agotó: usa la cuota entera por un instante cuando '
        'arranca y en cada solicitud más pesada, y solo falta procesador cuando esa parte es grande y no '
        'baja. En la red, la línea continua es lo que llega y la discontinua, lo que sale, y los totales '
        'cuentan desde que el servicio del FTP se inició; el disco es el de la carpeta de los datos.',
    'menos de 1% do tempo':
        'menos del 1% del tiempo',
    '{parte}% do tempo':
        '{parte}% del tiempo',
    'nunca':
        'nunca',
    'Servidor FTP':
        'Servidor FTP',
    'Painel':
        'Panel',
    'do servidor (sem limite)':
        'del servidor (sin límite)',
    'Memória':
        'Memoria',
    '{parte} de {todo} em uso':
        '{parte} de {todo} en uso',
    'Processador':
        'Procesador',
    'o servidor não tem':
        'el servidor no tiene',
    'Disco':
        'Disco',
    'Rede do FTP':
        'Red del FTP',
    'recebendo e enviando agora':
        'recibiendo y enviando ahora',
    'A tela se atualiza a cada {segundos} s. A atualização automática não conta como uso do painel: a '
    'sessão encerra depois de {prazo} sem ação sua.':
        'La pantalla se actualiza cada {segundos} s. La actualización automática no cuenta como uso del '
        'panel: la sesión se cierra después de {prazo} sin acción suya.',
    'Para acompanhar sem recarregar a página, ligue <strong>Atualizar sozinha</strong>.':
        'Para seguirla sin recargar la página, active <strong>Actualizar sola</strong>.',
    'últimos {tempo}':
        'últimos {tempo}',
    'Fora do ar':
        'Fuera de servicio',
    'Processos':
        'Procesos',
    'processador, pico de {pico}%':
        'procesador, pico de {pico}%',
    'Alocado aos {quantos} containers: <strong>{nucleos}</strong> e <strong>{memoria}</strong> de '
    'memória':
        'Asignado a los {quantos} contenedores: <strong>{nucleos}</strong> y <strong>{memoria}</strong> de memoria',
    'em uso agora: <strong>{nucleos}</strong> e <strong>{memoria}</strong>':
        'en uso ahora: <strong>{nucleos}</strong> y <strong>{memoria}</strong>',
    'em uso agora: <strong>{memoria}</strong>':
        'en uso ahora: <strong>{memoria}</strong>',
    'o servidor tem {nucleos} e {memoria}':
        'el servidor tiene {nucleos} y {memoria}',
    'nenhum':
        'ninguno',
    'desligado na stack':
        'desactivado en la stack',
    'Containers da stack':
        'Contenedores de la stack',
    'O painel não conseguiu ler o uso do processador neste servidor.':
        'El panel no pudo leer el uso del procesador en este servidor.',
    'O painel não conseguiu ler a memória deste servidor.':
        'El panel no pudo leer la memoria de este servidor.',
    '(soma incompleta: há pasta grande demais para ser lida inteira)':
        '(suma incompleta: hay una carpeta demasiado grande para leerse entera)',
    'O serviço do FTP ainda não publicou a leitura da rede dele. Ela aparece alguns segundos depois de '
    'ele iniciar.':
        'El servicio del FTP todavía no publicó la lectura de su red. Aparece unos segundos después de que se inicia.',
    'lendo':
        'leyendo',
    'topo em {velocidade}':
        'tope en {velocidade}',
    'Processador do servidor':
        'Procesador del servidor',
    'Memória do servidor':
        'Memoria del servidor',
    'sem leitura':
        'sin lectura',
    'Processador dos containers':
        'Procesador de los contenedores',
    'Memória dos containers':
        'Memoria de los contenedores',
    'Servidor e containers':
        'Servidor y contenedores',
    'ver o servidor':
        'ver el servidor',
    'núcleos':
        'núcleos',
    'núcleo':
        'núcleo',
    'O histórico aparece alguns segundos depois de o painel iniciar.':
        'El historial aparece unos segundos después de que el panel se inicia.',
    'No ar':
        'En servicio',
    'sem leitura: ela aparece alguns segundos depois de o container iniciar':
        'sin lectura: aparece unos segundos después de que el contenedor se inicia',
    '{quantos} em vigor':
        '{quantos} en vigor',
    'pico de {pico}%':
        'pico de {pico}%',
    'Média de 1 min':
        'Media de 1 min',
    'Carga média':
        'Carga media',
    'Ligado há':
        'Encendido hace',
    'Modelo':
        'Modelo',
    'Disponível':
        'Disponible',
    'Em cache':
        'En caché',
    'O painel não conseguiu ler o disco da pasta dos dados.':
        'El panel no pudo leer el disco de la carpeta de los datos.',
    'Livre':
        'Libre',
    'Pico recebendo':
        'Pico recibiendo',
    'Pico enviando':
        'Pico enviando',
    'Total recebido':
        'Total recibido',
    'Total enviado':
        'Total enviado',
    'Erros e descartes':
        'Errores y descartes',
    'Sem tráfego há':
        'Sin tráfico hace',
    'Parar a atualização':
        'Detener la actualización',
    'Atualizar sozinha':
        'Actualizar sola',
    'vez':
        'vez',
    'vezes':
        'veces',
    'Memória no limite':
        'Memoria en el límite',
    'de {todo}':
        'de {todo}',
    'sem limite':
        'sin límite',
    'no ar há {tempo}':
        'en servicio hace {tempo}',
    'Bloqueios de entrada':
        'Bloqueos de entrada',
    'a primeira leitura sai em alguns segundos':
        'la primera lectura sale en unos segundos',
    'Outros dados':
        'Otros datos',
    'Recursos do servidor':
        'Recursos del servidor',
    'A máquina inteira, e não só o que a stack usa dela.':
        'La máquina entera, y no solo lo que la stack usa de ella.',
    'Lido às {hora}.':
        'Leído a las {hora}.',
    'Atenção':
        'Atención',
    'Pastas do FTP':
        'Carpetas del FTP',
    'Os containers desta stack e o servidor em que ela roda.':
        'Los contenedores de esta stack y el servidor en el que se ejecuta.',
    'Como estas medidas são lidas':
        'Cómo se leen estas medidas',
    'Limite de processador atingido':
        'Límite de procesador alcanzado',
    'Encerrado por falta de memória':
        'Terminado por falta de memoria',
    'Sessões de administrador':
        'Sesiones de administrador',
    'Certificado':
        'Certificado',
    'A senha e os arquivos deste usuário passam a trafegar em texto puro e podem ser lidos por quem '
    'estiver na mesma rede. Use só para equipamento antigo sem suporte a TLS, em rede interna isolada, '
    'com o firewall liberando só esse equipamento. Os outros usuários continuam obrigados a usar TLS.':
        'La contraseña y los archivos de este usuario pasan a viajar en texto plano y pueden ser leídos por '
        'quien esté en la misma red. Úselo solo para equipos antiguos sin soporte de TLS, en red interna '
        'aislada, con el firewall permitiendo solo ese equipo. Los demás usuarios siguen obligados a usar TLS.',
    'Usuário criado.':
        'Usuario creado.',
    'Usuário criado e dispensado do TLS: a senha e os arquivos dele passam em texto puro.':
        'Usuario creado y dispensado del TLS: su contraseña y sus archivos pasan en texto plano.',
    'Usuário criado, mas a dispensa do TLS não foi gravada: ele só entra com TLS. Tente de novo em '
    'Editar.':
        'Usuario creado, pero la dispensa del TLS no se guardó: solo entra con TLS. Inténtelo de nuevo en Editar.',
    'Senha trocada.':
        'Contraseña cambiada.',
    'Pasta trocada. Os arquivos da pasta anterior continuam nela.':
        'Carpeta cambiada. Los archivos de la carpeta anterior siguen en ella.',
    'Perfil trocado. Vale na próxima entrada do usuário no FTP.':
        'Perfil cambiado. Vale en la próxima entrada del usuario en el FTP.',
    'Limites gravados. Valem na próxima entrada do usuário no FTP.':
        'Límites guardados. Valen en la próxima entrada del usuario en el FTP.',
    'Bloqueio removido. O usuário volta a poder entrar no FTP.':
        'Bloqueo eliminado. El usuario vuelve a poder entrar en el FTP.',
    'Usuário removido. Os arquivos continuam na pasta.':
        'Usuario eliminado. Los archivos siguen en la carpeta.',
    'Usuário removido e pasta apagada.':
        'Usuario eliminado y carpeta borrada.',
    'Usuário dispensado do TLS: a senha e os arquivos dele passam em texto puro.':
        'Usuario dispensado del TLS: su contraseña y sus archivos pasan en texto plano.',
    'O usuário volta a ser obrigado a usar TLS.':
        'El usuario vuelve a estar obligado a usar TLS.',
    'Administrador criado.':
        'Administrador creado.',
    'Senha trocada. As outras sessões desse administrador foram encerradas.':
        'Contraseña cambiada. Las demás sesiones de ese administrador se cerraron.',
    'Nome trocado. As outras sessões desse administrador foram encerradas.':
        'Nombre cambiado. Las demás sesiones de ese administrador se cerraron.',
    'Administrador removido. As sessões dele foram encerradas.':
        'Administrador eliminado. Sus sesiones se cerraron.',
    'Pasta <span class="suave">(deixe em branco para usar o nome do usuário)</span>':
        'Carpeta <span class="suave">(deje en blanco para usar el nombre del usuario)</span>',
    'Usuário não encontrado':
        'Usuario no encontrado',
    'Dispensar um usuário do TLS não está disponível nesta instalação: {motivo}. Quem muda isso é quem '
    'administra o servidor, no <code>.env</code>, com <code>./deploy.sh</code> em seguida.':
        'Dispensar a un usuario del TLS no está disponible en esta instalación: {motivo}. Quien cambia esto '
        'es quien administra el servidor, en el <code>.env</code>, con <code>./deploy.sh</code> a continuación.',
    'Administrador':
        'Administrador',
    'entra no painel e administra tudo; não é conta do FTP':
        'entra en el panel y lo administra todo; no es cuenta del FTP',
    'Completo':
        'Completo',
    'envia, baixa, renomeia e apaga':
        'envía, descarga, renombra y borra',
    'Envio':
        'Envío',
    'envia e baixa; não apaga nem altera o que já enviou':
        'envía y descarga; no borra ni altera lo que ya envió',
    'Só envio':
        'Solo envío',
    'só envia; não lista nem baixa nada, nem o que ela mesma enviou':
        'solo envía; no lista ni descarga nada, ni lo que ella misma envió',
    'Leitura':
        'Lectura',
    'só lista e baixa':
        'solo lista y descarga',
    'Pasta inválida. Veja a regra abaixo do campo.':
        'Carpeta no válida. Vea la regla debajo del campo.',
    'vazio: {padrao}, o padrão da stack':
        'vacío: {padrao}, el valor predeterminado de la stack',
    'vazio: o padrão da stack, que está desligado':
        'vacío: el valor predeterminado de la stack, que está desactivado',
    'na pasta dele':
        'en su carpeta',
    'TLS por usuário sem efeito':
        'TLS por usuario sin efecto',
    'Senhas erradas demais no FTP, vindas de: {origens}':
        'Demasiadas contraseñas incorrectas en el FTP, provenientes de: {origens}',
    'Usuários':
        'Usuarios',
    'Senha':
        'Contraseña',
    '(deixe em branco para o painel gerar uma senha forte)':
        '(deje en blanco para que el panel genere una contraseña fuerte)',
    'Repita a senha':
        'Repita la contraseña',
    'Mínimo de {minimo} caracteres. A senha gerada aparece uma única vez, na tela seguinte.':
        'Mínimo de {minimo} caracteres. La contraseña generada aparece una única vez, en la pantalla siguiente.',
    'As duas senhas não são iguais.':
        'Las dos contraseñas no son iguales.',
    'A senha deve ter de {minimo} a {maximo} caracteres.':
        'La contraseña debe tener de {minimo} a {maximo} caracteres.',
    'A senha não pode ter caractere de controle.':
        'La contraseña no puede tener caracteres de control.',
    'Fica dentro de <code>{pasta}</code> e é criada se não existir. Até 4 níveis separados por '
    '<code>/</code>; letras, números, <code>_</code>, <code>-</code> e ponto; nenhum nível começa com '
    'ponto.':
        'Queda dentro de <code>{pasta}</code> y se crea si no existe. Hasta 4 niveles separados por '
        '<code>/</code>; letras, números, <code>_</code>, <code>-</code> y punto; ningún nivel empieza con punto.',
    'Usuários com a mesma pasta, ou com uma dentro da outra, alcançam os arquivos um do outro, cada um '
    'até onde o perfil dele deixa. Para um equipamento não alcançar o backup de outro, dê a cada um a '
    'própria pasta.':
        'Los usuarios con la misma carpeta, o con una dentro de la otra, alcanzan los archivos unos de '
        'otros, cada uno hasta donde su perfil lo permite. Para que un equipo no alcance la copia de '
        'seguridad de otro, dé a cada uno su propia carpeta.',
    'Equipamento sem suporte a TLS: deixar este usuário entrar <strong>sem TLS</strong>':
        'Equipo sin soporte de TLS: dejar que este usuario entre <strong>sin TLS</strong>',
    'Sem marcar a caixa, o usuário só entra com TLS (FTPS explícito).':
        'Sin marcar la casilla, el usuario solo entra con TLS (FTPS explícito).',
    'Novo usuário':
        'Nuevo usuario',
    'Limites':
        'Límites',
    'Campo vazio quer dizer <strong>sem limite próprio</strong>: vale o da stack.':
        'Campo vacío quiere decir <strong>sin límite propio</strong>: vale el de la stack.',
    'Horário em que o FTP aceita a entrada: das':
        'Horario en que el FTP acepta la entrada: desde las',
    'até as':
        'hasta las',
    'Os limites valem na próxima entrada do usuário no FTP. Quando um limite do FTP muda, a sessão '
    'dele no painel é encerrada. Quem confere a senha do painel é o FTP: fora do horário, ou com todas '
    'as sessões dele ocupadas, o usuário também não entra no painel.':
        'Los límites valen en la próxima entrada del usuario en el FTP. Cuando cambia un límite del FTP, su '
        'sesión en el panel se cierra. Quien comprueba la contraseña del panel es el FTP: fuera del horario, '
        'o con todas sus sesiones ocupadas, el usuario tampoco entra en el panel.',
    'O bloqueio vale só para este usuário e só para o endereço que errou a senha: os outros endereços '
    'e a entrada dele pelo painel continuam valendo. Entrada certa zera a contagem. Entrada fora do '
    'horário conta como senha errada. Equipamentos que chegam ao FTP pelo mesmo endereço são '
    'bloqueados juntos. Mudar um destes dois campos tira os bloqueios do usuário.':
        'El bloqueo vale solo para este usuario y solo para la dirección que falló la contraseña: las demás '
        'direcciones y su entrada por el panel siguen valiendo. Una entrada correcta pone el conteo a cero. '
        'Una entrada fuera del horario cuenta como contraseña incorrecta. Los equipos que llegan al FTP por '
        'la misma dirección se bloquean juntos. Cambiar uno de estos dos campos quita los bloqueos del usuario.',
    'Gravar limites':
        'Guardar límites',
    'Nenhum bloqueio em vigor.':
        'Ningún bloqueo en vigor.',
    'O FTP está recusando este usuário quando ele chega dos endereços abaixo, por senhas erradas '
    'demais. Com a senha certa ele também é recusado, até o fim do prazo.':
        'El FTP está rechazando a este usuario cuando llega desde las direcciones de abajo, por demasiadas '
        'contraseñas incorrectas. Con la contraseña correcta también es rechazado, hasta el fin del plazo.',
    'Perfil':
        'Perfil',
    'O perfil vale no FTP e na entrada do usuário pelo painel. A troca vale no próximo login no FTP e '
    'encerra a sessão dele no painel; sessão de FTP que já está aberta segue com o perfil anterior até '
    'sair.':
        'El perfil vale en el FTP y en la entrada del usuario por el panel. El cambio vale en el próximo '
        'inicio de sesión en el FTP y cierra su sesión en el panel; la sesión de FTP que ya está abierta '
        'sigue con el perfil anterior hasta salir.',
    'No perfil Envio, o arquivo passa a ser do servidor assim que termina de chegar: daí em diante o '
    'usuário não o apaga, não o renomeia e não grava por cima. Equipamento que envia sempre com o '
    'mesmo nome de arquivo precisa do perfil Completo.':
        'En el perfil Envío, el archivo pasa a ser del servidor en cuanto termina de llegar: de ahí en '
        'adelante el usuario no lo borra, no lo renombra y no escribe encima. Un equipo que envía siempre '
        'con el mismo nombre de archivo necesita el perfil Completo.',
    'No perfil Só envio, a conta entra em uma área de entrada vazia e cada arquivo que chega é movido '
    'para a pasta do usuário: ela não lista nem baixa o que está lá. Nome repetido não substitui o '
    'anterior: o novo é guardado com a data e a hora no nome. Equipamento que envia com um nome '
    'provisório e renomeia no fim, ou que confere o envio listando a pasta, precisa de outro perfil.':
        'En el perfil Solo envío, la cuenta entra en un área de entrada vacía y cada archivo que llega se '
        'mueve a la carpeta del usuario: no lista ni descarga lo que hay allí. Un nombre repetido no '
        'sustituye al anterior: el nuevo se guarda con la fecha y la hora en el nombre. Un equipo que envía '
        'con un nombre provisional y lo renombra al final, o que comprueba el envío listando la carpeta, '
        'necesita otro perfil.',
    'Gravar perfil':
        'Guardar perfil',
    'Este usuário só entra com <strong>TLS</strong> (FTPS explícito).':
        'Este usuario solo entra con <strong>TLS</strong> (FTPS explícito).',
    'Dispensar TLS':
        'Dispensar del TLS',
    'Para equipamento antigo sem suporte a TLS, em rede interna isolada. A tela seguinte pede a '
    'confirmação.':
        'Para equipos antiguos sin soporte de TLS, en red interna aislada. La pantalla siguiente pide la '
        'confirmación.',
    'Também alcançada por: <strong>{outros}</strong>.':
        'También alcanzada por: <strong>{outros}</strong>.',
    'Editar usuário':
        'Editar usuario',
    'Remover usuário':
        'Eliminar usuario',
    'Exigir TLS':
        'Exigir TLS',
    'Sim, voltar a exigir o TLS':
        'Sí, volver a exigir el TLS',
    'Sim, deixar este usuário entrar sem TLS':
        'Sí, dejar que este usuario entre sin TLS',
    'Também alcançada por: {outros}':
        'También alcanzada por: {outros}',
    'Editar':
        'Editar',
    'Remover':
        'Eliminar',
    'Nenhum usuário ainda.':
        'Ningún usuario todavía.',
    'Dispensado do TLS pelo administrador, em Editar ou ao criar: a senha e os arquivos desse usuário '
    'trafegam em texto puro.':
        'Dispensado del TLS por el administrador, en Editar o al crear: la contraseña y los archivos de ese '
        'usuario viajan en texto plano.',
    'Perfil inválido.':
        'Perfil no válido.',
    'Já existe um usuário com este nome.':
        'Ya existe un usuario con este nombre.',
    'Sessões ao mesmo tempo no FTP':
        'Sesiones al mismo tiempo en el FTP',
    'conexões abertas com este usuário':
        'conexiones abiertas con este usuario',
    'Taxa de download, em KB por segundo':
        'Tasa de descarga, en KB por segundo',
    'no FTP e nos downloads dele pelo painel':
        'en el FTP y en sus descargas por el panel',
    'Taxa de envio, em KB por segundo':
        'Tasa de envío, en KB por segundo',
    'Downloads ao mesmo tempo pelo painel':
        'Descargas al mismo tiempo por el panel',
    'vazio: {padrao}':
        'vacío: {padrao}',
    'Senhas erradas no FTP até o bloqueio':
        'Contraseñas incorrectas en el FTP hasta el bloqueo',
    '{padrao}; 0: este usuário nunca é bloqueado':
        '{padrao}; 0: este usuario nunca se bloquea',
    'Minutos de bloqueio':
        'Minutos de bloqueo',
    'vazio: {padrao}, o padrão da stack; é também o tempo em que as senhas erradas se somam':
        'vacío: {padrao}, el valor predeterminado de la stack; es también el tiempo en que las contraseñas '
        'incorrectas se suman',
    'Este usuário segue o <code>FTP_TLS_MODE</code>, como todos os outros.':
        'Este usuario sigue el <code>FTP_TLS_MODE</code>, como todos los demás.',
    'Este usuário entra <strong>sem TLS</strong>: a senha e os arquivos dele trafegam em texto puro e '
    'podem ser lidos por quem estiver na mesma rede. Com TLS ele continua entrando normalmente.':
        'Este usuario entra <strong>sin TLS</strong>: su contraseña y sus archivos viajan en texto plano y '
        'pueden ser leídos por quien esté en la misma red. Con TLS sigue entrando normalmente.',
    'Volte a exigir assim que o equipamento tiver suporte a TLS, e troque a senha em seguida.':
        'Vuelva a exigirlo en cuanto el equipo tenga soporte de TLS, y cambie la contraseña a continuación.',
    'fora da pasta dos dados':
        'fuera de la carpeta de los datos',
    'inicial':
        'inicial',
    'Este já é o perfil do usuário.':
        'Este ya es el perfil del usuario.',
    'Este é o usuário inicial. A senha trocada aqui vale até o arquivo '
    '<code>.secrets/ftp-usuario-inicial-senha.txt</code> ser alterado: aí, na subida seguinte do '
    'serviço <code>ftp</code>, volta a valer a do arquivo.':
        'Este es el usuario inicial. La contraseña cambiada aquí vale hasta que se modifique el archivo '
        '<code>.secrets/ftp-usuario-inicial-senha.txt</code>: entonces, en el siguiente arranque del '
        'servicio <code>ftp</code>, vuelve a valer la del archivo.',
    'Esta pasta também é alcançada por: <strong>{outros}</strong>. Por isso ela não é apagada junto '
    'com o usuário: os arquivos continuam nela.':
        'Esta carpeta también es alcanzada por: <strong>{outros}</strong>. Por eso no se borra junto con el '
        'usuario: los archivos siguen en ella.',
    'Este é o usuário inicial, criado pela instalação. Removido, ele não volta nas próximas subidas do '
    'serviço <code>ftp</code>; para tê-lo de novo, crie um usuário com o mesmo nome.':
        'Este es el usuario inicial, creado por la instalación. Eliminado, no vuelve en los próximos '
        'arranques del servicio <code>ftp</code>; para tenerlo de nuevo, cree un usuario con el mismo nombre.',
    'A senha dele já trafegou em texto puro: troque-a depois de exigir o TLS.':
        'Su contraseña ya viajó en texto plano: cámbiela después de exigir el TLS.',
    'Com TLS este usuário continua entrando normalmente. Dê a ele uma pasta só dele e uma senha que '
    'não seja usada em mais nenhum lugar. A dispensa vale em instantes; as sessões em andamento no FTP '
    'não são interrompidas.':
        'Con TLS este usuario sigue entrando normalmente. Dele una carpeta solo suya y una contraseña que no '
        'se use en ningún otro lugar. La dispensa vale en instantes; las sesiones en curso en el FTP no se '
        'interrumpen.',
    'você':
        'usted',
    'Painel inteiro; {n} sessão aberta':
        'Panel entero; {n} sesión abierta',
    'Painel inteiro; {n} sessões abertas':
        'Panel entero; {n} sesiones abiertas',
    'Abrir na aba Arquivos':
        'Abrir en la pestaña Archivos',
    'Criado pela instalação, uma vez; removido, não volta sozinho':
        'Creado por la instalación, una vez; eliminado, no vuelve solo',
    'Limites próprios: {limites}':
        'Límites propios: {limites}',
    'limites':
        'límites',
    'bloqueado':
        'bloqueado',
    'Pasta':
        'Carpeta',
    'Uso':
        'Uso',
    'Último envio':
        'Último envío',
    '<strong>Administrador</strong> entra neste painel e administra tudo; não é conta do FTP. Alterar '
    'administrador pede a sua senha atual, e ninguém remove a própria conta. Até {maximo} '
    'administradores.':
        '<strong>Administrador</strong> entra en este panel y lo administra todo; no es cuenta del FTP. '
        'Modificar un administrador pide su contraseña actual, y nadie elimina su propia cuenta. Hasta '
        '{maximo} administradores.',
    '<strong>Completo</strong> envia, baixa, renomeia e apaga. <strong>Envio</strong> envia e baixa, '
    'sem apagar nem alterar o que já enviou. <strong>Só envio</strong> só envia: não lista nem baixa '
    'nada. <strong>Leitura</strong> só lista e baixa. O perfil vale no FTP e na entrada do usuário '
    'pelo painel.':
        '<strong>Completo</strong> envía, descarga, renombra y borra. <strong>Envío</strong> envía y '
        'descarga, sin borrar ni alterar lo que ya envió. <strong>Solo envío</strong> solo envía: no lista '
        'ni descarga nada. <strong>Lectura</strong> solo lista y descarga. El perfil vale en el FTP y en la '
        'entrada del usuario por el panel.',
    'Cada usuário do FTP fica preso na pasta dele, dentro de <code>{pasta}</code> no servidor. Toda '
    'alteração vale no próximo login, sem reiniciar o FTP.':
        'Cada usuario del FTP queda confinado en su carpeta, dentro de <code>{pasta}</code> en el servidor. '
        'Todo cambio vale en el próximo inicio de sesión, sin reiniciar el FTP.',
    'Usuário e perfil':
        'Usuario y perfil',
    'Usuário <strong>{nome}</strong>. Senha gerada pelo painel:':
        'Usuario <strong>{nome}</strong>. Contraseña generada por el panel:',
    'Copie agora para o equipamento ou para o seu cofre de senhas. Ela <strong>não será mostrada de '
    'novo</strong> e não fica guardada em lugar nenhum além do hash do FTP.':
        'Cópiela ahora en el equipo o en su gestor de contraseñas. <strong>No se mostrará de nuevo</strong> '
        'y no queda guardada en ningún lugar además del hash del FTP.',
    'Nome do usuário':
        'Nombre del usuario',
    'Criar usuário':
        'Crear usuario',
    'O que este usuário pode fazer':
        'Qué puede hacer este usuario',
    'Usuário <strong>{nome}</strong>{inicial}. O nome não muda: é com ele que o equipamento entra no '
    'FTP.':
        'Usuario <strong>{nome}</strong>{inicial}. El nombre no cambia: es con él que el equipo entra en el FTP.',
    'Pasta atual: {onde}, com {arquivos} arquivo(s), {tamanho}.':
        'Carpeta actual: {onde}, con {arquivos} archivo(s), {tamanho}.',
    'Os arquivos da pasta atual <strong>não são movidos nem apagados</strong>: continuam onde estão, '
    'e o usuário deixa de alcançá-los. A troca vale no próximo login no FTP e encerra a sessão dele '
    'no painel. A limpeza automática, se estiver ligada, é desligada: a regra era da pasta atual.':
        'Los archivos de la carpeta actual <strong>no se mueven ni se borran</strong>: siguen donde están, y '
        'el usuario deja de alcanzarlos. El cambio vale en el próximo inicio de sesión en el FTP y cierra su '
        'sesión en el panel. La limpieza automática, si está activada, se desactiva: la regla era de la '
        'carpeta actual.',
    'Pasta trocada. Os arquivos da pasta anterior continuam nela. A limpeza automática foi desligada: '
    'a regra era da pasta anterior.':
        'Carpeta cambiada. Los archivos de la carpeta anterior siguen en ella. La limpieza automática se '
        'desactivó: la regla era de la carpeta anterior.',
    'Limpeza automática gravada. Vale na próxima passada do painel.':
        'Limpieza automática guardada. Vale en la próxima pasada del panel.',
    'Limpeza automática desligada. Nenhum arquivo deste usuário é apagado sozinho.':
        'Limpieza automática desactivada. Ningún archivo de este usuario se borra solo.',
    'Limpeza automática':
        'Limpieza automática',
    'Limpeza automática: {regra}':
        'Limpieza automática: {regra}',
    'limpeza':
        'limpieza',
    'ligada':
        'activada',
    'Limpeza automática ligada em Editar: o painel apaga sozinho os arquivos antigos da pasta deste usuário.':
        'Limpieza automática activada en Editar: el panel borra solo los archivos antiguos de la carpeta de '
        'este usuario.',
    'Desligada: nenhum arquivo deste usuário é apagado sozinho.':
        'Desactivada: ningún archivo de este usuario se borra solo.',
    'O painel aplica a regra a cada minuto.':
        'El panel aplica la regla cada minuto.',
    'O painel aplica a regra a cada {n} minutos.':
        'El panel aplica la regla cada {n} minutos.',
    'Com <code>PAINEL_RETENCAO_MINUTOS=0</code>, a limpeza automática está parada nesta instalação: a '
    'regra fica gravada e não é aplicada.':
        'Con <code>PAINEL_RETENCAO_MINUTOS=0</code>, la limpieza automática está detenida en esta '
        'instalación: la regla queda guardada y no se aplica.',
    'A pasta deste usuário também é alcançada por <strong>{outros}</strong>: a limpeza apaga os '
    'arquivos antigos de todos os que estiverem nela.':
        'La carpeta de este usuario también es alcanzada por <strong>{outros}</strong>: la limpieza borra '
        'los archivos antiguos de todos los que estén en ella.',
    'O painel apaga sozinho os arquivos antigos da pasta deste usuário e das pastas de dentro dela. '
    'Campo vazio desliga aquela regra; os dois vazios desligam a limpeza.':
        'El panel borra solo los archivos antiguos de la carpeta de este usuario y de las carpetas que hay '
        'dentro de ella. Un campo vacío desactiva esa regla; los dos vacíos desactivan la limpieza.',
    'Manter só os arquivos mais recentes':
        'Mantener solo los archivos más recientes',
    'quantos ficam em cada pasta; os mais antigos saem':
        'cuántos quedan en cada carpeta; los más antiguos salen',
    'Apagar o arquivo com mais de tantos dias':
        'Borrar el archivo con más de tantos días',
    'dias no servidor, desde que chegou ou foi alterado':
        'días en el servidor, desde que llegó o fue modificado',
    'A contagem é por pasta: com 30, cada pasta fica com os 30 arquivos mais recentes dela. Com os '
    'dois campos preenchidos, sai o arquivo que passar de qualquer um. Não saem link simbólico nem '
    'arquivo ou pasta com o nome começado por ponto; a subpasta que a limpeza esvaziar sai junto.':
        'El conteo es por carpeta: con 30, cada carpeta queda con sus 30 archivos más recientes. Con los dos '
        'campos completados, sale el archivo que pase de cualquiera de ellos. No salen los enlaces '
        'simbólicos ni los archivos o carpetas con el nombre empezado por punto; la subcarpeta que la '
        'limpieza vacíe sale junto con ellos.',
    'O painel <strong>não tem lixeira</strong>: o que a limpeza apaga não volta. Na regra por dias, o '
    'equipamento que parar de enviar fica sem nenhum arquivo depois do prazo; para backup de '
    'equipamento, prefira manter os mais recentes.':
        'El panel <strong>no tiene papelera</strong>: lo que la limpieza borra no vuelve. En la regla por '
        'días, el equipo que deje de enviar queda sin ningún archivo después del plazo; para copias de '
        'seguridad de equipos, prefiera mantener los más recientes.',
    'para gravar a limpeza':
        'para guardar la limpieza',
    'Gravar limpeza':
        'Guardar limpieza',
    'mantém só o arquivo mais recente de cada pasta':
        'mantiene solo el archivo más reciente de cada carpeta',
    'mantém só os {n} arquivos mais recentes de cada pasta':
        'mantiene solo los {n} archivos más recientes de cada carpeta',
    'apaga o arquivo com mais de {n} dia':
        'borra el archivo con más de {n} día',
    'apaga o arquivo com mais de {n} dias':
        'borra el archivo con más de {n} días',
    'arquivos mantidos':
        'archivos mantenidos',
    'dias':
        'días',
    'pastas':
        'carpetas',
    'erros':
        'errores',
    'Valor inválido em "{campo}": deixe vazio ou use um número inteiro de 1 a {maximo}.':
        'Valor no válido en "{campo}": deje vacío o use un número entero de 1 a {maximo}.',
    'Limpeza automática do usuário alterada':
        'Limpieza automática del usuario modificada',
    'Limpeza automática: arquivos antigos apagados':
        'Limpieza automática: archivos antiguos borrados',
    'Limpeza automática não concluída':
        'Limpieza automática no concluida',
    'Limpeza automática, ligada pelo administrador: o servidor {regra}, sozinho. O que sai não volta: '
    'baixe o que precisa guardar.':
        'Limpieza automática, activada por el administrador: el servidor {regra}, solo. Lo que sale no '
        'vuelve: descargue lo que necesita guardar.',
    'Trocar pasta':
        'Cambiar carpeta',
    'Esta já é a pasta do usuário.':
        'Esta ya es la carpeta del usuario.',
    'Usuário <strong>{nome}</strong>. A senha antiga deixa de valer no próximo login.':
        'Usuario <strong>{nome}</strong>. La contraseña antigua deja de valer en el próximo inicio de sesión.',
    'Apagar também a pasta e tudo o que há nela':
        'Borrar también la carpeta y todo lo que hay en ella',
    'O painel <strong>não tem lixeira</strong>: a pasta apagada só volta de uma cópia de segurança. '
    'Sem marcar a caixa, os arquivos continuam em {onde}.':
        'El panel <strong>no tiene papelera</strong>: la carpeta borrada solo vuelve de una copia de '
        'seguridad. Sin marcar la casilla, los archivos siguen en {onde}.',
    'Remover <strong>{nome}</strong>? O login deixa de funcionar na hora.':
        '¿Eliminar <strong>{nome}</strong>? El inicio de sesión deja de funcionar en el acto.',
    'A pasta dele tem {arquivos} arquivo(s), {tamanho}, em {onde}.':
        'Su carpeta tiene {arquivos} archivo(s), {tamanho}, en {onde}.',
    'Sim, remover o usuário':
        'Sí, eliminar el usuario',
    'A pasta deste usuário não pode ser apagada junto: outro usuário a alcança, ou ela fica fora da '
    'pasta dos dados. Nada foi alterado.':
        'La carpeta de este usuario no puede borrarse junto con él: otro usuario la alcanza, o queda fuera '
        'de la carpeta de los datos. No se modificó nada.',
    'Não foi possível remover:':
        'No fue posible eliminar:',
    'Não foi possível alterar:':
        'No fue posible modificar:',
    'dividida':
        'compartida',
    'e outros':
        'y otros',
    'sem TLS':
        'sin TLS',
    'obrigatório':
        'obligatorio',
    'Pasta alcançada por mais de um usuário: cada um mexe nos arquivos do outro até onde o perfil dele '
    'deixa.':
        'Carpeta alcanzada por más de un usuario: cada uno toca los archivos del otro hasta donde su perfil '
        'lo permite.',
    'Limite próprio, ajustado em Editar.':
        'Límite propio, ajustado en Editar.',
    'Recusado pelo FTP por senhas erradas demais vindas de um endereço: o bloqueio sai sozinho no fim '
    'do prazo, ou em Editar.':
        'Rechazado por el FTP por demasiadas contraseñas incorrectas provenientes de una dirección: el '
        'bloqueo sale solo al final del plazo, o en Editar.',
    'As contas do painel e do FTP, cada uma com o seu perfil.':
        'Las cuentas del panel y del FTP, cada una con su perfil.',
    'Como funcionam os perfis e as etiquetas':
        'Cómo funcionan los perfiles y las etiquetas',
    'Não foi possível criar:':
        'No fue posible crear:',
    'Pasta nova':
        'Carpeta nueva',
    'Não foi possível trocar:':
        'No fue posible cambiar:',
    'Todos os usuários seguem o <code>FTP_TLS_MODE</code>.':
        'Todos los usuarios siguen el <code>FTP_TLS_MODE</code>.',
    'O usuário <strong>{nome}</strong> entra hoje <strong>sem TLS</strong>. Ao voltar a exigir, o '
    'equipamento dele só entra com TLS (FTPS explícito): confira antes se ele já foi configurado para '
    'isso.':
        'El usuario <strong>{nome}</strong> entra hoy <strong>sin TLS</strong>. Al volver a exigirlo, su '
        'equipo solo entra con TLS (FTPS explícito): compruebe antes si ya fue configurado para eso.',
    'Deixar <strong>{nome}</strong> entrar no FTP <strong>sem TLS</strong>?':
        '¿Dejar que <strong>{nome}</strong> entre en el FTP <strong>sin TLS</strong>?',
    'pedida para criar administrador':
        'pedida para crear administrador',
    'só para apagar a pasta':
        'solo para borrar la carpeta',
    'Como o servidor está agora e o que colocar no equipamento para ele enviar o backup.':
        'Cómo está el servidor ahora y qué poner en el equipo para que envíe la copia de seguridad.',
    '{espaco} livres no disco':
        '{espaco} libres en el disco',
    'Sem TLS: texto puro':
        'Sin TLS: texto plano',
    'TLS opcional: aceita texto puro':
        'TLS opcional: acepta texto plano',
    'TLS obrigatório no login':
        'TLS obligatorio en el inicio de sesión',
    'TLS obrigatório no login e nos dados':
        'TLS obligatorio en el inicio de sesión y en los datos',
    'hoje':
        'hoy',
    'A contagem está incompleta: há pasta grande demais para ser lida inteira.':
        'El conteo está incompleto: hay una carpeta demasiado grande para leerse entera.',
    'Arquivos recebidos por dia':
        'Archivos recibidos por día',
    '<strong class="numero">{quantos}</strong> com data de {desde} até hoje, em todas as pastas':
        '<strong class="numero">{quantos}</strong> con fecha desde {desde} hasta hoy, en todas las carpetas',
    'Conta o que está nas pastas agora, pela data de cada arquivo: o que foi apagado ou substituído '
    'não entra.':
        'Cuenta lo que está en las carpetas ahora, por la fecha de cada archivo: lo que fue borrado o '
        'sustituido no entra.',
    'Último envio por usuário':
        'Último envío por usuario',
    'ver os usuários':
        'ver los usuarios',
    'Espaço por pasta':
        'Espacio por carpeta',
    'ver as pastas':
        'ver las carpetas',
    'não lido':
        'no leído',
    'não foi possível ler o certificado':
        'no fue posible leer el certificado',
    'vencido há {dias} dias':
        'vencido hace {dias} días',
    'válido, faltam {dias} dias':
        'válido, faltan {dias} días',
    'Visão geral':
        'Visión general',
    'arquivos':
        'archivos',
    'Nenhum usuário cadastrado. O primeiro é criado em <a href="/usuarios">Usuários</a>.':
        'Ningún usuario registrado. El primero se crea en <a href="/usuarios">Usuarios</a>.',
    'Nenhum usuário está há mais de 7 dias sem enviar.':
        'Ningún usuario lleva más de 7 días sin enviar.',
    'Nenhuma pasta de usuário ainda.':
        'Ninguna carpeta de usuario todavía.',
    'Sem enviar há mais de 7 dias':
        'Sin enviar hace más de 7 días',
    'As {maiores} maiores de {todas} pastas.':
        'Las {maiores} mayores de {todas} carpetas.',
    'Situação do servidor':
        'Estado del servidor',
    'conferir a segurança':
        'revisar la seguridad',
    'contas cadastradas no FTP':
        'cuentas registradas en el FTP',
    'Espaço usado':
        'Espacio usado',
    'arquivo mais novo nas pastas':
        'archivo más nuevo en las carpetas',
    'ver os arquivos':
        'ver los archivos',
    'conferir a impressão digital':
        'comprobar la huella digital',
    'Atividade recente':
        'Actividad reciente',
    'ver o log inteiro':
        'ver el log entero',
    'Dados para configurar o equipamento':
        'Datos para configurar el equipo',
    'um usuário por equipamento ou por grupo, criado em <a href="/usuarios">Usuários</a>':
        'un usuario por equipo o por grupo, creado en <a href="/usuarios">Usuarios</a>',
    'e mais {resto}, na aba Usuários.':
        'y {resto} más, en la pestaña Usuarios.',
    'nas últimas 24 horas':
        'en las últimas 24 horas',
    'entre 1 e 7 dias':
        'entre 1 y 7 días',
    'há mais de 7 dias':
        'hace más de 7 días',
    'sem arquivo na pasta':
        'sin archivo en la carpeta',
    '{quantos} arquivo':
        '{quantos} archivo',
    '{quantos} arquivos':
        '{quantos} archivos',
    'nenhum arquivo na pasta':
        'ningún archivo en la carpeta',
    'modo TLS {modo}':
        'modo TLS {modo}',
    'com exceção por usuário':
        'con excepción por usuario',
    'Envio sem tamanho declarado.':
        'Envío sin tamaño declarado.',
    'Envio grande demais.':
        'Envío demasiado grande.',
    'Formato de envio não aceito.':
        'Formato de envío no aceptado.',
    'Idioma não aceito.':
        'Idioma no aceptado.',
    'Não foi possível gravar o idioma.':
        'No fue posible guardar el idioma.',
    'Formulário sem token válido. Abra a página de novo e repita.':
        'Formulario sin token válido. Abra la página de nuevo y repita.',
    'Envio malformado.':
        'Envío mal formado.',
    'cliente fora das redes permitidas':
        'cliente fuera de las redes permitidas',
    'endereço bloqueado por excesso de erros de usuário e senha':
        'dirección bloqueada por exceso de errores de usuario y contraseña',
    'endereço não aceito':
        'dirección no aceptada',
    'O envio não partiu deste painel.':
        'El envío no partió de este panel.',
    'Não encontrado':
        'No encontrado',
    'Voltar ao painel':
        'Volver al panel',
    'pedido sem o endereço do cliente':
        'solicitud sin la dirección del cliente',
    'contato de segurança não configurado':
        'contacto de seguridad no configurado',
    'Página não encontrada':
        'Página no encontrada',
    'OLT / rádio':
        'OLT / radio',
    'roteador / switch':
        'router / switch',
    'empresa / pessoa':
        'empresa / persona',
    'câmera':
        'cámara',
    '/olt /radio':
        '/olt /radio',
    '/roteador /switch':
        '/router /switch',
    '/empresa /pessoal':
        '/empresa /personal',
    '/cameras':
        '/camaras',
    'Pausar movimento':
        'Pausar movimiento',
    'Retomar movimento':
        'Reanudar movimiento',
    'a opção está desligada (<code>FTP_TLS_EXCECOES=nao</code>)':
        'la opción está desactivada (<code>FTP_TLS_EXCECOES=nao</code>)',
    'ela só vale com <code>FTP_TLS_MODE=2</code>, e o FTP está em outro modo':
        'solo vale con <code>FTP_TLS_MODE=2</code>, y el FTP está en otro modo',
    'ela não vale com <code>REDE_PERMITIR_IP_PUBLICO=sim</code>: FTP sem TLS na internet entrega a '
    'senha a quem escuta':
        'no vale con <code>REDE_PERMITIR_IP_PUBLICO=sim</code>: FTP sin TLS en internet entrega la '
        'contraseña a quien escucha',
    '(a de {dono}, {para})':
        '(la de {dono}, {para})',
    'Sua senha do FTP':
        'Su contraseña del FTP',
    'Sua senha atual':
        'Su contraseña actual',
    'Muitas tentativas. Aguarde alguns minutos e tente de novo.':
        'Demasiados intentos. Espere unos minutos e inténtelo de nuevo.',
    'para confirmar':
        'para confirmar',
    'A sua senha atual não confere. Nada foi apagado.':
        'Su contraseña actual no coincide. No se borró nada.',
    'A sua senha atual não confere. Nada foi alterado.':
        'Su contraseña actual no coincide. No se modificó nada.',
    'Não foi possível conferir a sua senha agora. Nada foi apagado. Tente de novo em instantes.':
        'No fue posible comprobar su contraseña ahora. No se borró nada. Inténtelo de nuevo en unos instantes.',
    'Não foi possível conferir a sua senha agora. Nada foi alterado. Tente de novo em instantes.':
        'No fue posible comprobar su contraseña ahora. No se modificó nada. Inténtelo de nuevo en unos instantes.',
    'FTP':
        'FTP',
    'Administradores entram com a conta do painel. Usuários do FTP entram com o nome e a senha do FTP '
    'e veem só os arquivos da própria pasta.':
        'Los administradores entran con la cuenta del panel. Los usuarios del FTP entran con el nombre y la '
        'contraseña del FTP y ven solo los archivos de su propia carpeta.',
    'Painel de administração da stack.':
        'Panel de administración de la stack.',
    'Entrar':
        'Entrar',
    'A página expirou. Tente de novo.':
        'La página expiró. Inténtelo de nuevo.',
    'Não foi possível entrar.':
        'No fue posible entrar.',
    'Backups e arquivos, guardados em um lugar só.':
        'Copias de seguridad y archivos, guardados en un solo lugar.',
    'Equipamentos de rede, câmeras, sistemas e arquivos de pessoas e empresas':
        'Equipos de red, cámaras, sistemas y archivos de personas y empresas',
    'Cada conta presa na própria pasta':
        'Cada cuenta confinada en su propia carpeta',
    'Painel só por HTTPS, atrás do nginx':
        'Panel solo por HTTPS, detrás de nginx',
    'Sessão encerrada depois de {prazo} sem uso':
        'Sesión cerrada después de {prazo} sin uso',
    'Entrar no painel':
        'Entrar en el panel',
    'Uso restrito a quem foi autorizado. As tentativas de entrada ficam registradas.':
        'Uso restringido a quien fue autorizado. Los intentos de entrada quedan registrados.',
    'A pasta passa por um link simbólico, que não é aceito.':
        'La carpeta pasa por un enlace simbólico, que no se acepta.',
    'Já existe um arquivo com este nome no caminho da pasta.':
        'Ya existe un archivo con este nombre en la ruta de la carpeta.',
    'Não foi possível conferir a pasta.':
        'No fue posible comprobar la carpeta.',
    'O comando de usuários não respondeu.':
        'El comando de usuarios no respondió.',
    'erro sem mensagem':
        'error sin mensaje',
    'sessões no FTP':
        'sesiones en el FTP',
    'download em KB/s':
        'descarga en KB/s',
    'envio em KB/s':
        'envío en KB/s',
    'horário':
        'horario',
    'downloads pelo painel':
        'descargas por el panel',
    'senhas erradas até o bloqueio':
        'contraseñas incorrectas hasta el bloqueo',
    'minutos de bloqueio':
        'minutos de bloqueo',
    '{inicio} às {fim}':
        '{inicio} a {fim}',
    'Limite inválido em "{limite}": deixe vazio ou use um número inteiro de {minimo} a {maximo}.':
        'Límite no válido en "{limite}": deje vacío o use un número entero de {minimo} a {maximo}.',
    'Horário inválido: preencha o início e o fim, no formato HH:MM, ou deixe os dois vazios.':
        'Horario no válido: complete el inicio y el fin, en el formato HH:MM, o deje los dos vacíos.',
    'Horário inválido: o início e o fim não podem ser iguais.':
        'Horario no válido: el inicio y el fin no pueden ser iguales.',
    'nunca bloqueia':
        'nunca bloquea',
    'Operação':
        'Operación',
    'Sistema':
        'Sistema',
    'atenção':
        'atención',
    'problema':
        'problema',
    'não se aplica':
        'no se aplica',
    'conferir no servidor':
        'comprobar en el servidor',
    'Use só para equipamento antigo sem suporte a TLS, em rede interna isolada, e volte para '
    '<code>FTP_TLS_MODE=2</code> assim que puder.':
        'Úselo solo para equipos antiguos sin soporte de TLS, en red interna aislada, y vuelva a '
        '<code>FTP_TLS_MODE=2</code> en cuanto pueda.',
    'válido até {data} ({dias} dias)':
        'válido hasta {data} ({dias} días)',
    'vencido em {data}':
        'vencido el {data}',
    'Idioma das telas':
        'Idioma de las pantallas',
    'Usuário do FTP':
        'Usuario del FTP',
    'Abas do painel':
        'Pestañas del panel',
    'Sair':
        'Salir',
    'só para rede privada, atrás de firewall':
        'solo para red privada, detrás de firewall',
    'Pular para o conteúdo':
        'Saltar al contenido',
    'Desenvolvido pela':
        'Desarrollado por',
    '<strong>{quantos} usuário(s) entram no FTP sem TLS</strong> ({nomes}): a senha e os arquivos '
    'deles trafegam em texto puro e podem ser lidos por quem estiver na mesma rede. Use só para '
    'equipamento antigo sem suporte a TLS, em rede interna isolada, e volte a exigir o TLS em <a '
    'href="/usuarios">Usuários</a> assim que puder.':
        '<strong>{quantos} usuario(s) entran en el FTP sin TLS</strong> ({nomes}): su contraseña y sus '
        'archivos viajan en texto plano y pueden ser leídos por quien esté en la misma red. Úselo solo para '
        'equipos antiguos sin soporte de TLS, en red interna aislada, y vuelva a exigir el TLS en <a '
        'href="/usuarios">Usuarios</a> en cuanto pueda.',
    'Endereço público aceito (<code>REDE_PERMITIR_IP_PUBLICO=sim</code>), por opção de quem instalou. '
    'FTP e painel na internet são alvo de varredura e de tentativa de senha o tempo todo: mantenha o '
    'firewall do servidor liberando só os endereços dos equipamentos e de quem administra.':
        'Dirección pública aceptada (<code>REDE_PERMITIR_IP_PUBLICO=sim</code>), por opción de quien '
        'instaló. FTP y panel en internet son blanco de escaneo y de intentos de contraseña todo el tiempo: '
        'mantenga el firewall del servidor permitiendo solo las direcciones de los equipos y de quien administra.',
    'Painel publicado por proxy ou túnel (<code>PAINEL_PROXY_CONFIAVEL</code>), por opção de quem '
    'instalou. Quem chega à tela de entrada é decidido lá: restrinja o acesso no proxy ou no túnel. O '
    'FTP não passa por ele.':
        'Panel publicado por proxy o túnel (<code>PAINEL_PROXY_CONFIAVEL</code>), por opción de quien '
        'instaló. Quién llega a la pantalla de entrada se decide allí: restrinja el acceso en el proxy o en '
        'el túnel. El FTP no pasa por él.',
    'O FTP está <strong>sem TLS</strong> (<code>FTP_TLS_MODE=0</code>): senhas e arquivos trafegam em '
    'texto puro e podem ser lidos por quem estiver na mesma rede.':
        'El FTP está <strong>sin TLS</strong> (<code>FTP_TLS_MODE=0</code>): las contraseñas y los archivos '
        'viajan en texto plano y pueden ser leídos por quien esté en la misma red.',
    'O TLS do FTP está <strong>opcional</strong> (<code>FTP_TLS_MODE=1</code>): quem entra sem TLS '
    'manda senha e arquivos em texto puro.':
        'El TLS del FTP está <strong>opcional</strong> (<code>FTP_TLS_MODE=1</code>): quien entra sin TLS '
        'manda contraseña y archivos en texto plano.',
    'Esta instalação está publicada fora da rede privada: veja como nesta aba':
        'Esta instalación está publicada fuera de la red privada: vea cómo en esta pestaña',
    '(instalação publicada)':
        '(instalación publicada)',
    'endereço público aceito: confira o firewall':
        'dirección pública aceptada: revise el firewall',
    'painel publicado por proxy ou túnel':
        'panel publicado por proxy o túnel',
    'O painel navega, baixa, envia arquivo, cria pasta, troca o nome e apaga; arquivo enviado não '
    'substitui outro. Trocar o nome e apagar pedem a sua senha atual, e apagar não tem lixeira. Todo '
    'download e toda alteração ficam registrados na aba Log.':
        'El panel navega, descarga, envía archivos, crea carpetas, cambia el nombre y borra; un archivo '
        'enviado no sustituye a otro. Cambiar el nombre y borrar piden su contraseña actual, y borrar no '
        'tiene papelera. Toda descarga y todo cambio quedan registrados en la pestaña Log.',
    'Arquivo enviado.':
        'Archivo enviado.',
    'Arquivo enviado. Já havia um com este nome: o novo foi guardado com a data e a hora no nome.':
        'Archivo enviado. Ya había uno con este nombre: el nuevo se guardó con la fecha y la hora en el nombre.',
    'Arquivo, guardado na pasta do usuário no servidor':
        'Archivo, guardado en la carpeta del usuario en el servidor',
    'Nome que já existe não substitui o anterior: o novo é guardado com a data e a hora no nome.':
        'Un nombre que ya existe no sustituye al anterior: el nuevo se guarda con la fecha y la hora en el nombre.',
    'Arquivo, gravado em <code>{onde}</code>':
        'Archivo, guardado en <code>{onde}</code>',
    'Nome que já existe na pasta não é substituído: o envio é recusado.':
        'Un nombre que ya existe en la carpeta no se sustituye: el envío se rechaza.',
    'Enviar arquivo':
        'Enviar archivo',
    'Gravar com o nome <span class="suave">(deixe em branco para manter o nome do arquivo)</span>':
        'Guardar con el nombre <span class="suave">(deje en blanco para mantener el nombre del archivo)</span>',
    'Até {maximo} por arquivo.':
        'Hasta {maximo} por archivo.',
    'Envio não permitido':
        'Envío no permitido',
    'Esta conta não tem a permissão de enviar arquivo pelo painel. Quem dá a permissão é um administrador.':
        'Esta cuenta no tiene el permiso de enviar archivos por el panel. Quien da el permiso es un administrador.',
    'Escolha o arquivo e envie de novo.':
        'Elija el archivo y envíe de nuevo.',
    'Nenhum arquivo escolhido':
        'Ningún archivo elegido',
    'O nome do arquivo usa letras, números, _, - e ponto, não começa com ponto e tem até 64 '
    'caracteres. Troque o nome do arquivo ou preencha o campo "Gravar com o nome".':
        'El nombre del archivo usa letras, números, _, - y punto, no empieza con punto y tiene hasta 64 '
        'caracteres. Cambie el nombre del archivo o complete el campo "Guardar con el nombre".',
    'Arquivo grande demais':
        'Archivo demasiado grande',
    'Arquivo grande demais: o painel recebe até {maximo} por arquivo.':
        'Archivo demasiado grande: el panel recibe hasta {maximo} por archivo.',
    'Esta conta envia um arquivo por vez.':
        'Esta cuenta envía un archivo por vez.',
    'O painel recebe até {maximo} arquivos por vez.':
        'El panel recibe hasta {maximo} archivos por vez.',
    'Muitos envios ao mesmo tempo':
        'Demasiados envíos al mismo tiempo',
    'Espere terminar e repita.':
        'Espere a que termine y repita.',
    'O envio parou antes do fim: nada foi gravado.':
        'El envío se detuvo antes del final: no se guardó nada.',
    'O servidor não tem espaço livre para este arquivo.':
        'El servidor no tiene espacio libre para este archivo.',
    'Sem espaço':
        'Sin espacio',
    'Arquivo não gravado':
        'Archivo no guardado',
    'Não foi possível gravar o arquivo.':
        'No fue posible guardar el archivo.',
    'Cada arquivo que termina de chegar é guardado na pasta do usuário <strong>{usuario}</strong> no '
    'servidor, fora do alcance desta conta: ela não lista, não baixa, não renomeia e não apaga o que '
    'já enviou, nem por FTP nem por aqui.':
        'Cada archivo que termina de llegar se guarda en la carpeta del usuario <strong>{usuario}</strong> '
        'en el servidor, fuera del alcance de esta cuenta: no lista, no descarga, no renombra y no borra lo '
        'que ya envió, ni por FTP ni por aquí.',
    'Aqui você navega, baixa e cria pasta. O perfil desta conta é de envio: o que já foi enviado não '
    'é renomeado nem apagado por ela. Todo download e toda pasta criada ficam registrados.':
        'Aquí usted navega, descarga y crea carpetas. El perfil de esta cuenta es de envío: lo que ya se '
        'envió no es renombrado ni borrado por ella. Toda descarga y toda carpeta creada quedan registradas.',
    'Aqui você navega, baixa, cria pasta, troca o nome e apaga. Trocar o nome e apagar pedem a sua '
    'senha do FTP, e apagar não tem lixeira. Todo download e toda alteração ficam registrados.':
        'Aquí usted navega, descarga, crea carpetas, cambia el nombre y borra. Cambiar el nombre y borrar '
        'piden su contraseña del FTP, y borrar no tiene papelera. Toda descarga y todo cambio quedan registrados.',
    'Esta conta também envia arquivo por aqui: o envio fica registrado e nunca substitui um arquivo que já existe.':
        'Esta cuenta también envía archivos por aquí: el envío queda registrado y nunca sustituye un archivo '
        'que ya existe.',
    'Enviar arquivo, só por FTP: o envio por aqui depende de uma permissão que o administrador dá a cada conta.':
        'Enviar archivos, solo por FTP: el envío por aquí depende de un permiso que el administrador da a '
        'cada cuenta.',
    'Ela envia arquivo, por FTP ou por esta tela, e mais nada.':
        'Envía archivos, por FTP o por esta pantalla, y nada más.',
    'Ela envia arquivo por FTP e mais nada.':
        'Envía archivos por FTP y nada más.',
    'no FTP e nos envios dele pelo painel; no FTP, cada arquivo enviado leva pelo menos 256 ÷ taxa segundos':
        'en el FTP y en sus envíos por el panel; en el FTP, cada archivo enviado tarda al menos 256 ÷ tasa segundos',
    'Permitir que este usuário <strong>envie arquivo pelo painel</strong>, para a pasta dele':
        'Permitir que este usuario <strong>envíe archivos por el panel</strong>, a su carpeta',
    'Sem marcar, o usuário só envia por FTP. Vale para os perfis Só envio, Envio e Completo; o perfil '
    'Leitura não envia. A permissão vale na hora. Arquivo enviado pelo painel tem até {maximo}, segue '
    'a taxa de envio acima e nunca substitui um arquivo que já existe.':
        'Sin marcar, el usuario solo envía por FTP. Vale para los perfiles Solo envío, Envío y Completo; el '
        'perfil Lectura no envía. El permiso vale en el acto. Un archivo enviado por el panel tiene hasta '
        '{maximo}, sigue la tasa de envío de arriba y nunca sustituye un archivo que ya existe.',
    'permitido':
        'permitido',
    'envio pelo painel':
        'envío por el panel',
    'destino':
        'destino',
    'motivo':
        'motivo',
    'apagados do servidor':
        'borrados del servidor',
    'acima do limite do bot':
        'por encima del límite del bot',
    'ignorados':
        'ignorados',
    'depois do envio':
        'después del envío',
    'minutos entre as passadas':
        'minutos entre las pasadas',
    'resultado':
        'resultado',
    'arquivo':
        'archivo',
    'situação':
        'estado',
    'segredos':
        'secretos',
    'Destino de envio gravado':
        'Destino de envío guardado',
    'Destino de envio removido':
        'Destino de envío eliminado',
    'Teste de destino de envio':
        'Prueba de destino de envío',
    'Envio para o destino pedido fora de hora':
        'Envío al destino solicitado fuera de hora',
    'Arquivos enviados para o destino':
        'Archivos enviados al destino',
    'Envio para o destino não concluído':
        'Envío al destino no concluido',
    'Arquivo recusado pelo destino deixado para trás':
        'Archivo rechazado por el destino dejado atrás',
    'Armazenamento S3':
        'Almacenamiento S3',
    'Bot do Telegram':
        'Bot de Telegram',
    'Destino gravado. Vale a partir da próxima passada.':
        'Destino guardado. Vale a partir de la próxima pasada.',
    'Destino removido: a configuração e os segredos dele foram apagados.':
        'Destino eliminado: su configuración y sus secretos fueron borrados.',
    'Teste concluído: o destino recebeu.':
        'Prueba concluida: el destino recibió.',
    'Passada pedida: o painel começa em instantes. Atualize a tela para acompanhar.':
        'Pasada solicitada: el panel empieza en instantes. Actualice la pantalla para seguirla.',
    'o nome do endereço não foi encontrado':
        'el nombre de la dirección no fue encontrado',
    'o endereço não é aceito pelo painel, ou o serviço mandou o pedido para outro endereço':
        'la dirección no es aceptada por el panel, o el servicio envió la solicitud a otra dirección',
    'não foi possível conectar ao serviço':
        'no fue posible conectar con el servicio',
    'o certificado do serviço não foi aceito':
        'el certificado del servicio no fue aceptado',
    'o serviço não respondeu a tempo':
        'el servicio no respondió a tiempo',
    'a resposta do serviço não foi entendida':
        'la respuesta del servicio no fue entendida',
    'o painel não faz esse pedido a um destino: ele só grava e só envia, e não apaga nada lá':
        'el panel no hace esa solicitud a un destino: solo escribe y solo envía, y no borra nada allí',
    'o serviço recusou a credencial ou a permissão':
        'el servicio rechazó la credencial o el permiso',
    'o bucket ou a conversa não existe para esta credencial':
        'el bucket o la conversación no existe para esta credencial',
    'o arquivo é maior do que o serviço aceita':
        'el archivo es mayor de lo que el servicio acepta',
    'um arquivo não pôde ser lido':
        'un archivo no pudo leerse',
    'a pasta escolhida não existe mais dentro dos dados':
        'la carpeta elegida ya no existe dentro de los datos',
    'faltam os segredos do destino: grave-os de novo':
        'faltan los secretos del destino: guárdelos de nuevo',
    'o S3 espera os outros destinos da mesma pasta entregarem o que falta antes de apagar mais arquivos':
        'el S3 espera a que los otros destinos de la misma carpeta entreguen lo que falta antes de borrar '
        'más archivos',
    'outro teste está em andamento: tente de novo em instantes':
        'otra prueba está en curso: inténtelo de nuevo en unos instantes',
    'o arquivo está vazio, e o bot não envia arquivo vazio':
        'el archivo está vacío, y el bot no envía archivos vacíos',
    'o nome do arquivo não cabe no destino':
        'el nombre del archivo no cabe en el destino',
    'o arquivo mudou durante o envio: repita quando ele terminar de chegar':
        'el archivo cambió durante el envío: repita cuando termine de llegar',
    'outro envio pedido pela tela está em andamento: tente de novo em instantes':
        'otro envío solicitado desde la pantalla está en curso: inténtelo de nuevo en unos instantes',
    'Enviar este arquivo pelo bot do Telegram':
        'Enviar este archivo por el bot de Telegram',
    'Enviar este arquivo para o armazenamento S3':
        'Enviar este archivo al almacenamiento S3',
    'Ainda chegando':
        'Todavía llegando',
    '{n} arquivo mudou há menos de dois minutos e ainda pode estar chegando: vai em uma próxima passada':
        '{n} archivo cambió hace menos de dos minutos y todavía puede estar llegando: va en una próxima pasada',
    '{n} arquivos mudaram há menos de dois minutos e ainda podem estar chegando: vão em uma próxima passada':
        '{n} archivos cambiaron hace menos de dos minutos y todavía pueden estar llegando: van en una próxima pasada',
    'O arquivo que chega inteiro por FTP ou pelo painel sai em instantes, sem esperar o intervalo. O '
    'intervalo confere o que ficou para trás: o arquivo que trocou de nome e o que chegou por outro '
    'caminho.':
        'El archivo que llega entero por FTP o por el panel sale en instantes, sin esperar el intervalo. El '
        'intervalo revisa lo que quedó atrás: el archivo que cambió de nombre y el que llegó por otro camino.',
    '{destino}: arquivo enviado.':
        '{destino}: archivo enviado.',
    '{destino}: o envio continua em segundo plano. O resultado aparece na aba Log.':
        '{destino}: el envío continúa en segundo plano. El resultado aparece en la pestaña Log.',
    'Arquivo enviado para o destino a pedido':
        'Archivo enviado al destino a pedido',
    'o destino está desligado ou sem os segredos':
        'el destino está desactivado o sin los secretos',
    'Formulário incompleto: abra a tela de novo.':
        'Formulario incompleto: abra la pantalla de nuevo.',
    'Endereço inválido: use https://nome ou https://nome:porta, em minúsculas e sem caminho.':
        'Dirección no válida: use https://nombre o https://nombre:puerto, en minúsculas y sin ruta.',
    'Região inválida: letras minúsculas, números e hífen, até 32 caracteres.':
        'Región no válida: letras minúsculas, números y guion, hasta 32 caracteres.',
    'Bucket inválido: de 3 a 63 caracteres, com letras minúsculas, números, ponto e hífen.':
        'Bucket no válido: de 3 a 63 caracteres, con letras minúsculas, números, punto y guion.',
    'Prefixo inválido: até 8 níveis separados por barra, com letras, números, _, - e ponto.':
        'Prefijo no válido: hasta 8 niveles separados por barra, con letras, números, _, - y punto.',
    'Escolha a forma do endereço do bucket.':
        'Elija la forma de la dirección del bucket.',
    'Escolha o que acontece com o arquivo depois do envio.':
        'Elija qué ocurre con el archivo después del envío.',
    'Pasta inválida: até 4 níveis separados por barra, com letras, números, _, - e ponto.':
        'Carpeta no válida: hasta 4 niveles separados por barra, con letras, números, _, - y punto.',
    'Intervalo inválido: de 5 a 1440 minutos.':
        'Intervalo no válido: de 5 a 1440 minutos.',
    'falha não identificada':
        'fallo no identificado',
    'a cada {n} minuto':
        'cada {n} minuto',
    'a cada {n} minutos':
        'cada {n} minutos',
    'Remover destino':
        'Eliminar destino',
    'o serviço respondeu com o código {codigo}':
        'el servicio respondió con el código {codigo}',
    'toda a pasta dos dados':
        'toda la carpeta de los datos',
    '{n} arquivo enviado':
        '{n} archivo enviado',
    '{n} arquivos enviados':
        '{n} archivos enviados',
    'Guardar no S3: o arquivo sai do servidor depois de gravado no destino':
        'Conservar en S3: el archivo sale del servidor después de guardado en el destino',
    'Copiar: o arquivo continua no servidor':
        'Copiar: el archivo sigue en el servidor',
    'gravados; não aparecem na tela':
        'guardados; no aparecen en la pantalla',
    'faltando':
        'faltan',
    '{destino}: não deu certo. Motivo: {motivo}.':
        '{destino}: no salió bien. Motivo: {motivo}.',
    'em branco mantém o gravado':
        'en blanco mantiene el guardado',
    '{n} apagado do servidor':
        '{n} borrado del servidor',
    '{n} apagados do servidor':
        '{n} borrados del servidor',
    '{n} acima do limite do bot (foi só o aviso)':
        '{n} por encima del límite del bot (solo fue el aviso)',
    '{n} ignorado':
        '{n} ignorado',
    '{n} ignorados':
        '{n} ignorados',
    '{n} recusado pelo destino':
        '{n} rechazado por el destino',
    '{n} recusados pelo destino':
        '{n} rechazados por el destino',
    'Endereço':
        'Dirección',
    'Bucket e prefixo':
        'Bucket y prefijo',
    'Região':
        'Región',
    'Pasta enviada':
        'Carpeta enviada',
    'Passadas':
        'Pasadas',
    'Depois do envio':
        'Después del envío',
    'Maior arquivo que o bot envia':
        'Mayor archivo que el bot envía',
    'Idioma das mensagens':
        'Idioma de los mensajes',
    'Envia os arquivos de uma pasta para um bucket de qualquer serviço que fale o protocolo do S3, na '
    'nuvem ou na rede interna. Pode só copiar, ou guardar lá e liberar o disco do servidor.':
        'Envía los archivos de una carpeta a un bucket de cualquier servicio que hable el protocolo de S3, '
        'en la nube o en la red interna. Puede solo copiar, o conservar allí y liberar el disco del servidor.',
    'Envia cada arquivo que chega em uma pasta para uma pessoa, um grupo ou um canal, por um bot do '
    'Telegram. O bot só envia: o painel não lê mensagem nem aceita comando pela conversa.':
        'Envía cada archivo que llega a una carpeta a una persona, un grupo o un canal, por un bot de '
        'Telegram. El bot solo envía: el panel no lee mensajes ni acepta comandos por la conversación.',
    'Testar':
        'Probar',
    'Enviar agora':
        'Enviar ahora',
    'Alterar':
        'Modificar',
    'Destinos':
        'Destinos',
    'Ligado: o painel envia sozinho, no intervalo abaixo':
        'Activado: el panel envía solo, en el intervalo de abajo',
    'Intervalo entre as passadas':
        'Intervalo entre las pasadas',
    'minutos, de 5 a 1440':
        'minutos, de 5 a 1440',
    'Chave de acesso inválida: de 3 a 128 caracteres, sem espaço.':
        'Clave de acceso no válida: de 3 a 128 caracteres, sin espacio.',
    'Chave secreta inválida: de 8 a 256 caracteres, sem espaço.':
        'Clave secreta no válida: de 8 a 256 caracteres, sin espacio.',
    'Token inválido: é o texto inteiro que o criador de bots entrega, com os números, os dois-pontos e o resto.':
        'Token no válido: es el texto entero que entrega el creador de bots, con los números, los dos puntos '
        'y el resto.',
    'Conversa inválida: o número da pessoa ou do grupo, ou o @nome do canal.':
        'Conversación no válida: el número de la persona o del grupo, o el @nombre del canal.',
    'A pasta não existe dentro dos dados. Crie em Arquivos ou confira o nome.':
        'La carpeta no existe dentro de los datos. Créela en Archivos o revise el nombre.',
    'não configurado':
        'no configurado',
    'faltam os segredos':
        'faltan los secretos',
    'ligado':
        'activado',
    'desligado':
        'desactivado',
    'Última passada':
        'Última pasada',
    'nenhuma ainda':
        'ninguna todavía',
    'Enviado desde que foi ligado':
        'Enviado desde que se activó',
    '{n} arquivo':
        '{n} archivo',
    '{n} arquivos':
        '{n} archivos',
    '{n} arquivo já gravado no S3 sai do servidor quando os outros destinos da pasta o entregarem':
        '{n} archivo ya guardado en S3 sale del servidor cuando los otros destinos de la carpeta lo entreguen',
    '{n} arquivos já gravados no S3 saem do servidor quando os outros destinos da pasta os entregarem':
        '{n} archivos ya guardados en S3 salen del servidor cuando los otros destinos de la carpeta los entreguen',
    'Agora':
        'Ahora',
    'passada em andamento':
        'pasada en curso',
    'Configurar':
        'Configurar',
    'A configuração está gravada, mas faltam os segredos deste destino (eles não entram na cópia de '
    'segurança). Abra <strong>Alterar</strong> e grave-os de novo; até lá, nada é enviado.':
        'La configuración está guardada, pero faltan los secretos de este destino (no entran en la copia de '
        'seguridad). Abra <strong>Modificar</strong> y guárdelos de nuevo; hasta entonces, no se envía nada.',
    'Chave de acesso e chave secreta':
        'Clave de acceso y clave secreta',
    'Token do bot e conversa':
        'Token del bot y conversación',
    'dentro dos dados, com as pastas de dentro dela; em branco é a pasta dos dados inteira':
        'dentro de los datos, con las carpetas que hay dentro de ella; en blanco es la carpeta de los datos entera',
    'Serve qualquer serviço que fale o protocolo do S3. A chave só precisa poder gravar no bucket '
    '(<code>s3:PutObject</code> e <code>s3:AbortMultipartUpload</code>): o painel não lê, não lista e '
    'não apaga nada no destino.':
        'Sirve cualquier servicio que hable el protocolo de S3. La clave solo necesita poder escribir en el '
        'bucket (<code>s3:PutObject</code> y <code>s3:AbortMultipartUpload</code>): el panel no lee, no '
        'lista y no borra nada en el destino.',
    'Em <strong>Guardar no S3</strong>, o destino passa a ter a única cópia: o painel não tem lixeira '
    'e não baixa de volta. A primeira passada envia tudo o que já está na pasta; com Guardar no S3, '
    'tudo isso sai do servidor. Trocar de Copiar para Guardar vale para o que for enviado dali em '
    'diante.':
        'En <strong>Conservar en S3</strong>, el destino pasa a tener la única copia: el panel no tiene '
        'papelera y no la descarga de vuelta. La primera pasada envía todo lo que ya está en la carpeta; con '
        'Conservar en S3, todo eso sale del servidor. Cambiar de Copiar a Conservar vale para lo que se '
        'envíe de ahí en adelante.',
    'O nome do objeto é o prefixo mais o caminho do arquivo dentro dos dados. Trocar o endereço, o '
    'bucket, o prefixo ou a pasta recomeça do zero: tudo o que está na pasta é enviado de novo.':
        'El nombre del objeto es el prefijo más la ruta del archivo dentro de los datos. Cambiar la '
        'dirección, el bucket, el prefijo o la carpeta vuelve a empezar de cero: todo lo que está en la '
        'carpeta se envía de nuevo.',
    'O bot <strong>só envia</strong>: o painel usa o envio de arquivo e o envio de mensagem, e nada '
    'mais. Não lê a conversa, não registra endereço de retorno e não aceita comando.':
        'El bot <strong>solo envía</strong>: el panel usa el envío de archivo y el envío de mensaje, y nada '
        'más. No lee la conversación, no registra dirección de retorno y no acepta comandos.',
    'A conversa é o número da pessoa ou do grupo (o de grupo começa com <code>-</code>) ou o '
    '<code>@nome</code> de um canal. O bot precisa estar no grupo ou no canal, e a pessoa precisa ter '
    'iniciado a conversa com ele.':
        'La conversación es el número de la persona o del grupo (el de grupo empieza con <code>-</code>) o '
        'el <code>@nombre</code> de un canal. El bot necesita estar en el grupo o en el canal, y la persona '
        'necesita haber iniciado la conversación con él.',
    'Vai um arquivo por mensagem, com o caminho, o tamanho e a data. O maior arquivo que o bot envia '
    'tem {limite}: acima disso vai só um aviso com o nome e o tamanho. Só é enviado o que chegar '
    'depois de o destino ser ligado; desligar e ligar de novo, ou trocar a pasta, recomeça dali.':
        'Va un archivo por mensaje, con la ruta, el tamaño y la fecha. El mayor archivo que el bot envía '
        'tiene {limite}: por encima de eso va solo un aviso con el nombre y el tamaño. Solo se envía lo que '
        'llegue después de que el destino se active; desactivar y activar de nuevo, o cambiar la carpeta, '
        'vuelve a empezar desde ahí.',
    'Preencha os dois segredos do destino: nenhum deles está gravado ainda.':
        'Complete los dos secretos del destino: ninguno de ellos está guardado todavía.',
    'A última passada parou antes do fim: {motivo}. A seguinte recomeça do mesmo arquivo.':
        'La última pasada se detuvo antes del final: {motivo}. La siguiente vuelve a empezar desde el mismo archivo.',
    'Como o painel envia':
        'Cómo envía el panel',
    'Os segredos ficam no servidor, na pasta <code>destinos</code> dos segredos da instalação, um por '
    'arquivo, e não entram na cópia de segurança: depois de restaurar uma cópia, grave-os de novo.':
        'Los secretos quedan en el servidor, en la carpeta <code>destinos</code> de los secretos de la '
        'instalación, uno por archivo, y no entran en la copia de seguridad: después de restaurar una copia, '
        'guárdelos de nuevo.',
    'Gravar':
        'Guardar',
    'Endereço do serviço':
        'Dirección del servicio',
    'só HTTPS, sem o bucket: <code>https://nome</code> ou <code>https://nome:porta</code>':
        'solo HTTPS, sin el bucket: <code>https://nombre</code> o <code>https://nombre:puerto</code>',
    'a que o serviço informa; onde não há, <code>us-east-1</code>':
        'la que el servicio informa; donde no hay, <code>us-east-1</code>',
    'Bucket':
        'Bucket',
    'já criado no serviço':
        'ya creado en el servicio',
    'Prefixo':
        'Prefijo',
    'pasta dentro do bucket; em branco grava na raiz dele':
        'carpeta dentro del bucket; en blanco guarda en su raíz',
    'Endereço do bucket':
        'Dirección del bucket',
    'Chave de acesso':
        'Clave de acceso',
    'Chave secreta':
        'Clave secreta',
    'Token do bot':
        'Token del bot',
    'Conversa que recebe':
        'Conversación que recibe',
    'Voltar para os destinos':
        'Volver a los destinos',
    'Remover <strong>{destino}</strong>? O painel apaga a configuração, o andamento e os segredos '
    'deste destino e para de enviar para ele. O que já foi enviado continua lá, e nenhum arquivo do '
    'servidor é apagado.':
        '¿Eliminar <strong>{destino}</strong>? El panel borra la configuración, el avance y los secretos de '
        'este destino y deja de enviarle. Lo que ya se envió sigue allí, y no se borra ningún archivo del servidor.',
    'Sim, remover o destino':
        'Sí, eliminar el destino',
    'À espera de outro destino':
        'A la espera de otro destino',
    'para gravar o destino':
        'para guardar el destino',
    'No caminho':
        'En la ruta',
    '<code>https://nome/bucket/arquivo</code>, o que a maioria dos serviços próprios usa':
        '<code>https://nombre/bucket/archivo</code>, lo que usa la mayoría de los servicios propios',
    'No nome':
        'En el nombre',
    '<code>https://bucket.nome/arquivo</code>, o que as nuvens grandes pedem':
        '<code>https://bucket.nombre/archivo</code>, lo que piden las nubes grandes',
    'Copiar':
        'Copiar',
    'o arquivo continua no servidor; o S3 é a segunda cópia':
        'el archivo sigue en el servidor; el S3 es la segunda copia',
    'Guardar no S3':
        'Conservar en S3',
    'o arquivo sai do servidor depois que o destino confirma a gravação':
        'el archivo sale del servidor después de que el destino confirma la escritura',
    'Não foi possível gravar o destino:':
        'No fue posible guardar el destino:',
    'para remover o destino':
        'para eliminar el destino',
    'Não foi possível remover o destino:':
        'No fue posible eliminar el destino:',
    'Arquivo maior que o limite de envio do bot ({limite}): não foi enviado por aqui.':
        'Archivo mayor que el límite de envío del bot ({limite}): no se envió por aquí.',
    'Teste do painel da allsafe-ftp-stack: o bot consegue enviar para esta conversa.':
        'Prueba del panel de la allsafe-ftp-stack: el bot consigue enviar a esta conversación.',
    'Novo S3':
        'Nuevo S3',
    'Novo bot':
        'Nuevo bot',
    'Novo com o mesmo acesso':
        'Nuevo con el mismo acceso',
    'novo destino':
        'nuevo destino',
    'Este tipo já tem os {n} destinos que o painel aceita: remova um antes de criar outro.':
        'Este tipo ya tiene los {n} destinos que el panel acepta: elimine uno antes de crear otro.',
    'Nome inválido: até 40 caracteres.':
        'Nombre no válido: hasta 40 caracteres.',
    'opcional, para reconhecer o destino na tela; até 40 caracteres':
        'opcional, para reconocer el destino en la pantalla; hasta 40 caracteres',
    'em branco usa o do destino de origem':
        'en blanco usa el del destino de origen',
    'Destino novo com o acesso de <strong>{origem}</strong>: o segredo deixado em branco é copiado dele, '
    'aqui no servidor. Troque a pasta ou o lugar: dois destinos não levam a mesma pasta ao mesmo lugar.':
        'Destino nuevo con el acceso de <strong>{origem}</strong>: el secreto dejado en blanco se copia de '
        'él, aquí en el servidor. Cambie la carpeta o el lugar: dos destinos no llevan la misma carpeta al '
        'mismo lugar.',
    'Este destino já existe: {outro} leva a mesma pasta, ou uma que a contém, ao mesmo lugar. '
    'Troque a pasta ou o lugar.':
        'Este destino ya existe: {outro} lleva la misma carpeta, o una que la contiene, al mismo lugar. '
        'Cambie la carpeta o el lugar.',
    'pasta enviada: {pasta}':
        'carpeta enviada: {pasta}',
    'Arquivo: <code>{arquivo}</code>. O arquivo continua no servidor e o andamento das passadas não muda.':
        'Archivo: <code>{arquivo}</code>. El archivo sigue en el servidor y el avance de las pasadas no cambia.',
    'Destino que recebe':
        'Destino que recibe',
    'Enviar':
        'Enviar',
    'Cópia do sistema gravada. A rotina vale a partir de agora.':
        'Copia del sistema guardada. La rutina vale a partir de ahora.',
    'Cópia do sistema pedida: ela é feita em segundo plano. Atualize a tela para acompanhar.':
        'Copia del sistema solicitada: se hace en segundo plano. Actualice la pantalla para seguirla.',
    'a cópia do sistema não tem um S3 escolhido com os segredos gravados':
        'la copia del sistema no tiene un S3 elegido con los secretos guardados',
    'falta a chave pública da cópia nesta instalação':
        'falta la clave pública de la copia en esta instalación',
    'a cifra da cópia falhou':
        'el cifrado de la copia falló',
    'os usuários estavam sendo alterados e a lista deles não pôde ser lida a tempo':
        'los usuarios se estaban modificando y su lista no pudo leerse a tiempo',
    'falta espaço em disco no servidor para montar uma parte da cópia':
        'falta espacio en disco en el servidor para montar una parte de la copia',
    'há pastas demais, uma dentro da outra, para o painel abrir':
        'hay demasiadas carpetas, una dentro de otra, para que el panel las abra',
    'erro de disco no servidor':
        'error de disco en el servidor',
    'erro interno do painel':
        'error interno del panel',
    'outra cópia do sistema está em andamento':
        'otra copia del sistema está en curso',
    'a cópia foi gravada no destino, mas o arquivo com a soma dela não: faça outra cópia':
        'la copia se guardó en el destino, pero el archivo con su suma no: haga otra copia',
    'Escolha um armazenamento S3 com os segredos gravados.':
        'Elija un almacenamiento S3 con los secretos guardados.',
    'Rotina inválida: de 0 a 30 dias.':
        'Rutina no válida: de 0 a 30 días.',
    'Hora inválida: use HH:MM, de 00:00 a 23:59.':
        'Hora no válida: use HH:MM, de 00:00 a 23:59.',
    'Cópia do sistema: não começou. Motivo: {motivo}.':
        'Copia del sistema: no empezó. Motivo: {motivo}.',
    'Este é o destino da cópia do sistema: sem ele, a cópia fica sem destino e a rotina dela para.':
        'Este es el destino de la copia del sistema: sin él, la copia queda sin destino y su rutina se detiene.',
    'só pelo botão ou pelo terminal':
        'solo por el botón o por el terminal',
    'todo dia, às {hora} (hora do servidor)':
        'todos los días, a las {hora} (hora del servidor)',
    'a cada {n} dia, às {hora} (hora do servidor)':
        'cada {n} día, a las {hora} (hora del servidor)',
    'a cada {n} dias, às {hora} (hora do servidor)':
        'cada {n} días, a las {hora} (hora del servidor)',
    'em andamento':
        'en curso',
    'não configurada':
        'no configurada',
    'rotina ligada':
        'rutina activada',
    'só pelo botão':
        'solo por el botón',
    'Cópia do sistema':
        'Copia del sistema',
    'O sistema inteiro em um arquivo só, cifrado, em um armazenamento S3: os usuários do FTP, os '
    'arquivos, os certificados e os dados do painel. É a mesma cópia que o '
    '<code>scripts/backup.sh</code> grava no servidor, e o <code>scripts/restaurar.sh</code> a abre '
    'com a chave privada da cópia. O painel só envia: as cópias se acumulam no bucket, e o prazo '
    'delas é da regra do bucket.':
        'El sistema entero en un solo archivo, cifrado, en un almacenamiento S3: los usuarios del FTP, los '
        'archivos, los certificados y los datos del panel. Es la misma copia que el '
        '<code>scripts/backup.sh</code> guarda en el servidor, y el <code>scripts/restaurar.sh</code> la '
        'abre con la clave privada de la copia. El panel solo envía: las copias se acumulan en el bucket, y '
        'su plazo es el de la regla del bucket.',
    'Falta a chave pública da cópia nesta instalação: rode <code>./deploy.sh</code>, que a cria, e volte aqui.':
        'Falta la clave pública de la copia en esta instalación: ejecute <code>./deploy.sh</code>, que la '
        'crea, y vuelva aquí.',
    'Grave primeiro um armazenamento S3, com os segredos: a cópia do sistema vai para um deles.':
        'Guarde primero un almacenamiento S3, con los secretos: la copia del sistema va a uno de ellos.',
    'A cópia anterior foi interrompida pelo reinício do painel: faça outra.':
        'La copia anterior fue interrumpida por el reinicio del panel: haga otra.',
    'A última cópia, de {quando}, não foi concluída: {motivo}.':
        'La última copia, de {quando}, no se concluyó: {motivo}.',
    '{n} arquivo mudou durante a leitura':
        '{n} archivo cambió durante la lectura',
    '{n} arquivos mudaram durante a leitura':
        '{n} archivos cambiaron durante la lectura',
    'cópia em andamento':
        'copia en curso',
    '{n} parte enviada':
        '{n} parte enviada',
    '{n} partes enviadas':
        '{n} partes enviadas',
    'Copiar e enviar agora':
        'Copiar y enviar ahora',
    'Destino':
        'Destino',
    'Bucket e pasta':
        'Bucket y carpeta',
    'Rotina':
        'Rutina',
    'Última cópia':
        'Última copia',
    'A cópia leva as pastas <code>auth</code>, <code>dados</code>, <code>certs</code> e '
    '<code>painel</code>, cifradas com a chave pública da cópia. O arquivo <code>.env</code> e os '
    'segredos da instalação não entram: guarde-os à parte, junto com a chave privada da cópia.':
        'La copia lleva las carpetas <code>auth</code>, <code>dados</code>, <code>certs</code> y '
        '<code>painel</code>, cifradas con la clave pública de la copia. El archivo <code>.env</code> y los '
        'secretos de la instalación no entran: guárdelos aparte, junto con la clave privada de la copia.',
    'Armazenamento S3 que recebe':
        'Almacenamiento S3 que recibe',
    'Pasta no bucket':
        'Carpeta en el bucket',
    'só para as cópias do sistema; em branco é a raiz do bucket':
        'solo para las copias del sistema; en blanco es la raíz del bucket',
    'de quantos em quantos dias, de 1 a 30; 0 é só pelo botão':
        'cada cuántos días, de 1 a 30; 0 es solo por el botón',
    'Hora da rotina':
        'Hora de la rutina',
    'hora do servidor':
        'hora del servidor',
    'A cópia é feita em segundo plano, com a prioridade mais baixa. Marque a rotina para a hora de '
    'menos uso: o tempo dela cresce com o tamanho dos dados.':
        'La copia se hace en segundo plano, con la prioridad más baja. Programe la rutina para la hora de '
        'menor uso: su duración crece con el tamaño de los datos.',
    'para gravar a cópia do sistema':
        'para guardar la copia del sistema',
    'Não foi possível gravar a cópia do sistema:':
        'No fue posible guardar la copia del sistema:',
    'Cópia do sistema para o S3 gravada':
        'Copia del sistema a S3 guardada',
    'Cópia do sistema pedida pela tela':
        'Copia del sistema solicitada desde la pantalla',
    'Cópia do sistema enviada para o S3':
        'Copia del sistema enviada a S3',
    'Cópia do sistema não concluída':
        'Copia del sistema no concluida',
    'Cópia do sistema ficou sem destino':
        'La copia del sistema quedó sin destino',
    'O remoto <strong>só recebe</strong>: o painel pede ao rclone que grave cada arquivo, e nada '
    'mais. Não lista, não baixa, não sincroniza e não apaga nada no remoto.':
        'El remoto <strong>solo recibe</strong>: el panel pide al rclone que escriba cada archivo, y nada '
        'más. No lista, no descarga, no sincroniza y no borra nada en el remoto.',
    'O token é obtido fora do painel, em um computador com navegador e com o rclone: o comando '
    '<code>rclone authorize {tipo}</code> abre a página da conta e imprime o token. O painel não abre '
    'essa página.':
        'El token se obtiene fuera del panel, en una computadora con navegador y con el rclone: el comando '
        '<code>rclone authorize {tipo}</code> abre la página de la cuenta e imprime el token. El panel no '
        'abre esa página.',
    'Remoto do rclone':
        'Remoto del rclone',
    'Novo remoto':
        'Nuevo remoto',
    'Depois de gravar, use <strong>Testar</strong> na lista dos destinos: o teste guarda a chave que '
    'o servidor apresentar e a ficha passa a mostrar a impressão digital dela, para conferir com a do '
    'servidor. Sem a chave guardada nada é enviado, e se ela mudar depois o envio para.':
        'Después de guardar, use <strong>Probar</strong> en la lista de los destinos: la prueba guarda la '
        'clave que el servidor presente y la ficha pasa a mostrar su huella digital, para compararla con la '
        'del servidor. Sin la clave guardada no se envía nada, y si cambia después el envío se detiene.',
    'O certificado do servidor é conferido. Informe o usuário com a senha, ou o token de acesso.':
        'El certificado del servidor se verifica. Indique el usuario con la contraseña, o el token de acceso.',
    'Informe o token da conta ou a credencial de uma conta de serviço.':
        'Indique el token de la cuenta o la credencial de una cuenta de servicio.',
    'A identificação e o tipo do drive são os que o rclone mostra ao configurar o remoto no mesmo '
    'computador em que o token foi obtido.':
        'La identificación y el tipo del drive son los que el rclone muestra al configurar el remoto en la '
        'misma computadora en que se obtuvo el token.',
    'o painel ainda não guardou a chave deste servidor: use Testar':
        'el panel todavía no guardó la clave de este servidor: use Probar',
    'a chave do servidor não é a que o painel guardou: confira o servidor e, se a troca for dele, '
    'grave o acesso de novo e teste':
        'la clave del servidor no es la que el panel guardó: revise el servidor y, si el cambio es del '
        'propio servidor, guarde el acceso de nuevo y pruebe',
    'a chave privada não abriu: confira a chave e a frase dela':
        'la clave privada no se abrió: revise la clave y su frase',
    'o remoto está sem espaço ou acima da cota':
        'el remoto está sin espacio o por encima de la cuota',
    'o rclone parou com um erro que o painel não reconhece':
        'el rclone se detuvo con un error que el panel no reconoce',
    'o rclone está ocupado com outro envio: tente de novo em instantes':
        'el rclone está ocupado con otro envío: inténtelo de nuevo en unos instantes',
    'A pasta no remoto começa pelo nome do bucket ou do contêiner, que já precisa existir: <code>bucket/pasta</code>.':
        'La carpeta en el remoto empieza por el nombre del bucket o del contenedor, que ya tiene que existir: '
        '<code>bucket/carpeta</code>.',
    'O envio só sai com TLS, e o certificado do servidor é conferido: servidor FTP sem TLS não serve de destino.':
        'El envío solo sale con TLS, y el certificado del servidor se verifica: un servidor FTP sin TLS no sirve de '
        'destino.',
    'O certificado do servidor é conferido. Conta com verificação em duas etapas só entra com o token de acesso.':
        'El certificado del servidor se verifica. Una cuenta con verificación en dos pasos solo entra con el token '
        'de acceso.',
    'Conta com verificação em duas etapas não serve de destino: o painel não tem como informar o código a cada envio.':
        'Una cuenta con verificación en dos pasos no sirve de destino: el panel no tiene cómo indicar el código en '
        'cada envío.',
    'A senha é uma senha de aplicativo, criada na conta para este uso, e não a senha de entrada.':
        'La contraseña es una contraseña de aplicación, creada en la cuenta para este uso, y no la contraseña de '
        'entrada.',
    'Informe a pasta no remoto: neste tipo ela é obrigatória e começa pelo nome do bucket ou do contêiner.':
        'Indique la carpeta en el remoto: en este tipo es obligatoria y empieza por el nombre del bucket o del '
        'contenedor.',
    'servidor FTP com TLS, com usuário e senha':
        'servidor FTP con TLS, con usuario y contraseña',
    'com usuário e senha':
        'con usuario y contraseña',
    'com o usuário e uma senha de aplicativo':
        'con el usuario y una contraseña de aplicación',
    'com a chave da API':
        'con la clave de la API',
    'com usuário, senha e chave da API':
        'con usuario, contraseña y clave de la API',
    'com a chave que o serviço dá ao rclone':
        'con la clave que el servicio da a rclone',
    'com o token de acesso':
        'con el token de acceso',
    'com usuário, senha e token':
        'con usuario, contraseña y token',
    'com a conta e a chave, ou com o endereço com assinatura':
        'con la cuenta y la clave, o con la dirección con firma',
    'com a conta e a chave':
        'con la cuenta y la clave',
    'com o endereço de autenticação, o usuário e a chave':
        'con la dirección de autenticación, el usuario y la clave',
    'com a chave de acesso e a chave secreta':
        'con la clave de acceso y la clave secreta',
    'com a concessão de acesso':
        'con la concesión de acceso',
    'com a chave da API, ou com usuário e senha':
        'con la clave de la API, o con usuario y contraseña',
    'com o token permanente':
        'con el token permanente',
    'Servidores de arquivos':
        'Servidores de archivos',
    'Nuvens de arquivos':
        'Nubes de archivos',
    'Armazenamento de provedores de nuvem':
        'Almacenamiento de proveedores de nube',
    'Transferência de arquivos para empresas':
        'Transferencia de archivos para empresas',
    'em branco é a 21':
        'en blanco es el 21',
    'Tipo de TLS':
        'Tipo de TLS',
    'só HTTPS: <code>https://nome</code>':
        'solo HTTPS: <code>https://nombre</code>',
    'no lugar da senha':
        'en lugar de la contraseña',
    'Biblioteca':
        'Biblioteca',
    'o nome dela, já criada no servidor':
        'su nombre, ya creada en el servidor',
    'Senha da biblioteca':
        'Contraseña de la biblioteca',
    'só quando a biblioteca é cifrada':
        'solo cuando la biblioteca está cifrada',
    'Tipo da conta':
        'Tipo de la cuenta',
    'E-mail da conta':
        'Correo de la cuenta',
    'Senha da caixa de correio':
        'Contraseña del buzón',
    'só na conta que tem duas senhas':
        'solo en la cuenta que tiene dos contraseñas',
    'Serviço':
        'Servicio',
    'só com o serviço Outro, e só HTTPS: <code>https://nome</code>':
        'solo con el servicio Otro, y solo HTTPS: <code>https://nombre</code>',
    'só HTTPS; em branco é o do próprio serviço':
        'solo HTTPS; en blanco es la del propio servicio',
    'o da conta, só HTTPS: <code>https://nome.sf-api.com</code>':
        'la de la cuenta, solo HTTPS: <code>https://nombre.sf-api.com</code>',
    'Chave da API':
        'Clave de la API',
    'Chave':
        'Clave',
    'Chave do rclone':
        'Clave de rclone',
    'a que o serviço mostra na conta':
        'la que el servicio muestra en la cuenta',
    'Token do aplicativo':
        'Token de la aplicación',
    'Conta':
        'Cuenta',
    'Endereço com assinatura (SAS)':
        'Dirección con firma (SAS)',
    'no lugar da conta e da chave':
        'en lugar de la cuenta y de la clave',
    'Compartilhamento':
        'Recurso compartido',
    'o nome dele, já criado na conta':
        'su nombre, ya creado en la cuenta',
    'Identificação da conta ou da chave':
        'Identificación de la cuenta o de la clave',
    'Chave de aplicação':
        'Clave de aplicación',
    'Bucket com acesso uniforme':
        'Bucket con acceso uniforme',
    'Endereço de autenticação':
        'Dirección de autenticación',
    'só HTTPS: <code>https://nome:porta/v3</code>':
        'solo HTTPS: <code>https://nombre:puerto/v3</code>',
    'Versão da autenticação':
        'Versión de la autenticación',
    'Senha ou chave':
        'Contraseña o clave',
    'Domínio do usuário':
        'Dominio del usuario',
    'só na versão 3':
        'solo en la versión 3',
    'Projeto':
        'Proyecto',
    'Domínio do projeto':
        'Dominio del proyecto',
    'só quando o serviço tem mais de uma':
        'solo cuando el servicio tiene más de una',
    'Zona':
        'Zona',
    'a do bucket; em branco é a do próprio serviço':
        'la del bucket; en blanco es la del propio servicio',
    'Concessão de acesso':
        'Concesión de acceso',
    'o nome e a pasta de partida: <code>nome/pasta</code>':
        'el nombre y la carpeta de partida: <code>nombre/carpeta</code>',
    'Site':
        'Sitio',
    'o nome da conta no serviço ou o domínio próprio, sem <code>https://</code>':
        'el nombre de la cuenta en el servicio o el dominio propio, sin <code>https://</code>',
    'o nome da conta no serviço, sem <code>https://</code>':
        'el nombre de la cuenta en el servicio, sin <code>https://</code>',
    'Token permanente':
        'Token permanente',
    'obrigatória; começa pelo nome do bucket ou do contêiner':
        'obligatoria; empieza por el nombre del bucket o del contenedor',
    'Explícito':
        'Explícito',
    'o comum, na porta 21':
        'el habitual, en el puerto 21',
    'Implícito':
        'Implícito',
    'em geral na porta 990':
        'en general en el puerto 990',
    'com o endereço do serviço':
        'con la dirección del servicio',
    'Índia':
        'India',
    'Japão':
        'Japón',
    'Austrália':
        'Australia',
    'Sim':
        'Sí',
    'Não':
        'No',
    'Favoritos':
        'Favoritos',
    'Compartilhadas comigo':
        'Compartidas conmigo',
    'Conectores':
        'Conectores',
    'Todas as pastas':
        'Todas las carpetas',
    'Escolha na lista':
        'Elija en la lista',
    'Serviço compatível com S3 não está nesta lista: para ele, use o destino S3.':
        'Un servicio compatible con S3 no está en esta lista: para él, use el destino S3.',
    'Acesso com campos a mais: informe uma forma de acesso só, e deixe em branco os campos da outra.':
        'Acceso con campos de más: indique una sola forma de acceso, y deje en blanco los campos de la otra.',
    'Escolha o tipo do remoto.':
        'Elija el tipo del remoto.',
    'Pasta no remoto inválida: até 16 níveis separados por barra, com letras, números, espaço, _, - e ponto.':
        'Carpeta en el remoto no válida: hasta 16 niveles separados por barra, con letras, números, espacio, '
        '_, - y punto.',
    'Cópia automática dos arquivos para fora do servidor: armazenamentos S3, remotos do rclone e bots do Telegram.':
        'Copia automática de los archivos fuera del servidor: almacenamientos S3, remotos del rclone y bots '
        'de Telegram.',
    'Enviar este arquivo para o remoto do rclone':
        'Enviar este archivo al remoto del rclone',
    'Acesso do remoto':
        'Acceso del remoto',
    'gravado; não aparece na tela':
        'guardado; no aparece en la pantalla',
    'servidor com acesso por SSH, com senha ou chave privada':
        'servidor con acceso por SSH, con contraseña o clave privada',
    'servidor de arquivos por HTTPS, com usuário e senha ou com token':
        'servidor de archivos por HTTPS, con usuario y contraseña o con token',
    'com o token da conta ou a credencial de uma conta de serviço':
        'con el token de la cuenta o la credencial de una cuenta de servicio',
    'com o token da conta e a identificação do drive':
        'con el token de la cuenta y la identificación del drive',
    'com o token da conta':
        'con el token de la cuenta',
    'nome ou endereço IP, sem a porta':
        'nombre o dirección IP, sin el puerto',
    'Porta':
        'Puerto',
    'em branco é a 22':
        'en blanco es el 22',
    'Chave privada':
        'Clave privada',
    'o arquivo inteiro, da linha BEGIN à linha END; no lugar da senha':
        'el archivo entero, de la línea BEGIN a la línea END; en lugar de la contraseña',
    'Frase da chave privada':
        'Frase de la clave privada',
    'só quando a chave é cifrada':
        'solo cuando la clave está cifrada',
    'Chave pública do servidor':
        'Clave pública del servidor',
    'uma por linha, como no arquivo de servidores conhecidos do SSH; em branco, o Testar guarda a que '
    'o servidor apresentar':
        'una por línea, como en el archivo de servidores conocidos de SSH; en blanco, el Probar guarda la '
        'que el servidor presente',
    'só HTTPS, com o caminho que o servidor pede: <code>https://nome/caminho</code>':
        'solo HTTPS, con la ruta que el servidor pide: <code>https://nombre/ruta</code>',
    'Programa do servidor':
        'Programa del servidor',
    'Token de acesso':
        'Token de acceso',
    'no lugar do usuário e da senha':
        'en lugar del usuario y de la contraseña',
    'Identificação do aplicativo':
        'Identificación de la aplicación',
    'em branco usa a do rclone':
        'en blanco usa la del rclone',
    'Segredo do aplicativo':
        'Secreto de la aplicación',
    'só com a identificação do aplicativo':
        'solo con la identificación de la aplicación',
    'Alcance':
        'Alcance',
    'Token da conta':
        'Token de la cuenta',
    'o texto entre chaves que o comando <code>rclone authorize</code> imprime':
        'el texto entre llaves que imprime el comando <code>rclone authorize</code>',
    'Credencial da conta de serviço':
        'Credencial de la cuenta de servicio',
    'o conteúdo do arquivo da conta; no lugar do token':
        'el contenido del archivo de la cuenta; en lugar del token',
    'Pasta de partida':
        'Carpeta de partida',
    'a identificação da pasta; em branco é a raiz da conta':
        'la identificación de la carpeta; en blanco es la raíz de la cuenta',
    'Drive compartilhado':
        'Drive compartido',
    'a identificação do drive':
        'la identificación del drive',
    'Identificação do drive':
        'Identificación del drive',
    'Tipo do drive':
        'Tipo del drive',
    'Organização':
        'Organización',
    'o domínio ou a identificação dela':
        'su dominio o su identificación',
    'Região da conta':
        'Región de la cuenta',
    'a pasta em que o remoto entra':
        'la carpeta en la que entra el remoto',
    'Deixe os campos do acesso em branco para usar o do destino de origem; para usar outro, preencha '
    'o acesso inteiro.':
        'Deje los campos del acceso en blanco para usar el del destino de origen; para usar otro, complete '
        'el acceso entero.',
    'Outro':
        'Otro',
    'qualquer servidor WebDAV':
        'cualquier servidor WebDAV',
    'com entrada por NTLM':
        'con entrada por NTLM',
    'Toda a conta':
        'Toda la cuenta',
    'Só os arquivos que o rclone criou':
        'Solo los archivos que el rclone creó',
    'Pessoal':
        'Personal',
    'Empresarial':
        'Empresarial',
    'Biblioteca de documentos':
        'Biblioteca de documentos',
    'Global':
        'Global',
    'Governo dos Estados Unidos':
        'Gobierno de los Estados Unidos',
    'Alemanha':
        'Alemania',
    'China':
        'China',
    'Estados Unidos':
        'Estados Unidos',
    'Europa':
        'Europa',
    'Tipo do remoto':
        'Tipo del remoto',
    'Pasta no remoto':
        'Carpeta en el remoto',
    'Envia os arquivos de uma pasta, pelo rclone, para o que o S3 não alcança: um servidor SFTP ou '
    'WebDAV, ou uma nuvem de arquivos. O remoto só recebe: o painel não lista, não baixa e não apaga '
    'nada nele.':
        'Envía los archivos de una carpeta, por el rclone, a lo que el S3 no alcanza: un servidor SFTP o '
        'WebDAV, o una nube de archivos. El remoto solo recibe: el panel no lista, no descarga y no borra nada en él.',
    'O acesso gravado não aparece aqui. Deixe os campos abaixo em branco para mantê-lo; para trocar '
    'qualquer parte dele, preencha o acesso inteiro de novo.':
        'El acceso guardado no aparece aquí. Deje los campos de abajo en blanco para mantenerlo; para '
        'cambiar cualquier parte de él, complete el acceso entero de nuevo.',
    'Depois de gravado, o acesso não volta para a tela.':
        'Después de guardado, el acceso no vuelve a la pantalla.',
    'Preencha o acesso do remoto: não há nenhum gravado para manter.':
        'Complete el acceso del remoto: no hay ninguno guardado para mantener.',
    'falta testar':
        'falta probar',
    'Chave do servidor':
        'Clave del servidor',
    'O arquivo vai para a pasta do remoto com o mesmo caminho que tem dentro dos dados, e grava por '
    'cima do que tiver o mesmo nome. O arquivo continua no servidor. Trocar a pasta no remoto, a '
    'pasta enviada ou o lugar do acesso recomeça do zero: tudo o que está na pasta é enviado de novo.':
        'El archivo va a la carpeta del remoto con la misma ruta que tiene dentro de los datos, y se escribe '
        'encima de lo que tenga el mismo nombre. El archivo sigue en el servidor. Cambiar la carpeta en el '
        'remoto, la carpeta enviada o el lugar del acceso vuelve a empezar de cero: todo lo que está en la '
        'carpeta se envía de nuevo.',
    '{campo}: em branco ou fora do formato.':
        '{campo}: en blanco o fuera del formato.',
    'O rclone não cifrou a senha: {motivo}.':
        'El rclone no cifró la contraseña: {motivo}.',
    'O painel ainda não guardou a chave deste servidor. Use <strong>Testar</strong>: o teste guarda a '
    'chave que o servidor apresentar e a ficha passa a mostrar a impressão digital dela, para '
    'conferir com a do servidor. Até lá, nada é enviado.':
        'El panel todavía no guardó la clave de este servidor. Use <strong>Probar</strong>: la prueba guarda '
        'la clave que el servidor presente y la ficha pasa a mostrar su huella digital, para compararla con '
        'la del servidor. Hasta entonces, no se envía nada.',
    'Não informar':
        'No indicar',
    'vale o padrão do rclone':
        'vale el valor predeterminado del rclone',
    'O tipo fica fixo depois de gravado: para outro tipo, crie outro destino.':
        'El tipo queda fijo después de guardado: para otro tipo, cree otro destino.',
    'Continuar':
        'Continuar',
    'onde os arquivos são gravados; em branco é a pasta em que o remoto entra':
        'donde se guardan los archivos; en blanco es la carpeta en la que entra el remoto',
    'Acesso incompleto: informe a senha, a chave privada, o token ou a credencial com que o remoto é '
    'aberto. O acesso inteiro cabe em 16 KiB.':
        'Acceso incompleto: indique la contraseña, la clave privada, el token o la credencial con que se '
        'abre el remoto. El acceso entero cabe en 16 KiB.',
    'A frase vale só para chave privada cifrada: a chave cifrada pede a frase, e a chave sem cifra não leva frase.':
        'La frase vale solo para clave privada cifrada: la clave cifrada pide la frase, y la clave sin '
        'cifrar no lleva frase.',
    'Não trocar':
        'No cambiar',
    'com os outros campos em branco, mantém o acesso gravado':
        'con los otros campos en blanco, mantiene el acceso guardado',
    'O painel só sai do servidor para os destinos gravados aqui, por HTTPS com o certificado '
    'conferido ou, no remoto SFTP do rclone, por SSH com a chave do servidor conferida. Sai arquivo '
    'comum: link simbólico e nome começado por ponto ficam de fora. O bot do Telegram envia em '
    'instantes o arquivo que chega inteiro por FTP ou pelo painel; nos outros casos, e sempre no S3 e '
    'no rclone, o arquivo só entra na passada depois de dois minutos sem mudar, para o que ainda está '
    'chegando não sair pela metade. A ordem é a da chegada ao servidor; uma falha do destino encerra '
    'a passada e a seguinte recomeça do mesmo arquivo. Pasta que troca de nome não reenvia os '
    'arquivos de dentro.':
        'El panel solo sale del servidor hacia los destinos guardados aquí, por HTTPS con el certificado '
        'verificado o, en el remoto SFTP del rclone, por SSH con la clave del servidor verificada. Sale el '
        'archivo común: el enlace simbólico y el nombre empezado por punto quedan fuera. El bot de Telegram '
        'envía en instantes el archivo que llega entero por FTP o por el panel; en los demás casos, y '
        'siempre en el S3 y en el rclone, el archivo solo entra en la pasada después de dos minutos sin '
        'cambiar, para que lo que todavía está llegando no salga a medias. El orden es el de la llegada al '
        'servidor; un fallo del destino cierra la pasada y la siguiente vuelve a empezar desde el mismo '
        'archivo. La carpeta que cambia de nombre no reenvía los archivos de dentro.',
    'Código do segundo fator recusado':
        'Código del segundo factor rechazado',
    'Entrada recusada: segundo fator ligado sem o segredo no servidor':
        'Entrada rechazada: segundo factor activado sin el secreto en el servidor',
    'Segundo fator ligado':
        'Segundo factor activado',
    'Segundo fator desligado':
        'Segundo factor desactivado',
    'Segundo fator desligado pelo terminal':
        'Segundo factor desactivado por el terminal',
    'Segundo fator':
        'Segundo factor',
    'Código QR do segundo fator':
        'Código QR del segundo factor',
    'A sua conta volta a entrar só com usuário e senha.':
        'Su cuenta vuelve a entrar solo con usuario y contraseña.',
    'A conta <strong>{nome}</strong> volta a entrar só com usuário e senha. É o caminho de quem '
    'perdeu o aparelho: depois de entrar, ele liga de novo, com uma chave nova.':
        'La cuenta <strong>{nome}</strong> vuelve a entrar solo con usuario y contraseña. Es el camino de '
        'quien perdió el dispositivo: después de entrar, lo activa de nuevo, con una clave nueva.',
    'A chave mostrada venceu. Leia a nova no aplicativo e tente de novo.':
        'La clave mostrada venció. Lea la nueva en la aplicación e inténtelo de nuevo.',
    'O código não confere com a chave desta tela. Confira a hora do celular, espere o próximo código '
    'e tente de novo.':
        'El código no coincide con la clave de esta pantalla. Revise la hora del celular, espere el próximo '
        'código e inténtelo de nuevo.',
    'Ligar o segundo fator':
        'Activar el segundo factor',
    'Depois de ligado, o painel pede, além da sua senha, o código de seis dígitos de um aplicativo '
    'autenticador. Vale só para a entrada neste painel: o FTP não muda.':
        'Una vez activado, el panel pide, además de su contraseña, el código de seis dígitos de una '
        'aplicación autenticadora. Vale solo para la entrada en este panel: el FTP no cambia.',
    'Abra o aplicativo autenticador no celular e leia o código abaixo.':
        'Abra la aplicación autenticadora en el celular y lea el código de abajo.',
    'Sem câmera: escolha digitar a chave no aplicativo, do tipo baseado em tempo, e copie esta.':
        'Sin cámara: elija escribir la clave en la aplicación, del tipo basado en tiempo, y copie esta.',
    'Digite o código que o aplicativo mostrar e confirme com a sua senha.':
        'Escriba el código que muestre la aplicación y confirme con su contraseña.',
    'Esta chave <strong>não será mostrada de novo</strong>. Quem a tiver gera os seus códigos: não a '
    'guarde em foto nem em mensagem.':
        'Esta clave <strong>no se mostrará de nuevo</strong>. Quien la tenga genera sus códigos: no la '
        'guarde en foto ni en mensaje.',
    'Código do aplicativo':
        'Código de la aplicación',
    'Desligar o segundo fator':
        'Desactivar el segundo factor',
    'A chave guardada é apagada: os códigos do aplicativo deixam de valer.':
        'La clave guardada se borra: los códigos de la aplicación dejan de valer.',
    'Sim, desligar o segundo fator':
        'Sí, desactivar el segundo factor',
    'O segundo fator de <strong>{nome}</strong> está desligado. Só o próprio administrador liga o '
    'dele, porque a chave fica no aparelho de quem entra.':
        'El segundo factor de <strong>{nome}</strong> está desactivado. Solo el propio administrador activa '
        'el suyo, porque la clave queda en el dispositivo de quien entra.',
    'Não foi possível gravar o segundo fator:':
        'No fue posible guardar el segundo factor:',
    '<strong>Ligado sem o segredo no servidor: {nomes}.</strong> Essas contas não entram até o '
    'segundo fator ser desligado, em <a href="/usuarios">Usuários</a> ou pelo terminal; depois, cada '
    'uma liga de novo.':
        '<strong>Activado sin el secreto en el servidor: {nomes}.</strong> Esas cuentas no entran hasta que '
        'el segundo factor se desactive, en <a href="/usuarios">Usuarios</a> o por el terminal; después, '
        'cada una lo activa de nuevo.',
    'Todos os administradores entram com a senha e o código de um aplicativo autenticador. Vale só '
    'para este painel: o FTP não muda.':
        'Todos los administradores entran con la contraseña y el código de una aplicación autenticadora. '
        'Vale solo para este panel: el FTP no cambia.',
    'Segundo fator dos administradores':
        'Segundo factor de los administradores',
    'Entram só com a senha: {nomes}. Cada administrador liga o dele em <a '
    'href="/usuarios">Usuários</a>, com um aplicativo autenticador.':
        'Entran solo con la contraseña: {nomes}. Cada administrador activa el suyo en <a '
        'href="/usuarios">Usuarios</a>, con una aplicación autenticadora.',
    '<strong>Este painel é alcançado de fora da rede privada:</strong> ligue o de todos.':
        '<strong>Este panel es alcanzado desde fuera de la red privada:</strong> active el de todos.',
    'Segundo fator ligado. A próxima entrada desta conta pede o código do aplicativo; as outras '
    'sessões dela foram encerradas.':
        'Segundo factor activado. La próxima entrada de esta cuenta pide el código de la aplicación; sus '
        'otras sesiones se cerraron.',
    'Segundo fator desligado. A conta volta a entrar só com usuário e senha.':
        'Segundo factor desactivado. La cuenta vuelve a entrar solo con usuario y contraseña.',
    'segundo fator ligado':
        'segundo factor activado',
    'sem segundo fator':
        'sin segundo factor',
    'Código de verificação':
        'Código de verificación',
    'O código não confere. Espere o aplicativo mostrar o próximo e tente de novo.':
        'El código no coincide. Espere a que la aplicación muestre el próximo e inténtelo de nuevo.',
    'A senha conferiu. Digite o código de seis dígitos que o aplicativo autenticador mostra para esta conta.':
        'La contraseña coincidió. Escriba el código de seis dígitos que la aplicación autenticadora muestra '
        'para esta cuenta.',
    'Código':
        'Código',
    'Confirmar':
        'Confirmar',
    'Sem o aparelho: outro administrador desliga o segundo fator da sua conta, na aba Usuários, ou '
    'quem tem acesso ao servidor desliga pelo terminal.':
        'Sin el dispositivo: otro administrador desactiva el segundo factor de su cuenta, en la pestaña '
        'Usuarios, o quien tiene acceso al servidor lo desactiva por el terminal.',
    'Voltar para usuário e senha':
        'Volver a usuario y contraseña',
    'Senha aceita, à espera do segundo fator':
        'Contraseña aceptada, a la espera del segundo factor',
    'Segundo fator cadastrado na entrada':
        'Segundo factor registrado en el inicio de sesión',
    'Segundo fator de usuário do FTP desligado':
        'Segundo factor de un usuario del FTP desactivado',
    'Na sua próxima entrada, o painel pede o cadastro de um aplicativo de novo, com uma chave nova.':
        'En su próximo inicio de sesión, el panel pide registrar una aplicación de nuevo, con una '
        'clave nueva.',
    'Na próxima entrada, a conta <strong>{nome}</strong> cadastra um aplicativo de novo, com uma '
    'chave nova. É o caminho de quem perdeu ou trocou o aparelho.':
        'En el próximo inicio de sesión, la cuenta <strong>{nome}</strong> registra una aplicación '
        'de nuevo, con una clave nueva. Es el camino de quien perdió o cambió el dispositivo.',
    'A conta <strong>{nome}</strong> volta a entrar no painel só com usuário e senha.':
        'La cuenta <strong>{nome}</strong> vuelve a entrar en el panel solo con usuario y '
        'contraseña.',
    'Aparelho perdido ou roubado: troque também a senha da conta. Até o cadastro novo, quem souber '
    'a senha cadastra o aplicativo.':
        'Dispositivo perdido o robado: cambie también la contraseña de la cuenta. Hasta el '
        'registro nuevo, quien sepa la contraseña registra la aplicación.',
    'Obrigatório (<code>PAINEL_SEGUNDO_FATOR_OBRIGATORIO=sim</code>): toda conta que entra neste '
    'painel, administrador ou usuário do FTP, passa pela senha e pelo código de um aplicativo '
    'autenticador; quem ainda não cadastrou cadastra na entrada. Vale só para este painel: o FTP '
    'não muda.':
        'Obligatorio (<code>PAINEL_SEGUNDO_FATOR_OBRIGATORIO=sim</code>): toda cuenta que entra en '
        'este panel, administrador o usuario del FTP, pasa por la contraseña y por el código de '
        'una aplicación de autenticación; quien todavía no la registró la registra en el inicio de '
        'sesión. Vale solo para este panel: el FTP no cambia.',
    'Administradores que ainda não cadastraram: {nomes}. Até lá, quem souber a senha da conta faz '
    'o cadastro.':
        'Administradores que todavía no lo registraron: {nomes}. Hasta entonces, quien sepa la '
        'contraseña de la cuenta hace el registro.',
    'Segundo fator desligado. Na próxima entrada, a conta cadastra um aplicativo de novo.':
        'Segundo factor desactivado. En el próximo inicio de sesión, la cuenta registra una '
        'aplicación de nuevo.',
    'cadastra o segundo fator na próxima entrada':
        'registra el segundo factor en el próximo inicio de sesión',
    'Sem o aparelho: peça ao administrador para desligar o segundo fator da sua conta.':
        'Sin el dispositivo: pida al administrador que desactive el segundo factor de su cuenta.',
    'Na entrada seguinte, o painel pede o cadastro de um aplicativo de novo.':
        'En el inicio de sesión siguiente, el panel pide registrar una aplicación de nuevo.',
    'Cadastre o segundo fator':
        'Registre el segundo factor',
    'A senha conferiu. Este painel exige, além da senha, o código de seis dígitos de um aplicativo '
    'autenticador. Cadastre o seu agora para entrar; vale só para este painel, o FTP não muda.':
        'La contraseña es correcta. Este panel exige, además de la contraseña, el código de seis '
        'dígitos de una aplicación de autenticación. Registre la suya ahora para entrar; vale solo '
        'para este panel, el FTP no cambia.',
    'Digite o código que o aplicativo mostrar.':
        'Escriba el código que muestre la aplicación.',
    'Cadastrar e entrar':
        'Registrar y entrar',
    'O segundo fator desta conta está ligado, mas o segredo dele não está no servidor. Um '
    'administrador ou quem tem acesso ao servidor precisa desligá-lo.':
        'El segundo factor de esta cuenta está activado, pero su secreto no está en el servidor. '
        'Un administrador o quien tiene acceso al servidor necesita desactivarlo.',
}

# Mensagem de erro do allsafe-ftp-user (ftp/usuario.sh), que fala português sem acento: a expressão que a
# reconhece inteira, a mesma do catálogo do inglês, e o modelo em espanhol, com os trechos variáveis nos lugares
# de \1, \2 e \3.
COMANDO = tuple((re.compile(regra), espanhol) for regra, espanhol in (
    (r'Perfil invalido: use completo, envio, soenvio ou leitura',
     r'Perfil no válido: use completo, envio, soenvio o leitura'),
    (r'Pasta invalida: ate 4 niveis separados por /; letras, numeros, _ - e ponto; nenhum nivel comeca com ponto',
     r'Carpeta no válida: hasta 4 niveles separados por /; letras, números, _ - y punto; ningún nivel empieza con '
     r'punto'),
    (r'Outra alteracao de usuario em andamento; tente de novo',
     r'Otro cambio de usuario en curso; inténtelo de nuevo'),
    (r'Pasta recusada: (.+) e link simbolico', r'Carpeta rechazada: \1 es un enlace simbólico'),
    (r'Pasta recusada: (.+) existe e nao e pasta', r'Carpeta rechazada: \1 existe y no es una carpeta'),
    (r'Limite invalido: (\S+) aceita vazio ou um inteiro de (\d+) a (\d+)',
     r'Límite no válido: \1 acepta vacío o un entero de \2 a \3'),
    (r'Limite invalido: enviar aceita vazio ou 1', r'Límite no válido: enviar acepta vacío o 1'),
    (r'Limite invalido: horario aceita vazio ou HHMM-HHMM, com inicio diferente do fim',
     r'Límite no válido: horario acepta vacío o HHMM-HHMM, con el inicio distinto del fin'),
    (r'Endereco invalido: use um IPv4, um IPv6 ou um prefixo, como 203\.0\.113\.7, 2001:db8::7 ou 203\.0\.113\.0/24',
     r'Dirección no válida: use un IPv4, un IPv6 o un prefijo, como 203.0.113.7, 2001:db8::7 o 203.0.113.0/24'),
    (r'Area de entrada recusada: (.+) passa por link simbolico',
     r'Área de entrada rechazada: \1 pasa por un enlace simbólico'),
    (r'Area de entrada recusada: (.+) existe e nao e pasta',
     r'Área de entrada rechazada: \1 existe y no es una carpeta'),
    (r'FTP_MAX_CLIENTS deve ser um inteiro maior que zero', r'FTP_MAX_CLIENTS debe ser un entero mayor que cero'),
    (r'Senha deve ter pelo menos 12 caracteres', r'La contraseña debe tener al menos 12 caracteres'),
    (r'Usuario ja existe: (.+)', r'El usuario ya existe: \1'),
    (r'Usuario nao existe: (.+)', r'El usuario no existe: \1'),
    (r'Origem invalida: use o endereco IP que aparece em bloqueios',
     r'Origen no válido: use la dirección IP que aparece en bloqueios'),
    (r'Endereco nao bloqueavel: (.+) e do proprio servidor', r'Dirección no bloqueable: \1 es del propio servidor'),
    (r'Prazo invalido: de 1 a 3650 dias', r'Plazo no válido: de 1 a 3650 días'),
    (r'Pasta dos bloqueios por endereco ausente: reinicie o servico ftp',
     r'Falta la carpeta de los bloqueos por dirección: reinicie el servicio ftp'),
    (r'Teto de (\d+) enderecos bloqueados: libere algum antes',
     r'Tope de \1 direcciones bloqueadas: libere alguna antes'),
    (r'Teto de (\d+) prefixos bloqueados: libere algum antes', r'Tope de \1 prefijos bloqueados: libere alguno antes'),
))
