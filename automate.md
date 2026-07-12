# Automation — Daily evaluation agent

How to automatically **fetch submitted results → analyze → generate the next day’s test → upload**.

Related files:

| Path | Role |
|------|------|
| [`agents/daily-eval/PROMPT.md`](agents/daily-eval/PROMPT.md) | Full agent instructions (source of truth for Grok) |
| [`agents/daily-eval/README.md`](agents/daily-eval/README.md) | Agent folder overview |
| [`scripts/run-daily-eval.sh`](scripts/run-daily-eval.sh) | Headless Grok runner |
| [`scripts/get-history.sh`](scripts/get-history.sh) | Pull `test_history` (+ timing) |
| [`scripts/upload-test.sh`](scripts/upload-test.sh) | Push next test to `current_test` |

---

## Goal pipeline

```text
  Student submits mock test
          │
          ▼
  Supabase test_history  (score, answers, timing)
          │
          │  ./scripts/get-history.sh
          ▼
  Grok agent  (headless or TUI)
          │
          ├─► agents/daily-eval/out/YYYY-MM-DD-analysis.md
          ├─► agents/daily-eval/out/YYYY-MM-DD-answer-key.md
          ├─► tests/daily-YYYY-MM-DD.json
          │
          │  ./scripts/upload-test.sh
          ▼
  Supabase current_test (id = 1)
          │
          ▼
  GitHub Pages site loads new test next day
```

**Can it be automatic?** Yes — with Grok CLI headless + a scheduler (cron / launchd) or Grok `/loop` while a session is open. There is no separate always-on cloud worker in this repo.

---

## Prerequisites

1. Repo checked out locally (e.g. `/Users/pphetra/projects/pran/iele-mockup`)
2. `.env` present (never commit):

   ```bash
   SUPABASE_URL=https://….supabase.co
   SUPABASE_PUBLISHABLE_KEY=sb_publishable_…
   SUPABASE_SECRET_KEY=sb_secret_…
   APP_SECRET=…
   ```

3. `grok` CLI on `PATH` and logged in  
4. Edge Functions deployed (`get-current-test`, `submit-result`, `admin`)  
5. Student has submitted at least one attempt (for non-empty history)

---

## How to call Grok

### A. One-shot script (recommended)

```bash
cd /Users/pphetra/projects/pran/iele-mockup

# Full cycle: fetch → analyze → generate → upload
./scripts/run-daily-eval.sh

# Same but do not upload
DRY_RUN=1 ./scripts/run-daily-eval.sh

# Explicit dry-run flag
./scripts/run-daily-eval.sh --dry-run
```

What the script runs (conceptually):

```bash
grok \
  --cwd /path/to/iele-mockup \
  --yolo \
  --output-format plain \
  -p "Execute agents/daily-eval/PROMPT.md … DRY_RUN=…"
```

- **`--yolo`** — auto-approve tools (needed for unattended runs)  
- **`-p` / headless** — single prompt, full tools, exits when done  
- Agent follows [`agents/daily-eval/PROMPT.md`](agents/daily-eval/PROMPT.md)

### B. Long-term coach memory (resume session)

Keep multi-day context in one Grok session:

```bash
# Later days — continue most recent session for this repo
./scripts/run-daily-eval.sh --continue
```

Or pin a session:

```bash
grok --resume <session-uuid> --cwd . --yolo \
  -p "Run daily eval per agents/daily-eval/PROMPT.md. DRY_RUN=0"
```

Sessions live under `~/.grok/sessions/`.

### C. Interactive TUI

```bash
cd /Users/pphetra/projects/pran/iele-mockup
grok
```

Then:

> Run the daily evaluation agent in `agents/daily-eval/PROMPT.md`.  
> Fetch history, write analysis under `agents/daily-eval/out/`,  
> generate tomorrow’s test, and upload unless I say dry-run.

### D. Grok `/loop` (while session stays open)

Inside an interactive Grok session:

```text
/loop 1d Run ./scripts/run-daily-eval.sh and summarize score, weak areas, and upload status.
```

Interval examples: `60s` (min), `5m`, `2h`, `1d`.

**Limitation:** `/loop` only runs while that Grok session remains open — not a cloud cron.

---

## Fully automatic schedules

### macOS / Linux cron

```bash
crontab -e
```

```cron
# Every day at 21:00 local time — after evening practice
0 21 * * * cd /Users/pphetra/projects/pran/iele-mockup && /usr/bin/env PATH="$HOME/.local/bin:/usr/local/bin:$PATH" ./scripts/run-daily-eval.sh >>logs/daily-eval.log 2>&1
```

