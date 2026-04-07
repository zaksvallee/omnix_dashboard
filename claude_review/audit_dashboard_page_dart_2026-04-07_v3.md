# Audit: dashboard_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: lib/ui/dashboard_page.dart (~5 544 lines)
- Read-only: yes

---

## Executive Summary

`dashboard_page.dart` is the largest single UI file in the repo. It is well-structured in terms of widget decomposition (clear lane separation, dedicated sub-widgets, no route logic) and the signal/dispatch/site workspace pattern is coherent. The primary risks are a structural one — a 25-parameter prop-drilling chain that is duplicated verbatim in three call sites — and several hot-path performance issues where projections and trend computations run unconditionally on every rebuild. Coverage of the workspace state machine (mode switching, lane filtering, selection resolution) is entirely absent. Overall: medium-high structural debt, low bug density, high coverage gap.

---

## What Looks Good

- Clean separation between `_DashboardOperationsWorkspace` (interactive state), `_RightRail` (read-only telemetry), and `_DesktopDashboard`/`_CompactDashboard` (layout shells). No route dispatch or persistence calls inside any of these.
- `_buildDashboardTriageSummary` is a pure free function — straightforward to test in isolation.
- `_DashboardAdvancedExportPanel` correctly guards async callbacks with `!mounted` before calling `setState` (line 4619).
- `_MixBar` guards division-by-zero cleanly (line 5420).
- `_formatTimestamp` handles the epoch-zero sentinel (line 5536).
- All `AnimatedContainer` chip widgets carry explicit `ValueKey` identifiers — good for widget-test stability.

---

## Findings

### P1 — Identical 25-parameter block copied three times (prop drilling god-constructor)
- Action: REVIEW
- `DashboardPage` has 30+ constructor parameters. The same block of ~25 guard/sovereign/coaching fields is forwarded verbatim at:
  - Lines 116–158 (`_CompactDashboard` instantiation inside `build`)
  - Lines 161–204 (`_DesktopDashboard` instantiation)
  - Lines 411–446 (`_RightRail` instantiation inside `_DesktopDashboard.build`)
- Why it matters: Any new field requires four edits in the same file (declaration, compact forward, desktop forward, right-rail forward). This is already the source of likely omission bugs and will silently produce stale values if a field is added to one branch but not another.
- Evidence: `dashboard_page.dart` lines 24–94, 116–204, 369–445
- Suggested follow-up: Codex should validate whether introducing a `_GuardSyncState` / `_SovereignReportState` value object (or a `DashboardRailData` record) and passing one object instead of 25 scalars would compile cleanly without touching any logic. A simple data class swap would cut the duplication with no behavioral change.

### P1 — `_buildSignalItems` uses raw summary string as item ID
- Action: AUTO
- `id: row` (line 1523) sets the unique identifier for each `_DashboardSignalItem` to the full summary string. If `OperationsHealthProjection.liveSignals` produces duplicate strings (two intel items with the same text), `_resolveSignalSelection` (line 1705) will always return the first match regardless of which was tapped, and the selected-highlight in `_signalLanePane` will apply to both cards simultaneously.
- Why it matters: A user tapping the second of two identical signals would see the first one remain highlighted — silent selection confusion on an ops-critical screen.
- Evidence: `_buildSignalItems` line 1523; `_resolveSignalSelection` line 1705; `_signalLanePane` comparison at line 1885
- Suggested follow-up: Codex should check whether `OperationsHealthProjection.liveSignals` can ever return duplicates, and if so confirm whether each `IntelligenceReceived` event has a stable unique ID that could be used instead of the row text.

### P2 — Four projection calls in `DashboardPage.build()` run on every parent rebuild
- Action: REVIEW
- `DashboardPage` is a `StatelessWidget`. Its `build()` (lines 97–211) unconditionally calls:
  - `eventStore.allEvents()` (line 98)
  - `OperationsHealthProjection.build(events)` (line 99)
  - `_buildDashboardTriageSummary(events)` (line 100) — O(n²): calls `triagePolicy.evaluateReceived` for each item with the full `allIntel` list
  - `_siteActivityService.buildSnapshot(events: events)` (line 101)
- Why it matters: On any parent `setState` (e.g., guard sync tick), all four projections run synchronously on the main thread before the frame is produced. For a large event store this directly impacts frame rate.
- Evidence: Lines 97–101
- Suggested follow-up: Codex should verify how frequently `DashboardPage`'s parent rebuilds, and whether converting to `StatefulWidget` with explicit field comparison (or caching via `InheritedWidget`/`Provider`) would be appropriate. If `eventStore` is an `InMemoryEventStore` that grows monotonically, memoizing the projection result against event count would be a minimal-risk win.

