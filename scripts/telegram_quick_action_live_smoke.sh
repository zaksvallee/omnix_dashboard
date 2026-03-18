#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG_FILE="config/onyx.local.json"
WEB_PORT="63123"
LOG_FILE="tmp/telegram_quick_action_live.log"
TELEGRAM_POLLS="0"
TELEGRAM_INTERVAL="5"
TELEGRAM_WATCH_ENABLED="off"
DVR_PROXY_PORT="9081"
DVR_PROXY_ENABLED="auto"
EFFECTIVE_CONFIG_FILE=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/telegram_quick_action_live_smoke.sh [--config <path>] [--web-port <port>] [--log-file <path>] [--poll-seconds <seconds>] [--telegram-polls <count>] [--telegram-watch <on|off>] [--dvr-proxy-port <port>] [--dvr-proxy <auto|on|off>]

Examples:
  ./scripts/telegram_quick_action_live_smoke.sh
  ./scripts/telegram_quick_action_live_smoke.sh --telegram-watch on --telegram-polls 24

This command:
  1. launches ONYX with a captured log file
  2. optionally starts a local DVR CORS proxy for browser-safe Hikvision polling
  3. starts a focused ONYX quick-action log watcher
  4. optionally starts a Telegram update watcher for the configured client chat

Stop it with Ctrl+C after the live Status/Details smoke completes.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="${2:-}"
      shift 2
      ;;
    --web-port)
      WEB_PORT="${2:-}"
      shift 2
      ;;
    --log-file)
      LOG_FILE="${2:-}"
      shift 2
      ;;
    --poll-seconds)
      TELEGRAM_INTERVAL="${2:-}"
      shift 2
      ;;
    --telegram-polls)
      TELEGRAM_POLLS="${2:-}"
      shift 2
      ;;
    --telegram-watch)
      TELEGRAM_WATCH_ENABLED="${2:-}"
      shift 2
      ;;
    --dvr-proxy-port)
      DVR_PROXY_PORT="${2:-}"
      shift 2
      ;;
    --dvr-proxy)
      DVR_PROXY_ENABLED="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

cleanup() {
  local code=$?
  trap - EXIT INT TERM
  if [[ -n "${DVR_PROXY_PID:-}" ]]; then
    kill "$DVR_PROXY_PID" 2>/dev/null || true
  fi
  if [[ -n "${LOG_WATCH_PID:-}" ]]; then
    kill "$LOG_WATCH_PID" 2>/dev/null || true
  fi
  if [[ -n "${TELEGRAM_WATCH_PID:-}" ]]; then
    kill "$TELEGRAM_WATCH_PID" 2>/dev/null || true
  fi
  if [[ -n "${APP_PID:-}" ]]; then
    kill "$APP_PID" 2>/dev/null || true
  fi
  wait 2>/dev/null || true
  exit "$code"
}

trap cleanup EXIT INT TERM

should_enable_dvr_proxy() {
  python3 - "$CONFIG_FILE" "$DVR_PROXY_ENABLED" <<'PY'
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
mode = sys.argv[2].strip().lower()
if mode == "on":
    print("1")
    raise SystemExit(0)
if mode == "off":
    print("0")
    raise SystemExit(0)

cfg = json.loads(config_path.read_text(encoding="utf-8"))
raw = str(cfg.get("ONYX_DVR_SCOPE_CONFIGS_JSON", "")).strip()
if not raw:
    print("0")
    raise SystemExit(0)
scopes = json.loads(raw)
if not scopes:
    print("0")
    raise SystemExit(0)
events_url = str(scopes[0].get("events_url", "")).strip().lower()
print("1" if events_url.startswith("http://192.168.") or events_url.startswith("http://10.") or events_url.startswith("http://172.") else "0")
PY
}

build_proxy_config() {
  local target_config="$1"
  python3 - "$CONFIG_FILE" "$target_config" "$DVR_PROXY_PORT" <<'PY'
import json
import sys
from pathlib import Path

source_path = Path(sys.argv[1])
target_path = Path(sys.argv[2])
proxy_port = sys.argv[3]
cfg = json.loads(source_path.read_text(encoding="utf-8"))
raw = str(cfg.get("ONYX_DVR_SCOPE_CONFIGS_JSON", "")).strip()
if raw:
    scopes = json.loads(raw)
    for scope in scopes:
        scope["events_url"] = f"http://127.0.0.1:{proxy_port}/alertStream"
    cfg["ONYX_DVR_SCOPE_CONFIGS_JSON"] = json.dumps(scopes, separators=(",", ":"))
target_path.write_text(json.dumps(cfg, indent=2) + "\n", encoding="utf-8")
print(target_path)
PY
}

echo "Starting ONYX live quick-action smoke..."
echo "  config: $CONFIG_FILE"
echo "  web port: $WEB_PORT"
echo "  log file: $LOG_FILE"
echo "  telegram watcher: $TELEGRAM_WATCH_ENABLED"

if [[ "$(should_enable_dvr_proxy)" == "1" ]]; then
  EFFECTIVE_CONFIG_FILE="tmp/telegram_quick_action_live_proxy_config.json"
  mkdir -p "$(dirname "$EFFECTIVE_CONFIG_FILE")"
  build_proxy_config "$EFFECTIVE_CONFIG_FILE" >/dev/null
  echo "  dvr proxy: on (port $DVR_PROXY_PORT)"
  python3 scripts/onyx_dvr_cors_proxy.py \
    --config "$CONFIG_FILE" \
    --port "$DVR_PROXY_PORT" &
  DVR_PROXY_PID=$!
else
  EFFECTIVE_CONFIG_FILE="$CONFIG_FILE"
  echo "  dvr proxy: off"
fi

./scripts/run_onyx_chrome_local.sh \
  --config "$EFFECTIVE_CONFIG_FILE" \
  --log-file "$LOG_FILE" \
  -- \
  --web-port "$WEB_PORT" &
APP_PID=$!

python3 scripts/watch_onyx_quick_actions.py --log-file "$LOG_FILE" &
LOG_WATCH_PID=$!

if [[ "$TELEGRAM_WATCH_ENABLED" == "on" ]]; then
  TELEGRAM_WATCH_ARGS=(
    python3
    scripts/watch_telegram_updates.py
    --config
    "$CONFIG_FILE"
    --interval-seconds
    "$TELEGRAM_INTERVAL"
  )
  if [[ "$TELEGRAM_POLLS" != "0" ]]; then
    TELEGRAM_WATCH_ARGS+=(--polls "$TELEGRAM_POLLS")
  fi
  "${TELEGRAM_WATCH_ARGS[@]}" &
  TELEGRAM_WATCH_PID=$!
fi

echo
echo "Live smoke is running."
echo "Send 'Status' or 'Details' from the real client Telegram thread."
echo "Stop with Ctrl+C when the smoke is complete."

wait "$APP_PID"
