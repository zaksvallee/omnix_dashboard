# Audit: lib/ui/ai_queue_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/ai_queue_page.dart` (5861 lines)
- Read-only: yes

---

## Executive Summary

`AIQueuePage` is the largest single file in the UI layer. It functions as a god widget: it owns queue state, domain seeding, layout orchestration, CCTV page routing, timer management, stats computation, and autonomy plan ranking — all inside one `StatefulWidget`. The architecture is functional but accumulates compounding risk: every tick triggers a full rebuild that re-derives expensive computed values; direct state mutation inside `build()` bypasses `setState`; and duplicated tile/pill/formatting primitives are scattered across the file.

The most urgent bugs are: (1) `_moShadowSites` rebuilds the full global snapshot on every access, called multiple times per tick; (2) `_desktopWorkspaceActive` is mutated inside a `LayoutBuilder` callback without `setState`; and (3) stale `_selectedFocusId` is never cleared after `widget.events` changes. These are all concrete, evidence-backed bugs.

---

## What Looks Good

- `_onTick` / `_cancelAction` / `_approveAction` / `_promoteAction` follow a clean pattern: mutate a local copy inside `setState`, then call helpers and post feedback after. No async gaps between mutation and render.
- `_ingestEvidenceReturnReceipt` and `_ingestAgentReturnIncidentReference` correctly guard `mounted` before calling `setState`.
- `_resolveSelectedFocus` gracefully degrades from lane match → lane-first → all-items → null.
- `_buildFocusItems` and the lane chip system make the queue navigation model legible.
- All destructive action buttons (`CANCEL`, `APPROVE`) are correctly guarded behind explicit `onPressed` callbacks, not fire-and-forget futures.
- `_effectiveLaneForItems` auto-recovers to the first non-empty lane if the selected lane is empty — good UX.

---

## Findings

### P1 — `_moShadowSites` rebuilds the global snapshot on every getter access

- **Action:** REVIEW
- **Finding:** `_moShadowSites` is a computed getter (line 5082) that calls `_globalPostureService.buildSnapshot(events: widget.events, ...)` every time it is accessed. During `build()`, it is accessed at least four separate times: once in `build()` directly, once each from `_laneRail` → `_emptyLaneState`, `_selectedAutomationBoard`, and `_workspaceContextRail`. Since `_ticker` fires `setState` every second, the full snapshot is rebuilt 4+ times per second.
- **Why it matters:** If `widget.events` contains hundreds of entries, this is O(n) work per second repeated across multiple call sites. Even at moderate list sizes this will cause jank.
- **Evidence:** `lib/ui/ai_queue_page.dart` lines 5082–5090 (getter), 286 (`build()` call), 2323 (`_selectedAutomationBoard`), 2332 (again), 2374 (again), 3509 (`_workspaceContextRail`).
- **Suggested follow-up:** Codex should validate that `buildSnapshot` is not O(1) (i.e. does real work). If so, memoize `_moShadowSites` as a cached field invalidated only in `didUpdateWidget` when `events` or `sceneReviewByIntelligenceId` change.

---

### P1 — Direct state mutation inside `LayoutBuilder` callback (outside `setState`)

- **Action:** REVIEW
- **Finding:** Inside `buildWorkspaceSection` (a nested function within `build()`), line 325 does `_desktopWorkspaceActive = useWideLayout;` without a `setState` call. This is a direct field write during the build phase.
- **Why it matters:** Writing to instance fields during `build()` is not safe in Flutter. It can cause the read value to be inconsistent between a frame's build pass and the check that fires in the same frame (e.g. `_workspaceContextRail` at line 3492 checks `_desktopWorkspaceActive || _hasPinnedCommandReceipt`). On subsequent frames the layout could be sized differently from the written value.
- **Evidence:** `lib/ui/ai_queue_page.dart` lines 319–395 (nested `buildWorkspaceSection`), line 325 (`_desktopWorkspaceActive = useWideLayout`), line 3492 (read of `_desktopWorkspaceActive`).
- **Suggested follow-up:** Codex should validate that `_desktopWorkspaceActive` is read inside the same `LayoutBuilder` callback that writes it, or move this to a `postFrameCallback`/`setState` approach.

---

### P1 — Stale `_selectedFocusId` not cleared after events rebuild

