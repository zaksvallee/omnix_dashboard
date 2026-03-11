#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SERIAL=""
DURATION_SECONDS=20
APP_PACKAGE="${ONYX_ANDROID_APP_PACKAGE:-com.example.omnix_dashboard}"
BUNDLE_DIR=""
ALLOW_UNLOCKED_ONLY=false
MIN_UNLOCKED_INGEST=10
MIN_LOCKED_CONFIRMED=1

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/guard_android_ptt_lockscreen_gate.sh \
    [--serial <device-serial>] \
    [--duration <seconds>] \
    [--app-package <package>] \
    [--bundle-dir <path>] \
    [--min-unlocked-ingest <count>] \
    [--min-locked-confirmed <count>] \
    [--allow-unlocked-only]

Purpose:
  Determine whether lockscreen PTT ingest is truly supported.

Behavior:
  - If --bundle-dir is omitted, creates a new OEM escalation bundle by calling:
      ./scripts/guard_android_oem_escalation_bundle.sh
  - Parses unlocked/locked evidence and writes a gate report.

Decision:
  - LOCKED_OK: confirmed locked-state ingest lines observed.
  - UNLOCKED_ONLY: no confirmed locked-state ingest; operate in unlocked/kiosk mode.
USAGE
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

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
    --app-package)
      APP_PACKAGE="${2:-$APP_PACKAGE}"
      shift 2
      ;;
    --bundle-dir)
      BUNDLE_DIR="${2:-}"
      shift 2
      ;;
    --min-unlocked-ingest)
      MIN_UNLOCKED_INGEST="${2:-10}"
      shift 2
      ;;
    --min-locked-confirmed)
      MIN_LOCKED_CONFIRMED="${2:-1}"
      shift 2
      ;;
    --allow-unlocked-only)
      ALLOW_UNLOCKED_ONLY=true
      shift 1
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

if ! [[ "$DURATION_SECONDS" =~ ^[0-9]+$ ]] || [[ "$DURATION_SECONDS" -lt 5 ]]; then
  fail "--duration must be an integer >= 5."
fi
if ! [[ "$MIN_UNLOCKED_INGEST" =~ ^[0-9]+$ ]]; then
  fail "--min-unlocked-ingest must be an integer >= 0."
fi
if ! [[ "$MIN_LOCKED_CONFIRMED" =~ ^[0-9]+$ ]]; then
  fail "--min-locked-confirmed must be an integer >= 0."
fi

if [[ -z "$BUNDLE_DIR" ]]; then
  STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
  BUNDLE_DIR="tmp/guard_field_validation/oem-escalation-$STAMP"
  cmd=("$ROOT_DIR/scripts/guard_android_oem_escalation_bundle.sh" "--duration" "$DURATION_SECONDS" "--out-dir" "$BUNDLE_DIR" "--app-package" "$APP_PACKAGE")
  if [[ -n "$SERIAL" ]]; then
    cmd+=("--serial" "$SERIAL")
  fi
  "${cmd[@]}"
fi

UNLOCKED_LOG="$BUNDLE_DIR/unlocked/logcat_ptt_matches.txt"
LOCKED_LOG="$BUNDLE_DIR/locked/logcat_ptt_matches.txt"
UNLOCKED_KEYS="$BUNDLE_DIR/unlocked/getevent_key_matches.txt"
LOCKED_KEYS="$BUNDLE_DIR/locked/getevent_key_matches.txt"

[[ -f "$UNLOCKED_LOG" ]] || fail "Missing file: $UNLOCKED_LOG"
[[ -f "$LOCKED_LOG" ]] || fail "Missing file: $LOCKED_LOG"
[[ -f "$UNLOCKED_KEYS" ]] || fail "Missing file: $UNLOCKED_KEYS"
[[ -f "$LOCKED_KEYS" ]] || fail "Missing file: $LOCKED_KEYS"

