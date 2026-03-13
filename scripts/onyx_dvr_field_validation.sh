#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

EDGE_BASE_URL="${EDGE_BASE_URL:-http://localhost:5000}"
PROVIDER="${ONYX_DVR_PROVIDER:-hikvision_dvr}"
BEARER_TOKEN="${ONYX_DVR_BEARER_TOKEN:-}"
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
  ./scripts/onyx_dvr_field_validation.sh [--edge-url <url>] [--provider <id>] [--event-id <dvr_event_id>] [--expect-camera <camera_id>] [--expect-zone <zone>] [--capture-dir <path>] [--bridges-file <path>] [--pollops-file <path>] [--timeline-file <path>] [--artifact-dir <path>] [--json-out <report.json>] [--skip-edge]

Purpose:
  Validate the live DVR pilot against the ONYX ingest and evidence path.
USAGE
}

lower() { printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'; }

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
  python3 - "$file" <<'PY'
import hashlib, sys
with open(sys.argv[1], 'rb') as handle:
    print(hashlib.sha256(handle.read()).hexdigest())
PY
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

json_string() {
  python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "${1:-}"
}

dvr_snapshot_url() {
  local base="$1"
  local provider="$2"
  local event_id="$3"
  local clean_base="${base%/}"
  case "$(lower "$provider")" in
    *hikvision*)
      printf '%s\n' "$clean_base/ISAPI/ContentMgmt/events/$event_id/snapshot"
      ;;
    *)
      printf '%s\n' "$clean_base/api/dvr/events/$event_id/snapshot.jpg"
      ;;
  esac
}

dvr_clip_url() {
  local base="$1"
  local provider="$2"
  local event_id="$3"
  local clean_base="${base%/}"
  case "$(lower "$provider")" in
    *hikvision*)
      printf '%s\n' "$clean_base/ISAPI/ContentMgmt/events/$event_id/clip"
      ;;
    *)
      printf '%s\n' "$clean_base/api/dvr/events/$event_id/clip.mp4"
      ;;
  esac
}

curl_args=(-fsS --max-time 15 -H "Accept: application/json")
if [[ -n "${BEARER_TOKEN:-}" ]]; then
  curl_args+=(-H "Authorization: Bearer ${BEARER_TOKEN}")
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --edge-url) EDGE_BASE_URL="${2:-}"; shift 2 ;;
    --provider) PROVIDER="${2:-}"; shift 2 ;;
    --event-id) EVENT_ID="${2:-}"; shift 2 ;;
    --expect-camera) EXPECT_CAMERA="${2:-}"; shift 2 ;;
    --expect-zone) EXPECT_ZONE="${2:-}"; shift 2 ;;
    --capture-dir) CAPTURE_DIR="${2:-}"; shift 2 ;;
    --bridges-file) BRIDGES_FILE="${2:-}"; shift 2 ;;
    --pollops-file) POLLOPS_FILE="${2:-}"; shift 2 ;;
    --timeline-file) TIMELINE_FILE="${2:-}"; shift 2 ;;
    --artifact-dir) ARTIFACT_DIR="${2:-}"; shift 2 ;;
    --json-out) JSON_OUT_FILE="${2:-}"; shift 2 ;;
    --skip-edge) SKIP_EDGE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "FAIL: Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$ARTIFACT_DIR" ]]; then
  ARTIFACT_DIR="tmp/dvr_field_validation/$(date -u +%Y%m%dT%H%M%SZ)"
fi
mkdir -p "$ARTIFACT_DIR"
if [[ -z "$JSON_OUT_FILE" ]]; then
  JSON_OUT_FILE="$ARTIFACT_DIR/validation_report.json"
fi

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

EDGE_STATUS="WARN"
EDGE_MESSAGE="Edge validation skipped."
BRIDGES_STATUS="WARN"
BRIDGES_MESSAGE="No /bridges capture provided."
POLLOPS_STATUS="WARN"
POLLOPS_MESSAGE="No /pollops capture provided."
TIMELINE_STATUS="WARN"
TIMELINE_MESSAGE="No timeline/live-ops capture provided."
WIRING_STATUS="WARN"
WIRING_MESSAGE="Need live evidence that at least one DVR channel is wired into ONYX."
HEALTH_STATUS="WARN"
HEALTH_MESSAGE="Need /bridges and /pollops captures to confirm live DVR health."
FIRST_EVENT_STATUS="WARN"
FIRST_EVENT_MESSAGE="Need a live DVR event artifact to confirm first end-to-end capture."
SNAPSHOT_STATUS="WARN"
SNAPSHOT_MESSAGE="Snapshot validation skipped."
CLIP_STATUS="WARN"
CLIP_MESSAGE="Clip validation skipped."
EDGE_OUTPUT=""

