# Guard Sync Supabase Contract

This document defines the backend contract for Android Guard App sync operations.

Migration source:
- [20260304_create_guard_sync_tables.sql](/Users/zaks/omnix_dashboard/supabase/migrations/20260304_create_guard_sync_tables.sql)

## Tables

### `public.guard_sync_operations`
Offline queue journal for idempotent operation replay.

Required write fields:
- `operation_id`
- `operation_type`
- `operation_status` (`queued` default, plus `synced`/`failed` in sync workers)
- `client_id`
- `site_id`
- `guard_id`
- `occurred_at`
- `payload` (JSON)

Read patterns:
- newest queued operations by `operation_status`, `occurred_at`
- operation history by `client_id`/`site_id`/`guard_id`

Uniqueness:
- `(client_id, site_id, guard_id, operation_id)`

### `public.guard_assignments`
Dispatch assignment + duty status.

Required write fields:
- `assignment_id`
- `dispatch_id`
- `client_id`
- `site_id`
- `guard_id`
- `duty_status`
- `issued_at`
- optional `acknowledged_at`

### `public.guard_location_heartbeats`
GPS heartbeat stream.

Required write fields:
- `heartbeat_id`
- `client_id`
- `site_id`
- `guard_id`
- `latitude`
- `longitude`
- `recorded_at`
- optional `accuracy_meters`

### `public.guard_checkpoint_scans`
NFC patrol verification records.

Required write fields:
- `scan_id`
- `client_id`
- `site_id`
- `guard_id`
- `checkpoint_id`
- `nfc_tag_id`
- `scanned_at`
- optional `latitude`/`longitude`

### `public.guard_incident_captures`
Media metadata records for captured photo/video.

Required write fields:
- `capture_id`
- `client_id`
- `site_id`
- `guard_id`
- `media_type` (`photo` or `video`)
- `local_reference` (or uploaded object reference)
- `captured_at`
- optional `dispatch_id`

### `public.guard_panic_signals`
Emergency panic activations.

Required write fields:
- `signal_id`
- `client_id`
- `site_id`
- `guard_id`
- `triggered_at`
- optional `latitude`/`longitude`

## Indexing & Updated Timestamps
All tables include:
- `created_at` / `updated_at`
- update trigger `public.set_guard_sync_updated_at()`
- indexes for `(client_id, site_id, guard_id, <time desc>)`

## Security Requirements
Before production:
- enable and validate RLS policies per table
- enforce guard/tenant scoping by `client_id` and `site_id`
- ensure anon/service role access is constrained to expected workflows

## Operational Notes
- Heartbeats will grow fastest; define retention and archival policy.
- Sync workers should treat `operation_id` as the idempotency key.
- Keep payload schema forward-compatible; version payload fields if needed.
- Use `public.apply_guard_ops_retention_plan(...)` for scheduled retention runs.
  This prunes projection tables and records replay-safety checks for canonical
  `guard_ops_events` before any archival decision.
