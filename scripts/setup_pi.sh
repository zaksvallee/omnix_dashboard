#!/usr/bin/env bash
set -euo pipefail

log() {
  echo "[setup_pi] $*"
}

fail() {
  echo "[setup_pi] ERROR: $*" >&2
  exit 1
}

if [[ "${EUID}" -ne 0 ]]; then
  fail "Run with sudo -E bash scripts/setup_pi.sh so environment variables are preserved."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO_URL="https://github.com/zaksvallee/omnix_dashboard.git"

INSTALL_DIR="${ONYX_INSTALL_DIR:-/opt/onyx}"
REPO_URL="${ONYX_REPO_URL:-$DEFAULT_REPO_URL}"
REPO_BRANCH="${ONYX_REPO_BRANCH:-main}"
FLUTTER_DIR="${ONYX_FLUTTER_DIR:-/opt/flutter}"
APP_USER="${ONYX_APP_USER:-${SUDO_USER:-pi}}"
APP_GROUP="${ONYX_APP_GROUP:-}"

if ! id "$APP_USER" >/dev/null 2>&1; then
  fail "App user '$APP_USER' does not exist."
fi

if [[ -z "$APP_GROUP" ]]; then
  APP_GROUP="$(id -gn "$APP_USER")"
fi

APP_HOME="$(getent passwd "$APP_USER" | cut -d: -f6)"
if [[ -z "$APP_HOME" ]]; then
  fail "Unable to determine home directory for '$APP_USER'."
fi

CONFIG_PATH="${INSTALL_DIR}/config/onyx.local.json"
SYSTEMD_DIR="/etc/systemd/system"

require_any_env() {
  local label="$1"
  shift
  local key=""
  for key in "$@"; do
    if [[ -n "${!key:-}" ]]; then
      return 0
    fi
  done
  fail "Missing ${label}. Export one of: $*"
}

run_as_app_user() {
  local command="$1"
  runuser -u "$APP_USER" -- env \
    HOME="$APP_HOME" \
    PATH="${FLUTTER_DIR}/bin:/usr/lib/dart/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    bash -lc "$command"
}

install_system_packages() {
  log "Updating Raspberry Pi packages"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get upgrade -y

  log "Installing system dependencies"
  apt-get install -y \
    apt-transport-https \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    ffmpeg \
    git \
    gnupg \
    libatlas-base-dev \
    libavcodec-dev \
    libavformat-dev \
    libgl1 \
    libglib2.0-0 \
    libgtk-3-dev \
    libjpeg-dev \
    liblapack-dev \
    libopenblas-dev \
    libpng-dev \
    libswscale-dev \
    libtiff-dev \
    lsof \
    pkg-config \
    python3 \
    python3-dev \
    python3-pip \
    python3-venv \
    unzip \
    xz-utils
}

install_dart_sdk() {
  log "Installing Dart SDK"
  install -d -m 0755 /usr/share/keyrings
  curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub \
    | gpg --dearmor --yes -o /usr/share/keyrings/dart-archive-keyring.gpg
  cat > /etc/apt/sources.list.d/dart_stable.list <<'EOF'
deb [signed-by=/usr/share/keyrings/dart-archive-keyring.gpg] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main
EOF
  apt-get update
  apt-get install -y dart
}

ensure_repo_checkout() {
  log "Cloning ONYX repo into ${INSTALL_DIR}"
  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    git -C "$INSTALL_DIR" fetch --prune origin
    git -C "$INSTALL_DIR" checkout "$REPO_BRANCH"
    git -C "$INSTALL_DIR" pull --ff-only origin "$REPO_BRANCH"
  elif [[ -e "$INSTALL_DIR" && -n "$(find "$INSTALL_DIR" -mindepth 1 -maxdepth 1 2>/dev/null | head -n 1)" ]]; then
    fail "Install directory ${INSTALL_DIR} exists and is not a git checkout."
  else
    rm -rf "$INSTALL_DIR"
    git clone --branch "$REPO_BRANCH" --single-branch "$REPO_URL" "$INSTALL_DIR"
  fi
  chown -R "$APP_USER:$APP_GROUP" "$INSTALL_DIR"
  install -d -o "$APP_USER" -g "$APP_GROUP" "${INSTALL_DIR}/tmp"
}

