# 🔑 Segredos

↩ [README do projeto](../README.md) · [📚 Índice da doc](README.md)

> O que fica em [`.secrets/`](../.secrets/) (fora do Git), quem gera cada arquivo e quais você preenche.

O `deploy.sh` cria `ftp_password.txt` com uma senha forte (`openssl rand -base64 36`,
permissão `0600`) na primeira execução, se o arquivo não existir ou estiver vazio.

Para usar uma senha própria, grave-a aqui antes do primeiro deploy — mínimo de
12 caracteres. Arquivos `.txt` desta pasta são ignorados pelo Git.
