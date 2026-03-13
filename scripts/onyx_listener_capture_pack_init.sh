#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="tmp/listener_capture"
SITE_ID=""
DEVICE_PATH=""
LEGACY_SOURCE=""
CLIENT_ID="CLIENT-001"
REGION_ID="REGION-GAUTENG"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_capture_pack_init.sh [--out-dir <path>] [--site-id <site_id>] [--device-path <tty>] [--legacy-source <label>] [--client-id <id>] [--region-id <id>]

Purpose:
  Initialize a listener dual-path capture pack with the exact files expected for
  serial bench replay, parity comparison, and pilot signoff.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --site-id)
      SITE_ID="${2:-}"
      shift 2
      ;;
    --device-path)
      DEVICE_PATH="${2:-}"
      shift 2
      ;;
    --legacy-source)
      LEGACY_SOURCE="${2:-}"
      shift 2
      ;;
    --client-id)
      CLIENT_ID="${2:-}"
      shift 2
      ;;
    --region-id)
      REGION_ID="${2:-}"
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

mkdir -p "$OUT_DIR"

cat >"$OUT_DIR/README.md" <<EOF
# Listener Capture Pack

- Initialized: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Site ID: ${SITE_ID:-<fill-me>}
- Device path: ${DEVICE_PATH:-<fill-me>}
- Legacy source: ${LEGACY_SOURCE:-<fill-me>}
- Client ID: ${CLIENT_ID:-<fill-me>}
- Region ID: ${REGION_ID:-<fill-me>}

## Required files

- \`serial_raw.txt\`
  Raw read-only serial capture lines from the bench session.
- \`legacy_events.json\`
  Legacy listener export normalized into accepted JSON rows for parity checks.
- \`field_notes.md\`
  Bench notes, wiring details, observed anomalies, and timestamps.

## Bench commands

\`\`\`bash
./scripts/onyx_listener_serial_bench.sh \\
  --input $OUT_DIR/serial_raw.txt \\
  --client-id ${CLIENT_ID:-CLIENT-001} \\
  --region-id ${REGION_ID:-REGION-GAUTENG} \\
  --site-id ${SITE_ID:-SITE-SANDTON}
\`\`\`

\`\`\`bash
./scripts/onyx_listener_parity_report.sh \\
  --serial tmp/listener_serial_bench/<timestamp>/parsed.json \\
  --legacy $OUT_DIR/legacy_events.json
\`\`\`
EOF

cat >"$OUT_DIR/serial_raw.txt" <<'EOF'
# Paste raw read-only serial lines here, one event per line.
# Example:
# 1130 01 004 1234 0001 2026-03-13T08:15:00Z
EOF

cat >"$OUT_DIR/legacy_events.json" <<'EOF'
[
  {
    "provider": "legacy_listener",
    "transport": "tcp",
    "external_id": "legacy-example-1",
    "account_number": "1234",
    "partition": "01",
    "event_code": "130",
    "event_qualifier": "1",
    "zone": "004",
    "site_id": "SITE-SANDTON",
    "client_id": "CLIENT-001",
    "region_id": "REGION-GAUTENG",
    "occurred_at_utc": "2026-03-13T08:15:15Z"
  }
]
EOF

cat >"$OUT_DIR/field_notes.md" <<EOF
# Listener Field Notes

- Date (local): $(date +%Y-%m-%d)
- Site ID: ${SITE_ID:-<fill-me>}
- Device path: ${DEVICE_PATH:-<fill-me>}
- Legacy source: ${LEGACY_SOURCE:-<fill-me>}
- Client ID: ${CLIENT_ID:-<fill-me>}
- Region ID: ${REGION_ID:-<fill-me>}
- Operator:
- Controller:

## Wiring

- GND connected:
- RX connected:
- TX disconnected:
- VCC disconnected:

## Observations

- Serial readability:
- Timestamp quality:
- Event-code consistency:
- Legacy listener availability:

## Anomalies

- None / describe any framing, noise, skew, or missing-event issues.
EOF

echo "PASS: Listener capture pack initialized: $OUT_DIR"
echo "Files:"
echo "  $OUT_DIR/README.md"
echo "  $OUT_DIR/serial_raw.txt"
echo "  $OUT_DIR/legacy_events.json"
echo "  $OUT_DIR/field_notes.md"
