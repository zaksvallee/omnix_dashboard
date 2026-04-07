# Hik-Connect OpenAPI Rollout Prep

This note captures the cloud-first Hik-Connect preparation that is already in
the repo and the exact runtime inputs we still need before enabling live ONYX
monitoring for approved sites.

## What Is Already Wired

- Application provider support: `hik_connect_openapi`
- Token flow:
  - `POST /api/hccgw/platform/v1/token/get`
- Alarm queue flow:
  - `POST /api/hccgw/alarm/v1/mq/subscribe`
  - `POST /api/hccgw/alarm/v1/mq/messages`
  - `POST /api/hccgw/alarm/v1/mq/messages/complete`
- Camera discovery:
  - `POST /api/hccgw/resource/v1/areas/cameras/get`
- Live video address lookup:
  - `POST /api/hccgw/video/v1/live/address/get`
- Playback scaffolding:
  - `POST /api/hccgw/video/v1/record/element/search`
  - `POST /api/hccgw/video/v1/video/download/url`

Relevant code:

- `/Users/zaks/omnix_dashboard/lib/application/hik_connect_openapi_config.dart`
- `/Users/zaks/omnix_dashboard/lib/application/hik_connect_openapi_client.dart`
- `/Users/zaks/omnix_dashboard/lib/application/hik_connect_camera_bootstrap_service.dart`
- `/Users/zaks/omnix_dashboard/lib/application/hik_connect_bootstrap_runtime_config.dart`
- `/Users/zaks/omnix_dashboard/lib/application/hik_connect_bootstrap_orchestrator_service.dart`
- `/Users/zaks/omnix_dashboard/lib/application/hik_connect_bootstrap_packet_service.dart`
- `/Users/zaks/omnix_dashboard/lib/application/hik_connect_env_seed_formatter.dart`
- `/Users/zaks/omnix_dashboard/lib/application/hik_connect_scope_seed_formatter.dart`
- `/Users/zaks/omnix_dashboard/lib/application/dvr_bridge_service.dart`
- `/Users/zaks/omnix_dashboard/lib/application/dvr_ingest_contract.dart`
- `/Users/zaks/omnix_dashboard/lib/application/dvr_scope_config.dart`
- `/Users/zaks/omnix_dashboard/lib/application/ops_integration_profile.dart`
- `/Users/zaks/omnix_dashboard/lib/main.dart`
- `/Users/zaks/omnix_dashboard/tool/hik_connect_bootstrap.dart`

## Runtime Inputs We Still Need

Before switching a real site to cloud monitoring, collect:

- `appKey`
- `appSecret`
- production API base URL
- one real `mq/messages` response
- one real camera list response
- one real live-address response
- if available, one real playback search response

These are the pieces that will let us harden the generic normalizer into a
tenant-accurate production mapping.

## Env-Based Fallback Config

The app now supports a cloud DVR fallback path through these env vars:

- `ONYX_DVR_PROVIDER=hik_connect_openapi`
- `ONYX_DVR_API_BASE_URL=https://<hik-connect-host>`
- `ONYX_DVR_APP_KEY=<app-key>`
- `ONYX_DVR_APP_SECRET=<app-secret>`
- `ONYX_DVR_AREA_ID=-1`
- `ONYX_DVR_INCLUDE_SUB_AREA=true`
- `ONYX_DVR_DEVICE_SERIAL_NO=<optional-device-serial>`
- `ONYX_DVR_ALARM_EVENT_TYPES=0,1,100657`

Use env fallback only for a single-site pilot or temporary smoke setup.

## One-Command Tenant Bootstrap

As soon as a tenant is approved, you can run the first inventory/bootstrap pull
directly from env:

- `ONYX_DVR_CLIENT_ID=<client-id>`
- `ONYX_DVR_REGION_ID=<region-id>`
- `ONYX_DVR_SITE_ID=<site-id>`
- `ONYX_DVR_API_BASE_URL=https://<hik-connect-host>`
- `ONYX_DVR_APP_KEY=<app-key>`
- `ONYX_DVR_APP_SECRET=<app-secret>`

Optional:

- `ONYX_DVR_PROVIDER=hik_connect_openapi`
- `ONYX_DVR_AREA_ID=-1`
- `ONYX_DVR_INCLUDE_SUB_AREA=true`
- `ONYX_DVR_DEVICE_SERIAL_NO=<optional-device-serial>`
- `ONYX_DVR_ALARM_EVENT_TYPES=0,1,100657`
- `ONYX_DVR_PAGE_SIZE=200`
- `ONYX_DVR_MAX_PAGES=20`

Then run:

