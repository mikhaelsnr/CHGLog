create table public.activities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  user_email text not null,
  sheet_row integer not null check (sheet_row > 0),
  change_number text not null check (change_number ~ '^CHG[0-9]{7}$'),
  title text not null default '',
  objective text not null default '',
  proponent text not null default '',
  status text not null default 'login' check (
    status in (
      'login',
      'ongoing pre-checks',
      'ongoing planned',
      'ongoing post',
      'implemented'
    )
  ),
  checked_in_at timestamptz not null default now(),
  status_updated_at timestamptz not null default now()
);

create index activities_user_checked_in_idx
  on public.activities (user_id, checked_in_at desc);
create index activities_sheet_row_idx
  on public.activities (sheet_row, change_number);

create table public.device_tokens (
  token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null default 'android',
  updated_at timestamptz not null default now()
);

create index device_tokens_user_idx on public.device_tokens (user_id);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_id uuid not null references public.activities(id) on delete cascade,
  title text not null,
  body text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create index notifications_user_created_idx
  on public.notifications (user_id, created_at desc);

alter table public.activities enable row level security;
alter table public.device_tokens enable row level security;
alter table public.notifications enable row level security;

create policy "Users can read their activities"
  on public.activities for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can create their activities"
  on public.activities for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can read their device tokens"
  on public.device_tokens for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can register device tokens"
  on public.device_tokens for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Users can refresh their device tokens"
  on public.device_tokens for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users can remove their device tokens"
  on public.device_tokens for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can read their notifications"
  on public.notifications for select to authenticated
  using ((select auth.uid()) = user_id);
