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

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_field_validation.sh [--capture-dir <path>] [--site-id <site_id>] [--device-path <tty>] [--legacy-source <label>] [--client-id <id>] [--region-id <id>] [--artifact-dir <path>] [--json-out <path>] [--min-match-rate-percent 95] [--max-skew-seconds 90] [--max-observed-skew-seconds <n>] [--allow-drift-reason <reason>]... [--max-drift-reason-count <reason=count>]... [--compare-previous] [--previous-report-json <path>] [--allow-match-rate-drop-percent 0] [--allow-max-skew-increase-seconds 0] [--allow-trend-drift-count-increase <reason=count>]... [--allow-mock-artifacts]

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
TREND_REPORT_JSON="$PILOT_ARTIFACT_DIR/trend_report.json"
TREND_REPORT_MD="$PILOT_ARTIFACT_DIR/trend_report.md"

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

if [[ "$SERIAL_CAPTURE_STATUS" == "PASS" && "$LEGACY_CAPTURE_STATUS" == "PASS" && "$FIELD_NOTES_STATUS" == "PASS" && "$WIRING_STATUS" == "PASS" && "$PARITY_STATUS" == "PASS" ]]; then
  if [[ "$COMPARE_PREVIOUS" -eq 1 ]]; then
    if [[ "$TREND_STATUS" == "PASS" ]]; then
      OVERALL_STATUS="PASS"
    else
      OVERALL_STATUS="FAIL"
    fi
  else
    OVERALL_STATUS="PASS"
  fi
elif [[ "$PARITY_STATUS" == "FAIL" || "$WIRING_STATUS" == "FAIL" || "$TREND_STATUS" == "FAIL" ]]; then
  OVERALL_STATUS="FAIL"
else
  OVERALL_STATUS="INCOMPLETE"
fi

STAGED_SERIAL_FILE="$(stage_optional_file "$SERIAL_FILE" "serial_raw.txt" || true)"
STAGED_LEGACY_FILE="$(stage_optional_file "$LEGACY_FILE" "legacy_events.json" || true)"
STAGED_FIELD_NOTES_FILE="$(stage_optional_file "$FIELD_NOTES_FILE" "field_notes.md" || true)"
STAGED_PARITY_REPORT_JSON="$(stage_optional_file "$PARITY_REPORT_JSON" "report.json" || true)"
STAGED_PARITY_REPORT_MD="$(stage_optional_file "$PARITY_REPORT_MD" "report.md" || true)"
STAGED_TREND_REPORT_JSON="$(stage_optional_file "$TREND_REPORT_JSON" "trend_report.json" || true)"
STAGED_TREND_REPORT_MD="$(stage_optional_file "$TREND_REPORT_MD" "trend_report.md" || true)"
STAGED_PILOT_OUTPUT_FILE="$(stage_optional_file "$PILOT_OUTPUT_FILE" "pilot_gate_output.txt" || true)"

VALIDATION_REPORT_MD="$ARTIFACT_DIR/validation_report.md"

