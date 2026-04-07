# Audit: Test Coverage — Full Repo

- Date: 2026-04-07
- Auditor: Claude Code
- Scope: all files under `lib/` vs all test files under `test/`
- Read-only: yes

---

## Executive Summary

410 production Dart files, 266 test files (~65% nominal ratio). Coverage quality is uneven: the
application layer is well-exercised, but the domain's incident/SLA subsystem, the CRM reporting
projection layer, and the dispatch engine primitives all carry zero direct test coverage. Three
critical paths (alarm, dispatch, escalation) each have meaningful entry-point tests, but their
lower layers — state machines, SLA evaluators, false-positive suppressors — are untested. The
consequence is that silent regressions in those lower layers will not surface until the
integration path fails in staging or production.

---

## What Looks Good

- **Monitoring watch escalation:** `monitoring_watch_escalation_policy_service_test.dart` (312 lines, 11 tests) is thorough. All `MonitoringWatchNotificationKind` values are exercised.
- **Dispatch triage:** `dispatch_application_service_triage_test.dart` (311 lines, 7 tests) covers the happy path and duplicate-dispatch guard via `ExecutionEngine` indirectly.
- **Agent coverage:** All 10 `onyx_agent_*` logic services have dedicated test files. The only gaps are the 4 platform-variant files (`server_io`, `server_stub`, `tcp_probe_io`, `tcp_probe_stub`), which are expected — their interface is covered by `onyx_agent_camera_bridge_server_contract_test.dart`.
- **HikConnect preflight suite:** 11 dedicated test files covering the full preflight bootstrap chain.
- **Telegram service layer:** High test density across approval, routing, push, quick-action, and identity flows.

---

## Findings

### P1 — Alarm path: `cctv_false_positive_policy.dart` has no test

- Action: **AUTO**
- Finding: `CctvFalsePositivePolicy` and `CctvFalsePositiveRule` (135 lines) are untested. This class makes alarm-suppression decisions that gate whether a CCTV alarm is surfaced to an operator.
- Why it matters: The `matches()` method contains time-window logic with a midnight-crossing branch:
  ```
  if (startHourLocal < endHourLocal) {
    return localHour >= startHourLocal && localHour < endHourLocal;
  }
  return localHour >= startHourLocal || localHour < endHourLocal;
  ```
  The inverted-window branch (`startHour > endHour`) is structurally different. If it silently evaluates incorrectly, alarms within the suppression window are surfaced when they should not be, or vice versa — no test will catch either failure mode.
- Evidence: `lib/application/cctv_false_positive_policy.dart`, lines 42–56
- Suggested follow-up: Codex should add a test for `CctvFalsePositiveRule.matches()` covering: (a) standard window, (b) midnight-crossing window, (c) empty zone wildcard, (d) confidence threshold boundary.

---

### P1 — Dispatch path: `DispatchStateMachine` has no test

- Action: **AUTO**
- Finding: `engine/dispatch/dispatch_state_machine.dart` (28 lines) defines the legal state transition matrix for dispatch actions. No test file exists.
- Why it matters: The matrix includes non-obvious rules (`decided → committing | executed | overridden`; terminal states return `false`). An incorrect transition guard would silently allow or block valid dispatches. The triage test exercises the `ExecutionEngine` but never calls `DispatchStateMachine.canTransition` directly.
- Evidence: `lib/engine/dispatch/dispatch_state_machine.dart`, lines 4–27
- Suggested follow-up: Codex should add a matrix test (one case per `from` state × allowed `to` state, plus one rejection case per terminal state).

---

### P1 — Escalation path: `SLABreachEvaluator` and `SLAClock` have no tests

