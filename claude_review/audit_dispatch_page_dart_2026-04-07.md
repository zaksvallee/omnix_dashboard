# Audit: dispatch_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/dispatch_page.dart`
- Read-only: yes

---

## Executive Summary

`dispatch_page.dart` is ~8,265 lines and is the largest single file in the UI layer. It is a god widget: `_DispatchPageState` contains dispatch projection, partner trend analytics, fleet scope command logic, alarm-state mutation, officer assignment, and all rendering — with no separation of concerns. The file has confirmed bugs (string interpolation, GlobalKey re-creation inside `build()`), widespread hardcoded fake data presented as operational truth, silent state divergence on local alarm mutations, and zero directly testable logic. Risk is high. The complexity makes further growth dangerous.

---

## What Looks Good

- `_resolveFocusReference` is thorough — it walks events to resolve ID, incident reference, and intel-linked dispatch across four resolution strategies.
- `_projectDispatches` and `_ingestEvidenceReturnReceipt` correctly defer `onSelectedDispatchChanged` via `addPostFrameCallback` during `initState` to avoid calling parent callbacks mid-tree build.
- `_confirmClearQueue` and `_confirmExpireTemporaryIdentityApproval` both use `showDialog` and guard the `mounted` check before acting, which is correct.
- `_setDispatchLaneFilter` correctly computes the next selected dispatch before `setState` so selection is never silently lost on filter change.
- `_suppressedDispatchReviewEntries` is capped at 4 entries and sorted before render — appropriate for a side-panel display.
- `_partnerDispatchProgressSummary` sorts by `occurredAt` then `sequence` — correct tie-breaking.
- `VideoFleetScopeHealthCard` receives all its children externally, keeping the card widget clean.

---

## Findings

### P1 — Confirmed Bug: String interpolation on object, not field

- **Action: AUTO**
- **Finding:** Line 4913 uses `'$dispatch.id'` inside a `_metaItem` call. This interpolates the `_DispatchItem` object itself, producing `Instance of '_DispatchItem'` at runtime.
- **Why it matters:** The Dispatch ID shown in the partner progression card within `_dispatchCard` will always display the object's `toString()` instead of the actual ID string. This is a visible data bug in a high-attention area.
- **Evidence:** `lib/ui/dispatch_page.dart:4913`
  ```dart
  _metaItem('Dispatch', '$dispatch.id', color: const Color(0xFF8FD1FF)),
  ```
  Should be `'${dispatch.id}'`.
- **Suggested follow-up:** Codex fix: change `'$dispatch.id'` → `'${dispatch.id}'`.

---

### P1 — Confirmed Bug: GlobalKeys re-created inside `build()`

- **Action: REVIEW**
- **Finding:** Lines 752–756 declare `GlobalKey` instances (`fleetPanelKey`, `suppressedPanelKey`, `commandActionsKey`, `selectedDispatchBoardKey`, `dispatchQueueKey`) as local `final` variables inside `build()`. These are new object instances on every rebuild.
- **Why it matters:** Flutter's `GlobalKey` is supposed to persist across builds. When keys are created locally inside `build()`, they never match on a subsequent rebuild, causing the `Scrollable.ensureVisible` calls in `openSection`, `openWatchActionDrilldown`, and `openLatestWatchActionDetail` to always find `null` contexts. The scroll-to-section feature silently does nothing on every build except the first.
- **Evidence:** `lib/ui/dispatch_page.dart:752–756`
  ```dart
  final fleetPanelKey = GlobalKey();
  final suppressedPanelKey = GlobalKey();
  final commandActionsKey = GlobalKey();
  final selectedDispatchBoardKey = GlobalKey();
  final dispatchQueueKey = GlobalKey();
  ```
- **Suggested follow-up:** Codex: move all five keys to `late final` fields on `_DispatchPageState`.

---

### P1 — State Divergence: `_clearAlarm` local mutation overwritten by next projection

