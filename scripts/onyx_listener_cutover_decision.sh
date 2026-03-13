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

json_get() {
  local report_file="$1"
  local expression="$2"
  python3 - "$report_file" "$expression" <<'PY'
import json
import sys

path = sys.argv[1]
expr = sys.argv[2].split(".")
with open(path, "r", encoding="utf-8") as handle:
    value = json.load(handle)
for key in expr:
    if isinstance(value, dict):
        value = value.get(key, "")
    else:
        value = ""
        break
if isinstance(value, bool):
    print("true" if value else "false")
elif value is None:
    print("")
else:
    print(value)
PY
}

validation_artifact_dir="$(dirname "$VALIDATION_REPORT_JSON")"

resolve_optional_report_path() {
  local existing_path="$1"
  local files_key="$2"
  local fallback_name="$3"

  if [[ -n "$existing_path" ]]; then
    printf '%s\n' "$existing_path"
    return 0
  fi

  local staged_path=""
  staged_path="$(json_get "$VALIDATION_REPORT_JSON" "files.${files_key}")"
  if [[ -n "$staged_path" && -f "$staged_path" ]]; then
    printf '%s\n' "$staged_path"
    return 0
  fi

  if [[ -n "$fallback_name" && -f "$validation_artifact_dir/$fallback_name" ]]; then
    printf '%s\n' "$validation_artifact_dir/$fallback_name"
    return 0
  fi

  printf '\n'
}

PARITY_REPORT_JSON="$(resolve_optional_report_path "$PARITY_REPORT_JSON" "parity_report_json" "report.json")"
PARITY_TREND_REPORT_JSON="$(resolve_optional_report_path "$PARITY_TREND_REPORT_JSON" "trend_report_json" "trend_report.json")"
VALIDATION_TREND_REPORT_JSON="$(resolve_optional_report_path "$VALIDATION_TREND_REPORT_JSON" "validation_trend_report_json" "validation_trend_report.json")"

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$(dirname "$VALIDATION_REPORT_JSON")"
fi
mkdir -p "$OUT_DIR"

python3 - "$VALIDATION_REPORT_JSON" "$PARITY_REPORT_JSON" "$PARITY_TREND_REPORT_JSON" "$VALIDATION_TREND_REPORT_JSON" "$OUT_DIR" "$REQUIRE_REAL_ARTIFACTS" <<'PY'
import json
import hashlib
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

def path_exists(raw_path):
    candidate = str(raw_path or "").strip()
    if not candidate:
        return True
    return Path(candidate).is_file()

