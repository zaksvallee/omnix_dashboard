#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROVIDER_ID="${ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER:-fsk_sdk}"
SERIAL=""
SDK_ARTIFACT=""
SDK_MAVEN_COORD=""
CONNECTOR_CLASS=""
APP_PACKAGE="${ONYX_ANDROID_APP_PACKAGE:-com.example.omnix_dashboard}"
APP_ACTIVITY="${ONYX_ANDROID_APP_ACTIVITY:-.MainActivity}"
READY_TIMEOUT_SECONDS=20
ALLOW_BROADCAST_FALLBACK=0
SKIP_INSTALL=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/guard_android_vendor_sdk_rollout.sh [--provider fsk_sdk|hikvision_sdk] [--serial <device-serial>] [--sdk-artifact <path-to-aar-or-jar>] [--sdk-maven <group:artifact:version>] [--connector-class <fqcn>] [--app-package <package>] [--app-activity <activity>] [--ready-timeout <seconds>] [--allow-broadcast-fallback] [--skip-install]

Purpose:
  Build/install ONYX Android app for a live telemetry provider with optional vendor SDK dependency overrides,
  then run connector doctor to verify strict direct-SDK readiness.

Examples:
  ./scripts/guard_android_vendor_sdk_rollout.sh \
    --provider fsk_sdk \
    --sdk-artifact android/app/libs/fsk-sdk.aar \
    --connector-class com.onyx.vendor.fsk.LiveSdkConnector

  ./scripts/guard_android_vendor_sdk_rollout.sh \
    --provider hikvision_sdk \
    --sdk-maven com.vendor:hikvision-sdk:4.5.6 \
    --connector-class com.onyx.vendor.hikvision.LiveSdkConnector
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
    --sdk-artifact)
      SDK_ARTIFACT="${2:-}"
      shift 2
      ;;
    --sdk-maven)
      SDK_MAVEN_COORD="${2:-}"
      shift 2
      ;;
    --connector-class)
      CONNECTOR_CLASS="${2:-}"
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
    --skip-install)
      SKIP_INSTALL=1
      shift
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

if ! [[ "$READY_TIMEOUT_SECONDS" =~ ^[0-9]+$ ]] || [[ "$READY_TIMEOUT_SECONDS" -lt 0 ]]; then
  fail "--ready-timeout must be a non-negative integer."
fi
if [[ -n "$SDK_ARTIFACT" && ! -f "$SDK_ARTIFACT" ]]; then
  fail "--sdk-artifact file not found: $SDK_ARTIFACT"
fi
if [[ -n "$SDK_ARTIFACT" && -n "$SDK_MAVEN_COORD" ]]; then
  warn "Both --sdk-artifact and --sdk-maven were supplied. Both will be passed to Gradle."
fi

PROVIDER_FAMILY="$(provider_family "$PROVIDER_ID")"

echo "== ONYX Vendor SDK Rollout =="
echo "Provider: $PROVIDER_ID"
echo "Serial: ${SERIAL:-auto}"
echo "SDK artifact: ${SDK_ARTIFACT:-<unset>}"
echo "SDK Maven coord: ${SDK_MAVEN_COORD:-<unset>}"
echo "Connector class: ${CONNECTOR_CLASS:-<unset>}"
echo "Allow broadcast fallback: $([[ "$ALLOW_BROADCAST_FALLBACK" -eq 1 ]] && echo yes || echo no)"

if [[ "$SKIP_INSTALL" -ne 1 ]]; then
  gradle_cmd=(./gradlew :app:installDebug)
  if [[ "$PROVIDER_FAMILY" == "hikvision" ]]; then
    gradle_cmd+=(
      -PONYX_USE_LIVE_FSK_SDK=false
      -PONYX_USE_LIVE_HIKVISION_SDK=true
    )
    if [[ -n "$SDK_ARTIFACT" ]]; then
      gradle_cmd+=("-PONYX_HIKVISION_SDK_ARTIFACT=$SDK_ARTIFACT")
    fi
    if [[ -n "$SDK_MAVEN_COORD" ]]; then
      gradle_cmd+=("-PONYX_HIKVISION_SDK_MAVEN_COORD=$SDK_MAVEN_COORD")
    fi
    if [[ -n "$CONNECTOR_CLASS" ]]; then
      gradle_cmd+=("-PONYX_HIKVISION_SDK_CONNECTOR_CLASS=$CONNECTOR_CLASS")
    fi
  else
    gradle_cmd+=(
      -PONYX_USE_LIVE_FSK_SDK=true
      -PONYX_USE_LIVE_HIKVISION_SDK=false
    )
    if [[ -n "$SDK_ARTIFACT" ]]; then
      gradle_cmd+=("-PONYX_FSK_SDK_ARTIFACT=$SDK_ARTIFACT")
    fi
    if [[ -n "$SDK_MAVEN_COORD" ]]; then
      gradle_cmd+=("-PONYX_FSK_SDK_MAVEN_COORD=$SDK_MAVEN_COORD")
    fi
    if [[ -n "$CONNECTOR_CLASS" ]]; then
      gradle_cmd+=("-PONYX_FSK_SDK_CONNECTOR_CLASS=$CONNECTOR_CLASS")
    fi
  fi

  echo "Installing debug build with provider-specific live flags..."
  (
    cd "$ROOT_DIR/android"
    "${gradle_cmd[@]}"
  )
  pass "Gradle install completed."
else
  warn "Skipping Gradle install as requested (--skip-install)."
fi

connector_doctor_cmd=(
  ./scripts/guard_android_connector_doctor.sh
  --provider "$PROVIDER_ID"
  --app-package "$APP_PACKAGE"
  --app-activity "$APP_ACTIVITY"
  --ready-timeout "$READY_TIMEOUT_SECONDS"
)
if [[ -n "$SERIAL" ]]; then
  connector_doctor_cmd+=(--serial "$SERIAL")
fi
if [[ "$ALLOW_BROADCAST_FALLBACK" -eq 1 ]]; then
  connector_doctor_cmd+=(--allow-broadcast-fallback)
fi

"${connector_doctor_cmd[@]}"
pass "Vendor SDK rollout check completed."
