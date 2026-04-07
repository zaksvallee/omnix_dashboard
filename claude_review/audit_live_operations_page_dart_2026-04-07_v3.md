# Audit: live_operations_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: lib/ui/live_operations_page.dart (full file, 18 933 lines)
- Read-only: yes

---

## Executive Summary

`live_operations_page.dart` is the most complex file in the codebase. At 18 933 lines it is a textbook god widget: domain event projection, cue classification, camera health polling, command-brain routing, ledger management, replay history memory, and full UI are all co-located in a single `State` class. The core architecture works and the detail is impressive, but the file carries several concrete bug risks, widespread duplication, and zero test coverage on any of its projection or classification logic. Two findings (nested `setState` and static mutable session state) can produce real runtime errors today.

---

## What Looks Good

- Lifecycle hygiene is solid: every `Timer` is cancelled in `dispose`, every `await` path checks `!mounted` before calling `setState`, and request serials (`_clientLaneCameraHealthRequestSerial`) guard against stale async results.
- `_projectFromEvents` is deterministic and produces no observable side effects on the event list — safe to call repeatedly.
- The `didUpdateWidget` guard (`_projectedEventInputsChanged`) avoids spurious re-projections on reference-equal lists.
- `_controlInboxDraftCueKindForSignals` covers a broad set of keyword signals without any external dependencies, making it easy to unit test in isolation once extracted.
- `ValueKey` coverage on interactive widgets is thorough and consistent.

---

## Findings

### P1 — Nested `setState` inside `setState` callback

- **Action:** AUTO
- **Finding:** `_applyOverride` (line 17180) and `_forceDispatch` (line 17210) both call `_projectFromEvents()` inside a `setState` lambda. `_projectFromEvents()` calls `setState()` itself (line 17315). Calling `setState` inside an active `setState` callback is a Flutter lifecycle violation that produces `setState() or markNeedsBuild() called during build` exceptions in debug builds and unpredictable behavior in release.
- **Evidence:** `live_operations_page.dart:17181–17194` (setState → _projectFromEvents → setState) and `17205–17215` (same pattern).
- **Suggested follow-up for Codex:** Extract the mutation from the `setState` lambda and call `_projectFromEvents()` after the `setState` closes, or fold the override state changes directly into `_projectFromEvents` so the single outer `setState` covers both.

---

### P1 — Static mutable session state on `State` class

- **Action:** REVIEW
- **Finding:** `_queueStateHintSeenThisSession` (line 1287) and `_replayHistoryMemoryByScopeThisSession` (line 1288–1290) are `static` mutable fields on `_LiveOperationsPageState`. Static fields on a `State` class are shared across all concurrent widget instances and survive widget tree teardown. If two `LiveOperationsPage` instances ever exist in the tree (e.g. navigator push/pop overlap, tab navigation), they will silently corrupt each other's session memory. The `debugReset*` static methods confirm this is a known concern, but the risk is not guarded at the instance level.
- **Evidence:** `live_operations_page.dart:1287–1290`.
- **Suggested follow-up for Codex:** Validate whether the app ever mounts two `LiveOperationsPage` instances simultaneously. If yes, move session memory to a scoped InheritedWidget, a provider, or the parent page state. If no, add a `DevTools` assertion documenting the constraint.

---

### P2 — Duplicate event scope filter

- **Action:** AUTO
- **Finding:** The switch/case filter that resolves `clientId` and `siteId` from every known event type is copy-pasted verbatim in two places: `_projectFromEvents` (lines 17261–17295) and `_eventsInCommandScope` (lines 6836–6878). Both iterate `widget.events`, match the same event types, and apply the same `clientId == scopeClientId` predicate. Any new event type added to one path must be manually added to the other or the behavior diverges.
- **Evidence:** `live_operations_page.dart:6836–6878` vs `17261–17295`.
- **Suggested follow-up for Codex:** Extract a private `_scopedEvents({bool includeAllSitesForClient = false})` method and replace both call sites.

---

### P2 — Duplicate cue message strings across two separate cue pipelines

- **Action:** AUTO
- **Finding:** `_liveClientLaneCueMessage(_ControlInboxDraftCueKind)` (lines 2044–2062) and `_controlInboxDraftCueMessage(_ControlInboxDraftCueKind)` (lines 2140–2158) return identical string literals for every `_ControlInboxDraftCueKind` value. Two separate functions, two separate maintenance surfaces, always identical output. Any copy-edit to one will silently drift from the other.
- **Evidence:** Compare `live_operations_page.dart:2044–2062` with `2140–2158` — every `case` branch is byte-for-byte identical.
- **Suggested follow-up for Codex:** Delete one function and replace all call sites with the surviving version. Both call sites already use `_ControlInboxDraftCueKind`, so no signature change is required.

---

### P2 — `_sortedControlInboxDrafts` re-executed multiple times per build, O(n log n × cue cost) per call

