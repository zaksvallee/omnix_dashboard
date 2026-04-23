-- Layer 2 Step 7 capture — post-cutover 4b constraints applied manually on live.
--
-- What: absorb the reviewed Layer 2 post-cutover constraints into the normal
--       migration chain after they were applied manually at cutover.
--
-- Why: the cutover runbook applies the staged 4b SQL files directly against
--      live because pre-cutover data would have rejected them. Once the wipe
--      and cleanup have completed, the active migration chain must capture the
--      resulting schema so the drift detector can return green and future
--      scratch/provisioned environments reproduce the post-cutover state.
--
-- Scope captured here:
--   - 3 UNIQUE constraints from 04_add_unique_constraints_dirty.sql
--   - 9 FK promotions from 01_add_fk_promotions_dirty.sql
--   - 6 NOT NULL promotions from 02_add_not_null_dirty_columns.sql
--   - 4 CHECK constraints from 03_add_check_constraints_dirty_enums.sql
--
-- Explicitly NOT captured here:
--   - client_evidence_ledger_dispatch_id_fkey
--     Deferred by audit/phase_5_section_3_amendment_4.md because
--     public.client_evidence_ledger.dispatch_id is text while
--     public.dispatch_intents.dispatch_id is uuid.
--   - clients_name_unique
--     Deferred by audit/phase_5_section_3_amendment_3.md to Layer 4 because
--     public.clients is preserved during Layer 2.
--
-- Operational note:
--   This migration exists for the active chain and scratch reproduction.
--   On the already-cut-over live environment, record this version as applied
--   via `supabase migration repair --status applied 20260423000107` instead of
--   replaying the DDL.

BEGIN;

-- UNIQUE constraints (from staged 04)
ALTER TABLE public.guards
  ADD CONSTRAINT guards_full_name_unique UNIQUE (full_name);

ALTER TABLE public.guards
  ADD CONSTRAINT guards_guard_id_unique UNIQUE (guard_id);

ALTER TABLE public.onyx_evidence_certificates
  ADD CONSTRAINT onyx_evidence_certificates_event_id_unique UNIQUE (event_id);

-- FK promotions (from staged 01, revised per amendment 4)
ALTER TABLE public.client_evidence_ledger
  ADD CONSTRAINT client_evidence_ledger_client_id_fkey
  FOREIGN KEY (client_id) REFERENCES public.clients (client_id) ON DELETE RESTRICT;

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

ALTER TABLE public.guard_ops_events
  ADD CONSTRAINT guard_ops_events_guard_id_fkey
  FOREIGN KEY (guard_id) REFERENCES public.guards (guard_id) ON DELETE RESTRICT;

ALTER TABLE public.incidents
  ADD CONSTRAINT incidents_site_id_fkey
  FOREIGN KEY (site_id) REFERENCES public.sites (site_id) ON DELETE RESTRICT;

ALTER TABLE public.onyx_evidence_certificates
  ADD CONSTRAINT onyx_evidence_certificates_incident_id_fkey
  FOREIGN KEY (incident_id) REFERENCES public.incidents (id) ON DELETE RESTRICT;

ALTER TABLE public.incident_aar_scores
  ADD CONSTRAINT incident_aar_scores_incident_id_fkey
  FOREIGN KEY (incident_id) REFERENCES public.incidents (id) ON DELETE RESTRICT;

-- NOT NULL promotions (from staged 02)
ALTER TABLE public.incidents ALTER COLUMN site_id SET NOT NULL;
ALTER TABLE public.onyx_evidence_certificates ALTER COLUMN incident_id SET NOT NULL;
ALTER TABLE public.guards ALTER COLUMN full_name SET NOT NULL;
ALTER TABLE public.guards ALTER COLUMN client_id SET NOT NULL;
ALTER TABLE public.guards ALTER COLUMN primary_site_id SET NOT NULL;
ALTER TABLE public.client_evidence_ledger ALTER COLUMN previous_hash SET NOT NULL;

-- CHECK constraints (from staged 03)
ALTER TABLE public.incidents
  ADD CONSTRAINT incidents_status_check
  CHECK (status IN ('detected', 'open', 'acknowledged', 'dispatched', 'on_site', 'secured', 'closed', 'false_alarm'));

ALTER TABLE public.incidents
  ADD CONSTRAINT incidents_priority_check
  CHECK (priority IN ('critical', 'high', 'medium', 'low'));

ALTER TABLE public.incidents
  ADD CONSTRAINT incidents_risk_level_check
  CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL'));

ALTER TABLE public.guards
  ADD CONSTRAINT guards_grade_check
  CHECK (grade IS NULL OR grade IN ('Grade A', 'Grade B', 'Grade C'));

COMMIT;
