#!/usr/bin/env bash
# Tjekker databasen fra bunden: migrationer + seed + tests på en tom Postgres.
# Bruges både lokalt (npm run db:test) og i CI. Rører aldrig Supabase.
#
# Lokalt uden Postgres kørende:
#   docker run --rm -d --name treatr-pg-test -p 55432:5432 -e POSTGRES_PASSWORD=x postgres:17
#   npm run db:test
#   docker stop treatr-pg-test
set -euo pipefail
cd "$(dirname "$0")/.."

ADMIN_URL="${TEST_DATABASE_URL:-postgresql://postgres:x@localhost:55432/postgres}"
DB_NAME="treatr_test"
DB_URL="${ADMIN_URL%/*}/${DB_NAME}"

if command -v psql >/dev/null 2>&1; then
  run_psql() { psql "$@"; }
else
  # Ingen psql installeret: lån den fra Postgres-imaget.
  run_psql() { docker run --rm -i --network host -v "$PWD":/work -w /work postgres:17 psql "$@"; }
fi
sql() { run_psql -X -q -v ON_ERROR_STOP=1 "$@"; }

echo "== Opretter tom testdatabase"
sql "$ADMIN_URL" -c "drop database if exists ${DB_NAME} with (force)" -c "create database ${DB_NAME}"
sql "$DB_URL" -c "alter database ${DB_NAME} set search_path = \"\$user\", public, extensions"

echo "== Supabase-efterligning (kun test)"
sql "$DB_URL" -f tests/db/00_supabase_shim.sql

echo "== Migrationer"
for f in supabase/migrations/*.sql; do
  echo "   $f"
  sql "$DB_URL" --single-transaction -f "$f"
done

echo "== Seed"
sql "$DB_URL" --single-transaction -f supabase/seed.sql

echo "== Tests"
for f in tests/db/[1-9]*.sql; do
  echo "   $f"
  sql "$DB_URL" -f "$f" 2>&1 | sed -e 's/^psql:[^ ]* NOTICE:  /     /'
done

echo "== Databasen er OK"
