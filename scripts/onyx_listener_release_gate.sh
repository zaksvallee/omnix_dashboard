#!/usr/bin/env bash
set -euo pipefail

VALIDATION_REPORT_JSON=""
READINESS_REPORT_JSON=""
CUTOVER_DECISION_JSON=""
CUTOVER_TREND_REPORT_JSON=""
SIGNOFF_FILE=""
SIGNOFF_REPORT_JSON=""
OUT_DIR=""
REQUIRE_REAL_ARTIFACTS=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_release_gate.sh [--validation-report-json <path>] [--readiness-report-json <path>] [--cutover-decision-json <path>] [--cutover-trend-report-json <path>] [--signoff-file <path>] [--signoff-report-json <path>] [--out-dir <path>] [--require-real-artifacts]

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
    --signoff-report-json)
      SIGNOFF_REPORT_JSON="${2:-}"
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

latest_signoff_markdown() {
  local base_dir="$1"
  if [[ ! -d "$base_dir" ]]; then
    return 1
  fi
  find "$base_dir" -maxdepth 1 -type f -name "*signoff*.md" -print0 2>/dev/null \
    | xargs -0 ls -1t 2>/dev/null \
    | head -n 1
}

latest_signoff_json() {
  local base_dir="$1"
  if [[ ! -d "$base_dir" ]]; then
    return 1
  fi
  find "$base_dir" -maxdepth 1 -type f -name "*signoff*.json" -print0 2>/dev/null \
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
if [[ -z "$READINESS_REPORT_JSON" && -f "$artifact_dir/readiness_report.json" ]]; then
  READINESS_REPORT_JSON="$artifact_dir/readiness_report.json"
fi
if [[ -z "$SIGNOFF_FILE" ]]; then
  latest_signoff="$(latest_signoff_markdown "$artifact_dir" || true)"
  if [[ -n "$latest_signoff" ]]; then
    SIGNOFF_FILE="$latest_signoff"
  fi
fi
if [[ -z "$SIGNOFF_REPORT_JSON" ]]; then
  latest_signoff_json_candidate="$(latest_signoff_json "$artifact_dir" || true)"
  if [[ -n "$latest_signoff_json_candidate" ]]; then
    SIGNOFF_REPORT_JSON="$latest_signoff_json_candidate"
  elif [[ -n "$SIGNOFF_FILE" ]]; then
    candidate_signoff_json="${SIGNOFF_FILE%.md}.json"
    if [[ -f "$candidate_signoff_json" ]]; then
      SIGNOFF_REPORT_JSON="$candidate_signoff_json"
    fi
  fi
fi

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$artifact_dir"
fi
mkdir -p "$OUT_DIR"

python3 - "$VALIDATION_REPORT_JSON" "$READINESS_REPORT_JSON" "$CUTOVER_DECISION_JSON" "$CUTOVER_TREND_REPORT_JSON" "$SIGNOFF_FILE" "$SIGNOFF_REPORT_JSON" "$OUT_DIR" "$REQUIRE_REAL_ARTIFACTS" <<'PY'
import json
import sys
from pathlib import Path

validation_path = Path(sys.argv[1])
readiness_path = Path(sys.argv[2]) if sys.argv[2] else None
cutover_path = Path(sys.argv[3]) if sys.argv[3] else None
cutover_trend_path = Path(sys.argv[4]) if sys.argv[4] else None
signoff_path = Path(sys.argv[5]) if sys.argv[5] else None
signoff_report_path = Path(sys.argv[6]) if sys.argv[6] else None
out_dir = Path(sys.argv[7])
require_real = sys.argv[8] == "1"

with validation_path.open("r", encoding="utf-8") as handle:
    validation = json.load(handle)

def load_optional(path):
    if not path:
        return None
    if not path.is_file():
        raise SystemExit(f"missing:{path}")
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)

readiness = load_optional(readiness_path)
cutover = load_optional(cutover_path)
cutover_trend = load_optional(cutover_trend_path)
signoff_report = load_optional(signoff_report_path)

result = "PASS"
fail_items = []
hold_items = []

def add_reason(items, code, message):
    items.append({"code": code, "message": message})

def path_exists(raw_path):
    candidate = str(raw_path or "").strip()
    if not candidate:
        return True
    return Path(candidate).is_file()

overall_status = str(validation.get("overall_status", "")).upper()
is_mock = bool(validation.get("is_mock", False))
artifact_dir = str(validation.get("artifact_dir", ""))
baseline_review = (validation.get("baseline_review") or {}).get("recommendation", "")
baseline_health = (validation.get("baseline_health") or {}).get("category", "")

if overall_status != "PASS":
    add_reason(
        fail_items,
        "validation_not_pass",
        f"validation overall_status is {overall_status or 'missing'}",
    )

