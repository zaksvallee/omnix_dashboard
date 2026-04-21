-- Layer 1 Step 4b — NOT NULL (staged — current data has NULL rows).
--
-- What: SET NOT NULL on 8 business-critical columns that currently have NULL
--       rows in live. Each would be rejected by PostgreSQL if applied now.
--
-- Phase 4 finding: §7 flagged columns where code assumes non-null but schema
--       allows null and live data contains nulls.
--
-- Why staged: specific null counts (probes P5.*):
--   - incidents.site_id: 238 / 241 NULL (98.8%)                     (P5.1)
--   - onyx_evidence_certificates.incident_id: 282 / 282 NULL (100%) (P5.3)
--   - guards.full_name: 5 / 12 NULL/blank (placeholder rows)        (P5.5)
--   - guards.client_id: 5 / 12 NULL                                 (P5.5)
--   - guards.primary_site_id: 5 / 12 NULL                           (P5.5)
--   - client_evidence_ledger.previous_hash: 2 / 16,388 NULL
--     (genesis-row artefact)                                        (P5.6)
--
-- Explicitly NOT included: onyx_evidence_certificates.face_match_id
--   face_match_id remains NULLABLE by design. Evidence certificates may be
--   linked to FR matches, LPR matches, or manual events; FR link is one of
--   several provenance paths and should not be required. Phase A classified
--   this column 4b; post-review decision (2026-04-21): do not add NOT NULL.
--   See audit note §3.
--
-- Cutover step: Layer 2.3 step 5 applies this file AFTER Layer 2 cleanup has:
--   (a) backfilled incidents.site_id (same mechanism as FK #01 cleanup (d)),
--   (b) backfilled onyx_evidence_certificates.incident_id from
--       cert.event_id → incidents.event_uid lookup (also FK #01 (e)),
--   (c) deleted the 5 placeholder `guards` rows (also pre-req for #04 dupes),
--   (d) either (1) seeded genesis `previous_hash` rows with a sentinel value
--       like `'GENESIS-<uuid>'`, or (2) explicitly decided previous_hash
--       stays nullable (in which case drop it from this file before cutover).
--
-- Cutover command:
--   psql -h aws-1-ap-northeast-1.pooler.supabase.com -p 5432 -U postgres \
--        -d postgres -f 02_add_not_null_dirty_columns.sql

BEGIN;

-- incidents.site_id: 238/241 null — pre-req: backfill site_id from context
ALTER TABLE public.incidents ALTER COLUMN site_id SET NOT NULL;

-- onyx_evidence_certificates.incident_id: 282/282 null — pre-req: backfill
ALTER TABLE public.onyx_evidence_certificates ALTER COLUMN incident_id SET NOT NULL;

-- face_match_id remains NULLABLE by design.
-- Evidence certificates may be linked to FR matches, LPR matches, or manual
-- events; FR link is one of several provenance paths and should not be
-- required. (Phase A classified this column 4b; post-review decision: do
-- not add NOT NULL.)

-- guards: 5 placeholder rows have NULL name/client/site — pre-req: delete them.
ALTER TABLE public.guards ALTER COLUMN full_name SET NOT NULL;
ALTER TABLE public.guards ALTER COLUMN client_id SET NOT NULL;
ALTER TABLE public.guards ALTER COLUMN primary_site_id SET NOT NULL;

-- client_evidence_ledger.previous_hash: 2 genesis rows NULL — pre-req: seed
-- genesis sentinel OR skip this line at cutover.
ALTER TABLE public.client_evidence_ledger ALTER COLUMN previous_hash SET NOT NULL;

COMMIT;