ensure_flutter_sdk() {
  if [[ "${ONYX_PI_SKIP_FLUTTER:-true}" == "true" ]]; then
    log "Skipping Flutter SDK install (Pi edge mode)"
    return 0
  fi

  if ! grep -q "sdk: flutter" "${INSTALL_DIR}/pubspec.yaml"; then
    return 0
  fi

  log "Installing Flutter SDK for repo dependency resolution"
  if [[ -d "${FLUTTER_DIR}/.git" ]]; then
    git -C "$FLUTTER_DIR" fetch --depth 1 origin stable
    git -C "$FLUTTER_DIR" checkout stable
    git -C "$FLUTTER_DIR" pull --ff-only origin stable
  elif [[ -e "$FLUTTER_DIR" && -n "$(find "$FLUTTER_DIR" -mindepth 1 -maxdepth 1 2>/dev/null | head -n 1)" ]]; then
    fail "Flutter directory ${FLUTTER_DIR} exists and is not a git checkout."
  else
    rm -rf "$FLUTTER_DIR"
    git clone https://github.com/flutter/flutter.git --branch stable --depth 1 "$FLUTTER_DIR"
  fi

  chown -R "$APP_USER:$APP_GROUP" "$FLUTTER_DIR"
  run_as_app_user "flutter config --no-analytics >/dev/null 2>&1 || true"
  run_as_app_user "flutter --version"
}

