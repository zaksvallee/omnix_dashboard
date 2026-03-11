# ONYX Guard App Deployment Status Checklist

Last updated: 2026-03-11 (Africa/Johannesburg)

## Completed
- [x] Supabase guard sync tables migrated and linked:
  `guard_sync_operations`, `guard_assignments`, `guard_location_heartbeats`,
  `guard_checkpoint_scans`, `guard_incident_captures`, `guard_panic_signals`.
- [x] Canonical append-only event log + media metadata tables deployed:
  `guard_ops_events`, `guard_ops_media`.
- [x] RLS/storage policies for guard media buckets validated:
  `guard-shift-verification`, `guard-patrol-images`, `guard-incident-media`.
- [x] Projection retention migration added:
  `202603050008_add_guard_projection_retention.sql` with
  `public.apply_guard_projection_retention(...)` and run-audit table.
- [x] Guard retention orchestration + canonical replay-safety checks added:
  `202603050009_add_guard_ops_replay_safety_retention.sql` with
  `public.assess_guard_ops_replay_safety(...)` and
  `public.apply_guard_ops_retention_plan(...)`.
- [x] Guard storage + RLS readiness check views migrated:
  `202603050010_add_guard_rls_storage_readiness_checks.sql` with
  `public.guard_storage_readiness_checks` and
  `public.guard_rls_readiness_checks`.
- [x] Guard readiness SQL smoke-check script added:
  [guard_readiness_smoke_checks.sql](/Users/zaks/omnix_dashboard/supabase/sql/guard_readiness_smoke_checks.sql).
- [x] Guard actor-contract SQL compatibility script added:
  [guard_actor_contract_checks.sql](/Users/zaks/omnix_dashboard/supabase/sql/guard_actor_contract_checks.sql)
  validates actor-context payload keys in recent `guard_ops_events`.
- [x] Pilot readiness command now supports strict live telemetry gating:
  `./scripts/guard_pilot_readiness_check.sh --enforce-live-telemetry`
  validates native SDK enabled + stub disabled + non-stub provider ID.
- [x] Android field callback validation helper added:
  [guard_android_field_validation.sh](/Users/zaks/omnix_dashboard/scripts/guard_android_field_validation.sh)
  emits test FSK heartbeat broadcasts over `adb` for live facade verification.
- [x] Android live telemetry validation runbook + artifact collector added:
  [guard_android_live_validation_runbook.md](/Users/zaks/omnix_dashboard/docs/guard_android_live_validation_runbook.md),
  [guard_android_live_validation.sh](/Users/zaks/omnix_dashboard/scripts/guard_android_live_validation.sh).
- [x] Android live telemetry artifact auto-report gate added:
  [guard_android_live_validation_report.sh](/Users/zaks/omnix_dashboard/scripts/guard_android_live_validation_report.sh).
- [x] Runtime live-ready telemetry enforcement added:
  `ONYX_GUARD_TELEMETRY_ENFORCE_LIVE_READY=true` forces telemetry payload
  health to `at_risk` if provider readiness is not `ready` or facade mode is
  not `live`.
- [x] Runtime telemetry provider-ID enforcement added:
  `ONYX_GUARD_TELEMETRY_REQUIRED_PROVIDER` validates active provider identity
  under live-ready gate and records expected vs active IDs in sync payloads.
- [x] Pilot readiness live-telemetry gate now validates required-provider config:
  required provider defaults to native provider when unset, and mismatches are
  surfaced as warnings for operator review.
- [x] Pilot readiness script now supports hardware-evidence gating:
  `--require-live-validation-artifacts` requires the latest
  `tmp/guard_field_validation/*/validation_report.md` to be `PASS`.
- [x] Hardware-evidence gate now enforces report freshness:
  `--max-live-validation-report-age-hours` (default `24`) rejects stale
  validation reports.
- [x] Android validation report now enforces provider/live-facade evidence:
  required provider ingest trace match + live-facade trace lines.
- [x] One-command Android pilot gate added:
  [guard_android_pilot_gate.sh](/Users/zaks/omnix_dashboard/scripts/guard_android_pilot_gate.sh)
  chains live validation, report generation, and readiness gating.
- [x] Direct SDK connector gate added for pilot validation:
  live-validation report/readiness now support `--require-direct-sdk-connector`
  and fail when live mode falls back to broadcast connector paths.
