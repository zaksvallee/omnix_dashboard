# Audit: live_operations_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/live_operations_page.dart`
- Read-only: yes

---

## Executive Summary

`live_operations_page.dart` is an **18,929-line god widget** containing ~25 classes, all business logic for incident projection, ledger derivation, guard vigilance, client draft staging, command parsing routing, camera health polling, and replay history memory — plus the full render tree. The file compiles and the existing 7,371-line widget test provides meaningful coverage of happy paths. However, there are confirmed bugs (state mutation in `build`, one unguarded async path), structural architecture violations (domain logic in UI state), pervasive exception swallowing, and coverage gaps that matter for a safety-critical operations product.

---

## What Looks Good

- **Serial-number guard on async camera load** (`_clientLaneCameraHealthRequestSerial`, lines 1416–1444): correctly discards stale responses when the scope changes mid-flight.
- **Mounted-check discipline**: almost every async method checks `!mounted` before calling `setState`. The few exceptions are noted below.
- **`_projectedEventInputsChanged`** (lines 2580–2602): structural equality on event lists rather than `==` prevents unnecessary projections on list rebuilds.
- **`_openCommandClientLane` busy-key pattern** for `_clearLearnedLaneStyle` / `_setLaneVoiceProfile` (lines 1683–1742): idempotent guard prevents double-firing.
- **`_editControlInboxDraft`** controller disposal via `addPostFrameCallback` (line 16988): correct pattern to avoid disposing a controller that a dialog still holds.

---

## Findings

### P1 — State mutation inside `build()` without `setState()`

- **Action: AUTO**
- **Finding**: `_desktopWorkspaceActive` is directly assigned inside the `LayoutBuilder` callback within `build()` at line 2852:
  ```dart
  _desktopWorkspaceActive = canUseEmbeddedDesktopLayout;
  ```
- **Why it matters**: Mutating instance state during `build` is a Flutter anti-pattern. `build` can be called multiple times per frame, and mutations here run outside the `setState` lifecycle. Any method that reads `_desktopWorkspaceActive` before the next frame completes (e.g., `_showLiveOpsFeedback` at line 8020) may observe a stale value. In practice this controls whether snack bars are suppressed in favour of the desktop receipt rail — a wrong read silently drops or duplicates operator feedback on the command surface.
- **Evidence**: `live_operations_page.dart:2852`
- **Suggested follow-up**: Codex should verify whether `_desktopWorkspaceActive` can be made a computed property (derived from the same `canUseEmbeddedDesktopLayout` expression inline wherever it is read), removing the field entirely, or moved into a `didChangeDependencies`/`didUpdateWidget` callback guarded by `setState`.

---

### P1 — `_stageClientDraftCommandForPrompt` — unguarded async exception

- **Action: AUTO**
- **Finding**: `clientDraftService.draft(...)` at line 6315 is awaited without a try/catch. If the draft service throws (network error, API timeout, malformed response), the exception propagates up through `_executeCommand` (the caller at line 7096), which is also unguarded.
- **Why it matters**: An unhandled exception in `_executeCommand` crashes the async callback tied to the command prompt submit button. The user sees no feedback, the command prompt stays in a submitted-but-incomplete state, and the ledger entry is never written. On a safety-critical response dashboard this is an operator-facing silent failure.
- **Evidence**: `live_operations_page.dart:6315` (the await), `live_operations_page.dart:7096` (the call site)
- **Suggested follow-up**: Codex should wrap the `clientDraftService.draft` call in a try/catch with a `_showLiveOpsFeedback` error path, mirroring the pattern used in `_approveControlInboxDraft` (lines 16847–16863).

---

### P2 — Dead code branch in `_openCommandClientLane`

- **Action: AUTO**
- **Finding**: Lines 7325–7329 contain two branches that both resolve to calling `_openClientLaneRecovery(clientCommsSnapshot)` — one where `clientCommsSnapshot != null` and one for the `null` case — but the `null` branch also passes `clientCommsSnapshot` (which is `null` at that point). The conditional at line 7325 adds no additional behaviour: both branches call the same method with the same nullable argument.
  ```dart
  if (clientCommsSnapshot != null) {
    await _openClientLaneRecovery(clientCommsSnapshot);  // line 7326
    return;
  }
  await _openClientLaneRecovery(clientCommsSnapshot);    // line 7329 — always null here
  ```
- **Why it matters**: Dead conditional branches are misleading to maintainers and suggest the `clientCommsSnapshot != null` branch was intended to do something different (perhaps open a scoped recovery vs. a global fallback). If the distinction was intentionally removed, the branch should be collapsed. If it was accidentally lost, the null path may be doing the wrong thing.
- **Evidence**: `live_operations_page.dart:7325–7329`
- **Suggested follow-up**: Codex should confirm whether the two calls are intentionally identical and collapse them, or restore the intended split behaviour.

