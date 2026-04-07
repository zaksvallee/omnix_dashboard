# Audit: morning_sovereign_report_service.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/morning_sovereign_report_service.dart` (3119 lines)
- Read-only: yes

---

## Executive Summary

The service is structurally coherent and demonstrates disciplined event-sourcing projection. The `generate()` method is well-decomposed into named builder methods, null-safety handling across `fromJson` factories is thorough, and the shift window calculation is correct. The main risks are: a silent exception swallow on ledger verification, a lossy default fallback in `_partnerDispatchStatusFromName`, a binary integrity score misrepresented as a score, two duplicated empty-state constants, and a cluster of untested decision-bucket paths. The file also consolidates all data model classes with the service, which is a long-term structural concern.

---

## What Looks Good

- `generate()` cleanly delegates to named builder methods (`_buildReceiptPolicy`, `_buildSiteActivity`, `_buildVehicleThroughput`, `_buildPartnerProgression`). Each builder is independently testable.
- `fromJson` factories across all model classes consistently use `(field as num?)?.toInt() ?? 0` and `(field as String? ?? '').trim()` — no raw casts that could throw.
- `SovereignReportVehicleVisitException.copyWith` adds the `clearOperatorReviewedAtUtc` escape hatch rather than relying on a nullable sentinel — a deliberate and correct pattern.
- `_compareOccurredAtThenSequence` is extracted as a top-level comparator and reused in both `_buildPartnerProgression` and `_buildVehicleThroughput`.
- `latestCompletedNightShiftEndLocal` is a pure static method with deterministic output — suitable for the existing boundary test.
- `_partnerDispatchStatusFromName` handles both `onSite`/`on_site` and `allClear`/`all_clear`/`canceled` variants — robust deserialization.

---

## Findings

### P1

**Action: REVIEW**

**Silent exception swallow on ledger verification**

`ReplayConsistencyVerifier.verify(nightEvents)` is called inside a bare `catch (_)` block. Any exception — including programmer errors, stack overflows, assertion failures — collapses to `replayVerified = false`. The operator has no visibility into why verification failed, and the failure mode is indistinguishable from a legitimate integrity violation vs. a code bug.

- Evidence: lines 1503–1508
- Why it matters: a bug inside `ReplayConsistencyVerifier` will silently mark the ledger as unverified every night without any trace, causing permanent false negatives on integrity checks.
- Suggested follow-up: Codex should check whether `ReplayConsistencyVerifier.verify` is defined to throw domain exceptions or arbitrary errors, and narrow the catch accordingly.

---

**Action: REVIEW**

**`_partnerDispatchStatusFromName` defaults unknown values to `accepted`**

The switch default arm (line 3107) returns `PartnerDispatchStatus.accepted` for any unrecognized status string. A typo in persisted data, a new enum value added to the partner system, or a schema version mismatch will silently produce `accepted` rather than surfacing an error.

- Evidence: lines 3098–3108
- Why it matters: silent misclassification — a cancelled dispatch with a typo in its stored status becomes an accepted one, skewing all downstream counts (`cancelledCount`, `scoreLabel`, `scoreReason`).
- Suggested follow-up: Codex should validate whether a null-return or explicit `unknown` enum value would be safer here, and whether any tests confirm the fallback assumption.

---

**Action: REVIEW**

**`integrityScore` is binary, not a score**

`integrityScore` is set to either `100` (verified) or `0` (failed) at line 1626. The field name and the model's `int` type imply a graduated metric, but no graduation logic exists. Any consumer rendering this as a percentage bar or threshold check may behave unexpectedly in future if partial verification is added.

- Evidence: line 1626, `SovereignReportLedgerIntegrity` field declaration lines 22–23
- Why it matters: API contract mismatch between the field's implied semantics and actual usage. If a partial replay check is ever introduced, this path will silently break consumer rendering.
- Suggested follow-up: DECISION — is `integrityScore` intended to be a scalar quality metric or simply a boolean expressed as int? If boolean, rename to `hashVerifiedScore` or collapse into `hashVerified`.

---

### P2

**Action: AUTO**

**Duplicated empty `SovereignReportPartnerProgression` constant**

`_buildPartnerProgression` constructs an identical empty-state constant in two separate early-return branches: `events.isEmpty` (lines 1930–1944) and `groupedByDispatch.isEmpty` (lines 1957–1971). The two objects are structurally identical.

