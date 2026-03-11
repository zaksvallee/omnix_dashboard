#!/usr/bin/env bash
set -euo pipefail

ACTION=""
PROVIDER_ID="${ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER:-fsk_sdk}"
SERIAL=""
SAMPLES=3
INTERVAL_SECONDS=1
ADAPTER_MODE=""
EXPECTED_PROVIDER="${ONYX_GUARD_TELEMETRY_REQUIRED_PROVIDER:-}"
MAX_REPORT_AGE_HOURS=24
RUN_FULL_TESTS=0
CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"
REQUIRE_REAL_DEVICE_ARTIFACTS=0
SKIP_CONNECTION_DOCTOR=0
SKIP_CONNECTOR_DOCTOR=0
ALLOW_BROADCAST_FALLBACK=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/guard_gate_auto.sh [--provider fsk_sdk|hikvision_sdk] [--action <broadcast-action>] [--serial <device-serial>] [--samples 3] [--interval 1] [--adapter standard|legacy_ptt|hikvision_guardlink] [--expected-provider <provider-id>] [--max-report-age-hours 24] [--config <path>] [--full-tests] [--require-real-device-artifacts] [--allow-broadcast-fallback] [--skip-connection-doctor] [--skip-connector-doctor]

Purpose:
  One command for both modes:
  - If an Android device is connected: runs guard_android_pilot_gate.sh
  - If no Android device is connected: runs guard_predevice_gate.sh

Defaults:
  --action defaults to provider-specific env:
    FSK: ONYX_FSK_SDK_HEARTBEAT_ACTION
    Hikvision: ONYX_HIKVISION_SDK_HEARTBEAT_ACTION
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
      EXPECTED_PROVIDER="${2:-}"
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
    --skip-connector-doctor)
      SKIP_CONNECTOR_DOCTOR=1
      shift
      ;;
    --allow-broadcast-fallback)
      ALLOW_BROADCAST_FALLBACK=1
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
    ACTION="${ONYX_FSK_SDK_HEARTBEAT_ACTION:-com.onyx.fsk.SDK_HEARTBEAT}"
  fi
fi

if [[ -z "$EXPECTED_PROVIDER" ]]; then
  EXPECTED_PROVIDER="$PROVIDER_ID"
fi

if [[ -z "$ACTION" ]]; then
  if [[ "$PROVIDER_FAMILY" == "hikvision" ]]; then
    echo "FAIL: --action is required for Hikvision (or set ONYX_HIKVISION_SDK_HEARTBEAT_ACTION)." >&2
  else
    echo "FAIL: --action is required for FSK (or set ONYX_FSK_SDK_HEARTBEAT_ACTION)." >&2
  fi
  exit 1
fi

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
  echo "== ONYX Guard Auto Gate =="
  echo "Mode: on-device pilot gate"
  echo "Connected devices: $DEVICE_COUNT"
  echo "Provider: $PROVIDER_ID"
  echo "Action: $ACTION"

  pilot_cmd=(
    ./scripts/guard_android_pilot_gate.sh
    --provider "$PROVIDER_ID"
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
  if [[ "$SKIP_CONNECTOR_DOCTOR" -eq 1 ]]; then
    pilot_cmd+=(--skip-connector-doctor)
  fi
  if [[ "$ALLOW_BROADCAST_FALLBACK" -eq 1 ]]; then
    pilot_cmd+=(--allow-broadcast-fallback)
  fi

  "${pilot_cmd[@]}"
else
  echo "== ONYX Guard Auto Gate =="
  echo "Mode: pre-device gate"
  echo "Connected devices: 0"

  pre_cmd=(
    ./scripts/guard_predevice_gate.sh
    --provider "$PROVIDER_ID"
    --samples "$SAMPLES"
    --max-report-age-hours "$MAX_REPORT_AGE_HOURS"
    --config "$CONFIG_FILE"
  )

  if [[ "$RUN_FULL_TESTS" -eq 1 ]]; then
    pre_cmd+=(--full-tests)
  fi

  "${pre_cmd[@]}"
fi
