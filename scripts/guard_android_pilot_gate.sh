#!/usr/bin/env bash
set -euo pipefail

ACTION="${ONYX_FSK_SDK_HEARTBEAT_ACTION:-}"
SERIAL=""
SAMPLES=5
INTERVAL_SECONDS=1
ADAPTER_MODE="${ONYX_FSK_SDK_PAYLOAD_ADAPTER:-standard}"
EXPECTED_PROVIDER="${ONYX_GUARD_TELEMETRY_REQUIRED_PROVIDER:-${ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER:-fsk_sdk}}"
MAX_REPORT_AGE_HOURS="${ONYX_MAX_LIVE_VALIDATION_REPORT_AGE_HOURS:-24}"
RUN_FULL_TESTS=0
OUT_DIR=""
REQUIRE_REAL_DEVICE_ARTIFACTS=0
RUN_CONNECTION_DOCTOR=1
CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/guard_android_pilot_gate.sh --action <broadcast-action> [--serial <device-serial>] [--samples 5] [--interval 1] [--adapter standard|legacy_ptt] [--expected-provider fsk_sdk] [--max-report-age-hours 24] [--config <path>] [--require-real-device-artifacts] [--full-tests] [--skip-connection-doctor] [--out-dir <path>]

Purpose:
  One-command pilot gate:
  1) Emit Android live telemetry callbacks
  2) Generate validation report
  3) Run readiness gate with live-telemetry + artifact freshness enforcement
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

if [[ -z "$ACTION" ]]; then
  echo "FAIL: --action is required (or set ONYX_FSK_SDK_HEARTBEAT_ACTION)."
  exit 1
fi
if ! [[ "$MAX_REPORT_AGE_HOURS" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --max-report-age-hours must be a non-negative integer."
  exit 1
fi

echo "== ONYX Android Pilot Gate =="
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

if [[ -n "$OUT_DIR" ]]; then
  artifact_dir="$OUT_DIR"
else
  artifact_dir="$(find tmp/guard_field_validation -type d -maxdepth 1 2>/dev/null | sort | tail -n 1)"
fi

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
