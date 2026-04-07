# Audit: events_review_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/events_review_page.dart` (7,724 lines)
- Read-only: yes

---

## Executive Summary

`EventsReviewPage` is the largest and most structurally overloaded widget in the UI layer. It does real work — the filter pipeline, scope summary computation, promotion decision dispatch, and partner trend analysis are all correct in isolation — but the file is a god object that violates every DDD boundary the application otherwise enforces. State is mutated directly inside `build()`, six domain-level summary computations run unconditionally on every frame, and three copies of an identical `SovereignReport` empty-stub factory are scattered through the class. Two confirmed state-mutation bugs in `build()` are the most urgent risk; everything else is structural debt that makes this file untestable and fragile to extend.

---

## What Looks Good

- **Filter pipeline chain is internally consistent.** The 5-stage chain (type → source → scope → provider → identityPolicy → prioritize) correctly preserves the focused event through each filter step using `_preserveFocusedEvent`. The logic is sound.
- **`_scheduleEnsureVisible` guards against repeat scheduling** correctly via `_lastAutoEnsuredEventId` (line 6676–6679).
- **`mounted` guard in `_showActionMessage`** (line 6635) prevents post-dispose setState.
- **Responsive layout** distinguishes handset, desktop, and ultrawide breakpoints cleanly via `LayoutBuilder`.
- **`_prioritizeEventsForScope`** correctly injects shadow-scope priority without mutating the original list.
- **`_partnerTrendLabel` / `_partnerTrendReason`** implement a clear severity model with a ±0.35 threshold. The logic is readable and defensible.

---

## Findings

### P1 — State mutation inside `build()`

- **Action: AUTO**
- Two state fields are mutated directly during `build()` without `setState`:
  - `_selectedEvent = selected;` — **line 375**
  - `_desktopWorkspaceActive = desktopWorkspace;` — **line 1901**
- **Why it matters:** Flutter's framework expects `build()` to be pure. Mutating state fields here bypasses the dirty-marking mechanism. In debug mode this triggers assertion failures. In profile/release mode it silently produces stale renders when the widget is rebuilt from an ancestor without re-entering these assignment paths. The `_desktopWorkspaceActive` mutation is especially risky because `_selectedEventFocusCard` reads it at line 5326, so the card's summary-only mode can lag by one frame.
- **Evidence:** `lib/ui/events_review_page.dart` lines 375, 1901.
- **Suggested follow-up for Codex:** Move `_selectedEvent` reconciliation into `didUpdateWidget` (it is already partially there at lines 205–218; the build path at 375 is a duplicate fallback that should be removed). Move `_desktopWorkspaceActive` into a `LayoutBuilder` callback that fires `setState` only when the boolean changes.

---

### P1 — God method `build()` contains the full filter pipeline and 6 domain computations

- **Action: REVIEW**
- `build()` runs 6 scope-summary computations, a 5-stage event filter chain, event list sorting, fallback scope derivation, and focus-card action closure construction before returning any widget. This is roughly 160 lines of business logic at the top of `build()` (lines 224–380).
- **Why it matters:** Any parent rebuild — even a MediaQuery change — re-executes all six domain computations unconditionally. There is no memoization. On a timeline with hundreds of events and a rich sovereign report history, this includes O(n·m) scans (see `_syntheticHistoricalLearningLabels` below). Domain logic in `build()` cannot be unit-tested without instantiating a widget tree.
- **Evidence:** `lib/ui/events_review_page.dart` lines 224–380, 103–107 (service declarations as static const).
- **Suggested follow-up for Codex:** Extract filter pipeline and summary computation into a `EventsReviewViewModel` class that can be built once and cached. Wire it as a computed property updated only when `widget.events`, `widget.sceneReviewByIntelligenceId`, or active filter state changes.

---

### P2 — Three near-identical `SovereignReport` empty-stub factories

- **Action: AUTO**
- `_syntheticHistoricalLearningLabels` (line 3517–3545), `_shadowHistoricalLabels` (line 3628–3657), and `_shadowHistoricalStrengthLabels` (line 3716–3744) each contain an identical orElse lambda that constructs an empty `SovereignReport`. All three copies are structurally identical.
- **Why it matters:** Any field added to `SovereignReport` must be updated in three places. This already caused a maintenance burden visible from the length of each stub.
- **Evidence:** Lines 3517–3545, 3628–3657, 3716–3744.
- **Suggested follow-up for Codex:** Extract a top-level `_emptySovereignReport(String date)` factory function and reference it from all three call sites.

---

### P2 — `_rowKeys` map grows unboundedly

- **Action: REVIEW**
- `_rowKeys` (line 129) is a `Map<String, GlobalKey>` that is populated by `_rowKeyForEvent` via `putIfAbsent`. It is never pruned.
- **Why it matters:** With a high-volume event stream, the map accumulates a GlobalKey per event ID for the lifetime of the widget. GlobalKeys are heavyweight Flutter objects. A session reviewing thousands of events will leak memory proportional to total event count, not visible-event count.
- **Evidence:** Lines 129, 6668–6673.
- **Suggested follow-up for Codex:** Prune entries whose event IDs are no longer present in `widget.events` inside `didUpdateWidget`. Or cap the map to the last N event IDs that match the current visible set.