if [[ "$SKIP_EDGE" -eq 1 ]]; then
  EDGE_STATUS="WARN"
  EDGE_MESSAGE="Edge validation skipped by request."
else
  EVENTS_BODY_FILE="$ARTIFACT_DIR/events_response.json"
  if curl "${curl_args[@]}" "$EDGE_BASE_URL" -o "$EVENTS_BODY_FILE" >/dev/null 2>"$ARTIFACT_DIR/events_validation.stderr"; then
    EDGE_OUTPUT="$(cat "$EVENTS_BODY_FILE")"
    if [[ -n "$EVENT_ID" ]] && ! contains_ci "$EDGE_OUTPUT" "$EVENT_ID"; then
      EDGE_STATUS="FAIL"
      EDGE_MESSAGE="DVR events endpoint did not include expected event $EVENT_ID."
    else
      EDGE_STATUS="PASS"
      EDGE_MESSAGE="DVR events endpoint responded successfully."
    fi
    if [[ -n "$EVENT_ID" ]]; then
      SNAPSHOT_URL="$(dvr_snapshot_url "$EDGE_BASE_URL" "$PROVIDER" "$EVENT_ID")"
      CLIP_URL="$(dvr_clip_url "$EDGE_BASE_URL" "$PROVIDER" "$EVENT_ID")"
      snapshot_args=("${curl_args[@]}")
      clip_args=("${curl_args[@]}")
      snapshot_args[1]="--max-time"; snapshot_args[2]="15"
      clip_args[1]="--max-time"; clip_args[2]="15"
      if curl -fsS --max-time 15 ${BEARER_TOKEN:+-H "Authorization: Bearer ${BEARER_TOKEN}"} "$SNAPSHOT_URL" -o /dev/null 2>"$ARTIFACT_DIR/snapshot_validation.stderr"; then
        SNAPSHOT_STATUS="PASS"
        SNAPSHOT_MESSAGE="Snapshot resolved for event $EVENT_ID."
      else
        SNAPSHOT_STATUS="FAIL"
        SNAPSHOT_MESSAGE="Snapshot fetch failed for event $EVENT_ID."
      fi
      if curl -fsS --max-time 15 ${BEARER_TOKEN:+-H "Authorization: Bearer ${BEARER_TOKEN}"} "$CLIP_URL" -o /dev/null 2>"$ARTIFACT_DIR/clip_validation.stderr"; then
        CLIP_STATUS="PASS"
        CLIP_MESSAGE="Clip resolved for event $EVENT_ID."
      else
        CLIP_STATUS="FAIL"
        CLIP_MESSAGE="Clip fetch failed for event $EVENT_ID."
      fi
    fi
  else
    EDGE_STATUS="FAIL"
    EDGE_MESSAGE="$(tail -n 1 "$ARTIFACT_DIR/events_validation.stderr" 2>/dev/null || echo "DVR events endpoint request failed.")"
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
    BRIDGES_MESSAGE="/bridges shows configured DVR health for provider $PROVIDER."
  else
    BRIDGES_STATUS="FAIL"
    BRIDGES_MESSAGE="/bridges capture is missing one or more required video markers (configured/provider/health)."
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
    POLLOPS_MESSAGE="/pollops shows DVR ingest context for provider $PROVIDER."
  else
    POLLOPS_STATUS="FAIL"
    POLLOPS_MESSAGE="/pollops capture is missing one or more required video markers (poll result/provider/context)."
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
  if [[ -n "$EVENT_ID" ]] && ! contains_ci "$TIMELINE_CONTENT" "$EVENT_ID"; then has_event=0; fi
  if [[ -n "$EXPECT_CAMERA" ]] && ! contains_ci "$TIMELINE_CONTENT" "$EXPECT_CAMERA"; then has_camera=0; fi
  if [[ -n "$EXPECT_ZONE" ]] && ! contains_ci "$TIMELINE_CONTENT" "$EXPECT_ZONE"; then has_zone=0; fi
  if [[ "$has_snapshot" -eq 1 && "$has_clip" -eq 1 && "$has_event" -eq 1 && "$has_camera" -eq 1 && "$has_zone" -eq 1 ]]; then
    TIMELINE_STATUS="PASS"
    TIMELINE_MESSAGE="Timeline/live-ops artifact includes snapshot and clip evidence for the DVR event."
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
    WIRING_MESSAGE="Expected DVR camera $EXPECT_CAMERA appears in ONYX artifacts."
  else
    WIRING_STATUS="FAIL"
    WIRING_MESSAGE="Expected DVR camera $EXPECT_CAMERA does not appear in ONYX artifacts."
  fi
fi

if [[ "$BRIDGES_STATUS" == "PASS" && "$POLLOPS_STATUS" == "PASS" ]]; then
  HEALTH_STATUS="PASS"
  HEALTH_MESSAGE="/bridges and /pollops both reflect live DVR health."
