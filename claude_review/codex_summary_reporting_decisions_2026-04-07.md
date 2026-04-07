# Codex Summary — Reporting Decisions — 2026-04-07

## Implemented

### Decision 1 — Camera staging mode visibility
- Added a visible `Camera control in staging mode` indicator to the CCTV agent UI.
- Added the same staging indicator to camera bridge controls in the admin/system runtime surface.
- Preserved simulation behavior. This is visibility only.

Touched files:
- `/Users/zaks/omnix_dashboard/lib/ui/onyx_camera_bridge_shell_panel.dart`
- `/Users/zaks/omnix_dashboard/lib/ui/onyx_agent_page.dart`
- `/Users/zaks/omnix_dashboard/lib/ui/admin_page.dart`

### Decision 2 — Client report narratives
- Removed hardcoded narrative content for:
  - `supervisorAssessment`
  - `companyAchievements`
  - `emergingThreats`
- Replaced those with empty/default placeholders.
- Added `ReportNarrativeRequest` carrying:
  - `clientId`
  - `reportPeriod`
  - `incidentSummary`
  - `escalationCount`
  - `slaComplianceRate`
- Attached the request model to the assembled report bundle so the Reports Workspace Agent can generate client-specific narratives later.

Touched files:
- `/Users/zaks/omnix_dashboard/lib/domain/crm/reporting/report_sections.dart`
- `/Users/zaks/omnix_dashboard/lib/domain/crm/reporting/report_bundle.dart`
- `/Users/zaks/omnix_dashboard/lib/domain/crm/reporting/report_bundle_assembler.dart`
- `/Users/zaks/omnix_dashboard/lib/domain/crm/reporting/report_bundle_canonicalizer.dart`

### Decision 3 — Patrol expectation constant
- Kept `_expectedPatrolsPerCheckIn = 8`.
- Added TODO:
  - `Per-contract value — move to client configuration when contract data model is ready`

Touched file:
- `/Users/zaks/omnix_dashboard/lib/domain/crm/reporting/dispatch_performance_projection.dart`

## Tests
- Added report assembler coverage for empty narrative fields plus `ReportNarrativeRequest`.
- Added agent UI coverage for visible staging-mode labeling.
- Updated admin camera bridge status coverage to assert staging visibility.

Touched tests:
- `/Users/zaks/omnix_dashboard/test/domain/crm/reporting/report_bundle_assembler_test.dart`
- `/Users/zaks/omnix_dashboard/test/ui/onyx_agent_page_widget_test.dart`
- `/Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart`

## Validation
- `dart analyze` on touched reporting/UI files and focused tests: passed
- `flutter test /Users/zaks/omnix_dashboard/test/domain/crm/reporting/report_bundle_assembler_test.dart`: passed
- `flutter test /Users/zaks/omnix_dashboard/test/ui/onyx_agent_page_widget_test.dart --plain-name "onyx agent page surfaces camera staging mode clearly"`: passed
- `flutter test /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart --plain-name "system runtime surfaces local camera bridge status"`: passed