readiness_status = ""
readiness_failure_code = ""
if readiness is not None:
    readiness_status = str(readiness.get("status", "")).upper()
    readiness_failure_code = str(readiness.get("failure_code", "")).strip()
    if readiness_status != "PASS":
        add_reason(
            fail_items,
            "readiness_not_pass",
            f"readiness status is {readiness_status or 'missing'}",
        )
        if readiness_failure_code:
            add_reason(
                fail_items,
                f"readiness_failure_{readiness_failure_code}",
                f"readiness failure_code is {readiness_failure_code}",
            )
    readiness_validation_report = str(readiness.get("validation_report_json", "")).strip()
    if readiness_validation_report and not path_exists(readiness_validation_report):
        add_reason(
            fail_items,
            "readiness_missing_validation_report",
            "readiness report references a missing validation report",
        )

if require_real and (is_mock or "/mock-" in artifact_dir or artifact_dir.startswith("mock-")):
    add_reason(
        fail_items,
        "mock_artifacts_not_allowed",
        "validation artifact is mock while real artifacts are required",
    )

cutover_decision = ""
if cutover is None:
    add_reason(hold_items, "missing_cutover_decision", "cutover decision artifact missing")
else:
    cutover_decision = str(cutover.get("decision", "")).upper()
    cutover_validation_report = str(cutover.get("validation_report_json", "")).strip()
    cutover_parity_report = str(cutover.get("parity_report_json", "")).strip()
    cutover_parity_trend = str(cutover.get("parity_trend_report_json", "")).strip()
    cutover_validation_trend = str(cutover.get("validation_trend_report_json", "")).strip()
    if cutover_validation_report and not path_exists(cutover_validation_report):
        add_reason(
            fail_items,
            "cutover_missing_validation_report",
            "cutover decision references a missing validation report",
        )
    if cutover_parity_report and not path_exists(cutover_parity_report):
        add_reason(
            fail_items,
            "cutover_missing_parity_report",
            "cutover decision references a missing parity report",
        )
    if cutover_parity_trend and not path_exists(cutover_parity_trend):
        add_reason(
            fail_items,
            "cutover_missing_parity_trend_report",
            "cutover decision references a missing parity trend report",
        )
    if cutover_validation_trend and not path_exists(cutover_validation_trend):
        add_reason(
            fail_items,
            "cutover_missing_validation_trend_report",
            "cutover decision references a missing validation trend report",
        )
    if cutover_decision == "BLOCK":
      add_reason(fail_items, "cutover_blocked", "cutover decision is BLOCK")
    elif cutover_decision != "GO":
      add_reason(
          hold_items,
          "cutover_not_go",
          f"cutover decision is {cutover_decision or 'missing'}",
      )

cutover_trend_status = ""
if cutover_trend is None:
    add_reason(hold_items, "missing_cutover_trend", "cutover trend artifact missing")
else:
    cutover_trend_status = str(cutover_trend.get("status", "")).upper()
    current_cutover_decision = str(cutover_trend.get("current_decision_json", "")).strip()
    previous_cutover_decision = str(cutover_trend.get("previous_decision_json", "")).strip()
    if current_cutover_decision and not path_exists(current_cutover_decision):
        add_reason(
            fail_items,
            "cutover_trend_missing_current_decision",
            "cutover trend references a missing current cutover decision",
        )
    if previous_cutover_decision and not path_exists(previous_cutover_decision):
        add_reason(
            fail_items,
            "cutover_trend_missing_previous_decision",
            "cutover trend references a missing previous cutover decision",
        )
    if cutover_trend_status != "PASS":
        add_reason(
            fail_items,
            "cutover_trend_not_pass",
            f"cutover trend status is {cutover_trend_status or 'missing'}",
        )

signoff_status = ""
if signoff_report is not None:
    signoff_status = str(signoff_report.get("status", "")).upper()
    signoff_parity_report = str(signoff_report.get("report_json", "")).strip()
    signoff_trend_report = str(signoff_report.get("trend_report_json", "")).strip()
    signoff_validation_report = str(signoff_report.get("validation_report_json", "")).strip()
    signoff_validation_trend = str(signoff_report.get("validation_trend_report_json", "")).strip()
    signoff_cutover_decision = str(signoff_report.get("cutover_decision_json", "")).strip()
    signoff_cutover_trend = str(signoff_report.get("cutover_trend_report_json", "")).strip()
    if signoff_parity_report and not path_exists(signoff_parity_report):
        add_reason(
            fail_items,
            "signoff_missing_parity_report",
            "signoff report references a missing parity report",
        )
    if signoff_trend_report and not path_exists(signoff_trend_report):
        add_reason(
            fail_items,
            "signoff_missing_trend_report",
            "signoff report references a missing trend report",
        )
    if signoff_validation_report and not path_exists(signoff_validation_report):
        add_reason(
            fail_items,
            "signoff_missing_validation_report",
            "signoff report references a missing validation report",
        )
    if signoff_validation_trend and not path_exists(signoff_validation_trend):
        add_reason(
            fail_items,
            "signoff_missing_validation_trend_report",
            "signoff report references a missing validation trend report",
        )
    if signoff_cutover_decision and not path_exists(signoff_cutover_decision):
        add_reason(
            fail_items,
            "signoff_missing_cutover_decision_report",
            "signoff report references a missing cutover decision report",
        )
    if signoff_cutover_trend and not path_exists(signoff_cutover_trend):
        add_reason(
            fail_items,
            "signoff_missing_cutover_trend_report",
            "signoff report references a missing cutover trend report",
        )
    if signoff_status != "PASS":
        add_reason(
            fail_items,
            "signoff_not_pass",
            f"signoff status is {signoff_status or 'missing'}",
        )
