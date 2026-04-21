create table if not exists public.site_alarm_events (
  id uuid primary key default gen_random_uuid(),
  site_id text not null,
  device_id text not null,
  event_type text not null,
  zone_id text,
  area_id text,
  zone_name text,
  area_name text,
  armed_state text,
  occurred_at timestamptz not null,
  raw_payload jsonb not null default '{}'::jsonb
);

create index if not exists site_alarm_events_site_occurred_idx
  on public.site_alarm_events (site_id, occurred_at desc);

create index if not exists site_alarm_events_device_occurred_idx
  on public.site_alarm_events (device_id, occurred_at desc);

alter table public.site_alarm_events enable row level security;

drop policy if exists "anon_can_read_site_alarm_events"
  on public.site_alarm_events;

create policy "anon_can_read_site_alarm_events"
  on public.site_alarm_events
  for select
  to anon
  using (true);

drop policy if exists "anon_can_insert_site_alarm_events"
  on public.site_alarm_events;

create policy "anon_can_insert_site_alarm_events"
  on public.site_alarm_events
  for insert
  to anon
  with check (true);
