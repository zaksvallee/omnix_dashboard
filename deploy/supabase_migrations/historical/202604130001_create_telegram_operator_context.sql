create table if not exists public.telegram_operator_context (
  chat_id text not null,
  thread_id bigint not null default 0,
  context_json jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  constraint telegram_operator_context_pkey primary key (chat_id, thread_id)
);

create index if not exists telegram_operator_context_updated_at_idx
  on public.telegram_operator_context (updated_at desc);
