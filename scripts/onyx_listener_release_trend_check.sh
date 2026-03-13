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

result_rank = {"FAIL": 0, "HOLD": 1, "PASS": 2}

current_result = str(current.get("result", "")).upper()
previous_result = str(previous.get("result", "")).upper()

current_hold = list(current.get("hold_reasons", []) or [])
previous_hold = list(previous.get("hold_reasons", []) or [])
current_fail = list(current.get("fail_reasons", []) or [])
previous_fail = list(previous.get("fail_reasons", []) or [])

regressions = []
if result_rank.get(current_result, -1) < result_rank.get(previous_result, -1):
    regressions.append(
        {
            "kind": "result_regression",
            "previous": previous_result,
            "current": current_result,
        }
    )

hold_increase = len(current_hold) - len(previous_hold)
if hold_increase > allow_hold_increase:
    regressions.append(
        {
            "kind": "hold_reason_increase",
            "previous": len(previous_hold),
            "current": len(current_hold),
            "delta": hold_increase,
            "allowed_increase": allow_hold_increase,
        }
    )

fail_increase = len(current_fail) - len(previous_fail)
if fail_increase > allow_fail_increase:
    regressions.append(
        {
            "kind": "fail_reason_increase",
            "previous": len(previous_fail),
            "current": len(current_fail),
            "delta": fail_increase,
            "allowed_increase": allow_fail_increase,
        }
    )

new_hold_reasons = sorted(set(current_hold) - set(previous_hold))
new_fail_reasons = sorted(set(current_fail) - set(previous_fail))

status = "PASS" if not regressions else "FAIL"
result = {
    "status": status,
    "summary": (
        f"release {previous_result or 'missing'} -> {current_result or 'missing'}; "
        f"hold reasons {len(previous_hold)} -> {len(current_hold)}; "
        f"fail reasons {len(previous_fail)} -> {len(current_fail)}"
    ),
    "current_release_gate_json": str(current_path),
    "previous_release_gate_json": str(previous_path),
    "result": {
        "previous": previous_result,
        "current": current_result,
    },
    "counts": {
        "hold_reasons": {
            "previous": len(previous_hold),
            "current": len(current_hold),
            "delta": hold_increase,
            "allowed_increase": allow_hold_increase,
        },
        "fail_reasons": {
            "previous": len(previous_fail),
            "current": len(current_fail),
            "delta": fail_increase,
            "allowed_increase": allow_fail_increase,
        },
    },
    "new_hold_reasons": new_hold_reasons,
    "new_fail_reasons": new_fail_reasons,
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
        f"- Hold reasons: `{len(previous_hold)} -> {len(current_hold)}` "
        f"(delta `{hold_increase}`, allowed `{allow_hold_increase}`)"
    ),
    (
        f"- Fail reasons: `{len(previous_fail)} -> {len(current_fail)}` "
        f"(delta `{fail_increase}`, allowed `{allow_fail_increase}`)"
    ),
    "",
    "## New Hold Reasons",
]
if new_hold_reasons:
    for item in new_hold_reasons:
        lines.append(f"- {item}")
else:
    lines.append("- None")

lines.extend(["", "## New Fail Reasons"])
if new_fail_reasons:
    for item in new_fail_reasons:
        lines.append(f"- {item}")
else:
    lines.append("- None")

lines.extend(["", "## Regressions"])
if regressions:
    for item in regressions:
        if item["kind"] == "result_regression":
            lines.append(f"- `{item['kind']}`: `{item['previous']} -> {item['current']}`")
        else:
            lines.append(
                f"- `{item['kind']}`: `{item['previous']} -> {item['current']}` "
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
            print(f"REGRESSION: {item['kind']} {item['previous']} -> {item['current']}")
        else:
            print(
                f"REGRESSION: {item['kind']} {item['previous']} -> {item['current']} "
                f"(delta {item['delta']}, allowed {item['allowed_increase']})"
            )
    sys.exit(1)
PY
