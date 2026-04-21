# Deploy-side Historical Migrations (pre-baseline)

This directory contains the 10 migration files from the parallel `deploy/supabase_migrations/` set (phase 1a §3.2 first flagged this as a parallel migration set separate from `supabase/migrations/`).

## Why they are here and not in the active chain

See `/Users/zaks/omnix_dashboard/supabase/migrations/historical/README.md` for the full rationale. The short version: applying these in timestamp order does not reproduce the live schema. The reverse-engineered baseline at `supabase/migrations/2026_04_21_000000_reverse_engineered_baseline.sql` is the sole active-chain migration going forward.

## Cross-directory overlap

Layer 1 Step 2 §1 alignment check: only **one object** is touched by migrations in both `supabase/migrations/historical/` and this directory — the `incidents` table.

- `supabase/migrations/historical/202603120002_expand_onyx_operational_registry.sql` creates `public.incidents` with 21 columns.
- `deploy/supabase_migrations/historical/202604140004_operator_discipline.sql` later ALTERs `public.incidents` (operator-discipline columns — `simulated`, operator tracking).

No contradiction: the deploy migration adds to what the supabase migration created.

## Orphaned entries

Three of the deploy migrations declare tables never present in live:

- `202604130001_create_telegram_operator_context.sql` — creates `telegram_operator_context` (absent).
- `202604130003_site_provisioning.sql` — creates `site_shift_schedules` (absent).

The third orphaned rename (`site_vehicle_presence` → `site_vehicle_registry`) is in `supabase/migrations/historical/`, not here.

## Do not run these

Same rule as the supabase-side historical: do not `psql -f` any of these files. The baseline supersedes them.

## Summary

- 10 files dated 2026-04-13 → 2026-04-14.
- Full per-statement detail in `audit/layer_1_step_2_migration_reconciliation.md`.
