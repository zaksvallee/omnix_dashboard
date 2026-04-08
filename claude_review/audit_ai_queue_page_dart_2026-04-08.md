# Audit: ai_queue_page.dart

- Date: 2026-04-08
- Auditor: Claude Code
- Scope: `lib/ui/ai_queue_page.dart`
- Read-only: yes

---

## Executive Summary

`AIQueuePage` is a 5,874-line `StatefulWidget` that contains the entire AI queue UI,
CCTV monitoring board, countdown timer, domain seeding logic, shadow dossier export,
and multiple data-shaping helpers in a single state class. The core logic is sound and
the page is defensively written in many places, but the file has crossed into god-object
territory. Several concrete bugs exist (hardcoded progress divisor, stale dismissed-alert
state after event replacement, unguarded post-frame callback). Performance is degraded by
a 1-Hz `setState` that fires even when no action is executing. Test coverage leaves all
of the critical timer and receipt-consumption paths untested.

Risk: **medium-high**. No crash-on-open paths were found, but the countdown progress bug
and the dismissed-alert staleness are real user-visible defects in production scenarios.

---

## What Looks Good

- `_onTick` guards `!mounted` and `_queuePaused` before touching state.
- `didUpdateWidget` equality checks are thorough; resets `_selectedFocusId` cleanly.
- `_ensureSingleExecuting` is a tight, safe invariant enforcer called from every
  state-mutating action.
- `_ingestEvidenceReturnReceipt` and `_ingestAgentReturnIncidentReference` both handle
  the `fromInit` / `mounted` / unmounted triad correctly for the `_commandReceipt` write.
- `_seedActions` degrades gracefully through three tiers: autonomy plans → live decisions
  → hardcoded demo fallback.
- `_focusLane` clears `_selectedFocusId` before reassigning (comment at line 5302
  confirms intent).

---

## Findings

### P1 — Progress bar divisor is hardcoded at 30 but actions can start with far more seconds

- **Action: AUTO**
- **Finding:** `_activeAutomationCard` computes progress as
  `(action.timeUntilExecutionSeconds / 30).clamp(0.0, 1.0)` (line 3542). The divisor 30
  is a hardcoded constant that does not reflect the actual initial countdown. When
  `_seedActions` falls into the decision-seeding branch, actions are assigned
  `timeUntilExecutionSeconds: 27 + (index * 18)` (line 5633). Index 3 → 81 seconds.
  The progress bar clamps immediately to `1.0` and shows a full bar from the first tick.
- **Why it matters:** Operators see a full "used up" bar on a fresh action, misreading
  urgency. The visual intervention window is meaningless for anything over 30s.
- **Evidence:** `lib/ui/ai_queue_page.dart` lines 3542, 5633.
- **Suggested follow-up:** Codex should confirm the initial countdown value is stored
  (either in `_AiQueueAction` or a parallel field) and used as the divisor.

---

### P1 — Dismissed CCTV alert IDs are not cleared when events are replaced

- **Action: REVIEW**
- **Finding:** `didUpdateWidget` (lines 253–258) resets `_actions`, `_stats`,
  `_cachedMoShadowSites`, and `_selectedFocusId` when `events` changes, but it does
  **not** clear `_dismissedCctvAlertIds` or `_dispatchedCctvAlertIds`. These sets are
  never cleared at any lifecycle point. If the host widget replaces the event list with
  a fresh dataset that includes an incident whose `id` was previously dismissed (possible
  when a new shift or investigation reuses the same ID namespace), that alert will be
  permanently invisible to the operator.
- **Why it matters:** Security-critical alerts can be silently hidden with no UI
  indication.
- **Evidence:** `lib/ui/ai_queue_page.dart` lines 222–223, 253–259,
  `_seedCctvAlerts` line 1211, `_availableCctvAlerts` line 1114.
- **Suggested follow-up:** Codex should decide whether dismissed IDs should be scoped to
  the current event set or to an explicit operator-clear action. At minimum, a
  `DECISION` is needed on lifetime of the dismissed set.

---

### P1 — `addPostFrameCallback` inside `LayoutBuilder` fires on every layout pass

- **Action: AUTO**
- **Finding:** Inside `buildWorkspaceSection` → `LayoutBuilder` builder (lines 329–332),
  the code registers a `WidgetsBinding.instance.addPostFrameCallback` on every layout
  pass. The guard `if (_desktopWorkspaceActive != useWideLayout)` prevents redundant
  `setState` calls, but the callback is still queued on every layout cycle at breakpoints
  near the 1180px threshold (e.g., when the window is being resized). Repeated
  registration during resize can queue multiple callbacks in the same frame.
- **Why it matters:** At the 1180px boundary, resize events queue cascading deferred
  setStates that cause rebuild loops. This is a known Flutter anti-pattern.
- **Evidence:** `lib/ui/ai_queue_page.dart` lines 329–332.
- **Suggested follow-up:** Codex should replace the `addPostFrameCallback` with a
  direct comparison in `build` — since `_desktopWorkspaceActive` is only read to branch
  layout, it can be computed inline rather than stored.

