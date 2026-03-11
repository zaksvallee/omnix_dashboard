#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PROVIDER_ID="${ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER:-fsk_sdk}"
SERIAL=""
APP_PACKAGE="${ONYX_ANDROID_APP_PACKAGE:-com.example.omnix_dashboard}"
APP_ACTIVITY="${ONYX_ANDROID_APP_ACTIVITY:-.MainActivity}"
READY_TIMEOUT_SECONDS=20
ALLOW_BROADCAST_FALLBACK=0
OUT_FILE=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/guard_android_connector_doctor.sh [--provider fsk_sdk|hikvision_sdk] [--serial <device-serial>] [--app-package <package>] [--app-activity <activity>] [--ready-timeout <seconds>] [--allow-broadcast-fallback] [--out <path>]

Purpose:
  Verify ONYX live telemetry starts with a direct SDK connector for the selected provider.
  Fails when reflective startup falls back to broadcast unless --allow-broadcast-fallback is set.
USAGE
}

pass() { printf "PASS: %s\n" "$1"; }
warn() { printf "WARN: %s\n" "$1"; }
fail() { printf "FAIL: %s\n" "$1"; exit 1; }

provider_family() {
  local provider
  provider="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]')"
  if [[ "$provider" == *"hikvision"* ]]; then
    echo "hikvision"
  else
    echo "fsk"
  fi
}

