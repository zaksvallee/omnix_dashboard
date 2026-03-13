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
MIN_MATCH_RATE_PERCENT=95
MAX_OBSERVED_SKEW_SECONDS=""
ALLOW_DRIFT_REASONS=()
MAX_DRIFT_REASON_COUNTS=()
COMPARE_PREVIOUS=0
PREVIOUS_REPORT_JSON=""
ALLOW_MATCH_RATE_DROP_PERCENT=0
ALLOW_MAX_SKEW_INCREASE_SECONDS=0
ALLOW_TREND_DRIFT_COUNT_INCREASES=()
INIT_CAPTURE_PACK=0
ALLOW_UNMATCHED_SERIAL=0
ALLOW_UNMATCHED_LEGACY=0
ALLOW_MOCK_ARTIFACTS=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_pilot_gate.sh [--capture-dir <path>] [--site-id <site_id>] [--device-path <tty>] [--legacy-source <label>] [--client-id <id>] [--region-id <id>] [--artifact-dir <path>] [--max-report-age-hours 24] [--max-skew-seconds 90] [--min-match-rate-percent 95] [--max-observed-skew-seconds <n>] [--allow-drift-reason <reason>]... [--max-drift-reason-count <reason=count>]... [--compare-previous] [--previous-report-json <path>] [--allow-match-rate-drop-percent 0] [--allow-max-skew-increase-seconds 0] [--allow-trend-drift-count-increase <reason=count>]... [--init-capture-pack] [--allow-unmatched-serial] [--allow-unmatched-legacy] [--allow-mock-artifacts]