- **Action: REVIEW**
- **Finding:** `_clearAlarm` (lines 2433–2468) directly mutates `_dispatches` by mapping over the list and setting status to `cleared`. However, `_dispatches` is fully re-projected from `widget.events` on every `didUpdateWidget` call when `events` changes. The local status mutation has no backing in the events list, so it is silently overwritten the next time the parent pushes a new `events` list.
- **Why it matters:** A controller clears an alarm via the UI, sees it marked cleared, then a polling update arrives — the alarm reappears as whatever status the event projection computes. This is a silent workflow regression that breaks operational continuity.
- **Evidence:** `lib/ui/dispatch_page.dart:2442–2456` (local mutation), `lib/ui/dispatch_page.dart:506–511` (projection re-trigger in `didUpdateWidget`).
- **Suggested follow-up:** Codex/DECISION: either route `_clearAlarm` through `widget.onExecute` so the event is committed upstream, or maintain a local cleared-dispatch override set that `_projectDispatches` respects.

---

### P1 — State Divergence: `_handleDispatchAction` enRoute mutation same risk

- **Action: REVIEW**
- **Finding:** Same pattern as `_clearAlarm`. `_handleDispatchAction` (lines 7316–7358) maps `_dispatches` to change `pending → enRoute` and `onSite → cleared` locally. These transitions are stored only in memory and will be overwritten by the next `_projectDispatches` run.
- **Why it matters:** The dispatch mutation from pressing "DISPATCH NOW" is not durable. If any re-projection occurs before the parent commits a matching event, the UI reverts to the pre-action state.
- **Evidence:** `lib/ui/dispatch_page.dart:7316–7343`.
- **Suggested follow-up:** Same as `_clearAlarm` — local mutations need upstream event commitment or a durable local override layer.

---

### P2 — Hardcoded Fake Data: AI Call Status panel is fully static

- **Action: DECISION**
- **Finding:** `_alarmCallStatusPanel` (lines 1904–2065) shows "AI CALL STATUS", "CALLING" or "COMPLETED", hardcoded attempt counts ("1" or "2"), hardcoded timestamps ("Last attempt: 23:43"), a hardcoded transcript ("AI: This is ONYX Security calling…"), and hardcoded "REAL EMERGENCY" classification. The only branch is `resolved = dispatch.status != _DispatchStatus.pending`.
- **Why it matters:** Controllers reading this panel in a real operational context will see fabricated call data. There is no connection to any actual telephony or AI-call event type. The panel creates false operational confidence.
- **Evidence:** `lib/ui/dispatch_page.dart:1904–2065`.
- **Suggested follow-up:** DECISION: either remove this panel until real AI-call events are ingested, or wire it to a real event type. Marking fake-data panels clearly as "demo" in the UI is a minimum safety step.

---

### P2 — Hardcoded Fake Data: Transport & Intake and Response Time Breakdown sections

- **Action: DECISION**
- **Finding:** `_systemStatusPanel` (lines 5181–5194) renders `_MetricRow` entries for "Vehicles Ready: 12 / 14", "Officers On Duty: 18 / 20", "Fuel Status: Optimal" — all `const` hardcoded. The Response Time Breakdown section (lines 5342–5365) renders `_BreakdownRow` entries for P1/P2/P3 average times that are also hardcoded constants.
- **Why it matters:** Controllers seeing these panels assume they are live readiness data. They are not. The "Vehicles Ready" and "Officers On Duty" values do not correspond to any modeled state.
- **Evidence:** `lib/ui/dispatch_page.dart:5184–5194`, `lib/ui/dispatch_page.dart:5342–5365`.
- **Suggested follow-up:** DECISION: remove sections or gate them behind a `showDemoSections` flag until real data models exist.

---

### P2 — Hardcoded Fake Data: `_alarmSummary` returns static text per priority

