#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REPORT_JSON=""
MAX_REPORT_AGE_HOURS=24
REQUIRE_REAL_ARTIFACTS=0
JSON_OUT=""
MARKDOWN_OUT=""
ARTIFACT_DIR=""
REPORT_AGE_HOURS=""
OVERALL_STATUS=""
BENCH_BASELINE_JSON=""
REQUIRE_TREND_PASS=0
VALIDATION_TREND_REPORT_JSON=""
REQUIRE_VALIDATION_TREND_PASS=0
CUTOVER_DECISION_JSON=""
REQUIRE_CUTOVER_GO=0
CUTOVER_TREND_REPORT_JSON=""
REQUIRE_CUTOVER_TREND_PASS=0
RELEASE_GATE_JSON=""
REQUIRE_RELEASE_GATE_PASS=0
RELEASE_TREND_REPORT_JSON=""
REQUIRE_RELEASE_TREND_PASS=0
REQUIRE_BASELINE_HISTORY=0
MAX_BASELINE_AGE_DAYS=""

pass() { printf "PASS: %s\n" "$1"; }

write_readiness_report() {
  [[ -n "${JSON_OUT:-}" ]] || return 0
  [[ -n "${MARKDOWN_OUT:-}" ]] || MARKDOWN_OUT="$(dirname "$JSON_OUT")/readiness_report.md"

  mkdir -p "$(dirname "$JSON_OUT")"
  mkdir -p "$(dirname "$MARKDOWN_OUT")"

  python3 - "$JSON_OUT" "$MARKDOWN_OUT" "${READINESS_STATUS:-FAIL}" "${READINESS_SUMMARY:-Listener readiness failed.}" "${REPORT_JSON:-}" "${ARTIFACT_DIR:-}" "${REPORT_AGE_HOURS:-}" "${OVERALL_STATUS:-}" "$REQUIRE_REAL_ARTIFACTS" "$REQUIRE_TREND_PASS" "$REQUIRE_VALIDATION_TREND_PASS" "$REQUIRE_CUTOVER_GO" "$REQUIRE_CUTOVER_TREND_PASS" "$REQUIRE_RELEASE_GATE_PASS" "$REQUIRE_RELEASE_TREND_PASS" "$REQUIRE_BASELINE_HISTORY" "${MAX_BASELINE_AGE_DAYS:-}" "${VALIDATION_TREND_REPORT_JSON:-}" "${CUTOVER_DECISION_JSON:-}" "${CUTOVER_TREND_REPORT_JSON:-}" "${RELEASE_GATE_JSON:-}" "${RELEASE_TREND_REPORT_JSON:-}" "${BENCH_BASELINE_JSON:-}" <<'PY'
import json
import sys
from pathlib import Path

json_out = Path(sys.argv[1])
md_out = Path(sys.argv[2])
status = sys.argv[3]
summary = sys.argv[4]
validation_report_json = sys.argv[5]
artifact_dir = sys.argv[6]
report_age_hours_raw = sys.argv[7]
overall_status = sys.argv[8]

def as_bool(raw: str) -> bool:
    return raw == "1"

require_real_artifacts = as_bool(sys.argv[9])
require_trend_pass = as_bool(sys.argv[10])
require_validation_trend_pass = as_bool(sys.argv[11])
require_cutover_go = as_bool(sys.argv[12])
require_cutover_trend_pass = as_bool(sys.argv[13])
require_release_gate_pass = as_bool(sys.argv[14])
require_release_trend_pass = as_bool(sys.argv[15])
require_baseline_history = as_bool(sys.argv[16])
max_baseline_age_days = sys.argv[17]
validation_trend_report_json = sys.argv[18]
cutover_decision_json = sys.argv[19]
cutover_trend_report_json = sys.argv[20]
release_gate_json = sys.argv[21]
release_trend_report_json = sys.argv[22]
bench_baseline_json = sys.argv[23]

report_age_hours = None
if report_age_hours_raw:
    try:
        report_age_hours = round(float(report_age_hours_raw), 2)
    except ValueError:
        report_age_hours = None

payload = {
    "status": status,
    "summary": summary,
    "validation_report_json": validation_report_json,
    "artifact_dir": artifact_dir,
    "report_age_hours": report_age_hours,
    "statuses": {
        "validation_overall_status": overall_status,
    },
    "requirements": {
        "require_real_artifacts": require_real_artifacts,
        "require_trend_pass": require_trend_pass,
        "require_validation_trend_pass": require_validation_trend_pass,
        "require_cutover_go": require_cutover_go,
        "require_cutover_trend_pass": require_cutover_trend_pass,
        "require_release_gate_pass": require_release_gate_pass,
        "require_release_trend_pass": require_release_trend_pass,
        "require_baseline_history": require_baseline_history,
        "max_baseline_age_days": max_baseline_age_days,
    },
    "resolved_files": {
        "validation_trend_report_json": validation_trend_report_json,
        "cutover_decision_json": cutover_decision_json,
        "cutover_trend_report_json": cutover_trend_report_json,
        "release_gate_json": release_gate_json,
        "release_trend_report_json": release_trend_report_json,
        "bench_baseline_json": bench_baseline_json,
    },
}

json_out.write_text(json.dumps(payload, indent=2), encoding="utf-8")

age_display = f"{report_age_hours:.2f}" if report_age_hours is not None else "n/a"
lines = [
    "# ONYX Listener Readiness Report",
    "",
    f"- Status: `{status}`",
    f"- Summary: `{summary}`",
    f"- Validation report: `{validation_report_json or 'n/a'}`",
    f"- Artifact dir: `{artifact_dir or 'n/a'}`",
    f"- Report age hours: `{age_display}`",
    "",
    "## Requirements",
    f"- Require real artifacts: `{require_real_artifacts}`",
    f"- Require trend pass: `{require_trend_pass}`",
    f"- Require validation trend pass: `{require_validation_trend_pass}`",
    f"- Require cutover GO: `{require_cutover_go}`",
    f"- Require cutover trend pass: `{require_cutover_trend_pass}`",
    f"- Require release gate pass: `{require_release_gate_pass}`",
    f"- Require release trend pass: `{require_release_trend_pass}`",
    f"- Require baseline history: `{require_baseline_history}`",
    f"- Max baseline age days: `{max_baseline_age_days or 'disabled'}`",
    "",
    "## Resolved Files",
    f"- Validation trend report JSON: `{validation_trend_report_json or 'n/a'}`",
    f"- Cutover decision JSON: `{cutover_decision_json or 'n/a'}`",
    f"- Cutover trend report JSON: `{cutover_trend_report_json or 'n/a'}`",
    f"- Release gate JSON: `{release_gate_json or 'n/a'}`",
    f"- Release trend report JSON: `{release_trend_report_json or 'n/a'}`",
    f"- Bench baseline JSON: `{bench_baseline_json or 'n/a'}`",
]
md_out.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

fail() {
  READINESS_STATUS="FAIL"
  READINESS_SUMMARY="$1"
  write_readiness_report
  printf "FAIL: %s\n" "$1"
  exit 1
}

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_pilot_readiness_check.sh [--report-json <path>] [--max-report-age-hours <hours>] [--json-out <path>] [--markdown-out <path>] [--require-real-artifacts] [--require-trend-pass] [--validation-trend-report-json <path>] [--require-validation-trend-pass] [--cutover-decision-json <path>] [--require-cutover-go] [--cutover-trend-report-json <path>] [--require-cutover-trend-pass] [--release-gate-json <path>] [--require-release-gate-pass] [--release-trend-report-json <path>] [--require-release-trend-pass] [--require-baseline-history] [--max-baseline-age-days <days>]

Purpose:
  Validate the latest listener field-validation artifact under
  tmp/listener_field_validation/ and fail if the evidence bundle is stale,
  incomplete, or corrupted.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report-json)
      REPORT_JSON="${2:-}"
      shift 2
      ;;
    --max-report-age-hours)
      MAX_REPORT_AGE_HOURS="${2:-}"
      shift 2
      ;;
    --json-out)
      JSON_OUT="${2:-}"
      shift 2
      ;;
    --markdown-out)
      MARKDOWN_OUT="${2:-}"
      shift 2
      ;;
    --require-real-artifacts)
      REQUIRE_REAL_ARTIFACTS=1
      shift
      ;;
    --require-trend-pass)
      REQUIRE_TREND_PASS=1
      shift
      ;;
    --validation-trend-report-json)
      VALIDATION_TREND_REPORT_JSON="${2:-}"
      shift 2
      ;;
    --require-validation-trend-pass)
      REQUIRE_VALIDATION_TREND_PASS=1
      shift
      ;;
    --cutover-decision-json)
      CUTOVER_DECISION_JSON="${2:-}"
      shift 2
      ;;
    --require-cutover-go)
      REQUIRE_CUTOVER_GO=1
      shift
      ;;
    --cutover-trend-report-json)
      CUTOVER_TREND_REPORT_JSON="${2:-}"
      shift 2
      ;;
    --require-cutover-trend-pass)
      REQUIRE_CUTOVER_TREND_PASS=1
      shift
      ;;
    --release-gate-json)
      RELEASE_GATE_JSON="${2:-}"
      shift 2
      ;;
    --require-release-gate-pass)
      REQUIRE_RELEASE_GATE_PASS=1
      shift
      ;;
    --release-trend-report-json)
      RELEASE_TREND_REPORT_JSON="${2:-}"
      shift 2
      ;;
    --require-release-trend-pass)
      REQUIRE_RELEASE_TREND_PASS=1
      shift
      ;;
    --require-baseline-history)
      REQUIRE_BASELINE_HISTORY=1
      shift
      ;;
    --max-baseline-age-days)
      MAX_BASELINE_AGE_DAYS="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

