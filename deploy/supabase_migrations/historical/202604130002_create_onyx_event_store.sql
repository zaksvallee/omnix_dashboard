create extension if not exists pgcrypto;

create table if not exists public.onyx_event_store (
  id uuid primary key default gen_random_uuid(),
  sequence bigint not null,
  site_id text not null,
  client_id text not null default '',
  event_type text not null,
  event_data jsonb not null,
  occurred_at timestamptz not null,
  hash text not null,
  previous_hash text not null
);

create unique index if not exists onyx_event_store_site_sequence_idx
  on public.onyx_event_store (site_id, sequence);

create index if not exists onyx_event_store_site_occurred_at_idx
  on public.onyx_event_store (site_id, occurred_at desc);

create index if not exists onyx_event_store_client_occurred_at_idx
  on public.onyx_event_store (client_id, occurred_at desc);
