create table if not exists public.onyx_awareness_latency (
  alert_id text primary key,
  event_id text not null,
  site_id text not null,
  client_id text not null,
  dvr_event_at timestamptz not null,
  snapshot_at timestamptz null,
  yolo_at timestamptz null,
  telegram_at timestamptz null,
  total_ms integer null,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists onyx_awareness_latency_site_idx
  on public.onyx_awareness_latency (site_id, telegram_at desc);

alter table public.onyx_awareness_latency enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'onyx_awareness_latency'
      and policyname = 'onyx_awareness_latency_service_role_all'
  ) then
    create policy onyx_awareness_latency_service_role_all
      on public.onyx_awareness_latency
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
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'onyx_awareness_latency'
      and policyname = 'onyx_awareness_latency_authenticated_read'
  ) then
    create policy onyx_awareness_latency_authenticated_read
      on public.onyx_awareness_latency
      for select
      to authenticated
      using (
        coalesce(auth.jwt() ->> 'site_id', '') = site_id
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
