create extension if not exists pgcrypto;

create or replace function public.set_client_conversation_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.client_conversation_messages (
  id uuid primary key default gen_random_uuid(),
  client_id text not null,
  site_id text not null,
  author text not null,
  body text not null,
  room_key text not null,
  viewer_role text not null,
  incident_status_label text not null default 'Update',
  occurred_at timestamptz not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint client_conversation_messages_body_not_blank
    check (length(btrim(body)) > 0)
);

create index if not exists client_conversation_messages_client_site_idx
  on public.client_conversation_messages (client_id, site_id);

create index if not exists client_conversation_messages_occurred_at_idx
  on public.client_conversation_messages (client_id, site_id, occurred_at desc);

drop trigger if exists set_client_conversation_messages_updated_at
  on public.client_conversation_messages;

create trigger set_client_conversation_messages_updated_at
before update on public.client_conversation_messages
for each row
execute function public.set_client_conversation_updated_at();

create table if not exists public.client_conversation_acknowledgements (
  id uuid primary key default gen_random_uuid(),
  client_id text not null,
  site_id text not null,
  message_key text not null,
  channel text not null,
  acknowledged_by text not null,
  acknowledged_at timestamptz not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint client_conversation_acknowledgements_message_key_not_blank
    check (length(btrim(message_key)) > 0),
  constraint client_conversation_ack_unique
    unique (client_id, site_id, message_key, channel)
);

create index if not exists client_conversation_ack_client_site_idx
  on public.client_conversation_acknowledgements (client_id, site_id);

create index if not exists client_conversation_ack_acknowledged_at_idx
  on public.client_conversation_acknowledgements (
    client_id,
    site_id,
    acknowledged_at desc
  );

drop trigger if exists set_client_conversation_ack_updated_at
  on public.client_conversation_acknowledgements;

create trigger set_client_conversation_ack_updated_at
before update on public.client_conversation_acknowledgements
for each row
execute function public.set_client_conversation_updated_at();

comment on table public.client_conversation_messages is
  'ONYX client app thread messages, scoped by client_id and site_id.';

comment on table public.client_conversation_acknowledgements is
  'ONYX client app acknowledgement state, scoped by client_id and site_id.';

comment on function public.set_client_conversation_updated_at() is
  'Shared updated_at trigger used by ONYX client conversation tables.';

-- Apply RLS policies for your auth model before using the anon key in production.
-- The Flutter repository currently expects read/write access on both tables for
-- the active client_id + site_id scope.
