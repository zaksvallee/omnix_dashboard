# Audit: dashboard_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: lib/ui/dashboard_page.dart (5544 lines)
- Read-only: yes

---

## Executive Summary

`dashboard_page.dart` is structurally functional but carries three serious architectural problems that will increasingly resist maintenance. First, every guard/sovereign/activity parameter fans through four widget layers with zero abstraction — 25+ props pass through `DashboardPage` → `_DesktopDashboard`/`_CompactDashboard` → `_RightRail` unchanged, a classic prop-drilling god-parameter problem. Second, domain logic (regex parsing, trend computation, receipt policy scoring) lives inside `StatelessWidget` and `State` classes — this is a direct layer violation in a DDD codebase. Third, several expensive computations run unconditionally on every `build()` call, including event store scans, triage policy evaluation, and sort operations. The widget test file covers surface-level smoke tests but has zero coverage of signal/dispatch parsing, trend logic, or filter state transitions.

---

## What Looks Good

- `_DashboardOperationsWorkspaceState` manages workspace mode and lane selection cleanly with early-return guards in setters (`if (_mode == mode) return;`), preventing unnecessary rebuilds.
- `_buildSiteItems` uses a defensive copy before sort (`[...sites]..sort(…)`) — snapshot integrity is preserved.
- `_DashboardAdvancedExportPanel` correctly checks `mounted` before calling `setState` after async clipboard/file operations (line 4619).
- Lane filter chips carry `ValueKey` strings throughout, enabling reliable widget test targeting.
- `_MixBar` correctly clamps fraction to `[0.0, 1.0]` (line 5420).
- `_formatTimestamp` guards the epoch-zero sentinel (line 5536).

---

## Findings

### P1 — Bug: Async export operations silently swallow all exceptions
- Action: AUTO
- Finding: `_copyText`, `_downloadJson`, `_downloadText`, `_shareText`, and `_openMailDraft` in `_DashboardAdvancedExportPanelState` are all `async` with no `try/catch`. If `Clipboard.setData`, the file service, or the email bridge throws, the exception is dropped and the receipt never updates — the operator sees stale feedback with no error indication.
- Why it matters: Export operations hit platform channels and can fail silently on Android/web permission errors or quota limits. The operator receives no feedback that the handoff failed.
- Evidence: `lib/ui/dashboard_page.dart` lines 4627–4694 — none of the five async helpers have error handling.
- Suggested follow-up for Codex: Wrap each async body in `try/catch`, then call `_setReceipt` with an error-colored receipt on failure.

---

### P1 — Bug: Stale `DateTime.now()` in build path for stale-sync alert
- Action: REVIEW
- Finding: The guard stale-sync alert at line 3772 uses `DateTime.now()` directly inside `_RightRail.build()`. If the widget tree is rebuilt for any unrelated reason (e.g. theme change, ancestor state update), the staleness window is re-evaluated silently. If the build is suppressed (e.g. widget off-screen in a ListView), the alert may never appear even when the sync is stale.
- Why it matters: A security ops dashboard that fails to show a stale-sync alert is a silent failure of the monitoring guarantee.
- Evidence: `lib/ui/dashboard_page.dart` lines 3770–3774.
- Suggested follow-up for Codex: Validate whether `_RightRail` is always rebuilt on a periodic tick or whether a timer-driven rebuild is needed to keep the staleness check live.

---

### P1 — Domain logic in UI: String-based signal/dispatch classification via regex in build path
- Action: REVIEW
- Finding: `_buildSignalItems` (line 1511) and `_buildDispatchItems` (line 1569) are instance methods on `_DashboardOperationsWorkspaceState` that parse raw string rows using `RegExp` and `startsWith` to classify events into lanes. This parsing logic belongs in an application-layer presenter or projection, not in widget state. Currently every `setState` (lane change, selection change) re-runs all regex matching against the full signal and dispatch string lists.
- Why it matters: (1) Domain rule leakage into UI — lane classification rules are silently split across the UI and whatever upstream code formats the string rows. (2) Performance — regex compilation and matching runs on every rebuild cycle even when the event store has not changed. (3) Untestable without a widget harness.
- Evidence: `lib/ui/dashboard_page.dart` lines 1511–1609.
- Suggested follow-up for Codex: Extract `_buildSignalItems` and `_buildDispatchItems` into a `DashboardWorkspacePresenter` or equivalent application-layer class. Cache the result and only recompute when `snapshot` changes.

