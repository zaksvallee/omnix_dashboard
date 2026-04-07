# Audit: CRM Reporting Subsystem

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: `lib/domain/crm/reporting/` — all 18 files
- Read-only: yes

---

## Executive Summary

The reporting subsystem is architecturally clean: pure static projection functions, immutable value objects, no UI coupling, and a well-defined assembly pipeline. The domain model is solid.

However, several concrete bugs and logic inconsistencies exist. The most serious are: a confirmed mismatch between `breachedIncidents` count and the effective compliance calculation in `SLADashboardProjection`; a force-unwrap on a nullable `slaProfile` in the assembler; fabricated guard PII fields that appear in live reports; and a complete absence of tests for the entire subsystem (8 projection classes, 0 test files).

Three different `slaComplianceRate` formulas are in use across the subsystem, producing divergent results for the same client in the same period. Two different month-filtering strategies are used, creating a latent timezone fault.

---

## What Looks Good

- All projections are pure static functions — no side effects, no state, easy to test in isolation.
- `SLADashboardProjection` correctly excludes overridden breaches from weighted compliance via a Set-based deduplication pattern.
- `MonthlyReportProjection` correctly delegates to `SLADashboardProjection` for authoritative compliance (no reimplementation).
- `ReportBundleCanonicalizer` produces a stable, versioned JSON payload with schema-version gating (`>= 2`, `>= 3`) — good forward compatibility pattern.
- `IncidentEvent.fromJson` / `toJson` are symmetric and type-safe.
- `ReportBrandingConfiguration` has a clean `copyWith` / `fromJson` / `toJson` round-trip.

---

## Findings

### P1 — Confirmed Bug: `breachedIncidents` diverges from compliance calculation

- **Action: AUTO**
- `SLADashboardProjection` computes `compliancePercentage` by excluding overridden incidents from `breachWeight`. However, `breachedIncidents` is set to `breaches.length` — a raw count that includes overridden incidents.
- Callers reading `breachedIncidents` from `SLADashboardSummary` will see a higher breach count than the compliance formula reflects. A report showing "3 breaches, 100% compliance" is internally contradictory.
- **Evidence:** `sla_dashboard_projection.dart:67-68`
  ```dart
  final total = incidents.length;
  final breached = breaches.length;  // includes overridden breaches
  ```
  vs. compliance logic at lines 58-64 which excludes overrides.
- **Suggested follow-up:** Replace `breaches.length` with a count of incidents where `breaches.contains(id) && !overrides.contains(id)`.

---

### P1 — Confirmed Bug: Force-unwrap on nullable `slaProfile` in assembler

- **Action: REVIEW**
- `ReportBundleAssembler.build` line 62: `slaProfile: aggregate.slaProfile!` — force-unwraps a nullable field. The `ClientAggregate.rebuild` path does not guarantee a profile is present if the client's CRM event stream is incomplete or reordered.
- The fallback `ClientAggregate` (for `crmEvents.isEmpty`) correctly provides a synthetic profile. But for non-empty `crmEvents` where no profile creation event has been replayed, this throws a `StateError` at runtime.
- **Evidence:** `report_bundle_assembler.dart:62`
- **Suggested follow-up:** Codex should check whether `ClientAggregate.rebuild` can return a null profile; if so, apply the same synthetic fallback or throw a descriptive domain exception.

---

### P1 — Data Quality: Fabricated guard PII fields in live reports

- **Action: REVIEW**
- `DispatchPerformanceProjection` synthesizes `guardName: 'Guard $guardId'`, `psiraNumber: 'PSIRA-$guardId'`, and `rank: 'Officer'` from scratch. These fields appear in serialized reports via `ReportBundleCanonicalizer` and are presented as real data.
- For a security operations context, a PSIRA number is a regulatory credential. Fabricated PSIRA numbers in client-facing reports are a compliance risk.
- **Evidence:** `dispatch_performance_projection.dart:49-54`
- **Suggested follow-up:** Either source guard metadata from a proper guard domain model, or mark these fields as `unknown`/`unresolved` with a clear sentinel so consumers know they are not authoritative.

---

### P2 — Logic Inconsistency: Three different `slaComplianceRate` formulas

