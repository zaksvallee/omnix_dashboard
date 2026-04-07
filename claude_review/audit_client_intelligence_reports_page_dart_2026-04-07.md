# Audit: client_intelligence_reports_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/client_intelligence_reports_page.dart`
- Read-only: yes

---

## Executive Summary

This is a structurally ambitious, feature-dense page (11,306 lines) that handles receipt
listing, PDF generation, partner scorecards, comparison ladders, drill-in dialogs, site
activity truth, branding overrides, section configuration, and clipboard exports — all
within a single `StatefulWidget`. Test coverage is extensive (75+ widget tests across the
dedicated test file plus integration tests in three other files), and the widget correctly
uses `mounted` guards and `setState` discipline in its async flows. However, the file
carries several concrete bugs and structural risks that should be addressed before this
surface hardens further.

**Risk level: Medium-High.** The two most dangerous items are the `_service` getter
(reinstantiates on every access during async operations) and the hardcoded stale
`_selectedScope`/`_startDate`/`_endDate` deterministic controls that are never wired to
the actual report generation call. Everything else is either a duplication candidate or
a coverage gap.

---

## What Looks Good

- **`mounted` guards are consistent.** Every async method that calls `setState` checks
  `!mounted` before proceeding (`_loadReceipts` line 259, `_generateReport` lines 287,
  `_openReceipt` line 307, `_showReceiptActionFeedback` line 10826).
- **`_isGenerating` / `_isRefreshing` interlocks prevent double-trigger.** All action
  buttons disable while an operation is in flight.
- **`addPostFrameCallback` for receipt consumption** (line 225) is correct — avoids
  calling back into the parent during `build`.
- **`didUpdateWidget` sync is correct.** `_shellBinding.syncFromWidget` is called before
  propagating partner scope changes.
- **`_ingestEvidenceReturnReceipt` handles both `initState` and live update** paths
  cleanly without needing duplication.
- **Test count is strong**: 75+ dedicated widget tests cover KPI filters, partner
  drill-ins, branding overrides, dock workflows, and export payloads.
- **`_desktopWorkspaceActive` flag** correctly switches between desktop command receipt
  and snackbar feedback.

---

## Findings

### P1 — `_service` getter reinstantiates `ReportGenerationService` on every access

- **Action: AUTO**
- **Finding:** `_service` is declared as a computed getter (lines 149–153) that calls
  `ReportGenerationService(store: widget.store, sceneReviewByIntelligenceId: ...)` on
  every access. Within `_loadReceipts`, `_generateReport`, and `_openReceipt`, it is
  called multiple times per async sequence (e.g., `_service.verifyReportHash` then
  `_service.summarizeSceneReviewForReceipt` on lines 250, 255; `_service.generatePdfReport`
  then `_service.verifyReportHash` on lines 274–284). Each call constructs a new
  `ReportGenerationService` instance.
- **Why it matters:** If `ReportGenerationService` holds any internal cache or memoised
  projection state, those results are discarded between calls in the same logical
  operation. Even if it is currently stateless, this is a fragile pattern — a future
  change to add service-level caching would silently fail. It also allocates unnecessary
  objects on hot async paths.
- **Evidence:** Lines 149–153, 250, 255, 275–284, 305–306.
- **Suggested follow-up for Codex:** Convert `_service` from a getter to a `late final`
  field initialised in `initState` (or inside `didUpdateWidget` if `store` or
  `sceneReviewByIntelligenceId` can change across remounts).

---

### P1 — `_buildDeterministicControls` state (`_selectedScope`, `_startDate`, `_endDate`) is dead UI

- **Action: REVIEW**
- **Finding:** Three state fields (`_selectedScope`, `_startDate`, `_endDate`) are
  declared at lines 143–145 and mutated by `_buildDeterministicControls` UI (lines
  7881–7980). However, **none of these fields is passed into the `generatePdfReport` call
  at line 275–281** — the generation call only passes `clientId`, `siteId`, `nowUtc`,
  `brandingConfiguration`, `sectionConfiguration`, and `investigationContextKey`.
  `_selectedScope` maps to a hardcoded list of estate names (lines 7882–7887) that do not
  correspond to `widget.selectedClient`/`widget.selectedSite`. `_startDate` and
  `_endDate` are date-pickers that never feed into generation scope.
