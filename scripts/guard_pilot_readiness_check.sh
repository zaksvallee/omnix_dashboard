#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

RUN_FULL_TESTS=0
ENFORCE_LIVE_TELEMETRY=0
REQUIRE_LIVE_VALIDATION_ARTIFACTS=0
REQUIRE_REAL_DEVICE_ARTIFACTS=0
REQUIRE_SUPABASE_CONFIG=0
REQUIRE_DIRECT_SDK_CONNECTOR=0
CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"
MAX_LIVE_VALIDATION_REPORT_AGE_HOURS="${ONYX_MAX_LIVE_VALIDATION_REPORT_AGE_HOURS:-24}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --full-tests)
      RUN_FULL_TESTS=1
      shift
      ;;
    --enforce-live-telemetry)
      ENFORCE_LIVE_TELEMETRY=1
      shift
      ;;
    --require-live-validation-artifacts)
      REQUIRE_LIVE_VALIDATION_ARTIFACTS=1
      shift
      ;;
    --require-real-device-artifacts)
      REQUIRE_REAL_DEVICE_ARTIFACTS=1
      shift
      ;;
    --require-supabase-config)
      REQUIRE_SUPABASE_CONFIG=1
      shift
      ;;
    --require-direct-sdk-connector)
      REQUIRE_DIRECT_SDK_CONNECTOR=1
      shift
      ;;
    --config)
      CONFIG_FILE="${2:-}"
      shift 2
      ;;
    --help|-h)
      echo "Usage: ./scripts/guard_pilot_readiness_check.sh [--full-tests] [--enforce-live-telemetry] [--require-live-validation-artifacts] [--require-real-device-artifacts] [--require-supabase-config] [--require-direct-sdk-connector] [--config <path>] [--max-live-validation-report-age-hours <hours>]"
      exit 0
      ;;
    --max-live-validation-report-age-hours)
      MAX_LIVE_VALIDATION_REPORT_AGE_HOURS="${2:-}"
      shift 2
      ;;
    *)
      echo "WARN: Ignoring unknown argument: $1"
      shift
      ;;
  esac
done

if [[ "$REQUIRE_DIRECT_SDK_CONNECTOR" -eq 1 && "$REQUIRE_LIVE_VALIDATION_ARTIFACTS" -ne 1 ]]; then
  echo "FAIL: --require-direct-sdk-connector requires --require-live-validation-artifacts."
  exit 1
fi

pass() { printf "PASS: %s\n" "$1"; }
warn() { printf "WARN: %s\n" "$1"; }
fail() { printf "FAIL: %s\n" "$1"; exit 1; }

check_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    pass "Found $path"
  else
    fail "Missing required file: $path"
  fi
}

json_value() {
  local key="$1"
  local file="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg key "$key" '.[$key] // ""' "$file"
    return
  fi
  sed -nE "s/^[[:space:]]*\"$key\"[[:space:]]*:[[:space:]]*\"([^\"]*)\"[[:space:]]*,?[[:space:]]*$/\1/p" "$file" | head -n 1
}

is_placeholder_secret() {
  local value
  value="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '\r')"
  if [[ -z "$value" ]]; then
    return 1
  fi
  if [[ "$value" == "replace-me" ]]; then
    return 0
  fi
  [[ "$value" == your_*_here ]]
}

is_placeholder_supabase_url() {
  local value
  value="$(echo "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -d '\r')"
  if [[ -z "$value" ]]; then
    return 1
  fi
  [[ "$value" == *"your-project.supabase.co"* ]]
}

latest_validation_report() {
  local base_dir="tmp/guard_field_validation"
  if [[ ! -d "$base_dir" ]]; then
    return 1
  fi
  find "$base_dir" -type f -name "validation_report.md" -print0 2>/dev/null \
    | xargs -0 ls -1t 2>/dev/null \
    | head -n 1
}

latest_validation_report_json() {
  local base_dir="tmp/guard_field_validation"
  if [[ ! -d "$base_dir" ]]; then
    return 1
  fi
  find "$base_dir" -type f -name "validation_report.json" -print0 2>/dev/null \
    | xargs -0 ls -1t 2>/dev/null \
    | head -n 1
}

report_age_hours() {
  local report_file="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$report_file" <<'PY'
import os
import sys
import time

path = sys.argv[1]
age_hours = (time.time() - os.path.getmtime(path)) / 3600.0
print(f"{age_hours:.2f}")
PY
    return 0
  fi
  echo "99999"
}

json_report_overall_status() {
  local report_file="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r '.overall_status // ""' "$report_file"
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$report_file" <<'PY'
import json
import sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
print(data.get("overall_status", ""))
PY
    return 0
  fi
  echo ""
}

