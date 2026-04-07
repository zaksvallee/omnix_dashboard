# Audit: tactical_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/tactical_page.dart` (~6983 lines)
- Read-only: yes

---

## Executive Summary

`tactical_page.dart` is the most complex single-file UI component in the repo. The responsive layout
logic, fleet scope rail, verification panel, and suppressed-review surface are all well-structured.
The `_TacticalDetailedWorkspaceHost` / `StatefulBuilder` split avoids lifting all state into a single
`StatefulWidget`, which is deliberate and reasonable at this density.

However, three confirmed bugs need immediate attention: (1) command-receipt feedback state is silently
discarded on every rebuild, (2) `GlobalKey` instances are re-created inside the builder on every
rebuild, breaking scroll-to-key, and (3) the map, geofence-alert count, SOS count, and lens anomaly
overlay are all driven by hardcoded stub data — live operational reads are never wired in. There are
also two O(n) event scans on every setState call, several identical code blocks duplicated across
narrow/wide layout paths, and meaningful test gaps on the file's most conditional logic.

Overall risk: **moderate-high**. The stub data issue means the map board is cosmetic, not operational.
The feedback-state bug means the command-receipt rail never shows user-triggered messages on the wide
layout.

---

## What Looks Good

- `_TacticalDetailedWorkspaceHost` cleanly separates one-time-consume semantics from layout state.
  The `_consumeAgentReturnIncidentReferenceOnce` / `_consumeEvidenceReturnReceiptOnce` guards are
  correct and tested.
- `_resolveFocusLinkState` and `_scopeForFocusReference` correctly walk the event stream with a
  latest-event-wins tie-break. The logic is thorough and handles all expected `DispatchEvent`
  subtypes.
- `_buildCctvLensTelemetry` correctly windows to a 6h lookback, applies a provider filter, and
  derives an anomaly trend from two sub-windows. The signal-classification heuristics
  (`fr_match`, `lpr_alert`, risk score ≥ 80) are consistent with the rest of the codebase.
- `_suppressedFleetReviewEntries` correctly caps the list at 4, sorts by review time, and skips
  entries with missing `intelligenceId` or missing review record.
- `_fleetScopeCommandAccent / _fleetScopeCommandHeadline / _fleetScopeCommandDetail` cascade logic
  is coherent and defensive.
- All `onExtendTemporaryIdentityApproval` / `onExpireTemporaryIdentityApproval` futures check
  `context.mounted` before proceeding. No unguarded post-async UI mutations.
- Responsive breakpoint handling (compact / wide / desktop) is layered cleanly and the `embedScroll`
  path correctly wraps columns in `SingleChildScrollView` only when needed.

---

## Findings

### P1 — commandReceipt feedback state is lost on every rebuild
- **Action:** REVIEW
- **Finding:** `commandReceipt` is declared as a local `var` inside the `StatefulBuilder.builder`
  lambda (line 440) and re-initialised from `_initialCommandReceipt(...)` on every call.
  `showTacticalFeedback` (line 479) calls `setState(() { commandReceipt = ... })`, which triggers the
  builder to re-run — immediately overwriting the feedback value with the default receipt.
  The feedback message appears for exactly one frame before vanishing.
- **Why it matters:** On the wide layout, `commandReceipt` is the only feedback mechanism for fleet
  drilldown, tactical handoff, dispatch handoff, coverage resync, and verification-queue actions.
  All of these silently drop their confirmation messages.
- **Evidence:** `tactical_page.dart` lines 440–443 (init), 471–493 (showTacticalFeedback mutation).
- **Suggested follow-up for Codex:** Move `commandReceipt` into `_TacticalDetailedWorkspaceHostState`
  as a persistent field (alongside `_showDetailedWorkspace`), or introduce a second
  `StatefulWidget` that owns this slot.

---

### P1 — GlobalKey instantiated inside StatefulBuilder.builder on every rebuild
- **Action:** AUTO
- **Finding:** `fleetPanelKey` and `suppressedPanelKey` are created with `GlobalKey()` on every
  `StatefulBuilder.builder` call (lines 467–468). A `GlobalKey` must be stable across rebuilds.
  A new key on every build causes the subtree to be torn down and rebuilt instead of updated, which
  means `Scrollable.ensureVisible(targetContext)` calls will find a stale or missing context — the
  scroll is silently skipped or fires on a detached element.
- **Why it matters:** `openWatchActionDrilldown`, `focusFilteredSuppressedReviews`, and
  `onOpenFleetStatus` all depend on these keys to scroll the fleet and suppressed panels into view.
  These scroll actions are currently no-ops or crash silently.
- **Evidence:** Lines 467–468 (key creation), 595–604, 640–649, 694–699 (key lookup + scroll).
- **Suggested follow-up for Codex:** Hoist `fleetPanelKey` and `suppressedPanelKey` into
  `_TacticalDetailedWorkspaceHostState` as instance fields.

---