- Action: **AUTO**
- Finding: `domain/incidents/risk/sla_breach_evaluator.dart` (43 lines) and `domain/incidents/risk/sla_clock.dart` (43 lines) are both untested. These are the two functions that decide whether an SLA breach event is emitted, which is the trigger point for escalation on the incident side.
- Why it matters: `SLAClock.evaluate()` computes `due = start + sla_minutes`; `SLABreachEvaluator` guards against duplicate breach events and decides when to emit. Bugs here (wrong duration unit, wrong terminal-state guard, duplicate emission) produce silent escalation inflation or total escalation suppression.
- Evidence: `lib/domain/incidents/risk/sla_clock.dart` lines 20–42; `lib/domain/incidents/risk/sla_breach_evaluator.dart` lines 6–42
- Suggested follow-up: Codex should test: (a) breach fires when `nowUtc > due`; (b) breach suppressed when incident is resolved/closed; (c) duplicate breach is not emitted when history already contains `incidentSlaBreached`.

---

### P1 — Escalation path: `IncidentService` has no test

- Action: **REVIEW**
- Finding: `domain/incidents/incident_service.dart` (90 lines) has no test. It is the coordinator that: loads from storage, calls `SLABreachEvaluator`, maps to CRM, persists. No test covers this chain.
- Why it matters: The `handle()` method chains multiple side-effectful writes (`incidentLog.append`, `crmLog.append`, `storage.saveIncidents`, `storage.saveCrm`). A partial-write scenario (exception after append but before save) is a known data-loss risk pattern and is completely untested.
- Evidence: `lib/domain/incidents/incident_service.dart`, lines 29–60
- Suggested follow-up: Zaks should decide whether `IncidentService` should be tested with real in-memory stores or with mocks. The partial-write risk (append succeeds, save throws) is the most important failure case to lock.

---

### P2 — Escalation trend projection: `EscalationTrendProjection` has no test

- Action: **AUTO**
- Finding: `domain/crm/reporting/escalation_trend_projection.dart` (55 lines) is untested. It computes `currentEscalations`, `previousEscalations`, `escalationDeltaPercent`, `breachDeltaPercent` from raw event history.
- Why it matters: The delta calculation uses division with a zero-guard — but only one path (`current == 0 ? 0.0 : 100.0`) handles the zero-previous case. This is a common source of off-by-one or logical errors in trend reporting.
- Evidence: `lib/domain/crm/reporting/escalation_trend_projection.dart`, lines 33–42
- Suggested follow-up: Test: (a) zero previous → delta = 100.0 or 0.0; (b) no events → all zeros; (c) mixed event types are counted correctly.

---

### P2 — `ExecutionEngine` has no dedicated test (only indirect coverage)

- Action: **AUTO**
- Finding: `engine/execution/execution_engine.dart` (31 lines) is only exercised indirectly through `dispatch_application_service_triage_test.dart`. Its own duplicate-execution guard (`_executedDispatchIds.contains`) and authority validation are not directly tested.
- Why it matters: The duplicate execution guard is a security control. Its only test exposure is through a higher-level coordinator, which means if the engine is replaced or its internals refactored, the guard can silently regress without any test failure.
- Evidence: `lib/engine/execution/execution_engine.dart`, lines 9–30
- Suggested follow-up: Codex should add a direct test: (a) duplicate dispatch throws `StateError`; (b) empty `authorizedBy` throws `StateError`; (c) empty `dispatchId` throws `ArgumentError`.

---

### P2 — CRM reporting projection layer is entirely untested

- Action: **REVIEW**
- Finding: The following 9 domain files have no test coverage at all:
  - `domain/crm/reporting/dispatch_performance_projection.dart`
  - `domain/crm/reporting/monthly_report_projection.dart`
  - `domain/crm/reporting/multi_site_comparison_projection.dart`
  - `domain/crm/reporting/report_bundle_assembler.dart`
  - `domain/crm/reporting/report_bundle_canonicalizer.dart`
  - `domain/crm/reporting/sla_dashboard_projection.dart`
  - `domain/crm/reporting/executive_summary_generator.dart`
  - `domain/crm/sla_tier_service.dart`
  - `domain/crm/sla_tier_projection.dart`
