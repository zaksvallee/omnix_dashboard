#!/usr/bin/env bash
set -euo pipefail

OUT_DIR=""
PROVIDER="${ONYX_DVR_PROVIDER:-hikvision_dvr}"
EVENT_ID="dvr-mock-1001"
EXPECT_CAMERA="dvr-cam-01"
EXPECT_ZONE="loading_bay"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_dvr_mock_validation_artifacts.sh [--out-dir <path>] [--provider <id>] [--event-id <id>] [--expect-camera <camera_id>] [--expect-zone <zone>]
USAGE
}

sha256_file() {
  local file="$1"
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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    --provider) PROVIDER="${2:-}"; shift 2 ;;
    --event-id) EVENT_ID="${2:-}"; shift 2 ;;
    --expect-camera) EXPECT_CAMERA="${2:-}"; shift 2 ;;
    --expect-zone) EXPECT_ZONE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "FAIL: Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="tmp/dvr_field_validation/mock-$(date -u +%Y%m%dT%H%M%SZ)"
fi
mkdir -p "$OUT_DIR"

cat >"$OUT_DIR/edge_validation.txt" <<EOF
Checking DVR events endpoint...
Checking snapshot ref for ${EVENT_ID}...
Checking clip ref for ${EVENT_ID}...
DVR pilot validation passed.
EOF

cat >"$OUT_DIR/events_response.json" <<EOF
{"events":[{"id":"${EVENT_ID}","camera_id":"${EXPECT_CAMERA}","zone":"${EXPECT_ZONE}","event_type":"intrusion"}]}
EOF

cat >"$OUT_DIR/bridges_capture.txt" <<EOF
ONYX BRIDGES
Telegram: READY • admin chat bound
Radio: configured
CCTV: configured • provider ${PROVIDER} • edge dvr.example.com • caps LIVE AI MONITORING • verified 2 • fail 0 • dropped 0 • queue 1/12 • last 10:05:01 UTC
CCTV Health: ok 2 • fail 0 • skip 0 • last 10:05:01 UTC • 1/1 appended • ${PROVIDER} • provider:${PROVIDER} | camera:${EXPECT_CAMERA} | zone:${EXPECT_ZONE}
Wearable: configured
Live polling: enabled
UTC: 2026-03-13T10:05:10Z
EOF

cat >"$OUT_DIR/pollops_capture.txt" <<EOF
📡 <b>ONYX POLLOPS</b>

<b>Poll Result</b>
Ops poll • ok 4/4

---

<b>Integrations</b>
• <b>Radio:</b> ok 2 • fail 0 • skip 0 • last 10:05:00 UTC
• <b>CCTV:</b> ok 3 • fail 0 • skip 0 • last 10:05:01 UTC • 1/1 appended • ${PROVIDER} • provider:${PROVIDER} | camera:${EXPECT_CAMERA} | zone:${EXPECT_ZONE}
<b>CCTV Context:</b> provider ${PROVIDER} • recent video intel 1 (6h) • intrusion 1 • line_crossing 0 • motion 0 • fr 0 • lpr 0
• <b>Wearable:</b> ok 1 • fail 0 • skip 0 • last 10:05:02 UTC
UTC: 2026-03-13T10:05:10Z
EOF

cat >"$OUT_DIR/timeline_capture.txt" <<EOF
Incident context
Event ${EVENT_ID}
Camera ${EXPECT_CAMERA}
Zone ${EXPECT_ZONE}
snapshot https://dvr.example.com/mock/${EVENT_ID}/snapshot.jpg
clip https://dvr.example.com/mock/${EVENT_ID}/clip.mp4
EOF

cat >"$OUT_DIR/validation_report.md" <<EOF
# ONYX DVR Field Validation Report

- Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Overall status: PASS
- Provider: ${PROVIDER}
- Edge URL: https://dvr.example.com/events
- Event ID: ${EVENT_ID}
- Expected camera: ${EXPECT_CAMERA}
- Expected zone: ${EXPECT_ZONE}
EOF

cat >"$OUT_DIR/validation_report.json" <<EOF
{
  "generated_at_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "artifact_dir": "$OUT_DIR",
  "capture_dir": "tmp/dvr_capture",
  "provider": "$PROVIDER",
  "edge_url": "https://dvr.example.com/events",
  "event_id": "$EVENT_ID",
  "expected_camera": "$EXPECT_CAMERA",
  "expected_zone": "$EXPECT_ZONE",
  "overall_status": "PASS",
  "is_mock": true,
  "metrics": {"fail_count": 0, "warn_count": 0},
  "gates": {
    "edge_validation": true,
    "snapshot_validation": true,
    "clip_validation": true,
    "bridges_validation": true,
    "pollops_validation": true,
    "timeline_validation": true,
    "camera_wired": true,
    "health_visible": true,
    "first_event_captured": true
  },
  "statuses": {
    "edge": "PASS",
    "snapshot": "PASS",
    "clip": "PASS",
    "bridges": "PASS",
    "pollops": "PASS",
    "timeline": "PASS",
    "camera_wiring": "PASS",
    "health_visibility": "PASS",
    "first_end_to_end_event": "PASS"
  },
  "messages": {
    "edge": "DVR events endpoint responded successfully.",
    "snapshot": "Snapshot resolved for event $EVENT_ID.",
    "clip": "Clip resolved for event $EVENT_ID.",
    "bridges": "/bridges shows configured DVR health for provider $PROVIDER.",
    "pollops": "/pollops shows DVR ingest context for provider $PROVIDER.",
    "timeline": "Timeline/live-ops artifact includes snapshot and clip evidence for the DVR event.",
    "camera_wiring": "Expected DVR camera $EXPECT_CAMERA appears in ONYX artifacts.",
    "health_visibility": "/bridges and /pollops both reflect live DVR health.",
    "first_end_to_end_event": "Live DVR evidence and ONYX timeline artifact confirm the first end-to-end event path."
  },
  "files": {
    "edge_validation": "$OUT_DIR/edge_validation.txt",
    "events_response": "$OUT_DIR/events_response.json",
    "bridges_capture": "$OUT_DIR/bridges_capture.txt",
    "pollops_capture": "$OUT_DIR/pollops_capture.txt",
    "timeline_capture": "$OUT_DIR/timeline_capture.txt",
    "markdown_report": "$OUT_DIR/validation_report.md"
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

python3 - "$OUT_DIR" <<'PY'
import json, pathlib, hashlib, sys
base = pathlib.Path(sys.argv[1])
report = base / "validation_report.json"
data = json.loads(report.read_text(encoding="utf-8"))
def sha(name):
    return hashlib.sha256((base / name).read_bytes()).hexdigest()
data["checksums"]["edge_validation_sha256"] = sha("edge_validation.txt")
data["checksums"]["events_response_sha256"] = sha("events_response.json")
data["checksums"]["bridges_capture_sha256"] = sha("bridges_capture.txt")
data["checksums"]["pollops_capture_sha256"] = sha("pollops_capture.txt")
data["checksums"]["timeline_capture_sha256"] = sha("timeline_capture.txt")
data["checksums"]["markdown_report_sha256"] = sha("validation_report.md")
report.write_text(json.dumps(data, indent=2), encoding="utf-8")
PY

./scripts/onyx_validation_bundle_certificate.sh \
  --report-json "$OUT_DIR/validation_report.json" \
  --out-json "$OUT_DIR/integrity_certificate.json" \
  --out-md "$OUT_DIR/integrity_certificate.md" >/dev/null

echo "PASS: Mock DVR validation artifacts generated: $OUT_DIR"
echo "Report: $OUT_DIR/validation_report.json"
