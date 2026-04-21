create extension if not exists pgcrypto;

create table if not exists public.site_vehicle_presence (
  id uuid primary key default gen_random_uuid(),
  site_id text not null,
  plate_number text not null,
  owner_name text,
  event_type text not null,
  channel_id int,
  zone_name text,
  occurred_at timestamptz not null default now()
);

create index if not exists site_vehicle_presence_site_time_idx
  on public.site_vehicle_presence (site_id, occurred_at desc);

create index if not exists site_vehicle_presence_site_plate_time_idx
  on public.site_vehicle_presence (site_id, plate_number, occurred_at desc);

alter table public.site_vehicle_presence enable row level security;

drop policy if exists site_vehicle_presence_service_all
  on public.site_vehicle_presence;
create policy site_vehicle_presence_service_all
  on public.site_vehicle_presence
  for all
  to service_role
  using (true)
  with check (true);

drop policy if exists site_vehicle_presence_anon_read
  on public.site_vehicle_presence;
create policy site_vehicle_presence_anon_read
  on public.site_vehicle_presence
  for select
  to anon
  using (true);

drop policy if exists site_vehicle_presence_authenticated_read
  on public.site_vehicle_presence;
create policy site_vehicle_presence_authenticated_read
  on public.site_vehicle_presence
  for select
  to authenticated
  using (
    site_id = coalesce(auth.jwt() ->> 'site_id', '')
    or site_id = any(
      coalesce(
        string_to_array(nullif(auth.jwt() ->> 'site_ids', ''), ','),
        array[]::text[]
      )
    )
  );
