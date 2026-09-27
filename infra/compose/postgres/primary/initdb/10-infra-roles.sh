#!/bin/bash
# Executable on purpose: Docker Desktop on macOS can report a mounted script as executable even
# when it isn't, and the postgres entrypoint then fails trying to run it (exit 126).
# Runs once, as the superuser, when the primary's volume is first created.
# Creates the two infrastructure roles and their replication slots. App roles belong in db/policies.
# Runs in the postgres database: function grants are per database, and that's where Barman connects.
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
  -v replicator_password="$REPLICATOR_PASSWORD" \
  -v barman_password="$BARMAN_PASSWORD" <<'SQL'
-- Cloud hot standby: streams WAL and nothing else.
CREATE ROLE replicator WITH LOGIN REPLICATION PASSWORD :'replicator_password';

-- Barman: streams WAL and runs base backups. It can log in (Barman checks settings and calls the
-- backup functions) but has no table privileges, so it can't read PHI.
CREATE ROLE barman WITH LOGIN REPLICATION PASSWORD :'barman_password';
GRANT pg_read_all_settings, pg_read_all_stats, pg_checkpoint TO barman;
GRANT EXECUTE ON FUNCTION pg_backup_start(text, boolean) TO barman;
GRANT EXECUTE ON FUNCTION pg_backup_stop(boolean) TO barman;
GRANT EXECUTE ON FUNCTION pg_switch_wal() TO barman;
GRANT EXECUTE ON FUNCTION pg_create_restore_point(text) TO barman;

SELECT pg_create_physical_replication_slot('cloud_replica');
SELECT pg_create_physical_replication_slot('barman');
SQL