if ! [[ "$MAX_REPORT_AGE_HOURS" =~ ^[0-9]+$ ]]; then
  fail "--max-report-age-hours must be a non-negative integer."
fi
if [[ -n "$MAX_BASELINE_AGE_DAYS" ]] && ! [[ "$MAX_BASELINE_AGE_DAYS" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  fail "--max-baseline-age-days must be a non-negative number."
fi
if [[ "$REQUIRE_REAL_ARTIFACTS" -eq 1 ]]; then
  REQUIRE_BASELINE_HISTORY=1
fi

latest_validation_report_json() {
  local base_dir="tmp/listener_field_validation"
  if [[ ! -d "$base_dir" ]]; then
    return 1
  fi
  find "$base_dir" -type f -name "validation_report.json" -print0 2>/dev/null \
    | xargs -0 ls -1t 2>/dev/null \
    | head -n 1
}

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
    if not isinstance(value, dict):
        value = ""
        break
    value = value.get(key, "")
if isinstance(value, bool):
    print("true" if value else "false")
elif value is None:
    print("")
else:
    print(value)
PY
}

report_age_hours() {
  local report_file="$1"
  python3 - "$report_file" <<'PY'
import os
import sys
import time
path = sys.argv[1]
age_hours = (time.time() - os.path.getmtime(path)) / 3600.0
print(f"{age_hours:.2f}")
PY
}

verify_json_report_checksums() {
  local report_file="$1"
  python3 - "$report_file" <<'PY'
import hashlib
import json
import os
import sys

report_file = sys.argv[1]
with open(report_file, "r", encoding="utf-8") as handle:
    data = json.load(handle)

files = data.get("files", {})
checksums = data.get("checksums", {})
artifact_dir = data.get("artifact_dir", "")

pairs = [
    ("serial_capture", "serial_capture_sha256"),
    ("serial_parsed_json", "serial_parsed_json_sha256"),
    ("bench_baseline_json", "bench_baseline_json_sha256"),
    ("baseline_review_json", "baseline_review_json_sha256"),
    ("baseline_health_json", "baseline_health_json_sha256"),
    ("legacy_capture", "legacy_capture_sha256"),
    ("field_notes", "field_notes_sha256"),
    ("parity_report_json", "parity_report_json_sha256"),
    ("parity_report_markdown", "parity_report_markdown_sha256"),
    ("trend_report_json", "trend_report_json_sha256"),
    ("trend_report_markdown", "trend_report_markdown_sha256"),
    ("pilot_gate_output", "pilot_gate_output_sha256"),
    ("markdown_report", "markdown_report_sha256"),
]

for file_key, checksum_key in pairs:
    path = files.get(file_key, "")
    expected = checksums.get(checksum_key, "")
    if not path or not expected:
        continue
    if not os.path.isfile(path):
        raise SystemExit(f"missing:{file_key}:{path}")
    digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
    if digest != expected:
        raise SystemExit(f"checksum:{file_key}:{path}")

if artifact_dir and not os.path.isdir(artifact_dir):
    raise SystemExit(f"artifact_dir:{artifact_dir}")

print("ok")
PY
}

verify_baseline_history() {
  local baseline_file="$1"
  local max_age_days="${2:-}"
  python3 - "$baseline_file" "$max_age_days" <<'PY'
import json
import sys
import time
from datetime import datetime, timezone

baseline_file = sys.argv[1]
max_age_days_raw = sys.argv[2].strip()

with open(baseline_file, "r", encoding="utf-8") as handle:
    data = json.load(handle)

history = data.get("promotion_history")
if not isinstance(history, list) or len(history) == 0:
    raise SystemExit("missing_history")

last_promoted = str(data.get("last_promoted_at_utc") or "").strip()
if not last_promoted:
    last_promoted = str(history[-1].get("promoted_at_utc") or "").strip()
if not last_promoted:
    raise SystemExit("missing_last_promoted_at")

try:
    promoted_at = datetime.fromisoformat(last_promoted.replace("Z", "+00:00"))
except ValueError as exc:
    raise SystemExit("invalid_last_promoted_at") from exc
if promoted_at.tzinfo is None:
    promoted_at = promoted_at.replace(tzinfo=timezone.utc)
promoted_at = promoted_at.astimezone(timezone.utc)

if max_age_days_raw:
    max_age_days = float(max_age_days_raw)
    age_days = max((time.time() - promoted_at.timestamp()) / 86400.0, 0.0)
    if age_days > max_age_days:
        raise SystemExit(f"stale:{age_days:.2f}")

print(last_promoted)
PY
}

verify_validation_trend_report() {
  local report_file="$1"
  python3 - "$report_file" <<'PY'
import json
import os
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)

status = str(data.get("status", "")).upper()
current_report = str(data.get("current_report_json", "")).strip()
previous_report = str(data.get("previous_report_json", "")).strip()

if not current_report or not os.path.isfile(current_report):
    raise SystemExit("missing_current_report")
if not previous_report or not os.path.isfile(previous_report):
    raise SystemExit("missing_previous_report")

print(status)
PY
}

