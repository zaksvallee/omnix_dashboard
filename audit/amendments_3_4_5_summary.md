## Phase 5 §3 — Amendment 3 (2026-04-23)

Date: 2026-04-23

Trigger: Phase B/C gate hardening found two Layer 2 / 4b coordination
conflicts that would have made the post-wipe constraint pass either fail or
mutate preserved configuration outside Layer 2's remit.

Substance:
- Title read verbatim: `Phase 5 §3 — Amendment 3 (2026-04-23)`.
- Reclassifies `public.client_conversation_push_sync_state` from untouched to
  wipe for Layer 2.
- Records that readiness checks found one live row with an orphan `client_id`,
  which would break `client_conversation_push_sync_state_client_id_fkey`
  promotion if preserved.
- Treats the table as safe to wipe because its rows regenerate on the next push
  sync and have no preservation value.
- Defers `clients_name_unique` out of Layer 2 4b and into Layer 4 site/client
  cleanup.
- Preserves the three live `public.clients` rows named `test` rather than
  renaming or deduplicating them during Layer 2.

Impact on downstream work:
- Layer 2 wipe tooling and runbook must include
  `public.client_conversation_push_sync_state` in the wipe set.
- Layer 2 4b SQL must not apply `clients_name_unique`; that cleanup belongs to
  Layer 4 with operator judgement.
- Any later client cleanup work must start from the premise that preserved
  client configuration won over optional uniqueness enforcement.

## Phase 5 §3 — Amendment 4 (2026-04-23)

Date: 2026-04-23

Trigger: Layer 2 step 7 attempted 4b FK promotion after the wipe and found
that one staged FK was structurally invalid, not merely dirty-data invalid.

Substance:
- Title read verbatim: `Phase 5 §3 — Amendment 4 (2026-04-23)`.
- Defers the staged FK
  `public.client_evidence_ledger.dispatch_id -> public.dispatch_intents.dispatch_id`
  out of Layer 2.
- Records the core incompatibility: child column is `text`, parent column is
  `uuid`.
- States explicitly that Layer 2 can remove bad rows but cannot make PostgreSQL
  implement an FK across incompatible types.
- Forbids Layer 2 4b from adding
  `client_evidence_ledger_dispatch_id_fkey`.
- Requires the FK readiness check to verify type compatibility for every staged
  FK before reporting green.
- Assigns future ownership to Layer 4 / Layer 6 schema cleanup, which must
  decide what `client_evidence_ledger.dispatch_id` really represents.

Impact on downstream work:
- Layer 2 post-wipe constraint promotion must treat this FK as an explicit
  deferral, not a retryable dirty-data issue.
- Layer 3 evidence/ledger restoration work inherits a named schema blocker
  around dispatch linkage.
- Later schema cleanup must choose between true dispatch reference,
  polymorphic identifier, or split references before the FK can exist.

## Phase 5 §3 — Amendment 5 (2026-04-23)

Date: 2026-04-23

Trigger: Layer 2 step 8 drift-detector gate could not return green immediately
after step 7 if step 7 applied SQL outside the active migration chain.

Substance:
- Title read verbatim: `Phase 5 §3 — Amendment 5 (2026-04-23)`.
- Clarifies that any staged 4b SQL applied directly to live in step 7 must be
  absorbed back into the normal migration chain before drift can be considered
  resolved.
- Requires an equivalent reviewed migration under `supabase/migrations/`
  encoding only the constraints actually applied, preserving Layer 2 deferrals.
- Requires repairing the migration status in
  `supabase_migrations.schema_migrations` via
  `supabase migration repair --status applied <version>`.
- Requires re-running
  `python3 scripts/schema_drift_check.py --self-test` only after the chain and
  live schema match again.
- Frames live-only step-7 SQL as a temporary transition mechanism, not a valid
  terminal state for cutover completion.

Impact on downstream work:
- Layer 2 execution is not complete until live-applied 4b changes are captured
  in the migration chain and drift returns green.
- Future cutover operators must budget for chain reconciliation after any
  direct live SQL in step 7.
- Layer 3 and later work can trust the schema baseline again only because this
  amendment forces chain/live convergence after cutover.
