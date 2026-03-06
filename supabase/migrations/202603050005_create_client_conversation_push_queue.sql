create extension if not exists pgcrypto;

create or replace function public.set_client_conversation_push_queue_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.client_conversation_push_queue (
  id uuid primary key default gen_random_uuid(),
  client_id text not null,
  site_id text not null,
  message_key text not null,
  title text not null,
  body text not null,
  occurred_at timestamptz not null,
  target_channel text not null,
  priority boolean not null default false,
  status text not null default 'queued',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint client_conversation_push_queue_status_valid
    check (status in ('queued', 'acknowledged')),
  constraint client_conversation_push_queue_target_channel_valid
    check (target_channel in ('client', 'control', 'resident')),
  constraint client_conversation_push_queue_body_not_blank
    check (length(btrim(body)) > 0)
);

create unique index if not exists client_conversation_push_queue_message_key_idx
  on public.client_conversation_push_queue (client_id, site_id, message_key);

create index if not exists client_conversation_push_queue_occurred_idx
  on public.client_conversation_push_queue (client_id, site_id, occurred_at desc);

drop trigger if exists set_client_conversation_push_queue_updated_at
  on public.client_conversation_push_queue;

create trigger set_client_conversation_push_queue_updated_at
before update on public.client_conversation_push_queue
for each row
execute function public.set_client_conversation_push_queue_updated_at();
