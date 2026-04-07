# Audit: guard_mobile_shell_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: lib/ui/guard_mobile_shell_page.dart (~6839 lines) + test/ui/guard_mobile_shell_page_widget_test.dart (~2670 lines)
- Read-only: yes

---

## Executive Summary

This file is the largest UI file in the project and one of the most structurally dense. It functions correctly as a rendering surface but has grown into a god-class shell that mixes domain-level health calculations, multi-path report assembly, and full widget composition inside a single `StatefulWidget` state. The constructor takes ~60 named parameters. The `build()` method branches into three full layout paths, each of which contains near-verbatim copies of two major content blocks.

The most urgent concrete risk is a **direct state mutation inside `build()`** (P1). Several O(n) scans are duplicated per build pass. The domain logic embedded in state is auditable but makes the widget untestable at unit scope and creates ownership confusion for future maintainers. Test coverage for failure branches and role-switch edge cases is thin.

---

## What Looks Good

- `_withSubmit` correctly gates `_submitting`, handles async exceptions, and guards `mounted` before `setState` — a clean, consistent submit-flow pattern.
- `_enforceOutcomeGovernance` enforces governance policy before any outcome label action fires. The policy is injected, not hardcoded.
- `addPostFrameCallback` is used correctly to defer the upstream `onSelectedOperationChanged(null)` notification out of the build phase.
- `_payloadInt`, `_payloadBool`, `_payloadDateTime` are robust helpers that handle type variance (int/num/String coercions) defensively.
- `_telemetryPayloadHealthTrendRows` sorts descending before taking 5, then reverses — correct chronological order for trend display.
- `_durationCompact` correctly handles negative durations implicitly via the `<1m` branch; negative callback ages are also handled in `_telemetryCallbackAgeLabel`.
- Test coverage for the happy path, role gating, PTT lockscreen, export audit filters, telemetry replay, and scope selection is comprehensive.

---

## Findings

### P1 — Direct State Mutation Inside `build()`

- **Action: AUTO**
- **Finding:** `_selectedOperationId = null` is assigned synchronously inside `build()` at line 1971 without a `setState()` call.
- **Why it matters:** Mutating instance fields directly during `build()` bypasses Flutter's rebuild contract. The change is not scheduled as a frame; it is applied mid-tree construction. If the subtree subsequently reads `_selectedOperationId` in the same build pass (e.g. in `_operationDetailPanel`), the value has silently changed without a guaranteed repaint cycle. This is a latent inconsistency bug.
- **Evidence:** `lib/ui/guard_mobile_shell_page.dart:1971`
  ```dart
  _selectedOperationId = null;
  if (!_selectionClearNotifyQueued) {
    _selectionClearNotifyQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
  ```
  The `addPostFrameCallback` is correctly deferred, but the field write is not.
- **Suggested follow-up for Codex:** Move the `_selectedOperationId = null` assignment into the `addPostFrameCallback` body alongside the `onSelectedOperationChanged` call, so both state mutation and upstream notification happen outside the build phase.

---

### P1 — `_buildDispatchCloseoutPacket` Uses Two Independent `DateTime.now()` Calls

- **Action: AUTO**
- **Finding:** The method creates `nowUtc` at line 1868 for downstream logic, but then calls `DateTime.now().toUtc()` again at line 1896 inside the string list (`'Generated At: ...'`). These two calls can produce timestamps that differ by a measurable wall-clock delta.
- **Why it matters:** The closeout packet is an audit artefact. If the `generatedAtUtc` passed to `onDispatchCloseoutPacketCopied` (line 5080 in `_buildScreenPanel`) differs from the timestamp embedded in the packet text, the audit trail is internally inconsistent.
- **Evidence:** `lib/ui/guard_mobile_shell_page.dart:1868` vs `1896`
  ```dart
  final nowUtc = DateTime.now().toUtc();        // line 1868
  ...
  'Generated At: ${_formatUtc(DateTime.now().toUtc())}',  // line 1896
  ```
  Additionally, `_buildScreenPanel` at line 5028 creates yet another independent `generatedAtUtc` for the `onDispatchCloseoutPacketCopied` callback, separate from both timestamps in `_buildDispatchCloseoutPacket`.
