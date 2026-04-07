# Audit: Business Intelligence Foundation — Carwash / Filling Station PoC Readiness

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: All BI, analytics, and traffic-counting code in `lib/` — vehicle counting, dwell time, foot traffic, repeat visitor, license plate, zone analytics
- Read-only: yes

---

## Executive Summary

The codebase has a **well-formed vehicle BI engine** that is substantially ready for a carwash or filling station proof of concept. The domain model, projection logic, dwell calculation, zone classification, repeat-visitor tracking, peak-hour computation, and exception detection are all implemented and tested. What is entirely absent is any **visual rendering layer** for these analytics — all computed data is surfaced only as text summary lines, never as charts, funnels, or drill-in panels. The gap between "data exists" and "BI demo is live" is primarily a UI build task, not a data pipeline task. The fastest path to a working demo is exposing existing `SovereignReportVehicleThroughput` data through new visual widgets rather than building a new pipeline.

---

## What Looks Good

- **`VehicleVisitLedgerProjector`** (`lib/application/vehicle_visit_ledger_projector.dart`) is a clean, pure-function projector. It merges per-plate events into visit records, classifies zone stages, computes dwell, detects repeat vehicles, loitering, suspicious short visits, and peak hour. No I/O, no side effects — easy to test and extend.

- **Zone classification** already covers carwash vocabulary: `wash`, `bay`, `service`, `vacuum`, `processing`, `queue` → `service` stage; `boom in`, `arrival lane`, `ingress` → `entry`; `boom out`, `exit lane`, `egress` → `exit`. No schema changes needed for a carwash pilot.

- **`SovereignReportVehicleThroughput`** (`lib/application/morning_sovereign_report_service.dart:1097`) is a fully serialisable domain model with per-scope breakdowns (`scopeBreakdowns`) and flagged exception visits (`exceptionVisits`). JSON round-trip is in place.

- **`SiteActivityIntelligenceService`** (`lib/application/site_activity_intelligence_service.dart`) provides person + vehicle signal counts, flagged identity detection, long-presence aggregation, and guard interaction detection from the same `IntelligenceReceived` event stream. Covers foot-traffic and perimeter-dwell analytics.

- **`MoOntologyService`** (`lib/application/mo_ontology_service.dart:157`) already classifies `petrol_station` as an environment type and maps `loitering` at a forecourt to the `public_forecourt_dwell` behaviour pattern. Context-aware classification is wired in.

- **`VehicleVisitReviewRecorded`** domain event + human-review flow in governance page means operators can annotate vehicle exceptions — a trust-building feature important for any client-facing BI demo.

- **Two test files** cover the projector and formatter with realistic zone/plate inputs including carwash zone labels (`Wash Bay 1`, `Entry Lane`, `Exit Lane`).

---

## Findings

### P1 — Hourly breakdown data is computed then silently discarded

- **Action:** REVIEW
- **Finding:** `_buildVehicleThroughput` in `morning_sovereign_report_service.dart` builds `visitsByHour: <int, int>{}` (line 2178) and uses it to compute `peakHourLabel` and `peakHourVisitCount`, but the full hourly map is **never stored on `SovereignReportVehicleThroughput`**. Only the single peak hour survives.
- **Why it matters:** A per-hour bar chart is the single most compelling visual for a carwash BI demo — it shows busy times at a glance. The data is computed and then thrown away. Adding `hourlyBreakdown: Map<int, int>` to `SovereignReportVehicleThroughput` is a one-field addition; the computation is already done.
- **Evidence:** `lib/application/morning_sovereign_report_service.dart:2178-2222`, `lib/application/morning_sovereign_report_service.dart:1097-1246`
- **Suggested follow-up for Codex:** Add `final Map<int, int> hourlyBreakdown` to `SovereignReportVehicleThroughput`, populate it from `visitsByHour` in `_buildVehicleThroughput`, and include it in `toJson`/`fromJson`.

---

### P1 — No dedicated BI / analytics page exists

