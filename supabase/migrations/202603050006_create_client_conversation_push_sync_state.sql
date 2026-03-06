create extension if not exists pgcrypto;

create or replace function public.set_client_conversation_push_sync_state_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table if not exists public.client_conversation_push_sync_state (
  id uuid primary key default gen_random_uuid(),
  client_id text not null,
  site_id text not null,
  status_label text not null default 'idle',
  last_synced_at timestamptz,
  failure_reason text,
  retry_count integer not null default 0,
  history jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint client_conversation_push_sync_state_unique
    unique (client_id, site_id),
  constraint client_conversation_push_sync_state_retry_count_non_negative
    check (retry_count >= 0),
  constraint client_conversation_push_sync_state_history_is_array
    check (jsonb_typeof(history) = 'array')
);

create index if not exists client_conversation_push_sync_state_scope_idx
  on public.client_conversation_push_sync_state (client_id, site_id);

drop trigger if exists set_client_conversation_push_sync_state_updated_at
  on public.client_conversation_push_sync_state;

create trigger set_client_conversation_push_sync_state_updated_at
before update on public.client_conversation_push_sync_state
for each row
execute function public.set_client_conversation_push_sync_state_updated_at();
