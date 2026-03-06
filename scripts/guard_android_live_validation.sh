#!/usr/bin/env bash
set -euo pipefail

ACTION="${ONYX_FSK_SDK_HEARTBEAT_ACTION:-}"
SERIAL=""
SAMPLES=5
INTERVAL_SECONDS=1
ADAPTER_MODE="${ONYX_FSK_SDK_PAYLOAD_ADAPTER:-standard}"
EXPECTED_PROVIDER="${ONYX_GUARD_TELEMETRY_REQUIRED_PROVIDER:-${ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER:-fsk_sdk}}"
OUT_DIR=""

pass() { printf "PASS: %s\n" "$1"; }
fail() { printf "FAIL: %s\n" "$1"; exit 1; }

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/guard_android_live_validation.sh --action <broadcast-action> [--serial <device-serial>] [--samples 5] [--interval 1] [--adapter standard|legacy_ptt] [--expected-provider <provider-id>] [--out-dir <path>]

Purpose:
  End-to-end Android field validation helper for ONYX telemetry callback ingestion.
  It emits test heartbeats over adb broadcast and captures ONYX telemetry logs as evidence.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --serial)
      SERIAL="${2:-}"
      shift 2
      ;;
    --samples)
      SAMPLES="${2:-5}"
      shift 2
      ;;
    --interval)
      INTERVAL_SECONDS="${2:-1}"
      shift 2
      ;;
    --adapter)
      ADAPTER_MODE="${2:-standard}"
      shift 2
      ;;
    --expected-provider)
      EXPECTED_PROVIDER="${2:-}"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

if [[ -z "$ACTION" ]]; then
  fail "--action is required (or set ONYX_FSK_SDK_HEARTBEAT_ACTION)."
fi
if ! command -v adb >/dev/null 2>&1; then
  fail "adb not found. Install android-platform-tools and ensure adb is on PATH."
fi
if ! [[ "$SAMPLES" =~ ^[0-9]+$ ]] || [[ "$SAMPLES" -lt 1 ]]; then
  fail "--samples must be a positive integer."
fi
if ! [[ "$INTERVAL_SECONDS" =~ ^[0-9]+$ ]] || [[ "$INTERVAL_SECONDS" -lt 0 ]]; then
  fail "--interval must be a non-negative integer."
fi
if [[ "$ADAPTER_MODE" != "standard" && "$ADAPTER_MODE" != "legacy_ptt" ]]; then
  fail "--adapter must be standard or legacy_ptt."
fi

DEVICES=()
while IFS= read -r device; do
  [[ -n "$device" ]] && DEVICES+=("$device")
done < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
if [[ "${#DEVICES[@]}" -eq 0 ]]; then
  adb devices -l || true
  fail "No Android devices connected (status=device). Connect a phone, enable Developer Options + USB debugging, and accept the RSA prompt."
fi

if [[ -z "$SERIAL" ]]; then
  SERIAL="${DEVICES[0]}"
fi

ADB=(adb -s "$SERIAL")
if ! "${ADB[@]}" get-state >/dev/null 2>&1; then
  fail "Device serial not available: $SERIAL"
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="tmp/guard_field_validation/$STAMP"
fi
mkdir -p "$OUT_DIR"

echo "Device serial: $SERIAL" | tee "$OUT_DIR/summary.txt"
echo "Broadcast action: $ACTION" | tee -a "$OUT_DIR/summary.txt"
echo "Adapter mode: $ADAPTER_MODE" | tee -a "$OUT_DIR/summary.txt"
echo "Expected provider: $EXPECTED_PROVIDER" | tee -a "$OUT_DIR/summary.txt"
echo "Samples: $SAMPLES" | tee -a "$OUT_DIR/summary.txt"
echo "Interval (s): $INTERVAL_SECONDS" | tee -a "$OUT_DIR/summary.txt"
echo "Run started (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUT_DIR/summary.txt"

"${ADB[@]}" shell getprop ro.product.model > "$OUT_DIR/device_model.txt" || true
"${ADB[@]}" shell getprop ro.build.version.release > "$OUT_DIR/android_version.txt" || true
"${ADB[@]}" shell dumpsys battery > "$OUT_DIR/battery_before.txt" || true

"${ADB[@]}" logcat -c || true

for ((i = 1; i <= SAMPLES; i++)); do
  captured_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if [[ "$ADAPTER_MODE" == "legacy_ptt" ]]; then
    "${ADB[@]}" shell am broadcast \
      -a "$ACTION" \
      --es pulse "$((70 + i))" \
      --es motion "0.$((i + 2))" \
      --es state "patrolling" \
      --es battery "$((80 - i))" \
      --es time_utc "$captured_at" \
      --es location_accuracy "4.$i" >/dev/null
  else
    "${ADB[@]}" shell am broadcast \
      -a "$ACTION" \
      --es heart_rate "$((70 + i))" \
      --es movement_level "0.$((i + 2))" \
      --es activity_state "patrolling" \
      --es battery_percent "$((80 - i))" \
      --es captured_at_utc "$captured_at" \
      --es gps_accuracy_meters "4.$i" >/dev/null
  fi

  echo "sent sample=$i captured_at_utc=$captured_at" | tee -a "$OUT_DIR/broadcasts.txt"
  if [[ "$i" -lt "$SAMPLES" && "$INTERVAL_SECONDS" -gt 0 ]]; then
    sleep "$INTERVAL_SECONDS"
  fi
done

sleep 2
"${ADB[@]}" shell dumpsys battery > "$OUT_DIR/battery_after.txt" || true
"${ADB[@]}" logcat -d > "$OUT_DIR/logcat_full.txt" || true
grep -i "ONYX_TELEMETRY" "$OUT_DIR/logcat_full.txt" > "$OUT_DIR/logcat_onyx_telemetry.txt" || true
grep -i "ingestFskSdkHeartbeat" "$OUT_DIR/logcat_full.txt" > "$OUT_DIR/logcat_ingest_trace.txt" || true

telemetry_line_count="$(wc -l < "$OUT_DIR/logcat_onyx_telemetry.txt" | tr -d ' ')"
echo "ONYX_TELEMETRY lines: $telemetry_line_count" | tee -a "$OUT_DIR/summary.txt"
echo "Run completed (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUT_DIR/summary.txt"

pass "Field validation artifacts captured in $OUT_DIR"
echo "Review:"
echo "  $OUT_DIR/summary.txt"
echo "  $OUT_DIR/broadcasts.txt"
echo "  $OUT_DIR/logcat_onyx_telemetry.txt"
