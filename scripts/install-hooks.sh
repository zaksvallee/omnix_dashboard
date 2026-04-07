#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_hook="${repo_root}/scripts/post-commit-hook.sh"
target_hook="${repo_root}/.git/hooks/post-commit"

if [[ ! -f "${source_hook}" ]]; then
  echo "Source hook not found: ${source_hook}" >&2
  exit 1
fi

if [[ ! -d "${repo_root}/.git/hooks" ]]; then
  echo "Git hooks directory not found: ${repo_root}/.git/hooks" >&2
  exit 1
fi

cp "${source_hook}" "${target_hook}"
chmod +x "${target_hook}"

echo "Hooks installed."
