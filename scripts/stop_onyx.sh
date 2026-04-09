#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
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

FLUTTER_PID_FILE="${ONYX_FLUTTER_PID_FILE:-tmp/onyx_flutter.pid}"
PROXY_PID_FILE="${ONYX_TELEGRAM_PROXY_PID_FILE:-tmp/onyx_telegram_proxy.pid}"
WORKER_PID_FILE="${ONYX_CAMERA_WORKER_PID_FILE:-tmp/onyx_camera_worker.pid}"

kill_from_pid_file() {
  local pid_file="$1"
  local label="$2"
  if [[ ! -f "$pid_file" ]]; then
    return 1
  fi
  local pid
  pid="$(tr -d '[:space:]' <"$pid_file")"
  if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
    rm -f "$pid_file"
    return 1
  fi
  echo "Stopping ${label} (pid ${pid})"
  kill -TERM "$pid" 2>/dev/null || true
  for _ in $(seq 1 20); do
    if ! kill -0 "$pid" 2>/dev/null; then
      rm -f "$pid_file"
      return 0
    fi
    sleep 0.25
  done
  kill -KILL "$pid" 2>/dev/null || true
  rm -f "$pid_file"
  return 0
}

kill_by_pattern() {
  local pattern="$1"
  local label="$2"
  local pids
  pids="$(pgrep -f "$pattern" || true)"
  if [[ -z "$pids" ]]; then
    return 1
  fi
  echo "Stopping ${label} (${pids//$'\n'/, })"
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    kill -TERM "$pid" 2>/dev/null || true
  done <<<"$pids"
  sleep 1
  while IFS= read -r pid; do
    [[ -n "$pid" ]] || continue
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
  done <<<"$pids"
  return 0
}

kill_from_pid_file "$FLUTTER_PID_FILE" "Flutter app" || \
  kill_by_pattern "flutter_tools\\.snapshot run|flutter run -d" "Flutter app" || true
kill_from_pid_file "$PROXY_PID_FILE" "Telegram proxy" || \
  kill_by_pattern "bin/onyx_telegram_bot_api_proxy\\.dart" "Telegram proxy" || true
kill_from_pid_file "$WORKER_PID_FILE" "Camera worker" || \
  kill_by_pattern "bin/onyx_camera_worker\\.dart" "Camera worker" || true

rm -f "$FLUTTER_PID_FILE" "$PROXY_PID_FILE" "$WORKER_PID_FILE"
echo "ONYX stack stop complete."
