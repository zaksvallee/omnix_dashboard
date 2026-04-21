# Post-cutover constraints (Layer 1 Step 4b staging)

These SQL files are **constraint additions that would be rejected by current live data** because phase 4 flagged that data as dirty. They are staged here — **outside `supabase/migrations/`** — so the Supabase CLI cannot pick them up during any `supabase db push` / `supabase db reset` / `supabase migration up` run.

## The rule

**These files are NEVER applied by `supabase db push`. They run manually at cutover only.**

The specific cutover step is **Layer 2.3 step 5** per phase 5 synthesis. Operator runs each file directly against live via `psql -h <pooler-host> -U postgres -f <file>` in order, after Layer 2 cleanup has normalised the affected data.

## Why

Each constraint below has **known violators in live right now**. If applied today, the migration would fail with `ERROR: check constraint violated` (or equivalent) and roll back. The Layer 2 cutover step cleans the dirty data first (renames `OPEN` → `open`, backfills missing `site_id` values, deletes test rows, resolves orphan client/dispatch IDs) and then applies these.

## Application order at cutover — **DO NOT RUN IN FILENAME ORDER**

There is a hard inter-file dependency: `01` requires UNIQUE constraints that `04` creates. Filename-numeric order would apply `01` first and fail. The correct apply order is:

1. **`04_add_unique_constraints_dirty.sql`** — creates the UNIQUE constraints that some FKs require as parent-column targets.
2. **`01_add_fk_promotions_dirty.sql`** — FK promotions; some FKs in this file reference parent columns made UNIQUE by `04` (notably `guards(guard_id)` which `guard_ops_events.guard_id` FK targets — Layer 2 cleanup adds `guards_guard_id_unique` before running `04`, or `04` is extended to include it).
3. **`02_add_not_null_dirty_columns.sql`** — independent of `01` / `04`. Can run any time after Layer 2 cleanup backfills NULLs.
4. **`03_add_check_constraints_dirty_enums.sql`** — independent of `01` / `04` / `02`. Can run any time after Layer 2 cleanup normalises enum values.

Files `02` and `03` commute (either order works) once Layer 2 cleanup has run. Files `01` and `04` do **not** commute: `04` must precede `01`.

### Each file's role

- `01_add_fk_promotions_dirty.sql` — FK promotions where child rows reference non-existent parents (cleanup resolves orphans first).
- `02_add_not_null_dirty_columns.sql` — NOT NULL on columns with NULL rows (cleanup backfills first).
- `03_add_check_constraints_dirty_enums.sql` — CHECK constraints on columns with non-canonical values (cleanup normalises first).
- `04_add_unique_constraints_dirty.sql` — UNIQUE on columns with duplicate groups (cleanup deduplicates first).

Each file has a header comment stating (a) what it does, (b) the phase 4 finding it addresses, (c) why it's staged (specific counts of violators), and (d) the cutover step that applies it.

## What if a file fails

If a 4b file fails during cutover application, it means Layer 2 cleanup did not fully normalise the affected data. **Do not bypass or modify the file.** Stop, re-query the live table to see residual violators, fix the cleanup, then re-run the file.

## Not supposed to be here forever

Once all four files have been applied at cutover, the constraints they add will be part of live. At that point a subsequent `supabase db pull` + reverse-engineered baseline regeneration will absorb these constraints into the active-chain baseline, and this directory can be deleted or renamed (`applied_YYYYMMDD/`) for audit trail.
