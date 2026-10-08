create table public.review_states (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  content_id text not null,
  interval_days integer not null check (interval_days between 1 and 30),
  due_at timestamptz not null,
  wrong_count integer not null default 0 check (wrong_count >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, content_id)
);
create table public.study_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id text not null,
  total integer not null check (total > 0),
  correct integer not null check (correct between 0 and total),
  seconds integer not null check (seconds >= 0),
  mode text not null check (mode in ('Luyện tập', 'Luyện có thời gian')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, session_id)
);
alter table public.review_states enable row level security;
alter table public.study_sessions enable row level security;
create policy "Own reviews" on public.review_states for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "Own sessions" on public.study_sessions for all to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
grant select, insert, update, delete on public.review_states, public.study_sessions to authenticated;
