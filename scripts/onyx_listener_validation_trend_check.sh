#!/usr/bin/env bash
set -euo pipefail

CURRENT_REPORT_JSON=""
PREVIOUS_REPORT_JSON=""
OUT_DIR=""
ALLOW_BASELINE_AGE_INCREASE_DAYS=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_validation_trend_check.sh [--current-report-json <path>] [--previous-report-json <path>] [--out-dir <path>] [--allow-baseline-age-increase-days 0]

Purpose:
  Compare one listener field-validation bundle against the previous run and
  fail when validation status, gate booleans, baseline review, or baseline
  health regress beyond the allowed thresholds.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --current-report-json)
      CURRENT_REPORT_JSON="${2:-}"
      shift 2
      ;;
    --previous-report-json)
      PREVIOUS_REPORT_JSON="${2:-}"
      shift 2
      ;;
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --allow-baseline-age-increase-days)
      ALLOW_BASELINE_AGE_INCREASE_DAYS="${2:-0}"
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

if ! [[ "$ALLOW_BASELINE_AGE_INCREASE_DAYS" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "FAIL: --allow-baseline-age-increase-days must be a non-negative number."
  exit 1
fi

latest_reports() {
  local base_dir="tmp/listener_field_validation"
  if [[ ! -d "$base_dir" ]]; then
    return 1
  fi
  find "$base_dir" -type f -name "validation_report.json" -print0 2>/dev/null \
    | xargs -0 ls -1t 2>/dev/null
}

if [[ -z "$CURRENT_REPORT_JSON" ]]; then
  CURRENT_REPORT_JSON="$(latest_reports | sed -n '1p' || true)"
fi
if [[ -z "$CURRENT_REPORT_JSON" || ! -f "$CURRENT_REPORT_JSON" ]]; then
  echo "FAIL: current listener validation report not found."
  exit 1
fi

if [[ -z "$PREVIOUS_REPORT_JSON" ]]; then
  PREVIOUS_REPORT_JSON="$(
    latest_reports \
      | awk -v current="$CURRENT_REPORT_JSON" '$0 != current { print; exit }' \
      || true
  )"
fi
if [[ -z "$PREVIOUS_REPORT_JSON" || ! -f "$PREVIOUS_REPORT_JSON" ]]; then
  echo "FAIL: previous listener validation report not found."
  exit 1
fi

if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="$(dirname "$CURRENT_REPORT_JSON")"
fi
mkdir -p "$OUT_DIR"

python3 - "$CURRENT_REPORT_JSON" "$PREVIOUS_REPORT_JSON" "$OUT_DIR" "$ALLOW_BASELINE_AGE_INCREASE_DAYS" <<'PY'
import json
import hashlib
import sys
from pathlib import Path

current_path = Path(sys.argv[1])
previous_path = Path(sys.argv[2])
out_dir = Path(sys.argv[3])
allow_age_increase = float(sys.argv[4])

with current_path.open("r", encoding="utf-8") as handle:
    current = json.load(handle)
with previous_path.open("r", encoding="utf-8") as handle:
    previous = json.load(handle)

def path_exists(raw_path):
    candidate = str(raw_path or "").strip()
    if not candidate:
        return True
    return Path(candidate).is_file()

def sha256_file(path_str):
    with open(path_str, "rb") as handle:
        return hashlib.sha256(handle.read()).hexdigest()

def validation_chain_regressions(report, label):
    regressions = []
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
                "code": f"{label}_validation_missing_{file_key}",
                "kind": "validation_chain_missing_file",
                "report_label": label,
                "missing_field": file_key,
                "missing_path": path_value,
            })
        elif path_value and not checksum_value:
            regressions.append({
                "code": f"{label}_validation_missing_{file_key}_checksum",
                "kind": "validation_chain_missing_checksum",
                "report_label": label,
                "missing_field": file_key,
                "missing_checksum_field": checksum_key,
            })
        elif path_value and checksum_value and sha256_file(path_value) != checksum_value:
            regressions.append({
                "code": f"{label}_validation_{file_key}_checksum_mismatch",
                "kind": "validation_chain_checksum_mismatch",
                "report_label": label,
                "mismatch_field": file_key,
                "path": path_value,
            })
        elif checksum_value and not path_value:
            regressions.append({
                "code": f"{label}_validation_missing_{file_key}_path",
                "kind": "validation_chain_missing_metadata",
                "report_label": label,
                "missing_field": file_key,
                "missing_checksum_field": checksum_key,
            })
    artifact_dir = str(report.get("artifact_dir", "")).strip()
    if artifact_dir and not Path(artifact_dir).is_dir():
        regressions.append({
            "code": f"{label}_validation_missing_artifact_dir",
            "kind": "validation_chain_missing_dir",
            "report_label": label,
            "missing_path": artifact_dir,
        })
    baseline_review = report.get("baseline_review", {}) or {}
    baseline_health = report.get("baseline_health", {}) or {}
    staged_baseline_review = str(files.get("baseline_review_json", "")).strip()
    staged_baseline_health = str(files.get("baseline_health_json", "")).strip()
    if staged_baseline_review and Path(staged_baseline_review).is_file():
        with Path(staged_baseline_review).open("r", encoding="utf-8") as handle:
            review_data = json.load(handle)
        for key in ("status", "recommendation", "summary", "bench_anomaly_status"):
            expected = str(review_data.get(key, "")).strip()
            actual = str(baseline_review.get(key, "")).strip()
            if actual != expected:
                regressions.append({
                    "code": f"{label}_validation_baseline_review_{key}_mismatch",
                    "kind": "validation_summary_mismatch",
                    "report_label": label,
                    "summary_field": f"baseline_review.{key}",
                    "expected": expected,
                    "actual": actual,
                })
    if staged_baseline_health and Path(staged_baseline_health).is_file():
        with Path(staged_baseline_health).open("r", encoding="utf-8") as handle:
            health_data = json.load(handle)
        for key in ("status", "category", "summary"):
            expected = str(health_data.get(key, "")).strip()
            actual = str(baseline_health.get(key, "")).strip()
            if actual != expected:
                regressions.append({
                    "code": f"{label}_validation_baseline_health_{key}_mismatch",
                    "kind": "validation_summary_mismatch",
                    "report_label": label,
                    "summary_field": f"baseline_health.{key}",
                    "expected": expected,
                    "actual": actual,
                })
        expected_age = health_data.get("age_days")
        actual_age = baseline_health.get("age_days")
        if expected_age != actual_age:
            regressions.append({
                "code": f"{label}_validation_baseline_health_age_days_mismatch",
                "kind": "validation_summary_mismatch",
                "report_label": label,
                "summary_field": "baseline_health.age_days",
                "expected": "" if expected_age is None else str(expected_age),
                "actual": "" if actual_age is None else str(actual_age),
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
        status_value = upper(statuses.get(status_key, ""))
        expected_gate_value = status_value == "PASS"
        if gate_value != expected_gate_value:
            regressions.append({
                "code": f"{label}_validation_{gate_key}_status_mismatch",
                "kind": "validation_status_gate_mismatch",
                "report_label": label,
                "gate_field": gate_key,
                "status_field": status_key,
                "expected": str(expected_gate_value).lower(),
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
            "code": f"{label}_validation_primary_failure_code_mismatch",
            "kind": "validation_primary_code_mismatch",
            "report_label": label,
            "summary_field": "primary_failure_code",
            "expected": expected_primary_failure,
            "actual": primary_failure_code,
        })
    if primary_warning_code != expected_primary_warning:
        regressions.append({
            "code": f"{label}_validation_primary_warning_code_mismatch",
            "kind": "validation_primary_code_mismatch",
            "report_label": label,
            "summary_field": "primary_warning_code",
            "expected": expected_primary_warning,
            "actual": primary_warning_code,
        })
    pilot_gate_report_path = str(files.get("pilot_gate_report_json", "")).strip()
    if pilot_gate_report_path and Path(pilot_gate_report_path).is_file():
        with Path(pilot_gate_report_path).open("r", encoding="utf-8") as handle:
            pilot_gate = json.load(handle)
        pilot_files = pilot_gate.get("files", {}) or {}
        pilot_statuses = pilot_gate.get("statuses", {}) or {}
        compare_previous = bool(pilot_gate.get("compare_previous", False))

        def add_pilot_issue(code_suffix, kind, **extra):
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
                add_pilot_issue(f"missing_{file_key}", "pilot_gate_missing_file", missing_field=file_key, missing_path="")
            elif not path_exists(file_path):
                add_pilot_issue(f"missing_{file_key}", "pilot_gate_missing_file", missing_field=file_key, missing_path=file_path)

        serial_parsed = str(pilot_files.get("serial_parsed_json", "")).strip()
        if serial_parsed and path_exists(serial_parsed):
            with Path(serial_parsed).open("r", encoding="utf-8") as handle:
                serial_data = json.load(handle)
            bench_status = upper((serial_data.get("anomaly_gate") or {}).get("status"))
            bench_failure_code = str((((serial_data.get("anomaly_gate") or {}).get("failures") or [{}])[0]).get("type", "") or "").strip()
            actual_bench_status = upper(pilot_statuses.get("bench_anomaly_status"))
            actual_bench_code = str(pilot_statuses.get("bench_primary_failure_code", "")).strip()
            if actual_bench_status != bench_status:
                add_pilot_issue("bench_anomaly_status_mismatch", "pilot_gate_status_mismatch", expected=bench_status, actual=actual_bench_status)
            if actual_bench_code != bench_failure_code:
                add_pilot_issue("bench_primary_failure_code_mismatch", "pilot_gate_code_mismatch", expected=bench_failure_code, actual=actual_bench_code)

        parity_report = str(pilot_files.get("parity_report_json", "")).strip()
        if parity_report and path_exists(parity_report):
            with Path(parity_report).open("r", encoding="utf-8") as handle:
                parity_data = json.load(handle)
            parity_status = upper(parity_data.get("status"))
            parity_code = str(parity_data.get("primary_issue_code", "")).strip()
            actual_parity_status = upper(pilot_statuses.get("parity_status"))
            actual_parity_code = str(pilot_statuses.get("parity_primary_issue_code", "")).strip()
            if actual_parity_status != parity_status:
                add_pilot_issue("parity_status_mismatch", "pilot_gate_status_mismatch", expected=parity_status, actual=actual_parity_status)
            if actual_parity_code != parity_code:
                add_pilot_issue("parity_primary_issue_code_mismatch", "pilot_gate_code_mismatch", expected=parity_code, actual=actual_parity_code)

        parity_readiness = str(pilot_files.get("parity_readiness_report_json", "")).strip()
        if parity_readiness and path_exists(parity_readiness):
            with Path(parity_readiness).open("r", encoding="utf-8") as handle:
                readiness_data = json.load(handle)
            readiness_status = upper(readiness_data.get("status"))
            readiness_code = str(readiness_data.get("failure_code", "")).strip()
            actual_readiness_status = upper(pilot_statuses.get("parity_readiness_status"))
            actual_readiness_code = str(pilot_statuses.get("parity_readiness_failure_code", "")).strip()
            if actual_readiness_status != readiness_status:
                add_pilot_issue("parity_readiness_status_mismatch", "pilot_gate_status_mismatch", expected=readiness_status, actual=actual_readiness_status)
            if actual_readiness_code != readiness_code:
                add_pilot_issue("parity_readiness_failure_code_mismatch", "pilot_gate_code_mismatch", expected=readiness_code, actual=actual_readiness_code)

        trend_report = str(pilot_files.get("trend_report_json", "")).strip()
        if compare_previous and trend_report and path_exists(trend_report):
            with Path(trend_report).open("r", encoding="utf-8") as handle:
                trend_data = json.load(handle)
            trend_status = upper(trend_data.get("status"))
            trend_code = str(trend_data.get("primary_regression_code", "")).strip()
            actual_trend_status = upper(pilot_statuses.get("parity_trend_status"))
            actual_trend_code = str(pilot_statuses.get("parity_trend_primary_regression_code", "")).strip()
            if actual_trend_status != trend_status:
                add_pilot_issue("parity_trend_status_mismatch", "pilot_gate_status_mismatch", expected=trend_status, actual=actual_trend_status)
            if actual_trend_code != trend_code:
                add_pilot_issue("parity_trend_primary_regression_code_mismatch", "pilot_gate_code_mismatch", expected=trend_code, actual=actual_trend_code)
    return regressions

status_rank = {
    "FAIL": 0,
    "WARN": 1,
    "INCOMPLETE": 1,
    "SKIP": 1,
    "PASS": 2,
}
review_rank = {
    "investigate_new_frame_shape": 0,
    "promote_baseline": 1,
    "hold_baseline": 2,
}
health_rank = {
    "missing_baseline": 0,
    "invalid_timestamp": 1,
    "missing_history": 2,
    "stale": 3,
    "fresh": 4,
}


def upper(value):
    return str(value or "").upper()


def lower(value):
    return str(value or "").lower()


def rank(mapping, value):
    key = upper(value) if mapping is status_rank else lower(value)
    return mapping.get(key, -1)


def maybe_float(value):
    if value in ("", None):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


current_overall = upper(current.get("overall_status"))
previous_overall = upper(previous.get("overall_status"))
current_review_status = upper((current.get("baseline_review") or {}).get("status"))
previous_review_status = upper((previous.get("baseline_review") or {}).get("status"))
current_review_recommendation = lower((current.get("baseline_review") or {}).get("recommendation"))
previous_review_recommendation = lower((previous.get("baseline_review") or {}).get("recommendation"))
current_health_status = upper((current.get("baseline_health") or {}).get("status"))
previous_health_status = upper((previous.get("baseline_health") or {}).get("status"))
current_health_category = lower((current.get("baseline_health") or {}).get("category"))
previous_health_category = lower((previous.get("baseline_health") or {}).get("category"))
current_age_days = maybe_float((current.get("baseline_health") or {}).get("age_days"))
previous_age_days = maybe_float((previous.get("baseline_health") or {}).get("age_days"))

regressions = []
regressions.extend(validation_chain_regressions(current, "current"))
regressions.extend(validation_chain_regressions(previous, "previous"))

if rank(status_rank, current_overall) < rank(status_rank, previous_overall):
    regressions.append(
        {
            "code": "overall_status_regression",
            "kind": "overall_status_regression",
            "previous": previous_overall,
            "current": current_overall,
        }
    )

if rank(status_rank, current_review_status) < rank(status_rank, previous_review_status):
    regressions.append(
        {
            "code": "baseline_review_status_regression",
            "kind": "baseline_review_status_regression",
            "previous": previous_review_status,
            "current": current_review_status,
        }
    )

if rank(review_rank, current_review_recommendation) < rank(review_rank, previous_review_recommendation):
    regressions.append(
        {
            "code": "baseline_review_recommendation_regression",
            "kind": "baseline_review_recommendation_regression",
            "previous": previous_review_recommendation,
            "current": current_review_recommendation,
        }
    )

if rank(status_rank, current_health_status) < rank(status_rank, previous_health_status):
    regressions.append(
        {
            "code": "baseline_health_status_regression",
            "kind": "baseline_health_status_regression",
            "previous": previous_health_status,
            "current": current_health_status,
        }
    )

if rank(health_rank, current_health_category) < rank(health_rank, previous_health_category):
    regressions.append(
        {
            "code": "baseline_health_category_regression",
            "kind": "baseline_health_category_regression",
            "previous": previous_health_category,
            "current": current_health_category,
        }
    )

gate_deltas = []
all_gates = sorted(set((previous.get("gates") or {}).keys()) | set((current.get("gates") or {}).keys()))
for gate_name in all_gates:
    previous_gate = bool((previous.get("gates") or {}).get(gate_name, False))
    current_gate = bool((current.get("gates") or {}).get(gate_name, False))
    gate_deltas.append(
        {
            "gate": gate_name,
            "previous": previous_gate,
            "current": current_gate,
        }
    )
    if previous_gate and not current_gate:
        regressions.append(
            {
                "code": "gate_regression",
                "kind": "gate_regression",
                "gate": gate_name,
                "previous": previous_gate,
                "current": current_gate,
            }
        )

age_delta = None
if current_age_days is not None and previous_age_days is not None:
    age_delta = round(current_age_days - previous_age_days, 2)
    if age_delta > allow_age_increase:
        regressions.append(
            {
                "code": "baseline_age_increase",
                "kind": "baseline_age_increase",
                "previous": previous_age_days,
                "current": current_age_days,
                "delta": age_delta,
                "allowed_increase_days": allow_age_increase,
            }
        )

status = "PASS" if not regressions else "FAIL"

summary_parts = [
    f"overall {previous_overall or 'missing'} -> {current_overall or 'missing'}",
    (
        "baseline review "
        f"{previous_review_recommendation or 'missing'} -> {current_review_recommendation or 'missing'}"
    ),
    (
        "baseline health "
        f"{previous_health_category or 'missing'} -> {current_health_category or 'missing'}"
    ),
]
if age_delta is not None:
    summary_parts.append(f"baseline age delta {age_delta:.2f}d")
summary = "; ".join(summary_parts)

result = {
    "status": status,
    "summary": summary,
    "current_report_json": str(current_path),
    "previous_report_json": str(previous_path),
    "current": {
        "overall_status": current_overall,
        "baseline_review_status": current_review_status,
        "baseline_review_recommendation": current_review_recommendation,
        "baseline_health_status": current_health_status,
        "baseline_health_category": current_health_category,
        "baseline_health_age_days": current_age_days,
    },
    "previous": {
        "overall_status": previous_overall,
        "baseline_review_status": previous_review_status,
        "baseline_review_recommendation": previous_review_recommendation,
        "baseline_health_status": previous_health_status,
        "baseline_health_category": previous_health_category,
        "baseline_health_age_days": previous_age_days,
    },
    "gate_deltas": gate_deltas,
    "metrics": {
        "baseline_health_age_days": {
            "previous": previous_age_days,
            "current": current_age_days,
            "delta": age_delta,
            "allowed_increase_days": allow_age_increase,
        }
    },
    "primary_regression_code": regressions[0]["code"] if regressions else "",
    "regression_codes": [item["code"] for item in regressions],
    "regressions": regressions,
}

json_out = out_dir / "validation_trend_report.json"
md_out = out_dir / "validation_trend_report.md"
json_out.write_text(json.dumps(result, indent=2), encoding="utf-8")

lines = [
    "# ONYX Listener Validation Trend Report",
    "",
    f"- Status: `{status}`",
    f"- Current validation report: `{current_path}`",
    f"- Previous validation report: `{previous_path}`",
    "",
    "## Summary",
    f"- `{summary}`",
    "",
    "## Status Deltas",
    f"- Overall status: `{previous_overall or 'missing'} -> {current_overall or 'missing'}`",
    (
        "- Baseline review: "
        f"`{previous_review_status or 'missing'} / {previous_review_recommendation or 'missing'} -> "
        f"{current_review_status or 'missing'} / {current_review_recommendation or 'missing'}`"
    ),
    (
        "- Baseline health: "
        f"`{previous_health_status or 'missing'} / {previous_health_category or 'missing'} -> "
        f"{current_health_status or 'missing'} / {current_health_category or 'missing'}`"
    ),
]
if age_delta is not None:
    lines.append(
        "- Baseline age: "
        f"`{previous_age_days:.2f}d -> {current_age_days:.2f}d` "
        f"(delta `{age_delta:.2f}d`, allowed increase `{allow_age_increase:.2f}d`)"
    )
else:
    lines.append("- Baseline age: `n/a`")

lines.extend(["", "## Gate Deltas"])
if gate_deltas:
    for gate in gate_deltas:
        lines.append(f"- `{gate['gate']}`: `{gate['previous']} -> {gate['current']}`")
else:
    lines.append("- None")

lines.extend(["", "## Regressions"])
if regressions:
    for item in regressions:
        if item["kind"] == "gate_regression":
            lines.append(
                f"- `{item['code']}` on `{item['gate']}`: `{item['previous']} -> {item['current']}`"
            )
        elif item["kind"] == "validation_chain_missing_file":
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` validation missing "
                f"`{item['missing_field']}` at `{item['missing_path']}`"
            )
        elif item["kind"] == "validation_chain_missing_metadata":
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` validation missing "
                f"path metadata for `{item['missing_field']}` while checksum "
                f"`{item['missing_checksum_field']}` is set"
            )
        elif item["kind"] == "validation_chain_missing_checksum":
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` validation missing "
                f"checksum metadata `{item['missing_checksum_field']}` for "
                f"`{item['missing_field']}`"
            )
        elif item["kind"] == "validation_chain_checksum_mismatch":
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` validation "
                f"`{item['mismatch_field']}` checksum mismatch at `{item['path']}`"
            )
        elif item["kind"] == "validation_chain_missing_dir":
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` validation missing "
                f"artifact dir `{item['missing_path']}`"
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
        elif item["kind"] == "pilot_gate_missing_file":
            suffix = f" at `{item['missing_path']}`" if item["missing_path"] else ""
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` pilot gate missing "
                f"`{item['missing_field']}`{suffix}"
            )
        elif item["kind"] in {"pilot_gate_status_mismatch", "pilot_gate_code_mismatch"}:
            lines.append(
                f"- `{item['code']}`: `{item['report_label']}` pilot gate expected "
                f"`{item['expected'] or 'missing'}` but saw `{item['actual'] or 'missing'}`"
            )
        elif item["kind"] == "baseline_age_increase":
            lines.append(
                f"- `{item['code']}`: `{item['previous']:.2f}d -> {item['current']:.2f}d` "
                f"(delta `{item['delta']:.2f}d`, allowed `{item['allowed_increase_days']:.2f}d`)"
            )
        else:
            lines.append(
                f"- `{item['code']}`: `{item['previous'] or 'missing'} -> {item['current'] or 'missing'}`"
            )
