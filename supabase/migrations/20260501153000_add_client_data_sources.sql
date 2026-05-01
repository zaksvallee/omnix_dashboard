create table if not exists public.client_data_sources (
  id uuid primary key default gen_random_uuid(),
  client_id text not null
    references public.clients (client_id)
    on delete cascade,
  site_id text not null
    references public.sites (site_id)
    on delete cascade,
  data_source_key text not null,
  active boolean not null default true,
  provisioned_at timestamptz not null default timezone('utc', now()),
  deprovisioned_at timestamptz,
  activation_source text not null default 'manual',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint client_data_sources_scope_unique
    unique (client_id, site_id, data_source_key),
  constraint client_data_sources_data_source_key_not_blank
    check (length(btrim(data_source_key)) > 0),
  constraint client_data_sources_activation_source_not_blank
    check (length(btrim(activation_source)) > 0),
  constraint client_data_sources_metadata_is_object
    check (jsonb_typeof(metadata) = 'object'),
  constraint client_data_sources_deprovision_window_valid
    check (
      deprovisioned_at is null
      or deprovisioned_at >= provisioned_at
    )
);

create index if not exists client_data_sources_site_active_idx
  on public.client_data_sources (site_id, active, data_source_key);

create index if not exists client_data_sources_client_active_idx
  on public.client_data_sources (client_id, active, site_id);

drop trigger if exists set_client_data_sources_updated_at
  on public.client_data_sources;
create trigger set_client_data_sources_updated_at
before update on public.client_data_sources
for each row
execute function public.set_guard_directory_updated_at();

insert into public.client_data_sources (
  client_id,
  site_id,
  data_source_key,
  active,
  provisioned_at,
  activation_source,
  metadata
)
select
  seed.client_id,
  seed.site_id,
  seed.data_source_key,
  true,
  timezone('utc', now()),
  'migration_backfill',
  jsonb_build_object(
    'seed_basis', seed.seed_basis,
    'backfilled_by_migration', '20260501153000_add_client_data_sources'
  )
from (
  select
    s.client_id,
    s.site_id,
    data_source_key,
    'baseline_site_scope'::text as seed_basis
  from public.sites s
  cross join lateral unnest(
    array['dispatch_events', 'incident_notes', 'shift_instances']
  ) as data_source_key

  union all

  select
    s.client_id,
    s.site_id,
    'cv_pipeline_footfall' as data_source_key,
    'site_occupancy_signal'::text as seed_basis
  from public.sites s
  where exists (
    select 1
    from public.site_occupancy_config soc
    where soc.site_id = s.site_id
  )
  or exists (
    select 1
    from public.site_occupancy_sessions sos
    where sos.site_id = s.site_id
  )

  union all

  select
    s.client_id,
    s.site_id,
    'fr_person_registry' as data_source_key,
    'face_registry_signal'::text as seed_basis
  from public.sites s
  where exists (
    select 1
    from public.fr_person_registry fpr
    where fpr.site_id = s.site_id
  )

  union all

  select
    s.client_id,
    s.site_id,
    'bi_vehicle_persistence' as data_source_key,
    'vehicle_analytics_signal'::text as seed_basis
  from public.sites s
  where exists (
    select 1
    from public.site_vehicle_registry svr
    where svr.site_id = s.site_id
  )
  or exists (
    select 1
    from public.site_intelligence_profiles sip
    where sip.site_id = s.site_id
      and sip.monitor_vehicle_movement = true
  )
) as seed
on conflict (client_id, site_id, data_source_key) do nothing;

comment on table public.client_data_sources is
  'Explicit site-scoped Zara data-source activations. Used as the primary activation truth when present, with runtime inference retained as a migration fallback.';

comment on column public.client_data_sources.activation_source is
  'Why this activation row exists (manual, migration_backfill, sync, etc.).';

alter table public.client_data_sources enable row level security;

drop policy if exists client_data_sources_service_role_all
  on public.client_data_sources;

create policy client_data_sources_service_role_all
  on public.client_data_sources
  for all
  to service_role
  using (true)
  with check (true);

grant select, insert, update, delete on public.client_data_sources
  to service_role;
