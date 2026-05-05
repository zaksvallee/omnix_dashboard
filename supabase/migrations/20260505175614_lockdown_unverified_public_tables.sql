-- =====================================================================
-- Lockdown for 55 public tables that had RLS disabled with full CRUD
-- granted to anon and authenticated.
--
-- Background:
--   Recon on 2026-05-05 found 55 public tables with RLS disabled AND
--   wide-open grants (DELETE, INSERT, REFERENCES, SELECT, TRIGGER,
--   TRUNCATE, UPDATE) to both anon and authenticated. Anyone with
--   the project anon key (which ships in the client bundle by design)
--   could read, modify, or truncate these tables via PostgREST.
--
--   Earlier today, exploratory SQL Editor sessions partially closed
--   3 of the 55: alarm_accounts and site_awareness_snapshots got
--   RLS enabled + a SELECT policy + grants revoked; alert_events
--   got RLS enabled + grants revoked.
--
--   This migration is fully idempotent — safe to run against the
--   partial state. It re-applies all changes uniformly so the schema
--   state matches the migration content exactly.
--
-- Strategy:
--   - 51 tables: hard lockdown — RLS on (idempotent), revoke all
--     from anon + authenticated (idempotent), no policies. service_role
--     retains access via Supabase default; bin/ workers, Edge
--     Functions, and v2 dashboard server-side use that path.
--   - 4 tables: same lockdown PLUS a tenant-scoped SELECT policy,
--     because Flutter lib/ reads them via the anon key on a
--     logged-in session (role = authenticated).
--   - DROP POLICY IF EXISTS for the 2 stopgap policies before
--     CREATE POLICY, so we cleanly redefine them.
--
-- Convention compliance (per memory #11, #6):
--   - No explicit BEGIN/COMMIT (CLI wraps each migration).
--   - Service role grants not touched (Supabase default).
-- =====================================================================


-- ---------------------------------------------------------------------
-- Block 0: Drop policies we plan to (re)create — idempotent prep
-- Also drops the dormant orphan policies on dispatch_actions
-- (4 inert pre-existing policies) and the duplicate
-- "anon_can_read_site_awareness" left over from earlier exploration.
-- ---------------------------------------------------------------------
DROP POLICY IF EXISTS "Allow anon read dispatch" ON public.dispatch_actions;
DROP POLICY IF EXISTS "Allow authenticated read dispatch" ON public.dispatch_actions;
DROP POLICY IF EXISTS "Allow realtime read" ON public.dispatch_actions;
DROP POLICY IF EXISTS "Allow select for authenticated" ON public.dispatch_actions;
DROP POLICY IF EXISTS anon_can_read_site_awareness ON public.site_awareness_snapshots;
DROP POLICY IF EXISTS site_awareness_snapshots_select_policy ON public.site_awareness_snapshots;
DROP POLICY IF EXISTS alarm_accounts_select_policy ON public.alarm_accounts;
DROP POLICY IF EXISTS site_occupancy_config_select_policy ON public.site_occupancy_config;
DROP POLICY IF EXISTS site_occupancy_sessions_select_policy ON public.site_occupancy_sessions;


-- ---------------------------------------------------------------------
-- Block 1: Hard lockdown — 51 tables
-- (RLS on, revoke all from anon + authenticated, no policies.)
-- ---------------------------------------------------------------------

ALTER TABLE public.alert_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.alert_events FROM anon, authenticated;

ALTER TABLE public.alert_rules ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.alert_rules FROM anon, authenticated;

ALTER TABLE public.area_sites ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.area_sites FROM anon, authenticated;

ALTER TABLE public.checkins ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.checkins FROM anon, authenticated;

ALTER TABLE public.civic_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.civic_events FROM anon, authenticated;

ALTER TABLE public.command_summaries ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.command_summaries FROM anon, authenticated;

ALTER TABLE public.decision_traces ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.decision_traces FROM anon, authenticated;

ALTER TABLE public.demo_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.demo_state FROM anon, authenticated;

ALTER TABLE public.deployments ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.deployments FROM anon, authenticated;

ALTER TABLE public.dispatch_actions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.dispatch_actions FROM anon, authenticated;

ALTER TABLE public.duty_states ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.duty_states FROM anon, authenticated;

ALTER TABLE public.escalation_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.escalation_events FROM anon, authenticated;

ALTER TABLE public.evidence_bundles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.evidence_bundles FROM anon, authenticated;

ALTER TABLE public.execution_locks ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.execution_locks FROM anon, authenticated;

ALTER TABLE public.external_signals ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.external_signals FROM anon, authenticated;

ALTER TABLE public.global_patterns ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.global_patterns FROM anon, authenticated;

ALTER TABLE public.guard_logs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.guard_logs FROM anon, authenticated;

ALTER TABLE public.guard_ops_replay_safety_checks ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.guard_ops_replay_safety_checks FROM anon, authenticated;

ALTER TABLE public.guard_ops_retention_runs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.guard_ops_retention_runs FROM anon, authenticated;

ALTER TABLE public.guard_projection_retention_runs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.guard_projection_retention_runs FROM anon, authenticated;

ALTER TABLE public.guard_sites ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.guard_sites FROM anon, authenticated;

ALTER TABLE public.incident_aar_scores ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.incident_aar_scores FROM anon, authenticated;

ALTER TABLE public.incident_outcomes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.incident_outcomes FROM anon, authenticated;

ALTER TABLE public.incident_replay_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.incident_replay_events FROM anon, authenticated;

ALTER TABLE public.incident_replays ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.incident_replays FROM anon, authenticated;

ALTER TABLE public.incident_snapshots ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.incident_snapshots FROM anon, authenticated;

ALTER TABLE public.intel_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.intel_events FROM anon, authenticated;

ALTER TABLE public.intel_patrol_links ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.intel_patrol_links FROM anon, authenticated;

ALTER TABLE public.intel_source_weights ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.intel_source_weights FROM anon, authenticated;

ALTER TABLE public.intelligence_snapshots ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.intelligence_snapshots FROM anon, authenticated;

ALTER TABLE public.keyword_escalations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.keyword_escalations FROM anon, authenticated;

ALTER TABLE public.logs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.logs FROM anon, authenticated;

ALTER TABLE public.mo_library ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.mo_library FROM anon, authenticated;

ALTER TABLE public.omnix_logs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.omnix_logs FROM anon, authenticated;

ALTER TABLE public.operational_nodes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.operational_nodes FROM anon, authenticated;

ALTER TABLE public.ops_orders ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.ops_orders FROM anon, authenticated;

ALTER TABLE public.patrol_route_cooldowns ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.patrol_route_cooldowns FROM anon, authenticated;

ALTER TABLE public.patrol_route_recommendations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.patrol_route_recommendations FROM anon, authenticated;

ALTER TABLE public.patrol_violations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.patrol_violations FROM anon, authenticated;

ALTER TABLE public.patrols ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.patrols FROM anon, authenticated;

ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.posts FROM anon, authenticated;

ALTER TABLE public.regional_risk_snapshots ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.regional_risk_snapshots FROM anon, authenticated;

ALTER TABLE public.site_api_tokens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.site_api_tokens FROM anon, authenticated;

ALTER TABLE public.site_zones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.site_zones FROM anon, authenticated;

ALTER TABLE public.threat_decay_profiles ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.threat_decay_profiles FROM anon, authenticated;

ALTER TABLE public.threat_scores ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.threat_scores FROM anon, authenticated;

ALTER TABLE public.vehicle_logs ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.vehicle_logs FROM anon, authenticated;

ALTER TABLE public.violations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.violations FROM anon, authenticated;

ALTER TABLE public.watch_archive ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.watch_archive FROM anon, authenticated;

ALTER TABLE public.watch_current_state ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.watch_current_state FROM anon, authenticated;

ALTER TABLE public.watch_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.watch_events FROM anon, authenticated;


-- ---------------------------------------------------------------------
-- Block 2: Stopgap RLS policies — 4 tables Flutter lib/ reads via anon
--
-- Pattern: revoke all, grant SELECT to authenticated, add tenant-scoped
-- SELECT policy. Logged-in Flutter sessions read as authenticated;
-- logged-out reads as anon, which has no grant and no policy — blocked.
-- ---------------------------------------------------------------------

-- alarm_accounts (has client_id and site_id)
ALTER TABLE public.alarm_accounts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.alarm_accounts FROM anon, authenticated;
GRANT SELECT ON public.alarm_accounts TO authenticated;
CREATE POLICY alarm_accounts_select_policy
  ON public.alarm_accounts
  FOR SELECT
  TO authenticated
  USING (
    client_id = onyx_client_id()
    AND onyx_has_site(site_id)
  );

-- site_awareness_snapshots (has client_id and site_id)
ALTER TABLE public.site_awareness_snapshots ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.site_awareness_snapshots FROM anon, authenticated;
GRANT SELECT ON public.site_awareness_snapshots TO authenticated;
CREATE POLICY site_awareness_snapshots_select_policy
  ON public.site_awareness_snapshots
  FOR SELECT
  TO authenticated
  USING (
    client_id = onyx_client_id()
    AND onyx_has_site(site_id)
  );

-- site_occupancy_config (site_id only)
ALTER TABLE public.site_occupancy_config ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.site_occupancy_config FROM anon, authenticated;
GRANT SELECT ON public.site_occupancy_config TO authenticated;
CREATE POLICY site_occupancy_config_select_policy
  ON public.site_occupancy_config
  FOR SELECT
  TO authenticated
  USING (onyx_has_site(site_id));

-- site_occupancy_sessions (site_id only)
ALTER TABLE public.site_occupancy_sessions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.site_occupancy_sessions FROM anon, authenticated;
GRANT SELECT ON public.site_occupancy_sessions TO authenticated;
CREATE POLICY site_occupancy_sessions_select_policy
  ON public.site_occupancy_sessions
  FOR SELECT
  TO authenticated
  USING (onyx_has_site(site_id));