- **Action:** AUTO
- **Finding:** In `didUpdateWidget` (line 240), when `widget.events` changes, `_actions` is fully rebuilt from `_seedActions`. The `_selectedFocusId` field is never reset. If the previously selected action ID no longer exists in the rebuilt `_actions`, `_resolveSelectedFocus` silently falls back to `laneItems.first`. This is an invisible stale state. The user's selection disappears without feedback.
- **Why it matters:** When a live incident closes, `_actions` drops that item, but `_selectedFocusId` still holds its ID. The board jumps to a different item silently.
- **Evidence:** `lib/ui/ai_queue_page.dart` lines 240–255 (didUpdateWidget events branch), line 5392–5410 (`_resolveSelectedFocus` fallback path).
- **Suggested follow-up:** Codex should validate that clearing `_selectedFocusId` when the referenced action ID is absent from the rebuilt actions list does not break the focus recovery logic elsewhere.

---

### P2 — `_buildDailyStats` redundant `whereType<DispatchEvent>()` filter

- **Action:** AUTO
- **Finding:** `_buildDailyStats` at line 5713 calls `events.whereType<DispatchEvent>()` then immediately applies a `.where((event) => event is DecisionCreated || event is IntelligenceReceived)`. Since all events in the list already extend `DispatchEvent`, the first `whereType` is a no-op filter and adds confusion about intent.
- **Why it matters:** It's misleading — a reader might assume this filters to a subset, but it doesn't. More importantly the intent (count only `DecisionCreated` + `IntelligenceReceived`) is obscured.
- **Evidence:** `lib/ui/ai_queue_page.dart` lines 5713–5719.
- **Suggested follow-up:** Replace the `whereType<DispatchEvent>().where(is DecisionCreated || is IntelligenceReceived)` with two separate typed counters matching the executed and overridden branches below.

---

### P2 — `_ingestEvidenceReturnReceipt`: `onConsumeEvidenceReturnReceipt` called unconditionally including when widget may be unmounted

- **Action:** REVIEW
- **Finding:** Line 3418: `widget.onConsumeEvidenceReturnReceipt?.call(receipt.auditId)` is called unconditionally at the end of `_ingestEvidenceReturnReceipt`, even on the `fromInit: true` path (which runs in `initState`). The `mounted` check at lines 3410–3416 only guards the `setState` call — the consume callback fires regardless of mount state.
- **Why it matters:** If the parent responds to this consume call by modifying provider state, calling it from inside `initState` (before the widget is fully mounted) could trigger upstream `setState` during the build phase of the parent.
- **Evidence:** `lib/ui/ai_queue_page.dart` lines 3396–3419, specifically line 3418 and the `fromInit` path at 3409–3411.
- **Suggested follow-up:** Verify whether the parent's `onConsumeEvidenceReturnReceipt` triggers a `setState` or `notifyListeners` on the parent. If so, the call should be deferred to `WidgetsBinding.instance.addPostFrameCallback` on the init path (mirroring the agent-return pattern at line 3442).

---

### P2 — `_hasPinnedCommandReceipt` uses magic string matching

- **Action:** AUTO
- **Finding:** Lines 3392–3394: `_commandReceipt.label == 'AGENT RETURN' || _commandReceipt.label == 'EVIDENCE RETURN'`. These hard-coded string comparisons are fragile. The labels are also set at lines 3426 and 3403/receipt.label respectively. A typo or label change breaks the pinned card silently.
- **Why it matters:** Receipt pinning is a UX feature — if this breaks, the command rail card stops appearing without any error.
- **Evidence:** Lines 3392–3394, 3403, 3426.
- **Suggested follow-up:** Introduce an enum or a `bool isPinned` flag on `_AiQueueCommandReceipt` and use that instead of string comparison.

---

### P2 — `_seedCctvAlerts` calls `DateTime.now()` on every render

- **Action:** REVIEW
- **Finding:** `_seedCctvAlerts` (line 1195) calls `DateTime.now()` for each generated alert (line 1218). `_seedCctvAlerts` is called from `_visibleCctvAlerts` (line 1093) which is called in `_buildCctvOverviewPage` on every build. Since `_ticker` fires setState every second, the alert occurrence timestamps drift slightly on every tick.
- **Why it matters:** The "occurred 2 minutes ago" time displayed in the CCTV alert panel will change every second even with no real events, causing visual flicker and inaccurate audit timestamps.
- **Evidence:** `lib/ui/ai_queue_page.dart` lines 1093–1101, 1195–1224 (especially line 1218: `DateTime.now().subtract(...)`).
- **Suggested follow-up:** Cache CCTV alert seed times at `initState` time (or when `_actions` changes) rather than computing fresh on each render pass.