---

### P2 — Pervasive silent exception swallowing in four catch blocks

- **Action: REVIEW**
- **Finding**: Four `} catch (_) {` blocks at lines 2619, 16853, 17010, and 17039 silently swallow all exception types, including `TypeError`, `NoSuchMethodError`, and `PlatformException`. Only a snack message is shown. No stack trace, no error logging, no telemetry.
- **Why it matters**: The most dangerous is line 2619 inside `_loadReplayHistorySignals`. A programming error (e.g., a null dereference inside `summarizeReplayHistorySignalStack`) will be swallowed and the UI will silently fall back to the remembered replay history. Operators will not know the signal load failed vs. simply being empty. For the inbox approve/reject paths (16853, 17010, 17039) the risk is that a transient failure looks identical to a deliberate no-op.
- **Evidence**: `live_operations_page.dart:2619`, `16853`, `17010`, `17039`
- **Suggested follow-up**: Codex should at minimum add `debugPrint('$error\n$stackTrace')` to each `catch (_)` block (matching the pattern already used at line 1433–1437) before landing any further error-path work.

---

### P2 — Domain logic embedded in UI state: `_liveClientLaneCueKind`

- **Action: REVIEW**
- **Finding**: `_liveClientLaneCueKind` (lines 1986–2039) performs keyword-matching classification of client messages using 50+ lines of `contains`/`_liveClientLaneCueContainsAny` calls directly inside `_LiveOperationsPageState`. The same pattern is duplicated inside `_controlInboxDraftCueForSignals` (used in the edit dialog). This is business logic for message tone classification embedded in UI state.
- **Why it matters**: The classification cannot be unit-tested without instantiating the full widget. It is not reusable from other pages (e.g., the client comms page, which may have similar cue-display logic). It is a layer violation: `_LiveOperationsPageState` is doing work that belongs in a `ControlInboxCueClassifier` service or similar.
- **Evidence**: `live_operations_page.dart:1986–2039`, and the duplicated signals list at ~2031–2038
- **Suggested follow-up**: This is a REVIEW finding because the keyword list itself may need product input. Codex should not extract this without Zaks confirming which signals are stable enough to centralise.

---

### P2 — God widget / file: 18,929 lines

- **Action: DECISION**
- **Finding**: The file contains the full render tree for the live operations page, ~25 internal classes (data records, enums, style helpers, dialog widgets), all projection logic (`_deriveIncidents`, `_deriveLedger`, `_deriveVigilance`), all command routing (`_executeCommand` and ~15 command handler methods), camera health polling, replay history memory management, and control inbox CRUD. This is a god object in UI clothing.
- **Why it matters**: The file cannot be meaningfully code-reviewed in one pass (as demonstrated by this audit needing strategic sampling). Widget tests cannot test projection logic in isolation. Extraction to separate files would allow `_deriveIncidents`, `_canonicalFocusReference`, `_liveClientLaneCueKind`, and the command handlers to be unit-tested independently. At 18,929 lines the file is at real risk of merge conflicts and becomes a bottleneck for parallel feature work.
- **Evidence**: `live_operations_page.dart:1–18929`
- **Suggested follow-up**: This is a DECISION item. Zaks needs to decide on extraction scope and which slices are worth the migration cost (likely: projection functions first, then command handlers, then dialogs). Codex should not start extraction without a confirmed split plan.

---

## Duplication

### 1. Dual `_syncTimer` / `_syncClientLaneCameraPreviewTimer` pattern

Two independent polling timers (`_ClientLaneLiveViewDialogState._syncTimer` at lines 368–382, and `_syncClientLaneCameraPreviewTimer` at lines 1635–1652) implement the same `cancel → null → recreate periodic` pattern independently. Both guard against `!mounted` inside the tick. The inline dialog version is simpler but the two will diverge if behavior changes.

- Files: `live_operations_page.dart:368–382` and `live_operations_page.dart:1635–1652`
- Centralization candidate: a `_PollingTimer` helper (or use the existing timer pattern from elsewhere in the codebase if one exists).

### 2. Hardcoded demo fallback data in three `_derive*` methods

`_deriveIncidents` (line 17510), `_deriveLedger` (line 18113), and `_deriveVigilance` (line 18168) all have an `if (empty) return const [hardcoded_demo_data]` fallback block. Each block embeds real-looking timestamps, site names, and IDs.

