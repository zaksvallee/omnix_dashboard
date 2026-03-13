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

def load_json(path_str):
    candidate = str(path_str or "").strip()
    if not candidate or not Path(candidate).is_file():
        return None
    with Path(candidate).open("r", encoding="utf-8") as handle:
        return json.load(handle)

rank = {"PASS": 0, "HOLD": 1, "FAIL": 2}
current_result = str(current.get("result", "")).upper()
previous_result = str(previous.get("result", "")).upper()
current_hold_codes = [str(item) for item in (current.get("hold_codes", []) or []) if str(item)]
previous_hold_codes = [str(item) for item in (previous.get("hold_codes", []) or []) if str(item)]
current_fail_codes = [str(item) for item in (current.get("fail_codes", []) or []) if str(item)]
previous_fail_codes = [str(item) for item in (previous.get("fail_codes", []) or []) if str(item)]

regressions = []

if current_path.name != "release_gate.json":
    regressions.append({
        "code": "current_gate_name_mismatch",
        "message": "Current release gate does not use the canonical staged filename release_gate.json.",
    })

if previous_path.name != "release_gate.json":
    regressions.append({
        "code": "previous_gate_name_mismatch",
        "message": "Previous release gate does not use the canonical staged filename release_gate.json.",
    })

def signoff_consistency_regressions(gate, gate_path, label):
    items = []
    gate_dir = gate_path.parent
    signoff_report_path = str(gate.get("signoff_report_json", "")).strip()
    signoff_file_path = str(gate.get("signoff_file", "")).strip()
    reported_signoff_status = str((gate.get("statuses", {}) or {}).get("signoff_status", "")).upper()
    canonical_signoff_file = str(gate_dir / "dvr_pilot_signoff.md")
    canonical_signoff_report = str(gate_dir / "dvr_pilot_signoff.json")
    if signoff_file_path and signoff_file_path != str(gate_dir / Path(signoff_file_path).name):
        items.append({
            "code": f"{label}_signoff_file_path_mismatch",
            "message": f"{label} release gate signoff markdown is not staged under its own artifact dir.",
        })
    if signoff_report_path and signoff_report_path != str(gate_dir / Path(signoff_report_path).name):
        items.append({
            "code": f"{label}_signoff_report_path_mismatch",
            "message": f"{label} release gate signoff report is not staged under its own artifact dir.",
        })
    if signoff_file_path and signoff_file_path != canonical_signoff_file:
        items.append({
            "code": f"{label}_signoff_file_name_mismatch",
            "message": f"{label} release gate signoff markdown does not use the canonical staged filename dvr_pilot_signoff.md.",
        })
    if signoff_report_path and signoff_report_path != canonical_signoff_report:
        items.append({
            "code": f"{label}_signoff_report_name_mismatch",
            "message": f"{label} release gate signoff report does not use the canonical staged filename dvr_pilot_signoff.json.",
        })
    signoff_report = load_json(signoff_report_path)
    if signoff_report is None:
        return items
    signoff_status = str(signoff_report.get("status", "")).upper()
    signoff_failure_code = str(signoff_report.get("failure_code", "")).strip()
    if reported_signoff_status and signoff_status and reported_signoff_status != signoff_status:
        items.append({
            "code": f"{label}_signoff_status_mismatch",
            "message": f"{label} release gate signoff_status does not match the referenced signoff report status.",
        })
    if signoff_status == "PASS" and signoff_failure_code:
        items.append({
            "code": f"{label}_signoff_failure_code_present_on_pass",
            "message": f"{label} signoff report is PASS but still carries failure_code={signoff_failure_code}.",
        })
    signoff_validation_report = str(signoff_report.get("report_json", "")).strip()
    gate_validation_report = str(gate.get("validation_report_json", "")).strip()
    if signoff_validation_report and gate_validation_report and signoff_validation_report != gate_validation_report:
        items.append({
            "code": f"{label}_signoff_validation_report_mismatch",
            "message": f"{label} signoff report points at a different validation report than the release gate.",
        })
    signoff_release_gate_json = str(signoff_report.get("release_gate_json", "")).strip()
    if signoff_release_gate_json and signoff_release_gate_json != str(gate_path):
        items.append({
            "code": f"{label}_signoff_release_gate_mismatch",
            "message": f"{label} signoff report points at a different release gate artifact than the trend input.",
        })
    signoff_release_gate_result = str(signoff_report.get("release_gate_result", "")).upper()
    if signoff_release_gate_result and signoff_release_gate_result != str(gate.get("result", "")).upper():
        items.append({
            "code": f"{label}_signoff_release_gate_result_mismatch",
            "message": f"{label} signoff report release_gate_result does not match the referenced release gate result.",
        })
    return items

