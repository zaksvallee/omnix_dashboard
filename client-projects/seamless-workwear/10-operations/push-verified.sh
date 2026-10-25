#!/bin/sh
# Run from a normal terminal with GitHub access. No production deployment.
set -eu
project=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
root=$(git -C "$project" rev-parse --show-toplevel)
cd "$root"
branch=build/seamless-independent-quotes-20261025
scope=client-projects/seamless-workwear
case "${1:-}" in
  --resume)
    if [ "$(git branch --show-current)" != "$branch" ]; then
      echo "Resume requires the existing branch: $branch" >&2
      exit 1
    fi
    if [ -n "$(git diff --cached --name-only -- . ":(exclude)$scope" ':(exclude)seamless-workwear-dev')" ]; then
      echo 'Unrelated staged changes found. Preserve them separately before resuming.' >&2
      exit 1
    fi
    ;;
  '')
    if ! git diff --cached --quiet; then
      echo 'Existing staged changes found. Use --resume only for the existing Seamless branch.' >&2
      exit 1
    fi
    if git show-ref --verify --quiet "refs/heads/$branch"; then
      echo "Branch already exists: $branch. Switch to it and use --resume after inspecting its changes." >&2
      exit 1
    fi
    ;;
  *) echo 'Usage: sh push-verified.sh [--resume]' >&2; exit 1 ;;
esac
git ls-remote --exit-code origin HEAD >/dev/null
npm test --prefix "$scope/storefront"
npm run smoke --prefix "$scope/storefront"
if [ "${1:-}" != --resume ]; then git switch -c "$branch"; fi
git add -- "$scope" seamless-workwear-dev
git diff --cached --check
git diff --cached --stat
if ! git diff --cached --quiet HEAD -- "$scope" seamless-workwear-dev; then
  git commit --only -m 'feat(seamless): independent quote requests and tracked build plan' -- "$scope" seamless-workwear-dev
fi
git push -u origin "$branch"
git ls-remote --exit-code origin "refs/heads/$branch"
echo 'Seamless source branch pushed. Production site and DNS have not been deployed.'
