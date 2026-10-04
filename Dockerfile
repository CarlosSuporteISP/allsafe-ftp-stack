FROM debian:bookworm-slim@sha256:88200866dfff7ea7f5cbcb6ec7c8a701889efe6fe859fe64d6990e4b07ea4171

LABEL org.opencontainers.image.title="AllSafe FTP" \
      org.opencontainers.image.description="Pure-FTPd isolado com TLS e usuarios virtuais" \
      org.opencontainers.image.vendor="AllSafe"

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
COPY --chmod=0755 scripts/entrypoint.sh /usr/local/sbin/allsafe-ftp-entrypoint
COPY --chmod=0755 scripts/ftp-user.sh /usr/local/sbin/allsafe-ftp-user

EXPOSE 2121 30000-30049

ENTRYPOINT ["/usr/local/sbin/allsafe-ftp-entrypoint"]