- **Suggested follow-up for Codex:** Accept a `DateTime generatedAtUtc` parameter in `_buildDispatchCloseoutPacket` and use it for both the text content and the caller-side callback. This ensures the audit label, the packet text, and the callback timestamp are all identical.

---

### P2 — SyncHistory Content Block Triplicated in `build()`

- **Action: REVIEW**
- **Finding:** The full sync history content (history filter chips, mode filter chips, facade dropdown, scoped selection chips, copy-scoped-keys button, failed-ops metrics strip, clear-queue button, `_historyOperationWorkspace`) is duplicated verbatim across three layout branches:
  1. Compact layout: `syncHistoryPanel` (lines ~2191–2415)
  2. Non-compact / stacked: `syncHistoryPanel` again (lines ~2619–2844)
  3. Non-compact / side-by-side: `syncHistoryBody` (lines ~2912–3128)
- **Why it matters:** Any change to the sync history panel must be made in three places. Branches 1 and 2 are near-identical; only branch 3 differs in layout role. This is a maintenance hazard in a file already at high complexity.
- **Evidence:** Compare lines 2191–2415, 2619–2844, and 2912–3128 of `lib/ui/guard_mobile_shell_page.dart`.
- **Suggested follow-up for Codex:** Extract the sync history content into a private `_syncHistoryContent()` method or a dedicated `_SyncHistoryPanel` widget. Branches 1 and 2 can share a single `OnyxSectionCard` wrapper; branch 3 uses the raw content.

---

### P2 — Screen Chip Mapping Triplicated in `build()`

- **Action: AUTO**
- **Finding:** The `_screensForRole(widget.operatorRole).map((screen) => switch(screen) { ... })` block that renders navigation chips is duplicated at lines 2143–2180, 2570–2608, and 2866–2903.
- **Why it matters:** Adding a new screen to `_GuardMobileScreen` requires updating the switch in three places plus `_screensForRole`. Missing one produces a silent fallback to the last `_` arm.
- **Evidence:** `lib/ui/guard_mobile_shell_page.dart:2143`, `2570`, `2866`.
- **Suggested follow-up for Codex:** Extract into `_buildScreenNavChips()` returning `List<Widget>` and call it from all three branches.

---

### P2 — Domain Logic Embedded in UI State

- **Action: DECISION**
- **Finding:** The following methods perform domain-level computation inside `_GuardMobileShellPageState`:
  - `_hasOpenShift`, `_shiftLifecycleLabel`, `_openShiftAgeLabel` — shift lifecycle
  - `_exportHealthVerdict`, `_exportHealthReason`, `_exportGeneratedHealthSeverity`, `_exportRatioHealthSeverity` — export health scoring
  - `_telemetryPayloadHealthVerdict`, `_telemetryPayloadHealthReason`, `_telemetryPayloadHealthVerdictFromPayload` — telemetry health scoring
  - `_resumeSyncTriggerCount`, `_telemetryPayloadHealthAlertCount`, `_exportAuditGeneratedEventCount` — shift-scoped aggregate counts
- **Why it matters:** These computations cannot be unit-tested without pumping a full widget tree. They duplicate logic that is conceptually owned by the guard sync domain. Any change to health thresholds requires touching the UI class directly.
- **Evidence:** `lib/ui/guard_mobile_shell_page.dart:608–832` (shift + export health), `1332–1398` (telemetry health).
- **Suggested follow-up for Codex:** Evaluate extracting these into a `GuardSyncShellViewModel` or `GuardShiftHealthSummary` domain object, computed upstream and passed as props. Mark DECISION because this changes the widget's public surface and affects the caller's wiring.

