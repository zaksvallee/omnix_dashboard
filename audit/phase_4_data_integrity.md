# ONYX Platform — Phase 4 Data Integrity Audit

**Date:** 2026-04-21
**Scope:** integrity of data in the Supabase `public` schema — orphaned rows, schema drift, value inconsistencies, timestamp anomalies, FK coverage, null-integrity, duplicates, orphaned blobs, origin anomalies, RLS coverage.
**Out of scope:** backend capability verification (phase 2a), feature verification (phase 2b), schema design critique, performance, migration quality, RLS logic correctness. Fix-work for the six daylight tasks is also out of scope — this audit flags, it does not remediate.

---

## 0. Access confirmation and input review

| Target | Method | Result |
|---|---|---|
| Supabase PostgREST (service-role) | curl with key from `config/onyx.local.json` | ok — read + count-exact queries work |
| Supabase CLI direct DB access | `supabase db dump / pull / push` all require Docker (not installed) | **unavailable** — same gap as phase 2a §0. Workaround: all live-data queries are made via PostgREST. Column types, NOT-NULL constraints, default values, RLS flags, and FK declarations are inferred from migration SQL and cross-referenced against live PostgREST shape — flagged inline in each finding where this is load-bearing. |
| `supabase/migrations/` | read | 44 files (2026-03-04 → 2026-04-17) |
| `deploy/supabase_migrations/` | read | 10 additional files (2026-04-13 → 2026-04-14) — the parallel migration set flagged in phase 1a §3.2 |
| `supabase/manual/` + `supabase/sql/` + `supabase/verification/` | read | 7 SQL helper / validation files |
| `psql` (local) | `/opt/homebrew/bin/psql` 16.13 | available but no DB connection string; Supabase direct-connect password not in local config |
| Phase 2a §6 (data layer verification) | re-read | ok |
| Phase 2b §6.2 (operationally significant findings) | re-read | ok |

**Current HEAD:** `omnix_dashboard/main` → `37c7760` (phase 2b §3–§6 + roll-up).

**Access gaps carried forward from phase 2a:**
- No direct psql / pg_dump of live schema. FK enforcement, RLS flags, default values, and system-catalogue constraints are inferred from migration SQL or from PostgREST response shape — not verified against `information_schema` / `pg_constraint`.
- `auth.users` is readable via `/auth/v1/admin/users` with service-role key (used in phase 2b §4); other `auth.*` tables not accessible.
- Supabase storage bucket *contents* listable via `/storage/v1/bucket` + `/storage/v1/object/list/<bucket>`; per-row storage-file mapping requires application knowledge (no direct catalog).

---

## 1. Orphaned rows

### 1.1 Method

`orphaned` = a row in a child table whose FK column value does not appear in the parent table's primary-key (or equivalent business-key) column.

Schema declares only **3 explicit FK constraints** (`REFERENCES public.<parent>(id)`), all within the `20260410_create_guard_patrol_system.sql` migration:

| Child | Column | Parent | On delete |
|---|---|---|---|
| `patrol_routes.checkpoints` | (implicit inline in the create stmt) | `patrol_checkpoints.id` | not specified |
| `patrol_compliance.route_id` | uuid | `patrol_routes.id` | not specified |
| `patrol_scans.checkpoint_id` | uuid | `patrol_checkpoints.id` | not specified |

Plus one later:
- `zara_action_log.scenario_id text not null references public.zara_scenarios(id) on delete cascade` — `202604170002_zara_action_log.sql`.

All four of these parent tables are currently empty per phase 2a §6.2 (patrol_* + zara_* all 0 rows) — there are no child rows to be orphaned.

**172 soft FK columns** (any column named `*_id` in migrations) exist without constraints. Orphan-probe across the soft-FK surface below.

### 1.2 Soft-FK orphan probes (populated child tables only)

Query template (via PostgREST):
```
GET /rest/v1/<child_table>?select=<fk_col>&order=<fk_col>.asc   → distinct child FK values
GET /rest/v1/<parent_table>?select=<pk_col>                     → parent PKs
# Python: len(set(child_fk) - set(parent_pk))                   → orphan count
```

