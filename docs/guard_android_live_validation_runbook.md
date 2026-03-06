# ONYX Android Live Telemetry Validation Runbook

Last updated: 2026-03-05 (Africa/Johannesburg)

## Objective

Prove end-to-end live callback ingestion on Android guard devices with evidence artifacts.

## Preconditions

- Android device connected over `adb`.
- ONYX app installed/running with live native telemetry config.
- `ONYX_GUARD_TELEMETRY_NATIVE_SDK=true`
- `ONYX_GUARD_TELEMETRY_NATIVE_STUB=false`
- `ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER=fsk_sdk`
- Live heartbeat action configured (`ONYX_FSK_SDK_HEARTBEAT_ACTION` or explicit `--action`).

## Step 0: Connection doctor (required before on-device run)

```bash
./scripts/guard_android_connection_doctor.sh
```

Expected:
- `adb` available.
- At least one device in `device` state.

If this step fails, do not run live validation yet.

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
  --require-real-device-artifacts \
  --max-live-validation-report-age-hours 12
```

Alternative single-command gate:

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

Note:
- `guard_android_pilot_gate.sh` now runs `guard_android_connection_doctor.sh` automatically.
- Use `--skip-connection-doctor` only if you already validated device connectivity in the same session.

Optional auditable wrapper report:

```bash
./scripts/guard_pilot_gate_report.sh -- \
  --enforce-live-telemetry \
  --require-live-validation-artifacts \
  --require-real-device-artifacts \
  --max-live-validation-report-age-hours 12
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
  --action com.onyx.fsk.SDK_HEARTBEAT \
  --samples 5 \
  --interval 1 \
  --adapter standard \
  --expected-provider fsk_sdk
```

Optional for legacy payload format:

```bash
./scripts/guard_android_live_validation.sh \
  --action com.onyx.fsk.SDK_HEARTBEAT \
  --samples 5 \
  --interval 1 \
  --adapter legacy_ptt \
  --expected-provider fsk_sdk
```

## Step 3: Verify Guard Sync UI during run

In ONYX Guard Sync screen, confirm:

- Provider readiness is `ready`.
- Telemetry adapter is `native_sdk:fsk_sdk` and mode is `live`.
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