verify_cutover_decision_report() {
  local report_file="$1"
  python3 - "$report_file" <<'PY'
import json
import os
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)

decision = str(data.get("decision", "")).upper()
validation_report = str(data.get("validation_report_json", "")).strip()
if not validation_report or not os.path.isfile(validation_report):
    raise SystemExit("missing_validation_report")

print(decision)
PY
}

verify_cutover_trend_report() {
  local report_file="$1"
  python3 - "$report_file" <<'PY'
import json
import os
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)

status = str(data.get("status", "")).upper()
current_decision = str(data.get("current_decision_json", "")).strip()
previous_decision = str(data.get("previous_decision_json", "")).strip()

if not current_decision or not os.path.isfile(current_decision):
    raise SystemExit("missing_current_decision")
if not previous_decision or not os.path.isfile(previous_decision):
    raise SystemExit("missing_previous_decision")

print(status)
PY
}

verify_release_gate_report() {
  local report_file="$1"
  python3 - "$report_file" <<'PY'
import json
import os
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)

result = str(data.get("result", "")).upper()
validation_report = str(data.get("validation_report_json", "")).strip()

if not validation_report or not os.path.isfile(validation_report):
    raise SystemExit("missing_validation_report")

print(result)
PY
}

verify_release_trend_report() {
  local report_file="$1"
  python3 - "$report_file" <<'PY'
import json
import os
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)

