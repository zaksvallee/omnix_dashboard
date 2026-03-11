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
EFFECTIVE_CONFIG_FILE=""
REQUIRE_REAL_DEVICE_ARTIFACTS=0
SKIP_CONNECTION_DOCTOR=0
SKIP_CONNECTOR_DOCTOR=0
ALLOW_BROADCAST_FALLBACK=0
USER_SUPPLIED_CONFIG=0

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
  if --config is not supplied and provider differs from config runtime provider,
  a temporary provider-aligned config is generated under tmp/onyx.auto.*.json.
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

json_value() {
  local key="$1"
  local file="$2"
  if [[ ! -f "$file" ]]; then
    echo ""
    return 0
  fi
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg key "$key" '.[$key] // ""' "$file"
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$file" "$key" <<'PY'
import json
import sys
path, key = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)
print(data.get(key, ""))
PY
    return 0
  fi
  sed -nE "s/^[[:space:]]*\"$key\"[[:space:]]*:[[:space:]]*\"([^\"]*)\"[[:space:]]*,?[[:space:]]*$/\1/p" "$file" | head -n 1
}

align_runtime_config_if_needed() {
  local provider_id="$1"
  local required_provider="$2"

  EFFECTIVE_CONFIG_FILE="$CONFIG_FILE"
  if [[ ! -f "$CONFIG_FILE" ]]; then
    return 0
  fi

  local config_provider
  local config_required_provider
  config_provider="$(json_value "ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER" "$CONFIG_FILE" | tr -d '\r')"
  config_required_provider="$(json_value "ONYX_GUARD_TELEMETRY_REQUIRED_PROVIDER" "$CONFIG_FILE" | tr -d '\r')"

  if [[ -z "$config_provider" ]]; then
    config_provider="android_native_sdk_stub"
  fi
  if [[ -z "$config_required_provider" ]]; then
    config_required_provider="$config_provider"
  fi

  if [[ "$config_provider" == "$provider_id" && "$config_required_provider" == "$required_provider" ]]; then
    return 0
  fi

  if [[ "$USER_SUPPLIED_CONFIG" -eq 1 ]]; then
    echo "WARN: Requested provider '$provider_id' differs from config provider '$config_provider' in $CONFIG_FILE." >&2
    echo "WARN: Using user-supplied config as-is." >&2
    return 0
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    echo "WARN: python3 unavailable; cannot auto-align runtime config provider for $provider_id." >&2
    return 0
  fi

  local stamp
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  local out_file="tmp/onyx.auto.${provider_id}.${stamp}.json"
  mkdir -p "$(dirname "$out_file")"
  python3 - "$CONFIG_FILE" "$out_file" "$provider_id" "$required_provider" <<'PY'
import json
import sys

source, target, provider, required = sys.argv[1:5]
with open(source, "r", encoding="utf-8") as f:
    data = json.load(f)

data["ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER"] = provider
data["ONYX_GUARD_TELEMETRY_REQUIRED_PROVIDER"] = required
data["ONYX_GUARD_TELEMETRY_NATIVE_STUB"] = "false"
data["ONYX_GUARD_TELEMETRY_NATIVE_SDK"] = "true"

with open(target, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, sort_keys=True)
    f.write("\n")
PY
  EFFECTIVE_CONFIG_FILE="$out_file"
  echo "WARN: Auto-aligned runtime config for provider '$provider_id' -> $EFFECTIVE_CONFIG_FILE" >&2
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
      USER_SUPPLIED_CONFIG=1
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
align_runtime_config_if_needed "$PROVIDER_ID" "$EXPECTED_PROVIDER"

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
  echo "Config: $EFFECTIVE_CONFIG_FILE"

  pilot_cmd=(
    ./scripts/guard_android_pilot_gate.sh
    --provider "$PROVIDER_ID"
    --action "$ACTION"
    --samples "$SAMPLES"
    --interval "$INTERVAL_SECONDS"
    --adapter "$ADAPTER_MODE"
    --expected-provider "$EXPECTED_PROVIDER"
    --max-report-age-hours "$MAX_REPORT_AGE_HOURS"
    --config "$EFFECTIVE_CONFIG_FILE"
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
  echo "Config: $EFFECTIVE_CONFIG_FILE"

  pre_cmd=(
    ./scripts/guard_predevice_gate.sh
    --provider "$PROVIDER_ID"
    --samples "$SAMPLES"
    --max-report-age-hours "$MAX_REPORT_AGE_HOURS"
    --config "$EFFECTIVE_CONFIG_FILE"
  )

  if [[ "$RUN_FULL_TESTS" -eq 1 ]]; then
    pre_cmd+=(--full-tests)
  fi

  "${pre_cmd[@]}"
fi
