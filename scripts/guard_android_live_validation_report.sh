#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_DIR=""
OUT_FILE=""
JSON_OUT_FILE=""
REQUIRED_PROVIDER="${ONYX_GUARD_TELEMETRY_REQUIRED_PROVIDER:-${ONYX_GUARD_TELEMETRY_NATIVE_PROVIDER:-fsk_sdk}}"
REQUIRE_DIRECT_SDK_CONNECTOR=0

pass() { printf "PASS: %s\n" "$1"; }
fail() { printf "FAIL: %s\n" "$1"; exit 1; }

sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
    return 0
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$file" <<'PY'
import hashlib
import sys
path = sys.argv[1]
with open(path, 'rb') as f:
    digest = hashlib.sha256(f.read()).hexdigest()
print(digest)
PY
    return 0
  fi
  echo ""
}

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/guard_android_live_validation_report.sh --artifact-dir <path> [--required-provider <provider-id>] [--require-direct-sdk-connector] [--out <report.md>] [--json-out <report.json>]

Purpose:
  Builds a markdown validation report from guard Android live-validation artifacts.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact-dir)
      ARTIFACT_DIR="${2:-}"
      shift 2
      ;;
    --out)
      OUT_FILE="${2:-}"
      shift 2
      ;;
    --json-out)
      JSON_OUT_FILE="${2:-}"
      shift 2
      ;;
    --required-provider)
      REQUIRED_PROVIDER="${2:-}"
      shift 2
      ;;
    --require-direct-sdk-connector)
      REQUIRE_DIRECT_SDK_CONNECTOR=1
      shift
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

if [[ -z "$ARTIFACT_DIR" ]]; then
  fail "--artifact-dir is required."
fi
if [[ ! -d "$ARTIFACT_DIR" ]]; then
  fail "Artifact directory not found: $ARTIFACT_DIR"
fi

SUMMARY_FILE="$ARTIFACT_DIR/summary.txt"
BROADCAST_FILE="$ARTIFACT_DIR/broadcasts.txt"
ONYX_LOG_FILE="$ARTIFACT_DIR/logcat_onyx_telemetry.txt"
INGEST_LOG_FILE="$ARTIFACT_DIR/logcat_ingest_trace.txt"
RUNTIME_PROFILE_TEXT_FILE="$ARTIFACT_DIR/runtime_profile.txt"
RUNTIME_PROFILE_JSON_FILE="$ARTIFACT_DIR/runtime_profile.json"

if [[ ! -f "$SUMMARY_FILE" ]]; then
  fail "Missing required file: $SUMMARY_FILE"
fi
if [[ ! -f "$BROADCAST_FILE" ]]; then
  fail "Missing required file: $BROADCAST_FILE"
fi
if [[ ! -f "$ONYX_LOG_FILE" ]]; then
  fail "Missing required file: $ONYX_LOG_FILE"
fi
if [[ ! -f "$INGEST_LOG_FILE" ]]; then
  fail "Missing required file: $INGEST_LOG_FILE"
fi

if [[ -z "$OUT_FILE" ]]; then
  OUT_FILE="$ARTIFACT_DIR/validation_report.md"
fi
if [[ -z "$JSON_OUT_FILE" ]]; then
  JSON_OUT_FILE="$ARTIFACT_DIR/validation_report.json"
fi

broadcast_count="$(grep -c '^sent sample=' "$BROADCAST_FILE" || true)"
telemetry_line_count="$(wc -l < "$ONYX_LOG_FILE" | tr -d ' ')"
legacy_ingest_line_count="$(wc -l < "$INGEST_LOG_FILE" | tr -d ' ')"
live_facade_trace_count="$(grep -Eic 'facade_ingest|sdk_callback_received|sdk_callback_error' "$ONYX_LOG_FILE" || true)"
ingest_line_count="$legacy_ingest_line_count"
if [[ "$live_facade_trace_count" -gt 0 ]]; then
  ingest_line_count="$((legacy_ingest_line_count + live_facade_trace_count))"
