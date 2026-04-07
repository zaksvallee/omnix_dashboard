# Governance P1 Summary — 2026-04-07

Status: implemented and validated

## Step 1

Replaced the fabricated governance operational cards with explicit pending-state UI in:

- `/Users/zaks/omnix_dashboard/lib/ui/governance_page.dart`

Changes:

- Removed the hardcoded `_buildCompliance`, `_buildVigilance`, and `_FleetStatus` seed values.
- Added `GovernanceOperationalFeeds` and related feed models.
- Switched the Governance page to render:
  - `Pending live feed` for compliance when live data is unavailable
  - `Pending live feed` for vigilance when watch runtime is unavailable
  - `Pending live feed` for fleet readiness when persisted dispatch state is unavailable
- Replaced the hero readiness chip with `Live` vs `Pending live feed`.

Validation:

- `dart analyze /Users/zaks/omnix_dashboard/lib/ui/governance_page.dart /Users/zaks/omnix_dashboard/test/ui/governance_page_widget_test.dart`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/governance_page_widget_test.dart --plain-name "governance page stays stable on phone viewport"`

## Step 2

Wired live governance operational feeds through the route layer in:

- `/Users/zaks/omnix_dashboard/lib/ui/onyx_route_governance_builders.dart`
- `/Users/zaks/omnix_dashboard/lib/main.dart`
- `/Users/zaks/omnix_dashboard/lib/ui/governance_page.dart`

Changes:

- Added a live `operationalFeedsLoader` to the Governance route builder.
- Compliance now comes from:
  - real guard assignment scope via `SharedPrefsGuardSyncRepository`
  - real credential/expiry data via `AdminDirectoryService`
- Vigilance now comes from:
  - `MonitoringWatchRuntimeState` live scope data
  - response averages from `OperationsHealthProjection`
- Fleet readiness now comes from:
  - `DispatchPersistenceService.readGuardAssignments()`
  - `DispatchPersistenceService.readGuardSyncOperations()`
- Added partner-scope feed refresh handling in `GovernancePage.didUpdateWidget(...)`.

Important implementation note:

- `GuardSyncRepository` does not actually expose PSIRA or driver license expiry fields by itself.
- To avoid fabricated compliance values, the implementation uses real guard assignment scope from guard sync plus real expiry data from the admin directory.
- If the admin directory is unavailable, compliance remains `Pending live feed` instead of falling back to invented numbers.

## Validation

- `dart analyze /Users/zaks/omnix_dashboard/lib/main.dart /Users/zaks/omnix_dashboard/lib/ui/onyx_route_governance_builders.dart /Users/zaks/omnix_dashboard/lib/ui/governance_page.dart /Users/zaks/omnix_dashboard/test/ui/governance_page_widget_test.dart`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/governance_page_widget_test.dart --plain-name "governance page stays stable on phone viewport"`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/governance_page_widget_test.dart --plain-name "governance page renders live operational feeds when available"`

Result:

- No fabricated compliance, vigilance, or fleet values remain in the live Governance path.
