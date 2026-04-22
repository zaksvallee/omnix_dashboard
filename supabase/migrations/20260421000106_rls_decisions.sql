-- Layer 1 Step 4a — RLS decisions on no-RLS tables.
--
-- What: three categories of RLS action on the 66 tables in live that currently
--       have RLS disabled (Step 1 §5.2):
--
--   A) ENABLE + basic policy: 5 client-scoped tables with populated data and a
--      clear client_id column. Policy shape: service-role full access;
--      authenticated users scoped by client_id claim.
--
--   B) DISABLED explicitly (internal / operator-managed): 5 tables that are
--      internal retention/locking/PostGIS reference — not application data.
--      RLS remains off with a COMMENT documenting that the state is intentional.
--
--   C) DISABLED with safety comment (sensitive, scope unclear): 19 tables
--      where the data is plainly sensitive (auth tokens, audit trails, intel,
--      identity, platform settings, logs) but multi-tenant scoping needs
--      Layer 6 design. RLS stays off but access is limited to service-role
--      via PostgREST config — authenticated roles get no policy grant. Layer 6
--      will design real client-scoped policies.
--
-- Phase 4 finding: §10 flagged ~15+ tables lacking RLS; Step 1 §5.2 enumerated
--       the full 66-table set. This migration acts on the decidable subset;
--       the remaining ~38 are listed in the audit doc §7 as Layer 6 deferrals.
--
-- 4a rationale: every ENABLE below is on a table whose current schema already
--       carries a client_id column suitable for scoping; DISABLED decisions
--       don't change runtime behaviour (RLS is already off) but document intent
--       for Layer 6.
--
-- Not here (moved to 4b): none — RLS decisions are all applicable now.
--
-- Section 7 of audit doc: ~38 tables remain as "ambiguous, defer to Layer 6"
--       — neither clearly-sensitive nor clearly-internal.

BEGIN;

-- =============================================================================
-- A) ENABLE + basic policy — client-scoped, populated, has client_id column
-- =============================================================================

-- client_evidence_ledger (16,388 rows). Note for post-cutover cleanup: the
-- `authenticated read by client_id` policy makes the 10 rows with orphan
-- client_id values (Step 4b #01 FK promotion candidate) unreachable to
-- authenticated users, since `CLIENT-001` does not match any real
-- clients.client_id. This is not wrong — orphans should be unreachable — but
-- documented here so cleanup knows the invisibility is by design until the
-- orphan values are resolved.
ALTER TABLE public.client_evidence_ledger ENABLE ROW LEVEL SECURITY;
CREATE POLICY client_evidence_ledger_service_role_all ON public.client_evidence_ledger
  AS PERMISSIVE FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY client_evidence_ledger_authenticated_read ON public.client_evidence_ledger
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (client_id = COALESCE(NULLIF(auth.jwt() ->> 'client_id', ''), ''));

-- client_conversation_messages (20 rows)
ALTER TABLE public.client_conversation_messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY client_conversation_messages_service_role_all ON public.client_conversation_messages
  AS PERMISSIVE FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY client_conversation_messages_authenticated_read ON public.client_conversation_messages
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (client_id = COALESCE(NULLIF(auth.jwt() ->> 'client_id', ''), ''));

-- client_conversation_acknowledgements (22 rows)
ALTER TABLE public.client_conversation_acknowledgements ENABLE ROW LEVEL SECURITY;
CREATE POLICY client_conversation_acknowledgements_service_role_all ON public.client_conversation_acknowledgements
  AS PERMISSIVE FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY client_conversation_acknowledgements_authenticated_read ON public.client_conversation_acknowledgements
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (client_id = COALESCE(NULLIF(auth.jwt() ->> 'client_id', ''), ''));

-- client_conversation_push_queue (11 rows)
ALTER TABLE public.client_conversation_push_queue ENABLE ROW LEVEL SECURITY;
CREATE POLICY client_conversation_push_queue_service_role_all ON public.client_conversation_push_queue
  AS PERMISSIVE FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY client_conversation_push_queue_authenticated_read ON public.client_conversation_push_queue
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (client_id = COALESCE(NULLIF(auth.jwt() ->> 'client_id', ''), ''));

-- client_conversation_push_sync_state (2 rows)
ALTER TABLE public.client_conversation_push_sync_state ENABLE ROW LEVEL SECURITY;
CREATE POLICY client_conversation_push_sync_state_service_role_all ON public.client_conversation_push_sync_state
  AS PERMISSIVE FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY client_conversation_push_sync_state_authenticated_read ON public.client_conversation_push_sync_state
  AS PERMISSIVE FOR SELECT TO authenticated
  USING (client_id = COALESCE(NULLIF(auth.jwt() ->> 'client_id', ''), ''));

-- =============================================================================
-- B) DISABLED intentionally — internal / PostGIS / retention pipeline
-- =============================================================================

