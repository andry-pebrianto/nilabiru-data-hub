#!/bin/bash
set -e

DB_NAME="${NEXTCLOUD_DB_NAME:-nextcloud}"

echo "Checking if database '${DB_NAME}' exists..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
  SELECT 'CREATE DATABASE "${DB_NAME}" OWNER ${POSTGRES_USER}'
  WHERE NOT EXISTS (
    SELECT FROM pg_database WHERE datname = '${DB_NAME}'
  )\gexec

  \c ${DB_NAME}

  GRANT ALL PRIVILEGES ON DATABASE "${DB_NAME}" TO ${POSTGRES_USER};
  GRANT ALL PRIVILEGES ON SCHEMA public TO ${POSTGRES_USER};
  ALTER SCHEMA public OWNER TO ${POSTGRES_USER};
EOSQL

echo "Database '${DB_NAME}' is ready."