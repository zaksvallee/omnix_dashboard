#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"
LOG_FILE="${ONYX_CAMERA_WORKER_LOG_FILE:-tmp/onyx_camera_worker.log}"
PID_FILE="${ONYX_CAMERA_WORKER_PID_FILE:-tmp/onyx_camera_worker.pid}"
WATCHDOG_LOG_FILE="${ONYX_CAMERA_WORKER_WATCHDOG_LOG_FILE:-tmp/onyx_camera_worker_watchdog.log}"
WATCHDOG_PID_FILE="${ONYX_CAMERA_WORKER_WATCHDOG_PID_FILE:-tmp/onyx_camera_worker_watchdog.pid}"
WATCHDOG_INTERVAL_SECONDS="${ONYX_CAMERA_WORKER_WATCHDOG_INTERVAL_SECONDS:-30}"
WATCHDOG_MODE=0
WATCHDOG_LOOP_MODE=0

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
    --watchdog)
      WATCHDOG_MODE=1
      shift
      ;;
    --watchdog-loop)
      WATCHDOG_LOOP_MODE=1
      shift
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
  matched_pid="$(pgrep -f "bin/onyx_camera_worker.dart" | head -n 1 || true)"
  if [[ -n "$matched_pid" ]]; then
    printf '%s\n' "$matched_pid"
    return 0
  fi
  return 1
}

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

watchdog_running_pid() {
  if [[ -f "$WATCHDOG_PID_FILE" ]]; then
    local existing_pid
    existing_pid="$(tr -d '[:space:]' <"$WATCHDOG_PID_FILE")"
    if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
      printf '%s\n' "$existing_pid"
      return 0
    fi
  fi
  local matched_pid
  matched_pid="$(pgrep -f "ensure_camera_worker\\.sh.*--watchdog-loop" | head -n 1 || true)"
  if [[ -n "$matched_pid" ]]; then
    printf '%s\n' "$matched_pid"
    return 0
  fi
  return 1
}

send_restart_alert() {
  local token chat thread
  token="$(json_value "ONYX_TELEGRAM_BOT_TOKEN" | tr -d '\r')"
  chat="$(json_value "ONYX_TELEGRAM_ADMIN_CHAT_ID" | tr -d '\r')"
  thread="$(json_value "ONYX_TELEGRAM_ADMIN_THREAD_ID" | tr -d '\r')"
  if [[ -z "$token" || -z "$chat" ]]; then
    return 0
  fi
  local timestamp
  timestamp="$(TZ=Africa/Johannesburg date '+%Y-%m-%d %H:%M:%S %Z')"
  local curl_args=(
    -s
    "https://api.telegram.org/bot${token}/sendMessage"
    -d "chat_id=${chat}"
    -d "text=⚠️ ONYX: Camera worker restarted automatically at ${timestamp}"
  )
  if [[ -n "$thread" ]]; then
    curl_args+=(-d "message_thread_id=${thread}")
  fi
  curl "${curl_args[@]}" >/dev/null 2>&1 || true
}

start_worker_once() {
  if existing_pid="$(running_pid)"; then
    mkdir -p "$(dirname "$PID_FILE")"
    printf '%s\n' "$existing_pid" >"$PID_FILE"
    echo "ONYX camera worker already running (pid ${existing_pid})"
    return 0
  fi

  mkdir -p "$(dirname "$LOG_FILE")"
  mkdir -p "$(dirname "$PID_FILE")"
  nohup ./scripts/run_camera_worker.sh --config "$CONFIG_FILE" \
    >"$LOG_FILE" 2>&1 &
  worker_pid=$!
  printf '%s\n' "$worker_pid" >"$PID_FILE"

  for _ in $(seq 1 20); do
    sleep 0.5
    if ! kill -0 "$worker_pid" 2>/dev/null; then
      break
    fi
    if grep -qE 'Camera worker starting|Connected.+listening for events' "$LOG_FILE" 2>/dev/null; then
      echo "ONYX camera worker running (pid ${worker_pid})"
      return 0
    fi
  done

  if kill -0 "$worker_pid" 2>/dev/null; then
    echo "ONYX camera worker running (pid ${worker_pid})"
    return 0
  fi

  echo "FAIL: ONYX camera worker failed to start" >&2
  rm -f "$PID_FILE"
  if [[ -f "$LOG_FILE" ]]; then
    tail -n 40 "$LOG_FILE" >&2 || true
  fi
  return 1
}

run_watchdog_loop() {
  trap 'rm -f "$WATCHDOG_PID_FILE"; exit 0' INT TERM EXIT
  mkdir -p "$(dirname "$WATCHDOG_LOG_FILE")"
  mkdir -p "$(dirname "$WATCHDOG_PID_FILE")"
  printf '%s\n' "$$" >"$WATCHDOG_PID_FILE"
  while true; do
    if ! running_pid >/dev/null 2>&1; then
      echo "[ONYX] ⚠️ Camera worker stopped — restarting..." | tee -a "$WATCHDOG_LOG_FILE"
      if start_worker_once >>"$WATCHDOG_LOG_FILE" 2>&1; then
        send_restart_alert
      fi
    fi
    sleep "$WATCHDOG_INTERVAL_SECONDS"
  done
}

if [[ "$WATCHDOG_LOOP_MODE" -eq 1 ]]; then
  run_watchdog_loop
  exit 0
fi

start_worker_once

if [[ "$WATCHDOG_MODE" -eq 1 ]]; then
  if watchdog_pid="$(watchdog_running_pid)"; then
    mkdir -p "$(dirname "$WATCHDOG_PID_FILE")"
    printf '%s\n' "$watchdog_pid" >"$WATCHDOG_PID_FILE"
    echo "ONYX camera worker watchdog already running (pid ${watchdog_pid})"
    exit 0
  fi
  mkdir -p "$(dirname "$WATCHDOG_LOG_FILE")"
  mkdir -p "$(dirname "$WATCHDOG_PID_FILE")"
  nohup "$0" \
    --config "$CONFIG_FILE" \
    --log-file "$LOG_FILE" \
    --pid-file "$PID_FILE" \
    --watchdog-loop \
    >"$WATCHDOG_LOG_FILE" 2>&1 &
  watchdog_pid=$!
  printf '%s\n' "$watchdog_pid" >"$WATCHDOG_PID_FILE"
  echo "ONYX camera worker watchdog running (pid ${watchdog_pid})"
fi

exit 0