- **Why it matters:** The "Client / Site" dropdown, "Start Date", and "End Date" pickers
  shown to operators appear to control generation scope but have no effect. This is a
  silent UX bug: an operator changing these controls before generating a report will
  receive a report for the injected `widget.selectedClient`/`widget.selectedSite`, not the
  UI-selected scope.
- **Evidence:** Lines 143–145 (declarations), 7881–7929 (UI writing to these fields),
  275–281 (generation ignoring them).
- **Suggested follow-up for Codex:** Either (a) wire these fields into the generation
  call so they control output, or (b) remove the deterministic controls UI if scope
  selection is already handled by the parent. A product decision is needed: do operators
  need ad-hoc scope overrides from within Reports, or should scope always be inherited
  from the parent?

---

### P2 — `_siteActivitySnapshot` calls `widget.store.allEvents()` inside every `_partnerScorecardLaneRow` rebuild

- **Action: REVIEW**
- **Finding:** `_siteActivitySnapshot` at line 10211 calls `widget.store.allEvents()` and
  passes the full event list to `_siteActivityService.buildSnapshot(...)`. This is called
  from `_partnerScorecardLaneRow` (line 6469), which is called in a loop for every row
  (lines 2917–2919). It is also called from `_partnerComparisonRow` (line 5668) and from
  `_partnerComparisonCard` and `_partnerScorecardLanesCard` at each `build` pass. Under
  a layout with several partner lanes, `allEvents()` is traversed N × lanes times per
  frame.
- **Why it matters:** If the store contains thousands of events (a realistic production
  size after weeks of operation), each full scan is O(n) and the total cost per frame is
  O(n × lanes). The `build` method triggers on `setState`, which is called on every
  receipt action, filter toggle, and feedback message.
- **Evidence:** Lines 6469, 5668, 3098–3101, 2846–2849, 10127, 10211.
- **Suggested follow-up for Codex:** Pre-compute site activity snapshots in
  `_loadReceipts` or in `didUpdateWidget` and cache results keyed by `clientId/siteId`.
  Pass cached values into the card builders rather than re-deriving inside `build`.

---

### P2 — `_openGovernanceScopeAction` is called 18 times inline across build methods

- **Action: AUTO**
- **Finding:** `_openGovernanceScopeAction(clientId: widget.selectedClient, siteId: widget.selectedSite)`
  is called 18 times across build paths (confirmed by grep), always with the same two
  constant arguments. Each call creates a new closure or returns null. While the
  allocation cost is small, the pattern means the same null-check logic is duplicated
  across every widget method and makes refactoring this callback fragile.
- **Why it matters:** Any change to the governance routing logic must be applied in 18+
  places. The current pattern also makes it non-obvious which surface owns the canonical
  governance action state.
- **Evidence:** Lines 154–167 (definition), confirmed 18 call sites by grep.
- **Suggested follow-up for Codex:** Cache as `late final _governanceScopeAction` in
  `initState`, updated in `didUpdateWidget` only when `widget.selectedClient` or
  `widget.selectedSite` changes.

---

### P2 — `_generateReport` calls `_loadReceipts()` then does not await `setState(() => _isGenerating = false)`

- **Action: REVIEW**
- **Finding:** In `_generateReport` (lines 272–300), the sequence is:
  1. `setState(() => _isGenerating = true)` (line 274)
  2. `await _service.generatePdfReport(...)` (line 275)
  3. `await _service.verifyReportHash(...)` (line 283)
  4. `await _loadReceipts()` (line 285) — which internally calls `setState`
  5. `if (!mounted) return` (line 287)
  6. `focusReportReceiptWorkspace(...)` (line 289)
  7. `setState(() => _isGenerating = false)` (line 291) — **AFTER** `presentReportPreviewRequest`

  `setState(() => _isGenerating = false)` (line 291) is placed before
  `presentReportPreviewRequest` on line 292, but `presentReportPreviewRequest` may itself
  trigger additional `setState` calls within the mixin. This creates an ordering dependency
  on the mixin's implementation remaining stateless during the preview request.
  More concretely: if `_loadReceipts` sets `_isRefreshing = false` in its own internal
  `setState`, and subsequently `!mounted` is true, `_generateReport` returns at line 287
  but `_isGenerating` is **never reset to false**, leaving the button disabled
  permanently for this widget's lifetime.
- **Why it matters:** If the widget unmounts during `_loadReceipts` (e.g., the user
  navigates away mid-generate), `_isGenerating` remains true. If the parent re-mounts
  this widget (same client/site route), the generate button is rendered disabled
  immediately on first appearance with no indication of the cause.
