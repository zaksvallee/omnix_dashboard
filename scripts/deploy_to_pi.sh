#!/usr/bin/env bash
# =====================================================================
# deploy_to_pi.sh — rsync + sudo systemctl restart over SSH.
#
# Solves two recurring deployment annoyances:
#   1. `ssh host "sudo ..."` fails with "a terminal is required to read
#      the password". We force TTY allocation via `ssh -t` for commands
#      that touch sudo.
#   2. Rsyncing half a dozen files + remembering which systemd unit
#      owns each service is error-prone. Each target below bundles the
#      file list + the unit name + an optional post-restart probe.
#
# The script is intentionally boring: explicit per-target file lists,
# explicit service names, explicit probes. When a new file belongs to a
# target, add it to the target. No wildcards, no implicit discovery.
#
# Usage:
#   scripts/deploy_to_pi.sh --target=yolo
#   scripts/deploy_to_pi.sh --target=dvr-proxy
#   scripts/deploy_to_pi.sh --target=camera-worker
#   scripts/deploy_to_pi.sh --target=rtsp
#   scripts/deploy_to_pi.sh --target=setup
#   scripts/deploy_to_pi.sh --target=all
#
# Flags:
#   --target=<name>   one of yolo|dvr-proxy|camera-worker|rtsp|setup|all
#   --host=<u@host>   override target host (default: onyx@192.168.0.67)
#   --no-restart      rsync only; skip systemctl restart
#   --no-probe        skip post-restart health probe
#   --dry-run         print commands without running them
#   -h, --help        this message
#
# Env overrides (useful for CI / alternate Pi):
#   ONYX_HOST         default onyx@192.168.0.67
#   ONYX_REMOTE_ROOT  default /opt/onyx
#
# SSH auth:
#   If key-based auth isn't set up yet, every SSH/rsync step will
#   prompt for the `onyx` password interactively. Sudo steps prompt
#   AGAIN for the same password (once ssh-copy-id is done, the SSH
#   prompts go away; the sudo prompt stays unless NOPASSWD is set).
#   One-time fix for password-prompt fatigue:
#     ssh-copy-id onyx@192.168.0.67
#     ssh onyx@192.168.0.67 'echo "onyx ALL=(root) NOPASSWD: /bin/systemctl" | sudo tee /etc/sudoers.d/onyx-systemctl'
# =====================================================================

set -euo pipefail

ONYX_HOST="${ONYX_HOST:-onyx@192.168.0.67}"
ONYX_REMOTE_ROOT="${ONYX_REMOTE_ROOT:-/opt/onyx}"
LOCAL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

TARGET=""
NO_RESTART=0
NO_PROBE=0
DRY_RUN=0

log()  { printf '[deploy] %s\n' "$*" >&2; }
die()  { printf '[deploy] ERROR: %s\n' "$*" >&2; exit 1; }
run()  { log "+ $*"; [[ "${DRY_RUN}" -eq 1 ]] || "$@"; }

