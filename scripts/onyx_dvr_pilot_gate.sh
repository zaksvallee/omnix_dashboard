#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

EDGE_URL="${EDGE_BASE_URL:-http://localhost:5000}"
PROVIDER="${ONYX_DVR_PROVIDER:-hikvision_dvr}"
EVENT_ID=""
SITE_ID=""
CAMERA_ID=""
ZONE=""
CAPTURE_DIR="tmp/dvr_capture"
ARTIFACT_DIR=""
MAX_REPORT_AGE_HOURS="${ONYX_DVR_MAX_VALIDATION_REPORT_AGE_HOURS:-24}"
INIT_CAPTURE_PACK=0
SKIP_EDGE=0
ALLOW_MOCK_ARTIFACTS=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_dvr_pilot_gate.sh [--edge-url <url>] [--provider <id>] [--site-id <site_id>] [--event-id <event_id>] [--camera-id <camera_id>] [--zone <zone>] [--capture-dir <path>] [--artifact-dir <path>] [--max-report-age-hours <hours>] [--init-capture-pack] [--skip-edge] [--allow-mock-artifacts]
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
    -h|--help) usage; exit 0 ;;
    *) echo "FAIL: Unknown argument: $1"; exit 1 ;;
  esac
done

if ! [[ "$MAX_REPORT_AGE_HOURS" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --max-report-age-hours must be a non-negative integer."
  exit 1
fi

if [[ -z "$ARTIFACT_DIR" ]]; then
  ARTIFACT_DIR="tmp/dvr_field_validation/pilot-$(date -u +%Y%m%dT%H%M%SZ)"
fi

echo "== ONYX DVR Pilot Gate =="
echo "Provider: $PROVIDER"
echo "Edge URL: $EDGE_URL"
echo "Site ID: ${SITE_ID:-<unset>}"
echo "Camera ID: ${CAMERA_ID:-<unset>}"
echo "Zone: ${ZONE:-<unset>}"
echo "Event ID: ${EVENT_ID:-<unset>}"
echo "Capture dir: $CAPTURE_DIR"
echo "Artifact dir: $ARTIFACT_DIR"
echo "Max report age: ${MAX_REPORT_AGE_HOURS}h"
echo "Real-artifact enforcement: $([[ "$ALLOW_MOCK_ARTIFACTS" -eq 1 ]] && echo no || echo yes)"

if [[ "$INIT_CAPTURE_PACK" -eq 1 ]]; then
  init_cmd=(./scripts/onyx_dvr_capture_pack_init.sh --out-dir "$CAPTURE_DIR" --provider "$PROVIDER")
  [[ -n "$SITE_ID" ]] && init_cmd+=(--site-id "$SITE_ID")
  [[ -n "$EDGE_URL" ]] && init_cmd+=(--edge-url "$EDGE_URL")
  [[ -n "$CAMERA_ID" ]] && init_cmd+=(--camera-id "$CAMERA_ID")
  [[ -n "$ZONE" ]] && init_cmd+=(--zone "$ZONE")
  [[ -n "$EVENT_ID" ]] && init_cmd+=(--event-id "$EVENT_ID")
  "${init_cmd[@]}"
fi

validate_cmd=(
  ./scripts/onyx_dvr_field_validation.sh
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

readiness_cmd=(
  ./scripts/onyx_dvr_pilot_readiness_check.sh
  --provider "$PROVIDER"
  --report-json "$ARTIFACT_DIR/validation_report.json"
  --max-report-age-hours "$MAX_REPORT_AGE_HOURS"
)
[[ -n "$CAMERA_ID" ]] && readiness_cmd+=(--expect-camera "$CAMERA_ID")
[[ -n "$ZONE" ]] && readiness_cmd+=(--expect-zone "$ZONE")
[[ "$ALLOW_MOCK_ARTIFACTS" -ne 1 ]] && readiness_cmd+=(--require-real-artifacts)
"${readiness_cmd[@]}"

echo
echo "PASS: DVR pilot gate completed."
echo "Capture pack: $CAPTURE_DIR"
echo "Validation artifact: $ARTIFACT_DIR"
echo "Signoff template: docs/onyx_dvr_pilot_signoff_template.md"
