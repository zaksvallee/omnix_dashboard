#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
role_file="${repo_root}/CLAUDE_CODE_ROLE.md"
review_dir="${repo_root}/claude_review"
today="$(TZ=Africa/Johannesburg date +%F)"
claude_bin="${CLAUDE_BIN:-}"

if [[ -z "${claude_bin}" ]]; then
  if command -v claude >/dev/null 2>&1; then
    claude_bin="claude"
  elif command -v claude-code >/dev/null 2>&1; then
    claude_bin="claude-code"
  elif compgen -G "${HOME}/.vscode/extensions/anthropic.claude-code-*/resources/native-binary/claude" >/dev/null 2>&1; then
    claude_bin="$(ls -1d "${HOME}"/.vscode/extensions/anthropic.claude-code-*/resources/native-binary/claude | tail -n 1)"
  else
    echo "claude command not found in PATH" >&2
    exit 1
  fi
fi

mkdir -p "${review_dir}"

audit_target="${1:-}"
mode="repo"
scope_label="repo_wide"
scope_description="${repo_root}"
resolved_target=""

if [[ -n "${audit_target}" ]]; then
  mode="file"
  if [[ "${audit_target}" = /* ]]; then
    resolved_target="${audit_target}"
  else
    resolved_target="${repo_root}/${audit_target}"
  fi

  if [[ ! -e "${resolved_target}" ]]; then
    echo "audit target not found: ${audit_target}" >&2
    exit 1
  fi

  scope_description="${resolved_target}"
  scope_label="$(basename "${resolved_target}")"
  scope_label="${scope_label//./_}"
  scope_label="$(printf '%s' "${scope_label}" | tr -cs '[:alnum:]' '_' | sed 's/^_//; s/_$//; s/__*/_/g')"
  if [[ -z "${scope_label}" ]]; then
    scope_label="target"
  fi
fi

report_path="${review_dir}/audit_${scope_label}_${today}.md"
version=2
while [[ -e "${report_path}" ]]; do
  report_path="${review_dir}/audit_${scope_label}_${today}_v${version}.md"
  version=$((version + 1))
done

if [[ "${mode}" = "repo" ]]; then
  prompt="Read ${role_file} first, then run a read-only structural audit of ${repo_root}. Write findings only to ${report_path}. Never write to /lib/ or /test/."
else
  prompt="Read ${role_file} first, then audit ${scope_description} for structure, bugs, duplication, coverage gaps, and performance concerns. Write findings only to ${report_path}. Never write to /lib/ or /test/."
fi

echo "Starting Claude audit..."
echo "Role file: ${role_file}"
echo "Scope: ${scope_description}"
echo "Report: ${report_path}"

claude_output_file="$(mktemp)"
trap 'rm -f "${claude_output_file}"' EXIT

set +e
"${claude_bin}" \
  -p "${prompt}" \
  --output-format text \
  --dangerously-skip-permissions \
  --permission-mode bypassPermissions \
  --effort low \
  >"${claude_output_file}" 2>&1
claude_status=$?
set -e

if [[ ${claude_status} -ne 0 ]]; then
  cat "${claude_output_file}" >&2
  exit "${claude_status}"
fi

if [[ -s "${claude_output_file}" ]]; then
  cat "${claude_output_file}"
fi

if [[ ! -f "${report_path}" ]]; then
  echo "Claude audit finished but no report was created:" >&2
  echo "${report_path}" >&2
  exit 1
fi

echo "Claude audit report written to:"
echo "${report_path}"
