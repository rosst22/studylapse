-- StudyLapse v2 schema.
-- Run in the Supabase SQL editor, or `supabase db push` with the CLI.
--
-- Design notes:
--  * SwiftData on the device stays the source of truth. This table is a backup,
--    so every row carries the local record's id (client_id) and upserts against
--    it. Syncing twice is a no-op rather than a duplicate.
--  * Row Level Security is on and there is no policy that lets one user see
--    another's rows. Without RLS the anon key would expose every session to
--    anyone who read it out of the app binary.
--  * ON DELETE CASCADE is what makes account deletion honest: removing the auth
--    user removes their sessions in the same transaction.

create table if not exists public.study_sessions (
  id                     uuid primary key default gen_random_uuid(),
  user_id                uuid not null references auth.users (id) on delete cascade,
  client_id              uuid not null,
  subject                text not null default '',
  started_at             timestamptz not null,
  duration_seconds       double precision not null default 0,
  lapse_coverage_seconds double precision not null default 0,
  frame_count            integer not null default 0,
  byte_size              bigint  not null default 0,
  gap_count              integer not null default 0,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  constraint study_sessions_user_client_unique unique (user_id, client_id)
);

create index if not exists study_sessions_user_started_idx
  on public.study_sessions (user_id, started_at desc);

alter table public.study_sessions enable row level security;

drop policy if exists "read own sessions"   on public.study_sessions;
drop policy if exists "insert own sessions" on public.study_sessions;
drop policy if exists "update own sessions" on public.study_sessions;
drop policy if exists "delete own sessions" on public.study_sessions;

create policy "read own sessions" on public.study_sessions
  for select using (auth.uid() = user_id);

create policy "insert own sessions" on public.study_sessions
  for insert with check (auth.uid() = user_id);

create policy "update own sessions" on public.study_sessions
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "delete own sessions" on public.study_sessions
  for delete using (auth.uid() = user_id);

-- Keep updated_at honest.
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists study_sessions_touch on public.study_sessions;
create trigger study_sessions_touch
  before update on public.study_sessions
  for each row execute function public.touch_updated_at();
