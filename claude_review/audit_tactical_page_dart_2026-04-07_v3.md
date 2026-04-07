# Audit: tactical_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/tactical_page.dart` (7337 lines)
- Read-only: yes

---

## Executive Summary

`tactical_page.dart` is the largest single file in the repo at ~7337 lines. It is structurally a **god widget**: map rendering, fleet scope command, CCTV telemetry aggregation, verification queue, suppressed review panel, geofence overlays, focus resolution, and three full layout paths all live in one class with no extracted coordinators. The widget is nominally `StatelessWidget` but carries all mutable state inside a nested `StatefulBuilder` with local variables — a pattern that defeats Flutter's normal lifecycle guarantees.

There are several real bugs: `GlobalKey` instances recreated on every `setState`, a `FlutterMap` key that destroys and recreates the tile layer on every zoom step, and `DateTime.now()` captured in the build path causing label drift. Several compute-heavy methods (`_buildCctvLensTelemetry`, `_resolvedIncidentMarkers`, `_suppressedFleetReviewEntries`) run on every rebuild with no memoisation. Duplication of the `onCycleFilter` switch, the `onCenterActive` pattern, and the primary-action-resolution logic across all three layout paths is significant.

Priority: **P1 bugs are real and active. P2 performance issues affect every rebuild. Structural issues are the root cause of most P2/P3 problems.**

---

## What Looks Good

- Strong key coverage on interactive children — `ValueKey` on every actionable widget keeps widget tests stable.
- `_TacticalDetailedWorkspaceHost` correctly isolates consume-once semantics for agent return and evidence receipts with `addPostFrameCallback` + mounted guard.
- `_confirmExpireTemporaryIdentityApproval` uses a local `dialogContext` correctly — no leaked navigator.
- `_resolvedIncidentMarkers` deduplicates events by reference before mapping, preventing duplicate map pins.
- `_scopeForFocusReference` and `_resolveFocusLinkState` handle the seeded/scopeBacked/exact distinction clearly.
- All three layout paths (compact, wide desktop, overview) share the same computed values (markers, bounds, alerts, telemetry) — no per-path data divergence risk.
- `_fleetScopeCommandDetail` uses a fallback cascade over nine candidate text fields, avoiding empty command cells.

---

## Findings

### P1 — GlobalKey Recreated on Every setState

- **Action:** AUTO
- **Finding:** `fleetPanelKey` and `suppressedPanelKey` are declared as `final fleetPanelKey = GlobalKey()` inside `StatefulBuilder.builder` (lines 468–469). They are recreated on every `setState()` call.
- **Why it matters:** Flutter uses `GlobalKey` identity to match widget subtrees across rebuilds. A new `GlobalKey` instance on every rebuild means the subtree is treated as a brand-new widget: its element is unmounted and remounted. This also causes `Scrollable.ensureVisible` (called in `openWatchActionDrilldown`, `focusFilteredSuppressedReviews`, etc.) to get a null `currentContext` immediately after a `setState`, silently skipping the scroll.
- **Evidence:** `lib/ui/tactical_page.dart:468–469`, `lib/ui/tactical_page.dart:600–612`, `lib/ui/tactical_page.dart:649–658`.
- **Suggested follow-up:** Move `fleetPanelKey` and `suppressedPanelKey` to state fields in `_TacticalDetailedWorkspaceHostState` or to a dedicated `StatefulWidget` that wraps the context rail and suppressed panel.

---

### P1 — FlutterMap Key Destroys Tile Layer on Every Zoom / Marker Change

- **Action:** REVIEW
- **Finding:** The `FlutterMap` widget is keyed with a composite string that includes `activeMarker?.id`, `zoom.toStringAsFixed(2)`, and `mapBounds` coordinates (lines 4467–4469). Any zoom step, marker selection, or scope change produces a new key, which Flutter interprets as a completely different widget — the old map element is unmounted, its tile cache is discarded, and a fresh `FlutterMap` is constructed.
- **Why it matters:** This means every zoom-in or zoom-out click discards all downloaded tiles and re-fetches them from OpenStreetMap. On a tactical page that operators use under time pressure, this produces a flickering blank map and unnecessary network traffic every time someone taps Zoom + or selects a marker.
- **Evidence:** `lib/ui/tactical_page.dart:4467–4469`, `lib/ui/tactical_page.dart:792–800`.
- **Suggested follow-up:** Use a `MapController` (from `flutter_map`) to programmatically move/zoom the map without changing its widget identity. Remove all dynamic segments from the `FlutterMap` key; a stable key (e.g. `const ValueKey('tactical-map')`) or no key at all is correct.

---

### P1 — `DateTime.now()` Captured in Build Path Causes Label Drift

