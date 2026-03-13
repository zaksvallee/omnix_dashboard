#!/usr/bin/env bash
set -euo pipefail

REPORT_JSON=""
MAX_REPORT_AGE_HOURS=24
ALLOW_UNMATCHED_SERIAL=0
ALLOW_UNMATCHED_LEGACY=0
REQUIRE_REAL_ARTIFACTS=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_parity_readiness_check.sh [--report-json <path>] [--max-report-age-hours 24] [--allow-unmatched-serial] [--allow-unmatched-legacy] [--require-real-artifacts]

Purpose:
  Validate the latest listener parity report and fail when the dual-path pilot
  evidence is stale, corrupted, or still diverging beyond the allowed gates.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report-json)
      REPORT_JSON="${2:-}"
      shift 2
      ;;
    --max-report-age-hours)
      MAX_REPORT_AGE_HOURS="${2:-24}"
      shift 2
      ;;
    --allow-unmatched-serial)
      ALLOW_UNMATCHED_SERIAL=1
      shift
      ;;
    --allow-unmatched-legacy)
      ALLOW_UNMATCHED_LEGACY=1
      shift
      ;;
    --require-real-artifacts)
      REQUIRE_REAL_ARTIFACTS=1
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

artifact_dir = data.get("artifact_dir", "")
files = data.get("files", {})
checksums = data.get("checksums", {})

for file_key, checksum_key in (
    ("serial_input", "serial_input_sha256"),
    ("legacy_input", "legacy_input_sha256"),
):
    path = files.get(file_key, "")
    expected = checksums.get(checksum_key, "")
    if not path or not expected:
        raise SystemExit(f"missing-metadata:{file_key}")
    if not os.path.isfile(path):
        raise SystemExit(f"missing-file:{file_key}:{path}")
    digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
    if digest != expected:
        raise SystemExit(f"checksum:{file_key}:{path}")

if artifact_dir and not os.path.isdir(artifact_dir):
    raise SystemExit(f"artifact-dir:{artifact_dir}")
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

if [[ -z "$REPORT_JSON" ]]; then
  REPORT_JSON="$(latest_report_json || true)"
fi
if [[ -z "$REPORT_JSON" || ! -f "$REPORT_JSON" ]]; then
  echo "FAIL: listener parity report not found."
  exit 1
fi

report_age="$(report_age_hours "$REPORT_JSON")"
if ! python3 - "$report_age" "$MAX_REPORT_AGE_HOURS" <<'PY'
import sys
age = float(sys.argv[1])
max_age = float(sys.argv[2])
raise SystemExit(0 if age <= max_age else 1)
PY
then
  echo "FAIL: listener parity report is stale (${report_age}h old > ${MAX_REPORT_AGE_HOURS}h)."
  exit 1
fi

verify_json_report_checksums "$REPORT_JSON"
echo "PASS: Listener parity checksums verified."

artifact_dir="$(json_get "$REPORT_JSON" "artifact_dir")"
matched_count="$(json_get "$REPORT_JSON" "matched_count")"
unmatched_serial_count="$(json_get "$REPORT_JSON" "unmatched_serial_count")"
unmatched_legacy_count="$(json_get "$REPORT_JSON" "unmatched_legacy_count")"
summary="$(json_get "$REPORT_JSON" "summary")"

if [[ "$REQUIRE_REAL_ARTIFACTS" -eq 1 ]]; then
  if [[ "$artifact_dir" == *"/mock-"* || "$artifact_dir" == mock-* ]]; then
    echo "FAIL: mock artifact directory is not allowed under --require-real-artifacts ($artifact_dir)."
    exit 1
  fi
  echo "PASS: Real-artifact gate passed ($artifact_dir)."
fi

if [[ "${matched_count:-0}" -lt 1 ]]; then
  echo "FAIL: listener parity report has no matched events."
  exit 1
fi
if [[ "$ALLOW_UNMATCHED_SERIAL" -ne 1 && "${unmatched_serial_count:-0}" -gt 0 ]]; then
  echo "FAIL: listener parity report has serial-only events ($unmatched_serial_count)."
  exit 1
fi
if [[ "$ALLOW_UNMATCHED_LEGACY" -ne 1 && "${unmatched_legacy_count:-0}" -gt 0 ]]; then
  echo "FAIL: listener parity report has legacy-only events ($unmatched_legacy_count)."
  exit 1
fi

echo "PASS: Listener parity readiness passed."
echo "Report: $REPORT_JSON"
echo "Summary: $summary"
