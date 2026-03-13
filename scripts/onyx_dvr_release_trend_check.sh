#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CURRENT_RELEASE_GATE_JSON=""
PREVIOUS_RELEASE_GATE_JSON=""
OUT_DIR=""
ALLOW_HOLD_REASON_INCREASE_COUNT=0
ALLOW_FAIL_REASON_INCREASE_COUNT=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_dvr_release_trend_check.sh [--current-release-gate-json <path>] [--previous-release-gate-json <path>] [--out-dir <path>] [--allow-hold-reason-increase-count <count>] [--allow-fail-reason-increase-count <count>]

Purpose:
  Compare one DVR release gate against the previous run and fail when the
  release posture regresses.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --current-release-gate-json) CURRENT_RELEASE_GATE_JSON="${2:-}"; shift 2 ;;
    --previous-release-gate-json) PREVIOUS_RELEASE_GATE_JSON="${2:-}"; shift 2 ;;
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    --allow-hold-reason-increase-count) ALLOW_HOLD_REASON_INCREASE_COUNT="${2:-0}"; shift 2 ;;
    --allow-fail-reason-increase-count) ALLOW_FAIL_REASON_INCREASE_COUNT="${2:-0}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "FAIL: Unknown argument: $1"; exit 1 ;;
  esac
done

if ! [[ "$ALLOW_HOLD_REASON_INCREASE_COUNT" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --allow-hold-reason-increase-count must be a non-negative integer."
  exit 1
fi
if ! [[ "$ALLOW_FAIL_REASON_INCREASE_COUNT" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --allow-fail-reason-increase-count must be a non-negative integer."
  exit 1
fi

latest_release_gates() {
  local base_dir="tmp/dvr_field_validation"
  if [[ ! -d "$base_dir" ]]; then
    return 1
  fi
  find "$base_dir" -type f -name "release_gate.json" -print0 2>/dev/null \
    | xargs -0 ls -1t 2>/dev/null
}

if [[ -z "$CURRENT_RELEASE_GATE_JSON" ]]; then
  CURRENT_RELEASE_GATE_JSON="$(latest_release_gates | sed -n '1p' || true)"
fi
if [[ -z "$CURRENT_RELEASE_GATE_JSON" || ! -f "$CURRENT_RELEASE_GATE_JSON" ]]; then
  echo "FAIL: current DVR release gate not found."
  exit 1
fi

if [[ -z "$PREVIOUS_RELEASE_GATE_JSON" ]]; then
  PREVIOUS_RELEASE_GATE_JSON="$(
    latest_release_gates \
      | awk -v current="$CURRENT_RELEASE_GATE_JSON" '$0 != current { print; exit }' \
      || true
  )"
fi
if [[ -z "$PREVIOUS_RELEASE_GATE_JSON" || ! -f "$PREVIOUS_RELEASE_GATE_JSON" ]]; then
  echo "FAIL: previous DVR release gate not found."
  exit 1
fi

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$(dirname "$CURRENT_RELEASE_GATE_JSON")"
fi
mkdir -p "$OUT_DIR"

python3 - "$CURRENT_RELEASE_GATE_JSON" "$PREVIOUS_RELEASE_GATE_JSON" "$OUT_DIR" "$ALLOW_HOLD_REASON_INCREASE_COUNT" "$ALLOW_FAIL_REASON_INCREASE_COUNT" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

current_path = Path(sys.argv[1])
previous_path = Path(sys.argv[2])
out_dir = Path(sys.argv[3])
allow_hold_increase = int(sys.argv[4])
allow_fail_increase = int(sys.argv[5])

with current_path.open("r", encoding="utf-8") as handle:
    current = json.load(handle)
with previous_path.open("r", encoding="utf-8") as handle:
    previous = json.load(handle)

rank = {"PASS": 0, "HOLD": 1, "FAIL": 2}
current_result = str(current.get("result", "")).upper()
previous_result = str(previous.get("result", "")).upper()
current_hold_codes = [str(item) for item in (current.get("hold_codes", []) or []) if str(item)]
previous_hold_codes = [str(item) for item in (previous.get("hold_codes", []) or []) if str(item)]
current_fail_codes = [str(item) for item in (current.get("fail_codes", []) or []) if str(item)]
previous_fail_codes = [str(item) for item in (previous.get("fail_codes", []) or []) if str(item)]

regressions = []

if rank.get(current_result, 99) > rank.get(previous_result, 99):
    regressions.append({
        "code": "result_regression",
        "message": f"Release result regressed from {previous_result or 'UNKNOWN'} to {current_result or 'UNKNOWN'}.",
    })

hold_increase = max(0, len(current_hold_codes) - len(previous_hold_codes))
if hold_increase > allow_hold_increase:
    regressions.append({
        "code": "hold_reason_increase",
        "message": (
            f"Release hold code count increased from {len(previous_hold_codes)} to "
            f"{len(current_hold_codes)}."
        ),
    })

fail_increase = max(0, len(current_fail_codes) - len(previous_fail_codes))
if fail_increase > allow_fail_increase:
    regressions.append({
        "code": "fail_reason_increase",
        "message": (
            f"Release fail code count increased from {len(previous_fail_codes)} to "
            f"{len(current_fail_codes)}."
        ),
    })

status = "FAIL" if regressions else "PASS"
summary = (
    "DVR release posture regressed against the previous run."
    if regressions
    else "DVR release posture is stable or improved against the previous run."
)
regression_codes = [item["code"] for item in regressions]
primary_regression_code = regression_codes[0] if regression_codes else ""

report = {
    "generated_at_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
    "status": status,
    "summary": summary,
    "current_release_gate_json": str(current_path),
    "previous_release_gate_json": str(previous_path),
    "current_result": current_result,
    "previous_result": previous_result,
    "allow_hold_reason_increase_count": allow_hold_increase,
    "allow_fail_reason_increase_count": allow_fail_increase,
    "observed": {
        "current_hold_code_count": len(current_hold_codes),
        "previous_hold_code_count": len(previous_hold_codes),
        "current_fail_code_count": len(current_fail_codes),
        "previous_fail_code_count": len(previous_fail_codes),
    },
    "regressions": regressions,
    "regression_codes": regression_codes,
    "primary_regression_code": primary_regression_code,
}

json_path = out_dir / "release_trend_report.json"
md_path = out_dir / "release_trend_report.md"
json_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
md_path.write_text(
    "\n".join(
        [
            "# ONYX DVR Release Trend Report",
            "",
            f"- Status: {status}",
            f"- Summary: {summary}",
            f"- Current result: {current_result or 'UNKNOWN'}",
            f"- Previous result: {previous_result or 'UNKNOWN'}",
            f"- Primary regression code: {primary_regression_code or 'none'}",
            "",
            "## Regressions",
            *([f"- {item['message']} (`{item['code']}`)" for item in regressions] or ["- none"]),
        ]
    ) + "\n",
    encoding="utf-8",
)

print(json_path)
print(md_path)
print(status)
if regressions:
    sys.exit(1)
PY
