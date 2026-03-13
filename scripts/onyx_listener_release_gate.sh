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

def load_json(path_str):
    candidate = str(path_str or "").strip()
    if not candidate or not Path(candidate).is_file():
        return None
    with Path(candidate).open("r", encoding="utf-8") as handle:
        return json.load(handle)

def validation_report_consistency_issues(report):
    issues = []
    files = report.get("files", {}) or {}
    gates = report.get("gates", {}) or {}
    statuses = report.get("statuses", {}) or {}
    baseline_review = report.get("baseline_review", {}) or {}
    baseline_health = report.get("baseline_health", {}) or {}

    staged_review = load_json(files.get("baseline_review_json", ""))
    if staged_review is not None:
        for key in ("status", "recommendation", "summary", "bench_anomaly_status"):
            expected = str(staged_review.get(key, "")).strip()
            actual = str(baseline_review.get(key, "")).strip()
            if actual != expected:
                issues.append((f"validation_baseline_review_{key}_mismatch", f"validation baseline review {key} does not match staged baseline review JSON"))

    staged_health = load_json(files.get("baseline_health_json", ""))
    if staged_health is not None:
        for key in ("status", "category", "summary"):
            expected = str(staged_health.get(key, "")).strip()
            actual = str(baseline_health.get(key, "")).strip()
            if actual != expected:
                issues.append((f"validation_baseline_health_{key}_mismatch", f"validation baseline health {key} does not match staged baseline health JSON"))
        if baseline_health.get("age_days") != staged_health.get("age_days"):
            issues.append(("validation_baseline_health_age_days_mismatch", "validation baseline health age_days does not match staged baseline health JSON"))

    for gate_key, status_key in (
        ("serial_capture_present", "serial_capture"),
        ("legacy_capture_present", "legacy_capture"),
        ("field_notes_present", "field_notes"),
        ("read_only_wiring_documented", "read_only_wiring"),
        ("bench_anomaly_gate_passed", "bench_anomaly_gate"),
        ("parity_gate_passed", "parity_gate"),
        ("trend_gate_passed", "trend_gate"),
    ):
        gate_value = bool(gates.get(gate_key, False))
        status_value = str(statuses.get(status_key, "")).upper()
        if gate_value != (status_value == "PASS"):
            issues.append((f"validation_{gate_key}_status_mismatch", f"validation gate {gate_key} does not match status field {status_key}"))

    failure_codes = [str(item) for item in (report.get("failure_codes", []) or [])]
    warning_codes = [str(item) for item in (report.get("warning_codes", []) or [])]
    primary_failure_code = str(report.get("primary_failure_code", "")).strip()
    primary_warning_code = str(report.get("primary_warning_code", "")).strip()
    expected_primary_failure = failure_codes[0] if failure_codes else ""
    expected_primary_warning = warning_codes[0] if warning_codes else ""
    if primary_failure_code != expected_primary_failure:
        issues.append(("validation_primary_failure_code_mismatch", "validation primary_failure_code does not match failure_codes"))
    if primary_warning_code != expected_primary_warning:
        issues.append(("validation_primary_warning_code_mismatch", "validation primary_warning_code does not match warning_codes"))

    pilot_gate = load_json(files.get("pilot_gate_report_json", ""))
    if pilot_gate is not None:
        pilot_files = pilot_gate.get("files", {}) or {}
        pilot_statuses = pilot_gate.get("statuses", {}) or {}
        compare_previous = bool(pilot_gate.get("compare_previous", False))

        required_files = [
            "serial_parsed_json",
            "parity_report_json",
            "parity_report_markdown",
            "parity_readiness_report_json",
            "parity_readiness_report_markdown",
        ]
        if compare_previous:
            required_files.extend(["trend_report_json", "trend_report_markdown"])
        for file_key in required_files:
            file_path = str(pilot_files.get(file_key, "")).strip()
            if not file_path:
                issues.append((f"validation_pilot_gate_missing_{file_key}", f"validation pilot gate is missing {file_key}"))
            elif not path_exists(file_path):
                issues.append((f"validation_pilot_gate_missing_{file_key}", f"validation pilot gate references a missing {file_key}"))

        serial_data = load_json(pilot_files.get("serial_parsed_json", ""))
        if serial_data is not None:
            anomaly_gate = serial_data.get("anomaly_gate", {}) or {}
            expected_status = str(anomaly_gate.get("status", "")).upper()
            expected_code = str((((anomaly_gate.get("failures") or [{}])[0]).get("type", "") or "")).strip()
            actual_status = str(pilot_statuses.get("bench_anomaly_status", "")).upper()
            actual_code = str(pilot_statuses.get("bench_primary_failure_code", "")).strip()
            if actual_status != expected_status:
                issues.append(("validation_pilot_gate_bench_anomaly_status_mismatch", "validation pilot gate bench anomaly status does not match serial bench output"))
            if actual_code != expected_code:
                issues.append(("validation_pilot_gate_bench_primary_failure_code_mismatch", "validation pilot gate bench primary failure code does not match serial bench output"))

        parity_data = load_json(pilot_files.get("parity_report_json", ""))
        if parity_data is not None:
            expected_status = str(parity_data.get("status", "")).upper()
            expected_code = str(parity_data.get("primary_issue_code", "")).strip()
            actual_status = str(pilot_statuses.get("parity_status", "")).upper()
            actual_code = str(pilot_statuses.get("parity_primary_issue_code", "")).strip()
            if actual_status != expected_status:
                issues.append(("validation_pilot_gate_parity_status_mismatch", "validation pilot gate parity status does not match parity report"))
            if actual_code != expected_code:
                issues.append(("validation_pilot_gate_parity_primary_issue_code_mismatch", "validation pilot gate parity primary issue code does not match parity report"))

        readiness_data = load_json(pilot_files.get("parity_readiness_report_json", ""))
        if readiness_data is not None:
            expected_status = str(readiness_data.get("status", "")).upper()
            expected_code = str(readiness_data.get("failure_code", "")).strip()
            actual_status = str(pilot_statuses.get("parity_readiness_status", "")).upper()
            actual_code = str(pilot_statuses.get("parity_readiness_failure_code", "")).strip()
            if actual_status != expected_status:
                issues.append(("validation_pilot_gate_parity_readiness_status_mismatch", "validation pilot gate parity readiness status does not match parity readiness report"))
            if actual_code != expected_code:
                issues.append(("validation_pilot_gate_parity_readiness_failure_code_mismatch", "validation pilot gate parity readiness failure code does not match parity readiness report"))

        trend_data = load_json(pilot_files.get("trend_report_json", ""))
        if compare_previous and trend_data is not None:
            expected_status = str(trend_data.get("status", "")).upper()
            expected_code = str(trend_data.get("primary_regression_code", "")).strip()
            actual_status = str(pilot_statuses.get("parity_trend_status", "")).upper()
            actual_code = str(pilot_statuses.get("parity_trend_primary_regression_code", "")).strip()
            if actual_status != expected_status:
                issues.append(("validation_pilot_gate_parity_trend_status_mismatch", "validation pilot gate parity trend status does not match parity trend report"))
            if actual_code != expected_code:
                issues.append(("validation_pilot_gate_parity_trend_primary_regression_code_mismatch", "validation pilot gate parity trend primary regression code does not match parity trend report"))
    return issues

