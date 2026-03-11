#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

CONFIG_FILE="config/onyx.local.json"
PROJECT_REF=""
ATTEMPT_LINK=false
DB_PASSWORD="${SUPABASE_DB_PASSWORD:-}"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/guard_supabase_remote_smoke.sh \
    [--config <path>] \
    [--project-ref <ref>] \
    [--attempt-link] \
    [--db-password <password>]

Purpose:
  Verify remote Supabase linkage/migration visibility before running SQL smoke checks.

Notes:
  - SQL smoke files are still intended for Supabase SQL Editor:
    supabase/sql/guard_readiness_smoke_checks.sql
    supabase/sql/guard_actor_contract_checks.sql
  - --attempt-link tries `supabase link` when project is not linked.
USAGE
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

warn() {
  printf 'WARN: %s\n' "$1"
}

pass() {
  printf 'PASS: %s\n' "$1"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      CONFIG_FILE="${2:-$CONFIG_FILE}"
      shift 2
      ;;
    --project-ref)
      PROJECT_REF="${2:-}"
      shift 2
      ;;
    --attempt-link)
      ATTEMPT_LINK=true
      shift
      ;;
    --db-password)
      DB_PASSWORD="${2:-}"
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

if ! command -v supabase >/dev/null 2>&1; then
  fail "supabase CLI not found. Install Supabase CLI first."
fi

infer_project_ref_from_config() {
  local config="$1"
  [[ -f "$config" ]] || return 0
  python3 - "$config" <<'PY'
import json, re, sys
p = sys.argv[1]
try:
    with open(p, 'r', encoding='utf-8') as f:
        data = json.load(f)
except Exception:
    print("")
    raise SystemExit(0)
url = str(data.get('SUPABASE_URL', '')).strip()
m = re.match(r'^https://([a-z0-9-]+)\.supabase\.co/?$', url)
print(m.group(1) if m else "")
PY
}

if [[ -z "$PROJECT_REF" ]]; then
  PROJECT_REF="$(infer_project_ref_from_config "$CONFIG_FILE" | tr -d '\r\n')"
fi

if [[ -n "$PROJECT_REF" ]]; then
  printf 'Project ref: %s\n' "$PROJECT_REF"
else
  warn "Project ref not provided and could not be inferred from $CONFIG_FILE"
fi

if supabase migration list >/tmp/onyx_supabase_migration_list.txt 2>/tmp/onyx_supabase_migration_list.err; then
  pass "supabase migration list succeeded (project linked in this shell)."
  cat /tmp/onyx_supabase_migration_list.txt
else
  warn "supabase migration list failed (not linked or unauthenticated)."
  cat /tmp/onyx_supabase_migration_list.err

  if [[ "$ATTEMPT_LINK" == true ]]; then
    [[ -n "$PROJECT_REF" ]] || fail "--attempt-link needs --project-ref or inferable SUPABASE_URL."
    if [[ -z "$DB_PASSWORD" ]]; then
      fail "--attempt-link requires DB password. Set SUPABASE_DB_PASSWORD or pass --db-password."
    fi
    printf '\nAttempting supabase link for project %s...\n' "$PROJECT_REF"
    if supabase link --project-ref "$PROJECT_REF" --password "$DB_PASSWORD"; then
      pass "supabase link succeeded."
      supabase migration list
    else
      fail "supabase link failed. Confirm supabase auth and DB password."
    fi
  fi
fi

printf '\nRemote SQL smoke files to run in Supabase SQL Editor:\n'
printf '  - %s\n' "$ROOT_DIR/supabase/sql/guard_readiness_smoke_checks.sql"
printf '  - %s\n' "$ROOT_DIR/supabase/sql/guard_actor_contract_checks.sql"

if [[ -n "$PROJECT_REF" ]]; then
  printf '\nSQL Editor URL:\n'
  printf '  https://supabase.com/dashboard/project/%s/sql/new\n' "$PROJECT_REF"
fi
