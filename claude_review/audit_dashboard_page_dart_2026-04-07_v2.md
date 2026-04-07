# Audit: dashboard_page.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: lib/ui/dashboard_page.dart (5,543 lines)
- Read-only: yes

---

## Executive Summary

`dashboard_page.dart` is a large but generally coherent file. The widget hierarchy is
well-named and the responsive layout branching is intentional. The main structural
problem is a **33-parameter prop-drilling chain** repeated verbatim three times, creating
a maintenance trap where every new field requires edits in at least five places.
Below that, several **hot-path redundancies** recompute expensive work (sorting,
regex parsing, JSON serialisation) on every build. The test suite covers the happy path
and key export interactions, but leaves the signal/dispatch parsing logic and
all three trend-analysis methods completely untested.

---

## What Looks Good

- `_DashboardOperationsWorkspaceState` cleanly owns mode + lane + selection state; the
  state transitions (`_setMode`, `_setSignalLane`, etc.) all guard against no-op sets.
- `_buildDashboardTriageSummary` is a pure free function — easy to unit test and already
  exercised at widget level.
- `_DashboardAdvancedExportPanel` is extracted into its own `StatefulWidget` with a
  clean receipt-feedback loop; the fallback clipboard path for missing share/mail
  bridges is consistently applied.
- `_formatTimestamp` correctly handles the epoch-zero sentinel with a readable label.
- `OnyxTruncationHint` usage is consistent across all three lane panes.

---

## Findings

### P1 — Prop-drilling explosion (33 fields duplicated three times)

- **Action: REVIEW**
- `DashboardPage` declares 33 constructor parameters. They are forwarded verbatim to
  `_CompactDashboard` (lines 114–157) and `_DesktopDashboard` (lines 159–203). Inside
  `_DesktopDashboard.build()` the same 33 fields are forwarded again to `_RightRail`
  (lines 409–446). `_CompactDashboard.build()` repeats the same forward to `_RightRail`
  (lines 617–656). The result is four identical 33-field parameter lists across the
  file.
- **Why it matters:** Any new field requires edits in at minimum five places. The
  current size already masks the actual calling contract, and the constructor of
  `_DesktopDashboard` and `_CompactDashboard` are structurally identical (lines 329–405
  vs 526–600) apart from their `build` methods. A single `_DashboardRailProps` value
  object (or an inherited widget) would eliminate this duplication entirely.
- **Evidence:** `dashboard_page.dart` lines 59–93, 114–157, 159–203, 368–404, 564–600.
- **Follow-up for Codex:** Verify that `_CompactDashboard` and `_DesktopDashboard`
  differ only in their `build` body, then assess whether they can be merged into a
  single widget with a `compact` flag, or whether the rail props should become an
  `InheritedWidget` / value bundle.

---

### P1 — Expensive work repeated on every build in `_DashboardOperationsWorkspaceState`

- **Action: AUTO**
- `build()` calls `_buildSignalItems`, `_buildDispatchItems`, and `_buildSiteItems` on
  every frame. `_buildSignalItems` (lines 1511–1567) constructs `RegExp` objects inline
  for each row on every call. `_buildSiteItems` (lines 1612–1619) sorts a copy of the
  sites list on every call.
- Additionally, `_siteFocusModel` (lines 1813–1863) calls `_buildSiteItems(widget.snapshot.sites)`
  **twice** (lines 1847 and 1853) to compute watch- and strong-lane counts, adding two
  extra sorts per build when the sites mode is active.
- **Why it matters:** These are O(n log n) or O(n·k) operations running in the widget
  `build` method. In a large operational session with many events, every rebuild
  (interaction, scroll, lane switch) triggers redundant sort and regex work.
- **Evidence:** `dashboard_page.dart` lines 997–1099 (build body), 1514–1517 (RegExp
  construction), 1613–1618 (sort), 1847, 1852 (double sort in focus model).
- **Follow-up for Codex:** Cache the results of `_buildSignalItems`, `_buildDispatchItems`,
  and `_buildSiteItems` — either via `didUpdateWidget` invalidation or by extracting
  them to a parent and passing them in as pre-computed lists. Pre-compile the RegExp
  objects as static constants.

---

### P1 — JSON/CSV/Telegram blobs serialised on every `_RightRail` rebuild, including when the panel is collapsed