- **Evidence:** Lines 274–300.
- **Suggested follow-up for Codex:** Move `setState(() => _isGenerating = false)` into a
  `finally` block, or use a `try/finally` to guarantee the flag is cleared regardless of
  the `!mounted` early return.

---

### P2 — Five near-identical "recovery card" widgets built inline

- **Action: AUTO**
- **Finding:** Five methods render structurally identical "empty state recovery" cards
  with title text, body text, and action buttons wrapped in a styled Container:
  - `_siteActivityQuietScopeRecoveryCard` (line 3912)
  - `_partnerScopePendingRecoveryCard` (line 3994)
  - `_partnerShiftEmptyReceiptsRecoveryCard` (line 4847)
  - `_partnerShiftEmptyChainsRecoveryCard` (line 4938)
  - `_partnerComparisonRecoveryCard` (approx. line 6100)

  All five share identical `BoxDecoration` (same colors, border radius, shadow), the same
  Column structure (title → body → Wrap buttons), and the same button widget
  (`_actionButton`). Only the strings and available actions differ.
- **Why it matters:** Any visual change (border radius, padding, shadow) requires five
  separate edits. The pattern also increases page size without adding capability.
- **Evidence:** Lines 3912–3991, 3994–4060, 4847–4936, 4938–5027, ~6100–6268.
- **Suggested follow-up for Codex:** Extract a shared `_ReportsRecoveryCard` widget or
  helper that accepts title, detail, and an actions builder. All five call sites can be
  reduced to configuration parameters.

---

### P3 — `_partnerScopeHistoryPointsFor` sorts `widget.morningSovereignReportHistory` on every call

- **Action: AUTO**
- **Finding:** `_partnerDispatchChainsForScope` (line 7049) and indirectly
  `_partnerScopeHistoryPointsFor` both call `[...widget.morningSovereignReportHistory]..sort(...)`
  on each invocation. This list is scanned per partner lane in `_partnerScorecardLaneRow`
  for every row rendered.
- **Why it matters:** Suspicion level — this is only costly if `morningSovereignReportHistory`
  is large (many days of history). But the sort-on-every-call pattern is a fragile
  default; it should be cached in `didUpdateWidget` when the list reference changes.
- **Evidence:** Lines 7054–7060.
- **Suggested follow-up for Codex:** Cache a sorted copy of `morningSovereignReportHistory`
  as `late List<SovereignReport> _sortedHistory` in `initState`, refreshed in
  `didUpdateWidget` when the list reference changes.

---

### P3 — `_partnerScoreboardMatchesFocus` delegates to `_partnerScoreboardMatchesScope` which delegates again

- **Action: AUTO**
- **Finding:** `_partnerScoreboardMatchesFocus` (line 7144) simply calls
  `_partnerScoreboardMatchesScope`, which calls `_partnerScoreboardMatchesScopeValues`.
  This two-level delegation adds no behaviour — it is indirection without intent.
- **Why it matters:** Minor maintainability issue. Calling code cannot distinguish between
  "focus" and "scope" semantics from the name alone if they are identical.
- **Evidence:** Lines 7144–7146.
- **Suggested follow-up for Codex:** Inline `_partnerScoreboardMatchesFocus` into
  `_partnerScoreboardMatchesScope` and remove the redundant alias.

---

## Duplication

### 1. `_openGovernanceScopeAction` repeated 18 times in build paths

- Files: same file, build methods throughout
- Centralization candidate: a single cached `VoidCallback?` field

### 2. Five near-identical recovery card structures

- Files: same file, lines 3912, 3994, 4847, 4938, ~6100
- Centralization candidate: `_ReportsRecoveryCard` extracted widget

### 3. `'OPEN GOVERNANCE DESK'` / `'OPEN ACTIVITY TRUTH DESK'` action buttons repeated across multiple card builders

- Every command banner and card independently constructs the same labelled `_actionButton`
  call with the same icons and the same label strings. A minor duplication candidate; lower
  priority than the recovery card consolidation.

### 4. Investigation comparison chip blocks (`Current Governance`, `Current Routine`, `Baseline Governance`, `Baseline Routine`)

