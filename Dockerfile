# SPDX-License-Identifier: Apache-2.0
# Três imagens sobre o mesmo Debian 13 fixado por digest: `nginx` (frente web do painel), `painel`
# (administração web) e `ftp` (servidor). O alvo padrão é o `ftp`.
ARG DEBIAN=debian:trixie-slim@sha256:a99cfc517144bc59b1978475ec53b46ecabec7e43635402ee5b77cc54cd1b20a


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
COPY --chmod=0644 nginx/erro/pedido.txt nginx/erro/rede.txt nginx/erro/taxa.txt nginx/erro/painel.txt /usr/share/allsafe-nginx/_erro/
# Arquivos estáticos do painel (pasta web/): quem serve é o nginx, sem passar pelo painel.
COPY --chmod=0644 web/estilo.css web/robots.txt /usr/share/allsafe-nginx/web/
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
    && mkdir -p /data /auth /etc/ssl/private /usr/local/lib/allsafe /usr/share/doc/allsafe-ftp-stack \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=0644 scripts/rede-privada.sh /usr/local/lib/allsafe/rede-privada.sh
COPY --chmod=0755 ftp/usuario.sh /usr/local/sbin/allsafe-ftp-user
# Licença e autoria acompanham as imagens do ftp e do painel (Apache-2.0, seção 4).
COPY --chmod=0644 LICENSE NOTICE /usr/share/doc/allsafe-ftp-stack/


FROM base AS painel

LABEL org.opencontainers.image.title="AllSafe FTP - painel" \
      org.opencontainers.image.description="Painel web da allsafe-ftp-stack: atras do nginx, sem porta de rede" \
      org.opencontainers.image.vendor="AllSafe"

# Só a biblioteca padrão do Python; a raiz do container é somente leitura, então nada de .pyc.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && mkdir -p /painel /nginx /opt/painel \
    && rm -rf /var/lib/apt/lists/*

# Os módulos do painel ficam lado a lado: o servidor.py é o ponto de entrada e importa os demais.
COPY --chmod=0644 painel/*.py VERSION /opt/painel/
COPY --chmod=0755 painel/entrypoint.sh /usr/local/sbin/allsafe-painel-entrypoint

# Sem EXPOSE: o painel não escuta em porta de rede, só no soquete Unix que o nginx abre.
ENTRYPOINT ["/usr/local/sbin/allsafe-painel-entrypoint"]


FROM base AS ftp

LABEL org.opencontainers.image.title="AllSafe FTP" \
      org.opencontainers.image.description="Pure-FTPd isolado com usuarios virtuais presos a propria pasta" \
      org.opencontainers.image.vendor="AllSafe"

COPY --chmod=0755 ftp/entrypoint.sh /usr/local/sbin/allsafe-ftp-entrypoint
COPY --chmod=0755 ftp/saude.sh /usr/local/sbin/allsafe-ftp-saude
COPY --chmod=0755 ftp/porteiro-tls.sh /usr/local/sbin/allsafe-ftp-porteiro-tls

EXPOSE 2121 30000-30049

ENTRYPOINT ["/usr/local/sbin/allsafe-ftp-entrypoint"]
