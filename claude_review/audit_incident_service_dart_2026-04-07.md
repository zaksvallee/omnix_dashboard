# Audit: incident_service.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/domain/incidents/incident_service.dart` + supporting chain:
  `lib/domain/incidents/store/incident_state_storage.dart`,
  `lib/infrastructure/persistence/local_event_storage.dart`,
  `lib/domain/incidents/risk/sla_breach_evaluator.dart`,
  `lib/domain/integration/incident_to_crm_mapper.dart`,
  `test/domain/incidents/incident_service_test.dart`
- Read-only: yes

---

## Executive Summary

`IncidentService` is well-designed for its size — injected clock, event-sourced projection, clean delegation to `SLABreachEvaluator` and `IncidentToCRMMapper`. The core happy-path logic is sound and the four existing tests cover the most important scenarios (SLA breach, double-fire guard, retroactive breach on restart).

However, there are four concrete bug candidates, three real coverage gaps, and a structural concern in `LocalEventStorage` that could cause a silent deployment failure. None of these are blocking, but two (double clock call in `overrideSla`, missing clock in `handle` CRM path) are cheap to fix and worth acting on before the service handles production volume.

---

## What Looks Good

- Injected `_clock` parameter makes the service fully testable with a fixed timestamp — consistently applied in `initialize` and `overrideSla`.
- SLA evaluation is stateless (`SLABreachEvaluator.evaluate`) and separated from persistence; the service is a thin coordinator.
- `initialize` captures `nowUtc` once before the loop (L38) — no per-iteration clock drift.
- `_lastSlaEvaluationAtByIncident` guard prevents spurious re-evaluation of the same incident on every `handle` call.
- `_FakeLocalEventStorage` in the test file is a clean, minimal double — no mocking framework noise.
- Test coverage is correctly focused on behavior contracts, not implementation details.

---

## Findings

### P1 — Bug: `overrideSla` calls `_clock()` twice, producing mismatched `eventId` and `timestamp`

- **Action:** AUTO
- `_clock()` is called at L147 to build the `eventId` and again at L150 to build the `timestamp`. If the underlying clock is `DateTime.now`, the two calls can return different instants, making the `eventId` and `timestamp` disagree by microseconds.
- **Why it matters:** The `eventId` is derived from `millisecondsSinceEpoch` of the first call; the `timestamp` is derived from the second call. In fast execution this is usually harmless, but in any environment where clock resolution is coarse (or the two calls straddle a millisecond boundary) the event log will contain an event whose ID and timestamp are not from the same moment — breaking traceability.
- **Evidence:** `incident_service.dart` L147–150
  ```dart
  eventId: 'SLA-OVR-${_clock().toUtc().millisecondsSinceEpoch}',  // call 1
  ...
  timestamp: _clock().toUtc().toIso8601String(),                   // call 2
  ```
- **Suggested follow-up:** Capture `final now = _clock().toUtc();` once at the top of `overrideSla` and use it for both fields.

---

### P1 — Bug: `IncidentToCRMMapper.map` uses real `DateTime.now` in the `handle` path

- **Action:** REVIEW
- In `initialize` (L79–83), `IncidentToCRMMapper.map` is called with `clock: _clock`, so the injected test clock is used when generating `eventId` and `contact_id` in the CRM event.
- In `handle` (L124–128), `clock` is **not passed**, so `IncidentToCRMMapper` falls back to `DateTime.now` for the CRM event ID.
- **Why it matters:** The CRM event generated via `handle` has a non-deterministic ID even in tests. This means any test that tries to assert on the CRM event's `eventId` or `contact_id` will be fragile. More importantly, the inconsistency means a CRM event from `handle` cannot be reproducibly replayed or correlated back to a fixed-clock test scenario.
- **Evidence:** `incident_service.dart` L124–128 vs L79–83; `incident_to_crm_mapper.dart` L14 (`clock ?? DateTime.now`).
- **Suggested follow-up:** Pass `clock: _clock` to `IncidentToCRMMapper.map` in the `handle` method, matching the `initialize` call site.

---

### P2 — Bug: `offline_duration_minutes: null` written to non-retroactive breach metadata

