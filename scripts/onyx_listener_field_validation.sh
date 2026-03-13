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
JSON_OUT_FILE=""
BENCH_BASELINE_JSON=""
PREVIOUS_REPORT_JSON=""
COMPARE_PREVIOUS=0
ALLOW_MOCK_ARTIFACTS=0
MIN_MATCH_RATE_PERCENT=95
MAX_SKEW_SECONDS=90
MAX_OBSERVED_SKEW_SECONDS=""
ALLOW_DRIFT_REASONS=()
MAX_DRIFT_REASON_COUNTS=()
ALLOW_MATCH_RATE_DROP_PERCENT=0
ALLOW_MAX_SKEW_INCREASE_SECONDS=0
ALLOW_TREND_DRIFT_COUNT_INCREASES=()
MAX_CAPTURE_SIGNATURES=""
ALLOW_CAPTURE_SIGNATURES=()
MAX_UNEXPECTED_SIGNATURES=""
MAX_FALLBACK_TIMESTAMP_COUNT=""
MAX_UNKNOWN_EVENT_RATE_PERCENT=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_field_validation.sh [--capture-dir <path>] [--site-id <site_id>] [--device-path <tty>] [--legacy-source <label>] [--client-id <id>] [--region-id <id>] [--artifact-dir <path>] [--json-out <path>] [--bench-baseline-json <path>] [--min-match-rate-percent 95] [--max-skew-seconds 90] [--max-observed-skew-seconds <n>] [--allow-drift-reason <reason>]... [--max-drift-reason-count <reason=count>]... [--compare-previous] [--previous-report-json <path>] [--allow-match-rate-drop-percent 0] [--allow-max-skew-increase-seconds 0] [--allow-trend-drift-count-increase <reason=count>]... [--max-capture-signatures <count>] [--allow-capture-signature <signature>]... [--max-unexpected-signatures <count>] [--max-fallback-timestamp-count <count>] [--max-unknown-event-rate-percent <percent>] [--allow-mock-artifacts]

Purpose:
  Validate one listener dual-path pilot capture pack, stage the evidence into a
  self-contained artifact bundle, and write markdown + JSON validation reports
  under tmp/listener_field_validation/.
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
    --json-out)
      JSON_OUT_FILE="${2:-}"
      shift 2
      ;;
    --bench-baseline-json)
      BENCH_BASELINE_JSON="${2:-}"
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
    --allow-mock-artifacts)
      ALLOW_MOCK_ARTIFACTS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "FAIL: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$BENCH_BASELINE_JSON" && -f "$CAPTURE_DIR/listener_bench_baseline.json" ]]; then
  BENCH_BASELINE_JSON="$CAPTURE_DIR/listener_bench_baseline.json"
fi

if [[ -z "$ARTIFACT_DIR" ]]; then
  ARTIFACT_DIR="tmp/listener_field_validation/$(date -u +%Y%m%dT%H%M%SZ)"
fi
mkdir -p "$ARTIFACT_DIR"

if [[ -z "$JSON_OUT_FILE" ]]; then
  JSON_OUT_FILE="$ARTIFACT_DIR/validation_report.json"
fi

lower() {
  printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'
}

contains_ci() {
  local haystack="${1:-}"
  local needle="${2:-}"
  if [[ -z "$needle" ]]; then
    return 0
  fi
  [[ "$(lower "$haystack")" == *"$(lower "$needle")"* ]]
}

sha256_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo ""
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
    return 0
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
    return 0
  fi
  python3 - "$file" <<'PY'
import hashlib
import sys
with open(sys.argv[1], 'rb') as handle:
    print(hashlib.sha256(handle.read()).hexdigest())
PY
}

json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
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

json_array_from_bash_array() {
  python3 - "$@" <<'PY'
import json
import sys
print(json.dumps(sys.argv[1:]))
PY
}

