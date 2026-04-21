create extension if not exists pgcrypto;

create table if not exists public.guard_ops_events (
  id uuid primary key default gen_random_uuid(),
  event_id text not null,
  guard_id text not null,
  site_id text not null,
  shift_id text not null,
  event_type text not null,
  sequence integer not null,
  occurred_at timestamptz not null,
  received_at timestamptz not null default timezone('utc', now()),
  device_id text not null,
  app_version text not null,
  payload jsonb not null default '{}'::jsonb,
  constraint guard_ops_events_event_id_not_blank
    check (length(btrim(event_id)) > 0),
  constraint guard_ops_events_guard_id_not_blank
    check (length(btrim(guard_id)) > 0),
  constraint guard_ops_events_site_id_not_blank
    check (length(btrim(site_id)) > 0),
  constraint guard_ops_events_shift_id_not_blank
    check (length(btrim(shift_id)) > 0),
  constraint guard_ops_events_event_type_not_blank
    check (length(btrim(event_type)) > 0),
  constraint guard_ops_events_device_id_not_blank
    check (length(btrim(device_id)) > 0),
  constraint guard_ops_events_app_version_not_blank
    check (length(btrim(app_version)) > 0),
  constraint guard_ops_events_sequence_positive
    check (sequence > 0),
  constraint guard_ops_events_event_id_unique
    unique (event_id),
  constraint guard_ops_events_shift_sequence_unique
    unique (shift_id, sequence)
);

create index if not exists guard_ops_events_site_occurred_idx
  on public.guard_ops_events (site_id, occurred_at desc);

create index if not exists guard_ops_events_guard_occurred_idx
  on public.guard_ops_events (guard_id, occurred_at desc);

create index if not exists guard_ops_events_shift_sequence_idx
  on public.guard_ops_events (shift_id, sequence);

create or replace function public.guard_ops_events_reject_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'guard_ops_events is append-only; UPDATE/DELETE is not permitted';
end;
$$;

drop trigger if exists guard_ops_events_reject_update
  on public.guard_ops_events;
create trigger guard_ops_events_reject_update
before update on public.guard_ops_events
for each row
execute function public.guard_ops_events_reject_mutation();

drop trigger if exists guard_ops_events_reject_delete
  on public.guard_ops_events;
create trigger guard_ops_events_reject_delete
before delete on public.guard_ops_events
for each row
execute function public.guard_ops_events_reject_mutation();

create table if not exists public.guard_ops_media (
  id uuid primary key default gen_random_uuid(),
  media_id text not null,
  event_id text not null,
  guard_id text not null,
  site_id text not null,
  shift_id text not null,
  bucket text not null,
  path text not null,
  local_path text not null,
  captured_at timestamptz not null,
  uploaded_at timestamptz,
  sha256 text,
  upload_status text not null default 'queued',
  retry_count integer not null default 0,
  failure_reason text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint guard_ops_media_media_id_not_blank
    check (length(btrim(media_id)) > 0),
  constraint guard_ops_media_event_id_not_blank
    check (length(btrim(event_id)) > 0),
  constraint guard_ops_media_guard_id_not_blank
    check (length(btrim(guard_id)) > 0),
  constraint guard_ops_media_site_id_not_blank
    check (length(btrim(site_id)) > 0),
  constraint guard_ops_media_shift_id_not_blank
    check (length(btrim(shift_id)) > 0),
  constraint guard_ops_media_bucket_not_blank
    check (length(btrim(bucket)) > 0),
  constraint guard_ops_media_path_not_blank
    check (length(btrim(path)) > 0),
  constraint guard_ops_media_local_path_not_blank
    check (length(btrim(local_path)) > 0),
  constraint guard_ops_media_status_not_blank
    check (length(btrim(upload_status)) > 0),
  constraint guard_ops_media_retry_non_negative
    check (retry_count >= 0),
  constraint guard_ops_media_media_id_unique
    unique (media_id),
  constraint guard_ops_media_event_path_unique
    unique (event_id, path),
  constraint guard_ops_media_event_fk
    foreign key (event_id)
    references public.guard_ops_events (event_id)
    on delete restrict
);

create index if not exists guard_ops_media_guard_captured_idx
  on public.guard_ops_media (guard_id, captured_at desc);

create index if not exists guard_ops_media_site_captured_idx
  on public.guard_ops_media (site_id, captured_at desc);

create index if not exists guard_ops_media_shift_captured_idx
  on public.guard_ops_media (shift_id, captured_at desc);

create index if not exists guard_ops_media_status_idx
  on public.guard_ops_media (upload_status, created_at desc);

create or replace function public.set_guard_ops_media_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists set_guard_ops_media_updated_at
  on public.guard_ops_media;
create trigger set_guard_ops_media_updated_at
before update on public.guard_ops_media
for each row
execute function public.set_guard_ops_media_updated_at();

insert into storage.buckets (id, name, public)
values
  ('guard-shift-verification', 'guard-shift-verification', false),
  ('guard-patrol-images', 'guard-patrol-images', false),
  ('guard-incident-media', 'guard-incident-media', false)
on conflict (id) do nothing;

comment on table public.guard_ops_events is
  'Canonical append-only guard operations event log.';

comment on table public.guard_ops_media is
  'Guard media metadata and upload state linked to guard_ops_events.';

-- NOTE: enable + validate RLS policies for all new tables and storage buckets.
