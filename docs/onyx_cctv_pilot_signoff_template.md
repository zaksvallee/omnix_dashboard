# ONYX CCTV Pilot Signoff

Date: `<YYYY-MM-DD>` (`Africa/Johannesburg`)

## Scope
- Pilot site: `<site_id>`
- Edge host: `<edge_url>`
- Camera: `<camera_id>`
- Zone: `<zone>`
- Provider: `frigate`
- Event ID: `<frigate_event_id>`

## Validation Commands
- Field validation:
  - `./scripts/onyx_cctv_field_validation.sh --edge-url <edge_url> --event-id <frigate_event_id> --expect-camera <camera_id> --expect-zone <zone> --capture-dir tmp/cctv_capture`
- Readiness gate:
  - `./scripts/onyx_cctv_pilot_readiness_check.sh --provider frigate --expect-camera <camera_id> --expect-zone <zone> --require-real-artifacts`

## Results
- Field validation overall status: `<PASS|FAIL|INCOMPLETE>`
- Readiness gate overall status: `<PASS|FAIL>`
- Validation artifact dir: `tmp/cctv_field_validation/<timestamp>`
- Capture pack dir: `tmp/cctv_capture`

## Evidence
- `/bridges` confirms CCTV configured and healthy: `<yes/no>`
- `/pollops` confirms event ingest: `<yes/no>`
- Snapshot reference retrieved: `<yes/no>`
- Clip reference retrieved: `<yes/no>`
- Timeline or Live Operations evidence present: `<yes/no>`

## Notes
- Event latency observation:
- Controller notes:
- Operator notes:
- Any anomalies or recovery actions:

## Decision
- Pilot Phase 1 checklist items closed: `<yes/no>`
- Remaining blockers:
