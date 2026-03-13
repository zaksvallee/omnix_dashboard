#!/usr/bin/env bash
set -euo pipefail

OUT_DIR=""
SITE_ID="SITE-SANDTON"
DEVICE_PATH="/dev/ttyUSB0"
LEGACY_SOURCE="legacy_listener"
CLIENT_ID="CLIENT-001"
REGION_ID="REGION-GAUTENG"
COMPARE_PREVIOUS=1

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_mock_validation_artifacts.sh [--out-dir <path>] [--site-id <site_id>] [--device-path <tty>] [--legacy-source <label>] [--client-id <id>] [--region-id <id>] [--no-compare-previous]

Purpose:
  Generate synthetic listener field-validation artifacts for local gate and
  signoff-tool verification when real serial hardware or legacy exports are not
  available. These artifacts are not valid for real pilot signoff.
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
    --no-compare-previous)
      COMPARE_PREVIOUS=0
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

if [[ -z "$OUT_DIR" ]]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  OUT_DIR="tmp/listener_field_validation/mock-$stamp"
fi
mkdir -p "$OUT_DIR"

CAPTURE_DIR="$OUT_DIR/mock_capture"
PREV_DIR="$OUT_DIR/mock_previous"
mkdir -p "$CAPTURE_DIR" "$PREV_DIR"

cat >"$CAPTURE_DIR/serial_raw.txt" <<'EOF'
1130 01 004 1234 0001 2026-03-13T08:15:00Z
EOF

cat >"$CAPTURE_DIR/legacy_events.json" <<EOF
[
  {
    "provider": "legacy_listener",
    "transport": "tcp",
    "external_id": "legacy-mock-1",
    "account_number": "1234",
    "partition": "01",
    "event_code": "130",
    "event_qualifier": "1",
    "zone": "004",
    "site_id": "$SITE_ID",
    "client_id": "$CLIENT_ID",
    "region_id": "$REGION_ID",
    "occurred_at_utc": "2026-03-13T08:15:20Z"
  }
]
EOF

cat >"$CAPTURE_DIR/field_notes.md" <<EOF
# Listener Field Notes

- Date (local): $(date +%Y-%m-%d)
- Site ID: $SITE_ID
- Device path: $DEVICE_PATH
- Legacy source: $LEGACY_SOURCE
- Client ID: $CLIENT_ID
- Region ID: $REGION_ID

## Wiring

- GND connected: yes
- RX connected: yes
- TX disconnected: yes
- VCC disconnected: yes

## Observations

- Serial readability: clear
- Timestamp quality: synthetic
- Event-code consistency: synthetic
- Legacy listener availability: synthetic export present

## Anomalies

- None. Mock bundle for tooling verification only.
EOF

if [[ "$COMPARE_PREVIOUS" -eq 1 ]]; then
  cat >"$PREV_DIR/report.json" <<'EOF'
{
  "summary": "previous synthetic parity summary",
  "match_rate_percent": 100.0,
  "max_skew_seconds_observed": 25,
  "drift_reason_counts": {}
}
EOF
fi

validation_cmd=(
  ./scripts/onyx_listener_field_validation.sh
  --capture-dir "$CAPTURE_DIR"
  --site-id "$SITE_ID"
  --device-path "$DEVICE_PATH"
  --legacy-source "$LEGACY_SOURCE"
  --client-id "$CLIENT_ID"
  --region-id "$REGION_ID"
  --artifact-dir "$OUT_DIR"
  --allow-mock-artifacts
)

if [[ "$COMPARE_PREVIOUS" -eq 1 ]]; then
  validation_cmd+=(--compare-previous)
  validation_cmd+=(--previous-report-json "$PREV_DIR/report.json")
  validation_cmd+=(--allow-match-rate-drop-percent 0)
  validation_cmd+=(--allow-max-skew-increase-seconds 5)
fi

"${validation_cmd[@]}" >/dev/null

python3 - "$OUT_DIR/validation_report.json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)

data["is_mock"] = True
data.setdefault("messages", {})
data["messages"]["mock_bundle"] = "Synthetic listener validation bundle for tooling verification only."

with open(path, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2)
PY

echo "PASS: Mock listener validation artifacts generated: $OUT_DIR"
echo "Report: $OUT_DIR/validation_report.json"
echo "These artifacts are for tooling verification only and are not valid for real pilot signoff."