- **Action:** AUTO
- **Finding:** `final now = DateTime.now()` is called at line 496 inside `StatefulBuilder.builder`. This value is used to derive `isCombatWindow` (combat vs day mode), `normMode`, and the `_clockLabel(now)` timestamp passed to `_verificationPanel`. Every `setState()` call (zoom, filter change, marker selection, drilldown toggle) re-evaluates `now`.
- **Why it matters:** The `normMode` string (`'night'`/`'day'`) flips at 06:00 and 22:00 without user action. More practically, `_clockLabel(now)` in the verification panel lens display shows the clock at the moment of the most recent rebuild — tapping Zoom+ changes the displayed timestamp. This creates a confusing UX where CCTV timestamps drift with UI interactions.
- **Evidence:** `lib/ui/tactical_page.dart:496–498`, `lib/ui/tactical_page.dart:848–849`.
- **Suggested follow-up:** Capture `now` once at page mount inside a `StatefulWidget` (or in `_TacticalDetailedWorkspaceHostState`) and expose it via the builder. Refresh on a timer if live clock display is intended.

---

### P1 (Suspicion) — `_suppressedReviewPanel` Crashes if Called with Empty List

- **Action:** AUTO
- **Finding:** `_suppressedReviewPanel` calls `entries.first` at line 2857 with no empty guard. The current call sites guard with `suppressedEntries.isNotEmpty` (lines 874–875, 908–909, 1082–1083, 1113–1114), so the crash does not occur today. But the method contract does not enforce this invariant — any future refactor that calls it without the guard will throw `RangeError: Invalid value: Valid value range is empty: 0`.
- **Evidence:** `lib/ui/tactical_page.dart:2857`.
- **Suggested follow-up:** Add an early return or assert at the top of `_suppressedReviewPanel`: `if (entries.isEmpty) return const SizedBox.shrink();`.

---

### P2 — Three Identical `onCycleFilter` Switch Blocks

- **Action:** AUTO
- **Finding:** The map filter cycle logic is copy-pasted verbatim in three places:
  1. Wide workspace status banner callback, lines ~670–677.
  2. Map board `buildWideWorkspace` callback, lines ~814–823.
  3. Narrow `buildSurfaceBody` callback, lines ~1163–1174.
  All three contain the identical `switch (mapFilter) { all → responding → incidents → all }` pattern.
- **Why it matters:** If a new filter value is added, all three copies must be updated. The current code already duplicates a 6-line block three times in the same method.
- **Evidence:** `lib/ui/tactical_page.dart:670–677`, `lib/ui/tactical_page.dart:814–823`, `lib/ui/tactical_page.dart:1163–1174`.
- **Suggested follow-up:** Extract a `_nextMapFilter(_TacticalMapFilter current)` helper that returns the next value in the cycle, and call it from all three callbacks.

---

### P2 — Five Identical `onCenterActive` Closures

- **Action:** AUTO
- **Finding:** The "find preferred marker and assign to `selectedMarkerId`" pattern is duplicated at lines approximately 679–690, 801–813, 854–866, 1151–1163, and 1193–1205. Each closure calls `_preferredMarker(visibleMarkers, focusReference: focusReference)` and then `setState(() { selectedMarkerId = targetMarker.id; })`.
- **Why it matters:** Any change to marker-selection semantics (e.g., adding a null guard or a tie-break) requires updating five sites.
- **Evidence:** Lines 679, 801, 854, 1151, 1193 (search for `onCenterActive`).
- **Suggested follow-up:** Extract a `_centerActiveMarker()` method that captures `visibleMarkers`, `focusReference`, and calls `setState`. Pass it directly where `onCenterActive` is wired.

---

### P2 — Primary-Action Resolution Logic Triplicated

- **Action:** REVIEW
- **Finding:** The pattern `hasTacticalLead ? ... : hasDispatchLead ? ... : canRecoverLead ? ... : openLeadDetail` appears with near-identical structure in three places:
  1. `_fleetScopePanel`, lines ~2206–2314.
  2. `_suppressedReviewPanel`, lines ~2860–2939.
  3. `_fleetScopeCard`, lines ~3371–3384.
  All three compute `hasTacticalLead`, `hasDispatchLane`/`hasDispatchLead`, `canRecover`, `primaryActionLabel`, `primaryActionColor`, and a `primaryAction` callback using the same priority logic.
- **Why it matters:** When action priority or label semantics change (e.g., a new "Escalate" action is introduced), all three blocks must be updated consistently.
- **Evidence:** `lib/ui/tactical_page.dart:2206`, `lib/ui/tactical_page.dart:2860`, `lib/ui/tactical_page.dart:3371`.
- **Suggested follow-up:** Extract a `_fleetScopeActionDescriptor` value object or a helper function that returns `(label, color, action)` given a scope and the available callbacks. All three sites would then call the same resolver.

---

### P2 — `_buildCctvLensTelemetry` and `_resolvedIncidentMarkers` Run on Every Rebuild