status = str(data.get("status", "")).upper()
current_gate = str(data.get("current_release_gate_json", "")).strip()
previous_gate = str(data.get("previous_release_gate_json", "")).strip()

if not current_gate or not os.path.isfile(current_gate):
    raise SystemExit("missing_current_release_gate")
if not previous_gate or not os.path.isfile(previous_gate):
    raise SystemExit("missing_previous_release_gate")

print(status)
PY
}

latest_report_json="$REPORT_JSON"
if [[ -z "$latest_report_json" ]]; then
  latest_report_json="$(latest_validation_report_json || true)"
fi
if [[ -z "$latest_report_json" || ! -f "$latest_report_json" ]]; then
  fail "No listener validation_report.json found under tmp/listener_field_validation."
fi

if [[ -z "$JSON_OUT" ]]; then
  candidate_dir="$(dirname "$latest_report_json")"
  JSON_OUT="$candidate_dir/readiness_report.json"
fi
if [[ -z "$MARKDOWN_OUT" ]]; then
  MARKDOWN_OUT="$(dirname "$JSON_OUT")/readiness_report.md"
fi

if [[ -z "$VALIDATION_TREND_REPORT_JSON" ]]; then
  candidate_dir="$(dirname "$latest_report_json")"
  if [[ -f "$candidate_dir/validation_trend_report.json" ]]; then
    VALIDATION_TREND_REPORT_JSON="$candidate_dir/validation_trend_report.json"
  fi
