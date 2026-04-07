# Codex Summary — Theme Batch 1 + Domain Coverage

- Date: 2026-04-07
- Workspace: `/Users/zaks/omnix_dashboard`
- Scope: token unblock, morning report P1 fix, theme migration batch 1, highest-risk domain coverage tranche

## Completed

### 1. Missing token unblock

- Added `OnyxColorTokens.accentSky` and `OnyxDesignTokens.accentSky` in:
  - `/Users/zaks/omnix_dashboard/lib/ui/theme/onyx_design_tokens.dart`
- Also added `OnyxDesignTokens.surfaceInset` alias during the theme migration so feature files can map inset/tinted surfaces cleanly.

### 2. Morning sovereign report P1 fix

- Fixed `_partnerDispatchStatusFromName` so unknown partner status strings map to `PartnerDispatchStatus.unknown` instead of silently defaulting to `accepted`.
- Added explicit `unknown` handling to downstream labels/reasons and enum consumers.
- Files touched:
  - `/Users/zaks/omnix_dashboard/lib/application/morning_sovereign_report_service.dart`
  - `/Users/zaks/omnix_dashboard/lib/domain/events/partner_dispatch_status_declared.dart`
  - `/Users/zaks/omnix_dashboard/lib/ui/events_review_page.dart`
  - `/Users/zaks/omnix_dashboard/lib/ui/admin_page.dart`
  - `/Users/zaks/omnix_dashboard/lib/ui/dispatch_page.dart`
  - `/Users/zaks/omnix_dashboard/lib/ui/governance_page.dart`
  - `/Users/zaks/omnix_dashboard/lib/ui/live_operations_page.dart`
  - `/Users/zaks/omnix_dashboard/test/application/morning_sovereign_report_service_test.dart`

### 3. Theme migration batch 1

- Migrated these screens without changing layout or logic:
  - `/Users/zaks/omnix_dashboard/lib/ui/app_shell.dart`
  - `/Users/zaks/omnix_dashboard/lib/ui/governance_page.dart`
  - `/Users/zaks/omnix_dashboard/lib/ui/dispatch_page.dart`
  - `/Users/zaks/omnix_dashboard/lib/ui/client_intelligence_reports_page.dart`
  - `/Users/zaks/omnix_dashboard/lib/ui/tactical_page.dart`
- Pattern applied:
  - file-private light palette constants remapped to `OnyxDesignTokens`
  - shared `0xFF8FD1FF` usages moved to token-backed accent constants/helpers where touched
  - the tactical and dispatch white glass overlays moved to token-backed glass surfaces
  - key white card/button surfaces were moved onto token-backed panel/card colors
- Expectation-only widget assertions were updated where the new panel color is intentionally no longer white:
  - `/Users/zaks/omnix_dashboard/test/ui/governance_page_widget_test.dart`
  - `/Users/zaks/omnix_dashboard/test/ui/dispatch_page_widget_test.dart`

### 4. Domain coverage tranche

- Added the first 5 high-risk domain test files from the audit:
  - `/Users/zaks/omnix_dashboard/test/domain/aggregate/dispatch_aggregate_test.dart`
  - `/Users/zaks/omnix_dashboard/test/domain/projection/operations_health_projection_test.dart`
  - `/Users/zaks/omnix_dashboard/test/domain/incidents/risk/incident_risk_projection_test.dart`
  - `/Users/zaks/omnix_dashboard/test/domain/crm/sla_tier_factory_test.dart`
  - `/Users/zaks/omnix_dashboard/test/domain/crm/sla_tier_projection_test.dart`
- Covered:
  - dispatch aggregate ordering and multi-dispatch independence
  - operations health counters, response averaging, health status scoring, pressure index, and truncation caps
  - incident risk tag extraction, score summing, and severity boundaries
  - SLA tier minute/weight thresholds per tier
  - SLA tier projection empty/client/latest/unknown-tier cases
- Hardened:
  - `/Users/zaks/omnix_dashboard/lib/domain/crm/sla_tier_projection.dart`
  - unknown tier names now return `null` instead of throwing during projection rebuild

## Validation

### Focused analyze passes

- `dart analyze /Users/zaks/omnix_dashboard/lib/ui/theme/onyx_design_tokens.dart`
- `dart analyze` on the morning sovereign report batch files
- `dart analyze` on each migrated screen with its affected widget test:
  - app shell
  - governance
  - dispatch
  - client reports
  - tactical
- `dart analyze` on the 5 domain files + 5 new domain tests
- final full repo `dart analyze`

### Focused tests

- `/Users/zaks/omnix_dashboard/test/application/morning_sovereign_report_service_test.dart`
- `/Users/zaks/omnix_dashboard/test/ui/app_shell_widget_test.dart`
- `/Users/zaks/omnix_dashboard/test/ui/governance_page_widget_test.dart`
- `/Users/zaks/omnix_dashboard/test/ui/dispatch_page_widget_test.dart`
- `/Users/zaks/omnix_dashboard/test/ui/client_intelligence_reports_page_widget_test.dart`
- `/Users/zaks/omnix_dashboard/test/ui/tactical_page_widget_test.dart`
- `/Users/zaks/omnix_dashboard/test/domain/aggregate/dispatch_aggregate_test.dart`
- `/Users/zaks/omnix_dashboard/test/domain/projection/operations_health_projection_test.dart`
- `/Users/zaks/omnix_dashboard/test/domain/incidents/risk/incident_risk_projection_test.dart`
- `/Users/zaks/omnix_dashboard/test/domain/crm/sla_tier_factory_test.dart`
- `/Users/zaks/omnix_dashboard/test/domain/crm/sla_tier_projection_test.dart`

## Remaining

- Theme migration batch 1 is complete for the 5 requested screens, but there are still untouched raw light-theme literals deeper in some screens. The private palettes and primary blockers are migrated; a future cleanup pass can finish the remaining one-off accent literals if needed.
- Domain coverage still has the rest of the audit backlog open after this first 5-file tranche.