- [x] Android connector doctor added:
  [guard_android_connector_doctor.sh](/Users/zaks/omnix_dashboard/scripts/guard_android_connector_doctor.sh)
  verifies provider-specific startup markers and direct-connector fallback status
  before strict pilot gates.
- [x] Vendor SDK rollout helper added:
  [guard_android_vendor_sdk_rollout.sh](/Users/zaks/omnix_dashboard/scripts/guard_android_vendor_sdk_rollout.sh)
  installs provider-specific live builds with SDK artifact/Maven overrides and
  immediately runs connector doctor verification.
- [x] Vendor SDK artifact inspector added:
  [guard_android_vendor_sdk_inspect.sh](/Users/zaks/omnix_dashboard/scripts/guard_android_vendor_sdk_inspect.sh)
  extracts class names from `.aar/.jar` files and suggests manager/callback candidates
  for rollout flags.
- [x] Android Gradle vendor SDK injection paths added for connector rollout:
  local drop-in artifacts (`android/app/libs/*.aar|*.jar`) plus optional
  `ONYX_FSK_SDK_ARTIFACT` / `ONYX_HIKVISION_SDK_ARTIFACT` and
  `ONYX_FSK_SDK_MAVEN_COORD` / `ONYX_HIKVISION_SDK_MAVEN_COORD`, including
  manager-candidate overrides via `ONYX_FSK_SDK_MANAGER_CLASS_CANDIDATES` /
  `ONYX_HIKVISION_SDK_MANAGER_CLASS_CANDIDATES`.
- [x] Validation report now emits machine-readable JSON:
  `validation_report.json` with `overall_status`, metrics, and gate booleans;
  readiness artifact gate prefers JSON over markdown parsing.
- [x] Readiness artifact gate now verifies JSON evidence checksums:
  SHA-256 hashes from `validation_report.json` must match on-disk evidence files.
- [x] Mock artifact generator added for no-device gate simulation:
  [guard_android_mock_validation_artifacts.sh](/Users/zaks/omnix_dashboard/scripts/guard_android_mock_validation_artifacts.sh).
- [x] Readiness now supports real-device-only evidence gating:
  `--require-real-device-artifacts` rejects mock artifact directories.
- [x] Auditable readiness wrapper added:
  [guard_pilot_gate_report.sh](/Users/zaks/omnix_dashboard/scripts/guard_pilot_gate_report.sh)
  emits `gate_report.json` + readiness log per gate run.
- [x] `GuardSyncRepository` stack implemented:
  shared-prefs local store, Supabase repository, fallback wrapper.
- [x] `GuardOpsRepository` implemented with deterministic per-shift sequencing,
  idempotent remote upsert contract, retry handling, and media decoupling.
- [x] Native telemetry diagnostics improved:
  provider registry introspection + alias-tolerant FSK heartbeat payload parsing.
- [x] Provider-specific native payload adapter profile added:
  `hikvision_guardlink` now supported in Android callback validation and replay fixtures.
- [x] Native telemetry provider registry now includes a dedicated Hikvision path:
  `hikvision_sdk` + `hikvision_sdk_stub` with live/stub runtime toggles and callback/debug endpoints.
- [x] Built-in reflective vendor connectors are available for both native provider
  families (`FskReflectiveVendorSdkConnector`, `HikvisionReflectiveVendorSdkConnector`)
  with safe broadcast fallback when vendor SDK classes are absent.
- [x] Live telemetry runtime now defaults to built-in reflective connectors when
  `ONYX_USE_LIVE_FSK_SDK=true` / `ONYX_USE_LIVE_HIKVISION_SDK=true` and no explicit
  connector class is configured; broadcast mode is used only as fallback on
  reflective startup failure.
- [x] Flutter native telemetry adapter now routes replay/debug method calls by
  provider family (`validateHikvisionPayloadMapping` / `emitDebugHikvisionSdkHeartbeatBroadcast`
  for Hikvision, FSK variants for FSK), while preserving legacy FSK helper APIs.
- [x] Android validation gate scripts now support provider-aware routing end-to-end
  (`--provider fsk_sdk|hikvision_sdk`) with provider-specific action/adapter defaults:
  `guard_android_live_validation.sh`, `guard_android_pilot_gate.sh`, `guard_gate_auto.sh`.
- [x] Supabase project link established in CLI and remote migration parity restored;
  `202603090001_add_guard_ops_media_visual_norm_metadata.sql` is applied remotely.