---

### P2 — `_shiftVerified` Flag Disconnected from Event Log

- **Action: REVIEW**
- **Finding:** `_shiftVerified` (line 331) is set to `true` when the guard taps "Capture + Start Shift" and reset to `false` on shift end. It is not derived from or cross-checked against `widget.recentEvents`. If the widget is rebuilt from a new parent (e.g. after a hot-reload, route pop, or `setState` at the parent that forces a new `GuardMobileShellPage` instance), `_shiftVerified` resets to `false` even if a real shift-start event is present in `recentEvents`.
- **Why it matters:** The "Shift Not Active" gate on the patrol image button (line 5508–5526) depends on `_shiftVerified`. A guard could be locked out of queuing patrol images after a widget rebuild even when their shift is actually open.
- **Evidence:** `lib/ui/guard_mobile_shell_page.dart:330–331`, `5508–5526`; `_hasOpenShift` (line 608) computes the correct lifecycle from events but is never used to seed `_shiftVerified`.
- **Suggested follow-up for Codex:** In `initState` (and `didUpdateWidget` when `recentEvents` changes), seed `_shiftVerified` from `_hasOpenShift(DateTime.now().toUtc())`.

---

### P2 — `_screensForRole` Called Repeatedly Per Build

- **Action: AUTO**
- **Finding:** `_screensForRole(widget.operatorRole)` is called at lines 2143, 2570, 2867, 6216, and 6222 in each build/layout pass. The method constructs a fresh `List` each call via `const [...]` inside a `switch` — the const lists are cached by Dart, but the method itself is invoked 5+ times per frame.
- **Why it matters:** Minor performance concern; primarily a clarity concern. The result is deterministic for a given `operatorRole` so it should be resolved once.
- **Evidence:** `lib/ui/guard_mobile_shell_page.dart:386–411`, called at `2143`, `2570`, `2867`, `6216`, `6222`.
- **Suggested follow-up for Codex:** Assign `final allowedScreens = _screensForRole(widget.operatorRole)` once at the top of `build()` and pass it where needed.

---

### P2 — O(n) Event List Scanned Multiple Times Per `build()` Pass in Sync Screen

- **Action: REVIEW**
- **Finding:** In the sync screen body (lines 3800–5170), the following helpers each iterate `widget.recentEvents` independently:
  - `_latestEventAt(shiftStart)`, `_latestEventAt(shiftEnd)` — two passes
  - `_latestResumeSyncTriggerAt()` — one pass
  - `_latestTelemetryPayloadHealthAlertAt()` — one pass
  - `_latestExportAuditResetEventAt()` — one pass
  - `_latestExportAuditGeneratedEventAt()` — one pass
  - `_shiftEventCount`, `_shiftEventFailedCount`, `_shiftEventPendingCount` — three passes
  - `_resumeSyncTriggerCount`, `_telemetryPayloadHealthAlertCount`, `_exportAuditResetEventCount`, `_exportAuditGeneratedEventCount` (multiple types) — 4+ passes
  - `_telemetryPayloadHealthTrendRows` — one pass with sort
  - `_recentExportAuditEvents` — called per filter chip (5 chips × 1 pass each)
  - `_pttLockscreenCaptureStatus` — one pass
  Total: 15–20 independent linear iterations over `recentEvents` per build of the sync screen.
- **Why it matters:** If `recentEvents` grows large (e.g. full shift of 200+ events), the sync screen rebuild cost is superlinear in event count. This is a hot path triggered by any parent `setState`.
- **Evidence:** `lib/ui/guard_mobile_shell_page.dart:598–720`, `877–889`, `3800–3826`, `4543–4558`.
- **Suggested follow-up for Codex:** Consider computing a `_GuardSyncShellDerivedState` record once per build from `recentEvents` and `recentMedia` (a single-pass pre-computation), then passing derived values to sub-methods. This collapses 15+ passes to 1.