usage() {
  sed -n '3,45p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# ---------------------------------------------------------------------
# Primitives
# ---------------------------------------------------------------------

# rsync_pair <local-relative-path> <remote-absolute-path>
rsync_pair() {
  local rel="$1"
  local dst="$2"
  local src="${LOCAL_ROOT}/${rel}"
  [[ -f "${src}" ]] || die "missing local file: ${src}"
  run rsync -avz "${src}" "${ONYX_HOST}:${dst}"
}

# restart_service <systemd-unit>
# Uses ssh -t so `sudo` has a TTY and can read the password prompt.
restart_service() {
  local svc="$1"
  log "Restarting ${svc} on ${ONYX_HOST} (sudo will prompt for password)"
  run ssh -t "${ONYX_HOST}" "sudo systemctl restart ${svc}"
  # is-active check doesn't need sudo
  run ssh "${ONYX_HOST}" "systemctl is-active ${svc} || true"
}

# probe_yolo: wait for warmup then hit /health and tail the log.
probe_yolo() {
  log "Waiting 45s for YOLO warmup"
  [[ "${DRY_RUN}" -eq 1 ]] || sleep 45
  run ssh "${ONYX_HOST}" "curl -s --max-time 10 http://127.0.0.1:11636/health"
  echo
  run ssh "${ONYX_HOST}" "tail -40 /opt/onyx/tmp/onyx_yolo_server.log || true"
}

probe_dvr_proxy() {
  log "Probing DVR proxy (5s grace)"
  [[ "${DRY_RUN}" -eq 1 ]] || sleep 5
  run ssh "${ONYX_HOST}" \
    "ss -tlnp 2>/dev/null | grep 11635 || echo '[deploy] proxy not listening yet'"
}

probe_camera_worker() {
  log "Camera worker restart probe: logs tail"
  [[ "${DRY_RUN}" -eq 1 ]] || sleep 5
  run ssh "${ONYX_HOST}" \
    "tail -40 /opt/onyx/tmp/onyx_camera_worker.log || true"
}

probe_rtsp() {
  log "RTSP frame server probe: logs tail"
  [[ "${DRY_RUN}" -eq 1 ]] || sleep 3
  run ssh "${ONYX_HOST}" \
    "tail -40 /opt/onyx/tmp/onyx_rtsp_frame_server.log || true"
}

# ---------------------------------------------------------------------
# Targets
# ---------------------------------------------------------------------

deploy_yolo() {
  log "=== target: yolo ==="
  rsync_pair tool/monitoring_yolo_detector_service.py \
             "${ONYX_REMOTE_ROOT}/tool/monitoring_yolo_detector_service.py"
  rsync_pair tool/start_monitoring_yolo_detector.sh \
             "${ONYX_REMOTE_ROOT}/tool/start_monitoring_yolo_detector.sh"
  if [[ "${NO_RESTART}" -eq 0 ]]; then
    restart_service "onyx-yolo-detector"
  fi
  if [[ "${NO_PROBE}" -eq 0 && "${NO_RESTART}" -eq 0 ]]; then
    probe_yolo
  fi
}

deploy_dvr_proxy() {
  log "=== target: dvr-proxy ==="
  # The tool entry imports from lib/application/local_hikvision_dvr_proxy_service.dart,
  # which holds the actual fix surface (commits 0c416c0, 260a46d). Sync both.
  rsync_pair tool/local_hikvision_dvr_proxy.dart \
             "${ONYX_REMOTE_ROOT}/tool/local_hikvision_dvr_proxy.dart"
  rsync_pair lib/application/local_hikvision_dvr_proxy_service.dart \
             "${ONYX_REMOTE_ROOT}/lib/application/local_hikvision_dvr_proxy_service.dart"
  if [[ "${NO_RESTART}" -eq 0 ]]; then
    restart_service "onyx-dvr-proxy"
  fi
  if [[ "${NO_PROBE}" -eq 0 && "${NO_RESTART}" -eq 0 ]]; then
    probe_dvr_proxy
  fi
}

deploy_camera_worker() {
  log "=== target: camera-worker ==="
  rsync_pair bin/onyx_camera_worker.dart \
             "${ONYX_REMOTE_ROOT}/bin/onyx_camera_worker.dart"
  # Camera worker doesn't depend on any lib/ files we've changed this
  # session beyond what the dart-run resolves at start. Add more
  # rsync_pair lines here if that changes.
  if [[ "${NO_RESTART}" -eq 0 ]]; then
    restart_service "onyx-camera-worker"
  fi
  if [[ "${NO_PROBE}" -eq 0 && "${NO_RESTART}" -eq 0 ]]; then
    probe_camera_worker
  fi
}

deploy_rtsp() {
  log "=== target: rtsp ==="
  rsync_pair tool/onyx_rtsp_frame_server.py \
             "${ONYX_REMOTE_ROOT}/tool/onyx_rtsp_frame_server.py"
  if [[ "${NO_RESTART}" -eq 0 ]]; then
    restart_service "onyx-rtsp-frame-server"
  fi
  if [[ "${NO_PROBE}" -eq 0 && "${NO_RESTART}" -eq 0 ]]; then
    probe_rtsp
  fi
}

deploy_setup() {
  log "=== target: setup ==="
  # Installer itself; no service restart on its own.
  rsync_pair scripts/setup_pi.sh \
             "${ONYX_REMOTE_ROOT}/scripts/setup_pi.sh"
  rsync_pair scripts/start_yolo_server.sh \
             "${ONYX_REMOTE_ROOT}/scripts/start_yolo_server.sh"
}

deploy_all() {
  deploy_setup
  deploy_rtsp
  deploy_yolo
  deploy_dvr_proxy
  deploy_camera_worker
}

# ---------------------------------------------------------------------
# Arg parse + dispatch
# ---------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target=*)    TARGET="${1#--target=}" ;;
    --target)      TARGET="${2:-}"; shift ;;
    --host=*)      ONYX_HOST="${1#--host=}" ;;
    --host)        ONYX_HOST="${2:-}"; shift ;;
    --no-restart)  NO_RESTART=1 ;;
    --no-probe)    NO_PROBE=1 ;;
    --dry-run)     DRY_RUN=1 ;;
    -h|--help)     usage; exit 0 ;;
    *)             die "unknown arg: $1" ;;
  esac
  shift
done

[[ -n "${TARGET}" ]] || die "missing --target=<name> (see --help)"

case "${TARGET}" in
  yolo)            deploy_yolo ;;
  dvr-proxy)       deploy_dvr_proxy ;;
  camera-worker)   deploy_camera_worker ;;
  rtsp)            deploy_rtsp ;;
  setup)           deploy_setup ;;
  all)             deploy_all ;;
  *)               die "unknown target: ${TARGET}" ;;
esac

log "done"
