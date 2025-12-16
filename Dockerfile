FROM debian:13-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    gettext-base \
    samba \
    smbclient \
    sssd \
    sssd-tools \
    sssd-ldap \
    libnss-sss \
    libpam-sss \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

COPY rootfs /docker-entrypoint.d
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY healthcheck.sh /healthcheck.sh

EXPOSE 445

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-n"]