- Why it matters: This subsystem generates client-facing PDF and text reports. Incorrect projections (wrong SLA tier selection, wrong breach counts, wrong month-over-month comparisons) produce incorrect client deliverables. The subsystem is structurally clean but has zero regression protection.
- Evidence: `lib/domain/crm/reporting/` — all files. No test in `test/` references `EscalationTrend`, `SLATier`, `ReportBundle`, `ExecutiveSummary`, or any of these types.
- Suggested follow-up: Zaks should prioritise which of these is most client-visible (likely `SLADashboardProjection` and `EscalationTrendProjection`). Codex can auto-implement those two; the rest should queue as REVIEW.

---

### P3 — `GuardPerformanceService` has no test

- Action: **AUTO**
- Finding: `application/guard_performance_service.dart` (60 lines) computes `SitePerformanceSummary` from the event store. Untested.
- Why it matters: The service iterates all events and computes 6 metrics. A wrong projection key (`clientId/regionId/siteId` triple) would silently return zero values for a site. No test guards this.
- Evidence: `lib/application/guard_performance_service.dart`, lines 14–53
- Suggested follow-up: Simple integration test with an in-memory store seeded with a few events.

---

### P3 — Platform adapter files have no tests (low priority)

- Action: **AUTO**
- Finding: The following files are untested stub/web platform adapters:
  - `application/browser_link_service.dart` / `_stub` / `_web`
  - `application/email_bridge_service.dart` / `_stub` / `_web`
  - `application/text_share_service.dart` / `_stub` / `_web`
  - `application/dispatch_snapshot_file_service_stub.dart` / `_web`
- Why it matters: These files are typically thin delegates and failing silently is low risk. But stub files that throw `UnimplementedError` or return empty values are a common source of confusion in CI if a test accidentally uses the wrong platform variant.
- Suggested follow-up: Codex can add a contract test that asserts each platform trio honours the shared interface signature — no behaviour test needed.

---

### P3 — Route builder files have no tests

- Action: **DECISION**
- Finding: The following UI route builder files are untested:
  - `ui/onyx_route_builders.dart`
  - `ui/onyx_route_command_center_builders.dart`
  - `ui/onyx_route_dispatcher.dart`
  - `ui/onyx_route_evidence_builders.dart`
  - `ui/onyx_route_governance_builders.dart`
  - `ui/onyx_route_operations_builders.dart`
  - `ui/onyx_route_system_builders.dart`
- Why it matters: Route builders wire `OnyxRoute` values to widget constructors. Mis-wired routes produce blank screens or wrong page loads. Some route-level tests exist (`onyx_app_*_route_widget_test.dart`) but they test the app shell routing, not the builder functions themselves.
- Suggested follow-up: Zaks should decide whether route builders require their own unit tests or whether the existing route smoke tests are sufficient. If a route is added and the builder is wrong, the current tests may not catch the mismatch.

---

## Agents — Coverage Summary

All 10 `onyx_agent_*` logic services have dedicated test files:

| File | Test |
|---|---|
| `onyx_agent_camera_bridge_health_service` | yes |
| `onyx_agent_camera_bridge_receiver` | yes |
| `onyx_agent_camera_bridge_server_contract` | yes |
| `onyx_agent_camera_bridge_server` | yes |
| `onyx_agent_camera_change_service` | yes |
| `onyx_agent_camera_probe_service` | yes |
| `onyx_agent_client_draft_service` | yes |
| `onyx_agent_cloud_boost_service` | yes |
| `onyx_agent_context_snapshot_service` | yes |
| `onyx_agent_local_brain_service` | yes |

**No agent logic service is untested.** The 4 untested files (`server_io`, `server_stub`, `tcp_probe_io`, `tcp_probe_stub`) are platform implementation variants — their contract is locked by `onyx_agent_camera_bridge_server_contract_test.dart`. This is acceptable.

---

## Critical Path Summary

