# Audit: lib/ui/onyx_agent_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/onyx_agent_page.dart` (11,287 lines), companion test `test/ui/onyx_agent_page_widget_test.dart` (7,967 lines)
- Read-only: yes

---

## Executive Summary

`onyx_agent_page.dart` is the largest single file in the UI layer at 11,287 lines. It is a functional, well-tested page with one confirmed rendering bug, three silent-failure catch blocks in tool action paths, two hot-path performance issues, and several structural concerns that will compound as the planner subsystem grows. The test suite (65 widget tests) is substantial but leaves key failure paths uncovered. Overall risk is **medium-high** — nothing is likely to silently corrupt production data, but the rendering bug will cause sporadic stale bridge-status UI, and the `catch (_)` patterns in action paths hide real errors from operators.

---

## What Looks Good

- **`_AgentThreadMemory.copyWith` sentinel pattern** is clean and correctly handles nullable optional fields without overloading with separate `clear*` booleans.
- **In-flight guards** (`_localBrainInFlight`, `_cloudBoostInFlight`) are applied at the call site, in the finally-block, and reflected in UI correctly (lines 5390–5431). No double-fire possible.
- **`_updateThreadById`** (lines 7483–7510) is the single write path for thread mutation → always calls `setState`, `_emitThreadSessionState`, and `_scheduleScrollToBottom`. No stray direct mutations of `_threads` outside this path.
- **Stale follow-up timer** cancels correctly in `dispose` (line 991) and re-fires are guarded by `mounted` checks throughout.
- **Test coverage of core prompt → response flow** is thorough, including cloud boost, local brain, structured recommendations, and the second-look path.

---

## Findings

### P1 — Bug: `_cameraBridgeLocalState` mutated in `didUpdateWidget` without `setState`

- Action: **AUTO**
- Finding: At lines 948–952, `_cameraBridgeLocalState` is directly assigned inside `didUpdateWidget` without a wrapping `setState` call. The presentation getter `_cameraBridgePresentation` (lines 899–907) reads from `_cameraBridgeLocalState.snapshot`, `validationInFlight`, and `resetInFlight`. Without `setState`, Flutter will not schedule a rebuild, so the camera bridge summary shell may continue showing the old snapshot until some unrelated state change triggers a rebuild.
- Why it matters: Operators relying on the bridge validation receipt banner (STALE RECEIPT / Re-Validate prompt) may see outdated status after the parent pushes a new `cameraBridgeHealthSnapshot`.
- Evidence: `lib/ui/onyx_agent_page.dart` lines 948–952; contrast with `_ingestEvidenceReturnReceipt` at lines 1294–1313 which correctly wraps in `setState` when `useSetState: true`.
- Suggested follow-up for Codex: Wrap the `_cameraBridgeLocalState = _cameraBridgeLocalState.syncSnapshot(...)` call inside `setState(() { ... })` at lines 950–952. Verify with a new widget test that pumps the widget with an initial snapshot, then calls `pumpWidget` with a new snapshot value and checks that the banner updates.

---

### P2 — Silent `catch (_)` blocks discard actionable error context in tool action paths

- Action: **REVIEW**
- Finding: Eight of nine `catch` blocks in this file use `catch (_)` and either silently reset to an empty state or display a generic user-facing message without logging. The only exception is the camera staging path at line 7103 which logs via `debugPrint`. All other paths — `_loadReplayHistorySignals` (line 978), `_refreshCameraAuditHistory` (line 2488), `_runLocalBrainSynthesis` (line 5302), `_runCloudBoost` (line 5350), `_runStructuredCloudSecondLook` (line 6045), `_runCameraChangeApproveAction` (line 7180), `_runCameraRollbackAction` (line 7227), `_runClientDraftAction` (line 7264) — all swallow the exception entirely.
- Why it matters: When camera rollback, client draft, or cloud boost fail for reasons other than network timeout (bad state, null pointer in service layer, unexpected response shape), there is no trace. Operators see a generic message, engineering sees nothing. Bugs in service implementations can go undetected across sessions.
- Evidence: Lines 978, 2488, 5302, 5350, 6045, 7180, 7227, 7264 — all `catch (_) { ... }` without `debugPrint` or `FlutterError.reportError`.
- Suggested follow-up for Codex: At minimum add `debugPrint` calls in each silent catch block matching the pattern at line 7103–7108. For the cloud/local brain paths, include the failed prompt scope in the trace.

---

### P2 — `_plannerConflictReport()` called 5–6 times per frame build

