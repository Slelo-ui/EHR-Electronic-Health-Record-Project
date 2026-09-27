# Barman plus the PostgreSQL 18 client tools it drives (pg_basebackup, pg_receivewal).
# Built on postgres:18 so those tools always match the server, and so Barman runs as the same
# postgres user (uid 999) that owns any cluster it restores.
FROM postgres:18

# Barman runs `file` on every WAL file it archives, and `barman recover` copies with rsync,
# so both are installed explicitly.
RUN apt-get update \
 && apt-get install -y --no-install-recommends barman file rsync \
 && rm -rf /var/lib/apt/lists/*

# Written from BARMAN_PASSWORD at start-up; set here so `docker compose exec` sessions use it too.
ENV PGPASSFILE=/tmp/barman.pgpass

COPY barman.conf /etc/barman.conf
COPY onprem.conf /etc/barman.d/onprem.conf
COPY entrypoint.sh /usr/local/bin/barman-entrypoint.sh

ENTRYPOINT ["/bin/sh", "/usr/local/bin/barman-entrypoint.sh"]
