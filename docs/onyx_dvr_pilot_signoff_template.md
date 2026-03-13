# ONYX DVR Pilot Signoff

Date: `<YYYY-MM-DD>`

## Scope
- DVR host: `<host>`
- Provider: `<hikvision_dvr|generic_dvr>`
- Camera: `<camera_id>`
- Zone: `<zone>`
- Event ID: `<event_id>`

## Validation Commands
- `./scripts/onyx_dvr_field_validation.sh --edge-url <dvr_url> --provider <provider> --event-id <event_id> --expect-camera <camera_id> --expect-zone <zone> --capture-dir tmp/dvr_capture`
- `./scripts/onyx_dvr_pilot_readiness_check.sh --provider <provider> --expect-camera <camera_id> --expect-zone <zone> --require-real-artifacts`

## Evidence
- `/bridges` confirms DVR configured and healthy: `yes|no`
- `/pollops` confirms event ingest: `yes|no`
- Snapshot reference retrieved: `yes|no`
- Clip reference retrieved: `yes|no`
- Timeline or Live Operations evidence present: `yes|no`

## Notes
- Operator observations:
- Any event lag:
- Any evidence retrieval anomalies:

## Decision
- DVR pilot checklist items closed: `yes|no`
- Remaining blockers: `none|describe`
