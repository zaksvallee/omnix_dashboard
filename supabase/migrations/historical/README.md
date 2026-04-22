# Historical Migrations (pre-baseline)

This directory contains the 44 migration files that predate the reverse-engineered baseline at `../20260421000000_reverse_engineered_baseline.sql`.

## Why they are here and not in the active chain

Layer 1 Step 2 of the audit remediation (see `audit/layer_1_step_2_migration_reconciliation.md`) established that applying these migrations in timestamp order **does not reproduce the live schema**. Specifically, tables such as `incidents` have 27–28 columns in live that were added out of band and are not described by any `ALTER TABLE ADD COLUMN` in these migrations. The baseline captures the complete live schema; historical migrations describe a path that stopped being followed.

If both the historical migrations and the baseline were left in the active `supabase/migrations/` chain, `supabase db reset` would run them in timestamp order: historical CREATE TABLEs would execute first, creating under-specified tables, then the baseline's `CREATE TABLE IF NOT EXISTS` would skip (tables already exist) — the final schema would be missing the out-of-band columns.

Moving these files into this `historical/` subdirectory removes them from the Supabase CLI's migration discovery. They remain here for:

- **audit trail** — the history of how the schema evolved, preserved even though the chain is no longer authoritative.
- **blame / context** — future engineers can trace when a table or column first appeared in the source tree.
- **reconciliation reference** — the drift + orphan catalogue in `audit/layer_1_step_2_migration_reconciliation.md` references these files by name.

## Do not run these

Do not `psql -f` any of these files against a live or scratch database. The baseline supersedes them. If reconstructing from scratch, apply only `../20260421000000_reverse_engineered_baseline.sql`.

## Orphaned entries

Three of these migration files declare objects that never existed in live (renamed out of band or never applied):

- `20260410_create_vehicle_presence.sql` — creates `site_vehicle_presence`, which was likely renamed to `site_vehicle_registry` in the live schema.

See the sibling `deploy/supabase_migrations/historical/README.md` for the other two (`telegram_operator_context` and `site_shift_schedules`).

## Summary

- 44 files dated 2026-03-04 → 2026-04-17.
- 718 DDL statements total (combined with `deploy/supabase_migrations/historical/`).
- Classification: 603 `applied`, 61 `applied_with_drift`, 12 `orphaned`, 42 `unverified` (33 DO-block, 9 other).
- Full per-statement detail in `audit/layer_1_step_2_migration_reconciliation.md`.
