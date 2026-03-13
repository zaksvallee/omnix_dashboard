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
CURRENT_STAGE="argument_validation"
PILOT_GATE_REPORT_JSON=""
PILOT_GATE_REPORT_MD=""
BENCH_ANOMALY_STATUS=""
BENCH_PRIMARY_FAILURE_CODE=""
PARITY_STATUS=""
PARITY_PRIMARY_ISSUE_CODE=""
PARITY_READINESS_STATUS=""
PARITY_READINESS_FAILURE_CODE=""
PARITY_TREND_STATUS=""
PARITY_TREND_PRIMARY_REGRESSION_CODE=""

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
    if isinstance(value, dict):
        value = value.get(key, "")
    elif isinstance(value, list):
        try:
            value = value[int(key)]
        except Exception:
            value = ""
            break
    else:
        value = ""
        break
if isinstance(value, bool):
    print("true" if value else "false")
elif value is None:
    print("")
else:
    print(value)
PY
}

refresh_pilot_gate_state() {
  if [[ -f "$ARTIFACT_DIR/serial_parsed.json" ]]; then
    BENCH_ANOMALY_STATUS="$(json_get "$ARTIFACT_DIR/serial_parsed.json" "anomaly_gate.status" | tr '[:lower:]' '[:upper:]')"
    BENCH_PRIMARY_FAILURE_CODE="$(json_get "$ARTIFACT_DIR/serial_parsed.json" "anomaly_gate.failures.0.type")"
  fi

  if [[ -f "$ARTIFACT_DIR/report.json" ]]; then
    PARITY_STATUS="$(json_get "$ARTIFACT_DIR/report.json" "status" | tr '[:lower:]' '[:upper:]')"
    PARITY_PRIMARY_ISSUE_CODE="$(json_get "$ARTIFACT_DIR/report.json" "primary_issue_code")"
  fi

  if [[ -f "$ARTIFACT_DIR/parity_readiness_report.json" ]]; then
    PARITY_READINESS_STATUS="$(json_get "$ARTIFACT_DIR/parity_readiness_report.json" "status" | tr '[:lower:]' '[:upper:]')"
    PARITY_READINESS_FAILURE_CODE="$(json_get "$ARTIFACT_DIR/parity_readiness_report.json" "failure_code")"
  fi

  if [[ -f "$ARTIFACT_DIR/trend_report.json" ]]; then
    PARITY_TREND_STATUS="$(json_get "$ARTIFACT_DIR/trend_report.json" "status" | tr '[:lower:]' '[:upper:]')"
    PARITY_TREND_PRIMARY_REGRESSION_CODE="$(json_get "$ARTIFACT_DIR/trend_report.json" "primary_regression_code")"
  fi
}

