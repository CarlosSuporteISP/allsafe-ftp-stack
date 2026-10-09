# 📸 Fotos da aplicação — allsafe-ftp-stack

↩ [README do projeto](../../README.md) · [Índice da documentação](../README.md)

## 💡 Em poucas palavras

Todas as telas do painel web, menu por menu, com a foto de cada uma e a explicação do que dá para fazer nela. As fotos são capturas reais da versão **0.24.2**, em tema escuro (o único do painel), com usuários de exemplo, como `olt-centro`, `switch-core` e `roteador-borda`. Clique em qualquer foto para abri-la em tamanho real.

O painel tem uma tela de entrada, seis abas para quem administra (Visão geral, Usuários, Arquivos, Administradores, Segurança e Atividade) e uma tela para o usuário do FTP baixar os próprios backups (Meus arquivos). Como abrir, criar administradores e o que protege o painel está em [Painel web](../painel.md).

> 🧱 **Uso só em rede privada:** por padrão, o painel abre apenas em IP privado, atrás de firewall, fora da internet. Veja [Segurança](../seguranca.md#rede-privada).

<details>
<summary>Sumário — clique para expandir</summary>

[Entrar](#entrar) · [Visão geral](#visao-geral) · [Usuários](#usuarios) · [Arquivos](#arquivos) · [Meus arquivos](#meus-arquivos) · [Administradores](#administradores) · [Segurança](#seguranca) · [Atividade](#atividade) · [Como as fotos foram feitas](#como-foram-feitas)

</details>

---

<a name="entrar"></a>

## 🚪 Entrar

<a href="imagens/entrar.png"><img src="imagens/entrar.png" alt="Tela de entrada do painel, com a logo, os campos Usuário e Senha, o botão Entrar e o aviso de uso só em rede privada" width="100%"></a>

<sub><b>v0.24.2</b> · tela de entrada · captura de 2026-10-09</sub>

**Para que serve:** conferir o usuário e a senha antes de mostrar qualquer dado da stack. É a mesma tela para quem administra e para o usuário do FTP.

**Como chegar:** abra `https://<endereço do painel>:8443` no navegador. Sem sessão, qualquer endereço do painel leva a esta tela.

| Item da tela | O que faz |
|---|---|
| **Usuário** | Recebe o nome do administrador ou o nome do usuário do FTP. Na primeira instalação, o administrador é o de `PAINEL_ADMIN_USER` (`admin`, se não foi trocado) |
| **Senha** | Recebe a senha da conta. A do primeiro administrador está em `.secrets/painel-admin-inicial-senha.txt`; a do usuário do FTP é a mesma que o equipamento usa |
| **Entrar** | Confere a conta: o administrador vai para a aba Visão geral e o usuário do FTP, para a tela Meus arquivos |
| Texto abaixo do título | Diz quem entra por esta tela. Com `PAINEL_ACESSO_USUARIOS_FTP=nao`, passa a ser `Painel de administração da stack.` |
| Aviso de rede privada | Lembra que o painel é só para rede interna, atrás de firewall; com `REDE_PERMITIR_IP_PUBLICO=sim`, vira o alerta de endereço público aceito |

<details>
<summary>Entrar ➜ Entrada recusada — clique para expandir</summary>

### Entrar ➜ Entrada recusada

<a href="imagens/entrar-recusada.png"><img src="imagens/entrar-recusada.png" alt="Tela de entrada com a mensagem Não foi possível entrar acima dos campos Usuário e Senha" width="100%"></a>

<sub><b>v0.24.2</b> · tela de entrada, entrada recusada · captura de 2026-10-09</sub>

| Mensagem | Quando aparece | O que fazer |
|---|---|---|
| Não foi possível entrar. | O usuário ou a senha estão errados; a tela não diz qual dos dois | Conferir os dois campos e tentar de novo |
| Muitas tentativas. Aguarde alguns minutos e tente de novo. | Cinco entradas erradas do mesmo endereço em 15 minutos | Esperar o bloqueio passar; a conta certa também é recusada enquanto ele dura |
| A página expirou. Tente de novo. | A tela ficou aberta tempo demais antes do envio | Enviar de novo |

</details>

<details>
<summary>Detalhe técnico — entrada e sessão</summary>

- Rota `GET /entrar` mostra o formulário; `POST /entrar` confere primeiro a conta de administrador, pelo hash `scrypt` de `DATA_DIR/painel/administradores`, e depois, se a entrada dos usuários do FTP estiver ligada, a conta do FTP, por um login no próprio servidor FTP.
- Resposta `401` para usuário ou senha errados, `429` para endereço bloqueado e `400` para formulário expirado. Cada caso grava `entrada_falha` ou `entrada_bloqueada` na [auditoria](../painel.md#auditoria), sem o nome digitado.
- A entrada com a conta do FTP leva alguns segundos: é o tempo que o servidor FTP gasta para conferir a senha. Veja [Usuário do FTP no painel](../painel.md#usuario-ftp).
- A sessão fica no cookie `__Host-sessao` (`Secure`, `HttpOnly`, `SameSite=Strict`) e encerra com 15 minutos sem uso ou em 8 horas.
- O envio só é aceito quando parte do próprio painel: o cabeçalho `Origin` tem de ser o endereço do painel. Detalhes em [Painel web](../painel.md#protecoes).

</details>

---

<a name="visao-geral"></a>

## 📊 Visão geral

<a href="imagens/visao-geral.png"><img src="imagens/visao-geral.png" alt="Aba Visão geral com os cartões Servidor FTP, Usuários, Espaço usado, Último envio e Certificado do FTP, cada um com o atalho para o detalhe, e os dados para configurar o equipamento" width="100%"></a>

<sub><b>v0.24.2</b> · menu Visão geral · captura de 2026-10-09</sub>

**Para que serve:** ver de uma vez se o FTP está no ar e quais dados digitar no equipamento que vai mandar o backup.

**Como chegar:** é a primeira tela do administrador depois da entrada; menu do topo ➜ **Visão geral**.

| Item da tela | O que mostra |
|---|---|
| **Servidor FTP** | `No ar` ou `Fora do ar`, e o modo de TLS em uso, com atalho para a aba Segurança |
| **Usuários** | Quantidade de usuários do FTP, com atalho para a aba Usuários |
| **Espaço usado** | Soma das pastas dos usuários e o espaço livre no disco, com atalho para as pastas, na aba Arquivos |
| **Último envio** | Data do arquivo mais novo entre todas as pastas, com atalho para a aba Arquivos |
| **Certificado do FTP** | Validade do certificado, com atalho para a impressão digital, na aba Segurança |
| **Dados para configurar o equipamento** | Servidor, porta de controle, portas passivas, protocolo e de onde vem o usuário: o que preencher no equipamento |
| Topo de todas as telas | As seis abas, com a aba em uso marcada, o nome do administrador da sessão e o botão **Sair**. Em tela estreita, as abas ficam numa linha que rola para o lado e o nome da aba aparece também como título da página |
| Rodapé de todas as telas | A versão da stack, o lembrete de rede privada e a autoria |

Nada é alterado por esta aba.

<details>
<summary>Visão geral ➜ Alerta de usuário sem TLS — clique para expandir</summary>

### Visão geral ➜ Alerta de usuário sem TLS

<a href="imagens/visao-geral-alerta-tls.png"><img src="imagens/visao-geral-alerta-tls.png" alt="Aba Visão geral com o alerta no topo de que dois usuários, central-pabx e radio-antigo, entram no FTP sem TLS, e o cartão Servidor FTP indicando TLS obrigatório no login, com exceção por usuário" width="100%"></a>

<sub><b>v0.24.2</b> · menu Visão geral, alerta de usuário sem TLS · captura de 2026-10-09</sub>

| Alerta no topo | Quando aparece | Como some |
|---|---|---|
| Quantos e quais usuários entram no FTP sem TLS | Com pelo menos um usuário dispensado do TLS | Quando o último volta a ser obrigado a usar TLS, em [Usuários ➜ Exigir TLS](#usuarios) |
| O FTP aceita senha e arquivo em texto puro | Com `FTP_TLS_MODE` em `0` ou `1` | Quando a variável volta para `2` ou `3` |

O mesmo alerta abre a aba Segurança. As condições para dispensar um usuário estão em [TLS por usuário](../seguranca.md#tls-por-usuario) e as do FTP sem TLS, em [Equipamento sem TLS](../seguranca.md#ftp-sem-tls).

</details>

<details>
<summary>Detalhe técnico — de onde vem cada número</summary>

- Rota `GET /`.
- `No ar` é a resposta da porta de controle do serviço `ftp`, pela rede interna da stack (`ftp:2121`).
- Usuários vêm do cadastro do FTP (`DATA_DIR/auth`); espaço, quantidade de arquivos e último envio são lidos de `DATA_DIR/dados`.
- Servidor, porta e faixa passiva são os valores de `FTP_PASSIVE_IP`, `FTP_PORT` e `FTP_PASSIVE_PORT_*` do `.env`: veja [Configuração](../configuracao.md#rede-e-portas).

</details>

---

<a name="usuarios"></a>

## 👥 Usuários

<a href="imagens/usuarios.png"><img src="imagens/usuarios.png" alt="Aba Usuários com o botão Novo usuário e a lista de usuários: o nome, com as etiquetas inicial, limites e bloqueado, a pasta no host, com a etiqueta dividida em duas, uso, arquivos, último envio, a coluna TLS, com obrigatório em todas as linhas, e as ações Editar, Trocar senha, Remover e Dispensar TLS" width="100%"></a>

<sub><b>v0.24.2</b> · menu Usuários · captura de 2026-10-09</sub>

**Para que serve:** criar a conta de cada equipamento ou pessoa, escolher e trocar a pasta em que ela fica presa, trocar a senha, dar limites próprios, tirar o bloqueio por senha errada e remover a conta, com ou sem a pasta, sem linha de comando.

**Como chegar:** menu do topo ➜ **Usuários**.

| Item da tela | O que faz |
|---|---|
| **Novo usuário** | Abre o formulário de cadastro |
| Usuário | Nome da conta. A etiqueta `inicial` marca o usuário criado na instalação (`FTP_USER`) |
| Pasta no host | Onde os arquivos desse usuário ficam no servidor. O endereço abre a pasta na aba Arquivos |
| Etiqueta `dividida` | A pasta é alcançada por mais de um usuário: um lê, grava e apaga os arquivos do outro |
| Etiqueta `limites` | O usuário tem limite próprio, gravado em **Editar**; passando o mouse, aparece cada um |
| Etiqueta `bloqueado` | O FTP está recusando o usuário por senhas erradas demais vindas de um endereço; sai sozinha no fim do prazo, ou em **Editar** |
| Uso · Arquivos · Último envio | Espaço ocupado, quantidade de arquivos e data do envio mais recente |
| Coluna TLS · **Dispensar TLS** · **Exigir TLS** | Como o usuário entra no FTP e o caminho para mudar: veja [Usuários ➜ TLS por usuário](#usuarios) |
| **Editar** | Abre a tela do usuário, com a troca da pasta, os limites próprios e os bloqueios |
| **Trocar senha** | Abre o formulário de troca de senha daquele usuário |
| **Remover** | Abre a confirmação de remoção daquele usuário, inclusive o inicial |

O usuário inicial tem a senha e a pasta trocadas e é removido como os demais. Removido, ele não volta nas próximas subidas do FTP; para tê-lo de novo, crie um usuário com o mesmo nome. A senha trocada aqui vale até o arquivo `.secrets/ftp-usuario-inicial-senha.txt` ser alterado. Veja [Segredos](../segredos.md#trocar-a-senha).

<details>
<summary>Usuários ➜ Novo usuário — clique para expandir</summary>

### Usuários ➜ Novo usuário

<a href="imagens/usuarios-novo.png"><img src="imagens/usuarios-novo.png" alt="Formulário Novo usuário com os campos Nome do usuário, Pasta, Senha e Repita a senha, o aviso de pasta dividida, a caixa Equipamento sem suporte a TLS, desmarcada, com o alerta do texto puro, e os botões Criar usuário e Cancelar" width="100%"></a>

<sub><b>v0.24.2</b> · menu Usuários, formulário Novo usuário · captura de 2026-10-09</sub>

| Campo | Obrigatório | O que preencher |
|---|---|---|
| Nome do usuário | Sim | Letras minúsculas, números, `_` e `-`; começa com letra ou `_`; até 32 caracteres |
| Pasta | Não | Em branco, é o nome do usuário. Escolhida, fica dentro de `DATA_DIR/dados`, com até 4 níveis separados por `/`, e é criada se não existir. O campo sugere as pastas que já existem |
| Senha | Não | 12 caracteres ou mais. Em branco, o painel gera uma senha forte |
| Repita a senha | Só com a senha preenchida | A mesma senha |
| Caixa **Equipamento sem suporte a TLS** | Não | Marque só para o equipamento antigo que não fala TLS: o usuário já nasce dispensado. Sem marcar, ele só entra com TLS |

**Resultado esperado:** a lista volta com a mensagem `Usuário criado.` e o usuário já entra por FTPS, sem reiniciar o FTP, preso na pasta escolhida.

> ⚠️ **Pasta dividida:** dois usuários com a mesma pasta, ou com uma dentro da outra, leem, gravam e apagam os arquivos um do outro. Na lista de usuários do começo desta seção, `filiais/olt-norte` fica dentro de `filiais`, a pasta de uma conta de consulta, e as duas levam a etiqueta `dividida`. Para um equipamento não alcançar o backup de outro, dê a cada um a própria pasta.

</details>

<details>
<summary>Usuários ➜ Novo usuário recusado — clique para expandir</summary>

### Usuários ➜ Novo usuário recusado

<a href="imagens/usuarios-novo-recusado.png"><img src="imagens/usuarios-novo-recusado.png" alt="Formulário Novo usuário com a mensagem Já existe um usuário com este nome acima dos campos" width="100%"></a>

<sub><b>v0.24.2</b> · menu Usuários, cadastro recusado · captura de 2026-10-09</sub>

O painel devolve o formulário com o motivo no topo e nada é criado.

| Mensagem | Motivo |
|---|---|
| Nome inválido. Veja a regra abaixo do campo. | O nome foge da regra de letras, números, `_` e `-` |
| Já existe um usuário com este nome. | O nome já está em uso |
| Pasta inválida. Veja a regra abaixo do campo. | A pasta foge da regra, tem mais de 4 níveis ou um nível começa com ponto |
| As duas senhas não são iguais. | Os dois campos de senha diferem |
| A senha deve ter de 12 a 128 caracteres. | Senha curta ou longa demais |

Pasta que passa por link simbólico, ou por um nome que já é de um arquivo, também é recusada, com o motivo na mesma faixa.

</details>

<details>
<summary>Usuários ➜ Senha gerada pelo painel — clique para expandir</summary>

### Usuários ➜ Senha gerada pelo painel

<a href="imagens/usuarios-senha-gerada.png"><img src="imagens/usuarios-senha-gerada.png" alt="Tela Usuário criado com a senha gerada pelo painel, aqui substituída por REDACTED, e o aviso de que ela não será mostrada de novo" width="100%"></a>

<sub><b>v0.24.2</b> · menu Usuários, senha gerada · captura de 2026-10-09</sub>

Aparece quando os dois campos de senha ficam em branco, no cadastro ou na troca de senha. A senha é mostrada **uma única vez**: copie para o equipamento ou para o cofre de senhas antes de sair da tela. Na foto, o valor foi trocado por `<REDACTED>`.

</details>

<details>
<summary>Usuários ➜ Editar — clique para expandir</summary>

### Usuários ➜ Editar

<a href="imagens/usuarios-editar.png"><img src="imagens/usuarios-editar.png" alt="Tela Editar usuário de roteador-borda, com o cartão Pasta, que mostra a pasta atual e o campo Pasta nova, o cartão TLS, que diz que o usuário só entra com TLS e traz o botão Dispensar TLS, e o cartão Limites preenchido com sessões, taxas, horário, downloads pelo painel, senhas erradas até o bloqueio e minutos de bloqueio" width="100%"></a>

<sub><b>v0.24.2</b> · menu Usuários, tela Editar usuário · captura de 2026-10-09</sub>

Reúne o que muda em um usuário sem criá-lo de novo. O nome não muda: é com ele que o equipamento entra no FTP.

| Cartão | O que faz |
|---|---|
| Topo | Mostra o usuário, leva a **Trocar senha** e volta para a lista |
| **Bloqueios** | Só aparece quando o FTP está recusando o usuário por senhas erradas demais: veja [Usuários ➜ Bloqueios](#usuarios) |
| **Pasta** | Mostra a pasta atual, com a quantidade de arquivos e o espaço ocupado, e troca a pasta do usuário |
| **TLS** | Diz se o usuário entra com ou sem TLS e leva à confirmação da troca: veja [Usuários ➜ TLS por usuário](#usuarios) |
| **Limites** | Grava os limites próprios do usuário: veja [Usuários ➜ Limites](#usuarios) |

| Campo do cartão Pasta | Obrigatório | O que preencher |
|---|---|---|
| Pasta nova | Sim | A mesma regra do cadastro: dentro de `DATA_DIR/dados`, com até 4 níveis separados por `/`; é criada se não existir |

**Resultado esperado:** depois de **Trocar pasta**, a lista volta com a mensagem `Pasta trocada. Os arquivos da pasta anterior continuam nela.` O usuário entra na pasta nova no próximo login no FTP, e a sessão dele no painel é encerrada.

| Mensagem | Motivo |
|---|---|
| Esta já é a pasta do usuário. | A pasta nova é igual à atual |
| Pasta inválida. Veja a regra abaixo do campo. | A pasta foge da regra, tem mais de 4 níveis ou um nível começa com ponto |

> ⚠️ **Os arquivos não acompanham a troca:** o que estava na pasta anterior continua nela, sem ser movido nem apagado, e o usuário deixa de alcançá-lo.

</details>

<details>
<summary>Usuários ➜ Limites — clique para expandir</summary>

### Usuários ➜ Limites

<a href="imagens/usuarios-limites-gravados.png"><img src="imagens/usuarios-limites-gravados.png" alt="Aba Usuários com a mensagem Limites gravados, valem na próxima entrada do usuário no FTP, e a etiqueta limites ao lado do nome roteador-borda" width="100%"></a>

<sub><b>v0.24.2</b> · menu Usuários, limites gravados · captura de 2026-10-09</sub>

O cartão **Limites** da tela **Editar** vale só para aquele usuário, seja a conta de um equipamento, que só envia, seja a de uma pessoa, que entra, envia e baixa. Campo em branco quer dizer sem limite próprio: vale o da stack.

| Campo | Onde vale | O que preencher |
|---|---|---|
| Sessões ao mesmo tempo no FTP | FTP | De 1 ao `FTP_MAX_CLIENTS` da stack |
| Taxa de download, em KB por segundo | FTP e downloads dele pelo painel | De 1 a 10.000.000 |
| Taxa de envio, em KB por segundo | FTP | De 1 a 10.000.000 |
| Horário em que o FTP aceita a entrada: das · até as | FTP e entrada dele no painel | Início e fim, em horas e minutos; pode passar da meia-noite, como `22:00` às `06:00` |
| Downloads ao mesmo tempo pelo painel | Painel | De 1 a 8; em branco, 2 |
| Senhas erradas no FTP até o bloqueio | FTP | De 1 a 100; `0`: este usuário nunca é bloqueado; em branco, o padrão da stack |
| Minutos de bloqueio | FTP | De 1 a 1440; em branco, o padrão da stack |

**Resultado esperado:** depois de **Gravar limites**, a lista volta com a mensagem `Limites gravados. Valem na próxima entrada do usuário no FTP.` e a etiqueta `limites` ao lado do nome; passando o mouse sobre ela, aparece cada limite do usuário. Para tirar um limite, apague o campo e grave de novo.

Na foto, `roteador-borda` ficou com 2 sessões, 4096 KB por segundo de download, 2048 de envio, entrada das `22:00` às `06:00`, 1 download por vez pelo painel e bloqueio de 30 minutos na terceira senha errada.

> ⚠️ **Taxa de envio e arquivo pequeno:** com a taxa de envio definida, o servidor segura cada arquivo enviado por cerca de `256 ÷ taxa` segundos. Para equipamento que manda muitos arquivos pequenos, use uma taxa alta ou deixe em branco. Os valores e o que cada limite muda para o usuário estão em [Painel web](../painel.md#limites).

</details>

<details>
<summary>Usuários ➜ Bloqueios — clique para expandir</summary>

### Usuários ➜ Bloqueios

<a href="imagens/usuarios-editar-bloqueios.png"><img src="imagens/usuarios-editar-bloqueios.png" alt="Tela Editar usuário de switch-core com o cartão Bloqueios: a origem bloqueada, a quantidade de senhas erradas, a hora do bloqueio, até quando ele vale e o botão Desbloquear" width="100%"></a>

<sub><b>v0.24.2</b> · menu Usuários, cartão Bloqueios · captura de 2026-10-09</sub>

O endereço que erra a senha de um usuário no FTP vezes demais fica bloqueado para aquele usuário, pelo tempo configurado: até lá, nem a senha certa entra dali. Na lista, o nome ganha a etiqueta `bloqueado`; passando o mouse sobre ela, aparecem os endereços.

| Item do cartão | O que mostra |
|---|---|
| Origem | O endereço de onde vieram as senhas erradas |
| Senhas erradas | Quantas foram contadas até o bloqueio |
| Bloqueado em · Até | A hora do bloqueio e a hora em que ele sai sozinho |
| **Desbloquear** | Tira todos os bloqueios do usuário na hora |

1. Corrija a senha no equipamento: se ele continuar errando, o bloqueio volta.
2. Clique em **Desbloquear**.

<a href="imagens/usuarios-desbloqueado.png"><img src="imagens/usuarios-desbloqueado.png" alt="Aba Usuários com a mensagem Bloqueio removido, o usuário volta a poder entrar no FTP, e o nome switch-core sem a etiqueta bloqueado" width="100%"></a>

<sub><b>v0.24.2</b> · menu Usuários, depois do desbloqueio · captura de 2026-10-09</sub>

**Resultado esperado:** a lista volta com a mensagem `Bloqueio removido. O usuário volta a poder entrar no FTP.`, sem a etiqueta `bloqueado`, e a entrada seguinte do equipamento passa.

Na foto, a origem é o endereço do host na rede interna da stack fotografada, porque as senhas erradas partiram do próprio servidor. O que conta como senha errada está em [Segurança](../seguranca.md#bloqueio-por-tentativa).

</details>

<details>
<summary>Usuários ➜ Trocar senha — clique para expandir</summary>

### Usuários ➜ Trocar senha

<a href="imagens/usuarios-trocar-senha.png"><img src="imagens/usuarios-trocar-senha.png" alt="Formulário Trocar senha do usuário switch-core, com os campos Senha e Repita a senha e os botões Trocar senha e Cancelar" width="100%"></a>

<sub><b>v0.24.2</b> · menu Usuários, formulário Trocar senha · captura de 2026-10-09</sub>

| Campo | Obrigatório | O que preencher |
|---|---|---|
| Senha | Não | 12 caracteres ou mais. Em branco, o painel gera uma senha forte |
| Repita a senha | Só com a senha preenchida | A mesma senha |

**Resultado esperado:** a lista volta com a mensagem `Senha trocada.`, a senha antiga deixa de valer no próximo login do equipamento e a sessão desse usuário no painel, se houver, é encerrada.

</details>

<details>
<summary>Usuários ➜ Remover — clique para expandir</summary>

### Usuários ➜ Remover

<a href="imagens/usuarios-remover.png"><img src="imagens/usuarios-remover.png" alt="Tela Remover usuário de ap-deposito, com o aviso dos arquivos da pasta, a caixa Apagar também a pasta e tudo o que há nela marcada, o campo Sua senha atual e os botões Sim, remover o usuário e Cancelar" width="100%"></a>

<sub><b>v0.24.2</b> · menu Usuários, confirmação de remoção · captura de 2026-10-09</sub>

| Item da tela | O que faz |
|---|---|
| Aviso dos arquivos | Mostra quantos arquivos o usuário tem, quanto ocupam e em que pasta eles continuam; em pasta dividida, diz quem mais a alcança |
| Caixa **Apagar também a pasta e tudo o que há nela** | Só aparece quando a pasta é só deste usuário. Marcada, a pasta sai junto com a conta, com tudo o que tem dentro e sem lixeira |
| **Sua senha atual** | Pedida só quando a caixa está marcada: é a senha de quem está usando o painel |
| **Sim, remover o usuário** | Apaga a conta: o login deixa de funcionar na hora |
| **Cancelar** | Volta para a lista sem alterar nada |

<a href="imagens/usuarios-removido.png"><img src="imagens/usuarios-removido.png" alt="Aba Usuários depois da remoção, com a mensagem Usuário removido e pasta apagada" width="100%"></a>

<sub><b>v0.24.2</b> · menu Usuários, depois da remoção · captura de 2026-10-09</sub>

**Resultado esperado:** com a caixa marcada e a senha certa, como na foto, a lista volta com a mensagem `Usuário removido e pasta apagada.` e a pasta some. Sem a caixa, a mensagem é `Usuário removido. Os arquivos continuam na pasta.`: a pasta fica em `DATA_DIR/dados` e continua visível na aba Arquivos, onde pode ser apagada depois.

<a href="imagens/usuarios-remover-inicial.png"><img src="imagens/usuarios-remover-inicial.png" alt="Tela Remover usuário do usuário inicial transfer, com o aviso de que, removido, ele não volta nas próximas subidas do serviço ftp, a caixa Apagar também a pasta e tudo o que há nela marcada, o campo Sua senha atual e os botões Sim, remover o usuário e Cancelar" width="100%"></a>

<sub><b>v0.24.2</b> · menu Usuários, remoção do usuário inicial · captura de 2026-10-09</sub>

O usuário inicial, o `FTP_USER` da instalação (`transfer`, no exemplo), é removido do mesmo jeito, com ou sem a pasta. A tela avisa que ele não volta nas próximas subidas do serviço `ftp`: para tê-lo de novo, crie um usuário com o mesmo nome.

</details>

<details>
<summary>Usuários ➜ TLS por usuário — clique para expandir</summary>

### Usuários ➜ TLS por usuário

<a href="imagens/usuarios-tls.png"><img src="imagens/usuarios-tls.png" alt="Aba Usuários com o aviso de que o usuário foi dispensado do TLS e a senha e os arquivos dele passam em texto puro, a coluna TLS, que mostra obrigatório ou sem TLS em cada linha, e os botões Dispensar TLS e Exigir TLS ao lado de Editar, Trocar senha e Remover" width="100%"></a>

<sub><b>v0.24.2</b> · menu Usuários, coluna TLS · captura de 2026-10-09</sub>

A coluna e os dois botões servem para o equipamento antigo que não fala TLS: ele é dispensado sozinho, e os demais continuam obrigados. O mesmo se faz na criação, com a caixa **Equipamento sem suporte a TLS** do **Novo usuário**, e no cartão **TLS** da tela **Editar**.

| Item da tela | O que faz |
|---|---|
| Coluna TLS | `obrigatório` para quem só entra com TLS e `sem TLS` para quem foi dispensado |
| **Dispensar TLS** | Abre a confirmação para deixar aquele usuário entrar sem TLS |
| **Exigir TLS** | Abre a confirmação para voltar a exigir o TLS de quem está dispensado |
| Caixa **Equipamento sem suporte a TLS**, em **Novo usuário** | Cria o usuário já dispensado do TLS; sem marcar, ele só entra com TLS |
| Cartão **TLS**, em **Editar** | Diz como aquele usuário entra e leva à mesma confirmação |

<a href="imagens/usuarios-novo-sem-tls.png"><img src="imagens/usuarios-novo-sem-tls.png" alt="Formulário Novo usuário preenchido para central-pabx, com a caixa Equipamento sem suporte a TLS marcada e o alerta de que a senha e os arquivos deste usuário passam a trafegar em texto puro" width="100%"></a>

<sub><b>v0.24.2</b> · menu Usuários, usuário novo sem TLS · captura de 2026-10-09</sub>

Na criação, a caixa marcada grava o usuário já dispensado, e a lista volta com a mensagem `Usuário criado e dispensado do TLS: a senha e os arquivos dele passam em texto puro.`

<a href="imagens/usuarios-editar-tls.png"><img src="imagens/usuarios-editar-tls.png" alt="Tela Editar usuário de central-pabx, com o cartão TLS avisando que este usuário entra sem TLS e o botão Exigir TLS" width="100%"></a>

<sub><b>v0.24.2</b> · menu Usuários, cartão TLS da tela Editar · captura de 2026-10-09</sub>

Na tela **Editar**, o cartão **TLS** diz como o usuário entra e traz o botão para trocar: **Dispensar TLS** para quem é obrigado, **Exigir TLS** para quem está dispensado. Para o usuário que já existe, o botão abre a confirmação:

<a href="imagens/usuarios-tls-dispensar.png"><img src="imagens/usuarios-tls-dispensar.png" alt="Tela Dispensar TLS do usuário radio-antigo, com o aviso de que a senha e os arquivos passam a trafegar em texto puro e os botões Sim, deixar este usuário entrar sem TLS e Cancelar" width="100%"></a>

<sub><b>v0.24.2</b> · menu Usuários, confirmação da dispensa do TLS · captura de 2026-10-09</sub>

**Resultado esperado:** a lista volta com a mensagem `Usuário dispensado do TLS: a senha e os arquivos dele passam em texto puro.`, a linha dele mostra `sem TLS` e as abas Visão geral e Segurança abrem com o alerta. A dispensa vale em instantes, sem derrubar quem está conectado. Ao voltar a exigir, a mensagem é `O usuário volta a ser obrigado a usar TLS.`

> ⚠️ **Dispensa do TLS:** o usuário dispensado manda senha e arquivo em texto puro. Use só para o equipamento antigo que não fala TLS, em rede interna isolada, com pasta e senha só dele, e troque a senha quando voltar a exigir. As condições estão em [TLS por usuário](../seguranca.md#tls-por-usuario).

</details>

<details>
<summary>Detalhe técnico — rotas e comando usado</summary>

- Rotas: `GET /usuarios`, `/usuarios/novo`, `/usuarios/editar?usuario=<nome>`, `/usuarios/senha?usuario=<nome>`, `/usuarios/remover?usuario=<nome>` e `/usuarios/tls?usuario=<nome>`; o envio de cada formulário é um `POST` na mesma rota, com o token CSRF da sessão. A exceção é a tela Editar, que envia a pasta para `POST /usuarios/pasta`, os limites para `POST /usuarios/limites` e o desbloqueio para `POST /usuarios/desbloquear`.
- A dispensa do TLS vale com `FTP_TLS_EXCECOES=sim`, que é o padrão, `FTP_TLS_MODE=2` e sem `REDE_PERMITIR_IP_PUBLICO=sim`. Fora disso, a coluna, os botões e a caixa somem, a rota `/usuarios/tls` responde `404` e a lista dos dispensados fica guardada, sem valer.
- O painel chama o mesmo `allsafe-ftp-user` do [`manage-user.sh`](../../manage-user.sh): painel e linha de comando alteram as mesmas contas. Veja [Operação](../operacao.md#usuarios).
- Cada alteração grava `usuario_criado`, `senha_trocada`, `pasta_trocada`, `limites_alterados`, `bloqueio_removido`, `usuario_removido`, `tls_dispensado` ou `tls_exigido` na [auditoria](../painel.md#auditoria), com o administrador que fez e sem a senha.
- A senha gerada tem 32 caracteres aleatórios e não fica guardada: só o hash vai para o cadastro do FTP.
- Sessões, taxas e horário ficam no cadastro do FTP, e é o `pure-ftpd` que os aplica a cada entrada; os downloads pelo painel e o bloqueio por tentativa ficam em arquivos próprios da stack: [Limites por usuário](../painel.md#limites).
- Mudar as senhas erradas até o bloqueio ou os minutos de bloqueio tira os bloqueios do usuário; trocar a senha dele e removê-lo também.
- As regras da pasta e o que a marca `dividida` confere estão em [Usuários pelo painel](../painel.md#usuarios).

</details>

---

<a name="arquivos"></a>

## 📁 Arquivos

<a href="imagens/arquivos.png"><img src="imagens/arquivos.png" alt="Aba Arquivos no primeiro nível, com a lista das pastas dos usuários, a data de cada uma, os botões Renomear e Apagar em cada linha e o formulário Nova pasta" width="100%"></a>

<sub><b>v0.24.2</b> · menu Arquivos · captura de 2026-10-09</sub>

**Para que serve:** ver o que cada equipamento enviou, baixar um backup pelo navegador, criar a pasta de um usuário novo, trocar o nome e apagar arquivo e pasta, sem cliente de FTP.

**Como chegar:** menu do topo ➜ **Arquivos**. Na aba Usuários, o endereço da coluna **Pasta no host** abre direto a pasta daquele usuário.

| Item da tela | O que faz |
|---|---|
| Caminho no alto da lista | Mostra a pasta aberta e volta a qualquer nível |
| Nome de uma pasta | Entra na pasta |
| Tamanho · Modificado | Tamanho do arquivo e data da última alteração |
| **Baixar** | Entrega o arquivo ao navegador, com o nome original |
| **Renomear** | Abre a tela que troca o nome do arquivo ou da pasta, dentro da mesma pasta; nome que já existe é recusado |
| **Apagar** | Abre a tela de confirmação: mostra o que vai sair, pede a caixa marcada e a sua senha atual e apaga de vez, sem lixeira |
| **Nova pasta** | Cria uma pasta vazia dentro da que está aberta |
| **Novo usuário nesta pasta** | Dentro de uma pasta, abre o cadastro de usuário com o campo Pasta preenchido |

O painel navega, baixa, cria pasta, troca o nome e apaga; enviar arquivo continua sendo feito por FTP. A pasta de um usuário do FTP não é renomeada nem apagada por aqui: sai junto com o usuário, em [Usuários ➜ Remover](#usuarios). As regras e os limites estão em [Painel web](../painel.md#arquivos).

<details>
<summary>Arquivos ➜ Pasta de um usuário e download — clique para expandir</summary>

### Arquivos ➜ Pasta de um usuário e download

<a href="imagens/arquivos-pasta.png"><img src="imagens/arquivos-pasta.png" alt="Aba Arquivos dentro da pasta roteador-borda, com o caminho no alto, a linha que diz de qual usuário do FTP é a pasta, o botão Novo usuário nesta pasta e os botões Baixar, Renomear e Apagar em cada arquivo" width="100%"></a>

<sub><b>v0.24.2</b> · menu Arquivos, pasta de um usuário · captura de 2026-10-09</sub>

1. Clique no nome da pasta para entrar.
2. Confira, na linha `Pasta do usuário do FTP`, de quem é a pasta.
3. Clique em **Baixar** na linha do arquivo.

**Resultado esperado:** o navegador salva o arquivo com o nome original, idêntico ao que o equipamento enviou, e a aba Atividade ganha a linha `Arquivo baixado`, com o administrador, o caminho e o tamanho.

| Limite | Valor |
|---|---|
| Downloads ao mesmo tempo | 8, somando administradores e usuários do FTP; o seguinte recebe a tela `Muitos downloads ao mesmo tempo` |
| Itens mostrados por pasta | 2000, com um aviso quando há mais |
| Retomada | Não há: se a conexão cair, o download começa de novo |

</details>

<details>
<summary>Arquivos ➜ Nova pasta — clique para expandir</summary>

### Arquivos ➜ Nova pasta

<a href="imagens/arquivos-pasta-criada.png"><img src="imagens/arquivos-pasta-criada.png" alt="Aba Arquivos com a mensagem Pasta criada e a pasta clientes na lista" width="100%"></a>

<sub><b>v0.24.2</b> · menu Arquivos, pasta criada · captura de 2026-10-09</sub>

| Campo | Obrigatório | O que preencher |
|---|---|---|
| Nome da pasta | Sim | Letras, números, `_`, `-` e ponto; não começa com ponto; até 64 caracteres. Uma pasta por vez: para criar `clientes/olt-01`, crie `clientes`, entre nela e crie `olt-01` |

**Resultado esperado:** a lista volta com a mensagem `Pasta criada.` e a pasta nova, vazia, já com o dono e a permissão que o FTP usa. Para um equipamento gravar nela, entre na pasta e clique em **Novo usuário nesta pasta**.

| Mensagem | Motivo |
|---|---|
| Caminho não aceito. | O nome foge da regra ou tenta sair da pasta dos dados |
| Já existe uma pasta ou um arquivo com este nome. | O nome já está em uso naquela pasta |
| Link simbólico não é seguido pelo painel. | O destino passa por um link simbólico |
| Pasta ou arquivo não encontrado. | A pasta de destino deixou de existir |

</details>

<details>
<summary>Arquivos ➜ Renomear — clique para expandir</summary>

### Arquivos ➜ Renomear

<a href="imagens/arquivos-renomear.png"><img src="imagens/arquivos-renomear.png" alt="Tela Renomear do arquivo switch-core-antigo.cfg, com a pasta em que ele fica, o campo Nome novo preenchido e os botões Trocar nome e Cancelar" width="100%"></a>

<sub><b>v0.24.2</b> · menu Arquivos, tela Renomear · captura de 2026-10-09</sub>

| Campo | Obrigatório | O que preencher |
|---|---|---|
| Nome novo | Sim | Letras, números, `_`, `-` e ponto; não começa com ponto; até 64 caracteres |

<a href="imagens/arquivos-renomeado.png"><img src="imagens/arquivos-renomeado.png" alt="Aba Arquivos dentro da pasta switch-core, com a mensagem Nome trocado e o arquivo com o nome novo na lista" width="100%"></a>

<sub><b>v0.24.2</b> · menu Arquivos, depois da troca de nome · captura de 2026-10-09</sub>

**Resultado esperado:** a pasta volta com a mensagem `Nome trocado.` e o item com o nome novo, no mesmo lugar. O painel não move de uma pasta para outra, e o equipamento que grava com o nome antigo cria outro arquivo no envio seguinte.

| Mensagem | Motivo |
|---|---|
| Nome não aceito. Veja a regra abaixo do campo. | O nome foge da regra |
| O item já tem este nome. | O nome novo é igual ao atual |
| Já existe uma pasta ou um arquivo com este nome. | O nome já está em uso naquela pasta; nada é substituído |

</details>

<details>
<summary>Arquivos ➜ Apagar — clique para expandir</summary>

### Arquivos ➜ Apagar

<a href="imagens/arquivos-apagar.png"><img src="imagens/arquivos-apagar.png" alt="Tela Apagar do arquivo teste-de-envio.txt, com o tamanho, a data e a pasta dele, o aviso de que o painel não tem lixeira, a caixa de confirmação marcada, o campo Sua senha atual e os botões Apagar de vez e Cancelar" width="100%"></a>

<sub><b>v0.24.2</b> · menu Arquivos, confirmação de apagar · captura de 2026-10-09</sub>

| Item da tela | O que faz |
|---|---|
| Primeira linha | Diz o que vai sair: o arquivo, com o tamanho e a data, ou a pasta, com a quantidade de arquivos e o espaço de tudo o que há dentro dela |
| Caixa **Conferi o nome e quero apagar** | Obrigatória: sem ela nada é apagado |
| **Sua senha atual** | A senha de quem está usando o painel, para confirmar |
| **Apagar de vez** | Apaga o arquivo, ou a pasta com tudo o que tem dentro |
| **Cancelar** | Volta para a pasta sem alterar nada |

<a href="imagens/arquivos-apagado.png"><img src="imagens/arquivos-apagado.png" alt="Aba Arquivos dentro da pasta switch-core, com a mensagem Apagado e a lista sem o arquivo teste-de-envio.txt" width="100%"></a>

<sub><b>v0.24.2</b> · menu Arquivos, depois de apagar · captura de 2026-10-09</sub>

**Resultado esperado:** a pasta volta com a mensagem `Apagado.` e sem o item, e a aba Atividade ganha a linha `Arquivo ou pasta apagado`.

> ⚠️ **Apagar não tem volta:** o painel não tem lixeira, e o que foi apagado só volta de uma cópia de segurança. Veja [Backup](../backup.md).

| Mensagem ou tela | Motivo |
|---|---|
| Marque a caixa de confirmação. Nada foi apagado. | A caixa ficou desmarcada |
| A sua senha atual não confere. Nada foi apagado. | O campo Sua senha atual está errado; cinco recusas em 15 minutos bloqueiam o endereço |
| Tela `Apagado em parte` | A pasta tem mais do que o painel apaga em um pedido: repita para continuar |
| Tela `Nada foi apagado` | O painel já está apagando outra pasta, ou um item não pôde ser removido |

<a href="imagens/arquivos-pasta-de-usuario.png"><img src="imagens/arquivos-pasta-de-usuario.png" alt="Tela Pasta de usuário do FTP, que recusa apagar a pasta roteador-borda por ser a pasta de um usuário e indica Usuários, Editar e Usuários, Remover" width="100%"></a>

<sub><b>v0.24.2</b> · menu Arquivos, pasta de usuário recusada · captura de 2026-10-09</sub>

A pasta de um usuário do FTP, e a pasta que tem a de um usuário dentro, não é renomeada nem apagada pela aba Arquivos: o cadastro ficaria apontando para uma pasta que não existe. Para dar outra pasta ao usuário, use **Usuários ➜ Editar**; para apagar a pasta junto com ele, **Usuários ➜ Remover**. O que está dentro dela é renomeado e apagado item por item.

</details>

<details>
<summary>Detalhe técnico — rotas e proteções</summary>

- Rotas: `GET /arquivos?pasta=<caminho>` lista, `GET /arquivos/baixar?arquivo=<caminho>` entrega e `POST /arquivos/pasta` cria a pasta, com o token CSRF. `GET /arquivos/renomear?item=<caminho>` e `GET /arquivos/apagar?item=<caminho>` mostram a tela de cada ação, e o envio é um `POST` na mesma rota. Não existe rota de envio.
- O caminho é sempre relativo a `DATA_DIR/dados`, aberto parte por parte e sem seguir link simbólico. Caminho com `..` recebe `400` e link simbólico, `403`, os dois com o evento `recusa_caminho`.
- O arquivo sai como anexo (`Content-Disposition: attachment`, RFC 6266 e RFC 8187), em blocos de 64 KiB, sem ser carregado na memória: o navegador salva e nunca abre.
- A pasta nova nasce com o dono `ftpdata` e o modo `0750`, os mesmos das pastas criadas pelo FTP.
- O nome é trocado por uma chamada só ao sistema, que recusa o nome que já existe; a pasta é esvaziada de dentro para fora, e um link simbólico dentro dela é apagado como link, sem tocar no destino.
- Um pedido de apagar remove até 50.000 itens ou trabalha por até 20 segundos, e o painel faz um apagamento por vez.
- A pasta de um usuário do FTP, ou a que tem uma dentro, responde `409` na tela e no envio.
- Os eventos `arquivo_baixado`, `arquivo_interrompido`, `pasta_criada`, `item_renomeado` e `item_apagado` ficam na [auditoria](../painel.md#auditoria); o conteúdo do arquivo nunca é registrado.
- O funcionamento completo está em [Arquivos e download](../painel.md#arquivos).

</details>

---

<a name="meus-arquivos"></a>

## 📥 Meus arquivos

<a href="imagens/meus-arquivos.png"><img src="imagens/meus-arquivos.png" alt="Tela Meus arquivos do usuário olt-centro, com as pastas 2026-09 e 2026-10, um arquivo de configuração com o botão Baixar e, no topo, só o nome do usuário e o botão Sair" width="100%"></a>

<sub><b>v0.24.2</b> · tela Meus arquivos, do usuário do FTP · captura de 2026-10-09</sub>

**Para que serve:** o dono dos arquivos baixa os próprios backups pelo navegador, sem depender de quem administra e sem conta nova.

**Como chegar:** abra o endereço do painel e entre com **o nome e a senha do FTP**, os mesmos que o equipamento usa. É a única tela que o usuário do FTP vê.

| Item da tela | O que faz |
|---|---|
| Caminho no alto da lista | Mostra a pasta aberta, a partir de **Início**, e volta a qualquer nível |
| Nome de uma pasta | Entra na pasta |
| Tamanho · Modificado | Tamanho do arquivo e data da última alteração |
| **Baixar** | Entrega o arquivo ao navegador, com o nome original |
| **Sair** | Encerra a sessão na hora |

O usuário vê só a pasta do cadastro dele e o que há dentro dela. O caminho da pasta no servidor não aparece, e não há menu de administração.

<details>
<summary>Meus arquivos ➜ Dentro de uma pasta — clique para expandir</summary>

### Meus arquivos ➜ Dentro de uma pasta

<a href="imagens/meus-arquivos-pasta.png"><img src="imagens/meus-arquivos-pasta.png" alt="Tela Meus arquivos dentro da pasta 2026-10, com três arquivos de backup, o tamanho e a data de cada um e o botão Baixar em cada linha" width="100%"></a>

<sub><b>v0.24.2</b> · tela Meus arquivos, dentro de uma pasta · captura de 2026-10-09</sub>

1. Clique no nome da pasta para entrar.
2. Clique em **Baixar** na linha do arquivo.
3. Clique em **Início**, no caminho do alto, para voltar à pasta do usuário.

**Resultado esperado:** o arquivo salvo é idêntico ao que o equipamento enviou, e a aba Atividade, que só o administrador vê, ganha a linha `Arquivo baixado`, com o nome do usuário do FTP, o caminho e o tamanho.

| Limite | Valor |
|---|---|
| Sessões por usuário do FTP | 3; a quarta entrada encerra a mais antiga |
| Downloads ao mesmo tempo por usuário | 2, ou o número gravado nos limites dele; o seguinte recebe a tela `Muitos downloads ao mesmo tempo` |
| Depois de trocar a senha ou remover o usuário | A sessão dele é encerrada no pedido seguinte |

</details>

<details>
<summary>Detalhe técnico — o que a conta do FTP alcança</summary>

- Rotas da sessão do usuário do FTP: `GET /` (leva a `/meus-arquivos`), `GET /meus-arquivos?pasta=<caminho>`, `GET /meus-arquivos/baixar?arquivo=<caminho>` e `POST /sair`. Qualquer outra responde `404`; quando é uma rota de administração, fica o evento `recusa_papel`.
- Quem confere a senha é o `pure-ftpd`, por um login na rede interna da stack; o painel não lê o hash do cadastro.
- O caminho é sempre relativo à pasta do cadastro, que é a raiz dele, com as mesmas conferências da [aba Arquivos](#arquivos).
- `PAINEL_ACESSO_USUARIOS_FTP=nao` desliga esta entrada: o painel passa a aceitar só administradores.
- O funcionamento completo está em [Usuário do FTP no painel](../painel.md#usuario-ftp).

</details>

---

<a name="administradores"></a>

## 🛡️ Administradores

<a href="imagens/administradores.png"><img src="imagens/administradores.png" alt="Aba Administradores com o botão Novo administrador e a lista de três administradores: a marca você na conta em uso, as sessões abertas de cada um e as ações Trocar senha, Trocar nome e Remover" width="100%"></a>

<sub><b>v0.24.2</b> · menu Administradores · captura de 2026-10-09</sub>

**Para que serve:** dar a cada pessoa que administra o painel o próprio usuário e a própria senha, e trocar o usuário e a senha do primeiro administrador depois da instalação.

**Como chegar:** menu do topo ➜ **Administradores**.

| Item da tela | O que faz |
|---|---|
| **Novo administrador** | Abre o formulário de cadastro |
| Administrador | Nome da conta. A etiqueta `você` marca a conta de quem está usando o painel |
| Sessões abertas | Quantos navegadores estão com aquela conta dentro do painel agora |
| **Trocar senha** | Abre a troca de senha, a própria ou a de outro |
| **Trocar nome** | Abre a troca do nome de entrada, o próprio ou o de outro |
| **Remover** | Abre a confirmação de remoção. Não aparece na própria conta: assim sempre sobra um administrador |

Todos têm o mesmo acesso, e o que cada um faz fica na aba Atividade com o nome de quem fez. O painel aceita até 20 administradores.

<details>
<summary>Administradores ➜ Novo administrador — clique para expandir</summary>

### Administradores ➜ Novo administrador

<a href="imagens/administradores-novo.png"><img src="imagens/administradores-novo.png" alt="Formulário Novo administrador com os campos Nome do administrador, Senha, Repita a senha e Sua senha atual, e os botões Criar administrador e Cancelar" width="100%"></a>

<sub><b>v0.24.2</b> · menu Administradores, formulário Novo administrador · captura de 2026-10-09</sub>

| Campo | Obrigatório | O que preencher |
|---|---|---|
| Nome do administrador | Sim | Letras minúsculas, números, `_` e `-`; começa com letra ou `_`; até 32 caracteres |
| Senha | Não | 12 caracteres ou mais. Em branco, o painel gera uma senha forte e a mostra uma única vez |
| Repita a senha | Só com a senha preenchida | A mesma senha |
| Sua senha atual | Sim | A senha de quem está usando o painel, para confirmar |

**Resultado esperado:** a lista volta com a mensagem `Administrador criado.` e o administrador novo entra logo em seguida, sem reiniciar nada.

</details>

<details>
<summary>Administradores ➜ Trocar senha — clique para expandir</summary>

### Administradores ➜ Trocar senha

<a href="imagens/administradores-trocar-senha.png"><img src="imagens/administradores-trocar-senha.png" alt="Formulário Trocar senha de administrador, com os campos Senha, Repita a senha e Sua senha atual e os botões Trocar senha e Cancelar" width="100%"></a>

<sub><b>v0.24.2</b> · menu Administradores, formulário Trocar senha · captura de 2026-10-09</sub>

| Campo | Obrigatório | O que preencher |
|---|---|---|
| Senha | Não | A senha nova, com 12 caracteres ou mais. Em branco, o painel gera uma |
| Repita a senha | Só com a senha preenchida | A mesma senha |
| Sua senha atual | Sim | A senha de quem está usando o painel, para confirmar |

**Resultado esperado:** a lista volta com a mensagem `Senha trocada. As outras sessões desse administrador foram encerradas.` e a senha antiga deixa de valer na hora.

É por aqui que a senha inicial da instalação é trocada depois do primeiro acesso. Sem nenhum administrador que consiga entrar, a senha é redefinida pelo servidor: [Recuperar o acesso](../painel.md#senha).

</details>

<details>
<summary>Administradores ➜ Trocar nome — clique para expandir</summary>

### Administradores ➜ Trocar nome

<a href="imagens/administradores-trocar-nome.png"><img src="imagens/administradores-trocar-nome.png" alt="Formulário Trocar nome de administrador, com o campo Nome novo preenchido com suporte-redes, o campo Sua senha atual e os botões Trocar nome e Cancelar" width="100%"></a>

<sub><b>v0.24.2</b> · menu Administradores, formulário Trocar nome · captura de 2026-10-09</sub>

| Campo | Obrigatório | O que preencher |
|---|---|---|
| Nome novo | Sim | A mesma regra do nome do administrador; diferente do atual e de todos os outros |
| Sua senha atual | Sim | A senha de quem está usando o painel, para confirmar |

**Resultado esperado:** a lista volta com a mensagem `Nome trocado. As outras sessões desse administrador foram encerradas.` A entrada passa a ser pelo nome novo, com a mesma senha.

Trocar o nome do primeiro administrador pelo painel não mexe no `.env`: o `PAINEL_ADMIN_USER` só é usado enquanto não existe nenhum administrador.

</details>

<details>
<summary>Administradores ➜ Remover — clique para expandir</summary>

### Administradores ➜ Remover

<a href="imagens/administradores-remover.png"><img src="imagens/administradores-remover.png" alt="Tela Remover administrador pedindo confirmação, com o campo Sua senha atual e os botões Sim, remover o administrador e Cancelar" width="100%"></a>

<sub><b>v0.24.2</b> · menu Administradores, confirmação de remoção · captura de 2026-10-09</sub>

| Item da tela | O que faz |
|---|---|
| Sua senha atual | Confirma que quem pede a remoção é o dono da sessão |
| **Sim, remover o administrador** | Apaga a conta: ela deixa de entrar na hora e as sessões abertas dela são encerradas |
| **Cancelar** | Volta para a lista sem alterar nada |

**Resultado esperado:** a lista volta com a mensagem `Administrador removido. As sessões dele foram encerradas.` Os usuários do FTP e os arquivos não mudam.

</details>

<details>
<summary>Detalhe técnico — mensagens de recusa, rotas e arquivo</summary>

| Mensagem | Motivo |
|---|---|
| A sua senha atual não confere. Nada foi alterado. | O campo Sua senha atual está errado; cinco recusas em 15 minutos bloqueiam o endereço |
| Já existe um administrador com este nome. | O nome já está em uso |
| O nome novo é igual ao atual. | A troca de nome não mudou nada |
| Limite de 20 administradores atingido: remova um antes de criar outro. | O painel já tem 20 administradores |

- Rotas: `GET /administradores`, `/administradores/novo`, `/administradores/senha?admin=<nome>`, `/administradores/nome?admin=<nome>` e `/administradores/remover?admin=<nome>`; o envio de cada formulário é um `POST` na mesma rota, com o token CSRF da sessão.
- Os administradores ficam em `DATA_DIR/painel/administradores` (`0600`, do `root`), uma linha `nome:hash` por conta. Só o hash `scrypt` é gravado.
- Cada alteração grava `admin_criado`, `admin_senha_trocada`, `admin_renomeado` ou `admin_removido` na [auditoria](../painel.md#auditoria), com quem fez e quem foi alterado; a senha atual errada grava `admin_senha_atual_recusada`.
- As regras completas estão em [Administradores do painel](../painel.md#administradores).

</details>

---

<a name="seguranca"></a>

## 🔐 Segurança

<a href="imagens/seguranca.png"><img src="imagens/seguranca.png" alt="Aba Segurança com a conferência da instalação, uma linha por item: endereço público, endereços do FTP e do painel, modo TLS, os dois certificados, redes permitidas, sessão, entrada dos usuários do FTP, bloqueio por tentativa no FTP, com o nome do usuário bloqueado, custo das senhas, contato de segurança, container e firewall" width="100%"></a>

<sub><b>v0.24.2</b> · menu Segurança · captura de 2026-10-09</sub>

**Para que serve:** conferir, em uma tela, se a instalação está dentro do que a stack exige: rede privada, TLS, certificados válidos, painel isolado e contato de segurança publicado.

**Como chegar:** menu do topo ➜ **Segurança**.

| Item da tela | O que mostra |
|---|---|
| Endereço público | Se a stack recusa endereço público (o padrão) ou se ele foi aceito com `REDE_PERMITIR_IP_PUBLICO=sim` |
| Endereço do FTP · IP anunciado no modo passivo | Onde o FTP escuta e o IP que ele informa ao cliente, com a indicação de privado ou público |
| TLS do FTP | O modo em uso (`FTP_TLS_MODE`), se a exceção por usuário está ligada e quem está dispensado |
| Certificado do FTP · Certificado do painel | Validade e impressão digital SHA-256, para comparar com a que o cliente FTP e o navegador mostram |
| Endereço do painel · Frente web | Onde o nginx publica o painel e como ele repassa os pedidos |
| Quem pode abrir o painel | As redes de `PAINEL_REDES_PERMITIDAS`; rede pública na lista aparece destacada |
| Sessão | Tempo sem uso, tempo máximo e bloqueio por entrada errada |
| Entrada dos usuários do FTP | Se os usuários do FTP entram no painel (`PAINEL_ACESSO_USUARIOS_FTP`) e como a senha deles é conferida |
| Bloqueio por tentativa no FTP | Quantas senhas erradas do mesmo endereço bloqueiam um usuário e por quanto tempo (`FTP_BLOQUEIO_TENTATIVAS` e `FTP_BLOQUEIO_MINUTOS`), e quem está bloqueado agora |
| Custo das senhas do FTP | Se todas as senhas estão gravadas com o custo do porte atual, ou quais usuários ainda estão com o anterior |
| Contato de segurança | O e-mail publicado em `/.well-known/security.txt` (`SEGURANCA_CONTATO_EMAIL`), ou o aviso de que não há contato |
| Container do painel | Raiz somente leitura e sem acesso ao Docker do host |
| Firewall do host | Lembrete: o painel não enxerga o firewall; a conferência é de quem administra o servidor |

Nada é alterado por esta aba. As regras de firewall de exemplo estão em [Segurança](../seguranca.md#rede-privada).

<details>
<summary>Segurança ➜ Alerta de usuário sem TLS — clique para expandir</summary>

### Segurança ➜ Alerta de usuário sem TLS

<a href="imagens/seguranca-tls-por-usuario.png"><img src="imagens/seguranca-tls-por-usuario.png" alt="Aba Segurança com o alerta no topo de que dois usuários, central-pabx e radio-antigo, entram no FTP sem TLS, e a linha TLS do FTP com a marca de atenção e os nomes dos usuários dispensados" width="100%"></a>

<sub><b>v0.24.2</b> · menu Segurança, alerta de usuário sem TLS · captura de 2026-10-09</sub>

Com pelo menos um usuário dispensado do TLS, a aba abre com o alerta e a linha **TLS do FTP** troca a marca de conferido pela de atenção, com a quantidade e os nomes de quem entra sem TLS.

**Resultado esperado:** depois de **Usuários ➜ Exigir TLS** no último usuário dispensado, o alerta some e a linha volta a dizer que todos entram com TLS.

</details>

<details>
<summary>Detalhe técnico — o que cada linha lê</summary>

- Rota `GET /seguranca`.
- As impressões digitais são calculadas dos arquivos `DATA_DIR/certs` (FTP) e `DATA_DIR/painel/tls` (painel), os mesmos que os serviços usam.
- As linhas com endereço e rede vêm do `.env`. Por padrão a stack recusa subir com valor que não seja privado; com `REDE_PERMITIR_IP_PUBLICO=sim`, o endereço e a rede públicos aparecem com a marca de atenção: [Segurança](../seguranca.md#ip-publico).
- O custo das senhas compara a memória gravada na senha de cada usuário com a do porte atual, calculada de `FTP_MAX_CLIENTS`; o hash não sai do cadastro: [Custo das senhas](../seguranca.md#custo-das-senhas).
- O contato é o valor de `SEGURANCA_CONTATO_EMAIL`; o arquivo `/.well-known/security.txt` segue a RFC 9116: [Contato de segurança](../seguranca.md#contato-de-seguranca).
- A última linha não tem marca de conferido de propósito: nenhum container da stack lê as regras de firewall do host.

</details>

---

<a name="atividade"></a>

## 📜 Atividade

<a href="imagens/atividade.png"><img src="imagens/atividade.png" alt="Aba Atividade com os registros do painel: data, endereço de origem, o que aconteceu e o detalhe, como arquivo baixado, pasta criada, administrador criado e tela de administração pedida por usuário do FTP" width="100%"></a>

<sub><b>v0.24.2</b> · menu Atividade · captura de 2026-10-09</sub>

**Para que serve:** saber quem entrou no painel, de onde, o que foi alterado e quem baixou cada arquivo.

**Como chegar:** menu do topo ➜ **Atividade**.

| Coluna | O que mostra |
|---|---|
| Quando | Data e hora do registro, do mais novo para o mais antigo |
| De onde | Endereço de quem fez o pedido |
| O que aconteceu | O evento, em uma frase: a tabela abaixo lista os principais |
| Detalhe | Quem fez (`admin=` ou `usuario=`), quem ou o que foi alterado, o caminho e o tamanho do arquivo. Senha e token nunca aparecem |

| O que aconteceu | Quando aparece |
|---|---|
| Entrada · Entrada recusada · Entrada bloqueada pelo limite de tentativas · Saída | Alguém entrou, errou o usuário ou a senha, teve o endereço bloqueado ou saiu |
| Usuário criado · Senha trocada · Pasta do usuário trocada · Usuário removido | Alteração de usuário do FTP, com o administrador que fez |
| Limites do usuário alterados · Bloqueio do usuário no FTP removido | Limites gravados, com o valor de cada um, e bloqueio por senha errada tirado em **Editar** |
| Usuário dispensado do TLS · Usuário volta a exigir TLS | Alteração do TLS de um usuário |
| Arquivo baixado · Download interrompido | Download pela aba Arquivos ou pela tela Meus arquivos, completo ou cortado antes do fim |
| Pasta criada · Arquivo ou pasta renomeado · Arquivo ou pasta apagado | Alteração pela aba Arquivos, com o caminho; o apagado aparece também quando a pasta sai junto com o usuário |
| Administrador criado · Senha de administrador trocada · Administrador renomeado · Administrador removido | Alteração de administrador, com quem fez e quem foi alterado |
| Senha atual recusada | Alteração de administrador recusada pela senha de confirmação |
| Tela de administração pedida por usuário do FTP | Um usuário do FTP tentou abrir uma aba de administração e recebeu `404` |
| Sessão de usuário do FTP encerrada | A senha ou a pasta do usuário mudou, ou ele foi removido |
| Caminho de arquivo recusado | Pedido que tenta sair da pasta dos dados ou que passa por link simbólico |

A aba mostra os últimos 300 registros. As transferências dos equipamentos não ficam aqui: estão no log do FTP, em [Operação](../operacao.md#logs).

<details>
<summary>Detalhe técnico — arquivo e eventos</summary>

- Rota `GET /atividade`.
- Os registros vêm de `DATA_DIR/painel/auditoria.log` (`0600`, do `root`). A lista completa de eventos, com o nome de cada um no arquivo, está em [Painel web](../painel.md#auditoria).
- O nome digitado em uma entrada recusada não é gravado: é comum a senha cair nesse campo por engano.
- Na foto, `172.29.5.1` é o endereço do host visto pela rede interna da stack fotografada: o acesso partiu do próprio servidor.

</details>

---

<a name="como-foram-feitas"></a>

## 🎞️ Como as fotos foram feitas

Capturas reais do painel no ar, feitas com Playwright no Google Chrome, em 1440×900 e tema escuro. A stack fotografada foi uma instalação de demonstração, separada da instalação em uso: subiu em `127.0.0.4`, com nomes de container, rede, pasta de dados e segredos próprios, recebeu usuários e arquivos de exemplo por FTPS e foi removida depois das fotos. Na coluna **Pasta no host**, a demonstração mostra a pasta padrão do `.env.example`, no lugar da pasta temporária em que ela de fato subiu.

Nenhuma senha aparece nas imagens: os campos de senha são mascarados pelo navegador e a senha gerada foi trocada por `<REDACTED>` antes da captura. As impressões digitais são dos certificados autoassinados da instalação fotografada; cada instalação gera os seus. O e-mail do contato de segurança é um endereço de exemplo.

Para abrir as imagens fora do GitHub, com aproximar e mover: [`imagens/visualizador.html`](imagens/visualizador.html).

---

⬅️ [Painel web](../painel.md) · 🏠 [Documentação](../README.md) · ➡️ [Solução de problemas](../solucao-de-problemas.md)
