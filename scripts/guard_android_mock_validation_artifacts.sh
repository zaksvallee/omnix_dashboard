#!/usr/bin/env bash
set -euo pipefail

OUT_DIR=""
PROVIDER_ID="${ONYX_GUARD_TELEMETRY_REQUIRED_PROVIDER:-${ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER:-fsk_sdk}}"
SAMPLES=5

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/guard_android_mock_validation_artifacts.sh [--out-dir <path>] [--provider <provider-id>] [--samples 5]

Purpose:
  Generates synthetic Android validation artifacts for local/CI gate verification
  when a physical adb device is unavailable.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --provider)
      PROVIDER_ID="${2:-fsk_sdk}"
      shift 2
      ;;
    --samples)
      SAMPLES="${2:-5}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "FAIL: Unknown argument: $1"
      exit 1
      ;;
  esac
done

if ! [[ "$SAMPLES" =~ ^[0-9]+$ ]] || [[ "$SAMPLES" -lt 1 ]]; then
  echo "FAIL: --samples must be a positive integer."
  exit 1
fi

if [[ -z "$OUT_DIR" ]]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  OUT_DIR="tmp/guard_field_validation/mock-$stamp"
fi
mkdir -p "$OUT_DIR"

{
  echo "Device serial: MOCK-DEVICE"
  echo "Broadcast action: com.onyx.fsk.SDK_HEARTBEAT"
  echo "Adapter mode: standard"
  echo "Expected provider: $PROVIDER_ID"
  echo "Samples: $SAMPLES"
  echo "Interval (s): 1"
  echo "Run started (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "ONYX_TELEMETRY lines: $((SAMPLES * 3))"
  echo "Run completed (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$OUT_DIR/summary.txt"

: > "$OUT_DIR/broadcasts.txt"
: > "$OUT_DIR/logcat_onyx_telemetry.txt"
: > "$OUT_DIR/logcat_ingest_trace.txt"

for ((i = 1; i <= SAMPLES; i++)); do
  captured_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "sent sample=$i captured_at_utc=$captured_at" >> "$OUT_DIR/broadcasts.txt"
  echo "I/ONYX_TELEMETRY: facade_ingest adapter=standard payloadKeys=[activity_state,battery_percent,captured_at_utc,gps_accuracy_meters,heart_rate,movement_level]" >> "$OUT_DIR/logcat_onyx_telemetry.txt"
  echo "I/ONYX_TELEMETRY: sdk_callback_received adapter=standard callback_count=$i captured_at_utc=$captured_at" >> "$OUT_DIR/logcat_onyx_telemetry.txt"
  echo "I/ONYX_TELEMETRY: ingestFskSdkHeartbeat result accepted=true captured_at_utc=$captured_at message=Wearable heartbeat bridge payload ingested." >> "$OUT_DIR/logcat_onyx_telemetry.txt"
  echo "I/ONYX_TELEMETRY: ingestFskSdkHeartbeat requested provider=$PROVIDER_ID payloadKeys=[activity_state,battery_percent,captured_at_utc,gps_accuracy_meters,heart_rate,movement_level]" >> "$OUT_DIR/logcat_ingest_trace.txt"
done

cat "$OUT_DIR/logcat_onyx_telemetry.txt" "$OUT_DIR/logcat_ingest_trace.txt" > "$OUT_DIR/logcat_full.txt"
echo "MOCK-MODEL" > "$OUT_DIR/device_model.txt"
echo "14" > "$OUT_DIR/android_version.txt"
echo "Battery Service state: mock" > "$OUT_DIR/battery_before.txt"
echo "Battery Service state: mock" > "$OUT_DIR/battery_after.txt"

./scripts/guard_android_live_validation_report.sh \
  --artifact-dir "$OUT_DIR" \
  --required-provider "$PROVIDER_ID"

echo "PASS: Mock validation artifacts generated: $OUT_DIR"
echo "Report: $OUT_DIR/validation_report.json"
