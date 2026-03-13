# ONYX Listener Serial Schema

Last updated: 2026-03-13 (Africa/Johannesburg)

## Purpose

This document defines the canonical envelope for the deferred Falcon/FSK serial
listener path before live wire-protocol capture is available.

Current status:
- Bench/schema scaffold only
- Not a production cutover path
- Real wire-protocol validation is still required on hardware

## Canonical Envelope

Serial captures should normalize into:

```json
{
  "provider": "falcon_serial",
  "transport": "serial",
  "external_id": "falcon_serial-ACC-PTN-CODE-ZONE-<ts>",
  "raw_line": "1130 01 004 1234 0001 2026-03-13T08:15:00Z",
  "account_number": "1234",
  "partition": "01",
  "event_code": "130",
  "event_qualifier": "1",
  "zone": "004",
  "user_code": "0001",
  "site_id": "SITE-SANDTON",
  "client_id": "CLIENT-001",
  "region_id": "REGION-GAUTENG",
  "occurred_at_utc": "2026-03-13T08:15:00Z",
  "metadata": {
    "parse_mode": "tokenized",
    "token_count": 6
  }
}
```

## Bench Assumptions

Until a real Falcon/panel capture is available, the bench parser accepts:

1. Tokenized lines:
   - `<qualifier+event_code> <partition> <zone> <account> [user_code] [timestamp]`
2. JSON lines:
   - one JSON object per line using the canonical keys above

These assumptions are deliberately narrow so that real wire capture can replace
them cleanly instead of forcing support for speculative protocol variants.

## Initial Event Mapping

- `130` -> `BURGLARY_ALARM`
- `131` -> `PERIMETER_ALARM`
- `140` -> `GENERAL_ALARM`
- `301` -> `OPENING`
- `302` -> `CLOSING`
- other codes -> `LISTENER_EVENT`

## Bench Replay

Use:

```bash
./scripts/onyx_listener_serial_bench.sh \
  --input tmp/listener_serial_capture/sample.txt \
  --client-id CLIENT-001 \
  --region-id REGION-GAUTENG \
  --site-id SITE-SANDTON
```

The script emits parsed envelopes to `tmp/listener_serial_bench/<timestamp>/parsed.json`.

## Parity Report

Once both paths are available, compare the serial bench output to the legacy
listener export:

```bash
./scripts/onyx_listener_parity_report.sh \
  --serial tmp/listener_serial_bench/<timestamp>/parsed.json \
  --legacy tmp/listener_legacy_export/accepted.json
```

The report emits:
- `matched_count`
- `unmatched_serial_count`
- `unmatched_legacy_count`
- per-event skew in seconds for matched pairs

## Pilot Gate

Once `tmp/listener_capture/` is filled with real capture data:

```bash
./scripts/onyx_listener_pilot_gate.sh \
  --capture-dir tmp/listener_capture \
  --site-id SITE-SANDTON \
  --device-path /dev/ttyUSB0 \
  --legacy-source legacy_listener
```

Then generate the closeout:

```bash
./scripts/onyx_listener_signoff_generate.sh
```

## Non-Goals

- No transmit/control path
- No panel writeback
- No production cutover decision
- No claim that the tokenized parser matches the final Falcon wire protocol
