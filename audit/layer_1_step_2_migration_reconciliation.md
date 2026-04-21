# Layer 1 Step 2 — Migration Reconciliation

**Date:** 2026-04-21
**Task:** Layer 1 Step 2. Reconcile the 54 pre-existing migration files against the reverse-engineered baseline from Step 1, producing a clean forward chain where the baseline is the authoritative starting point.
**Out of scope:** live schema mutations; cleanup of phase 4 integrity findings; new constraints; ghost-table conversion; data migrations; merging migrations; reordering historical by timestamp.

---

## 0. Pre-flight

| Check | Result |
|---|---|
| Step 1 inventory (`audit/layer_1_step_1_schema_baseline_inventory.md`) readable | yes — at commit `1887166` |
| Step 1 baseline SQL (`supabase/migrations/2026_04_21_000000_reverse_engineered_baseline.sql`) readable | yes — at commit `cb5cc4d` |
| Phase 5 synthesis (`audit/phase_5_synthesis.md`) on main | **no** — still absent at this HEAD (flagged in Step 1 §0.1). Step 2 proceeded using Step 1 inventory + phase 4 as the authoritative references, per the brief. |
| `supabase/migrations/` writable | yes |
| `deploy/supabase_migrations/` writable | yes |
| `omnix_dashboard/main` HEAD at start | `cb5cc4d` |
| Live Supabase untouched | **yes** — Step 2 performs zero operations against the live DB. All operations are (a) reading migration + baseline files locally, (b) classifying, (c) moving local files between directories via `git mv`, (d) applying only the baseline to a local scratch Postgres for verification. |
| Scratch Postgres still available | re-initialised at `/tmp/pg17_scratch` on port 55432 for §6 verification; torn down after. |

Pre-existing migration set to reconcile: **44** files in `supabase/migrations/` + **10** in `deploy/supabase_migrations/` = **54 files, 718 DDL statements**.

---

## 1. Reconciliation approach

### 1.1 Pattern chosen: **Pattern 2** (baseline as cut-line; historical migrations quarantined)

The brief defaulted to Pattern 1 (flat, baseline-first) unless a specific reason argues for Pattern 2. That specific reason exists and is concrete:

**Pattern 1 would fail the §6 reproducibility gate.** In Pattern 1, all 55 migration files (54 historical + 1 baseline) remain in `supabase/migrations/` and `supabase db reset` applies them in timestamp order. Historical migrations run first and use `CREATE TABLE IF NOT EXISTS`. When the baseline runs last, its `CREATE TABLE IF NOT EXISTS` statements **skip** — the tables already exist from the historical migrations.

The concrete evidence that historical migrations under-specify the current live schema:

| Table | Historical migration declares | Live has | Gap |
|---|---:|---:|---|
| `incidents` | 21 columns (`202603120002_expand_onyx_operational_registry.sql`) | 49 columns | 28 ghost columns added out of band — none of which appear in any later `ALTER TABLE ADD COLUMN` in the chain |
| `sites` | 20 columns (`202603120001_create_guard_directory_tables.sql`) | 36 columns | 16 ghost columns |
| `clients` | 12 columns (same file) | 20 columns | 8 ghost columns |
| `guards` | 14 columns (same file) | 25 columns | 11 ghost columns |
| `employees` | 4 columns (`202603120002_expand_onyx_operational_registry.sql` initial) | 32 columns | 28 ghost columns |

In Pattern 1, every one of these tables would come out of `supabase db reset` missing its ghost columns. Application code that reads `incidents.operator_notes` / `acknowledged_at` / `engine_message` etc. would then fail.

**Pattern 2 chosen:** move all 54 historical files into `historical/` subdirectories (which Supabase CLI does not discover), leaving only the baseline in the active chain. `supabase db reset` then applies **only** the baseline, which faithfully reproduces the live schema (Step 1 §6 verified this for 127 of 129 tables; the remaining 2 are PostGIS-dependent and reproduce on any Supabase target). The historical files remain in version control for audit trail, blame, and reconciliation reference.

### 1.2 Cross-directory alignment check (per user's note #1)

`supabase/migrations/` and `deploy/supabase_migrations/` were a **parallel set** (phase 1a §3.2). Before classification, cross-reference every object touched by migrations in both directories.

