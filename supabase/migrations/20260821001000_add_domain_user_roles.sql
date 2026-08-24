alter table public.allowed_email_domains
  add column user_role text not null default 'onsite',
  add constraint allowed_email_domains_user_role_check check (
    user_role in ('onsite', 'wln')
  );

insert into public.allowed_email_domains (domain, company_name, user_role)
values ('globe.com.ph', 'Globe Telecom', 'wln')
on conflict (domain) do update
set company_name = excluded.company_name,
    user_role = excluded.user_role;

create or replace function public.get_chglog_user_role(candidate_email text)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select user_role
      from public.allowed_email_domains
      where domain = split_part(lower(trim(candidate_email)), '@', 2)
    ),
    'onsite'
  );
$$;

grant execute on function public.get_chglog_user_role(text) to authenticated;
revoke execute on function public.get_chglog_user_role(text)
  from anon, public;

