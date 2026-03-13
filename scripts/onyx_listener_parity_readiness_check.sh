#!/usr/bin/env bash
set -euo pipefail

REPORT_JSON=""
JSON_OUT=""
MARKDOWN_OUT=""
MAX_REPORT_AGE_HOURS=24
MIN_MATCH_RATE_PERCENT=95
MAX_OBSERVED_SKEW_SECONDS=""
ALLOW_DRIFT_REASONS=()
MAX_DRIFT_REASON_COUNTS=()
ALLOW_UNMATCHED_SERIAL=0
ALLOW_UNMATCHED_LEGACY=0
REQUIRE_REAL_ARTIFACTS=0
INTEGRITY_CERTIFICATE_JSON=""
INTEGRITY_CERTIFICATE_MD=""
INTEGRITY_CERTIFICATE_STATUS=""

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/onyx_listener_parity_readiness_check.sh [--report-json <path>] [--json-out <path>] [--markdown-out <path>] [--max-report-age-hours 24] [--min-match-rate-percent 95] [--max-observed-skew-seconds <n>] [--allow-drift-reason <reason>]... [--max-drift-reason-count <reason=count>]... [--allow-unmatched-serial] [--allow-unmatched-legacy] [--require-real-artifacts]

Purpose:
  Validate the latest listener parity report and fail when the dual-path pilot
  evidence is stale, corrupted, or still diverging beyond the allowed gates.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --report-json)
      REPORT_JSON="${2:-}"
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
    --max-report-age-hours)
      MAX_REPORT_AGE_HOURS="${2:-24}"
      shift 2
      ;;
    --min-match-rate-percent)
      MIN_MATCH_RATE_PERCENT="${2:-95}"
      shift 2
      ;;
    --max-observed-skew-seconds)
      MAX_OBSERVED_SKEW_SECONDS="${2:-}"
      shift 2
      ;;
    --allow-drift-reason)
      ALLOW_DRIFT_REASONS+=("${2:-}")
      shift 2
      ;;
    --max-drift-reason-count)
      MAX_DRIFT_REASON_COUNTS+=("${2:-}")
      shift 2
      ;;
    --allow-unmatched-serial)
      ALLOW_UNMATCHED_SERIAL=1
      shift
      ;;
    --allow-unmatched-legacy)
      ALLOW_UNMATCHED_LEGACY=1
      shift
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

READINESS_STATUS="FAIL"
READINESS_SUMMARY="Listener parity readiness failed."
READINESS_FAILURE_CODE=""
artifact_dir=""
report_age=""
matched_count=""
unmatched_serial_count=""
unmatched_legacy_count=""
match_rate_percent=""
min_required_match_rate_percent=""
max_skew_seconds_observed=""
summary=""
drift_reason_counts=""