- **Action:** DECISION
- **Finding:** Vehicle throughput data is surfaced in two places only: a single `_RailMetricRow` text line in `dashboard_page.dart:4418-4432` and a single `_reportMetric` widget in `governance_page.dart:4959-4971`. Neither surface allows drill-in to individual visits, zone funnels, hourly bars, repeat-visitor lists, or dwell histograms.
- **Why it matters:** A carwash BI demo requires a client-facing view. An operator seeing "Visits 47 • Avg dwell 8.3m • Peak 09:00-10:00 (12)" in a metric pill is not a demo — it is a status badge. The data richness warrants a panel.
- **Evidence:** `lib/ui/dashboard_page.dart:4418-4432`, `lib/ui/governance_page.dart:4959-4971`
- **Suggested follow-up for Codex:** Zaks to decide placement — existing governance drill-in sheet vs. dedicated page under a new route. A `VehicleBiDashboardPanel` widget backed by `SovereignReportVehicleThroughput` and `VehicleVisitLedgerSnapshot` is the unit of work.

---

### P2 — Entry → Service → Exit funnel is computed but never visualised

- **Action:** REVIEW
- **Finding:** Every `VehicleVisitRecord` carries `sawEntry`, `sawService`, and `sawExit` booleans. The `SovereignReportVehicleThroughput` exposes aggregate `entryCount` / (no direct service count) / `exitCount` and `completedCount`. The funnel shape (how many enter, how many reach service, how many exit cleanly) is the core operational KPI for a carwash or filling station.
- **Why it matters:** Drop-off between entry and service (queue abandonment), between service and exit (blockage), and completedCount vs totalVisits (completion rate) are the metrics a carwash owner wants to see daily. Data exists; UI does not.
- **Evidence:** `lib/application/vehicle_visit_ledger_projector.dart:59-91`, `lib/application/morning_sovereign_report_service.dart:2254-2272`
- **Note:** `SovereignReportVehicleThroughput` currently exposes `completedVisits`, `activeVisits`, `incompleteVisits` but **not a raw `serviceCount`** (vehicles that reached the service zone). This is a one-aggregation gap.

---

### P2 — Repeat-visitor tracking exists but has no UI surface

- **Action:** REVIEW
- **Finding:** `VehicleThroughputSummary.repeatVehicles` (count of plates seen more than once) is populated at `lib/application/vehicle_visit_ledger_projector.dart:266`. `SovereignReportVehicleThroughput` carries `repeatVehicles`. Neither the dashboard nor governance page shows the actual repeat plates or their visit patterns.
- **Why it matters:** For a filling station demo, "loyal customer" identification — plates that appear 3+ times per week — is a direct business insight. The count exists; the per-plate breakdown does not.
- **Evidence:** `lib/application/vehicle_visit_ledger_projector.dart:221-227`, `lib/application/morning_sovereign_report_service.dart:2177-2191`
- **Suggested follow-up for Codex:** `vehicleVisitCount: Map<String, int>` in `_buildVehicleThroughput` (line 2177) could be exposed as `topRepeatPlates: List<({String plate, int visitCount})>` on the report model.

---

### P2 — Per-zone dwell breakdown does not exist

- **Action:** REVIEW
- **Finding:** Dwell is computed at visit level (entry-to-exit), not per zone stage. There is no way to determine how long a vehicle waited in the entry queue vs. how long it was in the wash bay vs. how long the exit took.
- **Why it matters:** For a carwash operator, bay dwell (service time) is distinct from queue wait time. Both are actionable. The `zoneLabels: List<String>` on `VehicleVisitRecord` captures which zones were seen, but no timestamps are retained per zone transition.
- **Evidence:** `lib/application/vehicle_visit_ledger_projector.dart:22-56`, `lib/application/vehicle_visit_ledger_projector.dart:365-450`
- **Note:** Fixing this requires changes to `_MutableVehicleVisit.absorb()` to record zone-entry timestamps. This is a schema change, not just a BI view change. Label as a **Phase 2** enhancement for a live demo.

---

### P3 — `SiteActivityIntelligenceService` long-presence threshold is hardcoded at 2 hours

