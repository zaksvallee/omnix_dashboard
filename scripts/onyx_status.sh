#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"
FLUTTER_PID_FILE="${ONYX_FLUTTER_PID_FILE:-tmp/onyx_flutter.pid}"
PROXY_PID_FILE="${ONYX_TELEGRAM_PROXY_PID_FILE:-tmp/onyx_telegram_proxy.pid}"
WORKER_PID_FILE="${ONYX_CAMERA_WORKER_PID_FILE:-tmp/onyx_camera_worker.pid}"
YOLO_PID_FILE="${ONYX_YOLO_SERVER_PID_FILE:-tmp/onyx_yolo_server.pid}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="${2:-}"
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

resolve_pid() {
  local pid_file="$1"
  local pattern="$2"
  if [[ -f "$pid_file" ]]; then
    local pid
    pid="$(tr -d '[:space:]' <"$pid_file")"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      printf '%s\n' "$pid"
      return 0
    fi
  fi
  local matched_pid
  matched_pid="$(pgrep -f "$pattern" | head -n 1 || true)"
  if [[ -n "$matched_pid" ]]; then
    printf '%s\n' "$matched_pid"
    return 0
  fi
  return 1
}

render_process_status() {
  local label="$1"
  local pid_file="$2"
  local pattern="$3"
  if pid="$(resolve_pid "$pid_file" "$pattern")"; then
    local command
    command="$(ps -p "$pid" -o command= 2>/dev/null | sed 's/^[[:space:]]*//')"
    echo "${label}: RUNNING (pid ${pid})"
    if [[ -n "$command" ]]; then
      echo "  ${command}"
    fi
    return 0
  fi
  echo "${label}: STOPPED"
  return 1
}

proxy_host="$(json_value "ONYX_TELEGRAM_PROXY_HOST" | tr -d '\r')"
proxy_port="$(json_value "ONYX_TELEGRAM_PROXY_PORT" | tr -d '\r')"
yolo_enabled="$(json_value "ONYX_MONITORING_YOLO_ENABLED" | tr -d '\r' | tr '[:upper:]' '[:lower:]')"
yolo_host="$(json_value "ONYX_MONITORING_YOLO_HOST" | tr -d '\r')"
yolo_port="$(json_value "ONYX_MONITORING_YOLO_PORT" | tr -d '\r')"
proxy_host="${proxy_host:-127.0.0.1}"
proxy_port="${proxy_port:-11637}"
yolo_host="${yolo_host:-127.0.0.1}"
yolo_port="${yolo_port:-11636}"
telegram_token="$(json_value "ONYX_TELEGRAM_BOT_TOKEN" | tr -d '\r')"

echo "ONYX stack status"
echo "Config: ${CONFIG_FILE}"
render_process_status \
  "Flutter app" \
  "$FLUTTER_PID_FILE" \
  "flutter_tools\\.snapshot run|flutter run -d" || true
render_process_status \
  "Telegram proxy" \
  "$PROXY_PID_FILE" \
  "bin/onyx_telegram_bot_api_proxy\\.dart" || true
if [[ "$yolo_enabled" == "true" ]]; then
  render_process_status \
    "YOLO detector" \
    "$YOLO_PID_FILE" \
    "tool/monitoring_yolo_detector_service\\.py" || true
else
  echo "YOLO detector: DISABLED"
fi
if render_process_status \
  "Camera worker" \
  "$WORKER_PID_FILE" \
  "bin/onyx_camera_worker\\.dart"; then
  :
else
  echo "Camera worker state: DISCONNECTED — RESTART REQUIRED"
fi

if lsof -nP -iTCP:"$proxy_port" -sTCP:LISTEN >/tmp/onyx_proxy_lsof_status 2>/dev/null; then
  echo "Proxy listen:"
  sed 's/^/  /' /tmp/onyx_proxy_lsof_status
  rm -f /tmp/onyx_proxy_lsof_status
else
  echo "Proxy listen: not detected on ${proxy_host}:${proxy_port}"
fi

if [[ "$yolo_enabled" == "true" ]]; then
  if lsof -nP -iTCP:"$yolo_port" -sTCP:LISTEN >/tmp/onyx_yolo_lsof_status 2>/dev/null; then
    echo "YOLO listen:"
    sed 's/^/  /' /tmp/onyx_yolo_lsof_status
    rm -f /tmp/onyx_yolo_lsof_status
  else
    echo "YOLO listen: not detected on ${yolo_host}:${yolo_port}"
  fi
  python3 - "$yolo_host" "$yolo_port" <<'PY'
import json
import sys
import urllib.request

host, port = sys.argv[1], sys.argv[2]
url = f"http://{host}:{port}/health"
try:
    with urllib.request.urlopen(url, timeout=3) as response:
        data = json.loads(response.read().decode())
    backend = data.get("backend", "unknown")
    ready = bool(data.get("ready"))
    detail = data.get("detail") or "ok"
    print(f"YOLO health: {'ready' if ready else 'not ready'} ({backend}; {detail})")
except Exception as exc:
    print(f"YOLO health: error ({exc})")
PY
fi

if [[ -n "$telegram_token" ]]; then
  python3 - "$telegram_token" <<'PY'
import json
import sys
import urllib.request

token = sys.argv[1].strip()
url = f"https://api.telegram.org/bot{token}/getWebhookInfo"
try:
    with urllib.request.urlopen(url, timeout=5) as response:
        data = json.loads(response.read().decode())
    result = data.get("result", {})
    print(f"Telegram queue depth: {result.get('pending_update_count', 'unknown')}")
except Exception as exc:
    print(f"Telegram queue depth: error ({exc})")
PY
else
  echo "Telegram queue depth: token missing from config"
fi
