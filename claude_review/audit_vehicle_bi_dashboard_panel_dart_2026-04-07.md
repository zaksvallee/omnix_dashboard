# Audit: vehicle_bi_dashboard_panel.dart

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/ui/vehicle_bi_dashboard_panel.dart`, `test/ui/vehicle_bi_dashboard_panel_test.dart`
- Read-only: yes

---

## Executive Summary

The panel is clean, purely presentational, and correctly stateless. It has no async work, no domain logic, and no lifecycle misuse. Risk is low. The main concerns are: a minor data-integrity gap in the repeat-rate calculation, a bar chart that silently renders broken for large hour sets, untested model fields that the model exposes but the panel ignores, and a redundant wrapping `Column` in `_VehicleBiFunnel`. Test coverage is shallow — one happy-path test and one empty-state test — leaving several boundary cases unverified.

---

## What Looks Good

- Purely `StatelessWidget` throughout — no state management, no async, no lifecycle exposure.
- `ValueKey` tags on every interactive element make widget-test targeting unambiguous.
- `math.max(1, …)` guards prevent divide-by-zero in both the hourly chart and the funnel, which is the correct pattern.
- `hourlyEntries` sort is correct and applied with `growable: false` (no allocation waste on re-sort).
- `_VehicleBiSectionCard` and `_VehicleBiEmptyState` are appropriately extracted; they would be reusable if promoted.
- `FractionallySizedBox` + `ratio.clamp(0.0, 1.0)` for funnel progress bars is safe and correct.

---

## Findings

### P1 — Repeat rate denominator uses `uniqueVehicles`, not `totalVisits`, but that is semantically ambiguous

- **Action: REVIEW**
- The repeat rate formula on line 20–22 divides `repeatVehicles / uniqueVehicles`. If a plate is counted in `repeatVehicles` but also in `uniqueVehicles` (i.e. `uniqueVehicles` is a set-size not a visit-count), then the denominator can equal `repeatVehicles`, capping the display at 100% while still showing a meaningful number. However, if `repeatVehicles > uniqueVehicles` is ever possible (e.g., due to a service pipeline bug that double-counts), the displayed percentage silently exceeds 100%.
- No guard exists for `repeatVehicles > uniqueVehicles`.
- **Evidence:** `vehicle_bi_dashboard_panel.dart:20–22`
- **Suggested follow-up:** Codex to verify the invariant `repeatVehicles <= uniqueVehicles` is enforced upstream in `_buildVehicleThroughput` (`morning_sovereign_report_service.dart:2173`). If not enforced there, a `.clamp(0.0, 100.0)` on the display value is the minimal safe fix.

---

### P2 — Bar chart height is fixed at 108 px; no minimum bar height for non-zero values

- **Action: AUTO**
- In `_VehicleBiHourlyChart` (line 267), bar height is `108 * (entry.value / maxValue)`. For a very large set of hours (24 hours all with value 1), every bar renders at `108 * (1/1) = 108` px — correct. But for a distribution like `{8: 1, 9: 100}`, the hour-8 bar renders at `108 * 0.01 = 1.08 px`, which is visually invisible yet has a value label `'1'` floating above nothing.
- There is no minimum bar height for non-zero values (e.g., `math.max(4.0, …)` is common practice).
- **Evidence:** `vehicle_bi_dashboard_panel.dart:267`
- **Suggested follow-up:** Codex to add `math.max(entry.value > 0 ? 4.0 : 0.0, 108 * (entry.value / maxValue))` to the bar height expression.

---

### P3 — `_VehicleBiFunnel` wraps its `Row` in a redundant `Column`

- **Action: AUTO**
- `_VehicleBiFunnel.build` returns a `Column` with a single `Row` child (lines 313–349). The `Column` serves no purpose here — it adds one extra layout pass with no structural justification.
- **Evidence:** `vehicle_bi_dashboard_panel.dart:313–349`
- **Suggested follow-up:** Codex to replace the `Column` wrapper with the bare `Row` directly.

---

### P4 — `scopeBreakdowns` and `exceptionVisits` are silently ignored by the panel

- **Action: DECISION**
- `SovereignReportVehicleThroughput` exposes `scopeBreakdowns` (per-zone breakdown) and `exceptionVisits` (suspicious/loitering visits) as structured lists, but `VehicleBiDashboardPanel` does not render them. `suspiciousShortVisitCount` and `loiteringVisitCount` are also in the model but not surfaced in any metric card.
- This is either intentional (phased UI build) or an oversight that leaves security-relevant exception data invisible.
- **Evidence:** `morning_sovereign_report_service.dart:1116–1117`; `vehicle_bi_dashboard_panel.dart:55–105` (no reference to these fields)
- **Suggested follow-up:** Zaks to decide whether exception visits and scope breakdowns should be surfaced in a follow-on section. If intentionally deferred, add a `// TODO: surface exceptionVisits` comment to track intent.

