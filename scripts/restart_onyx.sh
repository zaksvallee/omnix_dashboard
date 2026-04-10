#!/bin/bash
# ONYX safe restart — stash, pull, restart
set -e

CONFIG_FILE="config/onyx.local.json"
STASH_CREATED=0

echo "Stopping ONYX stack..."
./scripts/stop_onyx.sh --config "$CONFIG_FILE"

echo "Stashing local changes..."
if git diff --quiet && git diff --cached --quiet; then
  echo "No local changes to stash."
else
  git stash push -u -m "onyx-restart-$(date +%Y%m%d-%H%M%S)"
  STASH_CREATED=1
fi

echo "Pulling latest from main..."
git pull --rebase origin main

echo "Restoring local changes..."
if [[ "$STASH_CREATED" -eq 1 ]]; then
  git stash pop || true
else
  echo "No stashed changes to restore."
fi

echo "Starting ONYX stack..."
make
