create table if not exists public.allowed_email_domains (
  domain text primary key,
  company_name text not null,
  created_at timestamptz not null default now(),
  constraint allowed_email_domains_normalized check (
    domain = lower(trim(domain))
    and domain ~ '^[a-z0-9.-]+[.][a-z]{2,}$'
  )
);

alter table public.allowed_email_domains enable row level security;

insert into public.allowed_email_domains (domain, company_name)
values ('huawei.com', 'Huawei')
on conflict (domain) do update set company_name = excluded.company_name;

grant select on public.allowed_email_domains to supabase_auth_admin;
revoke all on public.allowed_email_domains from anon, authenticated;

create or replace function public.hook_allow_globe_email(event jsonb)
returns jsonb
language plpgsql
stable
as $$
declare
  user_email text;
  user_domain text;
begin
  user_email := lower(trim(coalesce(event->'user'->>'email', '')));
  user_domain := split_part(user_email, '@', 2);

  if user_email ~ '^[^@[:space:]]+@[^@[:space:]]+$'
    and exists (
      select 1
      from public.allowed_email_domains
      where domain = user_domain
    )
  then
    return '{}'::jsonb;
  end if;

  return jsonb_build_object(
    'error', jsonb_build_object(
      'http_code', 403,
      'message', 'Use an approved company email account to access CHGLog.'
    )
  );
end;
$$;

grant usage on schema public to supabase_auth_admin;
grant execute on function public.hook_allow_globe_email(jsonb)
  to supabase_auth_admin;
revoke execute on function public.hook_allow_globe_email(jsonb)
  from authenticated, anon, public;

create or replace function public.is_allowed_email_domain(candidate_email text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.allowed_email_domains
    where domain = split_part(lower(trim(candidate_email)), '@', 2)
  );
$$;

grant execute on function public.is_allowed_email_domain(text) to authenticated;
revoke execute on function public.is_allowed_email_domain(text)
  from anon, public;
