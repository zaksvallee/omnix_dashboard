#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE_HOST="${ONYX_HETZNER_HOST:-root@178.104.91.182}"
REMOTE_APP_DIR="${ONYX_HETZNER_APP_DIR:-/opt/onyx}"
SERVICE_NAME="onyx-telegram-ai-processor.service"
REMOTE_BUILD_DIR="$REMOTE_APP_DIR/telegram_ai_processor_src"
REMOTE_ENV_FILE="${ONYX_HETZNER_ENV_FILE:-$REMOTE_APP_DIR/config/worker.env}"
LOCAL_CONFIG_FILE="${ONYX_LOCAL_CONFIG_FILE:-config/onyx.local.json}"
TEMP_ENV_FILE="$(mktemp)"

cleanup() {
  rm -f "$TEMP_ENV_FILE"
}
trap cleanup EXIT

cd "$ROOT_DIR"

echo "[ONYX] Preparing remote build directory on $REMOTE_HOST..."
ssh "$REMOTE_HOST" "rm -rf $REMOTE_BUILD_DIR && mkdir -p $REMOTE_BUILD_DIR/bin $REMOTE_APP_DIR/bin $(dirname "$REMOTE_ENV_FILE")"

echo "[ONYX] Building managed env sync block from $LOCAL_CONFIG_FILE..."
python3 - "$LOCAL_CONFIG_FILE" > "$TEMP_ENV_FILE" <<'PY'
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
config = json.loads(config_path.read_text())

def pick(*keys: str, default: str = '') -> str:
    for key in keys:
        value = str(config.get(key, '')).strip()
        if value:
            return value
    return default

values = {
    'ONYX_SUPABASE_URL': pick('ONYX_SUPABASE_URL', 'SUPABASE_URL'),
    'ONYX_SUPABASE_SERVICE_KEY': pick('ONYX_SUPABASE_SERVICE_KEY'),
    'ONYX_TELEGRAM_BOT_TOKEN': pick('ONYX_TELEGRAM_BOT_TOKEN'),
    'ONYX_TELEGRAM_AI_OPENAI_API_KEY': pick(
        'ONYX_TELEGRAM_AI_OPENAI_API_KEY',
        'OPENAI_API_KEY',
    ),
    'ONYX_TELEGRAM_AI_OPENAI_MODEL': pick(
        'ONYX_TELEGRAM_AI_OPENAI_MODEL',
        'OPENAI_MODEL',
        default='gpt-5.4',
    ),
    'ONYX_TELEGRAM_AI_OPENAI_ENDPOINT': pick(
        'ONYX_TELEGRAM_AI_OPENAI_ENDPOINT',
        'OPENAI_BASE_URL',
    ),
    'OPENAI_API_KEY': pick('OPENAI_API_KEY'),
    'OPENAI_MODEL': pick('OPENAI_MODEL', default='gpt-5.4'),
    'OPENAI_BASE_URL': pick('OPENAI_BASE_URL'),
    'ONYX_TELEGRAM_CHAT_ID': pick('ONYX_TELEGRAM_CHAT_ID'),
    'ONYX_CLIENT_ID': pick('ONYX_CLIENT_ID'),
    'ONYX_SITE_ID': pick('ONYX_SITE_ID'),
}

print('# BEGIN ONYX TELEGRAM AI PROCESSOR')
for key, value in values.items():
    print(f'{key}={value}')
print('# END ONYX TELEGRAM AI PROCESSOR')
PY

echo "[ONYX] Copying standalone processor source + minimal pubspec..."
scp bin/onyx_telegram_ai_processor.dart "$REMOTE_HOST:$REMOTE_BUILD_DIR/bin/"
scp pubspec_ai_processor.yaml "$REMOTE_HOST:$REMOTE_BUILD_DIR/pubspec.yaml"
scp deploy/$SERVICE_NAME "$REMOTE_HOST:/etc/systemd/system/$SERVICE_NAME"
scp "$TEMP_ENV_FILE" "$REMOTE_HOST:$REMOTE_BUILD_DIR/worker.env.ai"

echo "[ONYX] Syncing required env vars into $REMOTE_ENV_FILE..."
ssh "$REMOTE_HOST" "python3 - <<'PY'
from pathlib import Path

env_path = Path('$REMOTE_ENV_FILE')
env_path.parent.mkdir(parents=True, exist_ok=True)
existing = env_path.read_text() if env_path.exists() else ''

start = '# BEGIN ONYX TELEGRAM AI PROCESSOR'
end = '# END ONYX TELEGRAM AI PROCESSOR'
managed = Path('$REMOTE_BUILD_DIR/worker.env.ai').read_text().strip()
managed_keys = {
    line.split('=', 1)[0]
    for line in managed.splitlines()
    if line and not line.startswith('#') and '=' in line
}

lines = existing.splitlines()
filtered = []
inside = False
for line in lines:
    if line.strip() == start:
        inside = True
        continue
    if line.strip() == end:
        inside = False
        continue
    key = line.split('=', 1)[0].strip() if '=' in line else ''
    if not inside and key not in managed_keys:
        filtered.append(line)

content = '\n'.join(line for line in filtered if line.strip())
if content:
    content = content + '\n\n' + managed + '\n'
else:
    content = managed + '\n'
env_path.write_text(content)
PY"

echo "[ONYX] Compiling Telegram AI processor on remote host..."
ssh "$REMOTE_HOST" "cd $REMOTE_BUILD_DIR && dart pub get && dart compile exe bin/onyx_telegram_ai_processor.dart -o $REMOTE_APP_DIR/bin/onyx_telegram_ai_processor"

echo "[ONYX] Restarting remote systemd service..."
ssh "$REMOTE_HOST" "systemctl daemon-reload && systemctl enable $SERVICE_NAME && systemctl restart $SERVICE_NAME && systemctl status $SERVICE_NAME --no-pager"

echo "[ONYX] Telegram AI processor deployed to $REMOTE_HOST"
