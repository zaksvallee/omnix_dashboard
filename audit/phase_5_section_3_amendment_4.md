Phase 5 §3 — Amendment 4 (2026-04-23)
Appends to: audit/phase_5_section_3_cutover_policy.md and amendments 1-3.
Trigger: Layer 2 step 7 attempted 4b FK promotion after the wipe and found
that one staged FK was structurally invalid, not merely dirty-data invalid.
Status: Additive amendment. Existing §3 text is not replaced; this section
narrows the Layer 2 4b FK scope.

3.4.3 Layer 2 4b scope — client_evidence_ledger.dispatch_id

The staged FK promotion:

public.client_evidence_ledger.dispatch_id -> public.dispatch_intents.dispatch_id

is deferred out of Layer 2.

Reason: the child column is text while the parent column is uuid. The Layer 2
wipe removes row-level orphan data, but it cannot make PostgreSQL implement a
foreign key across incompatible column types. Adding casts, changing column
types, or creating a compatibility column during cutover would be a schema
redesign, not a safe post-wipe constraint promotion.

Disposition change: Layer 2 4b must not add
client_evidence_ledger_dispatch_id_fkey. The FK readiness check must verify
type compatibility for every staged FK before reporting green, and must log this
dispatch_id relationship as explicitly deferred.

Future owner: Layer 4/Layer 6 schema cleanup should decide whether
client_evidence_ledger.dispatch_id is a true dispatch_intents reference, a
polymorphic event identifier, or should be split into type-specific references.
