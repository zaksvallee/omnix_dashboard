#!/usr/bin/env bash
set -euo pipefail

VALIDATION_REPORT_JSON=""
PARITY_REPORT_JSON=""
PARITY_TREND_REPORT_JSON=""
VALIDATION_TREND_REPORT_JSON=""
OUT_DIR=""
REQUIRE_REAL_ARTIFACTS=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_cutover_decision.sh [--validation-report-json <path>] [--parity-report-json <path>] [--parity-trend-report-json <path>] [--validation-trend-report-json <path>] [--out-dir <path>] [--require-real-artifacts]

Purpose:
  Collapse listener validation, parity, trend, and baseline posture into one
  cutover decision artifact with a GO, HOLD, or BLOCK outcome.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --validation-report-json)
      VALIDATION_REPORT_JSON="${2:-}"
      shift 2
      ;;
    --parity-report-json)
      PARITY_REPORT_JSON="${2:-}"
      shift 2
      ;;
    --parity-trend-report-json)
      PARITY_TREND_REPORT_JSON="${2:-}"
      shift 2
      ;;
    --validation-trend-report-json)
      VALIDATION_TREND_REPORT_JSON="${2:-}"
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

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$(dirname "$VALIDATION_REPORT_JSON")"
fi
mkdir -p "$OUT_DIR"

python3 - "$VALIDATION_REPORT_JSON" "$PARITY_REPORT_JSON" "$PARITY_TREND_REPORT_JSON" "$VALIDATION_TREND_REPORT_JSON" "$OUT_DIR" "$REQUIRE_REAL_ARTIFACTS" <<'PY'
import json
import sys
from pathlib import Path

validation_path = Path(sys.argv[1])
parity_path = Path(sys.argv[2]) if sys.argv[2] else None
parity_trend_path = Path(sys.argv[3]) if sys.argv[3] else None
validation_trend_path = Path(sys.argv[4]) if sys.argv[4] else None
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

parity = load_optional(parity_path)
parity_trend = load_optional(parity_trend_path)
validation_trend = load_optional(validation_trend_path)

decision = "GO"
blocking_reasons = []
hold_reasons = []

overall_status = str(validation.get("overall_status", "")).upper()
is_mock = bool(validation.get("is_mock", False))
artifact_dir = str(validation.get("artifact_dir", ""))
gates = validation.get("gates", {}) or {}
baseline_review = validation.get("baseline_review", {}) or {}
baseline_health = validation.get("baseline_health", {}) or {}

def gate(name):
    return bool(gates.get(name, False))

hard_gate_names = [
    "serial_capture_present",
    "legacy_capture_present",
    "field_notes_present",
    "read_only_wiring_documented",
    "bench_anomaly_gate_passed",
    "parity_gate_passed",
]
for gate_name in hard_gate_names:
    if not gate(gate_name):
        blocking_reasons.append(f"{gate_name} is false")

if overall_status != "PASS":
    blocking_reasons.append(f"validation overall_status is {overall_status or 'missing'}")

if require_real and (is_mock or "/mock-" in artifact_dir or artifact_dir.startswith("mock-")):
    blocking_reasons.append("validation artifact is mock while real artifacts are required")

baseline_recommendation = str(baseline_review.get("recommendation", "")).lower()
baseline_health_category = str(baseline_health.get("category", "")).lower()
baseline_health_status = str(baseline_health.get("status", "")).upper()

if baseline_recommendation == "investigate_new_frame_shape":
    blocking_reasons.append("baseline review recommends investigate_new_frame_shape")
elif baseline_recommendation and baseline_recommendation != "hold_baseline":
    hold_reasons.append(f"baseline review recommends {baseline_recommendation}")
elif not baseline_recommendation:
    hold_reasons.append("baseline review recommendation missing")

if baseline_health_status == "FAIL":
    blocking_reasons.append("baseline health status is FAIL")
elif baseline_health_category in {"stale", "missing_history", "invalid_timestamp", "missing_baseline"}:
    hold_reasons.append(f"baseline health category is {baseline_health_category}")
elif not baseline_health_category:
    hold_reasons.append("baseline health category missing")

