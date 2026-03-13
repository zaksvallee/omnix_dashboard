#!/usr/bin/env bash
set -euo pipefail

CURRENT_DECISION_JSON=""
PREVIOUS_DECISION_JSON=""
OUT_DIR=""
ALLOW_HOLD_REASON_INCREASE_COUNT=0
ALLOW_BLOCKING_REASON_INCREASE_COUNT=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_cutover_trend_check.sh [--current-decision-json <path>] [--previous-decision-json <path>] [--out-dir <path>] [--allow-hold-reason-increase-count 0] [--allow-blocking-reason-increase-count 0]

Purpose:
  Compare one listener cutover decision against the previous run and fail when
  the cutover posture regresses.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --current-decision-json)
      CURRENT_DECISION_JSON="${2:-}"
      shift 2
      ;;
    --previous-decision-json)
      PREVIOUS_DECISION_JSON="${2:-}"
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
    --allow-blocking-reason-increase-count)
      ALLOW_BLOCKING_REASON_INCREASE_COUNT="${2:-0}"
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
if ! [[ "$ALLOW_BLOCKING_REASON_INCREASE_COUNT" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --allow-blocking-reason-increase-count must be a non-negative integer."
  exit 1
fi

latest_decisions() {
  local base_dir="tmp/listener_field_validation"
  if [[ ! -d "$base_dir" ]]; then
    return 1
  fi
  find "$base_dir" -type f -name "cutover_decision.json" -print0 2>/dev/null \
    | xargs -0 ls -1t 2>/dev/null
}

if [[ -z "$CURRENT_DECISION_JSON" ]]; then
  CURRENT_DECISION_JSON="$(latest_decisions | sed -n '1p' || true)"
fi
if [[ -z "$CURRENT_DECISION_JSON" || ! -f "$CURRENT_DECISION_JSON" ]]; then
  echo "FAIL: current listener cutover decision not found."
  exit 1
fi

if [[ -z "$PREVIOUS_DECISION_JSON" ]]; then
  PREVIOUS_DECISION_JSON="$(
    latest_decisions \
      | awk -v current="$CURRENT_DECISION_JSON" '$0 != current { print; exit }' \
      || true
  )"
fi
if [[ -z "$PREVIOUS_DECISION_JSON" || ! -f "$PREVIOUS_DECISION_JSON" ]]; then
  echo "FAIL: previous listener cutover decision not found."
  exit 1
fi

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$(dirname "$CURRENT_DECISION_JSON")"
fi
mkdir -p "$OUT_DIR"

python3 - "$CURRENT_DECISION_JSON" "$PREVIOUS_DECISION_JSON" "$OUT_DIR" "$ALLOW_HOLD_REASON_INCREASE_COUNT" "$ALLOW_BLOCKING_REASON_INCREASE_COUNT" <<'PY'
import json
import sys
from pathlib import Path

current_path = Path(sys.argv[1])
previous_path = Path(sys.argv[2])
out_dir = Path(sys.argv[3])
allow_hold_increase = int(sys.argv[4])
allow_blocking_increase = int(sys.argv[5])

with current_path.open("r", encoding="utf-8") as handle:
    current = json.load(handle)
with previous_path.open("r", encoding="utf-8") as handle:
    previous = json.load(handle)

def path_exists(raw_path):
    candidate = str(raw_path or "").strip()
    if not candidate:
        return True
    return Path(candidate).is_file()

def decision_chain_regressions(report, label):
    regressions = []
    validation_report = str(report.get("validation_report_json", "")).strip()
    parity_report = str(report.get("parity_report_json", "")).strip()
    parity_trend_report = str(report.get("parity_trend_report_json", "")).strip()
    validation_trend_report = str(report.get("validation_trend_report_json", "")).strip()
    for field_name, value in (
        ("validation_report", validation_report),
        ("parity_report", parity_report),
        ("parity_trend_report", parity_trend_report),
        ("validation_trend_report", validation_trend_report),
    ):
        if value and not path_exists(value):
            regressions.append({
                "code": f"{label}_decision_missing_{field_name}",
                "kind": "decision_chain_missing_file",
                "decision_label": label,
                "missing_field": field_name,
                "missing_path": value,
            })
    return regressions

decision_rank = {"BLOCK": 0, "HOLD": 1, "GO": 2}

current_decision = str(current.get("decision", "")).upper()
previous_decision = str(previous.get("decision", "")).upper()

current_hold_codes = list(current.get("hold_codes", []) or current.get("hold_reasons", []) or [])
previous_hold_codes = list(previous.get("hold_codes", []) or previous.get("hold_reasons", []) or [])
current_blocking_codes = list(current.get("blocking_codes", []) or current.get("blocking_reasons", []) or [])
previous_blocking_codes = list(previous.get("blocking_codes", []) or previous.get("blocking_reasons", []) or [])

regressions = []
regressions.extend(decision_chain_regressions(current, "current"))
regressions.extend(decision_chain_regressions(previous, "previous"))
if decision_rank.get(current_decision, -1) < decision_rank.get(previous_decision, -1):
    regressions.append(
        {
            "code": "decision_regression",
            "kind": "decision_regression",
            "previous": previous_decision,
            "current": current_decision,
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

blocking_increase = len(current_blocking_codes) - len(previous_blocking_codes)
if blocking_increase > allow_blocking_increase:
    regressions.append(
        {
            "code": "blocking_reason_increase",
            "kind": "blocking_reason_increase",
            "previous": len(previous_blocking_codes),
            "current": len(current_blocking_codes),
            "delta": blocking_increase,
            "allowed_increase": allow_blocking_increase,
        }
    )

new_hold_codes = sorted(set(current_hold_codes) - set(previous_hold_codes))
new_blocking_codes = sorted(set(current_blocking_codes) - set(previous_blocking_codes))

status = "PASS" if not regressions else "FAIL"
result = {
    "status": status,
    "summary": (
        f"cutover {previous_decision or 'missing'} -> {current_decision or 'missing'}; "
        f"hold codes {len(previous_hold_codes)} -> {len(current_hold_codes)}; "
        f"blocking codes {len(previous_blocking_codes)} -> {len(current_blocking_codes)}"
    ),
    "current_decision_json": str(current_path),
    "previous_decision_json": str(previous_path),
    "decision": {
        "previous": previous_decision,
        "current": current_decision,
    },
    "counts": {
        "hold_reasons": {
            "previous": len(previous_hold_codes),
            "current": len(current_hold_codes),
            "delta": hold_increase,
            "allowed_increase": allow_hold_increase,
        },
        "blocking_reasons": {
            "previous": len(previous_blocking_codes),
            "current": len(current_blocking_codes),
            "delta": blocking_increase,
            "allowed_increase": allow_blocking_increase,
        },
    },
    "new_hold_reasons": new_hold_codes,
    "new_blocking_reasons": new_blocking_codes,
    "primary_regression_code": regressions[0]["code"] if regressions else "",
    "regression_codes": [item["code"] for item in regressions],
    "regressions": regressions,
}

json_out = out_dir / "cutover_trend_report.json"
md_out = out_dir / "cutover_trend_report.md"
json_out.write_text(json.dumps(result, indent=2), encoding="utf-8")

lines = [
    "# ONYX Listener Cutover Trend Report",
    "",
    f"- Status: `{status}`",
    f"- Current decision: `{current_path}`",
    f"- Previous decision: `{previous_path}`",
    "",
    "## Summary",
    f"- `{result['summary']}`",
    "",
    "## Decision Delta",
    f"- Decision: `{previous_decision or 'missing'} -> {current_decision or 'missing'}`",
    "",
    "## Count Deltas",
    (
        f"- Hold codes: `{len(previous_hold_codes)} -> {len(current_hold_codes)}` "
        f"(delta `{hold_increase}`, allowed `{allow_hold_increase}`)"
    ),
    (
        f"- Blocking codes: `{len(previous_blocking_codes)} -> {len(current_blocking_codes)}` "
        f"(delta `{blocking_increase}`, allowed `{allow_blocking_increase}`)"
    ),
    "",
    "## New Hold Codes",
]
if new_hold_codes:
    for item in new_hold_codes:
        lines.append(f"- {item}")
else:
    lines.append("- None")

lines.extend(["", "## New Blocking Codes"])
if new_blocking_codes:
    for item in new_blocking_codes:
        lines.append(f"- {item}")
else:
    lines.append("- None")

lines.extend(["", "## Regressions"])
if regressions:
    for item in regressions:
        if item["kind"] == "decision_regression":
            lines.append(f"- `{item['code']}`: `{item['previous']} -> {item['current']}`")
        elif item["kind"] == "decision_chain_missing_file":
            lines.append(
                f"- `{item['code']}`: `{item['decision_label']}` decision missing "
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

print(f"Cutover trend artifact: {json_out}")
print(f"Cutover trend markdown: {md_out}")
print(f"Status: {status}")

if regressions:
    for item in regressions:
        if item["kind"] == "decision_regression":
            print(f"REGRESSION: {item['code']} {item['previous']} -> {item['current']}")
        elif item["kind"] == "decision_chain_missing_file":
            print(
                f"REGRESSION: {item['code']} {item['decision_label']} missing "
                f"{item['missing_field']} at {item['missing_path']}"
            )
        else:
            print(
                f"REGRESSION: {item['code']} {item['previous']} -> {item['current']} "
                f"(delta {item['delta']}, allowed {item['allowed_increase']})"
            )
    sys.exit(1)
PY