write_config_from_env() {
  require_any_env "Supabase URL" SUPABASE_URL ONYX_SUPABASE_URL
  require_any_env "Supabase anon key" SUPABASE_ANON_KEY
  require_any_env "Supabase service key" ONYX_SUPABASE_SERVICE_KEY SUPABASE_SERVICE_KEY
  require_any_env "ONYX client ID" ONYX_CLIENT_ID
  require_any_env "ONYX site ID" ONYX_SITE_ID
  require_any_env "camera host or DVR upstream URL" ONYX_HIK_HOST ONYX_DVR_PROXY_UPSTREAM_URL
  require_any_env "camera username" ONYX_HIK_USERNAME ONYX_DVR_PROXY_UPSTREAM_USERNAME
  require_any_env "camera password" ONYX_HIK_PASSWORD ONYX_DVR_PROXY_UPSTREAM_PASSWORD ONYX_DVR_PASSWORD

  log "Generating ${CONFIG_PATH} from environment variables"
  install -d -m 0755 "${INSTALL_DIR}/config"
  python3 - "${INSTALL_DIR}/config/onyx.local.example.json" "$CONFIG_PATH" <<'PY'
import json
import os
import sys
from pathlib import Path

example_path = Path(sys.argv[1])
output_path = Path(sys.argv[2])
config = json.loads(example_path.read_text(encoding="utf-8"))

for key, value in os.environ.items():
    if key.startswith("ONYX_") or key.startswith("SUPABASE_"):
        config[key] = value

if os.environ.get("SUPABASE_URL") and not os.environ.get("ONYX_SUPABASE_URL"):
    config["ONYX_SUPABASE_URL"] = os.environ["SUPABASE_URL"]
if os.environ.get("ONYX_SUPABASE_URL") and not os.environ.get("SUPABASE_URL"):
    config["SUPABASE_URL"] = os.environ["ONYX_SUPABASE_URL"]
if os.environ.get("SUPABASE_SERVICE_KEY") and not os.environ.get("ONYX_SUPABASE_SERVICE_KEY"):
    config["ONYX_SUPABASE_SERVICE_KEY"] = os.environ["SUPABASE_SERVICE_KEY"]

defaults = {
    "ONYX_FR_ENABLED": "true",
    "ONYX_LPR_ENABLED": "true",
    "ONYX_MONITORING_YOLO_ENABLED": "true",
    "ONYX_MONITORING_FR_ENABLED": "true",
    "ONYX_MONITORING_LPR_ENABLED": "true",
    "ONYX_MONITORING_YOLO_HOST": "127.0.0.1",
    "ONYX_MONITORING_YOLO_PORT": "11636",
    "ONYX_MONITORING_YOLO_ENDPOINT": "http://127.0.0.1:11636/detect",
    "ONYX_RTSP_FRAME_SERVER_HOST": "127.0.0.1",
    "ONYX_RTSP_FRAME_SERVER_PORT": "11638",
    "ONYX_RTSP_FRAME_SERVER_ENDPOINT": "http://127.0.0.1:11638",
}

for key, value in defaults.items():
    if key == "ONYX_MONITORING_YOLO_ENABLED" and key not in os.environ:
        config[key] = value
        continue
    if not str(config.get(key, "") or "").strip():
        config[key] = value

output_path.write_text(json.dumps(config, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY
  chown "$APP_USER:$APP_GROUP" "${INSTALL_DIR}/config"
  chown "$APP_USER:$APP_GROUP" "$CONFIG_PATH"
  chmod 600 "$CONFIG_PATH"
}

install_repo_dependencies() {
  log "Installing Dart and Python dependencies for ONYX"
  if grep -q "sdk: flutter" "${INSTALL_DIR}/pubspec.yaml"; then
    run_as_app_user "cd '$INSTALL_DIR' && flutter pub get"
  else
    run_as_app_user "cd '$INSTALL_DIR' && dart pub get"
  fi

  run_as_app_user "cd '$INSTALL_DIR' && ./tool/setup_monitoring_yolo_detector.sh"
  python3 -c "
import json, pathlib
p = pathlib.Path('${CONFIG_PATH}')
c = json.loads(p.read_text())
c['ONYX_MONITORING_YOLO_MODEL'] = 'yolov8s.pt'
c['ONYX_MONITORING_YOLO_IMAGE_SIZE'] = '640'
p.write_text(json.dumps(c, indent=2, sort_keys=True))
"
  log "Pi edge mode: using yolov8s.pt at 640px"
  run_as_app_user "cd '$INSTALL_DIR' && ./.venv-monitoring-yolo/bin/pip install --upgrade opencv-python"
}

setup_swap() {
  if [[ -f /swapfile ]]; then
    log "Swap file already exists at /swapfile — skipping creation"
  else
    log "Creating 2GB swap file at /swapfile"
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
  fi
  if ! grep -q "^/swapfile" /etc/fstab; then
    log "Adding /swapfile to /etc/fstab"
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
  fi
  if [[ ! -f /etc/sysctl.d/99-onyx-swappiness.conf ]]; then
    log "Setting vm.swappiness=10 for conservative swap usage"
    echo 'vm.swappiness=10' > /etc/sysctl.d/99-onyx-swappiness.conf
    sysctl -p /etc/sysctl.d/99-onyx-swappiness.conf
  fi
}

install_systemd_units() {
  log "Installing systemd services"

  cat > "${SYSTEMD_DIR}/onyx-yolo-detector.service" <<EOF
[Unit]
Description=ONYX YOLO detector
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${INSTALL_DIR}
Environment=HOME=${APP_HOME}
Environment=PATH=/usr/lib/dart/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Restart=always
RestartSec=5
ExecStart=/bin/bash -lc 'mkdir -p tmp && exec ./scripts/start_yolo_server.sh --config "${CONFIG_PATH}" >>tmp/onyx_yolo_server.log 2>&1'

[Install]
WantedBy=multi-user.target
EOF

  cat > "${SYSTEMD_DIR}/onyx-rtsp-frame-server.service" <<EOF
[Unit]
Description=ONYX RTSP frame server
After=network-online.target onyx-yolo-detector.service
Wants=network-online.target onyx-yolo-detector.service

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${INSTALL_DIR}
Environment=HOME=${APP_HOME}
Environment=PATH=/usr/lib/dart/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Restart=always
RestartSec=5
ExecStart=/bin/bash -lc 'mkdir -p tmp && exec ./.venv-monitoring-yolo/bin/python ./tool/onyx_rtsp_frame_server.py --config "${CONFIG_PATH}" >>tmp/onyx_rtsp_frame_server.log 2>&1'

[Install]
WantedBy=multi-user.target
EOF

  cat > "${SYSTEMD_DIR}/onyx-dvr-proxy.service" <<EOF
[Unit]
Description=ONYX local Hikvision DVR proxy
After=network-online.target
Wants=network-online.target
Before=onyx-camera-worker.service

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${INSTALL_DIR}
Environment=HOME=${APP_HOME}
Environment=PATH=/usr/lib/dart/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Restart=always
RestartSec=5
ExecStart=/bin/bash -lc 'mkdir -p tmp && exec dart run tool/local_hikvision_dvr_proxy.dart --config "${CONFIG_PATH}" >>tmp/onyx_dvr_proxy.log 2>&1'

[Install]
WantedBy=multi-user.target
EOF

  cat > "${SYSTEMD_DIR}/onyx-camera-worker.service" <<EOF
[Unit]
Description=ONYX camera worker
After=network-online.target onyx-yolo-detector.service onyx-rtsp-frame-server.service onyx-dvr-proxy.service
Wants=network-online.target onyx-yolo-detector.service onyx-rtsp-frame-server.service onyx-dvr-proxy.service

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${INSTALL_DIR}
Environment=HOME=${APP_HOME}
Environment=PATH=/usr/lib/dart/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Restart=always
RestartSec=5
ExecStartPre=/bin/sleep 20
ExecStart=/bin/bash -lc 'mkdir -p tmp && exec ./scripts/run_camera_worker.sh --config "${CONFIG_PATH}" >>tmp/onyx_camera_worker.log 2>&1'

[Install]
WantedBy=multi-user.target
EOF

  cat > "${SYSTEMD_DIR}/onyx-telegram-webhook.service" <<EOF
[Unit]
Description=ONYX Telegram webhook
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${INSTALL_DIR}
Environment=HOME=${APP_HOME}
Environment=PATH=/usr/lib/dart/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Restart=always
RestartSec=5
ExecStart=/bin/bash -lc 'mkdir -p tmp && exec dart run bin/onyx_telegram_webhook.dart >>tmp/onyx_telegram_webhook.log 2>&1'

[Install]
WantedBy=multi-user.target
EOF

  cat > "${SYSTEMD_DIR}/onyx-telegram-ai-processor.service" <<EOF
[Unit]
Description=ONYX Telegram AI processor
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_GROUP}
WorkingDirectory=${INSTALL_DIR}
Environment=HOME=${APP_HOME}
Environment=PATH=/usr/lib/dart/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Restart=always
RestartSec=5
ExecStart=/bin/bash -lc 'mkdir -p tmp && exec dart run bin/onyx_telegram_ai_processor.dart >>tmp/onyx_telegram_ai_processor.log 2>&1'

[Install]
WantedBy=multi-user.target
EOF
}

enable_services() {
  log "Enabling ONYX services on boot"
  systemctl daemon-reload
  systemctl enable --now onyx-yolo-detector.service onyx-rtsp-frame-server.service onyx-dvr-proxy.service onyx-camera-worker.service
}

print_status() {
  log "Current ONYX service status"
  systemctl --no-pager --full --lines=5 status \
    onyx-yolo-detector.service \
    onyx-rtsp-frame-server.service \
    onyx-dvr-proxy.service \
    onyx-camera-worker.service || true
  if [[ -x "${INSTALL_DIR}/scripts/onyx_status.sh" ]]; then
    run_as_app_user "cd '${INSTALL_DIR}' && ./scripts/onyx_status.sh --config '${CONFIG_PATH}'" || true
  fi
}

main() {
  install_system_packages
  install_dart_sdk
  ensure_repo_checkout
  ensure_flutter_sdk
  write_config_from_env
  install_repo_dependencies
  setup_swap
  install_systemd_units
  enable_services
  print_status
  log "Pi edge agent scope: client=${ONYX_CLIENT_ID:-unset} site=${ONYX_SITE_ID:-unset}"
  log "ONYX Raspberry Pi setup complete."
}

main "$@"