---

### P2 — `_onTick` calls `setState` every second regardless of queue activity

- **Action: AUTO**
- **Finding:** `_onTick` (lines 5106–5136) unconditionally enters `setState` on every
  1-second tick. If no action is in `executing` status (queue idle or paused), the map
  produces an identical list and `expiredActionIds` is empty, yet a full widget rebuild
  is triggered.
- **Why it matters:** Every page widget in the subtree rebuilds once per second even on
  a quiet board. On desktop with three panels visible simultaneously, this is ~3 full
  subtree rebuilds/sec for no-op state.
- **Evidence:** `lib/ui/ai_queue_page.dart` lines 5106–5136.
- **Suggested follow-up:** Codex should add an early-exit guard:
  `if (_activeAction == null) return;` before entering `setState`.

---

### P2 — `_ingestAgentReturnIncidentReference` post-frame callback lacks mounted check

- **Action: AUTO**
- **Finding:** Line 3453–3455:
  ```dart
  WidgetsBinding.instance.addPostFrameCallback((_) {
    widget.onConsumeAgentReturnIncidentReference?.call(ref);
  });
  ```
  There is no `if (mounted)` guard inside the callback. If the widget is disposed
  between the frame that registers the callback and the frame that executes it, the
  callback fires against a stale widget reference. The companion
  `_ingestEvidenceReturnReceipt` method does not use `addPostFrameCallback` and is
  therefore not affected.
- **Why it matters:** Disposed widget callbacks are a lifecycle misuse that can trigger
  upstream state mutations in a dead context.
- **Evidence:** `lib/ui/ai_queue_page.dart` lines 3432–3456.
- **Suggested follow-up:** Codex should add `if (!mounted) return;` inside the callback.

---

### P2 — `_hasPinnedCommandReceipt` uses fragile string comparison on `label`

- **Action: AUTO**
- **Finding:** Lines 3403–3405:
  ```dart
  bool get _hasPinnedCommandReceipt =>
      _commandReceipt.label == 'AGENT RETURN' ||
      _commandReceipt.label == 'EVIDENCE RETURN';
  ```
  Receipt type is determined by matching hardcoded strings. Any typo or label change
  silently breaks the pinning logic. There is no enum or flag to make this type-safe.
- **Why it matters:** The pinned receipt controls whether the command rail and CCTV page
  show the latest command card. A silent mismatch means the receipt is never pinned after
  a label rename.
- **Evidence:** `lib/ui/ai_queue_page.dart` lines 3403–3405, 3437, 3438.
- **Suggested follow-up:** Codex should introduce a `receiptType` enum field on
  `_AiQueueCommandReceipt` or a `isPinned` bool, replacing the string match.

---

### P3 — `_buildDailyStats` double-filters via redundant `whereType<DispatchEvent>`

- **Action: AUTO**
- **Finding:** Lines 5726–5731:
  ```dart
  events
      .whereType<DispatchEvent>()
      .where((event) => event is DecisionCreated || event is IntelligenceReceived)
  ```
  Both `DecisionCreated` and `IntelligenceReceived` already extend `DispatchEvent`, so
  the outer `whereType<DispatchEvent>()` is redundant. The correct form is two separate
  `whereType` calls or a single `where` on the raw list.
- **Why it matters:** Cosmetic bug now; becomes a real bug if a third `DispatchEvent`
  subclass that is neither `DecisionCreated` nor `IntelligenceReceived` is added and
  incorrectly counted.
- **Evidence:** `lib/ui/ai_queue_page.dart` lines 5726–5731.
- **Suggested follow-up:** `events.whereType<DecisionCreated>().length + events.whereType<IntelligenceReceived>().length` for clarity.

---

### P3 — Hardcoded demo/seed data is in production path, not behind a flag

- **Action: DECISION**
- **Finding:** When `queuedDecisions.isEmpty` (lines 5563–5599), the seed method returns
  three hardcoded fake incidents (`INC-8829-QX`, `INC-8830-RZ`, `INC-8827-PX`). This
  path fires in production when no live events are present — i.e., immediately after
  login on a fresh deployment. Fake incident IDs appear as real in the UI.
- **Why it matters:** Operators could mistake demo data for real active incidents.
- **Evidence:** `lib/ui/ai_queue_page.dart` lines 5563–5599.
- **Suggested follow-up:** Zaks needs to decide: should the fallback be an empty-state
  card, or is the seed data intentional as onboarding scaffolding? If intentional, it
  should be clearly branded as demo content.

---

## Duplication

### Duplicate time formatter: `_formatTime` and `_formatChipTime`

- `_AIQueuePageState._formatTime` (line 5464) and `_AiQueueFocusItem._formatChipTime`
  (line 5867) contain identical `padLeft` time-formatting logic.
- **Centralization candidate:** Extract to a top-level `_formatCountdownTime(int)` or to
  a shared utility. `_AiQueueFocusItem` currently has to duplicate because it is a
  private class with no access to state methods.

---

### Promotion pressure label rendered in three call sites

