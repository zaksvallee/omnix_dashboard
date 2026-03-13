#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

EDGE_URL="${EDGE_BASE_URL:-http://localhost:5000}"
PROVIDER="${ONYX_CCTV_PROVIDER:-frigate}"
EVENT_ID=""
SITE_ID=""
CAMERA_ID=""
ZONE=""
CAPTURE_DIR="tmp/cctv_capture"
ARTIFACT_DIR=""
MAX_REPORT_AGE_HOURS="${ONYX_CCTV_MAX_VALIDATION_REPORT_AGE_HOURS:-24}"
INIT_CAPTURE_PACK=0
SKIP_EDGE=0
ALLOW_MOCK_ARTIFACTS=0
USE_MOCK_ARTIFACTS=0
GENERATE_SIGNOFF=0
SIGNOFF_OUT=""
CANONICAL_SIGNOFF_OUT=""
EXPORT_SIGNOFF_OUT=""
COMPARE_PREVIOUS_RELEASE=0
PREVIOUS_RELEASE_GATE_JSON=""
ALLOW_RELEASE_HOLD_REASON_INCREASE_COUNT=0
ALLOW_RELEASE_FAIL_REASON_INCREASE_COUNT=0
REQUIRE_RELEASE_GATE_PASS=0
REQUIRE_RELEASE_TREND_PASS=0

json_get() {
  local report_file="$1"
  local expression="$2"
  python3 - "$report_file" "$expression" <<'PY'
import json, sys
path = sys.argv[1]
expr = sys.argv[2].split(".")
with open(path, "r", encoding="utf-8") as handle:
    value = json.load(handle)
for key in expr:
    if not isinstance(value, dict):
        value = ""
        break
    value = value.get(key, "")
if isinstance(value, bool):
    print("true" if value else "false")
elif value is None:
    print("")
else:
    print(value)
PY
}

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_cctv_field_gate.sh [--edge-url <url>] [--provider <id>] [--site-id <site_id>] [--event-id <event_id>] [--camera-id <camera_id>] [--zone <zone>] [--capture-dir <path>] [--artifact-dir <path>] [--max-report-age-hours <hours>] [--init-capture-pack] [--skip-edge] [--allow-mock-artifacts] [--use-mock-artifacts] [--generate-signoff] [--signoff-out <path>] [--compare-previous-release] [--previous-release-gate-json <path>] [--allow-release-hold-reason-increase-count <count>] [--allow-release-fail-reason-increase-count <count>] [--require-release-gate-pass] [--require-release-trend-pass]

Purpose:
  One-command CCTV field gate:
  1) optionally initialize the capture pack
  2) run live CCTV validation or generate mock validation artifacts
  3) emit CCTV release-gate and release-trend artifacts
  4) optionally generate CCTV signoff aligned to the final release posture
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --edge-url) EDGE_URL="${2:-}"; shift 2 ;;
    --provider) PROVIDER="${2:-}"; shift 2 ;;
    --site-id) SITE_ID="${2:-}"; shift 2 ;;
    --event-id) EVENT_ID="${2:-}"; shift 2 ;;
    --camera-id) CAMERA_ID="${2:-}"; shift 2 ;;
    --zone) ZONE="${2:-}"; shift 2 ;;
    --capture-dir) CAPTURE_DIR="${2:-}"; shift 2 ;;
    --artifact-dir) ARTIFACT_DIR="${2:-}"; shift 2 ;;
    --max-report-age-hours) MAX_REPORT_AGE_HOURS="${2:-24}"; shift 2 ;;
    --init-capture-pack) INIT_CAPTURE_PACK=1; shift ;;
    --skip-edge) SKIP_EDGE=1; shift ;;
    --allow-mock-artifacts) ALLOW_MOCK_ARTIFACTS=1; shift ;;
    --use-mock-artifacts) USE_MOCK_ARTIFACTS=1; shift ;;
    --generate-signoff) GENERATE_SIGNOFF=1; shift ;;
    --signoff-out) SIGNOFF_OUT="${2:-}"; shift 2 ;;
    --compare-previous-release) COMPARE_PREVIOUS_RELEASE=1; shift ;;
    --previous-release-gate-json) PREVIOUS_RELEASE_GATE_JSON="${2:-}"; shift 2 ;;
    --allow-release-hold-reason-increase-count) ALLOW_RELEASE_HOLD_REASON_INCREASE_COUNT="${2:-0}"; shift 2 ;;
    --allow-release-fail-reason-increase-count) ALLOW_RELEASE_FAIL_REASON_INCREASE_COUNT="${2:-0}"; shift 2 ;;
    --require-release-gate-pass) REQUIRE_RELEASE_GATE_PASS=1; shift ;;
    --require-release-trend-pass) REQUIRE_RELEASE_TREND_PASS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "FAIL: Unknown argument: $1"; exit 1 ;;
  esac