- Evidence: lines 1929–1972
- Why it matters: if a field is added to `SovereignReportPartnerProgression`, both branches must be updated. One is consistently missed in practice.
- Suggested follow-up: Codex can extract a single `_emptyPartnerProgression` top-level or static const and reference it in both branches.

---

**Action: REVIEW**

**`loiteringVisitCount` counts across all visit statuses, including active and incomplete**

The loitering check at line 2206–2208 (`if (visit.dwell >= const Duration(minutes: 30))`) is outside the `switch (visit.statusAt(nowUtc))` block. This means active visits (still ongoing at report time) and incomplete visits (no exit recorded) are counted as loitering alongside genuine completed long-stay visits.

- Evidence: lines 2194–2209
- Why it matters: an active patrol vehicle that arrived 45 minutes before shift end will be flagged as a loitering exception. Depending on operational intent, this may be correct or a false positive source.
- Suggested follow-up: DECISION — should loitering be restricted to completed visits only, or is flagging long-active visits intentional?

---

**Action: REVIEW**

**`_sceneReviewDecisionBucket` fallback produces `.incident` for any non-empty posture**

When `decision` is empty but `posture` is non-empty and contains neither 'escalation' nor 'repeat', the function falls through to line 2584–2586 (`if (posture.isNotEmpty) return incident`). A posture like `'routine'` or `'normal'` would be classified as an incident bucket incorrectly.

- Evidence: lines 2558–2588
- Why it matters: posture strings are operator-entered labels. Any legitimate non-alert posture that doesn't match the expected substrings silently becomes an incident count, inflating `incidentAlerts`.
- Suggested follow-up: Codex should check the full set of posture labels used in `MonitoringSceneReviewRecord` to determine whether this default is reachable in production data.

---

**Action: REVIEW**

**`_vehicleExceptionPriority` uses string matching instead of type-safe dispatch**

`_vehicleExceptionPriority` (lines 2543–2556) maps string reason labels to priority ints. The strings are produced by `_vehicleVisitExceptionForVisit` (lines 2392–2402). Any future change to those string literals without updating the priority switch silently reverts to priority `9`.

- Evidence: lines 2392–2402 (producers), 2543–2556 (consumer)
- Why it matters: priority regression is silent — exception sort order breaks without any compiler warning or test failure.
- Suggested follow-up: Codex should introduce a typed `VehicleVisitExceptionReason` enum and replace string-matching with exhaustive switch.

---

**Action: REVIEW**

**Scope key format divergence: `|` vs `::`**

`_vehicleScopeFromKey` parses on `|` (line 2533), while `_partnerScopeKey` builds keys with `::` (line 3083) and `_partnerScopeFromKey` parses on `::` (line 3088). Two different separators for the same concept. The `_partnerScoreboardRows` grouping key uses yet another format: `::` with an extra field (line 2898).

- Evidence: `_vehicleScopeFromKey` line 2533, `_partnerScopeKey` line 3083, `_partnerScoreboardRows` line 2898
- Why it matters: if a scope key is accidentally passed to the wrong parser, the split will silently produce empty or malformed IDs.
- Suggested follow-up: Codex should confirm that vehicle and partner scope keys are never mixed, and consider extracting a single `_scopeKey`/`_scopeFromKey` helper with a consistent separator.

---

## Duplication

**1. Empty partner progression constant (see P2 above)**
- Lines 1930–1944 and 1957–1971
- Centralization candidate: single `_emptyPartnerProgression` const or static getter

**2. `const VehicleThroughputSummaryFormatter()` instantiated at two call sites**
- Lines 2288 and 2378
- Both instantiate a fresh const object. Should be a `static const _formatter` on the service class.

**3. `toStringAsFixed(1)` → `double.parse(...)` rounding pattern**
- Used at lines 1636, 2432–2433, 2942–2946 to round doubles to one decimal place.
- Identical three-expression idiom repeated. Could be extracted as a `_roundToOneDecimal(double)` helper.

**4. Inline sorted list construction pattern**
```dart
final sorted = list.toList(growable: false)..sort(comparator);
```
Repeated at lines 1691–1698, 2245–2246, 2068, 2098. Not harmful, but consistent extraction would reduce noise.

**5. `_latestSuppressedPattern` and `_latestActionTaken` share identical sort + iterate pattern**
- Both (lines 2596–2613 and 2615–2643) sort by `occurredAt` descending and iterate looking for the first matching bucket.
- Only the bucket predicate and output formatting differ.
- Candidate for a shared `_latestReviewEntry(predicate)` helper.

