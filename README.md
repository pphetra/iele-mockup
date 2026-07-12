# IELE Daily Mock Test

A simple daily practice system for IELE-style English exams.

- **Student** takes a 60-minute mock test in the browser  
- **Parent** uploads targeted tests and reviews scores + per-question timing  
- **Backend** is Supabase (Postgres + Edge Functions)  
- **Frontend** is a single static page on GitHub Pages  

**Live site:** https://pphetra.github.io/iele-mockup/

---

## How it works

```text
┌─────────────────────┐     publishable key      ┌──────────────────────────┐
│  GitHub Pages       │ ───────────────────────► │  Edge Functions          │
│  index.html         │                          │  get-current-test        │
│  (student UI)       │ ◄─────────────────────── │  submit-result           │
└─────────────────────┘     questions / OK       └────────────┬─────────────┘
                                                              │ supabaseAdmin
┌─────────────────────┐     secret key +         ┌────────────▼─────────────┐
│  Parent scripts     │     X-App-Secret         │  Postgres                │
│  upload-test.sh     │ ───────────────────────► │  current_test (today)    │
│  get-history.sh     │     admin function       │  test_history (attempts) │
└─────────────────────┘                          └──────────────────────────┘
```

| Role | What they do |
|------|----------------|
| Student | Open the site → Start → answer for 60 min → Submit |
| Parent | Upload tomorrow’s JSON test → review history / timing → plan next test |

---

## Repository layout

```text
iele-mockup/
├── index.html                 # Student UI (GitHub Pages)
├── tests/
│   └── daily-test-001.json    # Example daily test payload
├── scripts/
│   ├── upload-test.sh         # Upload questions via admin API
│   └── get-history.sh         # Fetch past results + timing
├── sql/
│   ├── 001_schema.sql         # Tables + grants
│   └── grants.sql             # Quick privilege / timing fix
├── supabase/
│   ├── config.toml            # verify_jwt = false for public fns
│   ├── README.md              # Deploy details
│   └── functions/
│       ├── get-current-test/  # Load today's test
│       ├── submit-result/     # Save score + timing
│       └── admin/             # Upload test / history
├── .env.example               # Local secrets template
└── README.md
```

---

## Student usage

1. Open https://pphetra.github.io/iele-mockup/  
2. Click **Start Today's Test** (60-minute timer starts)  
3. Work through sections: Grammar → Vocabulary → Reading → Writing  
4. Click **Submit Test** (auto-submits at 0:00)  
5. Results show MCQ score, time-per-question table, and JSON backup  

No login required.

---

## Parent workflow

### Daily loop

1. **Review** yesterday’s attempt (`./scripts/get-history.sh` or Supabase Table Editor)  
2. **Write / edit** a test JSON (focus weak areas)  
3. **Upload** before the student starts  
4. Student takes the test  
5. **Analyze** score, wrong items, and timing patterns  

### Upload a test

```bash
cp .env.example .env   # once — fill keys
./scripts/upload-test.sh tests/daily-test-001.json
```

Expected response:

```json
{"success":true,"message":"New test uploaded","count":25}
```

### Fetch history (includes timing)

```bash
./scripts/get-history.sh | jq .
```

### What to look for in timing

| Pattern | Likely meaning |
|---------|----------------|
| Long dwell + wrong | Concept gap — reteach |
| Very short dwell + wrong | Rushing / guessing |
| Many answer changes | Uncertainty |
| Section rollup skewed | e.g. reading eats the hour |

---

## Question JSON format

Each item in `questions`:

```json
{
  "type": "mcq",
  "section": "grammar",
  "question": "Grammar 1: Choose the correct option.\n\nIf she _____ harder…",
  "options": ["studied", "had studied", "has studied", "would study"],
  "correct": "had studied"
}
```

| Field | Notes |
|-------|--------|
| `type` | `mcq` or `writing` |
| `section` | `grammar` · `vocabulary` · `reading` · `writing` (UI groups by this) |
| `question` | May include a `Section N: instruction` prefix; UI strips it for display |
| `options` / `correct` | Required for `mcq` (`correct` must match an option string exactly) |
| `underline` | Optional target word for synonym items, e.g. `"lucid"` |
| Inline | Or mark the word in text as `__lucid__` |

**Writing example:**

```json
{
  "type": "writing",
  "section": "writing",
  "question": "Writing Task (about 20–25 minutes)\n\nSome people believe…"
}
```

Full sample: [`tests/daily-test-001.json`](tests/daily-test-001.json)

---

## Backend

### Tables

**`current_test`** — single active test (`id = 1`)

| Column | Type |
|--------|------|
| `id` | int (always `1`) |
| `questions` | jsonb |
| `updated_at` | timestamptz |

**`test_history`** — each student attempt

| Column | Type |
|--------|------|
| `id` | uuid |
| `test_date` | date |
| `score` | int (MCQ correct count) |
| `section_scores` | jsonb |
| `answers` | jsonb |
| `weak_areas` | text[] |
| `timing` | jsonb (per-question dwell, events, rollups) |
| `created_at` | timestamptz |