---

### P1 — Domain logic in UI: Trend computation and receipt policy scoring in `_RightRail`
- Action: REVIEW
- Finding: `_receiptPolicyTrendFor`, `_receiptInvestigationTrendFor`, `_siteActivityTrendFor`, `_receiptPolicySeverityScore`, `_slippingReceiptPolicySummary`, `_improvingReceiptPolicySummary`, and related helpers are all methods on the `_RightRail` `StatelessWidget`. They contain scoring formulas, delta thresholds, and comparative logic — clearly domain/application layer responsibilities. This is a hard DDD layer violation.
- Why it matters: Business rules embedded in `StatelessWidget` cannot be unit-tested in isolation, cannot be reused by other pages or services, and will drift silently as sovereign report structure evolves.
- Evidence: `lib/ui/dashboard_page.dart` lines 3128–3465.
- Suggested follow-up for Codex: Extract the trend/scoring logic into a `SovereignReportTrendService` or `DashboardRailPresenter` in `/lib/application/`.

---

### P2 — Performance: Expensive projections run on every `DashboardPage.build()`
- Action: REVIEW
- Finding: `DashboardPage.build()` (lines 98–101) calls `eventStore.allEvents()`, `OperationsHealthProjection.build(events)`, `_buildDashboardTriageSummary(events)`, and `_siteActivityService.buildSnapshot(events: events)` unconditionally on every rebuild. `_buildDashboardTriageSummary` loops all events and calls `triagePolicy.evaluateReceived` for each — potentially O(n²) if triage does any linear scan internally.
- Why it matters: Since `DashboardPage` is a `StatelessWidget`, it rebuilds whenever the parent rebuilds (e.g. during any state change higher in the tree). Any repeated `setState` call from `_DashboardOperationsWorkspaceState` (filter/selection taps) triggers a full re-projection of the event store.
- Evidence: `lib/ui/dashboard_page.dart` lines 97–101. `_buildDashboardTriageSummary` lines 252–327.
- Suggested follow-up for Codex: Move projection computation to a `ValueNotifier`/`InheritedWidget` or memoize via a controller layer that only recomputes when the event store changes, not on every UI interaction.

---

### P2 — Performance: `_buildSiteItems` sort called twice per `_siteFocusModel` render
- Action: AUTO
- Finding: `_siteFocusModel` calls `_buildSiteItems(widget.snapshot.sites)` twice (lines 1847 and 1852) to compute "Watch" and "Strong" counts. Each call creates a copy of the sites list and sorts it. This runs on every render of the workspace pane when mode == sites.
- Why it matters: Two redundant sort operations per frame in the hot render path.
- Evidence: `lib/ui/dashboard_page.dart` lines 1843–1855.
- Suggested follow-up for Codex: Hoist the `_buildSiteItems` result to a local variable before passing to `_siteFocusModel`, or compute watch/strong counts without a full sort (direct `where().length`).

---

### P2 — Performance: Export JSON/CSV computed eagerly before ExpansionTile opens
- Action: REVIEW
- Finding: `_RightRail.build()` passes pre-computed strings (`_siteActivityTruthJson()`, `_siteActivityTruthCsv()`, `_siteActivityTelegramSummary()`, `_guardPolicyTelemetryJson()`, etc.) to `_DashboardAdvancedExportPanel` before the "Advanced export and share" `ExpansionTile` is ever opened. Each of these methods calls `_siteActivityTrendFor`, sorts baseline reports, and runs `JsonEncoder.withIndent`. These are all wasted cycles if the panel stays collapsed.
- Why it matters: Every rebuild of `_RightRail` — including passive ones from ancestor state changes — triggers these string-building paths.
- Evidence: `lib/ui/dashboard_page.dart` lines 4279–4299 (call site), lines 3579–3692 (builders).
- Suggested follow-up for Codex: Move export string computation into `_DashboardAdvancedExportPanelState`, lazily evaluated when the panel expands, or pass builder callbacks instead of pre-computed strings.