---

## Coverage Gaps

**1. `_sceneReviewDecisionBucket` posture-based fallback path**
- No test exercises the case where `decision` is empty but `posture` is a non-'escalation'/non-'repeat' string.
- Expected result: `.incident`. Risk: the true production value may vary.

**2. `_partnerDispatchStatusFromName` unknown fallback**
- No test passes an unrecognized string to confirm it produces `accepted` silently.
- Should be a named test so the assumption is explicit and visible.

**3. `generate()` called before today's 06:00 local (pre-dawn cross-midnight case)**
- The existing shift boundary test (line 30 of the test file) covers one case. The test at line 48 appears to be post-6am.
- The pre-dawn branch (`nowLocal.isBefore(today0600)`) should have a dedicated test that verifies the window is `yesterday 22:00 – today 06:00`.

**4. `_applyVehicleVisitReviewEvents` with conflicting sequence numbers**
- No test covers the case where two review events for the same `vehicleVisitKey` share the same sequence but different timestamps. The comparator at lines 2311–2316 resolves this by `occurredAt`, but this is not tested.

**5. `_recentActionsSummary` when exactly 1 non-suppressed review exists**
- The function returns `''` when `recentActions.length <= 1` (line 2674). This edge case (1 action → empty summary) is not explicitly tested.

**6. `_buildPartnerProgression` with dispatch IDs that are all empty strings**
- The guard at line 1949 skips events with empty `dispatchId`. A batch of all-empty-ID events would fall through to the `groupedByDispatch.isEmpty` early return. Not covered.

**7. `_vehicleVisitExceptionForVisit` for a completed visit with dwell exactly at boundary values**
- `dwell < 2min` and `dwell >= 30min` thresholds are not tested at their boundary values (exactly 2min, exactly 30min).

---

## Performance / Stability Notes

**1. `_buildPartnerProgression` iterates `events` three times**
- Once to group by dispatch ID (line 1947–1955), once to iterate each group and build chains (line 1986–2067), once for scope grouping within the inner loop (line 1997–2001). The scope grouping accumulates into `groupedByScope` inside the dispatch-group loop, which is correct but the iteration pattern is not immediately obvious — a future maintainer could duplicate work here.

**2. `_buildVehicleThroughput` creates `VehicleThroughputSummary` intermediary only to flatten it**
- Lines 2254–2273 construct a `VehicleThroughputSummary` object. The only consumers are `const VehicleThroughputSummaryFormatter().format(summary)` at line 2288 and the field reads at lines 2275–2286. The intermediate object is purely a formatting convenience. Minor allocation concern on large vehicle ledgers, but not a hot path.

**3. `_recentActionsSummary` does not preserve sort order**
- The function iterates `reviews` in original (unsorted) order (line 2650), collecting non-suppressed entries. `_latestActionTaken` and `_latestSuppressedPattern` both re-sort by `occurredAt` descending. `_recentActionsSummary` does not sort, so "recent" is relative to original event order, not recency. This is a semantic inconsistency rather than a performance concern.
- Evidence: lines 2645–2678 vs. 2615–2643

---

## Recommended Fix Order

1. **Narrow the `catch (_)` in ledger verification** (P1) — the most dangerous silent failure; risk of permanent false negatives with no trace.
2. **Clarify `_partnerDispatchStatusFromName` unknown fallback** (P1) — introduces silent data corruption; either document the assumption or return null/unknown.
3. **Add missing test for pre-dawn shift window boundary** (Coverage) — the branch exists but is not locked by a test.
4. **Resolve `_sceneReviewDecisionBucket` posture fallback** (P2) — add a test that names the assumption and either confirms or corrects `.incident` default.
5. **Fix `_recentActionsSummary` sort-order inconsistency** (Performance/Stability) — trivial to fix, causes semantic drift from the other two summary helpers.
6. **Extract `_emptyPartnerProgression` const** (Duplication/AUTO) — low-risk, prevents future divergence.
7. **Decide `loiteringVisitCount` scope** (P2/DECISION) — product call before any fix.
8. **Extract `VehicleVisitExceptionReason` enum** (P2) — compiler-checked, prevents silent priority regression.
9. **Unify scope key separator** (P2) — prevents future cross-wiring bugs.
10. **Extract `_roundToOneDecimal` helper and shared `_latestReviewEntry` helper** (Duplication/AUTO) — low priority cleanup.