fi
if [[ -z "$CUTOVER_DECISION_JSON" ]]; then
  candidate_dir="$(dirname "$latest_report_json")"
  if [[ -f "$candidate_dir/cutover_decision.json" ]]; then
    CUTOVER_DECISION_JSON="$candidate_dir/cutover_decision.json"
  fi
fi
if [[ -z "$CUTOVER_TREND_REPORT_JSON" ]]; then
  candidate_dir="$(dirname "$latest_report_json")"
  if [[ -f "$candidate_dir/cutover_trend_report.json" ]]; then
    CUTOVER_TREND_REPORT_JSON="$candidate_dir/cutover_trend_report.json"
  fi
fi
if [[ -z "$RELEASE_GATE_JSON" ]]; then
  candidate_dir="$(dirname "$latest_report_json")"
  if [[ -f "$candidate_dir/release_gate.json" ]]; then
    RELEASE_GATE_JSON="$candidate_dir/release_gate.json"
  fi
fi
if [[ -z "$RELEASE_TREND_REPORT_JSON" ]]; then
  candidate_dir="$(dirname "$latest_report_json")"
  if [[ -f "$candidate_dir/release_trend_report.json" ]]; then
    RELEASE_TREND_REPORT_JSON="$candidate_dir/release_trend_report.json"
  fi
fi

report_age="$(report_age_hours "$latest_report_json")"
if ! python3 - "$report_age" "$MAX_REPORT_AGE_HOURS" <<'PY'
import sys
age = float(sys.argv[1])
max_age = float(sys.argv[2])
raise SystemExit(0 if age <= max_age else 1)
PY
then
  fail "Latest listener validation report is stale (${report_age}h old > ${MAX_REPORT_AGE_HOURS}h)."
fi

OVERALL_STATUS="$(json_get "$latest_report_json" "overall_status" | tr '[:lower:]' '[:upper:]')"
ARTIFACT_DIR="$(json_get "$latest_report_json" "artifact_dir")"
is_mock="$(json_get "$latest_report_json" "is_mock" | tr '[:upper:]' '[:lower:]')"
BENCH_BASELINE_JSON="$(json_get "$latest_report_json" "files.bench_baseline_json")"
serial_capture_present="$(json_get "$latest_report_json" "gates.serial_capture_present" | tr '[:upper:]' '[:lower:]')"
legacy_capture_present="$(json_get "$latest_report_json" "gates.legacy_capture_present" | tr '[:upper:]' '[:lower:]')"
field_notes_present="$(json_get "$latest_report_json" "gates.field_notes_present" | tr '[:upper:]' '[:lower:]')"
read_only_wiring_documented="$(json_get "$latest_report_json" "gates.read_only_wiring_documented" | tr '[:upper:]' '[:lower:]')"
bench_anomaly_gate_passed="$(json_get "$latest_report_json" "gates.bench_anomaly_gate_passed" | tr '[:upper:]' '[:lower:]')"
parity_gate_passed="$(json_get "$latest_report_json" "gates.parity_gate_passed" | tr '[:upper:]' '[:lower:]')"
trend_gate_passed="$(json_get "$latest_report_json" "gates.trend_gate_passed" | tr '[:upper:]' '[:lower:]')"
REPORT_JSON="$latest_report_json"
REPORT_AGE_HOURS="$report_age"
verify_result="$(verify_json_report_checksums "$latest_report_json")" || fail "Listener validation checksum verification failed: $verify_result"
pass "Listener validation checksums verified."