---

### P2 — Structural: 25-parameter prop drilling through four widget layers
- Action: DECISION
- Finding: All guard sync and sovereign report parameters are declared on `DashboardPage` (lines 27–93), duplicated in full on `_DesktopDashboard` (lines 333–405), `_CompactDashboard` (lines 527–601), and `_RightRail` (lines 3036–3109). The three intermediate classes pass every parameter down unchanged — no filtering, no derivation, no composition.
- Why it matters: Adding any new parameter requires changes in four places. This is already ~120 constructor parameter declarations for a single data path. The `_DashboardPage` class itself cannot be const-constructed because of nullable params that change.
- Evidence: `lib/ui/dashboard_page.dart` lines 27–94, 333–405, 527–601, 3036–3109.
- Suggested follow-up for Codex: **DECISION required.** Options are (a) introduce a `GuardRailConfig` value object and a `SovereignRailConfig` value object to group related params, (b) use an `InheritedWidget` or `Provider` to scope these params to the right-rail subtree only, or (c) extract `_RightRail` into a separate page-level widget that reads from a controller directly. All three need architectural alignment before implementation.

---

### P3 — Duplication: `_guardFailureTraceText` is a pure delegate with no purpose
- Action: AUTO
- Finding: `_guardFailureTraceText` (lines 3495–3498) is a one-line method that simply calls `_guardFailureTraceClipboard` with the same arguments and returns its result. It adds no logic.
- Why it matters: Dead indirection — any reader must follow two hops to understand what the export panel receives.
- Evidence: `lib/ui/dashboard_page.dart` lines 3495–3498, 3111–3126.
- Suggested follow-up for Codex: Remove `_guardFailureTraceText` and call `_guardFailureTraceClipboard` directly at line 4288.

---

### P3 — Duplication: Baseline report filtering duplicated in three trend methods
- Action: AUTO
- Finding: The baseline-report filtering and sorting block (filter out current report → sort descending by `generatedAtUtc` → take(3)) is copy-pasted verbatim in `_receiptPolicyTrendFor` (lines 3129–3143), `_receiptInvestigationTrendFor` (lines 3173–3190), and `_siteActivityTrendFor` (lines 3230–3246). All three differ only in what they do with the baseline after retrieving it.
- Why it matters: Any change to baseline selection logic (e.g. change take(3) to take(5)) must be applied in three places.
- Evidence: Lines 3129–3143, 3173–3190, 3230–3246.
- Suggested follow-up for Codex: Extract a `_baselineReports(SovereignReport current)` helper that returns the sorted, filtered, trimmed list. Each trend method calls it once.

---

### P3 — Duplication: `_siteActivityTruthJson` and `_siteActivityTruthCsv` share identical preamble
- Action: AUTO
- Finding: Both `_siteActivityTruthJson` (line 3579) and `_siteActivityTruthCsv` (line 3632) open with identical code: compute `sovereignReport`, call `_siteActivityTrendFor`, call `_siteActivityCommandScope`, and call `_siteActivityHistoryDatesForScope`. The only difference is the serialization format at the end.
- Why it matters: Any change to scope resolution or trend computation must be applied twice.
- Evidence: `lib/ui/dashboard_page.dart` lines 3579–3592, 3632–3647 (parallel preamble blocks).
- Suggested follow-up for Codex: Extract a private `_siteActivityExportState()` record/value that returns the common fields, then call it once from each format method.

---

