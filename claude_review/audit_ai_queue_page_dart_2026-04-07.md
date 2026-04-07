# Audit: lib/ui/ai_queue_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: lib/ui/ai_queue_page.dart (5845 lines)
- Read-only: yes

---

## Executive Summary

`AIQueuePage` is the most complex single file in the UI layer. At ~5845 lines it combines a 1-second timer loop, business-logic seeding, CCTV board management, stats computation, event matching, priority sorting, and five distinct workspace panels — all inside a single `StatefulWidget` and its private state class. The structural problem is significant but survivable in the near term. There are three concrete bugs that are observable in production (wrong progress bar, unguarded mounted callback, `NEXT_SHIFT` normalisation mismatch), plus a hot-path performance issue that fires every second. Coverage is near-zero for the private domain logic embedded here.

---

## What Looks Good

- `_AiQueueFocusItem` factory constructors give clean separation between action-backed and shadow-site-backed focus items.
- `_effectiveLaneForItems` and `_resolveSelectedFocus` are correct, defensively written, and easy to follow.
- `_ensureSingleExecuting` is a tight, single-purpose guard that is hard to break.
- Lane chip counts are derived from `focusItems` in the same build frame — no stale count risk.
- `didUpdateWidget` correctly guards all three route-selection checks before calling `_syncCctvRouteSelection`.
- `_ingestAgentReturnIncidentReference` defers the consume callback to `addPostFrameCallback`, avoiding calling a parent callback mid-build.
- `dispose()` cancels the ticker correctly.

---

## Findings

### P1 — Bug: Progress bar ignores `paused` state

- **Action: AUTO**
- **Finding:** `LinearProgressIndicator` value is `paused ? progress : progress` — both branches are identical. The bar continues animating during pause because the timer still ticks down (the `_onTick` guard checks `_queuePaused` not `action.status == paused`), but even if that were fixed the bar value would not freeze.
- **Why it matters:** A paused action appears to be counting down to the operator when it is not. This is a safety-relevant display error in a time-sensitive intervention UI.
- **Evidence:** `lib/ui/ai_queue_page.dart:3800` — `value: paused ? progress : progress`
- **Suggested follow-up:** Codex should change the paused branch to `value: progress` (no change needed there) but separately ensure `_onTick` does not decrement `timeUntilExecutionSeconds` for paused actions. Currently `_onTick` only skips decrement for `!= executing`, so a paused action **does** stop decrementing. The bug is purely visual — the expression is a no-op. Codex should confirm the operator intent: should the frozen progress be shown as a frozen bar at `progress`, or at 1.0 (full hold)? This should be labelled `DECISION` if intent is ambiguous.

---

### P1 — Bug: `_NEXT_SHIFT` normalisation mismatch between `_nextShiftDrafts` and `_isNextShiftDraft`

- **Action: AUTO**
- **Finding:** `_nextShiftDrafts` getter (line 5063) compares `metadata['scope'] == 'NEXT_SHIFT'` with no trim or case normalisation. `_isNextShiftDraft` (line 5396) applies `.trim().toUpperCase()`. If any plan arrives with `scope: 'next_shift'` or `scope: ' NEXT_SHIFT '`, `_nextShiftDrafts` returns empty while `_isNextShiftDraft` would return true. The drafts card will not render but `_displayQueuedActions` will also not filter that action out (it calls `_isNextShiftDraft`), so it could appear in both the queued stack and be missed by the drafts rail.
- **Why it matters:** A draft action could appear as a live queued action, triggering a countdown and operator promote/cancel controls on something that should only be in the drafts lane.
- **Evidence:** `lib/ui/ai_queue_page.dart:5063` vs `5396`
- **Suggested follow-up:** Codex should normalise `_nextShiftDrafts` to `(action.metadata['scope'] ?? '').trim().toUpperCase() == 'NEXT_SHIFT'` to match `_isNextShiftDraft`.

---

