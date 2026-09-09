#!/usr/bin/env bash
# Relio lokal starten. Kein Build noetig — index.html wird direkt ausgeliefert.
# Ein echter HTTP-Server (statt file://) ist noetig, damit Supabase-Auth funktioniert.
set -euo pipefail
PORT="${1:-8000}"
cd "$(dirname "$0")/.."
echo "Relio auf http://localhost:${PORT} — Strg+C zum Beenden"
echo "Achtung: spricht gegen die Produktions-Supabase. Zum Klicken den Demo-Modus nutzen."
exec python3 -m http.server "$PORT"
