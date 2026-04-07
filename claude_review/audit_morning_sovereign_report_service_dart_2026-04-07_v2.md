# Audit: morning_sovereign_report_service.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/morning_sovereign_report_service.dart` + `test/application/morning_sovereign_report_service_test.dart`
- Read-only: yes

---

## Executive Summary

The service is well-structured at the logic level: event filtering, shift window derivation, BI persistence, and partner dispatch chain assembly are all clean and correctly typed. The file is however severely overloaded — 3,284 lines containing 12 data model classes, 1 service class, and 4 top-level helpers. This violates single-responsibility and makes targeted testing and change isolation difficult.

Two confirmed display/count bugs were found. One fire-and-forget persistence path has no concurrency guard. The test suite has 8 tests, one of which is a very large integration scenario; several important branches have no coverage at all.

Risk level: **medium**. The data model is sound and the main logic path is well-exercised, but the `_recentActionsSummary` display bug, the loitering count/exception mismatch, and the dual empty-state return duplication should be fixed before new consumers depend on the report structure.

---

## What Looks Good

- Shift window derivation (`latestCompletedNightShiftEndLocal`) is deterministic and tested for the before/after 06:00 boundary.
- All `fromJson` factories defensively handle missing keys, type mismatches, and malformed ISO-8601 strings. Epoch fallback instead of null for required `DateTime` fields is the right choice for a report output model.
- `_partnerDispatchStatusFromName` handles both `onsite`/`on_site` and `allclear`/`all_clear` variants — good defensive serialization.
- `_delayMinutes` correctly returns `null` for negative durations rather than reporting a negative SLA.
- BI persistence errors are caught per-visit, so a single bad record does not abort the batch.
- `_applyVehicleVisitReviewEvents` correctly resolves the latest review event by `(sequence, occurredAt)` ordering instead of insertion order.

---

## Findings

### P1 — Confirmed Bug

**`_recentActionsSummary` always reports `(+1 more)` regardless of actual remaining count.**

- Evidence: `morning_sovereign_report_service.dart` lines 2802–2834.
- The loop breaks after collecting exactly 2 entries, then computes `recentActions.length - 1 = 1` and returns `(+1 more)`. If 10 non-suppressed actions existed, the summary still says `(+1 more)`.
- Why it matters: downstream consumers and Telegram digests showing the morning summary will under-report incident volume, which is an operational safety concern.
- Action: **AUTO**
- Suggested follow-up: Codex should count all non-suppressed entries first, collect only the first 2 for display, then report `(+{totalNonSuppressed - 1} more)`.

---

### P1 — Confirmed Data Inconsistency

**`loiteringVisitCount` in `_buildVehicleThroughput` counts all visits ≥ 30 min (any status), but loitering exception entries only appear for `completed` visits ≥ 30 min.**

- Evidence:
  - Lines 2264–2266: `if (visit.dwell >= const Duration(minutes: 30)) loiteringVisitCount += 1;` — no status guard.
  - Lines 2554–2556: exception `reasonLabel = 'Loitering visit'` only when `status == VehicleVisitStatus.completed` AND `dwell >= 30 min`.
- Why it matters: `vehicleThroughput.loiteringVisitCount` in the serialized report is higher than the number of exceptions labelled "Loitering visit". Any dashboard or consumer doing `loiteringVisitCount == exceptionVisits.where(loitering).length` will see a divergence.
- Action: **REVIEW** — product decision: should loitering apply to incomplete/active visits too? If no, add a `status == completed` guard at line 2264.
- Suggested follow-up: Codex to confirm intended semantics with Zaks, then align the counter with the exception logic.

---

### P2 — Structural Risk

**Fire-and-forget BI persistence has no concurrency guard.**