### P1 — Bug: `onConsumeEvidenceReturnReceipt` called regardless of mounted state

- **Action: REVIEW**
- **Finding:** `_ingestEvidenceReturnReceipt` (line 3380) calls `widget.onConsumeEvidenceReturnReceipt?.call(receipt.auditId)` unconditionally at line 3402, after the `fromInit / mounted / else` block. The `else` branch (line 3398) is reached when `!fromInit && !mounted` — the widget is unmounted — yet the consume callback fires. This tells the parent to discard the receipt while the widget is dead and can never show it. On next mount with the same widget configuration, the receipt will be gone.
- **Why it matters:** Evidence return receipts are one-shot; consuming them when unmounted silently drops them.
- **Evidence:** `lib/ui/ai_queue_page.dart:3380–3402`
- **Suggested follow-up:** Codex should move the `onConsumeEvidenceReturnReceipt` call inside the `mounted` guard branch only, or return early from the `else` path.

---

### P2 — Bug / Performance: `_moShadowSites` getter rebuilds snapshot on every access

- **Action: AUTO**
- **Finding:** `_moShadowSites` is a `get` that calls `_globalPostureService.buildSnapshot(events: widget.events, ...)` on every invocation (line 5066–5073). In `build()`, it is accessed at least four times per frame: once at line 285, once inside `_automationWorkspace` args (line 2012), and again inside `_laneRail` → `_emptyLaneState` at lines 2059–2060, plus any `_focusLane` call during interaction. Additionally, the 1-second `setState` from `_onTick` triggers a full rebuild, so `buildSnapshot` runs at minimum once per second even when the queue is idle.
- **Why it matters:** `buildSnapshot` iterates all events and all scene reviews. With a large event log this becomes expensive on every tick.
- **Evidence:** `lib/ui/ai_queue_page.dart:5066–5073`, called at lines 285, 2012, 2018, 2059–2060, 5264
- **Suggested follow-up:** Codex should cache `_moShadowSites` in a local variable at the top of `build()` and pass it down, or memoize it when `widget.events` / `widget.sceneReviewByIntelligenceId` change in `didUpdateWidget`.

---

### P2 — Bug: `_desktopWorkspaceActive` mutated inside `build()`

- **Action: REVIEW**
- **Finding:** `_desktopWorkspaceActive = useWideLayout` is assigned inside a `LayoutBuilder` callback nested within `buildWorkspaceSection` (line 324), which is called from inside `build()`. Mutating state inside a build callback is prohibited — it will trigger a debug assertion in checked mode and may cause incorrect behaviour in release builds if the layout pass runs more than once in a frame.
- **Why it matters:** Flutter may call `LayoutBuilder` callbacks multiple times per frame. If the first call sets `_desktopWorkspaceActive = true` and a later call sets it to `false`, the context rail visibility check at line 3476 (`if (_desktopWorkspaceActive || _hasPinnedCommandReceipt)`) will be wrong within the same frame.
- **Evidence:** `lib/ui/ai_queue_page.dart:324`
- **Suggested follow-up:** `_desktopWorkspaceActive` should be derived from the known viewport width available at the top of `build()`, not mutated mid-tree. Codex should replace the mutation with a local variable passed through or compute it from `MediaQuery.sizeOf` / the `constraints` already available at the `OnyxPageScaffold` `LayoutBuilder`.

---

### P2 — Bug: Progress bar divisor is hardcoded to 30 seconds

- **Action: REVIEW**
- **Finding:** `final progress = (action.timeUntilExecutionSeconds / 30).clamp(0.0, 1.0)` at line 3514. Actions are seeded with initial countdowns of 27, 45, 72, or arbitrary plan countdown values. An action seeded with 45 seconds starts at `45/30 = 1.5` which clamps to 1.0, so the bar shows 100% full from the start and only begins to visually decay once the counter drops below 30.
- **Why it matters:** The intervention window bar is the primary visual cue for when AI execution will fire. A bar that stays at 100% for the first half of a 45-second countdown misleads controllers.
- **Evidence:** `lib/ui/ai_queue_page.dart:3514`
- **Suggested follow-up:** The divisor should be the action's initial countdown, not 30. This requires either storing the initial value on `_AiQueueAction` or computing it from the seeded value at init time. Codex should verify whether the action model carries an initial countdown field or if it needs to be added.