elif [[ "$BRIDGES_STATUS" == "FAIL" || "$POLLOPS_STATUS" == "FAIL" ]]; then
  HEALTH_STATUS="FAIL"
  HEALTH_MESSAGE="One or more ONYX operator views do not reflect live DVR health."
fi

if [[ "$EDGE_STATUS" == "PASS" && "$TIMELINE_STATUS" == "PASS" && "$SNAPSHOT_STATUS" != "FAIL" && "$CLIP_STATUS" != "FAIL" ]]; then
  FIRST_EVENT_STATUS="PASS"
  FIRST_EVENT_MESSAGE="Live DVR evidence and ONYX timeline artifact confirm the first end-to-end event path."
elif [[ "$EDGE_STATUS" == "FAIL" || "$TIMELINE_STATUS" == "FAIL" || "$SNAPSHOT_STATUS" == "FAIL" || "$CLIP_STATUS" == "FAIL" ]]; then
  FIRST_EVENT_STATUS="FAIL"
  FIRST_EVENT_MESSAGE="The first end-to-end DVR event path is incomplete."
fi

FAIL_COUNT=0
WARN_COUNT=0
for status in "$EDGE_STATUS" "$BRIDGES_STATUS" "$POLLOPS_STATUS" "$TIMELINE_STATUS" "$WIRING_STATUS" "$HEALTH_STATUS" "$FIRST_EVENT_STATUS" "$SNAPSHOT_STATUS" "$CLIP_STATUS"; do
  if [[ "$status" == "FAIL" ]]; then FAIL_COUNT=$((FAIL_COUNT + 1)); fi
  if [[ "$status" == "WARN" ]]; then WARN_COUNT=$((WARN_COUNT + 1)); fi
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

MARKDOWN_REPORT="$ARTIFACT_DIR/validation_report.md"
cat >"$MARKDOWN_REPORT" <<EOF
# ONYX DVR Field Validation Report

- Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Overall status: $OVERALL_STATUS
- Provider: $PROVIDER
- Edge URL: $EDGE_BASE_URL
- Event ID: ${EVENT_ID:-}
- Expected camera: ${EXPECT_CAMERA:-}
- Expected zone: ${EXPECT_ZONE:-}

## Evidence Inputs

- Capture dir: ${CAPTURE_DIR:-}
- /bridges capture: ${STAGED_BRIDGES_FILE:-<missing>}
- /pollops capture: ${STAGED_POLLOPS_FILE:-<missing>}
- Timeline/live-ops capture: ${STAGED_TIMELINE_FILE:-<missing>}
- Artifact dir: $ARTIFACT_DIR

## Validation Results

- Edge validation: $EDGE_STATUS
  Result: $EDGE_MESSAGE
- Snapshot validation: $SNAPSHOT_STATUS
  Result: $SNAPSHOT_MESSAGE
- Clip validation: $CLIP_STATUS
  Result: $CLIP_MESSAGE
- /bridges validation: $BRIDGES_STATUS
  Result: $BRIDGES_MESSAGE
- /pollops validation: $POLLOPS_STATUS
  Result: $POLLOPS_MESSAGE
- Timeline/live-ops validation: $TIMELINE_STATUS
  Result: $TIMELINE_MESSAGE

## Checklist Mapping

- Wire one DVR channel to ONYX video bridge path: $WIRING_STATUS
  Evidence: $WIRING_MESSAGE
- Verify /pollops and /bridges reflect DVR health: $HEALTH_STATUS
  Evidence: $HEALTH_MESSAGE
- Capture first end-to-end event + snapshot + ONYX timeline record: $FIRST_EVENT_STATUS
  Evidence: $FIRST_EVENT_MESSAGE
EOF

