# CCTV Pilot Edge Scaffold

This folder provides the ONYX Phase 1 pilot edge scaffold for:

- Frigate with embedded `go2rtc`
- Mosquitto MQTT broker
- One pilot camera with:
  - sub-stream for detection
  - main stream for evidence recording

## What ONYX Expects

Configure ONYX with the pilot edge endpoint:

- `ONYX_CCTV_PROVIDER=frigate`
- `ONYX_CCTV_EVENTS_URL=https://<edge-host>/api/events`
- `ONYX_CCTV_LIVE_MONITORING=true`
- `ONYX_CCTV_FALSE_POSITIVE_RULES_JSON=[...]` when suppression rules are needed
- `ONYX_CCTV_EVIDENCE_QUEUE_DEPTH=12`
- `ONYX_CCTV_STALE_FRAME_SECONDS=1800`

ONYX consumes:

- Frigate event feed from `/api/events`
- deterministic snapshot refs from `/api/events/<event_id>/snapshot.jpg`
- deterministic clip refs from `/api/events/<event_id>/clip.mp4`
- MQTT topic prefix `frigate`

## Bring-Up Notes

1. Create the Mosquitto password file at `./mosquitto/config/passwords`.
2. Replace the sample RTSP credentials and camera IPs in `./frigate/config.yml`.
3. Adjust the `north_gate` zone coordinates to the real scene.
4. Start the stack with `docker compose up -d`.
5. Confirm:
   - Frigate UI is reachable on port `5000`
   - embedded `go2rtc` is reachable on port `1984`
   - MQTT broker is reachable on port `1883`
6. Run `./validate_pilot.sh` after the first event, optionally with `EVENT_ID=<frigate_event_id>`.
7. Save the ONYX `/bridges`, `/pollops`, and Live Operations or timeline outputs to text files.
8. Run `./scripts/onyx_cctv_field_validation.sh` from the repo root to generate a pilot validation report under `tmp/cctv_field_validation/`.

## Pilot Validation

Before marking the pilot live:

- Confirm detection uses the sub-stream input (`pilot_gate_sub`)
- Confirm recording uses the main-stream input (`pilot_gate_main`)
- Trigger a test event and verify:
  - `/bridges` shows CCTV configured and healthy
  - `/pollops` ingests the event
  - Live Operations shows snapshot/clip evidence refs
- Recommended report command:
  ```bash
  ./scripts/onyx_cctv_field_validation.sh \
    --edge-url https://<edge-host> \
    --event-id <frigate_event_id> \
    --expect-camera pilot_gate \
    --expect-zone north_gate \
    --capture-dir tmp/cctv_capture
  ```
- Output artifacts:
  - `tmp/cctv_field_validation/<timestamp>/validation_report.md`
  - `tmp/cctv_field_validation/<timestamp>/validation_report.json`
