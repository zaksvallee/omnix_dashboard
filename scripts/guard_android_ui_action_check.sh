#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SERIAL=""
DURATION=30
OUT_DIR="tmp/ui_action_check"

usage() {
  cat <<USAGE
Usage: ./scripts/guard_android_ui_action_check.sh [--serial <device-serial>] [--duration <seconds>] [--out-dir <path>]

Captures ONYX_UI_ACTION logcat output for a fixed duration and reports missing critical actions.

Options:
  --serial <id>       Target adb device serial.
  --duration <sec>    Capture duration in seconds (default: 30).
  --out-dir <path>    Output directory (default: tmp/ui_action_check).
  -h, --help          Show this help.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --serial)
      [[ $# -ge 2 ]] || { echo "ERROR: --serial requires value" >&2; exit 1; }
      SERIAL="$2"
      shift 2
      ;;
    --duration)
      [[ $# -ge 2 ]] || { echo "ERROR: --duration requires value" >&2; exit 1; }
      DURATION="$2"
      shift 2
      ;;
    --out-dir)
      [[ $# -ge 2 ]] || { echo "ERROR: --out-dir requires value" >&2; exit 1; }
      OUT_DIR="$2"
      shift 2
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

if ! [[ "$DURATION" =~ ^[0-9]+$ ]] || [[ "$DURATION" -lt 5 ]]; then
  echo "ERROR: --duration must be an integer >= 5" >&2
  exit 1
fi

ADB=(adb)
if [[ -n "$SERIAL" ]]; then
  ADB+=( -s "$SERIAL" )
fi

mkdir -p "$OUT_DIR"
TS="$(date -u +%Y%m%dT%H%M%SZ)"
LOG_FILE="$OUT_DIR/ui_action_logcat_$TS.txt"
REPORT_FILE="$OUT_DIR/ui_action_report_$TS.txt"

REQUIRED_ACTIONS=(
  "sites.add_site"
  "sites.view_on_map"
  "sites.open_settings"
  "sites.open_guard_roster"
  "events.view_in_ledger"
  "events.export_event_data"
  "ledger.verify_chain"
  "ledger.export_all"
  "ledger.export_entry"
  "ledger.view_in_event_review"
  "clients.retry_push_sync"
  "clients.open_room"
  "reports.export_all"
  "reports.preview_sample_receipt"
  "reports.download_sample_receipt"
  "live_operations.pause_automation"
  "live_operations.manual_override"
  "client_app.open_first_incident"
)

OPTIONAL_ALTERNATIVES=(
  "reports.preview_live_receipt"
  "reports.download_live_receipt"
  "client_app.open_first_incident_missing"
)

echo "== ONYX UI Action Check =="
echo "Device: ${SERIAL:-default}"
echo "Duration: ${DURATION}s"
echo "Log: $LOG_FILE"
echo

echo "Clearing logcat buffer..."
"${ADB[@]}" logcat -c || true

echo "Capture running. Trigger the app buttons now..."
"${ADB[@]}" logcat -v time | grep -E --line-buffered "ONYX_UI_ACTION" > "$LOG_FILE" &
CAPTURE_PID=$!

sleep "$DURATION"

kill "$CAPTURE_PID" >/dev/null 2>&1 || true
wait "$CAPTURE_PID" 2>/dev/null || true

echo "\n== Action Coverage Report ==" | tee "$REPORT_FILE"
TOTAL_LINES=$(wc -l < "$LOG_FILE" | tr -d ' ')
echo "Captured ONYX_UI_ACTION lines: $TOTAL_LINES" | tee -a "$REPORT_FILE"

MISSING=0
for action in "${REQUIRED_ACTIONS[@]}"; do
  if grep -Fq "\"action\":\"$action\"" "$LOG_FILE"; then
    echo "PASS  $action" | tee -a "$REPORT_FILE"
  else
    echo "MISS  $action" | tee -a "$REPORT_FILE"
    MISSING=$((MISSING + 1))
  fi
done

for action in "${OPTIONAL_ALTERNATIVES[@]}"; do
  if grep -Fq "\"action\":\"$action\"" "$LOG_FILE"; then
    echo "INFO  optional-seen $action" | tee -a "$REPORT_FILE"
  fi
done

echo "" | tee -a "$REPORT_FILE"
if [[ "$MISSING" -eq 0 ]]; then
  echo "PASS: All required UI actions were observed." | tee -a "$REPORT_FILE"
  exit 0
fi

echo "FAIL: Missing $MISSING required UI action(s)." | tee -a "$REPORT_FILE"
echo "Review report: $REPORT_FILE"
exit 1
