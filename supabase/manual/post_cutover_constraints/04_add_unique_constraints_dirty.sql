-- Layer 1 Step 4b — UNIQUE (staged — current data has duplicate groups).
--
-- What: add 3 UNIQUE constraints. Two currently have duplicate groups; one
--       (`guards(guard_id)`) is the parent-key prerequisite for the
--       guard_ops_events.guard_id FK promoted in 01.
--
-- Phase 4 finding: §8 enumerated duplicate-detection results. This file
--       covers the wipe-set duplicate groups plus the guards(guard_id) FK
--       prerequisite identified during Step 4 review. clients(name) is
--       deferred to Layer 4 because public.clients is a preservation table.
--
-- Why staged: duplicate-group probes (P6.*):
--   - guards(full_name): 3 dupe groups + 5 NULL — Lerato Moletsane × 2,
--     Thabo Mokoena × 2, Sipho Ndlovu × 2                 (P6.3)
--   - onyx_evidence_certificates(event_id): 5 dupe groups — EVT-...5-VMD × 3,
--     4 other pairs                                        (P6.5)
--   - guards(guard_id): no dirty duplicate probe; included because PostgreSQL
--     requires a referenced FK target to be UNIQUE or PRIMARY KEY.
--
-- Cutover step: Layer 2 runbook step 7 / phase 5 §3.4 step 7 applies this
-- file AFTER the wipe and preservation verification have completed:
--   (a) merged the 3 duplicate-name guard pairs (old `GRD-NNN` inactive + new
--       `GRD-<UUID>` active — likely keep the active one, archive the
--       inactive; also removes the 5 placeholder rows which interact with
--       #02 cleanup),
--   (b) de-duplicated the 5 onyx_evidence_certificates event_id groups (keep
--       one cert per event, archive or delete the duplicates — chain_position
--       sequence must remain 1..N after dedup).
--
-- Cutover command:
--   psql -h aws-1-ap-northeast-1.pooler.supabase.com -p 5432 -U postgres \
--        -d postgres -f 04_add_unique_constraints_dirty.sql

BEGIN;

-- guards(full_name): 3 dupe groups of 2 each + 5 NULLs (NULLs don't violate
-- UNIQUE under standard semantics; dupe rows must be resolved).
ALTER TABLE public.guards
  ADD CONSTRAINT guards_full_name_unique UNIQUE (full_name);

-- guards(guard_id): prerequisite for 01_add_fk_promotions_dirty.sql.
ALTER TABLE public.guards
  ADD CONSTRAINT guards_guard_id_unique UNIQUE (guard_id);

-- onyx_evidence_certificates(event_id): 5 dupe groups
ALTER TABLE public.onyx_evidence_certificates
  ADD CONSTRAINT onyx_evidence_certificates_event_id_unique UNIQUE (event_id);

COMMIT;
