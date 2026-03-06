#!/usr/bin/env bash
set -euo pipefail

RUN_FLUTTER=1
FULL_TESTS=0
SAMPLES=3
MAX_REPORT_AGE_HOURS=24
CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_ops_preflight.sh [--skip-flutter] [--full-tests] [--samples 3] [--max-report-age-hours 24] [--config <path>]

Purpose:
  One-command ONYX operator preflight:
  1) flutter analyze + flutter test (unless --skip-flutter)
  2) Guard auto gate (on-device if phone connected, pre-device otherwise)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-flutter)
      RUN_FLUTTER=0
      shift
      ;;
    --full-tests)
      FULL_TESTS=1
      shift
      ;;
    --samples)
      SAMPLES="${2:-3}"
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

echo "== ONYX Ops Preflight =="
echo "Config: $CONFIG_FILE"
echo "Flutter checks: $([[ "$RUN_FLUTTER" -eq 1 ]] && echo enabled || echo skipped)"
echo "Guard samples: $SAMPLES"
echo "Max report age: ${MAX_REPORT_AGE_HOURS}h"
echo ""

if [[ "$RUN_FLUTTER" -eq 1 ]]; then
  flutter analyze
  flutter test
fi

guard_cmd=(
  ./scripts/guard_gate_auto.sh
  --samples "$SAMPLES"
  --max-report-age-hours "$MAX_REPORT_AGE_HOURS"
  --config "$CONFIG_FILE"
)

if [[ "$FULL_TESTS" -eq 1 ]]; then
  guard_cmd+=(--full-tests)
fi

"${guard_cmd[@]}"

echo ""
echo "PASS: ONYX ops preflight complete."
