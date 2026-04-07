# Audit: morning_sovereign_report_service.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/morning_sovereign_report_service.dart`
- Read-only: yes

---

## Executive Summary

The service is functionally coherent and defensively coded — every JSON path has a safe fallback, the shift-window filter is correct, and the partner-dispatch chain builder handles multi-event ordering well. However the file has grown into a god-object (3282 lines, 14+ classes, 1 service) that mixes domain value types, serialisation, and coordination logic in a single compilation unit. There are three concrete bug candidates (loitering count discrepancy, silent suppressed-bucket default, non-chronological recent-actions summary), one dangerous architectural pattern (fire-and-forget BI persistence inside a synchronous `generate()` call), and several coverage gaps against edge cases that are plausibly reachable in production.

---

## What Looks Good

- Every `fromJson` path guards against null, missing keys, and wrong list element types — no unchecked casts.
- `_compareOccurredAtThenSequence` and the `firstOccurrenceByStatus` map correctly deduplicate multi-event dispatch chains without losing data.
- `_applyVehicleVisitReviewEvents` key-lookup by `sovereignReportVehicleVisitExceptionKey` correctly prefers `primaryEventId` over the composite key, and latest-wins selection uses `sequence` as tiebreaker.
- `_delayMinutes` guards negative durations and returns `null` rather than a misleading `0`.
- `_partnerDispatchStatusFromName` handles both `onsite`/`on_site` and `allclear`/`all_clear`/`canceled`/`cancelled` spelling variants.
- `_scheduleVehicleBiPersistence` guards the `null` repository case correctly and logs per-visit errors individually rather than aborting the whole batch.

---

## Findings

### P1 — Bug: `loiteringVisitCount` summary count diverges from `exceptionVisits` list

- **Action: AUTO**
- The counter `loiteringVisitCount` at line 2265 increments for **all visit statuses** where `dwell >= 30 minutes`.
- `_vehicleVisitExceptionForVisit` at line 2556–2558 only tags a visit as `'Loitering visit'` when `status == VehicleVisitStatus.completed` AND `dwell >= 30 min`.
- An `active` visit that has been open for 30+ minutes increments `loiteringVisitCount` but does **not** appear in `exceptionVisits` as a loitering exception. The two numbers visible in the report are therefore inconsistent.
- **Evidence:** `lib/application/morning_sovereign_report_service.dart:2265` (counter), `2556-2558` (exception guard).
- **Suggested follow-up:** Codex should verify whether the intent is to count all statuses (summary) vs. only completed (exception list), and align one or both. If the intent is to match the exception list, the counter at 2265 should be gated on `status == completed`.

---

### P1 — Bug: Empty `decision` + empty `posture` silently buckets as `suppressed`

- **Action: REVIEW**
- `_sceneReviewDecisionBucket` (line 2716) falls through all guards and returns `_SceneReviewDecisionBucket.suppressed` when both `decisionLabel` and `postureLabel` are empty strings.
- A review record where the operator did not fill in either field will inflate `suppressedActions` in the sovereign report.
- This is plausible whenever a review is created programmatically or via a partially-complete workflow.
- **Evidence:** `lib/application/morning_sovereign_report_service.dart:2740-2745`.
- **Suggested follow-up:** Add a fifth bucket (`unknown`) or treat empty-label reviews as `incident` to avoid silent suppression. Review whether any test fixture covers this path.

---

### P1 — Bug: `_recentActionsSummary` does not sort before iterating

- **Action: AUTO**
- `_latestActionTaken` (line 2777) and `_latestSuppressedPattern` (line 2758) both sort `reviews` by `occurredAt` descending before iterating. `_recentActionsSummary` (line 2803) does **not** sort — it iterates in insertion order (the order events arrived from the upstream `reviewedSceneEvents` list).
- The "first" element appended to `recentActions` at line 2832 may not be the most recent action, making `recentActionsSummary` inconsistent with `latestActionTaken`.
- **Evidence:** `lib/application/morning_sovereign_report_service.dart:2803-2833` vs. `2773-2801`.
- **Suggested follow-up:** Add the same sort step used in `_latestActionTaken` before the loop in `_recentActionsSummary`.

---

### P2 — Architectural: `generate()` is not pure — it fires BI persistence as a side effect

