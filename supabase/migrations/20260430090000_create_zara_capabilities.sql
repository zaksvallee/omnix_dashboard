create table if not exists public.zara_capabilities (
  capability_key text primary key,
  min_tier text not null check (min_tier in ('standard', 'premium', 'tactical')),
  display_name text not null,
  category text not null check (category in ('conversational', 'analytics', 'intelligence')),
  upsell_blurb text not null,
  upsell_cta text not null check (upsell_cta in ('feature_sheet', 'sales_call')),
  requires_data_source text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists zara_capabilities_tier_idx
  on public.zara_capabilities (min_tier, category);

create or replace function public.set_zara_capabilities_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists set_zara_capabilities_updated_at
  on public.zara_capabilities;

create trigger set_zara_capabilities_updated_at
before update on public.zara_capabilities
for each row
execute function public.set_zara_capabilities_updated_at();

alter table public.zara_capabilities enable row level security;

drop policy if exists zara_capabilities_service_all
  on public.zara_capabilities;
create policy zara_capabilities_service_all
  on public.zara_capabilities
  to service_role
  using (true)
  with check (true);

drop policy if exists zara_capabilities_public_select
  on public.zara_capabilities;
create policy zara_capabilities_public_select
  on public.zara_capabilities
  for select
  to authenticated, anon
  using (true);

comment on table public.zara_capabilities is
  'Canonical Zara capability registry for tier gating, refusal language, and comparison-page marketing.';

insert into public.zara_capabilities (
  capability_key,
  min_tier,
  display_name,
  category,
  upsell_blurb,
  upsell_cta,
  requires_data_source
)
values
  (
    'monitoring_status_brief',
    'standard',
    'Monitoring Status Brief',
    'conversational',
    'I can keep the monitoring brief in the Standard lane. No upgrade needed here.',
    'feature_sheet',
    null
  ),
  (
    'incident_summary_reply',
    'standard',
    'Incident Summary Reply',
    'conversational',
    'I can draft the incident summary in the Standard lane. No upgrade needed here.',
    'feature_sheet',
    null
  ),
  (
    'report_narrative_draft',
    'standard',
    'Report Narrative Draft',
    'intelligence',
    'I can draft the report narrative in the Standard lane. No upgrade needed here.',
    'feature_sheet',
    'report_bundle'
  ),
  (
    'dispatch_triage',
    'premium',
    'Dispatch Triage',
    'intelligence',
    'I can take dispatch triage further once Premium intelligence is switched on for this site.',
    'sales_call',
    'dispatch_events'
  ),
  (
    'incident_notes',
    'premium',
    'Incident Notes Timeline',
    'conversational',
    'I can work the incident-note timeline properly once Premium intelligence is active for this site.',
    'feature_sheet',
    'incident_notes'
  ),
  (
    'guard_shift_roster_brief',
    'premium',
    'Guard Shift Roster Brief',
    'analytics',
    'I can brief against the live roster once Premium intelligence is enabled for the guard workflow.',
    'feature_sheet',
    'shift_instances'
  ),
  (
    'footfall_count',
    'tactical',
    'Footfall Count',
    'analytics',
    'Footfall analytics sit in Tactical. I can help there once Tactical is enabled for this site.',
    'sales_call',
    'cv_pipeline_footfall'
  ),
  (
    'face_registry_lookup',
    'tactical',
    'Face Registry Lookup',
    'intelligence',
    'Face-registry lookups sit in Tactical. I can handle that once Tactical is enabled for this site.',
    'sales_call',
    'fr_person_registry'
  ),
  (
    'vehicle_pattern_analysis',
    'tactical',
    'Vehicle Pattern Analysis',
    'analytics',
    'Vehicle-pattern analysis sits in Tactical. I can handle that once Tactical is enabled for this site.',
    'sales_call',
    'bi_vehicle_persistence'
  ),
  (
    'theatre_action_orchestration',
    'tactical',
    'Theatre Action Orchestration',
    'intelligence',
    'Multi-step theatre orchestration sits in Tactical. I can take that on once Tactical is enabled for this site.',
    'sales_call',
    'zara_scenarios'
  )
on conflict (capability_key) do update
set
  min_tier = excluded.min_tier,
  display_name = excluded.display_name,
  category = excluded.category,
  upsell_blurb = excluded.upsell_blurb,
  upsell_cta = excluded.upsell_cta,
  requires_data_source = excluded.requires_data_source,
  updated_at = timezone('utc', now());
