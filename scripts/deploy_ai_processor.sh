#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE_HOST="${ONYX_HETZNER_HOST:-root@178.104.91.182}"
REMOTE_APP_DIR="${ONYX_HETZNER_APP_DIR:-/opt/onyx}"
SERVICE_NAME="onyx-telegram-ai-processor.service"
BUNDLE_DIR="build/telegram_ai_processor"

cd "$ROOT_DIR"

echo "[ONYX] Compiling Telegram AI processor..."
rm -rf "$BUNDLE_DIR"
dart build cli -t bin/onyx_telegram_ai_processor.dart -o "$BUNDLE_DIR"

echo "[ONYX] Copying binary and service file to $REMOTE_HOST..."
ssh "$REMOTE_HOST" "rm -rf $REMOTE_APP_DIR/telegram_ai_processor && mkdir -p $REMOTE_APP_DIR/telegram_ai_processor"
scp -r "$BUNDLE_DIR/bundle" "$REMOTE_HOST:$REMOTE_APP_DIR/telegram_ai_processor/"
scp deploy/$SERVICE_NAME "$REMOTE_HOST:/etc/systemd/system/$SERVICE_NAME"

echo "[ONYX] Restarting remote systemd service..."
ssh "$REMOTE_HOST" "systemctl daemon-reload && systemctl enable $SERVICE_NAME && systemctl restart $SERVICE_NAME && systemctl status $SERVICE_NAME --no-pager"

echo "[ONYX] Telegram AI processor deployed to $REMOTE_HOST"
