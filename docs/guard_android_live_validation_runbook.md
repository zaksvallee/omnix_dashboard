# ONYX Android Live Telemetry Validation Runbook

Last updated: 2026-03-11 (Africa/Johannesburg)

## Objective

Prove end-to-end live callback ingestion on Android guard devices with evidence artifacts.

## Preconditions

- Android device connected over `adb`.
- ONYX app installed/running with live native telemetry config.
- ONYX app starts foreground PTT listener service on launch (`ONYX PTT listener active` notification).
- If hardware key emits raw `KEY_F1` (no broadcast intent), enable `ONYX PTT Key Bridge` accessibility service in Android settings.
- Local runtime config exists at `config/onyx.local.json` (bootstrap once from template).
- `ONYX_GUARD_TELEMETRY_NATIVE_SDK=true`
- `ONYX_GUARD_TELEMETRY_NATIVE_STUB=false`
- `ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER=fsk_sdk` (or `hikvision_sdk`)
- Live heartbeat action configured (`ONYX_FSK_SDK_HEARTBEAT_ACTION`, `ONYX_HIKVISION_SDK_HEARTBEAT_ACTION`, or explicit `--action`).

Bootstrap command:

```bash
cp config/onyx.local.example.json config/onyx.local.json
```

## Step 0: Connection doctor (required before on-device run)

```bash
./scripts/guard_android_connection_doctor.sh
```

Expected:
- `adb` available.
- At least one device in `device` state.

If this step fails, do not run live validation yet.

## Step 0.5: Connector doctor (required for strict direct-SDK gates)

```bash
./scripts/guard_android_connector_doctor.sh --provider fsk_sdk
```

Expected:
- Detects live facade startup marker for selected provider.
- Reports no broadcast fallback traces when vendor SDK classes are present.

Optional one-command rollout (install + connector doctor):

```bash
./scripts/guard_android_vendor_sdk_rollout.sh \
  --provider fsk_sdk \
  --sdk-artifact android/app/libs/fsk-sdk.aar \
  --connector-class com.onyx.vendor.fsk.LiveSdkConnector \
  --manager-classes com.onyx.vendor.fsk.LiveSdkManager
```

If exactly one provider-matching `.aar/.jar` is already present under `android/app/libs`, you can omit `--sdk-artifact` and the script auto-detects it.

If manager class names are unknown, you can let rollout auto-discover candidates:

```bash
./scripts/guard_android_vendor_sdk_rollout.sh \
  --provider fsk_sdk \
  --sdk-artifact android/app/libs/fsk-sdk.aar \
  --connector-class com.onyx.vendor.fsk.LiveSdkConnector \
  --auto-manager-classes
```

If vendor class names are unknown, inspect the SDK artifact first:

```bash
./scripts/guard_android_vendor_sdk_inspect.sh \
  --artifact android/app/libs/fsk-sdk.aar \
  --provider fsk_sdk
```

If your handset integration uses a non-default heartbeat broadcast action (for example a Zello button action), set it during rollout:

```bash
./scripts/guard_android_vendor_sdk_rollout.sh \
  --provider fsk_sdk \
  --heartbeat-action com.zello.ptt.down \
  --allow-broadcast-fallback
```

Validation note for Zello actions:
- `com.zello.*` actions are often ordered broadcasts where Zello receivers can abort delivery.
- `guard_android_live_validation.sh` now auto-targets ONYX package for `com.zello.*` test injections (or use `--target-package`) so callback parsing can still be validated.

## Step 1: Local readiness gate

```bash
./scripts/guard_pilot_readiness_check.sh --enforce-live-telemetry
```

Expected:
- Live telemetry gate passes.
- Analyze + targeted guard tests pass.

After generating validation report (Step 5), enforce artifact gate:

```bash
./scripts/guard_pilot_readiness_check.sh --enforce-live-telemetry --require-live-validation-artifacts
```

Optional stricter freshness gate (example 12h):

