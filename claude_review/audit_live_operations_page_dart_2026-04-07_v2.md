# Audit: live_operations_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/live_operations_page.dart`
- Read-only: yes

---

## Executive Summary

`live_operations_page.dart` is the largest single file in the codebase at **18,833 lines**. It is a classic god-widget: one `StatefulWidget` (`LiveOperationsPage`) whose state class (`_LiveOperationsPageState`) owns domain projection, business-rule routing, async I/O orchestration, camera health polling, operator command parsing, UI layout, scroll coordination, and snack-bar/dialog management all in one place. The overall quality of the logic within the file is solid — the event-projection pipeline is careful, the `didUpdateWidget` guard is thorough, and most async paths respect `mounted`. The structural risk, however, is very high: almost any new feature touch requires reasoning about 18 000 lines of interleaved state and UI. There are also several concrete bugs, one mutable-static race, persistent demo-data leakage into production paths, and at least ten `Future.delayed(Duration.zero)` hacks that hide lifecycle ordering problems. Coverage at the unit level (domain projection, command routing) is absent — only widget-level smoke tests exist.

---

## What Looks Good

- `didUpdateWidget` is thorough and defensively guards every major state-refresh trigger (scope change, event list change, camera scope change, replay history scope change, agent return, auto-audit receipt).
- `_projectedEventInputsChanged` uses an O(n) structural diff rather than identity-only comparison, which avoids missed refreshes when the parent rebuilds with a new list instance containing the same data.
- `_loadClientLaneCameraHealth` uses a serial counter (`_clientLaneCameraHealthRequestSerial`) to cancel stale in-flight responses — a correct in-widget approach to request cancellation without a dedicated service.
- `catch (error, stackTrace)` in `_loadClientLaneCameraHealth` (line 1433) logs both error and stack trace; the error is surfaced to the user via feedback, not silently swallowed.
- Manual ledger entries and projected ledger entries are merged and sorted at build time (line 2818), not stored as a sorted list, avoiding ordering drift when new entries are added.
- `_LiveOpsCommandReceipt` and `_LiveOpsReplayHistoryMemory` are pure value types with `copyWith`, keeping them easy to test if ever extracted.
- 79 widget-level test cases provide broad smoke coverage of routing, command parsing, guard/patrol answers, camera health, and control-inbox interactions.

---

## Findings

### P1 — Mutable static state shared across widget instances
- **Action: REVIEW**
- `_queueStateHintSeenThisSession` (line 1287) and `_replayHistoryMemoryByScopeThisSession` (line 1288–1290) are `static` mutable fields on `_LiveOperationsPageState`. Any two mounted instances of `LiveOperationsPage` (e.g. in a route that mounts the widget twice during a hot-restart or route-level rebuild) share and clobber this state. The `debugReset*` methods exist precisely because this pattern requires manual teardown.
- **Why it matters:** Silent cross-widget contamination; the hint-seen flag and the replay history continuity view can flip without any setState, making the UI show stale data or skip the new-user hint on first render.
- **Evidence:** `lib/ui/live_operations_page.dart:1287–1290`, `1662–1668`.
- **Suggested follow-up for Codex:** Validate whether two instances of this page can coexist in the widget tree (e.g. during route animation overlap). If yes, extract these fields to a provided `InheritedWidget` or pass them as constructor parameters so each instance owns its own copy.

---

### P1 — `_desktopWorkspaceActive` mutated inside `build`
- **Action: REVIEW**
- Line 2852: `_desktopWorkspaceActive = canUseEmbeddedDesktopLayout;` is a direct field mutation inside `build()`. This is not inside a `setState` call, so Flutter will not schedule a rebuild if the value changes — but more critically, mutating state during `build` violates the contract that `build` is pure and may be called at any time by the framework.
- **Why it matters:** `_desktopWorkspaceActive` gates whether `_showLiveOpsFeedback` shows a snack bar or updates the command receipt rail (lines 7920–7930). If a build runs after a feedback call but before the next user interaction, the state used by `_showLiveOpsFeedback` will be incorrect for that frame cycle.
- **Evidence:** `lib/ui/live_operations_page.dart:1334`, `2852`, `7920`, `7929`.
- **Suggested follow-up for Codex:** Move `_desktopWorkspaceActive` computation to `didChangeDependencies` or to a layout callback result stored via `addPostFrameCallback`, not inside `build`.

---

