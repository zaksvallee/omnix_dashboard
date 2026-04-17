#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Compatibility entrypoint restored after the original on-disk script was lost.
# The camera worker watchdog implementation now lives in ensure_camera_worker.sh,
# so this wrapper preserves the historical invocation shape while delegating to
# the maintained watchdog path.
exec ./scripts/ensure_camera_worker.sh --watchdog "$@"
