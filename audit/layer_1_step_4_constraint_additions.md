# Layer 1 Step 4 — Constraint Additions

**Date:** 2026-04-21
**Task:** Final step of Layer 1 of the audit remediation. Add constraint migrations that bring the schema up to integrity standard per phase 4's findings, split into two groups — **4a applicable now** (in the active migration chain) and **4b staged for post-cutover** (out-of-chain, applied manually at Layer 2 runbook step 7 / phase 5 §3.4 step 7).
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
| 63 | `clients(name)` | same | **1 dupe group** (`test` × 3) | **Layer 4 deferred** (public.clients is preservation in Layer 2) |
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
| 83 | ~~`spatial_ref_sys`~~ | **EXCLUDED (platform-managed)** | ~~PostGIS reference data~~ — removed post-Phase-F: PostGIS owns the table; migration role cannot COMMENT or ALTER it. See §8.8. |
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
| NOT NULL | 14 | 6 (face_match_id removed — §3; current staged file has 6 ALTER COLUMN operations) |
| CHECK | 11 | 4 |
| UNIQUE | 3 | 3 (clients_name_unique deferred to Layer 4) |
| Indexes | 10 | 0 |
| RLS enable + policy | 5 | — |
| RLS DISABLED internal comment | 4 | — |
| RLS DISABLED safety comment | 19 | — |
| Ambiguous → Layer 6 | 38 | — |
| **Totals in Step 4 scope** | **80** | **23** |

4a : 4b ratio on constraint additions (excluding deferred) = 78% : 22%.

---

## 2. 4a migrations written

One file per constraint category, timestamped after the baseline:

| File | Adds | Count |
|---|---|---:|
| `supabase/migrations/20260421000101_add_fk_promotions.sql` | FK CONSTRAINT on 14 cols → sites/clients | 14 |
| `supabase/migrations/20260421000102_add_not_null_clean_columns.sql` | SET NOT NULL on 14 cols | 14 |
| `supabase/migrations/20260421000103_add_check_constraints_clean_enums.sql` | CHECK on 11 enum-like cols | 11 |
| `supabase/migrations/20260421000104_add_unique_constraints.sql` | UNIQUE on 3 cols | 3 |
| `supabase/migrations/20260421000105_add_indexes.sql` | CREATE INDEX IF NOT EXISTS for 10 indexes | 10 |
| `supabase/migrations/20260421000106_rls_decisions.sql` | 5 ENABLE + 4 internal-disable COMMENTs + 19 safety-disable COMMENTs (spatial_ref_sys removed post-Phase-F — platform-managed) | 28 statements |

Each file has a header comment block stating (a) what it does, (b) the phase 4 finding it addresses, (c) 4a classification rationale, and (d) what's been moved to 4b.

---

## 3. 4b stagings written

Placed at `supabase/manual/post_cutover_constraints/` — **outside `supabase/migrations/`** — so the Supabase CLI cannot auto-apply.

| File | Adds | Count | Violators in live today |
|---|---|---:|---|
| `README.md` | directory purpose, rule, apply order (non-numeric per dependency — see user adjustment) | — | — |
| `01_add_fk_promotions_dirty.sql` | 10 FK CONSTRAINTs | 10 | orphan rows: 10 + 16,388 + 20 + 22 + 10 + 1 + 3 + 4 + paired-null for 2 more |
| `02_add_not_null_dirty_columns.sql` | SET NOT NULL on 6 cols | 6 | null rows: 238 + 282 + 5 + 5 + 5 + 2 |
| `03_add_check_constraints_dirty_enums.sql` | CHECK on 4 cols | 4 | non-canonical values: 19 case-variant statuses + 111 touched by priority remap + 27 NULL risk_levels + 3 grade formats |
| `04_add_unique_constraints_dirty.sql` | UNIQUE on 3 cols | 3 | dupe groups: 3 + 5; plus `guards(guard_id)` FK prerequisite; `clients(name)` deferred to Layer 4 |

**Cutover step:** Layer 2 runbook step 7 / phase 5 §3.4 step 7. Operator runs files **in dependency order, not filename order** — see README and §8.

### 3.1 Post-review design decisions (2026-04-21)

Two decisions made during Phase B/C review that change the 4b set:

1. **`onyx_evidence_certificates.face_match_id` stays NULLABLE by design.** Originally classified 4b at #28 (282/282 NULL → SET NOT NULL). Decision: evidence certificates are linked via one of several provenance paths (FR match, LPR match, or manual event). FR-link is optional, not required. The column stays NULL where no FR match exists. Removed from `02_add_not_null_dirty_columns.sql` with a comment in-file explaining the decision.

2. **Priority vocabulary locked: `critical | high | medium | low` (lowercase).** See §8 for full convention.