- **Action: REVIEW**
- `_RightRail.build()` unconditionally calls `_siteActivityTruthJson()`,
  `_siteActivityTruthCsv()`, `_siteActivityTelegramSummary()`,
  `_guardPolicyTelemetryJson()`, `_guardPolicyTelemetryCsv()`,
  `_guardCoachingTelemetryJson()`, `_guardCoachingTelemetryCsv()`, and
  `_siteActivityReviewJson()` and passes them as `String` arguments to
  `_DashboardAdvancedExportPanel` (lines 4279–4300). These strings are produced even
  when the `ExpansionTile` containing the panel is collapsed.
- Each of these methods performs its own `JsonEncoder.withIndent('  ').convert(...)` or
  list join, and some iterate over `allEvents` (O(n)) — `_siteActivityCommandScope()`
  at lines 3517–3536 iterates `allEvents` up to four times independently across these
  methods.
- **Why it matters:** Every rebuild of the right rail serialises up to eight string
  blobs regardless of visibility. On large event sets this wastes CPU and GC pressure
  on every interaction.
- **Evidence:** `dashboard_page.dart` lines 4279–4300 (call site), 3579–3630
  (`_siteActivityTruthJson`), 3632–3678 (`_siteActivityTruthCsv`), 3517–3536
  (`_siteActivityCommandScope` — called once per export method).
- **Follow-up for Codex:** Move export string generation into `_DashboardAdvancedExportPanel`
  itself and compute lazily on demand (button press or expansion), or cache them with
  an `AutomaticKeepAliveClientMixin` / `didUpdateWidget` guard.

---

### P2 — Three trend methods each independently sort `morningSovereignReportHistory`

- **Action: AUTO**
- `_receiptPolicyTrendFor` (lines 3128–3170), `_receiptInvestigationTrendFor` (lines
  3172–3224), and `_siteActivityTrendFor` (lines 3226–3282) each start by copying and
  sorting `morningSovereignReportHistory`, then slicing the same top-3. The sort and
  filter logic is copy-pasted. All three are called in `_RightRail.build()` (lines
  3821–3829).
- **Why it matters:** The list is sorted three times on the same data in the same build
  call. If the history list grows large this is O(3 n log n) per build.
- **Evidence:** `dashboard_page.dart` lines 3130–3143, 3174–3187, 3229–3244.
- **Follow-up for Codex:** Extract the common "sort history, take 3 baseline" step into
  a single private helper, compute it once before calling the three trend methods, and
  pass the baseline in as a parameter.

---

### P2 — `_guardFailureTraceText` is a no-op passthrough

- **Action: AUTO**
- Lines 3495–3498 define `_guardFailureTraceText` as a one-liner that calls
  `_guardFailureTraceClipboard` with the same arguments:
  ```dart
  String _guardFailureTraceText(...) => _guardFailureTraceClipboard(...);
  ```
  The only call site (line 4288) invokes `_guardFailureTraceText`. The intermediate
  method adds no logic and creates a confusingly parallel name.
- **Why it matters:** Dead indirection; increases reading burden.
- **Evidence:** `dashboard_page.dart` lines 3495–3498, 4288.
- **Follow-up for Codex:** Delete `_guardFailureTraceText` and call
  `_guardFailureTraceClipboard` directly at line 4288.

---

### P2 — `_isSameSovereignReport` uses time equality, not a stable ID

- **Action: REVIEW**
- Lines 3284–3288 identify the "same report" by matching `generatedAtUtc`,
  `shiftWindowEndUtc`, and `date`. There is no `reportId` field or hash-based
  identity. Two reports generated within the same second covering the same window
  but with different content would be treated as the same report, and a regenerated
  report at a slightly different timestamp would be counted as distinct baseline data.
- **Why it matters:** The trend baseline computation (used for receipt policy,
  investigation, and site activity trends) could silently include or exclude the wrong
  report if the report generation clock has millisecond variation.
- **Evidence:** `dashboard_page.dart` lines 3284–3288, 3130–3131, 3174–3175, 3229–3230.
- **Follow-up for Codex:** Determine whether `SovereignReport` has or could have a
  stable ID field. If so, use it. If not, at minimum document the equality contract.

---

### P2 — Signal IDs are raw string rows — collisions possible

