#!/usr/bin/env bash
set -euo pipefail

REPORT_JSON=""
OUT_FILE=""
JSON_OUT_FILE=""
TREND_REPORT_JSON=""
REQUIRE_TREND_PASS=0
VALIDATION_REPORT_JSON=""
VALIDATION_TREND_REPORT_JSON=""
REQUIRE_VALIDATION_TREND_PASS=0
CUTOVER_DECISION_JSON=""
REQUIRE_CUTOVER_GO=0
CUTOVER_TREND_REPORT_JSON=""
REQUIRE_CUTOVER_TREND_PASS=0
ALLOW_MOCK_ARTIFACTS=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_signoff_generate.sh [--report-json <path>] [--trend-report-json <path>] [--require-trend-pass] [--validation-report-json <path>] [--validation-trend-report-json <path>] [--require-validation-trend-pass] [--cutover-decision-json <path>] [--require-cutover-go] [--cutover-trend-report-json <path>] [--require-cutover-trend-pass] [--out <path>] [--json-out <path>] [--allow-mock-artifacts]

Purpose:
  Generate a listener pilot signoff note from the parity report and field notes.
  Real-artifact readiness is enforced by default, and trend-pass can be
  required before closeout.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report-json)
      REPORT_JSON="${2:-}"
      shift 2
      ;;
    --trend-report-json)
      TREND_REPORT_JSON="${2:-}"
      shift 2
      ;;
    --require-trend-pass)
      REQUIRE_TREND_PASS=1
      shift
      ;;
    --validation-report-json)
      VALIDATION_REPORT_JSON="${2:-}"
      shift 2
      ;;
    --validation-trend-report-json)
      VALIDATION_TREND_REPORT_JSON="${2:-}"
      shift 2
      ;;
    --require-validation-trend-pass)
      REQUIRE_VALIDATION_TREND_PASS=1
      shift
      ;;
    --cutover-decision-json)
      CUTOVER_DECISION_JSON="${2:-}"
      shift 2
      ;;
    --require-cutover-go)
      REQUIRE_CUTOVER_GO=1
      shift
      ;;
    --cutover-trend-report-json)
      CUTOVER_TREND_REPORT_JSON="${2:-}"
      shift 2
      ;;
    --require-cutover-trend-pass)
      REQUIRE_CUTOVER_TREND_PASS=1
      shift
      ;;
    --out)
      OUT_FILE="${2:-}"
      shift 2
      ;;
    --json-out)
      JSON_OUT_FILE="${2:-}"
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

if [[ -z "$OUT_FILE" ]]; then
  local_date="$(TZ=Africa/Johannesburg date +%Y-%m-%d)"
  OUT_FILE="docs/onyx_listener_pilot_signoff_${local_date}.md"
fi
if [[ -z "$JSON_OUT_FILE" ]]; then
  JSON_OUT_FILE="${OUT_FILE%.md}.json"
fi

latest_report_json() {
  local base_dir="tmp/listener_parity"
  if [[ ! -d "$base_dir" ]]; then
    return 1
  fi
  find "$base_dir" -type f -name "report.json" -print0 2>/dev/null \
    | xargs -0 ls -1t 2>/dev/null \
    | head -n 1
}