### P1 — Demo/fallback data silently bleeds into production renders
- **Action: REVIEW**
- `_deriveIncidents` (line 17403) falls back to `_fallbackIncidents()` — a set of hardcoded demo incidents — when the decisions list is empty and `allowDemoFallback` is `true`. `allowDemoFallback` is `!hasScopeFocus`, meaning any global (non-scoped) render with no live events silently renders demo incidents. The same pattern applies to `_deriveLedger` (line 18017–18064) which returns hardcoded ledger entries with real-looking incident IDs and timestamps from 2026-03-10 when events are empty.
- **Why it matters:** A production operator viewing the global war room with no active events will see fabricated incidents (Echo-3, Bravo-2, INC-8830) and ledger entries that appear real. This is a safety concern in a live security operations context — operators could act on phantom data.
- **Evidence:** `lib/ui/live_operations_page.dart:17403–17421`, `17527–?`, `18017–18064`.
- **Suggested follow-up for Codex:** Verify whether `allowDemoFallback` is intentional for demo/staging builds only or if it can fire in production. Consider gating with a compile-time or runtime flag rather than scope-focus state.

---

### P2 — Ten `Future.delayed(Duration.zero)` synchronization hacks
- **Action: REVIEW**
- `Future.delayed(Duration.zero)` is used at lines 1759, 1773, 1785, 1807, 1878, 1914, 4322, 4356, 4449, 7140 to yield one microtask tick between a `setState` call and a subsequent `Scrollable.ensureVisible` or panel navigation.
- **Why it matters:** This pattern is a post-frame scheduling hack that works accidentally — there is no guarantee the next frame has completed layout by the time the microtask fires. It will silently fail in jank-heavy environments or during test pump sequences that do not call `pumpAndSettle`.
- **Evidence:** `lib/ui/live_operations_page.dart:1759, 1773, 1785, 1807, 1878, 1914, 4322, 4356, 4449, 7140`.
- **Suggested follow-up for Codex:** Replace with `WidgetsBinding.instance.addPostFrameCallback` followed by `Scrollable.ensureVisible`. This guarantees the callback fires after the frame that committed the `setState` change.

---

### P2 — `_loadReplayHistorySignals` swallows all exceptions silently
- **Action: AUTO**
- Line 2619: `catch (_)` catches every exception from `_loadReplayHistorySignals` without logging the error or stack trace. The error path sets state to an empty list but gives no visibility into why the load failed.
- **Why it matters:** If the scenario replay service throws a persistent error (network, malformed data), the page renders silently with an empty history and no operator or developer signal.
- **Evidence:** `lib/ui/live_operations_page.dart:2619–2630`.
- **Suggested follow-up for Codex:** Replace `catch (_)` with `catch (error, stackTrace)` and add `debugPrint` at minimum.

---

### P2 — Similar swallowed exceptions in control-inbox approve/reject/update paths
- **Action: AUTO**
- Lines 16753, 16910, 16939: `catch (_)` in `_approveControlInboxDraft`, `_editControlInboxDraft`, and `_rejectControlInboxDraft` suppress all thrown errors. Only a user-facing snack message is shown; the actual exception is lost.
- **Why it matters:** Failed Telegram/API draft approvals will appear as generic UI errors with no log trail for debugging.
- **Evidence:** `lib/ui/live_operations_page.dart:16753, 16910, 16939`.
- **Suggested follow-up for Codex:** Same fix as above — log `error` and `stackTrace` in each catch block.

---

### P2 — `_commandPromptController` not cleared after command submission
- **Action: REVIEW** (suspicion, not confirmed)
- `_submitPlainLanguageCommand` (line 6978) does not call `_commandPromptController.clear()` after a successful command is dispatched. The user must manually clear the field to enter a new command.
- **Why it matters:** In a time-critical war room context this is an operator friction point. It may also be intentional (let operator re-edit), but the test at line 466 in the widget test does not verify post-submit field state.
- **Evidence:** `lib/ui/live_operations_page.dart:6978–7093`.
- **Suggested follow-up for Codex:** Confirm intended UX: if the command field should clear on success, add `_commandPromptController.clear()` after line 7092.

---

### P3 — 294 direct `GoogleFonts.inter(...)` calls inside build methods
- **Action: REVIEW**
- 294 `GoogleFonts.inter(...)` calls are scattered throughout build methods. `GoogleFonts.inter` constructs a new `TextStyle` on every call during every rebuild, and creates a new lookup against the font registry each time.
- **Why it matters:** The `build` method for `_LiveOperationsPageState` (line 2811) is already a very large rebuild surface. Each `setState` call (62 total) rebuilds the entire tree that includes these 294 style constructions.
- **Evidence:** `lib/ui/live_operations_page.dart` — 294 occurrences of `GoogleFonts.inter`.
- **Suggested follow-up for Codex:** Define shared `TextStyle` constants using `GoogleFonts.inter(...)` at the top of the file or in `OnyxDesignTokens`, and reference them by name inside build methods. `GoogleFonts.getFont` results are already cached by the package but avoid repeated argument construction.

