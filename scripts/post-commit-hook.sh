#!/usr/bin/env bash
set -u

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${repo_root}" ]]; then
  exit 0
fi

audit_script="${repo_root}/scripts/run_claude_audit.sh"
if [[ ! -x "${audit_script}" ]]; then
  exit 0
fi

found_dart_file=0

while IFS= read -r -d '' changed_file; do
  [[ "${changed_file}" == *.dart ]] || continue
  [[ "${changed_file}" == test/* ]] && continue
  [[ -f "${repo_root}/${changed_file}" ]] || continue

  found_dart_file=1
  if ! "${audit_script}" "${changed_file}"; then
    echo "post-commit Claude audit skipped after error: ${changed_file}" >&2
  fi
done < <(git diff-tree --root --no-commit-id --name-only -r -z HEAD 2>/dev/null || true)

if [[ "${found_dart_file}" -eq 0 ]]; then
  exit 0
fi

exit 0