def readiness_report_consistency_issues(report):
    issues = []
    statuses = report.get("statuses", {}) or {}
    requirements = report.get("requirements", {}) or {}
    resolved_files = report.get("resolved_files", {}) or {}

    validation_report = str(report.get("validation_report_json", "")).strip()
    validation_data = load_json(validation_report)
    validation_trend = str(resolved_files.get("validation_trend_report_json", "")).strip()
    cutover_decision = str(resolved_files.get("cutover_decision_json", "")).strip()
    cutover_trend = str(resolved_files.get("cutover_trend_report_json", "")).strip()

    validation_trend_data = load_json(validation_trend)
    cutover_data = load_json(cutover_decision)
    cutover_trend_data = load_json(cutover_trend)

    actual_validation_status = str((validation_data or {}).get("overall_status", "")).upper()
    reported_validation_status = str(statuses.get("validation_overall_status", "")).upper()
    if validation_data is not None and reported_validation_status != actual_validation_status:
        issues.append(("readiness_validation_status_mismatch", f"readiness report validation status does not match referenced validation report ({reported_validation_status or 'missing'} vs {actual_validation_status or 'missing'})"))

    require_validation_trend_pass = bool(requirements.get("require_validation_trend_pass", False))
    require_cutover_go = bool(requirements.get("require_cutover_go", False))
    require_cutover_trend_pass = bool(requirements.get("require_cutover_trend_pass", False))

    actual_validation_trend_status = str((validation_trend_data or {}).get("status", "")).upper()
    actual_cutover_decision = str((cutover_data or {}).get("decision", "")).upper()
    actual_cutover_trend_status = str((cutover_trend_data or {}).get("status", "")).upper()

    if require_validation_trend_pass and actual_validation_trend_status != "PASS":
        issues.append(("readiness_required_validation_trend_not_pass", f"readiness report requires validation trend PASS but referenced validation trend status is {actual_validation_trend_status or 'missing'}"))
    if require_cutover_go and actual_cutover_decision != "GO":
        issues.append(("readiness_required_cutover_not_go", f"readiness report requires cutover GO but referenced cutover decision is {actual_cutover_decision or 'missing'}"))
    if require_cutover_trend_pass and actual_cutover_trend_status != "PASS":
        issues.append(("readiness_required_cutover_trend_not_pass", f"readiness report requires cutover trend PASS but referenced cutover trend status is {actual_cutover_trend_status or 'missing'}"))
    return issues

