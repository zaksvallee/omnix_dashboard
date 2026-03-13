#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CAPTURE_DIR="tmp/listener_capture"
SITE_ID=""
DEVICE_PATH=""
LEGACY_SOURCE=""
CLIENT_ID="CLIENT-001"
REGION_ID="REGION-GAUTENG"
ARTIFACT_DIR=""
BENCH_BASELINE_JSON=""
MAX_REPORT_AGE_HOURS=24
MIN_MATCH_RATE_PERCENT=95
MAX_SKEW_SECONDS=90
MAX_OBSERVED_SKEW_SECONDS=""
ALLOW_DRIFT_REASONS=()
MAX_DRIFT_REASON_COUNTS=()
COMPARE_PREVIOUS=0
PREVIOUS_REPORT_JSON=""
ALLOW_MATCH_RATE_DROP_PERCENT=0
ALLOW_MAX_SKEW_INCREASE_SECONDS=0
ALLOW_TREND_DRIFT_COUNT_INCREASES=()
MAX_CAPTURE_SIGNATURES=""
ALLOW_CAPTURE_SIGNATURES=()
MAX_UNEXPECTED_SIGNATURES=""
MAX_FALLBACK_TIMESTAMP_COUNT=""
MAX_UNKNOWN_EVENT_RATE_PERCENT=""
INIT_CAPTURE_PACK=0
GENERATE_SIGNOFF=0
SIGNOFF_OUT=""
ALLOW_MOCK_ARTIFACTS=0
REQUIRE_TREND_PASS=0
REQUIRE_BASELINE_HISTORY=0
MAX_BASELINE_AGE_DAYS=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_field_gate.sh [--capture-dir <path>] [--site-id <site_id>] [--device-path <tty>] [--legacy-source <label>] [--client-id <id>] [--region-id <id>] [--artifact-dir <path>] [--bench-baseline-json <path>] [--max-report-age-hours <hours>] [--min-match-rate-percent 95] [--max-skew-seconds 90] [--max-observed-skew-seconds <n>] [--allow-drift-reason <reason>]... [--max-drift-reason-count <reason=count>]... [--compare-previous] [--previous-report-json <path>] [--allow-match-rate-drop-percent 0] [--allow-max-skew-increase-seconds 0] [--allow-trend-drift-count-increase <reason=count>]... [--max-capture-signatures <count>] [--allow-capture-signature <signature>]... [--max-unexpected-signatures <count>] [--max-fallback-timestamp-count <count>] [--max-unknown-event-rate-percent <percent>] [--init-capture-pack] [--generate-signoff] [--signoff-out <path>] [--require-trend-pass] [--require-baseline-history] [--max-baseline-age-days <days>] [--allow-mock-artifacts]

