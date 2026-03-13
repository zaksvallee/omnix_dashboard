# ONYX Listener Pilot Signoff

Date: `<YYYY-MM-DD>` (`Africa/Johannesburg`)

## Scope
- Capture pack dir: `tmp/listener_capture`
- Parity artifact dir: `tmp/listener_parity/<timestamp>`
- Serial device path: `<tty_device>`
- Legacy source: `<legacy_listener_source>`

## Validation Commands
- Serial bench replay:
  - `./scripts/onyx_listener_serial_bench.sh --input tmp/listener_capture/serial_raw.txt --client-id <client_id> --region-id <region_id> --site-id <site_id>`
- Parity report:
  - `./scripts/onyx_listener_parity_report.sh --serial tmp/listener_parity/<timestamp>/serial_parsed.json --legacy tmp/listener_capture/legacy_events.json`
- Readiness gate:
  - `./scripts/onyx_listener_parity_readiness_check.sh --report-json tmp/listener_parity/<timestamp>/report.json --require-real-artifacts`

## Results
- Summary: `<summary>`
- Serial count: `<count>`
- Legacy count: `<count>`
- Matched count: `<count>`
- Unmatched serial count: `<count>`
- Unmatched legacy count: `<count>`

## Notes
- Wiring notes:
- Timestamp/skew notes:
- Missing-event notes:
- Contract/commercial notes:

## Decision
- Listener parity acceptable for pilot: `<yes/no>`
- Remaining blockers:
