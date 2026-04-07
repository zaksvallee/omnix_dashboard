# Codex Summary — CRM Report Crash Fix (2026-04-07)

## Batch
- Fixed the CRM report-generation crash caused by force-unwrapping `aggregate.slaProfile` when the CRM event stream does not contain an SLA profile event.
- Removed fabricated guard compliance identifiers from CRM report projections.

## What Changed

### Null-safe SLA profile fallback
- Updated `lib/domain/crm/reporting/report_bundle_assembler.dart`.
- Replaced the `aggregate.slaProfile!` force-unwrap with an `effectiveSlaProfile`.
- Fallback behavior:
  - use the attached CRM SLA profile when present
  - otherwise derive a default profile from the assigned CRM tier
  - if no tier exists either, fall back to `SLATier.protect`
- Result: report generation no longer crashes when the CRM stream is missing a profile-creation event.

### Guard PII fix
- Updated `lib/domain/crm/reporting/dispatch_performance_projection.dart`.
- Guard snapshots now:
  - use real directory-backed name / PSIRA / rank when supplied
  - use `guardId` only when no directory profile exists
  - leave `psiraNumber` and `rank` empty instead of fabricating values
- Result: client-facing reports never invent compliance identifiers.

### Optional Admin Directory enrichment
- Added `GuardReportingProfile` to `lib/domain/crm/reporting/report_sections.dart`.
- Added optional guard-profile loading to `lib/application/report_generation_service.dart`.
- Wired the live reports UI in `lib/ui/client_intelligence_reports_page.dart` to load Admin Directory guard data through `AdminDirectoryService` when Supabase is available.
- Failures in that enrichment path are ignored safely, so report generation still completes.

## Validation
- `flutter test /Users/zaks/omnix_dashboard/test/domain/crm/reporting/report_bundle_assembler_test.dart /Users/zaks/omnix_dashboard/test/domain/crm/reporting/dispatch_performance_projection_test.dart /Users/zaks/omnix_dashboard/test/application/report_generation_service_test.dart`
- `dart analyze`

## Tests Added / Updated
- `test/domain/crm/reporting/report_bundle_assembler_test.dart`
  - verifies report assembly succeeds when CRM events omit an SLA profile
- `test/domain/crm/reporting/dispatch_performance_projection_test.dart`
  - verifies no fabricated PSIRA / rank when directory data is missing
  - verifies real directory data is used when available

## Outcome
- CRM report generation is now resilient to incomplete CRM event streams.
- Guard identity data in client reports is now truthful and non-fabricated.