json_report_artifact_dir() {
  local report_file="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r '.artifact_dir // ""' "$report_file"
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$report_file" <<'PY'
import json
import sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
print(data.get("artifact_dir", ""))
PY
    return 0
  fi
  echo ""
}

json_report_required_provider() {
  local report_file="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r '.required_provider // ""' "$report_file"
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$report_file" <<'PY'
import json
import sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
print(data.get("required_provider", ""))
PY
    return 0
  fi
  echo ""
}

json_report_connector_fallback_inactive() {
  local report_file="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -r '.gates.connector_fallback_inactive // ""' "$report_file"
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$report_file" <<'PY'
import json
import sys
with open(sys.argv[1], 'r', encoding='utf-8') as f:
    data = json.load(f)
gates = data.get("gates", {}) if isinstance(data, dict) else {}
value = gates.get("connector_fallback_inactive", "")
if isinstance(value, bool):
    print("true" if value else "false")
else:
    print(value)
PY
    return 0
  fi
  echo ""
}

verify_json_report_checksums() {
  local report_file="$1"
  if ! command -v python3 >/dev/null 2>&1; then
    warn "Python is unavailable; skipping JSON checksum verification."
    return 0
  fi
  if python3 - "$report_file" <<'PY'
import hashlib
import json
import os
import sys

report_file = sys.argv[1]
with open(report_file, "r", encoding="utf-8") as f:
    data = json.load(f)

files = data.get("files", {})
checksums = data.get("checksums", {})

mapping = {
    "summary": "summary_sha256",
    "broadcasts": "broadcasts_sha256",
    "logcat_onyx_telemetry": "logcat_onyx_telemetry_sha256",
    "logcat_ingest_trace": "logcat_ingest_trace_sha256",
    "logcat_full": "logcat_full_sha256",
}

for file_key, checksum_key in mapping.items():
    path = files.get(file_key)
    expected = checksums.get(checksum_key, "")
    if not path or not expected:
        raise SystemExit(1)
    if not os.path.isfile(path):
        raise SystemExit(1)
    h = hashlib.sha256()
    with open(path, "rb") as evidence:
        for chunk in iter(lambda: evidence.read(1024 * 1024), b""):
            h.update(chunk)
    if h.hexdigest().lower() != str(expected).strip().lower():
        raise SystemExit(1)

raise SystemExit(0)
PY
  then
    pass "Live validation JSON checksum verification passed ($report_file)"
    return 0
  fi
  fail "Live validation artifact gate failed: JSON checksum verification failed ($report_file)"
}

run_with_timeout() {
  local seconds="$1"
  shift

  if command -v timeout >/dev/null 2>&1; then
    timeout "$seconds" "$@"
    return $?
  fi

  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$seconds" "$@"
    return $?
  fi

  if command -v python3 >/dev/null 2>&1; then
    python3 - "$seconds" "$@" <<'PY'
import subprocess
import sys

timeout_s = int(sys.argv[1])
cmd = sys.argv[2:]
try:
    completed = subprocess.run(cmd, check=False, timeout=timeout_s)
    raise SystemExit(completed.returncode)
except subprocess.TimeoutExpired:
    raise SystemExit(124)
PY
    return $?
  fi

  "$@"
}

echo "== ONYX Guard Pilot Readiness Check =="

check_file "supabase/migrations/202603050001_create_guard_sync_tables.sql"
check_file "supabase/migrations/202603050002_create_guard_ops_event_log.sql"
check_file "supabase/migrations/202603050003_apply_guard_rls_storage_policies.sql"
check_file "supabase/migrations/202603050008_add_guard_projection_retention.sql"
check_file "supabase/migrations/202603050009_add_guard_ops_replay_safety_retention.sql"
check_file "supabase/migrations/202603050010_add_guard_rls_storage_readiness_checks.sql"
check_file "docs/guard_app_android_deployment_blueprint_v2.md"
check_file "docs/guard_native_telemetry_sdk_contract.md"
check_file "docs/guard_app_deployment_status_checklist.md"
check_file "docs/guard_pilot_config_matrix.md"
check_file "docs/guard_android_live_validation_runbook.md"
check_file "supabase/sql/guard_readiness_smoke_checks.sql"
check_file "supabase/sql/guard_actor_contract_checks.sql"

