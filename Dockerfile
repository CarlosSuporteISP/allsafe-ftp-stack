# SPDX-License-Identifier: Apache-2.0
# Três imagens sobre o mesmo Debian 13 fixado por digest: `nginx` (frente web do painel), `painel`
# (administração web) e `ftp` (servidor). O alvo padrão é o `ftp`.
ARG DEBIAN=debian:trixie-slim@sha256:a99cfc517144bc59b1978475ec53b46ecabec7e43635402ee5b77cc54cd1b20a
# rclone da imagem do painel: a versão fica aqui e a soma de cada arquitetura, nos dois estágios `rclone-*`.
ARG RCLONE=1.75.2


# Frente web: só nginx e openssl, sem nada do FTP. Roda sem root (uid e gid 10001).
FROM ${DEBIAN} AS nginx

LABEL org.opencontainers.image.title="AllSafe FTP - nginx" \
      org.opencontainers.image.description="Frente web do painel da allsafe-ftp-stack: HTTPS, redes permitidas e arquivos estaticos" \
      org.opencontainers.image.vendor="AllSafe"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx openssl \
    && groupadd --gid 10001 frente \
    && useradd --uid 10001 --gid frente --home-dir /nonexistent \
       --shell /usr/sbin/nologin --no-create-home frente \
    && mkdir -p /usr/local/lib/allsafe /etc/allsafe-nginx /usr/share/allsafe-nginx/_erro /usr/share/allsafe-nginx/web/marca \
       /usr/share/doc/allsafe-ftp-stack \
    && rm -rf /var/lib/apt/lists/* /etc/nginx/sites-enabled /etc/nginx/sites-available /var/www/html

# As pastas de destino já existem (0755): o --chmod de um COPY vale também para a pasta que ele cria,
# e uma pasta 0644 não é atravessada por quem não é root.
COPY --chmod=0644 scripts/rede-privada.sh /usr/local/lib/allsafe/rede-privada.sh
COPY --chmod=0644 nginx/nginx.conf.modelo nginx/cabecalhos.conf /etc/allsafe-nginx/
COPY --chmod=0644 nginx/erro/pedido.txt nginx/erro/rede.txt nginx/erro/taxa.txt nginx/erro/painel.txt nginx/erro/envio.txt /usr/share/allsafe-nginx/_erro/
# Arquivos estáticos do painel (pasta web/): quem serve é o nginx, sem passar pelo painel.
COPY --chmod=0644 web/estilo.css web/robots.txt /usr/share/allsafe-nginx/web/
# Cópia comprimida do estilo, feita uma vez aqui: o nginx a entrega a quem aceita gzip, sem comprimir a cada pedido.
RUN gzip -9 -k -n /usr/share/allsafe-nginx/web/estilo.css
# Marca: só os arquivos gerados por scripts/gerar-marca.sh; as fontes (web/marca/fonte/) não entram na imagem.
COPY --chmod=0644 web/marca/favicon.ico web/marca/*.png /usr/share/allsafe-nginx/web/marca/
# Licença e autoria acompanham a imagem (Apache-2.0, seção 4).
COPY --chmod=0644 LICENSE NOTICE /usr/share/doc/allsafe-ftp-stack/
COPY --chmod=0755 nginx/entrypoint.sh /usr/local/sbin/allsafe-nginx-entrypoint
COPY --chmod=0755 nginx/saude.sh /usr/local/sbin/allsafe-nginx-saude

USER 10001:10001

EXPOSE 8443

ENTRYPOINT ["/usr/local/sbin/allsafe-nginx-entrypoint"]


FROM ${DEBIAN} AS base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       openssl pure-ftpd-common pure-ftpd \
    && groupadd --gid 10000 ftpdata \
    && useradd --uid 10000 --gid ftpdata --home-dir /nonexistent \
       --shell /usr/sbin/nologin --no-create-home ftpdata \
    # Perfis do FTP: o envio grava como outro usuário do mesmo grupo; a leitura e o só envio ficam fora do grupo.
    && useradd --uid 10002 --gid ftpdata --home-dir /nonexistent \
       --shell /usr/sbin/nologin --no-create-home ftpenvio \
    && groupadd --gid 10003 ftpleitura \
    && useradd --uid 10003 --gid ftpleitura --home-dir /nonexistent \
       --shell /usr/sbin/nologin --no-create-home ftpleitura \
    && groupadd --gid 10004 ftpsoenvio \
    && useradd --uid 10004 --gid ftpsoenvio --home-dir /nonexistent \
       --shell /usr/sbin/nologin --no-create-home ftpsoenvio \
    && mkdir -p /data /auth /etc/ssl/private /usr/local/lib/allsafe /usr/share/doc/allsafe-ftp-stack \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=0644 scripts/rede-privada.sh /usr/local/lib/allsafe/rede-privada.sh
COPY --chmod=0755 ftp/usuario.sh /usr/local/sbin/allsafe-ftp-user
COPY --chmod=0644 ftp/entrada.pl /usr/local/lib/allsafe/entrada.pl
COPY --chmod=0644 ftp/endereco.pl /usr/local/lib/allsafe/endereco.pl
# Licença e autoria acompanham as imagens do ftp e do painel (Apache-2.0, seção 4).
COPY --chmod=0644 LICENSE NOTICE /usr/share/doc/allsafe-ftp-stack/


# rclone: o destino da aba Destinos para o que o S3 não cobre (SFTP, WebDAV e nuvens de arquivos). Binário oficial do
# projeto, com a versão no endereço e a soma SHA-256 fixa, um estágio por arquitetura: se o arquivo publicado mudar,
# a construção falha. Trocar de versão é trocar o `ARG RCLONE` e as duas somas, com nova conferência.
FROM scratch AS rclone-amd64
ARG RCLONE
ADD --checksum=sha256:349ac8fba6ff65d6247043f1750cdcb518ec5d500ef91463a10d37c0ccdf3702 \
    https://github.com/rclone/rclone/releases/download/v${RCLONE}/rclone-v${RCLONE}-linux-amd64.zip /rclone.zip

FROM scratch AS rclone-arm64
ARG RCLONE
ADD --checksum=sha256:7e1e8d69654941b7b7df84ee74c5f7fb09cce7d5496947fb7bf16b55ff427d10 \
    https://github.com/rclone/rclone/releases/download/v${RCLONE}/rclone-v${RCLONE}-linux-arm64.zip /rclone.zip

FROM rclone-${TARGETARCH} AS rclone-zip


FROM base AS painel

LABEL org.opencontainers.image.title="AllSafe FTP - painel" \
      org.opencontainers.image.description="Painel web da allsafe-ftp-stack: atras do nginx, sem porta de rede" \
      org.opencontainers.image.vendor="AllSafe"

# Só a biblioteca padrão do Python; a raiz do container é somente leitura, então nada de .pyc.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# ca-certificates: as autoridades que o painel aceita ao falar HTTPS com os destinos de fora (S3 e bot do Telegram).
# age: cifra a cópia do sistema que o painel envia para o S3, com a chave pública da cópia (a mesma do scripts/backup.sh).
RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 ca-certificates age \
    && mkdir -p /painel /nginx /segredos /certs /opt/painel \
    && rm -rf /var/lib/apt/lists/*

# Do pacote do rclone entram só o binário e o texto da licença dele (MIT). O pacote é aberto pelo Python da imagem, e
# a construção para se o binário não responder com a versão pedida. Nada é baixado nem atualizado em execução.
ARG RCLONE
RUN --mount=type=bind,from=rclone-zip,source=/rclone.zip,target=/tmp/rclone.zip python3 -I - "${RCLONE}" <<'EOF'
import os, shutil, subprocess, sys, zipfile
pacote = zipfile.ZipFile('/tmp/rclone.zip')
binario, = [nome for nome in pacote.namelist() if nome.endswith('/rclone')]
leia, = [nome for nome in pacote.namelist() if nome.endswith('/README.txt')]
with pacote.open(binario) as origem, open('/usr/local/bin/rclone', 'wb') as destino:
    shutil.copyfileobj(origem, destino)
os.chmod('/usr/local/bin/rclone', 0o755)
texto = pacote.read(leia).decode('utf-8')
inicio = texto.rindex('\nLicense\n')
os.makedirs('/usr/share/doc/rclone', mode=0o755)
with open('/usr/share/doc/rclone/copyright', 'w', encoding='utf-8') as destino:
    destino.write(texto[inicio:texto.index('\nAuthors and contributors\n', inicio)].strip() + '\n')
versao = subprocess.run(['/usr/local/bin/rclone', 'version'], capture_output=True, text=True, check=True).stdout
assert versao.splitlines()[0] == 'rclone v' + sys.argv[1], versao
EOF

# Os módulos do painel ficam lado a lado: o servidor.py é o ponto de entrada e importa os demais.
COPY --chmod=0644 painel/*.py VERSION /opt/painel/
# Marca do estilo: o começo do SHA-256 do web/estilo.css vai no endereço dele em cada página. Estilo novo é endereço
# novo, e nem o navegador nem um proxy no caminho entregam o antigo. O arquivo não entra nesta imagem: é do nginx.
RUN --mount=type=bind,source=web/estilo.css,target=/tmp/estilo.css \
    sha256sum /tmp/estilo.css | cut -c1-12 > /opt/painel/ESTILO \
    && chmod 0644 /opt/painel/ESTILO
COPY --chmod=0755 painel/entrypoint.sh /usr/local/sbin/allsafe-painel-entrypoint

# Sem EXPOSE: o painel não escuta em porta de rede, só no soquete Unix que o nginx abre.
ENTRYPOINT ["/usr/local/sbin/allsafe-painel-entrypoint"]


FROM base AS ftp

LABEL org.opencontainers.image.title="AllSafe FTP" \
      org.opencontainers.image.description="Pure-FTPd isolado com usuarios virtuais presos a propria pasta" \
      org.opencontainers.image.vendor="AllSafe"

# age cifra e abre a cópia de segurança (scripts/backup.sh e scripts/restaurar.sh), que rodam nesta imagem.
RUN apt-get update \
    && apt-get install -y --no-install-recommends age \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=0755 ftp/entrypoint.sh /usr/local/sbin/allsafe-ftp-entrypoint
COPY --chmod=0755 ftp/saude.sh /usr/local/sbin/allsafe-ftp-saude
COPY --chmod=0755 ftp/porteiro.pl /usr/local/sbin/allsafe-ftp-porteiro
COPY --chmod=0755 ftp/vigia.pl /usr/local/sbin/allsafe-ftp-vigia

EXPOSE 2121 30000-30049

ENTRYPOINT ["/usr/local/sbin/allsafe-ftp-entrypoint"]
