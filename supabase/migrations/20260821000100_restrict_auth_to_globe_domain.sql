create or replace function public.hook_allow_globe_email(event jsonb)
returns jsonb
language plpgsql
stable
as $$
declare
  user_email text;
begin
  user_email := lower(trim(coalesce(event->'user'->>'email', '')));

  if user_email ~ '^[^@[:space:]]+@globe\.com\.ph$' then
    return '{}'::jsonb;
  end if;

  return jsonb_build_object(
    'error', jsonb_build_object(
      'http_code', 403,
      'message', 'Only @globe.com.ph Google accounts can use CHGLog.'
    )
  );
end;
$$;

grant usage on schema public to supabase_auth_admin;
grant execute on function public.hook_allow_globe_email(jsonb)
  to supabase_auth_admin;
revoke execute on function public.hook_allow_globe_email(jsonb)
  from authenticated, anon, public;
