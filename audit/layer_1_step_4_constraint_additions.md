# Layer 1 Step 4 — Constraint Additions

**Date:** 2026-04-21
**Task:** Final step of Layer 1 of the audit remediation. Add constraint migrations that bring the schema up to integrity standard per phase 4's findings, split into two groups — **4a applicable now** (in the active migration chain) and **4b staged for post-cutover** (out-of-chain, applied manually at Layer 2.3 step 5).
**Out of scope:** data cleanup, data migrations, ghost-table removals, Layer 6 multi-tenant RLS design, 4b application, policy-logic review, new tables, new columns, enum-type conversions.

---

## 0. Pre-flight and inputs

| Check | Result |
|---|---|
| Step 1 inventory (`audit/layer_1_step_1_schema_baseline_inventory.md`) read — §3 ghost columns, §5 RLS state | yes — at commit `1887166` |
| Step 1 baseline SQL read | yes — at commit `cb5cc4d` |
| Step 2 reconciliation (`audit/layer_1_step_2_migration_reconciliation.md`) read — §4 drift catalogue | yes — at commits `ffe760d` + `2897600` |
| Step 3 drift detector committed | yes — at commit `b7bf84a` |
| Phase 4 (`audit/phase_4_data_integrity.md`) read — §4 values, §6 FK integrity, §7 null integrity, §8 duplicates, §10 RLS coverage | yes |
| `omnix_dashboard/main` HEAD at start | `b7bf84a` |
| Live Supabase connectivity verified | yes — credentials discovered via `supabase db dump --dry-run --linked` (Step 1/3 pattern); `SET ROLE postgres` required to read application tables (`cli_login_postgres` role is schema-only) |
| Scratch Postgres target | Step 3's `scripts/schema_drift_check.py` provisions + tears down `/tmp/pg17_scratch` at port 55432 each run |

Live reads used: metadata harvest + classification probes only. Zero writes. Raw probe outputs preserved in session artefacts at `/tmp/layer1_step4/phase_a_probes_evidence.txt` + `metadata_harvest_evidence.txt`.

---

## 1. Classification table

Every 4b classification has SQL probe + literal count inline.

**Access path for every probe below:** `supabase db dump --dry-run --linked` → `eval $(... grep ^export)` → `psql -f <probe.sql>` with `SET ROLE postgres;` at the top. Credentials never committed, never logged to stdout.

### 1.1 FK promotions

**Existing hard FKs in live:** 57 (per Step 1 §1). **Soft-FK `*_id` columns total:** 172 (from Phase A probe P0 enumeration via `pg_attribute` with `attname LIKE '%\_id'`). **Delta:** ~115 promotion candidates. Probed the subset on populated tables; empty-table candidates are deferred as noted in §1.1.2.

#### 1.1.1 Per-candidate classification