---

### P2 — `_actions` rebuilt entirely in `didUpdateWidget` discarding operator state

- **Action:** REVIEW
- **Finding:** `didUpdateWidget` at lines 251–254 replaces `_actions` wholesale with `_seedActions(...)`. Any operator state (a user-initiated pause, a partially-counted-down executing action) is discarded when the parent pushes new events.
- **Why it matters:** A controller who has paused an action will see it immediately un-paused if the parent re-pushes events (e.g. on a widget rebuild). The 30-second countdown resets too, which may trigger unexpected auto-executions.
- **Evidence:** Lines 241–254 in `didUpdateWidget`; `_onTick` at 5093 uses `_queuePaused` that's keyed to the old action set.
- **Suggested follow-up:** Codex should validate whether the parent pushes new `events` frequently. If so, consider merging new plans into existing `_actions` rather than replacing them.

---

### P3 — `_autonomyPlanRank` can produce negative sort keys that are hard to reason about

- **Action:** REVIEW
- **Finding:** `_autonomyPlanRank` (lines 5637–5653) returns `priorityScore - 3` for shadow readiness bias, `-2` for promotion execution bias, `-1` for NEXT_SHIFT, and `priorityScore + 3` for everything else. For P1 critical (score 0), this produces sort keys of `-3`, `-2`, `-1`, and `+3`. These overlap with P2/P3 regular actions. A P3-medium shadow readiness bias (2 - 3 = -1) sorts equal to a P1-NEXT_SHIFT action (0 - 1 = -1).
- **Why it matters:** The sort is non-obvious and could produce unexpected queue ordering when multiple action types co-exist.
- **Evidence:** Lines 5637–5653.
- **Suggested follow-up:** Document the intended sort tier order in a comment, or refactor to a multi-key comparator that makes priority vs. type independent.

---

## Duplication

### 1. `_formatChipTime` and `_formatTime` are identical

`_AiQueueFocusItem._formatChipTime` (lines 5854–5859) and `_AIQueuePageState._formatTime` (lines 5451–5456) are exactly the same `mm:ss` formatter. The duplication is a maintenance hazard.

- **Files involved:** Same file, two locations.
- **Centralization candidate:** A top-level function or static method on `_AiQueueFocusItem` extended to `_AIQueuePageState`.

### 2. "Label + value" tile pattern implemented 4 times

- `_buildCctvInfoTile` (line 937) — white container, grey label, dark value
- `_contextMetric` (line 3300) — same layout, same colors
- `_activeMetricCard` (line 4858) — same layout, adds `mono`/`accent` flags
- `_miniPolicyTile` (line 3137) — same pattern but with accent color on value

All four render a small tile with a label line and a value line inside a rounded container. A single `_InfoTile` widget with optional `mono`, `accent`, `labelColor` parameters would replace all four.

### 3. "PROPOSED ACTION" container is duplicated between active and queued cards

`_activeAutomationCard` (lines 3627–3704) and `_queuedAutomationWorkspaceCard` (lines 2652–2703) both render a dark rounded container with heading `'PROPOSED ACTION'`, the action description text, and a row of `_detailCell` entries. The only difference is the styling of the child detail cells. This is a clear widget-extract candidate.

### 4. Promotion pressure/execution text rendered inline 3 times

`_activeAutomationCard` (lines 3705–3725), `_queuedAutomationWorkspaceCard` (lines 2694–2701 area), and `_queuedRow` (lines 4224–4245) all check and render `promotionPressureSummary` and `promotionExecutionSummary` with identical styles (`0xFF86EFAC`, `10.5sp`, `w700`). A `_PromotionCueText` widget would consolidate this.

### 5. "Pill / chip" pattern implemented twice

`_heroStatusChip` (line 1432) and `_workspaceStatusPill` (line 1941) are nearly identical pill containers — same border-radius, same opacity math on `withValues(alpha:)`, same font style. They differ only by padding constants.

---

## Coverage Gaps