### P1 — Map board, geofence-alert count, SOS count, and lens anomalies are all hardcoded stubs
- **Action:** DECISION
- **Finding:** `_markers` (line 327), `_geofences` (line 376), and `_anomalies` (line 398) are
  compile-time `const` lists. They are never derived from `events`, `fleetScopeHealth`, or any live
  data source. `geofenceAlerts` (line 539) and `sosAlerts` (line 547) are computed from these stubs,
  not from real telemetry. The map overlay, the SOS/geofence alert banners, and the lens anomaly
  bounding boxes all display fake data in every production environment.
  Additionally, "Active Responders: 8" (line 4245) is hardcoded in `_topBar`.
- **Why it matters:** Controllers reading this page believe they are seeing live tactical state when
  they are not. SOS and geofence banners will fire or not fire regardless of real guard telemetry.
- **Evidence:** Lines 327–426 (stub const lists), 539–553 (alert count derivation), 4245 (top bar).
- **Suggested follow-up for Codex:** Requires a product decision on what live data feeds the map
  (guard telemetry from `guard_sync_repository.dart`, DVR events, etc.). This is not an AUTO fix.

---

### P2 — `_buildCctvLensTelemetry()` and `_scopeForFocusReference()` both run O(n) on every setState
- **Action:** AUTO
- **Finding:** `_buildCctvLensTelemetry()` (line 554 call, 6233 definition) iterates all events with
  `.whereType<IntelligenceReceived>()` plus string `contains` checks on every builder invocation.
  `_resolveFocusLinkState` calls `_scopeForFocusReference` (line 5058), which does a second full
  linear scan over `events` on every rebuild. For an ops session with hundreds of events, both
  methods run on every user interaction (zoom, filter cycle, queue tab change, drilldown selection).
- **Why it matters:** Cumulative O(2n) computation on every setState in the hot path. As session
  event counts grow, this will produce perceptible jank on mid-range Android hardware.
- **Evidence:** Lines 554, 515–519, 6233–6318, 5073–5137.
- **Suggested follow-up for Codex:** Memoize both outputs in the host state. Recompute only when
  `events` or `fleetScopeHealth` change identity (pass as `key` or use a computed hash).

---

### P2 — `_recommendedFleetSummaryDrilldown` uses a for-loop to return the first element
- **Action:** AUTO
- **Finding:** Lines 3830–3836: the function iterates `_availableFleetSummaryDrilldowns` with a
  for-loop and immediately returns the first element, discarding the iteration. This can be replaced
  with `firstOrNull` from the `collection` package (already available in this repo).
- **Evidence:** Lines 3830–3836.
- **Suggested follow-up for Codex:** Replace with
  `_availableFleetSummaryDrilldowns(sections).firstOrNull`.

---

### P2 — `_suppressedReviewPanel` is a crash risk if call-site guard is ever missed
- **Action:** REVIEW
- **Finding:** `_suppressedReviewPanel` calls `entries.first` at line 2847 without a guard.
  Every current call site correctly guards with `suppressedEntries.isNotEmpty`, but the method has
  no internal assertion or early-return for an empty list. Any new render path that forgets the guard
  will throw a `StateError` at runtime.
- **Evidence:** Lines 2847, call sites at 865, 900, 1073, 1104.
- **Suggested follow-up for Codex:** Add `assert(entries.isNotEmpty)` at the top of
  `_suppressedReviewPanel`, or return `const SizedBox.shrink()` if `entries.isEmpty`.

---

### P2 — `wide` variable is a local captured by `showTacticalFeedback` before `LayoutBuilder` sets it
- **Action:** REVIEW
- **Finding:** `wide` is declared `var wide = false` at line 469, then set inside `LayoutBuilder`
  at lines 1215–1220. `showTacticalFeedback` (line 471) closes over `wide` and branches on it.
  Because Dart closures capture variable bindings (not values), any interaction that fires
  `showTacticalFeedback` after the layout pass will correctly read the updated `wide` value.
  However, the value is `false` during the frame before `LayoutBuilder` executes — e.g., in
  `addPostFrameCallback` handlers or if interactions fire during a partial build. The logic is
  correct in the common case but structurally fragile: `wide` is not part of state and has no
  write-protection.
- **Evidence:** Lines 469, 477, 1215–1220.
- **Suggested follow-up for Codex:** Hoist `wide` into host state or compute it once via a
  `LayoutBuilder` at the top level and pass it down explicitly.

---

## Duplication

### 1. `onCycleFilter` switch expression repeated × 3
- **Lines:** 663–668 (wide workspace banner), 806–813 (map board child), 1153–1163 (narrow path).
- **Pattern:** Identical `switch (mapFilter) { all → responding → incidents → all }` expression
  with inline `setState`.
- **Centralization candidate:** Extract a `_cycleMapFilter()` closure defined once in the
  `StatefulBuilder.builder` scope and pass it as a callback.

### 2. `_preferredMarker` + `setState(() => selectedMarkerId = ...)` repeated × 4
- **Lines:** 672–681, 793–803, 845–856, 1141–1151, 1184–1194.
- **Pattern:** Find the preferred marker, guard on null, then `setState(() { selectedMarkerId = ... })`.
- **Centralization candidate:** Define a single `_centerActiveTrack()` closure in the builder scope.

