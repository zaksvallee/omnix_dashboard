#!/usr/bin/env bash
set -euo pipefail

SERIAL_FILE=""
LEGACY_FILE=""
OUT_FILE=""
MAX_SKEW_SECONDS=90

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_parity_report.sh --serial <path> --legacy <path> [--out <path>] [--max-skew-seconds 90]

Purpose:
  Compare normalized serial listener envelopes against legacy listener envelopes
  and emit a parity report for dual-path pilot validation.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --serial)
      SERIAL_FILE="${2:-}"
      shift 2
      ;;
    --legacy)
      LEGACY_FILE="${2:-}"
      shift 2
      ;;
    --out)
      OUT_FILE="${2:-}"
      shift 2
      ;;
    --max-skew-seconds)
      MAX_SKEW_SECONDS="${2:-90}"
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

if [[ -z "$SERIAL_FILE" || ! -f "$SERIAL_FILE" ]]; then
  echo "FAIL: --serial must point to an existing JSON file."
  exit 1
fi
if [[ -z "$LEGACY_FILE" || ! -f "$LEGACY_FILE" ]]; then
  echo "FAIL: --legacy must point to an existing JSON file."
  exit 1
fi
if ! [[ "$MAX_SKEW_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --max-skew-seconds must be a non-negative integer."
  exit 1
fi

if [[ -z "$OUT_FILE" ]]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  OUT_FILE="tmp/listener_parity/$stamp/report.json"
fi
mkdir -p "$(dirname "$OUT_FILE")"

python3 - "$SERIAL_FILE" "$LEGACY_FILE" "$OUT_FILE" "$MAX_SKEW_SECONDS" <<'PY'
import json
import hashlib
import shutil
import sys
from datetime import datetime
from pathlib import Path

serial_file = Path(sys.argv[1])
legacy_file = Path(sys.argv[2])
out_file = Path(sys.argv[3])
max_skew = int(sys.argv[4])
artifact_dir = out_file.parent
artifact_dir.mkdir(parents=True, exist_ok=True)

serial_copy = artifact_dir / "serial_input.json"
legacy_copy = artifact_dir / "legacy_input.json"
shutil.copyfile(serial_file, serial_copy)
shutil.copyfile(legacy_file, legacy_copy)

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def load_items(path: Path):
    payload = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(payload, dict) and isinstance(payload.get("accepted"), list):
        return payload["accepted"]
    if isinstance(payload, list):
        return payload
    raise SystemExit(f"Unsupported payload shape: {path}")

def parse_dt(raw: str):
    return datetime.fromisoformat(raw.replace("Z", "+00:00"))

def same_event(left, right):
    if left.get("site_id", "") != right.get("site_id", ""):
        return False
    if left.get("account_number", "") != right.get("account_number", ""):
        return False
    if left.get("event_code", "") != right.get("event_code", ""):
        return False
    left_zone = left.get("zone", "")
    right_zone = right.get("zone", "")
    if left_zone and right_zone and left_zone != right_zone:
        return False
    left_partition = left.get("partition", "")
    right_partition = right.get("partition", "")
    if left_partition and right_partition and left_partition != right_partition:
        return False
    return True

serial = sorted(load_items(serial_file), key=lambda item: item.get("occurred_at_utc", ""))
legacy = sorted(load_items(legacy_file), key=lambda item: item.get("occurred_at_utc", ""))
available_legacy = list(legacy)
matches = []
unmatched_serial = []

for serial_item in serial:
    best_index = None
    best_skew = max_skew + 1
    for index, legacy_item in enumerate(available_legacy):
        if not same_event(serial_item, legacy_item):
            continue
        skew = abs(int((parse_dt(serial_item["occurred_at_utc"]) - parse_dt(legacy_item["occurred_at_utc"])).total_seconds()))
        if skew <= max_skew and skew < best_skew:
            best_index = index
            best_skew = skew
    if best_index is None:
        unmatched_serial.append(serial_item)
    else:
        legacy_item = available_legacy.pop(best_index)
        matches.append({
            "serial_external_id": serial_item.get("external_id", ""),
            "legacy_external_id": legacy_item.get("external_id", ""),
            "site_id": serial_item.get("site_id", ""),
            "account_number": serial_item.get("account_number", ""),
            "event_code": serial_item.get("event_code", ""),
            "zone": serial_item.get("zone", ""),
            "skew_seconds": best_skew,
        })

report = {
    "generated_at_utc": datetime.utcnow().isoformat(timespec="seconds") + "Z",
    "artifact_dir": str(artifact_dir),
    "capture_dir": str(legacy_file.parent),
    "serial_count": len(serial),
    "legacy_count": len(legacy),
    "matched_count": len(matches),
    "unmatched_serial_count": len(unmatched_serial),
    "unmatched_legacy_count": len(available_legacy),
    "max_allowed_skew_seconds": max_skew,
    "summary": f"serial {len(serial)} • legacy {len(legacy)} • matched {len(matches)} • serial_only {len(unmatched_serial)} • legacy_only {len(available_legacy)} • skew<={max_skew}s",
    "files": {
        "serial_input": str(serial_copy),
        "legacy_input": str(legacy_copy),
        "source_serial_input": str(serial_file),
        "source_legacy_input": str(legacy_file),
    },
    "checksums": {
        "serial_input_sha256": sha(serial_copy),
        "legacy_input_sha256": sha(legacy_copy),
    },
    "matches": matches,
    "unmatched_serial": unmatched_serial,
    "unmatched_legacy": available_legacy,
}

out_file.write_text(json.dumps(report, indent=2), encoding="utf-8")
print(f"PASS: Listener parity report written to {out_file}")
print(report["summary"])
PY
