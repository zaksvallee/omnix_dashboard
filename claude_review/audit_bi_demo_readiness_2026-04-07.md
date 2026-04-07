# Audit: BI Demo Readiness — Pharmaceutical Wholesaler Context

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `test/fixtures/carwash_bi_demo_report.json`, `lib/ui/vehicle_bi_dashboard_panel.dart`, `lib/ui/governance_page.dart` (drill-in wiring), `test/application/carwash_bi_demo_fixture_test.dart`, `test/ui/vehicle_bi_dashboard_panel_test.dart`
- Read-only: yes

---

## Executive Summary

The vehicle BI stack is **structurally sound** but **not ready for a pharmaceutical wholesaler demo today**. The domain model, projection pipeline, and panel widget are all functional. The three-card metric summary, hourly bar chart, and Entry→Service→Exit funnel render correctly with the carwash fixture. The governance drill-in path is correctly wired.

What undermines a live demo:

1. **The most compelling demo content — the two loitering exception events — is invisible.** `VehicleBiDashboardPanel` does not render `exceptionVisits` at all. The panel shows aggregate counts only.
2. **The fixture has three data contradictions** that an alert observer will notice immediately (ACTIVE vehicles last seen 4–6 hours before shift end; `suspiciousShortVisitCount: 3` with only 2 exception entries; `knownIdentitySignals: 0` vs `repeatVehicles: 10`).
3. **The fixture vocabulary is carwash-specific**. Zone labels (`Wash Bay 1`), posture narrative (`weekend wash-bay queueing`), and shift timing (`Saturday`) read as carwash context. A pharma wholesaler needs to mentally remap everything — which breaks demo flow.

With targeted fixes to the fixture and one panel addition (exception event list), this becomes a strong demo. Estimated surface area: small.

---

## 1. Fixture Assessment — Is the Carwash BI Demo Compelling and Complete?

### What Works Well

- **Hourly bell curve is immediately readable.** Values `2→4→6→12→10→5→3→2→2→1` (07:00–16:00) are realistic and will render as a clean visual arc on the bar chart. A business owner will recognise it as their own busy morning.
- **Internal arithmetic is clean.** Total visits 47 = entry 47 = completed 41 + active 4 + incomplete 2. Hourly sum = 47. Funnel entry/service/exit counts (47/43/41) are self-consistent.
- **Two loitering exception entries are well-formed.** Zone labels, workflow summaries, score reasons, and timestamps are all populated. These are the strongest story assets in the fixture — if they were visible in the panel.
- **AI:human override ratio (8:1) is believable.** 12.5% override rate signals a system that is working without over-asking for human input.
- **`normDrift.avgMatchScore: 98.1` with zero drift** sends a clean "stable, well-calibrated site" signal.
- **`complianceBlockage` all-zero** is appropriate. A carwash has no PSIRA/PDP complexity, and zero-blocked reads as clean rather than missing data.

### What Is Broken or Missing

| Issue | Severity | Demo Risk |
|---|---|---|
| `receiptPolicy` block is entirely empty (all zeros / empty strings) | P1 | Renders as a dead section if any governance panel iterates this block |
| `suspiciousShortVisitCount: 3` but only 2 exception entries | P1 | Count contradicts list; a viewer who asks "show me those 3" sees nothing |
| Both loitering vehicles `statusLabel: ACTIVE` with last-seen timestamps 4–6 hrs before shift end | P1 | Reads as a tracking fault unless explained |
| `knownIdentitySignals: 0` vs `repeatVehicles: 10` | P2 | These two numbers tell opposite stories about whether identity recognition works |
| `partnerProgression` all-zero with empty headline strings | P2 | Renders as a broken/unfinished feature rather than a quiet-shift signal |
| No revenue proxy anywhere | P3 | A business owner anchors on money; no estimated revenue figure leaves the story abstract |

**Previous audit (`audit_carwash_fixture_2026-04-07.md`) identified all six of these.** Based on the fixture file state as of this audit, none have been resolved.

### Fitness for a Pharmaceutical Wholesaler

The fixture is **not directly usable** for a pharma wholesaler demo. Every domain-specific string in the fixture is carwash vocabulary:

