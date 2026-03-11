# ONYX Guard Native Telemetry SDK Contract

This contract defines how Android native telemetry providers integrate with ONYX via `MethodChannel("onyx/guard_telemetry")`.

## Channel Methods

### `getTelemetryProviderStatus`

Input args:

```json
{
  "provider_id": "fsk_sdk"
}
```

### `listTelemetryProviders`

Purpose:
- returns the provider registry catalog so ONYX can surface actionable config hints when `provider_id` is wrong.

Input args:

```json
{
  "provider_id": "fsk_sdk"
}
```

### `validateFskPayloadMapping`

Purpose:
- replay a raw vendor payload through a selected adapter and return normalized ONYX heartbeat fields before field rollout.

Input args:

```json
{
  "provider_id": "fsk_sdk",
  "payload_adapter": "legacy_ptt",
  "payload": {
    "pulse": 81,
    "motion_score": 0.57,
    "state": "patrolling",
    "battery": 88,
    "time_utc": "2026-03-05T14:05:00Z"
  }
}
```

Expected response payload:

```json
{
  "accepted": true,
  "message": "Payload mapped successfully.",
  "adapter_requested": "legacy_ptt",
  "adapter_resolved": "legacy_ptt",
  "available_fsk_payload_adapters": ["standard", "legacy_ptt", "hikvision_guardlink"],
  "normalized_payload": {
    "heart_rate": 81,
    "movement_level": 0.57,
    "activity_state": "patrolling",
    "captured_at_utc": "2026-03-05T14:05:00Z"
  }
}
```

Expected response payload:

```json
{
  "requested_provider_id": "fsk_sdk",
  "default_provider_id": "android_native_sdk_stub",
  "available_provider_ids": [
    "android_native_sdk_stub",
    "hikvision_sdk",
    "hikvision_sdk_stub",
    "fsk_sdk",
    "fsk_sdk_stub"
  ],
  "provider_exists": true,
  "facade_id": "fsk_sdk_facade_live",
  "facade_live_mode": true,
  "facade_toggle_source": "build_config",
  "fsk_heartbeat_action": "com.onyx.fsk.SDK_HEARTBEAT",
  "fsk_heartbeat_action_source": "build_config",
  "fsk_payload_adapter": "standard",
  "fsk_payload_adapter_source": "build_config",
  "available_fsk_payload_adapters": ["standard", "legacy_ptt", "hikvision_guardlink"],
  "fsk_vendor_connector": "broadcast_intent_connector",
  "fsk_vendor_connector_source": "platform_default",
  "fsk_vendor_connector_fallback_active": false,
  "fsk_vendor_connector_error": null,
  "facade_callback_error_count": 0,
  "facade_last_callback_error_at_utc": null,
  "facade_last_callback_error_message": null
}
```

Expected response payload:

```json
{
  "provider_id": "fsk_sdk",
  "readiness": "ready",
  "message": "Native provider connected.",
  "sdk_status": "live",
  "facade_id": "fsk_sdk_facade_live",
  "facade_live_mode": true,
  "facade_toggle_source": "build_config"
}
```

If the provider is unknown:

```json
{
  "provider_id": "unknown_provider",
  "readiness": "error",
  "message": "No telemetry provider registered for unknown_provider.",
  "sdk_status": "error"
}
```

### `captureWearableHeartbeat`

Input args:

```json
{
  "provider_id": "fsk_sdk"
}
```

Expected response payload:

```json
{
  "heart_rate": 79,
  "movement_level": 0.72,
  "activity_state": "patrolling",
  "battery_percent": 91,
  "captured_at_utc": "2026-03-05T10:00:00Z",
  "source": "fsk_sdk",
  "provider_id": "fsk_sdk",
  "sdk_status": "live"
}
```

Required keys:
- `heart_rate`
- `movement_level`
- `activity_state`
- `captured_at_utc`
- `source`
- `provider_id`
- `sdk_status`

Optional keys:
- `battery_percent`

### `captureDeviceHealth`

Input args:

```json
{
  "provider_id": "fsk_sdk"
}
```

Expected response payload:

```json
{
  "battery_percent": 81,
  "gps_accuracy_meters": 5.1,
  "storage_available_mb": 3072,
  "network_state": "5G",
  "device_temperature_c": 34.3,
  "captured_at_utc": "2026-03-05T10:01:00Z",
  "source": "fsk_sdk",
  "provider_id": "fsk_sdk",
  "sdk_status": "live"
}
```

