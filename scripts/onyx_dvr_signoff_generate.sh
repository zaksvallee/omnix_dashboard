#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REPORT_JSON=""
OUT_FILE=""
PROVIDER="${ONYX_DVR_PROVIDER:-hikvision_dvr}"
EXPECT_CAMERA=""
EXPECT_ZONE=""
ALLOW_MOCK_ARTIFACTS=0
ARTIFACT_DIR=""
SIGNOFF_JSON_OUT=""
RELEASE_GATE_JSON=""
RELEASE_TREND_REPORT_JSON=""
REQUIRE_RELEASE_GATE_PASS=0
REQUIRE_RELEASE_TREND_PASS=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_dvr_signoff_generate.sh [--report-json <path>] [--out <path>] [--provider <id>] [--expect-camera <camera_id>] [--expect-zone <zone>] [--release-gate-json <path>] [--release-trend-report-json <path>] [--require-release-gate-pass] [--require-release-trend-pass] [--allow-mock-artifacts]
USAGE
}

json_string() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "${1:-}"
}

write_signoff_report() {
  local status="$1"
  local summary="$2"
  local failure_code="${3:-}"
  if [[ -z "$SIGNOFF_JSON_OUT" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$SIGNOFF_JSON_OUT")"
  local generated_at
  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  cat >"$SIGNOFF_JSON_OUT" <<EOF
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
  "release_gate_json": $(json_string "$RELEASE_GATE_JSON"),
  "release_trend_report_json": $(json_string "$RELEASE_TREND_REPORT_JSON"),
  "release_gate_result": $(json_string "$( [[ -n "$RELEASE_GATE_JSON" && -f "$RELEASE_GATE_JSON" ]] && json_get "$RELEASE_GATE_JSON" "result" || true )"),
  "release_trend_status": $(json_string "$( [[ -n "$RELEASE_TREND_REPORT_JSON" && -f "$RELEASE_TREND_REPORT_JSON" ]] && json_get "$RELEASE_TREND_REPORT_JSON" "status" || true )"),
  "require_release_gate_pass": $([[ "$REQUIRE_RELEASE_GATE_PASS" -eq 1 ]] && echo true || echo false),
  "require_release_trend_pass": $([[ "$REQUIRE_RELEASE_TREND_PASS" -eq 1 ]] && echo true || echo false),
  "signoff_markdown": $(json_string "$OUT_FILE"),
  "allow_mock_artifacts": $([[ "$ALLOW_MOCK_ARTIFACTS" -eq 1 ]] && echo true || echo false)
}
EOF
}

fail() {
  local summary="$1"
  local failure_code="${2:-signoff_failed}"
  write_signoff_report "FAIL" "$summary" "$failure_code"
  echo "FAIL: $summary"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report-json) REPORT_JSON="${2:-}"; shift 2 ;;
    --out) OUT_FILE="${2:-}"; shift 2 ;;
    --provider) PROVIDER="${2:-}"; shift 2 ;;
    --expect-camera) EXPECT_CAMERA="${2:-}"; shift 2 ;;
    --expect-zone) EXPECT_ZONE="${2:-}"; shift 2 ;;
    --release-gate-json) RELEASE_GATE_JSON="${2:-}"; shift 2 ;;
    --release-trend-report-json) RELEASE_TREND_REPORT_JSON="${2:-}"; shift 2 ;;
    --require-release-gate-pass) REQUIRE_RELEASE_GATE_PASS=1; shift ;;
    --require-release-trend-pass) REQUIRE_RELEASE_TREND_PASS=1; shift ;;
    --allow-mock-artifacts) ALLOW_MOCK_ARTIFACTS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "FAIL: Unknown argument: $1"; exit 1 ;;
  esac
done

