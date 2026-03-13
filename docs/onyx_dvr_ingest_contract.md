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
    - can require `release_gate.json` and `release_trend_report.json` to pass when those artifacts are part of the DVR pilot decision path
    - now also requires release-gate signoff artifacts to stay inside the active artifact dir when release posture is enforced
  - `scripts/onyx_dvr_mock_validation_artifacts.sh`
  - `scripts/onyx_dvr_pilot_gate.sh`
  - `scripts/onyx_dvr_field_gate.sh`
  - `scripts/onyx_dvr_signoff_generate.sh`
    - emits a sibling `*.json` signoff report on pass and fail once the validation bundle is resolved
    - now rejects release gate or release trend artifacts that point at a different validation or release chain
    - now also rejects release gates that point at different signoff markdown or signoff JSON paths than the signoff being generated
  - `scripts/onyx_dvr_release_gate.sh`
    - emits `release_gate.json` and `release_gate.md` from validation, readiness, and signoff posture
    - rejects contradictory or misaligned signoff audit JSON instead of trusting signoff presence alone
  - `scripts/onyx_dvr_release_trend_check.sh`
    - emits `release_trend_report.json` and `release_trend_report.md` from the current and previous release-gate posture
    - surfaces signoff-to-release mismatches as direct regressions
    - now also fails when a current or previous release gate points its signoff artifacts outside its own staged artifact dir
