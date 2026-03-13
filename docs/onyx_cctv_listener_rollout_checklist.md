# ONYX CCTV + Listener Rollout Checklist

Last updated: 2026-03-13 (Africa/Johannesburg)

## Scope and Priority

- Current priority: CCTV ingestion + ONYX bridge hardening.
- Deferred: Falcon/FSK listener bypass path (marked **TBC** until hardware is on hand).

---

## 1) CCTV Package Decision (Now)

- [x] Confirm primary package: **Frigate + go2rtc at site edge**.
- [x] Confirm ONYX stance: no dependency on Hikvision cloud event API for core detection.
- [x] Confirm architecture:
  - Edge: Frigate + go2rtc + MQTT broker.
  - ONYX: consume MQTT events + fetch snapshot/clip on demand.
  - Evidence: hash metadata + media references into ONYX ledger flow.
- [x] Confirm security posture:
  - VPN/overlay networking (WireGuard/Tailscale).
  - No public RTSP port forwarding.

---

## 2) CCTV MVP Build (Next)

- [ ] Provision one edge node (pilot site).
- [x] Add camera stream profiles:
  - Sub-stream for continuous detection.
  - Main stream for evidence/snapshot quality.
- [x] Enable Frigate event transport (MQTT topics) for ONYX bridge.
- [x] Implement ONYX `cctv_bridge_service` event mapping:
  - Camera ID, site ID, zone, label, confidence, timestamp.
- [x] Implement ONYX media pull path:
  - Snapshot URL fetch on event.
  - Clip reference fetch for post-incident timeline.
- [x] Persist normalized CCTV events into ONYX event flow.
- [x] Add operator visibility:
  - [x] Health state in `/bridges` and `/pollops`.
  - [x] Incident enrichment in Tactical/Operations views.

Acceptance for MVP:
- [ ] Motion/intrusion event reaches ONYX in near real time.
- [ ] Snapshot is retrievable per event.
- [x] Event appears in status/incident context without manual refresh.

Repo validation gates for MVP:
- `test/application/cctv_phase1_flow_test.dart`
- `deploy/cctv_pilot_edge/validate_pilot.sh`
- `scripts/onyx_cctv_field_validation.sh`

---

## 3) CCTV Hardening (After MVP)

- [x] Add per-camera health checks (stream up/down, stale frame age).
- [x] Add retry/backoff for snapshot/clip fetch.
- [x] Add queue protection (bounded queue + drop policy + alerting).
- [x] Add false-positive tuning workflow by zone/time window.
- [x] Add retention policy for snapshots/clips + audit controls.
- [x] Add bridge failure drills (camera offline, MQTT down, VPN flap).

Acceptance for hardening:
- [x] ONYX bridge survives transient outages without silent data loss.
- [x] Health degradation is visible in admin commands.
- [x] Evidence references remain deterministic for replay/reporting.

Repo validation gates for hardening:
- `test/application/cctv_phase1_flow_test.dart`
- `test/application/cctv_evidence_probe_service_test.dart`
- `scripts/onyx_cctv_field_validation.sh`

---

## 4) Listener / Falcon / FSK Path (**TBC**)

Status: **TBC** (not current priority; start only after hardware arrives).

- [ ] Acquire hardware:
  - USB-to-TTL adapter (CP2102 or FT232).
  - Isolation/protection accessories for field-safe serial capture.
- [ ] Bench-test read-only serial sniff:
  - Connect GND + RX only (no TX control path initially).
  - No VCC pin link.
- [ ] Validate actual wire protocol from panel/Falcon output.
- [x] Define ONYX serial ingestor schema (normalized event envelope).
- [ ] Run dual-path pilot (existing path + serial path) for parity checks.
- [ ] Decide cutover only after parity/latency pass criteria are met.

