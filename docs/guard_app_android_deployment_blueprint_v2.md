# ONYX Guard App (Android) Deployment Blueprint V2

## 1. Canonical Architecture Decision

Canonical source of truth for field operations is:
- `public.guard_ops_events` (append-only event log)

Projection/materialized-support tables remain valid for operational read models:
- `guard_assignments`
- `guard_location_heartbeats`
- `guard_checkpoint_scans`
- `guard_incident_captures`
- `guard_panic_signals`

Rule:
- Write once to `guard_ops_events` first.
- Projection tables are derived/updated by sync workers or backend processors.
- No parallel "competing" write paths as system-of-record.

## 2. Objective

Deliver an Android-first Guard App integrated with ONYX command/control that supports:
- dispatch receive and acknowledgement
- guard status updates
- NFC checkpoint verification
- mandatory patrol verification images
- shift-start verification image
- panic signaling
- GPS heartbeat tracking
- wearable heartbeat ingestion
- offline queue with deterministic sync to Supabase
- device health telemetry

## 3. Core Operational Principles

- Offline-first:
  all guard actions are locally committed before remote sync.
- Append-only:
  guard events are immutable.
- Deterministic ordering:
  per-shift monotonic `sequence`.
- Idempotent sync:
  duplicate sync attempts cannot create duplicate events.
- Media decoupling:
  media retries are independent of event sync.

## 4. Event Model (Tier-1 minimum)

Required event types:
- `SHIFT_START`
- `SHIFT_END`
- `SHIFT_VERIFICATION_IMAGE`
- `GPS_HEARTBEAT`
- `DISPATCH_RECEIVED`
- `DISPATCH_ACKED`
- `STATUS_CHANGED`
- `CHECKPOINT_SCANNED`
- `PATROL_IMAGE_CAPTURED`
- `PANIC_TRIGGERED`
- `PANIC_CLEARED`
- `WEARABLE_HEARTBEAT`
- `INCIDENT_REPORTED`
- `DEVICE_HEALTH`
- `SYNC_STATUS`

Required event fields:
- `event_id`
- `guard_id`
- `site_id`
- `shift_id`
- `sequence`
- `occurred_at`
- `event_type`
- `payload` (jsonb)
- `device_id`
- `app_version`

## 5. Supabase Contract (V2)

Primary event table:
- `public.guard_ops_events`

Important constraints:
- unique `(shift_id, sequence)`
- unique `event_id`
- trigger to reject `UPDATE` and `DELETE`

Indexes:
- `(site_id, occurred_at desc)`
- `(guard_id, occurred_at desc)`
- `(shift_id, sequence)`

Media metadata table:
- `public.guard_ops_media`

Fields:
- `media_id`
- `event_id`
- `guard_id`
- `site_id`
- `shift_id`
- `bucket`
- `path`
- `local_path`
- `captured_at`
- `uploaded_at`
- `sha256`
- `upload_status` (`queued`, `uploaded`, `failed`)
- `retry_count`
- `failure_reason`
- `visual_norm_mode` (`day`, `night`, `ir`)
- `visual_norm_metadata` (baseline/profile/threshold contract)

Storage buckets:
- `guard-shift-verification`
- `guard-patrol-images`
- `guard-incident-media`

## 6. Done vs Next

### Done
- [x] Guard operational tiers modeled.
- [x] Guard mobile domain core objects/services implemented.
- [x] Guard sync repository fallback path implemented.
- [x] GuardOpsRepository append-only event model implemented with local queue.
- [x] Android guard shell exists for:
  shift start, dispatch, status, checkpoint, panic, sync.
- [x] Mandatory shift verification image capture enforced.
- [x] Mandatory patrol verification image capture enforced.
- [x] Periodic + manual sync flow implemented with retry/backoff status.
- [x] Sync diagnostics surfaced:
  pending counts, failed counts, last success/failure, recent sync history.
- [x] Sync diagnostics extended with filter-aware row copy actions.
- [x] Replay and closeout export actions now persist last-copy audit metadata for operator handoff traceability.
- [x] Sync panel now surfaces a computed health state:
  `Healthy`, `Degraded`, `At Risk`, `Local Only`.
