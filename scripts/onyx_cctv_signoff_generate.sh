#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REPORT_JSON=""
OUT_FILE=""
JSON_OUT_FILE=""
PROVIDER="${ONYX_CCTV_PROVIDER:-frigate}"
EXPECT_CAMERA=""
EXPECT_ZONE=""
ALLOW_MOCK_ARTIFACTS=0
RELEASE_GATE_JSON=""
RELEASE_TREND_REPORT_JSON=""
REQUIRE_RELEASE_GATE_PASS=0
REQUIRE_RELEASE_TREND_PASS=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_cctv_signoff_generate.sh [--report-json <path>] [--out <path>] [--json-out <path>] [--provider <id>] [--expect-camera <camera_id>] [--expect-zone <zone>] [--release-gate-json <path>] [--release-trend-report-json <path>] [--require-release-gate-pass] [--require-release-trend-pass] [--allow-mock-artifacts]

Purpose:
  Generate a CCTV pilot signoff note from the latest validation artifact and the
  capture-pack field notes. Real-artifact readiness is enforced by default.
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
    --json-out)
      JSON_OUT_FILE="${2:-}"
      shift 2
      ;;
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
    --release-gate-json)
      RELEASE_GATE_JSON="${2:-}"
      shift 2
      ;;
    --release-trend-report-json)
      RELEASE_TREND_REPORT_JSON="${2:-}"
      shift 2
      ;;
    --require-release-gate-pass)
      REQUIRE_RELEASE_GATE_PASS=1
      shift
      ;;
    --require-release-trend-pass)
      REQUIRE_RELEASE_TREND_PASS=1
      shift
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