Required keys:
- `battery_percent`
- `gps_accuracy_meters`
- `storage_available_mb`
- `network_state`
- `device_temperature_c`
- `captured_at_utc`
- `source`
- `provider_id`
- `sdk_status`

### `ingestWearableHeartbeatBridge` (helper path)

Input args:

```json
{
  "provider_id": "fsk_sdk",
  "heart_rate": 78,
  "movement_level": 0.74,
  "activity_state": "patrolling",
  "battery_percent": 87,
  "captured_at_utc": "2026-03-05T10:05:00Z",
  "source": "onyx_guard_manual_bridge_seed",
  "sdk_status": "live",
  "gps_accuracy_meters": 4.0
}
```

Expected response payload:

```json
{
  "provider_id": "fsk_sdk",
  "accepted": true,
  "captured_at_utc": "2026-03-05T10:05:00Z",
  "message": "Wearable heartbeat bridge payload ingested."
}
```

ONYX bridge writer behavior:
- retries transient bridge failures with exponential backoff (default 3 attempts)
- treats `accepted: false` as a rejected ingest
- logs and surfaces failures without blocking guard event capture

### `ingestFskSdkHeartbeat` (SDK callback receiver)

Purpose:
- canonical Android receiver path for real FSK SDK callbacks
- normalizes and persists heartbeat payloads into the same bridge store used by `fsk_sdk`

Input args:

```json
{
  "provider_id": "fsk_sdk",
  "heart_rate": 78,
  "movement_level": 0.74,
  "activity_state": "patrolling",
  "battery_percent": 87,
  "captured_at_utc": "2026-03-05T10:05:00Z",
  "gps_accuracy_meters": 4.0
}
```

Expected response payload:

```json
{
  "provider_id": "fsk_sdk",
  "accepted": true,
  "captured_at_utc": "2026-03-05T10:05:00Z",
  "message": "Wearable heartbeat bridge payload ingested."
}
```

### `ingestHikvisionSdkHeartbeat` (SDK callback receiver)

Purpose:
- canonical Android receiver path for Hikvision SDK callbacks
- normalizes and persists heartbeat payloads into the same bridge-store contract used by `hikvision_sdk`

Input args:

```json
{
  "provider_id": "hikvision_sdk",
  "vitals_hr": 82,
  "motion_index": 0.62,
  "duty_state": "patrolling",
  "watch_battery_percent": 86,
  "event_utc": "2026-03-05T10:05:00Z",
  "gps_hdop_m": 4.0
}
```

Expected response payload:

```json
{
  "provider_id": "hikvision_sdk",
  "accepted": true,
  "captured_at_utc": "2026-03-05T10:05:00Z",
  "message": "Wearable heartbeat bridge payload ingested."
}
```

### `emitDebugFskSdkHeartbeatBroadcast` (debug helper)

Purpose:
- emits an Android broadcast on the configured FSK heartbeat action to validate callback wiring end-to-end without vendor SDK hardware.
- available only in debug builds.

Input args:

```json
{
  "provider_id": "fsk_sdk",
  "heart_rate": 77,
  "movement_level": 0.72,
  "activity_state": "patrolling",
  "battery_percent": 88,
  "captured_at_utc": "2026-03-05T10:10:00Z",
  "gps_accuracy_meters": 3.8
}
```

Expected response payload:

```json
{
  "provider_id": "fsk_sdk",
  "accepted": true,
  "captured_at_utc": "2026-03-05T10:10:00Z",
  "action": "com.onyx.fsk.SDK_HEARTBEAT",
  "message": "Debug SDK heartbeat broadcast emitted."
}
```

### `emitDebugHikvisionSdkHeartbeatBroadcast` (debug helper)

Purpose:
- emits an Android broadcast on the configured Hikvision heartbeat action to validate callback wiring end-to-end without vendor SDK hardware.
- available only in debug builds.

Input args:

```json
{
  "provider_id": "hikvision_sdk",
  "vitals_hr": 80,
  "motion_index": 0.66,
  "duty_state": "patrolling",
  "watch_battery_percent": 83,
  "event_utc": "2026-03-05T10:10:00Z",
  "gps_hdop_m": 3.9
}
```

Expected response payload:

