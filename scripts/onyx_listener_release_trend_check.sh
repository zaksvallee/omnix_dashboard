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
import hashlib
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

def readiness_report_consistency_regressions(path_str, label):
    regressions = []
    report = load_json(path_str)
    if report is None:
        return regressions
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
        regressions.append({
            "code": f"{label}_validation_status_mismatch",
            "kind": "readiness_chain_status_mismatch",
            "report_label": label,
            "expected": actual_validation_status,
            "actual": reported_validation_status,
        })

    require_validation_trend_pass = bool(requirements.get("require_validation_trend_pass", False))
    require_cutover_go = bool(requirements.get("require_cutover_go", False))
    require_cutover_trend_pass = bool(requirements.get("require_cutover_trend_pass", False))
    actual_validation_trend_status = str((validation_trend_data or {}).get("status", "")).upper()
    actual_cutover_decision = str((cutover_data or {}).get("decision", "")).upper()
    actual_cutover_trend_status = str((cutover_trend_data or {}).get("status", "")).upper()

    if require_validation_trend_pass and actual_validation_trend_status != "PASS":
        regressions.append({
            "code": f"{label}_required_validation_trend_not_pass",
            "kind": "readiness_chain_requirement_mismatch",
            "report_label": label,
            "requirement": "require_validation_trend_pass",
            "actual": actual_validation_trend_status,
        })
    if require_cutover_go and actual_cutover_decision != "GO":
        regressions.append({
            "code": f"{label}_required_cutover_not_go",
            "kind": "readiness_chain_requirement_mismatch",
            "report_label": label,
            "requirement": "require_cutover_go",
            "actual": actual_cutover_decision,
        })
    if require_cutover_trend_pass and actual_cutover_trend_status != "PASS":
        regressions.append({
            "code": f"{label}_required_cutover_trend_not_pass",
            "kind": "readiness_chain_requirement_mismatch",
            "report_label": label,
            "requirement": "require_cutover_trend_pass",
            "actual": actual_cutover_trend_status,
        })
    return regressions

