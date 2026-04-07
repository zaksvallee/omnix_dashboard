# Codex Summary — BI Foundation + urgent fixes
Date: 2026-04-07
Workspace: `/Users/zaks/omnix_dashboard`

## Completed

### Urgent fix 1 — obfuscation-safe audit type keys
- Replaced `runtimeType.toString()` usage with explicit audit type keys on `DispatchEvent` subclasses.
- Added `toAuditTypeKey()` on the domain event base and concrete event classes.
- Updated the sovereign ledger and other audit/export readers to use the explicit key.
- Added a hardcoded-string regression test so audit payload typing no longer depends on runtime class names.

Files:
- `lib/domain/events/dispatch_event.dart`
- `lib/domain/events/*.dart`
- `lib/ui/sovereign_ledger_page.dart`
- `lib/domain/evidence/client_ledger_service.dart`
- `lib/ui/events_page.dart`
- `lib/ui/events_review_page.dart`
- `lib/application/onyx_agent_context_snapshot_service.dart`
- `lib/presentation/incidents/manual_incident_page.dart`
- `test/domain/events/dispatch_event_audit_type_key_test.dart`
- `test/ui/sovereign_ledger_page_widget_test.dart`

### Urgent fix 2 — targeted flaky time-relative tests
- Removed the remaining direct `DateTime.now()` use from:
  - `test/ui/onyx_app_clients_route_widget_test.dart`
  - `test/ui/onyx_app_agent_route_widget_test.dart`
- Renamed the duplicate fallback test in `test/application/client_conversation_repository_test.dart` to:
  - `reads messages from fallback when primary message read fails`
- Added a narrow ONYX Telegram clock hook so the requested time-sensitive route tests can inject a deterministic time without changing general app behavior.
- Wired the targeted client-route matrix helpers to pass an explicit test clock only where needed:
  - deterministic client incident-read matrix
  - deterministic partner read matrix
  - camera zone label narrative matrix
- Also routed client quick-action packet time through the same hook so the zone-label status narrative uses the intended synthetic review window.

Files:
- `lib/application/onyx_telegram_operational_command_service.dart`
- `lib/main.dart`
- `test/ui/onyx_app_clients_route_widget_test.dart`
- `test/ui/onyx_app_agent_route_widget_test.dart`
- `test/application/client_conversation_repository_test.dart`

Note:
- A wider run of `onyx_app_clients_route_widget_test.dart` still shows separate phrase-shape failures in older carryover/ambiguity assertions that were outside the requested flaky-time batch.
- The specific requested flaky cases are green.

### BI foundation

#### Step 1 — hourly breakdown persisted
- Added `hourlyBreakdown: Map<int, int>` to `SovereignReportVehicleThroughput`.
- Populated it from the existing visit-by-hour computation.
- Serialized/deserialized it in `toJson` / `fromJson`.
- Added regression coverage in `morning_sovereign_report_service_test.dart`.

#### Step 2 — Vehicle BI dashboard panel
- Added `VehicleBiDashboardPanel`.
- Panel includes:
  - Total vehicles card
  - Average dwell time card
  - Repeat customer rate card
  - Hourly bar chart
  - Entry -> Service -> Exit funnel
- Added supporting throughput counts for the funnel:
  - `entryCount`
  - `serviceCount`
  - `exitCount`
- Added focused widget tests.

#### Step 3 — governance drill-in wiring
- Wired the existing `Vehicle Throughput` governance metric to open a BI dashboard drill-in.
- Added a focused governance widget test for the new dialog.

#### Step 4 — carwash demo fixture
- Added a reusable synthetic fixture JSON for a carwash BI shift:
  - `test/fixtures/carwash_bi_demo_report.json`
- Added a parser regression test to confirm the fixture loads into `SovereignReport`.
- Refined the fixture to the approved demo shape:
  - 47 vehicle visits over a single Saturday
  - repeat/new plate mix via `repeatVehicles: 10` and `uniqueVehicles: 37`
  - zone coverage across `Entry Lane`, `Wash Bay 1`, and `Exit Lane`
  - peak traffic concentrated in the 10:00-12:00 window
  - 2 suspicious loitering vehicles flagged in `exceptionVisits`

Files:
- `lib/application/morning_sovereign_report_service.dart`
- `lib/ui/vehicle_bi_dashboard_panel.dart`
- `lib/ui/governance_page.dart`
- `test/application/morning_sovereign_report_service_test.dart`
- `test/application/carwash_bi_demo_fixture_test.dart`
- `test/ui/vehicle_bi_dashboard_panel_test.dart`
- `test/ui/governance_page_widget_test.dart`
- `test/fixtures/carwash_bi_demo_report.json`

## Validation

### Urgent fixes
- `dart analyze lib/application/onyx_telegram_operational_command_service.dart lib/main.dart test/ui/onyx_app_clients_route_widget_test.dart test/ui/onyx_app_agent_route_widget_test.dart test/application/client_conversation_repository_test.dart`
- `flutter test test/domain/events/dispatch_event_audit_type_key_test.dart test/domain/evidence/client_ledger_service_test.dart test/ui/sovereign_ledger_page_widget_test.dart`
- `flutter test test/ui/onyx_app_agent_route_widget_test.dart`
- `flutter test test/application/client_conversation_repository_test.dart`
- Focused client-route passes:
  - `onyx app keeps the deterministic client incident-read matrix stable`
  - `onyx app keeps the deterministic partner read matrix stable`
  - `onyx app keeps camera zone labels deterministic in monitoring narratives`

### BI foundation
- `dart analyze lib/application/morning_sovereign_report_service.dart test/application/morning_sovereign_report_service_test.dart`
- `flutter test test/application/morning_sovereign_report_service_test.dart`
- `dart analyze lib/application/morning_sovereign_report_service.dart lib/ui/vehicle_bi_dashboard_panel.dart test/application/morning_sovereign_report_service_test.dart test/ui/vehicle_bi_dashboard_panel_test.dart`
- `flutter test test/ui/vehicle_bi_dashboard_panel_test.dart`
- `dart analyze lib/ui/governance_page.dart lib/ui/vehicle_bi_dashboard_panel.dart test/ui/governance_page_widget_test.dart`
- `flutter test test/ui/governance_page_widget_test.dart --plain-name "governance vehicle throughput metric opens BI dashboard"`
- `flutter test test/application/morning_sovereign_report_service_test.dart test/application/carwash_bi_demo_fixture_test.dart test/ui/vehicle_bi_dashboard_panel_test.dart`
- `dart analyze test/application/carwash_bi_demo_fixture_test.dart`
- `flutter test test/application/carwash_bi_demo_fixture_test.dart`
- Final repo-wide `dart analyze`

Result:
- All analyze runs above passed.
- All focused tests above passed.

## Verified remaining follow-up
- `test/ui/onyx_app_clients_route_widget_test.dart` still has unrelated carryover/ambiguity wording failures in the broader suite, e.g. area-name phrasing like `Gate` vs `Front Gate` / `Back Gate`. Those were surfaced during a full-file run but were outside the requested time-flake scope.
- BI dashboard is wired only as a governance drill-in for now; no standalone ONYX BI route/page exists yet.
- The carwash fixture is test/demo data only and is not yet exposed through a runtime demo picker.
