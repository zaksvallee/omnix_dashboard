#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

INPUT_FILE=""
CLIENT_ID="CLIENT-001"
REGION_ID="REGION-GAUTENG"
SITE_ID="SITE-SANDTON"
OUT_FILE=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_serial_bench.sh --input <path> [--client-id <id>] [--region-id <id>] [--site-id <id>] [--out <path>]

Purpose:
  Replay captured Falcon/listener serial lines through the ONYX serial envelope
  normalizer and emit parsed JSON for bench validation before hardware cutover.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input)
      INPUT_FILE="${2:-}"
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
    --site-id)
      SITE_ID="${2:-}"
      shift 2
      ;;
    --out)
      OUT_FILE="${2:-}"
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

if [[ -z "$INPUT_FILE" || ! -f "$INPUT_FILE" ]]; then
  echo "FAIL: --input must point to an existing serial capture file."
  exit 1
fi

if [[ -z "$OUT_FILE" ]]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  OUT_FILE="tmp/listener_serial_bench/$stamp/parsed.json"
fi
mkdir -p "$(dirname "$OUT_FILE")"

python3 - "$INPUT_FILE" "$CLIENT_ID" "$REGION_ID" "$SITE_ID" "$OUT_FILE" <<'PY'
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

input_path = Path(sys.argv[1])
client_id = sys.argv[2]
region_id = sys.argv[3]
site_id = sys.argv[4]
out_file = Path(sys.argv[5])

accepted = []
rejected = []

def ts_from_tokens(tokens):
    for token in reversed(tokens):
        try:
            return datetime.fromisoformat(token.replace("Z", "+00:00")).astimezone(timezone.utc).isoformat().replace("+00:00", "Z")
        except Exception:
            continue
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

for raw in input_path.read_text(encoding="utf-8").splitlines():
    line = raw.strip()
    if not line:
      continue
    envelope = None
    if line.startswith("{"):
        try:
            payload = json.loads(line)
            if isinstance(payload, dict):
                occurred = payload.get("occurred_at_utc") or payload.get("timestamp")
                if occurred:
                    envelope = {
                        "provider": payload.get("provider", "falcon_serial"),
                        "transport": payload.get("transport", "serial"),
                        "external_id": payload.get("external_id") or payload.get("id") or f"falcon_serial-{occurred}",
                        "raw_line": raw,
                        "account_number": payload.get("account_number", payload.get("account", "")),
                        "partition": payload.get("partition", ""),
                        "event_code": payload.get("event_code", payload.get("code", "")),
                        "event_qualifier": payload.get("event_qualifier", payload.get("qualifier", "")),
                        "zone": payload.get("zone", ""),
                        "user_code": payload.get("user_code", payload.get("user", "")),
                        "site_id": payload.get("site_id", site_id),
                        "client_id": payload.get("client_id", client_id),
                        "region_id": payload.get("region_id", region_id),
                        "occurred_at_utc": occurred,
                        "metadata": payload.get("metadata", {}),
                    }
        except Exception:
            envelope = None
    if envelope is None:
        tokens = re.split(r"\s+", line)
        if len(tokens) >= 4 and len(tokens[0]) >= 4:
            qualifier_code = tokens[0]
            envelope = {
                "provider": "falcon_serial",
                "transport": "serial",
                "external_id": f"falcon_serial-{tokens[3]}-{tokens[1]}-{qualifier_code[1:]}-{tokens[2]}",
                "raw_line": raw,
                "account_number": tokens[3],
                "partition": tokens[1],
                "event_code": qualifier_code[1:],
                "event_qualifier": qualifier_code[0],
                "zone": tokens[2],
                "user_code": tokens[4] if len(tokens) > 4 else "",
                "site_id": site_id,
                "client_id": client_id,
                "region_id": region_id,
                "occurred_at_utc": ts_from_tokens(tokens),
                "metadata": {"parse_mode": "tokenized", "token_count": len(tokens)},
            }
    if envelope is None:
        rejected.append(raw)
    else:
        accepted.append(envelope)

payload = {"accepted": accepted, "rejected": rejected}
out_file.write_text(json.dumps(payload, indent=2), encoding="utf-8")
print(f"PASS: Parsed {len(accepted)} serial envelope(s); rejected {len(rejected)}.")
print(f"Output: {out_file}")
PY
