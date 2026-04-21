create extension if not exists pgcrypto;

create or replace function public.set_guard_sync_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.guard_sync_operations (
  id uuid primary key default gen_random_uuid(),
  operation_id text not null,
  operation_type text not null,
  operation_status text not null default 'queued',
  client_id text not null,
  site_id text not null,
  guard_id text not null,
  occurred_at timestamptz not null,
  payload jsonb not null,
  failure_reason text,
  retry_count integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint guard_sync_operations_operation_id_not_blank
    check (length(btrim(operation_id)) > 0),
  constraint guard_sync_operations_type_not_blank
    check (length(btrim(operation_type)) > 0),
  constraint guard_sync_operations_status_not_blank
    check (length(btrim(operation_status)) > 0),
  constraint guard_sync_operations_retry_count_non_negative
    check (retry_count >= 0),
  constraint guard_sync_operations_unique_op
    unique (client_id, site_id, guard_id, operation_id)
);

create index if not exists guard_sync_operations_status_idx
  on public.guard_sync_operations (operation_status, occurred_at desc);

create index if not exists guard_sync_operations_client_site_guard_idx
  on public.guard_sync_operations (client_id, site_id, guard_id, occurred_at desc);

drop trigger if exists set_guard_sync_operations_updated_at
  on public.guard_sync_operations;

create trigger set_guard_sync_operations_updated_at
before update on public.guard_sync_operations
for each row
execute function public.set_guard_sync_updated_at();

create table if not exists public.guard_assignments (
  id uuid primary key default gen_random_uuid(),
  assignment_id text not null,
  dispatch_id text not null,
  client_id text not null,
  site_id text not null,
  guard_id text not null,
  duty_status text not null default 'available',
  issued_at timestamptz not null,
  acknowledged_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint guard_assignments_assignment_id_not_blank
    check (length(btrim(assignment_id)) > 0),
  constraint guard_assignments_dispatch_id_not_blank
    check (length(btrim(dispatch_id)) > 0),
  constraint guard_assignments_status_not_blank
    check (length(btrim(duty_status)) > 0),
  constraint guard_assignments_unique_assignment
    unique (client_id, site_id, guard_id, assignment_id)
);

create index if not exists guard_assignments_client_site_guard_idx
  on public.guard_assignments (client_id, site_id, guard_id, issued_at desc);

create index if not exists guard_assignments_dispatch_idx
  on public.guard_assignments (dispatch_id);

drop trigger if exists set_guard_assignments_updated_at
  on public.guard_assignments;

create trigger set_guard_assignments_updated_at
before update on public.guard_assignments
for each row
execute function public.set_guard_sync_updated_at();

create table if not exists public.guard_location_heartbeats (
  id uuid primary key default gen_random_uuid(),
  heartbeat_id text not null,
  client_id text not null,
  site_id text not null,
  guard_id text not null,
  latitude double precision not null,
  longitude double precision not null,
  accuracy_meters double precision,
  recorded_at timestamptz not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint guard_location_heartbeats_heartbeat_id_not_blank
    check (length(btrim(heartbeat_id)) > 0),
  constraint guard_location_heartbeats_accuracy_non_negative
    check (accuracy_meters is null or accuracy_meters >= 0),
  constraint guard_location_heartbeats_unique_id
    unique (client_id, site_id, guard_id, heartbeat_id)
);

create index if not exists guard_location_heartbeats_client_site_guard_idx
  on public.guard_location_heartbeats (client_id, site_id, guard_id, recorded_at desc);

drop trigger if exists set_guard_location_heartbeats_updated_at
  on public.guard_location_heartbeats;

create trigger set_guard_location_heartbeats_updated_at
before update on public.guard_location_heartbeats
for each row
execute function public.set_guard_sync_updated_at();

