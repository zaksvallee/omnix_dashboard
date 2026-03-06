# ONYX Guard Pilot Config Matrix

Last updated: 2026-03-05 (Africa/Johannesburg)

## 1. Flutter Runtime (`--dart-define`)

Use a local file for web/dev runs:

```bash
flutter run -d chrome --dart-define-from-file=config/onyx.local.json
```

Wrapper script (recommended):

```bash
./scripts/run_onyx_chrome_local.sh
```

Require Supabase-backed mode (fail fast if keys are missing):

```bash
./scripts/run_onyx_chrome_local.sh --require-supabase
```

Pilot live-telemetry gate command:

```bash
./scripts/guard_pilot_readiness_check.sh --full-tests --enforce-live-telemetry
```

Pilot gate with explicit Supabase configuration enforcement:

```bash
./scripts/guard_pilot_readiness_check.sh \
  --enforce-live-telemetry \
  --require-supabase-config
```

Pilot evidence-enforced gate command (requires latest Android artifact report to be PASS):

```bash
./scripts/guard_pilot_readiness_check.sh --enforce-live-telemetry --require-live-validation-artifacts
```

Pilot evidence freshness override (default max report age is 24h):

```bash
./scripts/guard_pilot_readiness_check.sh \
  --enforce-live-telemetry \
  --require-live-validation-artifacts \
  --max-live-validation-report-age-hours 12
```

Pilot real-device-only evidence gate:

```bash
./scripts/guard_pilot_readiness_check.sh \
  --enforce-live-telemetry \
  --require-live-validation-artifacts \
  --require-real-device-artifacts \
  --max-live-validation-report-age-hours 12
```

Minimum keys for Supabase-backed runs:

```json
{
  "SUPABASE_URL": "https://<project-ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<anon-key>"
}
```

Guard telemetry adapter keys:
- `ONYX_GUARD_TELEMETRY_NATIVE_SDK` (`true` or `false`)
- `ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER` (default `android_native_sdk_stub`)
- `ONYX_GUARD_TELEMETRY_REQUIRED_PROVIDER` (expected provider ID in live-ready gate; defaults to native provider value when unset)
- `ONYX_GUARD_TELEMETRY_NATIVE_STUB` (`true` or `false`)
- `ONYX_GUARD_TELEMETRY_ENFORCE_LIVE_READY` (`true` forces payload health to `at_risk` when provider is not `ready` or facade mode is not `live`)
- `ONYX_WEARABLE_TELEMETRY_URL` (HTTP fallback endpoint)
- `ONYX_DEVICE_HEALTH_URL` (HTTP fallback endpoint)
- `ONYX_GUARD_TELEMETRY_BEARER_TOKEN`
- `ONYX_CLIENT_APP_LOCALE` (`en`, `zu`, `af`; default `en`)

Readiness behavior:
- `--enforce-live-telemetry` validates both native and required provider IDs.
- If required provider is unset, readiness defaults it to the native provider.
- If required provider differs from native provider, readiness emits a warning to flag intentional cross-provider routing.

Guard sync alert threshold keys:
- `ONYX_GUARD_FAILURE_ALERT_THRESHOLD`
- `ONYX_GUARD_QUEUE_ALERT_THRESHOLD`
- `ONYX_GUARD_STALE_SYNC_ALERT_MINUTES`
- `ONYX_GUARD_FAILED_OPS_WARN_THRESHOLD`
- `ONYX_GUARD_FAILED_OPS_CRITICAL_THRESHOLD`
- `ONYX_GUARD_OLDEST_FAILED_WARN_MINUTES`
- `ONYX_GUARD_OLDEST_FAILED_CRITICAL_MINUTES`
- `ONYX_GUARD_FAILED_RETRY_WARN_THRESHOLD`
- `ONYX_GUARD_FAILED_RETRY_CRITICAL_THRESHOLD`
- `ONYX_GUARD_RESUME_SYNC_EVENT_THROTTLE_SECONDS`

