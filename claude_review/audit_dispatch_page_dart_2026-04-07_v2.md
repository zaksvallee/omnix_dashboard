# Audit: dispatch_page.dart (v2)

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/dispatch_page.dart` — full file, 8296 lines
- Read-only: yes

---

## Executive Summary

`dispatch_page.dart` is the largest single file in the codebase (~8,300 lines, ~287 KB). It is a critical operational surface — the live Dispatch War Room — and it is structurally dangerous. All domain logic (dispatch seeding, focus resolution, partner trend analysis, officer availability), all presentation state, and all side-effect routing live inside one `_DispatchPageState`. The `DispatchPage` widget constructor accepts 70+ parameters, making it the widest API boundary in the project. Several sections of the UI render **hardcoded mock data** unconditionally — AI call status, call transcripts, transport metrics, response time breakdowns — with no live wiring. A state override map (`_dispatchOverrides`) accumulates indefinitely and is never cleared on event refresh, meaning operator-triggered status overrides can permanently shadow real event-driven state. Most domain methods are called multiple times per build without memoization. The file needs significant extraction before it is safe to extend.

---

## What Looks Good

- `_seedDispatches` correctly scopes to `clientId`/`siteId` and falls back to static demo data when events are empty — the demo path is clearly guarded.
- `_resolveFocusReference` handles all focus resolution cases (exact, scope-backed, event-backed, seeded) with clear named record types.
- `_partnerDispatchProgressSummary` and `_partnerTrendSummary` are deterministic pure computations from `widget.events` — they are safe to extract and test.
- `_applyDispatchOverrides` is a clean pure map — no side effects.
- `_confirmClearQueue` and `_confirmExpireTemporaryIdentityApproval` correctly guard the `mounted` check after the `await`.
- Action routing methods (`_trackOfficer`, `_viewCamera`, `_callClient`, `_openAgent`) all correctly notify via `onAutoAuditAction` before delegating to widget callbacks.

---

## Findings

### P1 — `_dispatchOverrides` never cleared on event refresh

- **Action: REVIEW**
- `_dispatchOverrides` is a `Map<String, _DispatchOperatorOverride>` that accumulates operator manual status changes (lines 500–501). `_projectDispatches` (line 7373) calls `_applyDispatchOverrides` on every event update but never clears stale entries from `_dispatchOverrides`.
- If a dispatch transitions in the real event stream (e.g. arrives as `cleared` via `IncidentClosed`), the override from a previous manual action (`enRoute`, `cleared`) will continue to be applied over the live event truth indefinitely until the widget is rebuilt from scratch.
- **Evidence:** `lib/ui/dispatch_page.dart:500–501`, `7353–7358`, `7553–7568`, `7373–7427`. The `apply()` function inside `_projectDispatches` never calls `_dispatchOverrides.remove(...)` or `_dispatchOverrides.clear()`.
- **Suggested follow-up:** Codex should verify whether dispatches that appear with `cleared` status in `closedDispatchIds` still receive an override on top. Reproduce by: (1) manually clearing a dispatch via `_clearAlarm`, (2) allowing the same dispatch to re-arrive via a fresh event batch — the UI will show the override status, not the event status.

---

### P1 — `build()` writes directly to instance state without `setState`

- **Action: AUTO**
- Line 777: `_desktopWorkspaceActive = wide;` is a direct mutation of instance state inside `build()`. `build()` must be a pure function of state and widget props. This write happens outside `setState`, meaning it bypasses Flutter's dirty-tracking.
- If `_showDispatchFeedback` is called from a callback triggered before the next frame (where `_desktopWorkspaceActive` is still stale from the previous build), the wrong feedback path executes.
- **Evidence:** `lib/ui/dispatch_page.dart:777`.
- **Suggested follow-up:** Codex should replace the direct write with a `didChangeDependencies` or `LayoutBuilder`-scoped approach, or pass `wide` through to `_showDispatchFeedback` explicitly.

---

### P1 — Hardcoded mock data in `_alarmCallStatusPanel` renders unconditionally

- **Action: REVIEW**
- `_alarmCallStatusPanel` (lines 1922–2083) always renders fabricated data: call attempt count is hardcoded to `'1'` or `'2'` based only on whether the dispatch is `resolved`, timestamps are `'Last attempt: 23:43'` and `'Last attempt: 23:41'`, and the client response transcript is a static string (`'"AI: This is ONYX Security calling…"'`).
- This means every real dispatch on the live Dispatch War Room shows fake call data, regardless of actual communication records.
- **Evidence:** `lib/ui/dispatch_page.dart:1924–1925`, `1967`, `2009–2011`. `attempts` is derived only from `dispatch.status`, not from any event in `widget.events`.
- **Suggested follow-up:** Codex should confirm whether `ClientConversationRepository` or `clientCommsDeliveryPolicyService` emits events that could drive real call attempt data here, and wire them or mark this panel as a placeholder behind a feature flag.

---

### P1 — Hardcoded mock data in `_systemStatusPanel` Transport and Response Time sections

- **Action: REVIEW**
- Transport & Intake metrics (lines 5203–5213) are always `'12 / 14'`, `'18 / 20'`, `'Optimal'` — never derived from real events.
- Response Time Breakdown (lines 5359–5387) is always `'4.2 min avg'`, `'8.1 min avg'`, `'12.4 min avg'`.
- These panels appear on the primary desktop dispatch workspace.
- **Evidence:** `lib/ui/dispatch_page.dart:5203–5213`, `5359–5387`.

---

### P2 — `_alarmSummary` always returns one of 3 fixed strings

- **Action: AUTO**
- `_alarmSummary` (lines 2247–2253) maps each `_DispatchPriority` to a hardcoded string (`'Perimeter Breach • North Gate'`, etc). It ignores `dispatch.site`, `dispatch.type`, and all event context.
- On a live dispatch board, every P1 alarm reads `'Perimeter Breach • North Gate'` regardless of the actual site.
- **Evidence:** `lib/ui/dispatch_page.dart:2247–2253`.
- **Suggested follow-up:** Replace with a derivation from `dispatch.type` and `dispatch.site`, or at minimum use `_displaySiteLabel(dispatch.site)` in the output.

---

### P2 — `_alarmOfficerOptions` returns hardcoded officer rosters

- **Action: REVIEW**
- Lines 2180–2194: Officer picker options branch only on whether the site name contains `'sandton'`. All other sites receive a fixed list of 3 fictional officers.
- The actual guard roster is available via `widget.events` (ResponseArrived) and guard sync channels, but is not consulted.
- **Evidence:** `lib/ui/dispatch_page.dart:2180–2194`.

---

### P2 — `_handleDispatchAction` hardcodes fallback officer as 'Echo-3 - John Smith'

- **Action: REVIEW**
- Line 7322: `'Echo-3 - John Smith'` is substituted when no draft assignment exists. This synthetic officer name will appear in audit trail calls to `widget.onAutoAuditAction` and `widget.onExecute`, polluting the real dispatch record.
- **Evidence:** `lib/ui/dispatch_page.dart:7319–7322`.

---

### P2 — Duplicate `ValueKey('dispatch-workspace-filter-pending')` in same build path

- **Action: AUTO**
- Within the null-selected-dispatch branch of `_dispatchWorkspaceFocusCard`, the key `const ValueKey('dispatch-workspace-filter-pending')` is assigned to two separate `_workspaceActionChip` calls (lines 2663 and 2704) in the same widget subtree. Duplicate keys in the same subtree are a Flutter invariant violation that causes `GlobalKey` errors in debug and undefined reconciliation in release.
- **Evidence:** `lib/ui/dispatch_page.dart:2663`, `2704`.

---

### P2 — `_seedDispatches` assigns status via index fallback, not event-driven logic

- **Action: REVIEW**
- Lines 7755–7759: When a dispatch ID is not in `closedDispatchIds`, `executedDispatchIds`, or partner declarations, the status falls through to `index == 0 ? enRoute : index == 1 ? pending : enRoute`. This assigns `pending` only to the second dispatch alphabetically by event sort order, and `enRoute` to all others, regardless of reality.
- **Evidence:** `lib/ui/dispatch_page.dart:7755–7759`.

---

### P2 — `_partnerDispatchProgressSummary` and related methods iterate full event list on every build call

- **Action: AUTO**
- `_partnerDispatchProgressSummary(dispatchId)` (lines 7811–7849) calls `widget.events.whereType<PartnerDispatchStatusDeclared>().where(...)` for every dispatch card rendered. At 8 dispatches × frame rate, this scans the full event list repeatedly.
- Similarly `_averageResponseTimeLabel` (line 8018) iterates all events, and `_suppressedDispatchReviewEntries()` (line 5494) iterates `widget.fleetScopeHealth` and `sceneReviewByIntelligenceId` per build.
- None of these computations are memoized or cached in `initState`/`didUpdateWidget`.
- **Evidence:** `lib/ui/dispatch_page.dart:7811–7849`, `5494–5513`, `8018–8038`.
- **Suggested follow-up:** Compute these once in `_projectDispatches` or `didUpdateWidget` when `widget.events` changes, and cache results in state fields.

---

### P3 — `_dispatchWorkspaceFocusCard` duplicates action chip list verbatim

- **Action: AUTO**
- The `summaryOnly == true` path and `summaryOnly == false` path in `_dispatchWorkspaceFocusCard` (lines 2829–3013) each contain an identical `Wrap` of action chips. The only structural difference is a `Text` footer in the `summaryOnly` branch. The chip definitions are copy-pasted, not extracted.
- **Evidence:** `lib/ui/dispatch_page.dart:2832–2918` vs `2934–3013`.

---

### P3 — `_officersAvailable()` returns a synthetic count, not a real one

- **Action: REVIEW**
- Lines 7802–7809: `_officersAvailable()` counts distinct `guardId` values from `ResponseArrived` events, adds 8, and clamps to `[8, 24]`. Falls back to `12`. This value appears in the KPI band labelled 'OFFICERS AVAILABLE'. It is not a real on-duty count.
- **Evidence:** `lib/ui/dispatch_page.dart:7802–7809`.

---

### P3 — `_partnerTrendReason` returns empty string fallthrough

- **Action: AUTO**
- Line 8015: `return '';` is reached when `trendLabel` does not match any `case`. The `switch` covers `'IMPROVING'`, `'SLIPPING'`, `'STABLE'`, `'NEW'` — but `_partnerTrendLabel` can only return one of those four values. However the empty return is structurally fragile — if a new trend label is added, the UI silently renders a blank reason string with no warning.
- **Evidence:** `lib/ui/dispatch_page.dart:8013–8016`.

---

## Duplication

### 1. `_workspaceActionChip` blocks in `_dispatchWorkspaceFocusCard`
- **Files:** `dispatch_page.dart:2832–2918` and `2934–3013`
- Both branches render the identical set of filter chips (All, Active, Pending, Cleared, Open Dispatch Board, Fleet Watch Rail). The `summaryOnly` branch only adds a trailing `Text`. Centralize into a single `_dispatchFocusActionChips(...)` helper method.

### 2. `_alarmActionRow` calls `_alarmActionButton` with 'OPEN CLIENT COMMS' twice
- **Files:** `dispatch_page.dart:1549` (cleared branch of the `CLEAR ALARM` button) and `1870–1878` (inside the `expanded && pending` block).
- Both are `_callClient(dispatch)` wired to the same handler, same label. The first occurrence at line 1549 already handles the cleared case via `cleared ? _callClient(dispatch) : _clearAlarm(dispatch)`, making the second explicit button a visual duplicate on the same card.

### 3. `_displaySiteLabel` and `_displayClientLabel` share the same `vallee` / site substring matching pattern
- **Files:** `dispatch_page.dart:2255–2279` and `2282–2302`
- Both contain repeated `normalized.contains('vallee')`, `normalized.contains('sandton')`, `normalized.contains('north residential')` branches. The site-to-label mapping table should be centralized.

---

## Coverage Gaps

- **No unit tests for `_seedDispatches`** — the primary dispatch projection logic that maps raw `DispatchEvent` lists to `_DispatchItem` lists. Status derivation, priority assignment, officer assignment are all untested.
- **No unit tests for `_resolveFocusReference`** — the multi-case focus state machine (exact / scope-backed / event-backed / seeded) has no coverage.
- **No unit tests for `_partnerTrendSummary` / `_partnerTrendLabel` / `_partnerTrendReason`** — these compute trend analysis from sovereign report history. Threshold values (`±0.35`, `±2.0`) are magic numbers with no test.
- **No regression test for the `_dispatchOverrides` persistence bug** — a test that verifies a manually cleared dispatch is superseded when a live event arrives with the correct final status.
- **No test for the duplicate `ValueKey` bug** — a widget test that renders the null-selected-dispatch focus card and asserts no key collision.
- **No integration test for `_handleDispatchAction` audit trail** — the sequence of `onAutoAuditAction` calls and `_dispatchOverrides` mutations on dispatch action is not locked by any test.

---

## Performance / Stability Notes

- **`_dispatchCountForFilter` recalculates all 4 filter counts** every time the queue header renders (`_dispatchQueue`), calling `_visibleDispatches()` 4 times inside `_queueFilterChip`. Cache counts in `_projectDispatches`.
- **`_suppressedDispatchReviewEntries()` is called from `build()`** and performs a sort + take on every frame. Should be cached as state field updated in `didUpdateWidget` when `widget.fleetScopeHealth` or `widget.sceneReviewByIntelligenceId` changes.
- **`_fleetScopePanel` calls `VideoFleetScopeHealthSections.fromScopes` twice per render** (lines 5711–5715): once for `sections` and once for `filteredSections`. If `fromScopes` is not `O(1)` this doubles fleet scope computation per frame.
- **`_alarmBoardDispatches` calls `_dispatches.where(...)` twice** per desktop overview build (lines 1349–1375), creating two intermediate lists.
- **`_commandReceipt` is updated inside `setState` inside `_watchActionFocusBanner`** via `onExtendTemporaryIdentityApproval` which is an async future. If the widget is disposed before the future completes and the `mounted` check passes between the `await` and the `setState`, a stale state write can occur. This is guarded at lines 6957 and 6993, but Codex should verify the guard is before all state mutations, not just the snack call.

---

## Recommended Fix Order

1. **Fix `_dispatchOverrides` never cleared** — highest blast radius. A stale override can hide a real alarm state from operators (P1).
2. **Fix duplicate `ValueKey` in `_dispatchWorkspaceFocusCard`** — debug-mode crash risk, silent release bug (P2, AUTO).
3. **Remove the `build()` direct write of `_desktopWorkspaceActive`** — architectural correctness, safe fix (P1, AUTO).
4. **Add tests for `_seedDispatches`, `_resolveFocusReference`, `_partnerTrendLabel`** — all safe extractions with no production impact, but critical for safe future changes.
5. **Memoize `_partnerDispatchProgressSummary`, `_suppressedDispatchReviewEntries`, `_averageResponseTimeLabel`** — perf improvements, no behavioral change (P2, AUTO).
6. **Mark `_alarmCallStatusPanel`, Transport, and Response Time sections as mock/demo** — either hide behind a dev flag or wire to real data. Controllers using the live Dispatch Board should not see fabricated AI call transcripts (P1, REVIEW).
7. **Deduplicate `_dispatchWorkspaceFocusCard` action chip list** — reduces maintenance surface (P3, AUTO).
8. **Extract `_seedDispatches`, `_resolveFocusReference`, `_partnerTrendSummary` into a testable coordinator class** — DECISION: architecture choice on whether to leave in state or move to application layer.
