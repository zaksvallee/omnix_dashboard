#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VALIDATION_REPORT_JSON=""
READINESS_REPORT_JSON=""
SIGNOFF_FILE=""
SIGNOFF_REPORT_JSON=""
OUT_DIR=""
REQUIRE_REAL_ARTIFACTS=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_dvr_release_gate.sh [--validation-report-json <path>] [--readiness-report-json <path>] [--signoff-file <path>] [--signoff-report-json <path>] [--out-dir <path>] [--require-real-artifacts]

Purpose:
  Emit a final DVR release-gate artifact that collapses validation, readiness,
  and signoff presence into one PASS, HOLD, or FAIL report.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --validation-report-json) VALIDATION_REPORT_JSON="${2:-}"; shift 2 ;;
    --readiness-report-json) READINESS_REPORT_JSON="${2:-}"; shift 2 ;;
    --signoff-file) SIGNOFF_FILE="${2:-}"; shift 2 ;;
    --signoff-report-json) SIGNOFF_REPORT_JSON="${2:-}"; shift 2 ;;
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    --require-real-artifacts) REQUIRE_REAL_ARTIFACTS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "FAIL: Unknown argument: $1"; exit 1 ;;
  esac
done

latest_validation_report_json() {
  local base_dir="tmp/dvr_field_validation"
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
  echo "FAIL: DVR validation report not found."
  exit 1
fi

artifact_dir="$(dirname "$VALIDATION_REPORT_JSON")"
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

python3 - "$VALIDATION_REPORT_JSON" "$READINESS_REPORT_JSON" "$SIGNOFF_FILE" "$SIGNOFF_REPORT_JSON" "$OUT_DIR" "$REQUIRE_REAL_ARTIFACTS" <<'PY'
import json
import sys
from pathlib import Path

validation_path = Path(sys.argv[1])
readiness_path = Path(sys.argv[2]) if sys.argv[2] else None
signoff_path = Path(sys.argv[3]) if sys.argv[3] else None
signoff_report_path = Path(sys.argv[4]) if sys.argv[4] else None
out_dir = Path(sys.argv[5])
require_real = sys.argv[6] == "1"
release_gate_path = out_dir / "release_gate.json"

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
signoff_report = load_optional(signoff_report_path)

result = "PASS"
fail_items = []
hold_items = []
expected_validation_path = out_dir / validation_path.name
expected_readiness_path = out_dir / readiness_path.name if readiness_path else None
expected_signoff_path = out_dir / signoff_path.name if signoff_path else None
expected_signoff_report_path = out_dir / signoff_report_path.name if signoff_report_path else None
canonical_validation_path = out_dir / "validation_report.json"
canonical_readiness_path = out_dir / "readiness_report.json"
canonical_signoff_path = out_dir / "dvr_pilot_signoff.md"
canonical_signoff_report_path = out_dir / "dvr_pilot_signoff.json"
canonical_release_trend_report_path = out_dir / "release_trend_report.json"

def add_reason(items, code, message):
    items.append({"code": code, "message": message})

if str(validation.get("overall_status", "")).upper() != "PASS":
    result = "FAIL"
    add_reason(fail_items, "validation_not_pass", "Validation overall_status is not PASS.")
if validation_path != expected_validation_path:
    result = "FAIL"
    add_reason(fail_items, "validation_report_path_mismatch", "Validation report is not staged under the active release artifact dir.")
if validation_path != canonical_validation_path:
    result = "FAIL"
    add_reason(fail_items, "validation_report_name_mismatch", "Validation report does not use the canonical staged filename validation_report.json.")

is_mock = bool(validation.get("is_mock", False))
if require_real and is_mock:
    result = "FAIL"
    add_reason(fail_items, "mock_artifacts_not_allowed", "Validation bundle is marked as mock while real artifacts are required.")

if readiness is None:
    result = "HOLD" if result != "FAIL" else result
    add_reason(hold_items, "missing_readiness_report", "Readiness report is missing.")
else:
    if expected_readiness_path is not None and readiness_path != expected_readiness_path:
      result = "FAIL"
      add_reason(fail_items, "readiness_report_path_mismatch", "Readiness report is not staged under the active release artifact dir.")
    if readiness_path != canonical_readiness_path:
      result = "FAIL"
      add_reason(fail_items, "readiness_report_name_mismatch", "Readiness report does not use the canonical staged filename readiness_report.json.")
    readiness_status = str(readiness.get("status", "")).upper()
    readiness_failure_code = str(readiness.get("failure_code", "")).strip()
    readiness_validation_report = str(readiness.get("report_json", "")).strip()
    readiness_resolved_validation = str(((readiness.get("resolved_files", {}) or {}).get("validation_report_json", ""))).strip()
    if readiness_status != "PASS":
      result = "FAIL"
      code = readiness_failure_code or "readiness_not_pass"
      add_reason(fail_items, code, f"Readiness status is {readiness_status or 'unknown'}.")
    if readiness_status == "PASS" and readiness_failure_code:
      result = "FAIL"
      add_reason(fail_items, "readiness_failure_code_present_on_pass", "Readiness report is PASS but still carries a failure_code.")
    if readiness_validation_report and readiness_validation_report != str(validation_path):
      result = "FAIL"
      add_reason(fail_items, "readiness_validation_report_mismatch", "Readiness report points at a different validation bundle than the release gate.")
    if readiness_resolved_validation and readiness_resolved_validation != str(validation_path):
      result = "FAIL"
      add_reason(fail_items, "readiness_resolved_validation_report_mismatch", "Readiness resolved validation bundle does not match the release gate validation bundle.")

if signoff_report is None:
    result = "HOLD" if result != "FAIL" else result
    add_reason(hold_items, "missing_signoff_report", "Signoff report is missing.")
else:
    if expected_signoff_path is not None and signoff_path != expected_signoff_path:
        result = "FAIL"
        add_reason(fail_items, "signoff_file_path_mismatch", "Signoff markdown note is not staged under the active release artifact dir.")
    if expected_signoff_report_path is not None and signoff_report_path != expected_signoff_report_path:
        result = "FAIL"
        add_reason(fail_items, "signoff_report_path_mismatch", "Signoff report is not staged under the active release artifact dir.")
    if signoff_path != canonical_signoff_path:
        result = "FAIL"
        add_reason(fail_items, "signoff_file_name_mismatch", "Signoff markdown does not use the canonical staged filename dvr_pilot_signoff.md.")
    if signoff_report_path != canonical_signoff_report_path:
        result = "FAIL"
        add_reason(fail_items, "signoff_report_name_mismatch", "Signoff report does not use the canonical staged filename dvr_pilot_signoff.json.")
    signoff_status = str(signoff_report.get("status", "")).upper()
    signoff_failure_code = str(signoff_report.get("failure_code", "")).strip()
    signoff_validation_report = str(signoff_report.get("report_json", "")).strip()
    signoff_markdown = str(signoff_report.get("signoff_markdown", "")).strip()
    signoff_release_gate_json = str(signoff_report.get("release_gate_json", "")).strip()
    signoff_release_trend_report = str(signoff_report.get("release_trend_report_json", "")).strip()
    signoff_release_trend_status = str(signoff_report.get("release_trend_status", "")).upper()
    signoff_require_release_trend_pass = bool(signoff_report.get("require_release_trend_pass", False))
    if signoff_status != "PASS":
        result = "FAIL"
        code = signoff_failure_code or "signoff_not_pass"
        add_reason(fail_items, code, f"Signoff status is {signoff_status or 'unknown'}.")
    if signoff_status == "PASS" and signoff_failure_code:
        result = "FAIL"
        add_reason(fail_items, "signoff_failure_code_present_on_pass", "Signoff report is PASS but still carries a failure_code.")
    if signoff_validation_report and signoff_validation_report != str(validation_path):
        result = "FAIL"
        add_reason(fail_items, "signoff_validation_report_mismatch", "Signoff report points at a different validation bundle than the release gate.")
    if signoff_path and signoff_markdown and signoff_markdown != str(signoff_path):
        result = "FAIL"
        add_reason(fail_items, "signoff_markdown_mismatch", "Signoff report markdown path does not match the release gate signoff markdown.")
    if signoff_release_gate_json and signoff_release_gate_json != str(release_gate_path):
        result = "FAIL"
        add_reason(fail_items, "signoff_release_gate_mismatch", "Signoff report points at a different release gate artifact than the active release gate.")
    if signoff_release_trend_report:
        if signoff_release_trend_report != str(canonical_release_trend_report_path):
            result = "FAIL"
            add_reason(fail_items, "signoff_release_trend_report_mismatch", "Signoff report points at a different release trend artifact than the active release bundle.")
        elif not canonical_release_trend_report_path.is_file():
            result = "FAIL"
            add_reason(fail_items, "signoff_release_trend_report_not_found", "Signoff report points at a release trend artifact that was not found.")
        else:
            with canonical_release_trend_report_path.open("r", encoding="utf-8") as handle:
                release_trend_report = json.load(handle)
            actual_release_trend_current_gate = str(release_trend_report.get("current_release_gate_json", "")).strip()
            actual_release_trend_previous_gate = str(release_trend_report.get("previous_release_gate_json", "")).strip()
            actual_release_trend_status = str(release_trend_report.get("status", "")).upper()
            if actual_release_trend_current_gate and actual_release_trend_current_gate != str(release_gate_path):
                result = "FAIL"
                add_reason(fail_items, "signoff_release_trend_current_gate_mismatch", "Signoff release trend points at a different current release gate than the active release bundle.")
            if not actual_release_trend_previous_gate:
                result = "FAIL"
                add_reason(fail_items, "signoff_release_trend_previous_gate_missing", "Signoff release trend is missing its previous release gate reference.")
            elif not Path(actual_release_trend_previous_gate).is_file():
                result = "FAIL"
                add_reason(fail_items, "signoff_release_trend_previous_gate_not_found", "Signoff release trend previous gate artifact was not found.")
            elif Path(actual_release_trend_previous_gate).name != "release_gate.json":
                result = "FAIL"
                add_reason(fail_items, "signoff_release_trend_previous_gate_name_mismatch", "Signoff release trend previous gate does not use the canonical staged filename release_gate.json.")
            if signoff_release_trend_status and signoff_release_trend_status != actual_release_trend_status:
                result = "FAIL"
                add_reason(fail_items, "signoff_release_trend_status_mismatch", "Signoff report release_trend_status does not match the referenced release trend status.")
            if signoff_require_release_trend_pass and actual_release_trend_status != "PASS":
                result = "FAIL"
                code = str(release_trend_report.get("primary_regression_code", "")).strip() or "signoff_release_trend_not_pass"
                add_reason(fail_items, code, "Signoff requires a PASS release trend, but the referenced release trend is not PASS.")
    elif signoff_require_release_trend_pass:
        result = "FAIL"
        add_reason(fail_items, "signoff_release_trend_required_missing", "Signoff requires a release trend artifact, but none was recorded.")

if signoff_path and not signoff_path.is_file():
    result = "HOLD" if result != "FAIL" else result
    add_reason(hold_items, "missing_signoff_file", "Signoff markdown note is missing.")

summary = {
    "PASS": "DVR release gate passed.",
    "HOLD": "DVR release gate is holding for missing downstream artifacts.",
    "FAIL": "DVR release gate failed because one or more required upstream artifacts are not acceptable.",
}[result]

fail_codes = [item["code"] for item in fail_items]
hold_codes = [item["code"] for item in hold_items]
primary_fail_code = fail_codes[0] if fail_codes else ""
primary_hold_code = hold_codes[0] if hold_codes else ""

if signoff_report is not None:
    signoff_release_gate_result = str(signoff_report.get("release_gate_result", "")).upper()
    if signoff_release_gate_result and signoff_release_gate_result != result:
        result = "FAIL"
        add_reason(fail_items, "signoff_release_gate_result_mismatch", "Signoff report release_gate_result does not match the derived release result.")
        fail_codes = [item["code"] for item in fail_items]
        hold_codes = [item["code"] for item in hold_items]
        primary_fail_code = fail_codes[0] if fail_codes else ""
        primary_hold_code = hold_codes[0] if hold_codes else ""
        summary = {
            "PASS": "DVR release gate passed.",
            "HOLD": "DVR release gate is holding for missing downstream artifacts.",
            "FAIL": "DVR release gate failed because one or more required upstream artifacts are not acceptable.",
        }[result]

report = {
    "generated_at_utc": __import__("datetime").datetime.utcnow().replace(microsecond=0).isoformat() + "Z",
    "result": result,
    "summary": summary,
    "validation_report_json": str(validation_path),
    "readiness_report_json": str(readiness_path) if readiness_path else "",
    "signoff_file": str(signoff_path) if signoff_path else "",
    "signoff_report_json": str(signoff_report_path) if signoff_report_path else "",
    "statuses": {
        "validation_status": str(validation.get("overall_status", "")).upper(),
        "readiness_status": str((readiness or {}).get("status", "")).upper(),
        "signoff_status": str((signoff_report or {}).get("status", "")).upper(),
        "readiness_failure_code": str((readiness or {}).get("failure_code", "")).strip(),
        "signoff_failure_code": str((signoff_report or {}).get("failure_code", "")).strip(),
    },
    "is_mock": is_mock,
    "require_real_artifacts": require_real,
    "fail_reasons": [item["message"] for item in fail_items],
    "hold_reasons": [item["message"] for item in hold_items],
    "fail_codes": fail_codes,
    "hold_codes": hold_codes,
    "primary_fail_code": primary_fail_code,
    "primary_hold_code": primary_hold_code,
}

json_path = out_dir / "release_gate.json"
md_path = out_dir / "release_gate.md"
json_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
md_path.write_text(
    "\n".join(
        [
            "# ONYX DVR Release Gate",
            "",
            f"- Result: {result}",
            f"- Summary: {summary}",
            f"- Validation status: {report['statuses']['validation_status'] or 'UNKNOWN'}",
            f"- Readiness status: {report['statuses']['readiness_status'] or 'MISSING'}",
            f"- Signoff status: {report['statuses']['signoff_status'] or 'MISSING'}",
            f"- Primary fail code: {primary_fail_code or 'none'}",
            f"- Primary hold code: {primary_hold_code or 'none'}",
            "",
            "## Fail Reasons",
            *([f"- {item['message']} (`{item['code']}`)" for item in fail_items] or ["- none"]),
            "",
            "## Hold Reasons",
            *([f"- {item['message']} (`{item['code']}`)" for item in hold_items] or ["- none"]),
        ]
    ) + "\n",
    encoding="utf-8",
)

print(json_path)
print(md_path)
print(result)
PY