def sha256_file(path_str):
    with open(path_str, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()

def validation_bundle_chain_regressions(path_str, label):
    regressions = []
    if not path_str:
        return regressions
    report_path = Path(path_str)
    if not report_path.is_file():
        regressions.append({
            "code": f"{label}_missing_validation_report",
            "kind": "validation_chain_missing_file",
            "report_label": label,
            "missing_field": "validation_report",
            "missing_path": path_str,
        })
        return regressions
    with report_path.open("r", encoding="utf-8") as handle:
        report = json.load(handle)
    files = report.get("files", {}) or {}
    checksums = report.get("checksums", {}) or {}
    pairs = (
        ("serial_capture", "serial_capture_sha256"),
        ("serial_parsed_json", "serial_parsed_json_sha256"),
        ("bench_baseline_json", "bench_baseline_json_sha256"),
        ("baseline_review_json", "baseline_review_json_sha256"),
        ("baseline_health_json", "baseline_health_json_sha256"),
        ("legacy_capture", "legacy_capture_sha256"),
        ("field_notes", "field_notes_sha256"),
        ("parity_report_json", "parity_report_json_sha256"),
        ("parity_report_markdown", "parity_report_markdown_sha256"),
        ("parity_readiness_report_json", "parity_readiness_report_json_sha256"),
        ("parity_readiness_report_markdown", "parity_readiness_report_markdown_sha256"),
        ("trend_report_json", "trend_report_json_sha256"),
        ("trend_report_markdown", "trend_report_markdown_sha256"),
        ("pilot_gate_report_json", "pilot_gate_report_json_sha256"),
        ("pilot_gate_report_markdown", "pilot_gate_report_markdown_sha256"),
        ("pilot_gate_output", "pilot_gate_output_sha256"),
        ("markdown_report", "markdown_report_sha256"),
    )
    for file_key, checksum_key in pairs:
        path_value = str(files.get(file_key, "")).strip()
        checksum_value = str(checksums.get(checksum_key, "")).strip()
        if path_value and not path_exists(path_value):
            regressions.append({
                "code": f"{label}_missing_{file_key}",
                "kind": "validation_chain_missing_file",
                "report_label": label,
                "missing_field": file_key,
                "missing_path": path_value,
            })
        elif path_value and not checksum_value:
            regressions.append({
                "code": f"{label}_missing_{file_key}_checksum",
                "kind": "validation_chain_missing_checksum",
                "report_label": label,
                "missing_field": file_key,
                "missing_checksum_field": checksum_key,
            })
        elif path_value and checksum_value and sha256_file(path_value) != checksum_value:
            regressions.append({
                "code": f"{label}_{file_key}_checksum_mismatch",
                "kind": "validation_chain_checksum_mismatch",
                "report_label": label,
                "mismatch_field": file_key,
                "path": path_value,
            })
        elif checksum_value and not path_value:
            regressions.append({
                "code": f"{label}_missing_{file_key}_path",
                "kind": "validation_chain_missing_metadata",
                "report_label": label,
                "missing_field": file_key,
                "missing_checksum_field": checksum_key,
            })
    artifact_dir = str(report.get("artifact_dir", "")).strip()
    if artifact_dir and not Path(artifact_dir).is_dir():
        regressions.append({
            "code": f"{label}_missing_artifact_dir",
            "kind": "validation_chain_missing_dir",
            "report_label": label,
            "missing_path": artifact_dir,
        })
    baseline_review = report.get("baseline_review", {}) or {}
    baseline_health = report.get("baseline_health", {}) or {}
    staged_review = str(files.get("baseline_review_json", "")).strip()
    if staged_review and Path(staged_review).is_file():
        with Path(staged_review).open("r", encoding="utf-8") as handle:
            review_data = json.load(handle)
        for key in ("status", "recommendation", "summary", "bench_anomaly_status"):
            expected = str(review_data.get(key, "")).strip()
            actual = str(baseline_review.get(key, "")).strip()
            if actual != expected:
                regressions.append({
                    "code": f"{label}_baseline_review_{key}_mismatch",
                    "kind": "validation_summary_mismatch",
                    "report_label": label,
                    "summary_field": f"baseline_review.{key}",
                    "expected": expected,
                    "actual": actual,
                })
    staged_health = str(files.get("baseline_health_json", "")).strip()
    if staged_health and Path(staged_health).is_file():
        with Path(staged_health).open("r", encoding="utf-8") as handle:
            health_data = json.load(handle)
        for key in ("status", "category", "summary"):
            expected = str(health_data.get(key, "")).strip()
            actual = str(baseline_health.get(key, "")).strip()
            if actual != expected:
                regressions.append({
                    "code": f"{label}_baseline_health_{key}_mismatch",
                    "kind": "validation_summary_mismatch",
                    "report_label": label,
                    "summary_field": f"baseline_health.{key}",
                    "expected": expected,
                    "actual": actual,
                })
        if baseline_health.get("age_days") != health_data.get("age_days"):
            regressions.append({
                "code": f"{label}_baseline_health_age_days_mismatch",
                "kind": "validation_summary_mismatch",
                "report_label": label,
                "summary_field": "baseline_health.age_days",
                "expected": "" if health_data.get("age_days") is None else str(health_data.get("age_days")),
                "actual": "" if baseline_health.get("age_days") is None else str(baseline_health.get("age_days")),
            })
    gates = report.get("gates", {}) or {}
    statuses = report.get("statuses", {}) or {}
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
            regressions.append({
                "code": f"{label}_{gate_key}_status_mismatch",
                "kind": "validation_status_gate_mismatch",
                "report_label": label,
                "gate_field": gate_key,
                "status_field": status_key,
                "expected": str(status_value == "PASS").lower(),
                "actual": str(gate_value).lower(),
                "status": status_value,
            })
    failure_codes = [str(item) for item in (report.get("failure_codes", []) or [])]
    warning_codes = [str(item) for item in (report.get("warning_codes", []) or [])]
    primary_failure_code = str(report.get("primary_failure_code", "")).strip()
    primary_warning_code = str(report.get("primary_warning_code", "")).strip()
    expected_primary_failure = failure_codes[0] if failure_codes else ""
    expected_primary_warning = warning_codes[0] if warning_codes else ""
    if primary_failure_code != expected_primary_failure:
        regressions.append({
            "code": f"{label}_primary_failure_code_mismatch",
            "kind": "validation_primary_code_mismatch",
            "report_label": label,
            "summary_field": "primary_failure_code",
            "expected": expected_primary_failure,
            "actual": primary_failure_code,
        })
    if primary_warning_code != expected_primary_warning:
        regressions.append({
            "code": f"{label}_primary_warning_code_mismatch",
            "kind": "validation_primary_code_mismatch",
            "report_label": label,
            "summary_field": "primary_warning_code",
            "expected": expected_primary_warning,
            "actual": primary_warning_code,
        })
    regressions.extend(validation_pilot_gate_regressions(report, label))
    return regressions

def validation_pilot_gate_regressions(report, label):
    regressions = []
    files = report.get("files", {}) or {}
    pilot_gate_path = str(files.get("pilot_gate_report_json", "")).strip()
    if not pilot_gate_path or not path_exists(pilot_gate_path):
        return regressions
    with Path(pilot_gate_path).open("r", encoding="utf-8") as handle:
        pilot_gate = json.load(handle)
    pilot_files = pilot_gate.get("files", {}) or {}
    pilot_statuses = pilot_gate.get("statuses", {}) or {}
    compare_previous = bool(pilot_gate.get("compare_previous", False))

    def add(code_suffix, kind, **extra):
        issue = {
            "code": f"{label}_pilot_gate_{code_suffix}",
            "kind": kind,
            "report_label": label,
        }
        issue.update(extra)
        regressions.append(issue)

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
            add(f"missing_{file_key}", "pilot_gate_missing_file", missing_field=file_key, missing_path="")
        elif not path_exists(file_path):
            add(f"missing_{file_key}", "pilot_gate_missing_file", missing_field=file_key, missing_path=file_path)

    serial_parsed = str(pilot_files.get("serial_parsed_json", "")).strip()
    if serial_parsed and path_exists(serial_parsed):
        with Path(serial_parsed).open("r", encoding="utf-8") as handle:
            serial_data = json.load(handle)
        anomaly_gate = serial_data.get("anomaly_gate", {}) or {}
        expected_status = str(anomaly_gate.get("status", "")).upper()
        expected_code = str((((anomaly_gate.get("failures") or [{}])[0]).get("type", "") or "")).strip()
        actual_status = str(pilot_statuses.get("bench_anomaly_status", "")).upper()
        actual_code = str(pilot_statuses.get("bench_primary_failure_code", "")).strip()
        if actual_status != expected_status:
            add("bench_anomaly_status_mismatch", "pilot_gate_status_mismatch", expected=expected_status, actual=actual_status)
        if actual_code != expected_code:
            add("bench_primary_failure_code_mismatch", "pilot_gate_code_mismatch", expected=expected_code, actual=actual_code)

    parity_report = str(pilot_files.get("parity_report_json", "")).strip()
    if parity_report and path_exists(parity_report):
        with Path(parity_report).open("r", encoding="utf-8") as handle:
            parity_data = json.load(handle)
        expected_status = str(parity_data.get("status", "")).upper()
        expected_code = str(parity_data.get("primary_issue_code", "")).strip()
        actual_status = str(pilot_statuses.get("parity_status", "")).upper()
        actual_code = str(pilot_statuses.get("parity_primary_issue_code", "")).strip()
        if actual_status != expected_status:
            add("parity_status_mismatch", "pilot_gate_status_mismatch", expected=expected_status, actual=actual_status)
        if actual_code != expected_code:
            add("parity_primary_issue_code_mismatch", "pilot_gate_code_mismatch", expected=expected_code, actual=actual_code)

    parity_readiness = str(pilot_files.get("parity_readiness_report_json", "")).strip()
    if parity_readiness and path_exists(parity_readiness):
        with Path(parity_readiness).open("r", encoding="utf-8") as handle:
            readiness_data = json.load(handle)
        expected_status = str(readiness_data.get("status", "")).upper()
        expected_code = str(readiness_data.get("failure_code", "")).strip()
        actual_status = str(pilot_statuses.get("parity_readiness_status", "")).upper()
        actual_code = str(pilot_statuses.get("parity_readiness_failure_code", "")).strip()
        if actual_status != expected_status:
            add("parity_readiness_status_mismatch", "pilot_gate_status_mismatch", expected=expected_status, actual=actual_status)
        if actual_code != expected_code:
            add("parity_readiness_failure_code_mismatch", "pilot_gate_code_mismatch", expected=expected_code, actual=actual_code)

    trend_report = str(pilot_files.get("trend_report_json", "")).strip()
    if compare_previous and trend_report and path_exists(trend_report):
        with Path(trend_report).open("r", encoding="utf-8") as handle:
            trend_data = json.load(handle)
        expected_status = str(trend_data.get("status", "")).upper()
        expected_code = str(trend_data.get("primary_regression_code", "")).strip()
        actual_status = str(pilot_statuses.get("parity_trend_status", "")).upper()
        actual_code = str(pilot_statuses.get("parity_trend_primary_regression_code", "")).strip()
        if actual_status != expected_status:
            add("parity_trend_status_mismatch", "pilot_gate_status_mismatch", expected=expected_status, actual=actual_status)
        if actual_code != expected_code:
            add("parity_trend_primary_regression_code_mismatch", "pilot_gate_code_mismatch", expected=expected_code, actual=actual_code)
    return regressions

def parity_report_chain_regressions(path_str, label):
    regressions = []
    if not path_str:
        return regressions
    report_path = Path(path_str)
    if not report_path.is_file():
        regressions.append({
            "code": f"{label}_missing_report",
            "kind": "parity_chain_missing_file",
            "report_label": label,
            "missing_field": "report",
            "missing_path": path_str,
        })
        return regressions
    with report_path.open("r", encoding="utf-8") as handle:
        report = json.load(handle)
    files = report.get("files", {}) or {}
    checksums = report.get("checksums", {}) or {}
    for file_key, checksum_key in (
        ("serial_input", "serial_input_sha256"),
        ("legacy_input", "legacy_input_sha256"),
        ("report_markdown", "report_markdown_sha256"),
    ):
        path_value = str(files.get(file_key, "")).strip()
        checksum_value = str(checksums.get(checksum_key, "")).strip()
        if path_value and not path_exists(path_value):
            regressions.append({
                "code": f"{label}_missing_{file_key}",
                "kind": "parity_chain_missing_file",
                "report_label": label,
                "missing_field": file_key,
                "missing_path": path_value,
            })
        elif path_value and not checksum_value:
            regressions.append({
                "code": f"{label}_missing_{file_key}_checksum",
                "kind": "parity_chain_missing_checksum",
                "report_label": label,
                "missing_field": file_key,
                "missing_checksum_field": checksum_key,
            })
        elif path_value and checksum_value and sha256_file(path_value) != checksum_value:
            regressions.append({
                "code": f"{label}_{file_key}_checksum_mismatch",
                "kind": "parity_chain_checksum_mismatch",
                "report_label": label,
                "mismatch_field": file_key,
                "path": path_value,
            })
    return regressions

def parity_trend_chain_regressions(path_str, label):
    regressions = []
    if not path_str:
        return regressions
    report_path = Path(path_str)
    if not report_path.is_file():
        regressions.append({
            "code": f"{label}_missing_report",
            "kind": "parity_trend_missing_file",
            "report_label": label,
            "missing_field": "trend_report",
            "missing_path": path_str,
        })
        return regressions
    with report_path.open("r", encoding="utf-8") as handle:
        report = json.load(handle)
    current_report = str(report.get("current_report_json", "")).strip()
    previous_report = str(report.get("previous_report_json", "")).strip()
    if current_report and not path_exists(current_report):
        regressions.append({
            "code": f"{label}_missing_current_report",
            "kind": "parity_trend_missing_file",
            "report_label": label,
            "missing_field": "current_report",
            "missing_path": current_report,
        })
    else:
        regressions.extend(parity_report_chain_regressions(current_report, f"{label}_current_report"))
    if previous_report and not path_exists(previous_report):
        regressions.append({
            "code": f"{label}_missing_previous_report",
            "kind": "parity_trend_missing_file",
            "report_label": label,
            "missing_field": "previous_report",
            "missing_path": previous_report,
        })
    else:
        regressions.extend(parity_report_chain_regressions(previous_report, f"{label}_previous_report"))
    return regressions

def validation_trend_chain_regressions(path_str, label):
    regressions = []
    if not path_str:
        return regressions
    report_path = Path(path_str)
    if not report_path.is_file():
        regressions.append({
            "code": f"{label}_missing_report",
            "kind": "validation_trend_missing_file",
            "report_label": label,
            "missing_field": "trend_report",
            "missing_path": path_str,
        })
        return regressions
    with report_path.open("r", encoding="utf-8") as handle:
        report = json.load(handle)
    current_report = str(report.get("current_report_json", "")).strip()
    previous_report = str(report.get("previous_report_json", "")).strip()
    if current_report and not path_exists(current_report):
        regressions.append({
            "code": f"{label}_missing_current_report",
            "kind": "validation_trend_missing_file",
            "report_label": label,
            "missing_field": "current_report",
            "missing_path": current_report,
        })
    else:
        regressions.extend(validation_bundle_chain_regressions(current_report, f"{label}_current_report"))
    if previous_report and not path_exists(previous_report):
        regressions.append({
            "code": f"{label}_missing_previous_report",
            "kind": "validation_trend_missing_file",
            "report_label": label,
            "missing_field": "previous_report",
            "missing_path": previous_report,
        })
    else:
        regressions.extend(validation_bundle_chain_regressions(previous_report, f"{label}_previous_report"))
    return regressions

def cutover_decision_consistency_regressions(report, label):
    regressions = []
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

    def add(code_suffix, kind, expected, actual):
        regressions.append({
            "code": f"{label}_{code_suffix}",
            "kind": kind,
            "report_label": label,
            "expected": expected,
            "actual": actual,
        })

    if validation_data is not None:
        actual_validation_status = str(validation_data.get("overall_status", "")).upper()
        if str(statuses.get("validation_overall_status", "")).upper() != actual_validation_status:
            add("validation_status_mismatch", "cutover_chain_status_mismatch", actual_validation_status, str(statuses.get("validation_overall_status", "")).upper())

        actual_review = str(((validation_data.get("baseline_review") or {}).get("recommendation", ""))).lower()
        if str(statuses.get("baseline_review_recommendation", "")).lower() != actual_review:
            add("baseline_review_recommendation_mismatch", "cutover_chain_status_mismatch", actual_review, str(statuses.get("baseline_review_recommendation", "")).lower())

        actual_health_status = str(((validation_data.get("baseline_health") or {}).get("status", ""))).upper()
        if str(statuses.get("baseline_health_status", "")).upper() != actual_health_status:
            add("baseline_health_status_mismatch", "cutover_chain_status_mismatch", actual_health_status, str(statuses.get("baseline_health_status", "")).upper())

        actual_health_category = str(((validation_data.get("baseline_health") or {}).get("category", ""))).lower()
        if str(statuses.get("baseline_health_category", "")).lower() != actual_health_category:
            add("baseline_health_category_mismatch", "cutover_chain_status_mismatch", actual_health_category, str(statuses.get("baseline_health_category", "")).lower())

        actual_gates = validation_data.get("gates", {}) or {}
        for gate_key in sorted(set(actual_gates.keys()) | set(gates.keys())):
            expected = bool(actual_gates.get(gate_key, False))
            actual = bool(gates.get(gate_key, False))
            if actual != expected:
                add(f"gate_{gate_key}_mismatch", "cutover_chain_gate_mismatch", str(expected).lower(), str(actual).lower())

    if parity_data is not None:
        actual_parity_summary = str(parity_data.get("summary", "")).strip()
        if str(report.get("parity_summary", "")).strip() != actual_parity_summary:
            add("parity_summary_mismatch", "cutover_chain_status_mismatch", actual_parity_summary, str(report.get("parity_summary", "")).strip())

    if parity_trend_data is not None:
        actual_parity_trend_status = str(parity_trend_data.get("status", "")).upper()
        if str(statuses.get("parity_trend_status", "")).upper() != actual_parity_trend_status:
            add("parity_trend_status_mismatch", "cutover_chain_status_mismatch", actual_parity_trend_status, str(statuses.get("parity_trend_status", "")).upper())

    if validation_trend_data is not None:
        actual_validation_trend_status = str(validation_trend_data.get("status", "")).upper()
        if str(statuses.get("validation_trend_status", "")).upper() != actual_validation_trend_status:
            add("validation_trend_status_mismatch", "cutover_chain_status_mismatch", actual_validation_trend_status, str(statuses.get("validation_trend_status", "")).upper())

    expected_primary_blocking = blocking_codes[0] if blocking_codes else ""
    expected_primary_hold = hold_codes[0] if hold_codes else ""
    if primary_blocking_code != expected_primary_blocking:
        add("primary_blocking_code_mismatch", "cutover_chain_primary_code_mismatch", expected_primary_blocking, primary_blocking_code)
    if primary_hold_code != expected_primary_hold:
        add("primary_hold_code_mismatch", "cutover_chain_primary_code_mismatch", expected_primary_hold, primary_hold_code)

    if decision == "BLOCK" and not blocking_codes:
        add("decision_block_without_blocking_codes", "cutover_chain_decision_code_mismatch", "blocking_codes_present", "blocking_codes_missing")
    if decision == "HOLD" and (blocking_codes or not hold_codes):
        add("decision_hold_code_mismatch", "cutover_chain_decision_code_mismatch", "hold_only_codes", f"blocking={bool(blocking_codes)} hold={bool(hold_codes)}")
    if decision == "GO" and (blocking_codes or hold_codes):
        add("decision_go_with_reason_codes", "cutover_chain_decision_code_mismatch", "no_reason_codes", f"blocking={bool(blocking_codes)} hold={bool(hold_codes)}")

    return regressions

def cutover_decision_chain_regressions(path_str, label):
    regressions = []
    if not path_str:
        return regressions
    report_path = Path(path_str)
    if not report_path.is_file():
        regressions.append({
            "code": f"{label}_missing_decision",
            "kind": "cutover_chain_missing_file",
            "report_label": label,
            "missing_field": "decision",
            "missing_path": path_str,
        })
        return regressions
    with report_path.open("r", encoding="utf-8") as handle:
        report = json.load(handle)
    validation_report = str(report.get("validation_report_json", "")).strip()
    parity_report = str(report.get("parity_report_json", "")).strip()
    parity_trend = str(report.get("parity_trend_report_json", "")).strip()
    validation_trend = str(report.get("validation_trend_report_json", "")).strip()
    if validation_report and not path_exists(validation_report):
        regressions.append({
            "code": f"{label}_missing_validation_report",
            "kind": "cutover_chain_missing_file",
            "report_label": label,
            "missing_field": "validation_report",
            "missing_path": validation_report,
        })
    else:
        regressions.extend(validation_bundle_chain_regressions(validation_report, f"{label}_validation"))
    if parity_report and not path_exists(parity_report):
        regressions.append({
            "code": f"{label}_missing_parity_report",
            "kind": "cutover_chain_missing_file",
            "report_label": label,
            "missing_field": "parity_report",
            "missing_path": parity_report,
        })
    else:
        regressions.extend(parity_report_chain_regressions(parity_report, f"{label}_parity"))
    if parity_trend and not path_exists(parity_trend):
        regressions.append({
            "code": f"{label}_missing_parity_trend_report",
            "kind": "cutover_chain_missing_file",
            "report_label": label,
            "missing_field": "parity_trend_report",
            "missing_path": parity_trend,
        })
    else:
        regressions.extend(parity_trend_chain_regressions(parity_trend, f"{label}_parity_trend"))
    if validation_trend and not path_exists(validation_trend):
        regressions.append({
            "code": f"{label}_missing_validation_trend_report",
            "kind": "cutover_chain_missing_file",
            "report_label": label,
            "missing_field": "validation_trend_report",
            "missing_path": validation_trend,
        })
    else:
        regressions.extend(validation_trend_chain_regressions(validation_trend, f"{label}_validation_trend"))
    regressions.extend(cutover_decision_consistency_regressions(report, label))
    return regressions

def signoff_report_chain_regressions(path_str, label):
    regressions = []
    if not path_str:
        return regressions
    report_path = Path(path_str)
    if not report_path.is_file():
        regressions.append({
            "code": f"{label}_missing_report",
            "kind": "signoff_chain_missing_file",
            "report_label": label,
            "missing_field": "signoff_report",
            "missing_path": path_str,
        })
        return regressions
    with report_path.open("r", encoding="utf-8") as handle:
        report = json.load(handle)
    signoff_status = str(report.get("status", "")).upper()
    signoff_failure_code = str(report.get("failure_code", "")).strip()
    signoff_file = str(report.get("signoff_file", "")).strip()
    readiness_report = str(report.get("readiness_report_json", "")).strip()
    parity_report = str(report.get("report_json", "")).strip()
    parity_trend = str(report.get("trend_report_json", "")).strip()
    validation_report = str(report.get("validation_report_json", "")).strip()
    validation_trend = str(report.get("validation_trend_report_json", "")).strip()
    cutover_decision = str(report.get("cutover_decision_json", "")).strip()
    cutover_trend = str(report.get("cutover_trend_report_json", "")).strip()
    if signoff_file and not path_exists(signoff_file):
        regressions.append({
            "code": f"{label}_missing_signoff_file",
            "kind": "signoff_chain_missing_file",
            "report_label": label,
            "missing_field": "signoff_file",
            "missing_path": signoff_file,
        })
    if readiness_report and not path_exists(readiness_report):
        regressions.append({
            "code": f"{label}_missing_readiness_report",
            "kind": "signoff_chain_missing_file",
            "report_label": label,
            "missing_field": "readiness_report",
            "missing_path": readiness_report,
        })
    else:
        regressions.extend(readiness_report_consistency_regressions(readiness_report, f"{label}_readiness"))
    if parity_report and not path_exists(parity_report):
        regressions.append({
            "code": f"{label}_missing_parity_report",
            "kind": "signoff_chain_missing_file",
            "report_label": label,
            "missing_field": "parity_report",
            "missing_path": parity_report,
        })
    else:
        regressions.extend(parity_report_chain_regressions(parity_report, f"{label}_parity"))
    if parity_trend and not path_exists(parity_trend):
        regressions.append({
            "code": f"{label}_missing_trend_report",
            "kind": "signoff_chain_missing_file",
            "report_label": label,
            "missing_field": "trend_report",
            "missing_path": parity_trend,
        })
    else:
        regressions.extend(parity_trend_chain_regressions(parity_trend, f"{label}_trend"))
    if validation_report and not path_exists(validation_report):
        regressions.append({
            "code": f"{label}_missing_validation_report",
            "kind": "signoff_chain_missing_file",
            "report_label": label,
            "missing_field": "validation_report",
            "missing_path": validation_report,
        })
    else:
        regressions.extend(validation_bundle_chain_regressions(validation_report, f"{label}_validation"))
    if validation_trend and not path_exists(validation_trend):
        regressions.append({
            "code": f"{label}_missing_validation_trend_report",
            "kind": "signoff_chain_missing_file",
            "report_label": label,
            "missing_field": "validation_trend_report",
            "missing_path": validation_trend,
        })
    else:
        regressions.extend(validation_trend_chain_regressions(validation_trend, f"{label}_validation_trend"))
    if cutover_decision and not path_exists(cutover_decision):
        regressions.append({
            "code": f"{label}_missing_cutover_decision_report",
            "kind": "signoff_chain_missing_file",
            "report_label": label,
            "missing_field": "cutover_decision_report",
            "missing_path": cutover_decision,
        })
    else:
        regressions.extend(cutover_decision_chain_regressions(cutover_decision, f"{label}_cutover"))
    if cutover_trend and not path_exists(cutover_trend):
        regressions.append({
            "code": f"{label}_missing_cutover_trend_report",
            "kind": "signoff_chain_missing_file",
            "report_label": label,
            "missing_field": "cutover_trend_report",
            "missing_path": cutover_trend,
        })
    else:
        regressions.extend(cutover_trend_chain_regressions(cutover_trend, f"{label}_cutover_trend"))

    statuses = report.get("statuses", {}) or {}
    requirements = report.get("requirements", {}) or {}
    readiness_data = load_json(readiness_report)
    trend_data = load_json(parity_trend)
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

    def add_consistency(code_suffix, expected, actual):
        regressions.append({
            "code": f"{label}_{code_suffix}",
            "kind": "signoff_chain_status_mismatch",
            "report_label": label,
            "expected": expected,
            "actual": actual,
        })

    if signoff_status not in {"PASS", "FAIL"}:
        regressions.append({
            "code": f"{label}_invalid_status",
            "kind": "signoff_chain_status_mismatch",
            "report_label": label,
            "expected": "PASS|FAIL",
            "actual": signoff_status or "missing",
        })
    if signoff_status == "PASS" and signoff_failure_code:
        regressions.append({
            "code": f"{label}_failure_code_present_on_pass",
            "kind": "signoff_chain_status_mismatch",
            "report_label": label,
            "expected": "",
            "actual": signoff_failure_code,
        })
    if signoff_status == "FAIL" and not signoff_failure_code:
        regressions.append({
            "code": f"{label}_missing_failure_code",
            "kind": "signoff_chain_status_mismatch",
            "report_label": label,
            "expected": "non-empty failure_code",
            "actual": "",
        })

    if readiness_data is not None and reported_readiness_status != actual_readiness_status:
        add_consistency("readiness_status_mismatch", actual_readiness_status, reported_readiness_status)
    if readiness_data is not None and reported_readiness_failure_code != actual_readiness_failure_code:
        add_consistency("readiness_failure_code_mismatch", actual_readiness_failure_code, reported_readiness_failure_code)
    if trend_data is not None and reported_trend_status != actual_trend_status:
        add_consistency("trend_status_mismatch", actual_trend_status, reported_trend_status)
    if validation_trend_data is not None and reported_validation_trend_status != actual_validation_trend_status:
        add_consistency("validation_trend_status_mismatch", actual_validation_trend_status, reported_validation_trend_status)
    if cutover_data is not None and reported_cutover_decision != actual_cutover_decision:
        add_consistency("cutover_decision_mismatch", actual_cutover_decision, reported_cutover_decision)
    if cutover_trend_data is not None and reported_cutover_trend_status != actual_cutover_trend_status:
        add_consistency("cutover_trend_status_mismatch", actual_cutover_trend_status, reported_cutover_trend_status)

    require_trend_pass = bool(requirements.get("require_trend_pass", False))
    require_validation_trend_pass = bool(requirements.get("require_validation_trend_pass", False))
    require_cutover_go = bool(requirements.get("require_cutover_go", False))
    require_cutover_trend_pass = bool(requirements.get("require_cutover_trend_pass", False))

    if require_trend_pass and actual_trend_status != "PASS":
        regressions.append({
            "code": f"{label}_required_trend_not_pass",
            "kind": "signoff_chain_requirement_mismatch",
            "report_label": label,
            "requirement": "require_trend_pass",
            "actual": actual_trend_status,
        })
    if require_validation_trend_pass and actual_validation_trend_status != "PASS":
        regressions.append({
            "code": f"{label}_required_validation_trend_not_pass",
            "kind": "signoff_chain_requirement_mismatch",
            "report_label": label,
            "requirement": "require_validation_trend_pass",
            "actual": actual_validation_trend_status,
        })
    if require_cutover_go and actual_cutover_decision != "GO":
        regressions.append({
            "code": f"{label}_required_cutover_not_go",
            "kind": "signoff_chain_requirement_mismatch",
            "report_label": label,
            "requirement": "require_cutover_go",
            "actual": actual_cutover_decision,
        })
    if require_cutover_trend_pass and actual_cutover_trend_status != "PASS":
        regressions.append({
            "code": f"{label}_required_cutover_trend_not_pass",
            "kind": "signoff_chain_requirement_mismatch",
            "report_label": label,
            "requirement": "require_cutover_trend_pass",
            "actual": actual_cutover_trend_status,
        })
    return regressions

def cutover_trend_chain_regressions(path_str, label):
    regressions = []
    if not path_str:
        return regressions
    report_path = Path(path_str)
    if not report_path.is_file():
        regressions.append({
            "code": f"{label}_missing_report",
            "kind": "cutover_trend_missing_file",
            "report_label": label,
            "missing_field": "trend_report",
            "missing_path": path_str,
        })
        return regressions
    with report_path.open("r", encoding="utf-8") as handle:
        report = json.load(handle)
    current_decision = str(report.get("current_decision_json", "")).strip()
    previous_decision = str(report.get("previous_decision_json", "")).strip()
    if current_decision and not path_exists(current_decision):
        regressions.append({
            "code": f"{label}_missing_current_decision",
            "kind": "cutover_trend_missing_file",
            "report_label": label,
            "missing_field": "current_decision",
            "missing_path": current_decision,
        })
    else:
        regressions.extend(cutover_decision_chain_regressions(current_decision, f"{label}_current_decision"))
    if previous_decision and not path_exists(previous_decision):
        regressions.append({
            "code": f"{label}_missing_previous_decision",
            "kind": "cutover_trend_missing_file",
            "report_label": label,
            "missing_field": "previous_decision",
            "missing_path": previous_decision,
        })
    else:
        regressions.extend(cutover_decision_chain_regressions(previous_decision, f"{label}_previous_decision"))
    return regressions

def release_gate_consistency_regressions(report, label):
    regressions = []
    statuses = report.get("statuses", {}) or {}
    fail_codes = [str(item) for item in (report.get("fail_codes", []) or [])]
    hold_codes = [str(item) for item in (report.get("hold_codes", []) or [])]
    primary_fail_code = str(report.get("primary_fail_code", "")).strip()
    primary_hold_code = str(report.get("primary_hold_code", "")).strip()
    result = str(report.get("result", "")).upper()

    validation_report = str(report.get("validation_report_json", "")).strip()
    readiness_report = str(report.get("readiness_report_json", "")).strip()
    cutover_decision = str(report.get("cutover_decision_json", "")).strip()
    cutover_trend = str(report.get("cutover_trend_report_json", "")).strip()
    signoff_report = str(report.get("signoff_report_json", "")).strip()

    validation_data = load_json(validation_report)
    readiness_data = load_json(readiness_report)
    cutover_data = load_json(cutover_decision)
    cutover_trend_data = load_json(cutover_trend)
    signoff_data = load_json(signoff_report)

    def add(code_suffix, kind, expected, actual):
        regressions.append({
            "code": f"{label}_{code_suffix}",
            "kind": kind,
            "report_label": label,
            "expected": expected,
            "actual": actual,
        })

    if validation_data is not None:
        actual_validation_status = str(validation_data.get("overall_status", "")).upper()
        if str(statuses.get("validation_overall_status", "")).upper() != actual_validation_status:
            add("validation_status_mismatch", "release_gate_status_mismatch", actual_validation_status, str(statuses.get("validation_overall_status", "")).upper())

        actual_review = str(((validation_data.get("baseline_review") or {}).get("recommendation", ""))).lower()
        if str(statuses.get("baseline_review_recommendation", "")).lower() != actual_review:
            add("baseline_review_recommendation_mismatch", "release_gate_status_mismatch", actual_review, str(statuses.get("baseline_review_recommendation", "")).lower())

        actual_health = str(((validation_data.get("baseline_health") or {}).get("category", ""))).lower()
        if str(statuses.get("baseline_health_category", "")).lower() != actual_health:
            add("baseline_health_category_mismatch", "release_gate_status_mismatch", actual_health, str(statuses.get("baseline_health_category", "")).lower())

    if readiness_data is not None:
        actual_readiness_status = str(readiness_data.get("status", "")).upper()
        if str(statuses.get("readiness_status", "")).upper() != actual_readiness_status:
            add("readiness_status_mismatch", "release_gate_status_mismatch", actual_readiness_status, str(statuses.get("readiness_status", "")).upper())
        actual_readiness_failure = str(readiness_data.get("failure_code", "")).strip()
        if str(statuses.get("readiness_failure_code", "")).strip() != actual_readiness_failure:
            add("readiness_failure_code_mismatch", "release_gate_status_mismatch", actual_readiness_failure, str(statuses.get("readiness_failure_code", "")).strip())

    if cutover_data is not None:
        actual_cutover_decision = str(cutover_data.get("decision", "")).upper()
        if str(statuses.get("cutover_decision", "")).upper() != actual_cutover_decision:
            add("cutover_decision_mismatch", "release_gate_status_mismatch", actual_cutover_decision, str(statuses.get("cutover_decision", "")).upper())

    if cutover_trend_data is not None:
        actual_cutover_trend_status = str(cutover_trend_data.get("status", "")).upper()
        if str(statuses.get("cutover_trend_status", "")).upper() != actual_cutover_trend_status:
            add("cutover_trend_status_mismatch", "release_gate_status_mismatch", actual_cutover_trend_status, str(statuses.get("cutover_trend_status", "")).upper())

    if signoff_data is not None:
        actual_signoff_status = str(signoff_data.get("status", "")).upper()
        if str(statuses.get("signoff_status", "")).upper() != actual_signoff_status:
            add("signoff_status_mismatch", "release_gate_status_mismatch", actual_signoff_status, str(statuses.get("signoff_status", "")).upper())

    expected_primary_fail = fail_codes[0] if fail_codes else ""
    expected_primary_hold = hold_codes[0] if hold_codes else ""
    if primary_fail_code != expected_primary_fail:
        add("primary_fail_code_mismatch", "release_gate_primary_code_mismatch", expected_primary_fail, primary_fail_code)
    if primary_hold_code != expected_primary_hold:
        add("primary_hold_code_mismatch", "release_gate_primary_code_mismatch", expected_primary_hold, primary_hold_code)

    if result == "FAIL" and not fail_codes:
        add("result_fail_without_fail_codes", "release_gate_result_code_mismatch", "fail_codes_present", "fail_codes_missing")
    if result == "HOLD" and (fail_codes or not hold_codes):
        add("result_hold_code_mismatch", "release_gate_result_code_mismatch", "hold_only_codes", f"fail={bool(fail_codes)} hold={bool(hold_codes)}")
    if result == "PASS" and (fail_codes or hold_codes):
        add("result_pass_with_reason_codes", "release_gate_result_code_mismatch", "no_reason_codes", f"fail={bool(fail_codes)} hold={bool(hold_codes)}")

    return regressions

def gate_chain_regressions(report, label):
    regressions = []
    validation_report = str(report.get("validation_report_json", "")).strip()
    readiness_report = str(report.get("readiness_report_json", "")).strip()
    cutover_decision = str(report.get("cutover_decision_json", "")).strip()
    cutover_trend = str(report.get("cutover_trend_report_json", "")).strip()
    signoff_file = str(report.get("signoff_file", "")).strip()
    signoff_report = str(report.get("signoff_report_json", "")).strip()
    for field_name, value in (
        ("validation_report", validation_report),
        ("readiness_report", readiness_report),
        ("cutover_decision", cutover_decision),
        ("cutover_trend_report", cutover_trend),
        ("signoff_file", signoff_file),
        ("signoff_report", signoff_report),
    ):
        if value and not path_exists(value):
            regressions.append({
                "code": f"{label}_gate_missing_{field_name}",
                "kind": "gate_chain_missing_file",
                "gate_label": label,
                "missing_field": field_name,
                "missing_path": value,
            })
    regressions.extend(validation_bundle_chain_regressions(validation_report, f"{label}_gate_validation"))
    if readiness_report and path_exists(readiness_report):
        with Path(readiness_report).open("r", encoding="utf-8") as handle:
            readiness = json.load(handle)
        readiness_validation_report = str(readiness.get("validation_report_json", "")).strip()
        if readiness_validation_report and not path_exists(readiness_validation_report):
            regressions.append({
                "code": f"{label}_gate_readiness_missing_validation_report",
                "kind": "readiness_chain_missing_file",
                "report_label": f"{label}_gate_readiness",
                "missing_field": "validation_report",
                "missing_path": readiness_validation_report,
            })
        else:
            regressions.extend(validation_bundle_chain_regressions(readiness_validation_report, f"{label}_gate_readiness_validation"))
    regressions.extend(readiness_report_consistency_regressions(readiness_report, f"{label}_gate_readiness"))
    regressions.extend(cutover_decision_chain_regressions(cutover_decision, f"{label}_gate_cutover"))
    regressions.extend(cutover_trend_chain_regressions(cutover_trend, f"{label}_gate_cutover_trend"))
    regressions.extend(signoff_report_chain_regressions(signoff_report, f"{label}_gate_signoff"))
    regressions.extend(release_gate_consistency_regressions(report, f"{label}_gate"))
    return regressions

result_rank = {"FAIL": 0, "HOLD": 1, "PASS": 2}

current_result = str(current.get("result", "")).upper()
previous_result = str(previous.get("result", "")).upper()

current_hold_codes = list(current.get("hold_codes", []) or current.get("hold_reasons", []) or [])
previous_hold_codes = list(previous.get("hold_codes", []) or previous.get("hold_reasons", []) or [])
current_fail_codes = list(current.get("fail_codes", []) or current.get("fail_reasons", []) or [])
previous_fail_codes = list(previous.get("fail_codes", []) or previous.get("fail_reasons", []) or [])

regressions = []
regressions.extend(gate_chain_regressions(current, "current"))
regressions.extend(gate_chain_regressions(previous, "previous"))
if result_rank.get(current_result, -1) < result_rank.get(previous_result, -1):
    regressions.append(
        {
            "code": "result_regression",
            "kind": "result_regression",
            "previous": previous_result,
            "current": current_result,
        }
    )

hold_increase = len(current_hold_codes) - len(previous_hold_codes)
if hold_increase > allow_hold_increase:
    regressions.append(
        {
            "code": "hold_reason_increase",
            "kind": "hold_reason_increase",
            "previous": len(previous_hold_codes),
            "current": len(current_hold_codes),
            "delta": hold_increase,
            "allowed_increase": allow_hold_increase,
        }
    )

fail_increase = len(current_fail_codes) - len(previous_fail_codes)
if fail_increase > allow_fail_increase:
    regressions.append(
        {
            "code": "fail_reason_increase",
            "kind": "fail_reason_increase",
            "previous": len(previous_fail_codes),
            "current": len(current_fail_codes),
            "delta": fail_increase,
            "allowed_increase": allow_fail_increase,
        }
    )

new_hold_codes = sorted(set(current_hold_codes) - set(previous_hold_codes))
new_fail_codes = sorted(set(current_fail_codes) - set(previous_fail_codes))

status = "PASS" if not regressions else "FAIL"
result = {
    "status": status,
    "summary": (
        f"release {previous_result or 'missing'} -> {current_result or 'missing'}; "
        f"hold codes {len(previous_hold_codes)} -> {len(current_hold_codes)}; "
        f"fail codes {len(previous_fail_codes)} -> {len(current_fail_codes)}"
    ),
    "current_release_gate_json": str(current_path),
    "previous_release_gate_json": str(previous_path),
    "result": {
        "previous": previous_result,
        "current": current_result,
    },
    "counts": {
        "hold_reasons": {
            "previous": len(previous_hold_codes),
            "current": len(current_hold_codes),
            "delta": hold_increase,
            "allowed_increase": allow_hold_increase,
        },
        "fail_reasons": {
            "previous": len(previous_fail_codes),
            "current": len(current_fail_codes),
            "delta": fail_increase,
            "allowed_increase": allow_fail_increase,
        },
    },
    "new_hold_reasons": new_hold_codes,
    "new_fail_reasons": new_fail_codes,
    "primary_regression_code": regressions[0]["code"] if regressions else "",
    "regression_codes": [item["code"] for item in regressions],
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
        f"- Hold codes: `{len(previous_hold_codes)} -> {len(current_hold_codes)}` "
        f"(delta `{hold_increase}`, allowed `{allow_hold_increase}`)"
    ),
    (
        f"- Fail codes: `{len(previous_fail_codes)} -> {len(current_fail_codes)}` "
        f"(delta `{fail_increase}`, allowed `{allow_fail_increase}`)"
    ),
    "",
    "## New Hold Codes",
]
if new_hold_codes:
    for item in new_hold_codes:
        lines.append(f"- {item}")