- **Action: REVIEW**
- Three paths compute compliance for the same conceptual metric:
  1. `SLADashboardProjection`: weighted by severity, overrides respected. Authoritative.
  2. `MonthlyReportProjection`: delegates to `SLADashboardProjection`. Correct.
  3. `MultiSiteComparisonProjection`: `1.0 - (totalSlaBreaches / totalIncidents)` — raw ratio, ignores severity weights, ignores overrides.
- The `SitePerformance.slaComplianceRate` value in the same `ReportBundle` can differ materially from the authoritative `MonthlyReport.slaComplianceRate` for the same client+month.
- **Evidence:**
  - `sla_dashboard_projection.dart:42-73` (weighted)
  - `multi_site_comparison_projection.dart:44-46` (raw ratio)
- **Suggested follow-up:** `MultiSiteComparisonProjection` should either call `SLADashboardProjection` per site or accept a pre-computed `SLADashboardSummary` per site. Requires a `SLAProfile` input.

---

### P2 — Logic Inconsistency: Two month-filtering strategies with timezone fault

- **Action: REVIEW**
- Most projections filter with `e.timestamp.startsWith(month)` (string prefix on raw timestamp string). `SLADashboardProjection` filters by DateTime range: `ts.isBefore(fromUtc) || ts.isAfter(toUtc)`.
- If a timestamp is stored as a local-time ISO string (e.g., `2026-03-31T22:00:00-05:00`), `startsWith("2026-03")` returns true and includes it in March counts. But `DateTime.parse(...).toUtc()` gives `2026-04-01T03:00:00Z`, which falls outside the March DateTime window in `SLADashboardProjection` and is excluded.
- Result: `totalSlaBreaches` in `MonthlyReport` can be higher than `breachedIncidents` in `SLADashboardSummary` for the same period — with no error surfaced.
- **Evidence:**
  - `monthly_report_projection.dart:16-18, 34-37` (startsWith filter)
  - `sla_dashboard_projection.dart:20-21` (DateTime range filter)
- **Suggested follow-up:** Normalise all timestamps to UTC at ingestion boundary. If that is already guaranteed, document it. If not, unify all filtering to one strategy.

---

### P2 — Edge Case: `delta()` returns 100.0 for first-month scenarios

- **Action: REVIEW**
- In `EscalationTrendProjection`, when `previous == 0` and `current > 0`, `delta()` returns `100.0`. This sentinel is used when there is simply no prior period (first month of service) — a case semantically different from "doubled from 1 to 2."
- The `EscalationTrend` model has no field to distinguish "no prior data" from "100% increase." Downstream consumers (UI, PDF renderer) cannot distinguish these cases.
- **Evidence:** `escalation_trend_projection.dart:35-38`
- **Suggested follow-up:** Add a `bool hasPreviousPeriod` or `bool isFirstMonth` field to `EscalationTrend`, or use `null` for delta when previous data is absent.

---

### P2 — Edge Case: `previousMonth` is caller-provided with no validation

- **Action: AUTO**
- `EscalationTrendProjection.build` and `ReportBundleAssembler.build` accept `previousMonth` as a caller-supplied string. There is no assertion that `previousMonth` is actually the calendar month before `currentMonth`. A caller could pass `previousMonth: "2025-01"` alongside `currentMonth: "2026-03"`, producing misleading MoM deltas.
- **Evidence:** `escalation_trend_projection.dart:8`, `report_bundle_assembler.dart:76-80`
- **Suggested follow-up:** Add a domain assertion or computed helper: `String previousMonthOf(String currentMonth)` that derives the prior month from the current month string, removing the caller's ability to pass an unrelated period.

---

### P2 — Logic: `totalEscalations` double-counts incidents that are both escalated and breached

- **Action: REVIEW**
- Both `MonthlyReportProjection` and `EscalationTrendProjection` count escalations as `incidentEscalated || incidentSlaBreached`. An incident that fires both `incidentEscalated` and `incidentSlaBreached` events is counted twice in `totalEscalations`.
- This may be intentional (treat breach as a separate escalation event) but the model has no documentation of this intent, and the count diverges from what a human would call "number of escalated incidents."
- **Evidence:**
  - `monthly_report_projection.dart:28-31`
  - `escalation_trend_projection.dart:12-17`