def readiness_consistency_regressions(gate, gate_path, label):
    items = []
    gate_dir = gate_path.parent
    gate_validation_report = str(gate.get("validation_report_json", "")).strip()
    readiness_report_path = str(gate.get("readiness_report_json", "")).strip()
    canonical_validation = str(gate_dir / "validation_report.json")
    canonical_readiness = str(gate_dir / "readiness_report.json")
    if gate_validation_report and gate_validation_report != str(gate_dir / Path(gate_validation_report).name):
        items.append({
            "code": f"{label}_validation_report_path_mismatch",
            "message": f"{label} release gate validation report is not staged under its own artifact dir.",
        })
    if gate_validation_report and gate_validation_report != canonical_validation:
        items.append({
            "code": f"{label}_validation_report_name_mismatch",
            "message": f"{label} release gate validation report does not use the canonical staged filename validation_report.json.",
        })
    if readiness_report_path and readiness_report_path != str(gate_dir / Path(readiness_report_path).name):
        items.append({
            "code": f"{label}_readiness_report_path_mismatch",
            "message": f"{label} release gate readiness report is not staged under its own artifact dir.",
        })
    if readiness_report_path and readiness_report_path != canonical_readiness:
        items.append({
            "code": f"{label}_readiness_report_name_mismatch",
            "message": f"{label} release gate readiness report does not use the canonical staged filename readiness_report.json.",
        })
    readiness_report = load_json(readiness_report_path)
    reported_status = str((gate.get("statuses", {}) or {}).get("readiness_status", "")).upper()
    reported_failure_code = str((gate.get("statuses", {}) or {}).get("readiness_failure_code", "")).strip()
    if readiness_report is None:
        return items
    readiness_status = str(readiness_report.get("status", "")).upper()
    readiness_failure_code = str(readiness_report.get("failure_code", "")).strip()
    readiness_validation_report = str(readiness_report.get("report_json", "")).strip()
    readiness_resolved_validation = str(((readiness_report.get("resolved_files", {}) or {}).get("validation_report_json", ""))).strip()
    if reported_status and readiness_status and reported_status != readiness_status:
        items.append({
            "code": f"{label}_readiness_status_mismatch",
            "message": f"{label} release gate readiness_status does not match the referenced readiness report status.",
        })
    if reported_failure_code != readiness_failure_code:
        items.append({
            "code": f"{label}_readiness_failure_code_mismatch",
            "message": f"{label} release gate readiness_failure_code does not match the referenced readiness report failure_code.",
        })
    if readiness_status == "PASS" and readiness_failure_code:
        items.append({
            "code": f"{label}_readiness_failure_code_present_on_pass",
            "message": f"{label} readiness report is PASS but still carries failure_code={readiness_failure_code}.",
        })
    if readiness_validation_report and gate_validation_report and readiness_validation_report != gate_validation_report:
        items.append({
            "code": f"{label}_readiness_validation_report_mismatch",
            "message": f"{label} readiness report points at a different validation report than the release gate.",
        })
    if readiness_resolved_validation and gate_validation_report and readiness_resolved_validation != gate_validation_report:
        items.append({
            "code": f"{label}_readiness_resolved_validation_report_mismatch",
            "message": f"{label} readiness resolved validation bundle does not match the release gate validation bundle.",
        })
    return items

regressions.extend(signoff_consistency_regressions(current, current_path, "current_gate"))
regressions.extend(signoff_consistency_regressions(previous, previous_path, "previous_gate"))
regressions.extend(readiness_consistency_regressions(current, current_path, "current_gate"))
regressions.extend(readiness_consistency_regressions(previous, previous_path, "previous_gate"))

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
