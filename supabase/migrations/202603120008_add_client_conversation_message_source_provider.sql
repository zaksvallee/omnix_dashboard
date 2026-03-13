alter table public.client_conversation_messages
  add column if not exists message_source text not null default 'in_app';

alter table public.client_conversation_messages
  add column if not exists message_provider text not null default 'in_app';

update public.client_conversation_messages
set message_source = 'in_app'
where btrim(message_source) = '';

update public.client_conversation_messages
set message_provider = 'in_app'
where btrim(message_provider) = '';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'client_conversation_messages_source_valid'
      and conrelid = 'public.client_conversation_messages'::regclass
  ) then
    alter table public.client_conversation_messages
      add constraint client_conversation_messages_source_valid
      check (message_source in ('in_app', 'telegram', 'system'));
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'client_conversation_messages_provider_not_blank'
      and conrelid = 'public.client_conversation_messages'::regclass
  ) then
    alter table public.client_conversation_messages
      add constraint client_conversation_messages_provider_not_blank
      check (length(btrim(message_provider)) > 0);
  end if;
end
$$;

comment on column public.client_conversation_messages.message_source is
  'Source lane for the conversation message (in_app, telegram, system).';

comment on column public.client_conversation_messages.message_provider is
  'Provider identity for delivery/origin (e.g., in_app, telegram, openai).';
