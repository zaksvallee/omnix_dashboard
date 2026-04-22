-- Layer 1 Step 4a — UNIQUE constraints (no duplicates today).
--
-- What: add 3 UNIQUE constraints where live data currently has no duplicate
--       groups. Each was validated via `SELECT <col>, count(*) FROM <t>
--       GROUP BY <col> HAVING count(*) > 1` returning empty (see audit §1
--       probes P6.*).
--
-- Phase 4 finding: §8 enumerated duplicate-detection results. This migration
--       covers the subset where uniqueness is expected AND no duplicates exist.
--
-- 4a rationale: no duplicate groups means UNIQUE constraint will apply
--       without rejection.
--
-- Not here (moved to 4b): clients(name) — 3 rows named `test`; guards(full_name)
--       — 3 real persons each appearing twice; onyx_evidence_certificates
--       (event_id) — 5 dupe groups. See Step 4b #04.

BEGIN;

-- sites(name) — 0 dupe groups (P6.2); 8 rows all distinct
ALTER TABLE public.sites
  ADD CONSTRAINT sites_name_unique UNIQUE (name);

-- incidents(event_uid) — 0 dupe groups among non-null (P6.6); allows multiple NULLs
-- NULLs are distinct under UNIQUE per SQL standard; incidents with NULL event_uid
-- are not prevented by this constraint.
ALTER TABLE public.incidents
  ADD CONSTRAINT incidents_event_uid_unique UNIQUE (event_uid);

-- client_evidence_ledger(hash) — 0 dupe groups (P6.7); hash-chain integrity
ALTER TABLE public.client_evidence_ledger
  ADD CONSTRAINT client_evidence_ledger_hash_unique UNIQUE (hash);

COMMIT;
