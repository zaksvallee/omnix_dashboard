#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"
DEVICE="${ONYX_FLUTTER_DEVICE:-chrome}"
REQUIRE_SUPABASE=0
LOG_FILE=""
FLUTTER_PID_FILE="${ONYX_FLUTTER_PID_FILE:-tmp/onyx_flutter.pid}"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/run_onyx_chrome_local.sh [--config <path>] [--device <id>] [--require-supabase] [--log-file <path>] [-- <flutter run args...>]

Examples:
  ./scripts/run_onyx_chrome_local.sh
  ./scripts/run_onyx_chrome_local.sh --require-supabase
  ./scripts/run_onyx_chrome_local.sh --log-file tmp/telegram_quick_action_live.log
  ./scripts/run_onyx_chrome_local.sh --device edge -- --web-port 63099
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="${2:-}"
      shift 2
      ;;
    --device)
      DEVICE="${2:-}"
      shift 2
      ;;
    --require-supabase)
      REQUIRE_SUPABASE=1
      shift
      ;;
    --log-file)
      LOG_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "FAIL: Missing dart-define file: $CONFIG_FILE" >&2
  echo "Copy config/onyx.local.example.json to config/onyx.local.json and set runtime keys." >&2
  exit 1
fi

json_value() {
  local key="$1"
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

supabase_url="$(json_value "SUPABASE_URL" | tr -d '\r')"
supabase_anon_key="$(json_value "SUPABASE_ANON_KEY" | tr -d '\r')"
live_feed_url="$(json_value "ONYX_LIVE_FEED_URL" | tr -d '\r')"
telemetry_provider="$(json_value "ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER" | tr -d '\r')"
telemetry_stub="$(json_value "ONYX_GUARD_TELEMETRY_NATIVE_STUB" | tr -d '\r' | tr '[:upper:]' '[:lower:]')"
telegram_bridge_enabled="$(json_value "ONYX_TELEGRAM_BRIDGE_ENABLED" | tr -d '\r' | tr '[:upper:]' '[:lower:]')"
telegram_bot_token="$(json_value "ONYX_TELEGRAM_BOT_TOKEN" | tr -d '\r')"

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

telegram_bridge_mode="DISABLED"
if [[ "$telegram_bridge_enabled" == "true" && -n "$telegram_bot_token" ]]; then
  telegram_bridge_mode="PROXY"
fi

echo "ONYX launch profile:"
echo "  defines file: $CONFIG_FILE"
echo "  device: $DEVICE"
echo "  supabase: $supabase_mode"
echo "  telemetry: $telemetry_mode (${telemetry_provider:-unknown})"
echo "  live feed: $live_feed_mode"
echo "  telegram bridge: $telegram_bridge_mode"
if [[ -n "$LOG_FILE" ]]; then
  echo "  log file: $LOG_FILE"
fi

if [[ "$supabase_mode" != "LIVE" ]]; then
  if [[ "$REQUIRE_SUPABASE" -eq 1 ]]; then
    echo "FAIL: SUPABASE_URL and SUPABASE_ANON_KEY must be set when --require-supabase is enabled." >&2
    exit 1
  fi
  echo "WARN: SUPABASE_URL/SUPABASE_ANON_KEY missing; app will run in local fallback mode." >&2
fi

if [[ "$telegram_bridge_mode" == "PROXY" ]]; then
  ./scripts/ensure_telegram_bot_api_proxy.sh --config "$CONFIG_FILE"
fi

./scripts/ensure_yolo_server.sh --config "$CONFIG_FILE"
./scripts/ensure_rtsp_frame_server.sh --config "$CONFIG_FILE"
./scripts/ensure_dvr_proxy.sh --config "$CONFIG_FILE"
./scripts/ensure_camera_worker.sh --config "$CONFIG_FILE" --watchdog

if [[ "$DEVICE" == "chrome" ]] && pgrep -f "flutter.*run.*chrome" >/dev/null 2>&1; then
  echo "Flutter Chrome already running — skipping launch"
  exit 0
fi

echo "Launching ONYX..."
mkdir -p "$(dirname "$FLUTTER_PID_FILE")"
printf '%s\n' "$$" >"$FLUTTER_PID_FILE"
if [[ -n "$LOG_FILE" ]]; then
  mkdir -p "$(dirname "$LOG_FILE")"
  : > "$LOG_FILE"
  flutter run -d "$DEVICE" --dart-define-from-file="$CONFIG_FILE" "$@" 2>&1 | tee "$LOG_FILE"
  exit "${PIPESTATUS[0]}"
fi

exec flutter run -d "$DEVICE" --dart-define-from-file="$CONFIG_FILE" "$@"