- Risk: there is no runtime guard preventing demo data from appearing in a production build when an upstream event stream is temporarily empty. The fallback is gated only by `allowDemoFallback` in `_deriveIncidents`, but `_deriveLedger` and `_deriveVigilance` have unconditional fallbacks.
- Files: `live_operations_page.dart:17623–17681`, `18113–18163`, `18168–18194`
- Centralization candidate: a single `LiveOpsDemoFixtures` class, or better, a `kDebugMode` guard.

### 3. Repeated busy-set mutation pattern

The set-copy-and-add / set-copy-and-remove pattern for `_controlInboxBusyDraftIds`, `_controlInboxDraftEditBusyIds`, `_learnedStyleBusyScopeKeys`, and `_laneVoiceBusyScopeKeys` is repeated across 8+ setState calls (lines 16841, 16858, 16999, 17015, 17028, 17044, 1697, 1704, 1730, 1737). Each follows the same `{...existingSet, newKey}` / `Set.from(existingSet)..remove(key)` idiom. This is a candidate for a small generic helper or for switching to `HashSet` with direct mutation inside `setState`.

---

## Coverage Gaps

1. **`_deriveIncidents` with scope filters**: No test exercises the `hasScopeFocus` branch where events are pre-filtered by `clientId`/`siteId` before projection. A scope filter bug would silently show incidents from unrelated clients.
   - File: `live_operations_page.dart:17257–17291`

2. **`_canonicalFocusReference` resolution**: The multi-step dispatch → intelligence → decision lookup logic (lines 17347–17427) is complex and untested directly. A regression here would cause the wrong incident to be focused when an agent returns or a deep-link is followed.

3. **`_stageClientDraftCommandForPrompt` failure path**: No test covers what happens when `clientDraftService.draft` throws. Given the P1 finding above, this is an untested failure mode that could crash the async chain.

4. **`_deriveLedger` and `_deriveVigilance` demo fallback in non-demo context**: No test confirms the fallback is suppressed when a real (but empty) event stream is provided. The risk is demo data appearing to production operators after a reconnect gap.

5. **`_openCommandClientLane` null/non-null branch split**: No test distinguishes the `clientCommsSnapshot != null` and `null` paths — both currently call the same method. If the branch is later corrected to have different behaviour, there is no regression baseline.

---

## Performance / Stability Notes

1. **`_commandCenterModules` computed on every `build` rebuild** (line 3157): This method iterates `_incidents`, `_vigilance`, counts active/resolved incidents, sums module counts, and builds a 7-element list on every build. The camera preview timer fires `setState` every 5 seconds (`_clientLaneCameraPreviewRefreshInterval`), triggering a rebuild and re-running this computation. For a war room with many events this is repeated unnecessary work.
   - **Suggested follow-up**: Cache `_commandCenterModules` result alongside `_incidents` / `_vigilance` and invalidate only in `_projectFromEvents` and `didUpdateWidget`.

2. **`ledger` list rebuilt on every `build`** (line 2818–2819):
   ```dart
   final ledger = [..._manualLedger, ..._projectedLedger]
     ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
   ```
   This allocates and sorts on every rebuild. With the 5-second camera timer driving frequent rebuilds, this is a small but repeated allocation + sort in the hot path. Candidate for caching in `_projectFromEvents`.

3. **`_liveClientLaneCueKind` called for every inbox draft item in the visible list**: Each draft card computes its cue kind inline from full-string scanning (see lines 1986–2039). If the control inbox has many pending drafts and the page rebuilds frequently, this runs O(drafts) string scans per rebuild.

4. **`ScaffoldMessenger.maybeOf(context)` called inside `_showLiveOpsFeedback`** (line 8032): This traverses the widget tree upward on every operator feedback event. Low risk in isolation, but it is called from deeply nested callbacks including timer-driven paths. Worth noting if profiling reveals jank.

---

## Recommended Fix Order

1. **Fix `_stageClientDraftCommandForPrompt` missing try/catch** (P1) — prevents silent crash on AI draft failure in production.
2. **Fix `_desktopWorkspaceActive` mutation inside `build`** (P1) — prevents stale read leading to dropped/duplicated desktop receipt feedback.
3. **Add `debugPrint` to all four `catch (_)` blocks** (P2/AUTO) — minimum viable error visibility before larger structural work.
4. **Collapse the dead branch in `_openCommandClientLane`** (P2/AUTO) — low risk, clarifies intent.
5. **Add `kDebugMode` guard to `_deriveLedger` and `_deriveVigilance` demo fallbacks** (P2/REVIEW) — prevents demo data in production.
6. **Cache `_commandCenterModules` and ledger sort** (Performance/AUTO) — reduces repeated work in the 5-second camera rebuild path.
7. **Extract `_liveClientLaneCueKind` to a service** (P2/REVIEW) — requires product sign-off on signal list stability.
8. **God widget extraction** (DECISION) — requires Zaks to approve scope and sequencing.