- Action: **REVIEW**
- Finding: `_plannerConflictReport()` is a pure computation method (lines 8005–8118) that iterates all threads, builds multiple derived lists, and sorts them. It is called at: line 1323 (inside `build → LayoutBuilder`), line 1389 (`_buildConversationSurface`), line 2151 (`_buildNetworkRail`), line 5187 (`_submitPrompt`), line 6030 (`_runStructuredCloudSecondLook`), and line 8547 (one more build-path call). In `build`, the first two calls are inside the same frame — `_buildThreadRail` and `_buildConversationSurface` are called from the same `LayoutBuilder` callback, so each frame computes the report at least twice.
- Why it matters: As thread count and signal counts grow, this computation scales linearly. On a busy shift with many threads and reactivated signals, double-computing the planner report per frame adds measurable jank.
- Evidence: Lines 1323, 1389, 2151 in `build` path; method definition lines 8005–8118.
- Suggested follow-up for Codex: Cache the result as a local variable at the top of `build` (or at the `LayoutBuilder` builder boundary) and pass it to all three sub-build methods. The `_submitPrompt` and `_runStructuredCloudSecondLook` call sites are already outside the frame path and are fine.

---

### P2 — `_sameJsonState` uses `jsonEncode` for deep equality on every `didUpdateWidget` call

- Action: **REVIEW**
- Finding: `_sameJsonState` (lines 10786–10790) calls `jsonEncode` on both the old and new `initialThreadSessionState` maps to check equality. This is called in `didUpdateWidget` on every parent rebuild (line 941). The session state map contains all serialized threads, messages, memory, planner snapshots, and audit maps — it can be large. A `jsonEncode` round-trip on a multi-thread session with large message histories is O(n) in map depth and string allocation.
- Why it matters: If the parent widget rebuilds frequently (e.g., during live operations polling), every rebuild triggers a full JSON serialization of the entire session state twice just for equality checking.
- Evidence: Lines 941–944, 10786–10790.
- Suggested follow-up for Codex: Consider keying the comparison on a version counter or a lightweight hash computed at emit time, rather than re-encoding the full payload on every parent rebuild. The `version: 7` field in the serialized state is already present (line 10022) — this could be complemented by a monotonic counter that increments at each `_emitThreadSessionState` call.

---

### P3 — `_runStructuredRecommendationAction` is synchronous but `executeRecommendation` is handled by an async dispatcher

- Action: **REVIEW**
- Finding: `_handleAction` is `async` and calls all other action handlers with `await`. The `executeRecommendation` branch (line 6981) calls `_runStructuredRecommendationAction(action)` synchronously and returns — there is no `await`. The method itself is `void` (line 7285), so no future is dropped. However this creates an asymmetry: if `_runStructuredRecommendationAction` ever needs to be made async in future (e.g., to await a camera confirmation), the `await` will need to be added at the call site and could be missed.
- Why it matters: Low current risk. Asymmetry with all other branches makes it a latent trap.
- Evidence: Lines 6980–6982, 7285.
- Suggested follow-up for Codex: If `_runStructuredRecommendationAction` remains synchronous, add a `// sync — no await needed` comment at the call site to prevent future regressions.

---

### P3 — `_refreshCameraAuditHistory` contains direct field mutations outside `setState` when unmounted

- Action: **AUTO**
- Finding: Lines 2463–2466 and 2491–2494 directly set `_cameraAuditLoading = false` and `_cameraAuditHistory = ...` when `!mounted`, bypassing `setState`. While this is technically safe (no Flutter rebuild attempted), it means those fields hold stale values if the widget is remounted later. The pattern is inconsistent with the rest of the state class.
- Why it matters: If the widget is removed and re-added to the tree (e.g., route pop/push pattern), the history and loading fields may start in a stale state on the next mount, until the next `initState` refresh overwrites them.
- Evidence: Lines 2463–2466, 2491–2494.
- Suggested follow-up for Codex: Remove the direct field assignments when `!mounted` and simply `return` without side-effects. `initState` will re-trigger `_refreshCameraAuditHistory` on the next mount (line 933).

---

## Duplication

### Banner container decoration repeated across 5 banner-building methods

- `_buildEvidenceReturnBanner` (line 1842), `_buildOperatorFocusBanner` (line 1889), `_buildThreadMemoryBanner` (line 1953), `_buildRestoredPressureFocusBanner` (line 2053), and the network rail `_sideCard` helper all independently construct a `Container` with `BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(...))`. Color varies but the structure is identical.
- Centralization candidate: a private `_bannerContainer({required Color bg, required Color border, required Widget child})` helper would unify the five sites and reduce future copy-paste drift when the design token changes.

### Cloud mode description strings duplicated across 3 build methods