count_or_zero() {
  local pattern="$1"
  local file="$2"
  grep -Ec "$pattern" "$file" || true
}

unlocked_ingest="$(count_or_zero 'ptt_ingest_accepted' "$UNLOCKED_LOG")"
locked_ingest="$(count_or_zero 'ptt_ingest_accepted' "$LOCKED_LOG")"
locked_true="$(count_or_zero 'ptt_ingest_accepted.*locked=true' "$LOCKED_LOG")"
locked_false="$(count_or_zero 'ptt_ingest_accepted.*locked=false' "$LOCKED_LOG")"
locked_interactive_false="$(count_or_zero 'ptt_ingest_accepted.*interactive=false' "$LOCKED_LOG")"
unlocked_key_lines="$(wc -l < "$UNLOCKED_KEYS" | tr -d ' ')"
locked_key_lines="$(wc -l < "$LOCKED_KEYS" | tr -d ' ')"

decision="UNLOCKED_ONLY"
reason="No confirmed lockscreen ingest evidence."

if (( unlocked_ingest < MIN_UNLOCKED_INGEST )); then
  decision="INSUFFICIENT_BASELINE"
  reason="Unlocked ingest below threshold (${unlocked_ingest} < ${MIN_UNLOCKED_INGEST})."
elif (( locked_true >= MIN_LOCKED_CONFIRMED )) || (( locked_interactive_false >= MIN_LOCKED_CONFIRMED )); then
  decision="LOCKED_OK"
  reason="Confirmed lockscreen ingest evidence observed."
fi

REPORT_FILE="$BUNDLE_DIR/lockscreen_gate_report.md"
cat > "$REPORT_FILE" <<REPORT
# ONYX PTT Lockscreen Gate

- Captured at (UTC): \
\`$(date -u +%Y-%m-%dT%H:%M:%SZ)\`
- Bundle directory: \
\`$BUNDLE_DIR\`
- Decision: \
\`$decision\`
- Reason: $reason

## Metrics

- Unlocked ingest accepted: \
\`$unlocked_ingest\`
- Locked ingest accepted: \
\`$locked_ingest\`
- Locked ingest with \
\`locked=true\`: \
\`$locked_true\`
- Locked ingest with \
\`locked=false\`: \
\`$locked_false\`
- Locked ingest with \
\`interactive=false\`: \
\`$locked_interactive_false\`
- Unlocked key-event lines: \
\`$unlocked_key_lines\`
- Locked key-event lines: \
\`$locked_key_lines\`

## Operational Recommendation

REPORT

if [[ "$decision" == "LOCKED_OK" ]]; then
  cat >> "$REPORT_FILE" <<'REPORT'
- Lockscreen PTT appears viable on this firmware/device sample.
- Continue to monitor with periodic OEM bundle captures after firmware updates.
REPORT
elif [[ "$decision" == "INSUFFICIENT_BASELINE" ]]; then
  cat >> "$REPORT_FILE" <<'REPORT'
- Repeat capture and ensure side-key is pressed repeatedly during unlocked phase.
- Do not use this bundle as lockscreen support evidence.
REPORT
else
  cat >> "$REPORT_FILE" <<'REPORT'
- Use unlocked/kiosk operational mode for dependable PTT.
- Treat lockscreen side-key ingest as unsupported pending OEM firmware/system routing support.
REPORT
fi

printf '== ONYX PTT Lockscreen Gate ==\n'
printf 'Bundle: %s\n' "$BUNDLE_DIR"
printf 'Decision: %s\n' "$decision"
printf 'Reason: %s\n' "$reason"
printf 'Report: %s\n' "$REPORT_FILE"

if [[ "$decision" == "LOCKED_OK" ]]; then
  exit 0
fi
if [[ "$decision" == "UNLOCKED_ONLY" && "$ALLOW_UNLOCKED_ONLY" == true ]]; then
  exit 0
fi
exit 2