- **Action:** AUTO
- **Finding:** `longPresenceSignals` is filtered at `>= Duration(hours: 2)` (`lib/application/site_activity_intelligence_service.dart:204`). For a carwash or filling station context, any presence over 15–30 minutes is anomalous. The threshold is not configurable.
- **Why it matters:** A filling station demo would want to surface "vehicle present 35 minutes at pump 3" — but the current threshold silently ignores it.
- **Evidence:** `lib/application/site_activity_intelligence_service.dart:204-212`
- **Suggested follow-up for Codex:** Add `Duration longPresenceThreshold = const Duration(hours: 2)` parameter to `buildSnapshot()`.

---

### P3 — No Supabase persistence for BI data; analytics are ephemeral

- **Action:** DECISION
- **Finding:** `VehicleThroughputSummary` and `SovereignReportVehicleThroughput` are computed in-memory from in-flight `DispatchEvent` objects. They are serialised to JSON via `MorningSovereignReportService` but only as part of the daily sovereign report blob (SharedPreferences / local file). There is no Supabase table for historical vehicle throughput data.
- **Why it matters:** A week-over-week or month-over-month BI view for a carwash client requires persisted daily summaries. A live demo built on the current stack can only show the current session's data.
- **Evidence:** `lib/application/morning_sovereign_report_service.dart:430-560`, `lib/infrastructure/` (no vehicle BI persistence file found)
- **Note:** For a PoC demo, synthetic fixture data loaded from a JSON file is a viable workaround. For production BI, a `vehicle_throughput_snapshots` Supabase table is needed.

---

## Duplication

### Zone classification logic duplicated in two places

- `VehicleVisitLedgerProjector._classifyZoneStage()` (`lib/application/vehicle_visit_ledger_projector.dart:312-353`) and `MoOntologyService` (`lib/application/mo_ontology_service.dart:157-329`) both classify environment and behaviour from free-text zone/headline/summary strings using independent keyword lists.
- The vehicle-zone keywords (`wash`, `bay`, `service`, `boom in`, `boom out`) in `_classifyZoneStage` are not derived from `MoOntologyService` — they are a parallel vocabulary.
- **Centralisation candidate:** A shared `ZoneClassifierContract` or extending `MoOntologyService` to emit `VehicleVisitZoneStage` would remove the divergence risk. Not urgent for PoC, but a maintenance hazard if carwash keywords evolve.

---

## Coverage Gaps

| Gap | File | Risk |
|-----|------|------|
| No test for `SovereignReportVehicleThroughput` serialisation round-trip | `morning_sovereign_report_service.dart` | `fromJson(toJson())` drift is untested; silent data loss on schema change |
| No test for `_buildVehicleThroughput` with multi-scope events | `morning_sovereign_report_service.dart` | Cross-scope aggregation (line 2164-2209) not covered |
| No test for `SiteActivityIntelligenceService.buildSnapshot()` | `site_activity_intelligence_service.dart` | Long-presence grouping, flagged-identity detection untested |
| No test for `VehicleVisitRecord.statusAt()` stale-after boundary | `vehicle_visit_ledger_projector.dart:40-51` | Off-by-one in `staleAfter` edge case |
| No test for plate normalisation with spaces/case variants | `vehicle_visit_ledger_projector.dart:308-310` | `CA 123 456` vs `ca123456` merge correctness |

---

## Performance / Stability Notes

- **`_buildVehicleThroughput` duplicates peak-hour computation** that `VehicleVisitLedgerProjector._buildSummary()` already performs. Both do the same `visitsByHour` fold. On large event streams this is double work. Not critical at current scale but worth noting.
  - Evidence: `vehicle_visit_ledger_projector.dart:253-264` vs `morning_sovereign_report_service.dart:2210-2222`

- **`VehicleVisitLedgerProjector.projectByScope()` iterates all events twice** — once to segment by scope (line 116-133) and once per scope to build visits (line 141-155). For a single-site filling station this is negligible. For multi-client deployments with thousands of daily events it may be worth a single-pass design.

---

## Fastest Path to a Working BI PoC — Carwash / Filling Station