def cutover_decision_consistency_issues(report):
    issues = []
    statuses = report.get("statuses", {}) or {}
    gates = report.get("gates", {}) or {}
    blocking_codes = [str(item) for item in (report.get("blocking_codes", []) or [])]
    hold_codes = [str(item) for item in (report.get("hold_codes", []) or [])]
    primary_blocking_code = str(report.get("primary_blocking_code", "")).strip()
    primary_hold_code = str(report.get("primary_hold_code", "")).strip()
    decision = str(report.get("decision", "")).upper()

    validation_report = str(report.get("validation_report_json", "")).strip()
    parity_report = str(report.get("parity_report_json", "")).strip()
    parity_trend = str(report.get("parity_trend_report_json", "")).strip()
    validation_trend = str(report.get("validation_trend_report_json", "")).strip()

    validation_data = load_json(validation_report)
    parity_data = load_json(parity_report)
    parity_trend_data = load_json(parity_trend)
    validation_trend_data = load_json(validation_trend)

    if validation_data is not None:
        actual_validation_status = str(validation_data.get("overall_status", "")).upper()
        reported_validation_status = str(statuses.get("validation_overall_status", "")).upper()
        if reported_validation_status != actual_validation_status:
            issues.append(("cutover_validation_status_mismatch", f"cutover decision validation status does not match referenced validation report ({reported_validation_status or 'missing'} vs {actual_validation_status or 'missing'})"))

        actual_review = str(((validation_data.get("baseline_review") or {}).get("recommendation", ""))).lower()
        reported_review = str(statuses.get("baseline_review_recommendation", "")).lower()
        if reported_review != actual_review:
            issues.append(("cutover_baseline_review_recommendation_mismatch", f"cutover decision baseline review recommendation does not match referenced validation report ({reported_review or 'missing'} vs {actual_review or 'missing'})"))

        actual_health_status = str(((validation_data.get("baseline_health") or {}).get("status", ""))).upper()
        reported_health_status = str(statuses.get("baseline_health_status", "")).upper()
        if reported_health_status != actual_health_status:
            issues.append(("cutover_baseline_health_status_mismatch", f"cutover decision baseline health status does not match referenced validation report ({reported_health_status or 'missing'} vs {actual_health_status or 'missing'})"))

        actual_health_category = str(((validation_data.get("baseline_health") or {}).get("category", ""))).lower()
        reported_health_category = str(statuses.get("baseline_health_category", "")).lower()
        if reported_health_category != actual_health_category:
            issues.append(("cutover_baseline_health_category_mismatch", f"cutover decision baseline health category does not match referenced validation report ({reported_health_category or 'missing'} vs {actual_health_category or 'missing'})"))

        actual_gates = validation_data.get("gates", {}) or {}
        for gate_key in sorted(set(actual_gates.keys()) | set(gates.keys())):
            actual_gate = bool(actual_gates.get(gate_key, False))
            reported_gate = bool(gates.get(gate_key, False))
            if reported_gate != actual_gate:
                issues.append((f"cutover_gate_{gate_key}_mismatch", f"cutover decision gate {gate_key} does not match referenced validation report ({str(reported_gate).lower()} vs {str(actual_gate).lower()})"))

    if parity_data is not None:
        actual_parity_summary = str(parity_data.get("summary", "")).strip()
        reported_parity_summary = str(report.get("parity_summary", "")).strip()
        if reported_parity_summary != actual_parity_summary:
            issues.append(("cutover_parity_summary_mismatch", "cutover decision parity summary does not match referenced parity report"))

    if parity_trend_data is not None:
        actual_parity_trend_status = str(parity_trend_data.get("status", "")).upper()
        reported_parity_trend_status = str(statuses.get("parity_trend_status", "")).upper()
        if reported_parity_trend_status != actual_parity_trend_status:
            issues.append(("cutover_parity_trend_status_mismatch", f"cutover decision parity trend status does not match referenced parity trend report ({reported_parity_trend_status or 'missing'} vs {actual_parity_trend_status or 'missing'})"))

    if validation_trend_data is not None:
        actual_validation_trend_status = str(validation_trend_data.get("status", "")).upper()
        reported_validation_trend_status = str(statuses.get("validation_trend_status", "")).upper()
        if reported_validation_trend_status != actual_validation_trend_status:
            issues.append(("cutover_validation_trend_status_mismatch", f"cutover decision validation trend status does not match referenced validation trend report ({reported_validation_trend_status or 'missing'} vs {actual_validation_trend_status or 'missing'})"))

    expected_primary_blocking = blocking_codes[0] if blocking_codes else ""
    expected_primary_hold = hold_codes[0] if hold_codes else ""
    if primary_blocking_code != expected_primary_blocking:
        issues.append(("cutover_primary_blocking_code_mismatch", "cutover decision primary_blocking_code does not match blocking_codes"))
    if primary_hold_code != expected_primary_hold:
        issues.append(("cutover_primary_hold_code_mismatch", "cutover decision primary_hold_code does not match hold_codes"))

    if decision == "BLOCK" and not blocking_codes:
        issues.append(("cutover_decision_block_without_blocking_codes", "cutover decision is BLOCK but blocking_codes is empty"))
    if decision == "HOLD" and (blocking_codes or not hold_codes):
        issues.append(("cutover_decision_hold_code_mismatch", "cutover decision is HOLD but reason codes do not reflect a hold-only state"))
    if decision == "GO" and (blocking_codes or hold_codes):
        issues.append(("cutover_decision_go_with_reason_codes", "cutover decision is GO but blocking_codes or hold_codes are still present"))
    return issues