fi
accepted_count_legacy="$(grep -c 'accepted=true' "$ONYX_LOG_FILE" || true)"
accepted_count_live="$(grep -c 'sdk_callback_received' "$ONYX_LOG_FILE" || true)"
accepted_count="$((accepted_count_legacy + accepted_count_live))"
rejected_count_legacy="$(grep -c 'accepted=false' "$ONYX_LOG_FILE" || true)"
rejected_count_live="$(grep -c 'sdk_callback_error' "$ONYX_LOG_FILE" || true)"
rejected_count="$((rejected_count_legacy + rejected_count_live))"
provider_match_count="$(grep -c "provider=${REQUIRED_PROVIDER}" "$INGEST_LOG_FILE" || true)"
provider_startup_marker="fsk_live_facade_started"
required_provider_lower="$(printf '%s' "$REQUIRED_PROVIDER" | tr '[:upper:]' '[:lower:]')"
if [[ "$required_provider_lower" == *"hikvision"* ]]; then
  provider_startup_marker="hikvision_live_facade_started"
fi
provider_startup_count="$(grep -c "$provider_startup_marker" "$ONYX_LOG_FILE" || true)"
if [[ "$provider_match_count" -lt 1 && "$provider_startup_count" -gt 0 ]]; then
  provider_match_count="$provider_startup_count"
fi
connector_fallback_line_count="$(grep -Eic 'fallback_active=true|heartbeat_source=broadcast_fallback|falling back to broadcast' "$ONYX_LOG_FILE" || true)"

overall_status="PASS"
if [[ "$broadcast_count" -lt 1 ]]; then
  overall_status="FAIL"
fi
if [[ "$telemetry_line_count" -lt 1 ]]; then
  overall_status="FAIL"
fi
if [[ "$ingest_line_count" -lt 1 ]]; then
  overall_status="FAIL"
fi
if [[ "$accepted_count" -lt 1 ]]; then
  overall_status="FAIL"
fi
if [[ "$provider_match_count" -lt 1 ]]; then
  overall_status="FAIL"
fi
if [[ "$live_facade_trace_count" -lt 1 ]]; then
  overall_status="FAIL"
fi
if [[ "$REQUIRE_DIRECT_SDK_CONNECTOR" -eq 1 && "$connector_fallback_line_count" -gt 0 ]]; then
  overall_status="FAIL"
fi

summary_sha="$(sha256_file "$SUMMARY_FILE")"
broadcasts_sha="$(sha256_file "$BROADCAST_FILE")"
onyx_log_sha="$(sha256_file "$ONYX_LOG_FILE")"
ingest_log_sha="$(sha256_file "$INGEST_LOG_FILE")"
full_log_sha="$(sha256_file "$ARTIFACT_DIR/logcat_full.txt")"
runtime_profile_text_sha=""
runtime_profile_json_sha=""
if [[ -f "$RUNTIME_PROFILE_TEXT_FILE" ]]; then
  runtime_profile_text_sha="$(sha256_file "$RUNTIME_PROFILE_TEXT_FILE")"
fi
if [[ -f "$RUNTIME_PROFILE_JSON_FILE" ]]; then
  runtime_profile_json_sha="$(sha256_file "$RUNTIME_PROFILE_JSON_FILE")"
fi

cat > "$OUT_FILE" <<EOF
# ONYX Android Live Validation Report