---

### P2 — Structural: `_seedActions` contains domain logic inside UI state

- **Action: REVIEW**
- **Finding:** `_seedActions` (line 5465–5619) contains: event filtering, closed-dispatch set construction, priority mapping from plan priority to internal enum, action type assignment, fallback demo data, and a descending sort by `_autonomyPlanRank`. `_autonomyPlanRank` itself contains a bias scoring system. This is domain coordination logic — it belongs in `MonitoringWatchAutonomyService` or a dedicated view-model class, not in `_AIQueuePageState`.
- **Why it matters:** The logic is completely untestable without a widget harness. Bugs in rank ordering or event filtering are invisible until a controller sees wrong queue order in production.
- **Evidence:** `lib/ui/ai_queue_page.dart:5465–5637`
- **Suggested follow-up:** Extract `_seedActions` and `_autonomyPlanRank` into the service layer or a dedicated `AiQueueViewModel` that `AIQueuePage` consumes. This is a `REVIEW` item because it requires a new public contract.

---

### P2 — Structural: `_buildDailyStats` is domain logic inside UI state

- **Action: REVIEW**
- **Finding:** `_buildDailyStats` (line 5694–5721) computes a 24-hour windowed approval rate from raw events. It is called once in `initState` and never refreshed — so stats are stale after `didUpdateWidget` delivers new events.
- **Why it matters:** If the event list grows during the session (e.g. via Supabase realtime), today's stats will never update.
- **Evidence:** `lib/ui/ai_queue_page.dart:232` (only call site), `5694–5721`
- **Suggested follow-up:** Codex should (a) call `_buildDailyStats` in `didUpdateWidget` when `events` changes, and (b) move the computation to the application layer.

---

### P2 — Bug: `_visibleCctvAlerts` always returns at most 1 alert (`.take(1)`)

- **Action: REVIEW**
- **Finding:** `_visibleCctvAlerts` (line 1092–1102) filters and sorts, then returns `alerts.take(1).toList()`. The alert panel for the CCTV overview page (`_buildCctvAlertPanel`) only ever shows one alert. If three alerts are seeded from `_seedCctvAlerts`, two are silently dropped. The alert count strip at the top correctly shows the count (from `alerts.length` before the `.take(1)`), so the strip says "3 AI ALERTS" but only 1 is accessible.
- **Why it matters:** Operators believe they are acting on all alerts but two are hidden with no navigation path to reach them.
- **Evidence:** `lib/ui/ai_queue_page.dart:1101` — `return alerts.take(1).toList(growable: false);`
- **Suggested follow-up:** Codex should clarify intent. If single-alert design is intentional, the attention strip count should show only dismissible/active alerts within the visible set. If multi-alert navigation is intended, a selector or list needs to be built. Mark as `DECISION`.

---

### P3 — Bug: `_seedCctvAlerts` uses `DateTime.now()` in a method called multiple times per frame

- **Action: AUTO**
- **Finding:** `_seedCctvAlerts()` computes `occurredLabel` using `DateTime.now()` (line 1203). It is called from both `_visibleCctvAlerts` (line 1093) and `_syncCctvRouteSelection` (line 559). When both are called in the same `build()` cycle, the two invocations may produce slightly different timestamps (milliseconds apart), but more importantly the `feedId` matching in `_syncCctvRouteSelection` and `_visibleCctvAlerts` operates on two independently generated alert lists — alert identity is consistent (derived from `action.id`) but it wastes allocation.
- **Why it matters:** Minor allocation cost and `DateTime.now()` drift between calls. Not an operator-visible bug but a latent inconsistency.
- **Evidence:** `lib/ui/ai_queue_page.dart:559, 1093, 1179–1209`
- **Suggested follow-up:** Memoize `_seedCctvAlerts()` result in `build()` and pass it into `_syncCctvRouteSelection`. Since `_syncCctvRouteSelection` is called from `didUpdateWidget` as well, cache the result for the lifetime of the current `_actions` list.

