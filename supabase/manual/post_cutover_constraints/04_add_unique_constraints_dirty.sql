-- Layer 1 Step 4b — UNIQUE (staged — current data has duplicate groups).
--
-- What: add 3 UNIQUE constraints on columns that currently have duplicate
--       groups. Each would be rejected by PostgreSQL if applied now.
--
-- Phase 4 finding: §8 enumerated duplicate-detection results. This file
--       covers the 3 columns with actual duplicate groups.
--
-- Why staged: duplicate-group probes (P6.*):
--   - clients(name): 1 dupe group — `test` × 3 rows      (P6.1)
--   - guards(full_name): 3 dupe groups + 5 NULL — Lerato Moletsane × 2,
--     Thabo Mokoena × 2, Sipho Ndlovu × 2                 (P6.3)
--   - onyx_evidence_certificates(event_id): 5 dupe groups — EVT-...5-VMD × 3,
--     4 other pairs                                        (P6.5)
--
-- Cutover step: Layer 2.3 step 5 applies this file AFTER Layer 2 cleanup has:
--   (a) removed or merged the 3 `test` client rows (either delete, or rename
--       with unique suffix like `test-legacy-2026-04`),
--   (b) merged the 3 duplicate-name guard pairs (old `GRD-NNN` inactive + new
--       `GRD-<UUID>` active — likely keep the active one, archive the
--       inactive; also removes the 5 placeholder rows which interact with
--       #02 cleanup),
--   (c) de-duplicated the 5 onyx_evidence_certificates event_id groups (keep
--       one cert per event, archive or delete the duplicates — chain_position
--       sequence must remain 1..N after dedup).
--
-- Cutover command:
--   psql -h aws-1-ap-northeast-1.pooler.supabase.com -p 5432 -U postgres \
--        -d postgres -f 04_add_unique_constraints_dirty.sql

BEGIN;

-- clients(name): 1 dupe group `test` × 3
ALTER TABLE public.clients
  ADD CONSTRAINT clients_name_unique UNIQUE (name);

-- guards(full_name): 3 dupe groups of 2 each + 5 NULLs (NULLs don't violate
-- UNIQUE under standard semantics; dupe rows must be resolved).
ALTER TABLE public.guards
  ADD CONSTRAINT guards_full_name_unique UNIQUE (full_name);

-- onyx_evidence_certificates(event_id): 5 dupe groups
ALTER TABLE public.onyx_evidence_certificates
  ADD CONSTRAINT onyx_evidence_certificates_event_id_unique UNIQUE (event_id);

COMMIT;
