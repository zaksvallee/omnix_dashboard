#!/usr/bin/env bash
set -euo pipefail

SERIAL=""
DURATION_SECONDS=20
OUT_DIR=""
PATTERN='zello|ptt|sos|button|onyx_telemetry|kodiak|honeywell|kyocera|runbo|ruggear'

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/guard_android_ptt_sniffer.sh [--serial <device-serial>] [--duration <seconds>] [--out-dir <path>] [--pattern <regex>]

Purpose:
  Capture Android logs while you press PTT/SOS buttons and extract likely broadcast actions,
  delivery outcomes, and policy-abort hints (for example, ordered-broadcast aborts).
USAGE
}

pass() { printf "PASS: %s\n" "$1"; }
fail() { printf "FAIL: %s\n" "$1"; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --serial)
      SERIAL="${2:-}"
      shift 2
      ;;
    --duration)
      DURATION_SECONDS="${2:-20}"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --pattern)
      PATTERN="${2:-$PATTERN}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

if ! command -v adb >/dev/null 2>&1; then
  fail "adb not found. Install android-platform-tools."
fi
if ! [[ "$DURATION_SECONDS" =~ ^[0-9]+$ ]] || [[ "$DURATION_SECONDS" -lt 1 ]]; then
  fail "--duration must be a positive integer."
fi

DEVICES=()
while IFS= read -r device; do
  [[ -n "$device" ]] && DEVICES+=("$device")
done < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
if [[ "${#DEVICES[@]}" -eq 0 ]]; then
  fail "No Android devices connected (status=device)."
fi
if [[ -z "$SERIAL" ]]; then
  SERIAL="${DEVICES[0]}"
fi

ADB=(adb -s "$SERIAL")
if ! "${ADB[@]}" get-state >/dev/null 2>&1; then
  fail "Device serial not available: $SERIAL"
fi

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="tmp/guard_field_validation/ptt-sniffer-$STAMP"
fi
mkdir -p "$OUT_DIR"

echo "== ONYX PTT Sniffer =="
echo "Device serial: $SERIAL"
echo "Duration (s): $DURATION_SECONDS"
echo "Pattern: $PATTERN"
echo "Output dir: $OUT_DIR"

"${ADB[@]}" logcat -c || true

echo ""
echo "Press and hold/release the device PTT/SOS/talk buttons now..."
echo "Capturing for ${DURATION_SECONDS}s."
sleep "$DURATION_SECONDS"

"${ADB[@]}" logcat -d > "$OUT_DIR/logcat_full.txt" || true
grep -Ein "$PATTERN" "$OUT_DIR/logcat_full.txt" > "$OUT_DIR/logcat_matches.txt" || true

"${ADB[@]}" shell dumpsys activity broadcasts > "$OUT_DIR/broadcasts_dump.txt" || true
grep -Ein "$PATTERN|resultAbort|skipped by policy|BroadcastRecord\\{|ReceiverList\\{|Action: \"" \
  "$OUT_DIR/broadcasts_dump.txt" > "$OUT_DIR/broadcasts_matches.txt" || true

# Pull short context windows for recent candidate broadcasts.
awk '
  BEGIN { IGNORECASE = 1; keep = 0 }
  /BroadcastRecord\{.*(zello|ptt|button|sos)/ { print; keep = 10; next }
  keep > 0 { print; keep--; next }
' "$OUT_DIR/broadcasts_dump.txt" > "$OUT_DIR/recent_candidate_broadcasts.txt" || true

log_matches="$(wc -l < "$OUT_DIR/logcat_matches.txt" | tr -d ' ')"
broadcast_matches="$(wc -l < "$OUT_DIR/broadcasts_matches.txt" | tr -d ' ')"
candidate_blocks="$(grep -c "BroadcastRecord{" "$OUT_DIR/recent_candidate_broadcasts.txt" || true)"

echo ""
echo "Summary:"
echo "  logcat matches: $log_matches"
echo "  broadcast dump matches: $broadcast_matches"
echo "  candidate broadcast blocks: $candidate_blocks"
echo "Artifacts:"
echo "  $OUT_DIR/logcat_matches.txt"
echo "  $OUT_DIR/broadcasts_matches.txt"
echo "  $OUT_DIR/recent_candidate_broadcasts.txt"

if [[ "$candidate_blocks" -gt 0 ]]; then
  pass "Candidate broadcast actions captured."
else
  pass "No candidate broadcast actions matched; broaden pattern with --pattern if needed."
fi
