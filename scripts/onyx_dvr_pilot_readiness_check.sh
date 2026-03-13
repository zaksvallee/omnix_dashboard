#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROVIDER="${ONYX_DVR_PROVIDER:-hikvision_dvr}"
EXPECT_CAMERA=""
EXPECT_ZONE=""
REPORT_JSON=""
MAX_REPORT_AGE_HOURS="${ONYX_DVR_MAX_VALIDATION_REPORT_AGE_HOURS:-24}"
REQUIRE_REAL_ARTIFACTS=0
ARTIFACT_DIR=""
READINESS_JSON_OUT=""
READINESS_MD_OUT=""
REPORT_AGE_HOURS_VALUE=""
RELEASE_GATE_JSON=""
RELEASE_TREND_REPORT_JSON=""
REQUIRE_RELEASE_GATE_PASS=0
REQUIRE_RELEASE_TREND_PASS=0

pass() { printf "PASS: %s\n" "$1"; }
json_string() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "${1:-}"
}

write_readiness_report() {
  local status="$1"
  local summary="$2"
  local failure_code="${3:-}"
  if [[ -z "$READINESS_JSON_OUT" || -z "$READINESS_MD_OUT" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$READINESS_JSON_OUT")"
  mkdir -p "$(dirname "$READINESS_MD_OUT")"
  local generated_at
  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cat >"$READINESS_JSON_OUT" <<EOF
{
  "generated_at_utc": $(json_string "$generated_at"),
  "status": $(json_string "$status"),
  "failure_code": $(json_string "$failure_code"),
  "summary": $(json_string "$summary"),
  "provider": $(json_string "$PROVIDER"),
  "expected_camera": $(json_string "$EXPECT_CAMERA"),
  "expected_zone": $(json_string "$EXPECT_ZONE"),
  "report_json": $(json_string "$REPORT_JSON"),
  "artifact_dir": $(json_string "$ARTIFACT_DIR"),
  "max_report_age_hours": $(json_string "$MAX_REPORT_AGE_HOURS"),
  "require_real_artifacts": $([[ "$REQUIRE_REAL_ARTIFACTS" -eq 1 ]] && echo true || echo false),
  "report_age_hours": $(json_string "$REPORT_AGE_HOURS_VALUE"),
  "resolved_files": {
    "validation_report_json": $(json_string "$REPORT_JSON"),
    "release_gate_json": $(json_string "$RELEASE_GATE_JSON"),
    "release_trend_report_json": $(json_string "$RELEASE_TREND_REPORT_JSON")
  }
}
EOF
  {
    echo "# ONYX DVR Readiness Report"
    echo
    echo "- Generated: $generated_at"
    echo "- Status: $status"
    echo "- Failure code: ${failure_code:-none}"
    echo "- Provider: ${PROVIDER:-}"
    echo "- Expected camera: ${EXPECT_CAMERA:-}"
    echo "- Expected zone: ${EXPECT_ZONE:-}"
    echo "- Validation report: ${REPORT_JSON:-}"
    echo "- Release gate report: ${RELEASE_GATE_JSON:-}"
    echo "- Release trend report: ${RELEASE_TREND_REPORT_JSON:-}"
    echo "- Validation artifact dir: ${ARTIFACT_DIR:-}"
    echo "- Max report age hours: ${MAX_REPORT_AGE_HOURS:-}"
    echo "- Require real artifacts: $([[ "$REQUIRE_REAL_ARTIFACTS" -eq 1 ]] && echo yes || echo no)"
    echo "- Require release gate pass: $([[ "$REQUIRE_RELEASE_GATE_PASS" -eq 1 ]] && echo yes || echo no)"
    echo "- Require release trend pass: $([[ "$REQUIRE_RELEASE_TREND_PASS" -eq 1 ]] && echo yes || echo no)"
    echo "- Report age hours: ${REPORT_AGE_HOURS_VALUE:-}"
    echo
    echo "## Summary"
    echo "$summary"
  } >"$READINESS_MD_OUT"
}

fail() {
  local summary="$1"
  local failure_code="${2:-readiness_failed}"
  write_readiness_report "FAIL" "$summary" "$failure_code"
  printf "FAIL: %s\n" "$summary"
  exit 1
}

conclude_pass() {
  local summary="$1"
  write_readiness_report "PASS" "$summary" ""
  printf "PASS: %s\n" "$summary"
  exit 0
}

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_dvr_pilot_readiness_check.sh [--provider <id>] [--expect-camera <camera_id>] [--expect-zone <zone>] [--report-json <path>] [--release-gate-json <path>] [--release-trend-report-json <path>] [--max-report-age-hours <hours>] [--require-real-artifacts] [--require-release-gate-pass] [--require-release-trend-pass]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider) PROVIDER="${2:-}"; shift 2 ;;
    --expect-camera) EXPECT_CAMERA="${2:-}"; shift 2 ;;
    --expect-zone) EXPECT_ZONE="${2:-}"; shift 2 ;;
    --report-json) REPORT_JSON="${2:-}"; shift 2 ;;
    --release-gate-json) RELEASE_GATE_JSON="${2:-}"; shift 2 ;;
    --release-trend-report-json) RELEASE_TREND_REPORT_JSON="${2:-}"; shift 2 ;;
    --max-report-age-hours) MAX_REPORT_AGE_HOURS="${2:-}"; shift 2 ;;
    --require-real-artifacts) REQUIRE_REAL_ARTIFACTS=1; shift ;;
    --require-release-gate-pass) REQUIRE_RELEASE_GATE_PASS=1; shift ;;
    --require-release-trend-pass) REQUIRE_RELEASE_TREND_PASS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

