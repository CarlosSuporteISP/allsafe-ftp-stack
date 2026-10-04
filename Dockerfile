# Uma base, duas imagens: `painel` (administração web) e `ftp` (servidor). O alvo padrão é o `ftp`.
FROM debian:bookworm-slim@sha256:88200866dfff7ea7f5cbcb6ec7c8a701889efe6fe859fe64d6990e4b07ea4171 AS base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates openssl procps pure-ftpd-common pure-ftpd \
    && groupadd --gid 10000 ftpdata \
    && useradd --uid 10000 --gid ftpdata --home-dir /nonexistent \
       --shell /usr/sbin/nologin --no-create-home ftpdata \
    && mkdir -p /data /auth /etc/ssl/private \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=0644 scripts/rede-privada.sh /usr/local/lib/allsafe/rede-privada.sh
COPY --chmod=0755 scripts/ftp-user.sh /usr/local/sbin/allsafe-ftp-user


FROM base AS painel

LABEL org.opencontainers.image.title="AllSafe FTP - painel" \
      org.opencontainers.image.description="Painel web da allsafe-ftp-stack: HTTPS, so para rede privada" \
      org.opencontainers.image.vendor="AllSafe"

# Só a biblioteca padrão do Python; a raiz do container é somente leitura, então nada de .pyc.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends python3 \
    && mkdir -p /painel /opt/painel \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=0644 painel/servidor.py painel/estilo.css VERSION /opt/painel/
COPY --chmod=0755 scripts/painel-entrypoint.sh /usr/local/sbin/allsafe-painel-entrypoint

EXPOSE 8443

ENTRYPOINT ["/usr/local/sbin/allsafe-painel-entrypoint"]


FROM base AS ftp

LABEL org.opencontainers.image.title="AllSafe FTP" \
      org.opencontainers.image.description="Pure-FTPd isolado com TLS e usuarios virtuais" \
      org.opencontainers.image.vendor="AllSafe"

COPY --chmod=0755 scripts/entrypoint.sh /usr/local/sbin/allsafe-ftp-entrypoint

EXPOSE 2121 30000-30049

ENTRYPOINT ["/usr/local/sbin/allsafe-ftp-entrypoint"]
