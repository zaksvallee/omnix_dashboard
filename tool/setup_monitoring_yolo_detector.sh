#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${ROOT_DIR}/.venv-monitoring-yolo"
PYTHON_BIN="${PYTHON_BIN:-python3}"
ARCH="$(uname -m)"
REQUIREMENTS="tool/monitoring_yolo_detector.requirements.txt"

if [[ "$ARCH" == "aarch64" || "$ARCH" == "armv7l" ]]; then
  REQUIREMENTS="tool/monitoring_yolo_detector.requirements.pi.txt"
fi

REQ_FILE="${ROOT_DIR}/${REQUIREMENTS}"

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "Python interpreter not found: ${PYTHON_BIN}" >&2
  exit 1
fi

"${PYTHON_BIN}" -m venv "${VENV_DIR}"
"${VENV_DIR}/bin/python" -m pip install --upgrade pip
if [[ "$ARCH" == "aarch64" || "$ARCH" == "armv7l" ]]; then
  "${VENV_DIR}/bin/pip" install \
    --index-url https://download.pytorch.org/whl/cpu \
    torch \
    torchvision
fi
"${VENV_DIR}/bin/pip" install -r "${REQ_FILE}"

cat <<EOF
ONYX monitoring YOLO environment is ready.
Venv: ${VENV_DIR}
Requirements: ${REQUIREMENTS}

Next:
  ${ROOT_DIR}/tool/start_monitoring_yolo_detector.sh --config ${ROOT_DIR}/config/onyx.local.json
EOF