if ! [[ "$MAX_REPORT_AGE_HOURS" =~ ^[0-9]+$ ]]; then
  fail "--max-report-age-hours must be a non-negative integer."
fi

latest_validation_report_json() {
  local base_dir="tmp/dvr_field_validation"
  if [[ ! -d "$base_dir" ]]; then
    return 1
  fi
  find "$base_dir" -type f -name "validation_report.json" -print0 2>/dev/null \
    | xargs -0 ls -1t 2>/dev/null \
    | head -n 1
}

report_age_hours() {
  local report_file="$1"
  python3 - "$report_file" <<'PY'
import os, sys, time
print(f"{((time.time() - os.path.getmtime(sys.argv[1])) / 3600.0):.2f}")
PY
}

json_get() {
  local report_file="$1"
  local expression="$2"
  python3 - "$report_file" "$expression" <<'PY'
import json, sys
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

json_get_optional() {
  local report_file="$1"
  local expression="$2"
  if [[ -z "$report_file" || ! -f "$report_file" ]]; then
    echo ""
    return 0
  fi
  json_get "$report_file" "$expression"
}

verify_json_report_checksums() {
  local report_file="$1"
  python3 - "$report_file" <<'PY'
import hashlib, json, os, sys
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)
files = data.get("files", {})
checksums = data.get("checksums", {})
for file_key, checksum_key in [
    ("edge_validation", "edge_validation_sha256"),
    ("events_response", "events_response_sha256"),
    ("bridges_capture", "bridges_capture_sha256"),
    ("pollops_capture", "pollops_capture_sha256"),
    ("timeline_capture", "timeline_capture_sha256"),
    ("markdown_report", "markdown_report_sha256"),
]:
    path = files.get(file_key, "")
    expected = checksums.get(checksum_key, "")
    if not path or not expected:
        continue
    if not os.path.isfile(path):
        raise SystemExit(f"missing:{file_key}:{path}")
    digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
    if digest != expected:
        raise SystemExit(f"checksum:{file_key}:{path}")
print("ok")
PY
}

if [[ -z "$REPORT_JSON" ]]; then
  REPORT_JSON="$(latest_validation_report_json || true)"
