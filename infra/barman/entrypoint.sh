#!/bin/sh
# Keeps WAL streaming from the primary and takes a base backup whenever none exists.
# Barman only connects out; nothing in this container listens.
set -eu

if [ "$(id -u)" = 0 ]; then
  install -d -o postgres -g postgres -m 700 /var/lib/barman /var/log/barman
  touch /var/log/barman/barman.log
  chown postgres:postgres /var/log/barman/barman.log
  (umask 077 && printf '*:*:*:barman:%s\n' "$BARMAN_PASSWORD" > "$PGPASSFILE")
  chown postgres:postgres "$PGPASSFILE"
  tail -F /var/log/barman/barman.log &
  exec gosu postgres sh "$0" "$@"
fi

while :; do
  # Starts pg_receivewal if it isn't running, and applies the retention policy.
  barman -q cron || true
  if [ -z "$(barman list-backups --minimal onprem 2>/dev/null)" ]; then
    echo "No base backup yet; taking one"
    barman switch-wal --force --archive onprem || true
    barman backup --wait onprem || true
  fi
  sleep 30
done
