# Supabase Edge Functions (IELE mockup)

Uses [`@supabase/server`](https://github.com/supabase/server) (`withSupabase`) per `.agents/skills/supabase-server`.

| Function | Auth | Purpose |
|----------|------|---------|
| `get-current-test` | `publishable` | Student loads today's questions |
| `submit-result` | `publishable` | Student saves score + **timing** |
| `admin` | `secret` + `X-App-Secret` | Upload test / read history |

All three set `verify_jwt = false` in `config.toml` so platform JWT check does not block publishable/secret keys.

## Secrets

In Supabase Dashboard → **Edge Functions → Secrets**:

| Name | Value |
|------|--------|
| `APP_SECRET` | Parent PIN (e.g. same as local `.env`) |

Platform keys (`SUPABASE_URL`, publishable, secret) are injected automatically.

## Deploy

```bash
# Once
npx supabase login
npx supabase link --project-ref mkrzdyyvyxoxorrkfzdq

# Deploy all three
npx supabase functions deploy get-current-test --no-verify-jwt
npx supabase functions deploy submit-result --no-verify-jwt
npx supabase functions deploy admin --no-verify-jwt
```

Or from repo root after link:

```bash
npx supabase functions deploy
```

## SQL

Run `sql/001_schema.sql` (or at least `sql/grants.sql`) so `test_history.timing` exists and `service_role` can read/write.

## Call examples

**Student (frontend already does this):**

```bash
curl -H "apikey: $SUPABASE_PUBLISHABLE_KEY" \
  -H "Authorization: Bearer $SUPABASE_PUBLISHABLE_KEY" \
  "$SUPABASE_URL/functions/v1/get-current-test"
```

**Upload test:**

```bash
./scripts/upload-test.sh tests/daily-test-001.json
```

**History (with timing):**

```bash
./scripts/get-history.sh
```

## Auth notes (skill)

- Browser → `auth: 'publishable'`, send `apikey` (+ optional Bearer publishable).
- Admin → `auth: 'secret'`, send secret key as `apikey` / `Authorization: Bearer`.
- DB writes that must not depend on RLS → `ctx.supabaseAdmin`.
- Do **not** use legacy `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` in new code.