---

### P3 — `_deriveLedger` hardcodes `events.take(40)`
- **Action: REVIEW**
- Line 17943: `_deriveLedger` silently truncates the event list to 40 entries before processing. If more than 40 events are in the window, newer events that appear earlier in the list can be silently dropped.
- **Why it matters:** The sort at line 17408 (`decisions.sort((a, b) => b.occurredAt.compareTo(a.occurredAt))`) sorts decisions before truncation, but `_deriveLedger` processes `events` directly before any sorting/truncation — so the first 40 events by insertion order are used, not the 40 most recent. In a long-running session this will cause the ledger to show stale entries while newer events are silently excluded.
- **Evidence:** `lib/ui/live_operations_page.dart:17941–17943`.
- **Suggested follow-up for Codex:** Sort by `occurredAt` descending before calling `.take(40)`, or apply the limit after deriving entries (line 18014) to ensure most-recent entries are preserved.

---

### P3 — `_hashFor` is not a cryptographic hash
- **Action: REVIEW**
- `_hashFor` (line 18806) returns `seed.hashCode.toUnsigned(32).toRadixString(16)`. `hashCode` is not stable across Dart VM restarts, not unique for different strings, and not collision-resistant. Ledger entry hashes rendered in the UI may collide for distinct events or produce different values between sessions.
- **Why it matters:** The UI presents these as verification hashes (field `verified: true`), which implies integrity. Operators who notice the same hash for different events or mismatched hashes across sessions may lose trust in ledger integrity signals.
- **Evidence:** `lib/ui/live_operations_page.dart:18806–18809`.
- **Suggested follow-up for Codex:** Replace with a stable hash (e.g. a truncated SHA-256 or a deterministic CRC32 over the event ID bytes). Alternatively, rename the field and label to make clear this is a display identifier, not a cryptographic verification.

---

## Duplication

### 1. Client-scope resolution logic repeated three times
- Lines 6135–6142 (`_commandDecisionForPrompt`), 6921–6928 (`_commandToolBridge`), and 17158–17160 (`_projectFromEvents`) each independently resolve `resolvedClientId` and `resolvedSiteId` by preferring `activeIncident`, falling back to `clientCommsSnapshot`, then to `widget.initialScopeClientId/SiteId`.
- **Files involved:** All three sites are in `_LiveOperationsPageState`.
- **Centralization candidate:** Extract a `_resolvedScopeIds({_IncidentRecord? activeIncident, LiveClientCommsSnapshot? clientCommsSnapshot})` → `({String clientId, String siteId})` helper.

### 2. `_commsMomentLabel` called with the same timestamp pairs in two separate dialog-opening methods
- Lines 1560–1566 (`_showClientLaneStreamRelayDialog`) and 9303–9312 (camera panel builder) independently call `_commsMomentLabel` on `currentVisualVerifiedAtUtc`, `lastSuccessfulVisualAtUtc`, `currentVisualRelayLastFrameAtUtc`, `currentVisualRelayCheckedAtUtc`. The label-building logic is identical.
- **Centralization candidate:** A `_cameraVerificationLabels(ClientCameraHealthFactPacket)` → record that pre-computes all four labels.

### 3. Busy-set immutable-set pattern repeated four times
- `_learnedStyleBusyScopeKeys` (line 1697–1708), `_laneVoiceBusyScopeKeys` (line 1730–1742), `_controlInboxBusyDraftIds` (line 16745), `_controlInboxDraftEditBusyIds` (line 16898) all use the same `setState(() { set = {...set, key}; }) → try/await/finally → setState(() { set = Set.from(set)..remove(key); })` pattern.
- **Centralization candidate:** A generic `AsyncBusySet<T>` helper or a `_withBusy<T>(Set<T> currentSet, T key, Future<void> Function() work)` method.

### 4. Dialog shell structure duplicated between `_ClientLaneLiveViewDialog` and `_ClientLaneStreamRelayDialog`
- Lines 404–609 (`_ClientLaneLiveViewDialog.build`) and 149–346 (`_ClientLaneStreamRelayDialog.build`) share identical outer scaffolding: `Dialog` → `ConstrainedBox` → `SingleChildScrollView` → `Column` → header row (title/subtitle/close icon) → `Wrap` chips → content area → `Wrap` action buttons.
- **Centralization candidate:** A shared `_LiveViewDialogShell` widget that accepts title, subtitle, chips, content, and actions as slots.

---

## Coverage Gaps