- **Suggested follow-up:** Clarify whether the intent is "event count" or "incident count." If incident count, deduplicate by `incidentId`.

---

### P3 — Logic: `incidentDetails` in assembler is not month-scoped

- **Action: AUTO**
- `ReportBundleAssembler.build` line 110: `incidentDetails = incidentEvents.map(...)` — no month filter. If the caller passes a multi-month event stream (e.g., loading 90 days for trend analysis), all events appear in `incidentDetails`, not just the reporting month.
- This also means `ReportBundleCanonicalizer` serialises and includes out-of-period incidents in the report JSON.
- **Evidence:** `report_bundle_assembler.dart:110-119`
- **Suggested follow-up:** Apply `where((e) => e.timestamp.startsWith(currentMonth))` before `.map(...)`.

---

### P3 — Crash Risk: `IncidentSeverity.values.firstWhere` without `orElse`

- **Action: AUTO**
- `SLADashboardProjection` line 27-29: `IncidentSeverity.values.firstWhere((s) => s.name == severityName)` with no `orElse`. If an event carries an unrecognised or future severity name, this throws a `StateError` and the entire projection crashes.
- **Evidence:** `sla_dashboard_projection.dart:27-29`
- **Suggested follow-up:** Add `orElse: () => IncidentSeverity.low` (or skip the event) with a log/warning.

---

### P3 — Month-end boundary: brittle DateTime arithmetic

- **Action: AUTO**
- `monthly_report_projection.dart:47-50`:
  ```dart
  final monthEnd = monthStart
      .add(const Duration(days: 32))
      .copyWith(day: 1)
      .subtract(const Duration(seconds: 1));
  ```
  This works but relies on `add(32 days)` always crossing the month boundary. For DST-aware DateTimes this is safe since the code uses `.toUtc()`. Still non-obvious and harder to audit.
- **Evidence:** `monthly_report_projection.dart:47-50`
- **Suggested follow-up:** Replace with `DateTime.utc(monthStart.year, monthStart.month + 1, 1).subtract(Duration(seconds: 1))` — handles month boundary explicitly. Note: Dart handles `month = 13` as January of next year.

---

### P3 — Hardcoded narrative strings in assembler

- **Action: DECISION**
- `supervisorAssessment`, `companyAchievements`, and `emergingThreats` in `ReportBundleAssembler` (lines 121-144) are hardcoded strings identical for every client and every month. They appear in serialised reports.
- This may be intentional scaffolding awaiting dynamic content, but it is currently producing reports with verbatim repeated assessments that do not reflect client-specific conditions.
- **Evidence:** `report_bundle_assembler.dart:121-144`
- **Suggested follow-up:** Product decision needed — either these become caller-supplied inputs, or they are generated from report data, or they are explicitly marked as template placeholders in the output.

---

### P3 — Hardcoded patrol constant without client-level configurability

- **Action: DECISION**
- `DispatchPerformanceProjection._expectedPatrolsPerCheckIn = 8` is a hardcoded class constant (line 9). All compliance percentages for all clients use this value.
- **Evidence:** `dispatch_performance_projection.dart:9`
- **Suggested follow-up:** Product decision — if patrol expectations vary by contract, this constant must be per-client configuration. If it is industry-standard and universal, document that clearly.

---

## Duplication

### Month-prefix filtering
- `e.timestamp.startsWith(month)` appears in: `escalation_trend_projection.dart:13`, `monthly_report_projection.dart:17,21`, `multi_site_comparison_projection.dart:10`.
- All three are structurally identical filter predicates.
- Centralization candidate: a shared `_isInMonth(String timestamp, String month) => timestamp.startsWith(month)` helper (or the DateTime-based `_isInMonth` already in `dispatch_performance_projection.dart:92-95`).
- Note: `DispatchPerformanceProjection._isInMonth` uses DateTime normalization; the others use string prefix. Unifying these also resolves the timezone fault.

### Escalation counting definition
- `incidentEscalated || incidentSlaBreached` appears verbatim in both `monthly_report_projection.dart:29-30` and `multi_site_comparison_projection.dart:34-35`.
- Centralization candidate: an extension method or static helper `IncidentEvent.isEscalationEvent`.

---

## Coverage Gaps

The entire reporting subsystem has **zero test files**. Every projection class is untested.