- `_actionPolicyContent` (line 2990), `_activeAutomationCard` (line 3717), and
  `_queuedRow` (line 4236) all render `Text('Promotion pressure: $promotionPressureSummary')` with the same style.
- **Centralization candidate:** A `_promotionPressureText(String summary)` helper
  widget.

---

### Button row layout duplicated for stacked/wide in `_activeAutomationCard`

- Lines 3836–3895: The Cancel/Pause/Approve button set is rendered twice — once in a
  `Column` for narrow viewports and once in a `Row` for wide. The same three buttons
  are built with identical constructors in both branches.
- **Centralization candidate:** Build the button list once as a `List<Widget>`, then
  wrap in `Column` or `Row` based on `stackButtons`.

---

## Coverage Gaps

1. **No test for timer countdown stops when paused.** The pause test (line 110–125 in
   the test file) checks that `LinearProgressIndicator.value == 0.0`, but does not
   verify that `timeUntilExecutionSeconds` stops decrementing after a pause. A timer
   leak after pause is undetected.

2. **No test for `_promoteAction` UI flow.** Promote is one of the highest-stakes
   actions (it replaces the live action). No test verifies that promoting a queued action
   renders it as the active card and returns the previous executing action to pending.

3. **No test for shadow dossier dialog open/copy/close.** The dialog triggered by
   `_showMoShadowDossier` has no coverage. The clipboard write path is also untested.

4. **No test for `onConsumeAgentReturnIncidentReference` and
   `onConsumeEvidenceReturnReceipt` callbacks.** These are the only mechanism by which
   the parent widget knows a receipt has been consumed. If they fire at the wrong time or
   not at all, parent state drifts silently.

5. **No test for dismissed CCTV alert navigation (replacement alert selection).** The
   `_dismissCctvAlert` method selects a replacement alert by matching `feedId`. No test
   verifies that focus moves to the replacement or falls to `null` when no replacement
   exists.

6. **No test for `focusIncidentReference` normalization.** The
   `_normalizeIncidentReference` method strips `INC-` prefixes to match against raw
   dispatch IDs. No test covers the case where the prefix is present vs. absent in the
   route parameter.

7. **No test for `_buildDailyStats` 24-hour window boundary.** Events older than 24h
   must be excluded. No test verifies boundary events at exactly 24h.

---

## Performance / Stability Notes

1. **`_seedCctvAlerts()` is not cached.** It is called in `_syncCctvRouteSelection` on
   every `didUpdateWidget`, in `_visibleCctvAlerts` (a getter called during `build`),
   and in `_availableCctvAlerts`. Each call iterates `_actions` and constructs new
   `_CctvBoardAlert` objects. On a build triggered by the 1-Hz ticker, this runs every
   second.

2. **`_computeMoShadowSites()` calls `_globalPostureService.buildSnapshot`** every
   `didUpdateWidget` when events change. If `buildSnapshot` does event-scanning work
   internally (likely), this is acceptable because it is only called on actual event
   changes — not on the timer tick. No concern beyond the cost of the scan itself.

3. **`_standbyWorkspaceActions` and `_standbyWorkspaceMetrics` create fresh widget
   lists on every `build` call** for the `_workspaceRecoveryDeck`. These are called
   from four standby code paths. They build `InkWell + AnimatedContainer` trees with
   closure captures. Given the 1-Hz rebuild rate, this generates allocation pressure
   from otherwise static content.

4. **`_buildFocusItems` is called twice in `build`** (once at line 291 to build
   `focusItems`, and again inside `_focusLane` at line 5291 when `focusItems` is not
   passed). The second call is a fast path for action-triggered focus changes, not a
   build-path issue — no fix needed.

---

## Recommended Fix Order

1. **P1 — Progress bar divisor** (line 3542): Store initial countdown per action;
   use it as divisor. `AUTO` — low-risk mechanical fix.

2. **P1 — `addPostFrameCallback` in `LayoutBuilder`** (lines 329–332): Remove the
   callback; compute `_desktopWorkspaceActive` directly in the layout branch without
   deferred setState. `AUTO`.

3. **P2 — `_onTick` unconditional `setState`**: Add early exit when no action is in
   `executing` state. `AUTO`.

4. **P2 — `addPostFrameCallback` missing mounted guard** (line 3453): Add
   `if (!mounted) return;`. `AUTO`.

5. **P2 — `_hasPinnedCommandReceipt` string match**: Replace with enum or bool.
   `AUTO`.

6. **P1 — Dismissed alert set not cleared on event replacement**: Requires a
   `DECISION` from Zaks on lifetime scoping before Codex implements.

7. **P3 — `_buildDailyStats` redundant filter**: Straightforward cleanup. `AUTO`.

8. **Duplication — time formatter**: Extract shared helper. `AUTO`.

9. **Coverage — `_promoteAction` and `_togglePause` timer behavior**: New tests.
   `AUTO`.

10. **P3 — Demo seed data**: `DECISION` from Zaks on whether to retain, brand, or
    remove the fallback fixture data.
