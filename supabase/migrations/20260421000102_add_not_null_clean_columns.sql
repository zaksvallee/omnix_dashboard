-- Layer 1 Step 4a — NOT NULL (clean columns only).
--
-- What: SET NOT NULL on 14 business-critical columns where current live data
--       has zero NULL rows. Each was validated via `SELECT count(*) FILTER
--       (WHERE <col> IS NULL) FROM <t>` returning 0 (see audit §1 probes
--       P5.1–P5.14).
--
-- Phase 4 finding: §7 enumerated columns where code assumes non-null but
--       schema allows null. This migration covers the subset where live data
--       is already clean.
--
-- 4a rationale: every column below has 0 NULL rows today. ALTER COLUMN SET
--       NOT NULL will apply without rejection.
--
-- Not here (moved to 4b): incidents.site_id (238/241 null),
--       onyx_evidence_certificates.{incident_id,face_match_id} (282/282 null),
--       guards.{full_name,client_id,primary_site_id} (5/12 null — placeholder
--       rows), client_evidence_ledger.previous_hash (2/16388 null — genesis
--       rows). See Step 4b #02.

BEGIN;

-- incidents.client_id — 241/241 non-null (Phase A probe P5.2 = 0/241)
ALTER TABLE public.incidents ALTER COLUMN client_id SET NOT NULL;

-- client_evidence_ledger.client_id + dispatch_id — 16,388/16,388 non-null (P5.7)
ALTER TABLE public.client_evidence_ledger ALTER COLUMN client_id SET NOT NULL;
ALTER TABLE public.client_evidence_ledger ALTER COLUMN dispatch_id SET NOT NULL;

-- site_alarm_events.site_id — 11,227/11,227 non-null (P5.8 showed site_id nulls=0)
ALTER TABLE public.site_alarm_events ALTER COLUMN site_id SET NOT NULL;

-- fr_person_registry.site_id — 5/5 non-null (P5.9)
ALTER TABLE public.fr_person_registry ALTER COLUMN site_id SET NOT NULL;

-- site_camera_zones.site_id — 16/16 non-null (P5.10)
ALTER TABLE public.site_camera_zones ALTER COLUMN site_id SET NOT NULL;

-- site_occupancy_sessions.site_id — 11/11 non-null (P5.11)
ALTER TABLE public.site_occupancy_sessions ALTER COLUMN site_id SET NOT NULL;

-- telegram_inbound_updates.{update_id, chat_id} — 100/100 non-null (P5.12)
ALTER TABLE public.telegram_inbound_updates ALTER COLUMN update_id SET NOT NULL;
ALTER TABLE public.telegram_inbound_updates ALTER COLUMN chat_id SET NOT NULL;

-- dispatch_transitions key columns — 34/34 non-null (P5.13)
ALTER TABLE public.dispatch_transitions ALTER COLUMN dispatch_id SET NOT NULL;
ALTER TABLE public.dispatch_transitions ALTER COLUMN to_state SET NOT NULL;
ALTER TABLE public.dispatch_transitions ALTER COLUMN actor_type SET NOT NULL;

-- dispatch_intents key columns — 27/27 non-null (P5.14)
ALTER TABLE public.dispatch_intents ALTER COLUMN risk_level SET NOT NULL;
ALTER TABLE public.dispatch_intents ALTER COLUMN action_type SET NOT NULL;

COMMIT;