- **Action: REVIEW**
- `_DashboardSignalItem.id` is assigned `row` (the raw string from `liveSignals`) at
  line 1523. Selection state `_selectedSignalId` is compared against these IDs at line
  1706. If `liveSignals` contains duplicate strings, two cards will render with
  identical keys and the first match wins — the second item can never be individually
  selected.
- **Why it matters:** Silent deduplication that could mask data (e.g., two
  `IntelligenceReceived` events with identical summary strings).
- **Evidence:** `dashboard_page.dart` lines 1511–1523, 1705–1708.
- **Follow-up for Codex:** Verify whether `liveSignals` can contain duplicate strings.
  If so, index the items (e.g., `'$row-$index'`) to guarantee unique IDs.

---

### P2 — Triage posture string built in two separate places

- **Action: AUTO**
- The string `'Triage posture: A ${...} • W ${...} • DC ${...} • Esc ${...}'` is
  assembled in `_ExecutiveSummary.build()` (line 825) and again inside
  `_workspaceStatusBanner` (line 1281). Both read from the same `_DashboardTriageSummary`
  object.
- **Why it matters:** If the posture label format changes, both sites must be updated.
  `_DashboardTriageSummary` is the natural home for a `postureLabel` getter.
- **Evidence:** `dashboard_page.dart` lines 825, 1281.
- **Follow-up for Codex:** Add a `postureLabel` getter to `_DashboardTriageSummary` and
  reference it in both call sites.

---

### P3 — `DateTime.now()` called inside `_RightRail.build()` for stale-sync check

- **Action: REVIEW**
- Line 3772 calls `DateTime.now().toUtc()` inside the widget `build` method as part of
  the stale-sync alert computation. This is not a bug, but it means the alert state is
  sampled only when the widget rebuilds (e.g., user taps something). The stale-sync
  alert may appear/disappear a few seconds late relative to the actual threshold
  crossing.
- **Why it matters:** In an ops context where a 10-minute stale sync threshold is
  monitored, a missed transition is visible. If there is already a timer-driven rebuild
  mechanism at the page level this is a non-issue — but if rebuilds are purely
  event-driven, the alert could arrive late.
- **Evidence:** `dashboard_page.dart` lines 3770–3774.
- **Follow-up for Codex:** Verify whether the parent rebuilds on a regular interval. If
  not, confirm whether late alert rendering is acceptable.

---

### P3 — `_CompactDashboard` adds `_ExecutiveSummary` but `_DesktopDashboard` does not

- **Action: DECISION**
- `_CompactDashboard.build()` (lines 604–659) prepends `_ExecutiveSummary` above the
  workspace. `_DesktopDashboard` omits it entirely. The KPI Band content is therefore
  absent on desktop. This may be intentional (desktop has the `_TopBar` and the right
  rail), but it is not documented and the two paths diverge silently.
- **Why it matters:** If an operator uses desktop layout they never see the triage
  posture strip in KPI Band form. If this is a product decision it should be explicit.
- **Evidence:** `dashboard_page.dart` lines 604–658 vs 407–522.
- **Follow-up:** Zaks to confirm whether `_ExecutiveSummary` is intentionally
  desktop-suppressed.

---

## Duplication

| Pattern | Locations | Centralisation candidate |
|---|---|---|
| 33-field prop list | `DashboardPage` → `_CompactDashboard`, `_DesktopDashboard`, `_RightRail` (×4) | `_DashboardRailProps` value object or `InheritedWidget` |
| Triage posture string | lines 825, 1281 | `_DashboardTriageSummary.postureLabel` getter |
| `sort history → take 3 baseline` | `_receiptPolicyTrendFor`, `_receiptInvestigationTrendFor`, `_siteActivityTrendFor` | Single `_recentBaselineReports()` helper |
| `_siteActivityCommandScope()` called once per export method | `_siteActivityTruthJson`, `_siteActivityTruthCsv`, `_siteActivityTelegramSummary` | Compute once, pass to all three |
| `borderRadius: BorderRadius.circular(999)` pill pattern | 10+ inline sites across chips and containers | Already a pattern — no action needed unless a shared constant is preferred |

---

## Coverage Gaps

1. **`_buildSignalItems` regex classification** — The three-way branch (Intel / Incident
   / fallback Field/Patrol) at lines 1522–1566 has no unit test. Edge cases: row
   without `'risk \d+'` match, row starting with `'Patrol '` vs plain field row.

