#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_PYTHON="${ROOT_DIR}/.venv-monitoring-yolo/bin/python"
PYTHON_BIN="${PYTHON_BIN:-}"

if [[ -z "${PYTHON_BIN}" ]]; then
  if [[ -x "${VENV_PYTHON}" ]]; then
    PYTHON_BIN="${VENV_PYTHON}"
  else
    PYTHON_BIN="python3"
  fi
fi

# Force unbuffered stdout/stderr so systemd's log capture sees per-request
# prints, tracebacks, and logging output in real time. Without this, prints
# sit in glibc's block buffer (the fd is a file redirected by systemd, not
# a TTY, so stdout defaults to block-buffering) and nothing reaches the
# service log until the process dies or the buffer fills. This caused the
# YOLO service to appear silent during the MS Vallee freeze investigation.
export PYTHONUNBUFFERED=1

exec "${PYTHON_BIN}" -u "${ROOT_DIR}/tool/monitoring_yolo_detector_service.py" "$@"