latest_validation_report_json() {
  local base_dir="tmp/cctv_field_validation"
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

write_signoff_json() {
  local status="$1"
  local failure_code="$2"
  local readiness_status="$3"
  local require_real_artifacts="$4"
  local provider_value="$5"
  local camera_value="$6"
  local zone_value="$7"
  local overall_status="$8"
  local artifact_dir="$9"
  local capture_dir="${10}"
  local integrity_json="${11}"
  local integrity_md="${12}"
  local integrity_status="${13}"
  local release_gate_json="${14}"
  local release_trend_report_json="${15}"
  local release_gate_result="${16}"
  local release_trend_status="${17}"
  local require_release_gate_pass="${18}"
  local require_release_trend_pass="${19}"
  python3 - "$JSON_OUT_FILE" "$status" "$failure_code" "$REPORT_JSON" "$OUT_FILE" "$provider_value" "$camera_value" "$zone_value" "$require_real_artifacts" "$readiness_status" "$overall_status" "$artifact_dir" "$capture_dir" "$integrity_json" "$integrity_md" "$integrity_status" "$release_gate_json" "$release_trend_report_json" "$release_gate_result" "$release_trend_status" "$require_release_gate_pass" "$require_release_trend_pass" <<'PY'
import json
import sys
from pathlib import Path

out_path = Path(sys.argv[1])
payload = {
    "status": sys.argv[2],
    "failure_code": sys.argv[3],
    "report_json": sys.argv[4],
    "signoff_file": sys.argv[5],
    "provider": sys.argv[6],
    "expected_camera": sys.argv[7],
    "expected_zone": sys.argv[8],
    "require_real_artifacts": sys.argv[9] == "true",
    "readiness_status": sys.argv[10],
    "validation_overall_status": sys.argv[11],
    "artifact_dir": sys.argv[12],
    "capture_dir": sys.argv[13],
    "integrity_certificate_json": sys.argv[14],
    "integrity_certificate_markdown": sys.argv[15],
    "integrity_certificate_status": sys.argv[16],
    "release_gate_json": sys.argv[17],
    "release_trend_report_json": sys.argv[18],
    "release_gate_result": sys.argv[19],
    "release_trend_status": sys.argv[20],
    "require_release_gate_pass": sys.argv[21] == "true",
    "require_release_trend_pass": sys.argv[22] == "true",
}
out_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
PY
}

if [[ -z "$REPORT_JSON" ]]; then
  REPORT_JSON="$(latest_validation_report_json || true)"
fi
if [[ -z "$OUT_FILE" ]]; then
  local_date="$(TZ=Africa/Johannesburg date +%Y-%m-%d)"
  OUT_FILE="docs/onyx_cctv_pilot_signoff_${local_date}.md"
fi
if [[ -z "$JSON_OUT_FILE" ]]; then
  JSON_OUT_FILE="${OUT_FILE%.md}.json"
fi
mkdir -p "$(dirname "$OUT_FILE")"
mkdir -p "$(dirname "$JSON_OUT_FILE")"
if [[ -z "$REPORT_JSON" || ! -f "$REPORT_JSON" ]]; then
  write_signoff_json "FAIL" "validation_report_not_found" "" "$([[ "$ALLOW_MOCK_ARTIFACTS" -eq 1 ]] && echo false || echo true)" "$PROVIDER" "$EXPECT_CAMERA" "$EXPECT_ZONE" "" "" "" "" "" "" "$RELEASE_GATE_JSON" "$RELEASE_TREND_REPORT_JSON" "" "" "$([[ "$REQUIRE_RELEASE_GATE_PASS" -eq 1 ]] && echo true || echo false)" "$([[ "$REQUIRE_RELEASE_TREND_PASS" -eq 1 ]] && echo true || echo false)"
  echo "FAIL: validation_report.json not found."
  echo "Signoff JSON: $JSON_OUT_FILE"
  exit 1
fi

readiness_cmd=(
  ./scripts/onyx_cctv_pilot_readiness_check.sh
  --provider "$PROVIDER"
  --report-json "$REPORT_JSON"
)
if [[ -n "$EXPECT_CAMERA" ]]; then
  readiness_cmd+=(--expect-camera "$EXPECT_CAMERA")
fi
if [[ -n "$EXPECT_ZONE" ]]; then
  readiness_cmd+=(--expect-zone "$EXPECT_ZONE")
fi
if [[ "$ALLOW_MOCK_ARTIFACTS" -ne 1 ]]; then
  readiness_cmd+=(--require-real-artifacts)
fi
if [[ -n "$RELEASE_GATE_JSON" ]]; then
  readiness_cmd+=(--release-gate-json "$RELEASE_GATE_JSON")
fi
if [[ -n "$RELEASE_TREND_REPORT_JSON" ]]; then
  readiness_cmd+=(--release-trend-report-json "$RELEASE_TREND_REPORT_JSON")
fi
if [[ "$REQUIRE_RELEASE_GATE_PASS" -eq 1 ]]; then
  readiness_cmd+=(--require-release-gate-pass)
fi
if [[ "$REQUIRE_RELEASE_TREND_PASS" -eq 1 ]]; then
  readiness_cmd+=(--require-release-trend-pass)
fi

artifact_dir="$(json_get "$REPORT_JSON" "artifact_dir")"
capture_dir="$(json_get "$REPORT_JSON" "capture_dir")"
provider="$(json_get "$REPORT_JSON" "provider")"
overall_status="$(json_get "$REPORT_JSON" "overall_status")"
if [[ -z "$RELEASE_GATE_JSON" && -f "$artifact_dir/release_gate.json" ]]; then
  RELEASE_GATE_JSON="$artifact_dir/release_gate.json"
fi
if [[ -z "$RELEASE_TREND_REPORT_JSON" && -f "$artifact_dir/release_trend_report.json" ]]; then
  RELEASE_TREND_REPORT_JSON="$artifact_dir/release_trend_report.json"
fi
integrity_certificate_json="$artifact_dir/integrity_certificate.json"
integrity_certificate_md="$artifact_dir/integrity_certificate.md"
integrity_status=""
if [[ -f "$integrity_certificate_json" ]]; then
  integrity_status="$(json_get "$integrity_certificate_json" "status" | tr '[:lower:]' '[:upper:]')"
fi
require_real_artifacts="$([[ "$ALLOW_MOCK_ARTIFACTS" -eq 1 ]] && echo false || echo true)"
release_gate_result=""
release_trend_status=""
if [[ -n "$RELEASE_GATE_JSON" && -f "$RELEASE_GATE_JSON" ]]; then
  release_gate_result="$(json_get "$RELEASE_GATE_JSON" "result" | tr '[:lower:]' '[:upper:]')"
fi
if [[ -n "$RELEASE_TREND_REPORT_JSON" && -f "$RELEASE_TREND_REPORT_JSON" ]]; then
  release_trend_status="$(json_get "$RELEASE_TREND_REPORT_JSON" "status" | tr '[:lower:]' '[:upper:]')"
fi

if ! "${readiness_cmd[@]}" >/dev/null; then
  write_signoff_json "FAIL" "readiness_not_pass" "FAIL" "$require_real_artifacts" "${provider:-$PROVIDER}" "$EXPECT_CAMERA" "$EXPECT_ZONE" "$overall_status" "$artifact_dir" "$capture_dir" "$integrity_certificate_json" "$integrity_certificate_md" "$integrity_status" "$RELEASE_GATE_JSON" "$RELEASE_TREND_REPORT_JSON" "$release_gate_result" "$release_trend_status" "$([[ "$REQUIRE_RELEASE_GATE_PASS" -eq 1 ]] && echo true || echo false)" "$([[ "$REQUIRE_RELEASE_TREND_PASS" -eq 1 ]] && echo true || echo false)"
  echo "FAIL: CCTV signoff blocked: readiness did not pass."
  echo "Signoff JSON: $JSON_OUT_FILE"
  exit 1
fi

edge_url="$(json_get "$REPORT_JSON" "edge_url")"
event_id="$(json_get "$REPORT_JSON" "event_id")"
camera_id="$(json_get "$REPORT_JSON" "expected_camera")"
zone="$(json_get "$REPORT_JSON" "expected_zone")"
bridges_ok="$(json_get "$REPORT_JSON" "gates.bridges_validation")"
pollops_ok="$(json_get "$REPORT_JSON" "gates.pollops_validation")"
timeline_ok="$(json_get "$REPORT_JSON" "gates.timeline_validation")"
first_event_ok="$(json_get "$REPORT_JSON" "gates.first_event_captured")"

field_notes_file=""
if [[ -n "$capture_dir" && -f "$capture_dir/field_notes.md" ]]; then
  field_notes_file="$capture_dir/field_notes.md"
fi

{
  echo "# ONYX CCTV Pilot Signoff ($(TZ=Africa/Johannesburg date +%Y-%m-%d))"
  echo
  echo "Date: $(TZ=Africa/Johannesburg date +%Y-%m-%d) (Africa/Johannesburg)"
  echo
  echo "## Scope"
  echo "- Pilot site: \`${SITE_ID:-$(basename "$capture_dir" 2>/dev/null || echo "")}\`"
  echo "- Edge host: \`${edge_url:-}\`"
  echo "- Camera: \`${camera_id:-}\`"
  echo "- Zone: \`${zone:-}\`"
  echo "- Provider: \`${provider:-$PROVIDER}\`"
  echo "- Event ID: \`${event_id:-}\`"
  echo
  echo "## Validation Commands"
  echo "- Field validation:"
  echo "  - \`./scripts/onyx_cctv_field_validation.sh --edge-url ${edge_url:-<edge_url>} --event-id ${event_id:-<event_id>} --expect-camera ${camera_id:-<camera_id>} --expect-zone ${zone:-<zone>} --capture-dir ${capture_dir:-tmp/cctv_capture}\`"
  echo "- Readiness gate:"
  echo "  - \`./scripts/onyx_cctv_pilot_readiness_check.sh --provider ${provider:-$PROVIDER} --expect-camera ${camera_id:-<camera_id>} --expect-zone ${zone:-<zone>} --require-real-artifacts\`"
  echo
  echo "## Results"
  echo "- Field validation overall status: \`${overall_status:-}\`"
  echo "- Readiness gate overall status: \`PASS\`"
  echo "- Validation artifact dir: \`${artifact_dir:-}\`"
  echo "- Capture pack dir: \`${capture_dir:-}\`"
  echo
  echo "## Evidence"
  echo "- \`/bridges\` confirms CCTV configured and healthy: \`$([[ "$bridges_ok" == "true" ]] && echo yes || echo no)\`"
  echo "- \`/pollops\` confirms event ingest: \`$([[ "$pollops_ok" == "true" ]] && echo yes || echo no)\`"
  echo "- Snapshot reference retrieved: \`$([[ "$first_event_ok" == "true" ]] && echo yes || echo no)\`"
  echo "- Clip reference retrieved: \`$([[ "$first_event_ok" == "true" ]] && echo yes || echo no)\`"
  echo "- Timeline or Live Operations evidence present: \`$([[ "$timeline_ok" == "true" ]] && echo yes || echo no)\`"
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
  echo "- Pilot Phase 1 checklist items closed: \`$([[ "$overall_status" == "PASS" ]] && echo yes || echo no)\`"
  echo "- Remaining blockers: \`$([[ "$overall_status" == "PASS" ]] && echo none || echo review_validation_bundle)\`"
} >"$OUT_FILE"

write_signoff_json "PASS" "" "PASS" "$require_real_artifacts" "${provider:-$PROVIDER}" "${camera_id:-$EXPECT_CAMERA}" "${zone:-$EXPECT_ZONE}" "$overall_status" "$artifact_dir" "$capture_dir" "$integrity_certificate_json" "$integrity_certificate_md" "$integrity_status" "$RELEASE_GATE_JSON" "$RELEASE_TREND_REPORT_JSON" "$release_gate_result" "$release_trend_status" "$([[ "$REQUIRE_RELEASE_GATE_PASS" -eq 1 ]] && echo true || echo false)" "$([[ "$REQUIRE_RELEASE_TREND_PASS" -eq 1 ]] && echo true || echo false)"

echo "PASS: CCTV pilot signoff generated: $OUT_FILE"
echo "Signoff JSON: $JSON_OUT_FILE"
