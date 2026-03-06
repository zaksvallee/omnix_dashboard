#!/usr/bin/env bash
set -euo pipefail

ACTION="${ONYX_FSK_SDK_HEARTBEAT_ACTION:-}"
SERIAL=""
SAMPLES=3
INTERVAL_SECONDS=1
ADAPTER_MODE="${ONYX_FSK_SDK_PAYLOAD_ADAPTER:-standard}"
EXPECTED_PROVIDER="${ONYX_GUARD_TELEMETRY_REQUIRED_PROVIDER:-${ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER:-fsk_sdk}}"
MAX_REPORT_AGE_HOURS=24
RUN_FULL_TESTS=0
CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"
REQUIRE_REAL_DEVICE_ARTIFACTS=0
SKIP_CONNECTION_DOCTOR=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/guard_gate_auto.sh [--action <broadcast-action>] [--serial <device-serial>] [--samples 3] [--interval 1] [--adapter standard|legacy_ptt] [--expected-provider fsk_sdk] [--max-report-age-hours 24] [--config <path>] [--full-tests] [--require-real-device-artifacts] [--skip-connection-doctor]

Purpose:
  One command for both modes:
  - If an Android device is connected: runs guard_android_pilot_gate.sh
  - If no Android device is connected: runs guard_predevice_gate.sh
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
      SAMPLES="${2:-3}"
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
      EXPECTED_PROVIDER="${2:-fsk_sdk}"
      shift 2
      ;;
    --max-report-age-hours)
      MAX_REPORT_AGE_HOURS="${2:-24}"
      shift 2
      ;;
    --config)
      CONFIG_FILE="${2:-}"
      shift 2
      ;;
    --full-tests)
      RUN_FULL_TESTS=1
      shift
      ;;
    --require-real-device-artifacts)
      REQUIRE_REAL_DEVICE_ARTIFACTS=1
      shift
      ;;
    --skip-connection-doctor)
      SKIP_CONNECTION_DOCTOR=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "FAIL: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if ! [[ "$SAMPLES" =~ ^[0-9]+$ ]] || [[ "$SAMPLES" -lt 1 ]]; then
  echo "FAIL: --samples must be a positive integer." >&2
  exit 1
fi
if ! [[ "$MAX_REPORT_AGE_HOURS" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --max-report-age-hours must be a non-negative integer." >&2
  exit 1
fi

DEVICE_COUNT=0
if command -v adb >/dev/null 2>&1; then
  DEVICE_COUNT="$(adb devices | awk 'NR>1 && $2=="device" {count++} END {print count+0}')"
fi

if [[ "$DEVICE_COUNT" -gt 0 ]]; then
  if [[ -z "$ACTION" ]]; then
    echo "FAIL: Android device detected but --action (or ONYX_FSK_SDK_HEARTBEAT_ACTION) is not set." >&2
    exit 1
  fi

  echo "== ONYX Guard Auto Gate =="
  echo "Mode: on-device pilot gate"
  echo "Connected devices: $DEVICE_COUNT"

  pilot_cmd=(
    ./scripts/guard_android_pilot_gate.sh
    --action "$ACTION"
    --samples "$SAMPLES"
    --interval "$INTERVAL_SECONDS"
    --adapter "$ADAPTER_MODE"
    --expected-provider "$EXPECTED_PROVIDER"
    --max-report-age-hours "$MAX_REPORT_AGE_HOURS"
    --config "$CONFIG_FILE"
  )

  if [[ -n "$SERIAL" ]]; then
    pilot_cmd+=(--serial "$SERIAL")
  fi
  if [[ "$RUN_FULL_TESTS" -eq 1 ]]; then
    pilot_cmd+=(--full-tests)
  fi
  if [[ "$REQUIRE_REAL_DEVICE_ARTIFACTS" -eq 1 ]]; then
    pilot_cmd+=(--require-real-device-artifacts)
  fi
  if [[ "$SKIP_CONNECTION_DOCTOR" -eq 1 ]]; then
    pilot_cmd+=(--skip-connection-doctor)
  fi

  "${pilot_cmd[@]}"
else
  echo "== ONYX Guard Auto Gate =="
  echo "Mode: pre-device gate"
  echo "Connected devices: 0"

  pre_cmd=(
    ./scripts/guard_predevice_gate.sh
    --samples "$SAMPLES"
    --max-report-age-hours "$MAX_REPORT_AGE_HOURS"
    --config "$CONFIG_FILE"
  )

  if [[ "$RUN_FULL_TESTS" -eq 1 ]]; then
    pre_cmd+=(--full-tests)
  fi

  "${pre_cmd[@]}"
fi
