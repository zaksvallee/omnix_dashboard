# Audit: tactical_page.dart (v2)

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/tactical_page.dart` (7,065 lines)
- Read-only: yes

---

## Executive Summary

`TacticalPage` is the largest single UI file in the codebase at ~7,065 lines. It is architecturally coherent — `StatelessWidget` with a single `_TacticalDetailedWorkspaceHost` state owner — but it has grown into a god-widget that owns map rendering, fleet command, verification lens, suppressed-review surfacing, marker/geofence logic, CCTV telemetry aggregation, and full layout branching across three responsive modes. The file is not broken, but it is brittle: any layout change, fleet card update, or domain logic fix requires navigating 7,000 lines with no meaningful extraction boundary.

The two highest-risk bugs are both confirmed: `GlobalKey` objects are re-created on every `StatefulBuilder` rebuild (lines 469–470), and all map/fleet data is hardcoded (`_markers`, `_geofences`, `_anomalies`, `_buildCctvLensTelemetry`) so the rendered tactical map never reflects live state. The v1 audit already flagged these; this v2 confirms they are still present and documents additional duplication.

---

## What Looks Good

- **Idempotent consumption guards** — `_TacticalDetailedWorkspaceHostState` deduplicates `agentReturnIncidentReference` and `evidenceReturnReceipt` using `_lastConsumedAgentReturnIncidentReference` / `_lastConsumedEvidenceReturnAuditId`, plus `addPostFrameCallback` + mounted guard. Solid pattern (lines 212–245).
- **`_scopeForFocusReference` is cleanly extracted** — O(n) linear scan over `events` with deterministic latest-wins semantics; no hidden state (lines 5075–5138).
- **Responsive layout is explicit** — three mode conditions (`compactTacticalLane`, `wide`, `boundedDesktopSurface`) are derived once and passed consistently rather than re-evaluated in nested widgets (lines 1213–1251).
- **`_fleetScopeCommandDetail` candidate chain** — waterfall over ~9 optional text fields with a single empty-trim guard avoids repeated null checks (lines 3806–3830).
- **`AnimatedContainer` on marker lane cards** — 180 ms selection animation is inexpensive and bounded (line 4974).

---

## Findings

### P1 — GlobalKey re-created on every StatefulBuilder rebuild

- **Action: AUTO**
- `fleetPanelKey` and `suppressedPanelKey` are declared as `final` locals at lines 469–470, inside the `StatefulBuilder.builder` callback. This means two fresh `GlobalKey` objects are allocated on every `setState` call that triggers a rebuild. Flutter sees new keys where old ones existed, tears down and remounts the subtrees, and `Scrollable.ensureVisible` may silently fail because the prior context is gone.
- **Evidence:** `lib/ui/tactical_page.dart:469–470`
  ```dart
  final fleetPanelKey = GlobalKey();
  final suppressedPanelKey = GlobalKey();
  ```
- **Why it matters:** `openWatchActionDrilldown` and `focusFilteredSuppressedReviews` call `Scrollable.ensureVisible` using these keys (lines 597–607, 643–651). If the key context has been torn down, `currentContext` is null and the scroll silently no-ops. This is a confirmed UI regression path whenever the user changes a filter or drilldown while the fleet panel is visible.
- **Suggested follow-up:** Codex should move `fleetPanelKey` and `suppressedPanelKey` into `_TacticalDetailedWorkspaceHostState` fields, or extract fleet/suppressed panels into their own `StatefulWidget`s with stable keys.

---

### P1 — Map, geofences, and anomalies are hardcoded demo fixtures

- **Action: REVIEW**
- `_markers`, `_geofences`, and `_anomalies` are `static const` lists of fake data (lines 329–428). `_buildCctvLensTelemetry` at line 6235 reads real `events` and `cctvProvider` to count signals, FR matches, LPR hits, and asset readiness — but the visual map overlays are still stubbed. Guards plotted on the map (`Echo-3`, `Alpha-1`, `Vehicle R-12`, `INC-8829-QX`) bear no relation to runtime `events` or `fleetScopeHealth`.
- **Evidence:** `lib/ui/tactical_page.dart:329–428` (markers, geofences, anomalies all `const`).
- **Why it matters:** An operator reading `INC-8829-QX` on the map while the real incident in scope is different is a tactical reliability failure. Alerting thresholds (`sosAlerts`, `geofenceAlerts`) are computed from these hardcoded lists, not live data.
- **Suggested follow-up:** This is a product/architecture decision — Codex cannot resolve it without a domain model for map markers. Mark as DECISION for Zaks to define the guard/vehicle/incident data contract before Codex implements live marker binding.

---

### P1 — `_suppressedReviewPanel` crashes if called with an empty list

- **Action: AUTO**
- Line 2849: `final focusEntry = entries.first;` — no guard for `entries.isEmpty`. The caller at lines 867–880 and 901–915 only renders the panel when `suppressedEntries.isNotEmpty`, so in normal flow this is safe. But `_suppressedReviewPanel` is a private method with no defensive contract, and `suppressedEntries` is filtered to `take(4)` (line 2833). If a future call-site ever passes an empty list, this throws a `StateError` at runtime with no helpful message.
- **Evidence:** `lib/ui/tactical_page.dart:2849`
- **Suggested follow-up:** Add `if (entries.isEmpty) return const SizedBox.shrink();` at the top of `_suppressedReviewPanel`. AUTO: safe mechanical addition with no logic change.

---

### P2 — `wide` variable mutated inside `LayoutBuilder`, read before assignment

- **Action: REVIEW**
- `wide` is declared as a plain `var` at line 471 (`var wide = false`), inside the `StatefulBuilder.builder` callback. It is assigned inside the nested `LayoutBuilder.builder` at lines 1217–1222. The `showTacticalFeedback` closure at lines 473–495 closes over `wide` from the outer scope. If `showTacticalFeedback` is ever called from a path that runs before `LayoutBuilder` has built (e.g., during an imperative callback triggered from a mounted child before first layout), `wide` will be `false` even on a desktop viewport.
- **Evidence:** `lib/ui/tactical_page.dart:471, 1217–1222, 478–480`
- **Why it matters:** The `showTacticalFeedback` path branches on `wide` to decide snackbar vs. command receipt update. Getting this wrong silently degrades UX on wide viewports.
- **Suggested follow-up:** Codex should validate whether `showTacticalFeedback` can be called before `LayoutBuilder` builds. If yes, lift `wide` into widget state.

---

### P2 — `_headerDispatchAction` builds a fallback `VideoFleetScopeHealthView` with empty IDs, then rejects it

- **Action: AUTO**
- Lines 1281–1297: when `visibleFleetScopeHealth` is empty, `firstWhere` falls back to a `const VideoFleetScopeHealthView` with `clientId: ''` and `siteId: ''`. The very next guard at line 1306 then returns `null` if `targetClientId.trim().isEmpty`. The intermediate allocation of a dead `VideoFleetScopeHealthView` is unnecessary and misleading.
- **Evidence:** `lib/ui/tactical_page.dart:1281–1308`
- **Suggested follow-up:** Replace `firstWhere(…, orElse: () => const VideoFleetScopeHealthView(…))` with a direct null-return when `visibleFleetScopeHealth.isEmpty`. AUTO: purely cosmetic, no logic change.

---

### P2 — `_buildCctvLensTelemetry` iterates all `events` on every rebuild

- **Action: REVIEW**
- `_buildCctvLensTelemetry()` (line 6235) is called unconditionally every time the `StatefulBuilder` rebuilds (line 556). It performs a full linear scan of `events` filtering by `IntelligenceReceived`, provider, and 6h window. For a large event log this is O(n) on every user interaction (filter cycle, marker tap, queue tab change).
- **Evidence:** `lib/ui/tactical_page.dart:556, 6235–6330`
- **Suggested follow-up:** Either memoize the result (pass pre-computed telemetry as a prop from the parent) or use `useMemoized`/derived state so it only recomputes when `events` or `cctvProvider` changes.

---

### P2 — `_scopeForFocusReference` O(n) event scan runs on every rebuild

- **Action: REVIEW**
- `_resolveFocusLinkState` (line 5035) calls `_scopeForFocusReference` (line 5075) on every rebuild if `focusReference` is non-empty and not directly matched. `_scopeForFocusReference` scans all events, pattern-matching against `dispatchId`, `incidentDispatchReference`, `intelligenceId`, and `eventId`.
- **Evidence:** `lib/ui/tactical_page.dart:5060–5072, 5075–5138`
- **Suggested follow-up:** Same as `_buildCctvLensTelemetry` — results should be derived once per `events`/`focusReference` change, not on every frame rebuild.

---

### P3 — `_topBar` hardcodes `'Active Responders': '8'`

- **Action: REVIEW**
- Line 4247: `_topChip('Active Responders', '8', const Color(0xFF8FD1FF))` — hardcoded. This chip is always visible in the tactical overview bar and is never derived from runtime data.
- **Evidence:** `lib/ui/tactical_page.dart:4247`
- **Suggested follow-up:** Either remove the chip or connect it to a real count from `events` or fleet state. REVIEW because changing this touches the public widget interface.

---

### P3 — `_verificationPanel` references `cctvOpsReadiness` and `cctvOpsDetail` via parent instance

- **Action: REVIEW**
- `_verificationPanel` is a private method on `TacticalPage` (a `StatelessWidget`). It references `cctvOpsReadiness` and `cctvOpsDetail` (lines 5425–5430) directly from `this` even though it accepts no explicit props for them. This creates hidden coupling: the method implicitly reads parent-level props, making it hard to extract or test in isolation.
- **Evidence:** `lib/ui/tactical_page.dart:5425–5430`
- **Suggested follow-up:** If `_verificationPanel` is ever extracted to its own widget, these implicit references will cause compilation errors. Document as a coupling risk; lower priority until extraction is planned.

---

## Duplication

### 1. `onCenterActive` inline callback duplicated 3×

The lambda that calls `_preferredMarker(visibleMarkers, focusReference: focusReference)` and `setState(() { selectedMarkerId = targetMarker.id; })` appears identically at:
- Lines 673–684 (inside `buildWideWorkspace > workspaceBanner`)
- Lines 795–806 (inside `buildWideWorkspace > mapBoardChild`)
- Lines 847–857 (inside `buildWideWorkspace > contextRailChild`)

Plus two more in `buildSurfaceBody` (lines 1143–1153, 1186–1196). All five are identical expressions. A named `void _onCenterActive()` local inside `StatefulBuilder` would eliminate all repetition.

### 2. `onCycleFilter` switch expression duplicated 2×

The `mapFilter` cycle switch appears identically at lines 665–671 (workspaceBanner) and lines 808–815 (mapBoardChild), plus a third copy at lines 1155–1165 in the narrow path. A single named callback would cover all three.

### 3. Primary-action resolution pattern duplicated 3×

The `hasTacticalLead → hasDispatchLead → canRecoverLead → detail` chain for computing `primaryActionLabel`, `primaryActionColor`, and `VoidCallback primaryAction` appears in:
- `_fleetScopePanel` (lines 2198–2306)
- `_suppressedReviewPanel` (lines 2856–2931)
- `_fleetScopeCard` (lines 3363–3441)

Each copy computes the same conditional structure against slightly different scope/entry objects. An extracted helper `_resolvePrimaryFleetAction(scope, hasTactical, hasDispatch, canRecover)` would centralize this.

### 4. `RECOMMENDED MOVE` card widget duplicated

The `Container` block rendering "RECOMMENDED MOVE" / action-label is rendered identically at lines 2394–2429 (`_fleetScopePanel`) and lines 3030–3065 (`_suppressedReviewPanel`). Same decoration, padding, layout. Extraction to `_RecommendedMoveCard` would prevent future style drift.

### 5. Queue-tab action-chip row duplicated

The three `_tacticalWorkspaceActionChip` calls for Anomalies / Matches / Assets appear at:
- Lines 1804–1826 (status banner)
- Lines 4924–4946 (`_activeTrackSummaryCard`)
- Lines 5575–5618 (`_verificationPanel`)

All three produce identical chip config. A `_queueTabChips(onSetQueueTab)` helper would consolidate them.

---

## Coverage Gaps

1. **No test for `GlobalKey` scroll behavior** — `openWatchActionDrilldown` and `focusFilteredSuppressedReviews` are untested. There is no test that verifies `Scrollable.ensureVisible` fires (or safely no-ops) when the drilldown changes. `tactical_page_widget_test.dart` does not cover these paths.

2. **No test for `_suppressedReviewPanel` with suppressed entries** — The suppressed review panel with `hasTacticalLane`/`hasDispatchLane` branching is not covered in `tactical_page_widget_test.dart`.

3. **No test for `_resolveFocusLinkState` seeded path** — `_FocusLinkState.seeded` injects a synthetic marker (lines 5176–5186). There is no test that asserts this marker appears in the map overlay or that it is removed when focus resolves to a real scope.

4. **No test for `evidenceReturnReceipt` consumption** — `TacticalEvidenceReturnReceipt` and `onConsumeEvidenceReturnReceipt` are exercised nowhere in the widget test file.

5. **No test for CCTV telemetry aggregation** — `_buildCctvLensTelemetry` is a non-trivial computation (provider filter, 6h window, FR/LPR headline heuristics). There are no unit tests against it; a regression would be invisible until a visual inspection.

6. **No test for `_scopeForFocusReference` across event types** — The switch-match over 7 event types with `INC-` prefix normalization is business logic embedded in the UI layer with no dedicated test.

---

## Performance / Stability Notes

1. **`_buildCctvLensTelemetry` on every rebuild** — Confirmed O(n) linear scan of `events` on every `setState`. For an ops session with hundreds of intelligence events this degrades scroll and filter responsiveness. Memoize or derive upstream.

2. **`_scopeForFocusReference` on every rebuild** — Same pattern; confirmed O(n) event scan triggered on each `StatefulBuilder` rebuild when `focusReference` is non-empty.

3. **`GlobalKey` churn on every rebuild** — Two `GlobalKey()` allocations per rebuild (lines 469–470). Each allocation is cheap individually, but combined with Flutter's identity check on keys, this forces subtree remounts more often than necessary.

4. **`_fleetSummaryChips` builds 14 tiles unconditionally** — `_fleetSummaryChips` (line 3881) returns 14 `_fleetSummaryTile` widgets regardless of whether their counts are zero. Tiles with `count == 0` and no `onTap` are inert but still allocated. Low impact unless fleet sections grow.

5. **`_mapPanel` uses `MediaQuery.sizeOf(buildContext)` for a stepped height** — Lines 4393–4398 call `MediaQuery.sizeOf` inside a method that is itself inside `LayoutBuilder`. `LayoutBuilder` already provides `constraints`; relying on `MediaQuery.sizeOf` adds a redundant dependency on the ambient media query and will cause an extra rebuild if screen size changes (e.g., keyboard appears on a tablet).

---

## Recommended Fix Order

1. **Move `GlobalKey` objects to stable state (P1)** — Highest-impact bug fix. Prevents silent scroll failures on drilldown changes. AUTO.

2. **Guard `_suppressedReviewPanel` for empty entries (P1)** — One-line defensive guard. AUTO.

3. **Fix `_headerDispatchAction` empty-fallback pattern (P2)** — Dead allocation path. AUTO.

4. **Memoize `_buildCctvLensTelemetry` and `_scopeForFocusReference` (P2)** — Move computations upstream or cache keyed on `events`+`cctvProvider`. REVIEW.

5. **Consolidate `onCenterActive` / `onCycleFilter` closures (Duplication #1, #2)** — Single named callbacks inside `StatefulBuilder`. AUTO.

6. **Extract `_RecommendedMoveCard` and `_queueTabChips` (Duplication #4, #5)** — Prevents future style drift between fleet panel and suppressed panel. AUTO.

7. **Add `_buildCctvLensTelemetry` unit tests (Coverage Gap #5)** — Hidden business logic in UI layer needs a dedicated test before any telemetry refactor. REVIEW.

8. **DECISION: define live marker data contract** — Map markers, geofences, and anomalies must be connected to runtime domain data before the tactical map can be trusted in production. Blocked on product and architecture decision.
