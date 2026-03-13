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

def add_reason(items, code, message):
    items.append({"code": code, "message": message})

if str(validation.get("overall_status", "")).upper() != "PASS":
    result = "FAIL"
    add_reason(fail_items, "validation_not_pass", "Validation overall_status is not PASS.")

is_mock = bool(validation.get("is_mock", False))
if require_real and is_mock:
    result = "FAIL"
    add_reason(fail_items, "mock_artifacts_not_allowed", "Validation bundle is marked as mock while real artifacts are required.")

if readiness is None:
    result = "HOLD" if result != "FAIL" else result
    add_reason(hold_items, "missing_readiness_report", "Readiness report is missing.")
else:
    readiness_status = str(readiness.get("status", "")).upper()
    if readiness_status != "PASS":
      result = "FAIL"
      code = str(readiness.get("failure_code", "")).strip() or "readiness_not_pass"
      add_reason(fail_items, code, f"Readiness status is {readiness_status or 'unknown'}.")

if signoff_report is None:
    result = "HOLD" if result != "FAIL" else result
    add_reason(hold_items, "missing_signoff_report", "Signoff report is missing.")
else:
    signoff_status = str(signoff_report.get("status", "")).upper()
    if signoff_status != "PASS":
        result = "FAIL"
        code = str(signoff_report.get("failure_code", "")).strip() or "signoff_not_pass"
        add_reason(fail_items, code, f"Signoff status is {signoff_status or 'unknown'}.")

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
