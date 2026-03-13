#!/usr/bin/env bash
set -euo pipefail

VALIDATION_REPORT_JSON=""
READINESS_REPORT_JSON=""
CUTOVER_DECISION_JSON=""
CUTOVER_TREND_REPORT_JSON=""
SIGNOFF_FILE=""
OUT_DIR=""
REQUIRE_REAL_ARTIFACTS=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_release_gate.sh [--validation-report-json <path>] [--cutover-decision-json <path>] [--cutover-trend-report-json <path>] [--signoff-file <path>] [--out-dir <path>] [--require-real-artifacts]

Purpose:
  Emit a final listener release-gate artifact that collapses validation,
  cutover posture, and signoff presence into one PASS, HOLD, or FAIL report.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --validation-report-json)
      VALIDATION_REPORT_JSON="${2:-}"
      shift 2
      ;;
    --readiness-report-json)
      READINESS_REPORT_JSON="${2:-}"
      shift 2
      ;;
    --cutover-decision-json)
      CUTOVER_DECISION_JSON="${2:-}"
      shift 2
      ;;
    --cutover-trend-report-json)
      CUTOVER_TREND_REPORT_JSON="${2:-}"
      shift 2
      ;;
    --signoff-file)
      SIGNOFF_FILE="${2:-}"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --require-real-artifacts)
      REQUIRE_REAL_ARTIFACTS=1
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

if [[ -z "$VALIDATION_REPORT_JSON" ]]; then
  VALIDATION_REPORT_JSON="$(latest_validation_report_json || true)"
fi
if [[ -z "$VALIDATION_REPORT_JSON" || ! -f "$VALIDATION_REPORT_JSON" ]]; then
  echo "FAIL: validation report not found."
  exit 1
fi

artifact_dir="$(dirname "$VALIDATION_REPORT_JSON")"
if [[ -z "$CUTOVER_DECISION_JSON" && -f "$artifact_dir/cutover_decision.json" ]]; then
  CUTOVER_DECISION_JSON="$artifact_dir/cutover_decision.json"
fi
if [[ -z "$CUTOVER_TREND_REPORT_JSON" && -f "$artifact_dir/cutover_trend_report.json" ]]; then
  CUTOVER_TREND_REPORT_JSON="$artifact_dir/cutover_trend_report.json"
fi
if [[ -z "$SIGNOFF_FILE" ]]; then
  latest_signoff="$(find "$artifact_dir" -maxdepth 1 -type f -name "*.md" -print0 2>/dev/null | xargs -0 ls -1t 2>/dev/null | head -n 1 || true)"
  if [[ -n "$latest_signoff" && "$latest_signoff" != *"/validation_report.md" && "$latest_signoff" != *"/cutover_decision.md" && "$latest_signoff" != *"/cutover_trend_report.md" ]]; then
    SIGNOFF_FILE="$latest_signoff"
  fi
fi

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$artifact_dir"
fi
mkdir -p "$OUT_DIR"

python3 - "$VALIDATION_REPORT_JSON" "$CUTOVER_DECISION_JSON" "$CUTOVER_TREND_REPORT_JSON" "$SIGNOFF_FILE" "$OUT_DIR" "$REQUIRE_REAL_ARTIFACTS" <<'PY'
import json
import sys
from pathlib import Path

validation_path = Path(sys.argv[1])
cutover_path = Path(sys.argv[2]) if sys.argv[2] else None
cutover_trend_path = Path(sys.argv[3]) if sys.argv[3] else None
signoff_path = Path(sys.argv[4]) if sys.argv[4] else None
out_dir = Path(sys.argv[5])
require_real = sys.argv[6] == "1"

with validation_path.open("r", encoding="utf-8") as handle:
    validation = json.load(handle)

def load_optional(path):
    if not path:
        return None
    if not path.is_file():
        raise SystemExit(f"missing:{path}")
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)

cutover = load_optional(cutover_path)
cutover_trend = load_optional(cutover_trend_path)

result = "PASS"
fail_reasons = []
hold_reasons = []

overall_status = str(validation.get("overall_status", "")).upper()
is_mock = bool(validation.get("is_mock", False))
artifact_dir = str(validation.get("artifact_dir", ""))
baseline_review = (validation.get("baseline_review") or {}).get("recommendation", "")
baseline_health = (validation.get("baseline_health") or {}).get("category", "")

