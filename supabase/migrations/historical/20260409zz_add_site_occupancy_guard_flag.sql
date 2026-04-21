alter table public.site_occupancy_config
add column if not exists has_guard boolean default false;

update public.site_occupancy_config
set has_guard = false
where site_id = 'SITE-MS-VALLEE-RESIDENCE';