- **Action:** REVIEW
- **Finding:** Three expensive operations run inside `StatefulBuilder.builder` on every `setState()`:
  1. `_buildCctvLensTelemetry()` (line 562) — iterates all `IntelligenceReceived` events in `events`, does string parsing on `headline` and `summary`, and computes 8 aggregates.
  2. `_resolvedIncidentMarkers()` (called from `_resolvedMarkers()` at line 521) — builds a `sitePointByScope` map from all site markers, then iterates all events twice (once to deduplicate, once to map).
  3. `_suppressedFleetReviewEntries()` (line 563) — iterates fleet scope health and performs map lookups.
  
  Each of these is O(N) over the events list. With 500+ events (as suggested by recent commit history mentioning "500+ tests"), this is measurable on every `setState` triggered by zoom, filter, or marker tap.
- **Evidence:** `lib/ui/tactical_page.dart:562–564`, `lib/ui/tactical_page.dart:6552–6637`, `lib/ui/tactical_page.dart:5299–5344`.
- **Suggested follow-up:** Move these computations to the parent widget (outside `StatefulBuilder`) or memoize behind a separate `StatefulWidget` that only rebuilds when `events` or `fleetScopeHealth` changes.

---

### P2 — `_scopeForEvent` Called Twice Per Event in `_resolvedIncidentMarkers`

- **Action:** AUTO
- **Finding:** Inside `_resolvedIncidentMarkers`, each event in `events` is processed in a filter loop that calls `_scopeForEvent(event)` (line 5309). Later, the deduplicated map of events is iterated again, and `_scopeForEvent(event)!` is called a second time at line 5329. This doubles the switch dispatch cost for every event that passes the filter.
- **Evidence:** `lib/ui/tactical_page.dart:5307–5344`.
- **Suggested follow-up:** Store the scope result in the first pass: `final scope = _scopeForEvent(event); if (scope == null) continue; latestByReference[reference] = (event: event, scope: scope);` — eliminating the second call.

---

### P3 — `wide` Variable Captured by Closure Before `LayoutBuilder` Sets It

- **Action:** REVIEW
- **Finding:** `var wide = false` is declared at line ~470. `showTacticalFeedback` is a closure defined at line ~472 that branches on `wide`. `wide` is then assigned inside `LayoutBuilder.builder` at line ~1225. The closure captures `wide` by reference from the enclosing `StatefulBuilder` scope, so it reads whatever value `wide` was last assigned. This works because `LayoutBuilder` always runs before any callbacks fire in the same frame. However, the pattern is fragile: if any async callback (e.g., from `onExtendTemporaryIdentityApproval`) fires `showTacticalFeedback` after a frame where `LayoutBuilder` has not yet executed (e.g., during an overlay), the `wide` value will be stale from the previous frame.
- **Evidence:** `lib/ui/tactical_page.dart:470`, `lib/ui/tactical_page.dart:472–494`, `lib/ui/tactical_page.dart:1225–1230`.
- **Suggested follow-up:** Make `wide` a state field rather than a `StatefulBuilder` local, so it is stable between frames.

---

### P3 — Static Hardcoded Map Markers and Geofences

- **Action:** DECISION
- **Finding:** `_markers` (lines 336–378) and `_geofences` (lines 380–397) are `static const` lists hardcoded to Sandton, Johannesburg coordinates with fictional IDs (GUARD-ECHO-3, VEHICLE-R12, INC-8829-QX). These are used as the fallback when `liveMarkers.isEmpty` (line 5227). In a production context, operators will see fictional guard pings and a fake SOS marker whenever no live data is available.
- **Why it matters:** The fallback to `_markers` means a misconfigured or unscoped session shows a completely fake operational picture. This is a demo artefact that is still the live fallback in prod.
- **Evidence:** `lib/ui/tactical_page.dart:336–397`, `lib/ui/tactical_page.dart:5227`.
- **Suggested follow-up (DECISION):** Determine if the static markers should be removed (show empty map instead of fake data) or replaced with a clearly labeled "demo mode" path. Codex should not implement this without Zaks approval.

---

### P3 — `_CctvLensTelemetry` Uses an Inverted Match Score Formula

- **Action:** REVIEW
- **Finding:** The `suggestedMatchScore` is computed at line 6621–6625 as:
  ```dart
  (96 - (anomalies * 10) - (frMatches * 2) - (lprHits * 2)).clamp(35, 98)
  ```
  FR matches and LPR hits subtract from the match score. But FR matches and LPR hits are positive signals — they indicate the system correctly identified known subjects. The formula appears inverted: higher FR/LPR activity lowers the score.
