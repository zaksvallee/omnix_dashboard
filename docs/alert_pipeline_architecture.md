# ONYX Alert Pipeline Architecture

## Current design

Primary path:

Pi (edge) -> Hikvision NVR ISAPI `alertStream` -> ONYX camera worker -> YOLO/FR confirm -> Supabase `site_awareness_snapshots` -> Telegram

Backup path:

Mac (relay) -> Supabase `site_awareness_snapshots` polling -> forwards new `active_alerts` to Telegram when the primary sender is unavailable

## Stream ownership

- Single stream owner: Pi
- Reason: Hikvision `alertStream` behaves like a single-owner persistent feed in practice
- The Mac should not compete for the raw NVR stream when the Pi is the active edge node

## Telegram delivery roles

- Telegram primary sender: Pi
- Mac role: backup relay and dashboard host
- The Mac worker now supports passive Telegram relay from shared snapshot state

## Mac runtime wiring

- `ONYX_DVR_EVENTS_URL` can point the Mac worker at a local DVR relay endpoint
- `tool/local_hikvision_dvr_proxy.dart` provides a local relay on `127.0.0.1:11635`
- `scripts/run_camera_worker.sh` now exports DVR event and auth variables so the worker honors the configured relay endpoint

## Expected healthy states

Pi healthy:

- Pi camera worker receives real Hikvision events
- Pi writes fresh `site_awareness_snapshots`
- Pi sends Telegram alerts directly when Telegram credentials are configured

Mac healthy as backup:

- Local DVR proxy is running
- Mac worker starts with `DVR events endpoint override: http://127.0.0.1:11635/ISAPI/Event/notification/alertStream`
- If the Mac does not receive local alert payloads, it can still forward new shared alerts from Supabase to Telegram

## Current observed runtime blockers

- The Mac local DVR proxy now starts, but current health shows upstream reconnecting rather than connected
- SSH verification of the Pi was not possible from this workstation during the audit
- Fresh shared snapshots were observed, but no active alerts were present during the verification window

## Operational guidance

1. Keep the Pi as the only direct `alertStream` owner.
2. Ensure Pi Telegram credentials are present in `/opt/onyx/config/onyx.local.json`.
3. Keep the Mac DVR proxy and worker available as the fallback relay path.
4. Use Supabase `site_awareness_snapshots.active_alerts` as the shared handoff between edge detection and backup Telegram relay.