Tables with non-zero row counts that carry soft FKs (from phase 1a §3.3):

| Child | FK column | Parent (conventional) | Child rows | Orphan count | Sample orphan values | Likely cause |
|---|---|---|---:|---:|---|---|
| `site_alarm_events` | `site_id` | `sites.site_id` (text) | 11,220 | **see §1.3** | — | probed below |
| `site_alarm_events` | `client_id` | `clients.client_id` (text) | 11,220 | **see §1.3** | — | probed below |
| `incidents` | `site_id` | `sites.site_id` | 241 | **see §1.3** | — | probed below |
| `incidents` | `client_id` | `clients.client_id` | 241 | **see §1.3** | — | probed below |
| `client_evidence_ledger` | `client_id` | `clients.client_id` | 16,388 | **see §1.3** | — | probed below |
| `client_evidence_ledger` | `dispatch_id` | `dispatch_current_state.dispatch_id` | 16,388 | **see §1.3** | — | probed below |
| `onyx_evidence_certificates` | `site_id` / `client_id` / `camera_id` / `event_id` / `incident_id` / `face_match_id` / `zone_id` | various | 282 | **see §1.3** | — | probed below |
| `fr_person_registry` | `site_id` | `sites.site_id` | 5 | **see §1.3** | — | probed below |
| `telegram_inbound_updates` | `chat_id` | (Telegram-native — no parent in this DB) | 98 | n/a | — | external identifier — not a DB relationship |
| `client_conversation_messages` | `client_id` | `clients.client_id` | 20 | **see §1.3** | — | probed below |
| `client_conversation_acknowledgements` | `client_id` / `message_id` | `clients` / `client_conversation_messages` | 22 | **see §1.3** | — | probed below |
| `employee_site_assignments` | `employee_id` / `site_id` | `employees` / `sites` | 6 | **see §1.3** | — | probed below |
| `guard_ops_events` | `guard_id` / `site_id` / `client_id` | `guards` / `sites` / `clients` | 3 | **see §1.3** | — | probed below |
| `site_camera_zones` | `site_id` | `sites.site_id` | 16 | **see §1.3** | — | probed below |
| `site_occupancy_config` | `site_id` | `sites.site_id` | 1 | **see §1.3** | — | probed below |
| `site_occupancy_sessions` | `site_id` | `sites.site_id` | 10 | **see §1.3** | — | probed below |
| `site_alert_config` | `site_id` | `sites.site_id` | 1 | **see §1.3** | — | probed below |
| `site_api_tokens` | `site_id` | `sites.site_id` | 2 | **see §1.3** | — | probed below |
| `site_intelligence_profiles` | `site_id` | `sites.site_id` | 1 | **see §1.3** | — | probed below |
| `site_expected_visitors` | `site_id` | `sites.site_id` | 2 | **see §1.3** | — | probed below |
| `client_messaging_endpoints` | `client_id` | `clients.client_id` | 1 | **see §1.3** | — | probed below |
| `client_conversation_push_queue` | `client_id` | `clients.client_id` | 11 | **see §1.3** | — | probed below |
| `client_conversation_push_sync_state` | `client_id` | `clients.client_id` | 2 | **see §1.3** | — | probed below |
| `guard_ops_retention_runs` | — | n/a (aggregate) | 1 | n/a | — | — |
| `guard_ops_replay_safety_checks` | — | n/a (aggregate) | 1 | n/a | — | — |
| `guard_projection_retention_runs` | — | n/a (aggregate) | 2 | n/a | — | — |
| `onyx_power_mode_events` | `site_id` / `client_id` | `sites` / `clients` | 31 | **see §1.3** | — | probed below |
| `onyx_evidence_certificates` (detailed) | see above | see above | 282 | detailed below | — | — |
| `dispatch_current_state` | `incident_id` (text) | `incidents.id` | 27 | **see §1.3** | — | probed below |
| `dispatch_intents` | (TBD — schema text) | — | 27 | unknown | — | schema not inspected in this pass |
| `dispatch_transitions` | `dispatch_id` | `dispatch_current_state.dispatch_id` | 34 | **see §1.3** | — | probed below |