---

### P2 — `_clock12` / `_fullTimestamp` display UTC but label the variable `local`

- **Action: AUTO**
- `_clock12` at line 7708 assigns `value.toUtc()` to a variable named `local`. `_fullTimestamp` (line 7718) does the same. Both functions then format and display this value.
- **Why it matters:** The variable name `local` implies local-time conversion, but the actual behaviour is UTC. Operators reading timestamps in the detail pane are shown UTC time with no timezone label, which is a display accuracy concern. Any future developer who reads the code and adds time-zone handling will start from a wrong assumption.
- **Evidence:** Lines 7707–7723.
- **Suggested follow-up for Codex:** Rename `local` to `utc` in both functions. Consider appending `' UTC'` to the rendered string, or inject a timezone preference.

---

### P2 — `_sceneReviewIdentityPolicy` classifies by fragile substring match

- **Action: REVIEW**
- Lines 7555–7572 derive identity policy by checking `decisionSummary.contains('one-time approval')`, `contains('allowlisted for this site')`, etc. These are raw substring matches on a human-readable text field.
- **Why it matters:** A rewording of any Telegram or AI-generated summary string silently breaks identity policy filtering across the full timeline. The filter at lines 331–340 (`_activeIdentityPolicyFilter`) depends entirely on this classification. Events can be silently miscategorized or excluded from a filter that an operator is actively relying on.
- **Evidence:** Lines 7555–7572, 6803–6820.
- **Suggested follow-up for Codex:** `MonitoringSceneReviewRecord` should carry a typed identity-policy enum or a stable machine-readable code rather than relying on decisionSummary string content. The substring match should be treated as a stopgap pending that domain change.

---

### P2 — Repeated O(n) report scans on every build, no memoization

- **Action: REVIEW**
- `_syntheticHistoricalLearningLabels`, `_shadowHistoricalLabels`, and `_shadowHistoricalStrengthLabels` each copy the full `morningSovereignReportHistory` list, sort it, and scan it with full per-report service calls on every invocation. All three are called during `build()` (via `_syntheticScopeSummary` and `_shadowScopeSummary`). Each may also be called from within `_tomorrowPostureDraftsForReport`, producing recursive scans.
- **Why it matters:** With even 30 sovereign reports and 200 events per report, this is tens of thousands of iterations per frame rebuild. On a desktop with many ambient widget rebuilds (scrolling, hover) this is a measurable hot-path performance regression.
- **Evidence:** Lines 3509–3566, 3621–3683, 3709–3758.
- **Suggested follow-up for Codex:** Cache results keyed by `(reportDate, morningSovereignReportHistory.length)` or lift computation into the ViewModel layer where results can be computed once per state change.

---

### P2 — Hardcoded `'REGION-GAUTENG'` in seeded fallback event

- **Action: DECISION**
- `_timelineWithFocusedFallback` at line 2533 hardcodes `regionId: 'REGION-GAUTENG'` when constructing a synthetic `_SeededDispatchEvent` for a focused event not yet present in the live timeline.
- **Why it matters:** This is a production business-domain value embedded as a string literal in a UI helper method. If the app expands beyond Gauteng or the region identifier changes, the seeded fallback silently emits the wrong region, potentially routing governance and ledger navigation to the wrong scope.
- **Evidence:** Line 2533.
- **Suggested follow-up for Codex / DECISION for Zaks:** Determine whether the fallback scope should derive the region from `_focusedFallbackScope` (which already resolves clientId and siteId) or from an injected config. The region should not be hardcoded.

---

### P3 — Hardcoded version strings in VERSION INFO card

- **Action: AUTO**
- Lines 5261–5263 display `'v2.1.0'` and `'ONYX Core'` as hardcoded string literals in the detail pane's VERSION INFO section. `'Verified'` is also hardcoded as the chain position.
- **Why it matters:** These values are never updated from the domain event, making the version card always stale. The `'Verified'` chain position is displayed unconditionally regardless of actual integrity state.
- **Evidence:** Lines 5261–5268.
- **Suggested follow-up for Codex:** Pull version from a central `AppVersion` constant. Pull chain position from the event's version field or a domain check. Remove or disable the VERSION INFO card until it can display real data.

---

## Duplication

### Six independent banner Container+Column trees

- Each of the six scope-summary banner variants (partner: line 477, readiness: line 496, tomorrow: line 619, synthetic: line 865, shadow: ~line 1400, activity: line 1584, visit: line 1736) builds an independent `Container > Column > Text... > Wrap > [actions]` tree.
- The outer shell (color, padding, borderRadius, border, bannerText Text widget, evidence refs Text, action Wrap) is structurally identical across all six.
- **Centralization candidate:** A `_ScopeBanner` widget accepting a `color`, `borderColor`, `bannerText`, `detailWidgets`, and `actions` list would eliminate the repeated Container/decoration/action-row boilerplate. Each variant would only supply its unique detail rows.