def cutover_decision_chain_issues(path_str, label):
    issues = []
    if not path_str:
        return issues
    report_path = Path(path_str)
    if not report_path.is_file():
        issues.append((f"cutover_trend_missing_{label}_decision", f"cutover trend references a missing {label} cutover decision"))
        return issues
    with report_path.open("r", encoding="utf-8") as handle:
        report = json.load(handle)
    validation_report = str(report.get("validation_report_json", "")).strip()
    parity_report = str(report.get("parity_report_json", "")).strip()
    parity_trend = str(report.get("parity_trend_report_json", "")).strip()
    validation_trend = str(report.get("validation_trend_report_json", "")).strip()
    if validation_report and not path_exists(validation_report):
        issues.append((f"cutover_trend_{label}_missing_validation_report", f"cutover trend {label} decision references a missing validation report"))
    if parity_report and not path_exists(parity_report):
        issues.append((f"cutover_trend_{label}_missing_parity_report", f"cutover trend {label} decision references a missing parity report"))
    if parity_trend and not path_exists(parity_trend):
        issues.append((f"cutover_trend_{label}_missing_parity_trend_report", f"cutover trend {label} decision references a missing parity trend report"))
    if validation_trend and not path_exists(validation_trend):
        issues.append((f"cutover_trend_{label}_missing_validation_trend_report", f"cutover trend {label} decision references a missing validation trend report"))
    for code, message in cutover_decision_consistency_issues(report):
        nested_code = code[8:] if code.startswith("cutover_") else code
        nested_message = f"cutover trend {label} decision {message}" if message else f"cutover trend {label} decision consistency mismatch"
        issues.append((f"cutover_trend_{label}_{nested_code}", nested_message))
    return issues