- **Evidence:** `lib/ui/tactical_page.dart:6621–6625`.
- **Suggested follow-up:** Confirm with Zaks whether this formula is intentional (score represents "baseline stability" — more hits = more noise = lower baseline stability) or is a logic error. If inverted, the fix is `(60 + (frMatches * 2) + (lprHits * 2) - (anomalies * 10)).clamp(35, 98)`.

---

## Duplication Summary

| Pattern | Locations | Centralization candidate |
|---|---|---|
| `onCycleFilter` switch block | lines 670, 814, 1163 | `_nextMapFilter(MapFilter)` helper |
| `onCenterActive` closure (5x) | lines 679, 801, 854, 1151, 1193 | `_centerActiveMarker()` method on the stateful host |
| Primary action resolver | lines 2206, 2860, 3371 | `_fleetScopeActionDescriptor(scope)` value type |
| `_scopeForEvent` switch (clientId) | lines 5351–5360, 5154–5163 | Already in `_scopeForEvent` — remove duplication in `_scopeForFocusReference` |
| Action chip color constants for same semantic actions | verification panel, map board, status banner | Named color constants per action type |

---

## Coverage Gaps

- **`_buildCctvLensTelemetry`:** No unit test for the match score formula edge cases (all anomalies, zero events, high FR/LPR counts). The inverted formula suspicion above cannot be validated without a test.
- **`_consumeAgentReturnIncidentReferenceOnce` dedup guard:** Not tested. A duplicate call with the same `normalizedReference` should be a no-op — this is untested.
- **`_resolveFocusLinkState` seeded vs scopeBacked path:** The `_scopeForFocusReference` lookup that promotes `seeded → scopeBacked` is not covered by widget tests.
- **GlobalKey scroll behavior:** `openWatchActionDrilldown` calling `Scrollable.ensureVisible` on `fleetPanelKey.currentContext` — no test confirms the scroll fires or that context is non-null when expected.
- **`_suppressedReviewPanel` empty-list guard:** As noted in P1, the method has no test that calls it defensively with an empty list.
- **FlutterMap key churn:** No test or integration check that the map widget identity is preserved across zoom interactions.
- **`wide` = false branch of `showTacticalFeedback`:** The SnackBar path (narrow layout) is untested in `guards_page_widget_test.dart` (the closest widget test).
- **Combat window mode switch (22:00–06:00):** No test that `isCombatWindow` correctly gates `normMode = 'night'`.

---

## Performance / Stability Notes

- **Hot path computation:** `_buildCctvLensTelemetry`, `_suppressedFleetReviewEntries`, and `_resolvedIncidentMarkers` execute on every `setState`, triggered by zoom, marker tap, filter cycle, or drilldown toggle. With large event lists these will accumulate frame budget.
- **Tile cache destruction on zoom:** The `FlutterMap` key strategy causes full tile re-fetch on zoom, which is a network cost on every zoom tap, not just on initial load.
- **`GoogleFonts.inter()` called inline in build:** Every `GoogleFonts.inter(...)` call at render time performs a cache lookup + `TextStyle` allocation. The file contains hundreds of inline `GoogleFonts.inter(...)` calls. Moving repeated styles to `static const` or `final` class-level fields would reduce allocation pressure.
- **`_fleetSummaryChips` returns 14 tiles unconditionally:** All 14 fleet summary tiles are built and rendered on every fleet panel rebuild regardless of drilldown state. Tiles with zero counts are rendered as grey no-ops. This is not a correctness issue but adds widget tree depth on every pass.

---

## Recommended Fix Order

1. **[P1-BUG] Move `fleetPanelKey` / `suppressedPanelKey` to stable state.** Fixes the null-context scroll bug and subtree churn. (AUTO)
2. **[P1-BUG] Replace FlutterMap key with `MapController`.** Fixes tile cache destruction on zoom. (REVIEW — requires flutter_map MapController wiring)
3. **[P1-BUG] Fix `DateTime.now()` in build path.** Move to mount-time capture. (AUTO)
4. **[P1-FRAGILE] Add empty guard to `_suppressedReviewPanel`.** One-line fix. (AUTO)
5. **[P2-PERF] Extract `_buildCctvLensTelemetry`, `_resolvedIncidentMarkers`, `_suppressedFleetReviewEntries` out of `StatefulBuilder`.** Move to parent or memoize. (REVIEW)
6. **[P2-DUP] Extract `_nextMapFilter` and `_centerActiveMarker` helpers.** Eliminates three and five duplicated blocks respectively. (AUTO)
7. **[P2-DUP] Extract primary-action resolver.** Eliminates triplicated action cascade. (REVIEW)
8. **[P3-DECISION] Static markers demo fallback.** Needs product decision before Codex can act. (DECISION)
9. **[P3-REVIEW] Confirm `suggestedMatchScore` formula intent.** (REVIEW)
10. **[P3] Move repeated `GoogleFonts.inter(...)` styles to class-level constants.** Low risk, incremental cleanup. (AUTO)
