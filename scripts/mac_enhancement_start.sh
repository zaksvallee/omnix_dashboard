#!/usr/bin/env bash
# Run this when on Vallee WiFi to enable enhancement tier for alerts.
#
# Starts the ONYX enhancement tier (YOLO + FR + LPR + weapon) on the Mac,
# binding to all interfaces so the Pi on the LAN can reach it at
# http://<mac-ip>:11636/detect.
#
# Usage:
#   scripts/mac_enhancement_start.sh
#
# Ctrl-C to stop. Logs stream to the terminal AND tee into a persistent
# log file at tmp/onyx_mac_enhancement.log so post-hoc analysis (e.g. of
# [ONYX-YOLO-TIMING] latency) has history to grep after a crash or
# terminal scroll-back loss.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${ROOT_DIR}/.venv-mac-enhancement"
SERVICE_PY="${ROOT_DIR}/tool/monitoring_yolo_detector_service.py"
CONFIG_FILE="${ROOT_DIR}/config/onyx.mac_enhancement.json"
LOG_DIR="${ROOT_DIR}/tmp"
LOG_FILE="${LOG_DIR}/onyx_mac_enhancement.log"

if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
  echo "[mac-start] ERROR: venv not found at ${VENV_DIR}" >&2
  echo "[mac-start] Run scripts/mac_enhancement_setup.sh first." >&2
  exit 1
fi
if [[ ! -f "${CONFIG_FILE}" ]]; then
  echo "[mac-start] ERROR: config not found at ${CONFIG_FILE}" >&2
  exit 1
fi
if [[ ! -f "${SERVICE_PY}" ]]; then
  echo "[mac-start] ERROR: service not found at ${SERVICE_PY}" >&2
  exit 1
fi

mkdir -p "${LOG_DIR}"

# Show the LAN IP the Pi should point at, if we can figure it out.
LAN_IP=""
for iface in en0 en1 en2 en3; do
  IP="$(ipconfig getifaddr "${iface}" 2>/dev/null || true)"
  if [[ -n "${IP}" ]]; then
    LAN_IP="${IP}"
    echo "[mac-start] LAN IP on ${iface}: ${LAN_IP}"
    break
  fi
done
if [[ -z "${LAN_IP}" ]]; then
  echo "[mac-start] WARNING: couldn't determine LAN IP (no en0..en3 active)"
fi
echo "[mac-start] Listening on :11636 (bound to 0.0.0.0 per config)"
if [[ -n "${LAN_IP}" ]]; then
  echo "[mac-start] Point the Pi camera worker at:"
  echo "[mac-start]   ONYX_MONITORING_YOLO_ENDPOINT=http://${LAN_IP}:11636/detect"
fi
echo "[mac-start] Persistent log: ${LOG_FILE}"
echo "[mac-start] Ctrl-C to stop."
echo ""

export ONYX_DART_DEFINE_FILE="${CONFIG_FILE}"
# Unbuffered output so logs stream to this terminal in real time (matches
# the tooling added for the Pi service in commit d6e53f7).
export PYTHONUNBUFFERED=1

# tee so output goes to both the terminal AND the log file. Ctrl-C still
# propagates to the python process — tee exits when its upstream closes.
# `exec` replaces this shell so signals reach python directly.
exec "${VENV_DIR}/bin/python" -u "${SERVICE_PY}" --config "${CONFIG_FILE}" \
  2>&1 | tee -a "${LOG_FILE}"