The data pipeline is already built. The following tasks, in order, produce a demo:

### Step 1 — Expose hourly breakdown (1 model change, no new data fetch)
Add `hourlyBreakdown: Map<int, int>` to `SovereignReportVehicleThroughput` by retaining `visitsByHour` in `_buildVehicleThroughput`. Codex can action this as `AUTO`.

### Step 2 — Build `VehicleBiDashboardPanel` widget (new UI, no new services)
A stateless panel widget that accepts `SovereignReportVehicleThroughput` and renders:
- **Metric row:** totalVisits / completedVisits / averageCompletedDwellMinutes / uniqueVehicles / repeatVehicles
- **Hourly bar chart:** 24-slot horizontal bar using `hourlyBreakdown` — Flutter's `CustomPainter` or `fl_chart` (already available in ecosystem)
- **Funnel row:** Entry → Service → Exit counts as three labelled buckets with drop-off percentage
- **Exception list:** `exceptionVisits` rendered as a scrollable table (plate, dwell, reason)

No new Supabase queries. No new services. All data comes from `SovereignReportVehicleThroughput` already computed in `MorningSovereignReportService`.

### Step 3 — Wire into existing governance drill-in (no routing change)
The governance page already has `_showSiteActivityDrillIn(report)` (line 4957). A parallel `_showVehicleThroughputDrillIn(report)` on the existing "Vehicle Throughput" metric tap would open the `VehicleBiDashboardPanel` in a bottom sheet or side panel.

### Step 4 — Demo data fixture (if no live DVR for demo)
Add a fixture JSON file at `test/fixtures/carwash_vehicle_events.json` with 48 hours of synthetic `IntelligenceReceived` events covering a realistic carwash day (morning peak 08:00-10:00, lunchtime spike 12:00-13:00, afternoon steady). Feed through the existing projector. This is entirely self-contained.

### Step 5 — Configurable `longPresenceThreshold` in `SiteActivityIntelligenceService`
Drop threshold to 20 minutes for the demo site. Surfaces pump-blocking events that the 2-hour threshold currently hides.

---

## What Is Not Present (Confirmed Absent)

| Feature | Status |
|---------|--------|
| Vehicle counting chart / time-series visual | **Absent** — data exists, no rendering |
| Entry → Service → Exit funnel widget | **Absent** — booleans exist, no widget |
| Repeat visitor list / per-plate history | **Absent** — count exists, no list UI |
| Per-zone dwell breakdown | **Absent** — requires schema change |
| Foot traffic person count visual | **Absent** — `personSignals` exists, no chart |
| License plate lookup / history view | **Absent** — plate stored in events, no query surface |
| Historical / day-over-day comparison | **Absent** — no Supabase persistence layer |
| Carwash-specific KPIs (cars/hour, bay utilisation) | **Absent** — derivable from existing data |
| Filling-station KPIs (pump throughput, drive-off detection) | **Absent** — partial via suspiciousShortVisit |
| Heatmap / zone occupancy map | **Absent** |
| Dedicated BI page or route | **Absent** |

---

## Recommended Fix Order

1. **(REVIEW) Add `hourlyBreakdown` to `SovereignReportVehicleThroughput`** — one field, retain already-computed data, unblocks all chart work.
2. **(DECISION) Choose BI panel placement** — governance drill-in sheet vs. new page/route. Zaks decides.
3. **(AUTO) Make `longPresenceThreshold` configurable in `SiteActivityIntelligenceService`** — safe default-preserving change, improves filling-station relevance immediately.
4. **(REVIEW) Build `VehicleBiDashboardPanel`** — metric cards + hourly bar + funnel; Codex implements after #1 and #2 are resolved.
5. **(AUTO) Add `SovereignReportVehicleThroughput` JSON round-trip test** — guards against silent serialisation drift as model grows.
6. **(REVIEW) Add `topRepeatPlates` to throughput model** — expose `vehicleVisitCount` map as sorted repeat list for "loyal customer" widget.
7. **(DECISION) Supabase persistence for historical BI** — needed for production, not needed for PoC demo.
