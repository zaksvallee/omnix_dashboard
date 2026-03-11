#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SERIAL=""
CLEAR_LOG=0

usage() {
  cat <<USAGE
Usage: ./scripts/guard_android_ui_action_watch.sh [--serial <device-serial>] [--clear]

Streams Android logcat and highlights ONYX UI action telemetry lines.

Options:
  --serial <id>  Target a specific adb device serial.
  --clear        Clear logcat buffer before streaming.
  -h, --help     Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --serial)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --serial requires a value." >&2
        exit 1
      fi
      SERIAL="$2"
      shift 2
      ;;
    --clear)
      CLEAR_LOG=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

ADB=(adb)
if [[ -n "$SERIAL" ]]; then
  ADB+=( -s "$SERIAL" )
fi

if [[ $CLEAR_LOG -eq 1 ]]; then
  "${ADB[@]}" logcat -c
fi

echo "Streaming ONYX UI action telemetry..."
echo "Press Ctrl+C to stop."
echo

# Keep pattern tight: only UI action logs + key ingest logs for cross-checks.
"${ADB[@]}" logcat -v time | grep -E --line-buffered "ONYX_UI_ACTION|ONYX_TELEMETRY|ptt_ingest_accepted|ptt_key_bridge_accepted"