- **Action: REVIEW**
- `generate()` is presented as a synchronous report-builder but internally calls `_scheduleVehicleBiPersistence` (line 1665), which fires `unawaited(_persistVehicleBiSnapshots(...))`.
- Any caller that expects `generate()` to be a pure read of events will unknowingly trigger DB writes on every call. This is invisible to callers, untestable without a mock repository, and makes the method non-deterministic in test environments.
- Callers that invoke `generate()` multiple times (e.g. caching re-runs) will create multiple inflight persistence requests for the same data.
- **Evidence:** `lib/application/morning_sovereign_report_service.dart:1532-1722` (`generate`), `1665-1668` (`_scheduleVehicleBiPersistence` call), `2357-2372` (implementation).
- **Suggested follow-up:** Extract persistence into a separate method (`persistVehicleBi(SovereignReport report, ...)`) that callers invoke explicitly after receiving the report. This makes side-effects opt-in and testable.

---

### P2 — Bug: `integrityScore` is always 0 or 100 — binary, not a score

- **Action: DECISION**
- `SovereignReportLedgerIntegrity.integrityScore` is defined as an `int` intended to carry nuance (0–100), but the only production write path at line 1686 sets it to `replayVerified ? 100 : 0`.
- Any UI or downstream consumer expecting a graduated score will receive only extremes.
- **Evidence:** `lib/application/morning_sovereign_report_service.dart:1683-1687`.
- **Suggested follow-up:** Either document that the field is binary (and change type to `bool`), or implement a graduated scoring function using event counts and hash coverage.

---

### P2 — Fragile: `_countReasonToken` uses substring match for compliance metrics

- **Action: REVIEW**
- `_countReasonToken` (line 2903) does a case-insensitive `contains` over map keys to count PSIRA/PDP compliance blocks. If a free-text override reason contains the word `psira` as a substring of a longer phrase (e.g. `"non-psira complaint"`), it gets counted.
- This affects `psiraExpired` and `pdpExpired` in `SovereignReportComplianceBlockage` — values reported to clients.
- **Evidence:** `lib/application/morning_sovereign_report_service.dart:2903-2911`, used at `1598-1601`.
- **Suggested follow-up:** Use word-boundary matching or exact enum comparison rather than substring match for compliance counters.

---

### P3 — Structural: 14+ classes in one 3282-line file

- **Action: DECISION**
- All `SovereignReport*` value types (`SovereignReportLedgerIntegrity`, `SovereignReportAiHumanDelta`, `SovereignReportNormDrift`, `SovereignReportComplianceBlockage`, `SovereignReportSceneReview`, `SovereignReportReceiptPolicy`, `SovereignReportSiteActivity`, `SovereignReportVehicleThroughput`, `SovereignReportVehicleScopeBreakdown`, `SovereignReportVehicleVisitException`, `SovereignReportPartnerProgression`, `SovereignReportPartnerScopeBreakdown`, `SovereignReportPartnerScoreboardRow`, `SovereignReportPartnerDispatchChain`) live alongside the service coordinator in a single file.
- These are domain value objects. Their placement in the application layer violates DDD layer separation and makes it impossible to depend on them from domain code without pulling in infrastructure dependencies.
- **Evidence:** lines 22–1501 (value types), 1503–3227 (service).
- **Suggested follow-up:** Split value types to `lib/domain/reports/` (or `lib/application/reports/` as a minimal step). The service file should import them.

---

### P3 — Duplication: Two identical empty-guard early returns in `_buildPartnerProgression`

- **Action: AUTO**
- Lines 1989-2004 and 2016-2031 return identical `const SovereignReportPartnerProgression(...)` objects — one before grouping (when `events.isEmpty`) and one after grouping (when all events had empty `dispatchId`). The second guard is logically necessary, but the 13-field const literal is copy-pasted verbatim.
- **Evidence:** `lib/application/morning_sovereign_report_service.dart:1989-2031`.
- **Suggested follow-up:** Extract the empty sentinel as a named `static const` on `SovereignReportPartnerProgression` or a local `const _emptyPartnerProgression`, and reference it in both guards.

---

### P3 — Inconsistency: Partner scope key uses `::` but vehicle scope key uses `|`

