#!/usr/bin/env bash
set -euo pipefail

# Run the ONYX camera worker with config from the active dart-define JSON file.
# Usage:
#   ONYX_HIK_PASSWORD=yourpassword ./scripts/run_camera_worker.sh
#   ONYX_HIK_PASSWORD=yourpassword ./scripts/run_camera_worker.sh --config config/onyx.local.json

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG_FILE="${ONYX_DART_DEFINE_FILE:-config/onyx.local.json}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="${2:-}"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "FAIL: Missing dart-define file: $CONFIG_FILE" >&2
  echo "Copy config/onyx.local.example.json to config/onyx.local.json and set runtime keys." >&2
  exit 1
fi

json_value() {
  local key="$1"
  python3 - "$CONFIG_FILE" "$key" <<'PY'
import json
import sys

path, key = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)
value = data.get(key, "")
print("" if value is None else value)
PY
}

json_value_any() {
  local value=""
  for key in "$@"; do
    value="$(json_value "$key" | tr -d '\r')"
    if [[ -n "$value" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
  done
  printf '\n'
}

json_url_part() {
  local key="$1"
  local part="$2"
  python3 - "$CONFIG_FILE" "$key" "$part" <<'PY'
import json
import sys
from urllib.parse import urlparse

path, key, part = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)
raw = str(data.get(key, "") or "").strip()
if not raw:
    print("")
    raise SystemExit(0)
parsed = urlparse(raw)
if part == "host":
    print(parsed.hostname or "")
elif part == "port":
    print(parsed.port or "")
else:
    print("")
PY
}

set_optional_env() {
  local name="$1"
  local value="${2:-}"
  if [[ -n "$value" ]]; then
    export "$name=$value"
  else
    unset "$name"
  fi
}

export ONYX_SUPABASE_URL="$(json_value_any ONYX_SUPABASE_URL SUPABASE_URL)"
export ONYX_SUPABASE_SERVICE_KEY="$(json_value_any ONYX_SUPABASE_SERVICE_KEY SUPABASE_SERVICE_KEY)"
export SUPABASE_ANON_KEY="$(json_value_any SUPABASE_ANON_KEY ONYX_SUPABASE_ANON_KEY)"
set_optional_env ONYX_HIK_HOST "$(json_value_any ONYX_HIK_HOST || true)"
if [[ -z "${ONYX_HIK_HOST:-}" ]]; then
  set_optional_env ONYX_HIK_HOST "$(json_url_part ONYX_DVR_PROXY_UPSTREAM_URL host || true)"
fi
set_optional_env ONYX_HIK_PORT "$(json_value_any ONYX_HIK_PORT || true)"
if [[ -z "${ONYX_HIK_PORT:-}" ]]; then
  set_optional_env ONYX_HIK_PORT "$(json_url_part ONYX_DVR_PROXY_UPSTREAM_URL port || true)"
fi
set_optional_env ONYX_HIK_USERNAME "$(json_value_any ONYX_HIK_USERNAME ONYX_DVR_PROXY_UPSTREAM_USERNAME || true)"
set_optional_env ONYX_HIK_PASSWORD "${ONYX_HIK_PASSWORD:-$(json_value_any ONYX_HIK_PASSWORD ONYX_DVR_PROXY_UPSTREAM_PASSWORD ONYX_DVR_PASSWORD)}"
set_optional_env ONYX_HIK_KNOWN_FAULT_CHANNELS "$(json_value_any ONYX_HIK_KNOWN_FAULT_CHANNELS || true)"
set_optional_env ONYX_CLIENT_ID "$(json_value_any ONYX_CLIENT_ID || true)"
set_optional_env ONYX_SITE_ID "$(json_value_any ONYX_SITE_ID || true)"

exec dart run bin/onyx_camera_worker.dart "$@"
