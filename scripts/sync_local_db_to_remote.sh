#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${LOCAL_ENV_FILE:-$ROOT_DIR/backend/.env}"
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups}"
STAMP="$(date +%Y%m%d-%H%M%S)"

usage() {
  cat <<'USAGE'
Sync the local PostgreSQL database to the remote production database.

Required:
  REMOTE_DATABASE_URL=postgresql://...
  CONFIRM_RESTORE=replace-online-db

Optional:
  LOCAL_DATABASE_URL=postgresql://...
  LOCAL_ENV_FILE=/path/to/backend/.env
  BACKUP_DIR=/path/to/backup-dir

Example:
  REMOTE_DATABASE_URL="postgresql://..." \
  CONFIRM_RESTORE=replace-online-db \
  bash scripts/sync_local_db_to_remote.sh

This script backs up the remote database before replacing it.
USAGE
}

read_env_value() {
  local key="$1"
  if [[ ! -f "$ENV_FILE" ]]; then
    return 0
  fi

  grep -E "^[[:space:]]*${key}=" "$ENV_FILE" \
    | tail -n 1 \
    | sed -E "s/^[[:space:]]*${key}=//; s/^['\"]//; s/['\"]$//"
}

count_query="SELECT
  (SELECT COUNT(*) FROM users) AS users,
  (SELECT COUNT(*) FROM companies) AS companies,
  (SELECT COUNT(*) FROM students) AS students,
  (SELECT COUNT(*) FROM training) AS training,
  (SELECT COUNT(*) FROM applications) AS applications;"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -z "${REMOTE_DATABASE_URL:-}" ]]; then
  echo "REMOTE_DATABASE_URL is required." >&2
  usage >&2
  exit 1
fi

if [[ "${CONFIRM_RESTORE:-}" != "replace-online-db" ]]; then
  echo "Refusing to replace the remote database without confirmation." >&2
  echo "Set CONFIRM_RESTORE=replace-online-db when you are ready." >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"

LOCAL_DUMP="$BACKUP_DIR/local-$STAMP.dump"
REMOTE_BACKUP="$BACKUP_DIR/remote-before-$STAMP.dump"

echo "Checking local database..."
if [[ -n "${LOCAL_DATABASE_URL:-}" ]]; then
  psql "$LOCAL_DATABASE_URL" -c "$count_query"
  pg_dump "$LOCAL_DATABASE_URL" --format=custom --no-owner --no-acl --file="$LOCAL_DUMP"
else
  DB_USER="${DB_USER:-$(read_env_value DB_USER)}"
  DB_PASSWORD="${DB_PASSWORD:-$(read_env_value DB_PASSWORD)}"
  DB_HOST="${DB_HOST:-$(read_env_value DB_HOST)}"
  DB_PORT="${DB_PORT:-$(read_env_value DB_PORT)}"
  DB_NAME="${DB_NAME:-$(read_env_value DB_NAME)}"

  if [[ -z "$DB_USER" || -z "$DB_HOST" || -z "$DB_PORT" || -z "$DB_NAME" ]]; then
    echo "Local DB_* values are incomplete. Set LOCAL_DATABASE_URL or DB_USER/DB_PASSWORD/DB_HOST/DB_PORT/DB_NAME." >&2
    exit 1
  fi

  PGPASSWORD="$DB_PASSWORD" psql \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --username="$DB_USER" \
    --dbname="$DB_NAME" \
    -c "$count_query"

  PGPASSWORD="$DB_PASSWORD" pg_dump \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --username="$DB_USER" \
    --dbname="$DB_NAME" \
    --format=custom \
    --no-owner \
    --no-acl \
    --file="$LOCAL_DUMP"
fi

echo "Backing up remote database to $REMOTE_BACKUP..."
pg_dump "$REMOTE_DATABASE_URL" --format=custom --no-owner --no-acl --file="$REMOTE_BACKUP"

echo "Replacing remote database from $LOCAL_DUMP..."
pg_restore \
  --clean \
  --if-exists \
  --no-owner \
  --no-acl \
  --dbname="$REMOTE_DATABASE_URL" \
  "$LOCAL_DUMP"

echo "Remote counts after restore:"
psql "$REMOTE_DATABASE_URL" -c "$count_query"

echo "Done."
echo "Local dump:  $LOCAL_DUMP"
echo "Remote backup: $REMOTE_BACKUP"