```bash
./scripts/guard_pilot_readiness_check.sh \
  --enforce-live-telemetry \
  --require-live-validation-artifacts \
  --max-live-validation-report-age-hours 12
```

Optional real-device-only evidence gate:

```bash
./scripts/guard_pilot_readiness_check.sh \
  --enforce-live-telemetry \
  --require-live-validation-artifacts \
  --require-direct-sdk-connector \
  --require-real-device-artifacts \
  --max-live-validation-report-age-hours 12
```

Alternative single-command gate:

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

Note:
- `guard_android_pilot_gate.sh` now runs `guard_android_connection_doctor.sh` automatically.
- `guard_android_pilot_gate.sh` now runs `guard_android_connector_doctor.sh` automatically when direct connector enforcement is enabled.
- Use `--skip-connection-doctor` only if you already validated device connectivity in the same session.
- Use `--skip-connector-doctor` only if you intentionally want to defer connector verification.
- `guard_android_pilot_gate.sh` now enforces direct SDK connector mode by default and fails when live mode falls back to broadcast. Use `--allow-broadcast-fallback` only for intentional debug validation.

Optional auditable wrapper report:

```bash
./scripts/guard_pilot_gate_report.sh -- \
  --enforce-live-telemetry \
  --require-live-validation-artifacts \
  --require-direct-sdk-connector \
  --require-real-device-artifacts \
  --max-live-validation-report-age-hours 12
```

Pre-device one-command gate (no phone connected):

```bash
./scripts/guard_predevice_gate.sh --samples 3 --max-report-age-hours 24
```

Unified auto-gate (uses on-device gate when phone is connected, otherwise pre-device gate):

```bash
./scripts/guard_gate_auto.sh \
  --provider fsk_sdk \
  --action com.onyx.fsk.SDK_HEARTBEAT \
  --samples 5 \
  --interval 1 \
  --adapter standard \
  --expected-provider fsk_sdk \
  --max-report-age-hours 24
```

If `--provider` differs from the runtime provider in the selected config and you did not pass `--config`, `guard_gate_auto.sh` now creates a temporary provider-aligned config under `tmp/onyx.auto.*.json` automatically.

Operator preflight (analyze + tests + auto-gate in one command):

```bash
./scripts/onyx_ops_preflight.sh
```

Provider-specific preflight example (Hikvision, fallback allowed while SDK binary is pending):

```bash
./scripts/onyx_ops_preflight.sh \
  --provider hikvision_sdk \
  --allow-broadcast-fallback
```

No-device simulation (for CI/local pipeline checks):

```bash
./scripts/guard_android_mock_validation_artifacts.sh --samples 3
./scripts/guard_pilot_readiness_check.sh \
  --enforce-live-telemetry \
  --require-live-validation-artifacts \
  --max-live-validation-report-age-hours 12
```

## Step 2: Run on-device callback validation

```bash
./scripts/guard_android_live_validation.sh \
  --provider fsk_sdk \
  --action com.onyx.fsk.SDK_HEARTBEAT \
  --samples 5 \
  --interval 1 \
  --adapter standard \
  --expected-provider fsk_sdk
```

Notes:
- By default, the script force-stops and relaunches `com.example.omnix_dashboard/.MainActivity` and waits for a live-facade startup marker before sending samples.
- Use `--skip-start-app` only if you intentionally want to keep the current app process/session.
- On Android 13+ (`TIRAMISU` and above), adb broadcast injection is enabled for debug builds during validation.
- Foreground PTT listener auto-starts on device boot and app update (`BOOT_COMPLETED` / `MY_PACKAGE_REPLACED`). If OEM auto-start restrictions block this on your device, launch ONYX once manually before field tests.
- ONYX also accepts Fast Talkie style intents (`android.intent.action.PTT.down` / `android.intent.action.PTT.up`) in addition to Zello actions, so hardware-key bridge apps can be validated as fallback routing.

Optional for legacy payload format:

