# Audit: Empty State UI — lib/ui/ Pages

- Date: 2026-04-08
- Auditor: Claude Code
- Scope: All `*_page.dart` and data-driven board/panel files under `lib/ui/`
- Read-only: yes

---

## Executive Summary

Most pages handle empty data gracefully. The codebase has a clear pattern of three
tiers: `OnyxEmptyState` (widget), custom named empty-state widgets (e.g.
`_VipEmptyState`, `_VehicleBiEmptyState`, `_emptyQueueState`), and inline
ternary text. The majority of list surfaces are guarded before the list is built.

Two **confirmed** blank-panel gaps exist in `live_operations_page.dart`. Two
**soft** gaps exist where data-layer conventions prevent blank rendering in
practice but no UI contract enforces them — the runtime could produce blank panels
under edge-load or restore failure.

---

## What Looks Good

- `sites_page.dart:43` — top-level `OnyxEmptyState` guard before any layout is
  built. Nothing reaches the roster or workspace unless sites exist.
- `events_page.dart:1108` — `visibleRows.isEmpty ? _emptyState(…)` — the
  forensic list and its filter-specific text ("No rows in the X lane." /
  "No events match current forensic filters.") are well handled.
- `events_review_page.dart:4659,4790` — `OnyxEmptyState` for filtered-to-zero
  and detail-pane-unselected cases.
- `dispatch_page.dart:3971` — `buildQueueBody()` explicitly returns a styled
  container with explanatory text before the `ListView.separated` is reached.
- `vip_protection_page.dart:209,506` — dedicated `_VipEmptyState` widget shown
  when no VIP run is live.
- `client_comms_queue_board.dart:134,229` — `_emptyQueueState()` called when
  `items.isEmpty`.
- `vehicle_bi_dashboard_panel.dart:86` — `_VehicleBiEmptyState` with a `message`
  param for the hourly-traffic panel.
- `ledger_page.dart:981,1041` — `_emptyLaneState()` ("No rows in this lane yet.")
  guarded by `_emptyLaneState()` ternary at line 981.
- `dashboard_page.dart:1876,1924,1971` — `_MutedLabel` widgets for signal, dispatch,
  and site lanes when filtered to zero.
- `client_app_page.dart:3375,4703,4934` — `_notificationsList`, `_incidentFeedList`,
  and the thread chat list all have `items.isEmpty` / `visibleMessages.isEmpty`
  guards that route to styled `_deliveryRecoveryDeck` widgets.
- `guard_mobile_shell_page.dart:2098,2526` — `if (visibleHistoryOperations.isEmpty)`
  renders `Center(Text(...))` before the history `ListView.separated` is built.
- `ai_queue_page.dart:2899` — `_policyEmptyState` for the policy-action lane.

---

## Findings

### P1 — Confirmed Blank Panel

**Action: AUTO**

**`live_operations_page.dart` — Guard Vigilance panel renders blank when empty**

`_vigilance` is initialized to `const []` at line 1305 and populated from projected
data at line 17063. `_vigilancePanel()` (line 15451) is called unconditionally from
`_contextAndVigilancePanel()` (lines 12452, 12480). Inside `_vigilancePanel()` there
is no `isEmpty` guard — it goes directly to:

```
// line 15572
return wide
    ? ListView.separated(itemCount: _vigilance.length, …)
    : Column(children: [for (var i = 0; i < _vigilance.length; i++) …]);
```

When `_vigilance` is empty both branches produce zero children. The "Guard Vigilance"
panel header is painted (the `_panel(title: …)` wrapper at line 12449) but its body
is blank — no text, no icon, no loading cue.

- Evidence: `lib/ui/live_operations_page.dart:1305, 15451–15585, 12449–12452`
- Why it matters: On fresh load or when no guard is assigned a vigilance record the
  panel appears broken rather than informative.
- Suggested fix for Codex: Add `if (_vigilance.isEmpty) return Center(Text('No guard
  vigilance data yet.', …))` at the top of `_vigilancePanel`.