cat >"$JSON_OUT_FILE" <<EOF
{
  "generated_at_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "artifact_dir": $(json_string "$ARTIFACT_DIR"),
  "capture_dir": $(json_string "${CAPTURE_DIR:-}"),
  "provider": $(json_string "$PROVIDER"),
  "edge_url": $(json_string "$EDGE_BASE_URL"),
  "event_id": $(json_string "$EVENT_ID"),
  "expected_camera": $(json_string "$EXPECT_CAMERA"),
  "expected_zone": $(json_string "$EXPECT_ZONE"),
  "overall_status": "$OVERALL_STATUS",
  "is_mock": false,
  "metrics": {
    "fail_count": $FAIL_COUNT,
    "warn_count": $WARN_COUNT
  },
  "gates": {
    "edge_validation": $([[ "$EDGE_STATUS" == "PASS" ]] && echo true || echo false),
    "snapshot_validation": $([[ "$SNAPSHOT_STATUS" == "PASS" ]] && echo true || echo false),
    "clip_validation": $([[ "$CLIP_STATUS" == "PASS" ]] && echo true || echo false),
    "bridges_validation": $([[ "$BRIDGES_STATUS" == "PASS" ]] && echo true || echo false),
    "pollops_validation": $([[ "$POLLOPS_STATUS" == "PASS" ]] && echo true || echo false),
    "timeline_validation": $([[ "$TIMELINE_STATUS" == "PASS" ]] && echo true || echo false),
    "camera_wired": $([[ "$WIRING_STATUS" == "PASS" ]] && echo true || echo false),
    "health_visible": $([[ "$HEALTH_STATUS" == "PASS" ]] && echo true || echo false),
    "first_event_captured": $([[ "$FIRST_EVENT_STATUS" == "PASS" ]] && echo true || echo false)
  },
  "statuses": {
    "edge": "$EDGE_STATUS",
    "snapshot": "$SNAPSHOT_STATUS",
    "clip": "$CLIP_STATUS",
    "bridges": "$BRIDGES_STATUS",
    "pollops": "$POLLOPS_STATUS",
    "timeline": "$TIMELINE_STATUS",
    "camera_wiring": "$WIRING_STATUS",
    "health_visibility": "$HEALTH_STATUS",
    "first_end_to_end_event": "$FIRST_EVENT_STATUS"
  },
  "messages": {
    "edge": $(json_string "$EDGE_MESSAGE"),
    "snapshot": $(json_string "$SNAPSHOT_MESSAGE"),
    "clip": $(json_string "$CLIP_MESSAGE"),
    "bridges": $(json_string "$BRIDGES_MESSAGE"),
    "pollops": $(json_string "$POLLOPS_MESSAGE"),
    "timeline": $(json_string "$TIMELINE_MESSAGE"),
    "camera_wiring": $(json_string "$WIRING_MESSAGE"),
    "health_visibility": $(json_string "$HEALTH_MESSAGE"),
    "first_end_to_end_event": $(json_string "$FIRST_EVENT_MESSAGE")
  },
  "files": {
    "edge_validation": $(json_string "$ARTIFACT_DIR/edge_validation.txt"),
    "events_response": $(json_string "$ARTIFACT_DIR/events_response.json"),
    "bridges_capture": $(json_string "${STAGED_BRIDGES_FILE:-}"),
    "pollops_capture": $(json_string "${STAGED_POLLOPS_FILE:-}"),
    "timeline_capture": $(json_string "${STAGED_TIMELINE_FILE:-}"),
    "markdown_report": $(json_string "$MARKDOWN_REPORT")
  },
  "checksums": {
    "edge_validation_sha256": "",
    "events_response_sha256": "",
    "bridges_capture_sha256": "",
    "pollops_capture_sha256": "",
    "timeline_capture_sha256": "",
    "markdown_report_sha256": ""
  }
}
EOF

python3 - "$JSON_OUT_FILE" <<'PY'
import json
import pathlib
import hashlib
import sys

report = pathlib.Path(sys.argv[1])
data = json.loads(report.read_text(encoding='utf-8'))

def sha(path_str: str) -> str:
    if not path_str:
        return ""
    path = pathlib.Path(path_str)
    if not path.is_file():
        return ""
    return hashlib.sha256(path.read_bytes()).hexdigest()

files = data.get("files", {})
checksums = data.setdefault("checksums", {})
checksums["edge_validation_sha256"] = sha(files.get("edge_validation", ""))
checksums["events_response_sha256"] = sha(files.get("events_response", ""))
checksums["bridges_capture_sha256"] = sha(files.get("bridges_capture", ""))
checksums["pollops_capture_sha256"] = sha(files.get("pollops_capture", ""))
checksums["timeline_capture_sha256"] = sha(files.get("timeline_capture", ""))
checksums["markdown_report_sha256"] = sha(files.get("markdown_report", ""))
report.write_text(json.dumps(data, indent=2), encoding='utf-8')
PY

INTEGRITY_CERT_JSON="$ARTIFACT_DIR/integrity_certificate.json"
INTEGRITY_CERT_MD="$ARTIFACT_DIR/integrity_certificate.md"
if ! ./scripts/onyx_validation_bundle_certificate.sh \
  --report-json "$JSON_OUT_FILE" \
  --out-json "$INTEGRITY_CERT_JSON" \
  --out-md "$INTEGRITY_CERT_MD" >/dev/null; then
  echo "FAIL: DVR integrity certificate generation failed." >&2
  exit 1
fi

echo "DVR validation report: $JSON_OUT_FILE"
echo "Integrity certificate JSON: $INTEGRITY_CERT_JSON"
echo "Integrity certificate markdown: $INTEGRITY_CERT_MD"
echo "Overall status: $OVERALL_STATUS"
exit "$EXIT_CODE"