if ! [[ "$MAX_REPORT_AGE_HOURS" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --max-report-age-hours must be a non-negative integer."
  exit 1
fi
if ! [[ "$MIN_MATCH_RATE_PERCENT" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  echo "FAIL: --min-match-rate-percent must be a non-negative number."
  exit 1
fi
if [[ -n "$MAX_OBSERVED_SKEW_SECONDS" ]] && ! [[ "$MAX_OBSERVED_SKEW_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "FAIL: --max-observed-skew-seconds must be a non-negative integer."
  exit 1
fi
for allow_reason in "${ALLOW_DRIFT_REASONS[@]-}"; do
  if [[ -z "$allow_reason" ]]; then
    continue
  fi
  if [[ -z "$allow_reason" ]]; then
    echo "FAIL: --allow-drift-reason requires a non-empty value."
    exit 1
  fi
done
for drift_cap in "${MAX_DRIFT_REASON_COUNTS[@]-}"; do
  if [[ -z "$drift_cap" ]]; then
    continue
  fi
  if ! [[ "$drift_cap" =~ ^[A-Za-z0-9_:-]+=[0-9]+$ ]]; then
    echo "FAIL: --max-drift-reason-count must use reason=count."
    exit 1
  fi
done

latest_report_json() {
  local base_dir="tmp/listener_parity"
  if [[ ! -d "$base_dir" ]]; then
    return 1
  fi
  find "$base_dir" -type f -name "report.json" -print0 2>/dev/null \
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

write_parity_readiness_report() {
  [[ -n "$JSON_OUT" ]] || JSON_OUT="${artifact_dir:-tmp/listener_parity}/parity_readiness_report.json"
  [[ -n "$MARKDOWN_OUT" ]] || MARKDOWN_OUT="${JSON_OUT%.json}.md"
  mkdir -p "$(dirname "$JSON_OUT")"
  mkdir -p "$(dirname "$MARKDOWN_OUT")"
  python3 - "$JSON_OUT" "$MARKDOWN_OUT" "$READINESS_STATUS" "$READINESS_SUMMARY" "$READINESS_FAILURE_CODE" "${REPORT_JSON:-}" "${artifact_dir:-}" "${report_age:-}" "${matched_count:-}" "${unmatched_serial_count:-}" "${unmatched_legacy_count:-}" "${match_rate_percent:-}" "${min_required_match_rate_percent:-}" "${max_skew_seconds_observed:-}" "${summary:-}" "${drift_reason_counts:-}" "$MAX_REPORT_AGE_HOURS" "$MIN_MATCH_RATE_PERCENT" "${MAX_OBSERVED_SKEW_SECONDS:-}" "$ALLOW_UNMATCHED_SERIAL" "$ALLOW_UNMATCHED_LEGACY" "$REQUIRE_REAL_ARTIFACTS" "${INTEGRITY_CERTIFICATE_JSON:-}" "${INTEGRITY_CERTIFICATE_MD:-}" "${INTEGRITY_CERTIFICATE_STATUS:-}" <<'PY'
import json
import sys
from pathlib import Path

json_out = Path(sys.argv[1])
markdown_out = Path(sys.argv[2])
status = sys.argv[3]
summary_text = sys.argv[4]
failure_code = sys.argv[5]
report_json = sys.argv[6]
artifact_dir = sys.argv[7]
report_age = sys.argv[8]
matched_count = sys.argv[9]
unmatched_serial_count = sys.argv[10]
unmatched_legacy_count = sys.argv[11]
match_rate_percent = sys.argv[12]
report_min_match_rate_percent = sys.argv[13]
max_skew_seconds_observed = sys.argv[14]
report_summary = sys.argv[15]
drift_reason_counts = sys.argv[16]
max_report_age_hours = sys.argv[17]
requested_min_match_rate_percent = sys.argv[18]
requested_max_observed_skew_seconds = sys.argv[19]
allow_unmatched_serial = sys.argv[20] == "1"
allow_unmatched_legacy = sys.argv[21] == "1"
require_real_artifacts = sys.argv[22] == "1"
integrity_certificate_json = sys.argv[23]
integrity_certificate_markdown = sys.argv[24]
integrity_certificate_status = sys.argv[25]

payload = {
    "status": status,
    "summary": summary_text,
    "failure_code": failure_code,
    "report_json": report_json,
    "artifact_dir": artifact_dir,
    "metrics": {
        "report_age_hours": report_age,
        "matched_count": matched_count,
        "unmatched_serial_count": unmatched_serial_count,
        "unmatched_legacy_count": unmatched_legacy_count,
        "match_rate_percent": match_rate_percent,
        "report_min_match_rate_percent": report_min_match_rate_percent,
        "max_skew_seconds_observed": max_skew_seconds_observed,
    },
    "report_summary": report_summary,
    "drift_reason_counts": drift_reason_counts,
    "requirements": {
        "max_report_age_hours": max_report_age_hours,
        "requested_min_match_rate_percent": requested_min_match_rate_percent,
        "requested_max_observed_skew_seconds": requested_max_observed_skew_seconds,
        "allow_unmatched_serial": allow_unmatched_serial,
        "allow_unmatched_legacy": allow_unmatched_legacy,
        "require_real_artifacts": require_real_artifacts,
    },
    "statuses": {
        "integrity_certificate_status": integrity_certificate_status,
    },
    "resolved_files": {
        "integrity_certificate_json": integrity_certificate_json,
        "integrity_certificate_markdown": integrity_certificate_markdown,
    },
}
json_out.write_text(json.dumps(payload, indent=2), encoding="utf-8")

lines = [
    "# ONYX Listener Parity Readiness",
    "",
    f"- Status: `{status}`",
    f"- Summary: `{summary_text}`",
    f"- Failure code: `{failure_code or 'n/a'}`",
    f"- Report JSON: `{report_json or 'n/a'}`",
    f"- Artifact dir: `{artifact_dir or 'n/a'}`",
    "",
    "## Metrics",
    f"- Report age hours: `{report_age or 'n/a'}`",
    f"- Matched count: `{matched_count or 'n/a'}`",
    f"- Unmatched serial count: `{unmatched_serial_count or 'n/a'}`",
    f"- Unmatched legacy count: `{unmatched_legacy_count or 'n/a'}`",
    f"- Match rate percent: `{match_rate_percent or 'n/a'}`",
    f"- Report minimum match rate percent: `{report_min_match_rate_percent or 'n/a'}`",
    f"- Max skew seconds observed: `{max_skew_seconds_observed or 'n/a'}`",
    "",
    "## Requirements",
    f"- Max report age hours: `{max_report_age_hours}`",
    f"- Requested min match rate percent: `{requested_min_match_rate_percent}`",
    f"- Requested max observed skew seconds: `{requested_max_observed_skew_seconds or 'n/a'}`",
    f"- Allow unmatched serial: `{allow_unmatched_serial}`",
    f"- Allow unmatched legacy: `{allow_unmatched_legacy}`",
    f"- Require real artifacts: `{require_real_artifacts}`",
    "",
    "## Integrity Certificate",
    f"- Integrity certificate JSON: `{integrity_certificate_json or 'n/a'}`",
    f"- Integrity certificate markdown: `{integrity_certificate_markdown or 'n/a'}`",
    f"- Integrity certificate status: `{integrity_certificate_status or 'n/a'}`",
    "",
    "## Report Summary",
    f"- `{report_summary or 'n/a'}`",
    "",
    "## Drift Reasons",
    f"- `{drift_reason_counts or '{}'}'",
]
markdown_out.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY
}

fail_readiness() {
  local failure_code="$1"
  local failure_summary="$2"
  READINESS_STATUS="FAIL"
  READINESS_SUMMARY="$failure_summary"
  READINESS_FAILURE_CODE="$failure_code"
  write_parity_readiness_report
  echo "FAIL: $failure_summary"
  echo "Parity readiness JSON: $JSON_OUT"
  exit 1
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

artifact_dir = data.get("artifact_dir", "")
files = data.get("files", {})
checksums = data.get("checksums", {})

for file_key, checksum_key in (
    ("serial_input", "serial_input_sha256"),
    ("legacy_input", "legacy_input_sha256"),
    ("report_markdown", "report_markdown_sha256"),
):
    path = files.get(file_key, "")
    expected = checksums.get(checksum_key, "")
    if not path or not expected:
        raise SystemExit(f"missing-metadata:{file_key}")
    if not os.path.isfile(path):
        raise SystemExit(f"missing-file:{file_key}:{path}")
    digest = hashlib.sha256(open(path, "rb").read()).hexdigest()
    if digest != expected:
        raise SystemExit(f"checksum:{file_key}:{path}")

if artifact_dir and not os.path.isdir(artifact_dir):
    raise SystemExit(f"artifact-dir:{artifact_dir}")
PY
}

verify_parity_integrity_certificate() {
  local report_file="$1"
  python3 - "$report_file" <<'PY'
import hashlib
import json
import os
import sys

report_file = sys.argv[1]
with open(report_file, "r", encoding="utf-8") as handle:
    report = json.load(handle)

files = report.get("files", {}) or {}
checksums = report.get("checksums", {}) or {}
cert_json = str(files.get("integrity_certificate_json", "")).strip()
cert_md = str(files.get("integrity_certificate_markdown", "")).strip()
if not cert_json:
    raise SystemExit("missing-certificate-json")
if not os.path.isfile(cert_json):
    raise SystemExit(f"missing-certificate-json:{cert_json}")
if not cert_md:
    raise SystemExit("missing-certificate-markdown")
if not os.path.isfile(cert_md):
    raise SystemExit(f"missing-certificate-markdown:{cert_md}")

with open(cert_json, "r", encoding="utf-8") as handle:
    cert = json.load(handle)

if str(cert.get("status", "")).upper() != "PASS":
    raise SystemExit("certificate-not-pass")
if str(cert.get("report_json", "")).strip() != report_file:
    raise SystemExit("certificate-report-json-mismatch")
cert_files = cert.get("files", {}) or {}
cert_checksums = cert.get("checksums", {}) or {}
for report_key, cert_key in (
    ("serial_input", "serial_input"),
    ("legacy_input", "legacy_input"),
    ("report_markdown", "report_markdown"),
):
    if str(cert_files.get(cert_key, "")).strip() != str(files.get(report_key, "")).strip():
        raise SystemExit(f"certificate-file-mismatch:{report_key}")
for report_key, cert_key in (
    ("serial_input_sha256", "serial_input_sha256"),
    ("legacy_input_sha256", "legacy_input_sha256"),
    ("report_markdown_sha256", "report_markdown_sha256"),
):
    if str(cert_checksums.get(cert_key, "")).strip() != str(checksums.get(report_key, "")).strip():
        raise SystemExit(f"certificate-checksum-mismatch:{report_key}")
bundle_hash_expected = hashlib.sha256(
    json.dumps(
        {
            "artifact_dir": str(cert.get("artifact_dir", "")),
            "report_json": str(cert.get("report_json", "")),
            "checksums": cert_checksums,
        },
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
).hexdigest()
if str(cert.get("bundle_hash", "")).strip() != bundle_hash_expected:
    raise SystemExit("certificate-bundle-hash-mismatch")
print("ok")
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

validate_drift_policy() {
  local report_file="$1"
  shift
  python3 - "$report_file" "$@" <<'PY'
import json
import sys

report_file = sys.argv[1]
allow_reasons = []
caps = {}
mode = None
for token in sys.argv[2:]:
    if token == "--allow":
        mode = "allow"
        continue
    if token == "--caps":
        mode = "caps"
        continue
    if mode == "allow":
        allow_reasons.append(token)
    elif mode == "caps":
        reason, count = token.split("=", 1)
        caps[reason] = int(count)

with open(report_file, "r", encoding="utf-8") as handle:
    data = json.load(handle)

drifts = data.get("drift_reason_counts", {}) or {}
for reason, count in drifts.items():
    if allow_reasons and reason not in allow_reasons:
        raise SystemExit(f"disallowed:{reason}:{count}")
    if reason in caps and int(count) > caps[reason]:
        raise SystemExit(f"cap:{reason}:{count}:{caps[reason]}")
PY
}

if [[ -z "$REPORT_JSON" ]]; then
  REPORT_JSON="$(latest_report_json || true)"
fi
if [[ -z "$REPORT_JSON" || ! -f "$REPORT_JSON" ]]; then
  if [[ -n "$REPORT_JSON" ]]; then
    artifact_dir="$(dirname "$REPORT_JSON")"
  fi
  fail_readiness "missing_parity_report" "listener parity report not found."
fi

artifact_dir="$(json_get "$REPORT_JSON" "artifact_dir")"
if [[ -z "$artifact_dir" ]]; then
  artifact_dir="$(dirname "$REPORT_JSON")"
fi

report_age="$(report_age_hours "$REPORT_JSON")"
if ! python3 - "$report_age" "$MAX_REPORT_AGE_HOURS" <<'PY'
import sys
age = float(sys.argv[1])
max_age = float(sys.argv[2])
raise SystemExit(0 if age <= max_age else 1)
PY
then
  fail_readiness "parity_report_stale" "listener parity report is stale (${report_age}h old > ${MAX_REPORT_AGE_HOURS}h)."
fi

if ! verify_json_report_checksums "$REPORT_JSON"; then
  fail_readiness "parity_report_checksum_failed" "listener parity checksums did not verify."
fi
echo "PASS: Listener parity checksums verified."
if ! verify_parity_integrity_certificate "$REPORT_JSON"; then
  fail_readiness "parity_integrity_certificate_failed" "listener parity integrity certificate did not verify."
fi
INTEGRITY_CERTIFICATE_JSON="$(json_get "$REPORT_JSON" "files.integrity_certificate_json")"
INTEGRITY_CERTIFICATE_MD="$(json_get "$REPORT_JSON" "files.integrity_certificate_markdown")"
INTEGRITY_CERTIFICATE_STATUS="PASS"
echo "PASS: Listener parity integrity certificate verified."
matched_count="$(json_get "$REPORT_JSON" "matched_count")"
unmatched_serial_count="$(json_get "$REPORT_JSON" "unmatched_serial_count")"
unmatched_legacy_count="$(json_get "$REPORT_JSON" "unmatched_legacy_count")"
match_rate_percent="$(json_get "$REPORT_JSON" "match_rate_percent")"
min_required_match_rate_percent="$(json_get "$REPORT_JSON" "min_required_match_rate_percent")"
max_skew_seconds_observed="$(json_get "$REPORT_JSON" "max_skew_seconds_observed")"
summary="$(json_get "$REPORT_JSON" "summary")"
drift_reason_counts="$(json_get "$REPORT_JSON" "drift_reason_counts")"

if [[ "$REQUIRE_REAL_ARTIFACTS" -eq 1 ]]; then
  if [[ "$artifact_dir" == *"/mock-"* || "$artifact_dir" == mock-* ]]; then
    fail_readiness "mock_artifacts_not_allowed" "mock artifact directory is not allowed under --require-real-artifacts ($artifact_dir)."
  fi
  echo "PASS: Real-artifact gate passed ($artifact_dir)."
fi

drift_policy_args=()
if [[ -n "${ALLOW_DRIFT_REASONS[*]-}" ]]; then
  drift_policy_args+=(--allow)
  for allow_reason in "${ALLOW_DRIFT_REASONS[@]-}"; do
    [[ -n "$allow_reason" ]] || continue
    drift_policy_args+=("$allow_reason")
  done
fi
if [[ -n "${MAX_DRIFT_REASON_COUNTS[*]-}" ]]; then
  drift_policy_args+=(--caps)
  for drift_cap in "${MAX_DRIFT_REASON_COUNTS[@]-}"; do
    [[ -n "$drift_cap" ]] || continue
    drift_policy_args+=("$drift_cap")
  done
fi
policy_error="$(validate_drift_policy "$REPORT_JSON" "${drift_policy_args[@]-}" 2>&1 || true)"
if [[ -n "$policy_error" ]]; then
  case "$policy_error" in
    disallowed:*)
      reason="${policy_error#disallowed:}"
      reason_name="${reason%%:*}"
      reason_count="${reason##*:}"
      fail_readiness "parity_drift_reason_disallowed" "listener parity drift reason is not allowed ($reason_name: $reason_count)."
      ;;
    cap:*)
      payload="${policy_error#cap:}"
      reason_name="${payload%%:*}"
      rest="${payload#*:}"
      reason_count="${rest%%:*}"
      reason_cap="${payload##*:}"
      fail_readiness "parity_drift_reason_cap_exceeded" "listener parity drift reason exceeds cap ($reason_name: $reason_count > $reason_cap)."
      ;;
    *)
      fail_readiness "parity_drift_policy_failed" "listener parity drift policy validation failed."
      ;;
  esac
fi
if [[ -n "${ALLOW_DRIFT_REASONS[*]-}" || -n "${MAX_DRIFT_REASON_COUNTS[*]-}" ]]; then
  echo "PASS: Listener parity drift policy passed."
fi

if [[ "${matched_count:-0}" -lt 1 ]]; then
  fail_readiness "no_matched_events" "listener parity report has no matched events."
fi
if ! python3 - "$match_rate_percent" "$MIN_MATCH_RATE_PERCENT" <<'PY'
import sys
actual = float(sys.argv[1] or 0.0)
minimum = float(sys.argv[2])
raise SystemExit(0 if actual >= minimum else 1)
PY
then
  fail_readiness "match_rate_below_threshold" "listener parity match rate is below threshold (${match_rate_percent}% < ${MIN_MATCH_RATE_PERCENT}%)."
fi
echo "PASS: Listener parity match rate passed (${match_rate_percent}% >= ${MIN_MATCH_RATE_PERCENT}%)."

if [[ -n "$min_required_match_rate_percent" ]] && ! python3 - "$MIN_MATCH_RATE_PERCENT" "$min_required_match_rate_percent" <<'PY'
import sys
requested = float(sys.argv[1])
reported = float(sys.argv[2] or 0.0)
raise SystemExit(0 if requested >= reported else 1)
PY
then
  fail_readiness "requested_match_rate_weaker_than_report" "readiness threshold (${MIN_MATCH_RATE_PERCENT}%) is weaker than the report minimum (${min_required_match_rate_percent}%)."
fi

if [[ -n "$MAX_OBSERVED_SKEW_SECONDS" ]]; then
  if ! python3 - "$max_skew_seconds_observed" "$MAX_OBSERVED_SKEW_SECONDS" <<'PY'
import sys
observed = float(sys.argv[1] or 0.0)
maximum = float(sys.argv[2])
raise SystemExit(0 if observed <= maximum else 1)
PY
  then
    fail_readiness "observed_skew_above_threshold" "listener parity observed skew exceeds threshold (${max_skew_seconds_observed}s > ${MAX_OBSERVED_SKEW_SECONDS}s)."
  fi
  echo "PASS: Listener parity skew passed (${max_skew_seconds_observed}s <= ${MAX_OBSERVED_SKEW_SECONDS}s)."
fi
if [[ "$ALLOW_UNMATCHED_SERIAL" -ne 1 && "${unmatched_serial_count:-0}" -gt 0 ]]; then
  fail_readiness "unmatched_serial_present" "listener parity report has serial-only events ($unmatched_serial_count)."
fi
if [[ "$ALLOW_UNMATCHED_LEGACY" -ne 1 && "${unmatched_legacy_count:-0}" -gt 0 ]]; then
  fail_readiness "unmatched_legacy_present" "listener parity report has legacy-only events ($unmatched_legacy_count)."
fi

READINESS_STATUS="PASS"
READINESS_SUMMARY="Listener parity readiness passed."
READINESS_FAILURE_CODE=""
write_parity_readiness_report
echo "PASS: Listener parity readiness passed."
echo "Report: $REPORT_JSON"
echo "Parity readiness JSON: $JSON_OUT"
echo "Summary: $summary"
if [[ -n "$drift_reason_counts" && "$drift_reason_counts" != "{}" ]]; then
  echo "Drift reasons: $drift_reason_counts"
fi