create table if not exists public.guard_checkpoint_scans (
  id uuid primary key default gen_random_uuid(),
  scan_id text not null,
  client_id text not null,
  site_id text not null,
  guard_id text not null,
  checkpoint_id text not null,
  nfc_tag_id text not null,
  latitude double precision,
  longitude double precision,
  scanned_at timestamptz not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint guard_checkpoint_scans_scan_id_not_blank
    check (length(btrim(scan_id)) > 0),
  constraint guard_checkpoint_scans_checkpoint_id_not_blank
    check (length(btrim(checkpoint_id)) > 0),
  constraint guard_checkpoint_scans_nfc_tag_id_not_blank
    check (length(btrim(nfc_tag_id)) > 0),
  constraint guard_checkpoint_scans_unique_scan
    unique (client_id, site_id, guard_id, scan_id)
);

create index if not exists guard_checkpoint_scans_client_site_guard_idx
  on public.guard_checkpoint_scans (client_id, site_id, guard_id, scanned_at desc);

drop trigger if exists set_guard_checkpoint_scans_updated_at
  on public.guard_checkpoint_scans;

create trigger set_guard_checkpoint_scans_updated_at
before update on public.guard_checkpoint_scans
for each row
execute function public.set_guard_sync_updated_at();

create table if not exists public.guard_incident_captures (
  id uuid primary key default gen_random_uuid(),
  capture_id text not null,
  client_id text not null,
  site_id text not null,
  guard_id text not null,
  media_type text not null,
  local_reference text not null,
  dispatch_id text,
  captured_at timestamptz not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint guard_incident_captures_capture_id_not_blank
    check (length(btrim(capture_id)) > 0),
  constraint guard_incident_captures_media_type_not_blank
    check (length(btrim(media_type)) > 0),
  constraint guard_incident_captures_local_ref_not_blank
    check (length(btrim(local_reference)) > 0),
  constraint guard_incident_captures_unique_capture
    unique (client_id, site_id, guard_id, capture_id)
);

create index if not exists guard_incident_captures_client_site_guard_idx
  on public.guard_incident_captures (client_id, site_id, guard_id, captured_at desc);

create index if not exists guard_incident_captures_dispatch_idx
  on public.guard_incident_captures (dispatch_id);

drop trigger if exists set_guard_incident_captures_updated_at
  on public.guard_incident_captures;

create trigger set_guard_incident_captures_updated_at
before update on public.guard_incident_captures
for each row
execute function public.set_guard_sync_updated_at();

create table if not exists public.guard_panic_signals (
  id uuid primary key default gen_random_uuid(),
  signal_id text not null,
  client_id text not null,
  site_id text not null,
  guard_id text not null,
  latitude double precision,
  longitude double precision,
  triggered_at timestamptz not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint guard_panic_signals_signal_id_not_blank
    check (length(btrim(signal_id)) > 0),
  constraint guard_panic_signals_unique_signal
    unique (client_id, site_id, guard_id, signal_id)
);

create index if not exists guard_panic_signals_client_site_guard_idx
  on public.guard_panic_signals (client_id, site_id, guard_id, triggered_at desc);

drop trigger if exists set_guard_panic_signals_updated_at
  on public.guard_panic_signals;

create trigger set_guard_panic_signals_updated_at
before update on public.guard_panic_signals
for each row
execute function public.set_guard_sync_updated_at();

comment on table public.guard_sync_operations is
  'Offline guard operations queued and synchronized from Android guard devices.';

comment on table public.guard_assignments is
  'Guard dispatch assignments and duty-state transitions.';

comment on table public.guard_location_heartbeats is
  'Periodic guard GPS heartbeats from mobile device tracking.';

comment on table public.guard_checkpoint_scans is
  'NFC checkpoint verification scans for patrol compliance.';

comment on table public.guard_incident_captures is
  'Guard-captured incident media metadata (photo/video references).';

comment on table public.guard_panic_signals is
  'Emergency panic activations from guards.';

-- NOTE: Add RLS policies for your auth model before production usage.
