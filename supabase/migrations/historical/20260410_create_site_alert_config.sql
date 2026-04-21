create extension if not exists pgcrypto;

create table if not exists public.site_alert_config (
  id uuid primary key default gen_random_uuid(),
  site_id text not null unique,
  alert_window_start time not null default '23:00',
  alert_window_end time not null default '08:00',
  timezone text not null default 'Africa/Johannesburg',
  perimeter_sensitivity text not null default 'suspicious_only',
  semi_perimeter_sensitivity text not null default 'suspicious_only',
  indoor_sensitivity text not null default 'off',
  loiter_detection_minutes int not null default 3,
  perimeter_sequence_alert boolean not null default true,
  quiet_hours_sensitivity text not null default 'all_motion',
  day_sensitivity text not null default 'suspicious_only'
);

insert into public.site_alert_config (
  site_id,
  alert_window_start,
  alert_window_end,
  timezone,
  perimeter_sensitivity,
  semi_perimeter_sensitivity,
  indoor_sensitivity,
  loiter_detection_minutes,
  quiet_hours_sensitivity
) values (
  'SITE-MS-VALLEE-RESIDENCE',
  '23:00',
  '08:00',
  'Africa/Johannesburg',
  'suspicious_only',
  'suspicious_only',
  'off',
  3,
  'all_motion'
)
on conflict (site_id) do update
set alert_window_start = excluded.alert_window_start,
    alert_window_end = excluded.alert_window_end,
    timezone = excluded.timezone,
    perimeter_sensitivity = excluded.perimeter_sensitivity,
    semi_perimeter_sensitivity = excluded.semi_perimeter_sensitivity,
    indoor_sensitivity = excluded.indoor_sensitivity,
    loiter_detection_minutes = excluded.loiter_detection_minutes,
    quiet_hours_sensitivity = excluded.quiet_hours_sensitivity;

alter table public.site_alert_config enable row level security;

drop policy if exists "anon_can_read_site_alert_config"
  on public.site_alert_config;

create policy "anon_can_read_site_alert_config"
  on public.site_alert_config
  for select
  to anon
  using (true);
