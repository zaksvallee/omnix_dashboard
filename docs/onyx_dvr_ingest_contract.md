# ONYX DVR Ingest Contract

Last updated: 2026-03-13 (Africa/Johannesburg)

Purpose:
- prepare DVR work without creating a second ONYX event model
- keep DVR events on the same normalized intelligence/evidence path as CCTV edge events

Shared contract:
- `lib/application/video_edge_ingest_contract.dart`
  - common video analytics capability flags
  - common evidence-access model
  - common normalized event contract that emits `NormalizedIntelRecord`
- `lib/application/video_bridge_runtime.dart`
  - provider-neutral bridge fetch interface
  - provider-neutral evidence probe snapshot used by runtime health
  - CCTV adapters so `main.dart` now depends on a shared video bridge surface
- `lib/application/video_bridge_health_formatter.dart`
  - provider-neutral bridge and pilot summary formatting
  - shared `/bridges` and `/pollops` summary surface for CCTV now, DVR next

DVR scaffold:
- `lib/application/dvr_ingest_contract.dart`
  - provider profile metadata
  - private evidence URL templates
  - fixture-backed normalization scaffold
- `lib/application/dvr_bridge_service.dart`
  - live HTTP DVR bridge backed by the shared contract normalizer
  - provider-profile factory for Hikvision and generic DVR transports

Current provider profiles:
- `hikvision_dvr`
  - schema: `hikvision_isapi_event_notification_alert`
  - transport: `isapi_pull`
  - evidence mode: private fetch
- `generic_dvr`
  - schema: `generic_dvr_event_list`
  - transport: `http_pull`
  - evidence mode: private fetch

Normalized fields expected from DVR adapters:
- provider
- source type
- external event id
- client / region / site ids
- camera id
- channel id
- zone
- object label / confidence when available
- FR match id / confidence when available
- plate number / confidence when available
- headline
- risk score
- occurred-at timestamp
- snapshot and clip references

Rules:
- DVR adapters should emit `VideoEdgeEventContract`, then convert to `NormalizedIntelRecord`.
- Snapshot/clip references should default to private-fetch URLs, not public endpoints.
- Channel identity should stay explicit in the summary even if `NormalizedIntelRecord` still stores only `cameraId`.
- FR/LPR annotations should only surface when the provider profile enables those capabilities.

Fixture refs:
- `test/fixtures/dvr_hikvision_isapi_event_notification_alert_sample.json`
- `test/fixtures/dvr_generic_event_sample.json`

Current scope:
- not yet field-proven against a live DVR
- shared runtime and health-summary path is in place
- DVR-specific live bridge implementation is built
- DVR provider selection is wired into runtime env/config with CCTV-first precedence
- DVR-specific evidence probe implementation is built with provider auth support and per-camera health
- DVR field-tooling scaffold is in place:
  - `scripts/onyx_dvr_capture_pack_init.sh`
  - `scripts/onyx_dvr_field_validation.sh`
  - `scripts/onyx_dvr_pilot_readiness_check.sh`
    - emits `readiness_report.json` and `readiness_report.md` in the validation artifact dir
  - `scripts/onyx_dvr_mock_validation_artifacts.sh`
  - `scripts/onyx_dvr_pilot_gate.sh`
  - `scripts/onyx_dvr_field_gate.sh`
  - `scripts/onyx_dvr_signoff_generate.sh`