write_baseline_review_json() {
  local serial_report="${1:-}"
  local baseline_file="${2:-}"
  local out_file="${3:-}"
  python3 - "$serial_report" "$baseline_file" "$out_file" <<'PY'
import json
import sys

serial_report = sys.argv[1]
baseline_file = sys.argv[2]
out_file = sys.argv[3]

review = {
    "status": "WARN",
    "recommendation": "hold_baseline",
    "summary": "Baseline review not available.",
    "bench_anomaly_status": "",
    "observed_signatures": [],
    "baseline_signatures": [],
    "effective_allowed_signatures": [],
    "new_observed_signatures": [],
    "missing_baseline_signatures": [],
    "effective_nonbaseline_signatures": [],
}

if not serial_report:
    review["status"] = "FAIL"
    review["recommendation"] = "investigate_new_frame_shape"
    review["summary"] = "Serial parsed artifact is missing; baseline review cannot run."
else:
    with open(serial_report, "r", encoding="utf-8") as handle:
        serial_data = json.load(handle)
    stats = serial_data.get("stats", {})
    anomaly_gate = serial_data.get("anomaly_gate", {})
    observed_signatures = sorted((stats.get("capture_signature_counts") or {}).keys())
    effective_allowed_signatures = sorted(
        set((anomaly_gate.get("thresholds", {}) or {}).get("allowed_capture_signatures") or [])
    )
    bench_anomaly_status = str(anomaly_gate.get("status", "")).upper()
    review["bench_anomaly_status"] = bench_anomaly_status
    review["observed_signatures"] = observed_signatures
    review["effective_allowed_signatures"] = effective_allowed_signatures

    baseline_signatures = []
    if baseline_file:
        with open(baseline_file, "r", encoding="utf-8") as handle:
            baseline_data = json.load(handle)
        baseline_signatures = sorted(
            set((baseline_data.get("allowed_capture_signatures") or []))
        )
    review["baseline_signatures"] = baseline_signatures

    observed_set = set(observed_signatures)
    baseline_set = set(baseline_signatures)
    effective_set = set(effective_allowed_signatures)

    new_observed_signatures = sorted(observed_set - baseline_set)
    missing_baseline_signatures = sorted(baseline_set - observed_set)
    effective_nonbaseline_signatures = sorted(effective_set - baseline_set)
    review["new_observed_signatures"] = new_observed_signatures
    review["missing_baseline_signatures"] = missing_baseline_signatures
    review["effective_nonbaseline_signatures"] = effective_nonbaseline_signatures

    if bench_anomaly_status != "PASS":
        review["status"] = "FAIL"
        review["recommendation"] = "investigate_new_frame_shape"
        review["summary"] = (
            "Bench anomaly gate did not pass; investigate the observed serial frame shapes before updating the baseline."
        )
    elif not baseline_file:
        review["status"] = "WARN"
        review["recommendation"] = "promote_baseline"
        review["summary"] = (
            "No persisted listener bench baseline was provided; promote the observed clean signatures into a baseline before the next pilot run."
        )
    elif not baseline_signatures and observed_signatures:
        review["status"] = "WARN"
        review["recommendation"] = "promote_baseline"
        review["summary"] = (
            "Baseline file has no approved signatures; promote the observed clean signatures into listener_bench_baseline.json."
        )
    elif new_observed_signatures:
        review["status"] = "WARN"
        review["recommendation"] = "promote_baseline"
        review["summary"] = (
            "Observed signatures passed the bench gate but extend beyond the persisted baseline; review and promote them if they are expected."
        )
    else:
        review["status"] = "PASS"
        review["recommendation"] = "hold_baseline"
        if missing_baseline_signatures:
            review["summary"] = (
                "Observed signatures remain within the persisted baseline; hold the baseline and continue monitoring unused signature variants."
            )
        else:
            review["summary"] = (
                "Observed signatures match the persisted baseline; hold the current baseline."
            )

with open(out_file, "w", encoding="utf-8") as handle:
    json.dump(review, handle, indent=2)
PY
}

write_baseline_health_json() {
  local baseline_file="${1:-}"
  local out_file="${2:-}"
  python3 - "$baseline_file" "$out_file" <<'PY'
import json
import time
from datetime import datetime, timezone
import sys

baseline_file = sys.argv[1]
out_file = sys.argv[2]
warning_age_days = 30.0

health = {
    "status": "WARN",
    "category": "missing_baseline",
    "summary": "Listener bench baseline file is not available.",
    "advisory_max_age_days": warning_age_days,
    "baseline_file_present": False,
    "history_present": False,
    "last_promoted_at_utc": "",
    "age_days": None,
}

if baseline_file:
    try:
        with open(baseline_file, "r", encoding="utf-8") as handle:
            baseline = json.load(handle)
        health["baseline_file_present"] = True
        history = baseline.get("promotion_history")
        if not isinstance(history, list) or len(history) == 0:
            health["status"] = "WARN"
            health["category"] = "missing_history"
            health["summary"] = (
                "Listener bench baseline is present but has no promotion history yet."
            )
        else:
            health["history_present"] = True
            last_promoted = str(baseline.get("last_promoted_at_utc") or history[-1].get("promoted_at_utc") or "").strip()
            health["last_promoted_at_utc"] = last_promoted
            try:
                promoted_at = datetime.fromisoformat(last_promoted.replace("Z", "+00:00"))
                if promoted_at.tzinfo is None:
                    promoted_at = promoted_at.replace(tzinfo=timezone.utc)
                promoted_at = promoted_at.astimezone(timezone.utc)
                age_days = round(max((time.time() - promoted_at.timestamp()) / 86400.0, 0.0), 2)
                health["age_days"] = age_days
                if age_days > warning_age_days:
                    health["status"] = "WARN"
                    health["category"] = "stale"
                    health["summary"] = (
                        f"Listener bench baseline promotion is stale ({age_days}d old > {warning_age_days}d advisory window)."
                    )
                else:
                    health["status"] = "PASS"
                    health["category"] = "fresh"
                    health["summary"] = (
                        f"Listener bench baseline history is present and fresh ({age_days}d old)."
                    )
            except ValueError:
                health["status"] = "WARN"
                health["category"] = "invalid_timestamp"
                health["summary"] = (
                    "Listener bench baseline has promotion history but last_promoted_at_utc is invalid."
                )
    except FileNotFoundError:
        pass

with open(out_file, "w", encoding="utf-8") as handle:
    json.dump(health, handle, indent=2)
PY
}

stage_optional_file() {
  local source_path="${1:-}"
  local target_name="${2:-}"
  if [[ -z "$source_path" || ! -f "$source_path" || -z "$target_name" ]]; then
    return 1
  fi
  local target_path="$ARTIFACT_DIR/$target_name"
  if [[ "$source_path" != "$target_path" ]]; then
    cp "$source_path" "$target_path"
  fi
  printf '%s\n' "$target_path"
  return 0
}

SERIAL_FILE="$CAPTURE_DIR/serial_raw.txt"
LEGACY_FILE="$CAPTURE_DIR/legacy_events.json"
FIELD_NOTES_FILE="$CAPTURE_DIR/field_notes.md"

SERIAL_CAPTURE_STATUS="WARN"
SERIAL_CAPTURE_MESSAGE="Serial capture file not found."
LEGACY_CAPTURE_STATUS="WARN"
LEGACY_CAPTURE_MESSAGE="Legacy events file not found."
FIELD_NOTES_STATUS="WARN"
FIELD_NOTES_MESSAGE="Field notes file not found."
WIRING_STATUS="WARN"
WIRING_MESSAGE="Field notes did not document read-only wiring."
BENCH_ANOMALY_STATUS="WARN"
BENCH_ANOMALY_MESSAGE="Listener serial bench anomaly gate not run."
PARITY_STATUS="WARN"
PARITY_MESSAGE="Listener pilot gate not run."
TREND_STATUS="WARN"
TREND_MESSAGE="Trend comparison not requested."
OVERALL_STATUS="INCOMPLETE"