if [[ "$REQUIRE_REAL_ARTIFACTS" -eq 1 ]]; then
  if [[ "$is_mock" == "true" || "$ARTIFACT_DIR" == *"/mock-"* || "$ARTIFACT_DIR" == mock-* || "$ARTIFACT_DIR" == *"/mock-pass"* || "$ARTIFACT_DIR" == mock-pass* ]]; then
    fail "Listener readiness failed: mock artifact directory is not allowed under --require-real-artifacts ($ARTIFACT_DIR)."
  fi
  pass "Real-artifact gate passed ($ARTIFACT_DIR)."
fi

if [[ "$REQUIRE_VALIDATION_TREND_PASS" -eq 1 ]]; then
  [[ -n "$VALIDATION_TREND_REPORT_JSON" && -f "$VALIDATION_TREND_REPORT_JSON" ]] || fail "Listener readiness failed: validation trend report is missing under --require-validation-trend-pass."
  validation_trend_status="$(verify_validation_trend_report "$VALIDATION_TREND_REPORT_JSON" 2>&1)" || {
    case "$validation_trend_status" in
      missing_current_report)
        fail "Listener readiness failed: validation trend report references a missing current validation report."
        ;;
      missing_previous_report)
        fail "Listener readiness failed: validation trend report references a missing previous validation report."
        ;;
      *)
        fail "Listener readiness failed: validation trend verification failed: ${validation_trend_status:-unknown}."
        ;;
    esac
  }
  [[ "$validation_trend_status" == "PASS" ]] || fail "Listener readiness failed: validation trend report is not PASS (${validation_trend_status:-missing})."
  pass "Validation trend gate passed ($VALIDATION_TREND_REPORT_JSON)."
fi

if [[ "$REQUIRE_CUTOVER_GO" -eq 1 ]]; then
  [[ -n "$CUTOVER_DECISION_JSON" && -f "$CUTOVER_DECISION_JSON" ]] || fail "Listener readiness failed: cutover decision report is missing under --require-cutover-go."
  cutover_decision_status="$(verify_cutover_decision_report "$CUTOVER_DECISION_JSON" 2>&1)" || {
    case "$cutover_decision_status" in
      missing_validation_report)
        fail "Listener readiness failed: cutover decision references a missing validation report."
        ;;
      *)
        fail "Listener readiness failed: cutover decision verification failed: ${cutover_decision_status:-unknown}."
        ;;
    esac
  }
  [[ "$cutover_decision_status" == "GO" ]] || fail "Listener readiness failed: cutover decision is not GO (${cutover_decision_status:-missing})."
  pass "Cutover decision gate passed ($CUTOVER_DECISION_JSON)."
fi

if [[ "$REQUIRE_CUTOVER_TREND_PASS" -eq 1 ]]; then
  [[ -n "$CUTOVER_TREND_REPORT_JSON" && -f "$CUTOVER_TREND_REPORT_JSON" ]] || fail "Listener readiness failed: cutover trend report is missing under --require-cutover-trend-pass."
  cutover_trend_status="$(verify_cutover_trend_report "$CUTOVER_TREND_REPORT_JSON" 2>&1)" || {
    case "$cutover_trend_status" in
      missing_current_decision)
        fail "Listener readiness failed: cutover trend report references a missing current cutover decision."
        ;;
      missing_previous_decision)
        fail "Listener readiness failed: cutover trend report references a missing previous cutover decision."
        ;;
      *)
        fail "Listener readiness failed: cutover trend verification failed: ${cutover_trend_status:-unknown}."
        ;;
    esac
  }
  [[ "$cutover_trend_status" == "PASS" ]] || fail "Listener readiness failed: cutover trend report is not PASS (${cutover_trend_status:-missing})."
  pass "Cutover trend gate passed ($CUTOVER_TREND_REPORT_JSON)."
fi

if [[ "$REQUIRE_RELEASE_GATE_PASS" -eq 1 ]]; then
  [[ -n "$RELEASE_GATE_JSON" && -f "$RELEASE_GATE_JSON" ]] || fail "Listener readiness failed: release gate report is missing under --require-release-gate-pass."
  release_gate_status="$(verify_release_gate_report "$RELEASE_GATE_JSON" 2>&1)" || {
    case "$release_gate_status" in
      missing_validation_report)
        fail "Listener readiness failed: release gate references a missing validation report."
        ;;
      *)
        fail "Listener readiness failed: release gate verification failed: ${release_gate_status:-unknown}."
        ;;
    esac
  }
  [[ "$release_gate_status" == "PASS" ]] || fail "Listener readiness failed: release gate is not PASS (${release_gate_status:-missing})."
  pass "Release gate passed ($RELEASE_GATE_JSON)."