def signoff_report_consistency_issues(report):
    issues = []
    signoff_status = str(report.get("status", "")).upper()
    signoff_failure_code = str(report.get("failure_code", "")).strip()
    statuses = report.get("statuses", {}) or {}
    requirements = report.get("requirements", {}) or {}
    readiness_report = str(report.get("readiness_report_json", "")).strip()
    trend_report = str(report.get("trend_report_json", "")).strip()
    validation_report = str(report.get("validation_report_json", "")).strip()
    validation_trend = str(report.get("validation_trend_report_json", "")).strip()
    cutover_decision = str(report.get("cutover_decision_json", "")).strip()
    cutover_trend = str(report.get("cutover_trend_report_json", "")).strip()

    readiness_data = load_json(readiness_report)
    trend_data = load_json(trend_report)
    validation_data = load_json(validation_report)
    validation_trend_data = load_json(validation_trend)
    cutover_data = load_json(cutover_decision)
    cutover_trend_data = load_json(cutover_trend)

    actual_readiness_status = str((readiness_data or {}).get("status", "")).upper()
    actual_readiness_failure_code = str((readiness_data or {}).get("failure_code", "")).strip()
    actual_trend_status = str((trend_data or {}).get("status", "")).upper()
    actual_validation_trend_status = str((validation_trend_data or {}).get("status", "")).upper()
    actual_cutover_decision = str((cutover_data or {}).get("decision", "")).upper()
    actual_cutover_trend_status = str((cutover_trend_data or {}).get("status", "")).upper()

    reported_readiness_status = str(statuses.get("readiness_status", "")).upper()
    reported_readiness_failure_code = str(statuses.get("readiness_failure_code", "")).strip()
    reported_trend_status = str(statuses.get("trend_status", "")).upper()
    reported_validation_trend_status = str(statuses.get("validation_trend_status", "")).upper()
    reported_cutover_decision = str(statuses.get("cutover_decision", "")).upper()
    reported_cutover_trend_status = str(statuses.get("cutover_trend_status", "")).upper()

    if signoff_status not in {"PASS", "FAIL"}:
        issues.append(("signoff_invalid_status", f"signoff report status is {signoff_status or 'missing'}"))
    if signoff_status == "PASS" and signoff_failure_code:
        issues.append(("signoff_failure_code_present_on_pass", f"signoff report status is PASS but failure_code is {signoff_failure_code}"))
    if signoff_status == "FAIL" and not signoff_failure_code:
        issues.append(("signoff_missing_failure_code", "signoff report status is FAIL but failure_code is missing"))

    if readiness_data is not None and reported_readiness_status != actual_readiness_status:
        issues.append(("signoff_readiness_status_mismatch", f"signoff report readiness status does not match referenced readiness report ({reported_readiness_status or 'missing'} vs {actual_readiness_status or 'missing'})"))
    if readiness_data is not None and reported_readiness_failure_code != actual_readiness_failure_code:
        issues.append(("signoff_readiness_failure_code_mismatch", f"signoff report readiness failure code does not match referenced readiness report ({reported_readiness_failure_code or 'missing'} vs {actual_readiness_failure_code or 'missing'})"))
    if trend_data is not None and reported_trend_status != actual_trend_status:
        issues.append(("signoff_trend_status_mismatch", f"signoff report trend status does not match referenced trend report ({reported_trend_status or 'missing'} vs {actual_trend_status or 'missing'})"))
    if validation_trend_data is not None and reported_validation_trend_status != actual_validation_trend_status:
        issues.append(("signoff_validation_trend_status_mismatch", f"signoff report validation trend status does not match referenced validation trend report ({reported_validation_trend_status or 'missing'} vs {actual_validation_trend_status or 'missing'})"))
    if cutover_data is not None and reported_cutover_decision != actual_cutover_decision:
        issues.append(("signoff_cutover_decision_mismatch", f"signoff report cutover decision does not match referenced cutover decision ({reported_cutover_decision or 'missing'} vs {actual_cutover_decision or 'missing'})"))
    if cutover_trend_data is not None and reported_cutover_trend_status != actual_cutover_trend_status:
        issues.append(("signoff_cutover_trend_status_mismatch", f"signoff report cutover trend status does not match referenced cutover trend report ({reported_cutover_trend_status or 'missing'} vs {actual_cutover_trend_status or 'missing'})"))

    require_trend_pass = bool(requirements.get("require_trend_pass", False))
    require_validation_trend_pass = bool(requirements.get("require_validation_trend_pass", False))
    require_cutover_go = bool(requirements.get("require_cutover_go", False))
    require_cutover_trend_pass = bool(requirements.get("require_cutover_trend_pass", False))
    allow_mock_artifacts = bool(requirements.get("allow_mock_artifacts", False))
    validation_is_mock = bool((validation_data or {}).get("is_mock", False))
    validation_artifact_dir = str((validation_data or {}).get("artifact_dir", ""))

    if require_trend_pass and actual_trend_status != "PASS":
        issues.append(("signoff_required_trend_not_pass", f"signoff report requires trend PASS but referenced trend status is {actual_trend_status or 'missing'}"))
    if require_validation_trend_pass and actual_validation_trend_status != "PASS":
        issues.append(("signoff_required_validation_trend_not_pass", f"signoff report requires validation trend PASS but referenced validation trend status is {actual_validation_trend_status or 'missing'}"))
    if require_cutover_go and actual_cutover_decision != "GO":
        issues.append(("signoff_required_cutover_not_go", f"signoff report requires cutover GO but referenced cutover decision is {actual_cutover_decision or 'missing'}"))
    if require_cutover_trend_pass and actual_cutover_trend_status != "PASS":
        issues.append(("signoff_required_cutover_trend_not_pass", f"signoff report requires cutover trend PASS but referenced cutover trend status is {actual_cutover_trend_status or 'missing'}"))
    if (
        validation_data is not None
        and not allow_mock_artifacts
        and (validation_is_mock or "/mock-" in validation_artifact_dir or validation_artifact_dir.startswith("mock-"))
    ):
        issues.append(("signoff_mock_artifacts_not_allowed", "signoff report disallows mock artifacts but referenced validation bundle is mock"))
    return issues

