# Audit: client_intelligence_reports_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/client_intelligence_reports_page.dart`
- Read-only: yes

---

## Executive Summary

This is the largest UI file in the project (~11 100 lines). It is a single `StatefulWidget` state class that doubles as a business-logic coordinator, a data-shaping layer, a UI composition surface, and an ad-hoc analytics engine. The file is structurally ambitious and largely coherent, but it has crossed the god-object threshold. A dozen computed getters (e.g. `_sitePartnerComparisonRows`, `_partnerScopeHistoryPointsFor`) are called multiple times during every `build` cycle, each re-sorting the full sovereign report history. There are two concrete async lifecycle bugs: one where `_isGenerating` can be left permanently `true` on exception, and one where `_loadReceipts` issues `verifyReportHash` serially per event even for large receipt lists. Several pieces of business logic (trend scoring, branding severity, investigation comparison) are stateless pure functions but live inside state — they are untested and invisible to the test layer. The hardcoded `'Sandton Estate North'` / `_startDate` / `_endDate` demo defaults are still live and are not gated behind a flag.

Overall quality: **above average for complexity, risky in async safety and performance.**

---

## What Looks Good

- `didUpdateWidget` is thorough: it correctly re-creates `_service` when `store` or `sceneReviewByIntelligenceId` change, and correctly syncs `_shellBinding` through the mixin.
- `_ingestEvidenceReturnReceipt` correctly defers the consume callback via `addPostFrameCallback` with a `mounted` guard.
- `_openGovernanceScopeAction` normalizes and validates `clientId`/`siteId` before building the callback, preventing empty-scope navigation.
- All modal dialogs (`_openPartnerDrillIn`, `_openSiteActivityTruth`, `_openPartnerShiftDetail`) are `async`/`await` with `!mounted` guards before any post-await `setState`.
- `_partnerScoreboardMatchesScopeValues` normalises `.trim().toUpperCase()` for `partnerLabel` comparisons — avoids silent case-drift mismatches.
- `_receiptHistoryRecoveryFilters` ranks alternatives by count and order, giving operators the most useful fallback filter first.
- Key ValueKeys are assigned throughout: enables reliable widget testing.

---

## Findings

### P1 — Bug: `_isGenerating` is never reset on exception

- **Action:** AUTO
- **Finding:** `_generateReport()` (line 358) sets `_isGenerating = true` before the first `await`. If `_service.generatePdfReport`, `_service.verifyReportHash`, or `_loadReceipts` throws, control returns without ever calling `setState(() => _isGenerating = false)`. The Generate button is permanently disabled for the remainder of the widget's lifetime.
- **Why it matters:** In production, PDF generation can fail (Supabase timeout, hash mismatch, null guard in generation service). Once stuck, the user cannot generate any report without navigating away and back.
- **Evidence:** `lib/ui/client_intelligence_reports_page.dart` lines 358–388. No `try/finally` or `catch` wraps the async body. The only `setState(() => _isGenerating = false)` is at line 376, which is only reached on the happy path.
- **Suggested follow-up for Codex:** Wrap the `_generateReport` async body in a `try/finally` that resets `_isGenerating` and shows a `_showReceiptActionFeedback` error message.

---

### P1 — Bug: `_loadReceipts` calls `verifyReportHash` serially inside a for-loop

- **Action:** REVIEW
- **Finding:** `_loadReceipts` (lines 319–356) iterates over every `ReportGenerated` event and `await`s `_service.verifyReportHash(event)` per event, one at a time. This is O(n) sequential async calls. For a site with 50 receipts, 50 sequential hash checks block the UI state update for the full cumulative I/O duration.
- **Why it matters:** Hash verification likely reads from the event store or local storage. 50 sequential awaits means the `_isRefreshing` spinner sits on screen for the full serial chain. There is also a race: if `_loadReceipts` is called a second time while the first is still mid-loop (e.g. via the "Refresh Replay Verification" button, line 2244), two overlapping loops write to the same `rows` list before the `!mounted` guard is checked.
- **Evidence:** Lines 334–343. No `Future.wait` or concurrency limit is used. `_loadReceipts` is called from `initState` (line 185) and from `_generateReport` (line 371).
- **Suggested follow-up for Codex:** Replace serial loop with `Future.wait(reportEvents.map((event) => _service.verifyReportHash(event)))`, then zip results. Also add a `_loadInProgress` guard to prevent concurrent calls.

---

### P1 — Bug: `_desktopWorkspaceActive` is written during build