- Evidence: lines 1664–1667, 2356–2371. `_scheduleVehicleBiPersistence` calls `unawaited(_persistVehicleBiSnapshots(...))` inside the synchronous `generate()` method.
- Why it matters: If `generate()` is called multiple times in quick succession (e.g., a UI that rebuilds on every state change), multiple concurrent persistence futures can be writing the same `clientId/siteId/vehicleKey` rows to the BI repository simultaneously. There is no mutex, debounce, or in-flight guard.
- Action: **REVIEW**
- Suggested follow-up: Codex to check call sites for `generate()` and determine whether rapid re-generation is possible. If so, add an in-flight guard (`_activePersistFuture != null → skip`).

---

### P2 — Silent Error Swallow

**`ReplayConsistencyVerifier.verify` failure swallows the exception and type.**

- Evidence: lines 1554–1559. `catch (_)` discards the entire error.
- Why it matters: `StackOverflowError`, `OutOfMemoryError`, and assertion failures are not `Exception` subtypes in Dart — silently swallowing them prevents diagnosis. Also, the caller has no way to know why verification failed.
- Action: **AUTO**
- Suggested follow-up: Codex to narrow to `catch (e, st)`, log via `_logVehicleBiFailure`, and keep `replayVerified = false`.

---

### P2 — Display Bug Candidate

**`_partnerDispatchScoreLabel` assigns `WATCH` when dispatch reached `allClear` but `acceptedDelayMinutes` is `null`.**

- Evidence: lines 3135–3140.
  ```dart
  if (latestStatus == PartnerDispatchStatus.allClear) {
    if ((acceptedDelayMinutes ?? double.infinity) <= 5 &&
        (onSiteDelayMinutes ?? double.infinity) <= 15) {
      return 'STRONG';
    }
    return 'WATCH'; // ← null delay treated as ∞ → WATCH
  }
  ```
- Why it matters: `acceptedDelayMinutes` is null when the corresponding `DecisionCreated` event is outside the shift window. A partner who reached ALL CLEAR in-window but whose dispatch was created before the shift starts will be classified as `WATCH` instead of `STRONG`. This is a silent scoring error.
- Action: **DECISION** — should a missing `dispatchCreatedAt` mean WATCH, or should allClear with any confirmed on-site window be STRONG?
- Suggested follow-up: Zaks to decide the intended SLA rule for cross-boundary dispatches.

---

### P3 — Count Divergence

**`declarationCount` in `_buildPartnerProgression` uses `events.length` (all input events), not the count of events that had non-empty `dispatchId`.**

- Evidence: line 2165. Events with an empty `dispatchId` are skipped at line 2009 when building `groupedByDispatch`, but `declarationCount` counts them anyway.
- Why it matters: `partnerProgression.declarationCount` reported in the morning summary can be higher than the number of declarations actually attributed to a dispatch chain. Minor but produces a misleading total.
- Action: **AUTO**
- Suggested follow-up: Codex to count only events where `dispatchId.trim().isNotEmpty`.

---

## Duplication

### Empty-state `SovereignReportPartnerProgression` returned twice

- Lines 1989–2003 and 2016–2031 in `_buildPartnerProgression`.
- The first guard is `if (events.isEmpty)`, the second is `if (groupedByDispatch.isEmpty)`.
- The two returned `const` values are byte-for-byte identical.
- Centralization candidate: extract a private `_emptyPartnerProgression()` getter or const field.
- Files: `morning_sovereign_report_service.dart` only.
- Action: **AUTO**

### Dual scope-key delimiter schemes

- `_partnerScopeKey` (line 3246) uses `::` as delimiter; `_vehicleScopeFromKey` (line 2689) uses `|`.
- Both encode `clientId + delimiter + siteId`. The helper functions are separate but the inconsistency adds cognitive load and could cause a copy/paste error if someone applies the wrong parser.
- Action: **REVIEW**

### Verbatim list-parsing block repeated three times in `SovereignReportPartnerProgression.fromJson`

