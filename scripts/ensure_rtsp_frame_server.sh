#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"
LOG_FILE="${ONYX_RTSP_FRAME_SERVER_LOG_FILE:-tmp/onyx_rtsp_frame_server.log}"
PID_FILE="${ONYX_RTSP_FRAME_SERVER_PID_FILE:-tmp/onyx_rtsp_frame_server.pid}"
PYTHON_BIN="${ROOT_DIR}/.venv-monitoring-yolo/bin/python"

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

server_host="$(json_value "ONYX_RTSP_FRAME_SERVER_HOST" | tr -d '\r')"
server_port="$(json_value "ONYX_RTSP_FRAME_SERVER_PORT" | tr -d '\r')"
server_host="${server_host:-127.0.0.1}"
server_port="${server_port:-11638}"
server_url="http://${server_host}:${server_port}"

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
  matched_pid="$(pgrep -f "tool/onyx_rtsp_frame_server\\.py" | head -n 1 || true)"
  if [[ -n "$matched_pid" ]]; then
    printf '%s\n' "$matched_pid"
    return 0
  fi
  return 1
}

healthcheck() {
  python3 - "$server_url/health" <<'PY'
import json
import sys
import urllib.request
url = sys.argv[1]
try:
    with urllib.request.urlopen(url, timeout=3) as response:
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
  echo "ONYX RTSP frame server already reachable on ${server_url}"
  exit 0
fi

if existing_pid="$(running_pid)"; then
  echo "Restarting ONYX RTSP frame server (pid ${existing_pid})"
  kill -TERM "$existing_pid" 2>/dev/null || true
  sleep 1
  if kill -0 "$existing_pid" 2>/dev/null; then
    kill -KILL "$existing_pid" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
fi

if [[ ! -x "$PYTHON_BIN" ]]; then
  PYTHON_BIN="python3"
fi

mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$PID_FILE")"
nohup "$PYTHON_BIN" "$ROOT_DIR/tool/onyx_rtsp_frame_server.py" --config "$CONFIG_FILE" \
  >"$LOG_FILE" 2>&1 &
server_pid=$!
printf '%s\n' "$server_pid" >"$PID_FILE"

for _ in $(seq 1 40); do
  sleep 0.5
  if healthcheck; then
    echo "ONYX RTSP frame server listening on ${server_url}"
    exit 0
  fi
  if ! kill -0 "$server_pid" 2>/dev/null; then
    break
  fi
done

echo "FAIL: ONYX RTSP frame server failed to start on ${server_url}" >&2
rm -f "$PID_FILE"
if [[ -f "$LOG_FILE" ]]; then
  tail -n 60 "$LOG_FILE" >&2 || true
fi
exit 1