- [x] Guard sync report copy action implemented for escalation handoffs.
- [x] Queue depth + backend mode surfaced in app runtime hints.
- [x] Baseline guard sync migration exists.
- [x] Canonical event/media migration files created.
- [x] Operational Memory Engine architecture doc added.
- [x] Media quality gate path added for shift/patrol captures (blur/low-light/glare checks).
- [x] Day/night/IR visual norm metadata now persists with guard media records, including metadata constraints (`min_match_score` range + IR requirement contract).
- [x] Morning Sovereign Report flow added with 06:00 auto-generation (22:00-06:00 replay window), plus JSON/CSV export and share/email delivery actions.
- [x] Outcome labeling path added in guard flow (`true_threat`, `false_alarm`, `suspicious_activity`).
- [x] Outcome labeling metadata now captured: confidence + confirmation source.
- [x] Governance enforcement active: `true_threat` requires supervisor confirmation.
- [x] Governance policy is now config-driven by incident label + confirmer role.
- [x] Labeled incident events now include governance audit metadata (`policy_version`, `rule_id`).
- [x] Governance decision telemetry surfaced: denied-label counters + dashboard visibility.
- [x] Governance telemetry persists across restarts with 24h/7d trend visibility.
- [x] Dashboard operator action added to clear governance telemetry after review.
- [x] Governance telemetry export actions added (JSON/CSV clipboard export).
- [x] Downloadable governance telemetry pack actions added (JSON/CSV file download on web).
- [x] Mobile/web share adapter path added for governance telemetry pack export.
- [x] Guard sync failure trace now supports copy/download/share export sinks.
- [x] Wearable + device telemetry ingestion adapter scaffold wired into guard sync flow.
- [x] Web email-bridge export path added for supervisor failure-trace handoff.
- [x] Policy-gated operational coaching prompts now surface in guard sync UI.
- [x] Telemetry adapter supports HTTP provider connectors with env-config fallback to demo.
- [x] Coaching prompts now surface in dispatch/checkpoint contexts when risk priority is medium/high.
- [x] Coaching prompts can be acknowledged and are persisted as guard sync audit events.
- [x] Coaching prompt snooze windows implemented with supervisor-only override for high-priority prompts.
- [x] Coaching snooze windows now persist across app restarts via dispatch persistence cache.
- [x] Snooze-expiry telemetry events now emit when suppressed prompts reactivate.
- [x] Dashboard now surfaces coaching telemetry KPIs/history (ack/snooze/expiry).
- [x] Integration test coverage added for airplane-mode flow, reconnect sync, and duplicate prevention.
- [x] Guard media quality evaluator upgraded with pixel-level analysis + heuristic fallback.
- [x] Native Android telemetry adapter scaffold added via MethodChannel (wearable + device health).
- [x] Guard telemetry now records adapter identity + stub/live mode in event payloads and runtime hints.
- [x] Guard mobile Sync UI now displays telemetry adapter identity and stub/live mode.
- [x] Guard telemetry adapters now expose readiness probes (`ready/degraded/error`) and provider status in Guard Sync UI.
- [x] Android native telemetry now routes by provider registry with explicit unknown-provider error reporting.
- [x] Guard sync queue now marks Supabase operations `queued` → `synced` instead of deleting rows, preserving remote replay/audit history.
- [x] Guard Sync UI now supports status-filtered history views (`queued`, `synced`, `failed`, `all`) from Supabase-backed operations.
- [x] Failed-operation triage now includes selected operation detail and direct retry (`failed` → `queued` with retry count increment).
- [x] Failed-operation triage now supports scoped bulk retry from current history view.
- [x] Guard Sync history now persists selected filter + selected operation context across restarts.
- [x] App lifecycle resume now triggers immediate guard sync in backend mode (reconnect-aware catch-up).
- [x] Lifecycle reconnect path now emits `SYNC_STATUS` event metadata (`sync_reason: app_resumed`) before sync execution.
- [x] Resume-triggered `SYNC_STATUS` event writes are throttled (20s window) to avoid lifecycle spam while still forcing immediate sync.
- [x] Guard Sync UI and export summaries now surface resume-sync trigger count per active shift.
- [x] Guard Sync "Copy Sync Report" action now persists audit metadata and renders last-copy label in Sync UI.
- [x] Guard Sync includes "Clear Export Audits" action to reset sync/replay/closeout export audit labels between handoff cycles.
- [x] Guard Sync now persists and surfaces "Last export audit reset" metadata in UI and export payloads.
- [x] Export audit resets now emit `SYNC_STATUS` events (`export_audits_cleared`) for replayable operational traceability.
- [x] Failed-op KPI alert thresholds are runtime-configurable via `ONYX_GUARD_FAILED_OPS_*`, `ONYX_GUARD_OLDEST_FAILED_*`, and `ONYX_GUARD_FAILED_RETRY_*` env keys.
- [x] Native telemetry bridge writer contract implemented with retry/backoff and UI-driven bridge seeding (`ingestWearableHeartbeatBridge`).
- [x] Android FSK SDK callback receiver contract added (`ingestFskSdkHeartbeat` + `FskSdkBridgeReceiver`) with shared bridge-store persistence.
- [x] Android `TelemetrySdkFacade` + `FskSdkFacadeStub` wiring added so real SDK clients can be swapped in without channel/store changes.
- [x] `FskSdkFacadeLive` + heartbeat mapper scaffold added for direct SDK callback wiring without changing bridge/store contracts.
- [x] Android live SDK facade runtime toggle added via `BuildConfig.USE_LIVE_FSK_SDK` (Gradle property) with manifest metadata override.
- [x] Android live SDK facade now supports broadcast callback ingestion (`ONYX_FSK_SDK_HEARTBEAT_ACTION` / `onyx.fsk_sdk_heartbeat_action`) for provider-specific heartbeat adapter wiring.
- [x] Native telemetry status diagnostics now expose provider-catalog introspection (`listTelemetryProviders`) so misconfigured `provider_id` errors include available provider hints.
- [x] Live FSK callback ingestion now accepts vendor alias payload keys (snake/camel/vendor variants) to reduce integration friction across SDK broadcast formats.
- [x] Live FSK facade now supports pluggable payload adapters (`standard`, `legacy_ptt`) selected via Gradle/manifest, with active adapter surfaced in provider diagnostics.
- [x] Live FSK ingest now supports per-heartbeat adapter override keys (`payload_adapter`/`adapter_id`) for mixed vendor callback formats.
- [x] Provider-specific payload adapter profile added (`hikvision_guardlink`) with replay fixture + validation script support.
- [x] Native telemetry provider registry now includes `hikvision_sdk`/`hikvision_sdk_stub` with dedicated runtime config keys and callback/debug method paths (`ingestHikvisionSdkHeartbeat`, `emitDebugHikvisionSdkHeartbeatBroadcast`).
- [x] Built-in reflective connector adapters added for both provider families (`FskReflectiveVendorSdkConnector`, `HikvisionReflectiveVendorSdkConnector`) with runtime broadcast fallback.
- [x] Native telemetry channel now exposes payload replay validation (`validateFskPayloadMapping`) with fixture-driven adapter checks before deployment.
- [x] Flutter native telemetry adapter replay/debug flows now auto-select provider-family methods (`validateHikvisionPayloadMapping` / `emitDebugHikvisionSdkHeartbeatBroadcast` for Hikvision; FSK equivalents for FSK providers).
- [x] Android validation/pilot scripts now support provider-aware execution (`--provider fsk_sdk|hikvision_sdk`) with provider-specific heartbeat action and adapter defaults.
- [x] Android `onyx/guard_telemetry` MethodChannel handler is now wired in `MainActivity` with provider registry routing (`android_native_sdk_stub`, `fsk_sdk`, `fsk_sdk_stub`), bridge ingest methods, provider catalog introspection, and debug callback broadcast emission.
- [x] Android native telemetry runtime config now reads Gradle/manifest overrides for live toggle, callback action, and payload adapter (`ONYX_USE_LIVE_FSK_SDK`, `ONYX_FSK_SDK_HEARTBEAT_ACTION`, `ONYX_FSK_SDK_PAYLOAD_ADAPTER`).
- [x] Android live telemetry now supports vendor-specific connector injection (`ONYX_FSK_SDK_CONNECTOR_CLASS` / `onyx.fsk_sdk_connector_class`) via `FskVendorSdkConnector`, with broadcast fallback and connector diagnostics surfaced in provider status.
- [x] Vendor connector loader now supports `(Context)` ctor, `()` ctor, or static `create(Context)` factory for SDK adapter bootstraps.
- [x] Native provider status now reports connector fallback activation (`fsk_vendor_connector_fallback_active`) and downgrades readiness when fallback is active.

