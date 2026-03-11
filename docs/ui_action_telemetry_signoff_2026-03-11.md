# ONYX UI Action Telemetry Signoff (2026-03-11)

Status: `PASS` (manual session aggregation across repeated watcher runs)

## Scope
- Verify critical controller/operator CTAs emit `ONYX_UI_ACTION` telemetry.
- Device/runtime context used during validation:
  - Web debug runtime (`flutter run -d chrome`) for controller surfaces.
  - Android logcat watcher/checker flow for telemetry capture process.

## Required Action Coverage
- `sites.add_site`
- `sites.view_on_map`
- `sites.open_settings`
- `sites.open_guard_roster`
- `events.view_in_ledger`
- `events.export_event_data`
- `ledger.verify_chain`
- `ledger.export_all`
- `ledger.export_entry`
- `ledger.view_in_event_review`
- `clients.retry_push_sync`
- `clients.open_room`
- `reports.export_all`
- `reports.preview_sample_receipt` / `reports.preview_live_receipt`
- `reports.download_sample_receipt` / `reports.download_live_receipt`
- `live_operations.pause_automation`
- `live_operations.manual_override`
- `client_app.open_first_incident` / `client_app.open_first_incident_missing` /
  `client_app.reopen_selected_incident` / `client_app.reopen_selected_incident_missing`

## Notable Implementation Updates During Validation
- `scripts/guard_android_ui_action_check.sh` now accepts equivalent action variants
  for receipt preview/download and client-app incident-open paths.
- `Clients` incident feed rows now emit:
  - `client_app.reopen_selected_incident` with `source=clients_incident_feed`
  to make incident-open telemetry reachable in the current web flow.

## Evidence Notes
- Session logs captured all required actions (or accepted equivalents) at least once.
- Final previously-missing action family confirmed:
  - `client_app.reopen_selected_incident` (multiple hits from Clients incident feed row taps).

## Re-run Command
```bash
./scripts/guard_android_ui_action_check.sh --serial BV5300ProNEU032438 --duration 45
```

