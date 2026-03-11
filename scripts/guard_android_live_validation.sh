#!/usr/bin/env bash
set -euo pipefail

ACTION=""
PROVIDER_ID="${ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER:-fsk_sdk}"
SERIAL=""
SAMPLES=5
INTERVAL_SECONDS=1
ADAPTER_MODE=""
EXPECTED_PROVIDER="${ONYX_GUARD_TELEMETRY_REQUIRED_PROVIDER:-}"
OUT_DIR=""
APP_PACKAGE="${ONYX_ANDROID_APP_PACKAGE:-com.example.omnix_dashboard}"
APP_ACTIVITY="${ONYX_ANDROID_APP_ACTIVITY:-.MainActivity}"
START_APP=1
READY_TIMEOUT_SECONDS=20

pass() { printf "PASS: %s\n" "$1"; }
fail() { printf "FAIL: %s\n" "$1"; exit 1; }

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/guard_android_live_validation.sh [--provider fsk_sdk|hikvision_sdk] --action <broadcast-action> [--serial <device-serial>] [--samples 5] [--interval 1] [--adapter standard|legacy_ptt|hikvision_guardlink] [--expected-provider <provider-id>] [--app-package <package>] [--app-activity <activity>] [--skip-start-app] [--ready-timeout <seconds>] [--out-dir <path>]

Purpose:
  End-to-end Android field validation helper for ONYX telemetry callback ingestion.
  It emits test heartbeats over adb broadcast and captures ONYX telemetry logs as evidence.
USAGE
}

provider_family() {
  local provider
  provider="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')"
  if [[ "$provider" == *"hikvision"* ]]; then
    echo "hikvision"
  else
    echo "fsk"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider)
      PROVIDER_ID="${2:-}"
      shift 2
      ;;
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
    --app-package)
      APP_PACKAGE="${2:-}"
      shift 2
      ;;
    --app-activity)
      APP_ACTIVITY="${2:-}"
      shift 2
      ;;
    --skip-start-app)
      START_APP=0
      shift
      ;;
    --ready-timeout)
      READY_TIMEOUT_SECONDS="${2:-20}"
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

PROVIDER_FAMILY="$(provider_family "$PROVIDER_ID")"

if [[ -z "$ADAPTER_MODE" ]]; then
  if [[ "$PROVIDER_FAMILY" == "hikvision" ]]; then
    ADAPTER_MODE="${ONYX_HIKVISION_SDK_PAYLOAD_ADAPTER:-hikvision_guardlink}"
  else
    ADAPTER_MODE="${ONYX_FSK_SDK_PAYLOAD_ADAPTER:-standard}"
  fi
fi

if [[ -z "$ACTION" ]]; then
  if [[ "$PROVIDER_FAMILY" == "hikvision" ]]; then
    ACTION="${ONYX_HIKVISION_SDK_HEARTBEAT_ACTION:-}"
  else
    ACTION="${ONYX_FSK_SDK_HEARTBEAT_ACTION:-}"
  fi
fi

if [[ -z "$EXPECTED_PROVIDER" ]]; then
  EXPECTED_PROVIDER="$PROVIDER_ID"
fi

