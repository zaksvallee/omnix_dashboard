#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"
LOG_FILE="${ONYX_YOLO_SERVER_LOG_FILE:-tmp/onyx_yolo_server.log}"
PID_FILE="${ONYX_YOLO_SERVER_PID_FILE:-tmp/onyx_yolo_server.pid}"
VENV_PYTHON="${ROOT_DIR}/.venv-monitoring-yolo/bin/python"
START_SCRIPT="${ROOT_DIR}/scripts/start_yolo_server.sh"
START_REASON="bootstrap"

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

normalized_bool() {
  printf '%s' "$1" | tr -d '\r' | tr '[:upper:]' '[:lower:]'
}

resolved_flag() {
  local primary_key="$1"
  local fallback_key="$2"
  local primary_value="${!primary_key:-}"
  if [[ -z "$primary_value" ]]; then
    primary_value="$(json_value "$primary_key")"
  fi
  if [[ -n "$primary_value" ]]; then
    normalized_bool "$primary_value"
    return 0
  fi
  local fallback_value="${!fallback_key:-}"
  if [[ -z "$fallback_value" ]]; then
    fallback_value="$(json_value "$fallback_key")"
  fi
  normalized_bool "$fallback_value"
}

yolo_enabled="$(json_value "ONYX_MONITORING_YOLO_ENABLED" | tr -d '\r' | tr '[:upper:]' '[:lower:]')"
yolo_fr_enabled="$(resolved_flag "ONYX_FR_ENABLED" "ONYX_MONITORING_FR_ENABLED")"
yolo_lpr_enabled="$(resolved_flag "ONYX_LPR_ENABLED" "ONYX_MONITORING_LPR_ENABLED")"
yolo_host="$(json_value "ONYX_MONITORING_YOLO_HOST" | tr -d '\r')"
yolo_port="$(json_value "ONYX_MONITORING_YOLO_PORT" | tr -d '\r')"
yolo_warmup_seconds="${ONYX_MONITORING_YOLO_WARMUP_SECONDS:-$(json_value "ONYX_MONITORING_YOLO_WARMUP_SECONDS" | tr -d '\r')}"
yolo_host="${yolo_host:-127.0.0.1}"
yolo_port="${yolo_port:-11636}"
yolo_warmup_seconds="${yolo_warmup_seconds:-180}"
if [[ ! "$yolo_warmup_seconds" =~ ^[0-9]+$ ]] || [[ "$yolo_warmup_seconds" -le 0 ]]; then
  yolo_warmup_seconds=180
fi
yolo_url="http://${yolo_host}:${yolo_port}"

if [[ "$yolo_enabled" != "true" ]]; then
  exit 0
fi

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
  matched_pid="$(pgrep -f "tool/monitoring_yolo_detector_service\\.py" | head -n 1 || true)"
  if [[ -n "$matched_pid" ]]; then
    printf '%s\n' "$matched_pid"
    return 0
  fi
  return 1
}

log_lifecycle_event() {
  local reason="${1:-bootstrap}"
  mkdir -p "$(dirname "$LOG_FILE")"
  local epoch timestamp
  epoch="$(date +%s)"
  timestamp="$(TZ=Africa/Johannesburg date '+%Y-%m-%d %H:%M:%S %Z')"
  printf '[ONYX-LIFECYCLE] start epoch=%s reason=%s at=%s\n' \
    "$epoch" \
    "$reason" \
    "$timestamp" >>"$LOG_FILE"
}

healthcheck() {
  python3 - "$yolo_url/health" <<'PY'
import json
import sys
import urllib.request

url = sys.argv[1]
try:
    with urllib.request.urlopen(url, timeout=3) as response:
        data = json.loads(response.read().decode())
    ok = (
        response.status == 200
        and data.get("status") == "ok"
        and bool(data.get("ready"))
    )
except Exception:
    ok = False
sys.exit(0 if ok else 1)
PY
}

dependencies_ready() {
  if [[ ! -x "$VENV_PYTHON" ]]; then
    return 1
  fi
  "$VENV_PYTHON" - "$yolo_fr_enabled" "$yolo_lpr_enabled" <<'PY' >/dev/null 2>&1
import sys
import PIL  # noqa: F401
import pi_heif  # noqa: F401
import ultralytics  # noqa: F401
if sys.argv[1] == "true":
    try:
        import face_recognition  # noqa: F401
    except ImportError:
        sys.exit(1)
if sys.argv[2] == "true":
    import easyocr  # noqa: F401
PY
}

pid_elapsed_seconds() {
  local pid="$1"
  local elapsed
  elapsed="$(ps -o etime= -p "$pid" 2>/dev/null | tr -d '[:space:]')"
  if [[ -z "$elapsed" ]]; then
    return 1
  fi
  python3 - "$elapsed" <<'PY'
import sys

raw = sys.argv[1].strip()
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

if healthcheck; then
  mkdir -p "$(dirname "$PID_FILE")"
  if existing_pid="$(running_pid)"; then
    printf '%s\n' "$existing_pid" >"$PID_FILE"
  fi
  echo "ONYX YOLO detector already reachable on ${yolo_url}"
  exit 0
fi

if existing_pid="$(running_pid)"; then
  existing_age_seconds="$(pid_elapsed_seconds "$existing_pid" || true)"
  if [[ "$existing_age_seconds" =~ ^[0-9]+$ ]] &&
      [[ "$existing_age_seconds" -lt "$yolo_warmup_seconds" ]]; then
    mkdir -p "$(dirname "$PID_FILE")"
    printf '%s\n' "$existing_pid" >"$PID_FILE"
    echo "ONYX YOLO detector warming up on ${yolo_url} (pid ${existing_pid}, age ${existing_age_seconds}s)"
    exit 0
  fi
  echo "Restarting unhealthy ONYX YOLO detector (pid ${existing_pid})"
  START_REASON="restart_unhealthy"
  kill -TERM "$existing_pid" 2>/dev/null || true
  sleep 1
  if kill -0 "$existing_pid" 2>/dev/null; then
    kill -KILL "$existing_pid" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
fi

if ! dependencies_ready; then
  echo "Preparing ONYX YOLO detector environment..."
  bash ./tool/setup_monitoring_yolo_detector.sh
fi

mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$PID_FILE")"
log_lifecycle_event "$START_REASON"
nohup bash "$START_SCRIPT" --config "$CONFIG_FILE" \
  >"$LOG_FILE" 2>&1 &
yolo_pid=$!
printf '%s\n' "$yolo_pid" >"$PID_FILE"

for _ in $(seq 1 60); do
  sleep 0.5
  if healthcheck; then
    echo "ONYX YOLO detector listening on ${yolo_url}"
    exit 0
  fi
  if ! kill -0 "$yolo_pid" 2>/dev/null; then
    break
  fi
  yolo_age_seconds="$(pid_elapsed_seconds "$yolo_pid" || true)"
  if [[ "$yolo_age_seconds" =~ ^[0-9]+$ ]] &&
      [[ "$yolo_age_seconds" -lt "$yolo_warmup_seconds" ]]; then
    echo "ONYX YOLO detector warming up on ${yolo_url} (pid ${yolo_pid}, age ${yolo_age_seconds}s)"
    exit 0
  fi
done

echo "FAIL: ONYX YOLO detector failed to start on ${yolo_url}" >&2
rm -f "$PID_FILE"
if [[ -f "$LOG_FILE" ]]; then
  tail -n 60 "$LOG_FILE" >&2 || true
fi
exit 1