Apply schema:

```bash
# Dashboard → SQL Editor, or:
npx supabase db query --linked -f sql/001_schema.sql
```

### Edge Functions

| Function | Auth | Purpose |
|----------|------|---------|
| `get-current-test` | Publishable key | Return today’s `questions` |
| `submit-result` | Publishable key | Insert attempt + `timing` |
| `admin` | Secret key + `X-App-Secret` | `upload_test` · `get_history` · `get_current` |

Implemented with [`@supabase/server`](https://github.com/supabase/server) (`withSupabase`).  
DB access uses **`ctx.supabaseAdmin`** so RLS/grant issues do not block student flows.

Config: [`supabase/config.toml`](supabase/config.toml) (`verify_jwt = false` for these three).

### Secrets

| Name | Where | Used for |
|------|--------|----------|
| `SUPABASE_PUBLISHABLE_KEY` | Frontend + local `.env` | Student browser calls (safe to expose) |
| `SUPABASE_SECRET_KEY` | Local `.env` only | Parent scripts / admin |
| `APP_SECRET` | Edge Function secrets + `.env` | Second gate on `admin` (`X-App-Secret`) |

> The **publishable** key is meant for the browser.  
> Never put the **secret** key or `APP_SECRET` in `index.html` or a public repo.

---

## Local setup

### Prerequisites

- Node.js (for Supabase CLI via `npx`)  
- GitHub account (Pages)  
- Supabase project  

### 1. Clone & env

```bash
git clone git@github.com:pphetra/iele-mockup.git
cd iele-mockup
cp .env.example .env
# Edit .env with URL, publishable key, secret key, APP_SECRET
```

### 2. Database

```bash
npx supabase login
npx supabase link --project-ref <your-project-ref>
npx supabase db query --linked -f sql/001_schema.sql
```

### 3. Deploy functions

```bash
npx supabase secrets set APP_SECRET=your_app_secret

# Prefer --use-api if local Docker/ECR is flaky
npx supabase functions deploy get-current-test submit-result admin \
  --no-verify-jwt --use-api
```

### 4. Upload first test

```bash
./scripts/upload-test.sh tests/daily-test-001.json
```

### 5. Frontend

- Push to `main` → GitHub Pages serves `index.html` from `/`  
- Or open `index.html` locally (still calls remote Supabase)

Update `SUPABASE_URL` / `PUBLISHABLE_KEY` constants in `index.html` if you fork the project.

---

## API cheatsheet

```bash
# Load test (student)
curl -s "$SUPABASE_URL/functions/v1/get-current-test" \
  -H "apikey: $SUPABASE_PUBLISHABLE_KEY" \
  -H "Authorization: Bearer $SUPABASE_PUBLISHABLE_KEY"

# Submit result (student)
curl -s -X POST "$SUPABASE_URL/functions/v1/submit-result" \
  -H "apikey: $SUPABASE_PUBLISHABLE_KEY" \
  -H "Authorization: Bearer $SUPABASE_PUBLISHABLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"test_date":"2026-07-12","score":18,"answers":{},"timing":{}}'

# Admin: upload / history / current
curl -s -X POST "$SUPABASE_URL/functions/v1/admin" \
  -H "apikey: $SUPABASE_SECRET_KEY" \
  -H "Authorization: Bearer $SUPABASE_SECRET_KEY" \
  -H "X-App-Secret: $APP_SECRET" \
  -H "Content-Type: application/json" \
  -d @tests/daily-test-001.json   # includes "action":"upload_test"
```

Admin actions: `upload_test` · `get_history` · `get_current`

---

## Frontend notes

- Sections are grouped from each question’s `section` field  
- Sticky timer + answered progress  
- Per-question **dwell time** via `IntersectionObserver`  
- Answer timestamps and change counts for parent analysis  
- Display strips prefixes like `Vocabulary 4: Choose the word…`  
- Underlined vocab targets via `__word__` or `"underline": "word"`  

UI version label is shown under the page title (e.g. `UI v2.5`) to confirm cache.

---

## Security (practical)

| OK to expose | Keep private |
|--------------|----------------|
| Publishable key | Secret key |
| Project URL | `APP_SECRET` |
| This public GitHub repo | `.env` (gitignored) |

No RLS is required for the current design: Edge Functions write with the admin client. You can tighten later with RLS if needed.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `permission denied for table …` | Run `sql/grants.sql` |
| `Could not find the 'timing' column` | `alter table test_history add column if not exists timing jsonb;` |
| Admin `INVALID_CREDENTIALS` | Use **secret** key in `apikey` / `Authorization`, not publishable |
| Admin `Unauthorized` | Check `X-App-Secret` matches Edge secret `APP_SECRET` |
| Deploy fails on Docker/ECR | Add `--use-api` |
| Site looks old | Hard refresh or open `?v=25`; check green UI version label |
| Empty questions | Upload a test: `./scripts/upload-test.sh …` |

---

## License

Private family study tool — use and modify freely for your own practice setup.