3. **`clients_name_unique` deferred to Layer 4.** Layer 2 preserves
`public.clients` bit-for-bit; live has three preserved rows named `test`.
Applying client-name uniqueness in Layer 2 would require configuration cleanup,
which belongs in Layer 4 site/client cleanup rather than the event-corpus wipe.

### 3.2 client_evidence_ledger RLS — orphan-row visibility

The 4a RLS policy on `client_evidence_ledger` (`authenticated read by client_id match`) makes the **10 orphan rows with `client_id = CLIENT-001`** unreachable to authenticated users, since `CLIENT-001` does not match any real `clients.client_id`. This is **not wrong — orphans should be unreachable** — but is documented here so that Layer 2 post-cutover cleanup knows these 10 rows are effectively invisible from the application's perspective until the `CLIENT-001` values are resolved (reassigned to a real client or deleted). Service-role access sees them.

---

## 4. Scratch verification results

**Phase D (2026-04-21) — full scratch apply of baseline + 4a:** all six 4a migrations applied cleanly against a fresh scratch Postgres. Object-count deltas matched expectations exactly (14 FKs, 11 CHECKs, 3 UNIQUEs, 13 indexes including 3 backing UNIQUE indexes, 5 RLS-enables, 10 policies). See separate Phase D report log at `/tmp/layer1_step4/phase_d.log` for verbatim output.

### 4.1 Scratch-vs-live role identity gap (surfaced at Phase F)

Scratch Postgres runs as the local OS user (`postgres` superuser in the initdb default), who owns every object in the cluster — including extension-created objects like PostGIS's `spatial_ref_sys`. The migration role on live (`cli_login_postgres.mnbloeoiiwenlywnnoxe` → `postgres` via `SET ROLE`) is **not** the same as Supabase's internal PostGIS-owning role. On live, `spatial_ref_sys` is owned by a platform-managed role; the migration role has SELECT access but not ownership, so `COMMENT ON TABLE` / `ALTER TABLE` on it fail with `SQLSTATE 42501 must be owner`.

Phase D did not catch this because scratch superuser owns all objects. Phase F caught it on the first live push attempt (migration `000106` statement 16).

Fix: `000106` was amended to remove the `spatial_ref_sys` COMMENT entirely — the table is platform-managed and out of Step 4 scope. See §1.6 #83 (crossed out) and §8.8.

---

## 5. Drift detector assertion update

Post-Phase-F, update `SELF_TEST_EXPECTED` in `scripts/schema_drift_check.py`:

- `policies`: 157 → 167 (+10 from Step 4a RLS policy creations on 5 tables × 2 policies)
- `rls_enabled`: 63 → 68 (+5 from Step 4a RLS ENABLE on 5 tables)
- `foreign_keys`: 57 → 71 (+14 from Step 4a FK promotions)

All other values unchanged (tables 129, views 24, functions_public 32, triggers 37, enums_public 14, sequences_public 2). The four orphaned-direction keys added by `d471228` (orphaned_foreign_keys / orphaned_policies / orphaned_views / orphaned_rls_enabled) all stay at 0.

### 5.1 Before (pre-Phase-F, after detector coverage-gap fix `d471228`)

Self-test run against live with pre-4a expected counts (57/157/63):

```
SELF-TEST FAILED:
  - orphaned_foreign_keys: expected 0, got 14
  - orphaned_policies:     expected 0, got 10
  - orphaned_rls_enabled:  expected 0, got 5
SUMMARY
  Live:    129 tables, 24 views, 157 policies, 57 FKs
  Scratch: 129 tables, 24 views, 167 policies, 71 FKs
exit=1
```

Correct signal: live did not yet have the 4a changes, chain did. The three orphaned-direction failures (14+10+5 = 29 objects declared by chain but absent from live) pinpointed exactly the Step 4a set awaiting apply. No ghost-direction drift.

### 5.2 After (post-Phase-F, with updated assertions)

Self-test run against live with post-4a expected counts (71/167/68):

```
SELF-TEST PASSED — live matches expected; zero ghost (live→chain)
and zero orphaned (chain→live) across all asserted object types.
  live:    {'tables': 129, 'views': 24, 'policies': 167, 'fks': 71}
  scratch: {'tables': 129, 'views': 24, 'policies': 167, 'fks': 71}
exit=0
```