print_local_artifact_hint() {
  local provider_family="$1"
  local libs_dir="$ROOT_DIR/android/app/libs"
  local token_pattern="fsk"
  if [[ "$provider_family" == "hikvision" ]]; then
    token_pattern="hikvision|guardlink"
  fi

  if [[ ! -d "$libs_dir" ]]; then
    warn "Local SDK artifact directory not found: $libs_dir (create it and place provider SDK .aar/.jar files here)."
    return
  fi

  local all_candidates=()
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] && all_candidates+=("$candidate")
  done < <(find "$libs_dir" -maxdepth 1 -type f \( -name "*.aar" -o -name "*.jar" \) | sort)
  if [[ "${#all_candidates[@]}" -eq 0 ]]; then
    warn "No local .aar/.jar artifacts found in $libs_dir"
    return
  fi

  local family_candidates=()
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] && family_candidates+=("$candidate")
  done < <(printf '%s\n' "${all_candidates[@]}" | rg -i "$token_pattern" || true)

  if [[ "${#family_candidates[@]}" -gt 0 ]]; then
    warn "Provider-matching local artifacts found in $libs_dir (verify the intended one is linked):"
    printf '%s\n' "${family_candidates[@]}" | sed 's/^/  - /'
    return
  fi

  warn "Local artifacts exist but none match provider tokens ($token_pattern)."
  printf '%s\n' "${all_candidates[@]}" | sed 's/^/  - /'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider)
      PROVIDER_ID="${2:-}"
      shift 2
      ;;
    --serial)
      SERIAL="${2:-}"
      shift 2
      ;;
    --app-package)
      APP_PACKAGE="${2:-}"
      shift 2
      ;;
    --app-activity)
      APP_ACTIVITY="${2:-}"
      shift 2
      ;;
    --ready-timeout)
      READY_TIMEOUT_SECONDS="${2:-20}"
      shift 2
      ;;
    --allow-broadcast-fallback)
      ALLOW_BROADCAST_FALLBACK=1
      shift
      ;;
    --out)
      OUT_FILE="${2:-}"
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
if ! [[ "$READY_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || [[ "$READY_TIMEOUT_SECONDS" -lt 0 ]]; then
  fail "--ready-timeout must be a non-negative integer."
fi

PROVIDER_FAMILY="$(provider_family "$PROVIDER_ID")"
if [[ -z "$OUT_FILE" ]]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  OUT_FILE="tmp/guard_field_validation/connector-doctor-$stamp.log"
fi
mkdir -p "$(dirname "$OUT_FILE")"

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

startup_pattern="fsk_live_facade_started"
fallback_pattern='fsk_reflective_vendor_connector.*falling back to broadcast|fsk_live_facade_started.*fallback_active=true|fsk_live_facade_started.*connector=broadcast_intent_connector|fsk_vendor_connector_fallback_active[^a-zA-Z0-9]*true|heartbeat_source=broadcast_fallback.*fsk'
if [[ "$PROVIDER_FAMILY" == "hikvision" ]]; then
  startup_pattern="hikvision_live_facade_started"
  fallback_pattern='hikvision_reflective_vendor_connector.*falling back to broadcast|hikvision_live_facade_started.*fallback_active=true|hikvision_live_facade_started.*connector=broadcast_intent_connector|hikvision_vendor_connector_fallback_active[^a-zA-Z0-9]*true|heartbeat_source=broadcast_fallback.*hikvision'
fi

echo "== ONYX Connector Doctor =="
echo "Provider: $PROVIDER_ID"
echo "Device serial: $SERIAL"
echo "App package/activity: $APP_PACKAGE/$APP_ACTIVITY"
echo "Ready timeout (s): $READY_TIMEOUT_SECONDS"
echo "Allow broadcast fallback: $([[ "$ALLOW_BROADCAST_FALLBACK" -eq 1 ]] && echo yes || echo no)"

"${ADB[@]}" shell pm path "$APP_PACKAGE" >/dev/null 2>&1 || \
  fail "App package $APP_PACKAGE is not installed on device $SERIAL."
"${ADB[@]}" logcat -c || true
"${ADB[@]}" shell am force-stop "$APP_PACKAGE" >/dev/null 2>&1 || true
"${ADB[@]}" shell am start -n "$APP_PACKAGE/$APP_ACTIVITY" >/dev/null || \
  fail "Unable to start app activity $APP_PACKAGE/$APP_ACTIVITY."

ready=0
if [[ "$READY_TIMEOUT_SECONDS" -eq 0 ]]; then
  ready=1
else
  for ((t = 0; t < READY_TIMEOUT_SECONDS; t++)); do
    if "${ADB[@]}" logcat -d | grep -q "$startup_pattern"; then
      ready=1
      break
    fi
    sleep 1
  done
fi
if [[ "$ready" -ne 1 ]]; then
  fail "Did not observe startup marker '$startup_pattern' within ${READY_TIMEOUT_SECONDS}s."
fi
pass "Detected startup marker: $startup_pattern"

"${ADB[@]}" logcat -d | grep -i "ONYX_TELEMETRY" > "$OUT_FILE" || true
if [[ ! -s "$OUT_FILE" ]]; then
  fail "No ONYX_TELEMETRY lines captured. See $OUT_FILE"
fi

fallback_count="$(grep -Eic "$fallback_pattern" "$OUT_FILE" || true)"
if [[ "$fallback_count" -gt 0 ]]; then
  first_match="$(grep -Ein "$fallback_pattern" "$OUT_FILE" | head -n 1)"
  reflective_error_pattern='reflective start failed|failed to initialize vendor connector|No vendor manager class found'
  reflective_error_line="$(grep -Ein "$reflective_error_pattern" "$OUT_FILE" | tail -n 1 || true)"
  if [[ "$ALLOW_BROADCAST_FALLBACK" -eq 1 ]]; then
    warn "Connector fallback detected but allowed by flag. First match: $first_match"
    if [[ -n "$reflective_error_line" ]]; then
      warn "Most recent reflective connector error: $reflective_error_line"
    fi
    pass "Connector doctor completed with fallback allowed."
    echo "Telemetry log: $OUT_FILE"
    exit 0
  fi

  if [[ -n "$reflective_error_line" ]]; then
    warn "Most recent reflective connector error: $reflective_error_line"
  fi
  print_local_artifact_hint "$PROVIDER_FAMILY"

  if [[ "$PROVIDER_FAMILY" == "hikvision" ]]; then
    fail "Direct SDK connector missing for $PROVIDER_ID. Vendor SDK classes were not found or fallback activated. First match: $first_match. Ensure Hikvision SDK artifacts are linked (android/app/libs, ONYX_HIKVISION_SDK_ARTIFACT, or ONYX_HIKVISION_SDK_MAVEN_COORD), set ONYX_HIKVISION_SDK_CONNECTOR_CLASS if needed, and provide ONYX_HIKVISION_SDK_MANAGER_CLASS_CANDIDATES when vendor manager class names differ from defaults."
  fi
  fail "Direct SDK connector missing for $PROVIDER_ID. Vendor SDK classes were not found or fallback activated. First match: $first_match. Ensure FSK SDK artifacts are linked (android/app/libs, ONYX_FSK_SDK_ARTIFACT, or ONYX_FSK_SDK_MAVEN_COORD), set ONYX_FSK_SDK_CONNECTOR_CLASS if needed, and provide ONYX_FSK_SDK_MANAGER_CLASS_CANDIDATES when vendor manager class names differ from defaults."
fi

pass "Direct SDK connector is active for $PROVIDER_ID (no fallback traces)."
echo "Telemetry log: $OUT_FILE"