```json
{
  "provider_id": "hikvision_sdk",
  "accepted": true,
  "captured_at_utc": "2026-03-05T10:10:00Z",
  "action": "com.onyx.hikvision.SDK_HEARTBEAT",
  "message": "Debug SDK heartbeat broadcast emitted."
}
```

Alias support (Android live facade, applies to broadcast callbacks and direct `ingestFskSdkHeartbeat` payloads):
- `heart_rate`: `heart_rate`, `heartRate`, `hr`, `heartrate`, `heart_rate_bpm`
- `movement_level`: `movement_level`, `movementLevel`, `motion_level`, `movement`, `activity_level`
- `activity_state`: `activity_state`, `activityState`, `state`, `activity`
- `battery_percent`: `battery_percent`, `batteryPercent`, `battery`, `battery_level`
- `captured_at_utc`: `captured_at_utc`, `capturedAtUtc`, `captured_at`, `timestamp`, `time_utc`
- `gps_accuracy_meters`: `gps_accuracy_meters`, `gpsAccuracyMeters`, `gps_accuracy`, `accuracy`, `location_accuracy`

`hikvision_guardlink` adapter alias support:
- `heart_rate`: `vitals_hr`, `heartbeat_bpm`, `watch_hr`, `heart_rate`, `heartRate`, `hr`
- `movement_level`: `motion_index`, `movement_score`, `imu_motion_level`, `movement_level`, `movementLevel`, `motion_level`
- `activity_state`: `duty_state`, `guard_state`, `activity_label`, `activity_state`, `activityState`, `state`
- `battery_percent`: `watch_battery_percent`, `wearable_battery`, `watch_battery`, `battery_percent`, `batteryPercent`, `battery_level`
- `captured_at_utc`: `event_utc`, `event_time_utc`, `captured_time_utc`, `captured_at_utc`, `capturedAtUtc`, `timestamp`
- `gps_accuracy_meters`: `gps_hdop_m`, `location_accuracy_meters`, `fix_accuracy_m`, `gps_accuracy_meters`, `gpsAccuracyMeters`, `location_accuracy`

Per-heartbeat adapter override keys (optional):
- `payload_adapter`
- `payloadAdapter`
- `adapter_id`
- `adapterId`

Live-facade callback error telemetry keys (provider status):
- `facade_callback_error_count`
- `facade_last_callback_error_at_utc`
- `facade_last_callback_error_message`

Vendor connector fallback telemetry keys (provider status):
- `fsk_vendor_connector_fallback_active`
- `fsk_vendor_connector_error`

When provided, ONYX resolves the adapter per heartbeat and falls back to the configured adapter if the override is unknown.

Replay fixtures:
- [fsk_standard_sample.json](/Users/zaks/omnix_dashboard/assets/telemetry_payload_fixtures/fsk_standard_sample.json)
- [fsk_legacy_ptt_sample.json](/Users/zaks/omnix_dashboard/assets/telemetry_payload_fixtures/fsk_legacy_ptt_sample.json)
- [fsk_hikvision_guardlink_sample.json](/Users/zaks/omnix_dashboard/assets/telemetry_payload_fixtures/fsk_hikvision_guardlink_sample.json)

## SDK Status Values

- `stub`: placeholder provider implementation
- `live`: real vendor SDK integration
- `degraded`: provider reachable but partial data
- `error`: provider failed and returned fallback values

## Android Provider Routing

Current Android implementation routes by `provider_id` through a provider registry.

Registered stubs:
- `android_native_sdk_stub`
- `fsk_sdk_stub`
- `hikvision_sdk_stub`

Registered bridge/live path:
- `fsk_sdk` (native bridge provider)
- `hikvision_sdk` (native bridge provider)

When wiring real SDKs, replace/extend registry entries with vendor-backed providers that implement:
- `captureWearableHeartbeat`
- `captureDeviceHealth`
- `status`

`fsk_sdk` currently returns live device-health signals directly from Android and wearable heartbeat from a bridge cache in `SharedPreferences("onyx_guard_telemetry")`:
- `wearable_payload_json` (preferred full JSON payload)
- fallback discrete keys:
  - `wearable_heart_rate`
  - `wearable_movement_level`
  - `wearable_activity_state`
  - `wearable_battery_percent` (optional)
  - `wearable_captured_at_utc`
