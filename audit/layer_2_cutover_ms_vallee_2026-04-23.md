Layer 2 Cutover Execution Note — MS Vallee
Date: 2026-04-23
Status: Complete
Target: MS Vallee test site (owner-operator test environment)

References:
- audit/phase_5_section_3_cutover_policy.md
- audit/phase_5_section_3_amendment_3.md
- audit/phase_5_section_3_amendment_4.md
- audit/phase_5_section_3_amendment_5.md
- supabase/manual/cutover/RUNBOOK.md

Run identity

- RUN_TS: `20260423T132343Z`
- Reviewed wipe SQL: `supabase/manual/cutover/wipe.sql`
- Wipe preflight: `python3 scripts/cutover_generate_wipe_sql.py --check` passed immediately before live execution
- Final repo reconciliation commit: `ea3b80a` (`cutover: reconcile layer 2 post-wipe constraints with migration chain`)

Export artifacts

- Full export directory:
  `supabase/manual/cutover/exports/20260423T132343Z/`
- Protected archive copy:
  `/Users/zaks/onyx_cutover_exports/20260423T132343Z.tar.gz`
- Protected archive SHA-256:
  `d48c2aed89d69cb4d3350ba078675efd2dd6a8f09dada725192c13dd29aa6107`
- QA corpus freeze:
  `103` JSON files, `28,387` rows (`qa_corpus_index.json`)
- Preservation export:
  `18` JSON files, `61` rows (`preservation_index.json`)

Execution summary

1. Pre-wipe lock checks were clear after earlier stale-session cleanup.
2. The reviewed wipe SQL was executed live via `psql` with `SET ROLE postgres`.
3. The deliberate preservation-to-wipe FK break was handled as designed:
   `public.vehicles.assigned_employee_id` was nulled on `3` preserved vehicle rows
   before dummy employee rows were removed.
4. Post-wipe preservation verification matched the preserved export exactly:
   `18` tables, `61` rows.
5. Post-wipe sample wipe checks were all zero for:
   `client_evidence_ledger`, `site_alarm_events`, `incidents`,
   `telegram_inbound_updates`, and `vehicles.assigned_employee_id IS NOT NULL`.
6. `supabase/manual/post_cutover_constraints/04_add_unique_constraints_dirty.sql`
   applied successfully.
7. The first attempt to apply
   `supabase/manual/post_cutover_constraints/01_add_fk_promotions_dirty.sql`
   failed on:
   `client_evidence_ledger_dispatch_id_fkey`
   because `public.client_evidence_ledger.dispatch_id` is `text` while
   `public.dispatch_intents.dispatch_id` is `uuid`.
8. Per amendment 4, that FK was deferred out of Layer 2. The staged FK file and
   readiness checker were updated so the deferral is explicit and FK type
   compatibility is checked before reporting green.
9. The revised remaining 4b files then applied successfully:
   - `01_add_fk_promotions_dirty.sql` (revised to defer dispatch_id FK)
   - `02_add_not_null_dirty_columns.sql`
   - `03_add_check_constraints_dirty_enums.sql`

Chain reconciliation and drift gate

Step 8 exposed a process contradiction: step 7 had intentionally applied SQL
outside `supabase/migrations/`, but the drift detector correctly treats that as
live-only drift. Amendment 5 resolved this by requiring immediate capture of the
applied post-cutover constraints in the active chain.

Actions taken:

- Added migration:
  `supabase/migrations/20260423000107_capture_layer2_post_cutover_constraints.sql`
- Marked that migration applied on the linked remote via:
  `supabase migration repair --status applied 20260423000107`
- Re-ran:
  `python3 scripts/schema_drift_check.py --self-test --live-dump-timeout 1800`

Final drift result:

- `SELF-TEST PASSED`
- live = scratch:
  - `129` tables
  - `24` views
  - `167` policies
  - `80` foreign keys

Deferred items

- `client_evidence_ledger_dispatch_id_fkey` is deferred to later schema cleanup
  (Layer 4 / Layer 6 owner) because the relationship is structurally invalid as
  currently modelled (`text` child column to `uuid` parent column).
- `clients_name_unique` remains deferred to Layer 4 per amendment 3 because
  `public.clients` is preserved during Layer 2.

End state

- Layer 2 cutover for the MS Vallee test site completed successfully.
- Wipe-set event corpus removed.
- Preservation-set rows retained and re-verified.
- Reviewed post-cutover constraints landed, with the one structurally invalid FK
  explicitly deferred.
- Drift detector returned green after the chain was reconciled to the live
  post-cutover schema.