```sh
dart run tool/hik_connect_bootstrap.dart
```

That one command now returns:

- rollout readiness
- warnings
- full discovered camera summary
- ready-to-paste scope JSON
- ready-to-paste pilot env block

If you already have a saved Hik-Connect camera list payload before live
credentials are ready, you can bootstrap offline by adding:

- `ONYX_DVR_CAMERA_PAYLOAD_PATH=/absolute/path/to/camera-pages.json`

The payload file may be:

- one raw `areas/cameras/get` API response
- a JSON array of raw page responses
- or an object with a top-level `"pages"` array

## One-Command Payload Collection

If live tenant credentials are already available, you can collect a full raw
preflight bundle straight from Hik-Connect:

- `ONYX_DVR_PREFLIGHT_DIR=/absolute/path/to/bundle`
- `ONYX_DVR_CLIENT_ID=<client-id>`
- `ONYX_DVR_REGION_ID=<region-id>`
- `ONYX_DVR_SITE_ID=<site-id>`
- `ONYX_DVR_API_BASE_URL=https://<hik-connect-host>`
- `ONYX_DVR_APP_KEY=<app-key>`
- `ONYX_DVR_APP_SECRET=<app-secret>`

Optional:

- `ONYX_DVR_AREA_ID=-1`
- `ONYX_DVR_INCLUDE_SUB_AREA=true`
- `ONYX_DVR_DEVICE_SERIAL_NO=<optional-device-serial>`
- `ONYX_DVR_REPRESENTATIVE_CAMERA_ID=<preferred-resource-id>`
- `ONYX_DVR_REPRESENTATIVE_DEVICE_SERIAL_NO=<preferred-device-serial>`
- `ONYX_DVR_PAGE_SIZE=200`
- `ONYX_DVR_MAX_PAGES=20`
- `ONYX_DVR_PLAYBACK_LOOKBACK_MINUTES=60`
- `ONYX_DVR_PLAYBACK_WINDOW_MINUTES=5`

Then run:

```sh
dart run tool/hik_connect_collect_bundle.dart
```

That command writes:

- `camera-pages.json`
- `alarm-messages.json`
- `live-address.json`
- `playback-search.json`
- `video-download.json`

into the bundle directory, ready for the existing preflight flow.

If you already know which camera should be used for the first live/playback
sample, set `ONYX_DVR_REPRESENTATIVE_CAMERA_ID` and optionally
`ONYX_DVR_REPRESENTATIVE_DEVICE_SERIAL_NO` so the collector does not just use
the first discovered camera in the tenant inventory.

After a live collection run, the collector writes the resolved representative
camera and serial back into `bundle-manifest.json`, so reruns can keep using
the same representative camera even if those env overrides are not set again.
It also writes the resolved collection settings back into the manifest:

- `area_id`
- `include_sub_area`
- `device_serial_no`
- `alarm_event_types`
- `camera_labels`
- `page_size`
- `max_pages`
- `playback_lookback_minutes`
- `playback_window_minutes`

So reruns can keep using the same Hik-Connect scope filters, pagination, and
playback sampling window even if the shell env changes. Curated
`camera_labels` in the bundle also feed back into collection and preflight so
operator-facing names stop depending on raw Hikvision camera names.

If you want collection and report generation in one pass, run:

```sh
dart run tool/hik_connect_collect_preflight.dart
```

That command:

- collects the raw Hik-Connect payload bundle
- runs the same bundle preflight immediately
- writes `preflight-report.md`
- writes `preflight-report.json`
- writes `scope-seed.json`
- writes `pilot-env.sh`
- writes `bootstrap-packet.md`

## Offline Alarm Smoke

If you already have a saved `mq/messages` payload, you can preview how ONYX
will normalize it before live tenant wiring:

- `ONYX_DVR_CLIENT_ID=<client-id>`
- `ONYX_DVR_REGION_ID=<region-id>`
- `ONYX_DVR_SITE_ID=<site-id>`
- `ONYX_DVR_ALARM_PAYLOAD_PATH=/absolute/path/to/mq-messages.json`

Optional:

- `ONYX_DVR_API_BASE_URL=https://<hik-connect-host>`

Then run:

```sh
dart run tool/hik_connect_alarm_smoke.dart
```

This prints:

- normalized vs dropped message count
- each ONYX headline
- external id
- camera and area mapping
- ANPR plate when present
- summary/evidence URLs

## Offline Video Smoke

If you already have saved live/playback/download responses, you can preview the
operator-side video data shape before live UI wiring:

