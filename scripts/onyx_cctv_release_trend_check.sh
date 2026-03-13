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
  ./scripts/onyx_cctv_release_trend_check.sh [--current-release-gate-json <path>] [--previous-release-gate-json <path>] [--out-dir <path>] [--allow-hold-reason-increase-count <count>] [--allow-fail-reason-increase-count <count>]

Purpose:
  Compare one CCTV release gate against the previous run and fail when the
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
  local base_dir="tmp/cctv_field_validation"
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
  echo "FAIL: current CCTV release gate not found."
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
  echo "FAIL: previous CCTV release gate not found."
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

def add(code, message):
    regressions.append({"code": code, "message": message})

def gate_consistency_regressions(gate, gate_path, label):
    items = []
    gate_dir = gate_path.parent
    validation_report = str(gate.get("validation_report_json", "")).strip()
    signoff_report_path = str(gate.get("signoff_report_json", "")).strip()
    signoff_file_path = str(gate.get("signoff_file", "")).strip()
    integrity_json_path = str(gate.get("integrity_certificate_json", "")).strip()
    integrity_md_path = str(gate.get("integrity_certificate_markdown", "")).strip()
    statuses = gate.get("statuses", {}) or {}

    if gate_path.name != "release_gate.json":
        items.append({
            "code": f"{label}_gate_name_mismatch",
            "message": f"{label} release gate does not use the canonical staged filename release_gate.json.",
        })

    validation_data = load_json(validation_report)
    signoff_data = load_json(signoff_report_path)
    integrity_data = load_json(integrity_json_path)

    if validation_report and not Path(validation_report).is_file():
        items.append({
            "code": f"{label}_validation_report_not_found",
            "message": f"{label} release gate references a missing validation report.",
        })
    if validation_data is not None:
        actual_validation_status = str(validation_data.get("overall_status", "")).upper()
        if str(statuses.get("validation_overall_status", "")).upper() != actual_validation_status:
            items.append({
                "code": f"{label}_validation_status_mismatch",
                "message": f"{label} release gate validation status does not match the referenced validation report.",
            })

    if integrity_json_path and integrity_json_path != str(gate_dir / "integrity_certificate.json"):
        items.append({
            "code": f"{label}_integrity_certificate_path_mismatch",
            "message": f"{label} release gate integrity certificate JSON is not staged under its own artifact dir.",
        })
    if integrity_md_path and integrity_md_path != str(gate_dir / "integrity_certificate.md"):
        items.append({
            "code": f"{label}_integrity_certificate_markdown_path_mismatch",
            "message": f"{label} release gate integrity certificate markdown is not staged under its own artifact dir.",
        })
    if integrity_data is None:
        items.append({
            "code": f"{label}_integrity_certificate_not_found",
            "message": f"{label} release gate references a missing integrity certificate JSON.",
        })
    else:
        actual_integrity_status = str(integrity_data.get("status", "")).upper()
        if str(statuses.get("integrity_certificate_status", "")).upper() != actual_integrity_status:
            items.append({
                "code": f"{label}_integrity_certificate_status_mismatch",
                "message": f"{label} release gate integrity status does not match the referenced integrity certificate.",
            })
        if str(integrity_data.get("report_json", "")).strip() != validation_report:
            items.append({
                "code": f"{label}_integrity_certificate_validation_report_mismatch",
                "message": f"{label} integrity certificate points at a different validation report than the release gate.",
            })

    if signoff_report_path and signoff_report_path != str(gate_dir / Path(signoff_report_path).name):
        items.append({
            "code": f"{label}_signoff_report_path_mismatch",
            "message": f"{label} release gate signoff report is not staged under its own artifact dir.",
        })
    if signoff_file_path and signoff_file_path != str(gate_dir / Path(signoff_file_path).name):
        items.append({
            "code": f"{label}_signoff_file_path_mismatch",
            "message": f"{label} release gate signoff markdown is not staged under its own artifact dir.",
        })
    if signoff_data is None:
        if signoff_report_path:
            items.append({
                "code": f"{label}_signoff_report_not_found",
                "message": f"{label} release gate references a missing signoff report.",
            })
        return items

    actual_signoff_status = str(signoff_data.get("status", "")).upper()
    if str(statuses.get("signoff_status", "")).upper() != actual_signoff_status:
        items.append({
            "code": f"{label}_signoff_status_mismatch",
            "message": f"{label} release gate signoff status does not match the referenced signoff report.",
        })
    if actual_signoff_status == "PASS" and str(signoff_data.get("failure_code", "")).strip():
        items.append({
            "code": f"{label}_signoff_failure_code_present_on_pass",
            "message": f"{label} signoff report is PASS but still carries a failure code.",
        })
    if str(signoff_data.get("report_json", "")).strip() != validation_report:
        items.append({
            "code": f"{label}_signoff_validation_report_mismatch",
            "message": f"{label} signoff report points at a different validation report than the release gate.",
        })
    if signoff_file_path and str(signoff_data.get("signoff_file", "")).strip() != signoff_file_path:
        items.append({
            "code": f"{label}_signoff_markdown_mismatch",
            "message": f"{label} signoff report markdown path does not match the release gate signoff markdown.",
        })
    if str(signoff_data.get("integrity_certificate_json", "")).strip() != integrity_json_path:
        items.append({
            "code": f"{label}_signoff_integrity_certificate_mismatch",
            "message": f"{label} signoff report points at a different integrity certificate JSON than the release gate.",
        })
    if str(signoff_data.get("integrity_certificate_markdown", "")).strip() != integrity_md_path:
        items.append({
            "code": f"{label}_signoff_integrity_certificate_markdown_mismatch",
            "message": f"{label} signoff report points at a different integrity certificate markdown than the release gate.",
        })
    if str(signoff_data.get("integrity_certificate_status", "")).upper() != str(statuses.get("integrity_certificate_status", "")).upper():
        items.append({
            "code": f"{label}_signoff_integrity_certificate_status_mismatch",
            "message": f"{label} signoff report integrity status does not match the release gate integrity status.",
        })
    signoff_release_gate_json = str(signoff_data.get("release_gate_json", "")).strip()
    signoff_release_gate_result = str(signoff_data.get("release_gate_result", "")).upper()
    signoff_release_trend_report = str(signoff_data.get("release_trend_report_json", "")).strip()
    signoff_release_trend_status = str(signoff_data.get("release_trend_status", "")).upper()
    signoff_require_release_gate_pass = bool(signoff_data.get("require_release_gate_pass", False))
    signoff_require_release_trend_pass = bool(signoff_data.get("require_release_trend_pass", False))
    gate_result = str(gate.get("result", "")).upper()
    if signoff_release_gate_json and signoff_release_gate_json != str(gate_path):
        items.append({
            "code": f"{label}_signoff_release_gate_mismatch",
            "message": f"{label} signoff report points at a different release gate artifact than the release gate bundle.",
        })
    if signoff_release_gate_result and signoff_release_gate_result != gate_result:
        items.append({
            "code": f"{label}_signoff_release_gate_result_mismatch",
            "message": f"{label} signoff report release_gate_result does not match the release gate result.",
        })
    if signoff_require_release_gate_pass and gate_result != "PASS":
        items.append({
            "code": f"{label}_signoff_required_release_gate_not_pass",
            "message": f"{label} signoff requires a PASS release gate, but the release gate is not PASS.",
        })
    if signoff_release_trend_report:
        canonical_release_trend = str(gate_dir / "release_trend_report.json")
        if signoff_release_trend_report != canonical_release_trend:
            items.append({
                "code": f"{label}_signoff_release_trend_report_mismatch",
                "message": f"{label} signoff report points at a different release trend artifact than the release gate bundle.",
            })
        else:
            release_trend_report = load_json(signoff_release_trend_report)
            if release_trend_report is None:
                items.append({
                    "code": f"{label}_signoff_release_trend_report_not_found",
                    "message": f"{label} signoff report points at a release trend artifact that was not found.",
                })
            else:
                actual_release_trend_current_gate = str(release_trend_report.get("current_release_gate_json", "")).strip()
                actual_release_trend_status = str(release_trend_report.get("status", "")).upper()
                if actual_release_trend_current_gate and actual_release_trend_current_gate != str(gate_path):
                    items.append({
                        "code": f"{label}_signoff_release_trend_current_gate_mismatch",
                        "message": f"{label} signoff release trend points at a different current release gate than the release gate bundle.",
                    })
                if signoff_release_trend_status and signoff_release_trend_status != actual_release_trend_status:
                    items.append({
                        "code": f"{label}_signoff_release_trend_status_mismatch",
                        "message": f"{label} signoff report release_trend_status does not match the referenced release trend status.",
                    })
    elif signoff_require_release_trend_pass:
        items.append({
            "code": f"{label}_signoff_release_trend_required_missing",
            "message": f"{label} signoff requires a release trend artifact, but none was recorded.",
        })
    if signoff_require_release_trend_pass and signoff_release_trend_status and signoff_release_trend_status != "PASS":
        items.append({
            "code": f"{label}_signoff_release_trend_not_pass",
            "message": f"{label} signoff requires a PASS release trend, but the recorded release trend status is not PASS.",
        })
    return items