- optional GPS cache key:
  - `last_gps_accuracy_meters`

SDK integration note:
- wire vendor callbacks into `FskSdkBridgeReceiver.ingestHeartbeatFromSdk(...)`
- do not write directly to shared preferences from SDK glue code
- replace `FskSdkFacadeStub` with a real `TelemetrySdkFacade` implementation that forwards SDK callbacks into the same receiver.
- `FskSdkFacadeLive` now defaults to built-in reflective connector mode when
  live telemetry is enabled, with broadcast fallback only when reflective
  startup fails.
  - Broadcast action default remains `com.onyx.fsk.SDK_HEARTBEAT`.
  - Expected extras mirror `ingestFskSdkHeartbeat` input keys.
  - You can override action via:
    - Gradle: `-PONYX_FSK_SDK_HEARTBEAT_ACTION=...`
    - Manifest meta-data: `onyx.fsk_sdk_heartbeat_action`
- `FskSdkHeartbeatMapper` remains the normalization entrypoint for direct callback object adapters.
- runtime toggle is wired:
  - Gradle property: `-PONYX_USE_LIVE_FSK_SDK=true` (sets `BuildConfig.USE_LIVE_FSK_SDK`)
  - Manifest override: `<meta-data android:name="onyx.use_live_fsk_sdk" android:value="true" />`
  - Gradle property: `-PONYX_USE_LIVE_HIKVISION_SDK=true` (sets `BuildConfig.USE_LIVE_HIKVISION_SDK`)
  - Manifest override: `<meta-data android:name="onyx.use_live_hikvision_sdk" android:value="true" />`
- payload adapter selection is wired:
  - Gradle property: `-PONYX_FSK_SDK_PAYLOAD_ADAPTER=standard|legacy_ptt|hikvision_guardlink`
  - Manifest override: `<meta-data android:name="onyx.fsk_sdk_payload_adapter" android:value="standard" />`
  - Gradle property: `-PONYX_HIKVISION_SDK_PAYLOAD_ADAPTER=standard|legacy_ptt|hikvision_guardlink`
  - Manifest override: `<meta-data android:name="onyx.hikvision_sdk_payload_adapter" android:value="hikvision_guardlink" />`
- optional vendor connector class override is wired:
  - Gradle property: `-PONYX_FSK_SDK_CONNECTOR_CLASS=com.onyx.vendor.fsk.LiveSdkConnector`
  - Manifest override: `<meta-data android:name="onyx.fsk_sdk_connector_class" android:value="com.onyx.vendor.fsk.LiveSdkConnector" />`
  - Gradle property: `-PONYX_HIKVISION_SDK_CONNECTOR_CLASS=com.onyx.vendor.hikvision.LiveSdkConnector`
  - Manifest override: `<meta-data android:name="onyx.hikvision_sdk_connector_class" android:value="com.onyx.vendor.hikvision.LiveSdkConnector" />`
  - built-in reflective connector classes are available:
    - `com.example.omnix_dashboard.telemetry.FskReflectiveVendorSdkConnector`
    - `com.example.omnix_dashboard.telemetry.HikvisionReflectiveVendorSdkConnector`
  - default live-mode connector mapping:
    - `fsk_sdk` -> `com.example.omnix_dashboard.telemetry.FskReflectiveVendorSdkConnector`
    - `hikvision_sdk` -> `com.example.omnix_dashboard.telemetry.HikvisionReflectiveVendorSdkConnector`
  - class must implement `FskVendorSdkConnector`; fallback is broadcast connector when unavailable.
  - loader supports connector instantiation via one of:
    - constructor `(Context)`
    - no-arg constructor `()`
    - static factory `create(Context)`

## Dart Define Flags

Use these flags when running the app:

- `ONYX_GUARD_TELEMETRY_NATIVE_SDK=true`
- `ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER=fsk_sdk` (or `hikvision_sdk`)
- `ONYX_GUARD_TELEMETRY_NATIVE_STUB=false`

## Event Payload Mapping

ONYX guard events (`WEARABLE_HEARTBEAT`, `DEVICE_HEALTH`) persist:

- `source`
- `provider_id`
- `sdk_status`
- `adapter`
- `adapter_stub_mode`

This allows operational analytics to differentiate:
- demo fallback usage
- HTTP connector usage
- native SDK live usage
- native SDK stub/degraded modes