---

### P2 — Confirmed Blank Area

**Action: AUTO**

**`live_operations_page.dart` — Action Ladder steps area is blank when no incident is pinned**

`_ladderStepsFor(null)` returns `const []` (line 17501). The ladder panel always
renders the focus-card (`_actionLadderFocusCard`) which handles the null-incident
case gracefully ("Awaiting lead incident", line 11930). However, the `stepsList`
rendered below it is a zero-item `ListView.separated` or zero-iteration `Column` —
producing a visible blank region under the focus card.

```
// line 11900
child: Column(children: [
  _actionLadderFocusCard(activeIncident, steps),   // ← shows text
  const SizedBox(height: 6),
  if (wide) Expanded(child: stepsList) else stepsList,  // ← blank
]),
```

- Evidence: `lib/ui/live_operations_page.dart:11719, 17501, 11880–11905`
- Why it matters: The focus card already sets correct expectations but the steps
  area below shows dead space rather than a clear "steps appear once an incident is
  pinned" hint.
- Suggested fix for Codex: When `steps.isEmpty`, replace `stepsList` with a
  `_MutedLabel`-style widget ("Select a live incident to load the action ladder.").

---

### P3 — Soft Gap (No UI Contract)

**Action: REVIEW**

**`client_app_page.dart` — `_roomsList` has no `isEmpty` guard**

`_roomsList` (line 4400) builds a `ListView.separated` with `visibleRooms.length`
items and no prior `isEmpty` check. In production `rooms` is always seeded from
`_rooms`, but there is no UI safety net. If `rooms` is empty for any reason
(e.g. client scope is wrong, restore fails, widget is embedded with filtered-to-zero
data), the panel renders blank.

Compare with `_notificationsList` (line 3375) and `_incidentFeedList` (line 4703)
in the same file, which both begin with `if (items.isEmpty) return _deliveryRecoveryDeck(…)`.

- Evidence: `lib/ui/client_app_page.dart:4400–4411` (no guard),
  vs. `3375` and `4703` (guarded)
- Why it matters: Inconsistency in the file's own pattern. If placeholder seeding
  ever breaks or is toggled off, the rooms panel silently shows nothing.
- Suggested follow-up: Confirm whether `rooms` is guaranteed non-empty at all call
  sites; if not, add an `isEmpty` guard mirroring `_notificationsList`.

---

### P4 — Soft Gap (Restore-edge)

**Action: REVIEW**

**`onyx_agent_page.dart` — Thread rail `ListView` has no `isEmpty` guard**

`_buildThreadRail` (line 1567) calls `_orderedThreadsForRail` and immediately builds
a `ListView.separated` with `orderedThreads.length` items (line 1618). There is no
check for `orderedThreads.isEmpty`. In normal flow `_threads` is always seeded
(`_seedThreads()`, line 1071) with at least one thread, but line 8442 shows the
codebase is aware `_threads` can be empty:

```dart
// line 8442
(_threads.isEmpty ? fallbackSelectedThreadId : _threads.first.id)
```

On a bad restore or a future code path that clears `_threads`, the rail would
render blank.

- Evidence: `lib/ui/onyx_agent_page.dart:1617–1619` (no guard),
  `1071–1072` (seed), `8442` (isEmpty awareness)
- Why it matters: Thread rail blank = user has no way to create or switch threads
  from the rail.
- Suggested follow-up: Add an `if (orderedThreads.isEmpty)` branch that surfaces
  a "New thread" prompt or a `Center(Text('No conversations yet.'))`.

---

## Pages Verified with No List-Level Empty State Gaps

