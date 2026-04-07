# Audit: lib/ui/clients_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/clients_page.dart` (~4 408 lines)
- Read-only: yes

---

## Executive Summary

`clients_page.dart` is the single largest UI file in the repo. It is a monolithic state blob: domain data shaping, queue management, channel-status tracking, scroll routing, AI-assist coordination, and all layout logic live inside one `_ClientsPageState`. The architecture works but it is fragile — the state surface is too large to test in isolation, several force-unwrap calls can crash in edge cases, two whole subsystems (VoIP/push-status and learned-style) are pure local-state stubs that are never wired to anything real, and every build re-runs multiple O(n log n) passes over the full events list. Risk is medium-high for a production security-ops screen.

---

## What Looks Good

- `didUpdateWidget` is thorough: every incoming prop diff is handled individually with idempotent ingestion helpers, not a blanket reset.
- `_ingestStagedAgentDraftHandoff` and `_ingestEvidenceReturnReceipt` always consume via `addPostFrameCallback`, which prevents re-entrant setState issues.
- `_sendQueueItem` correctly checks `!mounted` after the async gap before touching state or showing a snackbar.
- `_applyRouteHandoff` uses a token-compare guard to prevent repeated applications of the same handoff — solid approach.
- Free functions (`_deriveClientSiteModel`, `_incidentFeedRows`, `_humanizeName`, `_utc`) are pure and side-effect-free, making them straightforward candidates for unit tests.
- `ClientsAgentDraftHandoff.matchesScope` normalises both sides with `.trim()` before comparing — defensive and correct.

---

## Findings

### P1 — Force-unwrap crash in `_openClientRoom`
- Action: AUTO
- `_openClientRoom` at line 3773 calls `callback(room, _selectedClientId!, _selectedSiteId!)`. Both fields are `String?` and can be null at the time of call if scope has not been resolved (e.g. when `widget.clientId` is empty and no lane has been selected).
- Why it matters: this crashes the app for any user who taps a room button before a client/site is selected.
- Evidence: `clients_page.dart:3773`
- Suggested follow-up: Codex should guard with `if (_selectedClientId == null || _selectedSiteId == null) return;` before the callback call, mirroring the null-check pattern used elsewhere.

---

### P1 — Force-unwrap crash in `_roomThreadContextCard` dropdown callbacks
- Action: AUTO
- `_selectorSurface` calls for CLIENT and SITE (lines 2072 and 2095) pass `_selectedClientId!` and `_selectedSiteId!` directly as the `value` for `DropdownButton`. If either is null when this card renders, it throws a null assertion error at runtime.
- Why it matters: `_selectedClientId` and `_selectedSiteId` are nullable and are only validated in `build()` at the point where `selectedClientId`/`selectedSiteId` locals are computed. The card-builder methods receive the validated locals as parameters but then ignore them and re-read the raw nullable fields.
- Evidence: `clients_page.dart:2072`, `clients_page.dart:2095`
- Suggested follow-up: Codex should pass the already-validated `currentClient.id` / `currentSite.id` into `_roomThreadContextCard` and use those instead of the nullable state fields.

---

### P1 — `_scheduleSelectionReconcile` called inside `build()`
- Action: REVIEW
- Lines 391–394 in `build()` call `_scheduleSelectionReconcile(clientId: selectedClientId, siteId: selectedSiteId)`, which schedules a `addPostFrameCallback` that may call `setState`. Calling `setState`-scheduling from `build()` is fragile: it creates a scheduled mutation after every frame that disagrees with the current selection, which means a single selection mismatch generates a perpetual extra rebuild cycle.
- Why it matters: in practice it is guarded by `_selectionReconcileScheduled`, but the guard is a boolean on the state object, meaning concurrent or back-to-back rebuilds before the frame fires can silently drop reconciliation. It also makes the data flow harder to reason about.
- Evidence: `clients_page.dart:391–394`, `clients_page.dart:3803–3825`
- Suggested follow-up: Zaks should decide whether this reconcile is still needed, or if `_syncSelectedScopeFromWidget` / `_applyRouteHandoff` already cover all selection sync paths. If it is needed, it should move to `didUpdateWidget`.

---

