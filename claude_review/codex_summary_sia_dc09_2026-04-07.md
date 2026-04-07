# Codex Summary — SIA DC-09 receiver foundation
Date: 2026-04-07
Workspace: `/Users/zaks/omnix_dashboard`

## Completed

### Core alarm domain model
- Replaced the Contact ID placeholder domain file with the shared typed contract for the receiver stack:
  - `ContactIdFrame`
  - `SiaDc09ParseResult`
  - `SiaParseFailure`
  - `ContactIdPayload`
  - `ContactIdEvent`
- Added `isTestSignal` on `ContactIdPayload` and explicit `isTest` / `isRestore` flags on `ContactIdEvent`.

Files:
- `lib/domain/alarms/contact_id_event.dart`
- `test/domain/alarms/contact_id_event_test.dart`

### DC-09 frame parsing
- Added `SiaDc09FrameParser` with:
  - CRC-16/ARC validation
  - unencrypted frame parsing
  - AES-128-CBC decryption for `*` frames
  - explicit `crcMismatch`, `decryptionFailed`, `malformedFrame`, and `unsupportedFormat` failures
- Exposed `computeCrcHex` / `appendCrc` helpers so tests and the receiver can generate valid frames consistently.

Files:
- `lib/infrastructure/alarm/sia_dc09_frame_parser.dart`
- `test/infrastructure/alarm/sia_dc09_frame_parser_test.dart`

### Contact ID payload parsing
- Added `ContactIdPayloadParser` and `ContactIdParseException`.
- Parser is pure and validates:
  - exact 15-character payload shape
  - message type `18`
  - qualifier codes `1`, `3`, `6`
  - `zone = 000` normalization to `0`

Files:
- `lib/infrastructure/alarm/contact_id_payload_parser.dart`
- `test/infrastructure/alarm/contact_id_payload_parser_test.dart`

### Contact ID event mapping
- Replaced the mapper placeholder with the approved reference-table mapping.
- Implemented:
  - type/severity mapping for the listed code bands
  - restore handling with burglary severity reduction only
  - unknown-code fallback to `IncidentType.other`
  - test-signal tagging for `601–609`
- Event IDs are generated deterministically from frame/payload content.

Files:
- `lib/domain/alarms/contact_id_event_mapper.dart`
- `test/domain/alarms/contact_id_event_mapper_test.dart`

### Supabase-backed account registry
- Added `AlarmAccountRegistry` with:
  - `alarm_accounts` lookup
  - `onyx_settings` port lookup with `5072` fallback
  - global/env AES key parsing from `ONYX_ALARM_AES_KEY`
  - per-account AES override decoding
- Added the initial schema migration for:
  - `public.onyx_settings`
  - `public.alarm_accounts`

Files:
- `lib/application/alarm_account_registry.dart`
- `test/application/alarm_account_registry_test.dart`
- `supabase/migrations/202604070002_create_alarm_receiver_registry.sql`

### Contact ID receiver service
- Replaced the receiver placeholder with a working TCP service.
- Service now:
  - binds on a configurable host/port
  - buffers partial socket input until `CRLF`
  - parses each frame through `SiaDc09FrameParser`
  - returns `ACK` for valid frames and `NAK` for invalid ones
  - tracks duplicates per account
  - handles sequence wrap-around from `65535 -> 0`
  - times out idle sockets without crashing the server

Files:
- `lib/infrastructure/alarm/contact_id_receiver_service.dart`
- `test/infrastructure/alarm/contact_id_receiver_service_test.dart`

### Alarm triage gateway
- Added `AlarmTriageGateway` to bridge receiver frames into ONYX triage without wiring production yet.
- Gateway behavior:
  - parses payloads
  - maps Contact ID events
  - audits every mapped event
  - suppresses duplicate frames from triage
  - suppresses test signals from triage while still auditing them
  - routes restores to `onRestore`
  - builds `OnyxWorkItem` objects for true triage candidates
  - uses fallback `unknown_account_{account}` / `unknown_site_{account}` scope ids when no registry match exists

Files:
- `lib/application/alarm_triage_gateway.dart`
- `test/application/alarm_triage_gateway_test.dart`

## Validation

- Per-layer `dart analyze` runs after each implementation step
- Final repo-wide `dart analyze`
- Final focused receiver/BI bundle:
  - `flutter test test/domain/alarms/contact_id_event_test.dart test/infrastructure/alarm/sia_dc09_frame_parser_test.dart test/infrastructure/alarm/contact_id_payload_parser_test.dart test/domain/alarms/contact_id_event_mapper_test.dart test/application/alarm_account_registry_test.dart test/infrastructure/alarm/contact_id_receiver_service_test.dart test/application/alarm_triage_gateway_test.dart test/application/carwash_bi_demo_fixture_test.dart`

Result:
- All analyze runs passed.
- All focused tests passed.

## Not wired yet

- `main.dart` was intentionally not modified.
- The receiver is not started anywhere in production/runtime code yet.
- No ONYX route or admin action activates the server.
- Activation still needs an explicit follow-up confirmation from Zaks.

## Notes

- The receiver/service implementation uses `dart:io`, but it remains isolated and unreferenced by the current Flutter runtime.
- The account registry uses `onyx_settings.key = 'sia_dc09_port'` and `alarm_accounts.account_number` / `client_id` / `site_id` / `aes_key_override` per the approved decision.
- Test signals are accepted, tagged `isTest`, audited, and intentionally never promoted into triage work items.
