set -e

DB_NAME="${N8N_DB_NAME:-n8n}"

echo "Checking if database '${DB_NAME}' exists..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<EOSQL
  SELECT 'CREATE DATABASE "${DB_NAME}"'
  WHERE NOT EXISTS (
    SELECT FROM pg_database WHERE datname = '${DB_NAME}'
  )\gexec
EOSQL

echo "Database '${DB_NAME}' is ready."