elif signoff_path is None or not signoff_path.is_file():
    add_reason(hold_items, "missing_signoff_file", "signoff file missing")
elif signoff_path is not None and signoff_path.is_file():
    add_reason(
        hold_items,
        "missing_signoff_report",
        "signoff report artifact missing",
    )

if baseline_review and baseline_review != "hold_baseline":
    add_reason(
        hold_items,
        f"baseline_review_{baseline_review}",
        f"baseline review recommendation is {baseline_review}",
    )
if baseline_health and baseline_health in {"stale", "missing_history", "invalid_timestamp", "missing_baseline"}:
    add_reason(
        hold_items,
        f"baseline_health_{baseline_health}",
        f"baseline health category is {baseline_health}",
    )

fail_reasons = [item["message"] for item in fail_items]
hold_reasons = [item["message"] for item in hold_items]
fail_codes = [item["code"] for item in fail_items]
hold_codes = [item["code"] for item in hold_items]

if fail_items:
    result = "FAIL"
elif hold_items:
    result = "HOLD"

payload = {
    "result": result,
    "summary": (
        "Listener release gate passed." if result == "PASS"
        else "Listener release gate is holding pending remaining prerequisites." if result == "HOLD"
        else "Listener release gate failed."
    ),
    "validation_report_json": str(validation_path),
    "readiness_report_json": str(readiness_path) if readiness_path else "",
    "cutover_decision_json": str(cutover_path) if cutover_path else "",
    "cutover_trend_report_json": str(cutover_trend_path) if cutover_trend_path else "",
    "signoff_file": str(signoff_path) if signoff_path else "",
    "signoff_report_json": str(signoff_report_path) if signoff_report_path else "",
    "statuses": {
        "validation_overall_status": overall_status,
        "readiness_status": readiness_status,
        "readiness_failure_code": readiness_failure_code,
        "cutover_decision": cutover_decision,
        "cutover_trend_status": cutover_trend_status,
        "signoff_status": signoff_status,
        "baseline_review_recommendation": str(baseline_review),
        "baseline_health_category": str(baseline_health),
    },
    "primary_fail_code": fail_codes[0] if fail_codes else "",
    "primary_hold_code": hold_codes[0] if hold_codes else "",
    "fail_codes": fail_codes,
    "hold_codes": hold_codes,
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
if readiness_path:
    lines.append(f"- Readiness report: `{readiness_path}`")
if cutover_path:
    lines.append(f"- Cutover decision: `{cutover_path}`")
if cutover_trend_path:
    lines.append(f"- Cutover trend report: `{cutover_trend_path}`")
if signoff_path:
    lines.append(f"- Signoff file: `{signoff_path}`")
if signoff_report_path:
    lines.append(f"- Signoff report: `{signoff_report_path}`")
lines.extend([
    "",
    "## Statuses",
    f"- Validation overall status: `{overall_status or 'missing'}`",
    f"- Readiness status: `{readiness_status or 'missing'}`",
    f"- Readiness failure code: `{readiness_failure_code or 'missing'}`",
    f"- Cutover decision: `{cutover_decision or 'missing'}`",
    f"- Cutover trend status: `{cutover_trend_status or 'missing'}`",
    f"- Signoff status: `{signoff_status or 'missing'}`",
    f"- Baseline review recommendation: `{baseline_review or 'missing'}`",
    f"- Baseline health category: `{baseline_health or 'missing'}`",
    f"- Primary fail code: `{payload['primary_fail_code'] or 'missing'}`",
    f"- Primary hold code: `{payload['primary_hold_code'] or 'missing'}`",
    "",
    "## Fail Reasons",
])
if fail_items:
    for item in fail_items:
        lines.append(f"- `{item['code']}`: {item['message']}")
else:
    lines.append("- None")
lines.extend(["", "## Hold Reasons"])
if hold_items:
    for item in hold_items:
        lines.append(f"- `{item['code']}`: {item['message']}")
else:
    lines.append("- None")

md_out.write_text("\n".join(lines) + "\n", encoding="utf-8")

print(f"Release gate artifact: {json_out}")
print(f"Release gate markdown: {md_out}")
print(f"Result: {result}")

if result == "FAIL":
    sys.exit(1)
PY
