# Audit: live_operations_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/live_operations_page.dart` (18,582 lines)
- Read-only: yes

---

## Executive Summary

`live_operations_page.dart` is the largest file in the repository at 18,582 lines and is the most severe god-object found in this codebase. The single `_LiveOperationsPageState` class owns incident projection, cue classification, draft sorting, camera health polling, stream relay dialog orchestration, command parsing dispatch, ledger management, vigilance derivation, replay history memory, queue filter state, and every UI panel across three layout modes. This creates extreme coupling, a massive rebuild surface, and makes the file nearly untestable at the integration boundary.

Several concrete bugs were found: a state mutation during `build()`, two instances of static shared mutable state that survive across widget instances and test runs, a duplicated `didUpdateWidget` condition block, a silent exception swallow in the camera loader, and dead-code in a recovery message branch. Significant algorithmic waste exists in the sort comparator and in the `ledger` list reconstruction on every build.

Test coverage (7,241 lines) is substantial at the widget level, but critical unit-level gaps exist for the classification and projection logic, which are untestable in isolation because they live inside the state class.

---

## What Looks Good

- **Camera health request serial guard** (`_clientLaneCameraHealthRequestSerial`, lines 1408/1425): correctly prevents stale async results from applying after scope changes. A sound pattern.
- **Dialog separation**: `_ClientLaneLiveViewDialog` and `_ClientLaneStreamRelayDialog` are properly extracted as StatefulWidget / StatelessWidget rather than being built inline in state methods.
- **`_projectedEventInputsChanged`** (line 2561): a focused, efficient change detector that avoids rebuilding from events unless relevant fields actually changed.
- **`ValueKey` discipline**: nearly all interactive elements carry stable `ValueKey` identifiers, which enables reliable widget test targeting.
- **Timer lifecycle**: camera preview timer is cancelled in `dispose()` and guarded with `!mounted` in the tick callback — no timer leak.
- **`_liveOpsReplayHistoryMemoryScopeKey`** scoping logic is clean and handles the `clientId`/`siteId`/`incidentReference` hierarchy clearly.

---

## Findings

### P1 — State mutation inside `build()`

- **Action: REVIEW**
- **Finding:** `_desktopWorkspaceActive = canUseEmbeddedDesktopLayout;` is assigned directly inside the `build()` method of `_LiveOperationsPageState`.
- **Why it matters:** `build()` must be a pure function of the current state. Mutating a field during `build()` means `_desktopWorkspaceActive` is only accurate after a build completes. The field is read by `_showLiveOpsFeedback()` (line 7759, 7768) to decide whether to show a SnackBar or update the receipt card. If `_showLiveOpsFeedback` is called before the next build (e.g., from a timer or callback), `_desktopWorkspaceActive` may reflect the stale value from the previous build layout.
- **Evidence:** `lib/ui/live_operations_page.dart:2826` (`_desktopWorkspaceActive = canUseEmbeddedDesktopLayout;`)
- **Suggested follow-up:** Codex should verify whether any path calls `_showLiveOpsFeedback` in the window between a viewport resize and the subsequent build completing. If so, the field must be computed defensively from current constraints, not cached from the last build.

---

### P1 — Static mutable state shared across widget instances

- **Action: REVIEW**
- **Finding:** Two `static` fields on `_LiveOperationsPageState` are writable mutable state:
  - `static bool _queueStateHintSeenThisSession` (line 1282)
  - `static Map<String, _LiveOpsReplayHistoryMemory> _replayHistoryMemoryByScopeThisSession` (lines 1283–1285)
