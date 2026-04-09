create table if not exists public.telegram_inbound_updates (
  id          uuid        primary key default gen_random_uuid(),
  update_id   bigint,
  chat_id     text,
  update_json jsonb       not null,
  received_at timestamptz not null default timezone('utc', now()),
  processed   boolean     not null default false
);

-- Unique constraint so duplicate deliveries from Telegram are idempotent.
create unique index if not exists telegram_inbound_updates_update_id_unique
  on public.telegram_inbound_updates (update_id)
  where update_id is not null;

-- Fast lookup for the processor: unprocessed rows ordered by arrival.
create index if not exists telegram_inbound_updates_unprocessed
  on public.telegram_inbound_updates (received_at asc)
  where processed = false;

-- Per-chat history queries.
create index if not exists telegram_inbound_updates_chat_received
  on public.telegram_inbound_updates (chat_id, received_at desc);

alter table public.telegram_inbound_updates enable row level security;

-- Service role bypasses RLS — inserts from the webhook process use the
-- service key and never hit these policies.

-- Authenticated dashboard users can read all inbound updates (support / ops).
drop policy if exists telegram_inbound_updates_select_policy
  on public.telegram_inbound_updates;
create policy telegram_inbound_updates_select_policy
  on public.telegram_inbound_updates
  for select
  to authenticated
  using (true);

-- No direct insert/update/delete for authenticated users —
-- all writes go through the service role.

comment on table public.telegram_inbound_updates is
  'Raw Telegram update payloads received by the webhook server. '
  'Inserts are service-role only; reads are open to authenticated dashboard users.';

comment on column public.telegram_inbound_updates.update_id is
  'Telegram update_id — unique per bot. Used to deduplicate redeliveries.';
comment on column public.telegram_inbound_updates.chat_id is
  'Extracted chat.id for fast per-chat queries without parsing update_json.';
comment on column public.telegram_inbound_updates.update_json is
  'Full Telegram Update object as received.';
comment on column public.telegram_inbound_updates.processed is
  'Set to true by the processor once the update has been handled.';
