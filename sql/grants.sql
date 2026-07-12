-- Run once in Supabase Dashboard → SQL Editor if you hit permission denied

grant all on table public.current_test to service_role;
grant all on table public.test_history to service_role;

grant select on table public.current_test to anon, authenticated;
grant insert, select on table public.test_history to anon, authenticated;

-- Ensure timing column exists for per-question analysis
alter table public.test_history
  add column if not exists timing jsonb;