Purpose:
  One-command listener pilot gate:
  1) optionally initialize the capture pack
  2) replay serial captures into normalized envelopes
  3) compare serial and legacy paths via parity report
  4) run readiness on the resulting parity artifact
  5) optionally compare the new artifact to the previous parity run
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
    --min-match-rate-percent)
      MIN_MATCH_RATE_PERCENT="${2:-95}"
      shift 2
      ;;
    --max-observed-skew-seconds)
      MAX_OBSERVED_SKEW_SECONDS="${2:-}"
      shift 2
      ;;
    --allow-drift-reason)
      ALLOW_DRIFT_REASONS+=("${2:-}")
      shift 2
      ;;
    --max-drift-reason-count)
      MAX_DRIFT_REASON_COUNTS+=("${2:-}")
      shift 2
      ;;
    --compare-previous)
      COMPARE_PREVIOUS=1
      shift
      ;;
    --previous-report-json)
      PREVIOUS_REPORT_JSON="${2:-}"
      shift 2
      ;;
    --allow-match-rate-drop-percent)
      ALLOW_MATCH_RATE_DROP_PERCENT="${2:-0}"
      shift 2
      ;;
    --allow-max-skew-increase-seconds)
      ALLOW_MAX_SKEW_INCREASE_SECONDS="${2:-0}"
      shift 2
      ;;
    --allow-trend-drift-count-increase)
      ALLOW_TREND_DRIFT_COUNT_INCREASES+=("${2:-}")
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
if ! [[ "$MIN_MATCH_RATE_PERCENT" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "FAIL: --min-match-rate-percent must be a non-negative number."
  exit 1
fi
if [[ -n "$MAX_OBSERVED_SKEW_SECONDS" ]] && ! [[ "$MAX_OBSERVED_SKEW_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --max-observed-skew-seconds must be a non-negative integer."
  exit 1
fi
if ! [[ "$ALLOW_MATCH_RATE_DROP_PERCENT" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "FAIL: --allow-match-rate-drop-percent must be a non-negative number."
  exit 1
fi
if ! [[ "$ALLOW_MAX_SKEW_INCREASE_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --allow-max-skew-increase-seconds must be a non-negative integer."
  exit 1
fi
for trend_drift_cap in "${ALLOW_TREND_DRIFT_COUNT_INCREASES[@]-}"; do
  [[ -n "$trend_drift_cap" ]] || continue
  if ! [[ "$trend_drift_cap" =~ ^[A-Za-z0-9_:-]+=[0-9]+$ ]]; then
    echo "FAIL: --allow-trend-drift-count-increase must use reason=count."
    exit 1
  fi
done

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
echo "Min match rate: ${MIN_MATCH_RATE_PERCENT}%"
echo "Max observed skew gate: ${MAX_OBSERVED_SKEW_SECONDS:-<disabled>}"
if [[ -n "${ALLOW_DRIFT_REASONS[*]-}" ]]; then
  echo "Allowed drift reasons: ${ALLOW_DRIFT_REASONS[*]}"
fi
if [[ -n "${MAX_DRIFT_REASON_COUNTS[*]-}" ]]; then
  echo "Drift caps: ${MAX_DRIFT_REASON_COUNTS[*]}"
fi
echo "Compare previous parity run: $([[ "$COMPARE_PREVIOUS" -eq 1 ]] && echo yes || echo no)"
if [[ -n "$PREVIOUS_REPORT_JSON" ]]; then
  echo "Previous report override: $PREVIOUS_REPORT_JSON"
fi
if [[ "$COMPARE_PREVIOUS" -eq 1 ]]; then
  echo "Allowed match-rate drop: ${ALLOW_MATCH_RATE_DROP_PERCENT}%"
  echo "Allowed max-skew increase: ${ALLOW_MAX_SKEW_INCREASE_SECONDS}s"
  if [[ -n "${ALLOW_TREND_DRIFT_COUNT_INCREASES[*]-}" ]]; then
    echo "Trend drift caps: ${ALLOW_TREND_DRIFT_COUNT_INCREASES[*]}"
  fi
fi
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
  --min-match-rate-percent "$MIN_MATCH_RATE_PERCENT" \
  --out "$ARTIFACT_DIR/report.json"

readiness_cmd=(
  ./scripts/onyx_listener_parity_readiness_check.sh
  --report-json "$ARTIFACT_DIR/report.json"
  --max-report-age-hours "$MAX_REPORT_AGE_HOURS"
  --min-match-rate-percent "$MIN_MATCH_RATE_PERCENT"
)
if [[ -n "$MAX_OBSERVED_SKEW_SECONDS" ]]; then
  readiness_cmd+=(--max-observed-skew-seconds "$MAX_OBSERVED_SKEW_SECONDS")
fi
for allow_reason in "${ALLOW_DRIFT_REASONS[@]-}"; do
  [[ -n "$allow_reason" ]] || continue
  readiness_cmd+=(--allow-drift-reason "$allow_reason")
done
for drift_cap in "${MAX_DRIFT_REASON_COUNTS[@]-}"; do
  [[ -n "$drift_cap" ]] || continue
  readiness_cmd+=(--max-drift-reason-count "$drift_cap")
done
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

if [[ "$COMPARE_PREVIOUS" -eq 1 ]]; then
  trend_cmd=(
    ./scripts/onyx_listener_parity_trend_check.sh
    --current-report-json "$ARTIFACT_DIR/report.json"
    --out-dir "$ARTIFACT_DIR"
    --allow-match-rate-drop-percent "$ALLOW_MATCH_RATE_DROP_PERCENT"
    --allow-max-skew-increase-seconds "$ALLOW_MAX_SKEW_INCREASE_SECONDS"
  )
  if [[ -n "$PREVIOUS_REPORT_JSON" ]]; then
    trend_cmd+=(--previous-report-json "$PREVIOUS_REPORT_JSON")
  fi
  for trend_drift_cap in "${ALLOW_TREND_DRIFT_COUNT_INCREASES[@]-}"; do
    [[ -n "$trend_drift_cap" ]] || continue
    trend_cmd+=(--allow-drift-count-increase "$trend_drift_cap")
  done
  "${trend_cmd[@]}"
fi

echo ""
echo "PASS: Listener pilot gate completed."
echo "Capture pack: $CAPTURE_DIR"
echo "Parity artifact: $ARTIFACT_DIR/report.json"
if [[ "$COMPARE_PREVIOUS" -eq 1 ]]; then
  echo "Trend artifact: $ARTIFACT_DIR/trend_report.json"
fi