- **Action: REVIEW**
- **Finding:** `_alarmSummary` (lines 2229–2234) returns one of three hardcoded strings based on dispatch priority. All P1 alarms show "Perimeter Breach • North Gate", all P2 show "Motion Sensor • Zone 3 • Garden", all P3 show "AI Motion Alert • Restricted Zone".
- **Why it matters:** These summaries are displayed prominently in the alarm board. Operators making tactical decisions based on these will be misled.
- **Evidence:** `lib/ui/dispatch_page.dart:2229–2234`.
- **Suggested follow-up:** Codex: source the summary from `dispatch.type` or a real event field. Remove the static lookup.

---

### P2 — Hardcoded Fake Data: Officer options and labels are hardcoded string-matching lookups

- **Action: REVIEW**
- **Finding:** `_alarmOfficerOptions` (lines 2162–2176) returns officer names based on whether the site label contains "sandton". `_displayOfficerLabel` (lines 2287–2303) maps `RO-441`, `RO-442`, etc. to names. `_displaySiteLabel` (lines 2237–2262) and `_displayClientLabel` (lines 2264–2284) map raw IDs to labels via hardcoded string contains checks against literal values like "vallee", "north residential", "sandton".
- **Why it matters:** These lookups are fragile and will silently fail for any site/client/officer not explicitly listed. Adding a new client or site requires code changes deep in UI state.
- **Evidence:** `lib/ui/dispatch_page.dart:2162–2303`.
- **Suggested follow-up:** DECISION: move label resolution upstream (domain/application layer), pass resolved labels into `_DispatchItem` or as widget props.

---

### P2 — Structural: Domain and application logic inside UI state

- **Action: REVIEW**
- **Finding:** The following methods contain logic that belongs in the application or domain layer, not in `_DispatchPageState`:
  - `_seedDispatches` — event projection to view model
  - `_resolveFocusReference` — focus resolution across event types
  - `_averageResponseTimeLabel` — KPI computation from events
  - `_partnerDispatchProgressSummary` — aggregation over all events per dispatch
  - `_partnerTrendSummary`, `_partnerTrendLabel`, `_partnerTrendReason`, `_partnerSeverityScore` — trend analytics
  - `_officersAvailable` — derived from events
  - `_injectFocusedDispatchFallback` — dispatch list shaping
- **Why it matters:** None of these are testable without a full widget test harness. Logic drift will compound over time.
- **Evidence:** `lib/ui/dispatch_page.dart:7361–7985`.
- **Suggested follow-up:** REVIEW: extract these into a `DispatchProjectionService` or a `DispatchPageController` that can be unit-tested with raw event lists.

---

### P2 — Structural: `_DispatchPageState` is an untestable god state object

- **Action: REVIEW**
- **Finding:** `_DispatchPageState` is ~7,600 lines. It contains event projection, partner trend analytics, fleet scope command headline generation, alarm-state mutation, officer assignment, receipt ingestion, layout decisions, and all rendering. The widget constructor (`DispatchPage`) has 60+ parameters (lines 333–461).
- **Why it matters:** No unit test can cover the projection logic without mounting the full widget. The constructor surface is so large that callsites are brittle and test setup is prohibitive.
- **Evidence:** `lib/ui/dispatch_page.dart:189–461` (constructor), `lib/ui/dispatch_page.dart:466–8069` (state).
- **Suggested follow-up:** REVIEW: extract a `DispatchBoardController` or view model. Break the page into at least three sub-widgets: `DispatchQueuePanel`, `DispatchAlarmOverview`, `FleetWatchRail`.

---

### P2 — Side Effect in `build()`: `_desktopWorkspaceActive` mutated outside `setState`

- **Action: AUTO**
- **Finding:** Line 759: `_desktopWorkspaceActive = wide` mutates instance state inside `build()`, outside of `setState`. This is used later by `_showDispatchFeedback` to decide between updating `_commandReceipt` or showing a snackbar.
- **Why it matters:** If `build()` is called without a full `setState`, `_desktopWorkspaceActive` reflects the last `build()` layout width, which may lag behind the actual layout. The feedback routing could silently pick the wrong channel.
- **Evidence:** `lib/ui/dispatch_page.dart:759`.
- **Suggested follow-up:** Codex: move `_desktopWorkspaceActive` update into `LayoutBuilder` or derive it from a stored constraint.