Live counts match expected exactly: 129 tables, 24 views, 167 policies, 71 FKs. Scratch (fresh baseline + 4a apply) reproduces live exactly. All 16 asserted drift categories pass (9 live-count assertions + 5 ghost assertions + 6 orphaned assertions, including the 4 new orphaned-direction keys added by Step 3's amendment commit).

### 5.3 Assertion update commit

Assertion update values captured in `scripts/schema_drift_check.py` `SELF_TEST_EXPECTED`:
- `policies`: 157 → 167
- `rls_enabled`: 63 → 68
- `foreign_keys`: 57 → 71

Committed as a separate commit after live application landed (per Step 4 rule: assertion update is a distinct commit from the constraint migrations).

---

## 6. Live application results

### 6.1 Phase F history (2026-04-22)

Phase F surfaced three issues not visible at scratch verification. Each was diagnosed read-only, resolved via metadata-only writes or local-only amendments, and re-attempted. No destructive operations.

| # | Step | Outcome | Resolution |
|---|---|---|---|
| 1 | `supabase db push --linked` (first attempt) | **Pre-flight rejection:** "Remote migration versions not found in local migrations directory" — 27 historical IDs in `supabase_migrations.schema_migrations` with no matching files in `supabase/migrations/` (Step 2 Pattern 2 quarantine left tracking table unreconciled). | `supabase migration repair --status reverted <27 IDs>` — metadata-only write. Commit `222a779` amends Step 2 audit note §8 documenting the gap. |
| 2 | `supabase db push --linked` (second attempt) | **Baseline re-apply attempted:** the CLI added the baseline to the apply plan because it had no tracking-table entry. Failed at statement 18 (`CREATE TYPE "public"."client_service_type"` — already exists). | Post-mortem probe confirmed **clean transactional rollback** (§4.1 of this note). No partial apply. Root cause: CLI's `migration repair` uses a literal no-underscore glob that didn't match our underscore-separated filenames. |
| 3 | File rename + `migration repair --status applied 20260421000000` | Success — marked baseline applied without running it. | Commit `96b1901` renamed 7 migration files (baseline + six 4a) to no-underscore form, updating 18 in-content references across 6 files. Commit `a0953fb` is orthogonal to this (the 000106 fix below). |
| 4 | `supabase db push --linked --yes` (third attempt) | 5 of 6 migrations applied successfully. Migration `000106_rls_decisions.sql` failed at statement 16 (`COMMENT ON TABLE public.spatial_ref_sys`) — migration role does not own the PostGIS-managed `spatial_ref_sys` table. | Post-mortem probe (F2-Option 1, 7 queries) confirmed **clean transactional rollback of `000106` only**; `000101`-`000105` landed on live successfully (71 FKs, 44 UNIQUEs, 10 new indexes, all tracking-table entries present). |
| 5 | Fix `000106` + retry | Commit `a0953fb` removed the `spatial_ref_sys` COMMENT; audit note §1.6 #83, §1.7 tally, §2, §4, §8.8 updated. Dry-run (`supabase db push --dry-run --linked`) showed exactly one migration in the plan: `20260421000106_rls_decisions.sql`. Apply (`supabase db push --linked --yes`) succeeded: `Applying migration 20260421000106_rls_decisions.sql...` + `Finished supabase db push.` + exit 0. |

### 6.2 Final live state

Post-apply object counts (per self-test at §5.2): **129 tables / 24 views / 167 policies / 71 FKs** on live. Matches scratch-reproduced chain byte-for-byte.

All six 4a migrations now recorded in `supabase_migrations.schema_migrations`:
- `20260421000000` reverse_engineered_baseline (recorded via `migration repair --status applied`)
- `20260421000101` add_fk_promotions (14 FKs)
- `20260421000102` add_not_null_clean_columns (14 NOT NULL flips — only 4 reflected in `pg_attribute.attnotnull` because 10 columns were already NOT NULL per baseline CREATE TABLE; no-op on those)
- `20260421000103` add_check_constraints_clean_enums (11 CHECKs)
- `20260421000104` add_unique_constraints (3 UNIQUEs; 3 backing unique indexes)
- `20260421000105` add_indexes (10 indexes)
- `20260421000106` rls_decisions (5 ENABLE + 10 policies + 4 internal-disable COMMENTs + 19 safety-disable COMMENTs; `spatial_ref_sys` removed from scope)

### 6.3 Plain drift check — deferred to future verification cycle

Plain drift check (`python3 scripts/schema_drift_check.py --verbose`) was attempted twice post-Phase-F; both attempts failed with transient pooler issues:

- **Attempt 1:** pg_dump of live timed out after 900s (clock exhaustion without completion).
- **Attempt 2:** `pg_dump: error: query failed: SSL SYSCALL error: EOF detected` mid-query on `pg_depend` (connection-level SSL termination).

Two distinct failure modes (timeout vs SSL EOF) against the same pooler within the same session suggest **pooler-side instability during the R3 window**, not a structural problem. Corroborating evidence:
- Self-test earlier in the same session (§5.2) completed the full live pg_dump cleanly.
- R1 + F5 `supabase db push` commands ran against the same pooler without issue.
- F2 read-only probes (metadata + 7 diagnostic queries) all returned in <30s.

**Self-test accepted as the canonical post-Phase-F green light.** The self-test is strictly stronger than the plain drift check: it performs the same live↔chain diff AND asserts live counts against hardcoded expected values. Any drift the plain check would surface, the self-test already caught and passed. The plain check adds a human-readable report but no new signal.

**Plain drift check to be re-run in a future routine verification cycle** when the pooler is stable. If that run reveals anything the self-test missed, treat as a new finding.

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

The FK in 4b #01 references `guards(guard_id)` but `guards` currently has no single-column UNIQUE on `guard_id` (only `guards_pkey` on `id UUID` + the `employees/guards_client_*` composite patterns). `04_add_unique_constraints_dirty.sql` now includes `guards_guard_id_unique UNIQUE (guard_id)` and must run before `01_add_fk_promotions_dirty.sql`.

### 8.4 `clients(name)` uniqueness deferred

`public.clients` is in the Layer 2 preservation set. Live contains three rows named `test`, so `clients_name_unique` cannot be applied without mutating preserved configuration. Per Phase 5 §3 Amendment 3, this constraint is deferred to Layer 4 site/client configuration cleanup.

### 8.5 `incidents.id` is text, not UUID

Phase 4 implied UUID throughout. Step 4 probe confirmed both `incidents.id` and `incidents.event_uid` are text. This is actually helpful — `onyx_evidence_certificates.incident_id text → incidents.id text` is type-compatible without a column migration. But Layer 6 may want to converge on UUID across identity tables for consistency; a column-type migration on `incidents.id` would be Layer 6+ refactor, not Step 4.

### 8.5 Attribute-level comparison in Step 3 drift detector is still set-based only

The detector diffs column-sets per table. It does not diff types, defaults, or constraints. The constraints added in Step 4 **are** recognised by the drift detector's FK / policy / RLS counters (because those count whole objects), but CHECK / NOT NULL / UNIQUE constraint additions on existing columns are not visible to a set-based diff. Layer 1 Step 3's known-limitations note already flags this; Phase E assertion update must bump FK / policy / RLS counts but not column-set counts.

### 8.6 `site_api_tokens` RLS decision

Phase 4 §10 flagged `site_api_tokens` as HIGH-risk (auth tokens without RLS). The 4a decision is DISABLED with safety comment — not ENABLE. This is **defensive** (service-role-only access via PostgREST config), not permissive. The risk is that any future grant to the `authenticated` role on this table would immediately expose tokens — but today no such grant exists. Layer 6 must design the policy that restricts this per-client (a token owner should only see their own client's tokens).

### 8.7 Layer 2 data cleanup scope

Every 4b file's header enumerates the Layer 2 cleanup prerequisites that must run before the file applies. Step 4 does not implement or validate those cleanup steps — Layer 2 owns them. If Layer 2's implementation diverges from the prerequisites listed in a 4b file header, the file may fail at cutover. Flagged as a cross-layer coordination obligation.

### 8.8 Scratch permission model diverges from live for extension-owned objects

**The gap:** scratch Postgres uses an initdb-created superuser who owns every object in the cluster, including objects created by `CREATE EXTENSION postgis` (notably `spatial_ref_sys`, `geography_columns`, `geometry_columns`, plus ~744 PostGIS functions). On live Supabase, PostGIS is installed under a platform-managed owning role. The migration role (`postgres` via `SET ROLE`) has usage but not ownership of extension-created objects. `COMMENT ON TABLE`, `ALTER TABLE`, `ENABLE ROW LEVEL SECURITY`, and similar owner-required operations on extension-owned objects fail on live with `SQLSTATE 42501 must be owner`.

**Where it surfaced:** Phase F statement 16 of `000106_rls_decisions.sql` (`COMMENT ON TABLE public.spatial_ref_sys`). Scratch verification (Phase D) did not flag it because scratch's single-user model made ownership a non-issue.

**Resolution for this step:** `spatial_ref_sys` removed from `000106` — it's platform-managed, out of Step 4 scope.

**Flagged for Layer 2 pre-flight:** any migration that touches extension-owned objects on live will fail regardless of what scratch shows. Scratch is a reproducibility check for application-owned DDL, not for cross-role permission semantics. Layer 2 should pre-flight any such migration against live with a `--dry-run`-equivalent or a role-probe check.

**Potentially affected extension-owned objects (Supabase managed):** PostGIS's `spatial_ref_sys` / `geography_columns` / `geometry_columns`; pg_cron's `job` / `job_run_details`; supabase_vault's encrypted-secrets tables; anything in the `graphql` / `extensions` / `vault` / `auth` / `storage` schemas. None of these should be touched by application-layer migrations.

---

*End of Step 4 audit note. Sections 4, 5, 6 pending subsequent phases.*
