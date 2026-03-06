#!/usr/bin/env bash
set -euo pipefail

SAMPLES=3
MAX_REPORT_AGE_HOURS=24
RUN_FULL_TESTS=0
CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/guard_predevice_gate.sh [--samples 3] [--max-report-age-hours 24] [--full-tests] [--config <path>]

Purpose:
  Run a strict, no-device guard readiness gate while hardware is pending:
  1) Generate mock live-validation artifacts
  2) Run readiness with live telemetry + artifact freshness + Supabase config gates
  3) Emit auditable gate report JSON/log paths
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --samples)
      SAMPLES="${2:-3}"
      shift 2
      ;;
    --max-report-age-hours)
      MAX_REPORT_AGE_HOURS="${2:-24}"
      shift 2
      ;;
    --full-tests)
      RUN_FULL_TESTS=1
      shift
      ;;
    --config)
      CONFIG_FILE="${2:-}"
      shift 2
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

echo "== ONYX Guard Pre-Device Gate =="
echo "Samples: $SAMPLES"
echo "Max report age: ${MAX_REPORT_AGE_HOURS}h"
echo "Config: $CONFIG_FILE"
echo ""

./scripts/guard_android_mock_validation_artifacts.sh --samples "$SAMPLES"

report_cmd=(
  ./scripts/guard_pilot_gate_report.sh
  --config "$CONFIG_FILE"
  --
  --enforce-live-telemetry
  --require-live-validation-artifacts
  --max-live-validation-report-age-hours "$MAX_REPORT_AGE_HOURS"
  --require-supabase-config
)

if [[ "$RUN_FULL_TESTS" -eq 1 ]]; then
  report_cmd+=(--full-tests)
fi

"${report_cmd[@]}"

echo ""
echo "PASS: Pre-device guard gate completed."
echo "Next: run ./scripts/guard_android_pilot_gate.sh when physical device is available."
