alter table public.client_conversation_push_sync_state
  add column if not exists probe_status_label text not null default 'idle',
  add column if not exists probe_last_run_at timestamptz,
  add column if not exists probe_failure_reason text,
  add column if not exists probe_history jsonb not null default '[]'::jsonb;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'client_conversation_push_sync_state_probe_history_is_array'
      and conrelid = 'public.client_conversation_push_sync_state'::regclass
  ) then
    alter table public.client_conversation_push_sync_state
      add constraint client_conversation_push_sync_state_probe_history_is_array
        check (jsonb_typeof(probe_history) = 'array');
  end if;
end
$$;
