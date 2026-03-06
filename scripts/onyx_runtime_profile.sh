#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"
JSON_OUTPUT=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_runtime_profile.sh [--config <path>] [--json]

Purpose:
  Emits ONYX runtime profile summary derived from dart-define JSON.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="${2:-}"
      shift 2
      ;;
    --json)
      JSON_OUTPUT=1
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

json_value() {
  local key="$1"
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo ""
    return 0
  fi
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg key "$key" '.[$key] // ""' "$CONFIG_FILE"
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$CONFIG_FILE" "$key" <<'PY'
import json
import sys
path, key = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)
print(data.get(key, ""))
PY
    return 0
  fi
  sed -nE "s/^[[:space:]]*\"$key\"[[:space:]]*:[[:space:]]*\"([^\"]*)\"[[:space:]]*,?[[:space:]]*$/\1/p" "$CONFIG_FILE" | head -n 1
}

config_exists="false"
if [[ -f "$CONFIG_FILE" ]]; then
  config_exists="true"
fi

supabase_url="$(json_value "SUPABASE_URL" | tr -d '\r')"
supabase_anon_key="$(json_value "SUPABASE_ANON_KEY" | tr -d '\r')"
live_feed_url="$(json_value "ONYX_LIVE_FEED_URL" | tr -d '\r')"
telemetry_provider="$(json_value "ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER" | tr -d '\r')"
telemetry_required_provider="$(json_value "ONYX_GUARD_TELEMETRY_REQUIRED_PROVIDER" | tr -d '\r')"
telemetry_stub="$(json_value "ONYX_GUARD_TELEMETRY_NATIVE_STUB" | tr -d '\r' | tr '[:upper:]' '[:lower:]')"
telemetry_native_sdk="$(json_value "ONYX_GUARD_TELEMETRY_NATIVE_SDK" | tr -d '\r' | tr '[:upper:]' '[:lower:]')"

supabase_mode="IN-MEMORY"
if [[ -n "$supabase_url" && -n "$supabase_anon_key" ]]; then
  supabase_mode="LIVE"
fi

telemetry_mode="STUB"
if [[ "$telemetry_stub" == "false" ]]; then
  telemetry_mode="LIVE"
fi

live_feed_mode="DISABLED"
if [[ -n "$live_feed_url" ]]; then
  live_feed_mode="CONFIGURED"
fi

if [[ -z "$telemetry_provider" ]]; then
  telemetry_provider="android_native_sdk_stub"
fi
if [[ -z "$telemetry_required_provider" ]]; then
  telemetry_required_provider="$telemetry_provider"
fi

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  cat <<EOF
{
  "config_file": "$CONFIG_FILE",
  "config_exists": $config_exists,
  "supabase_mode": "$supabase_mode",
  "supabase_url_set": $([[ -n "$supabase_url" ]] && echo "true" || echo "false"),
  "supabase_anon_key_set": $([[ -n "$supabase_anon_key" ]] && echo "true" || echo "false"),
  "live_feed_mode": "$live_feed_mode",
  "live_feed_url_set": $([[ -n "$live_feed_url" ]] && echo "true" || echo "false"),
  "telemetry_mode": "$telemetry_mode",
  "telemetry_native_sdk_enabled": $([[ "$telemetry_native_sdk" == "true" ]] && echo "true" || echo "false"),
  "telemetry_provider": "$telemetry_provider",
  "telemetry_required_provider": "$telemetry_required_provider"
}
EOF
  exit 0
fi

echo "ONYX runtime profile:"
echo "  config file: $CONFIG_FILE ($([[ "$config_exists" == "true" ]] && echo "found" || echo "missing"))"
echo "  supabase: $supabase_mode"
echo "  telemetry: $telemetry_mode (${telemetry_provider})"
echo "  telemetry native sdk: $([[ "$telemetry_native_sdk" == "true" ]] && echo "enabled" || echo "disabled")"
echo "  telemetry required provider: ${telemetry_required_provider}"
echo "  live feed: $live_feed_mode"