---

### P3 — Bug: `_dismissCctvAlert` may clear shared feed selection

- **Action: AUTO**
- **Finding:** `_dismissCctvAlert` clears `_selectedCctvFeedId` if it matches `alert.feedId` (line 1173–1175). If two alerts share the same `feedId` (e.g. CAM-03 alerts for two incidents), dismissing one clears the feed selection even though the other alert's feed remains active.
- **Why it matters:** The feed panel deselects, which confuses the operator — they were watching CAM-03 because of a live alert, dismiss one notification, and the camera deselects.
- **Evidence:** `lib/ui/ai_queue_page.dart:1167–1177`
- **Suggested follow-up:** Codex should only clear `_selectedCctvFeedId` if no other remaining visible alert uses that feedId.

---

## Duplication

### 1. `_formatTime` and `_formatChipTime` — identical logic
- `_AIQueuePageState._formatTime` (line 5435) and `_AiQueueFocusItem._formatChipTime` (line 5838) are identical `mm:ss` formatters.
- Files: same file, two locations.
- Centralization candidate: a top-level private function or extension on `int`.

### 2. Button row layout: stacked vs row — duplicated in `_activeAutomationCard`
- Lines 3806–3836 (stacked) and 3838–3868 (row) are two nearly identical button groups (Cancel / Pause-Resume / Approve).
- Centralization candidate: extract `_actionButtonRow` with a `stacked` flag.

### 3. `INTERVENTION WINDOW` copy block — duplicated in `_activeAutomationCard`
- Lines 3718–3750 (stacked) and 3752–3792 (row) duplicate the countdown label, subtitle, and timer display. Only layout differs.
- Centralization candidate: extract `_countdownBlock` with optional `showRow` parameter.

### 4. Recovery deck invocations — 5 call sites with near-identical standby messaging
- `_emptyLaneState`, `_automationStandbyCard`, `_policyEmptyState`, `_focusBanner` null branch, `_contextPanel` null branch all call `_workspaceRecoveryDeck` with the same `_standbyWorkspaceMetrics` and `_standbyWorkspaceActions` helpers.
- No structural fix needed — `_workspaceRecoveryDeck` itself is already the abstraction. But the 5 wrappers each hard-code slightly different eyebrow/title/summary strings that could be consolidated into an enum.

### 5. `promotionPressureSummary` + `promotionExecutionSummary` double-call
- Both are computed together in `_activeAutomationCard` (lines 3516–3519), `_queuedAutomationWorkspaceCard` (lines 2565–2568), `_actionPolicyContent` (lines 2936–2939), and `_queuedRow` (lines 4114–4116).
- Not structurally harmful but signals these two values form a logical pair. Extract into a single `_promotionSignals` record or named tuple.

---

## Coverage Gaps

1. **`_seedActions` branch logic** — three execution paths (autonomy plans, queued decisions, fallback demo data) are untestable without a widget. The priority ranking (`_autonomyPlanRank`) is completely uncovered.

2. **`_buildDailyStats`** — approval rate formula and 24-hour windowing are untestable. No test verifies stale stats after event update.

3. **`_ensureSingleExecuting`** — the auto-promote-next-pending behavior when an action expires or is approved/cancelled has no test. This is a critical path for the autonomy flow.

4. **Timer expiry path** — `_onTick` removing an expired executing action and then calling `_ensureSingleExecuting` to promote the next pending action has no test coverage. A widget test that advances a timer would catch this.