- Artifact directory: \`$ARTIFACT_DIR\`
- Generated at (UTC): \`$(date -u +%Y-%m-%dT%H:%M:%SZ)\`
- Required provider: \`$REQUIRED_PROVIDER\`
- Overall status: **$overall_status**

## Metrics

- Broadcast samples emitted: \`$broadcast_count\`
- ONYX telemetry log lines: \`$telemetry_line_count\`
- Ingest trace log lines: \`$ingest_line_count\`
- Accepted ingest results: \`$accepted_count\`
- Rejected ingest results: \`$rejected_count\`
- Provider-matched ingest traces: \`$provider_match_count\`
- Live-facade trace lines: \`$live_facade_trace_count\`
- Connector fallback traces: \`$connector_fallback_line_count\`

## Gate Evaluation

- Broadcasts present: $([[ "$broadcast_count" -gt 0 ]] && echo "PASS" || echo "FAIL")
- Telemetry logs present: $([[ "$telemetry_line_count" -gt 0 ]] && echo "PASS" || echo "FAIL")
- Ingest trace logs present: $([[ "$ingest_line_count" -gt 0 ]] && echo "PASS" || echo "FAIL")
- At least one accepted ingest: $([[ "$accepted_count" -gt 0 ]] && echo "PASS" || echo "FAIL")
- Ingest traces match required provider: $([[ "$provider_match_count" -gt 0 ]] && echo "PASS" || echo "FAIL")
- Live facade traces present: $([[ "$live_facade_trace_count" -gt 0 ]] && echo "PASS" || echo "FAIL")
- Direct SDK connector gate: $(
  if [[ "$REQUIRE_DIRECT_SDK_CONNECTOR" -eq 1 ]]; then
    [[ "$connector_fallback_line_count" -eq 0 ]] && echo "PASS" || echo "FAIL"
  else
    echo "SKIPPED"
  fi
)

## Evidence Files

- [summary.txt]($ARTIFACT_DIR/summary.txt)
- [broadcasts.txt]($ARTIFACT_DIR/broadcasts.txt)
- [logcat_onyx_telemetry.txt]($ARTIFACT_DIR/logcat_onyx_telemetry.txt)
- [logcat_ingest_trace.txt]($ARTIFACT_DIR/logcat_ingest_trace.txt)
- [logcat_full.txt]($ARTIFACT_DIR/logcat_full.txt)
$(if [[ -f "$RUNTIME_PROFILE_TEXT_FILE" ]]; then echo "- [runtime_profile.txt]($ARTIFACT_DIR/runtime_profile.txt)"; fi)
$(if [[ -f "$RUNTIME_PROFILE_JSON_FILE" ]]; then echo "- [runtime_profile.json]($ARTIFACT_DIR/runtime_profile.json)"; fi)
EOF

cat > "$JSON_OUT_FILE" <<EOF
{
  "generated_at_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "artifact_dir": "$ARTIFACT_DIR",
  "required_provider": "$REQUIRED_PROVIDER",
  "strict_require_direct_sdk_connector": $([[ "$REQUIRE_DIRECT_SDK_CONNECTOR" -eq 1 ]] && echo "true" || echo "false"),
  "overall_status": "$overall_status",
  "metrics": {
    "broadcast_count": $broadcast_count,
    "telemetry_line_count": $telemetry_line_count,
    "ingest_line_count": $ingest_line_count,
    "accepted_count": $accepted_count,
    "rejected_count": $rejected_count,
    "provider_match_count": $provider_match_count,
    "live_facade_trace_count": $live_facade_trace_count,
    "connector_fallback_line_count": $connector_fallback_line_count
  },
  "gates": {
    "broadcasts_present": $([[ "$broadcast_count" -gt 0 ]] && echo "true" || echo "false"),
    "telemetry_logs_present": $([[ "$telemetry_line_count" -gt 0 ]] && echo "true" || echo "false"),
    "ingest_logs_present": $([[ "$ingest_line_count" -gt 0 ]] && echo "true" || echo "false"),
    "accepted_present": $([[ "$accepted_count" -gt 0 ]] && echo "true" || echo "false"),
    "provider_match_present": $([[ "$provider_match_count" -gt 0 ]] && echo "true" || echo "false"),
    "live_facade_trace_present": $([[ "$live_facade_trace_count" -gt 0 ]] && echo "true" || echo "false"),
    "connector_fallback_inactive": $([[ "$connector_fallback_line_count" -eq 0 ]] && echo "true" || echo "false")
  },
  "files": {
    "summary": "$ARTIFACT_DIR/summary.txt",
    "broadcasts": "$ARTIFACT_DIR/broadcasts.txt",
    "logcat_onyx_telemetry": "$ARTIFACT_DIR/logcat_onyx_telemetry.txt",
    "logcat_ingest_trace": "$ARTIFACT_DIR/logcat_ingest_trace.txt",
    "logcat_full": "$ARTIFACT_DIR/logcat_full.txt",
    "runtime_profile_text": "$([[ -f "$RUNTIME_PROFILE_TEXT_FILE" ]] && echo "$RUNTIME_PROFILE_TEXT_FILE" || echo "")",
    "runtime_profile_json": "$([[ -f "$RUNTIME_PROFILE_JSON_FILE" ]] && echo "$RUNTIME_PROFILE_JSON_FILE" || echo "")",
    "markdown_report": "$OUT_FILE"
  },
  "checksums": {
    "summary_sha256": "$summary_sha",
    "broadcasts_sha256": "$broadcasts_sha",
    "logcat_onyx_telemetry_sha256": "$onyx_log_sha",
    "logcat_ingest_trace_sha256": "$ingest_log_sha",
    "logcat_full_sha256": "$full_log_sha",
    "runtime_profile_text_sha256": "$runtime_profile_text_sha",
    "runtime_profile_json_sha256": "$runtime_profile_json_sha"
  }
}
EOF

pass "Validation report written to $OUT_FILE"
pass "Validation report JSON written to $JSON_OUT_FILE"
if [[ "$overall_status" == "PASS" ]]; then
  pass "Live telemetry validation gates passed."
else
  fail "Live telemetry validation gates failed. Review report: $OUT_FILE"
fi