- Zone labels: `Wash Bay 1`, `Entry Lane`, `Exit Lane`
- Posture narrative: `"weekend wash-bay queueing"`, `"Saturday peak queueing at Wash Bay 1"`
- Shift context: Saturday, 10-hour window, recreational-traffic pattern
- Executive summary: `"Saturday throughput peaked between 10:00 and 12:00 as the entry lane fed Wash Bay 1 continuously"`

A pharmaceutical wholesaler's operational vocabulary would use: `Receiving Bay`, `Loading Dock`, `Controlled Access`, `Supplier Fleet`, `Cold Chain Delivery`, `Dispensary Gate`. Their peak window is weekday mornings (07:00–10:00), not Saturday midday. Their average delivery dwell (30–90 min) is two to six times the carwash dwell (14.6 min).

**If used as-is, the demo requires constant verbal translation** ("imagine this says Receiving Bay instead of Wash Bay 1"), which erodes credibility and flow. The platform story is sound; the asset is wrong for the audience.

A pharma-specific fixture is not a large build — it reuses the same JSON schema and the same test harness. It needs different zone labels, a weekday timeline, higher dwell values, and a narrative framing around supply chain gate control and cold chain delivery timing rather than wash throughput.

---

## 2. VehicleBiDashboardPanel — Is It Rendering All Key Metrics?

### What Renders

| Metric | Widget | Key |
|---|---|---|
| Total vehicles (with unique count) | `_VehicleBiMetricCard` | `vehicle-bi-total-vehicles-card` |
| Average dwell time (with completed visits) | `_VehicleBiMetricCard` | `vehicle-bi-average-dwell-card` |
| Repeat customer rate (computed, with repeat count) | `_VehicleBiMetricCard` | `vehicle-bi-repeat-rate-card` |
| Hourly bar chart (all hours, sorted) | `_VehicleBiHourlyChart` | Per-hour keys `vehicle-bi-hour-bar-{h}` |
| Entry → Service → Exit funnel with ratio bars | `_VehicleBiFunnel` | `vehicle-bi-funnel-entry/service/exit` |
| Empty hourly state | `_VehicleBiEmptyState` | — |

### What Is NOT Rendered — Demo-Critical Gaps

**`exceptionVisits` — the most critical omission for a live demo.**

`SovereignReportVehicleThroughput.exceptionVisits` carries the full list of flagged vehicle events: vehicle label, zone trail, score reason, first/last seen timestamps, workflow summary, and score label (`WATCH`/`ALERT`). In the carwash fixture this is the two loitering vehicles — the visceral demo moment that shows the AI catching something a human missed. This list is passed into `VehicleBiDashboardPanel` as part of `throughput` but is silently ignored.

- **Evidence:** `vehicle_bi_dashboard_panel.dart:8–106` — no reference to `exceptionVisits`, `loiteringVisitCount`, or `suspiciousShortVisitCount` anywhere in the widget tree.
- **Demo consequence:** The business owner sees "47 visits, 14.6 min dwell, 27% repeat rate" but never sees "we caught a vehicle loitering for 45 min at Wash Bay 1 during your morning peak." The most compelling piece of content is invisible.

**`loiteringVisitCount` and `suspiciousShortVisitCount` not in any metric card.**

Both are present on the model. Neither is surfaced. In the carwash fixture: `loiteringVisitCount: 2`, `suspiciousShortVisitCount: 3`. For a pharma wholesaler these would map to "vehicles that lingered at the receiving bay" and "drive-offs without completing intake" — direct security and compliance stories. Currently invisible.

**`peakHourLabel` / `peakHourVisitCount` not shown inside the panel body.**

The peak hour is used only in the dialog subtitle (`scopeLabel`) at the governance-page level (`governance_page.dart:11874`), not rendered inside the panel itself. A viewer who opens the panel and scrolls past the subtitle will miss it. Adding a fourth metric card for peak hour would complete the summary row naturally.

**`activeVisits` / `incompleteVisits` not surfaced.**

`activeVisits: 4` (vehicles still on-site at shift end) and `incompleteVisits: 2` (vehicles that entered but never completed) are operationally important — especially for a pharma wholesaler where an "active" delivery vehicle at shift end may signal a compliance gap. Neither is rendered.

**`workflowHeadline` not shown within the panel.**

Used in the dialog subtitle fallback but not inside the panel body. For a pharma context, a headline like "41 completed deliveries, 2 still in receiving bay" is a natural panel header.