regressions.extend(gate_consistency_regressions(current, current_path, "current"))
regressions.extend(gate_consistency_regressions(previous, previous_path, "previous"))

if rank.get(current_result, -1) > rank.get(previous_result, -1):
    add("result_regression", f"Release result regressed from {previous_result or 'UNKNOWN'} to {current_result or 'UNKNOWN'}.")

hold_increase = len(current_hold_codes) - len(previous_hold_codes)
if hold_increase > allow_hold_increase:
    add("hold_reason_increase", f"Hold reason count increased from {len(previous_hold_codes)} to {len(current_hold_codes)}.")

fail_increase = len(current_fail_codes) - len(previous_fail_codes)
if fail_increase > allow_fail_increase:
    add("fail_reason_increase", f"Fail reason count increased from {len(previous_fail_codes)} to {len(current_fail_codes)}.")

status = "FAIL" if regressions else "PASS"
report = {
    "generated_at_utc": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "status": status,
    "summary": "CCTV release posture has not regressed." if status == "PASS" else "CCTV release posture regressed from the previous bundle.",
    "current_release_gate_json": str(current_path),
    "previous_release_gate_json": str(previous_path),
    "primary_regression_code": regressions[0]["code"] if regressions else "",
    "regression_codes": [item["code"] for item in regressions],
    "regressions": regressions,
}

json_path = out_dir / "release_trend_report.json"
md_path = out_dir / "release_trend_report.md"
json_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
lines = [
    "# ONYX CCTV Release Trend Report",
    "",
    f"- Status: `{status}`",
    f"- Summary: {report['summary']}",
    f"- Current release gate: `{current_path}`",
    f"- Previous release gate: `{previous_path}`",
    f"- Primary regression code: `{report['primary_regression_code'] or 'none'}`",
]
if regressions:
    lines.extend(["", "## Regressions"])
    lines.extend([f"- `{item['code']}`: {item['message']}" for item in regressions])
md_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

print(f"Release trend artifact: {json_path}")
print(f"Release trend markdown: {md_path}")
print(f"Status: {status}")
if status != "PASS":
    raise SystemExit(1)
PY
