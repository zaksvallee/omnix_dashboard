# Schema Drift Check — Operating Doc

Manual detector for divergence between the live Supabase schema and the active migration chain (`supabase/migrations/*.sql`, excluding `historical/`). Prevents the ghost-schema problem (phase 4 §2, Step 1 inventory §1) from recurring.

**Scope.** Detect only. Does not resolve drift, does not write to live, does not run in CI. If it reports drift, a human resolves it before any further schema work.

## Prerequisites

- `supabase` CLI authenticated: `supabase login` + `supabase link --project-ref <ref>`. Credentials are discovered via `supabase db dump --dry-run --linked` each run (no file parsing, no credential hunting).
- Homebrew `postgresql@17` on `$PATH` at `/opt/homebrew/opt/postgresql@17/bin/` (server runs PG17; PG16 client is rejected with version-mismatch).
- Homebrew `postgis` installed (`brew install postgis`). Preflight fails closed if PostGIS is not installable in the scratch DB (Phase A decision — live uses PostGIS, so scratch must too, otherwise the comparison would undercount objects).
- Python 3.9+ (stdlib only, no third-party packages).
- Write access to `/tmp` for the scratch tempdir (auto-cleaned on exit).

## Usage

```bash
# plain-text report (default)
python3 scripts/schema_drift_check.py

# + per-object detail (also prints apply-chain errors from scratch)
python3 scripts/schema_drift_check.py --verbose

# machine-readable output, same hierarchy as the text report
python3 scripts/schema_drift_check.py --json

# assert expected baseline state (for post-migration verification)
python3 scripts/schema_drift_check.py --self-test

# fail faster while testing connectivity or operator UX
python3 scripts/schema_drift_check.py --self-test --live-dump-timeout 60
```

**Exit codes:**
- `0` — clean (zero drift)
- `1` — drift detected (report lists findings)
- `2` — error (preflight or provision failure; no comparison attempted)

**Runtime:** ~15 minutes. The live `pg_dump` over the Supabase pooler dominates (~8 min for a 129-table schema). Scratch provisioning + baseline apply + scratch dump + diff adds ~2–3 min. The script prints a `[live] starting pg_dump --schema-only` progress line before the long live dump; use a positive `--live-dump-timeout <seconds>` only when intentionally shortening or extending that wait.

## Output interpretation

The report has three sections:

1. **SUMMARY** — object counts per side (tables, views, policies, FKs). First-line sanity check.
2. **GHOST OBJECTS** — things present in **live** but not produced by the active chain. This is the ghost-schema signal. Any non-empty ghost section means live has been modified outside of migrations.
3. **ORPHANED OBJECTS** — things produced by the active chain but **not** in live. Means a migration declares an object that never landed (or was dropped out-of-band).

`--verbose` additionally prints column-level drift per table and the full stderr from the baseline apply to scratch (useful for diagnosing stub-related false positives).

## Drift-resolution rule

When the detector reports drift, it must be resolved before any further schema work. Resolution is exactly one of:

- **Add a migration** that captures the change (preferred when the live change is intentional), or
- **Revert the out-of-band change** in live (required when the live change was not intentional).

Do not suppress the finding. Do not add an exclusion. The detector is intentionally blunt so that no drift slips past unnoticed.

## Known limitations

- **Attribute-level comparison is set-based only.** Column names are diffed; column types, defaults, `NOT NULL`, and check constraints are not. A type change (e.g. `text` → `varchar(64)`) will not surface. Flagged as Phase B follow-up.
- **Supabase-managed objects don't apply cleanly in scratch.** `pg_cron`, `pg_graphql`, `supabase_vault`, the `supabase_realtime` publication, and PostGIS `topology` helpers (`addauth`, `checkauth`) all emit errors during apply but do not affect the compared object set. Errors are visible under `--verbose`.
- **Storage stubs are minimal.** `storage.objects` and `storage.buckets` are stubbed with only enough columns for referenced views/policies to apply. Drift inside the `storage` schema is not detected.
- **Auth stubs are minimal.** `auth.uid()`, `auth.jwt()`, `auth.role()` are stubbed. If a migration references another `auth.*` helper, apply may fail and the object depending on it will not appear in scratch — surfacing as a false ghost.
- **Historical migrations are excluded by design.** Files under `supabase/migrations/historical/` and `deploy/supabase_migrations/historical/` are out of the active chain (Layer 1 Step 2 Pattern 2 decision). Only the reverse-engineered baseline is authoritative.

## When to run

- **After any out-of-band change to live** — even one confirmed ok.
- **Before cutting a release** that touches schema.
- **After applying a new migration** (with `--self-test` to verify the baseline counts still hold).
- **After editing the baseline migration file** (e.g. to capture drift).

The script is manual-run only by design. It is not hooked into CI, pre-commit, or deploy pipelines — adding enforcement is a separate decision.

## Where it fits

Part of the Layer 1 audit remediation. Companion artifacts:
- `audit/layer_1_step_1_schema_baseline_inventory.md` — canonical live-schema inventory.
- `audit/layer_1_step_2_migration_reconciliation.md` — why the active chain is one baseline file.
- `audit/layer_1_step_3_drift_detector_notes.md` — design rationale and testing outcomes for this script.
