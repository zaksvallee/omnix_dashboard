#!/usr/bin/env bash
set -euo pipefail

RUN_FLUTTER=1
FULL_TESTS=0
FLUTTER_MODE="full"
SAMPLES=3
MAX_REPORT_AGE_HOURS=24
CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"
PROVIDER_ID="${ONYX_GUARD_TELEMETRY_REQUIRED_PROVIDER:-${ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER:-fsk_sdk}}"
ACTION=""
ADAPTER_MODE=""
USER_SUPPLIED_CONFIG=0
ALLOW_BROADCAST_FALLBACK=0
SKIP_CONNECTION_DOCTOR=0
SKIP_CONNECTOR_DOCTOR=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_ops_preflight.sh [--skip-flutter] [--smoke-ui] [--full-tests] [--provider <provider-id>] [--action <broadcast-action>] [--adapter <adapter-id>] [--samples 3] [--max-report-age-hours 24] [--config <path>] [--allow-broadcast-fallback] [--skip-connection-doctor] [--skip-connector-doctor]

Purpose:
  One-command ONYX operator preflight:
  1) flutter checks (default: analyze + full test, optional: smoke-ui)
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
    --smoke-ui)
      FLUTTER_MODE="smoke"
      shift
      ;;
    --samples)
      SAMPLES="${2:-3}"
      shift 2
      ;;
    --provider)
      PROVIDER_ID="${2:-}"
      shift 2
      ;;
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --adapter)
      ADAPTER_MODE="${2:-}"
      shift 2
      ;;
    --max-report-age-hours)
      MAX_REPORT_AGE_HOURS="${2:-24}"
      shift 2
      ;;
    --config)
      CONFIG_FILE="${2:-}"
      USER_SUPPLIED_CONFIG=1
      shift 2
      ;;
    --allow-broadcast-fallback)
      ALLOW_BROADCAST_FALLBACK=1
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

PROVIDER_FAMILY="fsk"
if [[ "$(echo "${PROVIDER_ID:-}" | tr '[:upper:]' '[:lower:]')" == *"hikvision"* ]]; then
  PROVIDER_FAMILY="hikvision"
fi
if [[ -z "$ACTION" ]]; then
  if [[ "$PROVIDER_FAMILY" == "hikvision" ]]; then
    ACTION="${ONYX_HIKVISION_SDK_HEARTBEAT_ACTION:-com.onyx.hikvision.SDK_HEARTBEAT}"
  else
    ACTION="${ONYX_FSK_SDK_HEARTBEAT_ACTION:-com.onyx.fsk.SDK_HEARTBEAT}"
  fi
fi
if [[ -z "$ADAPTER_MODE" ]]; then
  if [[ "$PROVIDER_FAMILY" == "hikvision" ]]; then
    ADAPTER_MODE="${ONYX_HIKVISION_SDK_PAYLOAD_ADAPTER:-hikvision_guardlink}"
  else
    ADAPTER_MODE="${ONYX_FSK_SDK_PAYLOAD_ADAPTER:-standard}"
  fi
fi

echo "== ONYX Ops Preflight =="
echo "Config: $CONFIG_FILE"
echo "Config source: $([[ "$USER_SUPPLIED_CONFIG" -eq 1 ]] && echo explicit || echo default/auto-align-eligible)"
echo "Flutter checks: $([[ "$RUN_FLUTTER" -eq 1 ]] && echo enabled || echo skipped)"
echo "Flutter mode: $FLUTTER_MODE"
echo "Guard samples: $SAMPLES"
echo "Telemetry provider: $PROVIDER_ID"
echo "Telemetry action: $ACTION"
echo "Telemetry adapter: $ADAPTER_MODE"
echo "Max report age: ${MAX_REPORT_AGE_HOURS}h"
echo "Allow broadcast fallback: $([[ "$ALLOW_BROADCAST_FALLBACK" -eq 1 ]] && echo yes || echo no)"
echo ""

if [[ "$RUN_FLUTTER" -eq 1 ]]; then
  if [[ "$FLUTTER_MODE" == "smoke" ]]; then
    ./scripts/ui_compact_smoke.sh
  else
    flutter analyze
    flutter test
  fi
fi

guard_cmd=(
  ./scripts/guard_gate_auto.sh
  --provider "$PROVIDER_ID"
  --action "$ACTION"
  --adapter "$ADAPTER_MODE"
  --samples "$SAMPLES"
  --max-report-age-hours "$MAX_REPORT_AGE_HOURS"
)

if [[ "$USER_SUPPLIED_CONFIG" -eq 1 ]]; then
  guard_cmd+=(--config "$CONFIG_FILE")
fi

if [[ "$FULL_TESTS" -eq 1 ]]; then
  guard_cmd+=(--full-tests)
fi
if [[ "$ALLOW_BROADCAST_FALLBACK" -eq 1 ]]; then
  guard_cmd+=(--allow-broadcast-fallback)
fi
if [[ "$SKIP_CONNECTION_DOCTOR" -eq 1 ]]; then
  guard_cmd+=(--skip-connection-doctor)
fi
if [[ "$SKIP_CONNECTOR_DOCTOR" -eq 1 ]]; then
  guard_cmd+=(--skip-connector-doctor)
fi

"${guard_cmd[@]}"

echo ""
echo "PASS: ONYX ops preflight complete."
