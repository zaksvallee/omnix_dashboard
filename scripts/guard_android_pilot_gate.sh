#!/usr/bin/env bash
set -euo pipefail

ACTION=""
PROVIDER_ID="${ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER:-fsk_sdk}"
SERIAL=""
SAMPLES=5
INTERVAL_SECONDS=1
ADAPTER_MODE=""
EXPECTED_PROVIDER="${ONYX_GUARD_TELEMETRY_REQUIRED_PROVIDER:-}"
MAX_REPORT_AGE_HOURS="${ONYX_MAX_LIVE_VALIDATION_REPORT_AGE_HOURS:-24}"
RUN_FULL_TESTS=0
OUT_DIR=""
REQUIRE_REAL_DEVICE_ARTIFACTS=0
RUN_CONNECTION_DOCTOR=1
CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/guard_android_pilot_gate.sh [--provider fsk_sdk|hikvision_sdk] --action <broadcast-action> [--serial <device-serial>] [--samples 5] [--interval 1] [--adapter standard|legacy_ptt|hikvision_guardlink] [--expected-provider <provider-id>] [--max-report-age-hours 24] [--config <path>] [--require-real-device-artifacts] [--full-tests] [--skip-connection-doctor] [--out-dir <path>]

Purpose:
  One-command pilot gate:
  1) Emit Android live telemetry callbacks
  2) Generate validation report
  3) Run readiness gate with live-telemetry + artifact freshness enforcement
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
    --max-report-age-hours)
      MAX_REPORT_AGE_HOURS="${2:-24}"
      shift 2
      ;;
    --config)
      CONFIG_FILE="${2:-}"
      shift 2
      ;;
    --require-real-device-artifacts)
      REQUIRE_REAL_DEVICE_ARTIFACTS=1
      shift
      ;;
    --full-tests)
      RUN_FULL_TESTS=1
      shift
      ;;
    --skip-connection-doctor)
      RUN_CONNECTION_DOCTOR=0
      shift
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
      echo "FAIL: Unknown argument: $1"
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
    ACTION="${ONYX_FSK_SDK_HEARTBEAT_ACTION:-}"
  fi
fi

if [[ -z "$EXPECTED_PROVIDER" ]]; then
  EXPECTED_PROVIDER="$PROVIDER_ID"
fi

if [[ -z "$ACTION" ]]; then
  if [[ "$PROVIDER_FAMILY" == "hikvision" ]]; then
    echo "FAIL: --action is required for Hikvision (or set ONYX_HIKVISION_SDK_HEARTBEAT_ACTION)."
  else
    echo "FAIL: --action is required for FSK (or set ONYX_FSK_SDK_HEARTBEAT_ACTION)."
  fi
  exit 1
fi
if ! [[ "$MAX_REPORT_AGE_HOURS" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --max-report-age-hours must be a non-negative integer."
  exit 1
fi

if [[ -z "$OUT_DIR" ]]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  OUT_DIR="tmp/guard_field_validation/pilot-$stamp"
fi

echo "== ONYX Android Pilot Gate =="
echo "Provider: $PROVIDER_ID"
echo "Action: $ACTION"
echo "Adapter: $ADAPTER_MODE"
echo "Expected provider: $EXPECTED_PROVIDER"
echo "Samples: $SAMPLES | Interval: ${INTERVAL_SECONDS}s"
echo "Max report age: ${MAX_REPORT_AGE_HOURS}h"
./scripts/onyx_runtime_profile.sh --config "$CONFIG_FILE"

if [[ "$RUN_CONNECTION_DOCTOR" -eq 1 ]]; then
  ./scripts/guard_android_connection_doctor.sh
fi

live_validation_cmd=(
  ./scripts/guard_android_live_validation.sh
  --provider "$PROVIDER_ID"
  --action "$ACTION"
  --samples "$SAMPLES"
  --interval "$INTERVAL_SECONDS"
  --adapter "$ADAPTER_MODE"
  --expected-provider "$EXPECTED_PROVIDER"
)
if [[ -n "$SERIAL" ]]; then
  live_validation_cmd+=(--serial "$SERIAL")
fi
if [[ -n "$OUT_DIR" ]]; then
  live_validation_cmd+=(--out-dir "$OUT_DIR")
fi

"${live_validation_cmd[@]}"

artifact_dir="$OUT_DIR"

if [[ -z "$artifact_dir" || ! -d "$artifact_dir" ]]; then
  echo "FAIL: Could not determine artifact directory."
  exit 1
fi

./scripts/onyx_runtime_profile.sh --config "$CONFIG_FILE" \
  > "$artifact_dir/runtime_profile.txt"
./scripts/onyx_runtime_profile.sh --config "$CONFIG_FILE" --json \
  > "$artifact_dir/runtime_profile.json"

./scripts/guard_android_live_validation_report.sh \
  --artifact-dir "$artifact_dir" \
  --required-provider "$EXPECTED_PROVIDER"

readiness_cmd=(
  ./scripts/guard_pilot_readiness_check.sh
  --enforce-live-telemetry
  --require-live-validation-artifacts
  --config "$CONFIG_FILE"
  --max-live-validation-report-age-hours "$MAX_REPORT_AGE_HOURS"
)
if [[ "$RUN_FULL_TESTS" -eq 1 ]]; then
  readiness_cmd+=(--full-tests)
fi
if [[ "$REQUIRE_REAL_DEVICE_ARTIFACTS" -eq 1 ]]; then
  readiness_cmd+=(--require-real-device-artifacts)
fi

"${readiness_cmd[@]}"

echo ""
echo "PASS: Android pilot gate completed."
echo "Report: $artifact_dir/validation_report.md"
echo "Runtime profile: $artifact_dir/runtime_profile.txt"
