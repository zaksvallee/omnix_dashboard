# ONYX Guard Validation Signoff (2026-03-11)

Date: 2026-03-11 (Africa/Johannesburg)

## Scope
- Real-device Android pilot validation for both telemetry provider families.
- Remote Supabase readiness/retention smoke checks.
- Actor-context contract verification against recent `guard_ops_events` rows.

## Android Pilot Gates

### FSK provider (`fsk_sdk`)
- Command profile: `--provider fsk_sdk --action com.onyx.fsk.SDK_HEARTBEAT --adapter standard --samples 5 --interval 1 --require-real-device-artifacts --full-tests`
- Overall status: `PASS`
- Generated at (UTC): `2026-03-11T11:21:05Z`
- Metrics:
  - `broadcast_count`: 5
  - `telemetry_line_count`: 66
  - `ingest_line_count`: 20
  - `accepted_count`: 5
  - `rejected_count`: 0
  - `provider_match_count`: 1
  - `live_facade_trace_count`: 10
- Artifact dir: `tmp/guard_field_validation/pilot-20260311T112042Z`

### Hikvision provider (`hikvision_sdk`)
- Command profile: `--provider hikvision_sdk --action com.onyx.hikvision.SDK_HEARTBEAT --adapter hikvision_guardlink --samples 5 --interval 1 --config tmp/onyx.local.hikvision.json --require-real-device-artifacts --full-tests`
- Overall status: `PASS`
- Generated at (UTC): `2026-03-11T11:22:03Z`
- Metrics:
  - `broadcast_count`: 5
  - `telemetry_line_count`: 66
  - `ingest_line_count`: 20
  - `accepted_count`: 5
  - `rejected_count`: 0
  - `provider_match_count`: 1
  - `live_facade_trace_count`: 10
- Artifact dir: `tmp/guard_field_validation/pilot-20260311T112141Z`

## Supabase Remote Validation
- Project link: `mnbloeoiiwenlywnnoxe`
- Migration sync state: local and remote aligned through `202603090001`.
- Retention readiness RPC checks executed:
  - `public.apply_guard_projection_retention(90, 30, 'pilot_readiness_dry_run')`
  - `public.apply_guard_ops_retention_plan(90, 30, 365, 'pilot_readiness_dry_run')`
- Result highlights:
  - Projection retention run completed with `deleted_*` counts at `0`.
  - Retention plan run completed with `replay_safe = true` and `guard_ops_pruned = false`.
  - `guard_storage_readiness_checks`: all `PASS`.
  - `guard_rls_readiness_checks`: all `PASS`.

## Actor Contract Validation
- Recent event window: latest 200 rows from `public.guard_ops_events`.
- Seeded validation rows: 3 events (SHIFT_START, STATUS_CHANGED, SYNC_STATUS) with full actor keys.
- Result:
  - `recent_rows`: 3
  - `missing_actor_role`: 0
  - `missing_actor_guard_id`: 0
  - `missing_actor_client_id`: 0
  - `missing_actor_site_id`: 0
  - `missing_actor_shift_id`: 0
  - `overall_status`: `PASS`

## Notes
- Pilot gate config passthrough bug was fixed in `scripts/guard_android_pilot_gate.sh` (commit `9bcecba`) so readiness checks honor `--config` for provider-specific runs.
