-- Layer 1 Step 4b — CHECK constraints (staged — current values are inconsistent).
--
-- What: add CHECK (<col> IN (<canonical values>)) on 5 enum-like columns
--       where live data contains case variants, mixed vocabularies, or format
--       inconsistencies. Each would reject live rows today.
--
-- Phase 4 finding: §4 enumerated value inconsistencies across enum-like
--       columns. This file covers the 4 columns with actual violators.
--
-- CANONICAL VOCABULARY (locked 2026-04-21):
--   ONYX convention for every enum-like column:
--     - Stored: lowercase only
--     - Displayed: Title Case at presentation layer
--     - Sorted: via explicit order map — NEVER alphabetical
--   Priority canonical set: critical | high | medium | low
--   Status canonical set:   detected | open | acknowledged | dispatched |
--                           on_site | secured | closed | false_alarm
--   (Status set covers all current live values after lowercasing, plus
--    `acknowledged` and `false_alarm` that exist in the canonical lifecycle
--    but have no rows yet. CHECK accepts the superset so future writes aren't
--    rejected.)
--
-- Legacy-variant cleanup (priority) — Layer 2 must map each before CHECK applies:
--   CRITICAL  → critical
--   HIGH      → high
--   High      → high
--   p1        → critical
--   p2        → high
--   p3        → medium
--   p4        → low
--   <any other value> → REJECT: manual review, do not silently remap
--
-- Legacy-variant cleanup (status) — same pattern:
--   OPEN      → open
--   <any other case variant> → lower() with manual verification
--   <any non-canonical value> → REJECT: manual review, do not silently remap
--
-- Why staged: distinct-value probes (P4.*) evidence:
--   - incidents.status: 7 distinct including `OPEN`/`open` case variants  (P4.1)
--     live counts: secured=139, open=78, OPEN=19, closed=2, detected=1,
--                  on_site=1, dispatched=1
--
--   - incidents.priority: 10 distinct across 4 vocabularies                (P4.2)
--     live counts: critical=73, p3=67, medium=38, CRITICAL=21, high=19,
--                  MEDIUM=12, HIGH=7, LOW=2, p1=1, p2=1
--
--   - incidents.risk_level: 5 values with 27 NULLs                         (P4.3)
--     live counts: CRITICAL=136, MEDIUM=50, NULL=27, HIGH=26, LOW=2
--     risk_level uses the SAME four-value set as priority but in UPPERCASE
--     today. dispatch_intents already has a matching CHECK on uppercase
--     risk_level — the convention for this particular column stays uppercase
--     to preserve compatibility with the already-enforced CHECK. (Cross-table
--     consistency: Layer 6 may revisit risk_level's case.)
--
--   - guards.grade: `C` + `Grade A` + NULL — format inconsistency          (P4.10)
--     live counts: NULL=9, C=2, Grade A=1
--     post-cleanup target: normalise both to `Grade A` / `Grade B` / `Grade C`
--     (3 affected rows).
--
--   - (onyx_evidence_certificates(event_id) duplicates are in #04 UNIQUE, not here)
--
-- Cutover step: Layer 2 runbook step 7 / phase 5 §3.4 step 7 applies this
-- file AFTER the wipe and preservation verification have completed:
--   (a) normalised incidents.status via the legacy→canonical map above
--       (UPDATE SET status = lower(status) for case variants; reject any
--       non-canonical value for manual review — 19 rows minimum),
--   (b) normalised incidents.priority via the legacy→canonical map above
--       (111 rows touched: 21 CRITICAL+7 HIGH+12 MEDIUM+2 LOW case variants;
--       1+1+67 p1/p2/p3 legacy values need mapping to critical/high/medium;
--       73 critical + 19 high + 38 medium are already canonical lowercase),
--   (c) backfilled incidents.risk_level NULLs (27 rows) — risk_level stays
--       UPPERCASE per existing CHECK pattern on dispatch_intents,
--   (d) normalised guards.grade format (3 rows).
--
-- Cutover command:
--   psql -h aws-1-ap-northeast-1.pooler.supabase.com -p 5432 -U postgres \
--        -d postgres -f 03_add_check_constraints_dirty_enums.sql

BEGIN;

-- incidents.status — canonical lowercase set (ONYX enum convention)
ALTER TABLE public.incidents
  ADD CONSTRAINT incidents_status_check
  CHECK (status IN ('detected', 'open', 'acknowledged', 'dispatched', 'on_site', 'secured', 'closed', 'false_alarm'));

-- incidents.priority — canonical lowercase set (locked 2026-04-21)
ALTER TABLE public.incidents
  ADD CONSTRAINT incidents_priority_check
  CHECK (priority IN ('critical', 'high', 'medium', 'low'));

-- incidents.risk_level — UPPERCASE retained for cross-table consistency with
-- existing dispatch_intents_risk_level_check. Layer 6 may revisit casing.
ALTER TABLE public.incidents
  ADD CONSTRAINT incidents_risk_level_check
  CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL'));

-- guards.grade — assumes Layer 2 normalised to `Grade X` format.
-- Current NULL rows are from placeholder guards (5 rows) being deleted in
-- Step 4b #02 cleanup; remaining NULLs may still exist on real guards.
ALTER TABLE public.guards
  ADD CONSTRAINT guards_grade_check
  CHECK (grade IS NULL OR grade IN ('Grade A', 'Grade B', 'Grade C'));

COMMIT;