```bash
./scripts/guard_android_live_validation.sh \
  --provider fsk_sdk \
  --action com.onyx.fsk.SDK_HEARTBEAT \
  --samples 5 \
  --interval 1 \
  --adapter legacy_ptt \
  --expected-provider fsk_sdk
```

Optional for Hikvision GuardLink payload format:

```bash
./scripts/guard_android_live_validation.sh \
  --provider hikvision_sdk \
  --action com.onyx.hikvision.SDK_HEARTBEAT \
  --samples 5 \
  --interval 1 \
  --adapter hikvision_guardlink \
  --expected-provider hikvision_sdk
```

PTT action discovery helper (use during new handset onboarding):

```bash
./scripts/guard_android_ptt_sniffer.sh --serial <device-serial> --duration 20
```

OEM escalation bundle helper (when locked-screen behavior differs from unlocked):

```bash
./scripts/guard_android_oem_escalation_bundle.sh --serial <device-serial> --duration 15
```

## Step 3: Verify Guard Sync UI during run

In ONYX Guard Sync screen, confirm:

- Provider readiness is `ready`.
- Telemetry adapter matches the configured provider (`native_sdk:fsk_sdk` or `native_sdk:hikvision_sdk`) and mode is `live`.
- Facade callback count increases after emitted samples.
- Last callback timestamp/message updates.
- No critical payload-health alerts are triggered for valid samples.

## Step 4: Collect and store evidence

Script output directory contains:

- `summary.txt`
- `broadcasts.txt`
- `logcat_onyx_telemetry.txt`
- `logcat_ingest_trace.txt`
- `logcat_full.txt`

Attach artifact directory path to pilot validation notes and update deployment checklist.

## Step 5: Generate automated validation report

```bash
./scripts/guard_android_live_validation_report.sh \
  --artifact-dir tmp/guard_field_validation/<timestamp> \
  --required-provider fsk_sdk
```

Output:
- `validation_report.md` inside the artifact directory.
- `validation_report.json` inside the artifact directory.
- `validation_report.json` includes SHA-256 checksums for evidence files.
- Script exits non-zero if required gates fail.
- Provider consistency is enforced: `required_provider` in report artifacts must
  match the configured telemetry gate provider.

## Pass Criteria

- `logcat_onyx_telemetry.txt` contains callback and ingest result lines.
- Guard Sync UI callback counters/timestamps reflect the run.
- No runtime crash during validation window.
- Events continue to sync through repository path after callback ingest.
- `validation_report.md` returns overall status `PASS`.
- `validation_report.json` returns `overall_status: "PASS"`.
- JSON evidence checksums match on-disk artifact files.
- Report confirms provider-matched ingest traces for required provider ID.
- Report confirms live-facade trace lines are present.

## Known Device Limitation (Blackview BV5300 Pro)

- Confirmed on 2026-03-11: side key emits raw Linux input `KEY_F1` (`/dev/input/event0`).
- ONYX bridge captures `KEY_F1` successfully while unlocked via `ONYX PTT Key Bridge` accessibility service.
- While lockscreen is active (`mWakefulness=Dozing`), side-key events are consumed by OEM/keyguard path before app-level handlers; no ONYX ingest logs are emitted.
- `key_bv_left_screen=1` alone did not restore locked-screen delivery in current firmware.

Verification commands:

```bash
adb -s <serial> shell getevent -lt
adb -s <serial> logcat -v time | grep -E --line-buffered "ptt_ingest_accepted|ptt_key_bridge_accepted"
```

Operational guidance:

- For locked-screen PTT, require OEM/system key-routing support that emits app-visible broadcasts while locked.
- Without OEM support, use unlocked/kiosk operation mode for dependable ONYX PTT ingest.
- Use [guard_blackview_oem_escalation_brief.md](/Users/zaks/omnix_dashboard/docs/guard_blackview_oem_escalation_brief.md)
  with generated escalation bundle artifacts when opening OEM support tickets.
