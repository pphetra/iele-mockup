#!/usr/bin/env bash
# Fetch test_history (includes timing) via admin Edge Function.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  echo "Missing .env"
  exit 1
fi

# shellcheck disable=SC1091
set -a
source .env
set +a

: "${SUPABASE_URL:?}"
: "${SUPABASE_SECRET_KEY:?}"
: "${APP_SECRET:?}"

curl -sS -X POST "${SUPABASE_URL}/functions/v1/admin" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer ${SUPABASE_SECRET_KEY}" \
  -H "apikey: ${SUPABASE_SECRET_KEY}" \
  -H "X-App-Secret: ${APP_SECRET}" \
  -d '{"action":"get_history"}'
echo
