#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

SOURCE_JSON=""
BASELINE_JSON=""
OUT_FILE=""
REPLACE_SIGNATURES=0
FORCE=0
SET_MAX_CAPTURE_SIGNATURES=""
SET_MAX_UNEXPECTED_SIGNATURES=""
SET_MAX_FALLBACK_TIMESTAMP_COUNT=""
SET_MAX_UNKNOWN_EVENT_RATE_PERCENT=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_bench_baseline_promote.sh [--source-json <path>]
    [--baseline-json <path>]
    [--out <path>]
    [--replace-signatures]
    [--set-max-capture-signatures <count>]
    [--set-max-unexpected-signatures <count>]
    [--set-max-fallback-timestamp-count <count>]
    [--set-max-unknown-event-rate-percent <percent>]
    [--force]

Purpose:
  Promote observed listener bench signatures into listener_bench_baseline.json
  from a passing serial_parsed.json or validation_report.json artifact while
  recording an audit trail inside the baseline file.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source-json)
      SOURCE_JSON="${2:-}"
      shift 2
      ;;
    --baseline-json)
      BASELINE_JSON="${2:-}"
      shift 2
      ;;
    --out)
      OUT_FILE="${2:-}"
      shift 2
      ;;
    --replace-signatures)
      REPLACE_SIGNATURES=1
      shift
      ;;
    --set-max-capture-signatures)
      SET_MAX_CAPTURE_SIGNATURES="${2:-}"
      shift 2
      ;;
    --set-max-unexpected-signatures)
      SET_MAX_UNEXPECTED_SIGNATURES="${2:-}"
      shift 2
      ;;
    --set-max-fallback-timestamp-count)
      SET_MAX_FALLBACK_TIMESTAMP_COUNT="${2:-}"
      shift 2
      ;;
    --set-max-unknown-event-rate-percent)
      SET_MAX_UNKNOWN_EVENT_RATE_PERCENT="${2:-}"
      shift 2
      ;;
    --force)
      FORCE=1
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

latest_validation_report_json() {
  local base_dir="tmp/listener_field_validation"
  if [[ ! -d "$base_dir" ]]; then
    return 1
  fi
  find "$base_dir" -type f -name "validation_report.json" -print0 2>/dev/null \
    | xargs -0 ls -1t 2>/dev/null \
    | head -n 1
}

if [[ -z "$SOURCE_JSON" ]]; then
  SOURCE_JSON="$(latest_validation_report_json || true)"
fi
if [[ -z "$SOURCE_JSON" || ! -f "$SOURCE_JSON" ]]; then
  echo "FAIL: --source-json must point to an existing JSON artifact or a latest validation_report.json must exist."
  exit 1
