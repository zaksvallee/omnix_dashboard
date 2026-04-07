# Audit: lib/ui/clients_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: lib/ui/clients_page.dart (4314 lines), test/ui/clients_page_widget_test.dart
- Read-only: yes

---

## Executive Summary

`clients_page.dart` is a large-surface god widget (4314 lines) that mixes domain model derivation, event fan-out, queue state management, async coordination, scroll anchoring, VoIP staging, push-sync status, and multi-layout composition inside a single `StatefulWidget`. The core mechanics are reasonably careful — `mounted` checks are present, `addPostFrameCallback` guards are consistent, and the route handoff token pattern is sound. However there are several concrete bug candidates, significant duplication, at least one stale-test assertion that likely fails against the current source, and multiple performance hot paths that fire on every build with no memoization.

---

## What Looks Good

- `mounted` guards after every await path — `_sendQueueItem`, `_prepareLatestSentFollowUpReply`, `_editQueueItem` all check `mounted` before touching state or showing snackbars.
- Route handoff token diffing in `didUpdateWidget` is clean and idempotent.
- `_resolvedQueueItemIds` + `_editedQueueDraftBodies` cleanly track local send/edit state without needing upstream confirmation.
- `_ingestStagedAgentDraftHandoff` deduplicates by ID before writing, preventing double-ingest on re-render.
- `unawaited()` wrapping is used consistently on fire-and-forget async calls inside callbacks.

---

## Findings

### P1 — Direct State Mutation Inside `build()` Without `setState`

- **Action: REVIEW**
- Lines 374–389 (`build`):
  ```dart
  if (_selectedClientId == null ||
      !clients.any((c) => c.id == _selectedClientId)) {
    _selectedClientId = clients.first.id;   // ← direct mutation in build
  }
  // ...
  if (_selectedSiteId == null ||
      !availableSites.any((site) => site.id == _selectedSiteId)) {
    _selectedSiteId = availableSites.first.id;  // ← direct mutation in build
  }
  ```
- **Why it matters:** Mutating `_selectedClientId` / `_selectedSiteId` directly inside `build()` bypasses the `setState` machinery. The mutation takes effect for this build, but if Flutter decides to rebuild the widget without invoking `setState`, the "corrected" selection is not guaranteed to persist. Worse, it silently overwrites values set by `_selectClientSite`, `_syncSelectedScopeFromWidget`, or `_applyRouteHandoff` if the client/site list has changed between calls. This can produce stale-selection UI that never triggers a re-render correction.
- **Evidence:** `lib/ui/clients_page.dart:374–389`
- **Suggested follow-up for Codex:** Move the fallback-selection logic into `_syncSelectedScopeFromWidget` or validate on scope change; do not mutate nullable selection fields inside `build`.

---

### P1 — `_retryPushSync` Leaves Push Status Stuck on Failure

- **Action: AUTO**
- Lines 3735–3752:
  ```dart
  Future<void> _retryPushSync() async {
    // ...
    setState(() { _pushSyncStatus = 'retry in flight'; ... });
    await callback();   // no try/catch, no finally reset
  }
  ```
- **Why it matters:** If `callback()` throws or completes without signalling success, `_pushSyncStatus` stays permanently at `'retry in flight'`. The delivery health card derives all its state from this string (lines 426–438). The UI will show "Push review" forever until the page is disposed, which is misleading for an ops dashboard.
- **Evidence:** `lib/ui/clients_page.dart:3735–3752`
- **Suggested follow-up for Codex:** Wrap `await callback()` in try/finally and reset `_pushSyncStatus` to a safe default in the `finally` block.

---

### P1 — Hardcoded Push/Backend/VoIP State Never Connects to Real Services

- **Action: DECISION**
- Lines 161–163:
  ```dart
  String _pushSyncStatus = 'push idle';
  String _backendProbeStatus = 'healthy';
  String _voipStageStatus = 'staged';
  ```
- **Why it matters:** All delivery health UI (`telegramBlocked`, `smsFallbackActive`, `voipReady`, `pushNeedsReview`, `backendProbeHealthy`) is derived purely from local string state that is only ever changed by UI button taps on lines 2562–2564, 2581–2583, 3738–3740. There is no service call, no subscription, no probe result fed from outside. This means the page always starts with `voipStaged = true`, which makes `_voipStageStatus.contains('staged')` return true, rendering the "VoIP Call Staged" panel on every load. This is almost certainly a placeholder that was never wired up.
- **Evidence:** `lib/ui/clients_page.dart:161–163, 429–442, 2562–2564`
- **Suggested follow-up for Codex:** Confirm with Zaks which of these statuses require real props vs. which are feature-flagged stubs. At minimum: `_voipStageStatus` should default to `'idle'` so the VoIP panel does not render on every page open.

---

### P1 — `_learnedStyleCard` Renders Hardcoded Placeholder Without Any Data Guard

