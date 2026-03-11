#!/usr/bin/env bash
set -euo pipefail

ARTIFACT_PATH=""
PROVIDER_ID=""
MAX_RESULTS=40
SHOW_ALL=0

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/guard_android_vendor_sdk_inspect.sh --artifact <path-to-aar-or-jar> [--provider fsk_sdk|hikvision_sdk] [--max-results 40] [--show-all]

Purpose:
  Inspect vendor SDK artifacts (.aar/.jar), list class names, and suggest likely
  manager/listener/connector classes for reflective ONYX telemetry integration.

Examples:
  ./scripts/guard_android_vendor_sdk_inspect.sh --artifact android/app/libs/fsk-sdk.aar --provider fsk_sdk
  ./scripts/guard_android_vendor_sdk_inspect.sh --artifact android/app/libs/hikvision-sdk.jar --provider hikvision_sdk --show-all
USAGE
}

pass() { printf "PASS: %s\n" "$1"; }
warn() { printf "WARN: %s\n" "$1"; }
fail() { printf "FAIL: %s\n" "$1"; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact)
      ARTIFACT_PATH="${2:-}"
      shift 2
      ;;
    --provider)
      PROVIDER_ID="${2:-}"
      shift 2
      ;;
    --max-results)
      MAX_RESULTS="${2:-40}"
      shift 2
      ;;
    --show-all)
      SHOW_ALL=1
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

if [[ -z "$ARTIFACT_PATH" ]]; then
  fail "--artifact is required."
fi
if [[ ! -f "$ARTIFACT_PATH" ]]; then
  fail "Artifact not found: $ARTIFACT_PATH"
fi
if ! [[ "$MAX_RESULTS" =~ ^[0-9]+$ ]] || [[ "$MAX_RESULTS" -lt 1 ]]; then
  fail "--max-results must be a positive integer."
fi

if ! command -v unzip >/dev/null 2>&1; then
  fail "unzip is required but not found on PATH."
fi

tmp_dir="$(mktemp -d)"
cleanup() { rm -rf "$tmp_dir"; }
trap cleanup EXIT

artifact_lower="$(echo "$ARTIFACT_PATH" | tr '[:upper:]' '[:lower:]')"
jar_paths=()

if [[ "$artifact_lower" == *.aar ]]; then
  unzip -qq "$ARTIFACT_PATH" -d "$tmp_dir/aar"
  if [[ -f "$tmp_dir/aar/classes.jar" ]]; then
    jar_paths+=("$tmp_dir/aar/classes.jar")
  fi
  while IFS= read -r jar_file; do
    [[ -n "$jar_file" ]] && jar_paths+=("$jar_file")
  done < <(find "$tmp_dir/aar" -type f -path "*/libs/*.jar" | sort)
elif [[ "$artifact_lower" == *.jar ]]; then
  jar_paths+=("$ARTIFACT_PATH")
else
  fail "Unsupported artifact type. Use .aar or .jar"
fi

if [[ "${#jar_paths[@]}" -eq 0 ]]; then
  fail "No classes.jar or embedded jars found in artifact: $ARTIFACT_PATH"
fi

list_jar_entries() {
  local jar_file="$1"
  if command -v jar >/dev/null 2>&1; then
    jar tf "$jar_file"
    return 0
  fi
  unzip -Z1 "$jar_file"
}

classes_file="$tmp_dir/classes.txt"
touch "$classes_file"

for jar_file in "${jar_paths[@]}"; do
  list_jar_entries "$jar_file" \
    | grep -E '\.class$' \
    | grep -v '/R(\$.*)?\.class$' \
    | grep -v '/BuildConfig\.class$' \
    | sed 's#/#.#g; s#\.class$##' \
    | sort -u >> "$classes_file" || true
done

sort -u "$classes_file" -o "$classes_file"
class_count="$(wc -l < "$classes_file" | tr -d ' ')"
if [[ "$class_count" -eq 0 ]]; then
  fail "No class symbols discovered in artifact."
fi

provider_token=""
if [[ -n "$PROVIDER_ID" ]]; then
  provider_token="$(echo "$PROVIDER_ID" | tr '[:upper:]' '[:lower:]')"
  provider_token="${provider_token%%_*}"
fi

rank_candidates() {
  local input_pattern="$1"
  local input_file="$2"
  local out_file="$3"
  grep -Ei "$input_pattern" "$input_file" > "$out_file.raw" || true
  if [[ -z "$provider_token" ]]; then
    sort -u "$out_file.raw" > "$out_file"
    return 0
  fi
  {
    grep -Ei "$provider_token" "$out_file.raw" || true
    grep -Eiv "$provider_token" "$out_file.raw" || true
  } | awk '!seen[$0]++' > "$out_file"
}

manager_candidates="$tmp_dir/manager_candidates.txt"
callback_candidates="$tmp_dir/callback_candidates.txt"
connector_candidates="$tmp_dir/connector_candidates.txt"

rank_candidates '(Manager|TelemetryService|SdkManager|TelemetryManager|TelemetryClient)$' "$classes_file" "$manager_candidates"
rank_candidates '(Listener|Callback)$' "$classes_file" "$callback_candidates"
rank_candidates 'Connector$' "$classes_file" "$connector_candidates"

echo "== ONYX Vendor SDK Inspect =="
echo "Artifact: $ARTIFACT_PATH"
echo "Provider: ${PROVIDER_ID:-<unset>}"
echo "Resolved jars: ${#jar_paths[@]}"
echo "Discovered classes: $class_count"
echo ""

print_candidates() {
  local title="$1"
  local file="$2"
  local csv_limit="${3:-6}"
  local count
  count="$(wc -l < "$file" | tr -d ' ')"
  echo "$title ($count):"
  if [[ "$count" -eq 0 ]]; then
    echo "  <none>"
    echo ""
    return 0
  fi
  head -n "$MAX_RESULTS" "$file" | sed 's/^/  - /'
  local csv
  csv="$(head -n "$csv_limit" "$file" | paste -sd, -)"
  if [[ -n "$csv" ]]; then
    echo "  Suggested CSV: $csv"
  fi
  echo ""
}

print_candidates "Manager candidates" "$manager_candidates" 8
print_candidates "Callback candidates" "$callback_candidates" 8
print_candidates "Connector candidates" "$connector_candidates" 4

if [[ "$SHOW_ALL" -eq 1 ]]; then
  echo "All classes:"
  sed 's/^/  /' "$classes_file"
  echo ""
else
  echo "Tip: pass --show-all to print every discovered class."
fi

pass "Inspection complete."