1. **No unit tests for `_projectFromEvents` / `_deriveIncidents` / `_deriveLedger` / `_deriveVigilance`.** These are pure transformation functions (inputs → projected model) that currently live inside the state class. All test coverage is at the widget level, which makes it expensive to test edge cases (e.g. IncidentClosed before DecisionCreated, scope filter with site mismatch, focus reference canonicalization with multiple intelligence events for the same site).

2. **`allowDemoFallback` fallback path is untested.** No widget test verifies that when `initialScopeClientId` is set and events are empty, no demo incidents appear. This is the production-safety gap from P1.

3. **`_hashFor` collision behavior is untested.** No test verifies that two different event IDs produce different display hashes.

4. **Camera preview auto-refresh timer teardown is untested.** No widget test verifies that `_clientLaneCameraPreviewTimer` is cancelled when `clientCommsSnapshot` changes to `null` mid-session (the `_syncClientLaneCameraPreviewTimer` guard at line 1638–1641 should handle this, but it is not exercised).

5. **Override dialog reason-code selection guard is tested (line 3897 in test file) but the `_forceDispatch` path has no test.** The happy path of force-dispatch (button tap → `_forceDispatch` → ledger entry → `_projectFromEvents`) is not covered.

6. **`_submitPlainLanguageCommand` with each specialized intent branch** (`patrolReportLookup`, `guardStatusLookup`, `showSiteMostAlertsThisWeek`, `showIncidentsLastNight`, `showDispatchesToday`, `showUnresolvedIncidents`, `summarizeIncident`) is only partially covered. There are widget tests for guard status and patrol lookup, but the remaining five branches (`showSiteMostAlertsThisWeek`, `showIncidentsLastNight`, `showDispatchesToday`, `showUnresolvedIncidents`, `summarizeIncident`) appear to have no dedicated failure-path tests (what happens when the service returns empty data or throws).

7. **`_rejectControlInboxDraft` has no test.** The approve and edit paths are covered but reject is absent from the test file.

---

## Performance / Stability Notes

1. **62 `setState` calls in a single 18 833-line state class.** Every `setState` rebuilds the entire `build` tree which, even with `const` subtrees, is a very large widget tree evaluation. The `LayoutBuilder` at line 2836 and `MediaQuery.sizeOf` at line 2821 mean any viewport change re-runs all of `build`.

2. **294 `GoogleFonts.inter(...)` calls inside the build path** (see P3 above). Each call allocates a new `TextStyle` object. At 60 fps during scroll or animation, this is significant allocation pressure.

3. **`_deriveLedger` and `_deriveVigilance` are called inside `setState` (line 17215)**, which means they run synchronously on the UI thread during a state update. Both iterate over the full event list. For large event windows (many sites, long sessions), this will cause frame-budget pressure. There is no memoization — if events have not changed, the derivation runs again on every `_projectFromEvents` call.

4. **`_replayHistoryMemoryByScopeThisSession` is rebuilt as a new spread map on every write** (lines 2647–2649, 2657–2660). For a session with many scope switches, this creates many intermediate map allocations. A mutable `HashMap` would be more appropriate for a session-scoped cache.

5. **`_storeReplayBackedCommandReceipt` / `_rememberReplayHistorySummary`** (not shown but called from `_showLiveOpsFeedback`) update the static session-scoped memory map on every operator feedback call. This means every snack bar / receipt update writes to a static map — coupling UI feedback to a persistence path in the hot feedback path.

---

## Recommended Fix Order

1. **(P1) Extract `_desktopWorkspaceActive` mutation out of `build`** — this is a correctness issue that affects the feedback rail vs. snack-bar routing on every render.
2. **(P1) Audit the mutable static fields** (`_queueStateHintSeenThisSession`, `_replayHistoryMemoryByScopeThisSession`) — confirm whether multiple instances can coexist and decide on owner.
3. **(P1) Gate demo/fallback data behind an explicit flag** — highest safety risk in a live ops context.
4. **(P2) Log all swallowed exceptions** (`_loadReplayHistorySignals`, approve/edit/reject paths) — AUTO, low risk.
5. **(P2) Replace `Future.delayed(Duration.zero)` with `addPostFrameCallback`** — prevents rare but silent scroll failures in test and production.
6. **(P3) Fix `_deriveLedger` sort-before-truncate** — silent data loss in long sessions; AUTO, low risk.
7. **(Duplication) Extract client-scope resolution helper** — reduces drift risk across three call sites.
8. **(Coverage) Extract and unit-test `_deriveIncidents` / `_deriveLedger` / `_deriveVigilance`** — these are pure functions that should be testable outside the widget.
9. **(Performance) Define shared `TextStyle` constants** for `GoogleFonts.inter` — reduces allocation pressure on hot rebuild paths.
10. **(P3) Replace `_hashFor` with a stable deterministic hash** or relabel the output so operators are not misled about its integrity properties.