if [[ -f "$SERIAL_FILE" ]]; then
  SERIAL_CAPTURE_STATUS="PASS"
  SERIAL_CAPTURE_MESSAGE="Serial raw capture is present."
fi
if [[ -f "$LEGACY_FILE" ]]; then
  LEGACY_CAPTURE_STATUS="PASS"
  LEGACY_CAPTURE_MESSAGE="Legacy events export is present."
fi
if [[ -f "$FIELD_NOTES_FILE" ]]; then
  FIELD_NOTES_STATUS="PASS"
  FIELD_NOTES_MESSAGE="Field notes are present."
  FIELD_NOTES_CONTENT="$(cat "$FIELD_NOTES_FILE")"
  has_gnd=0
  has_rx=0
  has_tx_disconnected=0
  has_vcc_disconnected=0
  contains_ci "$FIELD_NOTES_CONTENT" "gnd connected" && has_gnd=1
  contains_ci "$FIELD_NOTES_CONTENT" "rx connected" && has_rx=1
  contains_ci "$FIELD_NOTES_CONTENT" "tx disconnected" && has_tx_disconnected=1
  contains_ci "$FIELD_NOTES_CONTENT" "vcc disconnected" && has_vcc_disconnected=1
  if [[ "$has_gnd" -eq 1 && "$has_rx" -eq 1 && "$has_tx_disconnected" -eq 1 && "$has_vcc_disconnected" -eq 1 ]]; then
    WIRING_STATUS="PASS"
    WIRING_MESSAGE="Field notes document read-only wiring (GND/RX only, TX/VCC disconnected)."
  else
    WIRING_STATUS="FAIL"
    WIRING_MESSAGE="Field notes are missing one or more read-only wiring markers (GND connected, RX connected, TX disconnected, VCC disconnected)."
  fi
fi

PILOT_ARTIFACT_DIR="$ARTIFACT_DIR/pilot_artifact"
mkdir -p "$PILOT_ARTIFACT_DIR"
PILOT_OUTPUT_FILE="$ARTIFACT_DIR/pilot_gate_output.txt"
pilot_cmd=(
  ./scripts/onyx_listener_pilot_gate.sh
  --capture-dir "$CAPTURE_DIR"
  --client-id "$CLIENT_ID"
  --region-id "$REGION_ID"
  --artifact-dir "$PILOT_ARTIFACT_DIR"
  --min-match-rate-percent "$MIN_MATCH_RATE_PERCENT"
  --max-skew-seconds "$MAX_SKEW_SECONDS"
)
if [[ -n "$SITE_ID" ]]; then
  pilot_cmd+=(--site-id "$SITE_ID")
fi
if [[ -n "$BENCH_BASELINE_JSON" ]]; then
  pilot_cmd+=(--bench-baseline-json "$BENCH_BASELINE_JSON")
fi
if [[ -n "$DEVICE_PATH" ]]; then
  pilot_cmd+=(--device-path "$DEVICE_PATH")
fi
if [[ -n "$LEGACY_SOURCE" ]]; then
  pilot_cmd+=(--legacy-source "$LEGACY_SOURCE")
fi
if [[ -n "$MAX_OBSERVED_SKEW_SECONDS" ]]; then
  pilot_cmd+=(--max-observed-skew-seconds "$MAX_OBSERVED_SKEW_SECONDS")
fi
for allow_reason in "${ALLOW_DRIFT_REASONS[@]-}"; do
  [[ -n "$allow_reason" ]] || continue
  pilot_cmd+=(--allow-drift-reason "$allow_reason")
done
for drift_cap in "${MAX_DRIFT_REASON_COUNTS[@]-}"; do
  [[ -n "$drift_cap" ]] || continue
  pilot_cmd+=(--max-drift-reason-count "$drift_cap")
done
if [[ "$COMPARE_PREVIOUS" -eq 1 ]]; then
  pilot_cmd+=(--compare-previous)
fi
if [[ -n "$PREVIOUS_REPORT_JSON" ]]; then
  pilot_cmd+=(--previous-report-json "$PREVIOUS_REPORT_JSON")
fi
pilot_cmd+=(--allow-match-rate-drop-percent "$ALLOW_MATCH_RATE_DROP_PERCENT")
pilot_cmd+=(--allow-max-skew-increase-seconds "$ALLOW_MAX_SKEW_INCREASE_SECONDS")
for trend_cap in "${ALLOW_TREND_DRIFT_COUNT_INCREASES[@]-}"; do
  [[ -n "$trend_cap" ]] || continue
  pilot_cmd+=(--allow-trend-drift-count-increase "$trend_cap")
done
if [[ -n "$MAX_CAPTURE_SIGNATURES" ]]; then
  pilot_cmd+=(--max-capture-signatures "$MAX_CAPTURE_SIGNATURES")
fi
for signature in "${ALLOW_CAPTURE_SIGNATURES[@]-}"; do
  [[ -n "$signature" ]] || continue
  pilot_cmd+=(--allow-capture-signature "$signature")
done
if [[ -n "$MAX_UNEXPECTED_SIGNATURES" ]]; then
  pilot_cmd+=(--max-unexpected-signatures "$MAX_UNEXPECTED_SIGNATURES")
fi
if [[ -n "$MAX_FALLBACK_TIMESTAMP_COUNT" ]]; then
  pilot_cmd+=(--max-fallback-timestamp-count "$MAX_FALLBACK_TIMESTAMP_COUNT")