if parity is not None:
    parity_summary = str(parity.get("summary", "")).strip()
else:
    parity_summary = ""
    hold_reasons.append("parity report artifact missing")

if parity_trend is not None:
    parity_trend_status = str(parity_trend.get("status", "")).upper()
    if parity_trend_status != "PASS":
        blocking_reasons.append(f"parity trend status is {parity_trend_status or 'missing'}")
else:
    parity_trend_status = ""
    hold_reasons.append("parity trend artifact missing")

if validation_trend is not None:
    validation_trend_status = str(validation_trend.get("status", "")).upper()
    if validation_trend_status != "PASS":
        blocking_reasons.append(f"validation trend status is {validation_trend_status or 'missing'}")
else:
    validation_trend_status = ""
    hold_reasons.append("validation trend artifact missing")

if blocking_reasons:
    decision = "BLOCK"
elif hold_reasons:
    decision = "HOLD"

result = {
    "decision": decision,
    "summary": (
        "Ready for pilot cutover." if decision == "GO"
        else "Pilot validation passed but cutover should be held pending remaining review items."
        if decision == "HOLD"
        else "Cutover is blocked by failed hard gates or regressed artifacts."
    ),
    "validation_report_json": str(validation_path),
    "parity_report_json": str(parity_path) if parity_path else "",
    "parity_trend_report_json": str(parity_trend_path) if parity_trend_path else "",
    "validation_trend_report_json": str(validation_trend_path) if validation_trend_path else "",
    "require_real_artifacts": require_real,
    "is_mock_validation_bundle": is_mock,
    "statuses": {
        "validation_overall_status": overall_status,
        "baseline_review_recommendation": baseline_recommendation,
        "baseline_health_status": baseline_health_status,
        "baseline_health_category": baseline_health_category,
        "parity_trend_status": parity_trend_status,
        "validation_trend_status": validation_trend_status,
    },
    "gates": {
        key: bool(value) for key, value in sorted(gates.items())
    },
    "blocking_reasons": blocking_reasons,
    "hold_reasons": hold_reasons,
    "parity_summary": parity_summary,
}

json_out = out_dir / "cutover_decision.json"
md_out = out_dir / "cutover_decision.md"
json_out.write_text(json.dumps(result, indent=2), encoding="utf-8")

lines = [
    "# ONYX Listener Cutover Decision",
    "",
    f"- Decision: `{decision}`",
    f"- Summary: `{result['summary']}`",
    f"- Validation report: `{validation_path}`",
]
if parity_path:
    lines.append(f"- Parity report: `{parity_path}`")
if parity_trend_path:
    lines.append(f"- Parity trend report: `{parity_trend_path}`")
if validation_trend_path:
    lines.append(f"- Validation trend report: `{validation_trend_path}`")
lines.extend([
    "",
    "## Statuses",
    f"- Validation overall status: `{overall_status or 'missing'}`",
    f"- Baseline review recommendation: `{baseline_recommendation or 'missing'}`",
    f"- Baseline health: `{baseline_health_status or 'missing'} / {baseline_health_category or 'missing'}`",
    f"- Parity trend status: `{parity_trend_status or 'missing'}`",
    f"- Validation trend status: `{validation_trend_status or 'missing'}`",
    "",
    "## Hard Gates",
])
for key, value in sorted(gates.items()):
    lines.append(f"- `{key}`: `{value}`")
lines.extend(["", "## Blocking Reasons"])
if blocking_reasons:
    for item in blocking_reasons:
        lines.append(f"- {item}")
else:
    lines.append("- None")
lines.extend(["", "## Hold Reasons"])
if hold_reasons:
    for item in hold_reasons:
        lines.append(f"- {item}")
else:
    lines.append("- None")
if parity_summary:
    lines.extend(["", "## Parity Summary", f"- `{parity_summary}`"])

md_out.write_text("\n".join(lines) + "\n", encoding="utf-8")

print(f"Cutover decision artifact: {json_out}")
print(f"Cutover decision markdown: {md_out}")
print(f"Decision: {decision}")

if decision == "BLOCK":
    sys.exit(1)
PY
