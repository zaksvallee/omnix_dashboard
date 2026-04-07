# Audit: guard_mobile_shell_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/guard_mobile_shell_page.dart`
- Read-only: yes

---

## Executive Summary

`GuardMobileShellPage` is the largest single file in the repository at **6850 lines**. It is a well-intentioned diagnostic and field-ops shell, but it has grown into a God widget. All six guard screens, the sync console, telemetry health diagnostics, export audit timeline, coaching banner, shift lifecycle logic, and clipboard exports are implemented inside one `StatefulWidget` state class. The constructor carries **~60 parameters** and the `build()` method is bifurcated into two nearly-identical layout branches (compact and desktop), each clocking in at ~600 lines.

There are no structural crashes and the callback-based prop model is safe for a read-only shell. The primary risks are: a `build()`-time side-effect call that can schedule redundant state changes, a silent `_selectedOperation` fallback that creates selection drift, unguarded future calls after clear-queue, and a significant test gap across all non-happy-path flows.

---

## What Looks Good

- `_withSubmit` consistently guards all async callbacks with `mounted` checks and surfaces errors into `_lastActionStatus` rather than crashing.
- `_queueSelectedOperationClear` uses a debounce flag (`_selectionClearNotifyQueued`) to avoid stacking post-frame callbacks.
- `_ensureScreenAllowedForRole` and `_ensureValidOutcomeConfirmer` are called from both `initState` and `didUpdateWidget`, keeping role-gating consistent across hot reloads.
- `_payloadInt`, `_payloadBool`, `_payloadDateTime` are small, well-scoped helpers that safely coerce untyped payload maps.
- `_exportHealthVerdict` and `_telemetryPayloadHealthVerdict` correctly compute severity from multiple independent signals before picking the max.

---

## Findings

### P1 — Side-Effect Call Inside `build()`

- **Action:** REVIEW
- **Finding:** `_queueSelectedOperationClear()` is called unconditionally from inside `build()` at lines 1988–1993 whenever `_selectedOperationId` is not found in `visibleHistoryOperations`. That method schedules a `setState` via `addPostFrameCallback` and also fires `unawaited(widget.onSelectedOperationChanged(null))`.
- **Why it matters:** Calling `addPostFrameCallback` from inside `build()` is valid, but here it also fires an external async callback (`onSelectedOperationChanged`) from a build-triggered post-frame path. If the widget rebuilds multiple times before the callback resolves (e.g., due to rapid filter changes), the callback can fire multiple times in the same build cycle. The `_selectionClearNotifyQueued` guard only prevents double-scheduling within a single build pass; it resets to `false` before the callback body runs, so a second rebuild between schedule and callback execution would re-schedule.
- **Evidence:** Lines 1988–1993 (build method), lines 371–388 (`_queueSelectedOperationClear`).
- **Suggested follow-up:** Codex to verify whether `onSelectedOperationChanged(null)` is idempotent. If it triggers a DB write or state broadcast, the redundant-fire window is real.

---

### P1 — Unguarded Future After `onClearQueue`

- **Action:** AUTO
- **Finding:** In the "Clear Queue" button handler (compact layout line ~2396, desktop layout line ~3105), after `_withSubmit` returns, the code calls `await widget.onSelectedOperationChanged(null)` without a prior `mounted` check.
- **Why it matters:** `_withSubmit` already checks `mounted` internally, but after it completes the outer async handler continues with `await widget.onSelectedOperationChanged(null)`. If the widget is unmounted between `_withSubmit` returning and the outer `await`, calling a widget callback on an unmounted widget leaks the call.
- **Evidence:** Compact layout ~lines 2398–2404; desktop layout ~lines 3112–3118. Both branches have the same pattern: `if (!mounted) return; setState(() { _selectedOperationId = null; }); await widget.onSelectedOperationChanged(null);`
- **Suggested follow-up:** Add `if (!mounted) return;` immediately before the `await widget.onSelectedOperationChanged(null)` call in both branches.

---

### P1 — Silent Selection Drift in `_selectedOperation`