### 1.3 Parent-table shape — critical context

PostgREST probe of parent tables reveals that every parent carries **both** a UUID `id` (database PK) **and** a text business-key column (e.g. `clients.client_id` = `CLIENT-MS-VALLEE`, `sites.site_id` = `WTF-MAIN`, `guards.guard_id` = `GRD-001`). Parent-universe = UUID-set **∪** business-key-set. All orphan probes below accept either form as "resolvable."

```
clients: 9 rows — client_ids = {CLIENT-MS-VALLEE, CLT-001, CLT-002,
  00553da4-..., 6459f24d-..., 72981787-..., 74780962-..., e94025b0-..., f51762bc-...}
  (3 rows named "test" carry UUID-format client_ids; pollution already visible)
sites: 8 rows — site_ids = {WTF-MAIN, WTF-SOUTH, BLR-MAIN, SITE-MS-VALLEE-RESIDENCE,
  MELROSE-ARCH, SANDTON-CBD, RIDGEWAY-AREA, LENASIA-AREA}
  (4 of 8 sites have client_id = `00553da4-...` which belongs to a client named "test")
guards: 12 rows — each of 3 real guards (Thabo, Sipho, Lerato) appears TWICE —
  once as GRD-001/002/003 (is_active=false) and once as GRD-<UUID-hex> (is_active=true).
  Plus 5 rows with guard_id=UUID and client_id=NULL/primary_site_id=NULL/full_name=NULL.
employees: 6 rows; incidents: 241 rows.
```

### 1.4 Orphan probe — evidence

Full PostgREST paginated scans (`?limit=1000&offset=...` until exhausted), set-diff in Python against parent (UUID ∪ business-key) union.

| Child table | FK column | Rows (non-null) | Null FK | Distinct FK values | Orphan distinct values | Orphan rows | Sample orphan values | Likely cause |
|---|---|---:|---:|---:|---:|---:|---|---|
| `site_alarm_events` | `site_id` | 11,222 | 0 | 1 (`SITE-MS-VALLEE-RESIDENCE`) | 0 | 0 | — | — |
| `incidents` | `site_id` | 3 | **238** | 3 | 0 | 0 | — | **238 rows have NULL `site_id`** (98.8% of the table) — see §7 for null integrity |
| `onyx_evidence_certificates` | `site_id` | 282 | 0 | 1 | 0 | 0 | — | — |
| `fr_person_registry` | `site_id` | 5 | 0 | 1 | 0 | 0 | — | — |
| `site_camera_zones` | `site_id` | 16 | 0 | 1 | 0 | 0 | — | — |
| `site_occupancy_config` | `site_id` | 1 | 0 | 1 | 0 | 0 | — | — |
| `site_occupancy_sessions` | `site_id` | 11 | 0 | 1 | 0 | 0 | — | — |
| `site_alert_config` | `site_id` | 1 | 0 | 1 | 0 | 0 | — | — |
| `site_api_tokens` | `site_id` | 2 | 0 | 1 | 0 | 0 | — | — |
| `site_intelligence_profiles` | `site_id` | 1 | 0 | 1 | 0 | 0 | — | — |
| `site_expected_visitors` | `site_id` | 2 | 0 | 1 | 0 | 0 | — | — |
| `employee_site_assignments` | `site_id` | 6 | 0 | 3 | 0 | 0 | — | — |
| `onyx_power_mode_events` | `site_id` | 31 | 0 | 1 | 0 | 0 | — | — |
| `incidents` | `client_id` | 241 | 0 | 3 | 0 | 0 | — | — |
| `onyx_evidence_certificates` | `client_id` | 282 | 0 | 1 | 0 | 0 | — | — |
| `client_evidence_ledger` | `client_id` | 16,388 | 0 | 2 | **1** | **10** | `CLIENT-001` × 10 rows | `CLIENT-001` is not in `clients` table (only `CLIENT-MS-VALLEE` is the text form). Likely seed / legacy |
| `client_conversation_messages` | `client_id` | 20 | 0 | 1 | **1** | **20 (100%)** | `CLIENT-001` × 20 | every row orphaned — entire table references non-existent client |
| `client_conversation_acknowledgements` | `client_id` | 22 | 0 | 1 | **1** | **22 (100%)** | `CLIENT-001` × 22 | same — entire table orphaned |
| `client_conversation_push_queue` | `client_id` | 11 | 0 | 2 | **1** | **10 (91%)** | `CLIENT-001` × 10 | same pattern |
| `client_conversation_push_sync_state` | `client_id` | 2 | 0 | 2 | **1** | **1** | `CLIENT-001` × 1 | same pattern |
| `client_messaging_endpoints` | `client_id` | 1 | 0 | 1 | 0 | 0 | — | — |
| `guard_ops_events` | `guard_id` | 3 | 0 | 1 | **1** | **3 (100%)** | **`guard_actor_contract`** × 3 | literal string value, not an ID — matches the filename `supabase/sql/guard_actor_contract_checks.sql`. Test-harness pollution in a production table. |
| `onyx_evidence_certificates` | `incident_id` | 0 | **282** | 0 | 0 | 0 | — | **282/282 evidence certs have NULL `incident_id`** — certs never linked to incidents; see §7 |
| `onyx_evidence_certificates` | `face_match_id` | 0 | **282** | 0 | 0 | 0 | — | 282/282 NULL — consistent with phase 2a §1.2 (0 FR matches in window) |
| `dispatch_current_state` | `incident_id` | 0 | **27** | 0 | 0 | 0 | — | **27/27 dispatch rows have NULL `incident_id`** — dispatches never tied back to incidents |
| `dispatch_transitions` | `dispatch_id` | 34 | 0 | 27 | 0 | 0 | — | (FK is hard-enforced per migration? no — but coincidentally clean) |
| `client_evidence_ledger` | `dispatch_id` | **16,388** | **0** | **16,388** | **16,388** | **16,388 (100%)** | `DSP-0`, `DSP-1`, `DSP-1772725119216`, `DSP-2`, `INTEL-INT-50d52b2a14d5f79661c9` (sample) | **EVERY ledger row has an orphan `dispatch_id`.** Ledger uses a business-key convention (`DSP-*` for dispatches, `INTEL-*` for intelligence-provenance) that does not match `dispatch_current_state.dispatch_id` (UUID format, only 27 rows). The `dispatch_id` column is overloaded as a polymorphic reference and the actual target table differs per row type — no FK is valid in the general case |

