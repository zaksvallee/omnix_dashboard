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
USE_MOCK_ARTIFACTS=0
GENERATE_SIGNOFF=0
SIGNOFF_OUT=""
EFFECTIVE_SIGNOFF_OUT=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_dvr_field_gate.sh [--edge-url <url>] [--provider <id>] [--site-id <site_id>] [--event-id <event_id>] [--camera-id <camera_id>] [--zone <zone>] [--capture-dir <path>] [--artifact-dir <path>] [--max-report-age-hours <hours>] [--init-capture-pack] [--skip-edge] [--allow-mock-artifacts] [--use-mock-artifacts] [--generate-signoff] [--signoff-out <path>]

Purpose:
  One-command DVR field gate:
  1) optionally initialize the capture pack
  2) run the DVR pilot gate or generate mock validation artifacts
  3) optionally generate the DVR signoff note
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
    -h|--help) usage; exit 0 ;;
    *) echo "FAIL: Unknown argument: $1"; exit 1 ;;
  esac
done

if ! [[ "$MAX_REPORT_AGE_HOURS" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --max-report-age-hours must be a non-negative integer."
  exit 1
fi

if [[ "$USE_MOCK_ARTIFACTS" -eq 1 && "$SKIP_EDGE" -eq 0 ]]; then
  SKIP_EDGE=1
fi

if [[ -z "$ARTIFACT_DIR" ]]; then
  ARTIFACT_DIR="tmp/dvr_field_validation/field-$(date -u +%Y%m%dT%H%M%SZ)"
fi

if [[ "$GENERATE_SIGNOFF" -eq 1 ]]; then
  if [[ -n "$SIGNOFF_OUT" ]]; then
    EFFECTIVE_SIGNOFF_OUT="$SIGNOFF_OUT"
  else
    EFFECTIVE_SIGNOFF_OUT="$ARTIFACT_DIR/dvr_pilot_signoff.md"
  fi
fi

echo "== ONYX DVR Field Gate =="
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
    ./scripts/onyx_dvr_capture_pack_init.sh
    --out-dir "$CAPTURE_DIR"
    --provider "$PROVIDER"
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
    ./scripts/onyx_dvr_mock_validation_artifacts.sh
    --out-dir "$ARTIFACT_DIR"
    --provider "$PROVIDER"
  )
  [[ -n "$EVENT_ID" ]] && mock_cmd+=(--event-id "$EVENT_ID")
  [[ -n "$CAMERA_ID" ]] && mock_cmd+=(--expect-camera "$CAMERA_ID")
  [[ -n "$ZONE" ]] && mock_cmd+=(--expect-zone "$ZONE")
  "${mock_cmd[@]}"

  readiness_cmd=(
    ./scripts/onyx_dvr_pilot_readiness_check.sh
    --provider "$PROVIDER"
    --report-json "$ARTIFACT_DIR/validation_report.json"
    --max-report-age-hours "$MAX_REPORT_AGE_HOURS"
  )
  [[ -n "$CAMERA_ID" ]] && readiness_cmd+=(--expect-camera "$CAMERA_ID")
  [[ -n "$ZONE" ]] && readiness_cmd+=(--expect-zone "$ZONE")
  if [[ "$ALLOW_MOCK_ARTIFACTS" -ne 1 ]]; then
    readiness_cmd+=(--require-real-artifacts)
  fi
  "${readiness_cmd[@]}"
else
  gate_cmd=(
    ./scripts/onyx_dvr_pilot_gate.sh
    --edge-url "$EDGE_URL"
    --provider "$PROVIDER"
    --capture-dir "$CAPTURE_DIR"
    --artifact-dir "$ARTIFACT_DIR"
    --max-report-age-hours "$MAX_REPORT_AGE_HOURS"
  )
  [[ -n "$SITE_ID" ]] && gate_cmd+=(--site-id "$SITE_ID")
  [[ -n "$EVENT_ID" ]] && gate_cmd+=(--event-id "$EVENT_ID")
  [[ -n "$CAMERA_ID" ]] && gate_cmd+=(--camera-id "$CAMERA_ID")
  [[ -n "$ZONE" ]] && gate_cmd+=(--zone "$ZONE")
  [[ "$SKIP_EDGE" -eq 1 ]] && gate_cmd+=(--skip-edge)
  [[ "$ALLOW_MOCK_ARTIFACTS" -eq 1 ]] && gate_cmd+=(--allow-mock-artifacts)
  "${gate_cmd[@]}"
fi

if [[ "$GENERATE_SIGNOFF" -eq 1 ]]; then
  signoff_cmd=(
    ./scripts/onyx_dvr_signoff_generate.sh
    --report-json "$ARTIFACT_DIR/validation_report.json"
    --provider "$PROVIDER"
    --out "$EFFECTIVE_SIGNOFF_OUT"
  )
  [[ -n "$CAMERA_ID" ]] && signoff_cmd+=(--expect-camera "$CAMERA_ID")
  [[ -n "$ZONE" ]] && signoff_cmd+=(--expect-zone "$ZONE")
  [[ "$ALLOW_MOCK_ARTIFACTS" -eq 1 ]] && signoff_cmd+=(--allow-mock-artifacts)
  "${signoff_cmd[@]}"
fi

echo
echo "PASS: DVR field gate completed."
echo "Validation artifact: $ARTIFACT_DIR/validation_report.json"
if [[ -f "$ARTIFACT_DIR/readiness_report.json" ]]; then
  echo "Readiness artifact: $ARTIFACT_DIR/readiness_report.json"
fi
if [[ "$GENERATE_SIGNOFF" -eq 1 ]]; then
  echo "Signoff note: $EFFECTIVE_SIGNOFF_OUT"
fi