- **Action:** REVIEW
- **Finding:** `_selectedOperation(operations)` at lines 1223–1234 silently falls back to `operations.first` when `_selectedOperationId` is not found in the visible list. This means changing the operation mode filter or facade filter causes the detail panel to silently show a different operation without updating the selection state or calling `onSelectedOperationChanged`.
- **Why it matters:** The state reads `_selectedOperationId` for the detail panel, the desktop status banner chip ("Selected Op"), and the copy logic. When those diverge (ID says one thing, detail shows another), clipboard exports will contain the fallback operation's data while the UI shows a different operation ID in the chip. This is a silent data mismatch, not just a cosmetic flicker.
- **Evidence:** Lines 1223–1234 (`_selectedOperation`); lines 6017–6024 (`_guardDesktopWorkspaceStatusBanner`) uses a separate iteration over `widget.queuedOperations` and doesn't go through `_selectedOperation`, so the banner and the detail panel can show different operations.
- **Suggested follow-up:** On filter change, if `_selectedOperationId` is no longer in the visible set, `_selectedOperationId` should be reset to null (or to the new first's ID) and `onSelectedOperationChanged` called, rather than allowing silent fallback in the getter.

---

### P2 — `_screensForRole` Called Redundantly Every Build

- **Action:** AUTO
- **Finding:** `_screensForRole(widget.operatorRole)` is called at least 4 times per build cycle: once in the screen chip `Wrap` (compact ~line 2154, desktop ~line 2582), and twice in `_guardScreenWorkspace` (lines 6226, 6233). Each call performs a `switch` and allocates a new `const` list.
- **Why it matters:** `const` list allocation is cheap, but calling `_screensForRole` multiple times in the same build frame with the same argument is unnecessary. If the role changes, `didUpdateWidget` already calls `_ensureScreenAllowedForRole`. The result is stable within a frame and should be a local variable.
- **Evidence:** Lines 2154, 2582, 6226, 6233.
- **Suggested follow-up:** Codex to assign `final screens = _screensForRole(widget.operatorRole)` once in `build()` and thread it through.

---

### P2 — `DateTime.now().toUtc()` Called Independently Across Methods

- **Action:** AUTO
- **Finding:** `DateTime.now().toUtc()` is called independently inside `_failedOpsMetricsStrip` (line 1118), `_buildSyncReport` (line 1648), `_buildShiftReplaySummary` (line 1826), `_buildDispatchCloseoutPacket` (line 1889), `_syncTelemetryContextLines` (line 1752), and inside `_telemetryPayloadHealthVerdictFromPayload` (line 1579). When multiple of these are called in the same build frame, they return slightly different timestamps.
- **Why it matters:** In telemetry health calculations (e.g., `_telemetryCallbackFresh`) the freshness boundary is 2 minutes. Independent `now` calls across the build pass mean the freshness verdict for a chip label and the freshness verdict inside the clipboard export could differ for values near the boundary. This is unlikely to cause a user-visible bug but creates non-determinism in tests.
- **Evidence:** Lines 1118, 1579, 1648, 1752, 1826, 1889.
- **Suggested follow-up:** `nowUtc` is already passed as a parameter to `_telemetryPayloadHealthVerdict`, `_exportHealthVerdict`, etc. Codex to trace which callers create their own `nowUtc` and unify via a single `final nowUtc = DateTime.now().toUtc()` in `build()`, passed through.

---

### P2 — Massive Build Method Duplication (Compact vs Desktop)

- **Action:** REVIEW
- **Finding:** `build()` contains two completely separate widget trees for compact and desktop layouts (roughly lines 2015–2442 vs. 2444–3192). The following blocks are duplicated verbatim:
  - `OnyxPageHeader` with role/guard/site/sync chips
  - `_summaryStatsStrip` call
  - Reaction Ops / Supervisor Ops chip `Wrap`
  - `syncStatusLabel` and `_lastActionStatus` display
  - `historyRows` inner function (defined identically in both branches)
  - `guardScreenFlowPanel` / `syncHistoryPanel` construction
  - History filter chips, facade filter dropdown, scoped selection chips, failed ops metrics strip, clear queue button

  Both branches total ~1200 lines of near-identical layout code.
- **Why it matters:** A bug fix or feature change in one branch must be manually mirrored to the other. Past evidence of divergence: the desktop branch gained `_guardDesktopWorkspaceStatusBanner` and `stackPanels` logic without equivalent in compact, while compact retained `OnyxSectionCard` wrappers that the desktop branch dropped. The two branches are already slightly inconsistent (desktop uses `Expanded` + `_workspaceInsetPanel`, compact uses `OnyxSectionCard`), meaning future changes will silently diverge further.
- **Evidence:** Lines 2015–2442 (compact), lines 2444–3192 (desktop).
- **Suggested follow-up:** Extract the shared header, stats strip, coaching chips, and status text into helper methods. The layout-specific wiring (scrollable vs. expanded) can remain split, but the content children should be built once. This is a REVIEW item rather than AUTO because the right factoring depends on whether compact/desktop layout divergence is intentional.

---

### P2 — `_historyOperationWorkspace` Type-Checks Against Concrete Widget

- **Action:** AUTO
- **Finding:** Lines 6416 and 6420 check `detailPanel is SizedBox` and `detailPanel is! SizedBox` to decide layout branching. `_operationDetailPanel` returns `const SizedBox.shrink()` when no operation is selected (line 6651).
- **Why it matters:** This is a structural coupling: UI layout decisions depend on the concrete type returned by a private method. If `_operationDetailPanel` is refactored to return a different empty widget (e.g., wrapped in `Visibility`, `AnimatedSwitcher`, or `ConstrainedBox`), the layout branch silently breaks and the detail panel takes up half the row even when empty.
- **Evidence:** Lines 6416, 6420.
- **Suggested follow-up:** Replace with an explicit `bool _hasSelectedOperation` check or have `_operationDetailPanel` return `null` when empty, with the caller guarding on null.

---

### P2 — `_decodeCustomTelemetryPayloadJson` Throws Unguarded `FormatException`

- **Action:** AUTO
- **Finding:** `_decodeCustomTelemetryPayloadJson` (lines 495–505) calls `jsonDecode(raw)` without a try/catch. `jsonDecode` throws `FormatException` for malformed JSON. The caller of this method will be inside `_withSubmit`, so the error is caught and displayed as `_lastActionStatus`. However, the thrown type is `FormatException` — not `StateError` — so anyone reading the method signature or using it outside `_withSubmit` would not expect it to throw a format exception.
- **Why it matters:** The exception is swallowed into `_lastActionStatus` in normal use, so this isn't a crash risk. But the silent contract means if the method is ever called outside `_withSubmit`, a malformed JSON string crashes the caller.
- **Evidence:** Lines 495–505.
- **Suggested follow-up:** Wrap `jsonDecode` in a try/catch and rethrow as `StateError('Invalid JSON: $e')` for a consistent exception contract.

---

### P3 — `_operationRuntimeContext` Silently Drops Non-Map Payloads

- **Action:** AUTO
- **Finding:** `_operationRuntimeContext` (lines 6724–6729) returns `null` if `operation.payload['onyx_runtime_context']` is not a `Map`. No warning, no logging. Callers treat `null` as "context unavailable" and silently skip the context chips.
- **Why it matters:** If the `onyx_runtime_context` key exists but contains a non-map value (e.g., a string `"migrated"` written by an older format), the telemetry mode chips are silently hidden rather than showing a degraded state. This is acceptable for a diagnostic shell but creates invisible data gaps.
- **Evidence:** Lines 6724–6729.
- **Suggested follow-up:** Suspicion only, not a confirmed bug. Codex to verify whether `onyx_runtime_context` can ever be a non-map in real payloads.

---

## Duplication

### 1. Compact vs Desktop Header + Status Block
- Lines 2020–2094 (compact) vs. 2447–2516 (desktop)
- Identical: `OnyxPageHeader`, reaction ops chips, syncStatusLabel, lastActionStatus text block
- Centralization candidate: extract into `_buildPageHeaderBlock()` and `_buildStatusAnnotations()` helpers

### 2. `historyRows` Inner Function
- Defined twice identically: inside compact `LayoutBuilder` (~lines 2097–2141) and inside desktop `LayoutBuilder` (~lines 2525–2569)
- Centralization candidate: extract to a private method `_buildHistoryRows({required bool embeddedScroll})`

### 3. Sync History Panel Content
- Compact `syncHistoryPanel` (lines 2202–2427) and desktop `syncHistoryBody` (lines ~2700–3140) contain the same history filter chips, mode filter chips, facade dropdown, scoped selection chips, metrics strip, and clear queue button
- Centralization candidate: extract to `_buildSyncHistoryContent()`

### 4. `_recentExportAuditEvents` Scan Pattern
- Lines 678–691, 693–703, 719–731, 743–751 all scan `widget.recentEvents` with the pattern: `filter by syncStatus eventType → filter by payload key → fold for latest timestamp`
- A shared `_latestSyncStatusEventWhere(bool Function(Map<String,Object?>) test)` helper would remove the fold boilerplate

---

## Coverage Gaps

- **`_selectedOperation` fallback-to-first**: No test covers the case where `_selectedOperationId` does not match any visible operation. The silent fallback to `operations.first` is not tested.
- **`_enforceOutcomeGovernance` throw path**: `_enforceOutcomeGovernance` throws `StateError` when `confirmedBy` is not allowed. No test exercises this path to confirm it surfaces via `_withSubmit`.
- **`_decodeCustomTelemetryPayloadJson` with malformed JSON**: No test for the `FormatException` path.
- **Role screen gating**: `_ensureScreenAllowedForRole` is not covered by any widget test. The role-change path in `didUpdateWidget` is untested.
- **`didUpdateWidget` screen transition**: When `initialScreen` changes, the screen should update. No test covers this transition.
- **`_withSubmit` error surface**: No test verifies that a thrown error appears in `_lastActionStatus` and that `_submitting` returns to `false` after failure.
- **Export audit health verdict under each severity band**: `_exportHealthVerdict` and `_exportRatioHealthSeverity` have four distinct paths. Only the zero-activity path appears to be exercised by current tests.
- **Telemetry payload health trend rows**: `_telemetryPayloadHealthTrendRows` filters and sorts `recentEvents`; no widget test exercises this with real fixture data.
- **Compact vs desktop layout branching**: The test file only sets a phone viewport (`390×844`). There are no tests at tablet (1100–1280px) or desktop (>1280px) widths where the two branches diverge.

---

## Performance / Stability Notes

- **`_failedOpsMetricsStrip` called from `build()`**: This method iterates all `operations` twice (once to filter failed, once to fold retry count) and calls `DateTime.now().toUtc()` to compute oldest age. For queues with many operations (hundreds), this runs every rebuild. It should receive a pre-filtered list or be memoized.
- **`_visibleOperationsByMode` called in `build()` and passed into `_historyOperationWorkspace`**: This method filters all `queuedOperations` on every rebuild when the mode is not `all`. For large operation lists, this is a hot-path allocation per frame. Not a present issue, but worth noting as queue depth grows.
- **`_recentExportAuditEvents` creates a sorted copy**: Called during the sync screen render (`_guardScreenWorkspace` → `_buildScreenPanel` → sync case). Sorting is O(n log n) on every rebuild of the sync screen. For typical shift sizes this is negligible, but the repeated sort without caching is worth flagging.
- **Google Fonts lookups in every widget build**: The file calls `GoogleFonts.inter(...)` and `GoogleFonts.jetBrainsMono(...)` at dozens of call sites. `google_fonts` caches `TextStyle` instances, so this is not a crash risk, but it means many `TextStyle` object allocations per build pass. The styles are uniform enough that a small set of private `TextStyle` constants would eliminate the allocation churn.

---

## Recommended Fix Order

1. **Add `mounted` guard before `await widget.onSelectedOperationChanged(null)` in both clear-queue handlers** (P1 AUTO — small, safe, two-line fix in two places).
2. **Review `_queueSelectedOperationClear` call from `build()`** (P1 REVIEW — assess whether `onSelectedOperationChanged` is idempotent; if so, the risk is low).
3. **Fix `_selectedOperation` fallback drift** (P1 REVIEW — decide product behavior: reset to null or accept first fallback, then enforce via state rather than getter).
4. **Replace `detailPanel is SizedBox` type check with explicit null/bool** (P2 AUTO — single method refactor).
5. **Wrap `jsonDecode` in `_decodeCustomTelemetryPayloadJson`** (P2 AUTO — one try/catch).
6. **Cache `_screensForRole` result in `build()`** (P2 AUTO — one local variable assignment).
7. **Deduplicate `historyRows` inner function** (P2 AUTO — extract to private method, low risk).
8. **Add widget tests for role screen gating, `didUpdateWidget` screen transition, `_withSubmit` error path, compact vs desktop layout widths** (coverage gap — significant effort, schedule separately).
9. **Extract compact/desktop header and status annotation blocks into shared helpers** (P2 REVIEW — medium refactor, risk of subtle layout divergence if rushed).
