#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROVIDER_ID="${ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER:-fsk_sdk}"
SERIAL=""
SDK_ARTIFACT=""
SDK_MAVEN_COORD=""
CONNECTOR_CLASS=""
MANAGER_CLASSES=""
APP_PACKAGE="${ONYX_ANDROID_APP_PACKAGE:-com.example.omnix_dashboard}"
APP_ACTIVITY="${ONYX_ANDROID_APP_ACTIVITY:-.MainActivity}"
READY_TIMEOUT_SECONDS=20
ALLOW_BROADCAST_FALLBACK=0
SKIP_INSTALL=0
AUTO_MANAGER_CLASSES=1

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/guard_android_vendor_sdk_rollout.sh [--provider fsk_sdk|hikvision_sdk] [--serial <device-serial>] [--sdk-artifact <path-to-aar-or-jar>] [--sdk-maven <group:artifact:version>] [--connector-class <fqcn>] [--manager-classes <csv>] [--auto-manager-classes|--no-auto-manager-classes] [--app-package <package>] [--app-activity <activity>] [--ready-timeout <seconds>] [--allow-broadcast-fallback] [--skip-install]

Purpose:
  Build/install ONYX Android app for a live telemetry provider with optional vendor SDK dependency overrides,
  then run connector doctor to verify strict direct-SDK readiness.
  If --sdk-artifact and --sdk-maven are omitted, the script tries to auto-detect a provider-matching
  .aar/.jar from android/app/libs.

Examples:
  ./scripts/guard_android_vendor_sdk_rollout.sh \
    --provider fsk_sdk \
    --sdk-artifact android/app/libs/fsk-sdk.aar \
    --connector-class com.onyx.vendor.fsk.LiveSdkConnector \
    --manager-classes com.onyx.vendor.fsk.LiveSdkManager

  ./scripts/guard_android_vendor_sdk_rollout.sh \
    --provider hikvision_sdk \
    --sdk-maven com.vendor:hikvision-sdk:4.5.6 \
    --connector-class com.onyx.vendor.hikvision.LiveSdkConnector \
    --manager-classes com.vendor.hikvision.TelemetryManager

  ./scripts/guard_android_vendor_sdk_rollout.sh \
    --provider fsk_sdk \
    --sdk-artifact android/app/libs/fsk-sdk.aar \
    --connector-class com.onyx.vendor.fsk.LiveSdkConnector \
    --auto-manager-classes
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

auto_detect_local_artifact() {
  local provider_family="$1"
  local libs_dir="$ROOT_DIR/android/app/libs"
  if [[ ! -d "$libs_dir" ]]; then
    return 1
  fi

  local all_candidates=()
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] && all_candidates+=("$candidate")
  done < <(find "$libs_dir" -maxdepth 1 -type f \( -name "*.aar" -o -name "*.jar" \) | sort)
  if [[ "${#all_candidates[@]}" -eq 0 ]]; then
    return 1
  fi

  local token_pattern="fsk"
  if [[ "$provider_family" == "hikvision" ]]; then
    token_pattern="hikvision|guardlink"
  fi

  local family_candidates=()
  while IFS= read -r candidate; do
    [[ -n "$candidate" ]] && family_candidates+=("$candidate")
  done < <(printf '%s\n' "${all_candidates[@]}" | rg -i "$token_pattern" || true)

  if [[ "${#family_candidates[@]}" -eq 1 ]]; then
    printf '%s\n' "${family_candidates[0]}"
    return 0
  fi
  if [[ "${#family_candidates[@]}" -gt 1 ]]; then
    warn "Multiple provider-matching artifacts found in android/app/libs; specify --sdk-artifact explicitly."
    printf '%s\n' "${family_candidates[@]}" | sed 's/^/  - /'
    return 1
  fi

  if [[ "${#all_candidates[@]}" -eq 1 ]]; then
    printf '%s\n' "${all_candidates[0]}"
    return 0
  fi

  warn "Multiple artifacts found in android/app/libs; specify --sdk-artifact explicitly."
  printf '%s\n' "${all_candidates[@]}" | sed 's/^/  - /'
  return 1
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
    --manager-classes)
      MANAGER_CLASSES="${2:-}"
      shift 2
      ;;
    --auto-manager-classes)
      AUTO_MANAGER_CLASSES=1
      shift
      ;;
    --no-auto-manager-classes)
      AUTO_MANAGER_CLASSES=0
      shift
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

if [[ -z "$SDK_ARTIFACT" && -z "$SDK_MAVEN_COORD" ]]; then
  detected_artifact="$(auto_detect_local_artifact "$PROVIDER_FAMILY" || true)"
  if [[ -n "$detected_artifact" ]]; then
    SDK_ARTIFACT="$detected_artifact"
    pass "Auto-detected SDK artifact: $SDK_ARTIFACT"
  fi
fi

if [[ -z "$MANAGER_CLASSES" && "$AUTO_MANAGER_CLASSES" -eq 1 && -n "$SDK_ARTIFACT" ]]; then
  if [[ -x "$ROOT_DIR/scripts/guard_android_vendor_sdk_inspect.sh" ]]; then
    inspect_output="$(
      "$ROOT_DIR/scripts/guard_android_vendor_sdk_inspect.sh" \
        --artifact "$SDK_ARTIFACT" \
        --provider "$PROVIDER_ID" \
        --max-results 12 2>/dev/null || true
    )"
    auto_manager_csv="$(printf '%s\n' "$inspect_output" | awk -F'Suggested CSV: ' '/Suggested CSV:/ {print $2; exit}')"
    if [[ -n "$auto_manager_csv" ]]; then
      MANAGER_CLASSES="$auto_manager_csv"
      pass "Auto-discovered manager classes from artifact: $MANAGER_CLASSES"
    else
      warn "Unable to auto-discover manager classes from artifact; provide --manager-classes explicitly."
    fi
  else
    warn "Artifact inspector script is unavailable; cannot auto-discover manager classes."
  fi
fi

echo "== ONYX Vendor SDK Rollout =="
echo "Provider: $PROVIDER_ID"
echo "Serial: ${SERIAL:-auto}"
echo "SDK artifact: ${SDK_ARTIFACT:-<unset>}"
echo "SDK Maven coord: ${SDK_MAVEN_COORD:-<unset>}"
echo "Connector class: ${CONNECTOR_CLASS:-<unset>}"
echo "Manager classes: ${MANAGER_CLASSES:-<unset>}"
echo "Auto manager classes: $([[ "$AUTO_MANAGER_CLASSES" -eq 1 ]] && echo yes || echo no)"
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
    if [[ -n "$MANAGER_CLASSES" ]]; then
      gradle_cmd+=("-PONYX_HIKVISION_SDK_MANAGER_CLASS_CANDIDATES=$MANAGER_CLASSES")
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
    if [[ -n "$MANAGER_CLASSES" ]]; then
      gradle_cmd+=("-PONYX_FSK_SDK_MANAGER_CLASS_CANDIDATES=$MANAGER_CLASSES")
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
