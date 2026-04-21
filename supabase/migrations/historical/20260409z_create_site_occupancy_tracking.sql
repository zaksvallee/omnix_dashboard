create table if not exists public.site_occupancy_config (
  site_id text primary key,
  expected_occupancy int not null default 0,
  occupancy_label text not null default 'people',
  site_type text not null default 'private_residence',
  reset_hour int not null default 3
);

insert into public.site_occupancy_config (
  site_id,
  expected_occupancy,
  occupancy_label,
  site_type
) values (
  'SITE-MS-VALLEE-RESIDENCE',
  4,
  'residents',
  'private_residence'
)
on conflict (site_id) do nothing;

create table if not exists public.site_occupancy_sessions (
  id uuid primary key default gen_random_uuid(),
  site_id text not null,
  session_date date not null default current_date,
  peak_detected int not null default 0,
  last_detection_at timestamptz,
  channels_with_detections text[] default '{}',
  updated_at timestamptz default now(),
  unique(site_id, session_date)
);

alter table public.site_occupancy_config enable row level security;
alter table public.site_occupancy_sessions enable row level security;

drop policy if exists "anon_can_read_site_occupancy_config"
  on public.site_occupancy_config;

create policy "anon_can_read_site_occupancy_config"
  on public.site_occupancy_config
  for select
  to anon
  using (true);

drop policy if exists "anon_can_read_site_occupancy_sessions"
  on public.site_occupancy_sessions;

create policy "anon_can_read_site_occupancy_sessions"
  on public.site_occupancy_sessions
  for select
  to anon
  using (true);