---

### P2 — Duplicate ValueKeys in `_dispatchWorkspaceFocusCard`

- **Action: AUTO**
- **Finding:** `ValueKey('dispatch-workspace-filter-pending')` appears at lines 2649 and 2693 within the same render of `_dispatchWorkspaceFocusCard`. Also appears again at lines 2853 and 2862 in the `summaryOnly` branch. Flutter's key uniqueness requirement is violated within the same widget subtree.
- **Why it matters:** Duplicate keys within a sibling list cause Flutter to fail to match elements correctly on rebuild. This can cause state loss or assertion errors in debug mode.
- **Evidence:** `lib/ui/dispatch_page.dart:2649`, `2693`, `2853`, `2862`.
- **Suggested follow-up:** Codex: make all `_workspaceActionChip` keys unique (e.g. suffix with context: `dispatch-workspace-focus-filter-pending` vs `dispatch-workspace-recovery-filter-pending`).

---

### P3 — Performance: Multiple redundant event list scans on every build

- **Action: REVIEW**
- **Finding:** On every `build()` call:
  - `_averageResponseTimeLabel(widget.events)` iterates all events (line 3555).
  - `_suppressedDispatchReviewEntries()` iterates `fleetScopeHealth` and sorts (line 782).
  - `_visibleDispatches()` is called 3+ separate times (lines 775, 876, 3876).
  - `_dispatchCountForFilter` calls `_visibleDispatches()` once per filter chip (4 chips = 4 iterations).
  - `_officersAvailable()` iterates events (line 3562).
  - `_partnerDispatchProgressSummary` is called once per visible dispatch card, each scanning the full event list.
- **Why it matters:** With large event lists and many fleet scopes, these scans accumulate per frame. The fleet scope health panel and partner progression badges both trigger multiple scans per render.
- **Evidence:** `lib/ui/dispatch_page.dart:782`, `3555`, `3562`, `3876`, `4751`, `4159`.
- **Suggested follow-up:** REVIEW: precompute `averageResponseTime`, `officersAvailable`, `suppressedEntries`, `partnerProgressByDispatchId` in `didUpdateWidget` or a derived state object, not inside `build()`.

---

### P3 — Performance: `_partnerDispatchProgressSummary` not memoized, called per card

- **Action: REVIEW**
- **Finding:** Both `_dispatchCard` (line 4751) and `_selectedDispatchBoard` (line 4159) call `_partnerDispatchProgressSummary(dispatch.id)` independently. Each call walks `widget.events.whereType<PartnerDispatchStatusDeclared>()`. With N dispatch cards each calling this method, cost is O(N × events.length) per frame.
- **Evidence:** `lib/ui/dispatch_page.dart:4159`, `4751`.
- **Suggested follow-up:** Codex: compute `final partnerProgressByDispatchId = {...}` once per build (or in `didUpdateWidget`) and pass the result through.

---

### P3 — Bug Suspicion: Seeded placeholder dispatch time refreshes on every projection

- **Action: REVIEW**
- **Finding:** `_injectFocusedDispatchFallback` (lines 7516–7537) creates the seeded placeholder with `dispatchTime: _clockLabel(DateTime.now().toLocal())`. This is called every time `_projectDispatches()` runs, which happens on every `events` change in `didUpdateWidget`. The seeded dispatch's displayed time will tick forward.
- **Why it matters:** Controllers may see the "seeded" placeholder dispatch time change across renders, which is confusing and inconsistent. The time should be fixed at seed creation.
- **Evidence:** `lib/ui/dispatch_page.dart:7532`.
- **Suggested follow-up:** Codex: store the seeded dispatch creation time on first injection (state field), reuse it on subsequent projections if the focus reference hasn't changed.

---

### P3 — Bug Suspicion: `_selectedDispatch` silently falls back to first visible dispatch