{
  echo "# ONYX Listener Field Validation"
  echo
  echo "- Generated (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "- Overall status: \`${OVERALL_STATUS}\`"
  echo "- Capture dir: \`${CAPTURE_DIR}\`"
  echo "- Site ID: \`${SITE_ID:-}\`"
  echo "- Device path: \`${DEVICE_PATH:-}\`"
  echo "- Legacy source: \`${LEGACY_SOURCE:-}\`"
  echo "- Compare previous: \`$([[ "$COMPARE_PREVIOUS" -eq 1 ]] && echo yes || echo no)\`"
  echo
  echo "## Gates"
  echo "- Serial capture: \`${SERIAL_CAPTURE_STATUS}\` - ${SERIAL_CAPTURE_MESSAGE}"
  echo "- Legacy capture: \`${LEGACY_CAPTURE_STATUS}\` - ${LEGACY_CAPTURE_MESSAGE}"
  echo "- Field notes: \`${FIELD_NOTES_STATUS}\` - ${FIELD_NOTES_MESSAGE}"
  echo "- Read-only wiring: \`${WIRING_STATUS}\` - ${WIRING_MESSAGE}"
  echo "- Parity gate: \`${PARITY_STATUS}\` - ${PARITY_MESSAGE}"
  echo "- Trend gate: \`${TREND_STATUS}\` - ${TREND_MESSAGE}"
  echo
  echo "## Artifacts"
  [[ -n "$STAGED_SERIAL_FILE" ]] && echo "- Serial raw: \`${STAGED_SERIAL_FILE}\`"
  [[ -n "$STAGED_LEGACY_FILE" ]] && echo "- Legacy events: \`${STAGED_LEGACY_FILE}\`"
  [[ -n "$STAGED_FIELD_NOTES_FILE" ]] && echo "- Field notes: \`${STAGED_FIELD_NOTES_FILE}\`"
  [[ -n "$STAGED_PARITY_REPORT_JSON" ]] && echo "- Parity report JSON: \`${STAGED_PARITY_REPORT_JSON}\`"
  [[ -n "$STAGED_PARITY_REPORT_MD" ]] && echo "- Parity report markdown: \`${STAGED_PARITY_REPORT_MD}\`"
  [[ -n "$STAGED_TREND_REPORT_JSON" ]] && echo "- Trend report JSON: \`${STAGED_TREND_REPORT_JSON}\`"
  [[ -n "$STAGED_TREND_REPORT_MD" ]] && echo "- Trend report markdown: \`${STAGED_TREND_REPORT_MD}\`"
  [[ -n "$STAGED_PILOT_OUTPUT_FILE" ]] && echo "- Pilot gate output: \`${STAGED_PILOT_OUTPUT_FILE}\`"
} >"$VALIDATION_REPORT_MD"

VALIDATION_REPORT_MD_SHA="$(sha256_file "$VALIDATION_REPORT_MD")"
STAGED_SERIAL_SHA="$(sha256_file "$STAGED_SERIAL_FILE")"
STAGED_LEGACY_SHA="$(sha256_file "$STAGED_LEGACY_FILE")"
STAGED_FIELD_NOTES_SHA="$(sha256_file "$STAGED_FIELD_NOTES_FILE")"
STAGED_PARITY_REPORT_JSON_SHA="$(sha256_file "$STAGED_PARITY_REPORT_JSON")"
STAGED_PARITY_REPORT_MD_SHA="$(sha256_file "$STAGED_PARITY_REPORT_MD")"
STAGED_TREND_REPORT_JSON_SHA="$(sha256_file "$STAGED_TREND_REPORT_JSON")"
STAGED_TREND_REPORT_MD_SHA="$(sha256_file "$STAGED_TREND_REPORT_MD")"
STAGED_PILOT_OUTPUT_SHA="$(sha256_file "$STAGED_PILOT_OUTPUT_FILE")"

cat >"$JSON_OUT_FILE" <<EOF
{
  "generated_at_utc": $(printf '%s' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" | json_escape),
  "overall_status": $(printf '%s' "$OVERALL_STATUS" | json_escape),
  "capture_dir": $(printf '%s' "$CAPTURE_DIR" | json_escape),
  "artifact_dir": $(printf '%s' "$ARTIFACT_DIR" | json_escape),
  "site_id": $(printf '%s' "$SITE_ID" | json_escape),
  "device_path": $(printf '%s' "$DEVICE_PATH" | json_escape),
  "legacy_source": $(printf '%s' "$LEGACY_SOURCE" | json_escape),
  "compare_previous": $([[ "$COMPARE_PREVIOUS" -eq 1 ]] && echo true || echo false),
  "gates": {
    "serial_capture_present": $([[ "$SERIAL_CAPTURE_STATUS" == "PASS" ]] && echo true || echo false),
    "legacy_capture_present": $([[ "$LEGACY_CAPTURE_STATUS" == "PASS" ]] && echo true || echo false),
    "field_notes_present": $([[ "$FIELD_NOTES_STATUS" == "PASS" ]] && echo true || echo false),
    "read_only_wiring_documented": $([[ "$WIRING_STATUS" == "PASS" ]] && echo true || echo false),
    "parity_gate_passed": $([[ "$PARITY_STATUS" == "PASS" ]] && echo true || echo false),
    "trend_gate_passed": $([[ "$TREND_STATUS" == "PASS" ]] && echo true || echo false)
  },
  "statuses": {
    "serial_capture": $(printf '%s' "$SERIAL_CAPTURE_STATUS" | json_escape),
    "legacy_capture": $(printf '%s' "$LEGACY_CAPTURE_STATUS" | json_escape),
    "field_notes": $(printf '%s' "$FIELD_NOTES_STATUS" | json_escape),
    "read_only_wiring": $(printf '%s' "$WIRING_STATUS" | json_escape),
    "parity_gate": $(printf '%s' "$PARITY_STATUS" | json_escape),
    "trend_gate": $(printf '%s' "$TREND_STATUS" | json_escape)
  },
  "messages": {
    "serial_capture": $(printf '%s' "$SERIAL_CAPTURE_MESSAGE" | json_escape),
    "legacy_capture": $(printf '%s' "$LEGACY_CAPTURE_MESSAGE" | json_escape),
    "field_notes": $(printf '%s' "$FIELD_NOTES_MESSAGE" | json_escape),
    "read_only_wiring": $(printf '%s' "$WIRING_MESSAGE" | json_escape),
    "parity_gate": $(printf '%s' "$PARITY_MESSAGE" | json_escape),
    "trend_gate": $(printf '%s' "$TREND_MESSAGE" | json_escape)
  },
  "files": {
    "serial_capture": $(printf '%s' "$STAGED_SERIAL_FILE" | json_escape),
    "legacy_capture": $(printf '%s' "$STAGED_LEGACY_FILE" | json_escape),
    "field_notes": $(printf '%s' "$STAGED_FIELD_NOTES_FILE" | json_escape),
    "parity_report_json": $(printf '%s' "$STAGED_PARITY_REPORT_JSON" | json_escape),
    "parity_report_markdown": $(printf '%s' "$STAGED_PARITY_REPORT_MD" | json_escape),
    "trend_report_json": $(printf '%s' "$STAGED_TREND_REPORT_JSON" | json_escape),
    "trend_report_markdown": $(printf '%s' "$STAGED_TREND_REPORT_MD" | json_escape),
    "pilot_gate_output": $(printf '%s' "$STAGED_PILOT_OUTPUT_FILE" | json_escape),
    "markdown_report": $(printf '%s' "$VALIDATION_REPORT_MD" | json_escape)
  },
  "checksums": {
    "serial_capture_sha256": $(printf '%s' "$STAGED_SERIAL_SHA" | json_escape),
    "legacy_capture_sha256": $(printf '%s' "$STAGED_LEGACY_SHA" | json_escape),
    "field_notes_sha256": $(printf '%s' "$STAGED_FIELD_NOTES_SHA" | json_escape),
    "parity_report_json_sha256": $(printf '%s' "$STAGED_PARITY_REPORT_JSON_SHA" | json_escape),
    "parity_report_markdown_sha256": $(printf '%s' "$STAGED_PARITY_REPORT_MD_SHA" | json_escape),
    "trend_report_json_sha256": $(printf '%s' "$STAGED_TREND_REPORT_JSON_SHA" | json_escape),
    "trend_report_markdown_sha256": $(printf '%s' "$STAGED_TREND_REPORT_MD_SHA" | json_escape),
    "pilot_gate_output_sha256": $(printf '%s' "$STAGED_PILOT_OUTPUT_SHA" | json_escape),
    "markdown_report_sha256": $(printf '%s' "$VALIDATION_REPORT_MD_SHA" | json_escape)
  }
}
EOF

echo "Listener field validation artifact: $ARTIFACT_DIR"
echo "Validation report JSON: $JSON_OUT_FILE"
echo "Validation report markdown: $VALIDATION_REPORT_MD"
echo "Overall status: $OVERALL_STATUS"

if [[ "$OVERALL_STATUS" == "FAIL" ]]; then
  exit 1
fi
if [[ "$OVERALL_STATUS" != "PASS" ]]; then
  exit 2
fi