- Lines 827–861: `scopeBreakdowns`, `scoreboardRows`, `dispatchChains` are each parsed with an identical `if (raw is List) { for (final item in raw) { if (item is! Map) continue; ... } }` pattern.
- Same pattern appears in `SovereignReportVehicleThroughput.fromJson` for `scopeBreakdowns` and `exceptionVisits`.
- Centralization candidate: a private top-level helper `_parseJsonList<T>(Object? raw, T Function(Map<String, Object?>) fromJson)` would reduce 5 identical blocks to 5 one-liners.
- Action: **AUTO**

---

## Coverage Gaps

1. **`_recentActionsSummary` with >2 non-suppressed actions** — no test confirms the `(+N more)` count is correct (and it is currently wrong).

2. **Loitering count vs exception mismatch** — no test has an `active` or `incomplete` visit with dwell ≥ 30 minutes to expose the counter/exception divergence.

3. **`_partnerDispatchScoreLabel` for `allClear` with null delays** — not tested. A dispatch arriving in-window but created before the shift window would expose this path.

4. **`declarationCount` inflation from empty `dispatchId` events** — no test passes `PartnerDispatchStatusDeclared` events with an empty `dispatchId` to confirm the count behaviour.

5. **BI `upsertHourlyThroughput` failure path** — `_ThrowingVehicleVisitRepository` at line 944 is a no-op for `upsertHourlyThroughput`. The log path for hourly-throughput persistence failure (lines 2419–2423) is completely untested.

6. **`_cameraLabel` for numeric-only IDs** — covered by the `channel-(\d+)` branch but the `^\d+$` branch (a raw integer camera ID) is not exercised in any test.

7. **Negative duration `_delayMinutes`** — returns `null` but no test confirms this guards against event ordering anomalies (e.g., a declaration timestamped before the decision).

8. **`SovereignReportVehicleVisitException.copyWith(clearOperatorReviewedAtUtc: true)`** — the `clearOperatorReviewedAtUtc` escape hatch is tested implicitly via `_applyVehicleVisitReviewEvents` when `reviewed == false`, but no test directly invokes `copyWith` with the flag.

---

## Performance / Stability Notes

- **Triple iteration over visits in `_buildVehicleThroughput`** (lines 2247–2266, 2287–2298, 2313–2316): vehicle counts, exception generation, and entry/exit counts all iterate the same `visits` list separately. For large visit counts this is O(V × 3). Acceptable now but worth noting if visit volumes scale.

- **`_scheduleVehicleBiPersistence` has no in-flight guard**: If `generate()` is called while a previous persist future is still running (e.g., on every stream event), N concurrent per-visit upsert loops can pile up against the repository. Consider a guard field (`_biPersistInFlight`).

- **`String.split('T').first` on ISO-8601 strings** (line 2448): Correct but fragile. If a `DateTime.toIso8601String()` ever returns a truncated value without `T` (edge case under custom formatting), the date key silently becomes the full string. The `_dateKey` approach (lines 3241–3244) using explicit year/month/day fields is safer and should be preferred.

---

## Recommended Fix Order

1. **Fix `_recentActionsSummary` `(+1 more)` display bug** — P1, AUTO, affects report narrative correctness.
2. **Align `loiteringVisitCount` with exception semantics** — P1, needs DECISION first, then AUTO fix.
3. **Narrow `ReplayConsistencyVerifier` catch** — P2, AUTO, defensive hardening.
4. **Fix `declarationCount` inflation** — P3, AUTO, minor but produces misleading totals.
5. **Extract `_emptyPartnerProgression` deduplication** — AUTO cleanup, low risk.
6. **Extract `_parseJsonList` helper** — AUTO cleanup, reduces boilerplate.
7. **Add BI `upsertHourlyThroughput` failure test** — coverage gap, AUTO.
8. **Add `_partnerDispatchScoreLabel` null-delay DECISION** — blocked on Zaks input.
9. **Add concurrency guard for BI persistence** — P2, REVIEW, depends on call site analysis.
