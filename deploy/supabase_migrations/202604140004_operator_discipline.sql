alter table public.incidents
  add column if not exists simulated boolean not null default false,
  add column if not exists simulation_id text,
  add column if not exists revealed_at timestamptz;

create table if not exists public.onyx_operator_simulations (
  id text primary key,
  incident_id text not null,
  incident_event_uid text not null,
  operator_id text not null,
  site_id text not null,
  client_id text not null default '',
  simulated boolean not null default true,
  scenario_type text not null,
  expected_decision text not null,
  injected_at timestamptz not null,
  response_at timestamptz null,
  revealed_at timestamptz null,
  response_seconds double precision null,
  action_taken text null,
  escalation_decision text null,
  completed boolean not null default false,
  score_delta double precision not null default 0,
  result_label text not null default 'pending',
  headline text not null default '',
  summary text not null default ''
);

create index if not exists onyx_operator_simulations_site_idx
  on public.onyx_operator_simulations (site_id, injected_at desc);

create index if not exists onyx_operator_simulations_operator_idx
  on public.onyx_operator_simulations (operator_id, injected_at desc);

create table if not exists public.onyx_operator_scores (
  operator_id text not null,
  site_id text not null,
  period text not null,
  avg_response_seconds double precision not null default 0,
  correct_decisions integer not null default 0,
  incorrect_decisions integer not null default 0,
  missed_escalations integer not null default 0,
  simulations_completed integer not null default 0,
  score double precision not null default 0,
  weaknesses jsonb not null default '[]'::jsonb,
  recommendations jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default timezone('utc', now()),
  primary key (operator_id, site_id, period)
);

alter table public.onyx_operator_simulations enable row level security;
alter table public.onyx_operator_scores enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'onyx_operator_simulations'
      and policyname = 'onyx_operator_simulations_service_role_all'
  ) then
    create policy onyx_operator_simulations_service_role_all
      on public.onyx_operator_simulations
      for all
      to service_role
      using (true)
      with check (true);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'onyx_operator_scores'
      and policyname = 'onyx_operator_scores_service_role_all'
  ) then
    create policy onyx_operator_scores_service_role_all
      on public.onyx_operator_scores
      for all
      to service_role
      using (true)
      with check (true);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'onyx_operator_simulations'
      and policyname = 'onyx_operator_simulations_authenticated_read'
  ) then
    create policy onyx_operator_simulations_authenticated_read
      on public.onyx_operator_simulations
      for select
      to authenticated
      using (
        site_id = coalesce(auth.jwt() ->> 'site_id', '')
        or site_id = any (
          coalesce(
            (
              select array_agg(value::text)
              from jsonb_array_elements_text(
                coalesce(auth.jwt() -> 'site_ids', '[]'::jsonb)
              )
            ),
            array[]::text[]
          )
        )
      );
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'onyx_operator_scores'
      and policyname = 'onyx_operator_scores_authenticated_read'
  ) then
    create policy onyx_operator_scores_authenticated_read
      on public.onyx_operator_scores
      for select
      to authenticated
      using (
        site_id = coalesce(auth.jwt() ->> 'site_id', '')
        or site_id = any (
          coalesce(
            (
              select array_agg(value::text)
              from jsonb_array_elements_text(
                coalesce(auth.jwt() -> 'site_ids', '[]'::jsonb)
              )
            ),
            array[]::text[]
          )
        )
      );
  end if;
end
$$;
