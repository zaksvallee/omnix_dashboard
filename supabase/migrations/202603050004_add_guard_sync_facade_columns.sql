alter table if exists public.guard_sync_operations
  add column if not exists facade_id text;

alter table if exists public.guard_sync_operations
  add column if not exists facade_mode text;

alter table if exists public.guard_sync_operations
  drop constraint if exists guard_sync_operations_facade_mode_valid;

alter table if exists public.guard_sync_operations
  add constraint guard_sync_operations_facade_mode_valid
  check (
    facade_mode is null or facade_mode in ('live', 'stub', 'unknown')
  );

update public.guard_sync_operations
set
  facade_id = nullif(
    btrim(payload #>> '{onyx_runtime_context,telemetry_facade_id}'),
    ''
  ),
  facade_mode = case
    when lower(coalesce(payload #>> '{onyx_runtime_context,telemetry_facade_live_mode}', '')) = 'true' then 'live'
    when lower(coalesce(payload #>> '{onyx_runtime_context,telemetry_facade_live_mode}', '')) = 'false' then 'stub'
    when payload ? 'onyx_runtime_context' then 'unknown'
    else null
  end
where
  facade_id is null
  or facade_mode is null;

create index if not exists guard_sync_operations_facade_mode_idx
  on public.guard_sync_operations (facade_mode, occurred_at desc);

create index if not exists guard_sync_operations_client_site_guard_facade_idx
  on public.guard_sync_operations (
    client_id,
    site_id,
    guard_id,
    facade_mode,
    occurred_at desc
  );
