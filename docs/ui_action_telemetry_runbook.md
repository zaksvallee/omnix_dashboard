# ONYX UI Action Telemetry Runbook

Use this runbook to verify that critical app buttons emit runtime action telemetry.

## 1) Start watcher

```bash
./scripts/guard_android_ui_action_watch.sh --serial <device-serial> --clear
```

If you have only one device connected:

```bash
./scripts/guard_android_ui_action_watch.sh --clear
```

### Optional: run automated coverage check

```bash
./scripts/guard_android_ui_action_check.sh --serial <device-serial> --duration 45
```

This captures `ONYX_UI_ACTION` lines for the duration and prints `PASS/MISS` per required action.

## 2) Trigger key actions in the app

Exercise these controls:

- `Sites Command`:
  - `ADD SITE`
  - `VIEW ON MAP`
  - `SITE SETTINGS`
- `Events Review`:
  - `VIEW IN LEDGER`
  - `EXPORT EVENT DATA`
- `Sovereign Ledger`:
  - `VERIFY CHAIN`
  - `EXPORT LEDGER`
  - `EXPORT ENTRY DATA`
- `Clients`:
  - `Retry Push Sync`
  - `Residents` (room open)
- `Client Intelligence Reports`:
  - `Export All`
  - receipt `Preview` and `Download` (sample or live)
- `Live Operations`:
  - `Pause`
  - `Submit Override`
- `Client App`:
  - incident jump action (`No Incident Selected` / `No Thread Selected` / selected-thread reopen action)
  - quickest path on current web surface: `Clients` page -> tap any `Incident Feed` row
    (emits `client_app.reopen_selected_incident` via `clients_incident_feed` source)

## 3) Expected log examples

You should see lines like:

- `ONYX_UI_ACTION {"action":"sites.add_site", ...}`
- `ONYX_UI_ACTION {"action":"events.export_event_data", ...}`
- `ONYX_UI_ACTION {"action":"ledger.verify_chain", ...}`
- `ONYX_UI_ACTION {"action":"live_operations.pause_automation", ...}`
- `ONYX_UI_ACTION {"action":"client_app.open_first_incident", ...}`
- `ONYX_UI_ACTION {"action":"client_app.reopen_selected_incident", ...}`

## 4) Quick troubleshooting

- No output at all:
  - Confirm device is connected with `adb devices`.
  - Re-run watcher with `--clear`.
- Only `ONYX_TELEMETRY` appears but no `ONYX_UI_ACTION`:
  - Confirm you are pressing the updated CTA controls listed above.
  - Rebuild/reinstall latest app build.
- `zsh: command not found: rg`:
  - This watcher already uses `grep`; no ripgrep required.