2. **`_buildDispatchItems` status→lane mapping** — The switch at lines 1578–1582 maps
   `'CONFIRMED'`, `'EXECUTED'`, `'FAILED'`, `'DENIED'`, and the default case. There is
   no unit test verifying each branch. In particular the `'FAILED'` vs `'DENIED'` lane
   distinction (one is `risk`, the other is also `risk`) should be locked.

3. **All three `_*TrendFor` methods** — `_receiptPolicyTrendFor`,
   `_receiptInvestigationTrendFor`, and `_siteActivityTrendFor` compute delta thresholds
   (0.75, 0.5, 1.0) with no test coverage. These produce the `SLIPPING / IMPROVING /
   STABLE` labels shown in the right rail.

4. **`_siteActivityCommandScope()` multi-client/multi-site suppression** — The null
   return on multiple clientIds or siteIds (line 3532) is untested. A two-site activity
   scenario should confirm silent suppression behaviour is correct.

5. **`_isSameSovereignReport` edge cases** — Two reports at the same second, or a
   re-generated report with a new timestamp, have no coverage.

6. **Desktop layout KPI Band absence** — No test asserts that `_ExecutiveSummary` /
   KPI Band is absent on desktop viewport (1600×1000). The compact test confirms its
   presence on phone, but the desktop suppression path is unverified.

7. **Signal selection after lane switch** — When `_focusSignalLaneAction` switches the
   lane, it sets `_selectedSignalId` to `visible.first.id` (line 1118). There is no
   test covering the scenario where the currently selected item is not in the new lane
   (i.e., verifying fallback to first).

---

## Performance / Stability Notes

1. **RegExp instantiation in build hot path** — `RegExp(r'risk (\d+)', caseSensitive: false)`
   (line 1514) and `RegExp(r'Dispatch ([^ ]+) ([A-Z]+)')` (line 1572) are constructed
   inside `.map()` lambdas that run on every build. These should be `static const`
   fields.

2. **`_buildDashboardTriageSummary` called every build of `DashboardPage`** — This
   function iterates over all `IntelligenceReceived` events and calls
   `triagePolicy.evaluateReceived` for every one. If `evaluateReceived` itself iterates
   `allIntel` internally, the total complexity is O(n²) in event count. On a long-running
   session this becomes the dominant build cost. Evidence: lines 252–327.

3. **`_RightRail` is `StatelessWidget` but contains service instances as `static const`**
   — `_siteActivityTelegram = SiteActivityTelegramFormatter()` at line 3034 is fine as
   a `const` singleton. No issue here, just worth confirming the formatter has no
   mutable state.

4. **No key propagation on `_RightRail`** — `_RightRail` has no `key`. In the
   `_DesktopDashboard` it is created as a local variable and reused in
   `buildSurfaceBody`. If `buildSurfaceBody` is called in a new layout context (scroll
   vs non-scroll branch), Flutter may dispose and recreate the subtree. Because
   `_RightRail` is stateless this is not a state-loss bug, but the `ExpansionTile`
   expansion state inside it **will reset** on viewport resize that crosses the 1320px
   threshold. Evidence: lines 409–446, 478–509.

---

## Recommended Fix Order

1. **Extract `_DashboardRailProps`** (P1 prop-drilling) — Highest leverage; touches the
   most duplicated surface area and unblocks any future feature additions to the rail.
2. **Cache `_buildSignalItems` / `_buildDispatchItems` / `_buildSiteItems` results and
   pre-compile RegExp constants** (P1 hot-path) — Directly improves build performance
   on busy sessions; `AUTO` label means Codex can implement without a product decision.
3. **Lazy export string generation** (P1 JSON serialisation) — Move computation out of
   `build` into button-press handlers or expansion callbacks.
4. **Extract baseline sort helper for trend methods** (P2 duplication) — Small and
   safe; reduces the triple-sort on every build.
5. **Delete `_guardFailureTraceText` passthrough** (P2) — Trivial one-line removal.
6. **Add `postureLabel` getter to `_DashboardTriageSummary`** (P2 duplication) — Tiny
   but closes a silent divergence point.
7. **Add unit tests for signal/dispatch parsing and trend methods** (coverage gaps) —
   Locks the parsing contract before any further signal types are added.
8. **Zaks decision on desktop `_ExecutiveSummary` suppression** (P3 / DECISION) —
   Needs a product call before any implementation.
