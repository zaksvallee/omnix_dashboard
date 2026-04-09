alter table public.site_occupancy_config
add column if not exists has_gate_sensors boolean default false;
