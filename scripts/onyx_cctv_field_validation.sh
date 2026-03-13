#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

EDGE_BASE_URL="${EDGE_BASE_URL:-http://localhost:5000}"
PROVIDER="${ONYX_CCTV_PROVIDER:-frigate}"
EVENT_ID=""
EXPECT_CAMERA=""
EXPECT_ZONE=""
CAPTURE_DIR=""
BRIDGES_FILE=""
POLLOPS_FILE=""
TIMELINE_FILE=""
ARTIFACT_DIR=""
JSON_OUT_FILE=""
SKIP_EDGE=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_cctv_field_validation.sh [--edge-url <url>] [--provider <id>] [--event-id <frigate_event_id>] [--expect-camera <camera_id>] [--expect-zone <zone>] [--capture-dir <path>] [--bridges-file <path>] [--pollops-file <path>] [--timeline-file <path>] [--artifact-dir <path>] [--json-out <report.json>] [--skip-edge]

Purpose:
  Validate the live CCTV Phase 1 pilot against the remaining rollout checklist items.
  The script can:
  1) verify the Frigate edge API and optional snapshot/clip refs
  2) inspect captured /bridges and /pollops outputs
  3) inspect one captured ONYX timeline or Live Operations artifact
  4) stage the evidence into a self-contained artifact directory
  5) write markdown + JSON validation reports under tmp/cctv_field_validation/

Examples:
  ./scripts/onyx_cctv_field_validation.sh \
    --edge-url https://edge.example.com \
    --event-id evt-1001 \
    --expect-camera pilot_gate \
    --expect-zone north_gate \
    --capture-dir tmp/cctv_capture

  ./scripts/onyx_cctv_field_validation.sh \
    --skip-edge \
    --bridges-file tmp/cctv_capture/bridges.txt \
    --pollops-file tmp/cctv_capture/pollops.txt
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --edge-url)
      EDGE_BASE_URL="${2:-}"
      shift 2
      ;;
    --provider)
      PROVIDER="${2:-}"
      shift 2
      ;;
    --event-id)
      EVENT_ID="${2:-}"
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
    --capture-dir)
      CAPTURE_DIR="${2:-}"
      shift 2
      ;;
    --bridges-file)
      BRIDGES_FILE="${2:-}"
      shift 2
      ;;
    --pollops-file)
      POLLOPS_FILE="${2:-}"
      shift 2
      ;;
    --timeline-file)
      TIMELINE_FILE="${2:-}"
      shift 2
      ;;
    --artifact-dir)
      ARTIFACT_DIR="${2:-}"
      shift 2
      ;;
    --json-out)
      JSON_OUT_FILE="${2:-}"
      shift 2
      ;;
    --skip-edge)
      SKIP_EDGE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "FAIL: Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$ARTIFACT_DIR" ]]; then
  ARTIFACT_DIR="tmp/cctv_field_validation/$(date -u +%Y%m%dT%H%M%SZ)"
fi
mkdir -p "$ARTIFACT_DIR"
if [[ -z "$JSON_OUT_FILE" ]]; then
  JSON_OUT_FILE="$ARTIFACT_DIR/validation_report.json"
fi

lower() {
  printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'
}

sha256_file() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo ""
    return 0
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
    return 0
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$file" <<'PY'
import hashlib
import sys

path = sys.argv[1]
with open(path, 'rb') as handle:
    print(hashlib.sha256(handle.read()).hexdigest())
PY
    return 0
  fi
  echo ""
}

json_escape() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))'
    return 0
  fi
  sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//; s/^/"/; s/$/"/'
}

contains_ci() {
  local haystack="${1:-}"
  local needle="${2:-}"
  if [[ -z "$needle" ]]; then
    return 0
  fi
  [[ "$(lower "$haystack")" == *"$(lower "$needle")"* ]]
}

read_file_or_empty() {
  local path="${1:-}"
  if [[ -n "$path" && -f "$path" ]]; then
    cat "$path"
    return 0
  fi
  return 1
}

