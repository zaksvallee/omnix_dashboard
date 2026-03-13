#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REPORT_JSON=""
OUT_FILE=""
PROVIDER="${ONYX_CCTV_PROVIDER:-frigate}"
EXPECT_CAMERA=""
EXPECT_ZONE=""
ALLOW_MOCK_ARTIFACTS=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_cctv_signoff_generate.sh [--report-json <path>] [--out <path>] [--provider <id>] [--expect-camera <camera_id>] [--expect-zone <zone>] [--allow-mock-artifacts]

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

if [[ -z "$REPORT_JSON" ]]; then
  REPORT_JSON="$(latest_validation_report_json || true)"
fi
if [[ -z "$REPORT_JSON" || ! -f "$REPORT_JSON" ]]; then
  echo "FAIL: validation_report.json not found."
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

"${readiness_cmd[@]}" >/dev/null

artifact_dir="$(json_get "$REPORT_JSON" "artifact_dir")"
capture_dir="$(json_get "$REPORT_JSON" "capture_dir")"
provider="$(json_get "$REPORT_JSON" "provider")"
edge_url="$(json_get "$REPORT_JSON" "edge_url")"
event_id="$(json_get "$REPORT_JSON" "event_id")"
camera_id="$(json_get "$REPORT_JSON" "expected_camera")"
zone="$(json_get "$REPORT_JSON" "expected_zone")"
overall_status="$(json_get "$REPORT_JSON" "overall_status")"
bridges_ok="$(json_get "$REPORT_JSON" "gates.bridges_validation")"
pollops_ok="$(json_get "$REPORT_JSON" "gates.pollops_validation")"
timeline_ok="$(json_get "$REPORT_JSON" "gates.timeline_validation")"
first_event_ok="$(json_get "$REPORT_JSON" "gates.first_event_captured")"

field_notes_file=""
if [[ -n "$capture_dir" && -f "$capture_dir/field_notes.md" ]]; then
  field_notes_file="$capture_dir/field_notes.md"
fi

if [[ -z "$OUT_FILE" ]]; then
  local_date="$(TZ=Africa/Johannesburg date +%Y-%m-%d)"
  OUT_FILE="docs/onyx_cctv_pilot_signoff_${local_date}.md"
fi

mkdir -p "$(dirname "$OUT_FILE")"

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

echo "PASS: CCTV pilot signoff generated: $OUT_FILE"
