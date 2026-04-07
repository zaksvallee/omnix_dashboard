# Codex Summary — AUTO Batch 3 — 2026-04-07

## Scope completed

Implemented the requested AUTO fixes across:

- `lib/ui/dispatch_page.dart`
- `lib/ui/events_review_page.dart`
- `lib/ui/guard_mobile_shell_page.dart`
- `lib/ui/client_intelligence_reports_page.dart`
- `lib/application/export_coordinator.dart`

Did not touch tactical map data.

## Dispatch Page

Completed:

- Fixed the `'$dispatch.id'` interpolation issue by using `dispatch.id` directly.
- Moved the workspace `GlobalKey`s out of `build()` and into persistent `State` fields.
- Stopped operator actions from being overwritten by the next `_projectDispatches()` run.
  - Added `_dispatchOverrides` to hold operator-driven cleared / dispatched state.
  - `_clearAlarm()` now writes override state instead of mutating transient projected rows only.
  - `_handleDispatchAction()` now persists the next operator state before the next poll lands.
  - `_projectDispatches()` now reapplies overrides after projection.

Result:

- Polling no longer erases cleared / dispatched operator intent.
- Workspace anchor keys remain stable across rebuilds.

## Events Review Page

Completed:

- Removed build-time mutation of `_selectedEvent`.
  - Added queued post-frame sync via `_queueSelectedEventSync(...)`.
- Removed build-time mutation of `_desktopWorkspaceActive`.
  - Added queued post-frame sync via `_queueDesktopWorkspaceSync(...)`.
- Consolidated repeated empty `SovereignReport` factories into `_emptySovereignReport(...)`.
- Fixed `_clock12` / `_fullTimestamp` so UTC timestamps are labeled as UTC, not local.
- Replaced hardcoded version / source labels with event-derived helpers:
  - `_eventSchemaVersionLabel(...)`
  - `_eventSourceLabel(...)`
- Migrated AUTO clipboard/export copy actions to `ExportCoordinator`.

## Guard Mobile Shell

Completed:

- Removed build-time mutation of `_selectedOperationId`.
  - Added `_queueSelectedOperationClear()` for the invalid-selection clear path.
- Updated `didUpdateWidget(...)` to move parent-driven selection changes through `setState(...)`.
- Fixed `_buildDispatchCloseoutPacket(...)` to capture one `nowUtc` value and reuse it instead of calling `DateTime.now()` repeatedly for the same packet.

## Client Intelligence Reports

Completed:

- Replaced the `_service` getter with a persistent `ReportGenerationService` field initialized once and refreshed only when the backing store / scene-review map changes.
- Added a mounted guard before the final `_isGenerating` reset `setState(...)`.
- Migrated AUTO clipboard/export copy actions to `ExportCoordinator`.
- Routed CSV exports through `copyCsv(...)` instead of ad hoc text copies.

Additional repo-grounded fix required during validation:

- Report generation was anchoring `nowUtc` to wall-clock time, which caused generated reports to miss historical scene review data when the current month differed from the selected site's latest operational month.
- Added `_reportGenerationNowUtc()` to anchor generation to the latest relevant site event, falling back to `_endDate` only when no scoped operational events exist.

Result:

- Generated report previews now include the correct scene-review content for the active site history.
- The previously failing reviewed-preview widget flows are green again.

## Export Coordinator

Created:

- `lib/application/export_coordinator.dart`

Implemented:

- `copyJson(dynamic data, {String? label})`
- `copyCsv(List<String> lines, {String? label})`
- `copyText(String text, {String? label})`

Behavior:

- All three copy paths now route through uniform clipboard handling plus `logUiAction(...)`.

Current AUTO migration coverage in this batch:

- `events_review_page.dart` copy/export actions moved to `ExportCoordinator`
- `client_intelligence_reports_page.dart` copy/export actions moved to `ExportCoordinator`

Deferred by decision, as requested:

- `shareText` / `openMailDraft` migration
- feedback callback pattern cleanup

## Validation

### Analyze

Passed:

- `dart analyze lib/application/export_coordinator.dart lib/ui/dispatch_page.dart lib/ui/events_review_page.dart lib/ui/guard_mobile_shell_page.dart lib/ui/client_intelligence_reports_page.dart`

### Widget tests

Passed:

- `flutter test test/ui/dispatch_page_widget_test.dart`
- `flutter test test/ui/events_review_page_widget_test.dart`
- `flutter test test/ui/guard_mobile_shell_page_widget_test.dart`
- `flutter test test/ui/client_intelligence_reports_page_widget_test.dart`

## Notes

- The reports-page month-anchor correction was discovered during this AUTO batch because the new persistent report service exposed a date-sensitive preview path that the repo’s widget tests exercise.
- No tactical map data changes were made.