fi
if [[ -n "$MAX_UNKNOWN_EVENT_RATE_PERCENT" ]]; then
  pilot_cmd+=(--max-unknown-event-rate-percent "$MAX_UNKNOWN_EVENT_RATE_PERCENT")
fi
if [[ "$ALLOW_MOCK_ARTIFACTS" -eq 1 ]]; then
  pilot_cmd+=(--allow-mock-artifacts)
fi

if PILOT_OUTPUT="$("${pilot_cmd[@]}" 2>&1)"; then
  PARITY_STATUS="PASS"
  PARITY_MESSAGE="Listener pilot gate passed."
else
  PARITY_STATUS="FAIL"
  PARITY_MESSAGE="$(printf '%s' "$PILOT_OUTPUT" | tail -n 1)"
fi
printf '%s\n' "$PILOT_OUTPUT" >"$PILOT_OUTPUT_FILE"

PARITY_REPORT_JSON="$PILOT_ARTIFACT_DIR/report.json"
PARITY_REPORT_MD="$PILOT_ARTIFACT_DIR/report.md"
PARITY_READINESS_REPORT_JSON="$PILOT_ARTIFACT_DIR/parity_readiness_report.json"
PARITY_READINESS_REPORT_MD="$PILOT_ARTIFACT_DIR/parity_readiness_report.md"
TREND_REPORT_JSON="$PILOT_ARTIFACT_DIR/trend_report.json"
TREND_REPORT_MD="$PILOT_ARTIFACT_DIR/trend_report.md"
SERIAL_PARSED_JSON="$PILOT_ARTIFACT_DIR/serial_parsed.json"

if [[ -f "$SERIAL_PARSED_JSON" ]]; then
  bench_state="$(json_get "$SERIAL_PARSED_JSON" "anomaly_gate.status" | tr '[:lower:]' '[:upper:]')"
  if [[ "$bench_state" == "PASS" ]]; then
    BENCH_ANOMALY_STATUS="PASS"
    BENCH_ANOMALY_MESSAGE="Listener serial bench anomaly gate passed."
  else
    BENCH_ANOMALY_STATUS="FAIL"
    BENCH_ANOMALY_MESSAGE="Listener serial bench anomaly gate did not pass (${bench_state:-missing})."
  fi
else
  BENCH_ANOMALY_STATUS="FAIL"
  BENCH_ANOMALY_MESSAGE="Listener serial bench artifact was not generated."
fi

if [[ "$COMPARE_PREVIOUS" -eq 1 ]]; then
  if [[ -f "$TREND_REPORT_JSON" ]]; then
    trend_state="$(json_get "$TREND_REPORT_JSON" "status" | tr '[:lower:]' '[:upper:]')"
    if [[ "$trend_state" == "PASS" ]]; then
      TREND_STATUS="PASS"
      TREND_MESSAGE="Trend comparison passed."
    else
      TREND_STATUS="FAIL"
      TREND_MESSAGE="Trend comparison did not pass (${trend_state:-missing})."
    fi
  else
    TREND_STATUS="FAIL"
    TREND_MESSAGE="Trend comparison requested but no trend report was generated."
  fi
else
  TREND_STATUS="SKIP"
  TREND_MESSAGE="Trend comparison not requested."
fi

if [[ "$SERIAL_CAPTURE_STATUS" == "PASS" && "$LEGACY_CAPTURE_STATUS" == "PASS" && "$FIELD_NOTES_STATUS" == "PASS" && "$WIRING_STATUS" == "PASS" && "$BENCH_ANOMALY_STATUS" == "PASS" && "$PARITY_STATUS" == "PASS" ]]; then
  if [[ "$COMPARE_PREVIOUS" -eq 1 ]]; then
    if [[ "$TREND_STATUS" == "PASS" ]]; then
      OVERALL_STATUS="PASS"
    else
      OVERALL_STATUS="FAIL"
    fi
  else
    OVERALL_STATUS="PASS"
  fi
elif [[ "$BENCH_ANOMALY_STATUS" == "FAIL" || "$PARITY_STATUS" == "FAIL" || "$WIRING_STATUS" == "FAIL" || "$TREND_STATUS" == "FAIL" ]]; then
  OVERALL_STATUS="FAIL"
else
  OVERALL_STATUS="INCOMPLETE"
fi

STAGED_SERIAL_FILE="$(stage_optional_file "$SERIAL_FILE" "serial_raw.txt" || true)"
STAGED_SERIAL_PARSED_JSON="$(stage_optional_file "$SERIAL_PARSED_JSON" "serial_parsed.json" || true)"
STAGED_BENCH_BASELINE_JSON="$(stage_optional_file "$BENCH_BASELINE_JSON" "listener_bench_baseline.json" || true)"
STAGED_LEGACY_FILE="$(stage_optional_file "$LEGACY_FILE" "legacy_events.json" || true)"
STAGED_FIELD_NOTES_FILE="$(stage_optional_file "$FIELD_NOTES_FILE" "field_notes.md" || true)"
STAGED_PARITY_REPORT_JSON="$(stage_optional_file "$PARITY_REPORT_JSON" "report.json" || true)"
STAGED_PARITY_REPORT_MD="$(stage_optional_file "$PARITY_REPORT_MD" "report.md" || true)"
STAGED_PARITY_READINESS_REPORT_JSON="$(stage_optional_file "$PARITY_READINESS_REPORT_JSON" "parity_readiness_report.json" || true)"
STAGED_PARITY_READINESS_REPORT_MD="$(stage_optional_file "$PARITY_READINESS_REPORT_MD" "parity_readiness_report.md" || true)"
STAGED_TREND_REPORT_JSON="$(stage_optional_file "$TREND_REPORT_JSON" "trend_report.json" || true)"
STAGED_TREND_REPORT_MD="$(stage_optional_file "$TREND_REPORT_MD" "trend_report.md" || true)"
STAGED_PILOT_GATE_REPORT_JSON="$(stage_optional_file "$PILOT_ARTIFACT_DIR/pilot_gate_report.json" "pilot_gate_report.json" || true)"
STAGED_PILOT_GATE_REPORT_MD="$(stage_optional_file "$PILOT_ARTIFACT_DIR/pilot_gate_report.md" "pilot_gate_report.md" || true)"
STAGED_PILOT_OUTPUT_FILE="$(stage_optional_file "$PILOT_OUTPUT_FILE" "pilot_gate_output.txt" || true)"