- This 4-chip `Wrap` block appears identically in `_partnerComparisonCard` (lines 3237–3268)
  and `_partnerScopeCard` (lines 2636–2669). Should be extracted into a shared method
  `_receiptInvestigationComparisonChips(_ReceiptInvestigationComparison comparison)`.

---

## Coverage Gaps

### 1. `_generateReport` unmount during `_loadReceipts` — `_isGenerating` stuck true

- No test exercises the case where the widget unmounts while `_loadReceipts` runs inside
  `_generateReport`. The `!mounted` guard at line 287 returns without clearing
  `_isGenerating`. Untested.

### 2. `_buildDeterministicControls` scope controls have no effect on generation

- No test asserts that changing `_selectedScope` or dates before pressing Generate affects
  the generation call. This means the dead-UI bug (P1 above) is also undetected by the
  test suite.

### 3. `_openReceipt` — no test for the case where `regenerateFromReceipt` throws

- `_openReceipt` awaits two async calls without error handling. No test simulates a
  failure from `regenerateFromReceipt`.

### 4. `_ingestEvidenceReturnReceipt` + `addPostFrameCallback` ordering

- The `onConsumeEvidenceReturnReceipt` callback is invoked inside a `postFrameCallback`.
  If the widget unmounts between ingestion and the next frame, the callback is still fired.
  No test exercises this path.

### 5. KPI band `OUTPUT MODE` card — no test for filter/sort interplay

- The OUTPUT MODE KPI card has no `isActive`/`onTap` (lines 2471–2477) so it cannot
  trigger a filter. This is intentional but there is no test confirming that tapping the
  card does nothing (no accidental future regression if `onTap` is added).

---

## Performance / Stability Notes

### 1. `allEvents()` scanned per-lane per-frame inside `_siteActivitySnapshot`

- Confirmed in `_siteActivityHistoryPointsFor` (line 10127) and `_siteActivitySnapshot`
  (line 10211). Called inside `_partnerScorecardLaneRow` loop. Under large event stores
  and multiple partner lanes, this will be measurably slow.
- Concrete risk — not a suspicion.

### 2. `_service` getter allocates a new `ReportGenerationService` on every access

- See P1 above. At minimum, three allocations per `_loadReceipts` call per receipt.
  On large receipt lists this is quadratic allocation.

### 3. `build` method materialises 12+ KPI card widgets per frame unconditionally

- `_kpiBand` creates 12 `_kpiCard` widgets on every `build`. These include closures
  captured over `_receiptFilter` and filter-toggle lambdas. In the desktop layout,
  `build` is called on every receipt action, filter toggle, and feedback update. This is
  a moderate rebuild surface — not critical unless frame budgets are tight, but worth
  noting for profiling.

### 4. `_receiptHistoryMetrics` is recomputed in `build` every frame

- `_receiptHistoryMetrics(reportRows)` (line 324) is called unconditionally in `build`
  and feeds the supplemental deck. If this function involves O(n) passes over `_receipts`,
  it is recomputed on every `setState`, including low-signal ones like `_showReceiptActionFeedback`.
  Suspicion — actual cost depends on `_receiptHistoryMetrics` implementation.

---

## Recommended Fix Order

1. **Fix `_generateReport` `_isGenerating` stuck-true bug** (P1 / try-finally) — prevents
   silent operator block; `AUTO`, low risk.
2. **Convert `_service` getter to `late final` field** (P1) — removes repeated allocation
   and guards against future cache invalidation bugs; `AUTO`.
3. **Wire or remove `_buildDeterministicControls` state** (P1 dead UI) — requires product
   decision on scope override semantics; `DECISION`, then `REVIEW` implementation.
4. **Cache `_openGovernanceScopeAction` as a field** (P2) — safe mechanical refactor;
   `AUTO`.
5. **Pre-compute site activity snapshots out of `build`** (P2 perf) — `REVIEW`, needs
   care around `didUpdateWidget` timing.
6. **Extract `_ReportsRecoveryCard` from five duplicate recovery card methods** (P2
   duplication) — `AUTO`, no behaviour change.
7. **Extract `_receiptInvestigationComparisonChips`** (P3 duplication) — `AUTO`.
8. **Add test: unmount-during-generate leaves `_isGenerating` false** — `AUTO` after
   fix #1 lands.
9. **Add test: deterministic controls do not silently suppress generation scope** — `AUTO`
   after fix #3 is resolved.
10. **Inline `_partnerScoreboardMatchesFocus`** (P3) — `AUTO`, trivial.