latest_validation_report_json() {
  local base_dir="tmp/dvr_field_validation"
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

if [[ -z "$REPORT_JSON" ]]; then
  REPORT_JSON="$(latest_validation_report_json || true)"
fi
if [[ -z "$REPORT_JSON" || ! -f "$REPORT_JSON" ]]; then
  echo "FAIL: DVR validation_report.json not found."
  exit 1
fi

ARTIFACT_DIR="$(json_get "$REPORT_JSON" "artifact_dir")"
if [[ -z "$ARTIFACT_DIR" ]]; then
  ARTIFACT_DIR="$(cd "$(dirname "$REPORT_JSON")" && pwd)"
fi
if [[ -z "$RELEASE_GATE_JSON" && -f "$ARTIFACT_DIR/release_gate.json" ]]; then
  RELEASE_GATE_JSON="$ARTIFACT_DIR/release_gate.json"
fi
if [[ -z "$RELEASE_TREND_REPORT_JSON" && -f "$ARTIFACT_DIR/release_trend_report.json" ]]; then
  RELEASE_TREND_REPORT_JSON="$ARTIFACT_DIR/release_trend_report.json"
fi

if [[ -z "$OUT_FILE" ]]; then
  OUT_FILE="docs/onyx_dvr_pilot_signoff_$(TZ=Africa/Johannesburg date +%Y-%m-%d).md"
fi
mkdir -p "$(dirname "$OUT_FILE")"
SIGNOFF_JSON_OUT="$(dirname "$OUT_FILE")/$(basename "$OUT_FILE" .md).json"

readiness_cmd=(./scripts/onyx_dvr_pilot_readiness_check.sh --provider "$PROVIDER" --report-json "$REPORT_JSON")
[[ -n "$EXPECT_CAMERA" ]] && readiness_cmd+=(--expect-camera "$EXPECT_CAMERA")
[[ -n "$EXPECT_ZONE" ]] && readiness_cmd+=(--expect-zone "$EXPECT_ZONE")
[[ "$ALLOW_MOCK_ARTIFACTS" -ne 1 ]] && readiness_cmd+=(--require-real-artifacts)
"${readiness_cmd[@]}" >/dev/null || fail "DVR signoff blocked: readiness gate did not pass." "readiness_not_pass"

if [[ "$REQUIRE_RELEASE_GATE_PASS" -eq 1 ]]; then
  if [[ -z "$RELEASE_GATE_JSON" || ! -f "$RELEASE_GATE_JSON" ]]; then
    fail "DVR signoff blocked: release gate artifact not found." "release_gate_not_found"
  fi
  release_gate_validation_report="$(json_get "$RELEASE_GATE_JSON" "validation_report_json")"
  release_gate_signoff_file="$(json_get "$RELEASE_GATE_JSON" "signoff_file")"
  release_gate_signoff_report="$(json_get "$RELEASE_GATE_JSON" "signoff_report_json")"
  release_gate_result="$(json_get "$RELEASE_GATE_JSON" "result" | tr '[:lower:]' '[:upper:]')"
  if [[ -n "$release_gate_validation_report" && "$release_gate_validation_report" != "$REPORT_JSON" ]]; then
    fail "DVR signoff blocked: release gate points at a different validation bundle." "release_gate_validation_report_mismatch"
  fi
  if [[ -n "$release_gate_signoff_file" && "$release_gate_signoff_file" != "$OUT_FILE" ]]; then
    fail "DVR signoff blocked: release gate points at a different signoff markdown path." "release_gate_signoff_file_mismatch"
  fi
  if [[ -n "$release_gate_signoff_report" && "$release_gate_signoff_report" != "$SIGNOFF_JSON_OUT" ]]; then
    fail "DVR signoff blocked: release gate points at a different signoff report path." "release_gate_signoff_report_mismatch"
  fi
  if [[ "$release_gate_result" != "PASS" ]]; then
    release_gate_code="$(json_get "$RELEASE_GATE_JSON" "primary_fail_code")"
    if [[ -z "$release_gate_code" ]]; then
      release_gate_code="$(json_get "$RELEASE_GATE_JSON" "primary_hold_code")"
    fi
    fail "DVR signoff blocked: release gate is ${release_gate_result:-UNKNOWN}, expected PASS." "${release_gate_code:-release_gate_not_pass}"
  fi
fi

if [[ "$REQUIRE_RELEASE_TREND_PASS" -eq 1 ]]; then
  if [[ -z "$RELEASE_TREND_REPORT_JSON" || ! -f "$RELEASE_TREND_REPORT_JSON" ]]; then
    fail "DVR signoff blocked: release trend artifact not found." "release_trend_not_found"
  fi
  release_trend_current_gate="$(json_get "$RELEASE_TREND_REPORT_JSON" "current_release_gate_json")"
  release_trend_status="$(json_get "$RELEASE_TREND_REPORT_JSON" "status" | tr '[:lower:]' '[:upper:]')"
  if [[ -n "$RELEASE_GATE_JSON" && -n "$release_trend_current_gate" && "$release_trend_current_gate" != "$RELEASE_GATE_JSON" ]]; then
    fail "DVR signoff blocked: release trend points at a different current release gate." "release_trend_current_gate_mismatch"
  fi
  if [[ "$release_trend_status" != "PASS" ]]; then
    release_trend_code="$(json_get "$RELEASE_TREND_REPORT_JSON" "primary_regression_code")"
    fail "DVR signoff blocked: release trend is ${release_trend_status:-UNKNOWN}, expected PASS." "${release_trend_code:-release_trend_not_pass}"
  fi
fi

artifact_dir="$(json_get "$REPORT_JSON" "artifact_dir")"
capture_dir="$(json_get "$REPORT_JSON" "capture_dir")"
provider="$(json_get "$REPORT_JSON" "provider")"
edge_url="$(json_get "$REPORT_JSON" "edge_url")"
event_id="$(json_get "$REPORT_JSON" "event_id")"
camera_id="$(json_get "$REPORT_JSON" "expected_camera")"
zone="$(json_get "$REPORT_JSON" "expected_zone")"
overall_status="$(json_get "$REPORT_JSON" "overall_status")"
release_gate_result=""
release_trend_status=""
if [[ -n "$RELEASE_GATE_JSON" && -f "$RELEASE_GATE_JSON" ]]; then
  release_gate_result="$(json_get "$RELEASE_GATE_JSON" "result")"
fi
if [[ -n "$RELEASE_TREND_REPORT_JSON" && -f "$RELEASE_TREND_REPORT_JSON" ]]; then
  release_trend_status="$(json_get "$RELEASE_TREND_REPORT_JSON" "status")"
fi
field_notes_file=""
if [[ -n "$capture_dir" && -f "$capture_dir/field_notes.md" ]]; then
  field_notes_file="$capture_dir/field_notes.md"
fi

{
  echo "# ONYX DVR Pilot Signoff ($(TZ=Africa/Johannesburg date +%Y-%m-%d))"
  echo
  echo "Date: $(TZ=Africa/Johannesburg date +%Y-%m-%d) (Africa/Johannesburg)"
  echo
  echo "## Scope"
  echo "- DVR host: \`${edge_url:-}\`"
  echo "- Camera: \`${camera_id:-}\`"
  echo "- Zone: \`${zone:-}\`"
  echo "- Provider: \`${provider:-$PROVIDER}\`"
  echo "- Event ID: \`${event_id:-}\`"
  echo
  echo "## Validation Commands"
  echo "- Field validation:"
  echo "  - \`./scripts/onyx_dvr_field_validation.sh --edge-url ${edge_url:-<dvr_url>} --provider ${provider:-$PROVIDER} --event-id ${event_id:-<event_id>} --expect-camera ${camera_id:-<camera_id>} --expect-zone ${zone:-<zone>} --capture-dir ${capture_dir:-tmp/dvr_capture}\`"
  echo "- Readiness gate:"
  echo "  - \`./scripts/onyx_dvr_pilot_readiness_check.sh --provider ${provider:-$PROVIDER} --expect-camera ${camera_id:-<camera_id>} --expect-zone ${zone:-<zone>} --require-real-artifacts\`"
  if [[ -n "$RELEASE_GATE_JSON" ]]; then
    echo "- Release gate artifact: \`${RELEASE_GATE_JSON}\`"
  fi
  if [[ -n "$RELEASE_TREND_REPORT_JSON" ]]; then
    echo "- Release trend artifact: \`${RELEASE_TREND_REPORT_JSON}\`"
  fi
  echo
  echo "## Results"
  echo "- Field validation overall status: \`${overall_status:-}\`"
  echo "- Readiness gate overall status: \`PASS\`"
  if [[ -n "$release_gate_result" ]]; then
    echo "- Release gate result: \`${release_gate_result}\`"
  fi
  if [[ -n "$release_trend_status" ]]; then
    echo "- Release trend status: \`${release_trend_status}\`"
  fi
  echo "- Validation artifact dir: \`${artifact_dir:-}\`"
  echo "- Capture pack dir: \`${capture_dir:-}\`"
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
  echo "- DVR pilot checklist items closed: \`$([[ "$overall_status" == "PASS" ]] && echo yes || echo no)\`"
  echo "- Remaining blockers: \`$([[ "$overall_status" == "PASS" ]] && echo none || echo review_validation_bundle)\`"
} >"$OUT_FILE"

write_signoff_report "PASS" "DVR pilot signoff generated successfully." ""
echo "PASS: DVR pilot signoff generated: $OUT_FILE"