### P2 — `_siteFocusModel` calls `_buildSiteItems` twice for metric counts
- Action: AUTO
- Inside `_siteFocusModel` (lines 1813–1863), the Watch and Strong metric counts are computed by:
  ```
  _siteCount(_buildSiteItems(widget.snapshot.sites), _DashboardSiteLane.watch)
  _siteCount(_buildSiteItems(widget.snapshot.sites), _DashboardSiteLane.strong)
  ```
  (lines 1847, 1852) — each `_buildSiteItems` call copies and sorts the site list. The already-sorted `siteItems` local variable is available in scope from the outer `build()` call at line 1000 but is not threaded into `_siteFocusModel`.
- Why it matters: Redundant sort on every mode-tab interaction. Minor per call, cumulative if sites grow.
- Evidence: Lines 1000, 1847–1853
- Suggested follow-up: Codex should confirm whether `siteItems` (line 1000) can be passed through to `_siteFocusModel` and substituted for the two internal `_buildSiteItems` calls.

### P2 — `_siteActivityTrendFor` computed four times in the same `_RightRail.build()` cycle
- Action: AUTO
- `_RightRail.build()` calls:
  1. `_siteActivityTrendFor(sovereignReport, siteActivity)` at line 3827 (stored in `siteActivityTrend`)
  2. `_siteActivityTruthJson()` at line 4296 → calls `_siteActivityTrendFor` again (line 3582)
  3. `_siteActivityTruthCsv()` at line 4297 → calls `_siteActivityTrendFor` again (line 3634)
  4. `_siteActivityTelegramSummary()` at line 4298 → calls `_siteActivityTrendFor` again (line 3682)
- Each call independently sorts `morningSovereignReportHistory` and iterates it. The result at line 3827 is never reused for the export strings.
- Why it matters: Four identical computations on every build — wasteful and confusing; any future logic divergence in one copy will create a silent discrepancy between the metric display and the clipboard export.
- Evidence: Lines 3582, 3634, 3682, 3827
- Suggested follow-up: Codex should check whether pre-computing `siteActivityTrend` at the top of `build()` and passing it through to the export methods eliminates all four duplicate calls without changing observable behavior.

### P2 — `_receiptPolicyTrendFor` and `_receiptInvestigationTrendFor` also duplicate baseline sort
- Action: AUTO  
- Both methods (lines 3128–3170, 3172–3224) sort `morningSovereignReportHistory` independently, then `_siteActivityTrendFor` (lines 3226–3282) does a third independent sort of the same list — all three are called in sequence in `build()` (lines 3821–3829).
- Evidence: Lines 3128–3135, 3172–3179, 3226–3234, 3821–3829
- Suggested follow-up: Compute the sorted baseline once at the start of `build()` and pass it to all three trend methods.

### P2 — Unhandled futures in `_DashboardAdvancedExportPanel._actionButton`
- Action: REVIEW
- `_actionButton` wraps the async callback as `() async => onPressed()` (line 4754) with no try/catch. `_copyText`, `_downloadJson`, `_downloadText`, `_shareText`, and `_openMailDraft` all `await` platform channel calls (`Clipboard.setData`, `DispatchSnapshotFileService`, `TextShareService`, `EmailBridgeService`). Platform exceptions thrown from any of these are silently swallowed — the receipt panel will never update and the user sees no feedback.
- Why it matters: On devices where clipboard access or file I/O is restricted, the export action disappears silently with no operator indication of failure.
- Evidence: Line 4754; `_copyText` lines 4627–4633; `_downloadJson` lines 4635–4645
- Suggested follow-up: Codex should validate whether the underlying service methods themselves surface exceptions or return a success bool, and if exceptions can propagate, add a minimal catch to `_actionButton` that sets an error receipt.

---

## Duplication

### Triage posture string
- `'Triage posture: A ${triage.advisoryCount} • W ${triage.watchCount} • DC ${triage.dispatchCandidateCount} • Esc ${triage.escalateCount}'` appears at:
  - Line 825 (`_ExecutiveSummary.build`)
  - Line 1281 (`_workspaceStatusBanner`)
- Centralization candidate: a `_formatTriagePosture(_DashboardTriageSummary)` → `String` helper.

### `_isCompact` layout breakpoint inline at multiple sites
- Width breakpoints `< 1200`, `< 960`, `< 1080`, `< 920`, `< 1160`, `< 1320` appear scattered through `_TopBar`, `_ExecutiveSummary`, `_workspaceStatusBanner`, and `_DesktopDashboard.buildSurfaceBody`. No single breakpoint is reused consistently.
- Files involved: `dashboard_page.dart` throughout; `layout_breakpoints.dart` (imported but not fully exploited here).
- Centralization candidate: named constants or helper functions in `layout_breakpoints.dart`.

