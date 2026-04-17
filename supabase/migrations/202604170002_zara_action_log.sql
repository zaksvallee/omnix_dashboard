create table if not exists public.zara_action_log (
  id uuid primary key default gen_random_uuid(),
  org_id text not null default coalesce(nullif(auth.jwt() ->> 'org_id', ''), 'global'),
  scenario_id text not null references public.zara_scenarios(id) on delete cascade,
  action_kind text not null,
  proposed_at timestamptz not null default timezone('utc', now()),
  outcome text not null,
  executed_at timestamptz,
  payload_jsonb jsonb not null default '{}'::jsonb,
  result_jsonb jsonb not null default '{}'::jsonb
);

create index if not exists zara_action_log_scenario_idx
  on public.zara_action_log (scenario_id, proposed_at asc);

create index if not exists zara_action_log_org_idx
  on public.zara_action_log (org_id, proposed_at desc);

alter table public.zara_action_log enable row level security;

drop policy if exists zara_action_log_service_all
  on public.zara_action_log;
create policy zara_action_log_service_all
  on public.zara_action_log
  for all
  to service_role
  using (true)
  with check (true);

drop policy if exists zara_action_log_authenticated_select
  on public.zara_action_log;
create policy zara_action_log_authenticated_select
  on public.zara_action_log
  for select
  to authenticated
  using (
    org_id = coalesce(nullif(auth.jwt() ->> 'org_id', ''), 'global')
  );

drop policy if exists zara_action_log_authenticated_insert
  on public.zara_action_log;
create policy zara_action_log_authenticated_insert
  on public.zara_action_log
  for insert
  to authenticated
  with check (
    org_id = coalesce(nullif(auth.jwt() ->> 'org_id', ''), 'global')
  );

comment on table public.zara_action_log is
  'Append-only forensic trail of Zara Theatre action proposals and outcomes.';