---

### P3 — `_enforceOutcomeGovernance` Throws `StateError` Visible to Guard

- **Action: REVIEW**
- **Finding:** When `_enforceOutcomeGovernance` throws (lines 1233–1236), the message is `'Guard action failed: StateError: Confirmation role "guard" is not allowed for true_threat. Allowed: supervisor.'`. This is the raw exception text shown to a field guard in `_lastActionStatus`.
- **Why it matters:** On the panic screen during a live emergency, a guard seeing a technical `StateError` message is a UX failure in a safety-critical flow. The UI already shows a governance hint (lines 3609–3619) but does not prevent the button from being tapped.
- **Evidence:** `lib/ui/guard_mobile_shell_page.dart:1222–1237`, `3637–3645`, `6817–6821`.
- **Suggested follow-up for Codex:** Either disable the "Label: True Threat" button when `_outcomeConfirmedBy != 'supervisor'` and the policy requires it, or catch `StateError` in `_withSubmit` and translate to a user-readable message.

---

### P3 — `_operationModeFor` Scans `queuedOperations` Inside `build()` per Filter Chip

- **Action: AUTO**
- **Finding:** Lines 2233–2240 and 2947–2954 call `_operationModeFor(operation)` inside a `.where(...).length` chain inside a `.map` over `GuardSyncOperationModeFilter.values` — i.e. up to 4 mode-filter chips, each doing a full `queuedOperations` scan. This runs twice per build (compact branch and widescreen branch).
- **Why it matters:** With large operation queues, this is 4 × N work per build just for chip labels.
- **Evidence:** `lib/ui/guard_mobile_shell_page.dart:2225–2257`, `2940–2970`.
- **Suggested follow-up for Codex:** Pre-compute `Map<GuardSyncOperationModeFilter, int> operationCountsByMode` once per build.

---

### P3 — `no dispose()` Override

- **Action: AUTO**
- **Finding:** `_GuardMobileShellPageState` has no `dispose()` override. The state currently holds no streams or controllers, so this is not a live leak. But `_selectionClearNotifyQueued` and `addPostFrameCallback` registrations could in theory stack if the widget is removed before the callback fires.
- **Why it matters:** Defensive practice gap. If a `TextEditingController` or similar is added later (the `TextField` at line 3947 currently does not use one), there is no scaffold to clean it up.
- **Evidence:** `lib/ui/guard_mobile_shell_page.dart:316–6839` — no `dispose` method present.
- **Suggested follow-up for Codex:** Add a stub `dispose()` as a scaffold and move `_selectionClearNotifyQueued = false` into it to cancel any in-flight callback notification.

---

## Duplication

| Block | Locations | Centralization Candidate |
|---|---|---|
| Sync history content (filter chips, facade dropdown, scoped keys, metrics strip, queue clear, operation workspace) | lines ~2191–2415, ~2619–2844, ~2912–3128 | `_buildSyncHistoryContent()` or `_SyncHistoryContent` widget |
| Screen nav chips (`_screensForRole` → switch → chip) | lines 2143–2180, 2570–2608, 2866–2903 | `_buildScreenNavChips()` returning `List<Widget>` |
| `OnyxPageHeader` with role/guard/site/sync chips | compact branch lines 2008–2038, expanded branch lines 2436–2461 | Shared header builder |
| `syncStatusLabel` + `_lastActionStatus` text blocks | compact ~2061–2082, expanded ~2484–2505 | `_buildStatusTextRows()` |
| Coaching prompt ack/snooze buttons (identical logic with different `context:` string) | `_coachingPromptCard` lines 5225–5328, `_contextCoachingBanner` lines 5338–5484 | Extract shared `_coachingActionRow()` helper |

---

## Coverage Gaps