---

## 3. Governance Drill-In Wiring

### What Is Wired Correctly

- **Trigger path is clean.** `_reportMetric` at `governance_page.dart:4965-4977` has key `governance-metric-vehicle-throughput`, correct label and value, and an `onTap` that calls `_showVehicleBiDashboardDrillIn(report)`. No guard conditions, no dead-code path.
- **Dialog passes the full throughput object.** `_showVehicleBiDashboardDrillIn` at line 11858 passes `report.vehicleThroughput` directly to `VehicleBiDashboardPanel`. All exception, scope, and hourly data flows through correctly — they are simply not rendered by the panel.
- **Subtitle is contextually set.** `scopeLabel: '${report.reportDate} • ${report.vehiclePeakHourLabel}'` at line 11874 gives the dialog a meaningful date + peak-hour subtitle rather than the default "Current shift".
- **Dialog sizing is appropriate.** `maxWidth: 760, maxHeight: 720` at line 9941 is workable on a demo laptop. The panel uses `SingleChildScrollView` so content longer than 720px is scrollable.
- **`_GovernanceReportView` propagates all required fields.** Lines 13098–13111 show the complete vehicle throughput mapping from `SovereignReport` to `_GovernanceReportView`. No fields are dropped.

### Structural Risks in the Drill-In

**`VehicleBiDashboardPanel` inside `Expanded` inside a `Column` in the dialog.**

At `governance_page.dart:11871–11876`, the panel is wrapped in `Expanded` which constrains height to whatever the dialog `Column` leaves after the title/subtitle row. This is correct Flutter layout — `SingleChildScrollView` inside `Expanded` is the standard bounded-scroll pattern. No crash risk.

**No `scopeLabel` override for pharma context.**

The `scopeLabel` is hardcoded to `'${report.reportDate} • ${report.vehiclePeakHourLabel}'`. For a carwash fixture this reads `"2026-04-04 • 10:00-11:00"`. For a pharma demo, this remains meaningful date + peak-window information — no change needed structurally, but the fixture date and peak hour should reflect pharma hours.

**`Partner Progression` tile has no `onTap`.**

At `governance_page.dart:4979–4997`, the Partner Progression metric is rendered with no `onTap` handler (unlike Vehicle Throughput which has one). In the carwash fixture, `partnerProgression` is all-zeros. The tile will show "0 dispatches" with no drill-in capability. For a carwash or pharma demo where no armed response is dispatched, this reads as a dead/broken feature. The fixture's `partnerProgression` block needs at least a `workflowHeadline` string to signal "no dispatch required" rather than silence.

---

## 4. What Would Break or Look Bad in a Live Demo

Ranked by impact:

### Demo-Killer

**P1 — Exception events are not visible.**
The fixture's two loitering vehicles (ND456783, GP128440) are the single most visceral demo moment in the entire dataset. They are not rendered anywhere in `VehicleBiDashboardPanel`. A demo presenter clicking into "Vehicle Throughput" will see metrics and charts but no anomalies — the AI story is absent.
- Evidence: `vehicle_bi_dashboard_panel.dart:55–105` — no `exceptionVisits` reference.
- Action: DECISION — Zaks to decide whether a scrollable exception event list belongs at the bottom of the panel.

**P1 — ACTIVE loitering vehicles last-seen 4–6 hours before shift end.**
ND456783 last seen 09:43, GP128440 last seen 11:22, shift window closes 16:00. Both marked `ACTIVE`. Any sharp observer asks: "why is this vehicle still active if it was last seen at 9:43?" No answer exists in the fixture. For a pharma demo, this looks like a tracking fault — exactly the kind of credibility issue that kills a live demo.
- Evidence: `carwash_bi_demo_report.json:127–128`, `143–144`
- Action: REVIEW

### Likely to Get a Question

**P2 — `suspiciousShortVisitCount: 3` with only 2 exception entries.**
The summary line says "Short visits 3". If any widget surfaces the summary line AND exception visits, the count and the list contradict. More likely: a presenter who mentions the short visits is asked to show them and cannot.
- Evidence: `carwash_bi_demo_report.json:94` (summaryLine), lines 119–150 (2 exception entries).
- Action: REVIEW

