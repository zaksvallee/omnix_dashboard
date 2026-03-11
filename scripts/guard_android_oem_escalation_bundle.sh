#!/usr/bin/env bash
set -euo pipefail

SERIAL=""
DURATION_SECONDS=15
OUT_DIR=""
APP_PACKAGE="${ONYX_ANDROID_APP_PACKAGE:-com.example.omnix_dashboard}"
ACCESSIBILITY_SERVICE_CLASS_SUFFIX=".telemetry.OnyxPttAccessibilityService"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/guard_android_oem_escalation_bundle.sh \
    [--serial <device-serial>] \
    [--duration <seconds>] \
    [--out-dir <path>] \
    [--app-package <package>]

Purpose:
  Build an OEM-support evidence bundle for lockscreen side-key issues.
  Captures unlocked and locked key-press sessions with logcat + getevent,
  plus settings/dumpsys snapshots for escalation.
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
      DURATION_SECONDS="${2:-15}"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --app-package)
      APP_PACKAGE="${2:-$APP_PACKAGE}"
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
if ! [[ "$DURATION_SECONDS" =~ ^[0-9]+$ ]] || [[ "$DURATION_SECONDS" -lt 5 ]]; then
  fail "--duration must be an integer >= 5."
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
  OUT_DIR="tmp/guard_field_validation/oem-escalation-$STAMP"
fi
mkdir -p "$OUT_DIR"

echo "== ONYX OEM Escalation Bundle =="
echo "Device: $SERIAL"
echo "Duration per phase: ${DURATION_SECONDS}s"
echo "Output: $OUT_DIR"
echo ""

EXPECTED_ACCESSIBILITY_SERVICE="$APP_PACKAGE/${APP_PACKAGE}${ACCESSIBILITY_SERVICE_CLASS_SUFFIX}"
ACCESSIBILITY_ENABLED="$("${ADB[@]}" shell settings get secure accessibility_enabled | tr -d '\r')"
ENABLED_ACCESSIBILITY_SERVICES="$("${ADB[@]}" shell settings get secure enabled_accessibility_services | tr -d '\r')"

if [[ "$ACCESSIBILITY_ENABLED" != "1" ]]; then
  fail "Accessibility is disabled (accessibility_enabled=$ACCESSIBILITY_ENABLED). Enable ONYX PTT Key Bridge before capture."
fi
if ! printf '%s' "$ENABLED_ACCESSIBILITY_SERVICES" | grep -Fq "$EXPECTED_ACCESSIBILITY_SERVICE"; then
  fail "Expected accessibility service not enabled: $EXPECTED_ACCESSIBILITY_SERVICE"
fi

echo "Accessibility preflight: PASS"
echo "  enabled_accessibility_services=$ENABLED_ACCESSIBILITY_SERVICES"
echo "  accessibility_enabled=$ACCESSIBILITY_ENABLED"
echo ""

capture_phase() {
  local phase="$1"
  local phase_dir="$OUT_DIR/$phase"
  local log_file="$phase_dir/logcat_full.txt"
  local key_file="$phase_dir/getevent.txt"
  mkdir -p "$phase_dir"

  "${ADB[@]}" logcat -c || true
  "${ADB[@]}" logcat -v time > "$log_file" &
  local log_pid=$!

  "${ADB[@]}" shell getevent -lt > "$key_file" &
  local key_pid=$!

  echo "Phase '$phase' running for ${DURATION_SECONDS}s..."
  sleep "$DURATION_SECONDS"

  kill "$log_pid" >/dev/null 2>&1 || true
  kill "$key_pid" >/dev/null 2>&1 || true
  wait "$log_pid" 2>/dev/null || true
  wait "$key_pid" 2>/dev/null || true

  grep -Ei "ONYX_TELEMETRY|ptt_ingest|ptt_key_bridge|zello|buttonExtra1|buttonSOS" \
    "$log_file" > "$phase_dir/logcat_ptt_matches.txt" || true
  grep -Ei "KEY_F1|EV_KEY|SYN_REPORT" "$key_file" > "$phase_dir/getevent_key_matches.txt" || true
}

echo "Collecting static device context..."
"${ADB[@]}" shell getprop ro.product.model > "$OUT_DIR/device_model.txt" || true
"${ADB[@]}" shell getprop ro.build.fingerprint > "$OUT_DIR/build_fingerprint.txt" || true
"${ADB[@]}" shell getprop ro.build.version.release > "$OUT_DIR/android_version.txt" || true
"${ADB[@]}" shell dumpsys package "$APP_PACKAGE" > "$OUT_DIR/dumpsys_package_onyx.txt" || true
"${ADB[@]}" shell dumpsys accessibility > "$OUT_DIR/dumpsys_accessibility.txt" || true
"${ADB[@]}" shell dumpsys power > "$OUT_DIR/dumpsys_power.txt" || true
"${ADB[@]}" shell settings list system > "$OUT_DIR/settings_system.txt" || true
"${ADB[@]}" shell settings list secure > "$OUT_DIR/settings_secure.txt" || true
"${ADB[@]}" shell settings list global > "$OUT_DIR/settings_global.txt" || true
printf '%s\n' "$EXPECTED_ACCESSIBILITY_SERVICE" > "$OUT_DIR/accessibility_expected_service.txt"
printf '%s\n' "$ENABLED_ACCESSIBILITY_SERVICES" > "$OUT_DIR/accessibility_enabled_services.txt"
printf '%s\n' "$ACCESSIBILITY_ENABLED" > "$OUT_DIR/accessibility_enabled_flag.txt"

