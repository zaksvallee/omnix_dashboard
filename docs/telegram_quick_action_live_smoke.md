# Telegram Quick-Action Live Smoke

Use this run when Vallee or another Telegram-wired client lane is live and you want to confirm ONYX handles `Status` / `Details` quick actions end to end.

## Goal

Confirm that:

- the local ONYX app is running with the real dart-define config
- ONYX consumes the inbound action
- the app terminal logs the handled reply summary

## Commands

Fast path:

```bash
./scripts/telegram_quick_action_live_smoke.sh
```

Manual path:

Start ONYX with the local config:

```bash
./scripts/run_onyx_chrome_local.sh --log-file tmp/telegram_quick_action_live.log -- --web-port 63123
```

In a second terminal, watch the configured Telegram client chat:

```bash
python3 scripts/watch_telegram_updates.py --config config/onyx.local.json
```

In a third terminal, watch only the handled quick-action audit line:

```bash
python3 scripts/watch_onyx_quick_actions.py --log-file tmp/telegram_quick_action_live.log
```

## Live check

While ONYX is running, send `Status` or `Details` from the real client Telegram thread.

Expected signals:

- the quick-action log watcher prints a line like:

```text
ONYX Telegram quick action handled: action=statusFull scope=CLIENT-MS-VALLEE/SITE-MS-VALLEE-RESIDENCE ... reply=🧾 ONYX STATUS (FULL) | MS Vallee Residence | ... | Monitoring: STANDBY | Window: next watch starts 18:00
```

## Notes

- The Telegram Bot API cannot impersonate the client, so a true live smoke needs a real human-originated `Status` or `Details` message.
- The one-command wrapper now defaults to `log watcher only`. This avoids `HTTP 409: Conflict` errors caused by competing `getUpdates` polls against the same bot token.
- `scripts/watch_telegram_updates.py` is still useful as an optional manual tool, but only when you explicitly want raw Telegram queue visibility and are willing to accept API conflicts with the live app poller.
- If the local app is using the Vallee overnight watch config, the expected standby wording outside the watch is:

```text
Monitoring: STANDBY
Window: next watch starts 18:00
```