- [x] Guard readiness smoke checks executed against linked remote project:
  retention dry-run RPC calls succeeded and storage/RLS readiness views are fully `PASS`.
- [x] Guard actor-contract compatibility check validated with non-empty recent data:
  `recent_rows=3`, all actor-context key-missing counters `0`, overall status `PASS`.
- [x] Real-device strict Android pilot gates passed for both provider families
  (`fsk_sdk`, `hikvision_sdk`) using `--require-real-device-artifacts --full-tests`.
- [x] Sync/export artifacts now include telemetry payload health summaries
  (verdict/reason + callback error counters/timestamps).
- [x] Sync panel now includes telemetry payload health trend (`last 5` sync
  status events) for operator drift detection.
- [x] Telemetry payload health deterioration now emits replayable
  `SYNC_STATUS` alert events (severity + trend + reason, throttled).
- [x] Sync KPI surface now shows telemetry payload alert count + latest
  alert timestamp per active shift.
- [x] Export Audit Timeline now supports a `Telemetry Alerts` filter for
  payload-health deterioration events.
- [x] Sync panel includes one-click `Copy Telemetry Alerts Only` export for
  controller handoff.
- [x] Guard Sync UI now includes payload replay validation actions (`standard`, `legacy_ptt`) with inline normalized-output panel for operator checks.
- [x] Guard app shell screens implemented:
  shift start, dispatch, status, checkpoint, panic, sync.
- [x] Shift verification image and patrol image quality-gated capture flows wired.
- [x] Guard sync diagnostics and triage surfaced in UI:
  queue depth, failed rows, retry actions, export/report copy actions.
- [x] Clients route backend persistence path validated against Supabase repository.
- [x] Guard sync local history behavior normalized and tested:
  deterministic ordering + status/facade filtering parity with Supabase.
- [x] Pilot runtime configuration matrix documented:
  [guard_pilot_config_matrix.md](/Users/zaks/omnix_dashboard/docs/guard_pilot_config_matrix.md).
- [x] Controller UI compactness pass completed across core command routes:
  dashboard, dispatch, events, sites, guards, ledger, reports, plus adaptive
  shell sidebar behavior for typical desktop widths.
- [x] Widget smoke coverage added for compact command surfaces:
  [events_page_widget_test.dart](/Users/zaks/omnix_dashboard/test/ui/events_page_widget_test.dart),
  [sites_page_widget_test.dart](/Users/zaks/omnix_dashboard/test/ui/sites_page_widget_test.dart),
  [guards_page_widget_test.dart](/Users/zaks/omnix_dashboard/test/ui/guards_page_widget_test.dart),
  [reports_page_widget_test.dart](/Users/zaks/omnix_dashboard/test/ui/reports_page_widget_test.dart).
- [x] Consolidated UI regression suite passed (48 tests) after compactness
  rollout and telemetry/triage dashboard integration.
- [x] Chrome runtime preflight with local config passed:
  `flutter run -d chrome --dart-define-from-file=config/onyx.local.json`
  launched successfully with Supabase init and no immediate runtime layout
  exceptions observed.

## In Progress
- [ ] Native telemetry provider swap from scaffold/stub to production SDK adapters
  (FSK and later Hikvision-related telemetry providers).
- [ ] End-to-end live hardware validation on Android field devices.

## Next Execution Steps
1. Implement real Android telemetry SDK adapter(s) behind `TelemetrySdkFacade`
   and `GuardTelemetryIngestionAdapter` contracts.
2. Run on-device integration tests for:
   wearable heartbeat, device health, callback ingestion, reconnect sync.
3. Run and schedule retention orchestration (`apply_guard_ops_retention_plan`)
   in the linked Supabase project and review `guard_ops_retention_runs`.
4. Apply the config matrix to each pilot environment and capture per-site
   overrides (provider IDs, adapter mode, feed keys).
5. Execute pilot-site runbook:
   shift start -> checkpoint/image -> panic -> sync/replay closeout.

## Operator Command
- Local pilot readiness command:
  `./scripts/guard_pilot_readiness_check.sh`
- Include full test suite:
  `./scripts/guard_pilot_readiness_check.sh --full-tests`

## Release Gate
- [ ] Zero critical runtime errors on Android pilot devices.
- [ ] Offline queue replay proven without duplicates.
- [ ] RLS/auth scopes verified for guard-only data access.
- [ ] Control room confirms replay/export artifacts are sufficient for audit.