BASELINE_REVIEW_JSON="$ARTIFACT_DIR/baseline_review.json"
write_baseline_review_json \
  "$STAGED_SERIAL_PARSED_JSON" \
  "$STAGED_BENCH_BASELINE_JSON" \
  "$BASELINE_REVIEW_JSON"
BASELINE_REVIEW_STATUS="$(json_get "$BASELINE_REVIEW_JSON" "status" | tr '[:lower:]' '[:upper:]')"
BASELINE_REVIEW_RECOMMENDATION="$(json_get "$BASELINE_REVIEW_JSON" "recommendation")"
BASELINE_REVIEW_SUMMARY="$(json_get "$BASELINE_REVIEW_JSON" "summary")"
BASELINE_REVIEW_BENCH_STATUS="$(json_get "$BASELINE_REVIEW_JSON" "bench_anomaly_status")"
STAGED_BASELINE_REVIEW_JSON="$(stage_optional_file "$BASELINE_REVIEW_JSON" "baseline_review.json" || true)"

BASELINE_HEALTH_JSON="$ARTIFACT_DIR/baseline_health.json"
write_baseline_health_json \
  "$STAGED_BENCH_BASELINE_JSON" \
  "$BASELINE_HEALTH_JSON"
BASELINE_HEALTH_STATUS="$(json_get "$BASELINE_HEALTH_JSON" "status" | tr '[:lower:]' '[:upper:]')"
BASELINE_HEALTH_CATEGORY="$(json_get "$BASELINE_HEALTH_JSON" "category")"
BASELINE_HEALTH_SUMMARY="$(json_get "$BASELINE_HEALTH_JSON" "summary")"
BASELINE_HEALTH_AGE_DAYS="$(json_get "$BASELINE_HEALTH_JSON" "age_days")"
STAGED_BASELINE_HEALTH_JSON="$(stage_optional_file "$BASELINE_HEALTH_JSON" "baseline_health.json" || true)"

VALIDATION_FAILURE_CODES=()
VALIDATION_WARNING_CODES=()

if [[ "$SERIAL_CAPTURE_STATUS" != "PASS" ]]; then
  VALIDATION_WARNING_CODES+=("serial_capture_missing")
fi
if [[ "$LEGACY_CAPTURE_STATUS" != "PASS" ]]; then
  VALIDATION_WARNING_CODES+=("legacy_capture_missing")
fi
if [[ "$FIELD_NOTES_STATUS" != "PASS" ]]; then
  VALIDATION_WARNING_CODES+=("field_notes_missing")
fi
if [[ "$WIRING_STATUS" != "PASS" ]]; then
  VALIDATION_FAILURE_CODES+=("read_only_wiring_not_documented")
fi
if [[ "$BENCH_ANOMALY_STATUS" != "PASS" ]]; then
  VALIDATION_FAILURE_CODES+=("bench_anomaly_gate_not_pass")
fi
if [[ "$PARITY_STATUS" != "PASS" ]]; then
  VALIDATION_FAILURE_CODES+=("parity_gate_not_pass")
fi
if [[ "$COMPARE_PREVIOUS" -eq 1 && "$TREND_STATUS" != "PASS" ]]; then
  VALIDATION_FAILURE_CODES+=("trend_gate_not_pass")
fi

case "$BASELINE_REVIEW_RECOMMENDATION" in
  investigate_new_frame_shape)
    VALIDATION_FAILURE_CODES+=("baseline_review_investigate_new_frame_shape")
    ;;
  promote_baseline)
    VALIDATION_WARNING_CODES+=("baseline_review_promote_baseline")
    ;;
esac

case "$BASELINE_HEALTH_CATEGORY" in
  stale)
    VALIDATION_WARNING_CODES+=("baseline_health_stale")
    ;;
  missing_history)
    VALIDATION_WARNING_CODES+=("baseline_health_missing_history")
    ;;
  invalid_timestamp)
    VALIDATION_WARNING_CODES+=("baseline_health_invalid_timestamp")
    ;;
  missing_baseline)
    VALIDATION_WARNING_CODES+=("baseline_health_missing_baseline")
    ;;
esac

PRIMARY_VALIDATION_FAILURE_CODE="${VALIDATION_FAILURE_CODES[0]-}"
PRIMARY_VALIDATION_WARNING_CODE="${VALIDATION_WARNING_CODES[0]-}"
VALIDATION_FAILURE_CODES_JSON="$(json_array_from_bash_array "${VALIDATION_FAILURE_CODES[@]-}")"
VALIDATION_WARNING_CODES_JSON="$(json_array_from_bash_array "${VALIDATION_WARNING_CODES[@]-}")"

VALIDATION_REPORT_MD="$ARTIFACT_DIR/validation_report.md"

