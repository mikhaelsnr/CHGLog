alter table public.activities
  drop constraint activities_status_check;

update public.activities
set
  status = 'ongoing post-checks',
  status_updated_at = now()
where status = 'ongoing post';

alter table public.activities
  add constraint activities_status_check check (
    status in (
      'login',
      'ongoing pre-checks',
      'ongoing planned',
      'ongoing post-checks',
      'implemented'
    )
  );
