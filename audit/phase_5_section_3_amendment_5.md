Phase 5 §3 — Amendment 5 (2026-04-23)
Appends to: audit/phase_5_section_3_cutover_policy.md and amendments 1-4.
Trigger: Layer 2 step 8 drift-detector gate cannot return green immediately
after step 7 if step 7 applies SQL outside the active migration chain.
Status: Additive amendment. Existing §3 text is not replaced; this section
clarifies the post-step-7 chain-reconciliation requirement.

3.4.4 Step 8 prerequisite — absorb applied 4b constraints into the chain

If Layer 2 step 7 applies any staged 4b SQL directly against live, step 8 must
first capture the resulting schema changes in the normal migration chain before
the drift detector is re-run.

Required sequence:

1. Add an equivalent reviewed migration under `supabase/migrations/` that
   encodes the constraints actually applied at step 7, preserving any Layer 2
   deferrals.
2. Mark that migration version `applied` in the target environment's
   `supabase_migrations.schema_migrations` table via
   `supabase migration repair --status applied <version>`.
3. Re-run `python3 scripts/schema_drift_check.py --self-test`.

Rationale: the drift detector treats live-only schema changes as drift by
definition. Manual step-7 SQL is therefore a temporary transition mechanism,
not a substitute for updating the active chain. Cutover is not complete until
the chain matches live again.