**P2 — `knownIdentitySignals: 0` vs `repeatVehicles: 10`.**
These two metrics tell opposite stories. `knownIdentitySignals: 0` says no signal was from a known identity. `repeatVehicles: 10` says 10 vehicles were recognised as having visited before. A technically-aware prospect will notice. For a pharma wholesaler, known supplier fleets are central to the value proposition — having `knownIdentitySignals: 0` actively undermines that story.
- Evidence: `carwash_bi_demo_report.json:35`, line 86.
- Action: REVIEW

**P2 — Partner Progression tile shows "0 dispatches" with no headline.**
Without a `workflowHeadline`, the tile detail fallback resolves to `"Accept 0 • On site 0 • All clear 0"`. For a pharma prospect this reads as: either the platform does not dispatch, or this section is not ready. A one-line headline ("No dispatch required this shift") converts the dead tile into a positive signal.
- Evidence: `governance_page.dart:4979–4997`, `carwash_bi_demo_report.json:152–166`.
- Action: AUTO

### Visual / Polish

**P3 — `receiptPolicy` block is all-empty.**
All strings are `""` and all counts are `0`. If the governance page renders a receipt policy summary card, it will display as blank. Lower impact if the demo stays on the BI drill-in, but visible if the overview card row is walked through.
- Evidence: `carwash_bi_demo_report.json:55–76`.
- Action: REVIEW

**P3 — Bar chart has no minimum bar height for non-zero buckets.**
In the current fixture, the hour-16 bar has value 1 against a peak of 12. Rendered height = `108 × (1/12) = 9 px`. Barely visible but not zero. Acceptable with the carwash data. Would become a visual problem if any hour had value 1 against a peak of 50+.
- Evidence: `vehicle_bi_dashboard_panel.dart:267`.
- Action: AUTO (previously flagged)

---

## 5. What 3 Things Would Make the Biggest Impression on a Business Owner

### 1. Anomaly Exception List with Zone Trail

**Render `exceptionVisits` as a scrollable event list at the bottom of `VehicleBiDashboardPanel`.** Each entry should show: vehicle label, zone trail (`ENTRY → WASH BAY 1 (ACTIVE)`), first-seen / last-seen timestamps, and the AI score reason in plain language.

For the carwash fixture this surfaces:
- _"Vehicle ND456783 entered at 08:58, still at Wash Bay 1 at 09:43 — 45 minutes, flagged as WATCH. Bay blockage during pre-peak ramp."_
- _"Vehicle GP128440 held the exit lane from 10:36 to 11:22 during your peak hour — 46 minutes, flagged as WATCH."_

For a pharma wholesaler, these become:
- _"Supplier truck held the receiving bay for 2h40m — cold chain compliance window exceeded."_
- _"Unknown vehicle lingered at the dispensary gate for 38 minutes without completing intake."_

This is the single item with the highest business-owner impact. It shows the AI catching something a human might miss, with a legible explanation, without requiring any technical literacy.

### 2. Annotated Peak-Hour Bar Chart

**Add a visual peak-hour annotation to `_VehicleBiHourlyChart`** — a highlighted bar (different gradient), a label (`"Peak"` or the count `"12"` in a contrasting colour), or a horizontal reference line.

The raw bar chart is already good. The annotation turns it from "here is a chart" into "here is your busiest hour, this is when you needed more staff / more receiving bays / more gate capacity." This converts a descriptive display into an actionable operational insight in two seconds of looking.

For the carwash data: peak bar at 10:00 highlighted. For pharma: peak bar at 07:00 highlighted with a "supplier fleet arrives" callout.

### 3. Repeat Customer Rate as a Loyalty / Relationship KPI (reframed for pharma)

**Elevate the repeat-rate metric card with a context label.** Instead of just "27.0%" with "10 repeat vehicles", add a framing line: `"Recognised supplier fleet"` or `"Known repeat visitors"`.

For a carwash, 27% is a loyalty story — regulars are coming back. For a pharma wholesaler, known repeat vehicles are the supplier fleet: the trusted delivery partners the business relies on daily. Framing this as "27% of today's vehicles are known to the system" immediately signals that the platform builds an institutional memory of who belongs at the site — a direct access control and relationship-management story.

This requires only a label change in the metric card detail text, not a new data field. The `scopeLabel` prop or a new `contextLabel` on the metric card would be sufficient.

---

