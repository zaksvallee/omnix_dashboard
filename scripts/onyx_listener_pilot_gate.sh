#!/usr/bin/env bash
set -euo pipefail

CAPTURE_DIR="tmp/listener_capture"
SITE_ID=""
DEVICE_PATH=""
LEGACY_SOURCE=""
CLIENT_ID="CLIENT-001"
REGION_ID="REGION-GAUTENG"
ARTIFACT_DIR=""
BENCH_BASELINE_JSON=""
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
MAX_CAPTURE_SIGNATURES=""
ALLOW_CAPTURE_SIGNATURES=()
MAX_UNEXPECTED_SIGNATURES=""
MAX_FALLBACK_TIMESTAMP_COUNT=""
MAX_UNKNOWN_EVENT_RATE_PERCENT=""
INIT_CAPTURE_PACK=0
ALLOW_UNMATCHED_SERIAL=0
ALLOW_UNMATCHED_LEGACY=0
ALLOW_MOCK_ARTIFACTS=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_pilot_gate.sh [--capture-dir <path>] [--site-id <site_id>] [--device-path <tty>] [--legacy-source <label>] [--client-id <id>] [--region-id <id>] [--artifact-dir <path>] [--bench-baseline-json <path>] [--max-report-age-hours 24] [--max-skew-seconds 90] [--min-match-rate-percent 95] [--max-observed-skew-seconds <n>] [--allow-drift-reason <reason>]... [--max-drift-reason-count <reason=count>]... [--compare-previous] [--previous-report-json <path>] [--allow-match-rate-drop-percent 0] [--allow-max-skew-increase-seconds 0] [--allow-trend-drift-count-increase <reason=count>]... [--max-capture-signatures <count>] [--allow-capture-signature <signature>]... [--max-unexpected-signatures <count>] [--max-fallback-timestamp-count <count>] [--max-unknown-event-rate-percent <percent>] [--init-capture-pack] [--allow-unmatched-serial] [--allow-unmatched-legacy] [--allow-mock-artifacts]

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
    --bench-baseline-json)
      BENCH_BASELINE_JSON="${2:-}"
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

baseline_json_get() {
  local file_path="$1"
  local key="$2"
  python3 - "$file_path" "$key" <<'PY'
import json
import sys

path = sys.argv[1]
key = sys.argv[2]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)
value = data.get(key, "")
if value is None:
    print("")
elif isinstance(value, list):
    for item in value:
        if item is not None:
            print(str(item))
else:
    print(str(value))
PY
}

if [[ -z "$BENCH_BASELINE_JSON" && -f "$CAPTURE_DIR/listener_bench_baseline.json" ]]; then
  BENCH_BASELINE_JSON="$CAPTURE_DIR/listener_bench_baseline.json"
fi

