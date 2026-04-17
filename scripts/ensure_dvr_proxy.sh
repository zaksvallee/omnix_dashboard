#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"
LOG_FILE="${ONYX_DVR_PROXY_LOG_FILE:-tmp/dvr_proxy.log}"
PID_FILE="${ONYX_DVR_PROXY_PID_FILE:-tmp/onyx_dvr_proxy.pid}"
PYTHON_BIN="${ONYX_DVR_PROXY_PYTHON_BIN:-python3}"
PORT="${ONYX_DVR_PROXY_PORT:-11635}"
LOG_ROTATE_BYTES="${ONYX_DVR_PROXY_LOG_ROTATE_BYTES:-52428800}"
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
    --port)
      PORT="${2:-}"
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

rotate_log_if_needed() {
  if [[ ! -f "$LOG_FILE" ]]; then
    return 0
  fi
  local current_size
  current_size="$(wc -c <"$LOG_FILE" | tr -d '[:space:]')"
  if [[ -z "$current_size" || "$current_size" -lt "$LOG_ROTATE_BYTES" ]]; then
    return 0
  fi
  rm -f "${LOG_FILE}.1"
  mv "$LOG_FILE" "${LOG_FILE}.1"
}

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
  matched_pid="$(pgrep -f "scripts/onyx_dvr_cors_proxy\\.py.*--port ${PORT}" | head -n 1 || true)"
  if [[ -n "$matched_pid" ]]; then
    printf '%s\n' "$matched_pid"
    return 0
  fi
  matched_pid="$(pgrep -f "scripts/onyx_dvr_cors_proxy\\.py" | head -n 1 || true)"
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

if existing_pid="$(running_pid)"; then
  mkdir -p "$(dirname "$PID_FILE")"
  printf '%s\n' "$existing_pid" >"$PID_FILE"
  echo "ONYX DVR proxy already running (pid ${existing_pid})"
  exit 0
fi

rotate_log_if_needed
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$PID_FILE")"
touch "$LOG_FILE"
log_lifecycle_event "$START_REASON"
nohup "$PYTHON_BIN" scripts/onyx_dvr_cors_proxy.py --config "$CONFIG_FILE" --port "$PORT" \
  >>"$LOG_FILE" 2>&1 &
proxy_pid=$!
printf '%s\n' "$proxy_pid" >"$PID_FILE"

for _ in $(seq 1 20); do
  sleep 0.5
  if ! kill -0 "$proxy_pid" 2>/dev/null; then
    break
  fi
  if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "ONYX DVR proxy listening on http://127.0.0.1:${PORT}/alertStream"
    exit 0
  fi
done

echo "FAIL: ONYX DVR proxy failed to start on port ${PORT}" >&2
rm -f "$PID_FILE"
if [[ -f "$LOG_FILE" ]]; then
  tail -n 60 "$LOG_FILE" >&2 || true
fi
exit 1