- **Action:** REVIEW
- **Finding:** `_sortedControlInboxDrafts` creates a new sorted list on every call. Its comparator calls `_controlInboxDraftCueKindForSignals` twice per comparison — the cue function does multiple `String.contains` scans on concatenated signal strings. In `build()`, the sorted list is independently requested by `_visibleControlInboxDraftCount`, `_controlInboxPriorityDraftCount`, `_controlInboxHasSensitivePriorityDraft`, `_controlInboxCueSummaryItems`, and the inbox panel builder — all from the same `controlInboxSnapshot` reference. For large queues this is avoidable repeated work.
- **Evidence:** `live_operations_page.dart:2229–2261` (sort with per-comparison cue calls), callers at lines 2414, 2450, 8058, 8072, and multiple build-method references.
- **Suggested follow-up for Codex:** Compute and cache the sorted+cue-annotated list once per `build` call, then pass it down to all consumers in the same frame.

---

### P2 — `_desktopWorkspaceActive` mutated as a field inside `LayoutBuilder` callback during `build`

- **Action:** REVIEW
- **Finding:** Line 2852 assigns `_desktopWorkspaceActive = canUseEmbeddedDesktopLayout;` directly inside the `LayoutBuilder` builder — not inside a `setState`. This is a side effect during a build frame. Flutter does not prevent this from running, but it can lead to inconsistency if other code reads `_desktopWorkspaceActive` before the `LayoutBuilder` callback fires in the same frame (e.g. in `_showLiveOpsFeedback` called synchronously from a button). It also makes testing and reasoning about the field harder since it is not controlled by the normal setState lifecycle.
- **Evidence:** `live_operations_page.dart:2852`.
- **Suggested follow-up for Codex:** Convert to a computed getter `bool get _desktopWorkspaceActive => ...` that reads from `_showDetailedWorkspace` and layout constraints, or drive the value with a `LayoutBuilder` callback that calls `WidgetsBinding.addPostFrameCallback` to set via `setState` when the value changes.

---

### P2 — `_appendCommandLedgerEntry` captures two separate `DateTime.now()` calls for id and hash

- **Action:** AUTO
- **Finding:** The ledger entry constructed in `_appendCommandLedgerEntry` uses `DateTime.now().microsecondsSinceEpoch` for its `id` (line 7971) and a separate `DateTime.now().microsecondsSinceEpoch` for its `hash` (line 7977). The two timestamps can differ by microseconds, meaning the id encoded in a log will not match the timestamp encoded in the hash. This is a minor forensic integrity gap on the Sovereign Ledger.
- **Evidence:** `live_operations_page.dart:7971` and `7977`.
- **Suggested follow-up for Codex:** Capture `final now = DateTime.now()` once at the top of the method and use `now.microsecondsSinceEpoch` for both fields.

---

### P2 — `_openClientLaneAction` called twice for the same scope in `_clientLaneWatchPanel`

- **Action:** AUTO
- **Finding:** In `_clientLaneWatchPanel` (around line 9096), `_openClientLaneAction(clientId: snapshot.clientId, siteId: snapshot.siteId)` is called once in an `if () != null` guard and a second time to supply the actual `onPressed` value. Both calls recreate the same closure object. This is harmless but wasteful; if the method ever becomes non-trivial it will silently double-execute.
- **Evidence:** `live_operations_page.dart:9096–9103`.
- **Suggested follow-up for Codex:** Capture the result once: `final action = _openClientLaneAction(...)` and use `action` for both the guard and `onPressed`.

---

### P2 — Seeded fallback incident timestamp calls `DateTime.now()` inside `_projectFromEvents`

- **Action:** REVIEW
- **Finding:** `_injectFocusedIncidentFallback` (line 17497) stamps the synthetic fallback incident with `_hhmm(DateTime.now().toLocal())`. `_projectFromEvents` is called from `didUpdateWidget` on every widget rebuild that changes events, scope, or focus reference. On frequent parent rebuilds, the seeded incident timestamp will flicker visibly even when nothing about the real incident changed.
- **Evidence:** `live_operations_page.dart:17479–17501`.
- **Suggested follow-up for Codex:** Either fix the timestamp to the time the focus reference was first observed (store it alongside `_resolvedFocusReference`), or use a stable placeholder string like `'--:--'` for seeded incidents.

---

### P3 — `_controlInboxTopBarQueueState*` methods repeat the same three-branch if/switch cascade six times

- **Action:** AUTO
- **Finding:** Six private methods — `_controlInboxTopBarQueueStateLabel`, `_controlInboxTopBarQueueStateForeground`, `_controlInboxTopBarQueueStateBackground`, `_controlInboxTopBarQueueStateBorder`, `_controlInboxTopBarQueueStateIcon`, `_controlInboxQueueStateTooltip` — each independently re-evaluate `_controlInboxCueOnlyKind != null` → `_controlInboxPriorityOnly` → default. All six share the same branching skeleton.
- **Evidence:** `live_operations_page.dart:2289–2369`.
- **Suggested follow-up for Codex:** Consolidate into a single `_controlInboxTopBarQueueState(bool hasSensitivePriorityDraft)` method that returns a value object or record holding all six values, and compute it once per build.

---

