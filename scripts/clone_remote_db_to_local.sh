#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups}"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOCAL_DATABASE_URL="${LOCAL_DATABASE_URL:-}"

usage() {
  cat <<'USAGE'
Copy an online PostgreSQL database into the local PostgreSQL database.

Required:
  REMOTE_DATABASE_URL=postgresql://... bash scripts/clone_remote_db_to_local.sh

Optional:
  LOCAL_DATABASE_URL=postgresql://...   (defaults to backend/.env DATABASE_URL)
  BACKUP_DIR=/path/to/backups

The remote database is only read. The local database is replaced with the
remote dump, so use this only when replacing local data is intended.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -z "${REMOTE_DATABASE_URL:-}" ]]; then
  echo "REMOTE_DATABASE_URL is required." >&2
  usage >&2
  exit 1
fi

if [[ -z "$LOCAL_DATABASE_URL" && -f "$ROOT_DIR/backend/.env" ]]; then
  LOCAL_DATABASE_URL="$(grep -E '^DATABASE_URL=' "$ROOT_DIR/backend/.env" | tail -n 1 | sed -E 's/^DATABASE_URL=//; s/^['\"]//; s/['\"]$//')"
fi

if [[ -z "$LOCAL_DATABASE_URL" ]]; then
  echo "LOCAL_DATABASE_URL is required when backend/.env has no DATABASE_URL." >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"
LOCAL_DUMP="$BACKUP_DIR/online-copy-$STAMP.dump"

echo "Testing local database connection..."
psql "$LOCAL_DATABASE_URL" -v ON_ERROR_STOP=1 -c "SELECT current_database(), current_user;"

echo "Downloading online database to $LOCAL_DUMP..."
pg_dump "$REMOTE_DATABASE_URL" \
  --format=custom \
  --no-owner \
  --no-acl \
  --file="$LOCAL_DUMP"

echo "Restoring the online copy into the local database..."
pg_restore \
  --clean \
  --if-exists \
  --no-owner \
  --no-acl \
  --dbname="$LOCAL_DATABASE_URL" \
  "$LOCAL_DUMP"

echo "Checking restored local tables..."
psql "$LOCAL_DATABASE_URL" -v ON_ERROR_STOP=1 -c \
  "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name;"

echo "Online database copied to local successfully."
echo "Backup dump: $LOCAL_DUMP"