Live feed/news ingestion keys:
- `ONYX_LIVE_FEED_URL`
- `ONYX_LIVE_FEED_BEARER_TOKEN`
- `ONYX_LIVE_FEED_HEADERS_JSON`
- `ONYX_LIVE_FEED_POLL_INTERVAL_SECONDS`
- `ONYX_NEWSAPI_ORG_KEY`
- `ONYX_NEWSAPI_AI_KEY`
- `ONYX_NEWSDATA_IO_KEY`
- `ONYX_WORLDNEWSAPI_KEY`
- `ONYX_OPENWEATHER_KEY`
- `ONYX_NEWS_QUERY`
- `ONYX_COMMUNITY_FEED_JSON`
- `ONYX_SITE_LAT`
- `ONYX_SITE_LON`

Optional governance key:
- `ONYX_GUARD_OUTCOME_GOVERNANCE_JSON`

## 2. Android Native Telemetry Toggle (Gradle / Manifest)

Gradle properties used by Android facade:
- `ONYX_USE_LIVE_FSK_SDK` (`true` enables live facade)
- `ONYX_FSK_SDK_HEARTBEAT_ACTION` (broadcast action for SDK callback)
- `ONYX_FSK_SDK_PAYLOAD_ADAPTER` (`standard` or `legacy_ptt`)

Build example:

```bash
./gradlew :app:assembleDebug \
  -PONYX_USE_LIVE_FSK_SDK=true \
  -PONYX_FSK_SDK_HEARTBEAT_ACTION=com.onyx.fsk.SDK_HEARTBEAT \
  -PONYX_FSK_SDK_PAYLOAD_ADAPTER=standard
```

On-device callback validation helper:

```bash
./scripts/guard_android_field_validation.sh \
  --action com.onyx.fsk.SDK_HEARTBEAT \
  --samples 5 \
  --interval 1 \
  --adapter standard
```

End-to-end artifact capture helper:

```bash
./scripts/guard_android_live_validation.sh \
  --action com.onyx.fsk.SDK_HEARTBEAT \
  --samples 5 \
  --interval 1 \
  --adapter standard \
  --expected-provider fsk_sdk
```

Artifact report command:

```bash
./scripts/guard_android_live_validation_report.sh \
  --artifact-dir tmp/guard_field_validation/<timestamp> \
  --required-provider fsk_sdk
```

Note:
- Readiness artifact gate prefers `validation_report.json` and falls back to markdown report if JSON is unavailable.
- When JSON is available, readiness verifies embedded SHA-256 checksums against evidence files.

One-command Android pilot gate:

```bash
./scripts/guard_android_pilot_gate.sh \
  --action com.onyx.fsk.SDK_HEARTBEAT \
  --samples 5 \
  --interval 1 \
  --adapter standard \
  --expected-provider fsk_sdk \
  --require-real-device-artifacts \
  --max-report-age-hours 12
```

No-device fallback (CI/local gate simulation):

```bash
./scripts/guard_android_mock_validation_artifacts.sh --samples 3
./scripts/guard_pilot_readiness_check.sh \
  --enforce-live-telemetry \
  --require-live-validation-artifacts \
  --max-live-validation-report-age-hours 12
```

Auditable readiness JSON wrapper:

```bash
./scripts/guard_pilot_gate_report.sh -- \
  --enforce-live-telemetry \
  --require-supabase-config \
  --require-live-validation-artifacts \
  --require-real-device-artifacts \
  --max-live-validation-report-age-hours 12
```

Outputs:
- `tmp/guard_gate_reports/<timestamp>/gate_report.json`
- `tmp/guard_gate_reports/<timestamp>/readiness_output.log`
- `tmp/guard_gate_reports/<timestamp>/runtime_profile.txt`

Android live-validation artifact directories now also include:
- `runtime_profile.txt`
- `runtime_profile.json`

Runbook:
- [guard_android_live_validation_runbook.md](/Users/zaks/omnix_dashboard/docs/guard_android_live_validation_runbook.md)

## 3. Supabase Operational Retention Command

Run after migration `202603050009_add_guard_ops_replay_safety_retention.sql`:

```sql
select * from public.apply_guard_ops_retention_plan(90, 30, 365, 'pilot_schedule_run');
```

Audit views:
- `public.guard_projection_retention_runs`
- `public.guard_ops_replay_safety_checks`
- `public.guard_ops_retention_runs`

Policy note:
- Canonical `public.guard_ops_events` pruning is disabled by design.
- Replay safety checks are logged before any future archival decision.