fi
if [[ -z "$REPORT_JSON" || ! -f "$REPORT_JSON" ]]; then
  fail "DVR validation_report.json not found." "validation_report_not_found"
fi

ARTIFACT_DIR="$(json_get "$REPORT_JSON" "artifact_dir")"
if [[ -z "$ARTIFACT_DIR" ]]; then
  ARTIFACT_DIR="$(cd "$(dirname "$REPORT_JSON")" && pwd)"
fi
READINESS_JSON_OUT="$ARTIFACT_DIR/readiness_report.json"
READINESS_MD_OUT="$ARTIFACT_DIR/readiness_report.md"
if [[ -z "$RELEASE_GATE_JSON" && -f "$ARTIFACT_DIR/release_gate.json" ]]; then
  RELEASE_GATE_JSON="$ARTIFACT_DIR/release_gate.json"
fi
if [[ -z "$RELEASE_TREND_REPORT_JSON" && -f "$ARTIFACT_DIR/release_trend_report.json" ]]; then
  RELEASE_TREND_REPORT_JSON="$ARTIFACT_DIR/release_trend_report.json"
fi

REPORT_AGE_HOURS_VALUE="$(report_age_hours "$REPORT_JSON")"
if ! python3 - "$REPORT_AGE_HOURS_VALUE" "$MAX_REPORT_AGE_HOURS" <<'PY'
import sys
raise SystemExit(0 if float(sys.argv[1]) <= float(sys.argv[2]) else 1)
PY
then
  fail "Latest DVR validation report is stale (${REPORT_AGE_HOURS_VALUE}h old > ${MAX_REPORT_AGE_HOURS}h)." "validation_report_stale"
fi

verify_result="$(verify_json_report_checksums "$REPORT_JSON")" || fail "DVR validation checksum verification failed: $verify_result" "validation_checksum_failed"
pass "DVR validation checksums verified."

overall_status="$(json_get "$REPORT_JSON" "overall_status" | tr '[:lower:]' '[:upper:]')"
artifact_dir="$(json_get "$REPORT_JSON" "artifact_dir")"
is_mock="$(json_get "$REPORT_JSON" "is_mock" | tr '[:upper:]' '[:lower:]')"
report_provider="$(json_get "$REPORT_JSON" "provider")"
report_camera="$(json_get "$REPORT_JSON" "expected_camera")"
report_zone="$(json_get "$REPORT_JSON" "expected_zone")"

if [[ "$REQUIRE_REAL_ARTIFACTS" -eq 1 && "$is_mock" == "true" ]]; then
  fail "DVR readiness failed: mock artifacts are not allowed under --require-real-artifacts." "mock_artifacts_not_allowed"
fi
if [[ "$REQUIRE_REAL_ARTIFACTS" -eq 1 ]]; then
  pass "Real-artifact gate passed ($artifact_dir)."
fi

if [[ -n "$PROVIDER" && -n "$report_provider" && "$report_provider" != "$PROVIDER" ]]; then
  fail "DVR validation provider mismatch: report=$report_provider expected=$PROVIDER." "provider_mismatch"
fi
if [[ -n "$EXPECT_CAMERA" && -n "$report_camera" && "$report_camera" != "$EXPECT_CAMERA" ]]; then
  fail "DVR validation camera mismatch: report=$report_camera expected=$EXPECT_CAMERA." "camera_mismatch"
fi
if [[ -n "$EXPECT_ZONE" && -n "$report_zone" && "$report_zone" != "$EXPECT_ZONE" ]]; then
  fail "DVR validation zone mismatch: report=$report_zone expected=$EXPECT_ZONE." "zone_mismatch"
fi

for gate in edge_validation snapshot_validation clip_validation bridges_validation pollops_validation timeline_validation camera_wired health_visible first_event_captured; do
  gate_value="$(json_get "$REPORT_JSON" "gates.$gate" | tr '[:upper:]' '[:lower:]')"
  if [[ "$gate_value" != "true" ]]; then
    fail "DVR readiness failed: $gate gate is not true." "${gate}_false"
  fi
