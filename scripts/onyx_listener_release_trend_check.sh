#!/usr/bin/env bash
set -euo pipefail

CURRENT_RELEASE_GATE_JSON=""
PREVIOUS_RELEASE_GATE_JSON=""
OUT_DIR=""
ALLOW_HOLD_REASON_INCREASE_COUNT=0
ALLOW_FAIL_REASON_INCREASE_COUNT=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_release_trend_check.sh [--current-release-gate-json <path>] [--previous-release-gate-json <path>] [--out-dir <path>] [--allow-hold-reason-increase-count 0] [--allow-fail-reason-increase-count 0]

Purpose:
  Compare one listener release gate against the previous run and fail when the
  release posture regresses.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --current-release-gate-json)
      CURRENT_RELEASE_GATE_JSON="${2:-}"
      shift 2
      ;;
    --previous-release-gate-json)
      PREVIOUS_RELEASE_GATE_JSON="${2:-}"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --allow-hold-reason-increase-count)
      ALLOW_HOLD_REASON_INCREASE_COUNT="${2:-0}"
      shift 2
      ;;
    --allow-fail-reason-increase-count)
      ALLOW_FAIL_REASON_INCREASE_COUNT="${2:-0}"
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

if ! [[ "$ALLOW_HOLD_REASON_INCREASE_COUNT" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --allow-hold-reason-increase-count must be a non-negative integer."
  exit 1
fi
if ! [[ "$ALLOW_FAIL_REASON_INCREASE_COUNT" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --allow-fail-reason-increase-count must be a non-negative integer."
  exit 1
fi

latest_release_gates() {
  local base_dir="tmp/listener_field_validation"
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
  echo "FAIL: current listener release gate not found."
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
  echo "FAIL: previous listener release gate not found."
  exit 1
fi

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$(dirname "$CURRENT_RELEASE_GATE_JSON")"
fi
mkdir -p "$OUT_DIR"

python3 - "$CURRENT_RELEASE_GATE_JSON" "$PREVIOUS_RELEASE_GATE_JSON" "$OUT_DIR" "$ALLOW_HOLD_REASON_INCREASE_COUNT" "$ALLOW_FAIL_REASON_INCREASE_COUNT" <<'PY'
import json
import sys
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

def path_exists(raw_path):
    candidate = str(raw_path or "").strip()
    if not candidate:
        return True
    return Path(candidate).is_file()

def gate_chain_regressions(report, label):
    regressions = []
    validation_report = str(report.get("validation_report_json", "")).strip()
    readiness_report = str(report.get("readiness_report_json", "")).strip()
    cutover_decision = str(report.get("cutover_decision_json", "")).strip()
    cutover_trend = str(report.get("cutover_trend_report_json", "")).strip()
    signoff_file = str(report.get("signoff_file", "")).strip()
    signoff_report = str(report.get("signoff_report_json", "")).strip()
    for field_name, value in (
        ("validation_report", validation_report),
        ("readiness_report", readiness_report),
        ("cutover_decision", cutover_decision),
        ("cutover_trend_report", cutover_trend),
        ("signoff_file", signoff_file),
        ("signoff_report", signoff_report),
    ):
        if value and not path_exists(value):
            regressions.append({
                "code": f"{label}_gate_missing_{field_name}",
                "kind": "gate_chain_missing_file",
                "gate_label": label,
                "missing_field": field_name,
                "missing_path": value,
            })
    return regressions

result_rank = {"FAIL": 0, "HOLD": 1, "PASS": 2}

current_result = str(current.get("result", "")).upper()
previous_result = str(previous.get("result", "")).upper()

current_hold_codes = list(current.get("hold_codes", []) or current.get("hold_reasons", []) or [])
previous_hold_codes = list(previous.get("hold_codes", []) or previous.get("hold_reasons", []) or [])
current_fail_codes = list(current.get("fail_codes", []) or current.get("fail_reasons", []) or [])
previous_fail_codes = list(previous.get("fail_codes", []) or previous.get("fail_reasons", []) or [])

regressions = []
regressions.extend(gate_chain_regressions(current, "current"))
regressions.extend(gate_chain_regressions(previous, "previous"))
if result_rank.get(current_result, -1) < result_rank.get(previous_result, -1):
    regressions.append(
        {
            "code": "result_regression",
            "kind": "result_regression",
            "previous": previous_result,
            "current": current_result,
        }
    )

hold_increase = len(current_hold_codes) - len(previous_hold_codes)
if hold_increase > allow_hold_increase:
    regressions.append(
        {
            "code": "hold_reason_increase",
            "kind": "hold_reason_increase",
            "previous": len(previous_hold_codes),
            "current": len(current_hold_codes),
            "delta": hold_increase,
            "allowed_increase": allow_hold_increase,
        }
    )

fail_increase = len(current_fail_codes) - len(previous_fail_codes)
if fail_increase > allow_fail_increase:
    regressions.append(
        {
            "code": "fail_reason_increase",
            "kind": "fail_reason_increase",
            "previous": len(previous_fail_codes),
            "current": len(current_fail_codes),
            "delta": fail_increase,
            "allowed_increase": allow_fail_increase,
        }
    )

new_hold_codes = sorted(set(current_hold_codes) - set(previous_hold_codes))
new_fail_codes = sorted(set(current_fail_codes) - set(previous_fail_codes))

status = "PASS" if not regressions else "FAIL"
result = {
    "status": status,
    "summary": (
        f"release {previous_result or 'missing'} -> {current_result or 'missing'}; "
        f"hold codes {len(previous_hold_codes)} -> {len(current_hold_codes)}; "
        f"fail codes {len(previous_fail_codes)} -> {len(current_fail_codes)}"
    ),
    "current_release_gate_json": str(current_path),
    "previous_release_gate_json": str(previous_path),
    "result": {
        "previous": previous_result,
        "current": current_result,
    },
    "counts": {
        "hold_reasons": {
            "previous": len(previous_hold_codes),
            "current": len(current_hold_codes),
            "delta": hold_increase,
            "allowed_increase": allow_hold_increase,
        },
        "fail_reasons": {
            "previous": len(previous_fail_codes),
            "current": len(current_fail_codes),
            "delta": fail_increase,
            "allowed_increase": allow_fail_increase,
        },
    },
    "new_hold_reasons": new_hold_codes,
    "new_fail_reasons": new_fail_codes,
    "primary_regression_code": regressions[0]["code"] if regressions else "",
    "regression_codes": [item["code"] for item in regressions],
    "regressions": regressions,
}

json_out = out_dir / "release_trend_report.json"
md_out = out_dir / "release_trend_report.md"
json_out.write_text(json.dumps(result, indent=2), encoding="utf-8")

lines = [
    "# ONYX Listener Release Trend Report",
    "",
    f"- Status: `{status}`",
    f"- Current release gate: `{current_path}`",
    f"- Previous release gate: `{previous_path}`",
    "",
    "## Summary",
    f"- `{result['summary']}`",
    "",
    "## Result Delta",
    f"- Result: `{previous_result or 'missing'} -> {current_result or 'missing'}`",
    "",
    "## Count Deltas",
    (
        f"- Hold codes: `{len(previous_hold_codes)} -> {len(current_hold_codes)}` "
        f"(delta `{hold_increase}`, allowed `{allow_hold_increase}`)"
    ),
    (
        f"- Fail codes: `{len(previous_fail_codes)} -> {len(current_fail_codes)}` "
        f"(delta `{fail_increase}`, allowed `{allow_fail_increase}`)"
    ),
    "",
    "## New Hold Codes",
]
if new_hold_codes:
    for item in new_hold_codes:
        lines.append(f"- {item}")
else:
    lines.append("- None")

lines.extend(["", "## New Fail Codes"])
if new_fail_codes:
    for item in new_fail_codes:
        lines.append(f"- {item}")
else:
    lines.append("- None")

lines.extend(["", "## Regressions"])
if regressions:
    for item in regressions:
        if item["kind"] == "result_regression":
            lines.append(f"- `{item['code']}`: `{item['previous']} -> {item['current']}`")
        elif item["kind"] == "gate_chain_missing_file":
            lines.append(
                f"- `{item['code']}`: `{item['gate_label']}` gate missing "
                f"`{item['missing_field']}` at `{item['missing_path']}`"
            )
        else:
            lines.append(
                f"- `{item['code']}`: `{item['previous']} -> {item['current']}` "
                f"(delta `{item['delta']}`, allowed `{item['allowed_increase']}`)"
            )
else:
    lines.append("- None")

md_out.write_text("\n".join(lines) + "\n", encoding="utf-8")

print(f"Release trend artifact: {json_out}")
print(f"Release trend markdown: {md_out}")
print(f"Status: {status}")

if regressions:
    for item in regressions:
        if item["kind"] == "result_regression":
            print(f"REGRESSION: {item['code']} {item['previous']} -> {item['current']}")
        elif item["kind"] == "gate_chain_missing_file":
            print(
                f"REGRESSION: {item['code']} {item['gate_label']} missing "
                f"{item['missing_field']} at {item['missing_path']}"
            )
        else:
            print(
                f"REGRESSION: {item['code']} {item['previous']} -> {item['current']} "
                f"(delta {item['delta']}, allowed {item['allowed_increase']})"
            )
    sys.exit(1)
PY