### `ExpansionTile` boilerplate
- The exact `Theme(data: Theme.of(context).copyWith(dividerColor: Colors.transparent), child: ExpansionTile(tilePadding: EdgeInsets.zero, childrenPadding: EdgeInsets.zero, iconColor: ..., collapsedIconColor: ...))` block appears twice (lines 4023–4215, 4261–4303) in `_RightRail.build()`.
- Centralization candidate: a `_OnyxExpansionTile` widget.

### `_guardFailureTraceText` trivial alias
- `_guardFailureTraceText` (lines 3495–3498) is a one-liner that delegates directly to `_guardFailureTraceClipboard` with the same args. The alias adds nothing and creates a false impression of a second code path.
- Evidence: Lines 3111–3126 (definition of `_guardFailureTraceClipboard`), 3495–3498

---

## Coverage Gaps

- **Workspace state machine is untested**: No tests exercise `_DashboardOperationsWorkspaceState` mode switching (`_setMode`, `_focusSignalLaneAction`, `_focusDispatchLaneAction`, `_focusSiteLaneAction`), lane filtering, or selection resolution after a lane change clears the current selection.
- **`_buildSignalItems` regex parsing**: The `risk (\d+)` regex extraction (line 1514), the `row.startsWith('Intel ')` / `'Incident '` / `'Patrol '` branching (lines 1522–1563), and the `_siteTokenFromSummary` regex (line 2673) are all logic paths with no unit test coverage. A malformed signal string would silently produce a zero-risk item.
- **`_buildDispatchItems` status parsing**: The `Dispatch ([^ ]+) ([A-Z]+)` regex (line 1572) falls back to `row` as the dispatchId and `'DECIDED'` as the status when the match fails — an untested fallback path.
- **Export panel receipt feedback**: No widget test verifies that the receipt panel updates after a successful copy/download/share action.
- **Threat state threshold logic**: `_threat()` (line 213) uses `>= 80` / `>= 60` thresholds. No tests assert the exact CRITICAL/ELEVATED/STABLE boundary values.
- **`_isSameSovereignReport` identity logic** (line 3284): Uses a three-field tuple comparison instead of object identity. If two reports share the same `generatedAtUtc` but differ in content, it would be considered the same — no test covers this edge case.

---

## Performance / Stability Notes

- **`_siteActivityCommandScope()` iterates `allEvents` (O(n)) and is called implicitly during `_siteActivityTruthJson()` and `_siteActivityTruthCsv()`**: both are called unconditionally inside the "Advanced export" `ExpansionTile` children at build time (lines 4282–4298), even when the tile is collapsed. Flutter evaluates `ExpansionTile.children` eagerly. All JSON/CSV export strings are built on every `_RightRail.build()` call, including the full event-store iteration inside `_siteActivityCommandScope`.
- **`_siteActivityHistoryDatesForScope` defines an inner `two()` closure** (line 3554): The closure is recreated on every call. No semantic risk, but a minor allocation on a path that iterates all events.
- **`_DashboardOperationsWorkspaceState.build()` calls `_buildSignalItems`, `_buildDispatchItems`, and `_buildSiteItems` unconditionally** (lines 998–1000) on every `setState` (e.g., every lane or selection change), even if `widget.snapshot` hasn't changed. These are O(n) list transforms.

---

## Recommended Fix Order

1. **Extract `_GuardSyncState` / `DashboardRailData` value object** — eliminates the 3× verbatim 25-param forward blocks. Lowest risk, highest structural payoff. (P1 · REVIEW)
2. **Pre-compute trend baseline sort once in `_RightRail.build()`** and thread it through all three trend methods and the four export-string generators. (P2 · AUTO)
3. **Fix `_siteFocusModel` double `_buildSiteItems` call** — pass the already-sorted list from the outer scope. (P2 · AUTO)
4. **Resolve `_buildSignalItems` ID uniqueness** — confirm whether duplicate strings are possible and add a stable ID if so. (P1 · AUTO/REVIEW depending on projection contract)
5. **Add error receipt to `_actionButton`** for swallowed platform exceptions. (P2 · REVIEW)
6. **Write unit tests for `_buildSignalItems` and `_buildDispatchItems` parsing** — pure functions that can be extracted and tested without Flutter. (coverage · AUTO)
7. **Write widget tests for workspace mode and lane switching** — assert that selection resets correctly after lane change empties visible items. (coverage · AUTO)
8. **Remove `_guardFailureTraceText` alias** — call `_guardFailureTraceClipboard` directly. (cleanup · AUTO)