fi
if [[ -n "$SET_MAX_CAPTURE_SIGNATURES" ]] && ! [[ "$SET_MAX_CAPTURE_SIGNATURES" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --set-max-capture-signatures must be a non-negative integer."
  exit 1
fi
if [[ -n "$SET_MAX_UNEXPECTED_SIGNATURES" ]] && ! [[ "$SET_MAX_UNEXPECTED_SIGNATURES" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --set-max-unexpected-signatures must be a non-negative integer."
  exit 1
fi
if [[ -n "$SET_MAX_FALLBACK_TIMESTAMP_COUNT" ]] && ! [[ "$SET_MAX_FALLBACK_TIMESTAMP_COUNT" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --set-max-fallback-timestamp-count must be a non-negative integer."
  exit 1
fi
if [[ -n "$SET_MAX_UNKNOWN_EVENT_RATE_PERCENT" ]] && ! [[ "$SET_MAX_UNKNOWN_EVENT_RATE_PERCENT" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "FAIL: --set-max-unknown-event-rate-percent must be a non-negative number."
  exit 1
fi

resolve_and_promote() {
  python3 - "$SOURCE_JSON" "$BASELINE_JSON" "$OUT_FILE" "$REPLACE_SIGNATURES" "$FORCE" \
    "$SET_MAX_CAPTURE_SIGNATURES" "$SET_MAX_UNEXPECTED_SIGNATURES" "$SET_MAX_FALLBACK_TIMESTAMP_COUNT" "$SET_MAX_UNKNOWN_EVENT_RATE_PERCENT" <<'PY'
import json
import sys
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path

source_json = Path(sys.argv[1]).resolve()
baseline_json_arg = sys.argv[2].strip()
out_file_arg = sys.argv[3].strip()
replace_signatures = sys.argv[4] == "1"
force = sys.argv[5] == "1"
cli_max_capture_signatures = sys.argv[6].strip()
cli_max_unexpected_signatures = sys.argv[7].strip()
cli_max_fallback_timestamp_count = sys.argv[8].strip()
cli_max_unknown_event_rate_percent = sys.argv[9].strip()


def load_json(path: Path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


def parse_optional_int(raw: str):
    return None if not raw else int(raw)


def parse_optional_float(raw: str):
    return None if not raw else float(raw)


source_data = load_json(source_json)
source_kind = ""
serial_report_path = None
review = {}
site_id = ""
device_path = ""
thresholds = {}
observed_signatures = []

if isinstance(source_data, dict) and "baseline_review" in source_data:
    source_kind = "validation_report"
    review = deepcopy(source_data.get("baseline_review") or {})
    source_files = source_data.get("files") or {}
    serial_report_value = str(source_files.get("serial_parsed_json") or "").strip()
    if serial_report_value:
      serial_report_path = Path(serial_report_value)
      if not serial_report_path.is_absolute():
          serial_report_path = (source_json.parent / serial_report_path).resolve()
    if serial_report_path and serial_report_path.is_file():
        serial_report = load_json(serial_report_path)
        thresholds = deepcopy((serial_report.get("anomaly_gate") or {}).get("thresholds") or {})
    observed_signatures = list(review.get("observed_signatures") or [])
    site_id = str(source_data.get("site_id") or "").strip()
    device_path = str(source_data.get("device_path") or "").strip()
elif isinstance(source_data, dict) and "anomaly_gate" in source_data and "stats" in source_data:
    source_kind = "serial_parsed"
    serial_report_path = source_json
    thresholds = deepcopy((source_data.get("anomaly_gate") or {}).get("thresholds") or {})
    observed_signatures = sorted((source_data.get("stats") or {}).get("capture_signature_counts", {}).keys())
    review = {
        "status": str((source_data.get("anomaly_gate") or {}).get("status") or "WARN").upper(),
        "recommendation": "hold_baseline" if str((source_data.get("anomaly_gate") or {}).get("status") or "").upper() == "PASS" else "investigate_new_frame_shape",
        "summary": "Promotion sourced directly from serial_parsed.json.",
        "observed_signatures": observed_signatures,
    }
else:
    raise SystemExit("FAIL: --source-json must be a validation_report.json or serial_parsed.json artifact.")

baseline_path = None
if baseline_json_arg:
    baseline_path = Path(baseline_json_arg)
    if not baseline_path.is_absolute():
        baseline_path = (Path.cwd() / baseline_path).resolve()
elif source_kind == "validation_report":
    explicit_baseline = str(source_data.get("files", {}).get("bench_baseline_json") or source_data.get("bench_baseline_json") or "").strip()
    if explicit_baseline:
        baseline_path = Path(explicit_baseline)
        if not baseline_path.is_absolute():
            baseline_path = (source_json.parent / baseline_path).resolve()

if not baseline_path:
    raise SystemExit("FAIL: Could not resolve listener_bench_baseline.json. Pass --baseline-json explicitly.")

out_path = Path(out_file_arg).resolve() if out_file_arg else baseline_path
baseline_data = load_json(baseline_path) if baseline_path.is_file() else {}

review_status = str(review.get("status") or "").upper()
recommendation = str(review.get("recommendation") or "").strip() or "hold_baseline"
summary = str(review.get("summary") or "").strip()

if review_status == "FAIL" and not force:
    raise SystemExit(
        "FAIL: Baseline review status is FAIL. Refusing promotion without --force."
    )
if recommendation == "investigate_new_frame_shape" and not force:
    raise SystemExit(
        "FAIL: Baseline review recommends investigate_new_frame_shape. Refusing promotion without --force."
    )

existing_signatures = list(baseline_data.get("allowed_capture_signatures") or [])
observed_signatures = sorted(set(str(item).strip() for item in observed_signatures if str(item).strip()))
if replace_signatures:
    promoted_signatures = observed_signatures
else:
    promoted_signatures = sorted(set(existing_signatures) | set(observed_signatures))

def choose_value(cli_value, source_value, existing_value):
    if cli_value is not None:
        return cli_value
    if source_value not in ("", None, []):
        return source_value
    return existing_value

updated = deepcopy(baseline_data)
updated["site_id"] = site_id or str(updated.get("site_id") or "").strip()
updated["device_path"] = device_path or str(updated.get("device_path") or "").strip()
updated["allowed_capture_signatures"] = promoted_signatures
updated["max_capture_signatures"] = choose_value(
    parse_optional_int(cli_max_capture_signatures),
    thresholds.get("max_capture_signatures"),
    updated.get("max_capture_signatures"),
)
updated["max_unexpected_signatures"] = choose_value(
    parse_optional_int(cli_max_unexpected_signatures),
    thresholds.get("max_unexpected_signatures"),
    updated.get("max_unexpected_signatures"),
)
updated["max_fallback_timestamp_count"] = choose_value(
    parse_optional_int(cli_max_fallback_timestamp_count),
    thresholds.get("max_fallback_timestamp_count"),
    updated.get("max_fallback_timestamp_count"),
)
updated["max_unknown_event_rate_percent"] = choose_value(
    parse_optional_float(cli_max_unknown_event_rate_percent),
    thresholds.get("max_unknown_event_rate_percent"),
    updated.get("max_unknown_event_rate_percent"),
)

if "notes" not in updated:
    updated["notes"] = ""

audit_keys = {
    "promotion_history",
    "last_promoted_at_utc",
    "last_promoted_from",
    "last_promotion_mode",
    "last_review_recommendation",
}

comparison_before = deepcopy(baseline_data)
comparison_after = deepcopy(updated)
for key in audit_keys:
    comparison_before.pop(key, None)
    comparison_after.pop(key, None)
changed = comparison_before != comparison_after

if not changed and not force:
    print("PASS: Listener bench baseline already covers the observed signatures; no update written.")
    print(f"Baseline: {baseline_path}")
    print(f"Recommendation: {recommendation}")
    raise SystemExit(0)

promotion_mode = "replace_signatures" if replace_signatures else "merge_signatures"
new_signature_count = len(set(promoted_signatures) - set(existing_signatures))
history = list(updated.get("promotion_history") or [])
audit_entry = {
    "promoted_at_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "source_json": str(source_json),
    "source_kind": source_kind,
    "promotion_mode": promotion_mode,
    "review_status": review_status or "UNKNOWN",
    "recommendation": recommendation,
    "summary": summary,
    "observed_signatures": observed_signatures,
    "promoted_signatures_added": sorted(set(promoted_signatures) - set(existing_signatures)),
    "promoted_signature_count": len(promoted_signatures),
    "bench_thresholds": {
        "max_capture_signatures": updated.get("max_capture_signatures"),
        "max_unexpected_signatures": updated.get("max_unexpected_signatures"),
        "max_fallback_timestamp_count": updated.get("max_fallback_timestamp_count"),
        "max_unknown_event_rate_percent": updated.get("max_unknown_event_rate_percent"),
    },
}
history.append(audit_entry)
updated["promotion_history"] = history[-20:]
updated["last_promoted_at_utc"] = audit_entry["promoted_at_utc"]
updated["last_promoted_from"] = str(source_json)
updated["last_promotion_mode"] = promotion_mode
updated["last_review_recommendation"] = recommendation

out_path.parent.mkdir(parents=True, exist_ok=True)
with open(out_path, "w", encoding="utf-8") as handle:
    json.dump(updated, handle, indent=2)
    handle.write("\n")

print("PASS: Listener bench baseline updated.")
print(f"Baseline: {out_path}")
print(f"Source: {source_json}")
print(f"Recommendation: {recommendation}")
print(f"Promotion mode: {promotion_mode}")
print(f"Observed signatures: {len(observed_signatures)}")
print(f"Added signatures: {new_signature_count}")
print(f"Total baseline signatures: {len(promoted_signatures)}")
PY
}

resolve_and_promote
