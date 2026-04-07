create table if not exists public.vehicle_visits (
  id uuid primary key default gen_random_uuid(),
  client_id text not null,
  site_id text not null,
  vehicle_key text not null,
  plate_number text not null,
  started_at_utc timestamptz not null,
  last_seen_at_utc timestamptz not null,
  completed_at_utc timestamptz,
  saw_entry boolean not null default false,
  saw_service boolean not null default false,
  saw_exit boolean not null default false,
  dwell_minutes double precision,
  visit_status text not null check (visit_status in ('completed', 'incomplete', 'active')),
  is_suspicious_short boolean not null default false,
  is_loitering boolean not null default false,
  event_count int not null default 0,
  event_ids text[] not null default '{}'::text[],
  intelligence_ids text[] not null default '{}'::text[],
  zone_labels text[] not null default '{}'::text[],
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists vehicle_visits_scope_started
  on public.vehicle_visits (client_id, site_id, started_at_utc desc);

create index if not exists vehicle_visits_scope_plate
  on public.vehicle_visits (client_id, site_id, vehicle_key, started_at_utc desc);

create index if not exists vehicle_visits_scope_exception
  on public.vehicle_visits (
    client_id,
    site_id,
    is_loitering,
    is_suspicious_short,
    started_at_utc desc
  );

create unique index if not exists vehicle_visits_upsert_key
  on public.vehicle_visits (client_id, site_id, vehicle_key, started_at_utc);

create table if not exists public.hourly_throughput (
  id uuid primary key default gen_random_uuid(),
  client_id text not null,
  site_id text not null,
  visit_date date not null,
  hour_of_day int not null check (hour_of_day >= 0 and hour_of_day <= 23),
  visit_count int not null default 0,
  completed_count int not null default 0,
  entry_count int not null default 0,
  exit_count int not null default 0,
  service_count int not null default 0,
  avg_dwell_minutes double precision,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (client_id, site_id, visit_date, hour_of_day)
);

create index if not exists hourly_throughput_scope_date
  on public.hourly_throughput (client_id, site_id, visit_date desc, hour_of_day);

drop trigger if exists set_hourly_throughput_updated_at
  on public.hourly_throughput;
create trigger set_hourly_throughput_updated_at
before update on public.hourly_throughput
for each row
execute function public.set_guard_directory_updated_at();

alter table public.vehicle_visits enable row level security;
alter table public.hourly_throughput enable row level security;

drop policy if exists vehicle_visits_select_policy on public.vehicle_visits;
create policy vehicle_visits_select_policy
on public.vehicle_visits
for select
to authenticated
using (client_id = public.onyx_client_id());

drop policy if exists hourly_throughput_select_policy on public.hourly_throughput;
create policy hourly_throughput_select_policy
on public.hourly_throughput
for select
to authenticated
using (client_id = public.onyx_client_id());

comment on table public.vehicle_visits is
  'Phase 1 ONYX BI persistence for per-visit vehicle analytics. Writes are backend/service-role only; reads are client-scoped via RLS.';

comment on table public.hourly_throughput is
  'Phase 1 ONYX BI persistence for UTC-dated per-hour throughput buckets. Writes are backend/service-role only; reads are client-scoped via RLS.';
