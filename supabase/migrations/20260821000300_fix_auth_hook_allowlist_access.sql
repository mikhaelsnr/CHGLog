create or replace function public.hook_allow_globe_email(event jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
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

grant execute on function public.hook_allow_globe_email(jsonb)
  to supabase_auth_admin;
revoke execute on function public.hook_allow_globe_email(jsonb)
  from authenticated, anon, public;
