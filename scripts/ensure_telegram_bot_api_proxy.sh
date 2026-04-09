#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"
LOG_FILE="${ONYX_TELEGRAM_PROXY_LOG_FILE:-tmp/onyx_telegram_proxy.log}"
PID_FILE="${ONYX_TELEGRAM_PROXY_PID_FILE:-tmp/onyx_telegram_proxy.pid}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="${2:-}"
      shift 2
      ;;
    --log-file)
      LOG_FILE="${2:-}"
      shift 2
      ;;
    --pid-file)
      PID_FILE="${2:-}"
      shift 2
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
  exit 1
fi

json_value() {
  local key="$1"
  python3 - "$CONFIG_FILE" "$key" <<'PY'
import json
import sys

path, key = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)
value = data.get(key, "")
print("" if value is None else value)
PY
}

bridge_enabled="$(json_value "ONYX_TELEGRAM_BRIDGE_ENABLED" | tr -d '\r' | tr '[:upper:]' '[:lower:]')"
bot_token="$(json_value "ONYX_TELEGRAM_BOT_TOKEN" | tr -d '\r')"
proxy_host="$(json_value "ONYX_TELEGRAM_PROXY_HOST" | tr -d '\r')"
proxy_port="$(json_value "ONYX_TELEGRAM_PROXY_PORT" | tr -d '\r')"

if [[ "$bridge_enabled" != "true" || -z "$bot_token" ]]; then
  exit 0
fi

proxy_host="${proxy_host:-127.0.0.1}"
proxy_port="${proxy_port:-11637}"
proxy_url="http://${proxy_host}:${proxy_port}"

running_pid() {
  if [[ -f "$PID_FILE" ]]; then
    local existing_pid
    existing_pid="$(tr -d '[:space:]' <"$PID_FILE")"
    if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
      printf '%s\n' "$existing_pid"
      return 0
    fi
  fi
  local matched_pid
  matched_pid="$(pgrep -f "bin/onyx_telegram_bot_api_proxy.dart" | head -n 1 || true)"
  if [[ -n "$matched_pid" ]]; then
    printf '%s\n' "$matched_pid"
    return 0
  fi
  return 1
}

healthcheck() {
  python3 - "$proxy_url/health" <<'PY'
import json
import sys
import urllib.request

url = sys.argv[1]
try:
    with urllib.request.urlopen(url, timeout=2) as response:
        data = json.loads(response.read().decode())
    ok = response.status == 200 and data.get("status") == "ok"
except Exception:
    ok = False
sys.exit(0 if ok else 1)
PY
}

if healthcheck; then
  mkdir -p "$(dirname "$PID_FILE")"
  if existing_pid="$(running_pid)"; then
    printf '%s\n' "$existing_pid" >"$PID_FILE"
  fi
  echo "ONYX Telegram proxy already reachable on ${proxy_url}"
  exit 0
fi

mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$PID_FILE")"
nohup dart run bin/onyx_telegram_bot_api_proxy.dart --config "$CONFIG_FILE" \
  >"$LOG_FILE" 2>&1 &
proxy_pid=$!
printf '%s\n' "$proxy_pid" >"$PID_FILE"

for _ in $(seq 1 20); do
  sleep 0.5
  if healthcheck; then
    echo "ONYX Telegram proxy listening on ${proxy_url}"
    exit 0
  fi
  if ! kill -0 "$proxy_pid" 2>/dev/null; then
    break
  fi
done

echo "FAIL: ONYX Telegram proxy failed to start on ${proxy_url}" >&2
rm -f "$PID_FILE"
if [[ -f "$LOG_FILE" ]]; then
  tail -n 40 "$LOG_FILE" >&2 || true
fi
exit 1