---

### P5 — Bar chart label `'${entry.value}'` and funnel value `'$value'` duplicate display logic

- **Action: AUTO** (minor)
- Both `_VehicleBiHourlyChart` (line 257) and `_VehicleBiFunnelStage` (line 389) format integer counts as raw `'$value'` strings inline. This is fine now, but if number formatting ever needs localization (e.g., `1,234` for thousands), there are two separate sites to update rather than one.
- **Evidence:** `vehicle_bi_dashboard_panel.dart:257, 389`
- **Suggested follow-up:** Low priority. Acceptable as-is; flag only if locale formatting becomes a requirement.

---

## Duplication

- **`_VehicleBiMetricCard` and `_VehicleBiFunnelStage`** share the same visual container shell: white/`F8FBFF` background, `D7E2EE` border, rounded corners, `Inter` label + value text hierarchy. The difference is the accent dot vs the progress bar footer. If a third card type is added, this pattern should be abstracted into a shared card shell.
- **Files involved:** `vehicle_bi_dashboard_panel.dart:108–178` and `353–416`
- **Centralization candidate:** A `_VehicleBiCard` base shell with a `footer` slot slot would unify both.

---

## Coverage Gaps

1. **No test for `repeatRate` display when `repeatVehicles > uniqueVehicles`** — verifying whether the value clamps or overflows is untested.
   - `vehicle_bi_dashboard_panel_test.dart` — no such case exists.

2. **No test for single-bucket hourly breakdown** — a single entry `{10: 5}` should produce one bar at full height (108 px via `maxValue = 5`). Not tested.

3. **No test for a very skewed hourly distribution** — validates the sub-pixel bar issue (P2 above). Not tested.

4. **No test verifying funnel `peakCount` logic when all counts are 0** — the `math.max(1, …)` guard is correct but not covered by a test where `entryCount = serviceCount = exitCount = 0`. The empty-state test uses a zero-visit throughput but does not inspect funnel ratio values.

5. **No test verifying `scopeLabel` defaults to `'Current shift'`** — the default parameter is set but never asserted in any test.
   - `vehicle_bi_dashboard_panel.dart:16`; `vehicle_bi_dashboard_panel_test.dart` — absent.

6. **`_VehicleBiSectionCard` title rendering** — the section card title `'Hourly bar chart'` is never explicitly asserted in tests; only `'Entry -> Service -> Exit funnel'` is checked.

---

## Performance / Stability Notes

- **No performance concerns.** The widget tree is shallow and fully static. `SingleChildScrollView` wraps a small, bounded list.
- **Bar chart re-sorts on every `build`** — `hourlyEntries` is re-sorted on every rebuild of the parent (`vehicle_bi_dashboard_panel.dart:24–26`). Since `throughput` is passed as an immutable value object, the sort is correct but redundant if the parent rebuilds frequently. For a BI summary panel this is inconsequential, but it is worth noting. The `toList(growable: false)` allocation is already minimal.
- **`GoogleFonts.inter(…)` is called inline on every build** — this is the standard Flutter pattern for `GoogleFonts` and is acceptable for a panel that rebuilds rarely. Not a concern here.

---

## Recommended Fix Order

1. **(P1 — REVIEW)** Verify `repeatVehicles <= uniqueVehicles` invariant upstream; add clamp or upstream guard.
2. **(P2 — AUTO)** Add minimum bar height for non-zero hourly buckets in `_VehicleBiHourlyChart`.
3. **(P3 — AUTO)** Remove the redundant `Column` wrapper in `_VehicleBiFunnel`.
4. **(Coverage)** Add tests for: zero-funnel all-zeros path, single-bucket chart, `scopeLabel` default, skewed distribution.
5. **(P4 — DECISION)** Decide whether `exceptionVisits` / `suspiciousShortVisitCount` / `loiteringVisitCount` belong in a follow-on panel section.
6. **(Duplication)** Card shell abstraction — low priority, only worth doing if a third card variant is added.