Notes:
- Contract/commercial exposure from bypassing third-party listener remains **TBC**.
- Production rollout decision for listener bypass remains **TBC**.
- Schema scaffold refs:
  - `lib/application/listener_serial_ingestor.dart`
  - `docs/onyx_listener_serial_schema.md`
  - `scripts/onyx_listener_serial_bench.sh`
  - `lib/application/listener_parity_service.dart`
  - `scripts/onyx_listener_parity_report.sh`
  - `scripts/onyx_listener_capture_pack_init.sh`
  - `scripts/onyx_listener_pilot_gate.sh`
  - `scripts/onyx_listener_signoff_generate.sh`
  - Listener parity hardening defaults now enforce a minimum match-rate gate and optional observed-skew ceiling during readiness.
  - Listener parity artifacts now classify drift causes such as skew, zone, partition, account, and site divergence.
  - Listener readiness can now allow or cap specific drift reasons explicitly during pilot cutover evaluation.
  - Listener trend checks can now compare the latest parity report to the previous run and flag regressions in match rate, skew, or drift counts.
  - Listener pilot gate can now run the trend comparison inline against the previous parity artifact.
  - Listener signoff can now require a passing trend report before closeout.
  - Listener field validation bundles can now stage capture files plus parity/trend artifacts and be checked by a readiness gate.
  - Listener mock validation artifacts can now exercise the validation/readiness/signoff tooling without hardware and should be rejected for real signoff.
  - Listener field gate can now initialize capture packs, run validation/readiness, and optionally generate signoff in one command.
  - Listener cutover decisions can now be emitted as explicit `GO|HOLD|BLOCK` artifacts from the latest validation, parity, and trend posture instead of relying on manual summary reading.
  - Listener cutover posture can now be compared run-to-run so `GO|HOLD|BLOCK` regressions and increasing hold/block reason counts are surfaced explicitly.
  - Listener release posture can now be emitted as explicit `PASS|HOLD|FAIL` artifacts that collapse validation, cutover posture, and signoff presence into one final release gate.
  - Listener field gate can now enforce `--require-release-gate-pass`, treating a `HOLD` release posture as a blocking outcome for that invocation.
  - Listener release posture can now be compared run-to-run so `PASS|HOLD|FAIL` regressions and increasing hold/fail reason counts are surfaced explicitly.
  - Listener readiness can now enforce `release_gate = PASS` and `release_trend = PASS` explicitly once those artifacts exist in the validation bundle.
  - Listener field gate can now enforce `--require-release-trend-pass`, treating a failing release-trend check as a blocking outcome for that invocation.
  - Listener readiness now emits a machine-readable `readiness_report.json` plus `readiness_report.md` so downstream release posture can reference audited readiness state instead of terminal output alone.
  - Listener readiness now writes that artifact on both pass and fail once the validation bundle is resolved, so failed gate outcomes remain auditable.
  - Listener readiness failure artifacts now include a machine-readable `failure_code`, so downstream tooling does not need to parse prose summaries.
  - Listener release posture now carries `readiness_failure_code` forward when readiness fails, preserving the structured failure cause through the release gate.
  - Listener signoff now emits a machine-readable `signoff_report.json`, and release posture consumes that structured signoff state instead of only checking markdown file presence.

---

## 5) Operations Runbook Hooks

- [x] Add CCTV bridge checks to daily controller routine.
- [x] Add weekly edge node health review.
- [x] Add “incident evidence retrieval” drill to demo/prep routine.
- [x] Add “CCTV degraded mode” response steps for controllers.

---

## 6) Immediate Next Actions

- [x] Stand up pilot Frigate/go2rtc edge compose.
- [ ] Wire one camera to ONYX `cctv_bridge_service`.
- [x] Verify `/pollops` and `/bridges` reflect CCTV health.
- [ ] Capture first end-to-end event + snapshot + ONYX timeline record.

Field gate:
- Initialize `tmp/cctv_capture` with `scripts/onyx_cctv_capture_pack_init.sh` before the live pilot.
- Run `scripts/onyx_cctv_field_validation.sh --capture-dir tmp/cctv_capture` before checking the remaining live-pilot items.
- Keep both `validation_report.md` and `validation_report.json` as the pilot evidence bundle.
- Run `scripts/onyx_cctv_pilot_readiness_check.sh --require-real-artifacts` after validation to confirm the latest pilot evidence bundle is fresh and signoff-ready.
- Use `scripts/onyx_cctv_pilot_gate.sh` as the one-command wrapper after the capture pack is filled.
- Use `scripts/onyx_cctv_signoff_generate.sh` to generate the final pilot closeout note from the validated bundle.
- Use `scripts/onyx_cctv_mock_validation_artifacts.sh` only for local gate/tooling checks, never for real pilot signoff.
- Use `docs/onyx_cctv_pilot_signoff_template.md` for the final pilot closeout note.
