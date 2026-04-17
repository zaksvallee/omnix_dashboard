#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"
FLUTTER_PID_FILE="${ONYX_FLUTTER_PID_FILE:-tmp/onyx_flutter.pid}"
PROXY_PID_FILE="${ONYX_TELEGRAM_PROXY_PID_FILE:-tmp/onyx_telegram_proxy.pid}"
WORKER_PID_FILE="${ONYX_CAMERA_WORKER_PID_FILE:-tmp/onyx_camera_worker.pid}"
YOLO_PID_FILE="${ONYX_YOLO_SERVER_PID_FILE:-tmp/onyx_yolo_server.pid}"
RTSP_FRAME_PID_FILE="${ONYX_RTSP_FRAME_SERVER_PID_FILE:-tmp/onyx_rtsp_frame_server.pid}"
DVR_PROXY_PID_FILE="${ONYX_DVR_PROXY_PID_FILE:-tmp/onyx_dvr_proxy.pid}"
WORKER_WATCHDOG_PID_FILE="${ONYX_CAMERA_WORKER_WATCHDOG_PID_FILE:-tmp/onyx_camera_worker_watchdog.pid}"
LEGACY_WATCHDOG_PID_FILE="${ONYX_WATCHDOG_PID_FILE:-tmp/onyx_watchdog.pid}"
PROXY_LOG_FILE="${ONYX_TELEGRAM_PROXY_LOG_FILE:-tmp/onyx_telegram_proxy.log}"
WORKER_LOG_FILE="${ONYX_CAMERA_WORKER_LOG_FILE:-tmp/onyx_camera_worker.log}"
WORKER_WATCHDOG_LOG_FILE="${ONYX_CAMERA_WORKER_WATCHDOG_LOG_FILE:-tmp/onyx_camera_worker_watchdog.log}"
LEGACY_WATCHDOG_LOG_FILE="${ONYX_WATCHDOG_LOG_FILE:-tmp/onyx_watchdog.log}"
YOLO_LOG_FILE="${ONYX_YOLO_SERVER_LOG_FILE:-tmp/onyx_yolo_server.log}"
RTSP_FRAME_LOG_FILE="${ONYX_RTSP_FRAME_SERVER_LOG_FILE:-tmp/onyx_rtsp_frame_server.log}"
DVR_PROXY_LOG_FILE="${ONYX_DVR_PROXY_LOG_FILE:-tmp/dvr_proxy.log}"
UPTIME_RESTART_THRESHOLD_SECONDS="${ONYX_STATUS_RESTARTING_THRESHOLD_SECONDS:-10}"
RESPAWN_WINDOW_SECONDS="${ONYX_STATUS_RESPAWN_WINDOW_SECONDS:-60}"
CRASH_LOOP_RESPAWN_THRESHOLD="${ONYX_STATUS_CRASH_LOOP_THRESHOLD:-3}"

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

pid_elapsed_raw() {
  local pid="$1"
  ps -o etime= -p "$pid" 2>/dev/null | tr -d '[:space:]'
}

elapsed_to_seconds() {
  local raw="$1"
  python3 - "$raw" <<'PY'
import sys

raw = sys.argv[1].strip()
if not raw:
    raise SystemExit(1)
days = 0
if "-" in raw:
    days_part, raw = raw.split("-", 1)
    days = int(days_part or "0")
parts = [int(part or "0") for part in raw.split(":")]
if len(parts) == 3:
    hours, minutes, seconds = parts
elif len(parts) == 2:
    hours, minutes, seconds = 0, parts[0], parts[1]
elif len(parts) == 1:
    hours, minutes, seconds = 0, 0, parts[0]
else:
    raise SystemExit(1)
print(days * 86400 + hours * 3600 + minutes * 60 + seconds)
PY
}

format_uptime() {
  local total_seconds="$1"
  python3 - "$total_seconds" <<'PY'
import sys

total = int(sys.argv[1])
days, remainder = divmod(total, 86400)
hours, remainder = divmod(remainder, 3600)
minutes, seconds = divmod(remainder, 60)
parts = []
if days:
    parts.append(f"{days}d")
if hours:
    parts.append(f"{hours}h")
if minutes:
    parts.append(f"{minutes}m")
if seconds or not parts:
    parts.append(f"{seconds}s")
print(" ".join(parts))
PY
}

count_recent_restart_events() {
  local window_seconds="$1"
  shift
  python3 - "$window_seconds" "$@" <<'PY'
import os
import re
import sys
from collections import deque
from time import time

window = int(sys.argv[1])
paths = [path for path in sys.argv[2:] if path]
now = int(time())
cutoff = now - window
count = 0
fallback_count = 0

for path in paths:
    if not os.path.exists(path):
        continue
    try:
        recent_mtime = os.path.getmtime(path) >= cutoff
        lines = deque(maxlen=400)
        with open(path, "r", encoding="utf-8", errors="ignore") as handle:
            for line in handle:
                lines.append(line.rstrip("\n"))
    except OSError:
        continue

    for line in lines:
        match = re.search(r"epoch=(\d+)", line)
        if match:
            if int(match.group(1)) >= cutoff:
                count += 1
            continue
        if recent_mtime and (
            "stopped — restarting" in line.lower()
            or "[onyx-lifecycle] start" in line.lower()
        ):
            fallback_count += 1

print(count if count > 0 else fallback_count)
PY
}

