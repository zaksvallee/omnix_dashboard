#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE_HOST="${ONYX_HETZNER_HOST:-root@178.104.91.182}"
REMOTE_APP_DIR="${ONYX_HETZNER_APP_DIR:-/opt/onyx}"
SERVICE_NAME="onyx-telegram-ai-processor.service"
REMOTE_BUILD_DIR="$REMOTE_APP_DIR/telegram_ai_processor_src"

cd "$ROOT_DIR"

echo "[ONYX] Preparing remote build directory on $REMOTE_HOST..."
ssh "$REMOTE_HOST" "rm -rf $REMOTE_BUILD_DIR && mkdir -p $REMOTE_BUILD_DIR/bin $REMOTE_APP_DIR/bin"

echo "[ONYX] Copying standalone processor source + minimal pubspec..."
scp bin/onyx_telegram_ai_processor.dart "$REMOTE_HOST:$REMOTE_BUILD_DIR/bin/"
scp pubspec_ai_processor.yaml "$REMOTE_HOST:$REMOTE_BUILD_DIR/pubspec.yaml"
scp deploy/$SERVICE_NAME "$REMOTE_HOST:/etc/systemd/system/$SERVICE_NAME"

echo "[ONYX] Compiling Telegram AI processor on remote host..."
ssh "$REMOTE_HOST" "cd $REMOTE_BUILD_DIR && dart pub get && dart compile exe bin/onyx_telegram_ai_processor.dart -o $REMOTE_APP_DIR/bin/onyx_telegram_ai_processor"

echo "[ONYX] Restarting remote systemd service..."
ssh "$REMOTE_HOST" "systemctl daemon-reload && systemctl enable $SERVICE_NAME && systemctl restart $SERVICE_NAME && systemctl status $SERVICE_NAME --no-pager"

echo "[ONYX] Telegram AI processor deployed to $REMOTE_HOST"