latest_trend_report_json() {
  local base_dir="tmp/listener_parity"
  if [[ ! -d "$base_dir" ]]; then
    return 1
  fi
  find "$base_dir" -type f -name "trend_report.json" -print0 2>/dev/null \
    | xargs -0 ls -1t 2>/dev/null \
    | head -n 1
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

write_signoff_json_report() {
  local signoff_status="$1"
  local signoff_summary="$2"
  local signoff_failure_code="${3:-}"
  mkdir -p "$(dirname "$JSON_OUT_FILE")"
  python3 - "$JSON_OUT_FILE" "$OUT_FILE" "$REPORT_JSON" "$TREND_REPORT_JSON" "$VALIDATION_REPORT_JSON" "$VALIDATION_TREND_REPORT_JSON" "$CUTOVER_DECISION_JSON" "$CUTOVER_TREND_REPORT_JSON" "${trend_status:-}" "${validation_trend_status:-}" "${cutover_decision:-}" "${cutover_trend_status:-}" "$REQUIRE_TREND_PASS" "$REQUIRE_VALIDATION_TREND_PASS" "$REQUIRE_CUTOVER_GO" "$REQUIRE_CUTOVER_TREND_PASS" "$ALLOW_MOCK_ARTIFACTS" "$signoff_status" "$signoff_summary" "$signoff_failure_code" <<'PY'
import json
import sys
from pathlib import Path

json_out = Path(sys.argv[1])
markdown_out = sys.argv[2]
report_json = sys.argv[3]
trend_report_json = sys.argv[4]
validation_report_json = sys.argv[5]
validation_trend_report_json = sys.argv[6]
cutover_decision_json = sys.argv[7]
cutover_trend_report_json = sys.argv[8]
trend_status = sys.argv[9]
validation_trend_status = sys.argv[10]
cutover_decision = sys.argv[11]
cutover_trend_status = sys.argv[12]

def as_bool(raw: str) -> bool:
    return raw == "1"

require_trend_pass = as_bool(sys.argv[13])
require_validation_trend_pass = as_bool(sys.argv[14])
require_cutover_go = as_bool(sys.argv[15])
require_cutover_trend_pass = as_bool(sys.argv[16])
allow_mock_artifacts = as_bool(sys.argv[17])
signoff_status = sys.argv[18]
signoff_summary = sys.argv[19]
signoff_failure_code = sys.argv[20]

payload = {
    "status": signoff_status,
    "summary": signoff_summary,
    "failure_code": signoff_failure_code,
    "markdown_file": markdown_out,
    "report_json": report_json,
    "trend_report_json": trend_report_json,
    "validation_report_json": validation_report_json,
    "validation_trend_report_json": validation_trend_report_json,
    "cutover_decision_json": cutover_decision_json,
    "cutover_trend_report_json": cutover_trend_report_json,
    "statuses": {
        "trend_status": trend_status,
        "validation_trend_status": validation_trend_status,
        "cutover_decision": cutover_decision,
        "cutover_trend_status": cutover_trend_status,
    },
    "requirements": {
        "require_trend_pass": require_trend_pass,
        "require_validation_trend_pass": require_validation_trend_pass,
        "require_cutover_go": require_cutover_go,
        "require_cutover_trend_pass": require_cutover_trend_pass,
        "allow_mock_artifacts": allow_mock_artifacts,
    },
}

json_out.write_text(json.dumps(payload, indent=2), encoding="utf-8")
PY
}

fail_signoff() {
  local failure_code="$1"
  local failure_summary="$2"
  write_signoff_json_report "FAIL" "$failure_summary" "$failure_code"
  echo "FAIL: $failure_summary"
  echo "Signoff JSON: $JSON_OUT_FILE"
  exit 1
}

if [[ -z "$REPORT_JSON" ]]; then
  REPORT_JSON="$(latest_report_json || true)"
fi
if [[ -z "$REPORT_JSON" || ! -f "$REPORT_JSON" ]]; then
  fail_signoff "missing_parity_report" "listener parity report not found."
fi

if [[ "$REQUIRE_TREND_PASS" -eq 1 && -z "$TREND_REPORT_JSON" ]]; then
  report_artifact_dir="$(json_get "$REPORT_JSON" "artifact_dir")"
  if [[ -n "$report_artifact_dir" && -f "$report_artifact_dir/trend_report.json" ]]; then
    TREND_REPORT_JSON="$report_artifact_dir/trend_report.json"
  else
    TREND_REPORT_JSON="$(latest_trend_report_json || true)"
  fi
fi
if [[ -n "$TREND_REPORT_JSON" && ! -f "$TREND_REPORT_JSON" ]]; then
  fail_signoff "missing_trend_report" "trend report not found: $TREND_REPORT_JSON"
fi

if [[ -z "$VALIDATION_REPORT_JSON" ]]; then
  report_artifact_dir="$(json_get "$REPORT_JSON" "artifact_dir")"
  if [[ -n "$report_artifact_dir" ]]; then
    validation_candidate="$(dirname "$report_artifact_dir")/validation_report.json"
    if [[ -f "$validation_candidate" ]]; then
      VALIDATION_REPORT_JSON="$validation_candidate"
    fi
  fi
fi
if [[ "$REQUIRE_VALIDATION_TREND_PASS" -eq 1 && -z "$VALIDATION_TREND_REPORT_JSON" && -n "$VALIDATION_REPORT_JSON" ]]; then
  validation_artifact_dir="$(dirname "$VALIDATION_REPORT_JSON")"
  if [[ -f "$validation_artifact_dir/validation_trend_report.json" ]]; then
    VALIDATION_TREND_REPORT_JSON="$validation_artifact_dir/validation_trend_report.json"
  fi
fi
if [[ "$REQUIRE_CUTOVER_GO" -eq 1 && -z "$CUTOVER_DECISION_JSON" && -n "$VALIDATION_REPORT_JSON" ]]; then
  validation_artifact_dir="$(dirname "$VALIDATION_REPORT_JSON")"
  if [[ -f "$validation_artifact_dir/cutover_decision.json" ]]; then
    CUTOVER_DECISION_JSON="$validation_artifact_dir/cutover_decision.json"
  fi
fi
if [[ "$REQUIRE_CUTOVER_TREND_PASS" -eq 1 && -z "$CUTOVER_TREND_REPORT_JSON" && -n "$VALIDATION_REPORT_JSON" ]]; then
  validation_artifact_dir="$(dirname "$VALIDATION_REPORT_JSON")"
  if [[ -f "$validation_artifact_dir/cutover_trend_report.json" ]]; then
    CUTOVER_TREND_REPORT_JSON="$validation_artifact_dir/cutover_trend_report.json"
  fi
fi
if [[ -n "$VALIDATION_REPORT_JSON" && ! -f "$VALIDATION_REPORT_JSON" ]]; then
  fail_signoff "missing_validation_report" "validation report not found: $VALIDATION_REPORT_JSON"
fi
if [[ -n "$VALIDATION_TREND_REPORT_JSON" && ! -f "$VALIDATION_TREND_REPORT_JSON" ]]; then
  fail_signoff "missing_validation_trend_report" "validation trend report not found: $VALIDATION_TREND_REPORT_JSON"
fi
if [[ -n "$CUTOVER_DECISION_JSON" && ! -f "$CUTOVER_DECISION_JSON" ]]; then
  fail_signoff "missing_cutover_decision_report" "cutover decision report not found: $CUTOVER_DECISION_JSON"
fi
if [[ -n "$CUTOVER_TREND_REPORT_JSON" && ! -f "$CUTOVER_TREND_REPORT_JSON" ]]; then
  fail_signoff "missing_cutover_trend_report" "cutover trend report not found: $CUTOVER_TREND_REPORT_JSON"
fi

if [[ -n "$VALIDATION_REPORT_JSON" || "$REQUIRE_VALIDATION_TREND_PASS" -eq 1 ]]; then
  readiness_cmd=(./scripts/onyx_listener_pilot_readiness_check.sh --report-json "$VALIDATION_REPORT_JSON")
  if [[ "$REQUIRE_TREND_PASS" -eq 1 ]]; then
    readiness_cmd+=(--require-trend-pass)
  fi
  if [[ -n "$VALIDATION_TREND_REPORT_JSON" ]]; then
    readiness_cmd+=(--validation-trend-report-json "$VALIDATION_TREND_REPORT_JSON")
  fi
  if [[ "$REQUIRE_VALIDATION_TREND_PASS" -eq 1 ]]; then
    readiness_cmd+=(--require-validation-trend-pass)
  fi
  if [[ -n "$CUTOVER_DECISION_JSON" ]]; then
    readiness_cmd+=(--cutover-decision-json "$CUTOVER_DECISION_JSON")
  fi
  if [[ "$REQUIRE_CUTOVER_GO" -eq 1 ]]; then
    readiness_cmd+=(--require-cutover-go)
  fi
  if [[ -n "$CUTOVER_TREND_REPORT_JSON" ]]; then
    readiness_cmd+=(--cutover-trend-report-json "$CUTOVER_TREND_REPORT_JSON")
  fi
  if [[ "$REQUIRE_CUTOVER_TREND_PASS" -eq 1 ]]; then
    readiness_cmd+=(--require-cutover-trend-pass)
  fi
else
  readiness_cmd=(./scripts/onyx_listener_parity_readiness_check.sh --report-json "$REPORT_JSON")
fi
if [[ "$ALLOW_MOCK_ARTIFACTS" -ne 1 ]]; then
  readiness_cmd+=(--require-real-artifacts)
fi
if ! "${readiness_cmd[@]}" >/dev/null; then
  fail_signoff "readiness_not_pass" "listener readiness did not pass for signoff generation."
fi

trend_status=""
trend_markdown=""
if [[ -n "$TREND_REPORT_JSON" ]]; then
  trend_status="$(json_get "$TREND_REPORT_JSON" "status")"
  trend_markdown="$(dirname "$TREND_REPORT_JSON")/trend_report.md"
fi
if [[ "$REQUIRE_TREND_PASS" -eq 1 ]]; then
  if [[ -z "$TREND_REPORT_JSON" ]]; then
    fail_signoff "missing_trend_report" "--require-trend-pass was set but no trend report was found."
  fi
  if [[ "$trend_status" != "PASS" ]]; then
    fail_signoff "trend_not_pass" "listener trend report is not PASS (${trend_status:-missing})."
  fi
fi

validation_trend_status=""
validation_trend_markdown=""
if [[ -n "$VALIDATION_TREND_REPORT_JSON" ]]; then
  validation_trend_status="$(json_get "$VALIDATION_TREND_REPORT_JSON" "status")"
  validation_trend_markdown="$(dirname "$VALIDATION_TREND_REPORT_JSON")/validation_trend_report.md"
fi
if [[ "$REQUIRE_VALIDATION_TREND_PASS" -eq 1 ]]; then
  if [[ -z "$VALIDATION_TREND_REPORT_JSON" ]]; then
    fail_signoff "missing_validation_trend_report" "--require-validation-trend-pass was set but no validation trend report was found."
  fi
  if [[ "$validation_trend_status" != "PASS" ]]; then
    fail_signoff "validation_trend_not_pass" "listener validation trend report is not PASS (${validation_trend_status:-missing})."
  fi
fi

cutover_decision=""
if [[ -n "$CUTOVER_DECISION_JSON" ]]; then
  cutover_decision="$(json_get "$CUTOVER_DECISION_JSON" "decision")"
fi
if [[ "$REQUIRE_CUTOVER_GO" -eq 1 ]]; then
  if [[ -z "$CUTOVER_DECISION_JSON" ]]; then
    fail_signoff "missing_cutover_decision_report" "--require-cutover-go was set but no cutover decision report was found."
  fi
  if [[ "$cutover_decision" != "GO" ]]; then
    fail_signoff "cutover_decision_not_go" "listener cutover decision is not GO (${cutover_decision:-missing})."
  fi
fi

cutover_trend_status=""
cutover_trend_markdown=""
if [[ -n "$CUTOVER_TREND_REPORT_JSON" ]]; then
  cutover_trend_status="$(json_get "$CUTOVER_TREND_REPORT_JSON" "status")"
  cutover_trend_markdown="$(dirname "$CUTOVER_TREND_REPORT_JSON")/cutover_trend_report.md"
fi
if [[ "$REQUIRE_CUTOVER_TREND_PASS" -eq 1 ]]; then
  if [[ -z "$CUTOVER_TREND_REPORT_JSON" ]]; then
    fail_signoff "missing_cutover_trend_report" "--require-cutover-trend-pass was set but no cutover trend report was found."
  fi
  if [[ "$cutover_trend_status" != "PASS" ]]; then
    fail_signoff "cutover_trend_not_pass" "listener cutover trend report is not PASS (${cutover_trend_status:-missing})."
  fi
fi

artifact_dir="$(json_get "$REPORT_JSON" "artifact_dir")"
capture_dir="$(json_get "$REPORT_JSON" "capture_dir")"
summary="$(json_get "$REPORT_JSON" "summary")"
serial_count="$(json_get "$REPORT_JSON" "serial_count")"
legacy_count="$(json_get "$REPORT_JSON" "legacy_count")"
matched_count="$(json_get "$REPORT_JSON" "matched_count")"
unmatched_serial_count="$(json_get "$REPORT_JSON" "unmatched_serial_count")"
unmatched_legacy_count="$(json_get "$REPORT_JSON" "unmatched_legacy_count")"
serial_input="$(json_get "$REPORT_JSON" "files.serial_input")"
legacy_input="$(json_get "$REPORT_JSON" "files.legacy_input")"
report_markdown="$(json_get "$REPORT_JSON" "files.report_markdown")"
field_notes_file=""
if [[ -f "$capture_dir/field_notes.md" ]]; then
  field_notes_file="$capture_dir/field_notes.md"
fi

mkdir -p "$(dirname "$OUT_FILE")"
mkdir -p "$(dirname "$JSON_OUT_FILE")"

{
  echo "# ONYX Listener Pilot Signoff ($(TZ=Africa/Johannesburg date +%Y-%m-%d))"
  echo
  echo "Date: $(TZ=Africa/Johannesburg date +%Y-%m-%d) (Africa/Johannesburg)"
  echo
  echo "## Scope"
  echo "- Capture pack dir: \`${capture_dir}\`"
  echo "- Parity artifact dir: \`${artifact_dir}\`"
  echo "- Serial input: \`${serial_input}\`"
  echo "- Legacy input: \`${legacy_input}\`"
  if [[ -n "$report_markdown" ]]; then
    echo "- Parity markdown summary: \`${report_markdown}\`"
  fi
  if [[ -n "$TREND_REPORT_JSON" ]]; then
    echo "- Trend report JSON: \`${TREND_REPORT_JSON}\`"
  fi
  if [[ -n "$trend_markdown" && -f "$trend_markdown" ]]; then
    echo "- Trend report markdown: \`${trend_markdown}\`"
  fi
  if [[ -n "$VALIDATION_REPORT_JSON" ]]; then
    echo "- Validation report JSON: \`${VALIDATION_REPORT_JSON}\`"
  fi
  if [[ -n "$VALIDATION_TREND_REPORT_JSON" ]]; then
    echo "- Validation trend report JSON: \`${VALIDATION_TREND_REPORT_JSON}\`"
  fi
  if [[ -n "$validation_trend_markdown" && -f "$validation_trend_markdown" ]]; then
    echo "- Validation trend markdown: \`${validation_trend_markdown}\`"
  fi
  if [[ -n "$CUTOVER_DECISION_JSON" ]]; then
    echo "- Cutover decision JSON: \`${CUTOVER_DECISION_JSON}\`"
  fi
  if [[ -n "$CUTOVER_TREND_REPORT_JSON" ]]; then
    echo "- Cutover trend report JSON: \`${CUTOVER_TREND_REPORT_JSON}\`"
  fi
  if [[ -n "$cutover_trend_markdown" && -f "$cutover_trend_markdown" ]]; then
    echo "- Cutover trend markdown: \`${cutover_trend_markdown}\`"
  fi
  echo
  echo "## Results"
  echo "- Summary: \`${summary}\`"
  echo "- Serial count: \`${serial_count}\`"
  echo "- Legacy count: \`${legacy_count}\`"
  echo "- Matched count: \`${matched_count}\`"
  echo "- Unmatched serial count: \`${unmatched_serial_count}\`"
  echo "- Unmatched legacy count: \`${unmatched_legacy_count}\`"
  if [[ -n "$trend_status" ]]; then
    echo "- Trend status: \`${trend_status}\`"
  fi
  if [[ -n "$validation_trend_status" ]]; then
    echo "- Validation trend status: \`${validation_trend_status}\`"
  fi
  if [[ -n "$cutover_decision" ]]; then
    echo "- Cutover decision: \`${cutover_decision}\`"
  fi
  if [[ -n "$cutover_trend_status" ]]; then
    echo "- Cutover trend status: \`${cutover_trend_status}\`"
  fi
  echo
  echo "## Notes"
  if [[ -n "$field_notes_file" ]]; then
    echo "Imported from \`$field_notes_file\`."
    echo
    cat "$field_notes_file"
  else
    echo "- Field notes file not found in capture pack."
  fi
  echo
  echo "## Decision"
  echo "- Listener parity acceptable for pilot: \`yes\`"
  if [[ "$REQUIRE_TREND_PASS" -eq 1 ]]; then
    echo "- Listener trend regression check acceptable for pilot: \`yes\`"
  elif [[ -n "$trend_status" ]]; then
    echo "- Listener trend regression check acceptable for pilot: \`$([[ "$trend_status" == "PASS" ]] && echo yes || echo no)\`"
  fi
  if [[ "$REQUIRE_VALIDATION_TREND_PASS" -eq 1 ]]; then
    echo "- Listener validation trend check acceptable for pilot: \`yes\`"
  elif [[ -n "$validation_trend_status" ]]; then
    echo "- Listener validation trend check acceptable for pilot: \`$([[ "$validation_trend_status" == "PASS" ]] && echo yes || echo no)\`"
  fi
  if [[ "$REQUIRE_CUTOVER_GO" -eq 1 ]]; then
    echo "- Listener cutover decision acceptable for pilot: \`yes\`"
  elif [[ -n "$cutover_decision" ]]; then
    echo "- Listener cutover decision acceptable for pilot: \`$([[ "$cutover_decision" == "GO" ]] && echo yes || echo no)\`"
  fi
  if [[ "$REQUIRE_CUTOVER_TREND_PASS" -eq 1 ]]; then
    echo "- Listener cutover trend acceptable for pilot: \`yes\`"
  elif [[ -n "$cutover_trend_status" ]]; then
    echo "- Listener cutover trend acceptable for pilot: \`$([[ "$cutover_trend_status" == "PASS" ]] && echo yes || echo no)\`"
  fi
  echo "- Remaining blockers: \`none\`"
} >"$OUT_FILE"

write_signoff_json_report "PASS" "Listener pilot signoff generated." ""

echo "PASS: Listener pilot signoff generated: $OUT_FILE"
echo "Signoff JSON: $JSON_OUT_FILE"