resolve_worker_watchdog_pid() {
  if [[ -f "$WORKER_WATCHDOG_PID_FILE" ]]; then
    local existing_pid
    existing_pid="$(tr -d '[:space:]' <"$WORKER_WATCHDOG_PID_FILE")"
    if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
      printf '%s\n' "$existing_pid"
      return 0
    fi
  fi
  if [[ -f "$LEGACY_WATCHDOG_PID_FILE" ]]; then
    local legacy_pid
    legacy_pid="$(tr -d '[:space:]' <"$LEGACY_WATCHDOG_PID_FILE")"
    if [[ -n "$legacy_pid" ]] && kill -0 "$legacy_pid" 2>/dev/null; then
      printf '%s\n' "$legacy_pid"
      return 0
    fi
  fi
  local matched_pid
  matched_pid="$(pgrep -f "onyx_watchdog\\.sh|ensure_camera_worker\\.sh.*--watchdog-loop" | head -n 1 || true)"
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
  shift 3
  local log_files=()
  if [[ $# -gt 0 ]]; then
    log_files=("$@")
  fi
  if pid="$(resolve_pid "$pid_file" "$pattern")"; then
    local command
    command="$(ps -p "$pid" -o command= 2>/dev/null | sed 's/^[[:space:]]*//')"
    local elapsed_raw elapsed_seconds uptime_label restart_count state details
    elapsed_raw="$(pid_elapsed_raw "$pid" || true)"
    elapsed_seconds=""
    uptime_label=""
    if [[ -n "$elapsed_raw" ]]; then
      elapsed_seconds="$(elapsed_to_seconds "$elapsed_raw" || true)"
      if [[ "$elapsed_seconds" =~ ^[0-9]+$ ]]; then
        uptime_label="$(format_uptime "$elapsed_seconds")"
      fi
    fi
    if [[ "${#log_files[@]}" -gt 0 ]]; then
      restart_count="$(count_recent_restart_events "$RESPAWN_WINDOW_SECONDS" "${log_files[@]}")"
    else
      restart_count=0
    fi
    state="RUNNING"
    if [[ "$restart_count" =~ ^[0-9]+$ ]] &&
      [[ "$restart_count" -gt "$CRASH_LOOP_RESPAWN_THRESHOLD" ]]; then
      state="CRASH-LOOPING"
    elif [[ "$elapsed_seconds" =~ ^[0-9]+$ ]] &&
      [[ "$elapsed_seconds" -lt "$UPTIME_RESTART_THRESHOLD_SECONDS" ]]; then
      state="RESTARTING"
    fi
    details="pid ${pid}"
    if [[ -n "$uptime_label" ]]; then
      details="${details}, uptime ${uptime_label}"
    fi
    if [[ "$restart_count" =~ ^[0-9]+$ ]] && [[ "$restart_count" -gt 0 ]]; then
      details="${details}, respawns ${restart_count}/${RESPAWN_WINDOW_SECONDS}s"
    fi
    echo "${label}: ${state} (${details})"
    if [[ -n "$command" ]]; then
      echo "  ${command}"
    fi
    return 0
  fi
  echo "${label}: STOPPED"
  return 1
}

render_camera_worker_status() {
  if pid="$(resolve_pid "$WORKER_PID_FILE" "bin/onyx_camera_worker\\.dart")"; then
    local command elapsed_raw elapsed_seconds uptime_label restart_count state details
    command="$(ps -p "$pid" -o command= 2>/dev/null | sed 's/^[[:space:]]*//')"
    elapsed_raw="$(pid_elapsed_raw "$pid" || true)"
    elapsed_seconds=""
    uptime_label=""
    if [[ -n "$elapsed_raw" ]]; then
      elapsed_seconds="$(elapsed_to_seconds "$elapsed_raw" || true)"
      if [[ "$elapsed_seconds" =~ ^[0-9]+$ ]]; then
        uptime_label="$(format_uptime "$elapsed_seconds")"
      fi
    fi
    restart_count="$(count_recent_restart_events "$RESPAWN_WINDOW_SECONDS" "$WORKER_LOG_FILE" "$WORKER_WATCHDOG_LOG_FILE" "$LEGACY_WATCHDOG_LOG_FILE")"
    state="RUNNING"
    if [[ "$restart_count" =~ ^[0-9]+$ ]] &&
      [[ "$restart_count" -gt "$CRASH_LOOP_RESPAWN_THRESHOLD" ]]; then
      state="CRASH-LOOPING"
    elif [[ "$elapsed_seconds" =~ ^[0-9]+$ ]] &&
      [[ "$elapsed_seconds" -lt "$UPTIME_RESTART_THRESHOLD_SECONDS" ]]; then
      state="RESTARTING"
    fi
    details="pid ${pid}"
    if [[ -n "$uptime_label" ]]; then
      details="${details}, uptime ${uptime_label}"
    fi
    if [[ "$restart_count" =~ ^[0-9]+$ ]] && [[ "$restart_count" -gt 0 ]]; then
      details="${details}, respawns ${restart_count}/${RESPAWN_WINDOW_SECONDS}s"
    fi
    echo "Camera worker: ${state} (${details})"
    if [[ -n "$command" ]]; then
      echo "  ${command}"
    fi
    return 0
  fi

  if watchdog_pid="$(resolve_worker_watchdog_pid)"; then
    local watchdog_command
    watchdog_command="$(ps -p "$watchdog_pid" -o command= 2>/dev/null | sed 's/^[[:space:]]*//')"
    echo "Camera worker: RESTARTING (watchdog pid ${watchdog_pid}, awaiting respawn)"
    if [[ -n "$watchdog_command" ]]; then
      echo "  ${watchdog_command}"
    fi
    return 0
  fi

  echo "Camera worker: STOPPED"
  echo "Camera worker state: DISCONNECTED — RESTART REQUIRED"
  return 1
}

proxy_host="$(json_value "ONYX_TELEGRAM_PROXY_HOST" | tr -d '\r')"
proxy_port="$(json_value "ONYX_TELEGRAM_PROXY_PORT" | tr -d '\r')"
yolo_enabled="$(json_value "ONYX_MONITORING_YOLO_ENABLED" | tr -d '\r' | tr '[:upper:]' '[:lower:]')"
yolo_host="$(json_value "ONYX_MONITORING_YOLO_HOST" | tr -d '\r')"
yolo_port="$(json_value "ONYX_MONITORING_YOLO_PORT" | tr -d '\r')"
rtsp_frame_host="$(json_value "ONYX_RTSP_FRAME_SERVER_HOST" | tr -d '\r')"
rtsp_frame_port="$(json_value "ONYX_RTSP_FRAME_SERVER_PORT" | tr -d '\r')"
dvr_proxy_port="$(json_value "ONYX_DVR_PROXY_PORT" | tr -d '\r')"
proxy_host="${proxy_host:-127.0.0.1}"
proxy_port="${proxy_port:-11637}"
yolo_host="${yolo_host:-127.0.0.1}"
yolo_port="${yolo_port:-11636}"
rtsp_frame_host="${rtsp_frame_host:-127.0.0.1}"
rtsp_frame_port="${rtsp_frame_port:-11638}"
dvr_proxy_port="${dvr_proxy_port:-11635}"
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
  "bin/onyx_telegram_bot_api_proxy\\.dart" \
  "$PROXY_LOG_FILE" || true
if [[ "$yolo_enabled" == "true" ]]; then
  render_process_status \
    "YOLO detector" \
    "$YOLO_PID_FILE" \
    "tool/monitoring_yolo_detector_service\\.py" \
    "$YOLO_LOG_FILE" || true
  render_process_status \
    "RTSP frame server" \
    "$RTSP_FRAME_PID_FILE" \
    "tool/onyx_rtsp_frame_server\\.py" \
    "$RTSP_FRAME_LOG_FILE" || true
else
  echo "YOLO detector: DISABLED"
  echo "RTSP frame server: DISABLED"
fi
render_process_status \
  "DVR proxy" \
  "$DVR_PROXY_PID_FILE" \
  "scripts/onyx_dvr_cors_proxy\\.py" \
  "$DVR_PROXY_LOG_FILE" || true
if render_camera_worker_status; then
  :
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
  if lsof -nP -iTCP:"$rtsp_frame_port" -sTCP:LISTEN >/tmp/onyx_rtsp_frame_lsof_status 2>/dev/null; then
    echo "RTSP frame listen:"
    sed 's/^/  /' /tmp/onyx_rtsp_frame_lsof_status
    rm -f /tmp/onyx_rtsp_frame_lsof_status
  else
    echo "RTSP frame listen: not detected on ${rtsp_frame_host}:${rtsp_frame_port}"
  fi
  python3 - "$rtsp_frame_host" "$rtsp_frame_port" <<'PY'
import json
import sys
import urllib.request

host, port = sys.argv[1], sys.argv[2]
url = f"http://{host}:{port}/health"
try:
    with urllib.request.urlopen(url, timeout=3) as response:
        data = json.loads(response.read().decode())
    ready = bool(data.get("ready"))
    channel_count = data.get("channel_count", "unknown")
    print(f"RTSP frame health: {'ready' if ready else 'warming'} ({channel_count} channels)")
except Exception as exc:
    print(f"RTSP frame health: error ({exc})")
PY
fi

if lsof -nP -iTCP:"$dvr_proxy_port" -sTCP:LISTEN >/tmp/onyx_dvr_proxy_lsof_status 2>/dev/null; then
  echo "DVR proxy listen:"
  sed 's/^/  /' /tmp/onyx_dvr_proxy_lsof_status
  rm -f /tmp/onyx_dvr_proxy_lsof_status
else
  echo "DVR proxy listen: not detected on 127.0.0.1:${dvr_proxy_port}"
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