### 3. `Scrollable.ensureVisible` with identical duration/curve repeated × 4
- **Lines:** 600–604, 613–619, 644–650, 695–699.
- **Pattern:** `Scrollable.ensureVisible(ctx, duration: 220ms, curve: Curves.easeOutCubic)`.
- **Centralization candidate:** A single `_scrollToContext(BuildContext ctx)` helper defined once
  in the builder scope (or as a top-level function in the file).

### 4. Primary action label / color cascade repeated × 3
- **Lines:** 2196–2209 (`_fleetScopePanel`), 2854–2863 (`_suppressedReviewPanel`),
  3361–3374 (`_fleetScopeCard`).
- **Pattern:** `hasTacticalLead ? 'OPEN TACTICAL TRACK' : hasDispatchLead ? 'OPEN DISPATCH BOARD' : ...`
  with matching color cascades.
- **Centralization candidate:** Extract `_primaryFleetActionLabel` and `_primaryFleetActionColor`
  helpers or a `_FleetPrimaryAction` value object.

---

## Coverage Gaps

- **commandReceipt feedback logic is not tested.** No test exercises `showTacticalFeedback` on the
  wide layout and verifies that the receipt content changes. The P1 bug above means this would fail
  if such a test existed.

- **GlobalKey scroll behaviour is not tested.** No test checks that tapping a drilldown action
  calls `Scrollable.ensureVisible` on the fleet or suppressed panel. The P1 bug above means any
  such test would fail.

- **Seeded focus state (stub marker injection) is not tested.** The path where
  `focusState == _FocusLinkState.seeded` injects a synthetic `_MapMarker` into the marker list
  (lines 5166–5185) has no coverage.

- **`_buildCctvLensTelemetry` computation logic is not tested.** The 6h windowing, FR/LPR
  classification heuristics, trend derivation, and `suggestedMatchScore` formula are pure logic
  in a method that takes no parameters — a unit test calling it with a known event list would be
  straightforward but is absent.

- **`_scopeForFocusReference` is not tested.** The latest-event-wins tie-break and all the
  `INC-` prefix normalisation logic is untested.

- **Temporary identity approval / expiry flow is not tested.** Neither `onExtendTemporaryIdentityApproval`
  nor `onExpireTemporaryIdentityApproval` futures are exercised in the widget tests. The confirmation
  dialog path (`_confirmExpireTemporaryIdentityApproval`) is also absent from test coverage.

- **Narrow layout fleet scope panel drilldown path is not tested.** Tests cover phone viewport
  stability but do not exercise drilldown selection, clear, or scroll on the narrow path.

- **Empty `suppressedEntries` path is not tested.** The guard condition preventing the crash at
  `entries.first` is never exercised from a test that passes an empty list.

---

## Performance / Stability Notes

- **Two O(n) event scans per setState** (`_buildCctvLensTelemetry` + `_scopeForFocusReference`).
  On a session with 500+ events this is measurable. See P2 finding above.

- **`_fleetScopePanel` calls `VideoFleetScopeHealthSections.fromScopes` twice per rebuild**
  (lines 2149, 2150–2157) plus a third call inside `focusSections` construction (line 2168). For
  large fleet lists, consider computing once and reusing.

- **`_fleetSummaryChips` returns a 15-element `List<Widget>` built unconditionally on every rebuild**
  (lines 3879–4054), including per-chip callbacks with closures. This is fine at current fleet sizes
  but should be noted if `VideoFleetScopeHealthSections` is ever extended.

- **`_heroHeader` contains a nested `LayoutBuilder` inside a `Container` wrapping the full header.**
  Each resize event triggers a full rebuild of the header and all action chips. Consider using
  `OrientationBuilder` or a fixed compact breakpoint if the header becomes a hotspot.

---

## Recommended Fix Order

1. **Move `commandReceipt` into host state** — P1 bug, breaks feedback rail silently, fix is
   mechanical and low-risk.
2. **Hoist `fleetPanelKey` and `suppressedPanelKey` into host state** — P1 bug, breaks all
   scroll-to-fleet actions, fix is two-line field promotion.
3. **Add unit tests for `_buildCctvLensTelemetry` and `_scopeForFocusReference`** — these are
   the densest logic blocks in the file and are completely unguarded.
4. **Memoize `_buildCctvLensTelemetry` and `_scopeForFocusReference`** — performance fix,
   straightforward cache-by-events-identity pattern.
5. **Extract `_cycleMapFilter`, `_centerActiveTrack`, and `_scrollToContext` closures** — removes
   4 duplication blocks, reduces rebuild callback proliferation.
6. **Add `assert(entries.isNotEmpty)` to `_suppressedReviewPanel`** — defensive guard, one line.
7. **Product decision on live map data** — hardcoded stubs require scope clarification before
   any implementation can proceed.
