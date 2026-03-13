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
  - Listener readiness now verifies that referenced cutover and release evidence files still exist, so hollow `cutover_decision.json` or `release_gate.json` copies cannot satisfy readiness on top-level status alone.
  - Listener readiness now also walks through cutover-trend and release-trend references, so `PASS` trend artifacts cannot satisfy readiness if their current or previous aggregate reports point at missing evidence.
  - Listener release posture now carries `readiness_failure_code` forward when readiness fails, preserving the structured failure cause through the release gate.
  - Standalone listener release posture now also fails when staged cutover or signoff reports point at missing evidence files, so hollow aggregate artifacts cannot produce a clean release result outside the readiness path.
  - Standalone listener cutover and signoff now also fail when parity reports or parity-trend artifacts point at missing copied inputs, missing parity summaries, or checksum-mismatched copied parity files, so corrupted parity evidence cannot be promoted by later aggregate gates.
  - Standalone listener cutover now also blocks on hollow parity-trend current/previous reports, and standalone release now also fails on hollow cutover-trend current/previous decisions, so trend artifacts cannot mask missing lower-level evidence.
  - Listener parity-trend, cutover-trend, and release-trend artifacts now also fail directly on hollow current or previous inputs, and parity-trend also fails on checksum-mismatched copied parity files, so broken evidence chains are visible at the trend layer instead of only in downstream readiness or release checks.
  - Listener validation-trend artifacts now also fail directly on hollow or checksum-mismatched validation bundles, so broken staged evidence in current or previous field-validation runs is surfaced as a trend-layer regression instead of only by later readiness checks.
  - Listener cutover-trend and release-trend now recurse through nested cutover, signoff, parity, and validation evidence chains, so checksum-mismatched copied parity files or checksum-mismatched staged validation files now fail directly at the trend layer instead of being deferred to later cutover, release, or readiness gates.
  - Listener readiness and validation-trend now also verify that staged `pilot_gate_report.json` files still match the serial/parity/parity-readiness/parity-trend artifacts they summarize, so hollow or misleading pilot aggregate reports cannot survive only on checksum presence.
  - Listener release posture and release-trend now also verify that staged `signoff_report.json` status fields and enforced requirement flags still match the parity/trend/cutover artifacts they cite, so misleading closeout artifacts cannot survive only on path integrity.
  - Listener release-trend now also verifies that staged `readiness_report.json` status fields and enforced requirement flags still match the validation/trend/cutover artifacts they cite, so misleading readiness artifacts cannot survive only on path integrity.
  - Listener readiness and validation-trend now also verify that the top-level baseline review/health summaries, gate booleans, and primary code fields in `validation_report.json` still match the staged JSON artifacts and code arrays they summarize, so misleading validation aggregates cannot survive only on checksum presence.
  - Standalone listener cutover/release and cutover-trend/release-trend now enforce that same validation-bundle summary consistency, so misleading top-level validation summaries cannot survive outside the readiness path either.
  - Listener readiness, cutover-trend, and release gates now also verify that `cutover_decision.json` still matches the validation/parity/parity-trend/validation-trend artifacts it summarizes, including copied statuses, gate booleans, parity summary, and primary code fields, so stale or hand-edited cutover aggregates cannot survive only on referenced-path integrity.
  - Listener readiness and release-trend now also verify that `release_gate.json` still matches the validation/readiness/cutover/cutover-trend/signoff artifacts it summarizes, including copied statuses, primary codes, and result/code-shape rules, so stale or hand-edited release aggregates cannot survive only on referenced-path integrity.
  - Standalone listener cutover/release and cutover-trend/release-trend now also verify that a staged `pilot_gate_report.json` still matches the serial/parity/parity-readiness/parity-trend artifacts it summarizes, so a stale or hand-edited pilot aggregate cannot survive inside the validation bundle on checksum presence alone.
  - Listener signoff now records the readiness artifact it actually used, and release posture plus release-trend now verify those copied readiness fields, so a stale or hand-edited signoff aggregate cannot silently drift away from the readiness gate that produced it.
  - Listener release posture and release-trend now also reject contradictory top-level `signoff_report.json` state, such as `PASS` with a non-empty `failure_code` or `FAIL` without one.
  - Listener release posture and release-trend now also verify the signoff mock-artifact policy against the referenced validation bundle, so a tampered signoff report cannot claim mock artifacts were disallowed while still pointing at mock validation evidence.
  - Listener release posture now also rejects mixed-bundle signoff, so a signoff report cannot quietly point at different validation, readiness, or cutover artifacts than the release gate consuming it.
  - Mixed-bundle signoff rejection now also covers staged parity reports and parity trends from the validation bundle, preventing signoff from silently borrowing a different parity chain.
  - Mixed-bundle signoff rejection now also covers the resolved validation-trend artifact, preventing signoff from silently borrowing a different validation-trend report from another run.
  - Signoff/release artifact alignment is now exact rather than best-effort: if the release bundle does not have a given aligned artifact, signoff is not allowed to invent one from another run.
  - The same exact-alignment rule now applies to cutover parity and validation-trend evidence, and field-gate cutover now uses the staged validation-bundle parity artifacts instead of pilot-subdirectory copies.
  - Field-gate cutover now also keys that handoff off the staged artifact paths themselves, so cutover generation no longer depends on pilot-subdirectory parity copies when the staged bundle already exists.
  - Release posture and release trend now apply the same exact-alignment rule to `readiness_report.json`, preventing readiness from silently pointing at a different validation or cutover chain than the release gate consuming it.
  - Readiness/release alignment now also covers the resolved validation-trend artifact, preventing readiness from silently borrowing a different validation-trend report from another run.
  - Release posture now also requires `cutover_decision.json.validation_report_json` to match the same staged validation bundle, preventing cutover from silently pointing at another validation run with compatible copied statuses.
  - Release posture now also requires `cutover_decision.json.validation_trend_report_json` to match the staged validation-trend artifact when one exists.
  - Listener readiness now independently re-verifies the same release-gate alignment rules against nested readiness, cutover, and signoff artifacts instead of trusting the release gate's chosen references.
  - Listener readiness and release-trend now also require `release_gate.json.signoff_file` and `signoff_report_json` to point at the staged signoff artifacts under the same validation bundle instead of equivalent copied files elsewhere.
  - Listener readiness now also requires `release_trend_report.json.current_release_gate_json` to equal the staged release gate it is evaluating, preventing release trend from silently borrowing an equivalent current gate from another directory.
  - Listener signoff now emits a machine-readable `signoff_report.json`, and release posture consumes that structured signoff state instead of only checking markdown file presence.
  - Field-gate signoff now uses the staged parity report and staged parity trend from the validation bundle, preventing self-inflicted parity-path mismatches between signoff and release posture.
  - Listener release posture and release-trend artifacts now emit stable reason/regression codes, so downstream automation does not need to parse prose fail or hold summaries.
  - Listener cutover posture and cutover-trend artifacts now emit stable reason/regression codes, so downstream automation does not need to parse prose blocking or hold summaries.
  - Listener validation-trend artifacts now emit stable regression codes, so downstream automation does not need to parse prose validation-regression summaries.
  - Listener validation bundles now emit stable failure and warning codes, so downstream automation does not need to parse gate messages to classify incomplete or failed runs.
  - Listener signoff artifacts now persist on both pass and fail and carry a machine-readable `failure_code`, so blocked signoff attempts remain auditable without parsing terminal output.
  - Listener parity artifacts now emit stable issue and regression codes, so downstream automation does not need to parse parity drift summaries to classify divergence or regression.
  - Listener parity readiness now persists `parity_readiness_report.json` on both pass and fail and carries a machine-readable `failure_code`, so blocked parity gates remain auditable without parsing terminal output.
  - Listener parity artifacts now checksum the copied parity markdown summary, and parity readiness verifies that markdown alongside copied serial and legacy inputs so corrupted standalone parity bundles fail before later aggregate gates consume them.
  - The standalone listener pilot gate now stages the parity readiness artifact into its artifact directory and surfaces readiness status/failure code in its terminal summary.
  - The standalone listener pilot gate now also surfaces parity status, parity primary issue code, and parity-trend primary regression code in its terminal summary when those artifacts exist.
  - The standalone listener pilot gate now persists `pilot_gate_report.json` on both pass and fail, carrying parity, parity readiness, and parity trend statuses plus their primary codes so the standalone dual-path bench flow is auditable without terminal output alone.
  - Listener field-gate signoff now defaults into the field artifact directory and is passed to the release gate explicitly, so a generated signoff cannot be silently ignored by release posture when `--signoff-out` is omitted.
  - Standalone listener release-gate auto-discovery now only accepts filenames containing `signoff`, preventing `readiness_report.md` or other audited artifacts from being misclassified as signoff evidence.
  - Standalone listener cutover decision now auto-resolves staged parity and trend artifacts from the validation bundle, so one-command cutover evaluation no longer reports missing parity evidence when that evidence is already staged in the field-validation artifact.
  - Standalone listener signoff now auto-resolves validation and cutover artifacts from a staged field-validation bundle when parity artifacts are colocated there, so one-command closeout no longer assumes the older parent-directory layout.
  - Listener cutover-trend and release-trend checks now compare stable reason codes instead of prose reason text when those codes are present, preventing wording-only changes from showing up as false regressions.
  - Listener release posture now accepts a passing `signoff_report.json` as sufficient signoff evidence even if the companion markdown file is absent, preventing false `missing_signoff_file` holds when the audited signoff artifact already exists.
  - Listener field-validation now stages `parity_readiness_report.json` and `parity_readiness_report.md` from the pilot artifact and readiness verifies their checksums, so the bundled evidence preserves the full standalone parity-readiness chain.

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