5. **CCTV overview page** — the entire `_buildCctvOverviewPage` path (`viewport >= 1180 && !_showDetailedWorkspace`) has no widget test. Alert count strip, feed tile selection, dispatch guard staging, and dismiss behavior are all unverified.

6. **`_syncCctvRouteSelection`** — the feed-priority / incident-priority selection logic is untested. Edge case: both `initialSelectedFeedId` and `focusIncidentReference` are non-empty simultaneously.

7. **`_ingestEvidenceReturnReceipt` unmounted path** — the `!mounted` else branch that still fires the consume callback has no test.

8. **`_promoteAction` side effects** — promoting demotes the current executing action to `pending`, resets `_laneFilter` to `live`, selects the promoted action — three state mutations. No test verifies the combined post-state.

9. **`_isNextShiftDraft` vs `_nextShiftDrafts` mismatch** — no test covers the case where scope has a different casing or whitespace.

10. **`_resolveSelectedFocus` cross-lane fallback** — the path where `laneItems` is empty and `allItems` is non-empty (lane filter points to empty lane) is not tested. The operator would see the wrong item selected.

---

## Performance / Stability Notes

1. **`_moShadowSites` getter is O(events) and called 4+ times per build, including on every tick.** At 1-second interval with a large event set this is the highest-frequency expensive operation. Cache in `build()` local or `didUpdateWidget`.

2. **1-second `setState` in `_onTick` triggers a full subtree rebuild including all three workspace panels, the lane rail, and the context rail.** Even when no action is executing (queue clear), the ticker still fires and rebuilds the entire page. The guard `if (!mounted || _queuePaused) return` stops decrement but does not stop the setState when the queue is idle. Add an early return if no executing action exists.
   - Evidence: `lib/ui/ai_queue_page.dart:5076–5106`

3. **`_eventIdsForAction` is O(events) per action.** It is called from `_heroHeader` (once for the active action), `_queuedAutomationWorkspaceCard` (once per selected focus), and `_contextPanel` (once per selected focus). In a large event log with many pending actions this adds up during every build frame.

4. **`_seedCctvAlerts` allocates 3 `_CctvBoardAlert` objects on every call.** Called twice per build cycle in the CCTV path. Should be memoized when `_actions` has not changed.

5. **`_buildFocusItems` is called twice in `build()`** — once explicitly at line 286 and a second time inside `_focusLane` if called during interaction, but within `build()` itself the result at line 286 is correctly passed down. Not a live bug, but the pattern invites future callers to re-derive it unnecessarily.

---

## Recommended Fix Order

1. **Fix `_NEXT_SHIFT` normalisation mismatch** (P1 — AUTO) — tiny change, confirmed safety bug, could cause drafts to appear in live queue.
2. **Fix unmounted consume callback** (P1 — REVIEW) — prevent silent evidence receipt drop.
3. **Memoize `_moShadowSites` in `build()`** (P2 — AUTO) — eliminates repeated expensive snapshot calls on every tick.
4. **Skip `_onTick` setState when queue is idle** (P2 — AUTO) — stop rebuilding entire page at 1Hz when nothing is executing.
5. **Fix `_desktopWorkspaceActive` mutation in build** (P2 — REVIEW) — refactor to derive from known viewport rather than mutate mid-tree.
6. **Fix progress bar divisor** (P2 — REVIEW) — requires adding initial countdown to `_AiQueueAction` model.
7. **Clarify single-alert CCTV intent and fix strip count** (P2 — DECISION) — needs product input.
8. **Fix `_dismissCctvAlert` shared feed clear** (P3 — AUTO) — guard against clearing a feed that another alert still references.
9. **Extract `_seedActions` / `_buildDailyStats` to service layer** (P2 — REVIEW) — unlocks unit testability for priority ranking and stats.
10. **Add timer expiry + `_ensureSingleExecuting` widget tests** (coverage gap) — highest-risk untested path in the autonomy flow.