if [[ -n "$BENCH_BASELINE_JSON" ]]; then
  if [[ ! -f "$BENCH_BASELINE_JSON" ]]; then
    echo "FAIL: --bench-baseline-json must point to an existing JSON file."
    exit 1
  fi
  if [[ -z "$MAX_CAPTURE_SIGNATURES" ]]; then
    MAX_CAPTURE_SIGNATURES="$(baseline_json_get "$BENCH_BASELINE_JSON" "max_capture_signatures" | head -n 1)"
  fi
  if [[ ${#ALLOW_CAPTURE_SIGNATURES[@]} -eq 0 ]]; then
    while IFS= read -r signature; do
      [[ -n "$signature" ]] || continue
      ALLOW_CAPTURE_SIGNATURES+=("$signature")
    done < <(baseline_json_get "$BENCH_BASELINE_JSON" "allowed_capture_signatures")
  fi
  if [[ -z "$MAX_UNEXPECTED_SIGNATURES" ]]; then
    MAX_UNEXPECTED_SIGNATURES="$(baseline_json_get "$BENCH_BASELINE_JSON" "max_unexpected_signatures" | head -n 1)"
  fi
  if [[ -z "$MAX_FALLBACK_TIMESTAMP_COUNT" ]]; then
    MAX_FALLBACK_TIMESTAMP_COUNT="$(baseline_json_get "$BENCH_BASELINE_JSON" "max_fallback_timestamp_count" | head -n 1)"
  fi
  if [[ -z "$MAX_UNKNOWN_EVENT_RATE_PERCENT" ]]; then
    MAX_UNKNOWN_EVENT_RATE_PERCENT="$(baseline_json_get "$BENCH_BASELINE_JSON" "max_unknown_event_rate_percent" | head -n 1)"
  fi
fi

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
if [[ -n "$MAX_CAPTURE_SIGNATURES" ]] && ! [[ "$MAX_CAPTURE_SIGNATURES" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --max-capture-signatures must be a non-negative integer."
  exit 1
fi
if [[ -n "$MAX_UNEXPECTED_SIGNATURES" ]] && ! [[ "$MAX_UNEXPECTED_SIGNATURES" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --max-unexpected-signatures must be a non-negative integer."
  exit 1
fi
if [[ -n "$MAX_FALLBACK_TIMESTAMP_COUNT" ]] && ! [[ "$MAX_FALLBACK_TIMESTAMP_COUNT" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --max-fallback-timestamp-count must be a non-negative integer."
  exit 1
fi
if [[ -n "$MAX_UNKNOWN_EVENT_RATE_PERCENT" ]] && ! [[ "$MAX_UNKNOWN_EVENT_RATE_PERCENT" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "FAIL: --max-unknown-event-rate-percent must be a non-negative number."
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
echo "Bench baseline: ${BENCH_BASELINE_JSON:-<none>}"
echo "Max report age: ${MAX_REPORT_AGE_HOURS}h"
echo "Max skew: ${MAX_SKEW_SECONDS}s"
echo "Min match rate: ${MIN_MATCH_RATE_PERCENT}%"
echo "Max observed skew gate: ${MAX_OBSERVED_SKEW_SECONDS:-<disabled>}"
echo "Max capture signatures: ${MAX_CAPTURE_SIGNATURES:-<disabled>}"
if [[ -n "${ALLOW_CAPTURE_SIGNATURES[*]-}" ]]; then
  echo "Allowed capture signatures: ${ALLOW_CAPTURE_SIGNATURES[*]}"
fi
echo "Max unexpected signatures: ${MAX_UNEXPECTED_SIGNATURES:-<disabled>}"
echo "Max fallback timestamps: ${MAX_FALLBACK_TIMESTAMP_COUNT:-<disabled>}"
echo "Max unknown-event rate: ${MAX_UNKNOWN_EVENT_RATE_PERCENT:-<disabled>}%"
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

bench_cmd=(
  ./scripts/onyx_listener_serial_bench.sh
  --input "$CAPTURE_DIR/serial_raw.txt"
  --client-id "$CLIENT_ID"
  --region-id "$REGION_ID"
  --site-id "${SITE_ID:-SITE-SANDTON}"
  --out "$ARTIFACT_DIR/serial_parsed.json"
)
if [[ -n "$MAX_CAPTURE_SIGNATURES" ]]; then
  bench_cmd+=(--max-capture-signatures "$MAX_CAPTURE_SIGNATURES")
fi
for signature in "${ALLOW_CAPTURE_SIGNATURES[@]-}"; do
  [[ -n "$signature" ]] || continue
  bench_cmd+=(--allow-capture-signature "$signature")
done
if [[ -n "$MAX_UNEXPECTED_SIGNATURES" ]]; then
  bench_cmd+=(--max-unexpected-signatures "$MAX_UNEXPECTED_SIGNATURES")
fi
if [[ -n "$MAX_FALLBACK_TIMESTAMP_COUNT" ]]; then
  bench_cmd+=(--max-fallback-timestamp-count "$MAX_FALLBACK_TIMESTAMP_COUNT")
fi
if [[ -n "$MAX_UNKNOWN_EVENT_RATE_PERCENT" ]]; then
  bench_cmd+=(--max-unknown-event-rate-percent "$MAX_UNKNOWN_EVENT_RATE_PERCENT")
fi

"${bench_cmd[@]}"

./scripts/onyx_listener_parity_report.sh \
  --serial "$ARTIFACT_DIR/serial_parsed.json" \
  --legacy "$CAPTURE_DIR/legacy_events.json" \
  --max-skew-seconds "$MAX_SKEW_SECONDS" \
  --min-match-rate-percent "$MIN_MATCH_RATE_PERCENT" \
  --out "$ARTIFACT_DIR/report.json"

readiness_cmd=(
  ./scripts/onyx_listener_parity_readiness_check.sh
  --report-json "$ARTIFACT_DIR/report.json"
  --json-out "$ARTIFACT_DIR/parity_readiness_report.json"
  --markdown-out "$ARTIFACT_DIR/parity_readiness_report.md"
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

PARITY_STATUS=""
PARITY_PRIMARY_ISSUE_CODE=""
if [[ -f "$ARTIFACT_DIR/report.json" ]]; then
  PARITY_STATUS="$(
    python3 - "$ARTIFACT_DIR/report.json" <<'PY'
import json
import sys
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
print(str(data.get("status", "")).upper())
PY
  )"
  PARITY_PRIMARY_ISSUE_CODE="$(
    python3 - "$ARTIFACT_DIR/report.json" <<'PY'
import json
import sys
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
print(str(data.get("primary_issue_code", "")))
PY
  )"
fi

PARITY_READINESS_STATUS=""
PARITY_READINESS_FAILURE_CODE=""
if [[ -f "$ARTIFACT_DIR/parity_readiness_report.json" ]]; then
  PARITY_READINESS_STATUS="$(
    python3 - "$ARTIFACT_DIR/parity_readiness_report.json" <<'PY'
import json
import sys
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
print(str(data.get("status", "")).upper())
PY
  )"
  PARITY_READINESS_FAILURE_CODE="$(
    python3 - "$ARTIFACT_DIR/parity_readiness_report.json" <<'PY'
import json
import sys
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
print(str(data.get("failure_code", "")))
PY
  )"
fi

PARITY_TREND_STATUS=""
PARITY_TREND_PRIMARY_REGRESSION_CODE=""
if [[ -f "$ARTIFACT_DIR/trend_report.json" ]]; then
  PARITY_TREND_STATUS="$(
    python3 - "$ARTIFACT_DIR/trend_report.json" <<'PY'
import json
import sys
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
print(str(data.get("status", "")).upper())
PY
  )"
  PARITY_TREND_PRIMARY_REGRESSION_CODE="$(
    python3 - "$ARTIFACT_DIR/trend_report.json" <<'PY'
import json
import sys
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
print(str(data.get("primary_regression_code", "")))
PY
  )"
fi

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
if [[ -n "$PARITY_STATUS" ]]; then
  echo "Parity status: $PARITY_STATUS"
fi
if [[ -n "$PARITY_PRIMARY_ISSUE_CODE" ]]; then
  echo "Parity primary issue code: $PARITY_PRIMARY_ISSUE_CODE"
fi
if [[ -f "$ARTIFACT_DIR/parity_readiness_report.json" ]]; then
  echo "Parity readiness artifact: $ARTIFACT_DIR/parity_readiness_report.json"
  if [[ -n "$PARITY_READINESS_STATUS" ]]; then
    echo "Parity readiness status: $PARITY_READINESS_STATUS"
  fi
  if [[ -n "$PARITY_READINESS_FAILURE_CODE" ]]; then
    echo "Parity readiness failure code: $PARITY_READINESS_FAILURE_CODE"
  fi
fi
if [[ "$COMPARE_PREVIOUS" -eq 1 ]]; then
  echo "Trend artifact: $ARTIFACT_DIR/trend_report.json"
  if [[ -n "$PARITY_TREND_STATUS" ]]; then
    echo "Parity trend status: $PARITY_TREND_STATUS"
  fi
  if [[ -n "$PARITY_TREND_PRIMARY_REGRESSION_CODE" ]]; then
    echo "Parity trend primary regression code: $PARITY_TREND_PRIMARY_REGRESSION_CODE"
  fi
fi