### P2 — Channel state (VoIP / push-sync / backend probe) is a local stub, not wired to any backend
- Action: DECISION
- `_voipStageStatus`, `_pushSyncStatus`, and `_backendProbeStatus` are initialised to hardcoded strings (`'push idle'`, `'healthy'`, `''`) and mutated only by local UI actions (e.g. tapping "Place Call Now" sets `_voipStageStatus = 'dialing'`). No external signal ever updates them.
- Why it matters: the entire Delivery card and VoIP panel show status that is completely divorced from real backend state. An operator sees "Healthy • Last probe 5s ago" regardless of actual backend health. This is operationally dangerous for a security-ops tool.
- Evidence: `clients_page.dart:163–166`, `clients_page.dart:2596–2628`
- Suggested follow-up: Zaks must decide whether these should be driven by a real probe widget prop or by a domain service callback. Until decided, both Codex and Claude are blocked.

---

### P2 — `_learnedStyleSummaryForScope` always returns `null` — dead card render path
- Action: REVIEW
- Lines 3827–3836: the body of `_learnedStyleSummaryForScope` validates inputs and then unconditionally `return null`. The `_learnedStyleCard` block at line 548 is therefore dead in production.
- Why it matters: the card is shown in the sidebar; its presence implies learned-style data. If it is intentionally stubbed, the guard at line 548 is harmless but the code misleads reviewers. If it was supposed to be wired, it is silently broken.
- Evidence: `clients_page.dart:3827–3837`, `clients_page.dart:548–554`
- Suggested follow-up: either wire a real data source or remove the card and the stub method. Zaks to decide.

---

### P2 — Hardcoded `'2 unread'` label on Security Desk room button
- Action: REVIEW
- Line 2278: `unreadLabel: '2 unread'` is a static string baked into the room button. This will always display "2 unread" regardless of real thread state, which is actively misleading to operators.
- Evidence: `clients_page.dart:2278`
- Suggested follow-up: Codex to pass `null` for `unreadLabel` until a real unread count is available, or wire a live count from the events list.

---

### P2 — `_resolvedQueueItemIds` grows unboundedly
- Action: AUTO
- Every `_sendQueueItem` (line 3369) and `_rejectQueueItem` (line 3395) add to `_resolvedQueueItemIds`. Nothing ever removes from this set. Over a long session the set accumulates all IDs ever sent or rejected, consuming memory and making every `_visibleControllerQueueItems` filter slower.
- Evidence: `clients_page.dart:3369`, `clients_page.dart:3395`, `clients_page.dart:3254`
- Suggested follow-up: Codex should cap the set (keep last N IDs) or clear entries that are no longer in `_stagedAgentDraftHandoffs`.

---

### P3 — Room IDs in `_roomThreadContextCard` are synthesized display strings
- Action: REVIEW
- Lines 2134–2135 construct `'ROOM-${currentSite.code}'` and `'THREAD-${currentSite.code}'` as display values for ROOM ID and ACTIVE THREAD pills. These are not real room or thread identifiers — they are UI placeholders that look like real data.
- Evidence: `clients_page.dart:2134–2147`
- Suggested follow-up: If real room/thread IDs are available from the event stream or client model, they should be used. Otherwise label these fields as "example" or hide them.

---

## Duplication

### 1 — "Open Agent / Redraft with Agent" OutlinedButton style block repeated 4+ times
- Files: `clients_page.dart:1118–1145`, `1324–1346`, `2192–2225`, `3044–3068`
- Each instance copies identical `OutlinedButton.styleFrom` parameters (colors, padding, border radius, font size, icon). Minor variation is only the icon and label text.
- Centralization candidate: extract `_agentActionButton({required String label, required IconData icon, required VoidCallback? onPressed})` helper.

### 2 — `_withAgentDraftHandoffScopes` and `_withExplicitRouteScope` are near-identical model-injection patterns
- Files: `clients_page.dart:3545–3576`, `3578–3613`
- Both methods iterate over handoff/route IDs, check if the ID is absent from the current model maps, and synthesize a `_ClientOption`/`_SiteOption` with `_humanizeName`. The only difference is the source of the IDs.
- Centralization candidate: `_ClientSiteModel _injectMissingScopes(_ClientSiteModel model, Iterable<({String clientId, String siteId})> scopes)`.

