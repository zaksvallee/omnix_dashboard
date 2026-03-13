#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REPORT_JSON=""
MAX_REPORT_AGE_HOURS=24
REQUIRE_REAL_ARTIFACTS=0
REQUIRE_TREND_PASS=0

pass() { printf "PASS: %s\n" "$1"; }
fail() { printf "FAIL: %s\n" "$1"; exit 1; }

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_pilot_readiness_check.sh [--report-json <path>] [--max-report-age-hours <hours>] [--require-real-artifacts] [--require-trend-pass]

Purpose:
  Validate the latest listener field-validation artifact under
  tmp/listener_field_validation/ and fail if the evidence bundle is stale,
  incomplete, or corrupted.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report-json)
      REPORT_JSON="${2:-}"
      shift 2
      ;;
    --max-report-age-hours)
      MAX_REPORT_AGE_HOURS="${2:-}"
      shift 2
      ;;
    --require-real-artifacts)
      REQUIRE_REAL_ARTIFACTS=1
      shift
      ;;
    --require-trend-pass)
      REQUIRE_TREND_PASS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

if ! [[ "$MAX_REPORT_AGE_HOURS" =~ ^[0-9]+$ ]]; then
  fail "--max-report-age-hours must be a non-negative integer."
fi

latest_validation_report_json() {
  local base_dir="tmp/listener_field_validation"
  if [[ ! -d "$base_dir" ]]; then
    return 1
  fi
  find "$base_dir" -type f -name "validation_report.json" -print0 2>/dev/null \
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

report_age_hours() {
  local report_file="$1"
  python3 - "$report_file" <<'PY'
import os
import sys
import time
path = sys.argv[1]
age_hours = (time.time() - os.path.getmtime(path)) / 3600.0
print(f"{age_hours:.2f}")
PY
}

verify_json_report_checksums() {
  local report_file="$1"
  python3 - "$report_file" <<'PY'
import hashlib
import json
import os
import sys

report_file = sys.argv[1]
with open(report_file, "r", encoding="utf-8") as handle:
    data = json.load(handle)

files = data.get("files", {})
checksums = data.get("checksums", {})
artifact_dir = data.get("artifact_dir", "")

pairs = [
    ("serial_capture", "serial_capture_sha256"),
    ("legacy_capture", "legacy_capture_sha256"),
    ("field_notes", "field_notes_sha256"),
    ("parity_report_json", "parity_report_json_sha256"),
    ("parity_report_markdown", "parity_report_markdown_sha256"),
    ("trend_report_json", "trend_report_json_sha256"),
    ("trend_report_markdown", "trend_report_markdown_sha256"),
    ("pilot_gate_output", "pilot_gate_output_sha256"),
    ("markdown_report", "markdown_report_sha256"),
]

for file_key, checksum_key in pairs:
    path = files.get(file_key, "")
    expected = checksums.get(checksum_key, "")
    if not path or not expected:
        continue
    if not os.path.isfile(path):
        raise SystemExit(f"missing:{file_key}:{path}")
    digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
    if digest != expected:
        raise SystemExit(f"checksum:{file_key}:{path}")

if artifact_dir and not os.path.isdir(artifact_dir):
    raise SystemExit(f"artifact_dir:{artifact_dir}")

print("ok")
PY
}

latest_report_json="$REPORT_JSON"
if [[ -z "$latest_report_json" ]]; then
  latest_report_json="$(latest_validation_report_json || true)"
fi
if [[ -z "$latest_report_json" || ! -f "$latest_report_json" ]]; then
  fail "No listener validation_report.json found under tmp/listener_field_validation."
fi

report_age="$(report_age_hours "$latest_report_json")"
if ! python3 - "$report_age" "$MAX_REPORT_AGE_HOURS" <<'PY'
import sys
age = float(sys.argv[1])
max_age = float(sys.argv[2])
raise SystemExit(0 if age <= max_age else 1)
PY
then
  fail "Latest listener validation report is stale (${report_age}h old > ${MAX_REPORT_AGE_HOURS}h)."
fi

overall_status="$(json_get "$latest_report_json" "overall_status" | tr '[:lower:]' '[:upper:]')"
artifact_dir="$(json_get "$latest_report_json" "artifact_dir")"
is_mock="$(json_get "$latest_report_json" "is_mock" | tr '[:upper:]' '[:lower:]')"
serial_capture_present="$(json_get "$latest_report_json" "gates.serial_capture_present" | tr '[:upper:]' '[:lower:]')"
legacy_capture_present="$(json_get "$latest_report_json" "gates.legacy_capture_present" | tr '[:upper:]' '[:lower:]')"
field_notes_present="$(json_get "$latest_report_json" "gates.field_notes_present" | tr '[:upper:]' '[:lower:]')"
read_only_wiring_documented="$(json_get "$latest_report_json" "gates.read_only_wiring_documented" | tr '[:upper:]' '[:lower:]')"
parity_gate_passed="$(json_get "$latest_report_json" "gates.parity_gate_passed" | tr '[:upper:]' '[:lower:]')"
trend_gate_passed="$(json_get "$latest_report_json" "gates.trend_gate_passed" | tr '[:upper:]' '[:lower:]')"
verify_result="$(verify_json_report_checksums "$latest_report_json")" || fail "Listener validation checksum verification failed: $verify_result"
pass "Listener validation checksums verified."

if [[ "$REQUIRE_REAL_ARTIFACTS" -eq 1 ]]; then
  if [[ "$is_mock" == "true" || "$artifact_dir" == *"/mock-"* || "$artifact_dir" == mock-* || "$artifact_dir" == *"/mock-pass"* || "$artifact_dir" == mock-pass* ]]; then
    fail "Listener readiness failed: mock artifact directory is not allowed under --require-real-artifacts ($artifact_dir)."
  fi
  pass "Real-artifact gate passed ($artifact_dir)."
fi

[[ "$serial_capture_present" == "true" ]] || fail "Listener readiness failed: serial capture gate is not true."
[[ "$legacy_capture_present" == "true" ]] || fail "Listener readiness failed: legacy capture gate is not true."
[[ "$field_notes_present" == "true" ]] || fail "Listener readiness failed: field notes gate is not true."
[[ "$read_only_wiring_documented" == "true" ]] || fail "Listener readiness failed: read-only wiring gate is not true."
[[ "$parity_gate_passed" == "true" ]] || fail "Listener readiness failed: parity gate is not true."
if [[ "$REQUIRE_TREND_PASS" -eq 1 ]]; then
  [[ "$trend_gate_passed" == "true" ]] || fail "Listener readiness failed: trend gate is not true."
fi
[[ "$overall_status" == "PASS" ]] || fail "Listener readiness failed: overall status is $overall_status, expected PASS."

pass "Listener readiness passed ($latest_report_json)."
