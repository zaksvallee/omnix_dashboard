# Audit: SLA Timing Chain (sla_policy → sla_clock → sla_breach_evaluator)

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/domain/incidents/risk/sla_policy.dart`, `lib/domain/incidents/risk/sla_clock.dart`, `lib/domain/incidents/risk/sla_breach_evaluator.dart`
- Supporting files read: `incident_record.dart`, `incident_enums.dart`, `incident_service.dart`, `incident_event.dart`, `sla_profile.dart`
- Related prior audit: `audit_sla_incident_domain_2026-04-07.md` (covers partial-write, LateInitializationError, restart-miss — not repeated here)
- Read-only: yes

---

## Executive Summary

The three-file SLA chain has a structurally clean split of concerns. UTC arithmetic in the timing core is correct and midnight crossings are safe *for well-formed inputs*. However, two real failure modes exist: the `detectedAt` parser silently treats non-`Z` timestamps as local time (which can shift the SLA window by the device's UTC offset across any midnight), and `IncidentService` hard-codes `DateTime.now()` without clock injection, making load-shedding clock drift undetectable and untestable. Most critically, **no test in the repo directly exercises any of the three chain files** — the one indirect test that exercises the chain proves breach by accident of date arithmetic, not by controlled timing.

---

## Chain Architecture

```
SLAPolicy.resolveSlaMinutes(severity, profile)
    ↓ returns int (minutes)
SLAClock.evaluate(record, profile, nowUtc)
    ↓ returns SLAClock { startedAt, dueAt, breached }
SLABreachEvaluator.evaluate(history, record, profile, nowUtc)
    ↓ returns IncidentEvent? (null = no breach)
        ↑ called by IncidentService.handle(..., nowUtc: DateTime.now().toUtc())