- `ONYX_DVR_LIVE_ADDRESS_PAYLOAD_PATH=/absolute/path/to/live-address.json`
- `ONYX_DVR_PLAYBACK_PAYLOAD_PATH=/absolute/path/to/playback-search.json`
- `ONYX_DVR_VIDEO_DOWNLOAD_PAYLOAD_PATH=/absolute/path/to/video-download.json`

Provide at least one, then run:

```sh
dart run tool/hik_connect_video_smoke.dart
```

This prints:

- primary live URL and protocol variants
- playback record windows and URLs
- video download URL when present

## Combined Offline Preflight

If you want one combined rollout report across saved camera, alarm, and video
payloads, provide any subset of:

- `ONYX_DVR_PREFLIGHT_DIR=/absolute/path/to/payload-bundle`
- `ONYX_DVR_CAMERA_PAYLOAD_PATH`
- `ONYX_DVR_ALARM_PAYLOAD_PATH`
- `ONYX_DVR_LIVE_ADDRESS_PAYLOAD_PATH`
- `ONYX_DVR_PLAYBACK_PAYLOAD_PATH`
- `ONYX_DVR_VIDEO_DOWNLOAD_PAYLOAD_PATH`

If `ONYX_DVR_PREFLIGHT_DIR` is set, the preflight tool will automatically look
for these default files inside that folder:

- `bundle-manifest.json`
- `camera-pages.json`
- `alarm-messages.json`
- `live-address.json`
- `playback-search.json`
- `video-download.json`

The optional `bundle-manifest.json` can carry the site metadata and custom file
names, for example:

```json
{
  "client_id": "CLIENT-MS-VALLEE",
  "region_id": "REGION-GAUTENG",
  "site_id": "SITE-MS-VALLEE-RESIDENCE",
  "api_base_url": "https://api.hik-connect.example.com",
  "area_id": "-1",
  "include_sub_area": true,
  "device_serial_no": "",
  "alarm_event_types": [0, 1, 100657],
  "camera_labels": {
    "camera-front": "Front Gate"
  },
  "representative_camera_id": "camera-front",
  "representative_device_serial_no": "SERIAL-001",
  "page_size": 200,
  "max_pages": 20,
  "playback_lookback_minutes": 60,
  "playback_window_minutes": 5,
  "report_path": "preflight-report.md",
  "report_json_path": "preflight-report.json",
  "camera_payload_path": "cams.json",
  "alarm_payload_path": "alarms.json",
  "live_address_payload_path": "live.json"
}
```

The generated preflight report now includes a `Payload Inventory` section that
distinguishes:

- `found`
- `configured but missing`
- `unset`

So the first tenant run can tell the difference between a missing file path and
an empty or incorrect bundle reference.

It also includes a `Next Steps` section that turns partial results into a
collection/action checklist, for example fixing a missing bundle path, adding an
alarm sample, or capturing live/playback payloads for the first pilot.

## Bundle Scaffold Command

If you want a ready-made payload bundle folder before Hikvision data starts
arriving, run:

```sh
dart run tool/hik_connect_init_bundle.dart /absolute/path/to/bundle
```

Optional env overrides:

- `ONYX_DVR_CLIENT_ID`
- `ONYX_DVR_REGION_ID`
- `ONYX_DVR_SITE_ID`
- `ONYX_DVR_API_BASE_URL`

That command creates:

- `bundle-manifest.json`
- `camera-pages.json`
- `alarm-messages.json`
- `live-address.json`
- `playback-search.json`
- `video-download.json`
- `README.md`

After you run preflight against the bundle, ONYX now writes the saved report to:

- `preflight-report.md`
- `preflight-report.json`
- `scope-seed.json`
- `pilot-env.sh`
- `bootstrap-packet.md`

or to the custom output paths from the manifest:

- `report_path`
- `report_json_path`
- `scope_seed_path`
- `pilot_env_path`
- `bootstrap_packet_path`

The machine-readable `preflight-report.json` also includes a
`rollout_artifacts` block so later automation can discover the saved scope
seed, pilot env, and bootstrap packet paths directly.

When preflight runs against a real bundle directory, ONYX also writes a compact
last-run summary back into `bundle-manifest.json`, including:

- `last_preflight_at_utc`
- `last_rollout_readiness`
- `last_report_path`
- `last_report_json_path`
- `last_scope_seed_path`
- `last_pilot_env_path`
- `last_bootstrap_packet_path`

plus top-level camera/alarm/video readiness counters for quick bundle inspection.

You can read that summary without rerunning Hik-Connect by pointing ONYX at the
bundle:

```sh
dart run tool/hik_connect_bundle_status.dart /absolute/path/to/bundle
```

Or use:

- `ONYX_DVR_PREFLIGHT_DIR`