first_existing_file() {
  local candidate
  for candidate in "$@"; do
    if [[ -n "$candidate" && -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

stage_optional_file() {
  local source_path="${1:-}"
  local target_name="${2:-}"
  if [[ -z "$source_path" || ! -f "$source_path" || -z "$target_name" ]]; then
    return 1
  fi
  cp "$source_path" "$ARTIFACT_DIR/$target_name"
  printf '%s\n' "$ARTIFACT_DIR/$target_name"
  return 0
}

if [[ -n "$CAPTURE_DIR" ]]; then
  if [[ -z "$BRIDGES_FILE" ]]; then
    BRIDGES_FILE="$(first_existing_file "$CAPTURE_DIR/bridges.txt" "$CAPTURE_DIR/bridges.md" || true)"
  fi
  if [[ -z "$POLLOPS_FILE" ]]; then
    POLLOPS_FILE="$(first_existing_file "$CAPTURE_DIR/pollops.txt" "$CAPTURE_DIR/pollops.md" || true)"
  fi
  if [[ -z "$TIMELINE_FILE" ]]; then
    TIMELINE_FILE="$(
      first_existing_file \
        "$CAPTURE_DIR/live_ops.txt" \
        "$CAPTURE_DIR/live_operations.txt" \
        "$CAPTURE_DIR/timeline.txt" \
        "$CAPTURE_DIR/timeline.md" || true
    )"
  fi
fi

EDGE_STATUS="SKIP"
EDGE_MESSAGE="Edge validation skipped."
BRIDGES_STATUS="WARN"
BRIDGES_MESSAGE="No /bridges capture provided."
POLLOPS_STATUS="WARN"
POLLOPS_MESSAGE="No /pollops capture provided."
TIMELINE_STATUS="WARN"
TIMELINE_MESSAGE="No timeline/live-ops capture provided."
WIRING_STATUS="WARN"
WIRING_MESSAGE="Need live evidence that at least one camera is wired into ONYX."
HEALTH_STATUS="WARN"
HEALTH_MESSAGE="Need /bridges and /pollops captures to confirm live health."
FIRST_EVENT_STATUS="WARN"
FIRST_EVENT_MESSAGE="Need a live event artifact to confirm first end-to-end capture."

if [[ "$SKIP_EDGE" -eq 1 ]]; then
  EDGE_STATUS="WARN"
  EDGE_MESSAGE="Edge validation skipped by request."
else
  if EDGE_OUTPUT="$(
    EDGE_BASE_URL="$EDGE_BASE_URL" EVENT_ID="$EVENT_ID" \
      "$ROOT_DIR/deploy/cctv_pilot_edge/validate_pilot.sh" 2>&1
  )"; then
    EDGE_STATUS="PASS"
    if [[ -n "$EVENT_ID" ]]; then
      EDGE_MESSAGE="Frigate API, events feed, snapshot ref, and clip ref resolved for event $EVENT_ID."
    else
      EDGE_MESSAGE="Frigate API and events feed resolved."
    fi
  else
    EDGE_STATUS="FAIL"
    EDGE_MESSAGE="$(printf '%s' "$EDGE_OUTPUT" | tail -n 1)"
  fi
fi
printf '%s\n' "${EDGE_OUTPUT:-$EDGE_MESSAGE}" >"$ARTIFACT_DIR/edge_validation.txt"

if BRIDGES_CONTENT="$(read_file_or_empty "$BRIDGES_FILE")"; then
  has_cctv=0
  has_provider=0
  has_health=0
  has_configured=0
  contains_ci "$BRIDGES_CONTENT" "cctv:" && has_cctv=1
  contains_ci "$BRIDGES_CONTENT" "$PROVIDER" && has_provider=1
  contains_ci "$BRIDGES_CONTENT" "cctv health:" && has_health=1
  contains_ci "$BRIDGES_CONTENT" "configured" && has_configured=1
  if [[ "$has_cctv" -eq 1 && "$has_provider" -eq 1 && "$has_health" -eq 1 && "$has_configured" -eq 1 ]]; then
    BRIDGES_STATUS="PASS"
    BRIDGES_MESSAGE="/bridges shows configured CCTV health for provider $PROVIDER."
  else
    BRIDGES_STATUS="FAIL"
    BRIDGES_MESSAGE="/bridges capture is missing one or more required CCTV markers (configured/provider/health)."
  fi
fi

if POLLOPS_CONTENT="$(read_file_or_empty "$POLLOPS_FILE")"; then
  has_cctv=0
  has_provider=0
  has_context=0
  has_poll_result=0
  contains_ci "$POLLOPS_CONTENT" "cctv:" && has_cctv=1
  contains_ci "$POLLOPS_CONTENT" "$PROVIDER" && has_provider=1
  contains_ci "$POLLOPS_CONTENT" "cctv context:" && has_context=1
  contains_ci "$POLLOPS_CONTENT" "poll result" && has_poll_result=1
  if [[ "$has_cctv" -eq 1 && "$has_provider" -eq 1 && "$has_context" -eq 1 && "$has_poll_result" -eq 1 ]]; then
    POLLOPS_STATUS="PASS"
    POLLOPS_MESSAGE="/pollops shows CCTV ingest context for provider $PROVIDER."
  else
    POLLOPS_STATUS="FAIL"
    POLLOPS_MESSAGE="/pollops capture is missing one or more required CCTV markers (poll result/provider/context)."
  fi
fi

if TIMELINE_CONTENT="$(read_file_or_empty "$TIMELINE_FILE")"; then
  has_snapshot=0
  has_clip=0
  has_event=1
  has_camera=1
  has_zone=1
  contains_ci "$TIMELINE_CONTENT" "snapshot" && has_snapshot=1
  contains_ci "$TIMELINE_CONTENT" "clip" && has_clip=1
  if [[ -n "$EVENT_ID" ]] && ! contains_ci "$TIMELINE_CONTENT" "$EVENT_ID"; then
    has_event=0
  fi
  if [[ -n "$EXPECT_CAMERA" ]] && ! contains_ci "$TIMELINE_CONTENT" "$EXPECT_CAMERA"; then
    has_camera=0
  fi
  if [[ -n "$EXPECT_ZONE" ]] && ! contains_ci "$TIMELINE_CONTENT" "$EXPECT_ZONE"; then
    has_zone=0
  fi
  if [[ "$has_snapshot" -eq 1 && "$has_clip" -eq 1 && "$has_event" -eq 1 && "$has_camera" -eq 1 && "$has_zone" -eq 1 ]]; then
    TIMELINE_STATUS="PASS"
    TIMELINE_MESSAGE="Timeline/live-ops artifact includes snapshot and clip evidence for the captured event."
  else
    TIMELINE_STATUS="FAIL"
    TIMELINE_MESSAGE="Timeline/live-ops artifact is missing required evidence markers (snapshot/clip/event/camera/zone)."
  fi
fi

STAGED_BRIDGES_FILE="$(stage_optional_file "$BRIDGES_FILE" "bridges_capture.txt" || true)"
STAGED_POLLOPS_FILE="$(stage_optional_file "$POLLOPS_FILE" "pollops_capture.txt" || true)"
STAGED_TIMELINE_FILE="$(stage_optional_file "$TIMELINE_FILE" "timeline_capture.txt" || true)"

if [[ -n "$EXPECT_CAMERA" ]]; then
  if contains_ci "${POLLOPS_CONTENT:-}" "$EXPECT_CAMERA" || contains_ci "${TIMELINE_CONTENT:-}" "$EXPECT_CAMERA"; then
    WIRING_STATUS="PASS"
    WIRING_MESSAGE="Expected camera $EXPECT_CAMERA appears in ONYX artifacts."
  elif [[ "$TIMELINE_STATUS" == "PASS" || "$POLLOPS_STATUS" == "PASS" ]]; then
    WIRING_STATUS="FAIL"
    WIRING_MESSAGE="ONYX artifacts were captured, but expected camera $EXPECT_CAMERA was not found."
  fi
elif [[ "$TIMELINE_STATUS" == "PASS" || "$POLLOPS_STATUS" == "PASS" ]]; then
  WIRING_STATUS="PASS"
  WIRING_MESSAGE="ONYX artifacts show at least one live CCTV event path, but no specific camera was asserted."
fi

if [[ "$BRIDGES_STATUS" == "PASS" && "$POLLOPS_STATUS" == "PASS" ]]; then
  HEALTH_STATUS="PASS"
  HEALTH_MESSAGE="/bridges and /pollops both reflect live CCTV health."
elif [[ "$BRIDGES_STATUS" == "FAIL" || "$POLLOPS_STATUS" == "FAIL" ]]; then
  HEALTH_STATUS="FAIL"
  HEALTH_MESSAGE="One or more ONYX admin captures failed CCTV health validation."
fi

if [[ "$EDGE_STATUS" == "PASS" && "$TIMELINE_STATUS" == "PASS" ]]; then
  FIRST_EVENT_STATUS="PASS"
  FIRST_EVENT_MESSAGE="Live edge evidence and ONYX timeline artifact confirm the first end-to-end event path."
elif [[ "$EDGE_STATUS" == "FAIL" || "$TIMELINE_STATUS" == "FAIL" ]]; then
  FIRST_EVENT_STATUS="FAIL"
  FIRST_EVENT_MESSAGE="Live edge or ONYX timeline evidence is incomplete for the first end-to-end event."
fi

FAIL_COUNT=0
WARN_COUNT=0
for status in \
  "$EDGE_STATUS" \
  "$BRIDGES_STATUS" \
  "$POLLOPS_STATUS" \
  "$TIMELINE_STATUS" \
  "$WIRING_STATUS" \
  "$HEALTH_STATUS" \
  "$FIRST_EVENT_STATUS"; do
  if [[ "$status" == "FAIL" ]]; then
    FAIL_COUNT=$((FAIL_COUNT + 1))
  elif [[ "$status" == "WARN" ]]; then
    WARN_COUNT=$((WARN_COUNT + 1))
  fi
done

OVERALL_STATUS="PASS"
EXIT_CODE=0
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  OVERALL_STATUS="FAIL"
  EXIT_CODE=1
elif [[ "$WARN_COUNT" -gt 0 ]]; then
  OVERALL_STATUS="INCOMPLETE"
  EXIT_CODE=2
fi

REPORT_FILE="$ARTIFACT_DIR/validation_report.md"
cat >"$REPORT_FILE" <<EOF
# ONYX CCTV Field Validation Report

- Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Overall status: $OVERALL_STATUS
- Provider: $PROVIDER
- Edge URL: $EDGE_BASE_URL
- Event ID: ${EVENT_ID:-n/a}
- Expected camera: ${EXPECT_CAMERA:-n/a}
- Expected zone: ${EXPECT_ZONE:-n/a}

## Evidence Inputs

- Capture dir: ${CAPTURE_DIR:-not provided}
- /bridges capture: ${BRIDGES_FILE:-not provided}
- /pollops capture: ${POLLOPS_FILE:-not provided}
- Timeline/live-ops capture: ${TIMELINE_FILE:-not provided}
- Artifact dir: $ARTIFACT_DIR

## Validation Results

- Edge validation: $EDGE_STATUS
  Result: $EDGE_MESSAGE
- /bridges validation: $BRIDGES_STATUS
  Result: $BRIDGES_MESSAGE
- /pollops validation: $POLLOPS_STATUS
  Result: $POLLOPS_MESSAGE
- Timeline/live-ops validation: $TIMELINE_STATUS
  Result: $TIMELINE_MESSAGE

## Checklist Mapping

- Wire one camera to ONYX cctv_bridge_service: $WIRING_STATUS
  Evidence: $WIRING_MESSAGE
- Verify /pollops and /bridges reflect CCTV health: $HEALTH_STATUS
  Evidence: $HEALTH_MESSAGE
- Capture first end-to-end event + snapshot + ONYX timeline record: $FIRST_EVENT_STATUS
  Evidence: $FIRST_EVENT_MESSAGE

## Next Step

EOF

if [[ "$OVERALL_STATUS" == "PASS" ]]; then
  cat >>"$REPORT_FILE" <<'EOF'
Pilot field validation passed. Update the CCTV rollout checklist and attach this report to the handoff.
EOF
elif [[ "$OVERALL_STATUS" == "FAIL" ]]; then
  cat >>"$REPORT_FILE" <<'EOF'
Resolve the failing checks above, recapture the ONYX artifacts, and rerun this script.
EOF
else
  cat >>"$REPORT_FILE" <<'EOF'
Capture the missing ONYX artifacts and rerun this script to convert the remaining checklist items from incomplete to pass.
EOF
fi

EDGE_SHA="$(sha256_file "$ARTIFACT_DIR/edge_validation.txt")"
BRIDGES_SHA="$(sha256_file "${STAGED_BRIDGES_FILE:-}")"
POLLOPS_SHA="$(sha256_file "${STAGED_POLLOPS_FILE:-}")"
TIMELINE_SHA="$(sha256_file "${STAGED_TIMELINE_FILE:-}")"
REPORT_SHA="$(sha256_file "$REPORT_FILE")"

cat >"$JSON_OUT_FILE" <<EOF
{
  "generated_at_utc": $(printf '%s' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" | json_escape),
  "artifact_dir": $(printf '%s' "$ARTIFACT_DIR" | json_escape),
  "capture_dir": $(printf '%s' "${CAPTURE_DIR:-}" | json_escape),
  "provider": $(printf '%s' "$PROVIDER" | json_escape),
  "edge_url": $(printf '%s' "$EDGE_BASE_URL" | json_escape),
  "event_id": $(printf '%s' "${EVENT_ID:-}" | json_escape),
  "expected_camera": $(printf '%s' "${EXPECT_CAMERA:-}" | json_escape),
  "expected_zone": $(printf '%s' "${EXPECT_ZONE:-}" | json_escape),
  "overall_status": $(printf '%s' "$OVERALL_STATUS" | json_escape),
  "metrics": {
    "fail_count": $FAIL_COUNT,
    "warn_count": $WARN_COUNT
  },
  "gates": {
    "edge_validation": $(if [[ "$EDGE_STATUS" == "PASS" ]]; then echo "true"; else echo "false"; fi),
    "bridges_validation": $(if [[ "$BRIDGES_STATUS" == "PASS" ]]; then echo "true"; else echo "false"; fi),
    "pollops_validation": $(if [[ "$POLLOPS_STATUS" == "PASS" ]]; then echo "true"; else echo "false"; fi),
    "timeline_validation": $(if [[ "$TIMELINE_STATUS" == "PASS" ]]; then echo "true"; else echo "false"; fi),
    "camera_wired": $(if [[ "$WIRING_STATUS" == "PASS" ]]; then echo "true"; else echo "false"; fi),
    "health_visible": $(if [[ "$HEALTH_STATUS" == "PASS" ]]; then echo "true"; else echo "false"; fi),
    "first_event_captured": $(if [[ "$FIRST_EVENT_STATUS" == "PASS" ]]; then echo "true"; else echo "false"; fi)
  },
  "statuses": {
    "edge": $(printf '%s' "$EDGE_STATUS" | json_escape),
    "bridges": $(printf '%s' "$BRIDGES_STATUS" | json_escape),
    "pollops": $(printf '%s' "$POLLOPS_STATUS" | json_escape),
    "timeline": $(printf '%s' "$TIMELINE_STATUS" | json_escape),
    "camera_wiring": $(printf '%s' "$WIRING_STATUS" | json_escape),
    "health_visibility": $(printf '%s' "$HEALTH_STATUS" | json_escape),
    "first_end_to_end_event": $(printf '%s' "$FIRST_EVENT_STATUS" | json_escape)
  },
  "messages": {
    "edge": $(printf '%s' "$EDGE_MESSAGE" | json_escape),
    "bridges": $(printf '%s' "$BRIDGES_MESSAGE" | json_escape),
    "pollops": $(printf '%s' "$POLLOPS_MESSAGE" | json_escape),
    "timeline": $(printf '%s' "$TIMELINE_MESSAGE" | json_escape),
    "camera_wiring": $(printf '%s' "$WIRING_MESSAGE" | json_escape),
    "health_visibility": $(printf '%s' "$HEALTH_MESSAGE" | json_escape),
    "first_end_to_end_event": $(printf '%s' "$FIRST_EVENT_MESSAGE" | json_escape)
  },
  "files": {
    "edge_validation": $(printf '%s' "$ARTIFACT_DIR/edge_validation.txt" | json_escape),
    "bridges_capture": $(printf '%s' "${STAGED_BRIDGES_FILE:-}" | json_escape),
    "pollops_capture": $(printf '%s' "${STAGED_POLLOPS_FILE:-}" | json_escape),
    "timeline_capture": $(printf '%s' "${STAGED_TIMELINE_FILE:-}" | json_escape),
    "markdown_report": $(printf '%s' "$REPORT_FILE" | json_escape)
  },
  "checksums": {
    "edge_validation_sha256": $(printf '%s' "$EDGE_SHA" | json_escape),
    "bridges_capture_sha256": $(printf '%s' "$BRIDGES_SHA" | json_escape),
    "pollops_capture_sha256": $(printf '%s' "$POLLOPS_SHA" | json_escape),
    "timeline_capture_sha256": $(printf '%s' "$TIMELINE_SHA" | json_escape),
    "markdown_report_sha256": $(printf '%s' "$REPORT_SHA" | json_escape)
  }
}
EOF

echo "== ONYX CCTV Field Validation =="
echo "Overall: $OVERALL_STATUS"
echo "Report: $REPORT_FILE"
echo "Report JSON: $JSON_OUT_FILE"
echo "Edge: $EDGE_STATUS - $EDGE_MESSAGE"
echo "/bridges: $BRIDGES_STATUS - $BRIDGES_MESSAGE"
echo "/pollops: $POLLOPS_STATUS - $POLLOPS_MESSAGE"
echo "Timeline: $TIMELINE_STATUS - $TIMELINE_MESSAGE"
echo "Checklist:"
echo "  camera wiring: $WIRING_STATUS"
echo "  health visibility: $HEALTH_STATUS"
echo "  first end-to-end event: $FIRST_EVENT_STATUS"

exit "$EXIT_CODE"