| Page | List type | Guard |
|---|---|---|
| `sites_page.dart` | `ListView.separated` | `OnyxEmptyState` at top (line 43); `selectedPool` never empty |
| `events_page.dart` | `ListView.separated` | `visibleRows.isEmpty ? _emptyState(…)` (line 1108) |
| `events_review_page.dart` | `ListView.separated`, `Column` | `OnyxEmptyState` (lines 4659, 4790) |
| `dispatch_page.dart` | `ListView.separated` | `buildQueueBody()` isEmpty guard (line 3971) |
| `vip_protection_page.dart` | `SingleChildScrollView` | `_VipEmptyState` (line 209) |
| `client_comms_queue_board.dart` | items list | `_emptyQueueState()` (line 134) |
| `vehicle_bi_dashboard_panel.dart` | bar chart | `_VehicleBiEmptyState` (line 86) |
| `ledger_page.dart` | `ListView.separated` | `_emptyLaneState()` ternary (line 981) |
| `dashboard_page.dart` | `Column` (for-loop) | `_MutedLabel` ternaries (lines 1876, 1924, 1971) |
| `guards_page.dart` | `ListView.separated` | `detail == null` guard (line 995) routes to text before roster panel |
| `client_app_page.dart` (notifications/chat) | `ListView.separated` | `items.isEmpty` guard (lines 3375, 4934) |
| `guard_mobile_shell_page.dart` | `ListView.separated` | `isEmpty` guard before list (lines 2098, 2526) |
| `ai_queue_page.dart` | `GridView.builder`, lanes | `_policyEmptyState` (line 2899), lane isEmpty (line 2071) |
| `sites_command_page.dart` | `ListView` | inline text "No sites match…" (lines 649, 734) |
| `governance_page.dart` | `ListView.separated` | `children` is always non-empty (structural, not data-driven) |
| `admin_page.dart` | `GridView.count` | static cards, always populated |
| `sovereign_ledger_page.dart` | `SingleChildScrollView` | no data list — display only |
| `risk_intelligence_page.dart` | `Column` children | `withSignals.isEmpty → null` guard (line 483) |
| `client_intelligence_reports_page.dart` | detail panels | `isEmpty`/`isNotEmpty` guards throughout |
| `onyx_agent_page.dart` (message list) | `ListView.separated` | threads always seeded with ≥1 message; soft gap only |

---

## Duplication

The codebase has at least three slightly different empty-state idioms:

1. `OnyxEmptyState(label: '…')` — `sites_page.dart`, `events_review_page.dart`
2. Custom widget classes — `_VipEmptyState`, `_VehicleBiEmptyState`, `_emptyQueueState`
3. Inline ternary `isEmpty ? Text('…') : listWidget` — dashboard, ledger, guards

A shared `_CommandEmptyPanel(label, [icon])` helper inside `live_operations_page.dart`
would remove duplication between the two missing-empty-state findings (P1 and P2).

- Files involved: `live_operations_page.dart` (two locations), `dashboard_page.dart`,
  `ledger_page.dart`
- Centralization candidate: extend `OnyxEmptyState` or create a local `_OpsEmptySlot`
  for the live-ops context.

---

## Coverage Gaps

- No widget test verifies the empty-state branch of `_vigilancePanel`. The
  `live_operations_page.dart` test surface (if any) likely only exercises seeded data.
- No widget test for `_buildThreadRail` with `_threads` empty. The `onyx_agent_page`
  is probably not tested at widget level.
- `client_app_page.dart` widget tests for `_roomsList` with empty rooms list are not
  confirmed.

---

## Performance / Stability Notes

None specific to empty-state handling.

---

## Recommended Fix Order

1. **`live_operations_page.dart:_vigilancePanel`** (P1) — highest user-visibility
   impact; blank on cold load is a demo risk. Simple one-liner guard at top of method.
2. **`live_operations_page.dart:_actionLadderPanel` steps area** (P2) — similar risk
   window; one `_MutedLabel` widget resolves it cleanly.
3. **`client_app_page.dart:_roomsList`** (P3) — mirror the isEmpty guard pattern
   already present in `_notificationsList` and `_incidentFeedList` in the same file.
4. **`onyx_agent_page.dart:_buildThreadRail`** (P4) — lower urgency since seed data
   prevents blank in practice; but add the guard to match internal awareness at line 8442.