- `_buildConversationSurface` (lines 1508–1519), `_buildNetworkRail` (lines 2179–2187), and `_responsesForPrompt` (lines 5441–5451) each contain 3–4 nested ternary expressions that produce similar "Local first / OpenAI available / locked to local" string variants.
- Centralization candidate: a single `_cloudModeDescriptionLine({bool preferCloud, bool localConfigured, bool cloudConfigured, bool cloudAvailable})` helper would eliminate the three divergent copies and prevent tone drift.

### `_miniStatusTag` widget construction pattern

- The `_miniStatusTag` helper is called with the same set of tag label/color combinations across `_buildThreadRail` (lines 1714–1737) and `_buildOperatorFocusBanner` (lines 1921–1935). The same `(label: 'OPERATOR FOCUS', foreground: Color(0xFF1D4ED8), border: Color(0xFF93C5FD))` tuple appears in both places.
- Centralization candidate: named constants or a `_OperatorFocusTagSpec` value object for the per-tag color tuples.

---

## Coverage Gaps

1. **`_refreshCameraAuditHistory` failure path** — `catch (_)` at line 2488 silently returns an empty history. No test verifies that the loading indicator clears and the rail returns to an empty-history state when `readAuditHistory` throws.

2. **Camera rollback failure path** — `_runCameraRollbackAction` has `catch (_)` at line 7227 that appends a tool message, but no widget test covers this branch (only happy-path rollback appears tested).

3. **Client draft failure path** — `_runClientDraftAction` has `catch (_)` at line 7264. No test found for the failure branch.

4. **`didUpdateWidget` camera bridge snapshot re-render** — The fix for the P1 bug will need a dedicated test: pump with initial snapshot, pump-update with new snapshot, assert banner state changes. No such test currently exists.

5. **`_staleFollowUpSurfaceTimer` race on thread switch** — Line 1278 guards against firing after a thread switch (`_selectedThreadId != targetThreadId`), but there is no test that switches threads while the timer is armed and then verifies no follow-up message appears on the new thread.

6. **`_runStructuredCloudSecondLook` failure** — catch block at line 6045 appends an error tool message, but no test covers this path.

7. **`_sameJsonState` performance regression** — No test or benchmark validates that large session states don't cause observable frame delays during `didUpdateWidget`. Not a correctness gap, but a stability regression risk.

---

## Performance / Stability Notes

1. **`_plannerConflictReport()` called 2–3× per frame** (see P2 above). As the planner signal set grows beyond ~50 entries, the sort and filter work inside this method will become measurable. Caching the result as a `build`-local variable eliminates all duplicate computation within a single frame.

2. **`jsonEncode` on full session state for equality** (see P2 above). The full thread session state is potentially hundreds of kilobytes if many threads with long message histories exist. Serializing it twice per parent rebuild is an unnecessary allocation spike.

3. **`_scheduleScrollToBottom` via `addPostFrameCallback`** (line 7512) fires on every `_updateThreadById` call. When multiple messages are appended in rapid succession (e.g., structured recommendation + cloud second look override), multiple callbacks are queued. Each independently tries to animate or jump to the bottom. A debounce or dedup guard would prevent redundant scroll operations.
   - Evidence: Lines 7509, 7512–7530.

4. **`GlobalKey` maps for planner entries** (`_plannerMaintenanceAlertKeys`, `_plannerReportSectionKeys`, `_plannerBacklogEntryKeys`, etc.) at lines 824–831. These maps are never pruned. If signal IDs are generated dynamically over a long shift, the maps will grow unbounded. Each `GlobalKey` instance holds a reference to its `BuildContext`.
   - Evidence: Lines 824–831; creation sites throughout `_buildNetworkRail`.

---

## Recommended Fix Order

1. **P1 — Add `setState` wrapper for `_cameraBridgeLocalState` in `didUpdateWidget`** — confirmed rendering bug, trivial fix, needs one new widget test.
2. **P2 — Cache `_plannerConflictReport()` result in `build`** — pure performance, safe AUTO change, no logic risk.
3. **P2 — Add `debugPrint` to all silent `catch (_)` blocks** — improves observability for production incidents, zero risk to behavior.
4. **P3 — Remove stale direct field mutations in `_refreshCameraAuditHistory` when unmounted** — minor correctness cleanup.
5. **Coverage gaps: rollback failure, client draft failure, camera audit refresh failure** — three new widget tests.
6. **Coverage gap: `didUpdateWidget` snapshot re-render test** — pair with fix #1.
7. **Performance: `GlobalKey` map pruning** — low urgency but should be addressed before signal counts grow significantly in production.
8. **Duplication: banner container helper, cloud mode string helper** — housekeeping, defer unless actively editing those methods.
