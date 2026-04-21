alter table public.client_conversation_push_queue
  add column if not exists delivery_provider text not null default 'in_app';

update public.client_conversation_push_queue
set delivery_provider = 'in_app'
where delivery_provider is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'client_conversation_push_queue_delivery_provider_valid'
      and conrelid = 'public.client_conversation_push_queue'::regclass
  ) then
    alter table public.client_conversation_push_queue
      add constraint client_conversation_push_queue_delivery_provider_valid
        check (delivery_provider in ('in_app', 'telegram'));
  end if;
end
$$;
