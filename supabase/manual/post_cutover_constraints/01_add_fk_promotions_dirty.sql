-- Layer 1 Step 4b — FK promotions (staged — current data has orphans).
--
-- What: promote 9 soft-FK columns to hard FK CONSTRAINTs. Each has known
--       live-data orphan rows today and would be rejected by PostgreSQL if
--       applied now.
--
-- Phase 4 finding: §6 flagged 172 soft-FK columns; §1.4 enumerated orphans
--       per child table.
--
-- Why staged: every FK below has SQL-probe evidence of orphan rows:
--       (all probes: Layer 1 Step 4 audit doc §1; raw output in the
--       `/tmp/layer1_step4/phase_a_probes_evidence.txt` artefact at audit time)
--
--   - client_evidence_ledger.client_id → clients: 10 orphans (probe P3.1)
--   - client_evidence_ledger.dispatch_id → dispatch_intents: 16,388 orphans (100%) (P3.2)
--     DEFERRED OUT OF LAYER 2: the child column is text while the parent
--     dispatch_intents.dispatch_id column is uuid, so PostgreSQL cannot
--     implement this FK even after the wipe removes row-level orphans.
--     This needs schema redesign rather than cutover-time coercion.
--   - client_conversation_messages.client_id → clients: 20 orphans (100%) (P3.3)
--   - client_conversation_acknowledgements.client_id → clients: 22 orphans (100%) (P3.4)
--   - client_conversation_push_queue.client_id → clients: 10 orphans (P3.5)
--   - client_conversation_push_sync_state.client_id → clients: 1 orphan (P3.6)
--   - guard_ops_events.guard_id → guards: 3 orphans (100%) (P3.7)
--   - incidents.site_id → sites: 0 orphans BUT paired with NOT NULL which
--     has 238 nulls — kept with its NOT NULL as 4b (user adjustment 1)
--   - onyx_evidence_certificates.incident_id → incidents: 0 orphans BUT all
--     282 rows NULL — FK alone is operationally meaningless until backfill;
--     kept with its NOT NULL as 4b (user adjustment 2)
--   - incident_aar_scores.incident_id → incidents: 4 orphans (P3.25)
--
-- Cutover step: Layer 2 runbook step 7 / phase 5 §3.4 step 7 applies this
-- file AFTER the wipe, preservation verification, and 04 UNIQUE constraints:
--   (a) resolved orphan `CLIENT-001` references (migrate to real client_id or delete),
--   (b) deferred client_evidence_ledger.dispatch_id FK promotion because the
--       child/parent column types are incompatible (text → uuid),
--   (c) cleaned test-harness pollution in guard_ops_events (literal
--       `guard_actor_contract` guard_id),
--   (d) backfilled incidents.site_id from signal_received_at + alarm-event
--       context,
--   (e) backfilled onyx_evidence_certificates.incident_id from cert.event_id
--       → incidents.event_uid lookup,
--   (f) deleted or reassigned the 4 orphan incident_aar_scores rows.
--
-- Cutover command:
--   psql -h aws-1-ap-northeast-1.pooler.supabase.com -p 5432 -U postgres \
--        -d postgres -f 01_add_fk_promotions_dirty.sql

BEGIN;

-- client_evidence_ledger: 10 orphan client_id. The dispatch_id FK is deferred:
-- child column public.client_evidence_ledger.dispatch_id is text; parent column
-- public.dispatch_intents.dispatch_id is uuid.
ALTER TABLE public.client_evidence_ledger
  ADD CONSTRAINT client_evidence_ledger_client_id_fkey
  FOREIGN KEY (client_id) REFERENCES public.clients (client_id) ON DELETE RESTRICT;

-- client_conversation_*: 20+22+10+1 orphan client_id
ALTER TABLE public.client_conversation_messages
  ADD CONSTRAINT client_conversation_messages_client_id_fkey
  FOREIGN KEY (client_id) REFERENCES public.clients (client_id) ON DELETE CASCADE;
ALTER TABLE public.client_conversation_acknowledgements
  ADD CONSTRAINT client_conversation_acknowledgements_client_id_fkey
  FOREIGN KEY (client_id) REFERENCES public.clients (client_id) ON DELETE CASCADE;
ALTER TABLE public.client_conversation_push_queue
  ADD CONSTRAINT client_conversation_push_queue_client_id_fkey
  FOREIGN KEY (client_id) REFERENCES public.clients (client_id) ON DELETE CASCADE;
ALTER TABLE public.client_conversation_push_sync_state
  ADD CONSTRAINT client_conversation_push_sync_state_client_id_fkey
  FOREIGN KEY (client_id) REFERENCES public.clients (client_id) ON DELETE CASCADE;

-- guard_ops_events: 3 orphan guard_id (all `guard_actor_contract` test pollution).
-- Note: guards(guard_id) needs a single-column UNIQUE constraint before this
-- FK can apply. 04_add_unique_constraints_dirty.sql creates
-- `guards_guard_id_unique` and must run before this file.
ALTER TABLE public.guard_ops_events
  ADD CONSTRAINT guard_ops_events_guard_id_fkey
  FOREIGN KEY (guard_id) REFERENCES public.guards (guard_id) ON DELETE RESTRICT;

-- incidents.site_id: 0 orphans, 238 nulls. Paired with NOT NULL (Step 4b #02).
-- User adjustment 1: kept in 4b to ensure FK + NOT NULL apply together — FK
-- alone on a 98.8%-NULL column is operationally meaningless.
ALTER TABLE public.incidents
  ADD CONSTRAINT incidents_site_id_fkey
  FOREIGN KEY (site_id) REFERENCES public.sites (site_id) ON DELETE RESTRICT;

-- onyx_evidence_certificates.incident_id: 0 orphans, 282 nulls. Paired with
-- NOT NULL (Step 4b #02). User adjustment 2: same reasoning as incidents.
ALTER TABLE public.onyx_evidence_certificates
  ADD CONSTRAINT onyx_evidence_certificates_incident_id_fkey
  FOREIGN KEY (incident_id) REFERENCES public.incidents (id) ON DELETE RESTRICT;

-- incident_aar_scores.incident_id: 4 orphans (probe P3.25)
ALTER TABLE public.incident_aar_scores
  ADD CONSTRAINT incident_aar_scores_incident_id_fkey
  FOREIGN KEY (incident_id) REFERENCES public.incidents (id) ON DELETE CASCADE;

COMMIT;