{
  echo "# ONYX Listener Field Validation"
  echo
  echo "- Generated (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- Overall status: \`${OVERALL_STATUS}\`"
  echo "- Primary failure code: \`${PRIMARY_VALIDATION_FAILURE_CODE:-}\`"
  echo "- Primary warning code: \`${PRIMARY_VALIDATION_WARNING_CODE:-}\`"
  echo "- Capture dir: \`${CAPTURE_DIR}\`"
  echo "- Site ID: \`${SITE_ID:-}\`"
  echo "- Device path: \`${DEVICE_PATH:-}\`"
  echo "- Legacy source: \`${LEGACY_SOURCE:-}\`"
  echo "- Bench baseline: \`${BENCH_BASELINE_JSON:-}\`"
  echo "- Compare previous: \`$([[ "$COMPARE_PREVIOUS" -eq 1 ]] && echo yes || echo no)\`"
  echo
  echo "## Gates"
  echo "- Serial capture: \`${SERIAL_CAPTURE_STATUS}\` - ${SERIAL_CAPTURE_MESSAGE}"
  echo "- Legacy capture: \`${LEGACY_CAPTURE_STATUS}\` - ${LEGACY_CAPTURE_MESSAGE}"
  echo "- Field notes: \`${FIELD_NOTES_STATUS}\` - ${FIELD_NOTES_MESSAGE}"
  echo "- Read-only wiring: \`${WIRING_STATUS}\` - ${WIRING_MESSAGE}"
  echo "- Bench anomaly gate: \`${BENCH_ANOMALY_STATUS}\` - ${BENCH_ANOMALY_MESSAGE}"
  echo "- Parity gate: \`${PARITY_STATUS}\` - ${PARITY_MESSAGE}"
  echo "- Trend gate: \`${TREND_STATUS}\` - ${TREND_MESSAGE}"
  echo
  echo "## Validation Codes"
  if [[ ${#VALIDATION_FAILURE_CODES[@]} -gt 0 ]]; then
    echo "- Failure codes: \`${VALIDATION_FAILURE_CODES[*]}\`"
  else
    echo "- Failure codes: \`none\`"
  fi
  if [[ ${#VALIDATION_WARNING_CODES[@]} -gt 0 ]]; then
    echo "- Warning codes: \`${VALIDATION_WARNING_CODES[*]}\`"
  else
    echo "- Warning codes: \`none\`"
  fi
  echo
  echo "## Baseline Review"
  echo "- Status: \`${BASELINE_REVIEW_STATUS}\`"
  echo "- Recommendation: \`${BASELINE_REVIEW_RECOMMENDATION}\`"
  echo "- Bench anomaly status: \`${BASELINE_REVIEW_BENCH_STATUS:-unknown}\`"
  echo "- Summary: ${BASELINE_REVIEW_SUMMARY}"
  echo
  echo "## Baseline Health"
  echo "- Status: \`${BASELINE_HEALTH_STATUS}\`"
  echo "- Category: \`${BASELINE_HEALTH_CATEGORY}\`"
  [[ -n "$BASELINE_HEALTH_AGE_DAYS" ]] && echo "- Age (days): \`${BASELINE_HEALTH_AGE_DAYS}\`"
  echo "- Summary: ${BASELINE_HEALTH_SUMMARY}"
  echo
  echo "## Artifacts"
  [[ -n "$STAGED_SERIAL_FILE" ]] && echo "- Serial raw: \`${STAGED_SERIAL_FILE}\`"
  [[ -n "$STAGED_SERIAL_PARSED_JSON" ]] && echo "- Serial parsed JSON: \`${STAGED_SERIAL_PARSED_JSON}\`"
  [[ -n "$STAGED_BENCH_BASELINE_JSON" ]] && echo "- Bench baseline JSON: \`${STAGED_BENCH_BASELINE_JSON}\`"
  [[ -n "$STAGED_BASELINE_REVIEW_JSON" ]] && echo "- Baseline review JSON: \`${STAGED_BASELINE_REVIEW_JSON}\`"
  [[ -n "$STAGED_BASELINE_HEALTH_JSON" ]] && echo "- Baseline health JSON: \`${STAGED_BASELINE_HEALTH_JSON}\`"
  [[ -n "$STAGED_LEGACY_FILE" ]] && echo "- Legacy events: \`${STAGED_LEGACY_FILE}\`"
  [[ -n "$STAGED_FIELD_NOTES_FILE" ]] && echo "- Field notes: \`${STAGED_FIELD_NOTES_FILE}\`"
  [[ -n "$STAGED_PARITY_REPORT_JSON" ]] && echo "- Parity report JSON: \`${STAGED_PARITY_REPORT_JSON}\`"
  [[ -n "$STAGED_PARITY_REPORT_MD" ]] && echo "- Parity report markdown: \`${STAGED_PARITY_REPORT_MD}\`"
  [[ -n "$STAGED_PARITY_READINESS_REPORT_JSON" ]] && echo "- Parity readiness JSON: \`${STAGED_PARITY_READINESS_REPORT_JSON}\`"
  [[ -n "$STAGED_PARITY_READINESS_REPORT_MD" ]] && echo "- Parity readiness markdown: \`${STAGED_PARITY_READINESS_REPORT_MD}\`"
  [[ -n "$STAGED_TREND_REPORT_JSON" ]] && echo "- Trend report JSON: \`${STAGED_TREND_REPORT_JSON}\`"
  [[ -n "$STAGED_TREND_REPORT_MD" ]] && echo "- Trend report markdown: \`${STAGED_TREND_REPORT_MD}\`"
  [[ -n "$STAGED_PILOT_GATE_REPORT_JSON" ]] && echo "- Pilot gate report JSON: \`${STAGED_PILOT_GATE_REPORT_JSON}\`"
  [[ -n "$STAGED_PILOT_GATE_REPORT_MD" ]] && echo "- Pilot gate report markdown: \`${STAGED_PILOT_GATE_REPORT_MD}\`"
  [[ -n "$STAGED_PILOT_OUTPUT_FILE" ]] && echo "- Pilot gate output: \`${STAGED_PILOT_OUTPUT_FILE}\`"
} >"$VALIDATION_REPORT_MD"

VALIDATION_REPORT_MD_SHA="$(sha256_file "$VALIDATION_REPORT_MD")"
STAGED_SERIAL_SHA="$(sha256_file "$STAGED_SERIAL_FILE")"
STAGED_SERIAL_PARSED_JSON_SHA="$(sha256_file "$STAGED_SERIAL_PARSED_JSON")"
STAGED_BENCH_BASELINE_JSON_SHA="$(sha256_file "$STAGED_BENCH_BASELINE_JSON")"
STAGED_BASELINE_REVIEW_JSON_SHA="$(sha256_file "$STAGED_BASELINE_REVIEW_JSON")"
STAGED_BASELINE_HEALTH_JSON_SHA="$(sha256_file "$STAGED_BASELINE_HEALTH_JSON")"
STAGED_LEGACY_SHA="$(sha256_file "$STAGED_LEGACY_FILE")"
STAGED_FIELD_NOTES_SHA="$(sha256_file "$STAGED_FIELD_NOTES_FILE")"
STAGED_PARITY_REPORT_JSON_SHA="$(sha256_file "$STAGED_PARITY_REPORT_JSON")"
STAGED_PARITY_REPORT_MD_SHA="$(sha256_file "$STAGED_PARITY_REPORT_MD")"
STAGED_PARITY_READINESS_REPORT_JSON_SHA="$(sha256_file "$STAGED_PARITY_READINESS_REPORT_JSON")"
STAGED_PARITY_READINESS_REPORT_MD_SHA="$(sha256_file "$STAGED_PARITY_READINESS_REPORT_MD")"
STAGED_TREND_REPORT_JSON_SHA="$(sha256_file "$STAGED_TREND_REPORT_JSON")"
STAGED_TREND_REPORT_MD_SHA="$(sha256_file "$STAGED_TREND_REPORT_MD")"
STAGED_PILOT_GATE_REPORT_JSON_SHA="$(sha256_file "$STAGED_PILOT_GATE_REPORT_JSON")"
STAGED_PILOT_GATE_REPORT_MD_SHA="$(sha256_file "$STAGED_PILOT_GATE_REPORT_MD")"
STAGED_PILOT_OUTPUT_SHA="$(sha256_file "$STAGED_PILOT_OUTPUT_FILE")"

cat >"$JSON_OUT_FILE" <<EOF
{
  "generated_at_utc": $(printf '%s' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" | json_escape),
  "overall_status": $(printf '%s' "$OVERALL_STATUS" | json_escape),
  "primary_failure_code": $(printf '%s' "$PRIMARY_VALIDATION_FAILURE_CODE" | json_escape),
  "primary_warning_code": $(printf '%s' "$PRIMARY_VALIDATION_WARNING_CODE" | json_escape),
  "failure_codes": $VALIDATION_FAILURE_CODES_JSON,
  "warning_codes": $VALIDATION_WARNING_CODES_JSON,
  "capture_dir": $(printf '%s' "$CAPTURE_DIR" | json_escape),
  "artifact_dir": $(printf '%s' "$ARTIFACT_DIR" | json_escape),
  "site_id": $(printf '%s' "$SITE_ID" | json_escape),
  "device_path": $(printf '%s' "$DEVICE_PATH" | json_escape),
  "legacy_source": $(printf '%s' "$LEGACY_SOURCE" | json_escape),
  "bench_baseline_json": $(printf '%s' "$BENCH_BASELINE_JSON" | json_escape),
  "compare_previous": $([[ "$COMPARE_PREVIOUS" -eq 1 ]] && echo true || echo false),
  "gates": {
    "serial_capture_present": $([[ "$SERIAL_CAPTURE_STATUS" == "PASS" ]] && echo true || echo false),
    "legacy_capture_present": $([[ "$LEGACY_CAPTURE_STATUS" == "PASS" ]] && echo true || echo false),
    "field_notes_present": $([[ "$FIELD_NOTES_STATUS" == "PASS" ]] && echo true || echo false),
    "read_only_wiring_documented": $([[ "$WIRING_STATUS" == "PASS" ]] && echo true || echo false),
    "bench_anomaly_gate_passed": $([[ "$BENCH_ANOMALY_STATUS" == "PASS" ]] && echo true || echo false),
    "parity_gate_passed": $([[ "$PARITY_STATUS" == "PASS" ]] && echo true || echo false),
    "trend_gate_passed": $([[ "$TREND_STATUS" == "PASS" ]] && echo true || echo false)
  },
  "statuses": {
    "serial_capture": $(printf '%s' "$SERIAL_CAPTURE_STATUS" | json_escape),
    "legacy_capture": $(printf '%s' "$LEGACY_CAPTURE_STATUS" | json_escape),
    "field_notes": $(printf '%s' "$FIELD_NOTES_STATUS" | json_escape),
    "read_only_wiring": $(printf '%s' "$WIRING_STATUS" | json_escape),
    "bench_anomaly_gate": $(printf '%s' "$BENCH_ANOMALY_STATUS" | json_escape),
    "parity_gate": $(printf '%s' "$PARITY_STATUS" | json_escape),
    "trend_gate": $(printf '%s' "$TREND_STATUS" | json_escape)
  },
  "messages": {
    "serial_capture": $(printf '%s' "$SERIAL_CAPTURE_MESSAGE" | json_escape),
    "legacy_capture": $(printf '%s' "$LEGACY_CAPTURE_MESSAGE" | json_escape),
    "field_notes": $(printf '%s' "$FIELD_NOTES_MESSAGE" | json_escape),
    "read_only_wiring": $(printf '%s' "$WIRING_MESSAGE" | json_escape),
    "bench_anomaly_gate": $(printf '%s' "$BENCH_ANOMALY_MESSAGE" | json_escape),
    "parity_gate": $(printf '%s' "$PARITY_MESSAGE" | json_escape),
    "trend_gate": $(printf '%s' "$TREND_MESSAGE" | json_escape)
  },
  "baseline_review": $(cat "$BASELINE_REVIEW_JSON"),
  "baseline_health": $(cat "$BASELINE_HEALTH_JSON"),
  "files": {
    "serial_capture": $(printf '%s' "$STAGED_SERIAL_FILE" | json_escape),
    "serial_parsed_json": $(printf '%s' "$STAGED_SERIAL_PARSED_JSON" | json_escape),
    "bench_baseline_json": $(printf '%s' "$STAGED_BENCH_BASELINE_JSON" | json_escape),
    "baseline_review_json": $(printf '%s' "$STAGED_BASELINE_REVIEW_JSON" | json_escape),
    "baseline_health_json": $(printf '%s' "$STAGED_BASELINE_HEALTH_JSON" | json_escape),
    "legacy_capture": $(printf '%s' "$STAGED_LEGACY_FILE" | json_escape),
    "field_notes": $(printf '%s' "$STAGED_FIELD_NOTES_FILE" | json_escape),
    "parity_report_json": $(printf '%s' "$STAGED_PARITY_REPORT_JSON" | json_escape),
    "parity_report_markdown": $(printf '%s' "$STAGED_PARITY_REPORT_MD" | json_escape),
    "parity_readiness_report_json": $(printf '%s' "$STAGED_PARITY_READINESS_REPORT_JSON" | json_escape),
    "parity_readiness_report_markdown": $(printf '%s' "$STAGED_PARITY_READINESS_REPORT_MD" | json_escape),
    "trend_report_json": $(printf '%s' "$STAGED_TREND_REPORT_JSON" | json_escape),
    "trend_report_markdown": $(printf '%s' "$STAGED_TREND_REPORT_MD" | json_escape),
    "pilot_gate_report_json": $(printf '%s' "$STAGED_PILOT_GATE_REPORT_JSON" | json_escape),
    "pilot_gate_report_markdown": $(printf '%s' "$STAGED_PILOT_GATE_REPORT_MD" | json_escape),
    "pilot_gate_output": $(printf '%s' "$STAGED_PILOT_OUTPUT_FILE" | json_escape),
    "markdown_report": $(printf '%s' "$VALIDATION_REPORT_MD" | json_escape)
  },
  "checksums": {
    "serial_capture_sha256": $(printf '%s' "$STAGED_SERIAL_SHA" | json_escape),
    "serial_parsed_json_sha256": $(printf '%s' "$STAGED_SERIAL_PARSED_JSON_SHA" | json_escape),
    "bench_baseline_json_sha256": $(printf '%s' "$STAGED_BENCH_BASELINE_JSON_SHA" | json_escape),
    "baseline_review_json_sha256": $(printf '%s' "$STAGED_BASELINE_REVIEW_JSON_SHA" | json_escape),
    "baseline_health_json_sha256": $(printf '%s' "$STAGED_BASELINE_HEALTH_JSON_SHA" | json_escape),
    "legacy_capture_sha256": $(printf '%s' "$STAGED_LEGACY_SHA" | json_escape),
    "field_notes_sha256": $(printf '%s' "$STAGED_FIELD_NOTES_SHA" | json_escape),
    "parity_report_json_sha256": $(printf '%s' "$STAGED_PARITY_REPORT_JSON_SHA" | json_escape),
    "parity_report_markdown_sha256": $(printf '%s' "$STAGED_PARITY_REPORT_MD_SHA" | json_escape),
    "parity_readiness_report_json_sha256": $(printf '%s' "$STAGED_PARITY_READINESS_REPORT_JSON_SHA" | json_escape),
    "parity_readiness_report_markdown_sha256": $(printf '%s' "$STAGED_PARITY_READINESS_REPORT_MD_SHA" | json_escape),
    "trend_report_json_sha256": $(printf '%s' "$STAGED_TREND_REPORT_JSON_SHA" | json_escape),
    "trend_report_markdown_sha256": $(printf '%s' "$STAGED_TREND_REPORT_MD_SHA" | json_escape),
    "pilot_gate_report_json_sha256": $(printf '%s' "$STAGED_PILOT_GATE_REPORT_JSON_SHA" | json_escape),
    "pilot_gate_report_markdown_sha256": $(printf '%s' "$STAGED_PILOT_GATE_REPORT_MD_SHA" | json_escape),
    "pilot_gate_output_sha256": $(printf '%s' "$STAGED_PILOT_OUTPUT_SHA" | json_escape),
    "markdown_report_sha256": $(printf '%s' "$VALIDATION_REPORT_MD_SHA" | json_escape)
  }
}
EOF

INTEGRITY_CERT_JSON="$ARTIFACT_DIR/integrity_certificate.json"
INTEGRITY_CERT_MD="$ARTIFACT_DIR/integrity_certificate.md"
if ! ./scripts/onyx_validation_bundle_certificate.sh \
  --report-json "$JSON_OUT_FILE" \
  --out-json "$INTEGRITY_CERT_JSON" \
  --out-md "$INTEGRITY_CERT_MD" >/dev/null; then
  echo "FAIL: Listener integrity certificate generation failed." >&2
  exit 1
fi

echo "Listener field validation artifact: $ARTIFACT_DIR"
echo "Validation report JSON: $JSON_OUT_FILE"
echo "Validation report markdown: $VALIDATION_REPORT_MD"
echo "Integrity certificate JSON: $INTEGRITY_CERT_JSON"
echo "Integrity certificate markdown: $INTEGRITY_CERT_MD"
echo "Overall status: $OVERALL_STATUS"

if [[ "$OVERALL_STATUS" == "FAIL" ]]; then
  exit 1
fi
if [[ "$OVERALL_STATUS" != "PASS" ]]; then
  exit 2
fi