| Path | Entry-point test | Lower-layer gaps |
|---|---|---|
| Alarm | `listener_alarm_feed_service_test` (143 lines) | `CctvFalsePositivePolicy` (**no test**, P1) |
| Dispatch | `dispatch_application_service_triage_test` (311 lines) | `DispatchStateMachine` (**no test**, P1); `ExecutionEngine` (indirect only, P2) |
| Escalation | `monitoring_watch_escalation_policy_service_test` (312 lines) | `SLABreachEvaluator`, `SLAClock` (**no test**, P1); `IncidentService` (**no test**, P1); `EscalationTrendProjection` (**no test**, P2) |

---

## Coverage Gaps — Master List

Files with zero direct test coverage, grouped by risk level:

**High risk (business logic, no test):**
- `lib/application/cctv_false_positive_policy.dart` — alarm suppression (P1 AUTO)
- `lib/engine/dispatch/dispatch_state_machine.dart` — state transition matrix (P1 AUTO)
- `lib/domain/incidents/risk/sla_breach_evaluator.dart` — SLA breach emitter (P1 AUTO)
- `lib/domain/incidents/risk/sla_clock.dart` — SLA clock calculator (P1 AUTO)
- `lib/domain/incidents/risk/sla_policy.dart` — SLA resolution policy (P1 AUTO)
- `lib/domain/incidents/incident_service.dart` — incident lifecycle coordinator (P1 REVIEW)
- `lib/domain/crm/reporting/escalation_trend_projection.dart` — trend delta (P2 AUTO)
- `lib/engine/execution/execution_engine.dart` — execution + duplicate guard (P2 AUTO)
- `lib/domain/crm/reporting/sla_dashboard_projection.dart` — SLA dashboard (P2 REVIEW)
- `lib/domain/crm/reporting/dispatch_performance_projection.dart` — dispatch perf (P2 REVIEW)
- `lib/application/guard_performance_service.dart` — guard metrics (P3 AUTO)

**Medium risk (CRM projection subsystem, entirely untested):**
- `lib/domain/crm/reporting/monthly_report_projection.dart`
- `lib/domain/crm/reporting/multi_site_comparison_projection.dart`
- `lib/domain/crm/reporting/report_bundle_assembler.dart`
- `lib/domain/crm/reporting/report_bundle_canonicalizer.dart`
- `lib/domain/crm/reporting/executive_summary_generator.dart`
- `lib/domain/crm/sla_tier_service.dart`
- `lib/domain/crm/sla_tier_projection.dart`

**Low risk (platform adapters, stubs, data-only classes):**
- `lib/application/browser_link_service*.dart`
- `lib/application/email_bridge_service*.dart`
- `lib/application/text_share_service*.dart`
- `lib/application/dispatch_snapshot_file_service_stub.dart` / `_web`
- `lib/application/monitoring_watch_action_plan.dart` (data class)
- `lib/application/report_entry_context.dart`, `report_output_mode.dart`, etc. (data classes)
- `lib/domain/events/*.dart` (all event data classes — generally acceptable)

**UI (route builders — DECISION required):**
- `lib/ui/onyx_route_builders.dart` and 6 sibling builder files

---

## Recommended Fix Order

1. **`CctvFalsePositivePolicy`** — P1 AUTO. Midnight-crossing time window is a real edge-case bug magnet. Codex can add this test without any design input from Zaks.
2. **`DispatchStateMachine`** — P1 AUTO. Pure static function, the transition matrix has a clear canonical form to test.
3. **`SLABreachEvaluator` + `SLAClock`** — P1 AUTO. Two pure functions, no dependencies to stub. High-value, low-cost.
4. **`ExecutionEngine` direct test** — P2 AUTO. Locks the duplicate-dispatch and authority-guard controls.
5. **`IncidentService`** — P1 REVIEW. Block on Zaks decision: real stores or mocks? Partial-write path needs design intent.
6. **`EscalationTrendProjection`** — P2 AUTO. Straightforward projection test, self-contained.
7. **CRM reporting subsystem** — P2 REVIEW. Zaks should decide which projections are most client-visible and prioritise those two for Codex first.
8. **Route builders** — P3 DECISION. Low urgency but should be decided before the next major route refactor.