fi

if [[ "$REQUIRE_RELEASE_TREND_PASS" -eq 1 ]]; then
  [[ -n "$RELEASE_TREND_REPORT_JSON" && -f "$RELEASE_TREND_REPORT_JSON" ]] || fail "Listener readiness failed: release trend report is missing under --require-release-trend-pass."
  release_trend_status="$(verify_release_trend_report "$RELEASE_TREND_REPORT_JSON" 2>&1)" || {
    case "$release_trend_status" in
      missing_current_release_gate)
        fail "Listener readiness failed: release trend report references a missing current release gate."
        ;;
      missing_previous_release_gate)
        fail "Listener readiness failed: release trend report references a missing previous release gate."
        ;;
      *)
        fail "Listener readiness failed: release trend verification failed: ${release_trend_status:-unknown}."
        ;;
    esac
  }
  [[ "$release_trend_status" == "PASS" ]] || fail "Listener readiness failed: release trend report is not PASS (${release_trend_status:-missing})."
  pass "Release trend gate passed ($RELEASE_TREND_REPORT_JSON)."
fi

if [[ "$REQUIRE_BASELINE_HISTORY" -eq 1 ]]; then
  [[ -n "$BENCH_BASELINE_JSON" && -f "$BENCH_BASELINE_JSON" ]] || fail "Listener readiness failed: bench baseline JSON is missing under --require-baseline-history."
  baseline_history_result="$(verify_baseline_history "$BENCH_BASELINE_JSON" "$MAX_BASELINE_AGE_DAYS" 2>&1)" || {
    case "$baseline_history_result" in
      missing_history)
        fail "Listener readiness failed: bench baseline has no promotion_history."
        ;;
      missing_last_promoted_at)
        fail "Listener readiness failed: bench baseline has no last_promoted_at_utc."
        ;;
      invalid_last_promoted_at)
        fail "Listener readiness failed: bench baseline last_promoted_at_utc is invalid."
        ;;
      stale:*)
        age_days="${baseline_history_result#stale:}"
        fail "Listener readiness failed: bench baseline is stale (${age_days}d old > ${MAX_BASELINE_AGE_DAYS}d)."
        ;;
      *)
        fail "Listener readiness failed: bench baseline history verification failed: ${baseline_history_result:-unknown}."
        ;;
    esac
  }
  if [[ -n "$MAX_BASELINE_AGE_DAYS" ]]; then
    pass "Bench baseline freshness gate passed ($baseline_history_result)."
  else
    pass "Bench baseline history gate passed ($baseline_history_result)."
  fi
fi

[[ "$serial_capture_present" == "true" ]] || fail "Listener readiness failed: serial capture gate is not true."
[[ "$legacy_capture_present" == "true" ]] || fail "Listener readiness failed: legacy capture gate is not true."
[[ "$field_notes_present" == "true" ]] || fail "Listener readiness failed: field notes gate is not true."
[[ "$read_only_wiring_documented" == "true" ]] || fail "Listener readiness failed: read-only wiring gate is not true."
[[ "$bench_anomaly_gate_passed" == "true" ]] || fail "Listener readiness failed: bench anomaly gate is not true."
[[ "$parity_gate_passed" == "true" ]] || fail "Listener readiness failed: parity gate is not true."
if [[ "$REQUIRE_TREND_PASS" -eq 1 ]]; then
  [[ "$trend_gate_passed" == "true" ]] || fail "Listener readiness failed: trend gate is not true."
fi
[[ "$OVERALL_STATUS" == "PASS" ]] || fail "Listener readiness failed: overall status is $OVERALL_STATUS, expected PASS."

READINESS_STATUS="PASS"
READINESS_SUMMARY="Listener readiness checks passed."
write_readiness_report
pass "Listener readiness report written ($JSON_OUT)."

pass "Listener readiness passed ($latest_report_json)."