## Findings Summary

### P1

| # | Action | Finding | Evidence |
|---|---|---|---|
| 1 | DECISION | `exceptionVisits` not rendered in `VehicleBiDashboardPanel` — anomaly events are invisible | `vehicle_bi_dashboard_panel.dart:55–105` |
| 2 | REVIEW | Loitering vehicles marked `ACTIVE` with last-seen timestamps 4–6 hrs before shift end | `carwash_bi_demo_report.json:127–128, 143–144` |

### P2

| # | Action | Finding | Evidence |
|---|---|---|---|
| 3 | REVIEW | `suspiciousShortVisitCount: 3` with only 2 exception entries — count contradicts list | `carwash_bi_demo_report.json:94, 119–150` |
| 4 | REVIEW | `knownIdentitySignals: 0` vs `repeatVehicles: 10` — these tell opposite identity stories | `carwash_bi_demo_report.json:35, 86` |
| 5 | REVIEW | `loiteringVisitCount` and `suspiciousShortVisitCount` not in any metric card | `vehicle_bi_dashboard_panel.dart:55–105` |
| 6 | REVIEW | `peakHourLabel` / `peakHourVisitCount` not rendered inside panel body | `vehicle_bi_dashboard_panel.dart:55–105` |
| 7 | AUTO | `partnerProgression` has no `workflowHeadline` — renders as "Accept 0 • On site 0 • All clear 0" | `carwash_bi_demo_report.json:152–166` |

### P3

| # | Action | Finding | Evidence |
|---|---|---|---|
| 8 | REVIEW | Fixture vocabulary is carwash-specific — pharma demo requires separate fixture | `carwash_bi_demo_report.json` throughout |
| 9 | REVIEW | `receiptPolicy` block is all-empty — dead section if rendered in governance overview | `carwash_bi_demo_report.json:55–76` |
| 10 | AUTO | Bar chart has no minimum bar height for non-zero buckets (previously flagged) | `vehicle_bi_dashboard_panel.dart:267` |
| 11 | REVIEW | No revenue proxy in fixture — business owners anchor on money, not visit counts | `carwash_bi_demo_report.json` — absent field |

---

## Coverage Gaps

- No test exercises `exceptionVisits` rendering in `vehicle_bi_dashboard_panel_test.dart` — because the panel doesn't render them yet. When added, test coverage must cover: zero exceptions, one exception, loitering vs short-visit type distinction.
- No test asserts `loiteringVisitCount` or `suspiciousShortVisitCount` appear in the rendered panel.
- No pharma-specific fixture test exists. A `pharma_bi_demo_fixture_test.dart` mirroring the carwash test would lock the pharma fixture's parse contract before demo day.

---

## Recommended Fix Order

1. **(P1 — DECISION)** Decide whether `exceptionVisits` should be rendered in a new panel section, and if so, what the layout looks like — scrollable card list with zone trail and score reason. This is the single change with the highest demo impact.
2. **(P1 — REVIEW)** Fix the two loitering visit statuses/timestamps in the carwash fixture — either resolve to `RESOLVED` with a manager-action timestamp, or update `lastSeenAtUtc` to near shift-end.
3. **(P2 — REVIEW)** Add `suspiciousShortVisitCount` and `loiteringVisitCount` as a fourth or fifth metric card row, or add a security-summary card below the funnel.
4. **(P2 — AUTO)** Add `workflowHeadline: "No dispatch required this shift"` to `partnerProgression` in the fixture.
5. **(P2 — REVIEW)** Add a peak-hour annotation to the hourly bar chart.
6. **(P3 — REVIEW)** Build a `pharma_bi_demo_report.json` fixture using pharma zone vocabulary, weekday morning peak, higher dwell values, and a cold-chain delivery narrative. Reuse the same JSON schema — no model changes needed.
7. **(P3 — REVIEW)** Reconcile `knownIdentitySignals: 0` with `repeatVehicles: 10` in the fixture.
8. **(P3 — REVIEW)** Populate `receiptPolicy` with plausible strings or remove it from the demo fixture entirely.
9. **(P3 — AUTO)** Add minimum bar height for non-zero buckets in `_VehicleBiHourlyChart` (previously flagged as P2 AUTO in `audit_vehicle_bi_dashboard_panel_dart_2026-04-07.md`).
