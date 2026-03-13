#!/usr/bin/env bash
set -euo pipefail

OUT_DIR=""
PROVIDER="${ONYX_CCTV_PROVIDER:-frigate}"
EVENT_ID="evt-mock-1001"
EXPECT_CAMERA="pilot_gate"
EXPECT_ZONE="north_gate"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_cctv_mock_validation_artifacts.sh [--out-dir <path>] [--provider <id>] [--event-id <id>] [--expect-camera <camera_id>] [--expect-zone <zone>]

Purpose:
  Generates synthetic CCTV validation artifacts for local gate verification when
  a live edge node or camera is unavailable. These artifacts are not valid for
  real pilot signoff.
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
import hashlib
import sys

path = sys.argv[1]
with open(path, 'rb') as handle:
    print(hashlib.sha256(handle.read()).hexdigest())
PY
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      OUT_DIR="${2:-}"
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

if [[ -z "$OUT_DIR" ]]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  OUT_DIR="tmp/cctv_field_validation/mock-$stamp"
fi
mkdir -p "$OUT_DIR"

cat >"$OUT_DIR/edge_validation.txt" <<EOF
Checking Frigate API...
Checking events feed...
Checking snapshot ref for ${EVENT_ID}...
Checking clip ref for ${EVENT_ID}...
Pilot edge validation passed.
EOF

cat >"$OUT_DIR/bridges_capture.txt" <<EOF
ONYX BRIDGES
Telegram: READY • admin chat bound
Radio: configured
CCTV: configured • pilot edge • provider ${PROVIDER} • edge edge.example.com • caps LIVE AI MONITORING
CCTV Health: ok 2 • fail 0 • skip 0 • last 10:05:01 UTC • 1/1 appended • ${PROVIDER} • CCTV person detected in ${EXPECT_ZONE}
CCTV Recent: recent hardware intel 1 (6h) • intrusion 1 • line_crossing 0 • motion 0
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
• <b>CCTV:</b> ok 3 • fail 0 • skip 0 • last 10:05:01 UTC • 1/1 appended • ${PROVIDER} • CCTV person detected in ${EXPECT_ZONE} camera:${EXPECT_CAMERA}
<b>CCTV Context:</b> provider ${PROVIDER} • recent hardware intel 1 (6h) • intrusion 1 • line_crossing 0 • motion 0
• <b>Wearable:</b> ok 1 • fail 0 • skip 0 • last 10:05:02 UTC
• <b>News:</b> ok 4 • fail 0 • skip 0 • last 10:05:03 UTC

---

<b>Next</b>
• If any source is failing, run <code>/bridges</code> for deeper diagnostics.

UTC: 2026-03-13T10:05:10Z
EOF

cat >"$OUT_DIR/timeline_capture.txt" <<EOF
Incident context
Event ${EVENT_ID}
Camera ${EXPECT_CAMERA}
Zone ${EXPECT_ZONE}
snapshot https://edge.example.com/api/events/${EVENT_ID}/snapshot.jpg
clip https://edge.example.com/api/events/${EVENT_ID}/clip.mp4
EOF

cat >"$OUT_DIR/validation_report.md" <<EOF
# ONYX CCTV Field Validation Report

- Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Overall status: PASS
- Provider: ${PROVIDER}
- Edge URL: https://edge.example.com
- Event ID: ${EVENT_ID}
- Expected camera: ${EXPECT_CAMERA}
- Expected zone: ${EXPECT_ZONE}

## Evidence Inputs

- Capture dir: tmp/cctv_capture
- /bridges capture: $OUT_DIR/bridges_capture.txt
- /pollops capture: $OUT_DIR/pollops_capture.txt
- Timeline/live-ops capture: $OUT_DIR/timeline_capture.txt
- Artifact dir: $OUT_DIR

## Validation Results

- Edge validation: PASS
  Result: Frigate API, events feed, snapshot ref, and clip ref resolved for event ${EVENT_ID}.
- /bridges validation: PASS
  Result: /bridges shows configured CCTV health for provider ${PROVIDER}.
- /pollops validation: PASS
  Result: /pollops shows CCTV ingest context for provider ${PROVIDER}.