- **Action: REVIEW**
- Lines 3057–3093: The card shows `'"Reassuring with ETAs"'` and `'Learned from approved replies'` with no conditional check, no `usePlaceholderDataWhenEmpty` guard, and no real data source.
- **Why it matters:** Unlike `_fallbackFeed` and `_fallbackClients` which are conditionally injected via `usePlaceholderDataWhenEmpty`, the learned-style card hardcodes content unconditionally. In a production session with real client data, this card misleads operators into thinking the system has learned a tone that it has not.
- **Evidence:** `lib/ui/clients_page.dart:3073`
- **Suggested follow-up for Codex:** Either gate behind `usePlaceholderDataWhenEmpty` or add a `learnedTone` prop. Confirm with Zaks whether this feature is active.

---

### P1 — `_ingestEvidenceReturnReceipt` Never Clears `_activeEvidenceReturnReceipt`

- **Action: REVIEW**
- Lines 317–341: When a new evidence receipt arrives, `_activeEvidenceReturnReceipt` is set and the upstream `onConsumeEvidenceReturnReceipt` is called. But `_activeEvidenceReturnReceipt` is never cleared from local state. If the page is kept alive (e.g., persisted in a `PageView` or `IndexedStack`), the evidence banner will continue to show permanently, blocking the normal status banner.
- **Why it matters:** The evidence banner replaces the "What needs attention" panel (lines 961–1023). Once set, it can never be dismissed by the user, and a new receipt with the same `auditId` will not overwrite it (the `didUpdateWidget` guard checks `auditId` diff). The operator is stuck with a stale evidence context.
- **Evidence:** `lib/ui/clients_page.dart:317–341, 960–1024`
- **Suggested follow-up for Codex:** Add a dismiss callback or a `_clearEvidenceReturnReceipt` path after a timeout or explicit user action.

---

### P2 — Duplicate `ValueKey('clients-workspace-status-banner')` Across Shellless/Shelled Paths

- **Action: AUTO**
- Lines 1006–1009, 1011–1012, 1121–1124, 1126–1127: Both the shellless widget and the container wrapper use the same `const ValueKey('clients-workspace-status-banner')`. While the desktop layout only renders one at a time, tests or layout edge cases could surface a key collision warning.
- **Evidence:** `lib/ui/clients_page.dart:1006, 1011, 1121, 1126`
- **Suggested follow-up for Codex:** Use distinct keys e.g. `clients-workspace-status-banner-shellless` vs `clients-workspace-status-banner-card`.

---

### P2 — "Security Desk" Room Has Hardcoded `unreadLabel: '2 unread'`

- **Action: AUTO**
- Lines 2247–2254:
  ```dart
  _roomButton(
    'Security Desk',
    const Color(0xFF10B981),
    unreadLabel: '2 unread',      // ← always shows this, regardless of data
    enabled: roomRoutingAvailable,
    onTap: () => _openClientRoom('Security Desk'),
  ),
  ```
- **Why it matters:** The badge will always show "2 unread" for the Security Desk room regardless of actual activity. This is a hardcoded placeholder that looks like live data to operators. Only `Residents` and `Trustees` have no badge.
- **Evidence:** `lib/ui/clients_page.dart:2251`
- **Suggested follow-up for Codex:** Remove `unreadLabel` here or source it from a real prop/computed value.

---

## Duplication

### 1. `_withAgentDraftHandoffScopes` vs `_withExplicitRouteScope` — Near-Identical Synthetic Model Injection

- Lines 3504–3535 and 3537–3572.
- Both methods build `clientsById` and `sitesById` maps from a model, inject missing entries with `_humanizeName`, sort, and return a new `_ClientSiteModel`.
- The only differences are the source of injected IDs (staged handoffs vs. widget props).
- Centralization candidate: a private `_injectSyntheticScopeEntries(model, clientIds, siteIdToClientId)` helper.

### 2. `OutlinedButton.icon` "Ask Junior Analyst" / "Redraft with Junior Analyst" — Six Instances

- Lines ~1094, ~1297, ~1585–1618, ~2166–2197, ~2690–2712, ~3009–3030.
- Every instance has the same `OutlinedButton.styleFrom(...)` block with identical padding, foreground, side, backgroundColor, and shape values.
- The only variance is the label text, icon, key, and `onPressed` closure.
- Centralization candidate: a `_agentActionButton({required Key key, required String label, required bool redraft, required VoidCallback? onPressed})` private helper.

### 3. Inline "Open queued draft" `InkWell`/`Container` — Three Instances

- Lines ~2200–2225 (`_roomThreadContextCard`), ~2714–2742 (`_communicationChannelsCard`), ~2980–3005 (`_pendingDraftsCard`).
- Each renders a full-width tappable container with text "Open queued draft", identical decoration, same font style, but different key and `_openSimpleQueueForDraft` resume target.
- Centralization candidate: extract a `_queueDraftActionButton(...)` helper used by all three cards.

### 4. `_eventClientId` / `_eventSiteId` / `_eventIncidentReference` — Pattern-Matched Per Event Type

- Lines 4253–4267: three separate free functions each pattern-match the same four event types.
- This structure requires all three to be updated when a new event type is added. A single `_eventScope(DispatchEvent) → (clientId, siteId, incidentReference)` would be more cohesive.

---

## Coverage Gaps

### 1. `_retryPushSync` Failure Path — Untested