- **Action:** AUTO
- `SLABreachEvaluator.evaluate` uses an irrefutable pattern match to conditionally include `offline_duration_minutes` in metadata (L69 of `sla_breach_evaluator.dart`):
  ```dart
  if (offlineDurationMinutes case final value)
    'offline_duration_minutes': value,
  ```
  In Dart, `if (expr case final value)` is an irrefutable pattern — it matches everything, including `null`. When `handle` calls `evaluate` without passing `offlineDurationMinutes`, the parameter defaults to `null`, and the metadata map will contain `'offline_duration_minutes': null`.
- **Why it matters:** The breach event metadata silently carries a `null` key in every non-retroactive breach. Any downstream consumer that checks for `offline_duration_minutes` presence to distinguish retroactive vs live breaches will get a false positive.
- **Evidence:** `sla_breach_evaluator.dart` L68–70; `incident_service.dart` L111–119 (`handle` path does not pass `offlineDurationMinutes`).
- **Suggested follow-up:** Change the guard to `if (offlineDurationMinutes != null) 'offline_duration_minutes': offlineDurationMinutes!,`.

---

### P2 — Stability: `handle` always persists CRM log even when no CRM event was generated

- **Action:** AUTO
- `handle` unconditionally calls `storage.saveCrm(crmLog.all())` at L136, regardless of whether a CRM event was emitted in this invocation. For the common path (incoming event does not trigger an SLA breach), this is a full no-op write that serializes the entire CRM log to disk unnecessarily.
- **Why it matters:** In a high-throughput environment (e.g., rapid sensor events), this adds one full-log disk write per incident event even when the CRM log has not changed.
- **Evidence:** `incident_service.dart` L135–136.
- **Suggested follow-up:** Only call `storage.saveCrm` inside the `if (crmEvent != null)` block, matching the conditional structure already used in `initialize` (L93–95).

---

### P3 — Structural: `LocalEventStorage` uses relative file paths

