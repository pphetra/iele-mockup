#!/usr/bin/env bash
# Run the IELE daily evaluation agent via Grok headless mode.
#
# Usage:
#   ./scripts/run-daily-eval.sh              # analyze + generate + upload
#   DRY_RUN=1 ./scripts/run-daily-eval.sh    # analyze + generate only
#   ./scripts/run-daily-eval.sh --continue   # resume last Grok session in this repo
#
# Automation examples:
#   # macOS launchd / cron at 21:00 daily
#   0 21 * * * cd /path/to/iele-mockup && ./scripts/run-daily-eval.sh >>logs/daily-eval.log 2>&1
#
#   # Grok TUI recurring (while a session is open)
#   /loop 1d Run ./scripts/run-daily-eval.sh in this repo and summarize the result
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mkdir -p agents/daily-eval/out logs

if [[ ! -f .env ]]; then
  echo "Missing .env (need SUPABASE_URL, SUPABASE_SECRET_KEY, APP_SECRET)"
  exit 1
fi

if ! command -v grok >/dev/null 2>&1; then
  echo "grok CLI not found on PATH"
  exit 1
fi

PROMPT_FILE="$ROOT/agents/daily-eval/PROMPT.md"
if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Missing $PROMPT_FILE"
  exit 1
fi

DRY_RUN="${DRY_RUN:-0}"
CONTINUE_FLAG=()
EXTRA=()

for arg in "$@"; do
  case "$arg" in
    --continue|-c) CONTINUE_FLAG=(--continue) ;;
    --dry-run) DRY_RUN=1 ;;
    *) EXTRA+=("$arg") ;;
  esac
done

DATE_TAG="$(TZ=Asia/Bangkok date +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)"

USER_PROMPT=$(cat <<EOF
Execute the daily IELE evaluation agent instructions in agents/daily-eval/PROMPT.md exactly.

Today (Asia/Bangkok if available): ${DATE_TAG}
DRY_RUN=${DRY_RUN}

Requirements:
- Fetch history with ./scripts/get-history.sh
- Write analysis under agents/daily-eval/out/
- Write tomorrow's test as tests/daily-${DATE_TAG}.json (or next calendar day if you prefer — state which)
- If DRY_RUN=0, upload with ./scripts/upload-test.sh
- Do not print secrets from .env
EOF
)

echo "[daily-eval] starting grok headless  dry_run=${DRY_RUN}  date=${DATE_TAG}"

# --yolo: auto-approve tools for unattended runs
# --output-format json: machine-readable result (optional for logs)
set -x
grok \
  --cwd "$ROOT" \
  --yolo \
  --output-format plain \
  "${CONTINUE_FLAG[@]}" \
  "${EXTRA[@]}" \
  -p "$USER_PROMPT"
set +x

echo "[daily-eval] finished"