| Gap | Priority |
|---|---|
| `_enforceOutcomeGovernance` throws when `confirmedBy` is not in allowed list — no test asserts the UI shows an appropriate message or disables the button | High |
| `_shiftVerified` reset after widget rebuild (new widget instance with shift-start events in recentEvents) — no test verifies patrol image button availability survives rebuild | High |
| `didUpdateWidget` role-change → `_ensureScreenAllowedForRole` fallback — no test changes `operatorRole` after initial pump and asserts the active screen resets | Medium |
| `_confirmRetryAllFailedOps` dialog — no test pumps the dialog or verifies Cancel vs Retry paths | Medium |
| Bulk retry flow end-to-end — no test confirms `onRetryFailedOperationsBulk` receives the correct operation ID list | Medium |
| `_decodeCustomTelemetryPayloadJson` throws on empty or non-object input — no test confirms `_lastActionStatus` is set to an error string | Medium |
| `_telemetryPayloadHealthVerdictFromPayload` returns all four health states from synthetic payloads — no dedicated unit-level coverage (only integration via widget tests) | Medium |
| `_hasOpenShift` when latestStart == latestEnd (same-millisecond event) — `isAfter` returns false, open shift returns false — edge case untested | Low |
| Supervisor override snooze path in `_contextCoachingBanner` (`!canSnooze` branch) — no test explicitly covers this branch in a context-aware coaching banner | Low |
| `_exportHealthVerdict` / `_exportHealthReason` severity tie-breaking (generatedSeverity == ratioSeverity) — untested | Low |

---

## Performance / Stability Notes

1. **15–20 independent O(n) iterations over `recentEvents` per sync screen build** (see P2 finding above). No immediate breakage risk but will degrade with large shift event lists.

2. **`DateTime.now().toUtc()` called independently in `_syncTelemetryContextLines` (line 1731), `_buildSyncReport` (line 1627), `_buildShiftReplaySummary` (line 1805), `_buildDispatchCloseoutPacket` (lines 1868, 1896), and `_failedOpsMetricsStrip` (line 1097)**. Report-generation calls that compose multiple of these will have slightly inconsistent timestamps across sections.

3. **`_telemetryPayloadHealthTrendRows` sorts a new list on every call** (line 1511). This is called twice per render of the sync screen: once for `_telemetryPayloadHealthTrendLabel()` and once for `_telemetryPayloadHealthTrendDetails()`. The sort should be cached.

4. **`_recentExportAuditEvents(limit: widget.recentEvents.length, filter: X)` is called once per `_ExportAuditFilter` value** (5 calls) just to count matches for chip labels (lines 4543–4558). All five could be satisfied by a single scan that builds a frequency map.

---

## Recommended Fix Order

1. **Move `_selectedOperationId = null` out of `build()` into the `addPostFrameCallback` body** — P1, avoids potential mid-build state inconsistency, AUTO, low risk.

2. **Unify `DateTime.now()` in `_buildDispatchCloseoutPacket` and the caller in `_buildScreenPanel`** — P1, audit trail correctness, AUTO.

3. **Seed `_shiftVerified` from `_hasOpenShift` in `initState` / `didUpdateWidget`** — P2 bug risk for field operator UX, REVIEW before AUTO implementation.

4. **Extract `_buildScreenNavChips()`** — P2 duplication, AUTO, mechanical refactor.

5. **Pre-compute `allowedScreens` and `operationCountsByMode` once at top of `build()`** — P2/P3 performance, AUTO.

6. **Disable "Label: True Threat" button when governance policy blocks current confirmer** — P3 UX/safety, REVIEW.

7. **Extract sync history content block** — P2 duplication, REVIEW (touches layout contract).

8. **Add missing test cases for governance enforcement, `_shiftVerified` rebuild, and role-change `didUpdateWidget`** — Coverage gaps, AUTO.

9. **Evaluate `GuardSyncShellViewModel` extraction for domain health logic** — DECISION, architectural scope.
