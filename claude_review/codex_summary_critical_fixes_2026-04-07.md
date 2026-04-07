# Codex Summary — Critical Fixes

- Date: 2026-04-07
- Scope:
  - `lib/application/cctv_false_positive_policy.dart`
  - `lib/application/guard_sync_repository.dart`
- Status: implemented and validated

## Implemented

### CRITICAL BUG 1 — Missing JSON hour fields no longer widen into all-day suppression

- File: `/Users/zaks/omnix_dashboard/lib/application/cctv_false_positive_policy.dart`
- Fix:
  - `start_hour_local` or `end_hour_local` missing in JSON now marks the parsed rule inactive instead of defaulting to `0/0`.
  - Rules whose parsed start and end hours resolve to the same value are now logged and skipped.
  - `startHourLocal == endHourLocal` no longer acts as an all-hours wildcard in `matches()`.
- Safety effect:
  - Misconfigured JSON can no longer silently suppress real alarms for every hour of the day.

### CRITICAL BUG 2 — Confidence suppression semantics corrected

- File: `/Users/zaks/omnix_dashboard/lib/application/cctv_false_positive_policy.dart`
- Fix:
  - Suppression now applies only to low-confidence nuisance detections.
  - High-confidence detections are no longer suppressed by `min_confidence_percent`.
- Assumption used:
  - I implemented the contract described in the request: suppressing high-confidence detections is wrong, so `min_confidence_percent` is treated as the upper confidence ceiling for suppressible noise.

### CRITICAL BUG 3 — Guard sync Supabase writes are no longer delete-first

- File: `/Users/zaks/omnix_dashboard/lib/application/guard_sync_repository.dart`
- Fix:
  - `saveAssignments(...)` now upserts first, then prunes stale scoped rows only after the upsert succeeds.
  - `saveQueuedOperations(...)` now upserts first, then prunes stale queued rows only after the upsert succeeds.
  - Empty-list saves still clear the scoped rows directly, because there is no insert phase to confirm first.
- Safety effect:
  - A failed insert/upsert can no longer wipe existing assignments or queued operations before replacement data is stored.

## Added Tests

### CCTV false-positive policy

- File: `/Users/zaks/omnix_dashboard/test/application/cctv_false_positive_policy_test.dart`
- Coverage added:
  - missing hour fields -> inactive rule
  - same-hour parse result -> invalid rule skipped
  - low-confidence suppression inside a standard window
  - standard-window exclusive end-hour behavior
  - midnight-crossing window behavior

### CCTV bridge integration

- File: `/Users/zaks/omnix_dashboard/test/application/cctv_bridge_service_test.dart`
- Coverage updated:
  - false-positive bridge integration now proves low-confidence nuisance suppression instead of high-confidence suppression

### Guard sync Supabase path

- File: `/Users/zaks/omnix_dashboard/test/application/guard_sync_repository_test.dart`
- Coverage added:
  - `saveAssignments(...)` does not delete when upsert fails
  - `saveAssignments(...)` performs upsert before prune
  - `saveQueuedOperations(...)` does not delete when upsert fails
  - `saveQueuedOperations(...)` performs upsert before prune

## Validation

- `dart analyze /Users/zaks/omnix_dashboard/lib/application/cctv_false_positive_policy.dart /Users/zaks/omnix_dashboard/lib/application/guard_sync_repository.dart /Users/zaks/omnix_dashboard/test/application/cctv_false_positive_policy_test.dart /Users/zaks/omnix_dashboard/test/application/cctv_bridge_service_test.dart /Users/zaks/omnix_dashboard/test/application/guard_sync_repository_test.dart`
- `flutter test /Users/zaks/omnix_dashboard/test/application/cctv_false_positive_policy_test.dart /Users/zaks/omnix_dashboard/test/application/cctv_bridge_service_test.dart /Users/zaks/omnix_dashboard/test/application/guard_sync_repository_test.dart`

Result:

- `dart analyze`: passed
- `flutter test`: all passed
