create table if not exists public.guard_ops_replay_safety_checks (
  id uuid primary key default gen_random_uuid(),
  checked_at timestamptz not null default timezone('utc', now()),
  keep_days integer not null,
  cutoff_at timestamptz not null,
  high_volume_event_types text[] not null,
  high_volume_events_before_cutoff bigint not null default 0,
  non_high_volume_events_before_cutoff bigint not null default 0,
  oldest_high_volume_event_at timestamptz,
  oldest_non_high_volume_event_at timestamptz,
  replay_safe boolean not null default false,
  recommendation text not null
);

create table if not exists public.guard_ops_retention_runs (
  id uuid primary key default gen_random_uuid(),
  ran_at timestamptz not null default timezone('utc', now()),
  projection_keep_days integer not null,
  synced_operation_keep_days integer not null,
  guard_ops_keep_days integer not null,
  projection_run_id uuid not null
    references public.guard_projection_retention_runs (id)
    on delete restrict,
  replay_safety_check_id uuid not null
    references public.guard_ops_replay_safety_checks (id)
    on delete restrict,
  guard_ops_pruned boolean not null default false,
  replay_safe boolean not null default false,
  note text
);

create or replace function public.assess_guard_ops_replay_safety(
  keep_days integer default 365,
  high_volume_event_types text[] default array[
    'GPS_HEARTBEAT',
    'WEARABLE_HEARTBEAT',
    'DEVICE_HEALTH'
  ]::text[]
)
returns public.guard_ops_replay_safety_checks
language plpgsql
security definer
set search_path = public
as $$
declare
  cutoff timestamptz;
  high_volume_count bigint := 0;
  non_high_volume_count bigint := 0;
  oldest_high_volume timestamptz;
  oldest_non_high_volume timestamptz;
  safe_for_prune boolean := false;
  recommendation_text text;
  check_row public.guard_ops_replay_safety_checks;
begin
  if keep_days < 1 then
    raise exception 'keep_days must be >= 1';
  end if;

  if array_length(high_volume_event_types, 1) is null then
    raise exception 'high_volume_event_types must contain at least one event type';
  end if;

  cutoff := timezone('utc', now()) - make_interval(days => keep_days);

  select count(*), min(occurred_at)
  into high_volume_count, oldest_high_volume
  from public.guard_ops_events
  where occurred_at < cutoff
    and event_type = any(high_volume_event_types);

  select count(*), min(occurred_at)
  into non_high_volume_count, oldest_non_high_volume
  from public.guard_ops_events
  where occurred_at < cutoff
    and event_type <> all(high_volume_event_types);

  safe_for_prune := non_high_volume_count = 0;
  recommendation_text := case
    when safe_for_prune and high_volume_count > 0 then
      'Replay safety check passed. Only high-volume heartbeat classes are older than the keep window; candidate archival can be planned without touching non-heartbeat evidence.'
    when safe_for_prune and high_volume_count = 0 then
      'Replay safety check passed. No canonical events are older than the keep window.'
    else
      'Replay safety check failed for prune planning. Non-high-volume canonical events exist before cutoff; do not prune guard_ops_events.'
  end;

  insert into public.guard_ops_replay_safety_checks (
    keep_days,
    cutoff_at,
    high_volume_event_types,
    high_volume_events_before_cutoff,
    non_high_volume_events_before_cutoff,
    oldest_high_volume_event_at,
    oldest_non_high_volume_event_at,
    replay_safe,
    recommendation
  )
  values (
    keep_days,
    cutoff,
    high_volume_event_types,
    high_volume_count,
    non_high_volume_count,
    oldest_high_volume,
    oldest_non_high_volume,
    safe_for_prune,
    recommendation_text
  )
  returning *
  into check_row;

  return check_row;
end;
$$;

create or replace function public.apply_guard_ops_retention_plan(
  projection_keep_days integer default 90,
  synced_operation_keep_days integer default 30,
  guard_ops_keep_days integer default 365,
  note text default null
)
returns public.guard_ops_retention_runs
language plpgsql
security definer
set search_path = public
as $$
declare
  projection_run public.guard_projection_retention_runs;
  replay_check public.guard_ops_replay_safety_checks;
  run_row public.guard_ops_retention_runs;
begin
  projection_run := public.apply_guard_projection_retention(
    projection_keep_days,
    synced_operation_keep_days,
    note
  );

  replay_check := public.assess_guard_ops_replay_safety(guard_ops_keep_days);

  insert into public.guard_ops_retention_runs (
    projection_keep_days,
    synced_operation_keep_days,
    guard_ops_keep_days,
    projection_run_id,
    replay_safety_check_id,
    guard_ops_pruned,
    replay_safe,
    note
  )
  values (
    projection_keep_days,
    synced_operation_keep_days,
    guard_ops_keep_days,
    projection_run.id,
    replay_check.id,
    false,
    replay_check.replay_safe,
    note
  )
  returning *
  into run_row;

  return run_row;
end;
$$;

comment on table public.guard_ops_replay_safety_checks is
  'Audit rows for canonical guard_ops_events replay-safety assessments prior to any archival planning.';

comment on table public.guard_ops_retention_runs is
  'Retention orchestration runs combining projection pruning + canonical replay-safety checks. guard_ops_events pruning remains disabled by policy.';

comment on function public.assess_guard_ops_replay_safety(integer, text[]) is
  'Evaluates whether only high-volume heartbeat classes are older than cutoff; used before any canonical event archival decision.';

comment on function public.apply_guard_ops_retention_plan(integer, integer, integer, text) is
  'Runs projection retention and logs canonical replay-safety assessment in one operation.';
