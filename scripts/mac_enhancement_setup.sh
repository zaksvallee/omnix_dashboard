#!/usr/bin/env bash
# =====================================================================
# mac_enhancement_setup.sh — one-time setup for the Mac enhancement tier.
#
# Creates a dedicated venv at .venv-mac-enhancement, installs PyTorch
# with MPS support + ultralytics + face_recognition + easyocr, and
# downloads yolo11l.pt into models/. Safe to re-run.
#
# Usage:
#   scripts/mac_enhancement_setup.sh
#
# Then launch with:
#   scripts/mac_enhancement_start.sh
# =====================================================================

set -euo pipefail

log()  { printf '[mac-setup] %s\n' "$*"; }
die()  { printf '[mac-setup] ERROR: %s\n' "$*" >&2; exit 1; }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${ROOT_DIR}/.venv-mac-enhancement"
MODELS_DIR="${ROOT_DIR}/models"
MODEL_FILE="${MODELS_DIR}/yolo11l.pt"

# ---- Host checks ----
if [[ "$(uname -s)" != "Darwin" ]]; then
  die "This script is for macOS. Detected: $(uname -s)"
fi
ARCH="$(uname -m)"
if [[ "${ARCH}" != "arm64" ]]; then
  log "WARNING: Detected architecture '${ARCH}'. MPS acceleration is only"
  log "WARNING: available on arm64 (Apple Silicon). Installation will"
  log "WARNING: continue but inference will fall back to CPU."
fi

# ---- Python ----
PYTHON_BIN="${PYTHON_BIN:-python3}"
if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  die "python3 not on PATH. Install via 'brew install python@3.12' first."
fi
PY_MAJOR_MINOR="$("${PYTHON_BIN}" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
log "python: ${PYTHON_BIN} (version ${PY_MAJOR_MINOR})"

# ---- Build tools for face_recognition / dlib ----
if ! command -v cmake >/dev/null 2>&1; then
  log "cmake not found — installing via Homebrew (dlib build needs it)"
  if ! command -v brew >/dev/null 2>&1; then
    die "Homebrew not installed. Install from https://brew.sh/ first."
  fi
  brew install cmake
else
  log "cmake: $(cmake --version | head -1)"
fi

# ---- Venv ----
if [[ ! -d "${VENV_DIR}" ]]; then
  log "creating venv at ${VENV_DIR}"
  "${PYTHON_BIN}" -m venv "${VENV_DIR}"
else
  log "venv already exists at ${VENV_DIR} — reusing"
fi
# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

log "upgrading pip/setuptools/wheel inside venv"
pip install --upgrade pip setuptools wheel

# ---- PyTorch with MPS (default arm64 wheel supports MPS) ----
log "installing torch + torchvision (arm64 wheels include MPS support)"
pip install --upgrade torch torchvision

# ---- Inference stack ----
log "installing ultralytics (YOLO), easyocr, face_recognition"
pip install --upgrade ultralytics easyocr face_recognition

# Optional but useful — ultralytics tracker needs lap; works on x86_64 /
# Apple Silicon (the ARM64 hang is a Pi-specific wheel issue).
log "installing lap for ByteTrack (ultralytics tracker)"
pip install --upgrade "lap>=0.5.12"

# ---- Model weights ----
mkdir -p "${MODELS_DIR}"
if [[ -f "${MODEL_FILE}" ]]; then
  log "model already present: ${MODEL_FILE}"
else
  log "downloading yolo11l.pt to ${MODEL_FILE}"
  # `yolo download` is the ultralytics-supported way; writes to cwd by
  # default, so move it into models/ afterwards.
  ( cd "${MODELS_DIR}" && yolo download model=yolo11l.pt )
  if [[ ! -f "${MODEL_FILE}" ]]; then
    die "yolo11l.pt not found at ${MODEL_FILE} after download"
  fi
fi

# ---- Done ----
log ""
log "=============================================================="
log " Mac enhancement tier setup complete."
log ""
log "   venv:   ${VENV_DIR}"
log "   model:  ${MODEL_FILE}"
log ""
log " Start the enhancement server:"
log "   scripts/mac_enhancement_start.sh"
log ""
log " Point the Pi's camera worker at this Mac (from your Mac):"
log "   IP=\$(ipconfig getifaddr en0)  # or en1"
log "   echo \"ONYX_MONITORING_YOLO_ENDPOINT=http://\${IP}:11636/detect\""
log "=============================================================="