No test exercises the failure path of `onRetryPushSync` throwing or signaling an error. The "stuck push status" bug (P1 above) is therefore undetected by tests.

### 2. `_activeEvidenceReturnReceipt` Persistence — Untested

No test verifies the evidence receipt banner is dismissed or cleared after `onConsumeEvidenceReturnReceipt` fires.

### 3. `_prepareLatestSentFollowUpReply` — No Failure Path Coverage

`onSuggestLiveFollowUpReply` returning a null or empty draft falls through silently (uses the default fallback). There is no test for the case where it throws.

### 4. Route Handoff Token — No `ClientsRouteHandoffTarget.channelReview` Test

`test/ui/onyx_app_clients_route_widget_test.dart` and `clients_page_widget_test.dart` likely cover `pendingDrafts` and `threadContext` targets. `channelReview` has a different scroll anchor (`_communicationChannelsCardKey`) and should have dedicated coverage.

### 5. `_sendQueueItem` Where `onSendStagedAgentDraftHandoff` Returns `false`

The partial-send path (lines 3308–3325) shows a snackbar and returns without resolving the item. There is no test that confirms the item remains in the queue after a `false` return.

### 6. Stale Test Assertion — Likely Failure Against Current Source

`clients_page_widget_test.dart` line 58:
```dart
expect(find.text('3 PENDING MESSAGES'), findsOneWidget);
```
This string is produced by `client_comms_queue_board.dart:180`. The seed items returned by `_seedControllerQueueItems()` are 3 items. However, the test at line 53 also expects:
```dart
expect(find.text('Client Communications'), findsOneWidget);
```
`'Client Communications'` appears inside the `_heroHeader` widget — but `_heroHeader` is only rendered when `_showDetailedWorkspace == true`, and the default state is `false` (queue board only). This assertion will fail unless the test correctly opens the detailed workspace first. `_openDetailedWorkspaceIfPresent` is not called before these assertions. Codex should validate whether this test passes in CI.

---

## Performance / Stability Notes

### 1. `_incidentFeedRows` Called Once Per Non-Active Lane Per Build Inside `_activeLanesSection`

- Lines 1746–1768: `_activeLanesSection` maps the 2 non-active lanes through `_laneMetrics`, which calls `_incidentFeedRows` (a full O(n) scan + sort of `widget.events`) for each.
- On a large event list, this is 3 × scan + 3 × sort per build call. Since `build()` can fire on any state change (voice option tap, workspace toggle, etc.), this can be a visible hot path.
- **Suggested follow-up:** Memoize lane metrics in `didUpdateWidget` when `widget.events` changes reference.

### 2. `_agentIncidentReference` Iterates `_stagedAgentDraftHandoffs` and `widget.events` Per Build

- Lines 451–454 (build): computed twice — once for `agentIncidentReference`, once via `_latestStagedAgentDraftHandoffForScope` for `queuedDraftItemId`.
- Both paths iterate and sort the same collections. On large handoff and event sets, these compound.

### 3. `_humanizeName` Has No Caching

- Called inside `_deriveClientSiteModel`, `_withAgentDraftHandoffScopes`, `_withExplicitRouteScope`, and `_queueItemFromAgentDraftHandoff`.
- For the same `raw` string, it will produce the same output every call. A top-level cache (`Expando` or `static Map`) would eliminate all repeat computation.

### 4. `_visibleControllerQueueItems` Builds and Sorts Entire Staged Handoff Collection Per Build

- Line 3197: called inside the `build()` closure at line 450. The full filtered sort runs on every rebuild, including no-op rebuilds like voice-option selection.

---

## Recommended Fix Order

1. **(P1) Fix `_retryPushSync` missing try/finally** — AUTO, low risk, one-line fix that prevents stuck delivery health state.
2. **(P1) Change `_voipStageStatus` default from `'staged'` to `'idle'`** — AUTO after DECISION with Zaks on VoIP feature status; prevents VoIP panel always rendering.
3. **(P1) Remove hardcoded `unreadLabel: '2 unread'` from Security Desk** — AUTO, zero functional impact, removes misleading data.
4. **(P1) Move fallback-selection out of `build()` into `_syncSelectedScopeFromWidget`** — REVIEW, touches selection ownership logic.
5. **(P1) Add dismiss/clear path for `_activeEvidenceReturnReceipt`** — REVIEW with Zaks on intended UX.
6. **(P1) Gate `_learnedStyleCard` behind `usePlaceholderDataWhenEmpty` or add real prop** — DECISION on whether the learned-tone feature is live.
7. **(Coverage) Add `_retryPushSync` failure path test** — AUTO.
8. **(Coverage) Add `onSendStagedAgentDraftHandoff` returning `false` test** — AUTO.
9. **(Coverage) Validate and fix stale `'Client Communications'` + `'3 PENDING MESSAGES'` assertions** — AUTO (Codex to run and confirm).
10. **(Duplication) Extract `_agentActionButton` and `_queueDraftActionButton` helpers** — AUTO, reduces 6 + 3 duplicated button blocks.
11. **(Performance) Memoize `_laneMetrics` and `_agentIncidentReference` per build** — REVIEW.
