# Codex Summary — SLA Decisions

Date: 2026-04-07
Workspace: /Users/zaks/omnix_dashboard

## Repo-first verification status

Re-checked on a later pass before making any new edits.

Result:
- The repo already contains all three approved SLA decisions.
- No additional SLA code changes were necessary on this pass.
- Focused SLA tests and targeted `dart analyze` were rerun to confirm the implementation still matches the approved policy.

## Decision 1 — Clock drift tolerance

Implemented in:
- /Users/zaks/omnix_dashboard/lib/domain/incidents/risk/sla_breach_evaluator.dart
- /Users/zaks/omnix_dashboard/lib/domain/incidents/incident_event.dart
- /Users/zaks/omnix_dashboard/lib/domain/incidents/incident_record.dart
- /Users/zaks/omnix_dashboard/lib/domain/incidents/incident_projection.dart
- /Users/zaks/omnix_dashboard/lib/domain/incidents/timeline/incident_timeline_builder.dart
- /Users/zaks/omnix_dashboard/lib/domain/incidents/client/client_incident_log_projection.dart

Changes:
- Added `IncidentEventType.incidentSlaClockDriftDetected`.
- Added a 120-second drift tolerance window to SLA evaluation.
- If the gap between evaluations exceeds 120 seconds, SLA breach evaluation does not fire a breach event.
- The evaluator now emits a drift event containing `jump_seconds` and `sla_state = unverifiable_clock_event`.
- Incident replay/projection now preserves the SLA state as `unverifiable_clock_event` instead of marking the incident breached.

Tests added:
- `130-second clock jump emits drift event instead of breach`
- `90-second clock jump still evaluates the SLA normally`

## Decision 2 — Retroactive breach on restart

Implemented in:
- /Users/zaks/omnix_dashboard/lib/domain/incidents/incident_service.dart

Changes:
- `IncidentService.initialize(...)` now takes `slaProfile`.
- After replaying stored incident and CRM events, the service evaluates all open incidents against the current clock.
- If `nowUtc` is past `dueAt`, the service emits a retroactive `incidentSlaBreached` event.
- Retroactive breach metadata now includes:
  - `retroactive: true`
  - `offline_duration_minutes`
- Already-breached incidents are not double-fired.

Tests added:
- `initialize retroactively breaches overdue open incidents on restart`
- `initialize does not double-fire when the incident is already breached`

## UTC enforcement

Implemented in:
- /Users/zaks/omnix_dashboard/lib/domain/incidents/risk/sla_clock.dart

Changes:
- `SLAClock.evaluate(...)` now enforces that `record.detectedAt` is a UTC timestamp ending with `Z`.
- Non-UTC or suffixless timestamps throw `ArgumentError`.
- Existing incident-domain producers in this codepath already emit UTC ISO timestamps; no non-UTC live call sites remained after verification.

Test added:
- `rejects detectedAt timestamps without a UTC Z suffix`

## Validation

Passed:
- `flutter test /Users/zaks/omnix_dashboard/test/domain/incidents/risk/sla_clock_test.dart /Users/zaks/omnix_dashboard/test/domain/incidents/risk/sla_breach_evaluator_test.dart /Users/zaks/omnix_dashboard/test/domain/incidents/incident_service_test.dart /Users/zaks/omnix_dashboard/test/domain/integration/incident_to_crm_mapper_test.dart`
- `dart analyze /Users/zaks/omnix_dashboard/lib/domain/incidents/risk/sla_clock.dart /Users/zaks/omnix_dashboard/lib/domain/incidents/risk/sla_breach_evaluator.dart /Users/zaks/omnix_dashboard/lib/domain/incidents/incident_service.dart /Users/zaks/omnix_dashboard/lib/domain/incidents/incident_event.dart /Users/zaks/omnix_dashboard/lib/domain/incidents/incident_record.dart /Users/zaks/omnix_dashboard/lib/domain/incidents/incident_projection.dart /Users/zaks/omnix_dashboard/lib/domain/incidents/timeline/incident_timeline_builder.dart /Users/zaks/omnix_dashboard/lib/domain/incidents/client/client_incident_log_projection.dart /Users/zaks/omnix_dashboard/lib/domain/integration/incident_to_crm_mapper.dart /Users/zaks/omnix_dashboard/test/domain/incidents/risk/sla_clock_test.dart /Users/zaks/omnix_dashboard/test/domain/incidents/risk/sla_breach_evaluator_test.dart /Users/zaks/omnix_dashboard/test/domain/incidents/incident_service_test.dart /Users/zaks/omnix_dashboard/test/domain/integration/incident_to_crm_mapper_test.dart`