If you want the same snapshot as machine-readable JSON, add:

```sh
dart run tool/hik_connect_bundle_status.dart --json /absolute/path/to/bundle
```

If you want a non-zero exit code when the bundle is not actually ready, add:

```sh
dart run tool/hik_connect_bundle_status.dart --strict /absolute/path/to/bundle
```

That returns exit code `2` when the bundle is still pending or incomplete.

If you also want stale bundles to fail the same gate, add a max age:

```sh
dart run tool/hik_connect_bundle_status.dart --strict --max-age-hours=1 /absolute/path/to/bundle
```

Or use:

- `ONYX_DVR_BUNDLE_MAX_AGE_HOURS`

If you want the bundle itself to carry that freshness rule, set
`status_max_age_hours` in `bundle-manifest.json`. The status command will use
that manifest value when no CLI flag or env override is provided.

The status command now also prints concrete next steps, and the `--json` form
includes `warnings` plus `next_steps` so automation can explain why a bundle is
not ready without parsing the prose summary.

When a bundle has `last_collection_at_utc` recorded, the same max-age rule also
applies to the saved collection snapshot. So a bundle can now go `STALE`
because the payload pull itself is too old, even if the files still exist.

## Sanitized Share Export

If you need to share a preflight bundle safely, export a sanitized copy:

```sh
dart run tool/hik_connect_export_sanitized_bundle.dart /absolute/path/to/source-bundle /absolute/path/to/sanitized-bundle
```

Or use env:

- `ONYX_DVR_PREFLIGHT_DIR`
- `ONYX_DVR_SANITIZED_BUNDLE_DIR`

The sanitized export keeps the payload structure but redacts:

- tokens
- app keys and secrets
- bearer/password fields
- live/download/playback URLs

It also sanitizes the generated rollout artifacts inside the bundle, including:

- `scope-seed.json`
- `pilot-env.sh`
- `bootstrap-packet.md`

When camera or alarm payloads are included, also set:

- `ONYX_DVR_CLIENT_ID`
- `ONYX_DVR_REGION_ID`
- `ONYX_DVR_SITE_ID`

Then run:

```sh
dart run tool/hik_connect_preflight.dart
```

This prints one combined report with:

- camera bootstrap readiness
- alarm normalization summary
- live/playback/download availability
- a rollout readiness line across the payloads you supplied

## Preferred Multi-Site Scope Config

For multi-site rollout, prefer per-site DVR scope JSON instead of one global
env-only config. Example:

```json
[
  {
    "client_id": "CLIENT-MS-VALLEE",
    "region_id": "REGION-GAUTENG",
    "site_id": "SITE-MS-VALLEE-RESIDENCE",
    "provider": "hik_connect_openapi",
    "api_base_url": "https://api.hik-connect.example.com",
    "app_key": "replace-me",
    "app_secret": "replace-me",
    "area_id": "-1",
    "include_sub_area": true,
    "device_serial_no": "SERIAL-001",
    "alarm_event_types": [0, 1, 100657],
    "camera_labels": {
      "camera-front": "Front Yard",
      "camera-back": "Back Yard",
      "camera-drive": "Driveway"
    }
  }
]
```

Notes:

- `area_id=-1` is a common "all visible areas" placeholder for early rollout.
- `alarm_event_types` should be tightened once the approved tenant payloads are
  confirmed.
- `camera_labels` are optional but strongly recommended for cleaner ONYX
  summaries.

## Recommended First Live Rollout

1. Start with one site:
   - `CLIENT-MS-VALLEE / SITE-MS-VALLEE-RESIDENCE`
2. Use pull-based alarm intake first.
3. Run a full camera bootstrap pull and convert it into a scope seed:
   - fetch all camera pages
   - inspect the discovered device serials
   - export the suggested `camera_labels` map
   - paste the generated scope seed into the DVR scope config
4. Confirm:
   - token fetch works
   - queue subscription succeeds
   - `mq/messages` returns stable `alarmMsg` payloads
   - ONYX normalizes alarms and ANPR events correctly
   - live address returns a usable stream URL
5. Only then widen to multiple sites.

## What Is Still Not Done

- Real tenant payload normalization is not locked yet.
- Live view/playback operator surfaces are not yet wired to Hik-Connect stream
  addresses.
- A callback/webhook relay has not been introduced yet; the current prep is
  pull-first.

## Safest Next Step After Approval

As soon as Hikvision approves the integration and exposes credentials, provide:

- the credential screen
- base host or regional host details
- a real alarm batch payload
- a real camera listing payload
- a real live-address payload

That is the point where we should switch from generic scaffolding to the
production ONYX cloud integration path.