grep -Ei "smart_key|key_bv_left_screen|side_button|lock|ptt|zello|button|accessibility" \
  "$OUT_DIR/settings_system.txt" > "$OUT_DIR/settings_system_focus.txt" || true
grep -Ei "smart_key|key_bv_left_screen|side_button|lock|ptt|zello|button|accessibility" \
  "$OUT_DIR/settings_secure.txt" > "$OUT_DIR/settings_secure_focus.txt" || true
grep -Ei "smart_key|key_bv_left_screen|side_button|lock|ptt|zello|button|accessibility" \
  "$OUT_DIR/settings_global.txt" > "$OUT_DIR/settings_global_focus.txt" || true

echo ""
echo "UNLOCKED phase:"
echo "Keep screen unlocked. Press/release side key repeatedly."
capture_phase "unlocked"

echo ""
echo "LOCKED phase:"
echo "Lock the screen now, then keep pressing/releasing side key."
capture_phase "locked"

unlocked_ptt_lines="$(wc -l < "$OUT_DIR/unlocked/logcat_ptt_matches.txt" | tr -d ' ')"
locked_ptt_lines="$(wc -l < "$OUT_DIR/locked/logcat_ptt_matches.txt" | tr -d ' ')"
unlocked_key_lines="$(wc -l < "$OUT_DIR/unlocked/getevent_key_matches.txt" | tr -d ' ')"
locked_key_lines="$(wc -l < "$OUT_DIR/locked/getevent_key_matches.txt" | tr -d ' ')"
unlocked_ingest_lines="$(grep -c "ptt_ingest_accepted" "$OUT_DIR/unlocked/logcat_ptt_matches.txt" || true)"
locked_ingest_lines="$(grep -c "ptt_ingest_accepted" "$OUT_DIR/locked/logcat_ptt_matches.txt" || true)"
unlocked_ingest_locked_true="$(grep -c "ptt_ingest_accepted.*locked=true" "$OUT_DIR/unlocked/logcat_ptt_matches.txt" || true)"
unlocked_ingest_locked_false="$(grep -c "ptt_ingest_accepted.*locked=false" "$OUT_DIR/unlocked/logcat_ptt_matches.txt" || true)"
locked_ingest_locked_true="$(grep -c "ptt_ingest_accepted.*locked=true" "$OUT_DIR/locked/logcat_ptt_matches.txt" || true)"
locked_ingest_locked_false="$(grep -c "ptt_ingest_accepted.*locked=false" "$OUT_DIR/locked/logcat_ptt_matches.txt" || true)"

cat > "$OUT_DIR/summary.md" <<SUMMARY
# ONYX OEM Escalation Capture

- Device serial: \`$SERIAL\`
- Captured at (UTC): \`$(date -u +%Y-%m-%dT%H:%M:%SZ)\`
- App package: \`$APP_PACKAGE\`
- Phase duration (s): \`$DURATION_SECONDS\`

## Evidence Counts

- Unlocked phase logcat PTT lines: \`$unlocked_ptt_lines\`
- Locked phase logcat PTT lines: \`$locked_ptt_lines\`
- Unlocked phase key-event lines: \`$unlocked_key_lines\`
- Locked phase key-event lines: \`$locked_key_lines\`

## Accessibility Preflight

- Expected ONYX service: \`$EXPECTED_ACCESSIBILITY_SERVICE\`
- Enabled services snapshot: \`$ENABLED_ACCESSIBILITY_SERVICES\`
- accessibility_enabled: \`$ACCESSIBILITY_ENABLED\`

## App-Layer Ingest Breakdown

- Unlocked phase ingest accepted lines: \`$unlocked_ingest_lines\`
- Locked phase ingest accepted lines: \`$locked_ingest_lines\`
- Unlocked ingest lock-state: \`locked=true:$unlocked_ingest_locked_true\` / \`locked=false:$unlocked_ingest_locked_false\`
- Locked ingest lock-state: \`locked=true:$locked_ingest_locked_true\` / \`locked=false:$locked_ingest_locked_false\`

## Key Files

- \`$OUT_DIR/unlocked/logcat_ptt_matches.txt\`
- \`$OUT_DIR/locked/logcat_ptt_matches.txt\`
- \`$OUT_DIR/unlocked/getevent_key_matches.txt\`
- \`$OUT_DIR/locked/getevent_key_matches.txt\`
- \`$OUT_DIR/settings_system_focus.txt\`
- \`$OUT_DIR/settings_secure_focus.txt\`
- \`$OUT_DIR/settings_global_focus.txt\`
SUMMARY

echo ""
pass "OEM escalation bundle created at $OUT_DIR"
echo "Review:"
echo "  $OUT_DIR/summary.md"