Purpose:
  One-command listener field gate:
  1) optionally initialize the capture pack
  2) run listener field validation
  3) run listener readiness with real-artifact enforcement by default
  4) optionally generate the listener signoff note
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
    --bench-baseline-json)
      BENCH_BASELINE_JSON="${2:-}"
      shift 2
      ;;
    --max-report-age-hours)
      MAX_REPORT_AGE_HOURS="${2:-24}"
      shift 2
      ;;
    --min-match-rate-percent)
      MIN_MATCH_RATE_PERCENT="${2:-95}"
      shift 2
      ;;
    --max-skew-seconds)
      MAX_SKEW_SECONDS="${2:-90}"
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
    --max-capture-signatures)
      MAX_CAPTURE_SIGNATURES="${2:-}"
      shift 2
      ;;
    --allow-capture-signature)
      ALLOW_CAPTURE_SIGNATURES+=("${2:-}")
      shift 2
      ;;
    --max-unexpected-signatures)
      MAX_UNEXPECTED_SIGNATURES="${2:-}"
      shift 2
      ;;
    --max-fallback-timestamp-count)
      MAX_FALLBACK_TIMESTAMP_COUNT="${2:-}"
      shift 2
      ;;
    --max-unknown-event-rate-percent)
      MAX_UNKNOWN_EVENT_RATE_PERCENT="${2:-}"
      shift 2
      ;;
    --init-capture-pack)
      INIT_CAPTURE_PACK=1
      shift
      ;;
    --generate-signoff)
      GENERATE_SIGNOFF=1
      shift
      ;;
    --signoff-out)
      SIGNOFF_OUT="${2:-}"
      shift 2
      ;;
    --require-trend-pass)
      REQUIRE_TREND_PASS=1
      shift
      ;;
    --require-baseline-history)
      REQUIRE_BASELINE_HISTORY=1
      shift
      ;;
    --max-baseline-age-days)
      MAX_BASELINE_AGE_DAYS="${2:-}"
      shift 2
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
if [[ -n "$MAX_OBSERVED_SKEW_SECONDS" ]] && ! [[ "$MAX_OBSERVED_SKEW_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --max-observed-skew-seconds must be a non-negative integer."
  exit 1
fi
if [[ "$COMPARE_PREVIOUS" -eq 1 ]]; then
  REQUIRE_TREND_PASS=1
fi

if [[ -z "$ARTIFACT_DIR" ]]; then
  ARTIFACT_DIR="tmp/listener_field_validation/pilot-$(date -u +%Y%m%dT%H%M%SZ)"
fi

if [[ -z "$BENCH_BASELINE_JSON" && -f "$CAPTURE_DIR/listener_bench_baseline.json" ]]; then
  BENCH_BASELINE_JSON="$CAPTURE_DIR/listener_bench_baseline.json"
fi

json_get() {
  local report_file="$1"
  local expression="$2"
  python3 - "$report_file" "$expression" <<'PY'
import json
import sys

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

echo "== ONYX Listener Field Gate =="
echo "Capture dir: $CAPTURE_DIR"
echo "Artifact dir: $ARTIFACT_DIR"
echo "Site ID: ${SITE_ID:-<unset>}"
echo "Device path: ${DEVICE_PATH:-<unset>}"
echo "Legacy source: ${LEGACY_SOURCE:-<unset>}"
echo "Client ID: $CLIENT_ID"
echo "Region ID: $REGION_ID"
echo "Bench baseline: ${BENCH_BASELINE_JSON:-<none>}"
echo "Min match rate: ${MIN_MATCH_RATE_PERCENT}%"
echo "Max skew: ${MAX_SKEW_SECONDS}s"
echo "Max observed skew gate: ${MAX_OBSERVED_SKEW_SECONDS:-<disabled>}"
echo "Max capture signatures: ${MAX_CAPTURE_SIGNATURES:-<disabled>}"
if [[ -n "${ALLOW_CAPTURE_SIGNATURES[*]-}" ]]; then
  echo "Allowed capture signatures: ${ALLOW_CAPTURE_SIGNATURES[*]}"
fi
echo "Max unexpected signatures: ${MAX_UNEXPECTED_SIGNATURES:-<disabled>}"
echo "Max fallback timestamps: ${MAX_FALLBACK_TIMESTAMP_COUNT:-<disabled>}"
echo "Max unknown-event rate: ${MAX_UNKNOWN_EVENT_RATE_PERCENT:-<disabled>}%"
echo "Compare previous parity run: $([[ "$COMPARE_PREVIOUS" -eq 1 ]] && echo yes || echo no)"
if [[ -n "$PREVIOUS_REPORT_JSON" ]]; then
  echo "Previous report override: $PREVIOUS_REPORT_JSON"
fi
echo "Require trend pass: $([[ "$REQUIRE_TREND_PASS" -eq 1 ]] && echo yes || echo no)"
echo "Require baseline history: $([[ "$REQUIRE_BASELINE_HISTORY" -eq 1 ]] && echo yes || echo no)"
echo "Max baseline age: ${MAX_BASELINE_AGE_DAYS:-<disabled>}d"
echo "Generate signoff: $([[ "$GENERATE_SIGNOFF" -eq 1 ]] && echo yes || echo no)"
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

validate_cmd=(
  ./scripts/onyx_listener_field_validation.sh
  --capture-dir "$CAPTURE_DIR"
  --client-id "$CLIENT_ID"
  --region-id "$REGION_ID"
  --artifact-dir "$ARTIFACT_DIR"
  --min-match-rate-percent "$MIN_MATCH_RATE_PERCENT"
  --max-skew-seconds "$MAX_SKEW_SECONDS"
  --allow-match-rate-drop-percent "$ALLOW_MATCH_RATE_DROP_PERCENT"
  --allow-max-skew-increase-seconds "$ALLOW_MAX_SKEW_INCREASE_SECONDS"
)
if [[ -n "$SITE_ID" ]]; then
  validate_cmd+=(--site-id "$SITE_ID")
fi
if [[ -n "$BENCH_BASELINE_JSON" ]]; then
  validate_cmd+=(--bench-baseline-json "$BENCH_BASELINE_JSON")
fi
if [[ -n "$DEVICE_PATH" ]]; then
  validate_cmd+=(--device-path "$DEVICE_PATH")
fi
if [[ -n "$LEGACY_SOURCE" ]]; then
  validate_cmd+=(--legacy-source "$LEGACY_SOURCE")
fi
if [[ -n "$MAX_OBSERVED_SKEW_SECONDS" ]]; then
  validate_cmd+=(--max-observed-skew-seconds "$MAX_OBSERVED_SKEW_SECONDS")
fi
for allow_reason in "${ALLOW_DRIFT_REASONS[@]-}"; do
  [[ -n "$allow_reason" ]] || continue
  validate_cmd+=(--allow-drift-reason "$allow_reason")
done
for drift_cap in "${MAX_DRIFT_REASON_COUNTS[@]-}"; do
  [[ -n "$drift_cap" ]] || continue
  validate_cmd+=(--max-drift-reason-count "$drift_cap")
done
if [[ "$COMPARE_PREVIOUS" -eq 1 ]]; then
  validate_cmd+=(--compare-previous)
fi
if [[ -n "$PREVIOUS_REPORT_JSON" ]]; then
  validate_cmd+=(--previous-report-json "$PREVIOUS_REPORT_JSON")
fi
for trend_cap in "${ALLOW_TREND_DRIFT_COUNT_INCREASES[@]-}"; do
  [[ -n "$trend_cap" ]] || continue
  validate_cmd+=(--allow-trend-drift-count-increase "$trend_cap")
done
if [[ -n "$MAX_CAPTURE_SIGNATURES" ]]; then
  validate_cmd+=(--max-capture-signatures "$MAX_CAPTURE_SIGNATURES")
fi
for signature in "${ALLOW_CAPTURE_SIGNATURES[@]-}"; do
  [[ -n "$signature" ]] || continue
  validate_cmd+=(--allow-capture-signature "$signature")
done
if [[ -n "$MAX_UNEXPECTED_SIGNATURES" ]]; then
  validate_cmd+=(--max-unexpected-signatures "$MAX_UNEXPECTED_SIGNATURES")
fi
if [[ -n "$MAX_FALLBACK_TIMESTAMP_COUNT" ]]; then
  validate_cmd+=(--max-fallback-timestamp-count "$MAX_FALLBACK_TIMESTAMP_COUNT")
fi
if [[ -n "$MAX_UNKNOWN_EVENT_RATE_PERCENT" ]]; then
  validate_cmd+=(--max-unknown-event-rate-percent "$MAX_UNKNOWN_EVENT_RATE_PERCENT")
fi
if [[ "$ALLOW_MOCK_ARTIFACTS" -eq 1 ]]; then
  validate_cmd+=(--allow-mock-artifacts)
fi

"${validate_cmd[@]}"

readiness_cmd=(
  ./scripts/onyx_listener_pilot_readiness_check.sh
  --report-json "$ARTIFACT_DIR/validation_report.json"
  --max-report-age-hours "$MAX_REPORT_AGE_HOURS"
)
if [[ "$REQUIRE_TREND_PASS" -eq 1 ]]; then
  readiness_cmd+=(--require-trend-pass)
fi
if [[ "$REQUIRE_BASELINE_HISTORY" -eq 1 ]]; then
  readiness_cmd+=(--require-baseline-history)
fi
if [[ -n "$MAX_BASELINE_AGE_DAYS" ]]; then
  readiness_cmd+=(--max-baseline-age-days "$MAX_BASELINE_AGE_DAYS")
fi
if [[ "$ALLOW_MOCK_ARTIFACTS" -ne 1 ]]; then
  readiness_cmd+=(--require-real-artifacts)
fi

"${readiness_cmd[@]}"

if [[ "$GENERATE_SIGNOFF" -eq 1 ]]; then
  signoff_cmd=(
    ./scripts/onyx_listener_signoff_generate.sh
    --report-json "$ARTIFACT_DIR/pilot_artifact/report.json"
  )
  if [[ -f "$ARTIFACT_DIR/pilot_artifact/trend_report.json" ]]; then
    signoff_cmd+=(--trend-report-json "$ARTIFACT_DIR/pilot_artifact/trend_report.json")
  fi
  if [[ "$REQUIRE_TREND_PASS" -eq 1 ]]; then
    signoff_cmd+=(--require-trend-pass)
  fi
  if [[ -n "$SIGNOFF_OUT" ]]; then
    signoff_cmd+=(--out "$SIGNOFF_OUT")
  fi
  if [[ "$ALLOW_MOCK_ARTIFACTS" -eq 1 ]]; then
    signoff_cmd+=(--allow-mock-artifacts)
  fi
  "${signoff_cmd[@]}"
fi

VALIDATION_REPORT_JSON="$ARTIFACT_DIR/validation_report.json"
BASELINE_REVIEW_STATUS="$(json_get "$VALIDATION_REPORT_JSON" "baseline_review.status" | tr '[:lower:]' '[:upper:]')"
BASELINE_REVIEW_RECOMMENDATION="$(json_get "$VALIDATION_REPORT_JSON" "baseline_review.recommendation")"
BASELINE_REVIEW_SUMMARY="$(json_get "$VALIDATION_REPORT_JSON" "baseline_review.summary")"
BASELINE_HEALTH_STATUS="$(json_get "$VALIDATION_REPORT_JSON" "baseline_health.status" | tr '[:lower:]' '[:upper:]')"
BASELINE_HEALTH_CATEGORY="$(json_get "$VALIDATION_REPORT_JSON" "baseline_health.category")"
BASELINE_HEALTH_SUMMARY="$(json_get "$VALIDATION_REPORT_JSON" "baseline_health.summary")"
BASELINE_HEALTH_AGE_DAYS="$(json_get "$VALIDATION_REPORT_JSON" "baseline_health.age_days")"

echo ""
echo "PASS: Listener field gate completed."
echo "Capture pack: $CAPTURE_DIR"
echo "Validation artifact: $ARTIFACT_DIR"
echo "Baseline review: ${BASELINE_REVIEW_RECOMMENDATION:-unknown} (${BASELINE_REVIEW_STATUS:-unknown})"
echo "Baseline review summary: ${BASELINE_REVIEW_SUMMARY:-n/a}"
if [[ -n "$BASELINE_HEALTH_AGE_DAYS" ]]; then
  echo "Baseline health: ${BASELINE_HEALTH_CATEGORY:-unknown} (${BASELINE_HEALTH_STATUS:-unknown}, ${BASELINE_HEALTH_AGE_DAYS}d)"
else
  echo "Baseline health: ${BASELINE_HEALTH_CATEGORY:-unknown} (${BASELINE_HEALTH_STATUS:-unknown})"
fi
echo "Baseline health summary: ${BASELINE_HEALTH_SUMMARY:-n/a}"
if [[ "$GENERATE_SIGNOFF" -eq 1 ]]; then
  if [[ -n "$SIGNOFF_OUT" ]]; then
    echo "Signoff: $SIGNOFF_OUT"
  else
    echo "Signoff: docs/onyx_listener_pilot_signoff_$(TZ=Africa/Johannesburg date +%Y-%m-%d).md"
  fi
else
  echo "Signoff template: docs/onyx_listener_pilot_signoff_template.md"
fi