### Three identical `SovereignReport` empty-stub factories

- Already described in findings above (P2).

### `openLedgerFocus` closure duplicated in `build()` and `_reviewCommandWorkspace`

- An almost-identical closure (log action → call `widget.onOpenLedger` → fallback `_showActionMessage`) appears at lines ~1853–1869 (in `build()` header) and lines 1920–1936 (in `_reviewCommandWorkspace`).
- **Centralization candidate:** Extract `_openLedgerForEvent(DispatchEvent? selected)` method.

### `_eventSiteId`, `_eventClientId`, `_eventRegionId` are parallel if-chain dispatchers

- Lines 7662–7705: three functions with identical `if (event is X) return event.X` chain structure, covering the same 11 event types each.
- **Centralization candidate:** These should be methods or a field on `DispatchEvent` itself, not repeated dispatchers in the UI file.

---

## Coverage Gaps

- **Filter pipeline has no unit tests.** The 5-stage chain (type → source → scope → provider → identityPolicy) runs inside `build()` and cannot be exercised without a full widget tree. Extracting to a ViewModel would unlock unit tests for every filter combination.
- **`_sceneReviewIdentityPolicy` has no regression coverage.** The substring-match classification is the most fragile piece of logic in the file. A change in any matched string produces silent miscategorization. There are no tests that pin the exact strings that trigger each policy label.
- **`_partnerTrendLabel` threshold (0.35) has no unit test.** The boundary between IMPROVING, STABLE, and SLIPPING is a magic number with no test pinning its behaviour at the boundary.
- **`_tomorrowPostureDraftsForReport` recursion path is untested.** This method calls `_syntheticHistoricalLearningLabels` and `_shadowHistoricalLabels` internally. The case where those return empty lists (no historical reports) and the case where the current report is not found are not covered.
- **Fallback seeded event construction untested.** `_timelineWithFocusedFallback` creates a synthetic `_SeededDispatchEvent` when the requested eventId is missing. There are no tests for the seeded event's behaviour in the filter pipeline (does it survive all 5 filter stages? does it get selected correctly?).
- **Promotion accept/reject has no test coverage.** `_acceptSyntheticPromotion` and `_rejectSyntheticPromotion` call into `_moPromotionDecisionStore` which is a `static const` object. The round-trip (accept → rebuild → decisionStatus reflects accepted) is not covered.

---

## Performance / Stability Notes

- **Six unconditional domain computations per build frame.** `_partnerScopeSummary`, `_tomorrowPostureScopeSummary`, `_readinessScopeSummary`, `_syntheticScopeSummary`, `_shadowScopeSummary`, `_activityScopeSummary` all run on every build. Only one is displayed at a time (the `if / else if` chain at lines 477–1754). The five that are not displayed still execute, including their historical report scans.
- **`JsonEncoder.withIndent` in detail pane runs on every build.** Line 5233: `const JsonEncoder.withIndent('  ').convert(_eventPayload(selected))` converts the full event payload to a pretty-printed JSON string on every build, not only when `selected` changes. For events with large `summary` or `headline` fields this is wasted allocation.
- **`_partnerTrendSummary` iterates all reports twice** (once to build `matchingRows`, once to build `priorSeverity/accepted/onSite` lists) and is called during `build()`. No caching.

---

## Recommended Fix Order

1. **Remove state mutation from `build()`** (lines 375, 1901). This is a real bug with assertion risk in debug and stale-render risk in release. Fix is mechanical and low-risk. `AUTO`.
2. **Rename `local` → `utc` in `_clock12` / `_fullTimestamp`** and add a `' UTC'` suffix to displayed timestamps. One-line fix, prevents future misread. `AUTO`.
3. **Extract `_emptySovereignReport` factory** and collapse the three duplicate stubs. Safe, mechanical, immediately testable. `AUTO`.
4. **Deduplicate `openLedgerFocus` closure.** Extract `_openLedgerForEvent(DispatchEvent?)`. `AUTO`.
5. **Gate the six domain computations behind the `if/else if` scope-banner condition.** Only compute the summary that will actually be displayed. `REVIEW`.
6. **Cache `_rowKeys` to visible event set only.** Prune stale entries in `didUpdateWidget`. `REVIEW`.
7. **Extract filter pipeline to a ViewModel class.** Unlocks unit tests and eliminates repeated computation. Larger refactor. `REVIEW`.
8. **Pin `_sceneReviewIdentityPolicy` matching strings to domain constants.** Requires `DECISION` on whether to add a typed policy field to `MonitoringSceneReviewRecord`.
9. **Resolve `'REGION-GAUTENG'` hardcode.** `DECISION` — needs Zaks input on multi-region strategy.
10. **Fix VERSION INFO card** to use real version constant and real chain position. `AUTO` once constants are established.
