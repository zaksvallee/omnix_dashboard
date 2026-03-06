#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/guard_android_connection_doctor.sh

Purpose:
  Diagnose why ONYX Android field validation cannot see a device over adb.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

pass() { printf "PASS: %s\n" "$1"; }
warn() { printf "WARN: %s\n" "$1"; }
fail() { printf "FAIL: %s\n" "$1"; exit 1; }

if ! command -v adb >/dev/null 2>&1; then
  fail "adb not found. Install android-platform-tools (brew install android-platform-tools)."
fi
pass "adb found: $(command -v adb)"

if command -v rg >/dev/null 2>&1; then
  USB_MATCH="$(system_profiler SPUSBDataType 2>/dev/null | rg -i 'blackview|android|mtp|adb|pixel|samsung' || true)"
else
  USB_MATCH="$(system_profiler SPUSBDataType 2>/dev/null | grep -Ei 'blackview|android|mtp|adb|pixel|samsung' || true)"
fi

if [[ -n "$USB_MATCH" ]]; then
  pass "macOS USB profiler sees potential Android/MTP device."
else
  warn "macOS USB profiler did not detect an Android/MTP signature."
  warn "Check cable quality, USB mode (File transfer), and trust prompts."
fi

adb kill-server >/dev/null 2>&1 || true
adb start-server >/dev/null 2>&1 || true
ADB_DEVICES="$(adb devices -l)"
printf "%s\n" "$ADB_DEVICES"

DEVICE_COUNT="$(printf "%s\n" "$ADB_DEVICES" | awk 'NR>1 && $2=="device" {count++} END {print count+0}')"
UNAUTHORIZED_COUNT="$(printf "%s\n" "$ADB_DEVICES" | awk 'NR>1 && $2=="unauthorized" {count++} END {print count+0}')"
OFFLINE_COUNT="$(printf "%s\n" "$ADB_DEVICES" | awk 'NR>1 && $2=="offline" {count++} END {print count+0}')"

if [[ "$DEVICE_COUNT" -gt 0 ]]; then
  pass "adb reports $DEVICE_COUNT connected device(s). Ready for guard_android_pilot_gate.sh."
  exit 0
fi

if [[ "$UNAUTHORIZED_COUNT" -gt 0 ]]; then
  fail "adb device is unauthorized. Unlock phone and accept RSA prompt."
fi

if [[ "$OFFLINE_COUNT" -gt 0 ]]; then
  fail "adb device is offline. Reconnect cable and toggle USB debugging."
fi

fail "No adb devices in 'device' state. Enable Developer Options + USB debugging and set USB mode to File transfer."
