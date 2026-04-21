# Layer 1 Step 3 — Schema Drift Detector (Audit Notes)

**Date:** 2026-04-21
**Artifact:** `scripts/schema_drift_check.py` + `scripts/schema_drift_check.md`
**Status:** Self-test PASSED against current live + current chain (zero drift).

This note captures design rationale, testing outcomes, and limitations that belong in the audit trail rather than the day-to-day operating doc.

## 1. Phase A — Design decisions

All seven decisions made during Phase A and baked into the script's top comment block:

1. **Credential discovery** — Reuse Step 1's path: shell out to `supabase db dump --dry-run --linked` and parse the `export PG*=...` lines. No config-file hunting, no credential logging.
2. **Live capture** — `pg_dump --schema-only` via Homebrew `postgresql@17` (matches live's PG17.6 to avoid the known version-mismatch rejection). Same flag set the Supabase CLI generates internally: `--quote-all-identifier --role postgres --exclude-schema=<Supabase internals>`.
3. **Scratch database** — `tempfile.mkdtemp` → `initdb` → `pg_ctl` on port 55432 → `createdb verify` → prep (schemas, roles, extensions, auth + storage stubs) → apply active chain → `pg_dump`. Cleanup is triple-bound: try/finally + atexit + SIGINT/SIGTERM handlers.
4. **PostGIS — Option A (fail-closed).** `CREATE EXTENSION postgis` in scratch. Live uses PostGIS, so scratch must too, otherwise geometry-type columns and PostGIS helper objects would undercount. Preflight verifies the extension is available and exits 2 with a `brew install postgis` hint if not.
5. **Auth stub set** — All three `auth.*` helpers referenced by policies: `auth.uid()`, `auth.jwt()`, `auth.role()`. Stubbed to return NULL so policies can apply without Supabase's auth service running.
6. **Report format** — Plain-text default; `--json` provides the same hierarchy for machine consumption; `--verbose` adds per-object detail; `--self-test` asserts expected counts.
7. **No enforcement.** Manual-run only. Not hooked into CI, pre-commit, or deploys. Drift resolution remains a human decision.

Two follow-up questions were also answered: fail-closed PostGIS (keep) and re-discover credentials every run (keep).

## 2. Phase C — Testing outcomes

Self-test was executed three times during development. Each finding was category-1 (script bug) not category-3 (real drift):

| Run | Finding | Category | Fix |
|-----|---------|----------|-----|
| 1 | `pg_dump` subprocess killed at 120s timeout | 1 — script bug | Bumped to 300s |
| 2 | `pg_dump` subprocess killed at 300s timeout | 1 — script bug | Bumped to 900s after direct-timing measured 8m10s (490s) wall clock |
| 3 | `missing_views: expected 0, got 1` — ghost view `guard_storage_readiness_checks` | 1 — script bug | View queries `storage.buckets`; the storage stub only had `storage.objects`. Added `storage.buckets` stub and enabled verbose apply-error logging so silent DDL failures don't masquerade as drift |
| 4 | PASSED — 129/24/157/57 on both sides, zero diff | — | — |

The run-3 failure is the important one: before the fix, the detector flagged one ghost view and the failure was indistinguishable (at the report level) from a genuine out-of-band live change. The fix that exposed this path for future runs — `--verbose` now prints baseline-apply stderr — is what makes the detector trustworthy going forward.

## 3. Self-test confirmation (Phase D)

Final run on 2026-04-21, against current live and current chain:

```
SELF-TEST PASSED — live + scratch match Step 1/Step 2 documented state.
  live:    {'tables': 129, 'views': 24, 'policies': 157, 'fks': 57}
  scratch: {'tables': 129, 'views': 24, 'policies': 157, 'fks': 57}
  zero ghost, zero orphaned, zero column drift.
```

Full expected-state assertions (all passing):
- 129 tables, 24 views, 32 public functions, 37 triggers
- 157 policies, 14 public enums, 2 public sequences
- 63 RLS-enabled tables, 57 foreign keys
- 0 ghost tables, 0 ghost columns, 0 orphaned tables, 0 orphaned columns
- 0 missing policies, 0 missing FKs, 0 missing views

These match Step 1's baseline inventory and Step 2's post-reconciliation state exactly.

## 4. Known limitations beyond the operating doc

Captured in the operating doc for day-to-day users, and here for audit completeness:

- **Attribute-level drift** is column-set only. Types/defaults/constraints are not compared. A type change won't surface. This is a deliberate Phase B boundary — implementing type comparison requires a proper SQL parser, not a regex-based extractor.
- **Supabase-managed objects** (`pg_cron`, `pg_graphql`, `supabase_vault`, `supabase_realtime` publication, PostGIS `topology` helpers) produce ~70 apply-chain error lines in scratch. All expected, none affect the compared object set. Visible with `--verbose`.
- **Storage and auth stubs** are minimal. Drift inside `storage.*` and `auth.*` is not detected — only the objects referenced by public-schema migrations need stubbing, so only those are stubbed.
- **Historical migrations excluded by design.** Pattern 2 (Step 2) places the entire pre-baseline history under `historical/` subdirectories. Only the reverse-engineered baseline is the active chain.

## 5. What the detector does not do

Explicitly out of scope (per task spec):
- Drift resolution — only detection.
- CI enforcement — manual-run only.
- Writes to live — read-only dump.
- Data comparison — schema only.
- Migration authoring — a human writes the migration if drift is intentional.

These boundaries matter because the ghost-schema problem was caused in part by tools that tried to do too much. This detector's job is to print a list and exit.

## 6. Operating contract

- **Run cadence:** manual, on demand. Typical triggers listed in the operating doc.
- **Runtime budget:** ~15 min per run. The live `pg_dump` over the pooler dominates; the scratch side is ~2–3 min.
- **Cache:** none. Fresh dumps each run, scratch DB torn down on exit.
- **Credentials:** discovered per-run from the Supabase CLI's stored state. No persistent secret in the script or the repo.

## 7. Follow-ups (not blocking this step)

- Attribute-level diff (types/defaults/constraints) — Phase B.
- Storage and auth schema drift detection — would require reproducing more of the Supabase-managed bootstrap in scratch.
- Delta-based self-test expectations — current `SELF_TEST_EXPECTED` will need updating when the baseline changes (e.g. a new migration is added and captured). Document the update procedure alongside any baseline edit.
