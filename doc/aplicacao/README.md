# 📸 Fotos da aplicação — allsafe-ftp-stack

↩ [README do projeto](../../README.md) · [Índice da documentação](../README.md)

## 💡 Em poucas palavras

Todas as telas do painel web, menu por menu, com a foto de cada uma e a explicação do que dá para fazer nela. As fotos são capturas reais da versão **0.8.0**, em tema escuro (o único do painel), com usuários de exemplo: `olt-centro`, `switch-core` e `roteador-borda`. Clique em qualquer foto para abri-la em tamanho real.

O painel tem uma tela de entrada e quatro abas: Visão geral, Usuários, Segurança e Atividade. Como abrir, trocar a senha e o que protege o painel está em [Painel web](../painel.md).

> 🧱 **Uso só em rede privada:** o painel abre apenas em IP privado, atrás de firewall, nunca na internet. Veja [Segurança](../seguranca.md#rede-privada).

<details>
<summary>Sumário — clique para expandir</summary>

[Entrar](#entrar) · [Visão geral](#visao-geral) · [Usuários](#usuarios) · [Segurança](#seguranca) · [Atividade](#atividade) · [Como as fotos foram feitas](#como-foram-feitas)

</details>

---

<a name="entrar"></a>

## 🚪 Entrar

<a href="imagens/entrar.png"><img src="imagens/entrar.png" alt="Tela de entrada do painel, com o campo Senha do painel, o botão Entrar e o aviso de uso só em rede privada" width="100%"></a>

<sub><b>v0.8.0</b> · tela de entrada · captura de 2026-10-04</sub>

**Para que serve:** conferir a senha de administrador antes de mostrar qualquer dado da stack.

**Como chegar:** abra `https://<endereço do painel>:8443` no navegador. Sem sessão, qualquer endereço do painel leva a esta tela.

| Item da tela | O que faz |
|---|---|
| **Senha do painel** | Recebe a senha de administrador. A da primeira instalação está em `.secrets/painel_password.txt` |
| **Entrar** | Confere a senha e abre a aba Visão geral |
| Aviso de rede privada | Lembra que o painel é só para rede interna, atrás de firewall |

<details>
<summary>Entrar ➜ senha recusada — clique para expandir</summary>

### Entrar ➜ Senha recusada

<a href="imagens/entrar-recusada.png"><img src="imagens/entrar-recusada.png" alt="Tela de entrada com a mensagem Não foi possível entrar acima do campo da senha" width="100%"></a>

<sub><b>v0.8.0</b> · tela de entrada, senha recusada · captura de 2026-10-04</sub>

| Mensagem | Quando aparece | O que fazer |
|---|---|---|
| Não foi possível entrar. | A senha está errada | Conferir a senha e tentar de novo |
| Muitas tentativas. Aguarde alguns minutos e tente de novo. | Cinco senhas erradas do mesmo endereço em 15 minutos | Esperar o bloqueio passar; a senha certa também é recusada enquanto ele dura |
| A página expirou. Tente de novo. | A tela ficou aberta tempo demais antes do envio | Enviar de novo |

</details>

<details>
<summary>Detalhe técnico — entrada e sessão</summary>

- Rota `GET /entrar` mostra o formulário; `POST /entrar` confere a senha contra o hash `scrypt` de `/run/secrets/painel_password_hash`.
- Resposta `401` para senha errada, `429` para endereço bloqueado e `400` para formulário expirado. Cada caso grava `entrada_falha` ou `entrada_bloqueada` na [auditoria](../painel.md#auditoria).
- A sessão fica no cookie `__Host-sessao` (`Secure`, `HttpOnly`, `SameSite=Strict`) e encerra com 15 minutos sem uso ou em 8 horas.
- O envio só é aceito quando parte do próprio painel: o cabeçalho `Origin` tem de ser o endereço do painel. Detalhes em [Painel web](../painel.md#protecoes).

</details>

---

<a name="visao-geral"></a>

## 📊 Visão geral

<a href="imagens/visao-geral.png"><img src="imagens/visao-geral.png" alt="Aba Visão geral com os cartões Servidor FTP, Usuários, Espaço usado, Último envio e Certificado do FTP, e a tabela de dados para configurar o equipamento" width="100%"></a>

<sub><b>v0.8.0</b> · menu Visão geral · captura de 2026-10-04</sub>

**Para que serve:** ver de uma vez se o FTP está no ar e quais dados digitar no equipamento que vai mandar o backup.

**Como chegar:** é a primeira tela depois da entrada; menu do topo ➜ **Visão geral**.

| Item da tela | O que mostra |
|---|---|
| **Servidor FTP** | `No ar` ou `Fora do ar`, e o modo de TLS em uso |
| **Usuários** | Quantidade de usuários do FTP, com atalho para a lista |
| **Espaço usado** | Soma das pastas dos usuários e o espaço livre no disco |
| **Último envio** | Data do arquivo mais novo entre todas as pastas |
| **Certificado do FTP** | Validade do certificado, com atalho para a impressão digital |
| **Dados para configurar o equipamento** | Servidor, porta de controle, portas passivas e protocolo: o que preencher no equipamento |

Nada é alterado por esta aba.

> ⚠️ Com `FTP_TLS_MODE` em `0` ou `1`, esta aba abre com um alerta no topo: o FTP está aceitando senha e arquivo em texto puro. Veja [Equipamento sem TLS](../seguranca.md#ftp-sem-tls).

<details>
<summary>Detalhe técnico — de onde vem cada número</summary>

- Rota `GET /`.
- `No ar` é a resposta da porta de controle do serviço `ftp`, pela rede interna da stack (`ftp:2121`).
- Usuários vêm do PureDB (`DATA_DIR/auth`); espaço, quantidade de arquivos e último envio são lidos de `DATA_DIR/dados`.
- Servidor, porta e faixa passiva são os valores de `FTP_PUBLIC_IP`, `FTP_PORT` e `FTP_PASSIVE_PORT_*` do `.env`: veja [Configuração](../configuracao.md).

</details>

---

<a name="usuarios"></a>

## 👥 Usuários

<a href="imagens/usuarios.png"><img src="imagens/usuarios.png" alt="Aba Usuários com o botão Novo usuário e a lista de usuários: pasta no host, uso, arquivos, último envio e as ações Trocar senha e Remover" width="100%"></a>

<sub><b>v0.8.0</b> · menu Usuários · captura de 2026-10-04</sub>

**Para que serve:** criar a conta de cada equipamento, trocar a senha e remover a conta, sem linha de comando.

**Como chegar:** menu do topo ➜ **Usuários**.

| Item da tela | O que faz |
|---|---|
| **Novo usuário** | Abre o formulário de cadastro |
| Usuário | Nome da conta. A etiqueta `inicial` marca o usuário criado na instalação (`FTP_USER`) |
| Pasta no host | Onde os arquivos desse usuário ficam no servidor |
| Uso · Arquivos · Último envio | Espaço ocupado, quantidade de arquivos e data do envio mais recente |
| **Trocar senha** | Abre o formulário de troca de senha daquele usuário |
| **Remover** | Abre a confirmação de remoção daquele usuário |

O usuário inicial não tem ações: a senha dele vem de `.secrets/ftp_password.txt`. Veja [Segredos](../segredos.md#trocar-a-senha).

<details>
<summary>Usuários ➜ Novo usuário — clique para expandir</summary>

### Usuários ➜ Novo usuário

<a href="imagens/usuarios-novo.png"><img src="imagens/usuarios-novo.png" alt="Formulário Novo usuário com os campos Nome do usuário, Senha e Repita a senha, e os botões Criar usuário e Cancelar" width="100%"></a>

<sub><b>v0.8.0</b> · menu Usuários, formulário Novo usuário · captura de 2026-10-04</sub>

| Campo | Obrigatório | O que preencher |
|---|---|---|
| Nome do usuário | Sim | Letras minúsculas, números, `_` e `-`; começa com letra ou `_`; até 32 caracteres |
| Senha | Não | 12 caracteres ou mais. Em branco, o painel gera uma senha forte |
| Repita a senha | Só com a senha preenchida | A mesma senha |

**Resultado esperado:** a lista volta com a mensagem `Usuário criado.` e o usuário já entra por FTPS, sem reiniciar o FTP.

</details>

<details>
<summary>Usuários ➜ Novo usuário recusado — clique para expandir</summary>

### Usuários ➜ Novo usuário recusado

<a href="imagens/usuarios-novo-recusado.png"><img src="imagens/usuarios-novo-recusado.png" alt="Formulário Novo usuário com a mensagem As duas senhas não são iguais acima dos campos" width="100%"></a>

<sub><b>v0.8.0</b> · menu Usuários, cadastro recusado · captura de 2026-10-04</sub>

O painel devolve o formulário com o motivo no topo e nada é criado.

| Mensagem | Motivo |
|---|---|
| Nome inválido. Veja a regra abaixo do campo. | O nome foge da regra de letras, números, `_` e `-` |
| Já existe um usuário com este nome. | O nome já está em uso |
| As duas senhas não são iguais. | Os dois campos de senha diferem |
| A senha deve ter de 12 a 128 caracteres. | Senha curta ou longa demais |

</details>

<details>
<summary>Usuários ➜ Senha gerada pelo painel — clique para expandir</summary>

### Usuários ➜ Senha gerada pelo painel

<a href="imagens/usuarios-senha-gerada.png"><img src="imagens/usuarios-senha-gerada.png" alt="Tela Usuário criado com a senha gerada pelo painel, aqui substituída por REDACTED, e o aviso de que ela não será mostrada de novo" width="100%"></a>

<sub><b>v0.8.0</b> · menu Usuários, senha gerada · captura de 2026-10-04</sub>

Aparece quando os dois campos de senha ficam em branco, no cadastro ou na troca de senha. A senha é mostrada **uma única vez**: copie para o equipamento ou para o cofre de senhas antes de sair da tela. Na foto, o valor foi trocado por `<REDACTED>`.

</details>

<details>
<summary>Usuários ➜ Trocar senha — clique para expandir</summary>

### Usuários ➜ Trocar senha

<a href="imagens/usuarios-trocar-senha.png"><img src="imagens/usuarios-trocar-senha.png" alt="Formulário Trocar senha do usuário switch-core, com os campos Senha e Repita a senha e os botões Trocar senha e Cancelar" width="100%"></a>

<sub><b>v0.8.0</b> · menu Usuários, formulário Trocar senha · captura de 2026-10-04</sub>

| Campo | Obrigatório | O que preencher |
|---|---|---|
| Senha | Não | 12 caracteres ou mais. Em branco, o painel gera uma senha forte |
| Repita a senha | Só com a senha preenchida | A mesma senha |

**Resultado esperado:** a lista volta com a mensagem `Senha trocada.` e a senha antiga deixa de valer no próximo login do equipamento.

</details>

<details>
<summary>Usuários ➜ Remover — clique para expandir</summary>

### Usuários ➜ Remover

<a href="imagens/usuarios-remover.png"><img src="imagens/usuarios-remover.png" alt="Tela Remover usuário pedindo confirmação, com o aviso de que os arquivos não são apagados e os botões Sim, remover o usuário e Cancelar" width="100%"></a>

<sub><b>v0.8.0</b> · menu Usuários, confirmação de remoção · captura de 2026-10-04</sub>

| Item da tela | O que faz |
|---|---|
| Aviso dos arquivos | Mostra quantos arquivos o usuário tem e em que pasta eles continuam |
| **Sim, remover o usuário** | Apaga a conta: o login deixa de funcionar na hora |
| **Cancelar** | Volta para a lista sem alterar nada |

<a href="imagens/usuarios-removido.png"><img src="imagens/usuarios-removido.png" alt="Aba Usuários depois da remoção, com a mensagem Usuário removido, os arquivos continuam na pasta" width="100%"></a>

<sub><b>v0.8.0</b> · menu Usuários, depois da remoção · captura de 2026-10-04</sub>

**Resultado esperado:** a lista volta com a mensagem `Usuário removido. Os arquivos continuam na pasta.` A pasta do usuário fica em `DATA_DIR/dados/<usuario>` até alguém apagá-la no servidor.

</details>

<details>
<summary>Detalhe técnico — rotas e comando usado</summary>

- Rotas: `GET /usuarios`, `/usuarios/novo`, `/usuarios/senha?usuario=<nome>` e `/usuarios/remover?usuario=<nome>`; o envio de cada formulário é um `POST` na mesma rota, com o token CSRF da sessão.
- O painel chama o mesmo `allsafe-ftp-user` do [`manage-user.sh`](../../manage-user.sh): painel e linha de comando alteram as mesmas contas. Veja [Operação](../operacao.md#usuarios).
- Cada alteração grava `usuario_criado`, `senha_trocada` ou `usuario_removido` na [auditoria](../painel.md#auditoria), sem a senha.
- A senha gerada tem 32 caracteres aleatórios e não fica guardada: só o hash vai para o PureDB.

</details>

---

<a name="seguranca"></a>

## 🔐 Segurança

<a href="imagens/seguranca.png"><img src="imagens/seguranca.png" alt="Aba Segurança com a conferência da instalação: endereços do FTP e do painel, modo TLS, impressão digital dos dois certificados, redes permitidas, regras da sessão e o lembrete do firewall" width="100%"></a>

<sub><b>v0.8.0</b> · menu Segurança · captura de 2026-10-04</sub>

**Para que serve:** conferir, em uma tela, se a instalação está dentro do que a stack exige: rede privada, TLS, certificados válidos e painel isolado.

**Como chegar:** menu do topo ➜ **Segurança**.

| Item da tela | O que mostra |
|---|---|
| Endereço do FTP · IP anunciado no modo passivo | Onde o FTP escuta e o IP que ele informa ao cliente; os dois têm de ser privados |
| TLS do FTP | O modo em uso (`FTP_TLS_MODE`) |
| Certificado do FTP · Certificado do painel | Validade e impressão digital SHA-256, para comparar com a que o cliente FTP e o navegador mostram |
| Endereço do painel · Frente web | Onde o nginx publica o painel e como ele repassa os pedidos |
| Quem pode abrir o painel | As redes de `PAINEL_REDES_PERMITIDAS` |
| Sessão | Tempo sem uso, tempo máximo e bloqueio por senha errada |
| Container do painel | Raiz somente leitura e sem acesso ao Docker do host |
| Firewall do host | Lembrete: o painel não enxerga o firewall; a conferência é de quem administra o servidor |

Nada é alterado por esta aba. As regras de firewall de exemplo estão em [Segurança](../seguranca.md#rede-privada).

<details>
<summary>Detalhe técnico — o que cada linha lê</summary>

- Rota `GET /seguranca`.
- As impressões digitais são calculadas dos arquivos `DATA_DIR/certs` (FTP) e `DATA_DIR/painel/tls` (painel), os mesmos que os serviços usam.
- As linhas com endereço e rede vêm do `.env`; a stack recusa subir com valor que não seja privado, então um valor público nunca chega a aparecer aqui.
- A última linha não tem marca de conferido de propósito: nenhum container da stack lê as regras de firewall do host.

</details>

---

<a name="atividade"></a>

## 📜 Atividade

<a href="imagens/atividade.png"><img src="imagens/atividade.png" alt="Aba Atividade com os registros do painel: data, endereço de origem, o que aconteceu e o detalhe, como usuário criado e senha recusada" width="100%"></a>

<sub><b>v0.8.0</b> · menu Atividade · captura de 2026-10-04</sub>

**Para que serve:** saber quem entrou no painel, de onde, e o que foi alterado.

**Como chegar:** menu do topo ➜ **Atividade**.

| Coluna | O que mostra |
|---|---|
| Quando | Data e hora do registro, do mais novo para o mais antigo |
| De onde | Endereço de quem fez o pedido |
| O que aconteceu | Entrada, senha recusada, saída, usuário criado, senha trocada, usuário removido ou pedido recusado |
| Detalhe | O usuário alterado e se a senha foi informada ou gerada. Senha e token nunca aparecem |

A aba mostra os últimos 300 registros. As transferências dos equipamentos não ficam aqui: estão no log do FTP, em [Operação](../operacao.md#logs).

<details>
<summary>Detalhe técnico — arquivo e eventos</summary>

- Rota `GET /atividade`.
- Os registros vêm de `DATA_DIR/painel/auditoria.log` (`0600`, do `root`). A lista completa de eventos está em [Painel web](../painel.md#auditoria).
- Na foto, `172.29.1.1` é o endereço do host visto pela rede interna da stack: o acesso partiu do próprio servidor.

</details>

---

<a name="como-foram-feitas"></a>

## 🎞️ Como as fotos foram feitas

Capturas reais da instalação no ar, feitas com Playwright no Google Chrome, em 1440×900 e tema escuro. Os usuários de exemplo foram criados pelo próprio painel, receberam arquivos por FTPS e foram removidos depois das fotos.

Nenhuma senha aparece nas imagens: os campos de senha são mascarados pelo navegador e a senha gerada foi trocada por `<REDACTED>` antes da captura. As impressões digitais são dos certificados autoassinados da instalação fotografada; cada instalação gera os seus.

Para abrir as imagens fora do GitHub, com aproximar e mover: [`imagens/visualizador.html`](imagens/visualizador.html).

---

⬅️ [Painel web](../painel.md) · 🏠 [Documentação](../README.md) · ➡️ [Solução de problemas](../solucao-de-problemas.md)
