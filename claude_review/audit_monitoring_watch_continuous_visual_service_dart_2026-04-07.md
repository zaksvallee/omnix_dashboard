# Audit: monitoring_watch_continuous_visual_service.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/application/monitoring_watch_continuous_visual_service.dart` + `test/application/monitoring_watch_continuous_visual_service_test.dart`
- Read-only: yes

---

## Executive Summary

The service is well-reasoned at the domain level: the baseline→watching→sustained→persistent change-stage model is solid, the zone/priority classification is coherent, and the cross-camera correlation logic is correctly scoped. Test coverage for the happy paths is good.

However, `sweepScope` is a god method (~270 lines) that mutates state, fetches images, decodes frames, emits candidates, and assembles summaries all in one pass. Three copies of the same camera-error-reset block are a concrete duplication risk. The most consequential bug is that a transient HTTP error during an active streak silently resets all change state, which could suppress a real alert.

Risk level: **medium** — no data-loss risk, but the error-reset path and the god-method shape are the places most likely to produce subtle bugs.

---

## What Looks Good

- The `watching → sustained → persistent` stage progression is clean and testable; the stage-index comparison pattern (`changeStage.index`) is consistent throughout.
- Zone profiles derived from camera labels are stateless and deterministic — easy to unit-test in isolation.
- `_shouldEmitCandidateForStage` correctly guards both stage threshold and cooldown, and the `lastEmittedChangeStage < currentStage` gate prevents duplicate emissions at the same stage without suppressing a later promotion.
- `_baselineFingerprint` uses a per-pixel median across history frames — robust to single-frame noise.
- `_candidateChannelIds` prioritises known cameras and recent intel, then falls back to discovery — sensible ordering.
- Five test scenarios cover the core lifecycle; the cross-camera correlation test is particularly valuable.

---

## Findings

### P1 — Transient error silently resets active change streak

- **Action: REVIEW**
- **Finding:** All three error paths (HTTP non-2xx at line 316, decode failure at line 337, catch block at line 450) reset `changeStreakCount`, `changeActiveSinceUtc`, and `changeStage` to idle on any failure. A single transient connection drop during an active sustained or persistent streak resets the detector as if nothing was ever seen.
- **Why it matters:** A real intruder event could be mid-streak when a camera blips offline for one sweep. The service returns to `watching` stage, and the next candidate won't emit until the streak rebuilds past `minConsecutiveChangeSweeps`. This could delay or drop a genuine alert.
- **Evidence:** `monitoring_watch_continuous_visual_service.dart` lines 318–331, 339–350, 452–463.
- **Suggested follow-up:** Consider preserving `changeStreakCount` and `changeActiveSinceUtc` through a single failed sweep (only reset after N consecutive failures). Codex should validate whether the existing tests cover this path — they do not.

---

### P1 — Three identical camera-error-reset blocks (duplication + fragility)

- **Action: AUTO**
- **Finding:** The same six-field reset sequence (`reachable = false`, `lastSceneDeltaScore = null`, `changeActiveSinceUtc = null`, `changeStreakCount = 0`, `changeStage = idle`, `lastEmittedChangeStage = idle`) is copy-pasted verbatim in three separate error paths.
- **Why it matters:** If the reset logic needs to change (e.g., to preserve streak on transient error per P1 above), all three sites must be updated in sync. A missed site would cause inconsistent behaviour depending on which error occurred.
- **Evidence:** Lines 316–332 (HTTP non-2xx), 337–350 (decode null), 450–464 (catch block).
- **Suggested follow-up:** Extract a `_markCameraUnreachable(_ContinuousVisualCameraState state, String error)` helper. AUTO because it is a pure mechanical extraction.

---

### P2 — `sweepScope` is a god method (~270 lines)

- **Action: REVIEW**
- **Finding:** `sweepScope` (lines 238–507) handles scope key resolution, auth config, per-camera HTTP fetching, image decoding, baseline computation, change-stage advancement, candidate emission, state mutation, and scope snapshot assembly. There is no internal method boundary between these concerns.
- **Why it matters:** Any new requirement (e.g., per-camera timeout backoff, retry logic, new stage type) must be threaded through this single method. It is also difficult to test sub-behaviours in isolation.
- **Evidence:** Lines 238–507.
- **Suggested follow-up:** Codex should assess whether extraction into `_sweepCamera(...)` + `_assembleScopeResult(...)` helpers would be safe. REVIEW because the extraction boundary requires architectural alignment.