- **Action:** AUTO
- **Finding:** `_desktopWorkspaceActive` is a mutable state field set at line 544 inside `_reportsCommandWorkspace`, which is called from `build`. Writing to instance state inside `build` (outside `setState`) is a Flutter anti-pattern: it is invisible to the framework's dirty-tracking and can silently decohere from what was rendered in the same frame.
- **Why it matters:** `_desktopWorkspaceActive` is subsequently read in `_reportOperationsSurface` (line 2286) and `_selectedReportSurface` (line 1994) during the same `build` call. Because `_reportsCommandWorkspace` is called before those, the value is correct *this frame*, but it is not a `State` field change tracked via `setState`, meaning it will not trigger a rebuild if the layout changes via `LayoutBuilder` constraints on a subsequent frame that doesn't invalidate the parent.
- **Evidence:** Line 162 (declaration), line 544 (write-in-build), lines 1994 and 2286 (reads).
- **Suggested follow-up for Codex:** Replace with a derived bool computed inside `build` at the top level and passed down as a parameter, removing the mutable field entirely.

---

### P2 — Performance: `_sitePartnerComparisonRows` recomputed repeatedly per build

- **Action:** REVIEW
- **Finding:** `_sitePartnerComparisonRows` is a computed getter (line 7042) that calls `_sitePartnerScoreboardRows`, then for every partner row calls `_partnerScopeHistoryPointsFor` (which sorts a copy of `morningSovereignReportHistory`), then sorts the resulting comparison list. It is called at lines 2916, 3184, 10494, 10725 — i.e. multiple times per build, including in `_partnerComparisonCard` and `_partnerScorecardLanesCard` which are both rendered in the same `build()` pass.
- **Why it matters:** For a site with 10 partners and 30 days of sovereign report history, each call iterates and sorts hundreds of objects. Each `build` triggers 4+ full recomputations of this chain.
- **Evidence:** Lines 7042–7124 (computation), lines 2916, 3184, 10494, 10725 (call sites).
- **Suggested follow-up for Codex:** Memoize with a `late final` or compute once at the top of `build()` and pass down. At minimum, compute `_sitePartnerScoreboardRows` and `_sitePartnerComparisonRows` once each at the start of `build` and pass them as locals.

---

### P2 — Performance: `_reportGenerationNowUtc` iterates all events on every report generation

- **Action:** REVIEW
- **Finding:** `_reportGenerationNowUtc` (lines 269–316) iterates `widget.store.allEvents()` and pattern-matches every event against 8 domain event types to find the latest `occurredAt`. This is called in `_generateReport` (line 362). While only called once per generation, `allEvents()` may return thousands of events — and the method contains an 8-arm switch for every event, inside a sequential loop with no early exit.
- **Why it matters:** On a store with 5 000 events, this is 40 000 switch evaluations for a single report generation. More importantly, the logic belongs in the domain/application layer, not in UI state.
- **Evidence:** Lines 269–316.
- **Suggested follow-up for Codex:** Move to `ReportGenerationService` or a dedicated utility. If kept in UI, consider filtering `allEvents()` once at load time or using a pre-indexed `latestEventTimestamp` from the event store.

---

### P2 — Architecture: Domain business logic embedded in UI state

- **Action:** REVIEW
- **Finding:** The following logic lives entirely in `_ClientIntelligenceReportsPageState` with no extraction to the application or domain layer:
  - `_partnerScopeTrendLabel` / `_partnerScopeTrendReason` — scoring algorithm using severity deltas and period comparisons
  - `_receiptPolicyTrendLabel` / `_receiptPolicyTrendReason` / `_receiptPolicySeverityScore` — full policy scoring pipeline
  - `_receiptInvestigationTrendLabel` / `_receiptInvestigationTrendReason` — investigation drift classification
  - `_partnerComparisonSeverityScore` / `_partnerComparisonAcceptedDelay` / `_partnerComparisonOnSiteDelay` — partner ranking metrics
  - `_partnerSeverityScore` — core severity formula
