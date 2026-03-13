#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="tmp/dvr_capture"
SITE_ID=""
EDGE_URL=""
CAMERA_ID=""
ZONE=""
EVENT_ID=""
PROVIDER="${ONYX_DVR_PROVIDER:-hikvision_dvr}"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_dvr_capture_pack_init.sh [--out-dir <path>] [--site-id <site_id>] [--edge-url <url>] [--camera-id <camera_id>] [--zone <zone>] [--event-id <event_id>] [--provider <id>]

Purpose:
  Initialize a DVR pilot capture pack with the exact files expected by the
  DVR validation scripts and field signoff flow.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    --site-id) SITE_ID="${2:-}"; shift 2 ;;
    --edge-url) EDGE_URL="${2:-}"; shift 2 ;;
    --camera-id) CAMERA_ID="${2:-}"; shift 2 ;;
    --zone) ZONE="${2:-}"; shift 2 ;;
    --event-id) EVENT_ID="${2:-}"; shift 2 ;;
    --provider) PROVIDER="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "FAIL: Unknown argument: $1"; exit 1 ;;
  esac
done

mkdir -p "$OUT_DIR"

cat >"$OUT_DIR/README.md" <<EOF
# DVR Capture Pack

- Initialized: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Site ID: ${SITE_ID:-<fill-me>}
- DVR URL: ${EDGE_URL:-<fill-me>}
- Provider: ${PROVIDER:-<fill-me>}
- Camera ID: ${CAMERA_ID:-<fill-me>}
- Zone: ${ZONE:-<fill-me>}
- Event ID: ${EVENT_ID:-<fill-me>}

## Required files

- \`bridges.txt\`
  Capture the ONYX \`/bridges\` response after the DVR event.
- \`pollops.txt\`
  Capture the ONYX \`/pollops\` response for the same event window.
- \`live_ops.txt\`
  Capture the Live Operations or timeline text that includes snapshot/clip refs.
- \`field_notes.md\`
  Record operator, timestamp, observed behavior, and any anomalies.

## Validation commands

\`\`\`bash
./scripts/onyx_dvr_field_validation.sh \\
  --edge-url ${EDGE_URL:-https://<dvr-host>} \\
  --provider ${PROVIDER:-hikvision_dvr} \\
  --event-id ${EVENT_ID:-<dvr_event_id>} \\
  --expect-camera ${CAMERA_ID:-<camera_id>} \\
  --expect-zone ${ZONE:-<zone>} \\
  --capture-dir $OUT_DIR
\`\`\`

\`\`\`bash
./scripts/onyx_dvr_pilot_readiness_check.sh \\
  --provider ${PROVIDER:-hikvision_dvr} \\
  --expect-camera ${CAMERA_ID:-<camera_id>} \\
  --expect-zone ${ZONE:-<zone>} \\
  --require-real-artifacts
\`\`\`
EOF

cat >"$OUT_DIR/bridges.txt" <<'EOF'
Paste the ONYX /bridges output here.
EOF

cat >"$OUT_DIR/pollops.txt" <<'EOF'
Paste the ONYX /pollops output here.
EOF

cat >"$OUT_DIR/live_ops.txt" <<'EOF'
Paste the Live Operations or timeline output here, including snapshot and clip references.
EOF

cat >"$OUT_DIR/field_notes.md" <<EOF
# DVR Field Notes

- Date (local): $(date +%Y-%m-%d)
- Site ID: ${SITE_ID:-<fill-me>}
- DVR URL: ${EDGE_URL:-<fill-me>}
- Provider: ${PROVIDER:-<fill-me>}
- Camera ID: ${CAMERA_ID:-<fill-me>}
- Zone: ${ZONE:-<fill-me>}
- Event ID: ${EVENT_ID:-<fill-me>}
- Operator:
- Controller:

## Observations

- DVR reachability:
- /bridges status:
- /pollops status:
- Snapshot retrieval:
- Clip retrieval:
- Timeline/live-ops evidence:

## Anomalies

- None / describe any mismatch, delay, or evidence gap.
EOF

echo "PASS: DVR capture pack initialized: $OUT_DIR"
echo "Files:"
echo "  $OUT_DIR/README.md"
echo "  $OUT_DIR/bridges.txt"
echo "  $OUT_DIR/pollops.txt"
echo "  $OUT_DIR/live_ops.txt"
echo "  $OUT_DIR/field_notes.md"