write_pilot_gate_report() {
  local report_status="$1"
  local report_summary="$2"
  local report_failure_code="$3"

  mkdir -p "$(dirname "$PILOT_GATE_REPORT_JSON")"
  mkdir -p "$(dirname "$PILOT_GATE_REPORT_MD")"

  python3 - "$PILOT_GATE_REPORT_JSON" "$PILOT_GATE_REPORT_MD" "$report_status" "$report_summary" "$report_failure_code" "$CAPTURE_DIR" "$ARTIFACT_DIR" "$SITE_ID" "$DEVICE_PATH" "$LEGACY_SOURCE" "$CLIENT_ID" "$REGION_ID" "$COMPARE_PREVIOUS" "$ALLOW_MOCK_ARTIFACTS" "$MAX_REPORT_AGE_HOURS" "$MAX_SKEW_SECONDS" "$MIN_MATCH_RATE_PERCENT" "${MAX_OBSERVED_SKEW_SECONDS:-}" "${MAX_CAPTURE_SIGNATURES:-}" "${MAX_UNEXPECTED_SIGNATURES:-}" "${MAX_FALLBACK_TIMESTAMP_COUNT:-}" "${MAX_UNKNOWN_EVENT_RATE_PERCENT:-}" "${BENCH_ANOMALY_STATUS:-}" "${BENCH_PRIMARY_FAILURE_CODE:-}" "${PARITY_STATUS:-}" "${PARITY_PRIMARY_ISSUE_CODE:-}" "${PARITY_READINESS_STATUS:-}" "${PARITY_READINESS_FAILURE_CODE:-}" "${PARITY_TREND_STATUS:-}" "${PARITY_TREND_PRIMARY_REGRESSION_CODE:-}" <<'PY'
import json
import sys
from pathlib import Path

json_out = Path(sys.argv[1])
markdown_out = Path(sys.argv[2])
status = sys.argv[3]
summary = sys.argv[4]
failure_code = sys.argv[5]
capture_dir = sys.argv[6]
artifact_dir = sys.argv[7]
site_id = sys.argv[8]
device_path = sys.argv[9]
legacy_source = sys.argv[10]
client_id = sys.argv[11]
region_id = sys.argv[12]
compare_previous = sys.argv[13] == "1"
allow_mock_artifacts = sys.argv[14] == "1"
max_report_age_hours = sys.argv[15]
max_skew_seconds = sys.argv[16]
min_match_rate_percent = sys.argv[17]
max_observed_skew_seconds = sys.argv[18]
max_capture_signatures = sys.argv[19]
max_unexpected_signatures = sys.argv[20]
max_fallback_timestamp_count = sys.argv[21]
max_unknown_event_rate_percent = sys.argv[22]
bench_anomaly_status = sys.argv[23]
bench_primary_failure_code = sys.argv[24]
parity_status = sys.argv[25]
parity_primary_issue_code = sys.argv[26]
parity_readiness_status = sys.argv[27]
parity_readiness_failure_code = sys.argv[28]
parity_trend_status = sys.argv[29]
parity_trend_primary_regression_code = sys.argv[30]

artifact_dir_path = Path(artifact_dir)
files = {
    "serial_parsed_json": str(artifact_dir_path / "serial_parsed.json"),
    "parity_report_json": str(artifact_dir_path / "report.json"),
    "parity_report_markdown": str(artifact_dir_path / "report.md"),
    "parity_readiness_report_json": str(artifact_dir_path / "parity_readiness_report.json"),
    "parity_readiness_report_markdown": str(artifact_dir_path / "parity_readiness_report.md"),
    "trend_report_json": str(artifact_dir_path / "trend_report.json"),
    "trend_report_markdown": str(artifact_dir_path / "trend_report.md"),
    "markdown_report": str(markdown_out),
}

payload = {
    "status": status,
    "summary": summary,
    "failure_code": failure_code,
    "capture_dir": capture_dir,
    "artifact_dir": artifact_dir,
    "site_id": site_id,
    "device_path": device_path,
    "legacy_source": legacy_source,
    "client_id": client_id,
    "region_id": region_id,
    "compare_previous": compare_previous,
    "allow_mock_artifacts": allow_mock_artifacts,
    "requirements": {
        "max_report_age_hours": max_report_age_hours,
        "max_skew_seconds": max_skew_seconds,
        "min_match_rate_percent": min_match_rate_percent,
        "max_observed_skew_seconds": max_observed_skew_seconds,
        "max_capture_signatures": max_capture_signatures,
        "max_unexpected_signatures": max_unexpected_signatures,
        "max_fallback_timestamp_count": max_fallback_timestamp_count,
        "max_unknown_event_rate_percent": max_unknown_event_rate_percent,
    },
    "statuses": {
        "bench_anomaly_status": bench_anomaly_status,
        "bench_primary_failure_code": bench_primary_failure_code,
        "parity_status": parity_status,
        "parity_primary_issue_code": parity_primary_issue_code,
        "parity_readiness_status": parity_readiness_status,
        "parity_readiness_failure_code": parity_readiness_failure_code,
        "parity_trend_status": parity_trend_status,
        "parity_trend_primary_regression_code": parity_trend_primary_regression_code,
    },
    "files": files,
}

json_out.write_text(json.dumps(payload, indent=2), encoding="utf-8")

lines = [
    "# ONYX Listener Pilot Gate",
    "",
    f"- Status: `{status}`",
    f"- Summary: `{summary}`",
    f"- Failure code: `{failure_code or 'n/a'}`",
    f"- Capture dir: `{capture_dir}`",
    f"- Artifact dir: `{artifact_dir}`",
    f"- Site ID: `{site_id or 'n/a'}`",
    f"- Device path: `{device_path or 'n/a'}`",
    f"- Legacy source: `{legacy_source or 'n/a'}`",
    f"- Compare previous: `{'yes' if compare_previous else 'no'}`",
    "",
    "## Gate Status",
    f"- Bench anomaly: `{bench_anomaly_status or 'n/a'}`",
    f"- Bench primary failure code: `{bench_primary_failure_code or 'n/a'}`",
    f"- Parity: `{parity_status or 'n/a'}`",
    f"- Parity primary issue code: `{parity_primary_issue_code or 'n/a'}`",
    f"- Parity readiness: `{parity_readiness_status or 'n/a'}`",
    f"- Parity readiness failure code: `{parity_readiness_failure_code or 'n/a'}`",
    f"- Parity trend: `{parity_trend_status or 'n/a'}`",
    f"- Parity trend primary regression code: `{parity_trend_primary_regression_code or 'n/a'}`",
    "",
    "## Artifacts",
]

for label, path in [
    ("Serial parsed JSON", files["serial_parsed_json"]),
    ("Parity report JSON", files["parity_report_json"]),
    ("Parity report markdown", files["parity_report_markdown"]),
    ("Parity readiness JSON", files["parity_readiness_report_json"]),
    ("Parity readiness markdown", files["parity_readiness_report_markdown"]),
    ("Trend report JSON", files["trend_report_json"]),
    ("Trend report markdown", files["trend_report_markdown"]),
]:
    lines.append(f"- {label}: `{path if Path(path).exists() else 'missing'}`")

markdown_out.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

pilot_gate_exit_trap() {
  local exit_code=$?
  local report_status="PASS"
  local report_summary="Listener pilot gate passed."
  local report_failure_code=""

  if [[ -z "$PILOT_GATE_REPORT_JSON" || -z "$PILOT_GATE_REPORT_MD" ]]; then
    return "$exit_code"
  fi

  set +e
  refresh_pilot_gate_state

  if [[ "$exit_code" -ne 0 ]]; then
    report_status="FAIL"
    case "$CURRENT_STAGE" in
      capture_pack_init)
        report_failure_code="capture_pack_init_failed"
        report_summary="Listener capture-pack initialization failed."
        ;;
      serial_bench)
        report_failure_code="${BENCH_PRIMARY_FAILURE_CODE:-serial_bench_failed}"
        report_summary="Listener serial bench failed."
        ;;
      parity_report)
        report_failure_code="${PARITY_PRIMARY_ISSUE_CODE:-parity_report_failed}"
        report_summary="Listener parity report failed."
        ;;
      parity_readiness)
        report_failure_code="${PARITY_READINESS_FAILURE_CODE:-parity_readiness_failed}"
        report_summary="Listener parity readiness failed."
        ;;
      parity_trend)
        report_failure_code="${PARITY_TREND_PRIMARY_REGRESSION_CODE:-parity_trend_failed}"
        report_summary="Listener parity trend check failed."
        ;;
      *)
        report_failure_code="pilot_gate_failed"
        report_summary="Listener pilot gate failed."
        ;;
    esac
  elif [[ "$COMPARE_PREVIOUS" -eq 1 && -f "$ARTIFACT_DIR/trend_report.json" ]]; then
    report_summary="Listener pilot gate passed with parity trend comparison."
  fi

  write_pilot_gate_report "$report_status" "$report_summary" "$report_failure_code" || true
  set -e
  return "$exit_code"
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
PILOT_GATE_REPORT_JSON="$ARTIFACT_DIR/pilot_gate_report.json"
PILOT_GATE_REPORT_MD="$ARTIFACT_DIR/pilot_gate_report.md"
trap pilot_gate_exit_trap EXIT

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
  CURRENT_STAGE="capture_pack_init"
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

CURRENT_STAGE="serial_bench"
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

CURRENT_STAGE="parity_report"
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

CURRENT_STAGE="parity_readiness"
"${readiness_cmd[@]}"
refresh_pilot_gate_state

if [[ "$COMPARE_PREVIOUS" -eq 1 ]]; then
  CURRENT_STAGE="parity_trend"
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
  refresh_pilot_gate_state
fi

CURRENT_STAGE="completed"

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
echo "Pilot gate artifact: $PILOT_GATE_REPORT_JSON"
