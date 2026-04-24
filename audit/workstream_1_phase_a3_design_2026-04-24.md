# Workstream 1 Phase A3 — Operator Action Pipeline Design

## Operator decisions — locked 2026-04-24

All six A3 questions resolved. Phase B proceeds on these decisions.

**Q1 — Dispatch target model**: LOCKED. Option (i) with lazy incidents upsert. Handler upserts incidents row first (UI truth surface), then inserts dispatch_intents (action state machine), lets the auto_decided_transition trigger seed dispatch_transitions.

**Q2 — Acknowledge / False alarm target model**: LOCKED. Both upsert the incidents row if needed, then update incidents.status with action-specific timestamps and actor fields. Neither creates a dispatch_intents row.

**Q3 — Incident creation point**: LOCKED. Manual-only (operator button action) for Phase B. Automated promotion from site_alarm_events is explicitly deferred as a later Workstream 1 follow-up, NOT included in Phase B.

**Q4 — Ledger coupling**: LOCKED. No client_evidence_ledger writes in Phase B. Ledger coupling belongs to Workstream 2 so a single coherent write-path design emerges there. Avoids the dual-write problem.

**Q5 — v1 Flutter blast radius**: LOCKED with refinement. Operator chose Option (b) — don't patch lib/main.dart — with an explicit tightening beyond the A3 draft: do NOT add a "DEAD PATH" comment in Phase B. v1 stays fully out of scope. Phase B touches bin/onyx_telegram_ai_processor.dart only.

**Q6 — Pre-cutover incident origin**: LOCKED as not-a-blocker. Historical context, left open. Document if/when operator remembers.

## Phase B implementation notes (operator-mandated)

Two constraints Phase B must honor beyond the table-target design:

**Note 1 — Incident idempotency keyed off alert identity**: Phase B MUST key the incidents upsert off the alert's stable identity (e.g., the alert_id / alarm_event_id / a derived stable column), NOT off a fresh UUID generated at button-tap time. Tapping Dispatch twice on the same alert must hit the same incidents row. If incidents.id is UUID and cannot be derived from alert_id, then store the alert identity in a separate stable column (e.g., source_alert_id) and upsert on that.

**Note 2 — Dispatch duplicate-safety**: If the operator taps Dispatch twice for the same underlying incident, Phase B MUST NOT create two active dispatch_intents rows. Idempotency check: before insert, look for an existing dispatch_intents row for this incident with a not-yet-terminal state; if present, either skip the insert or update the existing row. Phase B must specify which pattern it chose during its Phase A re-confirmation step.

---

Date: 2026-04-24 SAST
Status: decision-complete, pending Phase B implementation
Precedes: Phase B (implementation)

## Six A3 questions — analysis and recommendations (now locked)

### Q1 — Dispatch target model

Handler recommendation (locked as Option (i) with lazy incident upsert):

1. Upsert the incidents row if one doesn't exist for this alert_id
2. Update incidents.status = 'dispatched' and set dispatched_at
3. Insert a dispatch_intents row referencing the incident (auto_decided_transition trigger seeds dispatch_transitions)
4. Log to site_alarm_events with event_type='telegram_dispatch_requested'
5. Edit the Telegram message to remove keyboard + append status

Reasoning: lazy promotion on first meaningful action answers Q3 and Q1 together. Uses the auto_decided_transition trigger machinery that already exists.

### Q2 — Acknowledge / False alarm target model

For Acknowledge (locked):
- Upsert incidents row if not present
- Update status='acknowledged', set acknowledged_at, set acknowledged_by='telegram:<operator_identifier>'
- Do NOT create a dispatch_intents row
- Log to site_alarm_events: event_type='telegram_acknowledged'
- Remove keyboard + append status

For False alarm (locked):
- Upsert incidents row if not present
- Update status='false_alarm', set resolved_at, set resolved_by, set controller_notes='Marked as false alarm via Telegram operator action'
- Log to site_alarm_events: event_type='telegram_false_alarm'
- Remove keyboard + append status

### Q3 — Incident creation point

Locked: Option (b) — manual-only on operator action for Phase B. Automated promotion deferred as a later Workstream 1 follow-up.

### Q4 — Ledger coupling

Locked: Option (iii) — defer ledger integration to Workstream 2.

### Q5 — v1 Flutter blast radius

Locked: no patch to lib/main.dart, no DEAD PATH comment. Fully out of scope.

### Q6 — Pre-cutover incident origin

Locked as not a blocker. Historical context, left open.

## Phase B scope

Files to modify:
- bin/onyx_telegram_ai_processor.dart — rewrite the three write-path button handlers (_handleDispatchCallback, _handleAcknowledgeCallback, _handleDismissCallback) and any shared helpers (_updateEventRow becomes obsolete and can be removed or repurposed as _upsertIncidentRow)

Tables touched at runtime:
- public.incidents (upsert, update)
- public.dispatch_intents (insert — Dispatch only)
- public.site_alarm_events (insert — operator action audit log)
- public.site_awareness_snapshots (existing _markSnapshotAlertHandled logic; unchanged)

Tables NOT touched:
- public.dispatch_transitions (seeded by trigger, not direct write)
- public.client_evidence_ledger (deferred to Workstream 2)

New fields the incidents upsert needs to populate on first creation:
- id (UUID generated or derived from alert_id?)
- site_id (from callback context)
- priority (from originating site_alarm_events row)
- status ('dispatched' | 'acknowledged' | 'false_alarm')
- signal_received_at (from alert timestamp)
- title / description (from alert payload)
- action-specific timestamps (dispatched_at | acknowledged_at | resolved_at)
- action-specific actor (acknowledged_by | resolved_by)
- controller_notes (for false alarm, matching v2 pattern)

Deployment path:
- Same as worker FD fix: scp the modified onyx_telegram_ai_processor.dart to Hetzner, restart onyx-telegram-ai-processor.service
- Verification: tap each button, observe new rows in incidents / dispatch_intents / dispatch_transitions / site_alarm_events

## Open items before Phase B

A: Does site_alarm_events contain enough context (site_id, priority, event_type, originating camera/channel, timestamp) for the handler to synthesize a complete incidents row on first upsert? If not, where does missing context come from? The handler receives callback.alertId and callback.siteId — is there a lookup from alertId back to the source alarm event row?

B: What's the idempotency model if operator taps Dispatch twice? Upsert handles this for the incidents row, but dispatch_intents is plain insert. Should we check for existing dispatch_intents and skip, or allow multiple?

These are small decisions that Phase B can answer during implementation by reading the existing code structure. Not A3 blockers.

---

*End of Phase A3 — decisions locked, Phase B unblocked.*
