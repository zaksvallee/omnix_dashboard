#!/usr/bin/env bash
set -euo pipefail

REPORT_JSON=""
OUT_FILE=""
ALLOW_MOCK_ARTIFACTS=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_signoff_generate.sh [--report-json <path>] [--out <path>] [--allow-mock-artifacts]

Purpose:
  Generate a listener pilot signoff note from the parity report and field notes.
  Real-artifact readiness is enforced by default.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report-json)
      REPORT_JSON="${2:-}"
      shift 2
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

readiness_cmd=(./scripts/onyx_listener_parity_readiness_check.sh --report-json "$REPORT_JSON")
if [[ "$ALLOW_MOCK_ARTIFACTS" -ne 1 ]]; then
  readiness_cmd+=(--require-real-artifacts)
fi
"${readiness_cmd[@]}" >/dev/null

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
  echo
  echo "## Results"
  echo "- Summary: \`${summary}\`"
  echo "- Serial count: \`${serial_count}\`"
  echo "- Legacy count: \`${legacy_count}\`"
  echo "- Matched count: \`${matched_count}\`"
  echo "- Unmatched serial count: \`${unmatched_serial_count}\`"
  echo "- Unmatched legacy count: \`${unmatched_legacy_count}\`"
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
  echo "- Remaining blockers: \`none\`"
} >"$OUT_FILE"

echo "PASS: Listener pilot signoff generated: $OUT_FILE"
