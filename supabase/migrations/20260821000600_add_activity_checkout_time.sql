alter table public.activities
  add column checked_out_at timestamptz,
  add column checked_out_time text;

alter table public.activities
  add constraint activities_checkout_status_check check (
    status = 'implemented'
    or (checked_out_at is null and checked_out_time is null)
  );

alter table public.activities
  add constraint activities_checkout_time_format_check check (
    checked_out_time is null
    or checked_out_time ~ '^[0-9]{4}H$'
  );