- **Action: REVIEW**
- `_partnerScopeKey` (line 3244) encodes `clientId::siteId`.
- `_vehicleScopeFromKey` (line 2690) expects `clientId|siteId` (single pipe separator).
- The two key formats are parallel structures doing the same job and look similar in code, but a developer misusing one parser against the other key format will silently get wrong `clientId`/`siteId` values.
- **Evidence:** `lib/application/morning_sovereign_report_service.dart:3244-3256` (partner), `2690-2698` (vehicle).
- **Suggested follow-up:** Standardise to one separator (prefer `|` to match the exception key at line 1495), or add a shared `_scopeKey` helper used by both.

---

## Duplication

| Pattern | Locations | Centralization Candidate |
|---|---|---|
| Identical `const SovereignReportPartnerProgression(...)` empty guard | Lines 1989–2004 and 2016–2031 | `static const _emptyPartnerProgression` |
| Repeated `item.map((key, value) => MapEntry(key.toString(), value))` Map-cast idiom | Lines 595, 604, 613, 623, 633, 651, 671, 690, 713 | `_castMap(Map raw)` helper |
| Repeated `(json['field'] as num?)?.toInt() ?? 0` pattern | Every `fromJson` in every class (~80 occurrences) | `_jsonInt(Object? v)` helper |
| Loitering/short-visit threshold constants (`Duration(minutes: 2)`, `Duration(minutes: 30)`) | Lines 2257, 2265, 2554, 2557 | Named constants `_shortVisitThreshold`, `_loiteringThreshold` |

---

## Coverage Gaps

1. **`_sceneReviewDecisionBucket` with empty decision and empty posture** — no test exercises the fallthrough-to-suppressed path. Given the P1 finding, this is the highest-priority gap.
2. **`_recentActionsSummary` ordering** — no test verifies that the "first" entry in the returned string is the most recent action rather than the first-inserted.
3. **`loiteringVisitCount` vs. exception list count for `active` visits ≥30 min** — not covered. A test with an active 45-minute visit would expose the discrepancy.
4. **`_scheduleVehicleBiPersistence` called multiple times on the same data** — no test verifies idempotency when `generate()` is called twice with the same event list.
5. **`_persistVehicleBiSnapshots` partial failure** — the per-visit catch block continues the loop, but there is no test verifying that a failure on visit N does not prevent visit N+1 from being persisted.
6. **`_countReasonToken` substring collision** — no test uses a reason string that contains the token as a substring of a larger word.
7. **`SovereignReport.fromJson` with a fully missing sub-object** (e.g. `vehicleThroughput` key absent entirely) — the `is Map` guard returns the const default, but no test exercises this path for the newer sub-objects (`vehicleThroughput`, `partnerProgression`).
8. **`_delayMinutes` with negative duration** (event timestamp before dispatch creation) — only partially covered; deserves an explicit test to lock the `null` return.

---

## Performance / Stability Notes

- **`_buildVehicleThroughput` iterates `visits` twice**: once in the main counting loop (line 2248) and again to build `entryCount`/`serviceCount`/`exitCount` inline at lines 2315–2317. These three `visits.where(...).length` calls are O(n) each and execute after the main loop. Not a problem at current volumes but worth noting if vehicle-visit counts grow significantly.
- **`_persistVehicleBiSnapshots` is sequential** (line 2379): all `upsertVisit` calls are awaited one by one inside a `for` loop. For snapshots with many visits this will be slow. Future concern if site visit counts grow; parallelising with `Future.wait` would be straightforward.
- **Report generation re-sorts `reviews` three times** for `_latestActionTaken`, `_recentActionsSummary`, and `_latestSuppressedPattern`. Each creates a copy and sorts it. A single pre-sorted list could be passed to all three.

---

## Recommended Fix Order

1. **P1 — Align `loiteringVisitCount` with exception list** (or document the intended difference). Cheap fix, visible inconsistency in client-facing output.
2. **P1 — Fix `_recentActionsSummary` missing sort**. One-line fix; matches the existing pattern in sibling methods.
3. **P1 — Decide empty-label bucket default in `_sceneReviewDecisionBucket`**. Requires a product decision on what "no label" means, then a test.
4. **P2 — Extract BI persistence from `generate()`** into an explicit caller-controlled method. Architectural change; low implementation risk but needs call-site updates.
5. **P2 — Fix `_countReasonToken` to use word-boundary matching** for compliance counters.
6. **AUTO cleanup — deduplicate empty `partnerProgression` guard literal**.
7. **AUTO cleanup — standardise scope key separator** across vehicle and partner scope helpers.
8. **DECISION — file split** into domain value types and service coordinator.