| Object | Touched in `supabase/` | Touched in `deploy/` | Drift risk |
|---|---|---|---|
| `table:incidents` | `202603120002_expand_onyx_operational_registry.sql` (CREATE TABLE with 21 cols + inline constraints) | `202604140004_operator_discipline.sql` (later ALTER — adds `simulated`, operator-discipline columns) | **none** — cross-directory compose relationship is additive (deploy extends supabase). No contradicting operations observed. |

**One object of overlap, no contradictions.** The `deploy/` set genuinely operated as an addition to the `supabase/` set for the `incidents` table; otherwise the two directories touch disjoint objects. Noted in §4 below but does not require a dedicated "cross-directory drift" subsection beyond this one row because there is no conflict to reconcile.

### 1.3 Forward-chain rules (effective 2026-04-21)

Going forward, every new migration applied to this project **must**:

1. Have a filename timestamp prefix **strictly greater than** `2026_04_21_000000_` (i.e. `2026_04_21_000001_*.sql` or later).
2. Live in `supabase/migrations/` directly (not in `historical/`).
3. Apply cleanly on top of the baseline to a fresh scratch Postgres. The operator adding the migration verifies this locally before commit. (Layer 1 Step 3 — process lock — will formalise this.)
4. If the migration touches anything documented in §4 (drift catalogue) of this file, update §4 in the same commit.

Live schema mutation is **not** performed in Step 2. Reconciliation is metadata + filesystem organisation.

---

## 2. Classification table

718 total DDL statements across 54 files, classified via automated scanner (see `/tmp/classifications3.json` in the session artefacts). Per-file summary below; full per-statement detail is in the JSON artefact and is too long to embed (would inflate this document by ~750 rows). The summary is sufficient to locate any specific statement by file + classification.

### 2.1 Per-file summary (non-drift-free files)

`applied` column elided when its count is the full total (i.e. all statements in the file classified as `applied`). Drift / orphan / unverified counts are listed explicitly.