Checklist for cron:

- [ ] Absolute `cd` path is correct  
- [ ] `PATH` includes `grok`  
- [ ] `.env` exists and is readable by the cron user  
- [ ] Machine is awake at run time (or use launchd + power settings)  
- [ ] `logs/` is writable (`mkdir -p logs`)

### Suggested human oversight (semi-auto)

```bash
DRY_RUN=1 ./scripts/run-daily-eval.sh
# Review:
#   agents/daily-eval/out/*-analysis.md
#   tests/daily-*.json
./scripts/upload-test.sh tests/daily-YYYY-MM-DD.json
```

---

## What the agent produces

| Output | Description |
|--------|-------------|
| `agents/daily-eval/out/YYYY-MM-DD-analysis.md` | Score, weak areas, timing patterns, parent note |
| `agents/daily-eval/out/YYYY-MM-DD-answer-key.md` | Parent-only key (not uploaded) |
| `tests/daily-YYYY-MM-DD.json` | Upload payload (`action` + `questions`) |
| Supabase `current_test` | Live test for the student site (if not dry-run) |

Analysis uses:

- `score`, `section_scores`, `answers`, `weak_areas`  
- `timing` — per-question `dwell_s`, answer changes, section rollups, slowest/fastest  

---

## Manual building blocks (without full agent)

```bash
# Pull all history
./scripts/get-history.sh | jq .

# Upload a hand-written or agent-written test
./scripts/upload-test.sh tests/daily-test-001.json
```

Admin API (same auth as scripts):

```bash
source .env

# History
curl -sS -X POST "$SUPABASE_URL/functions/v1/admin" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $SUPABASE_SECRET_KEY" \
  -H "apikey: $SUPABASE_SECRET_KEY" \
  -H "X-App-Secret: $APP_SECRET" \
  -d '{"action":"get_history"}'

# Current test
curl -sS -X POST "$SUPABASE_URL/functions/v1/admin" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $SUPABASE_SECRET_KEY" \
  -H "apikey: $SUPABASE_SECRET_KEY" \
  -H "X-App-Secret: $APP_SECRET" \
  -d '{"action":"get_current"}'
```

---

## Automation levels (summary)

| Level | Command / mechanism | Fully unattended? |
|-------|---------------------|-------------------|
| On demand | `./scripts/run-daily-eval.sh` | No — you run it |
| Dry-run then approve | `DRY_RUN=1` … then upload | Semi |
| Nightly cron | `0 21 * * * … run-daily-eval.sh` | Yes (if Mac on) |
| Grok `/loop 1d` | Inside open TUI session | Yes while open |
| Session memory | `--continue` / `--resume` | Optional quality boost |

---

## Security

- Cron and headless Grok use local **`.env`** (secret key + `APP_SECRET`). Keep the machine locked.  
- Do **not** paste secret keys into prompts.  
- `agents/daily-eval/out/` may contain student performance data — gitignored; treat as private.  
- Publishable key in `index.html` is fine; secret key never goes in the frontend.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `grok: command not found` (esp. cron) | Fix `PATH` or use absolute path to `grok` |
| Empty history | Student must submit once; check `submit-result` + `test_history` |
| Admin unauthorized | `.env` `APP_SECRET` must match Edge Function secret |
| Upload / history fails credentials | Use **secret** key, not publishable, in scripts |
| Agent stops for tool approval | Ensure `--yolo` (already in `run-daily-eval.sh`) |
| Site still shows old test | Confirm upload success; hard-refresh Pages |
| No analysis files | Check agent finished; re-run with `DRY_RUN=1` and read stdout |

---

## Recommended daily rhythm

| When | Action |
|------|--------|
| Afternoon / evening | Student takes test on https://pphetra.github.io/iele-mockup/ |
| ~21:00 | `./scripts/run-daily-eval.sh` (or cron) |
| Optional | Parent skims `out/*-analysis.md` |
| Next day | Student opens site → new targeted test |

---

## Quick copy-paste

```bash
cd /Users/pphetra/projects/pran/iele-mockup

# First time today
DRY_RUN=1 ./scripts/run-daily-eval.sh

# Happy with output?
./scripts/upload-test.sh tests/daily-$(TZ=Asia/Bangkok date +%Y-%m-%d).json
# or re-run full:
# DRY_RUN=0 ./scripts/run-daily-eval.sh

# Multi-day coach
./scripts/run-daily-eval.sh --continue
```
