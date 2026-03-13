#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VALIDATION_REPORT_JSON=""
SIGNOFF_FILE=""
SIGNOFF_REPORT_JSON=""
OUT_DIR=""
REQUIRE_REAL_ARTIFACTS=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_cctv_release_gate.sh [--validation-report-json <path>] [--signoff-file <path>] [--signoff-report-json <path>] [--out-dir <path>] [--require-real-artifacts]

Purpose:
  Emit a final CCTV release-gate artifact that collapses validation,
  staged integrity-certificate posture, and signoff presence into one PASS,
  HOLD, or FAIL report.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --validation-report-json) VALIDATION_REPORT_JSON="${2:-}"; shift 2 ;;
    --signoff-file) SIGNOFF_FILE="${2:-}"; shift 2 ;;
    --signoff-report-json) SIGNOFF_REPORT_JSON="${2:-}"; shift 2 ;;
    --out-dir) OUT_DIR="${2:-}"; shift 2 ;;
    --require-real-artifacts) REQUIRE_REAL_ARTIFACTS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "FAIL: Unknown argument: $1"; exit 1 ;;
  esac
done

latest_validation_report_json() {
  local base_dir="tmp/cctv_field_validation"
  if [[ ! -d "$base_dir" ]]; then
    return 1
  fi
  find "$base_dir" -type f -name "validation_report.json" -print0 2>/dev/null \
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

latest_signoff_markdown() {
  local base_dir="$1"
  if [[ ! -d "$base_dir" ]]; then
    return 1
  fi
  find "$base_dir" -maxdepth 1 -type f -name "*signoff*.md" -print0 2>/dev/null \
    | xargs -0 ls -1t 2>/dev/null \
    | head -n 1
}

if [[ -z "$VALIDATION_REPORT_JSON" ]]; then
  VALIDATION_REPORT_JSON="$(latest_validation_report_json || true)"
fi
if [[ -z "$VALIDATION_REPORT_JSON" || ! -f "$VALIDATION_REPORT_JSON" ]]; then
  echo "FAIL: CCTV validation report not found."
  exit 1
fi

artifact_dir="$(dirname "$VALIDATION_REPORT_JSON")"
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
if [[ -z "$SIGNOFF_FILE" ]]; then
  if [[ -n "$SIGNOFF_REPORT_JSON" ]]; then
    candidate_signoff_md="${SIGNOFF_REPORT_JSON%.json}.md"
    if [[ -f "$candidate_signoff_md" ]]; then
      SIGNOFF_FILE="$candidate_signoff_md"
    fi
  fi
  if [[ -z "$SIGNOFF_FILE" ]]; then
    latest_signoff_md_candidate="$(latest_signoff_markdown "$artifact_dir" || true)"
    if [[ -n "$latest_signoff_md_candidate" ]]; then
      SIGNOFF_FILE="$latest_signoff_md_candidate"
    fi
  fi
fi

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$artifact_dir"
fi
mkdir -p "$OUT_DIR"

python3 - "$VALIDATION_REPORT_JSON" "$SIGNOFF_FILE" "$SIGNOFF_REPORT_JSON" "$OUT_DIR" "$REQUIRE_REAL_ARTIFACTS" <<'PY'
import json
import sys
from pathlib import Path

validation_path = Path(sys.argv[1])
signoff_path = Path(sys.argv[2]) if sys.argv[2] else None
signoff_report_path = Path(sys.argv[3]) if sys.argv[3] else None
out_dir = Path(sys.argv[4])
require_real = sys.argv[5] == "1"
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

signoff_report = load_optional(signoff_report_path)
integrity_certificate_path = out_dir / "integrity_certificate.json"
integrity_certificate_markdown_path = out_dir / "integrity_certificate.md"
integrity_certificate = load_optional(integrity_certificate_path)

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

if integrity_certificate is None:
    result = "FAIL"
    add_reason(fail_items, "missing_integrity_certificate", "Validation bundle integrity certificate is missing.")
else:
    cert_report_json = str(integrity_certificate.get("report_json", "")).strip()
    cert_artifact_dir = str(integrity_certificate.get("artifact_dir", "")).strip()
    cert_status = str(integrity_certificate.get("status", "")).upper()
    if not integrity_certificate_markdown_path.is_file():
        result = "FAIL"
        add_reason(fail_items, "missing_integrity_certificate_markdown", "Validation bundle integrity certificate markdown is missing.")
    if cert_report_json and cert_report_json != str(validation_path):
        result = "FAIL"
        add_reason(fail_items, "integrity_certificate_report_mismatch", "Integrity certificate points at a different validation report than the release gate.")
    if cert_artifact_dir and cert_artifact_dir != str(out_dir):
        result = "FAIL"
        add_reason(fail_items, "integrity_certificate_artifact_dir_mismatch", "Integrity certificate points at a different artifact dir than the release gate.")
    if cert_status != "PASS":
        result = "FAIL"
        add_reason(fail_items, "integrity_certificate_not_pass", "Integrity certificate status is not PASS.")

if signoff_report is None:
    result = "HOLD" if result != "FAIL" else result
    add_reason(hold_items, "missing_signoff_report", "Signoff report is missing.")
else:
    signoff_status = str(signoff_report.get("status", "")).upper()
    signoff_failure_code = str(signoff_report.get("failure_code", "")).strip()
    signoff_validation_report = str(signoff_report.get("report_json", "")).strip()
    signoff_markdown = str(signoff_report.get("signoff_file", "")).strip()
    signoff_integrity_certificate_json = str(signoff_report.get("integrity_certificate_json", "")).strip()
    signoff_integrity_certificate_markdown = str(signoff_report.get("integrity_certificate_markdown", "")).strip()
    signoff_integrity_certificate_status = str(signoff_report.get("integrity_certificate_status", "")).upper()
    signoff_release_gate_json = str(signoff_report.get("release_gate_json", "")).strip()
    signoff_release_gate_result = str(signoff_report.get("release_gate_result", "")).upper()
    signoff_release_trend_report_json = str(signoff_report.get("release_trend_report_json", "")).strip()
    signoff_release_trend_status = str(signoff_report.get("release_trend_status", "")).upper()
    signoff_require_release_gate_pass = bool(signoff_report.get("require_release_gate_pass", False))
    signoff_require_release_trend_pass = bool(signoff_report.get("require_release_trend_pass", False))

    if signoff_status != "PASS":
        result = "FAIL"
        add_reason(fail_items, signoff_failure_code or "signoff_not_pass", f"Signoff status is {signoff_status or 'unknown'}.")
    if signoff_status == "PASS" and signoff_failure_code:
        result = "FAIL"
        add_reason(fail_items, "signoff_failure_code_present_on_pass", "Signoff report is PASS but still carries a failure_code.")
    if signoff_validation_report and signoff_validation_report != str(validation_path):
        result = "FAIL"
        add_reason(fail_items, "signoff_validation_report_mismatch", "Signoff report points at a different validation bundle than the release gate.")
    if signoff_path and signoff_markdown and signoff_markdown != str(signoff_path):
        result = "FAIL"
        add_reason(fail_items, "signoff_markdown_mismatch", "Signoff report markdown path does not match the provided signoff markdown.")
    if signoff_integrity_certificate_json and signoff_integrity_certificate_json != str(integrity_certificate_path):
        result = "FAIL"
        add_reason(fail_items, "signoff_integrity_certificate_mismatch", "Signoff report points at a different integrity certificate JSON than the active release bundle.")
    if signoff_integrity_certificate_markdown and signoff_integrity_certificate_markdown != str(integrity_certificate_markdown_path):
        result = "FAIL"
        add_reason(fail_items, "signoff_integrity_certificate_markdown_mismatch", "Signoff report points at a different integrity certificate markdown than the active release bundle.")
    if signoff_integrity_certificate_status and integrity_certificate is not None and signoff_integrity_certificate_status != str(integrity_certificate.get("status", "")).upper():
        result = "FAIL"
        add_reason(fail_items, "signoff_integrity_certificate_status_mismatch", "Signoff report integrity_certificate_status does not match the active integrity certificate status.")
    if signoff_release_gate_json and signoff_release_gate_json != str(release_gate_path):
        result = "FAIL"
        add_reason(fail_items, "signoff_release_gate_mismatch", "Signoff report points at a different release gate artifact than the active release bundle.")
    if signoff_release_gate_result and signoff_release_gate_result != result:
        result = "FAIL"
        add_reason(fail_items, "signoff_release_gate_result_mismatch", "Signoff report release_gate_result does not match the active release gate result.")
    if signoff_require_release_gate_pass and result != "PASS":
        result = "FAIL"
        add_reason(fail_items, "signoff_required_release_gate_not_pass", "Signoff requires a PASS release gate, but the active release gate is not PASS.")
    if signoff_release_trend_report_json:
        if signoff_release_trend_report_json != str(out_dir / "release_trend_report.json"):
            result = "FAIL"
            add_reason(fail_items, "signoff_release_trend_report_mismatch", "Signoff report points at a different release trend artifact than the active release bundle.")
        elif not (out_dir / "release_trend_report.json").is_file():
            result = "FAIL"
            add_reason(fail_items, "signoff_release_trend_report_not_found", "Signoff report points at a release trend artifact that was not found.")
        else:
            release_trend_report = load_optional(out_dir / "release_trend_report.json")
            actual_release_trend_status = str((release_trend_report or {}).get("status", "")).upper()
            actual_release_trend_current_gate = str((release_trend_report or {}).get("current_release_gate_json", "")).strip()
            if actual_release_trend_current_gate and actual_release_trend_current_gate != str(release_gate_path):
                result = "FAIL"
                add_reason(fail_items, "signoff_release_trend_current_gate_mismatch", "Signoff release trend points at a different current release gate than the active release bundle.")
            if signoff_release_trend_status and signoff_release_trend_status != actual_release_trend_status:
                result = "FAIL"
                add_reason(fail_items, "signoff_release_trend_status_mismatch", "Signoff report release_trend_status does not match the referenced release trend status.")
    elif signoff_require_release_trend_pass:
        result = "FAIL"
        add_reason(fail_items, "signoff_release_trend_required_missing", "Signoff requires a release trend artifact, but none was recorded.")
    if signoff_require_release_trend_pass and signoff_release_trend_status and signoff_release_trend_status != "PASS":
        result = "FAIL"
        add_reason(fail_items, "signoff_release_trend_not_pass", "Signoff requires a PASS release trend, but the recorded release trend status is not PASS.")

statuses = {
    "validation_overall_status": str(validation.get("overall_status", "")).upper(),
    "integrity_certificate_status": str((integrity_certificate or {}).get("status", "")).upper(),
    "signoff_status": str((signoff_report or {}).get("status", "")).upper() if signoff_report else "",
}

fail_codes = [item["code"] for item in fail_items]
hold_codes = [item["code"] for item in hold_items]
report = {
    "result": result,
    "summary": (
        "CCTV release posture is acceptable." if result == "PASS"
        else "CCTV release posture is waiting on remaining signoff prerequisites." if result == "HOLD"
        else "CCTV release posture is blocked by failed hard gates."
    ),
    "validation_report_json": str(validation_path),
    "integrity_certificate_json": str(integrity_certificate_path),
    "integrity_certificate_markdown": str(integrity_certificate_markdown_path),
    "signoff_file": str(signoff_path) if signoff_path else "",
    "signoff_report_json": str(signoff_report_path) if signoff_report_path else "",
    "require_real_artifacts": require_real,
    "statuses": statuses,
    "primary_fail_code": fail_codes[0] if fail_codes else "",
    "primary_hold_code": hold_codes[0] if hold_codes else "",
    "fail_codes": fail_codes,
    "hold_codes": hold_codes,
    "fail_reasons": [item["message"] for item in fail_items],
    "hold_reasons": [item["message"] for item in hold_items],
}

json_path = out_dir / "release_gate.json"
md_path = out_dir / "release_gate.md"
json_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
md_lines = [
    "# ONYX CCTV Release Gate",
    "",
    f"- Result: `{report['result']}`",
    f"- Summary: {report['summary']}",
    f"- Validation report: `{validation_path}`",
    f"- Integrity certificate JSON: `{integrity_certificate_path}`",
    f"- Integrity certificate markdown: `{integrity_certificate_markdown_path}`",
    f"- Signoff report JSON: `{report['signoff_report_json'] or 'missing'}`",
    f"- Signoff markdown: `{report['signoff_file'] or 'missing'}`",
    "",
    "## Statuses",
    f"- Validation overall status: `{statuses['validation_overall_status'] or 'missing'}`",
    f"- Integrity certificate status: `{statuses['integrity_certificate_status'] or 'missing'}`",
    f"- Signoff status: `{statuses['signoff_status'] or 'missing'}`",
    f"- Primary fail code: `{report['primary_fail_code'] or 'none'}`",
    f"- Primary hold code: `{report['primary_hold_code'] or 'none'}`",
]
if report["fail_reasons"]:
    md_lines.extend(["", "## Fail Reasons"])
    md_lines.extend([f"- {item}" for item in report["fail_reasons"]])
if report["hold_reasons"]:
    md_lines.extend(["", "## Hold Reasons"])
    md_lines.extend([f"- {item}" for item in report["hold_reasons"]])
md_path.write_text("\n".join(md_lines) + "\n", encoding="utf-8")

print(f"Release gate artifact: {json_path}")
print(f"Release gate markdown: {md_path}")
print(f"Result: {result}")
if result == "FAIL":
    raise SystemExit(1)
PY
