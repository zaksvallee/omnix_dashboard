create table if not exists public.site_shift_schedules (
  site_id text primary key,
  client_id text not null,
  region_id text not null,
  timezone text not null default 'Africa/Johannesburg',
  enabled boolean not null default true,
  start_hour integer not null default 18,
  start_minute integer not null default 0,
  end_hour integer not null default 18,
  end_minute integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create index if not exists site_shift_schedules_client_idx
  on public.site_shift_schedules (client_id, site_id);
