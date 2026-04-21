create table if not exists public.onyx_client_trust_snapshots (
  client_id text not null,
  site_id text not null,
  period_start timestamptz not null,
  period_end timestamptz not null,
  period_label text not null,
  incidents_handled integer not null default 0,
  avg_response_seconds double precision not null default 0,
  false_alarm_rate double precision not null default 0,
  false_alarms_reduced double precision not null default 0,
  guard_patrol_compliance double precision not null default 0,
  checkpoints_completed integer not null default 0,
  system_uptime double precision not null default 0,
  cameras_online integer not null default 0,
  cameras_total integer not null default 0,
  alerts_delivered integer not null default 0,
  avg_awareness_seconds double precision not null default 0,
  evidence_certificates_issued integer not null default 0,
  top_incident_zones jsonb not null default '[]'::jsonb,
  safer_score integer not null default 0,
  safer_score_trend text not null default 'stable',
  snapshot_at timestamptz not null default timezone('utc', now()),
  primary key (client_id, site_id, period_start, period_end)
);

create index if not exists onyx_client_trust_snapshots_client_site_snapshot_idx
  on public.onyx_client_trust_snapshots (client_id, site_id, snapshot_at desc);
