do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'clients'
      and column_name = 'zara_tier'
  ) and not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'clients'
      and column_name = 'zara_allowance_tier'
  ) then
    alter table public.clients
      rename column zara_tier to zara_allowance_tier;
  elsif not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'clients'
      and column_name = 'zara_allowance_tier'
  ) then
    alter table public.clients
      add column zara_allowance_tier text;
  end if;
end
$$;

update public.clients
set zara_allowance_tier = case
  when lower(trim(coalesce(zara_allowance_tier, ''))) in ('standard', 'premium', 'tactical')
    then lower(trim(zara_allowance_tier))
  when lower(trim(coalesce(metadata->>'zara_allowance_tier', ''))) in ('standard', 'premium', 'tactical')
    then lower(trim(metadata->>'zara_allowance_tier'))
  when lower(trim(coalesce(metadata->>'zara_tier', ''))) in ('standard', 'premium', 'tactical')
    then lower(trim(metadata->>'zara_tier'))
  else 'standard'
end;

alter table public.clients
  alter column zara_allowance_tier set default 'standard';

alter table public.clients
  alter column zara_allowance_tier set not null;

alter table public.clients
  drop constraint if exists clients_zara_tier_check;

alter table public.clients
  drop constraint if exists clients_zara_allowance_tier_check;

alter table public.clients
  add constraint clients_zara_allowance_tier_check
  check (zara_allowance_tier in ('standard', 'premium', 'tactical'));

comment on column public.clients.zara_allowance_tier is
  'Zara commercial allowance tier for this client. Used for volume, overage, and priority handling rather than capability access.';

alter table public.zara_capabilities
  drop constraint if exists zara_capabilities_upsell_cta_check;

drop index if exists zara_capabilities_tier_idx;

create index if not exists zara_capabilities_category_idx
  on public.zara_capabilities (category);

alter table public.zara_capabilities
  drop column if exists min_tier;

update public.zara_capabilities
set
  display_name = case capability_key
    when 'monitoring_status_brief' then 'Monitoring Status Brief'
    when 'incident_summary_reply' then 'Incident Summary Reply'
    when 'report_narrative_draft' then 'Report Narrative Draft'
    when 'dispatch_triage' then 'Dispatch Triage'
    when 'incident_notes' then 'Incident Notes Timeline'
    when 'guard_shift_roster_brief' then 'Guard Shift Roster Brief'
    when 'footfall_count' then 'Footfall Count'
    when 'face_registry_lookup' then 'Face Registry Lookup'
    when 'vehicle_pattern_analysis' then 'Vehicle Pattern Analysis'
    when 'theatre_action_orchestration' then 'Theatre Action Orchestration'
    else display_name
  end,
  upsell_blurb = case capability_key
    when 'monitoring_status_brief' then 'Monitoring status briefs are already available on ONYX live-monitoring sites.'
    when 'incident_summary_reply' then 'Incident summary replies are already available when the incident context is in lane.'
    when 'report_narrative_draft' then 'Report narrative drafts need the report bundle activated for this site. I can flag that through your account manager if helpful.'
    when 'dispatch_triage' then 'Dispatch triage needs dispatch event history activated for this site. I can flag that through your account manager if helpful.'
    when 'incident_notes' then 'Incident-note timelines need incident notes activated for this site. I can flag that through your account manager if helpful.'
    when 'guard_shift_roster_brief' then 'Guard shift roster briefs need shift coverage activated for this site. I can flag that through your account manager if helpful.'
    when 'footfall_count' then 'Footfall queries need the CV pipeline footfall feed activated for this site. I can flag that through your account manager if helpful.'
    when 'face_registry_lookup' then 'Face-registry lookups need face-registry matching activated for this site. I can flag that through your account manager if helpful.'
    when 'vehicle_pattern_analysis' then 'Vehicle pattern analysis needs vehicle analytics activated for this site. I can flag that through your account manager if helpful.'
    when 'theatre_action_orchestration' then 'Theatre action orchestration needs Zara scenarios activated for this site. I can flag that through your account manager if helpful.'
    else upsell_blurb
  end,
  upsell_cta = case
    when capability_key in ('monitoring_status_brief', 'incident_summary_reply')
      then 'feature_sheet'
    else 'account_manager'
  end,
  updated_at = timezone('utc', now());

alter table public.zara_capabilities
  add constraint zara_capabilities_upsell_cta_check
  check (upsell_cta in ('feature_sheet', 'account_manager'));

comment on table public.zara_capabilities is
  'Canonical Zara capability registry for infrastructure gating, refusal language, and allowance-aware product metadata.';
