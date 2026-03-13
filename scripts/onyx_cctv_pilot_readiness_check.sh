#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROVIDER="${ONYX_CCTV_PROVIDER:-frigate}"
EXPECT_CAMERA=""
EXPECT_ZONE=""
REPORT_JSON=""
MAX_REPORT_AGE_HOURS="${ONYX_CCTV_MAX_VALIDATION_REPORT_AGE_HOURS:-24}"
REQUIRE_REAL_ARTIFACTS=0

pass() { printf "PASS: %s\n" "$1"; }
fail() { printf "FAIL: %s\n" "$1"; exit 1; }

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_cctv_pilot_readiness_check.sh [--provider <id>] [--expect-camera <camera_id>] [--expect-zone <zone>] [--report-json <path>] [--max-report-age-hours <hours>] [--require-real-artifacts]

Purpose:
  Validate the latest CCTV field-validation artifact under tmp/cctv_field_validation/
  and fail if the pilot evidence bundle is stale, incomplete, or corrupted.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider)
      PROVIDER="${2:-}"
      shift 2
      ;;
    --expect-camera)
      EXPECT_CAMERA="${2:-}"
      shift 2
      ;;
    --expect-zone)
      EXPECT_ZONE="${2:-}"
      shift 2
      ;;
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
  local base_dir="tmp/cctv_field_validation"
  if [[ ! -d "$base_dir" ]]; then
    return 1
  fi
  find "$base_dir" -type f -name "validation_report.json" -print0 2>/dev/null \
    | xargs -0 ls -1t 2>/dev/null \
    | head -n 1
}