- **Action: REVIEW**
- **Finding:** `_selectedDispatch` (lines 739–748) falls back to `source.first` if `_selectedDispatchId` is not found in the visible set. This can occur silently after a filter change or projection update. The parent (`onSelectedDispatchChanged`) is not called when the fallback occurs inside `build()`.
- **Why it matters:** Parent state diverges from UI state: the parent still holds the old `selectedDispatchId` while the UI shows a different dispatch as selected.
- **Evidence:** `lib/ui/dispatch_page.dart:744–748`.
- **Suggested follow-up:** REVIEW: ensure fallback selection is always notified upstream. Consider moving this logic into `_setDispatchLaneFilter` and `_projectDispatches` where `setState` + notification already occurs.

---

### P3 — `_recommendedFleetSummaryDrilldown` uses a loop to return first item

- **Action: AUTO**
- **Finding:** Lines 6463–6469 use `for (final drilldown in list) { return drilldown; }` to return the first available drilldown. This is equivalent to `.firstOrNull` but obscures intent.
- **Evidence:** `lib/ui/dispatch_page.dart:6463–6469`.
- **Suggested follow-up:** Codex: replace with `_availableFleetSummaryDrilldowns(sections).firstOrNull`.

---

### P3 — Priority and type assigned by modulo index, not by event severity

- **Action: REVIEW**
- **Finding:** `_seedDispatches` (lines 7730–7734) assigns priority via `index % 3`. An operator's fifth dispatch is always `p3Medium` regardless of actual event severity. Type is derived from priority (lines 7763–7769) with the same brittleness.
- **Evidence:** `lib/ui/dispatch_page.dart:7730–7734`.
- **Suggested follow-up:** REVIEW: derive priority from actual event fields (e.g. `DecisionCreated` severity, intelligence risk score) or expose a priority field in the domain event.

---

### P3 — `_seedDispatches` falls back to four static placeholder dispatches when events are empty

- **Action: DECISION**
- **Finding:** Lines 7631–7672 return a hardcoded list of four `_DispatchItem` objects with fabricated IDs (`DSP-2441`, etc.) when `decisions.isEmpty`. These appear in the dispatch queue as if they are real operational dispatches.
- **Why it matters:** On a fresh or unconnected deployment, controllers see fabricated incident data. In a security ops context this is operationally dangerous.
- **Evidence:** `lib/ui/dispatch_page.dart:7631–7672`.
- **Suggested follow-up:** DECISION: replace with an empty-state UI or a clearly labeled "demo mode" indicator. Never render fabricated incident data as live.

---

## Duplication

### `_workspaceActionChip` filter chip block

The filter chip block (`_workspaceActionChip` calls for all/pending/cleared/active/board/system) appears three times:
1. In the `selectedDispatch == null` branch of `_dispatchWorkspaceFocusCard` (lines 2649–2724).
2. In the `summaryOnly` branch (lines 2820–2918).
3. In the non-summaryOnly branch (lines 2920–2994).

The only difference is the `summaryOnly` branch adds a trailing text line. The chip lists are ~identical across branches 2 and 3.
- **Centralization candidate:** Extract a `_workspaceFocusCardChips` method that takes `summaryOnly` as a parameter.

### Action-handler pattern repeated across `_trackOfficer`, `_viewCamera`, `_callClient`, `_openAgent`, `_openReport`

All five methods (lines 2316–2403) follow the same pattern:
1. Call `widget.onAutoAuditAction?.call(...)`.
2. Check for a specific callback, call it and return.
3. Fall back to `_showSignalSnack` or `_showDispatchFeedback`.

The only differences are the audit action name, the callback field, and the fallback message. This pattern is repeated five times with near-identical structure.
- **Centralization candidate:** A private `_handoffAction({required String auditKey, required String auditDetail, required VoidCallback? callback, required VoidCallback fallback})` helper.

### `_statusBadge` and `_heroChip` overlap