- Timeline/live-ops validation: PASS
  Result: Timeline/live-ops artifact includes snapshot and clip evidence for the captured event.

## Checklist Mapping

- Wire one camera to ONYX cctv_bridge_service: PASS
  Evidence: Expected camera ${EXPECT_CAMERA} appears in ONYX artifacts.
- Verify /pollops and /bridges reflect CCTV health: PASS
  Evidence: /bridges and /pollops both reflect live CCTV health.
- Capture first end-to-end event + snapshot + ONYX timeline record: PASS
  Evidence: Live edge evidence and ONYX timeline artifact confirm the first end-to-end event path.

## Next Step

Mock validation artifacts generated for tooling verification only. Do not use this bundle for real pilot signoff.
EOF

cat >"$OUT_DIR/validation_report.json" <<EOF
{
  "generated_at_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "artifact_dir": "$OUT_DIR",
  "capture_dir": "tmp/cctv_capture",
  "provider": "$PROVIDER",
  "edge_url": "https://edge.example.com",
  "event_id": "$EVENT_ID",
  "expected_camera": "$EXPECT_CAMERA",
  "expected_zone": "$EXPECT_ZONE",
  "overall_status": "PASS",
  "metrics": {
    "fail_count": 0,
    "warn_count": 0
  },
  "gates": {
    "edge_validation": true,
    "bridges_validation": true,
    "pollops_validation": true,
    "timeline_validation": true,
    "camera_wired": true,
    "health_visible": true,
    "first_event_captured": true
  },
  "statuses": {
    "edge": "PASS",
    "bridges": "PASS",
    "pollops": "PASS",
    "timeline": "PASS",
    "camera_wiring": "PASS",
    "health_visibility": "PASS",
    "first_end_to_end_event": "PASS"
  },
  "messages": {
    "edge": "Frigate API, events feed, snapshot ref, and clip ref resolved for event $EVENT_ID.",
    "bridges": "/bridges shows configured CCTV health for provider $PROVIDER.",
    "pollops": "/pollops shows CCTV ingest context for provider $PROVIDER.",
    "timeline": "Timeline/live-ops artifact includes snapshot and clip evidence for the captured event.",
    "camera_wiring": "Expected camera $EXPECT_CAMERA appears in ONYX artifacts.",
    "health_visibility": "/bridges and /pollops both reflect live CCTV health.",
    "first_end_to_end_event": "Live edge evidence and ONYX timeline artifact confirm the first end-to-end event path."
  },
  "files": {
    "edge_validation": "$OUT_DIR/edge_validation.txt",
    "bridges_capture": "$OUT_DIR/bridges_capture.txt",
    "pollops_capture": "$OUT_DIR/pollops_capture.txt",
    "timeline_capture": "$OUT_DIR/timeline_capture.txt",
    "markdown_report": "$OUT_DIR/validation_report.md"
  },
  "checksums": {
    "edge_validation_sha256": "",
    "bridges_capture_sha256": "",
    "pollops_capture_sha256": "",
    "timeline_capture_sha256": "",
    "markdown_report_sha256": ""
  }
}
EOF

python3 - "$OUT_DIR" <<'PY'
import json
import pathlib
import sys

base = pathlib.Path(sys.argv[1])
report = base / "validation_report.json"
data = json.loads(report.read_text(encoding="utf-8"))

def sha(name: str) -> str:
    import hashlib
    path = base / name
    return hashlib.sha256(path.read_bytes()).hexdigest()

data["checksums"]["edge_validation_sha256"] = sha("edge_validation.txt")
data["checksums"]["bridges_capture_sha256"] = sha("bridges_capture.txt")
data["checksums"]["pollops_capture_sha256"] = sha("pollops_capture.txt")
data["checksums"]["timeline_capture_sha256"] = sha("timeline_capture.txt")
data["checksums"]["markdown_report_sha256"] = sha("validation_report.md")
report.write_text(json.dumps(data, indent=2), encoding="utf-8")
PY

echo "PASS: Mock CCTV validation artifacts generated: $OUT_DIR"
echo "Report: $OUT_DIR/validation_report.json"