```

`nowUtc` is injectable at `SLAClock` and `SLABreachEvaluator` but is sourced from a live `DateTime.now()` call at the service layer. The chain's testability depends entirely on the service honouring the injected clock — it does not.

---

## Focus 1: Midnight Crossing Correctness

### Verdict: Safe for UTC-sourced strings. Unsafe for non-Z strings.

**Why the arithmetic is correct:**

`SLAClock.evaluate` computes `due = start.add(Duration(minutes: minutes))` (`sla_clock.dart:29`).
Dart's `DateTime.add(Duration)` adds elapsed time, not calendar time. It does not consult DST rules,
does not rebase on calendar boundaries, and treats midnight as any other instant.
A 15-minute SLA starting at `23:50:00Z` correctly produces `dueAt = 00:05:00Z` the next day.

**Where midnight can break:**

`SLAClock.evaluate` parses `record.detectedAt` as:
```dart
final start = DateTime.parse(record.detectedAt).toUtc();   // sla_clock.dart:22
```

Dart's `DateTime.parse` treats a string **without a `Z` or `+00:00` suffix as local time**.
The subsequent `.toUtc()` then converts from the device's local timezone to UTC.

- If a device is running in UTC+2 and `detectedAt` was stored without a `Z` (e.g., `"2026-04-07T23:50:00"`), Dart will interpret it as `21:50:00Z`, shifting the SLA start 2 hours earlier than intended.
- An incident detected at `23:50` local time with a 15-minute SLA would have its `dueAt` at `21:05Z` — already breached before the first operator even sees it.
- No validation enforces `Z` presence on `record.detectedAt` anywhere in `IncidentRecord`, `IncidentProjection`, or `SLAClock`.

**Evidence:** `sla_clock.dart:22`, `incident_record.dart:12` (no suffix contract on `detectedAt`)

**Action: REVIEW**
The prior audit also flagged this at P2 (`audit_sla_incident_domain_2026-04-07.md`).
If all incident sources reliably emit `Z`-suffixed ISO strings this is low probability, but no enforcement exists to guarantee it. An assertion or UTC-safe parse wrapper would close the gap. Codex should confirm whether any integration adapter (CCTV bridge, DVR ingest, Supabase deserialization) stores timestamps without `Z`.

---

## Focus 2: Load Shedding Clock Drift Handling

### Verdict: Not handled. Two distinct failure modes exist.

**Failure mode A — Forward jump (power restored, NTP resync):**

When power is restored after a load-shedding outage, the device clock may jump forward by minutes or hours via NTP. The next `IncidentService.handle` call evaluates all open incidents using `DateTime.now().toUtc()` at line 47 of `incident_service.dart`. If the clock jumped past an incident's `dueAt`, the incident appears breached at that instant even though it may have been actively managed during the outage.

There is no mechanism to distinguish a genuine breach from a clock-jump breach. The breach event is emitted, appended to the log, and sent to CRM without any drift guard.

**Failure mode B — Breach missed during outage (no events arrive):**

If the app is offline during the SLA window (screen locked, process killed by OS, load-shedding), no `handle()` call fires. `initialize()` (`incident_service.dart:17–27`) replays persisted events but does not evaluate SLA clocks. When the app restarts, open incidents that crossed their `dueAt` during the outage are never marked as breached. The SLA clock in `SLAClock.evaluate` would correctly return `breached: true` if called, but nothing calls it. This is the restart-miss bug flagged as P1 in the prior audit — it is directly exacerbated by load shedding.

**Evidence:** `incident_service.dart:47` (no clock injection), `incident_service.dart:17–27` (no SLA re-evaluation at restart)

**Action: DECISION**

The correct behaviour during and after a load-shedding event is a product decision:
- Should a breach that occurred during an outage be retroactively emitted when the app restarts? (affects CRM SLA records and compliance reporting)
- Should a clock jump of more than X minutes suppress breach detection until a human review? (requires a drift-tolerance threshold — what is acceptable?)

Neither question has an answer in code or documentation. Codex is blocked until Zaks decides the policy.

**What Codex can implement without a decision:**

The clock injection gap is independent of the policy question. `IncidentService` should accept a `DateTime Function() clock` parameter (matching the pattern in `IncidentToCRMMapper`) so that the drift scenarios can be tested at all. This is `AUTO` — it does not change behaviour, only makes the existing behaviour testable and sets the precondition for any future drift-tolerance logic.

---

## Focus 3: What Tests Prove the SLA Timing Is Correct

### Verdict: Nothing proves it. One indirect test proves breach-eventually, not timing.

### Existing test coverage of the chain

| File | Direct test file | Tests that exercise it |
|------|-----------------|------------------------|
| `sla_policy.dart` | None | None |
| `sla_clock.dart` | None | None (indirectly reached via `SLABreachEvaluator` in one service test) |
| `sla_breach_evaluator.dart` | None | None (indirectly reached in `incident_service_test.dart:15`) |

**The one test that touches the chain:**

`test/domain/incidents/incident_service_test.dart:15` — `'incident SLA breach preserves status and sets breach flag'`

This test:
1. Creates an incident with `detectedAt: DateTime.utc(2020, 1, 1, 0, 0)` and a 5-minute SLA
2. Calls `service.handle(...)` which internally calls `DateTime.now().toUtc()` as `nowUtc`
3. Expects `IncidentEventType.incidentSlaBreached` to be emitted

The breach is detected because `DateTime.now()` in 2026 is well past `2020-01-01T00:05:00Z`. This is not a timing proof — it is **proof by elapsed calendar time**. The test would still pass if the SLA window were 50 years. It proves the pipeline wires together; it does not prove:

- The clock boundary (`nowUtc == due` must NOT breach; one millisecond after must breach)
- Midnight arithmetic (`detectedAt = 23:58Z`, `minutes = 5`, `dueAt = 00:03Z` next day)
- That a resolved incident is suppressed (`isTerminal` guard in `sla_clock.dart:31–35`)
- That a closed incident is suppressed
- That a second handle call does not re-emit a breach (dedup guard in `evaluator:13–17`)
- Any load-shedding scenario

**Missing tests mapped to chain lines:**

| Gap | Chain location | Risk if absent |
|-----|---------------|----------------|
| `nowUtc.isAfter(due)` boundary — `nowUtc == due` must return `false` | `sla_clock.dart:35` | Off-by-one breach in high-frequency polling scenarios |
| `isTerminal` for `resolved` | `sla_clock.dart:31–32` | If guard regresses, resolved incidents accumulate false breaches |
| `isTerminal` for `closed` | `sla_clock.dart:33` | Same as above |
| `isTerminal` for `escalated` — currently NOT terminal | `sla_clock.dart:31–35` | Escalated incidents keep breaching on every `handle` call; dedup guard is the only protection |
| Midnight crossing: `detectedAt = 23:58Z`, `5 min SLA`, assert `dueAt = 00:03Z` | `sla_clock.dart:29` | Documents the arithmetic guarantee; catches any future DST-naive refactor |
| `detectedAt` without `Z` suffix, device in UTC+2 | `sla_clock.dart:22` | SLA window shifts silently by UTC offset |
| `alreadyBreached` dedup: second evaluate returns null | `sla_breach_evaluator.dart:13–17` | If guard is removed, CRM receives duplicate breach events |
| `_generateId` determinism after clock injection fix | `sla_breach_evaluator.dart:39–42` | Event IDs contain live clock reads; non-reproducible in tests |
| All four severity branches of `SLAPolicy.resolveSlaMinutes` | `sla_policy.dart:5–19` | Enum extension could silently fall through without exhaustion test |

---

## Findings Summary

### P1 — No SLA timing is provably correct by tests
- **Action: AUTO** (tests can be written without product decisions)
- The SLA chain has zero direct unit tests. The single indirect test proves wiring, not timing. Any refactor of the arithmetic, the terminal-status guard, or the dedup guard could regress silently.
- **Suggested follow-up for Codex:** Write `test/domain/incidents/risk/sla_clock_test.dart` and `sla_breach_evaluator_test.dart`. Priority cases listed in Focus 3 table above. `SLAPolicy` can be covered in 4 lines; `SLAClock` needs ~6 cases; `SLABreachEvaluator` needs ~4 cases.

### P2 — `detectedAt` without `Z` suffix silently shifts SLA window
- **Action: REVIEW**
- UTC arithmetic is correct for `Z`-suffixed strings. Non-`Z` strings are parsed as local time and then converted, shifting the SLA start by the device offset. No contract enforces the suffix.
- **Evidence:** `sla_clock.dart:22`
- **Suggested follow-up for Codex:** Add `assert(record.detectedAt.endsWith('Z') || record.detectedAt.contains('+'), 'detectedAt must be UTC-qualified')` in `SLAClock.evaluate`. Separately, audit whether any CCTV/DVR/Supabase deserialization path omits the `Z`.

### P2 — Load-shedding drift has no guard; policy decision is absent
- **Action: DECISION**
- `IncidentService` uses live `DateTime.now()` with no drift tolerance. Forward clock jumps on NTP resync after outage create false breaches. No product policy defines acceptable clock drift or retroactive breach treatment.
- **Evidence:** `incident_service.dart:47`
- **Suggested follow-up for Codex:** Clock injection is `AUTO` (no behaviour change). The drift-tolerance threshold and retroactive-breach policy are blocked on Zaks.

### P3 — `escalated` status is not terminal; escalated incidents can keep accumulating breach state across `handle` calls
- **Action: REVIEW**
- `sla_clock.dart:31–35` treats only `resolved` and `closed` as terminal. An incident in `escalated` status continues to evaluate as breachable on every `handle` call. The dedup guard (`evaluator:13–17`) prevents a second event from being emitted if `incidentSlaBreached` is already in history. But if an escalated incident is re-opened or history is partially replayed, the guard could be bypassed.
- This is also a product question: should escalation stop the SLA clock?
- **Evidence:** `sla_clock.dart:31–35`, `incident_enums.dart:29` (`escalated` is a valid `IncidentStatus`)

---

## Duplication

None within the three chain files. `DateTime.now()` duplication between `_generateId` (evaluator line 40) and `IncidentService.handle` (line 47) is carried forward from `audit_sla_incident_domain_2026-04-07.md`.

---

## Coverage Gaps (chain-specific)

| Test case | File to create | Priority |
|-----------|---------------|----------|
| Clock boundary: `nowUtc == due` → no breach | `sla_clock_test.dart` | High |
| Clock boundary: `nowUtc = due + 1ms` → breach | `sla_clock_test.dart` | High |
| Midnight crossing: `detectedAt = 23:58Z`, `5 min` → `dueAt = 00:03Z` | `sla_clock_test.dart` | High |
| Resolved incident → no breach | `sla_clock_test.dart` | Medium |
| Closed incident → no breach | `sla_clock_test.dart` | Medium |
| All 4 severity branches of SLAPolicy | `sla_policy_test.dart` | Medium |
| Dedup: second evaluate with existing breach in history → null | `sla_breach_evaluator_test.dart` | High |
| Non-Z detectedAt, device in UTC+2 → breach window shifts (documents risk) | `sla_clock_test.dart` | Medium |

---

## Recommended Fix Order

1. **(AUTO) Write direct unit tests for all three chain files** — unblocks safe refactoring of everything else; lowest-risk, highest-value action.
2. **(AUTO) Clock injection into `IncidentService`** — precondition for load-shedding tests and drift-tolerance logic; no behaviour change.
3. **(REVIEW) Assert UTC suffix on `detectedAt` in `SLAClock.evaluate`** — prevents silent timezone shift at midnight; requires confirming all event sources.
4. **(DECISION) Load-shedding drift policy** — Zaks to define: acceptable drift threshold, retroactive breach treatment, and whether escalated status is terminal.