done

if [[ "$overall_status" != "PASS" ]]; then
  fail "DVR readiness failed: latest report overall_status is not PASS ($REPORT_JSON)." "overall_status_not_pass"
fi

if [[ "$REQUIRE_RELEASE_GATE_PASS" -eq 1 ]]; then
  if [[ -z "$RELEASE_GATE_JSON" || ! -f "$RELEASE_GATE_JSON" ]]; then
    fail "DVR readiness failed: release gate artifact was not found under --require-release-gate-pass." "release_gate_not_found"
  fi
  if [[ "$RELEASE_GATE_JSON" != "$ARTIFACT_DIR/release_gate.json" ]]; then
    fail "DVR readiness failed: release gate does not use the canonical staged filename." "release_gate_name_mismatch"
  fi
  release_gate_validation_report="$(json_get "$RELEASE_GATE_JSON" "validation_report_json")"
  release_gate_signoff_file="$(json_get "$RELEASE_GATE_JSON" "signoff_file")"
  release_gate_signoff_report="$(json_get "$RELEASE_GATE_JSON" "signoff_report_json")"
  release_gate_signoff_status="$(json_get "$RELEASE_GATE_JSON" "statuses.signoff_status" | tr '[:lower:]' '[:upper:]')"
  release_gate_result="$(json_get "$RELEASE_GATE_JSON" "result" | tr '[:lower:]' '[:upper:]')"
  if [[ -n "$release_gate_validation_report" && "$release_gate_validation_report" != "$REPORT_JSON" ]]; then
    fail "DVR readiness failed: release gate validation report does not match the active validation bundle." "release_gate_validation_report_mismatch"
  fi
  if [[ -n "$release_gate_signoff_file" && "$release_gate_signoff_file" != "$ARTIFACT_DIR/$(basename "$release_gate_signoff_file")" ]]; then
    fail "DVR readiness failed: release gate signoff markdown is not staged under the active artifact dir." "release_gate_signoff_file_path_mismatch"
  fi
  if [[ -n "$release_gate_signoff_report" && "$release_gate_signoff_report" != "$ARTIFACT_DIR/$(basename "$release_gate_signoff_report")" ]]; then
    fail "DVR readiness failed: release gate signoff report is not staged under the active artifact dir." "release_gate_signoff_report_path_mismatch"
  fi
  if [[ -n "$release_gate_signoff_file" && "$release_gate_signoff_file" != "$ARTIFACT_DIR/dvr_pilot_signoff.md" ]]; then
    fail "DVR readiness failed: release gate signoff markdown does not use the canonical staged filename." "release_gate_signoff_file_name_mismatch"
  fi
  if [[ -n "$release_gate_signoff_report" && "$release_gate_signoff_report" != "$ARTIFACT_DIR/dvr_pilot_signoff.json" ]]; then
    fail "DVR readiness failed: release gate signoff report does not use the canonical staged filename." "release_gate_signoff_report_name_mismatch"
  fi
  if [[ -n "$release_gate_signoff_report" && -f "$release_gate_signoff_report" ]]; then
    signoff_report_validation="$(json_get_optional "$release_gate_signoff_report" "report_json")"
    signoff_report_release_gate="$(json_get_optional "$release_gate_signoff_report" "release_gate_json")"
    signoff_report_markdown="$(json_get_optional "$release_gate_signoff_report" "signoff_markdown")"
    signoff_report_status="$(json_get_optional "$release_gate_signoff_report" "status" | tr '[:lower:]' '[:upper:]')"
    if [[ -n "$signoff_report_validation" && "$signoff_report_validation" != "$REPORT_JSON" ]]; then
      fail "DVR readiness failed: release gate signoff report points at a different validation bundle." "release_gate_signoff_validation_report_mismatch"
    fi
    if [[ -n "$signoff_report_release_gate" && "$signoff_report_release_gate" != "$RELEASE_GATE_JSON" ]]; then
      fail "DVR readiness failed: release gate signoff report points at a different release gate artifact." "release_gate_signoff_release_gate_mismatch"
    fi
    if [[ -n "$release_gate_signoff_file" && -n "$signoff_report_markdown" && "$signoff_report_markdown" != "$release_gate_signoff_file" ]]; then
      fail "DVR readiness failed: release gate signoff report markdown path does not match the release gate signoff markdown." "release_gate_signoff_markdown_mismatch"
    fi
    if [[ -n "$release_gate_signoff_status" && -n "$signoff_report_status" && "$release_gate_signoff_status" != "$signoff_report_status" ]]; then
      fail "DVR readiness failed: release gate signoff status does not match the referenced signoff report." "release_gate_signoff_status_mismatch"
    fi
  fi
  if [[ "$release_gate_result" != "PASS" ]]; then
    release_gate_primary_code="$(json_get "$RELEASE_GATE_JSON" "primary_fail_code")"
    if [[ -z "$release_gate_primary_code" ]]; then
      release_gate_primary_code="$(json_get "$RELEASE_GATE_JSON" "primary_hold_code")"
    fi
    fail "DVR readiness failed: release gate is ${release_gate_result:-UNKNOWN}, expected PASS." "${release_gate_primary_code:-release_gate_not_pass}"
  fi