if [[ -f "$CONFIG_FILE" ]]; then
  pass "Found $CONFIG_FILE"
  supabase_url="$(json_value "SUPABASE_URL" "$CONFIG_FILE" | tr -d '\r')"
  supabase_anon_key="$(json_value "SUPABASE_ANON_KEY" "$CONFIG_FILE" | tr -d '\r')"

  if [[ "$REQUIRE_SUPABASE_CONFIG" -eq 1 ]]; then
    if [[ -z "$supabase_url" || -z "$supabase_anon_key" ]]; then
      fail "Supabase config gate failed: SUPABASE_URL and SUPABASE_ANON_KEY must both be set in $CONFIG_FILE."
    fi
    if is_placeholder_supabase_url "$supabase_url"; then
      fail "Supabase config gate failed: SUPABASE_URL is still the placeholder value in $CONFIG_FILE."
    fi
    if is_placeholder_secret "$supabase_anon_key"; then
      fail "Supabase config gate failed: SUPABASE_ANON_KEY is still a placeholder value in $CONFIG_FILE."
    fi
    pass "Supabase config gate passed."
  fi

  if [[ "$ENFORCE_LIVE_TELEMETRY" -eq 1 ]]; then
    native_sdk="$(json_value "ONYX_GUARD_TELEMETRY_NATIVE_SDK" "$CONFIG_FILE" | tr '[:upper:]' '[:lower:]')"
    native_stub="$(json_value "ONYX_GUARD_TELEMETRY_NATIVE_STUB" "$CONFIG_FILE" | tr '[:upper:]' '[:lower:]')"
    native_provider="$(json_value "ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER" "$CONFIG_FILE")"
    required_provider="$(json_value "ONYX_GUARD_TELEMETRY_REQUIRED_PROVIDER" "$CONFIG_FILE")"

    if [[ "$native_sdk" != "true" ]]; then
      fail "Live telemetry gate failed: ONYX_GUARD_TELEMETRY_NATIVE_SDK must be true."
    fi
    if [[ "$native_stub" != "false" ]]; then
      fail "Live telemetry gate failed: ONYX_GUARD_TELEMETRY_NATIVE_STUB must be false."
    fi
    if [[ -z "$native_provider" || "$native_provider" == "android_native_sdk_stub" ]]; then
      fail "Live telemetry gate failed: ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER must be a live provider ID."
    fi
    if [[ -z "$required_provider" ]]; then
      required_provider="$native_provider"
      pass "Live telemetry required provider not set; defaulting to native provider ($required_provider)."
    fi
    if [[ "$required_provider" == "android_native_sdk_stub" ]]; then
      fail "Live telemetry gate failed: ONYX_GUARD_TELEMETRY_REQUIRED_PROVIDER cannot be android_native_sdk_stub."
    fi
    if [[ "$required_provider" != "$native_provider" ]]; then
      warn "Live telemetry provider mismatch in config: native=$native_provider required=$required_provider."
    fi
    pass "Live telemetry gate passed (native: $native_provider, required: $required_provider)"
  fi
else
  if [[ "$ENFORCE_LIVE_TELEMETRY" -eq 1 || "$REQUIRE_SUPABASE_CONFIG" -eq 1 ]]; then
    fail "$CONFIG_FILE not found (required by the active readiness gate flags)."
  fi
  warn "$CONFIG_FILE not found (required for local chrome run with dart-define-from-file)."
  warn "Create it with: cp config/onyx.local.example.json config/onyx.local.json"
fi

if [[ "$REQUIRE_LIVE_VALIDATION_ARTIFACTS" -eq 1 ]]; then
  if ! [[ "$MAX_LIVE_VALIDATION_REPORT_AGE_HOURS" =~ ^[0-9]+$ ]]; then
    fail "Live validation artifact gate failed: --max-live-validation-report-age-hours must be a non-negative integer."
  fi
  latest_report_json="$(latest_validation_report_json || true)"
  latest_report_md="$(latest_validation_report || true)"
  if [[ -z "$latest_report_json" && -z "$latest_report_md" ]]; then
    fail "Live validation artifact gate failed: no validation_report.json or validation_report.md found under tmp/guard_field_validation."
  fi
  if [[ -n "$latest_report_json" && ! -f "$latest_report_json" ]]; then
    latest_report_json=""
  fi
  if [[ -n "$latest_report_md" && ! -f "$latest_report_md" ]]; then
    latest_report_md=""
  fi
  latest_report="$latest_report_json"
  if [[ -z "$latest_report" ]]; then
    latest_report="$latest_report_md"
  fi
  report_age="$(report_age_hours "$latest_report")"
  if command -v python3 >/dev/null 2>&1; then
    if ! python3 - "$report_age" "$MAX_LIVE_VALIDATION_REPORT_AGE_HOURS" <<'PY'