- **CCTV overview page** (`_buildCctvOverviewPage`): zero widget tests. The dismiss/dispatch/view-camera flow is entirely untested.
- **`_seedCctvAlerts` mapping logic**: no test verifying that camera label rotation or headline derivation from `actionType` works correctly for each branch (`VISION`, `AUTO-DISPATCH`, `VOIP`, videoOpsLabel).
- **`_autonomyPlanRank` sort order**: no test with mixed action types (shadow bias + NEXT_SHIFT + regular) verifying final queue order.
- **Timer expiry path**: no test verifying that when `timeUntilExecutionSeconds` hits 0, the action is removed and `_ensureSingleExecuting` promotes the next pending action.
- **`_promoteAction`**: no test verifying that the currently executing action is demoted to `pending` when a new action is promoted.
- **`didUpdateWidget` stale focus recovery**: no test for the case where `_selectedFocusId` references an action that no longer exists after events update.
- **`_buildDailyStats`**: no test with boundary events (events exactly at the 24h window edge).
- **`_ingestAgentReturnIncidentReference` / `_ingestEvidenceReturnReceipt`** on the `fromInit=false, !mounted` branch: no test.
- **`_resolveSelectedFocus` fallback through `allItems`**: only the happy path (lane match) is likely covered.

---

## Performance / Stability Notes

### 1. Full snapshot rebuild on every 1-second tick

`_moShadowSites` is called 4+ times during each `build()` pass, which is triggered every 1 second by `_ticker`. If `buildSnapshot` does O(n) work over `widget.events`, this is `4 * n` event list traversals per second per mounted instance. At 100+ events this will show in profiles.

**Concrete risk:** Operations team dashboard with 200+ events over a shift + shadow posture matching → compounding CPU usage.

### 2. `_eventIdsForAction` iterates all events per call, called multiple times per build

`_eventIdsForAction` (line 482) is O(n) over `widget.events`. It is called from:
- `_heroHeader` → `canOpenEvents` check (line 1298–1301)
- `_queuedAutomationWorkspaceCard` → `canOpenEvents` (line 2585–2587)
- `_contextPanel` → scoped events count (line 3215)

Per-build without memoization. On each 1-second tick this is re-run for the active action across three call sites.

### 3. All four derived action lists computed fresh per build

`_activeAction`, `_displayQueuedActions`, `_nextShiftDrafts`, `_moShadowSites` are all getters (computed every access). They are called repeatedly in `build()` and passed as parameters — but also accessed again inside nested `LayoutBuilder` callbacks inside the same build frame. A snapshot at the start of `build()` (already done for `activeAction`, `queuedActions`, `nextShiftDrafts`) is partially in place but `_moShadowSites` is not snapshotted.

### 4. CCTV overview page rebuilds alert seeds from mutable `_actions` list every second

`_seedCctvAlerts` reads `_actions.take(3)` and calls `DateTime.now()`. Since `_ticker` updates `_actions` every second, the CCTV page also rebuilds its alert labels (including timestamps) every second even when no real change has occurred.

---

## Recommended Fix Order

1. **Memoize `_moShadowSites`** — cache as a field, invalidate in `didUpdateWidget`. Reduces the most impactful per-tick CPU expenditure. `AUTO`.
2. **Move `_desktopWorkspaceActive` write out of `build()`** — use a `postFrameCallback` or derive it inline from the constraint without storing it. `AUTO`.
3. **Clear `_selectedFocusId` on events rebuild** — when `_actions` is replaced in `didUpdateWidget`, check if the selected ID still exists and clear it if not. `AUTO`.
4. **Deduplicate `_formatChipTime` / `_formatTime`** — trivial extract. `AUTO`.
5. **Extract `_InfoTile` widget** — consolidate the four label+value tile implementations. `AUTO`.
6. **Fix `_buildDailyStats` redundant filter** — remove `whereType<DispatchEvent>()`. `AUTO`.
7. **Replace `_hasPinnedCommandReceipt` string matching** — add `isPinned` bool to `_AiQueueCommandReceipt`. `AUTO`.
8. **Defer `onConsumeEvidenceReturnReceipt` on init path** — match the `addPostFrameCallback` pattern. `REVIEW`.
9. **Cache CCTV alert seed timestamps** — compute once at `initState` and when `_actions` changes. `AUTO`.
10. **Add widget tests for CCTV overview, timer expiry, and promote/demote paths** — `REVIEW` (test design needs sign-off on what state should be observable).