---

### P2 — `_snapshotFor` recomputes `hotCamera` and `correlatedGroup` after `sweepScope` already computed them

- **Action: AUTO**
- **Finding:** After `sweepScope` computes `hotCamera` (line 468) and `correlatedGroup` (line 469) to build the summary, it calls `_snapshotFor(scopeKey)!` (line 504), which re-derives both from scratch (lines 522–526). This is a double-compute on every sweep.
- **Why it matters:** At 6 cameras it is cheap, but the pattern means a future bug fix to the ranking logic must be applied in only one place — and the separation makes it easy to miss.
- **Evidence:** Lines 468–473 (in `sweepScope`) vs lines 522–526 (in `_snapshotFor`).
- **Suggested follow-up:** Pass the already-computed `hotCamera` and `correlatedGroup` into `_snapshotFor` instead of recomputing. AUTO because it is a pure refactor with no semantic change.

---

### P2 — `_buildCorrelationGroup` uses `cameras.first` for zone/area metadata

- **Action: REVIEW**
- **Finding:** When grouping cameras by area/zone key, the resulting `_ZoneCorrelationGroup` takes its `zoneLabel`, `watchRuleKey`, and `watchPriorityLabel` from `cameras.first` (lines 1399–1403). The `cameras` list ordering derives from `groups.putIfAbsent` insertion order. If cameras in the same area have different zone classifications (e.g., one tagged Perimeter, one tagged Entry), the group's zone is set by whichever camera was inserted first.
- **Why it matters:** The grouping key only uses area label (not zone), so two cameras with different zones but the same area label will share a group. The group's zone metadata — which drives priority and posture — will be arbitrary.
- **Evidence:** Lines 1399–1403 in `_buildCorrelationGroup`, grouping key at lines 1232–1237 in `_correlatedGroup`.
- **Suggested follow-up:** Consider picking the highest-priority zone from the group's cameras rather than `first`. REVIEW because the correct fallback strategy is a product decision.

---

### P3 — Error paths do not clear camera `history` — stale baseline risk

- **Action: REVIEW**
- **Finding:** On any of the three error paths, `cameraState.history` is left intact (the error resets happen only when `existingCameraState != null`, which is the pre-existing mutable state object — its `history` is never touched). After the camera recovers, it immediately computes a baseline from frames that may predate a significant scene change.
- **Why it matters:** If a camera was repositioned or its lighting changed while it was offline, the stale history will produce a false baseline. The stale-baseline guard at line 364 only fires if `lastSampledAtUtc` exceeds `staleBaselineAfter` — but `lastSampledAtUtc` is not updated during error, so the timer correctly measures elapsed time. This means a camera offline for less than `staleBaselineAfter` (8 minutes) will resume with a potentially invalid baseline.
- **Evidence:** Lines 316–332, 337–350, 450–464 (history not cleared); line 364 (stale guard).
- **Suggested follow-up:** Evaluate whether history should be cleared after N consecutive failures, even if elapsed time < `staleBaselineAfter`. REVIEW — this is a policy decision.

---

### P3 — `_zoneWatchProfileForCameraLabel` allocates two `RegExp` objects on every call

- **Action: AUTO**
- **Finding:** `_zoneWatchProfileForCameraLabel` defines `extractAreaLabel` as a local closure that allocates two `RegExp` objects every time it is called (lines 845–853). This is invoked once per camera per sweep.
- **Why it matters:** At 6+ cameras per sweep and frequent sweep intervals, this is unnecessary repeated allocation. Dart does not statically cache inline `RegExp` literals — only `const` patterns avoid re-allocation.
- **Evidence:** Lines 844–853.
- **Suggested follow-up:** Promote the two `RegExp` instances to `static const` class-level fields. AUTO.

---

### P3 — `_persistentChangeAfterFor` maps both `'entry'` and `'perimeter'` to `perimeterPersistentChangeAfter`

- **Action: DECISION**
- **Finding:** `_persistentChangeAfterFor` (line 1148) returns `perimeterPersistentChangeAfter` for both `'perimeter'` and `'entry'` zone labels. This is despite `entry_watch` and `perimeter_watch` being distinct rule keys with different risk boost values (7 vs 8).
- **Why it matters:** Entry and Perimeter zones share the same persistence threshold. If Entry should have its own timing, the current constructor exposes only `perimeterPersistentChangeAfter` (shared) — there is no `entryPersistentChangeAfter` parameter.
- **Evidence:** Lines 1149–1154.
- **Suggested follow-up:** DECISION — should Entry have its own persistence window separate from Perimeter?

