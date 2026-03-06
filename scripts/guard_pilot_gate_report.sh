#!/usr/bin/env bash
set -euo pipefail

OUT_DIR=""
CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/guard_pilot_gate_report.sh [--out-dir <path>] [--config <path>] [-- <guard_pilot_readiness_check args...>]

Purpose:
  Runs guard_pilot_readiness_check.sh and writes an auditable JSON gate report.
  Exit code mirrors guard_pilot_readiness_check.sh.
USAGE
}

readiness_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      OUT_DIR="${2:-}"
      shift 2
      ;;
    --config)
      CONFIG_FILE="${2:-}"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        readiness_args+=("$1")
        shift
      done
      ;;
    *)
      readiness_args+=("$1")
      shift
      ;;
  esac
done

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
if [[ -z "$OUT_DIR" ]]; then
  OUT_DIR="tmp/guard_gate_reports/$stamp"
fi
mkdir -p "$OUT_DIR"

output_log="$OUT_DIR/readiness_output.log"
json_report="$OUT_DIR/gate_report.json"
runtime_profile_text="$OUT_DIR/runtime_profile.txt"
runtime_profile_json="$OUT_DIR/runtime_profile.json"

command_str="./scripts/guard_pilot_readiness_check.sh"
for arg in "${readiness_args[@]}"; do
  command_str+=" $arg"
done

set +e
./scripts/guard_pilot_readiness_check.sh "${readiness_args[@]}" \
  >"$output_log" 2>&1
exit_code=$?
set -e

status="FAIL"
if [[ "$exit_code" -eq 0 ]]; then
  status="PASS"
fi

artifact_report_path=""
if grep -Eq 'validation_report\.(json|md)' "$output_log"; then
  artifact_report_path="$(grep -Eo 'tmp/guard_field_validation[^ ]+/validation_report\.(json|md)' "$output_log" | tail -n 1 || true)"
fi

./scripts/onyx_runtime_profile.sh --config "$CONFIG_FILE" > "$runtime_profile_text"
./scripts/onyx_runtime_profile.sh --config "$CONFIG_FILE" --json > "$runtime_profile_json"
runtime_profile_json_inline="$(cat "$runtime_profile_json")"

cat > "$json_report" <<EOF
{
  "generated_at_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "$status",
  "exit_code": $exit_code,
  "command": "$command_str",
  "output_log": "$output_log",
  "artifact_report_path": "$artifact_report_path",
  "runtime_profile_file": "$runtime_profile_text",
  "runtime_profile": $runtime_profile_json_inline
}
EOF

echo "Gate status: $status"
echo "Readiness output: $output_log"
echo "Gate JSON report: $json_report"
echo "Runtime profile: $runtime_profile_text"

if [[ "$exit_code" -ne 0 ]]; then
  echo "Readiness failed. Review log above."
  exit "$exit_code"
fi