COMMENT ON TABLE public.spatial_ref_sys IS
  'PostGIS reference data. RLS intentionally disabled — not application data.';

COMMENT ON TABLE public.guard_ops_replay_safety_checks IS
  'Guard-ops retention pipeline internal. RLS intentionally disabled — operator-managed, no client scope.';

COMMENT ON TABLE public.guard_ops_retention_runs IS
  'Guard-ops retention pipeline internal. RLS intentionally disabled — operator-managed, no client scope.';

COMMENT ON TABLE public.guard_projection_retention_runs IS
  'Guard-ops projection retention internal. RLS intentionally disabled — operator-managed, no client scope.';

COMMENT ON TABLE public.execution_locks IS
  'Internal mutex for dispatch execution. RLS intentionally disabled — operator-managed, no client scope.';

-- =============================================================================
-- C) DISABLED with safety comment — sensitive, scope unclear, defer design
--     to Layer 6. Until Layer 6 designs real policies, access is service-role
--     only via PostgREST config (no authenticated-role grant).
-- =============================================================================

COMMENT ON TABLE public.site_api_tokens IS
  'RLS disabled pending Layer 6 multi-tenant policy design; service-role-only access enforced via PostgREST config. Sensitive (auth tokens).';

COMMENT ON TABLE public.users IS
  'RLS disabled pending Layer 6 multi-tenant policy design; service-role-only access enforced via PostgREST config. Sensitive (identity).';

COMMENT ON TABLE public.roles IS
  'RLS disabled pending Layer 6 multi-tenant policy design; service-role-only access enforced via PostgREST config. Sensitive (authz).';

COMMENT ON TABLE public.decision_audit_log IS
  'RLS disabled pending Layer 6 multi-tenant policy design; service-role-only access enforced via PostgREST config. Sensitive (audit trail).';

COMMENT ON TABLE public.decision_traces IS
  'RLS disabled pending Layer 6 multi-tenant policy design; service-role-only access enforced via PostgREST config. Sensitive (audit trail).';

COMMENT ON TABLE public.alarm_accounts IS
  'RLS disabled pending Layer 6 multi-tenant policy design; service-role-only access enforced via PostgREST config. Sensitive (alarm-provider account credentials).';

COMMENT ON TABLE public.guard_logs IS
  'RLS disabled pending Layer 6 multi-tenant policy design; service-role-only access enforced via PostgREST config. Sensitive (guard activity logs).';

COMMENT ON TABLE public.vehicle_logs IS
  'RLS disabled pending Layer 6 multi-tenant policy design; service-role-only access enforced via PostgREST config. Sensitive (vehicle tracking logs).';

COMMENT ON TABLE public.evidence_bundles IS
  'RLS disabled pending Layer 6 multi-tenant policy design; service-role-only access enforced via PostgREST config. Sensitive (evidence data grouping).';

COMMENT ON TABLE public.intel_events IS
  'RLS disabled pending Layer 6 multi-tenant policy design; service-role-only access enforced via PostgREST config. Sensitive (intelligence event ingest).';

COMMENT ON TABLE public.intel_patrol_links IS
  'RLS disabled pending Layer 6 multi-tenant policy design; service-role-only access enforced via PostgREST config. Sensitive (intel ↔ patrol linkage).';

COMMENT ON TABLE public.intel_source_weights IS
  'RLS disabled pending Layer 6 multi-tenant policy design; service-role-only access enforced via PostgREST config. Sensitive (intel source weighting).';

COMMENT ON TABLE public.intelligence_snapshots IS
  'RLS disabled pending Layer 6 multi-tenant policy design; service-role-only access enforced via PostgREST config. Sensitive (intel snapshots).';

COMMENT ON TABLE public.threat_scores IS
  'RLS disabled pending Layer 6 multi-tenant policy design; service-role-only access enforced via PostgREST config. Sensitive (threat scoring output).';

COMMENT ON TABLE public.threat_decay_profiles IS
  'RLS disabled pending Layer 6 multi-tenant policy design; service-role-only access enforced via PostgREST config. Sensitive (threat-model configuration).';

COMMENT ON TABLE public.watch_events IS
  'RLS disabled pending Layer 6 multi-tenant policy design; service-role-only access enforced via PostgREST config. Sensitive (watch-event stream).';

COMMENT ON TABLE public.watch_archive IS
  'RLS disabled pending Layer 6 multi-tenant policy design; service-role-only access enforced via PostgREST config. Sensitive (watch archive).';

COMMENT ON TABLE public.watch_current_state IS
  'RLS disabled pending Layer 6 multi-tenant policy design; service-role-only access enforced via PostgREST config. Sensitive (watch current-state snapshot).';

COMMENT ON TABLE public.onyx_settings IS
  'RLS disabled pending Layer 6 multi-tenant policy design; service-role-only access enforced via PostgREST config. Sensitive (platform settings / secrets).';

COMMIT;
