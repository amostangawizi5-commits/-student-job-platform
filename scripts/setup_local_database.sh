#!/usr/bin/env bash
set -euo pipefail

DB_USER="student_job_platform"
DB_PASSWORD="student_job_platform"
DB_NAME="student_job_platform"
DB_HOST="127.0.0.1"
DB_PORT="5432"

echo "Starting local PostgreSQL..."
sudo systemctl enable --now postgresql

echo "Creating or updating local database user..."
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname = '${DB_USER}'" | grep -q 1; then
  sudo -u postgres psql -v ON_ERROR_STOP=1 \
    -c "ALTER ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASSWORD}';"
else
  sudo -u postgres psql -v ON_ERROR_STOP=1 \
    -c "CREATE ROLE ${DB_USER} LOGIN PASSWORD '${DB_PASSWORD}';"
fi

echo "Creating local database if needed..."
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname = '${DB_NAME}'" | grep -q 1; then
  sudo -u postgres createdb -O "${DB_USER}" "${DB_NAME}"
else
  sudo -u postgres psql -v ON_ERROR_STOP=1 \
    -c "ALTER DATABASE ${DB_NAME} OWNER TO ${DB_USER};"
fi

echo "Testing local connection..."
PGPASSWORD="${DB_PASSWORD}" psql \
  -h "${DB_HOST}" \
  -p "${DB_PORT}" \
  -U "${DB_USER}" \
  -d "${DB_NAME}" \
  -v ON_ERROR_STOP=1 \
  -c "SELECT current_database(), current_user;"

echo "Local PostgreSQL is ready. Start the API with:"
echo "  cd backend && npm start"