if [[ -z "$ACTION" ]]; then
  if [[ "$PROVIDER_FAMILY" == "hikvision" ]]; then
    fail "--action is required for Hikvision (or set ONYX_HIKVISION_SDK_HEARTBEAT_ACTION)."
  fi
  fail "--action is required for FSK (or set ONYX_FSK_SDK_HEARTBEAT_ACTION)."
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
if ! [[ "$READY_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || [[ "$READY_TIMEOUT_SECONDS" -lt 0 ]]; then
  fail "--ready-timeout must be a non-negative integer."
fi
if [[ "$ADAPTER_MODE" != "standard" && "$ADAPTER_MODE" != "legacy_ptt" && "$ADAPTER_MODE" != "hikvision_guardlink" ]]; then
  fail "--adapter must be standard, legacy_ptt, or hikvision_guardlink."
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
echo "Provider: $PROVIDER_ID" | tee -a "$OUT_DIR/summary.txt"
echo "Broadcast action: $ACTION" | tee -a "$OUT_DIR/summary.txt"
echo "Adapter mode: $ADAPTER_MODE" | tee -a "$OUT_DIR/summary.txt"
echo "Expected provider: $EXPECTED_PROVIDER" | tee -a "$OUT_DIR/summary.txt"
echo "Samples: $SAMPLES" | tee -a "$OUT_DIR/summary.txt"
echo "Interval (s): $INTERVAL_SECONDS" | tee -a "$OUT_DIR/summary.txt"
echo "App package/activity: $APP_PACKAGE/$APP_ACTIVITY" | tee -a "$OUT_DIR/summary.txt"
echo "Auto-start app: $START_APP" | tee -a "$OUT_DIR/summary.txt"
echo "Ready timeout (s): $READY_TIMEOUT_SECONDS" | tee -a "$OUT_DIR/summary.txt"
echo "Run started (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUT_DIR/summary.txt"

"${ADB[@]}" shell getprop ro.product.model > "$OUT_DIR/device_model.txt" || true
"${ADB[@]}" shell getprop ro.build.version.release > "$OUT_DIR/android_version.txt" || true
"${ADB[@]}" shell dumpsys battery > "$OUT_DIR/battery_before.txt" || true

"${ADB[@]}" logcat -c || true

if [[ "$START_APP" -eq 1 ]]; then
  if ! "${ADB[@]}" shell pm path "$APP_PACKAGE" >/dev/null 2>&1; then
    fail "App package $APP_PACKAGE is not installed on device $SERIAL."
  fi

  "${ADB[@]}" shell am force-stop "$APP_PACKAGE" >/dev/null 2>&1 || true
  start_target="${APP_PACKAGE}/${APP_ACTIVITY}"
  "${ADB[@]}" shell am start -n "$start_target" >/dev/null || fail "Unable to start app activity $start_target."

  ready_pattern="fsk_live_facade_started"
  if [[ "$PROVIDER_FAMILY" == "hikvision" ]]; then
    ready_pattern="hikvision_live_facade_started"
  fi

  if [[ "$READY_TIMEOUT_SECONDS" -gt 0 ]]; then
    ready=0
    for ((t = 0; t < READY_TIMEOUT_SECONDS; t++)); do
      if "${ADB[@]}" logcat -d | grep -q "$ready_pattern"; then
        ready=1
        break
      fi
      sleep 1
    done
    if [[ "$ready" -eq 1 ]]; then
      pass "Detected ONYX telemetry facade startup marker: $ready_pattern"
    else
      echo "WARN: Did not observe $ready_pattern within ${READY_TIMEOUT_SECONDS}s." | tee -a "$OUT_DIR/summary.txt"
      echo "WARN: If ONYX_TELEMETRY lines remain 0, rebuild/install with live provider flags for $PROVIDER_ID." | tee -a "$OUT_DIR/summary.txt"
    fi
  fi
fi

for ((i = 1; i <= SAMPLES; i++)); do
  captured_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if [[ "$ADAPTER_MODE" == "legacy_ptt" ]]; then
    "${ADB[@]}" shell am broadcast \
      -a "$ACTION" \
      --es payload_adapter "$ADAPTER_MODE" \
      --es pulse "$((70 + i))" \
      --es movement "0.$((i + 2))" \
      --es state "patrolling" \
      --es battery "$((80 - i))" \
      --es time_utc "$captured_at" \
      --es location_accuracy "4.$i" >/dev/null
  elif [[ "$ADAPTER_MODE" == "hikvision_guardlink" ]]; then
    "${ADB[@]}" shell am broadcast \
      -a "$ACTION" \
      --es payload_adapter "$ADAPTER_MODE" \
      --es vitals_hr "$((70 + i))" \
      --es motion_index "0.$((i + 2))" \
      --es duty_state "patrolling" \
      --es watch_battery_percent "$((80 - i))" \
      --es event_utc "$captured_at" \
      --es gps_hdop_m "4.$i" >/dev/null
  else
    "${ADB[@]}" shell am broadcast \
      -a "$ACTION" \
      --es payload_adapter "$ADAPTER_MODE" \
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
grep -E "ingest(Fsk|Hikvision)SdkHeartbeat|facade_ingest|sdk_callback_received|sdk_callback_error" "$OUT_DIR/logcat_full.txt" > "$OUT_DIR/logcat_ingest_trace.txt" || true

telemetry_line_count="$(wc -l < "$OUT_DIR/logcat_onyx_telemetry.txt" | tr -d ' ')"
echo "ONYX_TELEMETRY lines: $telemetry_line_count" | tee -a "$OUT_DIR/summary.txt"
echo "Run completed (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$OUT_DIR/summary.txt"

pass "Field validation artifacts captured in $OUT_DIR"
echo "Review:"
echo "  $OUT_DIR/summary.txt"
echo "  $OUT_DIR/broadcasts.txt"
echo "  $OUT_DIR/logcat_onyx_telemetry.txt"