fi

if [[ "$REQUIRE_RELEASE_TREND_PASS" -eq 1 ]]; then
  if [[ -z "$RELEASE_TREND_REPORT_JSON" || ! -f "$RELEASE_TREND_REPORT_JSON" ]]; then
    fail "DVR readiness failed: release trend artifact was not found under --require-release-trend-pass." "release_trend_not_found"
  fi
  if [[ "$RELEASE_TREND_REPORT_JSON" != "$ARTIFACT_DIR/release_trend_report.json" ]]; then
    fail "DVR readiness failed: release trend does not use the canonical staged filename." "release_trend_name_mismatch"
  fi
  release_trend_current_gate="$(json_get "$RELEASE_TREND_REPORT_JSON" "current_release_gate_json")"
  release_trend_previous_gate="$(json_get "$RELEASE_TREND_REPORT_JSON" "previous_release_gate_json")"
  release_trend_status="$(json_get "$RELEASE_TREND_REPORT_JSON" "status" | tr '[:lower:]' '[:upper:]')"
  if [[ -n "$RELEASE_GATE_JSON" && -n "$release_trend_current_gate" && "$release_trend_current_gate" != "$RELEASE_GATE_JSON" ]]; then
    fail "DVR readiness failed: release trend current gate does not match the active release gate artifact." "release_trend_current_gate_mismatch"
  fi
  if [[ -z "$release_trend_previous_gate" ]]; then
    fail "DVR readiness failed: release trend is missing its previous release gate reference." "release_trend_previous_gate_missing"
  fi
  if [[ ! -f "$release_trend_previous_gate" ]]; then
    fail "DVR readiness failed: release trend previous gate artifact was not found." "release_trend_previous_gate_not_found"
  fi
  if [[ -n "$release_trend_previous_gate" && "$(basename "$release_trend_previous_gate")" != "release_gate.json" ]]; then
    fail "DVR readiness failed: release trend previous gate does not use the canonical staged filename." "release_trend_previous_gate_name_mismatch"
  fi
  if [[ "$release_trend_status" != "PASS" ]]; then
    release_trend_primary_code="$(json_get "$RELEASE_TREND_REPORT_JSON" "primary_regression_code")"
    fail "DVR readiness failed: release trend is ${release_trend_status:-UNKNOWN}, expected PASS." "${release_trend_primary_code:-release_trend_not_pass}"
  fi
fi

conclude_pass "DVR readiness passed ($REPORT_JSON, age=${REPORT_AGE_HOURS_VALUE}h)."
