create table if not exists public.zara_scenarios (
  id text primary key,
  org_id text not null default coalesce(nullif(auth.jwt() ->> 'org_id', ''), 'global'),
  kind text not null,
  summary text not null,
  origin_event_ids text[] not null default '{}',
  lifecycle_state text not null,
  created_at timestamptz not null default timezone('utc', now()),
  resolved_at timestamptz,
  controller_user_id uuid default auth.uid()
);

create index if not exists zara_scenarios_org_created_idx
  on public.zara_scenarios (org_id, created_at desc);

create index if not exists zara_scenarios_lifecycle_idx
  on public.zara_scenarios (lifecycle_state, created_at desc);

alter table public.zara_scenarios enable row level security;

drop policy if exists zara_scenarios_service_all
  on public.zara_scenarios;
create policy zara_scenarios_service_all
  on public.zara_scenarios
  for all
  to service_role
  using (true)
  with check (true);

drop policy if exists zara_scenarios_authenticated_select
  on public.zara_scenarios;
create policy zara_scenarios_authenticated_select
  on public.zara_scenarios
  for select
  to authenticated
  using (
    org_id = coalesce(nullif(auth.jwt() ->> 'org_id', ''), 'global')
  );

drop policy if exists zara_scenarios_authenticated_insert
  on public.zara_scenarios;
create policy zara_scenarios_authenticated_insert
  on public.zara_scenarios
  for insert
  to authenticated
  with check (
    org_id = coalesce(nullif(auth.jwt() ->> 'org_id', ''), 'global')
  );

drop policy if exists zara_scenarios_authenticated_update
  on public.zara_scenarios;
create policy zara_scenarios_authenticated_update
  on public.zara_scenarios
  for update
  to authenticated
  using (
    org_id = coalesce(nullif(auth.jwt() ->> 'org_id', ''), 'global')
  )
  with check (
    org_id = coalesce(nullif(auth.jwt() ->> 'org_id', ''), 'global')
  );

comment on table public.zara_scenarios is
  'Auditable Zara Theatre scenarios persisted across controller sessions.';

comment on column public.zara_scenarios.origin_event_ids is
  'Dispatch-event ids that caused Zara to surface the scenario.';
