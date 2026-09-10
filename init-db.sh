#!/bin/bash
set -e

# Daftar database yang perlu diinisialisasi
DATABASES=(
  "${NEXTCLOUD_DB_NAME:-nextcloud}"
  "${GITEA_DB_NAME:-gitea}"
)

for DB_NAME in "${DATABASES[@]}"; do
  echo "Checking if database '${DB_NAME}' exists..."

  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
  SELECT 'CREATE DATABASE "${DB_NAME}" OWNER "${POSTGRES_USER}"'
  WHERE NOT EXISTS (
    SELECT FROM pg_database WHERE datname = '${DB_NAME}'
  )\gexec
EOSQL

  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "${DB_NAME}" <<EOSQL
  ALTER SCHEMA public OWNER TO "${POSTGRES_USER}";
  GRANT ALL ON SCHEMA public TO "${POSTGRES_USER}";

  GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "${POSTGRES_USER}";
  GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO "${POSTGRES_USER}";

  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO "${POSTGRES_USER}";
  ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO "${POSTGRES_USER}";
EOSQL

  echo "Database '${DB_NAME}' is ready."
  echo "----------------------------------------"
done