import sys
age = float(sys.argv[1])
max_age = float(sys.argv[2])
raise SystemExit(0 if age <= max_age else 1)
PY
    then
      fail "Live validation artifact gate failed: latest report is stale (${report_age}h old > ${MAX_LIVE_VALIDATION_REPORT_AGE_HOURS}h)."
    fi
  else
    report_age_rounded="$(printf '%.0f' "$report_age")"
    if [[ "$report_age_rounded" -gt "$MAX_LIVE_VALIDATION_REPORT_AGE_HOURS" ]]; then
      fail "Live validation artifact gate failed: latest report is stale (${report_age}h old > ${MAX_LIVE_VALIDATION_REPORT_AGE_HOURS}h)."
    fi
  fi
  overall_status=""
  connector_fallback_inactive=""
  if [[ -n "$latest_report_json" ]]; then
    overall_status="$(json_report_overall_status "$latest_report_json" | tr '[:lower:]' '[:upper:]')"
    verify_json_report_checksums "$latest_report_json"
    report_required_provider="$(json_report_required_provider "$latest_report_json")"
    if [[ "$ENFORCE_LIVE_TELEMETRY" -eq 1 && -n "${required_provider:-}" && -n "$report_required_provider" ]]; then
      if [[ "$report_required_provider" != "$required_provider" ]]; then
        fail "Live validation artifact gate failed: report required_provider ($report_required_provider) does not match telemetry gate required provider ($required_provider)."
      fi
    fi
    if [[ "$REQUIRE_DIRECT_SDK_CONNECTOR" -eq 1 ]]; then
      connector_fallback_inactive="$(
        json_report_connector_fallback_inactive "$latest_report_json" | tr '[:upper:]' '[:lower:]'
      )"
      if [[ "$connector_fallback_inactive" != "true" ]]; then
        fail "Live validation artifact gate failed: connector fallback is active (or missing gate data) under --require-direct-sdk-connector."
      fi
      pass "Direct SDK connector gate passed (no broadcast fallback detected)."
    fi
  fi
  if [[ "$REQUIRE_DIRECT_SDK_CONNECTOR" -eq 1 && -z "$latest_report_json" ]]; then
    fail "Live validation artifact gate failed: --require-direct-sdk-connector requires validation_report.json."
  fi
  if [[ -z "$overall_status" && -n "$latest_report_md" ]]; then
    if grep -q "Overall status: \*\*PASS\*\*" "$latest_report_md"; then
      overall_status="PASS"
    else
      overall_status="FAIL"
    fi
  fi
  if [[ "$overall_status" == "PASS" ]]; then
    if [[ "$REQUIRE_REAL_DEVICE_ARTIFACTS" -eq 1 ]]; then
      artifact_dir_label=""
      if [[ -n "$latest_report_json" ]]; then
        artifact_dir_label="$(json_report_artifact_dir "$latest_report_json")"
      fi
      if [[ -z "$artifact_dir_label" ]]; then
        artifact_dir_label="$(dirname "$latest_report")"
      fi
      if [[ "$artifact_dir_label" == *"/mock-"* || "$artifact_dir_label" == mock-* ]]; then
        fail "Live validation artifact gate failed: mock artifact directory is not allowed under --require-real-device-artifacts ($artifact_dir_label)."
      fi
      pass "Real-device artifact gate passed ($artifact_dir_label)"
    fi
    pass "Live validation artifact gate passed ($latest_report, age=${report_age}h)"
  else
    fail "Live validation artifact gate failed: report overall_status is not PASS ($latest_report)"
  fi
fi

if command -v flutter >/dev/null 2>&1; then
  echo "Running flutter analyze..."
  flutter analyze >/dev/null
  pass "flutter analyze"

  echo "Running guard reliability tests..."
  flutter test -r compact test/application/guard_sync_repository_test.dart >/dev/null
  flutter test -r compact test/application/guard_telemetry_ingestion_adapter_test.dart >/dev/null
  pass "targeted guard tests"

  if [[ "$RUN_FULL_TESTS" -eq 1 ]]; then
    echo "Running full flutter test suite..."
    flutter test -r compact >/dev/null
    pass "full flutter test suite"
  else
    warn "Skipped full flutter test suite (pass --full-tests to include)."
  fi
else
  fail "flutter is not installed or not on PATH."
fi

if command -v supabase >/dev/null 2>&1; then
  echo "Checking supabase migration state..."
  if run_with_timeout 20 supabase migration list >/dev/null 2>&1; then
    pass "supabase migration list"
  else
    warn "supabase migration list failed or timed out (project may not be linked in this shell)."
  fi
else
  warn "supabase CLI not found; cannot verify migration link/state."
fi

echo ""
echo "Recommended remote SQL smoke check:"
echo "Run /Users/zaks/omnix_dashboard/supabase/sql/guard_readiness_smoke_checks.sql in Supabase SQL editor."
echo "Then run /Users/zaks/omnix_dashboard/supabase/sql/guard_actor_contract_checks.sql in Supabase SQL editor."

echo ""
echo "Pilot readiness check complete."
