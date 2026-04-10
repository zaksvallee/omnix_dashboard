create extension if not exists pgcrypto;

create table if not exists public.site_camera_zones (
  id uuid primary key default gen_random_uuid(),
  site_id text not null,
  channel_id int not null,
  zone_name text not null,
  zone_type text not null,
  is_perimeter boolean not null default false,
  is_indoor boolean not null default false,
  notes text,
  unique (site_id, channel_id)
);

insert into public.site_camera_zones (
  site_id,
  channel_id,
  zone_name,
  zone_type,
  is_perimeter,
  is_indoor
)
values
  ('SITE-MS-VALLEE-RESIDENCE', 1,  'Street East Gate',        'perimeter',      true,  false),
  ('SITE-MS-VALLEE-RESIDENCE', 2,  'Back Kitchen Door',       'semi_perimeter', false, false),
  ('SITE-MS-VALLEE-RESIDENCE', 3,  'Main Gate Driveway',      'perimeter',      true,  false),
  ('SITE-MS-VALLEE-RESIDENCE', 4,  'Front Yard Pedestrian',   'perimeter',      true,  false),
  ('SITE-MS-VALLEE-RESIDENCE', 5,  'Interior Passage',        'indoor',         false, true),
  ('SITE-MS-VALLEE-RESIDENCE', 6,  'Inner Pedestrian Gate',   'semi_perimeter', false, false),
  ('SITE-MS-VALLEE-RESIDENCE', 7,  'Street West Gate',        'perimeter',      true,  false),
  ('SITE-MS-VALLEE-RESIDENCE', 8,  'Kitchen Extension',       'indoor',         false, true),
  ('SITE-MS-VALLEE-RESIDENCE', 9,  'Back Yard House',         'semi_perimeter', false, false),
  ('SITE-MS-VALLEE-RESIDENCE', 10, 'Dining Garage Access',    'indoor',         false, true),
  ('SITE-MS-VALLEE-RESIDENCE', 11, 'Kitchen',                 'indoor',         false, true),
  ('SITE-MS-VALLEE-RESIDENCE', 12, 'Garage',                  'indoor',         false, true),
  ('SITE-MS-VALLEE-RESIDENCE', 13, 'Inner Pedestrian Gate 2', 'semi_perimeter', false, false),
  ('SITE-MS-VALLEE-RESIDENCE', 14, 'Driveway',                'semi_perimeter', false, false),
  ('SITE-MS-VALLEE-RESIDENCE', 15, 'Pedestrian Path',         'semi_perimeter', false, false),
  ('SITE-MS-VALLEE-RESIDENCE', 16, 'Lounge Front Door',       'indoor',         false, true)
on conflict (site_id, channel_id) do update
set zone_name = excluded.zone_name,
    zone_type = excluded.zone_type,
    is_perimeter = excluded.is_perimeter,
    is_indoor = excluded.is_indoor;

alter table public.site_camera_zones enable row level security;

drop policy if exists "anon_can_read_site_camera_zones"
  on public.site_camera_zones;

create policy "anon_can_read_site_camera_zones"
  on public.site_camera_zones
  for select
  to anon
  using (true);