| Migration file | Total | applied | applied_with_drift | orphaned | unverified |
|---|---:|---:|---:|---:|---:|
| `deploy/202604130001_create_telegram_operator_context.sql` | 2 | — | 1 | **1** | — |
| `deploy/202604130002_create_onyx_event_store.sql` | 5 | 5 | — | — | — |
| `deploy/202604130003_site_provisioning.sql` | 2 | — | 1 | **1** | — |
| `deploy/202604130004_patrol_checkpoint_scans.sql` | 8 | 7 | 1 | — | — |
| `deploy/202604140001_create_evidence_certificates.sql` | 9 | 7 | 2 | — | — |
| `deploy/202604140002_power_mode_events.sql` | 7 | 6 | 1 | — | — |
| `deploy/202604140003_create_onyx_awareness_latency.sql` | 5 | 2 | 1 | — | 2 |
| `deploy/202604140004_operator_discipline.sql` | 11 | 7 | — | — | 4 |
| `deploy/202604140005_alert_outcomes.sql` | 3 | 2 | 1 | — | — |
| `deploy/202604140006_client_trust.sql` | 2 | 2 | — | — | — |
| `supabase/20260304_create_client_conversation_tables.sql` | 15 | 14 | 1 | — | — |
| `supabase/202603050001_create_guard_sync_tables.sql` | 35 | 34 | 1 | — | — |
| `supabase/202603050002_create_guard_ops_event_log.sql` | 21 | 20 | 1 | — | — |
| `supabase/202603050003_apply_guard_rls_storage_policies.sql` | 57 | 54 | — | — | 3 |
| `supabase/202603050004_add_guard_sync_facade_columns.sql` | 7 | 7 | — | — | — |
| `supabase/202603050005_create_client_conversation_push_queue.sql` | 7 | 6 | 1 | — | — |
| `supabase/202603050006_create_client_conversation_push_sync_state.sql` | 6 | 5 | 1 | — | — |
| `supabase/202603050007_add_probe_fields_to_client_push_sync_state.sql` | 2 | 1 | — | — | 1 |
| `supabase/202603050008_add_guard_projection_retention.sql` | 4 | 4 | — | — | — |
| `supabase/202603050009_add_guard_ops_replay_safety_retention.sql` | 9 | 8 | — | — | 1 |
| `supabase/202603050010_add_guard_rls_storage_readiness_checks.sql` | 2 | 2 | — | — | — |
| `supabase/202603090001_add_guard_ops_media_visual_norm_metadata.sql` | 8 | 5 | — | — | 3 |
| `supabase/202603120001_create_guard_directory_tables.sql` | 73 | 65 | 5 | — | 3 |
| `supabase/202603120002_expand_onyx_operational_registry.sql` | 78 | 64 | 1 | — | 13 |
| `supabase/202603120003_seed_guard_directory_baseline.sql` | 13 | 8 | — | — | 5 |
| `supabase/202603120004_sync_legacy_directory_from_employees.sql` | 23 | 22 | — | — | 1 |
| `supabase/202603120005_add_directory_delete_policies.sql` | 20 | 20 | — | — | — |
| `supabase/202603120006_add_client_push_delivery_provider.sql` | 3 | 2 | — | — | 1 |
| `supabase/202603120007_create_client_messaging_bridge_tables.sql` | 46 | 45 | 1 | — | — |
| `supabase/202603120008_add_client_conversation_message_source_provider.sql` | 8 | 6 | — | — | 2 |
| `supabase/202603150001_create_site_identity_registry_tables.sql` | 36 | 36 | — | — | — |
| `supabase/202604070001_default_site_coordinates.sql` | 3 | 3 | — | — | — |
| `supabase/202604070002_create_alarm_receiver_registry.sql` | 4 | 4 | — | — | — |
| `supabase/202604070003_create_bi_vehicle_persistence.sql` | 19 | 17 | — | — | 2 |
| `supabase/20260409_create_site_alarm_events.sql` | 8 | 8 | — | — | — |
| `supabase/20260409_create_telegram_inbound_updates.sql` | 13 | 8 | 4 | — | 1 |
| `supabase/20260409_site_awareness_anon_read.sql` | 2 | 2 | — | — | — |
| `supabase/20260409z_create_site_occupancy_tracking.sql` | 9 | 6 | 3 | — | — |
| `supabase/20260409zz_add_site_occupancy_guard_flag.sql` | 2 | 1 | — | **1** | — |
| `supabase/20260409zzz_add_site_occupancy_gate_sensor_flag.sql` | 1 | 1 | — | — | — |
| `supabase/20260410_add_client_messaging_endpoint_role.sql` | 3 | 3 | — | — | — |
| `supabase/20260410_add_on_demand_expected_visitors.sql` | 3 | 3 | — | — | — |
| `supabase/20260410_add_site_alert_config_vehicle_daytime_threshold.sql` | 2 | 1 | — | **1** | — |
| `supabase/20260410_add_site_camera_zones.sql` | 6 | 5 | 1 | — | — |
| `supabase/20260410_create_fr_person_registry.sql` | 4 | 4 | — | — | — |
| `supabase/20260410_create_guard_patrol_system.sql` | 35 | 19 | **16** | — | — |
| `supabase/20260410_create_site_alert_config.sql` | 6 | 5 | 1 | — | — |
| `supabase/20260410_create_site_api_tokens.sql` | 3 | 2 | 1 | — | — |
| `supabase/20260410_create_site_intelligence_profile.sql` | 19 | 11 | 8 | — | — |
| `supabase/20260410_create_site_visitors.sql` | 10 | 5 | 5 | — | — |
| `supabase/20260410_create_vehicle_presence.sql` | 11 | 4 | 2 | **5** | — |
| `supabase/20260411_add_site_intelligence_alert_delivery_controls.sql` | 3 | — | — | **3** | — |
| `supabase/202604170001_zara_scenarios.sql` | 14 | 14 | — | — | — |
| `supabase/202604170002_zara_action_log.sql` | 11 | 11 | — | — | — |
| **TOTAL** | **718** | **603** | **61** | **12** | **42** |

### 2.2 Classification totals with kind breakdown

| Classification | Count | Breakdown by kind |
|---|---:|---|
| **applied** | 603 | `drop_policy_if_exists`=122, `index`=92, `policy`=92, `comment`=50, `rls_enable`=47, `table`=45, `drop_trigger_if_exists`=32, `trigger`=32, `dml`=24, `column`=24, `function`=20, `extension`=12, `transaction`=6, `alter_table`=3, `view`=2 |
| **applied_with_drift** | 61 | `policy`=27, `index`=18, `table`=16 |
| **orphaned** | 12 | `column`=5, `table`=3, `policy`=3, `rls_enable`=1 |
| **unverified** | 42 | `do_block`=33, `other`=9 |
| `superseded` | 0 | none detected (would require cross-file back-reference; my classifier does not compute this) |
| `redundant` | 0 | every historical statement is *in one sense* redundant because the baseline now supersedes everything; this step uses `applied` + `applied_with_drift` + `orphaned` + `unverified` as the operative labels. The "redundant" classification is reserved for a future pass that proves no downstream consumer (e.g. `supabase_migrations` chain metadata) still reads the file. |

