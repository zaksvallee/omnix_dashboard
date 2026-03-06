create table if not exists public.guard_projection_retention_runs (
  id uuid primary key default gen_random_uuid(),
  ran_at timestamptz not null default timezone('utc', now()),
  keep_days integer not null,
  synced_operation_keep_days integer not null,
  deleted_location_heartbeats bigint not null default 0,
  deleted_checkpoint_scans bigint not null default 0,
  deleted_incident_captures bigint not null default 0,
  deleted_panic_signals bigint not null default 0,
  deleted_synced_operations bigint not null default 0,
  note text
);

create or replace function public.apply_guard_projection_retention(
  keep_days integer default 90,
  synced_operation_keep_days integer default 30,
  note text default null
)
returns public.guard_projection_retention_runs
language plpgsql
security definer
set search_path = public
as $$
declare
  keep_cutoff timestamptz;
  synced_cutoff timestamptz;
  location_deleted bigint := 0;
  checkpoint_deleted bigint := 0;
  incident_deleted bigint := 0;
  panic_deleted bigint := 0;
  synced_ops_deleted bigint := 0;
  run_row public.guard_projection_retention_runs;
begin
  if keep_days < 1 then
    raise exception 'keep_days must be >= 1';
  end if;
  if synced_operation_keep_days < 1 then
    raise exception 'synced_operation_keep_days must be >= 1';
  end if;

  keep_cutoff := timezone('utc', now()) - make_interval(days => keep_days);
  synced_cutoff := timezone('utc', now())
    - make_interval(days => synced_operation_keep_days);

  delete from public.guard_location_heartbeats
  where recorded_at < keep_cutoff;
  get diagnostics location_deleted = row_count;

  delete from public.guard_checkpoint_scans
  where scanned_at < keep_cutoff;
  get diagnostics checkpoint_deleted = row_count;

  delete from public.guard_incident_captures
  where captured_at < keep_cutoff;
  get diagnostics incident_deleted = row_count;

  delete from public.guard_panic_signals
  where triggered_at < keep_cutoff;
  get diagnostics panic_deleted = row_count;

  delete from public.guard_sync_operations
  where operation_status = 'synced'
    and occurred_at < synced_cutoff;
  get diagnostics synced_ops_deleted = row_count;

  insert into public.guard_projection_retention_runs (
    keep_days,
    synced_operation_keep_days,
    deleted_location_heartbeats,
    deleted_checkpoint_scans,
    deleted_incident_captures,
    deleted_panic_signals,
    deleted_synced_operations,
    note
  )
  values (
    keep_days,
    synced_operation_keep_days,
    location_deleted,
    checkpoint_deleted,
    incident_deleted,
    panic_deleted,
    synced_ops_deleted,
    note
  )
  returning *
  into run_row;

  return run_row;
end;
$$;

comment on table public.guard_projection_retention_runs is
  'Audit log for projection-table retention runs. Canonical guard_ops_events are never pruned by this job.';

comment on function public.apply_guard_projection_retention(integer, integer, text) is
  'Prunes high-volume guard projection tables while preserving canonical append-only guard_ops_events.';
