#!/bin/bash
set -e

DB_NAME="${NEXTCLOUD_DB_NAME:-nextcloud}"

echo "Checking if database '${DB_NAME}' exists..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
  SELECT 'CREATE DATABASE "${DB_NAME}" OWNER ${POSTGRES_USER}'
  WHERE NOT EXISTS (
    SELECT FROM pg_database WHERE datname = '${DB_NAME}'
  )\gexec
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "${DB_NAME}" <<EOSQL
  GRANT ALL PRIVILEGES ON DATABASE "${DB_NAME}" TO ${POSTGRES_USER};
  ALTER SCHEMA public OWNER TO ${POSTGRES_USER};
  GRANT ALL ON SCHEMA public TO ${POSTGRES_USER};

  -- Ini yang paling penting: cover tabel yang dibuat di masa depan
  ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON TABLES TO ${POSTGRES_USER};
  ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON SEQUENCES TO ${POSTGRES_USER};
EOSQL

echo "Database '${DB_NAME}' is ready."