else:
    lines.append("- None")

lines.extend(["", "## New Fail Codes"])
if new_fail_codes:
    for item in new_fail_codes:
        lines.append(f"- {item}")
else:
    lines.append("- None")

lines.extend(["", "## Regressions"])
if regressions:
    for item in regressions:
        if item["kind"] == "result_regression":
            lines.append(f"- `{item['code']}`: `{item['previous']} -> {item['current']}`")
        elif item["kind"] == "gate_chain_missing_file":
            lines.append(
                f"- `{item['code']}`: `{item['gate_label']}` gate missing "
                f"`{item['missing_field']}` at `{item['missing_path']}`"
            )
        elif item["kind"] in {
            "validation_chain_missing_file",
            "parity_chain_missing_file",
            "parity_trend_missing_file",
            "validation_trend_missing_file",
            "cutover_chain_missing_file",
            "cutover_trend_missing_file",
            "signoff_chain_missing_file",
            "readiness_chain_missing_file",
        }:
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` missing "
                f"`{item['missing_field']}` at `{item['missing_path']}`"
            )
        elif item["kind"] in {
            "validation_chain_missing_checksum",
            "parity_chain_missing_checksum",
        }:
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` missing checksum "
                f"`{item['missing_checksum_field']}` for `{item['missing_field']}`"
            )
        elif item["kind"] in {
            "validation_chain_checksum_mismatch",
            "parity_chain_checksum_mismatch",
        }:
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` checksum mismatch "
                f"for `{item['mismatch_field']}` at `{item['path']}`"
            )
        elif item["kind"] == "validation_summary_mismatch":
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` expected "
                f"`{item['summary_field']}` to be `{item['expected'] or 'missing'}` "
                f"but saw `{item['actual'] or 'missing'}`"
            )
        elif item["kind"] == "validation_status_gate_mismatch":
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` gate "
                f"`{item['gate_field']}` is `{item['actual']}` but "
                f"`{item['status_field']}` is `{item['status'] or 'missing'}`"
            )
        elif item["kind"] == "validation_primary_code_mismatch":
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` expected "
                f"`{item['summary_field']}` to be `{item['expected'] or 'missing'}` "
                f"but saw `{item['actual'] or 'missing'}`"
            )
        elif item["kind"] == "readiness_chain_status_mismatch":
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` expected "
                f"`{item['expected'] or 'missing'}` but saw `{item['actual'] or 'missing'}`"
            )
        elif item["kind"] == "readiness_chain_requirement_mismatch":
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` requires "
                f"`{item['requirement']}` but underlying status is `{item['actual'] or 'missing'}`"
            )
        elif item["kind"] == "signoff_chain_status_mismatch":
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` expected "
                f"`{item['expected'] or 'missing'}` but saw `{item['actual'] or 'missing'}`"
            )
        elif item["kind"] in {
            "release_gate_status_mismatch",
            "release_gate_primary_code_mismatch",
            "release_gate_result_code_mismatch",
        }:
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` expected "
                f"`{item['expected'] or 'missing'}` but saw `{item['actual'] or 'missing'}`"
            )
        elif item["kind"] == "pilot_gate_missing_file":
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` pilot gate missing "
                f"`{item['missing_field']}` at `{item['missing_path'] or 'missing'}`"
            )
        elif item["kind"] in {"pilot_gate_status_mismatch", "pilot_gate_code_mismatch"}:
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` pilot gate expected "
                f"`{item['expected'] or 'missing'}` but saw `{item['actual'] or 'missing'}`"
            )
        elif item["kind"] in {
            "cutover_chain_status_mismatch",
            "cutover_chain_gate_mismatch",
            "cutover_chain_primary_code_mismatch",
            "cutover_chain_decision_code_mismatch",
        }:
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` expected "
                f"`{item['expected'] or 'missing'}` but saw `{item['actual'] or 'missing'}`"
            )
        elif item["kind"] == "signoff_chain_requirement_mismatch":
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` requires "
                f"`{item['requirement']}` but underlying status is `{item['actual'] or 'missing'}`"
            )
        elif item["kind"] == "validation_chain_missing_metadata":
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` has checksum "
                f"`{item['missing_checksum_field']}` without a `{item['missing_field']}` path"
            )
        elif item["kind"] == "validation_chain_missing_dir":
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` missing artifact dir "
                f"`{item['missing_path']}`"
            )
        else:
            lines.append(
                f"- `{item['code']}`: `{item['previous']} -> {item['current']}` "
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
            print(f"REGRESSION: {item['code']} {item['previous']} -> {item['current']}")
        elif item["kind"] == "gate_chain_missing_file":
            print(
                f"REGRESSION: {item['code']} {item['gate_label']} missing "
                f"{item['missing_field']} at {item['missing_path']}"
            )
        elif item["kind"] in {
            "validation_chain_missing_file",
            "parity_chain_missing_file",
            "parity_trend_missing_file",
            "validation_trend_missing_file",
            "cutover_chain_missing_file",
            "cutover_trend_missing_file",
            "signoff_chain_missing_file",
            "readiness_chain_missing_file",
        }:
            print(
                f"REGRESSION: {item['code']} {item['report_label']} missing "
                f"{item['missing_field']} at {item['missing_path']}"
            )
        elif item["kind"] in {
            "validation_chain_missing_checksum",
            "parity_chain_missing_checksum",
        }:
            print(
                f"REGRESSION: {item['code']} {item['report_label']} missing checksum "
                f"{item['missing_checksum_field']} for {item['missing_field']}"
            )
        elif item["kind"] in {
            "validation_chain_checksum_mismatch",
            "parity_chain_checksum_mismatch",
        }:
            print(
                f"REGRESSION: {item['code']} {item['report_label']} checksum mismatch "
                f"for {item['mismatch_field']} at {item['path']}"
            )
        elif item["kind"] == "validation_summary_mismatch":
            print(
                f"REGRESSION: {item['code']} {item['report_label']} expected "
                f"{item['summary_field']}={item['expected'] or 'missing'} but saw {item['actual'] or 'missing'}"
            )
        elif item["kind"] == "validation_status_gate_mismatch":
            print(
                f"REGRESSION: {item['code']} {item['report_label']} gate "
                f"{item['gate_field']}={item['actual']} but {item['status_field']}={item['status'] or 'missing'}"
            )
        elif item["kind"] == "validation_primary_code_mismatch":
            print(
                f"REGRESSION: {item['code']} {item['report_label']} expected "
                f"{item['summary_field']}={item['expected'] or 'missing'} but saw {item['actual'] or 'missing'}"
            )
        elif item["kind"] == "readiness_chain_status_mismatch":
            print(
                f"REGRESSION: {item['code']} {item['report_label']} expected "
                f"{item['expected'] or 'missing'} but saw {item['actual'] or 'missing'}"
            )
        elif item["kind"] == "readiness_chain_requirement_mismatch":
            print(
                f"REGRESSION: {item['code']} {item['report_label']} requires "
                f"{item['requirement']} but underlying status is {item['actual'] or 'missing'}"
            )
        elif item["kind"] == "signoff_chain_status_mismatch":
            print(
                f"REGRESSION: {item['code']} {item['report_label']} expected "
                f"{item['expected'] or 'missing'} but saw {item['actual'] or 'missing'}"
            )
        elif item["kind"] in {
            "release_gate_status_mismatch",
            "release_gate_primary_code_mismatch",
            "release_gate_result_code_mismatch",
        }:
            print(
                f"REGRESSION: {item['code']} {item['report_label']} expected "
                f"{item['expected'] or 'missing'} but saw {item['actual'] or 'missing'}"
            )
        elif item["kind"] == "pilot_gate_missing_file":
            print(
                f"REGRESSION: {item['code']} {item['report_label']} pilot gate missing "
                f"{item['missing_field']} at {item['missing_path'] or 'missing'}"
            )
        elif item["kind"] in {"pilot_gate_status_mismatch", "pilot_gate_code_mismatch"}:
            print(
                f"REGRESSION: {item['code']} {item['report_label']} pilot gate expected "
                f"{item['expected'] or 'missing'} but saw {item['actual'] or 'missing'}"
            )
        elif item["kind"] in {
            "cutover_chain_status_mismatch",
            "cutover_chain_gate_mismatch",
            "cutover_chain_primary_code_mismatch",
            "cutover_chain_decision_code_mismatch",
        }:
            print(
                f"REGRESSION: {item['code']} {item['report_label']} expected "
                f"{item['expected'] or 'missing'} but saw {item['actual'] or 'missing'}"
            )
        elif item["kind"] == "signoff_chain_requirement_mismatch":
            print(
                f"REGRESSION: {item['code']} {item['report_label']} requires "
                f"{item['requirement']} but underlying status is {item['actual'] or 'missing'}"
            )
        elif item["kind"] == "validation_chain_missing_metadata":
            print(
                f"REGRESSION: {item['code']} {item['report_label']} has checksum "
                f"{item['missing_checksum_field']} without a {item['missing_field']} path"
            )
        elif item["kind"] == "validation_chain_missing_dir":
            print(
                f"REGRESSION: {item['code']} {item['report_label']} missing artifact dir "
                f"{item['missing_path']}"
            )
        else:
            print(
                f"REGRESSION: {item['code']} {item['previous']} -> {item['current']} "
                f"(delta {item['delta']}, allowed {item['allowed_increase']})"
            )
    sys.exit(1)
PY