latest_validation_report_md() {
  local base_dir="tmp/cctv_field_validation"
  if [[ ! -d "$base_dir" ]]; then
    return 1
  fi
  find "$base_dir" -type f -name "validation_report.md" -print0 2>/dev/null \
    | xargs -0 ls -1t 2>/dev/null \
    | head -n 1
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

files = data.get("files", {})
checksums = data.get("checksums", {})
artifact_dir = data.get("artifact_dir", "")

pairs = [
    ("edge_validation", "edge_validation_sha256"),
    ("bridges_capture", "bridges_capture_sha256"),
    ("pollops_capture", "pollops_capture_sha256"),
    ("timeline_capture", "timeline_capture_sha256"),
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

verify_integrity_certificate() {
  local report_file="$1"
  local cert_json="$2"
  local cert_md="$3"
  local artifact_dir
  artifact_dir="$(cd "$(dirname "$report_file")" && pwd)"
  if [[ -z "$cert_json" || ! -f "$cert_json" ]]; then
    echo "missing_json:${cert_json:-}"
    return 1
  fi
  if [[ "$cert_json" != "$artifact_dir/integrity_certificate.json" ]]; then
    echo "json_path_mismatch:$cert_json"
    return 1
  fi
  if [[ -z "$cert_md" || ! -f "$cert_md" ]]; then
    echo "missing_markdown:${cert_md:-}"
    return 1
  fi
  if [[ "$cert_md" != "$artifact_dir/integrity_certificate.md" ]]; then
    echo "markdown_path_mismatch:$cert_md"
    return 1
  fi
  local tmp_json tmp_md
  tmp_json="$(mktemp "$artifact_dir/integrity_certificate_check_json.XXXXXX")"
  tmp_md="$(mktemp "$artifact_dir/integrity_certificate_check_md.XXXXXX")"
  if ! ./scripts/onyx_validation_bundle_certificate.sh --report-json "$report_file" --out-json "$tmp_json" --out-md "$tmp_md" >/dev/null 2>&1; then
    rm -f "$tmp_json" "$tmp_md"
    echo "regenerate_failed"
    return 1
  fi
  if ! python3 - "$cert_json" "$tmp_json" <<'PY'
import json
import sys

current = json.load(open(sys.argv[1], "r", encoding="utf-8"))
regenerated = json.load(open(sys.argv[2], "r", encoding="utf-8"))
current.pop("generated_at_utc", None)
regenerated.pop("generated_at_utc", None)
if current != regenerated:
    raise SystemExit(1)
PY
  then
    rm -f "$tmp_json" "$tmp_md"
    echo "content_mismatch:$cert_json"
    return 1
  fi
  rm -f "$tmp_json" "$tmp_md"
  echo "ok"
}

latest_report_json="$REPORT_JSON"
if [[ -z "$latest_report_json" ]]; then
  latest_report_json="$(latest_validation_report_json || true)"
fi
latest_report_md="$(latest_validation_report_md || true)"
if [[ -z "$latest_report_json" && -z "$latest_report_md" ]]; then
  fail "No CCTV validation_report.json or validation_report.md found under tmp/cctv_field_validation."
fi
if [[ -n "$latest_report_json" && ! -f "$latest_report_json" ]]; then
  fail "Specified CCTV validation_report.json not found: $latest_report_json"
fi

latest_report="$latest_report_json"
if [[ -z "$latest_report" ]]; then
  latest_report="$latest_report_md"
fi

report_age="$(report_age_hours "$latest_report")"
if ! python3 - "$report_age" "$MAX_REPORT_AGE_HOURS" <<'PY'
import sys
age = float(sys.argv[1])
max_age = float(sys.argv[2])
raise SystemExit(0 if age <= max_age else 1)
PY
then
  fail "Latest CCTV validation report is stale (${report_age}h old > ${MAX_REPORT_AGE_HOURS}h)."
fi

overall_status=""
if [[ -n "$latest_report_json" ]]; then
  overall_status="$(json_get "$latest_report_json" "overall_status" | tr '[:lower:]' '[:upper:]')"
  artifact_dir="$(json_get "$latest_report_json" "artifact_dir")"
  report_provider="$(json_get "$latest_report_json" "provider")"
  report_camera="$(json_get "$latest_report_json" "expected_camera")"
  report_zone="$(json_get "$latest_report_json" "expected_zone")"
  first_event_captured="$(json_get "$latest_report_json" "gates.first_event_captured" | tr '[:upper:]' '[:lower:]')"
  edge_validation="$(json_get "$latest_report_json" "gates.edge_validation" | tr '[:upper:]' '[:lower:]')"
  health_visible="$(json_get "$latest_report_json" "gates.health_visible" | tr '[:upper:]' '[:lower:]')"
  camera_wired="$(json_get "$latest_report_json" "gates.camera_wired" | tr '[:upper:]' '[:lower:]')"
  verify_result="$(verify_json_report_checksums "$latest_report_json")" || fail "CCTV validation checksum verification failed: $verify_result"
  pass "CCTV validation checksums verified."
  cert_verify_result="$(verify_integrity_certificate "$latest_report_json" "$artifact_dir/integrity_certificate.json" "$artifact_dir/integrity_certificate.md")" || fail "CCTV integrity certificate verification failed: $cert_verify_result"
  pass "CCTV integrity certificate verified."

  if [[ "$REQUIRE_REAL_ARTIFACTS" -eq 1 ]]; then
    if [[ "$artifact_dir" == *"/mock-"* || "$artifact_dir" == mock-* || "$artifact_dir" == *"/mock-pass"* || "$artifact_dir" == mock-pass* ]]; then
      fail "CCTV readiness failed: mock artifact directory is not allowed under --require-real-artifacts ($artifact_dir)."
    fi
    pass "Real-artifact gate passed ($artifact_dir)."
  fi

  if [[ -n "$PROVIDER" && -n "$report_provider" && "$report_provider" != "$PROVIDER" ]]; then
    fail "CCTV validation provider mismatch: report=$report_provider expected=$PROVIDER."
  fi
  if [[ -n "$EXPECT_CAMERA" && -n "$report_camera" && "$report_camera" != "$EXPECT_CAMERA" ]]; then
    fail "CCTV validation camera mismatch: report=$report_camera expected=$EXPECT_CAMERA."
  fi
  if [[ -n "$EXPECT_ZONE" && -n "$report_zone" && "$report_zone" != "$EXPECT_ZONE" ]]; then
    fail "CCTV validation zone mismatch: report=$report_zone expected=$EXPECT_ZONE."
  fi
  if [[ "$edge_validation" != "true" ]]; then
    fail "CCTV readiness failed: edge validation gate is not true."
  fi
  if [[ "$health_visible" != "true" ]]; then
    fail "CCTV readiness failed: health visibility gate is not true."
  fi
  if [[ "$camera_wired" != "true" ]]; then
    fail "CCTV readiness failed: camera wiring gate is not true."
  fi
  if [[ "$first_event_captured" != "true" ]]; then
    fail "CCTV readiness failed: first end-to-end event gate is not true."
  fi
fi

if [[ -z "$overall_status" && -n "$latest_report_md" ]]; then
  if grep -q "Overall status: PASS" "$latest_report_md" || grep -q "Overall status: \*\*PASS\*\*" "$latest_report_md"; then
    overall_status="PASS"
  else
    overall_status="FAIL"
  fi
fi

if [[ "$overall_status" != "PASS" ]]; then
  fail "CCTV readiness failed: latest report overall_status is not PASS ($latest_report)."
fi

pass "CCTV readiness passed ($latest_report, age=${report_age}h)."
