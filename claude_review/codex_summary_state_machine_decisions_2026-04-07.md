# Codex Summary — State Machine Decisions

- Date: 2026-04-07
- Scope:
  - `lib/engine/dispatch/*`
  - `lib/domain/projection/*`
  - `lib/domain/incidents/*`
  - `lib/domain/crm/reporting/*`

## Decision 1 — `executed` means attempted, not succeeded

Implemented:

- Added `confirmed` to `ActionStatus` in `/Users/zaks/omnix_dashboard/lib/engine/dispatch/action_status.dart`
- Updated `/Users/zaks/omnix_dashboard/lib/engine/dispatch/dispatch_state_machine.dart` to the approved transition model:
  - `decided -> committing | executed | aborted | overridden`
  - `committing -> executed | failed | overridden`
  - `executed -> confirmed | failed`
  - `confirmed`, `aborted`, `overridden`, `failed` are terminal
- Updated `/Users/zaks/omnix_dashboard/lib/engine/vertical_slice_runner.dart` so the success path validates `executed -> confirmed` and replay expects `CONFIRMED`

Downstream alignment:

- Successful execution projections now resolve to `CONFIRMED` instead of `EXECUTED` in:
  - `/Users/zaks/omnix_dashboard/lib/domain/projection/dispatch_projection.dart`
  - `/Users/zaks/omnix_dashboard/lib/domain/projection/dispatch_aggregate.dart`
  - `/Users/zaks/omnix_dashboard/lib/domain/aggregate/dispatch_aggregate.dart`
  - `/Users/zaks/omnix_dashboard/lib/domain/projection/dashboard_overview_projection.dart`
  - `/Users/zaks/omnix_dashboard/lib/domain/projection/operations_health_projection.dart`
- UI consumers now recognize `CONFIRMED` while still accepting legacy `EXECUTED`:
  - `/Users/zaks/omnix_dashboard/lib/ui/dashboard_page.dart`
  - `/Users/zaks/omnix_dashboard/lib/ui/sites_page.dart`

Tests added:

- `/Users/zaks/omnix_dashboard/test/engine/dispatch_state_machine_test.dart`
  - full legal/illegal transition matrix
- `/Users/zaks/omnix_dashboard/test/engine/vertical_slice_runner_test.dart`
  - success path rebuilds into `CONFIRMED`

## Decision 2 — SLA breach must not force `escalated`

Implemented:

- Added `slaBreached` flag to `IncidentRecord` in `/Users/zaks/omnix_dashboard/lib/domain/incidents/incident_record.dart`
- Updated `/Users/zaks/omnix_dashboard/lib/domain/incidents/incident_projection.dart` so:
  - `incidentEscalated` still sets `status = escalated`
  - `incidentSlaBreached` now sets `slaBreached = true` and preserves the current status
- Updated `/Users/zaks/omnix_dashboard/lib/domain/incidents/client/client_incident_log_projection.dart` so SLA breach no longer masquerades as escalation in client-facing status

Downstream semantic alignment:

- Reporting projections no longer count `incidentSlaBreached` as an escalation event:
  - `/Users/zaks/omnix_dashboard/lib/domain/crm/reporting/escalation_trend_projection.dart`
  - `/Users/zaks/omnix_dashboard/lib/domain/crm/reporting/monthly_report_projection.dart`
  - `/Users/zaks/omnix_dashboard/lib/domain/crm/reporting/multi_site_comparison_projection.dart`

Tests added:

- `/Users/zaks/omnix_dashboard/test/domain/incidents/incident_service_test.dart`
  - `IncidentService` emits SLA breach while rebuilt incident stays `dispatchLinked`
  - rebuilt incident sets `slaBreached = true`
  - CRM logging still occurs for breach events
  - client incident log projection does not treat breach as escalation

## Validation

- `dart analyze` on all touched engine/domain/UI/test files
- `flutter test /Users/zaks/omnix_dashboard/test/engine/dispatch_state_machine_test.dart /Users/zaks/omnix_dashboard/test/engine/vertical_slice_runner_test.dart /Users/zaks/omnix_dashboard/test/domain/incidents/incident_service_test.dart`

Result:

- `dart analyze`: passed
- focused tests: all passed
