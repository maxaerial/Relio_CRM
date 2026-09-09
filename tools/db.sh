#!/usr/bin/env bash
# Direkter SQL-Zugang zur Relio-Datenbank.
#
# Braucht SUPABASE_DB_URL — zu finden im Supabase-Dashboard unter
# Project Settings -> Database -> Connection string -> URI (Session pooler).
# Niemals ins Repo committen, nur als Umgebungsvariable setzen:
#
#   export SUPABASE_DB_URL='postgresql://postgres.ftkriccztlcwccgetdqt:<PASSWORT>@aws-0-eu-central-1.pooler.supabase.com:5432/postgres'
#
#   tools/db.sh                          # interaktive psql-Sitzung
#   tools/db.sh -c 'select count(*) from kontakte'
#   tools/db.sh -f migration.sql
set -euo pipefail

if [[ -z "${SUPABASE_DB_URL:-}" ]]; then
  echo "SUPABASE_DB_URL ist nicht gesetzt — siehe Kommentar in $0" >&2
  exit 1
fi

exec psql "$SUPABASE_DB_URL" "$@"
