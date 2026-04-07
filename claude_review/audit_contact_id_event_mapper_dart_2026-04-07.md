# Audit: contact_id_event_mapper.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/domain/alarms/contact_id_event_mapper.dart` and sibling Contact ID stubs
- Read-only: yes

## Executive Summary

`ContactIdEventMapper` is a documented placeholder with zero implementation. The class body is empty. The two sibling files — `ContactIdEvent` and `ContactIdReceiverService` — are similarly empty stubs. No production code anywhere in the repo references any of the three classes, confirming they are pre-designed scaffolding only. There are no tests for any of them. The comments are well-structured and contain accurate architectural intent, but no behaviour exists to audit for bugs, performance, or duplication. The primary risk is that the design decisions deferred in the TODOs are load-bearing: the mapping strategy, zone/partition scope mapping, and transport isolation boundary must all be resolved before any receiver work can begin safely.

## What Looks Good

- Comment block in `contact_id_event_mapper.dart` correctly identifies the Contact ID event categories that need coverage (burglary, fire, panic, medical, tamper, comms trouble).
- The mapper is already placed inside `lib/domain/alarms/`, correctly separated from `lib/infrastructure/alarm/`, which shows the intended transport-isolation boundary is understood.
- `contact_id_receiver_service.dart` documents the full intended pipeline (panel → GPRS/IP → receiver → triage → escalation → dispatch/comms) — this is a useful north-star for implementation.
- The TODO in the mapper explicitly calls out keeping mapper logic pure (`TODO(zaks): Keep mapper logic pure so receiver transport details stay out of the domain layer`), which is the correct constraint.

## Findings

### P1 — No implementation exists; design decisions are unresolved blockers

- **Action:** DECISION
- **Finding:** All three Contact ID classes (`ContactIdEventMapper`, `ContactIdEvent`, `ContactIdReceiverService`) are empty. No mapping logic, no domain model fields, no receiver transport wiring exists.
- **Why it matters:** The Contact ID receiver is the entry point for alarm panel events into ONYX. Until the three open TODOs in the mapper and the two in the receiver service are resolved, no downstream work (triage agent, escalation policy, incident domain) can consume real alarm events.
- **Evidence:**
  - `lib/domain/alarms/contact_id_event_mapper.dart` lines 1–18: class body is `{}`
  - `lib/domain/alarms/contact_id_event.dart` lines 1–15: class body is `{}`
  - `lib/infrastructure/alarm/contact_id_receiver_service.dart` lines 1–18: class body is `{}`
- **Suggested follow-up for Codex:** Validate that no other file in `/lib/` or `/test/` imports or depends on any of these three classes. If confirmed zero consumers, the stubs are safe to leave until the design decisions are made.

### P2 — Zone/partition/account scope mapping decision is unresolved

- **Action:** DECISION
- **Finding:** The mapper TODO explicitly defers the question of how panel zone, partition, and account identifiers map into ONYX client/site/incident scope. This is an architectural decision, not a code task.
- **Why it matters:** The Contact ID protocol uses account codes, partition numbers, and zone numbers. ONYX uses client, site, and incident as its domain primitives. Without a resolved mapping strategy, the `ContactIdEvent` model cannot be defined, which means the mapper cannot be written, which means the receiver service has nowhere to send parsed frames.
- **Evidence:** `lib/domain/alarms/contact_id_event_mapper.dart` line 14–15 (TODO(zaks) for zone/partition/account mapping); `lib/domain/alarms/contact_id_event.dart` lines 5–12 (expected fields listed but not typed or enforced).
- **Suggested follow-up for Codex:** Confirm whether the SIA DC-09 receiver spec (`claude_review/spec_sia_dc09_receiver_2026-04-07.md`) already resolves this mapping decision. If it does, the scope mapping there should drive the `ContactIdEvent` field definitions.

### P3 — No test scaffolding exists for the mapper

- **Action:** AUTO (once implementation begins)
- **Finding:** There are no tests for `ContactIdEventMapper`, `ContactIdEvent`, or `ContactIdReceiverService`. Grep across all `*.dart` files confirms zero references to these classes outside their own definition files.
- **Why it matters:** The mapper is a pure domain function — it takes raw event codes and produces typed domain events. This is exactly the kind of logic that is cheapest to test before wiring to transport. Deferring test scaffolding means the first real implementation will arrive untested.
- **Evidence:** Repo-wide grep for `ContactIdEventMapper`, `ContactIdEvent`, `ContactIdReceiver` returns only the three stub files themselves.
- **Suggested follow-up for Codex:** Once `ContactIdEvent` fields are defined, a test fixture with known Contact ID code samples (e.g. burglary: `1130`, fire: `1110`, panic: `1120`) should be created to drive mapper correctness from day one.

## Duplication

No duplication to report. The three files are distinct stubs with no overlapping logic (there is no logic). The comment blocks reference each other's concerns appropriately without duplicating prose.

One **suspicion** worth flagging: if ONYX also plans to handle SIA DC-09 or CID-over-IP framing variants, the receiver parsing logic could diverge into separate service stubs that overlap in concern. The existing `spec_sia_dc09_receiver_2026-04-07.md` in `/claude_review/` should be cross-checked to confirm whether it describes a separate path or the same path as `ContactIdReceiverService`.

## Coverage Gaps

- No unit tests for `ContactIdEventMapper` (no implementation yet, so no test is possible — but test scaffolding should be planned in parallel with the design decision).
- No integration test for the receiver-to-domain pipeline.
- No test for the qualifier field (`new / restore / open / close`) which is a branch-heavy classification concern — it needs dedicated test cases once the model is defined.
- No test for unknown or malformed event codes reaching the mapper — the silent-fallback risk is high if the mapper later uses a lookup table with no default guard.

## Performance / Stability Notes

- No performance concerns exist yet because there is no implementation.
- **Pre-emptive concern (suspicion, not confirmed):** If the receiver is eventually implemented as a polling loop over a GPRS/IP socket without backoff or a dropped-frame buffer, it will be fragile under poor connectivity. The TODO in `contact_id_receiver_service.dart` line 17 already calls this out (`replay-safe buffering and observability`). This concern should be treated as a hard requirement, not a nice-to-have, before any live receiver goes near a panel.

## Recommended Fix Order

1. **DECISION — Resolve zone/partition/account → client/site/incident mapping** before any implementation begins. Cross-check with `spec_sia_dc09_receiver_2026-04-07.md` to see if this is already answered there.
2. **DECISION — Define `ContactIdEvent` field set** (minimal immutable shape) once the scope mapping is resolved. This unblocks both the mapper and the receiver.
3. **AUTO — Implement `ContactIdEventMapper`** with a lookup table for supported event codes, returning a typed result (or an explicit unknown-code sentinel — never a silent null).
4. **AUTO — Add test fixtures** for known event codes (burglary, fire, panic, medical, tamper, comms trouble) covering both `new` and `restore` qualifiers.
5. **REVIEW — Design `ContactIdReceiverService` transport wiring** with replay-safe buffering before any production integration is attempted.