### P3 — Duplication: `topSignalsSummary` rendered twice with near-identical logic
- Action: AUTO
- Finding: The triage posture string `'Top triage signals: ${triage.topSignalsSummary}'` is conditionally rendered in both `_ExecutiveSummary.build()` (lines 896–906) and `_workspaceStatusBanner` (lines 1288–1296), with nearly identical `if (…isNotEmpty)` guards and similar text styles.
- Why it matters: Minor UI drift between the two has already occurred (font sizes differ: 4.2 vs 4.1). If the format changes, both must be updated.
- Evidence: Lines 896–906 and 1288–1296.
- Suggested follow-up for Codex: This is low priority — document the intentional duplication or extract a `_TriageSignalLabel` widget.

---

## Coverage Gaps

1. **Signal/dispatch item parsing is entirely untested.** `_buildSignalItems` and `_buildDispatchItems` perform regex matching that maps raw strings to lane assignments and accent colors. No test exists for: missing match groups, unexpected row prefixes, `int.tryParse` returning null. Evidence: `test/ui/dashboard_page_widget_test.dart` — no calls to these methods or assertions on lane assignment.

2. **Trend computation logic has no unit tests.** `_receiptPolicyTrendFor`, `_receiptInvestigationTrendFor`, and `_siteActivityTrendFor` compute deltas and emit SLIPPING/IMPROVING/STABLE labels. No test exists for any delta threshold or edge case (empty baseline, all-zero current, etc.).

3. **Filter state transitions are not tested.** Lane filter chips, workspace mode chips, and the three `_focus*LaneAction` methods drive `setState` with selection side effects. No widget test exercises a filter tap and asserts that the pane content changes.

4. **Export panel action buttons are not tested.** The `_DashboardAdvancedExportPanel` contains ~20 action buttons across 5 export categories. The test file has helpers for `expectTextButtonDisabled` / `expectTextButtonEnabled` but no tests for any export action, download, or share flow.

5. **Guard stale-sync alert timing is not tested.** There is no test that provides a stale `guardLastSuccessfulSyncAtUtc` and asserts the 'Stale Sync' chip appears.

---

## Performance / Stability Notes

- `_buildDashboardTriageSummary` is a top-level function that runs `triagePolicy.evaluateReceived` for every `IntelligenceReceived` event on every build. If `evaluateReceived` does any linear scan of `allIntel` or `decisions`, this is O(n²). No memoization exists.
- `_siteActivityCommandScope()` iterates `allEvents` on every `_RightRail.build()` invocation (line 3516). This runs even when no site activity data is present.
- The `_DesktopDashboard.build()` method constructs a fully realized `_RightRail` widget at line 409 even when `stackRightRailBelow` is false and the rail is rendered in a `SizedBox` — this is fine, but worth noting that the right rail is always instantiated regardless of layout path.
- `_workspaceMetricGrid` uses a `LayoutBuilder` to compute cell widths (line 2483), which triggers an additional layout pass per pane render. This fires on every workspace pane rebuild, including selection taps.

---

## Recommended Fix Order

1. **(P1 AUTO)** Add try/catch to all five async export handlers in `_DashboardAdvancedExportPanelState` — defensive and isolated, no architectural change needed.
2. **(P3 AUTO)** Remove `_guardFailureTraceText` delegate — single-line mechanical change.
3. **(P3 AUTO)** Extract `_baselineReports` helper to eliminate the three-way duplication in trend methods.
4. **(P3 AUTO)** Extract `_siteActivityExportState()` to eliminate the duplicated preamble in JSON/CSV builders.
5. **(P2 AUTO)** Fix the double `_buildSiteItems` call in `_siteFocusModel`.
6. **(P1 REVIEW)** Validate stale-sync alert timing — confirm whether a periodic rebuild exists or whether a ticker is needed.
7. **(P2 REVIEW)** Move export string computation behind lazy evaluation (deferred until ExpansionTile opens).
8. **(P1 REVIEW)** Extract signal/dispatch item building to an application-layer presenter.
9. **(P1 REVIEW)** Extract trend/scoring logic from `_RightRail` into a service.
10. **(P1 DECISION)** Address the 25-parameter prop-drilling pattern — requires architecture alignment before any implementation.
