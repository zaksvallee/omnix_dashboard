#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"
LOG_FILE="${ONYX_CAMERA_WORKER_LOG_FILE:-tmp/onyx_camera_worker.log}"
PID_FILE="${ONYX_CAMERA_WORKER_PID_FILE:-tmp/onyx_camera_worker.pid}"

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

if existing_pid="$(running_pid)"; then
  mkdir -p "$(dirname "$PID_FILE")"
  printf '%s\n' "$existing_pid" >"$PID_FILE"
  echo "ONYX camera worker already running (pid ${existing_pid})"
  exit 0
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
    exit 0
  fi
done

if kill -0 "$worker_pid" 2>/dev/null; then
  echo "ONYX camera worker running (pid ${worker_pid})"
  exit 0
fi

echo "FAIL: ONYX camera worker failed to start" >&2
rm -f "$PID_FILE"
if [[ -f "$LOG_FILE" ]]; then
  tail -n 40 "$LOG_FILE" >&2 || true
fi
exit 1