- **Action:** REVIEW
- `LocalEventStorage` hardcodes `File('incident_events.json')` and `File('crm_events.json')` as relative paths (L10–11 of `local_event_storage.dart`). These resolve relative to the process working directory, which is non-deterministic in a Flutter app (it is typically the app bundle root on macOS/Linux, a sandboxed temp dir on Android, or the test runner's working directory in tests).
- **Why it matters:** In production, these files may not be written where the operator expects them, or may silently fail to persist between restarts if the working directory changes. In CI, test runs may inadvertently create files in the repo root.
- **Evidence:** `local_event_storage.dart` L10–11.
- **Suggested follow-up:** Inject the file paths (or a `Directory`) as constructor parameters so the caller can resolve the correct app-documents directory via `path_provider`.

---

### P3 — Structural: Double-initialization is not guarded

- **Action:** REVIEW (suspicion, not confirmed)
- `initialize` loads from storage and appends all loaded events into `incidentLog` (L30–33). If `initialize` is called a second time on the same live service instance (e.g., after a profile switch or reconnect), it will append a second copy of every persisted event to `incidentLog`. `IncidentEventLog.append` likely does not deduplicate.
- **Why it matters:** Double-initialization would cause `IncidentProjection.rebuild` to produce incorrect projections, silently doubling event counts and potentially re-firing SLA breach evaluation on already-processed history.
- **Evidence:** `incident_service.dart` L27–33. Behaviour of `IncidentEventLog.append` not verified in this audit pass.
- **Suggested follow-up:** Check whether `IncidentEventLog` deduplicates on `eventId`. If not, add a guard: `if (incidentLog.all().isNotEmpty) return;` at the top of `initialize`, or document that `initialize` must only be called once per instance.

---

## Duplication

### `saveIncidents` + `saveCrm` pair repeated three times

- `initialize` (L90–95, with conditional guards)
- `handle` (L135–136, unconditional pair)
- `overrideSla` (L155, incidents only)

The save-both pattern is structurally identical. A private `_flush({bool incidents = true, bool crm = true})` helper would eliminate the repetition and make the conditional-only-CRM path in `overrideSla` self-documenting.

**Files involved:** `incident_service.dart` L90–95, L135–136, L155.

---

### SLA breach → CRM injection pattern repeated in `initialize` and `handle`

Both `initialize` (L76–87) and `handle` (L121–132) do:
1. `incidentLog.append(slaEvent)`
2. `IncidentToCRMMapper.map(...)`
3. `if (crmEvent != null) crmLog.append(crmEvent)`

The logic is identical except for the `clock` argument inconsistency noted in P1. A private `_applyBreachEvent(IncidentEvent slaEvent, String clientId)` helper would centralize both the append logic and the clock argument, eliminating the inconsistency.

**Files involved:** `incident_service.dart` L76–87, L121–132.

---

## Coverage Gaps

### `overrideSla` is not tested

- No test verifies the emitted `IncidentEvent` structure, that `metadata` contains `operator_id` and `reason`, or that `saveIncidents` was called.
- The double-`_clock()` bug (P1 above) is not caught by any existing test because there is no test for this method at all.
- **Suggested test:** Call `overrideSla`, assert the returned event has `type == incidentSlaOverrideRecorded`, check `metadata['operator_id']` and `metadata['reason']`, and verify `storage.savedIncidents` contains the event.

### Clock-drift event path is not tested via `handle`

- `SLABreachEvaluator` can emit `incidentSlaClockDriftDetected` when `previousEvaluationAtUtc` exists and the time jump exceeds 120 seconds. The `handle` method feeds `_lastSlaEvaluationAtByIncident` as `previousEvaluationAtUtc`, so this path is reachable.
- No test exercises this branch. The emitted drift event would be returned in the `emitted` list and appended to `incidentLog`, but not to `crmLog` — this asymmetry is untested.
- **Suggested test:** Call `handle` twice with a clock that jumps >120s between calls; assert `emitted` contains `incidentSlaClockDriftDetected` and that `crmLog` remains empty.

### Double-initialization guard is untested

- The existing test `'initialize does not double-fire when the incident is already breached'` covers the case where the storage already contains a breach event — it does not cover calling `initialize` twice on the same service instance with an empty storage.
- **Suggested test:** Seed storage with one detected incident. Call `service.initialize(...)` twice. Assert `incidentLog.all()` contains each event only once.

### `storage.loadIncidents()` throwing is not tested

- No test checks what happens when the storage layer throws during `initialize`. The exception will propagate to the caller uncaught. Whether that is the intended behavior should be explicitly documented or tested.

---

## Performance / Stability Notes

- **Full log write on every `handle` call (O(n) per event):** `storage.saveIncidents(incidentLog.all())` serializes the entire event log to JSON on every incoming event. As the log grows, this becomes increasingly expensive. There is no batching, delta write, or append-only strategy. For low-traffic deployments this is fine; at higher throughput or larger log sizes, consider an append-only write or periodic flush.
- **`LocalEventStorage` has no write concurrency guard:** Dart is single-threaded but `Future` scheduling can interleave `handle` calls if called without `await`. Two concurrent writes to the same file could produce partial JSON. Consider using a write lock or queue if `handle` can be called from multiple async paths.

---

## Recommended Fix Order

1. **Pass `clock: _clock` in `handle`'s `IncidentToCRMMapper.map` call** — one-line fix, eliminates non-determinism in the CRM path. (P1 — AUTO after REVIEW)
2. **Capture `_clock().toUtc()` once in `overrideSla`** — one-line fix, eliminates eventId/timestamp mismatch. (P1 — AUTO)
3. **Fix irrefutable null pattern in `SLABreachEvaluator`** — one-line fix, removes silent `null` key in breach metadata. (P2 — AUTO)
4. **Add `overrideSla` test** — closes the largest coverage gap, and would have caught finding #2. (Coverage — AUTO)
5. **Guard `saveCrm` call in `handle`** — move inside `if (crmEvent != null)` block. (P2 — AUTO)
6. **Inject file paths in `LocalEventStorage`** — requires caller change; REVIEW before implementing. (P3 — REVIEW)
7. **Add double-initialization guard or test** — requires verifying `IncidentEventLog.append` deduplication behavior first. (P3 — REVIEW)