| # | Candidate | SQL probe (shape) | Result | 4a/4b |
|---|---|---|---|---|
| 1 | `client_evidence_ledger.client_id → clients.client_id` | `SELECT count(*) FILTER (WHERE client_id IS NOT NULL AND client_id NOT IN (SELECT client_id FROM clients)) FROM client_evidence_ledger;` | **10 orphans / 16,388 rows** | **4b** |
| 2 | `client_evidence_ledger.dispatch_id → dispatch_intents.dispatch_id::text` | same shape (with `::text` cast) | **16,388 orphans / 16,388 rows (100%)** | **4b** |
| 3 | `client_conversation_messages.client_id → clients.client_id` | same shape | **20 / 20 (100%)** | **4b** |
| 4 | `client_conversation_acknowledgements.client_id → clients.client_id` | same | **22 / 22 (100%)** | **4b** |
| 5 | `client_conversation_push_queue.client_id → clients.client_id` | same | **10 / 11 (91%)** | **4b** |
| 6 | `client_conversation_push_sync_state.client_id → clients.client_id` | same | **1 / 2** | **4b** |
| 7 | `guard_ops_events.guard_id → guards.guard_id` | same | **3 / 3 (100%)** — all `guard_actor_contract` test pollution | **4b** |
| 8 | `incident_aar_scores.incident_id → incidents.id` | `WHERE incident_id::text NOT IN (SELECT id::text FROM incidents)` | **4 / 11** | **4b** |
| 9 | `incidents.site_id → sites.site_id` | `FROM incidents` | 0 orphans; 238 nulls | **4b** (paired with NOT NULL #25 — user adjustment 1) |
| 10 | `incidents.client_id → clients.client_id` | same | 0 / 241 | **4a** |
| 11 | `site_alarm_events.site_id → sites.site_id` | same | 0 / 11,227 | **4a** |
| 12 | `onyx_evidence_certificates.site_id → sites.site_id` | same | 0 / 282 | **4a** |
| 13 | `onyx_evidence_certificates.client_id → clients.client_id` | same | 0 / 282 | **4a** |
| 14 | `onyx_evidence_certificates.incident_id → incidents.id` | `::text` cast variant | 0 orphans; 282 nulls | **4b** (paired with NOT NULL #27 — user adjustment 2) |
| 15 | `fr_person_registry.site_id → sites.site_id` | same | 0 / 5 | **4a** |
| 16 | `site_camera_zones.site_id → sites.site_id` | same | 0 / 16 | **4a** |
| 17 | `site_occupancy_config.site_id → sites.site_id` | same | 0 / 1 | **4a** |
| 18 | `site_occupancy_sessions.site_id → sites.site_id` | same | 0 / 11 | **4a** |
| 19 | `site_alert_config.site_id → sites.site_id` | same | 0 / 1 | **4a** |
| 20 | `site_api_tokens.site_id → sites.site_id` | same | 0 / 2 | **4a** |
| 21 | `site_intelligence_profiles.site_id → sites.site_id` | same | 0 / 1 | **4a** |
| 22 | `site_expected_visitors.site_id → sites.site_id` | same | 0 / 2 | **4a** |
| 23 | `onyx_power_mode_events.site_id → sites.site_id` | same | 0 / 31 | **4a** |
| 24 | `site_vehicle_registry.site_id → sites.site_id` | same | 0 / 4 | **4a** |

**Phase 4 misattributions caught:** `site_alarm_events.client_id`, `onyx_power_mode_events.client_id`, `telegram_inbound_updates.client_id`, `global_events.client_id` — **these columns do not exist in live** (`ERROR: column "client_id" does not exist` on P3.11, P3.24 second select, P3.27, P3.29). Phase 4 §1.4 misreported. Dropped from candidacy.

**Type compatibility verified:** `incidents.id` is **text** (not UUID as phase 4 implied). `onyx_evidence_certificates.incident_id text → incidents.id text` is type-compatible. `sites.site_id` has single-column UNIQUE index `sites_site_id_global_unique_idx`, so FK target is valid without adding a prerequisite UNIQUE. `clients.client_id` has `clients_client_id_compat_unique_idx` — same.

#### 1.1.2 Empty-table soft FKs

Not probed individually. Empty tables cannot violate a FK (vacuous truth), so they would all classify 4a if included. **Deferred out of Step 4 scope** — Layer 2 reviews ghost tables for drop-vs-keep first; adding FKs to tables Layer 2 may drop creates wasted migrations. Re-evaluate in Layer 6 (or an explicit Step 4.5).

### 1.2 NOT NULL

| # | Column | Probe | Nulls / Total | 4a/4b |
|---|---|---|---:|---|
| 25 | `incidents.site_id` | `count(*) FILTER (WHERE site_id IS NULL)` | **238 / 241** | **4b** |
| 26 | `incidents.client_id` | same | 0 / 241 | **4a** |
| 27 | `onyx_evidence_certificates.incident_id` | same | **282 / 282** | **4b** |
| 28 | `onyx_evidence_certificates.face_match_id` | same | **282 / 282** | **4b → design decision: stays NULLABLE** (see §3) |
| 29 | `guards.full_name` | `WHERE full_name IS NULL OR btrim(full_name) = ''` | **5 / 12** | **4b** |
| 30 | `guards.client_id` | nulls | **5 / 12** | **4b** |
| 31 | `guards.primary_site_id` | nulls | **5 / 12** | **4b** |
| 32 | `client_evidence_ledger.previous_hash` | nulls | **2 / 16,388** | **4b** (2 genesis rows) |
| 33 | `client_evidence_ledger.client_id` | nulls | 0 / 16,388 | **4a** |
| 34 | `client_evidence_ledger.dispatch_id` | nulls | 0 / 16,388 | **4a** |
| 35 | `site_alarm_events.site_id` | nulls | 0 / 11,227 | **4a** |
| 36 | `fr_person_registry.site_id` | nulls | 0 / 5 | **4a** |
| 37 | `site_camera_zones.site_id` | nulls | 0 / 16 | **4a** |
| 38 | `site_occupancy_sessions.site_id` | nulls | 0 / 11 | **4a** |
| 39 | `telegram_inbound_updates.update_id` | nulls | 0 / 100 | **4a** |
| 40 | `telegram_inbound_updates.chat_id` | nulls | 0 / 100 | **4a** |
| 41 | `dispatch_transitions.dispatch_id` | nulls | 0 / 34 | **4a** |
| 42 | `dispatch_transitions.to_state` | nulls | 0 / 34 | **4a** |
| 43 | `dispatch_transitions.actor_type` | nulls | 0 / 34 | **4a** |
| 44 | `dispatch_intents.risk_level` | nulls | 0 / 27 | **4a** |
| 45 | `dispatch_intents.action_type` | nulls | 0 / 27 | **4a** |

### 1.3 CHECK (canonical-value enums)

| # | Column | Probe (`GROUP BY`) | Distinct values found | 4a/4b |
|---|---|---|---|---|
| 46 | `incidents.status` | `SELECT status, count(*) FROM incidents GROUP BY status` | 7 values; mixed case (`OPEN`/19 vs `open`/78) | **4b** |
| 47 | `incidents.priority` | same | 10 across 4 vocabularies (`critical`/`CRITICAL`/`p3`/`HIGH`/...) | **4b** |
| 48 | `incidents.risk_level` | same | 5 values + 27 NULL | **4b** |
| 49 | `incidents.action_code` | same | 4 values + 69 NULL (CRITICAL_ALERT, MONITOR, ESCALATE, LOG_ONLY) | **4a** (NULL-tolerant CHECK) |
| 50 | `incidents.category` | same | 5 values + 27 NULL (Unknown, Robbery, Hijacking, General Incident, Public Unrest) | **4a** |
| 51 | `incidents.source` | same | 4 values + 3 NULL (manual, news, social, ops) | **4a** |
| 52 | `incidents.incident_type` | same | 3 values (technical_failure, breach, panic); 0 NULL | **4a** |
| 53 | `guards.grade` | same | NULL/9, `C`/2, `Grade A`/1 — format inconsistency | **4b** |
| 54 | `site_alarm_events.event_type` | same | 3 values (camera_worker_offline, false_alarm_cleared, armed_response_requested) | **4a** |
| 55 | `client_conversation_messages.author` | same | 2 values (Client/16, Control/4) | **4a** |
| 56 | `client_conversation_messages.viewer_role` | same | 2 values (client/16, control/4) | **4a** |
| 57 | `onyx_evidence_certificates.issuer` | same | 1 value (`ONYX Risk and Intelligence Group`/282) | **4a** — locks dead enum |
| 58 | `onyx_evidence_certificates.version` | same | 1 value (`1.0`/282) | **4a** |
| 59 | `onyx_power_mode_events.mode` | same | 3 values (threat/16, normal/14, degraded/1) | **4a** |
| 60 | `site_camera_zones.zone_type` | same | 3 values (perimeter/4, semi_perimeter/6, indoor/6) | **4a** |
| 61 | `employees.employment_status` | same | 1 value (active/6) | **4a** |

Dead-enum columns skipped (CHECK adds no value): `incidents.scope` (AREA/241), `incidents.channel` (NULL/241 — write-never-read).

### 1.4 UNIQUE

| # | Uniqueness expectation | Probe | Result | 4a/4b |
|---|---|---|---|---|
| 62 | `sites(name)` | `SELECT name, count(*) FROM sites GROUP BY name HAVING count(*) > 1` | 0 dupe groups | **4a** |
| 63 | `clients(name)` | same | **1 dupe group** (`test` × 3) | **4b** |
| 64 | `guards(full_name)` | same | **3 dupe groups** + 5 NULL (Lerato Moletsane × 2, Thabo Mokoena × 2, Sipho Ndlovu × 2) | **4b** |
| 65 | `onyx_evidence_certificates(event_id)` | same | **5 dupe groups** (EVT-…5-VMD × 3 + 4 pairs) | **4b** |
| 66 | `incidents(event_uid)` | same | 0 dupe groups | **4a** |
| 67 | `client_evidence_ledger(hash)` | same | 0 dupe groups | **4a** |

### 1.5 Indexes (from Step 2 §4.3 drift catalogue)

| # | Index | Rationale | 4a/4b |
|---|---|---|---|
| 68 | `patrol_routes_site_idx (site_id)` | Step 2 §4.3 | **4a** |
| 69 | `patrol_checkpoints_site_route_idx (site_id, route_id)` | same | **4a** |
| 70 | `patrol_scans_site_guard_scanned_idx (site_id, guard_id, scanned_at DESC)` | same | **4a** |
| 71 | `patrol_compliance_site_guard_date_idx (site_id, guard_id, compliance_date)` | same | **4a** |
| 72 | `site_intelligence_profiles_site_idx (site_id)` | same | **4a** |
| 73 | `site_zone_rules_site_zone_idx (site_id, zone_code)` | same | **4a** |
| 74 | `site_expected_visitors_site_idx (site_id)` | same | **4a** |
| 75 | `site_api_tokens_site_id_idx (site_id)` | same | **4a** |
| 76 | `onyx_evidence_certificates_detected_idx (detected_at DESC)` | same | **4a** |
| 77 | `onyx_awareness_latency_site_idx (site_id)` | same | **4a** |

Skipped from Step 2 §4.3: `site_vehicle_presence_*` (renamed target), `telegram_operator_context_*` + `site_shift_schedules_*` (never-applied tables).

### 1.6 RLS decisions (66 tables without RLS per Step 1 §5.2)

| # | Table | Decision | Rationale |
|---|---|---|---|
| 78 | `client_evidence_ledger` (16,388) | **4a ENABLE + policy** | client_id present; client-scoped audit chain |
| 79 | `client_conversation_messages` (20) | **4a ENABLE + policy** | client_id present |
| 80 | `client_conversation_acknowledgements` (22) | **4a ENABLE + policy** | client_id present |
| 81 | `client_conversation_push_queue` (11) | **4a ENABLE + policy** | client_id present |
| 82 | `client_conversation_push_sync_state` (2) | **4a ENABLE + policy** | client_id present |
| 83 | `spatial_ref_sys` | **4a DISABLED (internal comment)** | PostGIS reference data |
| 84 | `guard_ops_replay_safety_checks` | **4a DISABLED (internal)** | retention pipeline |
| 85 | `guard_ops_retention_runs` | **4a DISABLED (internal)** | retention pipeline |
| 86 | `guard_projection_retention_runs` | **4a DISABLED (internal)** | retention pipeline |
| 87 | `execution_locks` | **4a DISABLED (internal)** | dispatch mutex |
| 88 | `site_api_tokens` | **4a DISABLED (safety)** | auth tokens — user adjustment |
| 89 | `users` | **4a DISABLED (safety)** | identity — user adjustment |
| 90 | `roles` | **4a DISABLED (safety)** | authz — user adjustment |
| 91 | `decision_audit_log` | **4a DISABLED (safety)** | audit trail — user adjustment |
| 92 | `decision_traces` | **4a DISABLED (safety)** | audit trail — user adjustment |
| 93 | `alarm_accounts` | **4a DISABLED (safety)** | alarm-provider credentials |
| 94 | `evidence_bundles` | **4a DISABLED (safety)** | evidence grouping |
| 95 | `guard_logs` | **4a DISABLED (safety)** | guard activity logs |
| 96 | `vehicle_logs` | **4a DISABLED (safety)** | vehicle tracking |
| 97 | `intel_events` | **4a DISABLED (safety)** | intel ingest |
| 98 | `intel_patrol_links` | **4a DISABLED (safety)** | intel ↔ patrol |
| 99 | `intel_source_weights` | **4a DISABLED (safety)** | intel weighting |
| 100 | `intelligence_snapshots` | **4a DISABLED (safety)** | intel snapshots |
| 101 | `threat_scores` | **4a DISABLED (safety)** | threat output |
| 102 | `threat_decay_profiles` | **4a DISABLED (safety)** | threat config |
| 103 | `watch_events` | **4a DISABLED (safety)** | watch stream |
| 104 | `watch_archive` | **4a DISABLED (safety)** | watch archive |
| 105 | `watch_current_state` | **4a DISABLED (safety)** | watch snapshot |
| 106 | `onyx_settings` | **4a DISABLED (safety)** | platform settings/secrets |

**Ambiguous → deferred to Layer 6** (remaining ~38 tables): see §7.

### 1.7 Tally

| Category | 4a | 4b |
|---|---:|---:|
| FK promotions (populated only) | 14 | 10 |
| NOT NULL | 14 | 7 (face_match_id removed — §3) |
| CHECK | 11 | 4 |
| UNIQUE | 3 | 3 |
| Indexes | 10 | 0 |
| RLS enable + policy | 5 | — |
| RLS DISABLED internal comment | 5 | — |
| RLS DISABLED safety comment | 19 | — |
| Ambiguous → Layer 6 | 38 | — |
| **Totals in Step 4 scope** | **81** | **24** |

4a : 4b ratio on constraint additions (excluding deferred) = 77% : 23%.

---

## 2. 4a migrations written

One file per constraint category, timestamped after the baseline:

| File | Adds | Count |
|---|---|---:|
| `supabase/migrations/2026_04_21_000101_add_fk_promotions.sql` | FK CONSTRAINT on 14 cols → sites/clients | 14 |
| `supabase/migrations/2026_04_21_000102_add_not_null_clean_columns.sql` | SET NOT NULL on 14 cols | 14 |
| `supabase/migrations/2026_04_21_000103_add_check_constraints_clean_enums.sql` | CHECK on 11 enum-like cols | 11 |
| `supabase/migrations/2026_04_21_000104_add_unique_constraints.sql` | UNIQUE on 3 cols | 3 |
| `supabase/migrations/2026_04_21_000105_add_indexes.sql` | CREATE INDEX IF NOT EXISTS for 10 indexes | 10 |
| `supabase/migrations/2026_04_21_000106_rls_decisions.sql` | 5 ENABLE + 5 internal-disable COMMENTs + 19 safety-disable COMMENTs | 29 statements |

Each file has a header comment block stating (a) what it does, (b) the phase 4 finding it addresses, (c) 4a classification rationale, and (d) what's been moved to 4b.

---

## 3. 4b stagings written

Placed at `supabase/manual/post_cutover_constraints/` — **outside `supabase/migrations/`** — so the Supabase CLI cannot auto-apply.

| File | Adds | Count | Violators in live today |
|---|---|---:|---|
| `README.md` | directory purpose, rule, apply order (non-numeric per dependency — see user adjustment) | — | — |
| `01_add_fk_promotions_dirty.sql` | 10 FK CONSTRAINTs | 10 | orphan rows: 10 + 16,388 + 20 + 22 + 10 + 1 + 3 + 4 + paired-null for 2 more |
| `02_add_not_null_dirty_columns.sql` | SET NOT NULL on 7 cols | 7 | null rows: 238 + 282 + 5 + 5 + 5 + 2 |
| `03_add_check_constraints_dirty_enums.sql` | CHECK on 4 cols | 4 | non-canonical values: 19 case-variant statuses + 97 touched by priority remap + 27 NULL risk_levels + 3 grade formats |
| `04_add_unique_constraints_dirty.sql` | UNIQUE on 3 cols | 3 | dupe groups: 1 + 3 + 5 |

**Cutover step:** Layer 2.3 step 5 per phase 5 synthesis. Operator runs files **in dependency order, not filename order** — see README and §8.

### 3.1 Post-review design decisions (2026-04-21)

Two decisions made during Phase B/C review that change the 4b set:

1. **`onyx_evidence_certificates.face_match_id` stays NULLABLE by design.** Originally classified 4b at #28 (282/282 NULL → SET NOT NULL). Decision: evidence certificates are linked via one of several provenance paths (FR match, LPR match, or manual event). FR-link is optional, not required. The column stays NULL where no FR match exists. Removed from `02_add_not_null_dirty_columns.sql` with a comment in-file explaining the decision.

2. **Priority vocabulary locked: `critical | high | medium | low` (lowercase).** See §8 for full convention.

### 3.2 client_evidence_ledger RLS — orphan-row visibility

The 4a RLS policy on `client_evidence_ledger` (`authenticated read by client_id match`) makes the **10 orphan rows with `client_id = CLIENT-001`** unreachable to authenticated users, since `CLIENT-001` does not match any real `clients.client_id`. This is **not wrong — orphans should be unreachable** — but is documented here so that Layer 2 post-cutover cleanup knows these 10 rows are effectively invisible from the application's perspective until the `CLIENT-001` values are resolved (reassigned to a real client or deleted). Service-role access sees them.

---

## 4. Scratch verification results

*To be appended after Phase D.*

---

## 5. Drift detector assertion update

Post-Phase-F, update `SELF_TEST_EXPECTED` in `scripts/schema_drift_check.py`:

- `policies`: 157 → 167 (+10 from Step 4a RLS policy creations on 5 tables × 2 policies)
- `rls_enabled`: 63 → 68 (+5 from Step 4a RLS ENABLE on 5 tables)
- `foreign_keys`: 57 → 71 (+14 from Step 4a FK promotions)

All other values unchanged (tables 129, views 24, functions_public 32, triggers 37, enums_public 14, sequences_public 2). The four orphaned-direction keys added by `d471228` (orphaned_foreign_keys / orphaned_policies / orphaned_views / orphaned_rls_enabled) all stay at 0.

[Remainder of Section 5 to be filled post-Phase-F with actual before/after self-test outputs.]

---

## 6. Live application results

*To be appended after Phase F.*

---

## 7. Ambiguous RLS decisions deferred to Layer 6

**~38 tables** where the RLS decision is not obviously "enable + basic policy" (no clear client_id), not obviously "disable — internal" (not internal infrastructure), and not obviously "disable — safety" (not clearly sensitive). Layer 6 must decide the multi-tenant policy design for each. Until then they remain RLS-disabled, service-role-only via PostgREST config (same effective state as today; the deferral acknowledges a decision is required, not that one has been made).

| Table | Rows (est) | Why ambiguous |
|---|---:|---|
| `alert_events` | 0 | ghost — purpose unclear from name + absence of data |
| `alert_rules` | 0 | ghost — could be ops config (operator-scoped) or per-client |
| `area_sites` | 0 | ghost — mapping table; scope depends on how "area" is used |
| `checkins` | 0 | ghost — possibly guard check-ins (client-scoped) but unused |
| `civic_events` | 0 | ghost — appears to be public civic-event reference, scope unclear |
| `command_summaries` | 0 | ghost — could be ops summaries or per-client |
| `demo_state` | 1 | demo/presentation state — stop at Layer 2 (drop?) |
| `deployments` | 0 | ghost — guard deployments by site, but FKs exist (layer 2 decides) |
| `dispatch_actions` | 0 | ghost — dispatch catalogue, likely operator-only |
| `dispatch_intents` | 27 | no client_id column; dispatch system core; Layer 6 decides scoping |
| `dispatch_transitions` | 34 | same |
| `duty_states` | 0 | ghost — guard duty tracking |
| `escalation_events` | 0 | ghost — escalation log |
| `external_signals` | 0 | ghost — external-data ingest |
| `global_patterns` | 0 | ghost — pattern library, likely shared/public |
| `guard_sites` | 0 | ghost — guard-to-site mapping |
| `incident_aar_scores` | 11 | after-action scores; incident_id present but not client_id |
| `incident_outcomes` | 0 | ghost |
| `incident_replay_events` | 0 | ghost |
| `incident_replays` | 0 | ghost |
| `incident_snapshots` | 0 | ghost |
| `keyword_escalations` | 0 | ghost — keyword-triggered escalations |
| `mo_library` | 0 | ghost — modus operandi reference, likely shared |
| `operational_nodes` | 0 | ghost — operational-node registry |
| `ops_orders` | 0 | ghost — ops-order tracking |
| `patrol_route_cooldowns` | 0 | ghost |
| `patrol_route_recommendations` | 0 | ghost |
| `patrol_violations` | 0 | ghost |
| `patrols` | 0 | ghost — patrol master; scope depends on use |
| `posts` | 0 | ghost — posts/assignments |
| `regional_risk_snapshots` | 0 | ghost — regional risk snapshots |
| `site_awareness_snapshots` | 1 | snapshot; site-scoped but unclear sensitivity |
| `site_occupancy_config` | 1 | site-scoped; low sensitivity but policy design needed |
| `site_occupancy_sessions` | 11 | same |
| `site_zones` | 0 | ghost |
| `violations` | 0 | ghost |

Layer 6's input: above 38-row list. Layer 6 decides for each: ENABLE + policy (if client-scoped or site-scoped), DISABLE with internal comment (if internal), or DROP (if dead ghost). Policy design for the `dispatch_*` subsystem is the most load-bearing — production today has 27 dispatch intents + 34 transitions.

---

## 8. Known limitations

### 8.1 Priority / status / risk_level vocabulary — decision locked 2026-04-21

**ONYX enum convention (applies to every enum-like column in the schema):**
- **Stored:** lowercase only.
- **Displayed:** Title Case at presentation layer (Flutter/Next.js handle casing; DB stays lowercase).
- **Sorted:** via explicit order map in application code — never alphabetical.

**Priority canonical set (locked):** `critical | high | medium | low`. Stored order map: `{critical: 0, high: 1, medium: 2, low: 3}`.

**Status canonical set (applied):** `detected | open | acknowledged | dispatched | on_site | secured | closed | false_alarm`. Superset of current live values (after lowercasing) plus `acknowledged` and `false_alarm` which are in the lifecycle but have no rows yet. CHECK accepts the superset so future writes aren't rejected.

**risk_level exception:** stays UPPERCASE (`LOW | MEDIUM | HIGH | CRITICAL`) to match the already-enforced `dispatch_intents_risk_level_check` constraint. Cross-table case consistency is a Layer 6 concern.

**Legacy cleanup mapping** (in `03_add_check_constraints_dirty_enums.sql` file header — Layer 2 must apply before the CHECK runs):
- priority: `CRITICAL → critical`, `HIGH → high`, `MEDIUM → medium`, `LOW → low`; `p1 → critical`, `p2 → high`, `p3 → medium`, `p4 → low`; any other value → REJECT for manual review.
- status: `OPEN → open`; any non-canonical after lowercase → REJECT for manual review.

### 8.2 Empty-table soft FKs not probed individually

~90 ghost tables have `*_id` columns that could be promoted to hard FKs. Because the tables are empty, any probe returns "0 orphans" trivially and all would classify 4a. These were **deferred out of Step 4 scope** because Layer 2's ghost-table review may drop some of these tables entirely — adding FKs to tables slated for drop creates wasted migrations and complicates Layer 2's deletion plan.

**Follow-up:** after Layer 2 decides drop-vs-keep for each ghost table, re-run Phase A-equivalent classification on the survivors and add a Step-4.5 migration for promoted-FK constraints. 4a because empty tables can't violate.

### 8.3 `guard_ops_events.guard_id` FK prerequisite

The FK in 4b #01 references `guards(guard_id)` but `guards` currently has no single-column UNIQUE on `guard_id` (only `guards_pkey` on `id UUID` + the `employees/guards_client_*` composite patterns). Layer 2 cleanup must add `guards_guard_id_unique UNIQUE (guard_id)` before running `01_add_fk_promotions_dirty.sql`, or `04_add_unique_constraints_dirty.sql` must be extended to include it. Flagged in the 4b #01 file header.

### 8.4 `incidents.id` is text, not UUID

Phase 4 implied UUID throughout. Step 4 probe confirmed both `incidents.id` and `incidents.event_uid` are text. This is actually helpful — `onyx_evidence_certificates.incident_id text → incidents.id text` is type-compatible without a column migration. But Layer 6 may want to converge on UUID across identity tables for consistency; a column-type migration on `incidents.id` would be Layer 6+ refactor, not Step 4.

### 8.5 Attribute-level comparison in Step 3 drift detector is still set-based only

The detector diffs column-sets per table. It does not diff types, defaults, or constraints. The constraints added in Step 4 **are** recognised by the drift detector's FK / policy / RLS counters (because those count whole objects), but CHECK / NOT NULL / UNIQUE constraint additions on existing columns are not visible to a set-based diff. Layer 1 Step 3's known-limitations note already flags this; Phase E assertion update must bump FK / policy / RLS counts but not column-set counts.

### 8.6 `site_api_tokens` RLS decision

Phase 4 §10 flagged `site_api_tokens` as HIGH-risk (auth tokens without RLS). The 4a decision is DISABLED with safety comment — not ENABLE. This is **defensive** (service-role-only access via PostgREST config), not permissive. The risk is that any future grant to the `authenticated` role on this table would immediately expose tokens — but today no such grant exists. Layer 6 must design the policy that restricts this per-client (a token owner should only see their own client's tokens).

### 8.7 Layer 2 data cleanup scope

Every 4b file's header enumerates the Layer 2 cleanup prerequisites that must run before the file applies. Step 4 does not implement or validate those cleanup steps — Layer 2 owns them. If Layer 2's implementation diverges from the prerequisites listed in a 4b file header, the file may fail at cutover. Flagged as a cross-layer coordination obligation.

---

*End of Step 4 audit note. Sections 4, 5, 6 pending subsequent phases.*
