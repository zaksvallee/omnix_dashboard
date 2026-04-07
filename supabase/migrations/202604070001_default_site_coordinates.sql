alter table public.sites
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

alter table public.sites
  alter column latitude set default -26.2041,
  alter column longitude set default 28.0473;

update public.sites
set
  latitude = coalesce(latitude, -26.2041),
  longitude = coalesce(longitude, 28.0473)
where latitude is null or longitude is null;
