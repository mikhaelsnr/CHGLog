create extension if not exists pg_cron with schema pg_catalog;

create or replace function public.purge_expired_activities()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  deleted_count integer;
begin
  delete from public.activities
  where checked_in_at < now() - interval '1 month';

  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

revoke execute on function public.purge_expired_activities()
  from anon, authenticated, public;

select cron.schedule(
  'chglog-purge-expired-activities',
  '15 0 * * *',
  'select public.purge_expired_activities();'
);