### 3 — Inline action button decoration pattern repeated across `_communicationChannelsCard` and `_pendingDraftsCard`
- Files: `clients_page.dart:2695–2725`, `2727–2750`, `2752–2779`, `3017–3043`, `3044–3068`
- Each is an `InkWell` → `Container(padding, decoration, child: Text(label, textAlign: center))` block with slightly different border color. The `_channelActionButton` helper exists (line 2789) but is only used for VoIP call buttons — the same pattern in the delivery health section and drafts card uses raw InkWell+Container.
- Centralization candidate: extend `_channelActionButton` to accept a `key` and optional foreground color, or create a `_primaryActionTile` helper, and replace the inline copies.

---

## Coverage Gaps

- **`_deriveClientSiteModel`**: pure free function that builds client/site lists from events. No test. Edge cases include events with empty `clientId`/`siteId`, duplicate IDs, mixed event types.
- **`_incidentFeedRows`**: pure free function mapping events to feed rows. No test. Edge cases include unknown event subtypes (falls through silently), events with empty `eventId`.
- **`_humanizeName`**: pure free function for ID-to-display conversion. No test for inputs that lack the prefix, single-word IDs, empty strings, or IDs with underscores.
- **`_withAgentDraftHandoffScopes` / `_withExplicitRouteScope`**: state mutation helpers that synthesize phantom clients/sites — untested. A bug here causes silent display of wrong client names.
- **`ClientsAgentDraftHandoff.matchesScope`**: simple but security-relevant (determines scope isolation for message targeting). No test.
- **`_sendQueueItem` failure branch** (line 3356): the `!sent` path shows a snackbar and returns early — the queue item remains staged. This path has no test and no retry mechanism.
- **`_ingestStagedAgentDraftHandoff` dedup guard** (line 3417): if the same handoff ID arrives twice, the second is silently dropped. No test confirms this guard fires correctly.
- **`_applyRouteHandoff` with `force: true`** on init: the scroll call inside is gated on `effectiveTarget` not being `none`. No widget test confirms the scroll target is populated before the callback fires.

---

## Performance / Stability Notes

### Hot-path: `_incidentFeedRows` runs 3× per build
`build()` calls `_incidentFeedRows` directly for the active scope (line 403), then `_laneMetrics` is called for each of the two inactive lanes in `_activeLanesSection` (line 1783), and each `_laneMetrics` call runs `_incidentFeedRows` again. That is three full filter+sort passes over `widget.events` every time the widget rebuilds — which happens on every `setState` inside this file (voice selection, retry sync, etc.). For 200+ events this adds measurable frame time.

**Suggested approach**: memoize `_incidentFeedRows` output keyed on `(events, clientId, siteId)` at the top of `build()` and pass computed metrics down. Codex could implement with a simple local map populated once per build.

### `_visibleControllerQueueItems` rebuilds list every frame
Line 3238: this method sorts and filters `_stagedAgentDraftHandoffs.values` and maps them on every call. It is called on every build. For large handoff maps this is unnecessary work.

### `_deriveClientSiteModel` called every build
Line 346: called inside `build()` with the full events list. For a stable events list this produces the same result every call but does the full iteration each time. No cache or memoization.

---

## Recommended Fix Order

1. **P1 — Force-unwrap in `_openClientRoom`** (line 3773): crash risk, AUTO fix, trivial guard.
2. **P1 — Force-unwrap in `_roomThreadContextCard` dropdowns** (lines 2072, 2095): crash risk on unresolved scope, AUTO fix by plumbing validated IDs from `build()`.
3. **P2 — Hardcoded `'2 unread'` label** (line 2278): operationally misleading, AUTO fix (pass `null`).
4. **P2 — `_resolvedQueueItemIds` unbounded growth**: AUTO fix, cap or prune the set.
5. **P1 — `_scheduleSelectionReconcile` in `build()`**: REVIEW with Zaks before touching — may be unnecessary once routes are properly wired.
6. **Coverage: `_deriveClientSiteModel`, `_incidentFeedRows`, `_humanizeName`**: pure functions, straightforward unit tests, AUTO.
7. **Coverage: `ClientsAgentDraftHandoff.matchesScope` + `_sendQueueItem` failure branch**: AUTO.
8. **Duplication: agent action button style block**: AUTO cleanup once above bugs are resolved.
9. **Performance: memoize feed-row computation in `build()`**: REVIEW — requires structural judgment about widget lifecycle.
10. **P2 — VoIP/channel state not wired**: DECISION by Zaks — blocked until product direction is clear.
11. **P2 — `_learnedStyleSummaryForScope` stub**: DECISION by Zaks — remove or wire.