### In Progress (Now)
- [x] Canonical event log migration (`guard_ops_events`, `guard_ops_media`) applied to linked Supabase project.
- [x] RLS policies + storage policies finalized and validated in Supabase.
- [x] Retention orchestration now includes canonical replay-safety assessment:
  `apply_guard_ops_retention_plan(...)` + `assess_guard_ops_replay_safety(...)`.

### Next (Execution Order)
1. Replace Android native telemetry stubs with real wearable/device vendor SDK implementations.
2. Implement provider-specific native adapters following [`guard_native_telemetry_sdk_contract.md`](/Users/zaks/omnix_dashboard/docs/guard_native_telemetry_sdk_contract.md).

### Runtime Configuration Keys (Guard Sync Triage)
- `ONYX_GUARD_FAILED_OPS_WARN_THRESHOLD`
- `ONYX_GUARD_FAILED_OPS_CRITICAL_THRESHOLD`
- `ONYX_GUARD_OLDEST_FAILED_WARN_MINUTES`
- `ONYX_GUARD_OLDEST_FAILED_CRITICAL_MINUTES`
- `ONYX_GUARD_FAILED_RETRY_WARN_THRESHOLD`
- `ONYX_GUARD_FAILED_RETRY_CRITICAL_THRESHOLD`
- `ONYX_GUARD_RESUME_SYNC_EVENT_THROTTLE_SECONDS`

## 7. Exit Criteria

Guard Android MVP is deployment-ready when:
- append-only event log is live and enforced
- deterministic per-shift sequencing is verified
- offline queue sync succeeds without duplicates
- media upload retries are independent and reliable
- UI enforces required shift/patrol verification captures
- RLS and auth scopes are enforced
- pilot acceptance tests pass

## 8. Operational Memory Alignment

This blueprint is now aligned with the ONYX Operational Memory Engine specification:
- [onyx_operational_memory_engine.md](/Users/zaks/omnix_dashboard/docs/onyx_operational_memory_engine.md)
- [guard_pilot_config_matrix.md](/Users/zaks/omnix_dashboard/docs/guard_pilot_config_matrix.md)

Execution model:
- Stage 1: reliable capture + replay
- Stage 2: supervised coaching + welfare prompts
- Stage 3: multi-signal intelligence fusion
- Stage 4: predictive patrol optimization

12-week KPI roadmap and governance requirements are tracked in the Operational Memory Engine document and should be treated as release gates, not optional improvements.
