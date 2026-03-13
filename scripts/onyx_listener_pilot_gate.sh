#!/usr/bin/env bash
set -euo pipefail

CAPTURE_DIR="tmp/listener_capture"
SITE_ID=""
DEVICE_PATH=""
LEGACY_SOURCE=""
CLIENT_ID="CLIENT-001"
REGION_ID="REGION-GAUTENG"
ARTIFACT_DIR=""
MAX_REPORT_AGE_HOURS=24
MAX_SKEW_SECONDS=90
INIT_CAPTURE_PACK=0
ALLOW_UNMATCHED_SERIAL=0
ALLOW_UNMATCHED_LEGACY=0
ALLOW_MOCK_ARTIFACTS=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_pilot_gate.sh [--capture-dir <path>] [--site-id <site_id>] [--device-path <tty>] [--legacy-source <label>] [--client-id <id>] [--region-id <id>] [--artifact-dir <path>] [--max-report-age-hours 24] [--max-skew-seconds 90] [--init-capture-pack] [--allow-unmatched-serial] [--allow-unmatched-legacy] [--allow-mock-artifacts]

Purpose:
  One-command listener pilot gate:
  1) optionally initialize the capture pack
  2) replay serial captures into normalized envelopes
  3) compare serial and legacy paths via parity report
  4) run readiness on the resulting parity artifact
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --capture-dir)
      CAPTURE_DIR="${2:-}"
      shift 2
      ;;
    --site-id)
      SITE_ID="${2:-}"
      shift 2
      ;;
    --device-path)
      DEVICE_PATH="${2:-}"
      shift 2
      ;;
    --legacy-source)
      LEGACY_SOURCE="${2:-}"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="${2:-}"
      shift 2
      ;;
    --region-id)
      REGION_ID="${2:-}"
      shift 2
      ;;
    --artifact-dir)
      ARTIFACT_DIR="${2:-}"
      shift 2
      ;;
    --max-report-age-hours)
      MAX_REPORT_AGE_HOURS="${2:-24}"
      shift 2
      ;;
    --max-skew-seconds)
      MAX_SKEW_SECONDS="${2:-90}"
      shift 2
      ;;
    --init-capture-pack)
      INIT_CAPTURE_PACK=1
      shift
      ;;
    --allow-unmatched-serial)
      ALLOW_UNMATCHED_SERIAL=1
      shift
      ;;
    --allow-unmatched-legacy)
      ALLOW_UNMATCHED_LEGACY=1
      shift
      ;;
    --allow-mock-artifacts)
      ALLOW_MOCK_ARTIFACTS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "FAIL: Unknown argument: $1"
      exit 1
      ;;
  esac
done

if ! [[ "$MAX_REPORT_AGE_HOURS" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --max-report-age-hours must be a non-negative integer."
  exit 1
fi
if ! [[ "$MAX_SKEW_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --max-skew-seconds must be a non-negative integer."
  exit 1
fi

if [[ -z "$ARTIFACT_DIR" ]]; then
  ARTIFACT_DIR="tmp/listener_parity/pilot-$(date -u +%Y%m%dT%H%M%SZ)"
fi

echo "== ONYX Listener Pilot Gate =="
echo "Capture dir: $CAPTURE_DIR"
echo "Artifact dir: $ARTIFACT_DIR"
echo "Site ID: ${SITE_ID:-<unset>}"
echo "Device path: ${DEVICE_PATH:-<unset>}"
echo "Legacy source: ${LEGACY_SOURCE:-<unset>}"
echo "Client ID: $CLIENT_ID"
echo "Region ID: $REGION_ID"
echo "Max report age: ${MAX_REPORT_AGE_HOURS}h"
echo "Max skew: ${MAX_SKEW_SECONDS}s"
echo "Real-artifact enforcement: $([[ "$ALLOW_MOCK_ARTIFACTS" -eq 1 ]] && echo no || echo yes)"

if [[ "$INIT_CAPTURE_PACK" -eq 1 ]]; then
  init_cmd=(
    ./scripts/onyx_listener_capture_pack_init.sh
    --out-dir "$CAPTURE_DIR"
    --client-id "$CLIENT_ID"
    --region-id "$REGION_ID"
  )
  if [[ -n "$SITE_ID" ]]; then
    init_cmd+=(--site-id "$SITE_ID")
  fi
  if [[ -n "$DEVICE_PATH" ]]; then
    init_cmd+=(--device-path "$DEVICE_PATH")
  fi
  if [[ -n "$LEGACY_SOURCE" ]]; then
    init_cmd+=(--legacy-source "$LEGACY_SOURCE")
  fi
  "${init_cmd[@]}"
fi

mkdir -p "$ARTIFACT_DIR"

./scripts/onyx_listener_serial_bench.sh \
  --input "$CAPTURE_DIR/serial_raw.txt" \
  --client-id "$CLIENT_ID" \
  --region-id "$REGION_ID" \
  --site-id "${SITE_ID:-SITE-SANDTON}" \
  --out "$ARTIFACT_DIR/serial_parsed.json"

./scripts/onyx_listener_parity_report.sh \
  --serial "$ARTIFACT_DIR/serial_parsed.json" \
  --legacy "$CAPTURE_DIR/legacy_events.json" \
  --max-skew-seconds "$MAX_SKEW_SECONDS" \
  --out "$ARTIFACT_DIR/report.json"

readiness_cmd=(
  ./scripts/onyx_listener_parity_readiness_check.sh
  --report-json "$ARTIFACT_DIR/report.json"
  --max-report-age-hours "$MAX_REPORT_AGE_HOURS"
)
if [[ "$ALLOW_UNMATCHED_SERIAL" -eq 1 ]]; then
  readiness_cmd+=(--allow-unmatched-serial)
fi
if [[ "$ALLOW_UNMATCHED_LEGACY" -eq 1 ]]; then
  readiness_cmd+=(--allow-unmatched-legacy)
fi
if [[ "$ALLOW_MOCK_ARTIFACTS" -ne 1 ]]; then
  readiness_cmd+=(--require-real-artifacts)
fi

"${readiness_cmd[@]}"

echo ""
echo "PASS: Listener pilot gate completed."
echo "Capture pack: $CAPTURE_DIR"
echo "Parity artifact: $ARTIFACT_DIR/report.json"
