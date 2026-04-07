# Codex Summary — AUTO Batch 2 — 2026-04-07

Implemented AUTO findings across Telegram operational commands, monitoring watch continuity, ledger UI Supabase usage, and admin-page Supabase injection seams.

## Implemented

### 1. Telegram service regex bug
- Fixed `/Users/zaks/omnix_dashboard/lib/application/onyx_telegram_operational_command_service.dart`
- Changed `RegExp(r'\\s+')` to `RegExp(r'\s+')` in `_humanizeScopeLabel(...)`
- Added regression coverage in `/Users/zaks/omnix_dashboard/test/application/onyx_telegram_operational_command_service_test.dart`
  - verifies derived scope labels collapse repeated whitespace cleanly

### 2. Monitoring watch transient-error streak preservation
- Fixed `/Users/zaks/omnix_dashboard/lib/application/monitoring_watch_continuous_visual_service.dart`
- Added `_ContinuousVisualCameraState.lastKnownGoodStreak`
- Transient HTTP / decode / exception paths now preserve the active streak instead of resetting it to zero
- Added regression coverage in `/Users/zaks/omnix_dashboard/test/application/monitoring_watch_continuous_visual_service_test.dart`
  - verifies a transient error mid-streak preserves the count and the next healthy sweep continues from that streak

### 3. Supabase UI F1 — ledger page repository seam
- Fixed `/Users/zaks/omnix_dashboard/lib/ui/ledger_page.dart`
- Replaced the raw `Supabase.instance.client.from(...).select(...)` query with `ClientLedgerRepository.listLedgerRows(...)`
- Added `listLedgerRows(...)` to:
  - `/Users/zaks/omnix_dashboard/lib/domain/evidence/client_ledger_repository.dart`
  - `/Users/zaks/omnix_dashboard/lib/infrastructure/events/supabase_client_ledger_repository.dart`
  - `/Users/zaks/omnix_dashboard/lib/infrastructure/events/in_memory_client_ledger_repository.dart`
- Added widget coverage in `/Users/zaks/omnix_dashboard/test/ui/ledger_page_widget_test.dart`
  - verifies Supabase-backed rows load through the injected ledger repository

### 4. Supabase UI F2 — admin page site-identity repository injection
- Fixed `/Users/zaks/omnix_dashboard/lib/ui/admin_page.dart`
- Added constructor-time repository injection seam:
  - `siteIdentityRegistryRepositoryBuilder`
- Replaced inline `SupabaseSiteIdentityRegistryRepository(...)` construction with the injected resolver
- Wired the production route in `/Users/zaks/omnix_dashboard/lib/ui/onyx_route_system_builders.dart`

### 5. Supabase UI F3 — admin page client-messaging repository injection
- Fixed `/Users/zaks/omnix_dashboard/lib/ui/admin_page.dart`
- Added constructor-time repository injection seam:
  - `clientMessagingBridgeRepositoryBuilder`
- Replaced inline `SupabaseClientMessagingBridgeRepository(...)` construction in:
  - bridge creation flow
  - client onboarding save path
  - site onboarding save path
- Wired the production route in `/Users/zaks/omnix_dashboard/lib/ui/onyx_route_system_builders.dart`

## Validation

### Analyze
- `dart analyze`  
  Result: `No issues found!`

### Focused tests
- `flutter test /Users/zaks/omnix_dashboard/test/application/onyx_telegram_operational_command_service_test.dart`
- `flutter test /Users/zaks/omnix_dashboard/test/application/monitoring_watch_continuous_visual_service_test.dart`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/ledger_page_widget_test.dart`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart --plain-name "system tab renders telegram visitor proposal queue"`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart --plain-name "client comms bridge keeps link wording across dialog actions"`

All passed.