else:
    lines.append("- None")

md_out.write_text("\n".join(lines) + "\n", encoding="utf-8")

print(f"Validation trend artifact: {json_out}")
print(f"Validation trend markdown: {md_out}")
print(f"Status: {status}")

if regressions:
    for item in regressions:
        if item["kind"] == "gate_regression":
            print(f"REGRESSION: {item['code']}:{item['gate']} {item['previous']} -> {item['current']}")
        elif item["kind"] == "validation_chain_missing_file":
            print(
                f"REGRESSION: {item['code']} {item['report_label']} missing "
                f"{item['missing_field']} at {item['missing_path']}"
            )
        elif item["kind"] == "validation_chain_missing_metadata":
            print(
                f"REGRESSION: {item['code']} {item['report_label']} missing path "
                f"for {item['missing_field']} while {item['missing_checksum_field']} is set"
            )
        elif item["kind"] == "validation_chain_missing_checksum":
            print(
                f"REGRESSION: {item['code']} {item['report_label']} missing "
                f"checksum {item['missing_checksum_field']} for {item['missing_field']}"
            )
        elif item["kind"] == "validation_chain_checksum_mismatch":
            print(
                f"REGRESSION: {item['code']} {item['report_label']} checksum "
                f"mismatch for {item['mismatch_field']} at {item['path']}"
            )
        elif item["kind"] == "validation_chain_missing_dir":
            print(
                f"REGRESSION: {item['code']} {item['report_label']} missing artifact dir "
                f"{item['missing_path']}"
            )
        elif item["kind"] == "validation_summary_mismatch":
            print(
                f"REGRESSION: {item['code']} {item['report_label']} expected "
                f"{item['summary_field']}={item['expected'] or 'missing'} "
                f"but saw {item['actual'] or 'missing'}"
            )
        elif item["kind"] == "validation_status_gate_mismatch":
            print(
                f"REGRESSION: {item['code']} {item['report_label']} gate "
                f"{item['gate_field']}={item['actual']} but {item['status_field']}={item['status'] or 'missing'}"
            )
        elif item["kind"] == "validation_primary_code_mismatch":
            print(
                f"REGRESSION: {item['code']} {item['report_label']} expected "
                f"{item['summary_field']}={item['expected'] or 'missing'} "
                f"but saw {item['actual'] or 'missing'}"
            )
        elif item["kind"] == "pilot_gate_missing_file":
            suffix = f" at {item['missing_path']}" if item["missing_path"] else ""
            print(
                f"REGRESSION: {item['code']} {item['report_label']} pilot gate missing "
                f"{item['missing_field']}{suffix}"
            )
        elif item["kind"] in {"pilot_gate_status_mismatch", "pilot_gate_code_mismatch"}:
            print(
                f"REGRESSION: {item['code']} {item['report_label']} pilot gate expected "
                f"{item['expected'] or 'missing'} but saw {item['actual'] or 'missing'}"
            )
        else:
            print(f"REGRESSION: {item['code']} {item.get('previous')} -> {item.get('current')}")
    sys.exit(1)
PY