overall_status = str(validation.get("overall_status", "")).upper()
is_mock = bool(validation.get("is_mock", False))
artifact_dir = str(validation.get("artifact_dir", ""))
baseline_review = (validation.get("baseline_review") or {}).get("recommendation", "")
baseline_health = (validation.get("baseline_health") or {}).get("category", "")
validation_files = validation.get("files", {}) or {}
validation_parity_report = str(validation_files.get("parity_report_json", "")).strip()
validation_parity_trend = str(validation_files.get("trend_report_json", "")).strip()

if overall_status != "PASS":
    add_reason(
        fail_items,
        "validation_not_pass",
        f"validation overall_status is {overall_status or 'missing'}",
    )

for code, message in validation_report_consistency_issues(validation):
    add_reason(fail_items, code, message)

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
    for code, message in readiness_report_consistency_issues(readiness):
        add_reason(fail_items, code, message)

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
    for code, message in cutover_decision_consistency_issues(cutover):
        add_reason(fail_items, code, message)
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
    for code, message in cutover_decision_chain_issues(current_cutover_decision, "current"):
        add_reason(fail_items, code, message)
    for code, message in cutover_decision_chain_issues(previous_cutover_decision, "previous"):
        add_reason(fail_items, code, message)
    if cutover_trend_status != "PASS":
        add_reason(
            fail_items,
            "cutover_trend_not_pass",
            f"cutover trend status is {cutover_trend_status or 'missing'}",
        )