- **Why it matters:** These are untestable as-is. The test file for this widget (`test/ui/guards_page_widget_test.dart` doesn't even target this file). No unit coverage exists for the trend-detection logic, meaning a regression in the scoring formula is undetectable without manual UI inspection.
- **Evidence:** Lines 7264–7292 (`_partnerScopeTrendLabel`), lines 7435–7444 (`_receiptPolicySeverityScore`), lines 7715–7719 (`_partnerSeverityScore`).
- **Suggested follow-up for Codex:** Extract these as static functions or a `ReportReceiptAnalyticsService` / `PartnerScorecardAnalyticsService` in the application layer. Unit tests can then cover them directly.

---

### P2 — Bug suspicion: No guard against concurrent `_generateReport` invocations

- **Action:** AUTO
- **Finding:** The "Generate New Report" button checks `_isGenerating ? null : _generateReport` (line 1766), but the same button appears in at least three other places with the same guard (lines 2143, 2235). If `_isGenerating` becomes stuck (P1 above), none of these guards can reset it. More subtly, a double-tap before the first `setState` call at line 359 is processed could theoretically dispatch two concurrent `_generateReport` calls if Flutter batches the tap events.
- **Why it matters:** Double generation writes two `ReportGenerated` events before either `_loadReceipts` call completes, producing duplicate receipts in the store.
- **Evidence:** Lines 358–389. `_isGenerating` is set via `setState(() => _isGenerating = true)` but the guard is evaluated before that `setState` propagates on a double-tap.
- **Suggested follow-up for Codex:** Use a boolean flag set synchronously before the first `await`, not inside `setState`, as a re-entrant guard.

---

### P3 — Dead state: `_selectedScope` and `_startDate`/`_endDate` are unused in report generation

- **Action:** DECISION
- **Finding:** Three state fields are initialized but do not feed into `_generateReport`:
  - `_selectedScope = 'Sandton Estate North'` (line 158) — appears in a dropdown widget at line 7983 but is not passed to `_service.generatePdfReport`.
  - `_startDate = DateTime.utc(2024, 3, 1)` (line 159) — appears in date pickers but `_reportGenerationNowUtc()` derives the generation timestamp from the event store, ignoring these fields.
  - `_endDate = DateTime.utc(2024, 3, 10)` (line 160) — used only as the fallback in `_reportGenerationNowUtc` (line 316) if no events match.
- **Why it matters:** `_startDate` and `_endDate` still contain a hard-coded 2024 demo range. The `_endDate` fallback at line 316 means a site with no events gets a report dated March 2024. If these fields are genuinely unused, they add confusion; if they are intended to be used, the wiring is missing.
- **Evidence:** Lines 157–160, lines 362–366, line 316.
- **Suggested follow-up for Codex:** Either wire `_startDate`/`_endDate` into generation scope, or remove them. The `_endDate` fallback in `_reportGenerationNowUtc` should be replaced with `DateTime.now().toUtc()` to avoid stale demo dates.

---

### P3 — Hardcoded demo data: `_sampleReceipts` uses client/site literals

- **Action:** REVIEW
- **Finding:** `_sampleReceipts` (line 11079) creates `ReportGenerated` events with `clientId: 'Sandton Estate HOA'` and `siteId: 'Sandton Estate North'`. These do not match `widget.selectedClient`/`widget.selectedSite`. The `verifiedCount`/`pendingCount` computation at lines 419–420 uses `_receipts` (correct), but KPI counts passed to `_kpiBand` at line 795 use `reportRows` which falls back to `_sampleReceipts`. Governance investigation counts, receipt policy history, and the hero header metrics are therefore computed on sample data when no live receipts exist — they show fixture numbers, not real zeros.
- **Why it matters:** A new site with zero receipts will display sample KPIs (e.g. "1247 events", verified/pending from fixture data) in the hero header and supplemental deck. This is misleading to operators.
- **Evidence:** Lines 411, 795–820, 419–448. `_humanizeClient` and `_humanizeSite` at lines 11016–11030 only translate the fixture IDs — they won't match arbitrary real client IDs.
- **Suggested follow-up for Codex:** Either pass `selectedClient`/`selectedSite` into `_sampleReceipts` dynamically, or show genuine empty states (zero counts, OnyxEmptyState) when `_receipts.isEmpty` instead of falling back to sample data for metric computation.

---

### P3 — Duplication: partner-scope recovery card pattern repeated three times

- **Action:** AUTO
- **Finding:** Three near-identical recovery card widgets exist:
  - `_partnerScopePendingRecoveryCard` (called from `_partnerScopeCard`)
  - `_partnerDrillInRecoveryCard` (lines 4202–4331)
  - A third inline recovery block inside `_partnerLaneCommandBanner`
  All three render the same pattern: a chip row (DRILL-IN READY / RECEIPT BOARD / ACTIVITY), a detail text, and a button row with Open Receipt Board / Open Activity Truth / Open Governance / Clear Focus.
- **Why it matters:** Adding a new recovery action or changing copy requires editing three separate widget methods.
- **Evidence:** Lines 4202–4331 (`_partnerDrillInRecoveryCard`), line 2682 (`_partnerScopePendingRecoveryCard` call), lines 3029–3046 (inline logic in `_partnerLaneCommandBanner`).
- **Suggested follow-up for Codex:** Extract a shared `_partnerRecoveryCard` widget that accepts the chip labels, detail text, and button callbacks.

---

### P3 — Duplication: investigation comparison chip block copied across five surfaces

- **Action:** AUTO
- **Finding:** The five-chip "Current Governance / Current Routine / Baseline Governance / Baseline Routine / Baseline Receipts" `Wrap` block is copy-pasted into:
  1. `_receiptPolicyHistoryCard` (lines 3550–3576)
  2. `_openReceiptInvestigationHistory` dialog (lines 3695–3727)
  3. `_openPartnerDrillIn` dialog (lines 4468–4490)
  4. `_partnerComparisonCard` (lines 3323–3355)
  5. `_partnerScopeCard` (lines 2729–2758)
- **Why it matters:** The chip labels and color constants are duplicated verbatim across all five. Changing a label (e.g. "Baseline Governance" → "Gov. Baseline") requires five edits.
- **Evidence:** Lines 3550–3576, 3695–3727, 4468–4490, 3323–3355, 2729–2758.
- **Suggested follow-up for Codex:** Extract a `_receiptInvestigationComparisonChips(_ReceiptInvestigationComparison comparison)` widget method that builds the `Wrap` once.

---

## Coverage Gaps

1. **No test file for this widget.** `test/ui/guards_page_widget_test.dart` targets a different page. There is no `client_intelligence_reports_page_widget_test.dart` or equivalent. Given the complexity, this is the highest-risk untested surface in the UI layer.

2. **No unit tests for trend-scoring functions.** `_partnerScopeTrendLabel`, `_receiptPolicyTrendLabel`, `_receiptInvestigationTrendLabel`, and `_partnerSeverityScore` contain decision thresholds (e.g. `±0.35`, `±2.0 minutes`) that are invisible to CI. A threshold change is a silent regression.

3. **No test for `_generateReport` exception handling.** The P1 stuck-`_isGenerating` bug has no regression test because the method is untested.

4. **No test for `_reportGenerationNowUtc` fallback.** The 2024 fallback date at line 316 is reachable in any empty-store scenario and has no coverage.

5. **No test for `_loadReceipts` race condition.** Concurrent calls from `initState` and `_generateReport` are not exercised.

6. **`_sampleReceipts` client/site mismatch** (see P3 above) is not caught by any widget test because no test pumps the widget with `_receipts.isEmpty` and asserts that KPIs show zeros.

---

## Performance / Stability Notes

1. **`_sitePartnerComparisonRows` getter (line 7042):** Called 4+ times per `build`. Each call sorts a copy of `morningSovereignReportHistory` (O(n log n)) and then calls `_partnerScopeHistoryPointsFor` per partner row (another O(m log m) sort). For 10 partners × 30 reports this is ~300 sort passes per build. Memoize or compute once at build-top.

2. **`_receiptHistoryMetrics` (called from `build`):** Computes `filteredRows`, `reviewedCount`, `alertCount`, etc. by scanning the full `_receipts` list for each count category. Called in `build` at line 412, and also inside `_buildReceiptHistory` (line 8069). If the list is large the double-computation on each build is wasteful. Pass the pre-computed metrics object down instead of re-computing inside `_buildReceiptHistory`.

3. **`_partnerScopeHistoryPointsFor` (lines 6976–7040):** Creates a sorted copy of the full `morningSovereignReportHistory` list on every call. Called from `_sitePartnerComparisonRows` (which calls it per row), from `_partnerScorecardLaneRow` (per row in `build`), and from `_partnerComparisonRow` (per row in `build`). This compounds with point 1.

4. **`_partnerDispatchChainsForScope` (lines 7137–7163):** Also sorts a fresh copy of `morningSovereignReportHistory` per call. Called per partner lane row in `_partnerScorecardLaneRow`. Same pattern as point 3.

---

## Recommended Fix Order

1. **(P1) Wrap `_generateReport` in `try/finally`** — prevents permanent stuck state, simplest fix, AUTO candidate.
2. **(P1) Fix `_desktopWorkspaceActive` write-in-build** — convert to a derived local variable passed down from `build`, AUTO candidate.
3. **(P1) Parallelize `_loadReceipts` hash checks + add re-entrant guard** — `Future.wait` replaces serial loop, REVIEW for scope.
4. **(P3) Fix `_sampleReceipts` KPI fallback** — show true empty counts when `_receipts.isEmpty`, prevents misleading operator display.
5. **(P3) Replace hardcoded `_endDate` fallback in `_reportGenerationNowUtc`** — use `DateTime.now().toUtc()` as the safe fallback, DECISION on whether `_startDate`/`_endDate` fields are still needed.
6. **(P2) Memoize `_sitePartnerComparisonRows` and `_sitePartnerScoreboardRows`** — compute once in `build` and pass down.
7. **(P2) Extract trend/scoring functions to application service** — unlocks unit testing for the scoring pipeline.
8. **(P3) De-duplicate investigation comparison chip block** — extract shared widget method.
9. **(P3) De-duplicate partner recovery card** — extract shared widget method.
10. **Add `client_intelligence_reports_page_widget_test.dart`** — cover generate, load, filter, and empty-state paths.
