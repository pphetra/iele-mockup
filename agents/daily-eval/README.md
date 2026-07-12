# Long-term evaluation agent

Automatically (or on demand):

1. **Fetch** latest `test_history` (scores, answers, timing)  
2. **Analyze** weak skills + time patterns  
3. **Generate** tomorrow’s targeted mock test  
4. **Upload** to Supabase so GitHub Pages serves it  

## Can it be automatic?

**Yes.** Three layers:

| Level | How | Fully auto? |
|-------|-----|-------------|
| **A. On demand** | You run one command | Manual trigger |
| **B. Scheduled on this Mac** | `cron` / `launchd` calls Grok headless | Yes, if machine is on |
| **C. Grok session loop** | `/loop 1d …` inside an open Grok session | Yes, while Grok is running |

There is no cloud “always-on Grok server” in this repo: automation is **Grok CLI headless** + a scheduler on a machine you control (or a CI cron with a Grok API token if you add that later).

---

## How to call Grok for this

### 1) One-shot (recommended entry point)

```bash
cd /Users/pphetra/projects/pran/iele-mockup

# Analyze + generate + upload
./scripts/run-daily-eval.sh

# Analyze + generate only (no upload)
DRY_RUN=1 ./scripts/run-daily-eval.sh
```

Under the hood this is:

```bash
grok --cwd . --yolo -p "Execute agents/daily-eval/PROMPT.md …"
```

Headless mode (`grok -p`) runs tools, can call `./scripts/get-history.sh`, write files, and upload.

### 2) Resume the same long-term session

Keep coach memory across days:

```bash
# First run creates a session (note session id from logs / ~/.grok/sessions)
./scripts/run-daily-eval.sh

# Later days — continue most recent session in this repo
./scripts/run-daily-eval.sh --continue
# same as: grok --continue -p "…"
```

Or pin a session id:

```bash
grok --resume <session-uuid> --cwd . --yolo -p "Run daily eval per agents/daily-eval/PROMPT.md"
```

### 3) Interactive TUI

```bash
cd /path/to/iele-mockup
grok
```

Then paste:

> Run the daily evaluation agent in `agents/daily-eval/PROMPT.md`. Fetch history, write analysis, generate tomorrow’s test, upload.

Or schedule inside TUI:

```text
/loop 1d Run ./scripts/run-daily-eval.sh and summarize score, weak areas, and whether upload succeeded.
```

`/loop` needs the Grok session to stay open.

### 4) Fully automatic nightly (macOS cron)

```bash
crontab -e
```

```cron
# Every day 21:00 — after evening practice
0 21 * * * cd /Users/pphetra/projects/pran/iele-mockup && /usr/bin/env PATH="$HOME/.local/bin:/usr/local/bin:$PATH" ./scripts/run-daily-eval.sh >>logs/daily-eval.log 2>&1
```

Ensure:

- `grok` is on `PATH` for cron  
- `.env` exists with Supabase keys  
- Machine is awake (or use launchd with Power assertions)

---

## Pipeline diagram

```text
  Student submits test
          │
          ▼
  test_history (+ timing jsonb)
          │
          │  ./scripts/get-history.sh
          ▼
  Grok headless agent  ◄── agents/daily-eval/PROMPT.md
          │
          ├─► agents/daily-eval/out/YYYY-MM-DD-analysis.md
          ├─► agents/daily-eval/out/YYYY-MM-DD-answer-key.md
          ├─► tests/daily-YYYY-MM-DD.json
          │
          │  ./scripts/upload-test.sh
          ▼
  current_test (id=1)
          │
          ▼
  Student site loads new test next day
```

---

## Files

| Path | Role |
|------|------|
| `PROMPT.md` | Full agent instructions (source of truth) |
| `out/` | Analysis + answer keys (generated) |
| `../../scripts/run-daily-eval.sh` | Headless runner |
| `../../scripts/get-history.sh` | Pull history |
| `../../scripts/upload-test.sh` | Push next test |

---

## Suggested human oversight

Even with automation, glance at:

1. `out/*-analysis.md` — is the diagnosis sensible?  
2. `tests/daily-*.json` — any bad items?  
3. Upload confirmation  

For semi-auto: run with `DRY_RUN=1`, review, then:

```bash
./scripts/upload-test.sh tests/daily-YYYY-MM-DD.json
```

---

## Optional: multi-day trend memory

- Prefer `./scripts/run-daily-eval.sh --continue` so Grok keeps prior analyses in session context.  
- Or keep `out/*.md` as durable memory the agent re-reads each run (PROMPT already writes dated files — extend the prompt to “read last 7 analysis files” if you want file-based memory without session resume).

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `grok: command not found` in cron | Set full PATH or absolute path to `grok` |
| Empty history | Student must submit once; check `submit-result` |
| Upload unauthorized | `.env` `APP_SECRET` must match Edge Function secret |
| Agent doesn’t upload | Ensure `DRY_RUN=0` and `--yolo` (script already passes `--yolo`) |
| Wants approval every tool | Use `--yolo` (included) or permission allows |

---

## Security

- Cron/headless runs with your local `.env` (secret key). Keep the Mac locked.  
- Do not put secret keys in the Grok prompt text.  
- `out/` may contain student performance data — treat as private.