Both `_statusBadge` and `_heroChip` render a colored rounded pill with a label and foreground/background/border colors. `_statusBadge` adds an `onTap` option and uses `Color.lerp` for foreground. `_heroChip` is the simpler form. These could be unified.

### Compact/stacked layout duplication in `buildWideWorkspace`, `_watchActionFocusBanner`, `_fleetScopeCard`, `_fleetSummaryCommandDeck`

Each of these methods independently implements a `LayoutBuilder` → `compact` boolean → `if (compact) Column(...) else Row(...)` pattern. This pattern appears 7+ times across the file.

---

## Coverage Gaps

- **`_seedDispatches`** — Zero test coverage. The event-to-dispatch-item projection with status resolution, fallback, and limit logic is completely untested. A unit test with a crafted `List<DispatchEvent>` would catch regressions immediately.
- **`_resolveFocusReference`** — No tests for any of the four resolution paths (exact, scope-backed, intel-linked, seeded fallback). This is the most complex state-routing logic in the file.
- **`_handleDispatchAction`** — Untested state machine (pending→enRoute, enRoute stays, onSite→cleared). Each transition has distinct downstream effects.
- **`_partnerTrendSummary` / `_partnerTrendLabel`** — Trend analytics with threshold comparisons (`priorAverage - 0.35`, `priorAverage + 0.35`) are completely untested.
- **`_clearAlarm`** — The cleared-state mutation with fallback to `_callClient` is untested.
- **`_visibleDispatches` filter logic** — The four-lane filter with seeded placeholder exclusion is untested.
- **`_averageResponseTimeLabel`** — Edge cases (no events, negative durations) are untested.
- **Widget-level integration:** No widget test locks the scroll-to-section behavior, the receipt ingestion path, or the `agentReturnIncidentReference` handoff flow.

---

## Performance / Stability Notes

- **`build()` as a computation site:** Multiple O(N) event scans run on every build. For a page that re-renders on every polling update, this scales poorly with event history length.
- **`_suppressedDispatchReviewEntries()` sorts on every build:** The sort is stable but runs on every frame even when `fleetScopeHealth` and `sceneReviewByIntelligenceId` haven't changed.
- **60-parameter constructor:** Every callsite must set or default every parameter. One missing parameter silently gets its default, which may be operationally incorrect (e.g. `supabaseReady = false`, `guardSyncBackendEnabled = false`).
- **`GlobalKey` in `build()` (confirmed):** The `Scrollable.ensureVisible` calls will silently fail on every build after the first.

---

## Recommended Fix Order

1. **P1-A — Fix `'$dispatch.id'` string interpolation bug** (`AUTO`) — one-character fix, confirmed data display bug.
2. **P1-B — Move GlobalKeys to state fields** (`AUTO`) — fixes the silent scroll-to-section failure on every rebuild.
3. **P1-C — Fix duplicate `ValueKey` for filter chips** (`AUTO`) — prevents potential Flutter key assertion errors.
4. **P2-A — Fix `_desktopWorkspaceActive` side effect in `build()`** (`AUTO`) — prevent feedback routing from using stale layout state.
5. **P2-B — Address `_clearAlarm` and `_handleDispatchAction` state divergence** (`REVIEW`) — core operational correctness; requires Zaks decision on event commitment strategy.
6. **P2-C — Remove or gate fake data panels** (`DECISION`) — AI Call Status, Transport & Intake, Response Time Breakdown, and `_seedDispatches` static fallback.
7. **P3-A — Precompute `partnerProgressByDispatchId` and `averageResponseTime` in `didUpdateWidget`** (`REVIEW`) — performance.
8. **P3-B — Extract projection/analytics methods into a testable coordinator** (`REVIEW`) — structural; prerequisite for unit-test coverage.
9. **P3-C — Add unit tests for `_seedDispatches`, `_resolveFocusReference`, `_partnerTrendSummary`** — coverage gap; can only be done after extraction.
10. **P3-D — Replace `_recommendedFleetSummaryDrilldown` loop with `.firstOrNull`** (`AUTO`) — clarity.
