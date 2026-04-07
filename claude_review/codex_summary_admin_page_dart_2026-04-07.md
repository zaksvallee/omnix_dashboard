# Codex Summary: admin_page.dart

- Date: 2026-04-07
- Source report: `/Users/zaks/omnix_dashboard/claude_review/audit_admin_page_dart_2026-04-07.md`
- Scope: `/Users/zaks/omnix_dashboard/lib/ui/admin_page.dart`

## Intake

New Claude review files processed since the last repo commit:

- `/Users/zaks/omnix_dashboard/claude_review/audit_admin_page_dart_2026-04-07.md`

## P1 Classification

1. `P1-1 Duplicate public/private tab enums` -> `AUTO`
2. `P1-2 Stale context risk in _snack/_handleAdminFeedback` -> `AUTO`
3. `P1-3 _desktopWorkspaceActive mutated in build` -> `AUTO`
4. `P1-4 Sequential Supabase queries in _loadDirectoryFromSupabase` -> `AUTO`
5. `P1-5 Domain/persistence logic embedded directly in _AdministrationPageState` -> `REVIEW` (approved)

## P2 Classification

1. `P2-1 Seed-apply / Supabase load race` -> `REVIEW` (approved)
2. `P2-2 Empty setState(() {}) on every keystroke (x4 controllers)` -> `AUTO`
3. `P2-3 Two structurally identical receipt classes` -> `AUTO`

## AUTO Findings Implemented

### P1-1

- Removed the redundant private tab enum bridge.
- `AdministrationPageTab` is now the only tab enum used in `/Users/zaks/omnix_dashboard/lib/ui/admin_page.dart`.
- Deleted the `_adminTabFromPublic` / `_adminTabToPublic` translation helpers.

### P1-2

- Added a top-level `mounted` guard in `_handleAdminFeedback(...)`.
- This hardens both `_snack(...)` and direct `_handleAdminFeedback(...)` call paths without auditing dozens of call sites individually.

### P1-3

- Removed `_desktopWorkspaceActive` state.
- Desktop command-first behavior is now derived from layout:
  - build paths receive the computed `useDesktopWorkspace` flag directly
  - post-build feedback paths use `_usesDesktopWorkspace(...)`
- This removes the build-time state mutation while preserving the existing desktop receipt behavior.

### P1-4

- Parallelized the independent Supabase reads inside `_loadDirectoryFromSupabase()` with `Future.wait(...)`.
- Preserved the existing soft-fail contract for optional `client_messaging_endpoints` and `client_contacts` reads.

### P2-2

- Removed the four empty draft-change listeners that were calling `setState(() {})` on every keystroke.
- The affected editor/runtime surfaces now rebuild only their local subtree via `ListenableBuilder`:
  - radio intent dictionary
  - demo route cues
  - operator runtime
  - partner runtime
- This preserves the live draft/next-move behavior without dirtying the whole admin page on every text change.

### P2-3

- Removed the duplicate receipt payload shape by aliasing `_OnboardingDialogCommandReceipt` to `_AdminCommandReceipt`.
- Admin workspace receipts and onboarding dialog receipts now share one contract instead of two identical classes.

### P2-1

- Approved and implemented with the narrow sequencing change from Option B.
- Added `_refreshDirectoryAfterApprovedTelegramSeedApply()` in `/Users/zaks/omnix_dashboard/lib/ui/admin_page.dart`.
- When approved Telegram seed props change and Supabase is live, the page now awaits `_loadDirectoryFromSupabase()` instead of synchronously re-applying local seed data into widget state.
- In `initState()`, the same awaited refresh path is used when Supabase is live, so the initial optimistic seed overlay no longer races the later Supabase load.
- Offline behavior is preserved: when Supabase is unavailable, approved Telegram seeds still apply locally.

## REVIEW Findings Not Implemented

### P1-5

- Approved and implemented as the first extraction slice.
- Added `/Users/zaks/omnix_dashboard/lib/application/admin/admin_directory_service.dart`.
- Moved the Supabase directory read orchestration, row-to-model mapping, optional-table soft-fail behavior, and parallel fetch pattern out of `/Users/zaks/omnix_dashboard/lib/ui/admin_page.dart`.
- `AdministrationPage` now constructor-injects `AdminDirectoryService`, and `_loadDirectoryFromSupabase()` hydrates widget state from a returned `AdminDirectorySnapshot`.
- Added `/Users/zaks/omnix_dashboard/test/application/admin_directory_service_test.dart` covering:
  - typed row mapping and lane telemetry mapping
  - optional endpoint/contact fetch recovery without losing core directory rows

## Validation

Final validation after the `AUTO` fixes:

- `dart analyze /Users/zaks/omnix_dashboard/lib/ui/admin_page.dart /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart --plain-name "administration page can start on system tab from parent state"`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart --plain-name "build demo stack close returns focus to the generated site in sites tab"`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart --plain-name "system tab invokes radio queue action callbacks"`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart --plain-name "system tab can import identity rules json into runtime"`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart --plain-name "administration page edits site rows in place"`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart --plain-name "administration page edits guard rows in place"`
- `dart analyze /Users/zaks/omnix_dashboard/lib/application/admin/admin_directory_service.dart /Users/zaks/omnix_dashboard/lib/ui/admin_page.dart /Users/zaks/omnix_dashboard/test/application/admin_directory_service_test.dart /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart`
- `flutter test /Users/zaks/omnix_dashboard/test/application/admin_directory_service_test.dart`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart --plain-name "client onboarding preview pins dialog and admin receipts for copy snapshot"`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart --plain-name "system tab telegram lead command pins desktop receipt"`
- `dart analyze /Users/zaks/omnix_dashboard/lib/ui/admin_page.dart /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart --plain-name "system tab can update operator runtime in app"`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart --plain-name "system tab preserves operator runtime field when reset persistence fails"`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart --plain-name "system tab validates and saves radio intent dictionary"`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart --plain-name "system tab preserves demo route cue draft when reset persistence fails"`
- `dart analyze`
- `dart analyze /Users/zaks/omnix_dashboard/lib/ui/admin_page.dart /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart --plain-name "system tab shows telegram wiring checklist guidance"`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart --plain-name "system tab polls cctv from telegram camera bridge seed"`
- `flutter test /Users/zaks/omnix_dashboard/test/ui/admin_page_widget_test.dart --plain-name "build demo stack close returns focus to the generated site in sites tab"`

All of the above passed.
