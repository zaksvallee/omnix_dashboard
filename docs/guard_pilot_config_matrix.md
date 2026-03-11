# ONYX Guard Pilot Config Matrix

Last updated: 2026-03-05 (Africa/Johannesburg)

## 1. Flutter Runtime (`--dart-define`)

Create your local config from the committed template:

```bash
cp config/onyx.local.example.json config/onyx.local.json
```

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
  --require-direct-sdk-connector \
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
- `ONYX_FSK_SDK_PAYLOAD_ADAPTER` (`standard`, `legacy_ptt`, or `hikvision_guardlink`)
- `ONYX_FSK_SDK_CONNECTOR_CLASS` (optional fully-qualified Kotlin class implementing `FskVendorSdkConnector`)
- `ONYX_FSK_SDK_MANAGER_CLASS_CANDIDATES` (optional comma-separated FSK manager class candidates for reflective lookup)
- `ONYX_FSK_SDK_ARTIFACT` (optional path to FSK vendor SDK `.aar`/`.jar`)
- `ONYX_FSK_SDK_MAVEN_COORD` (optional Maven coordinate for FSK SDK, for example `com.vendor:fsk-sdk:1.2.3`)
- `ONYX_USE_LIVE_HIKVISION_SDK` (`true` enables live Hikvision facade)
- `ONYX_HIKVISION_SDK_HEARTBEAT_ACTION` (broadcast action for Hikvision SDK callback)
- `ONYX_HIKVISION_SDK_PAYLOAD_ADAPTER` (`standard`, `legacy_ptt`, or `hikvision_guardlink`)
- `ONYX_HIKVISION_SDK_CONNECTOR_CLASS` (optional fully-qualified Kotlin class implementing `FskVendorSdkConnector`)
- `ONYX_HIKVISION_SDK_MANAGER_CLASS_CANDIDATES` (optional comma-separated Hikvision manager class candidates for reflective lookup)
- `ONYX_HIKVISION_SDK_ARTIFACT` (optional path to Hikvision SDK `.aar`/`.jar`)
- `ONYX_HIKVISION_SDK_MAVEN_COORD` (optional Maven coordinate for Hikvision SDK, for example `com.vendor:hikvision-sdk:4.5.6`)

Default behavior note:
- When `ONYX_USE_LIVE_FSK_SDK=true` or `ONYX_USE_LIVE_HIKVISION_SDK=true` and no connector class is provided, ONYX now defaults to built-in reflective vendor connectors and only falls back to broadcast mode if reflective startup fails.
- Vendor SDK dependency loading supports:
  - drop-in files in `android/app/libs/*.aar|*.jar`
  - Gradle property artifact path (`ONYX_*_SDK_ARTIFACT`)
  - Gradle property Maven coordinate (`ONYX_*_SDK_MAVEN_COORD`)

Build example:

```bash
./gradlew :app:assembleDebug \
  -PONYX_USE_LIVE_FSK_SDK=true \
  -PONYX_FSK_SDK_HEARTBEAT_ACTION=com.onyx.fsk.SDK_HEARTBEAT \
  -PONYX_FSK_SDK_PAYLOAD_ADAPTER=standard \
  -PONYX_FSK_SDK_CONNECTOR_CLASS=com.example.omnix_dashboard.telemetry.FskReflectiveVendorSdkConnector \
  -PONYX_FSK_SDK_ARTIFACT=libs/fsk-sdk.aar \
  -PONYX_USE_LIVE_HIKVISION_SDK=true \
  -PONYX_HIKVISION_SDK_HEARTBEAT_ACTION=com.onyx.hikvision.SDK_HEARTBEAT \
  -PONYX_HIKVISION_SDK_PAYLOAD_ADAPTER=hikvision_guardlink \
  -PONYX_HIKVISION_SDK_CONNECTOR_CLASS=com.example.omnix_dashboard.telemetry.HikvisionReflectiveVendorSdkConnector \
  -PONYX_HIKVISION_SDK_ARTIFACT=libs/hikvision-sdk.aar
```

On-device callback validation helper:

```bash
./scripts/guard_android_field_validation.sh \
  --provider fsk_sdk \
  --action com.onyx.fsk.SDK_HEARTBEAT \
  --samples 5 \
  --interval 1 \
  --adapter standard
```

Connector doctor (preflight strict direct-SDK validation):

```bash
./scripts/guard_android_connector_doctor.sh --provider fsk_sdk
```

One-command vendor SDK rollout + connector verification:

```bash
./scripts/guard_android_vendor_sdk_rollout.sh \
  --provider fsk_sdk \
  --sdk-artifact android/app/libs/fsk-sdk.aar \
  --connector-class com.onyx.vendor.fsk.LiveSdkConnector \
  --manager-classes com.onyx.vendor.fsk.LiveSdkManager
```

Auto-discover manager classes from artifact (recommended when class names are unknown):

```bash
./scripts/guard_android_vendor_sdk_rollout.sh \
  --provider fsk_sdk \
  --sdk-artifact android/app/libs/fsk-sdk.aar \
  --connector-class com.onyx.vendor.fsk.LiveSdkConnector \
  --auto-manager-classes
```

Vendor artifact class inspection helper:

```bash
./scripts/guard_android_vendor_sdk_inspect.sh \
  --artifact android/app/libs/fsk-sdk.aar \
  --provider fsk_sdk
```

End-to-end artifact capture helper:

```bash
./scripts/guard_android_live_validation.sh \
  --provider fsk_sdk \
  --action com.onyx.fsk.SDK_HEARTBEAT \
  --samples 5 \
  --interval 1 \
  --adapter standard \
  --expected-provider fsk_sdk
```

Hikvision artifact capture helper:

```bash
./scripts/guard_android_live_validation.sh \
  --provider hikvision_sdk \
  --action com.onyx.hikvision.SDK_HEARTBEAT \
  --samples 5 \
  --interval 1 \
  --adapter hikvision_guardlink \
  --expected-provider hikvision_sdk
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
- In pre-device mode, the selected `--provider` must match the runtime config provider
  in `config/onyx.local.json` (`ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER` /
  `ONYX_GUARD_TELEMETRY_REQUIRED_PROVIDER`) or the gate fails by design.

One-command Android pilot gate:

```bash
./scripts/guard_android_pilot_gate.sh \
  --provider fsk_sdk \
  --action com.onyx.fsk.SDK_HEARTBEAT \
  --samples 5 \
  --interval 1 \
  --adapter standard \
  --expected-provider fsk_sdk \
  --require-real-device-artifacts \
  --max-report-age-hours 12
```

Hikvision one-command Android pilot gate:

```bash
./scripts/guard_android_pilot_gate.sh \
  --provider hikvision_sdk \
  --action com.onyx.hikvision.SDK_HEARTBEAT \
  --samples 5 \
  --interval 1 \
  --adapter hikvision_guardlink \
  --expected-provider hikvision_sdk \
  --require-real-device-artifacts \
  --max-report-age-hours 12
```

Direct connector gate behavior:
- `guard_android_pilot_gate.sh` now requires a direct SDK connector by default and fails if live mode falls back to broadcast.
- `guard_android_pilot_gate.sh` runs connector doctor automatically under strict mode.
- Strict mode also fails if the active connector is explicitly `broadcast_intent_connector`.
- Use `--allow-broadcast-fallback` only for intentional non-production debug runs.

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
  --require-direct-sdk-connector \
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