### P3 — `_clientCommsOpsFootnote(snapshot)` called twice in `_clientLaneWatchPanel`

- **Action:** AUTO
- **Finding:** `_clientCommsOpsFootnote(snapshot)` is called once in the conditional guard `if (_clientCommsOpsFootnote(snapshot).isNotEmpty)` and again inside the `Text` widget body (lines 9370–9380). If the function is ever non-trivial, this doubles its execution cost. It also makes the build subtly fragile if the method has observable side effects.
- **Evidence:** `live_operations_page.dart:9370–9380`.
- **Suggested follow-up for Codex:** Capture once as `final footnote = _clientCommsOpsFootnote(snapshot)` and use the local in both places.

---

## Duplication

| Duplicated block | Files / lines | Centralization candidate |
|---|---|---|
| Event clientId/siteId scope filter (switch/case over all event types) | Lines 6836–6878 and 17261–17295 | `_scopedEvents({bool includeAllSitesForClient})` private method |
| `_liveClientLaneCueMessage` vs `_controlInboxDraftCueMessage` (identical switch outputs) | Lines 2044–2062 and 2140–2158 | Single `_cueKindMessage(_ControlInboxDraftCueKind)` |
| Queue-state top-bar presentation logic (6 × three-branch cascade) | Lines 2289–2369 | `_QueueTopBarState` value record computed once per build |
| `_openClientLaneAction` double-call per watch panel render | Lines 9096–9103 | Local `final action = _openClientLaneAction(...)` |

---

## Coverage Gaps

- **`_deriveIncidents` / `_deriveLedger` / `_deriveVigilance` / `_canonicalFocusReference`** — zero unit tests. These are the core business logic of the page (event → incident projection). A wrong `closedIds` / `arrivedIds` / `executedIds` set produces incorrect incident status shown to operators. Coverage here is the highest ROI test target in this file.
- **`_controlInboxDraftCueKindForSignals`** — zero tests. This drives draft priority order and inbox badge counts visible to every controller. The keyword lists (lines 2079–2135) have no regression lock.
- **`_liveOpsReplayHistoryMemoryScopeKey`** — no tests for edge cases (empty clientId with non-empty siteId, unicode in ids, etc.).
- **`_injectFocusedIncidentFallback`** — no test verifying the seeded incident appears at index 0 when there is no live match.
- **`_incidentPriorityFor` posture escalation** — fire/smoke/flood/hazard branches have no test coverage. A typo in the posture keyword strings would silently downgrade an emergency incident's priority.
- **Static session state reset paths** — `debugResetQueueStateHintSession` and `debugResetReplayHistoryMemorySession` exist but there are no tests that verify multi-instance isolation.

---

## Performance / Stability Notes

- **`_sortedControlInboxDrafts` + cue classification called N × per build frame.** For a queue of 20 drafts, every build calls the sort + cue pipeline at least 4 independent times. For a queue of 100, this becomes measurable. Memoize at the build scope.
- **`_clientLaneCameraPreviewTimer` fires every 5 s regardless of widget visibility.** The timer guard `if (!mounted || _clientLaneCameraHealthLoading)` is correct for lifecycle safety but does not suppress polling when the page is pushed behind another route. Consider pausing the timer using `WidgetsBindingObserver` / `AppLifecycleState` or Route-aware activation.
- **The `build()` method re-creates `ledger` by spreading two lists and sorting on every build** (`[..._manualLedger, ..._projectedLedger]..sort(...)` at line 2818). This is O((m+n) log(m+n)) per frame. Both source lists are small in practice, but the allocation + sort happens even when neither list changed.
- **`_commandCenterHero` calls `_commandCenterModules` which iterates `_incidents` and calls `_visibleControlInboxDraftCount` (which iterates drafts) synchronously inside `LayoutBuilder`.** For the wide-screen desktop layout this happens twice per frame (once for the rail compact hero, once implicitly via the scroll path). Not yet a problem at current data sizes but will degrade as incident lists grow.

---

## Recommended Fix Order

1. **(P1)** Fix nested `setState` in `_applyOverride` and `_forceDispatch` — this is a confirmed Flutter lifecycle violation that will assert in debug builds.
2. **(P1)** Audit and document (or eliminate) static session state — at minimum add a runtime assert that only one instance is active at a time.
3. **(P2)** Extract the shared event scope filter to remove the maintenance split between `_eventsInCommandScope` and `_projectFromEvents`.
4. **(P2)** Delete the duplicate `_liveClientLaneCueMessage` / `_controlInboxDraftCueMessage` and unify at one call site.
5. **(P2)** Fix the double `DateTime.now()` in `_appendCommandLedgerEntry` to anchor id and hash to the same instant.
6. **(P2)** Add unit tests for `_deriveIncidents`, `_controlInboxDraftCueKindForSignals`, and `_incidentPriorityFor` posture escalation — these are pure functions that can be tested without a Flutter context.
7. **(P3)** Memoize the sorted+cue-annotated draft list at the build scope to eliminate repeated sort passes.
8. **(P3)** Consolidate the six `_controlInboxTopBarQueueState*` methods into a single record computation.