if overall_status != "PASS":
    fail_reasons.append(f"validation overall_status is {overall_status or 'missing'}")

if require_real and (is_mock or "/mock-" in artifact_dir or artifact_dir.startswith("mock-")):
    fail_reasons.append("validation artifact is mock while real artifacts are required")

cutover_decision = ""
if cutover is None:
    hold_reasons.append("cutover decision artifact missing")
else:
    cutover_decision = str(cutover.get("decision", "")).upper()
    if cutover_decision == "BLOCK":
      fail_reasons.append("cutover decision is BLOCK")
    elif cutover_decision != "GO":
      hold_reasons.append(f"cutover decision is {cutover_decision or 'missing'}")

cutover_trend_status = ""
if cutover_trend is None:
    hold_reasons.append("cutover trend artifact missing")
else:
    cutover_trend_status = str(cutover_trend.get("status", "")).upper()
    if cutover_trend_status != "PASS":
        fail_reasons.append(f"cutover trend status is {cutover_trend_status or 'missing'}")

if signoff_path is None or not signoff_path.is_file():
    hold_reasons.append("signoff file missing")

if baseline_review and baseline_review != "hold_baseline":
    hold_reasons.append(f"baseline review recommendation is {baseline_review}")
if baseline_health and baseline_health in {"stale", "missing_history", "invalid_timestamp", "missing_baseline"}:
    hold_reasons.append(f"baseline health category is {baseline_health}")

if fail_reasons:
    result = "FAIL"
elif hold_reasons:
    result = "HOLD"

payload = {
    "result": result,
    "summary": (
        "Listener release gate passed." if result == "PASS"
        else "Listener release gate is holding pending remaining prerequisites." if result == "HOLD"
        else "Listener release gate failed."
    ),
    "validation_report_json": str(validation_path),
    "cutover_decision_json": str(cutover_path) if cutover_path else "",
    "cutover_trend_report_json": str(cutover_trend_path) if cutover_trend_path else "",
    "signoff_file": str(signoff_path) if signoff_path else "",
    "statuses": {
        "validation_overall_status": overall_status,
        "cutover_decision": cutover_decision,
        "cutover_trend_status": cutover_trend_status,
        "baseline_review_recommendation": str(baseline_review),
        "baseline_health_category": str(baseline_health),
    },
    "require_real_artifacts": require_real,
    "fail_reasons": fail_reasons,
    "hold_reasons": hold_reasons,
}

json_out = out_dir / "release_gate.json"
md_out = out_dir / "release_gate.md"
json_out.write_text(json.dumps(payload, indent=2), encoding="utf-8")

lines = [
    "# ONYX Listener Release Gate",
    "",
    f"- Result: `{result}`",
    f"- Summary: `{payload['summary']}`",
    f"- Validation report: `{validation_path}`",
]
if cutover_path:
    lines.append(f"- Cutover decision: `{cutover_path}`")
if cutover_trend_path:
    lines.append(f"- Cutover trend report: `{cutover_trend_path}`")
if signoff_path:
    lines.append(f"- Signoff file: `{signoff_path}`")
lines.extend([
    "",
    "## Statuses",
    f"- Validation overall status: `{overall_status or 'missing'}`",
    f"- Cutover decision: `{cutover_decision or 'missing'}`",
    f"- Cutover trend status: `{cutover_trend_status or 'missing'}`",
    f"- Baseline review recommendation: `{baseline_review or 'missing'}`",
    f"- Baseline health category: `{baseline_health or 'missing'}`",
    "",
    "## Fail Reasons",
])
if fail_reasons:
    for item in fail_reasons:
        lines.append(f"- {item}")
else:
    lines.append("- None")
lines.extend(["", "## Hold Reasons"])
if hold_reasons:
    for item in hold_reasons:
        lines.append(f"- {item}")
else:
    lines.append("- None")

md_out.write_text("\n".join(lines) + "\n", encoding="utf-8")

print(f"Release gate artifact: {json_out}")
print(f"Release gate markdown: {md_out}")
print(f"Result: {result}")

if result == "FAIL":
    sys.exit(1)
PY