def sha256_file(path_str):
    with open(path_str, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()

def validation_report_consistency_issues(report):
    issues = []
    files = report.get("files", {}) or {}
    checksums = report.get("checksums", {}) or {}
    gates = report.get("gates", {}) or {}
    statuses = report.get("statuses", {}) or {}
    baseline_review = report.get("baseline_review", {}) or {}
    baseline_health = report.get("baseline_health", {}) or {}

    def load_json_file(path_str):
        candidate = str(path_str or "").strip()
        if not candidate or not Path(candidate).is_file():
            return None
        with Path(candidate).open("r", encoding="utf-8") as handle:
            return json.load(handle)

    staged_review = load_json_file(files.get("baseline_review_json", ""))
    if staged_review is not None:
        for key in ("status", "recommendation", "summary", "bench_anomaly_status"):
            expected = str(staged_review.get(key, "")).strip()
            actual = str(baseline_review.get(key, "")).strip()
            if actual != expected:
                issues.append((f"validation_baseline_review_{key}_mismatch", f"validation baseline review {key} does not match staged baseline review JSON"))

    staged_health = load_json_file(files.get("baseline_health_json", ""))
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

    parity_report_path = str(files.get("parity_report_json", "")).strip()
    parity_report_markdown_sha = str(checksums.get("parity_report_markdown_sha256", "")).strip()
    parity_integrity_certificate_json = str(files.get("parity_integrity_certificate_json", "")).strip()
    parity_integrity_certificate_markdown = str(files.get("parity_integrity_certificate_markdown", "")).strip()
    if parity_report_path:
        if not parity_integrity_certificate_json:
            issues.append(("validation_missing_parity_integrity_certificate_json", "validation bundle is missing staged parity integrity certificate JSON"))
        elif not path_exists(parity_integrity_certificate_json):
            issues.append(("validation_missing_parity_integrity_certificate_json", "validation bundle references a missing staged parity integrity certificate JSON"))
        if not parity_integrity_certificate_markdown:
            issues.append(("validation_missing_parity_integrity_certificate_markdown", "validation bundle is missing staged parity integrity certificate markdown"))
        elif not path_exists(parity_integrity_certificate_markdown):
            issues.append(("validation_missing_parity_integrity_certificate_markdown", "validation bundle references a missing staged parity integrity certificate markdown"))

    parity_data = load_json_file(parity_report_path)
    parity_integrity_data = load_json_file(parity_integrity_certificate_json)
    if parity_integrity_data is not None:
        actual_status = str(parity_integrity_data.get("status", "")).upper()
        if actual_status != "PASS":
            issues.append(("validation_parity_integrity_certificate_not_pass", "validation parity integrity certificate is not PASS"))
        referenced_report_json = str(parity_integrity_data.get("report_json", "")).strip()
        if not referenced_report_json:
            issues.append(("validation_parity_integrity_certificate_missing_report_json", "validation parity integrity certificate is missing report_json"))
        elif not path_exists(referenced_report_json):
            issues.append(("validation_parity_integrity_certificate_missing_report_json", "validation parity integrity certificate references a missing parity report"))
        else:
            referenced_report = load_json_file(referenced_report_json)
            if referenced_report is not None and parity_data is not None:
                for key in ("status", "summary", "primary_issue_code"):
                    expected = str(parity_data.get(key, "")).strip()
                    actual = str(referenced_report.get(key, "")).strip()
                    if actual != expected:
                        issues.append((f"validation_parity_integrity_certificate_{key}_mismatch", f"validation parity integrity certificate parity report {key} does not match staged parity report"))
        actual_summary = str(parity_integrity_data.get("report_summary", "")).strip()
        expected_summary = str((parity_data or {}).get("summary", "")).strip()
        if parity_data is not None and actual_summary != expected_summary:
            issues.append(("validation_parity_integrity_certificate_report_summary_mismatch", "validation parity integrity certificate report summary does not match staged parity report"))
        actual_markdown_sha = str(((parity_integrity_data.get("checksums") or {}).get("report_markdown_sha256", ""))).strip()
        if parity_report_markdown_sha and actual_markdown_sha != parity_report_markdown_sha:
            issues.append(("validation_parity_integrity_certificate_report_markdown_checksum_mismatch", "validation parity integrity certificate markdown checksum does not match staged parity markdown"))

    pilot_gate = load_json_file(files.get("pilot_gate_report_json", ""))
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
            elif not Path(file_path).is_file():
                issues.append((f"validation_pilot_gate_missing_{file_key}", f"validation pilot gate references a missing {file_key}"))

        serial_parsed = load_json_file(pilot_files.get("serial_parsed_json", ""))
        if serial_parsed is not None:
            anomaly_gate = serial_parsed.get("anomaly_gate", {}) or {}
            expected_status = str(anomaly_gate.get("status", "")).upper()
            expected_code = str((((anomaly_gate.get("failures") or [{}])[0]).get("type", "") or "")).strip()
            actual_status = str(pilot_statuses.get("bench_anomaly_status", "")).upper()
            actual_code = str(pilot_statuses.get("bench_primary_failure_code", "")).strip()
            if actual_status != expected_status:
                issues.append(("validation_pilot_gate_bench_anomaly_status_mismatch", "validation pilot gate bench anomaly status does not match serial bench output"))
            if actual_code != expected_code:
                issues.append(("validation_pilot_gate_bench_primary_failure_code_mismatch", "validation pilot gate bench primary failure code does not match serial bench output"))

        parity_data = load_json_file(pilot_files.get("parity_report_json", ""))
        if parity_data is not None:
            expected_status = str(parity_data.get("status", "")).upper()
            expected_code = str(parity_data.get("primary_issue_code", "")).strip()
            actual_status = str(pilot_statuses.get("parity_status", "")).upper()
            actual_code = str(pilot_statuses.get("parity_primary_issue_code", "")).strip()
            if actual_status != expected_status:
                issues.append(("validation_pilot_gate_parity_status_mismatch", "validation pilot gate parity status does not match parity report"))
            if actual_code != expected_code:
                issues.append(("validation_pilot_gate_parity_primary_issue_code_mismatch", "validation pilot gate parity primary issue code does not match parity report"))

        readiness_data = load_json_file(pilot_files.get("parity_readiness_report_json", ""))
        if readiness_data is not None:
            expected_status = str(readiness_data.get("status", "")).upper()
            expected_code = str(readiness_data.get("failure_code", "")).strip()
            actual_status = str(pilot_statuses.get("parity_readiness_status", "")).upper()
            actual_code = str(pilot_statuses.get("parity_readiness_failure_code", "")).strip()
            if actual_status != expected_status:
                issues.append(("validation_pilot_gate_parity_readiness_status_mismatch", "validation pilot gate parity readiness status does not match parity readiness report"))
            if actual_code != expected_code:
                issues.append(("validation_pilot_gate_parity_readiness_failure_code_mismatch", "validation pilot gate parity readiness failure code does not match parity readiness report"))

        trend_data = load_json_file(pilot_files.get("trend_report_json", ""))
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

def parity_report_chain_issues(path_str, label):
    issues = []
    if not path_str:
        return issues
    report_path = Path(path_str)
    if not report_path.is_file():
        issues.append((f"parity_trend_missing_{label}_report", f"parity trend references a missing {label} parity report"))
        return issues
    with report_path.open("r", encoding="utf-8") as handle:
        report = json.load(handle)
    files = report.get("files", {}) or {}
    checksums = report.get("checksums", {}) or {}
    serial_input = str(files.get("serial_input", "")).strip()
    legacy_input = str(files.get("legacy_input", "")).strip()
    report_markdown = str(files.get("report_markdown", "")).strip()
    serial_input_sha = str(checksums.get("serial_input_sha256", "")).strip()
    legacy_input_sha = str(checksums.get("legacy_input_sha256", "")).strip()
    report_markdown_sha = str(checksums.get("report_markdown_sha256", "")).strip()
    if serial_input and not path_exists(serial_input):
        issues.append((f"parity_trend_{label}_missing_serial_input", f"parity trend {label} parity report references a missing serial input"))
    elif serial_input and not serial_input_sha:
        issues.append((f"parity_trend_{label}_missing_serial_input_checksum", f"parity trend {label} parity report is missing serial input checksum metadata"))
    elif serial_input and sha256_file(serial_input) != serial_input_sha:
        issues.append((f"parity_trend_{label}_serial_input_checksum_mismatch", f"parity trend {label} parity report serial input checksum does not match"))
    if legacy_input and not path_exists(legacy_input):
        issues.append((f"parity_trend_{label}_missing_legacy_input", f"parity trend {label} parity report references a missing legacy input"))
    elif legacy_input and not legacy_input_sha:
        issues.append((f"parity_trend_{label}_missing_legacy_input_checksum", f"parity trend {label} parity report is missing legacy input checksum metadata"))
    elif legacy_input and sha256_file(legacy_input) != legacy_input_sha:
        issues.append((f"parity_trend_{label}_legacy_input_checksum_mismatch", f"parity trend {label} parity report legacy input checksum does not match"))
    if report_markdown and not path_exists(report_markdown):
        issues.append((f"parity_trend_{label}_missing_report_markdown", f"parity trend {label} parity report references a missing markdown summary"))
    elif report_markdown and not report_markdown_sha:
        issues.append((f"parity_trend_{label}_missing_report_markdown_checksum", f"parity trend {label} parity report is missing markdown checksum metadata"))
    elif report_markdown and sha256_file(report_markdown) != report_markdown_sha:
        issues.append((f"parity_trend_{label}_report_markdown_checksum_mismatch", f"parity trend {label} parity report markdown checksum does not match"))
    return issues

parity = load_optional(parity_path)
parity_trend = load_optional(parity_trend_path)
validation_trend = load_optional(validation_trend_path)
validation_artifact_dir = str((validation.get("artifact_dir") or "")).strip()
integrity_certificate_path = Path(validation_artifact_dir) / "integrity_certificate.json" if validation_artifact_dir else None
integrity_certificate_markdown_path = Path(validation_artifact_dir) / "integrity_certificate.md" if validation_artifact_dir else None
integrity_certificate = load_optional(integrity_certificate_path) if integrity_certificate_path and integrity_certificate_path.is_file() else None

decision = "GO"
blocking_items = []
hold_items = []

def add_reason(items, code, message):
    items.append({"code": code, "message": message})

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
        add_reason(blocking_items, f"gate_{gate_name}_false", f"{gate_name} is false")

if overall_status != "PASS":
    add_reason(
        blocking_items,
        "validation_not_pass",
        f"validation overall_status is {overall_status or 'missing'}",
    )

for code, message in validation_report_consistency_issues(validation):
    add_reason(blocking_items, code, message)

if require_real and (is_mock or "/mock-" in artifact_dir or artifact_dir.startswith("mock-")):
    add_reason(
        blocking_items,
        "mock_artifacts_not_allowed",
        "validation artifact is mock while real artifacts are required",
    )

baseline_recommendation = str(baseline_review.get("recommendation", "")).lower()
baseline_health_category = str(baseline_health.get("category", "")).lower()
baseline_health_status = str(baseline_health.get("status", "")).upper()

if baseline_recommendation == "investigate_new_frame_shape":
    add_reason(
        blocking_items,
        "baseline_review_investigate_new_frame_shape",
        "baseline review recommends investigate_new_frame_shape",
    )
elif baseline_recommendation and baseline_recommendation != "hold_baseline":
    add_reason(
        hold_items,
        f"baseline_review_{baseline_recommendation}",
        f"baseline review recommends {baseline_recommendation}",
    )
elif not baseline_recommendation:
    add_reason(hold_items, "missing_baseline_review", "baseline review recommendation missing")

if baseline_health_status == "FAIL":
    add_reason(blocking_items, "baseline_health_fail", "baseline health status is FAIL")
elif baseline_health_category in {"stale", "missing_history", "invalid_timestamp", "missing_baseline"}:
    add_reason(
        hold_items,
        f"baseline_health_{baseline_health_category}",
        f"baseline health category is {baseline_health_category}",
    )
elif not baseline_health_category:
    add_reason(hold_items, "missing_baseline_health_category", "baseline health category missing")

if parity is not None:
    parity_summary = str(parity.get("summary", "")).strip()
    parity_files = parity.get("files", {}) or {}
    parity_checksums = parity.get("checksums", {}) or {}
    parity_serial_input = str(parity_files.get("serial_input", "")).strip()
    parity_legacy_input = str(parity_files.get("legacy_input", "")).strip()
    parity_report_markdown = str(parity_files.get("report_markdown", "")).strip()
    parity_serial_input_sha = str(parity_checksums.get("serial_input_sha256", "")).strip()
    parity_legacy_input_sha = str(parity_checksums.get("legacy_input_sha256", "")).strip()
    parity_report_markdown_sha = str(parity_checksums.get("report_markdown_sha256", "")).strip()
    if parity_serial_input and not path_exists(parity_serial_input):
        add_reason(
            blocking_items,
            "parity_missing_serial_input",
            "parity report references a missing serial input",
        )
    elif parity_serial_input and not parity_serial_input_sha:
        add_reason(
            blocking_items,
            "parity_missing_serial_input_checksum",
            "parity report is missing serial input checksum metadata",
        )
    elif parity_serial_input and sha256_file(parity_serial_input) != parity_serial_input_sha:
        add_reason(
            blocking_items,
            "parity_serial_input_checksum_mismatch",
            "parity report serial input checksum does not match",
        )
    if parity_legacy_input and not path_exists(parity_legacy_input):
        add_reason(
            blocking_items,
            "parity_missing_legacy_input",
            "parity report references a missing legacy input",
        )
    elif parity_legacy_input and not parity_legacy_input_sha:
        add_reason(
            blocking_items,
            "parity_missing_legacy_input_checksum",
            "parity report is missing legacy input checksum metadata",
        )
    elif parity_legacy_input and sha256_file(parity_legacy_input) != parity_legacy_input_sha:
        add_reason(
            blocking_items,
            "parity_legacy_input_checksum_mismatch",
            "parity report legacy input checksum does not match",
        )
    if parity_report_markdown and not path_exists(parity_report_markdown):
        add_reason(
            blocking_items,
            "parity_missing_report_markdown",
            "parity report references a missing markdown summary",
        )
    elif parity_report_markdown and not parity_report_markdown_sha:
        add_reason(
            blocking_items,
            "parity_missing_report_markdown_checksum",
            "parity report is missing markdown checksum metadata",
        )
    elif parity_report_markdown and sha256_file(parity_report_markdown) != parity_report_markdown_sha:
        add_reason(
            blocking_items,
            "parity_report_markdown_checksum_mismatch",
            "parity report markdown checksum does not match",
        )
else:
    parity_summary = ""
    add_reason(hold_items, "missing_parity_report", "parity report artifact missing")

if parity_trend is not None:
    parity_trend_status = str(parity_trend.get("status", "")).upper()
    current_parity_report = str(parity_trend.get("current_report_json", "")).strip()
    previous_parity_report = str(parity_trend.get("previous_report_json", "")).strip()
    if current_parity_report and not path_exists(current_parity_report):
        add_reason(
            blocking_items,
            "parity_trend_missing_current_report",
            "parity trend references a missing current parity report",
        )
    if previous_parity_report and not path_exists(previous_parity_report):
        add_reason(
            blocking_items,
            "parity_trend_missing_previous_report",
            "parity trend references a missing previous parity report",
        )
    for code, message in parity_report_chain_issues(current_parity_report, "current"):
        add_reason(blocking_items, code, message)
    for code, message in parity_report_chain_issues(previous_parity_report, "previous"):
        add_reason(blocking_items, code, message)
    if parity_trend_status != "PASS":
        add_reason(
            blocking_items,
            "parity_trend_not_pass",
            f"parity trend status is {parity_trend_status or 'missing'}",
        )
else:
    parity_trend_status = ""
    add_reason(hold_items, "missing_parity_trend", "parity trend artifact missing")

if validation_trend is not None:
    validation_trend_status = str(validation_trend.get("status", "")).upper()
    if validation_trend_status != "PASS":
        add_reason(
            blocking_items,
            "validation_trend_not_pass",
            f"validation trend status is {validation_trend_status or 'missing'}",
        )
else:
    validation_trend_status = ""
    add_reason(hold_items, "missing_validation_trend", "validation trend artifact missing")

integrity_certificate_status = str((integrity_certificate or {}).get("status", "")).upper()
if not integrity_certificate_path or not integrity_certificate_path.is_file():
    add_reason(
        blocking_items,
        "missing_integrity_certificate",
        "validation bundle integrity certificate missing",
    )
elif integrity_certificate_status != "PASS":
    add_reason(
        blocking_items,
        "integrity_certificate_not_pass",
        f"validation bundle integrity certificate status is {integrity_certificate_status or 'missing'}",
    )
elif str((integrity_certificate or {}).get("report_json", "")).strip() != str(validation_path):
    add_reason(
        blocking_items,
        "integrity_certificate_validation_report_mismatch",
        "validation bundle integrity certificate does not match validation report",
    )

if not integrity_certificate_markdown_path or not integrity_certificate_markdown_path.is_file():
    add_reason(
        blocking_items,
        "missing_integrity_certificate_markdown",
        "validation bundle integrity certificate markdown missing",
    )

blocking_reasons = [item["message"] for item in blocking_items]
hold_reasons = [item["message"] for item in hold_items]
blocking_codes = [item["code"] for item in blocking_items]
hold_codes = [item["code"] for item in hold_items]

if blocking_items:
    decision = "BLOCK"
elif hold_items:
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
    "integrity_certificate_json": str(integrity_certificate_path) if integrity_certificate_path and integrity_certificate_path.is_file() else "",
    "integrity_certificate_markdown": str(integrity_certificate_markdown_path) if integrity_certificate_markdown_path and integrity_certificate_markdown_path.is_file() else "",
    "parity_report_json": str(parity_path) if parity_path else "",
    "parity_trend_report_json": str(parity_trend_path) if parity_trend_path else "",
    "validation_trend_report_json": str(validation_trend_path) if validation_trend_path else "",
    "require_real_artifacts": require_real,
    "is_mock_validation_bundle": is_mock,
    "statuses": {
        "validation_overall_status": overall_status,
        "integrity_certificate_status": integrity_certificate_status,
        "baseline_review_recommendation": baseline_recommendation,
        "baseline_health_status": baseline_health_status,
        "baseline_health_category": baseline_health_category,
        "parity_trend_status": parity_trend_status,
        "validation_trend_status": validation_trend_status,
    },
    "primary_blocking_code": blocking_codes[0] if blocking_codes else "",
    "primary_hold_code": hold_codes[0] if hold_codes else "",
    "blocking_codes": blocking_codes,
    "hold_codes": hold_codes,
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
if integrity_certificate_path and integrity_certificate_path.is_file():
    lines.append(f"- Integrity certificate JSON: `{integrity_certificate_path}`")
if integrity_certificate_markdown_path and integrity_certificate_markdown_path.is_file():
    lines.append(f"- Integrity certificate markdown: `{integrity_certificate_markdown_path}`")
lines.extend([
    "",
    "## Statuses",
    f"- Validation overall status: `{overall_status or 'missing'}`",
    f"- Integrity certificate status: `{integrity_certificate_status or 'missing'}`",
    f"- Baseline review recommendation: `{baseline_recommendation or 'missing'}`",
    f"- Baseline health: `{baseline_health_status or 'missing'} / {baseline_health_category or 'missing'}`",
    f"- Parity trend status: `{parity_trend_status or 'missing'}`",
    f"- Validation trend status: `{validation_trend_status or 'missing'}`",
    f"- Primary blocking code: `{result['primary_blocking_code'] or 'missing'}`",
    f"- Primary hold code: `{result['primary_hold_code'] or 'missing'}`",
    "",
    "## Hard Gates",
])
for key, value in sorted(gates.items()):
    lines.append(f"- `{key}`: `{value}`")
lines.extend(["", "## Blocking Reasons"])
if blocking_items:
    for item in blocking_items:
        lines.append(f"- `{item['code']}`: {item['message']}")
else:
    lines.append("- None")
lines.extend(["", "## Hold Reasons"])
if hold_items:
    for item in hold_items:
        lines.append(f"- `{item['code']}`: {item['message']}")
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
