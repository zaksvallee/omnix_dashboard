#!/usr/bin/env bash
set -euo pipefail

SERIAL_FILE=""
LEGACY_FILE=""
OUT_FILE=""
MAX_SKEW_SECONDS=90
MIN_MATCH_RATE_PERCENT=95

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_parity_report.sh --serial <path> --legacy <path> [--out <path>] [--max-skew-seconds 90] [--min-match-rate-percent 95]

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
    --min-match-rate-percent)
      MIN_MATCH_RATE_PERCENT="${2:-95}"
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
if ! [[ "$MIN_MATCH_RATE_PERCENT" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "FAIL: --min-match-rate-percent must be a non-negative number."
  exit 1
fi

if [[ -z "$OUT_FILE" ]]; then
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  OUT_FILE="tmp/listener_parity/$stamp/report.json"
fi
mkdir -p "$(dirname "$OUT_FILE")"

python3 - "$SERIAL_FILE" "$LEGACY_FILE" "$OUT_FILE" "$MAX_SKEW_SECONDS" "$MIN_MATCH_RATE_PERCENT" <<'PY'
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
min_match_rate = float(sys.argv[5])
artifact_dir = out_file.parent
artifact_dir.mkdir(parents=True, exist_ok=True)
summary_file = artifact_dir / "report.md"

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

def classify_drift(event, candidates):
    if not candidates:
        return {
            "reason": "no_counterpart_available",
            "counterpart_external_id": "",
            "observed_skew_seconds": 0,
            "event": event,
        }

    best_site = None
    best_account = None
    best_event_code = None
    best_partition = None
    best_zone = None
    best_logical = None
    best_logical_skew = 1 << 30

    for candidate in candidates:
        if candidate.get("site_id", "") == event.get("site_id", ""):
            best_site = best_site or candidate
        if (
            candidate.get("site_id", "") == event.get("site_id", "")
            and candidate.get("account_number", "") == event.get("account_number", "")
        ):
            best_account = best_account or candidate
        if (
            candidate.get("site_id", "") == event.get("site_id", "")
            and candidate.get("account_number", "") == event.get("account_number", "")
            and candidate.get("event_code", "") == event.get("event_code", "")
        ):
            best_event_code = best_event_code or candidate
        if (
            candidate.get("site_id", "") == event.get("site_id", "")
            and candidate.get("account_number", "") == event.get("account_number", "")
            and candidate.get("event_code", "") == event.get("event_code", "")
            and (
                not event.get("partition", "")
                or not candidate.get("partition", "")
                or candidate.get("partition", "") == event.get("partition", "")
            )
        ):
            best_partition = best_partition or candidate
        if (
            candidate.get("site_id", "") == event.get("site_id", "")
            and candidate.get("account_number", "") == event.get("account_number", "")
            and candidate.get("event_code", "") == event.get("event_code", "")
            and (
                not event.get("partition", "")
                or not candidate.get("partition", "")
                or candidate.get("partition", "") == event.get("partition", "")
            )
            and (
                not event.get("zone", "")
                or not candidate.get("zone", "")
                or candidate.get("zone", "") == event.get("zone", "")
            )
        ):
            best_zone = best_zone or candidate
        if same_event(event, candidate):
            skew = abs(int((parse_dt(event["occurred_at_utc"]) - parse_dt(candidate["occurred_at_utc"])).total_seconds()))
            if skew < best_logical_skew:
                best_logical_skew = skew
                best_logical = candidate

    if best_site is None:
        return {
            "reason": "site_id_mismatch",
            "counterpart_external_id": candidates[0].get("external_id", ""),
            "observed_skew_seconds": 0,
            "event": event,
        }
    if best_account is None:
        return {
            "reason": "account_number_mismatch",
            "counterpart_external_id": best_site.get("external_id", ""),
            "observed_skew_seconds": 0,
            "event": event,
        }
    if best_event_code is None:
        return {
            "reason": "event_code_mismatch",
            "counterpart_external_id": best_account.get("external_id", ""),
            "observed_skew_seconds": 0,
            "event": event,
        }
    if best_partition is None:
        return {
            "reason": "partition_mismatch",
            "counterpart_external_id": best_event_code.get("external_id", ""),
            "observed_skew_seconds": 0,
            "event": event,
        }
    if best_zone is None:
        return {
            "reason": "zone_mismatch",
            "counterpart_external_id": best_partition.get("external_id", ""),
            "observed_skew_seconds": 0,
            "event": event,
        }
    if best_logical is not None and best_logical_skew > max_skew:
        return {
            "reason": "skew_exceeded",
            "counterpart_external_id": best_logical.get("external_id", ""),
            "observed_skew_seconds": best_logical_skew,
            "event": event,
        }
    return {
        "reason": "unclassified_mismatch",
        "counterpart_external_id": best_zone.get("external_id", ""),
        "observed_skew_seconds": 0,
        "event": event,
    }

serial = sorted(load_items(serial_file), key=lambda item: item.get("occurred_at_utc", ""))
legacy = sorted(load_items(legacy_file), key=lambda item: item.get("occurred_at_utc", ""))
available_legacy = list(legacy)
matches = []
unmatched_serial = []
unmatched_serial_drifts = []

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
        unmatched_serial_drifts.append(classify_drift(serial_item, available_legacy))
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

unmatched_legacy_drifts = [classify_drift(legacy_item, unmatched_serial) for legacy_item in available_legacy]
drift_reason_counts = {}
for drift in unmatched_serial_drifts + unmatched_legacy_drifts:
    drift_reason_counts[drift["reason"]] = drift_reason_counts.get(drift["reason"], 0) + 1

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
    "match_rate_percent": round((len(matches) / len(legacy) * 100.0), 2) if len(legacy) > 0 else (100.0 if len(serial) == 0 else 0.0),
    "min_required_match_rate_percent": round(min_match_rate, 2),
    "max_skew_seconds_observed": max((match["skew_seconds"] for match in matches), default=0),
    "average_skew_seconds": round(sum(match["skew_seconds"] for match in matches) / len(matches), 2) if matches else 0.0,
    "drift_reason_counts": drift_reason_counts,
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
    "unmatched_serial_drifts": unmatched_serial_drifts,
    "unmatched_legacy_drifts": unmatched_legacy_drifts,
}

drift_summary = ", ".join(f"{key} {value}" for key, value in drift_reason_counts.items())
report["summary"] = (
    f"serial {report['serial_count']} • legacy {report['legacy_count']} • "
    f"matched {report['matched_count']} • serial_only {report['unmatched_serial_count']} • "
    f"legacy_only {report['unmatched_legacy_count']} • match_rate {report['match_rate_percent']:.1f}% • "
    f"max_skew {report['max_skew_seconds_observed']}s • avg_skew {report['average_skew_seconds']:.1f}s • "
    f"skew<={max_skew}s"
)
if drift_summary:
    report["summary"] += f" • drift[{drift_summary}]"
report["files"]["report_markdown"] = str(summary_file)

out_file.write_text(json.dumps(report, indent=2), encoding="utf-8")
lines = [
    "# ONYX Listener Parity Report",
    "",
    f"- Generated (UTC): `{report['generated_at_utc']}`",
    f"- Artifact dir: `{artifact_dir}`",
    f"- Serial input: `{report['files']['serial_input']}`",
    f"- Legacy input: `{report['files']['legacy_input']}`",
    "",
    "## Summary",
    f"- Status line: `{report['summary']}`",
    f"- Serial count: `{report['serial_count']}`",
    f"- Legacy count: `{report['legacy_count']}`",
    f"- Matched count: `{report['matched_count']}`",
    f"- Unmatched serial count: `{report['unmatched_serial_count']}`",
    f"- Unmatched legacy count: `{report['unmatched_legacy_count']}`",
    f"- Match rate: `{report['match_rate_percent']:.2f}%`",
    f"- Required minimum match rate: `{report['min_required_match_rate_percent']:.2f}%`",
    f"- Max allowed skew: `{report['max_allowed_skew_seconds']}s`",
    f"- Max observed skew: `{report['max_skew_seconds_observed']}s`",
    f"- Average skew: `{report['average_skew_seconds']:.2f}s`",
    "",
    "## Drift Reasons",
]
if drift_reason_counts:
    for reason, count in sorted(drift_reason_counts.items()):
        lines.append(f"- `{reason}`: `{count}`")
else:
    lines.append("- None")

lines.extend(["", "## Match Samples"])
if matches:
    for match in matches[:10]:
        lines.append(
            f"- `{match['serial_external_id']}` <-> `{match['legacy_external_id']}` "
            f"(event `{match['event_code']}`, zone `{match['zone']}`, skew `{match['skew_seconds']}s`)"
        )
else:
    lines.append("- None")

lines.extend(["", "## Drift Samples"])
drift_samples = unmatched_serial_drifts[:5] + unmatched_legacy_drifts[:5]
if drift_samples:
    for drift in drift_samples:
        event = drift["event"]
        lines.append(
            f"- `{drift['reason']}` on `{event.get('external_id', '')}` "
            f"(site `{event.get('site_id', '')}`, account `{event.get('account_number', '')}`, "
            f"event `{event.get('event_code', '')}`, zone `{event.get('zone', '')}`, "
            f"counterpart `{drift.get('counterpart_external_id', '')}`, "
            f"observed skew `{drift.get('observed_skew_seconds', 0)}s`)"
        )
else:
    lines.append("- None")

summary_file.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"PASS: Listener parity report written to {out_file}")
print(f"PASS: Listener parity markdown summary written to {summary_file}")
print(report["summary"])
PY
