#!/usr/bin/env bash
set -euo pipefail

ACTION="${ONYX_FSK_SDK_HEARTBEAT_ACTION:-}"
SAMPLES=3
INTERVAL_SECONDS=2
ADAPTER_MODE="${ONYX_FSK_SDK_PAYLOAD_ADAPTER:-standard}"

pass() { printf "PASS: %s\n" "$1"; }
warn() { printf "WARN: %s\n" "$1"; }
fail() { printf "FAIL: %s\n" "$1"; exit 1; }

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/guard_android_field_validation.sh --action <broadcast-action> [--samples 3] [--interval 2] [--adapter standard|legacy_ptt]

Purpose:
  Emit debug heartbeat broadcasts from adb to validate live FSK callback ingestion on Android devices.

Example:
  ./scripts/guard_android_field_validation.sh \
    --action com.onyx.fsk.SDK_HEARTBEAT \
    --samples 5 \
    --interval 1
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --samples)
      SAMPLES="${2:-3}"
      shift 2
      ;;
    --interval)
      INTERVAL_SECONDS="${2:-2}"
      shift 2
      ;;
    --adapter)
      ADAPTER_MODE="${2:-standard}"
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

pass "Connected devices: ${DEVICES[*]}"
echo "Sending $SAMPLES test heartbeat broadcast(s) on action: $ACTION (adapter: $ADAPTER_MODE)"

for ((i = 1; i <= SAMPLES; i++)); do
  CAPTURED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if [[ "$ADAPTER_MODE" == "legacy_ptt" ]]; then
    adb shell am broadcast \
      -a "$ACTION" \
      --es pulse "$((70 + i))" \
      --es motion "0.$((i + 2))" \
      --es state "patrolling" \
      --es battery "$((80 - i))" \
      --es time_utc "$CAPTURED_AT" \
      --es location_accuracy "4.$i" >/dev/null
  else
    adb shell am broadcast \
      -a "$ACTION" \
      --es heart_rate "$((70 + i))" \
      --es movement_level "0.$((i + 2))" \
      --es activity_state "patrolling" \
      --es battery_percent "$((80 - i))" \
      --es captured_at_utc "$CAPTURED_AT" \
      --es gps_accuracy_meters "4.$i" >/dev/null
  fi

  echo "  • Broadcast $i/$SAMPLES sent at $CAPTURED_AT"
  if [[ "$i" -lt "$SAMPLES" && "$INTERVAL_SECONDS" -gt 0 ]]; then
    sleep "$INTERVAL_SECONDS"
  fi
done

echo ""
pass "Field validation broadcasts complete."
echo "Next verification in ONYX Guard Sync screen:"
echo "  1. Provider readiness remains ready."
echo "  2. Facade callback count increases."
echo "  3. Last callback timestamp/message updates."