done

if ! [[ "$MAX_REPORT_AGE_HOURS" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --max-report-age-hours must be a non-negative integer."
  exit 1
fi
if ! [[ "$ALLOW_RELEASE_HOLD_REASON_INCREASE_COUNT" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --allow-release-hold-reason-increase-count must be a non-negative integer."
  exit 1
fi
if ! [[ "$ALLOW_RELEASE_FAIL_REASON_INCREASE_COUNT" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --allow-release-fail-reason-increase-count must be a non-negative integer."
  exit 1
fi
if [[ "$USE_MOCK_ARTIFACTS" -eq 1 && "$SKIP_EDGE" -eq 0 ]]; then
  SKIP_EDGE=1
fi

if [[ -z "$ARTIFACT_DIR" ]]; then
  ARTIFACT_DIR="tmp/cctv_field_validation/field-$(date -u +%Y%m%dT%H%M%SZ)"
fi

if [[ "$GENERATE_SIGNOFF" -eq 1 ]]; then
  CANONICAL_SIGNOFF_OUT="$ARTIFACT_DIR/signoff.md"
  if [[ -n "$SIGNOFF_OUT" ]]; then
    EXPORT_SIGNOFF_OUT="$SIGNOFF_OUT"
  fi
fi

echo "== ONYX CCTV Field Gate =="
echo "Provider: $PROVIDER"
echo "Edge URL: $EDGE_URL"
echo "Site ID: ${SITE_ID:-<unset>}"
echo "Camera ID: ${CAMERA_ID:-<unset>}"
echo "Zone: ${ZONE:-<unset>}"
echo "Event ID: ${EVENT_ID:-<unset>}"
echo "Capture dir: $CAPTURE_DIR"
echo "Artifact dir: $ARTIFACT_DIR"
echo "Max report age: ${MAX_REPORT_AGE_HOURS}h"
echo "Mock validation path: $([[ "$USE_MOCK_ARTIFACTS" -eq 1 ]] && echo enabled || echo disabled)"
echo "Signoff generation: $([[ "$GENERATE_SIGNOFF" -eq 1 ]] && echo enabled || echo disabled)"

if [[ "$INIT_CAPTURE_PACK" -eq 1 ]]; then
  init_cmd=(
    ./scripts/onyx_cctv_capture_pack_init.sh
    --out-dir "$CAPTURE_DIR"
  )
  [[ -n "$SITE_ID" ]] && init_cmd+=(--site-id "$SITE_ID")
  [[ -n "$EDGE_URL" ]] && init_cmd+=(--edge-url "$EDGE_URL")
  [[ -n "$CAMERA_ID" ]] && init_cmd+=(--camera-id "$CAMERA_ID")
  [[ -n "$ZONE" ]] && init_cmd+=(--zone "$ZONE")
  [[ -n "$EVENT_ID" ]] && init_cmd+=(--event-id "$EVENT_ID")
  "${init_cmd[@]}"
fi

if [[ "$USE_MOCK_ARTIFACTS" -eq 1 ]]; then
  mock_cmd=(
    ./scripts/onyx_cctv_mock_validation_artifacts.sh
    --out-dir "$ARTIFACT_DIR"
    --provider "$PROVIDER"
  )
  [[ -n "$EVENT_ID" ]] && mock_cmd+=(--event-id "$EVENT_ID")
  [[ -n "$CAMERA_ID" ]] && mock_cmd+=(--expect-camera "$CAMERA_ID")
  [[ -n "$ZONE" ]] && mock_cmd+=(--expect-zone "$ZONE")
  "${mock_cmd[@]}"
else
  validate_cmd=(
    ./scripts/onyx_cctv_field_validation.sh
    --edge-url "$EDGE_URL"
    --provider "$PROVIDER"
    --capture-dir "$CAPTURE_DIR"
    --artifact-dir "$ARTIFACT_DIR"
  )
  [[ -n "$EVENT_ID" ]] && validate_cmd+=(--event-id "$EVENT_ID")
  [[ -n "$CAMERA_ID" ]] && validate_cmd+=(--expect-camera "$CAMERA_ID")
  [[ -n "$ZONE" ]] && validate_cmd+=(--expect-zone "$ZONE")
  [[ "$SKIP_EDGE" -eq 1 ]] && validate_cmd+=(--skip-edge)
  "${validate_cmd[@]}"
fi

base_readiness_cmd=(
  ./scripts/onyx_cctv_pilot_readiness_check.sh
  --provider "$PROVIDER"
  --report-json "$ARTIFACT_DIR/validation_report.json"
  --max-report-age-hours "$MAX_REPORT_AGE_HOURS"
)
[[ -n "$CAMERA_ID" ]] && base_readiness_cmd+=(--expect-camera "$CAMERA_ID")
[[ -n "$ZONE" ]] && base_readiness_cmd+=(--expect-zone "$ZONE")
if [[ "$ALLOW_MOCK_ARTIFACTS" -ne 1 ]]; then
  base_readiness_cmd+=(--require-real-artifacts)
fi
"${base_readiness_cmd[@]}" >/dev/null

if [[ "$GENERATE_SIGNOFF" -eq 1 ]]; then
  signoff_cmd=(
    ./scripts/onyx_cctv_signoff_generate.sh
    --report-json "$ARTIFACT_DIR/validation_report.json"
    --provider "$PROVIDER"
    --out "$CANONICAL_SIGNOFF_OUT"
  )
  [[ -n "$CAMERA_ID" ]] && signoff_cmd+=(--expect-camera "$CAMERA_ID")
  [[ -n "$ZONE" ]] && signoff_cmd+=(--expect-zone "$ZONE")
  [[ "$ALLOW_MOCK_ARTIFACTS" -eq 1 ]] && signoff_cmd+=(--allow-mock-artifacts)
  "${signoff_cmd[@]}" >/dev/null
fi

release_cmd=(
  ./scripts/onyx_cctv_release_gate.sh
  --validation-report-json "$ARTIFACT_DIR/validation_report.json"
  --out-dir "$ARTIFACT_DIR"
)
if [[ "$GENERATE_SIGNOFF" -eq 1 ]]; then
  release_cmd+=(--signoff-file "$ARTIFACT_DIR/signoff.md" --signoff-report-json "$ARTIFACT_DIR/signoff.json")
fi
if [[ "$ALLOW_MOCK_ARTIFACTS" -ne 1 ]]; then
  release_cmd+=(--require-real-artifacts)
fi
"${release_cmd[@]}" >/dev/null

RELEASE_TREND_STATUS=""
RELEASE_TREND_PRIMARY_CODE=""
RELEASE_TREND_SUMMARY=""

if [[ "$GENERATE_SIGNOFF" -eq 1 ]]; then
  signoff_with_release_cmd=(
    ./scripts/onyx_cctv_signoff_generate.sh
    --report-json "$ARTIFACT_DIR/validation_report.json"
    --provider "$PROVIDER"
    --out "$CANONICAL_SIGNOFF_OUT"
    --release-gate-json "$ARTIFACT_DIR/release_gate.json"
  )
  [[ -n "$CAMERA_ID" ]] && signoff_with_release_cmd+=(--expect-camera "$CAMERA_ID")
  [[ -n "$ZONE" ]] && signoff_with_release_cmd+=(--expect-zone "$ZONE")
  [[ "$ALLOW_MOCK_ARTIFACTS" -eq 1 ]] && signoff_with_release_cmd+=(--allow-mock-artifacts)
  "${signoff_with_release_cmd[@]}" >/dev/null
  "${release_cmd[@]}" >/dev/null
fi

if [[ "$COMPARE_PREVIOUS_RELEASE" -eq 1 ]]; then
  release_trend_cmd=(
    ./scripts/onyx_cctv_release_trend_check.sh
    --current-release-gate-json "$ARTIFACT_DIR/release_gate.json"
    --out-dir "$ARTIFACT_DIR"
    --allow-hold-reason-increase-count "$ALLOW_RELEASE_HOLD_REASON_INCREASE_COUNT"
    --allow-fail-reason-increase-count "$ALLOW_RELEASE_FAIL_REASON_INCREASE_COUNT"
  )
  [[ -n "$PREVIOUS_RELEASE_GATE_JSON" ]] && release_trend_cmd+=(--previous-release-gate-json "$PREVIOUS_RELEASE_GATE_JSON")
  "${release_trend_cmd[@]}" >/dev/null
  if [[ -f "$ARTIFACT_DIR/release_trend_report.json" ]]; then
    RELEASE_TREND_STATUS="$(json_get "$ARTIFACT_DIR/release_trend_report.json" "status" | tr '[:lower:]' '[:upper:]')"
    RELEASE_TREND_PRIMARY_CODE="$(json_get "$ARTIFACT_DIR/release_trend_report.json" "primary_regression_code")"
    RELEASE_TREND_SUMMARY="$(json_get "$ARTIFACT_DIR/release_trend_report.json" "summary")"
  fi
  if [[ "$GENERATE_SIGNOFF" -eq 1 ]]; then
    signoff_with_trend_cmd=(
      ./scripts/onyx_cctv_signoff_generate.sh
      --report-json "$ARTIFACT_DIR/validation_report.json"
      --provider "$PROVIDER"
      --out "$CANONICAL_SIGNOFF_OUT"
      --release-gate-json "$ARTIFACT_DIR/release_gate.json"
      --release-trend-report-json "$ARTIFACT_DIR/release_trend_report.json"
    )
    [[ -n "$CAMERA_ID" ]] && signoff_with_trend_cmd+=(--expect-camera "$CAMERA_ID")
    [[ -n "$ZONE" ]] && signoff_with_trend_cmd+=(--expect-zone "$ZONE")
    [[ "$ALLOW_MOCK_ARTIFACTS" -eq 1 ]] && signoff_with_trend_cmd+=(--allow-mock-artifacts)
    "${signoff_with_trend_cmd[@]}" >/dev/null
  fi
fi

if [[ "$REQUIRE_RELEASE_TREND_PASS" -eq 1 ]]; then
  enforced_readiness_cmd=(
    ./scripts/onyx_cctv_pilot_readiness_check.sh
    --provider "$PROVIDER"
    --report-json "$ARTIFACT_DIR/validation_report.json"
    --release-gate-json "$ARTIFACT_DIR/release_gate.json"
    --release-trend-report-json "$ARTIFACT_DIR/release_trend_report.json"
    --max-report-age-hours "$MAX_REPORT_AGE_HOURS"
    --require-release-gate-pass
    --require-release-trend-pass
  )
  [[ -n "$CAMERA_ID" ]] && enforced_readiness_cmd+=(--expect-camera "$CAMERA_ID")
  [[ -n "$ZONE" ]] && enforced_readiness_cmd+=(--expect-zone "$ZONE")
  if [[ "$ALLOW_MOCK_ARTIFACTS" -ne 1 ]]; then
    enforced_readiness_cmd+=(--require-real-artifacts)
  fi
  "${enforced_readiness_cmd[@]}" >/dev/null
fi

release_result=""
release_primary_fail_code=""
release_primary_hold_code=""
if [[ -f "$ARTIFACT_DIR/release_gate.json" ]]; then
  release_result="$(json_get "$ARTIFACT_DIR/release_gate.json" "result" | tr '[:lower:]' '[:upper:]')"
  release_primary_fail_code="$(json_get "$ARTIFACT_DIR/release_gate.json" "primary_fail_code")"
  release_primary_hold_code="$(json_get "$ARTIFACT_DIR/release_gate.json" "primary_hold_code")"
fi

if [[ "$REQUIRE_RELEASE_GATE_PASS" -eq 1 && "$release_result" != "PASS" ]]; then
  echo "FAIL: CCTV release gate is ${release_result:-UNKNOWN}, expected PASS under --require-release-gate-pass."
  exit 1
fi

if [[ "$GENERATE_SIGNOFF" -eq 1 && -n "$EXPORT_SIGNOFF_OUT" && "$EXPORT_SIGNOFF_OUT" != "$CANONICAL_SIGNOFF_OUT" ]]; then
  mkdir -p "$(dirname "$EXPORT_SIGNOFF_OUT")"
  cp "$CANONICAL_SIGNOFF_OUT" "$EXPORT_SIGNOFF_OUT"
  cp "$ARTIFACT_DIR/signoff.json" "$(dirname "$EXPORT_SIGNOFF_OUT")/$(basename "$EXPORT_SIGNOFF_OUT" .md).json"
fi

echo ""
echo "PASS: CCTV field gate completed."
echo "Capture pack: $CAPTURE_DIR"
echo "Validation artifact: $ARTIFACT_DIR/validation_report.json"
echo "Release gate: $ARTIFACT_DIR/release_gate.json"
echo "Release gate result: ${release_result:-unknown}"
if [[ -n "$release_primary_fail_code" ]]; then
  echo "Release gate primary fail code: $release_primary_fail_code"
fi
if [[ -n "$release_primary_hold_code" ]]; then
  echo "Release gate primary hold code: $release_primary_hold_code"
fi
if [[ -f "$ARTIFACT_DIR/release_trend_report.json" ]]; then
  echo "Release trend: $ARTIFACT_DIR/release_trend_report.json"
  echo "Release trend status: ${RELEASE_TREND_STATUS:-unknown}"
  if [[ -n "$RELEASE_TREND_PRIMARY_CODE" ]]; then
    echo "Release trend primary regression code: $RELEASE_TREND_PRIMARY_CODE"
  fi
  if [[ -n "$RELEASE_TREND_SUMMARY" ]]; then
    echo "Release trend summary: $RELEASE_TREND_SUMMARY"
  fi
fi
if [[ "$GENERATE_SIGNOFF" -eq 1 ]]; then
  echo "Signoff artifact: $ARTIFACT_DIR/signoff.json"
  echo "Signoff markdown: $ARTIFACT_DIR/signoff.md"
  if [[ -n "$EXPORT_SIGNOFF_OUT" && "$EXPORT_SIGNOFF_OUT" != "$CANONICAL_SIGNOFF_OUT" ]]; then
    echo "Signoff export markdown: $EXPORT_SIGNOFF_OUT"
    echo "Signoff export JSON: $(dirname "$EXPORT_SIGNOFF_OUT")/$(basename "$EXPORT_SIGNOFF_OUT" .md).json"
  fi
fi