signoff_status = ""
if signoff_report is not None:
    signoff_status = str(signoff_report.get("status", "")).upper()
    signoff_validation_report = str(signoff_report.get("validation_report_json", "")).strip()
    signoff_readiness_report = str(signoff_report.get("readiness_report_json", "")).strip()
    signoff_parity_report = str(signoff_report.get("report_json", "")).strip()
    signoff_trend_report = str(signoff_report.get("trend_report_json", "")).strip()
    signoff_validation_trend = str(signoff_report.get("validation_trend_report_json", "")).strip()
    signoff_cutover_decision = str(signoff_report.get("cutover_decision_json", "")).strip()
    signoff_cutover_trend = str(signoff_report.get("cutover_trend_report_json", "")).strip()
    if signoff_validation_report and str(validation_path) and signoff_validation_report != str(validation_path):
        add_reason(
            fail_items,
            "signoff_validation_report_mismatch",
            "signoff report validation report does not match release gate validation report",
        )
    if signoff_readiness_report and readiness_path and signoff_readiness_report != str(readiness_path):
        add_reason(
            fail_items,
            "signoff_readiness_report_mismatch",
            "signoff report readiness report does not match release gate readiness report",
        )
    if signoff_parity_report and validation_parity_report and signoff_parity_report != validation_parity_report:
        add_reason(
            fail_items,
            "signoff_parity_report_mismatch",
            "signoff report parity report does not match validation bundle parity report",
        )
    if signoff_trend_report and validation_parity_trend and signoff_trend_report != validation_parity_trend:
        add_reason(
            fail_items,
            "signoff_parity_trend_report_mismatch",
            "signoff report parity trend does not match validation bundle parity trend report",
        )
    if signoff_cutover_decision and cutover_path and signoff_cutover_decision != str(cutover_path):
        add_reason(
            fail_items,
            "signoff_cutover_decision_report_mismatch",
            "signoff report cutover decision does not match release gate cutover decision",
        )
    if signoff_cutover_trend and cutover_trend_path and signoff_cutover_trend != str(cutover_trend_path):
        add_reason(
            fail_items,
            "signoff_cutover_trend_report_mismatch",
            "signoff report cutover trend does not match release gate cutover trend report",
        )
    if signoff_readiness_report and not path_exists(signoff_readiness_report):
        add_reason(
            fail_items,
            "signoff_missing_readiness_report",
            "signoff report references a missing readiness report",
        )
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
    for code, message in signoff_report_consistency_issues(signoff_report):
        add_reason(fail_items, code, message)
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
