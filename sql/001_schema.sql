-- IELE mock test tables + grants
-- Run in Supabase Dashboard → SQL Editor (or supabase db push)

-- Today's active test (single row id = 1)
create table if not exists public.current_test (
  id integer primary key,
  questions jsonb not null default '[]'::jsonb,
  updated_at timestamptz default now()
);

-- Past attempts (student results)
create table if not exists public.test_history (
  id uuid primary key default gen_random_uuid(),
  test_date date not null,
  score integer,
  section_scores jsonb,
  answers jsonb,
  weak_areas text[],
  timing jsonb,
  created_at timestamptz default now()
);

-- Add timing if table already existed without it
alter table public.test_history
  add column if not exists timing jsonb;

-- Privileged role used by secret key / supabaseAdmin
grant all on table public.current_test to service_role;
grant all on table public.test_history to service_role;

-- Optional direct REST access (functions use admin client, so not required)
grant select on table public.current_test to anon, authenticated;
grant insert, select on table public.test_history to anon, authenticated;

comment on column public.test_history.timing is
  'Per-question timing from the frontend: dwell, answer events, section rollups';