- **Why it matters:** Static fields are class-level, not instance-level. If two `LiveOperationsPage` instances exist simultaneously (e.g., in a multi-route stack, a split-screen layout, or in tests that don't call the debug reset helpers), they share and overwrite each other's queue-hint-seen state and replay history memory. The test file provides `debugResetQueueStateHintSession()` and `debugResetReplayHistoryMemorySession()` (lines 1257–1263) to work around this, but tests that fail to call these will silently inherit state from prior test cases.
- **Evidence:** `lib/ui/live_operations_page.dart:1282–1285`, `lib/ui/live_operations_page.dart:1643–1650`
- **Suggested follow-up:** Codex should audit all widget tests in `test/ui/live_operations_page_widget_test.dart` to confirm every test that depends on clean static state calls both reset helpers in `setUp`. Also assess whether the static design is intentional (session singleton) or accidental coupling.

---

### P2 — Duplicated `didUpdateWidget` condition block triggers double camera reload

- **Action: AUTO**
- **Finding:** In `didUpdateWidget` (lines 2543–2558), the same three-condition check (`clientId trim changed || siteId trim changed || onLoadCameraHealthFactPacketForScope changed`) appears twice — first to call `_syncClientLaneCameraPreviewTimer()` and then immediately to call `unawaited(_loadClientLaneCameraHealth())`. These two calls should be inside a single `if` block.
- **Why it matters:** As written, if the condition is true, both branches execute correctly. However, the duplicated guard is a maintenance hazard — a future developer editing the first block may not notice the second. It also reads as if the second call is independent, which it is not.
- **Evidence:** `lib/ui/live_operations_page.dart:2543–2558`
- **Suggested follow-up:** Codex should merge both calls under one `if` block. Functional behavior is unchanged.

---

### P2 — Silent exception swallow in camera health loader

- **Action: REVIEW**
- **Finding:** `_loadClientLaneCameraHealth()` wraps the `loader()` call in a bare `catch (_) { packet = null; }` (lines 1420–1424). Any exception from the external loader — network error, null dereference, platform exception — is silently discarded. The operator sees no feedback.
- **Why it matters:** A failed camera health check leaves `_clientLaneCameraHealthFactPacket` as `null` with `_clientLaneCameraHealthLoading = false`. The UI displays as if the camera is unavailable, which is indistinguishable from "no camera configured". This can mislead an operator who expected a visual confirmation.
- **Evidence:** `lib/ui/live_operations_page.dart:1420–1424`
- **Suggested follow-up:** Codex should assess whether to add a distinct error state (e.g., `_clientLaneCameraHealthError = true`) that the UI can surface, or at minimum log the caught error for diagnostics.

---

### P2 — Dead-code branch in `_openClientLaneRecovery` message

- **Action: AUTO**
- **Finding:** In `_openClientLaneRecovery` (lines 1870–1907), both branches of the `snapshot == null` ternary at line 1898 produce the identical string `'Client Comms fallback opened in place.'`. The `null` branch and the non-null branch produce the same message.
- **Why it matters:** The ternary condition is functionally dead. One of the two string literals is unreachable as intended, which suggests the `null` case message was either never written or was accidentally collapsed to match the non-null case during a refactor.
- **Evidence:** `lib/ui/live_operations_page.dart:1898`
- **Suggested follow-up:** Codex should verify which message is correct for each branch and restore the missing distinct copy, or collapse the ternary to a single string if both branches genuinely should say the same thing.

---

### P2 — `_appendCommandLedgerEntry` uses two separate `DateTime.now()` calls for ID and hash

- **Action: AUTO**
- **Finding:** `_appendCommandLedgerEntry` (lines 7703–7728) calls `DateTime.now().microsecondsSinceEpoch` separately for the `id` field and for the hash seed. If the clock advances between the two calls, the hash seed will not match the ID timestamp.
- **Why it matters:** While the window is tiny, the hash would not be a deterministic function of the entry ID. For a ledger intended to prove tamper-evidence, hash/ID consistency matters semantically. In tests running under clock manipulation, this can also produce divergence.
- **Evidence:** `lib/ui/live_operations_page.dart:7710`, `lib/ui/live_operations_page.dart:7716`
- **Suggested follow-up:** Codex should capture `DateTime.now().microsecondsSinceEpoch` into a single local variable and use it for both the `id` and the hash seed.

---

### P2 — Widget callback invoked inside `setState` in queue hint cycle methods

- **Action: REVIEW**
- **Finding:** `_markQueueStateHintSeen()` (lines 1652–1656) calls `widget.onQueueStateHintSeen?.call()` — a parent widget callback. This method is called directly inside `setState(() { _markQueueStateHintSeen(); })` in `_cycleControlInboxQueueStateChip` (lines 1776, 1783, 1795) and `_dismissQueueStateHint` (line 1806). Invoking a parent callback inside `setState` can trigger parent `setState` during a child's build-phase scheduling, which is fragile under Flutter's rebuild cycle.
- **Why it matters:** If the parent callback calls `setState` synchronously, Flutter may fire a rebuild on the parent tree while the child `setState` is still being scheduled. In practice this often works, but it can produce "setState called during build" errors in edge cases, particularly during hot reload or test pump sequences.
- **Evidence:** `lib/ui/live_operations_page.dart:1652–1656`, `lib/ui/live_operations_page.dart:1776–1806`
- **Suggested follow-up:** Codex should assess whether `widget.onQueueStateHintSeen?.call()` should be moved to a `WidgetsBinding.instance.addPostFrameCallback` or called after the `setState` closure, not inside it.

---

## Duplication

### 1. Two divergent cue-kind classification methods

- **Files:** `lib/ui/live_operations_page.dart:1967` (`_liveClientLaneCueKind`) and `lib/ui/live_operations_page.dart:2050` (`_controlInboxDraftCueKindForSignals`)
- **What they share:** Both return `_ControlInboxDraftCueKind` via the same keyword-matching logic over source text, reply text, and voice profile signals.
- **Where they diverge:** `_controlInboxDraftCueKindForSignals` additionally matches `'arrived'`, `'how long'`, `'arrived'` in the timing branch; checks `reply` text for timing keywords; and includes a `concise` branch (`'concise-updates'`, `'short'`, `'brief'`). `_liveClientLaneCueKind` has none of these.
- **Risk:** A future update to one classifier may not propagate to the other, causing the snapshot-level cue and the per-draft cue to diverge for the same message.
- **Centralization candidate:** A single `_classifyControlInboxCue({required String sourceText, required String replyText, required String voiceProfileLabel, required String learnedStyleExample, bool usesLearnedStyle = false})` function in a domain service, called from both sites.

### 2. Two cue-message switch statements with overlapping text

- **Files:** `lib/ui/live_operations_page.dart:2025` (`_liveClientLaneCueMessage`) and `lib/ui/live_operations_page.dart:2121` (`_controlInboxDraftCueMessage`)
- **What they share:** Both switch over `_ControlInboxDraftCueKind` and return operator-facing guidance strings. Six of the eight branches produce identical text.
- **Where they diverge:** `validation` branch differs slightly: `_liveClientLaneCueMessage` says "make sure the exact check is clear", `_controlInboxDraftCueMessage` says "make sure the next confirmed step is clear".
- **Centralization candidate:** Unify into one function; if the `validation` difference is intentional, pass a `bool perDraft` flag.

### 3. Three near-identical `Scrollable.ensureVisible` helpers

- **Files:** `lib/ui/live_operations_page.dart:1809`, `1822`, `1835`
- **Methods:** `_ensureControlInboxPanelVisible`, `_ensureActionLadderPanelVisible`, `_ensureContextAndVigilancePanelVisible`
- **Only difference:** `GlobalKey` reference and `alignment` value (0.04 / 0.08 / 0.06).
- **Centralization candidate:** `Future<void> _ensurePanelVisible(GlobalKey key, {double alignment = 0.06})`

### 4. Camera URL copy pattern repeated

- **Files:** `lib/ui/live_operations_page.dart:1454` (`_copyClientLaneCameraPreviewUrl`) and `lib/ui/live_operations_page.dart:1513` (`_copyClientLaneStreamPlayerUrl`)
- **Pattern:** Extract URI → guard null → `Clipboard.setData` → guard `!mounted` → `_showLiveOpsFeedback(...)` with fixed label/accent.
- **Centralization candidate:** `Future<void> _copyUriToClipboard(Uri uri, {required String message, required String detail})`.

---

## Coverage Gaps

### 1. Cue classification logic is untestable in isolation

`_liveClientLaneCueKind` and `_controlInboxDraftCueKindForSignals` are private instance methods of `_LiveOperationsPageState`. Their logic cannot be unit-tested without pumping a full widget. The divergence between the two classifiers (timing detection for `'arrived'`, `'how long'`; missing `concise` branch in the snapshot classifier) means an operator messaging path that triggers `concise` on a per-draft basis will never trigger it on the snapshot-level cue — and this cannot be caught by a unit test.

**Suggested follow-up:** Extract classification into a testable domain function or service. Add dedicated unit tests for each keyword branch, including `'arrived'`, `'how long'`, `concise`, and the `default` fallback.

### 2. Static state isolation between widget tests

The test file includes `debugResetQueueStateHintSession()` and `debugResetReplayHistoryMemorySession()`. If any test that sets `_queueStateHintSeenThisSession = true` or writes to `_replayHistoryMemoryByScopeThisSession` does not call both reset helpers before or after execution, subsequent tests will inherit corrupted state. This is a hidden test-ordering dependency.

**Suggested follow-up:** Codex should audit the test file for `setUp`/`tearDown` usage of both reset helpers. Add a shared `setUp` at the group level to guarantee clean static state before every test.

### 3. `_projectFromEvents` with scope focus and empty matching events

`_projectFromEvents` filters events by `clientId`/`siteId` when `hasScopeFocus == true`. If the scope is set but no events match (e.g., a new site with no activity), `liveProjectedIncidents` is empty and `_activeIncidentId` is set to `null`. There is no test that pumps `LiveOperationsPage` with a non-empty `initialScopeClientId` and zero matching events to confirm the board-clear state renders without error.

**Suggested follow-up:** Add a widget test for the empty-scoped-events path.

### 4. `_loadReplayHistorySignals` failure path

`_loadReplayHistorySignals` (lines 2585–2613) has a `catch (_)` branch that restores `_rememberedReplayHistorySummary` from session memory. No test covers the failure path to confirm the fallback is applied correctly and the widget does not enter an error state.

### 5. Camera health serial guard under rapid scope changes

The `_clientLaneCameraHealthRequestSerial` guard is correct but untested. No test pumps a rapid scope change (changing `clientCommsSnapshot` while a `_loadClientLaneCameraHealth` future is still pending) to confirm the stale result is discarded.

---

## Performance / Stability Notes

### 1. Ledger list rebuilt and sorted on every `build()`

`lib/ui/live_operations_page.dart:2792`:
```dart
final ledger = [..._manualLedger, ..._projectedLedger]
  ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
```
This creates a new list and sorts it on every call to `build()`, which includes widget rebuilds triggered by unrelated state changes (e.g., tab switches, command input). `_manualLedger` grows monotonically with no cap. A long session with frequent `_appendCommandLedgerEntry` calls will produce an ever-growing list that is allocated and sorted on every rebuild.

**Suggested follow-up:** Maintain a pre-sorted `_mergedLedger` field that is updated only in `_appendCommandLedgerEntry` and `_projectFromEvents`.

### 2. `_sortedControlInboxDrafts` calls `_controlInboxDraftCueKindForSignals` twice per draft per comparison

`lib/ui/live_operations_page.dart:2215–2241`: The sort comparator calls `_controlInboxDraftCueKindForSignals` for each of `a` and `b` on every comparison. For N drafts, this is O(N log N) calls, each performing multiple string operations. For a queue with 20+ drafts, this is measurable.

**Suggested follow-up:** Pre-compute cue kinds into a map keyed by draft update ID before sorting. Codex should also check whether `_sortedControlInboxDrafts` is called on every build or only when drafts change.

### 3. `_commandCurrentFocusPanel` re-derives heavy state on every build

`_commandCurrentFocusPanel` (lines 3485–3800+) computes `typedDecision`, `typedRecommendation`, `commandBrainSnapshot`, `commandBrainLine`, `focusAccent`, `focusBackground`, and many intermediate values on every call. This method is called from both the scrollable single-column layout and the desktop workspace shell on every build. No caching layer exists.

**Suggested follow-up:** Consider whether the `typedDecision` derivation can be memoized on `_activeIncident` identity.

### 4. `_criticalAlertIncident` getter runs a linear scan on every access

`_criticalAlertIncident` (lines 7693–7701) iterates all incidents on every call. It is called multiple times per `build()` path (at lines 2854, 2938, 3984+, 10900, 16346, 16349, 16436). For small incident lists this is negligible, but the pattern should be noted as N × call sites.

**Suggested follow-up:** Compute and cache `_criticalAlertIncident` inside `_projectFromEvents` alongside `_incidents`.

---

## Recommended Fix Order

1. **Merge the duplicated `didUpdateWidget` condition block** (P2/AUTO) — zero risk, single block consolidation.
2. **Capture a single `DateTime.now()` timestamp in `_appendCommandLedgerEntry`** (P2/AUTO) — one-line fix, prevents hash/ID drift.
3. **Fix the dead-code recovery message branch in `_openClientLaneRecovery`** (P2/AUTO) — restore the distinct null-case message.
4. **Pre-sort the merged ledger in state rather than on every `build()`** (Performance) — prevents unbounded allocation on long sessions.
5. **Pre-compute cue kinds before sorting in `_sortedControlInboxDrafts`** (Performance) — eliminates redundant string evaluations during sort.
6. **Move `widget.onQueueStateHintSeen?.call()` out of `setState` closure** (P2/REVIEW) — requires checking for parent rebuild side-effects first.
7. **Audit all widget tests for static state reset calls** (Coverage/REVIEW) — check `setUp`/`tearDown` discipline.
8. **Assess and address the `build()` mutation of `_desktopWorkspaceActive`** (P1/REVIEW) — requires confirming whether any callback path reads the field before the next build.
9. **Assess static session state isolation** (P1/REVIEW) — evaluate whether the two static fields are intentional singleton design or accidental coupling; if accidental, move to instance-scoped state.
10. **Extract cue classification into a domain service** (Structural/DECISION) — enables unit testing, eliminates the two-classifier divergence risk. Requires Zaks decision on where in the domain layer this belongs.