---

## Duplication

| Pattern | Locations | Centralization Candidate |
|---|---|---|
| Camera error reset (6 field assignments) | Lines 318–331, 339–349, 452–462 | `_markCameraUnreachable(state, error)` |
| `hotCamera` + `correlatedGroup` derivation | Lines 468–473 (`sweepScope`) and 522–526 (`_snapshotFor`) | Pass as parameters to `_snapshotFor` |
| `(label ?? '').trim()` null-coalesce pattern | Scattered throughout `_correlatedGroup`, `_buildCorrelationGroup`, `_watchPostureFor` | Acceptable inline — too small to extract |

---

## Coverage Gaps

1. **Transient error mid-streak** — no test verifies whether a single failed sweep during an active change streak resets or preserves the streak.
2. **`clearScope`** — not tested. Confirm it removes all mutable camera state and does not interfere with other scopes.
3. **`staleBaselineAfter` expiry** — no test with a gap between sweeps exceeding 8 minutes. Confirm history clears and status returns to `learning`.
4. **`_resolveStatus` returning `degraded`** — the condition `reachableCameraCount <= 0 && lastError.trim().isNotEmpty` is not tested in isolation.
5. **Zone-specific persistence windows** — `perimeterPersistentChangeAfter` and `outdoorPersistentChangeAfter` are not exercised in any test. No test confirms that a Perimeter camera reaches `persistent` earlier than a default camera.
6. **`maxCamerasPerSweep` and `discoveryProbeLimit` cap** — no test with more than 6 labeled cameras verifies that the correct subset is chosen and discovery channels are capped at 3.
7. **Channel ID ordering with recent intelligence** — no test verifies that cameras appearing in `recentIntelligence` are prioritised over unknown channels.
8. **Multi-camera correlation with mixed zone labels** — no test covering the `_buildCorrelationGroup` first-camera metadata selection when cameras have different zones but the same area key.
9. **`snapshotForScope` before any sweep** — should return `null`; no explicit test.
10. **Empty/invalid image bytes** — `_decodeFrameFingerprint` returns `null` for empty bytes (line 1070), but there is no test for corrupt (non-empty, non-decodable) input.

---

## Performance / Stability Notes

- **`Uint8List.fromList(bytes)` in `_decodeFrameFingerprint` (line 1073):** When the HTTP client returns `Uint8List` (which `http` does via `response.bodyBytes`), `Uint8List.fromList` copies the entire buffer. Pass `response.bodyBytes` as `Uint8List` directly and avoid the copy. The parameter type would need to widen to `Uint8List`, or the caller can cast before passing.
- **`history.removeAt(0)` (line 447):** O(n) list shift. Negligible at `maxHistoryFrames = 6`, but worth noting if the frame history budget grows.
- **Double derivation of `hotCamera` / `correlatedGroup` per sweep** — noted in P2 finding above. Low cost now, creeping cost if camera count grows.

---

## Recommended Fix Order

1. **[P1] Extract `_markCameraUnreachable` helper** — removes the tripled error-reset block; prerequisite to safely modifying streak-preservation policy.
2. **[P1/REVIEW] Streak preservation through transient error** — after the helper exists, evaluate preserving `changeStreakCount` / `changeActiveSinceUtc` for a single missed sweep. Confirm with Zaks.
3. **[AUTO] Pass `hotCamera`/`correlatedGroup` into `_snapshotFor`** — eliminates double-compute and couples the two derivation paths.
4. **[AUTO] Promote `extractAreaLabel` `RegExp` patterns to `static const`** — minor but free allocation win.
5. **[COVERAGE] Add test for transient error mid-streak** — highest-priority missing test.
6. **[COVERAGE] Add test for `staleBaselineAfter` expiry** — confirm history + status reset.
7. **[COVERAGE] Add test for zone-specific persistence windows** — verify perimeter cameras promote to persistent faster than default cameras.
8. **[DECISION] Clarify Entry vs Perimeter persistence window** — decide if `entryPersistentChangeAfter` parameter is needed.
9. **[REVIEW] `sweepScope` decomposition** — lower urgency; surface only after the error-reset and duplication fixes are in place.
