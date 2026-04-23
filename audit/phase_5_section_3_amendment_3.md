Phase 5 §3 — Amendment 3 (2026-04-23)
Appends to: audit/phase_5_section_3_cutover_policy.md and amendments 1-2.
Trigger: Phase B/C gate hardening found two Layer 2 / 4b coordination conflicts.
Status: Additive amendment. Existing §3 text is not replaced; this section
extends and narrows the Layer 2 execution policy.

3.3.1 correction — client_conversation_push_sync_state

Amendment 1 classified public.client_conversation_push_sync_state as untouched
because its two live rows regenerate on next push sync. Phase B/C readiness
checks confirmed that one of those rows contains an orphan client_id. If the
table remains untouched, 4b constraint application fails when
client_conversation_push_sync_state_client_id_fkey is promoted.

Disposition change: public.client_conversation_push_sync_state moves from
untouched to wipe for Layer 2.

Rationale: the table is explicitly auto-regenerating, has no preservation
value, and already contains test-grade orphan state. Wiping it is less
surprising than preserving dirty generated state that blocks the planned
post-wipe FK promotion.

3.4.2 Layer 2 4b scope — clients(name)

The staged 4b unique constraint clients_name_unique conflicts with the Layer 2
preservation rule for public.clients. Live contains three preserved rows named
"test"; Layer 2 is not the configuration-cleanup layer and should not mutate
preservation-set client rows solely to satisfy an optional uniqueness
constraint.

Disposition change: clients_name_unique is deferred out of Layer 2 4b and into
Layer 4 site/client configuration cleanup. The 4b constraint file applied by
Layer 2 must not add clients_name_unique.

Rationale: preserving client configuration bit-for-bit is more important in
Layer 2 than enforcing a client-name uniqueness invariant whose cleanup requires
operator judgement. Layer 4 owns dummy site/client cleanup and can deduplicate
or rename the test clients with proper context.