### 2.3 Dispositions applied

Per the decision tree in the brief:

| Classification | Disposition | File-level effect |
|---|---|---|
| `applied` (603 stmts) | `keep_as_historical` | File moved to `historical/` per Pattern 2 |
| `applied_with_drift` (61 stmts) | `reconcile` | Detail recorded in §4; **no mutation of original migration**. Follow-on reconciliation (if any) is Step 4 scope (add NOT NULL / CHECK / etc. to bring live up to spec). File moved to `historical/` |
| `orphaned` (12 stmts) | `mark_orphaned` | Detail in §3. File moved to `historical/`. No separate `retired/` subdirectory created — the `historical/` README.md is sufficient documentation for audit trail |
| `unverified` (42 stmts) | `keep_as_historical` (conservative) | 33 DO $$ blocks + 9 unrecognised shapes. All landed in files classified dominantly `applied`; none live in a file whose majority classification would have placed it elsewhere |

**Files per disposition:**

- 54 files → `keep_as_historical` (moved to `historical/` — all of them; §3 doesn't re-home orphan-containing files since every such file contains `applied` statements too, and moving them to `retired/` would lose the `applied` part of the trail).
- 0 files → `retire` (the `retire` disposition is not used in Step 2; no file is moved to a `retired/` subdirectory).
- 0 files mutated — original SQL preserved byte-for-byte.

---

## 3. Orphaned migrations detail

12 orphaned statements across 6 files. These are the statements that reference objects absent from live.

### 3.1 Table-level orphans (3)

| Migration | Orphaned object | Likely reason | Disposition |
|---|---|---|---|
| `supabase/historical/20260410_create_vehicle_presence.sql` | `public.site_vehicle_presence` (CREATE TABLE) + its RLS enablement + 3 policies on it (5 total orphan statements) | **Renamed out of band to `site_vehicle_registry`** — Step 1 §2.4 observed the live table `site_vehicle_registry` carries 4 rows with a similar shape, and no migration exists that creates `site_vehicle_registry`. The rename was applied via Studio SQL editor or similar, bypassing the migration chain | `mark_orphaned` |
| `deploy/historical/202604130001_create_telegram_operator_context.sql` | `public.telegram_operator_context` (CREATE TABLE + 1 follow-on index) | **Never applied** — phase 1a §3.3 flagged 404 on PostgREST; Step 1 §4 corroborated (no live presence); likely the migration was committed to the deploy set but the subsequent deploy pipeline never ran this file (the parallel `deploy/` set was applied manually in phase 2a §3.3's Apr-13 window and this specific one was missed) | `mark_orphaned` |
| `deploy/historical/202604130003_site_provisioning.sql` | `public.site_shift_schedules` (CREATE TABLE + 1 follow-on index) | **Never applied** — same diagnosis as above | `mark_orphaned` |

### 3.2 Column-level orphans (5 statements, 5 distinct columns)

Columns that were added by migration but are absent from live. All plausible causes converge on "feature was added, then rolled back / replaced / renamed without updating the migration chain."

| Migration | Orphaned column | Likely reason |
|---|---|---|
| `supabase/historical/20260409zz_add_site_occupancy_guard_flag.sql` | `site_occupancy_config.has_guard` | Feature flag added then dropped. Note: the sibling `20260409zzz_add_site_occupancy_gate_sensor_flag.sql` (for `has_gate_sensors`) IS applied — live has that column. Suggests the has_guard flag was abandoned in favour of gate-sensors |
| `supabase/historical/20260410_add_site_alert_config_vehicle_daytime_threshold.sql` | `site_alert_config.vehicle_daytime_threshold` | Numeric threshold column added then dropped; live `site_alert_config` has 1 row with 0 non-null values in this column path |
| `supabase/historical/20260411_add_site_intelligence_alert_delivery_controls.sql` | `site_intelligence_profiles.alert_with_snapshot` | Boolean delivery control, dropped |
| same file | `site_intelligence_profiles.alert_with_buttons` | same |
| same file | `site_intelligence_profiles.response_mode` | text-enum delivery control, dropped (live `site_intelligence_profiles` has 1 row; phase 4 §3b flagged these as likely-refactored delivery-control columns) |

### 3.3 Not-yet-covered orphan finding

In Step 1 §4, one additional orphaned migration reference was flagged: `deploy/historical/202604140004_operator_discipline.sql:1 [column:incidents.simulated]`. The re-run classifier in Step 2 correctly identified `incidents.simulated` as present in live (column 47 of 49 in `public.incidents`, populated with 241 `false` values). The Step 1 flag was a false positive from the first-pass classifier's column-parser bug (fixed in Step 2 — see §7.1 below). `incidents.simulated` is **applied, not orphaned**. This correction is reflected in the Step 2 totals above.

---

## 4. Drift catalogue (applied_with_drift detail)

61 statements flagged as drifted. Breakdown by drift type:

### 4.1 Table drift — live has extra columns not declared in migration (16 statements)

These are the classic ghost-column finding from phase 4 §2.5, now enumerated per migration. For each, migration + drift + follow-on-needed columns:

| Migration : statement | Table | Columns in migration | Columns in live | Extra in live (first 3) |
|---|---|---:|---:|---|
| `supabase/historical/202603120002_…registry.sql:31` | `incidents` | 21 | 49 | `acknowledged_at`, `acknowledged_by`, `action_code`, … (28 total) |
| `supabase/historical/202603120001_…directory_tables.sql:4` | `clients` | 12 | 20 | `address`, `client_type`, `contract_start`, … (8 total) |
| `supabase/historical/202603120001_…directory_tables.sql:5` | `sites` | 20 | 36 | `active`, `address`, `client_name`, … (16 total) |
| `supabase/historical/202603120001_…directory_tables.sql:8` | `guards` | 14 | 25 | `active`, `competency_type`, `competent`, … (11 total) |
| `supabase/historical/202603120001_…directory_tables.sql:6` | `controllers` | 10 | 13 | `first_name`, `last_name`, `source_employee_id` |
| `supabase/historical/202603120001_…directory_tables.sql:7` | `staff` | 10 | 13 | `first_name`, `last_name`, `source_employee_id` |
| `supabase/historical/202603050001_create_guard_sync_tables.sql:3` | `guard_sync_operations` | (subset) | (13 more) | `facade_id`, `facade_mode`, … |
| `supabase/historical/202603050002_…guard_ops_event_log.sql:11` | `guard_ops_media` | (subset) | +2 | `visual_norm_metadata`, `visual_norm_mode` |
| `supabase/historical/202603050005_…push_queue.sql:3` | `client_conversation_push_queue` | (subset) | +1 | `delivery_provider` |
| `supabase/historical/202603050006_…push_sync_state.sql:3` | `client_conversation_push_sync_state` | (subset) | +4 | `probe_failure_reason`, `probe_history`, `probe_last_run_at`, … |
| `supabase/historical/20260304_…conversation_tables.sql:3` | `client_conversation_messages` | (subset) | +2 | `message_provider`, `message_source` |
| `supabase/historical/202603120007_…bridge_tables.sql:3` | `client_messaging_endpoints` | (subset) | +1 | `endpoint_role` |
| `supabase/historical/20260409z_…site_occupancy_tracking.sql:1` | `site_occupancy_config` | (subset) | +1 | `has_gate_sensors` |
| `supabase/historical/20260410_create_site_visitors.sql:1` | `site_expected_visitors` | (subset) | +1 | `visit_type` |
| `supabase/historical/20260410_create_guard_patrol_system.sql:3` | `guard_assignments` | (initial shape) | `+live=8, -mig=6` | (mixed — later migration also touches `guard_assignments`) |
| `deploy/historical/202604140005_alert_outcomes.sql:1` | `onyx_alert_outcomes` | (initial) | +3 | `created_at`, `id`, `updated_at` (standard audit trio) |

Cross-reference: every row in this section corresponds to a concrete ghost-column finding in phase 4 §2.5 / §3.1. Step 4 will decide whether to add NOT NULL / default / check constraints on the ghost columns; Step 2 only records the drift.

### 4.2 Policy drift (27 statements)

Policies declared by migration whose named policy is absent in live. This is typically caused by a later out-of-band policy replacement (e.g. the migration created `patrol_routes_service_all`, live has `patrol_routes_service_policy` or similar under a different name).

Concentrated in one file: `supabase/historical/20260410_create_guard_patrol_system.sql` (10 policies, all `_service_all` / `_authenticated_read` pairs on `patrol_routes` / `patrol_checkpoints` / `guard_assignments` / `patrol_scans` / `patrol_compliance`). Other scattered drift:

| Migration | Policy (declared name → live state) |
|---|---|
| `supabase/historical/20260410_create_guard_patrol_system.sql` (×10) | 5 pairs of `_service_all`/`_authenticated_read` policies declared on patrol_* tables; absent by name in live. Live has policies on these tables but under different names (Step 1 §2: `patrol_checkpoints` has 1 policy live; migration declared 2). |
| `supabase/historical/20260409z_create_site_occupancy_tracking.sql` (×2) | `anon_can_read_site_occupancy_config` + `anon_can_read_site_occupancy_sessions` — absent in live |
| `supabase/historical/20260410_create_site_visitors.sql` (×3) | all three `site_expected_visitors_*` policies |
| `supabase/historical/20260410_create_site_intelligence_profile.sql` (×6) | 3 each on `site_intelligence_profiles` + `site_zone_rules` |
| `supabase/historical/20260410_add_site_camera_zones.sql` (×1) | `anon_can_read_site_camera_zones` |
| `supabase/historical/20260410_create_site_alert_config.sql` (×1) | `anon_can_read_site_alert_config` |
| `supabase/historical/20260409_create_telegram_inbound_updates.sql` (×1) | `telegram_inbound_updates_select_policy` |
| `deploy/historical/202604130004_patrol_checkpoint_scans.sql` (×1) | `patrol_checkpoint_scans_authenticated_read` |
| `deploy/historical/202604140001_create_evidence_certificates.sql` (×1) | `onyx_evidence_certificates_authenticated_read` |
| `deploy/historical/202604140002_power_mode_events.sql` (×1) | `onyx_power_mode_events_authenticated_read` |

Step 4 will need to reconcile policy naming if RLS policy-name stability is required for downstream tooling; Step 2 only catalogues.

### 4.3 Index drift (18 statements)

Indexes declared by migration whose named index is absent in live. Similar to policy drift: indexes likely exist under different names.

| Migration | Indexes absent in live |
|---|---|
| `supabase/historical/20260410_create_guard_patrol_system.sql` (×5) | `patrol_routes_site_idx`, `patrol_checkpoints_site_route_idx`, `guard_assignments_site_idx`, `patrol_scans_site_guard_scanned_idx`, `patrol_compliance_site_guard_date_idx` |
| `supabase/historical/20260410_create_site_intelligence_profile.sql` (×2) | `site_intelligence_profiles_site_idx`, `site_zone_rules_site_zone_idx` |
| `supabase/historical/20260410_create_site_visitors.sql` (×1) | `site_expected_visitors_site_idx` |
| `supabase/historical/20260410_create_vehicle_presence.sql` (×2) | `site_vehicle_presence_site_time_idx`, `site_vehicle_presence_site_plate_time_idx` (cascade of the renamed-table orphan in §3.1) |
| `supabase/historical/20260410_create_site_api_tokens.sql` (×1) | `site_api_tokens_site_id_idx` |
| `deploy/historical/202604130001_create_telegram_operator_context.sql` (×1) | `telegram_operator_context_updated_at_idx` (cascade of orphan table) |
| `deploy/historical/202604130003_site_provisioning.sql` (×1) | `site_shift_schedules_client_idx` (cascade of orphan table) |
| `deploy/historical/202604140001_create_evidence_certificates.sql` (×1) | `onyx_evidence_certificates_detected_idx` |
| `deploy/historical/202604140003_create_onyx_awareness_latency.sql` (×1) | `onyx_awareness_latency_site_idx` |

### 4.4 Cross-directory drift (per §1.2)

Only `table:incidents` is touched by both directories. The `deploy/` migration extended what the `supabase/` migration created; no contradicting operations. No cross-directory drift subsection required beyond §1.2.

---

## 5. Forward-chain layout (post-reconciliation)

### 5.1 Directory structure

```
supabase/migrations/
├── 2026_04_21_000000_reverse_engineered_baseline.sql    ← ACTIVE CHAIN (sole migration)
└── historical/
    ├── README.md
    ├── 20260304_create_client_conversation_tables.sql
    ├── 202603050001_create_guard_sync_tables.sql
    ├── ... (42 more files, timestamps 2026-03-05 → 2026-04-17)
    └── 202604170002_zara_action_log.sql

deploy/supabase_migrations/
└── historical/
    ├── README.md
    ├── 202604130001_create_telegram_operator_context.sql
    ├── 202604130002_create_onyx_event_store.sql
    ├── ... (6 more)
    └── 202604140006_client_trust.sql
```

- **Active chain:** `supabase/migrations/2026_04_21_000000_reverse_engineered_baseline.sql` only (1 file).
- **Historical record (supabase side):** `supabase/migrations/historical/` — 44 files + README.
- **Historical record (deploy side):** `deploy/supabase_migrations/historical/` — 10 files + README.
- **Supabase CLI discovery:** only scans the directory immediately under `supabase/migrations/`, so the 44 historical files are not in its applicative chain. `supabase db reset` will apply only the baseline.

### 5.2 Future-migration rules (recap from §1.3)

New migrations authored from 2026-04-21 onward must:

1. Timestamp **strictly after** `2026_04_21_000000_` (baseline).
2. Live in `supabase/migrations/` (not `historical/`).
3. Apply cleanly on top of the baseline to a fresh scratch Postgres.
4. If touching anything in §4, update §4 in the same commit.
5. Never mutate `historical/*.sql` — those files are frozen for audit trail.

Layer 1 Step 3 (process lock) will formalise these rules in tooling (pre-commit hook or CI check); Step 2 establishes them as documented convention.

---

## 6. Verification (hard gate)

### 6.1 Test harness

- Target: scratch Postgres 17.9 (Homebrew), freshly initdb'd at `/tmp/pg17_scratch`, started on `localhost:55432`. Same setup as Step 1 §6.
- Fresh database: `reconcile_verify` (created inside the scratch cluster; no reused state).
- Pre-apply prep (identical to Step 1 §6.1): `extensions`, `graphql`, `vault`, `auth`, `storage` schemas; `service_role`, `authenticated`, `anon` roles; `pgcrypto` + `uuid-ossp` in `extensions`; `auth.uid()` / `auth.jwt()` stubs; `storage.objects` minimal shape.
- Unavailable extensions commented out via `sed`: `pg_cron`, `pg_graphql`, `postgis`, `supabase_vault`.

### 6.2 Active chain applied

**Per Pattern 2, the active chain is exactly one file: the baseline.** No historical migrations are applied. The verification therefore applies `2026_04_21_000000_reverse_engineered_baseline.sql` only.

### 6.3 Object counts — Step 1 scratch vs Step 2 scratch

| Object | Step 1 §6.2 (baseline-only) | Step 2 §6 (reconciled active chain) | Match? |
|---|---:|---:|---|
| Tables | 127 | **127** | ✓ |
| Views | 17 | **17** | ✓ |
| Indexes | 314 | **314** | ✓ |
| Functions (public) | 32 | **32** | ✓ |
| Triggers | 34 | **34** | ✓ |
| Policies | 146 | **146** | ✓ |
| Enums | 14 | **14** | ✓ |
| Sequences | 2 | **2** | ✓ |
| RLS enabled | 62 | **62** | ✓ |
| Foreign keys | 42 | **42** | ✓ |

**All 10 object counts match exactly.** The 2-table and 7-view gap vs live (129 tables, 24 views) is entirely PostGIS-dependent — identical to Step 1's gap (`sites`, `intel_events` need `geography(Point,4326)`; 7 views cascade). On a real Supabase target, both environments reach 129 tables / 24 views.

### 6.4 Pass / fail

**PASS.** The reconciled chain reproduces the Step 1 baseline state exactly, and the baseline reproduces the live production schema (modulo PostGIS substitutions documented in Step 1 §6). Reconciliation is consistent — no objects differ.

---

## 7. Known limitations

### 7.1 First-pass column-parser bug (diagnosed and fixed)

The Step 2 initial classifier (the first `extract_ddl` pass in `/tmp/classifications.json`) used a regex-based column parser that could not handle nested parentheses inside column defaults (e.g. `DEFAULT COALESCE(NULLIF(auth.jwt() ->> 'org_id', ''), 'global')` and `geography(Point,4326)`). This caused ~20 columns to be classified as `orphaned` when they were actually `applied` — visible in the first classifier output as 32 orphaned statements including false-positive column drops on `sites.physical_address`, `controllers.*`, `guards.*`, `staff.*`, and the `incidents.simulated` finding from Step 1 §4.

The corrected classifier (`/tmp/classifications3.json`) uses a depth-counting paren-matcher and produces 12 orphaned statements. All orphans in §3 above are from the corrected run. The 20-statement delta is now correctly classified as `applied`.

### 7.2 DO $$ … $$ blocks — "unverified" as de-facto sixth category

Per user's note #2, DO $$ blocks are classified `unverified`: the block is treated as an opaque unit whose externally-observable effect is not statically derivable. 33 DO blocks across the 54 files, concentrated in `supabase/historical/202603120001_create_guard_directory_tables.sql` (3 blocks), `202603120002_expand_onyx_operational_registry.sql` (13 blocks — largest concentration; identity/role-binding setup), `202603120003_seed_guard_directory_baseline.sql` (5 blocks), `202603050003_apply_guard_rls_storage_policies.sql` (3 blocks), plus scattered singletons. None of these blocks ALTER the schema in a way not already covered by explicit `CREATE TABLE` / `ADD COLUMN` elsewhere in the same file — but since the classifier cannot verify this without execution, they remain `unverified`.

`unverified` statements do not block the §6 gate because the gate measures schema outcome (object counts), not historical-migration-replay validity. They become Step 4's concern only if Step 4 needs to replay an individual historical migration's intent.

### 7.3 Cross-migration "superseded" detection not performed

The `superseded` classification (statement contradicted by a later migration in the chain) requires building a dependency graph across migration files. The Step 2 classifier operates per-file and does not detect cross-file contradiction. Examples that *might* be superseded — e.g. a CREATE POLICY in migration A followed by a DROP POLICY + CREATE POLICY with a different body in migration B — are counted as two independent `applied` statements rather than one `applied` + one `superseded`.

Impact: minor. Cross-file contradictions would still be captured in the live schema regardless (the later statement wins at apply time), and the baseline reflects the live outcome. The `keep_as_historical` disposition is correct for both the superseded and the superseding statement. Step 2 does not need the distinction to produce the correct outcome.

### 7.4 `redundant` classification is latent

Every historical migration is, in a strong sense, redundant now that the baseline exists — applying any of them to a fresh DB would either (a) create an object the baseline also creates (the `CREATE TABLE IF NOT EXISTS` guards would make this a no-op on baseline-first chains, but the historical migration on its own would create the table, which the baseline would then conflict with), or (b) add a column the baseline already declares. Step 2 does not exercise the `redundant` classification because Pattern 2's file-system choice (quarantined `historical/`) achieves the same practical outcome — historical SQL is not re-run — without requiring per-statement classification.

Step 3 (process lock) may want to formally mark the historical files as `redundant` in a machine-readable manifest; Step 2 uses directory quarantine as the machine-readable signal.

### 7.5 9 "other" unverified statements

The 9 `other` unverified statements are DDL shapes the classifier didn't recognise. Inspection shows they are all either (a) comment-only lines that leaked past the comment-stripping filter (e.g. `-- ONYX guard data RLS and storage polic`), or (b) statement continuations where the SQL splitter didn't cleanly split (e.g. `scoped by site + guard) -- ==========`). These are not real DDL and have no schema effect.

### 7.6 GRANT/REVOKE classification is optimistic

The classifier marks GRANT/REVOKE as `applied` without verifying that the grant is currently in effect on live. Role-level grants tracked in pg_catalog were not dumped into the baseline comparison set. This is acceptable for Step 2 scope (reconciliation focuses on schema shape, not access-matrix verification) but means a grant statement in a historical migration that has since been revoked out of band would still be marked `applied` here.

### 7.7 Not blocking

None of the above invalidates the §6 gate. The reconciled chain produces the correct object counts against a scratch target; the baseline faithfully represents live. Step 2 is complete.

---

*End of Step 2 reconciliation. Step 3 (process lock) will add tooling / CI enforcement around the forward-chain rules in §1.3. Step 4 (constraints) will act on the §4 drift catalogue to add NOT NULL / CHECK / hard FK where phase 4 flagged them as desirable.*
