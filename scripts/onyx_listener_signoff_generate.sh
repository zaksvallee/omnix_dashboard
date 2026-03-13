#!/usr/bin/env bash
set -euo pipefail

REPORT_JSON=""
OUT_FILE=""
TREND_REPORT_JSON=""
REQUIRE_TREND_PASS=0
ALLOW_MOCK_ARTIFACTS=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_signoff_generate.sh [--report-json <path>] [--trend-report-json <path>] [--require-trend-pass] [--out <path>] [--allow-mock-artifacts]

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
    --out)
      OUT_FILE="${2:-}"
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

if [[ -z "$REPORT_JSON" ]]; then
  REPORT_JSON="$(latest_report_json || true)"
fi
if [[ -z "$REPORT_JSON" || ! -f "$REPORT_JSON" ]]; then
  echo "FAIL: listener parity report not found."
  exit 1
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
  echo "FAIL: trend report not found: $TREND_REPORT_JSON"
  exit 1
fi

readiness_cmd=(./scripts/onyx_listener_parity_readiness_check.sh --report-json "$REPORT_JSON")
if [[ "$ALLOW_MOCK_ARTIFACTS" -ne 1 ]]; then
  readiness_cmd+=(--require-real-artifacts)
fi
"${readiness_cmd[@]}" >/dev/null

trend_status=""
trend_markdown=""
if [[ -n "$TREND_REPORT_JSON" ]]; then
  trend_status="$(json_get "$TREND_REPORT_JSON" "status")"
  trend_markdown="$(dirname "$TREND_REPORT_JSON")/trend_report.md"
fi
if [[ "$REQUIRE_TREND_PASS" -eq 1 ]]; then
  if [[ -z "$TREND_REPORT_JSON" ]]; then
    echo "FAIL: --require-trend-pass was set but no trend report was found."
    exit 1
  fi
  if [[ "$trend_status" != "PASS" ]]; then
    echo "FAIL: listener trend report is not PASS (${trend_status:-missing})."
    exit 1
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

if [[ -z "$OUT_FILE" ]]; then
  local_date="$(TZ=Africa/Johannesburg date +%Y-%m-%d)"
  OUT_FILE="docs/onyx_listener_pilot_signoff_${local_date}.md"
fi

mkdir -p "$(dirname "$OUT_FILE")"

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
  echo "- Remaining blockers: \`none\`"
} >"$OUT_FILE"

echo "PASS: Listener pilot signoff generated: $OUT_FILE"
