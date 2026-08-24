alter table public.activities
  alter column user_id drop not null,
  alter column user_email drop not null;

alter table public.activities
  add column source text not null default 'app',
  add column full_name text,
  add column company text,
  add column contact_number text,
  add column manual_logged_by text,
  add constraint activities_source_check check (source in ('app', 'manual')),
  add constraint activities_app_user_check check (
    source = 'manual' or user_id is not null
  );

create index activities_user_email_idx
  on public.activities (lower(user_email))
  where user_email is not null;

