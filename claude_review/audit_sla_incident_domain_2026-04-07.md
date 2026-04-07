# Audit: SLA + Incident Domain Layer

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/domain/incidents/risk/sla_breach_evaluator.dart`, `lib/domain/incidents/risk/sla_clock.dart`, `lib/domain/incidents/incident_service.dart` (plus supporting types: `sla_policy.dart`, `incident_projection.dart`, `incident_event_log.dart`, `incident_record.dart`, `sla_profile.dart`, `local_event_storage.dart`)
- Read-only: yes

---

## Executive Summary

The SLA core logic is structurally sound — the three-layer split (policy → clock → evaluator) is clean and the dedup guard is correct. However, three real bugs are present: a partial-write hazard that can permanently lose CRM SLA events, an uninitialized `late` variable in `IncidentProjection` that throws cryptically on corrupted logs, and a `DateTime.now()` call inside `_generateId` that is uncorrelated with the `nowUtc` already in scope. Additionally, SLA breach detection is entirely absent at app restart, meaning long-lived incidents can slip through without ever firing a breach event. Test coverage for this domain layer is effectively zero.

---

## What Looks Good

- `SLAClock.evaluate` uses `Duration(minutes: minutes)` arithmetic on UTC `DateTime` objects. Dart's `DateTime.add` is wall-clock-free; midnight crossings are handled correctly.
- The `isTerminal` guard (resolved/closed) in `sla_clock.dart:31–35` correctly suppresses breach evaluation for closed incidents.
- `SLABreachEvaluator` receives `nowUtc` as a parameter — the injection point is there, even if the internal `_generateId` ignores it.
- The `alreadyBreached` dedup guard (`evaluator:13–17`) prevents repeated breach events for the same incident.
- `IncidentProjection` replays the full event list rather than reading mutable state — correct event-sourcing practice.
- `IncidentEvent.fromJson` / `toJson` are symmetrical and round-trip cleanly.

---

## Findings

### P1 — Partial write: CRM SLA breach event lost on process crash between the two saves

- **Action: REVIEW**
- In `incident_service.dart:63–64`, `saveIncidents` and `saveCrm` are called sequentially without any atomic guarantee:
  ```
  await storage.saveIncidents(incidentLog.all());  // line 63
  await storage.saveCrm(crmLog.all());             // line 64
  ```
- If the process dies, device loses power (load shedding), or `saveCrm` throws after `saveIncidents` succeeds, the incident log will contain `incidentSlaBreached` on the next load, but the CRM log will not contain the corresponding `CRMEvent`.
- The CRM event is never recovered. `initialize()` replays events directly into the in-memory logs via `incidentLog.append(e)` and `crmLog.append(e)` (lines 21–27) — it does not call `handle()`, so no SLA re-evaluation is performed. The breach-to-CRM bridge is bypassed entirely on restart.
- **Evidence:** `incident_service.dart:36–65`, `incident_service.dart:17–27`
- **Suggested follow-up for Codex:** Validate whether `IncidentToCRMMapper.map` is idempotent. If so, the `handle()` path could re-check for un-bridged SLA breach events during `initialize()`. Alternatively, wrap both saves atomically or move to a saga pattern that logs a "CRM event pending" marker before the CRM save.

---

### P1 — `LateInitializationError` when event log is replayed out of order

- **Action: AUTO**
- `IncidentProjection.rebuild` declares `late IncidentRecord record` (line 11) and only initializes it inside the `incidentDetected` branch. Every other branch calls `record.transition(...)` without a null guard.
- If the first event in the replayed list is any type other than `incidentDetected` (corrupted JSON, partial flush during power loss, manual test fixture, or future event ordering change), Dart throws `LateInitializationError: Local 'record' has not been initialized` — an opaque crash with no context about which incident or event caused it.
- The guard at line 8 (`if (events.isEmpty) throw Exception(...)`) does not protect this path.
- **Evidence:** `incident_projection.dart:11`, `incident_projection.dart:13–74`
- **Suggested follow-up for Codex:** Replace `late IncidentRecord record` with `IncidentRecord? record` and throw a domain-specific exception (including `incidentId` and offending `event.type`) when a non-`incidentDetected` event arrives before the record exists.

---

### P1 — SLA breach is never evaluated at app restart

- **Action: REVIEW**
- `initialize()` loads persisted events and appends them to the in-memory log. It does not evaluate SLA clocks. If the app was offline for several hours while an incident was open, no breach event will be generated on the next boot.
- Breach detection only fires inside `handle()` when a new `IncidentEvent` arrives. If no new events come in for a long-lived incident (which can happen in low-activity monitoring periods), the breach is silently missed forever.
- **Evidence:** `incident_service.dart:17–27` (initialize — no SLA evaluation), `incident_service.dart:42–51` (evaluation only inside handle)
- **Suggested follow-up for Codex:** After replaying events in `initialize()`, iterate over distinct incident IDs and call `SLABreachEvaluator.evaluate` for each open incident, using `DateTime.now().toUtc()` (or an injected clock). If a breach is found, append and persist immediately. This is a product decision as much as a bug — flag for Zaks on whether missed-at-restart breaches should also trigger CRM events retroactively.

---

### P2 — `_generateId` uses its own `DateTime.now()`, uncorrelated with `nowUtc`

- **Action: AUTO**
- `SLABreachEvaluator._generateId` calls `DateTime.now().toUtc().millisecondsSinceEpoch` (line 40) independently of the `nowUtc` parameter already passed to `evaluate()`.
- This means the breach event's `eventId` timestamp and the `timestamp` field on the returned `IncidentEvent` (line 31, sourced from `nowUtc`) are from different clock reads. Under load or during a GC pause these can diverge, breaking deterministic ID generation and making tests non-reproducible.
- The rest of the codebase (`IncidentToCRMMapper`) already uses an injected clock function for this exact reason — the test at `incident_to_crm_mapper_test.dart:20` demonstrates the expected pattern.
- **Evidence:** `sla_breach_evaluator.dart:40`, `sla_breach_evaluator.dart:12`
- **Suggested follow-up for Codex:** Pass `nowUtc` into `_generateId` as a parameter instead of calling `DateTime.now()`. The ID becomes `'SLA-$incidentId-${nowUtc.millisecondsSinceEpoch}'`.

---

### P2 — `incident_service.dart` hard-codes `DateTime.now()` in three places

- **Action: REVIEW**
- Three separate `DateTime.now()` calls exist in `incident_service.dart`:
  1. Line 47: `nowUtc: DateTime.now().toUtc()` — passed to `SLABreachEvaluator`
  2. Line 75: `DateTime.now().toUtc().millisecondsSinceEpoch` — override event ID
  3. Line 77: `DateTime.now().toUtc().toIso8601String()` — override event timestamp
- Calls at lines 75 and 77 are separate reads. Under preemption between them, the event ID and event timestamp can disagree by one millisecond or more. More importantly, none of these are injectable, making `IncidentService` untestable for time-sensitive scenarios (midnight, load-shedding clock drift, SLA window boundary).
- Load-shedding clock drift is a real threat: if the system clock jumps forward by hours when power is restored, all in-window incidents at that moment will have their SLA evaluated against the jumped clock and may breach falsely.
- **Evidence:** `incident_service.dart:47`, `incident_service.dart:75–77`
- **Suggested follow-up for Codex:** Inject a `DateTime Function() clock` into `IncidentService` (matching the pattern already used in `IncidentToCRMMapper`). Capture a single `final now = clock()` at the start of `handle()` and `overrideSla()`, then pass that single value everywhere.

---

### P2 — `detectedAt` string parsed without enforced UTC suffix

- **Action: REVIEW**
- `SLAClock.evaluate` does `DateTime.parse(record.detectedAt).toUtc()` (line 22). Dart's `DateTime.parse` treats strings without a timezone suffix (e.g., `"2026-04-07T23:45:00"` without `Z`) as **local time**, then `.toUtc()` converts. If any event source stores timestamps without `Z` and the device is not running in UTC, the SLA window silently shifts by the device's UTC offset.
- `IncidentProjection` assigns `detectedAt: event.timestamp` (line 22 of `incident_projection.dart`). Events created by `IncidentService.handle` use `nowUtc.toUtc().toIso8601String()` which includes the `Z` suffix. But external callers constructing `IncidentEvent` directly (integration adapters, tests) may not — there is no validation.
- **Evidence:** `sla_clock.dart:22`, `incident_projection.dart:22`, `incident_service.dart:31` (no contract on incoming `timestamp`)
- **Suggested follow-up for Codex:** Either add an assertion (`assert(record.detectedAt.endsWith('Z'), ...)`) in `SLAClock.evaluate`, or parse using `DateTime.parse(record.detectedAt).toUtc()` and verify in a test with a non-Z timestamp that the UTC conversion is still correct for the expected source.

---

### P3 — `incidentSlaBreached` silently forces `escalated` status regardless of prior state

- **Action: DECISION**
- `IncidentProjection` transitions the incident to `IncidentStatus.escalated` when it replays an `incidentSlaBreached` event (lines 62–65). This means an incident that was already in any other non-terminal state (e.g., `dispatchLinked`) will be overwritten to `escalated` by a breach event.
- If a breach fires while an incident is `dispatchLinked` and a dispatch is actively managing it, the status silently reverts to `escalated`. Downstream views or notification gates that branch on `dispatchLinked` status may then behave incorrectly.
- This is a product question as much as a bug: should breach override dispatch-linked status?
- **Evidence:** `incident_projection.dart:62–65`
- **Suggested follow-up for Codex:** No action until Zaks confirms intended behavior. If the correct behavior is "breach escalates only when no active dispatch", add a guard in `SLABreachEvaluator.evaluate` or in `IncidentProjection` to skip the status transition when `status == dispatchLinked`.

---

## Duplication

- `DateTime.now().toUtc()` appears in `sla_breach_evaluator.dart:40`, `incident_service.dart:47`, `incident_service.dart:75`, and `incident_service.dart:77`. Each is a separate uncorrelated clock read. The same problem was already solved in `IncidentToCRMMapper` with an injected `clock` parameter. The fix pattern is established and should be applied consistently.
- The sequential `await storage.saveX` / `await storage.saveY` pattern appears identically in `handle()` (lines 63–64). It also appears in `dispatch_persistence_service.dart` (from prior audits). No atomic or saga wrapper exists anywhere — the same partial-write vulnerability is replicated across services.

---

## Coverage Gaps

No test files exist for any of the following:

| File | Missing Tests |
|------|---------------|
| `sla_clock.dart` | breach at boundary (`nowUtc == due`), breach after midnight, no breach for resolved, no breach for closed, load-shedding clock jump |
| `sla_breach_evaluator.dart` | alreadyBreached dedup, null when terminal, correct `metadata.due_at` value, deterministic `eventId` when clock is injected |
| `sla_policy.dart` | all four severity branches, unknown severity (if enum is extended) |
| `incident_projection.dart` | first event not `incidentDetected` (crash path), all state transitions, SLA breach forces escalated status |
| `incident_service.dart` | partial write (save incidents succeeds, save CRM throws), SLA breach emitted and appended, `overrideSla` round-trip, no breach re-emitted if `alreadyBreached` in log |
| `incident_event_log.dart` | `byIncident` filters by correct ID, `all()` is unmodifiable |

Priority test cases to prove the highest-risk paths:

1. **Clock boundary test for `SLAClock`** — `nowUtc` exactly equal to `due` must NOT breach (breach is `isAfter`, exclusive). One millisecond after must breach.
2. **Partial-write regression for `IncidentService`** — mock `storage.saveCrm` to throw; verify the in-memory `crmLog` retains the appended event but the persisted CRM file does not, proving divergence.
3. **LateInitializationError path in `IncidentProjection`** — pass a list starting with `incidentClassified`; expect a domain exception (after the fix), not `LateInitializationError`.
4. **Restart-miss regression** — build an `IncidentService`, persist an open incident within its SLA window, advance mock clock past the SLA due, call `initialize()`, verify no breach event is generated (documents the current gap until it is resolved).
5. **Deterministic ID test for `SLABreachEvaluator`** — after the `_generateId` fix, verify the event ID contains the exact millisecondsSinceEpoch of the injected `nowUtc`.

---

## Performance / Stability Notes

- `incidentLog.all()` in `incident_service.dart:63` returns `List.unmodifiable(_events)` — the entire event log is serialized and written on every `handle()` call. For a service that accumulates thousands of incident events over a long shift, this becomes an O(n) full-rewrite on every event. No rotation or append-only write strategy is in place.
- `EventLogRotationGuard` is called before each save (lines 19 and 25 of `local_event_storage.dart`) — its enforcement logic should be audited separately to confirm it guards against unbounded growth before the O(n) write concern becomes critical.

---

## Recommended Fix Order

1. **(P1 — REVIEW) Partial write / CRM event loss** — highest operational risk; a single power failure can silently drop SLA breach records from the CRM lane with no recovery path.
2. **(P1 — AUTO) `LateInitializationError` in `IncidentProjection`** — safe, narrow fix; replace `late` with `?` and add a domain exception. Low risk, high clarity gain.
3. **(P1 — REVIEW) SLA evaluation missing at restart** — requires a product decision on retroactive CRM events, but the breach-miss risk is real in every app cycle.
4. **(P2 — AUTO) `_generateId` uses own `DateTime.now()`** — one-line fix; align with `IncidentToCRMMapper` injection pattern already in the codebase.
5. **(P2 — REVIEW) Inject clock into `IncidentService`** — precondition for reliable tests on all time-sensitive paths; resolves the load-shedding drift risk.
6. **(P2 — REVIEW) `detectedAt` UTC suffix validation** — low probability today given internal callers, but worth asserting before external adapters multiply.
7. **(P3 — DECISION) `incidentSlaBreached` → escalated side-effect** — product decision needed; no code change until Zaks confirms intent.
8. **Test suite for the SLA/incident domain** — all seven files in this layer are currently untested; see coverage gaps section for priority order.