Priority test cases needed:

| Test | Class | Scenario |
|------|-------|----------|
| T1 | `EscalationTrendProjection` | Both months have data — verify MoM delta arithmetic |
| T2 | `EscalationTrendProjection` | `previousEscalations == 0`, `currentEscalations > 0` — delta = 100.0 |
| T3 | `EscalationTrendProjection` | Both months empty — delta = 0.0 |
| T4 | `EscalationTrendProjection` | `currentMonth == previousMonth` (same string) — delta = 0.0, not a division error |
| T5 | `MonthlyReportProjection` | No incidents in month — compliance = 1.0 |
| T6 | `MonthlyReportProjection` | All incidents breached — compliance near 0 |
| T7 | `MonthlyReportProjection` | Breaches with overrides — overrides reduce breach weight |
| T8 | `SLADashboardProjection` | Override-recorded incident excluded from breachWeight AND from breachedIncidents (currently fails — see P1 finding) |
| T9 | `SLADashboardProjection` | Unknown severity name — should not throw |
| T10 | `SLADashboardProjection` | Events outside date range — excluded from counts |
| T11 | `MultiSiteComparisonProjection` | Events with no `site_id` in metadata — silently dropped, no crash |
| T12 | `MultiSiteComparisonProjection` | Single site with zero incidents — compliance = 1.0 |
| T13 | `DispatchPerformanceProjection` | Guards with patrols but no check-ins — compliance = 100% (verify intent) |
| T14 | `DispatchPerformanceProjection` | No dispatch events — empty guard list, zero patrol counts |
| T15 | `ReportBundleAssembler` | `crmEvents.isEmpty` — preview client fallback, no crash |
| T16 | `ReportBundleAssembler` | `incidentDetails` contains only current-month events (not multi-month) |
| T17 | `ReportBundleCanonicalizer` | `reportSchemaVersion < 2` — no `sceneReview` key in output |
| T18 | `ReportBundleCanonicalizer` | `reportSchemaVersion >= 3` — branding and section keys present |
| T19 | `ExecutiveSummaryGenerator` | `slaComplianceRate >= 0.95` → correct headline |
| T20 | `ExecutiveSummaryGenerator` | `totalSlaBreaches > 3` → systemic risk message |

---

## Performance / Stability Notes

- `ReportBundleAssembler` calls `SLADashboardProjection.build` (iterating all events twice — once for `incidentsInMonth` selection, once in the projection itself). For clients with large event streams this is O(n) twice, but both are in-memory — not a hot path concern unless events number in the thousands.
- `MultiSiteComparisonProjection` builds a `Map<String, List<IncidentEvent>>` in memory then iterates it a second time. For high site-count clients this allocates proportionally. Not a current risk.
- `ReportBundleCanonicalizer` uses `jsonEncode` directly on a manually constructed map. No streaming — the entire JSON is held in memory. Acceptable for report payloads, but worth noting if reports include many incident details.

---

## Recommended Fix Order

1. **P1 — `breachedIncidents` diverges from compliance** (`sla_dashboard_projection.dart:68`) — confirmed data inconsistency in live reports. AUTO.
2. **P1 — Force-unwrap `slaProfile!`** (`report_bundle_assembler.dart:62`) — runtime crash path. REVIEW.
3. **P1 — Fabricated PSIRA/guard fields** (`dispatch_performance_projection.dart:49-54`) — compliance risk in client-facing output. REVIEW.
4. **P2 — Unify month-filtering strategy** — resolves timezone fault and duplication. AUTO (after deciding on UTC-normalised timestamps).
5. **P2 — `previousMonth` validation / computed helper** — removes caller error vector. AUTO.
6. **P3 — `incidentDetails` month scope** (`report_bundle_assembler.dart:110`) — clear correctness bug. AUTO.
7. **P3 — `firstWhere` without `orElse`** (`sla_dashboard_projection.dart:27`) — crash on unknown severity. AUTO.
8. **P2 — Unify `slaComplianceRate` formula** across projections. REVIEW (requires SLA profile input for multi-site path).
9. **P3 — `monthEnd` arithmetic clarity** — refactor to explicit form. AUTO.
10. **DECISION — Hardcoded narrative strings and patrol constant** — product choices required before implementation.