**Additional finding: `onyx_evidence_certificates.camera_id` — no resolvable parent.** Sample values are text `"3","4","5","6","9","12","14","15","16"`. The naming suggests it should reference `site_camera_zones` — but `site_camera_zones` uses a column named `channel_id` (type `int`), not `camera_id`, so there is no text-column anywhere for these values to resolve against. Practical consequence: camera_id is a free-text field with no referential integrity enforceable even conventionally.

### 1.5 Section 1 summary

- **3 hard FK constraints** declared in migrations; all 3 target tables currently empty → no hard-FK orphans possible.
- **172 soft FK columns** (named `*_id` without constraint). Orphan probe covered ~25 FK relationships in tables with non-zero rows.
- **Orphaned rows found:**

| Severity (observable impact) | Finding |
|---|---|
| **high** — 100% orphan | `client_evidence_ledger.dispatch_id` — all 16,388 rows reference non-existent dispatch IDs (business-key vs UUID mismatch). Any v2 `/dispatches` drill-down from `/ledger` will break |
| **high** — 100% orphan | `client_conversation_messages.client_id` — all 20 rows point at `CLIENT-001` which doesn't exist |
| **high** — 100% orphan | `client_conversation_acknowledgements.client_id` — all 22 rows same |
| **high** — 100% orphan | `guard_ops_events.guard_id` — all 3 rows have literal value `guard_actor_contract` (test pollution) |
| **medium** — 91% orphan | `client_conversation_push_queue.client_id` — 10 of 11 rows |
| **medium** — 10 rows orphan | `client_evidence_ledger.client_id` — 10 of 16,388 use `CLIENT-001` |
| **low** | `client_conversation_push_sync_state.client_id` — 1 of 2 |

*§2–§11 pending.*
