create table if not exists public.onyx_alert_outcomes (
  alert_id text primary key,
  site_id text not null default '',
  client_id text not null default '',
  zone_id text not null default '',
  outcome text not null,
  operator_id text not null default '',
  note text,
  occurred_at timestamptz not null default timezone('utc', now()),
  confidence_at_time double precision,
  power_mode_at_time text
);

create index if not exists onyx_alert_outcomes_site_occurred_idx
  on public.onyx_alert_outcomes (site_id, occurred_at desc);

create index if not exists onyx_alert_outcomes_zone_occurred_idx
  on public.onyx_alert_outcomes (site_id, zone_id, occurred_at desc);
