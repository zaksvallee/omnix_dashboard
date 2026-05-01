create table if not exists public.zara_usage_ledger (
  id uuid primary key default gen_random_uuid(),
  client_id text not null,
  site_id text,
  audience text not null check (audience in ('client', 'admin')),
  delivery_mode text not null check (
    delivery_mode in ('telegram_live', 'approval_draft', 'sms_fallback')
  ),
  allowance_tier text not null check (
    allowance_tier in ('standard', 'premium', 'tactical')
  ),
  capability_key text,
  decision text not null check (
    decision in ('delegated', 'refused_data_source', 'fallback')
  ),
  provider_label text not null,
  used_fallback boolean not null default false,
  is_emergency boolean not null default false,
  billable_units integer not null default 0 check (billable_units >= 0),
  period_month date not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);

create index if not exists zara_usage_ledger_client_period_idx
  on public.zara_usage_ledger (client_id, period_month, created_at desc);

create index if not exists zara_usage_ledger_site_created_idx
  on public.zara_usage_ledger (site_id, created_at desc)
  where site_id is not null;

create or replace view public.zara_usage_monthly_summary as
select
  client_id,
  period_month,
  sum(billable_units)::bigint as total_units,
  count(*)::bigint as total_turns,
  count(*) filter (where is_emergency)::bigint as emergency_turns,
  max(created_at) as last_recorded_at
from public.zara_usage_ledger
group by client_id, period_month;

comment on table public.zara_usage_ledger is
  'Per-turn Zara allowance ledger. Records usage, billable units, emergency continuity, and delivery metadata without capability gating.';

comment on view public.zara_usage_monthly_summary is
  'Monthly Zara usage totals by client for allowance warnings and soft-overage handling.';

alter table public.zara_usage_ledger enable row level security;

drop policy if exists zara_usage_ledger_service_role_all
  on public.zara_usage_ledger;

create policy zara_usage_ledger_service_role_all
  on public.zara_usage_ledger
  for all
  to service_role
  using (true)
  with check (true);

grant select, insert on public.zara_usage_ledger to service_role;
grant select on public.zara_usage_monthly_summary to service_role;
